class_name EnvoyStats
extends Resource
## Envoy tunables (Prime Directive 3) — looked up via ContentDB, never literals in scripts.

@export var move_speed: float = 4.0

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law). This session is the first time the Envoy is
## a registered combatant (SimWorld.register_combatant), so it can take real damage —
## from Burn's contact-spread/DoT specifically (GAME-RULES §3's enemy<->player
## allegiance rule). No enemy attack exists yet, so this health is only reachable
## through Burn this session. 30.0 max_health against Burn's full-duration ~12.0 DoT
## total (burn_stats.tres) is ~40% of health: painful but survivable by design.
@export var max_health: float = 30.0
## Absent from the damage matrix (game/content/combat/damage_matrix.tres) — any typed
## hit against the Envoy resolves at the neutral 1.0 multiplier. Registered anyway
## (mirrors FangStats/OozeStats/WatcherStats' own family field) for consistency, not
## because a matrix row is needed yet.
@export var family: StringName = &"envoy"
## COMBAT FOOTPRINT (P28) — VALIDATED-FOR-M1 at the 2026-08-13 re-gate.
## The authoritative body radius: feeds BOTH Burn's contact-spread and the melee
## lunge clamp through the one shared _contact_distance (GAME-RULES §3), so it is
## never tuned for one of those in isolation. Derived from this model's CORE
## SILHOUETTE (radial p50 across its torso band), deliberately NOT its mesh AABB:
## the Knight model's 0.97 AABB is mostly an outstretched weapon, not body.
## Adopted after a live playtest confirmed believable body separation at authored
## contact with no toy-scale side effect. **REVALIDATION TRIGGER:** there is no
## sword model or attack animation yet, so weapon-reach/contact ALIGNMENT is
## explicitly NOT validated — re-check once real attack visuals exist, and do not
## retune this geometry to fix an animation problem unless authoritative contact
## itself proves wrong. Method + trigger recorded at ROADMAP P28.
@export var combat_radius: float = 0.45
## POST-HIT INVULNERABILITY (P44, ruled 2026-10-18) -- the SAME shared health-hit window enemies
## carry (FangStats.iframe_ticks_on_hit), deliberately GLOBAL: any unblocked, non-lethal HP hit --
## an enemy blow, a projectile or a spike pad -- starts it, and every ordinary hit from any source
## inside it is absorbed. Absorbed and blocked hits never restart it. No per-pad timer, no
## source-specific immunity (a 15 + 90 hazard-only split was proposed and REJECTED the same day).
## It was a literal 0 in the driver until then, so a spike pad dealt 10 on every active tick.
## 90 ticks = 3 s at 30 Hz: an intentional global survivability change. It is LONGER than every
## shipped enemy action's fire_interval_ticks (fang_bite 24 .. ooze_slam 55), so one enemy's own
## follow-up blows inside the window are absorbed too -- the opposite of the enemy-side cadence
## rule in FangStats, and accepted as such.
## CALIBRATION: HUMAN-ACCEPTED 2026-10-18 as the current baseline, not a permanent balance lock.
## Observed: a Floor 2 pad hit left time to step off before another hit; standing still and
## letting a Floor 2 crowd attack, the Envoy died after five damaging hits over ~16 s, with blows
## absorbed during the window -- "acceptable for the current development stage". Retune only on
## new gameplay evidence; no compensating enemy damage/cadence/hazard-timing changes (ROADMAP P44).
@export var iframe_ticks_on_hit: int = 90

## EMERGENCY RESYNCHRONIZATION (M2 Slice 2, ruled 2026-10-20). The first incapacitation on a floor
## is not the end: after `resync_delay_ticks` the Envoy returns IN PLACE at `resync_health_fraction`
## of max health, with the shared post-hit window above (no separate revival immunity). A second
## incapacitation on the same floor, with no charge left, is Emergency Recall. A new floor is a
## fresh allowance; unused ones never carry.
## FULL HEALTH IS A HUMAN DECISION (2026-10-20), not a provisional number: do not lower it without
## playtest evidence. It is deliberately NOT the future assisted co-op revival's 50% -- those are
## two different recoveries with different outcomes (ROADMAP).
## CALIBRATION: delay 45 ticks (1.5 s) PROVISIONAL, unplaytested. Record feel + date at the playtest.
@export var resyncs_per_floor: int = 1
@export var resync_health_fraction: float = 1.0
@export var resync_delay_ticks: int = 45

## CARRYING (Floor 4 Stage 2, 2026-10-16). A loose key is lifted by the primary attack press when
## it is within `pickup_reach`, inside the aim cone of `pickup_cone_half_angle_degrees`, and not
## under the Envoy's feet (`pickup_underfoot_radius`) -- SimWorld._resolve_interaction_target.
## The cursor need not touch the key. Starting values borrow the sword's own swing (reach 2.0,
## 60-degree half-angle, sword_burn_A.tres): "if you could hit it from here, you can pick it up".
## The underfoot radius is the Envoy's body radius: a key that close has no direction.
## CALIBRATION: the first values (reach 1.6, cursor within 0.8 of the key) were played 2026-10-16
## and read as "overly precise cursor-on-key targeting"; these replace them, UNPLAYTESTED. Record
## the observed feel and date here at the next mechanic playtest.
@export var pickup_reach: float = 2.0
@export var pickup_cone_half_angle_degrees: float = 60.0
@export var pickup_underfoot_radius: float = 0.45
