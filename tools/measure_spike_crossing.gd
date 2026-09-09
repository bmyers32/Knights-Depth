extends SceneTree
## HOW LONG DOES IT ACTUALLY TAKE TO CROSS THE SPIKE LANE? (ruled 2026-09-04)
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_spike_crossing.gd
##
## THE LAW: when the spikes retract and a normal-speed player commits immediately, they must be
## fully clear before the lane is damaging again. So SAFE_TICKS is not a feel number -- it is
## derived from a measured crossing, plus grace.
##
## MEASURED THROUGH THE REAL MOVE COMMAND at the authored envoy speed, from a legal standing
## position NORTH of the lane until the BODY is entirely clear on the far side. Not centre-to-
## centre: a body still overlapping the pad is still standing in it.
##
## Reports only.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var plan: FloorPlan = load("res://game/gen/depth_generator.gd").generate(0, 2)
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var envoy: Resource = db.get_resource(&"envoy", &"default")

	# ONE LANE PER HOST ROOM (corrected 2026-09-08). The floor now authors hazards in two
	# different chapters, and merging every pad on it produced a single "lane" spanning 82 units
	# of mostly void, whose crossing measured 249 ticks -- a number describing nothing that
	# exists. The tool was reporting its own assumption that a floor has exactly one hazard.
	# GROUPED BY CONTIGUITY, not by host room (corrected again 2026-09-08). Grouping by room was
	# right while every hazard was a crossing, and wrong the moment the Arena authored three
	# SEPARATE clusters inside one space -- merging those produced a single lane covering ground
	# that is mostly safe, and then measured a crossing of it. Pads that touch are one hazard.
	var lanes: Dictionary = {}
	var pads_of: Dictionary = {}
	var groups: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		var merged: bool = false
		for g in groups.size():
			if (groups[g] as Rect2).grow(0.5).intersects(pad.rect):
				groups[g] = (groups[g] as Rect2).merge(pad.rect)
				merged = true
				break
		if not merged:
			groups.append(pad.rect)
	for g in groups.size():
		lanes[g] = groups[g]
		pads_of[g] = 0
		for pad: SpikePadPlan in plan.spike_pads:
			if (groups[g] as Rect2).grow(0.5).intersects(pad.rect):
				pads_of[g] += 1
	print("SPIKE LANE CROSSINGS -- %d hazard lane(s)" % lanes.size())
	var lane_ids: Array = lanes.keys()
	lane_ids.sort()
	for lane_id: int in lane_ids:
		_measure(plan, envoy, lane_id, lanes[lane_id], int(pads_of[lane_id]))
	return


func _measure(plan: FloorPlan, envoy: Resource, lane_id: int, lane: Rect2, pad_count: int) -> void:
	print("")
	print("HAZARD GROUP %d" % lane_id)
	print("   lane %s  (%d pads)   envoy speed %.2f  radius %.2f" % [
		lane, pad_count, envoy.move_speed, envoy.combat_radius])

	var sim: Object = load("res://game/sim/sim_world.gd").new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	sim.register_obstacles(plan.obstacle_rects())
	for connection: TraversalConnection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)

	# THE CROSSING AXIS IS DERIVED, NOT ASSUMED. The first version always walked north-to-south
	# and silently produced nothing when a lane was crossed east-to-west -- an instrument that
	# only works on one floor's orientation is an instrument that will lie on the next one.
	# Travel runs along the LONGER axis of the space the lane sits in, which is the direction the
	# lane is a barrier across.
	var host: Rect2 = Rect2()
	for patch: WalkablePatch in plan.patches:
		if patch.rect.intersection(lane).get_area() > 0.0 and patch.rect.get_area() > host.get_area():
			host = patch.rect
	var along_x: bool = host.size.x >= host.size.y
	var clearance: float = envoy.combat_radius + 0.1
	var start: Vector3
	var direction: Vector3
	var finish: float
	if along_x:
		start = Vector3(lane.end.x + clearance, 0.0, lane.get_center().y)
		direction = Vector3(-1, 0, 0)
		finish = lane.position.x - clearance
	else:
		start = Vector3(lane.get_center().x, 0.0, lane.end.y + clearance)
		direction = Vector3(0, 0, -1)
		finish = lane.position.y - clearance
	sim.add_entity(PLAYER, start, envoy.move_speed, direction, envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	print("   host space %s -> crossing runs along %s" % [host, "x" if along_x else "z"])
	print("   commit from %s, clear at %s=%.2f" % [start, "x" if along_x else "z", finish])

	var ticks: int = 0
	for tick in 600:
		var here: float = sim.entities[PLAYER].x if along_x else sim.entities[PLAYER].z
		if here <= finish:
			ticks = tick
			break
		sim.tick([Command.new(sim.tick_count, PLAYER, "move", {"direction": direction})] as Array[Command], DT)
	if ticks == 0:
		print("   REFUSING TO REPORT: the crossing never completed -- the walk is obstructed, so")
		print("   this would be measuring geometry rather than cadence. Final %s" % sim.entities[PLAYER])
		quit(1)
		return

	print("")
	print("   CROSSING TOOK %d ticks (%.2f s)" % [ticks, ticks * DT])
	for slack in [0.20, 0.25]:
		print("   with %.0f%% grace -> SAFE_TICKS must be at least %d" % [slack * 100.0, ceili(ticks * (1.0 + slack))])
	print("")
	var phases: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		if not lane.intersects(pad.rect):
			continue
		print("   authored today: safe %d / active %d per pad" % [pad.safe_ticks, pad.active_ticks])
		phases.append(pad.phase_offset_ticks)
		break
	for pad: SpikePadPlan in plan.spike_pads:
		if lane.intersects(pad.rect) and phases.size() < pad_count:
			phases.append(pad.phase_offset_ticks)
	print("   phase offsets: %s" % str(phases))
	if phases.size() > 1 and phases.min() != phases.max():
		print("   NOTE: the pads are OUT OF PHASE, so this lane is never wholly safe at once --")
		print("   no safe window can satisfy the crossing law while that holds.")
	quit(0)
