class_name FloorBuilder
extends Node3D
## Presentation for one generated floor: builds the visible room from a FloorPlan's walkable
## rects and instantiates that floor's actor scenes from the same plan's spawn records.
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

## enemy_key -> scene, mirroring ContentDB's explicit-registry style rather than guessing a
## path from the key. Presentation is test-exempt by law, which is why the method surface
## here is pinned by tests/test_presentation_contracts.gd.
const ENEMY_SCENES: Dictionary = {
	&"fang": preload("res://game/actors/enemies/fang/fang.tscn"),
	&"ooze": preload("res://game/actors/enemies/ooze/ooze.tscn"),
	&"watcher": preload("res://game/actors/enemies/watcher/watcher.tscn"),
}

const _FLOOR_THICKNESS: float = 0.2
const _WALL_HEIGHT: float = 2.0
const _WALL_THICKNESS: float = 0.5
const _FLOOR_COLOR: Color = Color(0.22, 0.23, 0.27)
const _WALL_COLOR: Color = Color(0.38, 0.36, 0.44)


## Clears the previous floor and builds this one. Returns one record per spawned actor:
## {"actor_id": int, "enemy_key": StringName, "node": Node3D, "position": Vector3}.
## The DRIVER registers those with the sim through the ordinary ContentRegistrar path --
## this builder never touches SimWorld.
func build(plan: FloorPlan, first_actor_id: int) -> Array[Dictionary]:
	clear_floor()
	for rect in plan.walkable_rects:
		_build_room(rect)
	var spawned: Array[Dictionary] = []
	var next_actor_id: int = first_actor_id
	for spawn in plan.spawns:
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
			"node": node,
			"position": spawn["position"],
		})
		next_actor_id += 1
	return spawned


## Removed from the tree IMMEDIATELY, not just queue_free()d: a floor transition rebuilds
## within the same frame, and a queued-but-still-parented actor would be visible alongside
## the new roster for a frame and would still answer get_children().
func clear_floor() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _build_room(rect: Rect2) -> void:
	var centre := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
	_add_box(
		Vector3(rect.size.x, _FLOOR_THICKNESS, rect.size.y),
		centre + Vector3(0.0, -_FLOOR_THICKNESS * 0.5, 0.0),
		_FLOOR_COLOR,
	)
	# Walls sit OUTSIDE the boundary with their inner faces exactly on it, so what the
	# player sees as the wall face is the same line SimWorld clamps against.
	var half_wall: float = _WALL_THICKNESS * 0.5
	var span_x: float = rect.size.x + _WALL_THICKNESS * 2.0
	var wall_y: float = _WALL_HEIGHT * 0.5
	_add_box(Vector3(span_x, _WALL_HEIGHT, _WALL_THICKNESS), Vector3(centre.x, wall_y, rect.position.y - half_wall), _WALL_COLOR)
	_add_box(Vector3(span_x, _WALL_HEIGHT, _WALL_THICKNESS), Vector3(centre.x, wall_y, rect.end.y + half_wall), _WALL_COLOR)
	_add_box(Vector3(_WALL_THICKNESS, _WALL_HEIGHT, rect.size.y), Vector3(rect.position.x - half_wall, wall_y, centre.z), _WALL_COLOR)
	_add_box(Vector3(_WALL_THICKNESS, _WALL_HEIGHT, rect.size.y), Vector3(rect.end.x + half_wall, wall_y, centre.z), _WALL_COLOR)


func _add_box(size: Vector3, centre: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = centre
	add_child(instance)
