class_name SimWorld
extends RefCounted
## The one mutation path for gameplay state (Prime Directive 1). Zero Node imports —
## GAME-RULES SS1.1's CI proof is a script ticking this 1000x with no display server.
## Entities register their tunables via add_entity — Commands are requests, never
## authoritative tunables (GAME-RULES SS4.2's client/server boundary, built offline-first
## so M3 doesn't have to retrofit it); Command.params carries only per-tick intent.

var entities: Dictionary = {}  # actor_id -> Vector3 position
var _move_speeds: Dictionary = {}  # actor_id -> float
var tick_count: int = 0


func add_entity(actor_id: int, position: Vector3, move_speed: float) -> void:
	entities[actor_id] = position
	_move_speeds[actor_id] = move_speed


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
	var speed: float = _move_speeds.get(command.actor_id, 0.0)
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	position += direction * speed * dt
	entities[command.actor_id] = position
	return Event.new(tick_count, "moved", {"actor_id": command.actor_id, "position": position})
