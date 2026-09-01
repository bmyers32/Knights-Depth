extends GutTest
## P34 — PROJECTILE-VS-WORLD OBSTRUCTION. The nine pre-registered tests plus the two riders.
##
## THE DEFECT: shots passed through solid walls. With folded topology that is not cosmetic --
## a player could hit enemies, breakables and progression controls in areas they had not reached.
##
## THE LAWS UNDER TEST:
##   - ONE authored WALL/LEDGE fact, consumed by sim AND presentation. No second wall model.
##   - Solid wall and CLOSED gate stop a shot; an open LEDGE edge does not.
##   - Nearest valid impact wins by parametric t, across actors, breakables and world.
##   - WORLD -> BREAKABLE -> ACTOR resolves EXACT TIES ONLY. It is a determinism rule for
##     degenerate geometry, never a gameplay priority.
##   - Sim authority only: no Godot physics, no mesh, no raycast decides any of this.
##
## SYNTHETIC FIXTURE GEOMETRY -- mechanical law only, never shipped tuning.

const SHOOTER := 0
const TARGET := 1
const DT := 1.0 / 30.0

## TWO ROOMS WITH NO ROUTE BETWEEN THEM. The gap is void, so each room's facing edge is solid.
## "The far room" is literally an area the shooter has not reached.
const NEAR_ROOM := Rect2(-20.0, -5.0, 10.0, 10.0)   # x[-20,-10]
const FAR_ROOM := Rect2(10.0, -5.0, 10.0, 10.0)     # x[10,20]

var sim: SimWorld


func _patch(patch_id: int, rect: Rect2, style: StringName = &"wall") -> WalkablePatch:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	patch.boundary_style = style
	return patch


## Builds a real FloorPlan and hands the sim ITS canonical segments -- the same call
## presentation makes. A test that hand-wrote segments would prove nothing about the shared fact.
func _load(patches: Array, connections: Array = []) -> FloorPlan:
	var plan := FloorPlan.new()
	for patch in patches:
		plan.patches.append(patch)
	for connection in connections:
		plan.connections.append(connection)
	var rects: Array[Rect2] = plan.patch_rects()
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(plan.make_bounds(), Vector3.ZERO)
	sim.register_patches(rects)
	sim.register_solid_segments(plan.solid_segments())
	for connection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
	return plan


func _two_rooms() -> void:
	_load([_patch(0, NEAR_ROOM), _patch(1, FAR_ROOM)])


## A gun that fires once, travels fast enough to cross a room in a few ticks, and hits hard.
func _arm_shooter(at: Vector3, lifetime_ticks: int = 600) -> void:
	sim.add_entity(SHOOTER, at, 0.0, Vector3(1, 0, 0))
	sim.register_combatant(SHOOTER, 999.0, &"envoy", 0, 0.0, &"player")
	sim.register_gun(&"test_gun", 10.0, &"force", 30.0, lifetime_ticks, 0.2, 0.0, 1)
	sim.set_equipped_weapon(SHOOTER, &"test_gun")


func _fire_east() -> Array[Event]:
	var events: Array[Event] = sim.tick(
		[Command.new(sim.tick_count, SHOOTER, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT)
	for i in 60:
		events.append_array(sim.tick([] as Array[Command], DT))
	return events


func _kinds(events: Array[Event]) -> Array:
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	return kinds


func _end_reason(events: Array[Event]) -> String:
	for event in events:
		if event.kind == "projectile_expired":
			return String(event.payload.get("reason", ""))
	return ""


# --- 1 & 2: actor vs wall, both orders ----------------------------------------------------

func test_an_actor_clearly_before_the_wall_is_hit() -> void:
	_two_rooms()
	_arm_shooter(Vector3(-18.0, 0.0, 0.0))
	sim.add_entity(TARGET, Vector3(-13.0, 0.0, 0.0), 0.0)
	sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")

	var events: Array[Event] = _fire_east()
	assert_true(_kinds(events).has("hit"), "an actor in the open path must still be hit")
	assert_lt(sim._health[TARGET], 100.0, "and take the damage")


func test_a_wall_clearly_before_an_actor_stops_the_shot() -> void:
	_two_rooms()
	_arm_shooter(Vector3(-18.0, 0.0, 0.0))
	# The target stands in the FAR room -- behind a solid boundary, in ground never reached.
	sim.add_entity(TARGET, Vector3(15.0, 0.0, 0.0), 0.0)
	sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")

	var events: Array[Event] = _fire_east()
	assert_false(_kinds(events).has("hit"), "the wall must stop the shot")
	assert_eq(sim._health[TARGET], 100.0, "and the far actor must be untouched")
	assert_eq(_end_reason(events), "world", "termination provenance must say the world stopped it")


# --- 3 & 4: breakable vs wall, both orders ------------------------------------------------

func test_a_breakable_before_the_wall_is_hit_and_stops_the_shot() -> void:
	_two_rooms()
	_arm_shooter(Vector3(-18.0, 0.0, 0.0))
	sim.register_breakable(0, Vector3(-13.0, 0.0, 0.0), 0.6, 1.0)

	var events: Array[Event] = _fire_east()
	assert_true(_kinds(events).has("breakable_destroyed"), "a prop in the open path still stops it")
	assert_eq(_end_reason(events), "", "and needs no termination reason: its own event explains it")


func test_a_wall_before_a_breakable_stops_the_shot_and_spares_the_prop() -> void:
	_two_rooms()
	_arm_shooter(Vector3(-18.0, 0.0, 0.0))
	sim.register_breakable(0, Vector3(15.0, 0.0, 0.0), 0.6, 1.0)

	var events: Array[Event] = _fire_east()
	assert_false(_kinds(events).has("breakable_hit"), "the wall must stop it first")
	assert_true(sim._breakables.has(0), "and the unreached prop must survive")
	assert_eq(_end_reason(events), "world")


# --- 5: the tie ---------------------------------------------------------------------------

## AN ACTOR FLUSH WITH THE WALL. Its contact plane and the boundary coincide, so both candidates
## report the same t. The pinned order must resolve it the same way every time -- that is the
## whole job of the rule, and it is NOT a claim that walls matter more than actors.
func test_an_actor_flush_with_the_wall_resolves_deterministically_to_the_world() -> void:
	for attempt in 2:
		_two_rooms()
		_arm_shooter(Vector3(-18.0, 0.0, 0.0))
		# Centre exactly on the boundary with no body: contact plane == wall plane.
		sim.add_entity(TARGET, Vector3(-10.0, 0.0, 0.0), 0.0)
		sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.0, &"enemy")

		var events: Array[Event] = _fire_east()
		assert_eq(_end_reason(events), "world", "a tie resolves to WORLD, on every run")
		assert_eq(sim._health[TARGET], 100.0, "so the flush actor takes nothing")


# --- 6: an open ledge is not a projectile blocker -----------------------------------------

## THE WALL/LEDGE DISTINCTION, in one assertion. Identical geometry, identical bounds, one
## authored word different -- and the shot behaves differently while MOVEMENT LEGALITY DOES NOT.
func test_an_open_ledge_boundary_does_not_stop_a_shot() -> void:
	_load([_patch(0, NEAR_ROOM, &"ledge"), _patch(1, FAR_ROOM, &"ledge")])
	_arm_shooter(Vector3(-18.0, 0.0, 0.0))
	sim.add_entity(TARGET, Vector3(15.0, 0.0, 0.0), 0.0)
	sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")

	var events: Array[Event] = _fire_east()
	assert_true(_kinds(events).has("hit"), "a ledge is bounded for BODIES and transparent to shots")
	assert_lt(sim._health[TARGET], 100.0)


func test_a_ledge_still_bounds_a_body() -> void:
	_load([_patch(0, NEAR_ROOM, &"ledge")])
	sim.add_entity(TARGET, Vector3(-15.0, 0.0, 0.0), 6.0, Vector3(1, 0, 0), 0.5)
	sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")
	for i in 200:
		sim.tick([Command.new(sim.tick_count, TARGET, "move", {"direction": Vector3(1, 0, 0)})] as Array[Command], DT)
	assert_true(sim._bounds.fits(sim.entities[TARGET], 0.5),
		"rendering no wall must never mean the actor can walk off the ledge")


# --- 7 & 8: gates, both states -------------------------------------------------------------

func _rooms_joined_by(starts_open: bool) -> void:
	var connection := TraversalConnection.new()
	connection.connection_id = 0
	connection.patch_ids = Vector2i(0, 1)
	connection.aperture = Rect2(-11.5, -2.5, 23.0, 5.0)  # overlaps both rooms
	connection.starts_open = starts_open
	_load([_patch(0, NEAR_ROOM), _patch(1, FAR_ROOM)], [connection])


func test_a_closed_gate_stops_a_shot() -> void:
	_rooms_joined_by(false)
	_arm_shooter(Vector3(-18.0, 0.0, 0.0))
	sim.add_entity(TARGET, Vector3(15.0, 0.0, 0.0), 0.0)
	sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")

	var events: Array[Event] = _fire_east()
	assert_false(_kinds(events).has("hit"), "a closed route is a physical barrier to shots too")
	assert_eq(_end_reason(events), "world")


func test_the_same_connection_open_lets_the_shot_through() -> void:
	_rooms_joined_by(true)
	_arm_shooter(Vector3(-18.0, 0.0, 0.0))
	sim.add_entity(TARGET, Vector3(15.0, 0.0, 0.0), 0.0)
	sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")

	var events: Array[Event] = _fire_east()
	assert_true(_kinds(events).has("hit"),
		"the SAME geometry with the route open must pass -- gate solidity derives from connection state")


# --- 9: no sequence-breaking shot ----------------------------------------------------------

## RETIRED AS A FLOOR-1 ASSERTION 2026-09-01 — human ruling, recorded rather than silently
## weakened.
##
## This once asserted that the concealed crate could not be shot across the hall void. That
## content law is FALSIFIED: making a player walk the whole ring only to learn a breakable was
## empty is friction without discovery, so ranged probing across that void is now INTENTIONAL.
##
## THE MECHANIC IS NOT REOPENED. What changed is one floor's authored expectation, not P34: WALL
## still blocks, LEDGE still does not, canonical segments remain the shared truth, and
## nearest-impact/tie semantics are untouched. Those are pinned by the fixture tests above, which
## is where the mechanic always belonged -- this test was really asserting an AUTHORING decision
## while wearing a mechanic's name.
##
## It survives, rewritten, as the thing still worth guarding: a WALL on the shipped floor still
## stops a shot. The hall no longer supplies one, so it asks the arena instead.
func test_a_shipped_wall_still_stops_a_shot() -> void:
	var plan: FloorPlan = DepthGenerator.generate(0, 1)
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	sim.register_solid_segments(plan.solid_segments())
	for connection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
	var crate: BreakablePlan = plan.breakables[0]
	sim.register_breakable(crate.breakable_id, crate.position, crate.radius, crate.durability)

	# Stand deep in the ARENA and shoot at the far wall: solid geometry the floor still authors.
	var from := Vector3(-10.0, 0.0, -60.0)
	sim.add_entity(SHOOTER, from, 0.0, Vector3(0, 0, -1))
	sim.register_combatant(SHOOTER, 999.0, &"envoy", 0, 0.0, &"player")
	sim.register_gun(&"test_gun", 10.0, &"force", 30.0, 600, 0.2, 0.0, 1)
	sim.set_equipped_weapon(SHOOTER, &"test_gun")

	var events: Array[Event] = sim.tick(
		[Command.new(sim.tick_count, SHOOTER, "attack", {"aim": Vector3(-1, 0, 0)})] as Array[Command], DT)
	for i in 120:
		events.append_array(sim.tick([] as Array[Command], DT))

	var reason: String = ""
	for event in events:
		if event.kind == "projectile_expired":
			reason = String(event.payload.get("reason", ""))
	assert_eq(reason, "world", "a shot into the arena's west wall must still be stopped by the world")
	assert_true(sim._breakables.has(crate.breakable_id),
		"and nothing behind that wall is touched")


# --- RIDER 1: the closed termination-reason enum -------------------------------------------

## AUDITED, THEN CLOSED. Four paths destroy a projectile: breakable impact, actor impact,
## lifetime expiry and floor unload. Only the last two need provenance -- the first two are
## completely explained by their own authoritative hit events, which already carry the
## projectile id, and floor unload emits nothing at all.
func test_the_termination_reason_enum_is_closed() -> void:
	assert_eq(SimWorld.PROJECTILE_END_REASONS.size(), 2,
		"exactly two reasons have real consumers; a new one needs a consumer and a schema change")
	assert_true(SimWorld.PROJECTILE_END_REASONS.has(&"lifetime"))
	assert_true(SimWorld.PROJECTILE_END_REASONS.has(&"world"))


func test_lifetime_expiry_carries_the_lifetime_reason() -> void:
	# A ledge room stops nothing, so a SHORT-LIVED shot leaves and simply runs out.
	_load([_patch(0, NEAR_ROOM, &"ledge")])
	_arm_shooter(Vector3(-18.0, 0.0, 0.0), 20)
	var events: Array[Event] = _fire_east()
	assert_eq(_end_reason(events), "lifetime", "a shot that simply ran out must say so")


func test_every_emitted_termination_reason_is_in_the_closed_enum() -> void:
	# Drives all three observable shapes -- world stop, lifetime expiry, actor impact -- and
	# asserts no free-form reason can escape into the event stream.
	var seen: Array = []
	for scenario in ["world", "lifetime", "actor"]:
		if scenario == "lifetime":
			_load([_patch(0, NEAR_ROOM, &"ledge")])
			_arm_shooter(Vector3(-18.0, 0.0, 0.0), 20)
		else:
			_two_rooms()
			_arm_shooter(Vector3(-18.0, 0.0, 0.0))
		if scenario == "actor":
			sim.add_entity(TARGET, Vector3(-13.0, 0.0, 0.0), 0.0)
			sim.register_combatant(TARGET, 100.0, &"fang", 0, 0.5, &"enemy")
		for event in _fire_east():
			if event.kind == "projectile_expired":
				seen.append(event.payload.get("reason", &""))
	assert_gt(seen.size(), 0, "sanity: the scenarios produced terminations")
	for reason in seen:
		assert_true(SimWorld.PROJECTILE_END_REASONS.has(reason),
			"'%s' is not in the closed enum" % reason)


# --- RIDER 2: ambient territories carry no interior obstruction ----------------------------

## AN INSTRUMENT FOR ASSUMPTION DRIFT, not a permanent prohibition. P33's v1 constraint keeps
## ambient territories convex, which is why P34 introduces no new internal cover into them. If a
## future floor quietly puts a solid boundary inside an ambient territory while that constraint
## still claims to hold, this fails and the two laws get reconciled deliberately.
##
## PERIMETER CONTACT IS ALLOWED -- a territory bounded by walls is normal and expected. Only
## boundary that cuts through the INTERIOR counts.
func test_no_solid_segment_intrudes_into_an_ambient_territory() -> void:
	var plan: FloorPlan = DepthGenerator.generate(0, 1)
	var segments: Array[Dictionary] = plan.solid_segments()
	for encounter in plan.encounters_of_role(FloorLayers.ROLE_AMBIENT):
		for region: Rect2 in encounter.regions:
			for segment in segments:
				assert_false(_cuts_interior(segment, region),
					"segment %s cuts the interior of ambient territory %s" % [segment, region])


## Strictly inside on the normal axis, and overlapping with real length along the other.
func _cuts_interior(segment: Dictionary, region: Rect2) -> bool:
	var inset: float = 0.001
	var vertical: bool = segment["axis"] == &"x"
	var at: float = float(segment["at"])
	var normal_low: float = region.position.x if vertical else region.position.y
	var normal_high: float = region.end.x if vertical else region.end.y
	if at <= normal_low + inset or at >= normal_high - inset:
		return false  # on (or outside) the perimeter, which is allowed
	var span_low: float = region.position.y if vertical else region.position.x
	var span_high: float = region.end.y if vertical else region.end.x
	var overlap: float = minf(float(segment["max"]), span_high) - maxf(float(segment["min"]), span_low)
	return overlap > inset
