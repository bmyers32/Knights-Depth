extends GutTest
## END-TO-END: run seed -> FloorPlan -> load_floor -> FloorBuilder -> ordinary combat.
##
## The unit tests each prove one seam. This proves the seams COMPOSE in the real arena, on a
## real generated floor, driven through the real _physics_process -- which is the only thing
## that answers "is Slice 1 actually playable?" short of a human at the keyboard.
##
## BOOT-CLEAN IS NOT INTERACT-CLEAN (BRAIN, and this repo's own regression history): loading
## arena.tscn headlessly proves nothing about whether generated enemies can find, approach and
## hit the Envoy inside their generated room.

const DT := 1.0 / 30.0


## Boots the real arena on a seed whose depth-1 floor is known to contain `family`, with every
## enemy already aggroed so a bounded test window can actually observe combat.
func _boot(family: StringName, force_aggro: bool = true) -> Node3D:
	var chosen_seed: int = -1
	for candidate in 256:
		for spawn in DepthGenerator.generate(candidate, 1).spawns:
			if spawn["enemy_key"] == family:
				chosen_seed = candidate
				break
		if chosen_seed >= 0:
			break
	assert_true(chosen_seed >= 0, "no run seed below 256 produces a '%s'" % family)
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.run_seed = chosen_seed
	arena.debug_force_aggro = force_aggro
	add_child_autofree(arena)
	return arena


func test_the_arena_boots_a_generated_floor_with_a_live_roster() -> void:
	var arena: Node3D = _boot(&"fang")
	assert_gt(arena._enemies.size(), 0, "a generated floor must actually populate the arena")
	assert_not_null(arena.sim._bounds, "the sim must have adopted the floor's walkable law")
	assert_true(arena.sim._bounds.is_inside(arena.sim.entities[arena.envoy.actor_id]),
		"the Envoy must start inside the room")


## §1.3's visibility law: the active seed is reproducible from the screen, not from stdout.
func test_the_active_seed_is_visible_on_screen() -> void:
	var arena: Node3D = _boot(&"fang")
	var shown: String = arena._seed_label.text
	assert_true(shown.contains(str(arena.run_seed)), "the run seed must be on screen, got '%s'" % shown)
	assert_true(shown.contains("depth 1"), "and the depth with it, got '%s'" % shown)
	assert_true(shown.contains("archive"), "and the stratum, got '%s'" % shown)


## Actor ids are allocated by the driver now, not authored on scene children. They must be
## unique and must not collide with the Envoy.
func test_generated_actors_receive_unique_ids_that_never_collide_with_the_envoy() -> void:
	var arena: Node3D = _boot(&"fang")
	var seen: Dictionary = {}
	for actor_id: int in arena._enemies.keys():
		assert_false(seen.has(actor_id), "actor_id %d was allocated twice" % actor_id)
		assert_ne(actor_id, arena.envoy.actor_id, "an enemy must never take the Envoy's id")
		seen[actor_id] = true
	assert_eq(seen.size(), arena._enemies.size())


## THE INTEGRATED CLAIM: generated placements produce a floor where the AI can actually find
## and fight the player, and nothing leaves the room while it happens.
func test_combat_runs_normally_inside_the_generated_floor() -> void:
	var arena: Node3D = _boot(&"fang")
	var envoy_id: int = arena.envoy.actor_id
	var starting_health: float = arena.sim._health[envoy_id]

	var telegraphed: bool = false
	for i in 900:
		var events: Array[Event] = arena.sim.tick(arena.envoy.build_commands(arena.sim.tick_count), DT)
		for event in events:
			if event.kind == "attack_telegraph":
				telegraphed = true
		for actor_id: int in arena.sim.entities.keys():
			assert_true(arena.sim._bounds.is_inside(arena.sim.entities[actor_id]),
				"actor %d left the floor at %s on tick %d" % [actor_id, arena.sim.entities[actor_id], i])
		if arena.sim._health[envoy_id] < starting_health:
			break

	assert_true(telegraphed, "generated enemies must reach the Envoy and commit attacks -- if this fails, the floor is too big or spawns are too far")
	assert_lt(arena.sim._health[envoy_id], starting_health,
		"an aggroed roster must actually be able to land a hit on a floor it was generated onto")


## The player cannot leave the room by walking, driven through the real driver's own Command
## path rather than by poking the sim.
func test_the_envoy_cannot_walk_out_of_the_generated_room() -> void:
	var arena: Node3D = _boot(&"fang", false)
	var envoy_id: int = arena.envoy.actor_id
	for direction in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		for i in 200:
			arena.sim.tick([Command.new(arena.sim.tick_count, envoy_id, "move", {"direction": direction})] as Array[Command], DT)
		assert_true(arena.sim._bounds.is_inside(arena.sim.entities[envoy_id]),
			"walking %s for 200 ticks left the room at %s" % [direction, arena.sim.entities[envoy_id]])


## Reproducibility as a human would check it: same seed, same floor, twice.
func test_two_arenas_on_the_same_seed_build_identical_floors() -> void:
	var first: Node3D = _boot(&"fang", false)
	var second: Node3D = load("res://game/arena/arena.tscn").instantiate()
	second.run_seed = first.run_seed
	add_child_autofree(second)

	assert_eq(second._enemies.size(), first._enemies.size(), "same seed must build the same sized roster")
	assert_eq(second.sim._bounds.rects, first.sim._bounds.rects, "and the same room")
	var first_positions: Array = []
	var second_positions: Array = []
	for actor_id: int in first._enemies.keys():
		first_positions.append(first.sim.entities[actor_id])
	for actor_id: int in second._enemies.keys():
		second_positions.append(second.sim.entities[actor_id])
	first_positions.sort()
	second_positions.sort()
	assert_eq(second_positions, first_positions, "and the same enemies standing in the same places")
