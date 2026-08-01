class_name SimWorld
extends RefCounted
## The one mutation path for gameplay state (Prime Directive 1). Zero Node imports —
## GAME-RULES SS1.1's CI proof is a script ticking this 1000x with no display server.
## Entities register their tunables via add_entity/register_combatant/register_weapon —
## Commands are requests, never authoritative tunables (GAME-RULES SS4.2's
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
var _weapons: Dictionary = {}  # weapon_id(String) -> Dictionary of resolved weapon stats
var _matrix_families: Dictionary = {}  # family(String) -> {"weak_to": String, "resists": String}
var _matrix_weak_multiplier: float = 1.0
var _matrix_resist_multiplier: float = 1.0
var tick_count: int = 0


func add_entity(actor_id: int, position: Vector3, move_speed: float, facing: Vector3 = Vector3(0.0, 0.0, -1.0)) -> void:
	entities[actor_id] = position
	_move_speeds[actor_id] = move_speed
	_facings[actor_id] = _normalize_horizontal(facing, Vector3(0.0, 0.0, -1.0))


## Registers actor_id as a damageable target with a matrix row (GAME-RULES §3).
## Attackers (e.g. the Envoy this session) never call this — only entities that can
## be hit are candidates in _apply_attack's target search.
func register_combatant(actor_id: int, max_health: float, family: StringName) -> void:
	_health[actor_id] = max_health
	_families[actor_id] = family


## Registers a weapon's resolved content values once at scene setup (mirrors
## add_entity's move_speed pattern) — Command.params.weapon_id looks this up per
## attack; the numbers themselves never travel in a Command.
func register_weapon(weapon_id: StringName, damage: float, damage_type: StringName, reach: float, cone_half_angle_degrees: float, knockback_distance: float) -> void:
	_weapons[String(weapon_id)] = {
		"damage": damage,
		"damage_type": String(damage_type),
		"reach": reach,
		"cone_threshold": cos(deg_to_rad(cone_half_angle_degrees)),
		"knockback_distance": knockback_distance,
	}


## Installs the family x damage-type matrix (GAME-RULES §3) — one resource, resolved
## by the driver from ContentDB, unpacked here as plain data.
func set_damage_matrix(families: Dictionary, weak_multiplier: float, resist_multiplier: float) -> void:
	_matrix_families = families
	_matrix_weak_multiplier = weak_multiplier
	_matrix_resist_multiplier = resist_multiplier


func tick(commands: Array[Command], dt: float) -> Array[Event]:
	var events: Array[Event] = []
	for command in commands:
		if command.kind == "move":
			events.append(_apply_move(command, dt))
		elif command.kind == "attack":
			events.append_array(_apply_attack(command))
	tick_count += 1
	return events


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
func _apply_attack(command: Command) -> Array[Event]:
	var actor_id: int = command.actor_id
	if _health.get(actor_id, 1.0) <= 0.0:
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "attacker_dead"})]

	var weapon_id := String(command.params.get("weapon_id", ""))
	if not _weapons.has(weapon_id):
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "invalid_weapon"})]
	var weapon: Dictionary = _weapons[weapon_id]

	var attacker_position: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var stored_facing: Vector3 = _facings.get(actor_id, Vector3(0.0, 0.0, -1.0))
	var aim: Vector3 = command.params.get("aim", Vector3.ZERO)
	var resolved_aim: Vector3 = _normalize_horizontal(aim, stored_facing)
	# Facing only mutates on an ACCEPTED attack (past both rejection checks above) —
	# a cooldown/invalid attack spammed during downtime must not grant a free turn.
	_facings[actor_id] = resolved_aim

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

		var family: StringName = _families[target_id]
		var multiplier: float = _damage_multiplier(weapon.damage_type, family)
		var damage: float = weapon.damage * multiplier
		var remaining_health: float = _health[target_id] - damage
		_health[target_id] = remaining_health
		var knocked_position: Vector3 = target_position + resolved_aim * weapon.knockback_distance
		entities[target_id] = knocked_position

		events.append(Event.new(tick_count, "hit", {
			"attacker_id": actor_id,
			"target_id": target_id,
			"damage": damage,
			"damage_type": weapon.damage_type,
			"family": family,
			"position": knocked_position,
		}))
		if remaining_health <= 0.0:
			events.append(Event.new(tick_count, "died", {"actor_id": target_id}))

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
