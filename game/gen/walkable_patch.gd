class_name WalkablePatch
extends RefCounted
## SPATIAL layer: one rectangle of standable ground. Carries NO semantics -- not a room, not
## an encounter, not a zone. Progression, encounters and interactions are separate layers that
## merely happen to sit somewhere.
##
## IRREGULARITY IS FREE. A patch is much smaller than a room, so open areas, narrow connectors,
## L-shapes, and paths wrapping a void are all just unions of overlapping patches -- and
## WalkableBounds (union test + per-axis clamp, with the array-order phantom-wall fix already
## in) consumes that unchanged. A VOID is simply the absence of a patch. Folded topology needs
## no machinery at all: seeing a destination is free, reaching it is the route.
##
## `zone` metadata was considered and DROPPED: no mechanic queries it yet, and a taxonomy with
## no consumer is a schema pretending to be a design (§1.4).

var patch_id: int = -1
var rect: Rect2 = Rect2()

## PRESENTATION ONLY. Combat stays on one plane (ruled: depth comes from space, not from
## vertical combat systems), so the sim never reads this -- it exists so FloorBuilder can raise
## a platform and ramp up to it. If the floor still reads flat AFTER the spatial pass, that is
## the evidence that would justify authoritative height mechanics; until then, this is a look.
var elevation: float = 0.0
## Visual key only, same reasoning as elevation.
var surface: StringName = &"stone"

## PRESENTATION ONLY, and the point of it is what it is NOT: not every walkability edge is a
## wall (human finding, 2026-08-29 -- "some reference-floor platforms have open/ledge edges
## while still preventing the player from falling"). Sim legality is unchanged and unchanged in
## purpose; an actor still cannot leave walkable ground. This only decides whether FloorBuilder
## RENDERS that boundary as a solid wall or leaves it an open ledge you can see over.
##   &"wall"   solid vertical boundary (default)
##   &"ledge"  open edge -- no wall mesh, still mechanically bounded
var boundary_style: StringName = &"wall"


func centre() -> Vector3:
	return Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
