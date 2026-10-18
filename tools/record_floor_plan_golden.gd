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
##   2026-08-29  RE-BASELINED for the hidden-plate sizing (human replay finding). The plate's
##               authored FOOTPRINT shrank 3.2 -> 2.0 with its mesh, so it reads as a local
##               discovered control rather than a commitment plate. Geometry change only; no
##               mechanic, schema or effect changed. Hand-inspected before commit.
##   2026-09-01  RE-BASELINED for the door-control response beat: the hidden plate now also
##               activates E_PLATE_RESPONSE, an OPTIONAL non-sealing encounter that arrives when
##               the route opens. Authoring change built entirely from existing primitives.
##               Hand-inspected before commit.
##   2026-09-01  RE-BASELINED for per-edge boundary styles: patches gained four optional side
##               overrides and the hall roundabout now authors an open outer perimeter with a
##               solid void-facing interior. Schema + authoring migration. Hand-inspected.
##   2026-09-01  RE-BASELINED again: the roundabout's void-facing ring was opened by human ruling,
##               so the hall is fully ledged. Authoring change only. Hand-inspected.
##   2026-10-09  RE-BASELINED because the SERIALIZATION widened, not because a floor changed.
##               to_dict() had fallen behind the plan: it omitted obstacles, spike_pads and
##               hit_switches entirely, plus breakable.blocking_rect and connection.flank_style.
##               The depth-1 fixture gains those keys and nothing else -- every previously
##               recorded value was verified byte-unchanged before commit.
##               FIRST RECORDING of the depth-2 fixture. Floor 2 never had a cross-session
##               golden, and depth 1 contains none of the newly covered data, so without it the
##               widened fields would guard an empty floor. It is a NEW BASELINE, cross-checked
##               against the accepted archive_roundabout.tres: it protects Floor 2 from here on
##               and proves nothing about what Floor 2 was before today.
##   2026-10-12  RE-BASELINED because the SERIALIZATION widened again, not because a floor
##               changed. FloorPlan gained `place_label` (a place's own name; first consumer the
##               Terminal), so to_dict() gained one root key. The depth-1 and depth-2 fixtures
##               each gain exactly `"place_label": ""` and nothing else -- verified by diffing
##               the committed bytes against the re-recording before commit.
##               FIRST RECORDING of the depth-3 fixture: the Terminal. A NEW BASELINE for new
##               content, not a re-baseline of anything.
##   2026-10-13  FIRST RECORDING of the depth-4 fixture: the first Foundry floor, as a greybox
##               that has NOT passed a human spatial gate. A NEW BASELINE for new content. The
##               depth 1-3 fixtures were re-written by this run and came out byte-identical
##               (verified with git before commit): nothing about serialization moved.
##   2026-10-13  DEPTH 4 RE-RECORDED, same day, because the FLOOR changed on purpose. The first
##               greybox was played and ruled out (hazard rows under every fight); it was
##               re-authored to a hub with two key wings, a gate, a connector and a chamber.
##               Neither recording was ever accepted or committed. Depths 1-3 again byte-identical.
##   2026-10-14  DEPTH 4 RE-RECORDED for the approved Stage 1 spatial re-author: closer to the
##               reference topology (raised landing, U and stairs, wider lower access, a wider
##               and irregular west loop with a return route, a new east outline and key bay, a
##               new exit run). Gate, connector, its pads and the chamber are unchanged. Still
##               not spatially accepted. Depths 1-3 byte-identical.
##   2026-10-15  DEPTH 4 RE-RECORDED for the one amendment the human Stage 1 spatial PASS asked
##               for: the optional east loot room is restored where the first greybox had it
##               (one patch, one open doorway, its three breakables). Nothing else moved; patch
##               and connection ids after it shift by one. Depths 1-3 byte-identical. This
##               is the floor the human accepted as Stage 1 (spatial PASS, 2026-10-15).
##   2026-10-16  RE-BASELINED, approved by the human before recording: the SERIALIZATION widened
##               (FloorPlan gained the `carriables` layer, ALWAYS serialized, empty or not) and
##               Floor 4 changed on purpose (Stage 2 physical keys). Depths 1-3 each gain exactly
##               `"carriables": [],` and nothing else -- diff shown to the human beforehand and
##               re-verified with git after recording. Depth 4: the two hit-switch stand-ins
##               became carriables K_WEST/K_EAST at the same positions; T_WEST_CLEAR now reveals
##               the west key and opens C_WEST_RETURN; receivers R_GATE_1/R_GATE_2 (triggers 9,
##               10) open C_LOCK_W/C_LOCK_E. Geometry unchanged.
##   2026-10-16  DEPTH 4 RE-RECORDED, same day, for the Stage 2 playtest iteration (human ruling:
##               the west shortcut defeated key transport). Exactly four records changed: the
##               C_WEST_RETURN connection (6) is DELETED, not closed; K_WEST moved from the apex
##               niche to the far end of the top band, visible from the start; trigger 1
##               (T_WEST_CLEAR -> T_WEST_LIFT) now fires on K_WEST's first lift and activates
##               new optional encounter 6, E_WEST_RETURN (two Fangs and an Ooze on the way back).
##               No other id shifted. Depths 1-3 byte-identical to the approved rebaseline above.
##   2026-10-16  DEPTH 4 RE-RECORDED for the east Watcher defect (human-confirmed; Option A, human
##               approved): E_EAST's two Watchers moved (60,-50)->(53,-50) and (58,-32)->(50,-46),
##               inside their 18-unit leash of the whole doorway and of the key bay, so activation
##               is no longer undone on the next tick. Three numbers changed; nothing else.
##               The leash rule (2026-09-08) is untouched. Depths 1-3 byte-identical.
##   2026-10-17  DEPTH 4 RE-RECORDED for the P41 stepping-stone corridor (human-approved design and
##               rulings): the three 6-wide travelling-write bands became FOUR contiguous 5-wide
##               pads at x 18/23/28/33 in two alternating groups -- safe 130, active 30 (cycle
##               160), offsets 130/50/130/50. Pad 3 is new. Connector patch, doorways, damage and
##               player-only eligibility unchanged; nothing else on the floor moved. Depths 1-3
##               byte-identical.
##   2026-10-17  DEPTH 4 RE-RECORDED, same day, for the east doorway bypass (human-found defect):
##               T_EAST's region (40,-46,6,12) -> (40,-52,6,20), the east room's whole west
##               column, so a wall-hugging entry can no longer reach the key with the room
##               asleep. One trigger region changed; roster, positions and leash untouched.
##               Depths 1-3 byte-identical.
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

const GOLDEN_SEED: int = 20260828
## One fixture per authored floor. Must match tests/test_golden_seed.gd.
const FIXTURES: Dictionary = {
	1: "res://tests/fixtures/floor_plan_golden.json",
	2: "res://tests/fixtures/floor_plan_golden_depth2.json",
	3: "res://tests/fixtures/floor_plan_golden_depth3.json",
	4: "res://tests/fixtures/floor_plan_golden_depth4.json",
}


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
	for depth: int in FIXTURES:
		if not _record(generator, depth, FIXTURES[depth]):
			quit(1)
			return
	quit(0)


func _record(generator: GDScript, depth: int, output_path: String) -> bool:
	var plan: Object = generator.generate(GOLDEN_SEED, depth)
	var serialized: Dictionary = plan.to_dict()

	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("record_floor_plan_golden: cannot open %s (%d)" % [output_path, FileAccess.get_open_error()])
		return false
	# sort_keys defaults true, so key order is canonical rather than insertion-dependent.
	file.store_string(JSON.stringify(serialized, "	"))
	file.close()

	print("recorded floor plan -> %s" % output_path)
	print("  seed %d depth %d -> floor_seed %d" % [GOLDEN_SEED, depth, serialized["floor_seed"]])
	print("  entry %s -> end %s" % [serialized["entry_point"], serialized["end_marker"]])
	print("  authored_layout=%s" % serialized["authored_layout"])
	for patch in serialized["patches"]:
		print("  patch %d %-8s elev=%.1f %s" % [patch["patch_id"], patch["surface"], patch["elevation"], patch["rect"]])
	for connection in serialized["connections"]:
		print("  connection %d %s open=%s flank=%s %s" % [connection["connection_id"], connection["patch_ids"], connection["starts_open"], connection["flank_style"], connection["aperture"]])
	for trigger in serialized["triggers"]:
		print("  trigger %d %-22s source=%d enabled=%s plate=%s effects=%s" % [trigger["trigger_id"], trigger["kind"], trigger["source_id"], trigger["starts_enabled"], trigger["renders_as_plate"], trigger["effects"]])
	for encounter in serialized["encounters"]:
		print("  encounter %d %-10s confines=%s spawn_at_load=%s roster=%d" % [encounter["encounter_id"], encounter["role"], encounter["confines_player"], encounter["spawn_at_floor_load"], encounter["roster"].size()])
	for breakable in serialized["breakables"]:
		print("  breakable %d conceals trigger %d %s blocking=%s" % [breakable["breakable_id"], breakable["conceals_trigger_id"], breakable["position"], breakable["blocking_rect"]])
	for hit_switch in serialized["hit_switches"]:
		print("  switch %d %-8s hidden=%s %s effects=%s" % [hit_switch["switch_id"], hit_switch["mode"], hit_switch["starts_hidden"], hit_switch["position"], hit_switch["effects"]])
	for carriable in serialized["carriables"]:
		print("  carriable %d hidden=%s %s" % [carriable["carriable_id"], carriable["starts_hidden"], carriable["position"]])
	for obstacle in serialized["obstacles"]:
		print("  obstacle %d height=%.1f %s" % [obstacle["obstacle_id"], obstacle["height"], obstacle["rect"]])
	for pad in serialized["spike_pads"]:
		print("  pad %d safe=%d active=%d offset=%d %.1f %s hurts=%s %s" % [pad["pad_id"], pad["safe_ticks"], pad["active_ticks"], pad["phase_offset_ticks"], pad["damage"], pad["damage_type"], pad["eligible_allegiances"], pad["rect"]])
	return true
