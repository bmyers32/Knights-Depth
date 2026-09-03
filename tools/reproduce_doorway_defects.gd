extends SceneTree
## FLOOR 2 DOORWAY DEFECTS — reproduction, before any geometry moves (ruled 2026-09-03).
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/reproduce_doorway_defects.gd
##
## THE HUMAN REPRODUCED, in normal play:
##   * activated the Route A response, then retreated through the OPEN doorway;
##   * the Watcher could not follow;
##   * a Fang burrowed toward the player and disappeared permanently.
##
## PRECONDITIONS ARE ASSERTED CONTINUOUSLY and the run REFUSES to render a verdict when any of
## them lapses -- the banked lesson from five earlier instrumentation failures, where an idle,
## disengaged or dead actor produced a perfect zero that read exactly like a stall.
##
## Reports only. No geometry, content or law is changed here.

const DT: float = 1.0 / 30.0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.depth = 2
	Engine.get_main_loop().root.add_child(arena)
	var sim: Object = arena.sim
	var player: int = arena.envoy.actor_id
	var L: GDScript = load("res://game/gen/layouts/archive_roundabout.gd")
	var plan: FloorPlan = load("res://game/gen/depth_generator.gd").generate(arena.run_seed, 2)
	sim.debug_override_health(player, 100000.0)

	var route_a: Rect2 = plan.patch_by_id(L.P_ROUTE_A).rect
	var aperture: Rect2 = Rect2()
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == L.C_TO_A:
			aperture = connection.aperture

	print("FLOOR 2 DOORWAY DEFECT REPRODUCTION")
	print("   route A %s   doorway aperture %s (%.0f wide)" % [route_a, aperture, aperture.size.x])
	print("")

	# --- ARRANGE: buy the shortcut, so the response is live in Route A. ---------------------
	_walk(sim, player, Vector3(L.CONTROL_PLATE.get_center().x, 0.0, L.CONTROL_PLATE.get_center().y), 0.3)
	if String(sim._encounter_state.get(L.E_CONTROL_RESPONSE, "")) != "active":
		print("REFUSING TO MEASURE: the response never activated, so there is nothing to observe.")
		quit(1)
		return
	var roster: Array = sim._encounter_roster[L.E_CONTROL_RESPONSE]
	print("RESPONSE ACTIVE with roster %s" % str(roster))

	# WHAT BOUNDS DOES EACH ROSTER MEMBER ACTUALLY OBEY? This is the question the symptoms point at.
	for actor_id: int in roster:
		var bounds: Object = sim._legal_bounds_for(actor_id)
		var whole_floor: bool = bounds == sim._bounds
		print("   actor %d (%s)  legal bounds = %s   hard-confined = %s" % [
			actor_id, _family_of(sim, actor_id),
			"THE WHOLE FLOOR" if whole_floor else "its encounter region only", str(not whole_floor)])
	print("")

	# --- DEFECT 1: can the Watcher follow the player out through the open doorway? ----------
	_watcher_probe(sim, player, roster, route_a, aperture, L)

	# --- DEFECT 2: what happens to a Fang that burrows while the player is outside? ---------
	_fang_probe(sim, player, roster, route_a, L)
	quit(0)


func _family_of(sim: Object, actor_id: int) -> String:
	return String(sim._families.get(actor_id, &"?"))


## Teleport-free walk, through the real move Command.
func _walk(sim: Object, actor: int, target: Vector3, tolerance: float, max_ticks: int = 2500) -> bool:
	for i in max_ticks:
		var position: Vector3 = sim.entities[actor]
		if position.distance_to(target) < tolerance:
			return true
		var direction: Vector3 = target - position
		direction.y = 0.0
		sim.tick([Command.new(sim.tick_count, actor, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	return false


func _watcher_probe(sim: Object, player: int, roster: Array, route_a: Rect2, aperture: Rect2, L: GDScript) -> void:
	var watcher: int = -1
	for actor_id: int in roster:
		if _family_of(sim, actor_id) == "watcher":
			watcher = actor_id
	if watcher < 0:
		print("DEFECT 1 SKIPPED: no watcher in the roster.")
		return

	print("DEFECT 1 — WATCHER PURSUIT THROUGH THE OPEN DOORWAY")
	print("   the doorway is %s" % ("OPEN" if bool(sim._connection_open[L.C_TO_A]) else "SHUT -- refusing, this is not the case under test"))
	if not bool(sim._connection_open[L.C_TO_A]):
		return

	# GEOMETRY FIRST: does the Watcher's body even fit through the authored opening?
	var radius: float = float(sim._combat_radius.get(watcher, 0.0))
	var clearance: float = aperture.size.x - radius * 2.0
	print("   watcher body radius %.2f, doorway %.1f wide -> %.2f units of clearance  (%s)" % [
		radius, aperture.size.x, clearance, "FITS" if clearance > 0.0 else "DOES NOT FIT"])

	# THE DECISIVE QUESTION, asked directly rather than inferred from a chase. A chase can end
	# for reasons that have nothing to do with doorways -- the first run of this tool watched the
	# LEASH end it at tick 148 and correctly refused a verdict. Legality is the fact underneath.
	print("   is the doorway legal FOR THIS ACTOR?")
	var doorway_z: float = route_a.end.y + 1.0
	for z: float in [route_a.end.y - 1.0, route_a.end.y, doorway_z, route_a.end.y + 3.0]:
		var point := Vector3(aperture.get_center().x, 0.0, z)
		var mine: bool = sim._legal_bounds_for(watcher).fits(point, radius)
		var floor_wide: bool = sim._bounds.fits(point, radius)
		print("      z=%6.1f   legal for the watcher: %-5s   legal on the floor: %-5s   %s" % [
			z, str(mine), str(floor_wide),
			"<- OPEN TO EVERYONE ELSE, WALLED FOR THIS ACTOR" if floor_wide and not mine else ""])

	# Bring the player into route A so the Watcher engages, then retreat through the doorway.
	sim.debug_set_ai_active(watcher)
	_walk(sim, player, Vector3(route_a.get_center().x, 0.0, -55.0), 1.0)
	var engaged: bool = String(sim._ai_state.get(watcher, "")) == "active"
	print("   after approaching, watcher ai_state = %s" % String(sim._ai_state.get(watcher, "")))
	if not engaged:
		print("   REFUSING TO MEASURE defect 1: the watcher never engaged, so failing to follow")
		print("   would prove nothing about doorways.")
		return

	# JUST past the doorway, not across the room: the leash is 18 units, and retreating far
	# enough to break it would measure the leash again instead of the doorway.
	var north := Vector3(aperture.get_center().x, 0.0, route_a.end.y + 3.0)
	var start: Vector3 = sim.entities[watcher]
	var crossed: bool = false
	var lapsed: String = ""
	for tick in 900:
		sim.debug_override_health(player, 100000.0)
		# CONTINUOUS PRECONDITIONS.
		if sim._health.get(watcher, 0.0) <= 0.0:
			lapsed = "the watcher died"
			break
		if String(sim._ai_state.get(watcher, "")) != "active":
			lapsed = "engagement lapsed at tick %d (leash, not doorway)" % tick
			break
		var position: Vector3 = sim.entities[player]
		var direction: Vector3 = north - position
		direction.y = 0.0
		if direction.length() > 0.5:
			sim.tick([Command.new(sim.tick_count, player, "move", {"direction": direction.normalized()})] as Array[Command], DT)
		else:
			sim.tick([] as Array[Command], DT)
		if sim.entities[watcher].z > route_a.end.y:
			crossed = true
			break

	var here: Vector3 = sim.entities[watcher]
	print("   player ended at %s;  watcher %s -> %s (moved %.2f)" % [
		sim.entities[player].round(), start.round(), here.round(), start.distance_to(here)])
	if lapsed != "":
		print("   NO VERDICT: %s." % lapsed)
	elif crossed:
		print("   VERDICT: the watcher followed through the doorway. No defect here.")
	else:
		var doorway := Vector3(aperture.get_center().x, 0.0, route_a.end.y + 0.5)
		print("   VERDICT: THE WATCHER NEVER LEFT ROUTE A while engaged and alive.")
		print("            Is the doorway even legal FOR IT? fits(%s) under its own bounds = %s" % [
			doorway, str(sim._legal_bounds_for(watcher).fits(doorway, radius))])
		print("            ...and under the WHOLE FLOOR's bounds = %s" % str(sim._bounds.fits(doorway, radius)))
		print("            If those two disagree, the doorway is open and the actor is walled in.")
	print("")


func _fang_probe(sim: Object, player: int, roster: Array, route_a: Rect2, L: GDScript) -> void:
	var fang: int = -1
	for actor_id: int in roster:
		if _family_of(sim, actor_id) == "fang":
			fang = actor_id
	if fang < 0:
		print("DEFECT 2 SKIPPED: no fang in the roster.")
		return

	print("DEFECT 2 — FANG BURROWS WHILE THE PLAYER IS OUTSIDE ITS TERRITORY")
	sim.debug_set_ai_active(fang)
	# The player is already north in the concourse from defect 1. That IS the reproduction case.
	var player_in_route_a: bool = WalkableBounds.contains(route_a, sim.entities[player].x, sim.entities[player].z)
	print("   player at %s -- inside route A: %s" % [sim.entities[player].round(), str(player_in_route_a)])
	if not sim.debug_trigger_burrow(fang, player):
		# WHY it refused matters: "could not start" is not a finding, it is a missing measurement.
		print("   REFUSING TO MEASURE: the fang could not start a burrow. Gating facts --")
		print("      burrow authored for this actor : %s" % str(sim._ai_burrow.has(fang)))
		print("      already burrowing              : %s" % str(sim._burrow.has(fang)))
		print("      alive                          : %s (health %.1f)" % [
			str(sim._health.get(fang, 0.0) > 0.0), float(sim._health.get(fang, 0.0))])
		print("      combat-absent                  : %s" % str(sim.debug_is_combat_absent(fang)))
		print("      ai_state                       : %s" % String(sim._ai_state.get(fang, "")))
		return
	print("   burrow committed. fang alive=%s at %s" % [
		str(sim._health.get(fang, 0.0) > 0.0), sim.entities[fang].round()])

	var last_phase: String = ""
	var died: bool = false
	var emerged: bool = false
	for tick in 1200:
		sim.debug_override_health(player, 100000.0)
		var snapshot: Dictionary = sim.debug_describe_burrow(fang)
		var phase: String = String(snapshot.get("phase", "none"))
		if phase != last_phase:
			print("   tick %4d  phase %-14s combat_absent=%s  alive=%s  at %s" % [
				tick, phase, str(snapshot.get("combat_absent", false)),
				str(sim._health.get(fang, 0.0) > 0.0), sim.entities[fang].round()])
			last_phase = phase
		for event in sim.tick([] as Array[Command], DT):
			if event.kind == "died" and int(event.payload.get("actor_id", -1)) == fang:
				died = true
			if event.kind == "burrow_emerged" and int(event.payload.get("actor_id", -1)) == fang:
				emerged = true
		if died or emerged:
			break

	if emerged:
		print("   VERDICT: the fang emerged at %s. No defect on this path." % sim.entities[fang].round())
	elif died:
		print("   VERDICT: THE FANG DIED UNDERGROUND -- the emergence fail-safe fired.")
		print("            Every candidate rings the player at the authored emergence radius, and")
		print("            the player is outside this actor's legal bounds, so every candidate was")
		print("            refused as illegal placement. The actor was alive, engaged, and doing")
		print("            exactly what it is authored to do. To the player it simply vanished.")
	else:
		print("   VERDICT: still underground after 1200 ticks, alive and absent. That is the")
		print("            soft-lock the fail-safe exists to prevent, reached by another road.")
	print("")
