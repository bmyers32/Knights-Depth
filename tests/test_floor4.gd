extends GutTest
## THE FIRST FOUNDRY FLOOR (depth 4) -- GREYBOX, re-authored 2026-10-13 and again 2026-10-14
## (Stage 1: closer to the reference's shape). Stage 1 geometry spatially ACCEPTED by the human
## 2026-10-15, with the east loot room restored. Stage 2 (2026-10-16): the keys are PHYSICAL --
## lifted, carried and delivered with the primary attack press. Stage 2 iteration (same day, after
## the human mechanic playtest): the west loop lost its shortcut home, its key waits visibly at
## the far end, and lifting it wakes a return ambush -- the key is carried back the way you came.
##
## A normal expedition floor on a hub: arrival -> lower access -> HUB -> west loop and east room,
## each holding one KEY -> a north gate that needs both -> a write-sequence connector -> the main
## chamber -> exit. The first greybox (rows of cycling pads under every fight) was played and
## ruled out the same day; only its causeway sequence passed, and it survives here unchanged as
## the north connector.
##
## THE TWO-KEY GATE IS CONTENT, NOT A MECHANIC. Two ordinary closed connections stand in series,
## each with ONE receiver on its approach side: Gate 1's in the hub, Gate 2's in the vestibule
## between them. Either key fits either receiver, and Gate 2's can only be stood in once Gate 1 is
## open -- so the first key delivered always opens Gate 1 and the second opens Gate 2, in either
## wing order, with no AND-condition, no counter and no inventory. These tests keep it true.

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


## The pads in the direction of travel (west to east).
func _by_position() -> Array:
	var pads: Array = plan.spike_pads.duplicate()
	pads.sort_custom(func(a: SpikePadPlan, b: SpikePadPlan) -> bool: return a.rect.position.x < b.rect.position.x)
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
	for carriable: CarriablePlan in plan.carriables:
		points.append(carriable.position)
	for spawn: Dictionary in plan.all_spawns():
		points.append(spawn["position"])
	for rect: Rect2 in plan.obstacle_rects():
		points.append(_centre(rect))
	for pad: SpikePadPlan in plan.spike_pads:
		points.append(_centre(pad.rect))
	for trigger: FloorTrigger in plan.triggers:
		if trigger.renders_as_plate or trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
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
	for carriable: CarriablePlan in plan.carriables:
		assert_false(room.has_point(Vector2(carriable.position.x, carriable.position.z)), "a key is in the loot room")
	for trigger: FloorTrigger in plan.triggers:
		assert_false(trigger.region.intersects(room), "trigger %d fires in the loot room" % trigger.trigger_id)
	for site: EncounterSite in plan.encounters:
		for spawn: Dictionary in site.roster:
			assert_false(room.has_point(Vector2(spawn["position"].x, spawn["position"].z)), "a spawn stands in the loot room")
	var finds: int = 0
	for breakable: BreakablePlan in plan.breakables:
		finds += int(room.has_point(Vector2(breakable.position.x, breakable.position.z)))
	assert_eq(finds, 3, "the loot room holds the first greybox's three breakables")


# --- 3: THE STEPPING-STONE CORRIDOR ---------------------------------------------------------

## THE STEPPING-STONE CORRIDOR (human design, 2026-10-17; replaced the 2026-10-13 three-band
## travelling write). Four contiguous 5-wide pads in two alternating groups. Pinned value for
## value so that moving it cannot quietly change it -- these are playtest values, not law.
func test_the_corridor_is_the_approved_stepping_stone_layout() -> void:
	var pads: Array = _by_position()
	assert_eq(pads.size(), 4)
	for i in pads.size():
		var pad: SpikePadPlan = pads[i]
		assert_eq(pad.rect.size, Vector2(5.0, 8.0), "pad %d" % i)
		assert_eq([pad.safe_ticks, pad.active_ticks, pad.damage], [130, 30, 10.0], "pad %d" % i)
		assert_eq(_starts_at(pad), 0 if i % 2 == 0 else 80, "pad %d is in the wrong group" % i)
		if i > 0:
			assert_almost_eq(pad.rect.position.x, pads[i - 1].rect.end.x, 0.001, "pad %d is contiguous with the one before" % i)
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


## THE RULE THE CORRIDOR IS BUILT ON, read from the AUTHORITATIVE countdown in a real sim over
## three cycles, never from the table: the pad ahead retracts on the very tick the pad underfoot
## starts warning (the warning IS the "go"), groups alternate, each pad writes for exactly its
## active ticks per cycle, and two neighbours never write at once.
func test_the_pad_ahead_retracts_as_the_pad_underfoot_starts_warning() -> void:
	var lead: int = FloorBuilder._HAZARD_WARN_LEAD_TICKS
	var sim := SimWorld.new()
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	var ids: Array = []
	for pad: SpikePadPlan in _by_position():
		sim.register_spike_pad(pad.pad_id, pad.rect, pad.safe_ticks, pad.active_ticks, pad.phase_offset_ticks, pad.damage, pad.damage_type)
		ids.append(pad.pad_id)
	var cycle: int = plan.spike_pads[0].safe_ticks + plan.spike_pads[0].active_ticks
	var previous: Array = []
	var active_ticks: Dictionary = {}
	var go_signals: int = 0
	for tick in cycle * 3:
		var now: Array = []
		for pad_id: int in ids:
			now.append(sim.spike_pad_ticks_until_active(pad_id))
		assert_eq(now[0], now[2], "tick %d: pads 1 and 3 are one group" % tick)
		assert_eq(now[1], now[3], "tick %d: pads 2 and 4 are one group" % tick)
		for i in 4:
			if now[i] == 0:
				active_ticks[i] = int(active_ticks.get(i, 0)) + 1
				if i < 3:
					assert_ne(now[i + 1], 0, "tick %d: neighbours %d and %d write together" % [tick, i, i + 1])
		if not previous.is_empty():
			for i in 3:
				var retracted: bool = previous[i + 1] == 0 and now[i + 1] > 0
				var warns: bool = now[i] == lead and previous[i] == lead + 1
				assert_eq(retracted, warns, "tick %d: pad %d retracting and pad %d starting to warn must coincide" % [tick, i + 1, i])
				go_signals += int(warns)
		previous = now
		sim.tick([] as Array[Command], DT)
	assert_eq(go_signals, 3 * 3, "every pad but the last gave a go signal once per cycle")
	for i in 4:
		assert_eq(active_ticks[i], 3 * plan.spike_pads[0].active_ticks, "pad %d writes exactly its active ticks per cycle" % i)


## SHARED EDGES BELONG TO BOTH PADS (WalkableBounds.contains is inclusive): an Envoy standing
## exactly on the line is hurt by whichever side writes -- the step must clear the line.
func test_a_shared_edge_is_on_both_pads() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = arena.envoy.actor_id
	var pads: Array = _by_position()
	var line: Vector3 = Vector3(pads[1].rect.position.x, 0.0, pads[1].rect.get_center().y)
	assert_true(WalkableBounds.contains(pads[0].rect, line.x, line.z) and WalkableBounds.contains(pads[1].rect, line.x, line.z))
	_await_query(arena, pads[1].pad_id, 1)
	assert_gt(arena.sim.spike_pad_ticks_until_active(pads[0].pad_id), 0, "pad 1 is safe while pad 2 writes")
	arena.sim.entities[envoy_id] = line
	var before: float = arena.sim.health_of(envoy_id)
	_idle(arena, 2)
	assert_lt(arena.sim.health_of(envoy_id), before, "the line counts as the writing pad")


## DAMAGE RESOLVES BEFORE MOVEMENT within a tick, and the display agrees: once the pad LOOKS
## active (query 0 after a step), a step off it in the next tick is too late; a step taken while
## it still showed one tick of warning is in time.
func test_damage_resolves_before_movement_and_the_last_warning_tick_is_in_time() -> void:
	var pad: SpikePadPlan = _by_position()[0]
	var edge: Vector3 = Vector3(pad.rect.end.x - 0.05, 0.0, pad.rect.get_center().y)
	for late: bool in [true, false]:
		var arena: Node3D = _boot()
		var envoy_id: int = arena.envoy.actor_id
		_await_query(arena, pad.pad_id, 0 if late else 1)
		arena.sim.entities[envoy_id] = edge
		var before: float = arena.sim.health_of(envoy_id)
		arena._step([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": Vector3(1, 0, 0)})] as Array[Command], DT)
		assert_gt(arena.sim.entities[envoy_id].x, pad.rect.end.x, "the step did leave the pad")
		_idle(arena, 1)
		if late:
			assert_lt(arena.sim.health_of(envoy_id), before, "stepped off as it showed active: the hit already landed")
		else:
			assert_eq(arena.sim.health_of(envoy_id), before, "stepped off on the last warning tick: safe")


# --- the crossing, walked: a player who goes on the signal after a human reaction delay ------

const _REACTION_TICKS: int = 20  # ~0.67 s to notice and decide: a working assumption, not data
const _SIGNAL_BUDGET_TICKS: int = 400


## Steps until the pad's authoritative countdown reads `value` (at most two cycles).
func _await_query(arena: Node3D, pad_id: int, value: int) -> void:
	for i in _SIGNAL_BUDGET_TICKS:
		if arena.sim.spike_pad_ticks_until_active(pad_id) == value:
			return
		arena._step([] as Array[Command], DT)
	fail_test("pad %d never reached countdown %d" % [pad_id, value])


## Waits for a signal (a callable over the sim), then the reaction delay, then walks along the
## corridor to `x`. Returns false if the signal never came. Health is checked at every stage.
func _on_signal_walk_to(arena: Node3D, signal_seen: Callable, x: float, health: float, label: String) -> bool:
	var envoy_id: int = arena.envoy.actor_id
	var waited: int = 0
	while not signal_seen.call():
		arena._step([] as Array[Command], DT)
		waited += 1
		if waited > _SIGNAL_BUDGET_TICKS:
			return false
	assert_eq(arena.sim.health_of(envoy_id), health, "%s: hurt while waiting" % label)
	_idle(arena, _REACTION_TICKS)
	assert_eq(arena.sim.health_of(envoy_id), health, "%s: hurt during the reaction delay" % label)
	for i in _SIGNAL_BUDGET_TICKS:
		var dx: float = x - arena.sim.entities[envoy_id].x
		if absf(dx) < 0.07:
			break
		arena._step([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": Vector3(signf(dx), 0, 0)})] as Array[Command], DT)
	assert_eq(arena.sim.health_of(envoy_id), health, "%s: hurt while stepping" % label)
	return true


## The edge a player sees: the pad was writing on the last tick and is dark now.
func _retracts(arena: Node3D, pad_id: int) -> Callable:
	var state: Dictionary = {"was": arena.sim.spike_pad_ticks_until_active(pad_id)}
	return func() -> bool:
		var now: int = arena.sim.spike_pad_ticks_until_active(pad_id)
		var edge: bool = state["was"] == 0 and now > 0
		state["was"] = now
		return edge


func _warns(arena: Node3D, pad_id: int) -> Callable:
	return func() -> bool: return arena.sim.spike_pad_ticks_until_active(pad_id) == FloorBuilder._HAZARD_WARN_LEAD_TICKS


## Where a player waits on a pad: just short of its front edge, clear of the shared line.
func _front(pad: SpikePadPlan) -> float:
	return pad.rect.end.x - 0.5


## Where a player waits to start: at the apron's edge, just short of pad 1. (Measured: from 4 u
## further back, reaction + walk overran pad 1's 80-tick safe stretch and missed its first "go".)
func _onto_the_west_apron(arena: Node3D) -> void:
	var first: SpikePadPlan = _by_position()[0]
	arena.sim.entities[arena.envoy.actor_id] = Vector3(first.rect.position.x - 0.5, 0.0, first.rect.get_center().y)


func _east_apron_x() -> float:
	return (_by_position()[3].rect.end.x + _patch(&"P_CONNECTOR").end.x) * 0.5


## THE WHOLE CROSSING, as a player does it: from the west apron, onto pad 1 when it goes dark,
## then forward each time the pad underfoot starts warning, off pad 4 onto the east apron --
## each move only after the reaction delay, ordinary walking speed, and not one point of damage.
func test_a_player_crosses_on_the_signal_without_damage() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = arena.envoy.actor_id
	var pads: Array = _by_position()
	_onto_the_west_apron(arena)
	var health: float = arena.sim.health_of(envoy_id)
	assert_true(_on_signal_walk_to(arena, _retracts(arena, pads[0].pad_id), _front(pads[0]), health, "onto pad 1"))
	for i in range(1, 4):
		assert_true(_on_signal_walk_to(arena, _warns(arena, pads[i - 1].pad_id), _front(pads[i]), health, "onto pad %d" % (i + 1)))
	assert_true(_on_signal_walk_to(arena, _warns(arena, pads[3].pad_id), _east_apron_x(), health, "onto the east apron"))
	assert_gt(arena.sim.entities[envoy_id].x, pads[3].rect.end.x, "reached the east apron")
	_idle(arena, 200)
	assert_eq(arena.sim.health_of(envoy_id), health, "the apron is safe ground")


## A MISSED BEAT IS RECOVERABLE. From the apron, letting pad 1's opening pass just means waiting
## for the next. On a pad, when your pad warns BOTH neighbours have just gone dark (they are one
## group), so a player who will not go forward can step BACK and pick the rhythm up again --
## from the pad's centre or back half. Measured limit: retreating from the FRONT edge crosses the
## whole pad backwards (20 + 34 ticks > the 50-tick window) and is hit; forward is the way out there.
func test_a_missed_beat_can_be_recovered() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = arena.envoy.actor_id
	var pads: Array = _by_position()
	_onto_the_west_apron(arena)
	var health: float = arena.sim.health_of(envoy_id)
	# Let one whole opening go by from the apron.
	_await_query(arena, pads[0].pad_id, 0)
	_idle(arena, pads[0].active_ticks + 10)
	assert_true(_on_signal_walk_to(arena, _retracts(arena, pads[0].pad_id), _front(pads[0]), health, "onto pad 1, one cycle late"))
	assert_true(_on_signal_walk_to(arena, _warns(arena, pads[0].pad_id), pads[1].rect.get_center().x, health, "onto the middle of pad 2"))
	# Pad 2 warns: refuse to go forward and retreat to pad 1 instead.
	assert_true(_on_signal_walk_to(arena, _warns(arena, pads[1].pad_id), pads[0].rect.get_center().x, health, "back to pad 1"))
	assert_true(_on_signal_walk_to(arena, _warns(arena, pads[0].pad_id), _front(pads[1]), health, "forward again to pad 2"))
	for i in range(2, 4):
		assert_true(_on_signal_walk_to(arena, _warns(arena, pads[i - 1].pad_id), _front(pads[i]), health, "onto pad %d" % (i + 1)))
	assert_true(_on_signal_walk_to(arena, _warns(arena, pads[3].pad_id), _east_apron_x(), health, "onto the east apron"))
	assert_eq(arena.sim.health_of(envoy_id), health)


# --- 4: THE TWO-KEY GATE, AS DATA -------------------------------------------------------------

func _trigger(key: StringName) -> FloorTrigger:
	for trigger: FloorTrigger in plan.triggers:
		if trigger.trigger_id == _id(key):
			return trigger
	return null


func _carriable(key: StringName) -> CarriablePlan:
	for carriable: CarriablePlan in plan.carriables:
		if carriable.carriable_id == _id(key):
			return carriable
	return null


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


## Exactly two keys and two receivers, and each receiver opens its own gate and nothing else.
## Nothing else on the floor may open either gate: delivery is the only way through.
func test_each_receiver_opens_its_own_gate_and_nothing_else_does() -> void:
	assert_eq(plan.carriables.size(), 2, "two physical keys")
	assert_eq(plan.hit_switches.size(), 0, "the hit-switch stand-ins are gone")
	var receivers: Array = plan.triggers.filter(func(t: FloorTrigger) -> bool: return t.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED)
	assert_eq(receivers.size(), 2, "one receiver per gate")
	for pairing: Array in [[&"R_GATE_1", &"C_LOCK_W"], [&"R_GATE_2", &"C_LOCK_E"]]:
		var receiver: FloorTrigger = _trigger(pairing[0])
		assert_eq(receiver.kind, FloorLayers.TRIGGER_CARRIABLE_INSERTED)
		assert_true(receiver.once, "a receiver takes one key")
		assert_eq(receiver.effects.size(), 1)
		assert_eq(receiver.effects[0]["kind"], FloorLayers.EFFECT_OPEN_CONNECTION)
		assert_eq(int(receiver.effects[0]["target_id"]), _id(pairing[1]), "%s opens %s" % pairing)
	for trigger: FloorTrigger in plan.triggers:
		if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
			continue
		for effect: Dictionary in trigger.effects:
			assert_false(int(effect.get("target_id", -1)) in [_id(&"C_LOCK_W"), _id(&"C_LOCK_E")]
				and effect["kind"] in [FloorLayers.EFFECT_OPEN_CONNECTION, FloorLayers.EFFECT_TOGGLE_CONNECTION],
				"trigger %d opens a gate without a key" % trigger.trigger_id)


## SEQUENTIAL BY GEOMETRY, not by a rule: Gate 1's receiver stands in the hub, Gate 2's in the
## vestibule that only Gate 1 reaches. Each region sits wholly on its own side.
func test_the_receivers_stand_in_series() -> void:
	var hub: Rect2 = _patch(&"P_HUB")
	var vestibule: Rect2 = _patch(&"P_VESTIBULE")
	var first: Rect2 = _trigger(&"R_GATE_1").region
	var second: Rect2 = _trigger(&"R_GATE_2").region
	assert_true(hub.encloses(first), "Gate 1's receiver is in the hub")
	assert_true(vestibule.encloses(second), "Gate 2's receiver is in the vestibule")
	assert_false(hub.intersects(second), "Gate 2's receiver cannot be stood in from the hub")


const WEST_PATCHES: Array[StringName] = [&"P_WEST_NECK", &"P_WEST_LOW", &"P_WEST_BAY", &"P_WEST_RECESS",
	&"P_WEST_LEG", &"P_WEST_APEX", &"P_WEST_NICHE", &"P_WEST_TOP", &"P_WEST_LOW_BULGE", &"P_WEST_TOP_ALCOVE"]


## NO SHORTCUT HOME (Stage 2 iteration, 2026-10-16). The loop winds round its void but meets the
## rest of the floor at exactly one doorway, the one it is entered by -- so the key goes home the
## way it came. Not a door that opens late: the old return connection is gone from the floor.
func test_the_west_loop_is_entered_and_left_by_one_doorway() -> void:
	var west: Array = WEST_PATCHES.map(func(key: StringName) -> int: return _id(key))
	var ways_out: Array = []
	for connection: TraversalConnection in plan.connections:
		var near_in: bool = connection.patch_ids.x in west
		var far_in: bool = connection.patch_ids.y in west
		if near_in != far_in:
			ways_out.append(connection.connection_id)
	assert_eq(ways_out, [_id(&"C_HUB_WEST")], "the loop's only doorway is the one from the hub")


## The key waits in plain sight at the loop's far end -- the top band's end beside the hub, across
## the void from it -- not conjured by a clear. The hub is close enough to see it and too far to
## reach it.
func test_the_west_key_waits_visible_at_the_far_end_of_the_loop() -> void:
	var key: CarriablePlan = _carriable(&"K_WEST")
	assert_false(key.starts_hidden, "the key is discoverable, not revealed")
	var top: Rect2 = _patch(&"P_WEST_TOP")
	assert_true(top.has_point(Vector2(key.position.x, key.position.z)), "it stands on the top band")
	assert_lt(top.end.x - key.position.x, 4.0, "at the band's far end")
	var entry: Rect2 = _patch(&"P_WEST_NECK")
	assert_gt(_patch(&"P_HUB").position.y - key.position.z, 5.0, "across the void from the hub, not beside a door into it")
	assert_gt(Vector2(key.position.x, key.position.z).distance_to(entry.get_center()), 20.0, "and nowhere near the loop's entrance")
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			assert_ne(effect["kind"], FloorLayers.EFFECT_REVEAL_CARRIABLE, "no key on this floor is conjured")


## THE RETURN AMBUSH, AS DATA. The key's FIRST lift wakes a small, finite roster standing on the
## way back; it is optional, seals nobody in, and stands a fair distance from the key.
func test_the_first_lift_of_the_west_key_wakes_the_return_ambush() -> void:
	var trigger: FloorTrigger = _trigger(&"T_WEST_LIFT")
	assert_eq(trigger.kind, FloorLayers.TRIGGER_CARRIABLE_LIFTED)
	assert_eq(trigger.source_id, _id(&"K_WEST"))
	assert_true(trigger.once, "the first lift only")
	assert_eq(trigger.effects.map(func(e: Dictionary) -> Array: return [e["kind"], e["target_id"]]),
		[[FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, _id(&"E_WEST_RETURN")]])
	var ambush: EncounterSite = _encounter(&"E_WEST_RETURN")
	assert_eq(ambush.role, FloorLayers.ROLE_OPTIONAL, "it can be evaded; clearing it is never required")
	assert_false(ambush.confines_player, "and it seals nobody in")
	assert_false(ambush.spawn_at_floor_load, "it is not there until the key is lifted")
	assert_between(ambush.roster.size(), 2, 4, "small and finite")
	var key: CarriablePlan = _carriable(&"K_WEST")
	for spawn: Dictionary in ambush.roster:
		var at: Vector3 = spawn["position"]
		assert_gt(Vector2(at.x, at.z).distance_to(Vector2(key.position.x, key.position.z)), 14.0,
			"%s at %s arrives on top of the carrier" % [spawn["enemy_key"], at])
	var west: Array[Rect2] = []
	for key_name: StringName in WEST_PATCHES:
		west.append(_patch(key_name))
	for region: Rect2 in ambush.regions:
		var on_the_route: bool = false
		for patch: Rect2 in west:
			on_the_route = on_the_route or patch.encloses(region)
		assert_true(on_the_route, "ambush ground %s is off the loop" % region)
	# Nothing else on the floor watches a key's lift.
	for other: FloorTrigger in plan.triggers:
		if other.trigger_id != trigger.trigger_id:
			assert_ne(other.kind, FloorLayers.TRIGGER_CARRIABLE_LIFTED)


## NO CLOSED GATE CAN STRAND A KEY. The floor's only closing effect is the party plate's, beyond
## both gates; both gates open only by delivery. So by the time anything can close, both keys are
## already in their receivers and can no longer be lost.
func test_no_closing_effect_is_reachable_while_a_key_is_loose() -> void:
	var closers: Array = []
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect["kind"] in [FloorLayers.EFFECT_BLOCK_CONNECTION, FloorLayers.EFFECT_TOGGLE_CONNECTION]:
				closers.append(trigger.trigger_id)
	assert_eq(closers, [_id(&"T_PARTY")], "the party plate is the only thing on the floor that closes a route")
	var chamber: Rect2 = _patch(&"P_CHAMBER")
	assert_true(chamber.encloses(_trigger(&"T_PARTY").region), "and it stands north of both gates")


## The locks stand on the side of the hub their wing is on, so the gate reads as two halves.
func test_each_lock_stands_on_its_own_wings_side() -> void:
	var hub_x: float = _patch(&"P_HUB").get_center().x
	for connection: TraversalConnection in plan.connections:
		if connection.connection_id == _id(&"C_LOCK_W"):
			assert_lt(connection.aperture.end.x, hub_x, "the west lock is on the west half")
		if connection.connection_id == _id(&"C_LOCK_E"):
			assert_gt(connection.aperture.position.x, hub_x, "the east lock is on the east half")


## The east key sits behind cover: every line from the room's entrance to the key runs through the
## mass authored in front of it, so the room has to be entered to find it (Stage 1 composition).
func test_the_east_key_cannot_be_shot_from_the_doorway() -> void:
	var key_at := Vector2(_carriable(&"K_EAST").position.x, _carriable(&"K_EAST").position.z)
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
## On round the apex and east along the top band to the key at its far end.
const WEST_TO_KEY: Array[Vector3] = [Vector3(-42, 0, -64), Vector3(-20, 0, -63)]
## Home THE WAY IN: back along the band, down the leg, through the low band and the neck.
const WEST_HOME: Array[Vector3] = [Vector3(-42, 0, -64), Vector3(-47, 0, -62), Vector3(-47, 0, -52), Vector3(-47, 0, -44), Vector3(-47, 0, -39), Vector3(-27, 0, -38), Vector3(-16, 0, -38)]
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


## Where to stand to lift each key, and to deliver at each receiver.
const WEST_KEY_STAND := Vector3(-14.6, 0, -63)
const EAST_KEY_STAND := Vector3(46, 0, -58.6)
## Out of the bay the way in came: a straight line home from the key clips the cover mass.
const EAST_BAY_EXIT := Vector3(47, 0, -50)
const GATE_1_STAND := Vector3(-4, 0, -54.5)
const GATE_2_ROUTE: Array[Vector3] = [Vector3(-4, 0, -54.5), Vector3(-4, 0, -62), Vector3(4, 0, -62.5)]


## One primary-attack click, the shipped way: pressed then released, through the driver.
func _click(arena: Node3D, aim: Vector3) -> void:
	var envoy_id: int = arena.envoy.actor_id
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "pressed"})] as Array[Command], DT)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "released"})] as Array[Command], DT)


func _carried(arena: Node3D) -> int:
	return arena.sim.carried_by(arena.envoy.actor_id)


func _key_position(arena: Node3D, key: StringName) -> Vector3:
	return arena.sim._carriables[_id(key)]["position"]


## Lifts a key by aiming the attack press at it, from where the Envoy stands.
func _lift(arena: Node3D, key: StringName) -> void:
	_click(arena, _key_position(arena, key) - arena.sim.entities[arena.envoy.actor_id])


func _filled(arena: Node3D, receiver_key: StringName) -> bool:
	return arena.sim._triggers_fired.has(_id(receiver_key))


## Delivers the carried key at the first receiver that can take it: Gate 1's if it is still empty,
## otherwise through Gate 1 to Gate 2's.
func _deliver(arena: Node3D) -> void:
	assert_ne(_carried(arena), -1, "sanity: carrying a key to deliver")
	if not _filled(arena, &"R_GATE_1"):
		assert_true(_walk_to(arena, GATE_1_STAND, 0.3), "to Gate 1's receiver")
	else:
		for waypoint: Vector3 in GATE_2_ROUTE:
			assert_true(_walk_to(arena, waypoint, 0.3), "to Gate 2's receiver: %s" % waypoint)
	_click(arena, Vector3(0, 0, -2))
	assert_eq(_carried(arena), -1, "the press delivered the key")


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


## Out round the loop to the key, lifting it (which wakes the ambush). Leaves the Envoy carrying.
func _reach_and_lift_the_west_key(arena: Node3D) -> void:
	_walk(arena, WEST_OUT, "west")
	assert_eq(_state(arena, &"E_WEST"), "active", "the loop's fight woke on the way in")
	_kill(arena, &"E_WEST")
	_walk(arena, WEST_TO_KEY, "west, to the key")
	assert_true(_walk_to(arena, WEST_KEY_STAND, 0.3), "to the far end of the top band")
	assert_eq(_state(arena, &"E_WEST_RETURN"), "dormant", "the ambush waits for the lift, not for the walk")
	_lift(arena, &"K_WEST")
	assert_eq(_carried(arena), _id(&"K_WEST"), "the attack press lifts the focused key")
	assert_eq(_state(arena, &"E_WEST_RETURN"), "active", "and the lift wakes the way back")


func _take_the_west_key(arena: Node3D) -> void:
	_reach_and_lift_the_west_key(arena)
	_kill(arena, &"E_WEST_RETURN")  # a traversal test; the fight has its own test below
	_walk(arena, WEST_HOME, "west return, carrying")
	_deliver(arena)


func _take_the_east_key(arena: Node3D) -> void:
	_walk(arena, EAST_OUT, "east")
	assert_eq(_state(arena, &"E_EAST"), "active", "the room's fight woke on the way in")
	_kill(arena, &"E_EAST")
	assert_true(_walk_to(arena, EAST_KEY_STAND, 0.3), "into the key bay")
	_lift(arena, &"K_EAST")
	assert_eq(_carried(arena), _id(&"K_EAST"))
	assert_true(_walk_to(arena, EAST_BAY_EXIT), "out of the bay, carrying")
	_walk(arena, EAST_HOME, "east return, carrying")
	_deliver(arena)


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


## THE FIRST KEY, WHICHEVER WING IT CAME FROM, OPENS GATE 1 AND ONLY GATE 1.
func test_the_west_key_alone_opens_only_gate_one() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_take_the_west_key(arena)
	assert_true(_open(arena, &"C_LOCK_W"), "the first key delivered opens Gate 1")
	assert_false(_open(arena, &"C_LOCK_E"))
	assert_true(_walk_to(arena, Vector3(-4, 0, -62)), "the vestibule is now reachable")
	assert_false(_walk_to(arena, Vector3(4, 0, -74), 1.0, 400), "and the junction beyond it is not")


func test_the_east_key_alone_opens_only_gate_one() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_take_the_east_key(arena)
	assert_true(_open(arena, &"C_LOCK_W"), "either key fits Gate 1: the east key opens it too")
	assert_false(_open(arena, &"C_LOCK_E"))
	assert_eq(_state(arena, &"E_WEST_RETURN"), "dormant", "and the east key woke nothing in the west")


## Gate 2's receiver is behind Gate 1, so a carried key cannot reach it first.
func test_gate_two_receiver_cannot_be_reached_before_gate_one_opens() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_walk(arena, EAST_OUT, "east")
	_kill(arena, &"E_EAST")
	assert_true(_walk_to(arena, EAST_KEY_STAND, 0.3))
	_lift(arena, &"K_EAST")
	assert_true(_walk_to(arena, EAST_BAY_EXIT))
	_walk(arena, EAST_HOME, "east return, carrying")
	assert_true(_walk_to(arena, GATE_1_STAND, 0.3))
	assert_false(_walk_to(arena, Vector3(4, 0, -62.5), 0.3, 400), "Gate 1 still stands between the hub and Gate 2's receiver")
	assert_eq(_carried(arena), _id(&"K_EAST"), "the key is still in hand")


## A KEY KNOCKED LOOSE ON EITHER ROUTE CAN BE PICKED UP AGAIN, and a dropped key never blocks the
## fight around it. Drop by hit (a real enemy blow), recover by aiming at it, deliver.
func test_a_key_knocked_loose_on_the_east_route_is_recovered() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_walk(arena, EAST_OUT, "east")
	assert_true(_walk_to(arena, EAST_KEY_STAND, 0.3))
	_lift(arena, &"K_EAST")
	assert_eq(_carried(arena), _id(&"K_EAST"))
	# The east roster is live here. Wait for a real blow rather than staging one.
	var knocked: bool = false
	for i in 900:
		_idle(arena, 1)
		if _carried(arena) == -1:
			knocked = true
			break
	assert_true(knocked, "a Watcher in its own room hits a carrier who stands still")
	var key_at: Vector3 = _key_position(arena, &"K_EAST")
	assert_true(plan.make_bounds().fits(key_at, 0.45), "it fell where an Envoy can stand")
	_kill(arena, &"E_EAST")
	assert_true(_walk_to(arena, _beside(key_at), 0.2), "the fallen key lies on walkable ground")
	_lift(arena, &"K_EAST")
	assert_eq(_carried(arena), _id(&"K_EAST"), "and is lifted again")
	assert_true(_walk_to(arena, EAST_BAY_EXIT))
	_walk(arena, EAST_HOME, "east return, carrying")
	_deliver(arena)
	assert_true(_open(arena, &"C_LOCK_W"))


func test_a_key_dropped_on_the_west_route_is_recovered_and_cannot_be_lost_once_delivered() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_reach_and_lift_the_west_key(arena)
	_kill(arena, &"E_WEST_RETURN")
	_walk(arena, WEST_HOME.slice(0, 2), "partway home")
	_click(arena, Vector3(0, 0, -2))  # a voluntary drop, mid-route
	assert_eq(_carried(arena), -1)
	var key_at: Vector3 = _key_position(arena, &"K_WEST")
	_walk_to(arena, _beside(key_at), 0.2)
	_lift(arena, &"K_WEST")
	assert_eq(_carried(arena), _id(&"K_WEST"), "recovered: step off it and aim back")
	_walk(arena, WEST_HOME.slice(2), "the rest of the way home")
	_deliver(arena)
	assert_true(bool(arena.sim._carriables[_id(&"K_WEST")]["inserted"]))
	_lift(arena, &"K_WEST")
	assert_eq(_carried(arena), -1, "a delivered key can never be lifted back out")
	assert_true(_open(arena, &"C_LOCK_W"), "and its gate stays open")


## THE RETURN AMBUSH, THROUGH THE REAL ARENA: the lift wakes it once, it comes from a distance a
## carrier can read, and a carrier who stands there is reached -- not instantly.
func test_the_west_lift_wakes_the_ambush_at_a_readable_distance() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_reach_and_lift_the_west_key(arena)
	var envoy_at: Vector3 = arena.sim.entities[arena.envoy.actor_id]
	var engaged: int = 0
	for actor_id: int in arena.sim._encounter_roster[_id(&"E_WEST_RETURN")]:
		assert_false(arena.sim._combat_absent.has(actor_id), "actor %d is present the moment the key is lifted" % actor_id)
		assert_gt(_flat(arena.sim.entities[actor_id], envoy_at), 12.0, "actor %d appears too close to the carrier" % actor_id)
		engaged += int(String(arena.sim._ai_state.get(actor_id, "")) == "active")
	assert_gt(engaged, 0, "the nearest of them come for the key at once")
	var lifted_at: int = arena.sim.tick_count
	var dropped_at: int = -1
	for i in 900:
		_idle(arena, 1)
		if _carried(arena) == -1:
			dropped_at = arena.sim.tick_count
			break
	assert_ne(dropped_at, -1, "a carrier who stands still is reached")
	assert_gt(dropped_at - lifted_at, 60, "but with at least two seconds to see it coming and drop the key")


## The ambush is spent by the first lift: dropping and re-lifting the key wakes nothing more.
func test_re_lifting_the_west_key_wakes_no_second_ambush() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_reach_and_lift_the_west_key(arena)
	var roster: Array = arena.sim._encounter_roster[_id(&"E_WEST_RETURN")].duplicate()
	_kill(arena, &"E_WEST_RETURN")
	assert_eq(_state(arena, &"E_WEST_RETURN"), "cleared")
	assert_true(arena.sim._triggers_fired.has(_id(&"T_WEST_LIFT")), "the first lift spent its trigger")
	for i in 3:
		_click(arena, Vector3(0, 0, -2))
		assert_eq(_carried(arena), -1, "sanity: dropped")
		var key_at: Vector3 = _key_position(arena, &"K_WEST")
		assert_true(_walk_to(arena, _beside(key_at), 0.2))
		_lift(arena, &"K_WEST")
		assert_eq(_carried(arena), _id(&"K_WEST"), "sanity: lifted again")
		assert_eq(_state(arena, &"E_WEST_RETURN"), "cleared", "re-lift %d woke nothing" % i)
	assert_eq(arena.sim._encounter_roster[_id(&"E_WEST_RETURN")], roster, "and no roster grew")
	for actor_id: int in roster:
		assert_eq(arena.sim.health_of(actor_id), 0.0, "and nothing that was beaten came back")


## DROP THE KEY AND FIGHT: a real fight with the shipped sword, against the real roster, then the
## key is lifted again and carried home.
func test_the_carrier_can_drop_the_key_and_fight_the_ambush() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_reach_and_lift_the_west_key(arena)
	_click(arena, Vector3(0, 0, -2))
	assert_eq(_carried(arena), -1, "dropped to fight")
	var key_at: Vector3 = _key_position(arena, &"K_WEST")
	var envoy_id: int = arena.envoy.actor_id
	for i in 4000:
		if _state(arena, &"E_WEST_RETURN") == "cleared":
			break
		var target: int = -1
		var nearest: float = INF
		for actor_id: int in arena.sim._encounter_roster[_id(&"E_WEST_RETURN")]:
			if arena.sim.health_of(actor_id) <= 0.0 or arena.sim._combat_absent.has(actor_id):
				continue
			var distance: float = _flat(arena.sim.entities[actor_id], arena.sim.entities[envoy_id])
			if distance < nearest:
				nearest = distance
				target = actor_id
		if target < 0:
			_idle(arena, 1)
		elif nearest > 1.8:
			var toward: Vector3 = arena.sim.entities[target] - arena.sim.entities[envoy_id]
			toward.y = 0.0
			arena._step([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": toward.normalized()})] as Array[Command], DT)
		else:
			_click(arena, arena.sim.entities[target] - arena.sim.entities[envoy_id])
			_idle(arena, 8)
	assert_eq(_state(arena, &"E_WEST_RETURN"), "cleared", "the ambush is beaten with the sword")
	assert_eq(_carried(arena), -1, "no key was lifted by any swing of that fight")
	assert_eq(_key_position(arena, &"K_WEST"), key_at, "and the key lay where it was dropped throughout")
	assert_true(_walk_to(arena, _beside(key_at), 0.2))
	_lift(arena, &"K_WEST")
	assert_eq(_carried(arena), _id(&"K_WEST"))
	_walk(arena, WEST_HOME, "west return, carrying")
	_deliver(arena)
	assert_true(_open(arena, &"C_LOCK_W"))


## A standable point a step from a lying key -- never on it, since a key underfoot has no
## direction to aim at (SimWorld._resolve_interaction_target).
func _beside(key_at: Vector3) -> Vector3:
	var bounds: WalkableBounds = plan.make_bounds()
	for offset: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if bounds.fits(key_at + offset, 0.45):
			return key_at + offset
	return key_at + Vector3(1, 0, 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- 6: THE EAST ROOM, ON THE ROUTE A PLAYER WALKS --------------------------------------------

## Diagnosed after the human playtest (2026-10-16): the east room DOES activate on the normal
## route -- the doorway trigger fires as the player steps in -- and its Fangs engage.
func test_the_east_room_wakes_on_the_normal_route_to_its_key() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	assert_eq(_state(arena, &"E_EAST"), "dormant", "sanity: nothing east is awake from the hub")
	_walk(arena, EAST_OUT, "east")
	assert_eq(_state(arena, &"E_EAST"), "active", "the doorway wakes the room on the way to the key")
	assert_true(_walk_to(arena, EAST_KEY_STAND, 0.3), "into the key bay")
	var fangs_engaged: int = 0
	for actor_id: int in arena.sim._encounter_roster[_id(&"E_EAST")]:
		# Present, or underground mid-burrow -- never still deferred.
		assert_true(not arena.sim._combat_absent.has(actor_id) or arena.sim._burrow.has(actor_id),
			"actor %d never arrived" % actor_id)
		if arena.sim._families.get(actor_id, &"") == &"fang":
			fangs_engaged += int(String(arena.sim._ai_state.get(actor_id, "")) == "active")
	assert_gt(fangs_engaged, 0, "a Fang is on the carrier by the time the key is in reach")


## EVERY WATCHER JOINS THE FIGHT ON THE ROUTE A PLAYER WALKS (defect confirmed by human play,
## 2026-10-16). Both Watchers used to stand 20+ units from the doorway that wakes the room --
## beyond their 18-unit leash -- so activation engaged them and the leash dropped them back to
## idle on the next tick, and from the key bay they were out of detection range: the room's
## ranged pressure never arrived. Fixed in CONTENT (Option A): each Watcher now stands within its
## leash of every point of the doorway and of the key bay. The leash rule (2026-09-08) is untouched.
func test_the_east_watchers_engage_and_fire_on_the_normal_route() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	var watchers: Array = []
	for actor_id: int in arena.sim._encounter_roster[_id(&"E_EAST")]:
		if arena.sim._families.get(actor_id, &"") == &"watcher":
			watchers.append(actor_id)
	assert_eq(watchers.size(), 2, "sanity: the room fields two Watchers")
	var shots: Dictionary = {}
	var seen: Dictionary = {}
	var route: Array[Vector3] = []
	route.append_array(EAST_OUT)
	route.append(EAST_KEY_STAND)
	for waypoint: Vector3 in route:
		for i in 1500:
			var offset: Vector3 = waypoint - arena.sim.entities[arena.envoy.actor_id]
			offset.y = 0.0
			if offset.length() < 0.3:
				break
			arena._step([Command.new(arena.sim.tick_count, arena.envoy.actor_id, "move", {"direction": offset.normalized()})] as Array[Command], DT)
			_count_shots(arena, watchers, shots, seen)
	_lift(arena, &"K_EAST")
	for i in 150:  # a carrier lingering in the bay
		_idle(arena, 1)
		_count_shots(arena, watchers, shots, seen)
	for watcher_id: int in watchers:
		assert_gt(int(shots.get(watcher_id, 0)), 0, "Watcher %d never fired on the way to the key" % watcher_id)
		assert_eq(String(arena.sim._ai_state.get(watcher_id, "")), "active", "Watcher %d is still in the fight at the bay" % watcher_id)


## AND THE ORDINARY LEASH STILL LETS THE ROOM BE WALKED AWAY FROM: the placement fix engages the
## Watchers without making them follow a retreating player across the floor.
func test_the_east_room_gives_up_when_the_player_retreats_to_the_hub() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_walk(arena, EAST_OUT, "east")
	assert_eq(_state(arena, &"E_EAST"), "active")
	_walk(arena, EAST_HOME, "retreating")
	_walk(arena, [Vector3(-8, 0, -40), Vector3(-12, 0, -50)] as Array[Vector3], "across the hub")
	_idle(arena, 60)
	for actor_id: int in arena.sim._encounter_roster[_id(&"E_EAST")]:
		if arena.sim.health_of(actor_id) <= 0.0:
			continue
		assert_eq(String(arena.sim._ai_state.get(actor_id, "")), "idle", "actor %d is still chasing across the floor" % actor_id)


## THE DOORWAY WAKES THE ROOM FROM ANY LANE (defect found in human play, 2026-10-17). T_EAST
## used to span only the doorway's own width (z -46..-34), but the room opens wider than its
## doorway: a player hugging the north wall turned up the room's west column (x 38..40) and
## crossed into the room north of the trigger, reaching the key with the room still asleep. The
## threshold is now the room's whole west column, so no path into the room goes round it.
func test_the_east_threshold_spans_the_room_it_guards() -> void:
	var threshold: Rect2 = Rect2()
	for trigger: FloorTrigger in plan.triggers:
		if trigger.trigger_id == _id(&"T_EAST"):
			threshold = trigger.region
	var room: Rect2 = _patch(&"P_EAST_ROOM")
	assert_lte(threshold.position.y, room.position.y, "the threshold reaches the room's north wall")
	assert_gte(threshold.end.y, room.end.y, "the threshold reaches the room's south wall")
	# Cut where the room alone is walkable, past the overlap with the corridor: crossing it is
	# entering the room, and standing in the corridor never is.
	assert_gte(threshold.position.x, _patch(&"P_EAST_JOG").end.x, "the threshold starts past the corridor")
	assert_lt(threshold.position.x, _patch(&"P_EAST_ROOM_CROSS").position.x, "and before the room widens")


## Left wall, centre, right wall: each a route a player could take from the corridor to the key.
const EAST_LANES: Dictionary = {
	"left wall": [Vector3(36, 0, -45.4), Vector3(38.8, 0, -45.4), Vector3(38.8, 0, -51.4), Vector3(47, 0, -51.4), Vector3(47, 0, -55.5)],
	"centre": [Vector3(38.8, 0, -42), Vector3(47, 0, -50), Vector3(47, 0, -55.5)],
	"right wall": [Vector3(36, 0, -38.6), Vector3(38.8, 0, -38.6), Vector3(38.8, 0, -32.6), Vector3(53, 0, -33), Vector3(53, 0, -53), Vector3(47, 0, -55.5)],
}


func test_every_doorway_lane_wakes_the_east_room_before_the_key() -> void:
	for lane: String in EAST_LANES:
		var arena: Node3D = _boot()
		_reach_the_hub(arena)
		_walk(arena, EAST_OUT.slice(0, 3), "%s: down the corridor" % lane)
		var roster: Array = arena.sim._encounter_roster[_id(&"E_EAST")].duplicate()
		var bodies: Array = arena.sim.entities.keys()
		var route: Array[Vector3] = []
		route.assign(EAST_LANES[lane])
		route.append(EAST_KEY_STAND)
		var woke_at: Vector3 = Vector3.INF
		var deepest_asleep: float = -INF
		var arrived_at: Dictionary = {}
		var engaged: Dictionary = {}
		for waypoint: Vector3 in route:
			for i in 1500:
				var at: Vector3 = arena.sim.entities[arena.envoy.actor_id]
				if Vector2(waypoint.x - at.x, waypoint.z - at.z).length() < 0.3:
					break
				arena._step([Command.new(arena.sim.tick_count, arena.envoy.actor_id, "move", {"direction": Vector3(waypoint.x - at.x, 0, waypoint.z - at.z).normalized()})] as Array[Command], DT)
				at = arena.sim.entities[arena.envoy.actor_id]
				if _state(arena, &"E_EAST") == "dormant":
					deepest_asleep = maxf(deepest_asleep, at.x)
				elif woke_at == Vector3.INF:
					woke_at = at
					for actor_id: int in roster:
						arrived_at[actor_id] = arena.sim.entities[actor_id]
				for actor_id: int in roster:
					if String(arena.sim._ai_state.get(actor_id, "")) == "active":
						engaged[actor_id] = true
		assert_eq(_state(arena, &"E_EAST"), "active", "%s: the room woke on the way to the key" % lane)
		# A tick's step is 0.13 units: asleep, the Envoy never got past the threshold's edge.
		assert_lt(deepest_asleep, 40.2, "%s: walked into the room past x=%.2f with it asleep" % [lane, deepest_asleep])
		assert_gte(woke_at.x, 40.0, "%s: woke early, at %s, still outside the room" % [lane, woke_at])
		for actor_id: int in arrived_at:
			assert_gte(_flat(woke_at, arrived_at[actor_id]), 6.0, "%s: actor %d arrived on top of the Envoy" % [lane, actor_id])
		# The room's ranged pressure and a Fang reach every lane. The far Fang (56, -40) is NOT
		# asserted: from the north wall it wakes 19.6 units off, past its 18-unit leash, and the key
		# route never comes within its detection -- the accepted placement and leash, unchanged.
		var fangs_engaged: int = 0
		for actor_id: int in roster:
			if arena.sim._families.get(actor_id, &"") == &"watcher":
				assert_true(engaged.has(actor_id), "%s: Watcher %d never joined the fight" % [lane, actor_id])
			else:
				fangs_engaged += int(engaged.has(actor_id))
		assert_gt(fangs_engaged, 0, "%s: no Fang joined the fight" % lane)
		assert_eq(arena.sim._encounter_roster[_id(&"E_EAST")], roster, "%s: the roster changed" % lane)
		assert_eq(arena.sim.entities.keys(), bodies, "%s: bodies were added or removed" % lane)
		_lift(arena, &"K_EAST")
		assert_eq(_carried(arena), _id(&"K_EAST"), "%s: the key is in reach at the end of the lane" % lane)


## Waking is once: out of the room to the hub (the leash drops the chase, 2026-09-08) and back in
## by another lane brings nobody new.
func test_retreat_and_re_entry_wake_nobody_twice() -> void:
	var arena: Node3D = _boot()
	_reach_the_hub(arena)
	_walk(arena, EAST_OUT.slice(0, 3), "down the corridor")
	var route: Array[Vector3] = []
	route.assign(EAST_LANES["centre"].slice(0, 2))
	_walk(arena, route, "in by the centre")
	assert_eq(_state(arena, &"E_EAST"), "active")
	var roster: Array = arena.sim._encounter_roster[_id(&"E_EAST")].duplicate()
	var bodies: Array = arena.sim.entities.keys()
	_walk(arena, EAST_HOME, "retreating")
	_idle(arena, 60)
	route.assign(EAST_OUT.slice(0, 3))
	route.append_array(EAST_LANES["left wall"].slice(0, 4))
	_walk(arena, route, "back in along the left wall")
	assert_eq(_state(arena, &"E_EAST"), "active", "still the same fight")
	assert_eq(arena.sim._encounter_roster[_id(&"E_EAST")], roster, "the roster changed on re-entry")
	assert_eq(arena.sim.entities.keys(), bodies, "re-entry added or removed bodies")
	for actor_id: int in roster:
		assert_false(arena.sim._combat_absent.has(actor_id) and not arena.sim._burrow.has(actor_id),
			"actor %d went back to waiting" % actor_id)


func _count_shots(arena: Node3D, watchers: Array, shots: Dictionary, seen: Dictionary) -> void:
	for projectile_id: int in arena.sim._projectiles:
		if seen.has(projectile_id):
			continue
		seen[projectile_id] = true
		var attacker: int = int(arena.sim._projectiles[projectile_id]["attacker_id"])
		if attacker in watchers:
			shots[attacker] = int(shots.get(attacker, 0)) + 1


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
	assert_true(_open(arena, &"C_LOCK_W") and _open(arena, &"C_LOCK_E"), "both keys, in either order, open both gates")

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


# --- P44: the shipped post-hit window, through the real driver ----------------------------------

## The DRIVER registers the Envoy with its content window. The literal 0 it used to pass is exactly
## the defect P44 found; this is the test that fails if it comes back.
func test_the_driver_registers_the_envoy_with_its_content_window() -> void:
	var arena: Node3D = _boot()
	var stats: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	assert_eq(stats.iframe_ticks_on_hit, 90, "sanity: the ruled provisional shared window")
	assert_eq(int(arena.sim._iframe_ticks_on_hit[arena.envoy.actor_id]), stats.iframe_ticks_on_hit)


## Health, position and tick for every _step -- what the player sees, read back from the sim.
func _pad_trace(arena: Node3D, commands_at: Callable, ticks: int) -> Array:
	var envoy_id: int = arena.envoy.actor_id
	var trace: Array = []
	for i in ticks:
		var commands: Array[Command] = commands_at.call(arena.sim.tick_count, envoy_id)
		arena._step(commands, DT)
		trace.append([arena.sim.tick_count, arena.sim.health_of(envoy_id), arena.sim.entities[envoy_id]])
	return trace


## A real Arena on a real pad for two cycles. Knockback or drift could carry the Envoy off it, so
## the hard law is spacing (no two spike hits inside the window) and size (each is one pad
## hit); exactly one per activation is required only if contact was actually uninterrupted.
func test_a_real_arena_pad_hits_at_most_once_per_window() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = arena.envoy.actor_id
	var pad: SpikePadPlan = plan.spike_pads[0]
	var window: int = int(arena.sim._iframe_ticks_on_hit[envoy_id])
	arena.sim.entities[envoy_id] = _centre(pad.rect)
	var start: Vector3 = arena.sim.entities[envoy_id]
	var trace: Array = _pad_trace(arena, func(_t: int, _id: int) -> Array[Command]: return [] as Array[Command],
		2 * (pad.safe_ticks + pad.active_ticks))
	var drops: Array[int] = []
	var stayed: bool = true
	var last_health: float = 100000.0  # _boot's survivability override
	for row in trace:
		if row[1] < last_health:
			assert_almost_eq(last_health - row[1], pad.damage, 0.001, "each HP hit is one pad hit")
			drops.append(row[0])
		last_health = row[1]
		if row[2] != start:
			stayed = false
	assert_gt(drops.size(), 0, "the pad wrote while the Envoy stood on it")
	for i in range(1, drops.size()):
		assert_gte(drops[i] - drops[i - 1], window, "no two spike hits inside one window")
	if stayed:
		assert_eq(drops.size(), 2, "uninterrupted contact through two activations: one hit each")


## A GENERAL WINDOW COVERS THE NEXT PAD TOO (a consequence, not a hazard rule): hurt by one pad, the Envoy stands on the other
## pad of the same write group -- active at the same moment -- and takes nothing more.
func test_a_hurt_envoy_can_cross_another_active_corridor_pad() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = arena.envoy.actor_id
	var pads: Array = plan.spike_pads.duplicate()
	pads.sort_custom(func(a: SpikePadPlan, b: SpikePadPlan) -> bool: return a.rect.position.x < b.rect.position.x)
	var first: SpikePadPlan = pads[0]
	var partner: SpikePadPlan = pads[2]
	assert_eq(first.phase_offset_ticks, partner.phase_offset_ticks, "sanity: pads 1 and 3 write together")
	# Wait for the write at the arrival point, off every pad, so nothing opens a window early.
	for i in 400:
		if arena.sim.spike_pad_ticks_until_active(first.pad_id) == 0:
			break
		arena._step([] as Array[Command], DT)
	arena.sim.entities[envoy_id] = _centre(first.rect)
	var before: float = arena.sim.health_of(envoy_id)
	arena._step([] as Array[Command], DT)
	assert_almost_eq(before - arena.sim.health_of(envoy_id), first.damage, 0.001, "sanity: the first pad hurt")
	arena.sim.entities[envoy_id] = _centre(partner.rect)
	var hurt: float = arena.sim.health_of(envoy_id)
	var stood_on_live_spikes: int = 0
	for i in first.active_ticks - 1:
		if arena.sim.spike_pad_ticks_until_active(partner.pad_id) == 0:
			stood_on_live_spikes += 1
		arena._step([] as Array[Command], DT)
	assert_gt(stood_on_live_spikes, 0, "sanity: the partner pad was live underfoot")
	assert_eq(arena.sim.health_of(envoy_id), hurt, "the window the first pad opened covers every pad")


## Same scripted input, two fresh Arenas: the same trace, tick for tick.
func test_a_scripted_pad_crossing_replays_identically() -> void:
	var script: Callable = func(t: int, id: int) -> Array[Command]:
		if t >= 120 and t < 150:
			return [Command.new(t, id, "move", {"direction": Vector3(1, 0, 0)})] as Array[Command]
		return [] as Array[Command]
	var traces: Array = []
	for run in 2:
		var arena: Node3D = _boot()
		arena.sim.entities[arena.envoy.actor_id] = _centre(plan.spike_pads[0].rect)
		traces.append(_pad_trace(arena, script, 2 * (plan.spike_pads[0].safe_ticks + plan.spike_pads[0].active_ticks)))
	assert_eq(traces[0], traces[1])
