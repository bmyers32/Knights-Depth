extends GutTest
## FLOOR 2 BUILD CHECKS — the second authored floor, verified mechanically before human replay.
##
## THE GOVERNING QUESTION: can the same grammar produce a materially different convincing place
## without another foundational rewrite? Nothing in Floor 2 is a new primitive, so these assert
## that the SAME vocabulary carries a different composition -- and that the fork is a real
## decision rather than a decorative split.
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


## Route B, the open first traversal: concourse -> route B -> junction -> party plate.
func _take_route_b() -> void:
	assert_true(_walk_to(_centre(_patch(L.P_CONCOURSE))), "into the concourse")
	assert_true(_walk_to(Vector3(22.0, 0.0, -42.0)), "toward the route B mouth")
	assert_true(_walk_to(Vector3(23.0, 0.0, -55.0)), "down route B")
	assert_true(_walk_to(Vector3(20.0, 0.0, -66.0)), "into the junction")


# --- THE FLOOR EXISTS AND IS DIFFERENT ------------------------------------------------------

func test_depth_two_authors_a_different_floor_from_depth_one() -> void:
	var floor_one: FloorPlan = DepthGenerator.generate(arena.run_seed, 1)
	assert_ne(plan.patches.size(), 0, "floor 2 has geometry")
	assert_ne(_centre(plan.patches[0].rect), _centre(floor_one.patches[0].rect),
		"depth 2 must author a materially different floor, not the same one again")
	assert_eq(plan.encounters.size(), 3, "ambient, control response, and the optional vault")


## THE M2 DETERMINISM LAW applies to authored floors too. An authored layout takes no RNG draws,
## so this is nearly free -- and it is exactly the assertion that would catch the day someone
## reaches for a random number inside a hand-built layout without noticing.
func test_depth_two_generation_is_deterministic() -> void:
	var first: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "	")
	var second: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "	")
	assert_eq(first, second, "the same seed and depth must produce a byte-identical floor 2")


# --- 1: END-TO-END COMPLETION ---------------------------------------------------------------

## The whole floor, walked, using only player Commands.
func test_the_floor_completes_end_to_end() -> void:
	_take_route_b()
	_stand_on(L.PARTY_PLATE)
	assert_true(_open(L.C_TO_TERRACE), "party-sync opens the terrace route")
	_stand_on(L.EXIT_PLATE)
	assert_true(sim.debug_describe_floor()["floor_complete"], "and the floor completes")


# --- 2: ROUTE B PROGRESSES WITHOUT THE VAULT -------------------------------------------------

## THE OPTIONAL ENCOUNTER MUST BE OPTIONAL IN GEOMETRY, not merely in metadata.
func test_route_b_reaches_the_junction_without_entering_the_vault() -> void:
	_take_route_b()
	assert_eq(String(sim._encounter_state.get(L.E_VAULT, "")), "dormant",
		"the vault fight must not have started")
	for actor_id: int in sim._encounter_roster.get(L.E_VAULT, []):
		assert_true(sim.debug_is_combat_absent(actor_id), "its roster must still be waiting")
	assert_true(_walk_to(_centre(L.PARTY_PLATE)), "and the floor still progresses")
	assert_true(_open(L.C_TO_TERRACE))


func test_the_vault_never_seals_anyone_in() -> void:
	var vault: EncounterSite = plan.encounter_by_id(L.E_VAULT)
	assert_false(vault.confines_player, "an optional fight must never lock the player in")
	assert_eq(vault.role, FloorLayers.ROLE_OPTIONAL)
	assert_false(vault.spawn_at_floor_load, "and it arrives on opt-in, not at load")


# --- 3 & 4: ROUTE A IS GATED, AND THE CONTROL OPENS IT ONCE ----------------------------------

func test_route_a_is_closed_before_the_control() -> void:
	assert_false(_open(L.C_TO_A), "the shortcut must start shut")
	assert_true(_walk_to(_centre(_patch(L.P_CONCOURSE))), "into the concourse")
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


# --- 5: THE CONTROL RESPONSE ------------------------------------------------------------------

func test_the_control_wakes_a_local_non_sealing_response() -> void:
	_stand_on(L.CONTROL_PLATE)
	assert_eq(String(sim._encounter_state.get(L.E_CONTROL_RESPONSE, "")), "active",
		"opening the shortcut must wake something")
	for actor_id: int in sim._encounter_roster[L.E_CONTROL_RESPONSE]:
		assert_false(sim.debug_is_combat_absent(actor_id), "the response ARRIVES")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1,
		"but it must NOT seal the player in -- buying the shortcut is not a combat lock")


## And the shortcut is genuinely usable afterwards.
func test_route_a_is_walkable_once_opened() -> void:
	_stand_on(L.CONTROL_PLATE)
	assert_true(_walk_to(Vector3(-22.0, 0.0, -42.0)), "toward the route A mouth")
	assert_true(_walk_to(Vector3(-23.0, 0.0, -55.0)), "down route A")
	_stand_on(L.PARTY_PLATE)
	assert_true(_open(L.C_TO_TERRACE), "and route A lands beside the party plate")


## THE FORK IS A REAL DECISION: route A arrives far nearer the destination than route B does.
## That asymmetry is what makes the control worth using, and it is geometry rather than assertion.
func test_route_a_is_materially_shorter_to_the_party_plate() -> void:
	var destination: Vector3 = _centre(L.PARTY_PLATE)
	var from_a: float = Vector3(-23.0, 0.0, -61.0).distance_to(destination)
	var from_b: float = Vector3(23.0, 0.0, -61.0).distance_to(destination)
	assert_lt(from_a, from_b * 0.5,
		"route A must land far closer (%.1f) than route B (%.1f) or the shortcut is a fiction" % [from_a, from_b])


# --- 6 & 7: PARTY SYNC AND EXIT ---------------------------------------------------------------

func test_the_terrace_is_gated_until_party_sync() -> void:
	_take_route_b()
	assert_false(_open(L.C_TO_TERRACE), "the terrace must be earned")
	_stand_on(L.PARTY_PLATE)
	assert_true(_open(L.C_TO_TERRACE))


func test_the_exit_requires_the_plate_not_merely_the_terrace() -> void:
	_take_route_b()
	_stand_on(L.PARTY_PLATE)
	assert_true(_walk_to(Vector3(-20.0, 0.0, -76.0)), "step onto the terrace")
	assert_false(sim.debug_describe_floor()["floor_complete"], "arriving is not finishing")
	_stand_on(L.EXIT_PLATE)
	assert_true(sim.debug_describe_floor()["floor_complete"], "standing on the exit finishes it")


# --- 8: THE AMBIENT UNDER REAL AUTHORED GEOMETRY ----------------------------------------------

## Its home must be CONVEX, which P33 requires and a single rect guarantees.
func test_the_ambient_home_is_convex() -> void:
	var ambient: EncounterSite = plan.encounter_by_id(L.E_CONCOURSE_AMBIENT)
	assert_eq(ambient.regions.size(), 1, "one rect is convex by construction, not by inspection")
	assert_eq(ambient.regions[0], _patch(L.P_CONCOURSE))


func test_the_ambient_roster_fits_and_binds_to_its_home() -> void:
	for spawn in plan.encounter_by_id(L.E_CONCOURSE_AMBIENT).roster:
		var stats: Resource = ContentDB.get_resource(&"enemy", spawn["enemy_key"])
		assert_true(_patch(L.P_CONCOURSE).has_point(Vector2(spawn["position"].x, spawn["position"].z)),
			"%s spawns outside the home that owns it" % spawn["enemy_key"])
		assert_true(sim._bounds.fits(spawn["position"], stats.combat_radius),
			"%s does not fit where it spawns" % spawn["enemy_key"])


# --- 9 & 10: BOUNDARY TRUTH --------------------------------------------------------------------

## THE VAULT is the per-edge vocabulary's first shipped consumer: solid inward for occlusion,
## open on the exposed map-facing side.
func test_the_vault_derives_a_mixed_boundary() -> void:
	var vault: Rect2 = _patch(L.P_VAULT)
	var west: bool = false
	var east: bool = false
	for segment in plan.solid_segments():
		if segment["axis"] != &"x":
			continue
		if absf(float(segment["at"]) - vault.position.x) < 0.01:
			west = true
		if absf(float(segment["at"]) - vault.end.x) < 0.01:
			east = true
	assert_true(west, "the vault's inward side must be SOLID so the fight cannot be shot into")
	assert_false(east, "and its exposed map-facing side must be OPEN")


## Everything else is open: Floor 2 must not recreate Floor 1's early walls-everywhere look.
func test_only_the_vault_contributes_solid_boundary() -> void:
	var vault: Rect2 = _patch(L.P_VAULT)
	for segment in plan.solid_segments():
		var at: float = float(segment["at"])
		var near_vault: bool = (segment["axis"] == &"x" and absf(at - vault.position.x) < 0.01) \
			or (segment["axis"] == &"z" and (absf(at - vault.position.y) < 0.01 or absf(at - vault.end.y) < 0.01))
		assert_true(near_vault or _is_aperture_flank(at, segment["axis"]),
			"unexpected wall on axis %s at %.1f -- walls belong only where they earn it" % [segment["axis"], at])


func _is_aperture_flank(at: float, axis: StringName) -> bool:
	for connection in plan.connections:
		var aperture: Rect2 = connection.aperture
		if axis == &"x" and (absf(at - aperture.position.x) < 0.01 or absf(at - aperture.end.x) < 0.01):
			return true
		if axis == &"z" and (absf(at - aperture.position.y) < 0.01 or absf(at - aperture.end.y) < 0.01):
			return true
	return false


# --- 11: THE VISIBLE-BEFORE-REACHABLE LINE ------------------------------------------------------

## The measured beat was: standing at the CONCOURSE north edge, the JUNCTION is visible across the
## gap. This pins the WORLD GEOMETRY that measurement depended on, so a later coordinate change
## cannot silently invalidate it -- the camera reading was taken against exactly this line.
func test_the_concourse_to_junction_sightline_geometry_is_intact() -> void:
	var concourse: Rect2 = _patch(L.P_CONCOURSE)
	var junction: Rect2 = _patch(L.P_JUNCTION)
	assert_almost_eq(concourse.position.y, -46.0, 0.01, "the concourse' north edge is the observation line")
	assert_almost_eq(junction.end.y, -61.0, 0.01, "and the junction's near edge is what is seen")
	var gap: float = concourse.position.y - junction.end.y
	assert_almost_eq(gap, 15.0, 0.01, "the measured gap must not drift without re-measuring")
	# And it must be a GAP: no walkable ground between them on the centre line.
	assert_false(sim._bounds.is_inside(Vector3(0.0, 0.0, -53.0)),
			"the middle must stay unwalkable, or it is not visible-BEFORE-reachable")


func test_the_junction_cannot_be_reached_directly_across_the_gap() -> void:
	assert_true(_walk_to(Vector3(0.0, 0.0, -44.0)), "reach the concourse' north edge")
	for i in 400:
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": Vector3(0, 0, -1)})] as Array[Command], DT)
	assert_gt(sim.entities[player].z, -50.0,
		"walking straight at the junction must fail; the fork is the way round")
