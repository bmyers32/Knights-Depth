extends GutTest
## P17 CUTOFF — Fang's route-contesting mobility, implemented against frozen spec `d070b63`.
##
## THE LOAD-BEARING TESTS ARE THE DISCRIMINATION SET on the two-bucket recent-locomotion fact.
## Scurry v1 died because its detector measured RADIAL separation and never armed under
## diagonal or circling kites — a failure no test caught because none of them drove a
## realistic kite. So this file drives the movement shapes players actually use, and the
## circling test in particular is the one that would have caught both the v1 detector AND the
## unbounded-accumulator design that briefly replaced it.
##
## SYNTHETIC FIXTURE VALUES where the mechanical law is under test; the shipped
## 1.2/2.5/2.0/0.30/30/12/120 are provisional and validated by playtest, never pinned here.

const PLAYER_ID := 0
const ENEMY_ID := 1
const WEAPON_ID := &"test_bite"
const DT := 1.0 / 30.0

const N := 15                      # route_window_ticks
const MIN_ROUTE := 1.2
const LEAD := 2.5
const LATERAL := 2.0
const STEP := 0.30
const MAX_STEPS := 30
const PLANT := 12
const COOLDOWN := 120

const PLAYER_SPEED := 4.0
const ENEMY_SPEED := 3.0
const PREFERRED := 1.5

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_route_window(N)


func _register_player(position: Vector3 = Vector3.ZERO) -> void:
	sim.add_entity(PLAYER_ID, position, PLAYER_SPEED)
	sim.register_combatant(PLAYER_ID, 5000.0, &"envoy", 0, 0.4, &"player")


func _register_enemy(position: Vector3, cutoff: bool = true) -> void:
	sim.add_entity(ENEMY_ID, position, ENEMY_SPEED)
	sim.register_combatant(ENEMY_ID, 5000.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(WEAPON_ID, 5.0, &"force", PREFERRED, 90.0, 0.0, 9999)
	sim.register_ai(
		ENEMY_ID, CombatTestHelpers.single_action_repertoire(WEAPON_ID, PREFERRED, 10000),
		position, PREFERRED, 0.0, 60.0, 120.0, 0, 0,
		MIN_ROUTE if cutoff else 0.0, LEAD, LATERAL,
		STEP if cutoff else 0.0, MAX_STEPS if cutoff else 0, PLANT, COOLDOWN)


func _never_attack() -> void:
	sim._next_fire_tick[ENEMY_ID] = 1_000_000


func _move(direction: Vector3) -> Command:
	return Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": direction})


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


func _route_length() -> float:
	return sim.recent_route(PLAYER_ID).length()


## Drives the player straight and returns the tick a cutoff committed, or -1.
func _run_straight(ticks: int, direction: Vector3 = Vector3(0, 0, 1)) -> int:
	for i in ticks:
		if _of(sim.tick([_move(direction)], DT), "cutoff_committed").size() > 0:
			return sim.tick_count
	return -1


# ===================================================================================
# A. RECENT-ROUTE DISCRIMINATION — the set that would have caught v1
# ===================================================================================

func test_long_straight_travel_stays_valid() -> void:
	_register_player()
	for i in 300:
		sim.tick([_move(Vector3(0, 0, 1))], DT)
		if i > N:
			assert_gte(_route_length(), MIN_ROUTE, "tick %d: sustained straight travel must stay valid" % i)


func test_diagonal_travel_stays_valid() -> void:
	_register_player()
	var diagonal: Vector3 = Vector3(1, 0, 1).normalized()
	for i in 300:
		sim.tick([_move(diagonal)], DT)
		if i > N:
			assert_gte(_route_length(), MIN_ROUTE, "tick %d: diagonal travel is a route (v1 was blind to it)" % i)


## THE TEST THAT KILLS BOTH FAILED DESIGNS. v1's radial detector never armed while circling
## (radial speed 0.00). The unbounded accumulator that briefly replaced it would collapse
## toward zero after a full loop, because its vector was the historical chord. A bounded
## horizon must instead track RECENT tangential travel, indefinitely.
func test_sustained_circling_stays_valid_and_tracks_the_recent_tangent() -> void:
	_register_player(Vector3(4, 0, 0))
	var worst_angle: float = 0.0
	for i in 900:  # ~3 loops at radius 4
		var radial: Vector3 = sim.entities[PLAYER_ID]
		radial.y = 0.0
		var tangent: Vector3 = radial.normalized().rotated(Vector3.UP, PI * 0.5)
		sim.tick([_move(tangent)], DT)
		if i <= N * 2:
			continue
		assert_gte(_route_length(), MIN_ROUTE, "tick %d: circling is sustained travel and must stay valid" % i)
		var route_direction: Vector3 = sim.recent_route(PLAYER_ID).normalized()
		worst_angle = maxf(worst_angle, rad_to_deg(absf(route_direction.signed_angle_to(tangent, Vector3.UP))))
	assert_lt(worst_angle, 45.0, "the route must track the RECENT tangent, not a historical chord (worst %.1f deg)" % worst_angle)


func test_a_gradual_turn_ages_into_the_new_route() -> void:
	_register_player()
	for i in 60:
		sim.tick([_move(Vector3(0, 0, 1))], DT)
	# Turn by 3 degrees per tick -- no single tick is a "sharp" turn, which is exactly the case
	# an explicit turn threshold would have missed and a bounded horizon absorbs.
	var direction: Vector3 = Vector3(0, 0, 1)
	for i in 60:
		direction = direction.rotated(Vector3.UP, deg_to_rad(3.0))
		sim.tick([_move(direction)], DT)
	var route_direction: Vector3 = sim.recent_route(PLAYER_ID).normalized()
	var drift: float = rad_to_deg(absf(route_direction.signed_angle_to(direction, Vector3.UP)))
	assert_lt(drift, 45.0, "after a gradual 180-degree turn the route must describe where the player is going NOW (drift %.1f deg)" % drift)


func test_jitter_never_establishes_a_route() -> void:
	_register_player()
	for i in 300:
		var direction: Vector3 = Vector3(0, 0, 1) if i % 2 == 0 else Vector3(0, 0, -1)
		sim.tick([_move(direction)], DT)
		assert_lt(_route_length(), MIN_ROUTE, "tick %d: alternating input is not a committed route" % i)


# ===================================================================================
# B. THE FACT'S BOUNDARIES — exclusion, ageing, rollover
# ===================================================================================

func test_knockback_never_enters_the_route_fact() -> void:
	_register_player()
	# NO AI here on purpose: an AI actor re-equips its own authored action when it commits a
	# windup, which runs before Command dispatch and would silently replace the test weapon.
	sim.add_entity(ENEMY_ID, Vector3(0, 0, -1.0), 0.0)
	sim.register_combatant(ENEMY_ID, 500.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"shove", 5.0, &"force", 3.0, 90.0, 4.0)  # big knockback
	sim.set_equipped_weapon(ENEMY_ID, &"shove")
	var before: Vector3 = sim.entities[PLAYER_ID]
	sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3(0, 0, 1)})], DT)
	assert_ne(sim.entities[PLAYER_ID], before, "sanity: the player really was displaced")
	assert_almost_eq(_route_length(), 0.0, 0.0001, "forced displacement is not locomotion intent")


func test_bump_displacement_never_enters_the_route_fact() -> void:
	_register_player()
	sim.add_entity(ENEMY_ID, Vector3(0, 0, -1.0), 0.0)
	sim.register_combatant(ENEMY_ID, 500.0, &"fang", 0, 0.6, &"enemy")
	sim.register_shield(PLAYER_ID, 100.0, 0.0, 30, 1.5, 0.35, 2.0, 7, 45, 0, 0, 1.0)
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "block", {"held": true})], DT)
	var before: Vector3 = sim.entities[ENEMY_ID]
	for i in 8:
		sim.tick([], DT)
	assert_ne(sim.entities[ENEMY_ID], before, "sanity: the bump really slid the enemy")
	assert_almost_eq(sim.recent_route(ENEMY_ID).length(), 0.0, 0.0001, "an imposed slide is not the actor's route")


func test_melee_lunge_never_enters_the_route_fact() -> void:
	_register_player()
	var profile: Dictionary = {
		"damage": 5.0, "damage_type": &"force", "reach": 2.0, "cone_half_angle_degrees": 90.0,
		"knockback_distance": 0.0, "fire_interval_ticks": 0, "status_id": &"", "status_proc_chance": 0.0,
		"lunge_distance": 3.0, "lunge_duration_ticks": 6, "hit_active_ticks": 3, "windup_ticks": 2,
	}
	var combo: Array[Dictionary] = [profile]
	sim.register_melee_profiles(&"lunger", combo, profile, 60, 30, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"lunger")
	var before: Vector3 = sim.entities[PLAYER_ID]
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, 1), "phase": "pressed"})], DT)
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, 1), "phase": "released"})], DT)
	for i in 10:
		sim.tick([], DT)
	assert_ne(sim.entities[PLAYER_ID], before, "sanity: the lunge really moved the player")
	assert_almost_eq(_route_length(), 0.0, 0.0001, "attack-authored movement is not locomotion intent")


func test_validity_does_not_flicker_at_bucket_rollover() -> void:
	_register_player()
	for i in 200:
		sim.tick([_move(Vector3(0, 0, 1))], DT)
		if i > N:
			assert_gte(_route_length(), MIN_ROUTE, "tick %d (bucket %d): full-speed travel must not flicker across a rollover" % [i, sim.tick_count / N])


## THE CORRECTED LIFECYCLE. An earlier draft rolled buckets only on WRITE, so a stopped actor's
## route survived forever. Ageing must be a function of authoritative time, provable by a READ
## alone with no intervening writes.
func test_a_route_ages_out_after_2N_ticks_without_locomotion() -> void:
	_register_player()
	for i in 60:
		sim.tick([_move(Vector3(0, 0, 1))], DT)
	assert_gte(_route_length(), MIN_ROUTE, "sanity: a route was established")
	for i in N * 2 + 2:
		sim.tick([], DT)  # NO move Commands at all
	assert_almost_eq(_route_length(), 0.0, 0.0001, "a stop must age the route out by TIME, not by write activity")


func test_resuming_after_a_long_stop_shows_no_stale_direction() -> void:
	_register_player()
	for i in 60:
		sim.tick([_move(Vector3(0, 0, 1))], DT)
	for i in N * 2 + 2:
		sim.tick([], DT)
	for i in 30:
		sim.tick([_move(Vector3(1, 0, 0))], DT)
	var route_direction: Vector3 = sim.recent_route(PLAYER_ID).normalized()
	assert_almost_eq(route_direction.x, 1.0, 0.001, "the resumed route must be the NEW direction")
	assert_almost_eq(route_direction.z, 0.0, 0.001, "with no contamination from the abandoned one")


func test_route_fact_is_deterministic_across_identical_runs() -> void:
	var runs: Array = []
	for run in 2:
		sim = SimWorld.new()
		sim.set_route_window(N)
		_register_player()
		var recorded: Array[String] = []
		for i in 120:
			sim.tick([_move(Vector3(1, 0, 1).normalized())], DT)
			var route: Vector3 = sim.recent_route(PLAYER_ID)
			recorded.append("%.6f,%.6f" % [route.x, route.z])
		runs.append(recorded)
	assert_eq(runs[0], runs[1], "the route fact must be a pure function of accepted locomotion and tick")


# ===================================================================================
# C. CUTOFF LIFECYCLE
# ===================================================================================

func test_a_family_authoring_no_cutoff_never_commits() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0), false)
	_never_attack()
	assert_eq(_run_straight(400), -1, "an unauthored cutoff must never commit")
	assert_false(bool(sim.debug_describe_cutoff(ENEMY_ID, PLAYER_ID).authored))


func test_a_committed_route_provokes_a_cutoff() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_straight(400), -1, "sustained travel must provoke a cutoff -- this is the mechanic")


func test_side_and_lead_point_commit_once_and_never_re_evaluate() -> void:
	_register_player()
	_register_enemy(Vector3(3.0, 0, -6.0))
	_never_attack()
	assert_ne(_run_straight(400), -1, "sanity: committed")
	var first: Vector3 = sim.entities[ENEMY_ID]
	sim.tick([], DT)
	var step_one: Vector3 = sim.entities[ENEMY_ID] - first
	sim.entities[PLAYER_ID] = Vector3(-80.0, 0.0, 80.0)  # teleport: a homing cutoff would bend
	var before: Vector3 = sim.entities[ENEMY_ID]
	sim.tick([], DT)
	var step_two: Vector3 = sim.entities[ENEMY_ID] - before
	assert_almost_eq(step_one.normalized().dot(step_two.normalized()), 1.0, 0.0001,
		"the committed line must not bend toward the player")


func test_the_tie_resolves_to_the_canonical_side_not_float_noise() -> void:
	# Fang exactly behind the player ON its travel line: the signed lateral offset is 0, so
	# geometry cannot prefer a side and the canonical constant must decide.
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	var committed: Array = []
	for i in 400:
		committed = _of(sim.tick([_move(Vector3(0, 0, 1))], DT), "cutoff_committed")
		if committed.size() > 0:
			break
	assert_eq(committed.size(), 1, "sanity: it committed")
	assert_almost_eq(sim.entities[ENEMY_ID].x, 0.0, 0.0001, "sanity: the tie geometry really held")
	assert_eq(int(committed[0].payload.side), SimWorld.CUTOFF_CANONICAL_SIDE,
		"a true geometric tie resolves to the canonical side, never to float noise")


func test_identical_sims_choose_the_same_side() -> void:
	var sides: Array = []
	for run in 2:
		sim = SimWorld.new()
		sim.set_route_window(N)
		_register_player()
		_register_enemy(Vector3(0, 0, -6.0))
		_never_attack()
		for i in 400:
			var events: Array[Event] = sim.tick([_move(Vector3(0, 0, 1))], DT)
			var committed: Array = _of(events, "cutoff_committed")
			if committed.size() > 0:
				sides.append(int(committed[0].payload.side))
				break
		assert_eq(sides.size(), run + 1, "sanity: run %d committed" % run)
	assert_eq(sides[0], sides[1], "two identical sims must choose the same side by construction")


func test_facing_follows_cutoff_motion() -> void:
	_register_player()
	_register_enemy(Vector3(3.0, 0, -6.0))
	_never_attack()
	assert_ne(_run_straight(400), -1, "sanity: committed")
	var before: Vector3 = sim.entities[ENEMY_ID]
	sim.tick([], DT)
	var motion: Vector3 = (sim.entities[ENEMY_ID] - before).normalized()
	assert_almost_eq(sim._facings[ENEMY_ID].dot(motion), 1.0, 0.001,
		"option B: cutoff displacement writes facing along its own motion, and nothing else writes it")


func test_the_plant_is_stationary_and_cannot_attack() -> void:
	_register_player()
	_register_enemy(Vector3(3.0, 0, -6.0))
	_never_attack()
	assert_ne(_run_straight(400), -1, "sanity: committed")
	var events: Array[Event] = []
	for i in MAX_STEPS + 2:
		events.append_array(sim.tick([_move(Vector3(0, 0, 1))], DT))
		if _of(events, "cutoff_ended").size() > 0:
			break
	assert_eq(_of(events, "cutoff_ended").size(), 1, "displacement ends exactly once")
	assert_true(sim._cutoff_plant_until_tick.has(ENEMY_ID), "a completed cutoff owes its plant")

	sim._next_fire_tick[ENEMY_ID] = 0
	sim.entities[PLAYER_ID] = sim.entities[ENEMY_ID] + Vector3(0, 0, 0.8)
	var frozen: Vector3 = sim.entities[ENEMY_ID]
	var during: Array[Event] = []
	for i in PLANT - 2:
		during.append_array(sim.tick([], DT))
	assert_eq(sim.entities[ENEMY_ID], frozen, "the plant is stationary")
	assert_eq(_of(during, "attack_telegraph").size(), 0, "and no attack may start during it")


func test_ordinary_decisions_resume_after_the_plant() -> void:
	_register_player()
	_register_enemy(Vector3(3.0, 0, -6.0))
	_never_attack()
	assert_ne(_run_straight(400), -1, "sanity: committed")
	for i in MAX_STEPS + PLANT + 4:
		sim.tick([], DT)
	assert_false(sim._cutoff_active.has(ENEMY_ID), "displacement is over")
	assert_true(sim.tick_count >= int(sim._cutoff_plant_until_tick.get(ENEMY_ID, 0)), "the plant has expired")
	# Put the player back out of reach so the resumed decision must be PURSUIT -- otherwise the
	# Fang is legitimately in-band and holding, which would pass for the wrong reason.
	sim.entities[PLAYER_ID] = sim.entities[ENEMY_ID] + Vector3(0, 0, 20.0)
	var before: Vector3 = sim.entities[ENEMY_ID]
	sim.tick([], DT)
	assert_ne(sim.entities[ENEMY_ID], before, "ordinary pursuit resumes; Bite is not guaranteed")


# ===================================================================================
# D. BLOCKAGE AND AGENCY
# ===================================================================================

func test_segment_one_blockage_terminates_the_cutoff_with_no_plant() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -6.0))
	_never_attack()
	assert_ne(_run_straight(400), -1, "sanity: committed")
	# Park the player directly on the clearance leg so it clamps immediately.
	var cutoff: Dictionary = sim._cutoff_active[ENEMY_ID]
	sim.entities[PLAYER_ID] = sim.entities[ENEMY_ID] + cutoff.direction * 0.5
	var events: Array[Event] = sim.tick([], DT)
	var ended: Array = _of(events, "cutoff_ended")
	assert_eq(ended.size(), 1, "the cutoff ends")
	assert_eq(String(ended[0].payload.reason), "clearance_blocked", "and names the failed objective")
	assert_false(sim._cutoff_plant_until_tick.has(ENEMY_ID),
		"clearance failed, so no plant is owed -- the action's precondition was never met")
	assert_eq(int(sim._next_cutoff_tick[ENEMY_ID]), int(ended[0].tick) + COOLDOWN, "cooldown still arms")


func test_flinch_during_displacement_aborts_and_forfeits_the_remainder() -> void:
	_register_player()
	_register_enemy(Vector3(3.0, 0, -6.0))
	_never_attack()
	sim.set_flinch_tuning(90, 20)
	sim.register_flinch_profile(ENEMY_ID, 1.0)
	sim.register_weapon(&"poke", 10.0, &"force", 100.0, 180.0, 0.0, 0)
	sim._weapons["poke"].flinch_capability = "pressure"
	assert_ne(_run_straight(400), -1, "sanity: committed")
	sim.tick([], DT)
	assert_true(sim._cutoff_active.has(ENEMY_ID), "sanity: displacing")

	sim.set_equipped_weapon(PLAYER_ID, &"poke")
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	assert_eq(_of(events, "flinched").size(), 1, "sanity: the mechanism fired")
	assert_eq(_of(events, "cutoff_aborted").size(), 1, "a flinch ABORTS self-propelled mobility")
	assert_eq(_of(events, "cutoff_ended").size(), 0, "abort vocabulary is distinct from blockage termination")
	assert_false(sim._cutoff_plant_until_tick.has(ENEMY_ID), "no plant: flinch recovery replaces it")

	var aborted_at: Vector3 = sim.entities[ENEMY_ID]
	for i in 10:
		sim.tick([], DT)
	assert_eq(sim.entities[ENEMY_ID], aborted_at, "remaining movement is FORFEITED, never frozen and resumed")


func test_flinch_during_the_plant_is_not_an_abort() -> void:
	_register_player()
	_register_enemy(Vector3(3.0, 0, -6.0))
	_never_attack()
	sim.set_flinch_tuning(90, 20)
	sim.register_flinch_profile(ENEMY_ID, 1.0)
	sim.register_weapon(&"poke", 10.0, &"force", 100.0, 180.0, 0.0, 0)
	sim._weapons["poke"].flinch_capability = "pressure"
	assert_ne(_run_straight(400), -1, "sanity: committed")
	for i in MAX_STEPS + 2:
		sim.tick([_move(Vector3(0, 0, 1))], DT)
		if sim._cutoff_plant_until_tick.has(ENEMY_ID):
			break
	assert_true(sim._cutoff_plant_until_tick.has(ENEMY_ID), "sanity: planting")
	var deadline: int = int(sim._cutoff_plant_until_tick[ENEMY_ID])

	sim.set_equipped_weapon(PLAYER_ID, &"poke")
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	assert_eq(_of(events, "flinched").size(), 1, "sanity: the mechanism fired")
	assert_eq(_of(events, "cutoff_aborted").size(), 0, "the movement was already complete -- this is NOT an abort")
	assert_eq(int(sim._cutoff_plant_until_tick[ENEMY_ID]), deadline,
		"the plant deadline is absolute, so recovery and plant run alongside each other (max, never sum)")


func test_fang_lifecycle_never_touches_the_players_route_fact() -> void:
	_register_player()
	_register_enemy(Vector3(0, 0, -2.0))
	sim.set_flinch_tuning(90, 20)
	sim.register_flinch_profile(ENEMY_ID, 1.0)
	for i in 60:
		sim.tick([_move(Vector3(0, 0, 1))], DT)
	var established: float = _route_length()
	assert_gte(established, MIN_ROUTE, "sanity: the player has a route")
	# Drive the Fang through its own commitments; none of them own the player's route.
	for i in 30:
		sim.tick([_move(Vector3(0, 0, 1))], DT)
	assert_gte(_route_length(), MIN_ROUTE,
		"the player's route is an OBSERVED-ACTOR fact -- the Fang's bite/flinch/leash must never erase it")
