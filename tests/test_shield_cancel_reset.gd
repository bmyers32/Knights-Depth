extends GutTest
## Shield cancel is a SEQUENCE RESET (sword design pass, 2026-10-30, GAME-RULES §3).
## Raising the shield abandons the current sword sequence: whatever the cancelled or
## already-landed swing earned stays earned (hit, status, flinch, its cooldown), but
## the next legal sword attack is H1. This suite exists to keep the three sword
## techniques distinct and hard to erase by accident:
##   BEAT         pause inside the combo window           -> step preserved
##   CHARGE-STEP  hold under the threshold, walk, release -> step preserved
##   SHIELD CANCEL defend                                  -> step reset, commitment kept
## Combo-window expiry is the fourth, independent reset and is pinned here too so a
## future change to one cannot silently masquerade as another.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"test_reset_sword"
const TARGET_POSITION := Vector3(0.3, 0, -1)
const DT := 1.0 / 30.0

const CHARGE_THRESHOLD := 8
const COMBO_RESET := 30
const FIRE_INTERVAL := 6  # every step arms this cooldown -- the commitment a cancel must keep
const HIT_ACTIVE_TICKS := 2  # a release opens an executing swing whose hit lands 2 ticks later
const LUNGE_DURATION_TICKS := 4


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	sim.register_combatant(TARGET_ID, 999.0, &"test_target")
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	var combo_profiles: Array[Dictionary] = [_profile(5.0), _profile(5.0), _profile(5.0)]
	sim.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), CHARGE_THRESHOLD, COMBO_RESET)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _profile(damage: float) -> Dictionary:
	return {
		"damage": damage, "damage_type": &"force", "reach": 2.0, "cone_half_angle_degrees": 60.0,
		"knockback_distance": 0.0, "fire_interval_ticks": FIRE_INTERVAL, "status_id": &"", "status_proc_chance": 0.0,
		"lunge_distance": 0.0, "lunge_duration_ticks": LUNGE_DURATION_TICKS, "hit_active_ticks": HIT_ACTIVE_TICKS, "windup_ticks": 0,
	}


func _attack(phase: String) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": phase})], DT)


func _block(held: bool) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": held})], DT)


func _idle(ticks: int) -> Array[Event]:
	var events: Array[Event] = []
	for _i in range(ticks):
		events.append_array(sim.tick([], DT))
	return events


func _hits(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "hit")


func _rejections(events: Array[Event], reason: String) -> Array:
	return events.filter(func(e): return e.kind == "attack_rejected" and e.payload.reason == reason)


## Press + release, then run the swing to its end so the hit has resolved and the
## cooldown is armed by the swing itself. Returns the step id that landed.
func _land_step() -> String:
	_attack("pressed")
	var events := _attack("released")
	events.append_array(_idle(LUNGE_DURATION_TICKS))
	var hits := _hits(events)
	assert_eq(hits.size(), 1, "a tapped step must land exactly once")
	return String(hits[0].payload.attack_profile_id)


## Wait out whatever cooldown is armed, then land the next step and return its id.
func _next_step_after_cooldown() -> String:
	while sim.tick_count < int(sim._next_fire_tick.get(ATTACKER_ID, 0)):
		sim.tick([], DT)
	return _land_step()


# --- 1: pre-hit cancel -------------------------------------------------------------------

func test_1_pre_hit_cancel_lands_nothing_and_resets_to_H1() -> void:
	assert_eq(_land_step(), "1")
	_idle(FIRE_INTERVAL)  # serve H1's cooldown so H2 can open
	_attack("pressed")
	var release_events := _attack("released")  # H2 opens executing; its hit is 2 ticks away
	assert_eq(_hits(release_events).size(), 0, "sanity: the hit has not resolved yet")
	var block_events := _block(true)  # cancels before the hit tick
	assert_eq(_hits(block_events).size(), 0, "a pre-hit cancel lands no hit")
	assert_eq(block_events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 1)
	assert_eq(_hits(_idle(LUNGE_DURATION_TICKS)).size(), 0, "and nothing resolves later either")
	_block(false)
	assert_eq(_next_step_after_cooldown(), "1", "the sequence was abandoned: H1, not H2 and not H3")


# --- 2-3: post-hit cancel keeps the hit, resets the sequence ------------------------------

func test_2_post_H1_cancel_keeps_H1_and_the_next_legal_attack_is_H1() -> void:
	assert_eq(_land_step(), "1")
	var health_after_h1: float = sim._health[TARGET_ID]
	_block(true)
	_block(false)
	assert_eq(sim._health[TARGET_ID], health_after_h1, "the landed hit stands -- nothing is refunded or duplicated")
	assert_eq(_next_step_after_cooldown(), "1", "post-hit shield cancel resets the sequence")


func test_3_post_H2_cancel_keeps_H2_and_the_next_legal_attack_is_H1() -> void:
	assert_eq(_land_step(), "1")
	assert_eq(_next_step_after_cooldown(), "2")
	_block(true)
	_block(false)
	assert_eq(_next_step_after_cooldown(), "1", "not H3: the shield abandoned the sequence")


# --- 4-5: commitment is never refunded ----------------------------------------------------

func test_4_cooldown_stays_armed_after_a_post_hit_cancel() -> void:
	_attack("pressed")
	var events := _attack("released")
	events.append_array(_idle(HIT_ACTIVE_TICKS))
	assert_eq(_hits(events).size(), 1, "sanity: hit resolved, swing still in recovery")
	var cancel_tick: int = sim.tick_count
	_block(true)  # cancels the remaining recovery
	assert_eq(int(sim._next_fire_tick[ATTACKER_ID]), cancel_tick + FIRE_INTERVAL,
		"the cancelled swing's own cooldown is armed from the cancel tick")
	_block(false)
	var early := _attack("pressed")
	assert_eq(_rejections(early, "on_cooldown").size(), 1, "an attack inside that cooldown is refused")
	_attack("released")
	assert_eq(_hits(_idle(LUNGE_DURATION_TICKS)).size(), 0, "and nothing sneaks out of the refusal")


func test_5_shield_cancel_never_produces_a_free_immediate_opener() -> void:
	assert_eq(_land_step(), "1")
	var cancel_tick: int = sim.tick_count
	_block(true)
	_block(false)
	var first_hit_tick: int = -1
	var budget: int = FIRE_INTERVAL + LUNGE_DURATION_TICKS + 10
	while first_hit_tick < 0 and budget > 0:
		_attack("pressed")
		var events := _attack("released")
		for e in events:
			if e.kind == "hit":
				first_hit_tick = int(e.tick)
		budget -= 1
	assert_gt(first_hit_tick, 0, "an H1 eventually lands")
	assert_gte(first_hit_tick, cancel_tick + FIRE_INTERVAL,
		"the reset H1 is only legal once the cancelled swing's commitment has been served")


# --- 6-8: the techniques that are NOT resets ----------------------------------------------

func test_6_beat_without_shield_preserves_the_step() -> void:
	assert_eq(_land_step(), "1")
	_idle(COMBO_RESET - LUNGE_DURATION_TICKS - 2)  # a long pause, still inside the window
	assert_eq(_land_step(), "2", "BEAT: pausing inside the window keeps the step")


func test_7_charge_step_without_shield_preserves_the_step() -> void:
	assert_eq(_land_step(), "1")
	_idle(FIRE_INTERVAL)
	_attack("pressed")
	for _i in range(CHARGE_THRESHOLD - 2):  # hold under the threshold, moving freely all the while
		sim.tick([
			Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "held"}),
			Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3(0, 0, -1)}),
		], DT)
	var events := _attack("released")
	events.append_array(_idle(LUNGE_DURATION_TICKS))
	assert_eq(String(_hits(events)[0].payload.attack_profile_id), "2", "CHARGE-STEP: the preserved step fires on release")


func test_8_combo_expiry_still_resets_on_its_own() -> void:
	assert_eq(_land_step(), "1")
	_idle(COMBO_RESET + 1)
	assert_eq(_land_step(), "1", "window expiry resets independently of any shield")


func test_9_the_three_techniques_read_differently_from_the_same_H2() -> void:
	# Same start: H1 then H2 landed, cooldown served.
	assert_eq(_land_step(), "1")
	assert_eq(_next_step_after_cooldown(), "2")
	# Shield cancel -> H1.
	_block(true)
	_block(false)
	assert_eq(_next_step_after_cooldown(), "1")
	assert_eq(_next_step_after_cooldown(), "2")
	# Beat -> H3.
	_idle(FIRE_INTERVAL)
	assert_eq(_land_step(), "3", "the same pause without the shield continues the sequence")
