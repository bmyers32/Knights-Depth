extends GutTest
## Sword attack pipeline: facing/aim resolution, hit detection, damage matrix,
## knockback, death, rejection, and determinism (Phase D step 3, HANDOFF).

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"sword_A"


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	# Ally-filtering (locked defect fix): a valid target must have a DIFFERENT
	# allegiance than its attacker. Targets below default to "enemy" (register_
	# combatant's own default), so the attacker needs an explicit, different
	# allegiance or every attack in this file would filter as an allied contact.
	sim.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim.register_weapon(WEAPON_ID, 10.0, &"force", 2.0, 60.0, 1.0)
	sim.set_damage_matrix({"fang": {"weak_to": "pierce", "resists": "arc"}}, 1.5, 0.5)


func _register_fang(position: Vector3, max_health: float = 20.0) -> void:
	sim.add_entity(TARGET_ID, position, 0.0)
	sim.register_combatant(TARGET_ID, max_health, &"fang")


func _attack(aim: Vector3 = Vector3.ZERO, weapon_id: StringName = WEAPON_ID) -> Array[Event]:
	# Equip state is sim-owned (SimWorld.set_equipped_weapon) — the attack Command
	# itself carries only per-action intent (aim), never a weapon_id.
	sim.set_equipped_weapon(ATTACKER_ID, weapon_id)
	var command := Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": aim})
	return sim.tick([command], 1.0 / 30.0)


func _hit_events(events: Array[Event]) -> Array:
	return events.filter(func(e): return e.kind == "hit")


# --- Facing ---

func test_initial_facing_is_valid_and_normalized() -> void:
	_register_fang(Vector3(0, 0, -1))
	var events := _attack()
	assert_eq(_hit_events(events).size(), 1, "default facing should let a zero-aim attack hit a target directly ahead")


func test_nonzero_move_updates_facing() -> void:
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.RIGHT})], 1.0 / 30.0)
	_register_fang(Vector3(1, 0, 0))
	var events := _attack()
	assert_eq(_hit_events(events).size(), 1)


func test_zero_move_preserves_facing() -> void:
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.RIGHT})], 1.0 / 30.0)
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.ZERO})], 1.0 / 30.0)
	_register_fang(Vector3(1, 0, 0))
	var events := _attack()
	assert_eq(_hit_events(events).size(), 1, "facing should still be +X after a zero-direction move")


func test_invalid_or_zero_attack_aim_falls_back_to_stored_facing() -> void:
	_register_fang(Vector3(0, 0, -1))
	var events := _attack(Vector3.ZERO)
	assert_eq(_hit_events(events).size(), 1)


func test_explicit_attack_aim_can_differ_from_movement_direction() -> void:
	sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "move", {"direction": Vector3.RIGHT})], 1.0 / 30.0)
	_register_fang(Vector3(0, 0, -1))
	var events := _attack(Vector3(0, 0, -1))
	assert_eq(_hit_events(events).size(), 1, "explicit aim should land despite moving in a different direction")


func test_accepted_attack_updates_stored_facing_to_resolved_aim() -> void:
	_register_fang(Vector3(1, 0, 0))
	_attack(Vector3(1, 0, 0))
	var events := _attack(Vector3.ZERO)
	assert_eq(_hit_events(events).size(), 1, "a later zero-aim attack should use the previous attack's resolved aim as facing")


func test_rejected_attack_does_not_update_facing() -> void:
	_register_fang(Vector3(0, 0, -1))
	_attack(Vector3(1, 0, 0), &"nonexistent_weapon")
	var events := _attack(Vector3.ZERO)
	assert_eq(_hit_events(events).size(), 1, "a rejected attack must not have turned the attacker toward its aim")


# --- Hit detection ---

## Point-blank melee (locked, pre-gate fix pass): this bypass lives in the shared
## hit path, not AI-specific code -- the Envoy's own sword has the identical
## zero-offset cone seam. A zero-vector aim would normally fall back to stored
## facing, but at true zero separation the cone check doesn't apply at all.
func test_attack_resolves_at_near_zero_separation() -> void:
	_register_fang(Vector3.ZERO)  # exact same position as the attacker
	var events := _attack(Vector3.ZERO)
	assert_eq(_hit_events(events).size(), 1, "point-blank (near-zero separation) melee must still resolve a hit")


func test_target_in_range_and_inside_cone_is_hit() -> void:
	_register_fang(Vector3(0, 0, -1.5))
	var events := _attack(Vector3(0, 0, -1))
	assert_eq(_hit_events(events).size(), 1)


func test_target_behind_attacker_is_not_hit() -> void:
	_register_fang(Vector3(0, 0, 1.5))
	var events := _attack(Vector3(0, 0, -1))
	assert_eq(_hit_events(events).size(), 0)


func test_target_inside_cone_but_outside_reach_is_not_hit() -> void:
	_register_fang(Vector3(0, 0, -5))
	var events := _attack(Vector3(0, 0, -1))
	assert_eq(_hit_events(events).size(), 0)


func test_target_inside_reach_but_outside_cone_is_not_hit() -> void:
	_register_fang(Vector3(1.9, 0, 0))
	var events := _attack(Vector3(0, 0, -1))
	assert_eq(_hit_events(events).size(), 0)


func test_attacker_cannot_hit_itself() -> void:
	sim.register_combatant(ATTACKER_ID, 10.0, &"fang")
	var events := _attack(Vector3(0, 0, -1))
	assert_eq(_hit_events(events).size(), 0, "attacker must never appear as its own target")


func test_one_attack_cannot_hit_the_same_target_more_than_once() -> void:
	_register_fang(Vector3(0, 0, -1))
	var events := _attack(Vector3(0, 0, -1))
	assert_eq(_hit_events(events).size(), 1)


func test_multi_target_resolution_order_is_deterministic() -> void:
	_register_fang(Vector3(0, 0, -1))
	sim.add_entity(2, Vector3(0, 0, -1.2), 0.0)
	sim.register_combatant(2, 20.0, &"fang")
	var events := _attack(Vector3(0, 0, -1))
	var hit_targets: Array = []
	for event in _hit_events(events):
		hit_targets.append(event.payload.get("target_id"))
	assert_eq(hit_targets, [1, 2], "hit event order must follow actor_id sort, not dictionary iteration order")


# --- Damage matrix (GAME-RULES §3) ---

func test_pierce_receives_fangs_weakness_modifier() -> void:
	_register_fang(Vector3(0, 0, -1))
	sim.register_weapon(&"pierce_test", 10.0, &"pierce", 2.0, 60.0, 1.0)
	var events := _attack(Vector3(0, 0, -1), &"pierce_test")
	assert_almost_eq(_hit_events(events)[0].payload["damage"], 15.0, 0.001)


func test_arc_receives_fangs_resistance_modifier() -> void:
	_register_fang(Vector3(0, 0, -1))
	sim.register_weapon(&"arc_test", 10.0, &"arc", 2.0, 60.0, 1.0)
	var events := _attack(Vector3(0, 0, -1), &"arc_test")
	assert_almost_eq(_hit_events(events)[0].payload["damage"], 5.0, 0.001)


func test_force_remains_neutral() -> void:
	_register_fang(Vector3(0, 0, -1))
	var events := _attack(Vector3(0, 0, -1))
	assert_almost_eq(_hit_events(events)[0].payload["damage"], 10.0, 0.001)


func _register_target(family: StringName, position: Vector3, max_health: float = 20.0) -> void:
	sim.add_entity(TARGET_ID, position, 0.0)
	sim.register_combatant(TARGET_ID, max_health, family)


## Ooze/Watcher (Phase D step 7, HANDOFF) — same weak/resist mechanism proven above
## against Fang, exercised against the two families added this session so all three
## M1 damage-matrix rows have a concrete regression test (GAME-RULES §5: "damage-matrix
## unit tests both directions").
func test_umbral_receives_oozes_weakness_modifier() -> void:
	sim.set_damage_matrix({"ooze": {"weak_to": "umbral", "resists": "pierce"}}, 1.5, 0.5)
	_register_target(&"ooze", Vector3(0, 0, -1))
	sim.register_weapon(&"umbral_ooze_test", 10.0, &"umbral", 2.0, 60.0, 1.0)
	var events := _attack(Vector3(0, 0, -1), &"umbral_ooze_test")
	assert_almost_eq(_hit_events(events)[0].payload["damage"], 15.0, 0.001)


func test_pierce_receives_oozes_resistance_modifier() -> void:
	sim.set_damage_matrix({"ooze": {"weak_to": "umbral", "resists": "pierce"}}, 1.5, 0.5)
	_register_target(&"ooze", Vector3(0, 0, -1))
	sim.register_weapon(&"pierce_ooze_test", 10.0, &"pierce", 2.0, 60.0, 1.0)
	var events := _attack(Vector3(0, 0, -1), &"pierce_ooze_test")
	assert_almost_eq(_hit_events(events)[0].payload["damage"], 5.0, 0.001)


func test_arc_receives_watchers_weakness_modifier() -> void:
	sim.set_damage_matrix({"watcher": {"weak_to": "arc", "resists": "pierce"}}, 1.5, 0.5)
	_register_target(&"watcher", Vector3(0, 0, -1))
	sim.register_weapon(&"arc_watcher_test", 10.0, &"arc", 2.0, 60.0, 1.0)
	var events := _attack(Vector3(0, 0, -1), &"arc_watcher_test")
	assert_almost_eq(_hit_events(events)[0].payload["damage"], 15.0, 0.001)


func test_pierce_receives_watchers_resistance_modifier() -> void:
	sim.set_damage_matrix({"watcher": {"weak_to": "arc", "resists": "pierce"}}, 1.5, 0.5)
	_register_target(&"watcher", Vector3(0, 0, -1))
	sim.register_weapon(&"pierce_watcher_test", 10.0, &"pierce", 2.0, 60.0, 1.0)
	var events := _attack(Vector3(0, 0, -1), &"pierce_watcher_test")
	assert_almost_eq(_hit_events(events)[0].payload["damage"], 5.0, 0.001)


# --- Knockback & death ---

func test_knockback_resolves_through_the_sim() -> void:
	_register_fang(Vector3(0, 0, -1))
	_attack(Vector3(0, 0, -1))
	assert_almost_eq(sim.entities[TARGET_ID].z, -2.0, 0.001, "target should be pushed further along the attack direction")


func test_lethal_damage_emits_death_event() -> void:
	_register_fang(Vector3(0, 0, -1), 5.0)
	var events := _attack(Vector3(0, 0, -1))
	var died := events.filter(func(e): return e.kind == "died")
	assert_eq(died.size(), 1)
	assert_eq(died[0].payload["actor_id"], TARGET_ID)


func test_dead_targets_cannot_be_damaged_again() -> void:
	_register_fang(Vector3(0, 0, -1), 5.0)
	_attack(Vector3(0, 0, -1))
	var events := _attack(Vector3(0, 0, -1))
	assert_eq(_hit_events(events).size(), 0, "a dead target must not be a valid hit candidate")


# --- Rejection ---

func test_invalid_weapon_rejects_attack() -> void:
	var events := _attack(Vector3.ZERO, &"nonexistent_weapon")
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, "attack_rejected")
	assert_eq(events[0].payload["reason"], "invalid_weapon")


func test_dead_attacker_rejects_attack() -> void:
	sim.register_combatant(ATTACKER_ID, 0.0, &"fang")
	var events := _attack()
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, "attack_rejected")
	assert_eq(events[0].payload["reason"], "attacker_dead")


# --- Determinism ---

func test_identical_state_and_commands_produce_identical_results() -> void:
	_register_fang(Vector3(0, 0, -1))
	var sim2 := SimWorld.new()
	sim2.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim2.register_combatant(ATTACKER_ID, 999.0, &"envoy", 0, 0.0, &"player")
	sim2.register_weapon(WEAPON_ID, 10.0, &"force", 2.0, 60.0, 1.0)
	sim2.set_damage_matrix({"fang": {"weak_to": "pierce", "resists": "arc"}}, 1.5, 0.5)
	sim2.add_entity(TARGET_ID, Vector3(0, 0, -1), 0.0)
	sim2.register_combatant(TARGET_ID, 20.0, &"fang")

	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	sim2.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	var command1 := Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})
	var command2 := Command.new(sim2.tick_count, ATTACKER_ID, "attack", {"aim": Vector3(0, 0, -1)})
	var events1 := sim.tick([command1], 1.0 / 30.0)
	var events2 := sim2.tick([command2], 1.0 / 30.0)

	assert_eq(events1.size(), events2.size())
	for i in range(events1.size()):
		assert_eq(events1[i].kind, events2[i].kind)
		assert_eq(events1[i].payload, events2[i].payload)
	assert_eq(sim.entities[TARGET_ID], sim2.entities[TARGET_ID])
	assert_eq(sim.entities[ATTACKER_ID], sim2.entities[ATTACKER_ID])
