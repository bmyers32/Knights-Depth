class_name EnvoyStats
extends Resource
## Envoy tunables (Prime Directive 3) — looked up via ContentDB, never literals in scripts.

@export var move_speed: float = 4.0

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law). This session is the first time the Envoy is
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
## COMBAT FOOTPRINT (P28) — VALIDATED-FOR-M1 at the 2026-08-13 re-gate.
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
