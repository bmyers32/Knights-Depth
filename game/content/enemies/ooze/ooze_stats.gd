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


## APPROACH WEAVE (P17) — inert here. The four fields are ACTOR-level, so they exist on
## every family, but 0 degrees means the approach runs straight and this family's motion
## path is byte-identical to pre-P17. The canonical explanation lives in FangStats.
## P17 deliberately changes ONE family so the re-playtest can attribute any felt
## difference to the Fang alone (same discipline P29's iteration used for the Watcher).
@export var approach_weave_degrees: float = 0.0
@export var approach_weave_period_ticks: int = 0
@export var approach_weave_release_distance: float = 0.0
@export var approach_weave_phase_stride_ticks: int = 0
