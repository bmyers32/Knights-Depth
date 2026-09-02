extends SceneTree
## FLOOR 2 LEGIBILITY — is each beat's PAYOFF visible at its DECISION POINT?
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_floor2_legibility.gd
##
## A currency the player cannot see when they choose is not a currency. Projected through the
## REAL shipped camera -- the actual FollowCamera script, its authored offset and 45-degree
## pitch, its edge clamp, and the project's real viewport -- because these are claims about what
## is ON SCREEN, and world distance is not evidence for them.
##
## READS THE AUTHORED PLAN, never a copy of its coordinates. An earlier version of this tool
## hardcoded them and had to be manually re-synced every time the layout moved; that is exactly
## how a measurement quietly starts describing a floor that no longer exists.
##
## Reports only. No geometry is authored from this run.


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var L: GDScript = load("res://game/gen/layouts/archive_roundabout.gd")
	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var plan: FloorPlan = generator.generate(0, 2)

	var concourse: Rect2 = plan.patch_by_id(L.P_CONCOURSE).rect
	var route_a: Rect2 = plan.patch_by_id(L.P_ROUTE_A).rect
	var route_b: Rect2 = plan.patch_by_id(L.P_ROUTE_B).rect
	var junction: Rect2 = plan.patch_by_id(L.P_JUNCTION).rect
	var vault: Rect2 = plan.patch_by_id(L.P_VAULT).rect

	# The extent the camera clamp actually receives: the union of every authored rect.
	var extent: Rect2 = plan.patches[0].rect
	for rect: Rect2 in plan.all_rects():
		extent = extent.merge(rect)

	var camera: Camera3D = load("res://game/arena/follow_camera.gd").new()
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	Engine.get_main_loop().root.add_child(camera)
	camera.current = true
	camera.set_floor_extent(extent)
	var forward: Vector3 = -camera.global_transform.basis.z
	if forward.y >= 0.0 or forward.z >= 0.0:
		print("REFUSING TO MEASURE: the camera is not aimed at the ground.")
		quit(1)
		return
	print("FLOOR 2 LEGIBILITY — final authored coordinates, read from the plan")
	print("   floor extent %s   camera offset %s   pitch %.0f deg" % [extent, camera.offset, rad_to_deg(camera.rotation.x)])
	print("")

	var mouth_a := Vector3(route_a.get_center().x, 0.0, concourse.position.y)
	var mouth_b := Vector3(route_b.get_center().x, 0.0, concourse.position.y)
	var control := Vector3(L.CONTROL_PLATE.get_center().x, 0.0, L.CONTROL_PLATE.get_center().y)
	var exit_plate := Vector3(L.EXIT_PLATE.get_center().x, 1.0, L.EXIT_PLATE.get_center().y)

	# THE REQUIREMENT: both route choices meaningfully visible from the same decision area.
	print("DECISION: THE FORK  (the requirement -- both mouths from ONE decision area)")
	var legible_everywhere: bool = true
	for z: float in [-30.0, -34.0, -38.0, -42.0, -44.0]:
		var both: bool = _from(camera, Vector3(0.0, 0.0, z), [
			["mouth A", mouth_a], ["mouth B", mouth_b], ["control", control],
			["junction", Vector3(0.0, 0.0, junction.get_center().y)]])
		legible_everywhere = legible_everywhere and both
	print("   %s" % ("BOTH MOUTHS LEGIBLE THROUGHOUT THE APPROACH" if legible_everywhere
		else "NOT legible from every approach point -- inspect the rows above"))
	print("")

	print("DECISION: THE CONTROL  (standing on it, can the player see what it buys?)")
	_from(camera, control, [["mouth A (what it opens)", mouth_a], ["mouth B", mouth_b],
		["junction", Vector3(0.0, 0.0, junction.get_center().y)]])
	print("")

	print("ARRIVAL: THE JUNCTION  (is the exit readable once you are down?)")
	_from(camera, Vector3(-20.0, 0.0, junction.get_center().y), [["EXIT plate", exit_plate]])
	print("")

	print("PASSING: THE VAULT  (an empty room now -- it should read as a place, not a promise)")
	_from(camera, Vector3(route_b.get_center().x, 0.0, -54.0), [
		["vault mouth", Vector3(vault.position.x, 0.0, vault.get_center().y)],
		["vault interior", Vector3(vault.get_center().x, 0.0, vault.get_center().y)]])
	quit(0)


## Returns whether BOTH fork mouths were on screen, when both were asked for.
func _from(camera: Camera3D, stand: Vector3, targets: Array) -> bool:
	camera.position = camera._resolve_position(stand)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size
	var line: String = "   from %-22s " % str(stand)
	var mouths_seen: int = 0
	var mouths_asked: int = 0
	for entry in targets:
		var label: String = entry[0]
		var world: Vector3 = entry[1]
		var is_mouth: bool = label.begins_with("mouth")
		if is_mouth:
			mouths_asked += 1
		if camera.is_position_behind(world):
			line += "%s BEHIND  " % label
			continue
		var screen: Vector2 = camera.unproject_position(world)
		if screen.x < 0.0 or screen.x > size.x or screen.y < 0.0 or screen.y > size.y:
			line += "%s OFF-SCREEN  " % label
			continue
		if is_mouth:
			mouths_seen += 1
		line += "%s %.0f%%d/%.0f%%a  " % [label, screen.y / size.y * 100.0, screen.x / size.x * 100.0]
	print(line)
	return mouths_asked < 2 or mouths_seen == mouths_asked
