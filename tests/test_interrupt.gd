extends GutTest
## Interruption as graded content (manual-pass, GAME-RULES §3): a hit's
## interrupt_strength decides what happens when it lands on a currently
## winding-up enemy. interrupt_strength <= 0 (hits 1-2): damage/status resolve
## normally, knockback is suppressed, the windup continues untouched. > 0 (hit 3,
## charge): windup cancels (arms the SAME cooldown a completed attack would have)
## and knockback applies normally. A target that isn't winding up is completely
## unaffected -- unconditional knockback, exactly as before this session.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"test_interrupt_sword"
const TARGET_WEAPON_ID := &"test_target_weapon"
const TARGET_POSITION := Vector3(0, 0, -1)
const TARGET_FIRE_INTERVAL_TICKS := 45


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")

	sim.add_entity(TARGET_ID, TARGET_POSITION, 3.0)
	sim.register_combatant(TARGET_ID, 999.0, &"fang", 0, 0.0, &"enemy")
	sim.register_weapon(TARGET_WEAPON_ID, 5.0, &"force", 1.5, 90.0, 0.5, TARGET_FIRE_INTERVAL_TICKS)
	# windup_ticks=10000: this suite drives "winding up" state directly via
	# _start_target_windup below rather than waiting on the AI's own decision
	# timing -- a huge windup_ticks just keeps register_ai's own machinery from
	# ever completing a windup on its own mid-test.
	sim.register_ai(TARGET_ID, TARGET_WEAPON_ID, TARGET_POSITION, 1.5, 0.8, 10000, 8.0, 10.0)

	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.register_status(&"burn", 2.0, 5, 20)
	sim.set_status_priority({"burn": 1})

	var combo_profiles: Array[Dictionary] = [
		_profile(5.0, 0, &"burn", 1.0),  # hit1: non-interrupting, guaranteed Burn proc
		_profile(5.0, 0),  # hit2: non-interrupting
		_profile(5.0, 1),  # hit3: interrupting
	]
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0, 1), 5, 10)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _profile(damage: float, interrupt_strength: int = 0, status_id: StringName = &"", status_proc_chance: float = 0.0) -> Dictionary:
	return {
		"damage": damage,
		"damage_type": &"force",
		"reach": 2.0,
		"cone_half_angle_degrees": 60.0,
		"knockback_distance": 1.0,
		"fire_interval_ticks": 0,
		"status_id": status_id,
		"status_proc_chance": status_proc_chance,
		"interrupt_strength": interrupt_strength,
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


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


## Directly arms TARGET_ID's windup state (white-box setup, matching this codebase's
## existing convention of poking internal dicts for test setup -- see test_shield.gd)
## rather than waiting on the AI's own decision timing. fire_tick far in the future
## so it never completes mid-test unless a specific test ticks far enough to check.
func _start_target_windup(fire_tick_offset: int = 10000) -> void:
	sim._ai_attack_start_tick[TARGET_ID] = sim.tick_count
	sim._ai_attack_fire_tick[TARGET_ID] = sim.tick_count + fire_tick_offset


func test_non_interrupting_hit_during_windup_does_not_cancel_or_move_position() -> void:
	_start_target_windup()
	var position_before: Vector3 = sim.entities[TARGET_ID]
	_tap()  # hit1: non-interrupting
	assert_true(sim._ai_attack_fire_tick.has(TARGET_ID), "windup must still be in progress")
	assert_eq(sim.entities[TARGET_ID], position_before, "position must be unchanged -- knockback suppressed")


func test_non_interrupting_hit_during_windup_still_applies_damage_and_status_proc() -> void:
	_start_target_windup()
	var health_before: float = sim._health[TARGET_ID]
	var events := _tap()  # hit1: non-interrupting, guaranteed Burn proc
	assert_eq(_hit_events(events).size(), 1)
	assert_lt(sim._health[TARGET_ID], health_before, "damage must still apply")
	assert_true(sim._status_instances.has(TARGET_ID), "status must still apply despite the windup-knockback suppression")


func test_interrupting_hit_cancels_windup_and_applies_knockback() -> void:
	_start_target_windup()
	var position_before: Vector3 = sim.entities[TARGET_ID]
	_tap()  # hit1
	_tap()  # hit2
	_tap()  # hit3: interrupting
	assert_false(sim._ai_attack_fire_tick.has(TARGET_ID), "windup must be canceled")
	assert_true(sim.entities[TARGET_ID] != position_before, "position must change -- knockback applies")


func test_interrupted_windup_never_fires_even_after_ticking_past_original_fire_tick() -> void:
	_start_target_windup(5)  # near future this time, so ticking forward could reach it if uncanceled
	_tap()  # hit1
	_tap()  # hit2
	var all_events: Array[Event] = _tap()  # hit3: interrupting -- cancels
	for _i in range(20):
		all_events.append_array(_tick_noop())
	var enemy_authored_hits := all_events.filter(func(e): return e.kind == "hit" and e.payload.get("attacker_id") == TARGET_ID)
	assert_eq(enemy_authored_hits.size(), 0, "an interrupted windup must never fire")


func test_interrupting_hit_arms_the_same_cooldown_a_completed_attack_would_have() -> void:
	_start_target_windup()
	_tap()  # hit1
	_tap()  # hit2
	_press()
	var resolve_tick: int = sim.tick_count
	_release()  # hit3: interrupting, resolves at resolve_tick
	assert_eq(sim._next_fire_tick[TARGET_ID], resolve_tick + TARGET_FIRE_INTERVAL_TICKS, "a canceled windup must arm the same cooldown a completed attack would have")


func test_windup_interrupted_event_fires_only_on_an_interrupting_hit() -> void:
	_start_target_windup()
	var non_interrupting_events := _tap()  # hit1
	assert_eq(_events_of_kind(non_interrupting_events, "windup_interrupted").size(), 0)
	_tap()  # hit2
	var interrupting_events := _tap()  # hit3
	assert_eq(_events_of_kind(interrupting_events, "windup_interrupted").size(), 1)


func test_knockback_against_a_non_winding_up_enemy_is_unchanged() -> void:
	# TARGET_ID (registered via register_ai) auto-arms its OWN windup the moment it
	# ticks, since it's within its own detection/attack range of the attacker --
	# proving the regression guard needs a target that can never wind up at all, not
	# just one that hasn't yet. A plain combatant (no register_ai) is never in
	# _ai_attack_fire_tick, so this is a clean "not winding up" case by construction.
	var non_ai_target_id := 2
	sim.add_entity(non_ai_target_id, TARGET_POSITION, 0.0)
	sim.register_combatant(non_ai_target_id, 999.0, &"fang", 0, 0.0, &"enemy")
	var position_before: Vector3 = sim.entities[non_ai_target_id]
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "pressed"})], 1.0 / 30.0)
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": "released"})], 1.0 / 30.0)
	assert_true(sim.entities[non_ai_target_id] != position_before, "a hit against a non-winding-up target must always knock back, regardless of interrupt_strength")


func test_lethal_non_interrupting_hit_during_windup_still_suppresses_knockback() -> void:
	sim._health[TARGET_ID] = 1.0  # dies to hit1's 5 damage
	_start_target_windup()
	var position_before: Vector3 = sim.entities[TARGET_ID]
	var events := _tap()  # hit1: non-interrupting, lethal
	assert_eq(_events_of_kind(events, "died").size(), 1, "sanity: this hit must be lethal")
	assert_eq(sim.entities[TARGET_ID], position_before, "knockback suppression applies even to a lethal non-interrupting hit during windup")


func test_interrupt_sequence_is_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
		local_sim.add_entity(TARGET_ID, TARGET_POSITION, 3.0)
		local_sim.register_combatant(TARGET_ID, 999.0, &"fang", 0, 0.0, &"enemy")
		local_sim.register_weapon(TARGET_WEAPON_ID, 5.0, &"force", 1.5, 90.0, 0.5, TARGET_FIRE_INTERVAL_TICKS)
		local_sim.register_ai(TARGET_ID, TARGET_WEAPON_ID, TARGET_POSITION, 1.5, 0.8, 10000, 8.0, 10.0)
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		local_sim.register_status(&"burn", 2.0, 5, 20)
		local_sim.set_status_priority({"burn": 1})
		var combo_profiles: Array[Dictionary] = [_profile(5.0, 0, &"burn", 1.0), _profile(5.0, 0), _profile(5.0, 1)]
		local_sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0, 1), 5, 10)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
		local_sim._ai_attack_start_tick[TARGET_ID] = local_sim.tick_count
		local_sim._ai_attack_fire_tick[TARGET_ID] = local_sim.tick_count + 10000

		for phase in ["pressed", "released", "pressed", "released", "pressed", "released"]:
			local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO, "phase": phase})], 1.0 / 30.0)

		results.append({"health": local_sim._health[TARGET_ID], "position": local_sim.entities[TARGET_ID], "fire_tick_present": local_sim._ai_attack_fire_tick.has(TARGET_ID)})
	assert_eq(results[0], results[1], "an identical interrupt sequence must produce identical sim state")
