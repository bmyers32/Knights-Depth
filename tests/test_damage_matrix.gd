extends GutTest
## Content-lint: asserts the GAME-RULES §3 damage-matrix invariants against the real
## ContentDB resource (the matrix ships complete — six families locked, even though
## only Fang has an enemy resource this session).

var matrix: DamageMatrix


func before_each() -> void:
	matrix = ContentDB.get_resource(&"combat", &"damage_matrix")


func test_matrix_resource_loads() -> void:
	assert_not_null(matrix)


func test_each_non_force_type_is_weakness_of_exactly_two_families() -> void:
	for damage_type in ["pierce", "arc", "umbral"]:
		var count := 0
		for family in matrix.families:
			if matrix.families[family].get("weak_to", "") == damage_type:
				count += 1
		assert_eq(count, 2, "%s should be the weakness of exactly two families" % damage_type)


func test_force_is_never_a_weakness_or_resistance() -> void:
	for family in matrix.families:
		var row: Dictionary = matrix.families[family]
		assert_ne(row.get("weak_to", ""), "force", "%s should never be weak to Force" % family)
		assert_ne(row.get("resists", ""), "force", "%s should never resist Force" % family)


func test_each_family_resists_exactly_one_non_force_type() -> void:
	for family in matrix.families:
		var row: Dictionary = matrix.families[family]
		var resists: String = row.get("resists", "")
		assert_true(resists in ["pierce", "arc", "umbral"], "%s's resistance should be one of the three non-Force types" % family)


func test_matrix_ships_complete_with_all_six_families() -> void:
	var expected := ["fang", "dread", "tinker", "ooze", "hollow", "watcher"]
	for family in expected:
		assert_true(matrix.families.has(family), "%s should be present in the matrix (GAME-RULES §3: matrix ships complete)" % family)
