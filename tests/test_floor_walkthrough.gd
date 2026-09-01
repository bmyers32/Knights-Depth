extends GutTest
## END-TO-END: the whole authored grammar, walked in the real arena through the real driver.
##
##   START -> one-way commitment -> hall wrapping a void -> forward route VISIBLE BUT BLOCKED
##   -> branch west -> break the crate -> reveal the switch -> use it -> route opens
##   -> PARTY PLATE (stood on, never pressed): rear seals, forward opens, roster ARRIVES
##   -> clear -> ramp AND the last route open together -> raised ground -> EXIT PLATE
##
## The unit tests each prove one law. This proves they COMPOSE into something a player can
## actually walk, which is the only thing that answers "is this slice playable?" short of a
## human at the keyboard. BOOT-CLEAN IS NOT INTERACT-CLEAN.

const DT := 1.0 / 30.0
## preload, not a class_name alias: a class_name is not a constant expression in GDScript.
const L = preload("res://game/gen/layouts/archive_prototype.gd")


func _boot() -> Node3D:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	add_child_autofree(arena)
	# The floor is a long walk with a real fight in it; survivability keeps a TRAVERSAL test
	# measuring traversal. Never a balance claim.
	arena.sim.debug_override_health(arena.envoy.actor_id, 100000.0)
	return arena


func _plan(arena: Node3D) -> FloorPlan:
	return DepthGenerator.generate(arena.run_seed, arena.depth)


func _envoy(arena: Node3D) -> int:
	return arena.envoy.actor_id


## Drives the Envoy toward a point through the REAL Command path. Deliberately not a teleport:
## walking is what exercises the clamp, the apertures and every region trigger on the way.
##
## STRAIGHT-LINE STEERING, with no pathfinding -- the same thing a player does by holding a
## direction. Tests therefore route through intermediate points, and a direct walk that fails
## because geometry is in the way is the geometry working.
func _walk_to(arena: Node3D, target: Vector3, max_ticks: int = 1500) -> bool:
	var envoy_id: int = _envoy(arena)
	for i in max_ticks:
		var position: Vector3 = arena.sim.entities[envoy_id]
		if position.distance_to(target) < 1.2:
			return true
		var direction: Vector3 = target - position
		direction.y = 0.0
		arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	return arena.sim.entities[envoy_id].distance_to(target) < 1.2


## Cycles the shipped loadout until a projectile weapon is equipped, driving the real
## switch_weapon Command rather than reaching into sim state.
func _switch_to_the_wand(arena: Node3D) -> Array[Event]:
	var envoy_id: int = _envoy(arena)
	var events: Array[Event] = []
	for attempt in 4:
		events.append_array(arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "switch_weapon", {})] as Array[Command], DT))
		var probe: Array[Event] = arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": Vector3(0, 0, -1)})] as Array[Command], DT)
		events.append_array(probe)
		for event in probe:
			if event.kind == "projectile_fired":
				for i in 30:
					events.append_array(arena.sim.tick([] as Array[Command], DT))
				return events
		for i in 30:
			events.append_array(arena.sim.tick([] as Array[Command], DT))
	return events


## Walks onto an authored plate region, COLLECTING events, because occupancy is evaluated every
## tick: by the time the walk returns, whatever the plate does has already happened.
func _step_onto(arena: Node3D, region: Rect2, tolerance: float = 0.6) -> Array[Event]:
	var envoy_id: int = _envoy(arena)
	var target := Vector3(region.position.x + region.size.x * 0.5, 0.0, region.position.y + region.size.y * 0.5)
	var events: Array[Event] = []
	for i in 1500:
		var position: Vector3 = arena.sim.entities[envoy_id]
		if position.distance_to(target) < tolerance:
			break
		var direction: Vector3 = target - position
		direction.y = 0.0
		events.append_array(arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": direction.normalized()})] as Array[Command], DT))
	return events


func _patch_centre(arena: Node3D, patch_id: int) -> Vector3:
	return _plan(arena).patch_by_id(patch_id).centre()


func _open(arena: Node3D, connection_id: int) -> bool:
	return bool(arena.sim._connection_open[connection_id])


func _kinds(events: Array[Event]) -> Array:
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	return kinds


## Walks up to the crate and swings until it is gone.
##
## PRESS THEN RELEASE, not a bare "attack": the shipped loadout's sword is a combo weapon
## registered through register_melee_profiles, so a phase-less Command is not a swing at all.
## Driving the real weapon the real way is the point of an integration test -- a synthetic
## one-shot sword here would have proved nothing about the build a human will play.
func _break_the_crate(arena: Node3D) -> Array[Event]:
	var envoy_id: int = _envoy(arena)
	var crate: Vector3 = _plan(arena).breakables[0].position
	assert_true(_walk_to(arena, crate + Vector3(0.0, 0.0, 1.6)), "the crate must be reachable")
	var events: Array[Event] = []
	for swing in 12:
		var aim: Vector3 = (crate - arena.sim.entities[envoy_id]).normalized()
		events.append_array(arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "pressed"})] as Array[Command], DT))
		events.append_array(arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim, "phase": "released"})] as Array[Command], DT))
		for i in 14:  # let the swing resolve and the cooldown clear
			events.append_array(arena.sim.tick([] as Array[Command], DT))
		if arena.sim._breakables.is_empty():
			break
	assert_true(arena.sim._breakables.is_empty(), "the crate must be destructible with the shipped weapon")
	return events


## A spot on the approach that is NOT the plate. The approach patch's centre IS the plate
## centre, so any test wanting to stand "before" the plate must aim off to one side of it --
## otherwise the walk that positions the test has already triggered what it meant to observe.
func _approach_hold() -> Vector3:
	return Vector3(4.5, 0.0, -39.0)


func _step_onto_the_plate(arena: Node3D) -> Array[Event]:
	return _step_onto(arena, L.PARTY_PLATE_REGION)


## Everything up to and including the party committing to the fight.
func _reach_and_start_the_fight(arena: Node3D) -> void:
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_WEST)))
	_break_the_crate(arena)
	_step_onto(arena, L.HIDDEN_PLATE_REGION)
	assert_true(_walk_to(arena, _approach_hold()))
	_step_onto_the_plate(arena)


func _kill_the_roster(arena: Node3D) -> void:
	for actor_id: int in arena.sim._encounter_roster[L.E_ARENA]:
		arena.sim.debug_override_health(actor_id, 0.0)
	arena.sim.tick([] as Array[Command], DT)


# --- THE FLOOR EXISTS -------------------------------------------------------------------

func test_the_arena_boots_the_authored_floor_with_all_four_layers() -> void:
	var arena: Node3D = _boot()
	assert_gt(arena.sim._patch_rects.size(), 4, "spatial layer registered")
	assert_gt(arena.sim._connections.size(), 0, "progression layer registered")
	assert_gt(arena.sim._triggers.size(), 0, "controllers registered")
	assert_gt(arena.sim._encounters.size(), 1, "encounter layer registered")
	assert_gt(arena.sim._breakables.size(), 0, "interaction layer registered")
	assert_eq(arena.sim._breakables.size(), 1, "and one prop to search behind")


## SEED HONESTY on screen: while the layout is authored the HUD must say so, rather than
## implying a different seed would give a different floor.
func test_the_hud_declares_the_layout_authored() -> void:
	var shown: String = _boot()._seed_label.text
	assert_true(shown.contains("authored layout"),
		"the HUD must not advertise variety that does not exist, got '%s'" % shown)
	assert_true(shown.contains("seed 0"), "the seed is still shown as reproduction metadata, got '%s'" % shown)


func test_only_the_ambient_roster_is_present_before_anything_is_triggered() -> void:
	var arena: Node3D = _boot()
	var present: int = 0
	var absent: int = 0
	for actor_id: int in arena._enemies.keys():
		if arena.sim.debug_is_combat_absent(actor_id):
			absent += 1
		else:
			present += 1
	assert_eq(present, 1, "exactly the ambient territory is inhabited at load")
	# 4 = the 3-strong mandatory roster plus the single door-control response, which likewise
	# waits registered-but-absent until the hidden plate opens the way.
	assert_eq(absent, 4, "the deferred rosters are registered but have not been summoned")


# --- TRAVERSAL AND COMMITMENT -----------------------------------------------------------

func test_reaching_the_hall_commits_the_envoy_forward() -> void:
	var arena: Node3D = _boot()
	assert_true(_open(arena, L.C_COMMIT), "sanity: the way in starts open")
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_SOUTH)), "the Envoy must reach the hall")
	assert_false(_open(arena, L.C_COMMIT), "entering must seal the way back")
	assert_false(_walk_to(arena, _patch_centre(arena, L.P_START), 300), "and the start is unreachable now")


## The hall is a ring, so both arms lead onward -- a real branch, not a corridor with a bend.
func test_the_hall_offers_a_genuine_branch_around_a_void() -> void:
	var arena: Node3D = _boot()
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_SOUTH)))
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_WEST)), "west arm reachable")
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_NORTH)), "and it leads onward")
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_EAST)), "so does the east arm")
	assert_false(_walk_to(arena, Vector3(0.0, 0.0, -22.0), 400), "and the middle is a genuine void")


func test_the_forward_route_is_visible_but_blocked_until_earned() -> void:
	var arena: Node3D = _boot()
	assert_false(_open(arena, L.C_TO_APPROACH), "the way on starts closed")
	# Routed via an arm on purpose: _walk_to steers in a STRAIGHT LINE, exactly like a player
	# holding a direction, and the hall's void sits between the entrance and the far side. A
	# direct walk failing here is the void doing its job, not a defect.
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_WEST)), "round the west arm")
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_NORTH)), "to the far side of the hall")
	assert_false(_walk_to(arena, _patch_centre(arena, L.P_APPROACH), 400),
		"the Envoy must not be able to walk into the approach yet")


# --- SEARCH -> DISCOVER -> OPEN -----------------------------------------------------------

func test_breaking_the_crate_reveals_the_switch_that_opens_the_route() -> void:
	var arena: Node3D = _boot()
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_WEST)))
	assert_false(bool(arena.sim._trigger_enabled[L.T_HIDDEN_PLATE]), "concealed to begin with")

	var kinds: Array = _kinds(_break_the_crate(arena))
	assert_true(kinds.has("breakable_destroyed"), "the crate must be destructible")
	assert_true(kinds.has("floor_trigger_enabled"), "and must reveal what it hid")

	assert_false(_open(arena, L.C_TO_APPROACH), "revealing is not yet standing on it")
	_step_onto(arena, L.HIDDEN_PLATE_REGION)
	assert_true(_open(arena, L.C_TO_APPROACH), "stepping onto what it hid is what opens the way")


# --- THE PARTY PLATE ----------------------------------------------------------------------

## The reference sequence end to end: STAND on it, four consequences, one tick. No E, because
## the beat was always "the party commits together" and a keypress could never express that.
func test_the_party_plate_seals_the_rear_opens_the_way_and_summons_the_roster() -> void:
	var arena: Node3D = _boot()
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_WEST)))
	_break_the_crate(arena)
	_step_onto(arena, L.HIDDEN_PLATE_REGION)
	assert_true(_walk_to(arena, _approach_hold()))

	assert_true(_open(arena, L.C_TO_APPROACH), "sanity: rear open before the plate")
	assert_false(_open(arena, L.C_TO_ARENA), "sanity: forward closed before the plate")

	var kinds: Array = _kinds(_step_onto_the_plate(arena))

	assert_false(_open(arena, L.C_TO_APPROACH), "the rear route seals")
	assert_true(_open(arena, L.C_TO_ARENA), "the forward route opens")
	assert_eq(arena.sim._encounter_state[L.E_ARENA], "active", "the encounter begins")
	assert_true(kinds.has("encounter_activated"), "and announces itself")
	for actor_id: int in arena.sim._encounter_roster[L.E_ARENA]:
		assert_false(arena.sim.debug_is_combat_absent(actor_id), "the roster ARRIVES when they commit")


## NO PRESS SURVIVES ANYWHERE ON THIS FLOOR. Every control is something you stand on, and the
## `interact` Command was retired with its last consumer.
func test_the_floor_has_no_interact_verb_left() -> void:
	var arena: Node3D = _boot()
	for trigger in _plan(arena).triggers:
		assert_ne(String(trigger.kind), "interacted", "trigger %d still wants a press" % trigger.trigger_id)
	var plates: int = 0
	for trigger in _plan(arena).triggers:
		if trigger.renders_as_plate:
			plates += 1
	assert_eq(plates, 3, "the hidden plate, the party plate and the exit are all stood on")


func test_the_sealed_encounter_confines_both_sides() -> void:
	var arena: Node3D = _boot()
	_reach_and_start_the_fight(arena)
	var region: Rect2 = _plan(arena).encounters_of_role(FloorLayers.ROLE_MANDATORY)[0].regions[0]

	assert_false(_walk_to(arena, _patch_centre(arena, L.P_HALL_NORTH), 500), "the Envoy must not escape")
	var position: Vector3 = arena.sim.entities[_envoy(arena)]
	assert_true(position.z <= region.end.y + 0.001 and position.z >= region.position.y - 0.001,
		"the Envoy left the sealed encounter to %s" % position)
	for actor_id: int in arena.sim._encounter_roster[L.E_ARENA]:
		var enemy: Vector3 = arena.sim.entities[actor_id]
		assert_true(enemy.z <= region.end.y + 0.001 and enemy.z >= region.position.y - 0.001,
			"roster actor %d left the sealed encounter to %s" % [actor_id, enemy])


func test_clearing_the_encounter_opens_the_way_onward() -> void:
	var arena: Node3D = _boot()
	_reach_and_start_the_fight(arena)
	assert_false(_open(arena, L.C_TO_RAMP), "sanity: the exit starts closed")
	_kill_the_roster(arena)
	assert_eq(arena.sim._encounter_state[L.E_ARENA], "cleared")
	assert_true(_open(arena, L.C_TO_RAMP), "clearing must open the way onward")
	assert_eq(arena.sim.debug_describe_floor()["active_confinement"], -1, "and lift the seal")


## Combat still works, inside the summoned fight, on the real floor.
func test_the_summoned_roster_actually_fights() -> void:
	var arena: Node3D = _boot()
	_reach_and_start_the_fight(arena)
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_ARENA)))
	var envoy_id: int = _envoy(arena)
	var before: float = arena.sim._health[envoy_id]
	var telegraphs: int = 0
	for i in 900:
		for event in arena.sim.tick([] as Array[Command], DT):
			if event.kind == "attack_telegraph":
				telegraphs += 1
	assert_gt(telegraphs, 0, "a summoned roster must commit attacks")
	assert_lt(arena.sim._health[envoy_id], before, "and be able to land them")


# --- THE WHOLE GRAMMAR --------------------------------------------------------------------

## One continuous run from arrival to endpoint, using only player Commands. If this passes, a
## human can walk the floor.
func test_the_envoy_can_traverse_the_entire_floor_to_the_endpoint() -> void:
	var arena: Node3D = _boot()
	var plan: FloorPlan = _plan(arena)

	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_SOUTH)), "into the hall")
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_WEST)), "down the west branch")
	_break_the_crate(arena)
	_step_onto(arena, L.HIDDEN_PLATE_REGION)
	assert_true(_walk_to(arena, _approach_hold()), "through the route it opened")
	assert_false(_open(arena, L.C_TO_END), "sanity: the last route is earned, not free")
	_step_onto_the_plate(arena)
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_ARENA)), "into the fight")
	_kill_the_roster(arena)
	# THE FIGHT IS THE PREREQUISITE. No terminal switch: an obvious door asking only for an E
	# press had no discovery and no decision in it, so the clear opens the whole way out.
	assert_true(_open(arena, L.C_TO_END), "clearing the fight opens the last route itself")
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_RAMP)), "up the ramp")
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HIGH)), "onto the high ground")
	# THE EXIT IS A CONDITION, not a pillar: the floor is not finished until the whole
	# expedition is standing on it.
	assert_false(arena.sim.debug_describe_floor()["floor_complete"], "sanity: not finished on arrival")
	_step_onto(arena, L.EXIT_PLATE_REGION)
	assert_true(arena.sim.debug_describe_floor()["floor_complete"],
		"standing on the exit together is what finishes the floor")


## Elevation is PRESENTATION: the sim stays flat while the rendered Envoy climbs.
func test_the_envoy_is_lifted_onto_high_ground_without_the_sim_knowing() -> void:
	var arena: Node3D = _boot()
	_reach_and_start_the_fight(arena)
	_kill_the_roster(arena)
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HIGH)), "reach the raised ground")

	assert_almost_eq(arena.sim.entities[_envoy(arena)].y, 0.0, 0.001, "the sim stays on one plane")
	arena._physics_process(DT)
	assert_gt(arena.envoy.position.y, 1.0, "while presentation lifts the Envoy onto it")


## A LEDGE IS STILL A BOUNDARY. The raised platform renders no wall -- you can see over the
## drop -- and the sim refuses to let the Envoy off it anyway, because legality was never these
## meshes' job. This is the whole content of "not every walkability edge needs a wall".
func test_a_ledge_edge_bounds_the_envoy_without_rendering_a_wall() -> void:
	var arena: Node3D = _boot()
	var high: WalkablePatch = _plan(arena).patch_by_id(L.P_HIGH)
	assert_eq(high.boundary_style, &"ledge", "the high ground is authored as an open ledge")

	_reach_and_start_the_fight(arena)
	_kill_the_roster(arena)
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HIGH)), "reach the raised ground")

	# Walk hard at the open edge for long enough that any leak would show.
	for i in 300:
		arena.sim.tick([Command.new(arena.sim.tick_count, _envoy(arena), "move", {"direction": Vector3(1, 0, 0)})] as Array[Command], DT)
	var position: Vector3 = arena.sim.entities[_envoy(arena)]
	assert_true(arena.sim._bounds.fits(position, arena.envoy.stats.combat_radius),
		"the Envoy walked off an unwalled ledge to %s" % position)


# --- RANGED BREAKABLE PROBING (human ruling 2026-09-01) -------------------------------------

## THE NEWLY-INTENTIONAL BEHAVIOUR: with the roundabout's void ring opened, the crate can be shot
## from across the hall. Ruled acceptable and preferable -- walking the whole ring only to learn a
## breakable was empty is friction without discovery.
##
## THE THING THAT MUST STILL HOLD is progression. Breaking the crate only REVEALS the plate; the
## route is opened by STANDING on it, so remote destruction saves a wasted walk without skipping
## the floor. This asserts exactly that, because "you can now shoot it" would be a cheap win if it
## quietly bypassed the beat it belongs to.
func test_shooting_the_crate_across_the_void_reveals_but_does_not_bypass() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = _envoy(arena)
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_SOUTH)), "into the hall")

	# THE SHIPPED LOADOUT STARTS ON THE SWORD. Shooting means switching to the wand first, the
	# way a player does -- a bare "attack" here would swing at empty air and prove nothing.
	var events: Array[Event] = _switch_to_the_wand(arena)
	var crate: Vector3 = _plan(arena).breakables[0].position
	for shot in 30:
		var aim: Vector3 = (crate - arena.sim.entities[envoy_id]).normalized()
		events.append_array(arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim})] as Array[Command], DT))
		for i in 8:
			events.append_array(arena.sim.tick([] as Array[Command], DT))
		if arena.sim._breakables.is_empty():
			break

	assert_true(arena.sim._breakables.is_empty(), "the crate must be reachable by shot across the void")
	assert_true(_kinds(events).has("floor_trigger_enabled"), "and destroying it still reveals the plate")

	# THE PROGRESSION IS NOT SKIPPED: revealing is not opening.
	assert_false(_open(arena, L.C_TO_APPROACH), "revealing the plate must NOT open the route")
	_step_onto(arena, L.HIDDEN_PLATE_REGION)
	assert_true(_open(arena, L.C_TO_APPROACH), "standing on it is still what opens the way")


## And the route that follows remains fully walkable after a remote reveal -- deterministically,
## not merely on the tick it happened.
func test_the_floor_still_completes_after_a_remote_crate_kill() -> void:
	var arena: Node3D = _boot()
	var envoy_id: int = _envoy(arena)
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HALL_SOUTH)))
	_switch_to_the_wand(arena)
	var crate: Vector3 = _plan(arena).breakables[0].position
	for shot in 30:
		var aim: Vector3 = (crate - arena.sim.entities[envoy_id]).normalized()
		arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "attack", {"aim": aim})] as Array[Command], DT)
		for i in 8:
			arena.sim.tick([] as Array[Command], DT)
		if arena.sim._breakables.is_empty():
			break
	assert_true(arena.sim._breakables.is_empty(), "sanity: destroyed remotely")

	_step_onto(arena, L.HIDDEN_PLATE_REGION)
	assert_true(_walk_to(arena, _approach_hold()), "through the route it opened")
	_step_onto_the_plate(arena)
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_ARENA)), "into the fight")
	_kill_the_roster(arena)
	assert_true(_walk_to(arena, _patch_centre(arena, L.P_HIGH)), "onto the high ground")
	_step_onto(arena, L.EXIT_PLATE_REGION)
	assert_true(arena.sim.debug_describe_floor()["floor_complete"],
		"the whole floor must still complete after a remote reveal")
