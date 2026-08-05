extends GutTest
## Forward lunge (manual-pass, GAME-RULES §3): deterministic authored sim movement,
## distributed evenly over lunge_duration_ticks -- never instantaneous displacement,
## never physics momentum. Backward-compat is pinned by an all-zero-fields swing
## still resolving synchronously on the release tick, exactly as before this change.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"test_lunge_sword"
const TARGET_FAMILY := &"test_target"

const LUNGE_DISTANCE := 3.0
const LUNGE_DURATION_TICKS := 6
const HIT_ACTIVE_TICKS := 4
const FIRE_INTERVAL_TICKS := 5


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(TARGET_ID, Vector3(0.3, 0, -1), 0.0)
	sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var combo_profiles: Array[Dictionary] = [
		_profile(5.0, LUNGE_DISTANCE, LUNGE_DURATION_TICKS, HIT_ACTIVE_TICKS, FIRE_INTERVAL_TICKS),
		_profile(5.0),
		_profile(5.0),
	]
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), 999, 50)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _profile(damage: float, lunge_distance: float = 0.0, lunge_duration_ticks: int = 0, hit_active_ticks: int = 0, fire_interval_ticks: int = 0) -> Dictionary:
	return {
		"damage": damage,
		"damage_type": &"force",
		"reach": 2.0,
		"cone_half_angle_degrees": 60.0,
		"knockback_distance": 0.0,
		"fire_interval_ticks": fire_interval_ticks,
		"status_id": &"",
		"status_proc_chance": 0.0,
		"interrupt_strength": 0,
		"lunge_distance": lunge_distance,
		"lunge_duration_ticks": lunge_duration_ticks,
		"hit_active_ticks": hit_active_ticks,
		"windup_ticks": 0,
	}


func _press(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "pressed"})], 1.0 / 30.0)


func _release(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "released"})], 1.0 / 30.0)


func _tap(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	_press(aim)
	return _release(aim)


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _hit_events(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "hit")


func test_lunge_displaces_actor_by_authored_distance_over_duration_ticks() -> void:
	_tap(Vector3(0, 0, -1))
	for _i in range(LUNGE_DURATION_TICKS - 1):
		_tick_noop()
	assert_almost_eq(sim.entities[ATTACKER_ID].z, -LUNGE_DISTANCE, 0.01)


func test_lunge_distributes_evenly_across_duration_ticks() -> void:
	_tap(Vector3(0, 0, -1))  # 1st lunge tick already applied synchronously on release
	var per_tick_step: float = LUNGE_DISTANCE / LUNGE_DURATION_TICKS
	var position_after_first_tick: float = sim.entities[ATTACKER_ID].z
	assert_almost_eq(position_after_first_tick, -per_tick_step, 0.01)
	_tick_noop()
	var position_after_second_tick: float = sim.entities[ATTACKER_ID].z
	assert_almost_eq(position_after_second_tick - position_after_first_tick, -per_tick_step, 0.01)


## Uses "melee_swing" (always fires exactly when resolution happens) rather than
## "hit" (target-dependent -- by hit_tick the lunge has already carried the attacker
## partway toward/past a close target, which is a target-sweep concern, not a timing
## one) to isolate WHEN resolution occurs from whether anything was actually hit.
func test_swing_resolves_at_execution_start_plus_hit_active_ticks() -> void:
	var release_events: Array[Event] = _tap(Vector3(0, 0, -1))
	assert_eq(release_events.filter(func(e): return e.kind == "melee_swing").size(), 0, "swing must not resolve on the release tick when hit_active_ticks > 0")
	var events: Array[Event] = []
	for _i in range(HIT_ACTIVE_TICKS - 1):
		events = _tick_noop()
		assert_eq(events.filter(func(e): return e.kind == "melee_swing").size(), 0, "swing must not resolve before hit_active_ticks elapse")
	events = _tick_noop()
	assert_eq(events.filter(func(e): return e.kind == "melee_swing").size(), 1, "swing must resolve exactly hit_active_ticks after execution start")


func test_all_zero_fields_resolves_hit_on_the_same_tick_as_release() -> void:
	var flat_sim := SimWorld.new()
	flat_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	flat_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	flat_sim.add_entity(TARGET_ID, Vector3(0.3, 0, -1), 0.0)
	flat_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	flat_sim.set_damage_matrix({}, 1.5, 0.5)
	var combo_profiles: Array[Dictionary] = [_profile(5.0), _profile(5.0), _profile(5.0)]
	flat_sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), 999, 50)
	flat_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	flat_sim.tick([Command.new(flat_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], 1.0 / 30.0)
	var events := flat_sim.tick([Command.new(flat_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "hit").size(), 1, "an all-zero-fields swing must still resolve its hit on the same tick as release")


func test_movement_is_suppressed_while_executing() -> void:
	_tap(Vector3(0, 0, -1))
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.RIGHT})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "moved").size(), 0, "no moved Event while executing")
	assert_almost_eq(sim.entities[ATTACKER_ID].x, 0.0, 0.001, "WASD input must not displace the actor during the lunge")


func test_movement_resumes_after_lunge_completes() -> void:
	_tap(Vector3(0, 0, -1))
	for _i in range(LUNGE_DURATION_TICKS):
		_tick_noop()
	assert_false(sim._melee_hold.has(ATTACKER_ID), "sanity: the record must have naturally completed")
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.RIGHT})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "moved").size(), 1, "movement must resume once the lunge naturally completes")


func test_combo_advances_only_at_the_hit_active_tick_not_at_release() -> void:
	_tap(Vector3(0, 0, -1))
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 0, "combo index must not advance before the hit-active tick")
	for _i in range(HIT_ACTIVE_TICKS - 1):
		_tick_noop()
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 0, "still not advanced -- one tick short of hit_active_ticks")
	_tick_noop()  # this is the hit-active tick
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 1, "combo index must advance exactly at the hit-active tick")


func test_natural_completion_arms_cooldown_from_end_tick_not_release_tick() -> void:
	var tick_before_press: int = sim.tick_count
	_tap(Vector3(0, 0, -1))
	var execution_start_tick: int = tick_before_press + 1  # press consumes tick_before_press, release is the next tick
	for _i in range(LUNGE_DURATION_TICKS):
		_tick_noop()
	var expected_end_tick: int = execution_start_tick + LUNGE_DURATION_TICKS
	assert_eq(sim._next_fire_tick[ATTACKER_ID], expected_end_tick + FIRE_INTERVAL_TICKS)


func test_hit_active_ticks_greater_than_lunge_duration_is_clamped() -> void:
	var clamped_sim := SimWorld.new()
	clamped_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	clamped_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	clamped_sim.add_entity(TARGET_ID, Vector3(0.3, 0, -1), 0.0)
	clamped_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	clamped_sim.set_damage_matrix({}, 1.5, 0.5)
	# hit_active_ticks(10) > lunge_duration_ticks(3) -- an authoring mistake that
	# must be clamped, never silently lose the hit entirely.
	var combo_profiles: Array[Dictionary] = [_profile(5.0, 0.0, 3, 10), _profile(5.0), _profile(5.0)]
	clamped_sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), 999, 50)
	clamped_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	clamped_sim.tick([Command.new(clamped_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], 1.0 / 30.0)
	var release_events := clamped_sim.tick([Command.new(clamped_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], 1.0 / 30.0)
	var all_events: Array[Event] = release_events.duplicate()
	for _i in range(5):
		all_events.append_array(clamped_sim.tick([], 1.0 / 30.0))
	var hits := all_events.filter(func(e): return e.kind == "hit")
	assert_eq(hits.size(), 1, "the hit must still resolve (clamped to lunge_duration_ticks), not be silently lost")


func test_lunge_sequence_is_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
		local_sim.add_entity(TARGET_ID, Vector3(0.3, 0, -1), 0.0)
		local_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		var combo_profiles: Array[Dictionary] = [_profile(5.0, LUNGE_DISTANCE, LUNGE_DURATION_TICKS, HIT_ACTIVE_TICKS, FIRE_INTERVAL_TICKS), _profile(5.0), _profile(5.0)]
		local_sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), 999, 50)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], 1.0 / 30.0)
		for _j in range(LUNGE_DURATION_TICKS + 5):
			local_sim.tick([], 1.0 / 30.0)
		results.append({"health": local_sim._health[TARGET_ID], "position": local_sim.entities[ATTACKER_ID], "combo_index": local_sim._combo_index.get(ATTACKER_ID, 0)})
	assert_eq(results[0], results[1], "an identical lunge sequence must produce identical sim state")
