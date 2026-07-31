class_name SimWorld
extends RefCounted
## The one mutation path for gameplay state (Prime Directive 1). Zero Node imports —
## GAME-RULES SS1.1's CI proof is a script ticking this 1000x with no display server.
## Move speed travels in Command.params, never a sim-side const (Prime Directive 3);
## real Envoy tuning becomes a content-resource lookup once ContentDB exists (M1 step 2).

var entities: Dictionary = {}  # actor_id -> Vector3 position
var tick_count: int = 0


func tick(commands: Array[Command], dt: float) -> Array[Event]:
	var events: Array[Event] = []
	for command in commands:
		if command.kind == "move":
			events.append(_apply_move(command, dt))
	tick_count += 1
	return events


func _apply_move(command: Command, dt: float) -> Event:
	var position: Vector3 = entities.get(command.actor_id, Vector3.ZERO)
	var direction: Vector3 = command.params.get("direction", Vector3.ZERO)
	var speed: float = command.params.get("speed", 0.0)
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	position += direction * speed * dt
	entities[command.actor_id] = position
	return Event.new(tick_count, "moved", {"actor_id": command.actor_id, "position": position})
