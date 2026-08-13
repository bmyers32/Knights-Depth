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

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law).
@export var weak_multiplier: float = 1.5
@export var resist_multiplier: float = 0.5
