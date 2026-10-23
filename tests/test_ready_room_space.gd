extends GutTest
## THE READY ROOM AS ONE PREPARATION HALL (M2 Slice 3, human ruling 2026-10-22): a low arrival apron
## between raised side floors; the mission console directly ahead with a broad approach either
## side, stepping up onto one open staging floor; the supply stall in a corner, armory and crafting
## along an edge; the unchanged pad in a framed recess at the far end. Walls only at the perimeter.
##
## These tests protect FUNCTION -- clearances, reach, the pad's isolation, what the camera shows --
## measured from the Envoy's own body radius and walk speed. They do not pin cosmetic geometry:
## stations are found by key and stand points are derived from where things actually are, so a
## shelf can move without a test caring, unless it starts to obstruct.

const DT := 1.0 / 30.0
const HUB_SCENE := "res://game/hub/hub_space.tscn"
const READY_ROOM := preload("res://game/content/layouts/ready_room.tres")
const ENVOY_STATS := preload("res://game/content/envoy/envoy_stats.tres")
const WALK_TICKS := 900
## The camera tests look through the project's own 16:9 window, not headless's square default.
const WINDOW := Vector2i(1152, 648)

## Ruled 2026-10-21: the 4x4 party pad is kept exactly as it was.
const PAD_REGION := Rect2(-2, -25, 4, 4)
const PARTY_SIZE := 4
## Space left between two Envoys standing side by side: comfortable, not shoulder to shoulder.
const ELBOW_ROOM := 0.4
## How far in front of a station an Envoy stands to use it, beyond its own body.
const STATION_STANDOFF := 0.6
## Four Envoys standing on a ring this wide in front of the gate.
const GATHER_RING_RADIUS := 3.0
## Walking budgets, in seconds at the Envoy's own speed, by the routes a player steers.
const STATION_WALK_SECONDS := 7.5
const PAD_WALK_SECONDS := 8.5
const MIN_PAD_DISTANCE_FROM_ENTRY := 15.0
## The pad sits this far back inside the recess mouth, so the threshold is not the commitment.
const MIN_PAD_SETBACK := 2.5
## A future merchant is drawn larger than an Envoy (the enemy bodies are 1.0).
const MERCHANT_RADIUS := 1.0
## Chest height: the point of an Envoy the camera must be able to see.
const CHEST_HEIGHT := 1.0

var _radius: float = ENVOY_STATS.combat_radius
var _window_before: Vector2i


func before_all() -> void:
	_window_before = get_tree().root.size
	get_tree().root.size = WINDOW


func after_all() -> void:
	get_tree().root.size = _window_before


func _plan() -> FloorPlan:
	var plan := FloorPlan.new()
	plan.stratum_id = READY_ROOM.stratum_id
	LayoutCompiler.compile(READY_ROOM, plan)
	plan.validate({})
	return plan


func _bounds(plan: FloorPlan) -> WalkableBounds:
	return WalkableBounds.new(plan.patch_rects(), plan.obstacle_rects())


## Compiled patches and obstacles keep their id, not their authoring key.
func _patch(plan: FloorPlan, key: StringName) -> Rect2:
	var id: int = READY_ROOM.id_in(&"patch", key)
	for patch in plan.patches:
		if patch.patch_id == id:
			return patch.rect
	fail_test("no patch %s" % key)
	return Rect2()


func _obstacle(plan: FloorPlan, key: StringName) -> ObstaclePlan:
	var id: int = READY_ROOM.id_in(&"obstacle", key)
	for obstacle in plan.obstacles:
		if obstacle.obstacle_id == id:
			return obstacle
	fail_test("no obstacle %s" % key)
	return null


func _rect(plan: FloorPlan, key: StringName) -> Rect2:
	return _obstacle(plan, key).rect


func _pad(plan: FloorPlan) -> Rect2:
	for trigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") == FloorLayers.EFFECT_COMPLETE_FLOOR:
				return trigger.region
	fail_test("no deployment pad")
	return Rect2()


func _flat(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y)


# --- WHERE THINGS ARE: derived, never restated ---------------------------------------------

## In front of the gate, on the open staging floor: where a party collects itself.
func _forecourt(plan: FloorPlan) -> Vector3:
	return _flat(_patch(plan, &"P_FLOOR").get_center())


func _pad_slots(plan: FloorPlan) -> Array[Vector3]:
	var pad: Rect2 = _pad(plan)
	var quarter: Vector2 = pad.size * 0.25
	var slots: Array[Vector3] = []
	for sign_x: float in [-1.0, 1.0]:
		for sign_z: float in [-1.0, 1.0]:
			slots.append(_flat(pad.get_center() + Vector2(quarter.x * sign_x, quarter.y * sign_z)))
	return slots


func _gather_slots(plan: FloorPlan) -> Array[Vector3]:
	var slots: Array[Vector3] = []
	for index in PARTY_SIZE:
		var angle: float = TAU * float(index) / float(PARTY_SIZE) + PI * 0.25
		slots.append(_forecourt(plan) + Vector3(cos(angle), 0.0, sin(angle)) * GATHER_RING_RADIUS)
	return slots


## The route a player steers from the arrival onto the floor on one side: up that side's steps.
func _approach(plan: FloorPlan, east: bool) -> Array:
	return [_flat(_patch(plan, &"P_STEP_E" if east else &"P_STEP_W").get_center())]


## Where an Envoy stands to use each station, the thing it faces there, and how it gets there.
func _stations(plan: FloorPlan) -> Dictionary:
	var standoff: float = _radius + STATION_STANDOFF
	var console: Vector3 = plan.exit_console
	var counter: Rect2 = _rect(plan, &"O_COUNTER_E")
	var rack_n: Rect2 = _rect(plan, &"O_RACK_N")
	var rack_s: Rect2 = _rect(plan, &"O_RACK_S")
	var racks: Vector2 = (rack_n.get_center() + rack_s.get_center()) * 0.5
	var crafter: Rect2 = _rect(plan, &"O_CRAFTER")
	var plinth: Rect2 = _rect(plan, &"O_CRAFT_PLINTH")
	return {
		"briefing": {"via": [], "faces": console,
			"stand": console + (plan.entry_point - console).normalized() * (standoff + STATION_STANDOFF)},
		"supply": {"via": _approach(plan, false), "faces": _flat(counter.get_center()),
			"stand": _flat(Vector2(counter.end.x + standoff, counter.get_center().y))},
		"armory": {"via": _approach(plan, true), "faces": _flat(racks),
			"stand": _flat(Vector2(rack_s.position.x - standoff, racks.y))},
		"crafting": {"via": _approach(plan, true), "faces": _flat(crafter.get_center()),
			"stand": _flat(Vector2(plinth.position.x - standoff, crafter.get_center().y))},
	}


## Inside the stall's corner, between its shelves and its counter: where a merchant will stand.
func _merchant_spot(plan: FloorPlan) -> Vector3:
	var shelf_w: Rect2 = _rect(plan, &"O_STALL_SHELF_W")
	var shelf_n: Rect2 = _rect(plan, &"O_STALL_SHELF_N")
	return _flat(Vector2((shelf_w.end.x + _rect(plan, &"O_COUNTER_E").position.x) * 0.5,
		(shelf_n.end.y + _rect(plan, &"O_COUNTER_S").position.y) * 0.5))


## Round the counter's open end, between it and the back shelf, into the stall.
func _merchant_route(plan: FloorPlan) -> Array:
	var gap_z: float = (_rect(plan, &"O_STALL_SHELF_N").end.y + _rect(plan, &"O_COUNTER_E").position.y) * 0.5
	var stand: Vector3 = _stations(plan)["supply"]["stand"]
	var spot: Vector3 = _merchant_spot(plan)
	return [stand, Vector3(stand.x, 0.0, gap_z), Vector3(spot.x, 0.0, gap_z), spot]


## The clear span between two masses that frame an opening: from one's facing edge to the other's,
## so a mass that grows into the opening narrows it. `first` lies west of (or north of) `second`.
func _gap(first: Rect2, second: Rect2) -> Array:
	if first.end.x <= second.position.x:
		var z: float = (first.get_center().y + second.get_center().y) * 0.5
		return [Vector2(first.end.x, z), Vector2(second.position.x, z)]
	var x: float = (first.get_center().x + second.get_center().x) * 0.5
	return [Vector2(x, first.end.y), Vector2(x, second.position.y)]


## Across a patch, west edge to east edge, at its middle.
func _across(rect: Rect2) -> Array:
	return [Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y)]


func _segment_clear_of(from: Vector3, to: Vector3, region: Rect2, margin: float) -> bool:
	var grown: Rect2 = region.grow(margin)
	var steps: int = int(ceil(from.distance_to(to) / 0.1)) + 1
	for step in steps + 1:
		var at: Vector3 = from.lerp(to, float(step) / float(steps))
		if WalkableBounds.contains(grown, at.x, at.z):
			return false
	return true


# --- STATIC CLEARANCES ---------------------------------------------------------------------

func test_the_deployment_pad_is_the_unchanged_party_pad() -> void:
	var plan: FloorPlan = _plan()
	assert_eq(_pad(plan), PAD_REGION, "ruled: the 4x4 pad and T_DEPLOY stay exactly as they were")
	for obstacle in plan.obstacles:
		assert_false(obstacle.rect.intersects(_pad(plan)), "obstacle %d: the pad is fully standable" % obstacle.obstacle_id)


func test_four_envoys_fit_on_the_pad_without_touching() -> void:
	var plan: FloorPlan = _plan()
	var bounds: WalkableBounds = _bounds(plan)
	var slots: Array[Vector3] = _pad_slots(plan)
	for slot in slots:
		assert_true(WalkableBounds.contains(_pad(plan), slot.x, slot.z), "every slot counts as on the pad")
		assert_true(bounds.fits(slot, _radius), "an Envoy's whole body fits at %s" % slot)
	for a in slots.size():
		for b in range(a + 1, slots.size()):
			assert_gte(slots[a].distance_to(slots[b]), 2.0 * _radius + ELBOW_ROOM, "no two bodies overlap")


func test_a_party_can_gather_in_front_of_the_gate_and_on_arrival() -> void:
	var plan: FloorPlan = _plan()
	var bounds: WalkableBounds = _bounds(plan)
	var centre: Vector3 = _forecourt(plan)
	var ring := Rect2(Vector2(centre.x, centre.z), Vector2.ZERO).grow(GATHER_RING_RADIUS + _radius)
	for obstacle in plan.obstacles:
		assert_false(obstacle.rect.intersects(ring), "obstacle %d stands clear of the forecourt" % obstacle.obstacle_id)
	assert_false(ring.intersects(_pad(plan)), "gathering is not deploying")
	for slot in _gather_slots(plan):
		assert_true(bounds.fits(slot, _radius), "a gathering slot fits at %s" % slot)
	# Arriving together: four abreast where the Envoy appears.
	var spacing: float = 2.0 * _radius + ELBOW_ROOM
	for index in PARTY_SIZE:
		var at: Vector3 = plan.entry_point + Vector3((float(index) - float(PARTY_SIZE - 1) * 0.5) * spacing, 0.0, 0.0)
		assert_true(bounds.fits(at, _radius), "arrival: Envoy %d of four fits at %s" % [index + 1, at])


## A row of four, side by side, fits through every opening a party walks through together.
func test_every_route_admits_four_abreast() -> void:
	var plan: FloorPlan = _plan()
	var bounds: WalkableBounds = _bounds(plan)
	var screens: Rect2 = _rect(plan, &"O_CONSOLE_SCREENS")
	var landing: Rect2 = _patch(plan, &"P_LANDING")
	var openings: Dictionary = {
		"gate mouth": _gap(_rect(plan, &"O_FRAME_W"), _rect(plan, &"O_FRAME_E")),
		"west approach": _across(_patch(plan, &"P_STEP_W")),
		"east approach": _across(_patch(plan, &"P_STEP_E")),
		"west of the console": [Vector2(landing.position.x, landing.get_center().y), Vector2(screens.position.x, landing.get_center().y)],
		"east of the console": [Vector2(screens.end.x, landing.get_center().y), Vector2(landing.end.x, landing.get_center().y)],
		"arrival": _across(_patch(plan, &"P_ARRIVAL")),
	}
	var spacing: float = 2.0 * _radius + ELBOW_ROOM
	for name: String in openings:
		var ends: Array = openings[name]
		var middle: Vector2 = (ends[0] + ends[1]) * 0.5
		var along: Vector2 = (ends[1] - ends[0]).normalized()
		for index in PARTY_SIZE:
			var offset: float = (float(index) - float(PARTY_SIZE - 1) * 0.5) * spacing
			var at: Vector3 = _flat(middle + along * offset)
			assert_true(bounds.fits(at, _radius), "%s: Envoy %d of a row of four fits at %s" % [name, index + 1, at])


func test_the_pad_is_set_back_and_off_every_route_between_stations() -> void:
	var plan: FloorPlan = _plan()
	var pad: Rect2 = _pad(plan)
	var mouth_z: float = _rect(plan, &"O_FRAME_W").end.y
	assert_gte(mouth_z - pad.end.y, MIN_PAD_SETBACK, "the pad sits back from the recess mouth")
	assert_true(_patch(plan, &"P_GATE").encloses(pad), "the pad is inside the gate recess")
	var entry := Vector2(plan.entry_point.x, plan.entry_point.z)
	assert_gte(entry.distance_to(pad.get_center()), MIN_PAD_DISTANCE_FROM_ENTRY)
	var points: Array[Vector3] = [plan.entry_point, _forecourt(plan), _merchant_spot(plan)]
	var stations: Dictionary = _stations(plan)
	for name: String in stations:
		points.append(stations[name]["stand"])
	for a in points.size():
		for b in range(a + 1, points.size()):
			assert_true(_segment_clear_of(points[a], points[b], pad, _radius), "walking %s -> %s never brushes the pad" % [points[a], points[b]])


func test_every_station_has_room_and_the_merchant_has_a_corner() -> void:
	var plan: FloorPlan = _plan()
	var bounds: WalkableBounds = _bounds(plan)
	var stations: Dictionary = _stations(plan)
	for name: String in stations:
		var stand: Vector3 = stations[name]["stand"]
		assert_true(bounds.fits(stand, _radius), "%s: an Envoy fits where it stands to use it, %s" % [name, stand])
		assert_false(WalkableBounds.contains(_patch(plan, &"P_GATE"), stand.x, stand.z), "%s: outside the gate recess" % name)
	assert_true(bounds.fits(_merchant_spot(plan), MERCHANT_RADIUS), "a merchant-sized body fits in the stall's corner")


## The briefing is the first thing ahead: in line with the arrival, nearer than anything else.
func test_the_mission_console_stands_directly_ahead_of_arrival() -> void:
	var plan: FloorPlan = _plan()
	var console: Vector3 = plan.exit_console
	var entry: Vector3 = plan.entry_point
	assert_almost_eq(console.x, entry.x, 0.01, "straight ahead")
	assert_lt(console.z, entry.z, "ahead, toward the gate")
	var stations: Dictionary = _stations(plan)
	for name: String in stations:
		if name != "briefing":
			assert_lt(entry.distance_to(console), entry.distance_to(stations[name]["stand"]), "the console comes before %s" % name)


# --- WALKED, IN THE REAL HUB ---------------------------------------------------------------

func _hub() -> HubSpace:
	var hub: HubSpace = load(HUB_SCENE).instantiate()
	hub.layout = READY_ROOM
	hub.deploys = true
	add_child_autofree(hub)
	hub.set_physics_process(false)
	return hub


func _position(hub: HubSpace, actor_id: int = -1) -> Vector3:
	return hub.sim.entities[hub.envoy.actor_id if actor_id < 0 else actor_id]


## Walks straight at the target, letting the sim's own slide carry the Envoy along anything in the
## way. Returns the ticks taken, or -1 if it never arrived.
func _walk(hub: HubSpace, target: Vector3) -> int:
	for tick in WALK_TICKS:
		var to: Vector3 = target - _position(hub)
		to.y = 0.0
		if to.length() <= 0.1:
			return tick
		hub._step([Command.new(hub.sim.tick_count, hub.envoy.actor_id, "move", {"direction": to.normalized()})] as Array[Command], DT)
		if hub.is_leaving():
			return -1
	return -1


func _walk_route(hub: HubSpace, route: Array) -> int:
	var total: int = 0
	for point: Vector3 in route:
		var ticks: int = _walk(hub, point)
		if ticks < 0:
			return -1
		total += ticks
	return total


func _seconds(ticks: int) -> float:
	return float(ticks) * DT


## Walks at the pad until it deploys; the ticks it took, or -1.
func _walk_onto_pad(hub: HubSpace) -> int:
	for tick in WALK_TICKS:
		if hub.is_leaving():
			return tick
		var to: Vector3 = _flat(_pad(hub.plan).get_center()) - _position(hub)
		hub._step([Command.new(hub.sim.tick_count, hub.envoy.actor_id, "move", {"direction": to.normalized()})] as Array[Command], DT)
	return -1


func test_every_station_is_a_short_walk_from_arrival_and_never_deploys() -> void:
	var hub: HubSpace = _hub()
	var plan: FloorPlan = hub.plan
	var stations: Dictionary = _stations(plan)
	for name: String in stations:
		var there: Array = stations[name]["via"] + [stations[name]["stand"]]
		var ticks: int = _walk_route(hub, there)
		assert_gt(ticks, 0, "%s: reached on foot" % name)
		assert_lte(_seconds(ticks), STATION_WALK_SECONDS, "%s: %.1f s from arrival" % [name, _seconds(ticks)])
		var back: Array = stations[name]["via"].duplicate()
		back.reverse()
		assert_gt(_walk_route(hub, back + [plan.entry_point]), 0, "%s: and back to the arrival point" % name)
	var to_merchant: Array = stations["supply"]["via"] + _merchant_route(plan)
	assert_gt(_walk_route(hub, to_merchant), 0, "the merchant's corner is reachable round the counter")
	var out: Array = to_merchant.duplicate()
	out.reverse()
	assert_gt(_walk_route(hub, out), 0, "and back out onto the staging floor")
	assert_false(hub.is_leaving(), "touring every station deployed nothing")
	assert_gt(_walk_onto_pad(hub), 0, "the pad is the one thing that deploys")


func test_the_pad_is_a_short_walk_from_arrival_round_the_console() -> void:
	var hub: HubSpace = _hub()
	watch_signals(hub)
	var up: int = _walk_route(hub, [_approach(hub.plan, false)[0]])
	var on: int = _walk_onto_pad(hub)
	assert_gt(on, 0, "deployed")
	assert_lte(_seconds(up + on), PAD_WALK_SECONDS, "%.1f s from arrival to deployment" % _seconds(up + on))
	assert_signal_emit_count(hub, "deploy_requested", 1)


## Only the briefing console is something to use. Shelves, counter, racks, bench and crafter are
## scenery: no focus ring, and a press at them is an ordinary (weaponless) press that reads nothing.
func test_only_the_briefing_console_takes_focus() -> void:
	var hub: HubSpace = _hub()
	var stations: Dictionary = _stations(hub.plan)
	for name: String in stations:
		assert_gt(_walk_route(hub, stations[name]["via"] + [stations[name]["stand"]]), -1, name)
		var aim: Vector3 = stations[name]["faces"] - _position(hub)
		var focus: String = String(hub.sim.interaction_focus(hub.envoy.actor_id, aim).get("kind", ""))
		assert_eq(focus, "inspect" if name == "briefing" else "", "%s: focus is '%s'" % [name, focus])
		var press := Command.new(hub.sim.tick_count, hub.envoy.actor_id, "attack", {"aim": aim, "phase": "pressed"})
		var kinds: Array = hub.sim.tick([press] as Array[Command], DT).map(func(e: Event) -> String: return e.kind)
		assert_eq(kinds.has("exit_console_inspected"), name == "briefing", "%s: a press reads only the briefing" % name)
		assert_false(kinds.has("floor_complete"), "%s: and never deploys" % name)
		var back: Array = stations[name]["via"].duplicate()
		back.reverse()
		_walk_route(hub, back + [hub.plan.entry_point])


## The authoritative party rule, unchanged, in the new room: four Envoys walk from the forecourt
## past the gate's frame onto the pad, and it fires only when the last one steps on.
func test_four_envoys_walk_from_the_forecourt_onto_the_pad_together() -> void:
	var hub: HubSpace = _hub()
	watch_signals(hub)
	var gather: Array[Vector3] = _gather_slots(hub.plan)
	var slots: Array[Vector3] = _pad_slots(hub.plan)
	assert_gt(_walk_route(hub, _approach(hub.plan, false) + [_forecourt(hub.plan), gather[0]]), -1, "the Envoy joins the gathering")
	var party: Array[int] = [hub.envoy.actor_id]
	for index in range(1, PARTY_SIZE):
		var actor_id: int = hub.envoy.actor_id + 100 + index
		assert_true(hub.sim.add_entity(actor_id, gather[index], ENVOY_STATS.move_speed, Vector3(0, 0, -1), _radius))
		hub.sim.register_combatant(actor_id, ENVOY_STATS.max_health, ENVOY_STATS.family, ENVOY_STATS.iframe_ticks_on_hit, _radius, &"player")
		hub.sim.mark_run_persistent(actor_id)
		party.append(actor_id)
	# The Envoy waits until the other three are on the pad, so the rule is seen to hold off.
	var arrived: Array[bool] = [false, false, false, false]
	for tick in WALK_TICKS:
		if hub.is_leaving():
			break
		var commands: Array[Command] = []
		for index in PARTY_SIZE:
			if index == 0 and not (arrived[1] and arrived[2] and arrived[3]):
				continue
			var to: Vector3 = slots[index] - _position(hub, party[index])
			to.y = 0.0
			arrived[index] = to.length() <= 0.1
			if not arrived[index]:
				commands.append(Command.new(hub.sim.tick_count, party[index], "move", {"direction": to.normalized()}))
		if arrived[1] and arrived[2] and arrived[3] and not arrived[0]:
			assert_false(hub.is_leaving(), "three of four on the pad commits nobody")
		hub._step(commands, DT)
	assert_true(arrived[1] and arrived[2] and arrived[3], "every Envoy reached its corner past the frame pylons")
	assert_true(hub.is_leaving(), "the fourth Envoy stepping on deploys the party")
	assert_signal_emit_count(hub, "deploy_requested", 1)


# --- WHAT THE PLAYER SEES ------------------------------------------------------------------

## The steps are a picture on a flat sim: the Envoy is drawn on whatever ground is under it,
## and the sim position never leaves the plane.
func test_the_envoy_stands_on_the_visible_ground_and_the_sim_stays_flat() -> void:
	var hub: HubSpace = _hub()
	var plan: FloorPlan = hub.plan
	var arrival_ground: float = hub._floor_builder.elevation_at(plan.entry_point)
	assert_almost_eq(hub.envoy.position.y, arrival_ground, 0.001, "drawn on the arrival ground")
	var floor_height: float = 0.0
	for patch in plan.patches:
		if patch.patch_id == READY_ROOM.id_in(&"patch", &"P_FLOOR"):
			floor_height = patch.elevation
	assert_gt(floor_height, arrival_ground, "the staging floor is drawn above the arrival")
	assert_gt(_walk_route(hub, _approach(plan, false) + [_forecourt(plan)]), 0)
	assert_almost_eq(hub.envoy.position.y, floor_height, 0.001, "up the steps, the Envoy is drawn on the staging floor")
	assert_eq(_position(hub).y, 0.0, "and the sim never saw a height")


func test_the_console_faces_the_arriving_envoy() -> void:
	var hub: HubSpace = _hub()
	var console: Node3D = hub._floor_builder.exit_console_node()
	var to_arrival: Vector3 = hub.plan.entry_point - console.position
	to_arrival.y = 0.0
	assert_gt((-console.basis.z).dot(to_arrival.normalized()), 0.99, "its screen turns toward the arrival")


## Blocks are drawn at their own height in a hub (a counter is counter-high, not wall-high), and
## raised ground is solid. The skirt test itself must recognise the obstacles' faces.
func test_hub_blocks_carry_no_wall_skirts_and_raised_ground_is_solid() -> void:
	var hub: HubSpace = _hub()
	assert_false(hub._floor_builder.draw_obstacle_faces)
	assert_true(hub._floor_builder.solid_raised_ground)
	var faces: int = 0
	for segment in hub.plan.solid_segments():
		if hub._floor_builder._is_obstacle_face(segment):
			faces += 1
	assert_gt(faces, 0, "obstacle faces are recognised, so leaving them out means something")


## The real follow camera, placed where it would be with the Envoy standing at `at`.
func _camera_at(hub: HubSpace, at: Vector3) -> Camera3D:
	hub.envoy.position = hub._grounded(at)
	hub._camera.snap_to_target()
	return hub._camera


func _occluder(hub: HubSpace, camera: Camera3D, point: Vector3) -> String:
	for obstacle in hub.plan.obstacles:
		var base: float = hub._floor_builder.elevation_at(_flat(obstacle.rect.get_center()))
		var box := AABB(Vector3(obstacle.rect.position.x, base, obstacle.rect.position.y),
			Vector3(obstacle.rect.size.x, obstacle.height, obstacle.rect.size.y))
		if box.intersects_segment(camera.position, point) != null:
			return "obstacle %d at %s" % [obstacle.obstacle_id, obstacle.rect]
	return ""


func _top(hub: HubSpace, key: StringName) -> Vector3:
	var obstacle: ObstaclePlan = _obstacle(hub.plan, key)
	var centre: Vector3 = _flat(obstacle.rect.get_center())
	return centre + Vector3(0.0, hub._floor_builder.elevation_at(centre) + obstacle.height, 0.0)


## Useful visibility at each destination: standing there, the Envoy is in frame and unhidden, and
## so is what it came for. From the arrival the console fills the way ahead with the gate beyond;
## from every station the departure stays in sight.
func test_each_destination_frames_the_envoy_and_what_it_came_for() -> void:
	assert_eq(get_viewport().get_visible_rect().size, Vector2(WINDOW), "looking through a 16:9 window")
	var hub: HubSpace = _hub()
	var plan: FloorPlan = hub.plan
	var pad: Vector3 = _flat(_pad(plan).get_center())
	var views: Dictionary = {
		"arrival": [plan.entry_point, [_top(hub, &"O_CONSOLE_SCREENS"), plan.exit_console, pad]],
		"forecourt": [_forecourt(plan), [pad, _top(hub, &"O_FRAME_W"), _top(hub, &"O_FRAME_E")]],
		"merchant's corner": [_merchant_spot(plan), [_top(hub, &"O_COUNTER_E")]],
	}
	var stations: Dictionary = _stations(plan)
	for name: String in stations:
		views[name] = [stations[name]["stand"], [stations[name]["faces"], pad]]
	for slot in _pad_slots(plan):
		views["pad corner %s" % slot] = [slot, [pad]]
	var chest := Vector3(0.0, CHEST_HEIGHT, 0.0)
	for name: String in views:
		var camera: Camera3D = _camera_at(hub, views[name][0])
		var envoy: Vector3 = hub.envoy.position + chest
		assert_true(camera.is_position_in_frustum(envoy), "%s: the Envoy is in frame" % name)
		assert_eq(_occluder(hub, camera, envoy), "", "%s: nothing hides the Envoy" % name)
		for target: Vector3 in views[name][1]:
			assert_true(camera.is_position_in_frustum(target), "%s: %s is in frame" % [name, target])
	assert_eq(hub._camera._floor_extent, HubSpace._floor_extent_of(plan), "the camera knows the whole room")


## The room is larger than one screen: from the forecourt the camera cannot show both side walls.
func test_the_hall_is_wider_than_the_hub_camera_shows() -> void:
	var hub: HubSpace = _hub()
	var extent: Rect2 = HubSpace._floor_extent_of(hub.plan)
	var forecourt: Vector3 = _forecourt(hub.plan)
	var camera: Camera3D = _camera_at(hub, forecourt)
	var west := Vector3(extent.position.x, 0.0, forecourt.z)
	var east := Vector3(extent.end.x, 0.0, forecourt.z)
	assert_false(camera.is_position_in_frustum(west) and camera.is_position_in_frustum(east), "the hall overflows the frame")
