class_name StratumConfig
extends Resource
## One stratum's identity and content pool (M2, GAME-RULES §5).
##
## TRIMMED at the floor-grammar pivot. The chamber/corridor/spawn-count parameters that drove
## the falsified room-chain generator were REMOVED rather than left dangling: config with no
## consumer is a knob that lies about what it controls. They return, in whatever shape the new
## grammar actually needs, when procedural assembly does (ROADMAP "M2 FLOOR GRAMMAR").
##
## The hazard set and per-depth family weighting named in §5 are still not here, for the same
## reason: no consumer yet.

@export var stratum_id: StringName = &"archive"

## The families this stratum may spawn. The authored prototype names its own roster inline, but
## this stays the stratum's declared pool so a content-lint test can assert an authored floor
## never summons a family the stratum does not own.
@export var enemy_keys: Array[StringName] = [&"fang", &"ooze", &"watcher"]
