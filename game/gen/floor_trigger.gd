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
var effects: Array[Dictionary] = []
