extends SceneTree
## SEED SWEEP for the ADR-001 S2 composer: composes the prototype recipe for N run seeds and
## reports what happened -- successes, reseeds, fallbacks, rejection reasons, route shapes and
## lengths, piece choices, distinct spatial signatures, and generation time (p50 / p99).
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/compose_floor_sweep.gd -- --seeds=200 --depth=1 --recipe=proto_archive
## Writes build/compose_sweep_<recipe>.json (build/ is untracked) and prints the aggregate.
##
## No autoloads exist under -s: content is loaded by path, never through ContentDB. The S0
## progression validator and the S2.5 spawn-spacing rule run on every composed floor FOR
## INFORMATION (S3 puts the validator in the loop).
##
## S3a: every composed floor is also measured by tools/route_metrics.gd -- the patch graph's
## topology, and, when the floor carries one key and one receiver, the WALKED length of each
## mandatory leg under the door states the sim would have at that moment, the carry with its
## closing edges shut (what the return saves), the pieces the carry crosses, and the headings
## of the whole mandatory walk. Diagnostics only: nothing here is a pass/fail verdict.
##
## S3b: spawn spacing is IN the composer (the reaches are passed to compose), and every composed
## floor of a recipe that declares progression is held to its declarations by ObjectiveIntegrity,
## with keys set down anywhere. Two spacing margins are reported per floor, kept apart on purpose:
## from the activating region's CENTRE (what the composer rejects on) and from the region's NEAREST
## POINT (a stricter reading, diagnostic only -- three accepted shipped rooms fail it).

const RECIPE_DIR := "res://game/content/floors/recipes/"
const RouteMetrics := preload("res://tools/route_metrics.gd")
const SpawnReaches := preload("res://tools/spawn_reaches.gd")


func _init() -> void:
	var seeds: int = int(_arg("seeds", "100"))
	var depth: int = int(_arg("depth", "1"))
	var recipe_id: String = _arg("recipe", "proto_archive")
	var recipe: FloorRecipe = load(RECIPE_DIR + recipe_id + ".tres")
	var out_path: String = "res://build/compose_sweep_%s.json" % recipe_id
	var rules: Dictionary = _rules()
	var radii: Dictionary = _radii(recipe)
	var reaches: Dictionary = _reaches(recipe)
	var rows: Array[Dictionary] = []
	var times: Array[float] = []
	var radius: float = float(rules["body_radius"])
	var metrics: Dictionary = {}
	var totals: Dictionary = {"composed": 0, "fallback": 0, "structural": 0, "reseeded": 0, "progression_pass": 0, "progression_fail": 0, "progression_unsupported": 0, "spawn_unsafe": 0,
		"integrity_pass": 0, "integrity_fail": 0, "integrity_unsupported": 0, "integrity_undeclared": 0}
	var integrity_rules: Dictionary = rules.duplicate()
	integrity_rules["set_down_anywhere"] = true
	var integrity_times: Array[float] = []
	var declares: bool = recipe.nodes.any(func(node: Dictionary) -> bool: return node.has("progression"))
	var rejections: Dictionary = {}
	var signatures: Dictionary = {}
	var casts: Dictionary = {}
	var shapes: Dictionary = {}
	var lengths: Dictionary = {}
	for run_seed: int in seeds:
		var floor_seed: int = SeedMix.derive(run_seed, depth)
		var result: FloorComposer.ComposeResult = FloorComposer.compose(recipe, floor_seed, depth, radii, reaches)
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
			var spacing: Array[Dictionary] = EncounterSpacing.findings(result.layout, reaches)
			row["spawn_findings"] = spacing.size()
			if not spacing.is_empty():
				totals["spawn_unsafe"] += 1
			if declares:
				var started: int = Time.get_ticks_usec()
				var integrity: ObjectiveIntegrity.Report = ObjectiveIntegrity.check(recipe, result, plan, integrity_rules)
				integrity_times.append((Time.get_ticks_usec() - started) / 1000.0)
				row["integrity"] = String(integrity.outcome)
				row["integrity_claims"] = integrity.claims.size()
				row["integrity_baseline_states"] = integrity.baseline.states_explored
				if integrity.outcome != ObjectiveIntegrity.OUTCOME_PASS:
					row["integrity_summary"] = integrity.summary()
				totals["integrity_" + String(integrity.outcome)] += 1
			else:
				totals["integrity_undeclared"] += 1
			var measured: Dictionary = RouteMetrics.topology(plan, result.layout)
			measured.merge(_spacing_margins(result.layout, reaches))
			measured.merge(_route_metrics(recipe, result, plan, radius))
			row["metrics"] = measured
			for name: String in measured:
				if typeof(measured[name]) == TYPE_FLOAT or typeof(measured[name]) == TYPE_INT:
					if not metrics.has(name):
						metrics[name] = []
					metrics[name].append(float(measured[name]))
				elif typeof(measured[name]) == TYPE_STRING:
					var tally_key: String = "%s=%s" % [name, measured[name]]
					metrics[tally_key] = [float(metrics.get(tally_key, [0.0])[0]) + 1.0]
		rows.append(row)
		print("%4d  %s" % [run_seed, report.summary().split("\n")[0]])
	times.sort()
	var aggregate: Dictionary = {
		"recipe": recipe_id, "seeds": seeds, "depth": depth, "totals": totals, "rejections": rejections,
		"distinct_signatures": signatures.size(), "casts": casts, "shapes": shapes,
		"lengths": _bands(lengths), "metrics": _bands(metrics),
		"time_ms": {"p50": _percentile(times, 0.50), "p90": _percentile(times, 0.90), "p99": _percentile(times, 0.99), "max": times[times.size() - 1] if not times.is_empty() else 0.0},
		"integrity_time_ms": _time_band(integrity_times),
	}
	print(JSON.stringify(aggregate, "  "))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"aggregate": aggregate, "rows": rows}, "\t"))
	file.close()
	print("wrote ", out_path)
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


func _reaches(recipe: FloorRecipe) -> Dictionary:
	return SpawnReaches.for_keys(recipe.stratum.enemy_keys)


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
		out[edge] = {"min": values[0], "median": values[values.size() / 2], "max": values[values.size() - 1], "n": values.size()}
	return out


## The mandatory walk of a one-key floor, leg by leg, each under the doors open AT THAT MOMENT:
##   arrival -> the encounter's plate      (doors as authored)
##   plate   -> the key                    (+ whatever the clear opens)
##   key     -> the receiver               (+ whatever the lift opens: everything but the receiver's own doors)
##   receiver -> the exit pad              (everything open)
## and the carry again with every closing edge shut, which is the walk the return saves. {} when
## the floor has no single key/receiver pair or no sealing plate to measure against.
func _route_metrics(recipe: FloorRecipe, result: FloorComposer.ComposeResult, plan: FloorPlan, radius: float) -> Dictionary:
	if plan.carriables.size() != 1:
		return {}
	var receiver: FloorTrigger = null
	var plate: FloorTrigger = null
	var pad: FloorTrigger = null
	var cleared_opens: Array = []
	var receiver_opens: Array = []
	for trigger: FloorTrigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			var kind: StringName = effect.get("kind", &"")
			if kind == FloorLayers.EFFECT_ACTIVATE_ENCOUNTER and trigger.region.get_area() > 0.0:
				plate = trigger
			elif kind == FloorLayers.EFFECT_COMPLETE_FLOOR:
				pad = trigger
			elif kind == FloorLayers.EFFECT_OPEN_CONNECTION and trigger.kind == FloorLayers.TRIGGER_ENCOUNTER_CLEARED:
				cleared_opens.append(int(effect.get("target_id", -1)))
			elif kind == FloorLayers.EFFECT_OPEN_CONNECTION and trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
				receiver_opens.append(int(effect.get("target_id", -1)))
		if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
			receiver = trigger
	if receiver == null or plate == null or pad == null:
		return {}
	var initially_closed: Array = []
	for connection: TraversalConnection in plan.connections:
		if not connection.starts_open:
			initially_closed.append(connection.connection_id)
	var after_clear: Array = initially_closed.filter(func(id: int) -> bool: return not id in cleared_opens)
	var closing: Array = []
	for edge: Dictionary in recipe.edges:
		if bool(edge.get("closes_cycle", false)):
			closing.append(RouteMetrics.connection_of(result, RouteMetrics.instance_of_node(recipe, result, edge["from"]), edge["from_port"]))
			closing.append(RouteMetrics.connection_of(result, RouteMetrics.instance_of_node(recipe, result, edge["to"]), edge["to_port"]))
	var key: Vector3 = plan.carriables[0].position
	var key_spot := Rect2(key.x - 1.0, key.z - 1.0, 2.0, 2.0)
	var entry := Vector2(plan.entry_point.x, plan.entry_point.z)
	var to_plate: Dictionary = RouteMetrics.walk(plan, RouteMetrics.open_except(plan, initially_closed), entry, plate.region, radius)
	var plate_at: Vector2 = plate.region.get_center()
	var to_key: Dictionary = RouteMetrics.walk(plan, RouteMetrics.open_except(plan, after_clear), plate_at, key_spot, radius)
	var carry: Dictionary = RouteMetrics.walk(plan, RouteMetrics.open_except(plan, receiver_opens), Vector2(key.x, key.z), receiver.region, radius)
	var carry_shut: Dictionary = RouteMetrics.walk(plan, RouteMetrics.open_except(plan, receiver_opens + closing), Vector2(key.x, key.z), receiver.region, radius)
	var onward: Dictionary = RouteMetrics.walk(plan, RouteMetrics.open_except(plan, []), receiver.region.get_center(), pad.region, radius)
	var walked: Array = []
	for leg: Dictionary in [to_plate, to_key, carry, onward]:
		walked.append_array(leg["path"])
	var out: Dictionary = {
		"walk_to_plate": to_plate["length"], "walk_to_key": to_key["length"], "carry": carry["length"],
		"carry_without_return": carry_shut["length"], "walk_onward": onward["length"],
		"mandatory_walk": float(to_plate["length"]) + float(to_key["length"]) + float(carry["length"]) + float(onward["length"]),
		"carry_pieces_crossed": RouteMetrics.pieces_crossed(result, carry["path"]).size(),
		"headings": "".join(RouteMetrics.headings(walked)),
		"distinct_headings": _distinct(RouteMetrics.headings(walked)),
	}
	if float(carry["length"]) > 0.0 and float(carry_shut["length"]) > 0.0:
		out["return_saving"] = float(carry_shut["length"]) - float(carry["length"])
		out["return_ratio"] = float(carry["length"]) / float(carry_shut["length"])
	return out


func _time_band(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	values.sort()
	return {"p50": _percentile(values, 0.50), "p99": _percentile(values, 0.99), "max": values[values.size() - 1]}


## The smallest margin (distance minus arrival reach) of any plate-woken spawn, measured from the
## activating region's centre (the composer's rule) and from its nearest point (diagnostic). Empty
## when nothing on the floor is woken by a region.
func _spacing_margins(layout: AuthoredLayout, reaches: Dictionary) -> Dictionary:
	var centre_margin: float = INF
	var boundary_margin: float = INF
	for trigger: FloorTrigger in layout.triggers:
		if trigger.region.get_area() <= 0.0:
			continue
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") != FloorLayers.EFFECT_ACTIVATE_ENCOUNTER:
				continue
			for site: EncounterSite in layout.encounters:
				if site.key != effect.get("target_key", &"") and site.encounter_id != int(effect.get("target_id", -2)):
					continue
				for member: Dictionary in site.roster:
					var reach: float = float(reaches.get(member.get("enemy_key", &""), 0.0))
					var at: Vector3 = member.get("position", Vector3.ZERO)
					var point := Vector2(at.x, at.z)
					centre_margin = minf(centre_margin, point.distance_to(EncounterSpacing.activation_point(trigger.region)) - reach)
					var nearest := Vector2(clampf(point.x, trigger.region.position.x, trigger.region.end.x), clampf(point.y, trigger.region.position.y, trigger.region.end.y))
					boundary_margin = minf(boundary_margin, point.distance_to(nearest) - reach)
	if centre_margin == INF:
		return {}
	return {"spawn_margin_from_centre": centre_margin, "spawn_margin_from_region_edge": boundary_margin}


func _distinct(headings: PackedStringArray) -> int:
	var seen: Dictionary = {}
	for heading: String in headings:
		seen[heading] = true
	return seen.size()
