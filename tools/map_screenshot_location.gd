extends SceneTree
## WHERE IS THE PLAYER STANDING IN A SUPPLIED SCREENSHOT?
##
## Rulings keep turning on this and it may not be answered by looking at a picture and feeling
## confident. So the floor is searched by SIGNATURE: the features that are unambiguously readable
## in an image -- the surface the Envoy stands on, what colour of patch lies which way, whether
## hazard pads are visible on it, what crates are nearby -- are matched against the authored plan.
##
## SURFACE IS THE STRONGEST CUE, because it is what the eye reads as colour. Patches carry a
## `surface` name and the floor builder tints by it, so "dark ground with a large red-brown room
## to the east" is a fact about the plan, not an impression.

var L = load("res://game/gen/layouts/archive_roundabout.gd")
const STEP := 3.0
const NEAR := 22.0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var plan: FloorPlan = load("res://game/gen/depth_generator.gd").generate(0, 2)
	var bounds: WalkableBounds = plan.make_bounds()
	var names: Dictionary = {}
	for constant_name in L.get_script_constant_map():
		if String(constant_name).begins_with("P_"):
			names[int(L.get_script_constant_map()[constant_name])] = String(constant_name).substr(2)

	print("SCREENSHOT SIGNATURE MAP")
	print("")
	print("   Every standable position whose EAST neighbour is an arena-surfaced room, since both")
	print("   supplied images show dark ground with a large red-brown room off to the right.")
	print("")

	for patch: WalkablePatch in plan.patches:
		if patch.surface == &"arena":
			continue
		var east: WalkablePatch = _neighbour_east(plan, patch)
		if east == null or east.surface != &"arena":
			continue
		print("   STANDING IN %s %s  (surface %s)" % [names.get(patch.patch_id, "?"), patch.rect, patch.surface])
		print("      east neighbour: %s %s  (surface %s)" % [
			names.get(east.patch_id, "?"), east.rect, east.surface])
		var pads: Array = []
		for pad: SpikePadPlan in plan.spike_pads:
			if east.rect.intersects(pad.rect):
				pads.append(str(pad.rect))
		print("      hazard pads visible in that room: %s" % ("NONE" if pads.is_empty() else ", ".join(pads)))
		var crates: Array = []
		for breakable: BreakablePlan in plan.breakables:
			if WalkableBounds.contains(patch.rect, breakable.position.x, breakable.position.z):
				crates.append("%d at %s" % [breakable.breakable_id, str(breakable.position)])
		print("      crates on the ground you stand on: %s" % ("none" if crates.is_empty() else ", ".join(crates)))
		var raised: Array = []
		for other: WalkablePatch in plan.patches:
			if other.elevation != patch.elevation and (other.rect.get_center() - patch.rect.get_center()).length() < 60.0:
				raised.append("%s elev %.1f" % [names.get(other.patch_id, "?"), other.elevation])
		print("      nearby ground at another height: %s" % ("none" if raised.is_empty() else ", ".join(raised)))
		print("")

	print("   THE FORK, for comparison -- what the Court's decision point actually looks like:")
	var court: Rect2 = plan.patch_by_id(L.P_COURT).rect
	print("      COURT %s surface %s" % [court, plan.patch_by_id(L.P_COURT).surface])
	for connection: TraversalConnection in plan.connections:
		if connection.patch_ids.x == L.P_COURT or connection.patch_ids.y == L.P_COURT:
			var other_id: int = connection.patch_ids.y if connection.patch_ids.x == L.P_COURT else connection.patch_ids.x
			print("      way on -> %-12s aperture %s   open at load: %s" % [
				names.get(other_id, "?"), connection.aperture, str(connection.starts_open)])
	quit(0)


## The nearest patch lying EAST of this one and roughly level with it in z -- "the room off to the
## right", as opposed to any room that happens to have a larger x somewhere on the floor.
func _neighbour_east(plan: FloorPlan, patch: WalkablePatch) -> WalkablePatch:
	var best: WalkablePatch = null
	var best_gap: float = NEAR
	for other: WalkablePatch in plan.patches:
		if other.patch_id == patch.patch_id:
			continue
		if other.rect.position.y > patch.rect.end.y or other.rect.end.y < patch.rect.position.y:
			continue
		var gap: float = other.rect.position.x - patch.rect.end.x
		if gap >= 0.0 and gap < best_gap:
			best_gap = gap
			best = other
	return best
