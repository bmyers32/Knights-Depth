extends Node3D
## Real M1 arena (Phase D step 8, HANDOFF) — retires game/dev/envoy_movement_dev.tscn.
## The one shared SimWorld lives here, not on any actor (Prime Directive 1) — the
## scene owns setup (ContentDB lookups, entity/weapon/status registration) and drives
## the tick loop; actors only build Commands and mirror sim state onto their transform.

## Real M1 roster is locked (GAME-RULES §3/§7 seed+7) — Fang/Ooze/Watcher stay named
## scene children (a spawn-table system would be speculative generality for a fixed
## 3-family roster), but the driver tracks them in one dictionary keyed by actor_id
## instead of three separate if/elif chains, since later phases (death cleanup, and
## eventually an AI scan) both need to reason about "all living enemies" generically.
@onready var envoy: CharacterBody3D = $Envoy
@onready var _enemy_nodes: Dictionary = {
	&"fang": $Fang,
	&"ooze": $Ooze,
	&"watcher": $Watcher,
}
@onready var _failure_overlay: FailureOverlay = $FailureOverlay

## Real M1 loadout (CLAUDE.md M1 row: sword+gun+shield) — fixed switch order,
## advanced only via the sim-owned switch_weapon Command (Phase D step 8 Phase 2),
## never a direct driver call. sword_burn_A carries M1's one status effect (Burn);
## wand_A is ContentDB's plain Force-typed gun id (game/autoload/content_db.gd).
@export var loadout_weapon_ids: Array[StringName] = [&"sword_burn_A", &"wand_A"]

## Dev-only weapon carousel (Phase D step 8 Phase 5) — off by default. When true,
## registers every id in debug_weapon_ids (not just loadout_weapon_ids) and enables
## a raw KEY_TAB cycle (deliberately NOT an InputMap action — not a player-facing
## feature) that calls sim.set_equipped_weapon directly from the driver, the same
## mechanism the pre-arena dev scaffold used. Development tooling should not become
## a player system: the /playtest gate and the itch build must always run with this
## false, no exceptions — it exists for post-verdict damage-matrix diagnosis only.
@export var debug_loadout_override: bool = false
@export var debug_weapon_ids: Array[StringName] = [&"sword_A", &"sword_burn_A", &"wand_A", &"gun_pierce_A", &"gun_arc_A", &"gun_umbral_A"]

## Combat RNG seed (GAME-RULES §1.3 debug-overlay law: the active seed is always
## visible — printed in _ready() below, since no real debug overlay exists yet).
@export var combat_seed: int = 0

## Debug/diagnostic exports (manual-pass convention, this session): every export in
## this block is named debug_* and defaults to the AUTHENTIC game behavior — "all
## debug_* exports at default" is therefore the formal /playtest gate's state,
## mechanically verifiable rather than remembered, matching debug_loadout_override's
## existing shape above. debug_force_aggro=true skips the AI's own detection_radius
## gating entirely (every enemy starts "active", not "idle") for rapid mechanics
## iteration without walking into range each time -- the real driver never sets this.
@export var debug_force_aggro: bool = false
## Per-family isolation for a diagnostic pass (a family disabled here is skipped
## entirely -- no registration, node freed) -- all three true is the real roster.
@export var debug_enable_fang: bool = true
@export var debug_enable_ooze: bool = true
@export var debug_enable_watcher: bool = true
## Manual-pass tooling: this is the most temporally complex state machine in M1
## (lunge/windup/buffer) -- prints the Envoy's live pending-attack state
## (SimWorld.debug_describe_melee_state, a read-only public snapshot; never a
## direct underscore-field poke from this driver) each tick when on. Pure
## observability, default off, no gameplay effect either way.
@export var debug_show_attack_state: bool = false

var sim := SimWorld.new()
var _enemies: Dictionary = {}  # actor_id -> Node3D, entries removed on death
var _debug_equipped_index: int = 0
var _debug_tab_held_prev: bool = false
## actor_id -> {"color": Color, "duration_seconds": float}, resolved once at setup
## from each enemy's NaturalWeaponStats so _report_events never touches ContentDB.
var _enemy_telegraphs: Dictionary = {}
## Resolved once at setup from the loadout's combo/charge-capable SwordStats (Slice B
## charge-ready cue) — mirrors _enemy_telegraphs' resolve-once pattern, so
## _report_events never touches ContentDB. Stays Color.WHITE (never used) if no
## combo/charge weapon is in the loadout.
var _charge_ready_tint_color: Color = Color.WHITE
## Scene-owned run-ended flow flag (Phase D step 8, Phase 3) — presentation state,
## not gameplay state; SimWorld's own health dict remains the sole dead/alive
## authority (Prime Directive 1), this only gates whether the Envoy is still sent
## Commands. Temporary scaffolding: no sim-side respawn, no Commons transition — the
## real Emergency Recall/extraction flow is explicit M2 scope (GAME-RULES §5).
var _envoy_alive: bool = true


func _ready() -> void:
	sim.seed_combat_rng(combat_seed)
	print("combat RNG seed: ", combat_seed)

	sim.add_entity(envoy.actor_id, envoy.position, envoy.stats.move_speed)
	sim.register_combatant(envoy.actor_id, envoy.stats.max_health, envoy.stats.family, 0, envoy.stats.combat_radius, &"player")

	_register_enemies()

	for weapon_id in loadout_weapon_ids:
		ContentRegistrar.register_weapon(sim, weapon_id)
	sim.set_weapon_loadout(envoy.actor_id, loadout_weapon_ids)
	sim.set_equipped_weapon(envoy.actor_id, loadout_weapon_ids[0])

	for weapon_id in loadout_weapon_ids:
		var weapon: Resource = ContentDB.get_resource(&"weapon", weapon_id)
		if weapon is SwordStats and weapon.combo_profiles.size() > 0:
			_charge_ready_tint_color = weapon.charge_ready_tint_color
			break

	if debug_loadout_override:
		# Loud on purpose (AGENTS.md Invariable #2) -- a silent override would read
		# as the shipped loadout during a playtest instead of a deliberately-active
		# dev tool.
		print("!!! DEV CAROUSEL ACTIVE — not the shipped loadout !!!")
		for weapon_id in debug_weapon_ids:
			if not weapon_id in loadout_weapon_ids:
				ContentRegistrar.register_weapon(sim, weapon_id)

	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)

	var burn: BurnStats = ContentDB.get_resource(&"status", &"burn")
	sim.register_status(burn.status_id, burn.damage_per_tick, burn.tick_interval_ticks, burn.duration_ticks)
	var priority_table: StatusPriorityTable = ContentDB.get_resource(&"status", &"priority_table")
	sim.set_status_priority(priority_table.priority)

	var shield: ShieldStats = ContentDB.get_resource(&"shield", &"default")
	sim.register_shield(envoy.actor_id, shield.meter_max, shield.regen_per_tick, shield.break_recovery_delay_ticks, shield.knockback_distance)


func _register_enemies() -> void:
	# debug_enable_* lookup -- read once here, never per-tick.
	var family_enabled: Dictionary = {&"fang": debug_enable_fang, &"ooze": debug_enable_ooze, &"watcher": debug_enable_watcher}
	for enemy_key: StringName in _enemy_nodes:
		var actor: Node3D = _enemy_nodes[enemy_key]
		if not family_enabled[enemy_key]:
			actor.queue_free()
			continue
		# Sim registration goes through the shared ContentRegistrar so headless
		# fixtures exercise the SAME path this driver does (see that class's doc).
		var natural_weapon: NaturalWeaponStats = ContentRegistrar.register_enemy_body(sim, actor.actor_id, enemy_key, actor.position)
		ContentRegistrar.register_enemy_ai(sim, actor.actor_id, enemy_key, actor.position)
		if debug_force_aggro:
			sim.debug_set_ai_active(actor.actor_id)

		_enemies[actor.actor_id] = actor
		_enemy_telegraphs[actor.actor_id] = {
			"color": natural_weapon.telegraph_color,
			"duration_seconds": natural_weapon.windup_ticks / Engine.physics_ticks_per_second,
		}


func _physics_process(delta: float) -> void:
	if not _envoy_alive and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	# Once dead, the Envoy sends no further Commands (movement/attack/block/switch
	# all stop at once) — but the sim itself keeps ticking (status DoT, projectiles
	# in flight, and enemy AI) rather than freezing the whole simulation. (Godot's
	# typed-Array ternary doesn't coerce a bare "[]" to Array[Command], hence the
	# if/else instead of a one-line ternary here.)
	var commands: Array[Command] = []
	if _envoy_alive:
		_process_debug_weapon_cycle()  # stops along with every other Envoy input on death
		commands = envoy.build_commands(sim.tick_count)
	var events: Array[Event] = sim.tick(commands, delta)
	envoy.sync_from_sim(sim.entities[envoy.actor_id])
	for actor_id: int in _enemies.keys():
		var actor: Node3D = _enemies[actor_id]
		actor.sync_from_sim(sim.entities.get(actor_id, actor.position))
	_report_events(events)
	if debug_show_attack_state:
		var description: Dictionary = sim.debug_describe_melee_state(envoy.actor_id)
		if not description.is_empty():
			print("attack state: ", description)


## Dev-only debug input, deliberately NOT an InputMap action — edge-detected raw
## KEY_TAB advances through debug_weapon_ids so every damage type and the Burn
## carrier are reachable by hand for matrix/spread diagnosis. No-op unless
## debug_loadout_override is true (default false) — see that export's comment.
## Direct sim.set_equipped_weapon call from the driver, not the real switch_weapon
## Command: this is instrumentation, never the shipped weapon-switch feature.
func _process_debug_weapon_cycle() -> void:
	if not debug_loadout_override:
		return
	var tab_held: bool = Input.is_physical_key_pressed(KEY_TAB)
	if tab_held and not _debug_tab_held_prev:
		_debug_equipped_index = (_debug_equipped_index + 1) % debug_weapon_ids.size()
		sim.set_equipped_weapon(envoy.actor_id, debug_weapon_ids[_debug_equipped_index])
		print("DEV CAROUSEL equipped: ", debug_weapon_ids[_debug_equipped_index])
	_debug_tab_held_prev = tab_held


## Dev-only observability (AGENTS.md Invariable #2: every mechanic must be
## observable) — a real debug overlay/event log is future work (rule of two).
func _report_events(events: Array[Event]) -> void:
	for event in events:
		match event.kind:
			"melee_swing":
				print("melee swing: ", event.payload)
				# Slice B charge-ready cue (pure listener): a release closing any hold
				# -- tap or charge -- clears the tint; harmless no-op if it wasn't lit.
				if event.payload.get("actor_id") == envoy.actor_id:
					envoy.clear_charge_ready()
			"charge_ready":
				print("charge ready: ", event.payload)
				if event.payload.get("actor_id") == envoy.actor_id:
					envoy.show_charge_ready(_charge_ready_tint_color)
			"melee_hold_canceled":
				print("melee hold canceled: ", event.payload)
				if event.payload.get("actor_id") == envoy.actor_id:
					envoy.clear_charge_ready()
			"hit":
				print("hit: ", event.payload)
			"windup_interrupted":
				print("windup interrupted: ", event.payload)
			"died":
				print("died: ", event.payload)
				var actor_id: int = event.payload.get("actor_id")
				if actor_id == envoy.actor_id and _envoy_alive:
					# Guarded by _envoy_alive so a stray extra "died" Event (there
					# shouldn't be one — a dead actor can't be re-hit — but this keeps
					# the overlay a one-time transition regardless) can't show it twice.
					_envoy_alive = false
					_failure_overlay.show_failure()
				elif _enemies.has(actor_id):
					_enemies[actor_id].queue_free()
					_enemies.erase(actor_id)
					_enemy_telegraphs.erase(actor_id)
			"attack_telegraph":
				print("attack telegraph: ", event.payload)
				var actor_id: int = event.payload.get("actor_id")
				if _enemies.has(actor_id) and _enemy_telegraphs.has(actor_id):
					var telegraph: Dictionary = _enemy_telegraphs[actor_id]
					_enemies[actor_id].show_telegraph(telegraph.color, telegraph.duration_seconds)
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
			"weapon_switched":
				print("weapon switched: ", event.payload)
