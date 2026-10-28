class_name FloorRecipe
extends Resource
## ONE COMPOSED FLOOR'S STRUCTURE AND BUDGETS, AS CONTENT (ADR-001 §4, S2).
##
## A RECIPE IS AN EXPLICIT GRAPH, NOT A PLANNER. S2 proves placement and routing; the experience
## planner that splices cycle templates (plan stream, S3+) does not exist yet, so a recipe lists
## its nodes in PLACEMENT ORDER and its physical edges by hand. Tree edges give each node its
## parent; `closes_cycle` edges are routed once both ends stand, and a closing edge that cannot
## be routed is a failure of the node placed last (ADR §5.1 step 7).
##
## THE POOL IS EXPLICIT. Pieces are listed here rather than discovered on disk, so selection
## never depends on resource scanning or directory order (determinism law); the caster sorts
## them by piece_id before any seeded choice.
##
## EVERY NUMBER IS MEASURED (ADR-001-S2-MEASUREMENTS.md) and provisional. Budgets are COUNTS,
## never time: elapsed time is reported, and nothing branches on it.

## Node: {key: StringName, role: StringName, tags: Array[StringName], progression: StringName}.
## The first node is the entry and stands at the origin as authored.
##
## `progression` DECLARES what the node is for, and ObjectiveIntegrity proves it on every composed
## floor (S3b): MANDATORY -- the floor cannot be completed without the node's ground, nor without
## its mandatory fights cleared, its keys lifted, its receivers fed; OPTIONAL -- its ground is
## reachable, and the floor can still be completed without ever entering it. Absent means the node
## supports the route and claims neither: an ambient roster or a corridor room is not promoted to
## mandatory for holding enemies.
@export var nodes: Array[Dictionary] = []
const PROGRESSION_MANDATORY: StringName = &"mandatory"
const PROGRESSION_OPTIONAL: StringName = &"optional"
const PROGRESSIONS: Array[StringName] = [PROGRESSION_MANDATORY, PROGRESSION_OPTIONAL]
## Edge: {from, from_port, to, to_port, profile: StringName, closes_cycle: bool}.
@export var edges: Array[Dictionary] = []
## CROSS-PIECE DEPENDENCIES (G3 iteration, 2026-10-27): {from, from_port, to, effect, target_key}.
## The record the `from` node's piece names with its unlock port `from_port` also performs `effect`
## on the record `target_key` of the `to` node's piece. Installed by the composer as draft wires;
## the pieces actually cast are checked by the emitter, the shape of the entry here.
@export var dependencies: Array[Dictionary] = []
## VISIBILITY EDGES (S4): {from, from_port, to, to_port, intent, mandatory, door_port}. From a vantage
## port to an anchor port; `intent` reveal|conceal (VisibilityValidator). `mandatory` is a promise:
## lint refuses it unless every piece the two nodes can cast carries the vantage, the anchor and a
## gate `door_port` opened only by key receivers; on a placed floor it rejects when unseen, and
## certification fails when the progression validator cannot confirm the lock.
@export var visibility: Array[Dictionary] = []
@export var recipe_id: StringName = &""
@export var place_label: String = ""
## The stratum the floor belongs to; its enemy pool is the roster lint's pool.
@export var stratum: StratumConfig = null
@export var pieces: Array[FloorPiece] = []
@export var profiles: Array[TraversalProfile] = []
## Where the route is meant to go. Used to order leg directions: a first leg along the flow is
## tried before one against it.
@export var flow_axis: Vector2 = Vector2(0, -1)
## Leg lengths and positions step on this cell.
@export var grid_cell: float = 2.0
## No footprint or hallway comes closer than this to ground it does not join.
@export var margin: float = 2.0
## Everything placed stays inside this rectangle (world coordinates; the entry is at the origin).
@export var extent: Rect2 = Rect2(-80, -150, 160, 170)
## How many cast candidates a role is allowed per attempt, how many accepted placements an
## attempt may spend (undone ones included), and how many reseeded attempts precede the fallback.
@export var candidates_per_piece: int = 3
@export var placement_budget: int = 200
@export var reseed_budget: int = 3
## Compiled when every attempt fails; counted apart from successes, never as one.
@export var fallback: AuthoredLayout = null


func profile(wanted: StringName) -> TraversalProfile:
	for candidate: TraversalProfile in profiles:
		if candidate.profile_id == wanted:
			return candidate
	return null


func node(wanted: StringName) -> Dictionary:
	for candidate: Dictionary in nodes:
		if candidate.get("key", &"") == wanted:
			return candidate
	return {}


## The tree edge that places a node, or {} for the entry.
func parent_edge_of(node_key: StringName) -> Dictionary:
	for edge: Dictionary in edges:
		if edge.get("to", &"") == node_key and not bool(edge.get("closes_cycle", false)):
			return edge
	return {}


## Every structural fault in the recipe itself, before any seed is drawn.
func lint() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if recipe_id == &"":
		_finding(out, &"recipe_id_missing", "FloorRecipe: a recipe must be named", {})
	if stratum == null:
		_finding(out, &"stratum_missing", "FloorRecipe '%s': no stratum" % recipe_id, {})
	if fallback == null:
		_finding(out, &"fallback_missing", "FloorRecipe '%s': no authored fallback" % recipe_id, {})
	if grid_cell <= 0.0 or margin < 0.0 or extent.get_area() <= 0.0:
		_finding(out, &"recipe_geometry_invalid", "FloorRecipe '%s': grid %s, margin %s, extent %s" % [recipe_id, grid_cell, margin, extent], {})
	if candidates_per_piece < 1 or placement_budget < 1 or reseed_budget < 0:
		_finding(out, &"recipe_budget_invalid", "FloorRecipe '%s': budgets must be positive counts" % recipe_id, {})
	var seen: Dictionary = {}
	for index: int in nodes.size():
		var entry: Dictionary = nodes[index]
		var key: StringName = entry.get("key", &"")
		if key == &"" or seen.has(key):
			_finding(out, &"node_key_invalid", "FloorRecipe '%s': node %d has a missing or repeated key" % [recipe_id, index], {"node": key})
		seen[key] = true
		if not entry.get("role", &"") in FloorPiece.ROLES:
			_finding(out, &"node_role_unknown", "FloorRecipe '%s': node '%s' has role '%s'" % [recipe_id, key, entry.get("role", &"")], {"node": key})
		if entry.has("progression") and not entry["progression"] in PROGRESSIONS:
			_finding(out, &"node_progression_unknown", "FloorRecipe '%s': node '%s' declares progression '%s' (one of %s, or none)" % [recipe_id, key, entry["progression"], PROGRESSIONS], {"node": key})
		if index == 0 and entry.get("progression", &"") == PROGRESSION_OPTIONAL:
			_finding(out, &"entry_optional", "FloorRecipe '%s': the entry is where every route starts; it cannot be optional" % recipe_id, {"node": key})
		if index == 0 and entry.get("role", &"") != FloorPiece.ROLE_ENTRY:
			_finding(out, &"entry_not_first", "FloorRecipe '%s': the first node must be the entry" % recipe_id, {"node": key})
		elif index > 0:
			var parent: Dictionary = parent_edge_of(key)
			if parent.is_empty():
				_finding(out, &"node_unreached", "FloorRecipe '%s': node '%s' has no tree edge placing it" % [recipe_id, key], {"node": key})
			elif _index_of(parent.get("from", &"")) < 0 or _index_of(parent.get("from", &"")) >= index:
				_finding(out, &"node_order_invalid", "FloorRecipe '%s': node '%s' is placed before its parent '%s'" % [recipe_id, key, parent.get("from", &"")], {"node": key})
	for edge: Dictionary in edges:
		for end: String in ["from", "to"]:
			if _index_of(edge.get(end, &"")) < 0:
				_finding(out, &"edge_node_unknown", "FloorRecipe '%s': edge names node '%s', which does not exist" % [recipe_id, edge.get(end, &"")], {"edge": edge})
		if profile(edge.get("profile", &"")) == null:
			_finding(out, &"edge_profile_unknown", "FloorRecipe '%s': edge names profile '%s', which the recipe does not carry" % [recipe_id, edge.get("profile", &"")], {"edge": edge})
		if edge.get("from_port", &"") == &"" or edge.get("to_port", &"") == &"":
			_finding(out, &"edge_port_missing", "FloorRecipe '%s': an edge must name both ports" % recipe_id, {"edge": edge})
	var wired: Dictionary = {}
	for dependency: Dictionary in dependencies:
		var label: String = "%s.%s -> %s" % [dependency.get("from", &""), dependency.get("from_port", &""), dependency.get("to", &"")]
		for end: String in ["from", "to"]:
			if _index_of(dependency.get(end, &"")) < 0:
				_finding(out, &"dependency_node_unknown", "FloorRecipe '%s': dependency %s names node '%s', which does not exist" % [recipe_id, label, dependency.get(end, &"")], {"dependency": dependency})
		if dependency.get("from", &"") == dependency.get("to", &""):
			_finding(out, &"dependency_same_node", "FloorRecipe '%s': dependency %s stays inside one node; its piece's own effects say that" % [recipe_id, label], {"dependency": dependency})
		if dependency.get("from_port", &"") == &"" or dependency.get("target_key", &"") == &"":
			_finding(out, &"dependency_endpoint_missing", "FloorRecipe '%s': dependency %s must name its unlock port and its target key" % [recipe_id, label], {"dependency": dependency})
		if not dependency.get("effect", &"") in DraftEmitter.WIRABLE_EFFECTS:
			_finding(out, &"dependency_effect_unsupported", "FloorRecipe '%s': dependency %s asks for '%s'; wirable: %s" % [recipe_id, label, dependency.get("effect", &""), DraftEmitter.WIRABLE_EFFECTS], {"dependency": dependency})
		var identity: String = "%s|%s|%s|%s|%s" % [dependency.get("from", &""), dependency.get("from_port", &""), dependency.get("to", &""), dependency.get("effect", &""), dependency.get("target_key", &"")]
		if wired.has(identity):
			_finding(out, &"dependency_duplicate", "FloorRecipe '%s': dependency %s is listed twice" % [recipe_id, label], {"dependency": dependency})
		wired[identity] = true
	for sight: Dictionary in visibility:
		var sight_label: String = "%s.%s -> %s.%s" % [sight.get("from", &""), sight.get("from_port", &""), sight.get("to", &""), sight.get("to_port", &"")]
		for end: String in ["from", "to"]:
			if _index_of(sight.get(end, &"")) < 0:
				_finding(out, &"visibility_node_unknown", "FloorRecipe '%s': visibility %s names node '%s', which does not exist" % [recipe_id, sight_label, sight.get(end, &"")], {"visibility": sight})
		if sight.get("from_port", &"") == &"" or sight.get("to_port", &"") == &"":
			_finding(out, &"visibility_endpoint_missing", "FloorRecipe '%s': visibility %s must name its vantage and anchor ports" % [recipe_id, sight_label], {"visibility": sight})
		if not sight.get("intent", VisibilityValidator.INTENT_REVEAL) in VisibilityValidator.INTENTS:
			_finding(out, &"visibility_intent_unknown", "FloorRecipe '%s': visibility %s has intent '%s' (one of %s)" % [recipe_id, sight_label, sight.get("intent", &""), VisibilityValidator.INTENTS], {"visibility": sight})
		if bool(sight.get("mandatory", false)) and sight.get("intent", VisibilityValidator.INTENT_REVEAL) != VisibilityValidator.INTENT_REVEAL:
			_finding(out, &"visibility_conceal_mandatory", "FloorRecipe '%s': visibility %s: only a reveal can be mandatory; a concealment is reported" % [recipe_id, sight_label], {"visibility": sight})
		if bool(sight.get("mandatory", false)) and sight.get("door_port", &"") == &"":
			_finding(out, &"visibility_mandatory_without_door", "FloorRecipe '%s': visibility %s is mandatory but names no door_port; only a locked door is an enforceable reveal" % [recipe_id, sight_label], {"visibility": sight})
		elif bool(sight.get("mandatory", false)):
			for end: Array in [[&"from", &"vantage", sight.get("from_port", &"")], [&"to", &"anchor", sight.get("to_port", &"")]]:
				var castable: Array[FloorPiece] = _castable(sight.get(end[0], &""))
				if castable.is_empty():
					_finding(out, &"visibility_mandatory_unenforceable", "FloorRecipe '%s': visibility %s: no pool piece can be cast for node '%s'" % [recipe_id, sight_label, sight.get(end[0], &"")], {"visibility": sight})
				for piece: FloorPiece in castable:
					var fault: String = VisibilityValidator.declaration_fault(piece, end[1], end[2], sight.get("door_port", &""))
					if fault != "":
						_finding(out, &"visibility_mandatory_unenforceable", "FloorRecipe '%s': mandatory visibility %s: %s" % [recipe_id, sight_label, fault], {"visibility": sight, "piece": piece.piece_id})
					# ADR O6: a piece carrying a camera-sensitive promise does not opt in to mirroring.
					if piece.allows(&"mirror_x"):
						_finding(out, &"visibility_mandatory_mirrored", "FloorRecipe '%s': mandatory visibility %s: piece '%s' allows mirror_x (ADR O6)" % [recipe_id, sight_label, piece.piece_id], {"visibility": sight, "piece": piece.piece_id})
	for candidate: TraversalProfile in profiles:
		out.append_array(candidate.lint())
	var ids: Dictionary = {}
	for piece: FloorPiece in pieces:
		if piece == null:
			_finding(out, &"piece_missing", "FloorRecipe '%s': a null piece in the pool" % recipe_id, {})
			continue
		if ids.has(piece.piece_id):
			_finding(out, &"piece_id_duplicate", "FloorRecipe '%s': piece '%s' is in the pool twice" % [recipe_id, piece.piece_id], {"piece": piece.piece_id})
		ids[piece.piece_id] = true
	return out


## Every pool piece the composer could cast for a node, at any depth: its role and its tags.
func _castable(node_key: StringName) -> Array[FloorPiece]:
	var wanted: Dictionary = node(node_key)
	var out: Array[FloorPiece] = []
	if wanted.is_empty():
		return out
	var tags: Array[StringName] = []
	tags.assign(wanted.get("tags", []))
	for piece: FloorPiece in pieces:
		if piece != null and piece.role == wanted.get("role", &"") and piece.carries(tags):
			out.append(piece)
	return out


func _index_of(node_key: StringName) -> int:
	for index: int in nodes.size():
		if nodes[index].get("key", &"") == node_key:
			return index
	return -1


static func _finding(out: Array[Dictionary], rule: StringName, message: String, refs: Dictionary) -> void:
	out.append({"rule": rule, "message": message, "refs": refs})
