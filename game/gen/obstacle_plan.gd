class_name ObstaclePlan
extends RefCounted
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

var obstacle_id: int = -1
## Footprint on the XZ plane. Bodies are excluded from it; shots stop at its faces.
var rect: Rect2 = Rect2()
## Rendering only. The footprint is what gameplay reads.
var height: float = 2.4
