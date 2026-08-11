class_name WatcherStats
extends Resource
## Watcher (Claimed state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
## via ContentDB, never literals in scripts. True name: Custodian (Archive-recoverable,
## LEXICON.md) — not used in code identifiers, folk name only per the true-names law.

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate.
@export var max_health: float = 20.0
@export var family: StringName = &"watcher"
## Cadence constraint + derivation: see FangStats.iframe_ticks_on_hit. Same value for
## the same reason (this is a combat-wide invariant, not a per-family identity yet);
## PROVISIONAL/UNVALIDATED, revisit at the M1 playtest gate.
@export var iframe_ticks_on_hit: int = 5
## Burn contact-spread proximity radius (GAME-RULES §3) — eyeballed against the
## Goleling model, same provisional-until-arena-lighting status as the collision
## capsule in watcher.tscn.
@export var combat_radius: float = 0.8
