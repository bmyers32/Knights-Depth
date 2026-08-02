extends Node3D
## Dev-only scaffold (Phase D step 2-3, HANDOFF) proving input -> Command -> SimWorld ->
## render for a single Envoy, now extended to prove the melee AND ranged damage
## pipeline (hit detect -> damage matrix -> knockback -> death/events, plus the gun's
## deferred travel-time resolution) against a stationary Fang.
## The one shared SimWorld lives here, not on any actor (Prime Directive 1) — real
## levels will hold multiple sim-driven actors sharing one SimWorld, and ownership
## belongs to the scene, not to any one actor.
## Temporary: retired when the real M1 arena (step 8) replaces it.

@onready var envoy: CharacterBody3D = $Envoy
@onready var fang: Node3D = $Fang

## No runtime weapon-switching system this slice — the Envoy equips exactly one
## weapon, chosen at scene setup. Flip this in the Inspector (or a scene variant) to
## exercise the gun path (&"wand_A") instead of the default sword (&"sword_A"); both
## resolve through the same _ready() wiring and the same "attack" Command.
@export var starting_weapon_id: StringName = &"sword_A"

var sim := SimWorld.new()


func _ready() -> void:
	sim.add_entity(envoy.actor_id, envoy.position, envoy.stats.move_speed)

	var fang_stats: FangStats = ContentDB.get_resource(&"enemy", &"fang")
	sim.add_entity(fang.actor_id, fang.position, 0.0)
	sim.register_combatant(fang.actor_id, fang_stats.max_health, fang_stats.family, fang_stats.iframe_ticks_on_hit)

	var weapon: Resource = ContentDB.get_resource(&"weapon", starting_weapon_id)
	if weapon is GunStats:
		sim.register_gun(starting_weapon_id, weapon.base_damage, weapon.damage_type, weapon.speed, weapon.max_lifetime_ticks, weapon.hit_radius, weapon.knockback_distance, weapon.fire_interval_ticks)
	else:
		sim.register_weapon(starting_weapon_id, weapon.base_damage, weapon.damage_type, weapon.reach, weapon.cone_half_angle_degrees, weapon.knockback_distance)
	sim.set_equipped_weapon(envoy.actor_id, starting_weapon_id)

	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)

	# No enemy attacks the Envoy yet (Fang is still AI-less this session) — this
	# registration proves the block wiring (input -> Command -> state machine ->
	# Event) so step 6's real enemy AI has a target to attack into, not to
	# demonstrate absorption visually yet. GUT (tests/test_shield.gd) is the
	# authoritative proof of the mitigation math this session.
	var shield: ShieldStats = ContentDB.get_resource(&"shield", &"default")
	sim.register_shield(envoy.actor_id, shield.meter_max, shield.regen_per_tick, shield.break_recovery_delay_ticks, shield.knockback_distance)


func _physics_process(delta: float) -> void:
	var commands: Array[Command] = envoy.build_commands(sim.tick_count)
	var events: Array[Event] = sim.tick(commands, delta)
	envoy.sync_from_sim(sim.entities[envoy.actor_id])
	if fang:
		fang.sync_from_sim(sim.entities.get(fang.actor_id, fang.position))
	_report_events(events)


## Dev-only observability (AGENTS.md Invariable #2: every mechanic must be
## observable) — a real debug overlay/event log is future work, not needed for a
## two-scaffold prototype (rule of two).
func _report_events(events: Array[Event]) -> void:
	for event in events:
		match event.kind:
			"hit":
				print("hit: ", event.payload)
			"died":
				print("died: ", event.payload)
				if fang and event.payload.get("actor_id") == fang.actor_id:
					fang.queue_free()
					fang = null
			"attack_rejected":
				print("attack rejected: ", event.payload)
			"attack_absorbed":
				print("attack absorbed (iframes): ", event.payload)
			"blocked":
				print("blocked: ", event.payload)
			"shield_broken":
				print("shield broken: ", event.payload)
			"block_rejected":
				print("block rejected: ", event.payload)
			"projectile_fired":
				print("projectile fired: ", event.payload)
			"projectile_expired":
				print("projectile expired: ", event.payload)
