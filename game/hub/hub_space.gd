class_name HubSpace
extends Node3D
## A SAFE PLACE OUTSIDE ANY EXPEDITION (M2 Slice 3): Home, the Commons, or the Ready Room. One
## scene, configured by GameMain before it enters the tree, the way tests configure an Arena.
##
## ONE IMPLEMENTATION, NOT ONE AUTHORITY. The three places share this code only because all three
## are local today. Home is private, the Commons shared, the Ready Room the party's -- they will
## diverge at M3/M4, and nothing here should grow toward a common networked model.
##
## IT HAS A SIMWORLD, AND IT IS NOT AN EXPEDITION. The Envoy is a projection of sim state -- it
## cannot walk without one -- so this place owns a small SimWorld for movement, walkable legality
## and the console press, and nothing else: no weapons, no shield, no statuses, no roster, no
## Expedition object. Safety is by construction (and pinned by test_hub_layouts.gd), the same way
## the Terminal is safe: there is nothing here that could hurt anyone.
##
## TWO WAYS OUT, BOTH SIGNALS UP. Travel (a HUD destination, clicked, or chosen from the keyboard)
## and, in the Ready Room only, deployment (all living Envoys on the transmission pad -- the sim's
## own floor_complete).
## Either one latches this place shut on the spot: one request per place, ever. GameMain performs
## the move; nothing here changes scene.
##
## HUB FRAMING, NOT COMBAT FRAMING (human ruling 2026-10-22). hub_space.tscn brings the camera to
## (0, 9, 9) at the same 45 degrees, so a hub is larger than one screen and pans like a place you
## walk through. The expedition keeps M1's validated (0, 12, 12): nothing in a hub is fought.
## The scene also draws blocks at their own height and raised ground as solid (FloorBuilder).
##
## Pad deployment is today's SOLO mechanism. It reuses the party-wide occupancy rule because that
## is the rule the exit already uses -- it is not a co-op ready-up protocol, and none is implied.
##
## DEPLOYMENT LEAVES BY TRANSMISSION (human review 2026-10-22). The pad plays the same departure a
## floor exit does -- the field rises, the Envoy goes to light, the screen darkens -- over the same
## number of sim-rate ticks, with every input already latched off; only then does it ask GameMain to
## deploy. The countdown is this place's own picture, not an Expedition: no floor is completed by it.

signal travel_requested(destination: StringName)
signal deploy_requested

@export var layout: AuthoredLayout
## The place's name on the HUD.
@export var place_title: String = ""
@export var travel_font_size: int = 18
## Only the Ready Room deploys. A completed "floor" anywhere else is a content error.
@export var deploys: bool = false
## How long the deployment departure plays, in sim-rate ticks. GameMain hands over the Arena's own
## descent_ticks; 0 (unconfigured) deploys on the pad's own tick.
@export var departure_ticks: int = 0
## What the console says in a place with no floor ahead (the Commons).
@export var notice_title: String = ""
@export var notice_headline: String = ""
@export var notice_body: String = ""

## The Ready Room's briefing: the PREPARED Floor 1 plan, the same object the deployment installs.
var briefing_plan: FloorPlan = null
var briefing_detail: String = ""

@onready var envoy: CharacterBody3D = $Envoy
@onready var _floor_builder: FloorBuilder = $FloorBuilder
@onready var _camera: FollowCamera = $FollowCamera
@onready var _console_panel: ExitConsolePanel = $ExitConsolePanel
@onready var _place_label: Label = $HubPrompt/PlaceLabel
@onready var _travel: VBoxContainer = $HubPrompt/Travel
@onready var _travel_hint: Label = $HubPrompt/Travel/Hint
@onready var _travel_options: VBoxContainer = $HubPrompt/Travel/Options
@onready var _transmission: TransmissionField = $TransmissionField
@onready var _descent_overlay: DescentOverlay = $DescentOverlay

const _CONSOLE_ID: int = 0
## The hub's verbs. Block and weapon switch are combat context and never reach a hub sim; an
## attack reaches it only as a PRESS, which the sim spends on the console when one is focused.
const _HUB_COMMAND_KINDS: Array[String] = ["move", "attack"]
const TRAVEL_HINT: String = "Tab  choose a destination"
const CHOOSING_HINT: String = "Tab  next   ·   Enter  travel   ·   Esc  back"

var sim := SimWorld.new()
var plan: FloorPlan
var _leaving: bool = false
## Every other place this one can reach, in HUD order: {"id": StringName, "label": String}.
var _destinations: Array[Dictionary] = []
## The keyboard is choosing a destination: the buttons hold focus and the Envoy holds still.
var _choosing: bool = false
## Ticks left in the deployment departure; 0 when none is playing.
var _departure_ticks_remaining: int = 0
var _departure_begun: bool = false


func _ready() -> void:
	assert(layout != null, "a HubSpace needs its layout before it enters the tree")
	plan = FloorPlan.new()
	plan.stratum_id = layout.stratum_id
	plan.authored_layout = true
	LayoutCompiler.compile(layout, plan)
	plan.validate({})

	sim.add_entity(envoy.actor_id, plan.entry_point, envoy.stats.move_speed, Vector3(0.0, 0.0, -1.0), envoy.stats.combat_radius)
	# A living combatant, because both the console press and pad occupancy ask "is this Envoy in
	# play" of _health. It is never anything's target: there is nothing here to target it.
	sim.register_combatant(envoy.actor_id, envoy.stats.max_health, envoy.stats.family, envoy.stats.iframe_ticks_on_hit, envoy.stats.combat_radius, &"player")
	sim.register_carrier(envoy.actor_id, envoy.stats.pickup_reach, envoy.stats.pickup_cone_half_angle_degrees, envoy.stats.pickup_underfoot_radius)
	sim.mark_run_persistent(envoy.actor_id)
	sim.load_floor(plan.make_bounds(), plan.entry_point)
	# The hub's share of arena._unpack_floor, same order: geometry, then the things that name it.
	# A deliberate second copy (§1.4): extract a shared installer when a third consumer arrives.
	sim.register_patches(plan.patch_rects())
	sim.register_obstacles(plan.obstacle_rects())
	sim.register_solid_segments(plan.solid_segments())
	for connection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
	sim.register_exit_console(_CONSOLE_ID, plan.exit_console)
	for trigger in plan.triggers:
		sim.register_trigger(trigger.trigger_id, trigger.kind, trigger.region, trigger.source_id, trigger.once, trigger.effects, trigger.starts_enabled)
	if not deploys and _has_deploy_pad(plan):
		push_error("HubSpace '%s': a place that does not deploy has a floor-completing pad" % layout.layout_id)

	var barriers: Dictionary = {}
	for connection in plan.connections:
		barriers[connection.connection_id] = sim.gate_barrier(connection.connection_id)
	var spawned: Array[Dictionary] = _floor_builder.build(plan, envoy.actor_id + 1, barriers)
	assert(spawned.is_empty(), "a hub space never fields a roster")
	_floor_builder.build_walls(plan)
	# A hub's console is the first thing an arriving Envoy walks up to, so it faces the arrival.
	_floor_builder.turn_exit_console_toward(plan.entry_point)

	envoy.teleport_from_sim(_grounded(plan.entry_point))
	_camera.set_target(envoy)
	_camera.set_floor_extent(_floor_extent_of(plan))
	_camera.snap_to_target()

	_place_label.text = place_title
	_build_travel_options()
	print("hub entered: ", {"layout": layout.layout_id, "deploys": deploys})


## GameMain's configuration, before the place enters the tree.
func add_destination(id: StringName, label: String) -> void:
	_destinations.append({"id": id, "label": label})


func has_destination(id: StringName) -> bool:
	return _destinations.any(func(destination: Dictionary) -> bool: return destination["id"] == id)


func travel_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.assign(_travel_options.get_children())
	return buttons


func _build_travel_options() -> void:
	for destination in _destinations:
		var button := Button.new()
		button.text = destination["label"]
		button.add_theme_font_size_override("font_size", travel_font_size)
		# PRESS, not release: the request latches during input dispatch, BEFORE this tick builds any
		# Command, so the click that travels can never also be read as an attack press.
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		# Focusable only while the keyboard is choosing; otherwise Tab is never GUI focus navigation.
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(request_travel.bind(destination["id"]))
		_travel_options.add_child(button)
	# A closed ring. Tab / Shift+Tab already cycle within the container (Godot 4.7, pinned by
	# test_the_keyboard_cycles_the_destinations_and_confirms_one); the arrows navigate by screen
	# geometry and could walk out to any other control, so they are wired explicitly.
	var buttons: Array[Button] = travel_buttons()
	for index in buttons.size():
		buttons[index].focus_neighbor_bottom = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_neighbor_top = buttons[index].get_path_to(buttons[(index - 1 + buttons.size()) % buttons.size()])
	_travel_hint.text = TRAVEL_HINT


## THE KEYBOARD'S WAY TO A DESTINATION: Tab opens the choice on the first one, the GUI's own focus
## navigation moves through them, Enter/Space travels, Esc backs out. Opening it never travels --
## with two destinations there is no default to jump to.
func open_destination_choice() -> void:
	if _leaving or _choosing or _destinations.is_empty():
		return
	_choosing = true
	_console_panel.close()
	_floor_builder.show_interaction_focus("", -1, -1)
	for button in travel_buttons():
		button.focus_mode = Control.FOCUS_ALL
	travel_buttons()[0].grab_focus()
	_travel_hint.text = CHOOSING_HINT


func close_destination_choice() -> void:
	if not _choosing:
		return
	_choosing = false
	for button in travel_buttons():
		button.release_focus()
		button.focus_mode = Control.FOCUS_NONE
	_travel_hint.text = TRAVEL_HINT


func is_choosing_destination() -> bool:
	return _choosing


## THE ONE TRAVEL REQUEST, for a click and a keyboard confirm alike. Latched: a second call -- a
## double click, a click and Enter together, a second destination -- changes nothing.
func request_travel(destination: StringName) -> void:
	if _leaving:
		return
	if not has_destination(destination):
		push_error("HubSpace '%s': no way from here to '%s'" % [layout.layout_id, destination])
		return
	_leave()
	print("hub travel requested: ", {"from": layout.layout_id, "to": destination})
	travel_requested.emit(destination)


func is_leaving() -> bool:
	return _leaving


func is_departing() -> bool:
	return _departure_ticks_remaining > 0


## GameMain's stop before it removes this place: no further tick, input or request.
func freeze() -> void:
	_departure_ticks_remaining = 0
	_leave()


func _leave() -> void:
	close_destination_choice()
	_leaving = true
	_console_panel.close()
	_floor_builder.show_interaction_focus("", -1, -1)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if is_departing():
		_advance_departure()
		return
	if _leaving:
		return
	if _choosing:
		# The keys are steering the HUD, not the Envoy: nothing held reaches the sim meanwhile.
		_step([] as Array[Command], delta)
		return
	_step(hub_commands(envoy.build_commands(sim.tick_count)), delta)


## The Envoy's ordinary Commands, reduced to the hub's verbs.
static func hub_commands(commands: Array[Command]) -> Array[Command]:
	var kept: Array[Command] = []
	for command in commands:
		if not command.kind in _HUB_COMMAND_KINDS:
			continue
		if command.kind == "attack" and String(command.params.get("phase", "pressed")) != "pressed":
			continue
		kept.append(command)
	return kept


## One step, drivable without the Input singleton (tests), mirroring Arena._step's shape.
func _step(commands: Array[Command], delta: float) -> void:
	if is_departing():
		_advance_departure()
		return
	if _leaving:
		return
	var events: Array[Event] = sim.tick(commands, delta)
	envoy.sync_from_sim(_grounded(sim.entities[envoy.actor_id]))
	_report_events(events)
	if _leaving:
		return
	var focus: Dictionary = sim.interaction_focus(envoy.actor_id, envoy.current_aim())
	_floor_builder.show_interaction_focus(String(focus.get("kind", "")), -1, -1)
	if _console_panel.is_open() and not sim.exit_console_within_reach(envoy.actor_id, _CONSOLE_ID):
		_console_panel.close()


func _report_events(events: Array[Event]) -> void:
	for event in events:
		match event.kind:
			"exit_console_inspected":
				print("HUB CONSOLE INSPECTED: ", event.payload)
				if _console_panel.is_open():
					_console_panel.close()
				else:
					_open_console()
			"floor_trigger_fired":
				print("hub trigger fired: ", event.payload)
			"floor_complete":
				if not deploys:
					push_error("HubSpace '%s': floor_complete in a place that does not deploy" % layout.layout_id)
					continue
				if _leaving:
					continue
				_begin_departure()
			# Every tick (moved) and every press that met no console (no weapon here): expected,
			# and not worth a line each.
			"moved", "attack_rejected":
				pass
			_:
				push_warning("hub: event kind '%s' has no reporting case" % event.kind)


## The pad accepted the party: everything latches shut now, and the transmission plays out before
## the request goes up. One departure per place -- _leaving refuses any second floor_complete.
func _begin_departure() -> void:
	_leave()
	_departure_begun = true
	print("DEPLOYMENT BEGUN: ", {"from": layout.layout_id, "departure_ticks": departure_ticks})
	if departure_ticks <= 0:
		_depart()
		return
	_departure_ticks_remaining = departure_ticks
	# The way out is no longer on offer: inert buttons left on screen would read as a choice still open.
	_travel.visible = false
	# _leave stopped the tick; the departure is the one thing that still advances on it.
	set_physics_process(true)
	_transmission.begin(_floor_builder.exit_pad_centre())
	_descent_overlay.begin()
	_project_departure()


## One sim-rate tick of the departure, read the way the Arena reads Expedition.descent_progress().
func _advance_departure() -> void:
	_departure_ticks_remaining -= 1
	_project_departure()
	if _departure_ticks_remaining <= 0:
		_depart()


func _project_departure() -> void:
	var progress: float = departure_progress()
	envoy.visible = _transmission.show_progress(progress)
	_descent_overlay.show_progress(progress)


func _depart() -> void:
	_departure_ticks_remaining = 0
	set_physics_process(false)
	print("DEPLOYMENT REQUESTED: ", {"from": layout.layout_id})
	deploy_requested.emit()


## 0.0 as the pad accepts the party, 1.0 on the tick the departure ends.
func departure_progress() -> float:
	if departure_ticks <= 0 or not _departure_begun:
		return 0.0
	return 1.0 - float(_departure_ticks_remaining) / float(departure_ticks)


func _open_console() -> void:
	if briefing_plan != null:
		_console_panel.open(FloorPreview.of(briefing_plan), "EXPEDITION", briefing_detail)
	else:
		_console_panel.open_notice(notice_title, notice_headline, notice_body)


func console_text() -> String:
	return _console_panel.text() if _console_panel.is_open() else ""


## Event-driven, not polled on the tick: while a destination button holds focus the GUI consumes
## Tab for its own navigation first, so only the press that OPENS the choice ever arrives here.
func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("hub_travel"):
		get_viewport().set_input_as_handled()
		if _choosing:
			travel_buttons()[0].grab_focus()  # focus was lost (a click elsewhere): take it back
		else:
			open_destination_choice()
	elif event.is_action_pressed("ui_cancel"):
		if _choosing:
			close_destination_choice()
			get_viewport().set_input_as_handled()
		elif _console_panel.is_open():
			_console_panel.close()
			get_viewport().set_input_as_handled()


## Visual ground lift, exactly as the Arena does it (Floor 4's stepped landing): the sim is flat and
## a hub's steps are a picture, so presentation raises the Envoy onto them. Height never travels
## back into the sim (P40 tier A/B; nothing here reads height).
func _grounded(position: Vector3) -> Vector3:
	return Vector3(position.x, _floor_builder.elevation_at(position), position.z)


static func _has_deploy_pad(floor_plan: FloorPlan) -> bool:
	for trigger in floor_plan.triggers:
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") == FloorLayers.EFFECT_COMPLETE_FLOOR:
				return true
	return false


static func _floor_extent_of(floor_plan: FloorPlan) -> Rect2:
	var extent: Rect2 = Rect2()
	var rects: Array[Rect2] = floor_plan.all_rects()
	for index in rects.size():
		extent = rects[index] if index == 0 else extent.merge(rects[index])
	return extent
