extends GutTest
## THE KEY-TRIGGERED REINFORCEMENT (G3 iteration, 2026-10-27): the vault key's FIRST lift wakes a
## small optional roster in the landmark, through the one cross-piece wire the recipe declares.
##
##   1. THE WIRE: the emitted lift trigger carries the remapped activation; the recipe lint and the
##      emitter refuse every malformed endpoint; composition is deterministic; the accepted
##      recipes are untouched; integrity still holds and the roster is never a required kill.
##   2. THE REAL ARENA (seeds 1, 7, 42): dormant until the lift, awake exactly once after it; well
##      clear of the Envoy when it wakes; every Fang held by the LEASH LAW on every tick -- a
##      non-sealing roster is NOT walled into its territory (sim_world _hard_encounter_confinement
##      _applies, ruled 2026-09-03): home is where it returns to, its leash how far a chase may pull
##      it -- and never once on the spike crossing or in the vault; the Envoy
##      arriving by the spike shortcut AND by the long way; the door delivered to with the Fangs
##      still ALIVE; the set-down-and-fight strategy. Tactical evidence is the sim's own state --
##      the progression validator assumes fights are won and cannot certify any of this.

const GUARDED := "res://game/content/floors/recipes/proto_archive_fold_spikes_guarded.tres"
const SPIKES := "res://game/content/floors/recipes/proto_archive_fold_spikes.tres"
const DT := 1.0 / 30.0
const DEPTH: int = 1
const REACT: int = 10
## Every walk and wait is bounded; a stall fails, never hangs.
const STEP_BUDGET: int = 600
const DROP_BUDGET: int = 12
const RouteMetrics := preload("res://tools/route_metrics.gd")


func _envoy() -> EnvoyStats:
	return ContentDB.get_resource(&"envoy", &"default")


func _radii(recipe: FloorRecipe) -> Dictionary:
	var radii: Dictionary = {}
	for key: StringName in recipe.stratum.enemy_keys:
		radii[key] = ContentDB.get_resource(&"enemy", key).combat_radius
	return radii


func _compose(path: String, run_seed: int) -> FloorComposer.ComposeResult:
	var recipe: FloorRecipe = load(path)
	return FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, _radii(recipe))


func _compiled(layout: AuthoredLayout) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.stratum_id = layout.stratum_id
	LayoutCompiler.compile(layout, plan)
	return plan


func _rules(set_down: bool) -> Dictionary:
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_A")
	return {"body_radius": _envoy().combat_radius, "attack_reach": sword.reach, "pickup_reach": _envoy().pickup_reach, "set_down_anywhere": set_down}


# --- 1. THE WIRE --------------------------------------------------------------------------------

func test_the_first_lift_trigger_carries_the_remapped_activation_of_the_landmark_roster() -> void:
	var recipe: FloorRecipe = load(GUARDED)
	assert_eq(recipe.lint(), [] as Array[Dictionary])
	for run_seed in [1, 7, 42]:
		var composed: FloorComposer.ComposeResult = _compose(GUARDED, run_seed)
		assert_true(composed.report.succeeded(), composed.report.summary())
		if not composed.report.succeeded():
			continue
		var plan: FloorPlan = _compiled(composed.layout)
		var vault: StringName = RouteMetrics.instance_of_node(recipe, composed, &"objective")
		var landmark: StringName = RouteMetrics.instance_of_node(recipe, composed, &"landmark")
		var lift_id: int = composed.emit.global_id(vault, &"trigger", 0)
		var guard_id: int = composed.emit.global_id(landmark, &"encounter", 0)
		var lift: FloorTrigger = null
		for trigger: FloorTrigger in plan.triggers:
			if trigger.trigger_id == lift_id:
				lift = trigger
		assert_eq(lift.kind, FloorLayers.TRIGGER_CARRIABLE_LIFTED)
		assert_true(lift.once, "a lift watcher fires on the first lift only")
		assert_eq(lift.effects.map(func(e: Dictionary) -> String: return "%s:%d" % [e["kind"], e["target_id"]]),
			["open_connection:%d" % RouteMetrics.connection_of(composed, vault, &"back"), "activate_encounter:%d" % guard_id],
			"seed %d: the piece's own effect first, then the wired one, remapped into the landmark" % run_seed)
		var guard: EncounterSite = plan.encounter_by_id(guard_id)
		assert_eq([guard.role, guard.confines_player, guard.spawn_at_floor_load], [FloorLayers.ROLE_OPTIONAL, false, false], "optional, non-sealing, deferred")
		assert_true(FloorDraft.world_footprint(composed.draft.instance_of(landmark)).encloses(guard.regions[0]), "its territory is the landmark's")
		var again: FloorComposer.ComposeResult = _compose(GUARDED, run_seed)
		assert_eq(JSON.stringify(_compiled(again.layout).to_dict()), JSON.stringify(plan.to_dict()), "seed %d: deterministic" % run_seed)


func test_the_recipe_lint_refuses_every_malformed_dependency() -> void:
	var cases: Array = [
		[{"from": &"nowhere", "from_port": &"lift_signal", "to": &"landmark", "effect": &"activate_encounter", "target_key": &"E_GUARD"}, &"dependency_node_unknown"],
		[{"from": &"landmark", "from_port": &"lift_signal", "to": &"landmark", "effect": &"activate_encounter", "target_key": &"E_GUARD"}, &"dependency_same_node"],
		[{"from": &"objective", "from_port": &"", "to": &"landmark", "effect": &"activate_encounter", "target_key": &"E_GUARD"}, &"dependency_endpoint_missing"],
		[{"from": &"objective", "from_port": &"lift_signal", "to": &"landmark", "effect": &"open_connection", "target_key": &"E_GUARD"}, &"dependency_effect_unsupported"],
	]
	for case: Array in cases:
		var recipe: FloorRecipe = (load(GUARDED) as FloorRecipe).duplicate()
		recipe.dependencies = [case[0]] as Array[Dictionary]
		var rules: Array = recipe.lint().map(func(f: Dictionary) -> StringName: return f["rule"])
		assert_has(rules, case[1], str(case[0]))
	var twice: FloorRecipe = (load(GUARDED) as FloorRecipe).duplicate()
	twice.dependencies = [twice.dependencies[0], twice.dependencies[0]] as Array[Dictionary]
	assert_has(twice.lint().map(func(f: Dictionary) -> StringName: return f["rule"]), &"dependency_duplicate")


## THE EMITTER CHECKS THE PIECES ACTUALLY CAST: a wire to a port that is not an unlock port, to a
## record the target piece lacks, or of a kind that may not be wired is a named structural error
## with no layout -- never a plausible floor with a dangling effect.
func test_the_emitter_refuses_a_wire_whose_cast_endpoints_do_not_fit() -> void:
	var recipe: FloorRecipe = load(GUARDED)
	var composed: FloorComposer.ComposeResult = _compose(GUARDED, 7)
	var vault: StringName = RouteMetrics.instance_of_node(recipe, composed, &"objective")
	var landmark: StringName = RouteMetrics.instance_of_node(recipe, composed, &"landmark")
	var cases: Array = [
		[&"back", &"E_GUARD", FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, &"wire_port_not_unlock"],
		[&"lift_signal", &"E_NOBODY", FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, &"wire_target_unknown"],
		[&"lift_signal", &"E_GUARD", FloorLayers.EFFECT_OPEN_CONNECTION, &"wire_effect_unsupported"],
	]
	for case: Array in cases:
		var draft: FloorDraft = composed.draft
		var mark: Dictionary = draft.mark()
		draft.wires.clear()
		draft.wire(vault, case[0], landmark, case[2], case[1])
		var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
		assert_null(report.layout, str(case))
		assert_false(report.errors_of(case[3]).is_empty(), "%s: %s" % [case[3], report.summary()])
		draft.wires.clear()
		draft.wire(vault, &"lift_signal", landmark, FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, &"E_GUARD")
		draft.rewind(mark)
	draft_self_wire(composed, vault)


func draft_self_wire(composed: FloorComposer.ComposeResult, vault: StringName) -> void:
	composed.draft.wires.clear()
	composed.draft.wire(vault, &"lift_signal", vault, FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, &"E_GUARD")
	assert_false(DraftEmitter.emit(composed.draft).errors_of(&"wire_same_piece").is_empty(), "a wire never stays inside one piece")


## The roster is optional: integrity holds with keys set down anywhere, no claim makes the Fangs a
## required kill, the crossing is still reachable and omittable, the mandatory beats still stand.
func test_integrity_holds_and_the_reinforcement_is_never_a_required_kill() -> void:
	var recipe: FloorRecipe = load(GUARDED)
	for run_seed in [1, 7, 42]:
		var composed: FloorComposer.ComposeResult = _compose(GUARDED, run_seed)
		var report: ObjectiveIntegrity.Report = ObjectiveIntegrity.check(recipe, composed, _compiled(composed.layout), _rules(true))
		assert_eq(report.outcome, ObjectiveIntegrity.OUTCOME_PASS, "seed %d: %s" % [run_seed, report.summary()])
		var guard_id: int = composed.emit.global_id(RouteMetrics.instance_of_node(recipe, composed, &"landmark"), &"encounter", 0)
		assert_eq(report.claims.filter(func(c: ObjectiveIntegrity.Claim) -> bool: return c.kind == ObjectiveIntegrity.KIND_CLEAR and c.record_id == guard_id), [], "never a required kill")
		assert_eq(report.claims.size(), 9, "the fold's seven mandatory claims and the crossing's two optional ones, as before")


## Same geometry, same layouts: the guarded variant composes exactly the floors the spike variant
## does (the reinforcement is content inside the landmark's unchanged footprint and ports).
func test_the_reinforcement_does_not_change_composition() -> void:
	for run_seed in [1, 7, 42]:
		var spikes: GenerationReport = _compose(SPIKES, run_seed).report
		var guarded: GenerationReport = _compose(GUARDED, run_seed).report
		assert_eq(guarded.spatial_signature().replace("archive_landmark_crossing_guarded", "archive_landmark_crossing"), spikes.spatial_signature(), "seed %d" % run_seed)
		assert_eq(guarded.rejections, spikes.rejections, "seed %d: the same search, step for step" % run_seed)


# --- 2. THE REAL ARENA --------------------------------------------------------------------------

class Run:
	extends RefCounted
	var recipe: FloorRecipe
	var composed: FloorComposer.ComposeResult
	var plan: FloorPlan
	var arena: Node3D
	var guard_id: int = -1
	var territory: Rect2 = Rect2()
	var landmark: Rect2 = Rect2()
	var hazard: Rect2 = Rect2()
	var vault: Rect2 = Rect2()
	## The furthest any Fang was ever seen outside its home territory, and every tick one stood on
	## ground it must never reach (the spike crossing, the vault).
	var furthest_out: float = 0.0
	var trespass: Array = []


func _boot(run_seed: int) -> Run:
	var run := Run.new()
	run.recipe = load(GUARDED)
	run.composed = _compose(GUARDED, run_seed)
	assert_true(run.composed.report.succeeded(), run.composed.report.summary())
	var plan := FloorPlan.new()
	plan.run_seed = run_seed
	plan.depth = DEPTH
	plan.floor_seed = SeedMix.derive(run_seed, DEPTH)
	plan.stratum_id = run.composed.layout.stratum_id
	plan.authored_layout = false
	LayoutCompiler.compile(run.composed.layout, plan)
	run.plan = plan
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.run_seed = run_seed
	arena.itinerary = [DEPTH] as Array[int]
	arena.standalone = true
	arena.prepared_first_plan = plan
	add_child_autofree(arena)
	# Survivability keeps a TRAVERSAL test measuring traversal; every hit is still counted.
	arena.sim.debug_override_health(arena.envoy.actor_id, 100000.0)
	run.arena = arena
	var landmark_id: StringName = RouteMetrics.instance_of_node(run.recipe, run.composed, &"landmark")
	run.guard_id = run.composed.emit.global_id(landmark_id, &"encounter", 0)
	run.territory = plan.encounter_by_id(run.guard_id).regions[0]
	run.landmark = FloorDraft.world_footprint(run.composed.draft.instance_of(landmark_id))
	run.hazard = FloorDraft.world_footprint(run.composed.draft.instance_of(RouteMetrics.instance_of_node(run.recipe, run.composed, &"hazard")))
	run.vault = FloorDraft.world_footprint(run.composed.draft.instance_of(RouteMetrics.instance_of_node(run.recipe, run.composed, &"objective")))
	return run


func _id(run: Run) -> int:
	return run.arena.envoy.actor_id


func _at(run: Run) -> Vector3:
	return run.arena.sim.entities[_id(run)]


func _fangs(run: Run) -> Array:
	return run.arena.sim._encounter_roster[run.guard_id].filter(func(a: int) -> bool: return run.arena.sim.health_of(a) > 0.0)


## Every step goes through here, so the leash and the forbidden ground are checked on EVERY tick.
func _step(run: Run, commands: Array[Command]) -> void:
	run.arena._step(commands, DT)
	if String(run.arena.sim._encounter_state.get(run.guard_id, "")) != "active":
		return
	for actor_id: int in _fangs(run):
		if run.arena.sim.debug_is_combat_absent(actor_id):
			continue  # underground: where it surfaces is checked when it surfaces
		var p: Vector3 = run.arena.sim.entities[actor_id]
		var nearest := Vector2(clampf(p.x, run.territory.position.x, run.territory.end.x), clampf(p.z, run.territory.position.y, run.territory.end.y))
		run.furthest_out = maxf(run.furthest_out, nearest.distance_to(Vector2(p.x, p.z)))
		if WalkableBounds.contains(run.hazard, p.x, p.z) or WalkableBounds.contains(run.vault, p.x, p.z):
			run.trespass.append([run.arena.sim.tick_count, actor_id, p])


## The leash an unsealed Fang is held by (its own stats -- never a number restated here).
func _leash() -> float:
	return ContentDB.get_resource(&"enemy", &"fang").leash_radius


func _idle(run: Run, ticks: int) -> void:
	for i in ticks:
		_step(run, [] as Array[Command])


func _walk_to(run: Run, target: Vector3, reach: float) -> bool:
	for i in STEP_BUDGET:
		var offset: Vector3 = target - _at(run)
		offset.y = 0.0
		if offset.length() < reach:
			return true
		_step(run, [Command.new(run.arena.sim.tick_count, _id(run), "move", {"direction": offset.normalized()})] as Array[Command])
	return false


func _click(run: Run, aim: Vector3) -> void:
	_step(run, [Command.new(run.arena.sim.tick_count, _id(run), "attack", {"aim": aim, "phase": "pressed"})] as Array[Command])
	_step(run, [Command.new(run.arena.sim.tick_count, _id(run), "attack", {"aim": aim, "phase": "released"})] as Array[Command])


func _pad_containing(run: Run, point: Vector2) -> int:
	for pad: SpikePadPlan in run.plan.spike_pads:
		if WalkableBounds.contains(pad.rect, point.x, point.y):
			return pad.pad_id
	return -1


func _wait_for_retraction(run: Run, pad_id: int) -> void:
	var was: bool = run.arena.sim._spike_pad_is_active(pad_id)
	for i in 400:
		_idle(run, 1)
		var now: bool = run.arena.sim._spike_pad_is_active(pad_id)
		if was and not now:
			_idle(run, REACT)
			return
		was = now
	fail_test("band %d never dropped" % pad_id)


## The measured shortest route under the sim's doors, never through `avoid`, waiting for each band
## to drop before stepping onto it (the waiting is _follow's).
func _route(run: Run, target: Rect2, avoid: Array) -> Array:
	var open: Dictionary = {}
	for connection_id: int in run.arena.sim._connection_open:
		if bool(run.arena.sim._connection_open[connection_id]):
			open[connection_id] = true
	var at: Vector3 = _at(run)
	return RouteMetrics.walk(run.plan, open, Vector2(at.x, at.z), target, _envoy().combat_radius, avoid)["path"]


## Walks a route, waiting for each band to drop before stepping onto it; stops early (true) as
## soon as `stop_when` holds; false when a step could not be made.
func _follow(run: Run, path: Array, stop_when: Callable = Callable()) -> bool:
	for index: int in range(1, path.size()):
		if stop_when.is_valid() and stop_when.call():
			return true
		var point: Vector2 = path[index]
		var pad: int = _pad_containing(run, point)
		var here: Vector3 = _at(run)
		if pad >= 0 and _pad_containing(run, Vector2(here.x, here.z)) != pad:
			_wait_for_retraction(run, pad)
		if not _walk_to(run, Vector3(point.x, 0.0, point.y), 0.5):
			return false
	return true


func _receiver(plan: FloorPlan) -> Rect2:
	for trigger: FloorTrigger in plan.triggers:
		if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
			return trigger.region
	return Rect2()


func _plate(plan: FloorPlan) -> Rect2:
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") == FloorLayers.EFFECT_ACTIVATE_ENCOUNTER and trigger.region.get_area() > 0.0:
				return trigger.region
	return Rect2()


## Arrival -> plate -> the pit's fight removed -> the key, aimed at and lifted. Returns false when a
## step could not be made.
func _fetch(run: Run) -> bool:
	if not _follow(run, _route(run, _plate(run.plan), [])):
		return false
	_walk_to(run, Vector3(_plate(run.plan).get_center().x, 0, _plate(run.plan).get_center().y), 0.2)
	_idle(run, 2)
	var pit: int = run.composed.emit.global_id(RouteMetrics.instance_of_node(run.recipe, run.composed, &"encounter"), &"encounter", 0)
	for actor_id: int in run.arena.sim._encounter_roster[pit]:
		run.arena.sim.debug_override_health(actor_id, 0.0)
	_idle(run, 3)
	var key: Vector3 = run.plan.carriables[0].position
	if not _follow(run, _route(run, Rect2(key.x - 1.5, key.z - 1.5, 3.0, 3.0), [])):
		return false
	_walk_to(run, key, _envoy().pickup_reach * 0.8)
	_click(run, key - _at(run))
	return run.arena.sim.carried_by(_id(run)) == run.plan.carriables[0].carriable_id


func test_the_roster_sleeps_until_the_first_lift_wakes_it_well_clear_and_a_re_lift_wakes_nothing_more() -> void:
	for run_seed in [1, 7, 42]:
		var run: Run = _boot(run_seed)
		assert_eq(String(run.arena.sim._encounter_state[run.guard_id]), "dormant", "seed %d: asleep on arrival" % run_seed)
		for actor_id: int in run.arena.sim._encounter_roster[run.guard_id]:
			assert_true(run.arena.sim.debug_is_combat_absent(actor_id), "seed %d: not present before the lift" % run_seed)
		var actors_before: int = run.arena.sim.entities.size()
		assert_true(_fetch(run), "seed %d: the key was reached and lifted" % run_seed)
		assert_eq(String(run.arena.sim._encounter_state[run.guard_id]), "active", "seed %d: the lift woke it" % run_seed)
		# ACTIVATION SAFETY: at the moment of waking, every Fang stands inside its territory and
		# far beyond its arrival reach of the Envoy, who is in the vault.
		var reach: float = preload("res://tools/spawn_reaches.gd").for_keys([&"fang"])[&"fang"]
		for actor_id: int in _fangs(run):
			assert_false(run.arena.sim.debug_is_combat_absent(actor_id), "present once woken")
			var p: Vector3 = run.arena.sim.entities[actor_id]
			assert_true(WalkableBounds.contains(run.territory, p.x, p.z), "inside its territory")
			assert_gt(Vector2(p.x - _at(run).x, p.z - _at(run).z).length(), reach, "seed %d: woken beyond its arrival reach (%.1f)" % [run_seed, reach])
		# Drop the key and lift it again: the lift watcher is spent, nothing more arrives.
		_click(run, Vector3(1, 0, 0))
		assert_eq(run.arena.sim.carried_by(_id(run)), -1, "sanity: set down")
		var lying: Vector3 = run.arena.sim._carriables[run.plan.carriables[0].carriable_id]["position"]
		_walk_to(run, lying + Vector3(1.5, 0, 0), 0.3)
		_click(run, lying - _at(run))
		assert_eq(run.arena.sim.carried_by(_id(run)), run.plan.carriables[0].carriable_id, "sanity: lifted again")
		assert_eq(run.arena.sim.entities.size(), actors_before, "seed %d: no actor added by either lift" % run_seed)
		assert_eq(run.arena.sim._encounter_roster[run.guard_id].size(), 2, "the same two Fangs")
		# While the Envoy lingers in the vault, far beyond any leash, the Fangs stay home.
		_idle(run, 300)
		assert_eq(run.furthest_out, 0.0, "seed %d: no Fang left home while the Envoy was in the vault" % run_seed)
		assert_eq(run.trespass, [], "seed %d" % run_seed)


## APPROACH SAFETY, both ways home, the Fangs ALIVE throughout: the Envoy walks in carrying the key
## and does not fight. A bite drops the key; it is lifted again where it lies; the door takes it.
## The door is never denied by the roster, and no Fang ever leaves its territory.
func test_the_door_is_reached_and_opened_with_the_fangs_alive_by_either_route() -> void:
	for run_seed in [1, 7, 42]:
		for by_crossing: bool in [true, false]:
			var run: Run = _boot(run_seed)
			assert_true(_fetch(run), "seed %d: lifted" % run_seed)
			var label: String = "seed %d %s" % [run_seed, "by the crossing" if by_crossing else "the long way"]
			var avoid: Array = [] if by_crossing else [run.hazard]
			var receiver: Rect2 = _receiver(run.plan)
			var health: float = run.arena.sim.health_of(_id(run))
			var entered: Callable = func() -> bool: return WalkableBounds.contains(run.landmark, _at(run).x, _at(run).z)
			assert_true(_follow(run, _route(run, receiver, avoid), entered), "%s: to the landmark" % label)
			var nearest: float = INF
			for actor_id: int in _fangs(run):
				var p: Vector3 = run.arena.sim.entities[actor_id]
				nearest = minf(nearest, Vector2(p.x - _at(run).x, p.z - _at(run).z).length())
			var drops: int = 0
			var key_id: int = run.plan.carriables[0].carriable_id
			for attempt in DROP_BUDGET:
				if run.arena.sim.carried_by(_id(run)) == -1:
					drops += 1
					var lying: Vector3 = run.arena.sim._carriables[key_id]["position"]
					var off: Vector3 = (_at(run) - lying)
					off.y = 0.0
					_walk_to(run, lying + (off.normalized() if off.length() > 0.1 else Vector3(1, 0, 0)) * 1.2, 0.3)
					_click(run, lying - _at(run))
					continue
				_follow(run, _route(run, receiver, avoid), func() -> bool: return run.arena.sim.carried_by(_id(run)) == -1)
				if run.arena.sim.carried_by(_id(run)) == -1:
					continue
				_walk_to(run, Vector3(receiver.get_center().x, 0, receiver.get_center().y), 0.2)
				_click(run, Vector3(0, 0, -2))
				if bool(run.arena.sim._carriables[key_id]["inserted"]):
					break
			assert_true(bool(run.arena.sim._carriables[key_id]["inserted"]), "%s: the key went into the door within %d tries" % [label, DROP_BUDGET])
			assert_eq(_fangs(run).size(), 2, "%s: with both Fangs still alive -- no combat-clear was needed" % label)
			assert_lte(run.furthest_out, _leash(), "%s: every Fang within its leash of home on every tick" % label)
			assert_eq(run.trespass, [], "%s: no Fang ever on the spike crossing or in the vault" % label)
			gut.p("%s: nearest Fang on entering the landmark %.1f; furthest a Fang strayed from home %.1f; drops %d; damage taken %.0f"
				% [label, nearest, run.furthest_out, drops, health - run.arena.sim.health_of(_id(run))])


## SET THE KEY DOWN AND FIGHT: carried to the mouth of the return hall (outside the Fangs'
## territory), set down, the roster dealt with (removed through the sim -- tactical combat itself
## is not what this test proves), then the key lifted again where it lay and delivered.
func test_setting_the_key_down_outside_the_territory_and_fighting_then_delivering_works() -> void:
	for run_seed in [1, 7, 42]:
		var run: Run = _boot(run_seed)
		assert_true(_fetch(run), "seed %d: lifted" % run_seed)
		var outside: Callable = func() -> bool: return Vector2(_at(run).x, _at(run).z).distance_to(Vector2(run.landmark.get_center().x, run.landmark.get_center().y)) < run.landmark.size.x * 0.5 + 6.0
		_follow(run, _route(run, _receiver(run.plan), []), outside)
		_click(run, Vector3(0, 0, -1))
		var key_id: int = run.plan.carriables[0].carriable_id
		assert_eq(run.arena.sim.carried_by(_id(run)), -1, "seed %d: set down" % run_seed)
		var lying: Vector3 = run.arena.sim._carriables[key_id]["position"]
		assert_false(WalkableBounds.contains(run.territory, lying.x, lying.z), "seed %d: the key lies outside the Fangs' territory" % run_seed)
		for actor_id: int in _fangs(run):
			run.arena.sim.debug_override_health(actor_id, 0.0)
		_idle(run, 3)
		_walk_to(run, lying + Vector3(1.2, 0, 0), 0.3)
		_click(run, lying - _at(run))
		assert_eq(run.arena.sim.carried_by(_id(run)), key_id, "seed %d: lifted again where it lay" % run_seed)
		_follow(run, _route(run, _receiver(run.plan), []))
		_walk_to(run, Vector3(_receiver(run.plan).get_center().x, 0, _receiver(run.plan).get_center().y), 0.2)
		_click(run, Vector3(0, 0, -2))
		assert_true(bool(run.arena.sim._carriables[key_id]["inserted"]), "seed %d: delivered" % run_seed)
