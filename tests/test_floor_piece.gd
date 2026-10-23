extends GutTest
## A FloorPiece IS LINTABLE ON ITS OWN (ADR-001 S1, owner correction 1): the structural questions
## a piece can answer about itself -- body inside footprint, ports on the edge, references inside
## the body, ids real and unique, transforms the emitter supports -- are answered here, as
## findings, with nothing compiled. Whole-floor rules stay whole-floor rules.

const ENTRY := "res://game/content/floors/pieces/archive_entry_apron.tres"
const EXIT := "res://game/content/floors/pieces/archive_exit_gallery.tres"
const SHIPPED: Array[String] = [ENTRY, EXIT]


func _stratum_pool() -> Array[StringName]:
	var stratum: StratumConfig = ContentDB.get_resource(&"stratum", &"archive")
	return stratum.enemy_keys


func _rules_of(findings: Array[Dictionary]) -> Array:
	return findings.map(func(f: Dictionary) -> StringName: return f["rule"])


## The refs of the first finding of a rule. A missing finding fails an assertion that names
## what lint did report, never an index crash, so a dropped rule reads as the defect it is.
func _refs_of(findings: Array[Dictionary], rule: StringName) -> Dictionary:
	for finding: Dictionary in findings:
		if finding["rule"] == rule:
			return finding["refs"]
	assert_true(false, "expected a %s finding, got %s" % [rule, _rules_of(findings)])
	return {}


## A fresh, minimal piece every negative test starts from: one room flush with its north edge,
## one connector there. Built in code so a test mutates its own copy, never a shipped resource.
func _piece() -> FloorPiece:
	var piece := FloorPiece.new()
	piece.piece_id = &"fixture"
	piece.role = FloorPiece.ROLE_LANDMARK
	piece.footprint = Rect2(-8, -10, 16, 10)
	var body := AuthoredLayout.new()
	body.layout_id = &"fixture_body"
	var room := WalkablePatch.new()
	room.key = &"P_ROOM"
	room.patch_id = 0
	room.rect = Rect2(-6, -8, 12, 8)
	var patches: Array[WalkablePatch] = [room]
	body.patches = patches
	piece.body = body
	var port := PiecePort.new()
	port.key = &"in"
	port.kind = PiecePort.KIND_CONNECTOR
	port.edge = PiecePort.EDGE_NORTH
	port.offset = 5.5
	port.width = 5.0
	port.patch_key = &"P_ROOM"
	var ports: Array[PiecePort] = [port]
	piece.ports = ports
	return piece


func _trigger(key: StringName, id: int, effects: Array[Dictionary]) -> FloorTrigger:
	var trigger := FloorTrigger.new()
	trigger.key = key
	trigger.trigger_id = id
	trigger.region = Rect2(-1, -5, 2, 2)
	trigger.effects = effects
	return trigger


# --- the pieces that ship ------------------------------------------------------------------

func test_the_shipped_pieces_lint_clean_against_their_stratum() -> void:
	for path in SHIPPED:
		var piece: FloorPiece = load(path)
		assert_eq(piece.lint(_stratum_pool()), [] as Array[Dictionary], path)
		assert_true(piece.allows(FloorPiece.TRANSFORM_IDENTITY), "%s: identity is always allowed" % path)
	assert_push_error_count(0)


func test_the_shipped_pieces_declare_what_the_draft_needs() -> void:
	var entry: FloorPiece = load(ENTRY)
	var exit: FloorPiece = load(EXIT)
	assert_eq(entry.role, FloorPiece.ROLE_ENTRY)
	assert_eq(exit.role, FloorPiece.ROLE_EXIT)
	assert_eq(entry.port(&"out").kind, PiecePort.KIND_GATE, "the apron's door is a gate its own plate opens")
	assert_eq(exit.port(&"in").kind, PiecePort.KIND_CONNECTOR)
	assert_false(entry.allows(FloorPiece.TRANSFORM_MIRROR_X), "the apron did not opt in to mirroring")
	assert_true(exit.allows(FloorPiece.TRANSFORM_MIRROR_X), "the gallery did")
	# The one outward reference a piece may make: its own port.
	var hidden: FloorTrigger = entry.body.triggers[1]
	assert_eq(hidden.effects[0]["target_key"], &"@out")
	assert_eq(entry.body.breakables[0].conceals_trigger_id, hidden.trigger_id, "the crate hides the plate by NUMERIC id")


# --- geometry -------------------------------------------------------------------------------

func test_a_record_outside_the_footprint_is_a_finding() -> void:
	var piece: FloorPiece = _piece()
	var mass := ObstaclePlan.new()
	mass.key = &"O_OUT"
	mass.obstacle_id = 0
	mass.rect = Rect2(7, -5, 2, 2)  # x reaches 9; the footprint ends at 8
	var obstacles: Array[ObstaclePlan] = [mass]
	piece.body.obstacles = obstacles
	var findings: Array[Dictionary] = piece.lint()
	assert_eq(_rules_of(findings), [&"body_outside_footprint"])
	assert_eq(_refs_of(findings, &"body_outside_footprint"), {"layer": &"obstacle", "key": &"O_OUT"})


func test_a_port_must_lie_within_its_edge() -> void:
	var piece: FloorPiece = _piece()
	piece.port(&"in").offset = 12.0  # 12 + 5 > the 16-wide north edge
	assert_eq(_rules_of(piece.lint()), [&"port_off_edge"])
	piece.port(&"in").offset = 5.5
	piece.port(&"in").width = 0.0
	assert_eq(_rules_of(piece.lint()), [&"port_off_edge"])


func test_a_port_patch_must_reach_the_edge_across_the_span() -> void:
	var piece: FloorPiece = _piece()
	piece.body.patches[0].rect = Rect2(-6, -8, 12, 7)  # ends at z = -1, a unit short of the edge
	assert_eq(_rules_of(piece.lint()), [&"port_patch_not_on_edge"])
	piece.body.patches[0].rect = Rect2(0, -8, 6, 8)  # flush, but covers only [0, 6] of the span [-2.5, 2.5]
	assert_eq(_rules_of(piece.lint()), [&"port_patch_not_on_edge"])
	piece.port(&"in").patch_key = &"P_NOWHERE"
	assert_eq(_rules_of(piece.lint()), [&"port_patch_missing"])


func test_port_spans_follow_the_edge_naming_law() -> void:
	var piece: FloorPiece = _piece()
	var port: PiecePort = piece.port(&"in")
	assert_eq(piece.local_port_span(port), {"at": 0.0, "from": -2.5, "to": 2.5, "outward": 1.0}, "north = max z")
	port.edge = PiecePort.EDGE_WEST
	port.offset = 1.0
	port.width = 3.0
	assert_eq(piece.local_port_span(port), {"at": -8.0, "from": -9.0, "to": -6.0, "outward": -1.0}, "west = min x, offset from z-min")


# --- references ------------------------------------------------------------------------------

func test_a_reference_to_a_record_the_piece_does_not_contain_is_a_finding() -> void:
	var piece: FloorPiece = _piece()
	var triggers: Array[FloorTrigger] = [_trigger(&"T_A", 0, [{"kind": FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, "target_key": &"E_ELSEWHERE"}])]
	piece.body.triggers = triggers
	var findings: Array[Dictionary] = piece.lint()
	assert_eq(_rules_of(findings), [&"unresolved_reference"])
	assert_eq(_refs_of(findings, &"unresolved_reference").get("reference"), &"E_ELSEWHERE")


func test_a_reference_to_the_wrong_layer_is_a_finding() -> void:
	var piece: FloorPiece = _piece()
	var triggers: Array[FloorTrigger] = [_trigger(&"T_A", 0, [{"kind": FloorLayers.EFFECT_OPEN_CONNECTION, "target_key": &"P_ROOM"}])]
	piece.body.triggers = triggers
	assert_eq(_rules_of(piece.lint()), [&"unresolved_reference"], "a real patch is not a connection")


func test_a_port_reference_must_name_a_joinable_port_from_a_connection_effect() -> void:
	var piece: FloorPiece = _piece()
	var triggers: Array[FloorTrigger] = [_trigger(&"T_A", 0, [{"kind": FloorLayers.EFFECT_OPEN_CONNECTION, "target_key": &"@side"}])]
	piece.body.triggers = triggers
	assert_eq(_rules_of(piece.lint()), [&"port_reference_unknown"])
	triggers[0].effects = [{"kind": FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, "target_key": &"@in"}] as Array[Dictionary]
	assert_eq(_rules_of(piece.lint()), [&"port_reference_misused"], "only a connection effect can target a joint")
	triggers[0].effects = [{"kind": FloorLayers.EFFECT_OPEN_CONNECTION, "target_key": &"@in"}] as Array[Dictionary]
	assert_eq(piece.lint(), [] as Array[Dictionary])


func test_a_sentinel_effect_may_not_name_a_target_and_an_unknown_kind_is_a_finding() -> void:
	var piece: FloorPiece = _piece()
	var triggers: Array[FloorTrigger] = [_trigger(&"T_A", 0, [{"kind": FloorLayers.EFFECT_COMPLETE_FLOOR, "target_id": 3}])]
	piece.body.triggers = triggers
	assert_has(_rules_of(piece.lint()), &"reference_without_layer")
	triggers[0].effects = [{"kind": &"summon_dragon", "target_id": -1}] as Array[Dictionary]
	assert_eq(_rules_of(piece.lint()), [&"unknown_effect_kind"])


func test_a_watching_trigger_without_a_source_is_a_finding() -> void:
	var piece: FloorPiece = _piece()
	var watcher: FloorTrigger = _trigger(&"T_W", 0, [])
	watcher.kind = FloorLayers.TRIGGER_BREAKABLE_DESTROYED
	var triggers: Array[FloorTrigger] = [watcher]
	piece.body.triggers = triggers
	assert_eq(_rules_of(piece.lint()), [&"unresolved_reference"], "a breakable_destroyed trigger watches a breakable, and names none")


func test_an_unlock_port_names_one_real_record() -> void:
	var piece: FloorPiece = _piece()
	var unlock := PiecePort.new()
	unlock.key = &"unlock"
	unlock.kind = PiecePort.KIND_UNLOCK
	unlock.trigger_key = &"T_MISSING"
	piece.ports.append(unlock)
	assert_eq(_rules_of(piece.lint()), [&"port_target_missing"])
	var triggers: Array[FloorTrigger] = [_trigger(&"T_MISSING", 0, [])]
	piece.body.triggers = triggers
	assert_eq(piece.lint(), [] as Array[Dictionary])


# --- identities -----------------------------------------------------------------------------

func test_ids_must_be_real_and_unique_within_a_layer() -> void:
	var piece: FloorPiece = _piece()
	var triggers: Array[FloorTrigger] = [_trigger(&"T_A", 0, []), _trigger(&"T_B", 0, []), _trigger(&"T_C", -1, [])]
	piece.body.triggers = triggers
	var rules: Array = _rules_of(piece.lint())
	assert_has(rules, &"duplicate_local_id")
	assert_has(rules, &"unset_id")
	assert_eq(rules.size(), 2)


func test_a_duplicate_key_is_a_finding() -> void:
	var piece: FloorPiece = _piece()
	var twin := WalkablePatch.new()
	twin.key = &"P_ROOM"
	twin.patch_id = 1
	twin.rect = Rect2(-6, -8, 12, 8)
	piece.body.patches.append(twin)
	assert_eq(_rules_of(piece.lint()), [&"duplicate_key"])


# --- role, transforms, stratum --------------------------------------------------------------

func test_only_an_exit_piece_completes_a_floor_and_an_exit_piece_must() -> void:
	var piece: FloorPiece = _piece()
	var triggers: Array[FloorTrigger] = [_trigger(&"T_END", 0, [FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, FloorLayers.NO_TARGET)])]
	piece.body.triggers = triggers
	assert_eq(_rules_of(piece.lint()), [&"completion_outside_exit"])
	piece.role = FloorPiece.ROLE_EXIT
	piece.body.end_marker = Vector3(0, 0, -6)
	piece.body.exit_console = Vector3(3, 0, -6)
	assert_eq(piece.lint(), [] as Array[Dictionary])
	piece.body.triggers = [] as Array[FloorTrigger]
	assert_eq(_rules_of(piece.lint()), [&"exit_without_completion"])


func test_an_entry_piece_arrives_inside_itself() -> void:
	var piece: FloorPiece = _piece()
	piece.role = FloorPiece.ROLE_ENTRY
	piece.body.entry_point = Vector3(0, 0, 5)  # beyond the north edge
	var findings: Array[Dictionary] = piece.lint()
	assert_eq(_rules_of(findings), [&"body_outside_footprint"])
	assert_eq(_refs_of(findings, &"body_outside_footprint").get("key"), &"entry_point")


func test_transforms_are_identity_plus_an_explicit_opt_in() -> void:
	var piece: FloorPiece = _piece()
	piece.allowed_transforms = [FloorPiece.TRANSFORM_MIRROR_X] as Array[StringName]
	assert_eq(_rules_of(piece.lint()), [&"identity_required"])
	piece.allowed_transforms = [FloorPiece.TRANSFORM_IDENTITY, &"rotate_90"] as Array[StringName]
	assert_eq(_rules_of(piece.lint()), [&"transform_unsupported"], "rotation is deferred (ADR-001 §8); the emitter must not be asked for it")


func test_a_roster_outside_the_stratum_pool_is_a_finding_only_when_the_pool_is_given() -> void:
	var piece: FloorPiece = _piece()
	var site := EncounterSite.new()
	site.key = &"E_X"
	site.encounter_id = 0
	site.regions = [Rect2(-6, -8, 12, 8)] as Array[Rect2]
	site.roster = [{"enemy_key": &"dread", "position": Vector3(0, 0, -4)}] as Array[Dictionary]
	piece.body.encounters.append(site)
	assert_eq(piece.lint(), [] as Array[Dictionary], "no pool supplied: the rule does not run")
	var findings: Array[Dictionary] = piece.lint(_stratum_pool())
	assert_eq(_rules_of(findings), [&"roster_outside_stratum"])
	assert_eq(_refs_of(findings, &"roster_outside_stratum"), {"encounter": &"E_X", "enemy_key": &"dread"})
