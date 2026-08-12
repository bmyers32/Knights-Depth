extends GutTest
## Flinch/pressure reaction layer (GAME-RULES §3 batch). Mechanical laws only —
## tuning is validated by playtest, never encoded as arithmetic assertions across
## profiles. Synthetic profiles here on purpose: these tests protect the SIMULATION
## rules; real-content behavior is protected by the named integration fixtures.

const ATTACKER_ID := 0
const TARGET_ID := 1
const DT := 1.0 / 30.0
const TARGET_POSITION := Vector3(0, 0, -1)
const THRESHOLD := 16.0
const WINDOW := 90
const RECOVERY := 20

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	sim.register_combatant(TARGET_ID, 999.0, &"test_target")
	sim.register_flinch_profile(TARGET_ID, THRESHOLD)
	sim.set_flinch_tuning(WINDOW, RECOVERY)
	sim.set_damage_matrix({}, 1.5, 0.5)


func _weapon(id: StringName, damage: float, capability: String, contributes: bool = true) -> void:
	sim.register_weapon(id, damage, &"force", 2.0, 60.0, 0.0, 0, &"", 0.0)
	# register_weapon has no flinch params (flat legacy path) -- patch the resolved
	# profile directly, which is what the phased/gun paths do through content.
	sim._weapons[String(id)].flinch_capability = capability
	sim._weapons[String(id)].contributes_pressure = contributes


func _swing(id: StringName) -> Array[Event]:
	sim.set_equipped_weapon(ATTACKER_ID, id)
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)


func _idle(ticks: int = 1) -> void:
	for _i in range(ticks):
		sim.tick([], DT)


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- pressure accounting -----------------------------------------------------------

func test_contribution_eligible_damage_builds_pressure() -> void:
	_weapon(&"w", 8.0, "none")
	_swing(&"w")
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 8.0, 0.001)


func test_non_contributing_hit_builds_no_pressure() -> void:
	_weapon(&"w", 8.0, "pressure", false)
	_swing(&"w")
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 0.0, 0.001,
		"contribution eligibility is independent of trigger capability")


func test_resisted_and_amplified_hits_contribute_their_ACTUAL_damage() -> void:
	sim.set_damage_matrix({"test_target": {"weak_to": "arc", "resists": "force"}}, 1.5, 0.5)
	_weapon(&"w", 8.0, "none")
	_swing(&"w")
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 4.0, 0.001,
		"pressure is post-mitigation actual HP damage, not the weapon's authored damage")


func test_blocked_damage_never_contributes() -> void:
	sim.register_shield(TARGET_ID, 100.0, 0.0, 10, 0.0)
	sim.tick([Command.new(sim.tick_count, TARGET_ID, "block", {"held": true})], DT)
	_weapon(&"w", 8.0, "none")
	_swing(&"w")
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 0.0, 0.001)


func test_status_dot_damage_never_contributes() -> void:
	sim.register_status(&"burn", 2.0, 1, 30)
	sim.set_status_priority({"burn": 0})
	sim._status_instances[TARGET_ID] = {"id": "burn", "ticks_remaining": 30, "next_tick": sim.tick_count, "applied_tick": -1}
	_idle(10)
	assert_lt(sim._health[TARGET_ID], 999.0, "sanity: the DoT is actually ticking")
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 0.0, 0.001,
		"only direct contribution-eligible hits build pressure")


func test_contributions_expire_on_their_own_ticks() -> void:
	_weapon(&"w", 8.0, "none")
	_swing(&"w")
	_idle(WINDOW - 2)
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 8.0, 0.001, "still live one tick before expiry")
	_idle(2)
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 0.0, 0.001, "expired on its own tick")


func test_healing_never_reduces_recorded_pressure() -> void:
	_weapon(&"w", 8.0, "none")
	_swing(&"w")
	sim._health[TARGET_ID] = 999.0  # full heal
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 8.0, 0.001,
		"pressure is a recorded fact, never derived from max_hp - current_hp")


## Pressure RECORDS die with the actor; the registered threshold does not — it is
## setup data like max_health, so a re-registered actor is still flinchable. (The
## min(damage, hp_before) overkill clamp keeps that accounting deterministic, but is
## unobservable after death by construction, which is precisely why it exists.)
func test_pressure_records_die_with_the_actor_but_registration_survives() -> void:
	_weapon(&"w", 8.0, "none")
	_swing(&"w")
	assert_gt(sim.debug_describe_flinch_state(TARGET_ID).pressure, 0.0, "sanity: pressure banked")
	sim._health[TARGET_ID] = 3.0
	_weapon(&"lethal", 50.0, "none")
	assert_eq(_of(_swing(&"lethal"), "died").size(), 1)
	assert_false(sim._pressure_contributions.has(TARGET_ID), "contributions die with the actor")
	assert_almost_eq(sim.debug_describe_flinch_state(TARGET_ID).pressure, 0.0, 0.001)


# --- capability routing ------------------------------------------------------------

func test_capability_none_never_flinches_even_at_threshold() -> void:
	_weapon(&"w", 8.0, "none")
	_swing(&"w"); _swing(&"w"); _swing(&"w")
	assert_gte(sim.debug_describe_flinch_state(TARGET_ID).pressure, THRESHOLD, "sanity: threshold reached")
	assert_eq(_of(_swing(&"w"), "flinched").size(), 0)


func test_pressure_capability_cashes_out_at_threshold() -> void:
	_weapon(&"builder", 8.0, "exploit")
	_weapon(&"finisher", 8.0, "pressure")
	_swing(&"builder")
	var events := _swing(&"finisher")  # 8 + 8 = 16 >= threshold, counted before routing
	var flinched := _of(events, "flinched")
	assert_eq(flinched.size(), 1)
	assert_eq(flinched[0].payload.reason, "pressure")


func test_threshold_readiness_is_not_cash_out() -> void:
	_weapon(&"builder", 8.0, "exploit")
	_swing(&"builder")
	var events := _swing(&"builder")  # crosses threshold, but exploit never cashes
	assert_eq(_of(events, "flinched").size(), 0,
		"an exploit hit that crosses the threshold BANKS it for the next pressure hit")
	assert_true(sim.debug_describe_flinch_state(TARGET_ID).threshold_reached)
	_weapon(&"finisher", 1.0, "pressure")
	assert_eq(_of(_swing(&"finisher"), "flinched").size(), 1, "the banked pressure is still there to cash")


func test_current_hit_damage_counts_toward_its_own_cash_out() -> void:
	_weapon(&"big", THRESHOLD, "pressure")
	assert_eq(_of(_swing(&"big"), "flinched").size(), 1,
		"pressure is recorded BEFORE route selection, so one big hit can cash itself out")


func test_successful_flinch_does_not_consume_pressure() -> void:
	_weapon(&"big", THRESHOLD, "pressure")
	_swing(&"big")
	assert_gte(sim.debug_describe_flinch_state(TARGET_ID).pressure, THRESHOLD,
		"contributions leave only by expiring, never by being spent")


# --- vulnerability windows ---------------------------------------------------------

func _arm_windup(mode: StringName, vstart: int, vend: int, windup_ticks: int = 20) -> void:
	sim.register_weapon(&"claw", 5.0, &"force", 2.0, 90.0, 0.0, 45)
	sim.register_action_susceptibility(&"claw", mode, vstart, vend)
	sim.register_ai(TARGET_ID, &"claw", TARGET_POSITION, 2.0, 1.0, windup_ticks, 8.0, 18.0)
	sim.debug_set_ai_active(TARGET_ID)
	sim.tick([], DT)  # AI commits to a windup, recording its start tick


func test_exploit_flinches_only_inside_the_authored_window() -> void:
	_arm_windup(&"normal", 13, 20)
	_weapon(&"weak", 1.0, "exploit")
	assert_eq(_of(_swing(&"weak"), "flinched").size(), 0, "outside the window: no flinch")
	_idle(14)
	assert_eq(_of(_swing(&"weak"), "flinched").size(), 1, "inside the window: a weak hit punishes")


func test_protected_action_rejects_every_flinch_route() -> void:
	_arm_windup(&"protected", -1, -1)
	_weapon(&"big", THRESHOLD * 2.0, "pressure")
	assert_eq(_of(_swing(&"big"), "flinched").size(), 0,
		"PROTECTED means shield or disengage -- never interrupt")


func test_vulnerability_wins_the_reported_reason_but_pressure_is_still_recorded() -> void:
	_arm_windup(&"normal", 0, 30)
	_weapon(&"big", THRESHOLD, "pressure")
	var flinched := _of(_swing(&"big"), "flinched")
	assert_eq(flinched[0].payload.reason, "exploit", "routes short-circuit vulnerability-first")
	assert_gte(sim.debug_describe_flinch_state(TARGET_ID).pressure, THRESHOLD,
		"the hit's contribution is recorded regardless of which route reported")


func test_canceling_an_action_clears_its_vulnerability() -> void:
	_arm_windup(&"normal", 0, 30)
	_weapon(&"weak", 1.0, "exploit")
	_swing(&"weak")  # flinches via the window, which cancels the windup
	assert_eq(sim.debug_describe_flinch_state(TARGET_ID).action_mode, "normal",
		"FLINCHED must not inherit the canceled action's susceptibility")


# --- flinched state ----------------------------------------------------------------

func test_flinched_enemy_yields_no_commands_then_recovers_on_the_exact_tick() -> void:
	_arm_windup(&"normal", 0, 30)
	_weapon(&"weak", 1.0, "exploit")
	var flinched := _of(_swing(&"weak"), "flinched")
	var until: int = flinched[0].payload.until_tick
	var moved_while_flinched: int = 0
	while sim.tick_count < until:
		moved_while_flinched += _of(sim.tick([], DT), "moved").size()
	assert_eq(moved_while_flinched, 0, "no ordinary approach/retreat movement while FLINCHED")
	assert_eq(sim.debug_describe_flinch_state(TARGET_ID).flinched_ticks_left, 0)


func test_re_flinch_registers_but_does_not_extend_the_deadline() -> void:
	_arm_windup(&"normal", 0, 60)
	_weapon(&"weak", 1.0, "exploit")
	var first: int = _of(_swing(&"weak"), "flinched")[0].payload.until_tick
	_idle(3)
	sim._ai_attack_start_tick[TARGET_ID] = sim.tick_count  # re-enter a vulnerable action
	var second := _of(_swing(&"weak"), "flinched")
	assert_eq(second.size(), 1, "a qualifying re-flinch still registers")
	assert_eq(int(second[0].payload.until_tick), first, "but must NOT extend the deadline")
	assert_false(second[0].payload.extended)


func test_interrupted_attack_cooldown_runs_concurrently_with_recovery() -> void:
	_arm_windup(&"normal", 0, 30)
	_weapon(&"weak", 1.0, "exploit")
	_swing(&"weak")
	var cooldown_deadline: int = int(sim._next_fire_tick.get(TARGET_ID, 0))
	var recovery_deadline: int = int(sim._flinched_until_tick.get(TARGET_ID, 0))
	assert_gt(cooldown_deadline, 0, "an interrupted attack arms the normal post-attack cooldown")
	# Both are ABSOLUTE deadlines in one tick space, so they run concurrently: denial
	# ends at the later of the two, strictly earlier than if recovery were appended to
	# the cooldown. Failing this would mean flinch had silently become additive.
	assert_lt(max(cooldown_deadline, recovery_deadline), cooldown_deadline + RECOVERY,
		"effective denial must be max(recovery, cooldown), never the sum")


func test_only_one_windup_interrupted_event_when_a_hit_both_interrupts_and_flinches() -> void:
	_arm_windup(&"normal", 0, 30)
	sim.register_weapon(&"heavy", 1.0, &"force", 2.0, 60.0, 0.0, 0, &"", 0.0)
	sim._weapons["heavy"].flinch_capability = "exploit"
	sim._weapons["heavy"].interrupt_strength = 1
	var events := _swing(&"heavy")
	assert_eq(_of(events, "windup_interrupted").size(), 1, "the action is canceled exactly once")
	assert_eq(_of(events, "flinched").size(), 1)


func test_dead_actor_is_never_functionally_flinched() -> void:
	_arm_windup(&"normal", 0, 30)
	sim._health[TARGET_ID] = 1.0
	_weapon(&"lethal", 50.0, "exploit")
	var events := _swing(&"lethal")
	assert_eq(_of(events, "died").size(), 1)
	assert_eq(_of(events, "flinched").size(), 0, "death supersedes flinch")
	assert_false(sim._flinched_until_tick.has(TARGET_ID))


func test_unflinchable_actor_accumulates_no_pressure_at_all() -> void:
	var envoy_id: int = 5
	sim.add_entity(envoy_id, Vector3(0, 0, -1), 0.0)
	sim.register_combatant(envoy_id, 100.0, &"envoy", 0, 0.0, &"enemy")  # no flinch profile
	_weapon(&"w", 8.0, "pressure")
	_swing(&"w")
	assert_eq(sim.debug_describe_flinch_state(envoy_id), {},
		"an actor outside the reaction layer is distinct from one with zero pressure")


# --- determinism / lint ------------------------------------------------------------

func test_flinch_outcomes_are_deterministic_for_identical_inputs() -> void:
	var outcomes: Array = []
	for _run in range(2):
		var s := SimWorld.new()
		s.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		s.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
		s.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
		s.register_combatant(TARGET_ID, 999.0, &"test_target")
		s.register_flinch_profile(TARGET_ID, THRESHOLD)
		s.set_flinch_tuning(WINDOW, RECOVERY)
		s.set_damage_matrix({}, 1.5, 0.5)
		s.register_weapon(&"w", 8.0, &"force", 2.0, 60.0, 0.0, 0, &"", 0.0)
		s._weapons["w"].flinch_capability = "pressure"
		s.set_equipped_weapon(ATTACKER_ID, &"w")
		var log: Array = []
		for _i in range(4):
			for event in s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT):
				if event.kind == "flinched":
					log.append([event.tick, event.payload.reason, event.payload.until_tick])
		outcomes.append(log)
	assert_eq(outcomes[0], outcomes[1])


func test_unknown_capability_is_rejected_to_none_at_registration() -> void:
	var profiles: Array[Dictionary] = []
	for _i in range(3):
		profiles.append({
			"damage": 5.0, "damage_type": &"force", "reach": 2.0, "cone_half_angle_degrees": 60.0,
			"knockback_distance": 0.0, "fire_interval_ticks": 0, "status_id": &"", "status_proc_chance": 0.0,
			"flinch_capability": "wildly_invalid",
		})
	sim.register_melee_profiles(&"bad", profiles, profiles[0], 5, 10)
	assert_eq(sim._melee_combo_profiles["bad"][0].flinch_capability, "none",
		"unknown enum values must be rejected to the safe default, never silently kept")
