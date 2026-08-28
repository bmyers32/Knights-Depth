extends GutTest
## DepthGenerator determinism, TOPOLOGY, and placement law (GAME-RULES §1.3 seeded gen,
## §5 M2 gate).

const _DEPTH: int = 1
const _SWEEP: int = 120


func _stratum() -> StratumConfig:
	return ContentDB.get_resource(&"stratum", &"archive")


# --- DETERMINISM ---------------------------------------------------------------------

func test_same_seed_and_depth_produce_an_identical_plan() -> void:
	for seed_value in [0, 1, 7, 12345, -99]:
		var first: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		var second: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		assert_eq(first.to_dict(), second.to_dict(),
			"seed %d must regenerate identically -- a run is only reproducible if this holds" % seed_value)


## PURITY, not just repeatability. The generator creates its RNG inside generate(), so no
## state can carry between calls -- which means interleaving other generations must not
## perturb a result. This is the property that makes floor COUNT unable to shift a floor's
## contents, and it is what a shared/module-level RNG would silently break.
func test_generation_is_independent_of_call_order() -> void:
	var baseline: Dictionary = DepthGenerator.generate(42, _DEPTH).to_dict()
	for noise_seed in [1, 2, 3, 4, 5]:
		DepthGenerator.generate(noise_seed, _DEPTH + noise_seed)
	assert_eq(DepthGenerator.generate(42, _DEPTH).to_dict(), baseline,
		"generating other floors first must not change this one")


func test_different_depths_of_one_run_are_different_floors() -> void:
	assert_ne(DepthGenerator.generate(2026, 1).to_dict(), DepthGenerator.generate(2026, 2).to_dict(),
		"depth must reach the floor seed, or every floor of a run is the same room")
	assert_ne(DepthGenerator.derive_floor_seed(2026, 1), DepthGenerator.derive_floor_seed(2026, 2))


func test_the_plan_reports_its_own_provenance() -> void:
	var plan: FloorPlan = DepthGenerator.generate(555, 3)
	assert_eq(plan.run_seed, 555, "a bug report is seed + command log -- a plan must name its run")
	assert_eq(plan.depth, 3)
	assert_eq(plan.floor_seed, DepthGenerator.derive_floor_seed(555, 3))
	assert_eq(plan.stratum_id, _stratum().stratum_id)


# --- TOPOLOGY ------------------------------------------------------------------------

func test_the_floor_follows_the_authored_room_sequence() -> void:
	var sequence: Array[StringName] = _stratum().room_sequence
	for seed_value in 40:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		assert_eq(plan.rooms.size(), sequence.size(), "seed %d: room count must match content" % seed_value)
		for index in sequence.size():
			assert_eq(plan.rooms[index].kind, sequence[index],
				"seed %d: room %d must be a %s -- topology is content, not a generator whim" % [seed_value, index, sequence[index]])
			assert_eq(plan.rooms[index].room_id, index, "room_id must be its chain position")


func test_a_floor_always_offers_traversal_and_at_least_one_encounter() -> void:
	for seed_value in 40:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		assert_gt(plan.rooms_of_kind(RoomPlan.KIND_COMBAT).size(), 0, "seed %d: a floor needs a fight" % seed_value)
		assert_gt(plan.rooms_of_kind(RoomPlan.KIND_TRAVERSAL).size(), 0, "seed %d: a floor needs space between fights" % seed_value)
		assert_eq(plan.rooms_of_kind(RoomPlan.KIND_ENTRY).size(), 1, "seed %d: exactly one arrival point" % seed_value)


func test_consecutive_rooms_are_joined_and_never_overlap_each_other() -> void:
	for seed_value in 40:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		assert_eq(plan.connections.size(), plan.rooms.size() - 1, "a chain has one connection per adjacent pair")
		for index in plan.rooms.size() - 1:
			var near: RoomPlan = plan.rooms[index]
			var far: RoomPlan = plan.rooms[index + 1]
			assert_lt(far.rect.end.y, near.rect.position.y,
				"seed %d: rooms %d/%d must be separated by a corridor gap, not touching" % [seed_value, index, index + 1])


## THE LOAD-BEARING TOPOLOGY INVARIANT. An aperture must OVERLAP both rooms it joins, never
## merely abut them: two rects touching on a line share zero area, so an actor would never be
## inside both and the threshold would become a discontinuity the clamp cannot reason about.
## This overlap is also what makes an encounter gate free -- the room's own rect already covers
## its half of the aperture, so sealing a room cannot shrink it or snap an actor off the
## doorway.
func test_every_aperture_genuinely_overlaps_both_rooms_it_joins() -> void:
	var overlap: float = _stratum().aperture_overlap
	assert_gt(overlap, 0.0, "a zero overlap would make every threshold a discontinuity")
	for seed_value in _SWEEP:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		for connection in plan.connections:
			for room_id in [connection.room_ids.x, connection.room_ids.y]:
				var room: RoomPlan = plan.room_by_id(room_id)
				var shared: Rect2 = connection.aperture.intersection(room.rect)
				assert_gt(shared.get_area(), 0.0,
					"seed %d: aperture %d shares no AREA with room %d -- it abuts instead of overlapping" % [seed_value, connection.connection_id, room_id])


## Connectivity proved the way the sim experiences it: every room is reachable from the entry
## point by hopping between rects that overlap. No graph, no pathfinding -- just the union.
func test_every_room_is_reachable_from_the_entry_room() -> void:
	for seed_value in 40:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		var reached: Dictionary = {0: true}
		var changed: bool = true
		while changed:
			changed = false
			for connection in plan.connections:
				var a: int = connection.room_ids.x
				var b: int = connection.room_ids.y
				var room_a: RoomPlan = plan.room_by_id(a)
				var room_b: RoomPlan = plan.room_by_id(b)
				if connection.aperture.intersection(room_a.rect).get_area() <= 0.0:
					continue
				if connection.aperture.intersection(room_b.rect).get_area() <= 0.0:
					continue
				if reached.has(a) and not reached.has(b):
					reached[b] = true
					changed = true
				elif reached.has(b) and not reached.has(a):
					reached[a] = true
					changed = true
		assert_eq(reached.size(), plan.rooms.size(), "seed %d: the floor is not fully connected" % seed_value)


func test_only_combat_connections_are_gated() -> void:
	for seed_value in 40:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		for connection in plan.connections:
			var touches_combat: bool = false
			for room_id in [connection.room_ids.x, connection.room_ids.y]:
				if plan.room_by_id(room_id).kind == RoomPlan.KIND_COMBAT:
					touches_combat = true
			assert_eq(connection.gated, touches_combat,
				"seed %d: connection %d gating must follow whether it touches a fight" % [seed_value, connection.connection_id])


func test_the_flattened_walkable_view_matches_its_source() -> void:
	for seed_value in 40:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		assert_eq(plan.walkable_rects.size(), plan.rooms.size() + plan.connections.size(),
			"the derived legality view must contain every room and every aperture, and nothing else")
		var bounds: WalkableBounds = plan.make_bounds()
		for room in plan.rooms:
			assert_true(bounds.is_inside(room.centre()), "room %d's own centre must be walkable" % room.room_id)


func test_the_entry_point_and_end_marker_sit_at_opposite_ends_and_are_walkable() -> void:
	for seed_value in _SWEEP:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		var bounds: WalkableBounds = plan.make_bounds()
		assert_true(bounds.is_inside(plan.entry_point), "seed %d: the Envoy would arrive out of bounds" % seed_value)
		assert_true(bounds.is_inside(plan.end_marker), "seed %d: the terminal marker is unreachable" % seed_value)
		assert_true(plan.rooms[0].rect.has_point(Vector2(plan.entry_point.x, plan.entry_point.z)),
			"seed %d: arrival belongs in the ENTRY room" % seed_value)
		assert_lt(plan.end_marker.z, plan.entry_point.z,
			"seed %d: the floor must lead somewhere -- the marker sits deeper than the entrance" % seed_value)


# --- PLACEMENT LAW -------------------------------------------------------------------
# "The generator does not place actors the sim would reject." Every assertion below uses the
# SIM's own predicate (WalkableBounds), never a reimplementation of it.

func test_every_generated_placement_is_legal_and_room_local() -> void:
	var stratum: StratumConfig = _stratum()
	var total_spawns: int = 0
	for seed_value in _SWEEP:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		var bounds: WalkableBounds = plan.make_bounds()
		for room in plan.rooms:
			if room.kind != RoomPlan.KIND_COMBAT:
				assert_eq(room.spawns.size(), 0, "seed %d: only COMBAT rooms carry a roster" % seed_value)
				continue
			var entrance := Vector3(room.centre().x, 0.0, room.rect.end.y)
			for spawn in room.spawns:
				total_spawns += 1
				var position: Vector3 = spawn["position"]
				assert_true(bounds.is_inside(position),
					"seed %d: spawn at %s is outside the floor -- the sim would refuse it" % [seed_value, position])
				# ROOM-LOCAL: confinement is unconditional, so an actor outside its own room
				# would be permanently clamped against a region it is not in.
				assert_true(room.rect.has_point(Vector2(position.x, position.z)),
					"seed %d: spawn at %s is outside room %d, which OWNS it" % [seed_value, position, room.room_id])
				assert_true(position.distance_to(entrance) >= stratum.min_spawn_distance_from_entry - 0.001,
					"seed %d: spawn at %s ambushes the doorway" % [seed_value, position])
				assert_true(stratum.enemy_keys.has(spawn["enemy_key"]),
					"seed %d: '%s' is not in this stratum's family pool" % [seed_value, spawn["enemy_key"]])
	assert_gt(total_spawns, 300, "sanity: the sweep really generated a population to check")


func test_generated_spawns_never_stack_on_each_other() -> void:
	var minimum: float = _stratum().min_spawn_separation
	for seed_value in _SWEEP:
		for room in DepthGenerator.generate(seed_value, _DEPTH).rooms:
			for i in room.spawns.size():
				for j in range(i + 1, room.spawns.size()):
					var separation: float = room.spawns[i]["position"].distance_to(room.spawns[j]["position"])
					assert_true(separation >= minimum - 0.001,
						"seed %d: two spawns are %.2f apart (minimum %.2f) -- with no body collision they read as one broken actor" % [seed_value, separation, minimum])


func test_every_combat_room_is_actually_populated() -> void:
	var stratum: StratumConfig = _stratum()
	for seed_value in _SWEEP:
		for room in DepthGenerator.generate(seed_value, _DEPTH).rooms_of_kind(RoomPlan.KIND_COMBAT):
			assert_gt(room.spawns.size(), 0,
				"seed %d: an empty combat room would seal the player in and never reopen" % seed_value)
			assert_true(room.spawns.size() <= stratum.spawn_count_max, "seed %d: above the authored maximum" % seed_value)


func test_rooms_stay_within_their_authored_size_range_for_their_kind() -> void:
	var stratum: StratumConfig = _stratum()
	for seed_value in 60:
		for room in DepthGenerator.generate(seed_value, _DEPTH).rooms:
			var is_combat: bool = room.kind == RoomPlan.KIND_COMBAT
			var minimum: Vector2i = stratum.chamber_min_size if is_combat else stratum.connective_min_size
			var maximum: Vector2i = stratum.chamber_max_size if is_combat else stratum.connective_max_size
			assert_between(room.rect.size.x, float(minimum.x), float(maximum.x), "room %d width" % room.room_id)
			assert_between(room.rect.size.y, float(minimum.y), float(maximum.y), "room %d depth" % room.room_id)


## The validated combat-room primitive must stay bigger than connective space, or the
## exploration/arena contrast the human pass asked for disappears.
func test_combat_rooms_are_larger_than_connective_space() -> void:
	var stratum: StratumConfig = _stratum()
	assert_gt(stratum.chamber_min_size.x, stratum.connective_max_size.x,
		"the smallest combat room must still be wider than the widest corridor room")
	assert_gt(stratum.chamber_min_size.y, stratum.connective_max_size.y,
		"and deeper -- a floor of identical boxes is the 'bigger arena' the human pass rejected")


# --- PERFORMANCE ---------------------------------------------------------------------

## GAME-RULES §5 M2: "gen time <100 ms/floor". Measured now, while it is trivially true, so
## the gate item has a live instrument rather than an assumption to check at milestone close.
func test_generation_stays_far_under_the_hundred_millisecond_gate() -> void:
	var started: int = Time.get_ticks_usec()
	for seed_value in 50:
		DepthGenerator.generate(seed_value, _DEPTH)
	var per_floor_ms: float = (Time.get_ticks_usec() - started) / 1000.0 / 50.0
	gut.p("generation: %.3f ms/floor" % per_floor_ms)
	assert_lt(per_floor_ms, 100.0, "GAME-RULES §5 M2 budget is 100 ms per floor")
