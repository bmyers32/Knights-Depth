extends SceneTree
## Records the golden FloorPlan fixture (GAME-RULES §5 M2: "same seed -> byte-identical
## FloorPlan").
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/record_floor_plan_golden.gd
##
## RE-BASELINE LOG (append a dated line for every regeneration):
##   2026-08-28  FIRST RECORDING. Single rectangular chamber (M2 Slice 1).
##   2026-08-28  RE-BASELINED for the FLOOR-GRAMMAR pivot. The multi-room schema was falsified
##               by play ("it is still giving 4 boxes"); a floor is now four independent layers
##               (patches / connections+triggers / encounters / interactables+breakables) and
##               the old fixture describes a shape nothing can produce. Schema migration, not a
##               drift-hiding re-record. Hand-inspected before commit.
##   2026-08-28  RE-BASELINED for the multi-room slice. The FloorPlan schema itself changed --
##               a floor became RoomPlan[] + ConnectionPlan[] with a derived walkable union,
##               and spawns moved from the plan onto their owning room. The old fixture
##               described a shape the generator can no longer produce, so this is a schema
##               migration, not a drift-hiding re-record. Hand-inspected before commit.
##   2026-08-29  RE-BASELINED after the human floor-grammar play. TWO schema fields changed
##               (patches carry boundary_style; an encounter's territory became a UNION of
##               regions, not one rect) and TWO authored beats changed by ruling: the party
##               button became an occupancy PLATE, and the meaningless final switch was
##               deleted, so the last connection now opens from the encounter clear. The old
##               fixture describes a floor nothing can produce. Schema + authoring migration,
##               not a drift-hiding re-record. Hand-inspected before commit.
##   2026-08-29  RE-BASELINED for the interaction ruling. INTERACTABLES ARE RETIRED: the hidden
##               switch became a dormant PLATE enabled by the crate, the floor exit became a
##               group-occupancy plate emitting floor_complete, and the `switch` kind,
##               InteractablePlan, TRIGGER_INTERACTED and the `interact` Command went with their
##               last consumer. Triggers gained starts_enabled + renders_as_plate. Schema +
##               authoring migration, not a drift-hiding re-record. Hand-inspected before commit.
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
	print("  entry %s -> end %s" % [serialized["entry_point"], serialized["end_marker"]])
	print("  authored_layout=%s" % serialized["authored_layout"])
	for patch in serialized["patches"]:
		print("  patch %d %-8s elev=%.1f %s" % [patch["patch_id"], patch["surface"], patch["elevation"], patch["rect"]])
	for connection in serialized["connections"]:
		print("  connection %d %s open=%s %s" % [connection["connection_id"], connection["patch_ids"], connection["starts_open"], connection["aperture"]])
	for trigger in serialized["triggers"]:
		print("  trigger %d %-22s source=%d enabled=%s plate=%s effects=%s" % [trigger["trigger_id"], trigger["kind"], trigger["source_id"], trigger["starts_enabled"], trigger["renders_as_plate"], trigger["effects"]])
	for encounter in serialized["encounters"]:
		print("  encounter %d %-10s confines=%s spawn_at_load=%s roster=%d" % [encounter["encounter_id"], encounter["role"], encounter["confines_player"], encounter["spawn_at_floor_load"], encounter["roster"].size()])
	for breakable in serialized["breakables"]:
		print("  breakable %d conceals trigger %d %s" % [breakable["breakable_id"], breakable["conceals_trigger_id"], breakable["position"]])
	quit(0)
