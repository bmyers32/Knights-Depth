class_name FloorPlan
extends RefCounted
## One floor's complete deterministic description (CLAUDE.md Core Interfaces:
## DepthGenerator.generate(seed, depth) -> FloorPlan).
##
## THE SINGLE SOURCE for that floor. Sim reads bounds, rooms, rosters and the entry point;
## presentation reads the same rooms and connections to build geometry and instantiate
## actors. There is deliberately no second authored roster or collision layout in arena.tscn
## -- two descriptions of one floor is exactly the "never let two disagree silently" failure
## AGENTS.md Truth Homes exists to prevent.
##
## TWO VIEWS, ONE TRUTH:
##   rooms + connections  the authoring/gameplay view (roles, ownership, encounters)
##   walkable_rects       the flattened legality view the sim clamps against, DERIVED from
##                        the two above by rebuild_walkable_rects()
##
## Plain data, RefCounted, no Node/Resource deps: headless-runnable by law (CLAUDE.md
## Structure) and serializable, which is what lets a server hand a joining client a floor in
## M3 (§4.1: floor layout is server-authoritative).

## The run's seed, carried so a plan can always name its own provenance -- a bug report is
## seed + command log (§1.3), and a FloorPlan that can't say which run produced it breaks
## that contract.
var run_seed: int = 0
## The per-floor seed actually fed to the generator's RNG, derived from (run_seed, depth).
var floor_seed: int = 0
var depth: int = 0
var stratum_id: StringName = &""

var rooms: Array[RoomPlan] = []
var connections: Array[ConnectionPlan] = []

## DERIVED union of every room rect and every aperture rect. Never authored directly.
var walkable_rects: Array[Rect2] = []
## Where the Envoy stands on arrival, inside the ENTRY room.
var entry_point: Vector3 = Vector3.ZERO
## Deterministic terminal endpoint, inside the last room. Its ONLY job is to make the test
## grammar visible -- ENTRY -> TRAVERSAL -> COMBAT -> CLEAR -> TRAVERSAL -> FLOOR END. It is
## not an elevator, carries no transition logic, and triggers no run-end UI.
var end_marker: Vector3 = Vector3.ZERO


## Recomputes the flattened legality view from rooms + connections. Called by the generator
## once the topology is final; keeping it a function rather than inlining it is what lets a
## test assert that the derived form actually matches its source.
func rebuild_walkable_rects() -> void:
	var rects: Array[Rect2] = []
	for room in rooms:
		rects.append(room.rect)
	for connection in connections:
		rects.append(connection.aperture)
	walkable_rects = rects


## The bounds object the sim installs. Built here rather than by the driver so there is one
## rects -> WalkableBounds conversion in the project.
func make_bounds() -> WalkableBounds:
	return WalkableBounds.new(walkable_rects)


func room_by_id(room_id: int) -> RoomPlan:
	for room in rooms:
		if room.room_id == room_id:
			return room
	return null


func rooms_of_kind(kind: StringName) -> Array[RoomPlan]:
	var matching: Array[RoomPlan] = []
	for room in rooms:
		if room.kind == kind:
			matching.append(room)
	return matching


## Every spawn on the floor, flattened, each tagged with the room that OWNS it. Ownership
## rides with the record because confinement is unconditional -- an actor without a room is
## an actor with no legal region, so the driver must never lose the association.
func all_spawns() -> Array[Dictionary]:
	var flattened: Array[Dictionary] = []
	for room in rooms:
		for spawn in room.spawns:
			flattened.append({
				"enemy_key": spawn["enemy_key"],
				"position": spawn["position"],
				"room_id": room.room_id,
			})
	return flattened


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
	var room_dicts: Array = []
	for room in rooms:
		var spawn_dicts: Array = []
		for spawn in room.spawns:
			spawn_dicts.append({
				"enemy_key": String(spawn["enemy_key"]),
				"position": _point(spawn["position"]),
			})
		room_dicts.append({
			"room_id": room.room_id,
			"kind": String(room.kind),
			"rect": _rect(room.rect),
			"spawns": spawn_dicts,
		})
	var connection_dicts: Array = []
	for connection in connections:
		connection_dicts.append({
			"connection_id": connection.connection_id,
			"room_ids": [connection.room_ids.x, connection.room_ids.y],
			"aperture": _rect(connection.aperture),
			"gated": connection.gated,
		})
	var rect_dicts: Array = []
	for rect in walkable_rects:
		rect_dicts.append(_rect(rect))
	return {
		"run_seed": run_seed,
		"floor_seed": floor_seed,
		"depth": depth,
		"stratum_id": String(stratum_id),
		"rooms": room_dicts,
		"connections": connection_dicts,
		"walkable_rects": rect_dicts,
		"entry_point": _point(entry_point),
		"end_marker": _point(end_marker),
	}


func _rect(rect: Rect2) -> Dictionary:
	return {"x": _snap(rect.position.x), "z": _snap(rect.position.y), "w": _snap(rect.size.x), "d": _snap(rect.size.y)}


func _point(point: Vector3) -> Dictionary:
	return {"x": _snap(point.x), "y": _snap(point.y), "z": _snap(point.z)}


func _snap(value: float) -> float:
	return snappedf(value, 0.0001)
