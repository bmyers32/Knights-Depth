extends GutTest
## Sword design pass (2026-10-30, GAME-RULES §3 reaction layer): the two flinch routes
## stay separate systems, pressure is SPENT by the flinch it buys, and no sword stage
## interrupts a committed enemy action merely because it landed. Synthetic profiles on
## purpose (same discipline as test_flinch.gd): these protect SIMULATION rules; the
## shipped sword mapping is pinned in test_content_validation.gd.
##
## Vocabulary used below:
##   "opener" = an exploit-capable hit (sword hits 1-2): builds pressure, never cashes it.
##   "finisher" = a pressure-capable hit (sword hit 3 / charge): cashes pressure at the
##     threshold AND exploits a vulnerable window. interrupt_strength is 0 on both.

const ATTACKER_ID := 0
const TARGET_ID := 1
const DT := 1.0 / 30.0
const TARGET_POSITION := Vector3(0, 0, -1)
const THRESHOLD := 16.0
const WINDOW := 90
const RECOVERY := 20
const CLAW_COOLDOWN := 45
const KNOCKBACK := 1.0

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


## Flat-path weapon with a patched flinch capability (the phased/gun paths carry it
## through content; register_weapon predates the field). interrupt_strength stays 0:
## nothing in this suite owns the authored bypass.
func _weapon(id: StringName, damage: float, capability: String, knockback: float = KNOCKBACK) -> void:
	sim.register_weapon(id, damage, &"force", 2.0, 60.0, knockback, 0, &"", 0.0)
	sim._weapons[String(id)].flinch_capability = capability


func _swing(id: StringName) -> Array[Event]:
	sim.set_equipped_weapon(ATTACKER_ID, id)
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)


func _idle(ticks: int = 1) -> void:
	for _i in range(ticks):
		sim.tick([], DT)


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


func _pressure() -> float:
	return float(sim.debug_describe_flinch_state(TARGET_ID).pressure)


## The target commits to a 20-tick windup whose susceptibility is authored here. The
## tick that arms it also records its start tick, so a swing on the next tick lands at
## windup offset 1.
func _arm_windup(mode: StringName, vstart: int, vend: int, windup_ticks: int = 20) -> void:
	sim.register_weapon(&"claw", 5.0, &"force", 2.0, 90.0, 0.0, CLAW_COOLDOWN)
	sim.register_action_susceptibility(&"claw", mode, vstart, vend)
	sim.register_ai(TARGET_ID, CombatTestHelpers.single_action_repertoire(&"claw", 2.0, windup_ticks), TARGET_POSITION, 2.0, 1.0, 8.0, 18.0)
	sim.debug_set_ai_active(TARGET_ID)
	sim.tick([], DT)


func _target_is_winding_up() -> bool:
	return sim._ai_attack_fire_tick.has(TARGET_ID)


# --- 1-2: openers (exploit-capable) ---------------------------------------------------

func test_1_openers_build_pressure_past_the_threshold_without_pressure_flinching() -> void:
	_weapon(&"opener", THRESHOLD, "exploit")
	var events := _swing(&"opener")
	assert_gte(_pressure(), THRESHOLD, "the opener's damage is banked")
	assert_eq(_of(events, "flinched").size(), 0, "an exploit-capable hit never cashes pressure, however much is banked")


func test_2_openers_exploit_an_authored_vulnerable_window() -> void:
	_arm_windup(&"normal", 0, 30)
	_weapon(&"opener", 1.0, "exploit")
	var flinched := _of(_swing(&"opener"), "flinched")
	assert_eq(flinched.size(), 1, "inside the window a weak opener punishes")
	assert_eq(flinched[0].payload.reason, "exploit")


# --- 3-4: the finisher's bypass is gone ------------------------------------------------

func test_3_finisher_under_threshold_does_not_interrupt_a_normal_windup_merely_by_landing() -> void:
	_arm_windup(&"normal", -1, -1)
	_weapon(&"finisher", THRESHOLD - 1.0, "pressure")
	var before: Vector3 = sim.entities[TARGET_ID]
	var events := _swing(&"finisher")
	assert_eq(_of(events, "hit").size(), 1, "sanity: the hit landed")
	assert_eq(_of(events, "flinched").size(), 0, "no pressure, no vulnerability -> no flinch")
	assert_eq(_of(events, "windup_interrupted").size(), 0, "landing is not an interrupt any more (interrupt_strength 0)")
	assert_true(_target_is_winding_up(), "the committed action is still running")
	assert_eq(sim.entities[TARGET_ID], before, "a winding-up target that was not interrupted is not displaced either")


func test_4_finisher_at_threshold_pressure_flinches_and_interrupts_the_normal_windup() -> void:
	_arm_windup(&"normal", -1, -1)
	_weapon(&"finisher", THRESHOLD, "pressure")
	var before: Vector3 = sim.entities[TARGET_ID]
	var events := _swing(&"finisher")
	var flinched := _of(events, "flinched")
	assert_eq(flinched.size(), 1)
	assert_eq(flinched[0].payload.reason, "pressure")
	assert_eq(_of(events, "windup_interrupted").size(), 1, "the flinch route cancels the windup")
	assert_false(_target_is_winding_up())
	assert_almost_eq(sim.entities[TARGET_ID].distance_to(before), KNOCKBACK, 0.001,
		"knockback follows the CANCEL: a flinch that interrupts a windup also displaces (2026-10-30 coupling)")


# --- 5-6: pressure is spent by the flinch it bought ------------------------------------

func test_5_a_pressure_flinch_spends_the_pressure() -> void:
	_weapon(&"finisher", THRESHOLD, "pressure")
	assert_eq(_of(_swing(&"finisher"), "flinched").size(), 1, "sanity: cashed out")
	assert_almost_eq(_pressure(), 0.0, 0.001, "the bank is empty after a pressure flinch")


func test_6_the_next_pressure_flinch_needs_newly_accumulated_pressure() -> void:
	_weapon(&"finisher", THRESHOLD, "pressure", 0.0)  # no knockback: three swings must all stay in reach
	_weapon(&"small_finisher", THRESHOLD / 2.0, "pressure", 0.0)
	assert_eq(_of(_swing(&"finisher"), "flinched").size(), 1, "first cash-out")
	_idle(RECOVERY + 1)  # past the flinched state, well inside the 90-tick pressure window
	assert_eq(_of(_swing(&"small_finisher"), "flinched").size(), 0,
		"half a threshold of NEW pressure is not enough -- the spent bank does not count")
	assert_eq(_of(_swing(&"small_finisher"), "flinched").size(), 1,
		"two halves rebuilt past the threshold: the next pressure flinch is earned again")


# --- 7-8: exploit route is independent of the bank -------------------------------------

func test_7_finisher_in_a_vulnerable_window_flinches_below_the_threshold() -> void:
	_arm_windup(&"normal", 0, 30)
	_weapon(&"finisher", 1.0, "pressure")
	var flinched := _of(_swing(&"finisher"), "flinched")
	assert_eq(flinched.size(), 1)
	assert_eq(flinched[0].payload.reason, "exploit", "vulnerability is checked first")


func test_8_an_exploit_flinch_spends_no_pressure() -> void:
	_weapon(&"bank", THRESHOLD / 2.0, "none")
	_swing(&"bank")
	var banked: float = _pressure()
	assert_gt(banked, 0.0, "sanity: something is banked below the threshold")
	_arm_windup(&"normal", 0, 30)
	_weapon(&"finisher", 1.0, "pressure")
	assert_eq(_of(_swing(&"finisher"), "flinched")[0].payload.reason, "exploit")
	assert_almost_eq(_pressure(), banked + 1.0, 0.001,
		"the exploit flinch left the bank alone and this hit's own contribution was still recorded")


# --- 9-10: the charge follows the same model (phased path, content-shaped profiles) -----

func _register_phased_sword_with_pressure_charge() -> void:
	var step: Dictionary = {
		"damage": 1.0, "damage_type": &"force", "reach": 2.0, "cone_half_angle_degrees": 60.0,
		"knockback_distance": KNOCKBACK, "fire_interval_ticks": 0, "status_id": &"", "status_proc_chance": 0.0,
		"interrupt_strength": 0, "flinch_capability": &"exploit",
	}
	var charge: Dictionary = step.duplicate()
	charge.damage = THRESHOLD
	charge.flinch_capability = &"pressure"
	sim.register_melee_profiles(&"sword", [step.duplicate(), step.duplicate(), step.duplicate()], charge, 3, 50)
	sim.set_equipped_weapon(ATTACKER_ID, &"sword")


func _charge_release() -> Array[Event]:
	var aim := Vector3(0, 0, -1)
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "pressed"})], DT)
	for _i in range(3):
		sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "held"})], DT)
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "released"})], DT)


func test_9_charge_cashes_pressure_and_spends_it() -> void:
	_register_phased_sword_with_pressure_charge()
	var events := _charge_release()
	assert_eq(_of(events, "hit")[0].payload.attack_profile_id, "charge", "sanity: the charge fired")
	assert_eq(_of(events, "flinched")[0].payload.reason, "pressure")
	assert_almost_eq(_pressure(), 0.0, 0.001, "spent")


func test_10_charge_exploits_a_vulnerable_window_without_its_bypass() -> void:
	_register_phased_sword_with_pressure_charge()
	_arm_windup(&"normal", 0, 30)
	var events := _charge_release()
	var flinched := _of(events, "flinched")
	assert_eq(flinched.size(), 1)
	assert_eq(flinched[0].payload.reason, "exploit")
	assert_eq(_of(events, "windup_interrupted").size(), 1, "the window, not interrupt_strength, cancelled the action")


# --- 11-12: precedence and the interrupted enemy's cooldown ----------------------------

func test_11_both_routes_satisfiable_yields_exactly_one_flinch_and_keeps_the_bank() -> void:
	_arm_windup(&"normal", 0, 30)
	_weapon(&"finisher", THRESHOLD, "pressure")
	var events := _swing(&"finisher")
	assert_eq(_of(events, "flinched").size(), 1, "never two flinch events for one hit")
	assert_eq(_of(events, "flinched")[0].payload.reason, "exploit", "deterministic precedence: vulnerability wins")
	assert_eq(_of(events, "windup_interrupted").size(), 1, "and the action is cancelled exactly once")
	assert_gte(_pressure(), THRESHOLD, "an exploit flinch spends nothing, even with a full bank")


func test_12_a_real_interrupt_still_arms_the_enemy_cooldown_of_the_cancelled_action() -> void:
	_arm_windup(&"normal", -1, -1)
	_weapon(&"finisher", THRESHOLD, "pressure")
	var events := _swing(&"finisher")
	assert_eq(_of(events, "windup_interrupted").size(), 1, "sanity: a pressure interrupt")
	assert_eq(int(sim._next_fire_tick[TARGET_ID]), sim.tick_count - 1 + CLAW_COOLDOWN,
		"pending fire tick cleared -> the cancelled action's own cooldown, counted from the interrupt tick")


func test_13_protected_action_rejects_the_finisher_entirely() -> void:
	_arm_windup(&"protected", -1, -1)
	_weapon(&"finisher", THRESHOLD * 2.0, "pressure")
	var before: Vector3 = sim.entities[TARGET_ID]
	var events := _swing(&"finisher")
	assert_eq(_of(events, "flinched").size(), 0)
	assert_eq(_of(events, "windup_interrupted").size(), 0, "PROTECTED means shield or disengage -- no bypass exists to override it")
	assert_eq(sim.entities[TARGET_ID], before)
	assert_gte(_pressure(), THRESHOLD, "pressure that could not be cashed is kept, not spent")
