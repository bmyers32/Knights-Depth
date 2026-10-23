extends SceneTree
## DRAWS COMPOSED FLOORS AS SVG for the S2 human design gate (ADR-001 §7): one file per seed,
## top-down, +x to the right and -z (the flow) downward, so the picture reads like the floor
## papers' ASCII maps. Pieces are tinted by instance, hallways grey, apertures blue, obstacles
## dark, plates orange, encounter territories outlined red, entry / exit / console marked.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/draw_composed_floor.gd -- --seeds=1,7,42 --depth=1
## Writes build/composed/seed_<n>.svg (build/ is untracked) and prints a one-line legend per seed.

const RECIPE_PATH := "res://game/content/floors/recipes/proto_archive.tres"
const SCALE: float = 4.0
const PAD: float = 12.0
const TINTS: Array[String] = ["#d9c7a0", "#b8cfe0", "#cfe0b8", "#e0b8d6", "#e0d2b8", "#b8e0dc"]


func _init() -> void:
	var depth: int = int(_arg("depth", "1"))
	var recipe: FloorRecipe = load(RECIPE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/composed"))
	for token: String in _arg("seeds", "1,7,42").split(","):
		var run_seed: int = int(token)
		var result: FloorComposer.ComposeResult = FloorComposer.compose(recipe, SeedMix.derive(run_seed, depth), depth)
		if result.draft == null:
			print("seed %d: %s" % [run_seed, result.report.summary()])
			continue
		var path: String = "res://build/composed/seed_%d.svg" % run_seed
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(_svg(result))
		file.close()
		print("seed %d -> %s | %s" % [run_seed, path, result.report.spatial_signature()])
	quit()


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.get_slice("=", 1)
	return fallback


func _svg(result: FloorComposer.ComposeResult) -> String:
	var layout: AuthoredLayout = result.layout
	var plan := FloorPlan.new()
	LayoutCompiler.compile(layout, plan)
	var extent: Rect2 = result.report.extent.grow(PAD)
	var lines: PackedStringArray = []
	lines.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="monospace" font-size="10">'
		% [int(extent.size.x * SCALE), int(extent.size.y * SCALE), int(extent.size.x * SCALE), int(extent.size.y * SCALE)])
	lines.append('<rect width="100%" height="100%" fill="#f4f1ea"/>')
	# footprints, tinted by instance
	for index: int in result.draft.instances.size():
		var instance: FloorDraft.PieceInstance = result.draft.instances[index]
		var footprint: Rect2 = FloorDraft.world_footprint(instance)
		lines.append(_rect(footprint, extent, "none", TINTS[index % TINTS.size()], 1.0, "4 2"))
		var at: Vector2 = _to_svg(Vector2(footprint.position.x, footprint.end.y), extent)
		lines.append('<text x="%.1f" y="%.1f" fill="#555">%s %s %s</text>' % [at.x + 2.0, at.y + 11.0, instance.instance_id, instance.piece.piece_id, instance.transform])
	# ground: piece patches tinted, hallway patches grey
	for patch: WalkablePatch in layout.patches:
		var source: String = String(patch.key).get_slice(".", 0)
		var fill: String = "#c8c8c8"
		if source.begins_with("i"):
			fill = TINTS[int(source.substr(1)) % TINTS.size()]
		lines.append(_rect(patch.rect, extent, fill, "#777", 0.6, ""))
	for connection: TraversalConnection in layout.connections:
		lines.append(_rect(connection.aperture, extent, "#9fc5e8" if connection.starts_open else "#f6a5a5", "#2a6fb0", 0.8, ""))
	for obstacle: ObstaclePlan in layout.obstacles:
		lines.append(_rect(obstacle.rect, extent, "#4a4a4a", "#222", 0.6, ""))
	for site: EncounterSite in layout.encounters:
		for region: Rect2 in site.regions:
			lines.append(_rect(region, extent, "none", "#c0392b", 1.2, "6 3"))
		for spawn: Dictionary in site.roster:
			lines.append(_dot(spawn["position"], extent, "#c0392b", 2.4))
	for trigger: FloorTrigger in layout.triggers:
		if trigger.region.get_area() > 0.0:
			lines.append(_rect(trigger.region, extent, "#f39c12" if trigger.renders_as_plate else "none", "#b9770e", 0.8, "" if trigger.renders_as_plate else "2 2"))
	for breakable: BreakablePlan in layout.breakables:
		lines.append(_dot(breakable.position, extent, "#8e6b3e", 2.0))
	for hit_switch: HitSwitchPlan in layout.hit_switches:
		lines.append(_dot(hit_switch.position, extent, "#16a085", 2.4))
	for carriable: CarriablePlan in layout.carriables:
		lines.append(_dot(carriable.position, extent, "#8e44ad", 2.4))
	lines.append(_dot(layout.entry_point, extent, "#27ae60", 3.5))
	lines.append(_dot(layout.end_marker, extent, "#2c3e50", 3.5))
	lines.append(_dot(layout.exit_console, extent, "#2980b9", 2.5))
	var legend: Vector2 = _to_svg(Vector2(extent.position.x + 2.0, extent.position.y + 2.0), extent)
	lines.append('<text x="%.1f" y="%.1f" fill="#333">%s</text>' % [legend.x, legend.y, result.report.summary().split("\n")[0].xml_escape()])
	lines.append("</svg>")
	return "\n".join(lines)


## World (x, z) -> SVG (x right, z flipped so -z is down the page).
func _to_svg(point: Vector2, extent: Rect2) -> Vector2:
	return Vector2((point.x - extent.position.x) * SCALE, (extent.end.y - point.y) * SCALE)


func _rect(rect: Rect2, extent: Rect2, fill: String, stroke: String, width: float, dash: String) -> String:
	var top_left: Vector2 = _to_svg(Vector2(rect.position.x, rect.end.y), extent)
	var dashes: String = ' stroke-dasharray="%s"' % dash if dash != "" else ""
	return '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"%s/>' % [
		top_left.x, top_left.y, rect.size.x * SCALE, rect.size.y * SCALE, fill, stroke, width, dashes]


func _dot(point: Vector3, extent: Rect2, fill: String, radius: float) -> String:
	var at: Vector2 = _to_svg(Vector2(point.x, point.z), extent)
	return '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % [at.x, at.y, radius, fill]
