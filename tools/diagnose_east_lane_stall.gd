extends SceneTree
## THE ACTUAL SCREENSHOT STALL — east vertical lane (human replay of ef81219 / 69016ee).
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_east_lane_stall.gd
##
## THE IMAGE ITSELF DID NOT REACH THIS SESSION. Working from the description: "the long
## right-hand vertical lane near the upper section, with the Ooze immediately north of the Envoy
## in apparently continuous traversable space."
##
## MAPPED TO AUTHORED GEOMETRY, not to pixels: the long right-hand vertical lane is P_HALL_EAST,
## Rect2(8, -30, 8, 16) -> x[8,16], z[-30,-14]. "Upper section" is the northern end, z ~ -14..-20.
## "Immediately north of the Envoy" puts the Ooze at a smaller |z| than the player, both inside
## the arm, with no wall or void between them. That is the Ooze's OWN home territory.
##
## THE PRECONDITION IS ASSERTED, NOT ASSUMED. This project has now three times measured an idle
## or disengaged actor and read it as a navigation failure. If the pursuit mechanism is not
## actually live, this tool REFUSES to produce a movement verdict.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0
const OOZE: int = 100
const EAST_ARM := Rect2(8.0, -30.0, 8.0, 16.0)


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var sim_script: GDScript = load("res://game/sim/sim_world.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var plan: Object = generator.generate(0, 1)
	var stats: Resource = db.get_resource(&"enemy", &"ooze")

	var sim: Object = sim_script.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var envoy: Resource = db.get_resource(&"envoy", &"default")
	sim.add_entity(PLAYER, plan.entry_point, envoy.move_speed, Vector3(0, 0, -1), envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	sim.register_solid_segments(plan.solid_segments())
	for connection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
	for encounter in plan.encounters:
		sim.register_encounter(encounter.encounter_id, encounter.regions, encounter.role, encounter.confines_player, encounter.spawn_at_floor_load)

	var ambient_id: int = -1
	for encounter in plan.encounters:
		if encounter.role == &"ambient":
			ambient_id = encounter.encounter_id
	for spawn in plan.all_spawns():
		if spawn["enemy_key"] != &"ooze" or int(spawn["encounter_id"]) != ambient_id:
			continue
		registrar.register_enemy_body(sim, OOZE, &"ooze", spawn["position"])
		registrar.register_enemy_ai(sim, OOZE, &"ooze", spawn["position"])
		sim.assign_actor_encounter(OOZE, ambient_id)
		break

	# THE SCREENSHOT RELATIONSHIP: both in the east lane, Ooze immediately NORTH of the Envoy.
	var ooze_at := Vector3(12.0, 0.0, -17.0)
	var player_at := Vector3(12.0, 0.0, -19.0)
	sim.entities[OOZE] = ooze_at
	sim.entities[PLAYER] = player_at
	sim.tick(_no_commands(), DT)  # let acquisition run naturally

	if not _precondition(sim, stats, ooze_at, player_at):
		print("")
		print("REFUSING TO PRODUCE A MOVEMENT VERDICT: the pursuit mechanism is not live in this")
		print("state, so any displacement number below would answer a different question.")
		quit(1)
		return

	_trace(sim, stats, player_at)
	quit(0)


## THE ACTUAL COMPLAINT was that it "would not proceed farther despite facing/following the
## player" -- which is about FOLLOWING, not about a frozen tableau. So the second phase walks the
## player away up the lane, the way a human retreating would, and asks whether pursuit keeps up.
func _following_phase(sim: Object, stats: Resource) -> void:
	print("")
	print("FOLLOWING PHASE — player retreats NORTH up the lane at walking pace:")
	var player: Vector3 = sim.entities[PLAYER]
	var start: Vector3 = sim.entities[OOZE]
	var legs: int = 0
	var moves: int = 0
	for t in 400:
		# The observation is about MOVEMENT, so the player is kept alive on purpose. Letting a
		# 30 HP Envoy die mid-measurement silently converts this into a corpse test.
		sim.debug_override_health(PLAYER, 5000.0)
		var before: Vector3 = sim.entities[OOZE]
		for event in sim.tick(_no_commands(), DT):
			if event.kind == "cardinal_leg_committed":
				legs += 1
				if legs <= 6:
					print("   leg%d heading=%s at %s gap=%.2f" % [legs, event.payload["heading"],
						sim.entities[OOZE], sim.entities[OOZE].distance_to(sim.entities[PLAYER])])
		if before.distance_to(sim.entities[OOZE]) > 0.0001:
			moves += 1
		# Retreat north, staying inside the lane, stopping at its north end.
		player.z = minf(player.z + 0.04, -15.0)
		sim.entities[PLAYER] = player
		if t % 100 == 0:
			# WHY is it not moving? Print the gates the movement clause sits behind.
			print("   t%3d ooze=%s player=%s gap=%.2f | windup=%s fire_tick=%s next_fire=%s burrow=%s absent=%s" % [
				t, sim.entities[OOZE], player, sim.entities[OOZE].distance_to(player),
				sim._ai_attack_start_tick.has(OOZE), sim._ai_attack_fire_tick.has(OOZE),
				sim._next_fire_tick.get(OOZE, "-"), sim._burrow.has(OOZE), sim._combat_absent.has(OOZE)])
	print("   NET %.2f u   moved on %d/400 ticks   legs committed %d   final gap %.2f" % [
		start.distance_to(sim.entities[OOZE]), moves, legs, sim.entities[OOZE].distance_to(player)])

	# DIRECT PROBE of the chooser, so the failure is located rather than inferred.
	var region: Object = sim._legal_bounds_for(OOZE)
	var radius: float = stats.combat_radius
	var from: Vector3 = sim.entities[OOZE]
	print("")
	print("CHOOSER PROBE from %s to %s" % [from, player])
	print("   PLAYER HEALTH %.1f   living player id = %d" % [
		sim._health.get(PLAYER, -1.0), sim._find_living_player_id()])
	print("   dx=%.2f dz=%.2f  align_tolerance=%.2f  probe=%.2f" % [
		player.x - from.x, player.z - from.z, sim._CARDINAL_ALIGN_TOLERANCE, sim._CARDINAL_PROBE])
	print("   _choose_cardinal_leg -> %s" % sim._choose_cardinal_leg(from, player, region, radius))
	print("   north 1.0 legal? %s   south 1.0 legal? %s" % [
		region.fits(from + Vector3(0, 0, 1.0), radius), region.fits(from + Vector3(0, 0, -1.0), radius)])
	print("   ooze territory rects: %s" % [region.rects])


func _no_commands() -> Array:
	return Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))


## ASSERTS the mechanism under test is actually running. Returns false loudly rather than
## letting a verdict be drawn from an idle actor.
func _precondition(sim: Object, stats: Resource, ooze_at: Vector3, player_at: Vector3) -> bool:
	var separation: float = ooze_at.distance_to(player_at)
	var state: String = str(sim._ai_state.get(OOZE, "?"))
	var spawn: Vector3 = sim._ai_spawn_position.get(OOZE, Vector3.ZERO)
	var leash_distance: float = spawn.distance_to(player_at)
	print("PRECONDITION")
	print("   ooze %s   player %s   separation %.2f" % [ooze_at, player_at, separation])
	print("   ai_state=%s   language=%s" % [state, sim._ai_tuning.get(OOZE, {}).get("pursuit_language", "?")])
	print("   detection_radius %.2f  -> acquisition %s" % [stats.detection_radius,
		"OK" if leash_distance <= stats.detection_radius else "FAILS (spawn->player %.2f)" % leash_distance])
	print("   leash_radius %.2f      -> engagement %s" % [stats.leash_radius,
		"OK" if leash_distance <= stats.leash_radius else "DISENGAGES (spawn->player %.2f)" % leash_distance])
	print("   attack band: minimum %.2f  preferred %.2f" % [stats.minimum_attack_distance, stats.preferred_attack_distance])
	var in_band: bool = separation >= stats.minimum_attack_distance and separation <= stats.preferred_attack_distance
	print("   separation is %s the movement band" % ("INSIDE" if in_band else "outside"))
	# THE PLAYER MUST BE ALIVE, and must STAY alive: "no living player -> enemies stop acting
	# entirely" is a locked law, so a corpse produces a perfect zero that looks like a stall.
	# This was the FOURTH time this project measured a world where the mechanism could not run.
	print("   player health %.1f -> living player id %d" % [sim._health.get(PLAYER, -1.0), sim._find_living_player_id()])
	var ok: bool = state == "active" and sim._find_living_player_id() == PLAYER
	print("   -> mechanism live: %s" % ("YES" if ok else "NO"))
	print("")
	return ok


func _trace(sim: Object, stats: Resource, player_at: Vector3) -> void:
	var region: Object = sim._legal_bounds_for(OOZE)
	var radius: float = stats.combat_radius
	var from: Vector3 = sim.entities[OOZE]
	print("STATE AT THE STALL")
	print("   obstruction to player : %s" % sim._direct_route_obstruction(OOZE, player_at))
	print("   legal region rects    : %d" % region.rects.size())
	print("   cardinal heading held : %s" % sim._ai_cardinal_heading.get(OOZE, "none"))
	print("   direct line clear?    : %s" % ("YES" if sim._direct_route_obstruction(OOZE, player_at).is_empty() else "no"))
	# Is a plain cardinal route available from here?
	var south: Vector3 = Vector3(0.0, 0.0, -1.0)
	var west: Vector3 = Vector3(-1.0, 0.0, 0.0)
	print("   one body south legal? : %s" % region.fits(from + south * 1.5, radius))
	print("   one body west legal?  : %s" % region.fits(from + west * 1.5, radius))
	print("")

	print("MOVEMENT over 240 ticks (player stationary, as in the screenshot):")
	sim.debug_override_health(PLAYER, 5000.0)
	var start: Vector3 = from
	var attacks: int = 0
	var moves: int = 0
	for t in 240:
		var before: Vector3 = sim.entities[OOZE]
		sim.debug_override_health(PLAYER, 5000.0)
		for event in sim.tick(_no_commands(), DT):
			if event.kind == "attack_telegraph":
				attacks += 1
		if before.distance_to(sim.entities[OOZE]) > 0.0001:
			moves += 1
		if t % 60 == 0:
			print("   t%3d  %s  gap=%.2f" % [t, sim.entities[OOZE], sim.entities[OOZE].distance_to(player_at)])
	print("   NET DISPLACEMENT %.2f u   ticks with movement %d/240   telegraphs %d" % [
		start.distance_to(sim.entities[OOZE]), moves, attacks])
	print("")
	if moves == 0 and attacks > 0:
		print("CLASSIFICATION: NOT A NAVIGATION STALL. The actor is inside its authored movement")
		print("   band and HOLDING while it attacks -- movement preference governs approach only")
		print("   (minimum/preferred distance), and holding there is the shipped AI law. It reads")
		print("   as stuck because a slow enemy at attack range simply stands still between swings.")
	elif moves == 0:
		print("CLASSIFICATION: silent stall -- engaged, not attacking, not moving. A real defect.")
	else:
		print("CLASSIFICATION: it moves, but barely -- essentially holding at attack range.")
	_following_phase(sim, stats)
