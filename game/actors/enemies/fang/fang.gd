extends Node3D
## Minimal Fang presentation: mirrors sim position, no AI/behavior yet (Phase D step 3
## scope — Fang exists only to prove the combat pipeline against a real target).
## Never mutates sim state (Prime Directive 1).

var actor_id: int = 1


func sync_from_sim(sim_position: Vector3) -> void:
	position = sim_position
