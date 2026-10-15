extends GutTest
## THE TERMINAL (ruled 2026-10-12): a safe floor that restores living Envoys to full health,
## once per visit. Three layers, each tested where it lives:
##
##   the EFFECT    in a bare SimWorld -- what restoration does and refuses to do
##   the CONTENT   the authored floor as data -- that "safe" is enforced, not hoped
##   the VISIT     through the real arena -- that a player can actually use it
##
## What is deliberately NOT here: Continue vs Extract, shops, tiers. None of them exist.

const DT := 1.0 / 30.0
const TERMINAL = preload("res://game/content/layouts/terminal.tres")
const TERMINAL_DEPTH := 3
const ENVOY := 0
const ALLY := 1
const MAX_HEALTH := 100.0

const RESTORE := {"kind": &"restore_envoy_health", "target_id": -1}
const PLATE := Rect2(-1.0, -7.0, 2.0, 2.0)
const ON_PLATE := Vector3(0.0, 0.0, -6.0)
const OFF_PLATE := Vector3(0.0, 0.0, 0.0)


func after_each() -> void:
	await get_tree().process_frame


# --- THE EFFECT ------------------------------------------------------------------------------

func _sim(party: Array = [ENVOY]) -> SimWorld:
	var sim := SimWorld.new()
	for actor_id: int in party:
		sim.add_entity(actor_id, OFF_PLATE, 5.0)
		sim.register_combatant(actor_id, MAX_HEALTH, &"envoy", 0, 0.0, &"player")
		sim.mark_run_persistent(actor_id)
	var floor_rects: Array[Rect2] = [Rect2(-10.0, -10.0, 20.0, 20.0)]
	sim.load_floor(WalkableBounds.new(floor_rects), OFF_PLATE)
	sim.register_patches(floor_rects)
	return sim


func _tick(sim: SimWorld) -> Array[Event]:
	return sim.tick([] as Array[Command], DT)


func _of_kind(events: Array[Event], kind: String) -> Array:
	var found: Array = []
	for event: Event in events:
		if event.kind == kind:
			found.append(event)
	return found


func test_restoration_brings_a_wounded_envoy_to_full_health() -> void:
	var sim: SimWorld = _sim()
	sim.debug_override_health(ENVOY, 12.0)
	var events: Array[Event] = sim._apply_floor_effect(RESTORE)

	assert_eq(sim.health_of(ENVOY), MAX_HEALTH)
	assert_eq(events.size(), 1, "one Event says the whole of what happened")
	assert_eq(events[0].kind, "envoys_restored")
	assert_eq(events[0].tick, sim.tick_count)
	assert_eq(events[0].payload["restored"], [
		{"actor_id": ENVOY, "health_before": 12.0, "health": MAX_HEALTH, "max_health": MAX_HEALTH},
	])


## Recovery, not resurrection (ruled): the dead are neither healed nor reported as healed.
func test_restoration_never_revives_the_dead() -> void:
	var sim: SimWorld = _sim([ENVOY, ALLY])
	sim.debug_override_health(ENVOY, 30.0)
	sim.debug_override_health(ALLY, 0.0)
	var events: Array[Event] = sim._apply_floor_effect(RESTORE)

	assert_eq(sim.health_of(ENVOY), MAX_HEALTH, "the living Envoy is restored")
	assert_eq(sim.health_of(ALLY), 0.0, "the fallen one stays fallen")
	var restored: Array = events[0].payload["restored"]
	assert_eq(restored.size(), 1)
	assert_eq(restored[0]["actor_id"], ENVOY)


## The whole party at once, in id order, so the Event reads the same on every machine.
func test_restoration_reaches_every_living_envoy_wherever_they_stand() -> void:
	var sim: SimWorld = _sim([ALLY, ENVOY])
	sim.debug_override_health(ENVOY, 40.0)
	sim.debug_override_health(ALLY, 60.0)
	var events: Array[Event] = sim._apply_floor_effect(RESTORE)

	assert_eq(sim.health_of(ENVOY), MAX_HEALTH)
	assert_eq(sim.health_of(ALLY), MAX_HEALTH)
	var ids: Array = []
	for entry: Dictionary in events[0].payload["restored"]:
		ids.append(entry["actor_id"])
	assert_eq(ids, [ENVOY, ALLY], "deterministic order, never Dictionary order")


## Only run-persistent actors are the party. Nothing else on the floor is healed by it.
func test_restoration_ignores_everything_that_is_not_the_party() -> void:
	var sim: SimWorld = _sim()
	sim.add_entity(50, Vector3(3.0, 0.0, 0.0), 2.0)
	sim.register_combatant(50, 80.0, &"fang")
	sim.debug_override_health(50, 5.0)
	sim._apply_floor_effect(RESTORE)
	assert_eq(sim.health_of(50), 5.0, "an enemy standing in a Terminal is not a guest")


## THE SHIELD HAS ONE RECOVERY LAW AND THIS IS NOT IT (ruled). Statuses likewise: they end at the
## floor boundary, so restoration neither needs to nor may cleanse them.
func test_restoration_touches_health_and_nothing_else() -> void:
	var sim: SimWorld = _sim()
	sim.register_shield(ENVOY, 50.0, 0.5, 30, 1.0)
	sim.register_status(&"burn", 1.0, 10, 90)
	sim._shield_meter[ENVOY] = 9.0
	sim._apply_status(ENVOY, &"burn", "test", ENVOY, "test_bite")
	sim.debug_override_health(ENVOY, 20.0)
	assert_true(sim._status_instances.has(ENVOY), "sanity: the status really landed")

	sim._apply_floor_effect(RESTORE)

	assert_eq(sim.health_of(ENVOY), MAX_HEALTH)
	assert_eq(sim._shield_meter[ENVOY], 9.0, "the shield meter is exactly where play left it")
	assert_true(sim._status_instances.has(ENVOY), "and the effect is not a cleanse")


func test_restoration_at_full_health_still_reports_and_never_lowers() -> void:
	var sim: SimWorld = _sim()
	var events: Array[Event] = sim._apply_floor_effect(RESTORE)
	assert_eq(_of_kind(events, "envoys_restored").size(), 1, "the effect firing is observable on its own")
	assert_eq(sim.health_of(ENVOY), MAX_HEALTH)

	sim.debug_override_health(ENVOY, MAX_HEALTH + 500.0)
	sim._apply_floor_effect(RESTORE)
	assert_eq(sim.health_of(ENVOY), MAX_HEALTH + 500.0, "restoring raises to the ceiling, it never cuts down to it")


## `target_id = -1` MEANS "the party", ON PURPOSE. A restore that names a target is refused
## outright rather than quietly healing everyone anyway.
func test_no_target_is_the_stated_meaning_and_a_target_is_refused() -> void:
	assert_eq(SimWorld.EFFECT_NO_TARGET, -1)
	assert_eq(FloorLayers.NO_TARGET, SimWorld.EFFECT_NO_TARGET, "sim and gen must agree on what 'no target' is")
	assert_eq(int(RESTORE["target_id"]), SimWorld.EFFECT_NO_TARGET)

	var sim: SimWorld = _sim()
	sim.debug_override_health(ENVOY, 12.0)
	var events: Array[Event] = sim._apply_floor_effect({"kind": &"restore_envoy_health", "target_id": ENVOY})
	assert_eq(events.size(), 0, "a targeted restore does nothing and says nothing")
	assert_eq(sim.health_of(ENVOY), 12.0)


## Max health is the REGISTERED value and survives a floor change with the Envoy.
func test_the_ceiling_is_remembered_across_a_floor_change() -> void:
	var sim: SimWorld = _sim()
	sim.debug_override_health(ENVOY, 12.0)
	sim.load_floor(WalkableBounds.new([Rect2(-10.0, -10.0, 20.0, 20.0)] as Array[Rect2]), OFF_PLATE)
	assert_eq(sim.max_health_of(ENVOY), MAX_HEALTH)
	assert_eq(sim.health_of(ENVOY), 12.0, "sanity: arriving heals nothing by itself")


# --- THE EFFECT, REACHED THE REAL WAY: a plate, through tick() -------------------------------

func _sim_with_plate() -> SimWorld:
	var sim: SimWorld = _sim()
	sim.register_trigger(0, &"region_entered", PLATE, -1, true, [RESTORE])
	return sim


func test_stepping_on_the_plate_restores_through_the_tick() -> void:
	var sim: SimWorld = _sim_with_plate()
	sim.debug_override_health(ENVOY, 25.0)
	assert_eq(_of_kind(_tick(sim), "envoys_restored").size(), 0, "nothing happens away from the plate")
	assert_eq(sim.health_of(ENVOY), 25.0)

	sim.entities[ENVOY] = ON_PLATE
	var events: Array[Event] = _tick(sim)
	assert_eq(_of_kind(events, "floor_trigger_fired").size(), 1)
	assert_eq(_of_kind(events, "envoys_restored").size(), 1)
	assert_eq(sim.health_of(ENVOY), MAX_HEALTH)


## ONCE PER VISIT (ruled). Standing still, stepping off and back on, and being hurt again in
## between all leave the plate spent.
func test_the_plate_cannot_be_used_twice_in_one_visit() -> void:
	var sim: SimWorld = _sim_with_plate()
	sim.entities[ENVOY] = ON_PLATE
	_tick(sim)

	sim.debug_override_health(ENVOY, 10.0)
	for i in 30:
		assert_eq(_of_kind(_tick(sim), "envoys_restored").size(), 0, "standing on a spent plate")
	sim.entities[ENVOY] = OFF_PLATE
	_tick(sim)
	sim.entities[ENVOY] = ON_PLATE
	assert_eq(_of_kind(_tick(sim), "envoys_restored").size(), 0, "stepping off and back on")
	assert_eq(sim.health_of(ENVOY), 10.0, "the wound taken after recovery stays")


## A visit is a floor load: the fired-trigger record is floor state, so the next visit is fresh.
func test_a_new_visit_is_a_new_opportunity() -> void:
	var sim: SimWorld = _sim_with_plate()
	sim.entities[ENVOY] = ON_PLATE
	_tick(sim)
	sim.debug_override_health(ENVOY, 10.0)

	var floor_rects: Array[Rect2] = [Rect2(-10.0, -10.0, 20.0, 20.0)]
	sim.load_floor(WalkableBounds.new(floor_rects), OFF_PLATE)
	sim.register_patches(floor_rects)
	sim.register_trigger(0, &"region_entered", PLATE, -1, true, [RESTORE])
	sim.entities[ENVOY] = ON_PLATE
	assert_eq(_of_kind(_tick(sim), "envoys_restored").size(), 1)
	assert_eq(sim.health_of(ENVOY), MAX_HEALTH)


# --- THE CONTENT -----------------------------------------------------------------------------

func _plan() -> FloorPlan:
	return DepthGenerator.generate(0, TERMINAL_DEPTH)


func _effects_of_kind(plan: FloorPlan, kind: StringName) -> Array:
	var found: Array = []
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect["kind"] == kind:
				found.append({"trigger": trigger, "effect": effect})
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		for effect: Dictionary in hit_switch.effects:
			if effect["kind"] == kind:
				found.append({"trigger": null, "effect": effect})
	return found


## GUARANTEED SAFETY, as a list of everything that would break it. Returned rather than asserted
## so the test below can prove this check is able to fail.
func _safety_violations(plan: FloorPlan) -> Array[String]:
	var violations: Array[String] = []
	if not plan.encounters.is_empty():
		violations.append("%d encounter site(s)" % plan.encounters.size())
	if not plan.all_spawns().is_empty():
		violations.append("%d spawn(s)" % plan.all_spawns().size())
	if not plan.spike_pads.is_empty():
		violations.append("%d spike pad(s)" % plan.spike_pads.size())
	if not _effects_of_kind(plan, FloorLayers.EFFECT_ACTIVATE_ENCOUNTER).is_empty():
		violations.append("an effect that starts a fight")
	for connection: TraversalConnection in plan.connections:
		if not connection.starts_open:
			violations.append("connection %d starts closed" % connection.connection_id)
	if not _effects_of_kind(plan, FloorLayers.EFFECT_BLOCK_CONNECTION).is_empty():
		violations.append("an effect that seals a route")
	return violations


func test_the_terminal_is_safe_by_construction() -> void:
	assert_eq(_safety_violations(_plan()), [] as Array[String],
		"a Terminal holds nothing that can hurt or trap the party")


func test_the_safety_check_can_actually_fail() -> void:
	var with_pad: FloorPlan = _plan()
	with_pad.spike_pads.append(SpikePadPlan.new())
	assert_eq(_safety_violations(with_pad).size(), 1, "a hazard is noticed")

	var with_fight: FloorPlan = _plan()
	var site := EncounterSite.new()
	site.roster = [{"enemy_key": &"fang", "position": Vector3(0.0, 0.0, -19.0)}] as Array[Dictionary]
	with_fight.encounters.append(site)
	assert_eq(_safety_violations(with_fight).size(), 2, "and so is a roster")

	var with_gate: FloorPlan = _plan()
	with_gate.connections[0].starts_open = false
	assert_eq(_safety_violations(with_gate).size(), 1, "and so is a shut door")


func test_the_terminal_offers_exactly_one_recovery_and_one_way_out() -> void:
	var plan: FloorPlan = _plan()
	var recoveries: Array = _effects_of_kind(plan, FloorLayers.EFFECT_RESTORE_ENVOY_HEALTH)
	assert_eq(recoveries.size(), 1)
	var recovery: FloorTrigger = recoveries[0]["trigger"]
	assert_eq(int(recoveries[0]["effect"]["target_id"]), FloorLayers.NO_TARGET, "authored as party-wide, explicitly")
	assert_eq(recovery.kind, FloorLayers.TRIGGER_REGION, "any one Envoy reaching it restores the party")
	assert_true(recovery.once, "once per visit")
	assert_true(recovery.starts_enabled, "available on arrival, with nothing to earn first")
	assert_true(recovery.renders_as_plate, "and somewhere the player can see")

	var exits: Array = _effects_of_kind(plan, FloorLayers.EFFECT_COMPLETE_FLOOR)
	assert_eq(exits.size(), 1)
	var exit_trigger: FloorTrigger = exits[0]["trigger"]
	assert_eq(exit_trigger.kind, FloorLayers.TRIGGER_GROUP_OCCUPANCY, "leaving asks the whole party, like every floor")
	assert_true(exit_trigger.renders_as_plate)
	assert_true(WalkableBounds.contains(exit_trigger.region, plan.end_marker.x, plan.end_marker.z))
	assert_false(recovery.region.intersects(exit_trigger.region), "recovering and leaving are two different steps")


func test_the_terminal_is_walkable_from_arrival_to_exit() -> void:
	var plan: FloorPlan = _plan()
	var bounds: WalkableBounds = plan.make_bounds()
	assert_true(bounds.is_inside(plan.entry_point))
	assert_true(bounds.is_inside(plan.end_marker), "nothing has to be opened to reach the way out")
	for connection: TraversalConnection in plan.connections:
		for patch_id: int in [connection.patch_ids.x, connection.patch_ids.y]:
			assert_gt(connection.aperture.intersection(plan.patch_by_id(patch_id).rect).get_area(), 0.0,
				"aperture %d only abuts patch %d" % [connection.connection_id, patch_id])


## ITS OWN IDENTITY (ruled). The name is authored on the place; the stratum is a borrowed config
## and the depth is where it happens to sit today. Neither is what it is called.
func test_the_terminal_is_named_by_itself_not_by_where_it_sits() -> void:
	var plan: FloorPlan = _plan()
	assert_eq(plan.place_label, "Terminal")
	assert_eq(TERMINAL.place_label, "Terminal", "authored on the layout")
	assert_eq(plan.depth, TERMINAL_DEPTH)
	assert_eq(String(plan.stratum_id), "archive", "the v1 stratum association is technical only")
	assert_false(String(TERMINAL.layout_id).contains("archive"), "and is not part of the place's identity")
	for depth: int in [1, 2]:
		assert_eq(DepthGenerator.generate(0, depth).place_label, "", "an ordinary floor is known by its stratum")


## The Terminal took ONE depth, and the Foundry later took depth 4 (test_floor4.gd). Every other
## depth resolves exactly as it did before either existed.
func test_only_the_terminals_depth_resolves_to_the_terminal() -> void:
	var floor_one: int = DepthGenerator.generate(0, 1).patches.size()
	var floor_two: int = DepthGenerator.generate(0, 2).patches.size()
	assert_ne(floor_one, floor_two, "sanity: the two Archive floors are distinguishable")
	assert_eq(_plan().patches.size(), TERMINAL.patches.size())
	for depth: int in [5, 9]:
		assert_eq(DepthGenerator.generate(0, depth).patches.size(), floor_two, "depth %d is unchanged" % depth)
		assert_eq(DepthGenerator.generate(0, depth).place_label, "")


# --- THE VISIT -------------------------------------------------------------------------------

func _boot(depths: Array[int]) -> Node3D:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.itinerary = depths
	add_child_autofree(arena)
	return arena


func _move(arena: Node3D, direction: Vector3) -> void:
	arena._step([Command.new(arena.sim.tick_count, arena.envoy.actor_id, "move", {"direction": direction})] as Array[Command], DT)


func _walk_to(arena: Node3D, target: Vector3, reach: float = 0.6, max_ticks: int = 2000) -> bool:
	for i in max_ticks:
		var offset: Vector3 = target - arena.sim.entities[arena.envoy.actor_id]
		offset.y = 0.0
		if offset.length() < reach:
			return true
		_move(arena, offset.normalized())
	return false


func _centre(region: Rect2) -> Vector3:
	return Vector3(region.get_center().x, 0.0, region.get_center().y)


func _health(arena: Node3D) -> float:
	return arena.sim.health_of(arena.envoy.actor_id)


func _complete_the_floor(arena: Node3D) -> void:
	arena._report_events([Event.new(arena.sim.tick_count, "floor_complete", {})] as Array[Event])
	arena._resolve_floor_complete()


func test_a_terminal_visit_restores_once_and_lets_the_party_leave() -> void:
	var arena: Node3D = _boot([TERMINAL_DEPTH] as Array[int])
	var full: float = arena.envoy.stats.max_health
	assert_eq(arena._enemies.size(), 0, "nothing lives here")
	arena.sim.debug_override_health(arena.envoy.actor_id, full * 0.25)
	_move(arena, Vector3.ZERO)
	assert_true(arena._seed_label.text.contains("HP %.0f/%.0f" % [full * 0.25, full]),
		"the HUD shows the wound, got '%s'" % arena._seed_label.text)
	assert_true(arena._seed_label.text.contains("Terminal"), "and names the place, got '%s'" % arena._seed_label.text)

	var plate: Vector3 = _centre(TERMINAL.region_for(&"T_RECOVERY"))
	assert_true(_walk_to(arena, plate), "the plate is reachable from arrival")
	assert_eq(_health(arena), full)
	assert_true(arena._seed_label.text.contains("HP %.0f/%.0f" % [full, full]),
		"and the HUD shows the recovery, got '%s'" % arena._seed_label.text)

	# Hurt again, leave the plate, come back: the visit's one recovery is spent.
	arena.sim.debug_override_health(arena.envoy.actor_id, full * 0.5)
	assert_true(_walk_to(arena, plate + Vector3(6.0, 0.0, 0.0)))
	assert_true(_walk_to(arena, plate))
	assert_eq(_health(arena), full * 0.5, "a second step restores nothing")

	var way_out: Vector3 = _centre(TERMINAL.region_for(&"T_EXIT"))
	for i in 1500:
		if arena.expedition.is_complete:
			break
		_move(arena, (way_out - arena.sim.entities[arena.envoy.actor_id]).normalized())
	assert_true(arena.expedition.is_complete, "standing on the exit finishes the floor")


## A long wait in a Terminal costs nothing. FIXED window, per the repo's own trap list.
func test_waiting_in_a_terminal_never_costs_health() -> void:
	var arena: Node3D = _boot([TERMINAL_DEPTH] as Array[int])
	var before: float = _health(arena)
	var started: int = arena.sim.tick_count
	for i in 600:
		arena._step([] as Array[Command], DT)
	assert_eq(arena.sim.tick_count, started + 600, "sanity: the world really ran")
	assert_eq(_health(arena), before)


## THE QA ROUTE [1, 3, 2] -- a playtest arrangement, NOT production order (ruled). It exists to
## show recovery mattering: restored health is carried into a real combat floor.
func test_restored_health_carries_into_the_next_combat_floor() -> void:
	var arena: Node3D = _boot([1, TERMINAL_DEPTH, 2] as Array[int])
	var envoy_id: int = arena.envoy.actor_id
	var full: float = arena.envoy.stats.max_health
	arena.sim.debug_override_health(envoy_id, full * 0.2)
	arena.sim._apply_status(envoy_id, &"burn", "test", envoy_id, "test_bite")
	arena.sim._shield_meter[envoy_id] = arena.sim._shield_meter[envoy_id] * 0.5
	var shield: float = arena.sim._shield_meter[envoy_id]
	assert_true(arena.sim._status_instances.has(envoy_id), "sanity: burning when Floor 1 is completed")
	_complete_the_floor(arena)

	assert_eq(arena.expedition.current_depth(), TERMINAL_DEPTH)
	assert_false(arena.sim._status_instances.has(envoy_id), "the status ended with the floor, before any recovery")
	assert_eq(_health(arena), full * 0.2, "and arriving restored nothing by itself")
	assert_eq(arena.sim._shield_meter[envoy_id], shield, "nor touched the shield")

	assert_true(_walk_to(arena, _centre(TERMINAL.region_for(&"T_RECOVERY"))))
	assert_eq(_health(arena), full)
	_complete_the_floor(arena)

	assert_eq(arena.expedition.current_depth(), 2)
	assert_gt(arena._enemies.size(), 0, "sanity: this is a floor with a fight on it")
	assert_eq(_health(arena), full, "the recovery is what the party fights with")
	assert_false(arena.expedition.is_complete)


## STATUSES END AT FLOOR COMPLETION (ruled 2026-10-12) -- in the sim, in the completing tick, and
## reported. Proved on a bare SimWorld with NO load_floor after it, so the next floor's arrival
## cannot be what did the clearing.
func test_completing_a_floor_clears_every_status_and_says_so() -> void:
	var sim: SimWorld = _sim([ENVOY, ALLY])
	sim.register_status(&"burn", 1.0, 1, 90)
	sim._apply_status(ALLY, &"burn", "test", ALLY, "test_bite")
	sim._apply_status(ENVOY, &"burn", "test", ENVOY, "test_bite")
	_tick(sim)  # past the application-tick grace: from here Burn bites every tick
	var burning: float = sim.health_of(ENVOY)
	assert_gt(_of_kind(_tick(sim), "status_resolved").size(), 0, "sanity: Burn is live before completion")
	assert_lt(sim.health_of(ENVOY), burning, "sanity: and it costs health")

	var at_completion: float = sim.health_of(ENVOY)
	sim._apply_floor_effect({"kind": &"complete_floor", "target_id": -1})
	var events: Array[Event] = _tick(sim)

	assert_false(sim._status_instances.has(ENVOY))
	assert_false(sim._status_instances.has(ALLY))
	assert_eq(sim.health_of(ENVOY), at_completion, "not one more bite, not even in the completing tick")
	assert_eq(_of_kind(events, "status_resolved").size(), 0)
	var cleared: Array = _of_kind(events, "status_cleared")
	assert_eq(cleared.size(), 2)
	assert_eq(cleared[0].payload, {"actor_id": ENVOY, "status_id": "burn", "reason": "floor_complete"})
	assert_eq(cleared[1].payload["actor_id"], ALLY, "deterministic order, never Dictionary order")
	assert_eq(_of_kind(_tick(sim), "status_cleared").size(), 0, "reported once, not every tick after")


## A standing rule while the floor stays complete, not a one-shot: anything that lands afterwards
## (a later elevator/confirm state would allow it) is cleared before it can resolve.
func test_a_status_applied_after_completion_never_resolves() -> void:
	var sim: SimWorld = _sim()
	sim.register_status(&"burn", 1.0, 1, 90)
	sim._apply_floor_effect({"kind": &"complete_floor", "target_id": -1})
	_tick(sim)
	sim._apply_status(ENVOY, &"burn", "test", ENVOY, "test_bite")
	for i in 5:
		assert_eq(_of_kind(_tick(sim), "status_resolved").size(), 0)
	assert_eq(sim.health_of(ENVOY), MAX_HEALTH)
	assert_false(sim._status_instances.has(ENVOY))


## The rule does nothing at all until the floor is completed.
func test_statuses_are_untouched_on_a_floor_still_in_play() -> void:
	var sim: SimWorld = _sim()
	sim.register_status(&"burn", 1.0, 1, 90)
	sim._apply_status(ENVOY, &"burn", "test", ENVOY, "test_bite")
	for i in 5:
		assert_eq(_of_kind(_tick(sim), "status_cleared").size(), 0)
	assert_true(sim._status_instances.has(ENVOY))


## THE END OF A RUN. No floor follows the last one, so load_floor cannot be what cleanses here:
## the status is gone because the floor was completed, and the stopped world never brings it back.
func test_a_status_carried_into_the_final_completion_is_cleared_with_it() -> void:
	var arena: Node3D = _boot([TERMINAL_DEPTH] as Array[int])
	var envoy_id: int = arena.envoy.actor_id
	# Walked, not faked: the sim's own completion is the thing under test. Burn is applied at the
	# plate's edge so it cannot simply run out on the way there.
	var exit_plate: Rect2 = TERMINAL.region_for(&"T_EXIT")
	assert_true(_walk_to(arena, Vector3(exit_plate.get_center().x, 0.0, exit_plate.end.y + 1.5)))
	arena.sim._apply_status(envoy_id, &"burn", "test", envoy_id, "test_bite")
	assert_true(arena.sim._status_instances.has(envoy_id), "sanity: burning as the party reaches the exit")
	_walk_to(arena, _centre(exit_plate), 0.6, 120)  # the world stops on completion, short of the centre
	assert_true(arena.expedition.is_complete)
	assert_false(arena.sim._status_instances.has(envoy_id), "cleared by completion itself -- nothing loaded after")

	var at_completion: float = _health(arena)
	for i in 300:
		arena._step([] as Array[Command], DT)
	assert_eq(_health(arena), at_completion, "a completed expedition takes no more damage from anything")
	assert_false(arena._failure_overlay.visible)
