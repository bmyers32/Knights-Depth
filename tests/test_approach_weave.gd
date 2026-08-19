extends GutTest
## APPROACH WEAVE (P17) — Fang's authored BASELINE MOTION PATH.
##
## GAME-RULES §3 channel law (P17 amendment): FAMILIES own baseline motion PATH (spatial);
## entity STATES own motion RHYTHM/COORDINATION (temporal). The two are orthogonal but
## composable. The load-bearing test in this file is therefore NOT "does it zig-zag" (that
## is visible in a playtest) but `test_two_actors_never_share_a_weave_phase`: the amendment
## makes a deterministic per-actor phase offset BINDING precisely so a family's path can
## never impersonate Claimed coordination, and that is a claim only a test can hold.
##
## The other half of this file is negative-space coverage. A movement change lands in a
## shared decision function, and BRAIN records that changing such a function's control flow
## invalidates test SETUPS, not just assertions. So every neighbouring branch (retreat,
## hold, windup-freeze, flinch) is asserted UNCHANGED here rather than assumed.

var sim: SimWorld

const PLAYER_ID := 0
const ENEMY_ID := 1
const SECOND_ENEMY_ID := 2
const WEAPON_ID := &"test_bite"

const DEGREES := 35.0
const PERIOD := 30
const RELEASE := 3.0
const STRIDE := 7
const DT := 1.0 / 30.0


func _register_player(s: SimWorld, position: Vector3) -> void:
	s.add_entity(PLAYER_ID, position, 4.0)
	s.register_combatant(PLAYER_ID, 30.0, &"envoy", 0, 0.4, &"player")


## Mirrors test_enemy_ai.gd's hand-registration shape deliberately: these tests are about
## the weave expression itself, so they must not depend on Fang's live .tres values, which
## are provisional and expected to move at the first playtest.
func _register_enemy(s: SimWorld, position: Vector3, degrees: float, period: int, release: float, stride: int, actor_id: int = ENEMY_ID, minimum_attack_distance: float = 0.0) -> void:
	s.add_entity(actor_id, position, 3.0)
	s.register_combatant(actor_id, 20.0, &"fang", 15, 1.0, &"enemy")
	s.register_weapon(WEAPON_ID, 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	s.register_ai(actor_id, CombatTestHelpers.single_action_repertoire(WEAPON_ID, 1.5, 10000), position, 1.5, minimum_attack_distance, 20.0, 40.0, 0, 0, degrees, period, release, stride)


func _tick(s: SimWorld, times: int) -> void:
	for i in times:
		s.tick([], DT)


## Per-tick displacement direction, which is what the weave actually changes. Position
## deltas rather than the returned Command, so these assert the OBSERVABLE path.
func _step_headings(s: SimWorld, times: int, actor_id: int = ENEMY_ID) -> Array[Vector3]:
	var headings: Array[Vector3] = []
	for i in times:
		var before: Vector3 = s.entities[actor_id]
		s.tick([], DT)
		var delta: Vector3 = s.entities[actor_id] - before
		headings.append(Vector3.ZERO if delta.length() < 0.0001 else delta.normalized())
	return headings


# ---------------------------------------------------------------------------------
# 1. NO-OP BY DEFAULT — the whole feature must be invisible where it is not authored.
# ---------------------------------------------------------------------------------

func test_unauthored_weave_approaches_in_a_perfectly_straight_line() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -10), 0.0, 0, 0.0, 0)
	var headings: Array[Vector3] = _step_headings(sim, 40)
	for i in headings.size():
		if headings[i] == Vector3.ZERO:
			continue
		assert_almost_eq(headings[i].x, 0.0, 0.0001, "tick %d: an unauthored weave must produce zero lateral movement" % i)


func test_zero_degrees_with_a_period_authored_is_still_off() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -10), 0.0, PERIOD, RELEASE, STRIDE)
	var described: Dictionary = sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID)
	assert_false(bool(described.authored), "degrees 0 must leave NO weave record -- absence is the off state")


func test_period_below_two_is_rejected_as_off_not_floored() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -10), DEGREES, 1, RELEASE, STRIDE)
	var described: Dictionary = sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID)
	assert_false(bool(described.authored), "a period with no half-period must be treated as OFF, never floored to a 0-tick flip")


# ---------------------------------------------------------------------------------
# 2. THE WEAVE ITSELF — shape, and the amplitude content authored.
# ---------------------------------------------------------------------------------

func test_authored_weave_alternates_to_both_sides_of_the_straight_line() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -14), DEGREES, PERIOD, RELEASE, STRIDE)
	var headings: Array[Vector3] = _step_headings(sim, PERIOD * 2)
	var left: int = 0
	var right: int = 0
	for heading in headings:
		if heading.x > 0.01:
			right += 1
		elif heading.x < -0.01:
			left += 1
	assert_gt(left, 0, "the weave must swing to one side")
	assert_gt(right, 0, "...and to the other -- a one-sided weave is a drift, not a zig-zag")


## The reference heading is resampled EVERY tick, deliberately: the weave rotates off the
## live straight-to-player direction, and that direction itself turns as the actor swings
## off-axis. Measuring against a fixed +Z would drift by exactly the amount the mechanic is
## working, and would read as an amplitude bug that isn't one.
func test_weave_holds_the_authored_amplitude_exactly() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -14), DEGREES, PERIOD, RELEASE, STRIDE)
	for i in PERIOD:
		var straight: Vector3 = (sim.entities[PLAYER_ID] - sim.entities[ENEMY_ID])
		straight.y = 0.0
		straight = straight.normalized()
		var before: Vector3 = sim.entities[ENEMY_ID]
		sim.tick([], DT)
		var delta: Vector3 = sim.entities[ENEMY_ID] - before
		if delta.length() < 0.0001:
			continue
		var angle: float = rad_to_deg(absf(delta.normalized().signed_angle_to(straight, Vector3.UP)))
		assert_almost_eq(angle, DEGREES, 0.01, "tick %d: heading must sit exactly at the authored amplitude off the LIVE straight heading" % i)


func test_sign_flips_exactly_once_per_half_period() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -14), DEGREES, PERIOD, RELEASE, 0)
	var flips: int = 0
	var previous: int = sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID).sign
	for i in PERIOD * 2:
		sim.tick([], DT)
		var current: int = sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID).sign
		if current != previous:
			flips += 1
		previous = current
	assert_eq(flips, 4, "two full periods must produce exactly four sign flips (one per half period)")


# ---------------------------------------------------------------------------------
# 3. THE BINDING CONSEQUENCE — GAME-RULES §3: family path must never impersonate
#    Claimed coordination. This is the amendment's own enforcement.
# ---------------------------------------------------------------------------------

func test_two_actors_never_share_a_weave_phase() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(-2, 0, -14), DEGREES, PERIOD, RELEASE, STRIDE, ENEMY_ID)
	_register_enemy(sim, Vector3(2, 0, -14), DEGREES, PERIOD, RELEASE, STRIDE, SECOND_ENEMY_ID)
	var disagreements: int = 0
	for i in PERIOD * 2:
		sim.tick([], DT)
		var a: int = sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID).sign
		var b: int = sim.debug_describe_approach_weave(SECOND_ENEMY_ID, PLAYER_ID).sign
		if a != b:
			disagreements += 1
	assert_gt(disagreements, 0, "two Common actors weaving in unison read as CLAIMED coordination (GAME-RULES §3 binding consequence)")


## THE PHASE-NORMALIZATION INVARIANT (ruled): actor_id shifts PHASE and only phase — never
## the period, never the waveform, never the amplitude. Asserted with a deliberately absurd
## actor_id, because that is where an un-normalized offset would show up first: as a wave
## that drifts, stretches, or degenerates instead of one that is merely shifted.
func test_a_very_large_actor_id_produces_a_pure_phase_shift() -> void:
	const BIG_ID: int = 10_000_001
	const SAMPLES: int = PERIOD * 4

	# Reference waveform: same actor, stride 0, so its offset is 0 by construction.
	var reference := SimWorld.new()
	_register_player(reference, Vector3(0, 0, 0))
	_register_enemy(reference, Vector3(0, 0, -40), DEGREES, PERIOD, RELEASE, 0, BIG_ID)
	var reference_signs: Array[int] = []
	for i in SAMPLES * 2:
		reference.tick([], DT)
		reference_signs.append(int(reference.debug_describe_approach_weave(BIG_ID, PLAYER_ID).sign))

	var shifted := SimWorld.new()
	_register_player(shifted, Vector3(0, 0, 0))
	_register_enemy(shifted, Vector3(0, 0, -40), DEGREES, PERIOD, RELEASE, STRIDE, BIG_ID)
	var described: Dictionary = shifted.debug_describe_approach_weave(BIG_ID, PLAYER_ID)

	# PHASE: normalized into one period, never left as an unbounded product.
	var offset: int = int(described.phase_offset)
	assert_true(offset >= 0 and offset < PERIOD, "phase offset must normalize into [0, period), got %d" % offset)
	assert_eq(offset, (BIG_ID * STRIDE) % PERIOD, "and it must be exactly the normalized product")

	# PERIOD and AMPLITUDE: identical to the reference, untouched by actor_id.
	assert_eq(int(described.half_period), PERIOD / 2, "actor_id must not change the period")
	assert_eq(float(described.degrees), DEGREES, "actor_id must not change the amplitude")

	# WAVEFORM: the same square wave, merely shifted by that offset.
	var flips: int = 0
	var previous: int = int(shifted.debug_describe_approach_weave(BIG_ID, PLAYER_ID).sign)
	for i in SAMPLES:
		shifted.tick([], DT)
		var current: int = int(shifted.debug_describe_approach_weave(BIG_ID, PLAYER_ID).sign)
		assert_eq(current, reference_signs[i + offset], "tick %d: a large actor_id must be a pure SHIFT of the reference wave" % i)
		if current != previous:
			flips += 1
		previous = current
	assert_eq(flips, SAMPLES / (PERIOD / 2), "flip count must match the reference period exactly")


func test_phase_offset_is_a_deterministic_function_of_actor_id() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(-2, 0, -14), DEGREES, PERIOD, RELEASE, STRIDE, ENEMY_ID)
	_register_enemy(sim, Vector3(2, 0, -14), DEGREES, PERIOD, RELEASE, STRIDE, SECOND_ENEMY_ID)
	assert_eq(int(sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID).phase_offset), ENEMY_ID * STRIDE)
	assert_eq(int(sim.debug_describe_approach_weave(SECOND_ENEMY_ID, PLAYER_ID).phase_offset), SECOND_ENEMY_ID * STRIDE)


# ---------------------------------------------------------------------------------
# 4. THE RELEASE HINGE — both sides of it.
# ---------------------------------------------------------------------------------

func test_outside_the_release_distance_the_path_weaves() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -8), DEGREES, PERIOD, RELEASE, STRIDE)
	var described: Dictionary = sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID)
	assert_false(bool(described.released), "8.0 units is well outside the 3.0 release hinge")
	var headings: Array[Vector3] = _step_headings(sim, 5)
	assert_gt(absf(headings[0].x), 0.01, "an unreleased approach must carry lateral movement")


func test_inside_the_release_distance_the_path_straightens() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -2.5), DEGREES, PERIOD, RELEASE, STRIDE)
	var described: Dictionary = sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID)
	assert_true(bool(described.released), "2.5 units is inside the 3.0 release hinge")
	var headings: Array[Vector3] = _step_headings(sim, 5)
	for i in headings.size():
		if headings[i] == Vector3.ZERO:
			continue
		assert_almost_eq(headings[i].x, 0.0, 0.0001, "tick %d: a released approach must run dead straight" % i)


func test_the_hinge_is_crossed_exactly_once_on_a_full_approach() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -9), DEGREES, PERIOD, RELEASE, STRIDE)
	var transitions: int = 0
	var previous: bool = bool(sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID).released)
	for i in 200:
		sim.tick([], DT)
		var current: bool = bool(sim.debug_describe_approach_weave(ENEMY_ID, PLAYER_ID).released)
		if current != previous:
			transitions += 1
		previous = current
	assert_eq(transitions, 1, "the hinge must latch once on approach, never oscillate at the boundary")
	assert_true(previous, "the actor must end the approach in the released (straight) state")


# ---------------------------------------------------------------------------------
# 5. NEGATIVE SPACE — every neighbouring branch of the shared decision function is
#    asserted UNCHANGED (BRAIN: reordering/altering shared decisions invalidates setups).
# ---------------------------------------------------------------------------------

func test_retreat_is_never_woven() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	# Spawned INSIDE minimum_attack_distance so the retreat branch is the live one.
	_register_enemy(sim, Vector3(0, 0, -0.5), DEGREES, PERIOD, RELEASE, STRIDE, ENEMY_ID, 2.0)
	# Cooldown busy: isolate MOVEMENT from attack priority, exactly as
	# test_enemy_ai.gd::test_too_close_backs_away does. Without this the actor is
	# eligible to attack at 0.5 units, commits a windup, and freezes -- the test would
	# then assert nothing at all rather than assert retreat.
	sim._next_fire_tick[ENEMY_ID] = 100000
	var headings: Array[Vector3] = _step_headings(sim, 10)
	var moved: int = 0
	for heading in headings:
		if heading != Vector3.ZERO:
			moved += 1
	assert_gt(moved, 0, "the retreat branch must actually run, or this test proves nothing")
	for i in headings.size():
		if headings[i] == Vector3.ZERO:
			continue
		assert_almost_eq(headings[i].x, 0.0, 0.0001, "tick %d: a weaving retreat reads as fleeing indecision -- retreat stays straight" % i)
		assert_lt(headings[i].z, 0.0, "tick %d: the enemy should be moving AWAY from the player" % i)


func test_in_band_hold_stays_still() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -1.45), DEGREES, PERIOD, RELEASE, STRIDE, ENEMY_ID, 1.4)
	var before: Vector3 = sim.entities[ENEMY_ID]
	_tick(sim, 10)
	assert_almost_eq(sim.entities[ENEMY_ID].x, before.x, 0.0001, "an in-band hold must not acquire lateral drift from the weave")


func test_position_stays_frozen_during_windup() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	sim.add_entity(ENEMY_ID, Vector3(0, 0, -1.0), 3.0)
	sim.register_combatant(ENEMY_ID, 20.0, &"fang", 15, 1.0, &"enemy")
	sim.register_weapon(WEAPON_ID, 5.0, &"force", 1.5, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY_ID, CombatTestHelpers.single_action_repertoire(WEAPON_ID, 1.5, 20), Vector3(0, 0, -1.0), 1.5, 0.0, 20.0, 40.0, 0, 0, DEGREES, PERIOD, RELEASE, STRIDE)
	sim.tick([], DT)  # commits the windup
	var during: Vector3 = sim.entities[ENEMY_ID]
	_tick(sim, 10)
	assert_eq(sim.entities[ENEMY_ID], during, "a committed windup freezes movement -- the weave must not leak into it")


func test_flinched_actor_emits_no_woven_movement() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -8), DEGREES, PERIOD, RELEASE, STRIDE)
	sim.set_flinch_tuning(30, 20)
	sim.register_flinch_profile(ENEMY_ID, 1.0)
	sim.register_weapon(&"test_poke", 10.0, &"force", 20.0, 180.0, 0.0, 0)
	# register_weapon is the flat legacy path and carries no flinch params, so capability
	# is patched onto the resolved record -- the same idiom test_flinch.gd uses. Without
	# it the weapon defaults to "none", nothing flinches, and this test silently becomes
	# an assertion about ordinary approach movement.
	sim._weapons["test_poke"].flinch_capability = "pressure"
	sim.set_equipped_weapon(PLAYER_ID, &"test_poke")
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	var flinched: bool = false
	for event in events:
		if event.kind == "flinched":
			flinched = true
	assert_true(flinched, "the mechanism must fire before its consequences mean anything (BRAIN)")
	var frozen: Vector3 = sim.entities[ENEMY_ID]
	_tick(sim, 5)
	assert_eq(sim.entities[ENEMY_ID], frozen, "a flinched enemy yields no Command at all -- including no woven approach")


# ---------------------------------------------------------------------------------
# 6. DETERMINISM — the weave adds no RNG and no hidden state (GAME-RULES §1.3).
# ---------------------------------------------------------------------------------

func test_identical_setups_produce_identical_paths() -> void:
	var paths: Array = []
	for run in 2:
		var s := SimWorld.new()
		_register_player(s, Vector3(0, 0, 0))
		_register_enemy(s, Vector3(-2, 0, -14), DEGREES, PERIOD, RELEASE, STRIDE, ENEMY_ID)
		_register_enemy(s, Vector3(2, 0, -14), DEGREES, PERIOD, RELEASE, STRIDE, SECOND_ENEMY_ID)
		var recorded: Array[String] = []
		for i in 120:
			s.tick([], DT)
			recorded.append("%.6f,%.6f|%.6f,%.6f" % [s.entities[ENEMY_ID].x, s.entities[ENEMY_ID].z, s.entities[SECOND_ENEMY_ID].x, s.entities[SECOND_ENEMY_ID].z])
		paths.append(recorded)
	assert_eq(paths[0], paths[1], "the weave must be a pure function of (actor_id, tick) -- no RNG, no hidden state")
