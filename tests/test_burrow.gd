extends GutTest
## P17 BURROW v1 — Fang's ambush reposition, implemented against frozen spec `199f9d3`.
##
## The load-bearing set is the PARTICIPATION AUDIT made executable. Burrow introduces the sim's
## first living actor that temporarily leaves combat, and the audit found ALIVE == PRESENT
## PARTICIPANT true by construction in a single predicate. Every seam that assumed it is pinned
## here, including the two whose answers are RULINGS rather than consequences: Burn continues
## underground, contact spread does not.
##
## SYNTHETIC FIXTURE VALUES -- this file protects mechanical law. Fang's shipped
## 4.0/0.35/40/2.0/60/24/240 are provisional and validated by playtest, never pinned here.

const PLAYER_ID := 0
const ENEMY_ID := 1
const BLOCKER_ID := 2
const WEAPON_ID := &"test_bite"
const DT := 1.0 / 30.0

const JUMP_DISTANCE := 2.0
const JUMP_STEP := 0.5          # 4 steps
const JUMP_STEPS := 4
const UNDERGROUND := 10
const RADIUS := 2.0
const RETRY := 10
const REACQUISITION := 6
const COOLDOWN := 30

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()


func _register_player(position: Vector3 = Vector3.ZERO) -> void:
	sim.add_entity(PLAYER_ID, position, 4.0)
	sim.register_combatant(PLAYER_ID, 5000.0, &"envoy", 0, 0.4, &"player")


func _register_fang(position: Vector3, burrow: bool = true) -> void:
	sim.add_entity(ENEMY_ID, position, 3.0)
	sim.register_combatant(ENEMY_ID, 5000.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(WEAPON_ID, 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	sim.register_ai(
		ENEMY_ID, CombatTestHelpers.single_action_repertoire(WEAPON_ID, 1.5, 10000),
		position, 1.5, 0.0, 60.0, 200.0, 0, 0,
		JUMP_DISTANCE if burrow else 0.0, JUMP_STEP if burrow else 0.0,
		UNDERGROUND if burrow else 0, RADIUS, RETRY, REACQUISITION, COOLDOWN)
	sim._next_fire_tick[ENEMY_ID] = 1_000_000  # never attack; isolate mobility


## A body large enough to occupy every emergence candidate at once -- cheaper and more explicit
## than placing six separate blockers, and it makes "all candidates blocked" unambiguous.
func _register_blocker(position: Vector3, radius: float = 50.0) -> void:
	sim.add_entity(BLOCKER_ID, position, 0.0)
	sim.register_combatant(BLOCKER_ID, 5000.0, &"ooze", 0, radius, &"enemy")


func _tick(times: int) -> Array[Event]:
	var all: Array[Event] = []
	for i in times:
		all.append_array(sim.tick([], DT))
	return all


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


func _burrow_to_underground() -> void:
	assert_true(sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID), "sanity: the burrow triggered")
	for i in JUMP_STEPS:
		sim.tick([], DT)
	assert_true(sim._combat_absent.has(ENEMY_ID), "sanity: submerged")


# ===================================================================================
# A. PARTICIPATION — the audit, made executable
# ===================================================================================

func test_an_absent_actor_cannot_be_hit_by_melee() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -1.0))
	_burrow_to_underground()
	sim.register_weapon(&"sword", 10.0, &"force", 100.0, 180.0, 0.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"sword")
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	assert_eq(_of(events, "hit").size(), 0, "an absent actor is not a melee candidate")


func test_an_absent_actor_cannot_be_hit_by_a_projectile() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -3.0))
	_burrow_to_underground()
	sim.register_gun(&"gun", 10.0, &"force", 20.0, 120, 0.5, 0.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"gun")
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	assert_eq(_of(events, "projectile_fired").size(), 1, "sanity: the shot went out")
	var later: Array[Event] = _tick(30)
	assert_eq(_of(later, "hit").size(), 0, "the shot cannot find an absent actor")


## RULED: an in-flight projectile CONTINUES and expires normally. It is not deleted, and its
## source action is not cancelled -- the sweep simply re-filters candidates every tick.
func test_an_in_flight_projectile_continues_and_expires_normally() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -6.0))
	sim.register_gun(&"gun", 10.0, &"force", 6.0, 40, 0.3, 0.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"gun")
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	_burrow_to_underground()
	var later: Array[Event] = _tick(60)
	assert_eq(_of(later, "hit").size(), 0, "it cannot hit the absent actor")
	assert_eq(_of(later, "projectile_expired").size(), 1, "but it lives out its own lifetime and expires")


func test_an_absent_actor_is_not_bump_targetable() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -1.0))
	sim.register_shield(PLAYER_ID, 100.0, 0.0, 30, 1.5, 0.35, 2.0, 7, 45, 0, 0, 1.0)
	_burrow_to_underground()
	var before: Vector3 = sim.entities[ENEMY_ID]
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "block", {"held": true})], DT)
	assert_eq(_of(events, "shield_bumped").size(), 0, "an absent actor is not a bump candidate")
	assert_eq(sim.entities[ENEMY_ID], before, "and is not displaced")


func test_an_absent_actor_does_not_clamp_authored_displacement() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -1.0))
	_burrow_to_underground()
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.0)  # directly in the lunge path
	var profile: Dictionary = {
		"damage": 5.0, "damage_type": &"force", "reach": 2.0, "cone_half_angle_degrees": 90.0,
		"knockback_distance": 0.0, "fire_interval_ticks": 0, "status_id": &"", "status_proc_chance": 0.0,
		"lunge_distance": 3.0, "lunge_duration_ticks": 6, "hit_active_ticks": 3, "windup_ticks": 1,
	}
	var combo: Array[Dictionary] = [profile]
	sim.register_melee_profiles(&"lunger", combo, profile, 60, 30, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"lunger")
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], DT)
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], DT)
	_tick(8)
	assert_lt(sim.entities[PLAYER_ID].z, -2.0, "the lunge passed through where the absent actor stands")


## RULING, not a consequence: visibility does not answer this. _advance_status_ticks asks only
## whether the actor is ALIVE, and the ruling keeps that true underground.
func test_burn_continues_ticking_underground() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -1.0))
	sim.register_status(&"burn", 2.0, 5, 200)
	sim._status_instances[ENEMY_ID] = {"id": "burn", "applied_tick": -10, "next_tick": 0, "ticks_remaining": 200}
	_burrow_to_underground()
	var health_before: float = sim._health[ENEMY_ID]
	var events: Array[Event] = _tick(UNDERGROUND - 2)
	assert_gt(_of(events, "status_resolved").size(), 0, "Burn keeps resolving while the actor is absent")
	assert_lt(sim._health[ENEMY_ID], health_before, "and keeps costing health")


## THE OPPOSITE RULING, for the sibling system: a body that is not spatially present cannot be
## in contact, so spread does not occur.
func test_contact_spread_does_not_occur_underground() -> void:
	# Start them APART, so the only overlap in this test happens after the actor is absent --
	# otherwise spread fires legitimately during the still-present jump and proves nothing.
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	sim.register_status(&"burn", 1.0, 5, 200)
	sim.set_status_priority({"burn": 1})
	sim._status_instances[ENEMY_ID] = {"id": "burn", "applied_tick": -10, "next_tick": 999, "ticks_remaining": 200}
	_burrow_to_underground()
	assert_false(sim._status_instances.has(PLAYER_ID), "sanity: nothing spread before submerging")
	sim.entities[ENEMY_ID] = sim.entities[PLAYER_ID]  # exactly overlapping, if it were present
	_tick(10)
	assert_false(sim._status_instances.has(PLAYER_ID), "an absent actor is not a spread source")


func test_submerge_terminates_contact_episodes_so_later_spread_is_fresh() -> void:
	_register_player(Vector3(0, 0, -1.0))
	_register_fang(Vector3(0, 0, -1.0))
	sim._contact_transmitted_pairs[Vector2i(PLAYER_ID, ENEMY_ID)] = true
	assert_true(sim._contact_transmitted_pairs.has(Vector2i(PLAYER_ID, ENEMY_ID)), "sanity: an episode is recorded")
	_burrow_to_underground()
	assert_false(sim._contact_transmitted_pairs.has(Vector2i(PLAYER_ID, ENEMY_ID)),
		"submerge terminates the episode, so stale pair state cannot suppress valid post-emergence spread")


func test_stored_pressure_ages_normally_across_the_trip() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -1.0))
	sim.set_flinch_tuning(200, 20)
	sim.register_flinch_profile(ENEMY_ID, 100.0)
	sim._record_pressure(ENEMY_ID, 30.0)
	var before: float = sim._pressure_sum(ENEMY_ID)
	assert_almost_eq(before, 30.0, 0.001, "sanity: pressure banked")
	_burrow_to_underground()
	_tick(UNDERGROUND - 2)
	assert_almost_eq(sim._pressure_sum(ENEMY_ID), 30.0, 0.001,
		"pressure neither drains nor refreshes while absent -- it ages on its own clock")


func test_an_absent_actor_resolves_no_attack() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -1.0))
	_burrow_to_underground()
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3(0, 0, 1)})], DT)
	var rejected: Array = _of(events, "attack_rejected")
	assert_eq(rejected.size(), 1, "fail-closed: the attack is refused")
	assert_eq(String(rejected[0].payload.reason), "combat_absent")


# ===================================================================================
# B. LIFECYCLE
# ===================================================================================

func test_a_family_authoring_no_burrow_cannot_be_triggered() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -4.0), false)
	assert_false(sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID), "an unauthored burrow refuses to start")


func test_the_jump_travels_backward_then_submerges() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -4.0))
	var start: Vector3 = sim.entities[ENEMY_ID]
	assert_true(sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID), "sanity: triggered")
	var events: Array[Event] = _tick(JUMP_STEPS)
	assert_lt(sim.entities[ENEMY_ID].z, start.z, "the jump moves AWAY from the player")
	assert_almost_eq(sim.entities[ENEMY_ID].distance_to(start), JUMP_STEP * JUMP_STEPS, 0.001, "full authored distance")
	assert_eq(_of(events, "burrow_submerged").size(), 1, "and it submerges on completion")


func test_ordinary_ai_is_suspended_while_the_lifecycle_advances() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	var frozen: Vector3 = sim.entities[ENEMY_ID]
	_tick(UNDERGROUND - 2)
	assert_eq(sim.entities[ENEMY_ID], frozen, "the actor issues no locomotion while underground")
	assert_true(sim._burrow.has(ENEMY_ID), "but the lifecycle itself kept advancing")
	assert_eq(String(sim.debug_describe_burrow(ENEMY_ID).phase), "underground")


func test_the_full_cycle_emerges_and_returns_to_ordinary_decisions() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	var events: Array[Event] = _tick(UNDERGROUND + 2)
	assert_eq(_of(events, "burrow_emerged").size(), 1, "it emerges")
	assert_false(sim._combat_absent.has(ENEMY_ID), "and is a combat participant again")
	_tick(REACQUISITION + 2)
	assert_false(sim._burrow.has(ENEMY_ID), "the burrow record clears after the reacquisition beat")
	# Put the player out of reach: emerging at the authored radius leaves the Fang legitimately
	# in-band, where HOLDING is correct behaviour and would pass this for the wrong reason.
	sim.entities[PLAYER_ID] = sim.entities[ENEMY_ID] + Vector3(0, 0, 20.0)
	var before: Vector3 = sim.entities[ENEMY_ID]
	sim.tick([], DT)
	assert_ne(sim.entities[ENEMY_ID], before, "ordinary pursuit resumes; no Bite is guaranteed")


## Any successful authoritative flinch aborts the jump. PRESSURE route.
func test_a_pressure_flinch_aborts_the_jump_and_never_submerges() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -2.0))
	sim.set_flinch_tuning(200, 20)
	sim.register_flinch_profile(ENEMY_ID, 1.0)
	sim.register_weapon(&"poke", 10.0, &"force", 100.0, 180.0, 0.0, 0)
	sim._weapons["poke"].flinch_capability = "pressure"
	sim.set_equipped_weapon(PLAYER_ID, &"poke")
	assert_true(sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID), "sanity: triggered")
	sim.tick([], DT)
	var at_flinch: Vector3 = sim.entities[ENEMY_ID]

	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	assert_eq(_of(events, "flinched").size(), 1, "sanity: the mechanism fired")
	assert_false(sim._burrow.has(ENEMY_ID), "the jump is aborted")
	assert_false(sim._combat_absent.has(ENEMY_ID), "and it NEVER submerges from an aborted jump")

	var later: Array[Event] = _tick(20)
	assert_eq(_of(later, "burrow_submerged").size(), 0, "no delayed submerge")
	assert_almost_eq(sim.entities[ENEMY_ID].distance_to(at_flinch), 0.0, 0.6,
		"remaining jump movement is forfeited, never frozen and resumed")


## The EXPLOIT route reaches the same rule. Reachable mid-jump because a windup committed before
## the burrow stays open until SUBMERGE cancels it -- so vulnerability is still live.
func test_an_exploit_flinch_aborts_the_jump() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -2.0))
	sim.set_flinch_tuning(200, 20)
	sim.register_flinch_profile(ENEMY_ID, 100000.0)  # pressure route unreachable
	sim.register_action_susceptibility(WEAPON_ID, &"normal", 0, 100)
	sim.register_weapon(&"pick", 1.0, &"force", 100.0, 180.0, 0.0, 0)
	sim._weapons["pick"].flinch_capability = "exploit"
	sim.set_equipped_weapon(PLAYER_ID, &"pick")
	assert_true(sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID), "sanity: triggered")
	sim._ai_attack_start_tick[ENEMY_ID] = sim.tick_count  # a windup was open at burrow time
	sim.set_equipped_weapon(ENEMY_ID, WEAPON_ID)

	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	var flinched: Array = _of(events, "flinched")
	assert_eq(flinched.size(), 1, "sanity: the mechanism fired")
	assert_eq(String(flinched[0].payload.reason), "exploit", "via the EXPLOIT route specifically")
	assert_false(sim._burrow.has(ENEMY_ID), "which aborts the jump exactly as PRESSURE does")


func test_burn_death_underground_dies_without_emerging() -> void:
	_register_player()
	_register_fang(Vector3(0, 0, -2.0))
	sim.register_status(&"burn", 10000.0, 1, 200)
	# next_tick deliberately AFTER the jump: a lethal pulse on tick 0 would kill it mid-jump and
	# the test would never reach the underground case it exists to cover.
	sim._status_instances[ENEMY_ID] = {"id": "burn", "applied_tick": -10, "next_tick": sim.tick_count + JUMP_STEPS + 1, "ticks_remaining": 200}
	_burrow_to_underground()
	var events: Array[Event] = _tick(3)
	assert_eq(_of(events, "died").size(), 1, "Burn is the only route to death underground, and it works")
	assert_false(sim._burrow.has(ENEMY_ID), "burrow state is cleared")
	assert_false(sim._combat_absent.has(ENEMY_ID), "and combat-absence is cleared -- no soft-lock")
	var later: Array[Event] = _tick(UNDERGROUND + RETRY + 5)
	assert_eq(_of(later, "burrow_emerged").size(), 0, "a dead actor never emerges")


# ===================================================================================
# C. EMERGENCE
# ===================================================================================

func test_emergence_lands_on_the_far_side_of_the_player() -> void:
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	_tick(UNDERGROUND + 2)
	assert_gt(sim.entities[ENEMY_ID].z, 0.0, "it comes up BEYOND the player, opposite where it went under")
	assert_almost_eq(sim.entities[ENEMY_ID].distance_to(Vector3.ZERO), RADIUS, 0.01, "at the authored radius")


func test_the_degenerate_far_side_falls_back_to_the_jump_direction() -> void:
	# Fang goes under essentially on top of the player: "far side" has no meaning.
	_register_player(Vector3.ZERO)
	_register_fang(Vector3.ZERO)
	_burrow_to_underground()
	var jump_direction: Vector3 = sim._burrow[ENEMY_ID].direction
	_tick(UNDERGROUND + 2)
	var emerged: Vector3 = sim.entities[ENEMY_ID]
	assert_almost_eq(emerged.normalized().dot(-jump_direction), 1.0, 0.01,
		"the fallback is the OPPOSITE of the authored jump direction -- deterministic, never float noise")


func test_a_blocked_primary_candidate_rotates_through_the_fixed_set() -> void:
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	# Occupy the primary point (0 degrees) only.
	_register_blocker(Vector3(0, 0, RADIUS), 1.0)
	_tick(UNDERGROUND + 2)
	assert_false(sim._combat_absent.has(ENEMY_ID), "it still emerges")
	assert_gt(sim.entities[ENEMY_ID].distance_to(Vector3(0, 0, RADIUS)), 0.5,
		"but at a different candidate, not on top of the blocker")


func test_all_candidates_blocked_keeps_it_underground_without_overlapping() -> void:
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	_register_blocker(Vector3.ZERO)  # radius 50: every candidate is occupied
	var events: Array[Event] = _tick(UNDERGROUND + RETRY - 2)
	assert_eq(_of(events, "burrow_emerged").size(), 0, "it must never knowingly emerge overlapping a body")
	assert_true(sim._combat_absent.has(ENEMY_ID), "so it stays underground while the window runs")


func test_a_candidate_becoming_free_produces_a_deterministic_emergence() -> void:
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	_register_blocker(Vector3.ZERO)
	_tick(UNDERGROUND + 2)
	assert_true(sim._combat_absent.has(ENEMY_ID), "sanity: blocked")
	sim.entities[BLOCKER_ID] = Vector3(500, 0, 500)  # the way clears
	var events: Array[Event] = _tick(2)
	assert_eq(_of(events, "burrow_emerged").size(), 1, "it emerges as soon as a candidate is free")
	assert_almost_eq(sim.entities[ENEMY_ID].distance_to(Vector3(0, 0, RADIUS)), 0.0, 0.01,
		"and takes the FIRST candidate in the fixed order, deterministically")


## THE FAIL-SAFE. Not a tuning outcome: leaving a living actor combat-absent forever is an
## encounter soft-lock, which is strictly worse than a diagnosable death.
func test_the_retry_window_expiring_kills_it_underground_and_never_emerges() -> void:
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	_register_blocker(Vector3.ZERO)
	var events: Array[Event] = _tick(UNDERGROUND + RETRY + 2)
	assert_eq(_of(events, "burrow_emerged").size(), 0, "no materialization")
	assert_eq(_of(events, "died").size(), 1, "it dies authoritatively underground")
	assert_false(sim._burrow.has(ENEMY_ID), "burrow state cleared")
	assert_false(sim._combat_absent.has(ENEMY_ID), "combat-absence cleared -- no soft-lock")
	var later: Array[Event] = _tick(60)
	assert_eq(_of(later, "burrow_emerged").size(), 0, "and it never emerges afterwards")


func test_emergence_never_overlaps_a_combat_body() -> void:
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	_register_blocker(Vector3(0, 0, RADIUS), 1.0)
	_tick(UNDERGROUND + 2)
	for other_id in [PLAYER_ID, BLOCKER_ID]:
		var separation: float = sim.entities[ENEMY_ID].distance_to(sim.entities[other_id])
		assert_gte(separation, sim._contact_distance(ENEMY_ID, other_id) - 0.001,
			"emergence must never materialise inside actor %d's combat body" % other_id)


## MULTIPLE STARTING POSITIONS. The far-side vector is derived, not hardcoded to an axis, so
## the geometry has to hold from anywhere around the player.
func test_emergence_geometry_holds_from_many_starting_positions() -> void:
	for angle_degrees in [0.0, 37.0, 90.0, 143.0, 180.0, 251.0, 310.0]:
		sim = SimWorld.new()
		_register_player(Vector3.ZERO)
		var offset: Vector3 = Vector3(0, 0, -4.0).rotated(Vector3.UP, deg_to_rad(angle_degrees))
		_register_fang(offset)
		_burrow_to_underground()
		_tick(UNDERGROUND + 2)
		var emerged: Vector3 = sim.entities[ENEMY_ID]
		assert_almost_eq(emerged.length(), RADIUS, 0.01,
			"at %.0f deg: emerges at the authored radius from the player" % angle_degrees)
		# Far side means the emergence sits OPPOSITE the entry direction, across the player.
		assert_lt(emerged.normalized().dot(offset.normalized()), -0.9,
			"at %.0f deg: emerges on the FAR side from where it went under" % angle_degrees)


## The destination COMMITS at burrow entry. A player who keeps moving after the tell should be
## able to degrade it -- that is the intended counterplay, not a bug.
func test_player_movement_after_submerge_degrades_the_emergence() -> void:
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	var committed_point: Vector3 = Vector3(0, 0, RADIUS)
	# Walk away while it is underground.
	for i in UNDERGROUND + 2:
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3(1, 0, 0)})], DT)
	assert_almost_eq(sim.entities[ENEMY_ID].distance_to(committed_point), 0.0, 0.05,
		"it surfaces at the COMMITTED point, not where the player now is -- no underground retargeting")
	assert_gt(sim.entities[ENEMY_ID].distance_to(sim.entities[PLAYER_ID]), RADIUS,
		"so moving after the tell genuinely degrades the ambush")


## A player who holds still gets the ideal case, which is what makes the degradation meaningful.
func test_a_stationary_player_gets_the_intended_close_emergence() -> void:
	_register_player(Vector3.ZERO)
	_register_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	_tick(UNDERGROUND + 2)
	assert_almost_eq(sim.entities[ENEMY_ID].distance_to(sim.entities[PLAYER_ID]), RADIUS, 0.01,
		"standing still leaves the Fang exactly at its authored ambush radius")


# ===================================================================================
# D. STAGE 2 — emerge -> reacquisition beat -> ORDINARY attack
# ===================================================================================

## Registers a Fang whose bite is genuinely available, so the post-emergence attack can occur.
## The other tests suppress it deliberately to isolate mobility.
func _register_attacking_fang(position: Vector3) -> void:
	sim.add_entity(ENEMY_ID, position, 3.0)
	sim.register_combatant(ENEMY_ID, 5000.0, &"fang", 0, 0.6, &"enemy")
	sim.register_weapon(WEAPON_ID, 6.0, &"force", 1.65, 90.0, 0.0, 24)
	sim.register_ai(
		ENEMY_ID, CombatTestHelpers.single_action_repertoire(WEAPON_ID, 1.65, 12),
		position, 1.65, 0.0, 60.0, 200.0, 0, 0,
		JUMP_DISTANCE, JUMP_STEP, UNDERGROUND, RADIUS, RETRY, REACQUISITION, COOLDOWN)


## THE STAGE-2 CHAIN. Burrow earns POSITION; the attack that follows is an ordinary decision
## under existing selection and fire-time aim law, not something the burrow carried with it.
func test_an_ordinary_attack_follows_the_reacquisition_beat() -> void:
	_register_player(Vector3.ZERO)
	_register_attacking_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()

	var emerged_tick: int = -1
	var telegraph_tick: int = -1
	var hit_tick: int = -1
	for i in 200:
		for event in sim.tick([], DT):
			if event.kind == "burrow_emerged":
				emerged_tick = event.tick
			elif event.kind == "attack_telegraph" and emerged_tick != -1 and telegraph_tick == -1:
				telegraph_tick = event.tick
			elif event.kind == "hit" and int(event.payload.get("attacker_id", -1)) == ENEMY_ID and hit_tick == -1:
				hit_tick = event.tick
		if hit_tick != -1:
			break

	assert_ne(emerged_tick, -1, "it emerged")
	assert_ne(telegraph_tick, -1, "and then telegraphed an ORDINARY attack")
	assert_ne(hit_tick, -1, "which resolved")
	assert_gte(telegraph_tick - emerged_tick, REACQUISITION,
		"no attack may START before the reacquisition beat has run -- the beat is a real window, not a visible one")


## The beat is silent, and provably so: nothing may telegraph during it.
func test_no_attack_starts_during_the_reacquisition_beat() -> void:
	_register_player(Vector3.ZERO)
	_register_attacking_fang(Vector3(0, 0, -4.0))
	_burrow_to_underground()
	var during: Array[Event] = []
	var emerged: bool = false
	for i in 200:
		var events: Array[Event] = sim.tick([], DT)
		if not emerged:
			for event in events:
				if event.kind == "burrow_emerged":
					emerged = true
			continue
		during.append_array(events)
		if during.size() > 0 and sim.tick_count >= int(sim._burrow.get(ENEMY_ID, {}).get("deadline_tick", 0)) and not sim._burrow.has(ENEMY_ID):
			break
	assert_eq(_of(during, "attack_telegraph").size(), 0,
		"the reacquisition beat must contain no attack start at all")


## No attack target is carried underground: the Fang comes up with clean attack state and
## re-decides from scratch.
func test_no_attack_state_survives_the_trip() -> void:
	_register_player(Vector3.ZERO)
	_register_attacking_fang(Vector3(0, 0, -2.0))
	# Get a windup committed BEFORE the burrow, then burrow out of it.
	for i in 30:
		sim.tick([], DT)
		if sim._ai_attack_fire_tick.has(ENEMY_ID):
			break
	assert_true(sim._ai_attack_fire_tick.has(ENEMY_ID), "sanity: a windup was committed pre-burrow")
	_burrow_to_underground()
	assert_false(sim._ai_attack_fire_tick.has(ENEMY_ID),
		"submerge cancels the committed windup -- it must never fire from underground or resume on emergence")


func test_identical_runs_produce_identical_burrows() -> void:
	var runs: Array = []
	for run in 2:
		sim = SimWorld.new()
		_register_player(Vector3.ZERO)
		_register_fang(Vector3(0, 0, -4.0))
		sim.debug_trigger_burrow(ENEMY_ID, PLAYER_ID)
		var recorded: Array[String] = []
		for i in 60:
			for event in sim.tick([], DT):
				if String(event.kind).begins_with("burrow"):
					recorded.append("%d|%s" % [event.tick, event.kind])
			recorded.append("%.6f,%.6f" % [sim.entities[ENEMY_ID].x, sim.entities[ENEMY_ID].z])
		runs.append(recorded)
	assert_eq(runs[0], runs[1], "the burrow must be a pure function of world state -- no RNG, no hidden ordering")
