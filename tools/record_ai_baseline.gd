extends SceneTree
## Regenerates the P29 backward-compat golden baseline (tests/fixtures/).
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/record_ai_baseline.gd
##
## RE-BASELINING IS A DELIBERATE ACT, never a way to make a red test green. The baseline
## asserts that P29 did not move M1's shipped enemy behaviour; regenerating it after a
## behaviour change destroys exactly the evidence it exists to provide. Re-record only
## when the change to enemy behaviour is INTENDED, and record the reason + date in
## AiBaselineScenario's doc comment in the same commit (golden-seed re-baseline law,
## CLAUDE.md Always-On Rules).
##
## AiBaselineScenario is loaded DYNAMICALLY, not by its class_name: a `-s` script is
## compiled before the engine has registered project autoloads, so a compile-time
## reference to anything touching `ContentDB` fails with "Identifier not found". Waiting
## for the main loop and then load()-ing is the same shape addons/gut/gut_cmdln.gd uses
## for exactly this reason.

const OUTPUT_PATH: String = "res://tests/fixtures/ai_baseline_pre_p29.json"
const SCENARIO_PATH: String = "res://tests/helpers/ai_baseline_scenario.gd"


func _init() -> void:
	var iterations: int = 0
	while Engine.get_main_loop() == null and iterations < 20:
		await create_timer(0.01).timeout
		iterations += 1
	if Engine.get_main_loop() == null:
		push_error("record_ai_baseline: main loop did not start in time")
		quit(1)
		return

	var scenario: GDScript = load(SCENARIO_PATH)
	var sim_world: GDScript = load("res://game/sim/sim_world.gd")
	var sim: Object = sim_world.new()
	scenario.build(sim)
	var stream: Array = scenario.run(sim)

	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("record_ai_baseline: cannot open %s (%d)" % [OUTPUT_PATH, FileAccess.get_open_error()])
		quit(1)
		return
	file.store_string(JSON.stringify(stream, "\t"))
	file.close()

	print("recorded %d events -> %s" % [stream.size(), OUTPUT_PATH])
	quit(0)
