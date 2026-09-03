class_name FloorPlan
extends RefCounted
## One floor's complete deterministic description (CLAUDE.md Core Interfaces:
## DepthGenerator.generate(seed, depth) -> FloorPlan).
##
## FOUR INDEPENDENT LAYERS, none parenting another (see FloorLayers). The multi-room slice
## falsified rooms-plus-doors as the parent abstraction, so geometry, progression, encounters
## and interactions are now siblings that merely share coordinates.
##
## TWO VIEWS, ONE TRUTH:
##   patches + connections   the authoring view
##   open_walkable_rects()   the legality view the sim clamps against, DERIVED -- and derived
##                           per connection STATE, which is what makes a blocked gate real
##
## Plain data, RefCounted, no Node/Resource deps: headless-runnable by law (CLAUDE.md
## Structure) and serializable, which is what lets a server hand a joining client a floor in
## M3 (§4.1: floor layout is server-authoritative).
##
## SEED HONESTY. `run_seed` is canonical reproduction metadata and nothing more right now: the
## prototype floor is HAND-AUTHORED, so different seeds do NOT currently produce different
## spatial layouts. Procedural assembly is deferred until the grammar itself passes, and no
## UI or diagnostic may advertise variety that does not exist.

var run_seed: int = 0
var floor_seed: int = 0
var depth: int = 0
var stratum_id: StringName = &""
## True while the layout is authored rather than assembled. Read by the driver so the on-screen
## seed line can say so plainly instead of implying procedural variety.
var authored_layout: bool = true

# --- SPATIAL -------------------------------------------------------------------------
var patches: Array[WalkablePatch] = []
# --- PROGRESSION ---------------------------------------------------------------------
var connections: Array[TraversalConnection] = []
var triggers: Array[FloorTrigger] = []
# --- ENCOUNTER -----------------------------------------------------------------------
var encounters: Array[EncounterSite] = []
# --- WORLD INTERACTION ---------------------------------------------------------------
var breakables: Array[BreakablePlan] = []
var hit_switches: Array[HitSwitchPlan] = []
var obstacles: Array[ObstaclePlan] = []
var spike_pads: Array[SpikePadPlan] = []

## Where the Envoy arrives.
var entry_point: Vector3 = Vector3.ZERO
## Deterministic terminal endpoint. NOT an elevator, no transition logic, no run-end UI --
## it exists so the traversal grammar has a visible end.
var end_marker: Vector3 = Vector3.ZERO


## The legality view, for a given set of open connections. A BLOCKED connection contributes
## nothing, which removes the passage beyond the threshold while each patch's own rect still
## covers its half of the aperture -- so blocking never shrinks a space or snaps an actor off
## a doorway.
func open_walkable_rects(open_connection_ids: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for patch in patches:
		rects.append(patch.rect)
	for connection in connections:
		if open_connection_ids.get(connection.connection_id, false):
			rects.append(connection.aperture)
	return rects


## Every rect regardless of connection state -- used for the camera's extent and for
## presentation, which draws corridors whether or not they are currently passable.
func all_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for patch in patches:
		rects.append(patch.rect)
	for connection in connections:
		rects.append(connection.aperture)
	return rects


## THE ONE AUTHORITATIVE WALL REPRESENTATION (P34). Both consumers read THIS -- the sim for
## projectile obstruction, presentation for rendering -- so a wall cannot exist for one and not
## the other. Presentation may tessellate a segment for drawing; it must never rediscover
## whether or where a wall is.
##
## EXACT, not sampled. FloorBuilder used to sample each edge in 1.0 spans because it was drawing
## scenery and approximation was free; the sim needs the real thing, and two derivations of one
## fact is exactly the drift a single source exists to prevent.
##
## A segment is one axis-aligned run of solid boundary:
##   axis      &"x" -- a line at x = at, spanning z in [min, max]
##             &"z" -- a line at z = at, spanning x in [min, max]
##   outward   which way is NOT walkable (-1 / +1 along the axis normal), so presentation can
##             place a wall's thickness outside the floor rather than guessing
##   elevation the patch's own height, for rendering only
##
## LEDGE PATCHES CONTRIBUTE NOTHING. That is the whole content of the wall/ledge distinction:
## the sim will not stop a shot at an open edge, and presentation will not draw one, from the
## same authored fact. Movement legality is unaffected either way -- it never came from here.
func solid_segments() -> Array[Dictionary]:
	var rects: Array[Rect2] = all_rects()
	var segments: Array[Dictionary] = []
	for patch in patches:
		_segments_of_patch(patch, rects, segments)
	# Aperture SIDES are walls like any other: a corridor has flanks. Whether the corridor is
	# passable is a gate question (connection state), never a static-geometry one.
	for connection in connections:
		_segments_of(connection.aperture, 0.0, rects, segments)
	# OBSTACLE FACES ARE SOLID, from the same authored rect that excludes bodies. This is the
	# whole point: a shot stops exactly where a body would, because both read one fact. Their
	# faces are INWARD-facing walls, so they are emitted directly rather than through the
	# uncovered-span derivation, which asks "is there ground beyond this edge" -- and beyond an
	# obstacle's edge there always is.
	# A BLOCKING DESTRUCTIBLE CONTRIBUTES NO WALL FACES, deliberately, and this is worth stating
	# because the first version did emit them. A breakable ALREADY stops projectiles through its
	# own detection -- so faces duplicated that law, and the duplicate won: the west face stopped
	# every shot a hair SHORT of the prop, which made a destructible standing in a doorway
	# permanently indestructible. Its rect governs MOVEMENT; its own hit circle governs shots.
	for obstacle in obstacles:
		var box: Rect2 = obstacle.rect
		segments.append({"axis": &"x", "at": box.position.x, "min": box.position.y, "max": box.end.y, "outward": -1.0, "style": &"wall", "elevation": 0.0})
		segments.append({"axis": &"x", "at": box.end.x, "min": box.position.y, "max": box.end.y, "outward": 1.0, "style": &"wall", "elevation": 0.0})
		segments.append({"axis": &"z", "at": box.position.y, "min": box.position.x, "max": box.end.x, "outward": -1.0, "style": &"wall", "elevation": 0.0})
		segments.append({"axis": &"z", "at": box.end.y, "min": box.position.x, "max": box.end.x, "outward": 1.0, "style": &"wall", "elevation": 0.0})
	return _merge_collinear(_solid_only(_reject_style_conflicts(segments)))


## THE OPEN EDGES — the exact complement of solid_segments(), in the same shape, derived from the
## same pass (ruled 2026-09-02).
##
## PRESENTATION ONLY, and deliberately not handed to the sim. `ledge` renders as NOTHING today,
## so "ground intentionally ends here" and "a wall that was never built" are the same picture --
## an absence. Floor 2's Vault read as an unfinished room for exactly that reason. This exists so
## presentation can draw a low lip at an authored open edge.
##
## IT CHANGES NO LAW. A ledge stops no projectile, bounds no body and is not a new boundary type:
## movement legality never came from these segments, and the sim still receives solid_segments()
## alone. The lip is a picture of an edge that already existed.
func open_edge_segments() -> Array[Dictionary]:
	var rects: Array[Rect2] = all_rects()
	var segments: Array[Dictionary] = []
	for patch in patches:
		_segments_of_patch(patch, rects, segments)
	for connection in connections:
		_segments_of(connection.aperture, 0.0, rects, segments)
	return _merge_collinear(_ledge_only(_reject_style_conflicts(segments)))


static func _ledge_only(segments: Array[Dictionary]) -> Array[Dictionary]:
	var open_edges: Array[Dictionary] = []
	for segment in segments:
		if segment["style"] == &"ledge":
			open_edges.append(segment)
	return open_edges


## CONFLICT DETECTION, not precedence. Two overlapping patches can both own the same surviving
## exterior span; if they disagree about its style there is no honest winner, so this FAILS
## LOUDLY rather than resolving by array order. If it never fires, the condition genuinely cannot
## arise under the current derivation -- which is the other half of what the ruling asked.
static func _reject_style_conflicts(segments: Array[Dictionary]) -> Array[Dictionary]:
	for a in range(segments.size()):
		for b in range(a + 1, segments.size()):
			var first: Dictionary = segments[a]
			var second: Dictionary = segments[b]
			if first["style"] == second["style"]:
				continue
			if first["axis"] != second["axis"] or absf(float(first["at"]) - float(second["at"])) > 0.0001:
				continue
			if absf(float(first["outward"]) - float(second["outward"])) > 0.0001:
				continue
			var overlap: float = minf(float(first["max"]), float(second["max"])) - maxf(float(first["min"]), float(second["min"]))
			if overlap > 0.0001:
				push_error(("FloorPlan: conflicting boundary styles on one span -- %s vs %s on axis %s at %.2f, "
					+ "overlapping %.2f. Two patches disagree about the same exterior edge; author them to agree "
					+ "rather than relying on a precedence rule, because there is none.")
					% [first["style"], second["style"], first["axis"], first["at"], overlap])
	return segments


## A LEDGE contributes no solid boundary -- no wall mesh, and nothing for a projectile to meet.
## Movement legality is untouched either way: it never came from here.
static func _solid_only(segments: Array[Dictionary]) -> Array[Dictionary]:
	var solid: Array[Dictionary] = []
	for segment in segments:
		if segment["style"] != &"ledge":
			solid.append(segment)
	return solid


## Overlapping patches produce the SAME outer wall more than once -- the hall's west face is
## contributed by the strip and by the arm, overlapping wherever they overlap. Coincident
## geometry is a rendering defect (two boxes in one place) and pointless work for the sweep, so
## collinear runs sharing a line are unioned into one. Coverage is identical either way; this
## only removes duplicates.
static func _merge_collinear(segments: Array[Dictionary]) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for segment in segments:
		var key: String = "%s|%.4f|%.1f|%.4f" % [segment["axis"], segment["at"], segment["outward"], segment["elevation"]]
		if not grouped.has(key):
			grouped[key] = []
		grouped[key].append(segment)
	var keys: Array = grouped.keys()
	keys.sort()  # determinism: never let Dictionary order reach the output
	var merged: Array[Dictionary] = []
	for key: String in keys:
		var runs: Array = grouped[key]
		runs.sort_custom(func(a, b): return float(a["min"]) < float(b["min"]))
		var current: Dictionary = {}
		for run: Dictionary in runs:
			if current.is_empty():
				current = run.duplicate()
				continue
			if float(run["min"]) <= float(current["max"]) + 0.0001:
				current["max"] = maxf(float(current["max"]), float(run["max"]))
			else:
				merged.append(current)
				current = run.duplicate()
		if not current.is_empty():
			merged.append(current)
	return merged


## Emits EVERY surviving exterior side of a patch, each tagged with its effective style. Ledge
## sides are emitted too, then dropped after conflict detection -- suppressing them here would
## make a ledge silently lose to an overlapping patch's wall, which is exactly the invented
## precedence rule the ruling forbids.
static func _segments_of_patch(patch: WalkablePatch, rects: Array[Rect2], out: Array[Dictionary]) -> void:
	var rect: Rect2 = patch.rect
	var elevation: float = patch.elevation
	_emit(out, &"x", rect.position.x, -1.0, elevation, patch.edge_style(&"west"),
		_uncovered_span(rect.position.y, rect.end.y, rects, true, rect.position.x, -1.0))
	_emit(out, &"x", rect.end.x, 1.0, elevation, patch.edge_style(&"east"),
		_uncovered_span(rect.position.y, rect.end.y, rects, true, rect.end.x, 1.0))
	_emit(out, &"z", rect.position.y, -1.0, elevation, patch.edge_style(&"south"),
		_uncovered_span(rect.position.x, rect.end.x, rects, false, rect.position.y, -1.0))
	_emit(out, &"z", rect.end.y, 1.0, elevation, patch.edge_style(&"north"),
		_uncovered_span(rect.position.x, rect.end.x, rects, false, rect.end.y, 1.0))


static func _segments_of(rect: Rect2, elevation: float, rects: Array[Rect2], out: Array[Dictionary]) -> void:
	# WEST edge: solid wherever the strip immediately west of it is not walkable.
	_emit(out, &"x", rect.position.x, -1.0, elevation, &"wall",
		_uncovered_span(rect.position.y, rect.end.y, rects, true, rect.position.x, -1.0))
	_emit(out, &"x", rect.end.x, 1.0, elevation, &"wall",
		_uncovered_span(rect.position.y, rect.end.y, rects, true, rect.end.x, 1.0))
	_emit(out, &"z", rect.position.y, -1.0, elevation, &"wall",
		_uncovered_span(rect.position.x, rect.end.x, rects, false, rect.position.y, -1.0))
	_emit(out, &"z", rect.end.y, 1.0, elevation, &"wall",
		_uncovered_span(rect.position.x, rect.end.x, rects, false, rect.end.y, 1.0))


## The parts of an edge with no walkable ground on its far side, as exact intervals.
##
## The neighbour test is written for a point an epsilon OUTSIDE the edge, which is what decides
## whether a wall belongs there. Rects that merely touch the edge from outside DO cover it --
## abutting ground is still ground -- while the edge's own rect never covers its own outside.
static func _uncovered_span(low: float, high: float, rects: Array[Rect2], vertical: bool, at: float, outward: float) -> Array:
	var open_intervals: Array = [[low, high]]
	for other: Rect2 in rects:
		var near: float = other.position.x if vertical else other.position.y
		var far: float = other.end.x if vertical else other.end.y
		var covers: bool = (near <= at and far > at) if outward > 0.0 else (near < at and far >= at)
		if not covers:
			continue
		var other_low: float = other.position.y if vertical else other.position.x
		var other_high: float = other.end.y if vertical else other.end.x
		var remaining: Array = []
		for interval: Array in open_intervals:
			remaining.append_array(_subtract_interval(interval, other_low, other_high))
		open_intervals = remaining
		if open_intervals.is_empty():
			break
	return open_intervals


static func _subtract_interval(interval: Array, cut_low: float, cut_high: float) -> Array:
	var low: float = interval[0]
	var high: float = interval[1]
	if cut_high <= low or cut_low >= high:
		return [interval]
	var out: Array = []
	if cut_low > low:
		out.append([low, cut_low])
	if cut_high < high:
		out.append([cut_high, high])
	return out


static func _emit(out: Array[Dictionary], axis: StringName, at: float, outward: float, elevation: float, style: StringName, spans: Array) -> void:
	for span: Array in spans:
		if float(span[1]) - float(span[0]) <= 0.0001:
			continue  # a zero-length run is not a wall
		out.append({
			"axis": axis, "at": at, "min": float(span[0]), "max": float(span[1]),
			"outward": outward, "elevation": elevation, "style": style,
		})


## Just the ground, without any aperture. This is what the sim registers as the permanent
## spatial layer; connections are registered separately because their contribution comes and
## goes with their state.
func patch_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for patch in patches:
		rects.append(patch.rect)
	return rects


## The floor as it stands at load, before any trigger has fired. The sim rebuilds this itself
## the moment patches and connections are registered; this exists so load_floor always receives
## a real region rather than null.
func make_bounds() -> WalkableBounds:
	var open_ids: Dictionary = {}
	for connection in connections:
		open_ids[connection.connection_id] = connection.starts_open
	return WalkableBounds.new(open_walkable_rects(open_ids), obstacle_rects())


## Every rect that is solid AT FLOOR LOAD: permanent obstacles, plus destructibles that occupy
## ground until broken. The sim retires a destructible's share when it is destroyed, which is the
## only difference between the two -- and the reason they share one representation.
func obstacle_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for obstacle in obstacles:
		rects.append(obstacle.rect)
	for breakable in breakables:
		if breakable.blocking_rect.get_area() > 0.0:
			rects.append(breakable.blocking_rect)
	return rects


func patch_by_id(patch_id: int) -> WalkablePatch:
	for patch in patches:
		if patch.patch_id == patch_id:
			return patch
	return null


func encounter_by_id(encounter_id: int) -> EncounterSite:
	for encounter in encounters:
		if encounter.encounter_id == encounter_id:
			return encounter
	return null


func encounters_of_role(role: StringName) -> Array[EncounterSite]:
	var matching: Array[EncounterSite] = []
	for encounter in encounters:
		if encounter.role == role:
			matching.append(encounter)
	return matching


## Every spawn on the floor, flattened, each tagged with the site that OWNS it. Ownership rides
## with the record because confinement is unconditional -- an actor without a site has no legal
## region, so the driver must never lose the association.
func all_spawns() -> Array[Dictionary]:
	var flattened: Array[Dictionary] = []
	for encounter in encounters:
		for spawn in encounter.roster:
			flattened.append({
				"enemy_key": spawn["enemy_key"],
				"position": spawn["position"],
				"encounter_id": encounter.encounter_id,
			})
	return flattened


## Canonical serialization for the golden fixture (GAME-RULES §5 M2: same seed -> byte-identical
## FloorPlan). Floats snap to 4 decimals: raw determinism is proved separately in memory by
## test_depth_generator.gd, so this only has to catch BEHAVIOURAL drift, and encoding float
## print-formatting would make the fixture fail on an engine patch bump for a reason unrelated
## to generation changing.
func to_dict() -> Dictionary:
	var patch_dicts: Array = []
	for patch in patches:
		patch_dicts.append({
			"patch_id": patch.patch_id, "rect": _rect(patch.rect),
			"elevation": _snap(patch.elevation), "surface": String(patch.surface),
			"boundary_style": String(patch.boundary_style),
			"boundary_north": String(patch.boundary_north), "boundary_south": String(patch.boundary_south),
			"boundary_east": String(patch.boundary_east), "boundary_west": String(patch.boundary_west),
		})
	var connection_dicts: Array = []
	for connection in connections:
		connection_dicts.append({
			"connection_id": connection.connection_id,
			"patch_ids": [connection.patch_ids.x, connection.patch_ids.y],
			"aperture": _rect(connection.aperture),
			"starts_open": connection.starts_open, "has_barrier": connection.has_barrier,
		})
	var trigger_dicts: Array = []
	for trigger in triggers:
		trigger_dicts.append({
			"trigger_id": trigger.trigger_id, "kind": String(trigger.kind),
			"region": _rect(trigger.region), "source_id": trigger.source_id,
			"once": trigger.once, "starts_enabled": trigger.starts_enabled,
			"renders_as_plate": trigger.renders_as_plate, "effects": trigger.effects.map(func(e): return {"kind": String(e["kind"]), "target_id": e["target_id"]}),
		})
	var encounter_dicts: Array = []
	for encounter in encounters:
		var roster: Array = []
		for spawn in encounter.roster:
			roster.append({"enemy_key": String(spawn["enemy_key"]), "position": _point(spawn["position"])})
		var region_dicts: Array = []
		for region: Rect2 in encounter.regions:
			region_dicts.append(_rect(region))
		encounter_dicts.append({
			"encounter_id": encounter.encounter_id, "regions": region_dicts,
			"role": String(encounter.role), "confines_player": encounter.confines_player,
			"spawn_at_floor_load": encounter.spawn_at_floor_load, "roster": roster,
		})
	var breakable_dicts: Array = []
	for breakable in breakables:
		breakable_dicts.append({
			"breakable_id": breakable.breakable_id, "position": _point(breakable.position),
			"radius": _snap(breakable.radius), "durability": _snap(breakable.durability),
			"conceals_trigger_id": breakable.conceals_trigger_id,
		})
	return {
		"run_seed": run_seed, "floor_seed": floor_seed, "depth": depth,
		"stratum_id": String(stratum_id), "authored_layout": authored_layout,
		"patches": patch_dicts, "connections": connection_dicts, "triggers": trigger_dicts,
		"encounters": encounter_dicts, "breakables": breakable_dicts,
		"entry_point": _point(entry_point), "end_marker": _point(end_marker),
	}


func _rect(rect: Rect2) -> Dictionary:
	return {"x": _snap(rect.position.x), "z": _snap(rect.position.y), "w": _snap(rect.size.x), "d": _snap(rect.size.y)}


func _point(point: Vector3) -> Dictionary:
	return {"x": _snap(point.x), "y": _snap(point.y), "z": _snap(point.z)}


func _snap(value: float) -> float:
	return snappedf(value, 0.0001)


# --- AUTHORING VALIDATION ----------------------------------------------------------------
#
# Structural guards in the same family as _reject_style_conflicts: they DETECT authoring
# errors loudly and never repair them, because a silent repair would make the authored floor
# and the played floor two different floors.
#
# Run on EVERY produced plan by DepthGenerator.generate, whoever produced it -- so a future
# procedural producer inherits them without being asked to remember.


## `body_radii` maps an enemy key to its authored combat radius. Supplied by the producer, so
## this class never reaches for the ContentDB autoload; omit it and the clearance guard simply
## does not run, which keeps every hand-built test fixture working unchanged.
func validate(body_radii: Dictionary = {}) -> void:
	_reject_unnamed_connection_patches()
	_reject_bypassable_gates()
	_reject_impassable_apertures(body_radii)


## A connection that does not name the patches it joins cannot be checked by anything above,
## and presentation reads the same field to place its corridor slab at the right elevation --
## an unnamed connection silently draws at y=0, so a ramp's corridor floats or sinks.
func _reject_unnamed_connection_patches() -> void:
	for connection in connections:
		for patch_id: int in [connection.patch_ids.x, connection.patch_ids.y]:
			if patch_by_id(patch_id) == null:
				push_error(("FloorPlan: connection %d names patch %d, which does not exist. A connection must "
					+ "declare the two patches it joins: every structural check above reads that field, and so "
					+ "does the corridor's elevation.") % [connection.connection_id, patch_id])
				break
		if patch_by_id(connection.patch_ids.x) == null or patch_by_id(connection.patch_ids.y) == null:
			continue
		for patch_id: int in [connection.patch_ids.x, connection.patch_ids.y]:
			if connection.aperture.intersection(patch_by_id(patch_id).rect).get_area() <= 0.0:
				push_error(("FloorPlan: aperture %d only abuts patch %d rather than overlapping it. A zero-area "
					+ "junction makes the threshold a discontinuity the clamp cannot reason about.")
					% [connection.connection_id, patch_id])


## THE CLOSED-GATE INTEGRITY LAW (added 2026-09-02, after Floor 2's human replay).
##
## A CLOSED CONNECTION CLAIMS TO SEPARATE TWO PATCHES. Nothing previously checked that it does.
## Closing a gate removes its aperture from the walkable union and subtracts NOTHING -- so if
## the two patches also touch each other directly, the union still spans the seam and the gate
## separates nothing at all. Floor 2 shipped two such gates; both were purely decorative, and a
## walk straight south entered the "gated" shortcut without ever finding its control.
##
## WHY TOUCHING IS ENOUGH TO BE A BYPASS. Walkable edges are INCLUSIVE and legality is
## BODY-AWARE against the UNION, so a body straddling the seam of two abutting rects is covered
## by both halves and fits perfectly. "Zero shared area" therefore does NOT mean "not connected"
## -- an older comment in WalkableBounds said otherwise and was wrong once bodies arrived.
##
## SCOPE, STATED HONESTLY. This proves a gate is the only DIRECT adjacency between its two
## patches. It does NOT prove global separation, and must not: routes that fork and rejoin
## elsewhere are legitimate floor grammar, so "you can get there the long way round" is a
## routing fact rather than a broken gate. A bypass through a THIRD patch bridging both would
## not be caught here; that case is indistinguishable from an intended rejoin without authorial
## intent the plan does not record.
##
## APPLIES TO EVERY CLOSABLE CONNECTION, not merely those that start shut: a one-way commitment
## starts open and is blocked later, and a commitment that seals nothing is the same defect.
func _reject_bypassable_gates() -> void:
	for connection in connections:
		if not _is_closable(connection.connection_id):
			continue
		var a: WalkablePatch = patch_by_id(connection.patch_ids.x)
		var b: WalkablePatch = patch_by_id(connection.patch_ids.y)
		if a == null or b == null:
			continue  # already reported above
		if not _touches(a.rect, b.rect):
			continue
		push_error(("FloorPlan: connection %d can be closed, but patches %d and %d touch directly at %s -- "
			+ "so the walkable union spans their seam whether the gate is open or shut and the gate separates "
			+ "nothing. Patches joined by a closable connection must be DISJOINT, with the aperture as the only "
			+ "thing bridging them.") % [connection.connection_id, a.patch_id, b.patch_id,
			str(a.rect.intersection(b.rect)) if a.rect.intersects(b.rect) else "their shared edge"])


## Can this connection ever be shut? Either it starts that way, or some authored effect blocks it.
func _is_closable(connection_id: int) -> bool:
	for connection in connections:
		if connection.connection_id == connection_id and not connection.starts_open:
			return true
	for trigger in triggers:
		for authored_effect: Dictionary in trigger.effects:
			if authored_effect.get("kind", &"") == FloorLayers.EFFECT_BLOCK_CONNECTION \
					and int(authored_effect.get("target_id", -1)) == connection_id:
				return true
	return false


## INCLUSIVE on every edge, matching WalkableBounds: two rects that merely abut DO touch, because
## a body straddling that seam is legal. This is the whole point of the guard.
static func _touches(a: Rect2, b: Rect2) -> bool:
	return a.position.x <= b.end.x and b.position.x <= a.end.x \
			and a.position.y <= b.end.y and b.position.y <= a.end.y


## RETIRED 2026-09-02, the day after it was added: _reject_misoriented_gate_barriers.
##
## It guarded a symptom. The sim used to infer a closed gate's barrier orientation from the
## APERTURE'S proportions, so the guard refused aperture shapes that would be misread. The root
## fix (ruled) derives the barrier from the patches a connection joins instead, and once shape
## no longer decides anything there is nothing left for a shape guard to refuse -- the check
## could only ever fire on floors that are now correct.
##
## Removed rather than left passing: a guard that cannot fail is not evidence, and reading one
## as though it were is how a suite starts lying. What it protected is now covered directly by
## tests/test_gate_integrity.gd, which fires real shots at real gates in both orientations.


## IF A FLOOR AUTHORS A PASSAGE, THE ROSTER MUST ACTUALLY FIT THROUGH IT (ruled 2026-09-03).
##
## Nothing checked this. An aperture is the ONLY walkable ground spanning the gap between two
## disjoint patches, so a body crossing it must fit within its width ACROSS TRAVEL -- and a body
## wider than that meets an opening it can see, is authored to use, and cannot enter. The floor
## looks passable and is not, for that actor alone.
##
## MEASURED AGAINST EVERY BODY AUTHORED ON THE FLOOR, not against the roster nearest the door.
## Pursuit, retreat and knockback all move actors through openings their own encounter never
## mentioned, so "which roster was this door meant for" is not a question the plan can answer
## honestly. The widest authored body is the truthful bar.
##
## THE FIX IS THE FLOOR'S, NOT THE CONTENT'S. This never suggests shrinking an actor: a doorway
## too small for a shipped body is an authoring error in the doorway.
func _reject_impassable_apertures(body_radii: Dictionary) -> void:
	if body_radii.is_empty():
		return
	var widest: float = 0.0
	var widest_key: StringName = &""
	for encounter in encounters:
		for spawn: Dictionary in encounter.roster:
			var key: StringName = spawn.get("enemy_key", &"")
			var radius: float = float(body_radii.get(key, 0.0))
			if radius > widest:
				widest = radius
				widest_key = key
	if widest <= 0.0:
		return
	for connection in connections:
		var a: WalkablePatch = patch_by_id(connection.patch_ids.x)
		var b: WalkablePatch = patch_by_id(connection.patch_ids.y)
		if a == null or b == null:
			continue
		# Only a connection bridging a real GAP is load-bearing; where patches already overlap,
		# the aperture is not the only ground and its width constrains nothing.
		var apart_on_x: bool = a.rect.end.x < b.rect.position.x or b.rect.end.x < a.rect.position.x
		var apart_on_z: bool = a.rect.end.y < b.rect.position.y or b.rect.end.y < a.rect.position.y
		if apart_on_x == apart_on_z:
			continue
		var across: float = connection.aperture.size.y if apart_on_x else connection.aperture.size.x
		if across - widest * 2.0 <= 0.0:
			push_error(("FloorPlan: connection %d is %.1f wide across travel, but the widest body authored "
				+ "on this floor (%s, radius %.2f) needs more than %.1f. That opening is visible, walkable "
				+ "for the Envoy, and impassable for an actor the floor itself places. Widen the aperture; "
				+ "never shrink the actor.")
				% [connection.connection_id, across, widest_key, widest, widest * 2.0])
