extends GutTest
## THE GAME LOOP (M2 Slice 3): Title -> Home; Home, Commons and Ready Room one action apart; Ready
## Room pad -> Expedition -> summary -> Commons -- through the real GameMain, the real places and the
## real arena.
##
## Fades are advanced by hand (_settle) and every walk is bounded. Places are stepped through their
## own _step, never sim.tick, except where a test needs the raw Event batch of one press.

const DT := 1.0 / 30.0
const MAIN_SCENE := "res://game/main/main.tscn"
const ARENA_SCENE := "res://game/arena/arena.tscn"
## Generous: one fade-out + one fade-in completes in two steps of _settle's 1 s.
const SETTLE_STEPS := 10
const WALK_TICKS := 600
const HUB_PLACES: Array[StringName] = [GameMain.PLACE_HOME, GameMain.PLACE_COMMONS, GameMain.PLACE_READY_ROOM]


func after_each() -> void:
	Input.action_release("hub_travel")
	Input.action_release("restart")
	Input.action_release("move_forward")
	# Retired places are queue_free()d; let the frame land so they are not counted as orphans.
	await get_tree().process_frame


func _main() -> GameMain:
	var main: GameMain = load(MAIN_SCENE).instantiate()
	add_child_autofree(main)
	return main


## Runs whatever move is in progress to completion.
func _settle(main: GameMain) -> void:
	for i in SETTLE_STEPS:
		if not main.is_transitioning():
			return
		main._fade._process(1.0)
	assert_false(main.is_transitioning(), "the move finished within its bound")


## To any safe place, the way a player gets there: the title's button, then one hub travel action.
func _to(main: GameMain, destination: StringName) -> HubSpace:
	if main.place_id == GameMain.PLACE_TITLE:
		(main.place as TitleScreen).request_start()
		_settle(main)
	if main.place_id != destination:
		if main.place is HubSpace:
			(main.place as HubSpace).request_travel(destination)
		else:
			main.go_to(destination)  # from an arena: only tests take this shortcut
		_settle(main)
	assert_eq(main.place_id, destination)
	return main.place


func _to_home(main: GameMain) -> HubSpace:
	return _to(main, GameMain.PLACE_HOME)


func _to_commons(main: GameMain) -> HubSpace:
	return _to(main, GameMain.PLACE_COMMONS)


## Through a chosen safe hub, so deployment is exercised from either origin.
func _to_ready_room(main: GameMain, via: StringName = GameMain.PLACE_HOME) -> HubSpace:
	if main.place_id == GameMain.PLACE_READY_ROOM:
		return main.place
	_to(main, via)
	return _to(main, GameMain.PLACE_READY_ROOM)


func _button(hub: HubSpace, label: String) -> Button:
	for button in hub.travel_buttons():
		if button.text == label:
			return button
	fail_test("%s has no '%s' destination" % [hub.layout.layout_id, label])
	return null


func _labels(hub: HubSpace) -> Array:
	return hub.travel_buttons().map(func(button: Button) -> String: return button.text)


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _key(keycode: Key, echo: bool = false) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	key.echo = echo
	return key


func _move(hub: HubSpace, direction: Vector3) -> void:
	hub._step([Command.new(hub.sim.tick_count, hub.envoy.actor_id, "move", {"direction": direction})] as Array[Command], DT)


func _hub_position(hub: HubSpace) -> Vector3:
	return hub.sim.entities[hub.envoy.actor_id]


func _walk_to(hub: HubSpace, target: Vector3, reach: float = 0.2) -> bool:
	for i in WALK_TICKS:
		var to := target - _hub_position(hub)
		to.y = 0.0
		if to.length() <= reach:
			return true
		_move(hub, to.normalized())
	return false


func _press_at(hub: HubSpace, point: Vector3) -> Command:
	return Command.new(hub.sim.tick_count, hub.envoy.actor_id, "attack", {"aim": point - _hub_position(hub), "phase": "pressed"})


func _deploy(main: GameMain, via: StringName = GameMain.PLACE_HOME) -> Node3D:
	var ready_room: HubSpace = _to_ready_room(main, via)
	_walk_onto_pad(ready_room)
	assert_true(ready_room.is_leaving(), "the pad was reached")
	_finish_departure(ready_room)
	_settle(main)
	assert_eq(main.place_id, GameMain.PLACE_EXPEDITION)
	return main.place


## Plays the pad's departure transmission out, tick by tick, as the Ready Room's own step does.
func _finish_departure(ready_room: HubSpace) -> void:
	for i in ready_room.departure_ticks + 1:
		if not ready_room.is_departing():
			return
		ready_room._step([] as Array[Command], DT)
	assert_false(ready_room.is_departing(), "the departure ended within its bound")


## Up the west steps round the mission console, then onto the pad -- the way a player goes.
func _walk_onto_pad(ready_room: HubSpace) -> void:
	var layout: AuthoredLayout = ready_room.layout
	var step := Vector2.ZERO
	var staging := Vector2.ZERO
	for patch in ready_room.plan.patches:
		if patch.patch_id == layout.id_in(&"patch", &"P_STEP_W"):
			step = patch.rect.get_center()
		if patch.patch_id == layout.id_in(&"patch", &"P_FLOOR"):
			staging = patch.rect.get_center()
	_walk_to(ready_room, Vector3(step.x, 0, step.y))
	_walk_to(ready_room, Vector3(step.x, 0, staging.y))
	for i in WALK_TICKS:
		if ready_room.is_leaving():
			return
		_move(ready_room, (ready_room.plan.end_marker - _hub_position(ready_room)).normalized())


func _fall(arena: Node3D) -> void:
	var envoy_id: int = arena.envoy.actor_id
	arena.sim._iframe_ticks_remaining[envoy_id] = 0
	var lethal: Dictionary = {
		"damage": 1000.0, "damage_type": "force", "knockback_distance": 0.0,
		"contributes_pressure": false, "flinch_capability": "none", "interrupt_strength": 0,
	}
	arena._report_events(arena.sim._resolve_hit_on_target(-1, envoy_id, lethal, Vector3(0, 0, 1), "test_fall", "", -1, SimWorld.SOURCE_ENVIRONMENT))
	arena._resolve_transitions()


func _recall(arena: Node3D) -> void:
	_fall(arena)
	for i in arena.envoy.stats.resync_delay_ticks + 1:
		arena._step([] as Array[Command], DT)
	_fall(arena)
	assert_true(arena.expedition.is_recalled, "sanity: recovery exhausted")


func _extract(arena: Node3D) -> void:
	arena._report_events([Event.new(arena.sim.tick_count, "floor_complete", {})] as Array[Event])
	arena._resolve_transitions()
	assert_true(arena.expedition.is_complete, "sanity: extracted")


func _show_summary(arena: Node3D) -> void:
	arena._run_summary._process(arena._run_summary.intro_seconds + 0.01)


## A fresh expedition owes nothing to any before it.
func _assert_fresh(arena: Node3D) -> void:
	var envoy_id: int = arena.envoy.actor_id
	assert_false(arena.standalone, "deployed by the game loop")
	assert_eq(arena.expedition.run_seed, 0, "the Slice 3 seed, passed explicitly")
	assert_eq(arena.expedition.itinerary, [1, 2, 3, 4] as Array[int], "the arena's own authored itinerary")
	assert_eq(arena.expedition.current_depth(), 1)
	assert_eq(arena.expedition.phase, Expedition.PHASE_EXPLORING)
	assert_eq(arena.sim.tick_count, 0, "on a fresh clock")
	assert_eq(arena.sim.health_of(envoy_id), arena.envoy.stats.max_health, "at full health")
	assert_false(arena.sim.resync_pending(envoy_id), "no revival in flight")
	assert_eq(arena.sim._resyncs_used_on_floor.size(), 0, "the floor's revival unspent")
	assert_eq(arena.sim.carried_by(envoy_id), -1, "carrying nothing")
	assert_eq(arena.sim._projectiles.size(), 0, "nothing in flight")
	assert_eq(arena.sim._status_instances.size(), 0, "no status")
	assert_eq(arena.sim._equipped_weapon[envoy_id], arena.loadout_weapon_ids[0], "with the starting weapon")
	assert_eq(arena.damage_ledger.rows.size(), 0, "an empty ledger")
	assert_false(arena._run_summary.is_open(), "no outcome")
	assert_true(arena.envoy.visible)


# --- BOOT AND TITLE ------------------------------------------------------------------------

func test_the_game_boots_into_the_title_and_nothing_runs_behind_it() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), MAIN_SCENE, "the game launches GameMain")
	var main: GameMain = _main()
	assert_eq(main.place_id, GameMain.PLACE_TITLE)
	assert_true(main.place is TitleScreen)
	assert_eq(main.get_child_count(), 2, "the fade and the title, nothing else")
	assert_eq(main.deploy_count, 0)


func test_the_title_enters_home_once() -> void:
	var main: GameMain = _main()
	var title: TitleScreen = main.place
	title.request_start()
	title.request_start()
	assert_true(main.is_transitioning())
	_settle(main)
	assert_eq(main.place_id, GameMain.PLACE_HOME, "Home first, not the Commons")
	var home: HubSpace = main.place
	assert_eq(home.layout.layout_id, &"home")
	assert_eq(_hub_position(home), home.plan.entry_point, "arrives at Home's spawn")
	assert_eq(home.sim.entities.size(), 1, "the Envoy and nothing else")
	assert_eq(home.sim._weapons.size(), 0, "no weapons registered in a hub")
	assert_false(home.deploys)
	assert_false(is_instance_valid(title) and title.is_inside_tree(), "the title is gone")


# --- THE THREE SAFE PLACES -----------------------------------------------------------------

func test_every_hub_offers_exactly_the_other_two_by_name() -> void:
	var main: GameMain = _main()
	var expected: Dictionary = {
		GameMain.PLACE_HOME: ["Commons", "Ready Room"],
		GameMain.PLACE_COMMONS: ["Home", "Ready Room"],
		GameMain.PLACE_READY_ROOM: ["Home", "Commons"],
	}
	for place: StringName in HUB_PLACES:
		var hub: HubSpace = _to(main, place)
		assert_eq(_labels(hub), expected[place], "%s's destinations" % place)
		for button in hub.travel_buttons():
			assert_true(button.is_visible_in_tree(), "every destination is on screen")
			assert_eq(button.action_mode, BaseButton.ACTION_MODE_BUTTON_PRESS, "latches before the click can be read as an attack")
			assert_eq(button.focus_mode, Control.FOCUS_NONE, "never focusable until the keyboard asks")
		assert_false(hub.has_destination(place), "no way from a place to itself")


func test_every_safe_place_is_one_action_from_each_other_both_ways() -> void:
	var main: GameMain = _main()
	_to_home(main)
	# All six directed edges, each through the hub's own request, each arriving at the spawn.
	var route: Array[StringName] = [
		GameMain.PLACE_COMMONS, GameMain.PLACE_READY_ROOM, GameMain.PLACE_HOME,
		GameMain.PLACE_READY_ROOM, GameMain.PLACE_COMMONS, GameMain.PLACE_HOME,
	]
	for destination in route:
		var from: HubSpace = main.place
		_move(from, Vector3(1, 0, 0))  # from anywhere in the room, not at a doorway
		var hub: HubSpace = _to(main, destination)
		assert_eq(String(hub.layout.layout_id), String(destination))
		assert_eq(_hub_position(hub), hub.plan.entry_point, "arrives at %s's spawn" % destination)
		assert_eq(main.get_child_count(), 2, "one place and the fade")
	assert_eq(main.deploy_count, 0, "travelling never deploys")


func test_the_ready_room_returns_to_whichever_place_is_chosen() -> void:
	for choice: String in ["Home", "Commons"]:
		var main: GameMain = _main()
		# Arrive from the OTHER place, so the result is the choice and not a "back" button.
		var ready_room: HubSpace = _to_ready_room(main, GameMain.PLACE_COMMONS if choice == "Home" else GameMain.PLACE_HOME)
		_button(ready_room, choice).pressed.emit()
		_settle(main)
		assert_eq(main.place_id, StringName(choice.to_lower()), "the player's choice, not where they came from")
		assert_eq(main.deploy_count, 0)
		assert_null(main._prepared_plan, "leaving without deploying forgets the briefing")


func test_a_click_travels_once_whatever_else_is_pressed() -> void:
	var main: GameMain = _main()
	var home: HubSpace = _to_home(main)
	watch_signals(home)
	_button(home, "Commons").pressed.emit()
	_button(home, "Commons").pressed.emit()
	_button(home, "Ready Room").pressed.emit()
	home._unhandled_input(_press(&"hub_travel"))
	assert_signal_emit_count(home, "travel_requested", 1)
	assert_signal_emitted_with_parameters(home, "travel_requested", [GameMain.PLACE_COMMONS])
	assert_false(home.is_choosing_destination(), "a leaving place opens nothing")
	_settle(main)
	assert_eq(main.place_id, GameMain.PLACE_COMMONS, "the first click won")


func test_tab_opens_the_choice_and_never_travels_by_itself() -> void:
	var main: GameMain = _main()
	var home: HubSpace = _to_home(main)
	watch_signals(home)
	var at: Vector3 = _hub_position(home)
	home._unhandled_input(_press(&"hub_travel"))
	assert_true(home.is_choosing_destination())
	var buttons: Array[Button] = home.travel_buttons()
	assert_true(buttons[0].has_focus(), "the first destination is offered, not taken")
	for button in buttons:
		assert_eq(button.focus_mode, Control.FOCUS_ALL)
	assert_eq(home._travel_hint.text, HubSpace.CHOOSING_HINT)
	# A held Tab repeats; repeats choose nothing.
	for i in 5:
		home._unhandled_input(_key(KEY_TAB, true))
	assert_signal_emit_count(home, "travel_requested", 0)
	assert_false(main.is_transitioning())
	# While the keyboard steers the HUD, held movement reaches no sim.
	var tick: int = home.sim.tick_count
	Input.action_press("move_forward")
	for i in 5:
		home._physics_process(DT)
	Input.action_release("move_forward")
	assert_eq(home.sim.tick_count, tick + 5, "the room still runs")
	assert_eq(_hub_position(home), at, "the Envoy holds still")


func test_the_keyboard_cycles_the_destinations_and_confirms_one() -> void:
	var main: GameMain = _main()
	var commons: HubSpace = _to_commons(main)
	watch_signals(commons)
	# Something else focusable on screen, after the destinations in tree order -- the ring must not
	# leak into it (today's hub has nothing else; a later HUD control would).
	var stray := Button.new()
	commons.get_node("HubPrompt").add_child(stray)
	commons.open_destination_choice()
	var buttons: Array[Button] = commons.travel_buttons()
	# The GUI's own Tab / Shift+Tab / arrow navigation, kept to a closed ring of destinations.
	assert_same(buttons[0].find_next_valid_focus(), buttons[1])
	assert_same(buttons[1].find_next_valid_focus(), buttons[0], "and wraps")
	assert_same(buttons[0].find_prev_valid_focus(), buttons[1])
	assert_same(buttons[0].get_node(buttons[0].focus_neighbor_bottom), buttons[1])
	assert_same(buttons[1].get_node(buttons[1].focus_neighbor_top), buttons[0])
	buttons[1].grab_focus()
	assert_signal_emit_count(commons, "travel_requested", 0, "moving focus travels nowhere")
	get_viewport().push_input(_key(KEY_ENTER))
	assert_signal_emit_count(commons, "travel_requested", 1, "Enter confirms the focused destination")
	assert_signal_emitted_with_parameters(commons, "travel_requested", [GameMain.PLACE_READY_ROOM])
	_settle(main)
	assert_eq(main.place_id, GameMain.PLACE_READY_ROOM)


func test_escape_backs_out_of_the_choice_and_hands_the_keys_back() -> void:
	var main: GameMain = _main()
	var home: HubSpace = _to_home(main)
	home._unhandled_input(_press(&"hub_travel"))
	home._unhandled_input(_press(&"ui_cancel"))
	assert_false(home.is_choosing_destination())
	for button in home.travel_buttons():
		assert_false(button.has_focus())
		assert_eq(button.focus_mode, Control.FOCUS_NONE)
	assert_eq(home._travel_hint.text, HubSpace.TRAVEL_HINT)
	assert_false(home.is_leaving())
	var at: Vector3 = _hub_position(home)
	_move(home, Vector3(0, 0, -1))
	assert_ne(_hub_position(home), at, "the Envoy walks again")
	home._unhandled_input(_press(&"hub_travel"))
	assert_true(home.is_choosing_destination(), "and the choice can be opened again")


func test_requests_during_a_move_are_dropped() -> void:
	var main: GameMain = _main()
	_to_home(main)
	main.go_to(GameMain.PLACE_READY_ROOM)
	main.go_to(GameMain.PLACE_COMMONS)
	main.go_to(GameMain.PLACE_EXPEDITION)
	_settle(main)
	assert_eq(main.place_id, GameMain.PLACE_READY_ROOM, "the first request won; the rest were refused")
	assert_eq(main.deploy_count, 0)


func test_the_outgoing_place_is_stopped_before_the_fade_and_gone_before_the_next_arrives() -> void:
	var main: GameMain = _main()
	var home: HubSpace = _to_home(main)
	home.request_travel(GameMain.PLACE_COMMONS)
	assert_false(home.is_physics_processing(), "frozen at the request")
	var tick: int = home.sim.tick_count
	home._step([Command.new(tick, home.envoy.actor_id, "move", {"direction": Vector3(1, 0, 0)})] as Array[Command], DT)
	assert_eq(home.sim.tick_count, tick, "and a frozen place does not step")
	home._unhandled_input(_press(&"hub_travel"))
	assert_false(home.is_choosing_destination(), "nor answers the keyboard")
	main._fade._process(1.0)  # dark: the swap happens here
	assert_false(home.is_inside_tree(), "removed from the tree before the destination is shown")
	assert_eq(main.get_child_count(), 2, "exactly one place")
	assert_false(main.place.is_physics_processing(), "the destination waits for the screen to clear")
	main._fade._process(1.0)
	assert_true(main.place.is_physics_processing(), "and then takes input")


func test_an_open_console_panel_does_not_trap_travel() -> void:
	var main: GameMain = _main()
	var commons: HubSpace = _to_commons(main)
	var console: Vector3 = commons.plan.exit_console
	assert_true(_walk_to(commons, console + Vector3(0, 0, 1.5)))
	commons._step([_press_at(commons, console)] as Array[Command], DT)
	assert_ne(commons.console_text(), "", "sanity: the notice is open")
	commons._unhandled_input(_press(&"hub_travel"))
	assert_true(commons.is_choosing_destination(), "Tab still reaches travel")
	assert_eq(commons.console_text(), "", "choosing puts the panel away")
	_button(commons, "Home").pressed.emit()
	assert_true(commons.is_leaving())


func test_repeated_hub_travel_leaves_one_place_each_time() -> void:
	var main: GameMain = _main()
	_to_home(main)
	for i in 3:
		for place: StringName in [GameMain.PLACE_COMMONS, GameMain.PLACE_READY_ROOM, GameMain.PLACE_HOME]:
			_to(main, place)
			assert_eq(main.get_child_count(), 2, "cycle %d: one place and the fade" % i)
	assert_eq(main.deploy_count, 0)


# --- HUB INPUT -----------------------------------------------------------------------------

func test_a_hub_reads_only_movement_and_the_press() -> void:
	var all: Array[Command] = [
		Command.new(0, 0, "attack", {"aim": Vector3.FORWARD, "phase": "pressed"}),
		Command.new(0, 0, "attack", {"aim": Vector3.FORWARD, "phase": "held"}),
		Command.new(0, 0, "attack", {"aim": Vector3.FORWARD, "phase": "released"}),
		Command.new(0, 0, "move", {"direction": Vector3.FORWARD}),
		Command.new(0, 0, "block", {"held": true}),
		Command.new(0, 0, "switch_weapon"),
	]
	var kept: Array = HubSpace.hub_commands(all).map(func(c: Command) -> String: return "%s:%s" % [c.kind, c.params.get("phase", "")])
	assert_eq(kept, ["attack:pressed", "move:"], "block, weapon switch, held and released never reach a hub sim")


func test_the_console_press_is_spent_on_reading_without_a_weapon() -> void:
	var main: GameMain = _main()
	var commons: HubSpace = _to_commons(main)
	var console: Vector3 = commons.plan.exit_console
	assert_true(_walk_to(commons, console + Vector3(0, 0, 1.5)))
	var aim: Vector3 = console - _hub_position(commons)
	assert_eq(String(commons.sim.interaction_focus(commons.envoy.actor_id, aim).get("kind", "")), "inspect", "the focus rule finds the console")
	var events: Array[Event] = commons.sim.tick([_press_at(commons, console)] as Array[Command], DT)
	var kinds: Array = events.map(func(e: Event) -> String: return e.kind)
	assert_true(kinds.has("exit_console_inspected"))
	assert_false(kinds.has("attack_rejected"), "no ordinary attack was attempted")
	assert_false(kinds.has("melee_swing"))
	commons._report_events(events)
	assert_true(commons.console_text().contains("The Commons"), "the notice opened, got '%s'" % commons.console_text())
	commons._step([_press_at(commons, console)] as Array[Command], DT)
	assert_eq(commons.console_text(), "", "the same press puts it away")


func test_walking_home_or_the_commons_never_deploys() -> void:
	var main: GameMain = _main()
	for place: StringName in [GameMain.PLACE_HOME, GameMain.PLACE_COMMONS]:
		var hub: HubSpace = _to(main, place)
		for direction: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
			for i in 120:
				_move(hub, direction)
		assert_false(hub.is_leaving())
		assert_eq(main.place_id, place)


## The real sim's collision, walked: plaza -> mouth -> bay centre, for each district.
func test_every_commons_district_is_walkable_and_in_camera_range() -> void:
	var main: GameMain = _main()
	var commons: HubSpace = _to_commons(main)
	var routes: Dictionary = {
		"west": [Vector3(-11, 0, -19), Vector3(-15, 0, -19), Vector3(-23, 0, -19)],
		"east": [Vector3(11, 0, -19), Vector3(15, 0, -19), Vector3(23, 0, -19)],
		"north": [Vector3(5, 0, -16), Vector3(5, 0, -26), Vector3(0, 0, -30), Vector3(0, 0, -33), Vector3(0, 0, -39)],
	}
	# A straight walk at the monument stops at it.
	assert_true(_walk_to(commons, Vector3(0, 0, -15)))
	for i in 120:
		_move(commons, Vector3(0, 0, -1))
	assert_gt(_hub_position(commons).z, -19.5, "nothing walks through the monument")
	for district: String in routes:
		assert_true(_walk_to(commons, Vector3(5, 0, -8)), "back in the plaza before %s" % district)
		for waypoint: Vector3 in routes[district]:
			assert_true(_walk_to(commons, waypoint), "%s district: reached %s" % [district, waypoint])
		var back: Array = routes[district].duplicate()
		back.reverse()
		for waypoint: Vector3 in back:
			assert_true(_walk_to(commons, waypoint), "%s district: walked back through %s" % [district, waypoint])
	assert_eq(commons._camera._floor_extent, Rect2(-30, -44, 60, 44), "the camera knows the whole Commons")


# --- DEPLOYMENT ----------------------------------------------------------------------------

func test_the_briefing_describes_the_plan_deployment_installs() -> void:
	for via: StringName in [GameMain.PLACE_HOME, GameMain.PLACE_COMMONS]:
		_assert_briefing_is_deployed(via)


func _assert_briefing_is_deployed(via: StringName) -> void:
	var main: GameMain = _main()
	var ready_room: HubSpace = _to_ready_room(main, via)
	var briefed: FloorPlan = ready_room.briefing_plan
	assert_not_null(briefed)
	var console: Vector3 = ready_room.plan.exit_console
	assert_true(_walk_to(ready_room, console + Vector3(0, 0, 1.5)), "the briefing stands straight ahead of arrival")
	ready_room._step([_press_at(ready_room, console)] as Array[Command], DT)
	var text: String = ready_room.console_text()
	assert_true(text.contains("EXPEDITION"), text)
	assert_true(text.contains("Depth 1"), text)
	assert_true(text.contains("Seed 0"), text)
	assert_false(ready_room.is_leaving(), "reading is not deploying")

	var arena: Node3D = _deploy_from(main, ready_room)
	assert_same(arena._current_plan, briefed, "THE SAME PLAN, not an equal one")
	var regenerated: FloorPlan = DepthGenerator.generate(0, 1)
	assert_eq(arena._current_plan.patch_rects(), regenerated.patch_rects(), "and it is the seed's Floor 1")
	assert_eq(arena._current_plan.all_spawns(), regenerated.all_spawns())
	assert_eq(arena._current_plan.exit_console, regenerated.exit_console)
	assert_eq(arena._current_plan.triggers.size(), regenerated.triggers.size())
	assert_eq(FloorPreview.of(arena._current_plan), FloorPreview.of(briefed))


func _deploy_from(main: GameMain, ready_room: HubSpace) -> Node3D:
	_walk_onto_pad(ready_room)
	_finish_departure(ready_room)
	_settle(main)
	return main.place


# --- DEPLOYMENT TRANSMISSION (human review 2026-10-22) ---------------------------------------

## The pad plays the descent's own transmission before anything deploys: the same length, every
## input latched off, the request sent once on the last tick -- from either hub.
func test_the_pad_transmits_the_party_before_the_expedition_exists() -> void:
	for via: StringName in [GameMain.PLACE_HOME, GameMain.PLACE_COMMONS]:
		var main: GameMain = _main()
		var ready_room: HubSpace = _to_ready_room(main, via)
		watch_signals(ready_room)
		var probe: Node3D = load(ARENA_SCENE).instantiate()
		var descent_ticks: int = probe.descent_ticks
		probe.free()
		assert_eq(ready_room.departure_ticks, descent_ticks, "as long as a descent between floors")
		_walk_onto_pad(ready_room)
		assert_true(ready_room.is_departing(), "%s: the pad began the transmission" % via)
		assert_true(ready_room._transmission.is_showing(), "the transmission field is up")
		assert_false(ready_room._travel.is_visible_in_tree(), "the travel choice is taken off the screen")
		var held_at: Vector3 = _hub_position(ready_room)
		for i in descent_ticks - 1:
			# Everything a player could do mid-transmission, every tick: none of it reaches anything.
			ready_room._step([Command.new(ready_room.sim.tick_count, ready_room.envoy.actor_id, "move", {"direction": Vector3(1, 0, 0)}),
				_press_at(ready_room, ready_room.plan.exit_console)] as Array[Command], DT)
			ready_room.request_travel(GameMain.PLACE_COMMONS if via == GameMain.PLACE_HOME else GameMain.PLACE_HOME)
			ready_room._unhandled_input(_press(&"hub_travel"))
		assert_eq(_hub_position(ready_room), held_at, "the Envoy is held on the pad")
		assert_false(ready_room.is_choosing_destination(), "the travel choice stays shut")
		assert_signal_emit_count(ready_room, "travel_requested", 0)
		assert_signal_emit_count(ready_room, "deploy_requested", 0, "not before the transmission completes")
		assert_eq(main.place_id, GameMain.PLACE_READY_ROOM, "no expedition exists yet")
		assert_eq(main.deploy_count, 0)
		assert_false(ready_room.envoy.visible, "the Envoy has gone to light")
		assert_gt(ready_room.departure_progress(), 0.9)
		ready_room._step([] as Array[Command], DT)
		assert_signal_emit_count(ready_room, "deploy_requested", 1, "once, on the last tick")
		assert_almost_eq(ready_room._descent_overlay._shade.color.a, 1.0, 0.001, "and the screen is dark")
		_finish_departure(ready_room)
		_settle(main)
		assert_signal_emit_count(ready_room, "deploy_requested", 1, "and never again")
		assert_eq(main.deploy_count, 1)


## The handoff is a cut under the departure's darkness, and Floor 1 is arrived on the way a descent
## arrives on every later floor -- not through the generic fade.
func test_floor_one_arrives_by_transmission_not_by_a_fade() -> void:
	var main: GameMain = _main()
	var ready_room: HubSpace = _to_ready_room(main)
	var briefed: FloorPlan = ready_room.briefing_plan
	_walk_onto_pad(ready_room)
	_finish_departure(ready_room)
	# One frame: the screen is already dark, so the fade-out has nothing left to do.
	main._fade._process(1.0 / 60.0)
	assert_eq(main.place_id, GameMain.PLACE_EXPEDITION, "swapped on the next frame, with no fade")
	assert_false(main.is_transitioning(), "and handed over at once")
	assert_eq(main._fade.alpha(), 0.0, "Main's black is not what the player sees")
	var arena: Node3D = main.place
	assert_true(arena.arrives_by_transmission)
	assert_true(arena._descent_overlay.visible, "the arena's own descent overlay is clearing")
	assert_almost_eq(arena._descent_overlay._shade.color.a, 1.0, 0.001, "from fully dark")
	assert_false(arena._descent_overlay.is_descending(), "as an arrival, not a descent")
	assert_true(arena._transmission.is_showing(), "the arrival light on the Envoy")
	assert_true(arena._arrival_card.visible, "the arrival card")
	assert_true(arena._arrival_card._label.text.contains("Depth 1"), arena._arrival_card._label.text)
	assert_true(arena.is_physics_processing(), "the floor is live under the clearing light")
	# NOTHING WAS COMPLETED TO GET HERE.
	assert_same(arena._current_plan, briefed, "the prepared Floor 1, by identity")
	assert_eq(arena.expedition.current_depth(), 1)
	assert_eq(arena.expedition.position, 0, "no floor skipped")
	assert_eq(arena.expedition.floors_cleared(), 0)
	assert_eq(arena.expedition.phase, Expedition.PHASE_EXPLORING)
	_assert_fresh(arena)
	arena._descent_overlay._process(arena._descent_overlay.arrival_fade_seconds + 0.01)
	assert_false(arena._descent_overlay.visible, "and the screen clears")


## Floor 1 -> Floor 2 after a deployment is the descent it always was.
func test_the_first_descent_after_deployment_is_unchanged() -> void:
	var main: GameMain = _main()
	var arena: Node3D = _deploy(main)
	var promised: FloorPlan = arena._next_plan
	arena._report_events([Event.new(arena.sim.tick_count, "floor_complete", {})] as Array[Event])
	arena._resolve_transitions()
	assert_eq(arena.expedition.phase, Expedition.PHASE_DESCENDING)
	for i in arena.descent_ticks:
		arena._step([] as Array[Command], DT)
	assert_eq(arena.expedition.phase, Expedition.PHASE_EXPLORING)
	assert_eq(arena.expedition.current_depth(), 2, "Floor 1 cleared once, Floor 2 installed")
	assert_same(arena._current_plan, promised, "the plan Floor 1's exit previewed")
	assert_true(arena._transmission.is_showing(), "arriving in the transmission's light")
	assert_true(arena._arrival_card._label.text.contains("Depth 2"))


## A direct launch has no pad behind it: it arrives as it always has.
func test_a_standalone_arena_does_not_arrive_by_transmission() -> void:
	var arena: Node3D = load(ARENA_SCENE).instantiate()
	add_child_autofree(arena)
	assert_false(arena.arrives_by_transmission)
	assert_false(arena._descent_overlay.visible)
	assert_false(arena._transmission.is_showing())


## A travel move keeps the short fade; only deployment is a transmission.
func test_hub_travel_still_fades() -> void:
	var main: GameMain = _main()
	var home: HubSpace = _to_home(main)
	home.request_travel(GameMain.PLACE_COMMONS)
	assert_true(main.is_transitioning())
	assert_same(main.place, home, "the outgoing place stays until the screen is dark")
	main._fade._process(main._fade.fade_out_seconds * 0.5)
	assert_gt(main._fade.alpha(), 0.0)
	assert_lt(main._fade.alpha(), 1.0, "a visible fade")
	assert_false(home._transmission.is_showing(), "and no transmission plays for travel")
	assert_true(home._travel.is_visible_in_tree(), "and the travel choice stays on screen while it fades")
	_settle(main)
	assert_eq(main.place_id, GameMain.PLACE_COMMONS)


func test_the_pad_deploys_a_fresh_expedition_on_floor_one_once_from_either_hub() -> void:
	for via: StringName in [GameMain.PLACE_HOME, GameMain.PLACE_COMMONS]:
		var main: GameMain = _main()
		var ready_room: HubSpace = _to_ready_room(main, via)
		watch_signals(ready_room)
		var arena: Node3D = _deploy(main, via)
		assert_signal_emit_count(ready_room, "deploy_requested", 1)
		assert_eq(main.deploy_count, 1)
		_assert_fresh(arena)
		assert_eq(arena.sim._patch_rects.size(), DepthGenerator.generate(0, 1).patches.size(), "on Floor 1, via %s" % via)


func test_the_travel_shortcut_does_nothing_on_an_expedition() -> void:
	var main: GameMain = _main()
	var arena: Node3D = _deploy(main)
	Input.action_press("hub_travel")
	arena._physics_process(DT)
	assert_false(main.is_transitioning())
	assert_same(main.place, arena)


# --- RUN END -> COMMONS --------------------------------------------------------------------

func test_emergency_recall_returns_to_the_commons_only_through_the_summary() -> void:
	var main: GameMain = _main()
	var arena: Node3D = _deploy(main, GameMain.PLACE_HOME)
	_recall(arena)
	assert_eq(arena._run_summary.outcome(), RunSummaryOverlay.OUTCOME_RECALL)
	arena._run_summary.request_action()
	assert_false(main.is_transitioning(), "nothing leaves the run before its result is readable")
	assert_false(arena._run_summary._action.visible)
	_show_summary(arena)
	assert_true(arena._run_summary.is_action_available())
	assert_true(arena._run_summary.text().contains("Return to Commons"))
	assert_false(arena._run_summary.text().contains("Press R"), "no restart offered under the game loop")
	arena._run_summary.request_action()
	arena._run_summary.request_action()
	_settle(main)
	assert_eq(main.place_id, GameMain.PLACE_COMMONS, "to the Commons, though the run began from Home")
	assert_eq((main.place as HubSpace).layout.layout_id, &"commons")
	assert_eq(_hub_position(main.place), (main.place as HubSpace).plan.entry_point, "at the Commons' spawn")
	assert_false(arena.is_inside_tree(), "the finished run is gone")


func test_extraction_returns_to_the_commons_through_the_summary() -> void:
	for via: StringName in [GameMain.PLACE_HOME, GameMain.PLACE_COMMONS]:
		var main: GameMain = _main()
		var arena: Node3D = _deploy(main, via)
		_extract_last_floor(main, arena)
		assert_eq(arena._run_summary.outcome(), RunSummaryOverlay.OUTCOME_EXTRACTION)
		_show_summary(arena)
		arena._run_summary._action.pressed.emit()
		_settle(main)
		assert_eq(main.place_id, GameMain.PLACE_COMMONS, "never Home, via %s" % via)


## The real run is four floors; completing the last one is what extracts. Ridden here through the
## arena's own descent path, floor by floor.
func _extract_last_floor(main: GameMain, arena: Node3D) -> void:
	for i in arena.expedition.itinerary.size() - 1:
		arena._report_events([Event.new(arena.sim.tick_count, "floor_complete", {})] as Array[Event])
		arena._resolve_transitions()
		for t in arena.descent_ticks:
			arena._step([] as Array[Command], DT)
	_extract(arena)


func test_a_second_expedition_after_each_ending_starts_clean() -> void:
	var main: GameMain = _main()
	var first: Node3D = _deploy(main)
	_recall(first)
	_show_summary(first)
	first._run_summary.request_action()
	_settle(main)

	assert_eq(main.place_id, GameMain.PLACE_COMMONS)
	var second: Node3D = _deploy(main, GameMain.PLACE_COMMONS)
	assert_ne(second, first, "a new arena, not the old one reset")
	_assert_fresh(second)
	_extract_last_floor(main, second)
	_show_summary(second)
	second._run_summary.request_action()
	_settle(main)

	assert_eq(main.place_id, GameMain.PLACE_COMMONS)
	var third: Node3D = _deploy(main, GameMain.PLACE_HOME)
	_assert_fresh(third)
	assert_eq(main.deploy_count, 3)
	assert_eq(main.get_child_count(), 2, "one place and the fade, after three expeditions")


func test_leaving_the_ready_room_either_way_forgets_the_briefing() -> void:
	var main: GameMain = _main()
	for leave_to: StringName in [GameMain.PLACE_HOME, GameMain.PLACE_COMMONS]:
		_to_ready_room(main)
		assert_not_null(main._prepared_plan)
		_to(main, leave_to)
		assert_null(main._prepared_plan, "a briefing that was not deployed is not carried to %s" % leave_to)


# --- RESTART (R) ---------------------------------------------------------------------------

func test_r_restarts_only_a_standalone_arena() -> void:
	var main: GameMain = _main()
	var deployed: Node3D = _deploy(main)
	var standalone: Node3D = load(ARENA_SCENE).instantiate()
	add_child(standalone)
	assert_true(standalone.standalone, "a direct launch is standalone by default")
	Input.action_press("restart")
	assert_true(standalone._restart_requested(), "F6 / tests keep R")
	assert_false(deployed._restart_requested(), "the game loop does not")
	# Gone before any real frame: Godot reports a same-frame press as just-pressed on the next
	# physics step even once released, and a live standalone arena would reload the test runner.
	remove_child(standalone)
	standalone.free()
	_recall(deployed)
	_show_summary(deployed)
	assert_false(deployed._restart_requested(), "not even on the summary")
	Input.action_release("restart")
	assert_true(InputMap.has_action("restart"))


func test_a_standalone_summary_still_offers_r() -> void:
	var arena: Node3D = load(ARENA_SCENE).instantiate()
	add_child_autofree(arena)
	_recall(arena)
	_show_summary(arena)
	assert_false(arena._run_summary.is_action_available(), "no button outside the game loop")
	assert_true(arena._run_summary.text().contains(RunSummaryOverlay.RESTART_HINT))
