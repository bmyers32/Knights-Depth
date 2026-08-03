class_name BurnStats
extends Resource
## Burn (M1's one status, GAME-RULES §3) tunables — looked up via ContentDB, never
## literals in scripts. tick_interval_ticks/duration_ticks are sim-tick counts at 30 Hz.

@export var status_id: StringName = &"burn"

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate. 6 pulses over the full duration
## (90 / 15 = 6) at 2.0 damage each = 12.0 total from an uninterrupted Burn — chosen
## against Envoy's 30.0 max_health (envoy_stats.tres) so a full Burn costs ~40% of the
## Envoy's health: painful but survivable by design, not a one-shot punish.
@export var damage_per_tick: float = 2.0
@export var tick_interval_ticks: int = 15
@export var duration_ticks: int = 90
