extends Node3D
## Minimal Ooze presentation: mirrors sim position, no AI/behavior yet (Phase D step 7
## scope — Ooze exists only to prove the content pipeline + damage matrix + Burn
## contact-spread against a real target). Never mutates sim state (Prime Directive 1).
## TargetBody (a StaticBody3D on the dedicated "aimable_targets" physics layer) exists
## purely so the Envoy's mouse-aim raycast can find this enemy — it carries no
## gameplay collision response of its own. Structural mirror of fang.gd.

var actor_id: int = 2

@onready var _aim_anchor: Node3D = $AimAnchor


func sync_from_sim(sim_position: Vector3) -> void:
	position = sim_position


## A stable point to aim toward (roughly body-center height) — independent of exactly
## where on the model's silhouette the cursor's raycast landed. First-pass placement,
## eyeballed against the model's measured bounding box; revisit visually at the arena
## step (§5 M1) once there's real lighting/camera framing to judge it against.
func get_aim_anchor_position() -> Vector3:
	return _aim_anchor.global_position
