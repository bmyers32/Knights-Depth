extends GutTest
## Guards the content -> SimWorld registration path itself (ContentRegistrar), which
## arena.gd delegates to and headless fixtures reuse. Every authored value must arrive
## in sim unchanged: this class is the ONLY place content is unpacked, so a typo here
## silently retunes the whole game with no other test failing.
##
## Covers the paths arena.gd exercises but no scene test can reach headlessly --
## particularly register_enemy_ai, whose values only become observable once an enemy
## engages, which never happens at the arena's own spawn distances (~16 units vs an
## 8.0 detection radius).

const ACTOR_ID := 7

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()


# --- weapons: all three registration routes ---------------------------------------

func test_combo_sword_registers_every_authored_profile_field() -> void:
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_burn_A")
	ContentRegistrar.register_weapon(sim, &"sword_burn_A")

	var registered: Array = sim._melee_combo_profiles["sword_burn_A"]
	assert_eq(registered.size(), sword.combo_profiles.size(), "every authored combo step must register")
	for i in registered.size():
		var authored: MeleeAttackProfile = sword.combo_profiles[i]
		var resolved: Dictionary = registered[i]
		assert_eq(resolved.damage, authored.damage, "hit %d damage" % [i + 1])
		assert_eq(resolved.damage_type, String(authored.damage_type), "hit %d damage_type" % [i + 1])
		assert_eq(resolved.reach, authored.reach, "hit %d reach" % [i + 1])
		assert_eq(resolved.knockback_distance, authored.knockback_distance, "hit %d knockback" % [i + 1])
		assert_eq(resolved.fire_interval_ticks, authored.fire_interval_ticks, "hit %d cooldown" % [i + 1])
		assert_eq(resolved.status_id, String(authored.status_id), "hit %d status_id" % [i + 1])
		assert_eq(resolved.status_proc_chance, authored.status_proc_chance, "hit %d proc chance" % [i + 1])
		assert_eq(resolved.interrupt_strength, authored.interrupt_strength, "hit %d interrupt_strength" % [i + 1])
		assert_eq(resolved.lunge_distance, authored.lunge_distance, "hit %d lunge_distance" % [i + 1])
		assert_eq(resolved.lunge_duration_ticks, authored.lunge_duration_ticks, "hit %d lunge_duration" % [i + 1])
		assert_eq(resolved.hit_active_ticks, authored.hit_active_ticks, "hit %d hit_active_ticks" % [i + 1])

	assert_eq(sim._melee_charge_profiles["sword_burn_A"].damage, sword.charge_profile.damage, "charge profile damage")
	assert_eq(sim._melee_charge_profiles["sword_burn_A"].windup_ticks, sword.charge_profile.windup_ticks, "charge windup")
	assert_eq(sim._melee_charge_threshold_ticks["sword_burn_A"], sword.charge_threshold_ticks)
	assert_eq(sim._melee_combo_reset_ticks["sword_burn_A"], sword.combo_reset_ticks)
	assert_eq(sim._melee_input_buffer_ticks["sword_burn_A"], sword.input_buffer_ticks)


func test_gun_registers_through_the_projectile_route() -> void:
	var wand: GunStats = ContentDB.get_resource(&"weapon", &"wand_A")
	ContentRegistrar.register_weapon(sim, &"wand_A")
	var resolved: Dictionary = sim._weapons["wand_A"]
	assert_eq(resolved.resolution, "projectile", "a GunStats must never register as an instant melee sweep")
	assert_eq(resolved.damage, wand.base_damage)
	assert_eq(resolved.speed, wand.speed)
	assert_eq(resolved.max_lifetime_ticks, wand.max_lifetime_ticks)
	assert_eq(resolved.hit_radius, wand.hit_radius)
	assert_eq(resolved.knockback_distance, wand.knockback_distance)
	assert_eq(resolved.fire_interval_ticks, wand.fire_interval_ticks)


func test_sword_without_combo_profiles_stays_on_the_flat_route() -> void:
	ContentRegistrar.register_weapon(sim, &"sword_A")
	assert_false(sim._melee_combo_profiles.has("sword_A"), "an empty combo_profiles array must not route to the phased model")
	assert_eq(sim._weapons["sword_A"].resolution, "melee")


# --- enemies: body and AI halves ---------------------------------------------------

func test_enemy_body_registers_authored_defenses() -> void:
	var fang: FangStats = ContentDB.get_resource(&"enemy", &"fang")
	var position := Vector3(3, 0, -4)
	ContentRegistrar.register_enemy_body(sim, ACTOR_ID, &"fang", position)

	assert_eq(sim.entities[ACTOR_ID], position)
	assert_eq(sim._health[ACTOR_ID], fang.max_health)
	assert_eq(sim._families[ACTOR_ID], fang.family)
	assert_eq(sim._iframe_ticks_on_hit[ACTOR_ID], fang.iframe_ticks_on_hit,
		"the target's authored i-frame value must reach sim -- it doubles as an attacker cadence cap (BRAIN)")
	assert_eq(sim._combat_radius[ACTOR_ID], fang.combat_radius)
	assert_eq(sim._allegiance[ACTOR_ID], &"enemy")


func test_enemy_body_alone_registers_no_ai() -> void:
	ContentRegistrar.register_enemy_body(sim, ACTOR_ID, &"fang", Vector3.ZERO)
	assert_false(sim._ai_state.has(ACTOR_ID),
		"the body half must leave a target inert -- fixtures rely on this to isolate cadence from engagement")


func test_enemy_ai_registers_authored_tuning_and_equips_the_natural_weapon() -> void:
	var bite: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", &"fang_bite")
	var position := Vector3(-12, 0, -12)
	ContentRegistrar.register_enemy_body(sim, ACTOR_ID, &"fang", position)
	ContentRegistrar.register_enemy_ai(sim, ACTOR_ID, &"fang", position)

	var tuning: Dictionary = sim._ai_tuning[ACTOR_ID]
	assert_eq(tuning.preferred_attack_distance, bite.preferred_attack_distance)
	assert_eq(tuning.minimum_attack_distance, bite.minimum_attack_distance)
	assert_eq(tuning.windup_ticks, bite.windup_ticks)
	assert_eq(tuning.detection_radius, bite.detection_radius)
	assert_eq(tuning.leash_radius, bite.leash_radius)
	assert_eq(sim._ai_spawn_position[ACTOR_ID], position, "the leash anchors at the spawn position passed in")
	assert_eq(sim._ai_state[ACTOR_ID], "idle", "enemies start idle -- no initial aggro (locked)")
	assert_eq(sim._equipped_weapon[ACTOR_ID], "fang_bite", "register_ai equips the natural weapon internally")


## The natural weapon's reach must equal preferred_attack_distance or a settled enemy
## fires attacks it cannot land -- content's job, asserted here because the registrar is
## where the two values are wired to the same field.
func test_every_family_natural_weapon_reach_matches_its_preferred_distance() -> void:
	var actor_id: int = 100
	for enemy_key: StringName in ContentRegistrar.NATURAL_WEAPON_IDS:
		var weapon_id: StringName = ContentRegistrar.NATURAL_WEAPON_IDS[enemy_key]
		var natural: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", weapon_id)
		ContentRegistrar.register_enemy_body(sim, actor_id, enemy_key, Vector3.ZERO)
		assert_eq(sim._weapons[String(weapon_id)].reach, natural.preferred_attack_distance,
			"%s reach must equal its preferred_attack_distance" % [weapon_id])
		actor_id += 1
