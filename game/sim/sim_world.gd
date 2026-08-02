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
var tick_count: int = 0


func add_entity(actor_id: int, position: Vector3, move_speed: float, facing: Vector3 = Vector3(0.0, 0.0, -1.0)) -> void:
	entities[actor_id] = position
	_move_speeds[actor_id] = move_speed
	_facings[actor_id] = _normalize_horizontal(facing, Vector3(0.0, 0.0, -1.0))


## Registers actor_id as a damageable target with a matrix row (GAME-RULES §3).
## Attackers (e.g. the Envoy this session) never call this — only entities that can
## be hit are candidates in _apply_attack's target search. iframe_ticks_on_hit is the
## invulnerability window (in sim ticks) a successful UNBLOCKED, NON-LETHAL hit grants
## this combatant — default 0 keeps existing callers (Fang before this session) inert.
func register_combatant(actor_id: int, max_health: float, family: StringName, iframe_ticks_on_hit: int = 0) -> void:
	_health[actor_id] = max_health
	_families[actor_id] = family
	_iframe_ticks_on_hit[actor_id] = iframe_ticks_on_hit


## Registers a melee weapon's resolved content values once at scene setup (mirrors
## add_entity's move_speed pattern) — set_equipped_weapon + Command.params.aim is all
## an attack Command needs; the numbers themselves never travel in a Command.
func register_weapon(weapon_id: StringName, damage: float, damage_type: StringName, reach: float, cone_half_angle_degrees: float, knockback_distance: float, fire_interval_ticks: int = 0) -> void:
	_weapons[String(weapon_id)] = {
		"resolution": "melee",
		"damage": damage,
		"damage_type": String(damage_type),
		"reach": reach,
		"cone_threshold": cos(deg_to_rad(cone_half_angle_degrees)),
		"knockback_distance": knockback_distance,
		"fire_interval_ticks": fire_interval_ticks,
	}


## Registers a ranged weapon (GAME-RULES §3: "projectile with travel time") — same
## _weapons table as register_weapon, tagged for deferred resolution instead of an
## instant multi-target sweep. speed is continuous (units/second, mirrors movement's
## convention); max_lifetime_ticks is a sim-tick count (§3: durations in sim ticks,
## never seconds in code) so an unfired shot always despawns deterministically.
func register_gun(weapon_id: StringName, damage: float, damage_type: StringName, speed: float, max_lifetime_ticks: int, hit_radius: float, knockback_distance: float, fire_interval_ticks: int = 0) -> void:
	_weapons[String(weapon_id)] = {
		"resolution": "projectile",
		"damage": damage,
		"damage_type": String(damage_type),
		"speed": speed,
		"max_lifetime_ticks": max_lifetime_ticks,
		"hit_radius": hit_radius,
		"knockback_distance": knockback_distance,
		"fire_interval_ticks": fire_interval_ticks,
	}


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
## -> hit detect -> damage-type matrix -> knockback -> death/events. A single discrete
## attack this session; the 3-hit combo and hold-to-charge (locked in GAME-RULES §3)
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
		events.append_array(_resolve_hit_on_target(actor_id, target_id, weapon, resolved_aim))

	return events


## Shared resolution tail (iframe gate -> damage matrix -> shield gate -> knockback ->
## death/events) for one attacker/target pair — GAME-RULES §3's pipeline is the SAME
## for every weapon class, so melee's per-target loop and a projectile's arrival
## (_advance_projectiles) both call this instead of duplicating it.
func _resolve_hit_on_target(attacker_id: int, target_id: int, weapon: Dictionary, resolved_aim: Vector3) -> Array[Event]:
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
	if remaining_health <= 0.0:
		events.append(Event.new(tick_count, "died", {"actor_id": target_id}))
	else:
		# Lethal hits start no timer (moot for the dead) — non-lethal unblocked hits
		# are the ONLY i-frame trigger this session (dodge is a future, separately-
		# scoped second trigger through this same timer).
		_iframe_ticks_remaining[target_id] = _iframe_ticks_on_hit.get(target_id, 0)
	return events


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
			events.append_array(_resolve_hit_on_target(projectile.attacker_id, hit_target_id, weapon, projectile.direction))
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
