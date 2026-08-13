class_name MeleeAttackProfile
extends Resource
## One combo step's or one charge attack's resolved content (Prime Directive 3) —
## GAME-RULES §3 Slice B spec: combo moves to PER-HIT profiles, a charge selects its
## OWN profile (never a hardcoded bigger normal hit). SwordStats holds an Array[3] of
## these for combo_profiles plus one for charge_profile; a weapon with an empty
## combo_profiles array never registers via SimWorld.register_melee_profiles and stays
## on the older flat single-profile path (sword_A).

@export var damage: float = 10.0
@export var damage_type: StringName = &"force"
@export var reach: float = 2.0
@export var cone_half_angle_degrees: float = 60.0
@export var knockback_distance: float = 1.0
## Sim-tick cooldown before the next attack Command's "pressed" phase is accepted
## (reuses the existing per-actor _next_fire_tick gate — see SwordStats.status_id).
@export var fire_interval_ticks: int = 0
@export var status_id: StringName = &""
@export var status_proc_chance: float = 0.0
## Interruption as graded content (manual-pass, 2026-08-04): a hit with
## interrupt_strength > 0 cancels a target enemy's in-progress attack windup
## (SimWorld._cancel_enemy_windup) and knocks it back normally; a hit with 0 hits a
## winding-up enemy for damage/status as normal but its knockback is suppressed
## (crowding a stunned-looking enemy shouldn't shove it out of its own windup for
## free). Currently just a boolean gate (>0); the field is an int, not a bool, so it
## can graduate to comparison against a per-enemy poise/interruption threshold later
## without a shape change -- no enemy-side threshold value exists yet.
@export var interrupt_strength: int = 0

## Forward lunge (manual-pass, 2026-08-05): deterministic authored sim movement,
## distributed evenly across lunge_duration_ticks -- never instantaneous
## displacement, never physics momentum. All default to 0 (no lunge, no delay,
## same-tick resolution) so every weapon that doesn't author these stays on today's
## exact behavior. hit_active_ticks is the offset from the swing's own execution
## start to when the hit resolves; authoring convention is hit_active_ticks <=
## lunge_duration_ticks (SimWorld.register_melee_profiles clamps and warns on a
## violation -- a hit past the swing's own end would otherwise silently never
## resolve). Recovery (the tail after the hit, before the swing fully ends) is
## deliberately NOT its own field -- it's derived (lunge_duration_ticks -
## hit_active_ticks). If a future mechanic needs recovery-specific behavior (a
## distinct cancel window, faster shield engage than windup, its own animation
## cadence), promote it to an explicit field then -- don't extrapolate one now.
@export var lunge_distance: float = 0.0
@export var lunge_duration_ticks: int = 0
@export var hit_active_ticks: int = 0
## Charge-only: ticks between a charged release and the strike actually firing.
## Combo-step profiles carry this field too (same Resource class) but sim code only
## ever reads it off the resolved CHARGE profile -- meaningless on a combo step.
## Direction locks at release and never re-tracks during the windup; the strike's
## origin (for its own reach/cone sweep) is the actor's position at the moment it
## fires, resampled then, not frozen at release ("direction locked, origin moves").
@export var windup_ticks: int = 0

## FLINCH (batch, GAME-RULES §3 reaction layer) — two INDEPENDENT authored dimensions.
## Never derive one from the other, and never from damage/knockback/status.
##
## flinch_capability: what this hit can TRIGGER.
##   &"none"     — never triggers a flinch (may still build pressure).
##   &"exploit"  — flinches only when it lands during an enemy action authored
##                 VULNERABLE; never cashes stored pressure.
##   &"pressure" — cashes stored pressure at/above the target's threshold, AND
##                 exploits a VULNERABLE window like &"exploit".
## Locked M1 sword mapping, VALIDATED at the 2026-08-13 re-gate: hits 1-2 = exploit,
## hit 3 = pressure, charge = pressure (a deliberate SECOND cash-out route -- the
## player reported getting "hits and charge off" under real threat, so charge is a
## live option rather than a trap or a dominant answer). Threshold readiness is NOT cash-out: an exploit hit that
## pushes pressure past the threshold banks it for the next pressure-capable hit
## rather than flinching. That is intended behavior, not a tuning gap.
@export var flinch_capability: StringName = &"none"
## contributes_pressure: whether this hit's post-mitigation HP damage is RECORDED
## toward the target's pressure. Independent of capability above — a hit may
## contribute while being incapable of ever cashing out. Baseline M1 direct weapon
## hits default true; blocked/absorbed damage and all status/DoT damage never
## contribute (enforced in sim, not here).
@export var contributes_pressure: bool = true
