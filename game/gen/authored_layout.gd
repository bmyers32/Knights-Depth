class_name AuthoredLayout
extends Resource
## ONE AUTHORED FLOOR, AS CONTENT (P36 Slice A).
##
## Floor 1 and Floor 2 were builder FUNCTIONS: 129 placement calls across two scripts, each
## script carrying its own private copy of the same twelve helpers. That was correct while one
## floor existed and it stopped being correct at the second -- the duplication was the smell, and
## the values were never code in the first place. They are coordinates.
##
## WHAT THIS IS NOT. It is not a floor FORMAT, a room grammar, a segment pool or a mission. It
## holds exactly the eight layer arrays a FloorPlan already has, plus its two markers, and
## nothing above a single floor. Sequences, families and roles have ONE consumer each today and
## are deferred on that ground (P36 audit).
##
## WHAT STAYS IN CODE. Everything that reasons: the compiler, the validators, the generator's
## selection. And the WHY -- every layer class keeps its own commentary, because the reasoning
## for a boundary style belongs next to the boundary style, not in a data file that cannot hold
## a sentence.
##
## IDS ARE AUTHORED, NOT DERIVED. Triggers target connections and encounters by integer id, so
## those integers are content with meaning. Whether they also need stable SEMANTIC names is an
## open question this slice deliberately leaves open: the .gd authoring records still exist and
## still carry the names, and retiring them is a separate decision with its own evidence.

## A human-readable name for the floor this describes. Debug and authoring only -- no mechanic
## reads it, and the generator selects by depth, not by name.
@export var layout_id: StringName = &""
## What this place is CALLED, when it has a name of its own (the Terminal). Empty for an ordinary
## floor, which is known by its stratum. Authored here and not derived from depth or stratum,
## because where a place currently sits in the descent is not what it is.
@export var place_label: String = ""

@export var patches: Array[WalkablePatch] = []
@export var connections: Array[TraversalConnection] = []
@export var triggers: Array[FloorTrigger] = []
@export var encounters: Array[EncounterSite] = []
@export var breakables: Array[BreakablePlan] = []
@export var hit_switches: Array[HitSwitchPlan] = []
@export var obstacles: Array[ObstaclePlan] = []
@export var spike_pads: Array[SpikePadPlan] = []

@export var entry_point: Vector3 = Vector3.ZERO
@export var end_marker: Vector3 = Vector3.ZERO


## THE NUMERIC ID BEHIND AN AUTHORING KEY. Keys are unique across the whole layout -- the
## authored prefixes (P_ / C_ / T_ / E_ / S_ / B_) guarantee it -- so one lookup serves every
## layer and a caller never has to say which kind of thing it is asking about.
##
## THIS IS THE SEAM TESTS USE. They previously reached into a builder script's constants, which
## only worked while the coordinates lived in code. Asking the CONTENT what its own names mean
## survives the builders being deleted.
## THE RECORDS OF ONE LAYER, by the compiler's name for it.
func records_in(layer: StringName) -> Array:
	match String(layer):
		"patch": return patches
		"connection": return connections
		"trigger": return triggers
		"encounter": return encounters
		"breakable": return breakables
		"switch": return hit_switches
		"obstacle": return obstacles
		"pad": return spike_pads
	return []


## THE NUMERIC ID BEHIND A KEY, WITHIN ONE LAYER -- which is the only safe way to ask.
##
## A cross-reference knows what kind of thing it points at: `open_connection` targets a
## connection, `breakable_destroyed` watches a breakable. Resolving against every layer at once
## would let `target_key = &"P_COURT"` on an open_connection quietly produce a real patch id and
## compile a floor whose door opens nothing. Returns -1 and reports when the key is absent.
func id_in(layer: StringName, wanted: StringName) -> int:
	for record in records_in(layer):
		if record.key == wanted:
			return _numeric_id(record)
	push_error("AuthoredLayout '%s': no %s keyed '%s'" % [layout_id, layer, wanted])
	return -1


## REFUSES AMBIGUITY AND DANGLING REFERENCES. Detection only, like FloorPlan.validate() -- a
## layout is reported, never silently repaired.
func validate() -> void:
	var seen: Dictionary = {}
	for record in _all_records():
		if record.key == &"":
			continue
		if seen.has(record.key):
			push_error(("AuthoredLayout '%s': key '%s' is used by more than one record, so a "
				+ "cross-reference to it would be ambiguous") % [layout_id, record.key])
		seen[record.key] = true


func id_for(wanted: StringName) -> int:
	for record in _all_records():
		if record.key == wanted:
			return _numeric_id(record)
	push_error("AuthoredLayout '%s' has no record keyed '%s'" % [layout_id, wanted])
	return -1


## THE REGION A KEYED TRIGGER OCCUPIES. Plate rects used to be script constants beside the
## builder; in content they are simply the trigger's own region, which is where they always
## should have been -- one fact rather than a constant and a usage that can drift apart.
func region_for(wanted: StringName) -> Rect2:
	for trigger: FloorTrigger in triggers:
		if trigger.key == wanted:
			return trigger.region
	push_error("AuthoredLayout '%s' has no trigger keyed '%s'" % [layout_id, wanted])
	return Rect2()


func _all_records() -> Array:
	var records: Array = []
	records.append_array(patches)
	records.append_array(connections)
	records.append_array(triggers)
	records.append_array(encounters)
	records.append_array(breakables)
	records.append_array(hit_switches)
	records.append_array(obstacles)
	records.append_array(spike_pads)
	return records


## Each layer names its id field differently, deliberately -- `patch_id` and `trigger_id` are not
## interchangeable and a single `id` would invite treating them as if they were.
static func _numeric_id(record: Resource) -> int:
	for field: String in ["patch_id", "connection_id", "trigger_id", "encounter_id",
			"breakable_id", "switch_id", "obstacle_id", "pad_id"]:
		if field in record:
			return record.get(field)
	return -1
