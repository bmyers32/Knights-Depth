extends GutTest
## TERRITORY SEMANTICS — behavioural leash vs physical legality (ruled 2026-08-31).
##
## THE DEFECT THIS SPLIT FIXED: an ambient Ooze shield-bumped toward open floor clamped against
## its own territory edge. That edge runs through walkable ground with no wall anywhere near it,
## so a player saw an enemy stop dead in the open and read it as wedged in a gap. A BEHAVIOURAL
## LEASH HAD BEEN COMPILED INTO PHYSICAL LEGALITY.
##
## THE SEMANTIC MATRIX under test, and the anti-collapse guard that keeps it a matrix:
##
##   source                                voluntary          forced displacement
##   floor / WALL / closed connection      cannot cross       cannot cross
##   hard encounter seal                   cannot cross       cannot cross
##   ambient home territory                NOT A LIMIT        MAY cross; returns when disengaged
##
## PURSUIT IS DETECTION-GOVERNED, NOT TERRITORY-GOVERNED (ruled 2026-08-31, after play). An
## ENGAGED ambient enemy chases anywhere physically legal. Home keeps three jobs and no more:
## authored spawn context, acquisition association, and the destination it walks back to once
## it disengages. Kiting an ambient enemy across open floor is an ACCEPTED consequence at this
## floor scale, not a defect to be leashed away.
##
## SYNTHETIC FIXTURE GEOMETRY -- mechanical law only, never shipped tuning.

const PLAYER := 0
const ENEMY := 1
const DT := 1.0 / 30.0
const RADIUS := 1.45
const ENCOUNTER := 0

## One wide open room. HOME is the eastern half only, so the leash edge at x = 0 sits in the
## middle of perfectly walkable floor -- exactly the shipped condition that produced the defect.
const ROOM := Rect2(-20.0, -10.0, 40.0, 20.0)
const HOME := Rect2(0.0, -10.0, 20.0, 20.0)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)


## The Envoy, armed with a shield whose bump shoves hard enough to cross the leash.
func _arm_player(at: Vector3) -> void:
	sim.add_entity(PLAYER, at, 6.0, Vector3(1, 0, 0), 0.4)
	sim.register_combatant(PLAYER, 5000.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.register_shield(PLAYER, 100.0, 1.0, 30, 0.0, 0.5, 6.0, 6, 0)


## `confines` registers a SEALING encounter; it is also ACTIVATED here, because sealing is a
## live fact and not a property of role (ruled 2026-09-03). A registered-but-dormant encounter
## seals nobody -- the fixture has to start the fight, exactly as a floor does.
func _add_ooze(at: Vector3, role: StringName, regions: Array[Rect2], confines: bool = false) -> void:
	sim.register_encounter(ENCOUNTER, regions, role, confines, true)
	sim.add_entity(ENEMY, at, 1.5, Vector3(-1, 0, 0), RADIUS)
	sim.register_combatant(ENEMY, 500.0, &"ooze", 0, RADIUS, &"enemy")
	sim.register_weapon(&"test_slam", 5.0, &"force", 1.9, 90.0, 0.0, 9999)
	# Detection 12 / leash 20: large enough for ordinary pursuit, small enough that a test can
	# walk out of engagement and observe the disengaged return.
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"test_slam", 1.9, 10000),
		at, 2.2, 1.9, 12.0, 20.0, 0, 0, 0.0, 0.0, 0, 0.0, 0, 0, 0, 45)
	assert_true(sim.assign_actor_encounter(ENEMY, ENCOUNTER), "sanity: bound to its site")
	if confines:
		sim.debug_activate_encounter(ENCOUNTER)
		assert_eq(sim.debug_describe_floor()["active_confinement"], ENCOUNTER,
			"sanity: a seal fixture must actually be sealing, or it proves nothing")
	sim.debug_set_ai_active(ENEMY)


## Drives the real shield bump, westward, into the enemy.
func _bump() -> void:
	sim.tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})] as Array[Command], DT)
	sim.tick([Command.new(sim.tick_count, PLAYER, "bump", {"aim": Vector3(-1, 0, 0)})] as Array[Command], DT)
	for i in 12:
		sim.tick([] as Array[Command], DT)


func _run(ticks: int) -> void:
	for i in ticks:
		sim.tick([] as Array[Command], DT)


func _home_bounds() -> WalkableBounds:
	return sim._encounter_bounds[ENCOUNTER]


# --- THE HUMAN CASE, END TO END -----------------------------------------------------------

## Crosses instead of clamping, keeps aggro, steers home, arrives, resumes.
func test_a_bump_carries_an_ambient_actor_across_its_own_leash_and_it_returns() -> void:
	var ambient: Array[Rect2] = [HOME]
	_arm_player(Vector3(4.0, 0.0, 0.0))
	_add_ooze(Vector3(1.8, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, ambient)
	assert_true(_home_bounds().fits(sim.entities[ENEMY], RADIUS), "sanity: starts legally inside home")

	_bump()
	var after_bump: Vector3 = sim.entities[ENEMY]

	assert_lt(after_bump.x, 1.45,
		"the bump must CARRY it across the invisible leash, not clamp against it (at %s)" % after_bump)
	assert_false(_home_bounds().fits(after_bump, RADIUS), "sanity: it really is outside home now")
	assert_true(sim._bounds.fits(after_bump, RADIUS), "and physical legality still holds")
	assert_eq(sim._ai_state[ENEMY], "active", "aggro must survive being displaced")

	# RETURN IS A DISENGAGED behaviour. While the player is still in range the actor keeps
	# fighting -- that is the ruling. Walk far away, let engagement lapse, and only then does
	# home become its destination.
	sim.entities[PLAYER] = Vector3(-19.0, 0.0, 9.0)
	_run(600)
	assert_true(_home_bounds().fits(sim.entities[ENEMY], RADIUS),
		"a disengaged actor must walk back home, ending at %s" % sim.entities[ENEMY])


## A DISENGAGED actor walks home even when the player it was chasing is the other way. This is
## the return half of the ruling: home decides where it goes when nobody is being chased, and
## nothing else.
func test_a_disengaged_actor_returns_home_regardless_of_where_the_player_stands() -> void:
	var ambient: Array[Rect2] = [HOME]
	_arm_player(Vector3(4.0, 0.0, 0.0))
	_add_ooze(Vector3(1.8, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, ambient)
	_bump()
	assert_false(_home_bounds().fits(sim.entities[ENEMY], RADIUS), "sanity: the bump put it outside")

	# Walk out of engagement entirely, on the far side from home.
	sim.entities[PLAYER] = Vector3(-19.0, 0.0, 9.0)
	_run(600)
	assert_true(_home_bounds().fits(sim.entities[ENEMY], RADIUS),
		"a disengaged actor must return home, ending at %s" % sim.entities[ENEMY])


## Aggro and movement policy are SEPARATE FACTS: a returning actor is not a pacifist.
func test_a_returning_actor_is_still_a_combatant() -> void:
	var ambient: Array[Rect2] = [HOME]
	_arm_player(Vector3(4.0, 0.0, 0.0))
	_add_ooze(Vector3(1.8, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, ambient)
	_bump()
	assert_false(_home_bounds().fits(sim.entities[ENEMY], RADIUS), "sanity: outside home")

	# Stand INSIDE the action's authored band (1.9), outside home, and let it act. At 2.0 the
	# action is simply not eligible and the test would measure band arithmetic, not aggro.
	sim.entities[PLAYER] = sim.entities[ENEMY] + Vector3(-1.5, 0.0, 0.0)
	sim.debug_set_ai_active(ENEMY)
	sim._next_fire_tick[ENEMY] = 0
	var telegraphs: int = 0
	for i in 200:
		for event in sim.tick([] as Array[Command], DT):
			if event.kind == "attack_telegraph":
				telegraphs += 1
		sim.entities[PLAYER] = sim.entities[ENEMY] + Vector3(-1.5, 0.0, 0.0)
	assert_gt(telegraphs, 0, "an actor outside home must still fight when the player is in reach")


# --- PURSUIT IS DETECTION-GOVERNED --------------------------------------------------------

## INVERTED 2026-08-31. This previously asserted that voluntary pursuit never leaves home -- the
## v1 leash-hold. Human play judged that hold visibly artificial and ruled pursuit
## detection-governed instead, so the same scenario now asserts the OPPOSITE. Kiting across open
## floor is the accepted consequence at this scale.
func test_an_engaged_ambient_actor_chases_out_of_its_home() -> void:
	var ambient: Array[Rect2] = [HOME]
	_arm_player(Vector3(-4.0, 0.0, 0.0))
	_add_ooze(Vector3(3.0, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, ambient)
	_run(300)
	assert_false(_home_bounds().fits(sim.entities[ENEMY], RADIUS),
		"an engaged ambient enemy must follow the player out of its home, ended at %s" % sim.entities[ENEMY])
	assert_true(sim._bounds.fits(sim.entities[ENEMY], RADIUS), "while physical legality still binds it")


## The kiting consequence, accepted explicitly rather than tolerated silently: a player who keeps
## backing away keeps being followed, for as long as engagement holds.
func test_an_engaged_ambient_actor_can_be_kited_across_open_floor() -> void:
	var ambient: Array[Rect2] = [HOME]
	_arm_player(Vector3(6.0, 0.0, 0.0))
	_add_ooze(Vector3(10.0, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, ambient)
	for i in 400:
		sim.tick([] as Array[Command], DT)
		# Retreat slowly, staying inside detection so engagement never lapses.
		var gap: Vector3 = sim.entities[ENEMY] - sim.entities[PLAYER]
		if gap.length() > 4.0:
			sim.entities[PLAYER] = sim.entities[ENEMY] - gap.normalized() * 4.0
		sim.entities[PLAYER] = Vector3(maxf(sim.entities[PLAYER].x - 0.03, -18.0), 0.0, 0.0)
	assert_lt(sim.entities[ENEMY].x, 0.0, "it followed the kite well past its home edge")


## Inside its own home, away from the edge, nothing about this changes ordinary behaviour.
func test_ordinary_pursuit_inside_home_is_unchanged() -> void:
	var ambient: Array[Rect2] = [HOME]
	_arm_player(Vector3(16.0, 0.0, 0.0))
	_add_ooze(Vector3(4.0, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, ambient)
	var start_gap: float = sim.entities[ENEMY].distance_to(sim.entities[PLAYER])
	_run(300)
	assert_lt(sim.entities[ENEMY].distance_to(sim.entities[PLAYER]), start_gap,
		"an unleashed pursuit inside home must still close on the player")


# --- THE OTHER TWO CONFINEMENT SOURCES: BOTH HARD ------------------------------------------

## PHYSICAL. The same bump into a real boundary hard-stops.
func test_the_same_bump_into_a_wall_hard_stops() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var narrow: Array[Rect2] = [Rect2(0.0, -10.0, 20.0, 20.0)]  # floor ENDS at x = 0
	sim.load_floor(WalkableBounds.new(narrow), Vector3.ZERO)
	sim.register_patches(narrow)
	_arm_player(Vector3(4.0, 0.0, 0.0))
	_add_ooze(Vector3(1.8, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, narrow)

	_bump()
	assert_true(sim._bounds.fits(sim.entities[ENEMY], RADIUS),
		"physical legality is HARD for forced displacement too, ended at %s" % sim.entities[ENEMY])
	assert_gte(sim.entities[ENEMY].x, RADIUS - 0.001, "it must rest with its body against the floor edge")


## SEAL. A roster actor cannot be bumped out of a live sealed fight.
func test_a_roster_actor_cannot_be_bumped_out_of_a_sealed_encounter() -> void:
	var seal: Array[Rect2] = [HOME]
	_arm_player(Vector3(4.0, 0.0, 0.0))
	_add_ooze(Vector3(1.8, 0.0, 0.0), FloorLayers.ROLE_MANDATORY, seal, true)

	_bump()
	assert_true(_home_bounds().fits(sim.entities[ENEMY], RADIUS),
		"a sealed encounter is HARD legality; the roster stays in the fight (at %s)" % sim.entities[ENEMY])


# --- ANTI-COLLAPSE: the three must resolve DIFFERENTLY --------------------------------------

## THE POINT OF THE SPLIT, asserted as a distinction rather than as three separate behaviours.
## A future refactor cannot merge confinement back into one generic predicate without failing
## this: the SAME requested displacement against the SAME geometry resolves one way for a
## behavioural leash and the opposite way for the two hard sources.
func test_the_three_confinement_sources_resolve_differently() -> void:
	var region: Array[Rect2] = [HOME]

	before_each()
	_arm_player(Vector3(4.0, 0.0, 0.0))
	_add_ooze(Vector3(1.8, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, region)
	_bump()
	var ambient_crossed: bool = not _home_bounds().fits(sim.entities[ENEMY], RADIUS)

	before_each()
	_arm_player(Vector3(4.0, 0.0, 0.0))
	_add_ooze(Vector3(1.8, 0.0, 0.0), FloorLayers.ROLE_MANDATORY, region, true)
	_bump()
	var seal_crossed: bool = not _home_bounds().fits(sim.entities[ENEMY], RADIUS)

	assert_true(ambient_crossed, "an ambient leash MAY be crossed by force")
	assert_false(seal_crossed, "a seal may NOT -- same geometry, same bump, opposite result")


# --- THE P33 DETECTOR MUST NOT SEE A LEASH AS AN OBSTACLE -----------------------------------

## This refactor changes what the AI ASKS FOR at a home edge, so it could plausibly disturb the
## obstruction detector that reads those requests. Territory is not geometry: the detector must
## stay quiet at a leash edge in open floor, and must still fire on real geometry.
func test_the_obstruction_detector_ignores_a_leash_edge_but_not_a_real_wall() -> void:
	var ambient: Array[Rect2] = [HOME]
	_arm_player(Vector3(-12.0, 0.0, 0.0))
	_add_ooze(Vector3(1.6, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, ambient)
	assert_true(sim._direct_route_obstruction(ENEMY, Vector3(-12.0, 0.0, 0.0)).is_empty(),
		"a behavioural boundary in open floor is NOT a physical obstruction")

	# The same actor, same heading, with real geometry in the way instead.
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var split: Array[Rect2] = [Rect2(0.0, -10.0, 20.0, 20.0), Rect2(-40.0, -10.0, 15.0, 20.0)]
	sim.load_floor(WalkableBounds.new(split), Vector3.ZERO)
	sim.register_patches(split)
	_arm_player(Vector3(-30.0, 0.0, 0.0))
	_add_ooze(Vector3(1.6, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, [Rect2(0.0, -10.0, 20.0, 20.0)] as Array[Rect2])
	assert_false(sim._direct_route_obstruction(ENEMY, Vector3(-30.0, 0.0, 0.0)).is_empty(),
		"a real gap in the floor IS an obstruction, and must still be seen")


# --- THE HOME-POINT TIE RULE ---------------------------------------------------------------

## Two equally distant body-valid home rects. The winner must be the earlier authored one, on
## every run -- a determinism rule for degenerate geometry, carrying no gameplay meaning.
func test_equidistant_home_candidates_resolve_on_authored_order() -> void:
	var chosen: Array = []
	for attempt in 2:
		sim = SimWorld.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		var rects: Array[Rect2] = [Rect2(-30.0, -20.0, 60.0, 40.0)]
		sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
		sim.register_patches(rects)
		# Symmetric about x = 0. The actor is BOUND while legally inside the first rect, then
		# moved to the exact midpoint -- binding outside a site is refused, and rightly so.
		var twin: Array[Rect2] = [Rect2(-20.0, -8.0, 10.0, 16.0), Rect2(10.0, -8.0, 10.0, 16.0)]
		_arm_player(Vector3(0.0, 0.0, 18.0))
		_add_ooze(Vector3(-15.0, 0.0, 0.0), FloorLayers.ROLE_AMBIENT, twin)
		sim.entities[ENEMY] = Vector3(0.0, 0.0, 0.0)
		chosen.append(sim._nearest_home_point(ENEMY))
	assert_eq(chosen[0], chosen[1], "identical state must choose the identical home point")
	assert_lt(float(chosen[0].x), 0.0, "and it must be the FIRST authored rect on an exact tie")


# --- THE MECHANICAL REVISIT TRIGGER — FIRED, AND RETIRED 2026-09-03 -------------------------
#
# It existed to catch the day role stopped being a sufficient proxy for hard confinement, and it
# named the fix: "activation/seal state must become authoritative". That day came, by a road the
# trigger could not watch. It tested for a non-ambient roster spawning AT FLOOR LOAD; Floor 2
# instead authored an OPTIONAL, NON-SEALING encounter that activates mid-floor. The roster was
# walled in behind a door the player could walk through, and the same invisible walls killed a
# burrowing Fang by refusing every emergence candidate.
#
# The proxy is gone: _hard_encounter_confinement_applies now reads live seal state directly, so
# there is nothing left for this guard to warn about. Deleted rather than left passing -- its
# failure message gives instructions that are already carried out, and a guard whose stated
# reason is false teaches the next reader something untrue.
#
# WHAT REPLACES IT is not another proxy check but the behaviour itself, in
# tests/test_doorway_pursuit.gd: an unsealed roster follows the player through an open door, a
# sealing one does not, and the two differ ONLY in whether the encounter seals -- role held
# constant across both halves so it cannot silently become the deciding factor again.
