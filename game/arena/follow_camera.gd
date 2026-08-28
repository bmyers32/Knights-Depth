class_name FollowCamera
extends Camera3D
## ROADMAP P21, consumed by the M2 multi-room slice: a floor larger than one screen cannot be
## judged through a fixed camera.
##
## TRANSLATION ONLY. The rotation and height are exactly M1's validated framing — 45° down
## from (0, 12, 12) relative to the Envoy — so combat readability, apparent scale, and every
## telegraph/reach judgement made at the M1 gate carry over untouched. This camera changes
## WHERE you are looking, never HOW things look. Room-snapped (Zelda-style) framing was
## considered and deliberately deferred: it introduces a transition-feel design question that
## would confound the first exploration playtest.
##
## Presentation only (Prime Directive 1): reads the sim-mirrored target transform each frame
## and writes nothing.

## The validated M1 offset. Changing this re-opens every framing judgement made at the M1
## combat gate, so it is a deliberate act, not a tuning knob.
@export var offset: Vector3 = Vector3(0.0, 12.0, 12.0)

## How far INSIDE the floor's edge the camera's ground focus is kept, per axis. This is a
## deliberately CONSERVATIVE edge stop, not a computed view frustum.
##
## The failure modes are asymmetric and that decides the value. Too small a margin shows some
## void past a wall -- cosmetic. Too large a margin holds the focus so far from the Envoy that
## the Envoy leaves the frame -- fatal to a playtest. So these are set well under any plausible
## visible half-extent: at 6.0 the Envoy can be at most 6 units from the focus, comfortably
## inside frame at this fixed 45-degree framing, and the camera still stops before it drifts
## off the floor entirely.
@export var edge_margin_x: float = 6.0
@export var edge_margin_z: float = 6.0

## Interpolation rate. _process, not _physics_process: this is presentation smoothing over
## sim state, exactly what Prime Directive 2 reserves _process for. 0.0 = hard snap.
@export var follow_lerp_per_second: float = 12.0

var _target: Node3D = null
## Floor extents in XZ, from the loaded FloorPlan. Zero-size = unbounded (no clamp).
var _floor_extent: Rect2 = Rect2()


func _ready() -> void:
	# This camera does its OWN smoothing in _process, so it must opt out of Godot's physics
	# interpolation -- otherwise two smoothers fight over the same transform and the engine
	# warns "Interpolated Camera3D triggered from outside physics process" every frame.
	# Turning it off here is the correct resolution: the interpolation we want is the one
	# written above, against sim-mirrored state.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func set_target(target: Node3D) -> void:
	_target = target


## Called on every floor load with the union AABB of the floor's walkable rects.
func set_floor_extent(extent: Rect2) -> void:
	_floor_extent = extent


## Snaps to the target with no interpolation — used on floor arrival, so the camera does not
## sweep across the whole floor to catch up with a teleported Envoy.
func snap_to_target() -> void:
	if _target == null:
		return
	position = _resolve_position(_target.position)
	reset_physics_interpolation()


func _process(delta: float) -> void:
	if _target == null:
		return
	var desired: Vector3 = _resolve_position(_target.position)
	if follow_lerp_per_second <= 0.0:
		position = desired
		return
	# Frame-rate independent exponential smoothing: the fraction of the remaining distance
	# closed per second is constant, so the feel does not change with framerate.
	position = position.lerp(desired, 1.0 - exp(-follow_lerp_per_second * delta))


## Clamps the camera's ground focus so the view stops near the floor's edge instead of drifting
## into void. When the floor is NARROWER than twice the margin on an axis, the limits invert,
## so the camera centres on the floor rather than jittering between two impossible bounds --
## which is also what keeps a combat room the width of M1's arena framed exactly as M1 framed
## it, with the Envoy centred.
func _resolve_position(target_position: Vector3) -> Vector3:
	var focus := Vector2(target_position.x, target_position.z)
	if _floor_extent.size.x > 0.0 and _floor_extent.size.y > 0.0:
		var minimum := Vector2(_floor_extent.position.x + edge_margin_x, _floor_extent.position.y + edge_margin_z)
		var maximum := Vector2(_floor_extent.end.x - edge_margin_x, _floor_extent.end.y - edge_margin_z)
		focus.x = (minimum.x + maximum.x) * 0.5 if minimum.x > maximum.x else clampf(focus.x, minimum.x, maximum.x)
		focus.y = (minimum.y + maximum.y) * 0.5 if minimum.y > maximum.y else clampf(focus.y, minimum.y, maximum.y)
	return Vector3(focus.x, target_position.y, focus.y) + offset
