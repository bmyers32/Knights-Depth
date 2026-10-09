class_name ObstaclePlan
extends Resource
## SERIALISABLE AS CONTENT (P36 Slice A). The base changed from RefCounted to Resource and the
## authored fields gained @export, so an authored floor can live in a .tres instead of in a
## builder function. Nothing else about this class moved: the same values, the same consumers,
## the same meaning. Resource IS a RefCounted, so every existing holder is unaffected.
##
## THE COMPILER NEVER HANDS A LOADED RECORD STRAIGHT TO A FloorPlan -- it copies into a fresh
## instance (LayoutCompiler). A .tres is cached and shared by path, and a plan that aliased it
## would let one run's state leak into the next.
## SPATIAL layer: a STATIC gameplay obstacle -- a column, a rock, a machine, a ruin.
##
## ITS WHOLE JOB IS TO SHAPE SPACE: cover, sightlines, combat spacing, approach angles, lanes.
## It is not a combatant, it is not breakable, and it is not decoration.
##
## ONE AUTHORED FACT, BOTH CONSUMERS (ruled 2026-09-03). If it looks solid, actor legality
## agrees; if it stops a shot, the projectile geometry agrees -- and both read the SAME rect.
## There is deliberately no presentation-only cover and no invisible blocker, which is the exact
## failure P34 was fought over: a wall that exists for one consumer and not the other.
##
## A HOLE IN THE FLOOR, NOT A THING ON IT. Walkable space is a union of rects, so an obstacle is
## authored as an EXCLUSION from that union rather than as an object standing in it. That keeps
## it inside the legality law already shipped -- body-aware, union-tested -- instead of inventing
## a second notion of "something you cannot walk through".

## AUTHORING IDENTITY (P36 Slice A). A stable, human-readable name for this record, used by
## content cross-references and by tests. **Nothing at runtime reads it** -- the sim and the
## FloorPlan still speak in the numeric ids below, and the compiler resolves keys into those ids
## at build time. This exists because the .tres became the authoring surface and a cross-
## reference reading `target_id = 3` tells an author nothing about which door that is.
@export var key: StringName = &""
@export var obstacle_id: int = -1
## Footprint on the XZ plane. Bodies are excluded from it; shots stop at its faces.
@export var rect: Rect2 = Rect2()
## Rendering only. The footprint is what gameplay reads.
@export var height: float = 2.4
