extends SceneTree
## UPPER-AREA STALL RECON (human replay of 69016ee). CLASSIFY BEFORE CHANGING STEERING.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_hall_stall.gd
##
## NO SCREENSHOT REACHED THIS SESSION, so the location is reconstructed from the description --
## "led the Ooze around the floor back toward its original area", "upper area". That is the HALL
## (z -34 .. -12), whose four patches wrap a VOID, with the ambient Ooze's origin in the east arm.
## If the real stall was elsewhere, this recon is measuring the wrong spot and says so rather
## than quietly answering a different question.
##
## FOUR CANDIDATE CLASSIFICATIONS, and they want different fixes:
##   1. TRULY BLOCKED      -- no legal route exists; no steering grammar can help
##   2. CLOSED-GATE DEAD END -- every reachable aperture is shut. The candidate law is CORRECT to
##                            refuse it, and cardinal movement would stall identically. Routes to
##                            encounter/territory AUTHORING, not to steering.
##   3. INEXPRESSIBLE      -- a legal route exists but the current candidate vocabulary cannot
##                            name it. Routes to the steering model.
##   4. CARDINAL-SOLVABLE  -- a plain south/west leg sequence works. Direct evidence for model B.
##
## Reports only.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0
const OOZE: int = 100


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
	var radius: float = stats.combat_radius

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
	var home := Vector3.ZERO
	for spawn in plan.all_spawns():
		if spawn["enemy_key"] != &"ooze" or int(spawn["encounter_id"]) != ambient_id:
			continue
		home = spawn["position"]
		registrar.register_enemy_body(sim, OOZE, &"ooze", home)
		registrar.register_enemy_ai(sim, OOZE, &"ooze", home)
		sim.assign_actor_encounter(OOZE, ambient_id)
		break

	# THE ONE-WAY COMMITMENT HAS FIRED by the time anyone is in the hall, so the floor is in its
	# real state: C_COMMIT blocked behind the player, C_TO_APPROACH still shut.
	sim.entities[PLAYER] = Vector3(0.0, 0.0, -14.0)
	sim.tick(_no_commands(), DT)

	print("CONNECTION STATE in the hall (this is what the aperture vocabulary can see):")
	for connection_id in sim._connections:
		print("   connection %d  open=%s  aperture=%s" % [connection_id,
			sim._connection_open.get(connection_id, false), sim._connections[connection_id]["aperture"]])
	print("")

	# The stall shape: Ooze led round the ring, player across the VOID from it.
	var ooze_at := Vector3(12.0, 0.0, -22.0)      # east arm, its origin side
	var player_at := Vector3(-12.0, 0.0, -22.0)   # west arm, straight across the hole
	sim.entities[OOZE] = ooze_at
	sim.entities[PLAYER] = player_at
	sim.debug_set_ai_active(OOZE)

	print("STALL STATE  ooze=%s (r=%.2f)  player=%s  separation=%.2f" % [
		ooze_at, radius, player_at, ooze_at.distance_to(player_at)])

	var region: Object = sim._legal_bounds_for(OOZE)
	print("   _legal_bounds_for -> %d rects" % region.rects.size())
	print("   obstruction to player: %s" % sim._direct_route_obstruction(OOZE, player_at))
	var apertures: Array = sim._aperture_candidates(ooze_at, player_at, region, radius)
	print("   APERTURE candidates offered: %d %s" % [apertures.size(), apertures])
	var chosen: Vector3 = sim._select_avoidance_waypoint(OOZE, player_at)
	print("   selected waypoint: %s" % ("NONE" if chosen == Vector3.ZERO else str(chosen)))
	print("")

	_classify(sim, region, radius, ooze_at, player_at)

	_simulate_cardinal(region, radius, ooze_at, player_at)

	# What the actor ACTUALLY does over time.
	print("MOVEMENT over 300 ticks:")
	var start: Vector3 = sim.entities[OOZE]
	for t in 300:
		sim.tick(_no_commands(), DT)
		if t % 60 == 0:
			print("   t%3d  %s  gap=%.2f" % [t, sim.entities[OOZE], sim.entities[OOZE].distance_to(player_at)])
	print("   NET DISPLACEMENT %.2f u   final gap %.2f" % [
		start.distance_to(sim.entities[OOZE]), sim.entities[OOZE].distance_to(player_at)])
	quit(0)


func _no_commands() -> Array:
	return Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))


func _classify(sim: Object, region: Object, radius: float, from: Vector3, to: Vector3) -> void:
	# Is ANY legal route available at all? Probe a coarse cardinal staircase: the exact shape the
	# human described -- "south, south, south until lined up, then west, west, west".
	var cardinal_ok: bool = _cardinal_route(region, radius, from, to)
	var open_apertures: int = 0
	for connection_id in sim._connections:
		if bool(sim._connection_open.get(connection_id, false)):
			open_apertures += 1

	print("CLASSIFICATION")
	print("   open connections on the floor right now: %d" % open_apertures)
	print("   a plain CARDINAL route (axis legs only) from ooze to player: %s" % ("EXISTS" if cardinal_ok else "none found"))
	if cardinal_ok:
		print("   -> class 4 CARDINAL-SOLVABLE. A legal route exists that plain axis legs express,")
		print("      and the current vocabulary did not take it. This is DIRECT evidence for model B:")
		print("      the geometry is fine and the steering language is the limit.")
	elif open_apertures == 0:
		print("   -> class 2 CLOSED-GATE DEAD END. No grammar walks through a shut door; cardinal")
		print("      movement would stall here identically. Routes to encounter/territory AUTHORING.")
	else:
		print("   -> class 1 or 3: no cardinal route found, but openings exist. Needs the leg-count")
		print("      question answered before any steering model is graded against this spot.")
	print("")


## MODEL B, SIMULATED. A REACTIVE cardinal policy, not a planned staircase: pick the axis that
## reduces separation, walk it while it is legal, and when it blocks, take the other axis --
## even when that axis reduces nothing, which is the case a two-leg probe cannot express and is
## exactly what a ring route needs.
##
## The only real design question this exposes: when the useful axis is blocked and the other axis
## is neutral, WHICH WAY along it? Answered here deterministically by preferring the side whose
## first step is legal, then by a fixed tie order. That is wall-following in miniature, and it
## solves this class of geometry with no planning at all.
func _simulate_cardinal(region: Object, radius: float, from: Vector3, to: Vector3) -> void:
	print("MODEL B SIMULATION — reactive cardinal legs")
	_walk(region, radius, from, to, false)
	_walk(region, radius, from, to, true)


## TWO VARIANTS, because the difference between them is the whole finding.
##
## UNCOMMITTED: re-decide the axis every step. It alternates one step onto the free axis, reads
## itself as "aligned" again, switches back into the wall, and repeats -- THE SAME TWO-STATE
## OSCILLATION P33 already fixed, wearing cardinal clothing. Cardinal grammar does NOT get
## immunity for free; it inherits it only if legs are committed.
##
## COMMITTED: when the preferred axis blocks, commit to the perpendicular one and walk it until
## the preferred axis is free again. That is wall-following in miniature -- no planning, no
## graph -- and it is the version worth costing.
func _walk(region: Object, radius: float, from: Vector3, to: Vector3, committed: bool) -> void:
	var label: String = "AXIS-COMMITTED" if committed else "per-step re-pick"
	var at: Vector3 = from
	var step: float = 0.25
	var switches: int = 0
	var axis_is_x: bool = absf(to.x - at.x) >= absf(to.z - at.z)
	var wall_following: bool = false
	var follow_direction: float = 0.0

	for i in 8000:
		if at.distance_to(to) <= 2.2:
			print("   %s: ARRIVED after %d switches, %d steps, at %s" % [label, switches, i, at])
			return
		if not committed:
			# The naive version: re-choose the axis every step by whichever delta is larger.
			axis_is_x = absf(to.x - at.x) >= absf(to.z - at.z)

		if wall_following:
			var blocked_axis_now: Vector3 = _axis_step(axis_is_x, signf((to.x - at.x) if axis_is_x else (to.z - at.z)), step)
			if region.fits(at + blocked_axis_now, radius):
				wall_following = false  # the axis I wanted is free again
			else:
				var follow: Vector3 = _axis_step(not axis_is_x, follow_direction, step)
				if region.fits(at + follow, radius):
					at += follow
					continue
				wall_following = false

		var toward: float = signf((to.x - at.x) if axis_is_x else (to.z - at.z))
		var aligned: bool = absf((to.x - at.x) if axis_is_x else (to.z - at.z)) <= step
		if not aligned and region.fits(at + _axis_step(axis_is_x, toward, step), radius):
			at += _axis_step(axis_is_x, toward, step)
			continue

		if aligned:
			# Leg finished honestly: switch axis and commit to the new one.
			switches += 1
			axis_is_x = not axis_is_x
			wall_following = false
			if absf((to.x - at.x) if axis_is_x else (to.z - at.z)) <= step:
				print("   %s: ARRIVED (both axes aligned) after %d switches at %s" % [label, switches, at])
				return
			continue

		# Blocked, not aligned: wall-follow on the perpendicular axis until this one frees.
		switches += 1
		var chosen: float = 0.0
		for option: float in [1.0, -1.0]:
			if region.fits(at + _axis_step(not axis_is_x, option, step), radius):
				chosen = option
				break
		if chosen == 0.0:
			print("   %s: STALLED after %d switches at %s" % [label, switches, at])
			return
		follow_direction = chosen
		wall_following = true
		at += _axis_step(not axis_is_x, chosen, step)
		if switches > 80:
			print("   %s: gave up after %d switches at %s, gap %.2f" % [label, switches, at, at.distance_to(to)])
			return
	print("   %s: ran out of steps at %s, gap %.2f" % [label, at, at.distance_to(to)])


func _axis_step(axis_is_x: bool, direction: float, step: float) -> Vector3:
	return Vector3(direction * step, 0.0, 0.0) if axis_is_x else Vector3(0.0, 0.0, direction * step)


## Deterministic staircase probe: try Z-first then X-first, each as two straight cardinal legs.
func _cardinal_route(region: Object, radius: float, from: Vector3, to: Vector3) -> bool:
	for z_first: bool in [true, false]:
		var corner: Vector3 = Vector3(from.x, 0.0, to.z) if z_first else Vector3(to.x, 0.0, from.z)
		if region.fits(corner, radius) and _leg(region, radius, from, corner) and _leg(region, radius, corner, to):
			print("   cardinal route found via %s (%s first)" % [corner, "Z" if z_first else "X"])
			return true
	return false


func _leg(region: Object, radius: float, from: Vector3, to: Vector3) -> bool:
	var span: Vector3 = to - from
	span.y = 0.0
	var distance: float = span.length()
	if distance <= 0.0001:
		return true
	var direction: Vector3 = span.normalized()
	var travelled: float = 0.25
	while travelled <= distance:
		if not region.fits(from + direction * travelled, radius):
			return false
		travelled += 0.25
	return true
