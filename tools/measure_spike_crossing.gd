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

	# Start with the body fully clear on the NORTH side, and finish fully clear on the SOUTH.
	var start := Vector3(lane.get_center().x, 0.0, lane.end.y + envoy.combat_radius + 0.1)
	var finish_z: float = lane.position.y - envoy.combat_radius - 0.1
	sim.add_entity(PLAYER, start, envoy.move_speed, Vector3(0, 0, -1), envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	print("   commit from %s, clear at z=%.2f  (%.1f units of travel)" % [start, finish_z, start.z - finish_z])

	var ticks: int = 0
	for tick in 600:
		if sim.entities[PLAYER].z <= finish_z:
			ticks = tick
			break
		sim.tick([Command.new(sim.tick_count, PLAYER, "move", {"direction": Vector3(0, 0, -1)})] as Array[Command], DT)
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
