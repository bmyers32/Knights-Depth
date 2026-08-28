extends GutTest
## RUN vs FLOOR state law (M2 Slice 1), and the scanner that keeps it honest.
##
## THE SCANNER is the load-bearing test: it enumerates SimWorld's script variables and fails
## on any that STATE_SCOPES does not classify, so new sim state must declare its lifetime or
## break the build. Everything else here asserts what the classification actually DOES, since
## a table nobody executes is documentation, not law -- and load_floor() iterates that same
## table rather than carrying a second hand-written cleanup list, so the two cannot drift.
##
## FLOOR-TRANSITION LAW (Breon, 2026-08-28): a floor transition is an ENCOUNTER BOUNDARY,
## deliberately unlike burrow (temporary non-participation INSIDE one encounter). Durable run
## progression carries; transient combat effects do not.

const PLAYER_ID := 0
const ENEMY_ID := 1
const OTHER_ENEMY_ID := 2
const DT := 1.0 / 30.0

var sim: SimWorld


func _floor_a() -> WalkableBounds:
	var rects: Array[Rect2] = [Rect2(-10.0, -10.0, 20.0, 20.0)]
	return WalkableBounds.new(rects)


func _floor_b() -> WalkableBounds:
	var rects: Array[Rect2] = [Rect2(-14.0, -8.0, 28.0, 16.0)]
	return WalkableBounds.new(rects)


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)


# --- THE SCANNER ---------------------------------------------------------------------

func _script_variable_names() -> Array:
	var names: Array = []
	for property in sim.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(String(property.name))
	return names


## Every mutable script-owned state collection must declare a scope. This is the mechanism
## that makes the law survive future sessions: add a `var _something := {}` to SimWorld and
## this goes red until it is classified.
func test_every_sim_state_collection_declares_a_scope() -> void:
	var unclassified: Array = []
	for name in _script_variable_names():
		if not SimWorld.STATE_SCOPES.has(name):
			unclassified.append(name)
	assert_eq(unclassified, [],
		"SimWorld state without a STATE_SCOPES entry: %s -- classify it RUN / FLOOR / RUN_ACTOR / ACTOR_TRANSIENT, because load_floor() drives off that table" % [unclassified])


## The reverse direction: a stale entry for state that no longer exists would quietly stop
## being cleared while still reading as covered.
func test_no_scope_entry_names_state_that_no_longer_exists() -> void:
	var names: Array = _script_variable_names()
	var stale: Array = []
	for declared in SimWorld.STATE_SCOPES.keys():
		if not names.has(declared):
			stale.append(declared)
	assert_eq(stale, [], "STATE_SCOPES names state SimWorld no longer has: %s" % [stale])


func test_every_declared_scope_is_a_known_scope() -> void:
	var valid: Array = [SimWorld.SCOPE_RUN, SimWorld.SCOPE_FLOOR, SimWorld.SCOPE_RUN_ACTOR, SimWorld.SCOPE_ACTOR_TRANSIENT]
	for state_name in SimWorld.STATE_SCOPES:
		assert_true(valid.has(SimWorld.STATE_SCOPES[state_name]),
			"'%s' declares an unknown scope '%s'" % [state_name, SimWorld.STATE_SCOPES[state_name]])


## DISCRIMINATION CHECK. A scanner that can only pass is worse than no scanner, because it
## also reports success for the case it exists to catch. Proves the coverage check reacts to
## an unclassified name rather than being vacuously true.
func test_the_scanner_can_actually_fail() -> void:
	var pretend_state: Array = _script_variable_names()
	pretend_state.append("_scratch_state_that_is_not_classified")
	var unclassified: Array = []
	for name in pretend_state:
		if not SimWorld.STATE_SCOPES.has(name):
			unclassified.append(name)
	assert_eq(unclassified, ["_scratch_state_that_is_not_classified"],
		"the coverage check must detect an unclassified collection, or every assertion above is vacuous")


# --- FULL ROSTER REPLACEMENT ---------------------------------------------------------

func _build_populated_floor(bounds: WalkableBounds, entry: Vector3) -> void:
	sim.load_floor(bounds, entry)
	for enemy_id in [ENEMY_ID, OTHER_ENEMY_ID]:
		sim.add_entity(enemy_id, Vector3(float(enemy_id), 0.0, -3.0), 3.0)
		sim.register_combatant(enemy_id, 40.0, &"fang", 0, 0.6, &"enemy")
		sim.register_flinch_profile(enemy_id, 16.0)
		sim.register_ai(enemy_id, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 10),
			Vector3(float(enemy_id), 0.0, -3.0), 1.5, 0.0, 60.0, 200.0)


func _register_player() -> void:
	sim.add_entity(PLAYER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(PLAYER_ID, 100.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(PLAYER_ID)
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 0)
	sim.register_shield(PLAYER_ID, 100.0, 1.0, 30, 1.5)


func test_the_envoy_survives_a_floor_transition_and_the_whole_roster_does_not() -> void:
	_register_player()
	_build_populated_floor(_floor_a(), Vector3.ZERO)
	assert_true(sim.entities.has(ENEMY_ID), "sanity: floor A had enemies")

	sim.load_floor(_floor_b(), Vector3(0.0, 0.0, 5.0))

	assert_true(sim.entities.has(PLAYER_ID), "the Envoy is the one actor that outlives a floor")
	for enemy_id in [ENEMY_ID, OTHER_ENEMY_ID]:
		assert_false(sim.entities.has(enemy_id), "enemy %d must cease to exist" % enemy_id)
		assert_false(sim._health.has(enemy_id), "enemy %d health must not survive" % enemy_id)
		assert_false(sim._families.has(enemy_id), "enemy %d family must not survive" % enemy_id)
		assert_false(sim._ai_state.has(enemy_id), "enemy %d AI state must not survive" % enemy_id)
		assert_false(sim._ai_repertoire.has(enemy_id), "enemy %d repertoire must not survive" % enemy_id)
		assert_false(sim._ai_spawn_position.has(enemy_id), "enemy %d leash anchor must not survive" % enemy_id)
		assert_false(sim._flinch_thresholds.has(enemy_id), "enemy %d reaction profile must not survive" % enemy_id)


## Actor-keyed state is pruned per ACTOR, not per collection: the same dictionaries that lose
## every enemy entry keep the Envoy's.
func test_no_actor_keyed_state_of_a_departed_floor_survives_anywhere() -> void:
	_register_player()
	_build_populated_floor(_floor_a(), Vector3.ZERO)
	sim.load_floor(_floor_b(), Vector3(0.0, 0.0, 5.0))

	var leaked: Array = []
	for state_name in SimWorld.STATE_SCOPES:
		var value: Variant = sim.get(state_name)
		if not (value is Dictionary):
			continue
		for enemy_id in [ENEMY_ID, OTHER_ENEMY_ID]:
			if (value as Dictionary).has(enemy_id):
				leaked.append("%s[%d]" % [state_name, enemy_id])
	assert_eq(leaked, [], "old-floor actors still have state in: %s" % [leaked])


func test_the_envoy_is_repositioned_to_the_new_entry_point() -> void:
	_register_player()
	sim.load_floor(_floor_a(), Vector3.ZERO)
	for i in 20:
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3(1, 0, 0)})] as Array[Command], DT)
	assert_gt(sim.entities[PLAYER_ID].x, 1.0, "sanity: the Envoy walked somewhere on floor A")

	sim.load_floor(_floor_b(), Vector3(3.0, 0.0, 5.0))
	assert_eq(sim.entities[PLAYER_ID], Vector3(3.0, 0.0, 5.0), "the Envoy arrives at the new floor's entry point")


func test_the_new_floor_installs_its_own_bounds() -> void:
	_register_player()
	sim.load_floor(_floor_a(), Vector3.ZERO)
	assert_true(sim._bounds.is_inside(Vector3(0.0, 0.0, -9.0)), "sanity: legal on floor A")
	sim.load_floor(_floor_b(), Vector3.ZERO)
	assert_false(sim._bounds.is_inside(Vector3(0.0, 0.0, -9.0)), "floor B is shallower -- its own bounds must apply")
	assert_true(sim._bounds.is_inside(Vector3(-13.0, 0.0, 0.0)), "and wider")


# --- WHAT CARRIES ---------------------------------------------------------------------

func test_durable_envoy_run_state_carries_across_the_boundary() -> void:
	_register_player()
	sim.load_floor(_floor_a(), Vector3.ZERO)
	sim.set_weapon_loadout(PLAYER_ID, [&"test_bite"] as Array[StringName])
	sim.set_equipped_weapon(PLAYER_ID, &"test_bite")
	sim.debug_override_health(PLAYER_ID, 37.0)

	sim.load_floor(_floor_b(), Vector3.ZERO)

	assert_eq(sim._health[PLAYER_ID], 37.0, "attrition is the point of a run -- health carries")
	assert_eq(sim._equipped_weapon[PLAYER_ID], "test_bite", "equipment carries")
	assert_true(sim._weapon_loadouts.has(PLAYER_ID), "the loadout carries")
	assert_true(sim._shields.has(PLAYER_ID), "shield configuration carries")
	assert_eq(sim._families[PLAYER_ID], &"envoy", "identity carries")
	assert_eq(sim._allegiance[PLAYER_ID], &"player", "allegiance carries")


## SHIELD RULING: no floor-load refill. The meter carries at whatever value ordinary play
## left it, and the existing continuous regeneration remains the sole recovery authority --
## a transition must not become a stealth heal, and clearing the meter would be a stealth
## nerf (it defaults to 0.0).
func test_a_floor_transition_neither_refills_nor_empties_the_shield() -> void:
	_register_player()
	sim.load_floor(_floor_a(), Vector3.ZERO)
	sim._shield_meter[PLAYER_ID] = 42.0

	sim.load_floor(_floor_b(), Vector3.ZERO)

	assert_eq(sim._shield_meter[PLAYER_ID], 42.0, "the meter must be exactly what play left it")

	# ...and ordinary regeneration still works afterwards, unchanged.
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "block", {"held": false})] as Array[Command], DT)
	assert_eq(sim._shield_meter[PLAYER_ID], 43.0, "the one existing recovery law still applies on the new floor")


func test_the_clock_never_resets_mid_run() -> void:
	_register_player()
	sim.load_floor(_floor_a(), Vector3.ZERO)
	for i in 25:
		sim.tick([] as Array[Command], DT)
	var before: int = sim.tick_count
	sim.load_floor(_floor_b(), Vector3.ZERO)
	assert_eq(sim.tick_count, before,
		"tick_count is the run clock -- resetting it would make every stale absolute-tick deadline instantly satisfied")


func test_run_scoped_content_registration_survives() -> void:
	_register_player()
	sim.register_status(&"burn", 1.0, 5, 60)
	sim.set_status_priority({"burn": 1})
	sim.load_floor(_floor_a(), Vector3.ZERO)
	sim.load_floor(_floor_b(), Vector3.ZERO)
	assert_true(sim._weapons.has("test_bite"), "content tables are keyed by content id, not actor -- they persist")
	assert_true(sim._status_config.has("burn"), "status definitions persist")
	assert_false(sim._matrix_families.is_empty() and sim._matrix_weak_multiplier != 1.5, "the damage matrix persists")


## Ids are never reused within a run, so one run's event log stays unambiguous even though
## the projectile table itself is floor-scoped.
func test_projectile_ids_stay_monotonic_across_floors() -> void:
	_register_player()
	sim.load_floor(_floor_a(), Vector3.ZERO)
	sim.register_gun(&"test_gun", 5.0, &"force", 10.0, 60, 0.2, 0.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"test_gun")
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	var next_id_before: int = sim._next_projectile_id
	assert_gt(next_id_before, 0, "sanity: a projectile was actually created")

	sim.load_floor(_floor_b(), Vector3.ZERO)
	assert_eq(sim._next_projectile_id, next_id_before, "the id counter must not rewind")


# --- WHAT RESETS ----------------------------------------------------------------------

## STATUSES DO NOT CROSS A FLOOR BOUNDARY. Ruled explicitly: a completed floor is a combat
## episode boundary, unlike burrow's temporary non-participation within one encounter.
func test_active_statuses_do_not_survive_a_floor_transition() -> void:
	_register_player()
	sim.register_status(&"burn", 1.0, 5, 600)
	sim.set_status_priority({"burn": 1})
	sim.load_floor(_floor_a(), Vector3.ZERO)
	sim._apply_status(PLAYER_ID, &"burn", "test", PLAYER_ID, "test_bite")
	assert_true(sim._status_instances.has(PLAYER_ID), "sanity: the Envoy is burning")

	sim.load_floor(_floor_b(), Vector3.ZERO)
	assert_false(sim._status_instances.has(PLAYER_ID),
		"Burn must not follow the Envoy onto the next floor -- transient combat effects end with their encounter")


func test_transient_combat_state_is_cleared_for_the_envoy_too() -> void:
	_register_player()
	sim.load_floor(_floor_a(), Vector3.ZERO)
	# Hand-seed each transient collection: this asserts the CLASSIFICATION, independently of
	# whichever mechanic happens to populate it today.
	sim._iframe_ticks_remaining[PLAYER_ID] = 9
	sim._next_fire_tick[PLAYER_ID] = sim.tick_count + 500
	sim._combo_index[PLAYER_ID] = 2
	sim._combo_expire_tick[PLAYER_ID] = sim.tick_count + 40
	sim._melee_hold[PLAYER_ID] = {"state": "charging"}
	sim._melee_buffered_press[PLAYER_ID] = {"deadline_tick": 9999}
	sim._shield_state[PLAYER_ID] = "broken"
	sim._shield_break_ticks_remaining[PLAYER_ID] = 20
	sim._block_held_prev[PLAYER_ID] = true
	sim._block_start_tick[PLAYER_ID] = 3
	sim._shield_bump_ready_tick[PLAYER_ID] = 999
	sim._bump_slides[PLAYER_ID] = {"direction": Vector3.FORWARD}
	sim._parry_exposed_until_tick[PLAYER_ID] = 999
	sim._parry_exposed_damage_multiplier[PLAYER_ID] = 1.5
	sim._flinched_until_tick[PLAYER_ID] = 999
	sim._pressure_contributions[PLAYER_ID] = [[1, 5.0]]
	sim._combat_absent[PLAYER_ID] = true
	sim._ai_attack_start_tick[PLAYER_ID] = 1
	sim._ai_attack_fire_tick[PLAYER_ID] = 5

	sim.load_floor(_floor_b(), Vector3.ZERO)

	for state_name in SimWorld.STATE_SCOPES:
		if SimWorld.STATE_SCOPES[state_name] != SimWorld.SCOPE_ACTOR_TRANSIENT:
			continue
		var value: Variant = sim.get(state_name)
		assert_false((value as Dictionary).has(PLAYER_ID),
			"%s is ACTOR_TRANSIENT -- it must clear for the Envoy as well, not only for departed enemies" % state_name)
	# The shield state machine returns to neutral by DEFAULTING, which is why clearing it
	# introduces no second shield authority.
	assert_eq(sim._shield_state.get(PLAYER_ID, "ready"), "ready", "a broken shield does not stay broken across floors")


func test_in_flight_projectiles_die_with_their_floor() -> void:
	_register_player()
	sim.load_floor(_floor_a(), Vector3.ZERO)
	sim.register_gun(&"test_gun", 5.0, &"force", 10.0, 600, 0.2, 0.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"test_gun")
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	assert_false(sim._projectiles.is_empty(), "sanity: a shot is in flight")

	sim.load_floor(_floor_b(), Vector3.ZERO)
	assert_true(sim._projectiles.is_empty(), "a shot fired on the last floor must not arrive on this one")


func test_every_floor_scoped_collection_is_empty_after_a_transition() -> void:
	_register_player()
	_build_populated_floor(_floor_a(), Vector3.ZERO)
	for i in 10:
		sim.tick([] as Array[Command], DT)

	sim.load_floor(_floor_b(), Vector3(0.0, 0.0, 5.0))

	for state_name in SimWorld.STATE_SCOPES:
		if SimWorld.STATE_SCOPES[state_name] != SimWorld.SCOPE_FLOOR:
			continue
		var value: Variant = sim.get(state_name)
		if not (value is Dictionary):
			continue  # _bounds is assigned, not cleared
		assert_eq((value as Dictionary).size(), 0, "%s is FLOOR-scoped and must be empty after a transition" % state_name)


## The separate-streams law (GAME-RULES §1.3), asserted at the boundary that could break it:
## generation must not perturb combat rolls, and neither must floor count.
func test_floor_generation_never_perturbs_the_combat_rng() -> void:
	sim.seed_combat_rng(1234)
	var before: int = sim._combat_rng.state
	for depth in range(1, 6):
		DepthGenerator.generate(999, depth)
	sim.load_floor(_floor_a(), Vector3.ZERO)
	sim.load_floor(_floor_b(), Vector3.ZERO)
	assert_eq(sim._combat_rng.state, before,
		"generating floors must not advance the combat stream -- separate seeded streams per system")
