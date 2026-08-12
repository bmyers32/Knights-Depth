class_name ContentRegistrar
extends RefCounted
## The ONE content -> SimWorld registration entrypoint. Resolves ContentDB Resources
## and unpacks them into the plain values SimWorld's register_* API takes (Prime
## Directive 1's boundary: Resources never cross into sim/; the driver unpacks).
##
## Extracted VERBATIM from arena.gd (no logic change) so the scene driver and any
## headless verification fixture register content through the SAME path. A test that
## reimplements this unpack can stay green while production diverges -- exactly the
## escape that hid the i-frame/combo-cadence defect (BRAIN.md), where every combo test
## hand-built profiles and registered targets at iframe_ticks_on_hit = 0.
## Node-free (RefCounted) so a GUT test can call it without instantiating a scene.

## Maps each locked M1 enemy family to its natural-attack ContentDB id (GAME-RULES
## §3/§7 seed+7 roster) -- content, not a hardcoded weapon choice in sim/.
const NATURAL_WEAPON_IDS: Dictionary = {
	&"fang": &"fang_bite",
	&"ooze": &"ooze_slam",
	&"watcher": &"watcher_pulse",
}


## A SwordStats with a non-empty combo_profiles array (Slice B, GAME-RULES §3)
## registers via register_melee_profiles instead of the flat register_weapon path --
## sword_A (empty array) is unaffected.
static func register_weapon(sim: SimWorld, weapon_id: StringName) -> void:
	var weapon: Resource = ContentDB.get_resource(&"weapon", weapon_id)
	if weapon is GunStats:
		sim.register_gun(weapon_id, weapon.base_damage, weapon.damage_type, weapon.speed, weapon.max_lifetime_ticks, weapon.hit_radius, weapon.knockback_distance, weapon.fire_interval_ticks, weapon.status_id, weapon.status_proc_chance, String(weapon.flinch_capability), weapon.contributes_pressure)
	elif weapon is SwordStats and weapon.combo_profiles.size() > 0:
		var combo_dicts: Array[Dictionary] = []
		for profile in weapon.combo_profiles:
			combo_dicts.append(unpack_melee_profile(profile))
		sim.register_melee_profiles(weapon_id, combo_dicts, unpack_melee_profile(weapon.charge_profile), weapon.charge_threshold_ticks, weapon.combo_reset_ticks, weapon.input_buffer_ticks)
	else:
		sim.register_weapon(weapon_id, weapon.base_damage, weapon.damage_type, weapon.reach, weapon.cone_half_angle_degrees, weapon.knockback_distance, 0, weapon.status_id, weapon.status_proc_chance)


## Unpacks one MeleeAttackProfile Resource into the plain Dictionary shape
## register_melee_profiles expects. Public because the whole point of this class is
## that there is exactly one such unpack in the project.
static func unpack_melee_profile(profile: MeleeAttackProfile) -> Dictionary:
	return {
		"damage": profile.damage,
		"damage_type": profile.damage_type,
		"reach": profile.reach,
		"cone_half_angle_degrees": profile.cone_half_angle_degrees,
		"knockback_distance": profile.knockback_distance,
		"fire_interval_ticks": profile.fire_interval_ticks,
		"status_id": profile.status_id,
		"status_proc_chance": profile.status_proc_chance,
		"interrupt_strength": profile.interrupt_strength,
		"lunge_distance": profile.lunge_distance,
		"lunge_duration_ticks": profile.lunge_duration_ticks,
		"hit_active_ticks": profile.hit_active_ticks,
		"windup_ticks": profile.windup_ticks,
		"flinch_capability": profile.flinch_capability,
		"contributes_pressure": profile.contributes_pressure,
	}


## Registers one enemy family's BODY content -- entity, combatant defenses (health,
## i-frames, combat radius), and its natural weapon -- and returns the resolved
## NaturalWeaponStats so the caller can build presentation state (telegraph color/
## duration) from the same resource without a second lookup.
##
## Split from register_enemy_ai deliberately: a headless fixture that needs a target
## carrying REAL authored defenses (the i-frame/combo-cadence class of interaction)
## but no autonomous behavior registers this half alone. That is a legitimate content
## seam, not a test-only backdoor -- an inert target dummy is a real content shape.
## Node lifetime, telegraph caching, and debug_enable_* family gating stay with the
## scene driver.
static func register_enemy_body(sim: SimWorld, actor_id: int, enemy_key: StringName, position: Vector3) -> NaturalWeaponStats:
	var stats: Resource = ContentDB.get_resource(&"enemy", enemy_key)
	var natural_weapon_id: StringName = NATURAL_WEAPON_IDS[enemy_key]
	var natural_weapon: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", natural_weapon_id)

	sim.add_entity(actor_id, position, natural_weapon.move_speed)
	sim.register_combatant(actor_id, stats.max_health, stats.family, stats.iframe_ticks_on_hit, stats.combat_radius, &"enemy")
	# Registering a flinch profile is what makes an actor part of the reaction layer
	# at all -- the Envoy deliberately gets none in M1 (player reactions: ROADMAP P23).
	sim.register_flinch_profile(actor_id, stats.flinch_threshold)
	sim.register_action_susceptibility(natural_weapon_id, natural_weapon.windup_flinch_mode, natural_weapon.vulnerable_start_tick, natural_weapon.vulnerable_end_tick)
	sim.register_weapon(natural_weapon_id, natural_weapon.damage, natural_weapon.damage_type, natural_weapon.preferred_attack_distance, natural_weapon.cone_half_angle_degrees, natural_weapon.knockback_distance, natural_weapon.fire_interval_ticks)
	return natural_weapon


## Registers the engagement AI for an already-registered enemy body (above).
static func register_enemy_ai(sim: SimWorld, actor_id: int, enemy_key: StringName, position: Vector3) -> void:
	var natural_weapon_id: StringName = NATURAL_WEAPON_IDS[enemy_key]
	var natural_weapon: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", natural_weapon_id)
	sim.register_ai(actor_id, natural_weapon_id, position, natural_weapon.preferred_attack_distance, natural_weapon.minimum_attack_distance, natural_weapon.windup_ticks, natural_weapon.detection_radius, natural_weapon.leash_radius)
