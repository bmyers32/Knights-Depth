extends GutTest
## BODY-AWARE MOVEMENT LEGALITY (ruled 2026-08-29, after human play).
##
## THE DEFECT THIS EXISTS TO PREVENT: point-only legality could truthfully call a position legal
## while the actor's authored body extended through a solid boundary. Observed in play as an
## Ooze clipping through a wall. The law is now: A POSITION IS LEGAL ONLY WHEN THE ACTOR'S BODY
## FOOTPRINT LIES INSIDE THE WALKABLE UNION.
##
## THE UNION IS TESTED AS A UNION. Shrinking each rect by the radius independently would be the
## obvious implementation and would silently break the floor -- an actor in a doorway straddles
## a patch and an aperture and fits NEITHER alone. `test_the_union_holds_a_body_no_single_rect
## _could` and `test_a_body_traverses_an_aperture` are the two that would fail under that
## implementation, and they are the reason this file exists in this shape.
##
## SYNTHETIC FIXTURE GEOMETRY throughout -- mechanical law only, never shipped tuning.

const PLAYER_ID := 0
const ENEMY_ID := 1
const OTHER_ID := 2
const DT := 1.0 / 30.0

## x and z both span [-10, 10].
const WALL := 10.0
const SPAN := 20.0

## Two patches that ABUT on x = 0 -- zero shared area, so no single rect can hold a body
## straddling the seam, while the union holds it comfortably.
const WEST_HALF := Rect2(-10.0, -3.0, 10.0, 6.0)
const EAST_HALF := Rect2(0.0, -3.0, 10.0, 6.0)

## A real doorway: two patches with a gap, joined by an aperture that OVERLAPS both.
const WEST_ROOM := Rect2(-20.0, -3.0, 16.0, 6.0)   # x[-20,-4]
const EAST_ROOM := Rect2(4.0, -3.0, 16.0, 6.0)     # x[4,20]
const APERTURE := Rect2(-5.5, -1.5, 11.0, 3.0)     # x[-5.5,5.5] z[-1.5,1.5]

## An L: the inner (concave) corner sits at (-6, -6).
const ELL_ARM_A := Rect2(-10.0, -10.0, 20.0, 4.0)  # z[-10,-6]
const ELL_ARM_B := Rect2(-10.0, -10.0, 4.0, 20.0)  # x[-10,-6]

var sim: SimWorld


func _chamber() -> WalkableBounds:
	var rects: Array[Rect2] = [Rect2(-WALL, -WALL, SPAN, SPAN)]
	return WalkableBounds.new(rects)


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(_chamber(), Vector3.ZERO)


func _walk(actor_id: int, direction: Vector3, ticks: int) -> void:
	for i in ticks:
		sim.tick([Command.new(sim.tick_count, actor_id, "move", {"direction": direction})] as Array[Command], DT)


## Registers a body that can actually move, at `radius`.
func _body(actor_id: int, position: Vector3, radius: float, speed: float = 6.0) -> void:
	sim.add_entity(actor_id, position, speed, Vector3(0.0, 0.0, -1.0), radius)
	sim.register_combatant(actor_id, 999.0, &"envoy", 0, radius, &"player")


# --- THE PREDICATE ITSELF ----------------------------------------------------------------

## THE UNION PROPERTY, asserted directly. This is the test that fails the moment anyone
## "optimises" fits() into a per-rect shrink.
func test_the_union_holds_a_body_no_single_rect_could() -> void:
	var straddling := Vector3(0.0, 0.0, 0.0)
	var both := WalkableBounds.new([WEST_HALF, EAST_HALF] as Array[Rect2])
	var west_only := WalkableBounds.new([WEST_HALF] as Array[Rect2])
	var east_only := WalkableBounds.new([EAST_HALF] as Array[Rect2])

	assert_true(both.fits(straddling, 1.0), "the union must hold a body sitting across the seam")
	assert_false(west_only.fits(straddling, 1.0), "sanity: the west rect alone cannot hold it")
	assert_false(east_only.fits(straddling, 1.0), "sanity: the east rect alone cannot hold it")


func test_a_body_exactly_tangent_to_a_boundary_still_fits() -> void:
	var bounds := _chamber()
	# Resting against a wall must be legal, mirroring is_inside's inclusive edges -- otherwise
	# an actor could never touch a wall at all and the clamp would chatter against its own edge.
	assert_true(bounds.fits(Vector3(WALL - 1.0, 0.0, 0.0), 1.0), "a body touching the wall is legal")
	assert_false(bounds.fits(Vector3(WALL - 0.9, 0.0, 0.0), 1.0), "a body crossing it is not")


func test_a_bodiless_actor_keeps_point_legality_exactly() -> void:
	var bounds := _chamber()
	assert_true(bounds.fits(Vector3(WALL, 0.0, 0.0), 0.0), "radius 0 must degrade to is_inside")
	assert_eq(bounds.clamp_step(Vector3.ZERO, Vector3(99.0, 0.0, 0.0), 0.0), Vector3(WALL, 0.0, 0.0),
		"and clamp to the boundary itself, exactly as before this law existed")


# --- DISPLACEMENT ------------------------------------------------------------------------

func test_a_body_stops_short_of_a_straight_wall_by_its_own_radius() -> void:
	_body(PLAYER_ID, Vector3.ZERO, 1.2)
	_walk(PLAYER_ID, Vector3(1, 0, 0), 200)
	assert_almost_eq(sim.entities[PLAYER_ID].x, WALL - 1.2, 0.001,
		"the BODY meets the wall, so the centre rests one radius short of it")


## DIFFERENT AUTHORED RADII resolve differently against the same wall -- the law reads each
## actor's own body, never a shared constant.
func test_different_authored_radii_rest_at_different_distances() -> void:
	_body(PLAYER_ID, Vector3(0.0, 0.0, -4.0), 0.3)
	_body(ENEMY_ID, Vector3(0.0, 0.0, 4.0), 2.0)
	_walk(PLAYER_ID, Vector3(1, 0, 0), 200)
	_walk(ENEMY_ID, Vector3(1, 0, 0), 200)
	assert_almost_eq(sim.entities[PLAYER_ID].x, WALL - 0.3, 0.001, "a small body gets closer")
	assert_almost_eq(sim.entities[ENEMY_ID].x, WALL - 2.0, 0.001, "a large body is held further out")


## APERTURE TRAVERSAL, the case a per-rect shrink would break: shrinking WEST_ROOM and APERTURE
## independently leaves a gap between them that no body could cross, even though the union is
## continuous and comfortably wider than this actor.
func test_a_body_traverses_an_aperture_that_overlaps_both_patches() -> void:
	var rects: Array[Rect2] = [WEST_ROOM, EAST_ROOM, APERTURE]
	sim.load_floor(WalkableBounds.new(rects), Vector3(-12.0, 0.0, 0.0))
	_body(PLAYER_ID, Vector3(-12.0, 0.0, 0.0), 1.0)

	for i in 400:
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3(1, 0, 0)})] as Array[Command], DT)
		assert_true(sim._bounds.fits(sim.entities[PLAYER_ID], 1.0),
			"the body left the floor mid-crossing on tick %d at %s" % [i, sim.entities[PLAYER_ID]])
	assert_gt(sim.entities[PLAYER_ID].x, 4.0, "and it must actually reach the far room")


## CONCAVE CORNER. A body may not cut the inside of an L, and walking into one must not
## produce a single illegal position along the way.
func test_a_body_cannot_clip_a_concave_corner() -> void:
	var rects: Array[Rect2] = [ELL_ARM_A, ELL_ARM_B]
	var bounds := WalkableBounds.new(rects)
	# Centre is legal as a POINT (both arms miss it) yet the body reaches past the inner corner.
	assert_false(bounds.fits(Vector3(-7.0, 0.0, -7.0), 1.5), "the body overhangs the inner corner")

	sim.load_floor(bounds, Vector3(-8.0, 0.0, -8.0))
	_body(PLAYER_ID, Vector3(-8.0, 0.0, -8.0), 1.5)
	for i in 300:
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3(1, 0, 1).normalized()})] as Array[Command], DT)
		assert_true(sim._bounds.fits(sim.entities[PLAYER_ID], 1.5),
			"the body clipped the corner on tick %d at %s" % [i, sim.entities[PLAYER_ID]])


## LARGE KNOCKBACK into a boundary. Being SHOVED through a wall is the same defect as walking
## through one, and knockback is the seam most likely to be forgotten (the P17 audit missed
## both knockback paths).
func test_a_large_knockback_cannot_shove_a_body_through_a_boundary() -> void:
	_body(PLAYER_ID, Vector3(0.0, 0.0, 0.0), 0.4)
	_body(ENEMY_ID, Vector3(8.0, 0.0, 0.0), 1.0)
	sim.register_combatant(ENEMY_ID, 999.0, &"fang", 0, 1.0, &"enemy")
	sim.register_weapon(&"test_shove", 5.0, &"force", 30.0, 90.0, 25.0, 1)
	sim.set_equipped_weapon(PLAYER_ID, &"test_shove")

	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT)
	for i in 10:
		sim.tick([] as Array[Command], DT)

	assert_true(sim._bounds.fits(sim.entities[ENEMY_ID], 1.0),
		"a 25-unit shove left the body outside the floor at %s" % sim.entities[ENEMY_ID])
	assert_almost_eq(sim.entities[ENEMY_ID].x, WALL - 1.0, 0.001, "it stops with its body against the wall")


# --- PLACEMENT: TWO CONSUMERS, TWO DIFFERENT REFUSALS ------------------------------------

## PLACEMENT CONSUMER 1/2 -- REGISTRATION. Refuses LOUDLY and abandons the actor, because a
## spawn whose body cannot occupy its own position is a content defect that must be seen.
func test_registration_refuses_a_spawn_whose_body_does_not_fit() -> void:
	# Point-legal: x = 9.5 is inside the chamber. Body-illegal: a 1.2 radius crosses x = 10.
	assert_false(sim.add_entity(ENEMY_ID, Vector3(9.5, 0.0, 0.0), 3.0, Vector3(0, 0, -1), 1.2),
		"a body that does not fit must be refused, not silently relocated")
	assert_push_error("outside walkable bounds", "the refusal must be loud, not silent")
	assert_false(sim.entities.has(ENEMY_ID), "and the actor must not be registered at all")


func test_registration_still_accepts_the_same_spawn_for_a_bodiless_actor() -> void:
	# The CONTRAST that proves the refusal above measured the BODY and not the position.
	assert_true(sim.add_entity(ENEMY_ID, Vector3(9.5, 0.0, 0.0), 3.0, Vector3(0, 0, -1), 0.0),
		"radius 0 keeps the pre-2026-08-29 placement law exactly")


## PLACEMENT CONSUMER 2/2 -- BURROW EMERGENCE. Refuses SILENTLY and rotates to its next
## candidate, because retrying is its authored behaviour; the fail-safe death on exhaustion is
## untouched. Body extent is simply one more reason a candidate can be rejected.
func test_burrow_emergence_never_surfaces_a_body_outside_the_floor() -> void:
	_body(PLAYER_ID, Vector3(8.0, 0.0, 8.0), 0.4, 4.0)
	sim.add_entity(ENEMY_ID, Vector3(9.0, 0.0, 9.0), 3.0, Vector3(0, 0, -1), 0.6)
	sim.register_combatant(ENEMY_ID, 999.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY_ID, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 10000),
		Vector3(9.0, 0.0, 9.0), 1.5, 0.0, 60.0, 200.0, 0, 0,
		4.0, 0.5, 10, 2.0, 10, 6, 30)
	sim._next_fire_tick[ENEMY_ID] = 1_000_000

	assert_true(sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID), "sanity: the burrow triggered")
	for i in 40:
		sim.tick([] as Array[Command], DT)
		assert_true(sim._bounds.fits(sim.entities[ENEMY_ID], 0.6),
			"emergence put a body outside the floor on tick %d at %s" % [i, sim.entities[ENEMY_ID]])


# --- THE AMENDMENT: BODY-AWARE CLAMPING MUST NOT BREAK CONTACT ---------------------------

## Body-aware resting positions move every actor one radius off the boundary, which shifts
## where wall-pinned actors end up. Burn's contact-spread and the lunge clamp share ONE
## authoritative contact distance (_contact_distance), tuned jointly with clamp distance, so
## two actors pinned against the same wall must still QUALIFY as contact if they did before.
func test_two_bodies_pinned_against_one_wall_still_qualify_as_contact() -> void:
	_body(PLAYER_ID, Vector3(9.0, 0.0, 0.0), 0.6)
	_body(OTHER_ID, Vector3(9.0, 0.0, 1.0), 0.5)
	assert_true(sim._actors_overlap(PLAYER_ID, OTHER_ID), "sanity: in contact before being pinned")

	_walk(PLAYER_ID, Vector3(1, 0, 0), 60)
	_walk(OTHER_ID, Vector3(1, 0, 0), 60)

	assert_almost_eq(sim.entities[PLAYER_ID].x, WALL - 0.6, 0.001, "sanity: each rests on its own body")
	assert_almost_eq(sim.entities[OTHER_ID].x, WALL - 0.5, 0.001, "sanity: including the smaller one")
	assert_true(sim._actors_overlap(PLAYER_ID, OTHER_ID),
		"body-aware clamping must not silently separate actors out of contact at a wall")
