extends SceneTree
## DOES A CLOSED GATE ACTUALLY STOP A SHOT? (Floor 2 diagnosis, 2026-09-02)
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/probe_gate_barrier_axis.gd
##
## SimWorld._gate_segment derives the barrier's axis from the aperture's PROPORTIONS, assuming
## travel runs along the aperture's longer dimension. FloorBuilder always draws the barrier box
## across x. Those two rules agree only for corridor-shaped apertures. This asks the sim
## directly, per P34's law that sim and presentation must read ONE boundary fact.
##
## Reports only.

const DT: float = 1.0 / 30.0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var L: GDScript = load("res://game/gen/layouts/archive_roundabout.gd")
	var sim_script: GDScript = load("res://game/sim/sim_world.gd")
	var plan: FloorPlan = generator.generate(0, 2)

	print("CLOSED-GATE BARRIER ORIENTATION")
	for connection: TraversalConnection in plan.connections:
		if connection.starts_open:
			continue
		var a: Rect2 = connection.aperture
		# TRAVEL IS THE AXIS THAT CARRIES THE GAP, not the axis of greatest centre separation.
		# Comparing centres ties whenever a route is offset laterally, and the first version of
		# this tool reported a healthy gate as broken on exactly that tie. An instrument must be
		# shown to measure what it claims.
		var near: Rect2 = plan.patch_by_id(connection.patch_ids.x).rect
		var far: Rect2 = plan.patch_by_id(connection.patch_ids.y).rect
		var travel_axis: StringName = &"z" if (near.end.y < far.position.y or far.end.y < near.position.y) else &"x"
		# The sim's own rule, restated: barrier axis follows the aperture's LONGER dimension.
		var sim_axis: StringName = &"z" if a.size.y >= a.size.x else &"x"
		print("   connection %d  aperture %.0f x %.0f   travel runs along %s   sim barrier axis %s  -> %s" % [
			connection.connection_id, a.size.x, a.size.y, travel_axis, sim_axis,
			"AGREES" if sim_axis == travel_axis else "PERPENDICULAR TO TRAVEL -- shots pass through"])
	print("")

	# THE BEHAVIOURAL PROOF: stand in the concourse, shoot north at the shut shortcut.
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var envoy: Resource = db.get_resource(&"envoy", &"default")
	var sim: Object = sim_script.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	sim.register_solid_segments(plan.solid_segments())
	for connection: TraversalConnection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)

	# Shooter just south of the shut gate; a target sitting beyond it in the sealed route.
	var shooter := Vector3(-22.0, 0.0, -45.0)
	var target := Vector3(-22.0, 0.0, -50.0)
	sim.add_entity(0, shooter, 0.0, Vector3(0, 0, -1), 0.0)
	sim.register_combatant(0, 999.0, &"envoy", 0, 0.0, &"player")
	sim.debug_place_actor(1, target) if sim.has_method("debug_place_actor") else null
	sim.add_entity(1, target, 0.0)
	sim.register_combatant(1, 100.0, &"fang", 0, 0.9, &"enemy")
	sim.register_gun(&"probe_gun", 10.0, &"force", 30.0, 600, 0.2, 0.0, 1)
	sim.set_equipped_weapon(0, &"probe_gun")

	var empty: Array = Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))
	var hit: bool = false
	for event in sim.tick([Command.new(sim.tick_count, 0, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT):
		hit = hit or event.kind == "hit"
	for tick in 90:
		for event in sim.tick(empty, DT):
			hit = hit or event.kind == "hit"
	print("BEHAVIOURAL PROOF: shot fired north through the SHUT shortcut gate (C_TO_A)")
	print("   target beyond the gate was %s" % ("HIT -- the closed gate did not stop it" if hit else "not hit; the gate stopped the shot"))
	quit(0)
