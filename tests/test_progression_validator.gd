extends GutTest
## THE PROGRESSION VALIDATOR, PROVED AGAINST THE FLOORS THAT SHIP (ADR-001 S0).
##
## Three kinds of evidence, in this order:
##   1. the shipped floors PASS, and what the validator believes about them matches what their
##      content was authored to do (the crate before the plate, the keys before the locks);
##   2. the validator's own route through each floor REPLAYS in a real SimWorld and completes it --
##      the model's reading of triggers, effects, watchers and keys is the sim's reading;
##   3. negative fixtures: supported invalid progression FAILS, and what the model cannot establish
##      is UNSUPPORTED, never rounded to PASS.

const PROTOTYPE := "res://game/content/layouts/archive_prototype.tres"
const ROUNDABOUT := "res://game/content/layouts/archive_roundabout.tres"
const TERMINAL := "res://game/content/layouts/terminal.tres"
const FOUNDRY := "res://game/content/layouts/foundry_assembly.tres"
const READY_ROOM := "res://game/content/layouts/ready_room.tres"
const COMMONS := "res://game/content/layouts/commons.tres"
const SHIPPED_DEPTHS: Array[int] = [1, 2, 3, 4]

const ENVOY: int = 0
const DT := 1.0 / 30.0
## Replay bound: every step is one action plus a handful of ticks, never an open-ended wait.
const SETTLE_TICKS := 3


## The sim's own meanings for the rules, from content -- never numbers restated here.
func _rules() -> Dictionary:
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_A")
	return {"body_radius": envoy.combat_radius, "attack_reach": sword.reach, "pickup_reach": envoy.pickup_reach}


func _compiled(path: String) -> FloorPlan:
	var plan := FloorPlan.new()
	LayoutCompiler.compile(load(path), plan)
	return plan


func _check(plan: FloorPlan) -> ProgressionReport:
	return ProgressionValidator.check(plan, _rules())


## The first finding of a kind. A missing finding is an assertion failure with the report's
## summary, never an index crash, so a wrong verdict reads as the defect it is.
func _finding(report: ProgressionReport, kind: StringName) -> Dictionary:
	var found: Array[Dictionary] = report.findings_of(kind)
	assert_false(found.is_empty(), "expected a %s finding: %s" % [kind, report.summary()])
	if found.is_empty():
		return {"trace": [] as Array[String], "refs": {"closed_connections": [], "unfired_triggers": [],
			"connections_never_opened": [], "triggers_never_fired": []}}
	return found[0]


func _id(path: String, layer: StringName, key: StringName) -> int:
	return (load(path) as AuthoredLayout).id_in(layer, key)


func _trigger(plan: FloorPlan, trigger_id: int) -> FloorTrigger:
	for trigger in plan.triggers:
		if trigger.trigger_id == trigger_id:
			return trigger
	return null


func _step_index(trace: Array[String], prefix: String) -> int:
	for index in trace.size():
		if trace[index].begins_with(prefix):
			return index
	return -1


# --- 1. THE SHIPPED FLOORS --------------------------------------------------------------------

func test_every_shipped_floor_passes_and_ends_on_its_exit_plate() -> void:
	for depth in SHIPPED_DEPTHS:
		var plan: FloorPlan = DepthGenerator.generate(0, depth)
		var report: ProgressionReport = _check(plan)
		assert_eq(report.outcome, ProgressionReport.OUTCOME_PASS, "depth %d: %s" % [depth, report.summary()])
		assert_eq(report.findings, [] as Array[Dictionary], "depth %d reports nothing" % depth)
		assert_gt(report.trace.size(), 0, "depth %d has a route" % depth)
		var exit_id: int = -1
		for trigger in plan.triggers:
			for effect: Dictionary in trigger.effects:
				if effect["kind"] == FloorLayers.EFFECT_COMPLETE_FLOOR:
					exit_id = trigger.trigger_id
		var last_step: String = "" if report.trace.is_empty() else report.trace[-1]
		assert_eq(last_step, "enter trigger %d" % exit_id, "depth %d ends on the exit plate" % depth)
		assert_eq(_check(plan).to_dict(), report.to_dict(), "depth %d: deterministic" % depth)
		assert_lt(report.states_explored, 5000, "depth %d: a floor's progression is a small state space" % depth)


## Only what progression depends on becomes state; what was left out is listed, not hidden.
func test_floor_two_ignores_its_scenery_props_but_not_its_route_blocker_or_its_vault_cover() -> void:
	var report: ProgressionReport = _check(DepthGenerator.generate(0, 2))
	var ignored: Array = report.ignored.get("breakables", [])
	assert_has(ignored, _id(ROUNDABOUT, &"breakable", &"B_COURT_A"), "a search prop with no consequence")
	assert_does_not_have(ignored, _id(ROUNDABOUT, &"breakable", &"B_HALL_RUBBLE"), "rubble that blocks ground")
	assert_does_not_have(ignored, _id(ROUNDABOUT, &"breakable", &"B_VAULT_COVER"), "the cover a trigger watches")
	assert_has(report.ignored["encounters"], _id(ROUNDABOUT, &"encounter", &"E_COURT"), "an optional, unwatched, non-sealing fight")
	assert_does_not_have(report.ignored["encounters"], _id(ROUNDABOUT, &"encounter", &"E_WAVE_1"), "a sealing wave")
	assert_true(report.summary().contains("progression-neutral breakables ignored:"), report.summary())


## PASS is conditional on the fights, and says so: every mandatory encounter on the route is an
## assumption, never a silent given.
func test_a_pass_lists_the_fights_it_assumes_won() -> void:
	var report: ProgressionReport = _check(DepthGenerator.generate(0, 2))
	var arena_wave: int = _id(ROUNDABOUT, &"encounter", &"E_WAVE_3")
	assert_has(report.assumptions, "encounter %d is cleared by combat" % arena_wave)
	assert_true(report.summary().begins_with("progression: PASS (assuming"), report.summary())
	var terminal: ProgressionReport = _check(DepthGenerator.generate(0, 3))
	assert_eq(terminal.assumptions, [] as Array[String], "the Terminal asks nothing of the party")
	assert_true(terminal.summary().begins_with("progression: PASS after"), terminal.summary())


## Floor 1's authored dependency, read back: the hidden plate is dormant until the crate breaks.
func test_floor_one_breaks_the_crate_before_it_can_stand_on_the_hidden_plate() -> void:
	var report: ProgressionReport = _check(DepthGenerator.generate(0, 1))
	var crate: int = _step_index(report.trace, "break breakable %d" % _id(PROTOTYPE, &"breakable", &"B_CRATE"))
	var plate: int = _step_index(report.trace, "enter trigger %d" % _id(PROTOTYPE, &"trigger", &"T_HIDDEN_PLATE"))
	assert_gt(crate, -1, "the crate is broken: %s" % str(report.trace))
	assert_gt(plate, crate, "and only then is the plate stood on")


func test_floor_one_cannot_finish_if_the_crate_no_longer_enables_the_plate() -> void:
	var plan: FloorPlan = _compiled(PROTOTYPE)
	_trigger(plan, _id(PROTOTYPE, &"trigger", &"T_CRATE")).effects = []
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_FAIL, report.summary())
	var finding: Dictionary = _finding(report, &"exit_unreachable")
	assert_has(finding["refs"]["triggers_never_fired"], _id(PROTOTYPE, &"trigger", &"T_HIDDEN_PLATE"))
	assert_has(finding["refs"]["connections_never_opened"], _id(PROTOTYPE, &"connection", &"C_TO_APPROACH"))


## Floor 2's west loop is optional by design: its door can stay shut and the floor still ends.
func test_floor_two_still_finishes_with_the_cache_door_never_opening() -> void:
	var plan: FloorPlan = _compiled(ROUNDABOUT)
	_trigger(plan, _id(ROUNDABOUT, &"trigger", &"T_CACHE")).effects = []
	assert_eq(_check(plan).outcome, ProgressionReport.OUTCOME_PASS)


func test_floor_two_cannot_finish_if_the_last_wave_opens_nothing() -> void:
	var plan: FloorPlan = _compiled(ROUNDABOUT)
	_trigger(plan, _id(ROUNDABOUT, &"trigger", &"T_WAVE_3_CLEAR")).effects = []
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_FAIL, report.summary())
	assert_has(_finding(report, &"exit_unreachable")["refs"]["connections_never_opened"],
		_id(ROUNDABOUT, &"connection", &"C_ARENA_REWARD"))


## Floor 4's two keys open two locks; the route carries both, and one key cannot do it.
func test_floor_four_delivers_both_keys_and_fails_with_one() -> void:
	var report: ProgressionReport = _check(DepthGenerator.generate(0, 4))
	var west: int = _id(FOUNDRY, &"carriable", &"K_WEST")
	var east: int = _id(FOUNDRY, &"carriable", &"K_EAST")
	assert_gt(_step_index(report.trace, "deliver carriable %d" % west), -1, str(report.trace))
	assert_gt(_step_index(report.trace, "deliver carriable %d" % east), -1, str(report.trace))
	var plan: FloorPlan = _compiled(FOUNDRY)
	plan.carriables = plan.carriables.filter(func(key: CarriablePlan) -> bool: return key.carriable_id != west)
	var short: ProgressionReport = _check(plan)
	assert_eq(short.outcome, ProgressionReport.OUTCOME_FAIL, short.summary())


func test_the_ready_room_passes_and_a_place_without_an_exit_says_so() -> void:
	assert_eq(_check(_compiled(READY_ROOM)).outcome, ProgressionReport.OUTCOME_PASS)
	var commons: ProgressionReport = _check(_compiled(COMMONS))
	assert_eq(commons.outcome, ProgressionReport.OUTCOME_FAIL)
	assert_eq(commons.findings_of(&"no_exit").size(), 1)


# --- 2. THE ROUTE REPLAYS IN THE REAL SIM ----------------------------------------------------

## Every supported action in the validator's route, performed through the sim's own entry points
## (occupancy by standing there, props by the breakable path, switches by the switch path, keys by
## lift and insert, fights by their roster dying), ends in the sim's own floor_complete. The
## Envoy is MOVED, not walked: this proves the model's reading of triggers, effects, watchers and
## keys, not its reachability -- that is proved by the fixtures below.
func test_each_shipped_route_replays_through_a_real_sim_world() -> void:
	for depth in SHIPPED_DEPTHS:
		var plan: FloorPlan = DepthGenerator.generate(0, depth)
		var report: ProgressionReport = _check(plan)
		assert_true(report.is_pass(), "depth %d" % depth)
		var sim: SimWorld = _sim_with(plan)
		var completed: bool = false
		for step in report.trace:
			var words: PackedStringArray = step.split(" ")
			var events: Array[Event] = []
			match words[0]:
				"enter":
					var trigger: FloorTrigger = _trigger(plan, int(words[2]))
					sim.entities[ENVOY] = Vector3(trigger.region.get_center().x, 0.0, trigger.region.get_center().y)
				"break":
					events.append_array(sim._resolve_hit_on_breakable(-1, int(words[2]), 1000.0))
				"hit":
					events.append_array(sim._resolve_hit_on_switch(int(words[2])))
				"lift":
					events.append_array(sim._lift_carriable(ENVOY, int(words[2])))
				"deliver":
					events.append_array(sim._insert_carried(ENVOY, int(words[5])))
				"clear":
					pass  # an empty roster is already dead: the next tick clears it
				_:
					fail_test("depth %d: unreplayable step '%s'" % [depth, step])
			for i in SETTLE_TICKS:
				events.append_array(sim.tick([] as Array[Command], DT))
			for event in events:
				if event.kind == "floor_complete":
					completed = true
		assert_true(completed, "depth %d: the sim completed the floor along the validator's route" % depth)


func _sim_with(plan: FloorPlan) -> SimWorld:
	var sim := SimWorld.new()
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	sim.add_entity(ENVOY, plan.entry_point, envoy.move_speed, Vector3(0, 0, -1), envoy.combat_radius)
	sim.register_combatant(ENVOY, envoy.max_health, envoy.family, envoy.iframe_ticks_on_hit, envoy.combat_radius, &"player")
	sim.register_carrier(ENVOY, envoy.pickup_reach, envoy.pickup_cone_half_angle_degrees, envoy.pickup_underfoot_radius)
	sim.mark_run_persistent(ENVOY)
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	sim.register_obstacles(plan.obstacle_rects())
	sim.register_solid_segments(plan.solid_segments())
	for connection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
	for encounter in plan.encounters:
		sim.register_encounter(encounter.encounter_id, encounter.regions, encounter.role, encounter.confines_player, encounter.spawn_at_floor_load)
	for breakable in plan.breakables:
		sim.register_breakable(breakable.breakable_id, breakable.position, breakable.radius, breakable.durability, breakable.blocking_rect)
	for hit_switch in plan.hit_switches:
		sim.register_hit_switch(hit_switch.switch_id, hit_switch.position, hit_switch.radius, hit_switch.mode, hit_switch.effects, hit_switch.starts_hidden)
	for carriable in plan.carriables:
		sim.register_carriable(carriable.carriable_id, carriable.position, carriable.starts_hidden)
	for trigger in plan.triggers:
		sim.register_trigger(trigger.trigger_id, trigger.kind, trigger.region, trigger.source_id, trigger.once, trigger.effects, trigger.starts_enabled)
	return sim


# --- 3. NEGATIVE FIXTURES ----------------------------------------------------------------------

func _patch(plan: FloorPlan, patch_id: int, rect: Rect2) -> void:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	plan.patches.append(patch)


func _connect(plan: FloorPlan, connection_id: int, near_id: int, far_id: int, aperture: Rect2, starts_open: bool) -> void:
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = aperture
	connection.starts_open = starts_open
	plan.connections.append(connection)


func _region(plan: FloorPlan, trigger_id: int, region: Rect2, effects: Array[Dictionary], kind: StringName = FloorLayers.TRIGGER_REGION, starts_enabled: bool = true) -> void:
	var trigger := FloorTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.kind = kind
	trigger.region = region
	trigger.effects = effects
	trigger.starts_enabled = starts_enabled
	plan.triggers.append(trigger)


func _exit(plan: FloorPlan, trigger_id: int, region: Rect2) -> void:
	_region(plan, trigger_id, region, [FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, FloorLayers.NO_TARGET)], FloorLayers.TRIGGER_GROUP_OCCUPANCY)


## Two rooms north to south: A (the entry, z in [0, 10]) and B (z in [-12, -2]), joined by one
## aperture. B carries a one-way line that seals the aperture behind the party.
func _two_rooms_with_a_one_way() -> FloorPlan:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_patch(plan, 1, Rect2(-5, -12, 10, 10))
	_connect(plan, 0, 0, 1, Rect2(-2, -3, 4, 4), true)
	_region(plan, 0, Rect2(-5, -8, 10, 2), [FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, 0)])
	return plan


func test_a_one_way_commitment_with_the_exit_ahead_passes() -> void:
	var plan: FloorPlan = _two_rooms_with_a_one_way()
	_exit(plan, 9, Rect2(-2, -12, 4, 2))
	assert_eq(plan.violations(), [] as Array[Dictionary], "a sane fixture")
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_PASS, report.summary())
	assert_eq(report.trace, ["enter trigger 0", "enter trigger 9"] as Array[String], "the line must be crossed to reach the plate")


## REACHABILITY FROM THE ENTRY IS NOT SAFETY. The exit is right beside arrival, yet the party can
## walk through the one-way first and never come back: that state exists, and it is a softlock.
func test_a_one_way_commitment_that_strands_the_party_is_a_softlock() -> void:
	var plan: FloorPlan = _two_rooms_with_a_one_way()
	_exit(plan, 9, Rect2(2.5, 6, 2, 2))  # in the entry room, a step from arrival
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_FAIL, report.summary())
	assert_eq(report.trace, ["enter trigger 9"] as Array[String], "reachable from arrival -- which proves nothing about safety")
	var softlock: Dictionary = _finding(report, &"softlock")
	assert_eq(softlock["trace"], ["enter trigger 0"] as Array[String], "crossed the line, and the exit was behind it")
	assert_eq(softlock["refs"]["closed_connections"], [0] as Array[int])


## A key behind a sealed door: carrying it through is a route; walking through without it is a
## state the party can reach and never leave.
func test_a_key_left_behind_a_one_way_is_a_softlock_and_carried_through_is_a_pass() -> void:
	var plan: FloorPlan = _two_rooms_with_a_one_way()
	_patch(plan, 2, Rect2(-5, -24, 10, 10))
	_connect(plan, 1, 1, 2, Rect2(-2, -15, 4, 4), false)
	_exit(plan, 9, Rect2(-2, -24, 4, 2))
	var key := CarriablePlan.new()
	key.carriable_id = 0
	key.position = Vector3(3, 0, 5)  # in A, before the line
	plan.carriables.append(key)
	var receiver := FloorTrigger.new()
	receiver.trigger_id = 5
	receiver.kind = FloorLayers.TRIGGER_CARRIABLE_INSERTED
	receiver.region = Rect2(-4, -12, 2, 2)  # in B, past the line
	receiver.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 1)]
	plan.triggers.append(receiver)
	assert_eq(plan.violations(), [] as Array[Dictionary])
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_FAIL, report.summary())
	assert_eq(report.trace, ["lift carriable 0", "enter trigger 0", "deliver carriable 0 to receiver 5", "enter trigger 9"] as Array[String])
	assert_eq(_finding(report, &"softlock")["trace"], ["enter trigger 0"] as Array[String], "through the line empty-handed")
	# The same floor with the key past the line is safe: nothing can be left behind.
	key.position = Vector3(3, 0, -11)
	assert_eq(_check(plan).outcome, ProgressionReport.OUTCOME_PASS)


## A receiver is used by STANDING IN IT: a key in hand opens nothing from across a sealed door.
func test_a_receiver_the_party_cannot_stand_in_cannot_be_used() -> void:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_patch(plan, 1, Rect2(-5, -12, 10, 10))
	_connect(plan, 0, 0, 1, Rect2(-2, -3, 4, 4), false)
	var key := CarriablePlan.new()
	key.carriable_id = 0
	key.position = Vector3(3, 0, 5)
	plan.carriables.append(key)
	var receiver := FloorTrigger.new()
	receiver.trigger_id = 5
	receiver.kind = FloorLayers.TRIGGER_CARRIABLE_INSERTED
	receiver.region = Rect2(-4, -12, 2, 2)  # behind the very gate it would open
	receiver.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 0)]
	plan.triggers.append(receiver)
	_exit(plan, 9, Rect2(2, -12, 2, 2))
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_FAIL, report.summary())
	assert_has(_finding(report, &"exit_unreachable")["refs"]["triggers_never_fired"], 5)
	# Moved to the near side of the gate, the same receiver is an ordinary supported delivery.
	receiver.region = Rect2(-4, 1, 2, 2)
	var near: ProgressionReport = _check(plan)
	assert_eq(near.outcome, ProgressionReport.OUTCOME_PASS, near.summary())
	assert_eq(near.trace, ["lift carriable 0", "deliver carriable 0 to receiver 5", "enter trigger 9"] as Array[String])


## A switch the model cannot reach by melee is not FAIL and not PASS: the floor may be finishable
## by a shot the model does not establish, and the verdict says exactly that.
func test_a_switch_beyond_melee_reach_is_unsupported_not_pass() -> void:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_patch(plan, 1, Rect2(-5, -12, 10, 10))
	_connect(plan, 0, 0, 1, Rect2(-2, -3, 4, 4), false)
	_exit(plan, 9, Rect2(-2, -12, 4, 2))
	var switch := HitSwitchPlan.new()
	switch.switch_id = 0
	switch.position = Vector3(12, 0, 5)  # 7 units off the floor's east edge: a shot, never a swing
	switch.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 0)]
	plan.hit_switches.append(switch)
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_UNSUPPORTED, report.summary())
	assert_eq(report.findings_of(&"unsupported_ranged_switches").size(), 1, report.summary())
	assert_eq(report.trace, [] as Array[String], "no supported route is claimed")
	# Within a swing's reach of the floor, the same switch is an ordinary supported action.
	switch.position = Vector3(6, 0, 5)
	var near: ProgressionReport = _check(plan)
	assert_eq(near.outcome, ProgressionReport.OUTCOME_PASS, near.summary())
	assert_eq(near.trace, ["hit switch 0", "enter trigger 9"] as Array[String])


func test_an_effect_kind_the_model_does_not_know_is_unsupported() -> void:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_region(plan, 0, Rect2(-5, 2, 10, 2), [{"kind": &"teleport_party", "target_id": -1}])
	_exit(plan, 9, Rect2(-2, 0, 4, 2))
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_UNSUPPORTED, report.summary())
	assert_eq(_finding(report, &"unknown_effect")["refs"], {"trigger": 0})


## OCCUPANCY IS A CHOICE UNLESS THE GROUND LEAVES NONE. A plate in the middle of a room can be
## walked around; a line across a corridor cannot. The model reads that from the geometry alone.
func test_a_plate_in_a_room_is_skirted_but_a_line_across_a_corridor_is_crossed() -> void:
	var room := FloorPlan.new()
	room.entry_point = Vector3(0, 0, 18)
	_patch(room, 0, Rect2(-10, -20, 20, 40))
	_region(room, 0, Rect2(-1, -1, 2, 2), [FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, 0)])
	var fight := EncounterSite.new()
	fight.encounter_id = 0
	fight.regions = [Rect2(-10, -20, 20, 40)]
	room.encounters.append(fight)
	_exit(room, 9, Rect2(-2, -20, 4, 2))
	var skirted: ProgressionReport = _check(room)
	assert_eq(skirted.outcome, ProgressionReport.OUTCOME_PASS, skirted.summary())
	assert_eq(skirted.trace, ["enter trigger 9"] as Array[String], "straight past the plate")
	assert_eq(skirted.assumptions, [] as Array[String], "no fight was needed, so none is assumed")

	var corridor := FloorPlan.new()
	corridor.entry_point = Vector3(0, 0, 18)
	_patch(corridor, 0, Rect2(-1.5, -20, 3, 40))
	_region(corridor, 0, Rect2(-1.5, -1, 3, 2), [FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, 0)])
	var line_fight := EncounterSite.new()
	line_fight.encounter_id = 0
	line_fight.regions = [Rect2(-1.5, -20, 3, 40)]
	corridor.encounters.append(line_fight)
	_exit(corridor, 9, Rect2(-1.5, -20, 3, 2))
	var crossed: ProgressionReport = _check(corridor)
	assert_eq(crossed.outcome, ProgressionReport.OUTCOME_PASS, crossed.summary())
	assert_eq(crossed.trace, ["enter trigger 0", "clear encounter 0", "enter trigger 9"] as Array[String])
	assert_eq(crossed.assumptions, ["encounter 0 is cleared by combat"] as Array[String])


## A body-wide seam: ground two cells share only at a sliver does not join them.
func test_a_sliver_beside_a_line_does_not_let_a_body_slip_past() -> void:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 18)
	_patch(plan, 0, Rect2(-2, -20, 4, 40))
	# A side bay off the corridor's north end, so the line has a real door to seal behind the party.
	_patch(plan, 1, Rect2(4, 14, 6, 6))
	_connect(plan, 0, 0, 1, Rect2(1, 16, 4, 2), true)
	# The line leaves 0.3 of ground beside it: a point could pass, a 0.45 body cannot.
	_region(plan, 0, Rect2(-2, -1, 3.7, 2), [FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, 0)])
	_exit(plan, 9, Rect2(-2, -20, 4, 2))
	var report: ProgressionReport = _check(plan)
	assert_eq(report.trace, ["enter trigger 0", "enter trigger 9"] as Array[String], report.summary())
	var point_model: ProgressionReport = ProgressionValidator.check(plan, {"body_radius": 0.0})
	assert_eq(point_model.trace, ["enter trigger 9"] as Array[String], "a bodiless point does slip past")


## Ground a body cannot be centred on is not FAIL by fiat: if walking it as a point would finish
## the floor, the verdict names that as the thing the model will not establish.
func test_a_route_that_needs_ground_narrower_than_a_body_is_unsupported() -> void:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_patch(plan, 1, Rect2(-0.3, -12, 0.6, 12.5))  # a 0.6-wide walkway south, overlapping the entry room
	_patch(plan, 2, Rect2(-5, -22, 10, 10))
	_exit(plan, 9, Rect2(-2, -22, 4, 2))
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_UNSUPPORTED, report.summary())
	assert_eq(report.findings_of(&"unsupported_thin_ground").size(), 1, report.summary())
	assert_eq(report.trace, [] as Array[String])


func test_a_blocking_prop_in_a_doorway_must_be_broken_first() -> void:
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_patch(plan, 1, Rect2(-5, -12, 10, 10))
	_connect(plan, 0, 0, 1, Rect2(-2, -3, 4, 4), true)
	var rubble := BreakablePlan.new()
	rubble.breakable_id = 3
	rubble.position = Vector3(0, 0, -1)
	rubble.radius = 1.0
	rubble.blocking_rect = Rect2(-2, -3, 4, 4)
	plan.breakables.append(rubble)
	_exit(plan, 9, Rect2(-2, -12, 4, 2))
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_PASS, report.summary())
	assert_eq(report.trace, ["break breakable 3", "enter trigger 9"] as Array[String])


func test_a_hidden_plate_fires_when_enabled_under_a_standing_envoy() -> void:
	# The crate stands ON the dormant plate: breaking it from the plate's own ground fires the plate
	# at once (the sim's edge rule), opening the way without a second step.
	var plan := FloorPlan.new()
	plan.entry_point = Vector3(0, 0, 8)
	_patch(plan, 0, Rect2(-5, 0, 10, 10))
	_patch(plan, 1, Rect2(-5, -12, 10, 10))
	_connect(plan, 0, 0, 1, Rect2(-2, -3, 4, 4), false)
	_region(plan, 1, Rect2(-5, 0, 10, 10), [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 0)], FloorLayers.TRIGGER_REGION, false)
	var crate := BreakablePlan.new()
	crate.breakable_id = 0
	crate.position = Vector3(0, 0, 5)
	plan.breakables.append(crate)
	var watcher := FloorTrigger.new()
	watcher.trigger_id = 2
	watcher.kind = FloorLayers.TRIGGER_BREAKABLE_DESTROYED
	watcher.source_id = 0
	watcher.effects = [FloorLayers.effect(FloorLayers.EFFECT_ENABLE_TRIGGER, 1)]
	plan.triggers.append(watcher)
	_exit(plan, 9, Rect2(-2, -12, 4, 2))
	var report: ProgressionReport = _check(plan)
	assert_eq(report.outcome, ProgressionReport.OUTCOME_PASS, report.summary())
	assert_eq(report.trace, ["break breakable 0", "enter trigger 9"] as Array[String], "the plate fired under the Envoy's feet")


func test_the_summary_names_the_verdict_and_the_records_involved() -> void:
	var plan: FloorPlan = _two_rooms_with_a_one_way()
	_exit(plan, 9, Rect2(2.5, 6, 2, 2))
	var text: String = _check(plan).summary()
	assert_true(text.begins_with("progression: FAIL after"), text)
	assert_true(text.contains("[fail] softlock:"), text)
	assert_true(text.contains("closed_connections [0]"), text)
	assert_true(text.contains("not modelled:"), text)
