class_name BurnStats
extends Resource
## Burn (M1's one status, GAME-RULES §3) tunables — looked up via ContentDB, never
## literals in scripts. tick_interval_ticks/duration_ticks are sim-tick counts at 30 Hz.

@export var status_id: StringName = &"burn"

## First-pass numbers, TESTED at the M1 playtest gate 2026-08-11 (build d1dbab0,
## seed 0): verdict ITERATE, M1 NOT closed. Combat reads fair and legible (no unseen
## damage), but the gate found no encounter decisions -- "any reasonable way to kill
## works" -- and no realistically available failure: "failure must be orchestrated by
## the player." No threshold below was individually judged, so treat each as UNREFUTED,
## never confirmed. Named tuning axis for the next pass: enemy OUTPUT (damage, attack
## cadence, aggression) -- durability tuning ALONE only lengthens fights without making
## failure available. A re-gate on a frozen post-batch build closes M1
## (GAME-RULES calibration-note law). 6 pulses over the full duration
## (90 / 15 = 6) at 2.0 damage each = 12.0 total from an uninterrupted Burn — chosen
## against Envoy's 30.0 max_health (envoy_stats.tres) so a full Burn costs ~40% of the
## Envoy's health: painful but survivable by design, not a one-shot punish.
@export var damage_per_tick: float = 2.0
@export var tick_interval_ticks: int = 15
@export var duration_ticks: int = 90
