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

## ---------------------------------------------------------------------------------
## REPERTOIRE + ACTOR-LEVEL LOCOMOTION (P29). The canonical explanation for all three
## families lives here; OozeStats/WatcherStats carry only their per-family deltas.
## ---------------------------------------------------------------------------------

## The authored actions this family may choose between (ContentDB &"natural_weapon" ids).
## ORDER IS SEMANTICALLY MEANINGLESS AND MUST STAY THAT WAY: selection is by distance
## band, bands may not overlap, and a content-lint test proves a shuffled repertoire
## produces an identical event stream. Nothing — not sim, not the registrar, not this
## resource — may treat element 0 as privileged. Fang ships ONE action, which makes its
## band terminal and its behaviour byte-identical to pre-P29 (tests/test_ai_backward_compat.gd).
@export var action_ids: Array[StringName] = [&"fang_bite"]

## ENGAGEMENT SPACING — migrated verbatim from NaturalWeaponStats at P29 (no numerical
## change; VALIDATED-FOR-M1 at the 2026-08-13 re-gate, and inside the NUMERIC-TUNING
## FENCE). These are ACTOR identity: the band this family tries to HOLD. Farther than
## preferred, it approaches; closer than minimum, it backs away; inside, it stops.
## They govern MOVEMENT ONLY — since the locked pre-gate defect fix they never gate
## whether an attack may start, and since P29 attack eligibility is the action band
## instead. Fixing the earlier defect where one attack_range threshold let an enemy walk
## on top of the player before attacking.
## P28 (2026-08-13): DERIVED FROM CONTACT DISTANCE, not chosen freely.
## minimum_attack_distance = this family's combat contact distance, and preferred is held
## at least 0.3 beyond it — otherwise an enemy settles INSIDE the player's body.
## preferred_attack_distance additionally resolves any action authoring max_range = -1,
## which is how a single-action family says "my band is exactly my engagement reach"
## without duplicating the number.
@export var move_speed: float = 3.0
@export var preferred_attack_distance: float = 1.65
@export var minimum_attack_distance: float = 1.35

## AI leash/detection — migrated verbatim at P29. Enemies start idle with NO initial
## aggro; detection_radius gates both first acquisition and re-acquisition (only while
## idle, never mid-return). leash_radius is measured from the enemy's spawn/re-anchor
## position, not its current position (a fixed home leash, not a drifting one).
## leash_radius 18.0 is sized against the 40x40 arena (arena.tscn), where a
## straight-line retreat from any plausible re-anchor point gives 30+ units of room.
@export var detection_radius: float = 10.0
@export var leash_radius: float = 18.0
## ENGAGEMENT OPENER (P29 iteration, 2026-08-14). Sim ticks to wait after a GENUINE
## inactive->active acquisition before this family may commit its first attack. Arms the
## existing shared readiness gate (SimWorld._next_fire_tick) rather than a parallel clock,
## so it composes with cooldown for free and suppresses only the ATTACK -- the enemy keeps
## approaching during it. Answers the playtest finding that first-engagement firing "reads
## mechanically range-triggered": before this, crossing a band edge started a windup on
## that very tick, because a fresh actor's readiness gate defaults to ready.
## Re-acquisition uses max(), so it can never shorten a cooldown already running.
## 0 = off, and Fang/Ooze deliberately stay at 0: this iteration changes ONE family, so
## the re-playtest can attribute any felt difference to the Watcher alone.
@export var engagement_delay_ticks: int = 0

## Close-frustration patience: see WatcherStats.close_frustration_ticks. 0 here because
## this family authors no action requiring it -- the field is actor-level, so it exists on
## every family, but it is inert without a consumer action.
@export var close_frustration_ticks: int = 0


## ---------------------------------------------------------------------------------
## SCURRY (P17, spec committed 2026-08-19) — Fang's situational MOBILITY COMMITMENT.
##
## Not locomotion and not an attack: a short, self-propelled, authoritative displacement
## the Fang CHOOSES when the player has been creating separation while it pursues. It deals
## no damage and has no arrival event — v1 is mobility only, deliberately (a damaging tackle
## is a different mechanic, and the spec records why that pressure was removed).
##
## THE DECISION IT CHANGES (BRAIN: "A different path is not a different decision"): the
## Envoy moves at 4.0 and this family at 3.0, a permanent 1.0 u/s deficit that makes
## retreating-while-shooting free and unanswerable. The scurry is the answer to exactly that,
## and its falsification criterion is pre-registered in ROADMAP P17: falsified if optimal
## player behavior is unchanged, regardless of how it looks.
##
## ALL SIX VALUES PROVISIONAL/UNVALIDATED, approved 2026-08-19, deliberately OUTSIDE the M1
## NUMERIC FENCE — a new mechanic, never a retune of fenced HP/flinch/output. 0 = off, which
## is what every other family authors.
## ---------------------------------------------------------------------------------

## TRIGGER, half one: how much ground must be lost against this pursuit's BEST approach
## before it reads as retreat rather than repositioning. At the 1.0 u/s deficit this is
## ~2.5s of sustained retreat -- a player commitment, not a sidestep.
@export var scurry_trigger_separation: float = 0.0

## TRIGGER, half two: ticks since that best approach was last improved on. Secondary guard
## (separation is normally the binding condition); it exists so instantaneous separation --
## knockback, or this family's own 0.30-unit backing-away -- cannot fire a commitment.
## BOTH conditions are required. Separation alone fires on a sidestep; elapsed alone is
## failed-closure, which is P29's territory and a different fact about the world.
@export var scurry_trigger_ticks: int = 0

## Displacement per sim tick while scurrying. 0.30 = 9.0 u/s, exactly 3x this family's
## ordinary pursuit and 2.25x the Envoy, so it reads as a different KIND of motion rather
## than as running slightly faster.
@export var scurry_step_distance: float = 0.0

## Number of displacement steps. Counted in STEPS, never compared against an end tick --
## inherited verbatim from the bump slide, where a record created during one tick's Commands
## first advances on the NEXT, making tick arithmetic off-by-one bait. A counter cannot drift.
## 15 steps x 0.30 = 4.5 units authored over 0.5s. Against a fleeing Envoy that is ~2.5 units
## of NET closure. THAT IS THE INTENDED SPACING OUTCOME UNDER THE REPRESENTATIVE TRIGGERED-
## RETREAT SCENARIO, NOT A GUARANTEE: a player who turns, strafes, or is already further out
## ends up somewhere else entirely, and the mechanic is not "broken" when they do.
@export var scurry_steps: int = 0

## The mandatory SETTLE beat after displacement ends: stationary, and no attack may start.
## This is the one piece of the falsified weave experiment that playtested PASS (its
## release/straighten hinge, Q3), carried forward as a REQUIREMENT rather than trim. It is
## also the commitment's price -- 18 ticks is deliberately longer than the 12-tick bite
## windup so the opening is genuinely usable.
@export var scurry_settle_ticks: int = 0

## Armed at END OF DISPLACEMENT in every path (completed, blocked by contact, or aborted by
## flinch), never at settle end -- that single choice is what lets both flinch regimes fall
## out without separate cooldown rules. 90 ticks = 3.0s, well past settle, so a second
## scurry is a decision point rather than a rhythm.
## NOT an episode: the trigger already self-clears, because a completed scurry writes a new
## closest-approach minimum which zeroes the separation term. This is a rate limit, and the
## distinction matters -- no episode-consumption concept exists anywhere in this mechanic.
@export var scurry_cooldown_ticks: int = 0
