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
## CUTOFF (P17, pre-code spec `d070b63`) — Fang's route-contesting mobility commitment.
##
## NOT "close the gap". The scurry experiment closed a measured 2.50 units and was falsified
## because the player's optimal ESCAPE DIRECTION never changed (BRAIN: "Closing distance is
## not the same as contesting movement"). This action instead threatens the space AHEAD of
## the player's committed route: a lateral clearance leg, then a committed run to a lead
## point, then a plant. It deals no damage and has no arrival event.
##
## Reads the sim-owned two-bucket recent-locomotion fact of the OBSERVED actor. That fact is
## deliberately not Fang's: Fang's own attack/flinch/leash lifecycle must never erase where
## the player has been going (the structural correction over scurry v1, whose observer-owned
## record cleared on the Fang's own events).
##
## PRE-REGISTERED FALSIFICATION CRITERION, unchanged from the spec: falsified unless the
## player VOLUNTARILY CHANGES ROUTE in response to anticipated cutoff pressure. Detecting
## routes, reaching lead points and looking dynamic are all insufficient.
##
## ALL SEVEN VALUES PROVISIONAL/UNVALIDATED, outside the M1 NUMERIC FENCE. 0 = off, which is
## what every other family authors.
## ---------------------------------------------------------------------------------

## TRUST THRESHOLD: how much coherent recent travel Fang requires before believing the
## observed route direction. 1.2 units is ~0.3 s of travel at Envoy speed 4.0.
##
## TRUST, NOT HORIZON. RouteTuning.route_window_ticks governs how much recent history shapes
## the DIRECTION; this governs how much of it Fang needs before acting on it. Different jobs,
## different reasons to move — future tuning must not conflate them.
##
## KNOWN BOUNDARY, recorded not mitigated: `recent_route` covers 2N ticks just before a bucket
## rollover and N just after, so its magnitude halves at each rollover (4.0 -> 2.0 units at
## full speed, both clear of 1.2). Sustained travel below ~60% of full speed sits near this
## floor and can flicker across a rollover. If play reports "sometimes it just doesn't react",
## this is the first suspect -- diagnose from the logged magnitude, do NOT add hysteresis or
## move this number before a human verdict.
@export var cutoff_min_route_distance: float = 0.0

## How far ahead of the player the committed destination sits. An AUTHORED CONSTANT, never a
## solved intercept: it overshoots when Fang is close and undershoots when far. That is the
## accepted cost of the no-intercept-equations fence, stated rather than discovered later.
## 2.5 ~ the distance the player covers while Fang crosses a typical 4-unit engagement.
@export var cutoff_lead_distance: float = 0.0

## SEGMENT 1 length. Its purpose is CLEARANCE, not decoration: from directly behind a fleeing
## player, a straight path to the lead point runs through the player's contact corridor and
## terminates on their back. This leg establishes a usable outside line first. Readability is
## a welcome consequence, but clearance sets the number -- contact is 0.4 + 0.9 = 1.3, so 2.0
## clears it with margin.
@export var cutoff_lateral_distance: float = 0.0

## Displacement per sim tick while cutting off. 0.30 = 9.0 u/s, 3x ordinary pursuit and 2.25x
## the Envoy, so it reads as a different KIND of motion rather than as running faster.
@export var cutoff_step_distance: float = 0.0

## TOTAL step budget across both segments, bounding the commitment. Segment 2's length is
## geometry-dependent (it depends where the lead point falls), so without a cap a distant
## commitment could run arbitrarily long. 30 steps = 1.0 s.
@export var cutoff_max_steps: int = 0

## The plant: stationary, no attack may start, ending the commitment readably before the next
## ordinary decision. 12 ticks = 0.4 s, matching the bite windup -- a tell length the player
## already reads. Deliberately shorter than the 18-tick settle that playtested as
## "didn't really get to feel it".
##
## The plant adds NO stationary-facing writer (option B). Facing is written by cutoff
## displacement along its own motion, so a Fang that is beaten to the punch plants facing the
## abandoned committed destination -- which communicates that the mobility was committed.
@export var cutoff_plant_ticks: int = 0

## Armed at END OF DISPLACEMENT in every path -- completed, blocked, or flinch-aborted -- so
## an abort cannot be farmed into an immediate retry. 120 ticks = 4.0 s.
@export var cutoff_cooldown_ticks: int = 0
