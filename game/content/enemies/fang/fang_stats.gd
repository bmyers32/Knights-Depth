class_name FangStats
extends Resource
## Fang (Common state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
## via ContentDB, never literals in scripts.

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
## Fang: survives one full 26-damage combo with 19 margin, so the finisher's
## flinch is always observable; dies to the second. Threshold stays 16 = exactly
## hits 1+2 -- that IS the baseline pressure lesson, so it must not drift with HP.
@export var max_health: float = 45.0
@export var family: StringName = &"fang"
## FLINCH threshold (batch, PROVISIONAL/UNVALIDATED 2026-08-12): post-mitigation HP
## damage that must accumulate inside the shared pressure window before a
## pressure-capable hit can cash it out. 16.0 = the sword's hits 1+2 (8+8), so Fang
## teaches the BASELINE lesson: land the whole combo, the finisher pays off. Tuned
## jointly with max_health -- the two are ONE decision per enemy, never separately.
@export var flinch_threshold: float = 16.0
## CADENCE CONSTRAINT (locked as an invariant, value PROVISIONAL/UNVALIDATED):
## health-hit i-frames gate INDEPENDENT SEQUENTIAL hits, so this value doubles as a
## cap on any attacker's authored hit cadence. At 15 it silently absorbed sword_burn_A's
## own combo hits 2 and 3 (gaps of 6 and 7 ticks) -- a full 1->2->3 landed hit 1 only.
## Rule: iframe_ticks_on_hit < the smallest gap between consecutive authored hits.
## 5 keeps one tick of margin under that 6-tick minimum. Probed 2026-08-11 and played
## through both gates; VALIDATED-FOR-M1 at the 2026-08-13 re-gate.
## tests/test_combo_cadence_fixture.gd fails if a cadence retune ever violates the rule.
@export var iframe_ticks_on_hit: int = 5
## COMBAT FOOTPRINT (P28) — VALIDATED-FOR-M1 at the 2026-08-13 re-gate.
## The authoritative body radius: feeds BOTH Burn's contact-spread and the melee
## lunge clamp through the one shared _contact_distance (GAME-RULES §3), so it is
## never tuned for one of those in isolation. Derived from this model's CORE
## SILHOUETTE (radial p50 across its torso band), deliberately NOT its mesh AABB:
## Dino's 2.32 AABB is nose-to-tail LENGTH, not body width (core p50 = 0.79).
## Adopted after a live playtest confirmed believable body separation at authored
## contact with no toy-scale side effect. **REVALIDATION TRIGGER:** there is no
## sword model or attack animation yet, so weapon-reach/contact ALIGNMENT is
## explicitly NOT validated — re-check once real attack visuals exist, and do not
## retune this geometry to fix an animation problem unless authoritative contact
## itself proves wrong. Method + trigger recorded at ROADMAP P28.
@export var combat_radius: float = 0.9
