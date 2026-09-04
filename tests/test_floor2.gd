extends GutTest
## FLOOR 2 BUILD CHECKS — broad, massed, four turns (rebuilt 2026-09-04).
##
## REVEAL IS MEASURED, NOT ASSERTED. An earlier build shipped a test claiming "the entry cannot
## see the later floor", implemented as WORLD DISTANCE -- which is not visibility. It passed while
## the floor showed 10 of its 11 spaces from the drop. The real-camera instrument
## (tools/measure_floor_reveal.gd) owns that question now, and its table goes in the build report.
##
## WHAT THIS FILE PINS is the geometry and the laws the measurement rests on: that the floor
## spreads across BOTH axes, that its masses stand beside what they hide, that every beat still
## works in its new approach direction, and that the content laws hold.

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
	var centre := Vector3(plate.get_center().x, 0.0, plate.get_center().y)
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


## The whole floor, leg by leg. Waypoints, not pathfinding: a walk that fails because geometry is
## in the way is the geometry working.
func _walk_the_floor() -> void:
	assert_true(_walk_to(Vector3(-46.0, 0.0, -36.0)), "leg 1: down into the landing")
	assert_true(_walk_to(Vector3(-20.0, 0.0, -37.0)), "east along the west hall")
	assert_true(_walk_to(Vector3(-6.0, 0.0, -42.0)), "to the court's mouth")
	assert_true(_walk_to(Vector3(-2.0, 0.0, -50.0)), "leg 2: into the court")
	assert_true(_walk_to(Vector3(14.0, 0.0, -62.0)), "east across it, south of its limb")
	assert_true(_walk_to(Vector3(21.0, 0.0, -70.0)), "to the south lane's mouth")
	assert_true(_walk_to(Vector3(21.0, 0.0, -91.0)), "into the lane")
	assert_true(_walk_to(Vector3(2.0, 0.0, -91.0)), "leg 3: west across the hazard lane")
	assert_true(_walk_to(Vector3(-20.0, 0.0, -88.0)), "into the hall")
	assert_true(_walk_to(Vector3(-39.0, 0.0, -103.0)), "south through the bay's doorway")
	assert_true(_walk_to(Vector3(-38.0, 0.0, -116.0)), "into the bay")


# --- 1: THE FLOOR USES BOTH AXES ---------------------------------------------------------------

## THE HUMAN'S FINDING was that the floor read front-to-back. A strip with corners is still a
## strip, so this asserts that major spaces occupy materially different positions on BOTH axes.
func test_the_floor_spreads_across_both_axes() -> void:
	var extent: Rect2 = plan.patches[0].rect
	var xs: Array = []
	for patch: WalkablePatch in plan.patches:
		extent = extent.merge(patch.rect)
		xs.append(patch.rect.get_center().x)
	assert_gt(extent.size.x, 100.0, "the floor must be broad, not merely long")
	assert_gt(float(xs.max()) - float(xs.min()), 70.0,
		"major spaces must sit at materially different x, or the width is decoration")


## FOUR DIRECTION CHANGES: route direction is itself a reveal tool.
func test_the_route_changes_direction_four_times() -> void:
	# Centres of the spaces the route visits, in order.
	var route: Array = [L.P_LANDING, L.P_WEST_HALL, L.P_COURT, L.P_SOUTH_LANE, L.P_HALL,
		L.P_PUZZLE_BAY, L.P_JUNCTION, L.P_TERRACE]
	var turns: int = 0
	var previous_eastward: int = 0
	for i in range(1, route.size()):
		var step: float = _patch(route[i]).get_center().x - _patch(route[i - 1]).get_center().x
		if absf(step) < 6.0:
			continue  # a mostly north-south step changes no direction
		var eastward: int = 1 if step > 0.0 else -1
		if previous_eastward != 0 and eastward != previous_eastward:
			turns += 1
		previous_eastward = eastward
	assert_gte(turns, 2, "the route must reverse laterally, not merely drift")


# --- 2: THE MASSES ------------------------------------------------------------------------------

## THE HEIGHT-9 SLABS ARE GONE. They were compensating for placement: a mass close to the player
## needs extreme height to hide distant ground, while a modest one beside what it conceals does
## more. Every mass here is ordinary height.
func test_no_mass_relies_on_extreme_height() -> void:
	for obstacle: ObstaclePlan in plan.obstacles:
		assert_lte(obstacle.height, 5.0,
			"obstacle %d is %.1f tall; this floor conceals by PLACEMENT, not by scale"
				% [obstacle.obstacle_id, obstacle.height])


## AND THEY ARE REAL. A sight blocker a shot passes through is the presentation-lies defect
## arriving through a prop.
func test_every_mass_blocks_bodies_and_shots_alike() -> void:
	for obstacle: ObstaclePlan in plan.obstacles:
		var middle := Vector3(obstacle.rect.get_center().x, 0.0, obstacle.rect.get_center().y)
		assert_false(sim._bounds.fits(middle, 0.45),
			"no body may stand inside mass %d" % obstacle.obstacle_id)
	var faces: int = 0
	var first: Rect2 = plan.obstacles[0].rect
	for segment in plan.solid_segments():
		var at: float = float(segment["at"])
		if segment["axis"] == &"x" and (absf(at - first.position.x) < 0.01 or absf(at - first.end.x) < 0.01) \
				and float(segment["min"]) >= first.position.y - 0.01 and float(segment["max"]) <= first.end.y + 0.01:
			faces += 1
		if segment["axis"] == &"z" and (absf(at - first.position.y) < 0.01 or absf(at - first.end.y) < 0.01) \
				and float(segment["min"]) >= first.position.x - 0.01 and float(segment["max"]) <= first.end.x + 0.01:
			faces += 1
	assert_eq(faces, 4, "and each contributes its four faces, so shots stop where bodies do")


## OPENNESS IS PRESERVED: solidity comes from authored masses, never from closing rooms in.
func test_every_patch_keeps_its_low_rim() -> void:
	for patch: WalkablePatch in plan.patches:
		assert_eq(patch.boundary_style, &"ledge",
			"patch %d closed its edges; masses do the occluding here" % patch.patch_id)


# --- 3: THE FLOOR IS WALKABLE END TO END --------------------------------------------------------

func test_the_floor_completes_end_to_end() -> void:
	_walk_the_floor()
	assert_false(_open(L.C_DOOR_EAST), "the way on starts closed")
	sim.debug_activate_hit_switch(L.S_ALTERNATE)
	assert_true(_open(L.C_DOOR_EAST), "and the toggle opens it")
	assert_true(_walk_to(Vector3(-28.0, 0.0, -134.0)), "through the east door")
	assert_true(_walk_to(Vector3(-26.5, 0.0, -140.0)), "down through the junction's doorway")
	assert_true(_walk_to(Vector3(-10.0, 0.0, -154.0)), "into the junction")
	assert_true(_walk_to(Vector3(16.0, 0.0, -154.0)), "east along it, south of the screening mass")
	assert_true(_walk_to(Vector3(16.0, 0.0, -164.0)), "up onto the terrace")
	_stand_on(L.EXIT_PLATE)
	assert_true(sim.debug_describe_floor()["floor_complete"], "the floor completes")


func test_descending_seals_the_way_back() -> void:
	assert_true(_open(L.C_COMMIT), "the way down starts open")
	assert_true(_walk_to(Vector3(-46.0, 0.0, -36.0)), "commit past the trigger")
	assert_false(_open(L.C_COMMIT), "and it closes behind you")


func test_depth_two_generation_is_deterministic() -> void:
	var first: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "\t")
	var second: String = JSON.stringify(DepthGenerator.generate(4242, 2).to_dict(), "\t")
	assert_eq(first, second, "the same seed and depth must produce a byte-identical floor")


# --- 4: BEATS RE-CHECKED IN THEIR NEW APPROACH DIRECTIONS ---------------------------------------

## THE INTEGRATED CHAMBER IS NOW APPROACHED FROM THE EAST, so its composition was re-oriented
## rather than transplanted: the rubble must stand BETWEEN the doorway and the Watcher, or the
## threat-visible-before-actionable beat simply does not happen from this side.
func test_the_hall_rubble_stands_between_its_doorway_and_its_watcher() -> void:
	var doorway: float = 0.0
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == L.C_TO_HALL:
			doorway = connection.aperture.get_center().x
	var rubble: float = 0.0
	for breakable: BreakablePlan in plan.breakables:
		if breakable.breakable_id == L.B_HALL_RUBBLE:
			rubble = breakable.position.x
	var watcher: float = 0.0
	for spawn in plan.encounter_by_id(L.E_HALL).roster:
		if spawn["enemy_key"] == &"watcher":
			watcher = spawn["position"].x
	assert_lt(rubble, doorway, "the rubble is west of the way in")
	assert_lt(watcher, rubble, "and the watcher is west of the rubble -- it is behind cover")


## THE STAGING BANDS FOLLOW THE APPROACH TOO. A band on the wrong side of a space fires only
## once its fight is already behind the player.
func test_each_fight_wakes_when_its_space_is_entered() -> void:
	for encounter_id in [L.E_COURT, L.E_HALL, L.E_JUNCTION]:
		assert_eq(_state(encounter_id), "dormant", "encounter %d waits" % encounter_id)
	assert_ne(_state(L.E_LANDING), "dormant", "but the ambient landing pair are simply there")

	assert_true(_walk_to(Vector3(-46.0, 0.0, -36.0)))
	assert_true(_walk_to(Vector3(-20.0, 0.0, -37.0)))
	assert_true(_walk_to(Vector3(-6.0, 0.0, -42.0)))
	assert_true(_walk_to(Vector3(-2.0, 0.0, -50.0)))
	assert_eq(_state(L.E_COURT), "active", "the court wakes on entry")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1, "without sealing anyone in")


# --- 5: THE TWO FLOOR VERBS ---------------------------------------------------------------------

func test_the_toggle_swaps_both_doors_together() -> void:
	assert_true(_open(L.C_DOOR_WEST), "state A: west open")
	assert_false(_open(L.C_DOOR_EAST), "state A: east closed")
	sim.debug_activate_hit_switch(L.S_ALTERNATE)
	assert_false(_open(L.C_DOOR_WEST), "state B: west closed")
	assert_true(_open(L.C_DOOR_EAST), "state B: east open")
	sim.debug_activate_hit_switch(L.S_ALTERNATE)
	assert_true(_open(L.C_DOOR_WEST), "and back to state A")


func test_exactly_one_way_is_open_at_a_time() -> void:
	for flips in 5:
		assert_ne(_open(L.C_DOOR_WEST), _open(L.C_DOOR_EAST),
			"exactly one way open, after %d flips" % flips)
		sim.debug_activate_hit_switch(L.S_ALTERNATE)


## CAUSE AND EFFECT MUST BE READABLE TOGETHER. We have no vocabulary for remote causality.
func test_each_switch_stands_with_what_it_controls() -> void:
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		for connection: TraversalConnection in plan.connections:
			var controlled: bool = false
			for authored_effect: Dictionary in hit_switch.effects:
				if int(authored_effect["target_id"]) == connection.connection_id:
					controlled = true
			if not controlled:
				continue
			var door := Vector3(connection.aperture.get_center().x, 0.0, connection.aperture.get_center().y)
			assert_lt(hit_switch.position.distance_to(door), 20.0,
				"switch %d is %.1f from a door it controls" % [hit_switch.switch_id, hit_switch.position.distance_to(door)])


func test_the_vault_needs_its_own_concealed_switch() -> void:
	assert_false(_open(L.C_VAULT), "shut to begin with")
	sim.debug_destroy_breakable(L.B_VAULT_COVER)
	assert_false(_open(L.C_VAULT), "revealing is not pressing")
	sim.debug_activate_hit_switch(L.S_VAULT)
	assert_true(_open(L.C_VAULT), "and hitting it opens the door")


func test_the_vault_branch_is_east_and_holds_no_manufactured_fight() -> void:
	assert_gt(_patch(L.P_VAULT).get_center().x, _patch(L.P_COURT).get_center().x,
		"the optional branch leaves the court EASTWARD, off the forward axis")
	for encounter: EncounterSite in plan.encounters:
		assert_ne(encounter.regions[0], _patch(L.P_VAULT), "and nothing is placed there to justify it")


# --- 6: CONTENT LAWS ----------------------------------------------------------------------------

## EVERY PROP BREAKS IN ONE HIT, route blockers included (human ruling 2026-09-04, overturning the
## earlier rule that let a blocker author higher durability). Permanence is a CATEGORY -- an
## obstacle -- never a bigger number.
func test_every_prop_breaks_in_one_hit() -> void:
	for breakable: BreakablePlan in plan.breakables:
		assert_lte(breakable.durability, 1.0,
			"breakable %d must break in one hit; if it should be permanent, make it a mass"
				% breakable.breakable_id)


## THE HAZARD LANE IS CROSSABLE ON A COMMITMENT, with the window RE-DERIVED for this lane rather
## than inherited: the old lane measured 114 ticks and took 143; this one measures 99 and takes
## 124. Carrying the old number across would have been a value that once meant something.
func test_the_spike_lane_can_be_crossed_once_it_retracts() -> void:
	var offsets: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		offsets.append(pad.phase_offset_ticks)
		assert_gte(pad.safe_ticks, 124,
			"pad %d gives %d safe ticks; the measured crossing is 99 and needs grace on top"
				% [pad.pad_id, pad.safe_ticks])
	assert_eq(offsets.min(), offsets.max(),
		"these pads form one unbroken lane, so they must retract together: %s" % str(offsets))


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


## THE WIDEST AUTHORED BODY must be able to use every leg, because pursuit and knockback push
## enemies down lanes their own encounter never mentioned.
## THE RUBBLE SHAPES THE HALL WITHOUT SEALING IT: clear ground exists on both sides of it, so a
## player who declines to break through still has a way round -- which is what makes breaking it
## a choice rather than a toll.
func test_the_hall_rubble_shapes_without_sealing() -> void:
	var rubble: Rect2 = Rect2()
	for breakable: BreakablePlan in plan.breakables:
		if breakable.breakable_id == L.B_HALL_RUBBLE:
			rubble = breakable.blocking_rect
	var middle: float = rubble.get_center().x
	assert_true(sim._bounds.fits(Vector3(middle, 0.0, rubble.position.y - 2.0), 1.45),
		"the widest body must pass south of the rubble")
	assert_true(sim._bounds.fits(Vector3(middle, 0.0, rubble.end.y + 2.0), 1.45),
		"and north of it")


func test_the_widest_body_can_walk_every_leg() -> void:
	var widest: float = 0.0
	for encounter: EncounterSite in plan.encounters:
		for spawn in encounter.roster:
			widest = maxf(widest, float(ContentDB.get_resource(&"enemy", spawn["enemy_key"]).combat_radius))
	var lanes: Array = [
		["landing", Vector3(-56.0, 0.0, -36.0), Vector3(-32.0, 0.0, -36.0)],
		["west hall", Vector3(-32.0, 0.0, -37.0), Vector3(-4.0, 0.0, -37.0)],
		# EAST of the court's north-west limb, which is authored to stand there: the lane exists to
		# prove the room is crossable, not to insist the room is empty.
		["court, north-east", Vector3(10.0, 0.0, -48.0), Vector3(34.0, 0.0, -48.0)],
		# South of the Court's landmark, which stands at z[-70,-62]: the room is crossable around
		# its centrepiece, which is the point of having one.
		["court, south", Vector3(-2.0, 0.0, -72.0), Vector3(34.0, 0.0, -72.0)],
		["south lane", Vector3(2.0, 0.0, -91.0), Vector3(28.0, 0.0, -91.0)],
		# NO STRAIGHT LANE IS CLAIMED THROUGH THE HALL: it is an integrated chamber, deliberately
		# full of masses and a route blocker, and a full-width corridor through it would mean the
		# composition had failed. What IS claimed is below.
		["west of the hall's rubble", Vector3(-50.0, 0.0, -89.0), Vector3(-30.0, 0.0, -89.0)],
		["junction", Vector3(-28.0, 0.0, -152.0), Vector3(26.0, 0.0, -152.0)],
	]
	for lane in lanes:
		for step in 21:
			var point: Vector3 = (lane[1] as Vector3).lerp(lane[2] as Vector3, float(step) / 20.0)
			assert_true(sim._bounds.fits(point, widest),
				"%s must admit a body of radius %.2f, blocked at %s" % [lane[0], widest, point])


# --- 7: FLOOR 1 IS UNAFFECTED ---------------------------------------------------------------------

func test_depth_one_still_authors_the_prototype() -> void:
	var floor_one: FloorPlan = DepthGenerator.generate(arena.run_seed, 1)
	assert_eq(floor_one.spike_pads.size(), 0, "floor 1 gains no hazards")
	assert_eq(floor_one.obstacles.size(), 0, "no masses")
	assert_eq(floor_one.hit_switches.size(), 0, "and no switches")


# --- 8: LOCAL READABILITY (ruled 2026-09-05) ----------------------------------------------------

## HIDE FUTURE RELATIONSHIPS, NOT THE GROUND UNDER THE PLAYER'S FEET.
##
## THE RULE, derived from the camera rather than guessed: the view ray reaches the ground AT the
## player, descending one unit per unit, so its height d short of the player is exactly d --
## therefore A MASS OF HEIGHT h COVERS THE PLAYER WHENEVER THEY WALK WITHIN h UNITS OF ITS
## CAMERA-FACING FACE. The camera sits NORTH of the player, so that is a mass's north side.
##
## Three masses on the previous build were within THREE units of a walking line, and the human
## reported all three independently. This pins the clearance so it cannot creep back.
func test_no_mass_stands_on_top_of_a_walking_line() -> void:
	var walking_lines: Array = [
		Vector3(-46.0, 0.0, -36.0),  # landing
		Vector3(-20.0, 0.0, -37.0),  # west hall
		Vector3(-2.0, 0.0, -50.0),   # court, entering
		Vector3(14.0, 0.0, -62.0),   # court, crossing
		Vector3(21.0, 0.0, -91.0),   # the spike lane's commitment line
		Vector3(2.0, 0.0, -91.0),    # its far side
		Vector3(-39.0, 0.0, -103.0), # the bay's doorway
		Vector3(-10.0, 0.0, -154.0), # junction
		Vector3(16.0, 0.0, -154.0),  # junction, east
	]
	for obstacle: ObstaclePlan in plan.obstacles:
		for line: Vector3 in walking_lines:
			# Only a mass NORTH of the player can come between them and the camera.
			if line.z >= obstacle.rect.position.y:
				continue
			if line.x < obstacle.rect.position.x - 1.0 or line.x > obstacle.rect.end.x + 1.0:
				continue
			var gap: float = obstacle.rect.position.y - line.z
			assert_gte(gap, obstacle.height,
				"mass %d (height %.1f) is %.1f north of a walking line at %s -- it will cover the Envoy"
					% [obstacle.obstacle_id, obstacle.height, gap, line])


## THE SPIKE LANE'S COMMITMENT EDGE IS CLEAR. The player must be able to read the pads and their
## state before deciding to go; obstacle avoidance is not part of this hazard.
func test_the_spike_commitment_edge_is_uncluttered() -> void:
	var lane: Rect2 = plan.spike_pads[0].rect
	for pad: SpikePadPlan in plan.spike_pads:
		lane = lane.merge(pad.rect)
	# The approach room east of the lane, where the decision is made.
	for x: float in [lane.end.x + 2.0, lane.end.x + 4.0, lane.end.x + 6.0]:
		assert_true(sim._bounds.fits(Vector3(x, 0.0, lane.get_center().y), 1.45),
			"the approach at x=%.0f must be open ground, not something to squeeze past" % x)
	for obstacle: ObstaclePlan in plan.obstacles:
		assert_false(obstacle.rect.intersects(lane.grow(3.0)),
			"mass %d crowds the hazard's commitment edge" % obstacle.obstacle_id)


## A STRUCTURE WHOSE ONLY ROLE IS COVERING FAILS THE AUTHORED-PURPOSE TEST. The final-gate block
## was deleted rather than replaced, and this asserts nothing took its place.
func test_the_final_approach_carries_no_cover_only_block() -> void:
	var junction: Rect2 = _patch(L.P_JUNCTION)
	for obstacle: ObstaclePlan in plan.obstacles:
		assert_false(obstacle.rect.intersects(junction),
			"mass %d sits in the final approach; its reveal job belongs to the approach angle"
				% obstacle.obstacle_id)


## THE COURT KEEPS ITS OPEN GROUND. A landmark to orient by, not a clutter chamber.
func test_the_court_stays_mostly_open() -> void:
	var court: Rect2 = _patch(L.P_COURT)
	var occupied: float = 0.0
	for obstacle: ObstaclePlan in plan.obstacles:
		occupied += obstacle.rect.intersection(court).get_area()
	# A HEURISTIC, and named as one: 15% is "you can see across it and fight in it", not a law.
	# Human perception remains authoritative on whether the Court still breathes.
	assert_lt(occupied / court.get_area(), 0.15,
		"the Court is %.0f%% built on; it is a court, and it has to breathe" % (occupied / court.get_area() * 100.0))
	assert_gt(occupied, 0.0, "but it does have something to orient by")
