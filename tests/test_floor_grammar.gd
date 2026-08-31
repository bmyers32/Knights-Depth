extends GutTest
## FLOOR GRAMMAR at the sim level: connections, triggers, effects, interaction, encounters.
## Replaces test_room_encounters.gd, whose parent abstraction (rooms) was falsified by play.
##
## The laws under test:
##   - THE GATE DOES NOT KNOW WHY IT OPENED. Controllers write connection state; the connection
##     holds availability and nothing else.
##   - ONE INTERACTABLE, MANY ATOMIC EFFECTS. A trigger's whole list lands in one tick.
##   - ACTIVATION IS AUTHORED. Entering a region never starts a fight by itself.
##   - TERRITORY IS UNCONDITIONAL. An enemy never leaves its site, ambient or not.
##
## SYNTHETIC FIXTURE GEOMETRY -- mechanical law only, never shipped tuning.

const PLAYER := 0
const ENEMY_A := 1
const ENEMY_B := 2
const DT := 1.0 / 30.0

## Two patches with a gap, joined by one aperture that overlaps both.
const WEST := Rect2(-20.0, -10.0, 16.0, 20.0)   # x[-20,-4]  z[-10,10]
const EAST := Rect2(4.0, -10.0, 16.0, 20.0)     # x[4,20]    z[-10,10]
const DOOR := Rect2(-5.5, -2.0, 11.0, 4.0)      # x[-5.5,5.5] overlaps both by 1.5
const CONNECTION := 0
const ENCOUNTER := 0

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(PLAYER, Vector3(-12.0, 0.0, 0.0), 6.0)
	sim.register_combatant(PLAYER, 5000.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.load_floor(WalkableBounds.new([WEST, EAST, DOOR] as Array[Rect2]), Vector3(-12.0, 0.0, 0.0))
	var patches: Array[Rect2] = [WEST, EAST]
	sim.register_patches(patches)
	sim.register_connection(CONNECTION, DOOR, true)


func _walk(direction: Vector3, ticks: int) -> void:
	for i in ticks:
		sim.tick([Command.new(sim.tick_count, PLAYER, "move", {"direction": direction})] as Array[Command], DT)


func _tick(count: int = 1) -> Array[Event]:
	var events: Array[Event] = []
	for i in count:
		events.append_array(sim.tick([] as Array[Command], DT))
	return events


func _in(rect: Rect2, actor_id: int) -> bool:
	var p: Vector3 = sim.entities[actor_id]
	return p.x >= rect.position.x and p.x <= rect.end.x and p.z >= rect.position.y and p.z <= rect.end.y


func _effect(kind: StringName, target: int) -> Dictionary:
	return {"kind": kind, "target_id": target}


# --- CONNECTIONS: availability, ignorant of cause ---------------------------------------

func test_an_open_connection_lets_an_actor_cross_between_patches() -> void:
	_walk(Vector3(1, 0, 0), 200)
	assert_true(_in(EAST, PLAYER), "an open route must be walkable, got %s" % sim.entities[PLAYER])


func test_a_blocked_connection_is_a_real_wall_not_a_picture() -> void:
	sim.register_connection(CONNECTION, DOOR, false)
	_walk(Vector3(1, 0, 0), 200)
	assert_true(_in(WEST, PLAYER), "a closed route must actually stop the Envoy, got %s" % sim.entities[PLAYER])
	# The Envoy's BODY stops at the sealed edge, so its centre rests one radius short of it.
	assert_almost_eq(sim.entities[PLAYER].x, WEST.end.x - 0.4, 0.0001, "and stop their body at its edge")


# --- OCCUPANCY: STANDING ON SOMETHING, WHICH IS NOT THE SAME AS FITTING THERE -------------

## THE ANCHOR/BODY SPLIT (ruled). Occupancy asks "is this actor STANDING here"; legality asks
## "does this actor's BODY fit here". Merging them would let a wide actor operate a plate it
## never stepped onto -- and would make plate size depend on who walks over it.
func test_occupancy_is_an_anchor_question_not_a_body_question() -> void:
	var plate := Rect2(-1.0, -1.0, 2.0, 2.0)
	assert_true(WalkableBounds.contains(plate, 0.9, 0.0), "an anchor inside the plate is standing on it")
	assert_false(WalkableBounds.contains(plate, 1.6, 0.0),
		"an anchor outside it is not, however wide the body grazing it may be")


## THE FAR-EDGE TRAP, closed. Rect2.has_point is EXCLUSIVE on the far edge while
## WalkableBounds.is_inside is INCLUSIVE, so an actor clamped exactly onto a boundary read as
## "escaped" to one predicate and "legal" to the other. Every occupancy consumer now routes
## through the one shared inclusive helper.
func test_the_shared_containment_helper_is_inclusive_on_every_edge() -> void:
	var region := Rect2(0.0, 0.0, 4.0, 4.0)
	assert_true(WalkableBounds.contains(region, 4.0, 4.0), "the far corner counts as inside")
	assert_true(WalkableBounds.contains(region, 0.0, 0.0), "so does the near one")
	assert_false(region.has_point(Vector2(4.0, 4.0)),
		"sanity: Rect2.has_point disagrees, which is exactly why nothing may use it for occupancy")


# --- THE PARTY PLATE ----------------------------------------------------------------------

func _plate(effects: Array[Dictionary]) -> void:
	sim.register_trigger(9, FloorLayers.TRIGGER_GROUP_OCCUPANCY, Rect2(-14.0, -2.0, 4.0, 4.0), -1, true, effects)


## Solo resolves to one Envoy with no special case: the condition is "every living party
## member", and a party of one is satisfied by one.
func test_a_solo_envoy_standing_on_the_plate_fires_it() -> void:
	sim.register_connection(CONNECTION, DOOR, false)
	_plate([FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, CONNECTION)])
	sim.entities[PLAYER] = Vector3(-12.0, 0.0, 0.0)
	sim.tick([] as Array[Command], DT)
	assert_true(bool(sim._connection_open[CONNECTION]), "standing on it is the whole activation")


## THE DENOMINATOR IS THE EXPEDITION, NOT THE ROOM. A subset of the party must never be able to
## commit everyone to the fight while a teammate is still outside.
func test_a_partial_party_cannot_fire_the_plate() -> void:
	sim.add_entity(ENEMY_B, Vector3(-12.0, 0.0, 8.0), 6.0)
	sim.register_combatant(ENEMY_B, 500.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(ENEMY_B)
	sim.register_connection(CONNECTION, DOOR, false)
	_plate([FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, CONNECTION)])

	sim.entities[PLAYER] = Vector3(-12.0, 0.0, 0.0)
	sim.tick([] as Array[Command], DT)
	assert_false(bool(sim._connection_open[CONNECTION]), "one member standing on it is not the party")

	sim.entities[ENEMY_B] = Vector3(-12.5, 0.0, 0.0)
	sim.tick([] as Array[Command], DT)
	assert_true(bool(sim._connection_open[CONNECTION]), "the whole party on it together is")


## EDGE-TRIGGERED. A plate everybody is still standing on must not re-fire every tick -- which
## is what would happen if occupancy were read as a level rather than as a transition.
func test_the_plate_fires_on_the_edge_and_not_every_tick() -> void:
	_plate([FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, CONNECTION)])
	sim.entities[PLAYER] = Vector3(-12.0, 0.0, 0.0)
	var fired: int = 0
	for i in 30:
		for event in sim.tick([] as Array[Command], DT):
			if event.kind == "floor_trigger_fired":
				fired += 1
	assert_eq(fired, 1, "standing still fires once, not thirty times")


## THE LAW ITSELF: the connection is changed by an EFFECT and never learns what caused it.
## Three different controllers reach it identically.
func test_any_controller_opens_a_connection_the_same_way() -> void:
	for controller in ["region", "group_occupancy", "breakable", "encounter"]:
		sim = SimWorld.new()
		sim.add_entity(PLAYER, Vector3(-12.0, 0.0, 0.0), 6.0)
		sim.register_combatant(PLAYER, 5000.0, &"envoy", 0, 0.4, &"player")
		sim.mark_run_persistent(PLAYER)
		sim.load_floor(WalkableBounds.new([WEST, EAST] as Array[Rect2]), Vector3(-12.0, 0.0, 0.0))
		sim.register_patches([WEST, EAST] as Array[Rect2])
		sim.register_connection(CONNECTION, DOOR, false)
		var effects: Array = [_effect(FloorLayers.EFFECT_OPEN_CONNECTION, CONNECTION)]
		match controller:
			"region":
				sim.register_trigger(0, FloorLayers.TRIGGER_REGION, Rect2(-14.0, -2.0, 4.0, 4.0), -1, true, effects)
				_tick(2)
			"group_occupancy":
				sim.register_trigger(0, FloorLayers.TRIGGER_GROUP_OCCUPANCY, Rect2(-14.0, -2.0, 4.0, 4.0), -1, true, effects)
				_tick(2)
			"breakable":
				sim.register_breakable(0, Vector3(-12.0, 0.0, 0.0), 0.5, 1.0)
				sim.register_trigger(0, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, Rect2(), 0, true, effects)
				sim._resolve_hit_on_breakable(PLAYER, 0, 99.0)
			"encounter":
				sim.register_encounter(ENCOUNTER, [WEST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, false)
				sim.register_trigger(0, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, Rect2(), ENCOUNTER, true, effects)
				sim._activate_encounter(ENCOUNTER)
				_tick(2)
		assert_true(bool(sim._connection_open[CONNECTION]),
			"a '%s' controller must open the connection through exactly the same effect" % controller)


func test_a_one_shot_region_trigger_commits_the_player_forward() -> void:
	sim.register_trigger(0, FloorLayers.TRIGGER_REGION, EAST, -1, true,
		[_effect(FloorLayers.EFFECT_BLOCK_CONNECTION, CONNECTION)])
	_walk(Vector3(1, 0, 0), 120)
	assert_true(_in(EAST, PLAYER), "sanity: the Envoy crossed before the seal")
	assert_false(bool(sim._connection_open[CONNECTION]), "crossing must seal the way back")
	_walk(Vector3(-1, 0, 0), 200)
	assert_true(_in(EAST, PLAYER), "and the commitment must hold, got %s" % sim.entities[PLAYER])


# --- ATOMIC EFFECTS ---------------------------------------------------------------------

## The party-plate shape: seal the rear, open the way forward, start the fight -- one record,
## one tick, never observed half-applied.
func test_one_controller_applies_every_effect_atomically() -> void:
	sim.register_connection(1, Rect2(30.0, -2.0, 4.0, 4.0), false)
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	# A LIVING ROSTER, because activation and the clear check share one tick: an empty site is
	# activated and immediately cleared, which would test the opposite of what this is about.
	_add_enemy(ENEMY_A, Vector3(12.0, 0.0, 0.0))
	sim.register_trigger(0, FloorLayers.TRIGGER_GROUP_OCCUPANCY, Rect2(-14.0, -2.0, 4.0, 4.0), -1, true, [
		_effect(FloorLayers.EFFECT_BLOCK_CONNECTION, CONNECTION),
		_effect(FloorLayers.EFFECT_OPEN_CONNECTION, 1),
		_effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, ENCOUNTER),
	])

	var events: Array[Event] = sim.tick([] as Array[Command], DT)

	assert_false(bool(sim._connection_open[CONNECTION]), "rear sealed")
	assert_true(bool(sim._connection_open[1]), "forward opened")
	assert_eq(sim._encounter_state[ENCOUNTER], "active", "fight started")
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	assert_true(kinds.has("floor_trigger_fired"), "the trigger announces itself")
	assert_true(kinds.has("encounter_activated"), "and every consequence lands in the same tick")


func test_a_once_trigger_never_fires_twice() -> void:
	sim.register_trigger(0, FloorLayers.TRIGGER_REGION, WEST, -1, true,
		[_effect(FloorLayers.EFFECT_BLOCK_CONNECTION, CONNECTION)])
	_tick(2)
	assert_false(bool(sim._connection_open[CONNECTION]), "sanity: fired once")
	sim._connection_open[CONNECTION] = true
	sim._rebuild_regions()
	_tick(5)
	assert_true(bool(sim._connection_open[CONNECTION]), "a spent one-shot must never fire again")


# --- DORMANT CONTROLLERS: concealment without a press ------------------------------------

## CONCEALMENT IS NOW A DISABLED TRIGGER, not a hidden interactable. The plate exists in the
## plan from the start; breaking what hid it turns it on.
func test_a_dormant_plate_cannot_fire_until_it_is_enabled() -> void:
	sim.register_trigger(0, FloorLayers.TRIGGER_REGION, WEST, -1, true,
		[_effect(FloorLayers.EFFECT_OPEN_CONNECTION, CONNECTION)], false)
	sim.register_connection(CONNECTION, DOOR, false)
	_tick(5)
	assert_false(bool(sim._connection_open[CONNECTION]),
		"a dormant controller must not fire, however long the Envoy stands on it")

	var events: Array[Event] = sim._apply_floor_effect(_effect(FloorLayers.EFFECT_ENABLE_TRIGGER, 0))
	assert_eq(events[0].kind, "floor_trigger_enabled", "enabling announces itself")
	_tick(2)
	assert_true(bool(sim._connection_open[CONNECTION]), "and then it fires on the occupancy it always had")


## A dormant trigger must not BANK the edge it could not act on -- otherwise revealing a plate
## under an Envoy already standing on it would arm a transition that never happens.
func test_a_dormant_trigger_banks_no_occupancy_edge_while_it_waits() -> void:
	sim.register_trigger(0, FloorLayers.TRIGGER_REGION, WEST, -1, true,
		[_effect(FloorLayers.EFFECT_OPEN_CONNECTION, CONNECTION)], false)
	sim.register_connection(CONNECTION, DOOR, false)
	_tick(10)  # the Envoy stands on it the whole time, disabled
	sim._apply_floor_effect(_effect(FloorLayers.EFFECT_ENABLE_TRIGGER, 0))
	_tick(2)
	assert_true(bool(sim._connection_open[CONNECTION]),
		"revealed under someone already standing there, it must still fire")


# --- ENCOUNTERS -------------------------------------------------------------------------

func _add_enemy(actor_id: int, position: Vector3, encounter_id: int = ENCOUNTER) -> void:
	sim.add_entity(actor_id, position, 3.0)
	sim.register_combatant(actor_id, 100.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 0)
	sim.register_ai(actor_id, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 6),
		position, 1.5, 0.0, 60.0, 500.0)
	assert_true(sim.assign_actor_encounter(actor_id, encounter_id), "sanity: accepted into its site")


## THE FALSIFIED RULE, made unrepresentable: walking into an encounter region does nothing.
func test_entering_an_encounter_region_does_not_start_the_fight() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	_add_enemy(ENEMY_A, Vector3(16.0, 0.0, 0.0))
	_walk(Vector3(1, 0, 0), 200)
	assert_true(_in(EAST, PLAYER), "sanity: the Envoy is standing in the region")
	assert_eq(sim._encounter_state[ENCOUNTER], "dormant", "arrival alone must never start a fight")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1, "and nothing is sealed")


func test_activation_is_an_authored_effect_and_seals_both_sides() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	_add_enemy(ENEMY_A, Vector3(16.0, 0.0, 0.0))
	_walk(Vector3(1, 0, 0), 200)
	sim._activate_encounter(ENCOUNTER)
	assert_eq(sim._encounter_state[ENCOUNTER], "active")

	_walk(Vector3(-1, 0, 0), 300)
	assert_true(_in(EAST, PLAYER), "the Envoy escaped a sealed encounter to %s" % sim.entities[PLAYER])
	for i in 300:
		_tick()
	assert_true(_in(EAST, ENEMY_A), "and the roster is sealed in with them")


func test_a_dormant_roster_never_perceives_the_player() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	_add_enemy(ENEMY_A, Vector3(6.0, 0.0, 0.0))
	var start: Vector3 = sim.entities[ENEMY_A]
	sim.entities[PLAYER] = Vector3(4.5, 0.0, 0.0)  # right on its doorstep
	_tick(200)
	assert_almost_eq(sim.entities[ENEMY_A].distance_to(start), 0.0, 0.001,
		"a dormant roster must not react at all -- no line-of-sight model exists")


## Gated on ENCOUNTER STATE, not _ai_state, so a debug hook cannot repeal a design law.
func test_debug_force_aggro_cannot_wake_a_dormant_roster() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	_add_enemy(ENEMY_A, Vector3(6.0, 0.0, 0.0))
	sim.debug_set_ai_active(ENEMY_A)
	var start: Vector3 = sim.entities[ENEMY_A]
	sim.entities[PLAYER] = Vector3(4.5, 0.0, 0.0)
	_tick(200)
	assert_almost_eq(sim.entities[ENEMY_A].distance_to(start), 0.0, 0.001, "still asleep")


## AMBIENT: no ceremony, no lock, engages naturally -- but still bounded by its territory.
func test_an_ambient_roster_engages_without_ceremony_and_stays_in_its_territory() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_AMBIENT, false)
	_add_enemy(ENEMY_A, Vector3(6.0, 0.0, 0.0))
	assert_false(sim._encounter_state.has(ENCOUNTER), "an ambient site has no dormant/active life")

	sim.entities[PLAYER] = Vector3(8.0, 0.0, 0.0)
	_tick(120)
	assert_ne(sim.entities[ENEMY_A], Vector3(6.0, 0.0, 0.0), "an ambient enemy engages on its own")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1, "and never seals the player in")

	# Now lead it away: it must refuse to follow out of its territory.
	sim.entities[PLAYER] = Vector3(-12.0, 0.0, 0.0)
	_tick(400)
	assert_true(_in(EAST, ENEMY_A), "ambient does NOT mean whole-floor roaming, got %s" % sim.entities[ENEMY_A])


## DELIBERATELY REWRITTEN 2026-08-31 (territory split). This test previously asserted that an
## AMBIENT territory binds knockback. That law was overturned by evidence: a behavioural leash
## acting as a hard clamp is an invisible wall in walkable floor, and a player shield-bumping an
## Ooze saw it wedge against nothing. The ORIGINAL INTENT -- "forced displacement is not exempt
## from confinement" -- is preserved and now asserted against the confinement that is genuinely
## HARD. The ambient half moved to test_territory_semantics.gd, where it asserts the opposite.
func test_a_hard_seal_binds_knockback_not_only_locomotion() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	_add_enemy(ENEMY_A, Vector3(5.0, 0.0, 0.0))
	sim.register_weapon(&"test_shove", 5.0, &"force", 4.0, 90.0, 12.0, 0)
	sim.set_equipped_weapon(PLAYER, &"test_shove")
	sim.entities[PLAYER] = Vector3(8.0, 0.0, 0.0)
	sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(-1, 0, 0)})] as Array[Command], DT)
	assert_lt(sim._health[ENEMY_A], 100.0, "sanity: the hit landed")
	assert_true(_in(EAST, ENEMY_A), "12 units of knockback pushed it out of a HARD seal to %s" % sim.entities[ENEMY_A])


func test_assigning_an_actor_outside_its_site_fails_loudly() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	sim.add_entity(ENEMY_A, Vector3(-12.0, 0.0, 0.0), 3.0)
	assert_false(sim.assign_actor_encounter(ENEMY_A, ENCOUNTER), "the refusal must reach the caller")
	assert_false(sim._actor_encounter.has(ENEMY_A), "and bind nothing")
	assert_push_error("outside encounter", "silently accepting it would leave a permanently stuck actor")


func test_a_site_clears_only_when_its_whole_roster_is_dead() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	_add_enemy(ENEMY_A, Vector3(8.0, 0.0, 0.0))
	_add_enemy(ENEMY_B, Vector3(14.0, 0.0, 0.0))
	sim._activate_encounter(ENCOUNTER)
	sim.debug_override_health(ENEMY_A, 0.0)
	_tick()
	assert_eq(sim._encounter_state[ENCOUNTER], "active", "one survivor keeps it sealed")
	sim.debug_override_health(ENEMY_B, 0.0)
	_tick()
	assert_eq(sim._encounter_state[ENCOUNTER], "cleared")
	assert_eq(sim.debug_describe_floor()["active_confinement"], -1, "the seal lifts")


func test_clearing_a_site_fires_its_watchers() -> void:
	sim.register_connection(1, Rect2(30.0, -2.0, 4.0, 4.0), false)
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	sim.register_trigger(0, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, Rect2(), ENCOUNTER, true,
		[_effect(FloorLayers.EFFECT_OPEN_CONNECTION, 1)])
	_add_enemy(ENEMY_A, Vector3(8.0, 0.0, 0.0))
	sim._activate_encounter(ENCOUNTER)
	sim.debug_override_health(ENEMY_A, 0.0)
	_tick()
	assert_true(bool(sim._connection_open[1]), "progression must continue past a cleared fight")


## A deferred roster is registered up front but not PRESENT until summoned -- alive,
## untargetable, undrawn. Reuses burrow's participation predicate rather than a second one.
func test_a_deferred_roster_arrives_only_on_activation() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true, false)
	_add_enemy(ENEMY_A, Vector3(8.0, 0.0, 0.0))
	assert_true(sim.debug_is_combat_absent(ENEMY_A), "not present before it is summoned")
	assert_gt(sim._health[ENEMY_A], 0.0, "but alive -- absent is not dead")

	var events: Array[Event] = sim._activate_encounter(ENCOUNTER)
	assert_false(sim.debug_is_combat_absent(ENEMY_A), "activation makes it present")
	assert_true(events[0].payload["actor_ids"].has(ENEMY_A), "and names who arrived, so presentation can mirror it")


## Burrow vs floor state, kept distinct: an underground Fang is ALIVE, so it still counts.
func test_a_burrowed_member_keeps_its_site_sealed() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	sim.add_entity(ENEMY_A, Vector3(12.0, 0.0, 0.0), 3.0)
	sim.register_combatant(ENEMY_A, 100.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY_A, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 10000),
		Vector3(12.0, 0.0, 0.0), 1.5, 0.0, 60.0, 500.0, 0, 0, 2.0, 0.5, 20, 2.0, 30, 6, 30)
	assert_true(sim.assign_actor_encounter(ENEMY_A, ENCOUNTER))
	sim.entities[PLAYER] = Vector3(14.0, 0.0, 0.0)
	sim._activate_encounter(ENCOUNTER)

	assert_true(sim.debug_trigger_burrow(ENEMY_A, PLAYER), "sanity: burrowed")
	var absent: bool = false
	for i in 40:
		_tick()
		if sim.debug_is_combat_absent(ENEMY_A):
			absent = true
			break
	assert_true(absent, "sanity: it submerged")
	assert_eq(sim._encounter_state[ENCOUNTER], "active",
		"a combat-ABSENT member is still ALIVE -- an underground Fang must not clear the site")


# --- SCOPE -------------------------------------------------------------------------------

func test_all_floor_layer_state_dies_with_the_floor() -> void:
	sim.register_encounter(ENCOUNTER, [EAST] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true)
	sim.register_breakable(0, Vector3(-10.0, 0.0, 0.0), 0.8, 1.0)
	sim.register_trigger(0, FloorLayers.TRIGGER_REGION, WEST, -1, true, [])
	_add_enemy(ENEMY_A, Vector3(8.0, 0.0, 0.0))
	sim._activate_encounter(ENCOUNTER)
	_tick()

	sim.load_floor(WalkableBounds.new([Rect2(-5.0, -5.0, 10.0, 10.0)] as Array[Rect2]), Vector3.ZERO)

	assert_eq(sim.debug_describe_floor()["active_confinement"], -1, "a new floor inherits no seal")
	for state_name in ["_connections", "_connection_open", "_triggers", "_triggers_fired",
			"_trigger_enabled", "_breakables", "_encounters", "_encounter_bounds",
			"_encounter_roster", "_encounter_state", "_actor_encounter", "_patch_rects"]:
		assert_eq((sim.get(state_name) as Dictionary if sim.get(state_name) is Dictionary else sim.get(state_name)).size(), 0,
			"%s is FLOOR-scoped and must be empty after a transition" % state_name)
	assert_false(sim.entities.has(ENEMY_A), "nor do the actors survive")


# --- ALL_ACTIVE_ENVOYS_OCCUPY_REGION: one condition, two consumers -----------------------

## The extracted condition itself, asserted directly rather than only through its consumers.
func test_the_group_occupancy_condition_needs_every_living_envoy() -> void:
	var region := Rect2(-14.0, -2.0, 4.0, 4.0)
	sim.entities[PLAYER] = Vector3(-12.0, 0.0, 0.0)
	assert_true(sim.all_active_envoys_occupy(region), "a party of one is satisfied by one")

	sim.add_entity(ENEMY_B, Vector3(18.0, 0.0, 0.0), 6.0)
	sim.register_combatant(ENEMY_B, 500.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(ENEMY_B)
	assert_false(sim.all_active_envoys_occupy(region), "a subset of the party is not the party")

	sim.entities[ENEMY_B] = Vector3(-12.5, 0.0, 0.0)
	assert_true(sim.all_active_envoys_occupy(region), "everyone together satisfies it")


## THE FLOOR EXIT, the condition's second consumer. Effects stay authored separately: the same
## question ("is everyone here?") commits a party to a fight in one place and finishes the floor
## in another.
func test_the_exit_completes_the_floor_from_the_same_condition() -> void:
	sim.register_trigger(0, FloorLayers.TRIGGER_GROUP_OCCUPANCY, WEST, -1, true,
		[_effect(FloorLayers.EFFECT_COMPLETE_FLOOR, -1)])
	assert_false(sim.debug_describe_floor()["floor_complete"], "sanity: not complete on arrival")
	var kinds: Array = []
	for event in sim.tick([] as Array[Command], DT):
		kinds.append(event.kind)
	assert_true(kinds.has("floor_complete"), "standing on the exit together completes the floor")
	assert_true(sim.debug_describe_floor()["floor_complete"], "and it is an authoritative fact, not just an Event")


func test_completing_the_floor_twice_emits_nothing_the_second_time() -> void:
	sim.register_trigger(0, FloorLayers.TRIGGER_GROUP_OCCUPANCY, WEST, -1, false,
		[_effect(FloorLayers.EFFECT_COMPLETE_FLOOR, -1)])
	sim.tick([] as Array[Command], DT)
	var kinds: Array = []
	for i in 5:
		for event in sim.tick([] as Array[Command], DT):
			kinds.append(event.kind)
	assert_false(kinds.has("floor_complete"), "a completed floor completes once")


# --- TERRITORY IS A UNION, NOT A PATCH ----------------------------------------------------

## Confinement was validated and is kept; what human play falsified was the accidental
## assumption that a territory equals exactly ONE patch, which read as an ambient enemy stuck
## on a corner the instant its quarry crossed a seam it was authored to inhabit.
func test_an_ambient_roster_chases_across_its_whole_authored_territory() -> void:
	sim.add_entity(ENEMY_A, Vector3(12.0, 0.0, 0.0), 5.0)
	sim.register_combatant(ENEMY_A, 100.0, &"ooze", 0, 0.5, &"enemy")
	# TWO regions: the east patch it lives in, plus the doorway it is meant to defend.
	sim.register_encounter(ENCOUNTER, [EAST, DOOR] as Array[Rect2], FloorLayers.ROLE_AMBIENT, false)
	assert_true(sim.assign_actor_encounter(ENEMY_A, ENCOUNTER))

	var territory: WalkableBounds = sim._encounter_bounds[ENCOUNTER]
	assert_true(territory.fits(Vector3(4.5, 0.0, 0.0), 0.5), "it may stand in the patch it spawned in")
	assert_true(territory.fits(Vector3(-2.0, 0.0, 0.0), 0.5),
		"and it may cross the seam into the rest of its authored territory")
	assert_false(territory.fits(Vector3(-12.0, 0.0, 0.0), 0.5),
		"but a union is still a territory: it never becomes whole-floor roaming")
