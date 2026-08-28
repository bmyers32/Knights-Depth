extends GutTest
## DepthGenerator determinism and placement law (GAME-RULES §1.3 seeded gen, §5 M2 gate).

const _DEPTH: int = 1


func _stratum() -> StratumConfig:
	return ContentDB.get_resource(&"stratum", &"archive")


# --- DETERMINISM ---------------------------------------------------------------------

func test_same_seed_and_depth_produce_an_identical_plan() -> void:
	for seed_value in [0, 1, 7, 12345, -99]:
		var first: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		var second: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		assert_eq(first.to_dict(), second.to_dict(),
			"seed %d must regenerate identically -- a run is only reproducible if this holds" % seed_value)


## PURITY, not just repeatability. The generator creates its RNG inside generate(), so no
## state can carry between calls -- which means interleaving other generations must not
## perturb a result. This is the property that makes floor COUNT unable to shift a floor's
## contents, and it is what a shared/module-level RNG would silently break.
func test_generation_is_independent_of_call_order() -> void:
	var baseline: Dictionary = DepthGenerator.generate(42, _DEPTH).to_dict()
	for noise_seed in [1, 2, 3, 4, 5]:
		DepthGenerator.generate(noise_seed, _DEPTH + noise_seed)
	assert_eq(DepthGenerator.generate(42, _DEPTH).to_dict(), baseline,
		"generating other floors first must not change this one")


func test_different_depths_of_one_run_are_different_floors() -> void:
	var first: Dictionary = DepthGenerator.generate(2026, 1).to_dict()
	var second: Dictionary = DepthGenerator.generate(2026, 2).to_dict()
	assert_ne(first, second, "depth must reach the floor seed, or every floor of a run is the same room")
	assert_ne(DepthGenerator.derive_floor_seed(2026, 1), DepthGenerator.derive_floor_seed(2026, 2))


func test_the_plan_reports_its_own_provenance() -> void:
	var plan: FloorPlan = DepthGenerator.generate(555, 3)
	assert_eq(plan.run_seed, 555, "a bug report is seed + command log -- a plan must name its run")
	assert_eq(plan.depth, 3)
	assert_eq(plan.floor_seed, DepthGenerator.derive_floor_seed(555, 3))
	assert_eq(plan.stratum_id, _stratum().stratum_id)


# --- PLACEMENT LAW -------------------------------------------------------------------
# "The generator does not place actors the sim would reject." Every assertion below uses
# the SIM's own predicate (WalkableBounds), never a reimplementation of it.

func test_every_generated_placement_is_legal_across_many_seeds() -> void:
	var stratum: StratumConfig = _stratum()
	var total_spawns: int = 0
	for seed_value in 120:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		var bounds: WalkableBounds = plan.make_bounds()
		assert_true(bounds.is_inside(plan.entry_point),
			"seed %d: the Envoy's own entry point must be inside the floor" % seed_value)
		for spawn in plan.spawns:
			total_spawns += 1
			var position: Vector3 = spawn["position"]
			assert_true(bounds.is_inside(position),
				"seed %d: spawn at %s is outside the walkable floor -- the sim would refuse it" % [seed_value, position])
			assert_true(position.distance_to(plan.entry_point) >= stratum.min_spawn_distance_from_entry - 0.001,
				"seed %d: spawn at %s opens the floor already on top of the player" % [seed_value, position])
			assert_true(stratum.enemy_keys.has(spawn["enemy_key"]),
				"seed %d: '%s' is not in this stratum's family pool" % [seed_value, spawn["enemy_key"]])
	assert_gt(total_spawns, 300, "sanity: the sweep really generated a population to check")


func test_generated_spawns_never_stack_on_each_other() -> void:
	var minimum: float = _stratum().min_spawn_separation
	for seed_value in 120:
		var spawns: Array[Dictionary] = DepthGenerator.generate(seed_value, _DEPTH).spawns
		for i in spawns.size():
			for j in range(i + 1, spawns.size()):
				var separation: float = spawns[i]["position"].distance_to(spawns[j]["position"])
				assert_true(separation >= minimum - 0.001,
					"seed %d: two spawns are %.2f apart (minimum %.2f) -- with no body collision they read as one broken actor" % [seed_value, separation, minimum])


func test_a_floor_is_never_empty_and_respects_its_authored_counts() -> void:
	var stratum: StratumConfig = _stratum()
	for seed_value in 60:
		var count: int = DepthGenerator.generate(seed_value, _DEPTH).spawns.size()
		assert_true(count > 0, "seed %d generated an empty floor" % seed_value)
		assert_true(count <= stratum.spawn_count_max,
			"seed %d generated %d spawns, above the authored maximum" % [seed_value, count])


func test_the_chamber_stays_within_its_authored_size_range() -> void:
	var stratum: StratumConfig = _stratum()
	for seed_value in 60:
		var plan: FloorPlan = DepthGenerator.generate(seed_value, _DEPTH)
		assert_eq(plan.walkable_rects.size(), 1, "Slice 1 authors exactly one chamber per floor")
		var rect: Rect2 = plan.walkable_rects[0]
		assert_between(rect.size.x, float(stratum.chamber_min_size.x), float(stratum.chamber_max_size.x))
		assert_between(rect.size.y, float(stratum.chamber_min_size.y), float(stratum.chamber_max_size.y))


# --- PERFORMANCE ---------------------------------------------------------------------

## GAME-RULES §5 M2: "gen time <100 ms/floor". Measured now, while it is trivially true, so
## the gate item has a live instrument rather than an assumption to check at milestone close.
func test_generation_stays_far_under_the_hundred_millisecond_gate() -> void:
	var started: int = Time.get_ticks_usec()
	for seed_value in 50:
		DepthGenerator.generate(seed_value, _DEPTH)
	var per_floor_ms: float = (Time.get_ticks_usec() - started) / 1000.0 / 50.0
	gut.p("generation: %.3f ms/floor" % per_floor_ms)
	assert_lt(per_floor_ms, 100.0, "GAME-RULES §5 M2 budget is 100 ms per floor")
