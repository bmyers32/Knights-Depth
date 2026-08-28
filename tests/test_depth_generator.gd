extends GutTest
## The authored prototype floor, checked as DATA: determinism, connectivity, and the grammar
## requirements the slice was specified against.
##
## SEED HONESTY IS ASSERTED HERE, not merely documented: while the layout is authored, two
## different seeds must produce the same geometry. If that assertion ever flips to "different",
## it means procedural assembly returned and the honesty notice must come off the HUD with it.

const _DEPTH: int = 1


func _plan(seed_value: int = 0) -> FloorPlan:
	return DepthGenerator.generate(seed_value, _DEPTH)


# --- DETERMINISM AND HONESTY ----------------------------------------------------------

func test_same_seed_and_depth_produce_an_identical_plan() -> void:
	for seed_value in [0, 1, 7, 12345, -99]:
		assert_eq(_plan(seed_value).to_dict(), _plan(seed_value).to_dict(),
			"seed %d must regenerate identically" % seed_value)


func test_generation_is_independent_of_call_order() -> void:
	var baseline: Dictionary = _plan(42).to_dict()
	for noise_seed in [1, 2, 3, 4, 5]:
		DepthGenerator.generate(noise_seed, _DEPTH + noise_seed)
	assert_eq(_plan(42).to_dict(), baseline, "generating other floors first must not change this one")


## THE HONESTY CLAIM, executable. The prototype layout is hand-authored, so seeds do NOT vary
## geometry -- and the plan says so, which is what lets the HUD tell the truth.
func test_the_authored_layout_is_the_same_floor_for_every_seed() -> void:
	var first: FloorPlan = _plan(0)
	var second: FloorPlan = _plan(999)
	assert_true(first.authored_layout, "the plan must declare itself authored")
	assert_eq(first.patch_rects(), second.patch_rects(),
		"while the layout is authored, seeds must not change geometry -- if this fails, procedural assembly returned and the HUD notice must change with it")
	assert_ne(first.run_seed, second.run_seed, "the seed is still recorded as reproduction metadata")


## The procedural path is switched off, not rotted: its seed derivation stays live and tested.
func test_floor_seed_derivation_still_separates_depths() -> void:
	assert_ne(DepthGenerator.derive_floor_seed(2026, 1), DepthGenerator.derive_floor_seed(2026, 2))
	assert_eq(DepthGenerator.derive_floor_seed(2026, 3), DepthGenerator.derive_floor_seed(2026, 3))


# --- SPATIAL ---------------------------------------------------------------------------

func test_the_floor_is_a_connected_union_of_patches() -> void:
	var plan: FloorPlan = _plan()
	assert_gt(plan.patches.size(), 4, "an exploration floor is more than a handful of boxes")
	var bounds: WalkableBounds = plan.make_bounds()
	assert_true(bounds.is_inside(plan.entry_point), "the Envoy would arrive out of bounds")
	# The endpoint is legal ground even though the route to it starts closed.
	var everything := WalkableBounds.new(plan.all_rects())
	assert_true(everything.is_inside(plan.end_marker), "the terminal marker must stand on real ground")


## IRREGULARITY, asserted rather than assumed: the floor must not be a stack of same-sized
## boxes, and it must enclose at least one VOID -- ground you can see across but not walk on.
func test_the_floor_has_an_irregular_silhouette_and_a_void() -> void:
	var plan: FloorPlan = _plan()
	var widths: Dictionary = {}
	for patch in plan.patches:
		widths[patch.rect.size.x] = true
	assert_gt(widths.size(), 3, "patches of many different widths are what makes a silhouette irregular")

	# The hall ring: its centre is enclosed by walkable ground on every side but is not itself
	# walkable. A chain of boxes cannot produce this.
	var everything := WalkableBounds.new(plan.all_rects())
	var hole := Vector3(0.0, 0.0, -22.0)
	assert_false(everything.is_inside(hole), "the hall must wrap a genuine void at %s" % hole)
	for probe in [Vector3(-12.0, 0.0, -22.0), Vector3(12.0, 0.0, -22.0), Vector3(0.0, 0.0, -14.0), Vector3(0.0, 0.0, -31.0)]:
		assert_true(everything.is_inside(probe), "ground must wrap the void at %s" % probe)


func test_the_floor_offers_both_a_wide_area_and_a_narrow_path() -> void:
	var plan: FloorPlan = _plan()
	var widest: float = 0.0
	var narrowest: float = INF
	for patch in plan.patches:
		widest = maxf(widest, patch.rect.size.x)
		narrowest = minf(narrowest, patch.rect.size.x)
	assert_gt(widest, 24.0, "an open traversal/arena space")
	assert_lt(narrowest, 12.0, "and a narrower path -- uniform corridors read as one corridor")


func test_elevation_change_exists_and_is_presentation_only() -> void:
	var elevations: Dictionary = {}
	for patch in _plan().patches:
		elevations[patch.elevation] = true
	assert_gt(elevations.size(), 1, "at least one ramp/raised-ground transition")
	# The sim's own view of the floor carries no height at all: patch_rects is XZ only.
	for rect in _plan().patch_rects():
		assert_true(rect is Rect2, "the spatial layer the sim consumes is flat by construction")


# --- PROGRESSION -----------------------------------------------------------------------

func test_every_aperture_overlaps_both_patches_it_joins() -> void:
	var plan: FloorPlan = _plan()
	for connection in plan.connections:
		for patch_id in [connection.patch_ids.x, connection.patch_ids.y]:
			var patch: WalkablePatch = plan.patch_by_id(patch_id)
			assert_gt(connection.aperture.intersection(patch.rect).get_area(), 0.0,
				"aperture %d only abuts patch %d -- a zero-area junction makes the threshold a discontinuity" % [connection.connection_id, patch_id])


## A route the player can SEE before they can USE it is the core of the grammar. At least one
## connection must start closed while the ground beyond it already exists.
func test_at_least_one_route_is_visible_before_it_is_reachable() -> void:
	var plan: FloorPlan = _plan()
	var blocked: Array = []
	for connection in plan.connections:
		if not connection.starts_open:
			blocked.append(connection)
	assert_gt(blocked.size(), 0, "a floor with everything already open has nothing to discover")
	var everything := WalkableBounds.new(plan.all_rects())
	for connection in blocked:
		var beyond: WalkablePatch = plan.patch_by_id(connection.patch_ids.y)
		assert_true(everything.is_inside(beyond.centre()),
			"the ground past connection %d must already exist to be seen" % connection.connection_id)


## The blocker's answer must be SOMEWHERE ELSE. Asserted structurally: the trigger that opens
## the first blocked route is fired by an interactable, and that interactable is concealed by a
## breakable -- so the route cannot open by walking at it.
func test_a_blocked_route_is_opened_by_something_found_elsewhere() -> void:
	var plan: FloorPlan = _plan()
	var opener: FloorTrigger = null
	for trigger in plan.triggers:
		for effect in trigger.effects:
			if effect["kind"] == FloorLayers.EFFECT_OPEN_CONNECTION and effect["target_id"] == ArchivePrototypeLayout.C_TO_APPROACH:
				opener = trigger
	assert_not_null(opener, "something must open the forward route")
	assert_eq(opener.kind, FloorLayers.TRIGGER_INTERACTED, "and it must be an act, not arrival")

	var hidden: InteractablePlan = null
	for interactable in plan.interactables:
		if interactable.interactable_id == opener.source_id:
			hidden = interactable
	assert_not_null(hidden)
	assert_true(hidden.starts_hidden, "the opener must be concealed -- otherwise there is nothing to discover")
	var concealed_by: Array = []
	for breakable in plan.breakables:
		if breakable.conceals_interactable_id == hidden.interactable_id:
			concealed_by.append(breakable)
	assert_eq(concealed_by.size(), 1, "exactly one breakable must conceal it")


func test_a_one_way_commitment_exists() -> void:
	var plan: FloorPlan = _plan()
	var commitment: FloorTrigger = null
	for trigger in plan.triggers:
		if trigger.kind != FloorLayers.TRIGGER_REGION:
			continue
		for effect in trigger.effects:
			if effect["kind"] == FloorLayers.EFFECT_BLOCK_CONNECTION:
				commitment = trigger
	assert_not_null(commitment, "the floor must commit the player forward at least once")
	assert_true(commitment.once, "a commitment that can re-fire is not a commitment")
	assert_gt(commitment.region.get_area(), 0.0, "a region trigger needs a region")


## THE OWNERSHIP LAW, structurally: one interactable causes the whole party-button sequence.
func test_the_party_button_owns_its_whole_consequence_in_one_record() -> void:
	var plan: FloorPlan = _plan()
	var button: FloorTrigger = null
	for trigger in plan.triggers:
		if trigger.kind == FloorLayers.TRIGGER_INTERACTED and trigger.source_id == ArchivePrototypeLayout.I_PARTY_BUTTON:
			button = trigger
	assert_not_null(button, "the party button must have a trigger")
	var kinds: Array = []
	for effect in button.effects:
		kinds.append(effect["kind"])
	assert_true(kinds.has(FloorLayers.EFFECT_BLOCK_CONNECTION), "it seals the rear route")
	assert_true(kinds.has(FloorLayers.EFFECT_OPEN_CONNECTION), "it opens the way forward")
	assert_true(kinds.has(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER), "and it starts the fight")
	assert_eq(button.effects.size(), 3, "all of it in ONE authored record, not spread across systems")


func test_progression_continues_after_the_encounter_clears() -> void:
	var plan: FloorPlan = _plan()
	var found: bool = false
	for trigger in plan.triggers:
		if trigger.kind != FloorLayers.TRIGGER_ENCOUNTER_CLEARED:
			continue
		for effect in trigger.effects:
			if effect["kind"] == FloorLayers.EFFECT_OPEN_CONNECTION:
				found = true
	assert_true(found, "clearing the fight must open the way onward, or the floor dead-ends")


## Every effect must name something that exists. A dangling target would be a silent no-op --
## a door that never opens with no error to explain it.
func test_every_effect_targets_something_real() -> void:
	var plan: FloorPlan = _plan()
	var connection_ids: Dictionary = {}
	for connection in plan.connections:
		connection_ids[connection.connection_id] = true
	var encounter_ids: Dictionary = {}
	for encounter in plan.encounters:
		encounter_ids[encounter.encounter_id] = true
	var interactable_ids: Dictionary = {}
	for interactable in plan.interactables:
		interactable_ids[interactable.interactable_id] = true

	for trigger in plan.triggers:
		for effect in trigger.effects:
			var target: int = effect["target_id"]
			match String(effect["kind"]):
				"open_connection", "block_connection":
					assert_true(connection_ids.has(target), "trigger %d targets missing connection %d" % [trigger.trigger_id, target])
				"activate_encounter":
					assert_true(encounter_ids.has(target), "trigger %d targets missing encounter %d" % [trigger.trigger_id, target])
				"reveal_interactable":
					assert_true(interactable_ids.has(target), "trigger %d targets missing interactable %d" % [trigger.trigger_id, target])
				_:
					fail_test("trigger %d uses unknown effect kind '%s'" % [trigger.trigger_id, effect["kind"]])


# --- ENCOUNTER -------------------------------------------------------------------------

func test_the_floor_has_both_a_triggered_encounter_and_an_ambient_one() -> void:
	var plan: FloorPlan = _plan()
	var mandatory: Array[EncounterSite] = plan.encounters_of_role(FloorLayers.ROLE_MANDATORY)
	var ambient: Array[EncounterSite] = plan.encounters_of_role(FloorLayers.ROLE_AMBIENT)
	assert_eq(mandatory.size(), 1, "one authored lock-in fight")
	assert_eq(ambient.size(), 1, "and one territory that simply has enemies in it")
	assert_true(mandatory[0].confines_player, "a mandatory encounter seals")
	assert_false(ambient[0].confines_player, "an ambient one never does")
	assert_false(mandatory[0].spawn_at_floor_load, "its roster ARRIVES when summoned")
	assert_true(ambient[0].spawn_at_floor_load, "ambient enemies are simply there")


## NO ENCOUNTER MAY ACTIVATE BY GEOMETRY. This is the falsified rule made unrepresentable: no
## region trigger anywhere may carry an activation effect unless it was authored deliberately,
## and this floor authors none -- every fight starts from an act.
func test_no_encounter_activates_merely_because_a_region_was_entered() -> void:
	for trigger in _plan().triggers:
		if trigger.kind != FloorLayers.TRIGGER_REGION:
			continue
		for effect in trigger.effects:
			assert_ne(effect["kind"], FloorLayers.EFFECT_ACTIVATE_ENCOUNTER,
				"trigger %d starts a fight by walking into a region -- exactly what the multi-room slice falsified" % trigger.trigger_id)


func test_every_spawn_stands_inside_the_site_that_owns_it() -> void:
	var plan: FloorPlan = _plan()
	var everything := WalkableBounds.new(plan.all_rects())
	var stratum: StratumConfig = ContentDB.get_resource(&"stratum", &"archive")
	for encounter in plan.encounters:
		for spawn in encounter.roster:
			var position: Vector3 = spawn["position"]
			assert_true(everything.is_inside(position), "spawn at %s is off the floor" % position)
			assert_true(encounter.region.has_point(Vector2(position.x, position.z)),
				"spawn at %s is outside encounter %d, which OWNS it" % [position, encounter.encounter_id])
			assert_true(stratum.enemy_keys.has(spawn["enemy_key"]),
				"'%s' is not in this stratum's declared family pool" % spawn["enemy_key"])


func test_the_mandatory_roster_does_not_ambush_its_own_doorway() -> void:
	var plan: FloorPlan = _plan()
	var arena: EncounterSite = plan.encounters_of_role(FloorLayers.ROLE_MANDATORY)[0]
	var entrance := Vector3(0.0, 0.0, plan.patch_by_id(ArchivePrototypeLayout.P_ARENA).rect.end.y)
	for spawn in arena.roster:
		assert_gt(spawn["position"].distance_to(entrance), 8.0,
			"a spawn on top of the entrance is not difficulty, it is an unfair opening")


# --- PERFORMANCE -------------------------------------------------------------------------

## GAME-RULES §5 M2 budget, kept live even while the layout is authored.
func test_floor_construction_stays_far_under_the_hundred_millisecond_gate() -> void:
	var started: int = Time.get_ticks_usec()
	for seed_value in 50:
		DepthGenerator.generate(seed_value, _DEPTH)
	var per_floor_ms: float = (Time.get_ticks_usec() - started) / 1000.0 / 50.0
	gut.p("floor construction: %.3f ms" % per_floor_ms)
	assert_lt(per_floor_ms, 100.0, "GAME-RULES §5 M2 budget is 100 ms per floor")
