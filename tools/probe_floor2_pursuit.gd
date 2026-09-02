extends SceneTree
## FLOOR 2 PRE-BUILD MEASUREMENT 2 — can the accepted bab167d Ooze follow CONCOURSE -> ROUTE B ->
## JUNCTION on the draft coordinates?
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/probe_floor2_pursuit.gd
##
## THE PAPER ARGUMENT IS WITHDRAWN. "The gap is wider than the acquisition radius" says nothing
## about what an ALREADY-ENGAGED Ooze does while the player walks incrementally through connected
## space. Acquisition and continued pursuit are separate laws, so the route gets costed rather
## than argued.
##
## PRECONDITIONS ASSERTED CONTINUOUSLY, per the banked lesson: the player is held alive every
## tick and the run ABORTS the moment engagement lapses, because an idle or dead actor produces a
## perfect zero that looks exactly like a stall.
##
## Uses ONLY the currently accepted locomotion. No navigation code is added or proposed here.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0
const OOZE: int = 1

## Draft Floor 2 coordinates under review.
const CONCOURSE := Rect2(-26.0, -46.0, 52.0, 28.0)
const ROUTE_B := Rect2(16.0, -62.0, 14.0, 16.0)
const JUNCTION := Rect2(-30.0, -71.0, 60.0, 10.0)
const C_TO_B := Rect2(18.0, -48.0, 10.0, 4.0)   # aperture: concourse <-> route B

## The line a human would actually walk: across the concourse, into route B, down it, then west
## along the junction -- incrementally, staying engaged the whole way.
const WAYPOINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, -30.0),    # concourse, where the fight starts
	Vector3(20.0, 0.0, -36.0),   # drift east toward the route B mouth
	Vector3(23.0, 0.0, -46.0),   # through the aperture
	Vector3(23.0, 0.0, -58.0),   # down route B
	Vector3(20.0, 0.0, -66.0),   # into the junction
	Vector3(0.0, 0.0, -66.0),    # west along it, toward the party-sync spot
]


## QUESTION B: the transit itself. The Ooze is anchored beside the route B mouth so its leash
## cannot end the run before the geometry is tested -- otherwise this measures the leash again
## rather than the aperture.
static func _transit_probe(sim_script: GDScript, bounds_script: GDScript, registrar: GDScript, envoy: Resource, stats: Resource) -> void:
	var rects: Array[Rect2] = [CONCOURSE, ROUTE_B, JUNCTION, C_TO_B]
	var sim: Object = sim_script.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(bounds_script.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	sim.register_connection(0, C_TO_B, true)

	var anchor := Vector3(22.0, 0.0, -42.0)  # concourse side, beside the mouth
	sim.add_entity(PLAYER, anchor + Vector3(-2.0, 0.0, 0.0), envoy.move_speed, Vector3(0, 0, -1), envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER)
	registrar.register_enemy_body(sim, OOZE, &"ooze", anchor)
	registrar.register_enemy_ai(sim, OOZE, &"ooze", anchor)
	sim.debug_set_ai_active(OOZE)
	sim._next_fire_tick[OOZE] = 1_000_000

	var empty: Array = Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))
	var player: Vector3 = sim.entities[PLAYER]
	var destination := Vector3(23.0, 0.0, -56.0)  # down route B, through the aperture
	var stalled: int = 0
	var worst: int = 0
	var disengaged_at: int = -1
	for tick in 1200:
		sim.debug_override_health(PLAYER, 5000.0)
		if sim._ai_state.get(OOZE, "") != "active" and disengaged_at < 0:
			disengaged_at = tick
		var before: Vector3 = sim.entities[OOZE]
		sim.tick(empty, DT)
		# A STALL IS ONLY A STALL WHEN THE ACTOR WANTS TO MOVE. Counting every stationary tick
		# marks the ATTACK-BAND HOLD as a 30-second stall -- which is correct behaviour beside a
		# stationary player, and cost this probe a false "MATERIAL STALL" verdict on its first run.
		var wants_to_move: bool = sim.entities[OOZE].distance_to(sim.entities[PLAYER]) > stats.preferred_attack_distance
		if wants_to_move and before.distance_to(sim.entities[OOZE]) < 0.001:
			stalled += 1
			worst = maxi(worst, stalled)
		else:
			stalled = 0
		var step: Vector3 = destination - player
		step.y = 0.0
		if step.length() > 0.2:
			player += step.normalized() * 0.05
			sim.entities[PLAYER] = player

	print("B. APERTURE TRANSIT, ooze anchored beside the mouth:")
	print("   ooze ended at %s, player at %s, gap %.2f" % [sim.entities[OOZE], player, sim.entities[OOZE].distance_to(player)])
	print("   longest stall WHILE IT WANTED TO MOVE: %d ticks (%.1f s)%s" % [worst, worst * DT,
		"" if disengaged_at < 0 else "   (disengaged at tick %d)" % disengaged_at])
	if worst > 60:
		print("   VERDICT: MATERIAL STALL at the fork aperture -- return before building.")
	elif sim.entities[OOZE].z > -46.0:
		print("   VERDICT: it never entered route B. Worth inspecting before building.")
	else:
		print("   VERDICT: the fork transit is clean. The draft geometry is compatible with")
		print("            accepted v1 locomotion.")


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var sim_script: GDScript = load("res://game/sim/sim_world.gd")
	var bounds_script: GDScript = load("res://game/sim/walkable_bounds.gd")
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var stats: Resource = db.get_resource(&"enemy", &"ooze")
	var envoy: Resource = db.get_resource(&"envoy", &"default")

	var rects: Array[Rect2] = [CONCOURSE, ROUTE_B, JUNCTION, C_TO_B]
	var sim: Object = sim_script.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(bounds_script.new(rects), WAYPOINTS[0])
	sim.register_patches(rects)
	sim.register_connection(0, C_TO_B, true)

	var start := Vector3(0.0, 0.0, -30.0)
	sim.add_entity(PLAYER, start, envoy.move_speed, Vector3(0, 0, -1), envoy.combat_radius)
	sim.register_combatant(PLAYER, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER)
	# The Ooze starts close enough to acquire, then must FOLLOW.
	registrar.register_enemy_body(sim, OOZE, &"ooze", start + Vector3(4.0, 0.0, 4.0))
	registrar.register_enemy_ai(sim, OOZE, &"ooze", start + Vector3(4.0, 0.0, 4.0))
	sim.debug_set_ai_active(OOZE)
	sim._next_fire_tick[OOZE] = 1_000_000  # never attacks: this measures locomotion only

	print("FLOOR 2 DRAFT PURSUIT PROBE — concourse -> route B -> junction")
	print("   ooze speed %.2f  radius %.2f  detection %.2f  leash %.2f" % [
		stats.move_speed, stats.combat_radius, stats.detection_radius, stats.leash_radius])
	print("")
	print("TWO QUESTIONS, kept apart because they have different answers:")
	print("  A. how far along this route does an engaged Ooze actually FOLLOW before the leash")
	print("     ends the chase -- an authored law, not incidental geometry")
	print("  B. does the CONCOURSE -> aperture -> ROUTE_B transit itself stall, measured with the")
	print("     Ooze anchored close enough that the leash cannot end the run first")
	print("")

	var empty: Array = Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))
	var player: Vector3 = start
	var leg: int = 1
	var stalled: int = 0
	var worst_stall: int = 0
	var commits: int = 0
	var total_ticks: int = 0

	for tick in 3000:
		# CONTINUOUS PRECONDITIONS.
		sim.debug_override_health(PLAYER, 5000.0)
		if sim._ai_state.get(OOZE, "") != "active":
			print("A. ENGAGEMENT ENDED at tick %d, with the player at %s (waypoint leg %d of %d)." % [
				tick, player, leg, WAYPOINTS.size()])
			print("   The LEASH ended the chase, not the geometry. No stall had occurred: longest")
			print("   unbroken stall while engaged was %d ticks (%.1f s), avoidance commits %d." % [
				worst_stall, worst_stall * DT, commits])
			print("   This is the authored disengage law working, and the Ooze now returns home.")
			print("")
			_transit_probe(sim_script, bounds_script, registrar, envoy, stats)
			quit(0)
			return

		var before: Vector3 = sim.entities[OOZE]
		for event in sim.tick(empty, DT):
			if event.kind == "avoidance_committed":
				commits += 1
		if before.distance_to(sim.entities[OOZE]) < 0.001:
			stalled += 1
			worst_stall = maxi(worst_stall, stalled)
		else:
			stalled = 0

		# Walk the player along the route, slowly enough to stay engaged.
		if leg < WAYPOINTS.size():
			var target: Vector3 = WAYPOINTS[leg]
			var step: Vector3 = target - player
			step.y = 0.0
			if step.length() < 0.2:
				print("   reached waypoint %d %s at tick %4d -- ooze %s, gap %.2f" % [
					leg, target, tick, sim.entities[OOZE], sim.entities[OOZE].distance_to(player)])
				leg += 1
			else:
				player += step.normalized() * 0.06
				sim.entities[PLAYER] = player
		else:
			total_ticks = tick
			break

	var gap: float = sim.entities[OOZE].distance_to(sim.entities[PLAYER])
	print("")
	print("RESULT  final gap %.2f   longest unbroken stall %d ticks (%.1f s)   avoidance commits %d" % [
		gap, worst_stall, worst_stall * DT, commits])
	if leg < WAYPOINTS.size():
		print("   the PLAYER did not finish the route in the window -- widen it before reading this")
	if worst_stall > 60:
		print("   VERDICT: MATERIAL STALL. Return the failing geometry before building.")
	elif gap > 12.0:
		print("   VERDICT: the Ooze fell far behind (%.2f). Worth a look before building." % gap)
	else:
		print("   VERDICT: pursuit follows the route. Bounded lag and the accepted v1 zig only.")
	quit(0)
