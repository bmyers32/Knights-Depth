extends GutTest
## THE FOLD, PLAYED THROUGH THE REAL ARENA (ADR-001 S3b). The validator's claims are about a model;
## these tests hold the SHIPPED path to them: a composed fold handed to an Arena exactly as the debug
## playground does, the Envoy WALKED along measured routes by move Commands, the key lifted and
## delivered by the attack press, the fight's roster killed through the sim. What is asserted is the
## sim's own state and Events -- which door opened, which key was spent, where the Envoy stood.
##
## Also here, because they are about the same door: the lock is drawn ON the gate it opens, on the
## side the player stands, and a mirrored key door is just as valid as the authored one.

const FOLD_PATH := "res://game/content/floors/recipes/proto_archive_fold.tres"
const CROSSING := "res://game/content/floors/pieces/archive_landmark_crossing.tres"
const DT := 1.0 / 30.0
const DEPTH: int = 1
const RouteMetrics := preload("res://tools/route_metrics.gd")


func _envoy_stats() -> EnvoyStats:
	return ContentDB.get_resource(&"envoy", &"default")


func _radii(recipe: FloorRecipe) -> Dictionary:
	var radii: Dictionary = {}
	for key: StringName in recipe.stratum.enemy_keys:
		radii[key] = ContentDB.get_resource(&"enemy", key).combat_radius
	return radii


class Floor:
	extends RefCounted
	var recipe: FloorRecipe
	var composed: FloorComposer.ComposeResult
	var plan: FloorPlan
	var arena: Node3D
	var landmark: StringName
	var vault: StringName
	var pit: StringName


func _boot(run_seed: int) -> Floor:
	var fold := Floor.new()
	fold.recipe = load(FOLD_PATH)
	fold.composed = FloorComposer.compose(fold.recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, _radii(fold.recipe))
	assert_true(fold.composed.report.succeeded(), fold.composed.report.summary())
	var plan := FloorPlan.new()
	plan.run_seed = run_seed
	plan.depth = DEPTH
	plan.floor_seed = SeedMix.derive(run_seed, DEPTH)
	plan.stratum_id = fold.composed.layout.stratum_id
	plan.authored_layout = false
	LayoutCompiler.compile(fold.composed.layout, plan)
	plan.validate(_radii(fold.recipe))
	fold.plan = plan
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.run_seed = run_seed
	arena.itinerary = [DEPTH] as Array[int]
	arena.standalone = true
	arena.prepared_first_plan = plan
	add_child_autofree(arena)
	# Survivability keeps a TRAVERSAL test measuring traversal. Never a balance claim.
	arena.sim.debug_override_health(arena.envoy.actor_id, 100000.0)
	fold.arena = arena
	fold.landmark = RouteMetrics.instance_of_node(fold.recipe, fold.composed, &"landmark")
	fold.vault = RouteMetrics.instance_of_node(fold.recipe, fold.composed, &"objective")
	fold.pit = RouteMetrics.instance_of_node(fold.recipe, fold.composed, &"encounter")
	return fold


func _envoy_at(fold: Floor) -> Vector3:
	return fold.arena.sim.entities[fold.arena.envoy.actor_id]


func _walk_to(fold: Floor, target: Vector3, reach: float, max_ticks: int = 600) -> bool:
	for i in max_ticks:
		var offset: Vector3 = target - _envoy_at(fold)
		offset.y = 0.0
		if offset.length() < reach:
			return true
		fold.arena._step([Command.new(fold.arena.sim.tick_count, fold.arena.envoy.actor_id, "move", {"direction": offset.normalized()})] as Array[Command], DT)
	return false


## Walks the measured shortest route, under the doors as the sim has them NOW, into `target` --
## finishing on its centre, since the route ends on the region's first grid point, which may lie on
## its very edge (a key is the exception: standing on it, it cannot be aimed at).
func _walk_into(fold: Floor, target: Rect2, label: String, to_centre: bool = true) -> bool:
	var open: Dictionary = {}
	for connection_id: int in fold.arena.sim._connection_open:
		if bool(fold.arena.sim._connection_open[connection_id]):
			open[connection_id] = true
	var at: Vector3 = _envoy_at(fold)
	var route: Dictionary = RouteMetrics.walk(fold.plan, open, Vector2(at.x, at.z), target, _envoy_stats().combat_radius)
	if float(route["length"]) < 0.0:
		fail_test("%s: no route under the sim's doors" % label)
		return false
	var path: Array = route["path"]
	for index: int in range(1, path.size(), 2):
		if not _walk_to(fold, Vector3(path[index].x, 0.0, path[index].y), 0.6):
			fail_test("%s: stuck short of %s" % [label, path[index]])
			return false
	var last: Vector2 = path[path.size() - 1]
	if not _walk_to(fold, Vector3(last.x, 0.0, last.y), 0.4):
		return false
	if to_centre:
		return _walk_to(fold, Vector3(target.get_center().x, 0.0, target.get_center().y), 0.2)
	return true


## One primary-attack click, the shipped way, through the driver. The Arena consumes its Events
## itself, so what a press DID is read from the sim's state afterwards.
func _click(fold: Floor, aim: Vector3) -> void:
	var id: int = fold.arena.envoy.actor_id
	fold.arena._step([Command.new(fold.arena.sim.tick_count, id, "attack", {"aim": aim, "phase": "pressed"})] as Array[Command], DT)
	fold.arena._step([Command.new(fold.arena.sim.tick_count, id, "attack", {"aim": aim, "phase": "released"})] as Array[Command], DT)


func _idle(fold: Floor, ticks: int) -> void:
	for i in ticks:
		fold.arena._step([] as Array[Command], DT)


func _carried(fold: Floor) -> int:
	return fold.arena.sim.carried_by(fold.arena.envoy.actor_id)


func _trigger_with(plan: FloorPlan, effect_kind: StringName) -> FloorTrigger:
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") == effect_kind:
				return trigger
	return null


func _receiver(plan: FloorPlan) -> FloorTrigger:
	for trigger: FloorTrigger in plan.triggers:
		if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
			return trigger
	return null


func _open_set(fold: Floor) -> Array:
	var out: Array = []
	for connection_id: int in fold.arena.sim._connection_open:
		if bool(fold.arena.sim._connection_open[connection_id]):
			out.append(connection_id)
	out.sort()
	return out


## Arrival to the plate; the fight; the vault; the key; home by the return; into the door.
func _fight_and_fetch(fold: Floor) -> void:
	var plate: FloorTrigger = _trigger_with(fold.plan, FloorLayers.EFFECT_ACTIVATE_ENCOUNTER)
	assert_true(_walk_into(fold, plate.region, "to the plate"), "to the plate")
	_idle(fold, 2)  # occupancy is read at the start of a tick: the plate fires on the next one
	var fight: int = fold.composed.emit.global_id(fold.pit, &"encounter", 0)
	assert_eq(String(fold.arena.sim._encounter_state[fight]), "active", "the plate woke the fight")
	for actor_id: int in fold.arena.sim._encounter_roster[fight]:
		fold.arena.sim.debug_override_health(actor_id, 0.0)
	_idle(fold, 3)
	assert_eq(String(fold.arena.sim._encounter_state[fight]), "cleared")
	var key: Vector3 = fold.plan.carriables[0].position
	var reach: float = _envoy_stats().pickup_reach
	assert_true(_walk_into(fold, Rect2(key.x - 1.5, key.z - 1.5, 3.0, 3.0), "to the key", false), "to the key")
	assert_true(_walk_to(fold, key, reach * 0.8), "within reach of the key")
	_click(fold, key - _envoy_at(fold))
	assert_eq(_carried(fold), fold.plan.carriables[0].carriable_id, "the press lifted the key")
	assert_true(bool(fold.arena.sim._connection_open[RouteMetrics.connection_of(fold.composed, fold.vault, &"back")]), "lifting it opened the vault's back door")


## THE WHOLE FLOOR, PLAYED: the one key, from the vault, through the return, spent once at the
## landmark's door, which -- and only which -- opens; then the exit completes the fold.
func test_the_fold_is_played_through_the_real_arena_from_arrival_to_completion() -> void:
	for run_seed in [1, 7, 42]:
		var fold: Floor = _boot(run_seed)
		_fight_and_fetch(fold)
		var receiver: FloorTrigger = _receiver(fold.plan)
		assert_true(_walk_into(fold, receiver.region, "home to the door"), "seed %d: home to the door by the return" % run_seed)
		var door: int = RouteMetrics.connection_of(fold.composed, fold.landmark, &"out")
		assert_false(bool(fold.arena.sim._connection_open[door]), "sanity: the key door is still shut")
		var before: Array = _open_set(fold)
		var key_id: int = fold.plan.carriables[0].carriable_id
		_click(fold, Vector3(0, 0, -2))
		assert_true(fold.arena.sim._triggers_fired.has(receiver.trigger_id), "seed %d: the door took the key" % run_seed)
		assert_eq(_carried(fold), -1, "the hands are empty")
		assert_true(bool(fold.arena.sim._carriables[key_id]["inserted"]), "the key is spent")
		var opened: Array = _open_set(fold).filter(func(id: int) -> bool: return not id in before)
		assert_eq(opened, [door], "seed %d: the landmark's key door opened, and nothing else" % run_seed)
		_click(fold, Vector3(0, 0, -2))
		assert_eq(_open_set(fold).filter(func(id: int) -> bool: return not id in before), [door], "a second press changes no door")
		assert_eq(_carried(fold), -1, "and lifts nothing: the spent key is gone from play")
		var pad: FloorTrigger = _trigger_with(fold.plan, FloorLayers.EFFECT_COMPLETE_FLOOR)
		# Stepping onto the pad ends the expedition and the Arena freezes its world, so the walk
		# may stop short of the pad's centre: completion, not arrival, is what is asserted.
		_walk_into(fold, pad.region, "to the exit")
		_idle(fold, 3)
		assert_true(bool(fold.arena.sim.debug_describe_floor()["floor_complete"]), "seed %d: the sim completed the floor" % run_seed)


## THE LOCK IS USED FROM THE APPROACH SIDE: standing in the receiver, the Envoy is inside the
## landmark, the shut door stops it walking on, and the press there delivers. The lock is drawn on
## that door, on that side, and goes with the door when it opens.
func test_the_key_door_is_used_from_its_approach_side_and_draws_its_lock_on_the_gate() -> void:
	var fold: Floor = _boot(7)
	_fight_and_fetch(fold)
	var receiver: FloorTrigger = _receiver(fold.plan)
	assert_true(_walk_into(fold, receiver.region, "home to the door"), "home to the door")
	var landmark_footprint: Rect2 = FloorDraft.world_footprint(fold.composed.draft.instance_of(fold.landmark))
	var door: int = RouteMetrics.connection_of(fold.composed, fold.landmark, &"out")
	var barrier: Dictionary = fold.arena.sim.gate_barrier(door)
	assert_eq(barrier["axis"], &"x", "the key door is in a side wall: its barrier is a line of constant x")
	var line_x: float = float(barrier["at"])
	var inside: float = signf(landmark_footprint.get_center().x - line_x)
	# Try to walk straight on through the shut door.
	for i in 60:
		fold.arena._step([Command.new(fold.arena.sim.tick_count, fold.arena.envoy.actor_id, "move", {"direction": Vector3(-inside, 0, 0)})] as Array[Command], DT)
	assert_gt((_envoy_at(fold).x - line_x) * inside, 0.0, "the shut door held the Envoy on the landmark's side")
	assert_true(WalkableBounds.contains(receiver.region, _envoy_at(fold).x, _envoy_at(fold).z), "and it still stands in the receiver")
	var builder: FloorBuilder = fold.arena._floor_builder
	assert_eq(builder.receiver_gate(receiver.trigger_id), door, "the lock belongs to the key door")
	var lock: MeshInstance3D = builder.receiver_mesh(receiver.trigger_id)
	assert_true(lock.visible)
	assert_lt(absf(lock.position.x - line_x), 1.0, "the lock is ON the door's line")
	assert_gt((lock.position.x - line_x) * inside, 0.0, "on the side the player stands")
	assert_gt(lock.position.y, 0.5, "raised on the door, not a socket on the floor")
	_click(fold, Vector3(0, 0, -2))
	assert_true(bool(fold.arena.sim._connection_open[door]))
	assert_false(lock.visible, "the lock went with the door")


## B6, IN THE REAL SIM: the key set down on the return path (the carrier's press away from any
## receiver drops it there), lifted again, and delivered. Recoverable, and still spent only once.
func test_a_key_set_down_on_the_return_is_lifted_again_and_delivered() -> void:
	var fold: Floor = _boot(42)
	_fight_and_fetch(fold)
	var receiver: FloorTrigger = _receiver(fold.plan)
	var key_id: int = fold.plan.carriables[0].carriable_id
	# Out of the vault's back door and part-way up the return, then the press.
	var vault_back: TraversalConnection = null
	for connection: TraversalConnection in fold.plan.connections:
		if connection.connection_id == RouteMetrics.connection_of(fold.composed, fold.vault, &"back"):
			vault_back = connection
	var beyond: Rect2 = vault_back.aperture.grow(-1.0)
	beyond.position.y += 8.0
	assert_true(_walk_into(fold, beyond, "onto the return"), "onto the return hall")
	_click(fold, Vector3(0, 0, 2))
	assert_eq(_carried(fold), -1, "the press set the key down")
	assert_false(bool(fold.arena.sim._carriables[key_id]["inserted"]), "on the floor, not spent")
	var lying: Vector3 = fold.arena.sim._carriables[key_id]["position"]
	assert_true(_walk_to(fold, lying + Vector3(0, 0, 1.5), 0.3), "step off it")
	_click(fold, lying - _envoy_at(fold))
	assert_eq(_carried(fold), key_id, "lifted again where it lay")
	assert_true(_walk_into(fold, receiver.region, "home to the door"))
	_click(fold, Vector3(0, 0, -2))
	assert_true(bool(fold.arena.sim._carriables[key_id]["inserted"]), "spent at the door")
	assert_true(bool(fold.arena.sim._connection_open[RouteMetrics.connection_of(fold.composed, fold.landmark, &"out")]))


# --- a mirrored key door ----------------------------------------------------------------------

## The crossing placed MIRRORED by hand (composition never needs to), an entry above it and an exit
## landing at the end of its key door's hall: the door is now in the east wall, its receiver still on
## the threshold inside, the press from inside still delivers, and the lock is drawn on that door's
## inner face.
func test_a_mirrored_key_door_keeps_its_threshold_receiver_and_its_lock() -> void:
	var piece: FloorPiece = load(CROSSING)
	var draft := FloorDraft.new()
	draft.draft_id = &"mirrored_key_door"
	draft.stratum_id = &"archive"
	var entry: StringName = draft.place(load("res://game/content/floors/pieces/archive_entry_hall.tres"), Vector2(0, 24))
	var instance_id: StringName = draft.place(piece, Vector2.ZERO, FloorPiece.TRANSFORM_MIRROR_X)
	var landing: StringName = draft.place(load("res://game/content/floors/pieces/archive_exit_landing.tres"), Vector2(34, -3))
	var span: Dictionary = FloorDraft.port_span(draft.instance_of(instance_id), piece.port(&"out"))
	assert_eq(FloorDraft.world_edge(draft.instance_of(instance_id), &"west"), &"east", "mirroring moved the key door to the east wall")
	var approach: StringName = draft.lay([Rect2(-3, 2, 6, 8)] as Array[Rect2], &"stone", &"ledge")
	draft.bind(entry, &"out", approach, 1.5, &"ledge", 0)
	draft.bind(instance_id, &"in", approach, 1.5, &"ledge", 0)
	var hall: StringName = draft.lay([Rect2(float(span["at"]) + 2.0, float(span["from"]), 12.0, float(span["to"]) - float(span["from"]))] as Array[Rect2], &"stone", &"ledge")
	draft.bind(instance_id, &"out", hall, 1.5, &"ledge", 0)
	draft.bind(landing, &"side", hall, 1.5, &"ledge", 0)
	var emitted: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_true(emitted.is_ok(), emitted.summary())
	var plan := FloorPlan.new()
	plan.stratum_id = &"archive"
	LayoutCompiler.compile(emitted.layout, plan)
	var receiver: FloorTrigger = _receiver(plan)
	var door: TraversalConnection = null
	for connection: TraversalConnection in plan.connections:
		if not connection.starts_open:
			door = connection
	assert_not_null(door, "the key door starts shut")
	if door == null:
		return
	assert_true(is_equal_approx(receiver.region.end.x, float(span["at"])), "the receiver stands on the east door's threshold")
	assert_true(FloorDraft.world_footprint(draft.instance_of(instance_id)).encloses(receiver.region), "inside the crossing")
	assert_eq(FloorBuilder.lock_gate_of(receiver, plan), door.connection_id, "and it is that door's lock")
	# The press from inside delivers and opens exactly that door.
	var sim := SimWorld.new()
	var envoy: EnvoyStats = _envoy_stats()
	var stand := Vector3(receiver.region.get_center().x, 0.0, receiver.region.get_center().y)
	sim.add_entity(0, stand, envoy.move_speed, Vector3(1, 0, 0), envoy.combat_radius)
	sim.register_combatant(0, envoy.max_health, envoy.family, envoy.iframe_ticks_on_hit, envoy.combat_radius, &"player")
	sim.register_carrier(0, envoy.pickup_reach, envoy.pickup_cone_half_angle_degrees, envoy.pickup_underfoot_radius)
	sim.mark_run_persistent(0)
	sim.load_floor(plan.make_bounds(), stand)
	sim.register_patches(plan.patch_rects())
	sim.register_connection(door.connection_id, door.aperture, door.starts_open)
	sim.register_trigger(receiver.trigger_id, receiver.kind, receiver.region, receiver.source_id, receiver.once, receiver.effects, receiver.starts_enabled)
	sim.register_carriable(7, stand + Vector3(-1.0, 0.0, 0.0))
	sim._lift_carriable(0, 7)
	assert_eq(sim.interaction_focus(0, Vector3(1, 0, 0)), {"kind": "insert", "trigger_id": receiver.trigger_id, "carriable_id": 7})
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, 0, "attack", {"aim": Vector3(1, 0, 0), "phase": "pressed"})] as Array[Command], DT)
	assert_eq(events.filter(func(event: Event) -> bool: return event.kind == "carriable_inserted").size(), 1)
	assert_true(bool(sim._connection_open[door.connection_id]), "the mirrored door opened")
	# And the lock is drawn on its inner (west) face.
	var builder := FloorBuilder.new()
	add_child_autofree(builder)
	builder.build(plan, 100, {door.connection_id: sim.gate_barrier(door.connection_id)})
	assert_eq(builder.receiver_gate(receiver.trigger_id), door.connection_id)
	var line_x: float = float(sim.gate_barrier(door.connection_id)["at"])
	assert_lt(builder.receiver_mesh(receiver.trigger_id).position.x, line_x, "the lock is on the barrier's crossing-facing side")
	assert_lt(absf(builder.receiver_mesh(receiver.trigger_id).position.x - line_x), 1.0, "on the door's line")
