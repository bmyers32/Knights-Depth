extends Node3D
## Minimal Ooze presentation: mirrors sim position, AI decisions live entirely in
## SimWorld (Phase D step 8 Phase 4) — this script only renders what the sim already
## decided. Never mutates sim state (Prime Directive 1). TargetBody (a StaticBody3D
## on the dedicated "aimable_targets" physics layer) exists purely so the Envoy's
## mouse-aim raycast can find this enemy — it carries no gameplay collision response
## of its own. Structural mirror of fang.gd.

var actor_id: int = 2

@onready var _aim_anchor: Node3D = $AimAnchor
@onready var _telegraph: TelegraphIndicator = $TelegraphIndicator


func sync_from_sim(sim_position: Vector3) -> void:
	position = sim_position


## GAME-RULES §3 telegraph law — see TelegraphIndicator for the minimum-viable
## (no shader polish) rendering itself; this is just the actor-scoped entry point
## the arena driver calls on an "attack_telegraph" Event.
func show_telegraph(color: Color, duration_seconds: float, has_vulnerable_window: bool = false) -> void:
	_telegraph.flash(color, duration_seconds, has_vulnerable_window)


## P29 item 2: the authored VULNERABLE window just opened on this actor's committed
## action. Driven by the arena from telegraph tick + action content -- this actor never
## computes combat timing itself (Prime Directive 1).
func show_vulnerable_window() -> void:
	_telegraph.mark_vulnerable()


## The committed action was cancelled; stop advertising a window that no longer exists.
func clear_telegraph() -> void:
	_telegraph.clear()


## A stable point to aim toward (roughly body-center height) — independent of exactly
## where on the model's silhouette the cursor's raycast landed. First-pass placement,
## eyeballed against the model's measured bounding box; revisit visually at the arena
## step (§5 M1) once there's real lighting/camera framing to judge it against.
func get_aim_anchor_position() -> Vector3:
	return _aim_anchor.global_position


## P17 burrow: presentation MIRRORS the sim's authoritative combat participation -- it never
## decides it. Driven only by burrow_submerged / burrow_emerged Events.
##
## Two channels, because they are genuinely separate dimensions and the audit found the second
## one has NO sim gate at all: `visible` is what the player sees, and TargetBody's collision
## layer is what the Envoy's mouse-aim raycast can acquire. An absent Fang that stayed
## aim-acquirable would let the player lock onto a target the sim says is not there.
##
## Deferred because participation flips from _report_events, which runs inside the physics step.
func set_combat_present(present: bool) -> void:
	visible = present
	$TargetBody.set_deferred("collision_layer", 2 if present else 0)


## TELEPORT, not move. Snaps the transform AND cancels the render-side interpolation Godot would
## otherwise draw across the gap.
##
## WHY IT EXISTS (Stage-1 playtest defect, 2026-08-25): the burrow emergence read as the Fang
## "quickly flying from off-screen to the emergence point". The sim teleported correctly in a
## single tick -- the transform never occupied an intermediate position -- but the project runs
## physics_interpolation=true at 30 Hz, and to the renderer a one-tick position jump is
## indistinguishable from very fast travel, so it smoothly drew the trip.
##
## Note the class of bug: it is invisible to every test that samples the scene tree, because the
## artifact exists only between physics ticks. Automation can prove the transform snapped and the
## node stayed hidden; only a human eye could see the interpolation.
func teleport_from_sim(sim_position: Vector3) -> void:
	position = sim_position
	reset_physics_interpolation()
