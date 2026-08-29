class_name FloorTrigger
extends RefCounted
## PROGRESSION layer: a controller. Watches for one condition and issues an ordered list of
## floor effects ATOMICALLY when it fires.
##
## THE OWNERSHIP LAW. One interactable may cause many deterministic floor-state changes, and
## that sequence lives in ONE authored record -- never split across gate code, spawn code and
## presentation. The reference party button is exactly one trigger:
##     [BLOCK_CONNECTION(rear), OPEN_CONNECTION(fwd), ACTIVATE_ENCOUNTER(fight)]
## Reading that line tells you the whole consequence of pressing it. Distributing those three
## effects across three systems is how "why did the door shut?" becomes unanswerable.
##
## Effects apply in order within a single tick, so a trigger can never be observed half-fired.

var trigger_id: int = -1
var kind: StringName = FloorLayers.TRIGGER_REGION
## TRIGGER_REGION only: the area a run-persistent actor must enter.
var region: Rect2 = Rect2()
## Everything else: the interactable / breakable / encounter id being watched.
var source_id: int = -1
## One-shot by default. A commitment boundary that could re-fire is not a commitment.
var once: bool = true
## Dormant controllers. A disabled trigger is not evaluated at all, so it cannot fire and cannot
## bank an occupancy edge while it waits -- which is what makes "break the crate, then step on
## what it hid" work even if the Envoy is already standing there when it is revealed.
var starts_enabled: bool = true
## PRESENTATION ONLY. Occupancy regions come in two flavours: a visible plate you are meant to
## find and stand on, and an invisible line you cross (the one-way commitment). The sim treats
## them identically; only FloorBuilder reads this.
var renders_as_plate: bool = false
var effects: Array[Dictionary] = []
