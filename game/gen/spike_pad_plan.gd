class_name SpikePadPlan
extends RefCounted
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

var pad_id: int = -1
## Footprint. Standing on it is the predicate -- the same "is this actor on this region" question
## a plate asks, and deliberately not a body-overlap test, so the two cannot disagree.
var rect: Rect2 = Rect2()
var safe_ticks: int = 60
var active_ticks: int = 30
var phase_offset_ticks: int = 0
var damage: float = 12.0
var damage_type: StringName = &"force"
