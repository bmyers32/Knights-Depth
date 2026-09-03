extends SceneTree
## HOW MUCH OF THE FLOOR IS VISIBLE FROM WHERE? (2026-09-04)
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_floor_reveal.gd
##
## The human's finding was "I can see everything from the initial drop", and a production floor is
## supposed to unfold as it is traversed. That is a claim about what is ON SCREEN, so it gets
## projected through the REAL shipped camera rather than argued from world distance.
##
## READS THE AUTHORED PLAN, never a copy of its coordinates -- a measurement that has to be
## hand-resynced is how one quietly starts describing a floor that no longer exists.
##
## OCCLUSION IS MODELLED (2026-09-04). The first version measured the FRUSTUM only and could
## therefore never credit a wall, a column or a rise for hiding anything -- which made it useless
## for judging a fix whose whole method is occluders. A sample point now also has to have an
## unobstructed line from the camera: the ray is walked against every solid segment and obstacle,
## and blocked when it passes BELOW the height of something it crosses.
##
## STILL AN APPROXIMATION, stated rather than buried: ground is treated as flat at the sampled
## height, and a space counts as visible if ANY of its 25 sample points is both in frustum and
## unobstructed. So it errs toward reporting MORE reveal than a player sees, which is the safe
## direction for a measure whose job is to catch a floor that shows too much.
##
## Reports only. No geometry is authored from this run.


var _solids: Array[Dictionary] = []
var _blockers: Array[Dictionary] = []
## Wall height in the shipped builder. Read as a constant here rather than imported, because the
## builder is presentation and this tool must not start depending on it structurally.
const WALL_HEIGHT: float = 2.2


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var L: GDScript = load("res://game/gen/layouts/archive_roundabout.gd")
	var plan: FloorPlan = load("res://game/gen/depth_generator.gd").generate(0, 2)
	_solids = plan.solid_segments()
	_blockers = []
	for obstacle in plan.obstacles:
		_blockers.append({"rect": obstacle.rect, "height": obstacle.height})
	for breakable in plan.breakables:
		if breakable.blocking_rect.get_area() > 0.0:
			_blockers.append({"rect": breakable.blocking_rect, "height": 1.8})

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

	var names: Dictionary = {
		L.P_OVERLOOK: "OVERLOOK", L.P_DESCENT: "DESCENT", L.P_LANDING: "LANDING",
		L.P_THICKET: "THICKET", L.P_SPILLWAY: "SPILLWAY", L.P_GALLERY: "GALLERY",
		L.P_ROUTE_A: "ROUTE A", L.P_ROUTE_B: "ROUTE B", L.P_VAULT: "VAULT",
		L.P_JUNCTION: "JUNCTION", L.P_TERRACE: "TERRACE",
	}
	print("FLOOR REVEAL — how much is in view from each major standing point")
	print("   floor extent %s   %d occluders modelled" % [extent, _blockers.size() + _solids.size()])
	print("")

	var stations: Array = [
		["THE DROP (entry)", plan.entry_point],
		["foot of the descent", Vector3(0.0, 0.0, -22.0)],
		["mid landing", Vector3(0.0, 0.0, -28.0)],
		["thicket", Vector3(-20.0, 0.0, -46.0)],
		["spillway", Vector3(20.0, 0.0, -46.0)],
		["gallery", Vector3(0.0, 0.0, -64.0)],
		["junction", Vector3(0.0, 0.0, -92.0)],
	]
	for station in stations:
		_report(camera, plan, names, station[0], station[1])


func _report(camera: Camera3D, plan: FloorPlan, names: Dictionary, label: String, stand: Vector3) -> void:
	camera.position = camera._resolve_position(stand)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size

	# THE FRACTION MATTERS, not merely the yes/no: a sliver of a distant space is a hint, while
	# most of it on screen is the floor explaining itself before the player has walked anywhere.
	var seen: Array = []
	var wholly_or_mostly: int = 0
	for patch: WalkablePatch in plan.patches:
		var share: float = _fraction_visible(camera, size, patch.rect)
		if share <= 0.0:
			continue
		if share >= 0.5:
			wholly_or_mostly += 1
		seen.append("%s %.0f%%" % [names.get(patch.patch_id, str(patch.patch_id)), share * 100.0])
	print("FROM %-22s  %d of %d spaces in view, %d of them half or more" % [
		label, seen.size(), plan.patches.size(), wholly_or_mostly])
	print("        %s" % ", ".join(seen))


## What share of a rect's sample grid lands on screen. Any share above zero counts as "in view",
## because a sliver of a later space is still a glimpse of it.
func _fraction_visible(camera: Camera3D, size: Vector2, rect: Rect2) -> float:
	var visible_count: int = 0
	var total: int = 0
	for column in 5:
		for row in 5:
			var point := Vector3(
				rect.position.x + rect.size.x * (float(column) / 4.0),
				0.0,
				rect.position.y + rect.size.y * (float(row) / 4.0))
			total += 1
			if camera.is_position_behind(point):
				continue
			var screen: Vector2 = camera.unproject_position(point)
			if screen.x < 0.0 or screen.x > size.x or screen.y < 0.0 or screen.y > size.y:
				continue
			if _occluded(camera.global_position, point):
				continue
			visible_count += 1
	return float(visible_count) / float(total)


## Is the line from the camera to this ground point interrupted by something tall enough?
##
## Walked in steps rather than solved analytically: the geometry is a handful of axis-aligned
## boxes and a few hundred samples per space, so clarity is worth more here than cleverness --
## and a measurement nobody can check is worth nothing.
func _occluded(from: Vector3, to: Vector3) -> bool:
	var steps: int = 60
	for step in range(1, steps):
		var t: float = float(step) / float(steps)
		var along: Vector3 = from.lerp(to, t)
		for blocker in _blockers:
			if WalkableBounds.contains(blocker["rect"], along.x, along.z) and along.y < float(blocker["height"]):
				return true
		for segment in _solids:
			var on_span: bool = false
			if segment["axis"] == &"x":
				on_span = absf(along.x - float(segment["at"])) < 0.35 					and along.z >= float(segment["min"]) and along.z <= float(segment["max"])
			else:
				on_span = absf(along.z - float(segment["at"])) < 0.35 					and along.x >= float(segment["min"]) and along.x <= float(segment["max"])
			if on_span and along.y < float(segment["elevation"]) + WALL_HEIGHT:
				return true
	return false
