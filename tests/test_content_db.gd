extends GutTest


func test_get_resource_returns_envoy_default_stats() -> void:
	var stats: Resource = ContentDB.get_resource(&"envoy", &"default")
	assert_not_null(stats)


func test_get_resource_envoy_default_has_positive_move_speed() -> void:
	var stats: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	assert_gt(stats.move_speed, 0.0)


func test_get_resource_unknown_family_pushes_error_and_returns_null() -> void:
	var result: Resource = ContentDB.get_resource(&"nonexistent", &"default")
	assert_push_error("unknown family 'nonexistent'")
	assert_null(result)


func test_get_resource_unknown_id_pushes_error_and_returns_null() -> void:
	var result: Resource = ContentDB.get_resource(&"envoy", &"nonexistent")
	assert_push_error("unknown id 'nonexistent' in family 'envoy'")
	assert_null(result)


func test_get_resource_returns_sword_a_weapon_stats() -> void:
	var stats: Resource = ContentDB.get_resource(&"weapon", &"sword_A")
	assert_not_null(stats)


func test_get_resource_returns_fang_enemy_stats() -> void:
	var stats: Resource = ContentDB.get_resource(&"enemy", &"fang")
	assert_not_null(stats)


func test_get_resource_returns_damage_matrix() -> void:
	var matrix: Resource = ContentDB.get_resource(&"combat", &"damage_matrix")
	assert_not_null(matrix)


func test_integration_registered_entity_moves_at_content_db_speed() -> void:
	var stats: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	var sim := SimWorld.new()
	sim.add_entity(1, Vector3.ZERO, stats.move_speed)
	var commands: Array[Command] = [Command.new(0, 1, "move", {"direction": Vector3.RIGHT})]
	sim.tick(commands, 1.0)
	assert_almost_eq(sim.entities[1].x, stats.move_speed, 0.0001)
