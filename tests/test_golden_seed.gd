extends GutTest
## GOLDEN-SEED GATE (GAME-RULES §5 M2: "Same seed -> byte-identical FloorPlan").
##
## test_depth_generator.gd proves determinism WITHIN a session (generate twice, compare).
## This proves it ACROSS sessions: the fixture was recorded once, deliberately, inspected by
## hand, and committed. It is the instrument that notices generation changing.
##
## NEVER RE-RECORD THIS TO MAKE A RED TEST GREEN. If it fails, the question is "what did I
## change about generation, and did I mean to?" Re-record with tools/record_floor_plan_golden.gd
## only after answering that, and note the reason + date in the same commit (golden-seed
## re-baseline law, CLAUDE.md Always-On Rules; BRAIN: "Never rewrite yesterday's baseline to
## describe today").

const FIXTURE_PATH := "res://tests/fixtures/floor_plan_golden.json"
## Must match tools/record_floor_plan_golden.gd.
const GOLDEN_SEED := 20260828
const GOLDEN_DEPTH := 1


## Compares the SERIALIZED FORM against the committed bytes rather than parsing the fixture
## back into a Dictionary: JSON.parse_string widens every number to float, so a parsed
## comparison would silently stop distinguishing an int seed from a float one. Byte equality
## is also literally what the gate asks for.
func test_the_golden_seed_still_produces_the_committed_floor() -> void:
	var committed: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	assert_false(committed.is_empty(), "the golden fixture must exist -- record it with tools/record_floor_plan_golden.gd")

	var regenerated: String = JSON.stringify(DepthGenerator.generate(GOLDEN_SEED, GOLDEN_DEPTH).to_dict(), "\t")
	assert_eq(regenerated, committed,
		"seed %d depth %d no longer produces the recorded floor. If generation changed ON PURPOSE, re-record the fixture and date the reason; otherwise this is the regression it exists to catch." % [GOLDEN_SEED, GOLDEN_DEPTH])


## DISCRIMINATION CHECK: proves the comparison can fail, so the assertion above is not
## vacuously passing on, say, two empty strings.
func test_a_different_seed_does_not_match_the_golden_floor() -> void:
	var committed: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	var other: String = JSON.stringify(DepthGenerator.generate(GOLDEN_SEED + 1, GOLDEN_DEPTH).to_dict(), "\t")
	assert_ne(other, committed, "a different seed must produce a different floor, or the fixture proves nothing")


## The fixture is only trustworthy if a human could read it. Pins the shape a reviewer
## inspected: a connected chain, a legal arrival and endpoint, and a populated fight.
##
## Re-derives everything from the FIXTURE itself rather than from the generator that produced
## it -- otherwise a generator bug would be validating its own output.
func test_the_committed_fixture_describes_a_sane_floor() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	assert_true(parsed is Dictionary, "the fixture must be a JSON object")
	var fixture: Dictionary = parsed

	assert_eq(int(fixture["run_seed"]), GOLDEN_SEED)
	assert_eq(int(fixture["depth"]), GOLDEN_DEPTH)
	assert_eq(String(fixture["stratum_id"]), "archive")

	var rooms: Array = fixture["rooms"]
	var connections: Array = fixture["connections"]
	assert_gt(rooms.size(), 1, "a floor is more than one room")
	assert_eq(connections.size(), rooms.size() - 1, "a chain has one connection per adjacent pair")
	assert_eq((fixture["walkable_rects"] as Array).size(), rooms.size() + connections.size(),
		"the derived legality view must be exactly the rooms plus the apertures")

	var kinds: Array = []
	var populated_combat: int = 0
	for room in rooms:
		kinds.append(String(room["kind"]))
		if String(room["kind"]) == "combat":
			assert_gt((room["spawns"] as Array).size(), 0,
				"an empty combat room would seal the player in and never reopen")
			populated_combat += 1
		else:
			assert_eq((room["spawns"] as Array).size(), 0, "only combat rooms carry a roster")
	assert_eq(kinds[0], "entry", "the chain must start where the Envoy arrives")
	assert_gt(populated_combat, 0, "a floor needs a fight")
	assert_true(kinds.has("traversal"), "and space between fights")

	# Every aperture must genuinely OVERLAP both rooms it joins. Abutting rects share zero
	# area, which would make each threshold a discontinuity.
	for connection in connections:
		for room_id in connection["room_ids"]:
			var room: Dictionary = _room_with_id(rooms, int(room_id))
			assert_gt(_rect_of(connection["aperture"]).intersection(_rect_of(room["rect"])).get_area(), 0.0,
				"aperture %d only abuts room %d instead of overlapping it" % [int(connection["connection_id"]), int(room_id)])
		var touches_combat: bool = false
		for room_id in connection["room_ids"]:
			if String(_room_with_id(rooms, int(room_id))["kind"]) == "combat":
				touches_combat = true
		assert_eq(bool(connection["gated"]), touches_combat, "only connections touching a fight are gated")

	# Arrival and endpoint are both walkable, and the floor actually leads somewhere.
	var entry: Dictionary = fixture["entry_point"]
	var end_marker: Dictionary = fixture["end_marker"]
	assert_true(_is_walkable(fixture, entry), "the Envoy would arrive out of bounds")
	assert_true(_is_walkable(fixture, end_marker), "the terminal marker is unreachable")
	assert_lt(float(end_marker["z"]), float(entry["z"]), "the marker must sit deeper than the entrance")

	# And nothing was generated on top of the doorway into the fight.
	var minimum: float = ContentDB.get_resource(&"stratum", &"archive").min_spawn_distance_from_entry
	for room in rooms:
		if String(room["kind"]) != "combat":
			continue
		var rect: Rect2 = _rect_of(room["rect"])
		var entrance := Vector2(rect.get_center().x, rect.end.y)
		for spawn in room["spawns"]:
			var position := Vector2(float(spawn["position"]["x"]), float(spawn["position"]["z"]))
			assert_true(rect.has_point(position), "spawn outside the room that owns it")
			assert_gt(position.distance_to(entrance), minimum - 0.001, "spawn ambushes the doorway")


func _rect_of(source: Dictionary) -> Rect2:
	return Rect2(float(source["x"]), float(source["z"]), float(source["w"]), float(source["d"]))


func _room_with_id(rooms: Array, room_id: int) -> Dictionary:
	for room in rooms:
		if int(room["room_id"]) == room_id:
			return room
	return {}


func _is_walkable(fixture: Dictionary, point: Dictionary) -> bool:
	var flat := Vector2(float(point["x"]), float(point["z"]))
	for rect_source in fixture["walkable_rects"]:
		if _rect_of(rect_source).has_point(flat):
			return true
	return false
