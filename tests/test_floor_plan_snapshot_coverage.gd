extends GutTest
## SNAPSHOT COVERAGE SCANNER for FloorPlan.to_dict() (GAME-RULES §5 M2 golden-seed gate).
##
## WHY IT EXISTS. to_dict() is hand-written, and by 2026-10-09 it had silently fallen three whole
## layers behind the plan it claims to describe (obstacles, spike pads, hit switches) plus two
## fields -- so the golden fixture was byte-identical across changes it should have caught. A
## golden gate is only as wide as its serializer, and nothing was watching the serializer.
##
## IT PROVES VALUES, NOT NAMES. Finding the string "height" somewhere in the output proves
## nothing. So the scan changes ONE field of a seeded plan at a time and requires the serialized
## form to change with it -- per component for vectors and rects, per element for arrays, per key
## for the dictionaries nested inside them.
##
## IT FINDS FIELDS BY REFLECTION, so a field or a whole layer added to the plan later is scanned
## without anyone remembering this file. A value it does not know how to change is REPORTED, never
## skipped: an unscannable field must not pass by default.

## Authoring identity only. LayoutCompiler resolves these into numeric ids and never copies them
## onto a compiled plan -- pinned by the last test here, against both shipped floors.
const AUTHORING_ONLY: Array[String] = ["key", "near_key", "far_key", "source_key"]

## A default-constructed record has empty nested collections, and an empty collection has nothing
## to change. One representative element each, named by the field that holds it.
const NESTED_SEEDS: Dictionary = {
	"effects": {"kind": &"open_connection", "target_id": 3},
	"roster": {"enemy_key": &"fang", "position": Vector3(1.0, 2.0, 3.0)},
	"regions": Rect2(1.0, 2.0, 3.0, 4.0),
}


func test_every_runtime_field_reaches_the_snapshot() -> void:
	var missing: Array[String] = _unrepresented(func(plan: FloorPlan) -> Dictionary: return plan.to_dict())
	assert_eq(missing, [] as Array[String],
		"these FloorPlan fields can change without the canonical snapshot changing, so the golden gate does not protect them")


# --- THE SCANNER, PROVED RED -----------------------------------------------------------------
# A scanner never seen to fail is not a scanner. Each test hands it a serializer with one known
# hole and requires it to name exactly that hole.

func test_the_scanner_catches_an_omitted_field() -> void:
	var missing: Array[String] = _unrepresented(func(plan: FloorPlan) -> Dictionary:
		var serialized: Dictionary = plan.to_dict()
		for obstacle: Dictionary in serialized["obstacles"]:
			obstacle.erase("height")
		return serialized)
	assert_eq(missing, ["plan.obstacles[0].height"] as Array[String])


func test_the_scanner_catches_an_omitted_nested_value() -> void:
	var missing: Array[String] = _unrepresented(func(plan: FloorPlan) -> Dictionary:
		var serialized: Dictionary = plan.to_dict()
		for hit_switch: Dictionary in serialized["hit_switches"]:
			for effect: Dictionary in hit_switch["effects"]:
				effect.erase("target_id")
		return serialized)
	assert_eq(missing, ["plan.hit_switches[0].effects[0].target_id"] as Array[String])


func test_the_scanner_catches_an_omitted_root_field_and_a_single_component() -> void:
	var missing: Array[String] = _unrepresented(func(plan: FloorPlan) -> Dictionary:
		var serialized: Dictionary = plan.to_dict()
		serialized.erase("floor_seed")
		serialized["end_marker"].erase("y")
		return serialized)
	assert_eq(missing, ["plan.floor_seed", "plan.end_marker.y"] as Array[String])


func test_the_scanner_catches_an_omitted_layer() -> void:
	var missing: Array[String] = _unrepresented(func(plan: FloorPlan) -> Dictionary:
		var serialized: Dictionary = plan.to_dict()
		serialized.erase("spike_pads")
		return serialized)
	assert_has(missing, "plan.spike_pads[0].eligible_allegiances[0]")
	assert_has(missing, "plan.spike_pads[0].rect.w")


# --- THE EXCLUSION LIST, PROVED HONEST -------------------------------------------------------

func test_the_excluded_fields_never_reach_a_compiled_plan() -> void:
	for depth: int in [1, 2]:
		var plan: FloorPlan = DepthGenerator.generate(20260828, depth)
		for layer: Array in [plan.patches, plan.connections, plan.triggers, plan.encounters,
				plan.breakables, plan.hit_switches, plan.obstacles, plan.spike_pads]:
			for record: Object in layer:
				for field: String in AUTHORING_ONLY:
					if field in record:
						assert_eq(record.get(field), &"",
							"depth %d: '%s' is excluded from the snapshot as authoring-only, but a compiled record carries it" % [depth, field])


# --- machinery ---------------------------------------------------------------------------------

func _unrepresented(serialize: Callable) -> Array[String]:
	var plan: FloorPlan = _seeded_plan()
	var missing: Array[String] = []
	_scan(plan, "plan", plan, serialize, missing)
	return missing


## One record in every layer, found by reflection: a typed layer array knows its own record class.
func _seeded_plan() -> FloorPlan:
	var plan := FloorPlan.new()
	for property: Dictionary in _script_variables(plan):
		var layer: Variant = plan.get(property["name"])
		if not layer is Array or layer.get_typed_script() == null:
			continue
		var record: Object = layer.get_typed_script().new()
		for nested: Dictionary in _script_variables(record):
			var collection: Variant = record.get(nested["name"])
			if collection is Array and collection.is_empty() and NESTED_SEEDS.has(nested["name"]):
				var seed_value: Variant = NESTED_SEEDS[nested["name"]]
				collection.append(seed_value.duplicate() if seed_value is Dictionary else seed_value)
		layer.append(record)
	return plan


func _scan(holder: Object, path: String, plan: FloorPlan, serialize: Callable, missing: Array[String]) -> void:
	for property: Dictionary in _script_variables(holder):
		var field: String = property["name"]
		if AUTHORING_ONLY.has(field):
			continue
		var original: Variant = holder.get(field)
		var field_path: String = "%s.%s" % [path, field]
		if original is Array and not original.is_empty() and original[0] is Object:
			for index: int in original.size():
				_scan(original[index], "%s[%d]" % [field_path, index], plan, serialize, missing)
			continue
		var variants: Array[Dictionary] = _mutations(original)
		if variants.is_empty():
			missing.append(field_path + " (the scanner cannot change this value -- seed it or teach _mutations its type)")
			continue
		var baseline: String = JSON.stringify(serialize.call(plan))
		for variant: Dictionary in variants:
			holder.set(field, variant["value"])
			if JSON.stringify(serialize.call(plan)) == baseline:
				missing.append(field_path + variant["at"])
		holder.set(field, original)


func _script_variables(object: Object) -> Array[Dictionary]:
	var variables: Array[Dictionary] = []
	for property: Dictionary in object.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			variables.append(property)
	return variables


## Every single-fact change of a value: {"at": path suffix, "value": the changed copy}. The float
## step is far above to_dict()'s 4-decimal snap, so a change can never round away.
func _mutations(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match typeof(value):
		TYPE_BOOL:
			out.append({"at": "", "value": not value})
		TYPE_INT:
			out.append({"at": "", "value": value + 7})
		TYPE_FLOAT:
			out.append({"at": "", "value": value + 1.5})
		TYPE_STRING:
			out.append({"at": "", "value": value + "_changed"})
		TYPE_STRING_NAME:
			out.append({"at": "", "value": StringName(String(value) + "_changed")})
		TYPE_VECTOR3:
			for axis: int in 3:
				var moved: Vector3 = value
				moved[axis] += 1.5
				out.append({"at": "." + "xyz"[axis], "value": moved})
		TYPE_VECTOR2I:
			for axis: int in 2:
				var moved: Vector2i = value
				moved[axis] += 7
				out.append({"at": "." + "xy"[axis], "value": moved})
		TYPE_RECT2:
			# Named as to_dict() names them, so a report reads like the fixture it is about.
			var steps: Dictionary = {
				"x": Rect2(1.5, 0.0, 0.0, 0.0), "z": Rect2(0.0, 1.5, 0.0, 0.0),
				"w": Rect2(0.0, 0.0, 1.5, 0.0), "d": Rect2(0.0, 0.0, 0.0, 1.5),
			}
			for component: String in steps:
				var step: Rect2 = steps[component]
				out.append({"at": "." + component,
					"value": Rect2(value.position + step.position, value.size + step.size)})
		TYPE_ARRAY:
			for index: int in value.size():
				for inner: Dictionary in _mutations(value[index]):
					var copy: Array = value.duplicate(true)
					copy[index] = inner["value"]
					out.append({"at": "[%d]%s" % [index, inner["at"]], "value": copy})
		TYPE_DICTIONARY:
			for key: Variant in value:
				for inner: Dictionary in _mutations(value[key]):
					var copy: Dictionary = value.duplicate(true)
					copy[key] = inner["value"]
					out.append({"at": ".%s%s" % [key, inner["at"]], "value": copy})
	return out
