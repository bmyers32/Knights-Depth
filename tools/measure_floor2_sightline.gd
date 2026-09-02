extends SceneTree
## FLOOR 2 PRE-BUILD MEASUREMENT 1 — is the Junction actually VISIBLE from the Commons edge?
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_floor2_sightline.gd
##
## The visible-before-reachable beat is part of Floor 2's design CLAIM, not decoration, so world
## distance is not evidence. This projects the destination through the ACTUAL shipped camera --
## the real FollowCamera script, its authored offset and 45-degree pitch, its edge clamp fed the
## draft floor's real extent, and the project's real viewport size -- and reports where on screen
## the point lands.
##
## Reports only. No geometry is authored from this run.

## Draft Floor 2 coordinates under review.
const COMMONS := Rect2(-26.0, -46.0, 52.0, 28.0)
## FINAL AUTHORED COORDINATES (re-measured after the layout moved during implementation --
## the junction widened to the full span and the terrace shifted west to sit beyond the
## party-sync plate, so the earlier reading could not simply be assumed to survive).
const JUNCTION := Rect2(-30.0, -71.0, 60.0, 10.0)
const TERRACE := Rect2(-28.0, -83.0, 16.0, 12.0)
## Union of every authored patch -- what set_floor_extent receives.
const FLOOR_EXTENT := Rect2(-30.0, -83.0, 74.0, 81.0)


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var viewport: Viewport = Engine.get_main_loop().root
	var size: Vector2 = viewport.get_visible_rect().size
	print("VIEWPORT %.0f x %.0f (project setting, the real render target)" % [size.x, size.y])

	var camera_script: GDScript = load("res://game/arena/follow_camera.gd")
	var camera: Camera3D = camera_script.new()
	# THE SHIPPED ORIENTATION: 45 degrees down, offset (0, 12, 12).
	#
	# Expressed as a rotation rather than by copying the .tscn's nine floats. A first attempt fed
	# those floats to Transform3D(x_axis, y_axis, z_axis, origin), which treats them as COLUMNS
	# while the scene file lists them row-wise -- building the TRANSPOSE, a camera aimed at the
	# sky. Every target then read OFF-SCREEN and would have condemned the layout. Same lesson as
	# the AI probes: an instrument must be shown to be measuring the thing it claims.
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	viewport.add_child(camera)
	camera.current = true
	camera.set_floor_extent(FLOOR_EXTENT)
	print("CAMERA offset %s   fov %.1f (vertical)   pitch %.0f deg   edge margins %.1f / %.1f" % [
		camera.offset, camera.fov, rad_to_deg(camera.rotation.x), camera.edge_margin_x, camera.edge_margin_z])
	# SANITY: the camera must be looking DOWN and FORWARD, or nothing below means anything.
	var forward: Vector3 = -camera.global_transform.basis.z
	print("CAMERA forward %s  -- must have negative y and negative z" % forward)
	if forward.y >= 0.0 or forward.z >= 0.0:
		print("REFUSING TO MEASURE: the camera is not aimed at the ground.")
		quit(1)
		return
	print("")

	# THE OBSERVATION POINT: standing at the Commons' north edge, looking across the gap.
	var stand := Vector3(0.0, 0.0, COMMONS.position.y + 1.5)
	_look_from(camera, stand, "COMMONS north edge")

	# And from a little further back, where a player naturally approaches the edge.
	_look_from(camera, Vector3(0.0, 0.0, COMMONS.position.y + 8.0), "COMMONS, 8 u back from the edge")

	# The overlook, for the early establishing view.
	_look_from(camera, Vector3(0.0, 0.0, -6.0), "OVERLOOK (entry)")
	quit(0)


func _look_from(camera: Camera3D, stand: Vector3, label: String) -> void:
	# Place the camera exactly where the follow camera would put it, clamp included.
	camera.position = camera._resolve_position(stand)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size

	print("FROM %s  (player at %s, camera at %s)" % [label, stand, camera.position])
	_report(camera, size, "JUNCTION near edge", Vector3(0.0, 0.0, JUNCTION.end.y))
	_report(camera, size, "JUNCTION centre   ", Vector3(0.0, 0.0, JUNCTION.position.y + JUNCTION.size.y * 0.5))
	_report(camera, size, "TERRACE centre    ", Vector3(0.0, 1.0, TERRACE.position.y + TERRACE.size.y * 0.5))
	_report(camera, size, "COMMONS far edge  ", Vector3(0.0, 0.0, COMMONS.position.y))
	_report(camera, size, "ROUTE B mouth     ", Vector3(23.0, 0.0, COMMONS.position.y))
	print("")


func _report(camera: Camera3D, size: Vector2, what: String, world: Vector3) -> void:
	if camera.is_position_behind(world):
		print("   %s  BEHIND THE CAMERA -- not visible" % what)
		return
	var screen: Vector2 = camera.unproject_position(world)
	var on_screen: bool = screen.x >= 0.0 and screen.x <= size.x and screen.y >= 0.0 and screen.y <= size.y
	# Where vertically? 0.0 = top of screen, 1.0 = bottom. A beat needs to be comfortably inside,
	# not clinging to the top edge where it is a smear of pixels.
	var vertical: float = screen.y / size.y
	var verdict: String = "OFF-SCREEN"
	if on_screen:
		if vertical < 0.08:
			verdict = "marginal (top %.0f%% of screen)" % (vertical * 100.0)
		else:
			verdict = "VISIBLE (%.0f%% down the screen)" % (vertical * 100.0)
	print("   %s  screen %s  -> %s" % [what, screen.round(), verdict])
