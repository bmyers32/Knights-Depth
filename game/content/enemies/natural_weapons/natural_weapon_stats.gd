class_name NaturalWeaponStats
extends Resource
## One authored enemy ACTION (Prime Directive 3) — looked up via ContentDB, never
## literals in scripts. Registers through the SAME register_weapon/register_gun/
## _apply_attack pipeline the Envoy's own weapons use (GAME-RULES §3's combat pipeline is
## fixed) — an attacking enemy synthesizes the exact same "attack" Command shape a player
## would send.
##
## P29 SCOPE RULE: this resource describes an ACTION — what happens when it fires, and
## the distance band from which it may be chosen. It deliberately no longer describes the
## ACTOR. Locomotion identity (move_speed, engagement spacing, detection/leash radii)
## migrated to the enemy stats resources at P29, because repertoire order is semantically
## meaningless and therefore NO element of the repertoire may source actor-level tuning.
## The split, stated once: actor-level spacing answers "where do I want to stand";
## the band below answers "what can I do from here". Never conflate them.

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law).

## DISTANCE BAND (P29) — the range from which the AI may select this action.
##
## BOUNDARY CONVENTION (ruled, and the reason a closed interval is wrong): every
## NON-TERMINAL band is HALF-OPEN [min_range, max_range); only the repertoire's TERMINAL
## band (the single largest max_range) includes its own maximum. A closed interval on
## both ends would make adjacent bands BOTH match at the shared edge, violating the
## overlap law in the very content that introduced it. No epsilon, no tie-breaking:
## adjacent authored bands must satisfy next.min_range == prev.max_range exactly.
##
## A single-action repertoire is by definition terminal, so [0.0, max] is inclusive at
## both ends — byte-identical to the pre-P29 `distance <= preferred_attack_distance` gate.
@export var min_range: float = 0.0
## -1.0 is a SENTINEL, not a band: ContentRegistrar resolves it to the ACTOR's
## preferred_attack_distance before anything reaches sim (sim never sees -1). This is how
## a single-action family keeps expressing "my band is exactly my engagement reach"
## without duplicating the number. It resolves against an ACTOR field, never against a
## repertoire index.
@export var max_range: float = -1.0

## CONTEXTUAL SELECTION (P29 Watcher selection pass, 2026-08-17). When true, being inside
## this action's distance band is NOT sufficient to select it: the actor must also have
## FAILED TO CLOSE for its family's authored patience, and must not already have spent this
## failed-close episode's one fallback.
##
## Deliberately narrow, deliberately NOT a generic "context gate": there is exactly one
## consumer (watcher_survey) and the rule it expresses is specifically about close-range
## frustration. Generalise only when a SECOND real context-conditioned action exists
## (rule of two) -- a framework built for one consumer is a framework built on a guess.
##
## Why it exists: distance-band eligibility made "the player is 2-9 units away" and
## "Survey happens" the same statement, which reads as turret fire. Ruling: "It shouldn't
## be the main choice of action when a certain condition exists."
@export var requires_close_frustration: bool = false

## How this action resolves: &"melee" (instant cone sweep, register_weapon) or
## &"projectile" (travel time, register_gun). The scene/registrar branches on this
## exactly like it already branches GunStats vs SwordStats for player weapons.
@export var attack_resolution: StringName = &"melee"

## Projectile-only, inert at defaults so every melee action's .tres stays unchanged.
## Speed is continuous (units/second, mirrors movement); max_lifetime is a sim-tick count
## (GAME-RULES §3: durations in sim ticks, never seconds in code).
@export var projectile_speed: float = 0.0
@export var projectile_hit_radius: float = 0.0
@export var projectile_max_lifetime_ticks: int = 0

## The resolved max_range doubles as a MELEE action's registered reach — content's job to
## keep those consistent, not sim's to enforce (a content-lint test asserts it). A
## projectile action ignores reach entirely; its band bounds SELECTION, never travel.
@export var cone_half_angle_degrees: float = 90.0
@export var windup_ticks: int = 20
## Per-ACTION cadence, but the gate it arms is SHARED PER ACTOR (SimWorld._next_fire_tick)
## — ruled at P29 for v1. Firing any action starts the cooldown for the whole repertoire,
## and an interrupted windup arms this value for the action that was actually cancelled.
## Revisit trigger is filed at ROADMAP P29: per-action cooldown is reconsidered only on
## evidence that one action is suppressing another's desired availability SPECIFICALLY
## because they share the gate — "it fires too rarely" is not that evidence.
@export var fire_interval_ticks: int = 45
@export var damage: float = 5.0
## Locked to force (MECHANICS-REFERENCE.md §2's onboarding rule: ALL enemy damage is
## the baseline type in M1-M2; typed enemy damage phases in with typed_damage_ramp).
## Kept as an exported field, not a hardcoded literal in sim/, for when that ramp lands.
@export var damage_type: StringName = &"force"
@export var knockback_distance: float = 0.5

## Telegraph law (GAME-RULES §3): one flat color stands in for a real type->color
## palette table until a second reachable enemy damage type exists — enemies are
## Force-only (onboarding rule above), so a whole mapping table has nothing else to
## map yet. Authored PER ACTION since P29 so a future TYPED action can carry its own
## type's color; presentation caches by action_id.
##
## CHANNEL LAW CONSEQUENCE, stated because it looks like a bug otherwise: two actions on
## the same actor that share a damage type MUST share a telegraph color. Colour is owned
## by the damage type, never by the action — inventing a second hue to make two Force
## actions "easier to tell apart" would be presentation stealing a channel the type owns.
## Watcher's two tells are distinguished by WINDUP DURATION instead (pulse 20 ticks vs
## survey 34, a 70% longer telegraph), plus the projectile tracer the survey produces and
## the pulse does not. If a playtest finds them still confusable, the fix is a different
## non-colour channel (disc size, pulse rate), never a colour the type does not own.
@export var telegraph_color: Color = Color(0.9, 0.4, 0.1)

## ACTION SUSCEPTIBILITY (flinch batch) — how flinchable this enemy is DURING this
## action's windup. Per-action authoring is enemy identity: a generous window on one
## action and none at all on another can both be correct. Never respond to a balance
## problem by globally shrinking every window (GAME-RULES §3 telegraph/identity law).
##
## windup_flinch_mode applies OUTSIDE the interval below:
##   &"normal"    — ordinary susceptibility (threshold and vulnerability rules apply).
##   &"protected" — rejects ALL flinch; the answer is to shield or disengage, not to
##                  interrupt. Reserved for authored heavy commitments.
## The interval OVERRIDES to VULNERABLE. So "protected early, punishable late" is
## already expressible as base &"protected" + a late interval; two DISJOINT windows in
## one action are deferred until an enemy actually needs them (ROADMAP P24).
##
## vulnerable_start_tick / vulnerable_end_tick are offsets from WINDUP START (not from
## the attack landing), inclusive, in sim ticks. -1/-1 = never vulnerable.
## Only the Watcher's actions carry windows — its lesson is timing, not pressure. Since
## P29 the window is scoped to the COMMITTED action: SimWorld reads
## _action_susceptibility[_equipped_weapon[actor]], and commitment sets that, so a
## Watcher flinched mid-survey uses survey's window and never pulse's.
@export var windup_flinch_mode: StringName = &"normal"
@export var vulnerable_start_tick: int = -1
@export var vulnerable_end_tick: int = -1
