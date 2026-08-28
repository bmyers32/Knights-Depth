class_name FloorLayers
extends RefCounted
## THE FOUR INDEPENDENT LAYERS of a floor, and the vocabularies they share.
##
## A floor is a CONTINUOUS, STATEFUL TRAVERSAL SPACE whose available routes change in response
## to player actions -- not rooms-plus-doors. The multi-room slice falsified "sequential
## rectangular rooms connected by doors" as the parent abstraction (Breon, 2026-08-28: "It's
## still giving 4 boxes"), so NO LAYER PARENTS ANOTHER:
##
##   SPATIAL       WalkablePatch[]        geometry only, carries no semantics
##   PROGRESSION   TraversalConnection[]  availability, ignorant of its cause
##                 FloorTrigger[]         controllers
##                 (effects)              what a controller does
##   ENCOUNTER     EncounterSite[]        region != room, activation is AUTHORED
##   INTERACTION   InteractablePlan[] · BreakablePlan[]
##
## Constants live together here because they are a shared VOCABULARY rather than any one
## layer's property -- an effect names a connection, a trigger names an encounter, and none of
## them owns the words.

# --- PROGRESSION: what a controller can do -------------------------------------------
# THE CONTROLLED TRAVERSAL LAW: "the gate does not need to understand why it opened."
# A connection holds availability STATE. Effects write that state. Nothing links a connection
# back to whatever caused the change, so switches, objectives, encounter clears and one-way
# commitment are all the same thing to it.
const EFFECT_OPEN_CONNECTION: StringName = &"open_connection"
const EFFECT_BLOCK_CONNECTION: StringName = &"block_connection"
const EFFECT_ACTIVATE_ENCOUNTER: StringName = &"activate_encounter"
const EFFECT_REVEAL_INTERACTABLE: StringName = &"reveal_interactable"

# --- PROGRESSION: what can cause it ---------------------------------------------------
## Deliberately narrow. Note what is ABSENT: there is no "entered the encounter region" kind,
## because `enter area => start combat` is exactly what the last slice shipped and what was
## rejected. A trigger volume is still possible -- as an explicitly authored TRIGGER_REGION
## whose effects happen to include an activation -- but it can never be implied by geometry.
const TRIGGER_REGION: StringName = &"region_entered"
const TRIGGER_INTERACTED: StringName = &"interacted"
const TRIGGER_BREAKABLE_DESTROYED: StringName = &"breakable_destroyed"
const TRIGGER_ENCOUNTER_CLEARED: StringName = &"encounter_cleared"

# --- ENCOUNTER roles ------------------------------------------------------------------
## MANDATORY  completion may control required progression
## OPTIONAL   physically bypassable without ever activating it
## AMBIENT    inhabits its territory; no activation ceremony, no player lock. Its roster is
##            still CONFINED to that authored region -- ambient does not yet mean whole-floor
##            roaming, and this prototype adds no roaming/pathfinding system.
const ROLE_MANDATORY: StringName = &"mandatory"
const ROLE_OPTIONAL: StringName = &"optional"
const ROLE_AMBIENT: StringName = &"ambient"

# --- INTERACTABLE availability --------------------------------------------------------
## HIDDEN is how concealment-by-breakable is expressed: the interactable exists in the plan
## from the start, but is neither visible nor usable until a REVEAL effect enables it.
const INTERACTABLE_HIDDEN: StringName = &"hidden"
const INTERACTABLE_AVAILABLE: StringName = &"available"
const INTERACTABLE_USED: StringName = &"used"


## Builds one effect record. Plain data so it crosses into sim/ unchanged (Prime Directive 1)
## and serializes for M3, where floor state is server-authoritative (GAME-RULES §4.1).
static func effect(kind: StringName, target_id: int) -> Dictionary:
	return {"kind": kind, "target_id": target_id}
