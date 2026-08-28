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

## Close-frustration patience -- ACTIVE since the P17 burrow selector (2026-08-28). Ticks the
## family must fail to reach its own close band ([0, 1.65], derived from fang_bite) before the
## burrow becomes selectable.
##
## The SHARED factual primitive with the Watcher, whose Survey uses the same observation; the
## selection POLICIES stay family-specific (rule-of-two ruling: consolidate the fact, not the
## framework). 90 matching WatcherStats is a coincidence of scale, not coupling -- the two may
## diverge freely.
##
## 90 ticks / 3.0 s is a FIRST SELECTOR HYPOTHESIS, not a validated value: under diagonal kiting
## this family nets only 0.17 u/s of closure, so three seconds of failing to reach 1.65 is an
## unambiguous "I cannot establish pressure" signal. Validated only by ordinary-play evidence.
@export var close_frustration_ticks: int = 90


## ---------------------------------------------------------------------------------
## BURROW (P17, frozen spec `199f9d3`) — Fang's ambush reposition. MODE CHANGE, not pursuit.
##
## Large backward jump -> disappear underground -> relocate -> emerge on the far side of the
## player -> a reacquisition beat -> fresh ordinary decision. It deals no damage and stores no
## attack target: burrow earns POSITION, it never guarantees a Bite.
##
## Evidence-informed rather than arbitrary. Three pursuit-geometry experiments were falsified
## (weave, scurry, cutoff); the one positive human datum P17 produced was "I kind of like the
## lunge", so this follows the shape that datum shares -- COMMIT -> strong authored movement or
## state change -> READABLE RESOLUTION -- instead of iterating on chase geometry again.
##
## STAGE 1 CRITERION (frozen before implementation): passes only if it changes what the player
## PAYS ATTENTION TO -- the disappearance/emergence must force meaningful target reacquisition
## and response, not preserve the same frontal engagement problem.
##
## VALUE STATUS (updated 2026-08-28, after BOTH human stages PASSED):
## Six of the seven are now VALIDATED-FOR-ACTION and FROZEN -- the jump distance and step, the
## underground duration, the emergence radius and retry window, and the reacquisition beat were
## all judged in live play across Stage 1 (does the action read as a predator?) and Stage 2 (is
## emerge-then-attack fair?). Verdicts: PASS and PASS.
##   Stage 1: "backward jump reads well... like it's disappearing into the bush", burrow DOES
##            change what the player pays attention to.
##   Stage 2: "can locate/turn/respond before the attack", emerge->attack feels fair, the
##            reacquisition pause is appropriately timed.
## DO NOT TUNE THESE without contrary playtest evidence. Two mechanics were already falsified
## by tuning the wrong layer; a validated action is not a place to go looking for improvement.
##
## THE ONE EXCEPTION is burrow_cooldown_ticks, which remains PROVISIONAL: it paces how OFTEN the
## action happens, and nothing has yet chosen when the action happens at all. It is validated
## only once a selector exists and is itself validated.
## ---------------------------------------------------------------------------------

## The conspicuous disengage. 4.0 units is more than a second of ordinary movement delivered in
## a fraction of one, so the jump reads as a decision rather than as backing away.
@export var burrow_jump_distance: float = 0.0

## Displacement per tick during the jump. 0.35 = 10.5 u/s, covering the 4.0 in ~12 ticks.
## ANY successful FLINCH (EXPLOIT or PRESSURE alike) aborts the jump, forfeits the remainder,
## and Fang never submerges from an aborted jump -- it is self-propelled, so it dies with its
## agency. This deliberately does NOT inherit the bump's continue-through-flinch rule, which
## applies to motion IMPOSED on an actor.
@export var burrow_jump_step_distance: float = 0.0

## Ticks spent absent before the first emergence attempt. 40 = 1.33 s: long enough to genuinely
## lose track of the Fang, short enough that the pre-registered failure mode "disappearing only
## to waste time" is not invited.
@export var burrow_underground_ticks: int = 0

## How far beyond the player the emergence point sits, on the far side from where Fang went
## under. 2.0 is just outside bite reach (1.65), so arriving still costs a step -- emergence
## grants position, never a free hit.
@export var burrow_emergence_radius: float = 0.0

## FAIL-SAFE WINDOW, not a tuning knob. From the underground deadline, all six fixed candidate
## points are re-checked EVERY authoritative tick for this long. Fang must never knowingly
## emerge overlapping a collidable actor, so if every candidate stays blocked the whole window,
## Fang dies underground with a loud warning rather than emerging illegally or staying absent
## forever -- an encounter soft-lock is strictly worse than a diagnosable death. 60 = 2.0 s,
## far longer than any transient blockage in an open arena.
@export var burrow_emergence_retry_ticks: int = 0

## The reacquisition beat: stationary and no attack may start, so the player can perceive
## "there it is" and then locate, turn, dodge, shield or apply control. 24 = 0.8 s, deliberately
## longer than the 12-tick bite windup so response is POSSIBLE rather than merely visible.
##
## Categorically unlike the scurry and cutoff settle beats, which had no demonstrated
## player-facing purpose and playtested as dead pauses. This one has an informational job.
@export var burrow_reacquisition_ticks: int = 0

## Production pacing only -- Stage 1 is dev-triggered and ignores it in practice. 240 = 8.0 s,
## because a mode change should be an event, not a rhythm.
@export var burrow_cooldown_ticks: int = 0
