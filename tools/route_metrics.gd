extends RefCounted
## DIAGNOSTIC ROUTE AND TOPOLOGY METRICS for composed floors (ADR-001 S3a, G1). Tool-side only:
## nothing in the game reads this, and no verdict is drawn from it -- the sweep reports the
## numbers and the owner rules on them.
##
## DISTANCES ARE WALKED, NEVER STRAIGHT-LINE. A route is the shortest path the Envoy's CENTRE can
## take over the floor's legal ground (WalkableBounds.fits with the body radius, the sim's own
## predicate) on a fixed grid, 8-connected with no corner cutting, under a named set of open
## connections -- so a closed gate is a wall exactly as the sim makes it one.
##
## Loaded by path (`preload`), not as a global class: it is a tool, and a class_name would put
## it in every scope of the game.

const CELL: float = 1.0
const _DIAGONAL: float = 1.41421356
## A heading must persist this far (world units) along the walked path before it counts, so a
## doorway's half-step sideways is not reported as a turn.
const HEADING_MIN_RUN: float = 6.0


## Every connection id -> true, except those listed.
static func open_except(plan: FloorPlan, closed: Array) -> Dictionary:
	var open: Dictionary = {}
	for connection: TraversalConnection in plan.connections:
		if not connection.connection_id in closed:
			open[connection.connection_id] = true
	return open


## The connection id the emitter wrote for one placed port, or -1.
static func connection_of(result: FloorComposer.ComposeResult, instance_id: StringName, port_key: StringName) -> int:
	for joint: FloorDraft.Joint in result.draft.joints:
		if joint.instance_id == instance_id and joint.port_key == port_key:
			return int(result.emit.joints.get(joint.joint_id, {}).get("connection_id", -1))
	return -1


## The instance a recipe node was placed as (instances are allocated in node order).
static func instance_of_node(recipe: FloorRecipe, result: FloorComposer.ComposeResult, node_key: StringName) -> StringName:
	for index: int in recipe.nodes.size():
		if recipe.nodes[index].get("key", &"") == node_key:
			return result.draft.instances[index].instance_id
	return &""


## The shortest walked route from a point to any legal point inside `target`, under `open`, never
## standing inside an `avoid` rect (ground a route is asked to go round -- an optional hazard piece,
## to measure the way that does without it). Returns {length: float (-1 when unreachable),
## path: Array[Vector2]}.
static func walk(plan: FloorPlan, open: Dictionary, from: Vector2, target: Rect2, radius: float, avoid: Array = []) -> Dictionary:
	var bounds := WalkableBounds.new(plan.open_walkable_rects(open), plan.obstacle_rects())
	var area: Rect2 = _extent(plan).grow(CELL)
	var columns: int = int(ceil(area.size.x / CELL)) + 1
	var rows: int = int(ceil(area.size.y / CELL)) + 1
	var passable := PackedByteArray()
	passable.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			var point: Vector2 = area.position + Vector2(column, row) * CELL
			var avoided: bool = avoid.any(func(rect: Rect2) -> bool: return WalkableBounds.contains(rect, point.x, point.y))
			passable[row * columns + column] = 1 if not avoided and bounds.fits(Vector3(point.x, 0.0, point.y), radius) else 0
	var start: int = _nearest_passable(area, columns, rows, passable, from)
	if start < 0:
		return {"length": -1.0, "path": []}
	var dist := PackedFloat64Array()
	dist.resize(columns * rows)
	dist.fill(INF)
	var previous := PackedInt32Array()
	previous.resize(columns * rows)
	previous.fill(-1)
	dist[start] = 0.0
	var heap: Array = [[0.0, start]]
	var goal: int = -1
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var here: int = top[1]
		if top[0] > dist[here]:
			continue
		var at: Vector2 = area.position + Vector2(here % columns, here / columns) * CELL
		if WalkableBounds.contains(target, at.x, at.y):
			goal = here
			break
		var column: int = here % columns
		var row: int = here / columns
		for dz: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nc: int = column + dx
				var nr: int = row + dz
				if nc < 0 or nr < 0 or nc >= columns or nr >= rows or passable[nr * columns + nc] == 0:
					continue
				if dx != 0 and dz != 0 and (passable[row * columns + nc] == 0 or passable[nr * columns + column] == 0):
					continue  # no corner cutting: both orthogonal neighbours must be legal too
				var next: int = nr * columns + nc
				var cost: float = dist[here] + (_DIAGONAL if dx != 0 and dz != 0 else 1.0) * CELL
				if cost < dist[next]:
					dist[next] = cost
					previous[next] = here
					_push(heap, [cost, next])
	if goal < 0:
		return {"length": -1.0, "path": []}
	var path: Array[Vector2] = []
	var cursor: int = goal
	while cursor >= 0:
		path.push_front(area.position + Vector2(cursor % columns, cursor / columns) * CELL)
		cursor = previous[cursor]
	return {"length": float(dist[goal]), "path": path}


## How many distinct placed pieces a walked path passes through, in order (hallways excluded).
static func pieces_crossed(result: FloorComposer.ComposeResult, path: Array) -> Array[StringName]:
	var visited: Array[StringName] = []
	for point: Vector2 in path:
		for instance: FloorDraft.PieceInstance in result.draft.instances:
			if WalkableBounds.contains(FloorDraft.world_footprint(instance), point.x, point.y):
				if visited.is_empty() or visited[visited.size() - 1] != instance.instance_id:
					visited.append(instance.instance_id)
				break
	return visited


## The cardinal headings a walked path holds for at least HEADING_MIN_RUN, in order, with
## consecutive repeats merged. North is +z, as on every footprint edge.
static func headings(path: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var run_heading: String = ""
	var run_length: float = 0.0
	for index: int in range(1, path.size()):
		var step: Vector2 = path[index] - path[index - 1]
		var heading: String = ""
		if absf(step.x) >= absf(step.y):
			heading = "E" if step.x > 0.0 else "W"
		else:
			heading = "N" if step.y > 0.0 else "S"
		if heading == run_heading:
			run_length += step.length()
		else:
			run_heading = heading
			run_length = step.length()
		if run_length >= HEADING_MIN_RUN and (out.is_empty() or out[out.size() - 1] != heading):
			out.append(heading)
	return out


## SPACE GRAPH: a node per OWNER -- each placed piece and each laid hallway, read from the
## EMITTED layout's patch keys ("i03.P_HALL", "h02.R1"; the compiled plan keeps ids, not keys)
## -- and an edge per connection or touching rect
## pair between two different owners. A hallway's own legs overlap at their corners by design,
## so a patch-level graph would report loops that are only corners; this one reports the floor's
## macro topology. V, E, components, cyclomatic number, dead ends (degree 1), junctions
## (degree >= 3), extent and walkable fill.
static func topology(plan: FloorPlan, layout: AuthoredLayout) -> Dictionary:
	var owner_of: Dictionary = {}
	var rects: Array[Rect2] = []
	var owners_in_order: Array[String] = []
	for patch: WalkablePatch in layout.patches:
		var owner: String = String(patch.key).get_slice(".", 0)
		owner_of[patch.patch_id] = owner
		rects.append(patch.rect)
		if not owner in owners_in_order:
			owners_in_order.append(owner)
	var adjacent: Dictionary = {}
	for owner: String in owners_in_order:
		adjacent[owner] = {}
	for a: int in layout.patches.size():
		for b: int in range(a + 1, layout.patches.size()):
			var owner_a: String = owner_of[layout.patches[a].patch_id]
			var owner_b: String = owner_of[layout.patches[b].patch_id]
			if owner_a != owner_b and _share_boundary(rects[a], rects[b]):
				adjacent[owner_a][owner_b] = true
				adjacent[owner_b][owner_a] = true
	for connection: TraversalConnection in plan.connections:
		var near: String = owner_of.get(connection.patch_ids.x, "")
		var far: String = owner_of.get(connection.patch_ids.y, "")
		if near != "" and far != "" and near != far:
			adjacent[near][far] = true
			adjacent[far][near] = true
	var edges: int = 0
	var dead_ends: int = 0
	var junctions: int = 0
	for owner: String in owners_in_order:
		var degree: int = adjacent[owner].size()
		edges += degree
		if degree == 1:
			dead_ends += 1
		elif degree >= 3:
			junctions += 1
	edges /= 2
	var components: int = 0
	var seen: Dictionary = {}
	for owner: String in owners_in_order:
		if seen.has(owner):
			continue
		components += 1
		var stack: Array[String] = [owner]
		while not stack.is_empty():
			var here: String = stack.pop_back()
			if seen.has(here):
				continue
			seen[here] = true
			for next: String in adjacent[here]:
				stack.append(next)
	var extent: Rect2 = _extent(plan)
	var area: float = 0.0
	for rect: Rect2 in rects:
		area += rect.get_area()
	return {
		"spaces": owners_in_order.size(), "space_edges": edges, "components": components,
		"cyclomatic": edges - owners_in_order.size() + components, "dead_ends": dead_ends, "junctions": junctions,
		"extent_w": extent.size.x, "extent_d": extent.size.y,
		"fill": area / extent.get_area() if extent.get_area() > 0.0 else 0.0,
	}


static func _share_boundary(a: Rect2, b: Rect2) -> bool:
	var overlap_x: float = minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var overlap_z: float = minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	if overlap_x > 0.0 and overlap_z > 0.0:
		return true  # overlapping ground is joined ground
	return (absf(overlap_x) < 0.0001 and overlap_z > 0.0) or (absf(overlap_z) < 0.0001 and overlap_x > 0.0)


static func _extent(plan: FloorPlan) -> Rect2:
	var extent: Rect2 = Rect2()
	var rects: Array[Rect2] = plan.all_rects()
	for index: int in rects.size():
		extent = rects[index] if index == 0 else extent.merge(rects[index])
	return extent


static func _nearest_passable(area: Rect2, columns: int, rows: int, passable: PackedByteArray, point: Vector2) -> int:
	var best: int = -1
	var best_distance: float = INF
	var centre := Vector2i(int(round((point.x - area.position.x) / CELL)), int(round((point.y - area.position.y) / CELL)))
	for dz: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var column: int = centre.x + dx
			var row: int = centre.y + dz
			if column < 0 or row < 0 or column >= columns or row >= rows or passable[row * columns + column] == 0:
				continue
			var at: Vector2 = area.position + Vector2(column, row) * CELL
			if at.distance_to(point) < best_distance:
				best_distance = at.distance_to(point)
				best = row * columns + column
	return best


static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var index: int = heap.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if heap[parent][0] <= heap[index][0]:
			break
		var swap: Array = heap[parent]
		heap[parent] = heap[index]
		heap[index] = swap
		index = parent


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var index: int = 0
		while true:
			var left: int = index * 2 + 1
			var right: int = left + 1
			var smallest: int = index
			if left < heap.size() and heap[left][0] < heap[smallest][0]:
				smallest = left
			if right < heap.size() and heap[right][0] < heap[smallest][0]:
				smallest = right
			if smallest == index:
				break
			var swap: Array = heap[smallest]
			heap[smallest] = heap[index]
			heap[index] = swap
			index = smallest
	return top
