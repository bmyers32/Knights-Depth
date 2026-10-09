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
const L = preload("res://game/content/layouts/archive_roundabout.tres")

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


## Does this connection have one foot in that space? The fork's claim is spatial, so it is
## checked against the plan rather than inferred from a walk that happens to succeed.
func _connection_touches(connection_id: int, patch_id: int) -> bool:
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == connection_id:
			return connection.patch_ids.x == patch_id or connection.patch_ids.y == patch_id
	return false


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
	# ROUND THE LANDMARK, not through it: the Court's centrepiece stands at x[20,28] and the way
	# east passes on one side of it. That is what a landmark is for -- the room is navigated
	# BY the structure rather than across an empty floor with a decoration in the middle.
	assert_true(_walk_to(Vector3(20.0, 0.0, -72.0)), "south of the landmark")
	assert_true(_walk_to(Vector3(32.0, 0.0, -72.0)), "east past it")
	# THROUGH THE COURT, which is a room you cross now rather than a decision you make.
	assert_true(Vector3(22.0, 0.0, -60.0) != Vector3.ZERO)
	assert_true(_walk_to(Vector3(22.0, 0.0, -62.0)), "north across the court")
	assert_true(_walk_to(Vector3(22.0, 0.0, -76.0)), "through its one way on")
	# STRAIGHT UP THE HALL. No room between the Court and the choice, and nothing to walk round.
	assert_true(_walk_to(Vector3(22.0, 0.0, -90.0)), "north up the hall")
	assert_true(_walk_to(Vector3(22.0, 0.0, -110.0)), "to THE T, with both ways on in front of you")


## THE WEST, which is now every bit of it optional. Walked in full by the tests that care whether
## the old route still works as content -- and by none of the tests that prove the floor completes.
func _walk_the_west() -> void:
	assert_true(_walk_to(Vector3(12.0, 0.0, -110.0)), "LEFT: west out of the T")
	# THE HAZARD LIVES IN THE HALLWAY, crossed along its length -- the direction you were already
	# travelling. No room was built to hold it.
	assert_true(_walk_to(Vector3(-9.0, 0.0, -110.0)), "across the pads once they retract")
	assert_true(_walk_to(Vector3(-6.0, 0.0, -100.0)), "through into the optional chapter")
	assert_true(_walk_to(Vector3(-8.0, 0.0, -94.0)), "and round the south of its rubble")


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


## LAW REPLACED 2026-09-08: LATERAL REACH, not lateral reversals.
##
## This previously asserted the critical path REVERSES direction at least twice, because the floor
## it was written for got its variety from folding back on itself. That is exactly the shape the
## human kept rejecting -- a ribbon with corners is still a ribbon -- and the ruling is explicit
## that the eastern chapter must NOT turn back toward the centre for balance.
##
## So the property worth pinning inverted. A critical path that runs west-to-east across the whole
## floor without doubling back is now the GOOD case, and what must be true instead is that it
## genuinely reaches: the chapters occupy materially different lateral regions rather than
## clustering on one spine.
func test_the_critical_path_reaches_across_the_floor_laterally() -> void:
	var route: Array = [_id(&"P_LANDING"), _id(&"P_WEST_HALL"), _id(&"P_COURT"), _id(&"P_SPIKE_HALL"), _id(&"P_JUNCTION"),
		_id(&"P_EAST_HALL_A"), _id(&"P_EAST_HALL_B"), _id(&"P_WORKS"), _id(&"P_ARENA_LINK"), _id(&"P_ARENA"), _id(&"P_REWARD_HALL")]
	var extent: Rect2 = plan.patches[0].rect
	for patch: WalkablePatch in plan.patches:
		extent = extent.merge(patch.rect)
	var first: float = _patch(route[0]).get_center().x
	var last: float = _patch(route[route.size() - 1]).get_center().x
	assert_gt(absf(last - first), extent.size.x * 0.6,
		"the critical path must cross most of the floor's width, not orbit its middle")
	# And it gets there by travelling, not by one long jump between two clustered halves.
	var regions: Dictionary = {}
	for patch_id in route:
		regions[int(floor((_patch(patch_id).get_center().x - extent.position.x) / (extent.size.x / 5.0)))] = true
	assert_gte(regions.size(), 4,
		"the critical path's chapters must occupy at least four of the floor's five lateral fifths")


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
## LAW AMENDED 2026-09-09: rims are the DEFAULT, not the only option.
##
## This asserted every patch on the floor carried a low rim, which was right while the floor's
## only tool for enclosure was a screening mass -- "closing rooms in" was how you cheated reveal.
## The ruling separates the two: a CONNECTOR is rimmed so the player can see themselves and their
## path, and a DESTINATION may be walled because a room you have earned should feel enclosed.
##
## So the property worth pinning inverted. Walls are now legal but must be RARE and must belong to
## rooms that are destinations -- if half the floor is walled, enclosure has gone back to being a
## reveal trick.
func test_walls_belong_only_to_destinations() -> void:
	var walled: Array = []
	for patch: WalkablePatch in plan.patches:
		if patch.boundary_style == &"wall":
			walled.append(patch.patch_id)
	var destinations: Array = [_id(&"P_WORKS"), _id(&"P_REWARD_HALL")]
	for patch_id: int in walled:
		assert_true(destinations.has(patch_id),
			"patch %d closed its edges without being a destination room" % patch_id)
	assert_lt(walled.size(), plan.patches.size() / 4,
		"most of the floor must still be rimmed; enclosure is an accent, not the grammar")


# --- 3: THE FLOOR IS WALKABLE END TO END --------------------------------------------------------

func test_the_floor_completes_end_to_end() -> void:
	_walk_the_floor()
	# THE FLOOR COMPLETES WITHOUT THE WEST. That is the whole claim of this pass: the route the
	# player already knows is now content they may take, and nothing on the critical path waits
	# for it. No switch is hit, no puzzle is solved, no western room is entered.
	assert_true(_open(_id(&"C_TO_JUNCTION")), "the way east is open from the fork -- nothing gates the choice")
	_walk_the_east()
	_stand_on(_region(&"T_PARTY"))
	assert_eq(_state(_id(&"E_WAVE_1")), "active", "the party commits and the first wave wakes")
	_clear_the_arena()
	assert_true(_open(_id(&"C_ARENA_REWARD")), "the final wave opens the way on")
	assert_true(_walk_to(Vector3(230.0, 0.0, -138.0)), "east into the reward hall")
	assert_true(_walk_to(Vector3(242.0, 0.0, -134.0)), "across it, to the exit it carries")
	_stand_on(_region(&"T_EXIT"))
	assert_true(sim.debug_describe_floor()["floor_complete"], "the floor completes")


## Kills every wave in turn, the way the sim itself resolves them: the roster dies, the encounter
## notices on its own tick, and the trigger watching it does the rest. Nothing here reaches into
## wave state, because there is no wave state to reach into.
func _clear_the_arena() -> void:
	for encounter_id in [_id(&"E_WAVE_1"), _id(&"E_WAVE_2"), _id(&"E_WAVE_3")]:
		assert_eq(_state(encounter_id), "active",
			"wave %d must be the one running now" % encounter_id)
		_kill_roster(encounter_id)


func _kill_roster(encounter_id: int) -> void:
	for member_id: int in sim._encounter_roster[encounter_id]:
		sim._health[member_id] = 0.0
	sim.tick([], DT)


func test_descending_seals_the_way_back() -> void:
	assert_true(_open(_id(&"C_COMMIT")), "the way down starts open")
	assert_true(_walk_to(Vector3(-46.0, 0.0, -36.0)), "commit past the trigger")
	assert_false(_open(_id(&"C_COMMIT")), "and it closes behind you")


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
		if connection.connection_id == _id(&"C_TO_HALL"):
			doorway = connection.aperture.get_center().x
	var rubble: float = 0.0
	for breakable: BreakablePlan in plan.breakables:
		if breakable.breakable_id == _id(&"B_HALL_RUBBLE"):
			rubble = breakable.position.x
	var watcher: float = 0.0
	for spawn in plan.encounter_by_id(_id(&"E_HALL")).roster:
		if spawn["enemy_key"] == &"watcher":
			watcher = spawn["position"].x
	assert_lt(rubble, doorway, "the rubble is west of the way in")
	assert_lt(watcher, rubble, "and the watcher is west of the rubble -- it is behind cover")


## THE STAGING BANDS FOLLOW THE APPROACH TOO. A band on the wrong side of a space fires only
## once its fight is already behind the player.
func test_each_fight_wakes_when_its_space_is_entered() -> void:
	for encounter_id in [_id(&"E_COURT"), _id(&"E_HALL"), _id(&"E_POCKET"), _id(&"E_WORKS"), _id(&"E_SPIKE_HALL"), _id(&"E_WAVE_1"), _id(&"E_WAVE_2"), _id(&"E_WAVE_3")]:
		assert_eq(_state(encounter_id), "dormant", "encounter %d waits" % encounter_id)
	assert_ne(_state(_id(&"E_LANDING")), "dormant", "but the ambient landing pair are simply there")

	assert_true(_walk_to(Vector3(-46.0, 0.0, -36.0)))
	assert_true(_walk_to(Vector3(-20.0, 0.0, -37.0)))
	assert_true(_walk_to(Vector3(-6.0, 0.0, -42.0)))
	assert_true(_walk_to(Vector3(-2.0, 0.0, -50.0)))
	assert_eq(_state(_id(&"E_COURT")), "active", "the court wakes on entry")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1, "without sealing anyone in")


# --- 5: THE TWO FLOOR VERBS ---------------------------------------------------------------------

func test_the_toggle_swaps_both_doors_together() -> void:
	assert_true(_open(_id(&"C_DOOR_WEST")), "state A: west open")
	assert_false(_open(_id(&"C_DOOR_EAST")), "state A: east closed")
	sim.debug_activate_hit_switch(_id(&"S_ALTERNATE"))
	assert_false(_open(_id(&"C_DOOR_WEST")), "state B: west closed")
	assert_true(_open(_id(&"C_DOOR_EAST")), "state B: east open")
	sim.debug_activate_hit_switch(_id(&"S_ALTERNATE"))
	assert_true(_open(_id(&"C_DOOR_WEST")), "and back to state A")


func test_exactly_one_way_is_open_at_a_time() -> void:
	for flips in 5:
		assert_ne(_open(_id(&"C_DOOR_WEST")), _open(_id(&"C_DOOR_EAST")),
			"exactly one way open, after %d flips" % flips)
		sim.debug_activate_hit_switch(_id(&"S_ALTERNATE"))


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
	assert_false(_open(_id(&"C_VAULT")), "shut to begin with")
	sim.debug_destroy_breakable(_id(&"B_VAULT_COVER"))
	assert_false(_open(_id(&"C_VAULT")), "revealing is not pressing")
	sim.debug_activate_hit_switch(_id(&"S_VAULT"))
	assert_true(_open(_id(&"C_VAULT")), "and hitting it opens the door")


func test_the_vault_branch_is_east_and_holds_no_manufactured_fight() -> void:
	assert_gt(_patch(_id(&"P_VAULT")).get_center().x, _patch(_id(&"P_COURT")).get_center().x,
		"the optional branch leaves the court EASTWARD, off the forward axis")
	for encounter: EncounterSite in plan.encounters:
		assert_ne(encounter.regions[0], _patch(_id(&"P_VAULT")), "and nothing is placed there to justify it")


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
	# THE CROSSING LANE ONLY. The Arena authors three SEPARATE clusters whose phases are staggered
	# on purpose, so "all pads share a phase" stopped being a property of the floor the moment the
	# hazard gained a second use. The law it protects is unchanged and is stated where it applies:
	# pads that form ONE unbroken crossing with no safe ground between them must retract together,
	# because a player committed to that lane can never be asked to stop halfway.
	var offsets: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		if _patch(_id(&"P_SPIKE_HALL")).intersects(pad.rect):
			offsets.append(pad.phase_offset_ticks)
	assert_gte(offsets.size(), 2, "sanity: the crossing lane must actually have pads in it")
	for offset: int in offsets:
		assert_eq(offset, offsets[0],
			"these pads form one unbroken lane, so they must retract together: %s" % str(offsets))


## THE ARENA'S CROSS ALTERNATES -- the opposite property from the crossing lane, stated so a
## future reader does not "fix" it into agreement. Four arms blinking together would make the whole
## room unsafe at once and then wholly safe again; opposite arms sharing a phase and adjacent arms
## alternating makes the safe ground SWING between the vertical and horizontal diagonals, which a
## player can learn. A symmetrical pattern deserves a symmetrical rhythm.
func test_the_arena_cross_alternates_between_two_phases() -> void:
	var offsets: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		if _patch(_id(&"P_ARENA")).intersects(pad.rect):
			offsets.append(pad.phase_offset_ticks)
	assert_eq(offsets.size(), 4, "the cross has four arms")
	var distinct: Dictionary = {}
	for offset: int in offsets:
		distinct[offset] = int(distinct.get(offset, 0)) + 1
	assert_eq(distinct.size(), 2, "using exactly two phases: %s" % str(offsets))
	for phase: int in distinct:
		assert_eq(int(distinct[phase]), 2, "two arms each, so opposites match: %s" % str(offsets))


## AND IT IS ACTUALLY SYMMETRICAL, which is the composition the ruling asked for by name. Measured
## against the plate rather than eyeballed: a cross that is 9 out on one side and 13 on the other
## reads as four objects near a plate, not as one shape.
func test_the_arena_cross_is_symmetrical_about_the_plate() -> void:
	var centre: Vector2 = _region(&"T_PARTY").get_center()
	var horizontal: Array = []
	var vertical: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		if not _patch(_id(&"P_ARENA")).intersects(pad.rect):
			continue
		var offset: Vector2 = pad.rect.get_center() - centre
		if absf(offset.x) > absf(offset.y):
			horizontal.append(offset.x)
		else:
			vertical.append(offset.y)
	assert_eq(horizontal.size(), 2, "one arm east, one west")
	assert_eq(vertical.size(), 2, "one arm north, one south")
	assert_almost_eq(absf(float(horizontal[0])), absf(float(horizontal[1])), 0.01,
		"the east and west arms stand the same distance out")
	assert_almost_eq(absf(float(vertical[0])), absf(float(vertical[1])), 0.01,
		"and so do the north and south")
	assert_lt(float(horizontal[0]) * float(horizontal[1]), 0.0, "on opposite sides of the plate")
	assert_lt(float(vertical[0]) * float(vertical[1]), 0.0, "and so are these")


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
		if breakable.breakable_id == _id(&"B_HALL_RUBBLE"):
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
		# NORTH OF THE LANDMARK, which moved here to get off the fork's sightline. The Court still
		# has to be crossable along its north edge -- a landmark you cannot walk past is a wall.
		["court, north-east", Vector3(10.0, 0.0, -46.0), Vector3(40.0, 0.0, -46.0)],
		# South of the Court's landmark, which stands at z[-70,-62]: the room is crossable around
		# its centrepiece, which is the point of having one.
		["court, south", Vector3(-2.0, 0.0, -72.0), Vector3(34.0, 0.0, -72.0)],
		# WEST of the prop formation at x[23,25]: the lane still reads as one crossable span, and the
		# formation is a decision INSIDE it rather than a wall across it.

		# NO STRAIGHT LANE IS CLAIMED THROUGH THE HALL: it is an integrated chamber, deliberately
		# full of masses and a route blocker, and a full-width corridor through it would mean the
		# composition had failed. What IS claimed is below.
		["west of the hall's rubble", Vector3(-28.0, 0.0, -89.0), Vector3(-13.0, 0.0, -89.0)],
		# THE ARENA MUST BE CROSSABLE END TO END. A wave fight in a room the widest body cannot
		# traverse is a room that fights its own encounter.
		# THE FORK MUST BE CROSSABLE IN BOTH ITS DIRECTIONS, since that is the entire room: west to
		# east for the critical route, and north to south for the way down into the optional west.
		# ONE CONTINUOUS HALL, claimed in every direction it runs: north out of the Court, through
		# the junction, and out along both branches at the same twelve-wide scale.
		["north hall", Vector3(22.0, 0.0, -78.0), Vector3(22.0, 0.0, -100.0)],
		["the T, west to east", Vector3(18.0, 0.0, -110.0), Vector3(26.0, 0.0, -110.0)],
		["spike hall, east approach", Vector3(8.0, 0.0, -110.0), Vector3(13.0, 0.0, -110.0)],
		["spike hall, west arrival", Vector3(-10.0, 0.0, -110.0), Vector3(-7.0, 0.0, -110.0)],
		# THE LONG HALLWAY MUST BE A WALK, not a squeeze. Both legs claimed end to end for the
		# widest authored body, because the one thing a journey may never be is fiddly.
		["east hall, first leg", Vector3(36.0, 0.0, -114.0), Vector3(64.0, 0.0, -114.0)],
		["east hall, second leg", Vector3(74.0, 0.0, -122.0), Vector3(110.0, 0.0, -122.0)],
		["works", Vector3(120.0, 0.0, -132.0), Vector3(142.0, 0.0, -132.0)],
		["the arena link", Vector3(152.0, 0.0, -138.0), Vector3(164.0, 0.0, -138.0)],
		["arena, north perimeter", Vector3(176.0, 0.0, -150.0), Vector3(214.0, 0.0, -150.0)],
		["arena, south perimeter", Vector3(176.0, 0.0, -121.0), Vector3(214.0, 0.0, -121.0)],
		# THE ROUTE TO THE COMMITMENT POINT. Pinned as its own lane because the ruling is explicit
		# that the hazard FRAMES the plate and never gates it: reaching the middle of the room must
		# never be a timing puzzle, so this must stay walkable with every arm extended.
		["arena, the plate approach", Vector3(176.0, 0.0, -130.0), Vector3(191.0, 0.0, -130.0)],
		["reward hall", Vector3(226.0, 0.0, -134.0), Vector3(248.0, 0.0, -134.0)],
		# THE OPTIONAL LIMB IS HELD TO THE SAME BAR as the critical path. A branch the player is
		# invited to skip is not a branch that may be cramped.
		["west pocket (optional)", Vector3(-54.0, 0.0, -89.0), Vector3(-38.0, 0.0, -89.0)],
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
		Vector3(32.0, 0.0, -80.0),   # the descent into the lane
		Vector3(21.0, 0.0, -91.0),   # the spike lane's commitment line
		Vector3(2.0, 0.0, -91.0),    # its far side
		Vector3(-46.0, 0.0, -89.0),  # the optional west pocket
		Vector3(-13.0, 0.0, -104.0), # the bay's doorway
		Vector3(10.0, 0.0, -152.0),  # junction
		Vector3(30.0, 0.0, -152.0),  # junction, east
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
## GROUPED BY HOST ROOM, because the floor now has TWO hazard lanes in two different chapters.
## Merging every pad on the floor into one rect produced a lane spanning 60 units of void and
## failed three ways at once -- an instrument reporting its own assumption, which is the same
## error class as the reveal tool measuring from patch centres inside solid geometry.
func test_the_spike_commitment_edge_is_uncluttered() -> void:
	# GROUPED BY CONTIGUITY. Grouping by host room was right while every hazard was a crossing and
	# wrong the moment the Arena authored three SEPARATE clusters in one space: merging them
	# produced a single 22x20 "lane" covering ground that is mostly safe, and then measured its
	# edges. Pads that touch are one hazard; pads that do not are not.
	var lanes: Array = []
	for pad: SpikePadPlan in plan.spike_pads:
		var merged: bool = false
		for i in lanes.size():
			if (lanes[i] as Rect2).grow(0.5).intersects(pad.rect):
				lanes[i] = (lanes[i] as Rect2).merge(pad.rect)
				merged = true
				break
		if not merged:
			lanes.append(pad.rect)
	assert_gte(lanes.size(), 2, "the floor authors hazards in more than one place")
	for lane: Rect2 in lanes:
		var patch_id: int = -1
		for patch: WalkablePatch in plan.patches:
			if patch.rect.intersects(lane):
				patch_id = patch.patch_id
		# Clear ground at BOTH ends of the crossing: the phase must be readable before the
		# commitment, and there must be somewhere to arrive.
		# THE PROBE FOLLOWS THE CROSSING, and the crossing axis is a property of the ROOM rather
		# than of hazards in general. The spike room is crossed south to north now, and a test that
		# always probed along x measured the flanks of a lane nobody walks down.
		var host: Rect2 = plan.patch_by_id(patch_id).rect
		var along_x: bool = host.size.x - lane.size.x > host.size.y - lane.size.y
		for step: float in [-2.0, -4.0, 2.0, 4.0]:
			var probe: Vector3
			if along_x:
				probe = Vector3(lane.position.x + step if step < 0.0 else lane.end.x + step,
					0.0, lane.get_center().y)
			else:
				probe = Vector3(lane.get_center().x, 0.0,
					lane.position.y + step if step < 0.0 else lane.end.y + step)
			assert_true(sim._bounds.fits(probe, 1.45),
				"the approach to the hazard in space %d at %s must be open ground, not a squeeze"
					% [patch_id, str(probe)])
		for obstacle: ObstaclePlan in plan.obstacles:
			assert_false(obstacle.rect.intersects(lane.grow(3.0)),
				"mass %d crowds the commitment edge of the hazard in space %d"
					% [obstacle.obstacle_id, patch_id])


## A STRUCTURE WHOSE ONLY ROLE IS COVERING FAILS THE AUTHORED-PURPOSE TEST. Four such masses have
## now been deleted across three passes and none replaced; this pins the spaces whose reveal is
## meant to come from DISTANCE rather than from something standing in front of them.
func test_the_late_chapters_carry_no_cover_only_block() -> void:
	for patch_id in [_id(&"P_ARENA"), _id(&"P_REWARD_HALL"), _id(&"P_ARENA_LINK"), _id(&"P_WORKS")]:
		var space: Rect2 = _patch(patch_id)
		for obstacle: ObstaclePlan in plan.obstacles:
			assert_false(obstacle.rect.intersects(space),
				"mass %d sits in space %d, whose reveal is meant to come from the floor's length"
					% [obstacle.obstacle_id, patch_id])


## THE COURT KEEPS ITS OPEN GROUND. A landmark to orient by, not a clutter chamber.
func test_the_court_stays_mostly_open() -> void:
	var court: Rect2 = _patch(_id(&"P_COURT"))
	var occupied: float = 0.0
	for obstacle: ObstaclePlan in plan.obstacles:
		occupied += obstacle.rect.intersection(court).get_area()
	# A HEURISTIC, and named as one: 15% is "you can see across it and fight in it", not a law.
	# Human perception remains authoritative on whether the Court still breathes.
	assert_lt(occupied / court.get_area(), 0.15,
		"the Court is %.0f%% built on; it is a court, and it has to breathe" % (occupied / court.get_area() * 100.0))
	assert_gt(occupied, 0.0, "but it does have something to orient by")


# --- 8: THE ARENA'S WAVES -----------------------------------------------------------------------

## THE WAVE SEQUENCE IS BUILT FROM PARTS THAT ALREADY EXISTED, which is why these tests pin
## BEHAVIOUR rather than machinery. An encounter already advances to "cleared" the tick its whole
## roster is dead, already emits encounter_cleared, and already fires the triggers watching it.
## Three authored encounters plus two triggers is the entire wave system, and if a future reader
## goes looking for a wave manager, the correct conclusion is that there is deliberately none.
func _commit_to_the_arena() -> void:
	_walk_the_floor()
	_walk_the_east()
	_stand_on(_region(&"T_PARTY"))


## RIGHT: the critical chapter, three authored beats before the climax. Walked in full because it
## IS the floor now -- the completion test proves it end to end without a single western room.
func _walk_the_east() -> void:
	assert_true(_walk_to(Vector3(31.0, 0.0, -110.0)), "RIGHT: east out of the T")
	# THE LONG HALLWAY, walked as ONE PIECE. Both legs are twelve deep and only the direction
	# changes at the bend; the waypoints are the bend's, not the patches'.
	assert_true(_walk_to(Vector3(50.0, 0.0, -114.0)), "along its first leg")
	assert_true(_walk_to(Vector3(68.0, 0.0, -120.0)), "round the bend")
	assert_true(_walk_to(Vector3(90.0, 0.0, -122.0)), "along the second")
	assert_true(_walk_to(Vector3(114.0, 0.0, -124.0)), "and out into the works")
	assert_true(_walk_to(Vector3(136.0, 0.0, -128.0)), "across it to its control")
	assert_false(_open(_id(&"C_WORKS_LINK")), "whose door is shut until it is hit")
	sim.debug_activate_hit_switch(_id(&"S_WORKS"))
	assert_true(_open(_id(&"C_WORKS_LINK")), "and opens when it is")
	assert_true(_walk_to(Vector3(156.0, 0.0, -136.0)), "into the link out of it")
	assert_true(_walk_to(Vector3(178.0, 0.0, -140.0)), "and into the arena")
	assert_eq(_state(_id(&"E_WAVE_1")), "dormant", "entering starts nothing -- the plate does that")
	assert_true(_walk_to(Vector3(188.0, 0.0, -134.0)), "round the south arm")
	assert_true(_walk_to(Vector3(195.0, 0.0, -130.0)), "to the middle of the room")


func test_the_second_wave_waits_while_the_first_is_alive() -> void:
	_commit_to_the_arena()
	assert_eq(_state(_id(&"E_WAVE_1")), "active", "the first wave runs on entry")
	assert_eq(_state(_id(&"E_WAVE_2")), "dormant", "and the second waits")
	# Kill all but one, and tick well past any plausible timer: the gate on wave 2 is the last
	# member's LIFE, never elapsed time.
	var roster: Array = sim._encounter_roster[_id(&"E_WAVE_1")]
	for i in range(1, roster.size()):
		sim._health[roster[i]] = 0.0
	for _i in 120:
		sim.tick([], DT)
	assert_eq(_state(_id(&"E_WAVE_1")), "active", "one survivor keeps its wave running")
	assert_eq(_state(_id(&"E_WAVE_2")), "dormant", "so the next wave has not begun")


func test_the_last_death_of_a_wave_activates_the_next_exactly_once() -> void:
	_commit_to_the_arena()
	_kill_roster(_id(&"E_WAVE_1"))
	assert_eq(_state(_id(&"E_WAVE_1")), "cleared", "the wave completes")
	assert_eq(_state(_id(&"E_WAVE_2")), "active", "and the next begins")
	var size_after_activation: int = sim._encounter_roster[_id(&"E_WAVE_2")].size()
	for _i in 60:
		sim.tick([], DT)
	assert_eq(sim._encounter_roster[_id(&"E_WAVE_2")].size(), size_after_activation,
		"a spent trigger must not fire again and spawn the wave twice")


## ENGAGEMENT COMES FROM THE ORDINARY LAW, not from anything the waves add -- and that law has a
## RANGE, which is the point of this test. Activation engages every member, and then the ordinary
## leash immediately drops any whose spawn anchor is further than 18 from the player. The first
## rosters ignored that and two thirds of wave 2 spawned inert.
##
## So the wave system is not exempted; the ROSTERS are placed to satisfy it.
func test_a_newly_activated_wave_is_engaged_like_any_other_encounter() -> void:
	_commit_to_the_arena()
	_kill_roster(_id(&"E_WAVE_1"))
	for member_id: int in sim._encounter_roster[_id(&"E_WAVE_2")]:
		assert_eq(String(sim._ai_state.get(member_id, "")), "active",
			"actor %d must be engaged the moment its wave activates" % member_id)


## THE ARENA USES THE ARENA -- the inverse of the constraint this test used to carry.
##
## An earlier version asserted that every wave spawned WITHIN 18 units of the room's centre,
## because a member placed further out engaged and then went inert on the next tick. That was a
## workaround wearing a law's clothes, and it has been replaced by a fix at the engagement seam.
## So the test is inverted deliberately: a 46-wide arena whose fights all happen in a circle in
## the middle is a small room with wasted edges, and the freedom that was won here should fail
## loudly if a future edit quietly gives it back.
func test_the_waves_use_the_whole_arena() -> void:
	var arena_rect: Rect2 = _patch(_id(&"P_ARENA"))
	for site: EncounterSite in plan.encounters:
		if not [_id(&"E_WAVE_1"), _id(&"E_WAVE_2"), _id(&"E_WAVE_3")].has(site.encounter_id):
			continue
		var spread: Rect2 = Rect2(Vector2(site.roster[0]["position"].x, site.roster[0]["position"].z), Vector2.ZERO)
		for member: Dictionary in site.roster:
			spread = spread.expand(Vector2(member["position"].x, member["position"].z))
		assert_gt(spread.size.x, arena_rect.size.x * 0.35,
			"wave %d spans only %.0f of the arena's %.0f width; it is huddling, not composing"
				% [site.encounter_id, spread.size.x, arena_rect.size.x])


func test_the_way_on_stays_shut_until_the_final_wave_is_cleared() -> void:
	_commit_to_the_arena()
	assert_false(_open(_id(&"C_ARENA_REWARD")), "shut while wave 1 runs")
	_kill_roster(_id(&"E_WAVE_1"))
	assert_false(_open(_id(&"C_ARENA_REWARD")), "shut while wave 2 runs")
	_kill_roster(_id(&"E_WAVE_2"))
	assert_false(_open(_id(&"C_ARENA_REWARD")), "shut while wave 3 runs")
	_kill_roster(_id(&"E_WAVE_3"))
	assert_eq(_state(_id(&"E_WAVE_3")), "cleared", "the encounter completes")
	assert_true(_open(_id(&"C_ARENA_REWARD")), "and only then does the way on open")


## BOTH DOORS STAY SHUT FOR THE DURATION. The rear was closed by the commitment and the forward
## door by the waves, so the Arena is a room with no exit until it is finished -- which is what
## makes it a climax rather than a corridor with enemies in it.
func test_the_arena_seals_at_both_ends() -> void:
	_commit_to_the_arena()
	assert_false(_open(_id(&"C_LINK_ARENA")), "the way back closed when the party committed")
	assert_false(_open(_id(&"C_ARENA_REWARD")), "and the way on is not open yet")
	assert_eq(sim.debug_describe_floor()["active_confinement"], _id(&"E_WAVE_1"),
		"the running wave holds the player in its region")
	_kill_roster(_id(&"E_WAVE_1"))
	assert_eq(sim.debug_describe_floor()["active_confinement"], _id(&"E_WAVE_2"),
		"and confinement passes to the next wave without a gap to walk out through")


## SAME INPUTS, SAME PROGRESSION. The waves add no clock, no random draw and no per-run state, so
## two identical runs must agree exactly -- including on which tick each wave turned over.
func test_the_wave_progression_is_deterministic() -> void:
	var first: Array = _run_the_waves()
	before_each()
	var second: Array = _run_the_waves()
	assert_eq(first, second, "the same sequence must produce the same wave progression")


func _run_the_waves() -> Array:
	_commit_to_the_arena()
	var progression: Array = []
	for encounter_id in [_id(&"E_WAVE_1"), _id(&"E_WAVE_2"), _id(&"E_WAVE_3")]:
		progression.append([encounter_id, sim._encounter_roster[encounter_id].size()])
		_kill_roster(encounter_id)
		progression.append([encounter_id, _state(encounter_id), sim.tick_count])
	return progression


# --- 9: THE DECISION AND THE COMMITMENT ---------------------------------------------------------

## NEITHER OPTIONAL LIMB MAY BE REQUIRED. The end-to-end walk already proves the floor completes
## without entering them; this pins the other half -- that they are genuinely reachable before the
## commitment, so declining them is a choice the player got to make.
func test_the_whole_west_is_reachable_from_the_fork_before_committing() -> void:
	_walk_the_floor()
	# BOTH MOUTHS BELONG TO THE SAME ROOM, which is what makes it a fork rather than two doors a
	# room apart. Pinned as a property of the plan, not merely walked: a future edit that moves
	# one of them elsewhere breaks here with the reason.
	# BOTH ARMS BELONG TO THE SAME HALLWAY, which is what makes it a T rather than two doors a
	# room apart -- and the spike room is deliberately NOT one of them.
	assert_true(_connection_touches(_id(&"C_JUNCTION_WEST"), _id(&"P_JUNCTION")), "the optional arm leaves the T")
	assert_true(_connection_touches(_id(&"C_JUNCTION_EAST"), _id(&"P_JUNCTION")), "and so does the critical arm")
	assert_true(_open(_id(&"C_JUNCTION_WEST")), "the west arm is open at the fork")
	assert_true(_open(_id(&"C_JUNCTION_EAST")), "and so is the east")
	_walk_the_west()
	assert_true(_walk_to(Vector3(-46.0, 0.0, -88.0)), "the pocket can be walked into")
	assert_true(_walk_to(Vector3(-46.0, 0.0, -116.0)), "and the chapter continues into the bay")


## AND IT IS STILL REACHABLE AFTER LOOKING AT THE ARENA. Walking in, seeing what is there and
## walking back out must cost nothing -- otherwise the fork is decided by curiosity rather than by
## choice, which is the opposite of what a commitment plate is for.
func test_entering_the_arena_does_not_commit_you() -> void:
	_walk_the_floor()
	_walk_the_east()
	assert_eq(_state(_id(&"E_WAVE_1")), "dormant", "nothing has started")
	assert_true(_open(_id(&"C_LINK_ARENA")), "and the way back is still open")
	assert_true(_walk_to(Vector3(178.0, 0.0, -140.0)), "so you can walk back out")
	assert_true(_walk_to(Vector3(158.0, 0.0, -136.0)), "to the link")


## THE LOOP CLOSES FROM THE FAR SIDE, which is the difference between a loop and an out-and-back:
## what the player gets for going all the way is that they need not come all the way back.
func test_reaching_the_cache_opens_the_way_home() -> void:
	assert_false(_open(_id(&"C_RETURN")), "the return door starts shut")
	_walk_the_floor()
	_walk_the_west()
	assert_true(_walk_to(Vector3(-46.0, 0.0, -88.0)), "into the pocket")
	assert_true(_walk_to(Vector3(-46.0, 0.0, -116.0)), "into the bay")
	sim.debug_activate_hit_switch(_id(&"S_ALTERNATE"))
	assert_true(_walk_to(Vector3(-38.0, 0.0, -134.0)), "through the east door")
	assert_false(_open(_id(&"C_RETURN")), "still shut with the cache unreached")
	assert_true(_walk_to(Vector3(-22.0, 0.0, -126.0)), "into the cache")
	assert_true(_open(_id(&"C_RETURN")), "reaching it opens the way home")
	assert_true(_walk_to(Vector3(-19.0, 0.0, -116.0)), "up the return run")
	assert_true(_walk_to(Vector3(-19.0, 0.0, -96.0)), "and back into the hall")


## THE COMMITMENT MEANS ONE THING, and it means it indivisibly: the late floor opens and the
## exploration phase closes in the same instant. A plate that only opened would be a door.
func test_the_commitment_starts_the_fight_and_closes_the_way_back() -> void:
	_walk_the_floor()
	_walk_the_east()
	assert_true(_open(_id(&"C_LINK_ARENA")), "precondition: the way back is open on arrival")
	assert_eq(_state(_id(&"E_WAVE_1")), "dormant", "precondition: the fight has not started")
	_stand_on(_region(&"T_PARTY"))
	assert_eq(_state(_id(&"E_WAVE_1")), "active", "the fight begins")
	assert_false(_open(_id(&"C_LINK_ARENA")), "and the way back closes, in the same instant")


## THE HALL'S CONTROL IS THE WAY ON, and the enemies are pressure on the task rather than a clear
## condition. Stated as a test because the two read identically in a screenshot and completely
## differently in play -- and because a future sealing flag on this encounter would silently turn
## one into the other.
func test_the_hall_is_optional_content_that_seals_nobody_in() -> void:
	_walk_the_floor()
	_walk_the_west()
	assert_eq(_state(_id(&"E_HALL")), "active", "its fight runs when entered")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1,
		"but it seals nobody in -- a room you chose to enter may be a room you leave")


# --- 10: THE DAMAGE LEDGER IS ACTUALLY CONNECTED ------------------------------------------------

## SILENCE FROM AN INACTIVE OBSERVER IS NOT EVIDENCE (§27, and four prior instances in this
## project). An attribution table that is wired beside the real path instead of into it reports a
## confident, empty, wrong answer -- so this drives a REAL enemy hit and a REAL status tick through
## arena.gd's own _report_events and asserts both arrive.
func test_the_damage_ledger_records_a_real_hit_through_the_real_path() -> void:
	arena.damage_ledger.reset()
	sim.debug_override_health(player, 200.0)
	var before: float = arena.damage_ledger.health_damage
	# A genuine authored attack from a genuine enemy, resolved by the ordinary pipeline.
	var enemy_id: int = sim._encounter_roster[_id(&"E_LANDING")][0]
	sim.register_weapon(&"ledger_probe", 12.0, &"force", 2.0, 90.0, 0.0, 9999)
	var events: Array[Event] = sim._resolve_hit_on_target(
		enemy_id, player, sim._weapons[&"ledger_probe"], Vector3(0, 0, -1), "ledger_probe")
	arena._report_events(events)
	assert_gt(arena.damage_ledger.health_damage, before,
		"a hit on the Envoy must reach the ledger through the driver's own reporting loop")
	assert_gt(arena.damage_ledger.rows.size(), 0, "and leave an attributable row")
	var row: Dictionary = arena.damage_ledger.rows[arena.damage_ledger.rows.size() - 1]
	assert_eq(String(row.channel), "health")
	assert_eq(int(row.source_actor), enemy_id, "attributed to the actor that actually hit")


func test_the_damage_ledger_records_a_real_status_tick_with_its_owner() -> void:
	arena.damage_ledger.reset()
	sim.debug_override_health(player, 200.0)
	var enemy_id: int = sim._encounter_roster[_id(&"E_LANDING")][0]
	# Burn owned by the ENEMY, applied to the player: the case a ledger must attribute, because a
	# DoT is the one damage source with no on-screen cause at the moment it kills you.
	sim._apply_status(player, &"burn", "hit", enemy_id, "test")
	var seen: bool = false
	for _i in 400:
		var events: Array[Event] = sim.tick([] as Array[Command], DT)
		arena._report_events(events)
		if arena.damage_ledger.status_damage > 0.0:
			seen = true
			break
	assert_true(seen, "a status tick on the Envoy must reach the ledger -- not merely exist in the sim")
	var row: Dictionary = arena.damage_ledger.rows[arena.damage_ledger.rows.size() - 1]
	assert_eq(String(row.channel), "status")
	assert_eq(int(row.source_actor), enemy_id, "carrying the owner the provenance fix now preserves")


## AND THE EVALUATOR CAN ACTUALLY SEE IT -- a SECOND question from "is it recorded", and the one
## the previous build got wrong. The ledger worked perfectly and printed only on the player's
## death; the next replay did not die, so a live instrument reported nothing and read as "no
## damage happened". Recording was proven; being observable was not.
func test_the_damage_ledger_is_visible_on_the_debug_hud() -> void:
	arena.damage_ledger.reset()
	sim.debug_override_health(player, 200.0)
	var enemy_id: int = sim._encounter_roster[_id(&"E_LANDING")][0]
	sim.register_weapon(&"hud_probe", 17.0, &"force", 2.0, 90.0, 0.0, 9999)
	arena._report_events(sim._resolve_hit_on_target(
		enemy_id, player, sim._weapons[&"hud_probe"], Vector3(0, 0, -1), "hud_probe"))
	# One frame of the driver's own loop -- the label is written where the game writes it.
	arena._physics_process(DT)
	var shown: String = arena._seed_label.text
	assert_true(shown.contains("damage"), "the debug HUD must carry a damage readout: %s" % shown)
	assert_false(shown.contains("none yet"),
		"and it must reflect damage that actually landed, not a resting default: %s" % shown)
	assert_true(shown.contains("seed"), "without displacing the seed line it shares")

	# AND IT FITS. The first version of this test asserted only that the STRING was set, and the
	# label it was set on was 500px wide -- so the damage half ran off the end and two human
	# screenshots came back showing the seed line alone. "The data reached the label" and "the
	# evaluator can read it" are the same two questions as "recorded" and "observable", and I made
	# the same mistake one layer further out.
	var font: Font = arena._seed_label.get_theme_font(&"font")
	var font_size: int = arena._seed_label.get_theme_font_size(&"font_size")
	var needed: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	assert_lte(needed, arena._seed_label.size.x,
		"the readout needs %.0fpx and the label is %.0fpx wide -- it is being cut off on screen"
			% [needed, arena._seed_label.size.x])


# --- 11: CONNECTORS ARE NOT OCCLUDERS -----------------------------------------------------------

## A CONNECTOR MOVES YOU; IT DOES NOT HIDE THINGS (ruled 2026-09-09).
##
## Aperture flanks were emitted as full-height wall unconditionally, which is right for a doorway
## punched through an enclosed room and wrong for a hallway between two open spaces. Every
## connector on the critical route was getting the doorway treatment, so a fifty-unit bend read as
## a trench you were being funnelled along -- however low the rooms at either end were.
##
## The distinction this pins is the one the ruling draws: a route you travel is rimmed, a door
## that shuts is walled. Occlusion may happen along a connector; it is never its job, and a
## destination owns its own reveal.
func test_the_critical_route_is_rimmed_rather_than_walled() -> void:
	var rimmed: Array = [_id(&"C_TO_JUNCTION"), _id(&"C_JUNCTION_WEST"), _id(&"C_JUNCTION_EAST"),
		_id(&"C_EAST_HALL_BEND"), _id(&"C_HALL_WORKS"), _id(&"C_LINK_ARENA"), _id(&"C_TO_LANE"), _id(&"C_TO_HALL")]
	for connection: TraversalConnection in plan.connections:
		if not rimmed.has(connection.connection_id):
			continue
		assert_eq(connection.flank_style, &"ledge",
			"connection %d carries the route; its flanks must be a rim, not a wall" % connection.connection_id)


## AND A DOOR THAT SHUTS STILL LOOKS LIKE ONE. The exception is not an oversight: a closable gate
## needs geometry a player can believe closed, so the two doors on this floor that actually shut
## keep their walls.
func test_every_closable_door_keeps_real_walls() -> void:
	var closable: int = 0
	for connection: TraversalConnection in plan.connections:
		if connection.starts_open:
			continue
		closable += 1
		assert_eq(connection.flank_style, &"wall",
			"connection %d can be shut, so it must read as something that can shut" % connection.connection_id)
	assert_gt(closable, 0, "sanity: the floor must actually author doors that close")


## THE TWO SEGMENT VIEWS MUST STAY COMPLEMENTS, which is the defect this pins rather than a
## property anyone would have thought to assert.
##
## solid_segments() and open_edge_segments() are documented as ONE derivation read two ways: a
## boundary is a wall or it is a rim, and every boundary is exactly one of them. They were kept in
## step by hand, so when connection flanks learned a style, one call site got the argument and the
## other did not -- and every rimmed connector was re-derived as `wall` in the open view, then
## filtered out of BOTH sets. No wall, no lip, and a hallway whose edges were simply absent.
##
## The human saw it immediately as "the walkway edges disappear into flat geometry". The code
## could have said so first.
func test_every_authored_boundary_is_either_a_wall_or_a_rim() -> void:
	var walls: int = plan.solid_segments().size()
	var rims: int = plan.open_edge_segments().size()
	assert_gt(walls, 0, "sanity: the floor authors real walls")
	assert_gt(rims, 0, "sanity: and real rims")
	for connection: TraversalConnection in plan.connections:
		var flanked: bool = false
		var wanted: StringName = connection.flank_style
		var pool: Array = plan.solid_segments() if wanted == &"wall" else plan.open_edge_segments()
		for segment: Dictionary in pool:
			if String(segment["style"]) != String(wanted):
				continue
			# A flank runs along the aperture's own edge, on either axis.
			var on_x: bool = segment["axis"] == &"x" and (
				absf(float(segment["at"]) - connection.aperture.position.x) < 0.01
				or absf(float(segment["at"]) - connection.aperture.end.x) < 0.01)
			var on_z: bool = segment["axis"] == &"z" and (
				absf(float(segment["at"]) - connection.aperture.position.y) < 0.01
				or absf(float(segment["at"]) - connection.aperture.end.y) < 0.01)
			if on_x or on_z:
				flanked = true
				break
		assert_true(flanked,
			"connection %d asks for %s flanks and appears in neither view -- its edges are nowhere"
				% [connection.connection_id, wanted])


## AND THE RIM IS NOT A LIE. It is knee-high and shots cross it, exactly like every other ledge on
## the floor -- which is why lowering these was a change of STYLE and not a change of truth. A
## boundary that looks passable and stops a shot is the presentation-lies defect; so is its
## opposite, and this floor has now been bitten by the first one twice.
func test_a_rimmed_connector_does_not_secretly_block_shots() -> void:
	var walled: int = 0
	for segment: Dictionary in plan.solid_segments():
		if String(segment["style"]) == "wall":
			walled += 1
	# The sim receives solid_segments() and nothing else, so a rimmed flank contributing no wall
	# segment IS the guarantee: there is no invisible collider left behind it.
	var before_rimming: int = 70
	assert_lt(walled, before_rimming,
		"rimming the connectors must actually remove their wall segments, not merely retint them")


## ROOMS DO NOT OVERLAP (ruled 2026-09-09).
##
## The human's word for the eastern chapter was "patch soup": rectangles layered beside and across
## each other, so nothing said where one space ended and the next began. Overlap is how that
## happens -- two patches sharing ground need no doorway, so they get none, and the player is
## given no punctuation at all.
##
## The oldest offender was not eastern at all: the Landing and the West Hall had overlapped by 40
## square units since the floor was first authored, joined by that overlap and nothing else. This
## is a Floor 2 authoring target rather than a global validator, so it lives here.
func test_no_two_rooms_share_ground() -> void:
	for a: WalkablePatch in plan.patches:
		for b: WalkablePatch in plan.patches:
			if a.patch_id >= b.patch_id:
				continue
			assert_eq(a.rect.intersection(b.rect).get_area(), 0.0,
				"patches %d and %d share ground; a doorway is architecture, an overlap is an accident"
					% [a.patch_id, b.patch_id])


## THE CONTENT ANSWERS FOR ITS OWN NAMES (P36 Slice A). These used to be constants on a builder
## script, which only worked while the coordinates lived in code. The layout resource is the
## authoring surface now, so the names come from it.
func _id(key: StringName) -> int:
	return L.id_for(key)


func _region(key: StringName) -> Rect2:
	return L.region_for(key)
