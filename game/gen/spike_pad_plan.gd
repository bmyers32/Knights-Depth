class_name SpikePadPlan
extends Resource
## SERIALISABLE AS CONTENT (P36 Slice A). The base changed from RefCounted to Resource and the
## authored fields gained @export, so an authored floor can live in a .tres instead of in a
## builder function. Nothing else about this class moved: the same values, the same consumers,
## the same meaning. Resource IS a RefCounted, so every existing holder is unaffected.
##
## THE COMPILER NEVER HANDS A LOADED RECORD STRAIGHT TO A FloorPlan -- it copies into a fresh
## instance (LayoutCompiler). A .tres is cached and shared by path, and a plan that aliased it
## would let one run's state leak into the next.
## HAZARD layer: a timed spike pad. The first hazard, and deliberately the smallest one.
##
## RISK TOPOLOGY, NOT WALKABILITY. A hazard does not change where you may stand -- it changes
## what standing there costs, and when. That is what separates it from WALL (persistent
## topology), DOOR (state-controlled), DESTRUCTIBLE (removable) and OBSTACLE (solid).
##
## THE CYCLE IS AUTHORITATIVE AND DERIVED FROM THE TICK, never from an animation: phase is a pure
## function of tick_count and the authored numbers, so presentation can only ever project it.
## `phase_offset_ticks` lets neighbouring pads run out of step WITHOUT any per-pad clock -- the
## same trick the channel law requires of family motion, for the same reason.
##
## V1 FENCE, and a hard one: no randomised cycle, no linked trap networks, no status
## application, no switch-controlled spikes, no generalized trap scripting. Those need concrete
## consumers, and this one has exactly one job.

## AUTHORING IDENTITY (P36 Slice A). A stable, human-readable name for this record, used by
## content cross-references and by tests. **Nothing at runtime reads it** -- the sim and the
## FloorPlan still speak in the numeric ids below, and the compiler resolves keys into those ids
## at build time. This exists because the .tres became the authoring surface and a cross-
## reference reading `target_id = 3` tells an author nothing about which door that is.
@export var key: StringName = &""
@export var pad_id: int = -1
## Footprint. Standing on it is the predicate -- the same "is this actor on this region" question
## a plate asks, and deliberately not a body-overlap test, so the two cannot disagree.
@export var rect: Rect2 = Rect2()
@export var safe_ticks: int = 60
@export var active_ticks: int = 30
@export var phase_offset_ticks: int = 0
@export var damage: float = 12.0
@export var damage_type: StringName = &"force"
## WHO THIS HAZARD ACTUALLY HURTS, authored explicitly (ruled 2026-09-04).
##
## THE DEFAULT IS THE PLAYER ALONE, because the human ruled that enemies do not die to spikes --
## and the general lesson is stated here rather than assumed: "environment damage" does NOT imply
## "damages everything". Eligibility is a property of the authored hazard, so a later explosive
## block may legitimately hurt whatever its own content says it hurts.
##
## An allegiance list rather than a bool, so widening it needs no new field and no new law.
@export var eligible_allegiances: Array[StringName] = [&"player"]
