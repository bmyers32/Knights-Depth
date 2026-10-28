class_name CameraFraming
extends Resource
## THE EXPEDITION CAMERA AS DATA (ADR-001 O1, S4): one resource read by `FollowCamera` and handed
## to gen/, so the camera a player sees and the camera a floor is validated against cannot drift.
##
## The values are M1's validated framing, unchanged: 45 degrees down from (0, 12, 12) relative to
## the Envoy, Godot's default 75-degree vertical field of view (KEEP_HEIGHT), 6-unit edge stops.
## Changing any of them re-opens every framing judgement made at the M1 combat gate.
##
## Pure maths, no Node: the projection here is the camera's own perspective (Camera3D with
## KEEP_HEIGHT), pinned against the real node's `unproject_position` by tests/test_visibility.gd.

@export var offset: Vector3 = Vector3(0.0, 12.0, 12.0)
@export var pitch_degrees: float = -45.0
@export var fov_degrees: float = 75.0
@export var edge_margin_x: float = 6.0
@export var edge_margin_z: float = 6.0
## The reference window (project default, stretch `expand`). Reveals are judged at this aspect.
@export var viewport_size: Vector2 = Vector2(1152.0, 648.0)

## REVEAL VALIDATION (S4). Provisional per O4 -- measured, reported, not yet locked.
## A target point counts as seen only inside this inset of every screen edge (fraction of size):
## something under the HUD or clipped by the frame is not a reveal.
@export var reveal_safe_margin: float = 0.05
## A target is seen when its centre AND at least this share of its sample points are seen.
@export var reveal_min_visible_share: float = 0.6
## Half the spread of a target's sample cross (centre plus four points).
@export var reveal_sample_spread: float = 0.5
## The rendered occluders, as FloorBuilder draws them (test-pinned to its constants): solid
## segments as walls this tall and thick, closed gates this tall.
@export var occluder_wall_height: float = 2.2
@export var occluder_wall_thickness: float = 0.6
@export var occluder_gate_height: float = 2.6
## Intact breakables, as FloorBuilder draws them on arrival (test-pinned to the built meshes): an
## ordinary one is a cube this many times its radius on a side; a blocking one is its blocking
## rect this tall. A reveal that needs an urn smashed first is not a reveal.
@export var occluder_breakable_scale: float = 1.6
@export var occluder_blocker_height: float = 1.8
## Camera3D's default near plane: a point closer than this along the view is behind the camera.
@export var near: float = 0.05


## THE EDGE STOP, the one rule both the live camera and the validator use. When the floor is
## narrower than twice the margin on an axis the limits invert and the focus centres on the floor,
## which keeps an M1-sized room framed exactly as M1 framed it.
static func clamp_focus(target: Vector3, extent: Rect2, margin_x: float, margin_z: float) -> Vector3:
	var focus := Vector2(target.x, target.z)
	if extent.size.x > 0.0 and extent.size.y > 0.0:
		var minimum := Vector2(extent.position.x + margin_x, extent.position.y + margin_z)
		var maximum := Vector2(extent.end.x - margin_x, extent.end.y - margin_z)
		focus.x = (minimum.x + maximum.x) * 0.5 if minimum.x > maximum.x else clampf(focus.x, minimum.x, maximum.x)
		focus.y = (minimum.y + maximum.y) * 0.5 if minimum.y > maximum.y else clampf(focus.y, minimum.y, maximum.y)
	return Vector3(focus.x, target.y, focus.y)


func camera_position(stand: Vector3, extent: Rect2) -> Vector3:
	return clamp_focus(stand, extent, edge_margin_x, edge_margin_z) + offset


func camera_basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0))


## {behind: bool, screen: Vector2 in pixels of `viewport_size`} -- unproject_position's answer.
func project(camera: Vector3, world: Vector3) -> Dictionary:
	var local: Vector3 = camera_basis().inverse() * (world - camera)
	var depth: float = -local.z
	if depth < near:
		return {"behind": true, "screen": Vector2.ZERO}
	var focal: float = 1.0 / tan(deg_to_rad(fov_degrees) * 0.5)
	var aspect: float = viewport_size.x / viewport_size.y
	var ndc := Vector2(focal / aspect * local.x / depth, focal * local.y / depth)
	return {"behind": false, "screen": Vector2((ndc.x * 0.5 + 0.5) * viewport_size.x, (0.5 - ndc.y * 0.5) * viewport_size.y)}


func in_safe_band(screen: Vector2) -> bool:
	var inset: Vector2 = viewport_size * reveal_safe_margin
	return screen.x >= inset.x and screen.x <= viewport_size.x - inset.x and screen.y >= inset.y and screen.y <= viewport_size.y - inset.y
