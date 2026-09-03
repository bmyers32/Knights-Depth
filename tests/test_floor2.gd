extends GutTest
## FLOOR 2 BUILD CHECKS — the production-scale floor (rebuilt 2026-09-03).
##
## THE GOVERNING QUESTION has moved on. It is no longer only "can the grammar produce a second
## convincing place", but "does this read as a plausible FULL floor rather than a mechanics test
## map" -- which means the entry must not reveal the whole thing, and its combat spaces must be
## authored around the environment rather than sharing a room with it.
##
## DRIVEN THROUGH THE REAL ARENA at depth 2. A hand-built harness registers encounter SITES but
## never their ROSTERS -- the driver spawns those -- so an activation there resolves instantly to
## "cleared" against an empty roster and a working beat silently reads as broken.

const DT := 1.0 / 30.0
const L = preload("res://game/gen/layouts/archive_roundabout.gd")

var arena: Node3D
var sim: SimWorld
var plan: FloorPlan
var player: int


func before_each() -> void:
	arena = load("res://game/arena/arena.tscn").instantiate()
	arena.depth = 2
	add_child_autofree(arena)
	sim = arena.sim
	player = arena.envoy.actor_id
	plan = DepthGenerator.generate(arena.run_seed, arena.depth)
	# Traversal tests must measure traversal, never survivability. Never a balance claim.
	sim.debug_override_health(player, 1000000.0)


func _walk_to(target: Vector3, max_ticks: int = 3000) -> bool:
	for i in max_ticks:
		sim.debug_override_health(player, 1000000.0)
		var position: Vector3 = sim.entities[player]
		if position.distance_to(target) < 1.4:
			return true
		var direction: Vector3 = target - position
		direction.y = 0.0
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	return sim.entities[player].distance_to(target) < 1.4


func _stand_on(plate: Rect2) -> void:
	var centre: Vector3 = _centre(plate)
	for i in 3000:
		sim.debug_override_health(player, 1000000.0)
		if sim.entities[player].distance_to(centre) < 0.3:
			break
		var direction: Vector3 = centre - sim.entities[player]
		direction.y = 0.0
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	sim.tick([] as Array[Command], DT)


func _centre(rect: Rect2) -> Vector3:
	return Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)


func _patch(patch_id: int) -> Rect2:
	return plan.patch_by_id(patch_id).rect


func _open(connection_id: int) -> bool:
	return bool(sim._connection_open[connection_id])


func _state(encounter_id: int) -> String:
	return String(sim._encounter_state.get(encounter_id, ""))


## Down to the Gallery the western way. Waypoints, not pathfinding: a walk that fails because
## geometry is in the way is the geometry working.
func _descend_via_thicket() -> void:
	assert_true(_walk_to(Vector3(0.0, 0.0, -26.0)), "down the ramp into the landing")
	assert_true(_walk_to(Vector3(-10.0, 0.0, -32.0)), "west across the landing")
	assert_true(_walk_to(Vector3(-10.0, 0.0, -40.0)), "into the thicket")
	assert_true(_walk_to(Vector3(-19.5, 0.0, -52.0)), "across it, south of the rubble")
	assert_true(_walk_to(Vector3(-19.5, 0.0, -60.0)), "and on into the gallery")


func _descend_via_spillway() -> void:
	assert_true(_walk_to(Vector3(0.0, 0.0, -26.0)), "down the ramp into the landing")
	assert_true(_walk_to(Vector3(11.0, 0.0, -32.0)), "east across the landing")
	assert_true(_walk_to(Vector3(11.0, 0.0, -40.0)), "into the spillway")
	assert_true(_walk_to(Vector3(22.0, 0.0, -48.0)), "round the slow lane, clear of the spikes")
	assert_true(_walk_to(Vector3(18.5, 0.0, -60.0)), "and on into the gallery")


func _finish_from_the_gallery() -> void:
	assert_true(_walk_to(Vector3(10.0, 0.0, -78.0)), "down route B")
	assert_true(_walk_to(Vector3(10.0, 0.0, -90.0)), "into the junction")
	assert_true(_walk_to(Vector3(-20.0, 0.0, -92.0)), "west along it")
	assert_true(_walk_to(Vector3(-20.0, 0.0, -102.0)), "up onto the terrace")
	_stand_on(L.EXIT_PLATE)


# --- 1: THE FLOOR IS A SEQUENCE, NOT A ROOM WITH A FORK ----------------------------------------

func test_the_floor_has_production_scale_beat_density() -> void:
	assert_gte(plan.patches.size(), 9, "a production floor is a sequence of spaces")
	assert_gte(plan.spike_pads.size(), 1, "with a hazard")
	assert_gte(plan.obstacles.size(), 4, "obstacle composition")
	assert_gte(plan.breakables.size(), 2, "destructibles")
	assert_eq(plan.hit_switches.size(), 1, "and a remote switch")
	assert_gte(plan.encounters.size(), 4, "with several encounters rather than one")


## THE ENTRY MUST NOT REVEAL THE FLOOR. Asserted as the geometry the claim rests on: the spaces
## that carry the later beats are far beyond anything the Overlook looks at, and the two middle
## branches do not overlap in x, so standing in one shows nothing of the other.
func test_the_entry_cannot_see_the_later_floor() -> void:
	var overlook: Rect2 = _patch(L.P_OVERLOOK)
	var gallery: Rect2 = _patch(L.P_GALLERY)
	assert_gt(overlook.position.y - gallery.end.y, 40.0,
		"the gallery is far beyond the entry's reach, not merely further along")
	var thicket: Rect2 = _patch(L.P_THICKET)
	var spillway: Rect2 = _patch(L.P_SPILLWAY)
	assert_lt(thicket.end.x, spillway.position.x,
		"the two middle branches must not share ground, or neither hides the other")


func test_depth_two_generation_is_deterministic() -> void:
	var first: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "\t")
	var second: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "\t")
	assert_eq(first, second, "the same seed and depth must produce a byte-identical floor")


# --- 2: BOTH BRANCHES COMPLETE THE FLOOR -------------------------------------------------------

func test_the_floor_completes_through_the_thicket() -> void:
	_descend_via_thicket()
	_finish_from_the_gallery()
	assert_true(sim.debug_describe_floor()["floor_complete"], "the western way is a complete route")


func test_the_floor_completes_through_the_spillway() -> void:
	_descend_via_spillway()
	_finish_from_the_gallery()
	assert_true(sim.debug_describe_floor()["floor_complete"], "and so is the eastern way")


# --- 3: THE ONE-WAY COMMITMENT ------------------------------------------------------------------

## The floor's real phase transition, and the reason it needs no party plate to mark one.
func test_descending_seals_the_way_back() -> void:
	assert_true(_open(L.C_COMMIT), "the way down starts open")
	assert_true(_walk_to(Vector3(0.0, 0.0, -26.0)), "commit past the trigger")
	assert_false(_open(L.C_COMMIT), "and it closes behind you")
	assert_true(_walk_to(Vector3(0.0, 0.0, -22.0)), "walking back toward it is allowed")
	for i in 300:
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": Vector3(0, 0, 1)})] as Array[Command], DT)
	assert_lt(sim.entities[player].z, _patch(L.P_DESCENT).position.y,
		"but the descent is unreachable now, at %s" % sim.entities[player])


# --- 4: STAGED ENCOUNTER ACTIVATION -------------------------------------------------------------

## A long floor stages its fights rather than waking them all at load.
func test_the_later_encounters_are_dormant_until_reached() -> void:
	assert_eq(_state(L.E_GALLERY), "dormant", "the gallery waits")
	assert_eq(_state(L.E_JUNCTION), "dormant", "so does the junction")
	assert_eq(_state(L.E_ROUTE_A_RESPONSE), "dormant", "and the shortcut's price")
	assert_ne(_state(L.E_LANDING), "dormant", "but the ambient landing pair are simply there")


func test_entering_the_gallery_wakes_its_fight() -> void:
	_descend_via_thicket()
	assert_eq(_state(L.E_GALLERY), "active", "arriving is what starts it")
	for actor_id: int in sim._encounter_roster[L.E_GALLERY]:
		assert_false(sim.debug_is_combat_absent(actor_id), "and its roster arrives")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1, "without sealing the player in")


func test_the_junction_fight_waits_until_the_junction() -> void:
	_descend_via_spillway()
	assert_eq(_state(L.E_JUNCTION), "dormant", "still dormant from the gallery")
	assert_true(_walk_to(Vector3(10.0, 0.0, -78.0)))
	assert_true(_walk_to(Vector3(10.0, 0.0, -90.0)))
	assert_eq(_state(L.E_JUNCTION), "active", "and wakes on arrival")


# --- 5: THE INTEGRATED CHAMBER (the composition the ruling required) ----------------------------

## THREAT-VISIBLE-BEFORE-ACTIONABLE. The Watcher stands behind blocking rubble that holds the
## sightline BOTH ways: the player understands the threat before they can act on it, and the
## environment is what changes the relationship.
func test_the_gallery_watcher_stands_behind_cover_that_holds_the_line_both_ways() -> void:
	var rubble: BreakablePlan = null
	for breakable: BreakablePlan in plan.breakables:
		if breakable.breakable_id == L.B_GALLERY_RUBBLE:
			rubble = breakable
	assert_not_null(rubble, "the gallery's rubble exists")
	assert_gt(rubble.blocking_rect.get_area(), 0.0, "and occupies ground rather than merely standing on it")

	var watcher: Vector3 = Vector3.ZERO
	for spawn in plan.encounter_by_id(L.E_GALLERY).roster:
		if spawn["enemy_key"] == &"watcher":
			watcher = spawn["position"]
	assert_lt(absf(watcher.x - rubble.position.x), 3.0,
		"the watcher must be BEHIND the cover, not merely in the same room")
	assert_lt(watcher.z, rubble.position.z, "and on the far side of it from the approach")


## THE SAME ACT CHANGES THE FIGHT AND THE ROUTE: the rubble occupies a lane, so clearing it both
## exposes what is behind and opens the ground in front.
func test_breaking_the_gallery_rubble_opens_the_ground_it_held() -> void:
	var rubble: Rect2 = Rect2()
	for breakable: BreakablePlan in plan.breakables:
		if breakable.breakable_id == L.B_GALLERY_RUBBLE:
			rubble = breakable.blocking_rect
	var middle := Vector3(rubble.get_center().x, 0.0, rubble.get_center().y)
	assert_false(sim._bounds.fits(middle, 0.45), "the lane is held while the rubble stands")

	sim.debug_destroy_breakable(L.B_GALLERY_RUBBLE)
	assert_true(sim._bounds.fits(middle, 0.45), "and returns when it is cleared")


## OBSTACLES SHAPE THE APPROACH rather than blocking it: two lanes, both real.
func test_the_gallery_has_two_approaches_around_its_obstacles() -> void:
	var gallery: Rect2 = _patch(L.P_GALLERY)
	for x: float in [-22.0, 22.0]:
		assert_true(sim._bounds.fits(Vector3(x, 0.0, gallery.get_center().y), 1.45),
			"the widest authored body must fit down the lane at x=%.0f" % x)


# --- 6: THE HAZARD ------------------------------------------------------------------------------

func test_the_spillway_spikes_cycle_and_are_out_of_step() -> void:
	var differed: bool = false
	for i in 120:
		var first: bool = sim.debug_describe_spike_pad(0)["active"]
		var second: bool = sim.debug_describe_spike_pad(1)["active"]
		if first != second:
			differed = true
		sim.tick([] as Array[Command], DT)
	assert_true(differed, "neighbouring pads must not march in lockstep, or the lane is one gate")


## A HAZARD IS RISK TOPOLOGY, NOT WALKABILITY: the pad's ground stays walkable at every phase.
func test_a_spike_pad_never_changes_where_you_may_stand() -> void:
	var pad: SpikePadPlan = plan.spike_pads[0]
	var middle := Vector3(pad.rect.get_center().x, 0.0, pad.rect.get_center().y)
	for i in 120:
		assert_true(sim._bounds.fits(middle, 0.45),
			"spikes change what standing costs, never whether you may")
		sim.tick([] as Array[Command], DT)


## AND THERE IS A WAY ROUND. The fast line is the timed line; the slow line is not a gate.
func test_the_spillway_has_a_route_that_avoids_every_pad() -> void:
	_descend_via_spillway()
	for pad: SpikePadPlan in plan.spike_pads:
		assert_false(WalkableBounds.contains(pad.rect, sim.entities[player].x, sim.entities[player].z),
			"the slow lane must not end on a pad")


# --- 7: THE TWO FLOOR VERBS ---------------------------------------------------------------------

## PRESENCE. Route A is bought by standing.
func test_route_a_is_gated_until_the_control_is_stood_on() -> void:
	assert_false(_open(L.C_TO_A), "the shortcut starts shut")
	_descend_via_thicket()
	assert_false(_open(L.C_TO_A), "and stays shut on arrival")
	_stand_on(L.CONTROL_PLATE)
	assert_true(_open(L.C_TO_A), "standing on the control opens it")
	assert_eq(_state(L.E_ROUTE_A_RESPONSE), "active", "and wakes what guards it")


## THE PRICE STANDS IN THE SHORTCUT, so it is paid by whoever takes it -- and may be declined.
func test_the_shortcuts_price_stands_in_the_shortcut() -> void:
	var response: EncounterSite = plan.encounter_by_id(L.E_ROUTE_A_RESPONSE)
	assert_eq(response.regions[0], _patch(L.P_ROUTE_A), "its territory is the route itself")
	assert_false(response.confines_player, "and it never seals anyone in")


## PERCEPTION. The Vault is opened by finding a concealed switch and shooting it -- a different
## verb from the plate, because the spatial meaning differs.
func test_the_vault_switch_is_concealed_until_its_cover_is_broken() -> void:
	assert_true(bool(sim._hit_switches[L.S_VAULT]["hidden"]), "the switch starts hidden")
	assert_false(_open(L.C_VAULT), "and the vault door starts shut")
	sim.debug_destroy_breakable(L.B_COVER)
	assert_false(bool(sim._hit_switches[L.S_VAULT]["hidden"]), "breaking the cover reveals it")
	assert_false(_open(L.C_VAULT), "revealing is not pressing")


func test_shooting_the_revealed_switch_opens_the_vault() -> void:
	sim.debug_destroy_breakable(L.B_COVER)
	sim.debug_activate_hit_switch(L.S_VAULT)
	assert_true(_open(L.C_VAULT), "the switch opens the door it names")


## THE GATE ACTUALLY OWNS ITS BRANCH: there is no other way into the Vault.
func test_the_vault_cannot_be_entered_without_the_switch() -> void:
	# ASSERTED ON THE GAP, not on the room. The Vault's own ground is always legal -- it is a
	# patch -- and closing the door removes only the aperture that BRIDGES to it. Reachability is
	# the claim; standing-legality inside the destination was never the question.
	var route_b: Rect2 = _patch(L.P_ROUTE_B)
	var vault: Rect2 = _patch(L.P_VAULT)
	var gap := Vector3((route_b.end.x + vault.position.x) * 0.5, 0.0, vault.get_center().y)
	assert_false(sim._bounds.fits(gap, 0.45), "nothing bridges to the vault while its door is shut")
	sim.debug_destroy_breakable(L.B_COVER)
	sim.debug_activate_hit_switch(L.S_VAULT)
	assert_true(sim._bounds.fits(gap, 0.45), "and the switch is the only thing that bridges it")


## THE DESTINATION IS STILL EMPTY, and that is recorded rather than disguised.
func test_the_vault_contains_nothing_and_claims_nothing() -> void:
	for encounter: EncounterSite in plan.encounters:
		assert_ne(encounter.regions[0], _patch(L.P_VAULT), "no fight is placed there to invent a reason")


# --- 8: FLOOR 1 IS UNAFFECTED --------------------------------------------------------------------

func test_depth_one_still_authors_the_prototype() -> void:
	var floor_one: FloorPlan = DepthGenerator.generate(arena.run_seed, 1)
	assert_eq(floor_one.spike_pads.size(), 0, "floor 1 gains no hazards")
	assert_eq(floor_one.obstacles.size(), 0, "no obstacles")
	assert_eq(floor_one.hit_switches.size(), 0, "and no switches")
	assert_ne(floor_one.patches.size(), plan.patches.size(), "it is still its own floor")


# --- 9: THE ROSTER CAN USE THE FLOOR (§12) -------------------------------------------------------

## OBSTACLES MAY SHAPE SPACE; THEY MAY NOT STRAND THE ROSTER. Sampled with the WIDEST authored
## body rather than the player's, because pursuit, retreat and knockback all push enemies down
## lanes their own encounter never mentioned. The apertures are covered by FloorPlan's clearance
## guard; this is the other half -- the ground BETWEEN the obstacles.
func test_the_widest_authored_body_can_walk_every_main_lane() -> void:
	var widest: float = 0.0
	for encounter: EncounterSite in plan.encounters:
		for spawn in encounter.roster:
			widest = maxf(widest, float(ContentDB.get_resource(&"enemy", spawn["enemy_key"]).combat_radius))
	assert_gt(widest, 1.0, "sanity: the floor places a genuinely wide body")

	# One representative line through each space that a chase can legitimately cross.
	var lanes: Array = [
		["landing, west of the columns", Vector3(-12.0, 0.0, -30.0), Vector3(-12.0, 0.0, -22.0)],
		["landing, east of the columns", Vector3(11.0, 0.0, -30.0), Vector3(11.0, 0.0, -22.0)],
		["thicket, south of the rubble", Vector3(-29.0, 0.0, -52.0), Vector3(-11.0, 0.0, -52.0)],
		["spillway slow lane", Vector3(22.0, 0.0, -52.0), Vector3(22.0, 0.0, -40.0)],
		["gallery west approach", Vector3(-22.0, 0.0, -70.0), Vector3(-22.0, 0.0, -60.0)],
		["gallery east approach", Vector3(22.0, 0.0, -70.0), Vector3(22.0, 0.0, -60.0)],
		["junction, end to end", Vector3(-27.0, 0.0, -92.0), Vector3(27.0, 0.0, -92.0)],
	]
	for lane in lanes:
		var from: Vector3 = lane[1]
		var to: Vector3 = lane[2]
		for step in 21:
			var point: Vector3 = from.lerp(to, float(step) / 20.0)
			assert_true(sim._bounds.fits(point, widest),
				"%s must admit a body of radius %.2f, blocked at %s" % [lane[0], widest, point])


## EVERY AUTHORED SPAWN FITS WHERE IT IS PLACED, including inside the obstacle-shaped rooms.
func test_every_authored_spawn_fits_and_sits_in_its_own_home() -> void:
	for encounter: EncounterSite in plan.encounters:
		for spawn in encounter.roster:
			var radius: float = ContentDB.get_resource(&"enemy", spawn["enemy_key"]).combat_radius
			assert_true(sim._bounds.fits(spawn["position"], radius),
				"%s does not fit at %s" % [spawn["enemy_key"], spawn["position"]])
			assert_true(WalkableBounds.contains(encounter.regions[0], spawn["position"].x, spawn["position"].z),
				"%s spawns outside the home that owns it" % spawn["enemy_key"])
