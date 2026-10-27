extends GutTest
## THE TWO-BAND SPIKE CROSSING (G3 content iteration, 2026-10-27), proved in a real SimWorld.
##
## The piece is ground the Envoy walks through, south to north: 2 of staging, BAND A (4), an
## ISLAND of 3 that is never hazardous, BAND B (4), 2 of staging. The bands keep Floor 4's
## accepted schedule (safe 130 / active 30, the two 80 ticks apart) and its player-only targeting.
## What is asserted here is the SIM's behaviour under a walking, carrying Envoy -- never the
## progression validator's, which models no hazards at all.
##
## A FAIR CROSSING MUST NOT NEED INVULNERABILITY: every timed-crossing proof below registers the
## Envoy with ZERO hit i-frames, so any contact with an active band would show as damage. Only the
## blind crossing uses the shipped 90, because that is the case where it really does its job.

const PIECE := "res://game/content/floors/pieces/archive_traversal_spike_crossing.tres"
const SPIKES := "res://game/content/floors/recipes/proto_archive_fold_spikes.tres"
const DT := 1.0 / 30.0
const PLAYER := 0
const KEY := 7
const DEPTH: int = 1
const RouteMetrics := preload("res://tools/route_metrics.gd")
## A human-scale reaction, in ticks, between seeing a cue and moving on it (0.33 s).
const REACT: int = 10
## The zero-invulnerability runs give the Envoy this much health, so a mistake SHOWS (as lost
## health) instead of ending the run -- with no i-frames a band deals its damage every tick.
const PROBE_HEALTH: float = 1000.0
## Every walk is bounded: a body that cannot move fails the test instead of hanging the suite.
const WALK_BOUND: int = 2000


func _envoy() -> EnvoyStats:
	return ContentDB.get_resource(&"envoy", &"default")


## Loaded ONCE per test instance: `load()` of this piece measured 4.4 ms a call (2026-10-27), and
## the stagings and bands below are read every tick of every walk -- reloading it there was 55 s of
## the suite. The piece is read-only content, so caching changes nothing a test observes.
var _piece_cache: FloorPiece = null


func _piece() -> FloorPiece:
	if _piece_cache == null:
		_piece_cache = load(PIECE)
	return _piece_cache


func _pads() -> Array:
	return _piece().body.spike_pads


func _band(index: int) -> Rect2:
	return (_pads()[index] as SpikePadPlan).rect


## Where the Envoy may wait: the two stagings and the island, each the middle of its strip.
func _south_stage() -> float:
	return (_piece().footprint.position.y + _band(0).position.y) * 0.5


func _island() -> float:
	return (_band(0).end.y + _band(1).position.y) * 0.5


func _north_stage() -> float:
	return (_band(1).end.y + _piece().footprint.end.y) * 0.5


func _sim(iframes: int, carrying: bool = true) -> SimWorld:
	var envoy: EnvoyStats = _envoy()
	var sim := SimWorld.new()
	sim.seed_combat_rng(1)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var floor_rect: Rect2 = _piece().body.patches[0].rect
	var rects: Array[Rect2] = [floor_rect]
	var start := Vector3(0, 0, _south_stage())
	sim.load_floor(WalkableBounds.new(rects), start)
	sim.register_patches(rects)
	sim.add_entity(PLAYER, start, envoy.move_speed, Vector3(0, 0, 1), envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, iframes, envoy.combat_radius, &"player")
	sim.register_carrier(PLAYER, envoy.pickup_reach, envoy.pickup_cone_half_angle_degrees, envoy.pickup_underfoot_radius)
	sim.mark_run_persistent(PLAYER)
	for pad: SpikePadPlan in _pads():
		sim.register_spike_pad(pad.pad_id, pad.rect, pad.safe_ticks, pad.active_ticks, pad.phase_offset_ticks, pad.damage, pad.damage_type, pad.eligible_allegiances)
	if carrying:
		sim.register_carriable(KEY, start + Vector3(0, 0, -0.8))
		sim._lift_carriable(PLAYER, KEY)
	if iframes == 0:
		sim.debug_override_health(PLAYER, PROBE_HEALTH)
	return sim


func _z(sim: SimWorld) -> float:
	return sim.entities[PLAYER].z


func _move(sim: SimWorld, direction: Vector3) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, PLAYER, "move", {"direction": direction})] as Array[Command], DT)


func _idle(sim: SimWorld, ticks: int) -> void:
	for i in ticks:
		sim.tick([] as Array[Command], DT)


func _walk_to_z(sim: SimWorld, z: float, log: Array = []) -> bool:
	for i in WALK_BOUND:
		if _z(sim) >= z - 0.05:
			return true
		if sim.health_of(PLAYER) <= 0.0:
			break  # a body that cannot move ends the walk at once
		for event: Event in _move(sim, Vector3(0, 0, 1)):
			log.append([event.tick, event.kind])
	fail_test("could not walk to z %.2f (stuck at %.2f)" % [z, _z(sim)])
	return false


## The shipped cue, read the way presentation shows it: the band ahead has just gone DOWN.
func _wait_for_retraction(sim: SimWorld, pad_id: int) -> bool:
	var was_active: bool = sim._spike_pad_is_active(pad_id)
	for i in 400:
		_idle(sim, 1)
		var now: bool = sim._spike_pad_is_active(pad_id)
		if was_active and not now:
			_idle(sim, REACT)
			return true
		was_active = now
	fail_test("band %d never retracted" % pad_id)
	return false


## The other readable cue: the band shows NO warning (more than the warning lead from firing).
## Decided, then re-checked after the reaction delay -- a human sees the warning start and stops.
func _wait_for_calm(sim: SimWorld, pad_id: int) -> bool:
	var lead: int = FloorBuilder._HAZARD_WARN_LEAD_TICKS
	for i in 400:
		if sim.spike_pad_ticks_until_active(pad_id) > lead:
			_idle(sim, REACT)
			if sim.spike_pad_ticks_until_active(pad_id) > lead:
				return true
		_idle(sim, 1)
	fail_test("band %d never looked calm" % pad_id)
	return false


## Null when the crossing could not be completed (a cue never came, or the walk stalled).
func _timed_crossing(arrival: int, cue: Callable) -> SimWorld:
	var sim: SimWorld = _sim(0)
	_idle(sim, arrival)
	if not (cue.call(sim, 0) and _walk_to_z(sim, _island()) and cue.call(sim, 1) and _walk_to_z(sim, _north_stage())):
		return null
	return sim


# --- the authored shape -------------------------------------------------------------------------

func test_the_piece_is_two_full_width_bands_with_a_safe_island_and_safe_staging() -> void:
	var piece: FloorPiece = _piece()
	assert_eq(piece.lint([&"fang", &"ooze", &"watcher"]), [] as Array[Dictionary])
	assert_eq(piece.ports.size(), 2, "a two-port traversal segment")
	assert_eq(_pads().size(), 2)
	var floor_rect: Rect2 = piece.body.patches[0].rect
	for index in 2:
		assert_eq(_band(index).size.x, floor_rect.size.x, "band %d spans the whole width: it cannot be walked round" % index)
	var island: float = _band(1).position.y - _band(0).end.y
	assert_gt(island, 2.0 * _envoy().combat_radius, "the island holds a whole body clear of both bands")
	for z: float in [_south_stage(), _island(), _north_stage()]:
		for index in 2:
			assert_false(WalkableBounds.contains(_band(index), 0.0, z), "waiting ground at z %.1f is never a band" % z)
	# Floor 4's accepted schedule, the bands 80 ticks apart.
	var a: SpikePadPlan = _pads()[0]
	var b: SpikePadPlan = _pads()[1]
	assert_eq([a.safe_ticks, a.active_ticks, b.safe_ticks, b.active_ticks], [130, 30, 130, 30])
	assert_eq(posmod(a.phase_offset_ticks - b.phase_offset_ticks, a.safe_ticks + a.active_ticks), 80)
	for pad: SpikePadPlan in _pads():
		assert_eq(pad.eligible_allegiances, [&"player"] as Array[StringName], "band %d: player-only, unchanged" % pad.pad_id)


## TICK-ACCURATE PHASE AND ITS PICTURE: a band is active exactly when the authored schedule says,
## and the warning look the Arena paints (from the sim's own countdown) reads ACTIVE on exactly the
## ticks damage resolves, EARLY/URGENT for the 50 before, INACTIVE otherwise.
func test_the_bands_fire_on_their_authored_ticks_and_the_warning_matches() -> void:
	var sim: SimWorld = _sim(0, false)
	var lead: int = FloorBuilder._HAZARD_WARN_LEAD_TICKS
	for i in 320:
		for pad: SpikePadPlan in _pads():
			var cycle: int = pad.safe_ticks + pad.active_ticks
			var expected: bool = posmod(sim.tick_count + pad.phase_offset_ticks, cycle) >= pad.safe_ticks
			assert_eq(sim._spike_pad_is_active(pad.pad_id), expected, "pad %d tick %d" % [pad.pad_id, sim.tick_count])
			var until: int = sim.spike_pad_ticks_until_active(pad.pad_id)
			var look: StringName = FloorBuilder.hazard_warning_look(until)["phase"]
			assert_eq(look == &"active", expected, "pad %d tick %d: active look iff active" % [pad.pad_id, sim.tick_count])
			if not expected:
				assert_eq(look == &"inactive", until > lead, "pad %d tick %d: the warning shows exactly in the last %d ticks" % [pad.pad_id, sim.tick_count, lead])
		_idle(sim, 1)


# --- fairness, carrying, with NO invulnerability --------------------------------------------------

## "WAIT TILL IT DROPS, THEN GO": from every one of the 160 arrival phases, a carrying Envoy who
## steps REACT ticks after each band retracts crosses both with no damage, no drop, and every wait
## spent on the island or the staging.
func test_going_when_each_band_drops_crosses_unhit_from_every_arrival_phase() -> void:
	var cycle: int = _pads()[0].safe_ticks + _pads()[0].active_ticks
	var slowest: int = 0
	for arrival in cycle:
		var sim: SimWorld = _timed_crossing(arrival, _wait_for_retraction)
		if sim == null or sim.health_of(PLAYER) != PROBE_HEALTH or sim.carried_by(PLAYER) != KEY:
			fail_test("arrival %d: not crossed unhit and carrying (the first counter-example; the rest are not run)" % arrival)
			return
		slowest = maxi(slowest, sim.tick_count - arrival)
	assert_lt(slowest, 2 * cycle, "never more than two cycles, waits included (%d ticks)" % slowest)


## "GO WHEN IT LOOKS CALM" (no warning showing), re-checked after the reaction: also unhit from
## every phase -- the 50-tick warning is longer than the reaction plus the walk across a band.
func test_going_when_each_band_looks_calm_crosses_unhit_from_every_arrival_phase() -> void:
	var cycle: int = _pads()[0].safe_ticks + _pads()[0].active_ticks
	var crossed: int = 0
	for arrival in cycle:
		var sim: SimWorld = _timed_crossing(arrival, _wait_for_calm)
		if sim == null or sim.health_of(PLAYER) != PROBE_HEALTH or sim.carried_by(PLAYER) != KEY:
			fail_test("arrival %d: not crossed unhit and carrying (the first counter-example; the rest are not run)" % arrival)
			return
		crossed += 1
	assert_eq(crossed, cycle, "every arrival phase crossed unhit")


## CAUGHT ON A BAND WHEN ITS WARNING STARTS: from its middle, the nearest edge is 2 units (15
## ticks), so a player who reacts within 30 ticks still steps off clear; one who stands for 40 does
## not. The tolerance is the 50-tick warning minus the walk to the edge, and is stated here.
func test_a_warning_seen_from_mid_band_leaves_a_reaction_margin_of_at_least_a_second() -> void:
	for react: int in [30, 40]:
		var sim: SimWorld = _sim(0, false)
		# Wait on the staging for the warning to start, THEN stand mid-band: caught on it as it warns.
		for i in WALK_BOUND:
			if sim.spike_pad_ticks_until_active(0) == FloorBuilder._HAZARD_WARN_LEAD_TICKS:
				break
			_idle(sim, 1)
		if sim.spike_pad_ticks_until_active(0) != FloorBuilder._HAZARD_WARN_LEAD_TICKS:
			fail_test("band A never began to warn")
			return
		sim.entities[PLAYER] = Vector3(0, 0, _band(0).get_center().y)
		_idle(sim, react)
		for i in WALK_BOUND:
			if _z(sim) <= _band(0).position.y - 0.05:
				break
			_move(sim, Vector3(0, 0, -1))
		_idle(sim, 40)
		if react == 30:
			assert_eq(sim.health_of(PLAYER), PROBE_HEALTH, "stepped off in time after %d ticks" % react)
		else:
			assert_lt(sim.health_of(PLAYER), PROBE_HEALTH, "too slow after %d ticks: the band fired underfoot" % react)


## OCCUPANCY IS THE BODY'S CENTRE, inclusive, as for every plate: a body overlapping an active band
## with its centre off it is not hurt; a centre on the band's edge is.
func test_a_body_overlapping_an_active_band_is_hurt_only_when_its_centre_is_on_it() -> void:
	var edge: float = _band(0).position.y
	for case: Array in [[edge - 0.3, false], [edge, true]]:
		var sim: SimWorld = _sim(0, false)
		sim.entities[PLAYER] = Vector3(0, 0, case[0])
		for i in WALK_BOUND:
			if sim._spike_pad_is_active(0):
				break
			_idle(sim, 1)
		_idle(sim, 5)
		assert_eq(sim.health_of(PLAYER) < PROBE_HEALTH, case[1], "centre at %.2f, edge at %.2f" % [case[0], edge])


# --- blind, with the shipped invulnerability: what a mistake costs --------------------------------

## WALKING STRAIGHT THROUGH, from every phase: at most one hit per band (never death from full
## health). A hit drops the key where the Envoy stood; it lies on walkable ground, the Envoy steps
## past it, turns and lifts it -- inside the hit's invulnerability, so the band that dropped it
## cannot strike again -- and finishes the crossing carrying it.
func test_a_blind_carrier_takes_at_most_a_hit_a_band_and_recovers_the_key_every_time() -> void:
	var cycle: int = _pads()[0].safe_ticks + _pads()[0].active_ticks
	var hits_seen: Array[int] = []
	for arrival in cycle:
		var sim: SimWorld = _sim(_envoy().iframe_ticks_on_hit)
		_idle(sim, arrival)
		var hits: int = 0
		var health: float = sim.health_of(PLAYER)
		var guard: int = 0
		while _z(sim) < _north_stage() - 0.05 and guard < 2000 and sim.health_of(PLAYER) > 0.0:
			guard += 1
			_move(sim, Vector3(0, 0, 1))
			if sim.health_of(PLAYER) < health:
				hits += 1
				health = sim.health_of(PLAYER)
			if sim.carried_by(PLAYER) == -1:
				if sim.health_of(PLAYER) <= 0.0:
					break  # incapacitated: reported below, not recovered from
				var lying: Vector3 = sim._carriables[KEY]["position"]
				assert_true(WalkableBounds.contains(_piece().body.patches[0].rect, lying.x, lying.z), "arrival %d: the key lies on the floor" % arrival)
				for i in WALK_BOUND:
					if _z(sim) >= lying.z + 1.0:
						break
					_move(sim, Vector3(0, 0, 1))
				sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": lying - sim.entities[PLAYER], "phase": "pressed"})] as Array[Command], DT)
				sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": lying - sim.entities[PLAYER], "phase": "released"})] as Array[Command], DT)
				assert_eq(sim.carried_by(PLAYER), KEY, "arrival %d: the key was lifted again" % arrival)
		if hits > 2 or sim.health_of(PLAYER) <= 0.0 or sim.carried_by(PLAYER) != KEY:
			fail_test("arrival %d: %d hits, health %.0f, carrying %d (the first counter-example; the rest are not run)" % [arrival, hits, sim.health_of(PLAYER), sim.carried_by(PLAYER)])
			return
		hits_seen.append(hits)
	assert_eq(hits_seen.size(), cycle, "every arrival phase crossed, the key recovered after every hit")
	gut.p("blind crossings: hits per arrival phase -- 0: %d, 1: %d, 2: %d" % [hits_seen.count(0), hits_seen.count(1), hits_seen.count(2)])


func test_the_same_commands_replay_the_same_crossing() -> void:
	var logs: Array = []
	for run in 2:
		var sim: SimWorld = _sim(0)
		_idle(sim, 37)
		var log: Array = []
		assert_true(_wait_for_retraction(sim, 0) and _walk_to_z(sim, _island(), log) and _wait_for_retraction(sim, 1) and _walk_to_z(sim, _north_stage(), log))
		log.append([sim.tick_count, sim.entities[PLAYER]])
		logs.append(log)
	assert_eq(logs[0], logs[1])


# --- in the fold (the experimental recipe; the baseline is untouched) -----------------------------

func _radii(recipe: FloorRecipe) -> Dictionary:
	var radii: Dictionary = {}
	for key: StringName in recipe.stratum.enemy_keys:
		radii[key] = ContentDB.get_resource(&"enemy", key).combat_radius
	return radii


func _rules(set_down: bool) -> Dictionary:
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_A")
	return {"body_radius": _envoy().combat_radius, "attack_reach": sword.reach, "pickup_reach": _envoy().pickup_reach, "set_down_anywhere": set_down}


func _compose(run_seed: int) -> FloorComposer.ComposeResult:
	var recipe: FloorRecipe = load(SPIKES)
	return FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, _radii(recipe))


func _compiled(layout: AuthoredLayout) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.stratum_id = layout.stratum_id
	LayoutCompiler.compile(layout, plan)
	return plan


func test_the_spike_fold_keeps_its_declarations_and_the_crossing_is_reachable_and_omittable() -> void:
	var recipe: FloorRecipe = load(SPIKES)
	assert_eq(recipe.lint(), [] as Array[Dictionary])
	for run_seed in [1, 7, 42]:
		var composed: FloorComposer.ComposeResult = _compose(run_seed)
		assert_true(composed.report.succeeded(), composed.report.summary())
		if not composed.report.succeeded():
			continue
		var again: FloorComposer.ComposeResult = _compose(run_seed)
		assert_eq(JSON.stringify(_compiled(composed.layout).to_dict()), JSON.stringify(_compiled(again.layout).to_dict()), "seed %d: deterministic" % run_seed)
		var report: ObjectiveIntegrity.Report = ObjectiveIntegrity.check(recipe, composed, _compiled(composed.layout), _rules(true))
		assert_eq(report.outcome, ObjectiveIntegrity.OUTCOME_PASS, "seed %d: %s" % [run_seed, report.summary()])
		var hazard: Array = report.claims.filter(func(c: ObjectiveIntegrity.Claim) -> bool: return c.node == &"hazard")
		assert_eq(hazard.map(func(c: ObjectiveIntegrity.Claim) -> String: return "%s:%s" % [c.kind, c.result.verdict]),
			["reach:route_found", "ground:route_found"], "seed %d: the crossing can be entered, and the floor finished without it" % run_seed)
		assert_eq(report.claims.filter(func(c: ObjectiveIntegrity.Claim) -> bool: return c.node != &"hazard").size(), 7, "the seven mandatory claims of the fold stand")


func test_the_crossing_opens_no_early_way_into_the_vault() -> void:
	var recipe: FloorRecipe = load(SPIKES)
	var composed: FloorComposer.ComposeResult = _compose(7)
	var plan: FloorPlan = _compiled(composed.layout)
	var vault: StringName = RouteMetrics.instance_of_node(recipe, composed, &"objective")
	var pit: StringName = RouteMetrics.instance_of_node(recipe, composed, &"encounter")
	var session := ProgressionValidator.ObjectiveSession.new(plan, _rules(true))
	var fight: int = composed.emit.global_id(pit, &"encounter", 0)
	for goal: Dictionary in [{ProgressionValidator.GOAL_LIFT: composed.emit.global_id(vault, &"carriable", 0)},
			{ProgressionValidator.GOAL_OPEN: RouteMetrics.connection_of(composed, vault, &"back")}]:
		assert_eq(session.ask({ProgressionValidator.FORBID_CLEAR: [fight]}, goal).verdict, ProgressionValidator.ObjectiveResult.ROUTE_NONE, str(goal))


## BOTH WAYS HOME stay open once the key is lifted: the crossing, and the long way back through the
## cleared arena (asked by walking round the crossing's ground). Both measured as walked distance.
func test_with_the_key_in_hand_both_the_crossing_and_the_long_way_reach_the_door() -> void:
	var recipe: FloorRecipe = load(SPIKES)
	for run_seed in [1, 7, 42]:
		var composed: FloorComposer.ComposeResult = _compose(run_seed)
		var plan: FloorPlan = _compiled(composed.layout)
		var landmark: StringName = RouteMetrics.instance_of_node(recipe, composed, &"landmark")
		var hazard: Rect2 = FloorDraft.world_footprint(composed.draft.instance_of(RouteMetrics.instance_of_node(recipe, composed, &"hazard")))
		var open: Dictionary = RouteMetrics.open_except(plan, [RouteMetrics.connection_of(composed, landmark, &"out")])
		var key: Vector3 = plan.carriables[0].position
		var receiver: Rect2 = Rect2()
		for trigger: FloorTrigger in plan.triggers:
			if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
				receiver = trigger.region
		var radius: float = _envoy().combat_radius
		var short: float = float(RouteMetrics.walk(plan, open, Vector2(key.x, key.z), receiver, radius)["length"])
		var long: float = float(RouteMetrics.walk(plan, open, Vector2(key.x, key.z), receiver, radius, [hazard])["length"])
		assert_gt(short, 0.0, "seed %d: through the crossing" % run_seed)
		assert_gt(long, short, "seed %d: the long way exists and is longer (%.0f vs %.0f)" % [run_seed, long, short])
		gut.p("seed %d walked carry: crossing %.1f, long way %.1f" % [run_seed, short, long])
