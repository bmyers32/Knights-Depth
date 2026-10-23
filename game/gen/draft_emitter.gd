class_name DraftEmitter
extends RefCounted
## LOWERS A FloorDraft TO ONE FLAT AuthoredLayout (ADR-001 §5.5, S1) -- which the UNCHANGED
## LayoutCompiler then turns into an ordinary FloorPlan. The compiler never learns that pieces
## exist; this is the whole compatibility argument for composition.
##
## IDENTIFIERS BY TABLE, NEVER BY ARITHMETIC. Every piece numbers its records from 0, so two
## placed pieces collide on every layer. The emitter walks the draft in a fixed order -- each
## instance in placement order, each layer in FloorPiece.LAYERS order, each record in body
## order; then the hallway rects; then the joints -- and hands out one dense counter per layer.
## The resulting table `(instance, layer, local id) -> global id` is built COMPLETELY before any
## reference is rewritten, and every reference is then looked up in it BY ITS TARGET LAYER:
##   effects[].target_id        via the compiler's own effect -> layer table
##   trigger.source_id          via the compiler's own trigger kind -> layer table
##   connection.patch_ids       the patch layer
##   breakable.conceals_trigger_id   the trigger layer (the compiler copies this one verbatim,
##                              which is exactly the reference an offset scheme forgets)
## Keys become `iNN.KEY` so the emitted layout stays legible and stays unambiguous. `@port` on a
## connection effect resolves to the joint bound at that port.
##
## SENTINELS ARE NEVER REMAPPED. -1 means "no target" (FloorLayers.NO_TARGET) and survives
## untouched where a reference is permitted to be absent; a -1 where a target is required is an
## error. The exit console is one plan field registered under the sim's fixed console id, in a
## registry of its own -- no layer counter can reach it, and the emitter asserts exactly one
## exit piece supplies it.
##
## A STRUCTURAL FAULT IS A REPORT WITH NO LAYOUT, never a plausible floor with a wrong id in it.
## An unresolved reference, an unbound port, a transform the piece did not allow, overlapping
## footprints, a joint whose hallway does not meet its port, a gate with no gap, two patches of
## different pieces touching where no joint says they may -- each is a named error; the caller
## decides what to do (S2: reject the attempt), never the emitter.
##
## THE CANONICAL ORDER IS THE CONTRACT. A hand-authored floor equals an emitted one only if it
## lists its records in this same order with these same ids; that is deliberate, so equality of
## FloorPlan.to_dict() can be asserted exactly rather than hidden behind a normaliser.

## The outcome of one emission.
class EmitReport:
	extends RefCounted
	## The flat layout, or null when `errors` is not empty.
	var layout: AuthoredLayout = null
	## {kind, message, refs} -- structural failures, in the order they were found.
	var errors: Array[Dictionary] = []
	## instance/hallway/joint id -> layer -> local id -> global id.
	var remap: Dictionary = {}
	## instance id -> local key -> global key.
	var keys: Dictionary = {}
	## instance id -> local key -> {layer, local_id}: which record, in which layer, a key names.
	var key_records: Dictionary = {}
	## joint id -> {connection_id, aperture, gap, patch_id, hallway_patch_id}.
	var joints: Dictionary = {}

	func is_ok() -> bool:
		return errors.is_empty() and layout != null

	func global_id(owner_id: StringName, layer: StringName, local_id: int) -> int:
		return int(remap.get(owner_id, {}).get(layer, {}).get(local_id, -1))

	func global_key(instance_id: StringName, local_key: StringName) -> StringName:
		return keys.get(instance_id, {}).get(local_key, &"")

	func errors_of(kind: StringName) -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for error: Dictionary in errors:
			if error["kind"] == kind:
				found.append(error)
		return found

	func summary() -> String:
		if is_ok():
			return "emit: OK (%d patches, %d connections, %d triggers)" % [layout.patches.size(), layout.connections.size(), layout.triggers.size()]
		var lines: PackedStringArray = ["emit: FAILED with %d error(s)" % errors.size()]
		for error: Dictionary in errors:
			lines.append("  %s: %s" % [error["kind"], error["message"]])
		return "\n".join(lines)


const _EPSILON: float = 0.0001


static func emit(draft: FloorDraft) -> EmitReport:
	var report := EmitReport.new()
	_check_draft(draft, report)
	if not report.errors.is_empty():
		return report
	_allocate(draft, report)
	var bound: Dictionary = _resolve_joints(draft, report)
	if not report.errors.is_empty():
		return report
	var layout := AuthoredLayout.new()
	layout.layout_id = draft.draft_id
	layout.place_label = draft.place_label
	layout.stratum_id = draft.stratum_id
	var sources: Dictionary = {}  # global patch id -> the instance or hallway it came from
	for instance: FloorDraft.PieceInstance in draft.instances:
		_emit_instance(draft, instance, bound, report, layout, sources)
	for hallway: FloorDraft.HallwayFragment in draft.hallways:
		_emit_hallway(hallway, report, layout, sources)
	for joint: FloorDraft.Joint in draft.joints:
		_emit_joint(joint, report, layout)
	_emit_markers(draft, layout)
	_check_adjacency(draft, report, layout, sources)
	if not report.errors.is_empty():
		return report
	report.layout = layout
	return report


# --- 1. THE DRAFT ITSELF --------------------------------------------------------------------

static func _check_draft(draft: FloorDraft, report: EmitReport) -> void:
	if draft.draft_id == &"":
		_error(report, &"draft_id_missing", "DraftEmitter: the draft has no id", {})
	if draft.instances.is_empty():
		_error(report, &"draft_empty", "DraftEmitter: nothing is placed", {})
	var roles: Dictionary = {}
	var seen_ids: Dictionary = {}
	for instance: FloorDraft.PieceInstance in draft.instances:
		if seen_ids.has(instance.instance_id):
			_error(report, &"instance_id_duplicate", "DraftEmitter: instance '%s' appears twice" % instance.instance_id, {"instance": instance.instance_id})
		seen_ids[instance.instance_id] = true
		if instance.piece == null:
			_error(report, &"piece_missing", "DraftEmitter: instance '%s' places no piece" % instance.instance_id, {"instance": instance.instance_id})
			continue
		var piece: FloorPiece = instance.piece
		if not instance.transform in FloorPiece.SUPPORTED_TRANSFORMS:
			_error(report, &"transform_unsupported", "DraftEmitter: instance '%s' asks for transform '%s', which the emitter cannot apply"
				% [instance.instance_id, instance.transform], {"instance": instance.instance_id, "transform": instance.transform})
		elif not piece.allows(instance.transform):
			# O6: a piece that did not opt in is never mirrored quietly.
			_error(report, &"transform_not_allowed", "DraftEmitter: instance '%s' asks for transform '%s', which piece '%s' does not allow (%s)"
				% [instance.instance_id, instance.transform, piece.piece_id, piece.allowed_transforms],
				{"instance": instance.instance_id, "piece": piece.piece_id, "transform": instance.transform})
		for finding: Dictionary in piece.lint():
			_error(report, &"piece_lint_failed", "DraftEmitter: instance '%s' (%s): %s" % [instance.instance_id, finding["rule"], finding["message"]],
				{"instance": instance.instance_id, "piece": piece.piece_id, "rule": finding["rule"], "refs": finding["refs"]})
		roles[piece.role] = int(roles.get(piece.role, 0)) + 1
		if piece.body != null and piece.body.stratum_id != draft.stratum_id:
			_error(report, &"stratum_mismatch", "DraftEmitter: instance '%s' belongs to stratum '%s', the draft to '%s'"
				% [instance.instance_id, piece.body.stratum_id, draft.stratum_id], {"instance": instance.instance_id})
	for role: StringName in [FloorPiece.ROLE_ENTRY, FloorPiece.ROLE_EXIT]:
		if int(roles.get(role, 0)) != 1:
			_error(report, &"role_count", "DraftEmitter: a floor places exactly one %s piece, found %d" % [role, int(roles.get(role, 0))],
				{"role": role, "count": int(roles.get(role, 0))})
	if not report.errors.is_empty():
		return
	# FOOTPRINTS NEVER OVERLAP, and connective ground never enters one: a piece's interior is its
	# author's, and the only ground allowed to meet it is a joint's.
	for a_index: int in draft.instances.size():
		var a: FloorDraft.PieceInstance = draft.instances[a_index]
		var a_footprint: Rect2 = FloorDraft.world_footprint(a)
		for b_index: int in range(a_index + 1, draft.instances.size()):
			var b: FloorDraft.PieceInstance = draft.instances[b_index]
			if a_footprint.intersection(FloorDraft.world_footprint(b)).get_area() > 0.0:
				_error(report, &"footprint_overlap", "DraftEmitter: footprints of '%s' %s and '%s' %s overlap"
					% [a.instance_id, a_footprint, b.instance_id, FloorDraft.world_footprint(b)], {"instance": a.instance_id, "other": b.instance_id})
		for hallway: FloorDraft.HallwayFragment in draft.hallways:
			for rect: Rect2 in hallway.rects:
				if rect.get_area() <= 0.0:
					_error(report, &"hallway_rect_empty", "DraftEmitter: hallway '%s' has a rect with no area" % hallway.hallway_id, {"hallway": hallway.hallway_id})
				elif a_footprint.intersection(rect).get_area() > 0.0:
					_error(report, &"hallway_inside_footprint", "DraftEmitter: hallway '%s' rect %s enters the footprint of '%s' %s"
						% [hallway.hallway_id, rect, a.instance_id, a_footprint], {"hallway": hallway.hallway_id, "instance": a.instance_id})


# --- 2. IDENTITIES ----------------------------------------------------------------------------

## One counter per layer; the whole table exists before anything is rewritten.
static func _allocate(draft: FloorDraft, report: EmitReport) -> void:
	var next: Dictionary = {}
	for layer: StringName in FloorPiece.LAYERS:
		next[layer] = 0
	for instance: FloorDraft.PieceInstance in draft.instances:
		var table: Dictionary = {}
		var key_table: Dictionary = {}
		var key_records: Dictionary = {}
		for layer: StringName in FloorPiece.LAYERS:
			var ids: Dictionary = {}
			for record: Resource in instance.piece.body.records_in(layer):
				var local_id: int = AuthoredLayout._numeric_id(record)
				ids[local_id] = int(next[layer])
				next[layer] = int(next[layer]) + 1
				if record.key != &"":
					key_table[record.key] = _prefixed(instance.instance_id, record.key)
					key_records[record.key] = {"layer": layer, "local_id": local_id}
			table[layer] = ids
		report.remap[instance.instance_id] = table
		report.keys[instance.instance_id] = key_table
		report.key_records[instance.instance_id] = key_records
	for hallway: FloorDraft.HallwayFragment in draft.hallways:
		var ids: Dictionary = {}
		for index: int in hallway.rects.size():
			ids[index] = int(next[&"patch"])
			next[&"patch"] = int(next[&"patch"]) + 1
		report.remap[hallway.hallway_id] = {&"patch": ids}
	for joint: FloorDraft.Joint in draft.joints:
		report.remap[joint.joint_id] = {&"connection": {0: int(next[&"connection"])}}
		next[&"connection"] = int(next[&"connection"]) + 1


static func _prefixed(instance_id: StringName, key: StringName) -> StringName:
	return StringName("%s.%s" % [instance_id, key])


static func _hallway_key(hallway_id: StringName, index: int) -> StringName:
	return StringName("%s.R%d" % [hallway_id, index])


# --- 3. JOINTS --------------------------------------------------------------------------------

## Binds each joint to the hallway rect that faces its port: the rect must lie on the port's
## outward side with a non-negative gap and cover the port's span across. Returns
## "instance/port" -> joint info, for `@port` resolution.
static func _resolve_joints(draft: FloorDraft, report: EmitReport) -> Dictionary:
	var bound: Dictionary = {}
	var used_hallways: Dictionary = {}
	for joint: FloorDraft.Joint in draft.joints:
		var instance: FloorDraft.PieceInstance = draft.instance_of(joint.instance_id)
		if instance == null:
			_error(report, &"joint_instance_unknown", "DraftEmitter: joint '%s' names instance '%s', which is not placed" % [joint.joint_id, joint.instance_id], {"joint": joint.joint_id})
			continue
		var port: PiecePort = instance.piece.port(joint.port_key)
		if port == null or not port.is_joinable():
			_error(report, &"joint_port_unknown", "DraftEmitter: joint '%s' names port '%s' of '%s', which is not a connector or gate"
				% [joint.joint_id, joint.port_key, joint.instance_id], {"joint": joint.joint_id, "port": joint.port_key})
			continue
		var hallway: FloorDraft.HallwayFragment = draft.hallway_of(joint.hallway_id)
		if hallway == null:
			_error(report, &"joint_hallway_unknown", "DraftEmitter: joint '%s' names hallway '%s', which is not laid" % [joint.joint_id, joint.hallway_id], {"joint": joint.joint_id})
			continue
		used_hallways[joint.hallway_id] = true  # named by a joint, whether or not that joint resolves
		var slot: String = "%s/%s" % [joint.instance_id, joint.port_key]
		if bound.has(slot):
			_error(report, &"port_bound_twice", "DraftEmitter: port '%s' of '%s' is bound by '%s' and again by '%s'"
				% [joint.port_key, joint.instance_id, bound[slot]["joint_id"], joint.joint_id], {"joint": joint.joint_id, "port": joint.port_key})
			continue
		if joint.overlap <= 0.0:
			_error(report, &"joint_overlap_invalid", "DraftEmitter: joint '%s' overlaps its patches by %s; an aperture must reach into both" % [joint.joint_id, joint.overlap], {"joint": joint.joint_id})
			continue
		var span: Dictionary = FloorDraft.port_span(instance, port)
		var along_x: bool = PiecePort.runs_along_x(FloorDraft.world_edge(instance, port.edge))
		var outward: float = float(span["outward"])
		var at: float = float(span["at"])
		# THE RECT A PORT ENTERS IS NAMED OR UNIQUE, never the nearest of several (S2 ruling): a
		# joint that names no rect binds the ONE rect that faces its port, and two facing rects
		# are an ambiguity the emitter refuses rather than resolves.
		var facing: Array[int] = []
		var gaps: Dictionary = {}
		for index: int in hallway.rects.size():
			if joint.rect_index >= 0 and index != joint.rect_index:
				continue
			var rect: Rect2 = hallway.rects[index]
			var covers: bool
			var gap: float
			if along_x:
				covers = rect.position.x <= float(span["from"]) + _EPSILON and rect.end.x >= float(span["to"]) - _EPSILON
				gap = (rect.position.y - at) if outward > 0.0 else (at - rect.end.y)
			else:
				covers = rect.position.y <= float(span["from"]) + _EPSILON and rect.end.y >= float(span["to"]) - _EPSILON
				gap = (rect.position.x - at) if outward > 0.0 else (at - rect.end.x)
			if covers and gap >= -_EPSILON:
				facing.append(index)
				gaps[index] = maxf(gap, 0.0)
		if joint.rect_index >= hallway.rects.size():
			_error(report, &"joint_rect_unknown", "DraftEmitter: joint '%s' names rect %d of hallway '%s', which has %d" % [joint.joint_id, joint.rect_index, joint.hallway_id, hallway.rects.size()],
				{"joint": joint.joint_id, "hallway": joint.hallway_id, "rect_index": joint.rect_index})
			continue
		if facing.is_empty():
			_error(report, &"joint_unmet", "DraftEmitter: joint '%s': no rect of hallway '%s' lies beyond port '%s' of '%s' (%s edge at %s, span [%s, %s]) and covers it"
				% [joint.joint_id, joint.hallway_id, joint.port_key, joint.instance_id, FloorDraft.world_edge(instance, port.edge), at, span["from"], span["to"]],
				{"joint": joint.joint_id, "port": joint.port_key, "hallway": joint.hallway_id})
			continue
		if facing.size() > 1:
			_error(report, &"joint_ambiguous", "DraftEmitter: joint '%s': rects %s of hallway '%s' all face port '%s' of '%s'; name one with rect_index"
				% [joint.joint_id, facing, joint.hallway_id, joint.port_key, joint.instance_id],
				{"joint": joint.joint_id, "hallway": joint.hallway_id, "rects": facing})
			continue
		var best_index: int = facing[0]
		var best_gap: float = float(gaps[best_index])
		if port.kind == PiecePort.KIND_GATE and best_gap <= _EPSILON:
			# A closable connection between touching patches separates nothing (the closed-gate
			# integrity law, FloorPlan). The gap is what makes the gate real.
			_error(report, &"gate_without_gap", "DraftEmitter: joint '%s' is a gate, but hallway '%s' touches port '%s' of '%s' directly; a gate needs a gap its aperture can close"
				% [joint.joint_id, joint.hallway_id, joint.port_key, joint.instance_id], {"joint": joint.joint_id, "port": joint.port_key})
			continue
		var width: float = float(span["to"]) - float(span["from"])
		var depth: float = best_gap + 2.0 * joint.overlap
		var near: float = (at - joint.overlap) if outward > 0.0 else (at - best_gap - joint.overlap)
		var aperture: Rect2 = Rect2(float(span["from"]), near, width, depth) if along_x else Rect2(near, float(span["from"]), depth, width)
		var info: Dictionary = {
			"joint_id": joint.joint_id, "connection_id": report.global_id(joint.joint_id, &"connection", 0),
			"aperture": aperture, "gap": best_gap, "gate": port.kind == PiecePort.KIND_GATE,
			"patch_key": report.global_key(joint.instance_id, port.patch_key),
			"patch_id": report.global_id(joint.instance_id, &"patch", _local_patch_id(instance.piece, port.patch_key)),
			"hallway_patch_key": _hallway_key(joint.hallway_id, best_index),
			"hallway_patch_id": report.global_id(joint.hallway_id, &"patch", best_index),
		}
		bound[slot] = info
		report.joints[joint.joint_id] = info
	for hallway: FloorDraft.HallwayFragment in draft.hallways:
		if not used_hallways.has(hallway.hallway_id):
			_error(report, &"hallway_unbound", "DraftEmitter: hallway '%s' is bound to no port" % hallway.hallway_id, {"hallway": hallway.hallway_id})
	return bound


static func _local_patch_id(piece: FloorPiece, key: StringName) -> int:
	for patch: WalkablePatch in piece.body.patches:
		if patch.key == key:
			return patch.patch_id
	return -1


# --- 4. RECORDS -------------------------------------------------------------------------------

static func _emit_instance(draft: FloorDraft, instance: FloorDraft.PieceInstance, bound: Dictionary,
		report: EmitReport, layout: AuthoredLayout, sources: Dictionary) -> void:
	var id: StringName = instance.instance_id
	var body: AuthoredLayout = instance.piece.body
	var mirrored: bool = instance.transform == FloorPiece.TRANSFORM_MIRROR_X
	for patch: WalkablePatch in body.patches:
		var copy := WalkablePatch.new()
		copy.key = _prefixed_or_empty(id, patch.key)
		copy.patch_id = report.global_id(id, &"patch", patch.patch_id)
		copy.rect = FloorDraft.world_rect(instance, patch.rect)
		copy.elevation = patch.elevation
		copy.surface = patch.surface
		copy.boundary_style = patch.boundary_style
		copy.boundary_north = patch.boundary_north
		copy.boundary_south = patch.boundary_south
		# Mirroring swaps the two x-facing sides, exactly as it swaps a port's edge.
		copy.boundary_east = patch.boundary_west if mirrored else patch.boundary_east
		copy.boundary_west = patch.boundary_east if mirrored else patch.boundary_west
		layout.patches.append(copy)
		sources[copy.patch_id] = id
	for connection: TraversalConnection in body.connections:
		var copy := TraversalConnection.new()
		copy.key = _prefixed_or_empty(id, connection.key)
		copy.connection_id = report.global_id(id, &"connection", connection.connection_id)
		var near: Dictionary = _reference(report, id, &"patch", connection.near_key, connection.patch_ids.x, true, "connection '%s' near" % connection.key)
		var far: Dictionary = _reference(report, id, &"patch", connection.far_key, connection.patch_ids.y, true, "connection '%s' far" % connection.key)
		copy.near_key = near["key"]
		copy.far_key = far["key"]
		copy.patch_ids = Vector2i(int(near["id"]), int(far["id"]))
		copy.aperture = FloorDraft.world_rect(instance, connection.aperture)
		copy.starts_open = connection.starts_open
		copy.has_barrier = connection.has_barrier
		copy.flank_style = connection.flank_style
		layout.connections.append(copy)
	for trigger: FloorTrigger in body.triggers:
		var copy := FloorTrigger.new()
		copy.key = _prefixed_or_empty(id, trigger.key)
		copy.trigger_id = report.global_id(id, &"trigger", trigger.trigger_id)
		copy.kind = trigger.kind
		copy.region = FloorDraft.world_rect(instance, trigger.region) if trigger.region.get_area() > 0.0 else trigger.region
		var layer: StringName = LayoutCompiler._TRIGGER_SOURCE_LAYER.get(trigger.kind, &"none")
		if layer == &"none":
			if trigger.source_key != &"" or trigger.source_id >= 0:
				_error(report, &"reference_without_layer", "DraftEmitter: '%s' trigger '%s' of kind '%s' watches nothing, yet names a source"
					% [id, trigger.key, trigger.kind], {"instance": id, "key": trigger.key})
			copy.source_key = &""
			copy.source_id = FloorLayers.NO_TARGET
		else:
			var source: Dictionary = _reference(report, id, layer, trigger.source_key, trigger.source_id, true, "trigger '%s' source" % trigger.key)
			copy.source_key = source["key"]
			copy.source_id = int(source["id"])
		copy.once = trigger.once
		copy.starts_enabled = trigger.starts_enabled
		copy.renders_as_plate = trigger.renders_as_plate
		copy.effects = _effects(report, id, bound, trigger.effects, "trigger '%s'" % trigger.key)
		layout.triggers.append(copy)
	for site: EncounterSite in body.encounters:
		var copy := EncounterSite.new()
		copy.key = _prefixed_or_empty(id, site.key)
		copy.encounter_id = report.global_id(id, &"encounter", site.encounter_id)
		var regions: Array[Rect2] = []
		for region: Rect2 in site.regions:
			regions.append(FloorDraft.world_rect(instance, region))
		copy.regions = regions
		copy.role = site.role
		var roster: Array[Dictionary] = []
		for spawn: Dictionary in site.roster:
			roster.append({"enemy_key": spawn["enemy_key"], "position": FloorDraft.world_point(instance, spawn["position"])})
		copy.roster = roster
		copy.confines_player = site.confines_player
		copy.spawn_at_floor_load = site.spawn_at_floor_load
		layout.encounters.append(copy)
	for breakable: BreakablePlan in body.breakables:
		var copy := BreakablePlan.new()
		copy.key = _prefixed_or_empty(id, breakable.key)
		copy.breakable_id = report.global_id(id, &"breakable", breakable.breakable_id)
		copy.position = FloorDraft.world_point(instance, breakable.position)
		copy.radius = breakable.radius
		copy.durability = breakable.durability
		# The one reference the compiler copies verbatim: it must be remapped HERE or nowhere.
		copy.conceals_trigger_id = FloorLayers.NO_TARGET if breakable.conceals_trigger_id < 0 \
			else int(_reference(report, id, &"trigger", &"", breakable.conceals_trigger_id, true, "breakable '%s' conceals" % breakable.key)["id"])
		copy.blocking_rect = FloorDraft.world_rect(instance, breakable.blocking_rect) if breakable.blocking_rect.get_area() > 0.0 else breakable.blocking_rect
		layout.breakables.append(copy)
	for hit_switch: HitSwitchPlan in body.hit_switches:
		var copy := HitSwitchPlan.new()
		copy.key = _prefixed_or_empty(id, hit_switch.key)
		copy.switch_id = report.global_id(id, &"switch", hit_switch.switch_id)
		copy.position = FloorDraft.world_point(instance, hit_switch.position)
		copy.radius = hit_switch.radius
		copy.mode = hit_switch.mode
		copy.effects = _effects(report, id, bound, hit_switch.effects, "switch '%s'" % hit_switch.key)
		copy.starts_hidden = hit_switch.starts_hidden
		layout.hit_switches.append(copy)
	for obstacle: ObstaclePlan in body.obstacles:
		var copy := ObstaclePlan.new()
		copy.key = _prefixed_or_empty(id, obstacle.key)
		copy.obstacle_id = report.global_id(id, &"obstacle", obstacle.obstacle_id)
		copy.rect = FloorDraft.world_rect(instance, obstacle.rect)
		copy.height = obstacle.height
		layout.obstacles.append(copy)
	for pad: SpikePadPlan in body.spike_pads:
		var copy := SpikePadPlan.new()
		copy.key = _prefixed_or_empty(id, pad.key)
		copy.pad_id = report.global_id(id, &"pad", pad.pad_id)
		copy.rect = FloorDraft.world_rect(instance, pad.rect)
		copy.safe_ticks = pad.safe_ticks
		copy.active_ticks = pad.active_ticks
		copy.phase_offset_ticks = pad.phase_offset_ticks
		copy.damage = pad.damage
		copy.damage_type = pad.damage_type
		var allegiances: Array[StringName] = []
		for allegiance: StringName in pad.eligible_allegiances:
			allegiances.append(allegiance)
		copy.eligible_allegiances = allegiances
		layout.spike_pads.append(copy)
	for carriable: CarriablePlan in body.carriables:
		var copy := CarriablePlan.new()
		copy.key = _prefixed_or_empty(id, carriable.key)
		copy.carriable_id = report.global_id(id, &"carriable", carriable.carriable_id)
		copy.position = FloorDraft.world_point(instance, carriable.position)
		copy.starts_hidden = carriable.starts_hidden
		layout.carriables.append(copy)


static func _prefixed_or_empty(instance_id: StringName, key: StringName) -> StringName:
	return &"" if key == &"" else _prefixed(instance_id, key)


## One intra-piece reference, rewritten by its target layer: a key becomes the prefixed key AND
## the matching global id; a bare id goes through the table. `required` says whether -1 is a
## fault here (a connection must join two patches) or a permitted absence.
static func _reference(report: EmitReport, instance_id: StringName, layer: StringName, key: StringName,
		local_id: int, required: bool, what: String) -> Dictionary:
	if key != &"":
		# LAYER-SCOPED, like the compiler: a key that names a record of the wrong kind is not a
		# reference, however real that record is.
		var record: Dictionary = report.key_records.get(instance_id, {}).get(key, {})
		if record.is_empty() or record["layer"] != layer:
			_error(report, &"unresolved_reference", "DraftEmitter: '%s' %s names %s '%s', which that piece does not contain"
				% [instance_id, what, layer, key], {"instance": instance_id, "layer": layer, "reference": key})
			return {"key": &"", "id": FloorLayers.NO_TARGET}
		return {"key": report.global_key(instance_id, key), "id": report.global_id(instance_id, layer, int(record["local_id"]))}
	if local_id < 0:
		if required:
			_error(report, &"unresolved_reference", "DraftEmitter: '%s' %s names no %s at all" % [instance_id, what, layer],
				{"instance": instance_id, "layer": layer, "reference": local_id})
		return {"key": &"", "id": FloorLayers.NO_TARGET}
	var mapped: int = report.global_id(instance_id, layer, local_id)
	if mapped < 0:
		_error(report, &"unresolved_reference", "DraftEmitter: '%s' %s names %s id %d, which that piece does not contain"
			% [instance_id, what, layer, local_id], {"instance": instance_id, "layer": layer, "reference": local_id})
	return {"key": &"", "id": mapped}


static func _effects(report: EmitReport, instance_id: StringName, bound: Dictionary, effects: Array[Dictionary], what: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for effect: Dictionary in effects:
		var kind: StringName = effect.get("kind", &"")
		if not LayoutCompiler._EFFECT_TARGET_LAYER.has(kind):
			_error(report, &"unknown_effect_kind", "DraftEmitter: '%s' %s has an effect of unknown kind '%s'" % [instance_id, what, kind],
				{"instance": instance_id, "kind": kind})
			continue
		var layer: StringName = LayoutCompiler._EFFECT_TARGET_LAYER[kind]
		var target_key: StringName = effect.get("target_key", &"")
		var target_id: int = int(effect.get("target_id", FloorLayers.NO_TARGET))
		if layer == &"none":
			if target_key != &"" or target_id != FloorLayers.NO_TARGET:
				_error(report, &"reference_without_layer", "DraftEmitter: '%s' %s effect '%s' acts on no record, yet names a target" % [instance_id, what, kind],
					{"instance": instance_id, "kind": kind})
			out.append(FloorLayers.effect(kind, FloorLayers.NO_TARGET))
			continue
		if String(target_key).begins_with(FloorPiece.PORT_REFERENCE_PREFIX):
			var port_key: String = String(target_key).substr(FloorPiece.PORT_REFERENCE_PREFIX.length())
			var slot: String = "%s/%s" % [instance_id, port_key]
			if layer != &"connection" or not bound.has(slot):
				_error(report, &"unresolved_port", "DraftEmitter: '%s' %s effect '%s' names port '%s', which no joint binds" % [instance_id, what, kind, port_key],
					{"instance": instance_id, "port": StringName(port_key), "kind": kind})
				continue
			out.append({"kind": kind, "target_key": bound[slot]["joint_id"], "target_id": int(bound[slot]["connection_id"])})
			continue
		var resolved: Dictionary = _reference(report, instance_id, layer, target_key, target_id, true, "%s effect '%s'" % [what, kind])
		if resolved["key"] != &"":
			out.append({"kind": kind, "target_key": resolved["key"], "target_id": int(resolved["id"])})
		else:
			out.append(FloorLayers.effect(kind, int(resolved["id"])))
	return out


static func _emit_hallway(hallway: FloorDraft.HallwayFragment, report: EmitReport, layout: AuthoredLayout, sources: Dictionary) -> void:
	for index: int in hallway.rects.size():
		var patch := WalkablePatch.new()
		patch.key = _hallway_key(hallway.hallway_id, index)
		patch.patch_id = report.global_id(hallway.hallway_id, &"patch", index)
		patch.rect = hallway.rects[index]
		patch.surface = hallway.surface
		patch.boundary_style = hallway.boundary_style
		layout.patches.append(patch)
		sources[patch.patch_id] = hallway.hallway_id


static func _emit_joint(joint: FloorDraft.Joint, report: EmitReport, layout: AuthoredLayout) -> void:
	var info: Dictionary = report.joints[joint.joint_id]
	var connection := TraversalConnection.new()
	connection.key = joint.joint_id
	connection.connection_id = int(info["connection_id"])
	connection.near_key = info["patch_key"]
	connection.far_key = info["hallway_patch_key"]
	connection.patch_ids = Vector2i(int(info["patch_id"]), int(info["hallway_patch_id"]))
	connection.aperture = info["aperture"]
	connection.starts_open = not bool(info["gate"])
	connection.has_barrier = bool(info["gate"])
	connection.flank_style = joint.flank_style
	layout.connections.append(connection)


static func _emit_markers(draft: FloorDraft, layout: AuthoredLayout) -> void:
	for instance: FloorDraft.PieceInstance in draft.instances:
		if instance.piece.role == FloorPiece.ROLE_ENTRY:
			layout.entry_point = FloorDraft.world_point(instance, instance.piece.body.entry_point)
		if instance.piece.role == FloorPiece.ROLE_EXIT:
			layout.end_marker = FloorDraft.world_point(instance, instance.piece.body.end_marker)
			layout.exit_console = FloorDraft.world_point(instance, instance.piece.body.exit_console)


# --- 5. NOTHING TOUCHES BY ACCIDENT ----------------------------------------------------------

## Abutting patches JOIN (WalkableBounds is inclusive), so two pieces whose ground merely touches
## would share a passage no joint declared. The only cross-source contact allowed is a joint's
## own pair, and a joint's aperture may touch nothing but its two patches.
static func _check_adjacency(draft: FloorDraft, report: EmitReport, layout: AuthoredLayout, sources: Dictionary) -> void:
	var allowed: Dictionary = {}
	for joint_id: StringName in report.joints:
		var info: Dictionary = report.joints[joint_id]
		allowed[_pair(int(info["patch_id"]), int(info["hallway_patch_id"]))] = joint_id
	for a_index: int in layout.patches.size():
		var a: WalkablePatch = layout.patches[a_index]
		for b_index: int in range(a_index + 1, layout.patches.size()):
			var b: WalkablePatch = layout.patches[b_index]
			if sources[a.patch_id] == sources[b.patch_id]:
				continue
			if FloorPlan._touches(a.rect, b.rect) and not allowed.has(_pair(a.patch_id, b.patch_id)):
				_error(report, &"unintended_adjacency", "DraftEmitter: patch '%s' %s of '%s' touches patch '%s' %s of '%s' with no joint between them"
					% [a.key, a.rect, sources[a.patch_id], b.key, b.rect, sources[b.patch_id]],
					{"patch": a.patch_id, "other": b.patch_id, "source": sources[a.patch_id], "other_source": sources[b.patch_id]})
	for joint_id: StringName in report.joints:
		var info: Dictionary = report.joints[joint_id]
		for patch: WalkablePatch in layout.patches:
			if patch.patch_id == int(info["patch_id"]) or patch.patch_id == int(info["hallway_patch_id"]):
				continue
			if FloorPlan._touches(info["aperture"], patch.rect):
				_error(report, &"aperture_touches_stranger", "DraftEmitter: the aperture of joint '%s' %s touches patch '%s' %s, which it does not join"
					% [joint_id, info["aperture"], patch.key, patch.rect], {"joint": joint_id, "patch": patch.patch_id})


static func _pair(a: int, b: int) -> String:
	return "%d/%d" % [mini(a, b), maxi(a, b)]


static func _error(report: EmitReport, kind: StringName, message: String, refs: Dictionary) -> void:
	report.errors.append({"kind": kind, "message": message, "refs": refs})
