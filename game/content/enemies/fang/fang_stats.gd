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
## APPROACH WEAVE (P17, 2026-08-18) — Fang's BASELINE MOTION PATH.
##
## GAME-RULES §3 channel law (P17 amendment): FAMILIES own baseline motion PATH (the
## spatial channel); entity STATES own motion RHYTHM/COORDINATION (the temporal channel).
## Orthogonal but composable. A zig-zag approach is therefore family identity, and it does
## NOT make a Common Fang read as Drifted -- provided it never impersonates the temporal
## channel (see the stride field below, which is what keeps that promise).
##
## Taxonomy this expresses (ROADMAP P17): Fang = aggressive, NONLINEAR, committing.
## Scope: the APPROACH branch only. Retreat, in-band hold, windup-freeze and flinch are
## untouched -- a weaving retreat would read as fleeing indecision, not aggression.
##
## ALL FOUR VALUES ARE PROVISIONAL/UNVALIDATED (first playtest: P17 packet Q1-Q7). They
## are deliberately OUTSIDE the M1 NUMERIC FENCE -- this is a new mechanic, not a retune
## of fenced HP/flinch/output. A felt difficulty change here is evidence about the weave
## and is never permission to move Fang's fenced durability numbers.
## ---------------------------------------------------------------------------------

## Half-amplitude of the zig-zag, in degrees off the straight-to-player heading. The path
## alternates +/- this angle, so the full sweep is twice this. 0 = weave OFF entirely,
## which is the default for every other family and the reason this ships as a no-op
## everywhere it is not authored.
## KNOWN COST, not a defect: closing speed scales by cos(degrees). At 35 deg that is ~18%
## slower detection-to-band (~2.8s -> ~3.4s at move_speed 3.0). That interaction with the
## banked engagement_delay_ticks is P17 packet Q6.
@export var approach_weave_degrees: float = 0.0

## Full zig-zag period in sim ticks (GAME-RULES §3: durations in ticks, never seconds).
## The heading flips sign every HALF period. Must be >= 2 for a half-period to exist;
## sim treats anything smaller as OFF and warns.
## At 30 ticks (1.0s) and move_speed 3.0 the lateral excursion is ~0.86 units per
## half-beat -- just under Fang's 0.9 combat_radius, i.e. a body-width swing that reads as
## intent. Probed at 20 ticks it computes to ~0.57 and is expected to read as jitter.
@export var approach_weave_period_ticks: int = 0

## The RELEASE HINGE: inside this distance the approach straightens and runs at the player
## directly. This is what makes the authored beat "zig-zag rush -> straighten -> arrive ->
## windup" instead of a wobble that is still swinging while the actor tries to settle at
## preferred_attack_distance (1.65). Author it comfortably outside the engagement band.
## 0 = no hinge (weave right up to the band); kept expressible, deliberately not used.
@export var approach_weave_release_distance: float = 0.0

## PER-ACTOR PHASE STRIDE — ticks of phase offset applied per actor_id, so N Fangs on
## screen do not zig and zag in unison.
##
## THIS FIELD IS THE GAME-RULES §3 BINDING CONSEQUENCE, in data. The amendment requires
## that any family-owned path shape phased off a GLOBAL clock carry a deterministic
## per-actor offset -- without it, several Common Fangs render synchronized and read as
## CLAIMED, which is family identity stealing the state channel by accident. Verified by
## P17 packet Q7 and by tests/test_approach_weave.gd's de-correlation test.
##
## Deterministic (a pure function of actor_id), NOT random: no RNG stream is opened here.
## Idle wander is where genuine randomness arrives, with its own seeded stream (ROADMAP
## P18, GAME-RULES §1.3) -- this must not pre-empt that decision.
## 7 against a 30-tick period spreads consecutive actor_ids to phases 7/14/21/28/5/12...
## -- no small group lands in unison. 0 = no offset (single-actor scenes only).
@export var approach_weave_phase_stride_ticks: int = 0
