class_name HitSwitchPlan
extends Resource
## SERIALISABLE AS CONTENT (P36 Slice A). The base changed from RefCounted to Resource and the
## authored fields gained @export, so an authored floor can live in a .tres instead of in a
## builder function. Nothing else about this class moved: the same values, the same consumers,
## the same meaning. Resource IS a RefCounted, so every existing holder is unaffected.
##
## THE COMPILER NEVER HANDS A LOADED RECORD STRAIGHT TO A FloorPlan -- it copies into a fresh
## instance (LayoutCompiler). A .tres is cached and shared by path, and a plan that aliased it
## would let one run's state leak into the next.
## WORLD INTERACTION layer: a PERSISTENT hit target that fires authored floor effects.
##
## WHY IT IS NOT A BREAKABLE. The seam audit found that "hit a world object -> fire floor
## effects" is already expressible: a BreakablePlan is hittable, is explicitly not a combatant,
## and TRIGGER_BREAKABLE_DESTROYED already reaches OPEN_CONNECTION. The gap was exactly one
## thing -- the object is CONSUMED doing it. That is right for a crate and wrong for a switch,
## and it makes a toggle inexpressible, because destruction happens once.
##
## So a switch is not a crate that happens not to disappear (ruled 2026-09-03). It survives
## activation, it may be used again, and a toggle is its whole point.
##
## AND IT IS NOT AN INTERACTABLE. `interact` and TRIGGER_INTERACTED were retired for having no
## consumer, and nothing here brings them back: this is not a keypress at close range, it is a
## deliberate combat/world target you notice, line up on, and hit. A plate says GO AND STAND; a
## switch says SEE IT AND SHOOT IT. Both stay because their spatial meaning differs.
##
## STILL NOT A COMBATANT, for the reasons the breakable audit already established: registering
## one as a combatant would drag in shield bump, lunge clamp, burrow occupancy, contact-spread,
## i-frames, flinch, knockback and status procs, and would make it a valid target for enemy AI.
## It shares only DETECTION with the melee cone and the projectile sweep.

## THE WORLD-CONTROL LAW (2026-09-06), living with the seam it governs rather than in a review:
##
##     A WORLD-OPERABLE CONTROL IS NOT GATED BY WEAPON TYPE, unless weapon specificity is an
##     explicit authored mechanic. If an attack can validly strike world props, it can operate
##     world hit-controls.
##
## Operability derives from "can this attack legitimately reach a world target here", never from
## "what is equipped". That is true by construction rather than by intention: `_resolve_melee_swing`
## consults the switch cone beside the breakable cone, and the projectile sweep consults the switch
## sweep beside the breakable sweep. ONE seam, two consumers -- a third weapon class inherits it
## without being asked to remember.

const MODE_ONE_SHOT: StringName = &"one_shot"
const MODE_TOGGLE: StringName = &"toggle"

## AUTHORING IDENTITY (P36 Slice A). A stable, human-readable name for this record, used by
## content cross-references and by tests. **Nothing at runtime reads it** -- the sim and the
## FloorPlan still speak in the numeric ids below, and the compiler resolves keys into those ids
## at build time. This exists because the .tres became the authoring surface and a cross-
## reference reading `target_id = 3` tells an author nothing about which door that is.
@export var key: StringName = &""
@export var switch_id: int = -1
@export var position: Vector3 = Vector3.ZERO
@export var radius: float = 0.7
## ONE_SHOT fires once and then ignores every later hit. TOGGLE fires on every accepted
## activation, which is what makes "shoot to open, shoot again to close" authorable.
@export var mode: StringName = MODE_ONE_SHOT
## Fired on each accepted activation, in authored order. Ordinary floor effects -- the switch
## causes them and never interprets them, exactly as a plate does.
@export var effects: Array[Dictionary] = []
## A HIDDEN switch is not drawn and cannot be hit. It becomes real when something reveals it --
## which is how concealment composes: break the cover, and the thing behind it was always there.
@export var starts_hidden: bool = false
