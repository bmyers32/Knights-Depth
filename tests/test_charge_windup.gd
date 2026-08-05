extends GutTest
## Charge windup (manual-pass, GAME-RULES §3): a delay between a charged release and
## the strike actually firing. Direction locks at release and never re-tracks;
## origin resamples at windup-end ("direction locked, origin moves"). Free movement
## continues through the windup -- only "executing" suppresses it.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"test_windup_sword"
const TARGET_FAMILY := &"test_target"

const CHARGE_THRESHOLD := 5
const WINDUP_TICKS := 6
const CHARGE_HIT_ACTIVE_TICKS := 2
const CHARGE_LUNGE_DURATION_TICKS := 3
const CHARGE_LUNGE_DISTANCE := 3.0


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(TARGET_ID, Vector3(0, 0, -1), 0.0)
	sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var combo_profiles: Array[Dictionary] = [_flat_profile(5.0), _flat_profile(5.0), _flat_profile(5.0)]
	var charge_profile: Dictionary = _flat_profile(20.0)
	charge_profile.windup_ticks = WINDUP_TICKS
	charge_profile.hit_active_ticks = CHARGE_HIT_ACTIVE_TICKS
	charge_profile.lunge_duration_ticks = CHARGE_LUNGE_DURATION_TICKS
	# lunge_distance deliberately stays 0.0 here (the shared default) -- several
	# other tests in this file place the target at a fixed reach-sensitive position
	# that assumes no lunge overshoot during "executing". Only the one test that
	# specifically verifies lunge composition re-registers a nonzero distance for
	# itself (see test_charge_windup_then_lunge_composes_correctly).
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, charge_profile, CHARGE_THRESHOLD, 50)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _flat_profile(damage: float) -> Dictionary:
	return {
		"damage": damage,
		"damage_type": &"force",
		"reach": 2.0,
		"cone_half_angle_degrees": 60.0,
		"knockback_distance": 0.0,
		"fire_interval_ticks": 0,
		"status_id": &"",
		"status_proc_chance": 0.0,
		"interrupt_strength": 0,
		"lunge_distance": 0.0,
		"lunge_duration_ticks": 0,
		"hit_active_ticks": 0,
		"windup_ticks": 0,
	}


func _press(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "pressed"})], 1.0 / 30.0)


func _hold(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "held"})], 1.0 / 30.0)


func _release(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "released"})], 1.0 / 30.0)


func _hold_n_ticks(n: int, aim: Vector3 = Vector3.ZERO) -> void:
	for _i in range(n):
		_hold(aim)


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _swing_events(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "melee_swing")


func _charge_to_release(aim: Vector3 = Vector3(0, 0, -1)) -> void:
	_press(aim)
	_hold_n_ticks(CHARGE_THRESHOLD, aim)
	_release(aim)


func test_charged_release_enters_windup_before_resolving() -> void:
	_press(Vector3(0, 0, -1))
	_hold_n_ticks(CHARGE_THRESHOLD, Vector3(0, 0, -1))
	var events := _release(Vector3(0, 0, -1))
	assert_eq(_swing_events(events).size(), 0, "no swing on the release tick -- windup must delay resolution")
	assert_eq(sim._melee_hold[ATTACKER_ID].state, "windup")


func test_charged_hit_resolves_after_windup_plus_hit_active_ticks() -> void:
	_charge_to_release()
	var total_delay: int = WINDUP_TICKS + CHARGE_HIT_ACTIVE_TICKS
	var events: Array[Event] = []
	for _i in range(total_delay - 1):
		events = _tick_noop()
		assert_eq(_swing_events(events).size(), 0, "swing must not resolve before windup_ticks + hit_active_ticks elapse")
	events = _tick_noop()
	assert_eq(_swing_events(events).size(), 1, "swing must resolve exactly windup_ticks + hit_active_ticks after release")


func test_windup_aim_is_locked_and_does_not_re_track() -> void:
	# Release aimed directly at the target (0,0,-1). During windup, move in a
	# direction that would change _facings if aim tracked movement -- it must not.
	_press(Vector3(0, 0, -1))
	_hold_n_ticks(CHARGE_THRESHOLD, Vector3(0, 0, -1))
	_release(Vector3(0, 0, -1))
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.RIGHT})], 1.0 / 30.0)
	var all_events: Array[Event] = []
	for _i in range(WINDUP_TICKS + CHARGE_HIT_ACTIVE_TICKS + 5):
		all_events.append_array(_tick_noop())
	var hits := all_events.filter(func(e): return e.kind == "hit")
	assert_eq(hits.size(), 1, "the strike must still land on the target directly ahead -- aim never re-tracked toward the RIGHT move")


func test_windup_origin_resamples_at_windup_end_not_release_position() -> void:
	# Target at a FIXED position, deliberately just outside reach(2.0) from the
	# release position (distance 2.5) but within reach from where free movement
	# during the windup will carry the attacker (5 ticks * 4.0 speed * 1/30 dt ~=
	# 0.667 forward -> distance ~1.83). A frozen-at-release origin would miss; a
	# correctly resampled-at-windup-end origin must hit. (A prior version of this
	# test placed the target relative to the attacker's own live position, which
	# could never fail regardless of whether resampling was correct -- fixed here.)
	sim.entities[TARGET_ID] = Vector3(0, 0, -2.5)
	_press(Vector3(0, 0, -1))
	_hold_n_ticks(CHARGE_THRESHOLD, Vector3(0, 0, -1))
	_release(Vector3(0, 0, -1))
	for _i in range(WINDUP_TICKS - 1):
		sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3(0, 0, -1)})], 1.0 / 30.0)  # walks toward -Z, closing the gap
	var all_events: Array[Event] = []
	for _i in range(CHARGE_HIT_ACTIVE_TICKS + 5):
		all_events.append_array(_tick_noop())
	var hits := all_events.filter(func(e): return e.kind == "hit")
	assert_eq(hits.size(), 1, "the strike must use the post-windup position, not the far-away release position")


func test_free_movement_during_windup_is_unobstructed() -> void:
	_press(Vector3(0, 0, -1))
	_hold_n_ticks(CHARGE_THRESHOLD, Vector3(0, 0, -1))
	_release(Vector3(0, 0, -1))
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.RIGHT})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "moved").size(), 1, "movement must be unobstructed during windup")
	assert_gt(sim.entities[ATTACKER_ID].x, 0.0, "the attacker must actually have moved during windup")


## Regression note (post-implementation review): an earlier version of this test
## left the charge profile's lunge_distance at 0.0, so it verified zero actual
## displacement regardless of whether windup->executing composition was correct.
## Re-registers locally with a nonzero CHARGE_LUNGE_DISTANCE rather than changing
## before_each's shared setup -- several OTHER tests in this file place the target
## at a fixed reach-sensitive position that assumes no lunge overshoot during
## "executing"; giving every test a real lunge broke them via the same overshoot
## dynamic this file's own aim-lock/origin-resample tests are careful to avoid.
func test_charge_windup_then_lunge_composes_correctly() -> void:
	var combo_profiles: Array[Dictionary] = [_flat_profile(5.0), _flat_profile(5.0), _flat_profile(5.0)]
	var charge_profile: Dictionary = _flat_profile(20.0)
	charge_profile.windup_ticks = WINDUP_TICKS
	charge_profile.hit_active_ticks = CHARGE_HIT_ACTIVE_TICKS
	charge_profile.lunge_duration_ticks = CHARGE_LUNGE_DURATION_TICKS
	charge_profile.lunge_distance = CHARGE_LUNGE_DISTANCE
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, charge_profile, CHARGE_THRESHOLD, 50)
	_charge_to_release()
	var position_before_transition: Vector3 = sim.entities[ATTACKER_ID]
	for _i in range(WINDUP_TICKS):
		_tick_noop()
	# The transition tick ALSO applies its first lunge step (falls through within
	# _advance_pending_attacks in the same iteration), so exactly one step must have
	# applied, starting from the windup-end position (== position_before_transition
	# here, since no free movement happened in this test).
	assert_eq(sim._melee_hold[ATTACKER_ID].state, "executing")
	var per_tick_step: float = CHARGE_LUNGE_DISTANCE / CHARGE_LUNGE_DURATION_TICKS
	assert_almost_eq(sim.entities[ATTACKER_ID].z, position_before_transition.z - per_tick_step, 0.001, "the lunge must advance from the windup-end position by exactly one step")
	assert_almost_eq(sim.entities[ATTACKER_ID].x, position_before_transition.x, 0.001, "sanity: no lateral drift -- aim is locked straight down -Z")


func test_zero_windup_ticks_charge_resolves_like_a_tap() -> void:
	var flat_sim := SimWorld.new()
	flat_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	flat_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	flat_sim.add_entity(TARGET_ID, Vector3(0, 0, -1), 0.0)
	flat_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	flat_sim.set_damage_matrix({}, 1.5, 0.5)
	var combo_profiles: Array[Dictionary] = [_flat_profile(5.0), _flat_profile(5.0), _flat_profile(5.0)]
	flat_sim.register_melee_profiles(WEAPON_ID, combo_profiles, _flat_profile(20.0), CHARGE_THRESHOLD, 50)  # charge_profile has windup_ticks=0
	flat_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	flat_sim.tick([Command.new(flat_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], 1.0 / 30.0)
	for _i in range(CHARGE_THRESHOLD):
		flat_sim.tick([Command.new(flat_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "held"})], 1.0 / 30.0)
	var events := flat_sim.tick([Command.new(flat_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "hit").size(), 1, "a charge with windup_ticks=0 must resolve on the release tick, exactly like a tap")


func test_charge_windup_sequence_is_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
		local_sim.add_entity(TARGET_ID, Vector3(0, 0, -1), 0.0)
		local_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		var combo_profiles: Array[Dictionary] = [_flat_profile(5.0), _flat_profile(5.0), _flat_profile(5.0)]
		var charge_profile: Dictionary = _flat_profile(20.0)
		charge_profile.windup_ticks = WINDUP_TICKS
		charge_profile.hit_active_ticks = CHARGE_HIT_ACTIVE_TICKS
		local_sim.register_melee_profiles(WEAPON_ID, combo_profiles, charge_profile, CHARGE_THRESHOLD, 50)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], 1.0 / 30.0)
		for _j in range(CHARGE_THRESHOLD):
			local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "held"})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], 1.0 / 30.0)
		for _j in range(WINDUP_TICKS + CHARGE_HIT_ACTIVE_TICKS + 5):
			local_sim.tick([], 1.0 / 30.0)
		results.append({"health": local_sim._health[TARGET_ID], "combo_index": local_sim._combo_index.get(ATTACKER_ID, 0)})
	assert_eq(results[0], results[1], "an identical charge/windup sequence must produce identical sim state")
