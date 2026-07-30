extends GutTest

var sim: ToySimWorld


func before_each() -> void:
	sim = ToySimWorld.new()


func test_tick_with_no_commands_does_not_move() -> void:
	sim.tick([], 1.0 / 30.0)
	assert_eq(sim.position, Vector3.ZERO)


func test_move_command_advances_position_along_direction() -> void:
	var command := {"tick": 0, "actor_id": 1, "kind": "move", "params": {"direction": Vector3.RIGHT}}
	var events: Array = sim.tick([command], 1.0 / 30.0)
	assert_gt(sim.position.x, 0.0, "position should move along +X")
	assert_eq(sim.position.y, 0.0)
	assert_eq(sim.position.z, 0.0)
	assert_eq(events.size(), 1)
	assert_eq(events[0]["kind"], "moved")


func test_move_direction_is_normalized() -> void:
	var command := {"tick": 0, "actor_id": 1, "kind": "move", "params": {"direction": Vector3(3, 0, 0)}}
	sim.tick([command], 1.0)
	assert_almost_eq(sim.position.x, ToySimWorld.MOVE_SPEED, 0.0001, "unnormalized input should not move faster")


func test_tick_count_increments_deterministically() -> void:
	sim.tick([], 1.0 / 30.0)
	sim.tick([], 1.0 / 30.0)
	assert_eq(sim.tick_count, 2)
