extends CharacterBody3D


var sim := ToySimWorld.new()

func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	var command := {
		"tick": sim.tick_count,
		"actor_id": 0,
		"kind": "move",
		"params": {"direction": direction},
	}
	sim.tick([command], delta)
	position = sim.position
