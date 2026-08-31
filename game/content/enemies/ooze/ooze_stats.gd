class_name OozeStats
extends Resource
## Ooze (Drifted state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
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
## Ooze: ~3 full combos, so three flinch cycles are experienceable -- what the
## repeated-manipulation lesson needs. Threshold stays lowest (12) so cycles are
## cheap to re-earn. Durability is only half its identity; see its slam damage.
@export var max_health: float = 70.0
@export var family: StringName = &"ooze"
## FLINCH threshold (batch, PROVISIONAL/UNVALIDATED 2026-08-12): Ooze teaches
## SUSCEPTIBILITY VARIATION -- deliberately lower than Fang's 16.0, so it flinches
## earlier and can be manipulated repeatedly by a player who notices. Tuned jointly
## with max_health; the two are ONE decision per enemy.
@export var flinch_threshold: float = 12.0
## Cadence constraint + derivation: see FangStats.iframe_ticks_on_hit. Same value for
## the same reason (this is a combat-wide invariant, not a per-family identity yet);
## VALIDATED-FOR-M1 at the 2026-08-13 re-gate.
@export var iframe_ticks_on_hit: int = 5
## COMBAT FOOTPRINT (P28) — VALIDATED-FOR-M1 at the 2026-08-13 re-gate.
## The authoritative body radius: feeds BOTH Burn's contact-spread and the melee
## lunge clamp through the one shared _contact_distance (GAME-RULES §3), so it is
## never tuned for one of those in isolation. Derived from this model's CORE
## SILHOUETTE (radial p50 across its torso band), deliberately NOT its mesh AABB:
## the blob's spikes inflate its 2.30 AABB, but its BODY is genuinely fat (core p50
## = 1.45). This value was THE P28 defect: authored at 0.70, roughly half the real
## body, which is why the Envoy rendered fully inside the Ooze at melee contact.
## Adopted after a live playtest confirmed believable body separation at authored
## contact with no toy-scale side effect. **REVALIDATION TRIGGER:** there is no
## sword model or attack animation yet, so weapon-reach/contact ALIGNMENT is
## explicitly NOT validated — re-check once real attack visuals exist, and do not
## retune this geometry to fix an animation problem unless authoritative contact
## itself proves wrong. Method + trigger recorded at ROADMAP P28.
@export var combat_radius: float = 1.45

## Repertoire + actor-level locomotion (P29): see FangStats for the canonical
## explanation of every field below — the band/actor split, the order-is-meaningless
## rule, the P28 contact-distance derivation, and the leash/detection anchoring.
## Ooze ships ONE action, so its band is terminal and its behaviour is byte-identical
## to pre-P29. Per-family deltas only: it is the SLOW, FAT bruiser — the lowest
## move_speed in the roster, and the widest spacing, because minimum_attack_distance
## tracks its 1.45 combat_radius (P28's real correction: preferred moved 1.8 -> 2.2,
## since a bigger body legitimately gets a longer slam and preferred doubles as reach).
## All values migrated verbatim; no numerical change at P29.
@export var action_ids: Array[StringName] = [&"ooze_slam"]
@export var move_speed: float = 1.5
@export var preferred_attack_distance: float = 2.2
@export var minimum_attack_distance: float = 1.9
@export var detection_radius: float = 10.0
@export var leash_radius: float = 18.0
## Engagement opener: see FangStats.engagement_delay_ticks. Ooze stays at 0 (P29
## iteration changes the Watcher only).
@export var engagement_delay_ticks: int = 0

## Close-frustration patience: see WatcherStats.close_frustration_ticks. 0 here because
## this family authors no action requiring it -- the field is actor-level, so it exists on
## every family, but it is inert without a consumer action.
@export var close_frustration_ticks: int = 0


## BURROW (P17) — inert here. The seven fields are ACTOR-level, so they exist on every family,
## but 0 leaves this family byte-identical to pre-burrow. Canonical explanation in FangStats.
## P17 changes ONE family so a verdict can be attributed to the Fang alone.
## P33 BOUNDED LOCAL AVOIDANCE — how long a chosen local route is committed to, in sim ticks.
## ABSENCE IS OFF: 0 means this family never routes around an obstruction and pursues in
## straight lines, exactly as before P33 existed.
##
## PROVISIONAL/UNVALIDATED, outside the M1 numeric fence: 45 ticks is 1.5 s at 30 Hz, long
## enough to clear the authored neck (a 4.35 u sidestep at 1.5 u/s takes ~2.9 s of travel, but
## the commitment only has to survive until the direct line clears, which happens well before
## the waypoint is reached). The deadline exists to BOUND the behaviour, not to pace it.
@export var avoid_commit_ticks: int = 45

## THE OOZE'S MOVEMENT LANGUAGE (ruled 2026-08-31 after play: "Can it not just go south, south,
## south until lined up, then west, west, west?"). CARDINAL_COMMITTED walks one axis at a time
## and switches when aligned or blocked, which reads as deliberate rather than as continuous
## diagonal correction.
##
## AUTHORED PER FAMILY, not branched by name in code: GAME-RULES §3 channel law gives FAMILIES
## the baseline motion path, so a steering grammar belongs in content. Fang and Watcher keep
## &"direct" -- their lunge, burrow and approach weave are validated identities that cardinal
## legs would destroy.
@export var pursuit_language: StringName = &"cardinal_committed"

@export var burrow_jump_distance: float = 0.0
@export var burrow_jump_step_distance: float = 0.0
@export var burrow_underground_ticks: int = 0
@export var burrow_emergence_radius: float = 0.0
@export var burrow_emergence_retry_ticks: int = 0
@export var burrow_reacquisition_ticks: int = 0
@export var burrow_cooldown_ticks: int = 0
