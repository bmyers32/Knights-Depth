extends GutTest
## CLOSED-GATE INTEGRITY (ruled 2026-09-02, after Floor 2's human replay).
##
## THE DEFECT THIS EXISTS FOR. A closed connection claims to separate two patches, and nothing
## checked that it does. Closing a gate removes its aperture from the walkable union and
## subtracts NOTHING, so two patches that also touch each other stay joined across their own
## seam whether the gate is open or shut. Floor 2 shipped two such gates. A walk straight south
## entered the "gated" shortcut without ever finding its control, and `_connection_open == false`
## reported the gate shut the entire time -- the flag was true and meaningless.
##
## WHY TOUCHING IS ENOUGH. Walkable edges are INCLUSIVE and legality is BODY-AWARE against the
## UNION, so a body straddling the seam of two abutting rects is covered by both halves and fits.
## "Zero shared area" does not mean "not connected" once bodies exist.
##
## THE GUARD IS FLOOR-INDEPENDENT. Floor 2 was merely the first firing; these fixtures are
## synthetic so the invariant cannot quietly become a property of one authored floor.

const RADIUS := 0.45  # the shipped Envoy body


func _patch(patch_id: int, rect: Rect2) -> WalkablePatch:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	patch.boundary_style = &"ledge"
	return patch


func _connection(connection_id: int, near_id: int, far_id: int, aperture: Rect2, starts_open: bool) -> TraversalConnection:
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = aperture
	connection.starts_open = starts_open
	return connection


## Two patches and one gate between them. `standoff` is the gap the aperture must bridge:
## 0.0 reproduces the defect (they abut), 2.0 is the fix.
func _two_room_plan(standoff: float, starts_open: bool = false) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, Rect2(-10.0, -10.0, 20.0, 10.0)))
	plan.patches.append(_patch(1, Rect2(-10.0, standoff, 20.0, 10.0)))
	# Overlaps both, whatever the standoff.
	plan.connections.append(_connection(0, 0, 1, Rect2(-2.5, -1.5, 5.0, 3.0 + standoff), starts_open))
	return plan


# --- 1: THE DEFECT REPRODUCES ------------------------------------------------------------

func test_a_gate_between_touching_patches_is_reported() -> void:
	var plan: FloorPlan = _two_room_plan(0.0)
	plan.validate()
	assert_push_error("patches 0 and 1 touch directly")


## And it is a real bypass, not merely a rule violation: the union spans the seam with the gate
## shut, which is the fact the guard exists to stand in for.
func test_the_reported_gate_really_is_bypassable() -> void:
	var plan: FloorPlan = _two_room_plan(0.0)
	var shut := WalkableBounds.new(plan.open_walkable_rects({0: false}))
	assert_true(shut.fits(Vector3(8.0, 0.0, 0.0), RADIUS),
		"a body may stand on the seam far from the aperture while the gate is shut")
	assert_true(shut.fits(Vector3(8.0, 0.0, 1.0), RADIUS), "and continue through to the far patch")


# --- 2: THE FIX -----------------------------------------------------------------------------

func test_a_gate_bridging_a_real_gap_passes() -> void:
	var plan: FloorPlan = _two_room_plan(2.0)
	plan.validate()
	assert_push_error_count(0)


func test_the_passing_gate_really_does_separate() -> void:
	var plan: FloorPlan = _two_room_plan(2.0)
	var shut := WalkableBounds.new(plan.open_walkable_rects({0: false}))
	for x in [-9.0, -4.0, 0.0, 4.0, 9.0]:
		assert_false(shut.fits(Vector3(x, 0.0, 1.0), RADIUS),
			"nothing may stand in the far patch's mouth at x=%.1f while the gate is shut" % x)
	var open_bounds := WalkableBounds.new(plan.open_walkable_rects({0: true}))
	assert_true(open_bounds.fits(Vector3(0.0, 0.0, 1.0), RADIUS), "and opening it lets the body through")


# --- 3: SCOPE -------------------------------------------------------------------------------

## AN ALWAYS-OPEN CONNECTION IS EXEMPT. It never claims to separate anything, so abutting
## patches there are ordinary continuous ground rather than a broken promise.
func test_an_always_open_connection_is_not_required_to_separate() -> void:
	var plan: FloorPlan = _two_room_plan(0.0, true)
	plan.validate()
	assert_push_error_count(0)


## A ONE-WAY COMMITMENT starts OPEN and is blocked later. A commitment that seals nothing is
## exactly the same defect, so closability is read from the effects too, never from the flag alone.
func test_a_connection_blocked_by_a_later_effect_is_still_checked() -> void:
	var plan: FloorPlan = _two_room_plan(0.0, true)
	var trigger := FloorTrigger.new()
	trigger.trigger_id = 0
	trigger.kind = FloorLayers.TRIGGER_REGION
	trigger.region = Rect2(-1.0, -1.0, 2.0, 2.0)
	trigger.effects = [FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, 0)]
	plan.triggers.append(trigger)
	plan.validate()
	assert_push_error("patches 0 and 1 touch directly")


## THE LIMIT, ASSERTED SO IT IS NOT MISTAKEN FOR A PROOF OF GLOBAL SEPARATION. Routes that fork
## and rejoin are legitimate grammar -- Floor 2's own two routes rejoin at the junction -- so
## "reachable the long way round" must NOT fail authoring. The guard proves only that a gate is
## the sole DIRECT adjacency between its two patches.
func test_a_route_reachable_the_long_way_round_is_not_a_failure() -> void:
	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, Rect2(-10.0, -10.0, 8.0, 8.0)))    # start
	plan.patches.append(_patch(1, Rect2(-10.0, 2.0, 8.0, 8.0)))      # gated destination
	plan.patches.append(_patch(2, Rect2(-2.0, -10.0, 8.0, 20.0)))    # the long way round, touching both
	plan.connections.append(_connection(0, 0, 1, Rect2(-8.0, -3.0, 4.0, 7.0), false))
	plan.validate()
	assert_push_error_count(0)


# --- 4: THE SHIPPED FLOORS ---------------------------------------------------------------------

func test_both_authored_floors_pass_the_guard() -> void:
	for depth in [1, 2]:
		DepthGenerator.generate(0, depth)  # validate() runs inside generate
		assert_push_error_count(0, "authored floor at depth %d must have no bypassable gate" % depth)


## THE FLOOR 2 REGRESSION, behavioural rather than structural: walk at the gated shortcut without
## ever finding its control and confirm the floor refuses. This is the exact human finding.
func test_floor_two_route_a_cannot_be_entered_without_the_control() -> void:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.depth = 2
	add_child_autofree(arena)
	var L: GDScript = load("res://game/gen/layouts/archive_roundabout.gd")
	var plan: FloorPlan = DepthGenerator.generate(arena.run_seed, 2)
	var route_a: Rect2 = plan.patch_by_id(L.P_ROUTE_A).rect
	var envoy_id: int = arena.envoy.actor_id
	arena.sim.debug_override_health(envoy_id, 100000.0)

	var target := Vector3(-21.0, 0.0, -54.0)
	for i in 1500:
		var position: Vector3 = arena.sim.entities[envoy_id]
		assert_false(WalkableBounds.contains(route_a, position.x, position.z),
			"the Envoy reached the gated route at %s without ever touching its control" % position)
		var direction: Vector3 = target - position
		direction.y = 0.0
		if direction.length() < 0.3:
			break
		arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": direction.normalized()})] as Array[Command], 1.0 / 30.0)
	assert_false(bool(arena.sim._connection_open[L.C_TO_A]), "and the gate was shut the whole time")


# --- 5: THE BARRIER MUST LIE ACROSS TRAVEL -----------------------------------------------------

## A DOORWAY-SHAPED aperture (wider than deep) between patches separated along z gets a barrier
## running ALONG the travel direction. A shot then runs parallel to its own barrier and passes
## through the shut gate, while presentation draws the box across the opening -- the picture and
## the rule disagreeing, which P34 forbids. Floor 2 shipped exactly this.
func test_a_doorway_wider_than_it_is_deep_is_reported() -> void:
	var plan: FloorPlan = _two_room_plan(2.0)
	plan.connections[0].aperture = Rect2(-6.0, -1.5, 12.0, 5.0)  # 12 wide, 5 deep; travel is z
	plan.validate()
	assert_push_error("lies ALONG the direction of travel")


func test_a_corridor_deeper_than_it_is_wide_passes() -> void:
	var plan: FloorPlan = _two_room_plan(2.0)
	plan.connections[0].aperture = Rect2(-2.5, -1.5, 5.0, 5.0)
	plan.validate()
	assert_push_error_count(0)


## THE GUARD RESTATES SimWorld._gate_segment's rule from gen/, because gen/ must not import sim/.
## A second copy that silently drifts is worse than no check, so the two are pinned together
## here: shoot at a shut gate the guard accepts, and at one it rejects, and require the sim to
## agree with the guard both times.
func test_the_guard_and_the_sim_agree_about_which_gates_stop_a_shot() -> void:
	for deep: bool in [true, false]:
		var near := Rect2(-10.0, -10.0, 20.0, 10.0)
		var far := Rect2(-10.0, 2.0, 20.0, 10.0)
		var aperture: Rect2 = Rect2(-2.5, -1.5, 5.0, 5.0) if deep else Rect2(-6.0, -1.5, 12.0, 5.0)
		var plan := FloorPlan.new()
		plan.patches.append(_patch(0, near))
		plan.patches.append(_patch(1, far))
		plan.connections.append(_connection(0, 0, 1, aperture, false))

		var sim := SimWorld.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		var rects: Array[Rect2] = [near, far]
		sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
		sim.register_patches(rects)
		sim.register_solid_segments(plan.solid_segments())
		sim.register_connection(0, aperture, false)
		sim.add_entity(0, Vector3(0.0, 0.0, -3.0), 0.0, Vector3(0, 0, 1), 0.0)
		sim.register_combatant(0, 999.0, &"envoy", 0, 0.0, &"player")
		sim.add_entity(1, Vector3(0.0, 0.0, 5.0), 0.0)
		sim.register_combatant(1, 100.0, &"fang", 0, 0.9, &"enemy")
		sim.register_gun(&"g", 10.0, &"force", 30.0, 600, 0.2, 0.0, 1)
		sim.set_equipped_weapon(0, &"g")

		var hit: bool = false
		for event in sim.tick([Command.new(sim.tick_count, 0, "attack", {"aim": Vector3(0, 0, 1)})] as Array[Command], 1.0 / 30.0):
			hit = hit or event.kind == "hit"
		for i in 90:
			for event in sim.tick([] as Array[Command], 1.0 / 30.0):
				hit = hit or event.kind == "hit"
		if deep:
			assert_false(hit, "the shape the guard ACCEPTS must really stop a shot")
		else:
			assert_true(hit, "and the shape it REJECTS must really leak one -- otherwise the guard is superstition")


func test_both_authored_floors_have_correctly_oriented_barriers() -> void:
	for depth in [1, 2]:
		DepthGenerator.generate(0, depth)
		assert_push_error_count(0, "authored floor at depth %d must have no misoriented gate barrier" % depth)
