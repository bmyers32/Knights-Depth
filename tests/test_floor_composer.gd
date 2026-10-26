extends GutTest
## THE COMPOSER, PROVED (ADR-001 S2): deterministic casting, coupled placement and routing,
## bounded backtracking, honest fallbacks -- and every composed floor structurally sound through
## the unchanged compiler. Diversity is asserted on STRUCTURE (which pieces, which shapes, which
## lengths, which extents), never on serialized ids happening to differ.

const RECIPE_PATH := "res://game/content/floors/recipes/proto_archive.tres"
const DOGLEG_PATH := "res://game/content/floors/recipes/proto_archive_dogleg.tres"
const FOLD_PATH := "res://game/content/floors/recipes/proto_archive_fold.tres"
## Diagnostics live in tools/ (the sweep reports them); the fold's geometric contract is asserted
## with the SAME walked-route measure, so a test and the sweep cannot disagree about a length.
const RouteMetrics := preload("res://tools/route_metrics.gd")
const SWEEP: int = 40
const DEPTH: int = 1


func _recipe() -> FloorRecipe:
	return load(RECIPE_PATH)


func _rules() -> Dictionary:
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_A")
	return {"body_radius": envoy.combat_radius, "attack_reach": sword.reach, "pickup_reach": envoy.pickup_reach}


func _radii(recipe: FloorRecipe) -> Dictionary:
	var radii: Dictionary = {}
	for key: StringName in recipe.stratum.enemy_keys:
		radii[key] = ContentDB.get_resource(&"enemy", key).combat_radius
	return radii


func _compose(run_seed: int, recipe: FloorRecipe = _recipe()) -> FloorComposer.ComposeResult:
	return FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, _radii(recipe))


func _compiled(layout: AuthoredLayout) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.stratum_id = layout.stratum_id
	LayoutCompiler.compile(layout, plan)
	return plan


## A shallow copy of the recipe whose VALUE fields may be changed; its pools stay shared.
func _variant(extent: Rect2) -> FloorRecipe:
	var tight: FloorRecipe = _recipe().duplicate()
	tight.extent = extent
	return tight


# --- content ---------------------------------------------------------------------------------

func test_the_recipe_its_profiles_and_its_pieces_lint_clean() -> void:
	var recipe: FloorRecipe = _recipe()
	assert_eq(recipe.lint(), [] as Array[Dictionary])
	assert_eq(recipe.pieces.size(), 8, "the ADR's eight pieces: entry, exit, 2 landmarks, 2 encounters, 2 objectives")
	for piece: FloorPiece in recipe.pieces:
		assert_eq(piece.lint(recipe.stratum.enemy_keys), [] as Array[Dictionary], piece.piece_id)
	assert_eq(recipe.profile(&"link").max_legs, 1, "a LINK is one straight run")
	assert_gt(recipe.profile(&"detour").length_min, recipe.profile(&"link").length_max, "a DETOUR is visibly longer than the LINK beside it (ADR §5.2)")
	assert_push_error_count(0)


# --- determinism -------------------------------------------------------------------------------

func test_the_same_seed_and_content_compose_the_identical_floor() -> void:
	for run_seed in [0, 1, 7, 42, 1337]:
		var first: FloorComposer.ComposeResult = _compose(run_seed)
		var second: FloorComposer.ComposeResult = _compose(run_seed)
		assert_true(first.report.succeeded(), first.report.summary())
		assert_eq(JSON.stringify(_compiled(first.layout).to_dict()), JSON.stringify(_compiled(second.layout).to_dict()), "seed %d" % run_seed)
		assert_eq(first.report.spatial_signature(), second.report.spatial_signature())
		assert_eq(first.report.rejections, second.report.rejections, "the same search, step for step")


func test_composition_never_touches_the_global_or_combat_random_streams() -> void:
	seed(99)
	var before: int = randi()
	seed(99)
	_compose(3)
	assert_eq(randi(), before, "the global stream is untouched")
	assert_eq(DepthGenerator.derive_floor_seed(20260828, 1), SeedMix.derive(20260828, 1), "the pinned derivation is SeedMix, unchanged (the goldens hold its values)")


func test_casting_sorts_by_identity_then_draws_by_weight() -> void:
	var recipe: FloorRecipe = _recipe()
	var node: Dictionary = recipe.node(&"landmark")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var first: Array[FloorPiece] = FloorComposer.cast(recipe, node, DEPTH, rng)
	rng.seed = 5
	var again: Array[FloorPiece] = FloorComposer.cast(recipe, node, DEPTH, rng)
	assert_eq(first.size(), 2)
	assert_eq(first[0].piece_id, again[0].piece_id, "the same stream, the same order")
	# The pool's listing order is not an input: pieces are sorted by identity before the draw.
	var reversed: FloorRecipe = recipe.duplicate()
	var pool: Array[FloorPiece] = recipe.pieces.duplicate()
	pool.reverse()
	reversed.pieces = pool
	for seed_value in [5, 6, 7, 8]:
		rng.seed = seed_value
		var from_pool: Array[FloorPiece] = FloorComposer.cast(recipe, node, DEPTH, rng)
		rng.seed = seed_value
		var from_reversed: Array[FloorPiece] = FloorComposer.cast(reversed, node, DEPTH, rng)
		assert_eq(from_reversed.map(func(p: FloorPiece) -> StringName: return p.piece_id), from_pool.map(func(p: FloorPiece) -> StringName: return p.piece_id), "seed %d" % seed_value)
	for piece: FloorPiece in first:
		assert_eq(piece.role, FloorPiece.ROLE_LANDMARK)
	var tagged: Dictionary = {"key": &"encounter", "role": &"encounter", "tags": [&"sealing"] as Array[StringName]}
	var sealing: Array[FloorPiece] = FloorComposer.cast(recipe, tagged, DEPTH, rng)
	assert_eq(sealing.size(), 1)
	assert_eq(sealing[0].piece_id, &"archive_encounter_pit", "a node's tags filter the pool")
	var deep: Dictionary = {"key": &"x", "role": &"exit"}
	assert_eq(FloorComposer.cast(recipe, deep, 99, rng).size(), 1, "depth_max 0 means no upper bound")
	# A piece outside its depth band is not a candidate at all.
	var banded: FloorRecipe = recipe.duplicate()
	var late_exit: FloorPiece = (recipe.pieces[1] as FloorPiece).duplicate()
	late_exit.depth_min = 3
	late_exit.depth_max = 4
	banded.pieces = [late_exit] as Array[FloorPiece]
	assert_eq(FloorComposer.cast(banded, deep, 1, rng).size(), 0, "too shallow")
	assert_eq(FloorComposer.cast(banded, deep, 5, rng).size(), 0, "too deep")
	assert_eq(FloorComposer.cast(banded, deep, 3, rng).size(), 1, "in band")


# --- soundness of every composed floor ------------------------------------------------------

## Every composed floor of a recipe over the sweep: emitted, compiled with no violations, margins
## kept, joints named, routes inside their profiles, finishable. Returns how many seeds fell back.
func _sweep_is_sound(recipe: FloorRecipe) -> int:
	var fallbacks: int = 0
	for run_seed in SWEEP:
		var result: FloorComposer.ComposeResult = _compose(run_seed, recipe)
		if result.report.fallback:
			fallbacks += 1
			continue
		assert_true(result.emit.is_ok(), "seed %d: %s" % [run_seed, result.emit.summary()])
		var plan: FloorPlan = _compiled(result.layout)
		assert_eq(plan.violations(_radii(recipe)), [] as Array[Dictionary], "seed %d" % run_seed)
		assert_gt(plan.solid_segments().size(), 0)
		assert_push_error_count(0, "seed %d: one wall truth, no style conflict" % run_seed)
		# no two footprints overlap, no hallway enters a footprint, nothing touches without a joint
		var draft: FloorDraft = result.draft
		for a_index: int in draft.instances.size():
			for b_index: int in range(a_index + 1, draft.instances.size()):
				var a: Rect2 = FloorDraft.world_footprint(draft.instances[a_index]).grow(recipe.margin)
				assert_eq(a.intersection(FloorDraft.world_footprint(draft.instances[b_index])).get_area(), 0.0, "seed %d: footprints keep the margin" % run_seed)
		for joint: FloorDraft.Joint in draft.joints:
			assert_gte(joint.rect_index, 0, "seed %d: every joint names its rect" % run_seed)
		assert_true(recipe.extent.encloses(result.report.extent), "seed %d: inside the extent" % run_seed)
		# Every route, tree or closing, honours its profile: each leg at least leg_min, the total
		# inside the band, no more legs than allowed.
		for edge: String in result.report.routes:
			var route: Dictionary = result.report.routes[edge]
			var profile: TraversalProfile = recipe.profile(route["profile"])
			assert_lte(route["legs"].size(), profile.max_legs, "seed %d %s" % [run_seed, edge])
			for leg: float in route["legs"]:
				assert_gte(leg, profile.leg_min, "seed %d %s leg" % [run_seed, edge])
			assert_between(float(route["length"]), profile.length_min, profile.length_max, "seed %d %s length" % [run_seed, edge])
		var progression: ProgressionReport = ProgressionValidator.check(plan, _rules())
		assert_true(progression.is_pass(), "seed %d: %s" % [run_seed, progression.summary()])
	return fallbacks


func test_every_composed_floor_in_the_sweep_is_structurally_sound_and_finishable() -> void:
	# MEASURED BASELINE (2026-10-23), not a law: these forty seeds all composed. If content or
	# profiles change and this moves, the sweep tool says by how much; the owner rules on it (O4).
	assert_eq(_sweep_is_sound(_recipe()), 0, "fallbacks in seeds 0..%d" % (SWEEP - 1))


# --- the dogleg (S2.5 topology experiment) -----------------------------------------------------

func _dogleg() -> FloorRecipe:
	return load(DOGLEG_PATH)


func test_the_dogleg_recipe_lints_clean_and_is_as_sound_as_the_column() -> void:
	var recipe: FloorRecipe = _dogleg()
	assert_eq(recipe.lint(), [] as Array[Dictionary])
	assert_eq(recipe.profile(&"link_turn").max_legs, 2, "the turning LINK bends exactly once")
	assert_eq(_sweep_is_sound(recipe), 0, "fallbacks in seeds 0..%d (measured baseline 2026-10-23)" % (SWEEP - 1))


## TOPOLOGY, NOT SIZE. Column: the encounter stands on the landmark's axis behind a straight LINK
## and the shortcut returns into the encounter's flank. Dogleg: the main line leaves the
## landmark's SIDE, bends toward the flow and stands aside; the objective continues straight
## through the far door; its shortcut enters the exit's side, around the encounter.
func test_the_dogleg_differs_from_the_column_in_topology_not_in_dimensions() -> void:
	for run_seed in [1, 7, 42]:
		var column: GenerationReport = _compose(run_seed).report
		var dogleg: GenerationReport = _compose(run_seed, _dogleg()).report
		assert_true(column.succeeded() and dogleg.succeeded(), "seed %d" % run_seed)
		if not (column.succeeded() and dogleg.succeeded()):
			continue
		assert_eq(column.routes["landmark>encounter"]["shape"], FloorComposer.SHAPE_STRAIGHT, "column: a straight link")
		assert_eq(dogleg.routes["landmark>encounter"]["shape"], FloorComposer.SHAPE_L, "dogleg: one bend")
		assert_eq(float(column.cast[&"encounter"]["origin"].x), float(column.cast[&"landmark"]["origin"].x), "column: the encounter stays on the landmark's axis")
		assert_gte(absf(float(dogleg.cast[&"encounter"]["origin"].x) - float(dogleg.cast[&"landmark"]["origin"].x)), 8.0, "dogleg: the main line steps aside by at least a leg")
		assert_true(column.routes.has("objective>encounter") and not column.routes.has("objective>exit"), "column: the shortcut rejoins the encounter")
		assert_true(dogleg.routes.has("objective>exit") and not dogleg.routes.has("objective>encounter"), "dogleg: the shortcut bypasses the encounter into the exit's side")
		assert_lt(float(dogleg.cast[&"objective"]["origin"].y), float(dogleg.cast[&"landmark"]["origin"].y), "dogleg: the objective lies beyond the landmark along the flow")


## THE CLEARANCE LAW, DIRECTLY: everything new, grown by the margin, has no positive-area overlap
## with anything placed or with the new footprint; contact at exactly the margin passes (that is
## how a joint's gap passes); the extent bounds everything.
func test_clearance_keeps_the_margin_between_everything_new_and_everything_placed() -> void:
	var recipe: FloorRecipe = _recipe()
	assert_eq(recipe.margin, 2.0, "the measured margin this test is written against")
	var occupied: Array[Rect2] = [Rect2(0, -20, 10, 10)]
	var none: Array[Rect2] = []
	assert_eq(FloorComposer._clear(recipe, Rect2(11, -20, 10, 10), none, occupied), &"footprint_overlap", "one unit short of the margin")
	assert_eq(FloorComposer._clear(recipe, Rect2(12, -20, 10, 10), none, occupied), &"", "exactly the margin: clear")
	assert_eq(FloorComposer._clear(recipe, Rect2(40, -20, 10, 10), [Rect2(11, -20, 4, 4)] as Array[Rect2], occupied), &"ground_overlap", "a hallway rect a unit from placed ground")
	assert_eq(FloorComposer._clear(recipe, Rect2(40, -20, 10, 10), [Rect2(12, -20, 4, 4)] as Array[Rect2], occupied), &"", "a hallway rect at the margin from placed ground")
	assert_eq(FloorComposer._clear(recipe, Rect2(40, -20, 10, 10), [Rect2(41, -31, 4, 10)] as Array[Rect2], occupied), &"ground_overlap", "a hallway rect a unit from the new footprint")
	assert_eq(FloorComposer._clear(recipe, Rect2(40, -20, 10, 10), [Rect2(41, -32, 4, 10)] as Array[Rect2], occupied), &"", "at the gap: the joint")
	assert_eq(FloorComposer._clear(recipe, Rect2(200, -20, 10, 10), none, occupied), &"extent_exceeded")
	assert_eq(FloorComposer._clear(recipe, Rect2(40, -20, 10, 10), [Rect2(40, -200, 4, 10)] as Array[Rect2], occupied), &"extent_exceeded", "a hallway outside the extent")


func test_joints_carry_the_profile_style_of_the_hallway_they_enter() -> void:
	var result: FloorComposer.ComposeResult = _compose(1)
	assert_true(result.report.succeeded())
	var layout: AuthoredLayout = result.layout
	var style_of_patch: Dictionary = {}
	for patch: WalkablePatch in layout.patches:
		style_of_patch[patch.key] = patch.boundary_style
	var joints: int = 0
	for connection: TraversalConnection in layout.connections:
		if not String(connection.key).begins_with("j"):
			continue
		joints += 1
		assert_eq(connection.flank_style, style_of_patch[connection.far_key], "%s enters %s" % [connection.key, connection.far_key])
	assert_eq(joints, 10, "five edges, two joints each")
	var shortcut: TraversalProfile = _recipe().profile(&"shortcut")
	assert_eq(shortcut.boundary_style, &"wall", "the shortcut's hallway AND its joints are walled (one style per connective space)")


func test_the_closing_edge_makes_a_loop_and_the_detour_is_longer_than_the_link() -> void:
	for run_seed in 10:
		var report: GenerationReport = _compose(run_seed).report
		assert_true(report.succeeded(), report.summary())
		assert_true(report.routes.has("objective>encounter"), "seed %d: the cycle closed" % run_seed)
		assert_gt(float(report.routes["landmark>objective"]["length"]), float(report.routes["landmark>encounter"]["length"]), "seed %d" % run_seed)
		assert_eq(report.routes["landmark>encounter"]["shape"], FloorComposer.SHAPE_STRAIGHT, "a LINK is straight")


# --- diversity, on structure ------------------------------------------------------------------

func test_different_seeds_differ_in_pieces_shapes_lengths_and_extents() -> void:
	var signatures: Dictionary = {}
	var casts: Dictionary = {}
	var approach_shapes: Dictionary = {}
	var detour_lengths: Dictionary = {}
	var extents: Dictionary = {}
	for run_seed in SWEEP:
		var report: GenerationReport = _compose(run_seed).report
		if not report.succeeded():
			continue
		signatures[report.spatial_signature()] = true
		var cast_key: String = "%s/%s/%s" % [report.cast[&"landmark"]["piece_id"], report.cast[&"encounter"]["piece_id"], report.cast[&"objective"]["piece_id"]]
		casts[cast_key] = true
		approach_shapes[String(report.routes["entry>landmark"]["shape"]) + str(report.routes["entry>landmark"]["legs"])] = true
		detour_lengths[float(report.routes["landmark>objective"]["length"])] = true
		extents[report.extent] = true
	gut.p("distinct signatures %d, casts %d, approach shapes %d, detour lengths %d, extents %d" % [signatures.size(), casts.size(), approach_shapes.size(), detour_lengths.size(), extents.size()])
	assert_gt(signatures.size(), SWEEP / 2, "most seeds are distinct arrangements")
	assert_gte(casts.size(), 4, "several piece combinations are cast")
	assert_gte(approach_shapes.size(), 3, "the approach varies in shape or leg lengths")
	assert_gte(detour_lengths.size(), 3, "the detour varies in length")
	assert_gte(extents.size(), 3, "the floors differ in overall extent, not only in ids")


# --- backtracking, budgets, fallback ---------------------------------------------------------

## The objective hangs off the landmark's side, so a floor narrower than a landmark and an
## objective side by side (the narrowest pair spans 34) cannot be composed, while the main
## line alone still fits in 24: every objective position fails, the landmark frame pops and is
## retried through its ring, the attempts run out, and the authored fallback is reported -- apart.
## (A width of 40 is NOT impossible: the search jogs the approach aside and fits the loop.)
func test_an_impossible_recipe_backtracks_terminates_within_budget_and_falls_back() -> void:
	var tight: FloorRecipe = _variant(Rect2(-12, -160, 24, 164))
	var result: FloorComposer.ComposeResult = _compose(1, tight)
	var report: GenerationReport = result.report
	assert_true(report.fallback, report.summary())
	assert_false(report.succeeded())
	assert_false(report.structural, "an exhausted search is not a structural failure")
	assert_null(result.draft)
	assert_eq(result.layout, tight.fallback, "the recipe's own authored fallback, the same object")
	assert_eq(report.attempts, tight.reseed_budget + 1)
	assert_gt(report.backtracks, 0, "frames were popped and parents retried")
	assert_gt(int(report.rejections.get(&"extent_exceeded", 0)), 0)
	assert_lte(report.placements, tight.placement_budget * report.attempts, "placements stay inside the budget")
	assert_true(report.summary().begins_with("gen proto_archive"), report.summary())
	assert_true(report.summary().contains("FALLBACK"))


## MIRRORING IS REACHED ONLY WHEN IDENTITY CANNOT FIT (ADR §5.1 step 2). The prototype's approach
## can jog aside, which always makes room for the loop on the east, so no sweep seed ever mirrors
## (a finding for the owner). With a straight-only approach and an extent that only the west can
## hold, the identity-only gallery and the identity rotunda both fail and the mirrored rotunda --
## side to the west, the encounter mirrored to meet it -- is what composes.
func test_mirroring_is_reached_when_identity_cannot_fit() -> void:
	# East of x = 12 nothing fits (identity hangs the loop east, at x >= 12); west there is room for
	# a long first detour leg, which the 28-minimum detour needs so its second leg can stay short
	# enough for the shortcut's first leg to reach the encounter's side.
	var narrow: FloorRecipe = _variant(Rect2(-50, -160, 62, 164))
	var straight: TraversalProfile = narrow.profile(&"approach").duplicate()
	straight.max_legs = 1
	var profiles: Array[TraversalProfile] = []
	for profile: TraversalProfile in narrow.profiles:
		profiles.append(straight if profile.profile_id == &"approach" else profile)
	narrow.profiles = profiles
	narrow.placement_budget = 2000  # the contrived space is large; the budget is content, and this test is about the transform
	var report: GenerationReport = _compose(1, narrow).report
	assert_true(report.succeeded(), report.summary())
	if not report.succeeded():
		return
	assert_eq(report.cast[&"landmark"]["piece_id"], &"archive_landmark_rotunda", "the gallery does not allow mirroring")
	assert_eq(report.cast[&"landmark"]["transform"], FloorPiece.TRANSFORM_MIRROR_X)
	assert_lt(float(report.cast[&"objective"]["origin"].x), 0.0, "the loop hangs to the west")
	assert_eq(report.cast[&"encounter"]["transform"], FloorPiece.TRANSFORM_MIRROR_X, "the encounter's side port turned to meet the shortcut")
	assert_gt(report.backtracks, 0, "identity was tried and undone first")


## The budget is the bound: three placements can never finish five nodes, so every attempt stops
## at exactly three, says so, and the reseeds run out into the fallback.
func test_the_placement_budget_bounds_every_attempt() -> void:
	var starved: FloorRecipe = _variant(Rect2(-80, -160, 160, 164))
	starved.placement_budget = 3
	var report: GenerationReport = _compose(1, starved).report
	assert_true(report.fallback, report.summary())
	assert_eq(report.attempts, starved.reseed_budget + 1)
	assert_eq(report.placements, 3 * report.attempts, "exactly the budget, every attempt")
	assert_eq(int(report.rejections.get(&"placement_budget", 0)), report.attempts)


## A RECIPE IS CHECKED BEFORE ANY SEED IS DRAWN: a node listed before the node that places it,
## or an edge naming a node that does not exist, is a finding -- and composing such a recipe is
## a structural failure that falls back, never a search that runs on a malformed graph.
func test_a_recipe_placing_a_child_before_its_parent_is_refused() -> void:
	var recipe: FloorRecipe = _recipe()
	assert_eq(recipe.lint(), [] as Array[Dictionary])
	var disordered: FloorRecipe = recipe.duplicate()
	var nodes: Array[Dictionary] = recipe.nodes.duplicate()
	var objective: Dictionary = nodes[2]
	nodes.remove_at(2)
	nodes.insert(1, objective)  # entry, objective, landmark, ... -- the objective's parent comes after it
	disordered.nodes = nodes
	var rules: Array = disordered.lint().map(func(f: Dictionary) -> StringName: return f["rule"])
	assert_eq(rules, [&"node_order_invalid"])
	if rules.is_empty():
		return  # an unlinted recipe would run the search on a graph whose parent is not placed yet
	var result: FloorComposer.ComposeResult = _compose(1, disordered)
	assert_true(result.report.fallback and result.report.structural, result.report.summary())
	assert_eq(result.report.failing_validator, "recipe lint")
	var dangling: FloorRecipe = recipe.duplicate()
	var edges: Array[Dictionary] = recipe.edges.duplicate()
	edges.append({"from": &"landmark", "from_port": &"side", "to": &"treasury", "to_port": &"in", "profile": &"link"})
	dangling.edges = edges
	rules = dangling.lint().map(func(f: Dictionary) -> StringName: return f["rule"])
	assert_eq(rules, [&"edge_node_unknown"])


func test_a_broken_recipe_is_a_structural_failure_with_the_fallback() -> void:
	var broken: FloorRecipe = _variant(Rect2(-80, -160, 160, 164))
	broken.margin = 5.0  # above every profile's gap: no joint could ever pass the margin test
	var result: FloorComposer.ComposeResult = _compose(1, broken)
	assert_true(result.report.fallback)
	assert_true(result.report.structural)
	assert_eq(result.report.failing_validator, "recipe lint")
	assert_true(result.report.log[0].contains("profile_gap_below_margin") or result.report.log[0].contains("gap"), result.report.log[0])


func test_the_report_is_outside_the_plan_and_describes_the_search() -> void:
	var result: FloorComposer.ComposeResult = _compose(7)
	var plan: FloorPlan = _compiled(result.layout)
	assert_false(plan.to_dict().has("report"), "O2: diagnostics never enter the golden")
	var dict: Dictionary = result.report.to_dict()
	for key in ["recipe_id", "floor_seed", "attempts", "placements", "retries", "backtracks", "rejections", "fallback", "structural", "cast", "routes", "extent", "elapsed_usec", "signature"]:
		assert_true(dict.has(key), key)
	assert_eq(dict["cast"].size(), 5)
	assert_eq(dict["routes"].size(), 5)


func test_generation_time_is_measured_against_the_m2_gate_not_branched_on() -> void:
	var recipe: FloorRecipe = _recipe()
	var radii: Dictionary = _radii(recipe)
	var times: Array[float] = []
	for run_seed in 50:
		var started: int = Time.get_ticks_usec()
		FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, radii)
		times.append((Time.get_ticks_usec() - started) / 1000.0)
	times.sort()
	gut.p("compose: p50 %.2f ms, p99 %.2f ms, max %.2f ms" % [times[24], times[49], times[49]])
	assert_lt(times[49], 100.0, "GAME-RULES §5 M2: < 100 ms per floor (here the slowest of 50)")


# --- the emitter's S2 ruling: a port enters a named rect, or exactly one ------------------------

func test_a_joint_facing_two_hallway_rects_is_refused_unless_it_names_one() -> void:
	var draft := FloorDraft.new()
	draft.draft_id = &"ambiguous"
	draft.stratum_id = &"archive"
	var a: StringName = draft.place(load("res://game/content/floors/pieces/archive_entry_apron.tres"), Vector2(0, 0))
	var b: StringName = draft.place(load("res://game/content/floors/pieces/archive_exit_gallery.tres"), Vector2(0, -40), FloorPiece.TRANSFORM_MIRROR_X)
	# Two rects stacked along the spine both lie beyond A's door and cover its span.
	var spine: StringName = draft.lay([Rect2(-2.5, -24, 5, 10), Rect2(-2.5, -38, 5, 14)] as Array[Rect2], &"stone", &"ledge")
	draft.bind(a, &"out", spine, 1.5, &"ledge")
	draft.bind(b, &"in", spine, 1.5, &"ledge", 1)
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(report.errors.map(func(e: Dictionary) -> StringName: return e["kind"]), [&"joint_ambiguous"])
	assert_eq(report.errors_of(&"joint_ambiguous").map(func(e: Dictionary) -> Array: return e["refs"]["rects"]), [[0, 1]])
	draft.joints[0].rect_index = 0
	report = DraftEmitter.emit(draft)
	assert_true(report.is_ok(), report.summary())
	draft.joints[0].rect_index = 5
	report = DraftEmitter.emit(draft)
	assert_eq(report.errors.map(func(e: Dictionary) -> StringName: return e["kind"]), [&"joint_rect_unknown"])


# --- the fold (S3a: the folded remote-key expedition, geometry only) ---------------------------
#
# What S3a claims, and all it claims: the fold COMPOSES, soundly, into the intended arrangement --
# a plain arrival, a landmark whose key door is shut, a sealing fight off to one side, a vault
# beyond it, a return hall from the vault into the landmark, and an onward route folding back the
# other way. Every distance is WALKED (route_metrics), never straight-line. Whether the
# progression's mandatory beats are unavoidable is S3b's validator work and is NOT asserted here.

func _fold() -> FloorRecipe:
	return load(FOLD_PATH)


func _instance(recipe: FloorRecipe, result: FloorComposer.ComposeResult, node_key: StringName) -> FloorDraft.PieceInstance:
	return result.draft.instance_of(RouteMetrics.instance_of_node(recipe, result, node_key))


func _trigger_of_kind(plan: FloorPlan, kind: StringName) -> FloorTrigger:
	for trigger: FloorTrigger in plan.triggers:
		if trigger.kind == kind:
			return trigger
	return null


func _exit_pad(plan: FloorPlan) -> Rect2:
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") == FloorLayers.EFFECT_COMPLETE_FLOOR:
				return trigger.region
	return Rect2()


func test_the_fold_recipe_lints_clean_casts_one_piece_per_role_and_arrives_without_a_toll() -> void:
	var recipe: FloorRecipe = _fold()
	assert_eq(recipe.lint(), [] as Array[Dictionary])
	for piece: FloorPiece in recipe.pieces:
		assert_eq(piece.lint(recipe.stratum.enemy_keys), [] as Array[Dictionary], piece.piece_id)
	var rng := RandomNumberGenerator.new()
	for node: Dictionary in recipe.nodes:
		assert_eq(FloorComposer.cast(recipe, node, DEPTH, rng).size(), 1, "node %s has exactly one eligible piece" % node["key"])
	# The S2.5 ruling: the crate-and-plate entry toll is gone. The arrival has no gate, no trigger,
	# no prop to break -- it is somewhere to arrive, and its one door is open.
	var entry: FloorPiece = load("res://game/content/floors/pieces/archive_entry_hall.tres")
	assert_eq(entry.body.triggers.size(), 0)
	assert_eq(entry.body.breakables.size(), 0)
	for port: PiecePort in entry.ports:
		assert_eq(port.kind, PiecePort.KIND_CONNECTOR, "the arrival's way on is open")
	var back: TraversalProfile = recipe.profile(&"return")
	assert_true(back.leg_min >= back.overlap + back.width * 0.5,
		"a return leg shorter than overlap + half-width puts its next rect inside the joint aperture (S3a finding)")


func test_every_fold_floor_in_the_sweep_is_structurally_sound_and_finishable() -> void:
	# MEASURED BASELINE (2026-10-26): all forty seeds compose; the 200-seed sweep is the report.
	assert_eq(_sweep_is_sound(_fold()), 0, "fallbacks in seeds 0..%d" % (SWEEP - 1))


func test_the_same_seed_composes_the_identical_fold() -> void:
	for run_seed in [1, 7, 42]:
		var first: FloorComposer.ComposeResult = _compose(run_seed, _fold())
		var second: FloorComposer.ComposeResult = _compose(run_seed, _fold())
		assert_true(first.report.succeeded(), first.report.summary())
		assert_eq(JSON.stringify(_compiled(first.layout).to_dict()), JSON.stringify(_compiled(second.layout).to_dict()), "seed %d" % run_seed)


## THE KEY DOOR IS THE LANDMARK'S OWN SHUT DOOR, and the key that opens it rests in another piece.
## The receiver is the door's threshold: inside the landmark, touching the door's line, within its
## span -- under whatever transform the landmark was placed with.
func test_the_key_rests_in_the_vault_and_its_door_is_the_landmarks_shut_gate() -> void:
	var recipe: FloorRecipe = _fold()
	for run_seed in [1, 7, 42]:
		var result: FloorComposer.ComposeResult = _compose(run_seed, recipe)
		if not result.report.succeeded():
			fail_test("seed %d: %s" % [run_seed, result.report.summary()])
			continue
		var plan: FloorPlan = _compiled(result.layout)
		var landmark: FloorDraft.PieceInstance = _instance(recipe, result, &"landmark")
		var vault: FloorDraft.PieceInstance = _instance(recipe, result, &"objective")
		assert_eq(plan.carriables.size(), 1, "one key")
		var key: Vector3 = plan.carriables[0].position
		assert_true(WalkableBounds.contains(FloorDraft.world_footprint(vault), key.x, key.z), "seed %d: the key rests in the vault" % run_seed)
		var receiver: FloorTrigger = _trigger_of_kind(plan, FloorLayers.TRIGGER_CARRIABLE_INSERTED)
		if receiver == null:
			fail_test("seed %d: no receiver" % run_seed)
			continue
		assert_true(FloorDraft.world_footprint(landmark).encloses(receiver.region), "seed %d: the receiver is the landmark's" % run_seed)
		var door: int = RouteMetrics.connection_of(result, landmark.instance_id, &"out")
		var opened: Array = receiver.effects.map(func(e: Dictionary) -> int: return int(e.get("target_id", -1)))
		assert_eq(opened, [door], "seed %d: delivering the key opens the landmark's out door, and only that" % run_seed)
		var shut_on_arrival: bool = false
		for connection: TraversalConnection in plan.connections:
			if connection.connection_id == door:
				shut_on_arrival = not connection.starts_open
		assert_true(shut_on_arrival, "seed %d: the key door is shut on arrival" % run_seed)
		var port: PiecePort = landmark.piece.port(&"out")
		var span: Dictionary = FloorDraft.port_span(landmark, port)
		assert_false(PiecePort.runs_along_x(FloorDraft.world_edge(landmark, port.edge)), "sanity: the key door is in a side wall")
		var touches: bool = is_equal_approx(receiver.region.position.x, float(span["at"])) or is_equal_approx(receiver.region.end.x, float(span["at"]))
		assert_true(touches, "seed %d: the receiver stands on the door's threshold" % run_seed)
		assert_true(receiver.region.position.y >= float(span["from"]) - 0.001 and receiver.region.end.y <= float(span["to"]) + 0.001,
			"seed %d: the receiver lies within the door's span" % run_seed)


## THE RETURN IS A REAL SHORTCUT: with the key in hand (the fight cleared, the vault's back door
## open), the walked carry to the door is shorter than the same carry with the return hall shut --
## and it crosses from the vault into the landmark without entering the fight's room.
func test_the_return_shortens_the_carry_and_never_re_enters_the_fight() -> void:
	var recipe: FloorRecipe = _fold()
	var radius: float = float(_rules()["body_radius"])
	for run_seed in [1, 7, 42]:
		var result: FloorComposer.ComposeResult = _compose(run_seed, recipe)
		if not result.report.succeeded():
			fail_test("seed %d: %s" % [run_seed, result.report.summary()])
			continue
		var plan: FloorPlan = _compiled(result.layout)
		var landmark: FloorDraft.PieceInstance = _instance(recipe, result, &"landmark")
		var vault: FloorDraft.PieceInstance = _instance(recipe, result, &"objective")
		var pit: FloorDraft.PieceInstance = _instance(recipe, result, &"encounter")
		var door: int = RouteMetrics.connection_of(result, landmark.instance_id, &"out")
		var returns: Array = [RouteMetrics.connection_of(result, vault.instance_id, &"back"), RouteMetrics.connection_of(result, landmark.instance_id, &"back")]
		var key: Vector3 = plan.carriables[0].position
		var receiver: Rect2 = _trigger_of_kind(plan, FloorLayers.TRIGGER_CARRIABLE_INSERTED).region
		var carry: Dictionary = RouteMetrics.walk(plan, RouteMetrics.open_except(plan, [door]), Vector2(key.x, key.z), receiver, radius)
		var without: Dictionary = RouteMetrics.walk(plan, RouteMetrics.open_except(plan, [door] + returns), Vector2(key.x, key.z), receiver, radius)
		assert_gt(float(carry["length"]), 0.0, "seed %d: the key can be carried home" % run_seed)
		assert_gt(float(without["length"]), 0.0, "seed %d: sanity: the long way exists" % run_seed)
		assert_lt(float(carry["length"]), float(without["length"]), "seed %d: the return is shorter than going back through the fight" % run_seed)
		var crossed: Array[StringName] = RouteMetrics.pieces_crossed(result, carry["path"])
		assert_eq(crossed, [vault.instance_id, landmark.instance_id] as Array[StringName], "seed %d: vault, then the landmark -- nothing between but the return hall" % run_seed)
		var entered: bool = false
		for point: Vector2 in carry["path"]:
			entered = entered or WalkableBounds.contains(FloorDraft.world_footprint(pit), point.x, point.y)
		assert_false(entered, "seed %d: the carry never enters the fight's room" % run_seed)


## THE GEOMETRY BLOCKS WHAT IT SHOULD, read as reachability only (S3b's validator owns whether a
## mandatory beat is truly unavoidable): with the doors as authored the key is out of reach; with
## everything open except the key door the exit is out of reach; with that door open it is not.
func test_on_arrival_the_key_and_the_exit_lie_behind_shut_doors() -> void:
	var recipe: FloorRecipe = _fold()
	var radius: float = float(_rules()["body_radius"])
	for run_seed in [1, 7, 42]:
		var result: FloorComposer.ComposeResult = _compose(run_seed, recipe)
		if not result.report.succeeded():
			fail_test("seed %d: %s" % [run_seed, result.report.summary()])
			continue
		var plan: FloorPlan = _compiled(result.layout)
		var closed: Array = []
		for connection: TraversalConnection in plan.connections:
			if not connection.starts_open:
				closed.append(connection.connection_id)
		var entry := Vector2(plan.entry_point.x, plan.entry_point.z)
		var key: Vector3 = plan.carriables[0].position
		var key_spot := Rect2(key.x - 1.0, key.z - 1.0, 2.0, 2.0)
		var door: int = RouteMetrics.connection_of(result, _instance(recipe, result, &"landmark").instance_id, &"out")
		assert_eq(float(RouteMetrics.walk(plan, RouteMetrics.open_except(plan, closed), entry, key_spot, radius)["length"]), -1.0, "seed %d: the key is out of reach on arrival" % run_seed)
		assert_eq(float(RouteMetrics.walk(plan, RouteMetrics.open_except(plan, [door]), entry, _exit_pad(plan), radius)["length"]), -1.0, "seed %d: only the key door leads to the exit" % run_seed)
		assert_gt(float(RouteMetrics.walk(plan, RouteMetrics.open_except(plan, []), entry, _exit_pad(plan), radius)["length"]), 0.0, "seed %d: sanity: with the door open the exit is reached" % run_seed)


## THE FOLD: the fight and the vault lie off one side of the landmark; the onward route leaves the
## other side and turns back down the floor, so the exit ends up beside ground already walked.
func test_the_onward_route_folds_back_on_the_far_side_from_the_fight() -> void:
	var recipe: FloorRecipe = _fold()
	for run_seed in [1, 7, 42]:
		var report: GenerationReport = _compose(run_seed, recipe).report
		if not report.succeeded():
			fail_test("seed %d: %s" % [run_seed, report.summary()])
			continue
		var landmark: Vector2 = report.cast[&"landmark"]["origin"]
		var fight: Vector2 = report.cast[&"encounter"]["origin"]
		var exit: Vector2 = report.cast[&"exit"]["origin"]
		assert_lt(signf(fight.x - landmark.x) * signf(exit.x - landmark.x), 0.0, "seed %d: the exit leaves the landmark's other side" % run_seed)
		assert_lt(exit.y, landmark.y, "seed %d: and turns back down the floor" % run_seed)
		assert_eq(report.routes["landmark>exit"]["shape"], FloorComposer.SHAPE_L, "seed %d: one turn" % run_seed)
