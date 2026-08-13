class_name WatcherStats
extends Resource
## Watcher (Claimed state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
## via ContentDB, never literals in scripts. True name: Custodian (Archive-recoverable,
## LEXICON.md) — not used in code identifiers, folk name only per the true-names law.

## First-pass numbers, TESTED at the M1 playtest gate 2026-08-11 (build d1dbab0,
## seed 0): verdict ITERATE, M1 NOT closed. Combat reads fair and legible (no unseen
## damage), but the gate found no encounter decisions -- "any reasonable way to kill
## works" -- and no realistically available failure: "failure must be orchestrated by
## the player." No threshold below was individually judged, so treat each as UNREFUTED,
## never confirmed. Named tuning axis for the next pass: enemy OUTPUT (damage, attack
## cadence, aggression) -- durability tuning ALONE only lengthens fights without making
## failure available. A re-gate on a frozen post-batch build closes M1
## (GAME-RULES calibration-note law).
@export var max_health: float = 20.0
@export var family: StringName = &"watcher"
## FLINCH threshold (batch, PROVISIONAL/UNVALIDATED 2026-08-12): deliberately HIGH --
## Watcher's lesson is not pressure but the authored VULNERABLE window on its windup
## (watcher_pulse.tres), so raw damage is the expensive route and timing is the cheap
## one. Tuned jointly with max_health; the two are ONE decision per enemy.
@export var flinch_threshold: float = 24.0
## Cadence constraint + derivation: see FangStats.iframe_ticks_on_hit. Same value for
## the same reason (this is a combat-wide invariant, not a per-family identity yet);
## PROVISIONAL/UNVALIDATED, revisit at the re-gate.
@export var iframe_ticks_on_hit: int = 5
## COMBAT FOOTPRINT (P28 calibration, 2026-08-13) — PROVISIONAL/UNVALIDATED.
## The authoritative body radius: feeds BOTH Burn's contact-spread and the melee
## lunge clamp through the one shared _contact_distance (GAME-RULES §3), so it is
## never tuned for one of those in isolation. Derived from this model's CORE
## SILHOUETTE (radial p50 across its torso band), deliberately NOT its mesh AABB:
## Goleling's 2.19 AABB is outstretched arms (core p50 = 0.80).
## Adopted after a live playtest confirmed believable body separation at authored
## contact with no toy-scale side effect. **REVALIDATION TRIGGER:** there is no
## sword model or attack animation yet, so weapon-reach/contact ALIGNMENT is
## explicitly NOT validated — re-check once real attack visuals exist, and do not
## retune this geometry to fix an animation problem unless authoritative contact
## itself proves wrong. Method + trigger recorded at ROADMAP P28.
@export var combat_radius: float = 0.85
