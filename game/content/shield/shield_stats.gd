class_name ShieldStats
extends Resource
## Shield-class tunables (Prime Directive 3) — looked up via ContentDB, never literals
## in scripts. GAME-RULES §3: hold-to-block with its own break meter that regenerates,
## knockback on break. State machine (READY/HELD/BROKEN) lives in SimWorld
## (register_shield); this resource only carries the resolved numbers.

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate. These are the project's first meaningful
## combat-feel defaults (shield/i-frames, Phase D step 5) — UNVALIDATED PENDING THE
## STEP 8 PLAYTEST. Do not treat the seconds figures below as "this feels right";
## they exist only so the tick counts are legible against real time while reading data.
@export var meter_max: float = 20.0
## Regen rate. At the project's fixed 30 Hz sim tick (CLAUDE.md Stack): 0.4/tick =
## 12.0 meter/sec -> a full 0->20 regen takes 50 ticks ≈ 1.67s. Unvalidated feel.
@export var regen_per_tick: float = 0.4
## Ticks the meter stays locked at 0 after a break before regen resumes. At 30 Hz:
## 30 ticks = 1.0s. Unvalidated feel.
@export var break_recovery_delay_ticks: int = 30
@export var knockback_distance: float = 1.5
