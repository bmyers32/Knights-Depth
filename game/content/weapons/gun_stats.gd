class_name GunStats
extends Resource
## Gun-class weapon tunables (Prime Directive 3) — looked up via ContentDB, never
## literals in scripts. Ranged: a deterministic projectile with travel time through
## the same combat pipeline melee uses (GAME-RULES §3), not a hitscan.

## weapon_class (not `class` — reserved word for inner classes in GDScript) is
## GAME-RULES §3's required tag on every weapon resource (sword/gun/bomb).
@export var weapon_class: StringName = &"gun"

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate. speed is continuous (units/second, mirrors
## movement); max_lifetime_ticks and fire_interval_ticks are sim-tick counts at 30 Hz
## (60 ticks = 2.0s, so an unfired shot travels up to 16 units before despawning).
## fire_interval_ticks=15 is a basic semi-automatic fire-rate gate (a flat cooldown
## between shots) — NOT the slice-B shared press/hold/release charge model GAME-RULES
## §3 locks; that lands as its own weapon-agnostic mechanism later, gun included.
## knockback_distance=0.0 (manual playtest finding, 2026-08-02): at this weapon's own
## ~16-unit range, repeat-fire knockback displaced a stationary target off the gun's
## aim line before the next shot arrived, not out of reach — a sword's single discrete
## swing can afford knockback, a gun's repeat-fire cadence along one line cannot.
@export var base_damage: float = 6.0
@export var damage_type: StringName = &"force"
@export var speed: float = 8.0
@export var max_lifetime_ticks: int = 60
@export var hit_radius: float = 0.4
@export var knockback_distance: float = 0.0
@export var fire_interval_ticks: int = 15
## Optional status payload (GAME-RULES §3) — see SwordStats.status_id. No M1 gun
## variant sets this; kept symmetric with SwordStats so both weapon classes carry the
## same content shape for future weapons.
@export var status_id: StringName = &""
## Normal-hit proc chance for status_id (GAME-RULES §1.3 combat RNG) — see
## SwordStats.status_proc_chance. All M1 gun variants stay 0.0 (guns never proc).
@export var status_proc_chance: float = 0.0
