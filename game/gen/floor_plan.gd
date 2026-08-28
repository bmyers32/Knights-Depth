class_name FloorPlan
extends RefCounted
## One floor's complete deterministic description (CLAUDE.md Core Interfaces:
## DepthGenerator.generate(seed, depth) -> FloorPlan).
##
## THE SINGLE SOURCE for that floor: sim reads bounds + entry point, presentation reads the
## same rects to build geometry and the same spawn records to instantiate actors. There is
## deliberately no second authored roster or collision layout in arena.tscn -- two
## descriptions of one floor is exactly the "never let two disagree silently" failure
## AGENTS.md Truth Homes exists to prevent.
##
## Plain data, RefCounted, no Node/Resource deps: headless-runnable by law (CLAUDE.md
## Structure) and serializable, which is what lets a server hand a joining client a floor
## in M3 (§4.1: floor layout is server-authoritative).

## The run's seed, carried so a plan can always name its own provenance -- a bug report is
## seed + command log (§1.3), and a FloorPlan that can't say which run produced it breaks
## that contract.
var run_seed: int = 0
## The per-floor seed actually fed to the generator's RNG, derived from (run_seed, depth).
var floor_seed: int = 0
var depth: int = 0
var stratum_id: StringName = &""

## Walkable area, XZ plane. Slice 1 emits exactly one rect (one chamber).
var walkable_rects: Array[Rect2] = []
## Where the Envoy stands on arrival.
var entry_point: Vector3 = Vector3.ZERO
## [{"enemy_key": StringName, "position": Vector3}] -- this floor's ENTIRE roster.
## Every entry is floor-scoped: nothing here survives the next load_floor.
var spawns: Array[Dictionary] = []


## The bounds object the sim installs. Built here rather than by the driver so there is one
## rects -> WalkableBounds conversion in the project.
func make_bounds() -> WalkableBounds:
	return WalkableBounds.new(walkable_rects)


## Canonical serialization for the golden-seed fixture (GAME-RULES §5 M2: "same seed ->
## byte-identical FloorPlan").
##
## Floats are snapped to 4 decimals deliberately. The generator's raw determinism is proved
## separately and exactly by test_depth_generator.gd (generate twice, compare in memory);
## THIS serialization guards against BEHAVIOURAL DRIFT across sessions, and a fixture that
## also encoded float print-formatting would fail on an engine patch bump for a reason that
## has nothing to do with generation changing. 4 decimals is far finer than any drift a real
## generator change could produce.
func to_dict() -> Dictionary:
	var rect_dicts: Array = []
	for rect in walkable_rects:
		rect_dicts.append({
			"x": _snap(rect.position.x), "z": _snap(rect.position.y),
			"w": _snap(rect.size.x), "d": _snap(rect.size.y),
		})
	var spawn_dicts: Array = []
	for spawn in spawns:
		var position: Vector3 = spawn["position"]
		spawn_dicts.append({
			"enemy_key": String(spawn["enemy_key"]),
			"x": _snap(position.x), "y": _snap(position.y), "z": _snap(position.z),
		})
	return {
		"run_seed": run_seed,
		"floor_seed": floor_seed,
		"depth": depth,
		"stratum_id": String(stratum_id),
		"walkable_rects": rect_dicts,
		"entry_point": {"x": _snap(entry_point.x), "y": _snap(entry_point.y), "z": _snap(entry_point.z)},
		"spawns": spawn_dicts,
	}


func _snap(value: float) -> float:
	return snappedf(value, 0.0001)
