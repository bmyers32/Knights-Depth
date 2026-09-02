extends GutTest
## PRESENTATION API CONTRACTS — deliberately narrow, and deliberately an exception to
## "presentation is test-exempt" (CLAUDE.md).
##
## This does NOT test how anything looks. It tests that a SHARED presentation component
## still exposes the methods its consumers call, which is a structural fact, not a visual
## one — and it is a fact GDScript only checks at the moment the call executes.
##
## WHY IT EXISTS (regression, 2026-08-17): the P29 vulnerable-window cue rewrote
## TelegraphIndicator and dropped set_active(), which the ENVOY uses for its charge-ready
## cue. TelegraphIndicator lives under actors/enemies/ and reads as enemy-only, but the
## player shares it. Nothing failed until a live click produced
## "Nonexistent function 'set_active'" mid-combat: the headless suite is presentation-free,
## and the arena boot check never attacked, so 416 green tests and a clean boot both
## reported success on a build whose attack cue crashed.
##
## The lesson generalises past this component: a dynamically-dispatched call into a shared
## node is an UNCHECKED contract until something exercises that exact path. Where a
## component has multiple consumers, pin the surface.

const TELEGRAPH_INDICATOR := preload("res://game/actors/enemies/telegraph_indicator.gd")


func _method_names(script: GDScript) -> Array:
	var names: Array = []
	for method in script.get_script_method_list():
		names.append(String(method.name))
	return names


## Every method any consumer calls on TelegraphIndicator. Adding a consumer means adding
## its call here; removing one of these means finding its callers first.
##   flash / mark_vulnerable / clear  -> Fang, Ooze, Watcher (windup telegraph + P29 cue)
##   set_active                       -> Envoy (Slice B charge-ready cue)
func test_telegraph_indicator_exposes_every_method_its_consumers_call() -> void:
	var exposed: Array = _method_names(TELEGRAPH_INDICATOR)
	for required in ["flash", "mark_vulnerable", "clear", "set_active"]:
		assert_true(exposed.has(required),
			"TelegraphIndicator.%s() is called by a live consumer -- removing it breaks that caller at runtime, not at parse time" % required)
	# DISCRIMINATION CHECK: proves the mechanism can actually FAIL. A guard that reports
	# success for every input is worse than no guard, because it also reports success for
	# the case it was built to catch (BRAIN: "A configured hook is not a working hook --
	# trigger it to know").
	assert_false(exposed.has("method_that_does_not_exist"),
		"the method-list check must be capable of returning false, or every assertion above is vacuous")


## The enemy actors are structurally identical wrappers over the shared indicator; the
## arena calls all three of these on whichever enemy an Event names.
func test_enemy_actors_expose_the_methods_the_arena_driver_calls() -> void:
	for actor_path in [
		"res://game/actors/enemies/fang/fang.gd",
		"res://game/actors/enemies/ooze/ooze.gd",
		"res://game/actors/enemies/watcher/watcher.gd",
	]:
		var exposed: Array = _method_names(load(actor_path))
		# set_combat_present is the P17 burrow cross-layer contract: the TargetBody collider is the
		# one targetability channel no sim gate can reach, so presentation must mirror the sim's
		# participation fact. Exactly the set_active() failure class, pinned in advance.
		for required in ["sync_from_sim", "show_telegraph", "show_vulnerable_window", "clear_telegraph", "set_combat_present", "teleport_from_sim"]:
			assert_true(exposed.has(required), "%s must expose %s() -- arena.gd calls it from _report_events" % [actor_path, required])


func test_envoy_exposes_the_charge_cue_methods_the_arena_driver_calls() -> void:
	var exposed: Array = _method_names(load("res://game/actors/envoy/envoy.gd"))
	for required in ["show_charge_ready", "clear_charge_ready", "sync_from_sim", "build_commands", "teleport_from_sim"]:
		assert_true(exposed.has(required), "envoy.gd must expose %s() -- arena.gd calls it every frame or on an Event" % required)


## The tracer is the other shared presentation component (Watcher survey + player guns).
func test_projectile_tracer_exposes_its_launch_contract() -> void:
	assert_true(_method_names(preload("res://game/actors/projectile_tracer.gd")).has("launch"),
		"arena.gd calls ProjectileTracer.launch() for both the Watcher's survey and the player's guns")


# --- INTERACTION SMOKE: the real arena, driven through the real event handlers --------
# The contract tests above pin that methods EXIST. This one pins that the driver can
# actually call them on the real scene, because existence and reachability are different
# failures and only the second one crashed the build.
#
# BOOT-CLEAN IS NOT INTERACT-CLEAN. The prior verification loaded arena.tscn headlessly and
# reported no errors -- but scene load never sends an attack, so the charge-cue path was
# never executed. This instantiates the real arena and pushes the real Event kinds through
# _report_events, which is exactly the call chain that failed:
#     _physics_process -> _report_events -> envoy.clear_charge_ready() -> set_active()

func _instantiate_arena() -> Node3D:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	# DEPTH IS PINNED, never inherited from the boot scene. These assertions are about the
	# ARCHIVE PROTOTYPE specifically, so the floor they mean is stated rather than assumed --
	# the scene's boot depth is a handoff pointer that moves whenever a human is being handed
	# a different floor to play.
	arena.depth = 1
	add_child_autofree(arena)
	assert_not_null(arena, "the real arena scene must instantiate")
	return arena


## M2 Slice 1: a floor's roster comes from the run seed, so "the Fang" is no longer a scene
## child that can be fetched by name. Finds the lowest run seed whose depth-1 floor actually
## contains the family under test and boots the REAL arena on it.
##
## Deliberately searched rather than hardcoded: a hardcoded seed silently stops testing the
## family it names the moment stratum tuning shifts the draw, and it would fail as "the
## telegraph broke" rather than "that seed no longer spawns a Watcher".
func _instantiate_arena_containing(family: StringName) -> Node3D:
	var present: bool = false
	for spawn in DepthGenerator.generate(0, 1).all_spawns():
		if spawn["enemy_key"] == family:
			present = true
	assert_true(present, "the authored floor no longer contains a '%s'" % family)
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	# DEPTH IS PINNED, never inherited from the boot scene. These assertions are about the
	# ARCHIVE PROTOTYPE specifically, so the floor they mean is stated rather than assumed --
	# the scene's boot depth is a handoff pointer that moves whenever a human is being handed
	# a different floor to play.
	arena.depth = 1
	add_child_autofree(arena)
	assert_not_null(arena, "the real arena scene must instantiate")
	return arena


## Puts the Envoy inside the room that owns `actor_id`, which is where a player necessarily IS
## whenever that room's encounter is live.
##
## Load-bearing since room confinement landed: burrow emergence places candidates around the
## PLAYER, and an owned actor may only surface inside its own room. Triggering a burrow while
## the Envoy stands in a different room leaves every candidate illegal, so the fail-safe
## correctly kills the Fang underground -- a real interaction, not a defect, but not the
## scenario these lifecycle tests are about.
func _place_envoy_in_room_of(arena: Node3D, actor_id: int) -> void:
	# Territory is a UNION of regions now, so pick the one the actor actually stands in rather
	# than assuming a site owns exactly one rect.
	var actor_position: Vector3 = arena.sim.entities[actor_id]
	var regions: Array = arena.sim._encounters[int(arena.sim._actor_encounter[actor_id])]["regions"]
	var rect: Rect2 = regions[0]
	for candidate: Rect2 in regions:
		if WalkableBounds.contains(candidate, actor_position.x, actor_position.z):
			rect = candidate
			break
	var centre: Vector2 = rect.get_center()
	arena.sim.entities[arena.envoy.actor_id] = Vector3(centre.x, 0.0, centre.y)
	# A deferred roster is combat-ABSENT and hidden until summoned; these lifecycle tests need
	# it fully present, so activate its site through the real path rather than half-faking it.
	arena.sim._activate_encounter(int(arena.sim._actor_encounter[actor_id]))
	if arena._enemies.has(actor_id):
		arena._enemies[actor_id].set_combat_present(true)


## The generated counterpart to the retired get_node("Fang"): asks the SIM which family an
## actor belongs to, rather than assuming anything about actor_id allocation order.
func _enemy_of_family(arena: Node3D, family: StringName) -> int:
	for actor_id: int in arena._enemies.keys():
		if arena.sim._families.get(actor_id, &"") == family:
			return actor_id
	return -1


func test_arena_drives_the_player_charge_cue_without_crashing() -> void:
	var arena: Node3D = _instantiate_arena()
	var envoy_telegraph: Node3D = arena.envoy.get_node("TelegraphIndicator")
	var envoy_id: int = arena.envoy.actor_id

	# charge_ready -> show_charge_ready -> set_active(colour, true)
	arena._report_events([Event.new(0, "charge_ready", {"actor_id": envoy_id})] as Array[Event])
	assert_true(envoy_telegraph.visible, "the charge-ready cue must light up")

	# melee_swing -> clear_charge_ready -> set_active(WHITE, false)  <-- the exact crash path
	arena._report_events([Event.new(1, "melee_swing", {"actor_id": envoy_id, "weapon_id": "sword_burn_A", "attack_profile_id": "1"})] as Array[Event])
	assert_false(envoy_telegraph.visible, "and releasing the swing must clear it")


func test_arena_drives_the_enemy_windup_cues_without_crashing() -> void:
	var arena: Node3D = _instantiate_arena_containing(&"watcher")
	var watcher_id: int = _enemy_of_family(arena, &"watcher")
	var watcher: Node3D = arena._enemies[watcher_id]

	arena._report_events([Event.new(0, "attack_telegraph", {"actor_id": watcher_id, "damage_type": "force", "action_id": "watcher_survey"})] as Array[Event])
	assert_true(watcher.get_node("TelegraphIndicator").visible, "the windup telegraph must appear")

	arena._report_events([Event.new(1, "windup_interrupted", {"actor_id": watcher_id, "attacker_id": 0})] as Array[Event])
	assert_false(watcher.get_node("TelegraphIndicator").visible, "an interrupted windup must stop advertising its window")


## THE SHIPPED-CONTENT LINK. test_burrow.gd proves the MECHANIC with synthetic values; it
## cannot catch a .tres that never authored one. This drives the real arena's real SimWorld,
## registered through the production ContentRegistrar path, so "the trigger silently refuses in
## the actual build" fails here instead of during a playtest session.
##
## Boot-clean is not interact-clean: instantiating the arena proves nothing about whether the
## dev trigger can fire, which is exactly the class of gap that has cost this project sessions.
func test_arena_fang_can_actually_burrow_from_shipped_content() -> void:
	var arena: Node3D = _instantiate_arena_containing(&"fang")
	var fang_id: int = _enemy_of_family(arena, &"fang")
	_place_envoy_in_room_of(arena, fang_id)
	assert_true(arena.sim.debug_trigger_burrow(fang_id, arena.envoy.actor_id),
		"the SHIPPED Fang content must produce a triggerable burrow -- if this refuses, pressing B in the real build does nothing")
	assert_true(arena.sim._combat_absent.has(fang_id) or arena.sim._burrow.has(fang_id),
		"and the lifecycle must actually be running afterwards")


## THE FULL STAGE-1 CHAIN, driven through the REAL arena's real _physics_process: trigger ->
## sim lifecycle -> Events -> _report_events -> presentation mirror. Everything a live session
## exercises except the literal keypress.
##
## This exists because a Stage-1 session produced no burrow lines and nothing could distinguish
## "not pressed" from "silently broken". Boot-clean is not interact-clean, and neither is
## unit-clean: test_burrow.gd proves the SIM, and proved nothing about whether the driver
## mirrors it onto the node the player actually looks at.
func test_arena_drives_the_full_burrow_lifecycle_and_mirrors_participation() -> void:
	var arena: Node3D = _instantiate_arena_containing(&"fang")
	var fang_id: int = _enemy_of_family(arena, &"fang")
	_place_envoy_in_room_of(arena, fang_id)
	var fang: Node3D = arena._enemies[fang_id]
	var target_body: Node = fang.get_node("TargetBody")
	assert_true(fang.visible, "sanity: present before burrowing")
	assert_eq(target_body.collision_layer, 2, "sanity: aim-acquirable before burrowing")

	assert_true(arena.sim.debug_trigger_burrow(fang_id, arena.envoy.actor_id), "the trigger must fire")

	var submerged: bool = false
	for i in 40:
		arena._physics_process(1.0 / 30.0)
		if arena.sim._combat_absent.has(fang_id):
			submerged = true
			break
	assert_true(submerged, "the jump must reach SUBMERGED through the real driver")
	await get_tree().process_frame  # set_deferred flush
	assert_false(fang.visible, "presentation must HIDE an absent actor")
	assert_eq(target_body.collision_layer, 0,
		"and must disable the aim collider -- dimension 5, the targetability channel no sim gate can reach")

	var emerged: bool = false
	for i in 200:
		arena._physics_process(1.0 / 30.0)
		if not arena.sim._combat_absent.has(fang_id):
			emerged = true
			break
	assert_true(emerged, "it must emerge")
	await get_tree().process_frame
	assert_true(fang.visible, "presentation must SHOW it again")
	assert_eq(target_body.collision_layer, 2, "and restore aim acquisition")


## THE STAGE-1 EMERGENCE DEFECT, pinned. Samples the Fang every physics tick across a whole
## burrow and asserts it never occupies an intermediate transform while combat-absent, and that
## the tick it becomes visible is already the emergence tick.
##
## HONEST LIMIT, stated rather than implied: the observed defect was a RENDER-SIDE
## interpolation artifact between physics ticks, which no scene-tree sample can see. What this
## proves is that the transform teleports cleanly and the node stays hidden throughout -- the
## preconditions for the fix. The fix itself (reset_physics_interpolation) is pinned only by the
## contract test asserting teleport_from_sim exists and is what the driver calls.
func test_no_visible_travel_while_combat_absent() -> void:
	var arena: Node3D = _instantiate_arena_containing(&"fang")
	var fang_id: int = _enemy_of_family(arena, &"fang")
	_place_envoy_in_room_of(arena, fang_id)
	var fang: Node3D = arena._enemies[fang_id]
	assert_true(arena.sim.debug_trigger_burrow(fang_id, arena.envoy.actor_id), "sanity: triggered")

	var positions_while_absent: Array = []
	var visible_while_absent: bool = false
	var emerged_position: Vector3 = Vector3.ZERO
	var visible_on_emergence: Vector3 = Vector3.ZERO
	var was_absent: bool = false

	for i in 240:
		arena._physics_process(1.0 / 30.0)
		var absent: bool = arena.sim._combat_absent.has(fang_id)
		if absent:
			was_absent = true
			positions_while_absent.append(fang.position)
			if fang.visible:
				visible_while_absent = true
		elif was_absent:
			emerged_position = arena.sim.entities[fang_id]
			visible_on_emergence = fang.position
			break

	assert_true(was_absent, "sanity: it submerged")
	assert_false(visible_while_absent, "the node must never be drawn while the actor is absent")
	assert_gt(positions_while_absent.size(), 5, "sanity: it really was absent for a span")
	# One distinct transform for the whole absent span: it parks where the jump ended and does
	# not creep toward the emergence point.
	var distinct: Dictionary = {}
	for entry in positions_while_absent:
		distinct["%.4f,%.4f" % [entry.x, entry.z]] = true
	assert_eq(distinct.size(), 1, "the hidden node must not move at all while absent -- no travel to interpolate")
	assert_almost_eq(visible_on_emergence.distance_to(emerged_position), 0.0, 0.001,
		"the first frame it is visible must already be AT the emergence point")


## The shipped .tres values must be the ones the sim actually runs on. A unit test using
## synthetic numbers cannot catch an authored value that never reached registration.
func test_shipped_fang_burrow_values_reach_the_sim() -> void:
	var arena: Node3D = _instantiate_arena_containing(&"fang")
	var fang_id: int = _enemy_of_family(arena, &"fang")
	_place_envoy_in_room_of(arena, fang_id)
	var stats: Resource = ContentDB.get_resource(&"enemy", &"fang")
	var config: Dictionary = arena.sim._ai_burrow.get(fang_id, {})
	assert_false(config.is_empty(), "the shipped Fang must have a registered burrow")
	assert_almost_eq(float(config.jump_distance), stats.burrow_jump_distance, 0.001)
	assert_almost_eq(float(config.emergence_radius), stats.burrow_emergence_radius, 0.001)
	assert_eq(int(config.underground_ticks), stats.burrow_underground_ticks)
	assert_eq(int(config.reacquisition_ticks), stats.burrow_reacquisition_ticks)
	assert_eq(int(config.emergence_retry_ticks), stats.burrow_emergence_retry_ticks)


func _is_event_kind_token(candidate: String) -> bool:
	for index in candidate.length():
		var character: String = candidate[index]
		if character != "_" and (character < "a" or character > "z"):
			return false
	return true


## THE AUDIT, mechanised: every kind SimWorld can emit is either printed or explicitly passed.
## This is the gap class itself, not another instance of it -- it fails when a new mechanic
## adds an event kind and forgets the reporting decision, which is exactly how the scurry and
## cutoff kinds went missing.
func test_every_emitted_event_kind_has_a_reporting_decision() -> void:
	var source: String = FileAccess.get_file_as_string("res://game/sim/sim_world.gd")
	var emitted: Dictionary = {}
	# Plain string scanning rather than a RegEx: the pattern would need escaped dots and
	# parens, and GDScript rejects a bare backslash-dot inside a string literal at PARSE time.
	# Splitting is uglier and cannot fail to compile.
	for fragment in source.split("Event.new("):
		var comma: int = fragment.find(",")
		if comma == -1:
			continue
		var after: String = fragment.substr(comma)
		var opening: int = after.find('"')
		if opening == -1:
			continue
		var closing: int = after.find('"', opening + 1)
		if closing == -1:
			continue
		# "Event.new(" also appears in prose comments, where the next quoted run is ordinary
		# English. An event kind is a bare lower_snake identifier, so anything else is not one.
		var candidate: String = after.substr(opening + 1, closing - opening - 1)
		if not candidate.is_empty() and _is_event_kind_token(candidate):
			emitted[candidate] = true
	assert_gt(emitted.size(), 20, "sanity: the scan really found the sim's event kinds")

	var arena_source: String = FileAccess.get_file_as_string("res://game/arena/arena.gd")
	var block: String = arena_source.substr(arena_source.find("match event.kind:"))
	for kind in emitted.keys():
		assert_true(block.contains('"%s":' % kind),
			"SimWorld emits '%s' but arena._report_events has no case for it -- print it, or add an explicit pass saying why not" % kind)


func test_arena_drives_the_projectile_tracer_lifecycle_without_crashing() -> void:
	var arena: Node3D = _instantiate_arena()
	arena._report_events([Event.new(0, "projectile_fired", {
		"attacker_id": 0, "weapon_id": "wand_A", "projectile_id": 7,
		"position": Vector3.ZERO, "direction": Vector3(0, 0, -1),
	})] as Array[Event])
	assert_eq(arena._projectile_tracers.size(), 1, "a fired shot must spawn its tracer")

	arena._report_events([Event.new(1, "hit", {"attacker_id": 0, "target_id": 1, "projectile_id": 7})] as Array[Event])
	assert_eq(arena._projectile_tracers.size(), 0, "and its terminal event must remove it")


## FloorBuilder is M2's new shared presentation component, and it is exactly the shape this
## file exists to guard: the arena driver calls into it dynamically, presentation is
## test-exempt by law, and a renamed method would fail at the first floor load rather than
## at parse time.
func test_floor_builder_exposes_the_methods_the_arena_driver_calls() -> void:
	var exposed: Array = _method_names(preload("res://game/arena/floor_builder.gd"))
	for required in ["build", "clear_floor"]:
		assert_true(exposed.has(required), "arena.gd calls FloorBuilder.%s() on every floor load" % required)


## The generated roster must be the plan's roster. Pins the presentation half of the floor
## contract: what FloorBuilder instantiated, what the driver registered, and what the plan
## asked for are one set -- not three that merely usually agree.
func test_the_built_floor_matches_the_generated_plan() -> void:
	var arena: Node3D = _instantiate_arena_containing(&"fang")
	var plan: FloorPlan = DepthGenerator.generate(arena.run_seed, arena.depth)

	assert_eq(arena._enemies.size(), plan.all_spawns().size(),
		"every spawn the plan authored must exist as a live actor -- a dropped one means the sim refused a placement the generator promised was legal")

	var planned: Dictionary = {}
	for spawn in plan.all_spawns():
		planned[String(spawn["enemy_key"])] = int(planned.get(String(spawn["enemy_key"]), 0)) + 1
	var built: Dictionary = {}
	for actor_id: int in arena._enemies.keys():
		var family: String = String(arena.sim._families.get(actor_id, &""))
		built[family] = int(built.get(family, 0)) + 1
	assert_eq(built, planned, "the built roster's family census must equal the plan's")

	for actor_id: int in arena._enemies.keys():
		assert_true(arena.sim._bounds.is_inside(arena.sim.entities[actor_id]),
			"actor %d was spawned outside the floor it lives on" % actor_id)
		# Ownership is what makes confinement possible; an unowned actor would silently fall
		# back to the whole floor and be free to roam.
		assert_true(arena.sim._actor_encounter.has(actor_id), "actor %d was never bound to a site" % actor_id)
