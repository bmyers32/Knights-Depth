class_name EnvoyStats
extends Resource
## Envoy tunables (Prime Directive 3) — looked up via ContentDB, never literals in scripts.

@export var move_speed: float = 4.0

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate. This session is the first time the Envoy is
## a registered combatant (SimWorld.register_combatant), so it can take real damage —
## from Burn's contact-spread/DoT specifically (GAME-RULES §3's enemy<->player
## allegiance rule). No enemy attack exists yet, so this health is only reachable
## through Burn this session. 30.0 max_health against Burn's full-duration ~12.0 DoT
## total (burn_stats.tres) is ~40% of health: painful but survivable by design.
@export var max_health: float = 30.0
## Absent from the damage matrix (game/content/combat/damage_matrix.tres) — any typed
## hit against the Envoy resolves at the neutral 1.0 multiplier. Registered anyway
## (mirrors FangStats/OozeStats/WatcherStats' own family field) for consistency, not
## because a matrix row is needed yet.
@export var family: StringName = &"envoy"
## Burn contact-spread proximity radius (GAME-RULES §3) — first-pass, smaller than the
## enemies' so the Envoy must walk in close rather than start already overlapping Fang
## at envoy_movement_dev.tscn's default spawn distance (1.5 units).
@export var combat_radius: float = 0.4
