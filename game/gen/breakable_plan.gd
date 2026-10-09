class_name BreakablePlan
extends Resource
## SERIALISABLE AS CONTENT (P36 Slice A). The base changed from RefCounted to Resource and the
## authored fields gained @export, so an authored floor can live in a .tres instead of in a
## builder function. Nothing else about this class moved: the same values, the same consumers,
## the same meaning. Resource IS a RefCounted, so every existing holder is unaffected.
##
## THE COMPILER NEVER HANDS A LOADED RECORD STRAIGHT TO A FloorPlan -- it copies into a fresh
## instance (LayoutCompiler). A .tres is cached and shared by path, and a plan that aliased it
## would let one run's state leak into the next.
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

## AUTHORING IDENTITY (P36 Slice A). A stable, human-readable name for this record, used by
## content cross-references and by tests. **Nothing at runtime reads it** -- the sim and the
## FloorPlan still speak in the numeric ids below, and the compiler resolves keys into those ids
## at build time. This exists because the .tres became the authoring surface and a cross-
## reference reading `target_id = 3` tells an author nothing about which door that is.
@export var key: StringName = &""
@export var breakable_id: int = -1
@export var position: Vector3 = Vector3.ZERO
@export var radius: float = 0.7
## ORDINARY PROPS BREAK IN ONE HIT (ruled 2026-09-04). Clearing scenery must not feel like
## fighting a low-health enemy, so the baseline is deliberately below any authored weapon damage.
## A prop whose ROLE needs more -- a route blocker meant to cost something -- authors its own
## value; this is a default, not a law that every destructible is fragile.
@export var durability: float = 1.0
## interactable_id revealed on destruction, or -1 for a purely decorative prop.
@export var conceals_trigger_id: int = -1
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
@export var blocking_rect: Rect2 = Rect2()
