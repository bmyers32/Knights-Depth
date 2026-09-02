extends SceneTree
## FLOOR 2 DEFECT REPRODUCTION — a CLOSED connection that separates nothing.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/reproduce_gate_bypass.gd
##
## THE CLAIM UNDER TEST: closing C_TO_A prevents reaching ROUTE A. Measured against the
## authoritative walkable union and the real move Command, not against the gate's own state
## flag -- `_connection_open == false` says only that the gate is shut, never that it separates
## anything, and that is precisely the gap the human found.
##
## Reports only. No geometry is authored from this run.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	# LOADED DYNAMICALLY, not by class_name: a `-s` script compiles before the autoloads exist,
	# and depth_generator.gd names ContentDB. Same established pattern as the golden recorder.
	var L: GDScript = load("res://game/gen/layouts/archive_roundabout.gd")
	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var plan: FloorPlan = generator.generate(0, 2)
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var envoy: Resource = db.get_resource(&"envoy", &"default")
	var radius: float = envoy.combat_radius

	print("FLOOR 2 CLOSED-GATE BYPASS REPRODUCTION")
	print("   envoy body radius %.2f" % radius)
	print("")

	for connection: TraversalConnection in plan.connections:
		if connection.starts_open:
			continue
		_report_gate(plan, connection, radius)

	# And the behavioural proof: walk it.
	_walk_proof(plan, envoy, L)
	quit(0)


## Which authored patches does this aperture claim to join, and do those patches touch each
## other WITHOUT it? An aperture is only load-bearing when the patches it joins are disjoint.
func _report_gate(plan: FloorPlan, connection: TraversalConnection, radius: float) -> void:
	var aperture: Rect2 = connection.aperture
	var joined: Array[int] = []
	for patch: WalkablePatch in plan.patches:
		if patch.rect.intersects(aperture) and patch.rect.intersection(aperture).get_area() > 0.0:
			joined.append(patch.patch_id)
	print("CONNECTION %d  aperture %s  CLOSED" % [connection.connection_id, aperture])
	print("   claims to join patches %s" % str(joined))
	if joined.size() < 2:
		print("   (fewer than two patches -- nothing to say)")
		print("")
		return

	# THE UNION AS THE SIM ACTUALLY BUILDS IT WITH THIS GATE SHUT: every patch, plus every
	# OTHER aperture that is open. Exactly _rebuild_regions.
	var closed_rects: Array[Rect2] = []
	for patch: WalkablePatch in plan.patches:
		closed_rects.append(patch.rect)
	for other: TraversalConnection in plan.connections:
		if other.connection_id != connection.connection_id and other.starts_open:
			closed_rects.append(other.aperture)
	var bounds: Object = load("res://game/sim/walkable_bounds.gd").new(closed_rects)

	# Sample the seam between the two patches, OUTSIDE the aperture's own span, and ask the
	# authoritative predicate whether a body may legally stand there.
	var a: Rect2 = plan.patch_by_id(joined[0]).rect
	var b: Rect2 = plan.patch_by_id(joined[1]).rect
	var legal_outside: Array[Vector3] = []
	var legal_total: int = 0
	var seam_z: float = maxf(minf(a.end.y, b.end.y), minf(a.position.y, b.position.y))
	var lo: float = maxf(a.position.x, b.position.x)
	var hi: float = minf(a.end.x, b.end.x)
	var samples: int = 400
	for s in samples + 1:
		var x: float = lo + (hi - lo) * float(s) / float(samples)
		var point := Vector3(x, 0.0, seam_z)
		if not bounds.fits(point, radius):
			continue
		legal_total += 1
		if not bounds.contains(aperture, x, seam_z):
			legal_outside.append(point)
	print("   the two patches share the seam z=%.1f over x[%.1f, %.1f]" % [seam_z, lo, hi])
	print("   body-legal seam samples: %d of %d   OUTSIDE the aperture span: %d" % [
		legal_total, samples + 1, legal_outside.size()])
	if legal_total == 0:
		print("   VERDICT: the gate is LOAD-BEARING -- no legal crossing exists while it is shut.")
	elif legal_outside.is_empty():
		print("   VERDICT: crossings exist but ALL lie inside the aperture span.")
	else:
		print("   VERDICT: BYPASS. A body may legally cross at x=%.2f .. %.2f, outside the" % [
			legal_outside[0].x, legal_outside[-1].x])
		print("            blocking span entirely. The closed gate separates NOTHING.")
	print("")


## Behavioural proof through the real driver: boot depth 2, never touch the control, walk south.
func _walk_proof(plan: FloorPlan, envoy: Resource, L: GDScript) -> void:
	var sim: Object = load("res://game/sim/sim_world.gd").new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(PLAYER, plan.entry_point, envoy.move_speed, Vector3(0, 0, -1), envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	for connection: TraversalConnection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)

	var route_a: Rect2 = plan.patch_by_id(L.P_ROUTE_A).rect
	var empty: Array = Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))
	# Straight to the middle of route A, never going near the control plate.
	var target := Vector3(-21.0, 0.0, -54.0)
	for tick in 3000:
		var position: Vector3 = sim.entities[PLAYER]
		if position.x >= route_a.position.x and position.x <= route_a.end.x and position.z >= route_a.position.y and position.z <= route_a.end.y:
			print("BEHAVIOURAL PROOF: the Envoy stood INSIDE ROUTE A at %s on tick %d" % [position, tick])
			print("   with C_TO_A still %s and the control plate never touched." % (
				"OPEN" if bool(sim._connection_open[L.C_TO_A]) else "CLOSED"))
			print("   The gated shortcut is not gated.")
			return
		var direction: Vector3 = target - position
		direction.y = 0.0
		if direction.length() < 0.3:
			break
		sim.tick([Command.new(sim.tick_count, PLAYER, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	print("BEHAVIOURAL PROOF: the Envoy never entered route A. Final %s" % sim.entities[PLAYER])
