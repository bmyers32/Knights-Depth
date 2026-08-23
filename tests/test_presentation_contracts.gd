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
		for required in ["sync_from_sim", "show_telegraph", "show_vulnerable_window", "clear_telegraph", "set_combat_present"]:
			assert_true(exposed.has(required), "%s must expose %s() -- arena.gd calls it from _report_events" % [actor_path, required])


func test_envoy_exposes_the_charge_cue_methods_the_arena_driver_calls() -> void:
	var exposed: Array = _method_names(load("res://game/actors/envoy/envoy.gd"))
	for required in ["show_charge_ready", "clear_charge_ready", "sync_from_sim", "build_commands"]:
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
	var arena: Node3D = add_child_autofree(load("res://game/arena/arena.tscn").instantiate())
	assert_not_null(arena, "the real arena scene must instantiate")
	return arena


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
	var arena: Node3D = _instantiate_arena()
	var watcher_id: int = arena.get_node("Watcher").actor_id

	arena._report_events([Event.new(0, "attack_telegraph", {"actor_id": watcher_id, "damage_type": "force", "action_id": "watcher_survey"})] as Array[Event])
	assert_true(arena.get_node("Watcher").get_node("TelegraphIndicator").visible, "the windup telegraph must appear")

	arena._report_events([Event.new(1, "windup_interrupted", {"actor_id": watcher_id, "attacker_id": 0})] as Array[Event])
	assert_false(arena.get_node("Watcher").get_node("TelegraphIndicator").visible, "an interrupted windup must stop advertising its window")


## THE SHIPPED-CONTENT LINK. test_burrow.gd proves the MECHANIC with synthetic values; it
## cannot catch a .tres that never authored one. This drives the real arena's real SimWorld,
## registered through the production ContentRegistrar path, so "the trigger silently refuses in
## the actual build" fails here instead of during a playtest session.
##
## Boot-clean is not interact-clean: instantiating the arena proves nothing about whether the
## dev trigger can fire, which is exactly the class of gap that has cost this project sessions.
func test_arena_fang_can_actually_burrow_from_shipped_content() -> void:
	var arena: Node3D = _instantiate_arena()
	var fang_id: int = arena.get_node("Fang").actor_id
	assert_true(arena.sim.debug_trigger_burrow(fang_id, arena.envoy.actor_id),
		"the SHIPPED Fang content must produce a triggerable burrow -- if this refuses, pressing B in the real build does nothing")
	assert_true(arena.sim._combat_absent.has(fang_id) or arena.sim._burrow.has(fang_id),
		"and the lifecycle must actually be running afterwards")


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
