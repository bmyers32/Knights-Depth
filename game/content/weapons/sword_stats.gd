class_name SwordStats
extends Resource
## Sword-class weapon tunables (Prime Directive 3) — looked up via ContentDB, never
## literals in scripts. M1 default sword: Force-typed (GAME-RULES §3's "everybody's
## fallback" baseline), single discrete attack this session — combo/charge fields
## join this resource when Phase D sequences the locked 3-hit + hold-to-charge spec
## on top of this same pipeline.

## weapon_class (not `class` — reserved word for inner classes in GDScript) is
## GAME-RULES §3's required tag on every weapon resource (sword/gun/bomb).
@export var weapon_class: StringName = &"sword"

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate.
@export var base_damage: float = 10.0
@export var damage_type: StringName = &"force"
@export var reach: float = 2.0
@export var cone_half_angle_degrees: float = 60.0
@export var knockback_distance: float = 1.0
## Optional status payload (GAME-RULES §3) — empty means this weapon never applies a
## status. sword_A stays empty; sword_burn_A (dev-only Burn carrier, HANDOFF) is the
## only M1 weapon that sets this, so the baseline sword's proven behavior is untouched.
@export var status_id: StringName = &""
## Normal-hit proc chance for status_id (GAME-RULES §1.3 combat RNG) — default 0.0
## (sword_A never rolls). sword_burn_A's 0.3 is provisional/unvalidated, flagged for
## the step 8 playtest gate. HANDOFF carry-forward: future charged attacks (locked
## combo/charge follow-up, not built this session) may define a separate proc chance
## of their own — sword_burn_A is meant to apply Burn at 100% on a charged hit; do
## not overload THIS field with charge semantics when that step lands.
@export var status_proc_chance: float = 0.0
