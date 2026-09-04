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

	# The hazard lane is the union of every pad that shares the crossing.
	var lane: Rect2 = plan.spike_pads[0].rect
	for pad: SpikePadPlan in plan.spike_pads:
		lane = lane.merge(pad.rect)
	print("SPIKE LANE CROSSING")
	print("   lane %s  (%d pads merged)   envoy speed %.2f  radius %.2f" % [
		lane, plan.spike_pads.size(), envoy.move_speed, envoy.combat_radius])

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
	print("   authored today: safe %d / active %d per pad" % [
		plan.spike_pads[0].safe_ticks, plan.spike_pads[0].active_ticks])
	var phases: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		phases.append(pad.phase_offset_ticks)
	print("   phase offsets: %s" % str(phases))
	if phases.size() > 1 and phases.min() != phases.max():
		print("   NOTE: the pads are OUT OF PHASE, so this lane is never wholly safe at once --")
		print("   no safe window can satisfy the crossing law while that holds.")
	quit(0)
