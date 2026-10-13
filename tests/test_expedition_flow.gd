extends GutTest
## THE EXPEDITION, through the real arena and the real driver step.
##
##   begin -> Floor 1 -> descent -> Floor 2 -> descent -> Terminal -> expedition complete
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


func _complete_the_floor(arena: Node3D) -> void:
	_deliver(arena, ["floor_complete"])


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
	assert_eq(arena.expedition.itinerary, [1, 2, 3] as Array[int], "the shipped expedition is Archive 1, Archive 2, then the Terminal")
	assert_eq(arena.expedition.position, 0)
	assert_eq(arena.expedition.current_depth(), 1)
	assert_false(arena.expedition.is_complete)
	assert_eq(arena.sim._patch_rects.size(), _plan(1).patches.size(), "and Floor 1 is what is loaded")
	assert_true(arena._seed_label.text.contains("depth 1"), "the HUD names the depth, got '%s'" % arena._seed_label.text)
	assert_true(arena._seed_label.text.contains("floor 1/3"), "and the position in the run, got '%s'" % arena._seed_label.text)
	assert_false(arena._arrival_card.visible, "beginning is not arriving from a descent")
	assert_false(arena._completion_overlay.visible)
	assert_false(arena._failure_overlay.visible)


## The expedition, not the node, is the authority: the node's export is only what it was begun
## with.
func test_the_expedition_owns_its_itinerary_after_beginning() -> void:
	var arena: Node3D = _boot()
	arena.itinerary.append(7)
	assert_eq(arena.expedition.itinerary, [1, 2, 3] as Array[int],
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
	assert_true(arena._seed_label.text.contains("floor 2/3"), "got '%s'" % arena._seed_label.text)
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
	assert_eq(arena.expedition.position, 1, "resolution is what descends")


func test_a_duplicated_completion_cannot_skip_a_floor() -> void:
	var arena: Node3D = _boot([1, 2, 2] as Array[int])
	_deliver(arena, ["floor_complete", "floor_complete", "floor_complete"])
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
	assert_eq(second.expedition.itinerary, [1, 2, 3] as Array[int], "with the whole itinerary ahead")
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
	var final_exit: Vector3 = _centre(TERMINAL.region_for(&"T_EXIT"))
	for i in 1500:
		if arena.expedition.is_complete:
			break
		_move(arena, (final_exit - arena.sim.entities[envoy_id]).normalized())

	assert_true(arena.expedition.is_complete, "standing on the Terminal's exit completes the expedition")
	assert_true(arena._completion_overlay.visible)
	assert_false(arena._failure_overlay.visible)
	var stopped_at: int = arena.sim.tick_count
	_idle(arena, 30)
	assert_eq(arena.sim.tick_count, stopped_at, "and the world stops with it")
