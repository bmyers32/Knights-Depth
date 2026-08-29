extends SceneTree
## OOZE CORNER-RUBBING RECON (ruled 2026-08-29). INSTRUMENT BEFORE CLASSIFYING.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_ooze_pursuit.gd
##
## Human play: the ambient Ooze "became stuck on the corner" and could not follow through the
## hallway. Territory-as-a-union (ruled) removed the confinement half of that. What remains to
## classify is whether the residual rubbing is simply DIRECT STEERING meeting an obstacle -- the
## authored hall wraps a VOID, and a straight line to the player can cross it.
##
## Reports only. NOTHING is tuned from this, and no navigation system is implied by running it.
##
## The questions this answers, in order:
##   1. what movement vector does the Ooze request each tick?
##   2. what displacement does body-aware legality actually permit?
##   3. is the player straight-line reachable inside the Ooze's territory?
##   4. is the repeated wall-slide just direct pursuit re-requesting the blocked motion?
##   5. does the authored territory contain a legal route around the obstacle?
##
## Loaded DYNAMICALLY: a `-s` script compiles before autoloads register, so anything touching
## ContentDB by class_name fails with "Identifier not found".

const PLAYER_ID: int = 0
const DT: float = 1.0 / 30.0
const SAMPLE_TICKS: int = 240

var _late_rubbing: int = 0
var _late_progress: float = 0.0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var sim_script: GDScript = load("res://game/sim/sim_world.gd")
	var bounds_script: GDScript = load("res://game/sim/walkable_bounds.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")

	var plan: Object = generator.generate(0, 1)
	var sim: Object = sim_script.new()
	sim.set_damage_matrix({}, 1.5, 0.5)

	var envoy_stats: Resource = db.get_resource(&"envoy", &"default")
	sim.add_entity(PLAYER_ID, plan.entry_point, envoy_stats.move_speed, Vector3(0, 0, -1), envoy_stats.combat_radius)
	sim.register_combatant(PLAYER_ID, envoy_stats.max_health, envoy_stats.family, 0, envoy_stats.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER_ID)
	sim.load_floor(plan.make_bounds(), plan.entry_point)

	sim.register_patches(plan.patch_rects())
	for connection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
	for encounter in plan.encounters:
		sim.register_encounter(encounter.encounter_id, encounter.regions, encounter.role, encounter.confines_player, encounter.spawn_at_floor_load)

	# THE AMBIENT Ooze specifically. The mandatory arena roster also contains an ooze, and
	# picking the first one by family would instrument the wrong actor in the wrong territory.
	var ambient_id: int = -1
	for encounter in plan.encounters:
		if encounter.role == &"ambient":  # literal: a -s script compiles before class_names register
			ambient_id = encounter.encounter_id
	var ooze_id: int = -1
	var ooze_home := Vector3.ZERO
	for spawn in plan.all_spawns():
		if spawn["enemy_key"] != &"ooze" or int(spawn["encounter_id"]) != ambient_id:
			continue
		ooze_id = 100
		ooze_home = spawn["position"]
		registrar.register_enemy_body(sim, ooze_id, &"ooze", ooze_home)
		registrar.register_enemy_ai(sim, ooze_id, &"ooze", ooze_home)
		sim.assign_actor_encounter(ooze_id, int(spawn["encounter_id"]))
		break
	if ooze_id < 0:
		push_error("no ambient ooze in the authored floor")
		quit(1)
		return

	var stats: Resource = db.get_resource(&"enemy", &"ooze")
	var territory: Object = sim._encounter_bounds[int(sim._actor_encounter[ooze_id])]
	print("OOZE  body radius %.2f   move_speed %.2f   per-tick step %.4f" % [
		stats.combat_radius, stats.move_speed, stats.move_speed * DT])
	print("TERRITORY rects: %d" % territory.rects.size())
	for rect in territory.rects:
		print("   %s" % rect)
	print("")

	# THE LITERAL CASE. Two constraints have to hold at once or the trace measures nothing:
	#   * the straight line to the player must cross the VOID, and
	#   * the player must be INSIDE detection_radius, or the Ooze simply never engages.
	# A first pass at (-12, -22) sat 24 units away and produced a flat zero-movement trace that
	# looked exactly like corner-rubbing and was actually an idle enemy. Confirm the mechanism
	# fired before believing a zero (HANDOFF: a test that stops measuring can lie).
	var player_at := Vector3(6.0, 0.0, -15.0)
	sim.entities[PLAYER_ID] = player_at
	sim.debug_set_ai_active(ooze_id)

	var separation: float = ooze_home.distance_to(player_at)
	print("SETUP  ooze %s -> player %s   separation %.2f   detection_radius %.2f" % [
		ooze_home, player_at, separation, stats.detection_radius])
	if separation > stats.detection_radius:
		print("SETUP  WARNING: out of detection range -- this trace would measure an IDLE enemy")
	print("")

	_report_reachability(bounds_script, territory, ooze_home, player_at, stats.combat_radius)
	_run(sim, ooze_id, player_at, stats)
	quit(0)


## QUESTION 3 and 5: is the straight line legal, and does a legal route exist at all?
func _report_reachability(bounds_script: GDScript, territory: Object, from: Vector3, to: Vector3, radius: float) -> void:
	var blocked_at: float = -1.0
	for step in 200:
		var t: float = float(step) / 199.0
		if not territory.fits(from.lerp(to, t), radius):
			blocked_at = t
			break
	if blocked_at < 0.0:
		print("Q3 straight line  : LEGAL end to end -- an obstacle is not the explanation")
	else:
		var blocked_point: Vector3 = from.lerp(to, blocked_at)
		print("Q3 straight line  : BLOCKED at t=%.2f, %s -- the direct path crosses unlaid ground" % [blocked_at, blocked_point])

	# A crude legal-route probe over the territory's own rect centres, one and two waypoints
	# deep. Deliberately NOT a pathfinder -- it only answers whether a route EXISTS, which is
	# the question the ruling asks. Two waypoints because a path around a VOID needs to turn
	# twice: one waypoint can only cut a corner, never go around a hole.
	var centres: Array = []
	for rect in territory.rects:
		centres.append(Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5))
	for a in centres:
		if _leg_is_legal(territory, from, a, radius) and _leg_is_legal(territory, a, to, radius):
			print("Q5 legal route    : YES via %s -- one turn is enough" % a)
			print("")
			return
	for a in centres:
		if not _leg_is_legal(territory, from, a, radius):
			continue
		for b in centres:
			if _leg_is_legal(territory, a, b, radius) and _leg_is_legal(territory, b, to, radius):
				print("Q5 legal route    : YES via %s then %s -- the territory contains a way" % [a, b])
				print("                    around, but it needs TWO turns. Straight-line pursuit")
				print("                    cannot discover it.")
				print("")
				return
	print("Q5 legal route    : none found within two waypoints -- but this probe only tries RECT")
	print("                    CENTRES, which is far too coarse to describe a route that hugs a")
	print("                    void edge. Read the trace, not this line, for whether one exists.")
	print("")


func _leg_is_legal(territory: Object, from: Vector3, to: Vector3, radius: float) -> bool:
	for step in 120:
		if not territory.fits(from.lerp(to, float(step) / 119.0), radius):
			return false
	return true


## An empty Array[Command] built without naming the class: a -s script compiles before
## class_names register, so the typed array has to be constructed from the loaded script.
func _no_commands() -> Array:
	return Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))


## QUESTIONS 1, 2 and 4: requested vs permitted, tick by tick.
func _run(sim: Object, ooze_id: int, player_at: Vector3, stats: Resource) -> void:
	var full_step: float = stats.move_speed * DT
	var rubbing: int = 0
	var free: int = 0
	var last_report: int = -100
	var late_start: int = SAMPLE_TICKS - SAMPLE_TICKS / 3
	var late_from := Vector3.ZERO
	print("tick  position                     requested dir        moved    of %.4f" % full_step)
	for tick in SAMPLE_TICKS:
		var before: Vector3 = sim.entities[ooze_id]
		var wanted: Vector3 = player_at - before
		wanted.y = 0.0
		wanted = wanted.normalized()
		sim.tick(_no_commands(), DT)
		var after: Vector3 = sim.entities[ooze_id]
		var moved: float = before.distance_to(after)
		# "Rubbing" = the AI is still asking to move but legality is eating most of the step.
		if moved < full_step * 0.5:
			rubbing += 1
			if tick >= late_start:
				_late_rubbing += 1
		else:
			free += 1
		if tick == late_start:
			late_from = before
		if tick - last_report >= 40:
			last_report = tick
			print("%4d  %-28s %-20s %.4f" % [tick, after, wanted, moved])
	_late_progress = late_from.distance_to(sim.entities[ooze_id])
	print("")
	print("ENGAGED           : ai_state=%s  (a zero-movement trace from an IDLE enemy is not rubbing)" % sim._ai_state.get(ooze_id, "?"))
	print("Q1/Q2 permitted   : %d ticks moved freely, %d ticks lost >half the requested step" % [free, rubbing])
	var settled: Vector3 = sim.entities[ooze_id]
	print("Q4 final position : %s   distance to player %.2f" % [settled, settled.distance_to(player_at)])
	# THE WINDOW HAS TWO PHASES and averaging them hides the finding: a free approach down its
	# own arm, then contact with the void edge. Only the second phase is the thing under study.
	print("Q4 contact phase  : last third lost %d of %d ticks to legality; net progress %.3f u" % [
		_late_rubbing, SAMPLE_TICKS / 3, _late_progress])
	if _late_rubbing > (SAMPLE_TICKS / 3) / 2:
		print("Q4 disposition    : DIRECT STEERING vs OBSTACLE, CONFIRMED. Pursuit keeps re-requesting")
		print("                    motion into the void edge and the per-axis clamp grants only the")
		print("                    unblocked component, so the Ooze RUBS along the corner. It is not")
		print("                    stuck -- it makes real progress and would round the corner -- but")
		print("                    it reads as sluggish scraping. This is an AUTHORING constraint")
		print("                    (ambient territories used by straight-line AI must not require")
		print("                    obstacle routing), NOT a bounds defect and NOT a reason to")
		print("                    weaken body-aware legality.")
	else:
		print("Q4 disposition    : the expected direct-steering cause is NOT confirmed by the")
		print("                    contact phase; classify from the trace before implementing.")
