extends SceneTree
## ATTACK-BAND HOLD — is "facing/following the player while barely moving" the movement law?
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_attack_band_hold.gd
##
## THE HYPOTHESIS: the Ooze's movement band is minimum 1.90 to preferred 2.20 -- only 0.30 units
## wide. Movement preference governs APPROACH ONLY; an actor inside the band holds. So a player
## STRAFING LATERALLY around it stays inside that band the whole time, and the Ooze never
## translates while continuing to face and attack. That would read exactly as the human reported:
## following without moving.
##
## PRECONDITIONS ARE ASSERTED CONTINUOUSLY, not at tick 0 (banked lesson: four diagnostics in this
## project produced accurate numbers about a mechanism that was not running). Player health is
## held up every tick, and the run ABORTS the moment engagement or liveness lapses.
##
## Reports only. No value is tuned from this.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0
const OOZE: int = 1


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var stats: Resource = db.get_resource(&"enemy", &"ooze")
	print("OOZE BAND  minimum %.2f  preferred %.2f  -> hold band is %.2f units wide" % [
		stats.minimum_attack_distance, stats.preferred_attack_distance,
		stats.preferred_attack_distance - stats.minimum_attack_distance])
	print("           move_speed %.2f   body radius %.2f" % [stats.move_speed, stats.combat_radius])
	var slam: Resource = db.get_resource(&"natural_weapon", &"ooze_slam")
	print("           windup %d ticks (%.2f s)   fire interval %d ticks (%.2f s)" % [
		slam.windup_ticks, slam.windup_ticks * DT, slam.fire_interval_ticks, slam.fire_interval_ticks * DT])
	print("")

	_case("A  player STRAFES laterally at band distance (the reported case)", true, 2.05, stats)
	_case("B  player RETREATS straight back (control: should be chased)", false, 2.05, stats)
	quit(0)


func _no_commands() -> Array:
	return Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))


func _case(label: String, strafe: bool, band_distance: float, stats: Resource) -> void:
	var sim_script: GDScript = load("res://game/sim/sim_world.gd")
	var bounds_script: GDScript = load("res://game/sim/walkable_bounds.gd")
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")

	var sim: Object = sim_script.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	# A large open plain: nothing here can be blamed on geometry.
	var rects: Array[Rect2] = [Rect2(-40.0, -40.0, 80.0, 80.0)]
	sim.load_floor(bounds_script.new(rects), Vector3.ZERO)
	sim.register_patches(rects)

	var envoy: Resource = db.get_resource(&"envoy", &"default")
	sim.add_entity(PLAYER, Vector3(band_distance, 0.0, 0.0), envoy.move_speed, Vector3(-1, 0, 0), envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER)
	registrar.register_enemy_body(sim, OOZE, &"ooze", Vector3.ZERO)
	registrar.register_enemy_ai(sim, OOZE, &"ooze", Vector3.ZERO)
	sim.debug_set_ai_active(OOZE)

	var start: Vector3 = sim.entities[OOZE]
	var moved_ticks: int = 0
	var telegraphs: int = 0
	var angle: float = 0.0
	for t in 600:
		# CONTINUOUS PRECONDITION: a corpse or a disengaged actor produces a perfect zero that
		# looks exactly like the finding. Hold the player up and abort the moment it lapses.
		sim.debug_override_health(PLAYER, 5000.0)
		if sim._ai_state.get(OOZE, "") != "active":
			print("%s\n   ABORTED at tick %d: ai_state=%s -- mechanism no longer live\n" % [
				label, t, sim._ai_state.get(OOZE, "?")])
			return
		var before: Vector3 = sim.entities[OOZE]
		for event in sim.tick(_no_commands(), DT):
			if event.kind == "attack_telegraph":
				telegraphs += 1
		if before.distance_to(sim.entities[OOZE]) > 0.0001:
			moved_ticks += 1
		if strafe:
			# Orbit the Ooze at a constant band distance -- lateral motion only.
			angle += 0.012
			var centre: Vector3 = sim.entities[OOZE]
			sim.entities[PLAYER] = centre + Vector3(cos(angle), 0.0, sin(angle)) * band_distance
		else:
			sim.entities[PLAYER] = sim.entities[PLAYER] + Vector3(0.02, 0.0, 0.0)

	var gap: float = sim.entities[OOZE].distance_to(sim.entities[PLAYER])
	print("%s" % label)
	print("   ooze translated %.2f u over 600 ticks, moving on %d/600 ticks" % [
		start.distance_to(sim.entities[OOZE]), moved_ticks])
	print("   telegraphs %d   final gap %.2f (band %.2f-%.2f)" % [
		telegraphs, gap, stats.minimum_attack_distance, stats.preferred_attack_distance])
	if moved_ticks < 30:
		print("   -> PLANTED. It faces and attacks without translating: the band hold, not a stall.")
	print("")
