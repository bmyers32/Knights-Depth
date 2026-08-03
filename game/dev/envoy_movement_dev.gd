extends Node3D
## Dev-only scaffold (Phase D step 2-3, HANDOFF) proving input -> Command -> SimWorld ->
## render for a single Envoy, extended through step 7 to prove the full M1 content
## pipeline: three enemy families (Fang/Ooze/Watcher) against the complete damage
## matrix, plus Burn's hit-application and contact-episode spread.
## The one shared SimWorld lives here, not on any actor (Prime Directive 1) — real
## levels will hold multiple sim-driven actors sharing one SimWorld, and ownership
## belongs to the scene, not to any one actor.
## Temporary: retired when the real M1 arena (step 8) replaces it.

@onready var envoy: CharacterBody3D = $Envoy
@onready var fang: Node3D = $Fang
@onready var ooze: Node3D = $Ooze
@onready var watcher: Node3D = $Watcher

## Dev-only weapon roster (Phase D step 7) — cycled at runtime with a raw debug key
## (KEY_TAB, no InputMap action) so every damage type and the Burn carrier are
## reachable by hand against all three families without rebuilding the scene. This is
## a direct SimWorld.set_equipped_weapon call from the driver, the same mechanism the
## original single-weapon setup already used — not a new Command/UI (HANDOFF's
## "no runtime weapon-switching Command/UI" note is about a player-facing system;
## sword_burn_A/gun_pierce_A/gun_arc_A/gun_umbral_A are dev-only content variants,
## not new M1 weapons).
@export var weapon_ids: Array[StringName] = [&"sword_A", &"sword_burn_A", &"wand_A", &"gun_pierce_A", &"gun_arc_A", &"gun_umbral_A"]
@export var starting_weapon_id: StringName = &"sword_A"

## Combat RNG seed (GAME-RULES §1.3 debug-overlay law: the active seed is always
## visible — printed in _ready() below, since no real debug overlay exists yet).
## sword_burn_A's status_proc_chance (0.3) is the only M1 content that draws from
## this stream this session.
@export var combat_seed: int = 0

var sim := SimWorld.new()
var _equipped_index: int = 0
var _tab_held_prev: bool = false


func _ready() -> void:
	sim.seed_combat_rng(combat_seed)
	print("combat RNG seed: ", combat_seed)

	sim.add_entity(envoy.actor_id, envoy.position, envoy.stats.move_speed)
	# First session the Envoy is a registered combatant (real health) — required for
	# Burn's enemy<->player contact-spread leg (GAME-RULES §3 allegiance rule) to be
	# real. No enemy attacks exist yet, so Burn's contact spread is the only way this
	# health is currently reachable; see envoy_stats.gd for the damage-ratio note.
	sim.register_combatant(envoy.actor_id, envoy.stats.max_health, envoy.stats.family, 0, envoy.stats.combat_radius, &"player")

	_register_enemy(fang, ContentDB.get_resource(&"enemy", &"fang"))
	_register_enemy(ooze, ContentDB.get_resource(&"enemy", &"ooze"))
	_register_enemy(watcher, ContentDB.get_resource(&"enemy", &"watcher"))

	for weapon_id in weapon_ids:
		var weapon: Resource = ContentDB.get_resource(&"weapon", weapon_id)
		if weapon is GunStats:
			sim.register_gun(weapon_id, weapon.base_damage, weapon.damage_type, weapon.speed, weapon.max_lifetime_ticks, weapon.hit_radius, weapon.knockback_distance, weapon.fire_interval_ticks, weapon.status_id, weapon.status_proc_chance)
		else:
			sim.register_weapon(weapon_id, weapon.base_damage, weapon.damage_type, weapon.reach, weapon.cone_half_angle_degrees, weapon.knockback_distance, 0, weapon.status_id, weapon.status_proc_chance)
	_equipped_index = weapon_ids.find(starting_weapon_id)
	if _equipped_index == -1:
		_equipped_index = 0
	sim.set_equipped_weapon(envoy.actor_id, weapon_ids[_equipped_index])

	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)

	var burn: BurnStats = ContentDB.get_resource(&"status", &"burn")
	sim.register_status(burn.status_id, burn.damage_per_tick, burn.tick_interval_ticks, burn.duration_ticks)
	var priority_table: StatusPriorityTable = ContentDB.get_resource(&"status", &"priority_table")
	sim.set_status_priority(priority_table.priority)

	# No enemy attacks the Envoy yet (none of Fang/Ooze/Watcher have AI this session) —
	# this registration proves the block wiring (input -> Command -> state machine ->
	# Event) so a future AI step has a target to attack into. GUT (tests/test_shield.gd)
	# is the authoritative proof of the mitigation math this session.
	var shield: ShieldStats = ContentDB.get_resource(&"shield", &"default")
	sim.register_shield(envoy.actor_id, shield.meter_max, shield.regen_per_tick, shield.break_recovery_delay_ticks, shield.knockback_distance)


func _register_enemy(actor: Node3D, stats: Resource) -> void:
	sim.add_entity(actor.actor_id, actor.position, 0.0)
	sim.register_combatant(actor.actor_id, stats.max_health, stats.family, stats.iframe_ticks_on_hit, stats.combat_radius, &"enemy")


func _physics_process(delta: float) -> void:
	_process_debug_weapon_cycle()
	var commands: Array[Command] = envoy.build_commands(sim.tick_count)
	var events: Array[Event] = sim.tick(commands, delta)
	envoy.sync_from_sim(sim.entities[envoy.actor_id])
	if fang:
		fang.sync_from_sim(sim.entities.get(fang.actor_id, fang.position))
	if ooze:
		ooze.sync_from_sim(sim.entities.get(ooze.actor_id, ooze.position))
	if watcher:
		watcher.sync_from_sim(sim.entities.get(watcher.actor_id, watcher.position))
	_report_events(events)


## Dev-only debug input, deliberately NOT an InputMap action (a permanent
## player-facing weapon switcher is out of scope this session, HANDOFF) — edge-detected
## raw KEY_TAB advances through weapon_ids so every damage type and the Burn carrier
## are reachable by hand for the manual matrix/spread pass.
func _process_debug_weapon_cycle() -> void:
	var tab_held: bool = Input.is_physical_key_pressed(KEY_TAB)
	if tab_held and not _tab_held_prev:
		_equipped_index = (_equipped_index + 1) % weapon_ids.size()
		sim.set_equipped_weapon(envoy.actor_id, weapon_ids[_equipped_index])
		print("equipped: ", weapon_ids[_equipped_index])
	_tab_held_prev = tab_held


## Dev-only observability (AGENTS.md Invariable #2: every mechanic must be
## observable) — a real debug overlay/event log is future work, not needed for a
## dev scaffold (rule of two).
func _report_events(events: Array[Event]) -> void:
	for event in events:
		match event.kind:
			"hit":
				print("hit: ", event.payload)
			"died":
				print("died: ", event.payload)
				var actor_id: int = event.payload.get("actor_id")
				if actor_id == envoy.actor_id:
					# Loud on purpose: no respawn/Synchronization-Failure system exists
					# yet (HANDOFF gap note) — the dev scaffold does nothing further,
					# so a silent print here would read as a missing feature instead
					# of a deliberately-out-of-scope one.
					print("!!! ENVOY DIED — no respawn/Synchronization-Failure system exists yet, dev scaffold takes no further action !!!")
				elif fang and actor_id == fang.actor_id:
					fang.queue_free()
					fang = null
				elif ooze and actor_id == ooze.actor_id:
					ooze.queue_free()
					ooze = null
				elif watcher and actor_id == watcher.actor_id:
					watcher.queue_free()
					watcher = null
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
			"status_proc":
				print("status proc: ", event.payload)
			"status_applied":
				print("status applied: ", event.payload)
			"status_resolved":
				print("status resolved: ", event.payload)
			"status_expired":
				print("status expired: ", event.payload)
