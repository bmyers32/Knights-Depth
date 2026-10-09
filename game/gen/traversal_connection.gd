class_name TraversalConnection
extends Resource
## SERIALISABLE AS CONTENT (P36 Slice A). The base changed from RefCounted to Resource and the
## authored fields gained @export, so an authored floor can live in a .tres instead of in a
## builder function. Nothing else about this class moved: the same values, the same consumers,
## the same meaning. Resource IS a RefCounted, so every existing holder is unaffected.
##
## THE COMPILER NEVER HANDS A LOADED RECORD STRAIGHT TO A FloorPlan -- it copies into a fresh
## instance (LayoutCompiler). A .tres is cached and shared by path, and a plan that aliased it
## would let one run's state leak into the next.
## PROGRESSION layer: a controllable link between two patches.
##
## THE CONNECTION DOES NOT KNOW WHY IT OPENED. It owns availability and nothing else. A switch,
## an objective completion, an encounter activation or a one-way commitment all reach it
## through the same OPEN/BLOCK effect, and it can never tell them apart. That separation is the
## whole point: controllers and effects may multiply without this type changing.
##
## THE APERTURE OVERLAPS BOTH PATCHES it joins, never merely abuts them. Two rects touching on
## a line share zero area, so an actor would never be inside both and the threshold would be a
## discontinuity. The overlap is also what makes BLOCKING safe: each patch's own rect already
## covers its half of the aperture, so removing the aperture from the walkable union takes away
## the passage BEYOND the threshold without shrinking either side or snapping anyone off it.
##
## ONE-WAY COMMITMENT is deliberately NOT a field here. Bounds are positional, and a
## directional predicate would infect all eight authoritative displacement seams. A one-way
## boundary is instead an ordinary connection plus a one-shot TRIGGER_REGION whose effect
## blocks it -- same mechanism as every other controller, no new legality math.

## AUTHORING IDENTITY (P36 Slice A). A stable, human-readable name for this record, used by
## content cross-references and by tests. **Nothing at runtime reads it** -- the sim and the
## FloorPlan still speak in the numeric ids below, and the compiler resolves keys into those ids
## at build time. This exists because the .tres became the authoring surface and a cross-
## reference reading `target_id = 3` tells an author nothing about which door that is.
@export var key: StringName = &""
@export var connection_id: int = -1
## WHICH TWO SPACES THIS JOINS, by authoring key. The compiler resolves these into patch_ids.
## Left empty, patch_ids is taken as authored -- which is what the pre-migration builders did.
@export var near_key: StringName = &""
@export var far_key: StringName = &""
@export var patch_ids: Vector2i = Vector2i(-1, -1)
@export var aperture: Rect2 = Rect2()
@export var starts_open: bool = true
## Presentation hint only: whether to build a barrier mesh that can visibly close here. A
## connection with no barrier still blocks perfectly well -- it would just be invisible.
@export var has_barrier: bool = true

## WHAT THE CORRIDOR'S FLANKS ARE MADE OF, and the reason a connector need not be a trench.
##
## Aperture sides have always been emitted as full-height WALL, which is right for a doorway
## punched through an enclosed room and wrong for a hallway between two open spaces -- and every
## connector on Floor 2 was getting the doorway treatment. A long bend flanked by two 2.2-high
## walls reads as a trench you are being funnelled down, however low the rooms at either end are.
##
## `ledge` gives the same corridor a knee-high rim instead: the route is still bounded and still
## legible, the Envoy and the ground stay visible, and shots cross it the way they cross any other
## low rim. That last part is why this is a STYLE and not a cheat -- the geometry stays truthful
## either way, and the wall that stops a shot is still the wall you can see stopping it.
##
## DEFAULTS TO wall, so every connection authored before this reads exactly as it did.
@export var flank_style: StringName = &"wall"
