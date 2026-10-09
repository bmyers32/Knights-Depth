class_name EncounterSite
extends Resource
## SERIALISABLE AS CONTENT (P36 Slice A). The base changed from RefCounted to Resource and the
## authored fields gained @export, so an authored floor can live in a .tres instead of in a
## builder function. Nothing else about this class moved: the same values, the same consumers,
## the same meaning. Resource IS a RefCounted, so every existing holder is unaffected.
##
## THE COMPILER NEVER HANDS A LOADED RECORD STRAIGHT TO A FloorPlan -- it copies into a fresh
## instance (LayoutCompiler). A .tres is cached and shared by path, and a plan that aliased it
## would let one run's state leak into the next.
## ENCOUNTER layer. An ENCOUNTER REGION IS NOT A PHYSICAL ROOM -- that conflation is precisely
## what the multi-room slice falsified. A site is a region plus a roster plus a role, and it
## may sit anywhere in a continuous space.
##
## ACTIVATION IS AUTHORED. There is no "player entered my region, therefore fight" rule
## anywhere in the sim; an encounter starts because an effect said so. That is the
## generalisation of the one thing the last playtest positively liked -- the explicit
## "hit this button, start the encounter" sequence, which Breon reported "was solid."
##
## CONFINEMENT vs OWNERSHIP, kept separate:
##   `regions` confine this site's ROSTER always, whatever the state -- an enemy never leaves
##            its authored territory (ruled), and that includes AMBIENT rosters. A territory is
##            a UNION of regions, not one patch: human play falsified the accidental assumption
##            that territory == exactly one WalkablePatch, which read as an ambient Ooze stuck
##            on a corner the instant its quarry crossed a patch seam it was meant to inhabit.
##            Widening a territory is an AUTHORING act; it never repeals confinement, and it is
##            not floor-wide roaming (no roaming and no pathfinding exist).
##   `confines_player` decides whether ACTIVATION also seals the Envoy in. AMBIENT sites set it
##            false: enemies engage naturally as the player passes through, with no activation
##            ceremony and no arena lock.

## AUTHORING IDENTITY (P36 Slice A). A stable, human-readable name for this record, used by
## content cross-references and by tests. **Nothing at runtime reads it** -- the sim and the
## FloorPlan still speak in the numeric ids below, and the compiler resolves keys into those ids
## at build time. This exists because the .tres became the authoring surface and a cross-
## reference reading `target_id = 3` tells an author nothing about which door that is.
@export var key: StringName = &""
@export var encounter_id: int = -1
@export var regions: Array[Rect2] = []
@export var role: StringName = FloorLayers.ROLE_MANDATORY
## [{"enemy_key": StringName, "position": Vector3}] -- room-local in the old model, site-local
## now. Every actor here is owned by this site for its whole life.
@export var roster: Array[Dictionary] = []
@export var confines_player: bool = true
## AMBIENT rosters exist from floor load; triggered rosters materialise on activation, which is
## what makes a party button feel like it summoned something.
@export var spawn_at_floor_load: bool = false
