extends Node
## DEBUG-ONLY PLAYABLE COMPOSED FLOOR (ADR-001 S2 human design gate). Composes the prototype
## recipe for one run seed and deploys a standalone Arena on it as a one-floor expedition --
## exactly the way a test boots a single floor, with the composed plan handed in through the
## Arena's prepared-plan seam. Nothing here touches the normal itinerary or DepthGenerator.
##
## Run (windowed):  & "C:\Godot\Godot_v4.7-stable_win64.exe" --path . tools/composed_floor_playground.tscn -- --seed=7 --recipe=proto_archive
## Boot check:      & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless --path . tools/composed_floor_playground.tscn --quit-after 300 -- --seed=7
## (`tools/play_composed_floor.ps1 -Seed 7 -Recipe proto_archive_dogleg` wraps both.)
##
## A scene rather than a -s script because the Arena needs the ContentDB autoload.
##
## Composed with the SAME spawn-spacing rejection the sweep uses (S3b): a floor whose plate wakes a
## roster inside its arrival reach is refused here too, so nothing the composer would reject can
## be played by accident.

const ARENA := preload("res://game/arena/arena.tscn")
const RECIPE_DIR := "res://game/content/floors/recipes/"
const DEPTH: int = 1
const SpawnReaches := preload("res://tools/spawn_reaches.gd")


func _ready() -> void:
	var run_seed: int = int(_arg("seed", "1"))
	var recipe: FloorRecipe = load(RECIPE_DIR + _arg("recipe", "proto_archive") + ".tres")
	var radii: Dictionary = {}
	for key: StringName in recipe.stratum.enemy_keys:
		var stats: Resource = ContentDB.get_resource(&"enemy", key)
		if stats != null:
			radii[key] = stats.combat_radius
	var reaches: Dictionary = SpawnReaches.for_keys(recipe.stratum.enemy_keys)
	var result: FloorComposer.ComposeResult = FloorComposer.compose(recipe, SeedMix.derive(run_seed, DEPTH), DEPTH, radii, reaches)
	print("playground: spawn spacing judged for ", reaches.keys())
	print("playground: ", result.report.summary())
	print("playground: ", result.report.spatial_signature())
	var plan := FloorPlan.new()
	plan.run_seed = run_seed
	plan.depth = DEPTH
	plan.floor_seed = SeedMix.derive(run_seed, DEPTH)
	plan.stratum_id = result.layout.stratum_id
	plan.authored_layout = result.report.fallback
	LayoutCompiler.compile(result.layout, plan)
	plan.validate(radii)
	var arena: Node = ARENA.instantiate()
	arena.run_seed = run_seed
	arena.itinerary = [DEPTH] as Array[int]
	arena.standalone = true
	arena.prepared_first_plan = plan
	add_child(arena)


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.get_slice("=", 1)
	return fallback
