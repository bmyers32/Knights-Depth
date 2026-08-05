extends GutTest
## Manual-pass input buffer (GAME-RULES §3): a "pressed" arriving within
## input_buffer_ticks of the cooldown clearing is QUEUED (SimWorld._melee_buffered_
## press) instead of dropped outright, then automatically materializes into a real
## hold the tick the cooldown actually elapses (_advance_buffered_attacks).

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"test_buffer_sword"
const TARGET_FAMILY := &"test_target"
## Offset 0.3 off the X=0 lunge axis (manual-pass lunge-clamp addition): a target
## sitting EXACTLY on the attacker's straight-down--Z lunge path would now
## (correctly) clamp the lunge on contact -- these buffer-timing tests care about
## cooldown/materialization ticks, not the lunge-clamp mechanic, so the target stays
## reachable (well within reach=2.0) but off the exact swept line.
const TARGET_POSITION := Vector3(0.3, 0, -1)

const CHARGE_THRESHOLD := 20
const COMBO_RESET := 50
const INPUT_BUFFER_TICKS := 4
const HIT1_FIRE_INTERVAL := 10


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	sim.set_damage_matrix({}, 1.5, 0.5)
	# hit1 carries a real recovery window (HIT1_FIRE_INTERVAL) -- something to
	# actually buffer into; hits 2/3 and the charge stay uncapped so a materialized
	# hold's own release isn't gated by a second cooldown mid-test.
	var combo_profiles: Array[Dictionary] = [_profile(5.0, HIT1_FIRE_INTERVAL), _profile(5.0, 0), _profile(5.0, 0)]
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0, 0), CHARGE_THRESHOLD, COMBO_RESET, INPUT_BUFFER_TICKS)
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
		"interrupt_strength": 0,
	}


func _press(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "pressed"})], 1.0 / 30.0)


func _hold(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "held"})], 1.0 / 30.0)


func _release(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "released"})], 1.0 / 30.0)


func _tap(aim: Vector3 = Vector3.ZERO) -> Array[Event]:
	_press(aim)
	return _release(aim)


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _hit_events(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "hit")


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


## Advances noop ticks until exactly `remaining` ticks are left before ATTACKER_ID's
## cooldown clears -- avoids brittle hand-counted tick arithmetic in the tests below.
func _advance_until_remaining(remaining: int) -> void:
	while sim._next_fire_tick.get(ATTACKER_ID, 0) - sim.tick_count > remaining:
		_tick_noop()


func test_press_just_outside_buffer_window_is_still_rejected() -> void:
	_tap()  # hit1, arms the HIT1_FIRE_INTERVAL cooldown
	_advance_until_remaining(INPUT_BUFFER_TICKS + 1)
	var events := _press()
	assert_eq(_events_of_kind(events, "attack_rejected").size(), 1, "regression guard: outside the window, rejection is unchanged")
	assert_false(sim._melee_buffered_press.has(ATTACKER_ID), "outside the buffer window must not queue anything")


func test_press_within_buffer_window_is_accepted_silently() -> void:
	_tap()  # hit1
	_advance_until_remaining(INPUT_BUFFER_TICKS)
	var events := _press()
	assert_eq(_events_of_kind(events, "attack_rejected").size(), 0)
	assert_eq(_hit_events(events).size(), 0, "nothing resolves yet -- only queued")
	assert_true(sim._melee_buffered_press.has(ATTACKER_ID))


func test_buffered_press_materializes_automatically_on_the_tick_cooldown_clears() -> void:
	_tap()  # hit1
	_advance_until_remaining(INPUT_BUFFER_TICKS)
	_press()  # buffered
	while sim._melee_buffered_press.has(ATTACKER_ID):
		_tick_noop()
	assert_true(sim._melee_hold.has(ATTACKER_ID), "the hold must have opened automatically, with no released Command needed yet")
	assert_eq(int(sim._melee_hold[ATTACKER_ID].charge_ticks), 0)


func test_release_before_buffer_matures_resolves_as_single_tap_at_materialization() -> void:
	_tap()  # hit1 -> index now 1 (next tap is hit2)
	_advance_until_remaining(INPUT_BUFFER_TICKS)
	_press()  # buffered
	var release_events := _release()  # released before materialization
	assert_eq(_hit_events(release_events).size(), 0, "nothing resolves yet -- still buffered")

	var all_events: Array[Event] = []
	while sim._melee_buffered_press.has(ATTACKER_ID):
		all_events.append_array(_tick_noop())
	var hits := _hit_events(all_events)
	assert_eq(hits.size(), 1, "exactly one clean tap must resolve at materialization")
	assert_eq(hits[0].payload.get("attack_profile_id"), "2", "the queued press continues the combo sequence")
	assert_false(sim._melee_hold.has(ATTACKER_ID), "no stuck open hold afterward")


func test_held_ticks_after_materialization_still_count_toward_charge() -> void:
	_tap()  # hit1
	_advance_until_remaining(INPUT_BUFFER_TICKS)
	_press()  # buffered
	while sim._melee_buffered_press.has(ATTACKER_ID):
		_tick_noop()
	assert_true(sim._melee_hold.has(ATTACKER_ID), "sanity: materialized")
	for _i in range(CHARGE_THRESHOLD):
		_hold()
	var hits := _hit_events(_release())
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].payload.get("attack_profile_id"), "charge", "held ticks after materialization must still count toward charge")


func test_weapon_switch_while_buffered_discards_the_buffered_press() -> void:
	sim.set_weapon_loadout(ATTACKER_ID, [WEAPON_ID, &"other_weapon"])
	sim.register_weapon(&"other_weapon", 3.0, &"force", 2.0, 60.0, 0.0)
	_tap()  # hit1
	_advance_until_remaining(INPUT_BUFFER_TICKS)
	_press()  # buffered
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "switch_weapon")], 1.0 / 30.0)
	assert_false(sim._melee_buffered_press.has(ATTACKER_ID))
	var all_events: Array[Event] = []
	for _i in range(50):
		all_events.append_array(_tick_noop())
	assert_eq(_hit_events(all_events).size(), 0, "no phantom swing must ever fire from a discarded buffer")


func test_death_while_buffered_discards_the_buffered_press() -> void:
	_tap()  # hit1
	_advance_until_remaining(INPUT_BUFFER_TICKS)
	_press()  # buffered
	var killer_id := 2
	sim.add_entity(killer_id, Vector3.ZERO, 0.0)  # same position as ATTACKER_ID -- point-blank bypass guarantees a hit
	sim.register_combatant(killer_id, 999.0, &"killer_family")
	sim.register_weapon(&"lethal_weapon", 9999.0, &"force", 5.0, 180.0, 0.0)
	sim.set_equipped_weapon(killer_id, &"lethal_weapon")
	sim.tick([Command.new(sim.tick_count, killer_id, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_false(sim._melee_buffered_press.has(ATTACKER_ID))
	var all_events: Array[Event] = []
	for _i in range(50):
		all_events.append_array(_tick_noop())
	var corpse_hits := all_events.filter(func(e): return e.kind == "hit" and e.payload.get("attacker_id") == ATTACKER_ID)
	assert_eq(corpse_hits.size(), 0, "the corpse must never swing")


func test_block_rising_edge_while_buffered_discards_the_buffered_press() -> void:
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	_tap()  # hit1
	_advance_until_remaining(INPUT_BUFFER_TICKS)
	_press()  # buffered
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": true})], 1.0 / 30.0)
	assert_false(sim._melee_buffered_press.has(ATTACKER_ID))
	var all_events: Array[Event] = []
	for _i in range(50):
		all_events.append_array(_tick_noop())
	assert_eq(_hit_events(all_events).size(), 0)


func test_buffered_sequence_is_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
		local_sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
		local_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		var combo_profiles: Array[Dictionary] = [_profile(5.0, HIT1_FIRE_INTERVAL), _profile(5.0, 0), _profile(5.0, 0)]
		local_sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0, 0), CHARGE_THRESHOLD, COMBO_RESET, INPUT_BUFFER_TICKS)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)

		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
		while local_sim._next_fire_tick.get(ATTACKER_ID, 0) - local_sim.tick_count > INPUT_BUFFER_TICKS:
			local_sim.tick([], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
		for _j in range(20):
			local_sim.tick([], 1.0 / 30.0)

		results.append({"health": local_sim._health[TARGET_ID], "combo_index": local_sim._combo_index.get(ATTACKER_ID, 0), "hold_open": local_sim._melee_hold.has(ATTACKER_ID)})
	assert_eq(results[0], results[1], "an identical buffered sequence must produce identical sim state")


# --- Mid-swing buffering (manual-pass extension: two deadline sources -- end_tick
# while a swing is "executing", _next_fire_tick when only cooldown remains) ---

const MID_SWING_LUNGE_DURATION := 8
const MID_SWING_FIRE_INTERVAL := 5


func _make_mid_swing_sim() -> SimWorld:
	var s := SimWorld.new()
	s.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	s.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	s.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	s.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	s.set_damage_matrix({}, 1.5, 0.5)
	var hit1: Dictionary = _profile(5.0, MID_SWING_FIRE_INTERVAL)
	hit1.lunge_duration_ticks = MID_SWING_LUNGE_DURATION
	var combo_profiles: Array[Dictionary] = [hit1, _profile(5.0, 0), _profile(5.0, 0)]
	s.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0, 0), CHARGE_THRESHOLD, COMBO_RESET, INPUT_BUFFER_TICKS)
	s.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	return s


func test_mid_swing_press_at_exactly_buffer_ticks_remaining_queues() -> void:
	var s := _make_mid_swing_sim()
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
	while int(s._melee_hold[ATTACKER_ID].end_tick) - s.tick_count > INPUT_BUFFER_TICKS:
		s.tick([], 1.0 / 30.0)
	var events := s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "attack_rejected").size(), 0)
	assert_true(s._melee_buffered_press.has(ATTACKER_ID))


func test_mid_swing_press_one_tick_before_boundary_is_rejected_with_mid_swing() -> void:
	var s := _make_mid_swing_sim()
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
	while int(s._melee_hold[ATTACKER_ID].end_tick) - s.tick_count > INPUT_BUFFER_TICKS + 1:
		s.tick([], 1.0 / 30.0)
	var events := s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
	var rejected := events.filter(func(e): return e.kind == "attack_rejected")
	assert_eq(rejected.size(), 1)
	assert_eq(rejected[0].payload.get("reason"), "mid_swing")
	assert_false(s._melee_buffered_press.has(ATTACKER_ID))


## The corrected-mechanism test (manual-pass review caught an earlier draft of this
## design claiming materialization happens "at end_tick" -- it doesn't, since
## _advance_buffered_attacks runs BEFORE _advance_pending_attacks in tick() order,
## so a same-tick natural completion can't be seen by that earlier phase yet).
## Materialization must wait for _next_fire_tick specifically, never end_tick alone.
func test_mid_swing_buffered_press_materializes_at_next_fire_tick_not_end_tick() -> void:
	var s := _make_mid_swing_sim()
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
	while int(s._melee_hold[ATTACKER_ID].end_tick) - s.tick_count > INPUT_BUFFER_TICKS:
		s.tick([], 1.0 / 30.0)
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)  # buffered
	var end_tick: int = int(s._melee_hold[ATTACKER_ID].end_tick)
	while s.tick_count <= end_tick:
		s.tick([], 1.0 / 30.0)
	assert_true(s._melee_buffered_press.has(ATTACKER_ID), "must not materialize merely because the swing's own end_tick arrived")
	assert_false(s._melee_hold.has(ATTACKER_ID), "sanity: the swing itself has naturally completed")
	while s._melee_buffered_press.has(ATTACKER_ID):
		s.tick([], 1.0 / 30.0)
	assert_true(s._melee_hold.has(ATTACKER_ID), "must materialize once _next_fire_tick (end_tick + fire_interval_ticks) actually clears")


func test_charged_finisher_then_buffered_press_materializes_as_combo_hit_1() -> void:
	var s := SimWorld.new()
	s.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	s.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	s.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	s.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	s.set_damage_matrix({}, 1.5, 0.5)
	var combo_profiles: Array[Dictionary] = [_profile(5.0, 0), _profile(5.0, 0), _profile(5.0, 0)]
	s.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0, HIT1_FIRE_INTERVAL), CHARGE_THRESHOLD, COMBO_RESET, INPUT_BUFFER_TICKS)
	s.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)

	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
	for _i in range(CHARGE_THRESHOLD):
		s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "held"})], 1.0 / 30.0)
	var release_events := s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
	assert_eq(release_events.filter(func(e): return e.kind == "hit")[0].payload.get("attack_profile_id"), "charge")

	while s._next_fire_tick.get(ATTACKER_ID, 0) - s.tick_count > INPUT_BUFFER_TICKS:
		s.tick([], 1.0 / 30.0)
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)  # buffered
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)  # released before materialization
	assert_true(s._melee_buffered_press.has(ATTACKER_ID))

	var all_events: Array[Event] = []
	while s._melee_buffered_press.has(ATTACKER_ID):
		all_events.append_array(s.tick([], 1.0 / 30.0))
	var hits := all_events.filter(func(e): return e.kind == "hit")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].payload.get("attack_profile_id"), "1", "a press queued behind a charged finisher must materialize as combo hit 1")


## Post-implementation review regression: _apply_phased_melee_attack's "released"
## branch used to trigger its synchronous execution-tick catch-up off AMBIENT state
## ("is the hold executing right now?") rather than confirming THIS call is what
## opened it. A mid-swing buffered press's own early "released" takes
## _release_melee_hold's early-return branch (nothing in _melee_hold changes -- it
## only stashes buffered.released) while the ORIGINAL swing is still "executing",
## which used to satisfy the ambient check and double-apply that tick's lunge step.
func test_mid_swing_buffered_release_does_not_double_apply_the_original_swings_lunge() -> void:
	var s := SimWorld.new()
	s.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	s.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	s.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	s.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	s.set_damage_matrix({}, 1.5, 0.5)
	var hit1: Dictionary = _profile(5.0, 0)
	hit1.lunge_distance = 6.0
	hit1.lunge_duration_ticks = 12
	var combo_profiles: Array[Dictionary] = [hit1, _profile(5.0, 0), _profile(5.0, 0)]
	s.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0, 0), CHARGE_THRESHOLD, COMBO_RESET, INPUT_BUFFER_TICKS)
	s.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)

	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], 1.0 / 30.0)
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], 1.0 / 30.0)
	while int(s._melee_hold[ATTACKER_ID].end_tick) - s.tick_count > INPUT_BUFFER_TICKS:
		s.tick([], 1.0 / 30.0)

	var per_tick_step: float = 6.0 / 12.0
	var position_before: Vector3 = s.entities[ATTACKER_ID]
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], 1.0 / 30.0)  # buffers mid-swing
	assert_true(s._melee_buffered_press.has(ATTACKER_ID), "sanity: the second press must have buffered (mid-swing)")
	s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], 1.0 / 30.0)  # early release, before materialization
	var position_after: Vector3 = s.entities[ATTACKER_ID]
	assert_almost_eq(position_after.distance_to(position_before), per_tick_step * 2, 0.001, "exactly two ticks of the ORIGINAL swing's lunge must apply -- the buffered press's own early release must never cause a third (double) application")
