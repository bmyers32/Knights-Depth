extends GutTest
## P33 — BOUNDED LOCAL OBSTACLE AVOIDANCE. The eleven tests pre-registered in the frozen spec.
##
## THE FROZEN PASS SENTENCE this mechanic is judged against:
##   "The avoidance passes when the Ooze follows around the corner instead of rubbing at it:
##    recognizes obstruction, routes around, arrives"
##
## THE GEOMETRY IS THE REAL ONE -- the shipped floor's arena -> neck -> approach, at its actual
## dimensions, with the pursuer OFF-AXIS beside the jamb. That off-axis start is the whole
## defect: a pursuer already lined up with the neck never needed help. A synthetic "wide room
## with a gap" was tried first and was too forgiving to demonstrate anything (baseline arrived
## almost as fast), which is why these tests use the dimensions that actually failed in play.
##
## MEASURED, on this geometry, over 600 ticks:
##   avoidance ON  -> arrives tick 202, RUB TICKS 0
##   avoidance OFF -> arrives tick 321, RUB TICKS 203
## "Rub ticks" is the recon's own metric: ticks that lost more than half the requested step.
##
## SYNTHETIC FIXTURE VALUES for tuning -- mechanical law only, never shipped balance.

const PLAYER := 0
const ENEMY := 1
const DT := 1.0 / 30.0
const COMMIT_TICKS := 45
const RADIUS := 1.45   # the shipped Ooze body
const SPEED := 1.5     # the shipped Ooze move speed

## The shipped floor's fight space, at its real dimensions.
const ARENA := Rect2(-15.0, -68.0, 30.0, 20.0)
const NECK := Rect2(-2.5, -49.5, 5.0, 9.0)
const APPROACH := Rect2(-6.0, -42.0, 12.0, 6.0)

## Pursuer beside the west jamb; Envoy up the neck. The literal failing case.
const ENEMY_START := Vector3(-5.0, 0.0, -50.0)
const PLAYER_AT := Vector3(0.0, 0.0, -43.0)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ARENA, NECK, APPROACH]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)


func _engage(enemy_at: Vector3 = ENEMY_START, player_at: Vector3 = PLAYER_AT, commit_ticks: int = COMMIT_TICKS) -> void:
	sim.add_entity(PLAYER, player_at, 0.0, Vector3(0, 0, -1), 0.4)
	sim.register_combatant(PLAYER, 5000.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.add_entity(ENEMY, enemy_at, SPEED, Vector3(0, 0, -1), RADIUS)
	sim.register_combatant(ENEMY, 500.0, &"ooze", 0, RADIUS, &"enemy")
	sim.register_weapon(&"test_slam", 5.0, &"force", 1.9, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"test_slam", 1.9, 10000),
		enemy_at, 2.2, 1.9, 30.0, 60.0, 0, 0,
		0.0, 0.0, 0, 0.0, 0, 0, 0, commit_ticks)
	sim._next_fire_tick[ENEMY] = 1_000_000  # never attacks: this is a movement test
	sim.debug_set_ai_active(ENEMY)


func _run(ticks: int) -> Array[Event]:
	var seen: Array[Event] = []
	for i in ticks:
		seen.append_array(sim.tick([] as Array[Command], DT))
	return seen


func _kinds(events: Array[Event]) -> Array:
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	return kinds


func _committed() -> bool:
	return sim._ai_avoid_waypoint.has(ENEMY)


## Runs a pursuit and reports {arrived_tick, rub_ticks, committed, reasons} -- the recon's own
## metrics, so the mechanic is judged on the same measurement that condemned the baseline.
func _pursue(commit_ticks: int, ticks: int = 600) -> Dictionary:
	_engage(ENEMY_START, PLAYER_AT, commit_ticks)
	var full_step: float = SPEED * DT
	var arrived: int = -1
	var rub: int = 0
	var committed: int = 0
	var reasons: Dictionary = {}
	for tick in ticks:
		var before: Vector3 = sim.entities[ENEMY]
		for event in sim.tick([] as Array[Command], DT):
			if event.kind == "avoidance_committed":
				committed += 1
			elif event.kind == "avoidance_cleared":
				var reason: String = String(event.payload["reason"])
				reasons[reason] = int(reasons.get(reason, 0)) + 1
		var moved: float = before.distance_to(sim.entities[ENEMY])
		if arrived < 0 and moved < full_step * 0.5:
			rub += 1
		if arrived < 0 and sim.entities[ENEMY].distance_to(PLAYER_AT) < 2.5:
			arrived = tick
	return {"arrived": arrived, "rub": rub, "committed": committed, "reasons": reasons}


# --- 1 & 11: the literal case, and PROOF THE CHAIN FIRED ---------------------------------

## THE HEADLINE, against the frozen sentence. A pursuer beside the jamb must ROUTE AROUND and
## ARRIVE -- and the test must prove the MECHANIC did it, which is the eleventh pre-registered
## test folded in here where the evidence actually lives. A lucky wall-slide that happens to end
## up somewhere useful is not this mechanic working.
func test_the_literal_corner_is_routed_around_and_the_chain_is_observable() -> void:
	var result: Dictionary = _pursue(COMMIT_TICKS)
	assert_gt(int(result["committed"]), 0,
		"DETECTOR -> SELECTOR -> COMMITMENT must be observable, or a lucky slide looks like success")
	assert_gt(int(result["arrived"]), -1, "it must ARRIVE")
	assert_lt(int(result["rub"]), 20,
		"and it must FOLLOW AROUND rather than rub: the unaided baseline loses 203 ticks here")


## The same geometry with avoidance UNAUTHORED is the measured baseline. This is the control that
## proves the mechanic is doing the work rather than the geometry being forgiving.
func test_without_avoidance_the_same_pursuit_rubs() -> void:
	var result: Dictionary = _pursue(0)
	assert_eq(int(result["committed"]), 0, "absence is off: no avoidance may fire")
	assert_gt(int(result["rub"]), 100, "the unaided baseline must still grind against the jamb")


## Stated as a comparison so the claim is relative and cannot rot into an absolute threshold.
func test_avoidance_strictly_beats_the_baseline_on_both_measures() -> void:
	var with_avoidance: Dictionary = _pursue(COMMIT_TICKS)
	before_each()
	var without: Dictionary = _pursue(0)
	assert_lt(int(with_avoidance["rub"]), int(without["rub"]), "fewer ticks lost to the wall")
	assert_lt(int(with_avoidance["arrived"]), int(without["arrived"]), "and it gets there sooner")


# --- THE REAL LOOP: commitment must actually survive (2026-08-31 regression) ---------------

## THE DEFECT THIS PINS. The first candidate offset is one body radius; the old `reached` test
## accepted `<= body_radius`, so a freshly chosen waypoint qualified as reached on the very next
## evaluation. Commitment lasted ONE TICK and avoid_commit_ticks never mattered -- live play
## showed 41 commits in one encounter, 38 cleared as "reached", deadlines two ticks apart.
##
## THE EXISTING OSCILLATION TEST DID NOT CATCH THIS, and could not: it asserts the waypoint does
## not CHANGE while committed, which was true. `commit -> reached -> re-commit` is a different
## cycle from `commit -> waypoint mutates`. This watches the cycle that actually occurred.
func test_a_freshly_selected_waypoint_is_not_instantly_reached() -> void:
	_engage()
	_run(2)
	assert_true(_committed(), "sanity: an obstructed pursuit commits")
	var waypoint: Vector3 = sim._ai_avoid_waypoint[ENEMY]
	var gap: float = sim.entities[ENEMY].distance_to(waypoint)

	_run(1)
	assert_true(_committed(),
		"the tick after selection must STILL be committed -- a minimum-offset waypoint %.2f away must not read as already reached" % gap)


## The whole-pursuit shape, in the recon's own currency. A per-tick greedy sidestep produces
## commits by the dozen; a real commitment produces a handful.
func test_commitment_does_not_churn_across_a_whole_pursuit() -> void:
	var result: Dictionary = _pursue(COMMIT_TICKS)
	assert_lt(int(result["committed"]), 8,
		"a committed route must not be re-chosen dozens of times (pre-fix live play: 41 in one encounter)")


## THE SEMANTICALLY CORRECT EXIT should dominate: a commitment ends because avoidance is no
## longer NEEDED, not because the actor drifted a body-width from its own waypoint.
func test_route_clear_dominates_successful_avoidance() -> void:
	var result: Dictionary = _pursue(COMMIT_TICKS)
	var reasons: Dictionary = result["reasons"]
	var clear: int = int(reasons.get("route_clear", 0))
	var reached: int = int(reasons.get("reached", 0))
	assert_gt(clear, reached,
		"route_clear must dominate on the observed corner; got %s" % reasons)


## The arrival tolerance must stay strictly below the smallest first candidate offset, which IS
## the smallest authored body radius. Pinned against shipped content rather than derived, so
## authoring a small enemy fails loudly instead of silently resurrecting the collision.
func test_arrival_tolerance_stays_below_every_authored_body() -> void:
	for enemy_key: StringName in [&"fang", &"ooze", &"watcher"]:
		var stats: Resource = ContentDB.get_resource(&"enemy", enemy_key)
		assert_lt(SimWorld._AVOID_ARRIVAL_TOLERANCE, stats.combat_radius,
			"%s body %.2f is not larger than the arrival tolerance -- a selected waypoint would read as instantly reached" % [enemy_key, stats.combat_radius])


# --- 2: the opposite side has no route and is not selected -------------------------------

## ASYMMETRY IS THE NORMAL CASE. Pinned against the arena's west wall, only the eastward sidestep
## can qualify. Proven by WHERE it goes -- there is no stored side to read, by design.
func test_the_side_without_a_route_is_not_selected() -> void:
	_engage(Vector3(-13.0, 0.0, -50.0))
	_run(2)
	assert_true(_committed(), "an obstructed pursuit must commit to something")
	var waypoint: Vector3 = sim._ai_avoid_waypoint[ENEMY]
	assert_gt(waypoint.x, -13.0, "the route must head AWAY from the wall it is pinned against")
	assert_true(sim._bounds.fits(waypoint, RADIUS), "and the waypoint itself must be legal")


# --- 3 & 4: diagonal and near-tangent approaches ------------------------------------------

func test_a_diagonal_blocked_approach_commits() -> void:
	_engage(Vector3(5.0, 0.0, -51.0))
	_run(2)
	assert_true(_committed(), "a diagonal into the jamb is still an obstruction")


func test_a_near_tangent_blocked_approach_commits() -> void:
	# Grazing the west jamb: the discriminating case a gross-blockage detector gets wrong. The
	# target sits just INSIDE the neck -- one body-width further west and the case would be
	# testing an illegal spawn instead of a tangent.
	_engage(Vector3(-2.6, 0.0, -50.5), Vector3(-2.0, 0.0, -44.0))
	_run(2)
	assert_true(_committed(), "a near-tangent block is a block")


# --- 5: unobstructed pursuit must not enter avoidance -------------------------------------

func test_clear_pursuit_never_enters_avoidance() -> void:
	# Straight up the middle of the neck: nothing in the way at any point.
	var result: Dictionary = {}
	_engage(Vector3(0.0, 0.0, -52.0))
	var events: Array[Event] = _run(400)
	assert_false(_kinds(events).has("avoidance_committed"),
		"a clear line must never trigger avoidance -- false positives would reroute healthy pursuit")
	assert_lt(sim.entities[ENEMY].distance_to(PLAYER_AT), 2.5, "and it still arrives")


## Regression guard for ordinary open-field pursuit, where every enemy spends most of its life.
func test_open_field_pursuit_is_unchanged() -> void:
	_engage(Vector3(-10.0, 0.0, -60.0), Vector3(10.0, 0.0, -60.0))
	var events: Array[Event] = _run(400)
	assert_false(_kinds(events).has("avoidance_committed"), "open ground obstructs nothing")


# --- 6: the pinned tie rule ----------------------------------------------------------------

## A PURPOSE-BUILT SYMMETRIC FIXTURE: a small void dead ahead with identical clearance either
## side, so both candidates qualify at the same offset and the TIE RULE alone decides. The real
## floor cannot produce this -- its geometry is asymmetric, which is the point of the recon --
## so the degeneracy rule needs geometry built to be degenerate.
func test_a_symmetric_tie_resolves_to_the_pinned_side_every_time() -> void:
	var chosen: Array = []
	for attempt in 3:
		sim = SimWorld.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		# Everything is walkable except a 2 x 2 void at the origin.
		var rects: Array[Rect2] = [
			Rect2(-20.0, -20.0, 19.0, 40.0),  # west of the void
			Rect2(1.0, -20.0, 19.0, 40.0),    # east of the void
			Rect2(-1.0, -20.0, 2.0, 19.0),    # the corridor below it
			Rect2(-1.0, 1.0, 2.0, 19.0),      # and above it
		]
		sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
		sim.register_patches(rects)
		_engage(Vector3(0.0, 0.0, -6.0), Vector3(0.0, 0.0, 6.0))
		_run(2)
		assert_true(_committed(), "a void dead ahead must obstruct")
		chosen.append(sim._ai_avoid_waypoint[ENEMY])
	assert_eq(chosen[0], chosen[1], "identical state must yield an identical route")
	assert_eq(chosen[1], chosen[2], "on every run, not merely twice")
	assert_lt(float(chosen[0].x), 0.0,
		"a perfect tie resolves to the pinned side (RIGHT of travel = -x heading +z)")


# --- 7: commitment prevents oscillation ----------------------------------------------------

## Without commitment a sidestep is rubbing with extra steps: the instant the waypoint stops
## being the nearest improvement, direct pursuit re-requests the blocked vector.
func test_commitment_prevents_per_tick_reconsideration() -> void:
	_engage()
	_run(2)
	assert_true(_committed(), "sanity: committed")
	var waypoint: Vector3 = sim._ai_avoid_waypoint[ENEMY]
	var changes: int = 0
	for i in 20:
		_run(1)
		if _committed() and sim._ai_avoid_waypoint[ENEMY] != waypoint:
			changes += 1
			waypoint = sim._ai_avoid_waypoint[ENEMY]
	assert_eq(changes, 0, "a committed route must not be re-chosen every tick")


# --- 8: the direct route clearing exits avoidance early ------------------------------------

func test_the_route_clearing_exits_avoidance_before_the_deadline() -> void:
	_engage()
	_run(2)
	assert_true(_committed(), "sanity: committed")
	# Put the target in open line of sight without touching the deadline.
	sim.entities[PLAYER] = Vector3(-5.0, 0.0, -58.0)
	var events: Array[Event] = _run(2)
	assert_false(_committed(), "a cleared direct route must release the commitment immediately")
	var reasons: Array = []
	for event in events:
		if event.kind == "avoidance_cleared":
			reasons.append(String(event.payload["reason"]))
	assert_true(reasons.has("route_clear"), "and say why it released")


# --- 9: the deadline is bounded and deterministic ------------------------------------------

## A commitment must never outlive its budget even if the obstruction never resolves. Expiry
## degrades to ordinary pursuit -- today's behaviour -- never a permanent avoidance state.
func test_the_deadline_bounds_the_commitment() -> void:
	_engage(ENEMY_START, PLAYER_AT, 10)
	_run(2)
	assert_true(_committed(), "sanity: committed")
	var events: Array[Event] = _run(11)
	var reasons: Array = []
	for event in events:
		if event.kind == "avoidance_cleared":
			reasons.append(String(event.payload["reason"]))
	assert_true(reasons.has("deadline") or reasons.has("route_clear"),
		"a commitment must end within its budget, and say how")
	if _committed():
		assert_lt(int(sim._ai_avoid_deadline[ENEMY]) - sim.tick_count, 11,
			"no commitment may outlive its authored budget")


# --- 10: state lifetime --------------------------------------------------------------------

## PER-ACTOR AI STATE, FLOOR LIFETIME. Filed with the _ai_* family, not promoted to floor-global
## state merely because a floor transition clears it.
func test_avoidance_state_dies_with_the_floor() -> void:
	_engage()
	_run(2)
	assert_true(_committed(), "sanity: committed before the transition")
	var rects: Array[Rect2] = [ARENA, NECK, APPROACH]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	assert_false(sim._ai_avoid_waypoint.has(ENEMY), "waypoint must not survive the floor")
	assert_false(sim._ai_avoid_deadline.has(ENEMY), "nor the deadline")


# --- PRESERVED LAWS ------------------------------------------------------------------------

## Avoidance changes what the AI ASKS FOR; it must never widen what legality PERMITS.
func test_avoidance_never_carries_an_actor_outside_legal_ground() -> void:
	_engage(Vector3(-13.0, 0.0, -50.0))
	for i in 400:
		sim.tick([] as Array[Command], DT)
		assert_true(sim._bounds.fits(sim.entities[ENEMY], RADIUS),
			"avoidance put the body outside legal ground at %s" % sim.entities[ENEMY])


## Territory confinement outranks avoidance: a routed enemy is still a confined enemy.
func test_avoidance_cannot_leave_its_territory() -> void:
	_engage()
	sim.register_encounter(0, [ARENA] as Array[Rect2], FloorLayers.ROLE_AMBIENT, false)
	assert_true(sim.assign_actor_encounter(ENEMY, 0), "sanity: bound to its site")
	for i in 400:
		sim.tick([] as Array[Command], DT)
		assert_true(sim._encounter_bounds[0].fits(sim.entities[ENEMY], RADIUS),
			"a routing enemy left its territory to %s" % sim.entities[ENEMY])
