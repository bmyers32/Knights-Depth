extends GutTest
## Gun (ranged) attack pipeline: deferred travel-time resolution, swept-segment
## collision, and reuse of the SAME hit-resolution tail melee uses (iframes/matrix/
## shield/knockback/death) — Phase D step 6, HANDOFF. speed=30.0 is chosen so one
## sim tick (dt=1/30) advances the projectile exactly 1.0 unit, keeping tick math
## exact and readable across every test below.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const GUN_ID := &"wand_test"
const DT := 1.0 / 30.0


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_gun(GUN_ID, 10.0, &"force", 30.0, 5, 0.5, 1.0)
	sim.set_equipped_weapon(ATTACKER_ID, GUN_ID)
	sim.set_damage_matrix({}, 1.5, 0.5)


func _register_target(position: Vector3, max_health: float = 20.0) -> void:
	sim.add_entity(TARGET_ID, position, 0.0)
	sim.register_combatant(TARGET_ID, max_health, &"test_target")


func _fire(aim: Vector3 = Vector3(0, 0, -1)) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim})], DT)


func _noop() -> Array[Event]:
	return sim.tick([], DT)


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- Spawn / deferred resolution ---

func test_fire_emits_projectile_fired_and_no_immediate_hit() -> void:
	_register_target(Vector3(0, 0, -5))
	var events := _fire()
	assert_eq(_events_of_kind(events, "projectile_fired").size(), 1)
	assert_eq(_events_of_kind(events, "hit").size(), 0, "a shot must not resolve on its own spawn tick")


# --- Rate limit (fire_interval_ticks, default 0 -- a no-op gate unless configured) ---

func test_fire_interval_rejects_a_second_shot_before_the_cooldown_elapses() -> void:
	sim.register_gun(GUN_ID, 10.0, &"force", 30.0, 5, 0.5, 1.0, 3)
	sim.set_equipped_weapon(ATTACKER_ID, GUN_ID)
	_fire()
	var events := _fire()
	var rejected := _events_of_kind(events, "attack_rejected")
	assert_eq(rejected.size(), 1)
	assert_eq(rejected[0].payload.get("reason"), "on_cooldown")
	assert_eq(_events_of_kind(events, "projectile_fired").size(), 0, "a rejected attack must not also spawn a shot")


func test_fire_interval_allows_a_new_shot_once_it_elapses() -> void:
	sim.register_gun(GUN_ID, 10.0, &"force", 30.0, 5, 0.5, 1.0, 2)
	sim.set_equipped_weapon(ATTACKER_ID, GUN_ID)
	_fire()  # tick 0: fires, cooldown until tick 2
	_noop()  # tick 1: still on cooldown if fired again here
	var events := _fire()  # tick 2: cooldown boundary is inclusive (>=, not >)
	assert_eq(_events_of_kind(events, "projectile_fired").size(), 1, "a shot fired exactly on the cooldown boundary tick must be accepted")


# --- Travel / arrival ---

func test_projectile_hits_target_only_on_its_arrival_tick() -> void:
	_register_target(Vector3(0, 0, -3))
	_fire()
	assert_eq(_events_of_kind(_noop(), "hit").size(), 0, "tick 1 of travel: still 2 units short")
	assert_eq(_events_of_kind(_noop(), "hit").size(), 0, "tick 2 of travel: still 1 unit short")
	var arrival := _noop()  # tick 3 of travel: segment endpoint lands exactly on the target
	var hits := _events_of_kind(arrival, "hit")
	assert_eq(hits.size(), 1)
	assert_almost_eq(hits[0].payload["damage"], 10.0, 0.001)
	assert_almost_eq(sim.entities[TARGET_ID].z, -4.0, 0.001, "a projectile hit must apply its own knockback_distance, same as melee")


func test_projectile_expires_after_max_lifetime_with_no_hit() -> void:
	_fire()  # aimed into open space, nothing registered to hit
	var expired_count := 0
	for _i in range(5):
		expired_count += _events_of_kind(_noop(), "projectile_expired").size()
	assert_eq(expired_count, 1, "max_lifetime_ticks=5 must expire exactly once, never a hit")


# --- Ownership / eligibility ---

func test_owner_cannot_be_hit_by_own_projectile() -> void:
	sim.register_combatant(ATTACKER_ID, 10.0, &"test_target")
	_fire()
	var hit_count := 0
	for _i in range(5):
		hit_count += _events_of_kind(_noop(), "hit").size()
	assert_eq(hit_count, 0, "the shooter must never be a valid target for its own shot")


func test_dead_target_is_ignored_by_projectile() -> void:
	_register_target(Vector3(0, 0, -1))
	sim._health[TARGET_ID] = 0.0
	_fire()
	assert_eq(_events_of_kind(_noop(), "hit").size(), 0, "a dead target must not be a valid hit candidate")


# --- Shared pipeline reuse (the actual point of the refactor) ---

func test_shield_blocks_a_bullet_the_same_way_it_blocks_a_sword() -> void:
	_register_target(Vector3(0, 0, -1))
	sim.register_shield(TARGET_ID, 20.0, 1.0, 3, 2.0)
	sim.tick([Command.new(sim.tick_count, TARGET_ID, "block", {"held": true})], DT)  # rising edge -> HELD
	_fire()
	var events := _noop()  # 1-unit travel lands exactly on the target
	assert_eq(_events_of_kind(events, "blocked").size(), 1)
	assert_eq(_events_of_kind(events, "hit").size(), 0)
	assert_eq(sim._iframe_ticks_remaining.get(TARGET_ID, 0), 0, "a blocked bullet must never arm the i-frame timer, same as a blocked swing")


func test_iframes_absorb_a_bullet_the_same_way_they_absorb_a_sword() -> void:
	sim.add_entity(TARGET_ID, Vector3(0, 0, -1), 0.0)
	sim.register_combatant(TARGET_ID, 20.0, &"test_target", 5)
	sim._iframe_ticks_remaining[TARGET_ID] = 5
	_fire()
	var events := _noop()
	var absorbed := _events_of_kind(events, "attack_absorbed")
	assert_eq(absorbed.size(), 1)
	assert_eq(absorbed[0].payload.get("reason"), "iframes")
	assert_almost_eq(sim._health[TARGET_ID], 20.0, 0.001, "an absorbed bullet must deal zero damage")


# --- Swept-segment collision selection ---

func test_nearer_target_wins_when_both_intersect_the_same_tick_segment() -> void:
	sim.add_entity(1, Vector3(0, 0, -0.6), 0.0)
	sim.register_combatant(1, 20.0, &"test_target")
	sim.add_entity(5, Vector3(0, 0, -0.3), 0.0)
	sim.register_combatant(5, 20.0, &"test_target")
	_fire()
	var hits := _events_of_kind(_noop(), "hit")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].payload["target_id"], 5, "the nearer target along the swept segment must win, not registration/id order")


func test_lower_actor_id_breaks_an_exact_distance_tie() -> void:
	sim.add_entity(7, Vector3(0, 0, -0.5), 0.0)
	sim.register_combatant(7, 20.0, &"test_target")
	sim.add_entity(3, Vector3(0, 0, -0.5), 0.0)
	sim.register_combatant(3, 20.0, &"test_target")
	_fire()
	var hits := _events_of_kind(_noop(), "hit")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].payload["target_id"], 3, "an exact tie must break toward the lower actor_id, mirroring melee's determinism rule")


# --- Determinism ---

func test_identical_state_and_commands_produce_identical_projectile_trajectories() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_gun(GUN_ID, 10.0, &"force", 30.0, 5, 0.5, 1.0)
		local_sim.set_equipped_weapon(ATTACKER_ID, GUN_ID)
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		local_sim.add_entity(TARGET_ID, Vector3(0, 0, -3), 0.0)
		local_sim.register_combatant(TARGET_ID, 20.0, &"test_target")

		var event_kinds: Array = []
		event_kinds.append_array(local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT).map(func(e): return e.kind))
		for _t in range(3):
			event_kinds.append_array(local_sim.tick([], DT).map(func(e): return e.kind))

		results.append({
			"event_kinds": event_kinds,
			"target_position": local_sim.entities[TARGET_ID],
			"target_health": local_sim._health[TARGET_ID],
		})
	assert_eq(results[0], results[1], "an identical command sequence must produce an identical projectile trajectory and outcome")
