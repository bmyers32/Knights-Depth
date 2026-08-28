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
## DELIBERATELY NARROW (§1.4 rule of two): axis-aligned rectangles on the XZ plane and two
## predicates. This is NOT a wall/obstacle/navmesh/pathfinding framework and must not grow
## into one without two real consumers. A floor is a UNION of rects -- room rects plus the
## aperture rects that overlap them -- and connectivity is exactly that overlap. There is no
## graph, no portal list and no pathfinding here, and adding one needs its own justification.
##
## APERTURES MUST OVERLAP THE ROOMS THEY JOIN, never merely abut them. Two rects that touch
## on a line share zero area, so an actor is only ever inside one of them and the junction
## becomes a discontinuity the clamp cannot reason about. A real overlap gives a transition
## zone where is_inside() is true for both, which is what makes crossing a threshold
## continuous -- and it is also what makes an encounter gate free (see SimWorld: the room's
## own rect already covers the part of the aperture inside it, so closing the aperture
## cannot shrink the room or snap an actor off the threshold).

var rects: Array[Rect2] = []


func _init(walkable_rects: Array[Rect2] = []) -> void:
	rects = walkable_rects


## XZ projection: Rect2.position/end map to world x/z; world y (height) is ignored because
## floors are flat in M2.
##
## INCLUSIVE on both edges, unlike Rect2.has_point (which is exclusive on the far edge).
## That is not a style preference: clamp_step lands a clamped actor EXACTLY on the boundary,
## and an is_inside that rejected its own clamp output would make the two predicates
## disagree -- the actor would be legal to move to and illegal to stand on.
func is_inside(point: Vector3) -> bool:
	for rect in rects:
		if point.x >= rect.position.x and point.x <= rect.end.x \
				and point.z >= rect.position.y and point.z <= rect.end.y:
			return true
	return false


## Displacement seam. Returns the furthest legal point along an attempted move.
##
## PER-AXIS clamp, which reads as SLIDING ALONG the wall rather than sticking to it --
## deliberate, because every caller is authored displacement the player feels (locomotion,
## lunge, knockback, bump slide, burrow jump) and a hard stop on wall contact feels like a
## bug. Composes with the existing contact clamps (_find_earliest_lunge_contact): those
## shorten the segment first, this clamps whatever endpoint survived, so whichever legal
## stopping condition occurs first is the one that wins.
##
## MULTI-RECT (M2 multi-room slice). Evaluates a clamp candidate in EVERY rect that
## contains `from` and keeps the one nearest the intended destination.
##
## Slice 1 clamped into `_rect_index_containing(from)` -- the FIRST array-order rect holding
## the actor. In a doorway, where an aperture rect deliberately overlaps both rooms, an actor
## is inside two rects at once, so array order decided which wall it hit: a PHANTOM WALL
## across an opening the player can see is open. Choosing by distance-to-destination instead
## makes the outcome a property of the geometry rather than of authoring order.
##
## Ties break on array order (strict <, first rect wins), so the result stays deterministic
## and replayable -- required for M3, where a client and the server must clamp identically.
##
## Note the ordinary doorway case never reaches any of this: `to` inside ANY rect returns
## early, so walking through an opening is simply legal.
func clamp_step(from: Vector3, to: Vector3) -> Vector3:
	if rects.is_empty() or is_inside(to):
		return to
	var best: Vector3 = to
	var best_distance: float = INF
	for rect in rects:
		if not _contains(rect, from):
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


func _contains(rect: Rect2, point: Vector3) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x \
			and point.z >= rect.position.y and point.z <= rect.end.y
