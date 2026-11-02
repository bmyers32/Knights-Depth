extends GutTest
## Held attack intent survives temporary ineligibility (sword design pass, 2026-10-30,
## GAME-RULES §3). Playtest finding: after releasing a charge, pressing and HOLDING the
## next attack during the charge's windup/recovery was refused and then ignored for as
## long as the button stayed down -- the player had to let go and press again. The
## existing one-slot buffer (_melee_buffered_press) now carries a second kind of pending
## intent: a press rejected too early for the tap buffer leaves HELD intent behind, and
## if the button is still down at the first legal tick the hold opens there with no new
## rising edge. This is input retention, never autofire: every guard below pins that.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const ENEMY_ID := 2
const WEAPON_ID := &"test_retention_sword"
const OTHER_WEAPON_ID := &"test_retention_other"
const TARGET_POSITION := Vector3(0.3, 0, -1)
const AIM := Vector3(0, 0, -1)
const DT := 1.0 / 30.0

const CHARGE_THRESHOLD := 5
const COMBO_RESET := 50
const INPUT_BUFFER_TICKS := 4
const STEP_FIRE_INTERVAL := 12  # far longer than the tap buffer: a press right after a step is "too early"
const CHARGE_WINDUP := 6
const CHARGE_HIT_ACTIVE := 2
const CHARGE_LUNGE_DURATION := 3
const CHARGE_FIRE_INTERVAL := 8
const LOOP_BUDGET := 200


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	sim.register_combatant(TARGET_ID, 999.0, &"test_target")
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	var combo_profiles: Array[Dictionary] = [_profile(5.0, STEP_FIRE_INTERVAL), _profile(5.0, STEP_FIRE_INTERVAL), _profile(5.0, STEP_FIRE_INTERVAL)]
	var charge: Dictionary = _profile(20.0, CHARGE_FIRE_INTERVAL)
	charge.windup_ticks = CHARGE_WINDUP
	charge.hit_active_ticks = CHARGE_HIT_ACTIVE
	charge.lunge_duration_ticks = CHARGE_LUNGE_DURATION
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, charge, CHARGE_THRESHOLD, COMBO_RESET, INPUT_BUFFER_TICKS)
	sim.register_weapon(OTHER_WEAPON_ID, 10.0, &"force", 2.0, 60.0, 1.0)
	sim.set_weapon_loadout(ATTACKER_ID, [WEAPON_ID, OTHER_WEAPON_ID])
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _profile(damage: float, fire_interval_ticks: int) -> Dictionary:
	return {
		"damage": damage, "damage_type": &"force", "reach": 2.0, "cone_half_angle_degrees": 60.0,
		"knockback_distance": 0.0, "fire_interval_ticks": fire_interval_ticks, "status_id": &"", "status_proc_chance": 0.0,
		"lunge_distance": 0.0, "lunge_duration_ticks": 0, "hit_active_ticks": 0, "windup_ticks": 0,
	}


func _attack(phase: String) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": AIM, "phase": phase})], DT)


func _attack_and_block(phase: String, block_held: bool) -> Array[Event]:
	return sim.tick([
		Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": AIM, "phase": phase}),
		Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": block_held}),
	], DT)


func _block(held: bool) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": held})], DT)


func _idle(ticks: int) -> Array[Event]:
	var events: Array[Event] = []
	for _i in range(ticks):
		events.append_array(sim.tick([], DT))
	return events


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


func _state() -> String:
	return String(sim.debug_describe_melee_state(ATTACKER_ID).get("state", ""))


func _held_intent_queued() -> bool:
	return bool(sim.debug_describe_melee_state(ATTACKER_ID).get("buffered_held_intent", false))


func _eligible_tick() -> int:
	return int(sim._next_fire_tick.get(ATTACKER_ID, 0))


## Press, hold to the threshold, release: the charge's windup opens on the release tick.
func _fire_charge() -> Array[Event]:
	_attack("pressed")
	for _i in range(CHARGE_THRESHOLD):
		_attack("held")
	var events := _attack("released")
	assert_eq(_state(), "windup", "sanity: the charge is winding up")
	return events


## Keep the button physically down (envoy.gd reports "held" every tick) until the
## weapon's cooldown tick, recording the first tick a new hold is open. Returns that tick
## or -1. Capped so a hold that never opens fails an assertion, never hangs the suite.
func _hold_through_eligibility() -> int:
	for _i in range(LOOP_BUDGET):
		_attack("held")
		if _state() == "charging":
			return sim.tick_count - 1  # the tick the held Command was applied on
	return -1


# --- the chain the playtest asked for ----------------------------------------------------

func test_1_hold_pressed_during_charge_windup_opens_at_the_first_legal_tick_without_a_new_press() -> void:
	_fire_charge()
	var early := _attack("pressed")  # during the charge's own windup
	assert_eq(_of(early, "attack_rejected").size(), 1, "the tap is refused exactly as before")
	assert_eq(_of(early, "attack_rejected")[0].payload.reason, "mid_swing")
	assert_true(_held_intent_queued(), "but the held button is remembered")
	var opened_at: int = _hold_through_eligibility()
	assert_gt(opened_at, 0, "the next hold opened on its own")
	assert_eq(opened_at, _eligible_tick(), "exactly at the first legal tick, not before and not later")
	assert_false(_held_intent_queued(), "the intent was consumed by the hold it opened")


func test_2_the_retained_hold_charges_and_fires_like_any_other() -> void:
	_fire_charge()
	_attack("pressed")
	_hold_through_eligibility()
	var ready_seen: bool = false
	for _i in range(CHARGE_THRESHOLD + 1):
		ready_seen = ready_seen or _of(_attack("held"), "charge_ready").size() == 1
	assert_true(ready_seen, "the retained hold saturates to charge_ready")
	var events := _attack("released")
	events.append_array(_idle(CHARGE_WINDUP + CHARGE_LUNGE_DURATION))
	assert_eq(String(_of(events, "hit")[0].payload.attack_profile_id), "charge", "and releases a second charge")


func test_3_hold_pressed_during_charge_recovery_or_cooldown_is_retained_too() -> void:
	_fire_charge()
	_idle(CHARGE_WINDUP + CHARGE_LUNGE_DURATION)  # the swing has just ended; its cooldown is running
	var early := _attack("pressed")
	assert_eq(_of(early, "attack_rejected").size(), 1, "too early even for the tap buffer")
	assert_eq(_of(early, "attack_rejected")[0].payload.reason, "on_cooldown")
	assert_true(_held_intent_queued())
	assert_eq(_hold_through_eligibility(), _eligible_tick())


# --- release before eligibility: nothing materializes ----------------------------------

func test_4_release_before_eligibility_clears_the_intent_and_fires_nothing() -> void:
	_fire_charge()
	_attack("pressed")
	assert_true(_held_intent_queued())
	_attack("released")
	assert_false(_held_intent_queued(), "letting go erases the intent")
	var events := _idle(CHARGE_WINDUP + CHARGE_LUNGE_DURATION + CHARGE_FIRE_INTERVAL + 10)
	assert_eq(_of(events, "hit").size(), 1, "only the charge itself lands")
	assert_eq(_of(events, "melee_swing").size(), 1)
	assert_eq(_state(), "", "no tap materialized, no charge began")


func test_5_a_tap_pressed_too_early_still_materializes_nothing() -> void:
	_attack("pressed")
	_attack("released")  # step 1 lands, cooldown STEP_FIRE_INTERVAL armed
	var early := _attack("pressed")  # 12 ticks early, tap buffer is 4
	assert_eq(_of(early, "attack_rejected")[0].payload.reason, "on_cooldown")
	_attack("released")
	var events := _idle(STEP_FIRE_INTERVAL + 4)
	assert_eq(_of(events, "hit").size(), 0, "a press released before eligibility is dropped, exactly as before")


# --- invalidation -----------------------------------------------------------------------

func test_6_shield_activation_clears_the_pending_hold() -> void:
	_fire_charge()
	_attack("pressed")
	assert_true(_held_intent_queued())
	_attack_and_block("held", true)  # shield raised while the button is still down
	assert_false(_held_intent_queued(), "the rising edge discards the queued intent")
	for _i in range(CHARGE_WINDUP + CHARGE_LUNGE_DURATION + CHARGE_FIRE_INTERVAL + 5):
		_attack_and_block("held", true)
		assert_ne(_state(), "charging", "no attack may open while blocking")


func test_7_a_press_while_blocking_leaves_no_intent_behind() -> void:
	_block(true)
	var events := _attack_and_block("pressed", true)
	assert_eq(_of(events, "attack_rejected")[0].payload.reason, "blocking")
	assert_false(_held_intent_queued(), "a blocked press is refused outright, not remembered")
	_attack_and_block("held", true)
	assert_eq(_state(), "", "and holding on never opens anything behind the shield")


func test_8_weapon_switch_clears_the_pending_hold() -> void:
	_fire_charge()
	_attack("pressed")
	assert_true(_held_intent_queued())
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "switch_weapon")], DT)
	assert_false(_held_intent_queued(), "a switch clears all attack-input state, held intent included")


func test_9_death_clears_the_pending_hold() -> void:
	sim.register_combatant(ATTACKER_ID, 10.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(ENEMY_ID, Vector3(0.0, 0.0, 1.0), 0.0)
	sim.register_combatant(ENEMY_ID, 999.0, &"test_enemy")
	sim.register_weapon(&"lethal", 50.0, &"force", 2.0, 60.0, 0.0)
	sim.set_equipped_weapon(ENEMY_ID, &"lethal")
	_fire_charge()
	_attack("pressed")
	assert_true(_held_intent_queued())
	var events := sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	assert_eq(_of(events, "died").size(), 1, "sanity: the attacker died")
	assert_false(_held_intent_queued(), "death clears it")


# --- never autofire ---------------------------------------------------------------------

func test_10_held_reports_alone_never_create_intent_after_a_charge_fires() -> void:
	_fire_charge()
	# No new press: envoy.gd would never send these without one, but a client message is a
	# request (§4.2), so the sim must not infer a press from a bare held stream either.
	for _i in range(CHARGE_WINDUP + CHARGE_LUNGE_DURATION + CHARGE_FIRE_INTERVAL + 5):
		_attack("held")
		assert_false(_held_intent_queued())
	assert_eq(_state(), "", "no hold opened: a charge never repeats itself")


func test_11_held_intent_is_one_slot_and_never_materializes_a_tap() -> void:
	_fire_charge()
	_attack("pressed")
	var second := _attack("pressed")  # a phantom second rising edge while queued
	assert_eq(_of(second, "attack_rejected").size(), 1, "refused like any press mid-windup")
	assert_true(_held_intent_queued(), "and the queued intent is untouched -- one slot, first press owns it")
	assert_false(bool(sim.debug_describe_melee_state(ATTACKER_ID).buffered_released),
		"held intent never carries a stashed release, so it can never become a tap on its own")


# --- the tap buffer is unchanged --------------------------------------------------------

func test_12_normal_tap_buffering_still_materializes_a_queued_tap() -> void:
	_attack("pressed")
	_attack("released")  # step 1 lands, cooldown armed
	while sim.tick_count < _eligible_tick() - INPUT_BUFFER_TICKS:
		sim.tick([], DT)
	var queued := _attack("pressed")  # inside the tap window
	assert_eq(_of(queued, "attack_rejected").size(), 0, "buffered, not refused")
	assert_false(_held_intent_queued(), "this is TAP intent")
	_attack("released")
	var events := _idle(INPUT_BUFFER_TICKS + 1)
	var hits := _of(events, "hit")
	assert_eq(hits.size(), 1, "the queued tap materializes on the eligibility tick")
	assert_eq(int(hits[0].tick), _eligible_tick() - STEP_FIRE_INTERVAL, "at the cooldown's end, as before")
	assert_eq(String(hits[0].payload.attack_profile_id), "2")
