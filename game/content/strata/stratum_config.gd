class_name StratumConfig
extends Resource
## One stratum's generation parameters (M2, GAME-RULES §5: "stratum theme drives segment
## pool + hazard/status set + enemy-family weights — all from config").
##
## Prime Directive 3: every number a floor's shape depends on lives here, never as a
## literal in game/gen/. Retuning a stratum is a .tres edit.
##
## SCOPE: one stratum (Archive), one LINEAR CHAIN of rooms per floor. The hazard set,
## branching topology, and per-depth family weighting named in §5 are NOT here yet — they
## arrive with their own mechanics, and inventing their fields now would be authoring a
## schema against no consumer (§1.4).

@export var stratum_id: StringName = &"archive"

## THE ROOM CHAIN, in order. Topology is CONTENT, not code: the generator lays out whatever
## sequence appears here, so adding a second combat room is a .tres edit. Branching graphs are
## deliberately not expressible yet — a chain is what the first exploration playtest needs,
## and a graph brings its own layout and connectivity questions.
@export var room_sequence: Array[StringName] = [&"entry", &"traversal", &"combat", &"traversal"]

## COMBAT room extents, XZ, in world units. Integers are drawn inclusively from these ranges,
## so a floor's size is a small deterministic draw rather than a continuous float.
##
## VALIDATED BY PLAY (Breon, 2026-08-28): the M2 Slice 1 chamber at these dimensions was
## judged a good battle-arena room — bounds readable, placement fair, combat unaffected. The
## values originally had a camera ceiling on their Z range; the follow camera (P21) removed
## that constraint, but the numbers STAY because they are now validated for their real job.
## Do not retune them to make a floor longer — add rooms instead.
@export var chamber_min_size: Vector2i = Vector2i(24, 20)
@export var chamber_max_size: Vector2i = Vector2i(34, 26)

## ENTRY and TRAVERSAL room extents. Smaller than a combat room on purpose: connective space
## should read as somewhere you pass through, not as another arena.
@export var connective_min_size: Vector2i = Vector2i(12, 10)
@export var connective_max_size: Vector2i = Vector2i(18, 14)

## --- CONNECTIONS ---------------------------------------------------------------------
## Gap between two consecutive room rects. The aperture spans it.
@export var corridor_length: float = 6.0
## Aperture width. Wide enough to walk through without fighting the clamp, narrow enough to
## read as a doorway rather than a missing wall.
@export var aperture_width: float = 5.0
## How far the aperture pokes INTO each room it joins. MUST be > 0: two rects that merely abut
## share zero area, so an actor would never be inside both and the threshold would become a
## discontinuity (see WalkableBounds). This overlap is also what makes an encounter gate free
## — the room rect already covers its own share of the aperture, so sealing a room can never
## shrink it or snap an actor off the threshold.
@export var aperture_overlap: float = 1.5

## Distance the terminal marker sits inward from the last room's far (-Z) edge.
@export var end_marker_margin: float = 3.0

## The families this stratum may spawn. Slice 1 keeps M1's locked roster (GAME-RULES §3/§7
## seed+7) so generation is the only new variable under test — a new family and a new
## generator in one slice would make a bad floor unattributable.
@export var enemy_keys: Array[StringName] = [&"fang", &"ooze", &"watcher"]

@export var spawn_count_min: int = 3
@export var spawn_count_max: int = 5

## PROVISIONAL/UNVALIDATED. No enemy may be generated closer than this to the point where the
## player WALKS INTO its room — arriving already inside a Fang's bite band is not difficulty,
## it is an unfair encounter. Measured from the combat room's own entrance, not from the
## floor's entry point, because a room is entered on its own terms.
## Validated only by ordinary play; this is the first knob to move if encounters open badly.
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
