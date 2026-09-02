extends GutTest
## PER-EDGE BOUNDARY STYLE (ruled 2026-09-01).
##
## WHY THIS CAPABILITY EXISTS. Patch-level `boundary_style` was FALSIFIED BY AUTHORING: the hall
## wants an open outer perimeter AND a solid void-facing interior, and both belong to the same
## rectangle. Applying `ledge` at patch granularity reopened the P34 sequence break -- the
## concealed crate became shootable across the void, and two tests went red, correctly.
##
## SPLITTING PATCHES TO FAKE IT WAS REJECTED: walkable patches describe walkable SPACE, boundary
## style describes boundary SEMANTICS, and neither should impersonate the other.
##
## THE SINGLE-SOURCE LAW IS UNCHANGED. Overrides feed the SAME canonical exact-segment derivation
## that sim and presentation both read. There is no presentation-only and no projectile-only
## override anywhere.

const SOLO := Rect2(-10.0, -10.0, 20.0, 20.0)


func _patch(rect: Rect2, style: StringName = &"wall", sides: Dictionary = {}) -> WalkablePatch:
	var patch := WalkablePatch.new()
	patch.patch_id = 0
	patch.rect = rect
	patch.boundary_style = style
	patch.boundary_north = sides.get("north", &"")
	patch.boundary_south = sides.get("south", &"")
	patch.boundary_east = sides.get("east", &"")
	patch.boundary_west = sides.get("west", &"")
	return patch


func _plan_of(patches: Array) -> FloorPlan:
	var plan := FloorPlan.new()
	for patch in patches:
		plan.patches.append(patch)
	return plan


## Does a solid segment exist on this side of the solo patch?
func _has_side(plan: FloorPlan, axis: StringName, at: float, outward: float) -> bool:
	for segment in plan.solid_segments():
		if segment["axis"] == axis and absf(float(segment["at"]) - at) < 0.001 \
				and absf(float(segment["outward"]) - outward) < 0.001:
			return true
	return false


# --- 1: default compatibility ---------------------------------------------------------------

## A patch with NO overrides must derive exactly what it did before the capability existed.
func test_a_patch_without_overrides_is_unchanged() -> void:
	var plan: FloorPlan = _plan_of([_patch(SOLO)])
	assert_eq(plan.solid_segments().size(), 4, "an isolated walled patch still has four solid sides")


func test_a_wholly_ledged_patch_is_still_wholly_open() -> void:
	var plan: FloorPlan = _plan_of([_patch(SOLO, &"ledge")])
	assert_eq(plan.solid_segments().size(), 0, "patch-level ledge must still open every side")


# --- 2 & 3: one side, then mixed -------------------------------------------------------------

func test_one_side_override_changes_only_that_side() -> void:
	var plan: FloorPlan = _plan_of([_patch(SOLO, &"wall", {"north": &"ledge"})])
	assert_eq(plan.solid_segments().size(), 3, "exactly one side opens")
	assert_false(_has_side(plan, &"z", SOLO.end.y, 1.0), "the north side is open")
	assert_true(_has_side(plan, &"z", SOLO.position.y, -1.0), "the south side is untouched")
	assert_true(_has_side(plan, &"x", SOLO.position.x, -1.0), "west untouched")
	assert_true(_has_side(plan, &"x", SOLO.end.x, 1.0), "east untouched")


## THE CASE THE CAPABILITY EXISTS FOR: one rectangle, two semantics.
func test_one_patch_can_be_open_on_one_side_and_solid_on_another() -> void:
	var plan: FloorPlan = _plan_of([_patch(SOLO, &"wall", {"north": &"ledge", "east": &"ledge"})])
	assert_false(_has_side(plan, &"z", SOLO.end.y, 1.0), "north open")
	assert_false(_has_side(plan, &"x", SOLO.end.x, 1.0), "east open")
	assert_true(_has_side(plan, &"z", SOLO.position.y, -1.0), "south solid")
	assert_true(_has_side(plan, &"x", SOLO.position.x, -1.0), "west solid")


## The inverse authoring: a ledge patch made solid on one side.
func test_a_ledge_patch_can_be_made_solid_on_one_side() -> void:
	var plan: FloorPlan = _plan_of([_patch(SOLO, &"ledge", {"south": &"wall"})])
	assert_eq(plan.solid_segments().size(), 1, "only the overridden side is solid")
	assert_true(_has_side(plan, &"z", SOLO.position.y, -1.0), "and it is the south one")


# --- 4: internal seams stay invisible --------------------------------------------------------

## An override on a side that is INSIDE the walkable union must not conjure a boundary there.
## Style is only ever evaluated for spans that survive union derivation.
func test_an_override_on_an_internal_seam_creates_no_boundary() -> void:
	# Two patches meeting along x = 0; each patch's facing side is interior.
	var west: WalkablePatch = _patch(Rect2(-10.0, -5.0, 10.0, 10.0), &"wall")
	var east: WalkablePatch = _patch(Rect2(0.0, -5.0, 10.0, 10.0), &"wall")
	east.patch_id = 1
	var plan: FloorPlan = _plan_of([west, east])
	assert_false(_has_side(plan, &"x", 0.0, 1.0), "the shared seam must not become a wall")
	assert_false(_has_side(plan, &"x", 0.0, -1.0), "from either side")


# --- 5 & 6: both consumers read the same fact ------------------------------------------------

## PROJECTILE SEMANTICS. A wall side stops a shot; a ledge side does not. Same geometry, same
## bounds -- only the authored word differs.
func test_a_wall_side_blocks_and_a_ledge_side_does_not() -> void:
	for style: StringName in [&"wall", &"ledge"]:
		var near := Rect2(-20.0, -5.0, 10.0, 10.0)
		var far := Rect2(10.0, -5.0, 10.0, 10.0)
		var a: WalkablePatch = _patch(near, &"wall", {"east": style})
		var b: WalkablePatch = _patch(far, &"wall", {"west": style})
		b.patch_id = 1
		var plan: FloorPlan = _plan_of([a, b])

		var sim := SimWorld.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		var rects: Array[Rect2] = [near, far]
		sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
		sim.register_patches(rects)
		sim.register_solid_segments(plan.solid_segments())
		sim.add_entity(0, Vector3(-18.0, 0.0, 0.0), 0.0, Vector3(1, 0, 0))
		sim.register_combatant(0, 999.0, &"envoy", 0, 0.0, &"player")
		sim.add_entity(1, Vector3(15.0, 0.0, 0.0), 0.0)
		sim.register_combatant(1, 100.0, &"fang", 0, 0.5, &"enemy")
		sim.register_gun(&"g", 10.0, &"force", 30.0, 600, 0.2, 0.0, 1)
		sim.set_equipped_weapon(0, &"g")

		var hit: bool = false
		for event in sim.tick([Command.new(sim.tick_count, 0, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], 1.0 / 30.0):
			hit = hit or event.kind == "hit"
		for i in 60:
			for event in sim.tick([] as Array[Command], 1.0 / 30.0):
				hit = hit or event.kind == "hit"
		if style == &"wall":
			assert_false(hit, "a WALL side must stop the shot")
		else:
			assert_true(hit, "a LEDGE side must let it through")


## PRESENTATION reads the same segments, so an opened side simply is not there to draw. Asserted
## through the canonical list rather than through meshes, because that list IS what it draws.
func test_presentation_and_sim_read_the_same_boundary_fact() -> void:
	var plan: FloorPlan = _plan_of([_patch(SOLO, &"wall", {"north": &"ledge"})])
	var segments: Array[Dictionary] = plan.solid_segments()
	assert_eq(segments.size(), 3,
		"one derived list feeds both consumers; there is no presentation-only or projectile-only view")


# --- 7: the shipped roundabout ---------------------------------------------------------------

## THE AUTHORED RESULT, updated 2026-09-01: the roundabout is now FULLY open. The void-facing
## ring came off with the outer perimeter, because it was protecting a content law the human
## rejected -- ranged probing of the crate across the void is intentional.
##
## The capability this file exists for is unchanged and still exercised by the fixtures above;
## what changed is that FLOOR 1 no longer needs a mixed-side patch.
##
## THE ZERO-CONSUMER QUESTION IS NOW CLOSED (2026-09-02): Floor 2's Vault is the first shipped
## consumer -- solid on its inward sides so the optional fight cannot be farmed by shooting in
## from the gallery, LEDGE on its exposed map-facing side, one rectangle with two meanings. The
## override vocabulary therefore survives the same rule that retired the `switch` interactable,
## on evidence rather than on anticipation. Asserted in tests/test_floor2.gd.
func test_the_authored_roundabout_is_fully_open() -> void:
	var plan: FloorPlan = DepthGenerator.generate(0, 1)
	for segment in plan.solid_segments():
		var at: float = float(segment["at"])
		var vertical: bool = segment["axis"] == &"x"
		# No hall boundary of any kind survives -- outer perimeter or void ring.
		assert_false(vertical and (absf(absf(at) - 16.0) < 0.01 or absf(absf(at) - 8.0) < 0.01)
				and float(segment["min"]) > -34.5 and float(segment["max"]) < -11.5,
			"hall boundary at x=%.1f should be open" % at)
		assert_false(not vertical and (absf(at + 12.0) < 0.01 or absf(at + 16.0) < 0.01
				or absf(at + 28.0) < 0.01 or absf(at + 34.0) < 0.01),
			"hall boundary at z=%.1f should be open" % at)


# --- 8: determinism ---------------------------------------------------------------------------

func test_boundary_derivation_is_deterministic() -> void:
	var first: Array[Dictionary] = DepthGenerator.generate(0, 1).solid_segments()
	var second: Array[Dictionary] = DepthGenerator.generate(0, 1).solid_segments()
	assert_eq(first.size(), second.size(), "the same plan must derive the same number of segments")
	for i in first.size():
		assert_eq(first[i], second[i], "segment %d must be identical, including its style" % i)


# --- 9: the open-edge lip (2026-09-02) ---------------------------------------------------------
#
# `ledge` used to render as NOTHING, so an authored open edge and a wall that was never built
# were the same picture -- an absence. Floor 2's Vault read as an unfinished room for exactly
# that reason. open_edge_segments() exists so presentation can draw a low rim there.
#
# THE POINT OF THESE TESTS IS THAT NO LAW MOVED. A picture was added to a fact that already
# existed, and the guarantees below are what "presentation only" has to mean.

func test_open_edges_are_the_exact_complement_of_solid_ones() -> void:
	var plan: FloorPlan = _plan_of([_patch(SOLO, &"wall", {"north": &"ledge", "east": &"ledge"})])
	assert_eq(plan.solid_segments().size(), 2, "two sides stay solid")
	assert_eq(plan.open_edge_segments().size(), 2, "and the other two are open edges")
	for open_edge in plan.open_edge_segments():
		for solid in plan.solid_segments():
			assert_false(open_edge["axis"] == solid["axis"] and absf(float(open_edge["at"]) - float(solid["at"])) < 0.001
					and absf(float(open_edge["outward"]) - float(solid["outward"])) < 0.001,
				"no span may be both a wall and an open edge")


func test_a_fully_walled_patch_has_no_open_edges_and_the_inverse() -> void:
	assert_eq(_plan_of([_patch(SOLO, &"wall")]).open_edge_segments().size(), 0)
	assert_eq(_plan_of([_patch(SOLO, &"ledge")]).solid_segments().size(), 0)
	assert_eq(_plan_of([_patch(SOLO, &"ledge")]).open_edge_segments().size(), 4,
		"a wholly open patch has four rims to draw")


## INTERNAL SEAMS STAY INVISIBLE for open edges exactly as they do for walls -- the lip must not
## appear along a join inside the walkable union, or every floor grows fences through its middle.
func test_an_internal_seam_produces_no_lip() -> void:
	var west: WalkablePatch = _patch(Rect2(-10.0, -5.0, 10.0, 10.0), &"ledge")
	var east: WalkablePatch = _patch(Rect2(0.0, -5.0, 10.0, 10.0), &"ledge")
	east.patch_id = 1
	var plan: FloorPlan = _plan_of([west, east])
	for open_edge in plan.open_edge_segments():
		assert_false(open_edge["axis"] == &"x" and absf(float(open_edge["at"])) < 0.001,
			"the shared seam must not grow a rim")


## THE SIM NEVER SEES THEM. A lip that reached the sim would be a new boundary type by the back
## door -- the exact thing the ruling forbade.
func test_the_lip_stops_no_shot_and_bounds_no_body() -> void:
	var room := Rect2(-10.0, -5.0, 20.0, 10.0)
	var plan: FloorPlan = _plan_of([_patch(room, &"ledge")])
	var sim := SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [room]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	# The driver hands over solid_segments() ONLY. Registering open edges is not possible by
	# accident: there is no path for them into the sim at all.
	sim.register_solid_segments(plan.solid_segments())
	assert_eq(plan.open_edge_segments().size(), 4, "the rims exist for presentation")

	sim.add_entity(0, Vector3(-8.0, 0.0, 0.0), 0.0, Vector3(1, 0, 0))
	sim.register_combatant(0, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(1, Vector3(8.0, 0.0, 0.0), 0.0)
	sim.register_combatant(1, 100.0, &"fang", 0, 0.5, &"enemy")
	sim.register_gun(&"g", 10.0, &"force", 30.0, 600, 0.2, 0.0, 1)
	sim.set_equipped_weapon(0, &"g")
	var hit: bool = false
	for event in sim.tick([Command.new(sim.tick_count, 0, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], 1.0 / 30.0):
		hit = hit or event.kind == "hit"
	for i in 60:
		for event in sim.tick([] as Array[Command], 1.0 / 30.0):
			hit = hit or event.kind == "hit"
	assert_true(hit, "an open edge must still stop no shot -- the lip is a picture, not a wall")
	assert_false(sim._bounds.fits(Vector3(11.0, 0.0, 0.0), 0.5),
		"and legality is unchanged: it never came from these segments either way")
