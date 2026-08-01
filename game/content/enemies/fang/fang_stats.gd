class_name FangStats
extends Resource
## Fang (Common state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
## via ContentDB, never literals in scripts.

## Provisional first-pass number, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate.
@export var max_health: float = 20.0
@export var family: StringName = &"fang"
