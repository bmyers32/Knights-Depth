extends GutTest
## P16 (Treat, M1 close): shield bump + perfect parry — TWO SEPARABLE mechanics that
## share only the shield. Bump is a spacing utility with NO timing requirement; parry
## is a mastery layer whose sole extra reward is a temporary incoming-damage multiplier
## on the attacker (PARRY EXPOSED — LEXICON; distinct from VULNERABLE, and conferring
## no EXPLOIT/flinch susceptibility).

const PLAYER_ID := 0
const ENEMY_ID := 1
const DT := 1.0 / 30.0

## Synthetic FIXTURE values -- these deliberately do NOT track shipped content. This
## file protects the MECHANICAL laws (rising-edge trigger, cooldown, slide stepping,
## parry routing); tuning is validated by playtest, never pinned by assertions here.
const METER := 100.0
const BUMP_PADDING := 0.35
const BUMP_DISTANCE := 2.0
const BUMP_SLIDE_TICKS := 7
const BUMP_COOLDOWN := 45
const PARRY_WINDOW := 6
const PARRY_EXPOSURE := 45
const PARRY_MULTIPLIER := 1.5
## Player 0.4 + enemy 0.6 = 1.0 contact, so bump reaches to 1.35 with the padding.
const PLAYER_RADIUS := 0.4
const ENEMY_RADIUS := 0.6

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(PLAYER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(PLAYER_ID, 500.0, &"envoy", 0, PLAYER_RADIUS, &"player")
	sim.add_entity(ENEMY_ID, Vector3(0, 0, -1.0), 0.0)
	sim.register_combatant(ENEMY_ID, 500.0, &"test_enemy", 0, ENEMY_RADIUS, &"enemy")
	sim.register_shield(PLAYER_ID, METER, 0.0, 30, 1.5,
		BUMP_PADDING, BUMP_DISTANCE, BUMP_SLIDE_TICKS, BUMP_COOLDOWN,
		PARRY_WINDOW, PARRY_EXPOSURE, PARRY_MULTIPLIER)
	# Enemy melee, and a player sword for punishing a PARRY EXPOSED target.
	sim.register_weapon(&"claw", 10.0, &"force", 2.0, 90.0, 0.0)
	sim.register_weapon(&"sword", 10.0, &"force", 3.0, 90.0, 0.0)


func _block(held: bool, extra: Array[Command] = []) -> Array[Event]:
	var commands: Array[Command] = [Command.new(sim.tick_count, PLAYER_ID, "block", {"held": held})]
	commands.append_array(extra)
	return sim.tick(commands, DT)


func _enemy_attacks() -> Command:
	sim.set_equipped_weapon(ENEMY_ID, &"claw")
	return Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3(0, 0, 1)})


func _player_attacks() -> Array[Event]:
	sim.set_equipped_weapon(PLAYER_ID, &"sword")
	return sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- 1. SHIELD BUMP — spacing utility, no timing -----------------------------------

func test_bump_fires_on_the_rising_edge_and_displaces_a_close_hostile() -> void:
	var before: Vector3 = sim.entities[ENEMY_ID]
	var events := _block(true)
	assert_eq(_of(events, "shield_bumped").size(), 1)
	assert_eq(_of(events, "shield_bumped")[0].payload.bumped_ids, [ENEMY_ID])
	assert_almost_eq(sim.entities[ENEMY_ID].z, before.z, 0.001,
		"BUMP is a SLIDE, not an impulse: nothing has teleported on the raise tick")
	for _i in range(BUMP_SLIDE_TICKS):
		sim.tick([], DT)
	assert_almost_eq(sim.entities[ENEMY_ID].z, before.z - BUMP_DISTANCE, 0.001,
		"the full authored distance is delivered over bump_slide_ticks, directly away")
	assert_false(sim._bump_slides.has(ENEMY_ID), "and the slide record clears on completion")


func test_bump_requires_no_timing_and_ignores_hostiles_beyond_contact_plus_padding() -> void:
	# contact 1.0 + padding 0.35 = 1.35; park the enemy just outside it.
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.4)
	assert_eq(_of(_block(true), "shield_bumped").size(), 0, "outside reach: no bump")
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.3)
	_block(false)
	assert_eq(_of(_block(true), "shield_bumped").size(), 1, "inside reach: bump, with no timing demand")


func test_holding_the_shield_never_re_bumps() -> void:
	_block(true)
	var held_events: Array[Event] = []
	for _i in range(10):
		held_events.append_array(_block(true))
	assert_eq(_of(held_events, "shield_bumped").size(), 0,
		"only the READY->HELD rising edge bumps; holding must not repel continuously")


func test_bump_cooldown_suppresses_only_the_bump_not_blocking() -> void:
	_block(true)
	_block(false)
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.0)  # the first bump displaced it; bring it back
	var events := _block(true)  # re-raised well inside the cooldown
	assert_eq(_of(events, "shield_bumped").size(), 0, "second bump is on cooldown")
	assert_eq(sim._shield_state[PLAYER_ID], "held", "but the shield still raises normally")
	var blocked := sim.tick([_enemy_attacks()], DT)
	assert_eq(_of(blocked, "blocked").size(), 1, "and still blocks normally while cooling down")


func test_bump_cooldown_expires_on_its_exact_tick() -> void:
	_block(true)
	_block(false)
	while sim.tick_count < int(sim._shield_bump_ready_tick[PLAYER_ID]) - 1:
		sim.tick([], DT)
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.0)
	assert_eq(_of(_block(true), "shield_bumped").size(), 0, "one tick early: still suppressed")
	_block(false)
	assert_eq(_of(_block(true), "shield_bumped").size(), 1, "on the deadline: bump is available again")


func test_bump_never_displaces_allies() -> void:
	var ally_id: int = 7
	sim.add_entity(ally_id, Vector3(0, 0, -0.9), 0.0)
	sim.register_combatant(ally_id, 100.0, &"envoy", 0, ENEMY_RADIUS, &"player")
	var ally_before: Vector3 = sim.entities[ally_id]
	_block(true)
	assert_eq(sim.entities[ally_id], ally_before, "allies are never bump targets")


# --- 2. PERFECT PARRY — mastery layer, ONE reward -----------------------------------

func test_hit_inside_the_window_parries_and_marks_the_attacker_parry_exposed() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.6)  # outside bump reach (1.35), inside claw reach (2.0)
	_block(true)
	var events := sim.tick([_enemy_attacks()], DT)
	var parried := _of(events, "parried")
	assert_eq(parried.size(), 1)
	assert_eq(parried[0].payload.attacker_id, ENEMY_ID)
	assert_eq(int(parried[0].payload.until_tick), sim.tick_count - 1 + PARRY_EXPOSURE)


func test_hit_outside_the_window_blocks_normally_without_parrying() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.6)
	_block(true)
	for _i in range(PARRY_WINDOW + 1):
		_block(true)
	var events := sim.tick([_enemy_attacks()], DT)
	assert_eq(_of(events, "blocked").size(), 1, "still a normal block")
	assert_eq(_of(events, "parried").size(), 0, "but too late to parry")


func test_a_parried_hit_still_drains_the_meter() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.6)
	_block(true)
	var before: float = sim._shield_meter[PLAYER_ID]
	var events := sim.tick([_enemy_attacks()], DT)
	assert_eq(_of(events, "parried").size(), 1, "sanity: this was a parry")
	assert_almost_eq(sim._shield_meter[PLAYER_ID], before - 10.0, 0.001,
		"a parry's only extra reward is the punish window -- never meter efficiency")


func test_parry_exposed_multiplies_incoming_damage_then_expires_on_its_exact_tick() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.6)
	_block(true)
	sim.tick([_enemy_attacks()], DT)
	var until: int = int(sim._parry_exposed_until_tick[ENEMY_ID])

	var health_before: float = sim._health[ENEMY_ID]
	_player_attacks()
	assert_almost_eq(health_before - sim._health[ENEMY_ID], 10.0 * PARRY_MULTIPLIER, 0.001,
		"a PARRY EXPOSED target takes multiplied damage")

	while sim.tick_count < until:
		sim.tick([], DT)
	health_before = sim._health[ENEMY_ID]
	_player_attacks()
	assert_almost_eq(health_before - sim._health[ENEMY_ID], 10.0, 0.001,
		"exposure expires on its exact tick, back to base damage")


func test_parry_exposure_REFRESHES_and_never_stacks() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.6)
	_block(true)
	sim.tick([_enemy_attacks()], DT)
	var first_until: int = int(sim._parry_exposed_until_tick[ENEMY_ID])
	var first_multiplier: float = float(sim._parry_exposed_damage_multiplier[ENEMY_ID])

	for _i in range(10):
		sim.tick([], DT)
	_block(false)
	_block(true)  # earn a second parry mid-exposure
	sim.tick([_enemy_attacks()], DT)

	assert_gt(int(sim._parry_exposed_until_tick[ENEMY_ID]), first_until,
		"a newly earned parry REFRESHES: the deadline moves (unlike flinch's non-extension)")
	assert_eq(int(sim._parry_exposed_until_tick[ENEMY_ID]), sim.tick_count - 1 + PARRY_EXPOSURE,
		"and it is a FRESH FULL window, never remaining duration plus more")
	assert_almost_eq(float(sim._parry_exposed_damage_multiplier[ENEMY_ID]), first_multiplier, 0.001,
		"the multiplier is re-set, never compounded")


func test_parry_exposed_confers_no_flinch_susceptibility() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.6)
	sim.register_flinch_profile(ENEMY_ID, 999.0)  # unreachable threshold
	sim.set_flinch_tuning(90, 20)
	_block(true)
	sim.tick([_enemy_attacks()], DT)
	assert_true(sim._parry_exposed_until_tick.has(ENEMY_ID), "sanity: parry landed")
	sim._weapons["sword"].flinch_capability = "exploit"
	assert_eq(_of(_player_attacks(), "flinched").size(), 0,
		"PARRY EXPOSED is damage only -- it must never imply EXPLOIT/VULNERABLE")


func test_parry_exposure_dies_with_the_actor() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.6)
	_block(true)
	sim.tick([_enemy_attacks()], DT)
	assert_true(sim._parry_exposed_until_tick.has(ENEMY_ID))
	sim._health[ENEMY_ID] = 1.0
	_player_attacks()
	assert_false(sim._parry_exposed_until_tick.has(ENEMY_ID), "records die with the actor")


# --- 3. Phase-order invariant (locked, deliberate) ----------------------------------

## NON-RETROACTIVITY, documented intentional: projectiles resolve at the TOP of tick()
## before Commands, so a projectile arriving on the same tick the shield rises sees the
## PRE-RAISE state. This is NOT a "melee-only parry" rule -- see the later-tick test.
func test_same_tick_projectile_sees_pre_raise_shield_state() -> void:
	sim.register_gun(&"bolt", 10.0, &"force", 8.0, 60, 0.4, 0.0)
	sim.set_equipped_weapon(ENEMY_ID, &"bolt")
	sim.entities[ENEMY_ID] = Vector3(0, 0, -0.2)  # arrives on the very next tick
	sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3(0, 0, 1)})], DT)

	var health_before: float = sim._health[PLAYER_ID]
	var events := _block(true)  # raise on the same tick the bolt lands
	assert_eq(_of(events, "blocked").size(), 0, "the bolt resolved before the block Command")
	assert_eq(_of(events, "parried").size(), 0, "and therefore cannot be retroactively parried")
	assert_almost_eq(health_before - sim._health[PLAYER_ID], 10.0, 0.001, "it lands as an ordinary hit")
	assert_eq(sim._shield_state[PLAYER_ID], "held", "the shield is nonetheless up from this tick on")


## SPAWN DISTANCE RE-BASELINED 2026-08-14 (P29 item 3, authoritative projectile geometry).
## DELIBERATE, and it is a PRECONDITION restoration, not an assertion change: both
## assertions below are untouched and still demand exactly one block and one parry.
##
## This test's isolation depends on the bolt being STILL IN FLIGHT when the shield rises.
## Once the swept hit test began summing the target's body (0.40 bolt + 0.40 player = 0.80
## effective, was 0.40), the bolt from 1.6 units away started connecting during the three
## "still in flight" setup ticks — i.e. before the rising edge — so it landed as an
## ordinary unblocked hit and there was nothing to parry. Exactly BRAIN's "reordering a
## shared decision invalidates test SETUPS, not just assertions", in spatial form.
##
## 2.5 restores the intended timeline against the corrected geometry: contact needs
## 1.7 units of travel at 0.267/tick, so the bolt arrives on travel step 7 — after the
## rising edge on step 4, inside the four post-block ticks, and 3 ticks into the 6-tick
## parry window.
func test_later_tick_projectile_parries_normally_through_the_shared_gate() -> void:
	sim.register_gun(&"bolt", 10.0, &"force", 8.0, 60, 0.4, 0.0)
	sim.set_equipped_weapon(ENEMY_ID, &"bolt")
	sim.entities[ENEMY_ID] = Vector3(0, 0, -2.5)  # several travel ticks at 8.0 u/s
	sim.tick([Command.new(sim.tick_count, ENEMY_ID, "attack", {"aim": Vector3(0, 0, 1)})], DT)
	for _i in range(3):
		sim.tick([], DT)                             # bolt still in flight

	var events: Array[Event] = _block(true)          # rising edge, before arrival
	for _i in range(4):
		events.append_array(sim.tick([], DT))        # bolt arrives against an established shield
	assert_eq(_of(events, "blocked").size(), 1, "a later projectile blocks normally")
	assert_eq(_of(events, "parried").size(), 1, "and parries normally -- parry is not melee-only")


func test_bump_slide_carries_an_attacker_out_of_reach_so_its_attack_whiffs() -> void:
	# The spacing payoff (GAME-RULES §3): displacement is non-flinching, so the attack
	# is never cancelled -- it simply resolves later from a position out of its reach.
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.0)
	_block(true)
	for _i in range(BUMP_SLIDE_TICKS):
		sim.tick([], DT)
	assert_almost_eq(sim.entities[ENEMY_ID].z, -3.0, 0.001, "slid beyond the claw's 2.0 reach")
	var events := sim.tick([_enemy_attacks()], DT)
	assert_eq(_of(events, "blocked").size(), 0, "the attack whiffs from its new position")
	assert_eq(_of(events, "hit").size(), 0)
	assert_eq(_of(events, "parried").size(), 0, "nothing connected, so there is nothing to parry")


## REQUIRED (§3 non-flinching-displacement law): a BUMP during a committed windup must
## not cancel, reset, delay or desynchronise it. The attack's own timeline continues
## untouched while the actor slides, and resolves from wherever it ends up.
func test_bump_during_a_committed_windup_never_disturbs_its_timeline() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.0)
	sim.register_weapon(&"bite", 10.0, &"force", 2.0, 90.0, 0.0, 45)
	sim.register_ai(ENEMY_ID, CombatTestHelpers.single_action_repertoire(&"bite", 2.0, 12), Vector3(0, 0, -1.0), 2.0, 0.5, 20.0, 40.0)
	sim.debug_set_ai_active(ENEMY_ID)
	sim.tick([], DT)  # AI commits to a windup
	assert_true(sim._ai_attack_fire_tick.has(ENEMY_ID), "sanity: a windup is committed")

	var start_tick: int = int(sim._ai_attack_start_tick[ENEMY_ID])
	var fire_tick: int = int(sim._ai_attack_fire_tick[ENEMY_ID])
	var cooldown_before: int = int(sim._next_fire_tick.get(ENEMY_ID, 0))

	var events := _block(true)  # bump it mid-windup
	assert_eq(_of(events, "shield_bumped").size(), 1, "sanity: the bump landed")
	assert_eq(int(sim._ai_attack_start_tick[ENEMY_ID]), start_tick, "windup start is untouched")
	assert_eq(int(sim._ai_attack_fire_tick[ENEMY_ID]), fire_tick, "fire tick is untouched")
	assert_eq(int(sim._next_fire_tick.get(ENEMY_ID, 0)), cooldown_before,
		"and the slide never arms the enemy's own attack cooldown")
	assert_eq(_of(events, "windup_interrupted").size(), 0, "BUMP never interrupts")
	assert_eq(_of(events, "flinched").size(), 0, "and never flinches")

	var during: Array[Event] = []
	while sim.tick_count <= fire_tick:
		during.append_array(sim.tick([], DT))
		assert_eq(_of(during, "windup_interrupted").size(), 0,
			"the committed windup runs its ORIGINAL timeline throughout the slide")
	assert_false(sim._ai_attack_fire_tick.has(ENEMY_ID), "it fired on schedule, from wherever it now is")


## RULED 2026-08-19, NEWLY REVIEWED — not a backdated intention. The P16 record was checked
## and contained only the OPPOSITE proposition (a bump never INFLICTS flinch: LEXICON's BUMP
## entry, and test_bump_during_a_committed_windup_never_disturbs_its_timeline above). What a
## flinch does to an actor ALREADY sliding was unspecified and untested; it fell out of
## _advance_bump_slides() not being gated by _flinched_until_tick.
##
## PRINCIPLE: flinch suppresses AGENCY. Externally imposed displacement is not agency, so
## already-imparted forced motion completes. Pinned here because a rule that lives only in a
## comment is a rule that drifts — and because the opposite ruling is expected for
## self-propelled commitments (ROADMAP P17's scurry), which makes the boundary worth holding.
func test_a_flinched_actor_still_completes_an_imparted_bump_slide() -> void:
	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.0)
	sim.set_flinch_tuning(90, 20)
	sim.register_flinch_profile(ENEMY_ID, 1.0)
	sim._weapons["sword"].flinch_capability = "pressure"

	var start_z: float = sim.entities[ENEMY_ID].z
	_block(true)  # impart the slide
	assert_true(sim._bump_slides.has(ENEMY_ID), "sanity: a slide is in progress")

	var events: Array[Event] = _player_attacks()  # flinch it mid-slide
	assert_eq(_of(events, "flinched").size(), 1, "sanity: the mechanism fired -- the actor really is flinched")
	assert_true(sim.tick_count < int(sim._flinched_until_tick[ENEMY_ID]), "sanity: still inside the flinch window")

	for _i in range(BUMP_SLIDE_TICKS):
		sim.tick([], DT)
	assert_false(sim._bump_slides.has(ENEMY_ID), "the slide ran to completion rather than being aborted")
	assert_almost_eq(sim.entities[ENEMY_ID].z, start_z - BUMP_DISTANCE, 0.001,
		"and it delivered its FULL authored displacement -- flinch withholds an actor's own Commands, it does not undo motion imposed on it")


# --- 4. determinism / inertness -----------------------------------------------------

func test_shield_without_p16_content_behaves_exactly_as_before() -> void:
	var plain := SimWorld.new()
	plain.set_damage_matrix({}, 1.5, 0.5)
	plain.add_entity(PLAYER_ID, Vector3.ZERO, 4.0)
	plain.register_combatant(PLAYER_ID, 500.0, &"envoy", 0, PLAYER_RADIUS, &"player")
	plain.add_entity(ENEMY_ID, Vector3(0, 0, -1.0), 0.0)
	plain.register_combatant(ENEMY_ID, 500.0, &"test_enemy", 0, ENEMY_RADIUS, &"enemy")
	plain.register_shield(PLAYER_ID, METER, 0.0, 30, 1.5)  # pre-P16 call shape
	plain.register_weapon(&"claw", 10.0, &"force", 2.0, 90.0, 0.0)
	plain.set_equipped_weapon(ENEMY_ID, &"claw")
	var enemy_before: Vector3 = plain.entities[ENEMY_ID]
	var events: Array[Event] = plain.tick([Command.new(plain.tick_count, PLAYER_ID, "block", {"held": true})], DT)
	events.append_array(plain.tick([Command.new(plain.tick_count, ENEMY_ID, "attack", {"aim": Vector3(0, 0, 1)})], DT))
	assert_eq(_of(events, "shield_bumped").size(), 0, "no bump without authored content")
	assert_eq(_of(events, "parried").size(), 0, "no parry without authored content")
	assert_eq(plain.entities[ENEMY_ID], enemy_before, "nothing displaced")
	assert_eq(_of(events, "blocked").size(), 1, "ordinary blocking is untouched")


func test_bump_and_parry_outcomes_are_deterministic() -> void:
	var runs: Array = []
	for _run in range(2):
		before_each()
		var log: Array = []
		for event in _block(true):
			log.append([event.tick, event.kind])
		for event in sim.tick([_enemy_attacks()], DT):
			log.append([event.tick, event.kind])
		runs.append(log)
	assert_eq(runs[0], runs[1])
