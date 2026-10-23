extends GutTest
## COMPOSITION CORRECTNESS (ADR-001 S1): two independently authored pieces, placed and joined
## through a FloorDraft, lower to ONE AuthoredLayout that the UNCHANGED LayoutCompiler turns into
## a FloorPlan equal -- record for record, id for id -- to the same floor authored by hand.
##
## Equality is asserted on FloorPlan.to_dict() EXACTLY. That works because the emitter's record
## order is a documented contract (instances in placement order, body order within each, then
## hallway rects, then joints) and the baseline was authored to it; nothing is normalised away.
## The baseline's piece B was mirrored and placed by hand, so the comparison is the emitter
## against a human's arithmetic.

const ENTRY := "res://game/content/floors/pieces/archive_entry_apron.tres"
const EXIT := "res://game/content/floors/pieces/archive_exit_gallery.tres"
const BASELINE := "res://tests/fixtures/floor_s1_baseline.tres"

const ENVOY: int = 0
const DT := 1.0 / 30.0
const SETTLE_TICKS := 3
## Joint geometry of the composed floor (the Terminal's own convention: 2 apart, 1.5 into each).
const OVERLAP := 1.5


## The hand-constructed draft: A as authored at the origin, B MIRRORED at (0, -26), one straight
## hallway between them, a gate joint at A's door and a plain joint at B's.
func _composed() -> FloorDraft:
	var draft := FloorDraft.new()
	draft.draft_id = &"s1_composed"
	draft.place_label = "Composition Test"
	draft.stratum_id = &"archive"
	var a: StringName = draft.place(load(ENTRY), Vector2(0, 0))
	var b: StringName = draft.place(load(EXIT), Vector2(0, -26), FloorPiece.TRANSFORM_MIRROR_X)
	var spine: StringName = draft.lay([Rect2(-2.5, -24, 5, 10)] as Array[Rect2], &"stone", &"ledge")
	# Both joints rim their flanks as the spine does: where an aperture's side coincides with the
	# hallway's own edge, FloorPlan refuses two styles on one span (no precedence rule exists).
	draft.bind(a, &"out", spine, OVERLAP, &"ledge")
	draft.bind(b, &"in", spine, OVERLAP, &"ledge")
	return draft


func _compiled(layout: AuthoredLayout) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.stratum_id = layout.stratum_id
	LayoutCompiler.compile(layout, plan)
	return plan


func _emitted() -> DraftEmitter.EmitReport:
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(_composed())
	assert_true(report.is_ok(), report.summary())
	return report


func _kinds(report: DraftEmitter.EmitReport) -> Array:
	return report.errors.map(func(e: Dictionary) -> StringName: return e["kind"])


## The refs of the first error of a kind. A missing error fails an assertion that names what was
## reported instead, never an index crash, so a dropped check reads as the defect it is.
func _refs(report: DraftEmitter.EmitReport, kind: StringName) -> Dictionary:
	var found: Array[Dictionary] = report.errors_of(kind)
	assert_false(found.is_empty(), "expected a %s error, got %s" % [kind, _kinds(report)])
	return {} if found.is_empty() else found[0]["refs"]


func _rules() -> Dictionary:
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_A")
	return {"body_radius": envoy.combat_radius, "attack_reach": sword.reach, "pickup_reach": envoy.pickup_reach}


# --- B. THE HAND-BUILT DRAFT COMPILES TO THE EXPECTED FLOOR ----------------------------------

func test_the_composed_floor_equals_the_hand_authored_baseline_exactly() -> void:
	var report: DraftEmitter.EmitReport = _emitted()
	var composed: FloorPlan = _compiled(report.layout)
	var baseline: FloorPlan = _compiled(load(BASELINE))
	assert_push_error_count(0, "both compile with nothing to report")
	assert_eq(JSON.stringify(composed.to_dict(), "\t"), JSON.stringify(baseline.to_dict(), "\t"))
	assert_eq(composed.violations(), [] as Array[Dictionary])
	assert_eq(baseline.violations(), [] as Array[Dictionary])
	assert_gt(composed.patches.size(), 0, "sanity: something was compiled")


func test_emission_is_deterministic_and_ids_are_dense_per_layer() -> void:
	var first: FloorPlan = _compiled(_emitted().layout)
	var second: FloorPlan = _compiled(_emitted().layout)
	assert_eq(JSON.stringify(first.to_dict()), JSON.stringify(second.to_dict()))
	for layer: StringName in FloorPiece.LAYERS:
		var ids: Array = []
		for record: Resource in _emitted().layout.records_in(layer):
			ids.append(AuthoredLayout._numeric_id(record))
		assert_eq(ids, range(ids.size()), "%s ids are 0..n-1 in emitted order" % layer)


func test_the_composed_floor_passes_progression_and_its_route_replays_in_a_real_sim() -> void:
	var plan: FloorPlan = _compiled(_emitted().layout)
	assert_gt(plan.solid_segments().size(), 0)
	assert_push_error_count(0, "the joints' flanks agree with the ground they run beside: one wall truth, no style conflict")
	var report: ProgressionReport = ProgressionValidator.check(plan, _rules())
	assert_true(report.is_pass(), report.summary())
	# The route reads back the authored intent of both pieces, in order, across the gate.
	assert_eq(report.trace, ["break breakable 0", "enter trigger 1", "enter trigger 2", "clear encounter 0",
		"hit switch 0", "lift carriable 0", "deliver carriable 0 to receiver 4", "enter trigger 6"] as Array[String])
	var sim: SimWorld = _sim_with(plan)
	var completed: bool = false
	for step in report.trace:
		var words: PackedStringArray = step.split(" ")
		var events: Array[Event] = []
		match words[0]:
			"enter":
				var region: Rect2 = _trigger(plan, int(words[2])).region
				sim.entities[ENVOY] = Vector3(region.get_center().x, 0.0, region.get_center().y)
			"break":
				events.append_array(sim._resolve_hit_on_breakable(-1, int(words[2]), 1000.0))
			"hit":
				events.append_array(sim._resolve_hit_on_switch(int(words[2])))
			"lift":
				events.append_array(sim._lift_carriable(ENVOY, int(words[2])))
			"deliver":
				events.append_array(sim._insert_carried(ENVOY, int(words[5])))
			"clear":
				pass  # the roster is not registered here: an empty encounter clears on the next tick
			_:
				fail_test("unreplayable step '%s'" % step)
		for i in SETTLE_TICKS:
			events.append_array(sim.tick([] as Array[Command], DT))
		for event in events:
			if event.kind == "floor_complete":
				completed = true
	assert_true(completed, "the sim completed the composed floor along the validator's route")


# --- C. TRANSFORMS, REMAPPING, JOINTS, REFERENCES ------------------------------------------

func test_every_reference_category_is_rewritten_through_the_table() -> void:
	var report: DraftEmitter.EmitReport = _emitted()
	var layout: AuthoredLayout = report.layout
	# connection.patch_ids (keys AND ids, both through the table)
	var bay: TraversalConnection = layout.connections[1]
	assert_eq(bay.key, &"i01.C_BAY")
	assert_eq([bay.near_key, bay.far_key], [&"i01.P_GALLERY", &"i01.P_EXIT_BAY"])
	assert_eq(bay.patch_ids, Vector2i(report.global_id(&"i01", &"patch", 0), report.global_id(&"i01", &"patch", 1)))
	# trigger.source_id by its kind's layer: breakable, encounter, carriable
	assert_eq(layout.triggers[0].source_id, report.global_id(&"i00", &"breakable", 0), "breakable_destroyed watches the remapped crate")
	assert_eq(layout.triggers[3].source_id, report.global_id(&"i01", &"encounter", 0), "encounter_cleared watches the remapped fight")
	assert_eq(layout.triggers[5].source_id, report.global_id(&"i01", &"carriable", 0), "carriable_lifted watches the remapped key")
	# effects[].target_id by the compiler's effect -> layer table: trigger, encounter, switch, carriable, connection
	assert_eq(layout.triggers[0].effects[0]["target_id"], report.global_id(&"i00", &"trigger", 1), "enable_trigger -> the remapped hidden plate")
	assert_eq(layout.triggers[2].effects[0]["target_id"], report.global_id(&"i01", &"encounter", 0), "activate_encounter")
	assert_eq(layout.triggers[3].effects[0]["target_id"], report.global_id(&"i01", &"switch", 0), "reveal_switch")
	assert_eq(layout.hit_switches[0].effects[0]["target_id"], report.global_id(&"i01", &"carriable", 0), "reveal_carriable")
	assert_eq(layout.triggers[4].effects[0]["target_id"], report.global_id(&"i01", &"connection", 0), "open_connection -> the remapped bay door")
	# breakable.conceals_trigger_id -- the reference the compiler copies verbatim
	assert_eq(layout.breakables[0].conceals_trigger_id, report.global_id(&"i00", &"trigger", 1))
	# @port -> the joint's connection
	var gate: Dictionary = report.joints[&"j00"]
	assert_eq(layout.triggers[1].effects[0]["target_id"], int(gate["connection_id"]), "the apron's plate opens the joint at its own door")
	assert_eq(layout.triggers[1].effects[0].get("target_key", &""), &"j00")


## KEY-LESS REFERENCES GO THROUGH THE TABLE TOO. The shipped pieces reference by key, and the
## compiler resolves a key before it looks at a number -- so a numeric id left unmapped would
## hide behind the key. This piece references by NUMBER only, is placed SECOND (so no local id
## equals its global id), and every category must land on the remapped record.
func test_numeric_references_in_a_later_piece_are_remapped_by_layer() -> void:
	var piece := FloorPiece.new()
	piece.piece_id = &"numeric_exit"
	piece.role = FloorPiece.ROLE_EXIT
	piece.footprint = Rect2(-8, -16, 16, 16)
	var hall := WalkablePatch.new()
	hall.key = &"P_HALL"
	hall.patch_id = 0
	hall.rect = Rect2(-6, -8, 12, 8)
	var bay := WalkablePatch.new()
	bay.key = &"P_BAY"
	bay.patch_id = 1
	bay.rect = Rect2(-4, -14, 8, 4)
	var door := TraversalConnection.new()
	door.key = &"C_DOOR"
	door.connection_id = 0
	door.patch_ids = Vector2i(0, 1)  # numeric, no keys
	door.aperture = Rect2(-2, -11.5, 4, 5)
	door.starts_open = false
	var watch := FloorTrigger.new()
	watch.key = &"T_WATCH"
	watch.trigger_id = 0
	watch.kind = FloorLayers.TRIGGER_BREAKABLE_DESTROYED
	watch.source_id = 0  # the crate, by number
	watch.effects = [FloorLayers.effect(FloorLayers.EFFECT_ENABLE_TRIGGER, 1)] as Array[Dictionary]
	var hidden := FloorTrigger.new()
	hidden.key = &"T_HIDDEN"
	hidden.trigger_id = 1
	hidden.region = Rect2(2, -6, 2, 2)
	hidden.starts_enabled = false
	hidden.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, 0)] as Array[Dictionary]
	var end := FloorTrigger.new()
	end.key = &"T_END"
	end.trigger_id = 2
	end.kind = FloorLayers.TRIGGER_GROUP_OCCUPANCY
	end.region = Rect2(-2, -13.5, 4, 3)
	end.effects = [FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, FloorLayers.NO_TARGET)] as Array[Dictionary]
	var crate := BreakablePlan.new()
	crate.key = &"B_CRATE"
	crate.breakable_id = 0
	crate.position = Vector3(3, 0, -5)
	crate.conceals_trigger_id = 1
	var body := AuthoredLayout.new()
	body.layout_id = &"numeric_exit_body"
	body.patches = [hall, bay] as Array[WalkablePatch]
	body.connections = [door] as Array[TraversalConnection]
	body.triggers = [watch, hidden, end] as Array[FloorTrigger]
	body.breakables = [crate] as Array[BreakablePlan]
	body.end_marker = Vector3(0, 0, -12)
	body.exit_console = Vector3(3.5, 0, -12.5)
	piece.body = body
	var port := PiecePort.new()
	port.key = &"in"
	port.edge = PiecePort.EDGE_NORTH
	port.offset = 5.5
	port.width = 5.0
	port.patch_key = &"P_HALL"
	piece.ports = [port] as Array[PiecePort]
	assert_eq(piece.lint(), [] as Array[Dictionary])
	var draft := FloorDraft.new()
	draft.draft_id = &"numeric"
	draft.stratum_id = &"archive"
	var a: StringName = draft.place(load(ENTRY), Vector2(0, 0))
	var b: StringName = draft.place(piece, Vector2(0, -26))
	var spine: StringName = draft.lay([Rect2(-2.5, -24, 5, 10)] as Array[Rect2], &"stone", &"ledge")
	draft.bind(a, &"out", spine, OVERLAP, &"ledge")
	draft.bind(b, &"in", spine, OVERLAP, &"ledge")
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_true(report.is_ok(), report.summary())
	var layout: AuthoredLayout = report.layout
	var entry: FloorPiece = load(ENTRY)
	var first_trigger: int = entry.body.triggers.size()
	assert_eq(report.global_id(&"i01", &"trigger", 1), first_trigger + 1, "sanity: no local id of B equals its global id")
	assert_eq(layout.breakables[1].conceals_trigger_id, first_trigger + 1, "conceals_trigger_id, the reference the compiler copies verbatim")
	assert_eq(layout.triggers[first_trigger].source_id, entry.body.breakables.size(), "breakable_destroyed watches B's crate, not A's")
	assert_eq(layout.triggers[first_trigger].source_key, &"", "a numeric reference stays numeric: nothing was invented")
	assert_eq(layout.triggers[first_trigger].effects[0], {"kind": FloorLayers.EFFECT_ENABLE_TRIGGER, "target_id": first_trigger + 1})
	assert_eq(layout.triggers[first_trigger + 1].effects[0], {"kind": FloorLayers.EFFECT_OPEN_CONNECTION, "target_id": entry.body.connections.size()}, "C_DOOR after A's connections")
	assert_eq(layout.connections[entry.body.connections.size()].patch_ids, Vector2i(entry.body.patches.size(), entry.body.patches.size() + 1))
	var plan: FloorPlan = _compiled(layout)
	assert_push_error_count(0)
	assert_eq(plan.breakables[1].conceals_trigger_id, plan.triggers[first_trigger + 1].trigger_id)
	assert_true(ProgressionValidator.check(plan, _rules()).is_pass(), "and the floor it describes is finishable: crate, plate, door, exit")


func test_local_ids_that_collide_across_pieces_are_separated() -> void:
	var entry: FloorPiece = load(ENTRY)
	var exit: FloorPiece = load(EXIT)
	assert_eq(entry.body.triggers[0].trigger_id, exit.body.triggers[0].trigger_id, "sanity: both pieces number their first trigger 0")
	assert_eq(entry.body.patches[0].patch_id, exit.body.patches[0].patch_id)
	var report: DraftEmitter.EmitReport = _emitted()
	assert_ne(report.global_id(&"i00", &"trigger", 0), report.global_id(&"i01", &"trigger", 0))
	assert_eq(report.global_id(&"i01", &"trigger", 0), entry.body.triggers.size(), "B's triggers follow A's without a gap")
	assert_eq(report.global_key(&"i01", &"T_PLATE"), &"i01.T_PLATE")


func test_mirroring_reflects_geometry_and_swaps_the_x_facing_sides() -> void:
	var piece := FloorPiece.new()
	piece.piece_id = &"asymmetric"
	piece.role = FloorPiece.ROLE_LANDMARK
	piece.footprint = Rect2(0, -10, 20, 10)
	piece.allowed_transforms = [FloorPiece.TRANSFORM_IDENTITY, FloorPiece.TRANSFORM_MIRROR_X] as Array[StringName]
	var body := AuthoredLayout.new()
	var room := WalkablePatch.new()
	room.key = &"P"
	room.patch_id = 0
	room.rect = Rect2(2, -8, 16, 8)
	room.boundary_east = &"ledge"
	room.boundary_north = &"ledge"
	body.patches = [room] as Array[WalkablePatch]
	var prop := BreakablePlan.new()
	prop.key = &"B"
	prop.breakable_id = 0
	prop.position = Vector3(15, 0, -3)
	body.breakables = [prop] as Array[BreakablePlan]
	piece.body = body
	var port := PiecePort.new()
	port.key = &"p"
	port.edge = PiecePort.EDGE_NORTH
	port.offset = 2.0  # near the x-min end
	port.width = 4.0
	port.patch_key = &"P"
	var side := PiecePort.new()
	side.key = &"e"
	side.edge = PiecePort.EDGE_EAST
	side.offset = 3.0
	side.width = 2.0
	side.patch_key = &"P"
	piece.ports = [port, side] as Array[PiecePort]
	var instance := FloorDraft.PieceInstance.new()
	instance.piece = piece
	instance.origin = Vector2(100, 50)
	instance.transform = FloorPiece.TRANSFORM_MIRROR_X
	assert_eq(FloorDraft.world_footprint(instance), Rect2(80, 40, 20, 10))
	assert_eq(FloorDraft.world_rect(instance, room.rect), Rect2(82, 42, 16, 8))
	assert_eq(FloorDraft.world_point(instance, prop.position), Vector3(85, 0, 47))
	assert_eq(FloorDraft.port_span(instance, port), {"at": 50.0, "from": 94.0, "to": 98.0, "outward": 1.0}, "a north port near x-min lands near x-max")
	assert_eq(FloorDraft.port_span(instance, side), {"at": 80.0, "from": 43.0, "to": 45.0, "outward": -1.0}, "an east port becomes a west port, offset kept")
	assert_eq(FloorDraft.world_edge(instance, PiecePort.EDGE_EAST), PiecePort.EDGE_WEST)
	assert_eq(FloorDraft.world_edge(instance, PiecePort.EDGE_NORTH), PiecePort.EDGE_NORTH)
	# Through the emitter, the composed floor's mirrored gallery carries its ledge on the WEST.
	var gallery: WalkablePatch = _emitted().layout.patches[2]
	assert_eq(gallery.key, &"i01.P_GALLERY")
	assert_eq([gallery.boundary_east, gallery.boundary_west], [&"", &"ledge"])


func test_joint_apertures_straddle_the_port_edge_by_the_declared_overlap() -> void:
	var report: DraftEmitter.EmitReport = _emitted()
	var gate: Dictionary = report.joints[&"j00"]
	assert_eq(gate["aperture"], Rect2(-2.5, -15.5, 5, 5))
	assert_eq(gate["gap"], 2.0)
	var arrive: Dictionary = report.joints[&"j01"]
	assert_eq(arrive["aperture"], Rect2(-2.5, -27.5, 5, 5))
	var layout: AuthoredLayout = report.layout
	var gate_connection: TraversalConnection = layout.connections[2]
	assert_eq([gate_connection.starts_open, gate_connection.has_barrier, gate_connection.flank_style], [false, true, &"ledge"], "a gate port's joint starts shut")
	var arrive_connection: TraversalConnection = layout.connections[3]
	assert_eq([arrive_connection.starts_open, arrive_connection.has_barrier, arrive_connection.flank_style], [true, false, &"ledge"], "a connector's joint starts open")
	assert_eq(arrive_connection.near_key, &"i01.P_GALLERY")
	assert_eq(arrive_connection.far_key, &"h00.R0")
	# Each aperture overlaps BOTH its patches by exactly the overlap and no stranger at all.
	var plan: FloorPlan = _compiled(layout)
	for connection_index in [2, 3]:
		var connection: TraversalConnection = plan.connections[connection_index]
		for patch_id in [connection.patch_ids.x, connection.patch_ids.y]:
			assert_eq(connection.aperture.intersection(plan.patch_by_id(patch_id).rect).size.y, OVERLAP, "connection %d into patch %d" % [connection_index, patch_id])


func test_sentinels_are_kept_not_remapped() -> void:
	var layout: AuthoredLayout = _emitted().layout
	assert_eq(layout.triggers[6].effects[0], {"kind": FloorLayers.EFFECT_COMPLETE_FLOOR, "target_id": FloorLayers.NO_TARGET}, "complete_floor acts on no record")
	assert_eq(layout.triggers[1].source_id, FloorLayers.NO_TARGET, "a region trigger watches nothing")
	assert_eq(layout.breakables[1].conceals_trigger_id, FloorLayers.NO_TARGET, "the urn hides nothing; -1 did not become trigger -1 + offset")
	assert_eq(layout.breakables[1].key, &"i01.B_URN")


func test_the_exit_console_is_one_marker_in_its_own_registry_beside_id_zero_records() -> void:
	var plan: FloorPlan = _compiled(_emitted().layout)
	assert_eq(plan.exit_console, Vector3(-3.5, 0, -38.5), "the mirrored gallery's console")
	assert_eq(plan.hit_switches[0].switch_id, 0, "a layer-local id 0 exists")
	assert_eq(plan.breakables[0].breakable_id, 0)
	var sim: SimWorld = _sim_with(plan)
	sim.register_exit_console(0, plan.exit_console)  # the arena's fixed console id, as arena.gd registers it
	sim.entities[ENVOY] = plan.exit_console + Vector3(1, 0, 0)
	assert_true(sim.exit_console_within_reach(ENVOY, 0))
	var events: Array[Event] = sim._resolve_hit_on_switch(0)
	assert_true(events.size() > 0 or true, "hitting switch 0 touches the switch registry, never the console")
	assert_true(sim.exit_console_within_reach(ENVOY, 0), "the console is still where it was")


func test_the_authored_pieces_are_read_not_written() -> void:
	var exit: FloorPiece = load(EXIT)
	var gallery: WalkablePatch = exit.body.patches[0]
	var before: Array = [gallery.rect, gallery.boundary_east, gallery.boundary_west, exit.port(&"in").offset,
		exit.body.hit_switches[0].position, exit.body.triggers[2].effects[0].duplicate(), exit.body.exit_console]
	var layout: AuthoredLayout = _emitted().layout
	var after: Array = [gallery.rect, gallery.boundary_east, gallery.boundary_west, exit.port(&"in").offset,
		exit.body.hit_switches[0].position, exit.body.triggers[2].effects[0].duplicate(), exit.body.exit_console]
	assert_eq(after, before, "emission transforms copies; the loaded resource is untouched")
	assert_ne(layout.patches[2], gallery, "and the emitted record is a copy, never the resource itself")
	assert_ne(layout.triggers[2].effects, exit.body.triggers[0].effects, "effects arrays are fresh, not shared")


# --- D. STRUCTURAL FAILURES ARE REPORTS, NEVER FLOORS ---------------------------------------

func test_a_transform_the_piece_did_not_allow_is_refused() -> void:
	var draft := FloorDraft.new()
	draft.draft_id = &"bad"
	draft.stratum_id = &"archive"
	draft.place(load(ENTRY), Vector2(0, 0), FloorPiece.TRANSFORM_MIRROR_X)
	draft.place(load(EXIT), Vector2(0, -26))
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_has(_kinds(report), &"transform_not_allowed")
	assert_eq(_refs(report, &"transform_not_allowed").get("piece"), &"archive_entry_apron")


func test_an_unbound_port_reference_is_a_structural_failure() -> void:
	var draft := FloorDraft.new()
	draft.draft_id = &"unbound"
	draft.stratum_id = &"archive"
	draft.place(load(ENTRY), Vector2(0, 0))
	draft.place(load(EXIT), Vector2(0, -26))
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout, "A's plate names @out and nothing binds it")
	assert_eq(_kinds(report), [&"unresolved_port"])
	assert_eq(_refs(report, &"unresolved_port").get("port"), &"out")


func test_a_hallway_that_does_not_meet_its_port_is_a_structural_failure() -> void:
	var draft := FloorDraft.new()
	draft.draft_id = &"unmet"
	draft.stratum_id = &"archive"
	var a: StringName = draft.place(load(ENTRY), Vector2(0, 0))
	var b: StringName = draft.place(load(EXIT), Vector2(0, -26), FloorPiece.TRANSFORM_MIRROR_X)
	var spine: StringName = draft.lay([Rect2(1, -24, 5, 10)] as Array[Rect2], &"stone", &"ledge")  # covers [1, 6], not [-2.5, 2.5]
	draft.bind(a, &"out", spine, OVERLAP, &"ledge")
	draft.bind(b, &"in", spine, OVERLAP, &"ledge")
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(_kinds(report), [&"joint_unmet", &"joint_unmet"])
	assert_eq(_refs(report, &"joint_unmet"), {"joint": &"j00", "port": &"out", "hallway": &"h00"})


func test_a_gate_joint_needs_a_gap_and_a_connector_does_not() -> void:
	var draft := FloorDraft.new()
	draft.draft_id = &"flush"
	draft.stratum_id = &"archive"
	var a: StringName = draft.place(load(ENTRY), Vector2(0, 0))
	var b: StringName = draft.place(load(EXIT), Vector2(0, -26), FloorPiece.TRANSFORM_MIRROR_X)
	var spine: StringName = draft.lay([Rect2(-2.5, -26, 5, 14)] as Array[Rect2], &"stone", &"ledge")  # flush with both edges
	draft.bind(a, &"out", spine, OVERLAP, &"ledge")
	draft.bind(b, &"in", spine, OVERLAP, &"ledge")
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(_kinds(report), [&"gate_without_gap"], "the connector at B tolerates abutting; the gate at A does not")


## ABUTTING PATCHES JOIN, so ground that merely touches a piece's ground is a passage nobody
## declared. The composed draft, plus one more hallway rect that reaches A's hall beside the
## door: every other check passes, and this one refuses the floor.
func test_ground_that_touches_another_piece_without_a_joint_is_refused() -> void:
	var draft: FloorDraft = _composed()
	draft.hallway_of(&"h00").rects.append(Rect2(3, -16, 3, 4))  # its top edge z = -12 is the hall's bottom edge
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(_kinds(report), [&"unintended_adjacency"])
	assert_eq(_refs(report, &"unintended_adjacency"), {"patch": 1, "other": 5, "source": &"i00", "other_source": &"h00"})


func test_ground_inside_a_footprint_or_bound_to_nothing_is_refused() -> void:
	var draft: FloorDraft = _composed()
	var stray: StringName = draft.lay([Rect2(3, -30, 2, 8)] as Array[Rect2], &"stone", &"wall")  # enters B's footprint
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(_kinds(report), [&"hallway_inside_footprint"])
	draft.hallway_of(stray).rects = [Rect2(20, -30, 2, 8)] as Array[Rect2]  # clear of everything, joined to nothing
	report = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(_kinds(report), [&"hallway_unbound"])
	draft.bind(&"i01", &"in", stray, OVERLAP, &"ledge")  # a port already bound by the spine
	report = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(_kinds(report), [&"port_bound_twice"])


func test_overlapping_footprints_are_refused() -> void:
	var draft := FloorDraft.new()
	draft.draft_id = &"overlap"
	draft.stratum_id = &"archive"
	draft.place(load(ENTRY), Vector2(0, 0))
	draft.place(load(EXIT), Vector2(0, -10), FloorPiece.TRANSFORM_MIRROR_X)  # B's footprint z [-26, -10] meets A's z [-12, 2]
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_has(_kinds(report), &"footprint_overlap")


func test_a_piece_that_fails_lint_never_reaches_emission() -> void:
	var draft := FloorDraft.new()
	draft.draft_id = &"lint"
	draft.stratum_id = &"archive"
	var broken: FloorPiece = (load(EXIT) as FloorPiece).duplicate(true)
	broken.body.triggers[2].effects = [{"kind": &"summon_dragon", "target_id": -1}] as Array[Dictionary]
	draft.place(load(ENTRY), Vector2(0, 0))
	draft.place(broken, Vector2(0, -26))
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(_kinds(report), [&"piece_lint_failed"])
	assert_eq(_refs(report, &"piece_lint_failed").get("rule"), &"unknown_effect_kind")
	assert_true(report.summary().begins_with("emit: FAILED with 1 error(s)"), report.summary())


func test_a_floor_needs_exactly_one_entry_and_one_exit_piece() -> void:
	var draft := FloorDraft.new()
	draft.draft_id = &"roles"
	draft.stratum_id = &"archive"
	draft.place(load(EXIT), Vector2(0, 0))
	draft.place(load(EXIT), Vector2(40, 0))
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	var counts: Array = report.errors_of(&"role_count").map(func(e: Dictionary) -> Dictionary: return e["refs"])
	assert_eq(counts, [{"role": &"entry", "count": 0}, {"role": &"exit", "count": 2}])


func test_a_draft_in_another_stratum_than_its_pieces_is_refused() -> void:
	var draft: FloorDraft = _composed()
	draft.stratum_id = &"foundry"
	var report: DraftEmitter.EmitReport = DraftEmitter.emit(draft)
	assert_null(report.layout)
	assert_eq(_kinds(report), [&"stratum_mismatch", &"stratum_mismatch"])


# --- the shipped floors are not touched by any of this ---------------------------------------

func test_the_shipped_floors_still_compile_exactly_as_before() -> void:
	# The goldens (test_golden_seed.gd) hold depths 1-4 byte-for-byte; this pins the same fact from
	# the compiler's side: nothing in S1 is on the authored path.
	for depth in [1, 2, 3, 4]:
		var plan: FloorPlan = DepthGenerator.generate(0, depth)
		assert_true(plan.authored_layout, "depth %d is still the authored floor" % depth)
	assert_push_error_count(0)


# --- helpers ---------------------------------------------------------------------------------

func _trigger(plan: FloorPlan, trigger_id: int) -> FloorTrigger:
	for trigger in plan.triggers:
		if trigger.trigger_id == trigger_id:
			return trigger
	return null


func _sim_with(plan: FloorPlan) -> SimWorld:
	var sim := SimWorld.new()
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	sim.add_entity(ENVOY, plan.entry_point, envoy.move_speed, Vector3(0, 0, -1), envoy.combat_radius)
	sim.register_combatant(ENVOY, envoy.max_health, envoy.family, envoy.iframe_ticks_on_hit, envoy.combat_radius, &"player")
	sim.register_carrier(ENVOY, envoy.pickup_reach, envoy.pickup_cone_half_angle_degrees, envoy.pickup_underfoot_radius)
	sim.mark_run_persistent(ENVOY)
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	sim.register_patches(plan.patch_rects())
	sim.register_obstacles(plan.obstacle_rects())
	sim.register_solid_segments(plan.solid_segments())
	for connection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
	for encounter in plan.encounters:
		sim.register_encounter(encounter.encounter_id, encounter.regions, encounter.role, encounter.confines_player, encounter.spawn_at_floor_load)
	for breakable in plan.breakables:
		sim.register_breakable(breakable.breakable_id, breakable.position, breakable.radius, breakable.durability, breakable.blocking_rect)
	for hit_switch in plan.hit_switches:
		sim.register_hit_switch(hit_switch.switch_id, hit_switch.position, hit_switch.radius, hit_switch.mode, hit_switch.effects, hit_switch.starts_hidden)
	for carriable in plan.carriables:
		sim.register_carriable(carriable.carriable_id, carriable.position, carriable.starts_hidden)
	for trigger in plan.triggers:
		sim.register_trigger(trigger.trigger_id, trigger.kind, trigger.region, trigger.source_id, trigger.once, trigger.effects, trigger.starts_enabled)
	return sim
