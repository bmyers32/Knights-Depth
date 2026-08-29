class_name FloorPlan
extends RefCounted
## One floor's complete deterministic description (CLAUDE.md Core Interfaces:
## DepthGenerator.generate(seed, depth) -> FloorPlan).
##
## FOUR INDEPENDENT LAYERS, none parenting another (see FloorLayers). The multi-room slice
## falsified rooms-plus-doors as the parent abstraction, so geometry, progression, encounters
## and interactions are now siblings that merely share coordinates.
##
## TWO VIEWS, ONE TRUTH:
##   patches + connections   the authoring view
##   open_walkable_rects()   the legality view the sim clamps against, DERIVED -- and derived
##                           per connection STATE, which is what makes a blocked gate real
##
## Plain data, RefCounted, no Node/Resource deps: headless-runnable by law (CLAUDE.md
## Structure) and serializable, which is what lets a server hand a joining client a floor in
## M3 (§4.1: floor layout is server-authoritative).
##
## SEED HONESTY. `run_seed` is canonical reproduction metadata and nothing more right now: the
## prototype floor is HAND-AUTHORED, so different seeds do NOT currently produce different
## spatial layouts. Procedural assembly is deferred until the grammar itself passes, and no
## UI or diagnostic may advertise variety that does not exist.

var run_seed: int = 0
var floor_seed: int = 0
var depth: int = 0
var stratum_id: StringName = &""
## True while the layout is authored rather than assembled. Read by the driver so the on-screen
## seed line can say so plainly instead of implying procedural variety.
var authored_layout: bool = true

# --- SPATIAL -------------------------------------------------------------------------
var patches: Array[WalkablePatch] = []
# --- PROGRESSION ---------------------------------------------------------------------
var connections: Array[TraversalConnection] = []
var triggers: Array[FloorTrigger] = []
# --- ENCOUNTER -----------------------------------------------------------------------
var encounters: Array[EncounterSite] = []
# --- WORLD INTERACTION ---------------------------------------------------------------
var interactables: Array[InteractablePlan] = []
var breakables: Array[BreakablePlan] = []

## Where the Envoy arrives.
var entry_point: Vector3 = Vector3.ZERO
## Deterministic terminal endpoint. NOT an elevator, no transition logic, no run-end UI --
## it exists so the traversal grammar has a visible end.
var end_marker: Vector3 = Vector3.ZERO


## The legality view, for a given set of open connections. A BLOCKED connection contributes
## nothing, which removes the passage beyond the threshold while each patch's own rect still
## covers its half of the aperture -- so blocking never shrinks a space or snaps an actor off
## a doorway.
func open_walkable_rects(open_connection_ids: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for patch in patches:
		rects.append(patch.rect)
	for connection in connections:
		if open_connection_ids.get(connection.connection_id, false):
			rects.append(connection.aperture)
	return rects


## Every rect regardless of connection state -- used for the camera's extent and for
## presentation, which draws corridors whether or not they are currently passable.
func all_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for patch in patches:
		rects.append(patch.rect)
	for connection in connections:
		rects.append(connection.aperture)
	return rects


## Just the ground, without any aperture. This is what the sim registers as the permanent
## spatial layer; connections are registered separately because their contribution comes and
## goes with their state.
func patch_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for patch in patches:
		rects.append(patch.rect)
	return rects


## The floor as it stands at load, before any trigger has fired. The sim rebuilds this itself
## the moment patches and connections are registered; this exists so load_floor always receives
## a real region rather than null.
func make_bounds() -> WalkableBounds:
	var open_ids: Dictionary = {}
	for connection in connections:
		open_ids[connection.connection_id] = connection.starts_open
	return WalkableBounds.new(open_walkable_rects(open_ids))


func patch_by_id(patch_id: int) -> WalkablePatch:
	for patch in patches:
		if patch.patch_id == patch_id:
			return patch
	return null


func encounter_by_id(encounter_id: int) -> EncounterSite:
	for encounter in encounters:
		if encounter.encounter_id == encounter_id:
			return encounter
	return null


func encounters_of_role(role: StringName) -> Array[EncounterSite]:
	var matching: Array[EncounterSite] = []
	for encounter in encounters:
		if encounter.role == role:
			matching.append(encounter)
	return matching


## Every spawn on the floor, flattened, each tagged with the site that OWNS it. Ownership rides
## with the record because confinement is unconditional -- an actor without a site has no legal
## region, so the driver must never lose the association.
func all_spawns() -> Array[Dictionary]:
	var flattened: Array[Dictionary] = []
	for encounter in encounters:
		for spawn in encounter.roster:
			flattened.append({
				"enemy_key": spawn["enemy_key"],
				"position": spawn["position"],
				"encounter_id": encounter.encounter_id,
			})
	return flattened


## Canonical serialization for the golden fixture (GAME-RULES §5 M2: same seed -> byte-identical
## FloorPlan). Floats snap to 4 decimals: raw determinism is proved separately in memory by
## test_depth_generator.gd, so this only has to catch BEHAVIOURAL drift, and encoding float
## print-formatting would make the fixture fail on an engine patch bump for a reason unrelated
## to generation changing.
func to_dict() -> Dictionary:
	var patch_dicts: Array = []
	for patch in patches:
		patch_dicts.append({
			"patch_id": patch.patch_id, "rect": _rect(patch.rect),
			"elevation": _snap(patch.elevation), "surface": String(patch.surface),
			"boundary_style": String(patch.boundary_style),
		})
	var connection_dicts: Array = []
	for connection in connections:
		connection_dicts.append({
			"connection_id": connection.connection_id,
			"patch_ids": [connection.patch_ids.x, connection.patch_ids.y],
			"aperture": _rect(connection.aperture),
			"starts_open": connection.starts_open, "has_barrier": connection.has_barrier,
		})
	var trigger_dicts: Array = []
	for trigger in triggers:
		trigger_dicts.append({
			"trigger_id": trigger.trigger_id, "kind": String(trigger.kind),
			"region": _rect(trigger.region), "source_id": trigger.source_id,
			"once": trigger.once, "effects": trigger.effects.map(func(e): return {"kind": String(e["kind"]), "target_id": e["target_id"]}),
		})
	var encounter_dicts: Array = []
	for encounter in encounters:
		var roster: Array = []
		for spawn in encounter.roster:
			roster.append({"enemy_key": String(spawn["enemy_key"]), "position": _point(spawn["position"])})
		var region_dicts: Array = []
		for region: Rect2 in encounter.regions:
			region_dicts.append(_rect(region))
		encounter_dicts.append({
			"encounter_id": encounter.encounter_id, "regions": region_dicts,
			"role": String(encounter.role), "confines_player": encounter.confines_player,
			"spawn_at_floor_load": encounter.spawn_at_floor_load, "roster": roster,
		})
	var interactable_dicts: Array = []
	for interactable in interactables:
		interactable_dicts.append({
			"interactable_id": interactable.interactable_id, "position": _point(interactable.position),
			"use_radius": _snap(interactable.use_radius), "kind": String(interactable.kind),
			"starts_hidden": interactable.starts_hidden,
		})
	var breakable_dicts: Array = []
	for breakable in breakables:
		breakable_dicts.append({
			"breakable_id": breakable.breakable_id, "position": _point(breakable.position),
			"radius": _snap(breakable.radius), "durability": _snap(breakable.durability),
			"conceals_interactable_id": breakable.conceals_interactable_id,
		})
	return {
		"run_seed": run_seed, "floor_seed": floor_seed, "depth": depth,
		"stratum_id": String(stratum_id), "authored_layout": authored_layout,
		"patches": patch_dicts, "connections": connection_dicts, "triggers": trigger_dicts,
		"encounters": encounter_dicts, "interactables": interactable_dicts,
		"breakables": breakable_dicts,
		"entry_point": _point(entry_point), "end_marker": _point(end_marker),
	}


func _rect(rect: Rect2) -> Dictionary:
	return {"x": _snap(rect.position.x), "z": _snap(rect.position.y), "w": _snap(rect.size.x), "d": _snap(rect.size.y)}


func _point(point: Vector3) -> Dictionary:
	return {"x": _snap(point.x), "y": _snap(point.y), "z": _snap(point.z)}


func _snap(value: float) -> float:
	return snappedf(value, 0.0001)
