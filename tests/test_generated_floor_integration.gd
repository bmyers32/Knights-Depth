extends GutTest
## END-TO-END: run seed -> FloorPlan -> load_floor -> FloorBuilder -> explore -> lock-in fight
## -> clear -> continue to the floor's end.
##
## The unit tests each prove one seam. This proves the seams COMPOSE in the real arena, on a
## real generated floor, driven through the real driver -- which is the only thing that
## answers "is this slice actually playable?" short of a human at the keyboard.
##
## BOOT-CLEAN IS NOT INTERACT-CLEAN (BRAIN, and this repo's own regression history): loading
## arena.tscn headlessly proves nothing about whether a player can walk the chain, whether the
## gates seal, or whether clearing an encounter lets them out again.

const DT := 1.0 / 30.0


func _boot(force_aggro: bool = false) -> Node3D:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.debug_force_aggro = force_aggro
	add_child_autofree(arena)
	return arena


func _plan_of(arena: Node3D) -> FloorPlan:
	return DepthGenerator.generate(arena.run_seed, arena.depth)


func _envoy(arena: Node3D) -> int:
	return arena.envoy.actor_id


## Drives the Envoy toward a point through the REAL Command path, one sim tick at a time, and
## reports whether it arrived. Deliberately not a teleport: walking is what exercises the
## clamp, the apertures and the encounter trigger.
func _walk_toward(arena: Node3D, target: Vector3, max_ticks: int = 900) -> bool:
	var envoy_id: int = _envoy(arena)
	for i in max_ticks:
		var position: Vector3 = arena.sim.entities[envoy_id]
		if position.distance_to(target) < 1.0:
			return true
		var direction: Vector3 = (target - position)
		direction.y = 0.0
		arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": direction.normalized()})] as Array[Command], DT)
	return arena.sim.entities[envoy_id].distance_to(target) < 1.0


func _combat_room(plan: FloorPlan) -> RoomPlan:
	return plan.rooms_of_kind(RoomPlan.KIND_COMBAT)[0]


## INCLUSIVE containment. Rect2.has_point excludes the far edge, but WalkableBounds.is_inside
## includes it -- and a sealed actor comes to rest EXACTLY on the boundary, so has_point would
## report the correctly-clamped Envoy as having escaped.
func _inside(rect: Rect2, point: Vector3) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.z >= rect.position.y and point.z <= rect.end.y


# --- THE FLOOR EXISTS ----------------------------------------------------------------

func test_the_arena_boots_a_multi_room_floor() -> void:
	var arena: Node3D = _boot()
	var plan: FloorPlan = _plan_of(arena)
	assert_gt(plan.rooms.size(), 1, "a floor is more than one room -- that was the whole point of this slice")
	assert_not_null(arena.sim._bounds, "the sim must have adopted the floor's walkable law")
	assert_eq(arena.sim._rooms.size(), plan.rooms.size(), "every room must be registered with the sim")
	assert_gt(arena._enemies.size(), 0, "the combat room must be populated")


func test_the_active_seed_is_visible_on_screen() -> void:
	var arena: Node3D = _boot()
	var shown: String = arena._seed_label.text
	assert_true(shown.contains(str(arena.run_seed)), "the run seed must be on screen, got '%s'" % shown)
	assert_true(shown.contains("depth 1"), "and the depth with it, got '%s'" % shown)


func test_generated_actors_receive_unique_ids_that_never_collide_with_the_envoy() -> void:
	var arena: Node3D = _boot()
	var seen: Dictionary = {}
	for actor_id: int in arena._enemies.keys():
		assert_false(seen.has(actor_id), "actor_id %d was allocated twice" % actor_id)
		assert_ne(actor_id, _envoy(arena), "an enemy must never take the Envoy's id")
		seen[actor_id] = true


# --- EXPLORATION ---------------------------------------------------------------------

## The claim the whole slice rests on: connected spaces are actually walkable between. The
## Envoy starts in ENTRY and must reach the far side of the floor on foot.
func test_the_envoy_can_walk_the_whole_chain_from_entry_to_the_end_marker() -> void:
	var arena: Node3D = _boot()
	var plan: FloorPlan = _plan_of(arena)
	# Clear the encounter out of the way first, or the lock legitimately stops the walk --
	# that seal is tested on its own below.
	for actor_id: int in arena._enemies.keys():
		arena.sim.debug_override_health(actor_id, 0.0)

	for room in plan.rooms:
		assert_true(_walk_toward(arena, room.centre()),
			"the Envoy could not walk into room %d (%s) -- the chain is not traversable" % [room.room_id, room.kind])
	assert_true(_walk_toward(arena, plan.end_marker),
		"the Envoy could not reach the terminal marker -- progression does not continue past the fight")


## THE PHANTOM-WALL REGRESSION, at the level a player would feel it. Slice 1's clamp picked
## the first array-order rect containing the actor, so in a doorway (inside both the room and
## the aperture) it could clamp against a wall the player can see is open.
func test_no_phantom_wall_blocks_a_doorway() -> void:
	var arena: Node3D = _boot()
	var plan: FloorPlan = _plan_of(arena)
	for actor_id: int in arena._enemies.keys():
		arena.sim.debug_override_health(actor_id, 0.0)
	var connection: ConnectionPlan = plan.connections[0]
	var threshold := Vector3(connection.aperture.get_center().x, 0.0, connection.aperture.get_center().y)

	assert_true(_walk_toward(arena, threshold), "the Envoy must be able to stand in the doorway")
	var far_room: RoomPlan = plan.room_by_id(connection.room_ids.y)
	assert_true(_walk_toward(arena, far_room.centre()), "and must be able to keep going through it")


# --- THE LOCK-IN ENCOUNTER -----------------------------------------------------------

func test_entering_the_combat_room_seals_it_and_wakes_the_roster() -> void:
	var arena: Node3D = _boot()
	var plan: FloorPlan = _plan_of(arena)
	var room: RoomPlan = _combat_room(plan)
	assert_eq(arena.sim.debug_describe_encounters()["active_lock"], -1, "sanity: nothing is sealed at the start")

	assert_true(_walk_toward(arena, room.centre()), "the Envoy must be able to reach the fight")
	assert_eq(arena.sim.debug_describe_encounters()["active_lock"], room.room_id, "entering must seal the room")
	assert_eq(arena.sim._encounter_state[room.room_id], "active")


## BOTH SIDES (ruled). Neither the player nor any living roster member may leave through a
## closed connection -- and because the seal is the same per-actor region every displacement
## seam already consults, this holds for knockback and burrow too, not only walking.
func test_a_sealed_encounter_confines_the_envoy_and_the_roster() -> void:
	var arena: Node3D = _boot()
	var plan: FloorPlan = _plan_of(arena)
	var room: RoomPlan = _combat_room(plan)
	assert_true(_walk_toward(arena, room.centre()))

	# Try hard to walk back out the way we came in.
	var envoy_id: int = _envoy(arena)
	for i in 400:
		arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": Vector3(0, 0, 1)})] as Array[Command], DT)
	assert_true(_inside(room.rect, arena.sim.entities[envoy_id]),
		"the Envoy escaped a sealed encounter at %s" % arena.sim.entities[envoy_id])

	for actor_id: int in arena._enemies.keys():
		assert_true(_inside(room.rect, arena.sim.entities[actor_id]),
			"roster actor %d left the sealed encounter" % actor_id)


func test_clearing_the_roster_reopens_the_room_permanently() -> void:
	var arena: Node3D = _boot()
	var plan: FloorPlan = _plan_of(arena)
	var room: RoomPlan = _combat_room(plan)
	assert_true(_walk_toward(arena, room.centre()))
	assert_eq(arena.sim._encounter_state[room.room_id], "active", "sanity: sealed")

	for actor_id: int in arena._enemies.keys():
		arena.sim.debug_override_health(actor_id, 0.0)
	arena.sim.tick([] as Array[Command], DT)

	assert_eq(arena.sim._encounter_state[room.room_id], "cleared")
	assert_eq(arena.sim.debug_describe_encounters()["active_lock"], -1, "the lock must lift")
	assert_true(_walk_toward(arena, plan.end_marker),
		"after clearing, progression must continue to the end of the floor")

	# Permanent: walking back through does not restart the fight.
	assert_true(_walk_toward(arena, room.centre()))
	assert_eq(arena.sim._encounter_state[room.room_id], "cleared", "a cleared room must never re-arm")


## Combat still works, and still works INSIDE its room. Room confinement must not have made
## the fight spatially incoherent -- the enemies have to be able to reach the player.
func test_combat_runs_normally_inside_the_sealed_room() -> void:
	var arena: Node3D = _boot()
	var room: RoomPlan = _combat_room(_plan_of(arena))
	var envoy_id: int = _envoy(arena)
	# SURVIVABILITY FOR MEASUREMENT ONLY, never a balance claim. A sealed room removes retreat,
	# so the shipped 30 HP Envoy dies to a full roster before this window opens -- and a dead
	# player produces no AI activity at all, which would make this assert on the wrong thing.
	arena.sim.debug_override_health(envoy_id, 5000.0)
	assert_true(_walk_toward(arena, room.centre()))
	var starting_health: float = arena.sim._health[envoy_id]

	# A FIXED window, never "stop at the first hit": an attack committed during the walk-in can
	# land on the very first tick of this loop, and breaking there would end the measurement
	# before a single telegraph was observed -- which is exactly how this test first lied.
	var telegraphs: int = 0
	for i in 600:
		for event in arena.sim.tick([] as Array[Command], DT):
			if event.kind == "attack_telegraph":
				telegraphs += 1
	assert_gt(telegraphs, 0, "a woken roster must commit attacks")
	assert_lt(arena.sim._health[envoy_id], starting_health, "and must be able to land them")

	# Spatially coherent: confinement must not have left the fight happening somewhere else.
	for actor_id: int in arena._enemies.keys():
		assert_true(_inside(room.rect, arena.sim.entities[actor_id]),
			"roster actor %d fought its way out of the room" % actor_id)


# --- REPRODUCIBILITY -----------------------------------------------------------------

func test_two_arenas_on_the_same_seed_build_identical_floors() -> void:
	var first: Node3D = _boot()
	var second: Node3D = load("res://game/arena/arena.tscn").instantiate()
	second.run_seed = first.run_seed
	add_child_autofree(second)

	assert_eq(second._enemies.size(), first._enemies.size(), "same seed must build the same sized roster")
	assert_eq(second.sim._bounds.rects, first.sim._bounds.rects, "and the same rooms")
	var first_positions: Array = []
	var second_positions: Array = []
	for actor_id: int in first._enemies.keys():
		first_positions.append(first.sim.entities[actor_id])
	for actor_id: int in second._enemies.keys():
		second_positions.append(second.sim.entities[actor_id])
	first_positions.sort()
	second_positions.sort()
	assert_eq(second_positions, first_positions, "and the same enemies standing in the same places")
