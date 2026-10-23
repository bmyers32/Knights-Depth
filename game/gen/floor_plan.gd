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
## The place's own name, when it has one; empty means "known by its stratum". Resolved floor
## data, so a Terminal reads as a Terminal whatever stratum config it currently borrows.
var place_label: String = ""
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
var carriables: Array[CarriablePlan] = []

## Where the Envoy arrives.
var entry_point: Vector3 = Vector3.ZERO
## Deterministic terminal endpoint. NOT an elevator, no transition logic, no run-end UI --
## it exists so the traversal grammar has a visible end.
var end_marker: Vector3 = Vector3.ZERO
## The exit's information console: inspected with the attack press, read-only, never a trigger.
## Level content like the marker, so it is serialized and the goldens notice if it moves.
var exit_console: Vector3 = Vector3.ZERO


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
	# Aperture SIDES are boundaries like any other: a corridor has flanks. Whether the corridor is
	# passable is a gate question (connection state), never a static-geometry one -- and HOW TALL
	# those flanks stand is an authoring question, not a fact about corridors. A doorway through an
	# enclosed room wants a wall; a hallway between two open spaces wants a rim.
	for connection in connections:
		_segments_of(connection.aperture, 0.0, rects, segments, connection.flank_style)
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
	# THE COMPLEMENT HAS TO BE AN ACTUAL COMPLEMENT (fixed 2026-09-09). This call omitted the
	# connection's flank style and so re-derived every aperture as `wall` -- while solid_segments()
	# derived the same flanks as `ledge`. A rimmed connector was therefore dropped by BOTH filters:
	# no wall from one, no lip from the other, and a hallway whose edges simply were not there.
	#
	# The two functions are documented as the same pass read two ways, and they were kept in step
	# by hand until one of them was changed. There is now a test asserting they stay complements.
	for connection in connections:
		_segments_of(connection.aperture, 0.0, rects, segments, connection.flank_style)
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


static func _segments_of(rect: Rect2, elevation: float, rects: Array[Rect2], out: Array[Dictionary], style: StringName = &"wall") -> void:
	# WEST edge: solid wherever the strip immediately west of it is not walkable.
	_emit(out, &"x", rect.position.x, -1.0, elevation, style,
		_uncovered_span(rect.position.y, rect.end.y, rects, true, rect.position.x, -1.0))
	_emit(out, &"x", rect.end.x, 1.0, elevation, style,
		_uncovered_span(rect.position.y, rect.end.y, rects, true, rect.end.x, 1.0))
	_emit(out, &"z", rect.position.y, -1.0, elevation, style,
		_uncovered_span(rect.position.x, rect.end.x, rects, false, rect.position.y, -1.0))
	_emit(out, &"z", rect.end.y, 1.0, elevation, style,
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
			"flank_style": String(connection.flank_style),
		})
	var trigger_dicts: Array = []
	for trigger in triggers:
		trigger_dicts.append({
			"trigger_id": trigger.trigger_id, "kind": String(trigger.kind),
			"region": _rect(trigger.region), "source_id": trigger.source_id,
			"once": trigger.once, "starts_enabled": trigger.starts_enabled,
			"renders_as_plate": trigger.renders_as_plate, "effects": _effects(trigger.effects),
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
			"blocking_rect": _rect(breakable.blocking_rect),
		})
	var switch_dicts: Array = []
	for hit_switch in hit_switches:
		switch_dicts.append({
			"switch_id": hit_switch.switch_id, "position": _point(hit_switch.position),
			"radius": _snap(hit_switch.radius), "mode": String(hit_switch.mode),
			"starts_hidden": hit_switch.starts_hidden, "effects": _effects(hit_switch.effects),
		})
	var obstacle_dicts: Array = []
	for obstacle in obstacles:
		# `height` is rendering-only, and is here anyway: the snapshot protects the whole compiled
		# plan, not just the fields gameplay reads (ruled 2026-10-09).
		obstacle_dicts.append({
			"obstacle_id": obstacle.obstacle_id, "rect": _rect(obstacle.rect),
			"height": _snap(obstacle.height),
		})
	var pad_dicts: Array = []
	for pad in spike_pads:
		pad_dicts.append({
			"pad_id": pad.pad_id, "rect": _rect(pad.rect),
			"safe_ticks": pad.safe_ticks, "active_ticks": pad.active_ticks,
			"phase_offset_ticks": pad.phase_offset_ticks, "damage": _snap(pad.damage),
			"damage_type": String(pad.damage_type),
			"eligible_allegiances": pad.eligible_allegiances.map(func(a): return String(a)),
		})
	# ALWAYS SERIALIZED, EMPTY OR NOT (ruled 2026-10-16): the snapshot's shape must not depend on
	# what a floor happens to contain, because the same plain data is what M3 hands a client.
	var carriable_dicts: Array = []
	for carriable in carriables:
		carriable_dicts.append({
			"carriable_id": carriable.carriable_id, "position": _point(carriable.position),
			"starts_hidden": carriable.starts_hidden,
		})
	return {
		"run_seed": run_seed, "floor_seed": floor_seed, "depth": depth,
		"stratum_id": String(stratum_id), "place_label": place_label,
		"authored_layout": authored_layout,
		"patches": patch_dicts, "connections": connection_dicts, "triggers": trigger_dicts,
		"encounters": encounter_dicts, "breakables": breakable_dicts,
		"hit_switches": switch_dicts, "obstacles": obstacle_dicts, "spike_pads": pad_dicts,
		"carriables": carriable_dicts,
		"entry_point": _point(entry_point), "end_marker": _point(end_marker),
		"exit_console": _point(exit_console),
	}


func _effects(effects: Array[Dictionary]) -> Array:
	var effect_dicts: Array = []
	for effect in effects:
		effect_dicts.append({"kind": String(effect["kind"]), "target_id": effect["target_id"]})
	return effect_dicts


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
##
## REPORTS, exactly as before: every violation is a push_error. The rules themselves live in
## violations() so a producer that must DECIDE on a plan (a generator rejecting a candidate,
## ADR-001 S0) reads the same findings instead of a second copy of the rules that could drift.
func validate(body_radii: Dictionary = {}) -> void:
	for violation: Dictionary in violations(body_radii):
		push_error(violation["message"])


## THE SAME RULES AS validate(), RETURNED. One record per finding:
##   rule      StringName naming the guard (stable; tests and generators key on it)
##   message   the sentence validate() reports -- the one human-readable truth, not a second one
##   refs      {layer: id, ...} the records involved, by the plan's own numeric ids
## Empty means the plan passed every structural guard. Detection only, never repair.
func violations(body_radii: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_check_unnamed_connection_patches(out)
	_check_bypassable_gates(out)
	_check_impassable_apertures(body_radii, out)
	_check_obstructed_controls(out)
	_check_high_durability_props(out)
	_check_props_off_floor(out)
	_check_unusable_receivers(out)
	return out


static func _violation(rule: StringName, message: String, refs: Dictionary) -> Dictionary:
	return {"rule": rule, "message": message, "refs": refs}


## A connection that does not name the patches it joins cannot be checked by anything above,
## and presentation reads the same field to place its corridor slab at the right elevation --
## an unnamed connection silently draws at y=0, so a ramp's corridor floats or sinks.
func _check_unnamed_connection_patches(out: Array[Dictionary]) -> void:
	for connection in connections:
		for patch_id: int in [connection.patch_ids.x, connection.patch_ids.y]:
			if patch_by_id(patch_id) == null:
				out.append(_violation(&"unnamed_connection_patch",
					("FloorPlan: connection %d names patch %d, which does not exist. A connection must "
					+ "declare the two patches it joins: every structural check above reads that field, and so "
					+ "does the corridor's elevation.") % [connection.connection_id, patch_id],
					{"connection": connection.connection_id, "patch": patch_id}))
				break
		if patch_by_id(connection.patch_ids.x) == null or patch_by_id(connection.patch_ids.y) == null:
			continue
		for patch_id: int in [connection.patch_ids.x, connection.patch_ids.y]:
			if connection.aperture.intersection(patch_by_id(patch_id).rect).get_area() <= 0.0:
				out.append(_violation(&"abutting_aperture",
					("FloorPlan: aperture %d only abuts patch %d rather than overlapping it. A zero-area "
					+ "junction makes the threshold a discontinuity the clamp cannot reason about.")
					% [connection.connection_id, patch_id],
					{"connection": connection.connection_id, "patch": patch_id}))


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
func _check_bypassable_gates(out: Array[Dictionary]) -> void:
	for connection in connections:
		if not _is_closable(connection.connection_id):
			continue
		var a: WalkablePatch = patch_by_id(connection.patch_ids.x)
		var b: WalkablePatch = patch_by_id(connection.patch_ids.y)
		if a == null or b == null:
			continue  # already reported above
		if not _touches(a.rect, b.rect):
			continue
		out.append(_violation(&"bypassable_gate",
			("FloorPlan: connection %d can be closed, but patches %d and %d touch directly at %s -- "
			+ "so the walkable union spans their seam whether the gate is open or shut and the gate separates "
			+ "nothing. Patches joined by a closable connection must be DISJOINT, with the aperture as the only "
			+ "thing bridging them.") % [connection.connection_id, a.patch_id, b.patch_id,
			str(a.rect.intersection(b.rect)) if a.rect.intersects(b.rect) else "their shared edge"],
			{"connection": connection.connection_id, "patch": a.patch_id, "other_patch": b.patch_id}))


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
func _check_impassable_apertures(body_radii: Dictionary, out: Array[Dictionary]) -> void:
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
			out.append(_violation(&"impassable_aperture",
				("FloorPlan: connection %d is %.1f wide across travel, but the widest body authored "
				+ "on this floor (%s, radius %.2f) needs more than %.1f. That opening is visible, walkable "
				+ "for the Envoy, and impassable for an actor the floor itself places. Widen the aperture; "
				+ "never shrink the actor.")
				% [connection.connection_id, across, widest_key, widest, widest * 2.0],
				{"connection": connection.connection_id}))


## A CONTROL MUST NOT SIT UNDER PERMANENT GEOMETRY (ruled 2026-09-04).
##
## Floor 2 authored a plate overlapping a column, so it poked out from beneath something solid.
## The human read that exactly as it was -- an accident, not concealment -- and the distinction
## matters: GOOD concealment hides a control behind something REMOVABLE, so finding it is an
## action. Clipping under permanent geometry is not discovery language, it is a mistake that
## happens to be partly visible.
##
## Blocking destructibles are deliberately EXEMPT: hiding a control behind something the player
## can clear is the intended vocabulary, and refusing it here would forbid the good case along
## with the bad one.
func _check_obstructed_controls(out: Array[Dictionary]) -> void:
	for trigger in triggers:
		if not trigger.renders_as_plate or trigger.region.get_area() <= 0.0:
			continue
		for obstacle in obstacles:
			if obstacle.rect.intersection(trigger.region).get_area() > 0.0:
				out.append(_violation(&"obstructed_plate",
					("FloorPlan: trigger %d is drawn as a plate at %s but overlaps permanent obstacle %d "
					+ "at %s. A control is either plainly visible or hidden behind something REMOVABLE -- "
					+ "clipping under solid geometry reads as an authoring accident, because it is one.")
					% [trigger.trigger_id, str(trigger.region), obstacle.obstacle_id, str(obstacle.rect)],
					{"trigger": trigger.trigger_id, "obstacle": obstacle.obstacle_id}))
	for hit_switch in hit_switches:
		for obstacle in obstacles:
			if WalkableBounds.contains(obstacle.rect, hit_switch.position.x, hit_switch.position.z):
				out.append(_violation(&"obstructed_switch",
					("FloorPlan: hit-switch %d stands inside permanent obstacle %d. Concealment must be "
					+ "removable; a switch buried in a column is unhittable, not hidden.")
					% [hit_switch.switch_id, obstacle.obstacle_id],
					{"switch": hit_switch.switch_id, "obstacle": obstacle.obstacle_id}))


## AN AUTHORED GAMEPLAY PROP STANDS ON AUTHORED FLOOR (ruled 2026-09-08).
##
## THE CAUSE THIS GUARDS AGAINST IS DRIFT, NOT TYPOS. A prop is authored at an absolute
## coordinate while the room it belongs to is authored as a rect; move the room and the prop
## stays behind. Floor 2 shipped exactly that -- a breakable, targetable search prop left
## standing in void when its bay moved east -- and nothing objected, because every other guard
## asks whether an object is legally placed relative to OTHER objects, not whether it is
## anywhere at all.
##
## Apertures count as floor: a prop in a doorway is a deliberate composition, and one of the
## floor's route blockers lives in exactly that position. Presentation-only decoration is not a
## BreakablePlan and is therefore out of scope by construction -- this rule is about objects the
## player can target and destroy.
func _check_props_off_floor(out: Array[Dictionary]) -> void:
	for breakable in breakables:
		var x: float = breakable.position.x
		var z: float = breakable.position.z
		if not _on_floor(x, z):
			out.append(_violation(&"prop_off_floor",
				("FloorPlan: breakable %d stands at (%.1f, %.1f), which is on no patch and in no "
				+ "aperture. A prop the player can target must stand on ground the player can reach -- "
				+ "this is what a room moving out from under its own contents looks like.")
				% [breakable.breakable_id, x, z],
				{"breakable": breakable.breakable_id}))
	# A KEY IS HELD TO THE SAME LAW, and more strictly: it must be liftable, so it may not stand
	# inside permanent geometry either. Progression that needs it would otherwise be unwinnable.
	for carriable in carriables:
		var x: float = carriable.position.x
		var z: float = carriable.position.z
		if not _on_floor(x, z):
			out.append(_violation(&"carriable_off_floor",
				"FloorPlan: carriable %d stands at (%.1f, %.1f), on no patch and in no aperture."
				% [carriable.carriable_id, x, z],
				{"carriable": carriable.carriable_id}))
		for obstacle in obstacles:
			if WalkableBounds.contains(obstacle.rect, x, z):
				out.append(_violation(&"carriable_in_obstacle",
					"FloorPlan: carriable %d stands inside permanent obstacle %d and can never be lifted."
					% [carriable.carriable_id, obstacle.obstacle_id],
					{"carriable": carriable.carriable_id, "obstacle": obstacle.obstacle_id}))


func _on_floor(x: float, z: float) -> bool:
	for patch in patches:
		if WalkableBounds.contains(patch.rect, x, z):
			return true
	for connection in connections:
		if WalkableBounds.contains(connection.aperture, x, z):
			return true
	return false


## A RECEIVER TAKES ONE DELIVERY AT A REGION YOU CAN STAND IN (2026-10-16). Delivery is decided by
## the Envoy standing in the region, so a zero-area receiver could never be used; and filling is
## recorded as the trigger having fired, so a receiver that could fire again would swallow a
## second key while its gate was already open -- a key lost for nothing.
func _check_unusable_receivers(out: Array[Dictionary]) -> void:
	for trigger in triggers:
		if trigger.kind != FloorLayers.TRIGGER_CARRIABLE_INSERTED:
			continue
		if trigger.region.get_area() <= 0.0:
			out.append(_violation(&"receiver_without_region",
				"FloorPlan: receiver trigger %d has no region to stand in." % trigger.trigger_id,
				{"trigger": trigger.trigger_id}))
		if not trigger.once:
			out.append(_violation(&"receiver_not_once",
				"FloorPlan: receiver trigger %d is not `once`; a receiver accepts exactly one delivery." % trigger.trigger_id,
				{"trigger": trigger.trigger_id}))


## EVERY ENVIRONMENTAL PROP BREAKS IN ONE HIT (ruled 2026-09-04).
##
## Durability is not where challenge lives. A prop that soaks several swings turns clearing
## scenery into fighting a low-health enemy, and the human read exactly that. The difficulty of
## an environmental object comes from positioning, ordering, consequence, timing and the enemies
## around it -- never from its hit points.
##
## THE ALTERNATIVE IS EXPLICITNESS, not a bigger number: something the player must NOT be able to
## remove is an OBSTACLE, which is unbreakable by construction and says so. A high-HP prop is a
## permanent object wearing a destructible's clothes.
func _check_high_durability_props(out: Array[Dictionary]) -> void:
	for breakable in breakables:
		if breakable.durability > 1.0:
			out.append(_violation(&"high_durability_prop",
				("FloorPlan: breakable %d has durability %.1f. Every environmental prop breaks in ONE "
				+ "hit -- challenge comes from positioning and consequence, not from hit points. If it is "
				+ "meant to be permanent, author it as an ObstaclePlan, which cannot be broken at all.")
				% [breakable.breakable_id, breakable.durability],
				{"breakable": breakable.breakable_id}))
