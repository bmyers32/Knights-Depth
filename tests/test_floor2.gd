extends GutTest
## FLOOR 2 BUILD CHECKS — three folded legs (rebuilt 2026-09-04).
##
## THE GOVERNING QUESTION is now whether the floor UNFOLDS. The previous version showed 10 of its
## 11 spaces from the drop, and the test that was supposed to catch that used WORLD DISTANCE as a
## proxy for visibility -- which is not one. Distance along the view axis does not remove anything
## from view; it only makes it smaller. That test passed while the floor was fully exposed.
##
## SO REVEAL IS NOT ASSERTED HERE. It is MEASURED, through the real camera with occlusion, by
## tools/measure_floor_reveal.gd, and the number goes in the build report. What this file pins is
## the GEOMETRY the measurement depends on -- the folds, the wall heights, the gaps -- so a later
## edit cannot quietly undo the thing the measurement proved.

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
	sim.debug_override_health(player, 1000000.0)


func _walk_to(target: Vector3, max_ticks: int = 4000) -> bool:
	for i in max_ticks:
		sim.debug_override_health(player, 1000000.0)
		if sim.entities[player].distance_to(target) < 1.4:
			return true
		var direction: Vector3 = target - sim.entities[player]
		direction.y = 0.0
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	return sim.entities[player].distance_to(target) < 1.4


func _stand_on(plate: Rect2) -> void:
	var centre: Vector3 = Vector3(plate.get_center().x, 0.0, plate.get_center().y)
	for i in 4000:
		sim.debug_override_health(player, 1000000.0)
		if sim.entities[player].distance_to(centre) < 0.3:
			break
		var direction: Vector3 = centre - sim.entities[player]
		direction.y = 0.0
		sim.tick([Command.new(sim.tick_count, player, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	sim.tick([] as Array[Command], DT)


func _patch(patch_id: int) -> Rect2:
	return plan.patch_by_id(patch_id).rect


func _open(connection_id: int) -> bool:
	return bool(sim._connection_open[connection_id])


func _state(encounter_id: int) -> String:
	return String(sim._encounter_state.get(encounter_id, ""))


## The whole floor, leg by leg. Waypoints rather than pathfinding: a walk that fails because
## geometry is in the way is the geometry working.
func _walk_the_floor() -> void:
	assert_true(_walk_to(Vector3(-36.0, 0.0, -34.0)), "leg A: down into the landing")
	assert_true(_walk_to(Vector3(-20.0, 0.0, -38.0)), "east across the landing")
	assert_true(_walk_to(Vector3(8.0, 0.0, -39.0)), "along lane A to the first fold")
	assert_true(_walk_to(Vector3(10.0, 0.0, -58.0)), "leg B: south through the fold")
	assert_true(_walk_to(Vector3(-4.0, 0.0, -58.0)), "west past the spillway")
	assert_true(_walk_to(Vector3(-40.0, 0.0, -55.0)), "through the gallery's north lane")
	assert_true(_walk_to(Vector3(-40.0, 0.0, -96.0)), "leg C: south through the second fold")
	assert_true(_walk_to(Vector3(-30.0, 0.0, -106.0)), "into the puzzle bay")


# --- 1: THE FOLDS ARE REAL, AND TALL ENOUGH TO MATTER ------------------------------------------

## THE ARITHMETIC THIS FLOOR RESTS ON. The camera sits 12 above the player at 45 degrees, so a
## wall of height h at distance t hides ground out to t/(1 - h/12). At the DEFAULT obstacle height
## of 2.4 that is barely twelve units of shadow -- which is why the previous floor's obstacles
## hid nothing. The fold walls are tall for a measured reason, and this pins it.
func test_the_fold_walls_are_tall_enough_to_hide_a_leg() -> void:
	var tall: Array = []
	for obstacle: ObstaclePlan in plan.obstacles:
		if obstacle.height >= 6.0:
			tall.append(obstacle)
	assert_eq(tall.size(), 2, "two fold walls, one per turn -- few and large, never wall spam")
	for obstacle in tall:
		assert_gte(obstacle.height, 8.0,
			"a fold wall at height %.1f shadows only %.0f units at 25 away; it must hide a whole leg"
				% [obstacle.height, 25.0 / (1.0 - obstacle.height / 12.0) - 25.0])
		assert_gt(obstacle.rect.size.x, 40.0, "and it must span the leg, not stand in the middle of it")


## OPENNESS IS PRESERVED. The walls are the exception; every patch edge keeps its low rim.
func test_the_floor_keeps_its_open_edges() -> void:
	for patch: WalkablePatch in plan.patches:
		assert_eq(patch.boundary_style, &"ledge",
			"patch %d closed its edges; walls are for sightline control, not for enclosing rooms" % patch.patch_id)


## AND THE WALLS ARE REAL WALLS. A sight blocker a shot passes through is the presentation-lies
## defect arriving through the back door.
func test_a_fold_wall_blocks_bodies_and_shots_alike() -> void:
	var wall: Rect2 = Rect2()
	for obstacle: ObstaclePlan in plan.obstacles:
		if obstacle.height >= 6.0:
			wall = obstacle.rect
			break
	var middle := Vector3(wall.get_center().x, 0.0, wall.get_center().y)
	assert_false(sim._bounds.fits(middle, 0.45), "no body may stand inside a fold wall")
	# COUNTED WITHIN THE WALL'S OWN SPAN, not merely at its coordinates: a patch edge that happens
	# to share a line with the wall contributes its own segment, and the first version of this
	# check counted those too and read five faces on a four-sided box.
	var faces: int = 0
	for segment in plan.solid_segments():
		var at: float = float(segment["at"])
		var low: float = float(segment["min"])
		var high: float = float(segment["max"])
		if segment["axis"] == &"x" and (absf(at - wall.position.x) < 0.01 or absf(at - wall.end.x) < 0.01) 				and low >= wall.position.y - 0.01 and high <= wall.end.y + 0.01:
			faces += 1
		if segment["axis"] == &"z" and (absf(at - wall.position.y) < 0.01 or absf(at - wall.end.y) < 0.01) 				and low >= wall.position.x - 0.01 and high <= wall.end.x + 0.01:
			faces += 1
	assert_eq(faces, 4, "and it contributes its four faces, so shots stop where bodies do")


## EACH FOLD IS A TURN, not a straight line with a wall across it: the legs run in opposite
## directions, which is what puts a later leg outside the view rather than merely far down it.
func test_the_three_legs_change_direction() -> void:
	var landing: Rect2 = _patch(L.P_LANDING)
	var lane_a: Rect2 = _patch(L.P_LANE_A)
	var gallery: Rect2 = _patch(L.P_GALLERY)
	var junction: Rect2 = _patch(L.P_JUNCTION)
	assert_gt(lane_a.get_center().x, landing.get_center().x, "leg A turns EAST at its end")
	assert_lt(gallery.get_center().x, lane_a.get_center().x, "leg B runs back WEST")
	assert_gt(junction.get_center().x, gallery.get_center().x, "leg C runs back EAST")


# --- 2: THE FLOOR IS WALKABLE END TO END --------------------------------------------------------

func test_the_floor_completes_end_to_end() -> void:
	_walk_the_floor()
	# The east door starts shut; the toggle is what opens the way on.
	assert_false(_open(L.C_DOOR_EAST), "the way on starts closed")
	sim.debug_activate_hit_switch(L.S_ALTERNATE)
	assert_true(_open(L.C_DOOR_EAST), "and the toggle opens it")
	assert_true(_walk_to(Vector3(-19.0, 0.0, -124.0)), "through the east door")
	assert_true(_walk_to(Vector3(0.0, 0.0, -138.0)), "into the junction")
	assert_true(_walk_to(Vector3(12.0, 0.0, -148.0)), "and up onto the terrace")
	_stand_on(L.EXIT_PLATE)
	assert_true(sim.debug_describe_floor()["floor_complete"], "the floor completes")


func test_descending_seals_the_way_back() -> void:
	assert_true(_open(L.C_COMMIT), "the way down starts open")
	assert_true(_walk_to(Vector3(-36.0, 0.0, -34.0)), "commit past the trigger")
	assert_false(_open(L.C_COMMIT), "and it closes behind you")


func test_depth_two_generation_is_deterministic() -> void:
	var first: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "\t")
	var second: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "\t")
	assert_eq(first, second, "the same seed and depth must produce a byte-identical floor")


# --- 3: THE ALTERNATING DOORS (the first true consumer of the toggle) --------------------------

## STATE A -> STATE B -> STATE A. The doors swap TOGETHER, in one indivisible consequence, so
## the player never sees a moment where both are open or both are shut.
func test_the_toggle_swaps_both_doors_together() -> void:
	assert_true(_open(L.C_DOOR_WEST), "state A: west open")
	assert_false(_open(L.C_DOOR_EAST), "state A: east closed")

	sim.debug_activate_hit_switch(L.S_ALTERNATE)
	assert_false(_open(L.C_DOOR_WEST), "state B: west closed")
	assert_true(_open(L.C_DOOR_EAST), "state B: east open")

	sim.debug_activate_hit_switch(L.S_ALTERNATE)
	assert_true(_open(L.C_DOOR_WEST), "and back to state A")
	assert_false(_open(L.C_DOOR_EAST))


func test_the_two_doors_are_never_both_open_or_both_shut() -> void:
	for flips in 5:
		assert_ne(_open(L.C_DOOR_WEST), _open(L.C_DOOR_EAST),
			"exactly one way is open at a time, after %d flips" % flips)
		sim.debug_activate_hit_switch(L.S_ALTERNATE)


## SPATIAL LEGIBILITY: the switch and BOTH doors must be readable together. We have no vocabulary
## for remote causality, and the previous floor's distant switch is exactly what that costs.
func test_the_toggle_stands_with_the_doors_it_controls() -> void:
	var toggle: HitSwitchPlan = null
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		if hit_switch.switch_id == L.S_ALTERNATE:
			toggle = hit_switch
	assert_not_null(toggle)
	assert_eq(toggle.mode, HitSwitchPlan.MODE_TOGGLE, "this one is the reversible switch")
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id != L.C_DOOR_WEST and connection.connection_id != L.C_DOOR_EAST:
			continue
		var door := Vector3(connection.aperture.get_center().x, 0.0, connection.aperture.get_center().y)
		assert_lt(toggle.position.distance_to(door), 20.0,
			"door %d is %.1f from the switch; both doors must be legible from it"
				% [connection.connection_id, toggle.position.distance_to(door)])


## THE TOGGLE IS NOT THE VAULT'S CONTROL. Its unresolved problem is destination reward, never
## switch complexity, so it keeps a simple local one-shot beside its own door.
func test_the_vault_uses_a_simple_local_one_shot() -> void:
	var vault_switch: HitSwitchPlan = null
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		if hit_switch.switch_id == L.S_VAULT:
			vault_switch = hit_switch
	assert_eq(vault_switch.mode, HitSwitchPlan.MODE_ONE_SHOT, "not a toggle")
	var door: Rect2 = Rect2()
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == L.C_VAULT:
			door = connection.aperture
	assert_lt(vault_switch.position.distance_to(Vector3(door.get_center().x, 0.0, door.get_center().y)), 12.0,
		"and it stands beside the door it opens")


func test_the_vault_is_shut_until_its_own_switch_is_hit() -> void:
	assert_false(_open(L.C_VAULT), "shut to begin with")
	sim.debug_destroy_breakable(L.B_VAULT_COVER)
	assert_false(_open(L.C_VAULT), "revealing the switch is not pressing it")
	sim.debug_activate_hit_switch(L.S_VAULT)
	assert_true(_open(L.C_VAULT), "and hitting it opens the door")


func test_no_encounter_lives_in_the_vault() -> void:
	for encounter: EncounterSite in plan.encounters:
		assert_ne(encounter.regions[0], _patch(L.P_VAULT),
			"no fight is placed there to invent a reason to go")


# --- 4: STAGED ENCOUNTERS -----------------------------------------------------------------------

func test_the_later_fights_wait_until_their_leg_is_reached() -> void:
	assert_ne(_state(L.E_LANDING), "dormant", "the ambient landing pair are simply there")
	for encounter_id in [L.E_GALLERY, L.E_SPILLWAY, L.E_JUNCTION]:
		assert_eq(_state(encounter_id), "dormant", "encounter %d waits" % encounter_id)


func test_reaching_leg_b_wakes_its_fights() -> void:
	assert_true(_walk_to(Vector3(-36.0, 0.0, -34.0)))
	assert_true(_walk_to(Vector3(8.0, 0.0, -39.0)))
	assert_true(_walk_to(Vector3(10.0, 0.0, -62.0)))
	assert_eq(_state(L.E_SPILLWAY), "active", "the spillway wakes on arrival")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1, "without sealing anyone in")


# --- 5: CONTENT LAWS ----------------------------------------------------------------------------

## EVERY PROP BREAKS IN ONE HIT, route blockers included (ruled 2026-09-04, superseding the
## earlier split that let a blocker cost more). Durability is not where challenge lives: a prop
## that soaks swings turns clearing scenery into fighting a low-health enemy. The difficulty of
## an environmental object is positioning, ordering, consequence and the enemies around it.
##
## THE ALTERNATIVE IS EXPLICITNESS: something the player must not be able to remove is an
## OBSTACLE, unbreakable by construction, rather than a prop with a big number.
func test_every_prop_breaks_in_one_hit() -> void:
	for breakable: BreakablePlan in plan.breakables:
		assert_lte(breakable.durability, 1.0,
			"breakable %d must break in one hit; if it should be permanent, make it an obstacle"
				% breakable.breakable_id)


## AND THE SPIKE LANE MUST BE CROSSABLE ON A COMMITMENT. Its safe window is derived from a
## MEASURED crossing (114 ticks at the authored speed, body-clear to body-clear) plus grace --
## not from feel. Pads sharing a lane must also share a phase, or the lane is never wholly safe
## and no window can satisfy the law.
func test_the_spike_lane_can_be_crossed_once_it_retracts() -> void:
	var lane: Rect2 = plan.spike_pads[0].rect
	var phases: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		lane = lane.merge(pad.rect)
		phases.append(pad.phase_offset_ticks)
		assert_gte(pad.safe_ticks, 137,
			"pad %d gives %d safe ticks; the measured crossing is 114 and needs grace on top"
				% [pad.pad_id, pad.safe_ticks])
	assert_eq(phases.min(), phases.max(),
		"pads sharing one lane must share a phase, or it is never wholly safe: %s" % str(phases))


func test_spikes_are_player_facing_only() -> void:
	for pad: SpikePadPlan in plan.spike_pads:
		assert_false(pad.eligible_allegiances.has(&"enemy"),
			"pad %d would kill the roster; ordinary spikes are the player's problem" % pad.pad_id)


func test_every_authored_spawn_fits_and_sits_in_its_own_home() -> void:
	for encounter: EncounterSite in plan.encounters:
		for spawn in encounter.roster:
			var radius: float = ContentDB.get_resource(&"enemy", spawn["enemy_key"]).combat_radius
			assert_true(sim._bounds.fits(spawn["position"], radius),
				"%s does not fit at %s" % [spawn["enemy_key"], spawn["position"]])
			assert_true(WalkableBounds.contains(encounter.regions[0], spawn["position"].x, spawn["position"].z),
				"%s spawns outside the home that owns it" % spawn["enemy_key"])


## THE WIDEST AUTHORED BODY must be able to use the floor, because pursuit and knockback push
## enemies down lanes their own encounter never mentioned.
func test_the_widest_body_can_walk_every_leg() -> void:
	var widest: float = 0.0
	for encounter: EncounterSite in plan.encounters:
		for spawn in encounter.roster:
			widest = maxf(widest, float(ContentDB.get_resource(&"enemy", spawn["enemy_key"]).combat_radius))
	var lanes: Array = [
		["landing", Vector3(-44.0, 0.0, -40.0), Vector3(-14.0, 0.0, -40.0)],
		["lane A", Vector3(-14.0, 0.0, -39.0), Vector3(12.0, 0.0, -39.0)],
		["fold 1", Vector3(10.0, 0.0, -38.0), Vector3(10.0, 0.0, -58.0)],
		["gallery north lane", Vector3(-46.0, 0.0, -55.0), Vector3(-12.0, 0.0, -55.0)],
		["fold 2", Vector3(-40.0, 0.0, -80.0), Vector3(-40.0, 0.0, -98.0)],
		["puzzle bay", Vector3(-42.0, 0.0, -106.0), Vector3(-16.0, 0.0, -106.0)],
		["junction", Vector3(-24.0, 0.0, -138.0), Vector3(26.0, 0.0, -138.0)],
	]
	for lane in lanes:
		for step in 21:
			var point: Vector3 = (lane[1] as Vector3).lerp(lane[2] as Vector3, float(step) / 20.0)
			assert_true(sim._bounds.fits(point, widest),
				"%s must admit a body of radius %.2f, blocked at %s" % [lane[0], widest, point])


# --- 6: FLOOR 1 IS UNAFFECTED --------------------------------------------------------------------

func test_depth_one_still_authors_the_prototype() -> void:
	var floor_one: FloorPlan = DepthGenerator.generate(arena.run_seed, 1)
	assert_eq(floor_one.spike_pads.size(), 0, "floor 1 gains no hazards")
	assert_eq(floor_one.obstacles.size(), 0, "no obstacles")
	assert_eq(floor_one.hit_switches.size(), 0, "and no switches")
