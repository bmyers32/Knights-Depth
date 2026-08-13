class_name BurnStats
extends Resource
## Burn (M1's one status, GAME-RULES §3) tunables — looked up via ContentDB, never
## literals in scripts. tick_interval_ticks/duration_ticks are sim-tick counts at 30 Hz.

@export var status_id: StringName = &"burn"

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law). 6 pulses over the full duration
## (90 / 15 = 6) at 2.0 damage each = 12.0 total from an uninterrupted Burn — chosen
## against Envoy's 30.0 max_health (envoy_stats.tres) so a full Burn costs ~40% of the
## Envoy's health: painful but survivable by design, not a one-shot punish.
@export var damage_per_tick: float = 2.0
@export var tick_interval_ticks: int = 15
@export var duration_ticks: int = 90
