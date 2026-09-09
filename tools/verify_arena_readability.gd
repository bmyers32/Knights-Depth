extends SceneTree
## CAN THE PLAYER SEE THE FIGHT THEY ARE IN?
##
## The Arena ruling lists readability requirements the camera has to satisfy, and every one of
## them is a claim about the SHIPPED camera rather than about a floor plan: active pads readable,
## Envoy visible, enemies trackable, no accidental trapping pockets. So they are measured through
## the real camera at the real standing points instead of argued from a top-down rect, which is
## the mistake an earlier reveal test made when it used world distance as a proxy for visibility
## and passed while the floor showed almost everything.
##
## THE STANDING POINT IS THE PARTY PLATE, because that is where the player is at the instant every
## wave activates. If a threat is off-screen at the moment it wakes, the fight is unfair in the one
## way a wave arena must never be.

const L = preload("res://game/gen/layouts/archive_roundabout.gd")


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var plan: FloorPlan = load("res://game/gen/depth_generator.gd").generate(0, 2)
	var arena: Rect2 = plan.patch_by_id(L.P_ARENA).rect
	var extent: Rect2 = plan.patches[0].rect
	for patch: WalkablePatch in plan.patches:
		extent = extent.merge(patch.rect)

	var camera: Camera3D = load("res://game/arena/follow_camera.gd").new()
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	Engine.get_main_loop().root.add_child(camera)
	camera.current = true
	camera.set_floor_extent(extent)

	var plate := Vector3(L.PARTY_PLATE.get_center().x, 0.0, L.PARTY_PLATE.get_center().y)
	# Placed exactly as the reveal instrument places it -- through the shipped camera's own
	# resolver, so this measures the camera the game uses rather than one that resembles it.
	camera.position = camera._resolve_position(plate)
	camera.rotation = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
	var size: Vector2 = Engine.get_main_loop().root.get_viewport().get_visible_rect().size

	print("ARENA READABILITY — measured through the shipped camera, standing on the party plate")
	print("   arena %s   plate at %s" % [arena, plate])
	print("")

	print("   THE HAZARD -- every cluster must be readable before it matters")
	for pad: SpikePadPlan in plan.spike_pads:
		if not arena.intersects(pad.rect):
			continue
		var centre := Vector3(pad.rect.get_center().x, 0.0, pad.rect.get_center().y)
		print("      pad %d %s -> %s   (%.1f from the plate)" % [
			pad.pad_id, pad.rect, _verdict(camera, size, centre), (centre - plate).length()])

	print("")
	print("   THE THREATS -- on screen at the moment their wave wakes, or the fight is unfair")
	var offscreen: int = 0
	for site: EncounterSite in plan.encounters:
		if not arena.intersects(site.regions[0]):
			continue
		for member: Dictionary in site.roster:
			var at: Vector3 = member["position"]
			var seen: bool = _on_screen(camera, size, at)
			if not seen:
				offscreen += 1
			print("      encounter %d  %-8s %s -> %s   (%.1f from the plate)" % [
				site.encounter_id, String(member["enemy_key"]), str(at),
				"VISIBLE" if seen else "*** OFF SCREEN ***", (at - plate).length()])

	print("")
	print("   THE ENVOY -- the ground under their own feet")
	print("      plate itself: %s" % _verdict(camera, size, plate))
	var covered: int = 0
	for step in 16:
		var angle: float = TAU * float(step) / 16.0
		if not _on_screen(camera, size, plate + Vector3(cos(angle), 0.0, sin(angle)) * 6.0):
			covered += 1
	print("      %d of 16 points on a 6-unit ring around the plate are off screen" % covered)

	print("")
	if offscreen > 0:
		print("   FINDING: %d authored spawn(s) are off screen from the commitment point." % offscreen)
		print("   Reported rather than silently re-placed -- the camera is not mine to change, and")
		print("   whether an off-screen wake reads as unfair or as a threat arriving is a play")
		print("   question, not a measurement one.")
	else:
		print("   Every authored threat is on screen when its wave wakes.")
	quit(0)


func _verdict(camera: Camera3D, size: Vector2, point: Vector3) -> String:
	return "on screen" if _on_screen(camera, size, point) else "*** OFF SCREEN ***"


func _on_screen(camera: Camera3D, size: Vector2, point: Vector3) -> bool:
	if camera.is_position_behind(point):
		return false
	var projected: Vector2 = camera.unproject_position(point)
	return projected.x >= 0.0 and projected.x <= size.x and projected.y >= 0.0 and projected.y <= size.y
