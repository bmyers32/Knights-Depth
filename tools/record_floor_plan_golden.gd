extends SceneTree
## Records the golden FloorPlan fixture (GAME-RULES §5 M2: "same seed -> byte-identical
## FloorPlan").
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/record_floor_plan_golden.gd
##
## RE-BASELINING IS A DELIBERATE ACT, NEVER A WAY TO MAKE A RED TEST GREEN. This fixture's
## whole job is to notice that generation changed. If test_golden_seed.gd goes red, the
## question is "what did I change about generation, and did I mean to?" -- re-record only
## after answering that, and note the reason + date in the same commit (golden-seed
## re-baseline law, CLAUDE.md Always-On Rules).
##
## DepthGenerator is loaded DYNAMICALLY, not by class_name: a `-s` script compiles before
## the engine registers project autoloads, so a compile-time reference to anything touching
## ContentDB fails with "Identifier not found" (see tools/record_ai_baseline.gd).

const OUTPUT_PATH: String = "res://tests/fixtures/floor_plan_golden.json"
const GOLDEN_SEED: int = 20260828
const GOLDEN_DEPTH: int = 1


func _init() -> void:
	var iterations: int = 0
	while Engine.get_main_loop() == null and iterations < 20:
		await create_timer(0.01).timeout
		iterations += 1
	if Engine.get_main_loop() == null:
		push_error("record_floor_plan_golden: main loop did not start in time")
		quit(1)
		return

	var generator: GDScript = load("res://game/gen/depth_generator.gd")
	var plan: Object = generator.generate(GOLDEN_SEED, GOLDEN_DEPTH)
	var serialized: Dictionary = plan.to_dict()

	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("record_floor_plan_golden: cannot open %s (%d)" % [OUTPUT_PATH, FileAccess.get_open_error()])
		quit(1)
		return
	# sort_keys defaults true, so key order is canonical rather than insertion-dependent.
	file.store_string(JSON.stringify(serialized, "\t"))
	file.close()

	print("recorded floor plan -> %s" % OUTPUT_PATH)
	print("  seed %d depth %d -> floor_seed %d" % [GOLDEN_SEED, GOLDEN_DEPTH, serialized["floor_seed"]])
	print("  chamber %s" % [serialized["walkable_rects"]])
	print("  entry %s" % [serialized["entry_point"]])
	print("  spawns %d: %s" % [serialized["spawns"].size(), serialized["spawns"]])
	quit(0)
