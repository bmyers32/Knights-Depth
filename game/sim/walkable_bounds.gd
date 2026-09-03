class_name WalkableBounds
extends RefCounted
## The authoritative walkable-area law for a loaded floor (M2 Slice 1).
##
## Lives in sim/ deliberately: GAME-RULES §4.6 forbids trusting client-reported position
## for hit resolution, so "where may an actor legally be" cannot be a property of
## presentation geometry. Godot wall meshes are a RENDERING of this data, never its
## source. Plain data (Array[Rect2], zero Node/Resource deps) so it satisfies Prime
## Directive 1's sim boundary.
##
## SIM OWNS LEGALITY; GEN CONFORMS TO IT. game/gen/depth_generator.gd imports this class,
## never the reverse -- which is what makes "the generator never emits a placement the sim
## would reject" true by construction instead of by discipline.
##
## DELIBERATELY NARROW (§1.4 rule of two): axis-aligned rectangles on the XZ plane. This is
## NOT a wall/obstacle/navmesh/pathfinding framework and must not grow into one without two
## real consumers. A floor is a UNION of rects -- patch rects plus the aperture rects that
## overlap them -- and connectivity is exactly that overlap. There is no graph, no portal list
## and no pathfinding here, and adding one needs its own justification.
##
## APERTURES MUST OVERLAP THE PATCHES THEY JOIN, never merely abut them. Two rects that touch
## on a line share zero area, so an actor is only ever inside one of them and the junction
## becomes a discontinuity the clamp cannot reason about. A real overlap gives a transition
## zone where is_inside() is true for both, which is what makes crossing a threshold
## continuous -- and it is also what makes an encounter gate free (see SimWorld: the patch's
## own rect already covers the part of the aperture inside it, so closing the aperture
## cannot shrink the space or snap an actor off the threshold).
##
## BODY EXTENT IS PART OF THE LAW (ruled 2026-08-29, after human play). Point-only legality
## could truthfully call a position legal while the actor's authored body extended through a
## solid boundary -- observed as an Ooze clipping through a wall. `fits()` is the real
## predicate: A POSITION IS LEGAL ONLY WHEN THE ACTOR'S BODY FOOTPRINT LIES INSIDE THE UNION.
##
## THE UNION IS TESTED AS A UNION, NEVER RECT BY RECT. Shrinking each rect by the radius
## independently would be wrong AND would break the floor: an actor in a doorway straddles a
## patch and an aperture, and its body fits in NEITHER alone while fitting the union perfectly.
## So `fits` subtracts the whole union from the body's bounding box and asks whether any
## uncovered remainder actually reaches the body. Connectivity is preserved by construction.

## Fixed-count bisection for the retreat search: deterministic (no convergence-epsilon loop
## whose iteration count could differ between machines), and 20 halvings resolve the largest
## authored displacement in the game far below any tolerance a test or a player can see.
const _BISECT_ITERATIONS: int = 20
## Tangency tolerance. A body resting EXACTLY against a boundary must still fit, mirroring
## is_inside's inclusive edges -- without it an actor could never touch a wall at all, and the
## bisection below would chatter against its own rounding.
const _EDGE_EPSILON: float = 0.000001

var rects: Array[Rect2] = []
## STATIC OBSTACLES, subtracted from the union (2026-09-03). A floor is walkable ground MINUS
## the things standing in it -- authored as exclusions rather than as objects, so obstacles ride
## the legality law that already exists instead of introducing a second one.
##
## They are NOT the same as absent ground: a void is somewhere the floor never was, an obstacle
## is somewhere the floor is interrupted. Presentation draws the difference; legality does not
## care, and should not.
var blockers: Array[Rect2] = []


func _init(walkable_rects: Array[Rect2] = [], obstacle_rects: Array[Rect2] = []) -> void:
	rects = walkable_rects
	blockers = obstacle_rects


## XZ projection: Rect2.position/end map to world x/z; world y (height) is ignored because
## floors are flat in M2.
##
## INCLUSIVE on both edges, unlike Rect2.has_point (which is exclusive on the far edge).
## That is not a style preference: clamp_step lands a clamped actor EXACTLY on the boundary,
## and an is_inside that rejected its own clamp output would make the two predicates
## disagree -- the actor would be legal to move to and illegal to stand on.
##
## THIS IS THE ANCHOR/FEET PREDICATE, and it is deliberately NOT body-aware: floor triggers
## ask "is this actor STANDING on this region", which is a different question from "does this
## actor's body FIT here" (ruled). Use `fits` for legality, `is_inside`/`contains` for standing.
func is_inside(point: Vector3) -> bool:
	for blocker in blockers:
		if contains(blocker, point.x, point.z):
			return false
	for rect in rects:
		if contains(rect, point.x, point.z):
			return true
	return false


## The one shared INCLUSIVE region-containment helper. Every consumer that means "this anchor
## position is on this rect" routes through here so the far-edge disagreement that Rect2's own
## has_point introduces (exclusive) can never re-enter through a second hand-rolled test.
static func contains(rect: Rect2, x: float, z: float) -> bool:
	return x >= rect.position.x and x <= rect.end.x \
			and z >= rect.position.y and z <= rect.end.y


## BODY-AWARE LEGALITY -- the authoritative "may this actor be here" predicate.
##
## radius <= 0.0 degrades EXACTLY to is_inside, so every actor registered without a body
## (the whole pre-M2 suite, target dummies, tools) keeps its original behaviour bit for bit.
func fits(point: Vector3, radius: float) -> bool:
	if rects.is_empty():
		return true
	if radius <= 0.0:
		return is_inside(point)
	var min_x: float = point.x - radius
	var max_x: float = point.x + radius
	var min_z: float = point.z - radius
	var max_z: float = point.z + radius
	var body := Rect2(min_x, min_z, radius * 2.0, radius * 2.0)
	# AN OBSTACLE IS CHECKED FIRST AND SEPARATELY, because it is a subtraction: no amount of
	# walkable coverage makes standing inside a column legal, so this cannot be folded into the
	# "is it covered" question below.
	for blocker in blockers:
		if blocker.intersects(body) and _circle_reaches(blocker.intersection(body), point.x, point.z, radius):
			return false
	# Fast path: the body sits wholly within a single rect. This is the overwhelmingly common
	# case (anywhere but a threshold or a wall), and it keeps the subtraction below off the
	# per-tick path for most actors on most ticks.
	for rect in rects:
		if min_x >= rect.position.x and max_x <= rect.end.x \
				and min_z >= rect.position.y and max_z <= rect.end.y:
			return true
	# Otherwise: whatever part of the body's bounding box the union does NOT cover is the only
	# place an illegal overlap can live. If none of that remainder actually reaches the body
	# circle, the body fits the union even though it fits no single rect.
	for piece in _uncovered(body):
		if _circle_reaches(piece, point.x, point.z, radius):
			return false
	return true


## Displacement seam. Returns the furthest legal point along an attempted move.
##
## PER-AXIS clamp, which reads as SLIDING ALONG the wall rather than sticking to it --
## deliberate, because every caller is authored displacement the player feels (locomotion,
## lunge, knockback, bump slide, burrow jump) and a hard stop on wall contact feels like a
## bug. Composes with the existing contact clamps (_find_earliest_lunge_contact): those
## shorten the segment first, this clamps whatever endpoint survived, so whichever legal
## stopping condition occurs first is the one that wins.
##
## WITH A BODY, the resting position becomes boundary-minus-radius rather than the boundary
## itself. That is the point of the law, and it is why the slide candidates are tried as whole
## axis moves FIRST: a body brushing a wall keeps its full parallel travel, and only the
## blocked component is given up.
func clamp_step(from: Vector3, to: Vector3, radius: float = 0.0) -> Vector3:
	if rects.is_empty():
		return to
	if radius <= 0.0:
		return _clamp_step_point(from, to)
	if fits(to, radius):
		return to
	# GRACEFUL DEGRADATION, never a freeze. An actor whose body does not fit where it ALREADY
	# stands (authored content predating this law, or a radius registered after placement) must
	# still be able to move -- including back out. Refusing every step would present as a
	# permanently stuck enemy, which is strictly worse than the clipping this law fixes.
	if not fits(from, radius):
		return _clamp_step_point(from, to)
	var best: Vector3 = from
	var best_distance: float = from.distance_squared_to(to)
	# Full move first, then each single-axis slide. Ties keep the earlier candidate, so the
	# outcome is a property of the geometry rather than of evaluation order (M3 replayability).
	for candidate: Vector3 in [to, Vector3(to.x, to.y, from.z), Vector3(from.x, to.y, to.z)]:
		var reached: Vector3 = _furthest_fitting(from, candidate, radius)
		var distance: float = reached.distance_squared_to(to)
		if distance < best_distance:
			best_distance = distance
			best = reached
	return best


## Furthest body-legal point on the segment [from, target]. `from` is a caller-guaranteed
## fitting position, so the bisection always has a legal lower bound to return.
func _furthest_fitting(from: Vector3, target: Vector3, radius: float) -> Vector3:
	if fits(target, radius):
		return target
	var legal: Vector3 = from
	var illegal: Vector3 = target
	for _i in _BISECT_ITERATIONS:
		var mid: Vector3 = legal.lerp(illegal, 0.5)
		if fits(mid, radius):
			legal = mid
		else:
			illegal = mid
	return legal


## The parts of `query` that no walkable rect covers, as a list of disjoint rects.
func _uncovered(query: Rect2) -> Array[Rect2]:
	var pieces: Array[Rect2] = [query]
	for rect in rects:
		var remaining: Array[Rect2] = []
		for piece in pieces:
			remaining.append_array(_subtract(piece, rect))
		pieces = remaining
		if pieces.is_empty():
			break
	return pieces


## piece minus cutter, as up to four disjoint rects (left / right / above / below the overlap).
static func _subtract(piece: Rect2, cutter: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	# Border-touching rects cover nothing, so they are not cuts -- matching the fact that a
	# zero-area overlap is exactly what "merely abutting" means everywhere else in this file.
	if not piece.intersects(cutter):
		out.append(piece)
		return out
	var inter: Rect2 = piece.intersection(cutter)
	if inter.position.x > piece.position.x:
		out.append(Rect2(piece.position.x, piece.position.y, inter.position.x - piece.position.x, piece.size.y))
	if inter.end.x < piece.end.x:
		out.append(Rect2(inter.end.x, piece.position.y, piece.end.x - inter.end.x, piece.size.y))
	if inter.position.y > piece.position.y:
		out.append(Rect2(inter.position.x, piece.position.y, inter.size.x, inter.position.y - piece.position.y))
	if inter.end.y < piece.end.y:
		out.append(Rect2(inter.position.x, inter.end.y, inter.size.x, piece.end.y - inter.end.y))
	return out


## True if the body circle actually reaches into this uncovered rect. STRICT, with a tangency
## tolerance: a body resting exactly against the edge of unlaid ground is legal, the same way
## is_inside accepts a point exactly on the boundary.
static func _circle_reaches(rect: Rect2, x: float, z: float, radius: float) -> bool:
	var nearest_x: float = clampf(x, rect.position.x, rect.end.x)
	var nearest_z: float = clampf(z, rect.position.y, rect.end.y)
	var dx: float = x - nearest_x
	var dz: float = z - nearest_z
	return dx * dx + dz * dz < radius * radius - _EDGE_EPSILON


## POINT-ONLY clamp, preserved verbatim as the radius<=0 path so bodiless actors keep their
## exact pre-2026-08-29 trajectories.
##
## MULTI-RECT (M2 multi-room slice). Evaluates a clamp candidate in EVERY rect that
## contains `from` and keeps the one nearest the intended destination.
##
## Slice 1 clamped into `_rect_index_containing(from)` -- the FIRST array-order rect holding
## the actor. In a doorway, where an aperture rect deliberately overlaps both patches, an actor
## is inside two rects at once, so array order decided which wall it hit: a PHANTOM WALL
## across an opening the player can see is open. Choosing by distance-to-destination instead
## makes the outcome a property of the geometry rather than of authoring order.
##
## Ties break on array order (strict <, first rect wins), so the result stays deterministic
## and replayable -- required for M3, where a client and the server must clamp identically.
func _clamp_step_point(from: Vector3, to: Vector3) -> Vector3:
	if is_inside(to):
		return to
	var best: Vector3 = to
	var best_distance: float = INF
	for rect in rects:
		if not contains(rect, from.x, from.z):
			continue
		var candidate: Vector3 = _clamp_into(rect, to)
		var distance: float = candidate.distance_squared_to(to)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	if best_distance < INF:
		return best
	# `from` outside every rect should be unreachable: placement fails loudly
	# (SimWorld.add_entity) and every displacement path routes through this clamp, so an
	# actor can never arrive somewhere illegal. Clamping into the nearest rect keeps a defect
	# contained rather than returning an illegal point.
	for rect in rects:
		var candidate: Vector3 = _clamp_into(rect, to)
		var distance: float = candidate.distance_squared_to(to)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _clamp_into(rect: Rect2, point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, rect.position.x, rect.end.x),
		point.y,
		clampf(point.z, rect.position.y, rect.end.y),
	)
