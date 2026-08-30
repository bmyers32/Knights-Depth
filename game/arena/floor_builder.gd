class_name FloorBuilder
extends Node3D
## Presentation for one generated floor: builds the visible ground, walls, gates, props and
## endpoint from a FloorPlan, and instantiates that floor's actor scenes from the same plan.
##
## READS the plan, never authors one. There is deliberately no second roster or collision
## layout anywhere in arena.tscn — two descriptions of one floor that can silently disagree is
## the failure AGENTS.md Truth Homes exists to prevent.
##
## GEOMETRY HERE IS VISUAL ONLY. Walkable legality is SimWorld's (game/sim/walkable_bounds.gd,
## GAME-RULES §4.6): giving these meshes collision bodies would create a second authority over
## where an actor may stand, the exact inversion Prime Directive 1 forbids. Nothing needs them
## to collide — the Envoy's mouse aim raycasts the "aimable_targets" layer and falls back to a
## mathematical ground Plane, never to floor geometry.
##
## A GATE IS A PICTURE OF A RULE, NOT THE RULE. `set_gate_closed` shows or hides a barrier; the
## seal itself is the sim removing that aperture from the walkable union. Delete this node and
## a blocked route stays blocked — it would just be invisible.
##
## ELEVATION IS ALSO ONLY A PICTURE. Combat stays on one plane, so the sim never sees height;
## this raises the mesh and `elevation_at()` lets the driver lift an actor's transform to match.

const ENEMY_SCENES: Dictionary = {
	&"fang": preload("res://game/actors/enemies/fang/fang.tscn"),
	&"ooze": preload("res://game/actors/enemies/ooze/ooze.tscn"),
	&"watcher": preload("res://game/actors/enemies/watcher/watcher.tscn"),
}

const _FLOOR_THICKNESS: float = 0.2
const _WALL_HEIGHT: float = 2.2
const _WALL_THICKNESS: float = 0.6
const _GATE_HEIGHT: float = 2.6

const _SURFACE_COLORS: Dictionary = {
	&"stone": Color(0.19, 0.20, 0.24),
	&"arena": Color(0.26, 0.22, 0.24),
	&"ramp": Color(0.24, 0.25, 0.21),
	&"high": Color(0.22, 0.26, 0.30),
}
const _CORRIDOR_COLOR: Color = Color(0.15, 0.16, 0.19)
const _WALL_COLOR: Color = Color(0.36, 0.35, 0.42)
const _GATE_CLOSED_COLOR: Color = Color(0.78, 0.28, 0.26)
const _MARKER_COLOR: Color = Color(0.88, 0.80, 0.42)
const _BREAKABLE_COLOR: Color = Color(0.52, 0.40, 0.24)
## A COMMITMENT plate (the party's, the exit's): bold, warm, unmistakable.
const _PLATE_COLOR: Color = Color(0.92, 0.62, 0.24)
## A LOCAL control you discovered: cooler, dimmer, thinner. Same mechanism, quieter voice.
const _PLATE_MINOR_COLOR: Color = Color(0.40, 0.66, 0.78)
const _PLATE_THICKNESS: float = 0.12
const _PLATE_MINOR_THICKNESS: float = 0.06

var _gates: Dictionary = {}          # connection_id -> barrier mesh
var _plates: Dictionary = {}         # trigger_id -> plate mesh
var _breakables: Dictionary = {}     # breakable_id -> mesh
## rect -> elevation, so an actor's transform can be lifted onto raised ground.
var _elevation_rects: Array = []


## Clears the previous floor and builds this one. Returns one record per spawned actor:
## {"actor_id", "enemy_key", "encounter_id", "node", "position"}. The DRIVER registers those
## with the sim through the ordinary ContentRegistrar path — this builder never touches SimWorld.
func build(plan: FloorPlan, first_actor_id: int) -> Array[Dictionary]:
	clear_floor()
	for patch in plan.patches:
		_build_patch(patch)
		_elevation_rects.append({"rect": patch.rect, "elevation": patch.elevation})
	for connection in plan.connections:
		_build_connection(connection, plan)
	for breakable in plan.breakables:
		_build_breakable(breakable)
	# A PLATE IS A PICTURE OF A TRIGGER, exactly as a gate is a picture of a rule: the sim fires
	# on occupancy whether or not this mesh exists. It is drawn from the trigger itself so the
	# thing you stand on and the thing that fires can never be authored in two places. A DORMANT
	# plate is built and hidden, never spawned later -- presentation must not be able to
	# disagree with the sim about whether a control exists.
	for trigger in plan.triggers:
		if trigger.renders_as_plate:
			# PROMINENCE FOLLOWS THE AUTHORED KIND, and reads it rather than being told twice:
			# a group-occupancy plate is a commitment the whole expedition makes, so it is loud;
			# anything else is a local control, so it is quiet. No new data, no new mechanic.
			var commitment: bool = trigger.kind == FloorLayers.TRIGGER_GROUP_OCCUPANCY
			_build_plate(trigger.trigger_id, trigger.region, trigger.starts_enabled, commitment)
	_build_end_marker(plan.end_marker)

	var spawned: Array[Dictionary] = []
	var next_actor_id: int = first_actor_id
	for spawn in plan.all_spawns():
		var enemy_key: StringName = spawn["enemy_key"]
		if not ENEMY_SCENES.has(enemy_key):
			push_error("FloorBuilder: no scene registered for enemy_key '%s'" % enemy_key)
			continue
		var node: Node3D = ENEMY_SCENES[enemy_key].instantiate()
		node.actor_id = next_actor_id
		node.position = spawn["position"]
		add_child(node)
		spawned.append({
			"actor_id": next_actor_id, "enemy_key": enemy_key,
			"encounter_id": spawn["encounter_id"], "node": node, "position": spawn["position"],
		})
		next_actor_id += 1
	return spawned


## Removed from the tree IMMEDIATELY, not merely queue_free()d: a floor rebuild happens within
## one frame, and a queued-but-still-parented actor would be drawn alongside the new roster and
## would still answer get_children().
func clear_floor() -> void:
	_gates.clear()
	_plates.clear()
	_breakables.clear()
	_elevation_rects.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()


## Visual ground height under a world position, for lifting an actor onto raised patches.
## Returns the HIGHEST matching patch so a ramp overlapping high ground reads as continuous.
func elevation_at(position: Vector3) -> float:
	var best: float = 0.0
	for entry in _elevation_rects:
		var rect: Rect2 = entry["rect"]
		if position.x >= rect.position.x and position.x <= rect.end.x \
				and position.z >= rect.position.y and position.z <= rect.end.y:
			best = max(best, float(entry["elevation"]))
	return best


## Mirrors the sim's authoritative connection state. Presentation never decides a route is shut.
func set_gate_closed(connection_id: int, closed: bool) -> void:
	if _gates.has(connection_id):
		_gates[connection_id].visible = closed


func set_plate_visible(trigger_id: int, shown: bool) -> void:
	if _plates.has(trigger_id):
		_plates[trigger_id].visible = shown


func remove_breakable(breakable_id: int) -> void:
	if not _breakables.has(breakable_id):
		return
	var mesh: Node3D = _breakables[breakable_id]
	_breakables.erase(breakable_id)
	remove_child(mesh)
	mesh.queue_free()


# --- geometry --------------------------------------------------------------------------

## Ground plus a perimeter wall on every edge NOT shared with another patch or an aperture.
## Computed rather than authored: an irregular silhouette made of overlapping patches has no
## fixed notion of which side is "outside", and hand-listing walls per patch would drift from
## the geometry the sim actually clamps against the moment a patch moved.
func _build_patch(patch: WalkablePatch) -> void:
	var rect: Rect2 = patch.rect
	var lift := Vector3(0.0, patch.elevation, 0.0)
	var centre := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5) + lift
	_add_box(
		Vector3(rect.size.x, _FLOOR_THICKNESS, rect.size.y),
		centre + Vector3(0.0, -_FLOOR_THICKNESS * 0.5, 0.0),
		_SURFACE_COLORS.get(patch.surface, _CORRIDOR_COLOR),
	)


## Walls are built LAST, from the union, so they trace the floor's real silhouette. Each patch
## edge is sampled in short spans; a span with no other walkable ground beyond it gets a wall.
## Sampling rather than exact rectangle subtraction on purpose: the union is small, the result
## is identical at this resolution, and the alternative is a clipping library for scenery.
## NOT EVERY WALKABILITY EDGE IS A WALL (human finding, 2026-08-29). A `ledge` patch renders no
## vertical boundary at all: you can see over the drop, and the sim still refuses to let anyone
## off it, because legality was never these meshes' job in the first place. This is a rendering
## distinction only -- there is no second movement-legality system here, and adding one would be
## the exact inversion Prime Directive 1 forbids.
func build_walls(plan: FloorPlan) -> void:
	var rects: Array[Rect2] = plan.all_rects()
	for patch in plan.patches:
		if patch.boundary_style == &"ledge":
			continue
		_walls_for(patch.rect, patch.elevation, rects)
	for connection in plan.connections:
		_walls_for(connection.aperture, 0.0, rects)


func _walls_for(rect: Rect2, elevation: float, all_rects: Array[Rect2]) -> void:
	var step: float = 1.0
	var y: float = elevation + _WALL_HEIGHT * 0.5
	var x: float = rect.position.x
	while x < rect.end.x - 0.001:
		var span: float = minf(step, rect.end.x - x)
		var mid_x: float = x + span * 0.5
		if not _is_walkable(all_rects, Vector2(mid_x, rect.position.y - 0.5)):
			_add_box(Vector3(span, _WALL_HEIGHT, _WALL_THICKNESS), Vector3(mid_x, y, rect.position.y - _WALL_THICKNESS * 0.5), _WALL_COLOR)
		if not _is_walkable(all_rects, Vector2(mid_x, rect.end.y + 0.5)):
			_add_box(Vector3(span, _WALL_HEIGHT, _WALL_THICKNESS), Vector3(mid_x, y, rect.end.y + _WALL_THICKNESS * 0.5), _WALL_COLOR)
		x += span
	var z: float = rect.position.y
	while z < rect.end.y - 0.001:
		var span: float = minf(step, rect.end.y - z)
		var mid_z: float = z + span * 0.5
		if not _is_walkable(all_rects, Vector2(rect.position.x - 0.5, mid_z)):
			_add_box(Vector3(_WALL_THICKNESS, _WALL_HEIGHT, span), Vector3(rect.position.x - _WALL_THICKNESS * 0.5, y, mid_z), _WALL_COLOR)
		if not _is_walkable(all_rects, Vector2(rect.end.x + 0.5, mid_z)):
			_add_box(Vector3(_WALL_THICKNESS, _WALL_HEIGHT, span), Vector3(rect.end.x + _WALL_THICKNESS * 0.5, y, mid_z), _WALL_COLOR)
		z += span


func _is_walkable(rects: Array[Rect2], point: Vector2) -> bool:
	for rect in rects:
		if point.x >= rect.position.x and point.x <= rect.end.x \
				and point.y >= rect.position.y and point.y <= rect.end.y:
			return true
	return false


func _build_connection(connection: TraversalConnection, plan: FloorPlan) -> void:
	var rect: Rect2 = connection.aperture
	var centre := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
	# Corridors take the lower of the two patches they join, so a ramp reads as climbing INTO
	# high ground rather than as a step the player cannot see.
	var elevation: float = minf(_patch_elevation(plan, connection.patch_ids.x), _patch_elevation(plan, connection.patch_ids.y))
	_add_box(
		Vector3(rect.size.x, _FLOOR_THICKNESS, rect.size.y),
		centre + Vector3(0.0, elevation - _FLOOR_THICKNESS * 0.5, 0.0),
		_CORRIDOR_COLOR,
	)
	_elevation_rects.append({"rect": rect, "elevation": elevation})
	if not connection.has_barrier:
		return
	var gate := _add_box(
		Vector3(rect.size.x, _GATE_HEIGHT, _WALL_THICKNESS),
		Vector3(centre.x, elevation + _GATE_HEIGHT * 0.5, centre.z),
		_GATE_CLOSED_COLOR,
	)
	gate.visible = not connection.starts_open
	_gates[connection.connection_id] = gate


func _patch_elevation(plan: FloorPlan, patch_id: int) -> float:
	var patch: WalkablePatch = plan.patch_by_id(patch_id)
	return 0.0 if patch == null else patch.elevation


func _build_breakable(breakable: BreakablePlan) -> void:
	var size: float = breakable.radius * 1.6
	var mesh := _add_box(Vector3(size, size, size), breakable.position + Vector3(0.0, size * 0.5, 0.0), _BREAKABLE_COLOR)
	_breakables[breakable.breakable_id] = mesh


## The floor plate the party stands on. Flush with the ground and lit, so it reads as somewhere
## to STAND rather than something to press.
## THE MESH IS EXACTLY THE TRIGGER REGION, always. What varies is colour, thickness and glow --
## never footprint, because a plate that fires from ground outside its own picture is a lie.
func _build_plate(trigger_id: int, region: Rect2, visible_now: bool, commitment: bool) -> void:
	var centre := Vector3(region.position.x + region.size.x * 0.5, 0.0, region.position.y + region.size.y * 0.5)
	var colour: Color = _PLATE_COLOR if commitment else _PLATE_MINOR_COLOR
	var thickness: float = _PLATE_THICKNESS if commitment else _PLATE_MINOR_THICKNESS
	var plate := _add_box(
		Vector3(region.size.x, thickness, region.size.y),
		centre + Vector3(0.0, elevation_at(centre) + thickness * 0.5, 0.0),
		colour,
	)
	plate.material_override.emission_enabled = true
	plate.material_override.emission = colour
	plate.material_override.emission_energy_multiplier = 0.5 if commitment else 0.25
	plate.visible = visible_now
	_plates[trigger_id] = plate


## The terminal marker (ruled): a deterministic visual endpoint whose only job is to make the
## grammar's end visible. Not an elevator, no transition logic, no run-end UI.
func _build_end_marker(position: Vector3) -> void:
	var pillar := _add_box(Vector3(1.6, 3.2, 1.6), position + Vector3(0.0, elevation_at(position) + 1.6, 0.0), _MARKER_COLOR)
	pillar.material_override.emission_enabled = true
	pillar.material_override.emission = _MARKER_COLOR
	pillar.material_override.emission_energy_multiplier = 0.7


func _add_box(size: Vector3, centre: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = centre
	add_child(instance)
	return instance
