extends SceneTree
## PAPER MEASUREMENT of a SWITCHBACK floor, before any of it is authored (2026-09-04).
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_floor2_switchback.gd
##
## THE MEASURED PROBLEM: the current floor shows 10 of its 11 spaces from the drop. The cause is
## not size, and adding length would not fix it -- THE CAMERA LOOKS FAR AND NARROW. At a fixed
## 45-degree pitch down the -z axis it sees deep ahead and little to either side, so a floor laid
## out as a north-south column of spaces is a floor the camera reads end to end.
##
## THE PROPOSAL: lay the floor ACROSS the view rather than along it. Legs run east-west, stepped
## in z, so each leg leaves the frustum of the one before. No fog, no camera change, no empty
## corridors -- just geometry arranged against how the camera actually sees.
##
## Reports only. Nothing here is authored.

## Half-width of the view at a given depth, fitted from the shipped camera and re-derived below
## rather than trusted: roughly 13 units at the player's own depth, widening about 0.54 per unit.
const PROPOSED: Dictionary = {
	"OVERLOOK":  Rect2(-8.0, -10.0, 16.0, 8.0),
	"DESCENT":   Rect2(-4.0, -18.0, 8.0, 8.0),
	"LANDING":   Rect2(-16.0, -36.0, 32.0, 16.0),
	"WEST LANE": Rect2(-44.0, -34.0, 28.0, 8.0),
	"THICKET":   Rect2(-58.0, -58.0, 26.0, 22.0),
	"SPILLWAY":  Rect2(-58.0, -84.0, 26.0, 22.0),
	"EAST LANE": Rect2(-32.0, -80.0, 34.0, 8.0),
	"GALLERY":   Rect2(2.0, -102.0, 44.0, 22.0),
	"PUZZLE":    Rect2(10.0, -128.0, 34.0, 20.0),
	"JUNCTION":  Rect2(-24.0, -144.0, 68.0, 12.0),
	"TERRACE":   Rect2(-22.0, -160.0, 18.0, 14.0),
}

## Where a player actually stands while each beat is the current one.
const STATIONS: Array = [
	["THE DROP (entry)", Vector3(0.0, 0.0, -6.0)],
	["landing", Vector3(0.0, 0.0, -28.0)],
	["west lane", Vector3(-30.0, 0.0, -30.0)],
	["thicket", Vector3(-45.0, 0.0, -47.0)],
	["spillway", Vector3(-45.0, 0.0, -73.0)],
	["east lane", Vector3(-14.0, 0.0, -76.0)],
	["gallery", Vector3(24.0, 0.0, -91.0)],
	["puzzle", Vector3(27.0, 0.0, -118.0)],
	["junction", Vector3(0.0, 0.0, -138.0)],
]


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var extent: Rect2 = PROPOSED["OVERLOOK"]
	for key in PROPOSED:
		extent = extent.merge(PROPOSED[key])

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

	print("SWITCHBACK PROPOSAL — reveal per station (frustum only; occlusion NOT modelled)")
	print("   extent %s" % extent)
	print("")
	_derive_view_shape(camera)
	print("")

	var order: Array = PROPOSED.keys()
	for station in STATIONS:
		_report(camera, order, station[0], station[1])


## THE INSTRUMENT EXPLAINS ITSELF before it judges anything: how far and how wide does this
## camera actually see? Everything above rests on the answer, so it is measured, not assumed.
func _derive_view_shape(camera: Camera3D) -> void:
	camera.position = camera._resolve_position(Vector3(0.0, 0.0, -60.0))
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size
	print("VIEW SHAPE, measured from a stand at z=-60:")
	for depth: float in [0.0, 10.0, 20.0, 40.0, 60.0]:
		var half: float = 0.0
		for step in 2000:
			var x: float = float(step) * 0.05
			var point := Vector3(x, 0.0, -60.0 - depth)
			if camera.is_position_behind(point):
				break
			if camera.unproject_position(point).x > size.x:
				break
			half = x
		print("   %3.0f units ahead -> visible half-width %5.1f" % [depth, half])
	print("   ...so the view is DEEP and NARROW. Ground beside the player leaves it far sooner")
	print("   than ground in front of them, which is the whole basis of the proposal.")


func _report(camera: Camera3D, order: Array, label: String, stand: Vector3) -> void:
	camera.position = camera._resolve_position(stand)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size
	var seen: Array = []
	for key in order:
		if _any_corner_visible(camera, size, PROPOSED[key]):
			seen.append(key)
	print("FROM %-20s sees %d of %d: %s" % [label, seen.size(), order.size(), ", ".join(seen)])


func _any_corner_visible(camera: Camera3D, size: Vector2, rect: Rect2) -> bool:
	for column in 5:
		for row in 5:
			var point := Vector3(
				rect.position.x + rect.size.x * (float(column) / 4.0),
				0.0,
				rect.position.y + rect.size.y * (float(row) / 4.0))
			if camera.is_position_behind(point):
				continue
			var screen: Vector2 = camera.unproject_position(point)
			if screen.x >= 0.0 and screen.x <= size.x and screen.y >= 0.0 and screen.y <= size.y:
				return true
	return false
