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


func test_get_resource_returns_ooze_enemy_stats() -> void:
	var stats: Resource = ContentDB.get_resource(&"enemy", &"ooze")
	assert_not_null(stats)


func test_get_resource_returns_watcher_enemy_stats() -> void:
	var stats: Resource = ContentDB.get_resource(&"enemy", &"watcher")
	assert_not_null(stats)


func test_get_resource_returns_damage_matrix() -> void:
	var matrix: Resource = ContentDB.get_resource(&"combat", &"damage_matrix")
	assert_not_null(matrix)


func test_get_resource_returns_burn_status_stats() -> void:
	var stats: Resource = ContentDB.get_resource(&"status", &"burn")
	assert_not_null(stats)


func test_get_resource_returns_status_priority_table() -> void:
	var table: Resource = ContentDB.get_resource(&"status", &"priority_table")
	assert_not_null(table)


func test_get_resource_returns_sword_burn_a_weapon_stats() -> void:
	var stats: Resource = ContentDB.get_resource(&"weapon", &"sword_burn_A")
	assert_not_null(stats)


func test_get_resource_returns_typed_dev_gun_variants() -> void:
	for weapon_id in [&"gun_pierce_A", &"gun_arc_A", &"gun_umbral_A"]:
		var stats: Resource = ContentDB.get_resource(&"weapon", weapon_id)
		assert_not_null(stats, "%s should resolve as a real weapon resource" % weapon_id)


## Status proc chance (GAME-RULES §1.3 combat RNG) — sword_A/guns never roll;
## sword_burn_A's 0.15 is the only M1 content that draws from the stream this
## session (calibrated down from 0.3 after the clump-burn replay, 2026-08-04).
func test_sword_a_has_zero_status_proc_chance() -> void:
	var stats: SwordStats = ContentDB.get_resource(&"weapon", &"sword_A")
	assert_eq(stats.status_proc_chance, 0.0)


func test_sword_burn_a_has_provisional_proc_chance() -> void:
	var stats: SwordStats = ContentDB.get_resource(&"weapon", &"sword_burn_A")
	assert_almost_eq(stats.status_proc_chance, 0.15, 0.001)


func test_guns_have_zero_status_proc_chance() -> void:
	for weapon_id in [&"wand_A", &"gun_pierce_A", &"gun_arc_A", &"gun_umbral_A"]:
		var stats: GunStats = ContentDB.get_resource(&"weapon", weapon_id)
		assert_eq(stats.status_proc_chance, 0.0, "%s must default to zero proc chance" % weapon_id)


func test_integration_registered_entity_moves_at_content_db_speed() -> void:
	var stats: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	var sim := SimWorld.new()
	sim.add_entity(1, Vector3.ZERO, stats.move_speed)
	var commands: Array[Command] = [Command.new(0, 1, "move", {"direction": Vector3.RIGHT})]
	sim.tick(commands, 1.0)
	assert_almost_eq(sim.entities[1].x, stats.move_speed, 0.0001)
