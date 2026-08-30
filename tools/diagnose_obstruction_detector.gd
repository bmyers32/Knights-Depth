extends SceneTree
## OOZE NAVIGATION RECON — DETECTOR FIRST (ruled 2026-08-29). NO BEHAVIOUR IS IMPLEMENTED.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_obstruction_detector.gd
##
## THE DISCIPLINE THIS OBEYS is the one the scurry detector taught: a behaviour built on a blind
## trigger is not validated merely because the response is plausible. So the OBSTRUCTION
## DETECTOR is validated on its own, against the real failing geometry, BEFORE any avoidance
## behaviour is designed on top of it.
##
## The detector question, exactly as ruled:
##   "Is my intended direct movement toward the target obstructed by authoritative floor
##    geometry?"
##
## It must fire on: the literal observed corner, diagonal approaches, near-tangent approaches.
## It must NOT fire on: clear straight-line pursuit (the control).
##
## SIM GEOMETRY ONLY. No physics query, no NavigationAgent, no engine raycast -- the same fence
## every other spatial answer in this project sits behind.
##
## Loaded DYNAMICALLY: a `-s` script compiles before autoloads register.

const DT: float = 1.0 / 30.0
## Sampling step as a fraction of the body radius. Fine enough that a body cannot tunnel across
## a gap narrower than itself, which is the only way this detector could lie by omission.
const _SAMPLE_FRACTION: float = 0.5
## How far ahead the actor tests. TIED TO detection_radius (10.0 for the Ooze), not picked: an
## actor that only pursues what it can detect has no business reasoning about geometry beyond
## that. The first pass at this used 12.0 with cases 23 u away and reported them "clear" --
## which was CORRECT behaviour against MIS-AUTHORED CASES, and is precisely the trap the
## detector-first discipline exists to catch. Rubbing happens AT the obstruction, so that is
## where the cases must sit.
const _LOOKAHEAD: float = 10.0

var _checks: int = 0
var _failures: Array = []


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var bounds_script: GDScript = load("res://game/sim/walkable_bounds.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var plan: Object = generator.generate(0, 1)
	var radius: float = db.get_resource(&"enemy", &"ooze").combat_radius

	print("OBSTRUCTION DETECTOR VALIDATION — body radius %.2f, lookahead %.1f, step %.2f\n" % [
		radius, _LOOKAHEAD, radius * _SAMPLE_FRACTION])

	# THE LITERAL FAILING GEOMETRY: the mandatory encounter's territory. It spans the arena, the
	# corridor and the approach, so it is NOT convex -- an enemy in the arena chasing an Envoy
	# who is standing in the approach has a 5-wide neck between them and walls either side.
	# This is where a roster ooze meets a corner, and the ambient convexity constraint does not
	# apply here (it constrains AMBIENT territories only).
	var arena_territory: Object = _territory_of(plan, bounds_script, &"mandatory")
	print("MANDATORY territory (arena + corridor + approach), %d rects:" % arena_territory.rects.size())
	for rect in arena_territory.rects:
		print("   %s" % rect)
	print("")

	# 1. LITERAL. Ooze in the arena beside the neck, Envoy just up it: the jamb is between them.
	_case(arena_territory, radius, "LITERAL corner (arena -> neck, off-axis)",
		Vector3(-5.0, 0.0, -50.0), Vector3(0.0, 0.0, -43.0), true)
	# 2. DIAGONAL into the same neck from the other side.
	_case(arena_territory, radius, "DIAGONAL into the neck",
		Vector3(5.0, 0.0, -51.0), Vector3(0.0, 0.0, -43.0), true)
	# 3. NEAR-TANGENT: the line almost grazes the neck's edge. The discriminating case -- a
	#    detector that only works on gross blockage gets this wrong in one direction or other.
	_case(arena_territory, radius, "NEAR-TANGENT, grazing the neck's west jamb",
		Vector3(-2.6, 0.0, -50.5), Vector3(-2.6, 0.0, -38.0), true)
	# 4. CONTROL: straight down the open arena, nothing in the way. MUST NOT FIRE.
	_case(arena_territory, radius, "CONTROL: clear straight-line pursuit in the open arena",
		Vector3(-10.0, 0.0, -60.0), Vector3(10.0, 0.0, -60.0), false)
	# 5. CONTROL: straight up the neck, dead centre. MUST NOT FIRE.
	_case(arena_territory, radius, "CONTROL: straight up the middle of the neck",
		Vector3(0.0, 0.0, -50.0), Vector3(0.0, 0.0, -39.0), false)

	# 6. THE HORIZON, asserted rather than assumed: an obstruction beyond lookahead is NOT the
	#    detector's business, and reporting "clear" there is correct, not a miss.
	_case(arena_territory, radius, "HORIZON: same corner, but 23 u away (beyond lookahead)",
		Vector3(-10.0, 0.0, -60.0), Vector3(0.0, 0.0, -39.0), false)

	# The ambient territory is convex by authored law, so nothing inside it can obstruct. That
	# is the constraint doing its job, and it is worth asserting rather than assuming.
	var ambient: Object = _territory_of(plan, bounds_script, &"ambient")
	_case(ambient, radius, "CONTROL: inside the convex ambient column",
		Vector3(12.0, 0.0, -30.0), Vector3(12.0, 0.0, -14.0), false)

	print("")
	if _failures.is_empty():
		print("DETECTOR: %d/%d cases behaved as required." % [_checks, _checks])
		print("It fires on the literal corner, on a diagonal and on a near-tangent, and stays")
		print("quiet on every clear line. It is validated against the geometry that actually")
		print("fails -- not merely against the cleanest case.")
	else:
		print("DETECTOR: %d of %d cases WRONG -- do not build behaviour on it:" % [_failures.size(), _checks])
		for failure in _failures:
			print("   %s" % failure)

	print("")
	_trace_rub(arena_territory, radius, db.get_resource(&"enemy", &"ooze").move_speed)
	print("")
	_probe_local_routes(arena_territory, radius)
	quit(0 if _failures.is_empty() else 1)


## Q1/Q2/Q4 AT THE LITERAL CORNER. Drives the AUTHORITATIVE displacement seam directly
## (WalkableBounds.clamp_step, the same call locomotion makes) so what is measured is exactly
## what the sim would permit -- no AI band logic in the way to muddy the reading.
func _trace_rub(territory: Object, radius: float, move_speed: float) -> void:
	var position := Vector3(-5.0, 0.0, -50.0)
	var target := Vector3(0.0, 0.0, -43.0)
	var full_step: float = move_speed * DT
	var lost: int = 0
	print("RUB TRACE — direct pursuit into the literal corner, %d ticks at %.4f u/tick" % [180, full_step])
	for tick in 180:
		var wanted: Vector3 = (target - position)
		wanted.y = 0.0
		var attempted: Vector3 = position + wanted.normalized() * full_step
		var reached: Vector3 = territory.clamp_step(position, attempted, radius)
		var moved: float = position.distance_to(reached)
		if moved < full_step * 0.5:
			lost += 1
		if tick % 45 == 0:
			print("   %3d  %-28s moved %.4f  want %s" % [tick, reached, moved, wanted.normalized()])
		position = reached
	print("   Q1 requested : straight at the target EVERY tick -- pursuit never stops asking")
	print("   Q2 permitted : %d of 180 ticks lost >half the step to legality" % lost)
	print("   Q4 outcome   : settled at %s, %.2f from the target (started 8.60 away)" % [position, position.distance_to(target)])
	print("   Q3 provable? : YES -- the block is derivable from sim geometry alone (see above);")
	print("                  no engine query, no physics, no navmesh was consulted anywhere.")


func _territory_of(plan: Object, bounds_script: GDScript, role: StringName) -> Object:
	var open_ids: Dictionary = {}
	for connection in plan.connections:
		open_ids[connection.connection_id] = true
	var floor_rects: Array = plan.open_walkable_rects(open_ids)
	var clipped: Array[Rect2] = []
	for encounter in plan.encounters:
		if encounter.role != role:
			continue
		for region: Rect2 in encounter.regions:
			for rect: Rect2 in floor_rects:
				var shared: Rect2 = rect.intersection(region)
				if shared.get_area() > 0.0:
					clipped.append(shared)
	return bounds_script.new(clipped)


## THE DETECTOR ITSELF. Walks the intended direct line at body width and reports the first place
## the body would not fit. Pure sim geometry; deterministic; no engine query of any kind.
func _obstruction(territory: Object, from: Vector3, to: Vector3, radius: float) -> Dictionary:
	var span: Vector3 = to - from
	span.y = 0.0
	var distance: float = minf(span.length(), _LOOKAHEAD)
	if distance <= 0.0001:
		return {}
	var direction: Vector3 = span.normalized()
	var step: float = maxf(radius * _SAMPLE_FRACTION, 0.05)
	var travelled: float = step
	while travelled <= distance:
		var probe: Vector3 = from + direction * travelled
		if not territory.fits(probe, radius):
			return {"at": probe, "distance": travelled}
		travelled += step
	return {}


func _case(territory: Object, radius: float, label: String, from: Vector3, to: Vector3, must_fire: bool) -> void:
	_checks += 1
	# A case whose ENDPOINTS are not both legal would prove nothing about obstruction -- it
	# would only prove the case was authored wrong.
	var ends_legal: bool = territory.fits(from, radius) and territory.fits(to, radius)
	var hit: Dictionary = _obstruction(territory, from, to, radius)
	var fired: bool = not hit.is_empty()
	var verdict: String = "OK " if fired == must_fire else "WRONG"
	if fired != must_fire:
		_failures.append("%s: expected %s, got %s" % [label, "FIRE" if must_fire else "quiet", "FIRE" if fired else "quiet"])
	if not ends_legal:
		_failures.append("%s: endpoints are not both body-legal, the case itself is mis-authored" % label)
	var where: String = "blocked at %s after %.2f u" % [hit.get("at", Vector3.ZERO), hit.get("distance", 0.0)] if fired else "clear"
	print("%s  %-46s  %s" % [verdict, label, where])


## Q5/Q6 GROUNDWORK: is there a legal LOCAL route around the literal obstruction, and what would
## an actor have to remember to commit to it? Reports geometry only -- proposes no behaviour.
func _probe_local_routes(territory: Object, radius: float) -> void:
	var from := Vector3(-5.0, 0.0, -50.0)
	var to := Vector3(0.0, 0.0, -43.0)
	print("LOCAL ROUTE PROBE — from %s to %s" % [from, to])
	var blocked: Dictionary = _obstruction(territory, from, to, radius)
	if blocked.is_empty():
		print("   direct line is clear; nothing to route around")
		return
	print("   direct line blocked at %s" % blocked["at"])

	# Sidestep probe: how far perpendicular must the actor go before the onward line clears?
	var span: Vector3 = to - from
	span.y = 0.0
	var perpendicular := Vector3(-span.normalized().z, 0.0, span.normalized().x)
	for sign_index in 2:
		var sign: float = 1.0 if sign_index == 0 else -1.0
		var found: float = -1.0
		var offset: float = radius
		while offset <= 16.0:
			var waypoint: Vector3 = from + perpendicular * sign * offset
			if territory.fits(waypoint, radius) \
					and _obstruction(territory, from, waypoint, radius).is_empty() \
					and _obstruction(territory, waypoint, to, radius).is_empty():
				found = offset
				break
			offset += radius * 0.5
		var side: String = "left " if sign > 0.0 else "right"
		if found > 0.0:
			print("   %s sidestep: a legal two-leg route exists at %.2f u perpendicular" % [side, found])
		else:
			print("   %s sidestep: no single perpendicular waypoint clears it within 16 u" % side)
	print("")
	print("Q6 RETAINED STATE: a sidestep only helps if the actor COMMITS to it. Re-deciding every")
	print("   tick re-requests the blocked direct vector as soon as the waypoint stops being the")
	print("   nearest improvement, which is the rubbing behaviour with extra steps. The minimum")
	print("   memory is therefore: the chosen waypoint, the side chosen, and a re-evaluation")
	print("   condition -- three fields, per actor, floor-scoped.")
