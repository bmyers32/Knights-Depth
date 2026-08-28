class_name FloorBuilder
extends Node3D
## Presentation for one generated floor: builds the visible rooms, corridors, gates and
## terminal marker from a FloorPlan, and instantiates that floor's actor scenes from the same
## plan's room-local spawn records.
##
## READS the plan, never authors one. There is deliberately no second roster or collision
## layout anywhere in arena.tscn — the plan is the single description of a floor, and two
## descriptions that can silently disagree is the failure AGENTS.md Truth Homes exists to
## prevent.
##
## The geometry here is VISUAL ONLY. Walkable legality is SimWorld's (game/sim/
## walkable_bounds.gd, GAME-RULES §4.6): giving these meshes collision bodies would create a
## second authority over where an actor may stand, which is the exact inversion Prime
## Directive 1 forbids. Nothing in the project needs them to collide — the Envoy's mouse aim
## raycasts the "aimable_targets" layer and falls back to a mathematical ground Plane, never
## to floor geometry.
##
## A GATE IS A PICTURE OF A RULE, NOT THE RULE. `set_gate_closed` only shows or hides a
## barrier mesh; the mechanical seal is per-actor room confinement in the sim
## (SimWorld._legal_bounds_for). If this node were deleted entirely, a locked encounter would
## still be inescapable — it would just be invisible.

## enemy_key -> scene, mirroring ContentDB's explicit-registry style rather than guessing a
## path from the key. Presentation is test-exempt by law, which is why the method surface here
## is pinned by tests/test_presentation_contracts.gd.
const ENEMY_SCENES: Dictionary = {
	&"fang": preload("res://game/actors/enemies/fang/fang.tscn"),
	&"ooze": preload("res://game/actors/enemies/ooze/ooze.tscn"),
	&"watcher": preload("res://game/actors/enemies/watcher/watcher.tscn"),
}

const _FLOOR_THICKNESS: float = 0.2
const _WALL_HEIGHT: float = 2.0
const _WALL_THICKNESS: float = 0.5
const _GATE_HEIGHT: float = 2.4
## Room kinds get distinct floor tints so "which kind of space am I in" is legible without a
## minimap. Connective space reads darker; the combat room reads as the place that matters.
const _KIND_COLORS: Dictionary = {
	&"entry": Color(0.20, 0.24, 0.30),
	&"traversal": Color(0.18, 0.19, 0.23),
	&"combat": Color(0.26, 0.22, 0.24),
}
const _CORRIDOR_COLOR: Color = Color(0.16, 0.17, 0.20)
const _WALL_COLOR: Color = Color(0.38, 0.36, 0.44)
const _GATE_OPEN_COLOR: Color = Color(0.35, 0.55, 0.45)
const _GATE_CLOSED_COLOR: Color = Color(0.75, 0.30, 0.28)
const _MARKER_COLOR: Color = Color(0.85, 0.78, 0.42)

## connection_id -> the barrier mesh, so a gate can be shown/hidden on an Event.
var _gates: Dictionary = {}


## Clears the previous floor and builds this one. Returns one record per spawned actor:
## {"actor_id": int, "enemy_key": StringName, "room_id": int, "node": Node3D, "position": Vector3}.
## The DRIVER registers those with the sim through the ordinary ContentRegistrar path — this
## builder never touches SimWorld.
func build(plan: FloorPlan, first_actor_id: int) -> Array[Dictionary]:
	clear_floor()
	for room in plan.rooms:
		_build_room(room, _gap_at(plan, room.room_id, true), _gap_at(plan, room.room_id, false))
	for connection in plan.connections:
		_build_connection(connection)
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
			"actor_id": next_actor_id,
			"enemy_key": enemy_key,
			"room_id": spawn["room_id"],
			"node": node,
			"position": spawn["position"],
		})
		next_actor_id += 1
	return spawned


## Removed from the tree IMMEDIATELY, not just queue_free()d: a floor transition rebuilds
## within the same frame, and a queued-but-still-parented actor would be visible alongside the
## new roster for a frame and would still answer get_children().
func clear_floor() -> void:
	_gates.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()


## Mirrors the sim's authoritative encounter state. Presentation never decides that a gate is
## shut — it is told.
func set_gate_closed(connection_id: int, closed: bool) -> void:
	if not _gates.has(connection_id):
		return
	var gate: MeshInstance3D = _gates[connection_id]
	gate.visible = closed
	gate.material_override.albedo_color = _GATE_CLOSED_COLOR if closed else _GATE_OPEN_COLOR


## Aperture width at one end of a room, read from the PLAN rather than assumed. A number that
## appears in two places is a defect (§1.2): the opening's width is authored once in
## StratumConfig and reaches here only through the connection that used it. A room with no
## connection on that side gets 0.0 and is walled solid, which is what makes the chain's two
## dead ends read as dead ends.
func _gap_at(plan: FloorPlan, room_id: int, at_min_z: bool) -> float:
	for connection in plan.connections:
		# The connection stores (near, far) = (+Z room, -Z room), so a room is opened at its
		# -Z edge when it is the NEAR side, and at its +Z edge when it is the FAR side.
		if at_min_z and connection.room_ids.x == room_id:
			return connection.aperture.size.x
		if not at_min_z and connection.room_ids.y == room_id:
			return connection.aperture.size.x
	return 0.0


func _build_room(room: RoomPlan, gap_at_min_z: float, gap_at_max_z: float) -> void:
	var rect: Rect2 = room.rect
	var centre := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
	_add_box(
		Vector3(rect.size.x, _FLOOR_THICKNESS, rect.size.y),
		centre + Vector3(0.0, -_FLOOR_THICKNESS * 0.5, 0.0),
		_KIND_COLORS.get(room.kind, _CORRIDOR_COLOR),
	)
	# The side walls run the room's full depth. The +Z/-Z walls are deliberately NOT built
	# here: an aperture punches through them, and a wall with a hole in it is two walls. They
	# are built by _build_connection, which knows where the hole is.
	var half_wall: float = _WALL_THICKNESS * 0.5
	var wall_y: float = _WALL_HEIGHT * 0.5
	_add_box(Vector3(_WALL_THICKNESS, _WALL_HEIGHT, rect.size.y), Vector3(rect.position.x - half_wall, wall_y, centre.z), _WALL_COLOR)
	_add_box(Vector3(_WALL_THICKNESS, _WALL_HEIGHT, rect.size.y), Vector3(rect.end.x + half_wall, wall_y, centre.z), _WALL_COLOR)
	_end_wall(rect, rect.position.y, gap_at_min_z)
	_end_wall(rect, rect.end.y, gap_at_max_z)


## One end wall, split symmetrically around a centred opening. gap = 0.0 walls it solid.
func _end_wall(rect: Rect2, z: float, gap: float) -> void:
	var wall_y: float = _WALL_HEIGHT * 0.5
	var side: float = (rect.size.x - gap) * 0.5
	if side <= 0.0:
		return
	var left_centre: float = rect.position.x + side * 0.5
	var right_centre: float = rect.end.x - side * 0.5
	_add_box(Vector3(side, _WALL_HEIGHT, _WALL_THICKNESS), Vector3(left_centre, wall_y, z), _WALL_COLOR)
	_add_box(Vector3(side, _WALL_HEIGHT, _WALL_THICKNESS), Vector3(right_centre, wall_y, z), _WALL_COLOR)


func _build_connection(connection: ConnectionPlan) -> void:
	var rect: Rect2 = connection.aperture
	var centre := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
	_add_box(
		Vector3(rect.size.x, _FLOOR_THICKNESS, rect.size.y),
		centre + Vector3(0.0, -_FLOOR_THICKNESS * 0.5, 0.0),
		_CORRIDOR_COLOR,
	)
	# Corridor side walls, spanning only the gap between the two rooms.
	var half_wall: float = _WALL_THICKNESS * 0.5
	var wall_y: float = _WALL_HEIGHT * 0.5
	_add_box(Vector3(_WALL_THICKNESS, _WALL_HEIGHT, rect.size.y), Vector3(rect.position.x - half_wall, wall_y, centre.z), _WALL_COLOR)
	_add_box(Vector3(_WALL_THICKNESS, _WALL_HEIGHT, rect.size.y), Vector3(rect.end.x + half_wall, wall_y, centre.z), _WALL_COLOR)

	if not connection.gated:
		return
	# The barrier sits at the corridor's midpoint, which is OUTSIDE both room rects. That is
	# the honest place for it: the sealed region is the room, and everything past the
	# threshold is what becomes unreachable.
	var gate := _add_box(
		Vector3(rect.size.x, _GATE_HEIGHT, _WALL_THICKNESS),
		Vector3(centre.x, _GATE_HEIGHT * 0.5, centre.z),
		_GATE_OPEN_COLOR,
	)
	gate.visible = false
	_gates[connection.connection_id] = gate


## The terminal marker (ruled): a deterministic visual endpoint whose only job is to make the
## test grammar visible — ENTRY -> TRAVERSAL -> COMBAT -> CLEAR -> TRAVERSAL -> FLOOR END.
## Not an elevator, no transition logic, no run-end UI. Reaching it proves that progression
## continued after the locked encounter.
func _build_end_marker(position: Vector3) -> void:
	var pillar := _add_box(Vector3(1.6, 3.0, 1.6), position + Vector3(0.0, 1.5, 0.0), _MARKER_COLOR)
	pillar.material_override.emission_enabled = true
	pillar.material_override.emission = _MARKER_COLOR
	pillar.material_override.emission_energy_multiplier = 0.6


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
