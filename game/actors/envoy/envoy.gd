extends CharacterBody3D
## Real Envoy presentation: builds Commands from input, renders sim state. Never mutates
## gameplay state directly — the scene driver owns the one shared SimWorld and ticks it.

## Dedicated physics layer (project.godot [layer_names]) that ONLY aimable enemies sit
## on, so this raycast never entangles with terrain/projectile-blocking geometry added
## at the arena step (§5 M1).
const AIMABLE_TARGET_LAYER_MASK: int = 1 << 1  # layer 2
const AIM_RAYCAST_DISTANCE: float = 100.0

var actor_id: int = 0
var stats: EnvoyStats


func _ready() -> void:
	stats = ContentDB.get_resource(&"envoy", &"default")


func build_commands(tick: int) -> Array[Command]:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	var commands: Array[Command] = [Command.new(tick, actor_id, "move", {"direction": direction})]
	if Input.is_action_just_pressed("attack"):
		# The sim resolves whichever weapon is currently equipped (SimWorld.
		# set_equipped_weapon) — presentation sends only per-action intent (aim),
		# never a weapon_id. Zero-vector aim (no camera in the viewport, or the ray
		# never crosses the ground plane) falls back to stored facing —
		# see SimWorld._normalize_horizontal.
		commands.append(Command.new(tick, actor_id, "attack", {"aim": _compute_mouse_aim()}))
	# held sent every tick, unconditionally — mirrors "move": each tick fully declares
	# intent so the sim's rising-edge detection (SimWorld._apply_block) never depends
	# on a missed edge-triggered press.
	commands.append(Command.new(tick, actor_id, "block", {"held": Input.is_action_pressed("block")}))
	return commands


## Mouse-to-world aim, two-stage (manual playtest finding: a ground-plane-only ray
## misses anything above ground level — clicking Fang's upper body clicked past it,
## onto the floor beyond, since the ray from a raised screen point crosses the ground
## plane well past the actual target). Stage 1: raycast the dedicated aimable-target
## physics layer; a hit resolves toward THAT target's own aim anchor, a stable point
## independent of exactly where on its silhouette the cursor landed. Stage 2 (nothing
## under the cursor): fall back to the original ground-plane intersection, unchanged.
## Either stage only shapes a DIRECTION vector — no target id crosses the Command
## boundary; the sim alone decides what actually gets hit (Prime Directive 1).
func _compute_mouse_aim() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)

	var target_point = _raycast_aimable_target(ray_origin, ray_direction)
	if target_point == null:
		var ground_plane := Plane(Vector3.UP, position.y)
		target_point = ground_plane.intersects_ray(ray_origin, ray_direction)
	if target_point == null:
		return Vector3.ZERO
	return target_point - position


## Godot has no built-in "aim at cursor, preferring a target" — this is the raycast
## half of the two-stage recipe above:
## https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html
func _raycast_aimable_target(ray_origin: Vector3, ray_direction: Vector3):
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * AIM_RAYCAST_DISTANCE)
	query.collision_mask = AIMABLE_TARGET_LAYER_MASK
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return null
	var aim_owner: Node = _find_aim_anchor_owner(result.get("collider"))
	if aim_owner != null:
		return aim_owner.get_aim_anchor_position()
	return result.get("position")


## The collider itself is often a bare physics node with no gameplay script (e.g.
## Fang's TargetBody) — the real aim-anchor owner is usually that collider's parent
## (the actor's root node, per fang.gd). Checked collider-first too, so a future
## enemy could still implement the method directly on its own collider if that ever
## makes more sense.
func _find_aim_anchor_owner(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("get_aim_anchor_position"):
		return node
	var parent: Node = node.get_parent()
	if parent != null and parent.has_method("get_aim_anchor_position"):
		return parent
	return null


func sync_from_sim(sim_position: Vector3) -> void:
	# Presentation-only: mirrors sim state onto the transform, never writes sim state
	# (Prime Directive 1).
	position = sim_position
