class_name HitSwitchPlan
extends RefCounted
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

var switch_id: int = -1
var position: Vector3 = Vector3.ZERO
var radius: float = 0.7
## ONE_SHOT fires once and then ignores every later hit. TOGGLE fires on every accepted
## activation, which is what makes "shoot to open, shoot again to close" authorable.
var mode: StringName = MODE_ONE_SHOT
## Fired on each accepted activation, in authored order. Ordinary floor effects -- the switch
## causes them and never interprets them, exactly as a plate does.
var effects: Array[Dictionary] = []
## A HIDDEN switch is not drawn and cannot be hit. It becomes real when something reveals it --
## which is how concealment composes: break the cover, and the thing behind it was always there.
var starts_hidden: bool = false
