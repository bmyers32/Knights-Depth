class_name FamilyLocomotionScenario
extends RefCounted
## ONE scenario builder, TWO named artifacts with one job each (P17 baseline split).
##
## WHY THIS EXISTS. `AiBaselineScenario` recorded Fang AND Ooze into a single fixture.
## P17 lawfully changes Fang's motion path, which makes that artifact's rows disagree about
## their own authority: Ooze rows would still gate, Fang rows would not. BRAIN's rule --
## "Never rewrite yesterday's baseline to describe today" -- forbids the tempting fix
## (re-record it) and forbids the sloppy one (retire it row-by-row). So the roles split:
##
##   1. tests/fixtures/ai_baseline_pre_p29.json  — FROZEN, byte-for-byte, EVIDENCE ONLY.
##      Gating authority formally retired; see tests/test_ai_backward_compat.gd.
##   2. tests/fixtures/ai_canary_ooze.json       — the ACTIVE gate on the shared
##      locomotion/decision path, carried by an explicitly UNAFFECTED family.
##   3. tests/fixtures/ai_baseline_p17_fang.json — the new governing baseline for Fang,
##      recorded only AFTER the approved P17 behaviour existed.
##
## Both live artifacts are produced by THIS class and compared by THIS class, because a
## baseline whose generator and comparator are two copies of "the same" code protects
## nothing (the lesson AiBaselineScenario itself records).
##
## NO ALLOW-LIST. Unlike the P29 baseline, neither live artifact tolerates additive keys:
## each was recorded against the behaviour it governs, so any difference at all is a
## regression requiring explanation. Re-record only for a deliberate, dated behaviour
## change -- and when that day comes, split again rather than overwrite.

const PLAYER_ID: int = 0
const ENEMY_ID: int = 1

const TICKS: int = 200
const DT: float = 1.0 / 30.0
const SEED: int = 20260818

## Straight down -Z from the player, far enough out that the whole approach is observed:
## outside Fang's 3.0 release hinge by a wide margin, inside its 10.0 detection radius.
const SPAWN: Vector3 = Vector3(0.0, 0.0, -8.0)


## Mirrors arena.gd's registration order, through the PRODUCTION path (ContentRegistrar),
## so "the real game's setup" has exactly one meaning. One enemy only: these artifacts
## isolate a single family's locomotion, which is what lets the Ooze canary stay a genuine
## no-change gate while Fang legitimately moves.
static func build(sim: SimWorld, family_key: StringName) -> void:
	sim.seed_combat_rng(SEED)

	var envoy_stats: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	sim.add_entity(PLAYER_ID, Vector3.ZERO, envoy_stats.move_speed)
	sim.register_combatant(PLAYER_ID, envoy_stats.max_health, envoy_stats.family, 0, envoy_stats.combat_radius, &"player")

	ContentRegistrar.register_enemy_body(sim, ENEMY_ID, family_key, SPAWN)
	ContentRegistrar.register_enemy_ai(sim, ENEMY_ID, family_key, SPAWN)

	var loadout: Array[StringName] = [&"sword_burn_A", &"wand_A"]
	for weapon_id in loadout:
		ContentRegistrar.register_weapon(sim, weapon_id)
	sim.set_weapon_loadout(PLAYER_ID, loadout)
	sim.set_equipped_weapon(PLAYER_ID, loadout[0])

	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)

	var flinch: FlinchTuning = ContentDB.get_resource(&"combat", &"flinch_tuning")
	sim.set_flinch_tuning(flinch.pressure_window_ticks, flinch.flinch_recovery_ticks)

	var burn: BurnStats = ContentDB.get_resource(&"status", &"burn")
	sim.register_status(burn.status_id, burn.damage_per_tick, burn.tick_interval_ticks, burn.duration_ticks)
	var priority_table: StatusPriorityTable = ContentDB.get_resource(&"status", &"priority_table")
	sim.set_status_priority(priority_table.priority)

	var shield: ShieldStats = ContentDB.get_resource(&"shield", &"default")
	sim.register_shield(PLAYER_ID, shield.meter_max, shield.regen_per_tick, shield.break_recovery_delay_ticks, shield.knockback_distance, shield.bump_padding, shield.bump_distance, shield.bump_slide_ticks, shield.bump_cooldown_ticks, shield.parry_window_ticks, shield.parry_exposure_ticks, shield.parry_damage_multiplier)


## A fixed function of tick -- no RNG, no reading sim state, so the command log is identical
## across runs by construction rather than by luck.
##
## The player deliberately STANDS STILL for the first 60 ticks. That is the whole point of
## these artifacts: the enemy's own approach path is the thing under test, and a moving
## player would fold the player's path into the record and mask a locomotion regression.
## After that the phases exercise the branches a locomotion edit could plausibly disturb --
## melee pressure into flinch, Burn proc, block, weapon switch, projectiles.
##
## Attack is appended BEFORE move on any tick carrying both -- the locked ordering envoy.gd
## uses.
static func commands_for_tick(tick: int) -> Array[Command]:
	var commands: Array[Command] = []
	if tick < 60:
		return commands  # observe the approach, unpolluted
	if tick < 130:
		if tick % 8 == 0:
			commands.append(Command.new(tick, PLAYER_ID, "attack", {"aim": Vector3(0.0, 0.0, -1.0), "phase": "pressed"}))
		elif tick % 8 == 3:
			commands.append(Command.new(tick, PLAYER_ID, "attack", {"aim": Vector3(0.0, 0.0, -1.0), "phase": "released"}))
	elif tick < 155:
		commands.append(Command.new(tick, PLAYER_ID, "block", {"held": true}))
	elif tick == 155:
		commands.append(Command.new(tick, PLAYER_ID, "switch_weapon", {}))
	else:
		if tick % 6 == 0:
			commands.append(Command.new(tick, PLAYER_ID, "attack", {"aim": Vector3(0.0, 0.0, -1.0)}))
		commands.append(Command.new(tick, PLAYER_ID, "move", {"direction": Vector3(0.4, 0.0, -1.0)}))
	return commands


static func run(family_key: StringName) -> Array:
	var sim := SimWorld.new()
	build(sim, family_key)
	var stream: Array = []
	for tick in TICKS:
		for event in sim.tick(commands_for_tick(tick), DT):
			stream.append(serialize(event))
	return stream


## Canonical, diff-friendly serialization: payload keys SORTED (insertion order must never
## become part of the contract) and floats fixed-width -- str() on a Vector3 truncates to a
## precision that would hide a real drift.
static func serialize(event: Event) -> String:
	var keys: Array = event.payload.keys()
	keys.sort()
	var parts: Array = []
	for key in keys:
		parts.append("%s=%s" % [key, _format_value(event.payload[key])])
	return "%d|%s|%s" % [event.tick, event.kind, ",".join(parts)]


static func _format_value(value: Variant) -> String:
	if value is Vector3:
		return "(%.6f,%.6f,%.6f)" % [value.x, value.y, value.z]
	if value is float:
		return "%.6f" % value
	return str(value)
