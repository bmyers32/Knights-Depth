class_name FloorTrigger
extends Resource
## SERIALISABLE AS CONTENT (P36 Slice A). The base changed from RefCounted to Resource and the
## authored fields gained @export, so an authored floor can live in a .tres instead of in a
## builder function. Nothing else about this class moved: the same values, the same consumers,
## the same meaning. Resource IS a RefCounted, so every existing holder is unaffected.
##
## THE COMPILER NEVER HANDS A LOADED RECORD STRAIGHT TO A FloorPlan -- it copies into a fresh
## instance (LayoutCompiler). A .tres is cached and shared by path, and a plan that aliased it
## would let one run's state leak into the next.
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

## AUTHORING IDENTITY (P36 Slice A). A stable, human-readable name for this record, used by
## content cross-references and by tests. **Nothing at runtime reads it** -- the sim and the
## FloorPlan still speak in the numeric ids below, and the compiler resolves keys into those ids
## at build time. This exists because the .tres became the authoring surface and a cross-
## reference reading `target_id = 3` tells an author nothing about which door that is.
@export var key: StringName = &""
@export var trigger_id: int = -1
@export var kind: StringName = FloorLayers.TRIGGER_REGION
## TRIGGER_REGION only: the area a run-persistent actor must enter.
@export var region: Rect2 = Rect2()
## Everything else: the interactable / breakable / encounter id being watched.
## WHAT THIS TRIGGER WATCHES, by authoring key -- a breakable, an encounter, a switch. Resolved
## into source_id by the compiler, which knows from `kind` which layer to look in.
@export var source_key: StringName = &""
@export var source_id: int = -1
## One-shot by default. A commitment boundary that could re-fire is not a commitment.
@export var once: bool = true
## Dormant controllers. A disabled trigger is not evaluated at all, so it cannot fire and cannot
## bank an occupancy edge while it waits -- which is what makes "break the crate, then step on
## what it hid" work even if the Envoy is already standing there when it is revealed.
@export var starts_enabled: bool = true
## PRESENTATION ONLY. Occupancy regions come in two flavours: a visible plate you are meant to
## find and stand on, and an invisible line you cross (the one-way commitment). The sim treats
## them identically; only FloorBuilder reads this.
@export var renders_as_plate: bool = false
@export var effects: Array[Dictionary] = []
