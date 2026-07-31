extends CharacterBody3D
## Real Envoy presentation: builds Commands from input, renders sim state. Never mutates
## gameplay state directly — the scene driver owns the one shared SimWorld and ticks it.

var actor_id: int = 0
var stats: EnvoyStats


func _ready() -> void:
	stats = ContentDB.get_resource(&"envoy", &"default")


func build_command(tick: int) -> Command:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	return Command.new(tick, actor_id, "move", {"direction": direction})


func sync_from_sim(sim_position: Vector3) -> void:
	# Presentation-only: mirrors sim state onto the transform, never writes sim state
	# (Prime Directive 1).
	position = sim_position
