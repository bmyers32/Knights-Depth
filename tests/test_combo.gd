extends GutTest
## Slice B combo (GAME-RULES §3: 3-hit combo, per-hit content profiles) — the tap
## half of SimWorld's phased press/held/released attack model. See test_charge.gd
## for the hold-to-charge half and the interruption rules shared by both.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"test_combo_sword"
const TARGET_FAMILY := &"test_target"  # absent from the matrix -> multiplier always 1.0
const TARGET_POSITION := Vector3(0, 0, -1)  # directly ahead of the attacker's default facing

const CHARGE_THRESHOLD := 5
const COMBO_RESET := 10


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	# Ally-filtering (locked defect fix): the attacker needs an allegiance different
	# from the target's (default "enemy") or every attack below filters as allied.
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var combo_profiles: Array[Dictionary] = [_profile(5.0), _profile(5.0), _profile(5.0)]
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), CHARGE_THRESHOLD, COMBO_RESET)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _profile(damage: float, fire_interval_ticks: int = 0) -> Dictionary:
	return {
		"damage": damage,
		"damage_type": &"force",
		"reach": 2.0,
		"cone_half_angle_degrees": 60.0,
		"knockback_distance": 0.0,
		"fire_interval_ticks": fire_interval_ticks,
		"status_id": &"",
		"status_proc_chance": 0.0,
	}


func _press(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "pressed"})], 1.0 / 30.0)


func _release(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "released"})], 1.0 / 30.0)


## A quick tap: pressed then released on the very next tick, well under
## CHARGE_THRESHOLD -- always resolves as the current combo step.
func _tap(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	_press(aim)
	return _release(aim)


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _hit_events(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "hit")


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- Backward compatibility (locked contract: rewrite nothing) ---

func test_phaseless_attack_command_on_a_non_combo_weapon_still_resolves_instantly() -> void:
	var flat_sim := SimWorld.new()
	flat_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	flat_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	flat_sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	flat_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	flat_sim.register_weapon(&"flat_sword", 10.0, &"force", 2.0, 60.0, 0.0)
	flat_sim.set_equipped_weapon(ATTACKER_ID, &"flat_sword")
	flat_sim.set_damage_matrix({}, 1.5, 0.5)
	var events := flat_sim.tick([Command.new(flat_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "hit").size(), 1, "a phase-less Command must still resolve a non-combo weapon's swing on the same tick")


# --- Combo sequencing ---

func test_tap_tap_tap_resolves_steps_1_2_3_then_resets() -> void:
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1")
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "2")
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "3")
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1", "after hit 3 the sequence resets -- the next tap is hit 1 again")


func test_melee_swing_event_reports_weapon_id_and_profile_id_separately() -> void:
	_press()
	var events := _release()
	var swings := _events_of_kind(events, "melee_swing")
	assert_eq(swings.size(), 1)
	assert_eq(swings[0].payload.get("weapon_id"), String(WEAPON_ID), "profile identity must never substitute for the real weapon id")
	assert_eq(swings[0].payload.get("attack_profile_id"), "1")


func test_combo_advances_on_a_whiff_with_no_target_in_range() -> void:
	sim.entities[TARGET_ID] = Vector3(0, 0, -100)  # far outside reach
	var events := _tap()
	assert_eq(_hit_events(events).size(), 0, "sanity: this tap must not land a hit")
	assert_eq(_events_of_kind(events, "melee_swing")[0].payload.get("attack_profile_id"), "1")
	sim.entities[TARGET_ID] = TARGET_POSITION  # back in range for the next tap
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "2", "a whiff must still advance the combo step")


func test_combo_advances_even_when_the_swing_is_iframe_absorbed() -> void:
	# Long enough to absorb both taps below -- combo advancement is read from
	# melee_swing (emitted regardless of per-target outcome), not from "hit", since
	# neither tap is expected to land.
	sim._iframe_ticks_remaining[TARGET_ID] = 10
	var events := _tap()
	assert_eq(_events_of_kind(events, "attack_absorbed").size(), 1)
	assert_eq(_events_of_kind(events, "melee_swing")[0].payload.get("attack_profile_id"), "1")
	var next_events := _tap()
	assert_eq(_events_of_kind(next_events, "attack_absorbed").size(), 1, "sanity: still absorbed, so the profile-id check below isn't accidentally reading a real hit")
	assert_eq(_events_of_kind(next_events, "melee_swing")[0].payload.get("attack_profile_id"), "2", "an absorbed swing must still advance the combo step")


func test_combo_resets_after_long_inactivity() -> void:
	_tap()  # hit 1
	for _i in range(30):
		_tick_noop()
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1", "long inactivity beyond the reset window must restart the sequence")


func test_combo_persists_within_the_inactivity_window() -> void:
	_tap()  # hit 1
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "2", "tapping again immediately must continue the sequence")


# --- Cooldown / defensive guards ---

func test_pressed_is_rejected_while_on_cooldown() -> void:
	sim._next_fire_tick[ATTACKER_ID] = sim.tick_count + 100
	var events := _press()
	assert_eq(_events_of_kind(events, "attack_rejected").size(), 1)
	assert_eq(events[0].payload.get("reason"), "on_cooldown")
	assert_false(sim._melee_hold.has(ATTACKER_ID), "a rejected press must not open a hold")


func test_each_swing_arms_the_next_fire_tick_from_its_own_profiles_cooldown() -> void:
	var combo_profiles: Array[Dictionary] = [_profile(5.0, 4), _profile(5.0, 0), _profile(5.0, 0)]
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), CHARGE_THRESHOLD, COMBO_RESET)
	_tap()  # hit 1, fire_interval_ticks=4
	var immediate := _press()
	assert_eq(_events_of_kind(immediate, "attack_rejected").size(), 1, "hit 1's own cooldown must gate the very next press")


func test_second_pressed_while_already_holding_is_a_silent_noop() -> void:
	_press()
	var events := _press()  # shouldn't happen from correctly edge-detected input, but must not double-open or error
	assert_eq(events.size(), 0)
	assert_eq(_hit_events(_release()).size(), 1, "the original hold must still resolve normally")
