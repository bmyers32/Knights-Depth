extends GutTest
## THE SPIKE-RETURN FOLD, PLAYED THROUGH THE REAL ARENA (G3 content iteration, 2026-10-27).
## Seeds 1, 7 and 42 of the EXPERIMENTAL recipe, each played twice from the moment the key is
## lifted: home by the spike crossing (waiting on safe ground for each band to drop, then crossing),
## and home the long way through the cleared arena (walking round the crossing's ground). Both are
## timed in sim ticks, waiting included -- the measure of whether the shortcut is one.

const SPIKES := "res://game/content/floors/recipes/proto_archive_fold_spikes.tres"
const DT := 1.0 / 30.0
const DEPTH: int = 1
const REACT: int = 10
const RouteMetrics := preload("res://tools/route_metrics.gd")


func _envoy() -> EnvoyStats:
	return ContentDB.get_resource(&"envoy", &"default")


class Run:
	extends RefCounted
	var recipe: FloorRecipe
	var composed: FloorComposer.ComposeResult
	var plan: FloorPlan
	var arena: Node3D


func _boot(run_seed: int) -> Run:
	var run := Run.new()
	run.recipe = load(SPIKES)
	var radii: Dictionary = {}
	for key: StringName in run.recipe.stratum.enemy_keys:
		radii[key] = ContentDB.get_resource(&"enemy", key).combat_radius
	run.composed = FloorComposer.compose(run.recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, radii)
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
	# Survivability keeps a TRAVERSAL test measuring traversal; any health lost is still visible.
	arena.sim.debug_override_health(arena.envoy.actor_id, 100000.0)
	run.arena = arena
	return run


func _at(run: Run) -> Vector3:
	return run.arena.sim.entities[run.arena.envoy.actor_id]


func _step(run: Run, direction: Vector3) -> void:
	run.arena._step([Command.new(run.arena.sim.tick_count, run.arena.envoy.actor_id, "move", {"direction": direction})] as Array[Command], DT)


func _idle(run: Run, ticks: int) -> void:
	for i in ticks:
		run.arena._step([] as Array[Command], DT)


func _walk_to(run: Run, target: Vector3, reach: float, max_ticks: int = 600) -> bool:
	for i in max_ticks:
		var offset: Vector3 = target - _at(run)
		offset.y = 0.0
		if offset.length() < reach:
			return true
		_step(run, offset.normalized())
	return false


func _pad_containing(run: Run, point: Vector2) -> int:
	for pad: SpikePadPlan in run.plan.spike_pads:
		if WalkableBounds.contains(pad.rect, point.x, point.y):
			return pad.pad_id
	return -1


## Before stepping onto a band from safe ground: wait for it to DROP, then REACT ticks.
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


## Before stepping onto a band from safe ground: wait until it shows NO warning, re-checked after
## REACT ticks -- the bolder reading of the same picture.
func _wait_for_calm(run: Run, pad_id: int) -> void:
	var lead: int = FloorBuilder._HAZARD_WARN_LEAD_TICKS
	for i in 400:
		if run.arena.sim.spike_pad_ticks_until_active(pad_id) > lead:
			_idle(run, REACT)
			if run.arena.sim.spike_pad_ticks_until_active(pad_id) > lead:
				return
		_idle(run, 1)
	fail_test("band %d never looked calm" % pad_id)


## Walks the measured route into `target` under the sim's doors, never through `avoid`, and -- when
## the route steps onto a band from ground that is not that band -- waits on the band's cue
## (`cue`: _wait_for_retraction, the cautious reading, or _wait_for_calm, the bold one).
func _walk_into(run: Run, target: Rect2, avoid: Array, label: String, to_centre: bool = true, cue: Callable = Callable()) -> bool:
	var open: Dictionary = {}
	for connection_id: int in run.arena.sim._connection_open:
		if bool(run.arena.sim._connection_open[connection_id]):
			open[connection_id] = true
	var at: Vector3 = _at(run)
	var route: Dictionary = RouteMetrics.walk(run.plan, open, Vector2(at.x, at.z), target, _envoy().combat_radius, avoid)
	if float(route["length"]) < 0.0:
		fail_test("%s: no route" % label)
		return false
	var path: Array = route["path"]
	for index: int in range(1, path.size()):
		var point: Vector2 = path[index]
		var pad: int = _pad_containing(run, point)
		var here: Vector3 = _at(run)
		if pad >= 0 and _pad_containing(run, Vector2(here.x, here.z)) != pad:
			if cue.is_valid():
				cue.call(run, pad)
			else:
				_wait_for_retraction(run, pad)
		if not _walk_to(run, Vector3(point.x, 0.0, point.y), 0.5):
			fail_test("%s: stuck short of %s" % [label, point])
			return false
	if not to_centre:
		return true  # a key is the exception: standing on it, it cannot be aimed at
	return _walk_to(run, Vector3(target.get_center().x, 0.0, target.get_center().y), 0.2)


func _click(run: Run, aim: Vector3) -> void:
	var id: int = run.arena.envoy.actor_id
	run.arena._step([Command.new(run.arena.sim.tick_count, id, "attack", {"aim": aim, "phase": "pressed"})] as Array[Command], DT)
	run.arena._step([Command.new(run.arena.sim.tick_count, id, "attack", {"aim": aim, "phase": "released"})] as Array[Command], DT)


func _trigger_with(plan: FloorPlan, kind: StringName) -> FloorTrigger:
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") == kind:
				return trigger
	return null


func _receiver(plan: FloorPlan) -> Rect2:
	for trigger: FloorTrigger in plan.triggers:
		if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
			return trigger.region
	return Rect2()


## Arrival -> plate -> fight cleared -> key lifted. Returns the tick of the lift.
func _fetch(run: Run) -> int:
	var plate: FloorTrigger = _trigger_with(run.plan, FloorLayers.EFFECT_ACTIVATE_ENCOUNTER)
	assert_true(_walk_into(run, plate.region, [], "to the plate"))
	_idle(run, 2)
	var pit: StringName = RouteMetrics.instance_of_node(run.recipe, run.composed, &"encounter")
	var fight: int = run.composed.emit.global_id(pit, &"encounter", 0)
	for actor_id: int in run.arena.sim._encounter_roster[fight]:
		run.arena.sim.debug_override_health(actor_id, 0.0)
	_idle(run, 3)
	assert_eq(String(run.arena.sim._encounter_state[fight]), "cleared")
	var key: Vector3 = run.plan.carriables[0].position
	assert_true(_walk_into(run, Rect2(key.x - 1.5, key.z - 1.5, 3.0, 3.0), [], "to the key", false))
	_walk_to(run, key, _envoy().pickup_reach * 0.8)
	_click(run, key - _at(run))
	assert_eq(run.arena.sim.carried_by(run.arena.envoy.actor_id), run.plan.carriables[0].carriable_id, "lifted")
	return run.arena.sim.tick_count


## Home by one route, then the key into the landmark's door and on to the exit. Returns the ticks
## from the lift to the delivery.
func _home(run: Run, avoid: Array, label: String, cue: Callable = Callable()) -> int:
	var lifted: int = _fetch(run)
	var health: float = run.arena.sim.health_of(run.arena.envoy.actor_id)
	assert_true(_walk_into(run, _receiver(run.plan), avoid, label, true, cue), label)
	_click(run, Vector3(0, 0, -2))
	var delivered: int = run.arena.sim.tick_count
	var key_id: int = run.plan.carriables[0].carriable_id
	assert_true(bool(run.arena.sim._carriables[key_id]["inserted"]), "%s: the key is in the door" % label)
	assert_eq(run.arena.sim.health_of(run.arena.envoy.actor_id), health, "%s: no damage on the way home" % label)
	_walk_into(run, _trigger_with(run.plan, FloorLayers.EFFECT_COMPLETE_FLOOR).region, [], "to the exit")
	_idle(run, 3)
	assert_true(bool(run.arena.sim.debug_describe_floor()["floor_complete"]), "%s: the floor completes" % label)
	return delivered - lifted


func test_both_ways_home_are_played_to_completion_and_timed() -> void:
	for run_seed in [1, 7, 42]:
		var short_run: Run = _boot(run_seed)
		var by_crossing: int = _home(short_run, [], "seed %d by the crossing" % run_seed)
		var bold_run: Run = _boot(run_seed)
		var boldly: int = _home(bold_run, [], "seed %d by the crossing, going when calm" % run_seed, _wait_for_calm)
		var long_run: Run = _boot(run_seed)
		var hazard: Rect2 = FloorDraft.world_footprint(long_run.composed.draft.instance_of(RouteMetrics.instance_of_node(long_run.recipe, long_run.composed, &"hazard")))
		var the_long_way: int = _home(long_run, [hazard], "seed %d the long way" % run_seed)
		gut.p("seed %d lift -> delivery: crossing (wait till it drops) %.1f s, crossing (go when calm) %.1f s, long way %.1f s" % [run_seed, by_crossing / 30.0, boldly / 30.0, the_long_way / 30.0])
		assert_gt(the_long_way, 0)
		assert_gt(by_crossing, 0)
