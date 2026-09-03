class_name BreakablePlan
extends RefCounted
## WORLD INTERACTION layer: a minimal destructible prop.
##
## SCOPE FENCE, and it is a hard one. This exists ONLY to test
##     search environment -> discover progression control.
## No currency, no hearts, no loot table, no drop economy, no generalized destructible
## framework. Its entire authored consequence is: destroyed -> optionally reveal a contained
## interactable.
##
## A BREAKABLE IS NOT A COMBATANT. The pre-code inheritance audit (ROADMAP) found that
## registering one via register_combatant would drag in shield bump, lunge clamp, burrow
## occupancy, Burn contact-spread, i-frames, flinch, pressure, knockback, status procs -- and
## would make props valid attack targets for enemies, since _is_valid_target only compares
## allegiance. Four of six scans wrong and ten reactions wrong: the pipeline does not fork
## cleanly, so props get their own registry and share only DETECTION with the melee cone and
## the projectile sweep.

var breakable_id: int = -1
var position: Vector3 = Vector3.ZERO
var radius: float = 0.7
var durability: float = 1.0
## interactable_id revealed on destruction, or -1 for a purely decorative prop.
var conceals_trigger_id: int = -1
## REMOVABLE TOPOLOGY (2026-09-03). An EMPTY rect means the prop is a target and nothing more --
## the original behaviour, unchanged. A real rect means it also OCCUPIES that ground until it is
## destroyed, and then stops.
##
## THIS IS WHAT SEPARATES A DESTRUCTIBLE FROM A PROP WITH HP. Its authored spatial role is the
## point: temporary route blockage, sightline blockage, temporary cover, enemy containment. A
## breakable that shapes no space is decoration you can hit.
##
## Deliberately the SAME representation an obstacle uses -- an exclusion from the walkable union
## -- so "solid until broken" is the obstacle law with an end date rather than a second notion of
## impassable.
var blocking_rect: Rect2 = Rect2()
