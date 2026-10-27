extends GutTest
## SPAWN SAFETY (ADR-001 S2.5). The human's finding on the S2 prototype -- "activating the plate
## makes enemies appear directly on top of the player" -- becomes a derived, content-driven rule:
## no activation spawn inside its own ARRIVAL REACH of the plate. The rule is calibrated here
## against the shipped floors the human accepted (all pass) and the exit gallery the human
## rejected (fails), so it discriminates exactly the judgement it encodes.

const LAYOUTS := ["archive_prototype", "archive_roundabout", "foundry_assembly", "terminal"]
const PIECES_DIR := "res://game/content/floors/pieces/"
const RECIPES := ["proto_archive", "proto_archive_dogleg", "proto_archive_fold"]
const SWEEP: int = 20
const DEPTH: int = 1


func _envoy() -> EnvoyStats:
	return ContentDB.get_resource(&"envoy", &"default")


func _ticks_per_second() -> float:
	return float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))


func _shortest_windup(stats: Resource) -> int:
	var windup: int = -1
	for action_id: StringName in stats.action_ids:
		var weapon: Resource = load("res://game/content/enemies/natural_weapons/%s.tres" % action_id)
		if windup < 0 or weapon.windup_ticks < windup:
			windup = weapon.windup_ticks
	return maxi(windup, 0)


func _reach(key: StringName) -> float:
	var envoy: EnvoyStats = _envoy()
	var stats: Resource = ContentDB.get_resource(&"enemy", key)
	return EncounterSpacing.arrival_reach(envoy.combat_radius, stats.combat_radius, stats.preferred_attack_distance, stats.move_speed, _shortest_windup(stats), envoy.spawn_reaction_ticks, _ticks_per_second())


func _reaches() -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in [&"fang", &"ooze", &"watcher"]:
		out[key] = _reach(key)
	return out


func _piece(piece_id: String) -> FloorPiece:
	return load(PIECES_DIR + piece_id + ".tres")


func _layout(layout_id: String) -> AuthoredLayout:
	return load("res://game/content/layouts/%s.tres" % layout_id)


# --- the rule ----------------------------------------------------------------------------------

## MEASURED CALIBRATION (2026-10-23), from the shipped stats: the fang closes fastest but strikes
## shortest, the ooze is slow but wide-bodied with a long slam. A mutant dropping any term of the
## reach moves every one of these.
func test_arrival_reach_is_derived_from_the_roster_stats_not_chosen() -> void:
	assert_almost_eq(_reach(&"fang"), 5.7, 0.01, "0.45 + 0.9 + 1.65 + 3.0 x (12 + 15) / 30")
	assert_almost_eq(_reach(&"ooze"), 6.35, 0.01, "0.45 + 1.45 + 2.2 + 1.5 x (30 + 15) / 30")
	assert_almost_eq(_reach(&"watcher"), 5.633, 0.01, "0.45 + 0.85 + 2.0 + 2.0 x (20 + 15) / 30; the pulse is its shortest windup")
	var envoy: EnvoyStats = _envoy()
	var fang: Resource = ContentDB.get_resource(&"enemy", &"fang")
	var faster: float = EncounterSpacing.arrival_reach(envoy.combat_radius, fang.combat_radius, fang.preferred_attack_distance, fang.move_speed * 2.0, _shortest_windup(fang), envoy.spawn_reaction_ticks, _ticks_per_second())
	assert_gt(faster, _reach(&"fang"), "a faster enemy reaches farther in the same allowance")
	var patient: float = EncounterSpacing.arrival_reach(envoy.combat_radius, fang.combat_radius, fang.preferred_attack_distance, fang.move_speed, _shortest_windup(fang), envoy.spawn_reaction_ticks * 2, _ticks_per_second())
	assert_gt(patient, _reach(&"fang"), "a longer reaction allowance demands more room")


## The player is taken to stand at the region's centre when it fires: exact for a plate, a median
## estimate for a threshold zone. (Nearest-point was tried and rejected by the calibration below:
## three shipped threshold rooms author their rosters inside the zone that wakes them.)
func test_the_activation_point_is_the_centre_of_the_region() -> void:
	assert_eq(EncounterSpacing.activation_point(Rect2(-1, -5, 2, 2)), Vector2(0, -4), "a 2x2 plate")
	assert_eq(EncounterSpacing.activation_point(Rect2(-12, -96, 10, 16)), Vector2(-7, -88), "a threshold zone")


func test_a_roster_member_whose_reach_was_not_supplied_is_reported_not_assumed_safe() -> void:
	var findings: Array[Dictionary] = EncounterSpacing.findings(_piece("archive_encounter_pit").body, {})
	assert_eq(findings.size(), 3, "three roster members, no reaches")
	for finding: Dictionary in findings:
		assert_eq(finding["rule"], EncounterSpacing.RULE_REACH_UNKNOWN)


# --- calibration against human judgement --------------------------------------------------------

## CALIBRATION, not a claim about those floors: the rule must agree with the judgement it encodes.
## The tightest accepted room is the Roundabout's E_POCKET ambush (a fang 5.83 from the zone's
## centre against a reach of 5.7), so the reaction allowance in EnvoyStats cannot grow by more
## than a tick without this test saying which shipped room it now contradicts.
func test_every_shipped_activated_encounter_passes() -> void:
	var reaches: Dictionary = _reaches()
	for layout_id: String in LAYOUTS:
		assert_eq(EncounterSpacing.findings(_layout(layout_id), reaches), [] as Array[Dictionary], layout_id)


## The S2 exit gallery (kept on disk as the S1 baseline fixture, no longer in any recipe) is the
## piece the human rejected: both guards wake within 2.2 of the plate.
func test_the_rejected_exit_gallery_fails_and_the_corrected_pit_passes() -> void:
	var reaches: Dictionary = _reaches()
	var gallery: Array[Dictionary] = EncounterSpacing.findings(_piece("archive_exit_gallery").body, reaches)
	assert_eq(gallery.size(), 2, "the fang and the ooze")
	for finding: Dictionary in gallery:
		assert_eq(finding["rule"], EncounterSpacing.RULE_SPAWN_WITHIN_REACH)
		assert_lt(float(finding["refs"]["distance"]), 2.5, finding["message"])
		assert_gt(float(finding["refs"]["required"]), 5.0, finding["message"])
	assert_eq(EncounterSpacing.findings(_piece("archive_encounter_pit").body, reaches), [] as Array[Dictionary], "the resized pit")
	assert_eq(EncounterSpacing.findings(_piece("archive_exit_landing").body, reaches), [] as Array[Dictionary], "the landing wakes nothing")


func test_every_piece_in_every_recipe_pool_spawns_safely() -> void:
	var reaches: Dictionary = _reaches()
	for recipe_id: String in RECIPES:
		var recipe: FloorRecipe = load("res://game/content/floors/recipes/%s.tres" % recipe_id)
		for piece: FloorPiece in recipe.pieces:
			assert_eq(EncounterSpacing.findings(piece.body, reaches), [] as Array[Dictionary], "%s: %s" % [recipe_id, piece.piece_id])
			assert_ne(piece.piece_id, &"archive_exit_gallery", "%s: the rejected gallery is not a destination" % recipe_id)


## Composed floors are the pieces translated and possibly mirrored; the rule holds in world
## coordinates for both recipes, including on mirrored instances.
func test_composed_floors_of_both_recipes_spawn_safely() -> void:
	var reaches: Dictionary = _reaches()
	for recipe_id: String in RECIPES:
		var recipe: FloorRecipe = load("res://game/content/floors/recipes/%s.tres" % recipe_id)
		var judged: int = 0
		for run_seed in SWEEP:
			var result: FloorComposer.ComposeResult = FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH)
			if result.report.fallback:
				continue
			judged += 1
			assert_eq(EncounterSpacing.findings(result.layout, reaches), [] as Array[Dictionary], "%s seed %d" % [recipe_id, run_seed])
		assert_gt(judged, 0, "%s composed something to judge" % recipe_id)


# --- in the composer (S3b) -----------------------------------------------------------------------

## A recipe whose destination is the rejected S2 gallery: its guards wake 2.0 and 2.2 from the plate.
func _gallery_recipe() -> FloorRecipe:
	var recipe := FloorRecipe.new()
	recipe.recipe_id = &"fixture_unsafe_gallery"
	recipe.stratum = load("res://game/content/strata/archive.tres")
	recipe.fallback = load("res://game/content/layouts/archive_prototype.tres")
	recipe.pieces = [_piece("archive_entry_hall"), _piece("archive_exit_gallery")] as Array[FloorPiece]
	recipe.profiles = [load("res://game/content/floors/profiles/approach.tres")] as Array[TraversalProfile]
	recipe.nodes = [{"key": &"entry", "role": &"entry"}, {"key": &"exit", "role": &"exit"}] as Array[Dictionary]
	recipe.edges = [{"from": &"entry", "from_port": &"out", "to": &"exit", "to_port": &"in", "profile": &"approach"}] as Array[Dictionary]
	return recipe


## SPACING IS A COMPOSITION REJECTION when the reaches are supplied: the same seed composes without
## them and falls back with them, naming the rule; never silently "fixed".
func test_the_composer_rejects_a_floor_whose_plate_wakes_a_roster_inside_its_reach() -> void:
	var recipe: FloorRecipe = _gallery_recipe()
	assert_eq(recipe.lint(), [] as Array[Dictionary])
	var unjudged: FloorComposer.ComposeResult = FloorComposer.compose(recipe, SeedMix.derive(1, DEPTH), DEPTH)
	assert_true(unjudged.report.succeeded(), "without reaches the composer does not judge spawns: " + unjudged.report.summary())
	var judged: FloorComposer.ComposeResult = FloorComposer.compose(recipe, SeedMix.derive(1, DEPTH), DEPTH, {}, _reaches())
	assert_true(judged.report.fallback, judged.report.summary())
	assert_eq(judged.report.failing_validator, "EncounterSpacing")
	assert_gt(int(judged.report.rejections.get(EncounterSpacing.RULE_SPAWN_WITHIN_REACH, 0)), 0, str(judged.report.rejections))
	assert_true(judged.report.log.size() > 0 and Array(judged.report.log).any(func(line: String) -> bool: return line.contains("spawns")), "the finding is in the log")


## Safe content is untouched by the rule: the fold composes the same floor with spacing in the loop.
func test_the_fold_composes_the_same_floors_with_spacing_in_the_loop() -> void:
	var recipe: FloorRecipe = load("res://game/content/floors/recipes/proto_archive_fold.tres")
	for run_seed in [1, 7, 42]:
		var plain: FloorComposer.ComposeResult = FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH)
		var judged: FloorComposer.ComposeResult = FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, {}, _reaches())
		assert_true(judged.report.succeeded(), judged.report.summary())
		assert_eq(judged.report.spatial_signature(), plain.report.spatial_signature(), "seed %d" % run_seed)


## WHAT THE RULE DOES NOT PROVE, pinned so it cannot be over-read: a wave woken by a CLEAR (not by a
## region) is not judged, however close it spawns -- later waves remain unproven.
func test_a_wave_woken_by_a_clear_is_not_judged_by_the_spacing_rule() -> void:
	var layout := AuthoredLayout.new()
	layout.layout_id = &"fixture_wave"
	var wave := EncounterSite.new()
	wave.key = &"E_WAVE_2"
	wave.encounter_id = 1
	wave.regions = [Rect2(-5, -5, 10, 10)] as Array[Rect2]
	wave.roster = [{"enemy_key": &"fang", "position": Vector3(0, 0, 0)}] as Array[Dictionary]
	layout.encounters = [wave] as Array[EncounterSite]
	var after_clear := FloorTrigger.new()
	after_clear.key = &"T_NEXT_WAVE"
	after_clear.trigger_id = 0
	after_clear.kind = FloorLayers.TRIGGER_ENCOUNTER_CLEARED
	after_clear.source_id = 0
	after_clear.effects = [{"kind": FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, "target_key": &"E_WAVE_2"}] as Array[Dictionary]
	layout.triggers = [after_clear] as Array[FloorTrigger]
	assert_eq(EncounterSpacing.findings(layout, _reaches()), [] as Array[Dictionary], "not judged -- which is a limitation, not a pass")


## THE TOOLS JUDGE BY THE SAME NUMBERS: the sweep and the debug playground derive reaches by path
## (tools/spawn_reaches.gd), the tests through ContentDB -- two derivations, one answer.
func test_the_tools_derive_the_same_reaches_the_tests_do() -> void:
	var tools: Dictionary = preload("res://tools/spawn_reaches.gd").for_keys([&"fang", &"ooze", &"watcher"])
	var ours: Dictionary = _reaches()
	assert_eq(tools.keys().size(), 3)
	for key: StringName in ours:
		assert_almost_eq(float(tools[key]), float(ours[key]), 0.0001, String(key))
