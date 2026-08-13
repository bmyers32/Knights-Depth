class_name OozeStats
extends Resource
## Ooze (Drifted state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
## via ContentDB, never literals in scripts.

## First-pass numbers, TESTED at the M1 playtest gate 2026-08-11 (build d1dbab0,
## seed 0): verdict ITERATE, M1 NOT closed. Combat reads fair and legible (no unseen
## damage), but the gate found no encounter decisions -- "any reasonable way to kill
## works" -- and no realistically available failure: "failure must be orchestrated by
## the player." No threshold below was individually judged, so treat each as UNREFUTED,
## never confirmed. Named tuning axis for the next pass: enemy OUTPUT (damage, attack
## cadence, aggression) -- durability tuning ALONE only lengthens fights without making
## failure available. A re-gate on a frozen post-batch build closes M1
## (GAME-RULES calibration-note law).
## STEP-6 TUNING (batch, 2026-08-13) — PROVISIONAL/UNVALIDATED, answers the M1
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
## PROVISIONAL/UNVALIDATED, revisit at the re-gate.
@export var iframe_ticks_on_hit: int = 5
## COMBAT FOOTPRINT (P28 calibration, 2026-08-13) — PROVISIONAL/UNVALIDATED.
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
