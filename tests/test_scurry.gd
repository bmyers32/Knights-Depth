extends GutTest
## P17 SCURRY — Fang's situational mobility commitment. Spec: ROADMAP P17 (committed 8dd504e
## BEFORE any code existed, so this suite measures the implementation against a fixed design
## rather than against itself).
##
## The two load-bearing tests are the SIGNAL pair, because the retreat signal is the part that
## can be subtly wrong while looking right:
##   * positive — a player retreating faster than the Fang eventually triggers a commitment;
##   * negative — a stationary target at range can NEVER trigger one through elapsed time
##     alone. That is failed-closure (P29's fact about the world), not retreat, and conflating
##     them would turn this into a turret that charges anyone who stands still.
##
## Everything else pins a ruled semantic: the seven-boundary lifetime of the closest-approach
## fact, fixed direction at commit, mobility-only, the two flinch regimes, settle, and
## cooldown-at-displacement-end.
##
## SYNTHETIC FIXTURE VALUES, deliberately NOT tracking shipped content (same discipline as
## test_shield_bump_parry.gd): this file protects the MECHANICAL laws. Fang's authored
## 2.5/45/0.30/15/18/90 are provisional and are validated by playtest, never pinned here.

const PLAYER_ID := 0
const ENEMY_ID := 1
const WEAPON_ID := &"test_bite"
const DT := 1.0 / 30.0

const TRIGGER_SEPARATION := 1.0
const TRIGGER_TICKS := 10
const STEP_DISTANCE := 0.3
const STEPS := 5
const SETTLE_TICKS := 8
const COOLDOWN_TICKS := 40

const PLAYER_SPEED := 4.0
const ENEMY_SPEED := 3.0
const PREFERRED := 1.5

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()


func _register_player(position: Vector3 = Vector3.ZERO) -> void:
	sim.add_entity(PLAYER_ID, position, PLAYER_SPEED)
	sim.register_combatant(PLAYER_ID, 500.0, &"envoy", 0, 0.4, &"player")


func _register_enemy(position: Vector3, scurry: bool = true, speed: float = ENEMY_SPEED) -> void:
	sim.add_entity(ENEMY_ID, position, speed)
	sim.register_combatant(ENEMY_ID, 500.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(WEAPON_ID, 5.0, &"force", PREFERRED, 90.0, 0.0, 9999)
	sim.register_ai(
		ENEMY_ID, CombatTestHelpers.single_action_repertoire(WEAPON_ID, PREFERRED, 10000),
		position, PREFERRED, 0.0, 40.0, 80.0, 0, 0,
		TRIGGER_SEPARATION if scurry else 0.0, TRIGGER_TICKS if scurry else 0,
		STEP_DISTANCE if scurry else 0.0, STEPS if scurry else 0,
		SETTLE_TICKS if scurry else 0, COOLDOWN_TICKS if scurry else 0)


## Suppresses the bite entirely, so pursuit/mobility is observed without an attack commitment
## clearing the closest-approach fact underneath the test (the house idiom from test_enemy_ai).
func _never_attack() -> void:
	sim._next_fire_tick[ENEMY_ID] = 1_000_000


func _retreat() -> Command:
	return Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3(0, 0, 1)})


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


## Runs until the first commitment or the tick budget runs out; returns the tick it committed
## on, or -1. Player retreats every tick.
func _run_retreating(max_ticks: int) -> int:
	for i in max_ticks:
		var events: Array[Event] = sim.tick([_retreat()], DT)
		if _of(events, "scurry_committed").size() > 0:
			return sim.tick_count
	return -1


# ===================================================================================
# THE SIGNAL PAIR
# ===================================================================================

func test_POSITIVE_a_player_retreating_faster_than_the_fang_eventually_triggers() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	var committed_tick: int = _run_retreating(400)
	assert_ne(committed_tick, -1, "sustained retreat MUST eventually provoke a commitment -- this is the entire mechanic")

	# It committed on the terms content authored, not merely at some point.
	var separation_at_commit: float = TRIGGER_SEPARATION
	assert_true(committed_tick >= TRIGGER_TICKS,
		"it cannot commit before the authored elapsed floor has passed")
	assert_gt(separation_at_commit, 0.0, "sanity: the fixture authors a real separation requirement")


func test_NEGATIVE_a_stationary_target_at_range_never_triggers_from_elapsed_time_alone() -> void:
	# Enemy speed 0: the gap is CONSTANT, so `elapsed` grows without bound while `separation`
	# stays exactly 0. The harshest possible form of the question.
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0), true, 0.0)
	_never_attack()
	for i in 600:
		var events: Array[Event] = sim.tick([], DT)
		assert_eq(_of(events, "scurry_committed").size(), 0,
			"tick %d: elapsed time alone must NEVER read as retreat -- that is failed-closure, a different fact" % i)
	var described: Dictionary = sim.debug_describe_scurry(ENEMY_ID, PLAYER_ID)
	assert_gt(int(described.elapsed), TRIGGER_TICKS, "sanity: the elapsed term really did run far past its threshold")
	assert_almost_eq(float(described.separation), 0.0, 0.0001, "and the separation term stayed at zero throughout")


func test_NEGATIVE_approaching_a_stationary_target_never_triggers() -> void:
	# The realistic form: while closing on a stationary player the minimum refreshes every
	# tick, so BOTH terms stay pinned at zero by construction rather than by tuning.
	_register_player()
	_register_enemy(Vector3(0, 0, -20.0))
	_never_attack()
	for i in 200:
		assert_eq(_of(sim.tick([], DT), "scurry_committed").size(), 0, "tick %d: closing is not retreating" % i)


# ===================================================================================
# DEFAULT-OFF
# ===================================================================================

func test_a_family_authoring_no_scurry_is_completely_unaffected() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0), false)
	_never_attack()
	assert_eq(_run_retreating(400), -1, "an unauthored scurry must never commit")
	assert_false(bool(sim.debug_describe_scurry(ENEMY_ID, PLAYER_ID).authored), "and no record should exist at all")


# ===================================================================================
# COMMITMENT + DISPLACEMENT
# ===================================================================================

func test_direction_is_fixed_at_commit_and_never_re_evaluated() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")

	# Teleport the player far to the side. A homing scurry would curve; a COMMITMENT does not.
	sim.entities[PLAYER_ID] = Vector3(50.0, 0.0, 0.0)
	var before: Vector3 = sim.entities[ENEMY_ID]
	sim.tick([], DT)
	var step: Vector3 = sim.entities[ENEMY_ID] - before
	assert_almost_eq(step.x, 0.0, 0.0001,
		"the committed line must not bend toward the player -- re-aiming would delete the counterplay this mechanic exists to create")
	assert_gt(step.z, 0.0, "and it keeps travelling along the direction captured at commit")


func test_displacement_delivers_its_authored_distance_then_settles() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")
	var start: Vector3 = sim.entities[ENEMY_ID]

	var ended: Array = []
	for i in STEPS:
		ended.append_array(_of(sim.tick([], DT), "scurry_ended"))
	assert_eq(ended.size(), 1, "displacement ends exactly once")
	assert_eq(String(ended[0].payload.reason), "completed")
	assert_almost_eq(sim.entities[ENEMY_ID].distance_to(start), STEP_DISTANCE * STEPS, 0.0001,
		"the full authored displacement is delivered")
	# Anchored on the Event's OWN tick, not on tick_count after the fact: tick_count advances
	# last inside tick(), so a post-tick read is one ahead of the tick that stamped the
	# deadline (BRAIN: events carry the authoritative timestamp).
	assert_eq(int(sim._scurry_settle_until_tick[ENEMY_ID]), int(ended[0].tick) + SETTLE_TICKS,
		"and the mandatory settle beat is armed")


func test_the_actor_does_not_steer_while_displacing() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")
	for i in STEPS:
		var before: Vector3 = sim.entities[ENEMY_ID]
		sim.tick([], DT)
		var step: float = sim.entities[ENEMY_ID].distance_to(before)
		if sim._scurry_active.has(ENEMY_ID) or step > 0.0:
			assert_almost_eq(step, STEP_DISTANCE, 0.0001,
				"tick %d: authored displacement REPLACES locomotion -- never displacement plus a move Command" % i)


func test_blocked_displacement_ends_early_but_still_owes_its_settle() -> void:
	# Player parked close ahead: the sweep clamps on contact partway through.
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")
	sim.entities[PLAYER_ID] = sim.entities[ENEMY_ID] + Vector3(0, 0, 0.5)

	var ended: Array = []
	for i in STEPS:
		ended.append_array(_of(sim.tick([], DT), "scurry_ended"))
	assert_eq(ended.size(), 1, "it ends once")
	assert_eq(String(ended[0].payload.reason), "blocked", "and reports that it was blocked")
	assert_true(sim._scurry_settle_until_tick.has(ENEMY_ID),
		"settle is the commitment's PRICE, not a reward for arriving -- a blocked scurry still owes it")


# ===================================================================================
# SETTLE
# ===================================================================================

func test_settle_is_stationary_and_cannot_start_an_attack() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")
	for i in STEPS:
		sim.tick([], DT)
	assert_true(sim._scurry_settle_until_tick.has(ENEMY_ID), "sanity: settling")

	sim._next_fire_tick[ENEMY_ID] = 0  # cooldown fully ready: only settle can hold it back
	sim.entities[PLAYER_ID] = sim.entities[ENEMY_ID] + Vector3(0, 0, 0.8)  # well inside reach
	var frozen: Vector3 = sim.entities[ENEMY_ID]
	var events: Array[Event] = []
	for i in SETTLE_TICKS - 1:
		events.append_array(sim.tick([], DT))
	assert_eq(sim.entities[ENEMY_ID], frozen, "the actor is stationary throughout settle")
	assert_eq(_of(events, "attack_telegraph").size(), 0, "and cannot start an attack during it")


func test_the_actor_acts_again_after_settle_expires() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")
	for i in STEPS + SETTLE_TICKS + 1:
		sim.tick([], DT)
	assert_false(sim._scurry_settle_until_tick.has(ENEMY_ID) and sim.tick_count < int(sim._scurry_settle_until_tick[ENEMY_ID]),
		"settle has expired")
	var before: Vector3 = sim.entities[ENEMY_ID]
	sim.tick([], DT)
	assert_ne(sim.entities[ENEMY_ID], before, "ordinary pursuit resumes")


# ===================================================================================
# THE TWO FLINCH REGIMES — the ruled asymmetry, tested as two distinct regimes
# ===================================================================================

func _arm_flinch() -> void:
	sim.set_flinch_tuning(90, 20)
	sim.register_flinch_profile(ENEMY_ID, 1.0)
	sim.register_weapon(&"poke", 10.0, &"force", 100.0, 180.0, 0.0, 0)
	sim._weapons["poke"].flinch_capability = "pressure"
	sim.set_equipped_weapon(PLAYER_ID, &"poke")


func _player_flinches_enemy() -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)


func test_REGIME_ONE_flinch_during_displacement_aborts_and_forfeits_the_remainder() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	_arm_flinch()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")
	sim.tick([], DT)  # one step travelled
	assert_true(sim._scurry_active.has(ENEMY_ID), "sanity: still displacing")
	var at_flinch: Vector3 = sim.entities[ENEMY_ID]

	var events: Array[Event] = _player_flinches_enemy()
	assert_eq(_of(events, "flinched").size(), 1, "sanity: the mechanism fired")
	var ended: Array = _of(events, "scurry_ended")
	assert_eq(ended.size(), 1, "the scurry ends on the flinch")
	assert_eq(String(ended[0].payload.reason), "aborted", "and reports an ABORT -- vocabulary reserved for this regime")
	assert_false(sim._scurry_active.has(ENEMY_ID), "displacement is over")
	assert_false(sim._scurry_settle_until_tick.has(ENEMY_ID),
		"settle is SKIPPED -- flinch recovery replaces it, never two stacked punish windows")
	assert_eq(int(sim._next_scurry_tick[ENEMY_ID]), int(ended[0].tick) + COOLDOWN_TICKS,
		"cooldown arms at end of displacement in every path, so an abort cannot be farmed into a retry")

	# Displacement is a tick PHASE that runs before Commands dispatch, so this tick's step had
	# already been taken when the flinch resolved. Forfeiture is about every step AFTER the
	# abort, which is what this measures.
	var aborted_at: Vector3 = sim.entities[ENEMY_ID]
	assert_almost_eq(aborted_at.distance_to(at_flinch), STEP_DISTANCE, 0.0001,
		"sanity: the in-flight step for the aborting tick still landed")
	for i in 10:
		sim.tick([], DT)
	assert_eq(sim.entities[ENEMY_ID], aborted_at,
		"the remaining authored movement is FORFEITED, never frozen and resumed")


func test_REGIME_TWO_flinch_during_settle_is_not_an_abort() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	_arm_flinch()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")
	for i in STEPS:
		sim.tick([], DT)
	assert_true(sim._scurry_settle_until_tick.has(ENEMY_ID), "sanity: settling")
	var settle_deadline: int = int(sim._scurry_settle_until_tick[ENEMY_ID])
	var cooldown_before: int = int(sim._next_scurry_tick[ENEMY_ID])

	var events: Array[Event] = _player_flinches_enemy()
	assert_eq(_of(events, "flinched").size(), 1, "sanity: the mechanism fired")
	assert_eq(_of(events, "scurry_ended").size(), 0,
		"a flinch during SETTLE is not a scurry event at all -- the movement was already complete")
	assert_eq(int(sim._scurry_settle_until_tick[ENEMY_ID]), settle_deadline,
		"the settle deadline is untouched: it lives in absolute tick space, so recovery and settle run alongside each other (max, never sum)")
	assert_eq(int(sim._next_scurry_tick[ENEMY_ID]), cooldown_before,
		"and the cooldown, already armed at end of displacement, does not re-arm")


# ===================================================================================
# CLOSEST-APPROACH LIFETIME — the seven ruled boundaries
# ===================================================================================

func _record() -> Dictionary:
	return sim._ai_closest_approach.get(ENEMY_ID, {})


func test_BOUNDARY_1_and_7_reaching_and_holding_close_range_keeps_refreshing_the_fact() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()  # arrives and HOLDS instead of committing a bite
	for i in 200:
		sim.tick([], DT)
	assert_false(_record().is_empty(), "arriving is pursuit SUCCEEDING, not ending -- the fact persists")
	assert_lt(float(_record().distance), 2.0, "and it refreshed all the way down to the engagement band")

	# ...which is exactly what lets a retreat from close range register as separation.
	assert_ne(_run_retreating(400), -1, "a player who runs after being caught must still provoke a commitment")


func test_BOUNDARY_2_committing_bite_clears_the_fact() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -2.0))
	for i in 200:
		sim.tick([], DT)
		if sim._ai_attack_fire_tick.has(ENEMY_ID):
			break
	assert_true(sim._ai_attack_fire_tick.has(ENEMY_ID), "sanity: a bite is committed")
	assert_true(_record().is_empty(), "a committed attack ends the pursuit attempt, so its fact is cleared")


func test_BOUNDARY_3_finishing_bite_reinitializes_rather_than_hair_triggering() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -2.0))
	# Long enough windup that the player can open real distance while the Fang is committed --
	# which is precisely the situation the rule exists for.
	sim.register_ai(ENEMY_ID, CombatTestHelpers.single_action_repertoire(WEAPON_ID, PREFERRED, 40),
		Vector3(0, 0, -2.0), PREFERRED, 0.0, 40.0, 80.0, 0, 0,
		TRIGGER_SEPARATION, TRIGGER_TICKS, STEP_DISTANCE, STEPS, SETTLE_TICKS, COOLDOWN_TICKS)
	for i in 60:
		sim.tick([], DT)
		if sim._ai_attack_fire_tick.has(ENEMY_ID):
			break
	assert_true(sim._ai_attack_fire_tick.has(ENEMY_ID), "sanity: a bite is committed")
	assert_true(_record().is_empty(), "sanity: committing cleared the fact (boundary 2)")

	# The player leaves WHILE the Fang is locked in its windup.
	sim.entities[PLAYER_ID] = Vector3(0, 0, 12.0)
	var events: Array[Event] = []
	for i in 60:
		events.append_array(sim.tick([], DT))
		if not _record().is_empty():
			break

	assert_eq(_of(events, "scurry_committed").size(), 0,
		"THE ANTI-HAIR-TRIGGER RULE: distance opened while the Fang was busy biting must never fire a scurry the instant it recovers")
	assert_false(_record().is_empty(), "the fact reinitialized once pursuit resumed")
	assert_gt(float(_record().distance), 5.0,
		"to the CURRENT gap, so separation is measured from here -- not from the stale close-range minimum")
	assert_eq(int(_record().tick), sim.tick_count - 1,
		"and its timestamp restarts too, so the bite's own duration cannot pre-satisfy the elapsed term")


func test_BOUNDARY_4_being_flinched_clears_the_fact() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	_arm_flinch()
	for i in 40:
		sim.tick([], DT)
	assert_false(_record().is_empty(), "sanity: a fact exists before the flinch")
	_player_flinches_enemy()
	assert_true(_record().is_empty(),
		"distance gained while this actor had no agency is not separation its pursuit lost")


func test_BOUNDARY_5_completing_a_scurry_reinitializes_and_prevents_chaining() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_retreating(400), -1, "sanity: it committed")
	assert_true(_record().is_empty(), "the fact clears at commit")
	for i in STEPS + SETTLE_TICKS + 2:
		sim.tick([_retreat()], DT)
	assert_false(_record().is_empty(), "it reinitializes once ordinary pursuit resumes")
	# The new minimum zeroes the separation term outright -- chaining is structurally
	# impossible, not merely rate-limited.
	assert_almost_eq(float(sim.debug_describe_scurry(ENEMY_ID, PLAYER_ID).separation), 0.0, 0.5,
		"separation restarts from the post-scurry gap")


func test_BOUNDARY_6_disengaging_clears_the_fact_and_reacquisition_starts_fresh() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	for i in 40:
		sim.tick([], DT)
	assert_false(_record().is_empty(), "sanity: pursuing with a fact")

	sim.entities[PLAYER_ID] = Vector3(0, 0, 500.0)  # far past leash
	sim.tick([], DT)
	assert_eq(String(sim._ai_state[ENEMY_ID]), "idle", "sanity: disengaged")
	assert_true(_record().is_empty(), "a leash definitively ends the pursuit attempt")

	sim.entities[PLAYER_ID] = sim.entities[ENEMY_ID] + Vector3(0, 0, 6.0)  # walk back into detection
	sim.tick([], DT)
	sim.tick([], DT)
	assert_false(_record().is_empty(), "reacquisition starts a fresh fact")
	assert_gt(float(_record().distance), 4.0, "initialized to the CURRENT gap, never the stale one")


# ===================================================================================
# DETERMINISM
# ===================================================================================

func test_identical_setups_produce_identical_scurries() -> void:
	var runs: Array = []
	for run in 2:
		sim = SimWorld.new()
		_register_player()
		_register_enemy(Vector3(0, 0, -6.0))
		_never_attack()
		var recorded: Array[String] = []
		for i in 300:
			for event in sim.tick([_retreat()], DT):
				if String(event.kind).begins_with("scurry"):
					recorded.append("%d|%s" % [event.tick, event.kind])
			recorded.append("%.6f" % sim.entities[ENEMY_ID].z)
		runs.append(recorded)
	assert_eq(runs[0], runs[1], "the scurry must be a pure function of world state -- no RNG, no hidden ordering")
