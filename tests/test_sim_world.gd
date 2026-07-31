extends GutTest

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()


func test_tick_with_no_commands_does_not_move() -> void:
	var commands: Array[Command] = []
	sim.tick(commands, 1.0 / 30.0)
	assert_eq(sim.entities.get(0, Vector3.ZERO), Vector3.ZERO)


func test_move_command_advances_position_along_direction() -> void:
	var commands: Array[Command] = [Command.new(0, 1, "move", {"direction": Vector3.RIGHT, "speed": 4.0})]
	var events: Array[Event] = sim.tick(commands, 1.0 / 30.0)
	var position: Vector3 = sim.entities[1]
	assert_gt(position.x, 0.0, "position should move along +X")
	assert_eq(position.y, 0.0)
	assert_eq(position.z, 0.0)
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, "moved")


func test_move_direction_is_normalized() -> void:
	var commands: Array[Command] = [Command.new(0, 1, "move", {"direction": Vector3(3, 0, 0), "speed": 4.0})]
	sim.tick(commands, 1.0)
	assert_almost_eq(sim.entities[1].x, 4.0, 0.0001, "unnormalized input should not move faster")


func test_actors_move_independently() -> void:
	var commands: Array[Command] = [
		Command.new(0, 1, "move", {"direction": Vector3.RIGHT, "speed": 4.0}),
		Command.new(0, 2, "move", {"direction": Vector3.LEFT, "speed": 4.0}),
	]
	sim.tick(commands, 1.0)
	assert_gt(sim.entities[1].x, 0.0)
	assert_lt(sim.entities[2].x, 0.0)


func test_tick_count_increments_deterministically() -> void:
	var commands: Array[Command] = []
	sim.tick(commands, 1.0 / 30.0)
	sim.tick(commands, 1.0 / 30.0)
	assert_eq(sim.tick_count, 2)


func test_ticks_1000_times_headless() -> void:
	var commands: Array[Command] = []
	for i in range(1000):
		sim.tick(commands, 1.0 / 30.0)
	assert_eq(sim.tick_count, 1000)
