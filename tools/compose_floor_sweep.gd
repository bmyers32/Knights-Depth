extends SceneTree
## SEED SWEEP for the ADR-001 S2 composer: composes the prototype recipe for N run seeds and
## reports what happened -- successes, reseeds, fallbacks, rejection reasons, route shapes and
## lengths, piece choices, distinct spatial signatures, and generation time (p50 / p99).
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/compose_floor_sweep.gd -- --seeds=200 --depth=1
## Writes build/compose_sweep.json (build/ is untracked) and prints the aggregate.
##
## No autoloads exist under -s: content is loaded by path, never through ContentDB. The S0
## progression validator runs on every composed floor FOR INFORMATION (S3 puts it in the loop).

const RECIPE_PATH := "res://game/content/floors/recipes/proto_archive.tres"
const OUT_PATH := "res://build/compose_sweep.json"


func _init() -> void:
	var seeds: int = int(_arg("seeds", "100"))
	var depth: int = int(_arg("depth", "1"))
	var recipe: FloorRecipe = load(RECIPE_PATH)
	var rules: Dictionary = _rules()
	var radii: Dictionary = _radii(recipe)
	var rows: Array[Dictionary] = []
	var times: Array[float] = []
	var totals: Dictionary = {"composed": 0, "fallback": 0, "structural": 0, "reseeded": 0, "progression_pass": 0, "progression_fail": 0, "progression_unsupported": 0}
	var rejections: Dictionary = {}
	var signatures: Dictionary = {}
	var casts: Dictionary = {}
	var shapes: Dictionary = {}
	var lengths: Dictionary = {}
	for run_seed: int in seeds:
		var floor_seed: int = SeedMix.derive(run_seed, depth)
		var result: FloorComposer.ComposeResult = FloorComposer.compose(recipe, floor_seed, depth, radii)
		var report: GenerationReport = result.report
		var row: Dictionary = report.to_dict()
		row["run_seed"] = run_seed
		times.append(report.elapsed_usec / 1000.0)
		for reason: StringName in report.rejections:
			rejections[reason] = int(rejections.get(reason, 0)) + int(report.rejections[reason])
		if report.fallback:
			totals["fallback"] += 1
			if report.structural:
				totals["structural"] += 1
		else:
			totals["composed"] += 1
			if report.attempts > 1:
				totals["reseeded"] += 1
			signatures[report.spatial_signature()] = int(signatures.get(report.spatial_signature(), 0)) + 1
			for node: StringName in report.cast:
				var choice: String = "%s=%s/%s" % [node, report.cast[node]["piece_id"], report.cast[node]["transform"]]
				casts[choice] = int(casts.get(choice, 0)) + 1
			for edge: String in report.routes:
				var route: Dictionary = report.routes[edge]
				var shape_key: String = "%s:%s" % [edge, route["shape"]]
				shapes[shape_key] = int(shapes.get(shape_key, 0)) + 1
				if not lengths.has(edge):
					lengths[edge] = []
				lengths[edge].append(float(route["length"]))
			var plan := FloorPlan.new()
			plan.stratum_id = result.layout.stratum_id
			LayoutCompiler.compile(result.layout, plan)
			var progression: ProgressionReport = ProgressionValidator.check(plan, rules)
			row["progression"] = String(progression.outcome)
			row["progression_steps"] = progression.trace.size()
			totals["progression_" + String(progression.outcome)] += 1
		rows.append(row)
		print("%4d  %s" % [run_seed, report.summary().split("\n")[0]])
	times.sort()
	var aggregate: Dictionary = {
		"seeds": seeds, "depth": depth, "totals": totals, "rejections": rejections,
		"distinct_signatures": signatures.size(), "casts": casts, "shapes": shapes,
		"lengths": _bands(lengths),
		"time_ms": {"p50": _percentile(times, 0.50), "p90": _percentile(times, 0.90), "p99": _percentile(times, 0.99), "max": times[times.size() - 1] if not times.is_empty() else 0.0},
	}
	print(JSON.stringify(aggregate, "  "))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"aggregate": aggregate, "rows": rows}, "\t"))
	file.close()
	print("wrote ", OUT_PATH)
	quit()


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.get_slice("=", 1)
	return fallback


## The sim's own meanings, read from the content resources by path.
func _rules() -> Dictionary:
	var envoy: Resource = load("res://game/content/envoy/envoy_stats.tres")
	var sword: Resource = load("res://game/content/weapons/sword_stats.tres")
	return {"body_radius": envoy.combat_radius, "attack_reach": sword.reach, "pickup_reach": envoy.pickup_reach}


func _radii(recipe: FloorRecipe) -> Dictionary:
	var radii: Dictionary = {}
	for key: StringName in recipe.stratum.enemy_keys:
		var stats: Resource = load("res://game/content/enemies/%s/%s_stats.tres" % [key, key])
		if stats != null:
			radii[key] = stats.combat_radius
	return radii


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index: int = clampi(int(ceil(fraction * sorted_values.size())) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _bands(lengths: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for edge: String in lengths:
		var values: Array = lengths[edge]
		values.sort()
		out[edge] = {"min": values[0], "max": values[values.size() - 1], "n": values.size()}
	return out
