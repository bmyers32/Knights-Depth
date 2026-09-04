extends GutTest
## THE PERSISTENT HIT-SWITCH (ruled 2026-09-03).
##
## WHY IT IS NOT A BREAKABLE. The seam audit found "hit a world object -> fire floor effects"
## already expressible: a breakable is hittable, is explicitly not a combatant, and its
## destruction trigger already reaches OPEN_CONNECTION. The gap was exactly one thing -- the
## object is CONSUMED doing it. Right for a crate, wrong for a switch, and it makes a toggle
## inexpressible because destruction happens once.
##
## WHY IT IS NOT AN INTERACTABLE EITHER. `interact` was retired for having no consumer and does
## not come back here. A plate says GO AND STAND; a switch says SEE IT AND SHOOT IT. Both exist
## because their spatial meaning differs, not because one is a nicer verb.

const DT := 1.0 / 30.0
const PLAYER := 0
## Deliberately NOT 0: switch ids and actor ids are separate namespaces, and an id that happens
## to collide with the player's would make the "not a combatant" test below pass by accident.
const SWITCH := 5
const DOOR := 0
const ROOM := Rect2(-20.0, -10.0, 20.0, 20.0)
## Reachable ONLY through the aperture, so walkability there is a fact about the door.
const BEYOND := Vector3(2.0, 0.0, 0.0)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	sim.add_entity(PLAYER, Vector3(-15.0, 0.0, 0.0), 0.0, Vector3(1, 0, 0), 0.45)
	sim.register_combatant(PLAYER, 1000.0, &"envoy", 0, 0.45, &"player")
	sim.register_connection(DOOR, Rect2(0.0, -2.0, 4.0, 4.0), false)
	sim.register_gun(&"wand", 10.0, &"force", 40.0, 600, 0.2, 0.0, 1)
	sim.set_equipped_weapon(PLAYER, &"wand")


func _switch(mode: StringName, effects: Array, hidden: bool = false) -> void:
	sim.register_hit_switch(SWITCH, Vector3(-5.0, 0.0, 0.0), 0.7, mode, effects, hidden)


func _shoot() -> Array[Event]:
	var events: Array[Event] = sim.tick(
		[Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT)
	for i in 60:
		events.append_array(sim.tick([] as Array[Command], DT))
	return events


func _kinds(events: Array[Event]) -> Array:
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	return kinds


func _open() -> bool:
	return bool(sim._connection_open[DOOR])


# --- 1: THE BASIC VERB -------------------------------------------------------------------------

func test_shooting_a_switch_fires_its_authored_effects() -> void:
	_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])
	assert_false(_open(), "sanity: the door starts shut")
	var events: Array[Event] = _shoot()
	assert_true(_kinds(events).has("switch_activated"), "the shot must activate it")
	assert_true(_open(), "and the authored effect must have landed")


## IT SURVIVES. That is the entire reason this is not a breakable.
func test_the_switch_persists_after_activation() -> void:
	_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])
	_shoot()
	assert_true(sim._hit_switches.has(SWITCH), "a switch is not consumed by being used")


func test_an_unrelated_impact_does_nothing() -> void:
	_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])
	# Fired the other way, at nothing.
	var events: Array[Event] = sim.tick(
		[Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(-1, 0, 0)})] as Array[Command], DT)
	for i in 60:
		events.append_array(sim.tick([] as Array[Command], DT))
	assert_false(_kinds(events).has("switch_activated"), "a shot that misses activates nothing")
	assert_false(_open())


# --- 2: ONE-SHOT vs TOGGLE ---------------------------------------------------------------------

func test_a_one_shot_switch_cannot_refire() -> void:
	_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])
	_shoot()
	assert_true(_open())
	var again: Array[Event] = _shoot()
	assert_false(_kinds(again).has("switch_activated"), "a spent one-shot ignores later hits")
	assert_true(_open(), "and the door it opened stays open")


## THE HUMAN-REQUESTED BEAT: shoot to open, shoot again to close.
func test_a_toggle_switch_flips_the_door_each_time() -> void:
	_switch(&"toggle", [FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, DOOR)])
	_shoot()
	assert_true(_open(), "first activation opens")
	_shoot()
	assert_false(_open(), "second closes")
	_shoot()
	assert_true(_open(), "third opens again")


## EXACTLY ONE TRANSITION PER ACCEPTED ACTIVATION. The hazard named in the ruling is a burst
## flipping open/shut/open during one intended activation.
##
## THE GUARANTEE IS STRUCTURAL, not a cooldown: a shot TERMINATES on the prop it meets, so one
## projectile can never register twice -- and no multi-projectile weapon exists in the model,
## since _spawn_projectile emits exactly one shot per attack and there are no pellets. If a
## spread weapon is ever authored, this is the assumption that has to be revisited, and this
## test is where it will fail.
func test_one_attack_produces_exactly_one_transition() -> void:
	_switch(&"toggle", [FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, DOOR)])
	var events: Array[Event] = _shoot()
	var activations: int = 0
	var transitions: int = 0
	for event in events:
		if event.kind == "switch_activated":
			activations += 1
		if event.kind == "connection_changed":
			transitions += 1
	assert_eq(activations, 1, "one attack, one activation")
	assert_eq(transitions, 1, "one activation, one door transition")


## A projectile is spent on the switch, which is what makes the above structural.
func test_the_shot_is_consumed_by_the_switch() -> void:
	_switch(&"toggle", [FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, DOOR)])
	_shoot()
	assert_eq(sim._projectiles.size(), 0, "the shot does not carry on past the target it triggered")


# --- 3: CONCEALMENT -> REVEAL ------------------------------------------------------------------

## REVEAL IS LITERAL. A hidden switch is a real authored object that is not yet visible, and
## unhiding it is the only thing REVEAL means -- it is not a signalling channel.
func test_a_hidden_switch_cannot_be_hit_until_it_is_revealed() -> void:
	_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)], true)
	var blind: Array[Event] = _shoot()
	assert_false(_kinds(blind).has("switch_activated"), "a hidden switch is in no hit scan")
	assert_false(_open())

	sim._apply_floor_effect(FloorLayers.effect(FloorLayers.EFFECT_REVEAL_SWITCH, SWITCH))
	var seeing: Array[Event] = _shoot()
	assert_true(_kinds(seeing).has("switch_activated"), "once revealed it is an ordinary target")
	assert_true(_open())


## THE COMPOSITION THE FLOOR WANTS: break the cover, and the thing behind it was always there.
func test_breaking_cover_reveals_the_switch_behind_it() -> void:
	_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)], true)
	sim.register_breakable(0, Vector3(-9.0, 0.0, 0.0), 0.7, 5.0)
	sim.register_trigger(0, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, Rect2(), 0, true,
		[FloorLayers.effect(FloorLayers.EFFECT_REVEAL_SWITCH, SWITCH)], true)

	var events: Array[Event] = _shoot()  # the cover is nearer, so it is what the shot meets
	assert_true(_kinds(events).has("breakable_destroyed"), "the cover breaks")
	assert_true(_kinds(events).has("switch_revealed"), "and what it hid becomes real")
	assert_false(_kinds(events).has("switch_activated"),
		"the same shot must not also press it -- that shot was spent on the cover")
	_shoot()
	assert_true(_open(), "a second, deliberate shot presses the switch")


# --- 4: THE SWITCH IS NOT A COMBATANT ----------------------------------------------------------

func test_a_switch_is_absent_from_every_combatant_registry() -> void:
	var health_before: int = sim._health.size()
	var families_before: int = sim._families.size()
	var bodies_before: int = sim._combat_radius.size()
	_switch(&"one_shot", [])
	assert_eq(sim._health.size(), health_before, "registering a switch adds no health")
	assert_eq(sim._families.size(), families_before, "no family")
	assert_eq(sim._combat_radius.size(), bodies_before, "no combat body")
	assert_false(sim.entities.has(SWITCH), "and the sim does not move it")


# --- 5: THE CONNECTION REMAINS AUTHORITATIVE ----------------------------------------------------

## The switch causes the effect; the door owns the state. Movement follows the door, never the
## switch -- which is what "the connection remains authoritative" has to mean mechanically.
func test_movement_follows_the_door_not_the_switch() -> void:
	_switch(&"toggle", [FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, DOOR)])
	assert_false(sim._bounds.is_inside(BEYOND), "shut: the ground beyond is not walkable")
	_shoot()
	assert_true(sim._bounds.is_inside(BEYOND), "open: it is")
	_shoot()
	assert_false(sim._bounds.is_inside(BEYOND), "shut again")


## TOGGLE IS A REAL OPERATION, not two effects in a trench coat: it names no state, so it cannot
## be authored wrongly by a controller that guessed the current one.
func test_toggle_needs_no_knowledge_of_the_current_state() -> void:
	_switch(&"toggle", [FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, DOOR)])
	sim._apply_floor_effect(FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR))
	assert_true(_open(), "sanity: opened by something else entirely")
	_shoot()
	assert_false(_open(), "the switch still flips it, having asked nobody what it was")


# --- 6: EVERY WEAPON OPERATES A SWITCH (ruled 2026-09-04) ---------------------------------------
#
# A switch is a world target, not a gun target. Special-casing a weapon family would make the
# verb "shoot it" rather than "hit it", and the player would have to guess which of their
# weapons the world respects.

func test_a_gun_operates_a_switch() -> void:
	_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])
	_shoot()
	assert_true(_open(), "a projectile weapon must work")


func test_a_melee_weapon_operates_a_switch() -> void:
	_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])
	# Stand within reach of the switch and swing, rather than firing across the room.
	sim.entities[PLAYER] = Vector3(-7.0, 0.0, 0.0)
	sim.register_weapon(&"blade", 12.0, &"force", 3.0, 120.0, 0.0, 0)
	sim.set_equipped_weapon(PLAYER, &"blade")
	var events: Array[Event] = sim.tick(
		[Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT)
	for i in 30:
		events.append_array(sim.tick([] as Array[Command], DT))
	assert_true(_kinds(events).has("switch_activated"), "a melee swing must work too")
	assert_true(_open())


## THE SHARED FACT: the switch is reached through the same detection every world prop uses, so
## any attack that can strike a crate can operate it. This asserts the property rather than the
## two examples, so a third weapon class cannot arrive and quietly not work.
func test_a_switch_and_a_crate_answer_to_the_same_attacks() -> void:
	for melee: bool in [true, false]:
		before_each()
		_switch(&"one_shot", [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, DOOR)])
		sim.register_breakable(9, Vector3(-5.0, 0.0, 3.0), 0.7, 1.0)
		if melee:
			sim.entities[PLAYER] = Vector3(-7.0, 0.0, 0.0)
			sim.register_weapon(&"blade", 12.0, &"force", 3.0, 120.0, 0.0, 0)
			sim.set_equipped_weapon(PLAYER, &"blade")
		var events: Array[Event] = sim.tick(
			[Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT)
		for i in 60:
			events.append_array(sim.tick([] as Array[Command], DT))
		assert_true(_kinds(events).has("switch_activated"),
			"%s must operate a world switch" % ("melee" if melee else "ranged"))


## ONE ATTACK IS ONE FLIP, FOR MELEE TOO. The projectile half of this was already pinned; the
## melee path only started working when the cone test was fixed, so it needs its own proof that
## a single swing does not flip a toggle twice.
func test_one_melee_swing_produces_exactly_one_transition() -> void:
	_switch(&"toggle", [FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, DOOR)])
	sim.entities[PLAYER] = Vector3(-7.0, 0.0, 0.0)
	sim.register_weapon(&"blade", 12.0, &"force", 3.0, 120.0, 0.0, 0)
	sim.set_equipped_weapon(PLAYER, &"blade")
	var events: Array[Event] = sim.tick(
		[Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT)
	for i in 40:
		events.append_array(sim.tick([] as Array[Command], DT))
	var activations: int = 0
	var transitions: int = 0
	for event in events:
		if event.kind == "switch_activated":
			activations += 1
		if event.kind == "connection_changed":
			transitions += 1
	assert_eq(activations, 1, "one swing, one activation")
	assert_eq(transitions, 1, "one activation, one door transition")
	assert_true(_open(), "and it left the door in the flipped state, not back where it started")
