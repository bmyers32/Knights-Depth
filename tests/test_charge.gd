extends GutTest
## Slice B hold-to-charge (GAME-RULES §3) — the continuum model (locked spec):
## charge is how long you hold the SAME attack, not a separate mode. Release before
## charge_threshold_ticks fires the current combo step; release at/after it fires
## charge_profile instead, ending the sequence. Also covers the interruption rules
## (block-cancel, weapon-switch, death) shared with test_combo.gd's tap half.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"test_charge_sword"
const TARGET_FAMILY := &"test_target"
const TARGET_POSITION := Vector3(0, 0, -1)

const CHARGE_THRESHOLD := 5
const COMBO_RESET := 10


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var combo_profiles: Array[Dictionary] = [_profile(5.0), _profile(5.0), _profile(5.0)]
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), CHARGE_THRESHOLD, COMBO_RESET)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _profile(damage: float) -> Dictionary:
	return {
		"damage": damage,
		"damage_type": &"force",
		"reach": 2.0,
		"cone_half_angle_degrees": 60.0,
		"knockback_distance": 0.0,
		"fire_interval_ticks": 0,
		"status_id": &"",
		"status_proc_chance": 0.0,
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


func _hold_n_ticks(n: int, aim: Vector3 = Vector3.ZERO) -> void:
	for _i in range(n):
		_hold(aim)


func _hit_events(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "hit")


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- Tap vs. charge threshold ---

func test_release_well_before_threshold_fires_the_current_combo_step() -> void:
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD - 2)
	var hit: Event = _hit_events(_release())[0]
	assert_eq(hit.payload.get("attack_profile_id"), "1")
	assert_almost_eq(hit.payload.get("damage"), 5.0, 0.001)


func test_release_one_tick_before_threshold_is_still_a_combo_step() -> void:
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD - 1)
	assert_eq(_hit_events(_release())[0].payload.get("attack_profile_id"), "1", "exact boundary: one tick short of threshold must resolve as a tap, not a charge")


func test_release_at_threshold_fires_the_charged_attack() -> void:
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD)
	var hit: Event = _hit_events(_release())[0]
	assert_eq(hit.payload.get("attack_profile_id"), "charge")
	assert_almost_eq(hit.payload.get("damage"), 20.0, 0.001)


func test_holding_well_past_threshold_still_fires_exactly_one_identical_charged_attack() -> void:
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD + 20)  # saturation -- no additional power, no variable tiers
	var events := _release()
	var hits := _hit_events(events)
	assert_eq(hits.size(), 1, "saturation: only ever one hit from the eventual release")
	assert_eq(hits[0].payload.get("attack_profile_id"), "charge")
	assert_almost_eq(hits[0].payload.get("damage"), 20.0, 0.001)


# --- Sequence interaction (continuum model, locked amendment) ---

func test_tap_tap_hold_release_advances_then_charges_then_resets() -> void:
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1")
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "2")
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD)
	assert_eq(_hit_events(_release())[0].payload.get("attack_profile_id"), "charge", "charge replaces whatever step would have been next (step 3), it doesn't require reaching it")
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1", "a charged release must reset the sequence back to hit 1")


func test_holding_does_not_itself_reset_the_combo_index() -> void:
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1")
	_press()
	_hold_n_ticks(2)  # well under threshold -- an aborted charge attempt
	assert_eq(_hit_events(_release())[0].payload.get("attack_profile_id"), "2", "a short hold that resolves as a tap must still be step 2 -- merely holding never resets the index")


# --- Release-time aim ---

func test_charged_attack_uses_release_time_aim_not_press_time_aim() -> void:
	# Pressed and held aimed away from the target -- a press-time-frozen aim would
	# miss. Released aimed directly at the target (its actual position).
	_press(Vector3(1, 0, 0))
	_hold_n_ticks(CHARGE_THRESHOLD, Vector3(1, 0, 0))
	var events := _hit_events(_release(Vector3(0, 0, -1)))
	assert_eq(events.size(), 1, "the charged attack must resolve against the release-time aim, hitting the target directly ahead")
	assert_eq(events[0].payload.get("attack_profile_id"), "charge")


# --- Movement during charge ---

func test_movement_commands_resolve_normally_while_a_hold_is_open() -> void:
	_press()
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.RIGHT})], 1.0 / 30.0)
	assert_eq(_events_of_kind(events, "moved").size(), 1, "movement must not be blocked by an open charge hold")
	assert_gt(sim.entities[ATTACKER_ID].x, 0.0, "the attacker must actually have moved")


# --- Interruption: block cancels an open charge ---

func test_block_rising_edge_cancels_an_open_charge_with_no_swing_or_event() -> void:
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	_press()
	_hold()
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": true})], 1.0 / 30.0)
	assert_eq(_hit_events(events).size(), 0)
	assert_false(sim._melee_hold.has(ATTACKER_ID), "the hold must be discarded")
	var release_events := _release()
	assert_eq(_hit_events(release_events).size(), 0, "a release with no open hold must not fire a phantom attack")


func test_block_cancel_does_not_reset_the_combo_index() -> void:
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1")
	_press()
	_hold()
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": true})], 1.0 / 30.0)  # cancels the hold
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": false})], 1.0 / 30.0)  # release block
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "2", "block-canceling an unreleased hold must not consume or reset a combo step")


# --- Interruption: weapon switch ---

func test_weapon_switch_cancels_an_open_hold_and_resets_combo() -> void:
	sim.set_weapon_loadout(ATTACKER_ID, [WEAPON_ID, &"other_weapon"])
	sim.register_weapon(&"other_weapon", 3.0, &"force", 2.0, 60.0, 0.0)
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1")
	_press()
	_hold()
	var switch_events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "switch_weapon")], 1.0 / 30.0)
	assert_eq(_events_of_kind(switch_events, "weapon_switched").size(), 1)
	assert_eq(_hit_events(switch_events).size(), 0, "no phantom tap must fire from the discarded hold")
	assert_false(sim._melee_hold.has(ATTACKER_ID))
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "switch_weapon")], 1.0 / 30.0)  # back to the combo weapon
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1", "a weapon switch must reset the combo sequence")


# --- Interruption: death ---

func test_death_clears_the_open_hold_and_combo_state() -> void:
	assert_eq(_hit_events(_tap())[0].payload.get("attack_profile_id"), "1")
	_press()
	_hold()
	assert_true(sim._melee_hold.has(ATTACKER_ID), "sanity: the hold is open before the lethal hit")

	var killer_id := 2
	sim.add_entity(killer_id, Vector3.ZERO, 0.0)  # same position as ATTACKER_ID -- point-blank bypass guarantees a hit
	sim.register_combatant(killer_id, 999.0, &"killer_family")  # default allegiance "enemy"
	sim.register_weapon(&"lethal_weapon", 9999.0, &"force", 5.0, 180.0, 0.0)
	sim.set_equipped_weapon(killer_id, &"lethal_weapon")
	var events := sim.tick([Command.new(sim.tick_count, killer_id, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	var deaths := _events_of_kind(events, "died").filter(func(e): return e.payload.get("actor_id") == ATTACKER_ID)
	assert_eq(deaths.size(), 1, "sanity: the attacker actually died this tick")
	assert_false(sim._melee_hold.has(ATTACKER_ID), "death must clear the open hold")
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 0, "death must clear the combo index")


# --- Determinism ---

func test_press_hold_release_sequence_is_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
		local_sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
		local_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY)
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		var combo_profiles: Array[Dictionary] = [_profile(5.0), _profile(5.0), _profile(5.0)]
		local_sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), CHARGE_THRESHOLD, COMBO_RESET)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
		for _j in range(CHARGE_THRESHOLD):
			local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "held"})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
		results.append({"health": local_sim._health[TARGET_ID], "combo_index": local_sim._combo_index.get(ATTACKER_ID, 0)})
	assert_eq(results[0], results[1], "an identical press/held/released sequence must produce identical sim state")


# --- charge_ready event (manual-pass cue, pure event-listener design) ---

func test_charge_ready_fires_exactly_once_at_the_saturation_tick() -> void:
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD - 1)
	var events := _hold()  # the tick charge_ticks first reaches CHARGE_THRESHOLD
	assert_eq(_events_of_kind(events, "charge_ready").size(), 1)


func test_charge_ready_does_not_fire_before_threshold() -> void:
	_press()
	var events: Array[Event] = []
	for _i in range(CHARGE_THRESHOLD - 1):
		events.append_array(_hold())
	assert_eq(_events_of_kind(events, "charge_ready").size(), 0)


func test_charge_ready_does_not_repeat_on_subsequent_held_ticks() -> void:
	_press()
	var events: Array[Event] = []
	for _i in range(CHARGE_THRESHOLD + 20):
		events.append_array(_hold())
	assert_eq(_events_of_kind(events, "charge_ready").size(), 1, "must fire exactly once across the whole saturated hold, never per tick")


func test_charge_ready_does_not_fire_on_a_release_that_never_reached_threshold() -> void:
	var events := _tap()
	assert_eq(_events_of_kind(events, "charge_ready").size(), 0)


# --- melee_hold_canceled event (pairs with charge_ready to drive the presentation
# tint listener -- released/block-cancel/switch-cancel/death all clear it) ---

func test_melee_hold_canceled_fires_on_block_cancel_of_an_open_hold() -> void:
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	_press()
	_hold()
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": true})], 1.0 / 30.0)
	assert_eq(_events_of_kind(events, "melee_hold_canceled").size(), 1)


func test_melee_hold_canceled_does_not_fire_on_block_cancel_with_no_open_hold() -> void:
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": true})], 1.0 / 30.0)
	assert_eq(_events_of_kind(events, "melee_hold_canceled").size(), 0, "raising block with nothing to cancel must stay silent")


func test_melee_hold_canceled_fires_on_weapon_switch_of_an_open_hold() -> void:
	sim.set_weapon_loadout(ATTACKER_ID, [WEAPON_ID, &"other_weapon"])
	sim.register_weapon(&"other_weapon", 3.0, &"force", 2.0, 60.0, 0.0)
	_press()
	_hold()
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "switch_weapon")], 1.0 / 30.0)
	assert_eq(_events_of_kind(events, "melee_hold_canceled").size(), 1)


func test_melee_hold_canceled_fires_on_death_with_an_open_hold() -> void:
	_press()
	_hold()
	var killer_id := 2
	sim.add_entity(killer_id, Vector3.ZERO, 0.0)  # same position as ATTACKER_ID -- point-blank bypass guarantees a hit
	sim.register_combatant(killer_id, 999.0, &"killer_family")
	sim.register_weapon(&"lethal_weapon", 9999.0, &"force", 5.0, 180.0, 0.0)
	sim.set_equipped_weapon(killer_id, &"lethal_weapon")
	var events := sim.tick([Command.new(sim.tick_count, killer_id, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_eq(_events_of_kind(events, "melee_hold_canceled").size(), 1)


func test_melee_hold_canceled_does_not_fire_on_a_normal_release() -> void:
	_press()
	var events := _release()  # tap, well before threshold
	assert_eq(_events_of_kind(events, "melee_hold_canceled").size(), 0, "a normal release produces melee_swing, never melee_hold_canceled")
