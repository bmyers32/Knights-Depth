class_name NaturalWeaponStats
extends Resource
## Enemy natural-attack tunables (Prime Directive 3) — looked up via ContentDB, never
## literals in scripts. Registers through the SAME register_weapon/_apply_attack
## pipeline the Envoy's sword uses (GAME-RULES §3's combat pipeline is fixed) — an
## attacking enemy synthesizes the exact same "attack" Command shape a player would
## send (Phase D step 8 Phase 4).

## First-pass numbers, TESTED at the M1 playtest gate 2026-08-11 (build d1dbab0,
## seed 0): verdict ITERATE, M1 NOT closed. Combat reads fair and legible (no unseen
## damage), but the gate found no encounter decisions -- "any reasonable way to kill
## works" -- and no realistically available failure: "failure must be orchestrated by
## the player." No threshold below was individually judged, so treat each as UNREFUTED,
## never confirmed. Named tuning axis for the next pass: enemy OUTPUT (damage, attack
## cadence, aggression) -- durability tuning ALONE only lengthens fights without making
## failure available. A re-gate on a frozen post-batch build closes M1
## (GAME-RULES calibration-note law), alongside this session's other new AI
## numbers (detection/leash radii especially — see below).
@export var move_speed: float = 2.5
## Engagement spacing (locked defect fix, pre-gate pass): the band an engaged enemy
## tries to hold — farther than preferred_attack_distance, it approaches; closer than
## minimum_attack_distance, it backs away; inside the band, it stops and attacks
## (fixes the earlier defect where a single attack_range threshold let an enemy walk
## on top of the player before attacking). preferred_attack_distance doubles as the
## weapon's actual reach passed to register_weapon — keep it <= the attack's real
## hit range so a settled enemy can always land the attack it fires; content's job to
## keep those consistent, not sim's to enforce.
@export var preferred_attack_distance: float = 1.5
@export var minimum_attack_distance: float = 0.8
@export var cone_half_angle_degrees: float = 90.0
@export var windup_ticks: int = 20
## Reused as the shared per-actor cooldown gate (SimWorld._next_fire_tick) — the AI
## phase never starts a new windup until this elapses, so there is no separate
## AI-owned cooldown dict.
@export var fire_interval_ticks: int = 45
@export var damage: float = 5.0
## Locked to force (MECHANICS-REFERENCE.md §2's onboarding rule: ALL enemy damage is
## the baseline type in M1; typed enemy damage phases in at M2). Kept as an exported
## field, not a hardcoded literal in sim/, for when that ramp lands.
@export var damage_type: StringName = &"force"
@export var knockback_distance: float = 0.5

## AI leash/detection (Phase D step 8 Phase 4): enemies start idle with NO initial
## aggro — detection_radius gates both first acquisition and re-acquisition (only
## while idle, never mid-return). leash_radius is measured from the enemy's spawn
## position, not its current position (a fixed home leash, not a drifting one).
## Widened leash_radius 10.0 -> 18.0 (manual-pass calibration, 2026-08-04): the old
## 2.0-unit detection-to-leash gap forced running laps in the old 20x20 arena to ever
## exceed it; sized against the 40x40 arena (arena.tscn) where a straight-line
## retreat from any plausible re-anchor point gives 30+ units of room. Unvalidated
## first-pass numbers, revisit at the M1 playtest gate.
@export var detection_radius: float = 8.0
@export var leash_radius: float = 18.0

## Telegraph law (GAME-RULES §3): one flat color stands in for a real type->color
## palette table until a second reachable enemy damage type exists — M1's enemies are
## Force-only (onboarding rule above), so a whole mapping table has nothing else to
## map yet.
@export var telegraph_color: Color = Color(0.9, 0.4, 0.1)
