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


# --- 4: THE BURROW EMERGENCE LAW (P17 evolved, ruled 2026-09-03) --------------------------------
#
# P17 authored the retry-window timeout under OPEN-ARENA scope, where every candidate being
# blocked was supposed to be unreachable, so the only resolution was a loud death. Floors
# produced a real consumer: a committed destination can go invalid for ordinary world reasons,
# and killing an enemy for a room layout is a defect with a warning attached.
#
# TWO OUTCOMES NOW. Abort to the committed burrow ENTRY when that placement is legal and
# unoccupied -- deterministic, no search, nowhere surprising. The loud death survives, but means
# something narrower: the authored candidates AND the abort destination were all impossible.

## Small enough that EVERY candidate in the fixed emergence set lands off the floor -- including
## the diagonals, which a merely-small box still admits. Paired with a deliberately large
## emergence radius below rather than a knife-edge box, so the fixture is blocked by a wide
## margin instead of by luck.
const TIGHT := Rect2(-2.5, -2.5, 5.0, 5.0)


## Registers a burrower on a floor of the caller's choosing, with the shipped Fang's shape.
func _burrower_on(rects: Array[Rect2], at: Vector3, player_at: Vector3) -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(WalkableBounds.new(rects), player_at)
	sim.register_patches(rects)
	sim.add_entity(PLAYER, player_at, 6.0, Vector3(0, 0, 1), 0.45)
	sim.register_combatant(PLAYER, 100000.0, &"envoy", 0, 0.45, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.add_entity(ENEMY, at, 4.0, Vector3(0, 0, 1), 0.9)
	sim.register_combatant(ENEMY, 500.0, &"fang", 0, 0.9, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 2.0, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"test_bite", 2.0, 10000),
		at, 2.2, 1.9, 30.0, 60.0, 0, 45, 4.0, 0.4, 20, 6.0, 30, 15, 0, 45)
	sim.debug_set_ai_active(ENEMY)
	sim._next_fire_tick[ENEMY] = 1_000_000


var _resolution: Dictionary = {}

## Runs a committed burrow to its resolution. Returns the resolving event kind, or "" if it
## never resolved -- which is itself a failure, and asserted as one. The payload is kept because
## the EVENT is authoritative about where the actor was placed; reading `entities` afterwards
## reads a position the AI may already have moved on from in the same tick.
func _resolve_burrow(max_ticks: int = 900) -> String:
	_resolution = {}
	for i in max_ticks:
		sim.debug_override_health(PLAYER, 100000.0)
		for event in sim.tick([] as Array[Command], DT):
			if int(event.payload.get("actor_id", -1)) != ENEMY:
				continue
			if event.kind == "burrow_emerged" or event.kind == "burrow_aborted" or event.kind == "died":
				_resolution = event.payload
				return event.kind
	return ""


## ORDINARY EMERGENCE STILL WINS. The new fallback must not have displaced the authored path.
func test_ordinary_emergence_still_resolves_normally() -> void:
	var open_floor: Array[Rect2] = [Rect2(-20.0, -20.0, 40.0, 40.0)]
	_burrower_on(open_floor, Vector3(0.0, 0.0, -4.0), Vector3(0.0, 0.0, 0.0))
	assert_true(sim.debug_trigger_burrow(ENEMY, PLAYER))
	assert_eq(_resolve_burrow(), "burrow_emerged", "an unobstructed burrow must simply emerge")
	assert_false(sim.debug_is_combat_absent(ENEMY))


## TIMEOUT WITH A LEGAL ENTRY -> ABORT TO ENTRY. The floor is a tight box: the player stands at
## the centre, so every candidate ringing them at the authored emergence radius lands outside the
## walkable floor, while the burrow's own entry remains perfectly legal.
func test_a_blocked_emergence_aborts_to_the_burrow_entry() -> void:
	var tight: Array[Rect2] = [TIGHT]
	# The player stands clear of the entry: a burrow may never abort into another body, so a
	# player parked on top of the entry would have this test measuring occupancy instead.
	_burrower_on(tight, Vector3(0.0, 0.0, -1.5), Vector3(0.0, 0.0, 1.0))
	assert_true(sim.debug_trigger_burrow(ENEMY, PLAYER))
	var entry: Vector3 = sim.entities[ENEMY]
	assert_eq(_resolve_burrow(), "burrow_aborted",
		"with every candidate off the floor, the burrow must abort rather than kill the actor")
	assert_true(sim._health.get(ENEMY, 0.0) > 0.0, "and the actor is alive")
	assert_false(sim.debug_is_combat_absent(ENEMY), "present again")
	assert_lt(sim.entities[ENEMY].distance_to(entry), 4.5,
		"it comes back where it went down, not somewhere surprising (%s vs entry %s)" % [sim.entities[ENEMY], entry])


## THE ABORT DESTINATION IS THE COMMITTED ENTRY, not the submerge point drifted by the jump --
## asserted as an exact identity so a later refactor cannot quietly substitute "wherever it
## happened to end up".
func test_the_abort_lands_on_the_committed_entry_exactly() -> void:
	var tight: Array[Rect2] = [TIGHT]
	_burrower_on(tight, Vector3(0.0, 0.0, -1.5), Vector3(0.0, 0.0, 1.0))
	assert_true(sim.debug_trigger_burrow(ENEMY, PLAYER))
	var committed: Vector3 = sim.entities[ENEMY]
	assert_eq(_resolve_burrow(), "burrow_aborted")
	# Asserted against the EVENT, which is authoritative about placement. The jump carries the
	# body away from the entry before it submerges, so "wherever it ended up" is a different
	# point entirely -- that difference is exactly what this pins.
	var landed: Vector3 = _resolution.get("position", Vector3.INF)
	assert_almost_eq(landed.x, committed.x, 0.001, "exactly the committed entry x")
	assert_almost_eq(landed.z, committed.z, 0.001, "exactly the committed entry z")


## TIMEOUT WITH AN ILLEGAL ENTRY -> THE LOUD FAIL-SAFE SURVIVES, and now means something
## narrower: the authored candidates AND the deterministic abort destination were both
## impossible. Reached here by shrinking the floor out from under the entry mid-burrow.
func test_the_loud_failsafe_still_fires_when_the_entry_is_also_impossible() -> void:
	var tight: Array[Rect2] = [TIGHT]
	_burrower_on(tight, Vector3(0.0, 0.0, -1.5), Vector3(0.0, 0.0, 1.0))
	assert_true(sim.debug_trigger_burrow(ENEMY, PLAYER))
	# The world changes under it while it is under: the ground it left no longer exists.
	for i in 20:
		sim.tick([] as Array[Command], DT)
	# The surviving ground no longer includes the entry -- the player's half of the box remains,
	# so the world is still coherent and only the abort destination has become impossible.
	var sliver: Array[Rect2] = [Rect2(-2.5, 0.0, 5.0, 2.5)]
	sim._bounds = WalkableBounds.new(sliver)
	assert_eq(_resolve_burrow(), "died",
		"with the candidates AND the entry impossible, the loud fail-safe is still the answer")
	assert_push_error_count(0)  # a warning, deliberately, not an error


## THE SOFT-LOCK IS UNREACHABLE BY EITHER ROAD. Whatever happens, a burrow resolves.
func test_a_burrow_always_resolves_one_way_or_the_other() -> void:
	for tight: bool in [true, false]:
		var rects: Array[Rect2] = [TIGHT]
		if not tight:
			rects = [Rect2(-20.0, -20.0, 40.0, 40.0)] as Array[Rect2]
		_burrower_on(rects, Vector3(0.0, 0.0, -1.5), Vector3(0.0, 0.0, 1.0))
		assert_true(sim.debug_trigger_burrow(ENEMY, PLAYER))
		var outcome: String = _resolve_burrow()
		assert_ne(outcome, "", "a burrow must never simply never resolve (tight=%s)" % str(tight))
		assert_false(sim._health.get(ENEMY, 0.0) > 0.0 and sim.debug_is_combat_absent(ENEMY),
			"and must never leave an actor alive and absent (tight=%s)" % str(tight))


# --- 6: AN ACTIVATED ROSTER KNOWS THE FIGHT HAS STARTED (ruled 2026-09-04) ----------------------
#
# Walking into a room that wakes a group must not require damaging one of them before the group
# understands it is in combat. The trigger IS the awareness.
#
# NOT aggro-by-damage: nothing is fabricated and no attacker is invented. The actor stops being
# unaware, and ordinary target rules choose from there -- which is exactly why environment damage
# still confers nothing.

func test_activating_an_encounter_engages_its_roster_immediately() -> void:
	_add_enemy(&"watcher", 0.85, Vector3(0.0, 0.0, -17.0), FloorLayers.ROLE_OPTIONAL, false)
	assert_eq(String(sim._ai_state.get(ENEMY, "")), "active",
		"the roster is engaged the moment its encounter activates, with no hit required")


## AND WITHOUT DETECTION DOING THE WORK. Placed far outside its own detection radius, an
## activated actor is still engaged -- otherwise "activation engages" would only be true for
## rooms small enough that detection would have fired anyway.
func test_activation_engages_beyond_detection_range() -> void:
	sim.register_encounter(ENCOUNTER, [SOUTH] as Array[Rect2], FloorLayers.ROLE_OPTIONAL, false, true)
	sim.add_entity(ENEMY, Vector3(-9.0, 0.0, -19.0), 4.0, Vector3(0, 0, 1), 0.85)
	sim.register_combatant(ENEMY, 500.0, &"watcher", 0, 0.85, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 2.0, 90.0, 0.0, 9999)
	# Detection 1.0: far too small to notice a player standing across the room.
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"test_bite", 2.0, 10000),
		Vector3(-9.0, 0.0, -19.0), 2.2, 1.9, 1.0, 60.0, 0, 0, 0.0, 0.0, 0, 0.0, 0, 0, 0, 45)
	assert_true(sim.assign_actor_encounter(ENEMY, ENCOUNTER))
	assert_ne(String(sim._ai_state.get(ENEMY, "")), "active", "sanity: dormant and unaware to begin with")

	sim.debug_activate_encounter(ENCOUNTER)
	assert_eq(String(sim._ai_state.get(ENEMY, "")), "active",
		"activation is the awareness; detection range must not have to agree")


## THE THREE SOURCES OF AWARENESS STAY SEPARATE, so a later refactor cannot merge them: an
## attack confers attacker-specific aggro, activation confers engagement, and the environment
## confers nothing at all.
func test_environment_damage_still_confers_no_awareness() -> void:
	sim.register_encounter(ENCOUNTER, [SOUTH] as Array[Rect2], FloorLayers.ROLE_AMBIENT, false, true)
	sim.add_entity(ENEMY, Vector3(0.0, 0.0, -17.0), 4.0, Vector3(0, 0, 1), 0.85)
	sim.register_combatant(ENEMY, 500.0, &"watcher", 0, 0.85, &"enemy")
	sim.register_weapon(&"test_bite", 5.0, &"force", 2.0, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"test_bite", 2.0, 10000),
		Vector3(0.0, 0.0, -17.0), 2.2, 1.9, 1.0, 60.0, 0, 0, 0.0, 0.0, 0, 0.0, 0, 0, 0, 45)
	assert_true(sim.assign_actor_encounter(ENEMY, ENCOUNTER))
	# A pad authored to include enemies, so the damage genuinely lands.
	sim.register_spike_pad(0, Rect2(-3.0, -20.0, 6.0, 6.0), 1, 10000, 0, 8.0, &"force", [&"player", &"enemy"])
	sim.entities[PLAYER] = Vector3(0.0, 0.0, -2.0)
	_run(30)
	assert_lt(sim._health[ENEMY], 500.0, "sanity: the hazard hurt it")
	assert_ne(String(sim._ai_state.get(ENEMY, "")), "active",
		"being hurt by the floor is not being told a fight has started")
