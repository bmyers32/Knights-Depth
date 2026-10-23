extends GutTest
## FloorPlan.violations() IS validate() RETURNED (ADR-001 S0). One set of rules, two readers:
## validate() reports every finding as a push_error exactly as before; violations() hands the same
## findings to a caller that must DECIDE -- a generator rejecting a candidate. These tests hold the
## two together so the rules can never drift apart, and pin that the shipped floors are clean.

const RADIUS := 0.45

const LAYOUTS: Array[String] = [
	"res://game/content/layouts/archive_prototype.tres",
	"res://game/content/layouts/archive_roundabout.tres",
	"res://game/content/layouts/terminal.tres",
	"res://game/content/layouts/foundry_assembly.tres",
	"res://game/content/layouts/home.tres",
	"res://game/content/layouts/commons.tres",
	"res://game/content/layouts/ready_room.tres",
]


func _patch(patch_id: int, rect: Rect2) -> WalkablePatch:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	return patch


func _connection(connection_id: int, near_id: int, far_id: int, aperture: Rect2, starts_open: bool) -> TraversalConnection:
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = aperture
	connection.starts_open = starts_open
	return connection


func _compiled(path: String) -> FloorPlan:
	var plan := FloorPlan.new()
	LayoutCompiler.compile(load(path), plan)
	return plan


## The violation at an index. A missing record is an assertion failure that names what was
## returned, never an index crash, so a dropped rule reads as the defect it is.
func _violation_at(found: Array[Dictionary], index: int) -> Dictionary:
	assert_lt(index, found.size(), "expected a violation at %d, got %s" % [index, found])
	if index >= found.size():
		return {"rule": &"", "message": "", "refs": {}}
	return found[index]


func test_every_shipped_layout_has_no_violations() -> void:
	for path in LAYOUTS:
		assert_eq(_compiled(path).violations(), [] as Array[Dictionary], path)
	assert_push_error_count(0)


## Every violation validate() would have reported is a record, with the same sentence.
func test_a_bypassable_gate_is_returned_and_still_reported() -> void:
	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, Rect2(-10, -10, 20, 10)))
	plan.patches.append(_patch(1, Rect2(-10, 0, 20, 10)))  # abuts patch 0: the gate separates nothing
	plan.connections.append(_connection(0, 0, 1, Rect2(-2.5, -1.5, 5, 3), false))
	var found: Array[Dictionary] = plan.violations()
	assert_eq(found.size(), 1)
	var gate: Dictionary = _violation_at(found, 0)
	assert_eq(gate["rule"], &"bypassable_gate")
	assert_eq(gate["refs"], {"connection": 0, "patch": 0, "other_patch": 1})
	assert_true(gate["message"].contains("patches 0 and 1 touch directly"), gate["message"])
	plan.validate()
	assert_push_error(gate["message"])


func test_a_connection_naming_a_missing_patch_is_returned() -> void:
	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, Rect2(-10, -10, 20, 10)))
	plan.connections.append(_connection(3, 0, 9, Rect2(-2.5, -1.5, 5, 3), true))
	var rules: Array = plan.violations().map(func(v: Dictionary) -> StringName: return v["rule"])
	assert_eq(rules, [&"unnamed_connection_patch"])
	assert_eq(_violation_at(plan.violations(), 0)["refs"].get("patch"), 9)


func test_an_impassable_aperture_is_returned_only_when_bodies_are_known() -> void:
	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, Rect2(-10, -12, 20, 10)))
	plan.patches.append(_patch(1, Rect2(-10, 0, 20, 10)))
	plan.connections.append(_connection(0, 0, 1, Rect2(-0.5, -3, 1, 4), true))  # 1.0 wide across travel
	var site := EncounterSite.new()
	site.encounter_id = 0
	site.roster = [{"enemy_key": &"ooze", "position": Vector3(0, 0, 5)}]
	plan.encounters.append(site)
	assert_eq(plan.violations(), [] as Array[Dictionary], "no bodies supplied: the clearance rule cannot run")
	var found: Array[Dictionary] = plan.violations({&"ooze": 0.9})
	assert_eq(found.size(), 1)
	assert_eq(_violation_at(found, 0)["rule"], &"impassable_aperture")
	assert_eq(_violation_at(found, 0)["refs"], {"connection": 0})


func test_props_and_keys_off_floor_are_returned_with_their_ids() -> void:
	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, Rect2(-10, -10, 20, 20)))
	var prop := BreakablePlan.new()
	prop.breakable_id = 7
	prop.position = Vector3(40, 0, 40)
	prop.durability = 3.0
	plan.breakables.append(prop)
	var key := CarriablePlan.new()
	key.carriable_id = 2
	key.position = Vector3(-40, 0, 0)
	plan.carriables.append(key)
	var rules: Array = plan.violations().map(func(v: Dictionary) -> StringName: return v["rule"])
	assert_eq(rules, [&"high_durability_prop", &"prop_off_floor", &"carriable_off_floor"])
	assert_eq(_violation_at(plan.violations(), 1)["refs"], {"breakable": 7})
	assert_eq(_violation_at(plan.violations(), 2)["refs"], {"carriable": 2})
	plan.validate()
	assert_push_error_count(3)


func test_a_receiver_that_is_not_once_is_returned() -> void:
	var plan := FloorPlan.new()
	plan.patches.append(_patch(0, Rect2(-10, -10, 20, 20)))
	var receiver := FloorTrigger.new()
	receiver.trigger_id = 4
	receiver.kind = FloorLayers.TRIGGER_CARRIABLE_INSERTED
	receiver.region = Rect2(-1, -1, 2, 2)
	receiver.once = false
	plan.triggers.append(receiver)
	var found: Array[Dictionary] = plan.violations()
	assert_eq(found.size(), 1)
	assert_eq(_violation_at(found, 0)["rule"], &"receiver_not_once")
	assert_eq(_violation_at(found, 0)["refs"], {"trigger": 4})
