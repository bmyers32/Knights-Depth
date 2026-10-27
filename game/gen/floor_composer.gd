class_name FloorComposer
extends RefCounted
## CASTS, PLACES AND ROUTES A FloorRecipe INTO A FloorDraft (ADR-001 §5.1, S2) and lowers it
## through DraftEmitter -> the unchanged LayoutCompiler -> FloorPlan.
##
## ONE COUPLED SEARCH, piece by piece, in the recipe's placement order. For node N with parent P
## on tree edge E (profile F): the candidate pieces for N's role come from the CAST stream (sorted
## by piece_id first, then weighted-shuffled, capped); each candidate's transforms are identity
## then mirror_x if the piece allows it; and the POSITIONS come from the ROUTE, never the other
## way round -- every leg shape F allows (straight; L; Z) at every grid-stepped length fixes the
## child's position exactly, because the child's port must sit at the end of the last leg. The
## ring of positions is walked from a start the PLACE stream chose; its contents and order never
## change. The first position whose route and footprint are clear is accepted and committed; a
## node with no clear position pops, its parent's commit is undone (FloorDraft.rewind) and the
## parent's next position is tried. A cycle-closing edge is routed the moment both of its ends
## stand; failing that is a failure of the node placed last.
##
## ENUMERATION IS LAZY: a frame's cursor yields the next clear option when asked and remembers
## where it was. The search usually accepts the first; the whole ring is walked only when a
## node genuinely has nowhere to go. The order is the same either way.
##
## DETERMINISM: every collection is sorted before it is drawn from; the two streams are seeded
## from the floor seed through SeedMix.derive (one salt per stream, one more per reseeded
## attempt); the combat RNG is never touched; and nothing branches on time -- the clock is read
## twice, for the report.
##
## BUDGETS ARE COUNTS. A candidate cap per node, a placement budget per attempt (undone
## placements included), a reseed budget before the authored fallback. The fallback is a
## fallback: reported apart, never counted as a composed floor.
##
## NOT HERE, BY STAGE: the experience planner (templates spliced by a plan stream), cross-piece
## dependency wiring (S3), visibility projection (S4), population (populate stream reserved).

## What compose() returns. `layout` is the composed layout, or the recipe's authored fallback
## when `report.fallback` is true; `draft` and `emit` are null on a fallback.
class ComposeResult:
	extends RefCounted
	var layout: AuthoredLayout = null
	var draft: FloorDraft = null
	var emit: DraftEmitter.EmitReport = null
	var report: GenerationReport = null


## Stream salts (ADR §5): cast = 2, place = 3; 1 (plan) and 4 (populate) are reserved. Reseeded
## attempts derive a new attempt seed from the floor seed and the attempt number, offset so an
## attempt salt can never coincide with a stream salt.
const STREAM_CAST: int = 2
const STREAM_PLACE: int = 3
const ATTEMPT_SALT: int = 100

const SHAPE_STRAIGHT: StringName = &"I"
const SHAPE_L: StringName = &"L"
const SHAPE_Z: StringName = &"Z"
const SHAPE_U: StringName = &"U"

const _EPSILON: float = 0.0001


## `body_radii` (enemy key -> combat radius) feeds FloorPlan's aperture-clearance rule exactly as
## DepthGenerator supplies it; gen/ reaches no autoload, so the caller looks the radii up.
##
## `spawn_reaches` (enemy key -> EncounterSpacing.arrival_reach), when supplied, makes spawn safety
## a COMPOSITION REJECTION (S3b): an attempt whose emitted floor puts a plate-woken roster member
## inside its arrival reach of the plate's centre is refused like a plan violation. What that rule
## judges is exactly what EncounterSpacing judges -- region-triggered activations, measured from the
## region's centre -- and nothing more: waves woken by a clear, and activation from anywhere else
## on a threshold zone, are not proven safe by it.
static func compose(recipe: FloorRecipe, floor_seed: int, depth: int, body_radii: Dictionary = {}, spawn_reaches: Dictionary = {}) -> ComposeResult:
	var started: int = Time.get_ticks_usec()
	var result := ComposeResult.new()
	var report := GenerationReport.new()
	report.recipe_id = recipe.recipe_id
	report.floor_seed = floor_seed
	report.depth = depth
	result.report = report
	var findings: Array[Dictionary] = recipe.lint()
	findings.append_array(_lint_against_recipe(recipe))
	if not findings.is_empty():
		for finding: Dictionary in findings:
			report.note("recipe: %s" % finding["message"])
		report.structural = true
		report.failing_validator = "recipe lint"
		return _fall_back(recipe, result, started)
	for attempt: int in range(1, recipe.reseed_budget + 2):
		report.attempts = attempt
		var attempt_seed: int = floor_seed if attempt == 1 else SeedMix.derive(floor_seed, ATTEMPT_SALT + attempt)
		var cast_rng := RandomNumberGenerator.new()
		cast_rng.seed = SeedMix.derive(attempt_seed, STREAM_CAST)
		var place_rng := RandomNumberGenerator.new()
		place_rng.seed = SeedMix.derive(attempt_seed, STREAM_PLACE)
		var draft: FloorDraft = _search(recipe, depth, cast_rng, place_rng, report)
		if draft == null:
			report.note("attempt %d: search exhausted" % attempt)
			continue
		_wire(recipe, draft)
		var emitted: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
		if not emitted.is_ok():
			# The emitter refusing a draft the search accepted is a STRUCTURAL failure: the
			# search's own checks and the emitter's disagree, which is a defect, not bad luck.
			report.structural = true
			report.failing_validator = "emit"
			for error: Dictionary in emitted.errors:
				report.reject(StringName("emit_%s" % error["kind"]))
				report.note("attempt %d: %s" % [attempt, error["message"]])
			continue
		var plan := FloorPlan.new()
		plan.stratum_id = emitted.layout.stratum_id
		LayoutCompiler.compile(emitted.layout, plan)
		var violations: Array[Dictionary] = plan.violations(body_radii)
		if not violations.is_empty():
			report.structural = true
			report.failing_validator = "FloorPlan.violations"
			for violation: Dictionary in violations:
				report.reject(StringName("plan_%s" % violation["rule"]))
				report.note("attempt %d: %s" % [attempt, violation["message"]])
			continue
		if not spawn_reaches.is_empty():
			var unsafe: Array[Dictionary] = EncounterSpacing.findings(emitted.layout, spawn_reaches)
			if not unsafe.is_empty():
				report.structural = true
				report.failing_validator = "EncounterSpacing"
				for finding: Dictionary in unsafe:
					report.reject(StringName(finding["rule"]))
					report.note("attempt %d: %s" % [attempt, finding["message"]])
				continue
		report.structural = false
		report.failing_validator = ""
		result.layout = emitted.layout
		result.draft = draft
		result.emit = emitted
		report.extent = _extent_of(plan)
		report.elapsed_usec = Time.get_ticks_usec() - started
		return result
	return _fall_back(recipe, result, started)


## The recipe's cross-piece dependencies as draft wires, in recipe order. Instances are allocated
## in node order, so node i IS instance i; which pieces were cast is the emitter's to check.
static func _wire(recipe: FloorRecipe, draft: FloorDraft) -> void:
	for dependency: Dictionary in recipe.dependencies:
		var from_index: int = recipe._index_of(dependency["from"])
		var to_index: int = recipe._index_of(dependency["to"])
		draft.wire(draft.instances[from_index].instance_id, dependency["from_port"], draft.instances[to_index].instance_id,
			dependency["effect"], dependency["target_key"])


static func _fall_back(recipe: FloorRecipe, result: ComposeResult, started: int) -> ComposeResult:
	result.report.fallback = true
	result.layout = recipe.fallback
	result.report.note("fallback: %s" % (recipe.fallback.layout_id if recipe.fallback != null else "NONE"))
	result.report.elapsed_usec = Time.get_ticks_usec() - started
	return result


## Checks the recipe can only make at composition time: pieces lint against the stratum pool,
## and no profile's joint gap is smaller than the margin (a hallway rect at the gap would then
## fail the margin test it is supposed to pass by construction).
static func _lint_against_recipe(recipe: FloorRecipe) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pool: Array[StringName] = recipe.stratum.enemy_keys if recipe.stratum != null else [] as Array[StringName]
	for piece: FloorPiece in recipe.pieces:
		if piece != null:
			for finding: Dictionary in piece.lint(pool):
				out.append({"rule": &"piece_lint_failed", "message": "piece '%s': %s" % [piece.piece_id, finding["message"]], "refs": finding["refs"]})
	for profile: TraversalProfile in recipe.profiles:
		if profile.gap < recipe.margin:
			out.append({"rule": &"profile_gap_below_margin", "message": "profile '%s' gap %s is below the recipe margin %s" % [profile.profile_id, profile.gap, recipe.margin], "refs": {"profile": profile.profile_id}})
	return out


static func _extent_of(plan: FloorPlan) -> Rect2:
	var extent: Rect2 = Rect2()
	var rects: Array[Rect2] = plan.all_rects()
	for index: int in rects.size():
		extent = rects[index] if index == 0 else extent.merge(rects[index])
	return extent


# --- 1. CAST ----------------------------------------------------------------------------------

## The candidates for one node, in the order the search will try them: eligible by role, depth
## band and tags; sorted by piece_id; weighted-shuffled by the cast stream; capped.
static func cast(recipe: FloorRecipe, node: Dictionary, depth: int, rng: RandomNumberGenerator) -> Array[FloorPiece]:
	var eligible: Array[FloorPiece] = []
	var wanted_tags: Array[StringName] = []
	for tag in node.get("tags", []):
		wanted_tags.append(tag)
	for piece: FloorPiece in recipe.pieces:
		if piece.role == node.get("role", &"") and piece.eligible_at(depth) and piece.carries(wanted_tags):
			eligible.append(piece)
	eligible.sort_custom(func(a: FloorPiece, b: FloorPiece) -> bool: return String(a.piece_id) < String(b.piece_id))
	var ordered: Array[FloorPiece] = []
	while not eligible.is_empty() and ordered.size() < recipe.candidates_per_piece:
		var total: float = 0.0
		for piece: FloorPiece in eligible:
			total += piece.weight
		var draw: float = rng.randf() * total
		var chosen: int = eligible.size() - 1
		var running: float = 0.0
		for index: int in eligible.size():
			running += eligible[index].weight
			if draw < running:
				chosen = index
				break
		ordered.append(eligible[chosen])
		eligible.remove_at(chosen)
	return ordered


# --- 2. THE SEARCH ----------------------------------------------------------------------------

static func _search(recipe: FloorRecipe, depth: int, cast_rng: RandomNumberGenerator, place_rng: RandomNumberGenerator, report: GenerationReport) -> FloorDraft:
	var draft := FloorDraft.new()
	draft.draft_id = recipe.recipe_id
	draft.place_label = recipe.place_label
	draft.stratum_id = recipe.stratum.stratum_id
	# Both streams are consumed ONCE per node, in node order, before anything is placed, so the
	# search path can never change what the streams say.
	var casts: Array = []
	var ring_starts: Array[int] = []
	for node: Dictionary in recipe.nodes:
		casts.append(cast(recipe, node, depth, cast_rng))
		ring_starts.append(place_rng.randi())
	var frames: Array[Dictionary] = []
	var placed: Dictionary = {}  # node key -> instance id
	var budget_left: int = recipe.placement_budget
	var index: int = 0
	while index < recipe.nodes.size():
		if frames.size() == index:
			frames.append({"cursor": _Cursor.new(recipe, draft, placed, index, casts[index], ring_starts[index], report), "mark": draft.mark()})
		var frame: Dictionary = frames[index]
		var option: Dictionary = frame["cursor"].next()
		if option.is_empty():
			frames.pop_back()
			if index == 0:
				return null
			index -= 1
			draft.rewind(frames[index]["mark"])
			placed.erase(recipe.nodes[index].get("key", &""))
			report.backtracks += 1
			continue
		if budget_left <= 0:
			report.reject(&"placement_budget")
			return null
		budget_left -= 1
		report.placements += 1
		var node_key: StringName = recipe.nodes[index].get("key", &"")
		_commit(recipe, draft, placed, node_key, option, report)
		if not _close_cycles(recipe, draft, placed, node_key, report):
			draft.rewind(frame["mark"])
			placed.erase(node_key)
			report.reject(&"cycle_unroutable")
			report.retries += 1
			continue
		index += 1
	_record(recipe, draft, placed, report)
	return draft


## Places the option's piece and, for every node but the entry, lays its hallway and binds both
## joints -- the one draft mutation the search makes, and the one `rewind` takes back.
static func _commit(recipe: FloorRecipe, draft: FloorDraft, placed: Dictionary, node_key: StringName, option: Dictionary, report: GenerationReport) -> void:
	var instance_id: StringName = draft.place(option["piece"], option["origin"], option["transform"])
	placed[node_key] = instance_id
	if option.has("rects"):
		var edge: Dictionary = option["edge"]
		var profile: TraversalProfile = recipe.profile(edge["profile"])
		var hallway_id: StringName = draft.lay(option["rects"], profile.surface, profile.boundary_style)
		draft.bind(placed[edge["from"]], edge["from_port"], hallway_id, profile.overlap, profile.boundary_style, 0)
		draft.bind(instance_id, edge["to_port"], hallway_id, profile.overlap, profile.boundary_style, option["rects"].size() - 1)
		var total: float = 0.0
		for leg: float in option["legs"]:
			total += leg
		report.routes["%s>%s" % [edge["from"], edge["to"]]] = {"profile": profile.profile_id, "shape": option["shape"], "legs": option["legs"], "length": total}


## Routes every closing edge whose two ends now stand. False if one cannot be routed.
static func _close_cycles(recipe: FloorRecipe, draft: FloorDraft, placed: Dictionary, just_placed: StringName, report: GenerationReport) -> bool:
	for edge: Dictionary in recipe.edges:
		if not bool(edge.get("closes_cycle", false)):
			continue
		if edge["from"] != just_placed and edge["to"] != just_placed:
			continue
		if not (placed.has(edge["from"]) and placed.has(edge["to"])):
			continue
		var rects: Array[Rect2] = _route_between(recipe, draft, placed, edge, report)
		if rects.is_empty():
			return false
		var profile: TraversalProfile = recipe.profile(edge["profile"])
		var hallway_id: StringName = draft.lay(rects, profile.surface, profile.boundary_style)
		draft.bind(placed[edge["from"]], edge["from_port"], hallway_id, profile.overlap, profile.boundary_style, 0)
		draft.bind(placed[edge["to"]], edge["to_port"], hallway_id, profile.overlap, profile.boundary_style, rects.size() - 1)
	return true


static func _record(recipe: FloorRecipe, draft: FloorDraft, placed: Dictionary, report: GenerationReport) -> void:
	report.cast.clear()
	for node: Dictionary in recipe.nodes:
		var instance: FloorDraft.PieceInstance = draft.instance_of(placed[node["key"]])
		report.cast[node["key"]] = {"piece_id": instance.piece.piece_id, "transform": instance.transform, "origin": instance.origin}


# --- 3. POSITIONS FROM THE ROUTE --------------------------------------------------------------

## One node's option stream: candidates (cast order) x transforms (identity, then mirror if
## allowed) x the profile's position ring from the place stream's start. `next()` yields the
## next CLEAR option, counting every rejection by reason, or {} when the node has nowhere left.
class _Cursor:
	extends RefCounted
	var _recipe: FloorRecipe
	var _report: GenerationReport
	var _entry: Array = []
	var _is_entry: bool = false
	var _edge: Dictionary = {}
	var _profile: TraversalProfile = null
	var _ring: Array = []
	var _ring_start: int = 0
	var _candidates: Array = []
	var _occupied: Array[Rect2] = []
	var _start: Vector2 = Vector2.ZERO
	var _normal: Vector2 = Vector2.ZERO
	var _blocked: bool = false
	var _c: int = 0
	var _t: int = 0
	var _k: int = 0
	var _transforms: Array[StringName] = []
	var _probe: FloorDraft.PieceInstance = null
	var _child_port: PiecePort = null
	var _child_normal: Vector2 = Vector2.ZERO
	var _child_centre0: Vector2 = Vector2.ZERO
	var _pair_ready: bool = false
	## The ring entries whose last leg ends facing this pair's child port, in ring order. The
	## place stream's start is taken within THIS list, so a start that lands among shapes the
	## port cannot face does not collapse onto the first shape it can (which was always the
	## shortest straight run).
	var _faced: Array[int] = []

	func _init(recipe: FloorRecipe, draft: FloorDraft, placed: Dictionary, index: int, candidates: Array, ring_start: int, report: GenerationReport) -> void:
		_recipe = recipe
		_report = report
		_candidates = candidates
		_ring_start = ring_start
		if index == 0:
			_is_entry = true
			_entry = candidates.duplicate()
			return
		var node: Dictionary = recipe.nodes[index]
		_edge = recipe.parent_edge_of(node["key"])
		_profile = recipe.profile(_edge["profile"])
		var parent: FloorDraft.PieceInstance = draft.instance_of(placed[_edge["from"]])
		var parent_port: PiecePort = parent.piece.port(_edge["from_port"])
		if parent_port == null or not parent_port.is_joinable():
			report.reject(&"parent_port_missing")
			_blocked = true
			return
		if parent_port.width > _profile.width + _EPSILON:
			report.reject(&"port_wider_than_profile")
			_blocked = true
			return
		var span: Dictionary = FloorDraft.port_span(parent, parent_port)
		_start = FloorComposer._centre_of(span, parent, parent_port)
		_normal = FloorComposer._normal_of(span, parent, parent_port)
		_ring = FloorComposer._ring(_profile, recipe.grid_cell, _normal, recipe.flow_axis)
		if _ring.is_empty():
			report.reject(&"profile_ring_empty")
			_blocked = true
			return
		_occupied = FloorComposer._occupied(draft)

	func next() -> Dictionary:
		if _is_entry:
			if _entry.is_empty():
				return {}
			return {"piece": _entry.pop_front(), "transform": FloorPiece.TRANSFORM_IDENTITY, "origin": Vector2.ZERO}
		if _blocked:
			return {}
		while _c < _candidates.size():
			if not _pair_ready and not _begin_pair():
				_advance_pair()
				continue
			while _k < _faced.size():
				var shape: Dictionary = _ring[_faced[(_ring_start + _k) % _faced.size()]]
				_k += 1
				var geometry: Dictionary = FloorComposer._lay_legs(_start, _normal, _profile, shape)
				var end: Vector2 = geometry["end"]
				var port_centre: Vector2 = end + Vector2(shape["final"]) * _profile.gap
				var origin: Vector2 = port_centre - _child_centre0
				_probe.origin = origin
				var footprint: Rect2 = FloorDraft.world_footprint(_probe)
				var reason: StringName = FloorComposer._clear(_recipe, footprint, geometry["rects"], _occupied)
				if reason != &"":
					_report.reject(reason)
					continue
				return {"piece": _probe.piece, "transform": _probe.transform, "origin": origin, "rects": geometry["rects"], "edge": _edge,
					"shape": shape["shape"], "legs": shape["legs"]}
			_advance_pair()
		return {}

	## Prepares the (candidate, transform) pair at the cursor. False when the pair cannot be tried.
	func _begin_pair() -> bool:
		var piece: FloorPiece = _candidates[_c]
		if _t == 0:
			_transforms = [FloorPiece.TRANSFORM_IDENTITY]
			if piece.allows(FloorPiece.TRANSFORM_MIRROR_X):
				_transforms.append(FloorPiece.TRANSFORM_MIRROR_X)
		_pair_ready = true
		_k = 0
		_faced = []
		_child_port = piece.port(_edge["to_port"])
		if _child_port == null or not _child_port.is_joinable():
			_report.reject(&"child_port_missing")
			return false
		if _child_port.width > _profile.width + _EPSILON:
			_report.reject(&"port_wider_than_profile")
			return false
		_probe = FloorDraft.PieceInstance.new()
		_probe.piece = piece
		_probe.transform = _transforms[_t]
		var probe_span: Dictionary = FloorDraft.port_span(_probe, _child_port)
		_child_normal = FloorComposer._normal_of(probe_span, _probe, _child_port)
		_child_centre0 = FloorComposer._centre_of(probe_span, _probe, _child_port)
		for index: int in _ring.size():
			if _child_normal == -Vector2(_ring[index]["final"]):
				_faced.append(index)
		if _faced.is_empty():
			# No shape of this profile ends facing the child's port: a structural mismatch
			# between the port's edge and the route, counted once per piece and transform.
			_report.reject(&"child_port_facing")
			return false
		return true

	func _advance_pair() -> void:
		_pair_ready = false
		_t += 1
		if _t >= _transforms.size():
			_t = 0
			_c += 1


## The fixed enumeration ring of one profile: straight runs, then L turns, then Z jogs, lengths
## ascending on the grid, each turn tried toward the flow before away from it. The ring's
## contents never depend on the seed; only where the search starts walking it does.
static func _ring(profile: TraversalProfile, cell: float, normal: Vector2, flow: Vector2) -> Array:
	var ring: Array = []
	var lengths: Array[float] = _steps(profile.leg_min, profile.length_max, cell)
	var turns: Array[Vector2] = _turns(normal, flow)
	for total: float in _steps(profile.length_min, profile.length_max, cell):
		ring.append({"shape": SHAPE_STRAIGHT, "legs": [total], "turn": Vector2.ZERO, "final": normal})
	if profile.max_legs >= 2:
		for first: float in lengths:
			for second: float in lengths:
				if first + second < profile.length_min - _EPSILON or first + second > profile.length_max + _EPSILON:
					continue
				for turn: Vector2 in turns:
					ring.append({"shape": SHAPE_L, "legs": [first, second], "turn": turn, "final": turn})
	if profile.max_legs >= 3:
		for first: float in lengths:
			for lateral: float in lengths:
				for third: float in lengths:
					var total: float = first + lateral + third
					if total < profile.length_min - _EPSILON or total > profile.length_max + _EPSILON:
						continue
					for turn: Vector2 in turns:
						ring.append({"shape": SHAPE_Z, "legs": [first, lateral, third], "turn": turn, "final": normal})
	return ring


static func _steps(from: float, to: float, cell: float) -> Array[float]:
	var out: Array[float] = []
	var value: float = ceilf(from / cell - _EPSILON) * cell
	while value <= to + _EPSILON:
		out.append(value)
		value += cell
	return out


## The two perpendiculars of a direction, the one closer to the flow first (ties: the
## right-hand turn first, by convention).
static func _turns(normal: Vector2, flow: Vector2) -> Array[Vector2]:
	var right := Vector2(normal.y, -normal.x)
	var left := Vector2(-normal.y, normal.x)
	if left.dot(flow) > right.dot(flow) + _EPSILON:
		return [left, right]
	return [right, left]


## Rects for one leg shape from a start point along a normal. Legs overlap by half a width at
## every corner so the walkable union joins them; nothing else joins them.
static func _lay_legs(start: Vector2, normal: Vector2, profile: TraversalProfile, shape: Dictionary) -> Dictionary:
	var half: float = profile.width * 0.5
	var legs: Array = shape["legs"]
	var rects: Array[Rect2] = []
	var p0: Vector2 = start + normal * profile.gap
	var p1: Vector2 = p0 + normal * float(legs[0])
	if shape["shape"] == SHAPE_STRAIGHT:
		rects.append(_rect_along(p0, p1, half, 0.0, 0.0))
		return {"rects": rects, "end": p1}
	var turn: Vector2 = shape["turn"]
	var p2: Vector2 = p1 + turn * float(legs[1])
	if shape["shape"] == SHAPE_L:
		rects.append(_rect_along(p0, p1, half, 0.0, half))
		rects.append(_rect_along(p1, p2, half, half, 0.0))
		return {"rects": rects, "end": p2}
	var p3: Vector2 = p2 + normal * float(legs[2])
	rects.append(_rect_along(p0, p1, half, 0.0, half))
	rects.append(_rect_along(p1, p2, half, half, half))
	rects.append(_rect_along(p2, p3, half, half, 0.0))
	return {"rects": rects, "end": p3}


## An axis-aligned rect around the centreline a -> b, `half` wide on each side, extended by
## `before` behind a and `after` beyond b.
static func _rect_along(a: Vector2, b: Vector2, half: float, before: float, after: float) -> Rect2:
	var direction: Vector2 = (b - a).normalized()
	var from: Vector2 = a - direction * before
	var to: Vector2 = b + direction * after
	var low := Vector2(minf(from.x, to.x), minf(from.y, to.y))
	var high := Vector2(maxf(from.x, to.x), maxf(from.y, to.y))
	if absf(direction.x) > 0.5:
		return Rect2(low.x, low.y - half, high.x - low.x, 2.0 * half)
	return Rect2(low.x - half, low.y, 2.0 * half, high.y - low.y)


static func _centre_of(span: Dictionary, instance: FloorDraft.PieceInstance, port: PiecePort) -> Vector2:
	var along: float = (float(span["from"]) + float(span["to"])) * 0.5
	if PiecePort.runs_along_x(FloorDraft.world_edge(instance, port.edge)):
		return Vector2(along, float(span["at"]))
	return Vector2(float(span["at"]), along)


static func _normal_of(span: Dictionary, instance: FloorDraft.PieceInstance, port: PiecePort) -> Vector2:
	if PiecePort.runs_along_x(FloorDraft.world_edge(instance, port.edge)):
		return Vector2(0.0, float(span["outward"]))
	return Vector2(float(span["outward"]), 0.0)


# --- 4. CLEARANCE -----------------------------------------------------------------------------

## Every footprint and hallway rect the draft holds.
static func _occupied(draft: FloorDraft) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for instance: FloorDraft.PieceInstance in draft.instances:
		out.append(FloorDraft.world_footprint(instance))
	for hallway: FloorDraft.HallwayFragment in draft.hallways:
		out.append_array(hallway.rects)
	return out


## Why a placement is not clear, or &"" when it is. Everything new, grown by the margin, must
## have no positive-area overlap with anything already there or with the new footprint (the new
## hallway's own rects excepted, which overlap at their corners by design), and must lie inside
## the extent. Contact at exactly the gap is area zero and passes: that is the joint.
static func _clear(recipe: FloorRecipe, footprint: Rect2, rects: Array[Rect2], occupied: Array[Rect2]) -> StringName:
	if not recipe.extent.encloses(footprint):
		return &"extent_exceeded"
	for rect: Rect2 in rects:
		if not recipe.extent.encloses(rect):
			return &"extent_exceeded"
	var grown_footprint: Rect2 = footprint.grow(recipe.margin)
	for other: Rect2 in occupied:
		if grown_footprint.intersection(other).get_area() > _EPSILON:
			return &"footprint_overlap"
	for rect: Rect2 in rects:
		var grown: Rect2 = rect.grow(recipe.margin)
		for other: Rect2 in occupied:
			if grown.intersection(other).get_area() > _EPSILON:
				return &"ground_overlap"
		if grown.intersection(footprint).get_area() > _EPSILON:
			return &"ground_overlap"
	return &""


# --- 5. CLOSING A CYCLE -----------------------------------------------------------------------

## A hallway between two ports that both stand already: straight when they face each other on
## one line; an L when they are perpendicular; a Z when they face each other off-line; a U when
## they face the same way. Each shape is fixed by the geometry up to one grid-stepped length,
## tried ascending; the first clear one is the route. Empty means none fits.
static func _route_between(recipe: FloorRecipe, draft: FloorDraft, placed: Dictionary, edge: Dictionary, report: GenerationReport) -> Array[Rect2]:
	var profile: TraversalProfile = recipe.profile(edge["profile"])
	var a_instance: FloorDraft.PieceInstance = draft.instance_of(placed[edge["from"]])
	var b_instance: FloorDraft.PieceInstance = draft.instance_of(placed[edge["to"]])
	var a_port: PiecePort = a_instance.piece.port(edge["from_port"])
	var b_port: PiecePort = b_instance.piece.port(edge["to_port"])
	var empty: Array[Rect2] = []
	if a_port == null or b_port == null or not a_port.is_joinable() or not b_port.is_joinable():
		report.reject(&"cycle_port_missing")
		return empty
	if a_port.width > profile.width + _EPSILON or b_port.width > profile.width + _EPSILON:
		report.reject(&"port_wider_than_profile")
		return empty
	var a_span: Dictionary = FloorDraft.port_span(a_instance, a_port)
	var b_span: Dictionary = FloorDraft.port_span(b_instance, b_port)
	var na: Vector2 = _normal_of(a_span, a_instance, a_port)
	var nb: Vector2 = _normal_of(b_span, b_instance, b_port)
	var p0: Vector2 = _centre_of(a_span, a_instance, a_port) + na * profile.gap
	var p_end: Vector2 = _centre_of(b_span, b_instance, b_port) + nb * profile.gap
	var half: float = profile.width * 0.5
	var occupied: Array[Rect2] = _occupied(draft)
	var shapes: Array[Dictionary] = []
	var delta: Vector2 = p_end - p0
	if na == -nb:
		var ahead: float = delta.dot(na)
		var side: Vector2 = Vector2(-na.y, na.x)
		var lateral: float = delta.dot(side)
		if absf(lateral) < _EPSILON:
			shapes.append({"shape": SHAPE_STRAIGHT, "points": [p0, p_end], "legs": [ahead]})
		elif profile.max_legs >= 3:
			var d2: Vector2 = side if lateral > 0.0 else -side
			for first: float in _steps(profile.leg_min, ahead - profile.leg_min, recipe.grid_cell):
				var third: float = ahead - first
				var p1: Vector2 = p0 + na * first
				var p2: Vector2 = p1 + d2 * absf(lateral)
				shapes.append({"shape": SHAPE_Z, "points": [p0, p1, p2, p_end], "legs": [first, absf(lateral), third]})
	elif absf(na.dot(nb)) < _EPSILON and profile.max_legs >= 2:
		var first: float = delta.dot(na)
		var second: float = (-delta).dot(nb)
		var p1: Vector2 = p0 + na * first
		shapes.append({"shape": SHAPE_L, "points": [p0, p1, p_end], "legs": [first, second]})
	elif na == nb and profile.max_legs >= 3:
		var side: Vector2 = Vector2(-na.y, na.x)
		var lateral: float = delta.dot(side)
		var ahead: float = delta.dot(na)
		var d2: Vector2 = side if lateral > 0.0 else -side
		for first: float in _steps(profile.leg_min, profile.length_max, recipe.grid_cell):
			var third: float = first - ahead
			var p1: Vector2 = p0 + na * first
			var p2: Vector2 = p1 + d2 * absf(lateral)
			shapes.append({"shape": SHAPE_U, "points": [p0, p1, p2, p_end], "legs": [first, absf(lateral), third]})
	else:
		report.reject(&"cycle_ports_incompatible")
		return empty
	if shapes.is_empty():
		report.reject(&"cycle_no_shape")
		return empty
	for shape: Dictionary in shapes:
		var legs: Array = shape["legs"]
		var total: float = 0.0
		var too_short: bool = false
		for leg: float in legs:
			total += leg
			if leg < profile.leg_min - _EPSILON:
				too_short = true
		if too_short or total < profile.length_min - _EPSILON or total > profile.length_max + _EPSILON:
			report.reject(&"cycle_length_out_of_band")
			continue
		var points: Array = shape["points"]
		var rects: Array[Rect2] = []
		for leg_index: int in range(points.size() - 1):
			var before: float = half if leg_index > 0 else 0.0
			var after: float = half if leg_index < points.size() - 2 else 0.0
			rects.append(_rect_along(points[leg_index], points[leg_index + 1], half, before, after))
		var reason: StringName = _clear_route(recipe, rects, occupied)
		if reason != &"":
			report.reject(reason)
			continue
		report.routes["%s>%s" % [edge["from"], edge["to"]]] = {"profile": profile.profile_id, "shape": shape["shape"], "legs": legs, "length": total}
		return rects
	return empty


static func _clear_route(recipe: FloorRecipe, rects: Array[Rect2], occupied: Array[Rect2]) -> StringName:
	for rect: Rect2 in rects:
		if not recipe.extent.encloses(rect):
			return &"extent_exceeded"
		var grown: Rect2 = rect.grow(recipe.margin)
		for other: Rect2 in occupied:
			if grown.intersection(other).get_area() > _EPSILON:
				return &"ground_overlap"
	return &""
