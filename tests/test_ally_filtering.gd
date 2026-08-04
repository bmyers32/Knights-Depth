extends GutTest
## Ally-filtering (locked defect fix, pre-gate pass): same-allegiance actors are never
## valid attack targets, checked FIRST at candidacy time in the shared hit path — no
## damage, knockback, defenses, status proc/RNG draw, or Events for an allied
## contact. Melee excludes allied candidates from its cone scan entirely; a
## projectile passes straight through an ally (never expires on one, no mutual
## bullet shields). Burn's own contact-spread eligibility is untouched (its
## player<->player rejection lives in _advance_contact_spread's own locked rules,
## covered in test_burn_spread.gd).

const ATTACKER_ID := 0
const ALLY_ID := 1
const PLAYER_ID := 2
const SEED := 4242


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


func test_melee_ignores_an_allied_enemy_and_still_hits_the_player() -> void:
	var sim := SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 20.0, &"fang", 0, 0.0, &"enemy")
	sim.add_entity(ALLY_ID, Vector3(0, 0, -1), 0.0)
	sim.register_combatant(ALLY_ID, 20.0, &"fang", 0, 0.0, &"enemy")
	sim.add_entity(PLAYER_ID, Vector3(0, 0, -1.8), 0.0)
	sim.register_combatant(PLAYER_ID, 30.0, &"envoy", 0, 0.0, &"player")
	sim.register_weapon(&"test_weapon", 10.0, &"force", 2.0, 60.0, 1.0)
	sim.set_equipped_weapon(ATTACKER_ID, &"test_weapon")
	sim.set_damage_matrix({}, 1.5, 0.5)

	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	var hits := _events_of_kind(events, "hit")
	assert_eq(hits.size(), 1, "only the player should be hit; the allied enemy is skipped entirely, not just missed")
	assert_eq(hits[0].payload.get("target_id"), PLAYER_ID)
	assert_almost_eq(sim._health[ALLY_ID], 20.0, 0.001, "an allied contact must deal zero damage")


func test_projectile_passes_through_an_ally_and_hits_the_player_behind_it() -> void:
	var sim := SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 20.0, &"fang", 0, 0.0, &"enemy")
	sim.add_entity(ALLY_ID, Vector3(0, 0, -1), 0.0)
	sim.register_combatant(ALLY_ID, 20.0, &"fang", 0, 0.0, &"enemy")
	sim.add_entity(PLAYER_ID, Vector3(0, 0, -3), 0.0)
	sim.register_combatant(PLAYER_ID, 30.0, &"envoy", 0, 0.0, &"player")
	sim.register_gun(&"test_gun", 10.0, &"force", 30.0, 5, 0.5, 1.0)  # speed=30 -> 1.0 unit/tick at dt=1/30
	sim.set_equipped_weapon(ATTACKER_ID, &"test_gun")
	sim.set_damage_matrix({}, 1.5, 0.5)

	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)  # spawn tick, no travel yet
	var events: Array[Event] = []
	for i in 4:  # tick 1 lands on the ally's position, tick 3 reaches the player
		events.append_array(sim.tick([], 1.0 / 30.0))
	var hits := _events_of_kind(events, "hit")
	assert_eq(hits.size(), 1, "the shot must pass through the ally and hit only the player")
	assert_eq(hits[0].payload.get("target_id"), PLAYER_ID)
	assert_almost_eq(sim._health[ALLY_ID], 20.0, 0.001, "a projectile passing through an ally must deal zero damage")


func test_player_versus_player_melee_is_rejected() -> void:
	var sim := SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_combatant(ATTACKER_ID, 30.0, &"envoy", 0, 0.0, &"player")
	sim.add_entity(PLAYER_ID, Vector3(0, 0, -1), 0.0)
	sim.register_combatant(PLAYER_ID, 30.0, &"envoy", 0, 0.0, &"player")
	sim.register_weapon(&"test_weapon", 10.0, &"force", 2.0, 60.0, 1.0)
	sim.set_equipped_weapon(ATTACKER_ID, &"test_weapon")
	sim.set_damage_matrix({}, 1.5, 0.5)

	var events := sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(_events_of_kind(events, "hit").size(), 0, "same-allegiance (player-vs-player) attacks must never land -- co-op insurance")
	assert_almost_eq(sim._health[PLAYER_ID], 30.0, 0.001)


func _fresh_proc_sim(chance: float = 0.5) -> SimWorld:
	var s := SimWorld.new()
	s.seed_combat_rng(SEED)
	s.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	s.register_combatant(ATTACKER_ID, 20.0, &"fang", 0, 0.0, &"enemy")
	s.register_weapon(&"proc_weapon", 10.0, &"force", 2.0, 60.0, 1.0, 0, &"burn", chance)
	s.set_equipped_weapon(ATTACKER_ID, &"proc_weapon")
	s.set_damage_matrix({}, 1.5, 0.5)
	s.register_status(&"burn", 4.0, 15, 90)
	s.set_status_priority({"burn": 0})
	return s


## Mirrors test_status_proc.gd's "fresh target, then move it far away" pattern --
## lets one SimWorld accumulate a clean, one-draw-per-attack sequence.
func _attack_fresh_hostile(s: SimWorld, target_id: int) -> Array[Event]:
	s.add_entity(target_id, Vector3(0, 0, -1), 0.0)
	s.register_combatant(target_id, 100.0, &"envoy", 0, 0.0, &"player")
	var events := s.tick([Command.new(s.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	s.entities[target_id] = Vector3(1000.0, 0.0, 0.0)
	return events


func test_allied_contact_consumes_no_proc_roll() -> void:
	var sim_a := _fresh_proc_sim()
	var draw1_a: String = _events_of_kind(_attack_fresh_hostile(sim_a, 10), "status_proc")[0].payload.get("result")
	var draw2_a: String = _events_of_kind(_attack_fresh_hostile(sim_a, 11), "status_proc")[0].payload.get("result")

	var sim_b := _fresh_proc_sim()
	var draw1_b: String = _events_of_kind(_attack_fresh_hostile(sim_b, 10), "status_proc")[0].payload.get("result")

	# An attack attempt against an ALLIED enemy in between -- must draw nothing.
	sim_b.add_entity(ALLY_ID, Vector3(0, 0, -1), 0.0)
	sim_b.register_combatant(ALLY_ID, 20.0, &"fang", 0, 0.0, &"enemy")
	var ally_events := sim_b.tick([Command.new(sim_b.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(_events_of_kind(ally_events, "hit").size(), 0)
	assert_eq(_events_of_kind(ally_events, "status_proc").size(), 0, "an allied contact must not even attempt a roll")
	sim_b.entities[ALLY_ID] = Vector3(1000.0, 0.0, 0.0)

	var draw2_b: String = _events_of_kind(_attack_fresh_hostile(sim_b, 11), "status_proc")[0].payload.get("result")

	assert_eq(draw1_a, draw1_b)
	assert_eq(draw2_a, draw2_b, "an allied contact in between must not shift the subsequent proc outcome")
