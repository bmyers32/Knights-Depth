class_name ToySimWorld
extends RefCounted
## Warmup 2 (M0): miniature of the SimWorld.tick(commands, dt) -> Array[Event] contract
## from CLAUDE.md Core Interfaces. No Node/scene-tree imports — sim is headless by law
## (GAME-RULES SS1.1). MOVE_SPEED is a bare const, not a content resource: single
## warmup-scoped occurrence, not scattered (GAME-RULES SS1.2) — real tunables move to
## content/ once ContentDB exists in M1.

const MOVE_SPEED: float = 4.0

var position: Vector3 = Vector3.ZERO
var tick_count: int = 0


func tick(commands: Array, dt: float) -> Array:
	var events: Array = []
	for command in commands:
		if command.get("kind") == "move":
			var direction: Vector3 = command.get("params", {}).get("direction", Vector3.ZERO)
			if direction.length_squared() > 0.0:
				direction = direction.normalized()
			position += direction * MOVE_SPEED * dt
			events.append({
				"tick": tick_count,
				"kind": "moved",
				"payload": {"position": position},
			})
	tick_count += 1
	return events
