class_name OozeStats
extends Resource
## Ooze (Drifted state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
## via ContentDB, never literals in scripts.

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate.
@export var max_health: float = 20.0
@export var family: StringName = &"ooze"
## Cadence constraint + derivation: see FangStats.iframe_ticks_on_hit. Same value for
## the same reason (this is a combat-wide invariant, not a per-family identity yet);
## PROVISIONAL/UNVALIDATED, revisit at the M1 playtest gate.
@export var iframe_ticks_on_hit: int = 5
## Burn contact-spread proximity radius (GAME-RULES §3) — eyeballed against the
## GreenSpikyBlob model, same provisional-until-arena-lighting status as the collision
## capsule in ooze.tscn.
@export var combat_radius: float = 0.7
