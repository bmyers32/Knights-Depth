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

## P29 retired the family -> natural-weapon-id map that used to live here as a script
## literal. A family's repertoire is enemy IDENTITY, so it is authored on the enemy stats
## resource (`action_ids`) where a designer edits it, not in a .gd constant (Prime
## Directive 3). Nothing in this file may treat any repertoire index as privileged.


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


## Resolves one action's band against its owning ACTOR (P29). max_range = -1 is a
## sentinel meaning "my band ends at the actor's engagement reach" -- resolved here, so
## sim never sees a sentinel and never needs to know an actor field to interpret a band.
## Deliberately NOT resolved against a repertoire index: order carries no meaning.
static func resolve_max_range(action: NaturalWeaponStats, enemy_stats: Resource) -> float:
	return enemy_stats.preferred_attack_distance if action.max_range < 0.0 else action.max_range


## Registers one enemy family's BODY content -- entity, combatant defenses (health,
## i-frames, combat radius), and EVERY action in its repertoire -- and returns
## {action_id: NaturalWeaponStats} so the caller can build per-action presentation state
## (telegraph color/duration) from the same resources without a second lookup.
##
## Split from register_enemy_ai deliberately: a headless fixture that needs a target
## carrying REAL authored defenses (the i-frame/combo-cadence class of interaction)
## but no autonomous behavior registers this half alone. That is a legitimate content
## seam, not a test-only backdoor -- an inert target dummy is a real content shape.
## Node lifetime, telegraph caching, and debug_enable_* family gating stay with the
## scene driver.
##
## The melee/projectile branch mirrors register_weapon's existing GunStats-vs-SwordStats
## shape exactly -- an enemy action and a player weapon reach the same two sim entry
## points (register_weapon / register_gun), because there is only ever ONE combat
## pipeline (GAME-RULES §3).
static func register_enemy_body(sim: SimWorld, actor_id: int, enemy_key: StringName, position: Vector3) -> Dictionary:
	var stats: Resource = ContentDB.get_resource(&"enemy", enemy_key)

	# M2 placement law: an out-of-bounds spawn is refused LOUDLY by the sim, and the rest of
	# this actor's registration is abandoned with it. Registering health/AI for an actor
	# that has no position would leave a combatant that exists but cannot be located --
	# strictly worse to diagnose than one enemy simply missing from the floor.
	# BODY-AWARE placement: the spawn must fit, not merely fall inside. Passed explicitly because
	# registration order is add_entity THEN register_combatant, so the sim does not know this
	# actor's body yet -- it is the same stats.combat_radius registered two lines below.
	if not sim.add_entity(actor_id, position, stats.move_speed, Vector3(0.0, 0.0, -1.0), stats.combat_radius):
		return {}
	sim.register_combatant(actor_id, stats.max_health, stats.family, stats.iframe_ticks_on_hit, stats.combat_radius, &"enemy")
	# Registering a flinch profile is what makes an actor part of the reaction layer
	# at all -- the Envoy deliberately gets none in M1 (player reactions: ROADMAP P23).
	sim.register_flinch_profile(actor_id, stats.flinch_threshold)

	var actions: Dictionary = {}
	for action_id: StringName in stats.action_ids:
		var action: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", action_id)
		sim.register_action_susceptibility(action_id, action.windup_flinch_mode, action.vulnerable_start_tick, action.vulnerable_end_tick)
		if action.attack_resolution == &"projectile":
			sim.register_gun(action_id, action.damage, action.damage_type, action.projectile_speed, action.projectile_max_lifetime_ticks, action.projectile_hit_radius, action.knockback_distance, action.fire_interval_ticks)
		else:
			# A melee action's reach IS its resolved band ceiling, so a settled enemy can
			# always land what it fires (content's job to keep those consistent; the
			# content-lint test asserts it, sim does not enforce it).
			sim.register_weapon(action_id, action.damage, action.damage_type, resolve_max_range(action, stats), action.cone_half_angle_degrees, action.knockback_distance, action.fire_interval_ticks)
		actions[action_id] = action
	return actions


## Registers the engagement AI for an already-registered enemy body (above). Actor-level
## spacing/leash come from the ENEMY stats (P29: "where do I want to stand"); the
## repertoire carries per-action bands and windups ("what can I do from here").
static func register_enemy_ai(sim: SimWorld, actor_id: int, enemy_key: StringName, position: Vector3) -> void:
	var stats: Resource = ContentDB.get_resource(&"enemy", enemy_key)
	var repertoire: Array[Dictionary] = []
	for action_id: StringName in stats.action_ids:
		var action: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", action_id)
		repertoire.append({
			"id": action_id,
			"min_range": action.min_range,
			"max_range": resolve_max_range(action, stats),
			"windup_ticks": action.windup_ticks,
			"requires_close_frustration": action.requires_close_frustration,
		})
	sim.register_ai(actor_id, repertoire, position, stats.preferred_attack_distance, stats.minimum_attack_distance, stats.detection_radius, stats.leash_radius, stats.engagement_delay_ticks, stats.close_frustration_ticks, stats.burrow_jump_distance, stats.burrow_jump_step_distance, stats.burrow_underground_ticks, stats.burrow_emergence_radius, stats.burrow_emergence_retry_ticks, stats.burrow_reacquisition_ticks, stats.burrow_cooldown_ticks, stats.avoid_commit_ticks, stats.pursuit_language)
