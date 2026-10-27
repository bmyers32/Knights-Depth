extends GutTest
## OBJECTIVE INTEGRITY (ADR-001 S3b): a declared outcome is REQUIRED when no route to the goal
## survives it being withheld -- asked of the search by forbidding the action, never by deleting a
## record from the floor. Three verdicts, never blurred: ROUTE_NONE (exhaustive), ROUTE_FOUND (with
## the route), UNSUPPORTED (budget, or a route only a relaxed model finds). Solvability is the
## separate ProgressionValidator.check, read alongside.
##
##   1. the query itself, on small hand-built floors
##   2. the opt-in voluntary set-down, which finds a stranding the default model cannot see
##   3. the fold: every declaration holds, and each withheld beat leaves no route
##   4. declarations: optional content is independent, ambient rosters are not promoted, and a
##      wrong declaration is caught with the route that contradicts it

const FOLD_PATH := "res://game/content/floors/recipes/proto_archive_fold.tres"
const PIECES := "res://game/content/floors/pieces/"
const PROFILES := "res://game/content/floors/profiles/"
const DEPTH: int = 1
const RouteMetrics := preload("res://tools/route_metrics.gd")

const NONE := ProgressionValidator.ObjectiveResult.ROUTE_NONE
const FOUND := ProgressionValidator.ObjectiveResult.ROUTE_FOUND
const UNSUPPORTED := ProgressionValidator.ObjectiveResult.UNSUPPORTED


func _rules(set_down_anywhere: bool = false) -> Dictionary:
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_A")
	return {"body_radius": envoy.combat_radius, "attack_reach": sword.reach, "pickup_reach": envoy.pickup_reach,
		"set_down_anywhere": set_down_anywhere}


func _radii(recipe: FloorRecipe) -> Dictionary:
	var radii: Dictionary = {}
	for key: StringName in recipe.stratum.enemy_keys:
		radii[key] = ContentDB.get_resource(&"enemy", key).combat_radius
	return radii


func _compiled(layout: AuthoredLayout) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.stratum_id = layout.stratum_id
	LayoutCompiler.compile(layout, plan)
	return plan


func _compose(recipe: FloorRecipe, run_seed: int) -> FloorComposer.ComposeResult:
	return FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, _radii(recipe))


# --- 1. THE QUERY ------------------------------------------------------------------------------

func _patch(plan: FloorPlan, patch_id: int, rect: Rect2) -> void:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	plan.patches.append(patch)


func _connect(plan: FloorPlan, connection_id: int, near_id: int, far_id: int, aperture: Rect2, starts_open: bool) -> void:
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = aperture
	connection.starts_open = starts_open
	plan.connections.append(connection)


func _trigger(plan: FloorPlan, trigger_id: int, kind: StringName, region: Rect2, effects: Array[Dictionary], source_id: int = -1) -> void:
	var trigger := FloorTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.kind = kind
	trigger.region = region
	trigger.source_id = source_id
	trigger.effects = effects
	plan.triggers.append(trigger)


func _key(plan: FloorPlan, carriable_id: int, at: Vector3) -> void:
	var key := CarriablePlan.new()
	key.carriable_id = carriable_id
	key.position = at
	plan.carriables.append(key)


## Three rooms north to south, A (arrival, z 0..10), B (z -12..-2), C (z -24..-14). B holds a
## sealing fight on a plate, its far door to C opens on the clear; C holds a key; A's south door
## to B is open, and the exit stands back in A behind a door the key opens.
func _fight_then_key_floor() -> FloorPlan:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_patch(plan, 1, Rect2(-5, -12, 10, 10))
	_patch(plan, 2, Rect2(-5, -24, 10, 10))
	_patch(plan, 3, Rect2(8, 0, 6, 10))
	_connect(plan, 0, 0, 1, Rect2(-2, -3, 4, 4), true)
	_connect(plan, 1, 1, 2, Rect2(-2, -15, 4, 4), false)
	_connect(plan, 2, 0, 3, Rect2(4, 3, 5, 4), false)
	var fight := EncounterSite.new()
	fight.encounter_id = 0
	fight.regions = [Rect2(-5, -12, 10, 10)] as Array[Rect2]
	fight.role = FloorLayers.ROLE_MANDATORY
	fight.confines_player = true
	plan.encounters.append(fight)
	_trigger(plan, 0, FloorLayers.TRIGGER_REGION, Rect2(-5, -6, 10, 2), [FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, 0)])
	_trigger(plan, 1, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, Rect2(), [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 1)], 0)
	_key(plan, 0, Vector3(0, 0, -20))
	_trigger(plan, 2, FloorLayers.TRIGGER_CARRIABLE_INSERTED, Rect2(2, 3, 3, 4), [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 2)])
	_trigger(plan, 9, FloorLayers.TRIGGER_GROUP_OCCUPANCY, Rect2(10, 4, 2, 2), [FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, FloorLayers.NO_TARGET)])
	return plan


func test_a_withheld_beat_leaves_no_route_and_the_unconstrained_floor_still_has_one() -> void:
	var plan: FloorPlan = _fight_then_key_floor()
	assert_eq(plan.violations(), [] as Array[Dictionary], "a sane fixture")
	assert_true(ProgressionValidator.check(plan, _rules()).is_pass(), "solvable")
	var free: ProgressionValidator.ObjectiveResult = ProgressionValidator.check_objective(plan, _rules(), {})
	assert_eq(free.verdict, FOUND, free.summary())
	assert_eq(free.trace, ["enter trigger 0", "clear encounter 0", "lift carriable 0", "deliver carriable 0 to receiver 2", "enter trigger 9"] as Array[String])
	for forbidden: Dictionary in [{ProgressionValidator.FORBID_CLEAR: [0]}, {ProgressionValidator.FORBID_LIFT: [0]},
			{ProgressionValidator.FORBID_DELIVER: [2]}, {ProgressionValidator.FORBID_GROUND: [Rect2(-5, -24, 10, 10)]}]:
		var result: ProgressionValidator.ObjectiveResult = ProgressionValidator.check_objective(plan, _rules(), forbidden)
		assert_eq(result.verdict, NONE, result.summary())
		assert_eq(result.trace, [] as Array[String])


## A FORBIDDEN ACTION IS NOT A DELETED RECORD: the fight still seals the party when they step on its
## plate. With the clear withheld, the plate is a dead end -- and the key behind it is unreachable,
## asked directly as a goal.
func test_a_sealing_fight_never_won_holds_the_party_and_the_key_beyond_stays_out_of_reach() -> void:
	var plan: FloorPlan = _fight_then_key_floor()
	var lifted: ProgressionValidator.ObjectiveResult = ProgressionValidator.check_objective(plan, _rules(), {ProgressionValidator.FORBID_CLEAR: [0]}, {ProgressionValidator.GOAL_LIFT: 0})
	assert_eq(lifted.verdict, NONE, lifted.summary())
	var opened: ProgressionValidator.ObjectiveResult = ProgressionValidator.check_objective(plan, _rules(), {ProgressionValidator.FORBID_CLEAR: [0]}, {ProgressionValidator.GOAL_OPEN: 1})
	assert_eq(opened.verdict, NONE, "the fight's far door never opens without the clear")
	var control: ProgressionValidator.ObjectiveResult = ProgressionValidator.check_objective(plan, _rules(), {}, {ProgressionValidator.GOAL_LIFT: 0})
	assert_eq(control.verdict, FOUND, control.summary())
	assert_eq(plan.encounters.size(), 1, "nothing was deleted to ask the question")


## A BYPASS IS REPORTED WITH THE ROUTE THAT TAKES IT. Open a side door around the fight and the
## clear is no longer required: the answer is the route that walks round it.
func test_a_bypassable_beat_is_found_with_its_route() -> void:
	var plan: FloorPlan = _fight_then_key_floor()
	_patch(plan, 4, Rect2(-14, -24, 6, 34))
	_connect(plan, 3, 0, 4, Rect2(-9, 3, 5, 4), true)
	_connect(plan, 4, 4, 2, Rect2(-9, -22, 5, 4), true)
	var result: ProgressionValidator.ObjectiveResult = ProgressionValidator.check_objective(plan, _rules(), {ProgressionValidator.FORBID_CLEAR: [0]})
	assert_eq(result.verdict, FOUND, result.summary())
	assert_false(result.trace.has("clear encounter 0"), "the bypass never fights")
	assert_true(result.trace.has("lift carriable 0"), "it still carries the key: %s" % str(result.trace))


func test_a_search_that_runs_out_of_budget_is_unsupported_not_a_verdict() -> void:
	var rules: Dictionary = _rules()
	rules["max_states"] = 1
	var result: ProgressionValidator.ObjectiveResult = ProgressionValidator.check_objective(_fight_then_key_floor(), rules, {ProgressionValidator.FORBID_CLEAR: [0]})
	assert_eq(result.verdict, UNSUPPORTED)
	assert_true(result.reason.contains("exceeded"), result.reason)


## A route only a RELAXED model finds is not a proof either way: a switch out of melee reach that
## opens the only way round the fight.
func test_a_route_only_a_relaxation_finds_is_unsupported() -> void:
	var plan: FloorPlan = _fight_then_key_floor()
	_patch(plan, 4, Rect2(-14, -24, 6, 34))
	_connect(plan, 3, 0, 4, Rect2(-9, 3, 5, 4), false)
	_connect(plan, 4, 4, 2, Rect2(-9, -22, 5, 4), true)
	var lever := HitSwitchPlan.new()
	lever.switch_id = 0
	lever.position = Vector3(-30, 0, 5)  # far off the floor's ground: only a shot reaches it
	lever.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 3)] as Array[Dictionary]
	plan.hit_switches.append(lever)
	var result: ProgressionValidator.ObjectiveResult = ProgressionValidator.check_objective(plan, _rules(), {ProgressionValidator.FORBID_CLEAR: [0]})
	assert_eq(result.verdict, UNSUPPORTED, result.summary())
	assert_true(result.reason.contains("beyond melee reach"), result.reason)


# --- 2. VOLUNTARY SET-DOWN (B6) ----------------------------------------------------------------

## Lifting the key opens the way on; a one-way line in that way seals it behind the party. Carried
## through, the floor finishes. SET DOWN before the line, the key is stranded -- a state the default
## model never visits (keys fall only at attacks and fights), and the opt-in rule does.
func _lift_opens_a_one_way() -> FloorPlan:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_patch(plan, 1, Rect2(-5, -12, 10, 10))
	_patch(plan, 2, Rect2(-5, -24, 10, 10))
	_connect(plan, 0, 0, 1, Rect2(-2, -3, 4, 4), false)
	_connect(plan, 1, 1, 2, Rect2(-2, -15, 4, 4), false)
	_key(plan, 0, Vector3(3, 0, 5))
	_trigger(plan, 0, FloorLayers.TRIGGER_CARRIABLE_LIFTED, Rect2(), [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 0)], 0)
	_trigger(plan, 1, FloorLayers.TRIGGER_REGION, Rect2(-5, -8, 10, 2), [FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, 0)])
	_trigger(plan, 2, FloorLayers.TRIGGER_CARRIABLE_INSERTED, Rect2(-4, -12, 2, 2), [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 1)])
	_trigger(plan, 9, FloorLayers.TRIGGER_GROUP_OCCUPANCY, Rect2(-2, -24, 4, 2), [FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, FloorLayers.NO_TARGET)])
	return plan


func test_a_key_set_down_before_a_one_way_is_found_stranded_only_by_the_set_down_rule() -> void:
	var plan: FloorPlan = _lift_opens_a_one_way()
	assert_eq(plan.violations(), [] as Array[Dictionary])
	var default_model: ProgressionReport = ProgressionValidator.check(plan, _rules(false))
	assert_eq(default_model.outcome, ProgressionReport.OUTCOME_PASS, "the default model cannot see the stranding: " + default_model.summary())
	var anywhere: ProgressionReport = ProgressionValidator.check(plan, _rules(true))
	assert_eq(anywhere.outcome, ProgressionReport.OUTCOME_FAIL, anywhere.summary())
	var softlocks: Array[Dictionary] = anywhere.findings_of(&"softlock")
	assert_false(softlocks.is_empty(), "a softlock is reported")
	if not softlocks.is_empty():
		var how: Array = softlocks[0]["trace"]
		assert_true(how.has("set down carriable 0"), "the stranding route sets the key down: %s" % str(how))
		assert_true(how.find("set down carriable 0") < how.find("enter trigger 1"), "before crossing the line")
	assert_true(anywhere.limitations.any(func(line: String) -> bool: return line.contains("set down on any reachable ground")),
		"the coverage it claims is stated")


# --- 3. THE FOLD -------------------------------------------------------------------------------

func _fold() -> FloorRecipe:
	return load(FOLD_PATH)


func test_the_fold_declares_its_arena_vault_key_door_and_exit_mandatory_and_nothing_else() -> void:
	var declared: Dictionary = {}
	for node: Dictionary in _fold().nodes:
		declared[node["key"]] = node.get("progression", &"")
	assert_eq(declared, {&"entry": &"", &"landmark": &"mandatory", &"encounter": &"mandatory", &"objective": &"mandatory", &"exit": &"mandatory"})
	assert_eq(_fold().lint(), [] as Array[Dictionary])


## Every declaration holds on the composed floor, with the voluntary set-down in the model: ground
## of each mandatory piece, the arena's clear, the key's lift and the door's delivery are each
## required, and the floor is solvable with no softlock.
func test_every_fold_declaration_holds_with_keys_set_down_anywhere() -> void:
	var recipe: FloorRecipe = _fold()
	for run_seed in [1, 7, 42]:
		var composed: FloorComposer.ComposeResult = _compose(recipe, run_seed)
		assert_true(composed.report.succeeded(), composed.report.summary())
		if not composed.report.succeeded():
			continue
		var report: ObjectiveIntegrity.Report = ObjectiveIntegrity.check(recipe, composed, _compiled(composed.layout), _rules(true))
		assert_eq(report.outcome, ObjectiveIntegrity.OUTCOME_PASS, "seed %d: %s" % [run_seed, report.summary()])
		assert_true(report.baseline.is_pass(), "seed %d: solvable, no softlock: %s" % [run_seed, report.baseline.summary()])
		var asked: Array = report.claims.map(func(claim: ObjectiveIntegrity.Claim) -> String: return "%s/%s" % [claim.node, claim.kind])
		asked.sort()
		assert_eq(asked, ["encounter/clear", "encounter/ground", "exit/ground", "landmark/deliver", "landmark/ground", "objective/ground", "objective/lift"], "seed %d" % run_seed)
		for claim: ObjectiveIntegrity.Claim in report.claims:
			assert_eq(claim.result.verdict, NONE, "seed %d: %s" % [run_seed, claim.describe()])


func test_every_fold_floor_in_a_sweep_keeps_its_declarations() -> void:
	var recipe: FloorRecipe = _fold()
	for run_seed in 40:
		var composed: FloorComposer.ComposeResult = _compose(recipe, run_seed)
		if not composed.report.succeeded():
			fail_test("seed %d: %s" % [run_seed, composed.report.summary()])
			continue
		var report: ObjectiveIntegrity.Report = ObjectiveIntegrity.check(recipe, composed, _compiled(composed.layout), _rules(false))
		assert_eq(report.outcome, ObjectiveIntegrity.OUTCOME_PASS, "seed %d: %s" % [run_seed, report.summary()])


## The specific bypasses the slice must exclude, each asked as its own goal on one composed floor.
func test_no_fold_route_reaches_the_vault_the_key_door_or_the_exit_without_its_beat() -> void:
	var recipe: FloorRecipe = _fold()
	var composed: FloorComposer.ComposeResult = _compose(recipe, 7)
	var plan: FloorPlan = _compiled(composed.layout)
	var landmark: StringName = RouteMetrics.instance_of_node(recipe, composed, &"landmark")
	var vault: StringName = RouteMetrics.instance_of_node(recipe, composed, &"objective")
	var pit: StringName = RouteMetrics.instance_of_node(recipe, composed, &"encounter")
	var fight: int = composed.emit.global_id(pit, &"encounter", 0)
	var key: int = composed.emit.global_id(vault, &"carriable", 0)
	var receiver: int = composed.emit.global_id(landmark, &"trigger", 0)
	var vault_back: int = RouteMetrics.connection_of(composed, vault, &"back")
	var key_door: int = RouteMetrics.connection_of(composed, landmark, &"out")
	var session := ProgressionValidator.ObjectiveSession.new(plan, _rules(true))
	var cases: Array = [
		["the key is lifted without the clear", {ProgressionValidator.FORBID_CLEAR: [fight]}, {ProgressionValidator.GOAL_LIFT: key}],
		["the vault's back door opens without the clear (premature return access)", {ProgressionValidator.FORBID_CLEAR: [fight]}, {ProgressionValidator.GOAL_OPEN: vault_back}],
		["the key door opens without the key lifted", {ProgressionValidator.FORBID_LIFT: [key]}, {ProgressionValidator.GOAL_OPEN: key_door}],
		["the key door opens without delivery", {ProgressionValidator.FORBID_DELIVER: [receiver]}, {ProgressionValidator.GOAL_OPEN: key_door}],
		["the exit is reached without delivery", {ProgressionValidator.FORBID_DELIVER: [receiver]}, {}],
		["the exit is reached without the clear", {ProgressionValidator.FORBID_CLEAR: [fight]}, {}],
		["the exit is reached without the lift", {ProgressionValidator.FORBID_LIFT: [key]}, {}],
	]
	for case: Array in cases:
		var result: ProgressionValidator.ObjectiveResult = session.ask(case[1], case[2])
		assert_eq(result.verdict, NONE, "%s: %s" % [case[0], result.summary()])
	# Controls: each goal IS reached when nothing is withheld, in the authored order.
	var lift: ProgressionValidator.ObjectiveResult = session.ask({}, {ProgressionValidator.GOAL_LIFT: key})
	assert_eq(lift.verdict, FOUND)
	assert_lt(lift.trace.find("clear encounter %d" % fight), lift.trace.find("lift carriable %d" % key), "the clear comes first: %s" % str(lift.trace))
	assert_eq(session.ask({}, {ProgressionValidator.GOAL_OPEN: key_door}).verdict, FOUND)
	assert_eq(session.ask({}, {ProgressionValidator.GOAL_OPEN: vault_back}).verdict, FOUND, "the return opens -- after the clear")


## THE KEY'S DOOR IS UNAMBIGUOUS AFTER REMAPPING: the receiver the vault's key is delivered to is
## the landmark's own, in another piece, and its only effect opens the landmark's out door.
func test_the_receiver_owns_exactly_its_door_after_remapping_and_the_key_comes_from_another_piece() -> void:
	var recipe: FloorRecipe = _fold()
	for run_seed in [1, 7, 42]:
		var composed: FloorComposer.ComposeResult = _compose(recipe, run_seed)
		var plan: FloorPlan = _compiled(composed.layout)
		var landmark: StringName = RouteMetrics.instance_of_node(recipe, composed, &"landmark")
		var vault: StringName = RouteMetrics.instance_of_node(recipe, composed, &"objective")
		var receiver_id: int = composed.emit.global_id(landmark, &"trigger", 0)
		var key_id: int = composed.emit.global_id(vault, &"carriable", 0)
		assert_ne(landmark, vault, "two pieces")
		var receivers: Array = plan.triggers.filter(func(t: FloorTrigger) -> bool: return t.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED)
		assert_eq(receivers.size(), 1)
		assert_eq((receivers[0] as FloorTrigger).trigger_id, receiver_id, "seed %d: the landmark's receiver" % run_seed)
		assert_eq((receivers[0] as FloorTrigger).effects, [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, RouteMetrics.connection_of(composed, landmark, &"out"))])
		assert_eq(plan.carriables.map(func(c: CarriablePlan) -> int: return c.carriable_id), [key_id], "seed %d: the vault's key" % run_seed)


# --- 4. DECLARATIONS ---------------------------------------------------------------------------

## An independent fixture recipe: entry -> rotunda -> an AMBIENT lane -> exit, with a gallery off the
## rotunda's side that nothing on the route needs.
func _branch_recipe(declarations: Dictionary) -> FloorRecipe:
	var recipe := FloorRecipe.new()
	recipe.recipe_id = &"fixture_optional_branch"
	recipe.stratum = load("res://game/content/strata/archive.tres")
	recipe.fallback = load("res://game/content/layouts/archive_prototype.tres")
	recipe.pieces = [load(PIECES + "archive_entry_hall.tres"), load(PIECES + "archive_landmark_rotunda.tres"),
		load(PIECES + "archive_landmark_gallery.tres"), load(PIECES + "archive_encounter_lane.tres"),
		load(PIECES + "archive_exit_landing.tres")] as Array[FloorPiece]
	recipe.profiles = [load(PROFILES + "approach.tres"), load(PROFILES + "link.tres"), load(PROFILES + "link_turn.tres")] as Array[TraversalProfile]
	var nodes: Array[Dictionary] = [{"key": &"entry", "role": &"entry"}, {"key": &"hub", "role": &"landmark"},
		{"key": &"lane", "role": &"encounter", "tags": [&"ambient"]}, {"key": &"exit", "role": &"exit"},
		{"key": &"branch", "role": &"landmark"}]
	for node: Dictionary in nodes:
		if declarations.has(node["key"]):
			node["progression"] = declarations[node["key"]]
	recipe.nodes = nodes
	recipe.edges = [
		{"from": &"entry", "from_port": &"out", "to": &"hub", "to_port": &"in", "profile": &"approach"},
		{"from": &"hub", "from_port": &"out", "to": &"lane", "to_port": &"in", "profile": &"link"},
		{"from": &"lane", "from_port": &"out", "to": &"exit", "to_port": &"in", "profile": &"link"},
		{"from": &"hub", "from_port": &"side", "to": &"branch", "to_port": &"in", "profile": &"link_turn"},
	] as Array[Dictionary]
	recipe.extent = Rect2(-80, -160, 160, 164)
	recipe.placement_budget = 300
	return recipe


func _integrity(recipe: FloorRecipe, run_seed: int) -> ObjectiveIntegrity.Report:
	var composed: FloorComposer.ComposeResult = _compose(recipe, run_seed)
	assert_true(composed.report.succeeded(), composed.report.summary())
	return ObjectiveIntegrity.check(recipe, composed, _compiled(composed.layout), _rules(true))


## OPTIONAL, NON-VACUOUSLY: the branch is REACHABLE (a route stands on it), and the floor is
## completed with its ground withheld. The lane's roster is ambient: its node is mandatory ground,
## but no claim makes its enemies a required kill.
func test_optional_content_is_reachable_and_omittable_and_an_ambient_roster_is_not_a_required_kill() -> void:
	var recipe: FloorRecipe = _branch_recipe({&"hub": &"mandatory", &"lane": &"mandatory", &"exit": &"mandatory", &"branch": &"optional"})
	assert_eq(recipe.lint(), [] as Array[Dictionary])
	for run_seed in [1, 7]:
		var report: ObjectiveIntegrity.Report = _integrity(recipe, run_seed)
		assert_eq(report.outcome, ObjectiveIntegrity.OUTCOME_PASS, "seed %d: %s" % [run_seed, report.summary()])
		var reach: Array = report.claims.filter(func(c: ObjectiveIntegrity.Claim) -> bool: return c.node == &"branch" and c.kind == ObjectiveIntegrity.KIND_REACH)
		assert_eq(reach.size(), 1)
		if reach.size() == 1:
			assert_eq((reach[0] as ObjectiveIntegrity.Claim).result.verdict, FOUND, "the branch can actually be entered")
		var omit: Array = report.claims.filter(func(c: ObjectiveIntegrity.Claim) -> bool: return c.node == &"branch" and c.kind == ObjectiveIntegrity.KIND_GROUND)
		assert_eq(omit.size(), 1)
		if omit.size() == 1:
			assert_eq((omit[0] as ObjectiveIntegrity.Claim).result.verdict, FOUND, "and the floor is finished without it")
		assert_eq(report.claims_of(ObjectiveIntegrity.KIND_CLEAR), [], "the lane's ambient roster is never a required kill")
		assert_eq(report.claims.filter(func(c: ObjectiveIntegrity.Claim) -> bool: return c.node == &"lane").size(), 1, "the lane claims its ground only")


## A WRONG DECLARATION IS CAUGHT, with the route that contradicts it: the branch declared mandatory
## is completed around; the hub declared optional cannot be.
func test_a_wrong_declaration_fails_with_the_contradicting_route() -> void:
	var report: ObjectiveIntegrity.Report = _integrity(_branch_recipe({&"branch": &"mandatory"}), 1)
	assert_eq(report.outcome, ObjectiveIntegrity.OUTCOME_FAIL, report.summary())
	var broken: Array = report.broken_claims()
	assert_eq(broken.size(), 1, report.summary())
	if broken.size() == 1:
		var claim: ObjectiveIntegrity.Claim = broken[0]
		assert_eq([claim.node, claim.kind], [&"branch", ObjectiveIntegrity.KIND_GROUND])
		assert_eq(claim.result.verdict, FOUND)
		assert_false(claim.result.trace.is_empty(), "the completing route is the evidence")
	var hub_optional: ObjectiveIntegrity.Report = _integrity(_branch_recipe({&"hub": &"optional"}), 1)
	assert_eq(hub_optional.outcome, ObjectiveIntegrity.OUTCOME_FAIL, hub_optional.summary())
	assert_eq(hub_optional.broken_claims().map(func(c: ObjectiveIntegrity.Claim) -> String: return "%s/%s" % [c.node, c.kind]), ["hub/ground"])


## The fold with its arena declared optional: withholding the arena's ground leaves no route.
func test_the_fold_with_its_arena_declared_optional_fails() -> void:
	var recipe: FloorRecipe = _fold().duplicate()
	var nodes: Array[Dictionary] = []
	for node: Dictionary in _fold().nodes:
		var copy: Dictionary = node.duplicate()
		if copy["key"] == &"encounter":
			copy["progression"] = &"optional"
		nodes.append(copy)
	recipe.nodes = nodes
	var report: ObjectiveIntegrity.Report = _integrity(recipe, 7)
	assert_eq(report.outcome, ObjectiveIntegrity.OUTCOME_FAIL, report.summary())
	assert_eq(report.broken_claims().map(func(c: ObjectiveIntegrity.Claim) -> String: return "%s/%s" % [c.node, c.kind]), ["encounter/ground"])


func test_a_recipe_declaring_an_unknown_progression_or_an_optional_entry_is_refused() -> void:
	var recipe: FloorRecipe = _branch_recipe({&"entry": &"optional", &"hub": &"required"})
	var rules: Array = recipe.lint().map(func(f: Dictionary) -> StringName: return f["rule"])
	assert_has(rules, &"entry_optional")
	assert_has(rules, &"node_progression_unknown")
