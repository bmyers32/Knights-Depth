extends GutTest
## ROOM OWNERSHIP AND ENCOUNTER LAW (M2 multi-room slice).
##
## Three notions of "where may this actor be" that must never merge:
##   FLOOR WALKABILITY  permanent, the union of every room and aperture rect
##   ROOM OWNERSHIP     permanent for an enemy's lifetime, unconditional
##   ENCOUNTER LOCK     temporary, seals the Envoy in while a fight runs
## _bounds is never mutated to express the latter two. This file is what proves that the
## per-actor resolution actually implements all three.
##
## SYNTHETIC FIXTURE GEOMETRY -- mechanical law only, never shipped tuning.

const PLAYER_ID := 0
const ENEMY_A := 1
const ENEMY_B := 2
const DT := 1.0 / 30.0

## A two-room floor: ENTRY at +Z, COMBAT at -Z, joined by an aperture that overlaps both.
##   entry   x[-6, 6]  z[-10,  0]
##   combat  x[-10,10] z[-36,-16]
##   gap     z[-16, -10] plus 1.5 of overlap into each room
const ENTRY_RECT := Rect2(-6.0, -10.0, 12.0, 10.0)
const COMBAT_RECT := Rect2(-10.0, -36.0, 20.0, 20.0)
const APERTURE := Rect2(-2.5, -17.5, 5.0, 9.0)  # z[-17.5, -8.5]: 1.5 into each room
const ENTRY_ROOM := 0
const COMBAT_ROOM := 1

var sim: SimWorld


func _floor_bounds() -> WalkableBounds:
	var rects: Array[Rect2] = [ENTRY_RECT, COMBAT_RECT, APERTURE]
	return WalkableBounds.new(rects)


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(PLAYER_ID, Vector3(0.0, 0.0, -5.0), 6.0)
	sim.register_combatant(PLAYER_ID, 500.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(PLAYER_ID)
	sim.load_floor(_floor_bounds(), Vector3(0.0, 0.0, -5.0))
	sim.register_room(ENTRY_ROOM, &"entry", ENTRY_RECT)
	sim.register_room(COMBAT_ROOM, &"combat", COMBAT_RECT)


func _add_enemy(actor_id: int, position: Vector3, room_id: int = COMBAT_ROOM) -> void:
	sim.add_entity(actor_id, position, 3.0)
	sim.register_combatant(actor_id, 100.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 0)
	sim.register_ai(actor_id, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 6),
		position, 1.5, 0.0, 60.0, 500.0)
	assert_true(sim.assign_actor_room(actor_id, room_id), "sanity: the enemy was accepted into room %d" % room_id)


func _walk(direction: Vector3, ticks: int) -> void:
	for i in ticks:
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": direction})] as Array[Command], DT)


func _in(rect: Rect2, actor_id: int) -> bool:
	var position: Vector3 = sim.entities[actor_id]
	return position.x >= rect.position.x and position.x <= rect.end.x \
			and position.z >= rect.position.y and position.z <= rect.end.y


# --- ROOM OWNERSHIP: ALWAYS, not lock-scoped -----------------------------------------

## The ruling in its strongest form: confinement does NOT depend on encounter state. A
## dormant room's Fang, forcibly aggroed and given hundreds of ticks, must still not follow
## the player out into the corridor.
func test_an_enemy_never_leaves_its_room_even_when_unsealed_and_aggroed() -> void:
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -30.0))
	sim.debug_set_ai_active(ENEMY_A)
	# Force the encounter to be irrelevant: mark it cleared so no lock exists at all.
	sim._encounter_state[COMBAT_ROOM] = "cleared"

	for i in 600:
		sim.tick([] as Array[Command], DT)
	assert_true(_in(COMBAT_RECT, ENEMY_A),
		"the Fang left its room at %s -- confinement must not be conditional on a lock" % sim.entities[ENEMY_A])


func test_room_confinement_binds_knockback_not_only_locomotion() -> void:
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -17.0))  # just inside the combat room's +Z edge
	sim.register_weapon(&"test_shove", 5.0, &"force", 4.0, 90.0, 12.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"test_shove")
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, -20.0)

	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, 1)})] as Array[Command], DT)

	assert_lt(sim._health[ENEMY_A], 100.0, "sanity: the hit landed")
	assert_true(_in(COMBAT_RECT, ENEMY_A),
		"12 units of knockback pushed the Fang out of its room to %s -- displacement INFLICTED on an actor obeys ownership too" % sim.entities[ENEMY_A])


func test_assigning_an_actor_to_a_room_it_is_not_standing_in_fails_loudly() -> void:
	sim.add_entity(ENEMY_A, Vector3(0.0, 0.0, -5.0), 3.0)  # in ENTRY, not COMBAT
	assert_false(sim.assign_actor_room(ENEMY_A, COMBAT_ROOM), "the refusal must reach the caller")
	assert_false(sim._actor_room.has(ENEMY_A), "and must bind nothing")
	assert_push_error("is not inside room", "silently accepting it would leave a permanently stuck actor")


# --- DORMANT ROSTERS DO NOT AGGRO ----------------------------------------------------

## Ruled: no line-of-sight model. A dormant room's roster ignores a player loitering in the
## doorway; crossing INTO the room is what starts the fight.
func test_a_dormant_roster_ignores_a_player_standing_in_the_open_doorway() -> void:
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -19.0))  # well inside detection_radius of the door
	var start: Vector3 = sim.entities[ENEMY_A]
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, -13.0)  # in the corridor, outside the room

	for i in 200:
		sim.tick([] as Array[Command], DT)

	assert_eq(sim._encounter_state[COMBAT_ROOM], "dormant", "loitering outside must not start the fight")
	assert_almost_eq(sim.entities[ENEMY_A].distance_to(start), 0.0, 0.001,
		"a dormant Fang must not have moved -- that would be aggro through a doorway")


## Gated on ENCOUNTER STATE, not on _ai_state: debug_force_aggro writes _ai_state directly, and
## a debug hook must not be able to repeal a design law.
func test_debug_force_aggro_cannot_repeal_the_dormant_rule() -> void:
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -19.0))
	sim.debug_set_ai_active(ENEMY_A)
	var start: Vector3 = sim.entities[ENEMY_A]
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, -13.0)

	for i in 200:
		sim.tick([] as Array[Command], DT)
	assert_almost_eq(sim.entities[ENEMY_A].distance_to(start), 0.0, 0.001,
		"a force-aggroed but DORMANT roster must still stay asleep")


# --- ACTIVATION ----------------------------------------------------------------------

func test_entering_the_room_activates_the_encounter_and_wakes_the_roster() -> void:
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -30.0))
	var events: Array[Event] = []
	_walk(Vector3(0, 0, -1), 5)
	for i in 200:
		events.append_array(sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3(0, 0, -1)})] as Array[Command], DT))
		if sim._encounter_state[COMBAT_ROOM] == "active":
			break

	assert_eq(sim._encounter_state[COMBAT_ROOM], "active", "crossing into the room must seal it")
	var activated: bool = false
	for event in events:
		if event.kind == "encounter_activated" and int(event.payload["room_id"]) == COMBAT_ROOM:
			activated = true
	assert_true(activated, "and must announce it, or presentation can never draw the gate")
	assert_eq(sim._ai_state[ENEMY_A], "active", "activation is what wakes the roster")


## THE THRESHOLD CASE, called out explicitly in the ruling. Activation must not shrink the
## combat space or snap an actor away from the doorway. It cannot, by construction: the
## aperture overlaps the room, so a player standing in the threshold is already inside the
## ROOM rect, which covers their half of the aperture.
func test_activation_while_crossing_the_threshold_never_snaps_the_envoy() -> void:
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -30.0))
	# Stand exactly in the overlap strip: inside BOTH the aperture and the combat room.
	var threshold := Vector3(0.0, 0.0, COMBAT_RECT.end.y - 0.5)
	assert_true(APERTURE.has_point(Vector2(threshold.x, threshold.z)), "sanity: the fixture point is in the aperture")
	assert_true(COMBAT_RECT.has_point(Vector2(threshold.x, threshold.z)), "sanity: and in the combat room")
	sim.entities[PLAYER_ID] = threshold

	sim.tick([] as Array[Command], DT)

	assert_eq(sim._encounter_state[COMBAT_ROOM], "active", "standing in the threshold counts as entering")
	assert_eq(sim.entities[PLAYER_ID], threshold, "the Envoy must not be moved by the seal closing around them")
	# And the ground under their feet is still legal afterwards.
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3.ZERO})] as Array[Command], DT)
	assert_eq(sim.entities[PLAYER_ID], threshold, "nor on the tick after")


func test_the_sealed_envoy_cannot_walk_back_out_through_the_closed_connection() -> void:
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -30.0))
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, -20.0)
	sim.tick([] as Array[Command], DT)
	assert_eq(sim._encounter_state[COMBAT_ROOM], "active", "sanity: sealed")

	_walk(Vector3(0, 0, 1), 300)
	assert_true(_in(COMBAT_RECT, PLAYER_ID), "the Envoy escaped the seal to %s" % sim.entities[PLAYER_ID])
	assert_almost_eq(sim.entities[PLAYER_ID].z, COMBAT_RECT.end.y, 0.001, "and should be pressed against its +Z edge")


func test_only_one_encounter_is_ever_sealed_at_a_time() -> void:
	sim.register_room(2, &"combat", Rect2(-10.0, -60.0, 20.0, 20.0))
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -30.0))
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, -20.0)
	sim.tick([] as Array[Command], DT)
	assert_eq(sim.debug_describe_encounters()["active_lock"], COMBAT_ROOM)
	assert_eq(sim._encounter_state[2], "dormant", "a second combat room must stay dormant while one is live")


# --- CLEARING ------------------------------------------------------------------------

func test_the_room_clears_only_when_every_roster_member_is_dead() -> void:
	_add_enemy(ENEMY_A, Vector3(-4.0, 0.0, -30.0))
	_add_enemy(ENEMY_B, Vector3(4.0, 0.0, -30.0))
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, -20.0)
	sim.tick([] as Array[Command], DT)
	assert_eq(sim._encounter_state[COMBAT_ROOM], "active", "sanity: sealed")

	sim.debug_override_health(ENEMY_A, 0.0)
	sim.tick([] as Array[Command], DT)
	assert_eq(sim._encounter_state[COMBAT_ROOM], "active", "one survivor keeps the room sealed")

	sim.debug_override_health(ENEMY_B, 0.0)
	var events: Array[Event] = sim.tick([] as Array[Command], DT)
	assert_eq(sim._encounter_state[COMBAT_ROOM], "cleared")
	assert_eq(sim.debug_describe_encounters()["active_lock"], -1, "the lock must lift")
	var cleared: bool = false
	for event in events:
		if event.kind == "encounter_cleared" and int(event.payload["room_id"]) == COMBAT_ROOM:
			cleared = true
	assert_true(cleared, "clearing must announce itself so the gates can reopen")


## BURROW vs FLOOR TRANSITION, the distinction stated in the ruling: burrow is temporary
## non-participation INSIDE an encounter. A burrowed Fang is ALIVE, so it still counts, and
## the room must not clear while it is underground.
func test_a_burrowed_fang_is_alive_and_keeps_its_room_sealed() -> void:
	sim.add_entity(ENEMY_A, Vector3(0.0, 0.0, -30.0), 3.0)
	sim.register_combatant(ENEMY_A, 100.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY_A, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 10000),
		Vector3(0.0, 0.0, -30.0), 1.5, 0.0, 60.0, 500.0, 0, 0,
		2.0, 0.5, 20, 2.0, 30, 6, 30)
	assert_true(sim.assign_actor_room(ENEMY_A, COMBAT_ROOM))
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, -20.0)
	sim.tick([] as Array[Command], DT)
	assert_eq(sim._encounter_state[COMBAT_ROOM], "active", "sanity: sealed")

	assert_true(sim.debug_trigger_burrow(ENEMY_A, PLAYER_ID), "sanity: the burrow triggered")
	var went_absent: bool = false
	for i in 40:
		sim.tick([] as Array[Command], DT)
		if sim._combat_absent.has(ENEMY_A):
			went_absent = true
			break
	assert_true(went_absent, "sanity: it submerged")
	assert_eq(sim._encounter_state[COMBAT_ROOM], "active",
		"a combat-ABSENT actor is still ALIVE -- an underground Fang must not clear the room")


## Emergence is placement, and placement honours ownership: a Fang cannot surface outside the
## room that owns it, even if a candidate point would be legal floor elsewhere.
func test_a_burrowing_fang_never_surfaces_outside_its_own_room() -> void:
	sim.add_entity(ENEMY_A, Vector3(0.0, 0.0, -18.0), 3.0)
	sim.register_combatant(ENEMY_A, 100.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY_A, CombatTestHelpers.single_action_repertoire(&"test_bite", 1.5, 10000),
		Vector3(0.0, 0.0, -18.0), 1.5, 0.0, 60.0, 500.0, 0, 0,
		2.0, 0.5, 6, 2.0, 60, 6, 30)
	assert_true(sim.assign_actor_room(ENEMY_A, COMBAT_ROOM))
	# Player right at the room's +Z lip, so the far-side emergence candidates point out of it.
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, COMBAT_RECT.end.y - 0.5)
	sim.tick([] as Array[Command], DT)

	assert_true(sim.debug_trigger_burrow(ENEMY_A, PLAYER_ID), "sanity: triggered")
	for i in 200:
		sim.tick([] as Array[Command], DT)
		assert_true(_in(COMBAT_RECT, ENEMY_A) or sim._combat_absent.has(ENEMY_A),
			"the Fang surfaced outside its room at %s" % sim.entities[ENEMY_A])
		if not sim._combat_absent.has(ENEMY_A) and sim._burrow.has(ENEMY_A):
			break
	assert_true(_in(COMBAT_RECT, ENEMY_A), "final position must be inside the owning room")


# --- SCOPE ---------------------------------------------------------------------------

func test_all_room_and_encounter_state_dies_with_the_floor() -> void:
	_add_enemy(ENEMY_A, Vector3(0.0, 0.0, -30.0))
	sim.entities[PLAYER_ID] = Vector3(0.0, 0.0, -20.0)
	sim.tick([] as Array[Command], DT)
	assert_eq(sim.debug_describe_encounters()["active_lock"], COMBAT_ROOM, "sanity: an encounter is live")

	var rects: Array[Rect2] = [Rect2(-5.0, -5.0, 10.0, 10.0)]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)

	assert_eq(sim.debug_describe_encounters()["active_lock"], -1, "a new floor must not inherit a lock")
	assert_eq(sim._rooms.size(), 0, "nor its rooms")
	assert_eq(sim._encounter_state.size(), 0, "nor its encounter progress")
	assert_eq(sim._actor_room.size(), 0, "nor who owned whom")
	assert_false(sim.entities.has(ENEMY_A), "nor the actors themselves")
