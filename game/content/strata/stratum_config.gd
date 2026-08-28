class_name StratumConfig
extends Resource
## One stratum's generation parameters (M2, GAME-RULES §5: "stratum theme drives segment
## pool + hazard/status set + enemy-family weights — all from config").
##
## Prime Directive 3: every number a floor's shape depends on lives here, never as a
## literal in game/gen/. Retuning a stratum is a .tres edit.
##
## SLICE 1 SCOPE: one stratum (Archive), one rectangular chamber per floor. The hazard set,
## segment pool, and per-depth family weighting named in §5 are NOT here yet — they arrive
## with the segment system, and inventing their fields now would be authoring a schema
## against no consumer (§1.4).

@export var stratum_id: StringName = &"archive"

## Chamber extents, XZ, in world units. Integers are drawn inclusively from these ranges,
## so a floor's size is a small deterministic draw rather than a continuous float.
##
## THE Z RANGE IS CAMERA-CONSTRAINED, not a taste decision: arena.tscn's FixedCamera sits at
## (0, 12, 12) looking down 45° and does not track the Envoy (ROADMAP P21, still open). A
## chamber deeper than ~26 walks the entry point off the bottom of frame. When P21 lands,
## this ceiling is the first thing that should rise.
@export var chamber_min_size: Vector2i = Vector2i(24, 20)
@export var chamber_max_size: Vector2i = Vector2i(34, 26)

## Distance the entry point sits inward from the chamber's south (+Z) edge.
@export var entry_edge_margin: float = 3.0

## The families this stratum may spawn. Slice 1 keeps M1's locked roster (GAME-RULES §3/§7
## seed+7) so generation is the only new variable under test — a new family and a new
## generator in one slice would make a bad floor unattributable.
@export var enemy_keys: Array[StringName] = [&"fang", &"ooze", &"watcher"]

@export var spawn_count_min: int = 3
@export var spawn_count_max: int = 5

## PROVISIONAL/UNVALIDATED (M2 Slice 1). No enemy may be generated closer than this to the
## Envoy's entry point — arriving already inside a Fang's bite band is not difficulty, it is
## an unfair floor. 10.0 sits just beyond the largest authored detection_radius (10.0), so a
## fresh floor opens with the player unaggroed and free to choose the engagement.
## Validated only by ordinary play; this is the first knob to move if floors open badly.
@export var min_spawn_distance_from_entry: float = 10.0

## Keeps spawns off the wall so an enemy never begins clamped against the boundary.
@export var spawn_edge_margin: float = 2.5

## Minimum separation between two generated spawns. Enemies have no body collision yet
## (ROADMAP P20's other half), so without this the generator can legally stack two actors
## in the same spot and the floor reads as broken.
@export var min_spawn_separation: float = 3.0

## Rejection-sampling budget per spawn. Exhausting it drops that spawn (the floor simply has
## fewer) rather than relaxing a placement law — a floor with one less Fang is a fine floor;
## one with an illegally-placed Fang is a defect.
@export var max_spawn_placement_attempts: int = 40
