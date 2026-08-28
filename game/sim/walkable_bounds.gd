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
## into one without two real consumers. Slice 1 authors exactly ONE rect per floor; the
## Array shape exists because FloorPlan already needs to describe a floor's walkable set,
## not as a down payment on multi-room connectivity (see clamp_step's doorway note).

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
## `from` selects WHICH rect constrains the move -- an actor is clamped against the room it
## is standing in. Doorways/overlapping rects are NOT handled and NOT tested: Slice 1
## authors one rect, and multi-rect connectivity is a later M2 question that must arrive
## with its own tests rather than inherit an untested code path here.
func clamp_step(from: Vector3, to: Vector3) -> Vector3:
	if rects.is_empty() or is_inside(to):
		return to
	var index: int = _rect_index_containing(from)
	if index < 0:
		# `from` outside every rect should be unreachable: spawn/registration placement
		# fails loudly (SimWorld.add_entity) and every displacement path routes through
		# this clamp, so an actor can never arrive somewhere illegal. Falling back to the
		# first rect keeps a defect contained instead of returning an illegal point.
		index = 0
	var rect: Rect2 = rects[index]
	return Vector3(
		clampf(to.x, rect.position.x, rect.end.x),
		to.y,
		clampf(to.z, rect.position.y, rect.end.y),
	)


func _rect_index_containing(point: Vector3) -> int:
	for index in rects.size():
		var rect: Rect2 = rects[index]
		if point.x >= rect.position.x and point.x <= rect.end.x \
				and point.z >= rect.position.y and point.z <= rect.end.y:
			return index
	return -1
