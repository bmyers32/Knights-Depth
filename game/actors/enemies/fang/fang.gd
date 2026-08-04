extends Node3D
## Minimal Fang presentation: mirrors sim position, AI decisions live entirely in
## SimWorld (Phase D step 8 Phase 4) — this script only renders what the sim already
## decided. Never mutates sim state (Prime Directive 1). TargetBody (a StaticBody3D
## on the dedicated "aimable_targets" physics layer) exists purely so the Envoy's
## mouse-aim raycast can find this enemy — it carries no gameplay collision response
## of its own.

var actor_id: int = 1

@onready var _aim_anchor: Node3D = $AimAnchor
@onready var _telegraph: TelegraphIndicator = $TelegraphIndicator


func sync_from_sim(sim_position: Vector3) -> void:
	position = sim_position


## GAME-RULES §3 telegraph law — see TelegraphIndicator for the minimum-viable
## (no shader polish) rendering itself; this is just the actor-scoped entry point
## the arena driver calls on an "attack_telegraph" Event.
func show_telegraph(color: Color, duration_seconds: float) -> void:
	_telegraph.flash(color, duration_seconds)


## A stable point to aim toward (roughly body-center height) — independent of exactly
## where on the model's silhouette the cursor's raycast landed. First-pass placement,
## eyeballed against the model's measured bounding box; revisit visually at the arena
## step (§5 M1) once there's real lighting/camera framing to judge it against.
func get_aim_anchor_position() -> Vector3:
	return _aim_anchor.global_position
