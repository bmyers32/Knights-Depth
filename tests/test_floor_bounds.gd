extends GutTest
## THE BOUNDS AUDIT, MADE EXECUTABLE (M2 Slice 1).
##
## A pre-implementation audit enumerated every authoritative write to SimWorld.entities[].
## The remembered P17 list (move / lunge / bump / burrow) turned out to be STALE: it omitted
## BOTH knockback paths and registration placement. Every site that audit found gets a test
## here, named for its seam, because "walls constrain only ordinary locomotion" is precisely
## the failure the audit existed to prevent -- being SHOVED through a wall is the same defect
## as walking through one.
##
## Six DISPLACEMENT seams are clamped; two PLACEMENT seams reject instead. The distinction is
## deliberate: a move that would leave the floor stops at the boundary, but a spawn outside
## the floor is a generator/content defect and must fail loudly rather than be silently
## relocated into the room, which would hide the bug behind a floor that merely looks odd.
##
## SYNTHETIC FIXTURE VALUES throughout -- this file protects the mechanical law, never
## shipped tuning.

const PLAYER_ID := 0
const ENEMY_ID := 1
const DT := 1.0 / 30.0

## x and z both span [-10, 10].
const WALL := 10.0
const SPAN := 20.0

var sim: SimWorld


func _chamber() -> WalkableBounds:
	var rects: Array[Rect2] = [Rect2(-WALL, -WALL, SPAN, SPAN)]
	return WalkableBounds.new(rects)


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(_chamber(), Vector3.ZERO)


func _move(actor_id: int, direction: Vector3) -> void:
	sim.tick([Command.new(sim.tick_count, actor_id, "move", {"direction": direction})] as Array[Command], DT)


func _melee_profile(damage: float, knockback: float = 0.0, lunge_distance: float = 0.0, lunge_duration_ticks: int = 0) -> Dictionary:
	return {
		"damage": damage, "damage_type": &"force", "reach": 3.0,
		"cone_half_angle_degrees": 80.0, "knockback_distance": knockback,
		"fire_interval_ticks": 0, "status_id": &"", "status_proc_chance": 0.0,
		"interrupt_strength": 0, "lunge_distance": lunge_distance,
		"lunge_duration_ticks": lunge_duration_ticks, "hit_active_ticks": 4,
		"windup_ticks": 0,
	}


# --- DISPLACEMENT SEAM 1/6: ordinary locomotion --------------------------------------

func test_seam_1_walking_into_a_wall_stops_at_it() -> void:
	sim.add_entity(PLAYER_ID, Vector3(9.0, 0.0, 0.0), 6.0)
	for i in 60:
		_move(PLAYER_ID, Vector3(1.0, 0.0, 0.0))
	assert_almost_eq(sim.entities[PLAYER_ID].x, WALL, 0.0001, "the Envoy must stop at the wall, not pass through it")
	assert_true(sim._bounds.is_inside(sim.entities[PLAYER_ID]), "and must remain in legal space")


## PER-AXIS clamping is what makes wall contact read as sliding rather than sticking. A
## diagonal into a wall must keep the free axis moving -- a hard stop on contact would feel
## like a bug even though it is technically legal.
func test_seam_1_a_diagonal_into_a_wall_slides_along_it() -> void:
	sim.add_entity(PLAYER_ID, Vector3(9.9, 0.0, 0.0), 6.0)
	for i in 15:
		_move(PLAYER_ID, Vector3(1.0, 0.0, -1.0).normalized())
	assert_almost_eq(sim.entities[PLAYER_ID].x, WALL, 0.0001, "the blocked axis pins to the wall")
	assert_lt(sim.entities[PLAYER_ID].z, -1.0, "while the free axis keeps moving -- this is a slide, not a stop")


## THE BACKWARD-COMPATIBILITY PROPERTY, asserted rather than assumed: bounds are optional, so
## the entire pre-M2 suite is unaffected BY CONSTRUCTION and not by luck.
func test_walking_is_unconstrained_when_no_floor_is_loaded() -> void:
	var unbounded := SimWorld.new()
	unbounded.add_entity(PLAYER_ID, Vector3(9.0, 0.0, 0.0), 6.0)
	for i in 60:
		unbounded.tick([Command.new(unbounded.tick_count, PLAYER_ID, "move", {"direction": Vector3(1.0, 0.0, 0.0)})] as Array[Command], DT)
	assert_gt(unbounded.entities[PLAYER_ID].x, WALL, "a sim with no floor loaded must clamp nothing at all")


# --- DISPLACEMENT SEAM 2/6: authored melee lunge -------------------------------------

func test_seam_2_a_lunge_cannot_carry_the_attacker_through_a_wall() -> void:
	sim.add_entity(PLAYER_ID, Vector3(8.5, 0.0, 0.0), 4.0)
	sim.register_combatant(PLAYER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	var profiles: Array[Dictionary] = [_melee_profile(5.0, 0.0, 6.0, 6), _melee_profile(5.0), _melee_profile(5.0)]
	sim.register_melee_profiles(&"test_lunge", profiles, _melee_profile(9.0), 999, 50)
	sim.set_equipped_weapon(PLAYER_ID, &"test_lunge")

	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(1, 0, 0), "phase": "pressed"})] as Array[Command], DT)
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(1, 0, 0), "phase": "released"})] as Array[Command], DT)
	for i in 12:
		sim.tick([] as Array[Command], DT)

	assert_almost_eq(sim.entities[PLAYER_ID].x, WALL, 0.0001,
		"a 6.0-unit lunge from 8.5 must be stopped by the wall at 10.0, not end at 14.5")


# --- DISPLACEMENT SEAM 3/6: hit knockback --------------------------------------------

func test_seam_3_hit_knockback_cannot_shove_a_target_through_a_wall() -> void:
	sim.add_entity(PLAYER_ID, Vector3(6.0, 0.0, 0.0), 4.0)
	sim.register_combatant(PLAYER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(ENEMY_ID, Vector3(8.0, 0.0, 0.0), 0.0)
	sim.register_combatant(ENEMY_ID, 999.0, &"test_enemy", 0, 0.0, &"enemy")
	sim.register_weapon(&"test_knock", 5.0, &"force", 3.0, 80.0, 6.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"test_knock")

	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT)

	assert_lt(sim._health[ENEMY_ID], 999.0, "sanity: the hit actually landed")
	assert_almost_eq(sim.entities[ENEMY_ID].x, WALL, 0.0001,
		"6.0 of knockback from 8.0 must stop at the wall -- displacement INFLICTED on an actor obeys the same walls")


# --- DISPLACEMENT SEAM 4/6: shield-break knockback -----------------------------------

## The SHIELD sits on the enemy here so the player's own attack can break it; block is
## actor-agnostic in the sim, so this exercises _resolve_blocked_hit exactly as shipped.
func test_seam_4_shield_break_knockback_cannot_shove_a_target_through_a_wall() -> void:
	sim.add_entity(PLAYER_ID, Vector3(6.0, 0.0, 0.0), 4.0)
	sim.register_combatant(PLAYER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(ENEMY_ID, Vector3(8.0, 0.0, 0.0), 0.0)
	sim.register_combatant(ENEMY_ID, 999.0, &"test_enemy", 0, 0.0, &"enemy")
	sim.register_shield(ENEMY_ID, 1.0, 0.0, 30, 6.0)
	sim.register_weapon(&"test_breaker", 50.0, &"force", 3.0, 80.0, 0.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"test_breaker")

	sim.tick([Command.new(sim.tick_count, ENEMY_ID, "block", {"held": true})] as Array[Command], DT)
	var events: Array[Event] = sim.tick([
		Command.new(sim.tick_count, ENEMY_ID, "block", {"held": true}),
		Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(1, 0, 0)}),
	] as Array[Command], DT)

	var broke: bool = false
	for event in events:
		if event.kind == "shield_broken":
			broke = true
	assert_true(broke, "sanity: the shield actually broke")
	assert_almost_eq(sim.entities[ENEMY_ID].x, WALL, 0.0001, "shield-break recoil must clamp to the floor too")


# --- DISPLACEMENT SEAM 5/6: shield bump slide ----------------------------------------

func test_seam_5_a_bump_slide_cannot_push_a_target_through_a_wall() -> void:
	sim.add_entity(PLAYER_ID, Vector3(8.6, 0.0, 0.0), 4.0)
	sim.register_combatant(PLAYER_ID, 999.0, &"envoy", 0, 0.4, &"player")
	sim.add_entity(ENEMY_ID, Vector3(9.6, 0.0, 0.0), 0.0)
	sim.register_combatant(ENEMY_ID, 999.0, &"test_enemy", 0, 0.6, &"enemy")
	# meter_max, regen, break_delay, knockback, bump_padding, bump_distance, slide_ticks
	sim.register_shield(PLAYER_ID, 100.0, 0.0, 30, 0.0, 0.5, 5.0, 5, 0)

	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "block", {"held": true})] as Array[Command], DT)
	assert_true(sim._bump_slides.has(ENEMY_ID), "sanity: the bump actually started a slide")
	for i in 10:
		sim.tick([] as Array[Command], DT)

	assert_almost_eq(sim.entities[ENEMY_ID].x, WALL, 0.0001, "a bump slide must end at the wall, not beyond it")


# --- DISPLACEMENT SEAM 6/6: burrow backward jump -------------------------------------

func test_seam_6_a_burrow_jump_cannot_carry_the_actor_through_a_wall() -> void:
	sim.add_entity(PLAYER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(PLAYER_ID, 999.0, &"envoy", 0, 0.4, &"player")
	sim.add_entity(ENEMY_ID, Vector3(9.0, 0.0, 0.0), 3.0)
	sim.register_combatant(ENEMY_ID, 999.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	# A 4.0 jump away from the player (+X) from x = 9.0 would otherwise reach 13.0.
	sim.register_ai(ENEMY_ID, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 10000),
		Vector3(9.0, 0.0, 0.0), 1.5, 0.0, 60.0, 200.0, 0, 0,
		4.0, 0.5, 10, 2.0, 10, 6, 30)
	sim._next_fire_tick[ENEMY_ID] = 1_000_000

	assert_true(sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID), "sanity: the burrow triggered")
	for i in 12:
		sim.tick([] as Array[Command], DT)
		assert_true(sim._bounds.is_inside(sim.entities[ENEMY_ID]),
			"the burrowing Fang left the floor on tick %d at %s" % [i, sim.entities[ENEMY_ID]])
	assert_almost_eq(sim.entities[ENEMY_ID].x, WALL, 0.0001, "the jump must be stopped by the wall")


# --- PLACEMENT SEAM 1/2: burrow emergence --------------------------------------------

## Emergence is PLACEMENT, so an out-of-bounds candidate is refused exactly like an occupied
## one -- the fixed candidate set keeps rotating and the retry/timeout law is untouched.
func test_placement_burrow_emergence_never_surfaces_outside_the_floor() -> void:
	sim.add_entity(PLAYER_ID, Vector3(9.0, 0.0, 0.0), 4.0)
	sim.register_combatant(PLAYER_ID, 999.0, &"envoy", 0, 0.4, &"player")
	sim.add_entity(ENEMY_ID, Vector3(5.0, 0.0, 0.0), 3.0)
	sim.register_combatant(ENEMY_ID, 999.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY_ID, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 10000),
		Vector3(5.0, 0.0, 0.0), 1.5, 0.0, 60.0, 200.0, 0, 0,
		2.0, 0.5, 6, 2.0, 30, 6, 30)
	sim._next_fire_tick[ENEMY_ID] = 1_000_000

	assert_true(sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID), "sanity: triggered")
	var emerged: bool = false
	for i in 120:
		sim.tick([] as Array[Command], DT)
		if not sim._combat_absent.has(ENEMY_ID) and sim._burrow.has(ENEMY_ID):
			emerged = true
			break
	assert_true(emerged, "sanity: it emerged rather than timing out")

	var surfaced: Vector3 = sim.entities[ENEMY_ID]
	assert_true(sim._bounds.is_inside(surfaced), "emergence at %s is outside the floor" % surfaced)
	# DISCRIMINATION: the player sits 1.0 from the wall with a 2.0 emergence radius, so the
	# zero-degree far-side candidate lands at x = 11.0 -- outside. Proving it was NOT chosen
	# proves the filter actually rejected something rather than passing everything through.
	assert_lt(surfaced.x, WALL + 0.0001, "the illegal zero-degree candidate must have been skipped")


# --- PLACEMENT SEAM 2/2: registration ------------------------------------------------

## Registration REFUSES rather than clamping. A silently relocated spawn would hide a
## generator defect; a missing enemy plus an error line is diagnosable.
func test_placement_registering_an_entity_outside_the_floor_fails_loudly() -> void:
	var accepted: bool = sim.add_entity(ENEMY_ID, Vector3(25.0, 0.0, 0.0), 3.0)
	assert_false(accepted, "add_entity must report the refusal to its caller")
	assert_false(sim.entities.has(ENEMY_ID), "and must register nothing at all -- never a clamped position")
	assert_push_error("outside walkable bounds", "the refusal must be loud, not silent")


func test_placement_inside_the_floor_still_registers_normally() -> void:
	assert_true(sim.add_entity(ENEMY_ID, Vector3(5.0, 0.0, 5.0), 3.0), "a legal placement must be accepted")
	assert_eq(sim.entities[ENEMY_ID], Vector3(5.0, 0.0, 5.0))


func test_content_registrar_abandons_an_enemy_the_sim_refuses() -> void:
	var actions: Dictionary = ContentRegistrar.register_enemy_body(sim, ENEMY_ID, &"fang", Vector3(40.0, 0.0, 0.0))
	assert_true(actions.is_empty(), "a refused placement must abort the rest of that actor's registration")
	assert_false(sim.entities.has(ENEMY_ID), "no position")
	assert_false(sim._health.has(ENEMY_ID), "and no orphaned combatant that exists but cannot be located")
	assert_push_error("outside walkable bounds", "the refusal must be loud")


# --- MULTI-RECT / DOORWAY (M2 multi-room slice) ---------------------------------------
# Slice 1's clamp chose the FIRST array-order rect containing the actor. In a doorway -- where
# an aperture rect deliberately overlaps both rooms -- that made wall placement depend on
# authoring order, producing a PHANTOM WALL across a visibly open threshold.

## Two rooms joined by an aperture that overlaps both, mirroring what DepthGenerator emits.
##   room A  x[-6, 6]   z[-10, 0]
##   room B  x[-10,10]  z[-36,-16]
##   door    x[-2.5,2.5] z[-17.5,-8.5]  (1.5 into each room)
func _two_room_floor() -> WalkableBounds:
	var rects: Array[Rect2] = [
		Rect2(-6.0, -10.0, 12.0, 10.0),
		Rect2(-10.0, -36.0, 20.0, 20.0),
		Rect2(-2.5, -17.5, 5.0, 9.0),
	]
	return WalkableBounds.new(rects)


func test_an_actor_can_walk_between_two_rooms_through_their_aperture() -> void:
	sim = SimWorld.new()
	sim.load_floor(_two_room_floor(), Vector3(0.0, 0.0, -5.0))
	sim.add_entity(PLAYER_ID, Vector3(0.0, 0.0, -5.0), 6.0)
	for i in 200:
		_move(PLAYER_ID, Vector3(0.0, 0.0, -1.0))
	assert_lt(sim.entities[PLAYER_ID].z, -20.0, "the Envoy must reach the far room, not stop at the first wall")


## THE PHANTOM-WALL REGRESSION ITSELF. Standing in the overlap strip, an actor is inside TWO
## rects. Array order must not decide which one constrains it: the clamp picks the candidate
## nearest the intended destination, so the open direction stays open.
func test_standing_in_a_doorway_no_array_order_wall_appears() -> void:
	var bounds: WalkableBounds = _two_room_floor()
	# Inside both room A (z >= -10) and the aperture (z <= -8.5).
	var threshold := Vector3(0.0, 0.0, -9.0)
	assert_true(bounds.is_inside(threshold), "sanity: the threshold is legal")

	# Deeper into the corridor is legal, and must be returned unchanged.
	var onward := Vector3(0.0, 0.0, -12.0)
	assert_eq(bounds.clamp_step(threshold, onward), onward, "a legal destination is never clamped")

	# Sideways out of the corridor is illegal. Room A's wall is at x = 6, the aperture's at
	# x = 2.5; the clamp must choose the one NEAREST the destination, never the first in the
	# array -- which is what stops a doorway from acquiring an invisible wall.
	var sideways := Vector3(9.0, 0.0, -9.0)
	var clamped: Vector3 = bounds.clamp_step(threshold, sideways)
	assert_true(bounds.is_inside(clamped), "the clamp must land somewhere legal")
	assert_almost_eq(clamped.x, 6.0, 0.0001, "it must clamp to room A's wall, the nearer legal edge")


func test_a_diagonal_through_a_doorway_is_not_blocked_by_the_corridor_walls() -> void:
	sim = SimWorld.new()
	sim.load_floor(_two_room_floor(), Vector3(0.0, 0.0, -5.0))
	sim.add_entity(PLAYER_ID, Vector3(1.5, 0.0, -5.0), 6.0)
	# Aim diagonally THROUGH the doorway, converging on it. The x component is absorbed by the
	# corridor wall while the z component keeps carrying the actor onward -- a diagonal that
	# instead drifted AWAY from the opening would legitimately hit the wall beside it, which is
	# correct behaviour and not what this test is about.
	for i in 300:
		_move(PLAYER_ID, Vector3(-0.4, 0.0, -1.0).normalized())
	assert_lt(sim.entities[PLAYER_ID].z, -20.0, "the diagonal must still get through the door")
	assert_true(sim._bounds.is_inside(sim.entities[PLAYER_ID]), "and stay legal the whole way")
