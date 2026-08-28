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
## inspected: four independent layers, a connected walkable union, and the authored grammar
## legible as data.
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
	assert_true(bool(fixture["authored_layout"]), "the fixture must declare itself authored")

	# --- SPATIAL: irregular, and it wraps a void.
	var patches: Array = fixture["patches"]
	assert_gt(patches.size(), 4, "an exploration floor is more than a handful of boxes")
	var widths: Dictionary = {}
	var elevations: Dictionary = {}
	for patch in patches:
		widths[float(patch["rect"]["w"])] = true
		elevations[float(patch["elevation"])] = true
	assert_gt(widths.size(), 3, "many different widths are what makes a silhouette irregular")
	assert_gt(elevations.size(), 1, "and at least one ramp/raised-ground change")
	assert_false(_walkable(fixture, Vector2(0.0, -22.0)), "the hall must wrap a genuine void")
	for probe in [Vector2(-12.0, -22.0), Vector2(12.0, -22.0)]:
		assert_true(_walkable(fixture, probe), "with ground wrapping it at %s" % probe)

	# --- PROGRESSION: every aperture overlaps both patches; something starts closed.
	var connections: Array = fixture["connections"]
	assert_gt(connections.size(), 0)
	var closed: int = 0
	for connection in connections:
		if not bool(connection["starts_open"]):
			closed += 1
		for patch_id in connection["patch_ids"]:
			var patch: Dictionary = _by_id(patches, "patch_id", int(patch_id))
			assert_gt(_rect(connection["aperture"]).intersection(_rect(patch["rect"])).get_area(), 0.0,
				"aperture %d only abuts patch %d instead of overlapping it" % [int(connection["connection_id"]), int(patch_id)])
	assert_gt(closed, 0, "a floor with every route already open has nothing to discover")

	# --- The authored grammar, readable as data.
	var triggers: Array = fixture["triggers"]
	var by_kind: Dictionary = {}
	for trigger in triggers:
		by_kind[String(trigger["kind"])] = true
		assert_gt((trigger["effects"] as Array).size(), 0, "a controller with no effect does nothing")
	assert_true(by_kind.has("region_entered"), "a one-way commitment")
	assert_true(by_kind.has("breakable_destroyed"), "a concealment reveal")
	assert_true(by_kind.has("interacted"), "player-operated switches")
	assert_true(by_kind.has("encounter_cleared"), "and progression past the fight")

	# THE PARTY BUTTON: its whole consequence in ONE record.
	var multi: int = 0
	for trigger in triggers:
		if (trigger["effects"] as Array).size() >= 3:
			multi += 1
	assert_gt(multi, 0, "one interactable must own a multi-effect sequence atomically")

	# NO fight may start merely by entering a region -- the rule play falsified.
	for trigger in triggers:
		if String(trigger["kind"]) != "region_entered":
			continue
		for effect in trigger["effects"]:
			assert_ne(String(effect["kind"]), "activate_encounter",
				"trigger %d starts a fight by walking into a region" % int(trigger["trigger_id"]))

	# --- ENCOUNTER + INTERACTION.
	var roles: Dictionary = {}
	for encounter in fixture["encounters"]:
		roles[String(encounter["role"])] = true
		for spawn in encounter["roster"]:
			var position := Vector2(float(spawn["position"]["x"]), float(spawn["position"]["z"]))
			assert_true(_walkable(fixture, position), "spawn at %s is off the floor" % position)
			assert_true(_rect(encounter["region"]).has_point(position),
				"spawn at %s is outside the site that owns it" % position)
	assert_true(roles.has("mandatory"), "one authored lock-in fight")
	assert_true(roles.has("ambient"), "and one inhabited territory")

	var hidden: int = 0
	for interactable in fixture["interactables"]:
		if bool(interactable["starts_hidden"]):
			hidden += 1
	assert_eq(hidden, 1, "exactly one concealed progression control")
	assert_eq((fixture["breakables"] as Array).size(), 1, "concealed by exactly one prop")
	assert_eq(int(fixture["breakables"][0]["conceals_interactable_id"]),
		int(_first_hidden(fixture)["interactable_id"]), "and the prop must conceal THAT switch")

	# --- Arrival and endpoint both stand on real ground, and the floor leads somewhere.
	var entry: Dictionary = fixture["entry_point"]
	var end_marker: Dictionary = fixture["end_marker"]
	assert_true(_walkable(fixture, Vector2(float(entry["x"]), float(entry["z"]))), "the Envoy would arrive out of bounds")
	assert_true(_walkable(fixture, Vector2(float(end_marker["x"]), float(end_marker["z"]))), "the marker is unreachable")
	assert_lt(float(end_marker["z"]), float(entry["z"]), "the floor must lead somewhere")


func _rect(source: Dictionary) -> Rect2:
	return Rect2(float(source["x"]), float(source["z"]), float(source["w"]), float(source["d"]))


func _by_id(items: Array, key: String, wanted: int) -> Dictionary:
	for item in items:
		if int(item[key]) == wanted:
			return item
	return {}


func _first_hidden(fixture: Dictionary) -> Dictionary:
	for interactable in fixture["interactables"]:
		if bool(interactable["starts_hidden"]):
			return interactable
	return {}


## Walkable means "inside any patch or any aperture" -- the union, exactly as the sim sees it.
func _walkable(fixture: Dictionary, point: Vector2) -> bool:
	for patch in fixture["patches"]:
		if _rect(patch["rect"]).has_point(point):
			return true
	for connection in fixture["connections"]:
		if _rect(connection["aperture"]).has_point(point):
			return true
	return false
