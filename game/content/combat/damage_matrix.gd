class_name DamageMatrix
extends Resource
## Family x damage-type matchup table (GAME-RULES §3) — single source of truth for
## every enemy family's weakness/resistance; MECHANICS-REFERENCE §1 is the design
## source. Ships complete (all 6 families) even though M1 only fields Fang/Ooze/
## Watcher — the matrix is locked, content catches up. Invariants (each non-Force
## type = weakness of exactly two families; every family resists exactly one
## non-Force type; Force is nobody's weakness/resistance) are content-lint-tested in
## tests/test_damage_matrix.gd.

## family(String) -> {"weak_to": String, "resists": String}. Force never appears as
## either value for any family — it's the universal, unresisted-but-unrewarding fallback.
@export var families: Dictionary = {
	"fang": {"weak_to": "pierce", "resists": "arc"},
	"dread": {"weak_to": "pierce", "resists": "umbral"},
	"tinker": {"weak_to": "umbral", "resists": "arc"},
	"ooze": {"weak_to": "umbral", "resists": "pierce"},
	"hollow": {"weak_to": "arc", "resists": "umbral"},
	"watcher": {"weak_to": "arc", "resists": "pierce"},
}

## First-pass numbers, TESTED at the M1 playtest gate 2026-08-11 (build d1dbab0,
## seed 0): verdict ITERATE, M1 NOT closed. Combat reads fair and legible (no unseen
## damage), but the gate found no encounter decisions -- "any reasonable way to kill
## works" -- and no realistically available failure: "failure must be orchestrated by
## the player." No threshold below was individually judged, so treat each as UNREFUTED,
## never confirmed. Named tuning axis for the next pass: enemy OUTPUT (damage, attack
## cadence, aggression) -- durability tuning ALONE only lengthens fights without making
## failure available. A re-gate on a frozen post-batch build closes M1
## (GAME-RULES calibration-note law).
@export var weak_multiplier: float = 1.5
@export var resist_multiplier: float = 0.5
