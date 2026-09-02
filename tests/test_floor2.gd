extends GutTest
## FLOOR 2 BUILD CHECKS — the second authored floor, verified mechanically before human replay.
##
## THE GOVERNING QUESTION: can the same grammar produce a materially different convincing place
## without another foundational rewrite? Nothing in Floor 2 is a new primitive, so these assert
## that the SAME vocabulary carries a different composition -- and, since the 2026-09-02
## iteration, that each thing on the floor has a reason to be there.
##
## DRIVEN THROUGH THE REAL ARENA at depth 2, not through a hand-built SimWorld. A hand-built
## harness registers encounter SITES but never their ROSTERS -- the driver spawns those -- so an
## activation there resolves instantly to "cleared" against an empty roster and the response beat
## silently reads as broken. Same banked lesson as the AI probes: an instrument must be shown to
## be measuring the thing it claims.

const DT := 1.0 / 30.0
const L = preload("res://game/gen/layouts/archive_roundabout.gd")

var arena: Node3D
var sim: SimWorld
var plan: FloorPlan
var player: int


func before_each() -> void:
	arena = load("res://game/arena/arena.tscn").instantiate()
	# Set BEFORE add_child: _ready loads the floor, and depth is what selects the layout.
	arena.depth = 2
	add_child_autofree(arena)
	sim = arena.sim
	player = arena.envoy.actor_id
	plan = DepthGenerator.generate(arena.run_seed, arena.depth)
	# Traversal tests must measure traversal. Never a balance claim.
	sim.debug_override_health(player, 100000.0)


## Walks the Envoy to a point through the real move Command. Straight-line, no pathfinding --
## tests route through intermediate points, and a walk that fails because geometry is in the way
## is the geometry working.
func _walk_to(target: Vector3, max_ticks: int = 2000) -> bool:
	for i in max_ticks:
		var position: Vector3 = sim.entities[player]
		if position.distance_to(target) < 1.2:
			return true
		var direction: Vector3 = target - position
		direction.y = 0.0
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	return sim.entities[player].distance_to(target) < 1.2


## Walks ONTO a plate and lets the occupancy tick resolve. `_walk_to` stops within 1.2 units,
## which for a 2x2 plate can leave the Envoy beside it rather than on it -- the trigger then
## fires a moment later and the assertion reads a floor that has not changed yet.
func _stand_on(plate: Rect2) -> void:
	var centre: Vector3 = _centre(plate)
	for i in 2000:
		var position: Vector3 = sim.entities[player]
		if position.distance_to(centre) < 0.3:
			break
		var direction: Vector3 = centre - position
		direction.y = 0.0
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	sim.tick([] as Array[Command], DT)


func _centre(rect: Rect2) -> Vector3:
	return Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)


func _open(connection_id: int) -> bool:
	return bool(sim._connection_open[connection_id])


func _patch(patch_id: int) -> Rect2:
	return plan.patch_by_id(patch_id).rect


## Route B, the open first traversal: concourse -> route B -> junction.
func _take_route_b() -> void:
	assert_true(_walk_to(Vector3(0.0, 0.0, -32.0)), "into the concourse")
	assert_true(_walk_to(Vector3(10.0, 0.0, -44.0)), "toward the route B mouth")
	assert_true(_walk_to(Vector3(10.0, 0.0, -55.0)), "down route B")
	assert_true(_walk_to(Vector3(6.0, 0.0, -66.0)), "into the junction")


## The last leg, shared by several routes: west along the junction, up onto the terrace, exit.
func _finish_from_the_junction() -> void:
	assert_true(_walk_to(Vector3(-20.0, 0.0, -66.0)), "west along the junction")
	assert_true(_walk_to(Vector3(-20.0, 0.0, -76.0)), "up onto the terrace")
	_stand_on(L.EXIT_PLATE)


# --- THE FLOOR EXISTS AND IS DIFFERENT ------------------------------------------------------

func test_depth_two_authors_a_different_floor_from_depth_one() -> void:
	var floor_one: FloorPlan = DepthGenerator.generate(arena.run_seed, 1)
	assert_ne(plan.patches.size(), 0, "floor 2 has geometry")
	assert_ne(_centre(plan.patches[0].rect), _centre(floor_one.patches[0].rect),
		"depth 2 must author a materially different floor, not the same one again")


## THE M2 DETERMINISM LAW applies to authored floors too. An authored layout takes no RNG draws,
## so this is nearly free -- and it is exactly the assertion that would catch the day someone
## reaches for a random number inside a hand-built layout without noticing.
func test_depth_two_generation_is_deterministic() -> void:
	var first: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "\t")
	var second: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "\t")
	assert_eq(first, second, "the same seed and depth must produce a byte-identical floor 2")


# --- 1: END-TO-END COMPLETION, AND THE EXIT OWNS SYNCHRONISATION ------------------------------

## The whole floor, walked, using only player Commands. Note how short this is now: the
## intermediate party plate is gone, so arriving at the junction leads straight to the exit.
func test_the_floor_completes_end_to_end() -> void:
	_take_route_b()
	_finish_from_the_junction()
	assert_true(sim.debug_describe_floor()["floor_complete"], "and the floor completes")


## THE REDUNDANT BEAT IS GONE. One all-party requirement on the floor, not two in a row.
func test_the_exit_is_the_only_party_wide_requirement() -> void:
	var group_triggers: int = 0
	for trigger: FloorTrigger in plan.triggers:
		if trigger.kind == FloorLayers.TRIGGER_GROUP_OCCUPANCY:
			group_triggers += 1
	assert_eq(group_triggers, 1,
		"'everyone is here' must mean something; asking for it twice in a row means nothing")


## And the way to the terrace is simply open -- no plate stands between the junction and the exit.
func test_nothing_gates_the_walk_from_the_junction_to_the_exit() -> void:
	assert_true(_open(L.C_TO_TERRACE), "the terrace route starts open")
	_take_route_b()
	assert_true(_walk_to(Vector3(-20.0, 0.0, -66.0)))
	assert_true(_walk_to(Vector3(-20.0, 0.0, -76.0)), "walked without buying anything")
	assert_false(sim.debug_describe_floor()["floor_complete"],
		"arriving is still not finishing -- the exit plate remains the act")


# --- 2: THE FORK IS LEGIBLE -------------------------------------------------------------------

## THE HUMAN FINDING, pinned as geometry. The fork was structurally real and behaviourally
## invisible: the camera reaches ~34 units of width at the mouths' depth, and the mouths sat 46
## apart, so they could never appear together. The screen-space proof is a camera measurement
## (tools/measure_floor2_legibility.gd); this guards the world geometry that measurement rests
## on, so a later coordinate change cannot silently undo it.
func test_the_fork_mouths_are_close_enough_to_share_a_screen() -> void:
	var a: Rect2 = _patch(L.P_ROUTE_A)
	var b: Rect2 = _patch(L.P_ROUTE_B)
	var separation: float = b.get_center().x - a.get_center().x
	assert_lt(separation, 28.0,
		"mouths %.0f apart cannot both be on screen; a lateral choice only reads as a choice when both options fit the camera's reach" % separation)
	assert_gt(separation, 12.0, "but they must still read as two distinct ways, not one wide one")
	assert_almost_eq(a.get_center().x, -b.get_center().x, 0.01,
		"symmetric about the centre line, so neither route is merely the one you happen to face")


## THE MIDDLE MUST STAY A GAP, or the fork is decoration around continuous ground.
func test_the_two_routes_are_separated_by_real_void() -> void:
	assert_false(sim._bounds.is_inside(Vector3(0.0, 0.0, -55.0)),
		"the ground between the routes must not exist")
	assert_gt(_patch(L.P_ROUTE_B).position.x - _patch(L.P_ROUTE_A).end.x, 4.0,
		"and the void must be wide enough to read as one")


# --- 3: THE JUNCTION IS STILL VISIBLE BEFORE IT IS REACHABLE ----------------------------------

func test_the_concourse_to_junction_sightline_geometry_is_intact() -> void:
	var concourse: Rect2 = _patch(L.P_CONCOURSE)
	var junction: Rect2 = _patch(L.P_JUNCTION)
	assert_almost_eq(concourse.position.y, -46.0, 0.01, "the concourse's north edge is the observation line")
	assert_almost_eq(junction.end.y, -61.0, 0.01, "and the junction's near edge is what is seen")
	assert_almost_eq(concourse.position.y - junction.end.y, 15.0, 0.01,
		"the measured gap must not drift without re-measuring")
	assert_false(sim._bounds.is_inside(Vector3(0.0, 0.0, -53.0)),
		"the middle must stay unwalkable, or it is not visible-BEFORE-reachable")


func test_the_junction_cannot_be_reached_directly_across_the_gap() -> void:
	assert_true(_walk_to(Vector3(0.0, 0.0, -44.0)), "reach the concourse's north edge")
	for i in 400:
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": Vector3(0, 0, -1)})] as Array[Command], DT)
	assert_gt(sim.entities[player].z, -50.0,
		"walking straight at the junction must fail; the fork is the way round")


# --- 4: ROUTE B PROGRESSES WITHOUT BUYING ANYTHING --------------------------------------------

func test_route_b_reaches_the_exit_without_the_control() -> void:
	_take_route_b()
	assert_false(_open(L.C_TO_A), "the shortcut was never bought")
	assert_eq(String(sim._encounter_state.get(L.E_CONTROL_RESPONSE, "")), "dormant",
		"and nothing was woken")
	_finish_from_the_junction()
	assert_true(sim.debug_describe_floor()["floor_complete"], "the long way is a complete route")


# --- 5: ROUTE A IS GATED, AND THE CONTROL BUYS IT ---------------------------------------------

func test_route_a_is_closed_before_the_control() -> void:
	assert_false(_open(L.C_TO_A), "the shortcut must start shut")
	assert_true(_walk_to(Vector3(0.0, 0.0, -32.0)), "into the concourse")
	assert_false(_open(L.C_TO_A), "and stay shut until the control is used")


func test_the_control_opens_route_a_and_fires_once() -> void:
	_stand_on(L.CONTROL_PLATE)
	assert_true(_open(L.C_TO_A), "standing on it opens the shortcut")
	var fired: int = 0
	for i in 120:
		for event in sim.tick([] as Array[Command], DT):
			if event.kind == "floor_trigger_fired":
				fired += 1
	assert_eq(fired, 0, "a one-shot control must not re-fire while stood on")


## CAUSAL LEGIBILITY, pinned as geometry. The control charges no walking distance -- costing
## showed it cannot, because any detour big enough to feel like a price costs MORE than the
## shortcut saves. What it must do instead is sit where its purpose is visible: beside the mouth
## it opens.
func test_the_control_sits_beside_the_mouth_it_opens() -> void:
	var control: Vector3 = _centre(L.CONTROL_PLATE)
	var mouth := Vector3(_patch(L.P_ROUTE_A).get_center().x, 0.0, _patch(L.P_CONCOURSE).position.y)
	assert_lt(control.distance_to(mouth), 8.0,
		"the control must be in sight of what it buys, or the player cannot connect the two")


func test_route_a_is_walkable_once_opened() -> void:
	_stand_on(L.CONTROL_PLATE)
	assert_true(_walk_to(Vector3(-10.0, 0.0, -55.0)), "down route A")
	assert_true(_walk_to(Vector3(-20.0, 0.0, -66.0)), "and it lands in the junction's west end")


## THE FORK IS A REAL DECISION: Route A arrives materially nearer the exit than Route B does.
func test_route_a_is_materially_shorter_to_the_exit() -> void:
	var exit_point: Vector3 = _centre(L.EXIT_PLATE)
	var from_a: float = Vector3(_patch(L.P_ROUTE_A).get_center().x, 0.0, -61.0).distance_to(exit_point)
	var from_b: float = Vector3(_patch(L.P_ROUTE_B).get_center().x, 0.0, -61.0).distance_to(exit_point)
	assert_lt(from_a, from_b * 0.75,
		"route A must land materially closer (%.1f) than route B (%.1f) or the shortcut is a fiction" % [from_a, from_b])


# --- 6: THE PRICE STANDS WHERE THE SHORTCUT IS ------------------------------------------------

## THE 2026-09-02 RESEQUENCING. The response used to wake loose in the Concourse -- the room the
## player was already in and could walk away from -- so even its cost was soft. It now stands in
## Route A, so the price is paid by whoever actually takes the shortcut.
func test_the_response_belongs_to_the_route_it_guards() -> void:
	var response: EncounterSite = plan.encounter_by_id(L.E_CONTROL_RESPONSE)
	assert_eq(response.regions.size(), 1, "one rect is convex by construction, not by inspection")
	assert_eq(response.regions[0], _patch(L.P_ROUTE_A), "and that rect is the shortcut itself")
	for spawn in response.roster:
		var stats: Resource = ContentDB.get_resource(&"enemy", spawn["enemy_key"])
		assert_true(WalkableBounds.contains(_patch(L.P_ROUTE_A), spawn["position"].x, spawn["position"].z),
			"%s must stand in the route it is the price of" % spawn["enemy_key"])
		assert_true(sim._bounds.fits(spawn["position"], stats.combat_radius),
			"%s does not fit where it spawns" % spawn["enemy_key"])


func test_the_control_wakes_the_response_without_sealing_anyone_in() -> void:
	_stand_on(L.CONTROL_PLATE)
	assert_eq(String(sim._encounter_state.get(L.E_CONTROL_RESPONSE, "")), "active",
		"opening the shortcut must wake what guards it")
	for actor_id: int in sim._encounter_roster[L.E_CONTROL_RESPONSE]:
		assert_false(sim.debug_is_combat_absent(actor_id), "the response ARRIVES")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1,
		"but it must NOT seal the player in -- buying a shortcut is not a mandatory arena lock")


## AND THE PLAYER MAY DECLINE. Open the shortcut, look at what is standing in it, take the long
## way anyway. If that were impossible the "choice" would be a toll booth.
func test_the_player_may_open_route_a_and_still_take_route_b() -> void:
	_stand_on(L.CONTROL_PLATE)
	assert_eq(String(sim._encounter_state.get(L.E_CONTROL_RESPONSE, "")), "active")
	_take_route_b()
	_finish_from_the_junction()
	assert_true(sim.debug_describe_floor()["floor_complete"],
		"declining the shortcut after opening it must still finish the floor")


# --- 7: THE AMBIENT --------------------------------------------------------------------------

func test_the_ambient_home_is_convex_and_its_roster_fits() -> void:
	var ambient: EncounterSite = plan.encounter_by_id(L.E_CONCOURSE_AMBIENT)
	assert_eq(ambient.regions.size(), 1, "one rect is convex by construction, not by inspection")
	assert_eq(ambient.regions[0], _patch(L.P_CONCOURSE))
	for spawn in ambient.roster:
		var stats: Resource = ContentDB.get_resource(&"enemy", spawn["enemy_key"])
		assert_true(WalkableBounds.contains(_patch(L.P_CONCOURSE), spawn["position"].x, spawn["position"].z),
			"%s spawns outside the home that owns it" % spawn["enemy_key"])
		assert_true(sim._bounds.fits(spawn["position"], stats.combat_radius),
			"%s does not fit where it spawns" % spawn["enemy_key"])


# --- 8: THE VAULT IS AN EMPTY ROOM, HONESTLY ---------------------------------------------------

## Its fight asked for a detour, combat and risk and paid essentially nothing. Deactivated rather
## than given a faked reward. The room stays; the toll does not.
func test_the_vault_asks_for_nothing() -> void:
	assert_eq(plan.encounters.size(), 2, "ambient and the route-A response; no vault fight")
	for encounter: EncounterSite in plan.encounters:
		assert_ne(encounter.regions[0], _patch(L.P_VAULT), "no encounter lives in the vault")
	for trigger: FloorTrigger in plan.triggers:
		assert_false(WalkableBounds.contains(_patch(L.P_VAULT), trigger.region.get_center().x, trigger.region.get_center().y),
			"and no plate inside it asks the player to start one")


## But it is still a place, reachable and walkable.
func test_the_vault_is_still_a_room_you_can_enter() -> void:
	assert_true(_open(L.C_VAULT), "its mouth is open")
	_take_route_b()
	assert_true(_walk_to(Vector3(24.0, 0.0, -54.0)), "and the room can be walked into and looked at")


## THE BOUNDARY RATIONALE WENT WITH THE FIGHT. Mixed WALL/LEDGE existed to occlude an encounter
## that no longer happens here, and a validated capability is not entitled to survive without a
## consumer. Asserted so the zero-consumer audit reads code rather than memory.
func test_per_edge_boundary_overrides_now_have_no_authored_consumer() -> void:
	for depth in [1, 2]:
		for patch: WalkablePatch in DepthGenerator.generate(0, depth).patches:
			for side: StringName in [patch.boundary_north, patch.boundary_south, patch.boundary_east, patch.boundary_west]:
				assert_eq(side, &"", "depth %d patch %d still overrides a single edge" % [depth, patch.patch_id])


# --- 9: BOUNDARY AND GATE TRUTH ----------------------------------------------------------------

## Floor 2 is open ground: every patch edge is a ledge, so the only solid boundary comes from
## aperture flanks. The lip (2026-09-02) is what now makes those open edges read as intentional.
func test_the_floor_is_open_ground_with_readable_edges() -> void:
	assert_gt(plan.open_edge_segments().size(), 0, "the floor's open edges exist to be drawn")
	for segment in plan.solid_segments():
		assert_true(_is_aperture_flank(float(segment["at"]), segment["axis"]),
			"unexpected wall on axis %s at %.1f -- walls belong only where they earn it" % [segment["axis"], segment["at"]])


func _is_aperture_flank(at: float, axis: StringName) -> bool:
	for connection in plan.connections:
		var aperture: Rect2 = connection.aperture
		if axis == &"x" and (absf(at - aperture.position.x) < 0.01 or absf(at - aperture.end.x) < 0.01):
			return true
		if axis == &"z" and (absf(at - aperture.position.y) < 0.01 or absf(at - aperture.end.y) < 0.01):
			return true
	return false


## THE ROOT GATE FIXES STILL HOLD ON THE REAUTHORED FLOOR: the shut shortcut separates real
## ground, and its barrier lies across travel rather than along it.
func test_the_shut_shortcut_still_separates_and_is_oriented_correctly() -> void:
	assert_eq(sim.gate_barrier(L.C_TO_A)["axis"], &"z",
		"travel runs along z here, so the barrier must lie across x")
	var route_a: Rect2 = _patch(L.P_ROUTE_A)
	for x in [-15.0, -10.0, -5.0]:
		assert_false(sim._bounds.fits(Vector3(x, 0.0, route_a.end.y), 0.45),
			"nothing may stand in the shortcut's mouth at x=%.0f while it is shut" % x)
