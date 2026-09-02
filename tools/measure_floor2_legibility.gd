extends SceneTree
## FLOOR 2 BEAT-ECONOMY MEASUREMENT — is each beat's PAYOFF legible at its DECISION POINT?
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_floor2_legibility.gd
##
## A currency the player cannot see when they choose is not a currency. The beat table claims
## Route A's saving is illegible and the Vault's temptation is unreadable; both are claims about
## what is ON SCREEN, so both get projected through the real shipped camera rather than argued
## from world distance. Same instrument as the sightline measurement, same guard against a
## transposed basis.
##
## Reports only. No geometry is authored from this run.

const FLOOR_EXTENT := Rect2(-30.0, -85.0, 74.0, 83.0)


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var L: GDScript = load("res://game/gen/layouts/archive_roundabout.gd")
	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var plan: FloorPlan = generator.generate(0, 2)
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

	print("FLOOR 2 LEGIBILITY — can the player PRICE each choice at the moment they make it?")
	print("")

	# DECISION 1: the fork. Standing in the concourse where the two mouths diverge, can the
	# player see what Route A actually buys -- the party plate at the junction's west end?
	print("DECISION: THE FORK  (standing mid-concourse, about to pick a route)")
	_from(camera, Vector3(0.0, 0.0, -40.0), [
		["ROUTE A mouth      ", Vector3(-22.0, 0.0, -47.0)],
		["ROUTE B mouth      ", Vector3(22.0, 0.0, -47.0)],
		["PARTY PLATE (what A buys)", Vector3(-22.0, 0.0, -66.0)],
		["JUNCTION centre    ", Vector3(0.0, 0.0, -66.0)],
	])

	# DECISION 2: the control. Standing on it, is the thing it opens visible?
	print("DECISION: THE CONTROL  (standing on the plate, about to pay for the shortcut)")
	_from(camera, Vector3(-14.0, 0.0, -32.0), [
		["ROUTE A mouth      ", Vector3(-22.0, 0.0, -47.0)],
		["PARTY PLATE (what it buys)", Vector3(-22.0, 0.0, -66.0)],
	])

	# DECISION 3: the vault. Walking down route B, is it visible and does it read as inviting?
	print("DECISION: THE VAULT  (walking down route B, about to pass its mouth)")
	_from(camera, Vector3(23.0, 0.0, -52.0), [
		["VAULT mouth        ", Vector3(31.0, 0.0, -54.0)],
		["VAULT interior     ", Vector3(38.0, 0.0, -54.0)],
		["VAULT plate        ", Vector3(36.0, 0.0, -55.0)],
		["JUNCTION (the way on)", Vector3(20.0, 0.0, -66.0)],
	])

	# DECISION 4: the party plate, and what standing on it opens.
	print("DECISION: THE PARTY PLATE  (standing on it, about to be sent a few steps north)")
	_from(camera, Vector3(-22.0, 0.0, -66.0), [
		["TERRACE gate       ", Vector3(-20.0, 0.0, -72.0)],
		["EXIT plate         ", Vector3(-20.0, 1.0, -80.0)],
	])
	_measure_view_width(camera, plan, L)
	quit(0)


## HOW WIDE IS THE CAMERA'S VIEW AT PLAYER SCALE? The fork's two mouths measured OFF-SCREEN
## from mid-concourse while the DESTINATION measured visible, which is the opposite of the
## assumption the beat table started from. If the room is wider than the view, its two exits can
## never be on screen together and the fork cannot read as a fork -- so the number matters.
func _measure_view_width(camera: Camera3D, plan: FloorPlan, L: GDScript) -> void:
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size
	var stand := Vector3(0.0, 0.0, -40.0)
	camera.position = camera._resolve_position(stand)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	print("CAMERA REACH at the fork's decision point (player at %s)" % stand)
	for z: float in [-40.0, -47.0, -55.0, -66.0]:
		var half: float = 0.0
		for step in 2000:
			var x: float = float(step) * 0.05
			var world := Vector3(x, 0.0, z)
			if camera.is_position_behind(world):
				break
			var screen: Vector2 = camera.unproject_position(world)
			if screen.x > size.x:
				break
			half = x
		print("   at z=%.0f the view spans x[%.1f, %.1f]  (%.0f units wide)" % [z, -half, half, half * 2.0])
	var concourse: Rect2 = plan.patch_by_id(L.P_CONCOURSE).rect
	print("   the CONCOURSE is %.0f units wide, and its two route mouths sit %.0f apart." % [
		concourse.size.x, plan.patch_by_id(L.P_ROUTE_B).rect.get_center().x - plan.patch_by_id(L.P_ROUTE_A).rect.get_center().x])


func _from(camera: Camera3D, stand: Vector3, targets: Array) -> void:
	camera.position = camera._resolve_position(stand)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_visible_rect().size
	print("   player at %s" % stand)
	for entry in targets:
		var world: Vector3 = entry[1]
		if camera.is_position_behind(world):
			print("      %s  BEHIND THE CAMERA -- not visible" % entry[0])
			continue
		var screen: Vector2 = camera.unproject_position(world)
		var on: bool = screen.x >= 0.0 and screen.x <= size.x and screen.y >= 0.0 and screen.y <= size.y
		var down: float = screen.y / size.y
		var across: float = screen.x / size.x
		var verdict: String = "OFF-SCREEN"
		if on:
			verdict = "marginal (%.0f%% down)" % (down * 100.0) if down < 0.08 else "VISIBLE (%.0f%% down, %.0f%% across)" % [down * 100.0, across * 100.0]
		print("      %s  -> %s" % [entry[0], verdict])
	print("")
