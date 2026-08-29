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
@onready var _telegraph: TelegraphIndicator = $TelegraphIndicator


func _ready() -> void:
	stats = ContentDB.get_resource(&"envoy", &"default")


## Slice B charge-ready cue (manual-pass) -- a pure Event LISTENER, never a poll: the
## arena driver calls these only in direct response to charge_ready/melee_swing/
## melee_hold_canceled Events. This actor never reads charge_ticks, thresholds, or
## hold state from the sim -- presentation renders only what Events tell it. This is
## the precedent for every future persistent indicator (charge bars, status auras,
## combo counters): land it as a listener, never a poll.
func show_charge_ready(color: Color) -> void:
	_telegraph.set_active(color, true)


func clear_charge_ready() -> void:
	_telegraph.set_active(Color.WHITE, false)


func build_commands(tick: int) -> Array[Command]:
	var commands: Array[Command] = []
	# Attack is built and appended BEFORE move (manual-pass fix, post-implementation
	# review catch): a "released" that transitions a hold straight into "executing"
	# does so while THIS Command is processed -- SimWorld's move-suppression check
	# only sees the transition if attack has already run this tick. With move
	# first (the original order), the tick's own movement would apply BEFORE the
	# transition, then the swing's first lunge step would ALSO apply via the
	# synchronous catch-up call -- one tick blending free input with authored
	# movement, contradicting "authored movement replaces input, never a blend."
	# The sim resolves whichever weapon is currently equipped (SimWorld.
	# set_equipped_weapon) — presentation sends only per-action intent (phase + aim),
	# never a weapon_id or a tap/charge decision (Slice B, GAME-RULES §3: that
	# decision is sim-owned, content-driven by whether the equipped weapon has a
	# charge profile registered — see SimWorld._apply_attack). Zero-vector aim (no
	# camera in the viewport, or the ray never crosses the ground plane) falls back
	# to stored facing — see SimWorld._normalize_horizontal. A combo/charge weapon gets
	# "held" every tick the button stays down and "released" on the falling edge.
	#
	# BOTH EDGES ARE FORWARDED (locked fix, step-4 recon): this runs once per PHYSICS
	# tick (arena.gd._physics_process, 30 Hz), and in a physics context both
	# is_action_just_pressed and is_action_just_released report true when a click
	# opened AND closed since the previous tick -- i.e. any click shorter than ~33 ms,
	# which fast clicks and gaming mice produce routinely. The former if/elif chain
	# forwarded only "pressed" and DISCARDED the release, which stranded
	# SimWorld._melee_hold in "charging" forever: the next tick has no edges and no
	# held state, so nothing ever closed it, and every later press hit
	# _begin_melee_hold's already-charging silent no-op branch -- the Envoy's attack
	# stayed dead until a weapon switch, a block rising edge, or death cleared it.
	# Sending both phases in order resolves such a click as one clean tap, which is
	# also what the player asked for.
	var just_pressed: bool = Input.is_action_just_pressed("attack")
	var just_released: bool = Input.is_action_just_released("attack")
	if just_pressed:
		commands.append(Command.new(tick, actor_id, "attack", {"aim": _compute_mouse_aim(), "phase": "pressed"}))
	if just_released:
		commands.append(Command.new(tick, actor_id, "attack", {"aim": _compute_mouse_aim(), "phase": "released"}))
	elif not just_pressed and Input.is_action_pressed("attack"):
		# "held" only on ticks carrying no edge at all -- a press tick already declared
		# intent, and charge accumulation starts from the tick after it.
		commands.append(Command.new(tick, actor_id, "attack", {"aim": _compute_mouse_aim(), "phase": "held"}))
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	commands.append(Command.new(tick, actor_id, "move", {"direction": direction}))
	# held sent every tick, unconditionally — mirrors "move": each tick fully declares
	# intent so the sim's rising-edge detection (SimWorld._apply_block) never depends
	# on a missed edge-triggered press.
	commands.append(Command.new(tick, actor_id, "block", {"held": Input.is_action_pressed("block")}))

	# NO INTERACT VERB (2026-08-29). Every floor control is now something you STAND ON, so the
	# `interact` Command was retired with its last consumer rather than kept warm for a future
	# one (§1.4 rule of two, run backwards). It returns out of git when a press is earned.

	if Input.is_action_just_pressed("switch_weapon"):
		# No weapon_id in params — this only ever advances the sim-owned loadout
		# array (SimWorld.set_weapon_loadout), it never names a weapon (Prime
		# Directive 1 boundary-rule comment at sim_world.gd's dispatch site).
		commands.append(Command.new(tick, actor_id, "switch_weapon"))
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


## Arrival on a newly loaded floor (M2). Identical in kind to the enemies' burrow-emergence
## teleport and for the same reason: physics_interpolation=true means the renderer would
## otherwise smoothly draw the trip from the old floor's position to the new entry point,
## and the Envoy would appear to fly across the room on arrival.
func teleport_from_sim(sim_position: Vector3) -> void:
	position = sim_position
	reset_physics_interpolation()
