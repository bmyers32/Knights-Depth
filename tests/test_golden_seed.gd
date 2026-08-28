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
## inspected: one chamber, a legal entry point, and a non-empty roster standing inside it.
func test_the_committed_fixture_describes_a_sane_floor() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	assert_true(parsed is Dictionary, "the fixture must be a JSON object")
	var fixture: Dictionary = parsed

	assert_eq(int(fixture["run_seed"]), GOLDEN_SEED)
	assert_eq(int(fixture["depth"]), GOLDEN_DEPTH)
	assert_eq(String(fixture["stratum_id"]), "archive")
	assert_eq((fixture["walkable_rects"] as Array).size(), 1, "Slice 1 floors are a single chamber")
	assert_gt((fixture["spawns"] as Array).size(), 0, "a floor with no enemies is not a floor")

	# Re-derive the geometry from the fixture itself and check it, rather than trusting the
	# generator that produced it -- otherwise a generator bug would validate its own output.
	var rect: Dictionary = fixture["walkable_rects"][0]
	var min_x: float = float(rect["x"])
	var min_z: float = float(rect["z"])
	var max_x: float = min_x + float(rect["w"])
	var max_z: float = min_z + float(rect["d"])

	var entry: Dictionary = fixture["entry_point"]
	assert_between(float(entry["x"]), min_x, max_x, "the entry point must be inside the chamber")
	assert_between(float(entry["z"]), min_z, max_z, "the entry point must be inside the chamber")

	var minimum_distance: float = ContentDB.get_resource(&"stratum", &"archive").min_spawn_distance_from_entry
	for spawn in fixture["spawns"]:
		assert_between(float(spawn["x"]), min_x, max_x, "spawn outside the chamber on X")
		assert_between(float(spawn["z"]), min_z, max_z, "spawn outside the chamber on Z")
		var offset := Vector2(float(spawn["x"]) - float(entry["x"]), float(spawn["z"]) - float(entry["z"]))
		assert_gt(offset.length(), minimum_distance - 0.001, "the floor must not open with an enemy on top of the player")
