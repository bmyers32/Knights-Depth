extends GutTest
## DOORWAYS, PURSUIT AND BURROW (ruled 2026-09-03, after human play).
##
## THE HUMAN REPRODUCED, in ordinary play: activate the Route A response, retreat through the
## OPEN doorway, and the Watcher could not follow while a burrowing Fang vanished permanently.
##
## ONE ROOT CAUSE UNDER BOTH. Hard roster confinement was keyed to encounter ROLE. The source
## comment was honest that role was only a proxy -- valid because every non-ambient roster
## "activates and seals" -- and it named a mechanical revisit trigger. Floor 2 broke the premise
## a way that trigger could not see: an OPTIONAL, NON-SEALING encounter that activates while
## `confines_player` stays false. The player could leave; the roster was walled in behind an open
## door. The same invisible walls then killed the Fang, whose emergence candidates all ring the
## player and were therefore all illegal placement for it.
##
## SEALING IS NOW THE AUTHORITY. A roster is hard-confined exactly while its own encounter is the
## one actually sealing the player in; everything else leashes.

const DT := 1.0 / 30.0
const PLAYER := 0
const ENEMY := 1
const ENCOUNTER := 0

## Two rooms with a real gap, bridged only by the aperture: a doorway, not a seam.
const SOUTH := Rect2(-10.0, -20.0, 20.0, 12.0)
const NORTH := Rect2(-10.0, -6.0, 20.0, 12.0)
const DOOR := Rect2(-2.5, -9.0, 5.0, 4.0)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [SOUTH, NORTH, DOOR]
	sim.load_floor(WalkableBounds.new(rects), Vector3(0.0, 0.0, -14.0))
	var patches: Array[Rect2] = [SOUTH, NORTH]
	sim.register_patches(patches)
	sim.register_connection(0, DOOR, true)
	sim.add_entity(PLAYER, Vector3(0.0, 0.0, -14.0), 6.0, Vector3(0, 0, 1), 0.45)
	sim.register_combatant(PLAYER, 100000.0, &"envoy", 0, 0.45, &"player")
	sim.mark_run_persistent(PLAYER)


## Puts an enemy in the SOUTH room, bound to an encounter over that room alone.
func _add_enemy(family: StringName, radius: float, at: Vector3, role: StringName, confines: bool) -> void:
	sim.register_encounter(ENCOUNTER, [SOUTH] as Array[Rect2], role, confines, true)
	sim.add_entity(ENEMY, at, 4.0, Vector3(0, 0, 1), radius)
	sim.register_combatant(ENEMY, 500.0, family, 0, radius, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 2.0, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"test_bite", 2.0, 10000),
		at, 2.2, 1.9, 30.0, 60.0, 0, 0, 0.0, 0.0, 0, 0.0, 0, 0, 0, 45)
	assert_true(sim.assign_actor_encounter(ENEMY, ENCOUNTER), "sanity: bound to its site")
	# THE FIGHT IS STARTED, always. A non-ambient encounter registers as DORMANT, and a dormant
	# roster perceives nothing and yields no Commands at all -- the first version of this file
	# left it dormant and read the resulting perfect stillness as "cannot use the door". Both
	# halves of the comparison below therefore activate; only `confines` differs, which is the
	# whole point.
	sim.debug_activate_encounter(ENCOUNTER)
	assert_eq(sim.debug_describe_floor()["active_confinement"], ENCOUNTER if confines else -1,
		"sanity: activation must seal exactly when the encounter says it confines the player")
	sim.debug_set_ai_active(ENEMY)
	# ATTACKS OFF. These tests measure LOCOMOTION through a doorway, and the fixture's authored
	# windup is long enough to lock an actor in place for the whole run -- the first version of
	# this file read a windup-locked enemy as "cannot use the door", which is the same class of
	# instrumentation error as reading an idle actor as a stall.
	sim._next_fire_tick[ENEMY] = 1_000_000


func _run(ticks: int) -> void:
	for i in ticks:
		sim.debug_override_health(PLAYER, 100000.0)
		sim.tick([] as Array[Command], DT)


## Walks the player north, through the doorway, keeping it alive throughout.
func _retreat_through_the_door(ticks: int) -> void:
	for i in ticks:
		sim.debug_override_health(PLAYER, 100000.0)
		var target := Vector3(0.0, 0.0, -2.0)
		var direction: Vector3 = target - sim.entities[PLAYER]
		direction.y = 0.0
		if direction.length() < 0.4:
			sim.tick([] as Array[Command], DT)
			continue
		sim.tick([Command.new(sim.tick_count, PLAYER, "move", {"direction": direction.normalized()})] as Array[Command], DT)


# --- 1: AN OPEN DOOR IS OPEN TO EVERYONE -------------------------------------------------------

## THE EXACT HUMAN FINDING. An unsealed roster must be able to follow the player out.
func test_an_unsealed_roster_can_follow_the_player_through_an_open_door() -> void:
	_add_enemy(&"watcher", 0.85, Vector3(0.0, 0.0, -17.0), FloorLayers.ROLE_OPTIONAL, false)
	_run(20)
	assert_eq(String(sim._ai_state.get(ENEMY, "")), "active", "sanity: it must be engaged to pursue")
	_retreat_through_the_door(600)
	assert_eq(String(sim._ai_state.get(ENEMY, "")), "active", "sanity: still engaged, so this measures the door")
	assert_gt(sim.entities[ENEMY].z, SOUTH.end.y,
		"the enemy must be able to leave through an open door it fits (ended at %s)" % sim.entities[ENEMY])


## THE LEGALITY FACT UNDERNEATH, asserted directly rather than inferred from a chase -- a chase
## can end for reasons that have nothing to do with doorways, and the first reproduction run
## watched the leash end one at tick 148 and correctly refused a verdict.
func test_the_doorway_is_legal_for_an_unsealed_roster_and_for_the_player_alike() -> void:
	_add_enemy(&"watcher", 0.85, Vector3(0.0, 0.0, -17.0), FloorLayers.ROLE_OPTIONAL, false)
	for z: float in [SOUTH.end.y - 1.0, SOUTH.end.y, SOUTH.end.y + 1.0, SOUTH.end.y + 3.0]:
		var point := Vector3(0.0, 0.0, z)
		assert_eq(sim._legal_bounds_for(ENEMY).fits(point, 0.85), sim._bounds.fits(point, 0.85),
			"an open door must not be walkable for one side of the fight and walled for the other (z=%.1f)" % z)


## AND A SEAL STILL SEALS. The fix must not have deleted hard confinement, only re-keyed it.
func test_a_sealed_roster_still_cannot_leave_its_fight() -> void:
	_add_enemy(&"watcher", 0.85, Vector3(0.0, 0.0, -17.0), FloorLayers.ROLE_MANDATORY, true)
	assert_eq(sim.debug_describe_floor()["active_confinement"], ENCOUNTER, "sanity: the seal is live")
	_run(20)
	_retreat_through_the_door(600)
	assert_lte(sim.entities[ENEMY].z, SOUTH.end.y + 0.001,
		"a live seal is HARD legality; the roster stays in the fight (at %s)" % sim.entities[ENEMY])


## THE DISTINCTION, so a later refactor cannot quietly merge them again: same geometry, same
## retreat, opposite outcomes, decided only by whether the encounter is actually sealing.
func test_sealing_not_role_decides_whether_a_roster_is_walled_in() -> void:
	_add_enemy(&"watcher", 0.85, Vector3(0.0, 0.0, -17.0), FloorLayers.ROLE_OPTIONAL, false)
	_run(20)
	_retreat_through_the_door(600)
	var unsealed_followed: bool = sim.entities[ENEMY].z > SOUTH.end.y

	before_each()
	# SAME ROLE, sealing this time. Role is held constant on purpose: if role still decided this,
	# both halves would agree and the test could not tell the two laws apart.
	_add_enemy(&"watcher", 0.85, Vector3(0.0, 0.0, -17.0), FloorLayers.ROLE_OPTIONAL, true)
	_run(20)
	_retreat_through_the_door(600)
	var sealed_followed: bool = sim.entities[ENEMY].z > SOUTH.end.y

	assert_true(unsealed_followed, "an unsealed roster follows through an open door")
	assert_false(sealed_followed, "a sealing one does not -- same role, opposite result")


# --- 2: A FANG NEVER VANISHES ------------------------------------------------------------------

## THE REGRESSION THE RULING NAMED. A Fang that burrows near or across a connection must not end
## up permanently alive-and-invisible, and must not be killed by the emergence fail-safe either.
## Both are the same failure to the player: it vanished.
func test_a_fang_burrowing_while_the_player_leaves_resolves_rather_than_vanishing() -> void:
	_add_enemy(&"fang", 0.9, Vector3(0.0, 0.0, -17.0), FloorLayers.ROLE_OPTIONAL, false)
	# Authored burrow, matching the shipped Fang's shape.
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"test_bite", 2.0, 10000),
		Vector3(0.0, 0.0, -17.0), 2.2, 1.9, 30.0, 60.0, 0, 45, 4.0, 0.4, 20, 2.0, 30, 15, 0, 45)
	sim.debug_set_ai_active(ENEMY)
	sim._next_fire_tick[ENEMY] = 1_000_000
	_run(10)
	assert_true(sim.debug_trigger_burrow(ENEMY, PLAYER), "sanity: the burrow must actually start")

	var died: bool = false
	var emerged: bool = false
	for i in 900:
		sim.debug_override_health(PLAYER, 100000.0)
		# The player leaves through the door WHILE the Fang is under -- the reproduction case.
		var target := Vector3(0.0, 0.0, -2.0)
		var direction: Vector3 = target - sim.entities[PLAYER]
		direction.y = 0.0
		var commands: Array[Command] = [] as Array[Command]
		if direction.length() > 0.4:
			commands.append(Command.new(sim.tick_count, PLAYER, "move", {"direction": direction.normalized()}))
		for event in sim.tick(commands, DT):
			if event.kind == "died" and int(event.payload.get("actor_id", -1)) == ENEMY:
				died = true
			if event.kind == "burrow_emerged" and int(event.payload.get("actor_id", -1)) == ENEMY:
				emerged = true
		if died or emerged:
			break

	assert_false(died, "the emergence fail-safe must not fire during ordinary play -- to the player that is a vanishing")
	assert_true(emerged, "the burrow must resolve")
	assert_false(sim.debug_is_combat_absent(ENEMY), "and it must come back as a participant")
	assert_true(sim._health.get(ENEMY, 0.0) > 0.0, "alive")


## THE SOFT-LOCK HALF, stated separately because it is a different failure with the same look:
## alive, absent, and never resolving.
func test_a_burrow_never_leaves_an_actor_alive_and_absent_forever() -> void:
	_add_enemy(&"fang", 0.9, Vector3(0.0, 0.0, -17.0), FloorLayers.ROLE_OPTIONAL, false)
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"test_bite", 2.0, 10000),
		Vector3(0.0, 0.0, -17.0), 2.2, 1.9, 30.0, 60.0, 0, 45, 4.0, 0.4, 20, 2.0, 30, 15, 0, 45)
	sim.debug_set_ai_active(ENEMY)
	sim._next_fire_tick[ENEMY] = 1_000_000
	_run(10)
	assert_true(sim.debug_trigger_burrow(ENEMY, PLAYER))
	_retreat_through_the_door(900)
	assert_false(sim._health.get(ENEMY, 0.0) > 0.0 and sim.debug_is_combat_absent(ENEMY),
		"an actor may not be left alive and absent indefinitely: %s" % str(sim.debug_describe_burrow(ENEMY)))


# --- 3: THE FLOOR MUST NOT AUTHOR A DOOR ITS OWN ROSTER CANNOT USE ------------------------------

## Generalized from the same finding: an aperture narrower than a body it is authored to admit is
## an opening the player can see, walk through, and watch an enemy fail to follow them into.
func test_an_aperture_too_narrow_for_an_authored_body_is_reported() -> void:
	var plan := FloorPlan.new()
	for entry in [[0, SOUTH], [1, NORTH]]:
		var patch := WalkablePatch.new()
		patch.patch_id = entry[0]
		patch.rect = entry[1]
		patch.boundary_style = &"ledge"
		plan.patches.append(patch)
	var connection := TraversalConnection.new()
	connection.connection_id = 0
	connection.patch_ids = Vector2i(0, 1)
	connection.aperture = Rect2(-1.0, -9.0, 2.0, 4.0)  # 2 wide
	plan.connections.append(connection)
	var site := EncounterSite.new()
	site.encounter_id = 0
	site.regions = [SOUTH]
	site.role = FloorLayers.ROLE_AMBIENT
	site.roster = [{"enemy_key": &"ooze", "position": Vector3(0.0, 0.0, -16.0)}]
	plan.encounters.append(site)

	plan.validate({&"ooze": 1.45})  # needs more than 2.9 units
	assert_push_error("impassable")


func test_a_wide_enough_aperture_passes() -> void:
	var plan := FloorPlan.new()
	for entry in [[0, SOUTH], [1, NORTH]]:
		var patch := WalkablePatch.new()
		patch.patch_id = entry[0]
		patch.rect = entry[1]
		patch.boundary_style = &"ledge"
		plan.patches.append(patch)
	var connection := TraversalConnection.new()
	connection.connection_id = 0
	connection.patch_ids = Vector2i(0, 1)
	connection.aperture = DOOR  # 5 wide
	plan.connections.append(connection)
	var site := EncounterSite.new()
	site.encounter_id = 0
	site.regions = [SOUTH]
	site.role = FloorLayers.ROLE_AMBIENT
	site.roster = [{"enemy_key": &"ooze", "position": Vector3(0.0, 0.0, -16.0)}]
	plan.encounters.append(site)

	plan.validate({&"ooze": 1.45})
	assert_push_error_count(0)


func test_both_authored_floors_admit_every_body_they_place() -> void:
	for depth in [1, 2]:
		DepthGenerator.generate(0, depth)  # validate() runs inside, with real radii
		assert_push_error_count(0, "depth %d authors a doorway its own roster cannot use" % depth)
