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

## Node: {key: StringName, role: StringName, tags: Array[StringName]}. The first node is the
## entry and stands at the origin as authored.
@export var nodes: Array[Dictionary] = []
## Edge: {from, from_port, to, to_port, profile: StringName, closes_cycle: bool}.
@export var edges: Array[Dictionary] = []
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


func _index_of(node_key: StringName) -> int:
	for index: int in nodes.size():
		if nodes[index].get("key", &"") == node_key:
			return index
	return -1


static func _finding(out: Array[Dictionary], rule: StringName, message: String, refs: Dictionary) -> void:
	out.append({"rule": rule, "message": message, "refs": refs})
