extends GutTest
## THE COMPILER REFUSES BAD CONTENT (P36 Slice A).
##
## Semantic keys made the content legible; they also made it possible to author a reference that
## points at nothing, or at two things, or at the wrong KIND of thing. A compiler that resolved
## those quietly would hand the sim a floor full of real-looking ids whose doors open the wrong
## rooms -- a defect that reads as a content mistake for a week before anyone suspects the
## toolchain.
##
## These are detection tests, matching the project's existing convention: a plan is REPORTED,
## never silently repaired (FloorPlan.validate does the same).

const LAYOUT := preload("res://game/content/layouts/archive_roundabout.tres")


## TYPED ARRAYS ASSIGNED DIRECTLY. The first version of this fixture used set() with untyped
## array literals, which does not coerce into a typed @export -- so every layout came out empty,
## no error fired, and three tests "failed" for a reason that had nothing to do with the code
## under test. A fixture that cannot build the thing it is testing reports on itself.
func _layout() -> AuthoredLayout:
	var layout := AuthoredLayout.new()
	layout.layout_id = &"fixture"
	return layout


func _patch(key: StringName, id: int) -> WalkablePatch:
	var patch := WalkablePatch.new()
	patch.key = key
	patch.patch_id = id
	patch.rect = Rect2(0.0, 0.0, 10.0, 10.0)
	return patch


## THE SHIPPED CONTENT MUST BE CLEAN -- stated first, because a validator that fires on the real
## floors would be a false alarm rather than a guard, and the three tests below would all pass
## while the game was broken.
func test_the_shipped_floors_validate_without_complaint() -> void:
	LAYOUT.validate()
	var plan := FloorPlan.new()
	LayoutCompiler.compile(LAYOUT, plan)
	assert_push_error_count(0, "the authored floor must compile with nothing to report")
	assert_gt(plan.patches.size(), 0, "sanity: it must actually have compiled something")


func test_duplicate_keys_are_rejected() -> void:
	var layout := _layout()
	var patches: Array[WalkablePatch] = [_patch(&"P_TWICE", 1), _patch(&"P_TWICE", 2)]
	layout.patches = patches
	assert_eq(layout.patches.size(), 2, "sanity: the fixture must actually hold both records")
	layout.validate()
	assert_push_error("AuthoredLayout 'fixture': key 'P_TWICE' is used by more than one record, so a cross-reference to it would be ambiguous")


func test_an_unresolved_reference_is_rejected() -> void:
	var connection := TraversalConnection.new()
	connection.connection_id = 0
	connection.near_key = &"P_REAL"
	connection.far_key = &"P_MISSING"
	var layout := _layout()
	var patches: Array[WalkablePatch] = [_patch(&"P_REAL", 7)]
	var connections: Array[TraversalConnection] = [connection]
	layout.patches = patches
	layout.connections = connections
	var plan := FloorPlan.new()
	LayoutCompiler.compile(layout, plan)
	assert_push_error("AuthoredLayout 'fixture': no patch keyed 'P_MISSING'")
	assert_eq(plan.connections[0].patch_ids.y, -1,
		"an unresolved reference must not become a plausible id")


## THE ONE THAT MATTERS MOST. Keys are unique across a whole layout, so a lookup that searched
## every layer would resolve this to a REAL patch id and compile a connection-opening effect that
## points at a patch. Resolution is scoped to the layer the reference's kind demands.
func test_a_reference_to_the_wrong_layer_is_rejected() -> void:
	var trigger := FloorTrigger.new()
	trigger.trigger_id = 0
	trigger.kind = FloorLayers.TRIGGER_REGION
	var effects: Array[Dictionary] = [{"kind": FloorLayers.EFFECT_OPEN_CONNECTION, "target_key": &"P_COURTYARD"}]
	trigger.effects = effects
	var layout := _layout()
	var patches: Array[WalkablePatch] = [_patch(&"P_COURTYARD", 4)]
	var triggers: Array[FloorTrigger] = [trigger]
	layout.patches = patches
	layout.triggers = triggers
	var plan := FloorPlan.new()
	LayoutCompiler.compile(layout, plan)
	assert_push_error("AuthoredLayout 'fixture': no connection keyed 'P_COURTYARD'")
	assert_eq(plan.triggers[0].effects[0]["target_id"], -1,
		"a wrong-layer reference must not borrow a real id from the layer it does belong to")
