class_name LayoutCompiler
extends RefCounted
## THE ONE BUILDER (P36 Slice A). Turns an AuthoredLayout into the layer arrays of a FloorPlan.
##
## IT REPLACES TWELVE HELPERS TIMES TWO. Each authored floor used to carry a private copy of
## `_patch`, `_connect`, `_trigger`, `_mass`, `_spikes`, `_breakable` and `_encounter`. Two
## copies of the same twelve functions was the actual duplication in the floor layer -- not the
## coordinates, which were always data.
##
## EVERY RECORD IS COPIED, NEVER ALIASED, and that is the whole safety argument for this file.
## A .tres is cached by path and shared by every caller, so handing a loaded record straight to a
## FloorPlan would let one run mutate the content of the next -- the same class of defect as a
## node holding gameplay state. Each field is copied into a fresh instance, and the Array and
## Dictionary fields are deep-copied because those are reference types in GDScript and a shallow
## copy would share them silently.
##
## IT ADDS NO BEHAVIOUR. This is a representation migration: the plan it produces must be
## byte-identical to the one the builder functions produced, and a parity harness proves it
## rather than a comment claiming it. If this file ever starts DECIDING something -- defaulting a
## value, deriving an id, inferring a style -- that is the moment it stopped being a compiler.


## Effect kinds, and which layer each one's target lives in. Listed rather than inferred: a kind
## whose target layer is guessed wrongly resolves to a real id in the wrong layer, which is the
## kind of defect that looks like a content error for a week.
const _EFFECT_TARGET_LAYER: Dictionary = {
	&"open_connection": &"connection", &"block_connection": &"connection",
	&"toggle_connection": &"connection", &"activate_encounter": &"encounter",
	&"enable_trigger": &"trigger", &"reveal_switch": &"switch",
	&"reveal_carriable": &"carriable",
	&"complete_floor": &"none", &"restore_envoy_health": &"none",
}

const _TRIGGER_SOURCE_LAYER: Dictionary = {
	&"breakable_destroyed": &"breakable", &"encounter_cleared": &"encounter",
	&"switch_activated": &"switch", &"carriable_lifted": &"carriable",
}


static func compile(layout: AuthoredLayout, plan: FloorPlan) -> void:
	# AMBIGUOUS KEYS ARE CAUGHT BEFORE ANYTHING IS BUILT. A duplicate key does not fail loudly on
	# its own -- the first match simply wins -- so it has to be looked for deliberately.
	layout.validate()
	for patch: WalkablePatch in layout.patches:
		var copy := WalkablePatch.new()
		copy.patch_id = patch.patch_id
		copy.rect = patch.rect
		copy.elevation = patch.elevation
		copy.surface = patch.surface
		copy.boundary_style = patch.boundary_style
		copy.boundary_north = patch.boundary_north
		copy.boundary_south = patch.boundary_south
		copy.boundary_east = patch.boundary_east
		copy.boundary_west = patch.boundary_west
		plan.patches.append(copy)

	for connection: TraversalConnection in layout.connections:
		var copy := TraversalConnection.new()
		copy.connection_id = connection.connection_id
		copy.patch_ids = Vector2i(
			_resolve(layout, &"patch", connection.near_key, connection.patch_ids.x),
			_resolve(layout, &"patch", connection.far_key, connection.patch_ids.y))
		copy.aperture = connection.aperture
		copy.starts_open = connection.starts_open
		copy.has_barrier = connection.has_barrier
		copy.flank_style = connection.flank_style
		plan.connections.append(copy)

	for trigger: FloorTrigger in layout.triggers:
		var copy := FloorTrigger.new()
		copy.trigger_id = trigger.trigger_id
		copy.kind = trigger.kind
		copy.region = trigger.region
		copy.source_id = _resolve(layout,
			_TRIGGER_SOURCE_LAYER.get(trigger.kind, &"none"), trigger.source_key, trigger.source_id)
		copy.once = trigger.once
		copy.starts_enabled = trigger.starts_enabled
		copy.renders_as_plate = trigger.renders_as_plate
		copy.effects = _copy_effects(trigger.effects, layout)
		plan.triggers.append(copy)

	for site: EncounterSite in layout.encounters:
		var copy := EncounterSite.new()
		copy.encounter_id = site.encounter_id
		var regions: Array[Rect2] = []
		for region: Rect2 in site.regions:
			regions.append(region)
		copy.regions = regions
		copy.role = site.role
		var roster: Array[Dictionary] = []
		for spawn: Dictionary in site.roster:
			roster.append({"enemy_key": spawn["enemy_key"], "position": spawn["position"]})
		copy.roster = roster
		copy.confines_player = site.confines_player
		copy.spawn_at_floor_load = site.spawn_at_floor_load
		plan.encounters.append(copy)

	for breakable: BreakablePlan in layout.breakables:
		var copy := BreakablePlan.new()
		copy.breakable_id = breakable.breakable_id
		copy.position = breakable.position
		copy.radius = breakable.radius
		copy.durability = breakable.durability
		copy.conceals_trigger_id = breakable.conceals_trigger_id
		copy.blocking_rect = breakable.blocking_rect
		plan.breakables.append(copy)

	for hit_switch: HitSwitchPlan in layout.hit_switches:
		var copy := HitSwitchPlan.new()
		copy.switch_id = hit_switch.switch_id
		copy.position = hit_switch.position
		copy.radius = hit_switch.radius
		copy.mode = hit_switch.mode
		copy.effects = _copy_effects(hit_switch.effects, layout)
		copy.starts_hidden = hit_switch.starts_hidden
		plan.hit_switches.append(copy)

	for obstacle: ObstaclePlan in layout.obstacles:
		var copy := ObstaclePlan.new()
		copy.obstacle_id = obstacle.obstacle_id
		copy.rect = obstacle.rect
		copy.height = obstacle.height
		plan.obstacles.append(copy)

	for pad: SpikePadPlan in layout.spike_pads:
		var copy := SpikePadPlan.new()
		copy.pad_id = pad.pad_id
		copy.rect = pad.rect
		copy.safe_ticks = pad.safe_ticks
		copy.active_ticks = pad.active_ticks
		copy.phase_offset_ticks = pad.phase_offset_ticks
		copy.damage = pad.damage
		copy.damage_type = pad.damage_type
		var allegiances: Array[StringName] = []
		for allegiance: StringName in pad.eligible_allegiances:
			allegiances.append(allegiance)
		copy.eligible_allegiances = allegiances
		plan.spike_pads.append(copy)

	for carriable: CarriablePlan in layout.carriables:
		var copy := CarriablePlan.new()
		copy.carriable_id = carriable.carriable_id
		copy.position = carriable.position
		copy.starts_hidden = carriable.starts_hidden
		plan.carriables.append(copy)

	plan.place_label = layout.place_label
	plan.entry_point = layout.entry_point
	plan.end_marker = layout.end_marker
	plan.exit_console = layout.exit_console


## Effects reach the FloorPlan as {kind, target_id} exactly as before -- numeric, because that is
## what the sim consumes and ruling 2 forbids redesigning runtime identity. Content may author
## `target_key` instead; it is resolved here and never travels further.
static func _copy_effects(effects: Array[Dictionary], layout: AuthoredLayout) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for effect: Dictionary in effects:
		var kind: StringName = effect["kind"]
		if not _EFFECT_TARGET_LAYER.has(kind):
			push_error("LayoutCompiler: effect kind '%s' has no known target layer" % kind)
		var target: int = _resolve(layout, _EFFECT_TARGET_LAYER.get(kind, &"none"),
			effect.get("target_key", &""), effect.get("target_id", -1))
		copied.append({"kind": kind, "target_id": target})
	return copied


## A key wins when present; otherwise the authored numeric id stands. That fallback is what lets
## content migrate one cross-reference at a time instead of in a single irreversible rewrite.
##
## RESOLUTION IS LAYER-SCOPED. The caller says which layer the reference must land in, so a key
## that names the wrong KIND of record is reported rather than quietly yielding a real id from
## somewhere else -- which would compile a valid-looking floor that does the wrong thing.
static func _resolve(layout: AuthoredLayout, layer: StringName, key: StringName, fallback: int) -> int:
	if key == &"":
		return fallback
	if layer == &"none":
		push_error("LayoutCompiler: '%s' is referenced by key, but its reference has no target layer" % key)
		return -1
	return layout.id_in(layer, key)
