extends CharacterBody3D
## Real Envoy presentation: builds Commands from input, renders sim state. Never mutates
## gameplay state directly — the scene driver owns the one shared SimWorld and ticks it.

var actor_id: int = 0
var stats: EnvoyStats


func _ready() -> void:
	stats = ContentDB.get_resource(&"envoy", &"default")


func build_commands(tick: int) -> Array[Command]:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	var commands: Array[Command] = [Command.new(tick, actor_id, "move", {"direction": direction})]
	if Input.is_action_just_pressed("attack"):
		# aim = ZERO: no dedicated aim input yet, so the sim falls back to facing
		# (last move direction) — see SimWorld._normalize_horizontal.
		commands.append(Command.new(tick, actor_id, "attack", {"weapon_id": &"sword_A", "aim": Vector3.ZERO}))
	# held sent every tick, unconditionally — mirrors "move": each tick fully declares
	# intent so the sim's rising-edge detection (SimWorld._apply_block) never depends
	# on a missed edge-triggered press.
	commands.append(Command.new(tick, actor_id, "block", {"held": Input.is_action_pressed("block")}))
	return commands


func sync_from_sim(sim_position: Vector3) -> void:
	# Presentation-only: mirrors sim state onto the transform, never writes sim state
	# (Prime Directive 1).
	position = sim_position
