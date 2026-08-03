class_name SimWorld
extends RefCounted
## The one mutation path for gameplay state (Prime Directive 1). Zero Node imports —
## GAME-RULES SS1.1's CI proof is a script ticking this 1000x with no display server.
## Entities register their tunables via add_entity/register_combatant/register_weapon/
## register_gun; set_equipped_weapon picks which one an actor's "attack" Commands
## resolve — Commands are requests, never authoritative tunables (GAME-RULES SS4.2's
## client/server boundary, built offline-first so M3 doesn't have to retrofit it);
## Command.params carries only per-tick intent. Content resources never cross into
## sim/ directly (that would be a Resource dependency baked into the sim boundary) —
## the scene driver resolves ContentDB lookups and unpacks plain values here, the same
## pattern add_entity already established for move_speed.

const _FACING_EPSILON_SQ: float = 0.000001

var entities: Dictionary = {}  # actor_id -> Vector3 position
var _move_speeds: Dictionary = {}  # actor_id -> float
var _facings: Dictionary = {}  # actor_id -> Vector3 (horizontal, normalized, never zero)
var _health: Dictionary = {}  # actor_id -> float (combatants only)
var _families: Dictionary = {}  # actor_id -> StringName (combatants only)
var _iframe_ticks_on_hit: Dictionary = {}  # actor_id -> int (combatants only)
var _iframe_ticks_remaining: Dictionary = {}  # actor_id -> int, counts down once per tick()
var _weapons: Dictionary = {}  # weapon_id(String) -> Dictionary of resolved weapon stats
var _equipped_weapon: Dictionary = {}  # actor_id -> weapon_id(String), sim-owned equip state
var _next_fire_tick: Dictionary = {}  # actor_id -> int, tick_count before which "attack" is rejected
var _projectiles: Dictionary = {}  # projectile_id(int) -> Dictionary of in-flight shot state
var _next_projectile_id: int = 0
var _matrix_families: Dictionary = {}  # family(String) -> {"weak_to": String, "resists": String}
var _matrix_weak_multiplier: float = 1.0
var _matrix_resist_multiplier: float = 1.0
var _shields: Dictionary = {}  # actor_id -> Dictionary of resolved shield stats
var _shield_state: Dictionary = {}  # actor_id -> "ready" | "held" | "broken"
var _shield_meter: Dictionary = {}  # actor_id -> float
var _shield_break_ticks_remaining: Dictionary = {}  # actor_id -> int
var _block_held_prev: Dictionary = {}  # actor_id -> bool, previous tick's held input (edge detection)
var _block_start_tick: Dictionary = {}  # actor_id -> int, tick of the last ready->held transition
var _combat_radius: Dictionary = {}  # actor_id -> float, contact-spread proximity radius (combatants only)
var _allegiance: Dictionary = {}  # actor_id -> StringName ("player" | "enemy"), for spread allegiance rules
## actor_id -> {id: String, ticks_remaining: int, next_tick: int, applied_tick: int}.
## One record per actor (single-status-slot law, GAME-RULES §3) instead of four
## parallel dictionaries -- the fields always travel together, so a status ending is
## one dictionary erase, not four synchronized ones.
var _status_instances: Dictionary = {}
var _status_config: Dictionary = {}  # status_id(String) -> {damage_per_tick, tick_interval_ticks, duration_ticks}
var _status_priority: Dictionary = {}  # status_id(String) -> int, higher replaces lower (GAME-RULES §3)
var _contact_transmitted_pairs: Dictionary = {}  # Vector2i(min_id, max_id) -> bool, current contact episode's transmission state
var tick_count: int = 0

## The combat RNG stream (GAME-RULES §1.3's first concrete consumer) — its own named
## RandomNumberGenerator instance, never the engine's global randi()/randf(). Future
## systems (loot, gen) get their OWN dedicated instances so their draws never shift
## combat's. Seeded deterministically to 0 in _init() below so even a bare
## SimWorld.new() (every existing call site) never falls back to OS entropy;
## seed_combat_rng() overrides it explicitly. The ONLY draw site is
## _roll_status_proc() — no other sim/ code may call randf()/randi() on this or any
## other stream.
var _combat_rng := RandomNumberGenerator.new()


func _init() -> void:
	_combat_rng.seed = 0


## Explicit combat-RNG seeding (GAME-RULES §1.3: seeded per-system, attributable).
## Callers (the dev scaffold's debug print, GUT tests) call this once after
## SimWorld.new() — mirrors register_status/set_damage_matrix's post-construction
## configuration pattern rather than a constructor param, so it never breaks the
## existing zero-arg SimWorld.new() call sites.
func seed_combat_rng(seed: int) -> void:
	_combat_rng.seed = seed


func add_entity(actor_id: int, position: Vector3, move_speed: float, facing: Vector3 = Vector3(0.0, 0.0, -1.0)) -> void:
	entities[actor_id] = position
	_move_speeds[actor_id] = move_speed
	_facings[actor_id] = _normalize_horizontal(facing, Vector3(0.0, 0.0, -1.0))


## Registers actor_id as a damageable target with a matrix row (GAME-RULES §3).
## Attackers (e.g. the Envoy this session) never call this — only entities that can
## be hit are candidates in _apply_attack's target search. iframe_ticks_on_hit is the
## invulnerability window (in sim ticks) a successful UNBLOCKED, NON-LETHAL hit grants
## this combatant — default 0 keeps existing callers (Fang before this session) inert.
## combat_radius/allegiance are Burn contact-spread inputs (GAME-RULES §3 "spreads on
## contact"): combat_radius=0.0 opts an actor out of ever overlapping anyone (existing
## callers that don't pass it stay inert); allegiance defaults "enemy" for the same
## backward-compat reason — the Envoy is the only caller that ever passes "player".
func register_combatant(actor_id: int, max_health: float, family: StringName, iframe_ticks_on_hit: int = 0, combat_radius: float = 0.0, allegiance: StringName = &"enemy") -> void:
	_health[actor_id] = max_health
	_families[actor_id] = family
	_iframe_ticks_on_hit[actor_id] = iframe_ticks_on_hit
	_combat_radius[actor_id] = combat_radius
	_allegiance[actor_id] = allegiance


## Registers a melee weapon's resolved content values once at scene setup (mirrors
## add_entity's move_speed pattern) — set_equipped_weapon + Command.params.aim is all
## an attack Command needs; the numbers themselves never travel in a Command.
## status_id is an optional status payload (GAME-RULES §3) — empty StringName means
## this weapon never applies a status; a successful non-lethal, unblocked hit from a
## weapon carrying one calls _apply_status from _resolve_hit_on_target.
## status_proc_chance is the normal-hit proc rate (default 0.0 — a weapon with a
## status_id but zero chance never actually applies it); 0.0/1.0 short-circuit
## deterministically without drawing from _combat_rng (see _roll_status_proc).
func register_weapon(weapon_id: StringName, damage: float, damage_type: StringName, reach: float, cone_half_angle_degrees: float, knockback_distance: float, fire_interval_ticks: int = 0, status_id: StringName = &"", status_proc_chance: float = 0.0) -> void:
	_weapons[String(weapon_id)] = {
		"resolution": "melee",
		"damage": damage,
		"damage_type": String(damage_type),
		"reach": reach,
		"cone_threshold": cos(deg_to_rad(cone_half_angle_degrees)),
		"knockback_distance": knockback_distance,
		"fire_interval_ticks": fire_interval_ticks,
		"status_id": String(status_id),
		"status_proc_chance": status_proc_chance,
	}


## Registers a ranged weapon (GAME-RULES §3: "projectile with travel time") — same
## _weapons table as register_weapon, tagged for deferred resolution instead of an
## instant multi-target sweep. speed is continuous (units/second, mirrors movement's
## convention); max_lifetime_ticks is a sim-tick count (§3: durations in sim ticks,
## never seconds in code) so an unfired shot always despawns deterministically.
## status_id/status_proc_chance: see register_weapon.
func register_gun(weapon_id: StringName, damage: float, damage_type: StringName, speed: float, max_lifetime_ticks: int, hit_radius: float, knockback_distance: float, fire_interval_ticks: int = 0, status_id: StringName = &"", status_proc_chance: float = 0.0) -> void:
	_weapons[String(weapon_id)] = {
		"resolution": "projectile",
		"damage": damage,
		"damage_type": String(damage_type),
		"speed": speed,
		"max_lifetime_ticks": max_lifetime_ticks,
		"hit_radius": hit_radius,
		"knockback_distance": knockback_distance,
		"fire_interval_ticks": fire_interval_ticks,
		"status_id": String(status_id),
		"status_proc_chance": status_proc_chance,
	}


## Registers a status effect's resolved content values (GAME-RULES §3: Burn v1 —
## DoT ticks, spreads on contact, one slot per entity). tick_interval_ticks/
## duration_ticks are sim-tick counts, never seconds in code.
func register_status(status_id: StringName, damage_per_tick: float, tick_interval_ticks: int, duration_ticks: int) -> void:
	_status_config[String(status_id)] = {
		"damage_per_tick": damage_per_tick,
		"tick_interval_ticks": tick_interval_ticks,
		"duration_ticks": duration_ticks,
	}


## Installs the cross-status replacement priority (GAME-RULES §3: statuses are
## exclusive, never stacked — a new status replaces the current one per a priority
## table in data). Ships as real data from day one even with only Burn registered,
## same pattern as the damage matrix shipping all six families before content catches
## up — a second status (ROADMAP P2) is a data change here, not a code change.
func set_status_priority(priority: Dictionary) -> void:
	_status_priority = priority


## Sets which registered weapon_id resolves actor_id's "attack" Commands — sim-owned
## equip state, not yet switchable at runtime (this slice sets it once at scene
## setup). Presentation sends only per-action intent (aim); it never tells the sim
## which weapon to use for a given swing.
func set_equipped_weapon(actor_id: int, weapon_id: StringName) -> void:
	_equipped_weapon[actor_id] = String(weapon_id)


## Installs the family x damage-type matrix (GAME-RULES §3) — one resource, resolved
## by the driver from ContentDB, unpacked here as plain data.
func set_damage_matrix(families: Dictionary, weak_multiplier: float, resist_multiplier: float) -> void:
	_matrix_families = families
	_matrix_weak_multiplier = weak_multiplier
	_matrix_resist_multiplier = resist_multiplier


## Registers actor_id as a shield-capable blocker (GAME-RULES §3) — starts in the
## "ready" state with a full meter. Only entities with a registered shield process
## "block" Commands; unregistered actors silently ignore them (_apply_block).
func register_shield(actor_id: int, meter_max: float, regen_per_tick: float, break_recovery_delay_ticks: int, knockback_distance: float) -> void:
	_shields[actor_id] = {
		"meter_max": meter_max,
		"regen_per_tick": regen_per_tick,
		"break_recovery_delay_ticks": break_recovery_delay_ticks,
		"knockback_distance": knockback_distance,
	}
	_shield_state[actor_id] = "ready"
	_shield_meter[actor_id] = meter_max


## Autonomous-phase law (GAME-RULES §2): a phase that scans all actors on its own
## (contact spread, status resolution — and future Frost/Venom/Hex/AI behaviors) never
## mutates the collection it's iterating. Secondary effects (new spread recipients,
## expirations, deaths) are collected during a read-only scan and committed in a
## separate pass afterward, so one actor's resolution can never change a later
## actor's eligibility within the same phase.
func tick(commands: Array[Command], dt: float) -> Array[Event]:
	_advance_iframes()
	# Projectiles advance before this tick's Commands are processed (mirrors
	# _advance_iframes running first) — a shot spawned THIS tick doesn't also travel
	# this tick, so spawn and first step of travel always land on separate ticks, same
	# as a melee swing resolving instantly on its own tick.
	var events: Array[Event] = _advance_projectiles(dt)
	for command in commands:
		if command.kind == "move":
			events.append(_apply_move(command, dt))
		elif command.kind == "attack":
			events.append_array(_apply_attack(command))
		elif command.kind == "block":
			events.append_array(_apply_block(command))
	# Contact spread reads this tick's post-attack status state (so a hit-applied
	# status this same tick is visible as a snapshot candidate, but its one-tick grace
	# keeps it from actually transmitting until a later tick); status ticking then
	# resolves DoT/duration for anyone due. Both run after Commands, before tick_count
	# advances, per the locked Burn contact-episode design.
	events.append_array(_advance_contact_spread())
	events.append_array(_advance_status_ticks())
	tick_count += 1
	return events


## Invulnerability timers live entirely in SimWorld and count down once per tick()
## call, independent of which Commands arrive — never derived from Commands
## themselves (GAME-RULES §3: durations in sim ticks, never seconds in code).
func _advance_iframes() -> void:
	for actor_id in _iframe_ticks_remaining.keys():
		if _iframe_ticks_remaining[actor_id] > 0:
			_iframe_ticks_remaining[actor_id] -= 1


func _apply_move(command: Command, dt: float) -> Event:
	var position: Vector3 = entities.get(command.actor_id, Vector3.ZERO)
	var direction: Vector3 = command.params.get("direction", Vector3.ZERO)
	var speed: float = _move_speeds.get(command.actor_id, 0.0)
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		_facings[command.actor_id] = direction
	position += direction * speed * dt
	entities[command.actor_id] = position
	return Event.new(tick_count, "moved", {"actor_id": command.actor_id, "position": position})


## Combat pipeline order (GAME-RULES §3 / CLAUDE.md Core Interfaces, fixed): validate
## -> hit detect -> damage-type matrix -> status -> knockback -> death/events. A single
## discrete attack this session; the 3-hit combo and hold-to-charge (locked in GAME-RULES §3)
## will sequence multiple attacks through this same pipeline, not a second path.
## The equipped weapon (set_equipped_weapon) decides resolution: melee sweeps all
## qualifying targets instantly; a gun spawns a projectile and resolves later
## (_advance_projectiles) — both funnel into the same _resolve_hit_on_target tail.
func _apply_attack(command: Command) -> Array[Event]:
	var actor_id: int = command.actor_id
	if _health.get(actor_id, 1.0) <= 0.0:
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "attacker_dead"})]

	var weapon_id: String = _equipped_weapon.get(actor_id, "")
	if not _weapons.has(weapon_id):
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "invalid_weapon"})]
	var weapon: Dictionary = _weapons[weapon_id]

	# Per-weapon rate limit (manual playtest finding: spam-clicking the gun fired a new
	# shot every tick, far past any intended cadence). fire_interval_ticks defaults to
	# 0 -- a no-op gate -- so melee (no cooldown configured this session) is unaffected.
	if tick_count < _next_fire_tick.get(actor_id, 0):
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "on_cooldown"})]
	_next_fire_tick[actor_id] = tick_count + int(weapon.get("fire_interval_ticks", 0))

	var attacker_position: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var stored_facing: Vector3 = _facings.get(actor_id, Vector3(0.0, 0.0, -1.0))
	var aim: Vector3 = command.params.get("aim", Vector3.ZERO)
	var resolved_aim: Vector3 = _normalize_horizontal(aim, stored_facing)
	# Facing only mutates on an ACCEPTED attack (past both rejection checks above) —
	# a cooldown/invalid attack spammed during downtime must not grant a free turn.
	_facings[actor_id] = resolved_aim

	if weapon.resolution == "projectile":
		return _spawn_projectile(actor_id, weapon_id, weapon, attacker_position, resolved_aim)

	var events: Array[Event] = []
	var target_ids: Array = _families.keys().filter(func(id): return id != actor_id and _health.get(id, 0.0) > 0.0)
	target_ids.sort()  # dictionary iteration order must never leak into event order

	for target_id in target_ids:
		var target_position: Vector3 = entities.get(target_id, Vector3.ZERO)
		var offset: Vector3 = target_position - attacker_position
		offset.y = 0.0
		var distance_sq: float = offset.length_squared()
		if distance_sq > weapon.reach * weapon.reach:
			continue
		if distance_sq > _FACING_EPSILON_SQ:
			var normalized_offset: Vector3 = offset / sqrt(distance_sq)
			if resolved_aim.dot(normalized_offset) < weapon.cone_threshold:
				continue
		# else: attacker and target share a position — hit at zero distance, cone check
		# doesn't apply (no defined direction to check against).
		events.append_array(_resolve_hit_on_target(actor_id, target_id, weapon, resolved_aim, weapon_id))

	return events


## Shared resolution tail (iframe gate -> damage matrix -> shield gate -> status ->
## knockback -> death/events) for one attacker/target pair — GAME-RULES §3's pipeline
## is the SAME for every weapon class, so melee's per-target loop and a projectile's
## arrival (_advance_projectiles) both call this instead of duplicating it.
func _resolve_hit_on_target(attacker_id: int, target_id: int, weapon: Dictionary, resolved_aim: Vector3, weapon_id: String) -> Array[Event]:
	# i-frames fully negate a hit: no damage, no knockback, no status, no meter
	# interaction — the attack simply doesn't land (locked invariant).
	if _iframe_ticks_remaining.get(target_id, 0) > 0:
		return [Event.new(tick_count, "attack_absorbed", {
			"attacker_id": attacker_id, "target_id": target_id, "reason": "iframes",
		})]

	var family: StringName = _families[target_id]
	var multiplier: float = _damage_multiplier(weapon.damage_type, family)
	var damage: float = weapon.damage * multiplier
	var target_position: Vector3 = entities.get(target_id, Vector3.ZERO)

	# A held shield redirects damage into its own meter instead of health — no health
	# loss, no weapon knockback, no i-frames (distinct defenses; block must not also
	# grant invulnerability). See _resolve_blocked_hit.
	if _shield_state.get(target_id, "ready") == "held":
		return [_resolve_blocked_hit(target_id, target_position, resolved_aim, attacker_id, damage)]

	var remaining_health: float = _health[target_id] - damage
	_health[target_id] = remaining_health
	var knocked_position: Vector3 = target_position + resolved_aim * weapon.knockback_distance
	entities[target_id] = knocked_position

	var events: Array[Event] = [Event.new(tick_count, "hit", {
		"attacker_id": attacker_id,
		"target_id": target_id,
		"damage": damage,
		"damage_type": weapon.damage_type,
		"family": family,
		"position": knocked_position,
	})]

	# Roll-consumption rule (locked): the proc roll happens here, UNCONDITIONALLY,
	# regardless of whether this hit turns out lethal — a weapon with no status_id
	# never reaches _roll_status_proc at all (sword_A/wand_A are unaffected). The
	# target's remaining health must never affect whether _combat_rng advances, or
	# identical seeds would diverge based on victim HP; only the ACTUAL status
	# application (below) is gated on survival, matching the i-frame precedent (no
	# point arming a DoT on a corpse).
	var proc_result: Dictionary = {}
	if weapon.get("status_id", "") != "":
		proc_result = _roll_status_proc(attacker_id, target_id, weapon, weapon_id)
		events.append(proc_result.event)

	if remaining_health <= 0.0:
		events.append(Event.new(tick_count, "died", {"actor_id": target_id}))
	else:
		# Lethal hits start no timer (moot for the dead) — non-lethal unblocked hits
		# are the ONLY i-frame trigger this session (dodge is a future, separately-
		# scoped second trigger through this same timer).
		_iframe_ticks_remaining[target_id] = _iframe_ticks_on_hit.get(target_id, 0)
		if proc_result.get("succeeded", false):
			events.append(_apply_status(target_id, weapon.status_id, "hit", attacker_id, weapon_id))
	return events


## Rolls a status-carrying weapon's normal-hit proc chance exactly once (GAME-RULES
## §1.3's first concrete combat-RNG consumer). chance <= 0.0 and >= 1.0 short-circuit
## deterministically WITHOUT drawing from _combat_rng (guns and, later, a charged
## attack's separate proc value stay off the stream entirely at those boundaries) —
## only a genuine 0.0-1.0 chance consumes one _combat_rng.randf() call. Always
## returns a status_proc Event (one kind, not separate attempted/succeeded/failed
## kinds) regardless of the outcome, so the roll is observable even on a lethal hit
## where the status itself never gets armed.
func _roll_status_proc(attacker_id: int, target_id: int, weapon: Dictionary, weapon_id: String) -> Dictionary:
	var status_id: String = weapon.status_id
	var chance: float = weapon.get("status_proc_chance", 0.0)
	var succeeded: bool
	if chance <= 0.0:
		succeeded = false
	elif chance >= 1.0:
		succeeded = true
	else:
		succeeded = _combat_rng.randf() < chance
	var event := Event.new(tick_count, "status_proc", {
		"attacker_id": attacker_id,
		"target_id": target_id,
		"status_id": status_id,
		"chance": chance,
		"result": ("success" if succeeded else "fail"),
	})
	return {"event": event, "succeeded": succeeded}


## Spawns a deferred-resolution shot (GAME-RULES §3: "ranged: projectile with travel
## time"). No hit resolves on the spawning tick — _advance_projectiles sweeps its path
## each subsequent tick() call until it lands or expires. Nothing caps concurrent
## shots this slice (no ammo/reload/rate-limit is in scope).
func _spawn_projectile(attacker_id: int, weapon_id: String, weapon: Dictionary, position: Vector3, direction: Vector3) -> Array[Event]:
	var projectile_id: int = _next_projectile_id
	_next_projectile_id += 1
	_projectiles[projectile_id] = {
		"attacker_id": attacker_id,
		"weapon_id": weapon_id,
		"weapon": weapon,
		"position": position,
		"direction": direction,
		"ticks_alive": 0,
	}
	return [Event.new(tick_count, "projectile_fired", {
		"attacker_id": attacker_id, "weapon_id": weapon_id, "projectile_id": projectile_id,
		"position": position, "direction": direction,
	})]


## Sweeps every live projectile's this-tick travel SEGMENT (not just its endpoint)
## against combatants, so a shot can't tunnel through a target it crossed mid-tick.
## A hit resolves through the same _resolve_hit_on_target melee uses — a bullet is
## gated by iframes/shield exactly like a sword swing. Expires unfired shots after
## max_lifetime_ticks (a sim-tick count, GAME-RULES §3).
func _advance_projectiles(dt: float) -> Array[Event]:
	var events: Array[Event] = []
	var expired_ids: Array = []
	var projectile_ids: Array = _projectiles.keys()
	projectile_ids.sort()  # determinism — dictionary iteration order must never leak into event order

	for projectile_id in projectile_ids:
		var projectile: Dictionary = _projectiles[projectile_id]
		var weapon: Dictionary = projectile.weapon
		var start_position: Vector3 = projectile.position
		var end_position: Vector3 = start_position + projectile.direction * weapon.speed * dt

		var hit_target_id: int = _find_earliest_swept_hit(start_position, end_position, projectile.attacker_id, weapon.hit_radius)
		if hit_target_id != -1:
			events.append_array(_resolve_hit_on_target(projectile.attacker_id, hit_target_id, weapon, projectile.direction, projectile.weapon_id))
			expired_ids.append(projectile_id)
			continue

		projectile.position = end_position
		projectile.ticks_alive += 1
		if projectile.ticks_alive >= weapon.max_lifetime_ticks:
			events.append(Event.new(tick_count, "projectile_expired", {
				"attacker_id": projectile.attacker_id, "weapon_id": projectile.weapon_id,
				"projectile_id": projectile_id, "position": projectile.position,
			}))
			expired_ids.append(projectile_id)

	for projectile_id in expired_ids:
		_projectiles.erase(projectile_id)
	return events


## Closest-point-on-segment test against every live, targetable combatant except the
## shooter — earliest intersection along the segment wins; sorted ascending actor_id
## iteration breaks an exact tie in favor of the lower id (mirrors melee's sorted-
## target-id determinism rule). Returns -1 for no hit.
func _find_earliest_swept_hit(start: Vector3, end: Vector3, attacker_id: int, hit_radius: float) -> int:
	var travel: Vector3 = end - start
	var travel_length_sq: float = travel.length_squared()

	var best_target_id: int = -1
	var best_t: float = INF
	var candidate_ids: Array = _families.keys().filter(func(id): return id != attacker_id and _health.get(id, 0.0) > 0.0)
	candidate_ids.sort()

	for target_id in candidate_ids:
		var target_position: Vector3 = entities.get(target_id, Vector3.ZERO)
		var t: float = 0.0
		if travel_length_sq > _FACING_EPSILON_SQ:
			t = clamp((target_position - start).dot(travel) / travel_length_sq, 0.0, 1.0)
		var closest_point: Vector3 = start + travel * t
		if closest_point.distance_squared_to(target_position) <= hit_radius * hit_radius and t < best_t:
			best_t = t
			best_target_id = target_id

	return best_target_id


## Resolves damage against a HELD shield (GAME-RULES §3: own break meter, knockback
## on break). Full absorption, zero spill: meter clamps at 0 on overflow, the target
## takes no health damage that swing — poor meter management is punished by the
## BROKEN state (block forced off, exposed, own knockback), not partial HP loss.
func _resolve_blocked_hit(target_id: int, target_position: Vector3, resolved_aim: Vector3, attacker_id: int, damage: float) -> Event:
	var shield: Dictionary = _shields[target_id]
	var remaining_meter: float = _shield_meter.get(target_id, 0.0)
	if damage >= remaining_meter:
		_shield_meter[target_id] = 0.0
		_shield_state[target_id] = "broken"
		_shield_break_ticks_remaining[target_id] = shield.break_recovery_delay_ticks
		var knocked_position: Vector3 = target_position + resolved_aim * shield.knockback_distance
		entities[target_id] = knocked_position
		return Event.new(tick_count, "shield_broken", {
			"actor_id": target_id, "attacker_id": attacker_id, "position": knocked_position,
		})
	_shield_meter[target_id] = remaining_meter - damage
	return Event.new(tick_count, "blocked", {
		"attacker_id": attacker_id, "target_id": target_id,
		"damage_absorbed": damage, "remaining_meter": _shield_meter[target_id],
	})


## "block" Command handler: held is the raw per-tick input (mirrors move's continuous
## style — every tick fully declares intent, replay/prediction-friendly for M3).
## Unregistered actors (no shield) silently ignore block Commands. State machine
## (GAME-RULES §3, this session's design lock):
##   READY  — shield lowered, meter regenerates toward max each tick.
##   HELD   — actively blocking, meter frozen (holding is a commitment).
##   BROKEN — meter hit 0 via _resolve_blocked_hit; no regen until
##            break_recovery_delay_ticks elapse, then regen resumes and the instant
##            meter > 0 the state becomes READY (no minimum threshold).
## READY -> HELD requires a RISING EDGE of held (prev tick false, this tick true) —
## not just "state is ready and held is true". This is deliberate: it makes holding
## straight through a break never auto-re-enter HELD (which would freeze regen at a
## sliver), while a genuine first press or a release-then-repress both still work,
## because both produce a real edge. No separate "just recovered" flag needed.
func _apply_block(command: Command) -> Array[Event]:
	var actor_id: int = command.actor_id
	if not _shields.has(actor_id):
		return []

	var held: bool = command.params.get("held", false)
	var rising_edge: bool = held and not _block_held_prev.get(actor_id, false)
	_block_held_prev[actor_id] = held

	var shield: Dictionary = _shields[actor_id]
	var state: String = _shield_state.get(actor_id, "ready")

	# Time-based recovery/regen bookkeeping — independent of this tick's input.
	if state == "broken":
		if _shield_break_ticks_remaining.get(actor_id, 0) > 0:
			_shield_break_ticks_remaining[actor_id] -= 1
		else:
			var recovered_meter: float = min(_shield_meter.get(actor_id, 0.0) + shield.regen_per_tick, shield.meter_max)
			_shield_meter[actor_id] = recovered_meter
			if recovered_meter > 0.0:
				state = "ready"
				_shield_state[actor_id] = "ready"
	elif state == "ready":
		_shield_meter[actor_id] = min(_shield_meter.get(actor_id, 0.0) + shield.regen_per_tick, shield.meter_max)
	# "held": meter stays frozen — no regen while actively blocking.

	# This tick's input against the (possibly just-recovered) state.
	if state == "broken":
		if held:
			return [Event.new(tick_count, "block_rejected", {"actor_id": actor_id, "reason": "broken"})]
	elif state == "ready":
		if held and rising_edge:
			_shield_state[actor_id] = "held"
			_block_start_tick[actor_id] = tick_count
	elif state == "held":
		if not held:
			_shield_state[actor_id] = "ready"

	return []


## Arms/refreshes target_id's single status slot (GAME-RULES §3: exclusive, never
## stacked). Re-applying the SAME status_id always refreshes (a melee weapon hitting
## an already-Burning target resets its clock); a DIFFERENT status only overwrites
## when its priority is >= the active one's — with only Burn registered this session
## that branch is structurally present but unreachable/untested until a second status
## (ROADMAP P2) makes it real, same "ships complete, content catches up" shape as the
## damage matrix. applied_tick is the one-tick grace gate: a status armed THIS tick
## cannot deal a DoT pulse or act as a contact-spread source until a later tick.
func _apply_status(target_id: int, status_id: StringName, application_source: String, source_actor_id: int, source_weapon_id: String) -> Event:
	var new_id: String = String(status_id)
	var existing: Dictionary = _status_instances.get(target_id, {})
	var can_apply: bool = existing.is_empty() or existing.id == new_id or _status_priority.get(new_id, 0) >= _status_priority.get(existing.id, 0)
	if can_apply:
		var config: Dictionary = _status_config[new_id]
		_status_instances[target_id] = {
			"id": new_id,
			"ticks_remaining": config.duration_ticks,
			"next_tick": tick_count + config.tick_interval_ticks,
			"applied_tick": tick_count,
		}
	var payload: Dictionary = {
		"target_id": target_id,
		"status_id": new_id,
		"application_source": application_source,
		"source_actor_id": source_actor_id,
	}
	if application_source == "hit":
		payload["source_weapon_id"] = source_weapon_id
	return Event.new(tick_count, "status_applied", payload)


## True if a and b's registered combat_radius circles overlap (horizontal distance —
## flattened like melee's reach check, GAME-RULES §3 "spreads on contact"). Pure
## SimWorld distance math against `entities`/`_combat_radius` — no Area3D/
## body_entered, no generic collision subsystem (locked scope fence).
func _actors_overlap(a: int, b: int) -> bool:
	var offset: Vector3 = entities.get(b, Vector3.ZERO) - entities.get(a, Vector3.ZERO)
	offset.y = 0.0
	var radius_sum: float = _combat_radius.get(a, 0.0) + _combat_radius.get(b, 0.0)
	return offset.length_squared() <= radius_sum * radius_sum


## Autonomous-phase law (see tick()): erases a transmitted-pair marker once its actors
## separate or either dies, collected first then erased, never mutating
## _contact_transmitted_pairs while iterating it.
func _cleanup_stale_contact_pairs() -> void:
	var stale: Array = []
	for pair_key in _contact_transmitted_pairs.keys():
		var a: int = pair_key.x
		var b: int = pair_key.y
		if _health.get(a, 0.0) <= 0.0 or _health.get(b, 0.0) <= 0.0 or not _actors_overlap(a, b):
			stale.append(pair_key)
	for pair_key in stale:
		_contact_transmitted_pairs.erase(pair_key)


## Burn contact-episode spread (GAME-RULES §3 "spreads on contact", locked design):
## an unburned, alive actor catches a status from an overlapping actor whose status
## was armed on a STRICTLY EARLIER tick (the one-tick grace — both hit- and
## spread-applied statuses are silent on their own application tick), whose ordered
## pair hasn't already transmitted during this continuous overlap episode, and whose
## allegiance pair isn't player<->player. Recipients are collected against an
## immutable snapshot of eligible sources taken at the top of this phase — an actor
## gaining or losing its status later in the SAME tick (via this collected spread, or
## via the status-tick phase that runs after this one) never changes who could source
## a transmission during this scan (autonomous-phase law, see tick()).
func _advance_contact_spread() -> Array[Event]:
	var events: Array[Event] = []
	_cleanup_stale_contact_pairs()

	var eligible_sources: Dictionary = {}  # actor_id -> status_id, snapshot -- never re-read after this loop
	for actor_id in _status_instances.keys():
		var instance: Dictionary = _status_instances[actor_id]
		if instance.applied_tick < tick_count and _health.get(actor_id, 0.0) > 0.0:
			eligible_sources[actor_id] = instance.id

	var alive_ids: Array = _families.keys().filter(func(id): return _health.get(id, 0.0) > 0.0)
	alive_ids.sort()  # determinism -- dictionary iteration order must never leak into event order

	var collected: Array = []  # {recipient, source, status_id, pair_key}
	for i in range(alive_ids.size()):
		for j in range(i + 1, alive_ids.size()):
			var a: int = alive_ids[i]
			var b: int = alive_ids[j]  # b > a always, so Vector2i(a, b) is already the canonical (min, max) key
			var pair_key := Vector2i(a, b)
			if _contact_transmitted_pairs.get(pair_key, false):
				continue
			if not _actors_overlap(a, b):
				continue
			var a_eligible: bool = eligible_sources.has(a)
			var b_eligible: bool = eligible_sources.has(b)
			if a_eligible == b_eligible:
				continue  # both or neither are an eligible source -- nothing to transmit
			var source_id: int = a if a_eligible else b
			var recipient_id: int = b if a_eligible else a
			if _status_instances.has(recipient_id):
				continue  # recipient already has an active status -- not "unburned"
			if _allegiance.get(source_id, &"enemy") == &"player" and _allegiance.get(recipient_id, &"enemy") == &"player":
				continue  # player -> player spread is explicitly rejected this session
			collected.append({"recipient": recipient_id, "source": source_id, "status_id": eligible_sources[source_id], "pair_key": pair_key})

	collected.sort_custom(func(x, y): return x.recipient < y.recipient if x.recipient != y.recipient else x.source < y.source)
	for entry in collected:
		_contact_transmitted_pairs[entry.pair_key] = true
		events.append(_apply_status(entry.recipient, entry.status_id, "spread", entry.source, ""))
	return events


## The seam a future status×family interaction layer (ROADMAP P2 -- e.g. Ooze healing
## from Burn) slots into without touching application, spread, timing, or determinism.
## M1 only ever returns a damage outcome; the function exists so nothing downstream of
## it assumes "status tick == health loss" in a way that would need restructuring.
func _compute_status_tick_outcome(status_id: String) -> Dictionary:
	var config: Dictionary = _status_config.get(status_id, {})
	return {"damage": config.get("damage_per_tick", 0.0)}


## DoT/duration resolution for every actor with an active status (GAME-RULES §3).
## Autonomous-phase law (see tick()): the scan below is read-only (only calls
## _compute_status_tick_outcome and reads existing instance fields); every mutation
## (health loss, next_tick advance, duration decrement, expiry, death) is committed in
## the second loop, after the scan has finished, so no actor's resolution this tick can
## change another actor's outcome within the same phase.
func _advance_status_ticks() -> Array[Event]:
	var events: Array[Event] = []
	var actor_ids: Array = _status_instances.keys().filter(func(id): return _health.get(id, 0.0) > 0.0)
	actor_ids.sort()  # determinism -- dictionary iteration order must never leak into event order

	var planned: Array = []
	for actor_id in actor_ids:
		var instance: Dictionary = _status_instances[actor_id]
		if instance.applied_tick == tick_count:
			continue  # grace -- armed this very tick, resolves starting next tick
		var due: bool = tick_count >= instance.next_tick
		planned.append({
			"actor_id": actor_id,
			"status_id": instance.id,
			"outcome": (_compute_status_tick_outcome(instance.id) if due else {}),
			"next_tick": (tick_count + _status_config[instance.id].get("tick_interval_ticks", 1) if due else instance.next_tick),
			"will_expire": instance.ticks_remaining - 1 <= 0,
		})

	for entry in planned:
		var actor_id: int = entry.actor_id
		var instance: Dictionary = _status_instances[actor_id]
		instance.next_tick = entry.next_tick
		var died: bool = false
		if entry.outcome.has("damage"):
			var remaining_health: float = _health[actor_id] - entry.outcome.damage
			_health[actor_id] = remaining_health
			events.append(Event.new(tick_count, "status_resolved", {"actor_id": actor_id, "status_id": entry.status_id, "damage": entry.outcome.damage}))
			if remaining_health <= 0.0:
				events.append(Event.new(tick_count, "died", {"actor_id": actor_id}))
				_status_instances.erase(actor_id)
				died = true
		if not died:
			instance.ticks_remaining -= 1
			if entry.will_expire:
				events.append(Event.new(tick_count, "status_expired", {"actor_id": actor_id, "status_id": entry.status_id}))
				_status_instances.erase(actor_id)
	return events


func _damage_multiplier(damage_type: String, family: StringName) -> float:
	var row: Dictionary = _matrix_families.get(String(family), {})
	if row.get("weak_to", "") == damage_type:
		return _matrix_weak_multiplier
	if row.get("resists", "") == damage_type:
		return _matrix_resist_multiplier
	return 1.0


## Flattens to the horizontal plane; falls back to `fallback` for zero-length,
## non-finite, or vertical-only input (GAME-RULES §4.2 spirit: never trust a raw
## input vector — this is also the shape M3's server-side validation inherits).
func _normalize_horizontal(vector: Vector3, fallback: Vector3) -> Vector3:
	var horizontal := Vector3(vector.x, 0.0, vector.z)
	if is_finite(horizontal.x) and is_finite(horizontal.z) and horizontal.length_squared() > _FACING_EPSILON_SQ:
		return horizontal.normalized()
	return fallback
