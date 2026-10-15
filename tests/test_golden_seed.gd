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
## THE SECOND FLOOR'S FIXTURE -- FIRST RECORDED 2026-10-09, and that date is the limit of what it
## proves. It is a baseline going FORWARD: it notices Floor 2 changing from here on. It is not
## evidence that Floor 2 matched anything before that day -- the floor passed its spatial gate on
## 2026-09-09 with no cross-session golden at all.
const FIXTURE_DEPTH2_PATH := "res://tests/fixtures/floor_plan_golden_depth2.json"
const GOLDEN_DEPTH2 := 2
## Must match DepthGenerator's depth-2 layout.
const LAYOUT_DEPTH2_PATH := "res://game/content/layouts/archive_roundabout.tres"
## THE TERMINAL'S FIXTURE -- FIRST RECORDED 2026-10-12. A new baseline for new content: it
## notices the Terminal changing from here on and says nothing about any earlier floor.
const FIXTURE_DEPTH3_PATH := "res://tests/fixtures/floor_plan_golden_depth3.json"
const GOLDEN_DEPTH3 := 3
## THE FIRST FOUNDRY FLOOR'S FIXTURE -- FIRST RECORDED 2026-10-13, as an unaccepted greybox. A new
## baseline for new content; it says nothing about any earlier floor.
const FIXTURE_DEPTH4_PATH := "res://tests/fixtures/floor_plan_golden_depth4.json"
const GOLDEN_DEPTH4 := 4


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


func test_the_golden_seed_still_produces_the_committed_second_floor() -> void:
	var committed: String = FileAccess.get_file_as_string(FIXTURE_DEPTH2_PATH)
	assert_false(committed.is_empty(), "the depth-2 fixture must exist -- record it with tools/record_floor_plan_golden.gd")

	var regenerated: String = JSON.stringify(DepthGenerator.generate(GOLDEN_SEED, GOLDEN_DEPTH2).to_dict(), "\t")
	assert_eq(regenerated, committed,
		"seed %d depth %d no longer produces the recorded floor. If generation changed ON PURPOSE, re-record the fixture and date the reason; otherwise this is the regression it exists to catch." % [GOLDEN_SEED, GOLDEN_DEPTH2])
	assert_ne(committed, FileAccess.get_file_as_string(FIXTURE_PATH), "the two floors must not share a fixture")


func test_the_golden_seed_still_produces_the_committed_terminal() -> void:
	var committed: String = FileAccess.get_file_as_string(FIXTURE_DEPTH3_PATH)
	assert_false(committed.is_empty(), "the depth-3 fixture must exist -- record it with tools/record_floor_plan_golden.gd")

	var regenerated: String = JSON.stringify(DepthGenerator.generate(GOLDEN_SEED, GOLDEN_DEPTH3).to_dict(), "	")
	assert_eq(regenerated, committed,
		"seed %d depth %d no longer produces the recorded floor. If generation changed ON PURPOSE, re-record the fixture and date the reason; otherwise this is the regression it exists to catch." % [GOLDEN_SEED, GOLDEN_DEPTH3])
	for other: String in [FIXTURE_PATH, FIXTURE_DEPTH2_PATH]:
		assert_ne(committed, FileAccess.get_file_as_string(other), "the Terminal must not share a fixture with %s" % other)


func test_the_golden_seed_still_produces_the_committed_foundry_floor() -> void:
	var committed: String = FileAccess.get_file_as_string(FIXTURE_DEPTH4_PATH)
	assert_false(committed.is_empty(), "the depth-4 fixture must exist -- record it with tools/record_floor_plan_golden.gd")

	var regenerated: String = JSON.stringify(DepthGenerator.generate(GOLDEN_SEED, GOLDEN_DEPTH4).to_dict(), "\t")
	assert_eq(regenerated, committed,
		"seed %d depth %d no longer produces the recorded floor. If generation changed ON PURPOSE, re-record the fixture and date the reason; otherwise this is the regression it exists to catch." % [GOLDEN_SEED, GOLDEN_DEPTH4])
	for other: String in [FIXTURE_PATH, FIXTURE_DEPTH2_PATH, FIXTURE_DEPTH3_PATH]:
		assert_ne(committed, FileAccess.get_file_as_string(other), "the Foundry must not share a fixture with %s" % other)


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
	assert_true(by_kind.has("encounter_cleared"), "and progression past the fight")
	assert_true(by_kind.has("group_occupancy"), "the commitment beat is a plate you stand on, not an E press")
	assert_false(by_kind.has("interacted"), "and no control anywhere on the floor asks for a press")

	# THE PARTY PLATE: its whole consequence in ONE record.
	var multi: int = 0
	for trigger in triggers:
		if (trigger["effects"] as Array).size() >= 3:
			multi += 1
	assert_gt(multi, 0, "one controller must own a multi-effect sequence atomically")

	# NO fight may start merely by entering a region -- the rule play falsified. A PARTY PLATE is
	# deliberately exempt and deliberately a DIFFERENT KIND: the falsified rule was geometry
	# implying combat ("you walked into the room, so fight"), while a plate is an authored object
	# you must deliberately stand on, with the whole party. Occupancy is the input either way;
	# what changed is that one is implied by a room and the other is authored as a thing.
	# REFINED 2026-09-01 alongside its sibling in test_depth_generator.gd: the exemption is not
	# "party plates only" but "anything the player can SEE and must deliberately stand on".
	# An INVISIBLE region trigger starting a fight is still the falsified rule and still banned.
	for trigger in triggers:
		if String(trigger["kind"]) != "region_entered" or bool(trigger["renders_as_plate"]):
			continue
		for effect in trigger["effects"]:
			assert_ne(String(effect["kind"]), "activate_encounter",
				"trigger %d starts a fight from an INVISIBLE region" % int(trigger["trigger_id"]))

	# --- ENCOUNTER + INTERACTION.
	var roles: Dictionary = {}
	for encounter in fixture["encounters"]:
		roles[String(encounter["role"])] = true
		for spawn in encounter["roster"]:
			var position := Vector2(float(spawn["position"]["x"]), float(spawn["position"]["z"]))
			assert_true(_walkable(fixture, position), "spawn at %s is off the floor" % position)
			var owned: bool = false
			for region in encounter["regions"]:
				owned = owned or _rect(region).has_point(position)
			assert_true(owned, "spawn at %s is outside the site that owns it" % position)
	assert_true(roles.has("mandatory"), "one authored lock-in fight")
	assert_true(roles.has("ambient"), "and one inhabited territory")

	var dormant: int = 0
	for trigger in triggers:
		if not bool(trigger["starts_enabled"]):
			dormant += 1
	assert_eq(dormant, 1, "exactly one concealed progression control")
	assert_eq((fixture["breakables"] as Array).size(), 1, "concealed by exactly one prop")
	assert_eq(int(fixture["breakables"][0]["conceals_trigger_id"]),
		int(_first_dormant(fixture)["trigger_id"]), "and the prop must conceal THAT control")

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


func _first_dormant(fixture: Dictionary) -> Dictionary:
	for trigger in fixture["triggers"]:
		if not bool(trigger["starts_enabled"]):
			return trigger
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


# --- FLOOR 2: THE FIXTURE AGAINST THE ACCEPTED CONTENT -----------------------------------------
#
# The byte test above only says the generator still agrees with the fixture. This says the
# fixture agrees with the AUTHORED FLOOR -- read straight from the .tres, going through neither
# LayoutCompiler nor to_dict(), so a serializer that dropped or mangled a layer cannot vouch for
# itself. Scope is completeness and content preservation only: it asserts no rule about what a
# floor ought to contain.

func test_the_second_floor_fixture_preserves_the_authored_content() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_DEPTH2_PATH))
	var layout: AuthoredLayout = load(LAYOUT_DEPTH2_PATH)

	for layer: String in ["patches", "connections", "triggers", "encounters", "breakables",
			"hit_switches", "obstacles", "spike_pads"]:
		assert_gt((layout.get(layer) as Array).size(), 0, "Floor 2 authors %s" % layer)
		assert_eq((fixture[layer] as Array).size(), (layout.get(layer) as Array).size(),
			"the fixture must carry every authored record in %s" % layer)

	for obstacle: ObstaclePlan in layout.obstacles:
		var recorded: Dictionary = _by_id(fixture["obstacles"], "obstacle_id", obstacle.obstacle_id)
		assert_true(_same_rect(recorded["rect"], obstacle.rect), "obstacle %d footprint" % obstacle.obstacle_id)
		assert_almost_eq(float(recorded["height"]), obstacle.height, 0.0001, "obstacle %d height" % obstacle.obstacle_id)

	for pad: SpikePadPlan in layout.spike_pads:
		var recorded: Dictionary = _by_id(fixture["spike_pads"], "pad_id", pad.pad_id)
		assert_true(_same_rect(recorded["rect"], pad.rect), "pad %d footprint" % pad.pad_id)
		assert_eq(int(recorded["safe_ticks"]), pad.safe_ticks, "pad %d safe window" % pad.pad_id)
		assert_eq(int(recorded["active_ticks"]), pad.active_ticks, "pad %d active window" % pad.pad_id)
		assert_eq(int(recorded["phase_offset_ticks"]), pad.phase_offset_ticks, "pad %d phase" % pad.pad_id)
		assert_almost_eq(float(recorded["damage"]), pad.damage, 0.0001, "pad %d damage" % pad.pad_id)
		assert_eq(String(recorded["damage_type"]), String(pad.damage_type), "pad %d damage type" % pad.pad_id)
		assert_eq(_strings(recorded["eligible_allegiances"]), _strings(pad.eligible_allegiances), "pad %d eligibility" % pad.pad_id)

	for hit_switch: HitSwitchPlan in layout.hit_switches:
		var recorded: Dictionary = _by_id(fixture["hit_switches"], "switch_id", hit_switch.switch_id)
		assert_true(_same_point(recorded["position"], hit_switch.position), "switch %d position" % hit_switch.switch_id)
		assert_almost_eq(float(recorded["radius"]), hit_switch.radius, 0.0001, "switch %d radius" % hit_switch.switch_id)
		assert_eq(String(recorded["mode"]), String(hit_switch.mode), "switch %d mode" % hit_switch.switch_id)
		assert_eq(bool(recorded["starts_hidden"]), hit_switch.starts_hidden, "switch %d concealment" % hit_switch.switch_id)
		assert_eq(_recorded_effects(recorded["effects"]), _authored_effects(layout, hit_switch.effects),
			"switch %d effects" % hit_switch.switch_id)

	for connection: TraversalConnection in layout.connections:
		var recorded: Dictionary = _by_id(fixture["connections"], "connection_id", connection.connection_id)
		assert_eq(String(recorded["flank_style"]), String(connection.flank_style), "connection %d flank" % connection.connection_id)
		assert_true(_same_rect(recorded["aperture"], connection.aperture), "connection %d aperture" % connection.connection_id)
		assert_eq(bool(recorded["starts_open"]), connection.starts_open, "connection %d initial state" % connection.connection_id)

	for breakable: BreakablePlan in layout.breakables:
		var recorded: Dictionary = _by_id(fixture["breakables"], "breakable_id", breakable.breakable_id)
		assert_true(_same_point(recorded["position"], breakable.position), "breakable %d position" % breakable.breakable_id)
		assert_true(_same_rect(recorded["blocking_rect"], breakable.blocking_rect), "breakable %d blocking rect" % breakable.breakable_id)

	for trigger: FloorTrigger in layout.triggers:
		var recorded: Dictionary = _by_id(fixture["triggers"], "trigger_id", trigger.trigger_id)
		assert_eq(String(recorded["kind"]), String(trigger.kind), "trigger %d kind" % trigger.trigger_id)
		assert_eq(bool(recorded["starts_enabled"]), trigger.starts_enabled, "trigger %d enabled" % trigger.trigger_id)
		assert_eq(_recorded_effects(recorded["effects"]), _authored_effects(layout, trigger.effects),
			"trigger %d effects" % trigger.trigger_id)

	for site: EncounterSite in layout.encounters:
		var recorded: Dictionary = _by_id(fixture["encounters"], "encounter_id", site.encounter_id)
		assert_eq(String(recorded["role"]), String(site.role), "encounter %d role" % site.encounter_id)
		assert_eq((recorded["regions"] as Array).size(), site.regions.size(), "encounter %d territory" % site.encounter_id)
		var recorded_roster: Array = []
		for spawn: Dictionary in recorded["roster"]:
			recorded_roster.append(String(spawn["enemy_key"]))
		var authored_roster: Array = []
		for spawn: Dictionary in site.roster:
			authored_roster.append(String(spawn["enemy_key"]))
		assert_eq(recorded_roster, authored_roster, "encounter %d roster" % site.encounter_id)

	assert_true(_same_point(fixture["entry_point"], layout.entry_point), "entry point")
	assert_true(_same_point(fixture["end_marker"], layout.end_marker), "end marker")


## to_dict() snaps to 4 decimals, so the fixture may sit up to half a step from the authored value.
func _same_rect(recorded: Dictionary, authored: Rect2) -> bool:
	return (absf(float(recorded["x"]) - authored.position.x) <= 0.0001
		and absf(float(recorded["z"]) - authored.position.y) <= 0.0001
		and absf(float(recorded["w"]) - authored.size.x) <= 0.0001
		and absf(float(recorded["d"]) - authored.size.y) <= 0.0001)


func _same_point(recorded: Dictionary, authored: Vector3) -> bool:
	return (absf(float(recorded["x"]) - authored.x) <= 0.0001
		and absf(float(recorded["y"]) - authored.y) <= 0.0001
		and absf(float(recorded["z"]) - authored.z) <= 0.0001)


func _strings(values: Array) -> Array:
	var out: Array = []
	for value: Variant in values:
		out.append(String(value))
	return out


func _recorded_effects(effects: Array) -> Array:
	var out: Array = []
	for effect: Dictionary in effects:
		out.append("%s -> %d" % [effect["kind"], int(effect["target_id"])])
	return out


## Content names its targets by key; the fixture holds the resolved numeric id. Keys are unique
## across a layout, so the layout itself can say which id a key means.
func _authored_effects(layout: AuthoredLayout, effects: Array) -> Array:
	var out: Array = []
	for effect: Dictionary in effects:
		var key: StringName = effect.get("target_key", &"")
		var target: int = layout.id_for(key) if key != &"" else int(effect.get("target_id", -1))
		out.append("%s -> %d" % [effect["kind"], target])
	return out
