class_name DepthGenerator
extends RefCounted
## DepthGenerator.generate(seed, depth) -> FloorPlan — a PURE FUNCTION of its inputs
## (CLAUDE.md Core Interfaces; signature is pinned there under "do not drift").
##
## Purity is mechanical, not aspirational: the RNG is created fresh INSIDE generate(), so no
## state carries between calls and the same (seed, depth) yields the same floor regardless of
## what was generated before it. That also satisfies GAME-RULES §1.3's separate-streams law by
## construction — there is no shared object through which a generation draw could perturb
## SimWorld._combat_rng, and floor COUNT cannot shift combat rolls either.
##
## Stratum parameters resolve internally through ContentDB so the public signature stays
## exactly two ints; _generate_from below is the pure core that takes plain params, which is
## the same driver-unpacks-the-Resource boundary ContentRegistrar draws for the sim.
##
## TOPOLOGY: a LINEAR CHAIN laid along -Z, so the player walks away from the camera and
## deeper into the floor. Room ROLES come from StratumConfig.room_sequence (content, not
## code); sizes, rosters and placements are seeded. Branching graphs are later work.

## Slice generates for the Archive only. Depth -> stratum selection (Archive 1-3, Foundry 4-5
## per GAME-RULES §5) arrives with the second stratum; hardcoding a lookup table for one entry
## would be a schema with no consumer.
const _SLICE_STRATUM: StringName = &"archive"

## 64-bit odd constants (PCG's multiplier and increment). Chosen over String.hash() on
## purpose: hash() is stable within an engine version but NOT guaranteed across them, and
## GAME-RULES §5's golden-seed gate has to survive a Godot patch bump. GDScript ints are
## int64 and multiplication overflow wraps two's-complement, which is deterministic.
const _SEED_MIX_A: int = 6364136223846793005
const _SEED_MIX_B: int = 1442695040888963407


static func generate(seed: int, depth: int) -> FloorPlan:
	var stratum: StratumConfig = ContentDB.get_resource(&"stratum", _SLICE_STRATUM)
	return _generate_from(seed, depth, stratum)


## Derives this floor's seed from the run seed and the depth. Every floor of a run draws from
## the same run seed but a different stream, so re-entering depth 3 rebuilds depth 3 and never
## depth 2's layout.
static func derive_floor_seed(run_seed: int, depth: int) -> int:
	var mixed: int = run_seed * _SEED_MIX_A + depth * _SEED_MIX_B
	mixed ^= mixed >> 31
	mixed = mixed * _SEED_MIX_A
	mixed ^= mixed >> 29
	return mixed


static func _generate_from(run_seed: int, depth: int, stratum: StratumConfig) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.run_seed = run_seed
	plan.depth = depth
	plan.floor_seed = derive_floor_seed(run_seed, depth)
	plan.stratum_id = stratum.stratum_id

	var rng := RandomNumberGenerator.new()
	rng.seed = plan.floor_seed

	_lay_out_chain(rng, stratum, plan)
	_connect_chain(stratum, plan)
	plan.rebuild_walkable_rects()

	# Rosters are placed AFTER the topology is final and the legality view is derived, so
	# every spawn can be validated against the sim's own predicate rather than against a
	# half-built floor.
	var bounds: WalkableBounds = plan.make_bounds()
	for room in plan.rooms:
		if room.kind == RoomPlan.KIND_COMBAT:
			room.spawns = _place_room_roster(rng, stratum, room, bounds)

	var first: RoomPlan = plan.rooms[0]
	plan.entry_point = first.centre()
	var last: RoomPlan = plan.rooms[plan.rooms.size() - 1]
	plan.end_marker = Vector3(last.centre().x, 0.0, last.rect.position.y + stratum.end_marker_margin)
	return plan


## Rooms are stacked along -Z with corridor_length of empty space between consecutive rects,
## every room centred on x = 0. The gap is what the aperture spans; without it, two room rects
## would abut and the junction would carry no overlap.
static func _lay_out_chain(rng: RandomNumberGenerator, stratum: StratumConfig, plan: FloorPlan) -> void:
	var z_cursor: float = 0.0
	for index in stratum.room_sequence.size():
		var kind: StringName = stratum.room_sequence[index]
		var minimum: Vector2i = stratum.chamber_min_size if kind == RoomPlan.KIND_COMBAT else stratum.connective_min_size
		var maximum: Vector2i = stratum.chamber_max_size if kind == RoomPlan.KIND_COMBAT else stratum.connective_max_size
		var width: int = rng.randi_range(minimum.x, maximum.x)
		var extent: int = rng.randi_range(minimum.y, maximum.y)

		var room := RoomPlan.new()
		room.room_id = index
		room.kind = kind
		room.rect = Rect2(-width * 0.5, z_cursor - extent, float(width), float(extent))
		plan.rooms.append(room)

		z_cursor = room.rect.position.y - stratum.corridor_length


## One aperture per adjacent pair. Each spans the corridor gap AND pokes aperture_overlap into
## both rooms, so the union stays genuinely connected at the threshold.
static func _connect_chain(stratum: StratumConfig, plan: FloorPlan) -> void:
	for index in plan.rooms.size() - 1:
		var near: RoomPlan = plan.rooms[index]        # the +Z side
		var far: RoomPlan = plan.rooms[index + 1]     # the -Z side
		var connection := ConnectionPlan.new()
		connection.connection_id = index
		connection.room_ids = Vector2i(near.room_id, far.room_id)
		var min_z: float = far.rect.end.y - stratum.aperture_overlap
		var max_z: float = near.rect.position.y + stratum.aperture_overlap
		connection.aperture = Rect2(
			-stratum.aperture_width * 0.5, min_z,
			stratum.aperture_width, max_z - min_z,
		)
		# PRESENTATION flag only: a barrier is drawn here and can visibly close. The
		# mechanical seal is room confinement in the sim, never a change to the walkable set.
		connection.gated = near.kind == RoomPlan.KIND_COMBAT or far.kind == RoomPlan.KIND_COMBAT
		plan.connections.append(connection)


## Populates ONE combat room. Distances are measured from that room's own entrance — the
## midpoint of its +Z edge, which is where the player walks in — because a room is entered on
## its own terms, not relative to the far-away floor entry.
static func _place_room_roster(rng: RandomNumberGenerator, stratum: StratumConfig, room: RoomPlan, bounds: WalkableBounds) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	var entrance := Vector3(room.centre().x, 0.0, room.rect.end.y)
	var inner := Rect2(
		room.rect.position + Vector2.ONE * stratum.spawn_edge_margin,
		room.rect.size - Vector2.ONE * stratum.spawn_edge_margin * 2.0,
	)
	var count: int = rng.randi_range(stratum.spawn_count_min, stratum.spawn_count_max)
	for index in count:
		# The family draw happens BEFORE placement and exactly once per spawn, so a rejected
		# position never shifts which family gets placed. Rejection sampling that also
		# re-rolled identity would make the roster depend on geometry luck.
		var enemy_key: StringName = stratum.enemy_keys[rng.randi_range(0, stratum.enemy_keys.size() - 1)]
		var placed: Dictionary = _sample_position(rng, stratum, inner, entrance, bounds, spawns)
		if placed.is_empty():
			# Budget exhausted: drop this spawn. A room with one fewer enemy is a fine room;
			# one with an illegally-placed enemy is a defect the sim would reject.
			continue
		spawns.append({"enemy_key": enemy_key, "position": placed["position"]})
	return spawns


static func _sample_position(rng: RandomNumberGenerator, stratum: StratumConfig, inner: Rect2, entrance: Vector3, bounds: WalkableBounds, placed: Array[Dictionary]) -> Dictionary:
	for _attempt in stratum.max_spawn_placement_attempts:
		var candidate := Vector3(
			rng.randf_range(inner.position.x, inner.end.x),
			0.0,
			rng.randf_range(inner.position.y, inner.end.y),
		)
		# The sim's OWN predicate, not a reimplementation of it — this is the whole reason
		# WalkableBounds lives in sim/ and is imported here.
		if not bounds.is_inside(candidate):
			continue
		if candidate.distance_to(entrance) < stratum.min_spawn_distance_from_entry:
			continue
		var separated: bool = true
		for existing in placed:
			if candidate.distance_to(existing["position"]) < stratum.min_spawn_separation:
				separated = false
				break
		if separated:
			return {"position": candidate}
	return {}
