extends GutTest
## Lunge pass-through fix (manual-pass, GAME-RULES §3): authored melee lunge
## movement clamps to hostile contact -- a swept (not endpoint-only) check against
## the authoritative combined-combat-radii contact distance (SimWorld._contact_
## distance, shared with Burn's own contact-spread formula). Attack-authored
## movement semantics only -- ordinary walking, enemy movement, walls, and bounds
## stay fully unconstrained (ROADMAP P20 remains open).

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const OTHER_TARGET_ID := 2
const ALLY_ID := 3
const WEAPON_ID := &"test_clamp_sword"
const TARGET_FAMILY := &"test_target"

const LUNGE_DISTANCE := 6.0
const LUNGE_DURATION_TICKS := 12
const HIT_ACTIVE_TICKS := 8
const KNOCKBACK_DISTANCE := 2.0
const FIRE_INTERVAL_TICKS := 3

const ATTACKER_RADIUS := 0.4
const TARGET_RADIUS := 0.6
const CONTACT_DISTANCE := ATTACKER_RADIUS + TARGET_RADIUS  # 1.0, 0.0 padding


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, ATTACKER_RADIUS, &"player")
	sim.set_damage_matrix({}, 1.5, 0.5)
	_register_weapon(sim)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)


func _profile(damage: float) -> Dictionary:
	return {
		"damage": damage,
		"damage_type": &"force",
		"reach": 8.0,  # generous -- reach/cone aren't the focus of these tests
		"cone_half_angle_degrees": 90.0,
		"knockback_distance": KNOCKBACK_DISTANCE,
		"fire_interval_ticks": FIRE_INTERVAL_TICKS,
		"status_id": &"",
		"status_proc_chance": 0.0,
		"interrupt_strength": 0,
		"lunge_distance": LUNGE_DISTANCE,
		"lunge_duration_ticks": LUNGE_DURATION_TICKS,
		"hit_active_ticks": HIT_ACTIVE_TICKS,
		"windup_ticks": 0,
	}


func _register_weapon(s: SimWorld) -> void:
	var combo_profiles: Array[Dictionary] = [_profile(5.0), _profile(5.0), _profile(5.0)]
	s.register_melee_profiles(WEAPON_ID, combo_profiles, _profile(20.0), 999, 50)


func _register_target(id: int, position: Vector3, radius: float = TARGET_RADIUS, allegiance: StringName = &"enemy") -> void:
	sim.add_entity(id, position, 0.0)
	sim.register_combatant(id, 999.0, TARGET_FAMILY, 0, radius, allegiance)


func _press(aim: Vector3 = Vector3(0, 0, -1)) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "pressed"})], 1.0 / 30.0)


func _release(aim: Vector3 = Vector3(0, 0, -1)) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim, "phase": "released"})], 1.0 / 30.0)


func _tap(aim: Vector3 = Vector3(0, 0, -1)) -> Array[Event]:
	_press(aim)
	return _release(aim)


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _hit_events(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "hit")


func test_lunge_stops_at_shared_contact_distance() -> void:
	# Target close enough that the clamp forms well BEFORE hit_tick (checked at
	# rest, pre-hit/pre-knockback -- knockback legitimately opens a gap afterward,
	# which is a separate, already-covered behavior, not what this test targets).
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	_tap()
	for _i in range(6):
		_tick_noop()
	var resting_distance: float = sim.entities[ATTACKER_ID].distance_to(sim.entities[TARGET_ID])
	assert_almost_eq(resting_distance, CONTACT_DISTANCE, 0.01, "the attacker must rest exactly at the shared contact distance")


func test_attacker_never_passes_the_far_side_of_a_contacted_target() -> void:
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	_tap()
	for _i in range(LUNGE_DURATION_TICKS + 5):
		_tick_noop()
	assert_true(sim.entities[ATTACKER_ID].z > -3.0, "the attacker must never cross to the far (more negative Z) side of the target")


func test_clamp_holds_through_remaining_ticks_despite_knockback() -> void:
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	_tap()
	for _i in range(LUNGE_DURATION_TICKS + 5):
		_tick_noop()
	assert_lt(sim.entities[TARGET_ID].z, -3.0 - 1.5, "sanity: the target was knocked back, opening a gap")
	var attacker_position_snapshot: Vector3 = sim.entities[ATTACKER_ID]
	for _i in range(10):
		_tick_noop()
	assert_almost_eq(sim.entities[ATTACKER_ID].z, attacker_position_snapshot.z, 0.001, "the attacker must remain resting in place -- no chase into the knockback gap")


func test_contacted_target_remains_in_forward_lane_for_next_combo_step() -> void:
	# Zero knockback for this test -- isolates "does the next swing's own fresh
	# sweep immediately re-clamp against the same still-nearby target" from
	# knockback's separate gap-opening behavior (covered above).
	var zero_kb_profiles: Array[Dictionary] = []
	for _i in range(3):
		var p: Dictionary = _profile(5.0)
		p.knockback_distance = 0.0
		zero_kb_profiles.append(p)
	var zero_kb_charge: Dictionary = _profile(20.0)
	zero_kb_charge.knockback_distance = 0.0
	sim.register_melee_profiles(WEAPON_ID, zero_kb_profiles, zero_kb_charge, 999, 50)
	_register_target(TARGET_ID, Vector3(0, 0, -3))

	_tap()  # hit1
	for _i in range(LUNGE_DURATION_TICKS + FIRE_INTERVAL_TICKS + 2):
		_tick_noop()
	# The clamp is immediate (attacker already rests exactly at contact distance,
	# so hit2's own sweep starts "already inside" -- t=0), but hit2's HIT still only
	# resolves hit_active_ticks after ITS OWN execution start, same as hit1.
	var all_events: Array[Event] = _tap()  # hit2 -- a fresh sweep from the resting position
	for _i in range(HIT_ACTIVE_TICKS + 2):
		all_events.append_array(_tick_noop())
	var hits := _hit_events(all_events)
	assert_eq(hits.size(), 1, "the target must still be hit -- it never left the forward lane")
	assert_almost_eq(sim.entities[ATTACKER_ID].distance_to(sim.entities[TARGET_ID]), CONTACT_DISTANCE, 0.01, "hit2 must re-clamp at the same contact distance")


## Checks the clamp field directly, not hit events -- this weapon's generous
## reach/cone (deliberately not the focus of these tests) means hit RESOLUTION
## sweeps every target within range independently of which one clamped the LUNGE,
## so hit events aren't a reliable signal for "which target won the sweep."
func test_nearest_target_wins() -> void:
	_register_target(TARGET_ID, Vector3(0, 0, -3))  # farther
	_register_target(OTHER_TARGET_ID, Vector3(0, 0, -1.5))  # nearer
	_tap()
	for _i in range(3):
		_tick_noop()
	assert_eq(int(sim._melee_hold[ATTACKER_ID].get("clamped_target_id", -1)), OTHER_TARGET_ID, "the nearer target along the sweep must be contacted first")


func test_actor_id_tie_break_when_equidistant() -> void:
	_register_target(OTHER_TARGET_ID, Vector3(0, 0, -3))
	_register_target(TARGET_ID, Vector3(0, 0, -3))  # exact same position -- a genuine tie
	_tap()
	for _i in range(3):
		_tick_noop()
	assert_eq(int(sim._melee_hold[ATTACKER_ID].get("clamped_target_id", -1)), TARGET_ID, "an exact tie must break toward the lower actor_id (TARGET_ID=1 < OTHER_TARGET_ID=2)")


func test_allies_never_clamp_the_lunge() -> void:
	sim.add_entity(ALLY_ID, Vector3(0, 0, -3), 0.0)
	sim.register_combatant(ALLY_ID, 999.0, TARGET_FAMILY, 0, TARGET_RADIUS, &"player")  # same allegiance as the attacker
	_tap()
	for _i in range(LUNGE_DURATION_TICKS + 5):
		_tick_noop()
	assert_almost_eq(sim.entities[ATTACKER_ID].z, -LUNGE_DISTANCE, 0.01, "an ally in the path must never clamp the lunge -- full distance applies")


func test_no_target_lunge_distance_unchanged() -> void:
	_tap()
	for _i in range(LUNGE_DURATION_TICKS + 5):
		_tick_noop()
	assert_almost_eq(sim.entities[ATTACKER_ID].z, -LUNGE_DISTANCE, 0.01, "with nothing in the path, the full authored distance must apply, exactly as before this change")


## Displacement-only regression pair (locked requirement): clamped and unclamped
## executions of the IDENTICAL profile must produce identical hit_tick/end_tick/
## cooldown-arming, differing only in final displacement.
func test_clamped_and_unclamped_executions_have_identical_timing() -> void:
	var expected_hit_tick: int = 1 + HIT_ACTIVE_TICKS
	var expected_end_tick: int = 1 + LUNGE_DURATION_TICKS

	# Unclamped: nothing in the path.
	_press()
	_release()
	var unclamped_hold: Dictionary = sim._melee_hold[ATTACKER_ID]
	assert_eq(int(unclamped_hold.hit_tick), expected_hit_tick)
	assert_eq(int(unclamped_hold.end_tick), expected_end_tick)
	for _i in range(LUNGE_DURATION_TICKS + 5):
		_tick_noop()
	var unclamped_cooldown: int = sim._next_fire_tick.get(ATTACKER_ID, 0)
	assert_almost_eq(sim.entities[ATTACKER_ID].z, -LUNGE_DISTANCE, 0.01, "sanity: unclamped run traveled the full distance")

	# Clamped: fresh sim, a target in the path.
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, ATTACKER_RADIUS, &"player")
	sim.set_damage_matrix({}, 1.5, 0.5)
	_register_weapon(sim)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	_press()
	_release()
	var clamped_hold: Dictionary = sim._melee_hold[ATTACKER_ID]
	assert_eq(int(clamped_hold.hit_tick), expected_hit_tick, "contact clamping must never alter hit_tick")
	assert_eq(int(clamped_hold.end_tick), expected_end_tick, "contact clamping must never alter end_tick")
	for _i in range(LUNGE_DURATION_TICKS + 5):
		_tick_noop()
	var clamped_cooldown: int = sim._next_fire_tick.get(ATTACKER_ID, 0)
	assert_eq(clamped_cooldown, unclamped_cooldown, "cooldown must arm at the identical tick regardless of clamping")
	assert_lt(sim.entities[ATTACKER_ID].distance_to(Vector3.ZERO), LUNGE_DISTANCE - 0.5, "sanity: the clamped run's displacement genuinely differs from the unclamped run")


func test_target_death_at_hit_active_tick_clears_clamp_and_resumes_next_tick_only() -> void:
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	sim._health[TARGET_ID] = 1.0  # dies to the first hit (damage 5.0)
	_tap()
	for _i in range(HIT_ACTIVE_TICKS - 1):
		_tick_noop()
	var position_before_death_tick: Vector3 = sim.entities[ATTACKER_ID]
	var death_tick_events := _tick_noop()  # the hit-active tick: hit resolves, target dies, clamp clears
	assert_eq(death_tick_events.filter(func(e): return e.kind == "died").size(), 1, "sanity: the target died this tick")
	assert_almost_eq(sim.entities[ATTACKER_ID].z, position_before_death_tick.z, 0.001, "the death tick itself must apply zero movement -- never retroactively applied")
	var position_before_resume: Vector3 = sim.entities[ATTACKER_ID]
	_tick_noop()
	assert_lt(sim.entities[ATTACKER_ID].z, position_before_resume.z, "movement must resume starting the tick AFTER death, not the death tick itself")


func test_despawn_or_invalid_target_clears_the_clamp() -> void:
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	_tap()
	for _i in range(6):  # enough to establish the clamp, well before hit_tick(9)
		_tick_noop()
	assert_true(sim._melee_hold[ATTACKER_ID].has("clamped_target_id"), "sanity: clamped")
	# Simulate despawn/invalidation WITHOUT the normal death pipeline (bypasses
	# _clear_clamps_targeting entirely) -- the movement phase's own defensive
	# fallback check must still catch it.
	sim._health[TARGET_ID] = 0.0
	var position_before: Vector3 = sim.entities[ATTACKER_ID]
	_tick_noop()
	assert_false(sim._melee_hold[ATTACKER_ID].has("clamped_target_id"), "the defensive fallback must clear an invalid clamp target")
	assert_almost_eq(sim.entities[ATTACKER_ID].z, position_before.z, 0.001, "the discovery tick itself must apply zero movement")


func test_surviving_knockback_opens_gap_without_chase_or_passthrough() -> void:
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	_tap()
	for _i in range(LUNGE_DURATION_TICKS + 5):
		_tick_noop()
	var distance_after_hit: float = sim.entities[ATTACKER_ID].distance_to(sim.entities[TARGET_ID])
	assert_gt(distance_after_hit, CONTACT_DISTANCE + 0.5, "surviving knockback must open a real gap, not keep the attacker glued at exactly contact distance")
	var attacker_position_snapshot: Vector3 = sim.entities[ATTACKER_ID]
	for _i in range(10):
		_tick_noop()
	assert_almost_eq(sim.entities[ATTACKER_ID].z, attacker_position_snapshot.z, 0.001, "no chase toward the target's new position")


func test_clamped_pair_remains_eligible_for_burn_contact_spread() -> void:
	sim.register_status(&"burn", 2.0, 5, 20)
	sim.set_status_priority({"burn": 1})
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	_tap()
	for _i in range(5):  # clamped well before hit_tick(9), before any knockback
		_tick_noop()
	assert_true(sim._melee_hold[ATTACKER_ID].has("clamped_target_id"), "sanity: clamped")
	assert_true(sim._actors_overlap(ATTACKER_ID, TARGET_ID), "the clamped resting distance must itself qualify as Burn contact -- same shared formula")


func test_shield_cancel_after_contact_behaves_per_locked_rules() -> void:
	sim.register_shield(ATTACKER_ID, 20.0, 1.0, 3, 1.0)
	_register_target(TARGET_ID, Vector3(0, 0, -3))
	_tap()
	for _i in range(5):  # clamped, pre-hit
		_tick_noop()
	assert_true(sim._melee_hold[ATTACKER_ID].has("clamped_target_id"), "sanity: clamped")
	var health_before: float = sim._health[TARGET_ID]
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "block", {"held": true})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "melee_hold_canceled").size(), 1)
	assert_almost_eq(sim._health[TARGET_ID], health_before, 0.001, "pre-hit cancel: no damage, per the existing locked shield-cancel rules")
	assert_false(sim._melee_hold.has(ATTACKER_ID))


func test_ordinary_walking_is_unaffected_by_the_clamp_mechanic() -> void:
	_register_target(TARGET_ID, Vector3(0, 0, -1))
	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "moved").size(), 1, "ordinary walking must never clamp -- only authored attack lunge does")
	assert_lt(sim.entities[ATTACKER_ID].z, 0.0, "the walk must have actually moved the attacker")


func test_contact_selection_and_final_positions_are_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, ATTACKER_RADIUS, &"player")
		local_sim.add_entity(TARGET_ID, Vector3(0, 0, -3), 0.0)
		local_sim.register_combatant(TARGET_ID, 999.0, TARGET_FAMILY, 0, TARGET_RADIUS, &"enemy")
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		_register_weapon(local_sim)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"})], 1.0 / 30.0)
		for _j in range(LUNGE_DURATION_TICKS + 5):
			local_sim.tick([], 1.0 / 30.0)
		results.append({"attacker_position": local_sim.entities[ATTACKER_ID], "target_position": local_sim.entities[TARGET_ID], "target_health": local_sim._health[TARGET_ID]})
	assert_eq(results[0], results[1], "an identical contact-clamp sequence must produce identical positions and outcomes")
