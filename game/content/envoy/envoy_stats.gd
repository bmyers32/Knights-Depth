class_name EnvoyStats
extends Resource
## Envoy tunables (Prime Directive 3) — looked up via ContentDB, never literals in scripts.

@export var move_speed: float = 4.0

## First-pass numbers, TESTED at the M1 playtest gate 2026-08-11 (build d1dbab0,
## seed 0): verdict ITERATE, M1 NOT closed. Combat reads fair and legible (no unseen
## damage), but the gate found no encounter decisions -- "any reasonable way to kill
## works" -- and no realistically available failure: "failure must be orchestrated by
## the player." No threshold below was individually judged, so treat each as UNREFUTED,
## never confirmed. Named tuning axis for the next pass: enemy OUTPUT (damage, attack
## cadence, aggression) -- durability tuning ALONE only lengthens fights without making
## failure available. A re-gate on a frozen post-batch build closes M1
## (GAME-RULES calibration-note law). This session is the first time the Envoy is
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
