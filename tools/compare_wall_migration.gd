extends SceneTree
## P34 PRESENTATION MIGRATION — BEFORE/AFTER WALL REGRESSION EVIDENCE.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/compare_wall_migration.gd
##
## Presentation stopped SAMPLING walls (1.0 spans, probing 0.5 beyond each edge) and now reads
## FloorPlan.solid_segments() -- the same canonical fact the sim consumes for projectile
## obstruction. This tool reproduces the OLD sampler exactly as it was, computes the NEW
## segments, and diffs them on the shipped floor so the difference is OBSERVED rather than
## assumed away.
##
## Checklist, per the migration rider: missing/added walls · gaps · doubled or overlapping
## segments · corner discontinuities · WALL/LEDGE treatment · gate disagreement · changed
## openings · silhouette.
##
## Reports only. Nothing is tuned or authored from this.

const PROBE: float = 0.5    # the old sampler's look-beyond distance
const SPAN: float = 1.0     # the old sampler's quantisation
const FINE: float = 0.05    # comparison resolution


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var plan: Object = generator.generate(0, 1)
	var rects: Array = plan.all_rects()
	var segments: Array = plan.solid_segments()

	print("WALL MIGRATION COMPARISON — authored floor, seed 0 depth 1")
	print("  patches %d   apertures %d   canonical segments %d\n" % [
		plan.patches.size(), plan.connections.size(), segments.size()])

	var edges: Array = _all_edges(plan)
	var only_old: Array = []
	var only_new: Array = []
	var samples: int = 0
	var agree: int = 0
	for edge in edges:
		var at: float = float(edge["at"])
		var vertical: bool = bool(edge["vertical"])
		var outward: float = float(edge["outward"])
		var position: float = float(edge["min"])
		while position < float(edge["max"]) - 0.0001:
			var mid: float = position + FINE * 0.5
			var old_walled: bool = _old_sampler_walls(edge, mid, rects)
			var new_walled: bool = _new_segment_walls(segments, at, vertical, outward, mid)
			samples += 1
			if old_walled == new_walled:
				agree += 1
			elif old_walled:
				only_old.append(_where(at, vertical, mid))
			else:
				only_new.append(_where(at, vertical, mid))
			position += FINE

	print("BOUNDARY AGREEMENT: %d of %d sampled points (%.2f%%)" % [agree, samples, 100.0 * float(agree) / float(maxi(samples, 1))])
	_report("WALLED BEFORE, OPEN NOW (potential missing wall)", only_old)
	_report("OPEN BEFORE, WALLED NOW (potential added wall)", only_new)

	_report_openings(plan, rects, segments)
	_report_overlaps(segments)
	_report_ledges(plan, segments)
	print("GATES: presentation gate meshes are built by _build_connection, which this migration")
	print("       did not touch. Gate placement and state rendering are unchanged by construction.")


func _all_edges(plan: Object) -> Array:
	var edges: Array = []
	for patch in plan.patches:
		if patch.boundary_style == &"ledge":
			continue
		edges.append_array(_edges_of(patch.rect))
	for connection in plan.connections:
		edges.append_array(_edges_of(connection.aperture))
	return edges


func _edges_of(rect: Rect2) -> Array:
	return [
		{"vertical": true, "at": rect.position.x, "outward": -1.0, "min": rect.position.y, "max": rect.end.y, "rect": rect},
		{"vertical": true, "at": rect.end.x, "outward": 1.0, "min": rect.position.y, "max": rect.end.y, "rect": rect},
		{"vertical": false, "at": rect.position.y, "outward": -1.0, "min": rect.position.x, "max": rect.end.x, "rect": rect},
		{"vertical": false, "at": rect.end.y, "outward": 1.0, "min": rect.position.x, "max": rect.end.x, "rect": rect},
	]


## THE OLD SAMPLER, reproduced: quantise the edge into 1.0 spans and probe 0.5 beyond each
## span's midpoint. A point is walled if the span containing it was walled.
func _old_sampler_walls(edge: Dictionary, position: float, rects: Array) -> bool:
	var low: float = float(edge["min"])
	var high: float = float(edge["max"])
	var cursor: float = low
	while cursor < high - 0.001:
		var span: float = minf(SPAN, high - cursor)
		if position >= cursor and position < cursor + span:
			var mid: float = cursor + span * 0.5
			var probe: Vector2
			if bool(edge["vertical"]):
				probe = Vector2(float(edge["at"]) + float(edge["outward"]) * PROBE, mid)
			else:
				probe = Vector2(mid, float(edge["at"]) + float(edge["outward"]) * PROBE)
			return not _walkable(rects, probe)
		cursor += span
	return false


func _new_segment_walls(segments: Array, at: float, vertical: bool, outward: float, position: float) -> bool:
	var axis: StringName = &"x" if vertical else &"z"
	for segment in segments:
		if segment["axis"] != axis:
			continue
		if absf(float(segment["at"]) - at) > 0.0001 or absf(float(segment["outward"]) - outward) > 0.0001:
			continue
		if position >= float(segment["min"]) and position <= float(segment["max"]):
			return true
	return false


func _walkable(rects: Array, point: Vector2) -> bool:
	for rect: Rect2 in rects:
		if point.x >= rect.position.x and point.x <= rect.end.x \
				and point.y >= rect.position.y and point.y <= rect.end.y:
			return true
	return false


func _where(at: float, vertical: bool, position: float) -> Vector2:
	return Vector2(at, position) if vertical else Vector2(position, at)


## Groups scattered mismatch points into runs so the ledger reads as regions, not confetti.
func _report(title: String, points: Array) -> void:
	if points.is_empty():
		print("%s: none" % title)
		return
	print("%s: %d sampled points" % [title, points.size()])
	var shown: int = 0
	var last := Vector2(9999.0, 9999.0)
	for point: Vector2 in points:
		if point.distance_to(last) > 0.2 and shown < 12:
			print("   near %s" % point)
			shown += 1
		last = point


## The one difference that matters: how WIDE does each threshold render, before and after?
func _report_openings(plan: Object, rects: Array, segments: Array) -> void:
	print("")
	print("OPENING WIDTHS at each aperture mouth (the authored corridor is 5.00 wide):")
	for patch in plan.patches:
		if patch.boundary_style == &"ledge":
			continue  # a ledge renders no wall BEFORE OR AFTER; measuring it compares nothing
		for connection in plan.connections:
			var aperture: Rect2 = connection.aperture
			for edge in _edges_of(patch.rect):
				if bool(edge["vertical"]):
					continue
				var at: float = float(edge["at"])
				if at <= aperture.position.y or at >= aperture.end.y:
					continue  # this edge does not cross that aperture
				var old_open: float = 0.0
				var new_open: float = 0.0
				var position: float = float(edge["min"])
				while position < float(edge["max"]) - 0.0001:
					var mid: float = position + FINE * 0.5
					if not _old_sampler_walls(edge, mid, rects):
						old_open += FINE
					if not _new_segment_walls(segments, at, false, float(edge["outward"]), mid):
						new_open += FINE
					position += FINE
				if absf(old_open - new_open) > 0.01:
					print("   patch %d edge z=%.1f : rendered opening %.2f -> %.2f  (walkable aperture %.2f)"
						% [patch.patch_id, at, old_open, new_open, aperture.size.x])


func _report_overlaps(segments: Array) -> void:
	var doubled: int = 0
	for a in range(segments.size()):
		for b in range(a + 1, segments.size()):
			var first: Dictionary = segments[a]
			var second: Dictionary = segments[b]
			if first["axis"] != second["axis"]:
				continue
			if absf(float(first["at"]) - float(second["at"])) > 0.0001:
				continue
			if absf(float(first["outward"]) - float(second["outward"])) > 0.0001:
				continue
			var overlap: float = minf(float(first["max"]), float(second["max"])) - maxf(float(first["min"]), float(second["min"]))
			if overlap > 0.0001:
				doubled += 1
				print("DOUBLED SEGMENT: %s overlaps %s by %.3f" % [first, second, overlap])
	if doubled == 0:
		print("DOUBLED/OVERLAPPING SEGMENTS: none")


func _report_ledges(plan: Object, segments: Array) -> void:
	var offenders: int = 0
	for patch in plan.patches:
		if patch.boundary_style != &"ledge":
			continue
		for segment in segments:
			var vertical: bool = segment["axis"] == &"x"
			var at: float = float(segment["at"])
			var on_edge: bool = (vertical and (absf(at - patch.rect.position.x) < 0.0001 or absf(at - patch.rect.end.x) < 0.0001)) \
				or (not vertical and (absf(at - patch.rect.position.y) < 0.0001 or absf(at - patch.rect.end.y) < 0.0001))
			if not on_edge:
				continue
			var span_low: float = patch.rect.position.y if vertical else patch.rect.position.x
			var span_high: float = patch.rect.end.y if vertical else patch.rect.end.x
			if minf(float(segment["max"]), span_high) - maxf(float(segment["min"]), span_low) > 0.0001:
				offenders += 1
				print("LEDGE VIOLATION: patch %d is a ledge but segment %s lies on its edge" % [patch.patch_id, segment])
	if offenders == 0:
		print("WALL/LEDGE TREATMENT: no segment lies on any ledge patch's edge (correct)")
