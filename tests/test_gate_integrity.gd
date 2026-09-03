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
#
# THE DEFECT. The sim used to infer a closed gate's barrier orientation from the APERTURE'S
# proportions, assuming travel ran along its longer dimension. True for a corridor-shaped
# aperture; false for a DOORWAY-shaped one wider than it is deep. Floor 2 authored exactly that,
# so the barrier lay ALONG travel: a shot ran parallel to its own barrier and passed through a
# gate the player could see was shut, while presentation drew the box across the opening.
#
# THE ROOT FIX (ruled 2026-09-02) derives the barrier from the patches the connection joins.
# These fire real shots at real gates in BOTH aperture shapes, because the point of the fix is
# that shape no longer decides anything.


## Two rooms separated along `axis`, joined by an aperture of the given shape.
func _gate_fixture(separated_on_z: bool, doorway: bool, starts_open: bool) -> Dictionary:
	var near: Rect2 = Rect2(-10.0, -10.0, 20.0, 8.0) if separated_on_z else Rect2(-10.0, -10.0, 8.0, 20.0)
	var far: Rect2 = Rect2(-10.0, 2.0, 20.0, 8.0) if separated_on_z else Rect2(2.0, -10.0, 8.0, 20.0)
	# DOORWAY = wide across travel, shallow along it. CORRIDOR = the transpose.
	var aperture: Rect2
	if separated_on_z:
		aperture = Rect2(-6.0, -3.0, 12.0, 6.0) if doorway else Rect2(-2.5, -3.0, 5.0, 6.0)
	else:
		aperture = Rect2(-3.0, -6.0, 6.0, 12.0) if doorway else Rect2(-3.0, -2.5, 6.0, 5.0)

	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, near))
	plan.patches.append(_patch(1, far))
	plan.connections.append(_connection(0, 0, 1, aperture, starts_open))

	var sim := SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [near, far]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	sim.register_solid_segments(plan.solid_segments())
	sim.register_connection(0, aperture, starts_open)
	return {"sim": sim, "plan": plan, "separated_on_z": separated_on_z}


## Fires through the gate along the direction of travel. Returns whether the target was hit.
func _shoot_through(fixture: Dictionary) -> bool:
	var sim: SimWorld = fixture["sim"]
	var on_z: bool = fixture["separated_on_z"]
	var aim: Vector3 = Vector3(0, 0, 1) if on_z else Vector3(1, 0, 0)
	sim.add_entity(0, -aim * 5.0, 0.0, aim, 0.0)
	sim.register_combatant(0, 999.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(1, aim * 6.0, 0.0)
	sim.register_combatant(1, 100.0, &"fang", 0, 0.9, &"enemy")
	sim.register_gun(&"g", 10.0, &"force", 30.0, 600, 0.2, 0.0, 1)
	sim.set_equipped_weapon(0, &"g")
	var hit: bool = false
	for event in sim.tick([Command.new(sim.tick_count, 0, "attack", {"aim": aim})] as Array[Command], 1.0 / 30.0):
		hit = hit or event.kind == "hit"
	for i in 90:
		for event in sim.tick([] as Array[Command], 1.0 / 30.0):
			hit = hit or event.kind == "hit"
	return hit


## THE CASE THAT SHIPPED BROKEN: a doorway wider than it is deep.
func test_a_doorway_shaped_gate_blocks_when_closed() -> void:
	for on_z: bool in [true, false]:
		assert_false(_shoot_through(_gate_fixture(on_z, true, false)),
			"a shut doorway-shaped gate must stop the shot (travel along %s)" % ("z" if on_z else "x"))


func test_a_corridor_shaped_gate_blocks_when_closed() -> void:
	for on_z: bool in [true, false]:
		assert_false(_shoot_through(_gate_fixture(on_z, false, false)),
			"a shut corridor-shaped gate must stop the shot (travel along %s)" % ("z" if on_z else "x"))


## AND BOTH MUST PASS WHEN OPEN -- otherwise the fix is just a wall, and gate solidity would no
## longer derive from connection state.
func test_both_shapes_let_the_shot_through_when_open() -> void:
	for doorway: bool in [true, false]:
		for on_z: bool in [true, false]:
			assert_true(_shoot_through(_gate_fixture(on_z, doorway, true)),
				"an OPEN gate must obstruct nothing (%s, travel along %s)" % [
					"doorway" if doorway else "corridor", "z" if on_z else "x"])


## PRESENTATION AND SIM MUST AGREE ABOUT ORIENTATION. The mesh is built from the sim's own
## barrier, so this asserts the fact the mesh is built FROM -- the barrier lies across travel,
## whatever the aperture's shape. Drawing it across x regardless is exactly the old bug.
func test_the_barrier_lies_across_travel_for_every_aperture_shape() -> void:
	for doorway: bool in [true, false]:
		for on_z: bool in [true, false]:
			var sim: SimWorld = _gate_fixture(on_z, doorway, false)["sim"]
			var barrier: Dictionary = sim.gate_barrier(0)
			assert_false(barrier.is_empty(), "every registered connection must have a barrier")
			assert_eq(barrier["axis"], &"z" if on_z else &"x",
				"barrier must lie across travel (%s aperture, travel along %s)" % [
					"doorway" if doorway else "corridor", "z" if on_z else "x"])


func test_both_authored_floors_have_correctly_oriented_barriers() -> void:
	for depth in [1, 2]:
		var plan: FloorPlan = DepthGenerator.generate(0, depth)
		var sim := SimWorld.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		sim.load_floor(plan.make_bounds(), plan.entry_point)
		sim.register_patches(plan.patch_rects())
		for connection in plan.connections:
			sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
		for connection in plan.connections:
			var a: Rect2 = plan.patch_by_id(connection.patch_ids.x).rect
			var b: Rect2 = plan.patch_by_id(connection.patch_ids.y).rect
			var apart_on_z: bool = a.end.y < b.position.y or b.end.y < a.position.y
			var apart_on_x: bool = a.end.x < b.position.x or b.end.x < a.position.x
			if apart_on_z == apart_on_x:
				continue  # touching patches: an always-open connection, orientation is moot
			assert_eq(sim.gate_barrier(connection.connection_id)["axis"], &"z" if apart_on_z else &"x",
				"depth %d connection %d barrier must lie across travel" % [depth, connection.connection_id])


# --- 6: CONTROLS MUST NOT HIDE UNDER PERMANENT GEOMETRY (ruled 2026-09-04) ----------------------
#
# Floor 2 authored a plate overlapping a column, so it poked out from under something solid. The
# human read it exactly as it was -- an accident, not concealment. The distinction the guard
# encodes: GOOD concealment hides a control behind something REMOVABLE, so finding it is an
# action; clipping under permanent geometry is a mistake that happens to be partly visible.

func _floor_with_control_at(region: Rect2, obstacle_rect: Rect2) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, Rect2(-20.0, -20.0, 40.0, 40.0)))
	var obstacle := ObstaclePlan.new()
	obstacle.obstacle_id = 0
	obstacle.rect = obstacle_rect
	plan.obstacles.append(obstacle)
	var trigger := FloorTrigger.new()
	trigger.trigger_id = 0
	trigger.kind = FloorLayers.TRIGGER_REGION
	trigger.region = region
	trigger.renders_as_plate = true
	trigger.effects = [] as Array[Dictionary]
	plan.triggers.append(trigger)
	return plan


func test_a_plate_overlapping_a_permanent_obstacle_is_reported() -> void:
	_floor_with_control_at(Rect2(-1.0, -1.0, 2.0, 2.0), Rect2(-2.0, -2.0, 3.0, 3.0)).validate()
	assert_push_error("overlaps permanent obstacle")


func test_a_plate_clear_of_obstacles_passes() -> void:
	_floor_with_control_at(Rect2(8.0, 8.0, 2.0, 2.0), Rect2(-2.0, -2.0, 3.0, 3.0)).validate()
	assert_push_error_count(0)


## THE EXEMPTION IS THE POINT, not an oversight: hiding a control behind something the player can
## CLEAR is the intended vocabulary, and a guard that refused it would forbid the good case with
## the bad one.
func test_concealment_behind_a_removable_blocker_is_allowed() -> void:
	var plan: FloorPlan = _floor_with_control_at(Rect2(-1.0, -1.0, 2.0, 2.0), Rect2(30.0, 30.0, 2.0, 2.0))
	var rubble := BreakablePlan.new()
	rubble.breakable_id = 0
	rubble.position = Vector3(0.0, 0.0, 0.0)
	rubble.radius = 1.5
	rubble.blocking_rect = Rect2(-2.0, -2.0, 4.0, 4.0)
	plan.breakables.append(rubble)
	plan.validate()
	assert_push_error_count(0, "a control behind something removable is concealment, not a defect")


func test_a_switch_buried_in_an_obstacle_is_reported() -> void:
	var plan: FloorPlan = _floor_with_control_at(Rect2(20.0, 20.0, 2.0, 2.0), Rect2(-2.0, -2.0, 4.0, 4.0))
	var buried := HitSwitchPlan.new()
	buried.switch_id = 0
	buried.position = Vector3(0.0, 0.0, 0.0)
	plan.hit_switches.append(buried)
	plan.validate()
	assert_push_error("unhittable, not hidden")


func test_both_authored_floors_keep_their_controls_clear() -> void:
	for depth in [1, 2]:
		DepthGenerator.generate(0, depth)
		assert_push_error_count(0, "depth %d hides a control under permanent geometry" % depth)
