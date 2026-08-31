extends SceneTree
## WEDGED-OOZE REPRODUCTION (human finding 2026-08-31). MEASURE BEFORE WIDENING ANYTHING.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_wedged_ooze.gd
##
## THE CONTRADICTION THIS EXISTS TO RESOLVE:
##   authored aperture      5.00 wide
##   Ooze diameter          2.90
##   clearance validator    says the route is valid
##   live play              produced an Ooze stuck at a hall opening after a shield bump
##
## All four cannot be right. Either the validator measures something other than the condition
## that traps an actor, or the displacement path puts a body somewhere pursuit cannot leave.
##
## WIDENING THE APERTURE BLIND WOULD HIDE WHICHEVER IT IS. Reports only; nothing is authored,
## tuned or fixed from this run.
##
## Loaded DYNAMICALLY: a `-s` script compiles before autoloads register.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0
const OOZE: int = 100


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var bounds_script: GDScript = load("res://game/sim/walkable_bounds.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var plan: Object = generator.generate(0, 1)
	var stats: Resource = db.get_resource(&"enemy", &"ooze")
	var radius: float = stats.combat_radius

	print("WEDGED-OOZE REPRODUCTION")
	print("  Ooze radius %.2f (diameter %.2f)   move_speed %.2f" % [radius, radius * 2.0, stats.move_speed])
	print("")

	# THE WHOLE FLOOR as the sim sees it with every route open -- the most permissive case, so
	# anything that traps a body here is geometry, never gating.
	var open_ids: Dictionary = {}
	for connection in plan.connections:
		open_ids[connection.connection_id] = true
	var floor_bounds: Object = bounds_script.new(plan.open_walkable_rects(open_ids))

	# THE ACTUAL LEGAL REGION FOR THE AMBIENT OOZE is its TERRITORY, not the floor. Measuring
	# against the floor answers a question no enemy is ever asked.
	var ambient_id: int = -1
	for encounter in plan.encounters:
		if encounter.role == &"ambient":
			ambient_id = encounter.encounter_id
	var clipped: Array[Rect2] = []
	for encounter in plan.encounters:
		if encounter.encounter_id != ambient_id:
			continue
		for region: Rect2 in encounter.regions:
			for rect: Rect2 in plan.open_walkable_rects(open_ids):
				var shared: Rect2 = rect.intersection(region)
				if shared.get_area() > 0.0:
					clipped.append(shared)
	var territory: Object = bounds_script.new(clipped)
	print("AMBIENT OOZE TERRITORY, %d rects:" % territory.rects.size())
	for rect in territory.rects:
		print("   %s" % rect)
	var legal_west: float = INF
	var cursor: float = 0.0
	while cursor <= 20.0:
		if territory.fits(Vector3(cursor, 0.0, -22.0), radius):
			legal_west = minf(legal_west, cursor)
		cursor += 0.01
	print("  westernmost LEGAL centre for a %.2f body at z=-22 : x = %.2f" % [radius, legal_west])
	print("  the nearest hall aperture mouth sits at x in [-2.50, 2.50]")
	print("  -> the Ooze cannot approach within %.2f units of it, by TERRITORY, not by width" % (legal_west - 2.5))
	print("")

	_report_cross_sections(plan, floor_bounds, radius)
	_report_validator_gap(plan, floor_bounds, radius)
	_probe_corners(plan, floor_bounds, radius)
	quit(0)


## Q: what is the ACTUAL minimum legal cross-section through each aperture, for a real body?
## The validator compares aperture WIDTH against diameter. That is a different question from
## "how far across the mouth can a body's CENTRE legally sit", which is what traps an actor.
func _report_cross_sections(plan: Object, bounds: Object, radius: float) -> void:
	print("APERTURE CROSS-SECTIONS — authored width vs LEGAL CENTRE BAND for a %.2f-radius body" % radius)
	print("  (a body needs its centre inside the band; band = width - 2*radius if the mouth is clean)")
	for connection in plan.connections:
		var aperture: Rect2 = connection.aperture
		var vertical: bool = aperture.size.y >= aperture.size.x
		var width: float = aperture.size.x if vertical else aperture.size.y
		# Sample across the mouth at its midpoint along travel.
		var mid: float = aperture.position.y + aperture.size.y * 0.5 if vertical else aperture.position.x + aperture.size.x * 0.5
		var low: float = aperture.position.x if vertical else aperture.position.y
		var high: float = aperture.end.x if vertical else aperture.end.y
		var legal_low: float = INF
		var legal_high: float = -INF
		var step: float = 0.02
		var cursor: float = low
		while cursor <= high:
			var point: Vector3 = Vector3(cursor, 0.0, mid) if vertical else Vector3(mid, 0.0, cursor)
			if bounds.fits(point, radius):
				legal_low = minf(legal_low, cursor)
				legal_high = maxf(legal_high, cursor)
			cursor += step
		var band: float = 0.0 if legal_low == INF else legal_high - legal_low
		var verdict: String = "OK" if band > 0.0 else "IMPASSABLE"
		print("  connection %d: authored width %.2f  ->  legal centre band %.2f  [%s]" % [
			connection.connection_id, width, band, verdict])
	print("")


## Q: does the clearance validator measure the same geometric condition that traps a body?
func _report_validator_gap(plan: Object, bounds: Object, radius: float) -> void:
	print("VALIDATOR vs REALITY")
	print("  The shipped validator asserts: min(aperture.size.x, aperture.size.y) > diameter.")
	print("  That is a WIDTH test on the aperture rect ALONE. It never asks whether a body's")
	print("  centre can legally occupy the mouth, and it never looks at what the aperture joins.")
	print("")
	print("  The two differ wherever the union around a mouth is not a clean rectangle -- which")
	print("  is exactly where a corner can pinch a body that the width test called fine.")
	print("")


## Q: is the Ooze truly too large, or is it TRAPPED BY A CORNER despite nominal width?
##
## Reproduces the shape of the live failure: put a body against each aperture mouth, offset to
## one side the way a shield bump would leave it, and ask whether ordinary pursuit can get out.
func _probe_corners(plan: Object, bounds: Object, radius: float) -> void:
	print("CORNER-TRAP PROBE — a body shoved to the SIDE of each mouth, as a bump would leave it")
	for connection in plan.connections:
		var aperture: Rect2 = connection.aperture
		var vertical: bool = aperture.size.y >= aperture.size.x
		if not vertical:
			continue
		var mouth_z: float = aperture.end.y
		# Hard against the west jamb, the worst legal position a bump could deposit a body in.
		var probe := Vector3(aperture.position.x + radius, 0.0, mouth_z - radius)
		if not bounds.fits(probe, radius):
			print("  connection %d: the jamb-hugging position is not even legal (nothing to trap)" % connection.connection_id)
			continue
		# Can it move along the corridor from there, and can it move across?
		var forward_ok: bool = bounds.fits(probe + Vector3(0.0, 0.0, -radius), radius)
		var backward_ok: bool = bounds.fits(probe + Vector3(0.0, 0.0, radius), radius)
		var across_ok: bool = bounds.fits(probe + Vector3(radius, 0.0, 0.0), radius)
		var escapes: int = int(forward_ok) + int(backward_ok) + int(across_ok)
		var flag: String = "WEDGED" if escapes == 0 else ("tight" if escapes == 1 else "free")
		print("  connection %d at %s: forward %s  back %s  across %s  -> %s" % [
			connection.connection_id, probe,
			"yes" if forward_ok else "NO", "yes" if backward_ok else "NO",
			"yes" if across_ok else "NO", flag])
	print("")
	print("NOTE: a body that can still move but only along ONE axis is not stuck to the sim --")
	print("      it is stuck to the PLAYER, because straight-line pursuit keeps requesting the")
	print("      blocked direction. That is the same class as the P33 corner finding, and it is")
	print("      the reading to check before concluding the passage is too narrow.")
