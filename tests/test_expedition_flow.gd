extends GutTest
## THE EXPEDITION, through the real arena and the real driver step.
##
##   begin -> Floor 1 -> descent -> Floor 2 -> descent -> Terminal -> descent -> Foundry ->
##   expedition complete
##   (and failure, restart). Tests about the LAST floor name their own itinerary, so they keep
##   meaning what they say when the shipped run grows.
##
## test_floor_scope.gd already proves what SimWorld.load_floor keeps and drops. What nothing
## proved before this file is the DRIVER: that a completion actually leads somewhere, that the
## presentation half of a floor load survives being run a second time, and that the run ends.
##
## EVERY STEP GOES THROUGH arena._step(), never sim.tick() directly. The other arena tests tick
## the sim themselves, which skips event reporting and transition resolution -- exactly the
## code under test here.
##
## Most tests INJECT the floor_complete Event rather than walking a whole floor to earn it:
## they are about what the driver does with a completion, not about reaching one. One test at
## the bottom earns both completions the real way, end to end.

const DT := 1.0 / 30.0
const FLOOR_ONE = preload("res://game/content/layouts/archive_prototype.tres")
const FLOOR_TWO = preload("res://game/content/layouts/archive_roundabout.tres")
const TERMINAL = preload("res://game/content/layouts/terminal.tres")
const FOUNDRY = preload("res://game/content/layouts/foundry_assembly.tres")


## A retired floor's nodes are queue_free()d, which only lands at the end of a frame. Without
## this every descent in this file would be reported as that many orphans.
func after_each() -> void:
	await get_tree().process_frame


func _boot(depths: Array[int] = []) -> Node3D:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	# An empty argument means "whatever the shipped scene says" -- which is itself under test.
	if not depths.is_empty():
		arena.itinerary = depths
	add_child_autofree(arena)
	return arena


func _envoy(arena: Node3D) -> int:
	return arena.envoy.actor_id


func _idle(arena: Node3D, ticks: int) -> void:
	for i in ticks:
		arena._step([] as Array[Command], DT)


func _move(arena: Node3D, direction: Vector3) -> void:
	arena._step([Command.new(arena.sim.tick_count, _envoy(arena), "move", {"direction": direction})] as Array[Command], DT)


## One driver step's worth of reporting + resolution for a hand-built batch.
func _deliver(arena: Node3D, kinds: Array) -> void:
	var batch: Array[Event] = []
	for kind: String in kinds:
		var payload: Dictionary = {"actor_id": _envoy(arena)} if kind == "died" else {}
		batch.append(Event.new(arena.sim.tick_count, kind, payload))
	arena._report_events(batch)
	arena._resolve_floor_complete()


## Completes the floor and rides the whole descent, landing on the far side of it. Tests about
## the descent window itself use _deliver and step it by hand.
func _complete_the_floor(arena: Node3D) -> void:
	_deliver(arena, ["floor_complete"])
	_ride(arena)


## The descent's fixed window, one driver step per sim-rate tick. Idling is the honest input: a
## descent ignores whatever is sent, so nothing richer could change the result.
func _ride(arena: Node3D) -> void:
	_idle(arena, arena.descent_ticks)


func _plan(depth: int) -> FloorPlan:
	return DepthGenerator.generate(0, depth)


func _roster_size(depth: int) -> int:
	return _plan(depth).all_spawns().size()


func _health(arena: Node3D) -> float:
	return arena.sim._health[_envoy(arena)]


# --- BEGIN ---------------------------------------------------------------------------------

## THE SHIPPED SCENE, with nothing overridden: this is what boot and restart both produce.
func test_the_boot_scene_begins_the_shipped_expedition_on_floor_one() -> void:
	var arena: Node3D = _boot()
	assert_eq(arena.expedition.itinerary, [1, 2, 3, 4] as Array[int], "the shipped expedition is Archive 1, Archive 2, the Terminal, then the Foundry")
	assert_eq(arena.expedition.position, 0)
	assert_eq(arena.expedition.current_depth(), 1)
	assert_false(arena.expedition.is_complete)
	assert_eq(arena.sim._patch_rects.size(), _plan(1).patches.size(), "and Floor 1 is what is loaded")
	assert_true(arena._seed_label.text.contains("depth 1"), "the HUD names the depth, got '%s'" % arena._seed_label.text)
	assert_true(arena._seed_label.text.contains("floor 1/4"), "and the position in the run, got '%s'" % arena._seed_label.text)
	assert_false(arena._arrival_card.visible, "beginning is not arriving from a descent")
	assert_false(arena._completion_overlay.visible)
	assert_false(arena._failure_overlay.visible)


## The expedition, not the node, is the authority: the node's export is only what it was begun
## with.
func test_the_expedition_owns_its_itinerary_after_beginning() -> void:
	var arena: Node3D = _boot()
	arena.itinerary.append(7)
	assert_eq(arena.expedition.itinerary, [1, 2, 3, 4] as Array[int],
		"editing the node's configuration mid-run must not rewrite the run")


# --- DESCENT -------------------------------------------------------------------------------

func test_completing_a_floor_with_an_entry_left_descends() -> void:
	var arena: Node3D = _boot()
	var ticks_before: int = arena.sim.tick_count
	_idle(arena, 5)
	_complete_the_floor(arena)

	assert_eq(arena.expedition.position, 1)
	assert_eq(arena.expedition.current_depth(), 2)
	assert_false(arena.expedition.is_complete)
	assert_eq(arena.sim._patch_rects.size(), _plan(2).patches.size(), "Floor 2's geometry is the sim's law now")
	assert_eq(arena.sim.entities[_envoy(arena)], _plan(2).entry_point, "the Envoy arrives at Floor 2's entry")
	assert_eq(arena.envoy.position.x, _plan(2).entry_point.x, "and so does the Envoy the player sees")
	assert_eq(arena.envoy.position.z, _plan(2).entry_point.z)
	assert_false(arena.sim.debug_describe_floor()["floor_complete"], "the new floor is not yet complete")
	assert_eq(arena.sim.tick_count, ticks_before + 5, "the run clock carries straight on")
	assert_true(arena._seed_label.text.contains("depth 2"), "got '%s'" % arena._seed_label.text)
	assert_true(arena._seed_label.text.contains("floor 2/4"), "got '%s'" % arena._seed_label.text)
	assert_true(arena._arrival_card.visible, "the arrival is announced")
	assert_false(arena._completion_overlay.visible, "a descent is not the end of the run")


func test_health_equipment_and_shield_survive_the_descent() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = _envoy(arena)
	# The shipped switch, the shipped way: the sword is equipped first, the wand second.
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "switch_weapon", {})] as Array[Command], DT)
	arena.sim.debug_override_health(envoy_id, 11.0)
	arena.sim._shield_meter[envoy_id] = arena.sim._shield_meter[envoy_id] * 0.5
	var equipped: StringName = arena.sim._equipped_weapon[envoy_id]
	var shield: float = arena.sim._shield_meter[envoy_id]
	var loadout: Array = arena.sim._weapon_loadouts[envoy_id].duplicate()
	assert_ne(equipped, arena.loadout_weapon_ids[0], "sanity: the switch really changed the weapon")

	_complete_the_floor(arena)

	assert_eq(_health(arena), 11.0, "a descent neither heals nor harms")
	assert_eq(arena.sim._equipped_weapon[envoy_id], equipped, "the weapon in hand stays in hand")
	assert_eq(arena.sim._weapon_loadouts[envoy_id], loadout, "with the whole loadout behind it")
	assert_eq(arena.sim._shield_meter[envoy_id], shield, "and the shield is neither refilled nor emptied")


func test_the_departing_floor_leaves_nothing_behind() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = _envoy(arena)
	_idle(arena, 2)
	var old_enemy_ids: Array = arena._enemies.keys()
	var old_nodes: Array = arena._floor_builder.get_children()
	assert_gt(old_enemy_ids.size(), 0, "sanity: Floor 1 has a roster to leave behind")

	# A shot in flight, a lit charge indicator and a status: one of each kind of leftover.
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "switch_weapon", {})] as Array[Command], DT)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	assert_gt(arena._projectile_tracers.size(), 0, "sanity: a tracer is in the air")
	arena.envoy.show_charge_ready(Color.RED)

	_complete_the_floor(arena)

	assert_eq(arena._projectile_tracers.size(), 0, "no tracer flies on into the next floor")
	assert_eq(arena.sim._projectiles.size(), 0, "because no projectile does")
	assert_eq(arena._windup_cues.size(), 0)
	assert_false(arena.envoy._telegraph.visible, "an indicator lit on the old floor is put out")
	for old_node: Node in old_nodes:
		assert_true(old_node.is_queued_for_deletion() or old_node.get_parent() == null,
			"'%s' belonged to Floor 1 and must not be standing on Floor 2" % old_node.name)
	for old_id: int in old_enemy_ids:
		assert_false(arena._enemies.has(old_id), "enemy %d did not follow the party down" % old_id)
		assert_false(arena.sim.entities.has(old_id), "in the picture or in the sim")
	# And they are really gone once the frame ends, not merely detached and leaking.
	await get_tree().process_frame
	await get_tree().process_frame
	for old_node: Variant in old_nodes:
		assert_false(is_instance_valid(old_node), "a Floor 1 node outlived the frame it was retired in")


func test_the_new_floor_is_fully_populated_with_fresh_actors() -> void:
	var arena: Node3D = _boot()
	var highest_old_id: int = int(arena._enemies.keys().max())
	_complete_the_floor(arena)

	assert_eq(arena._enemies.size(), _roster_size(2), "every enemy Floor 2 authors is standing on it")
	for actor_id: int in arena._enemies.keys():
		assert_gt(actor_id, highest_old_id, "an actor id is never reused within a run")
		assert_true(arena.sim.entities.has(actor_id), "and each one is real in the sim")
		assert_true(is_instance_valid(arena._enemies[actor_id]))
	# The second build must not have stacked onto the first.
	var live_children: int = 0
	for child: Node in arena._floor_builder.get_children():
		if not child.is_queued_for_deletion():
			live_children += 1
	var fresh: Node3D = _boot([2] as Array[int])
	assert_eq(live_children, fresh._floor_builder.get_child_count(),
		"arriving on Floor 2 builds exactly what booting on Floor 2 builds")


## NON-BLOCKING AND SAFE (ruled): nothing unavoidable may hurt the party on arrival, and the
## card must never cost them control. Measured over a FIXED window -- the card's own lifetime
## and then some -- rather than until something happens.
func test_arrival_is_safe_and_leaves_the_player_in_control() -> void:
	var arena: Node3D = _boot()
	_complete_the_floor(arena)
	var before: float = _health(arena)
	var window: int = int(ceil(arena._arrival_card.display_seconds / DT)) + 60
	var started: int = arena.sim.tick_count
	_idle(arena, window)
	assert_eq(arena.sim.tick_count, started + window, "the sim never paused for the card")
	assert_eq(_health(arena), before, "standing still on arrival for %d ticks cost health" % window)

	var entry: Vector3 = arena.sim.entities[_envoy(arena)]
	assert_eq(arena.expedition.position, 1, "sanity: waiting advanced nothing")
	for i in 10:
		_move(arena, Vector3(0, 0, -1))
	assert_ne(arena.sim.entities[_envoy(arena)], entry, "a move Command moves the Envoy")


## Control is also live on the very FIRST tick after a descent, while the card is up.
func test_control_is_live_while_the_card_is_showing() -> void:
	var arena: Node3D = _boot()
	_complete_the_floor(arena)
	var entry: Vector3 = arena.sim.entities[_envoy(arena)]
	var moved: bool = false
	for direction: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
		_move(arena, direction)
		if arena.sim.entities[_envoy(arena)] != entry:
			moved = true
			break
	assert_true(arena._arrival_card.visible, "sanity: the card is still up")
	assert_true(moved, "and the Envoy answered input underneath it")


# --- ORDERING ------------------------------------------------------------------------------

## The floor must not change while the batch that announced its completion is still being
## reported -- the rest of that batch names actors of the floor being left.
func test_nothing_changes_until_the_whole_batch_is_reported() -> void:
	var arena: Node3D = _boot()
	var batch: Array[Event] = [Event.new(arena.sim.tick_count, "floor_complete", {})]
	arena._report_events(batch)
	assert_eq(arena.expedition.position, 0, "reporting a completion is not acting on it")
	assert_eq(arena.sim._patch_rects.size(), _plan(1).patches.size(), "Floor 1 is still loaded")
	arena._resolve_floor_complete()
	assert_eq(arena.expedition.phase, Expedition.PHASE_DESCENDING, "resolution is what begins the descent")
	_ride(arena)
	assert_eq(arena.expedition.position, 1, "and riding it out is what arrives")


func test_a_duplicated_completion_cannot_skip_a_floor() -> void:
	var arena: Node3D = _boot([1, 2, 2] as Array[int])
	_deliver(arena, ["floor_complete", "floor_complete", "floor_complete"])
	assert_eq(arena.expedition.phase, Expedition.PHASE_DESCENDING)
	_ride(arena)
	assert_eq(arena.expedition.position, 1, "three completions in one batch are one descent")
	assert_false(arena.expedition.is_complete)
	arena._resolve_floor_complete()
	arena._resolve_floor_complete()
	assert_eq(arena.expedition.position, 1, "and resolving again with nothing new does nothing")


## FAILURE WINS (ruled): completing the floor on the tick the Envoy dies is a failed run.
func test_dying_on_the_completing_tick_is_failure_not_descent() -> void:
	for order: Array in [["floor_complete", "died"], ["died", "floor_complete"]]:
		var arena: Node3D = _boot()
		_deliver(arena, order)
		assert_eq(arena.expedition.position, 0, "%s: a dead expedition does not descend" % [order])
		assert_false(arena.expedition.is_complete, "%s: and does not complete" % [order])
		assert_eq(arena.expedition.phase, Expedition.PHASE_EXPLORING, "%s: no descent is begun either" % [order])
		assert_false(arena._descent_overlay.visible, "%s" % [order])
		assert_true(arena._failure_overlay.visible, "%s: it fails" % [order])
		assert_false(arena._arrival_card.visible)
		assert_false(arena._completion_overlay.visible)
		assert_eq(arena.sim._patch_rects.size(), _plan(1).patches.size(), "%s: Floor 1 stays loaded" % [order])
		arena.free()


func test_dying_on_the_final_floor_is_failure_not_completion() -> void:
	var arena: Node3D = _boot([1, 2] as Array[int])
	_complete_the_floor(arena)
	_deliver(arena, ["died"])
	assert_true(arena._failure_overlay.visible)
	# And a completion arriving after death changes nothing.
	_complete_the_floor(arena)
	assert_false(arena.expedition.is_complete, "a failed run is never also a completed one")
	assert_false(arena._completion_overlay.visible)


# --- COMPLETION ----------------------------------------------------------------------------

func test_completing_the_last_entry_completes_the_expedition() -> void:
	var arena: Node3D = _boot([1, 2] as Array[int])
	_complete_the_floor(arena)
	_idle(arena, 3)
	var enemies_before: Array = arena._enemies.keys()
	_complete_the_floor(arena)

	assert_true(arena.expedition.is_complete)
	assert_eq(arena.expedition.position, 1, "it ends on the floor it finished")
	assert_true(arena._completion_overlay.visible, "the run says it is over")
	assert_false(arena._failure_overlay.visible)
	assert_eq(arena._enemies.keys(), enemies_before, "no third floor was loaded")
	assert_eq(arena.sim._patch_rects.size(), _plan(2).patches.size())


## The END state only: a completed expedition's world stops, so nothing can kill the Envoy on
## the completion screen and end the run a second time the other way.
func test_a_completed_expedition_stops_the_world() -> void:
	var arena: Node3D = _boot([2] as Array[int])
	_complete_the_floor(arena)
	var stopped_at: int = arena.sim.tick_count
	var position: Vector3 = arena.sim.entities[_envoy(arena)]
	for i in 30:
		_move(arena, Vector3(1, 0, 0))
	assert_eq(arena.sim.tick_count, stopped_at, "no further tick is simulated")
	assert_eq(arena.sim.entities[_envoy(arena)], position, "and no Command is applied")


func test_a_completed_expedition_cannot_be_completed_again() -> void:
	var arena: Node3D = _boot([2] as Array[int])
	_complete_the_floor(arena)
	_complete_the_floor(arena)
	_complete_the_floor(arena)
	assert_true(arena.expedition.is_complete)
	assert_eq(arena.expedition.position, 0)
	assert_eq(arena.sim._patch_rects.size(), _plan(2).patches.size(), "and nothing was reloaded")


# --- RESTART -------------------------------------------------------------------------------

## Restart is a scene reload (arena.gd), so "restart begins a FRESH expedition" means: a newly
## instantiated arena owes nothing to the one before it. Nothing about a run may live anywhere
## that outlives the scene.
func test_a_restarted_arena_begins_a_fresh_expedition() -> void:
	var first: Node3D = _boot()
	_idle(first, 20)
	first.sim.debug_override_health(_envoy(first), 3.0)
	_complete_the_floor(first)
	assert_eq(first.expedition.position, 1, "sanity: the first run got somewhere")
	first.free()

	var second: Node3D = _boot()
	assert_eq(second.expedition.position, 0, "back to the first entry")
	assert_eq(second.expedition.current_depth(), 1)
	assert_eq(second.expedition.itinerary, [1, 2, 3, 4] as Array[int], "with the whole itinerary ahead")
	assert_false(second.expedition.is_complete)
	assert_eq(_health(second), second.envoy.stats.max_health, "at full health")
	assert_eq(second.sim._equipped_weapon[_envoy(second)], second.loadout_weapon_ids[0], "with the starting weapon")
	assert_eq(second.sim.tick_count, 0, "on a fresh clock")
	assert_eq(second.sim._patch_rects.size(), _plan(1).patches.size(), "on Floor 1")
	assert_false(second._arrival_card.visible)
	assert_true(InputMap.has_action("restart"), "and the action that triggers it still exists")


# --- THE WHOLE THING, EARNED ---------------------------------------------------------------

func _walk_to(arena: Node3D, target: Vector3, reach: float = 1.2, max_ticks: int = 4000) -> bool:
	var envoy_id: int = _envoy(arena)
	for i in max_ticks:
		var offset: Vector3 = target - arena.sim.entities[envoy_id]
		offset.y = 0.0
		if offset.length() < reach:
			return true
		_move(arena, offset.normalized())
	return false


func _centre(region: Rect2) -> Vector3:
	return Vector3(region.get_center().x, 0.0, region.get_center().y)


func _kill(arena: Node3D, roster: Array) -> void:
	for actor_id: int in roster:
		arena.sim.debug_override_health(actor_id, 0.0)
	_idle(arena, 1)


## Floor 1's critical path, as test_floor_walkthrough.gd walks it, but through the driver.
func _play_floor_one_to_its_exit(arena: Node3D) -> void:
	var envoy_id: int = _envoy(arena)
	var plan: FloorPlan = _plan(1)
	assert_true(_walk_to(arena, plan.patch_by_id(FLOOR_ONE.id_for(&"P_HALL_SOUTH")).centre()), "F1: into the hall")
	assert_true(_walk_to(arena, plan.patch_by_id(FLOOR_ONE.id_for(&"P_HALL_WEST")).centre()), "F1: down the west branch")
	var crate: Vector3 = plan.breakables[0].position
	assert_true(_walk_to(arena, crate + Vector3(0.0, 0.0, 1.6)), "F1: to the crate")
	for swing in 12:
		var aim: Vector3 = (crate - arena.sim.entities[envoy_id]).normalized()
		arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "pressed"})] as Array[Command], DT)
		arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "released"})] as Array[Command], DT)
		_idle(arena, 14)
		if arena.sim._breakables.is_empty():
			break
	assert_true(arena.sim._breakables.is_empty(), "F1: the crate breaks")
	assert_true(_walk_to(arena, _centre(FLOOR_ONE.region_for(&"T_HIDDEN_PLATE")), 0.6), "F1: onto the hidden plate")
	assert_true(_walk_to(arena, Vector3(4.5, 0.0, -39.0)), "F1: through the route it opened")
	assert_true(_walk_to(arena, _centre(FLOOR_ONE.region_for(&"T_PARTY_PLATE")), 0.6), "F1: onto the party plate")
	assert_true(_walk_to(arena, plan.patch_by_id(FLOOR_ONE.id_for(&"P_ARENA")).centre()), "F1: into the fight")
	_kill(arena, arena.sim._encounter_roster[FLOOR_ONE.id_for(&"E_ARENA")])
	assert_true(_walk_to(arena, plan.patch_by_id(FLOOR_ONE.id_for(&"P_RAMP")).centre()), "F1: up the ramp")
	assert_true(_walk_to(arena, plan.patch_by_id(FLOOR_ONE.id_for(&"P_HIGH")).centre()), "F1: onto the high ground")


## Floor 2's critical path, as test_floor2.gd walks it (east at the T, no western detour).
func _play_floor_two_to_its_exit(arena: Node3D) -> void:
	for waypoint: Vector3 in [
		Vector3(-46, 0, -36), Vector3(-20, 0, -37), Vector3(-6, 0, -42), Vector3(-2, 0, -50),
		Vector3(14, 0, -62), Vector3(20, 0, -72), Vector3(32, 0, -72), Vector3(22, 0, -62),
		Vector3(22, 0, -76), Vector3(22, 0, -90), Vector3(22, 0, -110),
		Vector3(31, 0, -110), Vector3(50, 0, -114), Vector3(68, 0, -120), Vector3(90, 0, -122),
		Vector3(114, 0, -124), Vector3(136, 0, -128),
	]:
		assert_true(_walk_to(arena, waypoint, 1.4), "F2: to %s" % waypoint)
	arena.sim.debug_activate_hit_switch(FLOOR_TWO.id_for(&"S_WORKS"))
	assert_true(_walk_to(arena, Vector3(156, 0, -136), 1.4), "F2: into the link")
	assert_true(_walk_to(arena, Vector3(178, 0, -140), 1.4), "F2: into the arena")
	assert_true(_walk_to(arena, _centre(FLOOR_TWO.region_for(&"T_PARTY")), 0.3), "F2: onto the party plate")
	_idle(arena, 1)
	for wave: StringName in [&"E_WAVE_1", &"E_WAVE_2", &"E_WAVE_3"]:
		_kill(arena, arena.sim._encounter_roster[FLOOR_TWO.id_for(wave)])
	# Stops short of the exit plate on purpose: stepping onto it is the caller's to observe.
	assert_true(_walk_to(arena, Vector3(230, 0, -138), 1.4), "F2: into the reward hall")


## The Foundry's critical path, as test_floor4.gd walks it: both keys (west first), the gate, the
## connector, the chamber. Stops short of the exit plate.
## One attack click aimed at a world point, the shipped way (pressed then released).
func _click_at(arena: Node3D, point: Vector3) -> void:
	var envoy_id: int = arena.envoy.actor_id
	var aim: Vector3 = point - arena.sim.entities[envoy_id]
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "pressed"})] as Array[Command], DT)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "released"})] as Array[Command], DT)


func _play_floor_four_to_its_exit(arena: Node3D) -> void:
	# Off the raised landing, round the U and down the stairs into the lower access.
	for waypoint: Vector3 in [Vector3(-46, 0, 7.5), Vector3(-34, 0, 7.5), Vector3(-34, 0, -4), Vector3(-34, 0, -9), Vector3(-24, 0, -12)]:
		assert_true(_walk_to(arena, waypoint, 1.0), "F4 access: to %s" % waypoint)
	# Fought, as a player would: a pack that is merely walked past follows into the hub.
	_kill(arena, arena.sim._encounter_roster[FOUNDRY.id_for(&"E_ACCESS")])
	for waypoint: Vector3 in [
		Vector3(-17.5, 0, -21), Vector3(-12.5, 0, -27), Vector3(-12.5, 0, -34),
		Vector3(-16, 0, -38), Vector3(-27, 0, -38), Vector3(-47, 0, -39), Vector3(-47, 0, -44),
		Vector3(-47, 0, -52), Vector3(-47, 0, -62), Vector3(-45, 0, -69),
	]:
		assert_true(_walk_to(arena, waypoint, 1.0), "F4 west: to %s" % waypoint)
	_kill(arena, arena.sim._encounter_roster[FOUNDRY.id_for(&"E_WEST")])
	# The keys are physical (Stage 2): lifted and delivered with the attack press. The west key
	# waits at the far end of the top band; lifting it wakes the return ambush.
	for waypoint: Vector3 in [Vector3(-42, 0, -64), Vector3(-20, 0, -63)]:
		assert_true(_walk_to(arena, waypoint, 1.0), "F4 west: to %s" % waypoint)
	assert_true(_walk_to(arena, Vector3(-14.6, 0, -63), 0.3), "F4: to the west key")
	_click_at(arena, FOUNDRY.carriables[0].position)
	_kill(arena, arena.sim._encounter_roster[FOUNDRY.id_for(&"E_WEST_RETURN")])
	# Home the way in: there is no shortcut from the key to the hub.
	for waypoint: Vector3 in [
		Vector3(-42, 0, -64), Vector3(-47, 0, -62), Vector3(-47, 0, -52), Vector3(-47, 0, -44),
		Vector3(-47, 0, -39), Vector3(-27, 0, -38), Vector3(-16, 0, -38),
	]:
		assert_true(_walk_to(arena, waypoint, 1.0), "F4 west home: to %s" % waypoint)
	assert_true(_walk_to(arena, Vector3(-4, 0, -54.5), 0.3), "F4: to Gate 1's receiver")
	_click_at(arena, Vector3(-4, 0, -57))
	for waypoint: Vector3 in [
		Vector3(8, 0, -40), Vector3(21, 0, -38), Vector3(31, 0, -42), Vector3(41, 0, -42),
	]:
		assert_true(_walk_to(arena, waypoint, 1.0), "F4 east: to %s" % waypoint)
	_kill(arena, arena.sim._encounter_roster[FOUNDRY.id_for(&"E_EAST")])
	assert_true(_walk_to(arena, Vector3(46, 0, -58.6), 0.3), "F4: into the east key bay")
	_click_at(arena, FOUNDRY.carriables[1].position)
	for waypoint: Vector3 in [
		Vector3(47, 0, -50), Vector3(41, 0, -42), Vector3(31, 0, -42), Vector3(21, 0, -38), Vector3(8, 0, -40), Vector3(-4, 0, -54.5),
		Vector3(-4, 0, -62),
	]:
		assert_true(_walk_to(arena, waypoint, 1.0), "F4 to Gate 2: to %s" % waypoint)
	assert_true(_walk_to(arena, Vector3(4, 0, -62.5), 0.3), "F4: to Gate 2's receiver")
	_click_at(arena, Vector3(4, 0, -65))
	assert_true(bool(arena.sim._connection_open[FOUNDRY.id_for(&"C_LOCK_E")]), "F4: both keys delivered")
	for waypoint: Vector3 in [
		Vector3(4, 0, -74), Vector3(11, 0, -74), Vector3(42, 0, -74), Vector3(42, 0, -82),
	]:
		assert_true(_walk_to(arena, waypoint, 1.0), "F4 north: to %s" % waypoint)
	assert_true(_walk_to(arena, _centre(FOUNDRY.region_for(&"T_PARTY")), 0.3), "F4: onto the party plate")
	_idle(arena, 1)
	for wave: StringName in [&"E_WAVE_1", &"E_WAVE_2", &"E_WAVE_3"]:
		_kill(arena, arena.sim._encounter_roster[FOUNDRY.id_for(wave)])
	for waypoint: Vector3 in [
		Vector3(48, 0, -100), Vector3(48, 0, -118), Vector3(42, 0, -121), Vector3(42, 0, -131),
		Vector3(42, 0, -140), Vector3(64, 0, -140),
	]:
		assert_true(_walk_to(arena, waypoint, 1.0), "F4 exit: to %s" % waypoint)


## ONE CONTINUOUS EXPEDITION, every completion earned by standing on the authored exits with
## nothing injected. If this passes, a human can play the run from boot to the completion screen.
func test_a_whole_expedition_plays_from_floor_one_to_completion() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = _envoy(arena)
	# Survivability keeps a TRAVERSAL test measuring traversal. Never a balance claim.
	arena.sim.debug_override_health(envoy_id, 100000.0)

	_play_floor_one_to_its_exit(arena)
	assert_eq(arena.expedition.position, 0, "sanity: reaching the high ground is not finishing")

	# Wounded, wand in hand, half a shield: the state the descent has to carry.
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "switch_weapon", {})] as Array[Command], DT)
	arena.sim.debug_override_health(envoy_id, 80000.0)
	arena.sim._shield_meter[envoy_id] = arena.sim._shield_meter[envoy_id] * 0.5
	var equipped: StringName = arena.sim._equipped_weapon[envoy_id]
	var shield_before: float = arena.sim._shield_meter[envoy_id]
	var floor_one_ticks: int = arena.sim.tick_count

	# Step by step onto the exit, so the state is read on the very tick before the descent.
	var exit_centre: Vector3 = _centre(FLOOR_ONE.region_for(&"T_EXIT_PLATE"))
	var health_before: float = _health(arena)
	for i in 1500:
		if arena.expedition.position == 1:
			break
		health_before = _health(arena)
		shield_before = arena.sim._shield_meter[envoy_id]
		var offset: Vector3 = exit_centre - arena.sim.entities[envoy_id]
		_move(arena, offset.normalized())

	assert_eq(arena.expedition.position, 1, "standing on Floor 1's exit descends")
	assert_eq(arena.expedition.current_depth(), 2)
	assert_eq(arena.sim.entities[envoy_id], _plan(2).entry_point, "arriving at Floor 2's entry")
	assert_eq(_health(arena), health_before, "with the health the party left with")
	assert_eq(arena.sim._shield_meter[envoy_id], shield_before, "the shield they left with")
	assert_eq(arena.sim._equipped_weapon[envoy_id], equipped, "and the weapon they were holding")
	assert_gt(arena.sim.tick_count, floor_one_ticks, "on the same clock")
	assert_eq(arena._enemies.size(), _roster_size(2), "onto a fully populated Floor 2")
	assert_true(arena._arrival_card.visible)

	# Arrival on the REAL run clock, which is what decides the spike pads' phase.
	var window: int = int(ceil(arena._arrival_card.display_seconds / DT)) + 60
	var on_arrival: float = _health(arena)
	_idle(arena, window)
	assert_eq(_health(arena), on_arrival, "standing still on a real arrival for %d ticks cost health" % window)

	arena.sim.debug_override_health(envoy_id, 100000.0)
	_play_floor_two_to_its_exit(arena)
	assert_false(arena.expedition.is_complete, "sanity: reaching the reward hall is not finishing")
	# Not _walk_to: the world stops the moment the plate is occupied, short of its centre.
	var floor_two_exit: Vector3 = _centre(FLOOR_TWO.region_for(&"T_EXIT"))
	for i in 1500:
		if arena.expedition.position == 2:
			break
		_move(arena, (floor_two_exit - arena.sim.entities[envoy_id]).normalized())

	assert_eq(arena.expedition.position, 2, "standing on Floor 2's exit descends to the Terminal")
	assert_false(arena.expedition.is_complete)
	assert_eq(arena._enemies.size(), 0, "where nothing is waiting for the party")
	assert_true(arena._arrival_card._label.text.contains("Terminal"), "and the arrival names the place, got '%s'" % arena._arrival_card._label.text)

	# Hurt on arrival, restored by the plate, and only then out through the exit.
	arena.sim.debug_override_health(envoy_id, 7.0)
	assert_true(_walk_to(arena, _centre(TERMINAL.region_for(&"T_RECOVERY")), 0.6), "T: onto the recovery plate")
	assert_eq(_health(arena), arena.envoy.stats.max_health, "the Terminal restores the Envoy to full")
	var terminal_exit: Vector3 = _centre(TERMINAL.region_for(&"T_EXIT"))
	for i in 1500:
		if arena.expedition.position == 3:
			break
		_move(arena, (terminal_exit - arena.sim.entities[envoy_id]).normalized())

	assert_eq(arena.expedition.position, 3, "standing on the Terminal's exit descends into the Foundry")
	assert_false(arena.expedition.is_complete, "the Terminal is no longer where the run ends")
	assert_eq(arena.expedition.current_depth(), 4)
	assert_eq(arena.sim.entities[envoy_id], _plan(4).entry_point, "arriving at the Foundry's entry")
	assert_eq(_health(arena), arena.envoy.stats.max_health, "with the health the Terminal restored")
	assert_true(arena._arrival_card._label.text.contains("Foundry"), "and the arrival names the stratum, got '%s'" % arena._arrival_card._label.text)
	assert_true(arena._seed_label.text.contains("floor 4/4"), "got '%s'" % arena._seed_label.text)

	# Arrival on the REAL run clock again: the Foundry's lanes are phased by it too.
	var foundry_arrival: float = _health(arena)
	_idle(arena, window)
	assert_eq(_health(arena), foundry_arrival, "standing still on the Foundry's arrival for %d ticks cost health" % window)

	arena.sim.debug_override_health(envoy_id, 100000.0)
	_play_floor_four_to_its_exit(arena)
	assert_false(arena.expedition.is_complete, "sanity: reaching the output run is not finishing")
	var final_exit: Vector3 = _centre(FOUNDRY.region_for(&"T_EXIT"))
	for i in 1500:
		if arena.expedition.is_complete:
			break
		_move(arena, (final_exit - arena.sim.entities[envoy_id]).normalized())

	assert_true(arena.expedition.is_complete, "standing on the Foundry's exit completes the expedition")
	assert_true(arena._completion_overlay.visible)
	assert_false(arena._failure_overlay.visible)
	var stopped_at: int = arena.sim.tick_count
	_idle(arena, 30)
	assert_eq(arena.sim.tick_count, stopped_at, "and the world stops with it")


# --- THE DESCENT (M2 expedition frame, Slice 1) --------------------------------------------

## Every input the Envoy can send, for a tick that is supposed to ignore all of them.
func _everything(arena: Node3D, phase: String) -> Array[Command]:
	var envoy_id: int = _envoy(arena)
	var tick: int = arena.sim.tick_count
	return [
		Command.new(tick, envoy_id, "move", {"direction": Vector3(1, 0, 0)}),
		Command.new(tick, envoy_id, "attack", {"aim": Vector3(0, 0, -1), "phase": phase}),
		Command.new(tick, envoy_id, "block", {"held": true}),
		Command.new(tick, envoy_id, "switch_weapon", {}),
	] as Array[Command]


## The families a plan fields, most numerous first, ties by name -- derived here from the plan
## alone, so the arena's preview is checked against the content rather than against itself.
func _expected_families(plan: FloorPlan) -> Array:
	var counts: Dictionary = {}
	for spawn: Dictionary in plan.all_spawns():
		var family: StringName = ContentDB.get_resource(&"enemy", spawn["enemy_key"]).family
		counts[family] = int(counts.get(family, 0)) + 1
	var families: Array = counts.keys()
	families.sort_custom(func(a: StringName, b: StringName) -> bool:
		return counts[a] > counts[b] or (counts[a] == counts[b] and String(a) < String(b)))
	return families


## THE DESTINATION IS RESOLVED BEFORE THE EXIT IS REACHED: on the first tick of a floor, with
## nothing completed, the next floor's plan is cached and the console can already describe it.
func test_the_next_floor_is_resolved_from_the_moment_of_arrival() -> void:
	var arena: Node3D = _boot()
	assert_eq(arena.expedition.phase, Expedition.PHASE_EXPLORING, "sanity: nobody is on the exit")
	assert_not_null(arena._next_plan, "the destination is resolved before the exit is reached")
	var preview: Dictionary = arena.next_floor_preview()
	assert_eq(preview["depth"], 2)
	assert_eq(preview["place"], "Archive")
	assert_eq(preview["stratum"], "Archive")
	assert_eq(preview["families"], _expected_families(_plan(2)), "the families Floor 2 actually fields")
	assert_false(arena._console_panel.is_open(), "nothing is shown until the console is read")


## THE PREVIEW IS A PROMISE: the floor installed is the very plan the console was read from.
func test_the_floor_installed_is_the_plan_the_console_describes() -> void:
	var arena: Node3D = _boot()
	for expected_depth: int in [2, 3, 4]:
		var previewed: FloorPlan = arena._next_plan
		assert_eq(previewed.depth, expected_depth)
		_complete_the_floor(arena)
		assert_same(arena._current_plan, previewed, "depth %d: the same plan object, not a regeneration" % expected_depth)
		assert_eq(arena.sim._patch_rects.size(), previewed.patches.size())


# --- THE EXIT CONSOLE (revised 2026-10-19) ----------------------------------------------------

## Where an Envoy stands to read the console: on the line from the console toward the pad, at
## the shipped reach less a margin -- the natural spot for someone walking up to the exit.
func _reading_spot(plan: FloorPlan) -> Vector3:
	var reach: float = (load("res://game/content/envoy/envoy_stats.tres") as EnvoyStats).pickup_reach
	var toward_pad := Vector3(plan.end_marker.x - plan.exit_console.x, 0.0, plan.end_marker.z - plan.exit_console.z).normalized()
	return plan.exit_console + toward_pad * (reach - 0.5)


## Stands the Envoy at the reading spot and presses attack at the console, through the driver.
func _read_console(arena: Node3D) -> void:
	var envoy_id: int = _envoy(arena)
	var plan: FloorPlan = arena._current_plan
	arena.sim.entities[envoy_id] = _reading_spot(plan)
	var aim: Vector3 = plan.exit_console - _reading_spot(plan)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "pressed"})] as Array[Command], DT)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "released"})] as Array[Command], DT)


func _exit_region(plan: FloorPlan) -> Rect2:
	for trigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect["kind"] == FloorLayers.EFFECT_COMPLETE_FLOOR:
				return trigger.region
	return Rect2()


## EVERY FLOOR'S CONSOLE CAN BE READ WITHOUT DESCENDING: it stands on walkable ground beside its
## pad, and the spot it is read from is walkable, within the sim's reach, and on no trigger.
func test_every_floor_has_a_console_beside_its_exit_that_is_read_off_the_pad() -> void:
	for depth: int in [1, 2, 3, 4]:
		var plan: FloorPlan = _plan(depth)
		var bounds: WalkableBounds = plan.make_bounds()
		var exit: Rect2 = _exit_region(plan)
		assert_true(bounds.is_inside(plan.exit_console), "depth %d: the console stands on the floor" % depth)
		assert_false(WalkableBounds.contains(exit, plan.exit_console.x, plan.exit_console.z), "depth %d: not on the pad" % depth)
		assert_lt(Vector2(plan.exit_console.x - plan.end_marker.x, plan.exit_console.z - plan.end_marker.z).length(), 8.0,
			"depth %d: beside the pad, not across the room" % depth)
		var spot: Vector3 = _reading_spot(plan)
		assert_true(bounds.is_inside(spot), "depth %d: the reading spot is walkable" % depth)
		for trigger in plan.triggers:
			assert_false(WalkableBounds.contains(trigger.region, spot.x, spot.z), "depth %d: reading stands on no trigger (%d)" % [depth, trigger.trigger_id])


## Read it, read it again to put it away, read it again; Esc closes it; walking away closes it.
func test_the_console_is_optional_dismissable_and_rereadable() -> void:
	var arena: Node3D = _boot()
	_read_console(arena)
	assert_true(arena._console_panel.is_open(), "the press read the console")
	_read_console(arena)
	assert_false(arena._console_panel.is_open(), "the same press puts it away")
	_read_console(arena)
	assert_true(arena._console_panel.is_open(), "and it can be read again")
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	arena._unhandled_input(escape)
	assert_false(arena._console_panel.is_open(), "Esc closes it")
	_read_console(arena)
	assert_true(arena._console_panel.is_open())
	var plan: FloorPlan = arena._current_plan
	var away: Vector3 = _reading_spot(plan) + (_reading_spot(plan) - plan.exit_console).normalized() * 0.2
	# Bounded: a reach check that never says "out" must fail this test, not hang the suite.
	for step in 20:
		if not arena.sim.exit_console_within_reach(_envoy(arena), arena._EXIT_CONSOLE_ID):
			break
		away += (away - plan.exit_console).normalized() * 0.5
		arena.sim.entities[_envoy(arena)] = away
	_idle(arena, 1)
	assert_false(arena._console_panel.is_open(), "walking out of reach closes it")


func test_the_console_says_what_the_cached_destination_is() -> void:
	var arena: Node3D = _boot()
	_read_console(arena)
	var text: String = arena._console_panel.text()
	assert_true(text.contains("Depth 2"), "got '%s'" % text)
	assert_true(text.contains("Archive"), "got '%s'" % text)
	for family: StringName in _expected_families(_plan(2)):
		assert_true(text.contains(String(family).capitalize()), "and %s, got '%s'" % [family, text])


## The console reads the CACHED plan, never one of its own: swap what is cached and it says so.
func test_the_console_reads_the_cached_plan_and_nothing_else() -> void:
	var arena: Node3D = _boot()
	arena._next_plan = _plan(4)
	_read_console(arena)
	var text: String = arena._console_panel.text()
	assert_true(text.contains("Depth 4") and text.contains("Foundry"), "got '%s'" % text)


func test_the_terminal_console_names_the_foundry() -> void:
	var arena: Node3D = _boot([3, 4] as Array[int])
	_read_console(arena)
	var text: String = arena._console_panel.text()
	assert_true(text.contains("Depth 4") and text.contains("Foundry"), "got '%s'" % text)
	for family: StringName in _expected_families(_plan(4)):
		assert_true(text.contains(String(family).capitalize()), "and %s, got '%s'" % [family, text])


func test_reading_the_console_never_starts_a_descent() -> void:
	var arena: Node3D = _boot()
	for i in 6:
		_read_console(arena)
	_idle(arena, 3)
	assert_eq(arena.expedition.phase, Expedition.PHASE_EXPLORING)
	assert_eq(arena.expedition.position, 0)
	assert_false(arena.sim._floor_complete)
	assert_false(arena._descent_overlay.visible)


## Never reading it costs nothing: the exit works exactly as it does for a reader.
func test_a_floor_is_descended_without_ever_reading_the_console() -> void:
	var arena: Node3D = _boot()
	_complete_the_floor(arena)
	assert_eq(arena.expedition.current_depth(), 2)
	assert_false(arena._console_panel.is_open())


func test_a_descent_closes_the_console() -> void:
	var arena: Node3D = _boot()
	_read_console(arena)
	assert_true(arena._console_panel.is_open(), "sanity")
	_deliver(arena, ["floor_complete"])
	assert_false(arena._console_panel.is_open(), "closed the moment the descent began")
	arena._step(_everything(arena, "pressed"), DT)
	assert_false(arena._console_panel.is_open(), "and no press during the descent reads anything")
	_ride(arena)
	assert_false(arena._console_panel.is_open(), "nor is it open on arrival")


func test_the_final_floor_console_names_extraction_not_a_floor() -> void:
	var arena: Node3D = _boot([1, 2] as Array[int])
	_complete_the_floor(arena)
	assert_null(arena._next_plan, "nothing lies below the last floor")
	assert_eq(arena.next_floor_preview(), {})
	_read_console(arena)
	var text: String = arena._console_panel.text()
	assert_true(text.contains("Extraction"), "got '%s'" % text)
	assert_false(text.contains("Depth"), "no invented destination, got '%s'" % text)
	_deliver(arena, ["floor_complete"])
	assert_true(arena.expedition.is_complete, "the last exit ends the run at once -- no ride to nowhere")
	assert_eq(arena.expedition.phase, Expedition.PHASE_COMPLETE)
	assert_false(arena._console_panel.is_open())
	assert_false(arena._transmission.is_showing(), "no transmission for a ride that never starts")
	assert_true(arena.envoy.visible)
	assert_true(arena._completion_overlay.visible)


## Floors 1-4 each draw their console where the plan puts it, on the ground it stands on, and
## the pad's frame where the plan's exit is -- no tall marker over it.
func test_each_floor_draws_its_console_and_pad() -> void:
	var arena: Node3D = _boot()
	for depth: int in [1, 2, 3, 4]:
		var plan: FloorPlan = arena._current_plan
		assert_eq(plan.depth, depth)
		var console: Node3D = arena._floor_builder.exit_console_node()
		assert_not_null(console, "depth %d" % depth)
		var expected := Vector3(plan.exit_console.x, arena._floor_builder.elevation_at(plan.exit_console), plan.exit_console.z)
		assert_almost_eq(console.position, expected, Vector3.ONE * 0.001, "depth %d: where the plan says" % depth)
		var centre: Vector3 = arena._floor_builder.exit_pad_centre()
		assert_almost_eq(Vector2(centre.x, centre.z), Vector2(plan.end_marker.x, plan.end_marker.z), Vector2.ONE * 0.001, "depth %d: the pad" % depth)
		if depth < 4:
			_complete_the_floor(arena)


func test_the_focus_glow_follows_the_sims_answer() -> void:
	var arena: Node3D = _boot()
	arena._floor_builder.show_interaction_focus("inspect", -1, -1)
	assert_true(arena._floor_builder.exit_console_focused())
	assert_true(arena._floor_builder._focus_ring.visible)
	arena._floor_builder.show_interaction_focus("", -1, -1)
	assert_false(arena._floor_builder.exit_console_focused())
	assert_false(arena._floor_builder._focus_ring.visible)


## EXACT FIXED-TICK DURATION, from the run configuration -- checked at a non-default value too,
## so the countdown is shown to come from config rather than coincide with it.
func test_the_descent_lasts_exactly_the_configured_ticks() -> void:
	for ticks: int in [45, 7]:
		var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
		arena.descent_ticks = ticks
		add_child_autofree(arena)
		_deliver(arena, ["floor_complete"])
		_idle(arena, ticks - 1)
		assert_eq(arena.expedition.phase, Expedition.PHASE_DESCENDING, "%d: still riding after %d ticks" % [ticks, ticks - 1])
		assert_eq(arena.expedition.position, 0)
		_idle(arena, 1)
		assert_eq(arena.expedition.phase, Expedition.PHASE_EXPLORING, "%d: arrived on tick %d" % [ticks, ticks])
		assert_eq(arena.expedition.position, 1)
		assert_eq(arena.expedition.current_depth(), 2)


## THE FLOOR IS SUSPENDED (ruled): no tick, no movement, no AI, no damage, no projectile, no
## hazard progress -- whatever the player presses -- for the whole descent.
func test_the_floor_is_suspended_for_the_whole_descent() -> void:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.itinerary = [4, 3] as Array[int]
	arena.debug_force_aggro = true  # every enemy awake, so a frozen one is frozen, not idle
	add_child_autofree(arena)
	var envoy_id: int = _envoy(arena)
	# A shot in flight, so a projectile has a reason to move.
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "switch_weapon", {})] as Array[Command], DT)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	_idle(arena, 3)
	assert_gt(arena.sim._projectiles.size(), 0, "sanity: a projectile is in flight")
	# CONTROL: the very same inputs DO act on a live floor.
	var before_control: Vector3 = arena.sim.entities[envoy_id]
	arena._step(_everything(arena, "pressed"), DT)
	assert_ne(arena.sim.entities[envoy_id], before_control, "sanity: on a live floor, input moves the Envoy")

	_deliver(arena, ["floor_complete"])
	assert_eq(arena.expedition.phase, Expedition.PHASE_DESCENDING)
	var tick: int = arena.sim.tick_count
	var entities: Dictionary = arena.sim.entities.duplicate(true)
	var health: Dictionary = arena.sim._health.duplicate(true)
	var projectiles: Variant = arena.sim._projectiles.duplicate(true)
	var ai_state: Dictionary = arena.sim._ai_state.duplicate(true)
	var shield: float = arena.sim._shield_meter[envoy_id]
	var equipped: StringName = arena.sim._equipped_weapon[envoy_id]
	var pads: Dictionary = {}
	for pad_id: int in arena._floor_builder.hazard_pad_ids():
		pads[pad_id] = arena.sim.spike_pad_ticks_until_active(pad_id)
	assert_gt(pads.size(), 0, "sanity: the Foundry has pads to freeze")

	for i in arena.descent_ticks - 1:
		arena._step(_everything(arena, "held" if i % 2 == 0 else "pressed"), DT)
		assert_eq(arena.sim.tick_count, tick, "descent tick %d: the floor's clock did not move" % i)
	assert_eq(arena.sim.entities, entities, "nobody moved, the Envoy included")
	assert_eq(arena.sim._health, health, "nobody was hurt")
	assert_eq(arena.sim._projectiles, projectiles, "no shot travelled")
	assert_eq(arena.sim._ai_state, ai_state, "no AI decided anything")
	assert_eq(arena.sim._shield_meter[envoy_id], shield, "the shield neither drained nor regenerated")
	assert_eq(arena.sim._equipped_weapon[envoy_id], equipped, "no weapon switch was applied")
	for pad_id: int in pads:
		assert_eq(arena.sim.spike_pad_ticks_until_active(pad_id), pads[pad_id], "pad %d did not advance" % pad_id)


## NO STALE INTENT CROSSES THE SHAFT: a charge held into the lift and a button still down on
## arrival start nothing on the new floor.
func test_no_attack_or_movement_intent_is_carried_into_the_new_floor() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = _envoy(arena)
	# Sword in hand (the shipped first weapon): press and hold, so a charge is open at the exit.
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})] as Array[Command], DT)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1), "phase": "held"})] as Array[Command], DT)
	assert_true(arena.sim._melee_hold.has(envoy_id), "sanity: a charge is open when the floor completes")

	_deliver(arena, ["floor_complete"])
	for i in arena.descent_ticks:
		arena._step(_everything(arena, "pressed"), DT)
	assert_eq(arena.expedition.current_depth(), 2, "sanity: arrived")
	assert_eq(arena.sim.entities[envoy_id], _plan(2).entry_point, "standing exactly on the entry: no move was banked")
	assert_false(arena.sim._melee_hold.has(envoy_id), "the charge stayed on Floor 1")
	assert_false(arena.sim._melee_buffered_press.has(envoy_id), "and no press was buffered on the way down")
	assert_ne(arena.sim._shield_state.get(envoy_id, "ready"), "held", "the shield is not raised by a block sent in the lift")

	# The button is still down on arrival, then let go: an orphan hold/release is not an attack.
	var events: Array[Event] = arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1), "phase": "held"})] as Array[Command], DT)
	events.append_array(arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})] as Array[Command], DT))
	for event in events:
		assert_ne(event.kind, "melee_swing", "a release with no press on this floor swung the sword")
		assert_ne(event.kind, "charge_ready")


func test_a_completion_during_the_descent_is_not_a_second_descent() -> void:
	var arena: Node3D = _boot()
	_deliver(arena, ["floor_complete"])
	_idle(arena, 5)
	_deliver(arena, ["floor_complete", "floor_complete"])
	_idle(arena, arena.descent_ticks)
	assert_eq(arena.expedition.position, 1, "one floor down, not two")
	assert_eq(arena.expedition.phase, Expedition.PHASE_EXPLORING)


## THE TRANSMISSION, as a picture of the countdown: the field rises round the Envoy, the Envoy goes
## to light and is hidden -- never scaled -- and on arrival it is shown again at the entry with the
## light fading off it. Everything transient is put away once the fade is done.
func test_the_envoy_is_transmitted_out_and_rematerializes_on_arrival() -> void:
	var arena: Node3D = _boot()
	var model: Node3D = arena.envoy.get_node("Model")
	var model_scale: Vector3 = model.scale
	_deliver(arena, ["floor_complete"])
	assert_true(arena._transmission.is_showing(), "the pad is transmitting")
	assert_almost_eq(arena._transmission.position, arena._floor_builder.exit_pad_centre(), Vector3.ONE * 0.001, "at the pad")
	assert_true(arena.envoy.visible, "the Envoy is still there as it begins")
	var vanish_tick: int = ceili(arena._transmission.vanish_progress * arena.descent_ticks)
	_idle(arena, vanish_tick + 1)
	assert_false(arena.envoy.visible, "gone to light before the screen is dark")
	assert_eq(arena.envoy.scale, Vector3.ONE, "the Envoy is hidden, never squashed")
	assert_eq(model.scale, model_scale)
	_idle(arena, arena.descent_ticks - vanish_tick - 1)
	assert_eq(arena.expedition.current_depth(), 2)
	assert_true(arena.envoy.visible, "rematerialized on the new floor")
	assert_eq(arena.envoy.position, _plan(2).entry_point, "standing on the new floor, not below it")
	assert_true(arena._transmission.is_showing(), "the arrival glow is fading off it")
	assert_almost_eq(arena._transmission.position, arena._grounded(_plan(2).entry_point), Vector3.ONE * 0.001)
	assert_true(arena._arrival_card.visible)
	arena._transmission._process(arena._transmission.arrival_seconds + 0.01)
	assert_false(arena._transmission.is_showing(), "and put away once it has")


## A shot drawn in flight is put away when the Envoy leaves: it would otherwise keep flying
## through a suspended floor.
func test_tracers_are_put_away_when_the_descent_begins() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = _envoy(arena)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "switch_weapon", {})] as Array[Command], DT)
	arena._step([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
	assert_gt(arena._projectile_tracers.size(), 0, "sanity: a shot is drawn")
	_deliver(arena, ["floor_complete"])
	assert_eq(arena._projectile_tracers.size(), 0)


## Restart mid-descent: a fresh arena owes nothing to a run caught in the shaft.
func test_a_restart_during_the_descent_begins_a_fresh_expedition() -> void:
	var first: Node3D = _boot()
	_deliver(first, ["floor_complete"])
	_idle(first, 10)
	assert_eq(first.expedition.phase, Expedition.PHASE_DESCENDING, "sanity: caught mid-ride")
	first.free()
	var second: Node3D = _boot()
	assert_eq(second.expedition.phase, Expedition.PHASE_EXPLORING)
	assert_eq(second.expedition.position, 0)
	assert_false(second._descent_overlay.visible)
	assert_false(second._transmission.is_showing())
	assert_true(second.envoy.visible)
	assert_false(second._console_panel.is_open())
	assert_eq(second._next_plan.depth, 2)
