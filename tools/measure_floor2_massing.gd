extends SceneTree
## PAPER MEASUREMENT of a BROADER, MASSED Floor 2 — before any of it is authored (2026-09-04).
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_floor2_massing.gd
##
## WHAT THE CURRENT FLOOR MEASURED, and it is a sharper complaint than "too much is visible":
## every space in view is either SOLVED (most of it visible AND its way in visible) or oriented.
## ZERO spaces anywhere on the floor are FORESHADOWED -- seen without their route. The floor has
## no glimpse register at all. Spaces are either fully explained or absent.
##
## THE REFERENCE ACHIEVES CONTAINMENT WITH MODEST ARCHITECTURE, so the question is no longer "how
## tall must a wall be". It is: can broad lateral travel plus ordinary-height masses that hide
## APERTURES rather than whole rooms produce orientation now, foreshadowing next, route later?
##
## THE PROPOSAL DELIBERATELY USES SHORT MASSES (height 4, versus the shipped height-9 slabs) so
## the paper can report whether the giant walls are still needed. That is the question being
## asked; it is not assumed either way.
##
## Reports only. Nothing here is authored.

const MASS_HEIGHT: float = 4.0

## Broad in BOTH axes: major spaces sit at materially different x as well as z.
const SPACES: Dictionary = {
	"OVERLOOK":   Rect2(-56.0, -12.0, 16.0, 10.0),
	"DESCENT":    Rect2(-52.0, -24.0, 10.0, 12.0),
	"LANDING":    Rect2(-58.0, -46.0, 28.0, 22.0),
	"WEST HALL":  Rect2(-34.0, -42.0, 32.0, 10.0),
	"COURT":      Rect2(-4.0, -74.0, 40.0, 30.0),
	"VAULT":      Rect2(40.0, -66.0, 14.0, 14.0),
	"SOUTH LANE": Rect2(0.0, -92.0, 30.0, 10.0),
	"HALL":       Rect2(-52.0, -100.0, 50.0, 22.0),
	"PUZZLE BAY": Rect2(-50.0, -124.0, 28.0, 16.0),
	"P WEST":     Rect2(-50.0, -140.0, 12.0, 12.0),
	"P EAST":     Rect2(-34.0, -140.0, 12.0, 12.0),
	"JUNCTION":   Rect2(-30.0, -158.0, 58.0, 16.0),
	"TERRACE":    Rect2(8.0, -174.0, 18.0, 14.0),
}

## The APERTURE into each space -- what must be hidden for a glimpse to stay a glimpse.
const WAYS_IN: Dictionary = {
	# The entry has no way IN -- you arrive there. Given its own footprint so the classifier does
	# not report the space the player is standing in as an unreachable glimpse.
	"OVERLOOK":   Rect2(-56.0, -12.0, 16.0, 10.0),
	"DESCENT":    Rect2(-49.5, -25.5, 5.0, 4.0),
	"LANDING":    Rect2(-49.5, -47.0, 5.0, 6.0),
	"WEST HALL":  Rect2(-35.0, -40.0, 6.0, 6.0),
	"COURT":      Rect2(-6.0, -48.0, 6.0, 8.0),
	"VAULT":      Rect2(35.5, -61.0, 6.0, 5.0),
	"SOUTH LANE": Rect2(20.0, -84.0, 6.0, 6.0),
	"HALL":       Rect2(-6.0, -90.0, 6.0, 8.0),
	"PUZZLE BAY": Rect2(-42.0, -110.0, 6.0, 8.0),
	"P WEST":     Rect2(-46.0, -142.0, 5.0, 6.0),
	"P EAST":     Rect2(-30.0, -142.0, 5.0, 6.0),
	"JUNCTION":   Rect2(-28.0, -160.0, 6.0, 6.0),
	"TERRACE":    Rect2(14.0, -176.0, 5.0, 6.0),
}

## ORDINARY-HEIGHT ARCHITECTURE, placed to hide WAYS IN rather than whole rooms. Each is an
## L-limb or a room's near wall -- the shapes the reference uses -- not a slab across the floor.
const MASSES: Array = [
	Rect2(-30.0, -58.0, 26.0, 6.0),   # the court's near wall: hides its mouth from the landing
	Rect2(-4.0, -52.0, 10.0, 10.0),   # L-limb turning that wall north, so the mouth is round a corner
	Rect2(6.0, -84.0, 26.0, 6.0),     # the south lane's near wall
	Rect2(-14.0, -84.0, 8.0, 14.0),   # L-limb: hall's mouth is reached around it
	Rect2(-40.0, -108.0, 26.0, 6.0),  # the puzzle bay's near wall
	Rect2(-2.0, -150.0, 24.0, 6.0),   # screens the terrace approach from the junction's east end
	# THE HALL'S OWN NEAR WALL. Added after the first run measured it at 80% from the Landing --
	# whole-room comprehension of a late space. A mass close to the room it hides works where one
	# close to the VIEWER cannot: shadow reach is t/(1 - h/12), so the same modest height covers
	# far more ground when it stands at the far end of the sightline.
	Rect2(-58.0, -78.0, 50.0, 6.0),
]

## Where the player stands while each beat is current.
const STATIONS: Array = [
	["THE DROP", Vector3(-48.0, 0.0, -7.0)],
	["landing", Vector3(-44.0, 0.0, -36.0)],
	["west hall", Vector3(-18.0, 0.0, -37.0)],
	["court", Vector3(16.0, 0.0, -60.0)],
	["south lane", Vector3(15.0, 0.0, -87.0)],
	["hall", Vector3(-28.0, 0.0, -89.0)],
	["puzzle bay", Vector3(-36.0, 0.0, -116.0)],
	["junction", Vector3(0.0, 0.0, -150.0)],
]


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var extent: Rect2 = SPACES["OVERLOOK"]
	for key in SPACES:
		extent = extent.merge(SPACES[key])

	var camera: Camera3D = load("res://game/arena/follow_camera.gd").new()
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	Engine.get_main_loop().root.add_child(camera)
	camera.current = true
	camera.set_floor_extent(extent)
	if -camera.global_transform.basis.z.y >= 0.0:
		print("REFUSING TO MEASURE: the camera is not aimed at the ground.")
		quit(1)
		return

	print("BROADER MASSED PROPOSAL — orientation now, foreshadowing next, route later")
	print("   extent %s   %.0f wide x %.0f deep" % [extent, extent.size.x, extent.size.y])
	print("   %d masses, ALL height %.1f (the shipped fold walls are 9.0)" % [MASSES.size(), MASS_HEIGHT])
	print("")
	for station in STATIONS:
		_report(camera, station[0], station[1])


func _report(camera: Camera3D, label: String, stand: Vector3) -> void:
	camera.position = camera._resolve_position(stand)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size

	var lines: Array = []
	var solved: int = 0
	var glimpsed: int = 0
	for key in SPACES:
		var share: float = _fraction_visible(camera, size, SPACES[key])
		if share <= 0.0:
			continue
		var route: bool = WAYS_IN.has(key) and _fraction_visible(camera, size, WAYS_IN[key]) > 0.0
		var verdict: String = "FORESHADOW"
		if route and share >= 0.5:
			verdict = "SOLVED"
			solved += 1
		elif route:
			verdict = "oriented"
		else:
			glimpsed += 1
		lines.append("%s %.0f%% %s" % [key, share * 100.0, verdict])
	print("FROM %-14s %d in view -- %d SOLVED, %d glimpsed" % [label, lines.size(), solved, glimpsed])
	print("      %s" % ", ".join(lines))


func _fraction_visible(camera: Camera3D, size: Vector2, rect: Rect2) -> float:
	var seen: int = 0
	for column in 5:
		for row in 5:
			var point := Vector3(
				rect.position.x + rect.size.x * (float(column) / 4.0), 0.0,
				rect.position.y + rect.size.y * (float(row) / 4.0))
			if camera.is_position_behind(point):
				continue
			var screen: Vector2 = camera.unproject_position(point)
			if screen.x < 0.0 or screen.x > size.x or screen.y < 0.0 or screen.y > size.y:
				continue
			if _occluded(camera.global_position, point):
				continue
			seen += 1
	return float(seen) / 25.0


func _occluded(from: Vector3, to: Vector3) -> bool:
	for step in range(1, 60):
		var along: Vector3 = from.lerp(to, float(step) / 60.0)
		for mass: Rect2 in MASSES:
			if along.x >= mass.position.x and along.x <= mass.end.x \
					and along.z >= mass.position.y and along.z <= mass.end.y \
					and along.y < MASS_HEIGHT:
				return true
	return false
