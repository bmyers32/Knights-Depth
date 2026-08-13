class_name EnvoyStats
extends Resource
## Envoy tunables (Prime Directive 3) — looked up via ContentDB, never literals in scripts.

@export var move_speed: float = 4.0

## First-pass numbers, TESTED at the M1 playtest gate 2026-08-11 (build d1dbab0,
## seed 0): verdict ITERATE, M1 NOT closed. Combat reads fair and legible (no unseen
## damage), but the gate found no encounter decisions -- "any reasonable way to kill
## works" -- and no realistically available failure: "failure must be orchestrated by
## the player." No threshold below was individually judged, so treat each as UNREFUTED,
## never confirmed. Named tuning axis for the next pass: enemy OUTPUT (damage, attack
## cadence, aggression) -- durability tuning ALONE only lengthens fights without making
## failure available. A re-gate on a frozen post-batch build closes M1
## (GAME-RULES calibration-note law). This session is the first time the Envoy is
## a registered combatant (SimWorld.register_combatant), so it can take real damage —
## from Burn's contact-spread/DoT specifically (GAME-RULES §3's enemy<->player
## allegiance rule). No enemy attack exists yet, so this health is only reachable
## through Burn this session. 30.0 max_health against Burn's full-duration ~12.0 DoT
## total (burn_stats.tres) is ~40% of health: painful but survivable by design.
@export var max_health: float = 30.0
## Absent from the damage matrix (game/content/combat/damage_matrix.tres) — any typed
## hit against the Envoy resolves at the neutral 1.0 multiplier. Registered anyway
## (mirrors FangStats/OozeStats/WatcherStats' own family field) for consistency, not
## because a matrix row is needed yet.
@export var family: StringName = &"envoy"
## COMBAT FOOTPRINT (P28 calibration, 2026-08-13) — PROVISIONAL/UNVALIDATED.
## The authoritative body radius: feeds BOTH Burn's contact-spread and the melee
## lunge clamp through the one shared _contact_distance (GAME-RULES §3), so it is
## never tuned for one of those in isolation. Derived from this model's CORE
## SILHOUETTE (radial p50 across its torso band), deliberately NOT its mesh AABB:
## the Knight model's 0.97 AABB is mostly an outstretched weapon, not body.
## Adopted after a live playtest confirmed believable body separation at authored
## contact with no toy-scale side effect. **REVALIDATION TRIGGER:** there is no
## sword model or attack animation yet, so weapon-reach/contact ALIGNMENT is
## explicitly NOT validated — re-check once real attack visuals exist, and do not
## retune this geometry to fix an animation problem unless authoritative contact
## itself proves wrong. Method + trigger recorded at ROADMAP P28.
@export var combat_radius: float = 0.45
