extends GutTest
## Combat RNG / status proc chance (GAME-RULES §1.3's first concrete consumer) —
## locked roll-consumption rule: a roll happens only after a hit passes every
## validation/defense gate and is status-eligible; blocked/absorbed/missed/rejected
## attacks draw nothing; a LETHAL eligible hit still consumes exactly one roll
## (the stream must never advance based on victim health); chance 0.0/1.0
## short-circuit without drawing. Burn's DoT/expiry/refresh mechanics (deterministic,
## chance=1.0) live in test_burn.gd; this file is the proc/RNG mechanism itself.

var sim: SimWorld

const ATTACKER_ID := 0
const WEAPON_ID := &"sword_burn_test"
const TARGET_FAMILY := &"test_target"  # absent from the matrix -> multiplier always 1.0
const TARGET_POSITION := Vector3(0, 0, -1)  # directly ahead of the attacker's default facing
const SEED := 1337


func _fresh_sim(chance: float = 0.5) -> SimWorld:
	var s := SimWorld.new()
	s.seed_combat_rng(SEED)
	s.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	# Ally-filtering (locked defect fix): the attacker needs an allegiance different
	# from the target's (default "enemy") or every attack below filters as allied.
	s.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	s.register_weapon(WEAPON_ID, 10.0, &"force", 2.0, 60.0, 1.0, 0, &"burn", chance)
	s.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	s.set_damage_matrix({}, 1.5, 0.5)
	s.register_status(&"burn", 4.0, 15, 90)
	s.set_status_priority({"burn": 0})
	return s


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


## Attacks a fresh target at TARGET_POSITION with WEAPON_ID's currently-equipped
## weapon, then moves that target far out of range so it never interferes with a
## later attack in the same sequence -- lets one SimWorld accumulate a clean,
## one-draw-per-attack sequence against a series of otherwise-untouched targets.
func _attack_fresh_target(s: SimWorld, target_id: int, max_health: float = 100.0) -> Array[Event]:
	s.add_entity(target_id, TARGET_POSITION, 0.0)
	s.register_combatant(target_id, max_health, TARGET_FAMILY, 0, 0.0, &"enemy")
	var events := s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	s.entities[target_id] = Vector3(1000.0, 0.0, 0.0)
	return events


# --- Event vocabulary ---

func test_hit_emits_a_single_status_proc_event_with_chance_and_result() -> void:
	var s := _fresh_sim(0.5)
	var events := _attack_fresh_target(s, 1)
	var proc := _events_of_kind(events, "status_proc")
	assert_eq(proc.size(), 1, "exactly one status_proc kind, never separate attempted/succeeded/failed kinds")
	assert_eq(proc[0].payload.get("status_id"), "burn")
	assert_eq(proc[0].payload.get("attacker_id"), ATTACKER_ID)
	assert_eq(proc[0].payload.get("target_id"), 1)
	assert_almost_eq(proc[0].payload.get("chance"), 0.5, 0.001)
	assert_true(proc[0].payload.get("result") in ["success", "fail"])


# --- Roll-consumption gates ---

## The eligible-hit boundary asserted from the outside: a hit only reaches
## _roll_status_proc after clearing validation (rejected: cooldown) AND landing
## (missed: no target in cone/reach) AND every defense gate. Blocked/absorbed are
## covered separately below; this test is the two gates upstream of those.
func test_missed_and_rejected_attacks_draw_nothing_and_emit_no_status_proc() -> void:
	# --- MISS: no target in reach/cone ---
	var miss_baseline := _fresh_sim()
	var miss_draw1: String = _events_of_kind(_attack_fresh_target(miss_baseline, 1), "status_proc")[0].payload.get("result")
	var miss_draw2: String = _events_of_kind(_attack_fresh_target(miss_baseline, 2), "status_proc")[0].payload.get("result")

	var miss_with_gap := _fresh_sim()
	var miss_gap_draw1: String = _events_of_kind(_attack_fresh_target(miss_with_gap, 1), "status_proc")[0].payload.get("result")
	miss_with_gap.add_entity(97, Vector3(0, 0, -100), 0.0)  # far outside reach/cone
	miss_with_gap.register_combatant(97, 100.0, TARGET_FAMILY, 0, 0.0, &"enemy")
	var missed_events := miss_with_gap.tick([Command.new(miss_with_gap.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(_events_of_kind(missed_events, "hit").size(), 0)
	assert_eq(_events_of_kind(missed_events, "status_proc").size(), 0, "a missed attack must not attempt a roll")
	miss_with_gap.entities[97] = Vector3(1000.0, 0.0, 0.0)
	var miss_gap_draw2: String = _events_of_kind(_attack_fresh_target(miss_with_gap, 2), "status_proc")[0].payload.get("result")

	assert_eq(miss_draw1, miss_gap_draw1)
	assert_eq(miss_draw2, miss_gap_draw2, "a missed attack in between must not shift the subsequent proc outcome")

	# --- REJECTED: cooldown ---
	var reject_baseline := _fresh_sim()
	var reject_draw1: String = _events_of_kind(_attack_fresh_target(reject_baseline, 1), "status_proc")[0].payload.get("result")
	var reject_draw2: String = _events_of_kind(_attack_fresh_target(reject_baseline, 2), "status_proc")[0].payload.get("result")

	var reject_with_gap := _fresh_sim()
	var reject_gap_draw1: String = _events_of_kind(_attack_fresh_target(reject_with_gap, 1), "status_proc")[0].payload.get("result")
	# A long-cooldown variant, fired ONCE with no target in range at all (arms the
	# cooldown gate; can't land, so it can't draw either), then immediately re-fired
	# while still on cooldown -- isolates the rejection gate from the roll entirely.
	reject_with_gap.register_weapon(&"cooldown_burn", 10.0, &"force", 2.0, 60.0, 1.0, 1000, &"burn", 0.5)
	reject_with_gap.set_equipped_weapon(ATTACKER_ID, &"cooldown_burn")
	reject_with_gap.tick([Command.new(reject_with_gap.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	var rejected_events := reject_with_gap.tick([Command.new(reject_with_gap.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(_events_of_kind(rejected_events, "attack_rejected").size(), 1)
	assert_eq(rejected_events.filter(func(e): return e.kind == "attack_rejected")[0].payload.get("reason"), "on_cooldown")
	assert_eq(_events_of_kind(rejected_events, "status_proc").size(), 0, "a cooldown-rejected attack must not attempt a roll")
	# _next_fire_tick is keyed by actor_id, not weapon_id -- cooldown_burn's long
	# cooldown otherwise persists onto WEAPON_ID after the switch below, which would
	# reject the measurement attack too. Clearing it isolates "did the REJECTED
	# attack itself draw" from that unrelated per-actor cooldown-sharing behavior.
	reject_with_gap._next_fire_tick.erase(ATTACKER_ID)
	reject_with_gap.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	var reject_gap_draw2: String = _events_of_kind(_attack_fresh_target(reject_with_gap, 2), "status_proc")[0].payload.get("result")

	assert_eq(reject_draw1, reject_gap_draw1)
	assert_eq(reject_draw2, reject_gap_draw2, "a cooldown-rejected attack in between must not shift the subsequent proc outcome")


func test_blocked_hit_draws_nothing_and_does_not_shift_the_sequence() -> void:
	var sim_a := _fresh_sim()
	var draw1_a: String = _events_of_kind(_attack_fresh_target(sim_a, 1), "status_proc")[0].payload.get("result")
	var draw2_a: String = _events_of_kind(_attack_fresh_target(sim_a, 2), "status_proc")[0].payload.get("result")

	var sim_b := _fresh_sim()
	var draw1_b: String = _events_of_kind(_attack_fresh_target(sim_b, 1), "status_proc")[0].payload.get("result")

	sim_b.add_entity(99, TARGET_POSITION, 0.0)
	sim_b.register_combatant(99, 100.0, TARGET_FAMILY, 0, 0.0, &"enemy")
	sim_b.register_shield(99, 20.0, 1.0, 3, 2.0)
	sim_b.tick([Command.new(sim_b.tick_count, 99, "block", {"held": true})], 1.0 / 30.0)
	var blocked_events := sim_b.tick([Command.new(sim_b.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_eq(_events_of_kind(blocked_events, "blocked").size(), 1)
	assert_eq(_events_of_kind(blocked_events, "status_proc").size(), 0, "a blocked hit must not even attempt a roll")
	sim_b.entities[99] = Vector3(1000.0, 0.0, 0.0)

	var draw2_b: String = _events_of_kind(_attack_fresh_target(sim_b, 2), "status_proc")[0].payload.get("result")

	assert_eq(draw1_a, draw1_b)
	assert_eq(draw2_a, draw2_b, "a blocked hit in between must not shift the subsequent proc outcome")


func test_iframe_absorbed_hit_draws_nothing_and_does_not_shift_the_sequence() -> void:
	var sim_a := _fresh_sim()
	var draw1_a: String = _events_of_kind(_attack_fresh_target(sim_a, 1), "status_proc")[0].payload.get("result")
	var draw2_a: String = _events_of_kind(_attack_fresh_target(sim_a, 2), "status_proc")[0].payload.get("result")

	var sim_b := _fresh_sim()
	var draw1_b: String = _events_of_kind(_attack_fresh_target(sim_b, 1), "status_proc")[0].payload.get("result")

	sim_b.add_entity(99, TARGET_POSITION, 0.0)
	sim_b.register_combatant(99, 100.0, TARGET_FAMILY, 5, 0.0, &"enemy")
	sim_b._iframe_ticks_remaining[99] = 5
	var absorbed_events := sim_b.tick([Command.new(sim_b.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	assert_eq(_events_of_kind(absorbed_events, "attack_absorbed").size(), 1)
	assert_eq(_events_of_kind(absorbed_events, "status_proc").size(), 0, "an i-frame-absorbed hit must not even attempt a roll")
	sim_b.entities[99] = Vector3(1000.0, 0.0, 0.0)

	var draw2_b: String = _events_of_kind(_attack_fresh_target(sim_b, 2), "status_proc")[0].payload.get("result")

	assert_eq(draw1_a, draw1_b)
	assert_eq(draw2_a, draw2_b, "an absorbed hit in between must not shift the subsequent proc outcome")


func test_lethal_eligible_hit_consumes_exactly_one_roll() -> void:
	var sim_a := _fresh_sim()  # baseline: two non-lethal hits
	var draw1_a: String = _events_of_kind(_attack_fresh_target(sim_a, 1), "status_proc")[0].payload.get("result")
	var draw2_a: String = _events_of_kind(_attack_fresh_target(sim_a, 2), "status_proc")[0].payload.get("result")

	var sim_b := _fresh_sim()
	var lethal_events := _attack_fresh_target(sim_b, 1, 5.0)  # dies to the 10.0-damage hit
	assert_eq(_events_of_kind(lethal_events, "died").size(), 1)
	var draw1_b: String = _events_of_kind(lethal_events, "status_proc")[0].payload.get("result")
	assert_eq(_events_of_kind(lethal_events, "status_applied").size(), 0, "a lethal hit must not arm a status even if its roll succeeded")

	var draw2_b: String = _events_of_kind(_attack_fresh_target(sim_b, 2), "status_proc")[0].payload.get("result")

	assert_eq(draw1_a, draw1_b, "the lethal hit's own roll must match the non-lethal baseline's first roll")
	assert_eq(draw2_a, draw2_b, "the roll AFTER a lethal hit must match the baseline's second roll -- the lethal hit consumed exactly one draw, never zero")


# --- Chance boundaries (0.0 / 1.0 short-circuit without drawing) ---

func test_zero_chance_never_procs_and_does_not_consume_a_draw() -> void:
	var sim_a := _fresh_sim(0.5)
	var draw_a: String = _events_of_kind(_attack_fresh_target(sim_a, 1), "status_proc")[0].payload.get("result")

	var sim_b := _fresh_sim(0.5)
	sim_b.register_weapon(&"zero_chance_burn", 10.0, &"force", 2.0, 60.0, 1.0, 0, &"burn", 0.0)
	sim_b.set_equipped_weapon(ATTACKER_ID, &"zero_chance_burn")
	var zero_events := _attack_fresh_target(sim_b, 99)
	assert_eq(_events_of_kind(zero_events, "status_proc")[0].payload.get("result"), "fail")
	assert_eq(_events_of_kind(zero_events, "status_applied").size(), 0)

	sim_b.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	var draw_b: String = _events_of_kind(_attack_fresh_target(sim_b, 1), "status_proc")[0].payload.get("result")

	assert_eq(draw_a, draw_b, "a 0.0-chance proc must not consume a draw from the stream")


func test_full_chance_always_procs_and_does_not_consume_a_draw() -> void:
	var sim_a := _fresh_sim(0.5)
	var draw_a: String = _events_of_kind(_attack_fresh_target(sim_a, 1), "status_proc")[0].payload.get("result")

	var sim_b := _fresh_sim(0.5)
	sim_b.register_weapon(&"full_chance_burn", 10.0, &"force", 2.0, 60.0, 1.0, 0, &"burn", 1.0)
	sim_b.set_equipped_weapon(ATTACKER_ID, &"full_chance_burn")
	var full_events := _attack_fresh_target(sim_b, 99)
	assert_eq(_events_of_kind(full_events, "status_proc")[0].payload.get("result"), "success")
	assert_eq(_events_of_kind(full_events, "status_applied").size(), 1)

	sim_b.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	var draw_b: String = _events_of_kind(_attack_fresh_target(sim_b, 1), "status_proc")[0].payload.get("result")

	assert_eq(draw_a, draw_b, "a 1.0-chance proc must not consume a draw from the stream")


# --- Determinism ---

func test_identical_seed_produces_identical_proc_sequence() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.seed_combat_rng(SEED)
		var sequence: Array = []
		for i in range(6):
			var roll: Dictionary = local_sim._roll_status_proc(ATTACKER_ID, 1, {"status_id": "burn", "status_proc_chance": 0.5}, String(WEAPON_ID))
			sequence.append(roll.succeeded)
		results.append(sequence)
	assert_eq(results[0], results[1], "identical seed + identical draw sequence must produce identical outcomes")


func test_different_seeds_can_diverge() -> void:
	# Not a strict law (a coincidental match is possible), but pins that the seed
	# actually participates in the outcome rather than being silently ignored.
	var sim_a := SimWorld.new()
	sim_a.seed_combat_rng(1)
	var sim_b := SimWorld.new()
	sim_b.seed_combat_rng(2)
	var sequence_a: Array = []
	var sequence_b: Array = []
	for i in range(10):
		sequence_a.append(sim_a._roll_status_proc(ATTACKER_ID, 1, {"status_id": "burn", "status_proc_chance": 0.5}, "w").succeeded)
		sequence_b.append(sim_b._roll_status_proc(ATTACKER_ID, 1, {"status_id": "burn", "status_proc_chance": 0.5}, "w").succeeded)
	assert_ne(sequence_a, sequence_b, "different seeds should not coincidentally produce the same 10-roll sequence")
