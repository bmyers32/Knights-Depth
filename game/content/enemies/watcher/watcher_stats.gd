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

## Repertoire + actor-level locomotion (P29): see FangStats for the canonical
## explanation of every field below. Spacing/leash values migrated verbatim; no
## numerical change at P29.
##
## THE WATCHER IS THE FIRST MULTI-ACTION FAMILY, and the reason P29 exists. Two authored
## actions, selected by distance band:
##   watcher_pulse  [0.0, 2.0)  melee — the EXPLOIT teacher, unchanged from M1
##   watcher_survey [2.0, 9.0]  ranged — terminal band, new at P29
## Order here is meaningless; the bands decide. They tile with no overlap and no gap.
##
## WHY A SECOND ACTION DOES NOT DILUTE THIS FAMILY'S LESSON: Watcher teaches "raw
## pressure is expensive (threshold 24, deliberately above a full combo's hits 1+2);
## reading the windup is cheap." watcher_survey adds no second key to a second lock — it
## teaches the SAME lesson at a SECOND distance with a DIFFERENT tool, and its longer
## windup makes it the most readable action in the game.
##
## The engagement band below stays actor-level and UNCHANGED, deliberately: deriving
## movement from the selected action would make the Watcher hold at survey range and
## become a turret, letting the player stand at 3 units and never meet the melee action
## at all. Keeping it means the Watcher always wants to be on you — the survey is what it
## does on the way in and when you push it off ("you cannot disengage for free"). The
## steady state is still pulse: the approach terminates at distance <= 2.0, inside the
## pulse band. Do NOT couple selection to movement to make the survey fire more often;
## the levers are content only (band edges, spacing, windup/cadence, projectile speed).
@export var action_ids: Array[StringName] = [&"watcher_pulse", &"watcher_survey"]
@export var move_speed: float = 2.0
@export var preferred_attack_distance: float = 2.0
@export var minimum_attack_distance: float = 1.3
@export var detection_radius: float = 10.0
@export var leash_radius: float = 18.0
## ENGAGEMENT OPENER -- see FangStats.engagement_delay_ticks for the mechanism.
## **VALIDATED / BANKED PASS at the P29 re-playtest 2026-08-17.** Observed feel, verbatim:
## "The engagement delay made it feel like it noticed me before acting."
## HANDS OFF: this value is settled and is not part of any open P29 question. Do not
## retune it while chasing the survey's cadence or its selection feel -- those are
## separate findings with their own levers, and moving a banked number to chase an
## unrelated complaint is how a validated result gets quietly lost.
@export var engagement_delay_ticks: int = 10

## CLOSE-FRUSTRATION PATIENCE (P29 Watcher selection pass, 2026-08-17) -- how long this
## family keeps trying to CLOSE before an action authoring requires_close_frustration
## becomes selectable. Actor-level because it is a TEMPERAMENT, not a property of the bolt:
## it must never encode assumptions about projectile speed, size or windup, so that a
## future package pass is a pure content swap and never a selection re-tune.
##
## 90 (3.0 s) PROVISIONAL/UNVALIDATED. Chosen longer than the survey's own 34-tick windup
## so the sequence reads approach -> fail -> commit rather than blurring together; long
## enough that brief repositioning does not trigger it; short enough that sustained kiting
## is answered within a few seconds. **Candidate fallback: 60 (2.0 s)** if the replay finds
## 90 too passive. The replay decides; do not pre-emptively split the difference.
@export var close_frustration_ticks: int = 90


## APPROACH WEAVE (P17) — inert here. The four fields are ACTOR-level, so they exist on
## every family, but 0 degrees means the approach runs straight and this family's motion
## path is byte-identical to pre-P17. The canonical explanation lives in FangStats.
## P17 deliberately changes ONE family so the re-playtest can attribute any felt
## difference to the Fang alone (same discipline P29's iteration used for the Watcher).
@export var approach_weave_degrees: float = 0.0
@export var approach_weave_period_ticks: int = 0
@export var approach_weave_release_distance: float = 0.0
@export var approach_weave_phase_stride_ticks: int = 0
