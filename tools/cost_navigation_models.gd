extends SceneTree
## P33 NAVIGATION MODEL COSTING (ruled 2026-08-31: zig-zag pursuit rejected by play).
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/cost_navigation_models.gd
##
## THE HUMAN BAR this must serve:
##   "When the Ooze has to go around something, it looks like it picked somewhere to go and goes
##    there, rather than changing its mind back and forth."
##
## THE DECIDING QUESTION between the candidate models is not smoothness -- it is HOW MANY
## COMMITTED LEGS the real geometry needs. If one intermediate point always suffices, model B
## (single committed leg) is the smallest thing that works. If ordinary Floor 1 geometry already
## needs two, B is a half-measure and C must be costed honestly instead.
##
## So this measures, per scenario: is the direct line clear; does ONE waypoint solve it; does it
## take TWO; and how many legs a straight-leg walker actually consumes end to end.
##
## MEASUREMENT ONLY. No model is implemented here.

const RADIUS: float = 1.45
const SAMPLE: float = 0.5
## A pursuer stops at attack range; it never needs to stand ON its target. A first pass tested
## the PLAYER position against the OOZE body radius and skipped three scenarios as "mis-authored"
## -- the harness was asking the wrong question, not the cases being wrong.
const STOP_SHORT: float = 2.2

## Floor 1 geometry, real values.
const ARENA := Rect2(-15.0, -68.0, 30.0, 20.0)
const NECK := Rect2(-2.5, -49.5, 5.0, 9.0)
const APPROACH := Rect2(-6.0, -42.0, 12.0, 6.0)
const HALL_S := Rect2(-16.0, -16.0, 32.0, 4.0)
const HALL_W := Rect2(-16.0, -30.0, 8.0, 16.0)
const HALL_E := Rect2(8.0, -30.0, 8.0, 16.0)
const HALL_N := Rect2(-16.0, -34.0, 32.0, 6.0)

var _bounds_script: GDScript


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1
	_bounds_script = load("res://game/sim/walkable_bounds.gd")

	print("NAVIGATION MODEL COSTING — how many committed legs does the real geometry need?\n")

	var fight: Object = _bounds([ARENA, NECK, APPROACH])
	var hall: Object = _bounds([HALL_S, HALL_W, HALL_E, HALL_N])

	_scenario("1  stationary player, straight across the arena", fight,
		Vector3(-10.0, 0.0, -60.0), Vector3(10.0, 0.0, -60.0))
	_scenario("2  player around ONE corner (arena -> up the neck)", fight,
		Vector3(-5.0, 0.0, -50.0), Vector3(0.0, 0.0, -43.0))
	_scenario("3  strafing player, sampled at three strafe positions", fight,
		Vector3(-5.0, 0.0, -50.0), Vector3(-2.0, 0.0, -43.0))
	_scenario("3b same, player strafed to the far side", fight,
		Vector3(-5.0, 0.0, -50.0), Vector3(2.0, 0.0, -43.0))
	_scenario("4  TOP-OF-SQUARE: across the hall void, west arm to east arm", hall,
		Vector3(-12.0, 0.0, -22.0), Vector3(12.0, 0.0, -22.0))
	_scenario("5  disengaged return home, neck -> arena", fight,
		Vector3(0.0, 0.0, -45.0), Vector3(-5.0, 0.0, -60.0))

	print("READING THIS:")
	print("  'direct' scenarios need no model at all -- any candidate handles them.")
	print("  '1 leg' scenarios are solved by model B (one committed waypoint, straight legs).")
	print("  '2 legs' scenarios are where B stops being sufficient and C is genuinely earned.")
	quit(0)


## Nearest point to `near` where this body fits, scanned deterministically outward.
func _nearest_legal(bounds: Object, near: Vector3) -> Vector3:
	var step: float = 0.25
	var radius_out: float = step
	while radius_out <= 12.0:
		var samples: int = 16
		for i in samples:
			var angle: float = TAU * float(i) / float(samples)
			var point: Vector3 = near + Vector3(cos(angle), 0.0, sin(angle)) * radius_out
			if bounds.fits(point, RADIUS):
				return point
		radius_out += step
	return Vector3.ZERO


func _bounds(rects: Array) -> Object:
	var typed: Array[Rect2] = []
	for rect: Rect2 in rects:
		typed.append(rect)
	return _bounds_script.new(typed)


func _clear(bounds: Object, from: Vector3, to: Vector3) -> bool:
	var span: Vector3 = to - from
	span.y = 0.0
	var distance: float = span.length()
	if distance <= 0.0001:
		return true
	var direction: Vector3 = span.normalized()
	var travelled: float = SAMPLE
	while travelled <= distance:
		if not bounds.fits(from + direction * travelled, RADIUS):
			return false
		travelled += SAMPLE
	return true


## Candidate intermediate points, generated the way the shipped selector does: perpendicular
## offsets ascending from one body radius, right before left. Deterministic.
func _candidates(bounds: Object, from: Vector3, to: Vector3) -> Array:
	var span: Vector3 = to - from
	span.y = 0.0
	if span.length() <= 0.0001:
		return []
	var forward: Vector3 = span.normalized()
	var perpendicular := Vector3(-forward.z, 0.0, forward.x)
	var out: Array = []
	var offset: float = RADIUS
	while offset <= 24.0:
		for sign: float in [1.0, -1.0]:
			var point: Vector3 = from + perpendicular * sign * offset
			if bounds.fits(point, RADIUS):
				out.append(point)
		offset += RADIUS * 0.5
	return out


func _scenario(label: String, bounds: Object, from: Vector3, raw_to: Vector3) -> void:
	# Pull the destination back to attack range along the approach line, then to the nearest
	# legal standing point if a body this size still does not fit there.
	var to: Vector3 = raw_to
	var span: Vector3 = raw_to - from
	span.y = 0.0
	if span.length() > STOP_SHORT:
		to = raw_to - span.normalized() * STOP_SHORT
	if not bounds.fits(to, RADIUS):
		to = _nearest_legal(bounds, to)
	if not bounds.fits(from, RADIUS) or to == Vector3.ZERO:
		print("%s\n   SKIPPED: no body-legal standing point near the target\n" % label)
		return
	if _clear(bounds, from, to):
		print("%s\n   DIRECT -- no navigation needed\n" % label)
		return

	# ONE generator for every leg count, or the comparison is rigged: a 1-leg search using only
	# perpendicular offsets, while the 2-leg search also sees rect centres, reports "needs 2" for
	# routes that one better-chosen point solves. Scenario 5 did exactly that.
	var candidates: Array = _candidates(bounds, from, to)
	for rect: Rect2 in bounds.rects:
		var centre := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
		if bounds.fits(centre, RADIUS):
			candidates.append(centre)
	for point: Vector3 in candidates:
		if _clear(bounds, from, point) and _clear(bounds, point, to):
			print("%s\n   1 LEG via %s -- model B suffices\n" % [label, point])
			return

	# TWO LEGS. Perpendicular offsets alone cannot describe a route AROUND a void -- they only
	# ever step sideways from the blocked line. So the two-leg search also considers the walkable
	# rects' own centres, which is the cheapest generator that can express "go via that space".
	# Without this, a failure would blame the leg count for what is really a generator limit.
	var waypoints: Array = candidates.duplicate()
	for rect: Rect2 in bounds.rects:
		var centre := Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
		if bounds.fits(centre, RADIUS):
			waypoints.append(centre)
	for a: Vector3 in waypoints:
		if not _clear(bounds, from, a):
			continue
		for b: Vector3 in waypoints:
			if _clear(bounds, a, b) and _clear(bounds, b, to):
				print("%s\n   2 LEGS via %s then %s -- model B is INSUFFICIENT here\n" % [label, a, b])
				return
	print("%s\n   NO ROUTE within two legs from these candidates\n" % label)
