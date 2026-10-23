class_name FloorPiece
extends Resource
## AN AUTHORED, SELF-CONTAINED FRAGMENT OF A FLOOR (ADR-001 §4, LEXICON O7; S1).
##
## THE BODY IS AN ORDINARY AuthoredLayout IN LOCAL COORDINATES. No second content format: a
## piece's interior is authored exactly as a whole floor is, compiles through the same
## LayoutCompiler once the emitter has placed it, and may use every layer a floor may. What a
## piece adds is the contract AROUND that body -- a footprint, the transforms it tolerates, and
## the ports where the rest of a floor may join it -- and nothing else.
##
## A PIECE REFERENCES NOTHING OUTSIDE ITSELF. Every key its body names resolves inside its body,
## with one exception that is the whole point of ports: a connection-layer effect may name a
## connector/gate port as `@<port key>`, meaning "the joint the draft binds here". That is how a
## piece opens its own door without knowing what is on the other side.
##
## LINTABLE ALONE (owner correction, ADR §0): lint() answers the structural questions a piece
## can answer about itself and never asks it to be a complete floor. Whole-floor rules
## (FloorPlan.violations, progression) run on the emitted floor. Detection only, never repair,
## like every validator in gen/.
##
## WHAT IS DELIBERATELY ABSENT UNTIL S2 CASTS PIECES: depth bands, weights, tags. Their only
## consumer is the caster, and a field with no consumer is a schema pretending to be a design.
## The stratum is the body's own `stratum_id` -- one fact, not two that could disagree.

const ROLE_ENTRY: StringName = &"entry"
const ROLE_LANDMARK: StringName = &"landmark"
const ROLE_OBJECTIVE: StringName = &"objective"
const ROLE_ENCOUNTER: StringName = &"encounter"
const ROLE_EXIT: StringName = &"exit"
const ROLES: Array[StringName] = [ROLE_ENTRY, ROLE_LANDMARK, ROLE_OBJECTIVE, ROLE_ENCOUNTER, ROLE_EXIT]

## IDENTITY IS THE DEFAULT; MIRRORING IS OPT-IN (owner ruling O6). A piece whose reveals,
## encounters or hazards read differently reflected simply never lists mirror_x, and the
## emitter refuses to apply what a piece did not allow.
const TRANSFORM_IDENTITY: StringName = &"identity"
const TRANSFORM_MIRROR_X: StringName = &"mirror_x"
const SUPPORTED_TRANSFORMS: Array[StringName] = [TRANSFORM_IDENTITY, TRANSFORM_MIRROR_X]

## A body effect's `target_key` beginning with this names one of the piece's own ports.
const PORT_REFERENCE_PREFIX: String = "@"

## The compiler's layer names, in the order the emitter allocates identities (one counter each).
const LAYERS: Array[StringName] = [&"patch", &"connection", &"trigger", &"encounter",
	&"breakable", &"switch", &"obstacle", &"pad", &"carriable"]

@export var piece_id: StringName = &""
@export var role: StringName = ROLE_LANDMARK
## Local coordinates. The origin is wherever the author put it; the draft supplies the offset.
@export var body: AuthoredLayout = null
## Reserved ground including wall thickness: every body rect and point lies inside it, ports
## sit on its edge, and two footprints never overlap once placed.
@export var footprint: Rect2 = Rect2()
@export var allowed_transforms: Array[StringName] = [TRANSFORM_IDENTITY]
@export var ports: Array[PiecePort] = []


func port(wanted: StringName) -> PiecePort:
	for candidate: PiecePort in ports:
		if candidate.key == wanted:
			return candidate
	return null


func allows(transform: StringName) -> bool:
	return transform in allowed_transforms


# --- LINT ---------------------------------------------------------------------------------

## Every structural fault this piece has on its own, as {rule, message, refs}. Empty means the
## piece may be placed. `enemy_keys` is the stratum's pool, supplied by the caller exactly as
## FloorPlan.violations takes body radii -- gen/ never reaches for an autoload -- and the roster
## rule simply does not run when it is omitted.
func lint(enemy_keys: Array[StringName] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if piece_id == &"":
		_finding(out, &"piece_id_missing", "FloorPiece: a piece must be named", {})
	if not role in ROLES:
		_finding(out, &"role_unknown", "FloorPiece '%s': role '%s' is not one of %s" % [piece_id, role, ROLES], {"role": role})
	if body == null:
		_finding(out, &"body_missing", "FloorPiece '%s': no body" % piece_id, {})
		return out
	if footprint.get_area() <= 0.0:
		_finding(out, &"footprint_empty", "FloorPiece '%s': footprint %s has no area" % [piece_id, footprint], {})
	_check_transforms(out)
	_check_identities(out)
	_check_body_inside_footprint(out)
	_check_references(out)
	_check_role(out)
	_check_ports(out)
	_check_rosters(enemy_keys, out)
	return out


func _check_transforms(out: Array[Dictionary]) -> void:
	if allowed_transforms.is_empty() or not TRANSFORM_IDENTITY in allowed_transforms:
		_finding(out, &"identity_required", "FloorPiece '%s': a piece must at least allow being placed as authored (identity)" % piece_id, {})
	for transform: StringName in allowed_transforms:
		if not transform in SUPPORTED_TRANSFORMS:
			_finding(out, &"transform_unsupported", "FloorPiece '%s': transform '%s' is not one the emitter supports (%s)"
				% [piece_id, transform, SUPPORTED_TRANSFORMS], {"transform": transform})


## Ids are the emitter's input to its remap table, so every record needs a real one and no two
## records of a layer may share one. Keys must be unambiguous for the same reason the compiler
## demands it.
func _check_identities(out: Array[Dictionary]) -> void:
	var seen_keys: Dictionary = {}
	for layer: StringName in LAYERS:
		var seen_ids: Dictionary = {}
		for record: Resource in body.records_in(layer):
			var local_id: int = AuthoredLayout._numeric_id(record)
			if local_id < 0:
				_finding(out, &"unset_id", "FloorPiece '%s': %s '%s' has no id (ids are >= 0; -1 is the sentinel)"
					% [piece_id, layer, record.key], {"layer": layer, "key": record.key})
			elif seen_ids.has(local_id):
				_finding(out, &"duplicate_local_id", "FloorPiece '%s': %s id %d is used twice" % [piece_id, layer, local_id],
					{"layer": layer, "id": local_id})
			seen_ids[local_id] = true
			if record.key != &"":
				if seen_keys.has(record.key):
					_finding(out, &"duplicate_key", "FloorPiece '%s': key '%s' is used by more than one record" % [piece_id, record.key],
						{"key": record.key})
				seen_keys[record.key] = true


func _check_body_inside_footprint(out: Array[Dictionary]) -> void:
	for patch: WalkablePatch in body.patches:
		_rect_inside(out, &"patch", patch.key, patch.rect)
	for connection: TraversalConnection in body.connections:
		_rect_inside(out, &"connection", connection.key, connection.aperture)
	for trigger: FloorTrigger in body.triggers:
		if trigger.region.get_area() > 0.0:
			_rect_inside(out, &"trigger", trigger.key, trigger.region)
	for site: EncounterSite in body.encounters:
		for region: Rect2 in site.regions:
			_rect_inside(out, &"encounter", site.key, region)
		for spawn: Dictionary in site.roster:
			_point_inside(out, &"encounter", site.key, spawn.get("position", Vector3.ZERO))
	for breakable: BreakablePlan in body.breakables:
		_point_inside(out, &"breakable", breakable.key, breakable.position)
		if breakable.blocking_rect.get_area() > 0.0:
			_rect_inside(out, &"breakable", breakable.key, breakable.blocking_rect)
	for hit_switch: HitSwitchPlan in body.hit_switches:
		_point_inside(out, &"switch", hit_switch.key, hit_switch.position)
	for obstacle: ObstaclePlan in body.obstacles:
		_rect_inside(out, &"obstacle", obstacle.key, obstacle.rect)
	for pad: SpikePadPlan in body.spike_pads:
		_rect_inside(out, &"pad", pad.key, pad.rect)
	for carriable: CarriablePlan in body.carriables:
		_point_inside(out, &"carriable", carriable.key, carriable.position)


func _rect_inside(out: Array[Dictionary], layer: StringName, key: StringName, rect: Rect2) -> void:
	if not footprint.encloses(rect):
		_finding(out, &"body_outside_footprint", "FloorPiece '%s': %s '%s' at %s reaches outside the footprint %s"
			% [piece_id, layer, key, rect, footprint], {"layer": layer, "key": key})


func _point_inside(out: Array[Dictionary], layer: StringName, key: StringName, point: Vector3) -> void:
	if not WalkableBounds.contains(footprint, point.x, point.z):
		_finding(out, &"body_outside_footprint", "FloorPiece '%s': %s '%s' at %s lies outside the footprint %s"
			% [piece_id, layer, key, point, footprint], {"layer": layer, "key": key})


## EVERY REFERENCE RESOLVES INSIDE THE BODY, by the layer the compiler will look in -- the same
## tables, so a piece cannot pass lint and then fail to compile for a reason lint could have
## named. The one thing allowed to point outward is `@port` on a connection-layer effect.
func _check_references(out: Array[Dictionary]) -> void:
	for connection: TraversalConnection in body.connections:
		_check_reference(out, &"connection", connection.key, &"patch", connection.near_key, connection.patch_ids.x, "near")
		_check_reference(out, &"connection", connection.key, &"patch", connection.far_key, connection.patch_ids.y, "far")
	for trigger: FloorTrigger in body.triggers:
		var layer: StringName = LayoutCompiler._TRIGGER_SOURCE_LAYER.get(trigger.kind, &"none")
		if layer == &"none":
			if trigger.source_key != &"" or trigger.source_id >= 0:
				_finding(out, &"reference_without_layer", "FloorPiece '%s': trigger '%s' of kind '%s' watches nothing, yet names a source"
					% [piece_id, trigger.key, trigger.kind], {"layer": &"trigger", "key": trigger.key})
		else:
			_check_reference(out, &"trigger", trigger.key, layer, trigger.source_key, trigger.source_id, "source")
		_check_effects(out, &"trigger", trigger.key, trigger.effects)
	for hit_switch: HitSwitchPlan in body.hit_switches:
		_check_effects(out, &"switch", hit_switch.key, hit_switch.effects)


func _check_effects(out: Array[Dictionary], layer: StringName, key: StringName, effects: Array[Dictionary]) -> void:
	for effect: Dictionary in effects:
		var kind: StringName = effect.get("kind", &"")
		if not LayoutCompiler._EFFECT_TARGET_LAYER.has(kind):
			_finding(out, &"unknown_effect_kind", "FloorPiece '%s': %s '%s' has an effect of unknown kind '%s'"
				% [piece_id, layer, key, kind], {"layer": layer, "key": key, "kind": kind})
			continue
		var target_layer: StringName = LayoutCompiler._EFFECT_TARGET_LAYER[kind]
		var target_key: StringName = effect.get("target_key", &"")
		var target_id: int = int(effect.get("target_id", FloorLayers.NO_TARGET))
		if target_layer == &"none":
			if target_key != &"" or target_id != FloorLayers.NO_TARGET:
				_finding(out, &"reference_without_layer", "FloorPiece '%s': %s '%s' effect '%s' acts on no record, yet names a target"
					% [piece_id, layer, key, kind], {"layer": layer, "key": key, "kind": kind})
			continue
		if String(target_key).begins_with(PORT_REFERENCE_PREFIX):
			var port_key: StringName = StringName(String(target_key).substr(PORT_REFERENCE_PREFIX.length()))
			if target_layer != &"connection":
				_finding(out, &"port_reference_misused", "FloorPiece '%s': %s '%s' effect '%s' names port '%s', but only a connection effect may target a joint"
					% [piece_id, layer, key, kind, port_key], {"layer": layer, "key": key, "port": port_key})
			elif port(port_key) == null or not port(port_key).is_joinable():
				_finding(out, &"port_reference_unknown", "FloorPiece '%s': %s '%s' effect '%s' names port '%s', which is not a connector or gate of this piece"
					% [piece_id, layer, key, kind, port_key], {"layer": layer, "key": key, "port": port_key})
			continue
		_check_reference(out, layer, key, target_layer, target_key, target_id, String(kind))


func _check_reference(out: Array[Dictionary], layer: StringName, key: StringName, target_layer: StringName,
		target_key: StringName, target_id: int, what: String) -> void:
	if target_key != &"":
		if not _has_key(target_layer, target_key):
			_finding(out, &"unresolved_reference", "FloorPiece '%s': %s '%s' (%s) names %s '%s', which this piece does not contain"
				% [piece_id, layer, key, what, target_layer, target_key], {"layer": layer, "key": key, "reference": target_key})
	elif not _has_id(target_layer, target_id):
		_finding(out, &"unresolved_reference", "FloorPiece '%s': %s '%s' (%s) names %s id %d, which this piece does not contain"
			% [piece_id, layer, key, what, target_layer, target_id], {"layer": layer, "key": key, "reference": target_id})


func _has_key(layer: StringName, wanted: StringName) -> bool:
	for record: Resource in body.records_in(layer):
		if record.key == wanted:
			return true
	return false


func _has_id(layer: StringName, wanted: int) -> bool:
	for record: Resource in body.records_in(layer):
		if AuthoredLayout._numeric_id(record) == wanted:
			return true
	return false


## What a role promises the floor: the entry piece supplies arrival, the exit piece supplies the
## one completion plus the console and marker, and no other piece may finish a floor.
func _check_role(out: Array[Dictionary]) -> void:
	var completions: int = 0
	for trigger: FloorTrigger in body.triggers:
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") == FloorLayers.EFFECT_COMPLETE_FLOOR:
				completions += 1
	if role == ROLE_EXIT:
		if completions != 1:
			_finding(out, &"exit_without_completion", "FloorPiece '%s': an exit piece authors exactly one complete_floor, found %d"
				% [piece_id, completions], {"completions": completions})
		_point_inside(out, &"exit_console", &"exit_console", body.exit_console)
		_point_inside(out, &"end_marker", &"end_marker", body.end_marker)
	elif completions > 0:
		_finding(out, &"completion_outside_exit", "FloorPiece '%s': only an exit piece may complete the floor (role is '%s')"
			% [piece_id, role], {"completions": completions})
	if role == ROLE_ENTRY:
		_point_inside(out, &"entry_point", &"entry_point", body.entry_point)


func _check_ports(out: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for candidate: PiecePort in ports:
		if candidate.key == &"":
			_finding(out, &"port_key_missing", "FloorPiece '%s': a port has no key" % piece_id, {})
		elif seen.has(candidate.key):
			_finding(out, &"port_key_duplicate", "FloorPiece '%s': port '%s' is declared twice" % [piece_id, candidate.key], {"port": candidate.key})
		seen[candidate.key] = true
		if not candidate.kind in PiecePort.KINDS:
			_finding(out, &"port_kind_unknown", "FloorPiece '%s': port '%s' has unknown kind '%s'" % [piece_id, candidate.key, candidate.kind], {"port": candidate.key})
			continue
		if candidate.is_joinable():
			_check_joinable_port(out, candidate)
		elif candidate.kind == PiecePort.KIND_UNLOCK:
			var named: int = int(candidate.trigger_key != &"") + int(candidate.switch_key != &"")
			if named != 1:
				_finding(out, &"port_target_missing", "FloorPiece '%s': unlock port '%s' must name exactly one trigger or switch" % [piece_id, candidate.key], {"port": candidate.key})
			elif candidate.trigger_key != &"" and not _has_key(&"trigger", candidate.trigger_key):
				_finding(out, &"port_target_missing", "FloorPiece '%s': unlock port '%s' names trigger '%s', which does not exist" % [piece_id, candidate.key, candidate.trigger_key], {"port": candidate.key})
			elif candidate.switch_key != &"" and not _has_key(&"switch", candidate.switch_key):
				_finding(out, &"port_target_missing", "FloorPiece '%s': unlock port '%s' names switch '%s', which does not exist" % [piece_id, candidate.key, candidate.switch_key], {"port": candidate.key})
		else:
			_point_inside(out, &"port", candidate.key, candidate.position)


## A joinable port sits ON the footprint edge, within it, and its patch reaches that edge across
## the whole span -- so the joint's aperture overlaps real ground on the piece's side.
func _check_joinable_port(out: Array[Dictionary], candidate: PiecePort) -> void:
	if not candidate.edge in PiecePort.EDGES:
		_finding(out, &"port_edge_unknown", "FloorPiece '%s': port '%s' names edge '%s'" % [piece_id, candidate.key, candidate.edge], {"port": candidate.key})
		return
	var along_x: bool = PiecePort.runs_along_x(candidate.edge)
	var edge_length: float = footprint.size.x if along_x else footprint.size.y
	if candidate.width <= 0.0 or candidate.offset < 0.0 or candidate.offset + candidate.width > edge_length:
		_finding(out, &"port_off_edge", "FloorPiece '%s': port '%s' spans [%s, %s] along a %s edge of length %s"
			% [piece_id, candidate.key, candidate.offset, candidate.offset + candidate.width, candidate.edge, edge_length], {"port": candidate.key})
		return
	var patch: WalkablePatch = null
	for record: WalkablePatch in body.patches:
		if record.key == candidate.patch_key:
			patch = record
	if patch == null:
		_finding(out, &"port_patch_missing", "FloorPiece '%s': port '%s' names patch '%s', which does not exist" % [piece_id, candidate.key, candidate.patch_key], {"port": candidate.key})
		return
	var span: Dictionary = local_port_span(candidate)
	var flush: bool
	var covers: bool
	if along_x:
		flush = is_equal_approx(patch.rect.end.y if candidate.edge == PiecePort.EDGE_NORTH else patch.rect.position.y, float(span["at"]))
		covers = patch.rect.position.x <= float(span["from"]) and patch.rect.end.x >= float(span["to"])
	else:
		flush = is_equal_approx(patch.rect.end.x if candidate.edge == PiecePort.EDGE_EAST else patch.rect.position.x, float(span["at"]))
		covers = patch.rect.position.y <= float(span["from"]) and patch.rect.end.y >= float(span["to"])
	if not (flush and covers):
		_finding(out, &"port_patch_not_on_edge", "FloorPiece '%s': port '%s' lies on the %s edge, but patch '%s' %s does not reach it across the span [%s, %s]"
			% [piece_id, candidate.key, candidate.edge, patch.key, patch.rect, span["from"], span["to"]], {"port": candidate.key, "patch": patch.key})


## The line a joinable port occupies, in the piece's own coordinates (PiecePort.span_on).
func local_port_span(candidate: PiecePort) -> Dictionary:
	return PiecePort.span_on(footprint, candidate.edge, candidate.offset, candidate.width)


func _check_rosters(enemy_keys: Array[StringName], out: Array[Dictionary]) -> void:
	if enemy_keys.is_empty():
		return
	for site: EncounterSite in body.encounters:
		for spawn: Dictionary in site.roster:
			var enemy: StringName = spawn.get("enemy_key", &"")
			if not enemy in enemy_keys:
				_finding(out, &"roster_outside_stratum", "FloorPiece '%s': encounter '%s' summons '%s', which the stratum does not own"
					% [piece_id, site.key, enemy], {"encounter": site.key, "enemy_key": enemy})


static func _finding(out: Array[Dictionary], rule: StringName, message: String, refs: Dictionary) -> void:
	out.append({"rule": rule, "message": message, "refs": refs})
