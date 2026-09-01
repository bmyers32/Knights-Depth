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

## PER-SIDE OVERRIDES, added 2026-09-01 because patch granularity was FALSIFIED by authoring: the
## hall wants an open outer perimeter AND a solid void-facing interior, and both belong to the
## same rectangle. One flag cannot say two things.
##
## DELIBERATELY NARROW -- four axis-aligned sides of a rectangle, nothing more. Not polygon edge
## metadata, not a material system, not generalized boundary components. The consumer is
## rectangular WalkablePatch boundary semantics and that is all this serves.
##
## AXIS NAMING, stated so it cannot be guessed wrong: NORTH is the MAX-z side (toward the floor's
## entrance, up-screen), SOUTH the MIN-z side, EAST the MAX-x side, WEST the MIN-x side.
##
## Empty means "inherit boundary_style":
##     effective_edge_style = side_override if authored else boundary_style
##
## SPLITTING PATCHES TO FAKE THIS WAS REJECTED. Walkable patches describe walkable SPACE; boundary
## style describes boundary SEMANTICS. Making one impersonate the other would leave geometry seams
## whose only purpose is to compensate for missing vocabulary.
var boundary_north: StringName = &""
var boundary_south: StringName = &""
var boundary_east: StringName = &""
var boundary_west: StringName = &""


## The style that actually governs one side.
func edge_style(side: StringName) -> StringName:
	var override: StringName = &""
	match String(side):
		"north": override = boundary_north
		"south": override = boundary_south
		"east": override = boundary_east
		"west": override = boundary_west
	return boundary_style if override == &"" else override


func centre() -> Vector3:
	return Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
