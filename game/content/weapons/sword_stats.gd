class_name SwordStats
extends Resource
## Sword-class weapon tunables (Prime Directive 3) — looked up via ContentDB, never
## literals in scripts. M1 default sword: Force-typed (GAME-RULES §3's "everybody's
## fallback" baseline), single discrete attack this session — combo/charge fields
## join this resource when Phase D sequences the locked 3-hit + hold-to-charge spec
## on top of this same pipeline.

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate.
@export var base_damage: float = 10.0
@export var damage_type: StringName = &"force"
@export var reach: float = 2.0
@export var cone_half_angle_degrees: float = 60.0
@export var knockback_distance: float = 1.0
