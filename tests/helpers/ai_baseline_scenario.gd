class_name AiBaselineScenario
extends RefCounted
## The P29 BACKWARD-COMPAT CONTRACT, in one shared location.
##
## P29 (enemy action repertoire) rewrites the AI's attack-eligibility gate — a change to
## a SHARED decision function's condition order, the exact shape BRAIN warns silently
## invalidates test setups rather than assertions. The protection is a recorded
## golden-behaviour baseline: this scenario, run through the PRODUCTION registration path
## (ContentRegistrar), captured before the change and re-run after it.
##
## THE CONTRACT (ruled): old and new streams are compared through a normalizer whose
## explicit additive-key allow-list is EXACTLY `attack_telegraph -> action_id`, and
## nothing else. After normalization the streams must be byte-identical. Decisions,
## timing, movement, attack resolution, damage, cooldowns and reactions therefore remain
## exactly unchanged. ANY ADDITIONAL DIFFERENCE IS A REGRESSION REQUIRING EXPLANATION,
## never another normalization exception.
##
## Scenario and serializer live HERE, not in the recorder and the test separately —
## a baseline whose generator and comparator are two copies of "the same" code protects
## nothing (BRAIN: "Convenience-zeroed defenses in tests hide the interactions worth
## testing", same root: production and tests reading content through two paths).

## Fang and Ooze only. Watcher is deliberately EXCLUDED: it is the one family P29
## intentionally changes (it gains watcher_survey), so including it would bake an
## expected-to-change actor into a no-change gate.
const PLAYER_ID: int = 0
const FANG_ID: int = 1
const OOZE_ID: int = 2

const TICKS: int = 200
const DT: float = 1.0 / 30.0
const SEED: int = 20260814

## The ONLY payload keys P29 is permitted to add, per event kind. Dropped before
## comparison so the pre-change recording stays valid. Adding an entry here is a
## deliberate contract amendment, never a way to make a red test pass.
const ADDITIVE_KEY_ALLOWLIST: Dictionary = {
	"attack_telegraph": ["action_id"],
}


## Mirrors arena.gd::_ready()'s registration order. Enemy content goes through
## ContentRegistrar (the one shared unpack); the remaining calls are the same flat
## ContentDB unpacks arena.gd performs, kept in the same order so the two cannot
## disagree about what "the real game's setup" means.
static func build(sim: SimWorld) -> void:
	sim.seed_combat_rng(SEED)

	var envoy_stats: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	sim.add_entity(PLAYER_ID, Vector3(0.0, 0.0, 0.0), envoy_stats.move_speed)
	sim.register_combatant(PLAYER_ID, envoy_stats.max_health, envoy_stats.family, 0, envoy_stats.combat_radius, &"player")

	ContentRegistrar.register_enemy_body(sim, FANG_ID, &"fang", Vector3(0.0, 0.0, -4.0))
	ContentRegistrar.register_enemy_ai(sim, FANG_ID, &"fang", Vector3(0.0, 0.0, -4.0))
	ContentRegistrar.register_enemy_body(sim, OOZE_ID, &"ooze", Vector3(2.5, 0.0, -4.0))
	ContentRegistrar.register_enemy_ai(sim, OOZE_ID, &"ooze", Vector3(2.5, 0.0, -4.0))

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


## A fixed function of tick — no RNG, no reading sim state, so the command log is
## identical across runs by construction rather than by luck. Phases chosen to exercise
## every branch the P29 edit could plausibly disturb, verified against the recorded
## stream's event mix rather than assumed: approach, engagement-band settle, enemy
## telegraph/windup/hit cadence, player combo taps landing REAL hits (so pressure ->
## flinch -> windup_interrupted and Burn proc/spread/expiry all occur), a death and its
## cleanup, blocking an incoming enemy hit, weapon switch, and gun projectiles.
##
## Attack is appended BEFORE move on any tick carrying both — the locked ordering
## envoy.gd uses, so a tap-release tick cannot blend free input with authored lunge
## movement (BRAIN: "A same-tick state transition needs 'did I cause it'").
static func commands_for_tick(tick: int) -> Array[Command]:
	var commands: Array[Command] = []
	# Envoy move_speed 4.0 at 30 Hz = 0.133/tick; 18 ticks closes ~2.4 units, settling
	# just inside sword reach of Fang at z=-4 without walking through it.
	if tick < 18:
		commands.append(Command.new(tick, PLAYER_ID, "move", {"direction": Vector3(0.0, 0.0, -1.0)}))
	elif tick < 120:
		# 8-tick tap cycle: press, release 3 ticks later (well under the 20-tick charge
		# threshold, so every cycle resolves as a combo step, not a charge).
		if tick % 8 == 0:
			commands.append(Command.new(tick, PLAYER_ID, "attack", {"aim": Vector3(0.0, 0.0, -1.0), "phase": "pressed"}))
		elif tick % 8 == 3:
			commands.append(Command.new(tick, PLAYER_ID, "attack", {"aim": Vector3(0.0, 0.0, -1.0), "phase": "released"}))
	elif tick < 150:
		commands.append(Command.new(tick, PLAYER_ID, "block", {"held": true}))
	elif tick == 150:
		commands.append(Command.new(tick, PLAYER_ID, "switch_weapon", {}))
	else:
		if tick % 6 == 0:
			commands.append(Command.new(tick, PLAYER_ID, "attack", {"aim": Vector3(0.0, 0.0, -1.0)}))
		commands.append(Command.new(tick, PLAYER_ID, "move", {"direction": Vector3(0.3, 0.0, -1.0)}))
	return commands


## Runs the scenario and returns the normalized event stream.
static func run(sim: SimWorld) -> Array:
	var stream: Array = []
	for tick in TICKS:
		var events: Array[Event] = sim.tick(commands_for_tick(tick), DT)
		for event in events:
			stream.append(serialize(event))
	return stream


## Canonical, diff-friendly serialization. Payload keys are SORTED (dictionary insertion
## order must never become part of the contract) and floats are fixed-width — str() on a
## Vector3 truncates to a precision that would hide a real drift.
static func serialize(event: Event) -> String:
	var dropped: Array = ADDITIVE_KEY_ALLOWLIST.get(event.kind, [])
	var keys: Array = event.payload.keys()
	keys.sort()
	var parts: Array = []
	for key in keys:
		if String(key) in dropped:
			continue
		parts.append("%s=%s" % [key, _format_value(event.payload[key])])
	return "%d|%s|%s" % [event.tick, event.kind, ",".join(parts)]


static func _format_value(value: Variant) -> String:
	if value is Vector3:
		return "(%.6f,%.6f,%.6f)" % [value.x, value.y, value.z]
	if value is float:
		return "%.6f" % value
	return str(value)
