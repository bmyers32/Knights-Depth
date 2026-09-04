extends Node3D
## Real M1 arena (Phase D step 8, HANDOFF) — retires game/dev/envoy_movement_dev.tscn.
## The one shared SimWorld lives here, not on any actor (Prime Directive 1) — the
## scene owns setup (ContentDB lookups, entity/weapon/status registration) and drives
## the tick loop; actors only build Commands and mirror sim state onto their transform.

## M2 Slice 1 retired the hand-authored roster: Fang/Ooze/Watcher are no longer named scene
## children. A floor's ENTIRE roster now comes from the FloorPlan the run seed produced, and
## FloorBuilder instantiates it. The M1 roster is still what spawns (StratumConfig.enemy_keys
## holds the locked §3/§7 seed+7 families) — what changed is who decides placement and count.
@onready var envoy: CharacterBody3D = $Envoy
@onready var _floor_builder: FloorBuilder = $FloorBuilder
@onready var _camera: FollowCamera = $FollowCamera
@onready var _seed_label: Label = $SeedHud/SeedLabel
@onready var _failure_overlay: FailureOverlay = $FailureOverlay

const PROJECTILE_TRACER: PackedScene = preload("res://game/actors/projectile_tracer.tscn")
## Player-shot tracer colour. GAME-RULES §3's channel law says damage TYPES own colour,
## but no type->palette table exists yet (enemy telegraphs stand in with one flat colour
## for exactly the same reason). One placeholder here, replaced by the real palette in
## the same pass that gives telegraphs theirs -- never a per-weapon colour, which would
## let presentation invent a channel the type owns.
const PROJECTILE_TRACER_FALLBACK_COLOR: Color = Color(0.55, 0.85, 1.0)

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

## THE RUN SEED (GAME-RULES §1.3: the active seed is always visible and logged; a bug
## report is seed + command log). One seed drives the whole run — it seeds the combat RNG
## AND derives every floor's layout — so "same seed, same run" is a single fact a human can
## hold. It is rendered on screen by _update_seed_label, not merely printed, because a
## printed seed is unavailable in exactly the shipped build a playtest runs.
##
## Generation never draws from the combat stream and vice versa (§1.3 separate streams):
## DepthGenerator builds its own RandomNumberGenerator per call, so floor count cannot shift
## a single combat roll.
@export var run_seed: int = 0
## Which depth to generate. Slice 1 loads exactly one floor at startup; the elevator that
## advances this is explicitly out of scope (GAME-RULES §5 M2 run structure).
@export var depth: int = 1

## Debug/diagnostic exports (manual-pass convention, this session): every export in
## this block is named debug_* and defaults to the AUTHENTIC game behavior — "all
## debug_* exports at default" is therefore the formal /playtest gate's state,
## mechanically verifiable rather than remembered, matching debug_loadout_override's
## existing shape above. debug_force_aggro=true skips the AI's own detection_radius
## gating entirely (every enemy starts "active", not "idle") for rapid mechanics
## iteration without walking into range each time -- the real driver never sets this.
@export var debug_force_aggro: bool = false
## REMOVED at M2 Slice 1: debug_enable_fang/ooze/watcher. Those exports isolated ONE named
## scene child per family, a notion generated floors no longer have — a floor may contain
## three Fangs and no Watcher. The reproduction handle they served is now the run seed,
## which is strictly better: it reproduces the whole floor, not just its cast.

## Manual-pass tooling: this is the most temporally complex state machine in M1
## (lunge/windup/buffer) -- prints the Envoy's live pending-attack state
## (SimWorld.debug_describe_melee_state, a read-only public snapshot; never a
## direct underscore-field poke from this driver) each tick when on. Pure
## observability, default off, no gameplay effect either way.
@export var debug_show_attack_state: bool = false
## DEV VALIDATION TARGET (flinch batch) -- > 0.0 overrides every enemy's max_health at
## setup so a target survives multiple full combos. ALL mechanical flinch validation
## runs against this, deliberately independent of shipped enemy tuning: pressure
## accumulation, threshold crossing with a SURVIVOR, re-flinch behavior, expiry ticks.
## 0.0 = off (authentic). Never enabled for a /playtest gate or an itch build.
@export var debug_validation_target_health: float = 0.0
## > 0.0 replaces every enemy's authored flinch_threshold, isolating CAPABILITY
## questions from THRESHOLD questions (a low value makes repeated cash-outs cheap
## enough to exercise the full flinch lifecycle). 0.0 = off (authentic).
@export var debug_flinch_threshold_override: float = 0.0
## Prints the live flinch/pressure snapshot for each enemy (SimWorld.
## debug_describe_flinch_state, a read-only public snapshot). Pure observability.
@export var debug_show_flinch_state: bool = false
## P29 action-selection snapshot: which authored action each enemy is eligible for at its
## current distance and, when NONE is, the nearest authored band. Exists so an accidental
## band gap is diagnosable on sight instead of presenting as "the enemy mysteriously
## stopped attacking." Pure observability, default off.
@export var debug_show_action_selection: bool = false

## P17 BURROW STAGE 1 -- the controlled execution path. Validate an action before validating its
## selector: the scurry entangled the two, its detector never recognised representative play, and
## the response was never cleanly judged. So burrow fires ON DEMAND (raw KEY_B, edge-detected,
## deliberately NOT an InputMap action -- dev tooling must not become a player system) and earns
## an AI selector only after a human verdict on the action itself.
##
## A Stage-1 session therefore runs with this TRUE and is explicitly NOT the formal gate state.
@export var debug_burrow_trigger: bool = false
## P17 selector snapshot: each condition's live value against its threshold -- frustration
## elapsed vs required, whether the episode is already spent, cooldown remaining, and whether
## the selector would fire this tick. Pure observability, default off.
@export var debug_show_burrow_selection: bool = false

var sim := SimWorld.new()
var _enemies: Dictionary = {}  # actor_id -> Node3D, entries removed on death
## Monotonic across the whole RUN, never reset per floor: a reused actor_id would make two
## different enemies indistinguishable in one run's event log. Starts at 1 because the Envoy
## holds 0 (envoy.gd) and is the only actor that outlives a floor.
var _next_actor_id: int = 1
## No room -> gate map any more: a connection_changed Event names its own connection_id, so
## presentation never has to infer which barriers an encounter owns. That inference existed
## only because rooms parented gates -- which is exactly the abstraction that failed.
var _debug_equipped_index: int = 0
var _debug_tab_held_prev: bool = false
var _debug_burrow_held_prev: bool = false
## action_id -> {"color": Color, "duration_seconds": float}, resolved once at setup from
## each action's NaturalWeaponStats so _report_events never touches ContentDB. Keyed by
## ACTION since P29 (an actor may have several), and read via the attack_telegraph
## Event's own action_id -- presentation never re-derives which action an actor chose.
var _action_telegraphs: Dictionary = {}
## weapon_id -> {"speed": float, "color": Color} for the projectile tracer, resolved once
## at setup for BOTH enemy ranged actions and player guns. Speed is deliberately read
## from CONTENT here rather than carried in the projectile_fired Event: a tunable does not
## belong in an Event payload, and the Event already carries weapon_id to look it up by.
var _projectile_visuals: Dictionary = {}
## projectile_id -> Node3D. A tracer is COSMETIC PREDICTION: it extrapolates from the
## spawn state in projectile_fired and is removed by any terminal event carrying its id.
## SimWorld stays authoritative for position, collision, hit and expiry, and presentation
## never feeds anything back -- a tracer/sim disagreement is always a TRACER bug.
var _projectile_tracers: Dictionary = {}
## How far above its floor a tracer flies. Presentation only -- the sim resolves every shot on
## the flat plane, and lifting the picture must never be mistaken for giving shots a height.
const _MUZZLE_HEIGHT: float = 0.9
## actor_id -> {"opens_tick": int, "ends_tick": int, "marked": bool} for the P29 vulnerable
## cue. Absolute sim ticks derived from the telegraph Event's OWN tick plus authored
## content -- Event.tick is the authoritative timestamp (BRAIN), never tick_count sampled
## afterwards. Purely presentation scheduling; reads sim state, never writes it.
var _windup_cues: Dictionary = {}
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
	sim.seed_combat_rng(run_seed)
	print("run seed: ", run_seed)

	# The body radius rides along because placement legality is body-aware (ruled): it is the
	# same stats.combat_radius registered as the combatant body on the next line.
	sim.add_entity(envoy.actor_id, envoy.position, envoy.stats.move_speed, Vector3(0.0, 0.0, -1.0), envoy.stats.combat_radius)
	sim.register_combatant(envoy.actor_id, envoy.stats.max_health, envoy.stats.family, 0, envoy.stats.combat_radius, &"player")
	# The ONE actor that survives a floor transition. Everything else on a floor belongs to
	# that floor (SimWorld.STATE_SCOPES).
	sim.mark_run_persistent(envoy.actor_id)

	for weapon_id in loadout_weapon_ids:
		ContentRegistrar.register_weapon(sim, weapon_id)
	sim.set_weapon_loadout(envoy.actor_id, loadout_weapon_ids)
	sim.set_equipped_weapon(envoy.actor_id, loadout_weapon_ids[0])

	for weapon_id in loadout_weapon_ids:
		var weapon: Resource = ContentDB.get_resource(&"weapon", weapon_id)
		if weapon is SwordStats and weapon.combo_profiles.size() > 0:
			_charge_ready_tint_color = weapon.charge_ready_tint_color
			break

	# The tracer path has TWO real consumers on day one (rule of two): the Watcher's
	# ranged action, cached in _register_enemies, and the player's guns here. One shared
	# scene, no generic VFX framework.
	_cache_gun_visuals(loadout_weapon_ids)


	if debug_loadout_override:
		# Loud on purpose (AGENTS.md Invariable #2) -- a silent override would read
		# as the shipped loadout during a playtest instead of a deliberately-active
		# dev tool.
		print("!!! DEV CAROUSEL ACTIVE — not the shipped loadout !!!")
		for weapon_id in debug_weapon_ids:
			if not weapon_id in loadout_weapon_ids:
				ContentRegistrar.register_weapon(sim, weapon_id)
		_cache_gun_visuals(debug_weapon_ids)

	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)

	var flinch: FlinchTuning = ContentDB.get_resource(&"combat", &"flinch_tuning")
	sim.set_flinch_tuning(flinch.pressure_window_ticks, flinch.flinch_recovery_ticks)

	var burn: BurnStats = ContentDB.get_resource(&"status", &"burn")
	sim.register_status(burn.status_id, burn.damage_per_tick, burn.tick_interval_ticks, burn.duration_ticks)
	var priority_table: StatusPriorityTable = ContentDB.get_resource(&"status", &"priority_table")
	sim.set_status_priority(priority_table.priority)

	var shield: ShieldStats = ContentDB.get_resource(&"shield", &"default")
	sim.register_shield(envoy.actor_id, shield.meter_max, shield.regen_per_tick, shield.break_recovery_delay_ticks, shield.knockback_distance, shield.bump_padding, shield.bump_distance, shield.bump_slide_ticks, shield.bump_cooldown_ticks, shield.parry_window_ticks, shield.parry_exposure_ticks, shield.parry_damage_multiplier)

	# LAST: every RUN-scoped registration above must exist before a floor is loaded into it.
	_load_floor()


## Resolves tracer speed/colour for any GunStats in the given ids. Colour comes from the
## damage-type channel the telegraph already uses (GAME-RULES §3 channel law: types own
## colour, presentation reads it and never invents one).
func _cache_gun_visuals(weapon_ids: Array[StringName]) -> void:
	for weapon_id in weapon_ids:
		var weapon: Resource = ContentDB.get_resource(&"weapon", weapon_id)
		if weapon is GunStats:
			_projectile_visuals[String(weapon_id)] = {
				"speed": weapon.speed,
				"color": PROJECTILE_TRACER_FALLBACK_COLOR,
				"hit_radius": weapon.hit_radius,
			}


## Generates the floor for the current depth and installs it in BOTH layers: the sim gets
## the walkable law and a cleared encounter, presentation gets geometry and actor scenes --
## both from the SAME FloorPlan, so the room the player sees and the room the sim clamps
## against can never be two different rooms.
##
## Ordering matters and is not incidental:
##   1. generate      -- pure, no side effects, so a bad plan is diagnosable before anything
##                       is mutated
##   2. sim.load_floor -- retires the OLD encounter (statuses, projectiles, AI, old actors)
##                       and adopts the new bounds, BEFORE any new actor is registered
##   3. build         -- new scenes instantiated with freshly allocated actor_ids
##   4. register      -- through the ordinary ContentRegistrar path, unchanged
func _load_floor() -> void:
	var plan: FloorPlan = DepthGenerator.generate(run_seed, depth)
	print("floor loaded: ", {
		"run_seed": run_seed, "depth": depth, "authored_layout": plan.authored_layout,
		"patches": plan.patches.size(), "connections": plan.connections.size(),
		"triggers": plan.triggers.size(), "encounters": plan.encounters.size(),
		"breakables": plan.breakables.size(),
	})

	sim.load_floor(plan.make_bounds(), plan.entry_point)
	_unpack_floor(plan)

	# Presentation state keyed to the departing floor dies with it. The sim has already dropped
	# its side; these are the mirrors.
	_enemies.clear()
	_windup_cues.clear()
	for projectile_id: int in _projectile_tracers.keys():
		_despawn_tracer(projectile_id)
	envoy.teleport_from_sim(plan.entry_point)
	_camera.set_target(envoy)
	_camera.set_floor_extent(_floor_extent_of(plan))
	_camera.snap_to_target()

	var barriers: Dictionary = {}
	for connection in plan.connections:
		barriers[connection.connection_id] = sim.gate_barrier(connection.connection_id)
	var spawned: Array[Dictionary] = _floor_builder.build(plan, _next_actor_id, barriers)
	_floor_builder.build_walls(plan)
	_next_actor_id += spawned.size()  # ids are never reused within a run
	for record in spawned:
		var actor: Node3D = record["node"]
		var actor_id: int = record["actor_id"]
		var actions: Dictionary = ContentRegistrar.register_enemy_body(sim, actor_id, record["enemy_key"], record["position"])
		if actions.is_empty():
			_floor_builder.remove_child(actor)
			actor.queue_free()
			continue
		ContentRegistrar.register_enemy_ai(sim, actor_id, record["enemy_key"], record["position"])
		# TERRITORY IS PERMANENT and unconditional (ruled): this enemy belongs to the encounter
		# site that authored it for its whole life, whatever the activation state. Refused loudly
		# by the sim if a layout ever places a spawn outside its own site.
		sim.assign_actor_encounter(actor_id, int(record["encounter_id"]))
		if debug_validation_target_health > 0.0:
			sim.debug_override_health(actor_id, debug_validation_target_health)
		if debug_flinch_threshold_override > 0.0:
			sim.register_flinch_profile(actor_id, debug_flinch_threshold_override)
		if debug_force_aggro:
			sim.debug_set_ai_active(actor_id)

		_enemies[actor_id] = actor
		# Registered but not yet PRESENT: a deferred roster is invisible and untargetable until
		# its site activates. The sim already marked it combat-absent; this is the mirror.
		if sim.debug_is_combat_absent(actor_id):
			actor.set_combat_present(false)
		for action_id: StringName in actions:
			var action: NaturalWeaponStats = actions[action_id]
			_action_telegraphs[String(action_id)] = {
				"color": action.telegraph_color,
				"duration_seconds": action.windup_ticks / Engine.physics_ticks_per_second,
				"vulnerable_start": action.vulnerable_start_tick,
				"vulnerable_end": action.vulnerable_end_tick,
				"windup_ticks": action.windup_ticks,
			}
			if action.attack_resolution == &"projectile":
				_projectile_visuals[String(action_id)] = {
					"speed": action.projectile_speed,
					"color": action.telegraph_color,
					"hit_radius": action.projectile_hit_radius,
				}
	_update_seed_label(plan)


## Unpacks the four floor LAYERS into the sim. The driver does the unpacking so sim/ never
## imports gen/ -- the same boundary ContentRegistrar draws for Resources.
##
## ORDER MATTERS: patches before connections (bounds rebuild from both), encounters before any
## actor (assign_actor_encounter validates against a registered territory), triggers last
## because they only ever NAME the things above.
func _unpack_floor(plan: FloorPlan) -> void:
	sim.register_patches(plan.patch_rects())
	# ONE canonical boundary, handed to the sim exactly as presentation receives it.
	sim.register_obstacles(plan.obstacle_rects())
	for pad in plan.spike_pads:
		sim.register_spike_pad(pad.pad_id, pad.rect, pad.safe_ticks, pad.active_ticks,
			pad.phase_offset_ticks, pad.damage, pad.damage_type, pad.eligible_allegiances)
	sim.register_solid_segments(plan.solid_segments())
	for connection in plan.connections:
		sim.register_connection(connection.connection_id, connection.aperture, connection.starts_open)
	for encounter in plan.encounters:
		sim.register_encounter(encounter.encounter_id, encounter.regions, encounter.role, encounter.confines_player, encounter.spawn_at_floor_load)
	for breakable in plan.breakables:
		sim.register_breakable(breakable.breakable_id, breakable.position, breakable.radius, breakable.durability, breakable.blocking_rect)
	for hit_switch in plan.hit_switches:
		sim.register_hit_switch(hit_switch.switch_id, hit_switch.position, hit_switch.radius,
			hit_switch.mode, hit_switch.effects, hit_switch.starts_hidden)
	for trigger in plan.triggers:
		sim.register_trigger(trigger.trigger_id, trigger.kind, trigger.region, trigger.source_id, trigger.once, trigger.effects, trigger.starts_enabled)


## Visual ground lift for an actor. Sim positions are FLAT -- combat lives on one plane -- so
## presentation raises them onto whatever the visible ground is doing. Elevation never travels
## back the other way.
func _grounded(position: Vector3) -> Vector3:
	return Vector3(position.x, _floor_builder.elevation_at(position), position.z)


## Union AABB of everything walkable, for the camera's edge clamp. Derived from the plan, so
## the camera can never disagree with the floor about where the floor is.
func _floor_extent_of(plan: FloorPlan) -> Rect2:
	var extent: Rect2 = Rect2()
	var rects: Array[Rect2] = plan.all_rects()
	for index in rects.size():
		extent = rects[index] if index == 0 else extent.merge(rects[index])
	return extent


## §1.3's visibility law, satisfied ON SCREEN rather than in stdout: a printed seed is
## unavailable in exactly the shipped build a playtest runs, which is the build whose floor
## someone will want to reproduce.
func _update_seed_label(plan: FloorPlan) -> void:
	# SEED HONESTY: while the layout is authored, SAY SO. A seed printed beside a fixed floor
	# would advertise procedural variety that does not exist yet.
	var provenance: String = "authored layout" if plan.authored_layout else "generated"
	_seed_label.text = "seed %d · depth %d · %s · %s" % [plan.run_seed, plan.depth, plan.stratum_id, provenance]


func _physics_process(delta: float) -> void:
	# RESTART (R) is available AT ANY TIME, not only from the run-end screen. Iterating on a
	# mechanic means running the same encounter over and over, and closing/relaunching the whole
	# app between attempts is the single biggest tax on that loop. Durable playtest UX, retained
	# independently of any mechanic that prompted it.
	#
	# A full scene reload rather than a bespoke "respawn the enemies" path, deliberately: dead
	# enemies have had their nodes queue_free()d, so a partial reset would have to re-instantiate
	# them and then re-derive which sim state is encounter-scoped versus run-scoped -- a SECOND
	# notion of "reset" to keep in sync with the first. The reload already restores every actor
	# to its authored spawn with a fresh SimWorld, through the same code path run-end restart has
	# always used.
	#
	# Scope note: this widens WHEN an existing player-facing action is reachable. It is not
	# instrumentation and not behind a debug_* export, because an export defaulting to off would
	# be unavailable in exactly the gate-state build a playtest runs. Combat behaviour is
	# untouched.
	if Input.is_action_just_pressed("restart"):
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
		_process_debug_burrow_trigger()
		commands = envoy.build_commands(sim.tick_count)
	var events: Array[Event] = sim.tick(commands, delta)
	envoy.sync_from_sim(_grounded(sim.entities[envoy.actor_id]))
	for actor_id: int in _enemies.keys():
		var actor: Node3D = _enemies[actor_id]
		actor.sync_from_sim(_grounded(sim.entities.get(actor_id, actor.position)))
	_report_events(events)
	_advance_windup_cues()
	if debug_show_attack_state:
		var description: Dictionary = sim.debug_describe_melee_state(envoy.actor_id)
		if not description.is_empty():
			print("attack state: ", description)
	if debug_show_flinch_state:
		for actor_id: int in _enemies.keys():
			var flinch_state: Dictionary = sim.debug_describe_flinch_state(actor_id)
			if not flinch_state.is_empty():
				print("flinch state [", actor_id, "]: ", flinch_state)
	if debug_show_burrow_selection:
		for actor_id: int in _enemies.keys():
			var selection: Dictionary = sim.debug_describe_burrow_selection(actor_id, envoy.actor_id)
			if bool(selection.get("authored", false)):
				print("burrow selection: ", selection)

	if debug_show_action_selection:
		for actor_id: int in _enemies.keys():
			var selection: Dictionary = sim.debug_describe_action_selection(actor_id, envoy.actor_id)
			if not selection.is_empty():
				print("action selection: ", selection)


## STAGE 1 controlled burrow. Edge-detected raw KEY_B, no-op unless debug_burrow_trigger is
## true (default false). Reports a refused trigger rather than silently doing nothing, so a
## playtest can tell "it did not fire" from "I did not press it".
func _process_debug_burrow_trigger() -> void:
	if not debug_burrow_trigger:
		return
	var held: bool = Input.is_physical_key_pressed(KEY_B)
	if held and not _debug_burrow_held_prev:
		# Logged on the EDGE, before any outcome, so a session can distinguish "the key was never
		# observed" from "it was observed and every actor refused". A previous Stage-1 run left
		# exactly that ambiguous, and the answer is not inferable after the fact.
		print("burrow key: ", {"tick": sim.tick_count, "enemies": _enemies.size()})
		for actor_id: int in _enemies.keys():
			if sim.debug_trigger_burrow(actor_id, envoy.actor_id):
				print("burrow triggered: ", {"actor_id": actor_id})
			else:
				print("burrow refused: ", {"actor_id": actor_id})
	_debug_burrow_held_prev = held


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


## Fires the ONE distinct vulnerable-window cue at the exact sim tick the authored window
## opens, and retires the schedule when the windup ends. Content truth is NORMAL early ->
## VULNERABLE late -> fire, so the early phase deliberately gets NO special signal: NORMAL
## is ordinary susceptibility, and cueing it would promise the player something the sim
## does not actually grant.
##
## tick_count advances as the LAST statement of SimWorld.tick(), so the tick just
## simulated is tick_count - 1 (BRAIN: "Events carry the authoritative timestamp").
func _advance_windup_cues() -> void:
	var simulated_tick: int = sim.tick_count - 1
	for actor_id: int in _windup_cues.keys():
		var cue: Dictionary = _windup_cues[actor_id]
		if simulated_tick > int(cue.ends_tick):
			_windup_cues.erase(actor_id)
			continue
		if not bool(cue.marked) and simulated_tick >= int(cue.opens_tick):
			cue.marked = true
			if _enemies.has(actor_id):
				_enemies[actor_id].show_vulnerable_window()


## Spawns a cosmetic tracer for a shot the sim has already created. Presentation is
## handed the spawn state and EXTRAPOLATES (dead-reckons) from it — this is not
## interpolation between sim states, because there is no second sim state to interpolate
## toward. The sim never publishes per-tick projectile positions and does not need to:
## travel is a straight line at constant speed from a fixed origin.
func _spawn_tracer(payload: Dictionary) -> void:
	var visuals: Dictionary = _projectile_visuals.get(String(payload.get("weapon_id", "")), {})
	if visuals.is_empty():
		return  # unregistered visual -- a missing tracer is a cosmetic gap, never a sim error
	var tracer: ProjectileTracer = PROJECTILE_TRACER.instantiate()
	add_child(tracer)
	# hit_radius comes from CONTENT, resolved once at setup -- never from the Event, whose
	# payload must stay free of tunables (and whose shape the backward-compat allow-list pins).
	# GROUNDED TO THE FLOOR IT WAS FIRED FROM. The sim is FLAT -- every actor position is y=0 --
	# and presentation lifts actors to their patch elevation on the way out. The tracer was the
	# one thing that did not get lifted, so a shot fired on a raised platform launched at y=0 and
	# flew UNDERNEATH it. Authority was never wrong; the picture was.
	var muzzle: Vector3 = _grounded(payload.get("position", Vector3.ZERO)) + Vector3(0.0, _MUZZLE_HEIGHT, 0.0)
	tracer.launch(muzzle, payload.get("direction", Vector3.FORWARD), float(visuals.speed), visuals.color, float(visuals.get("hit_radius", 0.0)))
	_projectile_tracers[int(payload.get("projectile_id", -1))] = tracer


func _despawn_tracer(projectile_id: int) -> void:
	if not _projectile_tracers.has(projectile_id):
		return
	var tracer: Node3D = _projectile_tracers[projectile_id]
	_projectile_tracers.erase(projectile_id)
	tracer.queue_free()


## Dev-only observability (AGENTS.md Invariable #2: every mechanic must be
## observable) — a real debug overlay/event log is future work (rule of two).
func _report_events(events: Array[Event]) -> void:
	for event in events:
		# Tracer lifecycle is handled ONCE, ahead of the match, deliberately: a shot has
		# FIVE terminal exits (hit / blocked / shield_broken / attack_absorbed /
		# projectile_expired) and per-arm handling would silently leak a tracer the first
		# time a sixth appeared. The rule is uniform -- any event other than the spawn
		# that carries my projectile_id ends me -- so it is expressed uniformly.
		if event.kind != "projectile_fired" and event.payload.has("projectile_id"):
			_despawn_tracer(int(event.payload["projectile_id"]))
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
				# A cancelled action must stop advertising a window that no longer exists
				# -- the sim already erased its susceptibility along with the windup.
				var interrupted_id: int = event.payload.get("actor_id")
				_windup_cues.erase(interrupted_id)
				if _enemies.has(interrupted_id):
					_enemies[interrupted_id].clear_telegraph()
			"flinched":
				print("FLINCHED: ", event.payload)
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
					_windup_cues.erase(actor_id)
					# _action_telegraphs is deliberately NOT pruned here: since P29 it is
					# keyed by ACTION, not actor, so it is resolved-once CONTENT shared by
					# every actor of that family. Erasing it on one death would silently
					# blank the tells of the next actor to use those actions. In-flight
					# tracers this actor fired also survive — a projectile outlives its
					# owner, exactly as it survives a flinch.
			"attack_telegraph":
				print("attack telegraph: ", event.payload)
				var actor_id: int = event.payload.get("actor_id")
				# P29: the COMMITTED action decides the tell, and the Event names it --
				# presentation never re-derives which action an actor chose.
				var action_id: String = String(event.payload.get("action_id", ""))
				if _enemies.has(actor_id) and _action_telegraphs.has(action_id):
					var telegraph: Dictionary = _action_telegraphs[action_id]
					var has_window: bool = int(telegraph.vulnerable_start) >= 0 and int(telegraph.vulnerable_end) >= int(telegraph.vulnerable_start)
					# An action with a window opens in the UNDERSTATED preparing phase, so the
					# window's arrival has somewhere to pop to; one with none keeps the flat
					# telegraph unchanged (Fang, Ooze).
					_enemies[actor_id].show_telegraph(telegraph.color, telegraph.duration_seconds, has_window)
					_windup_cues.erase(actor_id)
					if has_window:
						_windup_cues[actor_id] = {
							"opens_tick": event.tick + int(telegraph.vulnerable_start),
							"ends_tick": event.tick + int(telegraph.windup_ticks),
							"marked": false,
						}
			"attack_rejected":
				print("attack rejected: ", event.payload)
			"attack_absorbed":
				print("attack absorbed (iframes): ", event.payload)
			"blocked":
				print("blocked: ", event.payload)
			"shield_broken":
				print("shield broken: ", event.payload)
			"shield_bumped":
				print("shield bumped: ", event.payload)
			"parried":
				print("PARRIED: ", event.payload)
			"block_rejected":
				print("block rejected: ", event.payload)
			"projectile_fired":
				print("projectile fired: ", event.payload)
				_spawn_tracer(event.payload)
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
			# P17 burrow. Presentation mirrors the sim's authoritative participation fact; it never
			# decides it. Both kinds are printed rather than passed -- disappearing and reappearing
			# are exactly the beats a playtest needs to correlate against what it saw.
			# WHY a burrow happened, not just that it did: source (selector vs debug) and the
			# frustration elapsed at commitment. The scurry's detector was falsified by an autopsy
			# that should have run before play -- this makes the selector's reasoning readable
			# from an ordinary session log.
			# ENCOUNTERS. Presentation mirrors the sim's authoritative seal; it never decides one.
			# The barriers are a PICTURE of room confinement -- deleting them would leave a locked
			# encounter just as inescapable, only invisible.
			# FLOOR STATE. Every one of these mirrors an authoritative sim fact; presentation
			# decides none of them. A gate is a PICTURE of the sim having removed an aperture
			# from the walkable union -- delete this block and the route stays blocked.
			"connection_changed":
				print("connection changed: ", event.payload)
				_floor_builder.set_gate_closed(int(event.payload["connection_id"]), not bool(event.payload["open"]))
			"floor_trigger_fired":
				print("TRIGGER FIRED: ", event.payload)
			"avoidance_committed":
				print("AVOIDANCE COMMITTED: ", event.payload)
			"avoidance_cleared":
				print("avoidance cleared: ", event.payload)
			"floor_trigger_enabled":
				print("REVEALED: ", event.payload)
				_floor_builder.set_plate_visible(int(event.payload["trigger_id"]), true)
			"floor_complete":
				print("FLOOR COMPLETE: the expedition stood on the exit together")
			"breakable_hit":
				print("breakable hit: ", event.payload)
			"breakable_destroyed":
				print("BREAKABLE DESTROYED: ", event.payload)
				_floor_builder.remove_breakable(int(event.payload["breakable_id"]))
			"encounter_activated":
				print("ENCOUNTER ACTIVATED: ", event.payload)
				# A deferred roster ARRIVES here. Mirrored through the same two calls burrow
				# emergence uses -- teleport FIRST, so physics interpolation cannot draw them
				# flying in from wherever the node happened to be parked.
				for arrived_id: int in event.payload.get("actor_ids", []):
					if _enemies.has(arrived_id):
						_enemies[arrived_id].teleport_from_sim(_grounded(sim.entities[arrived_id]))
						_enemies[arrived_id].set_combat_present(true)
			"encounter_cleared":
				print("ENCOUNTER CLEARED: ", event.payload)
			"burrow_committed":
				print("burrow committed: ", event.payload)
			"burrow_submerged":
				print("burrow submerged: ", event.payload)
				var submerged_id: int = event.payload.get("actor_id")
				if _enemies.has(submerged_id):
					_enemies[submerged_id].set_combat_present(false)
					_enemies[submerged_id].clear_telegraph()
				_windup_cues.erase(submerged_id)
			"hazard_phase_changed":
				# Presentation PROJECTS the phase; it never owns it. The sim decided this on the
				# tick, and an animation that disagreed would be lying about where it is safe
				# to stand.
				_floor_builder.set_hazard_active(int(event.payload.get("pad_id", -1)), bool(event.payload.get("active", false)))
			"switch_activated":
				# A switch is a picture of a rule too: presentation reports the activation and
				# never decides what it did. The door it opened arrives as its own
				# connection_changed, through the same path a plate's would.
				print("switch activated: ", event.payload)
				_floor_builder.set_switch_state(int(event.payload.get("switch_id", -1)), true)
			"switch_revealed":
				print("switch revealed: ", event.payload)
				_floor_builder.set_switch_visible(int(event.payload.get("switch_id", -1)), true)
			"burrow_aborted":
				# The burrow failed and the Fang came back up where it went down. Presented
				# exactly like an emergence, because to the player it IS one -- what differs is
				# only where it happens, and that is already in the payload.
				print("burrow aborted to entry: ", event.payload)
				var aborted_id: int = event.payload.get("actor_id")
				if _enemies.has(aborted_id):
					_enemies[aborted_id].teleport_from_sim(event.payload.get("position"))
					_enemies[aborted_id].set_combat_present(true)
			"burrow_emerged":
				print("burrow emerged: ", event.payload)
				var emerged_id: int = event.payload.get("actor_id")
				if _enemies.has(emerged_id):
					# TELEPORT before showing, not sync: the node must arrive at the emergence
					# point with its render-side interpolation CANCELLED. Snapping alone is not
					# enough -- physics_interpolation is on, so the renderer would smoothly draw
					# the one-tick jump and the emergence reads as flying in from off-screen
					# (the Stage-1 playtest defect).
					_enemies[emerged_id].teleport_from_sim(event.payload.get("position"))
					_enemies[emerged_id].set_combat_present(true)
			# DELIBERATELY NOT REPORTED: emitted for every actor every tick, so printing it
			# would bury every other line. Recorded here so the next audit does not
			# re-litigate it.
			"moved":
				pass
			_:
				# THE GAP CLASS, closed mechanically. Twice a mechanic's events were absent from
				# this block and their absence was misread as the mechanic not firing -- once for
				# the scurry, once for the cutoff. An unhandled kind is now loud the moment it
				# first appears, so a new mechanic cannot ship silently unobservable. Every kind
				# above is either printed or explicitly passed; there is no third category.
				push_warning("arena: event kind '%s' has no reporting case -- add one, or add an explicit pass documenting why it is not reported" % event.kind)
