extends GutTest
## THE FIRST FOUNDRY FLOOR (depth 4) -- GREYBOX, re-authored 2026-10-13 and again 2026-10-14
## (Stage 1: closer to the reference's shape). Stage 1 geometry spatially ACCEPTED by the human
## 2026-10-15, with the east loot room restored; keys are still hit-switch stand-ins (Stage 2).
##
## A normal expedition floor on a hub: arrival -> lower access -> HUB -> west loop and east room,
## each holding one KEY -> a north gate that needs both -> a write-sequence connector -> the main
## chamber -> exit. The first greybox (rows of cycling pads under every fight) was played and
## ruled out the same day; only its causeway sequence passed, and it survives here unchanged as
## the north connector.
##
## THE TWO-KEY GATE IS CONTENT, NOT A MECHANIC. Two ordinary closed connections stand in series,
## each opened by its own wing's hit switch. "Both, in either order" falls out of that with no
## AND-condition, no counter and no inventory -- and these tests are what keep it true.

const DT := 1.0 / 30.0
const L = preload("res://game/content/layouts/foundry_assembly.tres")
const FOUNDRY_DEPTH := 4
## The widest free-standing mass the shipped roster reliably routes round, measured by
## tools/measure_block_pursuit.gd: every family gets round 3 units, an Ooze pins on 4.
const WIDEST_ROUTABLE_MASS := 3.0

var plan: FloorPlan


func before_each() -> void:
	plan = DepthGenerator.generate(0, FOUNDRY_DEPTH)


func after_each() -> void:
	await get_tree().process_frame


func _id(key: StringName) -> int:
	return L.id_for(key)


func _patch(key: StringName) -> Rect2:
	return plan.patch_by_id(_id(key)).rect


func _centre(region: Rect2) -> Vector3:
	return Vector3(region.get_center().x, 0.0, region.get_center().y)


func _encounter(key: StringName) -> EncounterSite:
	for site: EncounterSite in plan.encounters:
		if site.encounter_id == _id(key):
			return site
	return null


func _families(key: StringName) -> Dictionary:
	var census: Dictionary = {}
	for spawn: Dictionary in _encounter(key).roster:
		census[spawn["enemy_key"]] = int(census.get(spawn["enemy_key"], 0)) + 1
	return census


## The tick, within its own cycle, on which this pad becomes active.
func _starts_at(pad: SpikePadPlan) -> int:
	return posmod(pad.safe_ticks - pad.phase_offset_ticks, pad.safe_ticks + pad.active_ticks)


func _sequence() -> Array:
	var pads: Array = plan.spike_pads.duplicate()
	pads.sort_custom(func(a: SpikePadPlan, b: SpikePadPlan) -> bool: return _starts_at(a) < _starts_at(b))
	return pads


# --- 1: IT IS THE FOUNDRY, AND NOTHING ELSE MOVED ---------------------------------------------

func test_depth_four_is_the_foundry_floor() -> void:
	assert_eq(plan.patches.size(), L.patches.size())
	assert_eq(String(plan.stratum_id), "foundry")
	assert_eq(plan.place_label, "", "an ordinary floor, known by its stratum")
	assert_eq(String(L.stratum_id), "foundry", "and the floor itself says which stratum it belongs to")
	assert_true(plan.authored_layout)
	assert_push_error_count(0, "the authored floor passes every structural guard")


func test_the_archive_and_the_terminal_keep_their_stratum() -> void:
	for depth: int in [1, 2, 3, 5]:
		assert_eq(String(DepthGenerator.generate(0, depth).stratum_id), "archive", "depth %d" % depth)


func test_depth_four_generation_is_deterministic() -> void:
	var again: FloorPlan = DepthGenerator.generate(0, FOUNDRY_DEPTH)
	assert_eq(JSON.stringify(plan.to_dict()), JSON.stringify(again.to_dict()))


func test_every_spawn_is_owned_fits_the_floor_and_belongs_to_the_stratum() -> void:
	var stratum: StratumConfig = ContentDB.get_resource(&"stratum", &"foundry")
	var floor_bounds: WalkableBounds = plan.make_bounds()
	assert_gt(plan.all_spawns().size(), 0, "sanity: the floor has a roster")
	for site: EncounterSite in plan.encounters:
		for spawn: Dictionary in site.roster:
			var position: Vector3 = spawn["position"]
			var radius: float = ContentDB.get_resource(&"enemy", spawn["enemy_key"]).combat_radius
			assert_true(stratum.enemy_keys.has(spawn["enemy_key"]), "'%s' is not in the Foundry's pool" % spawn["enemy_key"])
			assert_true(floor_bounds.fits(position, radius), "%s at %s does not fit the floor" % [spawn["enemy_key"], position])
			var owned: bool = false
			for region: Rect2 in site.regions:
				owned = owned or WalkableBounds.contains(region, position.x, position.z)
			assert_true(owned, "spawn at %s is outside encounter %d, which owns it" % [position, site.encounter_id])


# --- 2: COMBAT GROUND IS STABLE GROUND --------------------------------------------------------

## THE RULING THIS FLOOR EXISTS BECAUSE OF (2026-10-13): fighting on a cycling floor did not feel
## good. No fight on this floor has a hazard anywhere in its territory.
func test_no_encounter_has_a_hazard_in_its_territory() -> void:
	assert_gt(plan.spike_pads.size(), 0, "sanity: the floor does have a hazard somewhere")
	for site: EncounterSite in plan.encounters:
		for region: Rect2 in site.regions:
			for pad: SpikePadPlan in plan.spike_pads:
				assert_false(region.intersects(pad.rect), "encounter %d fights on pad %d" % [site.encounter_id, pad.pad_id])


func test_the_hazard_lives_only_in_the_north_connector() -> void:
	for pad: SpikePadPlan in plan.spike_pads:
		assert_true(_patch(&"P_CONNECTOR").encloses(pad.rect), "pad %d is outside the connector" % pad.pad_id)
		assert_eq(pad.eligible_allegiances, [&"player"] as Array[StringName],
			"pad %d: enemies stay immune to environmental hazards" % pad.pad_id)


func test_the_arrival_and_the_hub_hold_no_fight() -> void:
	for site: EncounterSite in plan.encounters:
		for region: Rect2 in site.regions:
			for patch_key: StringName in [&"P_ARRIVAL", &"P_HUB", &"P_VESTIBULE", &"P_CONNECTOR", &"P_EXIT"]:
				assert_false(region.intersects(_patch(patch_key)), "%s is inside encounter %d" % [patch_key, site.encounter_id])


## MEASURED, NOT ASSUMED. A mass that stands free in a room must be one the roster can get
## round; a mass built into a room's corner has no far side to get round to.
func test_no_free_standing_mass_is_wider_than_the_roster_can_route_round() -> void:
	for obstacle: ObstaclePlan in plan.obstacles:
		var in_a_corner: bool = false
		for patch: WalkablePatch in plan.patches:
			if not patch.rect.encloses(obstacle.rect):
				continue
			var on_x: bool = is_equal_approx(obstacle.rect.position.x, patch.rect.position.x) or is_equal_approx(obstacle.rect.end.x, patch.rect.end.x)
			var on_z: bool = is_equal_approx(obstacle.rect.position.y, patch.rect.position.y) or is_equal_approx(obstacle.rect.end.y, patch.rect.end.y)
			in_a_corner = on_x and on_z
		if in_a_corner:
			continue
		assert_lte(maxf(obstacle.rect.size.x, obstacle.rect.size.y), WIDEST_ROUTABLE_MASS,
			"obstacle %d stands free and is wider than an Ooze can route round" % obstacle.obstacle_id)


## HEIGHT IS A PICTURE (E-1, 2026-10-14). The landing is drawn raised and stairs step down into
## the lower access; the sim never reads elevation, so movement, reach and combat stay planar.
func test_the_landing_is_raised_and_steps_down_into_the_access() -> void:
	assert_gt(plan.patch_by_id(_id(&"P_ARRIVAL")).elevation, 0.0)
	assert_eq(plan.patch_by_id(_id(&"P_U_RIM")).elevation, plan.patch_by_id(_id(&"P_ARRIVAL")).elevation)
	# Walked north (toward -z): each step is lower than the one before, by one modest riser.
	var steps: Array = [&"P_U_RIM", &"P_STAIR_1", &"P_STAIR_2", &"P_STAIR_3", &"P_ACCESS_ROOM"]
	for i in range(1, steps.size()):
		var above: WalkablePatch = plan.patch_by_id(_id(steps[i - 1]))
		var below: WalkablePatch = plan.patch_by_id(_id(steps[i]))
		assert_true(above.rect.grow(0.001).intersects(below.rect), "%s and %s do not meet" % [steps[i - 1], steps[i]])
		assert_lt(below.rect.position.y, above.rect.position.y, "%s is not further north" % steps[i])
		assert_almost_eq(above.elevation - below.elevation, 0.375, 0.001, "riser between %s and %s" % [steps[i - 1], steps[i]])
	assert_eq(plan.patch_by_id(_id(&"P_ACCESS_ROOM")).elevation, 0.0, "the stairs land on ground level")


## Everything FloorBuilder draws on the floor stands on ground level. Not taste: it draws ordinary
## breakables and obstacle wall faces at y = 0 whatever the ground (found 2026-10-14, reported,
## not fixed), so a prop on raised ground would be drawn sunk into it.
func test_nothing_drawn_on_the_floor_stands_on_raised_ground() -> void:
	var points: Array = [plan.end_marker]
	for breakable: BreakablePlan in plan.breakables:
		points.append(breakable.position)
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		points.append(hit_switch.position)
	for spawn: Dictionary in plan.all_spawns():
		points.append(spawn["position"])
	for rect: Rect2 in plan.obstacle_rects():
		points.append(_centre(rect))
	for pad: SpikePadPlan in plan.spike_pads:
		points.append(_centre(pad.rect))
	for trigger: FloorTrigger in plan.triggers:
		if trigger.renders_as_plate:
			points.append(_centre(trigger.region))
	for point: Vector3 in points:
		for patch: WalkablePatch in plan.patches:
			if WalkableBounds.contains(patch.rect, point.x, point.z):
				assert_eq(patch.elevation, 0.0, "%s stands on raised patch %d" % [point, patch.patch_id])


## The wings are not two copies of one room: different families, different shapes.
func test_the_two_wings_ask_different_things() -> void:
	assert_ne(_families(&"E_WEST"), _families(&"E_EAST"), "the wings field the same roster")
	assert_true(_families(&"E_WEST").has(&"ooze") and not _families(&"E_WEST").has(&"watcher"), "west is the close-quarters fight")
	assert_true(_families(&"E_EAST").has(&"watcher") and not _families(&"E_EAST").has(&"ooze"), "east is the ranged one")
	# West is fought through a run of narrow and broad spaces; east in one open room, whatever
	# rects its silhouette is drawn with -- every one of them overlaps or touches the room.
	assert_gt(_encounter(&"E_WEST").regions.size(), 1, "west is fought through several spaces")
	var room: Rect2 = _patch(&"P_EAST_ROOM_CROSS")
	for region: Rect2 in _encounter(&"E_EAST").regions:
		assert_true(region.grow(0.001).intersects(room), "east region %s is a separate space" % region)


## The loot room (restored by human ruling, 2026-10-15) is a side room and nothing more: one open
## doorway off the east room, nothing in it that progression needs, and something in it to find.
## Its breakables are interim content until rewards exist.
func test_the_east_loot_room_is_optional() -> void:
	var pocket: int = _id(&"P_EAST_POCKET")
	var doors: Array = []
	for connection: TraversalConnection in plan.connections:
		if connection.patch_ids.x == pocket or connection.patch_ids.y == pocket:
			doors.append(connection)
	assert_eq(doors.size(), 1, "the loot room is a dead end with one doorway")
	assert_eq(doors[0].connection_id, _id(&"C_EAST_POCKET"))
	assert_true(doors[0].starts_open, "it can never lock anyone in or out")
	var room: Rect2 = _patch(&"P_EAST_POCKET")
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		assert_false(room.has_point(Vector2(hit_switch.position.x, hit_switch.position.z)), "a key is in the loot room")
	for trigger: FloorTrigger in plan.triggers:
		assert_false(trigger.region.intersects(room), "trigger %d fires in the loot room" % trigger.trigger_id)
	for site: EncounterSite in plan.encounters:
		for spawn: Dictionary in site.roster:
			assert_false(room.has_point(Vector2(spawn["position"].x, spawn["position"].z)), "a spawn stands in the loot room")
	var finds: int = 0
	for breakable: BreakablePlan in plan.breakables:
		finds += int(room.has_point(Vector2(breakable.position.x, breakable.position.z)))
	assert_eq(finds, 3, "the loot room holds the first greybox's three breakables")


# --- 3: THE WRITE SEQUENCE, PRESERVED ---------------------------------------------------------

## The causeway that passed human play on 2026-10-13, pinned value for value so that moving it
## cannot quietly change it.
func test_the_sequence_is_the_one_that_passed_play() -> void:
	var pads: Array = _sequence()
	assert_eq(pads.size(), 3)
	for i in pads.size():
		var pad: SpikePadPlan = pads[i]
		assert_eq(pad.rect.size, Vector2(6.0, 8.0), "band %d" % i)
		assert_eq([pad.safe_ticks, pad.active_ticks, pad.damage], [210, 30, 10.0], "band %d" % i)
		assert_eq(_starts_at(pad), 40 * i, "band %d fires 40 ticks after the one before it" % i)
		if i > 0:
			assert_almost_eq(pad.rect.position.x - pads[i - 1].rect.position.x, 6.0, 0.001,
				"band %d is the next one along, in the direction of travel" % i)
			assert_eq(pad.rect.position.y, pads[0].rect.position.y)


func test_the_bands_span_the_connector_and_leave_an_apron_at_each_end() -> void:
	var hall: Rect2 = _patch(&"P_CONNECTOR")
	var bed: Rect2 = plan.spike_pads[0].rect
	for pad: SpikePadPlan in plan.spike_pads:
		bed = bed.merge(pad.rect)
		assert_eq(pad.rect.size.y, hall.size.y, "pad %d leaves a strip to walk round it" % pad.pad_id)
	assert_gte(bed.position.x - hall.position.x, 4.0, "somewhere to stand and watch a cycle before committing")
	assert_gte(hall.end.x - bed.end.x, 4.0, "and somewhere to arrive")
	for connection: TraversalConnection in plan.connections:
		for pad: SpikePadPlan in plan.spike_pads:
			assert_false(pad.rect.intersects(connection.aperture), "doorway %d opens onto pad %d" % [connection.connection_id, pad.pad_id])


## ONE BAND AT A TIME, measured in a real sim over a whole cycle rather than read off the offsets.
func test_only_one_band_writes_at_a_time_and_every_band_writes() -> void:
	var sim := SimWorld.new()
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	for pad: SpikePadPlan in plan.spike_pads:
		sim.register_spike_pad(pad.pad_id, pad.rect, pad.safe_ticks, pad.active_ticks, pad.phase_offset_ticks, pad.damage, pad.damage_type)
	var ever_active: Dictionary = {}
	for tick in plan.spike_pads[0].safe_ticks + plan.spike_pads[0].active_ticks:
		var writing: int = 0
		for pad: SpikePadPlan in plan.spike_pads:
			if sim.spike_pad_ticks_until_active(pad.pad_id) == 0:
				writing += 1
				ever_active[pad.pad_id] = true
		assert_lte(writing, 1, "%d bands writing together at tick %d" % [writing, tick])
		sim.tick([] as Array[Command], DT)
	assert_eq(ever_active.size(), plan.spike_pads.size())


## THE FRONT OUTRUNS A WALKING ENVOY, so following the write is always safe.
func test_the_write_front_outruns_a_walking_envoy() -> void:
	var envoy: Resource = ContentDB.get_resource(&"envoy", &"default")
	var pads: Array = _sequence()
	var step_ticks: int = _starts_at(pads[1]) - _starts_at(pads[0])
	assert_gt(pads[0].rect.size.x / (envoy.move_speed * DT), float(step_ticks))
	assert_gte(step_ticks, pads[0].active_ticks, "a band finishes writing before the next begins")


# --- 4: THE TWO-KEY GATE, AS DATA -------------------------------------------------------------

func _effects_of_switch(key: StringName) -> Array:
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		if hit_switch.switch_id == _id(key):
			return hit_switch.effects
	return []


func _starts_open(key: StringName) -> bool:
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == _id(key):
			return connection.starts_open
	return true


func test_the_north_route_passes_two_locks_in_series() -> void:
	assert_false(_starts_open(&"C_LOCK_W"))
	assert_false(_starts_open(&"C_LOCK_E"))
	# In series: the vestibule is reached only through one lock and left only through the other.
	var touching_vestibule: Array = []
	for connection: TraversalConnection in plan.connections:
		if connection.patch_ids.x == _id(&"P_VESTIBULE") or connection.patch_ids.y == _id(&"P_VESTIBULE"):
			touching_vestibule.append(connection.connection_id)
	touching_vestibule.sort()
	var locks: Array = [_id(&"C_LOCK_W"), _id(&"C_LOCK_E")]
	locks.sort()
	assert_eq(touching_vestibule, locks, "the vestibule has a way in or out that is not a lock")
	# And everything north of the gate hangs off the junction, which only the second lock reaches.
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == _id(&"C_LOCK_E"):
			continue
		for north: StringName in [&"P_JUNCTION", &"P_CONNECTOR", &"P_CHAMBER", &"P_EXIT_NECK", &"P_EXIT_RUN", &"P_EXIT"]:
			if connection.patch_ids.x == _id(north) or connection.patch_ids.y == _id(north):
				for south: StringName in [&"P_HUB", &"P_WEST_TOP", &"P_EAST_ROOM", &"P_EAST_BAY", &"P_EAST_POCKET", &"P_ACCESS_ROOM"]:
					assert_false(connection.patch_ids.x == _id(south) or connection.patch_ids.y == _id(south),
						"connection %d joins %s to %s round the gate" % [connection.connection_id, south, north])


## Each key opens its OWN lock and never the other: that is the whole of "both are required".
func test_each_key_opens_its_own_lock_and_only_that_lock() -> void:
	var west: Array = _effects_of_switch(&"S_WEST_KEY")
	var east: Array = _effects_of_switch(&"S_EAST_KEY")
	var west_targets: Array = []
	for effect: Dictionary in west:
		assert_eq(effect["kind"], FloorLayers.EFFECT_OPEN_CONNECTION)
		west_targets.append(int(effect["target_id"]))
	west_targets.sort()
	var expected: Array = [_id(&"C_LOCK_W"), _id(&"C_WEST_RETURN")]
	expected.sort()
	assert_eq(west_targets, expected, "the west key opens its lock and the way back to the hub")
	assert_eq(east.size(), 1)
	assert_eq(int(east[0]["target_id"]), _id(&"C_LOCK_E"))
	# Nothing else on the floor may open either lock.
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			assert_false(int(effect.get("target_id", -1)) in [_id(&"C_LOCK_W"), _id(&"C_LOCK_E")]
				and effect["kind"] in [FloorLayers.EFFECT_OPEN_CONNECTION, FloorLayers.EFFECT_TOGGLE_CONNECTION],
				"trigger %d opens a lock without its key" % trigger.trigger_id)


## The locks stand on the side of the hub their wing is on, so the gate reads as two halves.
func test_each_lock_stands_on_its_own_wings_side() -> void:
	var hub_x: float = _patch(&"P_HUB").get_center().x
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == _id(&"C_LOCK_W"):
			assert_lt(connection.aperture.end.x, hub_x, "the west lock is on the west half")
		if connection.connection_id == _id(&"C_LOCK_E"):
			assert_gt(connection.aperture.position.x, hub_x, "the east lock is on the east half")


## The east key is in the open, so it must not be strikeable from the doorway: every line from
## the room's entrance to the key runs through the mass authored in front of it.
func test_the_east_key_cannot_be_shot_from_the_doorway() -> void:
	var key_at := Vector2.ZERO
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		if hit_switch.switch_id == _id(&"S_EAST_KEY"):
			key_at = Vector2(hit_switch.position.x, hit_switch.position.z)
	var door := Rect2()
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == _id(&"C_EAST_HALL_ROOM"):
			door = connection.aperture
	var covers: Array[Rect2] = plan.obstacle_rects()
	for step in 11:
		var from := Vector2(door.end.x, lerpf(door.position.y, door.end.y, float(step) / 10.0))
		var blocked: bool = false
		for sample in 200:
			var point: Vector2 = from.lerp(key_at, float(sample) / 199.0)
			for cover: Rect2 in covers:
				blocked = blocked or cover.has_point(point)
		assert_true(blocked, "the key is in plain sight from %s" % from)


# --- 5: THE VISIT, THROUGH THE REAL ARENA -----------------------------------------------------

## Off the raised landing, round the U, down the stairs (waking the access pair at their foot).
const TO_THE_ACCESS_ROOM: Array[Vector3] = [Vector3(-46, 0, 7.5), Vector3(-34, 0, 7.5), Vector3(-34, 0, -4), Vector3(-34, 0, -9), Vector3(-24, 0, -12)]
const TO_THE_HUB: Array[Vector3] = [Vector3(-17.5, 0, -21), Vector3(-12.5, 0, -27), Vector3(-12.5, 0, -34)]
## Out along the bottom band (waking its fight at the neck), up the west leg to the apex.
const WEST_OUT: Array[Vector3] = [Vector3(-16, 0, -38), Vector3(-27, 0, -38), Vector3(-47, 0, -39), Vector3(-47, 0, -44), Vector3(-47, 0, -52), Vector3(-47, 0, -62), Vector3(-45, 0, -69)]
## Home a different way: east along the top band and through the door the key opened.
const WEST_HOME: Array[Vector3] = [Vector3(-40, 0, -64), Vector3(-20, 0, -63), Vector3(-15, 0, -57), Vector3(-10, 0, -52)]
const EAST_OUT: Array[Vector3] = [Vector3(8, 0, -40), Vector3(21, 0, -38), Vector3(31, 0, -42), Vector3(41, 0, -42), Vector3(47, 0, -50)]
const EAST_HOME: Array[Vector3] = [Vector3(41, 0, -42), Vector3(31, 0, -42), Vector3(21, 0, -38), Vector3(8, 0, -40)]
const THROUGH_THE_GATE: Array[Vector3] = [Vector3(-4, 0, -50), Vector3(-4, 0, -62), Vector3(4, 0, -62), Vector3(4, 0, -74)]
const TO_THE_PLATE: Array[Vector3] = [Vector3(11, 0, -74), Vector3(42, 0, -74), Vector3(42, 0, -82)]
const TO_THE_EXIT: Array[Vector3] = [Vector3(48, 0, -100), Vector3(48, 0, -118), Vector3(42, 0, -121), Vector3(42, 0, -131), Vector3(42, 0, -140), Vector3(64, 0, -140)]


func _boot() -> Node3D:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	# QA arrangement only: the shipped run reaches this floor through the Terminal.
	arena.itinerary = [FOUNDRY_DEPTH] as Array[int]
	add_child_autofree(arena)
	# Survivability keeps a TRAVERSAL test measuring traversal. Never a balance claim.
	arena.sim.debug_override_health(arena.envoy.actor_id, 100000.0)
	return arena


func _walk_to(arena: Node3D, target: Vector3, reach: float = 1.0, max_ticks: int = 1500) -> bool:
	for i in max_ticks:
		var offset: Vector3 = target - arena.sim.entities[arena.envoy.actor_id]
		offset.y = 0.0
		if offset.length() < reach:
			return true
		arena._step([Command.new(arena.sim.tick_count, arena.envoy.actor_id, "move", {"direction": offset.normalized()})] as Array[Command], DT)
	return false


func _walk(arena: Node3D, route: Array[Vector3], label: String) -> void:
	for waypoint: Vector3 in route:
		assert_true(_walk_to(arena, waypoint), "%s: to %s" % [label, waypoint])


func _idle(arena: Node3D, ticks: int) -> void:
	for i in ticks:
		arena._step([] as Array[Command], DT)


func _kill(arena: Node3D, encounter_key: StringName) -> void:
	for actor_id: int in arena.sim._encounter_roster[_id(encounter_key)]:
		arena.sim.debug_override_health(actor_id, 0.0)
	_idle(arena, 1)


func _open(arena: Node3D, connection_key: StringName) -> bool:
	return bool(arena.sim._connection_open[_id(connection_key)])


func _state(arena: Node3D, encounter_key: StringName) -> String:
	return String(arena.sim._encounter_state.get(_id(encounter_key), ""))


## Strikes a key the ordinary way a hit does, through the driver, so the gate meshes hear it.
func _strike(arena: Node3D, switch_key: StringName) -> void:
	arena._report_events(arena.sim.debug_activate_hit_switch(_id(switch_key)))
	_idle(arena, 1)


## Through the lower access, FIGHTING its pack the way a player does. A roster that is walked
## past instead follows into the hub, gives up, and then cannot find its way home through a
## doorway that is not on its straight line -- measured 2026-10-13 at 12-17 ms a tick for two
## Fangs rubbing the hub wall. That is a pursuit limitation of the sim, reported and not fixed
## here; a traversal test must not be a benchmark of it.
func _reach_the_hub(arena: Node3D) -> void:
	_walk(arena, TO_THE_ACCESS_ROOM, "access")
	assert_eq(_state(arena, &"E_ACCESS"), "active", "the access room's pair wakes when it is entered")
	_kill(arena, &"E_ACCESS")
	_walk(arena, TO_THE_HUB, "access")


func _take_the_west_key(arena: Node3D) -> void:
	_walk(arena, WEST_OUT, "west")
	assert_eq(_state(arena, &"E_WEST"), "active", "the loop's fight woke on the way in")
	assert_true(bool(arena.sim._hit_switches[_id(&"S_WEST_KEY")]["hidden"]), "the west key is not there until the fight is won")
	_strike(arena, &"S_WEST_KEY")
	assert_false(_open(arena, &"C_LOCK_W"), "and a hidden key cannot be struck")
	_kill(arena, &"E_WEST")
	assert_false(bool(arena.sim._hit_switches[_id(&"S_WEST_KEY")]["hidden"]), "clearing the loop reveals it")
	assert_false(_open(arena, &"C_WEST_RETURN"), "the way back stays shut until the key is struck")
	_strike(arena, &"S_WEST_KEY")
	assert_true(_open(arena, &"C_LOCK_W"), "the west key opens the west lock")
	assert_true(_open(arena, &"C_WEST_RETURN"), "and the short way back to the hub")
	_walk(arena, WEST_HOME, "west return")


func _take_the_east_key(arena: Node3D) -> void:
	_walk(arena, EAST_OUT, "east")
	assert_eq(_state(arena, &"E_EAST"), "active", "the room's fight woke on the way in")
	_kill(arena, &"E_EAST")
	_strike(arena, &"S_EAST_KEY")
	assert_true(_open(arena, &"C_LOCK_E"), "the east key opens the east lock")
	_walk(arena, EAST_HOME, "east return")


## Off the east room and back, through the real arena: the doorway is walkable and the side trip
## adds nothing to the route to the key.
func test_the_east_loot_room_is_reachable_from_the_east_room() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_walk(arena, EAST_OUT.slice(0, 4), "east")
	_kill(arena, &"E_EAST")
	_walk(arena, [Vector3(58, 0, -35), Vector3(68, 0, -35)] as Array[Vector3], "into the loot room")
	_walk(arena, [Vector3(58, 0, -35), Vector3(47, 0, -50)] as Array[Vector3], "back to the key")


func test_the_hud_names_the_foundry() -> void:
	var arena: Node3D = _boot()
	assert_true(arena._seed_label.text.contains("Foundry"), "got '%s'" % arena._seed_label.text)
	assert_true(arena._seed_label.text.contains("depth 4"), "got '%s'" % arena._seed_label.text)
	assert_eq(arena._enemies.size(), plan.all_spawns().size())


func test_waiting_on_arrival_never_costs_health() -> void:
	var arena: Node3D = _boot()
	var before: float = arena.sim.health_of(arena.envoy.actor_id)
	var started: int = arena.sim.tick_count
	_idle(arena, 600)
	assert_eq(arena.sim.tick_count, started + 600, "sanity: the world really ran")
	assert_eq(arena.sim.health_of(arena.envoy.actor_id), before)


func test_the_west_key_alone_does_not_open_the_north_route() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_take_the_west_key(arena)
	assert_true(_open(arena, &"C_LOCK_W"))
	assert_false(_open(arena, &"C_LOCK_E"), "the east lock is the east key's")
	assert_true(_walk_to(arena, Vector3(-4, 0, -62)), "the vestibule is now reachable")
	assert_false(_walk_to(arena, Vector3(4, 0, -74), 1.0, 400), "and the junction beyond it is not")


func test_the_east_key_alone_does_not_open_the_north_route() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_take_the_east_key(arena)
	assert_true(_open(arena, &"C_LOCK_E"))
	assert_false(_open(arena, &"C_LOCK_W"), "the west lock is the west key's")
	assert_false(_walk_to(arena, Vector3(-4, 0, -62), 1.0, 400), "the hub's own lock still stands")
	assert_false(_open(arena, &"C_WEST_RETURN"), "and the east key opened nothing in the west")


## BOTH ORDERS, each walked end to end and each ending the expedition.
func test_west_then_east_completes_the_floor() -> void:
	_play_through(true)


func test_east_then_west_completes_the_floor() -> void:
	_play_through(false)


func _play_through(west_first: bool) -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = arena.envoy.actor_id
	_reach_the_hub(arena)
	assert_ne(_state(arena, &"E_WEST"), "active", "reaching the hub woke neither wing")
	assert_ne(_state(arena, &"E_EAST"), "active")
	if west_first:
		_take_the_west_key(arena)
		_take_the_east_key(arena)
	else:
		_take_the_east_key(arena)
		_take_the_west_key(arena)
	assert_true(_open(arena, &"C_LOCK_W") and _open(arena, &"C_LOCK_E"), "both keys, in either order, open the gate")

	_walk(arena, THROUGH_THE_GATE, "gate")
	_walk(arena, TO_THE_PLATE, "connector")
	assert_true(_open(arena, &"C_CONNECTOR_CHAMBER"), "entering the chamber does not commit you")
	assert_true(_walk_to(arena, _centre(L.region_for(&"T_PARTY")), 0.3), "onto the party plate")
	_idle(arena, 1)
	assert_eq(_state(arena, &"E_WAVE_1"), "active", "the party commits and the first wave wakes")
	assert_false(_open(arena, &"C_CONNECTOR_CHAMBER"), "and the way back closes")
	for wave: StringName in [&"E_WAVE_1", &"E_WAVE_2", &"E_WAVE_3"]:
		assert_eq(_state(arena, wave), "active", "%s is the one running now" % wave)
		assert_false(_open(arena, &"C_CHAMBER_TOP"), "the way on stays shut until the last wave is cleared")
		_kill(arena, wave)
	assert_true(_open(arena, &"C_CHAMBER_TOP"), "the final wave opens the way on")

	_walk(arena, TO_THE_EXIT, "exit")
	assert_false(arena.expedition.is_complete, "sanity: the exit run is not the exit")
	var way_out: Vector3 = _centre(L.region_for(&"T_EXIT"))
	for i in 1500:
		if arena.expedition.is_complete:
			break
		arena._step([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": (way_out - arena.sim.entities[envoy_id]).normalized()})] as Array[Command], DT)
	assert_true(arena.expedition.is_complete, "the Foundry is the last floor: its exit ends the expedition")
	assert_true(arena._completion_overlay.visible)


## A lane does what it says: standing in a band when it writes costs health.
func test_standing_in_a_band_when_it_writes_costs_health() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = arena.envoy.actor_id
	# Placed, not walked: this is about the pad, and the gate has its own tests.
	arena.sim.entities[envoy_id] = _centre(plan.spike_pads[0].rect)
	var before: float = arena.sim.health_of(envoy_id)
	_idle(arena, plan.spike_pads[0].safe_ticks + plan.spike_pads[0].active_ticks)
	assert_lt(arena.sim.health_of(envoy_id), before)
