extends GutTest
## switch_weapon Command (Phase D step 8 Phase 2): advances a registered loadout,
## wraps, carries no weapon_id, and never touches the shared per-actor fire cooldown.

var sim: SimWorld

const ACTOR_ID := 0
const WEAPON_A := &"weapon_a"
const WEAPON_B := &"weapon_b"


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ACTOR_ID, Vector3.ZERO, 4.0)
	sim.register_weapon(WEAPON_A, 10.0, &"force", 2.0, 60.0, 1.0)
	sim.register_weapon(WEAPON_B, 10.0, &"force", 2.0, 60.0, 1.0)
	sim.set_weapon_loadout(ACTOR_ID, [WEAPON_A, WEAPON_B])
	sim.set_equipped_weapon(ACTOR_ID, WEAPON_A)


func _switch() -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ACTOR_ID, "switch_weapon")], 1.0 / 30.0)


func test_switch_advances_to_next_weapon_in_loadout() -> void:
	var events := _switch()
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, "weapon_switched")
	assert_eq(events[0].payload, {"actor_id": ACTOR_ID, "weapon_id": String(WEAPON_B)})


func test_switch_wraps_around_the_loadout() -> void:
	_switch()  # A -> B
	var events := _switch()  # B -> A
	assert_eq(events[0].payload.get("weapon_id"), String(WEAPON_A))


func test_switch_with_no_registered_loadout_is_a_noop() -> void:
	sim = SimWorld.new()
	sim.add_entity(1, Vector3.ZERO, 4.0)
	sim.register_weapon(WEAPON_A, 10.0, &"force", 2.0, 60.0, 1.0)
	sim.set_equipped_weapon(1, WEAPON_A)
	var events := sim.tick([Command.new(sim.tick_count, 1, "switch_weapon")], 1.0 / 30.0)
	assert_eq(events.size(), 0)


func test_switch_does_not_reset_the_shared_fire_cooldown() -> void:
	# fire_interval_ticks=15 so a second attack this soon is cooldown-rejected
	# regardless of which of the two (identically-cadenced) weapons is equipped.
	sim.register_weapon(WEAPON_A, 10.0, &"force", 2.0, 60.0, 1.0, 15)
	sim.register_weapon(WEAPON_B, 10.0, &"force", 2.0, 60.0, 1.0, 15)
	sim.tick([Command.new(sim.tick_count, ACTOR_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	_switch()
	var events := sim.tick([Command.new(sim.tick_count, ACTOR_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
	var rejected := events.filter(func(e): return e.kind == "attack_rejected")
	assert_eq(rejected.size(), 1)
	assert_eq(rejected[0].payload.get("reason"), "on_cooldown")
