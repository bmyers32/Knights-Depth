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
##
## TIERS (test-harness rule, 2026-10-27). Full coverage is the DEFAULT; less is asked for by name
## and shown in the output and the JSON:
##   --integrity=full   ObjectiveIntegrity with keys set down anywhere (default, certification)
##   --integrity=fast   the same claims, the voluntary set-down not modelled
##   --integrity=off    no integrity at all -- reported NOT_EVALUATED, never as a pass
##   --metrics=on|off   route and topology metrics (default on) -- off is reported NOT_EVALUATED
##
## S4: the shared camera (game/content/camera/expedition_framing.tres) is passed to compose, so a
## recipe's mandatory reveals are enforced exactly as on a played floor; every visibility edge is
## tallied, and with metrics on each REVEAL edge is also judged along a WALKED route -- from the
## entry under the floor's starting door states when the anchor's ground is reachable then, else
## from the vantage with every door open: where along the walk the anchor is first seen, the share
## of the walk it is seen from, and how far the declared vantage lies from the walked line.
##
## THE VERDICT IS MACHINE-CHECKED (owner review, 2026-10-28). A full-coverage sweep ends with a
## `certification` block and EXITS 1 when it fails, so "the step ran" can never be read as "the
## recipe passed". It passes only when every seed composed the REQUESTED recipe (a fallback is
## counted apart, never as a success), nothing was structural, progression and declared integrity
## passed on every composed floor, no spawn was unsafe, and every declared-mandatory reveal held AND
## was confirmed enforceable on every seed -- an unenforceable mandatory reveal is a failure, never
## an optional one. Reseeds are reported, not failed. A reduced sweep says NOT_CERTIFIED, exits 0.

const RECIPE_DIR := "res://game/content/floors/recipes/"
const RouteMetrics := preload("res://tools/route_metrics.gd")
const SpawnReaches := preload("res://tools/spawn_reaches.gd")
const CAMERA_PATH := "res://game/content/camera/expedition_framing.tres"


func _init() -> void:
	var seeds: int = int(_arg("seeds", "100"))
	var depth: int = int(_arg("depth", "1"))
	var recipe_id: String = _arg("recipe", "proto_archive")
	var recipe: FloorRecipe = load(RECIPE_DIR + recipe_id + ".tres")
	var out_path: String = "res://build/compose_sweep_%s.json" % recipe_id
	var rules: Dictionary = _rules()
	var radii: Dictionary = _radii(recipe)
	var reaches: Dictionary = _reaches(recipe)
	var camera: CameraFraming = load(CAMERA_PATH)
	var sight_tallies: Dictionary = {}
	var visibility_times: Array[float] = []
	var rows: Array[Dictionary] = []
	var times: Array[float] = []
	var radius: float = float(rules["body_radius"])
	var metrics: Dictionary = {}
	var totals: Dictionary = {"composed": 0, "fallback": 0, "structural": 0, "reseeded": 0, "progression_pass": 0, "progression_fail": 0, "progression_unsupported": 0, "spawn_unsafe": 0,
		"integrity_pass": 0, "integrity_fail": 0, "integrity_unsupported": 0, "integrity_undeclared": 0}
	var integrity_mode: String = _arg("integrity", "full")
	var metrics_mode: String = _arg("metrics", "on")
	assert(integrity_mode in ["full", "fast", "off"] and metrics_mode in ["on", "off"], "--integrity=full|fast|off, --metrics=on|off")
	var integrity_rules: Dictionary = rules.duplicate()
	integrity_rules["set_down_anywhere"] = integrity_mode == "full"
	if integrity_mode != "full" or metrics_mode != "on":
		print("REDUCED COVERAGE: integrity=%s metrics=%s -- not a certification sweep" % [integrity_mode, metrics_mode])
	var integrity_times: Array[float] = []
	# Where a sweep's wall time goes, per phase (R10, 2026-10-28) -- measured, never assumed.
	var phase_times: Dictionary = {}
	var declares: bool = recipe.nodes.any(func(node: Dictionary) -> bool: return node.has("progression"))
	var rejections: Dictionary = {}
	var signatures: Dictionary = {}
	var casts: Dictionary = {}
	var shapes: Dictionary = {}
	var lengths: Dictionary = {}
	for run_seed: int in seeds:
		var floor_seed: int = SeedMix.derive(run_seed, depth)
		var result: FloorComposer.ComposeResult = FloorComposer.compose(recipe, floor_seed, depth, radii, reaches, camera, rules)
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
			var phase_started: int = Time.get_ticks_usec()
			var progression: ProgressionReport = ProgressionValidator.check(plan, rules)
			_phase(phase_times, "progression", phase_started)
			row["progression"] = String(progression.outcome)
			row["progression_steps"] = progression.trace.size()
			totals["progression_" + String(progression.outcome)] += 1
			# Certification asks every declared-mandatory relationship (ENFORCE_ALWAYS); the composer
			# asked it only where a reveal failed. Timed apart from generation.
			var certified: Array = []
			if not recipe.visibility.is_empty():
				var sight_started: int = Time.get_ticks_usec()
				certified = VisibilityValidator.check(recipe, result.draft, result.emit, plan, camera, rules, VisibilityValidator.ENFORCE_ALWAYS).to_dicts()
				visibility_times.append((Time.get_ticks_usec() - sight_started) / 1000.0)
				_phase(phase_times, "visibility_certify", sight_started)
				row["visibility_certified"] = certified
			for sight: Dictionary in certified:
				var tally: Dictionary = sight_tallies.get(sight["edge"], {"holds": 0, "fails": 0, "mandatory": 0, "unenforceable": 0, "errors": 0})
				tally["holds" if sight["holds"] else "fails"] += 1
				if sight["mandatory"]:
					tally["mandatory"] += 1
				elif sight["declared_mandatory"]:
					tally["unenforceable"] += 1
				if sight["verdict"] == "error":
					tally["errors"] += 1
				sight_tallies[sight["edge"]] = tally
			var spacing: Array[Dictionary] = EncounterSpacing.findings(result.layout, reaches)
			row["spawn_findings"] = spacing.size()
			if not spacing.is_empty():
				totals["spawn_unsafe"] += 1
			if declares and integrity_mode == "off":
				row["integrity"] = "not_evaluated"
			elif declares:
				var started: int = Time.get_ticks_usec()
				var integrity: ObjectiveIntegrity.Report = ObjectiveIntegrity.check(recipe, result, plan, integrity_rules)
				integrity_times.append((Time.get_ticks_usec() - started) / 1000.0)
				_phase(phase_times, "integrity", started)
				row["integrity"] = String(integrity.outcome)
				row["integrity_claims"] = integrity.claims.size()
				row["integrity_baseline_states"] = integrity.baseline.states_explored
				if integrity.outcome != ObjectiveIntegrity.OUTCOME_PASS:
					row["integrity_summary"] = integrity.summary()
				totals["integrity_" + String(integrity.outcome)] += 1
			else:
				totals["integrity_undeclared"] += 1
			var measured: Dictionary = {}
			if metrics_mode == "on":
				phase_started = Time.get_ticks_usec()
				measured = RouteMetrics.topology(plan, result.layout)
				measured.merge(_spacing_margins(result.layout, reaches))
				_phase(phase_times, "topology_spacing", phase_started)
				phase_started = Time.get_ticks_usec()
				measured.merge(_route_metrics(recipe, result, plan, radius))
				_phase(phase_times, "route_metrics", phase_started)
				phase_started = Time.get_ticks_usec()
				measured.merge(_reveal_walks(recipe, result, plan, radius, camera))
				_phase(phase_times, "reveal_walks", phase_started)
				row["metrics"] = measured
			else:
				row["metrics"] = "not_evaluated"
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
		"distinct_signatures": signatures.size(), "casts": casts, "shapes": shapes, "visibility": sight_tallies,
		"visibility_certify_time_ms": _time_bands(visibility_times),
		"lengths": _bands(lengths), "metrics": _bands(metrics),
		"time_ms": {"p50": _percentile(times, 0.50), "p90": _percentile(times, 0.90), "p99": _percentile(times, 0.99), "max": times[times.size() - 1] if not times.is_empty() else 0.0},
		"integrity_time_ms": _time_band(integrity_times),
		"phase_time_ms": _phase_bands(phase_times, times),
		"coverage": {"integrity": integrity_mode if declares else "undeclared", "metrics": metrics_mode},
	}
	if declares and integrity_mode == "off":
		for key: String in ["integrity_pass", "integrity_fail", "integrity_unsupported"]:
			totals[key] = "NOT_EVALUATED"
	if metrics_mode == "off":
		aggregate["metrics"] = "NOT_EVALUATED"
	var certification: Dictionary = _certify(totals, sight_tallies, seeds, declares, integrity_mode == "full" and metrics_mode == "on")
	aggregate["certification"] = certification
	print(JSON.stringify(aggregate, "  "))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"aggregate": aggregate, "rows": rows}, "\t"))
	file.close()
	print("wrote ", out_path)
	print("CERTIFICATION %s%s" % [certification["verdict"], "" if certification["failures"].is_empty() else ": " + "; ".join(certification["failures"])])
	quit(1 if certification["verdict"] == "FAIL" else 0)


## The pass criteria of a certification sweep (header), each failure named.
func _certify(totals: Dictionary, sight_tallies: Dictionary, seeds: int, declares: bool, full: bool) -> Dictionary:
	if not full:
		return {"verdict": "NOT_CERTIFIED", "failures": ["reduced coverage"], "requested_recipe_composed": totals["composed"], "fallbacks": totals["fallback"]}
	var failures: PackedStringArray = []
	var composed: int = int(totals["composed"])
	if composed != seeds:
		failures.append("requested recipe composed on %d/%d seeds (%d fallbacks, %d structural)" % [composed, seeds, totals["fallback"], totals["structural"]])
	if int(totals["progression_pass"]) != composed:
		failures.append("progression passed on %d/%d composed floors" % [totals["progression_pass"], composed])
	if declares and int(totals["integrity_pass"]) != composed:
		failures.append("integrity passed on %d/%d composed floors" % [totals["integrity_pass"], composed])
	if int(totals["spawn_unsafe"]) > 0:
		failures.append("%d floors with unsafe spawns" % totals["spawn_unsafe"])
	for edge: String in sight_tallies:
		var tally: Dictionary = sight_tallies[edge]
		if int(tally["mandatory"]) + int(tally["unenforceable"]) == 0:
			continue
		if int(tally["unenforceable"]) > 0:
			failures.append("mandatory %s unenforceable on %d seeds" % [edge, tally["unenforceable"]])
		if int(tally["fails"]) > 0 or int(tally["errors"]) > 0 or int(tally["holds"]) != composed:
			failures.append("mandatory %s held on %d/%d seeds (%d errors)" % [edge, tally["holds"], composed, tally["errors"]])
	return {"verdict": "PASS" if failures.is_empty() else "FAIL", "failures": Array(failures), "requested_recipe_composed": composed,
		"fallbacks": totals["fallback"], "reseeded": totals["reseeded"]}


func _phase(phase_times: Dictionary, name: String, started_usec: int) -> void:
	if not phase_times.has(name):
		phase_times[name] = [] as Array[float]
	phase_times[name].append((Time.get_ticks_usec() - started_usec) / 1000.0)


## Per phase: total and mean ms, so the dominant cost of a sweep is named, not guessed.
func _phase_bands(phase_times: Dictionary, compose_times: Array[float]) -> Dictionary:
	var out: Dictionary = {}
	var all: Dictionary = phase_times.duplicate()
	all["compose"] = compose_times
	for name: String in all:
		var values: Array = all[name]
		var total: float = 0.0
		for value: float in values:
			total += value
		out[name] = {"total_ms": total, "mean_ms": total / maxf(1.0, float(values.size())), "count": values.size()}
	return out


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


## Each REVEAL edge judged along a walked route (header). Diagnostics only.
func _reveal_walks(recipe: FloorRecipe, result: FloorComposer.ComposeResult, plan: FloorPlan, radius: float, camera: CameraFraming) -> Dictionary:
	var out: Dictionary = {}
	var extent: Rect2 = VisibilityValidator.extent_of(plan)
	var starting: Dictionary = {}
	for connection: TraversalConnection in plan.connections:
		if connection.starts_open or not connection.has_barrier:
			starting[connection.connection_id] = true
	for index: int in recipe.visibility.size():
		var edge: Dictionary = recipe.visibility[index]
		if edge.get("intent", VisibilityValidator.INTENT_REVEAL) != VisibilityValidator.INTENT_REVEAL or index >= result.report.visibility.size():
			continue
		var judged: Dictionary = result.report.visibility[index]
		var vantage := Vector3(judged["vantage"][0], judged["vantage"][1], judged["vantage"][2])
		var anchor := Vector3(judged["anchor"][0], judged["anchor"][1], judged["anchor"][2])
		var door: int = -1
		var along: Vector3 = Vector3.ZERO
		if edge.get("door_port", &"") != &"":
			var target: FloorDraft.PieceInstance = result.draft.instances[recipe._index_of(edge["to"])]
			door = RouteMetrics.connection_of(result, target.instance_id, edge["door_port"])
			along = Vector3(1, 0, 0) if PiecePort.runs_along_x(FloorDraft.world_edge(target, target.piece.port(edge["door_port"]).edge)) else Vector3(0, 0, 1)
		var blockers: Array[Dictionary] = VisibilityValidator.occluders(plan, camera, [door] if door >= 0 else [])
		var goal := Rect2(anchor.x - 2.0, anchor.z - 2.0, 4.0, 4.0)
		var mode: String = "from_entry"
		var walked: Dictionary = RouteMetrics.walk(plan, starting, Vector2(plan.entry_point.x, plan.entry_point.z), goal, radius)
		if float(walked["length"]) < 0.0:
			mode = "from_vantage_open"
			walked = RouteMetrics.walk(plan, RouteMetrics.open_except(plan, []), Vector2(vantage.x, vantage.z), goal, radius)
		var prefix: String = "reveal_%d_" % index
		out[prefix + "mode"] = mode if float(walked["length"]) >= 0.0 else "unwalkable"
		var path: Array = walked["path"]
		if path.is_empty():
			continue
		var travelled: float = 0.0
		var first_seen: float = -1.0
		var seen: int = 0
		var nearest: float = INF
		for step: int in path.size():
			var point: Vector2 = path[step]
			if step > 0:
				travelled += point.distance_to(path[step - 1])
			nearest = minf(nearest, point.distance_to(Vector2(vantage.x, vantage.z)))
			var sight: VisibilityValidator.Sight = VisibilityValidator.look(camera, extent, blockers, Vector3(point.x, 0.0, point.y), anchor, along)
			if sight.seen(camera.reveal_min_visible_share):
				seen += 1
				if first_seen < 0.0:
					first_seen = travelled
		out[prefix + "walk_m"] = travelled
		out[prefix + "first_seen_m"] = first_seen
		out[prefix + "seen_to_go_m"] = travelled - first_seen if first_seen >= 0.0 else -1.0
		out[prefix + "seen_share"] = float(seen) / float(path.size())
		out[prefix + "vantage_offset_m"] = nearest
	return out


func _time_bands(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	return {"p50": _percentile(sorted_values, 0.5), "p99": _percentile(sorted_values, 0.99), "max": sorted_values[sorted_values.size() - 1]}


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
