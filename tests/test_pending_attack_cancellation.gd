extends GutTest
## Shield-cancel timing + enemy-interrupt (manual-pass, GAME-RULES §3). Three shield
## timing windows collapse into one uniform cancel check (pre-hit: no hit, no combo
## credit; same-tick: hit resolves first, then cancel; post-hit: hit stands, cancel
## remainder) because _advance_pending_attacks always runs before this tick's block
## Command, by construction. Enemy hits interrupt a player's pending attack
## unconditionally (M1 simplification, no poise yet) -- windup/executing only,
## never a pre-release "charging" hold.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const ENEMY_ID := 2
const WEAPON_ID := &"test_cancel_sword"

const CHARGE_THRESHOLD := 5
const WINDUP_TICKS := 3
const HIT_ACTIVE_TICKS := 4
const LUNGE_DURATION_TICKS := 6
const FIRE_INTERVAL_TICKS := 5
const INPUT_BUFFER_TICKS := 10


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	sim.add_entity(TARGET_ID, Vector3(0, 0, -1), 0.0)
	sim.register_combatant(TARGET_ID, 999.0, &"test_target")
	sim.set_damage_matrix({}, 1.5, 0.5)
	# All three combo steps carry the same timing (not just hit1) -- several tests
	# below cancel a SECOND swing (hit2) and need it to have a real "executing"
	# window to cancel into, not an all-zero-fields instant resolve.
	var combo_profiles: Array[Dictionary] = [
		_profile(5.0, 0, HIT_ACTIVE_TICKS, LUNGE_DURATION_TICKS, FIRE_INTERVAL_TICKS),
		_profile(5.0, 0, HIT_ACTIVE_TICKS, LUNGE_DURATION_TICKS, FIRE_INTERVAL_TICKS),
		_profile(5.0, 0, HIT_ACTIVE_TICKS, LUNGE_DURATION_TICKS, FIRE_INTERVAL_TICKS),
	]
	var charge_profile: Dictionary = _profile(20.0, WINDUP_TICKS)
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, charge_profile, CHARGE_THRESHOLD, 50, INPUT_BUFFER_TICKS)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _profile(damage: float, windup_ticks: int = 0, hit_active_ticks: int = 0, lunge_duration_ticks: int = 0, fire_interval_ticks: int = 0) -> Dictionary:
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
		"lunge_distance": 0.0,
		"lunge_duration_ticks": lunge_duration_ticks,
		"hit_active_ticks": hit_active_ticks,
		"windup_ticks": windup_ticks,
	}


func _register_enemy_attacker() -> void:
	sim.add_entity(ENEMY_ID, Vector3.ZERO, 0.0)  # same position as ATTACKER_ID -- point-blank bypass guarantees a hit
	sim.register_combatant(ENEMY_ID, 999.0, &"enemy_family")  # default allegiance "enemy"
	sim.register_weapon(&"test_enemy_weapon", 1.0, &"force", 5.0, 180.0, 0.0)  # chip damage, interrupt_strength defaults 0 -- proves "unconditional"
	sim.set_equipped_weapon(ENEMY_ID, &"test_enemy_weapon")


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


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _hit_events(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "hit")


func _block(held: bool) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": held})], 1.0 / 30.0)


# --- Shield-cancel timing ---

func test_pre_hit_shield_cancel_no_damage_and_no_combo_credit() -> void:
	_tap()
	var health_before: float = sim._health[TARGET_ID]
	_block(true)  # well before hit_tick (execution_start + HIT_ACTIVE_TICKS)
	assert_almost_eq(sim._health[TARGET_ID], health_before, 0.001, "no damage from a pre-hit-tick cancel")
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 0, "no combo credit -- the swing retroactively never occurred")
	var all_events: Array[Event] = []
	for _i in range(HIT_ACTIVE_TICKS + LUNGE_DURATION_TICKS + 5):
		all_events.append_array(_tick_noop())
	assert_eq(_hit_events(all_events).size(), 0, "the canceled hit must never fire later")


func test_same_tick_shield_cancel_resolves_the_hit_before_cancellation() -> void:
	_tap()
	for _i in range(HIT_ACTIVE_TICKS - 1):
		_tick_noop()
	var health_before: float = sim._health[TARGET_ID]
	var events := _block(true)  # this tick == hit_tick exactly
	assert_lt(sim._health[TARGET_ID], health_before, "the hit must resolve THIS tick before the cancellation")
	assert_eq(events.filter(func(e): return e.kind == "hit").size(), 1)
	assert_eq(events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 1, "cancellation must also fire this same tick")
	assert_false(sim._melee_hold.has(ATTACKER_ID))


func test_post_hit_shield_cancel_preserves_the_hit_but_cancels_remaining_lunge() -> void:
	_tap()
	for _i in range(HIT_ACTIVE_TICKS):
		_tick_noop()
	assert_true(sim._melee_hold.has(ATTACKER_ID), "sanity: still in recovery, not yet naturally completed")
	var health_before: float = sim._health[TARGET_ID]
	var events := _block(true)
	assert_almost_eq(sim._health[TARGET_ID], health_before, 0.001, "no NEW damage -- the hit already resolved earlier")
	assert_eq(events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 1)
	assert_false(sim._melee_hold.has(ATTACKER_ID))


func test_canceled_charge_windup_produces_no_fallback_attack_and_no_partial_charge() -> void:
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD)
	_release()
	assert_eq(sim._melee_hold[ATTACKER_ID].state, "windup")
	var health_before: float = sim._health[TARGET_ID]
	var combo_index_before: int = sim._combo_index.get(ATTACKER_ID, 0)
	var events := _block(true)
	assert_eq(events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 1)
	assert_almost_eq(sim._health[TARGET_ID], health_before, 0.001)
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), combo_index_before, "no partial charge, no combo credit")
	var all_events: Array[Event] = []
	for _i in range(WINDUP_TICKS + HIT_ACTIVE_TICKS + LUNGE_DURATION_TICKS + 5):
		all_events.append_array(_tick_noop())
	assert_eq(_hit_events(all_events).size(), 0, "the canceled charge must never fire")


func test_block_engages_immediately_after_any_cancellation() -> void:
	_tap()
	_block(true)
	assert_eq(sim._shield_state[ATTACKER_ID], "held", "block must engage the same tick as the cancellation")


func test_buffered_press_flushes_on_cancellation() -> void:
	_tap()  # hit1 -> executing (INPUT_BUFFER_TICKS=10 is generous, well past end_tick's own window)
	var press_events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
	assert_eq(press_events.filter(func(e): return e.kind == "attack_rejected").size(), 0, "sanity: the press must have buffered, not been rejected")
	assert_true(sim._melee_buffered_press.has(ATTACKER_ID), "sanity: a press is queued behind the mid-swing")
	_block(true)
	assert_false(sim._melee_buffered_press.has(ATTACKER_ID), "cancellation must flush the queued press")
	var all_events: Array[Event] = []
	for _i in range(30):
		all_events.append_array(_tick_noop())
	assert_eq(_hit_events(all_events).size(), 0, "the flushed press must never fire on its own")


func test_cancellation_sequence_is_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
		local_sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
		local_sim.add_entity(TARGET_ID, Vector3(0, 0, -1), 0.0)
		local_sim.register_combatant(TARGET_ID, 999.0, &"test_target")
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		# Matches before_each exactly (all three combo steps carry the same timing) --
		# a prior version of this test diverged here (hits 2/3 all-zero-fields),
		# which happened to stay harmless only because this specific sequence never
		# touches hit 2/3, but would have silently misrepresented the file's own
		# documented setup if ever extended.
		var combo_profiles: Array[Dictionary] = [_profile(5.0, 0, HIT_ACTIVE_TICKS, LUNGE_DURATION_TICKS, FIRE_INTERVAL_TICKS), _profile(5.0, 0, HIT_ACTIVE_TICKS, LUNGE_DURATION_TICKS, FIRE_INTERVAL_TICKS), _profile(5.0, 0, HIT_ACTIVE_TICKS, LUNGE_DURATION_TICKS, FIRE_INTERVAL_TICKS)]
		local_sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0, WINDUP_TICKS), CHARGE_THRESHOLD, 50, INPUT_BUFFER_TICKS)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "block", {"held": true})], 1.0 / 30.0)
		results.append({"health": local_sim._health[TARGET_ID], "combo_index": local_sim._combo_index.get(ATTACKER_ID, 0), "shield_state": local_sim._shield_state[ATTACKER_ID]})
	assert_eq(results[0], results[1], "an identical cancellation sequence must produce identical sim state")


# --- Enemy interrupt (M1 simplification: unconditional, no poise) ---

func test_enemy_hit_interrupts_player_executing_swing_unconditionally() -> void:
	_register_enemy_attacker()
	_tap()
	assert_true(sim._melee_hold.has(ATTACKER_ID))
	var events := sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	var cancel_events := events.filter(func(e): return e.kind == "melee_hold_canceled" and e.payload.get("actor_id") == ATTACKER_ID)
	assert_eq(cancel_events.size(), 1, "even a zero-interrupt_strength hit must cancel the player's own pending attack")
	assert_false(sim._melee_hold.has(ATTACKER_ID))


func test_enemy_hit_interrupts_player_windup() -> void:
	_register_enemy_attacker()
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD)
	_release()
	assert_eq(sim._melee_hold[ATTACKER_ID].state, "windup")
	var events := sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 1)
	assert_false(sim._melee_hold.has(ATTACKER_ID))


func test_enemy_hit_does_not_interrupt_a_charging_hold() -> void:
	_register_enemy_attacker()
	_press()
	_hold_n_ticks(2)  # well under CHARGE_THRESHOLD, still charging
	var events := sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 0, "a pre-release charging hold is out of scope for enemy interrupt")
	assert_true(sim._melee_hold.has(ATTACKER_ID), "the hold must survive")
	assert_eq(sim._melee_hold[ATTACKER_ID].state, "charging")


func test_enemy_interrupt_arms_the_same_cooldown_a_completed_attack_would_have() -> void:
	_register_enemy_attacker()
	_tap()
	var resolve_tick: int = sim.tick_count
	sim.tick([Command.new(resolve_tick, ENEMY_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_eq(sim._next_fire_tick[ATTACKER_ID], resolve_tick + FIRE_INTERVAL_TICKS)


# --- Combo-state interaction ---

func test_cancel_of_executing_preserves_prior_combo_progress() -> void:
	_tap()  # complete hit1 fully
	for _i in range(LUNGE_DURATION_TICKS + FIRE_INTERVAL_TICKS + 2):
		_tick_noop()
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 1, "sanity: hit1 completed and advanced the combo")
	_tap()  # start hit2, cancel before its hit_tick
	_block(true)
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 1, "canceling hit2's attempt must not reset or advance prior progress")


func test_lethal_hit_during_executing_fully_resets_combo_state() -> void:
	_tap()
	for _i in range(LUNGE_DURATION_TICKS + FIRE_INTERVAL_TICKS + 2):
		_tick_noop()
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 1, "sanity")
	_tap()  # start hit2, executing
	sim._health[ATTACKER_ID] = 1.0
	_register_enemy_attacker()
	sim.register_weapon(&"test_lethal_weapon", 9999.0, &"force", 5.0, 180.0, 0.0)
	sim.set_equipped_weapon(ENEMY_ID, &"test_lethal_weapon")
	sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_eq(sim._combo_index.get(ATTACKER_ID, 0), 0, "death must fully reset combo index, unlike a mere cancellation")


# --- Weapon switch ---

func test_weapon_switch_during_executing_clears_the_record() -> void:
	sim.set_weapon_loadout(ATTACKER_ID, [WEAPON_ID, &"other_weapon"])
	sim.register_weapon(&"other_weapon", 3.0, &"force", 2.0, 60.0, 0.0)
	_tap()
	assert_true(sim._melee_hold.has(ATTACKER_ID))
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "switch_weapon")], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 1)
	assert_false(sim._melee_hold.has(ATTACKER_ID))


func test_weapon_switch_during_windup_clears_the_record() -> void:
	sim.set_weapon_loadout(ATTACKER_ID, [WEAPON_ID, &"other_weapon"])
	sim.register_weapon(&"other_weapon", 3.0, &"force", 2.0, 60.0, 0.0)
	_press()
	_hold_n_ticks(CHARGE_THRESHOLD)
	_release()
	assert_eq(sim._melee_hold[ATTACKER_ID].state, "windup")
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "switch_weapon")], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 1)
	assert_false(sim._melee_hold.has(ATTACKER_ID))
