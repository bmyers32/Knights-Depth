class_name GameMain
extends Node
## THE GAME LOOP'S NAVIGATION (M2 Slice 3): Title -> Home; Home, Commons and Ready Room each
## one action from the other two; Ready Room pad -> Expedition -> summary -> Commons. The scene
## root, not an autoload: it owns which place is on screen and the concrete moves between them,
## and nothing else. No gameplay state lives here -- every SimWorld belongs to the place that is
## showing, and dies with it.
##
## EXACTLY ONE PLACE AT A TIME. A move is: latch -> freeze the outgoing place (no tick, no input)
## -> fade to black -> REMOVE it from the tree and free it -> build the destination with its
## parameters -> add it, held still -> fade in -> hand it input. remove_child before queue_free is
## the point: a queued node still in the tree would keep processing beside its replacement.
##
## Deliberately not a scene-management framework (§1.4): five destinations, written out.
##
## M3: deploy() is the seam a server-side "request deployment" replaces; nothing here is synced.

const PLACE_TITLE: StringName = &"title"
const PLACE_HOME: StringName = &"home"
const PLACE_COMMONS: StringName = &"commons"
const PLACE_READY_ROOM: StringName = &"ready_room"
const PLACE_EXPEDITION: StringName = &"expedition"

const _TITLE: PackedScene = preload("res://game/ui/title_screen.tscn")
const _HUB: PackedScene = preload("res://game/hub/hub_space.tscn")
const _ARENA: PackedScene = preload("res://game/arena/arena.tscn")
const _HOME_LAYOUT: AuthoredLayout = preload("res://game/content/layouts/home.tres")
const _COMMONS_LAYOUT: AuthoredLayout = preload("res://game/content/layouts/commons.tres")
const _READY_ROOM_LAYOUT: AuthoredLayout = preload("res://game/content/layouts/ready_room.tres")
## What a hub's travel buttons call each place. "Home" is provisional (2026-10-21): no lore name yet.
const PLACE_LABELS: Dictionary = {
	PLACE_HOME: "Home",
	PLACE_COMMONS: "Commons",
	PLACE_READY_ROOM: "Ready Room",
}

## FIXED for M2 Slice 3 (human ruling 2026-10-20): every deployment uses seed 0, passed explicitly.
## A development baseline, not the seed policy -- see ROADMAP (fresh seed by default once floors
## actually vary by seed; deliberate replay-by-seed).
@export var run_seed: int = 0
## Empty = the Arena's own authored itinerary. Never a second copy of [1, 2, 3, 4].
@export var itinerary_override: Array[int] = []

var place_id: StringName = &""
var place: Node = null
## How many expeditions this session has deployed. Observability for tests and the log.
var deploy_count: int = 0
## The Floor 1 plan the Ready Room is briefing on, handed to the deployment that follows it.
var _prepared_plan: FloorPlan = null
var _transitioning: bool = false

@onready var _fade: FadeOverlay = $FadeOverlay


func _ready() -> void:
	_install(_build(PLACE_TITLE), PLACE_TITLE)
	_resume()


func is_transitioning() -> bool:
	return _transitioning


## THE ONE WAY BETWEEN PLACES. Every request -- a title button, a hub action, a pad, a summary
## button -- arrives here; while one move is in progress every other is dropped.
func go_to(destination: StringName) -> void:
	if _transitioning:
		return
	_transitioning = true
	print("navigation: ", {"from": place_id, "to": destination})
	if place != null and place.has_method("freeze"):
		place.freeze()
	# DEPLOYMENT IS A TRANSMISSION, NOT A FADE (human review 2026-10-22). The Ready Room has already
	# played the descent's departure and ended on its dark screen, so the swap is a cut under that
	# darkness: covering instantly here shows nothing new, and the fade-out completes on its first step.
	if destination == PLACE_EXPEDITION:
		_fade.cover()
	_fade.fade_out(_arrive.bind(destination))


func _arrive(destination: StringName) -> void:
	if place != null:
		remove_child(place)
		place.queue_free()
		place = null
	_install(_build(destination), destination)
	if destination == PLACE_EXPEDITION:
		# The arena arrives the way every floor after it does -- its own descent overlay, dark, clearing
		# off a floor that is already live -- so Main's black steps aside at once rather than fading.
		_fade.uncover()
		_resume()
		return
	# Held still while the screen clears: the destination's first tick is the first one the player
	# can see.
	place.set_physics_process(false)
	_fade.fade_in(_resume)


func _resume() -> void:
	_transitioning = false
	if place != null and not (place is HubSpace and place.is_leaving()):
		place.set_physics_process(true)


func _install(node: Node, id: StringName) -> void:
	place = node
	place_id = id
	add_child(node)


func _build(destination: StringName) -> Node:
	match destination:
		PLACE_TITLE:
			var title: TitleScreen = _TITLE.instantiate()
			title.start_requested.connect(go_to.bind(PLACE_HOME))
			return title
		PLACE_HOME:
			_prepared_plan = null
			var home: HubSpace = _hub(_HOME_LAYOUT, "HOME", [PLACE_COMMONS, PLACE_READY_ROOM])
			home.notice_title = "NOTICE"
			home.notice_headline = "Home"
			home.notice_body = "Your own space. The Commons and the Ready Room are a step away."
			return home
		PLACE_COMMONS:
			# Whatever was briefed is not deployed: leaving the Ready Room forgets it.
			_prepared_plan = null
			var commons: HubSpace = _hub(_COMMONS_LAYOUT, "THE COMMONS", [PLACE_HOME, PLACE_READY_ROOM])
			commons.notice_title = "NOTICE"
			commons.notice_headline = "The Commons"
			commons.notice_body = "Envoys gather here between expeditions, and muster in the Ready Room before one."
			return commons
		PLACE_READY_ROOM:
			# PREPARED ONCE, here: the plan the briefing describes IS the plan deployment installs.
			# The seam a future expedition choice hands its configuration through.
			_prepared_plan = DepthGenerator.generate(run_seed, expedition_itinerary()[0])
			var ready_room: HubSpace = _hub(_READY_ROOM_LAYOUT, "READY ROOM", [PLACE_HOME, PLACE_COMMONS])
			ready_room.deploys = true
			# The departure lasts exactly as long as a descent between floors: the arena's own value,
			# read from its scene, never restated.
			ready_room.departure_ticks = int(_arena_default(&"descent_ticks"))
			ready_room.briefing_plan = _prepared_plan
			ready_room.briefing_detail = "Seed %d · %s · %d floors" % [
				run_seed, "authored layout" if _prepared_plan.authored_layout else "generated",
				expedition_itinerary().size()]
			ready_room.deploy_requested.connect(go_to.bind(PLACE_EXPEDITION))
			return ready_room
		PLACE_EXPEDITION:
			assert(_prepared_plan != null, "a deployment always follows a Ready Room briefing")
			var arena: Node3D = _ARENA.instantiate()
			arena.standalone = false
			arena.run_seed = run_seed
			if not itinerary_override.is_empty():
				arena.itinerary = itinerary_override
			arena.prepared_first_plan = _prepared_plan
			arena.arrives_by_transmission = true
			_prepared_plan = null
			deploy_count += 1
			# Every ending -- Extraction or Emergency Recall -- regroups in the Commons, never Home.
			arena.return_to_commons_requested.connect(go_to.bind(PLACE_COMMONS))
			print("deployment: ", {"count": deploy_count, "run_seed": run_seed})
			return arena
	push_error("GameMain: no place called '%s'" % destination)
	return Node.new()


func _hub(layout: AuthoredLayout, title: String, destinations: Array[StringName]) -> HubSpace:
	var hub: HubSpace = _HUB.instantiate()
	hub.layout = layout
	hub.place_title = title
	for destination in destinations:
		hub.add_destination(destination, PLACE_LABELS[destination])
	hub.travel_requested.connect(go_to)
	return hub


## The itinerary a deployment will run: the override, or the Arena scene's own authored value --
## read from the scene rather than restated, so the two can never disagree.
func expedition_itinerary() -> Array[int]:
	var itinerary: Array[int] = []
	if not itinerary_override.is_empty():
		itinerary.assign(itinerary_override)
		return itinerary
	itinerary.assign(_arena_default(&"itinerary"))
	return itinerary


## One of the Arena scene's own configured values: the scene's override if it has one, else the
## script's default.
func _arena_default(property: StringName) -> Variant:
	var state: SceneState = _ARENA.get_state()
	for index in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == property:
			return state.get_node_property_value(0, index)
	return load("res://game/arena/arena.gd").get_property_default_value(property)
