extends GutTest
## Home, the Commons and the Ready Room are SAFE BY CONTENT (M2 Slice 3), exactly as the Terminal
## is: nothing in any of them can hurt anyone, and only the Ready Room can complete a "floor" --
## the deployment pad. These are the facts HubSpace relies on and does not re-check.

const HOME := preload("res://game/content/layouts/home.tres")
const COMMONS := preload("res://game/content/layouts/commons.tres")
const READY_ROOM := preload("res://game/content/layouts/ready_room.tres")
const HUBS: Array[AuthoredLayout] = [HOME, COMMONS, READY_ROOM]
## The provisional Commons greybox (human ruling 2026-10-21): about 60 x 44, not a final size.
const COMMONS_FOOTPRINT := Vector2(60.0, 44.0)
const COMMONS_DISTRICT_BAYS: Array[StringName] = [&"P_WEST_BAY", &"P_EAST_BAY", &"P_NORTH_BAY"]
## Pad placement: far enough from where the Envoy arrives that only a deliberate walk reaches it.
const MIN_PAD_DISTANCE_FROM_ENTRY: float = 12.0


func _compile(layout: AuthoredLayout) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.stratum_id = layout.stratum_id
	LayoutCompiler.compile(layout, plan)
	plan.validate({})
	return plan


func _completing_triggers(plan: FloorPlan) -> Array[FloorTrigger]:
	var found: Array[FloorTrigger] = []
	for trigger in plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") == FloorLayers.EFFECT_COMPLETE_FLOOR:
				found.append(trigger)
	return found


func _on_a_patch(plan: FloorPlan, at: Vector3) -> bool:
	for patch in plan.patches:
		if WalkableBounds.contains(patch.rect, at.x, at.z):
			return true
	return false


func test_no_hub_space_holds_anything_that_can_hurt_or_be_fought() -> void:
	for layout: AuthoredLayout in HUBS:
		var plan: FloorPlan = _compile(layout)
		assert_eq(plan.encounters.size(), 0, "%s: no roster" % layout.layout_id)
		assert_eq(plan.spike_pads.size(), 0, "%s: no hazards" % layout.layout_id)
		assert_eq(plan.breakables.size(), 0, "%s: no props to fight" % layout.layout_id)
		assert_eq(plan.hit_switches.size(), 0, "%s: no switches" % layout.layout_id)
		assert_eq(plan.carriables.size(), 0, "%s: no keys" % layout.layout_id)
		for trigger in plan.triggers:
			for effect: Dictionary in trigger.effects:
				assert_eq(effect["kind"], FloorLayers.EFFECT_COMPLETE_FLOOR, "%s: the only effect a hub authors is deployment" % layout.layout_id)


func test_only_the_ready_room_deploys_and_through_one_party_pad() -> void:
	assert_eq(_completing_triggers(_compile(HOME)).size(), 0, "Home can never start an expedition")
	assert_eq(_completing_triggers(_compile(COMMONS)).size(), 0, "nor can the Commons")
	var pads: Array[FloorTrigger] = _completing_triggers(_compile(READY_ROOM))
	assert_eq(pads.size(), 1, "exactly one deployment pad")
	assert_eq(pads[0].kind, FloorLayers.TRIGGER_GROUP_OCCUPANCY, "the party stands on it, as on every exit")
	assert_true(pads[0].renders_as_plate, "and it is drawn, so it is never stepped on unseen")


func test_the_pad_is_off_the_arrival_path() -> void:
	var plan: FloorPlan = _compile(READY_ROOM)
	var pad: Rect2 = _completing_triggers(plan)[0].region
	var entry := Vector2(plan.entry_point.x, plan.entry_point.z)
	assert_false(pad.has_point(entry), "arriving is not deploying")
	assert_gte(entry.distance_to(pad.get_center()), MIN_PAD_DISTANCE_FROM_ENTRY)
	for obstacle in plan.obstacles:
		assert_false(obstacle.rect.intersects(pad), "the pad is fully standable")


func test_every_hub_space_is_a_well_formed_place() -> void:
	for layout: AuthoredLayout in HUBS:
		var plan: FloorPlan = _compile(layout)
		assert_true(_on_a_patch(plan, plan.entry_point), "%s: the Envoy arrives on the floor" % layout.layout_id)
		assert_true(_on_a_patch(plan, plan.exit_console), "%s: its console stands on the floor" % layout.layout_id)
		assert_ne(plan.place_label, "", "%s: the place has a name" % layout.layout_id)
		# No mass-size cap here: the floors' 3-unit rule exists so enemies can path round cover,
		# and nothing paths in a hub (ruled 2026-10-22, for the Ready Room's console installation).
		for obstacle in plan.obstacles:
			assert_false(obstacle.rect.has_point(Vector2(plan.entry_point.x, plan.entry_point.z)))


## Compiled patches keep their id, not their authoring key.
func _patch(plan: FloorPlan, key: StringName) -> WalkablePatch:
	var id: int = COMMONS.id_in(&"patch", key)
	for patch in plan.patches:
		if patch.patch_id == id:
			return patch
	return null


func test_the_commons_is_a_plaza_with_three_joined_district_bays() -> void:
	var plan: FloorPlan = _compile(COMMONS)
	assert_eq(HubSpace._floor_extent_of(plan).size, COMMONS_FOOTPRINT, "the provisional greybox footprint")
	var plaza: WalkablePatch = _patch(plan, &"P_PLAZA")
	assert_not_null(plaza)
	for key in COMMONS_DISTRICT_BAYS:
		var bay: WalkablePatch = _patch(plan, key)
		assert_not_null(bay, String(key))
		assert_ne(bay.surface, plaza.surface, "%s reads as its own district" % key)
		assert_false(bay.rect.intersects(plaza.rect), "%s is a bay off the plaza, not part of it" % key)
		var mouths: int = 0
		for patch in plan.patches:
			if patch != bay and patch != plaza and patch.rect.intersects(bay.rect) and patch.rect.intersects(plaza.rect):
				mouths += 1
		assert_eq(mouths, 1, "%s opens onto the plaza through one mouth" % key)
	assert_true(plaza.rect.has_point(Vector2(plan.exit_console.x, plan.exit_console.z)), "the notice stands in the plaza")


func test_home_is_the_small_private_room_and_the_commons_far_larger() -> void:
	var home: Rect2 = HubSpace._floor_extent_of(_compile(HOME))
	var commons: Rect2 = HubSpace._floor_extent_of(_compile(COMMONS))
	assert_gt(commons.get_area(), home.get_area() * 2.0, "the shared hub is not a personal antechamber")
