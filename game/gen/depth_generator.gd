class_name DepthGenerator
extends RefCounted
## DepthGenerator.generate(seed, depth) -> FloorPlan — a PURE FUNCTION of its inputs
## (CLAUDE.md Core Interfaces; signature is pinned there under "do not drift").
##
## Purity is mechanical, not aspirational: the RNG is created fresh INSIDE generate(), so
## no state carries between calls and the same (seed, depth) yields the same floor
## regardless of what was generated before it. That also satisfies GAME-RULES §1.3's
## separate-streams law by construction — there is no shared object through which a
## generation draw could perturb SimWorld._combat_rng, and floor COUNT cannot shift combat
## rolls either.
##
## Stratum parameters resolve internally through ContentDB so the public signature stays
## exactly two ints; _generate_from below is the pure core that takes plain params, which is
## the same driver-unpacks-the-Resource boundary ContentRegistrar draws for the sim.

## Slice 1 generates for the Archive only. Depth -> stratum selection (Archive 1-3, Foundry
## 4-5 per GAME-RULES §5) arrives with the second stratum; hardcoding a lookup table for one
## entry would be a schema with no consumer.
const _SLICE_1_STRATUM: StringName = &"archive"

## 64-bit odd constants (PCG's multiplier and increment). Chosen over String.hash() on
## purpose: hash() is stable within an engine version but NOT guaranteed across them, and
## GAME-RULES §5's golden-seed gate has to survive a Godot patch bump. GDScript ints are
## int64 and multiplication overflow wraps two's-complement, which is deterministic.
const _SEED_MIX_A: int = 6364136223846793005
const _SEED_MIX_B: int = 1442695040888963407


static func generate(seed: int, depth: int) -> FloorPlan:
	var stratum: StratumConfig = ContentDB.get_resource(&"stratum", _SLICE_1_STRATUM)
	return _generate_from(seed, depth, stratum)


## Derives this floor's seed from the run seed and the depth. Every floor of a run draws
## from the same run seed but a different stream, so re-entering depth 3 rebuilds depth 3
## and never depth 2's layout.
static func derive_floor_seed(run_seed: int, depth: int) -> int:
	var mixed: int = run_seed * _SEED_MIX_A + depth * _SEED_MIX_B
	mixed ^= mixed >> 31
	mixed = mixed * _SEED_MIX_A
	mixed ^= mixed >> 29
	return mixed


static func _generate_from(run_seed: int, depth: int, stratum: StratumConfig) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.run_seed = run_seed
	plan.depth = depth
	plan.floor_seed = derive_floor_seed(run_seed, depth)
	plan.stratum_id = stratum.stratum_id

	var rng := RandomNumberGenerator.new()
	rng.seed = plan.floor_seed

	# CHAMBER. Centred on the origin so the fixed camera's framing holds (see
	# StratumConfig.chamber_min_size's camera note).
	var width: int = rng.randi_range(stratum.chamber_min_size.x, stratum.chamber_max_size.x)
	var depth_extent: int = rng.randi_range(stratum.chamber_min_size.y, stratum.chamber_max_size.y)
	var rect := Rect2(-width * 0.5, -depth_extent * 0.5, float(width), float(depth_extent))
	plan.walkable_rects = [rect]

	# ENTRY at the middle of the south (+Z) edge: the player arrives with the whole room
	# ahead, which is what makes min_spawn_distance_from_entry a fair-opening rule rather
	# than an arbitrary radius.
	plan.entry_point = Vector3(0.0, 0.0, rect.end.y - stratum.entry_edge_margin)

	var bounds: WalkableBounds = plan.make_bounds()
	plan.spawns = _place_spawns(rng, stratum, rect, plan.entry_point, bounds)
	return plan


static func _place_spawns(rng: RandomNumberGenerator, stratum: StratumConfig, rect: Rect2, entry_point: Vector3, bounds: WalkableBounds) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []
	var count: int = rng.randi_range(stratum.spawn_count_min, stratum.spawn_count_max)
	var inner := Rect2(
		rect.position + Vector2.ONE * stratum.spawn_edge_margin,
		rect.size - Vector2.ONE * stratum.spawn_edge_margin * 2.0,
	)
	for index in count:
		# The family draw happens BEFORE placement and exactly once per spawn, so a
		# rejected position never shifts which family gets placed. Rejection sampling that
		# also re-rolled identity would make the roster depend on geometry luck.
		var enemy_key: StringName = stratum.enemy_keys[rng.randi_range(0, stratum.enemy_keys.size() - 1)]
		var placed: Dictionary = _sample_position(rng, stratum, inner, entry_point, bounds, spawns)
		if placed.is_empty():
			# Budget exhausted: drop this spawn. A floor with one fewer enemy is a fine
			# floor; one with an illegally-placed enemy is a defect the sim would reject.
			continue
		spawns.append({"enemy_key": enemy_key, "position": placed["position"]})
	return spawns


static func _sample_position(rng: RandomNumberGenerator, stratum: StratumConfig, inner: Rect2, entry_point: Vector3, bounds: WalkableBounds, placed: Array[Dictionary]) -> Dictionary:
	for _attempt in stratum.max_spawn_placement_attempts:
		var candidate := Vector3(
			rng.randf_range(inner.position.x, inner.end.x),
			0.0,
			rng.randf_range(inner.position.y, inner.end.y),
		)
		# The sim's OWN predicate, not a reimplementation of it — this is the whole reason
		# WalkableBounds lives in sim/ and is imported here.
		if not bounds.is_inside(candidate):
			continue
		if candidate.distance_to(entry_point) < stratum.min_spawn_distance_from_entry:
			continue
		var separated: bool = true
		for existing in placed:
			if candidate.distance_to(existing["position"]) < stratum.min_spawn_separation:
				separated = false
				break
		if separated:
			return {"position": candidate}
	return {}
