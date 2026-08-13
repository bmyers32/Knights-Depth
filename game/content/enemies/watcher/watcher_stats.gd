class_name WatcherStats
extends Resource
## Watcher (Claimed state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
## via ContentDB, never literals in scripts. True name: Custodian (Archive-recoverable,
## LEXICON.md) — not used in code identifiers, folk name only per the true-names law.

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law).
## STEP-6 TUNING (batch) — VALIDATED-FOR-M1 at the 2026-08-13 re-gate; answers the M1
## gate's ITERATE finding #3 ("failure must be orchestrated by the player").
## HP and flinch_threshold are ONE co-authored decision and must move together;
## OUTPUT (damage/cadence) is co-equal with durability, never durability alone --
## more HP by itself only lengthens fights without making failure available.
## Watcher: squishiest, survives one combo with 12 margin. Threshold stays
## HIGHEST (24), deliberately ABOVE hits 1+2 (16), so pressure cashes only on a
## full combo -- making the authored VULNERABLE window the cheap route and raw
## damage the expensive one. A charge alone (20) cannot cash here, by design.
@export var max_health: float = 38.0
@export var family: StringName = &"watcher"
## FLINCH threshold (batch, PROVISIONAL/UNVALIDATED 2026-08-12): deliberately HIGH --
## Watcher's lesson is not pressure but the authored VULNERABLE window on its windup
## (watcher_pulse.tres), so raw damage is the expensive route and timing is the cheap
## one. Tuned jointly with max_health; the two are ONE decision per enemy.
@export var flinch_threshold: float = 24.0
## Cadence constraint + derivation: see FangStats.iframe_ticks_on_hit. Same value for
## the same reason (this is a combat-wide invariant, not a per-family identity yet);
## VALIDATED-FOR-M1 at the 2026-08-13 re-gate.
@export var iframe_ticks_on_hit: int = 5
## COMBAT FOOTPRINT (P28) — VALIDATED-FOR-M1 at the 2026-08-13 re-gate.
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
