extends SceneTree
## FLOOR 2 ITERATION — PAPER MEASUREMENT of the proposed fork, BEFORE authoring anything.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_floor2_fork_proposal.gd
##
## The ruling requires both route mouths to be meaningfully visible from a shared decision area,
## and requires Route A to be re-costed in real play rather than asserted. Both are measurable on
## paper coordinates, so the proposal is measured before it is built and the veto stays cheap.
##
## PROPOSAL: the Concourse keeps its ratified width -- the human liked the openness -- and only
## the ROUTE MOUTHS come inboard. That fixes what failed without spending what worked.
##
## Reports only. Nothing here is authored.

## Unchanged from the shipped floor.
const CONCOURSE := Rect2(-26.0, -46.0, 52.0, 28.0)
const JUNCTION := Rect2(-30.0, -71.0, 60.0, 10.0)
const TERRACE := Rect2(-28.0, -85.0, 16.0, 12.0)
const EXIT_PLATE := Rect2(-22.0, -82.0, 4.0, 4.0)
const FLOOR_EXTENT := Rect2(-30.0, -85.0, 74.0, 83.0)

## PROPOSED: mouths 20 apart instead of 46.
const ROUTE_A := Rect2(-16.0, -62.0, 12.0, 14.0)
const ROUTE_B := Rect2(4.0, -62.0, 12.0, 14.0)
const MOUTH_A := Vector3(-10.0, 0.0, -47.0)
const MOUTH_B := Vector3(10.0, 0.0, -47.0)

## Candidate control placements, costed below.
const CONTROL_ON_THE_WAY := Vector3(-14.0, 0.0, -32.0)   # shipped position
const CONTROL_WEST_WING := Vector3(-23.0, 0.0, -30.0)    # a real detour
const CONTROL_EAST_WING := Vector3(23.0, 0.0, -30.0)     # on the way to the DEFAULT route

const RAMP_FOOT := Vector3(0.0, 0.0, -20.0)


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var viewport: Viewport = Engine.get_main_loop().root
	var camera: Camera3D = load("res://game/arena/follow_camera.gd").new()
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	viewport.add_child(camera)
	camera.current = true
	camera.set_floor_extent(FLOOR_EXTENT)
	var forward: Vector3 = -camera.global_transform.basis.z
	if forward.y >= 0.0 or forward.z >= 0.0:
		print("REFUSING TO MEASURE: the camera is not aimed at the ground.")
		quit(1)
		return

	print("PROPOSED FORK — are BOTH mouths visible from a shared decision area?")
	print("   shipped: mouths 46 apart, both OFF-SCREEN.  proposed: %.0f apart." % (MOUTH_B.x - MOUTH_A.x))
	print("")
	for stand: Vector3 in [Vector3(0, 0, -34.0), Vector3(0, 0, -40.0), Vector3(0, 0, -44.0)]:
		_from(camera, stand)

	print("ROUTE A RE-COSTED against the REAL destination.")
	print("   The intermediate party plate is removed (ruling F), so Route A no longer saves")
	print("   distance to a plate whose purpose needed explaining -- it saves distance to the")
	print("   EXIT, which the player can already see.")
	var exit_point := Vector3(EXIT_PLATE.get_center().x, 0.0, EXIT_PLATE.get_center().y)
	var a_exit := Vector3(-10.0, 0.0, -61.0)
	var b_exit := Vector3(10.0, 0.0, -61.0)
	var via_a: float = a_exit.distance_to(exit_point)
	var via_b: float = b_exit.distance_to(exit_point)
	print("   from Route A's foot %s -> exit  = %.1f" % [a_exit, via_a])
	print("   from Route B's foot %s -> exit  = %.1f" % [b_exit, via_b])
	print("   Route A saves %.1f units of walking." % (via_b - via_a))
	print("")

	print("WHAT THE CONTROL COSTS, in the same currency it pays in.")
	print("   On a ONE-PASS floor the only price a control can charge is the walk to reach it.")
	print("   If that detour costs about what the shortcut saves, buying it is never worth it.")
	for entry in [["shipped, on the way west", CONTROL_ON_THE_WAY],
			["west wing (a real detour)", CONTROL_WEST_WING],
			["east wing (on the way to the DEFAULT route)", CONTROL_EAST_WING]]:
		var control: Vector3 = entry[1]
		var direct: float = RAMP_FOOT.distance_to(MOUTH_A)
		var detoured: float = RAMP_FOOT.distance_to(control) + control.distance_to(MOUTH_A)
		var cost: float = detoured - direct
		var verdict: String = "WORTH IT (saves %.1f more than it costs)" % (via_b - via_a - cost)
		if cost >= via_b - via_a:
			verdict = "NEVER WORTH IT (costs %.1f, saves %.1f)" % [cost, via_b - via_a]
		elif cost < 2.0:
			verdict = "FREE -- and a free control is not a choice"
		print("   %-44s detour %5.1f   -> %s" % [entry[0], cost, verdict])
	quit(0)


func _from(camera: Camera3D, stand: Vector3) -> void:
	camera.position = camera._resolve_position(stand)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size
	var line: String = "   from %s  " % stand
	var both: bool = true
	for entry in [["A", MOUTH_A], ["B", MOUTH_B], ["junction", Vector3(0, 0, -66.0)]]:
		var world: Vector3 = entry[1]
		if camera.is_position_behind(world):
			line += "%s BEHIND  " % entry[0]
			both = false
			continue
		var screen: Vector2 = camera.unproject_position(world)
		var on: bool = screen.x >= 0.0 and screen.x <= size.x and screen.y >= 0.0 and screen.y <= size.y
		if not on:
			line += "%s OFF-SCREEN  " % entry[0]
			if entry[0] != "junction":
				both = false
			continue
		line += "%s %.0f%%down/%.0f%%across  " % [entry[0], screen.y / size.y * 100.0, screen.x / size.x * 100.0]
	print(line + ("  <- BOTH MOUTHS LEGIBLE" if both else "  <- still not a readable fork"))
