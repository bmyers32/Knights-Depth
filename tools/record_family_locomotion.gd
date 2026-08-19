extends SceneTree
## Records the two LIVE locomotion artifacts of the P17 baseline split.
##
## Run (records both):
##   & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/record_family_locomotion.gd
##
## RE-RECORDING IS A DELIBERATE ACT, never a way to make a red test green.
##
## And when a family's behaviour DOES lawfully change, the move is not to overwrite the
## artifact that governs it — it is to retire that artifact to evidence and create a new
## dated one (BRAIN: "Never rewrite yesterday's baseline to describe today"). The frozen
## tests/fixtures/ai_baseline_pre_p29.json is the worked example: this tool cannot write
## it, by design, and must never be taught how.
##
## FamilyLocomotionScenario is loaded DYNAMICALLY, not by its class_name: a `-s` script is
## compiled before the engine has registered project autoloads, so a compile-time reference
## to anything touching `ContentDB` fails with "Identifier not found".

const SCENARIO_PATH: String = "res://tests/helpers/family_locomotion_scenario.gd"

## family_key -> output fixture. Ooze is the ACTIVE canary (an explicitly unaffected
## family). The Fang entry recorded the P17 approach weave, which was FALSIFIED and
## reverted on 2026-08-19: its artifact is now experiment evidence and re-running this
## against `fang` would overwrite that evidence with post-revert (straight) behaviour.
## Left in place for the successor mechanic, which will need a freshly DATED artifact of
## its own -- never this one overwritten.
const ARTIFACTS: Dictionary = {
	&"ooze": "res://tests/fixtures/ai_canary_ooze.json",
	&"fang": "res://tests/fixtures/ai_baseline_p17_fang.json",
}


func _init() -> void:
	var iterations: int = 0
	while Engine.get_main_loop() == null and iterations < 20:
		await create_timer(0.01).timeout
		iterations += 1
	if Engine.get_main_loop() == null:
		push_error("record_family_locomotion: main loop did not start in time")
		quit(1)
		return

	var scenario: GDScript = load(SCENARIO_PATH)
	for family_key in ARTIFACTS:
		var output_path: String = ARTIFACTS[family_key]
		var stream: Array = scenario.run(family_key)
		if stream.is_empty():
			push_error("record_family_locomotion: %s produced an EMPTY stream -- refusing to write" % family_key)
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			push_error("record_family_locomotion: cannot open %s (%d)" % [output_path, FileAccess.get_open_error()])
			quit(1)
			return
		file.store_string(JSON.stringify(stream, "\t"))
		file.close()
		print("recorded %d events (%s) -> %s" % [stream.size(), family_key, output_path])
	quit(0)
