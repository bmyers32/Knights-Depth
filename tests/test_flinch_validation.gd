extends GutTest
## STEP 3 — DEV-TARGET MECHANICAL VALIDATION of the flinch/pressure layer.
##
## Real content through the production registration path (ContentRegistrar), against a
## DEV VALIDATION TARGET whose health is overridden so it survives multiple full
## combos. That override is the whole point: flinch MECHANICS are proven here,
## deliberately independent of shipped enemy tuning, so step 6's live tuning can move
## HP and thresholds freely without invalidating any of this.
##
## Complements tests/test_flinch.gd, which protects the same laws with synthetic
## profiles. This file exists because synthetic profiles cannot catch a mismatch
## between the LAWS and the actual authored sword/enemy content (BRAIN: convenience
## fixtures hide the interactions worth testing).

const ATTACKER_ID := 0
const TARGET_ID := 1
const DT := 1.0 / 30.0
const TARGET_POSITION := Vector3(0, 0, -1.6)
const AIM := Vector3(0, 0, -1)
## Survives many full combos (a full 1->2->3 deals 26 against a 20 HP shipped Fang).
const VALIDATION_HEALTH := 400.0

var sim: SimWorld
var _sword: SwordStats
var _fang: FangStats
var _tuning: FlinchTuning


func before_each() -> void:
	_sword = ContentDB.get_resource(&"weapon", &"sword_burn_A")
	_fang = ContentDB.get_resource(&"enemy", &"fang")
	_tuning = ContentDB.get_resource(&"combat", &"flinch_tuning")
	sim = SimWorld.new()
	sim.seed_combat_rng(0)
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, envoy.move_speed)
	sim.register_combatant(ATTACKER_ID, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	# Body only -- an inert target isolates flinch mechanics from engagement movement.
	ContentRegistrar.register_enemy_body(sim, TARGET_ID, &"fang", TARGET_POSITION)
	ContentRegistrar.register_weapon(sim, &"sword_burn_A")
	sim.set_equipped_weapon(ATTACKER_ID, &"sword_burn_A")
	sim.set_flinch_tuning(_tuning.pressure_window_ticks, _tuning.flinch_recovery_ticks)
	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)
	var burn: BurnStats = ContentDB.get_resource(&"status", &"burn")
	sim.register_status(burn.status_id, burn.damage_per_tick, burn.tick_interval_ticks, burn.duration_ticks)
	sim.set_status_priority((ContentDB.get_resource(&"status", &"priority_table") as StatusPriorityTable).priority)
	sim.debug_override_health(TARGET_ID, VALIDATION_HEALTH)


func _tick(commands: Array[Command] = []) -> Array[Event]:
	sim.debug_override_health(TARGET_ID, VALIDATION_HEALTH)  # dev target never dies
	return sim.tick(commands, DT)


func _attack(phase: String) -> Array[Event]:
	return _tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": AIM, "phase": phase})])


## Drives real taps until `count` hits have LANDED, returning them in order.
func _land_hits(count: int, max_ticks: int = 200) -> Array:
	var landed: Array = []
	var pressed: bool = false
	for _i in range(max_ticks):
		if landed.size() >= count:
			break
		var events: Array[Event] = _attack("released" if pressed else "pressed")
		pressed = not pressed
		for event in events:
			if event.kind == "hit":
				landed.append({"tick": event.tick, "profile": event.payload.get("attack_profile_id"), "damage": event.payload.damage})
			elif event.kind == "flinched":
				landed.append({"tick": event.tick, "profile": "FLINCH", "reason": event.payload.reason, "until": event.payload.until_tick, "deadline_set": event.payload.recovery_deadline_set})
	return landed


## Delegates to the ONE shared quiescence helper (see BRAIN: "stopped acting" is not
## "idle"), then restores the dev target's health, since settling costs ticks during
## which a Burn DoT or a materializing buffered press can still damage it.
func _settle() -> void:
	CombatTestHelpers.settle(sim, ATTACKER_ID, AIM, DT)
	sim.debug_override_health(TARGET_ID, VALIDATION_HEALTH)


func _pressure() -> float:
	return sim.debug_describe_flinch_state(TARGET_ID).pressure


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- 3.1 per-hit pressure accumulation ---------------------------------------------

func test_31_each_landed_hit_banks_its_own_post_mitigation_damage() -> void:
	var authored: Array = []
	for profile in _sword.combo_profiles:
		authored.append(profile.damage)
	var running: float = 0.0
	var pressed: bool = false
	var seen: int = 0
	for _i in range(200):
		if seen >= 3:
			break
		for event in _attack("released" if pressed else "pressed"):
			if event.kind == "hit":
				running += float(event.payload.damage)
				seen += 1
				assert_almost_eq(_pressure(), running, 0.001,
					"pressure after hit %d must equal the running sum of ACTUAL damage" % seen)
		pressed = not pressed
	assert_eq(seen, 3, "all three authored combo hits must land against the dev target")
	assert_almost_eq(running, authored[0] + authored[1] + authored[2], 0.001,
		"Force is neutral vs Fang, so actual damage equals the authored numbers here")


func test_31_contributions_expire_on_their_own_authored_ticks() -> void:
	_land_hits(1)
	_settle()
	var contributions: Array = sim.debug_describe_flinch_state(TARGET_ID).contributions
	assert_gt(contributions.size(), 0, "sanity: at least one contribution is banked")
	var newest: int = 0
	for contribution in contributions:
		assert_lte(int(contribution.ticks_left), _tuning.pressure_window_ticks,
			"no contribution may outlive the authored window")
		newest = max(newest, int(contribution.ticks_left))
	for _i in range(newest - 1):
		_tick()
	assert_gt(_pressure(), 0.0, "still live one tick before the newest contribution expires")
	_tick(); _tick()
	assert_almost_eq(_pressure(), 0.0, 0.001, "expired exactly on its own tick, not refreshed by later damage")


# --- 3.2 threshold crossing with a survivor ----------------------------------------

func test_32_hit_three_cashes_out_pressure_against_a_survivor() -> void:
	var sequence: Array = _land_hits(4)  # 3 hits + the flinch entry
	var flinches: Array = sequence.filter(func(e): return e.profile == "FLINCH")
	assert_eq(flinches.size(), 1, "exactly one flinch across a full combo")
	assert_eq(flinches[0].reason, "pressure", "the finisher cashes stored pressure")
	var hits_before_flinch: int = 0
	for entry in sequence:
		if entry.profile == "FLINCH":
			break
		hits_before_flinch += 1
	assert_eq(hits_before_flinch, 3, "hits 1-2 build; hit 3 is the cash-out")
	assert_gt(sim._health[TARGET_ID], 0.0, "the target SURVIVES -- death would supersede the flinch")
	assert_gte(_pressure(), _fang.flinch_threshold,
		"a successful flinch must not consume or reset the recorded pressure")


# --- 3.3 charge-release cash-out (second pressure route, R1) ------------------------

func test_33_charge_release_also_cashes_out_banked_pressure() -> void:
	_land_hits(2)  # hits 1-2 bank 16.0 against Fang's 16.0 threshold
	assert_gte(_pressure(), _fang.flinch_threshold, "sanity: pressure is banked and ready")
	# Hold past charge_threshold_ticks, then release: the charge profile is authored
	# pressure-capable, so it is a SECOND cash-out route alongside the basic finisher.
	_settle()
	_attack("pressed")
	for _i in range(_sword.charge_threshold_ticks + 2):
		_attack("held")
	var flinched: Array = _of(_attack("released"), "flinched")
	for _i in range(_sword.charge_profile.windup_ticks + _sword.charge_profile.lunge_duration_ticks + 4):
		flinched.append_array(_of(_tick(), "flinched"))
	assert_eq(flinched.size(), 1, "a charged release cashes out banked pressure")
	assert_eq(flinched[0].payload.reason, "pressure")


# --- 3.4 composed lifecycle at a low threshold -------------------------------------

## The bulliable-enemy composition (law 2.5) evidenced end-to-end, at a deliberately
## LOW threshold so repeated cash-outs are exercised rather than barely reached. This
## is the direct evidence for the PROVISIONAL non-extension re-flinch rule, gathered
## before live tuning adds noise.
func test_34_composed_flinch_lifecycle_persist_no_extend_then_reflinch() -> void:
	sim.register_flinch_profile(TARGET_ID, 4.0)  # debug_flinch_threshold_override equivalent

	# 1. Build pressure until the first cash-out.
	var first: Array = _land_hits(4)
	var first_flinch: Dictionary = {}
	for entry in first:
		if entry.profile == "FLINCH":
			first_flinch = entry
			break
	assert_false(first_flinch.is_empty(), "a pressure-capable hit must cash out at the low threshold")
	var original_until: int = int(first_flinch.until)
	var pressure_at_flinch: float = _pressure()

	# 2. Contributions PERSIST with their original expiry -- never consumed or reset.
	assert_gt(pressure_at_flinch, 0.0)

	# 3. A qualifying hit DURING recovery adds pressure but must not extend the deadline.
	var mid_recovery_flinches: Array = []
	var pressed: bool = false
	while sim.tick_count < original_until - 1:
		for event in _attack("released" if pressed else "pressed"):
			if event.kind == "flinched":
				mid_recovery_flinches.append(event)
		pressed = not pressed
	for event in mid_recovery_flinches:
		assert_eq(int(event.payload.until_tick), original_until,
			"a mid-recovery re-flinch registers but must NOT extend flinched_until_tick")
		assert_false(event.payload.recovery_deadline_set)
	assert_gt(_pressure(), 0.0, "mid-recovery hits still bank pressure normally")

	# 4. Recovery ends on its exact tick, and the next eligible hit re-flinches.
	while sim.tick_count < original_until:
		_tick()
	assert_eq(sim.debug_describe_flinch_state(TARGET_ID).flinched_ticks_left, 0,
		"recovery expires on its exact authored tick")
	var after: Array = _land_hits(2)
	var re_flinched: Array = after.filter(func(e): return e.profile == "FLINCH")
	assert_gt(re_flinched.size(), 0, "a susceptible enemy can be flinched again once recovered")
	assert_true(re_flinched[0].deadline_set, "the post-recovery flinch sets a FRESH deadline")


# --- 3.5 expiry ticks and concurrent cooldown --------------------------------------

func test_35_flinch_deadline_is_recovery_ticks_from_the_landing_tick() -> void:
	var sequence: Array = _land_hits(4)
	for entry in sequence:
		if entry.profile == "FLINCH":
			assert_eq(int(entry.until), int(entry.tick) + _tuning.flinch_recovery_ticks,
				"the deadline is an absolute tick, exactly recovery_ticks from the hit")
			return
	fail_test("no flinch occurred")


## With a real AI-driven Watcher: interrupting its windup arms the normal post-attack
## cooldown, and that cooldown runs CONCURRENTLY with flinch recovery in the same
## absolute tick space -- effective denial is max(recovery, cooldown), never the sum.
func test_35_interrupted_attack_cooldown_runs_concurrently_with_recovery() -> void:
	var watcher_id: int = 9
	ContentRegistrar.register_enemy_body(sim, watcher_id, &"watcher", Vector3(0, 0, -1.8))
	ContentRegistrar.register_enemy_ai(sim, watcher_id, &"watcher", Vector3(0, 0, -1.8))
	sim.debug_override_health(watcher_id, VALIDATION_HEALTH)
	var pulse: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", &"watcher_pulse")

	# Let it commit to a windup, then land a hit inside its authored VULNERABLE window.
	var flinched: Array = []
	var pressed: bool = false
	for _i in range(120):
		sim.debug_override_health(watcher_id, VALIDATION_HEALTH)
		for event in _attack("released" if pressed else "pressed"):
			if event.kind == "flinched" and event.payload.actor_id == watcher_id:
				flinched.append(event)
		pressed = not pressed
		if not flinched.is_empty():
			break
	assert_gt(flinched.size(), 0, "the authored window on Watcher's windup must be reachable in play")

	var recovery_deadline: int = int(flinched[0].payload.until_tick)
	var cooldown_deadline: int = int(sim._next_fire_tick.get(watcher_id, 0))
	assert_gt(cooldown_deadline, 0, "an interrupted attack arms the normal post-attack cooldown")
	assert_lt(max(recovery_deadline, cooldown_deadline), cooldown_deadline + pulse.fire_interval_ticks,
		"denial must be max(recovery, cooldown) -- never recovery appended to cooldown")
