extends GutTest
## ADR-001 S4 VISIBILITY, PROVED AGAINST WHAT THE PLAYER SEES.
##
## The shared camera resource (O1) is the camera the Arena actually uses; its projection agrees
## with the real FollowCamera on shipped Floor 2; occlusion is tested against opaque boxes and,
## on a composed fold, against the meshes FloorBuilder really draws. The fold's mandatory reveal
## is the LOCKED DOOR seen from the landmark's approach -- not the exit, which the fold may hide.

const FRAMING := "res://game/content/camera/expedition_framing.tres"
const SPIKES := "res://game/content/floors/recipes/proto_archive_fold_spikes.tres"
const GUARDED := "res://game/content/floors/recipes/proto_archive_fold_spikes_guarded.tres"
const DEPTH: int = 1
## Screen agreement with the real camera, in pixels of the 1152 x 648 reference window.
const PIXEL_EPSILON: float = 0.5
const POSITION_EPSILON: float = 0.0001
## How far the authored door anchor may sit from the centre of the lock FloorBuilder draws. The
## lock stands on the sim's barrier line, which lies in the joint's gap a little beyond the hall.
const LOCK_TOLERANCE: float = 1.5


func _framing() -> CameraFraming:
	return load(FRAMING)


func _rules() -> Dictionary:
	var envoy: Resource = load("res://game/content/envoy/envoy_stats.tres")
	var sword: Resource = load("res://game/content/weapons/sword_stats.tres")
	return {"body_radius": envoy.combat_radius, "attack_reach": sword.reach, "pickup_reach": envoy.pickup_reach}


func _radii(recipe: FloorRecipe) -> Dictionary:
	var radii: Dictionary = {}
	for key: StringName in recipe.stratum.enemy_keys:
		radii[key] = ContentDB.get_resource(&"enemy", key).combat_radius
	return radii


func _compose(recipe: FloorRecipe, run_seed: int, camera: CameraFraming = null) -> FloorComposer.ComposeResult:
	return FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, _radii(recipe), {}, camera, _rules())


func _plan_of(result: FloorComposer.ComposeResult, run_seed: int) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.run_seed = run_seed
	plan.depth = DEPTH
	plan.floor_seed = SeedMix.derive(run_seed, DEPTH)
	plan.stratum_id = result.layout.stratum_id
	plan.authored_layout = false
	LayoutCompiler.compile(result.layout, plan)
	return plan


func _scene_property(path: String, node_name: String, property: String) -> Variant:
	var state: SceneState = (load(path) as PackedScene).get_state()
	for node: int in state.get_node_count():
		if state.get_node_name(node) == node_name:
			for index: int in state.get_node_property_count(node):
				if state.get_node_property_name(node, index) == property:
					return state.get_node_property_value(node, index)
	return null


# --- O1: one camera, M1's framing preserved -------------------------------------------------

func test_the_expedition_camera_reads_the_shared_framing_and_keeps_the_m1_framing() -> void:
	var framing := _framing()
	assert_eq(framing.offset, Vector3(0, 12, 12), "the validated M1 offset")
	assert_eq(framing.edge_margin_x, 6.0)
	assert_eq(framing.edge_margin_z, 6.0)
	assert_eq(framing.fov_degrees, 75.0, "Godot's default, which the M1 camera never overrode")
	var bound: Resource = _scene_property("res://game/arena/arena.tscn", "FollowCamera", "framing")
	assert_not_null(bound, "the Arena's camera is bound to the shared resource")
	assert_eq(bound.resource_path, FRAMING)
	var authored: Transform3D = _scene_property("res://game/arena/arena.tscn", "FollowCamera", "transform")
	var camera := FollowCamera.new()
	camera.framing = framing
	add_child_autofree(camera)
	assert_eq(camera.offset, framing.offset)
	assert_eq(camera.fov, 75.0)
	assert_eq(camera.keep_aspect, Camera3D.KEEP_HEIGHT)
	for axis: int in 3:
		assert_almost_eq(camera.basis[axis], authored.basis[axis], Vector3.ONE * 0.000001, "the applied pitch is the scene's authored rotation")
		assert_almost_eq(framing.camera_basis()[axis], authored.basis[axis], Vector3.ONE * 0.000001)
	# The hubs keep their own closer camera: no framing, offset unchanged.
	assert_null(_scene_property("res://game/hub/hub_space.tscn", "FollowCamera", "framing"))
	assert_eq(_scene_property("res://game/hub/hub_space.tscn", "FollowCamera", "offset"), Vector3(0, 9, 9))


func test_the_occluder_dimensions_are_the_ones_floor_builder_draws() -> void:
	var framing := _framing()
	assert_eq(framing.occluder_wall_height, FloorBuilder._WALL_HEIGHT)
	assert_eq(framing.occluder_wall_thickness, FloorBuilder._WALL_THICKNESS)
	assert_eq(framing.occluder_gate_height, FloorBuilder._GATE_HEIGHT)
	assert_eq(framing.occluder_blocker_height, FloorBuilder._BLOCKER_HEIGHT)


## Intact breakables are occluders at the size FloorBuilder actually builds them: the validator's
## box for an ordinary urn and for a blocking barricade equals the built mesh's box.
func test_intact_breakables_occlude_at_their_drawn_size() -> void:
	var framing := _framing()
	var plan := FloorPlan.new()
	var urn := BreakablePlan.new()
	urn.key = &"B_URN"
	urn.breakable_id = 0
	urn.position = Vector3(0, 0, -5)
	var barricade := BreakablePlan.new()
	barricade.key = &"B_WALL"
	barricade.breakable_id = 1
	barricade.position = Vector3(6, 0, -5)
	barricade.blocking_rect = Rect2(4, -6, 4, 2)
	plan.breakables = [urn, barricade] as Array[BreakablePlan]
	var builder := FloorBuilder.new()
	add_child_autofree(builder)
	builder._build_breakable(urn)
	builder._build_breakable(barricade)
	var boxes: Dictionary = {}
	for blocker: Dictionary in VisibilityValidator.occluders(plan, framing, []):
		boxes[blocker["what"]] = blocker["box"]
	for breakable: BreakablePlan in plan.breakables:
		var mesh: MeshInstance3D = builder._breakables[breakable.breakable_id]
		var drawn: AABB = mesh.global_transform * mesh.get_aabb()
		assert_true(boxes.has("breakable %s" % breakable.key), "%s is an occluder" % breakable.key)
		if not boxes.has("breakable %s" % breakable.key):
			continue
		var modelled: AABB = boxes["breakable %s" % breakable.key]
		assert_almost_eq(modelled.position, drawn.position, Vector3.ONE * POSITION_EPSILON, "%s placed as drawn" % breakable.key)
		assert_almost_eq(modelled.size, drawn.size, Vector3.ONE * POSITION_EPSILON, "%s sized as drawn" % breakable.key)
	# And it hides what stands behind it: a low point just past an urn on the camera's line.
	var stand := Vector3(0, 0, 4)
	var camera: Vector3 = framing.camera_position(stand, Rect2())
	var behind: Vector3 = urn.position + (urn.position - camera).normalized() * 0.4
	behind.y = 0.2
	var sight: VisibilityValidator.Sight = VisibilityValidator.look(framing, Rect2(), VisibilityValidator.occluders(plan, framing, []), stand, behind)
	assert_false(sight.centre_seen, "an intact urn on the line hides the point behind it: %s" % [sight.misses])
	assert_has(sight.misses, "breakable B_URN")


func test_the_projection_matches_the_real_follow_camera_on_floor_2() -> void:
	var framing := _framing()
	var plan: FloorPlan = DepthGenerator.generate(0, 2)
	var extent: Rect2 = VisibilityValidator.extent_of(plan)
	var arena_script: Node = load("res://game/arena/arena.gd").new()
	assert_eq(extent, arena_script._floor_extent_of(plan), "the validator's extent is the Arena's")
	arena_script.free()
	var root: Window = get_tree().root
	var restore: Vector2i = root.size
	root.size = Vector2i(framing.viewport_size)
	var camera := FollowCamera.new()
	camera.framing = framing
	add_child_autofree(camera)
	camera.current = true
	camera.follow_lerp_per_second = 0.0
	camera.set_floor_extent(extent)
	var target := Node3D.new()
	add_child_autofree(target)
	camera.set_target(target)
	var stands: Array[Vector3] = [plan.entry_point, Vector3(extent.position.x, 0, extent.position.y), Vector3(extent.end.x, 0, extent.end.y)]
	for patch: WalkablePatch in plan.patches:
		stands.append(Vector3(patch.rect.get_center().x, 0, patch.rect.get_center().y))
	var compared: int = 0
	var worst: float = 0.0
	for stand: Vector3 in stands:
		target.position = stand
		camera.snap_to_target()
		assert_almost_eq(camera.global_position, framing.camera_position(stand, extent), Vector3.ONE * POSITION_EPSILON, "camera placed by the same edge stop at %s" % stand)
		for patch: WalkablePatch in plan.patches:
			for corner: Vector2 in [patch.rect.position, patch.rect.end, patch.rect.get_center()]:
				for height: float in [0.0, 1.3]:
					var point := Vector3(corner.x, height, corner.y)
					var projected: Dictionary = framing.project(camera.global_position, point)
					assert_eq(projected["behind"], camera.is_position_behind(point), "behind agrees for %s" % point)
					if projected["behind"]:
						continue
					var real: Vector2 = camera.unproject_position(point)
					worst = maxf(worst, real.distance_to(projected["screen"]))
					compared += 1
	root.size = restore
	assert_lt(worst, PIXEL_EPSILON, "projection agrees with unproject_position within %s px (worst %.4f over %d points)" % [PIXEL_EPSILON, worst, compared])
	assert_gt(compared, 500, "enough points compared to mean something")
	gut.p("Floor 2: %d points across %d stands, worst %.5f px" % [compared, stands.size(), worst])


# --- occlusion, the band, intent ----------------------------------------------------------

func test_an_opaque_box_between_camera_and_target_hides_it_and_a_low_one_does_not() -> void:
	var framing := _framing()
	var stand := Vector3.ZERO
	var target := Vector3(0, 0, -10)
	var clear: VisibilityValidator.Sight = VisibilityValidator.look(framing, Rect2(), [], stand, target)
	assert_true(clear.seen(framing.reveal_min_visible_share), "nothing in the way: seen")
	var wall: Array[Dictionary] = [{"box": AABB(Vector3(-5, 0, -8.3), Vector3(10, 2.2, 0.6)), "what": "wall"}]
	var blocked: VisibilityValidator.Sight = VisibilityValidator.look(framing, Rect2(), wall, stand, target)
	assert_false(blocked.centre_seen, "a 2.2 wall across the line hides the target")
	assert_has(blocked.misses, "wall")
	var kerb: Array[Dictionary] = [{"box": AABB(Vector3(-5, 0, -8.3), Vector3(10, 0.5, 0.6)), "what": "kerb"}]
	assert_true(VisibilityValidator.look(framing, Rect2(), kerb, stand, target).seen(framing.reveal_min_visible_share), "a kerb the line passes over hides nothing")
	var aside: VisibilityValidator.Sight = VisibilityValidator.look(framing, Rect2(), [], stand, Vector3(40, 0, -10))
	assert_false(aside.centre_seen, "off screen is not seen")
	assert_has(aside.misses, "off-band")


func test_conceal_holds_only_when_the_anchor_is_unseen() -> void:
	var result := VisibilityValidator.EdgeResult.new()
	result.intent = VisibilityValidator.INTENT_CONCEAL
	result.verdict = VisibilityValidator.VERDICT_UNSEEN
	assert_true(result.holds())
	result.verdict = VisibilityValidator.VERDICT_SEEN
	assert_false(result.holds())
	result.declared_mandatory = true
	assert_false(result.rejects(), "a relationship never asked never rejects")


# --- the fold: the locked door is the reveal ---------------------------------------------

func test_the_locked_door_is_seen_from_the_landmark_approach_and_the_relationship_is_enforced() -> void:
	var framing := _framing()
	for path: String in [SPIKES, GUARDED]:
		var recipe: FloorRecipe = load(path)
		for run_seed: int in [1, 7, 42]:
			var result := _compose(recipe, run_seed, framing)
			assert_true(result.report.succeeded(), result.report.summary())
			if not result.report.succeeded():
				return  # a fallback floor has no placed pieces to look at; the failure is already recorded
			var plan := _plan_of(result, run_seed)
			var certified: VisibilityValidator.Report = VisibilityValidator.check(recipe, result.draft, result.emit, plan, framing, _rules(), VisibilityValidator.ENFORCE_ALWAYS)
			var door: VisibilityValidator.EdgeResult = certified.edges[0]
			assert_eq(door.label(), "landmark.approach -> landmark.door_lock (reveal)")
			assert_true(door.holds(), "%s seed %d: door seen (%s)" % [recipe.recipe_id, run_seed, door.to_dict()])
			assert_true(door.mandatory(), "%s seed %d: enforceable: %s" % [recipe.recipe_id, run_seed, door.enforcement])
			assert_eq(result.report.visibility.size(), recipe.visibility.size(), "every edge reported on the returned floor")


func test_the_door_reveal_matches_the_drawn_lock_and_the_real_meshes() -> void:
	var framing := _framing()
	var recipe: FloorRecipe = load(GUARDED)
	# A seed whose exit is CONCEALED from the approach by a wall: the same look is then checked both
	# ways against real meshes -- the door clear, the pad blocked.
	var run_seed: int = -1
	var result: FloorComposer.ComposeResult = null
	for candidate: int in 40:
		result = _compose(recipe, candidate, framing)
		if not result.report.succeeded():
			continue
		var concealed: Dictionary = result.report.visibility[1]
		if concealed["holds"] and not (concealed["misses"] as Array).is_empty() and String(concealed["misses"][0]).begins_with("wall"):
			run_seed = candidate
			break
	assert_gt(run_seed, -1, "some seed conceals the exit behind a wall")
	if run_seed < 0:
		return
	var plan := _plan_of(result, run_seed)
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.run_seed = run_seed
	arena.itinerary = [DEPTH] as Array[int]
	arena.standalone = true
	arena.prepared_first_plan = plan
	add_child_autofree(arena)
	var builder: FloorBuilder = arena._floor_builder
	var landmark: FloorDraft.PieceInstance = result.draft.instances[recipe._index_of(&"landmark")]
	var receiver: int = result.emit.global_id(landmark.instance_id, &"trigger", 0)
	var lock: MeshInstance3D = builder.receiver_mesh(receiver)
	assert_not_null(lock, "the door's lock is drawn")
	var door: Dictionary = result.report.visibility[0]
	var anchor := Vector3(door["anchor"][0], door["anchor"][1], door["anchor"][2])
	var vantage := Vector3(door["vantage"][0], door["vantage"][1], door["vantage"][2])
	var lock_centre: Vector3 = lock.global_position
	assert_lt(anchor.distance_to(lock_centre), LOCK_TOLERANCE, "the authored anchor %s is the drawn lock %s" % [anchor, lock_centre])
	# The real camera, where FollowCamera puts it for an Envoy on the vantage.
	var camera: FollowCamera = arena._camera
	var target := Node3D.new()
	target.position = vantage
	add_child_autofree(target)
	camera.set_target(target)
	camera.snap_to_target()
	assert_almost_eq(camera.global_position, framing.camera_position(vantage, VisibilityValidator.extent_of(plan)), Vector3.ONE * POSITION_EPSILON)
	var root: Window = get_tree().root
	var restore: Vector2i = root.size
	root.size = Vector2i(framing.viewport_size)
	var screen: Vector2 = camera.unproject_position(lock_centre)
	root.size = restore
	assert_true(framing.in_safe_band(screen), "the drawn lock is inside the safe band on the real camera (%s)" % screen)
	gut.p("seed %d: anchor %s, drawn lock %s (%.2f apart), lock on screen at %s of %s" % [run_seed, anchor, lock_centre, anchor.distance_to(lock_centre), screen, framing.viewport_size])
	var gate: int = builder.receiver_gate(receiver)
	var excluded: Array = [lock, builder._gates.get(gate, null)]
	assert_eq(_mesh_blockers(builder, camera.global_position, lock_centre, excluded), [], "no drawn mesh stands between the camera and the lock")
	var pad := Vector3(result.report.visibility[1]["anchor"][0], result.report.visibility[1]["anchor"][1], result.report.visibility[1]["anchor"][2])
	assert_false(_mesh_blockers(builder, camera.global_position, pad, []).is_empty(), "the exit pad the validator calls walled off is walled off by real meshes")


## Every visible drawn mesh whose box the camera->point segment crosses, except those listed and
## any box the point itself sits in (the ground under a pad, the lock's own frame).
func _mesh_blockers(builder: Node, from: Vector3, to: Vector3, excluded: Array) -> Array:
	var found: Array = []
	var stack: Array[Node] = [builder]
	while not stack.is_empty():  # bounded: a finite scene tree, each node visited once
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var mesh := node as MeshInstance3D
		if mesh == null or not mesh.is_visible_in_tree() or mesh in excluded:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if box.grow(0.01).has_point(to):
			continue
		if box.intersects_segment(from, to) != null:
			found.append(mesh.name)
	return found


# --- the rejection rules -------------------------------------------------------------------

## The guarded recipe with its door anchor moved behind the east pillar (south face, low), and the
## door edge's other fields overridden. Pieces are duplicated: the loaded content is never touched.
func _with_hidden_anchor(fields: Dictionary) -> FloorRecipe:
	var source: FloorRecipe = load(GUARDED)
	var recipe: FloorRecipe = source.duplicate(true)
	var pieces: Array[FloorPiece] = []
	for piece: FloorPiece in source.pieces:
		var copy: FloorPiece = piece.duplicate(true)
		if piece.piece_id == &"archive_landmark_crossing_guarded":
			copy.port(&"door_lock").position = Vector3(3.5, 0.4, -12.4)
		pieces.append(copy)
	recipe.pieces = pieces
	var edges: Array[Dictionary] = []
	for edge: Dictionary in source.visibility:
		edges.append(edge.duplicate())
	edges[0].merge(fields, true)
	recipe.visibility = edges
	return recipe


func test_a_blocked_mandatory_reveal_rejects_every_attempt_deterministically() -> void:
	var framing := _framing()
	var recipe := _with_hidden_anchor({})
	var first := _compose(recipe, 7, framing)
	assert_true(first.report.fallback, "no attempt can show the door, so the floor falls back: %s" % first.report.summary())
	assert_eq(first.report.failing_validator, "VisibilityValidator")
	var exhausted: int = Array(first.report.log).filter(func(line: String) -> bool: return line.ends_with("search exhausted")).size()
	assert_gt(int(first.report.rejections.get(&"visibility_mandatory_unseen", 0)), 0)
	assert_eq(int(first.report.rejections.get(&"visibility_mandatory_unseen", 0)) + exhausted, recipe.reseed_budget + 1, "every attempt that emitted a floor was rejected for the reveal")
	var again := _compose(recipe, 7, framing)
	assert_eq(again.report.to_dict(), first.report.to_dict().merged({"elapsed_usec": again.report.elapsed_usec}, true), "the same seed rejects the same way")
	assert_eq(again.report.log, first.report.log)
	assert_string_contains("\n".join(first.report.log), "mandatory reveal landmark.approach -> landmark.door_lock (reveal) unseen")


func test_an_unseen_optional_reveal_is_reported_and_never_rejects() -> void:
	var framing := _framing()
	var recipe := _with_hidden_anchor({"mandatory": false})
	var plain := _compose(load(GUARDED), 7, framing)
	var result := _compose(recipe, 7, framing)
	assert_true(result.report.succeeded(), result.report.summary())
	if not result.report.succeeded():
		return
	assert_eq(result.report.spatial_signature(), plain.report.spatial_signature(), "the same floor as with the door in view")
	assert_false(result.report.visibility[0]["holds"], "reported unseen")
	assert_false(result.report.visibility[0]["mandatory"])


## An invalid mandatory declaration is never quietly demoted to an optional reveal (owner review,
## 2026-10-28): lint refuses it, and compose falls back STRUCTURALLY rather than composing a floor
## that pretends the promise holds.
func test_a_mandatory_reveal_of_a_door_no_key_locks_is_refused_never_optional() -> void:
	var framing := _framing()
	var recipe := _with_hidden_anchor({"door_port": &"side"})
	var rules: Array = recipe.lint().map(func(finding: Dictionary) -> StringName: return finding["rule"])
	assert_has(rules, &"visibility_mandatory_unenforceable", "an open connector is not a lockable door")
	var result := _compose(recipe, 7, framing)
	assert_true(result.report.fallback, "no floor is composed on an impossible promise")
	assert_true(result.report.structural, "a recipe fault, counted apart from seeds that fail to fit")
	assert_eq(result.report.failing_validator, "recipe lint")
	assert_eq(result.report.visibility, [], "no visibility is reported as if a floor had been judged")


## The piece-local half of the promise, rule by rule: the vantage and anchor ports exist, the door
## is a gate, and nothing but a key receiver opens it -- a toggle switch counts as an opener.
func test_the_declaration_lint_knows_what_makes_a_door_locked() -> void:
	var source: FloorPiece = null
	for piece: FloorPiece in (load(GUARDED) as FloorRecipe).pieces:
		if piece.piece_id == &"archive_landmark_crossing_guarded":
			source = piece
	assert_not_null(source)
	if source == null:
		return
	assert_eq(VisibilityValidator.declaration_fault(source, &"vantage", &"approach"), "")
	assert_eq(VisibilityValidator.declaration_fault(source, &"anchor", &"door_lock", &"out"), "", "the shipped door is locked by its receiver alone")
	assert_string_contains(VisibilityValidator.declaration_fault(source, &"vantage", &"door_lock"), "no vantage port")
	assert_string_contains(VisibilityValidator.declaration_fault(source, &"anchor", &"approach", &"out"), "no anchor port")
	assert_string_contains(VisibilityValidator.declaration_fault(source, &"anchor", &"door_lock", &"side"), "no gate port")
	var toggled: FloorPiece = source.duplicate(true)
	var lever := HitSwitchPlan.new()
	lever.key = &"S_BYPASS"
	lever.switch_id = 0
	lever.mode = HitSwitchPlan.MODE_TOGGLE
	lever.effects = [{"kind": FloorLayers.EFFECT_TOGGLE_CONNECTION, "target_key": &"@out"}] as Array[Dictionary]
	toggled.body.hit_switches = [lever] as Array[HitSwitchPlan]
	assert_string_contains(VisibilityValidator.declaration_fault(toggled, &"anchor", &"door_lock", &"out"), "switch S_BYPASS", "a toggle that opens the door makes it no lock")


func test_visibility_changes_nothing_on_a_floor_where_every_mandatory_reveal_holds() -> void:
	var framing := _framing()
	for path: String in [SPIKES, GUARDED]:
		var recipe: FloorRecipe = load(path)
		for run_seed: int in [1, 7, 42]:
			var without := FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, _radii(recipe))
			var with := _compose(recipe, run_seed, framing)
			assert_eq(with.report.spatial_signature(), without.report.spatial_signature(), "%s seed %d: same floor" % [recipe.recipe_id, run_seed])
			assert_eq(with.report.attempts, without.report.attempts)
			var again := _compose(recipe, run_seed, framing)
			assert_eq(again.report.visibility, with.report.visibility, "deterministic")


func test_the_recipe_lint_refuses_malformed_visibility() -> void:
	var source: FloorRecipe = load(GUARDED)
	var cases: Dictionary = {
		&"visibility_node_unknown": {"from": &"nowhere", "from_port": &"approach", "to": &"landmark", "to_port": &"door_lock"},
		&"visibility_endpoint_missing": {"from": &"landmark", "from_port": &"", "to": &"landmark", "to_port": &"door_lock"},
		&"visibility_intent_unknown": {"from": &"landmark", "from_port": &"approach", "to": &"landmark", "to_port": &"door_lock", "intent": &"glimpse"},
		&"visibility_conceal_mandatory": {"from": &"landmark", "from_port": &"approach", "to": &"exit", "to_port": &"pad", "intent": &"conceal", "mandatory": true, "door_port": &"out"},
		&"visibility_mandatory_without_door": {"from": &"landmark", "from_port": &"approach", "to": &"landmark", "to_port": &"door_lock", "mandatory": true},
	}
	assert_eq(source.lint(), [], "the shipped edges lint clean")
	for rule: StringName in cases:
		var recipe: FloorRecipe = source.duplicate()
		recipe.visibility = [cases[rule]] as Array[Dictionary]
		var rules: Array = recipe.lint().map(func(finding: Dictionary) -> StringName: return finding["rule"])
		assert_has(rules, rule, "lint names %s" % rule)
	# ADR O6: the piece that carries a mandatory reveal may not opt in to mirroring.
	var mirrored: FloorRecipe = source.duplicate()
	var pieces: Array[FloorPiece] = []
	for piece: FloorPiece in source.pieces:
		var copy: FloorPiece = piece.duplicate(true)
		if piece.piece_id == &"archive_landmark_crossing_guarded":
			copy.allowed_transforms = [&"identity", &"mirror_x"] as Array[StringName]
		pieces.append(copy)
	mirrored.pieces = pieces
	var found: Array = mirrored.lint().map(func(finding: Dictionary) -> StringName: return finding["rule"])
	assert_has(found, &"visibility_mandatory_mirrored", "a mirrorable piece cannot carry a mandatory reveal")
