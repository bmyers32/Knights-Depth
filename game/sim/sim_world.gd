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
## Manual-pass lunge-clamp addition: the ONE shared epsilon for "authoritative
## contact distance" (combined combat radii), used by BOTH Burn contact-spread
## (_actors_overlap) and the melee lunge clamp (_find_earliest_lunge_contact) via
## _contact_distance -- the two mechanics must never have independently tuned
## thresholds for the same physical contact concept. 0.0: Burn's existing formula
## has zero tolerance today (exact `<=`), so this preserves its tested behavior
## unchanged; no nonzero value is justified without evidence the exact-touching
## threshold itself is wrong, which is a separate calibration question from this
## change.
const _CONTACT_PADDING: float = 0.0

var entities: Dictionary = {}  # actor_id -> Vector3 position
var _move_speeds: Dictionary = {}  # actor_id -> float
var _facings: Dictionary = {}  # actor_id -> Vector3 (horizontal, normalized, never zero)
var _health: Dictionary = {}  # actor_id -> float (combatants only)
var _families: Dictionary = {}  # actor_id -> StringName (combatants only)
var _iframe_ticks_on_hit: Dictionary = {}  # actor_id -> int (combatants only)
var _iframe_ticks_remaining: Dictionary = {}  # actor_id -> int, counts down once per tick()
var _weapons: Dictionary = {}  # weapon_id(String) -> Dictionary of resolved weapon stats
var _equipped_weapon: Dictionary = {}  # actor_id -> weapon_id(String), sim-owned equip state
var _weapon_loadouts: Dictionary = {}  # actor_id -> Array[String], switch_weapon's fixed cycle order
var _next_fire_tick: Dictionary = {}  # actor_id -> int, tick_count before which "attack" is rejected
var _projectiles: Dictionary = {}  # projectile_id(int) -> Dictionary of in-flight shot state
var _next_projectile_id: int = 0
var _matrix_families: Dictionary = {}  # family(String) -> {"weak_to": String, "resists": String}
var _matrix_weak_multiplier: float = 1.0
var _matrix_resist_multiplier: float = 1.0
## Slice B (3-hit combo + hold-to-charge, GAME-RULES §3) — weapon_id(String) keyed,
## populated only by register_melee_profiles. A weapon_id present here routes
## _apply_attack to the phased press/held/released model (_apply_phased_melee_
## attack) instead of the original flat instant-resolve path; a weapon never
## registered this way (guns, sword_A, every enemy natural weapon) is completely
## unaffected -- these dicts simply stay empty for it.
var _melee_combo_profiles: Dictionary = {}  # weapon_id(String) -> Array[Dictionary] (resolved profiles, size 3)
var _melee_charge_profiles: Dictionary = {}  # weapon_id(String) -> Dictionary (resolved profile)
var _melee_charge_threshold_ticks: Dictionary = {}  # weapon_id(String) -> int
var _melee_combo_reset_ticks: Dictionary = {}  # weapon_id(String) -> int
var _melee_input_buffer_ticks: Dictionary = {}  # weapon_id(String) -> int
## actor_id -> a THREE-STATE pending-attack record (manual-pass lunge/windup,
## generalizing the original hold-only shape rather than adding a second dict --
## these states are temporally exclusive phases of one "this actor has an attack in
## progress" concept):
##   "charging" — {weapon_id, state, charge_ticks} — button down, pre-release,
##     unchanged from the original Slice B shape.
##   "windup"   — {weapon_id, state, profile, attack_profile_id, aim, windup_end_tick}
##     — charge-only (charge_profile.windup_ticks > 0), entered on a charged
##     release instead of resolving instantly. aim is locked at release and never
##     re-tracks. No end_tick yet -- not buffer-eligible (see _begin_melee_hold).
##   "executing" — {weapon_id, state, profile, attack_profile_id, aim,
##     execution_start_tick, hit_tick, end_tick, hit_resolved} — the swing is
##     actively resolving (lunge unfolding, hit pending/resolved, recovery
##     running). Entered directly from a combo-tap release, or from "windup" once
##     windup_end_tick arrives (entities[actor_id] is RESAMPLED at that transition
##     -- "origin moves" -- profile/attack_profile_id/aim carry over unchanged).
## Erased on natural completion (_advance_melee_execution_tick's end_tick branch),
## cancellation (_cancel_open_melee_hold: block rising-edge, enemy interrupt), or
## death/switch (_clear_attack_input_state) -- never left dangling.
var _melee_hold: Dictionary = {}
var _combo_index: Dictionary = {}  # actor_id -> int, 0 = next tap swing is hit 1
var _combo_expire_tick: Dictionary = {}  # actor_id -> int, a "pressed" after this tick starts a fresh sequence (index snapped to 0)
## actor_id -> {weapon_id: String, released: bool, release_aim: Vector3} -- present
## ONLY while a "pressed" that arrived during recovery is queued waiting for the
## cooldown to clear (manual-pass input buffer, GAME-RULES §3). released/release_aim
## capture an early release that arrived before the buffer materialized, so it can
## still resolve as a clean tap on the materialization tick instead of a stuck hold
## (see _advance_buffered_attacks). Erased alongside _melee_hold everywhere that
## clears it (_clear_attack_input_state, block's rising-edge cancel).
var _melee_buffered_press: Dictionary = {}
var _shields: Dictionary = {}  # actor_id -> Dictionary of resolved shield stats
var _shield_state: Dictionary = {}  # actor_id -> "ready" | "held" | "broken"
var _shield_meter: Dictionary = {}  # actor_id -> float
var _shield_break_ticks_remaining: Dictionary = {}  # actor_id -> int
var _block_held_prev: Dictionary = {}  # actor_id -> bool, previous tick's held input (edge detection)
var _block_start_tick: Dictionary = {}  # actor_id -> int, tick of the last ready->held transition
## P16 shield bump: actor_id -> int, ABSOLUTE tick before which a rising edge raises
## the shield normally but performs no bump. Only the bump is gated -- blocking itself
## is never suppressed by this.
var _shield_bump_ready_tick: Dictionary = {}
## P16 BUMP slide: actor_id -> {direction, step_distance, end_tick}. A short AUTHORED
## SLIDE, deliberately not KNOCKBACK (LEXICON: knockback is an immediate impulse; bump
## is a controlled shove that resolves over several ticks so it reads as "get off me"
## rather than "heavy hit").
## Deliberately NOT stored in _melee_hold: that record's lifecycle is welded to attack
## resolution -- completing one arms _next_fire_tick, resolves a hit, and advances combo
## state. Driving a bumped enemy through it would rewrite that enemy's own attack
## cooldown and desynchronise its committed windup, violating GAME-RULES §3's
## non-flinching-displacement law. This record touches no attack state at all, so the
## windup continues on its original timeline by construction rather than by care.
var _bump_slides: Dictionary = {}
## P16 PARRY EXPOSED (LEXICON): actor_id -> absolute tick / multiplier. A temporary
## INCOMING-DAMAGE multiplier on an attacker that a defender perfect-parried.
## Deliberately NOT named "vulnerable": VULNERABLE already means an enemy action's
## FLINCH susceptibility, and these must never be conflated -- PARRY EXPOSED is damage
## only and confers no EXPLOIT susceptibility. Not a status instance either (it never
## touches the single-slot/spread architecture).
## REFRESH, never stack: one record per actor; a new parry overwrites the deadline with
## a fresh full window and re-sets (never compounds) the multiplier.
var _parry_exposed_until_tick: Dictionary = {}
var _parry_exposed_damage_multiplier: Dictionary = {}
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
## Enemy AI (Phase D step 8 Phase 4) — deterministic, no RNG (a future variance need
## gets its OWN GAME-RULES §1.3 stream, never combat's). AI only ever decides
## move_direction/attack-intent by synthesizing the same Command shapes a player
## would send; it never bypasses _apply_move/_apply_attack.
var _ai_natural_weapon: Dictionary = {}  # actor_id -> weapon_id(String)
## actor_id -> Vector3, the leash/detection anchor. Scene-init/encounter-reset data
## only in the sense that register_ai unconditionally overwrites it on
## re-registration — at runtime it RE-ANCHORS to the stopped position on disengage
## (locked behavior, pre-gate fix pass: no universal return-to-spawn).
var _ai_spawn_position: Dictionary = {}
var _ai_state: Dictionary = {}  # actor_id -> "idle" | "active"
var _ai_tuning: Dictionary = {}  # actor_id -> {preferred_attack_distance, minimum_attack_distance, windup_ticks, detection_radius, leash_radius}
var _ai_attack_start_tick: Dictionary = {}  # actor_id -> int, present only while winding up
var _ai_attack_fire_tick: Dictionary = {}  # actor_id -> int, present only while winding up
## FLINCH reaction layer (batch, GAME-RULES §3). FLINCHED is an actor/AI REACTION
## STATE, deliberately NOT a status instance -- it must never use the single-slot
## status/spread architecture (three-axis law, §6.8: statuses are a combat method,
## reactions are what a body does).
## actor_id -> int, an ABSOLUTE tick deadline (same convention as _next_fire_tick /
## _combo_expire_tick, never a per-tick countdown). Absolute is what makes §3's
## "effective denial is max(recovery, cooldown), never the sum" fall out for free:
## both deadlines run concurrently in the same tick space.
var _flinched_until_tick: Dictionary = {}
## actor_id -> Array of {damage: float, expiry_tick: int}. A ROLLING per-contribution
## queue, never a refreshed timer -- late damage must not revive early damage. Pruned
## LAZILY at record/read time; there is deliberately no per-tick scan (§3: pressure is
## stored opportunity, and flinch is evaluated ONLY inside hit resolution).
## Contributions are recorded FACTS: never recomputed from HP, so healing can't erase
## them. No attacker attribution in M1 -- no shares, no assists (ROADMAP P27).
var _pressure_contributions: Dictionary = {}
var _flinch_thresholds: Dictionary = {}  # actor_id -> float; presence = "this actor can flinch"
## weapon_id(String) -> {mode: String, vulnerable_start: int, vulnerable_end: int},
## resolved from NaturalWeaponStats. Read against _ai_attack_start_tick to derive the
## target's CURRENT action mode -- no new state, the windup start tick already exists.
var _action_susceptibility: Dictionary = {}
var _pressure_window_ticks: int = 0
var _flinch_recovery_ticks: int = 0
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
	_weapons[String(weapon_id)] = _resolve_melee_profile(damage, String(damage_type), reach, cone_half_angle_degrees, knockback_distance, fire_interval_ticks, String(status_id), status_proc_chance)


## Shared by register_weapon and register_melee_profiles (rule of two: both build the
## exact same resolved-profile shape from plain scalars) -- the one place the
## cone_half_angle_degrees -> cone_threshold conversion happens. Also the one place
## the hit_active_ticks <= lunge_duration_ticks profile invariant is linted (manual-
## pass, GAME-RULES §3 damage-matrix-lint precedent): a hit whose offset lands past
## its own swing's end_tick would otherwise silently never resolve (the end_tick
## branch erases the record before a later hit_tick could fire) -- clamped and
## warned, never silently lost. debug_label is cosmetic (warning message only).
func _resolve_melee_profile(damage: float, damage_type: String, reach: float, cone_half_angle_degrees: float, knockback_distance: float, fire_interval_ticks: int, status_id: String, status_proc_chance: float, interrupt_strength: int = 0, lunge_distance: float = 0.0, lunge_duration_ticks: int = 0, hit_active_ticks: int = 0, windup_ticks: int = 0, debug_label: String = "", flinch_capability: String = "none", contributes_pressure: bool = true) -> Dictionary:
	var resolved_hit_active_ticks: int = hit_active_ticks
	if resolved_hit_active_ticks > lunge_duration_ticks:
		var label_suffix: String = (" [%s]" % debug_label) if debug_label != "" else ""
		push_warning("MeleeAttackProfile%s: hit_active_ticks (%d) > lunge_duration_ticks (%d) -- clamped" % [label_suffix, hit_active_ticks, lunge_duration_ticks])
		resolved_hit_active_ticks = lunge_duration_ticks
	return {
		"resolution": "melee",
		"damage": damage,
		"damage_type": damage_type,
		"reach": reach,
		"cone_threshold": cos(deg_to_rad(cone_half_angle_degrees)),
		"knockback_distance": knockback_distance,
		"fire_interval_ticks": fire_interval_ticks,
		"status_id": status_id,
		"status_proc_chance": status_proc_chance,
		"interrupt_strength": interrupt_strength,
		"lunge_distance": lunge_distance,
		"lunge_duration_ticks": lunge_duration_ticks,
		"hit_active_ticks": resolved_hit_active_ticks,
		"windup_ticks": windup_ticks,
		"flinch_capability": _lint_flinch_capability(flinch_capability, debug_label),
		"contributes_pressure": contributes_pressure,
	}


## Registration-time lint (mirrors the hit_active_ticks clamp above): an unknown enum
## value is content that would otherwise fail SILENTLY as "never flinches." Rejected to
## the safe default and warned, never silently accepted. Deliberately does NOT infer
## validity from damage/knockback/status -- a zero-damage pressure cash-out profile is
## schema-legal; whether it is GOOD content is a separate design question.
func _lint_flinch_capability(capability: String, debug_label: String) -> String:
	if capability in ["none", "exploit", "pressure"]:
		return capability
	var label_suffix: String = (" [%s]" % debug_label) if debug_label != "" else ""
	push_warning("flinch_capability%s: unknown value '%s' -- expected none/exploit/pressure, defaulting to none" % [label_suffix, capability])
	return "none"


## Registers a combo/charge-capable melee weapon (GAME-RULES §3 Slice B) -- the
## alternative to register_weapon for a weapon whose content (SwordStats.
## combo_profiles) is non-empty. weapon_id stays the real equip identity, never a
## composite id -- combo/charge profiles live in SimWorld's own tables keyed by it,
## exactly like set_damage_matrix keys off family names rather than embedding a
## DamageMatrix Resource in sim/. combo_profiles/charge_profile are plain resolved
## Dictionaries (the driver unpacks each MeleeAttackProfile Resource before calling
## this -- Resources never cross into sim/, see class doc). Presence of weapon_id in
## _melee_combo_profiles after this call is what routes _apply_attack to the phased
## model; register_weapon's flat path is completely untouched for every other
## weapon.
func register_melee_profiles(weapon_id: StringName, combo_profiles: Array[Dictionary], charge_profile: Dictionary, charge_threshold_ticks: int, combo_reset_ticks: int, input_buffer_ticks: int = 0) -> void:
	var key: String = String(weapon_id)
	var resolved_combo: Array = []
	for i in combo_profiles.size():
		var profile: Dictionary = combo_profiles[i]
		resolved_combo.append(_resolve_melee_profile(profile.damage, String(profile.damage_type), profile.reach, profile.cone_half_angle_degrees, profile.knockback_distance, profile.fire_interval_ticks, String(profile.status_id), profile.status_proc_chance, int(profile.get("interrupt_strength", 0)), float(profile.get("lunge_distance", 0.0)), int(profile.get("lunge_duration_ticks", 0)), int(profile.get("hit_active_ticks", 0)), int(profile.get("windup_ticks", 0)), "%s combo hit %d" % [key, i + 1], String(profile.get("flinch_capability", "none")), bool(profile.get("contributes_pressure", true))))
	_melee_combo_profiles[key] = resolved_combo
	_melee_charge_profiles[key] = _resolve_melee_profile(charge_profile.damage, String(charge_profile.damage_type), charge_profile.reach, charge_profile.cone_half_angle_degrees, charge_profile.knockback_distance, charge_profile.fire_interval_ticks, String(charge_profile.status_id), charge_profile.status_proc_chance, int(charge_profile.get("interrupt_strength", 0)), float(charge_profile.get("lunge_distance", 0.0)), int(charge_profile.get("lunge_duration_ticks", 0)), int(charge_profile.get("hit_active_ticks", 0)), int(charge_profile.get("windup_ticks", 0)), "%s charge" % key, String(charge_profile.get("flinch_capability", "none")), bool(charge_profile.get("contributes_pressure", true)))
	_melee_charge_threshold_ticks[key] = charge_threshold_ticks
	_melee_combo_reset_ticks[key] = combo_reset_ticks
	_melee_input_buffer_ticks[key] = input_buffer_ticks


## Registers a ranged weapon (GAME-RULES §3: "projectile with travel time") — same
## _weapons table as register_weapon, tagged for deferred resolution instead of an
## instant multi-target sweep. speed is continuous (units/second, mirrors movement's
## convention); max_lifetime_ticks is a sim-tick count (§3: durations in sim ticks,
## never seconds in code) so an unfired shot always despawns deterministically.
## status_id/status_proc_chance: see register_weapon.
func register_gun(weapon_id: StringName, damage: float, damage_type: StringName, speed: float, max_lifetime_ticks: int, hit_radius: float, knockback_distance: float, fire_interval_ticks: int = 0, status_id: StringName = &"", status_proc_chance: float = 0.0, flinch_capability: String = "none", contributes_pressure: bool = true) -> void:
	_weapons[String(weapon_id)] = {
		"resolution": "projectile",
		"flinch_capability": _lint_flinch_capability(flinch_capability, String(weapon_id)),
		"contributes_pressure": contributes_pressure,
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


## Registers actor_id's fixed weapon-switch order (Phase D step 8) — setup-time
## configuration, called once from the scene driver, same boundary as every other
## register_*/set_* call: initialization/configuration goes through a direct call,
## player intent during gameplay goes through a Command, simulation outcomes come
## back as Events. "switch_weapon" (below) only ever advances through THIS array —
## it carries no weapon_id of its own (Command.params stays per-tick intent only,
## never an id), so it can't equip anything outside the loadout set up here.
func set_weapon_loadout(actor_id: int, weapon_ids: Array[StringName]) -> void:
	var ids: Array[String] = []
	for weapon_id in weapon_ids:
		ids.append(String(weapon_id))
	_weapon_loadouts[actor_id] = ids


## Installs the shared flinch clocks (FlinchTuning resource) — same driver-unpacks-a
## resource boundary as set_damage_matrix. Shared deliberately: per-enemy variation is
## expressed by flinch_threshold (register_flinch_profile), never by private clocks.
func set_flinch_tuning(pressure_window_ticks: int, flinch_recovery_ticks: int) -> void:
	_pressure_window_ticks = pressure_window_ticks
	_flinch_recovery_ticks = flinch_recovery_ticks


## Marks actor_id as FLINCHABLE and sets how much recent post-mitigation HP damage a
## pressure-capable hit must find to cash out. An actor with no profile registered can
## never flinch and accumulates no pressure — that is how the Envoy stays out of the
## reaction layer in M1 (player-side reactions are ROADMAP P23/P24, not this batch).
func register_flinch_profile(actor_id: int, flinch_threshold: float) -> void:
	_flinch_thresholds[actor_id] = flinch_threshold


## Authored per-ACTION susceptibility for a natural weapon's windup (see
## NaturalWeaponStats). mode applies outside [vulnerable_start, vulnerable_end]; the
## interval overrides to VULNERABLE. Offsets are from windup START, inclusive.
func register_action_susceptibility(weapon_id: StringName, mode: StringName, vulnerable_start_tick: int, vulnerable_end_tick: int) -> void:
	_action_susceptibility[String(weapon_id)] = {
		"mode": String(mode),
		"vulnerable_start": vulnerable_start_tick,
		"vulnerable_end": vulnerable_end_tick,
	}


## Installs the family x damage-type matrix (GAME-RULES §3) — one resource, resolved
## by the driver from ContentDB, unpacked here as plain data.
func set_damage_matrix(families: Dictionary, weak_multiplier: float, resist_multiplier: float) -> void:
	_matrix_families = families
	_matrix_weak_multiplier = weak_multiplier
	_matrix_resist_multiplier = resist_multiplier


## Registers actor_id as a shield-capable blocker (GAME-RULES §3) — starts in the
## "ready" state with a full meter. Only entities with a registered shield process
## "block" Commands; unregistered actors silently ignore them (_apply_block).
func register_shield(actor_id: int, meter_max: float, regen_per_tick: float, break_recovery_delay_ticks: int, knockback_distance: float, bump_padding: float = 0.0, bump_distance: float = 0.0, bump_slide_ticks: int = 1, bump_cooldown_ticks: int = 0, parry_window_ticks: int = 0, parry_exposure_ticks: int = 0, parry_damage_multiplier: float = 1.0) -> void:
	_shields[actor_id] = {
		"meter_max": meter_max,
		"regen_per_tick": regen_per_tick,
		"break_recovery_delay_ticks": break_recovery_delay_ticks,
		"knockback_distance": knockback_distance,
		# P16 (all default to inert, so every pre-P16 caller keeps byte-identical
		# behavior: a 0 bump_distance displaces nothing and a 0
		# parry_window_ticks can never contain a hit).
		"bump_padding": bump_padding,
		"bump_distance": bump_distance,
		"bump_slide_ticks": bump_slide_ticks,
		"bump_cooldown_ticks": bump_cooldown_ticks,
		"parry_window_ticks": parry_window_ticks,
		"parry_exposure_ticks": parry_exposure_ticks,
		"parry_damage_multiplier": parry_damage_multiplier,
	}
	_shield_state[actor_id] = "ready"
	_shield_meter[actor_id] = meter_max


## Registers actor_id as AI-controlled (Phase D step 8 Phase 4) — setup-time
## configuration, same boundary as every other register_*/set_* call (see
## set_weapon_loadout's comment). natural_weapon_id must already be registered via
## register_weapon (its reach == preferred_attack_distance, so a settle-in-band enemy
## can always actually land the attack it fires — content's job to keep those
## consistent, not sim's to enforce); this call also equips it (mirrors
## set_equipped_weapon's existing pattern — an enemy only ever has the one natural
## attack). spawn_position anchors the leash (leash_radius is measured from here,
## never the actor's drifting current position — though disengage re-anchors this
## to wherever the actor stopped, see the leash-exceeded branch below). Starts
## "idle" — no initial aggro;
## detection_radius (read from _ai_tuning at decide-time) gates first acquisition
## exactly like re-acquisition. preferred_attack_distance/minimum_attack_distance
## (engagement-spacing fix) bound the band an engaged enemy tries to hold: farther
## than preferred -> approach, closer than minimum -> back away, inside the band ->
## stop and attack.
func register_ai(actor_id: int, natural_weapon_id: StringName, spawn_position: Vector3, preferred_attack_distance: float, minimum_attack_distance: float, windup_ticks: int, detection_radius: float, leash_radius: float) -> void:
	_ai_natural_weapon[actor_id] = String(natural_weapon_id)
	_ai_spawn_position[actor_id] = spawn_position
	_ai_state[actor_id] = "idle"
	_ai_tuning[actor_id] = {
		"preferred_attack_distance": preferred_attack_distance,
		"minimum_attack_distance": minimum_attack_distance,
		"windup_ticks": windup_ticks,
		"detection_radius": detection_radius,
		"leash_radius": leash_radius,
	}
	set_equipped_weapon(actor_id, natural_weapon_id)


## Debug-only, setup-time direct write (arena.gd's debug_force_aggro) -- called ONCE
## from _ready(), never during ticking. Skips authentic detection_radius gating for
## manual diagnostic testing; the real gameplay driver never calls this
## (debug_force_aggro defaults false). Must be called AFTER register_ai for this
## actor (which unconditionally sets "idle" internally) -- this exists so the one
## place that ever mutates _ai_state stays inside SimWorld even for a debug hook,
## instead of arena.gd reaching into the dict directly.
func debug_set_ai_active(actor_id: int) -> void:
	_ai_state[actor_id] = "active"


## Debug-only, setup-time health override (arena.gd's debug_validation_target_health)
## -- the DEV VALIDATION TARGET: a body that survives multiple full combos so flinch
## MECHANICS can be exercised independently of shipped enemy tuning. Called once from
## _ready(), never during ticking, and never by the real driver (default 0.0 = off).
## Exists so the driver never writes _health directly (same precedent as
## debug_set_ai_active): a debug hook is still a mutation, and mutations live here.
func debug_override_health(actor_id: int, health: float) -> void:
	_health[actor_id] = health


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
	# Input buffer (manual-pass, GAME-RULES §3): resolve any press that queued during
	# a prior tick's cooldown BEFORE this tick's Commands process, so if this same
	# tick also carries this actor's "held"/"released" Command, it lands against the
	# freshly-opened hold correctly rather than a tick late.
	events.append_array(_advance_buffered_attacks())
	# Pending melee attacks (manual-pass lunge/windup) advance here -- after the
	# buffer (so a press materialized above can still be picked up as "executing"
	# this same tick), before AI decisions/Commands (so a hit whose hit_tick is THIS
	# tick resolves, and any resulting combo bookkeeping happens, before this same
	# tick's block Command could process -- the ordering that makes the shield-
	# cancel timing rule explicit-by-construction rather than incidental Command-
	# array order; see _advance_melee_execution_tick).
	events.append_array(_advance_pending_attacks())
	# BUMP slides advance alongside pending attacks and BEFORE AI decisions, so a
	# sliding actor's own move Command (issued below) is suppressed this same tick, and
	# so the AI re-evaluates fresh geometry the tick after the slide completes.
	_advance_bump_slides()
	# AI (Phase D step 8 Phase 4) decides enemy Commands here, right before dispatch,
	# so its output (move/attack) feeds through the exact same handlers below a
	# player's own Commands would — no separate resolution path. It also appends any
	# "attack_telegraph" Events directly into this tick's events (a side effect of the
	# DECISION itself, not of a Command being applied, so it can't be an
	# _apply_*-returned Event like everything else here).
	var all_commands: Array[Command] = commands + _decide_ai_commands(events)
	for command in all_commands:
		if command.kind == "move":
			# Movement suppression during "executing" (manual-pass, locked):
			# authored lunge movement REPLACES input by design -- the lunge is
			# content, never an input-plus-lunge vector blend. This is what lets
			# weapon lines own their movement identity as pure content. "windup"
			# and "charging" are unaffected (free movement, explicit locked rule).
			if _melee_hold.get(command.actor_id, {}).get("state", "") == "executing":
				continue
			# An actor mid-BUMP-slide does not steer: authored displacement replaces
			# locomotion for its duration, the same rule the lunge follows. This
			# suppresses MOVEMENT ONLY -- the actor's attack timeline is untouched.
			if _bump_slides.has(command.actor_id):
				continue
			events.append(_apply_move(command, dt))
		elif command.kind == "attack":
			events.append_array(_apply_attack(command))
		elif command.kind == "block":
			events.append_array(_apply_block(command))
		elif command.kind == "switch_weapon":
			events.append_array(_apply_switch_weapon(command))
	# Contact spread reads this tick's post-attack status state (so a hit-applied
	# status this same tick is visible as a snapshot candidate, but its one-tick grace
	# keeps it from actually transmitting until a later tick); status ticking then
	# resolves DoT/duration for anyone due. Both run after Commands, before tick_count
	# advances, per the locked Burn contact-episode design.
	events.append_array(_advance_contact_spread())
	events.append_array(_advance_status_ticks())
	# tick_count advances LAST, so any read of it after tick() returns describes the sim
	# AFTER advancement -- one tick later than the Events produced during this call.
	# Event.tick is the authoritative occurrence timestamp; assert timing against that,
	# never against tick_count sampled by the caller afterwards (BRAIN).
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


## Ally-filtering (locked defect fix, pre-gate pass): same-allegiance actors are
## never valid attack targets — checked FIRST, at candidacy time, so an allied
## contact produces no damage, knockback, defenses, status proc/RNG draw, or Events
## at all (not a null-outcome event; it's simply never a candidate). Applied
## identically to melee's target scan and a projectile's swept-hit candidates —
## enemy-vs-enemy and (forward to M3 co-op) player-vs-player are the same case,
## generalized from allegiance alone, no special-casing per pair. Burn's own
## contact-spread eligibility is unrelated and untouched (its player<->player
## rejection lives in _advance_contact_spread, per its own locked rules).
func _is_valid_target(attacker_id: int, target_id: int) -> bool:
	if target_id == attacker_id:
		return false
	if _health.get(target_id, 0.0) <= 0.0:
		return false
	return _allegiance.get(target_id, &"enemy") != _allegiance.get(attacker_id, &"enemy")


## Combat pipeline order (GAME-RULES §3 / CLAUDE.md Core Interfaces, fixed): validate
## -> hit detect -> damage-type matrix -> status -> knockback -> death/events. The
## 3-hit combo and hold-to-charge (Slice B, GAME-RULES §3) sequence through this
## exact pipeline too — see _apply_phased_melee_attack, which resolves into the same
## _resolve_melee_swing/_resolve_hit_on_target tail as this function's flat path,
## never a second path. The equipped weapon (set_equipped_weapon) decides
## resolution: melee sweeps all qualifying targets instantly; a gun spawns a
## projectile and resolves later (_advance_projectiles) — both funnel into the same
## _resolve_hit_on_target tail.
func _apply_attack(command: Command) -> Array[Event]:
	var actor_id: int = command.actor_id
	if _health.get(actor_id, 1.0) <= 0.0:
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "attacker_dead"})]

	var weapon_id: String = _equipped_weapon.get(actor_id, "")
	var is_phased_melee: bool = _melee_combo_profiles.has(weapon_id)
	if not is_phased_melee and not _weapons.has(weapon_id):
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "invalid_weapon"})]

	# phase defaults to "pressed" -- every pre-Slice-B Command (every existing test,
	# every gun/enemy attack) carries no phase key at all and falls straight through
	# to the untouched instant-resolve path below, byte-for-byte (backward-compat
	# contract, locked spec).
	var phase: String = String(command.params.get("phase", "pressed"))
	if is_phased_melee:
		return _apply_phased_melee_attack(actor_id, weapon_id, phase, command)
	if phase != "pressed":
		return []  # held/released are meaningless for a weapon with no charge profile registered

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

	return _resolve_melee_swing(actor_id, attacker_position, resolved_aim, weapon, weapon_id, "")


## Slice B phased attack model (GAME-RULES §3: 3-hit combo + hold-to-charge) — the
## resolution path for any weapon registered via register_melee_profiles. Continuum
## model (locked spec): charge is how long you hold the same attack, not a separate
## mode. A single press -> [held...] -> released cycle always resolves to exactly
## ONE swing: the current combo step if released before charge_threshold_ticks, the
## charge_profile instead if released at/after it. Dead-actor rejection already
## happened in _apply_attack above, uniformly for all three phases.
func _apply_phased_melee_attack(actor_id: int, weapon_id: String, phase: String, command: Command) -> Array[Event]:
	match phase:
		"pressed":
			return _begin_melee_hold(actor_id, weapon_id)
		"held":
			var hold: Dictionary = _melee_hold.get(actor_id, {})
			# "held" only means anything while still "charging" -- a windup/
			# executing record has no charge_ticks field at all (shouldn't be
			# reachable via envoy.gd's own edge-detected input, since "released"
			# only ever fires on a genuine button-up, but guarded defensively
			# rather than assumed).
			if hold.get("weapon_id", "") == weapon_id and hold.get("state", "") == "charging":
				var threshold: int = _melee_charge_threshold_ticks.get(weapon_id, 0)
				var was_ready: bool = int(hold.charge_ticks) >= threshold
				hold.charge_ticks = min(int(hold.charge_ticks) + 1, threshold)  # saturates -- holding past threshold never charges further
				var is_ready: bool = int(hold.charge_ticks) >= threshold
				# charge_ready fires exactly once, on the false->true saturation edge
				# (manual-pass cue, GAME-RULES §3) -- a pure state-transition signal,
				# never repeated on subsequent held ticks. Presentation listens for
				# this to turn a persistent tint ON; it never polls charge_ticks/
				# threshold itself (see SwordStats.charge_ready_tint_color's comment).
				if is_ready and not was_ready:
					return [Event.new(tick_count, "charge_ready", {"actor_id": actor_id, "weapon_id": weapon_id})]
			return []
		"released":
			# Post-implementation review catch: checking the AMBIENT post-call state
			# below (without first confirming THIS call is what produced it) double-
			# processes an unrelated, already-open "executing" record -- reachable
			# when a mid-swing buffered press's own "released" arrives while the
			# original swing is still executing: _release_melee_hold takes its
			# early-return branch (stashes buffered.released, touches nothing in
			# _melee_hold), yet the original swing's state still reads "executing"
			# afterward, triggering a spurious second _advance_melee_execution_tick
			# call this same tick (double-applies that tick's lunge step). Gating on
			# was_charging ensures the synchronous catch-up only fires when THIS
			# call is what transitioned charging -> executing.
			var was_charging: bool = _melee_hold.get(actor_id, {}).get("state", "") == "charging"
			var events: Array[Event] = _release_melee_hold(actor_id, weapon_id, command)
			# Backward-compat/off-by-one fix (manual-pass): a record opened just now
			# by this Command needs ONE synchronous execution-tick call, since
			# _advance_pending_attacks already ran earlier this same tick() call and
			# won't see this brand-new record until the NEXT tick otherwise -- every
			# existing all-zero-field weapon would resolve its hit one tick late.
			if was_charging and _melee_hold.get(actor_id, {}).get("state", "") == "executing":
				events.append_array(_advance_melee_execution_tick(actor_id))
			return events
		_:
			return []


## Slice B interruption rule (locked): death and a weapon switch both clear ALL
## attack-input state (hold + combo index + inactivity timer) -- see both death
## sites above and _apply_switch_weapon. A block rising-edge is the one interruption
## that does NOT call this: it only cancels the in-progress hold, deliberately
## leaving combo_index/expire untouched (locked rule -- block-canceling an
## unreleased hold doesn't consume/complete a step, so prior progress survives).
## Returns a "melee_hold_canceled" Event iff a hold was actually open (manual-pass
## cue: presentation listens for this to clear a persistent charge-ready tint --
## checked BEFORE erasing, never emitted for a no-op cancel of nothing).
func _clear_attack_input_state(actor_id: int) -> Array[Event]:
	var events: Array[Event] = []
	if _melee_hold.has(actor_id):
		events.append(Event.new(tick_count, "melee_hold_canceled", {"actor_id": actor_id, "weapon_id": String(_melee_hold[actor_id].weapon_id)}))
	_melee_hold.erase(actor_id)
	_combo_index.erase(actor_id)
	_combo_expire_tick.erase(actor_id)
	_melee_buffered_press.erase(actor_id)
	return events


## Lunge-clamp death/despawn clearing (manual-pass, locked ordering): "a dead or
## removed actor cannot block authored movement." Called from BOTH death sites
## (a lethal hit and a lethal status tick), same tick as the death itself -- since
## this always runs AFTER that tick's own movement phase already completed (see
## _advance_melee_execution_tick's call order), the dying tick's forfeited movement
## is never retroactively applied; whoever was clamped to dead_actor_id simply does
## a fresh sweep starting the very next tick. Scans every open _melee_hold rather
## than tracking a reverse index -- this sim has a handful of actors, a linear scan
## per death is free, and a reverse index would be another parallel dict to keep in
## sync for no measurable benefit.
## Reaction records die WITH the actor (§3) — pressure is stored opportunity against a
## living body, never a ledger that outlives it or transfers to a respawn.
func _clear_reaction_state(actor_id: int) -> void:
	_flinched_until_tick.erase(actor_id)
	_pressure_contributions.erase(actor_id)
	# PARRY EXPOSED dies with the actor too -- it is a temporary state on a living
	# body, never a ledger that outlives it.
	_parry_exposed_until_tick.erase(actor_id)
	_parry_exposed_damage_multiplier.erase(actor_id)
	_bump_slides.erase(actor_id)


func _clear_clamps_targeting(dead_actor_id: int) -> void:
	for actor_id in _melee_hold.keys():
		var hold: Dictionary = _melee_hold[actor_id]
		if int(hold.get("clamped_target_id", -1)) == dead_actor_id:
			hold.erase("clamped_target_id")


## Input buffer (manual-pass, GAME-RULES §3): materializes any buffered press whose
## cooldown has now elapsed into a real _melee_hold, exactly as a fresh "pressed"
## would -- reusing _begin_melee_hold rather than duplicating its logic. A release
## that arrived early (buffered.released, set by _release_melee_hold's no-open-hold
## branch) resolves immediately in the same tick via a synthesized Command, so a
## press that was tapped-and-released before it ever materialized still becomes one
## clean swing, never a stuck open hold. Autonomous-phase law (see tick()'s class
## comment): actor_ids sorted before any mutation, since dictionary iteration order
## must never leak into event order.
func _advance_buffered_attacks() -> Array[Event]:
	var events: Array[Event] = []
	var actor_ids: Array = _melee_buffered_press.keys()
	actor_ids.sort()
	for actor_id in actor_ids:
		var buffered: Dictionary = _melee_buffered_press[actor_id]
		if tick_count < _next_fire_tick.get(actor_id, 0):
			continue  # still not ready -- keep waiting
		_melee_buffered_press.erase(actor_id)
		var weapon_id: String = buffered.weapon_id
		events.append_array(_begin_melee_hold(actor_id, weapon_id))
		if buffered.released:
			events.append_array(_release_melee_hold(actor_id, weapon_id, Command.new(tick_count, actor_id, "attack", {"aim": buffered.release_aim})))
	return events


## Buffer eligibility (manual-pass, GAME-RULES §3) -- shared by both deadline
## sources in _begin_melee_hold below (rule of two). Hard fence: at most one queued
## press per actor -- a press arriving while one is already queued is rejected
## buffer_full and never modifies the existing entry's aim/release state, regardless
## of which deadline source it came from.
func _try_buffer_press(actor_id: int, weapon_id: String, deadline_tick: int, rejection_reason: String) -> Array[Event]:
	if _melee_buffered_press.has(actor_id):
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "buffer_full"})]
	var remaining: int = deadline_tick - tick_count
	var buffer_window: int = _melee_input_buffer_ticks.get(weapon_id, 0)
	if remaining <= buffer_window:
		_melee_buffered_press[actor_id] = {"weapon_id": weapon_id, "released": false, "release_aim": Vector3.ZERO}
		return []
	return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": rejection_reason})]


func _begin_melee_hold(actor_id: int, weapon_id: String) -> Array[Event]:
	if _melee_hold.has(actor_id):
		var hold: Dictionary = _melee_hold[actor_id]
		if hold.get("state", "") == "charging":
			# A "pressed" while already charging shouldn't happen with correctly
			# edge-detected input (envoy.gd only sends one rising edge per press) --
			# defensive no-op, not a player action worth an Event.
			return []
		if hold.get("state", "") == "windup":
			# No end_tick exists yet to compute a buffering deadline against -- a
			# scope cut for M1, not a technical wall (a projected end_tick IS
			# computable as windup_end_tick + charge_profile.lunge_duration_ticks;
			# deferred to avoid another branch in an already-complex state machine --
			# revisit if the manual re-pass finds mid-windup taps feel bad). Always
			# rejected, never buffered.
			return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "mid_swing"})]
		# "executing" -- buffer-eligible against the swing's own end_tick (input
		# buffer extended to cover mid-swing presses, manual-pass: dropping these
		# would reintroduce the exact combo dead-zone the cooldown buffer already
		# fixed, now reachable for the first time since swings span multiple ticks).
		return _try_buffer_press(actor_id, weapon_id, int(hold.end_tick), "mid_swing")
	if tick_count < _next_fire_tick.get(actor_id, 0):
		# Input buffer (manual-pass fix, GAME-RULES §3): a press landing close enough
		# to the cooldown's end is QUEUED instead of dropped -- diagnosed as the
		# likely dominant cause of "mush" (a slightly-early click reading as nothing
		# happening at all). input_buffer_ticks=0 (default) makes "remaining <=
		# buffer_window" never true while genuinely on cooldown, so this is a true
		# no-op for every weapon that doesn't opt in -- byte-identical rejection.
		return _try_buffer_press(actor_id, weapon_id, _next_fire_tick.get(actor_id, 0), "on_cooldown")
	if tick_count > _combo_expire_tick.get(actor_id, -1):
		_combo_index[actor_id] = 0  # inactivity window elapsed -- next swing starts a fresh sequence
	_melee_hold[actor_id] = {"weapon_id": weapon_id, "state": "charging", "charge_ticks": 0}
	return []


## Picks the profile (combo step or charge) and locks aim, then opens "windup"
## (charge only, when charge_profile.windup_ticks > 0) or "executing" directly (tap,
## or charge with windup_ticks <= 0 -- special-cased to skip windup entirely, so a
## weapon with no authored windup keeps resolving exactly as it did before this
## change). No longer resolves the swing or touches combo state itself -- that all
## moves to _advance_melee_execution_tick's hit-tick branch (manual-pass refinement,
## locked: "acceptance finalizes at the hit-active tick, not at press").
func _release_melee_hold(actor_id: int, weapon_id: String, command: Command) -> Array[Event]:
	var hold: Dictionary = _melee_hold.get(actor_id, {})
	if hold.get("weapon_id", "") != weapon_id or hold.get("state", "") != "charging":
		# No open CHARGING hold for this weapon -- usually switch/death/block already
		# cleared it. The one real case: the player released before a buffered press
		# ever materialized (_advance_buffered_attacks). Stash the release so it
		# resolves as one clean tap the moment the buffer opens, instead of a stuck
		# hold that envoy will never send a matching "released" for again (it
		# already told itself locally the button was up).
		var buffered: Dictionary = _melee_buffered_press.get(actor_id, {})
		if buffered.get("weapon_id", "") == weapon_id:
			var stored_facing: Vector3 = _facings.get(actor_id, Vector3(0.0, 0.0, -1.0))
			buffered.released = true
			buffered.release_aim = _normalize_horizontal(command.params.get("aim", Vector3.ZERO), stored_facing)
		return []

	var stored_facing: Vector3 = _facings.get(actor_id, Vector3(0.0, 0.0, -1.0))
	# Release-time aim (locked spec): a charged strike fires wherever the player is
	# aiming when they let go, never frozen at the moment they first pressed --
	# locked from here on, windup/executing never re-read command.params.aim again.
	var aim: Vector3 = command.params.get("aim", Vector3.ZERO)
	var resolved_aim: Vector3 = _normalize_horizontal(aim, stored_facing)
	_facings[actor_id] = resolved_aim

	var threshold: int = _melee_charge_threshold_ticks.get(weapon_id, 0)
	var charged: bool = int(hold.charge_ticks) >= threshold
	var profile: Dictionary
	var attack_profile_id: String
	if charged:
		profile = _melee_charge_profiles[weapon_id]
		attack_profile_id = "charge"
	else:
		var combo_profiles: Array = _melee_combo_profiles[weapon_id]
		var index: int = _combo_index.get(actor_id, 0)
		profile = combo_profiles[index]
		attack_profile_id = str(index + 1)

	if charged and int(profile.get("windup_ticks", 0)) > 0:
		_melee_hold[actor_id] = {
			"weapon_id": weapon_id,
			"state": "windup",
			"profile": profile,
			"attack_profile_id": attack_profile_id,
			"aim": resolved_aim,
			"windup_end_tick": tick_count + int(profile.get("windup_ticks", 0)),
		}
		return []

	_melee_hold[actor_id] = {
		"weapon_id": weapon_id,
		"state": "executing",
		"profile": profile,
		"attack_profile_id": attack_profile_id,
		"aim": resolved_aim,
		"execution_start_tick": tick_count,
		"hit_tick": tick_count + int(profile.get("hit_active_ticks", 0)),
		"end_tick": tick_count + int(profile.get("lunge_duration_ticks", 0)),
		"hit_resolved": false,
	}
	return []


## New autonomous phase (manual-pass lunge/windup) -- tick() order: after
## _advance_buffered_attacks, before AI decisions/Commands. Handles every actor with
## an OPEN "windup"/"executing" record that existed before this tick began; a record
## opened THIS tick by a Command is handled by the synchronous catch-up call at its
## Command-processing site instead (_apply_phased_melee_attack's "released" branch)
## -- see _advance_melee_execution_tick's own doc for why calling it unconditionally
## from both places would double-process a record's first tick. Autonomous-phase law
## (see tick()'s class comment): sorted actor_ids, re-fetched per actor since an
## earlier actor's resolution this same pass could in principle affect a later one.
func _advance_pending_attacks() -> Array[Event]:
	var events: Array[Event] = []
	var actor_ids: Array = _melee_hold.keys()
	actor_ids.sort()
	for actor_id in actor_ids:
		var hold: Dictionary = _melee_hold.get(actor_id, {})
		var state: String = hold.get("state", "")
		if state == "windup":
			if tick_count < int(hold.windup_end_tick):
				continue
			var profile: Dictionary = hold.profile
			# Origin moves (locked spec): resample position HERE, at the moment the
			# strike actually fires, never frozen at release -- free movement during
			# the windup means this can differ from the release-time position.
			# Direction (aim) carries over unchanged -- locked at release, never
			# re-tracks.
			_melee_hold[actor_id] = {
				"weapon_id": hold.weapon_id,
				"state": "executing",
				"profile": profile,
				"attack_profile_id": hold.attack_profile_id,
				"aim": hold.aim,
				"execution_start_tick": tick_count,
				"hit_tick": tick_count + int(profile.get("hit_active_ticks", 0)),
				"end_tick": tick_count + int(profile.get("lunge_duration_ticks", 0)),
				"hit_resolved": false,
			}
			events.append_array(_advance_melee_execution_tick(actor_id))
		elif state == "executing":
			events.append_array(_advance_melee_execution_tick(actor_id))
	return events


## Per-actor "executing" tick: lunge-this-tick, hit-tick check+resolve+combo
## bookkeeping, end-tick natural-completion+cooldown-arm+erase. Called from TWO
## places (manual-pass backward-compat/off-by-one fix -- see both call sites'
## comments): _advance_pending_attacks (a record already open before this tick),
## and synchronously from _apply_phased_melee_attack's "released" branch (a record
## that just opened THIS tick, after _advance_pending_attacks already ran) -- never
## both for the same tick's first execution step, or lunge movement/hit-tick checks
## would double-apply.
func _advance_melee_execution_tick(actor_id: int) -> Array[Event]:
	var hold: Dictionary = _melee_hold.get(actor_id, {})
	if hold.get("state", "") != "executing":
		return []
	var events: Array[Event] = []
	var profile: Dictionary = hold.profile

	# Lunge pass-through fix (manual-pass, locked spec): authored movement clamps to
	# hostile contact -- this is attack-authored movement semantics, not a general
	# collision layer (ordinary walking/enemies/walls/bounds stay untouched; ROADMAP
	# P20 remains fully open). Runs BEFORE hit resolution below, every tick, so the
	# clamp always sweeps against pre-knockback positions -- knockback (applied
	# later this same tick, only to the TARGET) can never retroactively place the
	# clamp through a target, and once clamped, later ticks never re-sweep at all
	# (frozen), so a subsequent knockback just opens the gap naturally -- no chase,
	# no attach, no pass-through possible. See _find_earliest_lunge_contact.
	var lunge_duration_ticks: int = int(profile.get("lunge_duration_ticks", 0))
	if lunge_duration_ticks > 0 and tick_count < int(hold.end_tick):
		if hold.has("clamped_target_id"):
			# Retained clamp: remaining authored distance for this tick is forfeited
			# -- never redistributed later, never converted into extra time (timing
			# invariance: this branch never touches hit_tick/end_tick/cooldown/combo
			# timing, only whether entities[actor_id] gets written this tick).
			# Defensive fallback (the primary path is _clear_clamps_targeting at both
			# death sites, which clears this the same tick the target dies/despawns
			# -- this only catches whatever that misses): if the clamp target is no
			# longer valid, clear it now but still skip movement THIS tick -- "never
			# retroactively apply the death tick's forfeited movement," resumption
			# starts next tick only.
			if not _is_valid_target(actor_id, int(hold.clamped_target_id)):
				hold.erase("clamped_target_id")
		else:
			var lunge_distance: float = float(profile.get("lunge_distance", 0.0))
			var step: Vector3 = hold.aim * (lunge_distance / lunge_duration_ticks)
			var start: Vector3 = entities.get(actor_id, Vector3.ZERO)
			var end: Vector3 = start + step
			var contact: Dictionary = _find_earliest_lunge_contact(start, end, actor_id)
			if contact.is_empty():
				entities[actor_id] = end
			else:
				entities[actor_id] = contact.entry_position
				hold.clamped_target_id = contact.target_id

	if tick_count >= int(hold.hit_tick) and not bool(hold.hit_resolved):
		hold.hit_resolved = true
		var attacker_position: Vector3 = entities.get(actor_id, Vector3.ZERO)
		events.append_array(_resolve_melee_swing(actor_id, attacker_position, hold.aim, profile, hold.weapon_id, hold.attack_profile_id))
		# Combo bookkeeping moves here from the old synchronous release (manual-pass
		# refinement, locked): "acceptance finalizes at the hit-active tick, not at
		# press" -- a swing canceled before this point retroactively never occurred
		# for combo purposes (see _cancel_open_melee_hold); a swing that reaches
		# this point and whiffs still advances, per the original lock. Derives the
		# combo step from the record's OWN attack_profile_id rather than re-reading
		# _combo_index, so this never depends on that dict having stayed untouched
		# since release.
		if hold.attack_profile_id == "charge":
			_combo_index[actor_id] = 0  # a charged hit ends the sequence (locked amendment)
		else:
			var combo_profiles: Array = _melee_combo_profiles[hold.weapon_id]
			var index: int = int(hold.attack_profile_id) - 1
			_combo_index[actor_id] = (index + 1) % combo_profiles.size()
			_combo_expire_tick[actor_id] = tick_count + _melee_combo_reset_ticks.get(hold.weapon_id, 0)

	if tick_count >= int(hold.end_tick):
		_next_fire_tick[actor_id] = int(hold.end_tick) + int(profile.get("fire_interval_ticks", 0))
		_melee_hold.erase(actor_id)

	return events


## Shared cancellation helper (rule of two: block's rising edge and an enemy hit
## landing on a winding-up/executing player both need it). State-agnostic -- reads
## only .weapon_id/.profile, never branches on state explicitly. Emits
## "melee_hold_canceled" iff a hold was actually open (checked BEFORE erasing).
## Never touches _combo_index/_combo_expire_tick (locked rule: canceling doesn't
## consume/reset combo progress -- only a charged hit landing, or death/switch via
## _clear_attack_input_state, does that). arm_cooldown only actually arms one when
## hold.has("profile") -- a "charging" hold never has this key (only assigned at
## release), so canceling a pre-release hold naturally stays cooldown-free, matching
## the existing tested contract, with no extra state check needed.
func _cancel_open_melee_hold(actor_id: int, arm_cooldown: bool) -> Array[Event]:
	var events: Array[Event] = []
	if _melee_hold.has(actor_id):
		var hold: Dictionary = _melee_hold[actor_id]
		events.append(Event.new(tick_count, "melee_hold_canceled", {"actor_id": actor_id, "weapon_id": String(hold.weapon_id)}))
		if arm_cooldown and hold.has("profile"):
			_next_fire_tick[actor_id] = tick_count + int(hold.profile.get("fire_interval_ticks", 0))
		_melee_hold.erase(actor_id)
	# A queued press is discarded on ANY cancellation, independent of whether a hold
	# happens to still be open (e.g. a swing already naturally completed and only
	# the buffered next press remains) -- "cancellation always clears the queue"
	# (locked spec), never conditional on _melee_hold's own state.
	_melee_buffered_press.erase(actor_id)
	return events


## Debug-only, read-only snapshot (arena.gd's debug_show_attack_state) -- never
## called during real gameplay logic, only for manual-pass observability. Public so
## the driver never reaches into an underscore-prefixed field directly (matches
## debug_set_ai_active's existing precedent).
func debug_describe_melee_state(actor_id: int) -> Dictionary:
	var description: Dictionary = {}
	if _melee_hold.has(actor_id):
		var hold: Dictionary = _melee_hold[actor_id]
		var state: String = hold.get("state", "")
		description["state"] = state
		if state == "charging":
			description["charge_ticks"] = hold.charge_ticks
		elif state == "windup":
			description["ticks_to_fire"] = int(hold.windup_end_tick) - tick_count
		elif state == "executing":
			description["ticks_to_hit"] = max(0, int(hold.hit_tick) - tick_count)
			description["recovery_ticks_remaining"] = max(0, int(hold.end_tick) - max(tick_count, int(hold.hit_tick)))
	if _melee_buffered_press.has(actor_id):
		var buffered: Dictionary = _melee_buffered_press[actor_id]
		description["buffered_weapon_id"] = buffered.weapon_id
		description["buffered_released"] = buffered.released
	return description


## Dev-only, read-only flinch/pressure snapshot (§5.26 observability) — never called by
## gameplay logic. Exposes the two clocks SEPARATELY (retained combo step lives in
## debug_describe_melee_state) because the two-clock rule is exactly the thing a player
## can't see and a developer must. No player-facing meter.
func debug_describe_flinch_state(actor_id: int) -> Dictionary:
	if not _flinch_thresholds.has(actor_id):
		return {}  # not a flinchable actor at all -- distinct from "zero pressure"
	var contributions: Array = []
	for contribution in _pressure_contributions.get(actor_id, []):
		contributions.append({"damage": contribution.damage, "ticks_left": int(contribution.expiry_tick) - tick_count})
	return {
		"pressure": _pressure_sum(actor_id),
		"threshold": _flinch_thresholds[actor_id],
		"threshold_reached": _pressure_sum(actor_id) >= float(_flinch_thresholds[actor_id]),
		"contributions": contributions,
		"action_mode": _flinch_mode_of(actor_id),
		"flinched_ticks_left": max(0, int(_flinched_until_tick.get(actor_id, -1)) - tick_count),
	}


## Shared melee target sweep (rule of two: the original single-profile instant path
## and Slice B's phased release both need it) — GAME-RULES §3's per-weapon hit
## detection, unchanged from the original _apply_attack body. attack_profile_id is
## "" for the original flat path (no melee_swing Event, no attack_profile_id key on
## the resulting hit Events — old payload shapes stay byte-identical) and "1"/"2"/
## "3"/"charge" for a Slice B swing.
func _resolve_melee_swing(actor_id: int, attacker_position: Vector3, resolved_aim: Vector3, weapon: Dictionary, weapon_id: String, attack_profile_id: String) -> Array[Event]:
	var events: Array[Event] = []
	if attack_profile_id != "":
		events.append(Event.new(tick_count, "melee_swing", {"actor_id": actor_id, "weapon_id": weapon_id, "attack_profile_id": attack_profile_id}))

	var target_ids: Array = _families.keys().filter(func(id): return _is_valid_target(actor_id, id))
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
		# doesn't apply (no defined direction is well-defined at true zero offset).
		# Point-blank melee (locked, pre-gate fix pass): this bypass lives HERE, in the
		# shared hit path used by every melee attacker — the Envoy's own sword has the
		# identical zero-offset seam swinging from inside a target's radius, not just
		# AI-driven enemies. Deliberately narrow (near-EXACT position coincidence,
		# not "combat radii merely overlap" more broadly) — at any nonzero offset the
		# cone direction is well-defined and the normal check already applies correctly.
		events.append_array(_resolve_hit_on_target(actor_id, target_id, weapon, resolved_aim, weapon_id, attack_profile_id))

	return events


## Shared resolution tail (iframe gate -> damage matrix -> shield gate -> status ->
## knockback -> death/events) for one attacker/target pair — GAME-RULES §3's pipeline
## is the SAME for every weapon class, so melee's per-target loop and a projectile's
## arrival (_advance_projectiles) both call this instead of duplicating it.
## Interruption as graded content (manual-pass, GAME-RULES §3) -- called only when an
## interrupting hit (interrupt_strength > 0) lands on a currently winding-up enemy.
## Clears the pending windup exactly like a completed attack would have (mirrors
## _decide_attack_commands' own consume-on-fire step) and arms the SAME cooldown a
## completed attack would have via _next_fire_tick, so the interrupt doesn't leave
## the enemy free to instantly re-windup -- "pending fire tick cleared -> cooldown".
## Uses _equipped_weapon rather than _ai_natural_weapon: register_ai always equips an
## AI actor's natural weapon internally, so the two are always equal here -- one dict
## hop instead of two.
func _cancel_enemy_windup(actor_id: int) -> void:
	_ai_attack_start_tick.erase(actor_id)
	_ai_attack_fire_tick.erase(actor_id)
	_next_fire_tick[actor_id] = tick_count + int(_weapons.get(_equipped_weapon.get(actor_id, ""), {}).get("fire_interval_ticks", 0))


## target_id's CURRENT action mode, derived from the windup it is actually in — no new
## state (the windup start tick already exists). Returns "normal" when not winding up,
## so §5.13b's action-scoped cleanup is free: _cancel_enemy_windup erases the start
## tick, and the vulnerability derived from it disappears with it. A FLINCHED enemy
## therefore never inherits the canceled action's susceptibility.
func _flinch_mode_of(actor_id: int) -> String:
	if not _ai_attack_start_tick.has(actor_id):
		return "normal"
	var susceptibility: Dictionary = _action_susceptibility.get(_equipped_weapon.get(actor_id, ""), {})
	if susceptibility.is_empty():
		return "normal"
	var start: int = int(susceptibility.get("vulnerable_start", -1))
	var end: int = int(susceptibility.get("vulnerable_end", -1))
	if start >= 0 and end >= start:
		var elapsed: int = tick_count - int(_ai_attack_start_tick[actor_id])
		if elapsed >= start and elapsed <= end:
			return "vulnerable"  # the interval always OVERRIDES the base mode
	return String(susceptibility.get("mode", "normal"))


## Records one contribution as a FACT (§3): never recomputed from HP, so healing can't
## erase it, and a successful flinch never consumes it — contributions only ever leave
## by expiring on their own tick.
func _record_pressure(target_id: int, amount: float) -> void:
	if amount <= 0.0 or not _flinch_thresholds.has(target_id):
		return
	var queue: Array = _pressure_contributions.get(target_id, [])
	queue.append({"damage": amount, "expiry_tick": tick_count + _pressure_window_ticks})
	_pressure_contributions[target_id] = queue


## Live pressure total, pruning expired contributions lazily as it reads (there is no
## per-tick scan anywhere — §3 forbids per-tick threshold monitoring).
func _pressure_sum(target_id: int) -> float:
	var queue: Array = _pressure_contributions.get(target_id, [])
	var live: Array = []
	var total: float = 0.0
	for contribution in queue:
		if int(contribution.expiry_tick) > tick_count:
			live.append(contribution)
			total += float(contribution.damage)
	if not queue.is_empty():
		_pressure_contributions[target_id] = live
	return total


## Picks the flinch route for one landed hit. Fixed short-circuit order with
## VULNERABILITY FIRST (§3): when both routes qualify, vulnerability wins as the
## REPORTED reason, while the hit's pressure contribution is still recorded normally by
## the caller and expires on its own tick. PROTECTED rejects everything.
## Threshold readiness is NOT cash-out: an "exploit" hit that pushes pressure past the
## threshold banks it for the next pressure-capable hit rather than flinching.
func _select_flinch_route(target_id: int, capability: String) -> String:
	if not _flinch_thresholds.has(target_id) or capability == "none":
		return ""
	var mode: String = _flinch_mode_of(target_id)
	if mode == "protected":
		return ""
	if mode == "vulnerable":
		return "exploit"
	if capability == "pressure" and _pressure_sum(target_id) >= float(_flinch_thresholds[target_id]):
		return "pressure"
	return ""


## PARRY EXPOSED lookup — 1.0 (no effect) unless a live exposure record exists. Read
## lazily at hit resolution; there is no per-tick scan, matching the pressure/flinch
## discipline of storing an absolute deadline and asking only when it matters.
func _parry_exposure_multiplier(actor_id: int) -> float:
	if tick_count >= int(_parry_exposed_until_tick.get(actor_id, -1)):
		return 1.0
	return float(_parry_exposed_damage_multiplier.get(actor_id, 1.0))


## P16 perfect parry. The window is measured from the shield's RISING EDGE, so it is
## earned by raising the shield into the attack rather than by holding it.
##
## NON-RETROACTIVITY INVARIANT (locked, deliberate): parry state is read at the moment
## a hit resolves, and phase order within a tick is preserved untouched. Projectiles
## resolve at the TOP of tick() (_advance_projectiles), before Commands, so a
## projectile arriving on the same tick the shield rises sees the PRE-RAISE shield
## state and is neither blocked nor parried by it. Later projectiles use the
## established shield/parry state normally through this same shared gate. This is NOT
## a "melee-only parry" rule -- it is ordinary non-retroactivity, and the fix is never
## to reorder projectile resolution for this feature.
##
## REFRESH, never stack: a newly earned parry overwrites the deadline with a fresh FULL
## window and re-sets the multiplier. Remaining duration is never added and multipliers
## never compound -- one record per actor. This deliberately diverges from flinch's
## non-extension rule: a defender-earned window should renew every time it is earned,
## whereas flinch must not be extendable by the attacker.
func _try_parry(defender_id: int, attacker_id: int) -> Array[Event]:
	var shield: Dictionary = _shields.get(defender_id, {})
	var window: int = int(shield.get("parry_window_ticks", 0))
	if window <= 0 or not _block_start_tick.has(defender_id):
		return []
	if tick_count - int(_block_start_tick[defender_id]) > window:
		return []
	var exposure: int = int(shield.get("parry_exposure_ticks", 0))
	var multiplier: float = float(shield.get("parry_damage_multiplier", 1.0))
	if exposure <= 0 or multiplier <= 1.0:
		return []  # inert content -- a parry with no payload is not an event
	_parry_exposed_until_tick[attacker_id] = tick_count + exposure
	_parry_exposed_damage_multiplier[attacker_id] = multiplier
	return [Event.new(tick_count, "parried", {
		"defender_id": defender_id,
		"attacker_id": attacker_id,
		"until_tick": tick_count + exposure,
		"damage_multiplier": multiplier,
	})]


func _resolve_hit_on_target(attacker_id: int, target_id: int, weapon: Dictionary, resolved_aim: Vector3, weapon_id: String, attack_profile_id: String = "") -> Array[Event]:
	# i-frames fully negate a hit: no damage, no knockback, no status, no meter
	# interaction — the attack simply doesn't land (locked invariant).
	if _iframe_ticks_remaining.get(target_id, 0) > 0:
		return [Event.new(tick_count, "attack_absorbed", {
			"attacker_id": attacker_id, "target_id": target_id, "reason": "iframes",
		})]

	var family: StringName = _families[target_id]
	var multiplier: float = _damage_multiplier(weapon.damage_type, family)
	# P16 PARRY EXPOSED: the narrowest possible seam -- ONE multiply, folded in beside
	# the damage matrix rather than a new mitigation stage. Because it lands before the
	# post-mitigation figure is recorded, parry damage feeds the pressure ledger and
	# every downstream consumer naturally, with no special-casing anywhere.
	# Damage ONLY: this never confers EXPLOIT/flinch susceptibility (see LEXICON).
	var damage: float = weapon.damage * multiplier * _parry_exposure_multiplier(target_id)
	var target_position: Vector3 = entities.get(target_id, Vector3.ZERO)

	# A held shield redirects damage into its own meter instead of health — no health
	# loss, no weapon knockback, no i-frames (distinct defenses; block must not also
	# grant invulnerability). See _resolve_blocked_hit.
	if _shield_state.get(target_id, "ready") == "held":
		var blocked: Array[Event] = [_resolve_blocked_hit(target_id, target_position, resolved_aim, attacker_id, damage)]
		# P16 perfect parry: a hit landing inside the window measured from the shield's
		# own rising edge (_block_start_tick, which already existed) marks the ATTACKER
		# PARRY EXPOSED. The meter still drained above, deliberately -- a parry's only
		# extra reward is the offensive punish window, never meter efficiency.
		blocked.append_array(_try_parry(target_id, attacker_id))
		return blocked

	var hp_before: float = _health[target_id]
	var remaining_health: float = hp_before - damage
	_health[target_id] = remaining_health

	# Pressure bookkeeping runs BEFORE route selection (locked): a finisher whose own
	# damage crosses the threshold must cash out on THIS hit, not the next one. An
	# overkill hit contributes min(damage, hp_before) so accounting stays deterministic
	# and a corpse can't bank more than it had left. Blocked/absorbed hits never reach
	# here at all, and status/DoT damage never routes through this function -- both are
	# excluded structurally rather than by a flag.
	if bool(weapon.get("contributes_pressure", true)):
		_record_pressure(target_id, min(damage, hp_before))

	# Route selection must read the windup while it is STILL LIVE -- the cancel below
	# erases the start tick that the vulnerability window is derived from. Death
	# supersedes flinch (§3): a dead actor is never functionally flinched.
	var flinch_reason: String = ""
	if remaining_health > 0.0:
		flinch_reason = _select_flinch_route(target_id, String(weapon.get("flinch_capability", "none")))

	# Interruption as graded content (manual-pass, GAME-RULES §3): while target_id is
	# winding up its own attack, a non-interrupting hit (interrupt_strength <= 0)
	# neither cancels the windup nor displaces the target -- damage/status below
	# still resolve normally, only knockback is suppressed (crowding a stunned-
	# looking enemy shouldn't shove it out of its own windup for free). Otherwise
	# displacement is a de facto interrupt, so an interrupting hit both knocks back
	# AND cancels the windup. A target that isn't winding up is completely
	# unaffected by any of this -- unconditional knockback, exactly as before.
	var target_is_winding_up: bool = _ai_attack_fire_tick.has(target_id)
	var interrupt_strength: int = int(weapon.get("interrupt_strength", 0))
	var interrupts_this_windup: bool = target_is_winding_up and interrupt_strength > 0
	var knocked_position: Vector3 = target_position
	if not target_is_winding_up or interrupt_strength > 0:
		knocked_position = target_position + resolved_aim * weapon.knockback_distance
		entities[target_id] = knocked_position
	# ATOMICITY (locked): the enemy's current action is canceled EXACTLY ONCE, here at
	# hit resolution -- windup clear, cooldown arming, the interruption Event, and the
	# action-scoped susceptibility cleanup are ONE combat consequence, whether the cause
	# was graded interrupt_strength, a flinch, or both. Nothing downstream re-cancels:
	# the AI phase only OBSERVES FLINCHED and never mutates combat state.
	var cancels_windup: bool = target_is_winding_up and (interrupt_strength > 0 or flinch_reason != "")
	if cancels_windup:
		_cancel_enemy_windup(target_id)

	# Hit-establishes-aggro (locked defect fix): a successful hostile hit FROM THE
	# PLAYER activates the target's AI regardless of detection_radius — detection is
	# passive-acquisition only; a landed hit is an unambiguous "the player is right
	# here." Harmless no-op for a non-AI target (_ai_state.has check) or a lethal hit
	# (the target dies this same resolution and AI already skips dead actors).
	if _allegiance.get(attacker_id, &"enemy") == &"player" and _ai_state.has(target_id):
		_ai_state[target_id] = "active"

	var hit_payload: Dictionary = {
		"attacker_id": attacker_id,
		"target_id": target_id,
		"damage": damage,
		"damage_type": weapon.damage_type,
		"family": family,
		"position": knocked_position,
	}
	# Slice B: profile identity never substitutes for weapon identity -- omitted
	# entirely (not even an empty string) for the original flat path, so every
	# existing test's exact payload-key expectations stay untouched.
	if attack_profile_id != "":
		hit_payload["attack_profile_id"] = attack_profile_id
	var events: Array[Event] = [Event.new(tick_count, "hit", hit_payload)]
	if cancels_windup:
		events.append(Event.new(tick_count, "windup_interrupted", {"actor_id": target_id, "attacker_id": attacker_id}))
	if flinch_reason != "":
		# Re-flinch: a qualifying flinch on an ALREADY-flinched enemy fully registers
		# damage/pressure/knockback/interruption but does NOT extend the deadline.
		# EVIDENCE BOUNDARY (2026-08-13 re-gate) -- deliberately split, do not collapse:
		#   MECHANICAL non-extension: VALIDATED. Proven by the step-3 lifecycle tests
		#     (test_flinch.gd + test_flinch_validation.gd::test_34), and immutable by
		#     construction -- the assignment below is the only write and is guarded.
		#   GENERAL flinch feel: VALIDATED ("Displacement and flinch looked good").
		#   NARROW feel of sustained repeated chain-flinch on a susceptible survivor:
		#     STILL OPEN. The re-gate did not deliberately exercise it, so no claim is
		#     made either way. Non-extension vs refresh stays a live design question,
		#     and deliberately NOT a content flag until real evidence exists.
		var already_flinched: bool = tick_count < int(_flinched_until_tick.get(target_id, -1))
		if not already_flinched:
			_flinched_until_tick[target_id] = tick_count + _flinch_recovery_ticks
		events.append(Event.new(tick_count, "flinched", {
			"actor_id": target_id,
			"attacker_id": attacker_id,
			"reason": flinch_reason,
			"until_tick": int(_flinched_until_tick.get(target_id, tick_count)),
			# CONTRACT: true iff processing THIS flinch wrote _flinched_until_tick.
			# It names the observable write, not a design meaning, so it stays correct
			# under the current non-extension rule AND under any future refresh rule.
			# (It was briefly named "extended", which read as the opposite of the
			# mechanic on a first flinch -- nothing is extended when a deadline is
			# first established. Observability must never state the inverse of the
			# behavior it reports.)
			"recovery_deadline_set": not already_flinched,
		}))

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
		events.append_array(_clear_attack_input_state(target_id))
		_clear_clamps_targeting(target_id)
		_clear_reaction_state(target_id)
	else:
		# Lethal hits start no timer (moot for the dead) — non-lethal unblocked hits
		# are the ONLY i-frame trigger this session (dodge is a future, separately-
		# scoped second trigger through this same timer).
		_iframe_ticks_remaining[target_id] = _iframe_ticks_on_hit.get(target_id, 0)
		if proc_result.get("succeeded", false):
			events.append(_apply_status(target_id, weapon.status_id, "hit", attacker_id, weapon_id))
		# M1 simplification: all incoming hits interrupt pending player attacks.
		# Future: respect interrupt_strength/poise. Unconditional, not graded by the
		# attacker's interrupt_strength (no enemy content sets that field today --
		# this is a separate, simpler "getting hit interrupts your own attack" rule,
		# not an extension of the player-interrupts-enemy-windup mechanic above).
		# Deliberately excludes "charging" (pre-release hold interruptibility is out
		# of scope for this change) -- only an open windup/executing record cancels.
		var target_hold_state: String = _melee_hold.get(target_id, {}).get("state", "")
		if target_hold_state == "windup" or target_hold_state == "executing":
			events.append_array(_cancel_open_melee_hold(target_id, true))
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


## Closest-point-on-segment test against every live, targetable, HOSTILE combatant
## except the shooter — earliest intersection along the segment wins; sorted
## ascending actor_id iteration breaks an exact tie in favor of the lower id (mirrors
## melee's sorted-target-id determinism rule). Returns -1 for no hit. Ally-filtering
## (_is_valid_target) means an allied actor is never even a candidate here — a shot
## passes straight through one with no expiry, no mutual bullet shields between allies.
func _find_earliest_swept_hit(start: Vector3, end: Vector3, attacker_id: int, hit_radius: float) -> int:
	var travel: Vector3 = end - start
	var travel_length_sq: float = travel.length_squared()

	var best_target_id: int = -1
	var best_t: float = INF
	var candidate_ids: Array = _families.keys().filter(func(id): return _is_valid_target(attacker_id, id))
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


## P16 shield bump — displaces every living HOSTILE already inside contact range plus
## the authored padding, away from the blocker. Eligibility is
## `distance <= _contact_distance(blocker, hostile) + bump_padding`, so the authored
## number means EXTRA PROXIMITY BEYOND both actors' combat footprints and scales itself
## across families of different size rather than needing per-family radii.
## Reuses the same direct displacement write knockback already performs — no new
## movement path, and deliberately no generic "reaction" framework for one consumer.
## Allies are never bumped (_is_valid_target), matching every other sweep in this file.
func _apply_shield_bump(actor_id: int, shield: Dictionary) -> Array[Event]:
	var distance: float = float(shield.get("bump_distance", 0.0))
	if distance <= 0.0 or tick_count < int(_shield_bump_ready_tick.get(actor_id, 0)):
		return []  # inert content, or still cooling down -- blocking itself is unaffected
	var padding: float = float(shield.get("bump_padding", 0.0))
	var origin: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var bumped: Array = []
	var candidate_ids: Array = _families.keys().filter(func(id): return _is_valid_target(actor_id, id))
	candidate_ids.sort()  # determinism -- dictionary order must never leak into event order
	for target_id in candidate_ids:
		var offset: Vector3 = entities.get(target_id, Vector3.ZERO) - origin
		offset.y = 0.0
		var reach: float = _contact_distance(actor_id, target_id) + padding
		if offset.length_squared() > reach * reach:
			continue
		# Zero offset has no defined push direction; fall back to the blocker's facing
		# so a perfectly overlapping actor is still moved deterministically.
		var direction: Vector3 = _normalize_horizontal(offset, _facings.get(actor_id, Vector3(0.0, 0.0, -1.0)))
		# Start an authored SLIDE rather than teleporting: the whole point of the
		# revision is that the motion reads as a controlled shove over time.
		var slide_ticks: int = max(1, int(shield.get("bump_slide_ticks", 1)))
		_bump_slides[target_id] = {
			"direction": direction,
			"step_distance": distance / float(slide_ticks),
			"steps_remaining": slide_ticks,
		}
		bumped.append(target_id)
	if bumped.is_empty():
		# LOCKED RULE: the cooldown arms only when at least one hostile is actually
		# displaced. It exists to RATE-LIMIT THE SPACING EFFECT, not to punish an empty
		# shield raise -- a rising edge with no eligible hostile produces no bump and
		# spends no cooldown. Found by test: arming on every edge meant raising the
		# shield in open space locked out the next real bump.
		return []
	_shield_bump_ready_tick[actor_id] = tick_count + int(shield.get("bump_cooldown_ticks", 0))
	return [Event.new(tick_count, "shield_bumped", {"actor_id": actor_id, "bumped_ids": bumped})]


## Advances every live BUMP slide by one authored step. Reuses the SAME segment sweep
## the sword lunge uses (_find_earliest_lunge_contact), so bump inherits whatever the
## project authoritatively treats as a blocker rather than inventing its own rules.
## KNOWN LIMITATION, deliberately not fixed here (ROADMAP P20): that sweep only
## considers actors of a DIFFERENT allegiance, and no walls or arena bounds exist
## anywhere in this project. A bumped enemy can therefore slide through another enemy
## and past the visual arena edge. Revalidate bump when body-blocking or world bounds
## become real; do not pull that work forward for this Treat.
## Autonomous-phase law (see tick()): sorted ids, no mutation of the collection while
## iterating -- completed slides are collected first and erased afterwards.
func _advance_bump_slides() -> void:
	var actor_ids: Array = _bump_slides.keys()
	actor_ids.sort()
	var completed: Array = []
	for actor_id in actor_ids:
		var slide: Dictionary = _bump_slides[actor_id]
		var start: Vector3 = entities.get(actor_id, Vector3.ZERO)
		var end: Vector3 = start + slide.direction * float(slide.step_distance)
		# Closing-direction semantics mean separation is never clamped by the source,
		# so this only stops the slide against something it is genuinely moving INTO.
		var contact: Dictionary = _find_earliest_lunge_contact(start, end, actor_id)
		if contact.is_empty():
			entities[actor_id] = end
		else:
			entities[actor_id] = contact.entry_position
			completed.append(actor_id)  # blocked: the slide ends here, never chases
			continue
		# Counted in STEPS rather than compared against an end tick: the record is
		# created during one tick's Commands and first advances on the NEXT, so tick
		# arithmetic here is off-by-one bait. A counter simply cannot drift.
		slide.steps_remaining = int(slide.steps_remaining) - 1
		if int(slide.steps_remaining) <= 0:
			completed.append(actor_id)
	for actor_id in completed:
		_bump_slides.erase(actor_id)


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
			# Slice B interruption rule (locked): raising block cancels an
			# in-progress charge hold/windup/executing swing -- no swing (or no
			# REST of an in-progress one), no charge event, attacking and defensive
			# blocking never coexist. combo_index/expire deliberately survive (see
			# _cancel_open_melee_hold's doc) -- this only discards the attack itself.
			# Shield-cancel timing (manual-pass, locked): because _advance_pending_
			# attacks already ran earlier this same tick (see tick()), an
			# "executing" record's hit_resolved is already correctly set one way or
			# the other by the time this runs -- pre-hit-tick: no hit ever happened
			# (combo bookkeeping never ran either, since it lives in the hit-tick
			# branch); same-tick-as-hit: the hit already resolved, only remaining
			# lunge/recovery is canceled; post-hit (recovery): hit already stands.
			# One uniform cancel call correctly produces all three outcomes.
			#
			# P16 shield bump fires on THIS rising edge -- spacing utility, never
			# timing-gated, so it is available to any player rather than being a
			# second skill check. Its own cooldown gates ONLY the bump: the shield
			# above is already raised and blocks normally either way.
			var events: Array[Event] = _apply_shield_bump(actor_id, shield)
			events.append_array(_cancel_open_melee_hold(actor_id, true))
			return events
	elif state == "held":
		if not held:
			_shield_state[actor_id] = "ready"

	return []


## Advances actor_id's equipped weapon to the next id in its registered loadout
## (set_weapon_loadout), wrapping around — a local "cycle" input, not identity: the
## Command carries no weapon_id (see set_weapon_loadout's boundary-rule comment).
## An actor with no registered loadout (e.g. an enemy) silently no-ops.
func _apply_switch_weapon(command: Command) -> Array[Event]:
	var actor_id: int = command.actor_id
	if not _weapon_loadouts.has(actor_id):
		return []
	var loadout: Array[String] = _weapon_loadouts[actor_id]
	if loadout.is_empty():
		return []
	var current_index: int = loadout.find(_equipped_weapon.get(actor_id, ""))
	if current_index == -1:
		current_index = 0
	var next_index: int = (current_index + 1) % loadout.size()
	var next_weapon_id: String = loadout[next_index]
	# Slice B interruption rule (locked): a switch discards any in-progress hold and
	# resets the combo sequence -- no tap fires, no charge event, combo state never
	# survives a weapon swap in M1. _clear_attack_input_state's own "melee_hold_
	# canceled" Event (if a hold was actually open) is a real observable transition,
	# distinct from -- and always alongside -- "weapon_switched".
	var events: Array[Event] = _clear_attack_input_state(actor_id)
	_equipped_weapon[actor_id] = next_weapon_id
	events.append(Event.new(tick_count, "weapon_switched", {"actor_id": actor_id, "weapon_id": next_weapon_id}))
	return events


## STANDING RULE (locked, pre-gate fix pass — belongs in GAME-RULES §3 once a human
## can edit that file; guard.py blocks agent edits to it by design, so it lives here
## until then): distance preferences (preferred_attack_distance/minimum_attack_
## distance) govern MOVEMENT ONLY. They never gate attack eligibility. Crowding an
## enemy triggers a movement response (retreat), never a shutdown of its ability to
## attack — applies to every current and future engagement AI, melee or ranged alike.
## See _decide_single_ai_command's attack-priority ordering for the mechanism.
##
## Enemy AI top-level decision pass (Phase D step 8 Phase 4) — a CONSUMER of the
## existing simulation, not a new gameplay system: it only ever decides
## move_direction/attack-intent, synthesizing the exact same Command shapes a
## player would send. No RNG (deterministic AI v1). Actors iterate in sorted
## actor_id order so dictionary iteration order never leaks into decision/event
## order (same discipline as every other autonomous phase — see tick()'s
## class-level "Autonomous-phase law" comment). events is mutated in place
## (Array is a reference type in GDScript) so a telegraph can be appended at the
## exact moment an enemy commits to a windup, which isn't itself the result of
## applying any Command.
func _decide_ai_commands(events: Array[Event]) -> Array[Command]:
	var commands: Array[Command] = []
	var player_id: int = _find_living_player_id()
	if player_id == -1:
		# No living player: enemies stop acting entirely (locked). Any in-progress
		# windup simply sits inert — a restart (fresh SimWorld) is the only way play
		# resumes, per Phase 3's death handling.
		return commands

	var ai_actor_ids: Array = _ai_state.keys()
	ai_actor_ids.sort()
	for actor_id in ai_actor_ids:
		if _health.get(actor_id, 0.0) <= 0.0:
			continue  # a dead enemy emits nothing and decides nothing
		commands.append_array(_decide_single_ai_command(actor_id, player_id, events))
	return commands


func _find_living_player_id() -> int:
	var actor_ids: Array = _allegiance.keys()
	actor_ids.sort()
	for actor_id in actor_ids:
		if _allegiance[actor_id] == &"player" and _health.get(actor_id, 0.0) > 0.0:
			return actor_id
	return -1


## One actor_id's idle/active state machine for this tick. "active" covers
## both pursuing and engaged — attack timing is two nullable tick fields
## (_ai_attack_start_tick/_ai_attack_fire_tick), not a fourth state; see
## _decide_attack_commands.
func _decide_single_ai_command(actor_id: int, player_id: int, events: Array[Event]) -> Array[Command]:
	# FLINCHED: pure OBSERVATION (locked). This branch mutates nothing and emits
	# nothing -- the cancel, the cooldown arming, and the Event all happened once, at
	# hit resolution. A flinched enemy simply yields no Command: no new attack, and no
	# ordinary approach/retreat movement. Its cooldown deadline keeps running in the
	# same absolute tick space, so effective attack denial is max(recovery, cooldown),
	# never the sum. In-flight projectiles are untouched -- flinch cancels ACTION state,
	# not combat entities that already exist.
	if tick_count < int(_flinched_until_tick.get(actor_id, -1)):
		return []

	var tuning: Dictionary = _ai_tuning[actor_id]
	var spawn_position: Vector3 = _ai_spawn_position[actor_id]
	var position: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var player_position: Vector3 = entities.get(player_id, Vector3.ZERO)
	var state: String = _ai_state.get(actor_id, "idle")

	if state == "idle":
		var spawn_to_player: Vector3 = player_position - spawn_position
		spawn_to_player.y = 0.0
		if spawn_to_player.length() > tuning.detection_radius:
			return []  # no re-acquisition path except idle -> active (locked)
		_ai_state[actor_id] = "active"
		state = "active"

	# state == "active": leash check first (measured from the fixed anchor, not this
	# actor's current position) — a player who wandered far enough drops pursuit
	# entirely, even if still technically "in range" of a leash-adjacent position.
	var spawn_to_player: Vector3 = player_position - spawn_position
	spawn_to_player.y = 0.0
	if spawn_to_player.length() > tuning.leash_radius:
		# Disengage (locked behavior change, pre-gate fix pass): no universal
		# return-to-spawn. The enemy stops exactly where it is and goes idle
		# immediately — its leash/detection anchor RE-ANCHORS to this stopped
		# position, so the NEXT chase is leashed from here, not the original spawn
		# point (an accepted "chain-drag" consequence for this milestone; noted for
		# M2's room-bounded territory). Passive re-acquisition still only happens
		# from idle, using the new anchor — the existing idle->active reset rule is
		# unchanged. Original scene spawn positions are scene-init/encounter-reset
		# data only (register_ai unconditionally overwrites this on re-registration).
		_ai_spawn_position[actor_id] = position
		_ai_state[actor_id] = "idle"
		_ai_attack_start_tick.erase(actor_id)
		_ai_attack_fire_tick.erase(actor_id)
		return []

	# Attack priority over movement (locked defect fix): preferred/minimum distance
	# governs MOVEMENT ONLY -- it never gates whether an otherwise-valid attack can
	# start. The earlier version let retreat pre-empt an attack that could otherwise
	# land, which meant a player standing inside an enemy's minimum_attack_distance
	# could suppress that enemy's attack indefinitely (a real exploit, not cosmetic
	# jitter). Order, evaluated fresh every tick:
	#   1. A windup already in progress always freezes movement and runs to
	#      completion, regardless of how distance has changed since it started (no
	#      more mid-windup distance-based cancellation).
	#   2. Otherwise, if the weapon's own cooldown has elapsed AND the target is
	#      within its actual reach (== preferred_attack_distance; content's job to
	#      keep those equal, see NaturalWeaponStats), stop and start a new windup --
	#      even at a distance inside minimum_attack_distance. Crowding cannot
	#      indefinitely suppress an attack.
	#   3. Only if neither of the above applies does movement preference run:
	#      closer than minimum -> retreat, farther than preferred -> approach,
	#      inside the band (here only because the weapon is on cooldown) -> hold.
	if _ai_attack_fire_tick.has(actor_id):
		return _decide_attack_commands(actor_id, tuning, player_id, events)

	var to_player: Vector3 = player_position - position
	to_player.y = 0.0
	var distance_to_player: float = to_player.length()

	if tick_count >= _next_fire_tick.get(actor_id, 0) and distance_to_player <= tuning.preferred_attack_distance:
		return _decide_attack_commands(actor_id, tuning, player_id, events)

	if distance_to_player < tuning.minimum_attack_distance:
		return [Command.new(tick_count, actor_id, "move", {"direction": -to_player.normalized()})]

	if distance_to_player > tuning.preferred_attack_distance:
		return [Command.new(tick_count, actor_id, "move", {"direction": to_player.normalized()})]

	return []  # in band, weapon on cooldown: hold position and wait


## In-range attack timing — two nullable tick fields, not a distinct "windup" state
## (locked). Reuses the shared per-actor fire-rate gate (_next_fire_tick, the same
## one _apply_attack already checks) instead of a second AI-owned cooldown dict, so
## an enemy can't start a new windup before its own weapon's fire_interval_ticks has
## elapsed from its last actual attack.
func _decide_attack_commands(actor_id: int, tuning: Dictionary, player_id: int, events: Array[Event]) -> Array[Command]:
	if _ai_attack_fire_tick.has(actor_id):
		if tick_count < _ai_attack_fire_tick[actor_id]:
			return []  # still winding up
		_ai_attack_start_tick.erase(actor_id)
		_ai_attack_fire_tick.erase(actor_id)
		var stored_facing: Vector3 = _facings.get(actor_id, Vector3(0.0, 0.0, -1.0))
		var aim: Vector3 = _normalize_horizontal(entities.get(player_id, Vector3.ZERO) - entities.get(actor_id, Vector3.ZERO), stored_facing)
		return [Command.new(tick_count, actor_id, "attack", {"aim": aim})]

	if tick_count < _next_fire_tick.get(actor_id, 0):
		return []  # weapon's own cooldown from the last attack hasn't elapsed yet

	_ai_attack_start_tick[actor_id] = tick_count
	_ai_attack_fire_tick[actor_id] = tick_count + int(tuning.windup_ticks)
	var weapon_id: String = _ai_natural_weapon.get(actor_id, "")
	var damage_type: String = _weapons.get(weapon_id, {}).get("damage_type", "force")
	events.append(Event.new(tick_count, "attack_telegraph", {"actor_id": actor_id, "damage_type": damage_type}))
	return []


## Arms/refreshes target_id's single status slot (GAME-RULES §3: exclusive, never
## stacked). Re-applying the SAME status_id always refreshes (a melee weapon hitting
## an already-Burning target resets its clock); a DIFFERENT status only overwrites
## when its priority is >= the active one's — with only Burn registered this session
## that branch is structurally present but unreachable/untested until a second status
## (ROADMAP P2) makes it real, same "ships complete, content catches up" shape as the
## damage matrix. applied_tick is the one-tick grace gate: a status armed THIS tick
## cannot deal a DoT pulse or act as a contact-spread source until a later tick.
## inherited_duration (locked, pre-gate fix pass): a HIT application (the default,
## -1) always arms the full configured duration — the existing refresh behavior.
## Contact spread passes the transmitting source's own remaining duration instead
## (snapshotted by the caller under the autonomous-phase law) so a chain can never
## contain more remaining duration than its source had; still capped at the
## configured duration as a defensive floor/ceiling, never a fresh full copy.
func _apply_status(target_id: int, status_id: StringName, application_source: String, source_actor_id: int, source_weapon_id: String, inherited_duration: int = -1) -> Event:
	var new_id: String = String(status_id)
	var existing: Dictionary = _status_instances.get(target_id, {})
	var can_apply: bool = existing.is_empty() or existing.id == new_id or _status_priority.get(new_id, 0) >= _status_priority.get(existing.id, 0)
	if can_apply:
		var config: Dictionary = _status_config[new_id]
		var duration: int = config.duration_ticks if inherited_duration < 0 else min(inherited_duration, config.duration_ticks)
		_status_instances[target_id] = {
			"id": new_id,
			"ticks_remaining": duration,
			"next_tick": tick_count + config.tick_interval_ticks,
			"applied_tick": tick_count,
		}
		# Hit-establishes-aggro (locked defect fix): a status APPLICATION (fresh apply
		# or refresh) attributable to the player also activates the target's AI,
		# exactly like a health-hit — covers a hit-triggered proc AND Burn's contact
		# spread when its immediate source is the player. A later DoT TICK never
		# reaches this function at all (_advance_status_ticks resolves ticks
		# directly), so ticking alone can never (re-)establish aggro — only an
		# application can.
		if _allegiance.get(source_actor_id, &"enemy") == &"player" and _ai_state.has(target_id):
			_ai_state[target_id] = "active"
	var payload: Dictionary = {
		"target_id": target_id,
		"status_id": new_id,
		"application_source": application_source,
		"source_actor_id": source_actor_id,
	}
	if application_source == "hit":
		payload["source_weapon_id"] = source_weapon_id
	return Event.new(tick_count, "status_applied", payload)


## Authoritative contact distance between two actors (combined combat radii + the
## one shared _CONTACT_PADDING) -- the single source of truth for "physical
## contact" GAME-RULES §3 leans on twice: Burn's contact-spread (_actors_overlap)
## and the manual-pass melee lunge clamp (_find_earliest_lunge_contact). Never
## duplicate this formula at either call site.
func _contact_distance(a: int, b: int) -> float:
	return _combat_radius.get(a, 0.0) + _combat_radius.get(b, 0.0) + _CONTACT_PADDING


## Manual-pass lunge clamp: sweeps actor_id's intended movement segment [start,end]
## against every living HOSTILE combatant's authoritative contact distance
## (_contact_distance -- combined combat radii, GAME-RULES §3), finding the TRUE
## entry point where the segment first crosses into contact range (proper segment-
## circle intersection -- NOT merely "closest approach within radius", which is
## what _find_earliest_swept_hit's projectile math answers; that's a different
## question, "does this segment ever get close enough," not "where exactly does it
## first touch"). Earliest entry along the segment wins; exact-t ties break by
## ascending actor_id for free (candidates are visited in sorted order, and only a
## STRICTLY earlier t replaces the current best -- mirrors every other sweep's
## determinism rule in this file). Ally-filtering (_is_valid_target) means an
## allied actor is never even a candidate -- allies never clamp the lunge. Returns
## {} if the full segment stays clear of every hostile's contact range.
func _find_earliest_lunge_contact(start: Vector3, end: Vector3, actor_id: int) -> Dictionary:
	var travel: Vector3 = end - start
	travel.y = 0.0
	var a_coeff: float = travel.length_squared()

	var best_target_id: int = -1
	var best_t: float = INF
	var candidate_ids: Array = _families.keys().filter(func(id): return _is_valid_target(actor_id, id))
	candidate_ids.sort()

	for target_id in candidate_ids:
		var target_position: Vector3 = entities.get(target_id, Vector3.ZERO)
		var contact: float = _contact_distance(actor_id, target_id)
		var f: Vector3 = start - target_position
		f.y = 0.0
		var c_coeff: float = f.length_squared() - contact * contact

		# b_coeff < 0 means this segment is CLOSING the gap toward the candidate.
		var b_coeff: float = 2.0 * f.dot(travel)
		var t: float = INF
		if c_coeff <= 0.0:
			# Already inside contact distance. CLOSING-DIRECTION SEMANTICS (locked):
			# a body obstructs only movement that closes toward it -- you are never
			# blocked by the thing you are moving AWAY from. Previously this branch
			# clamped unconditionally ("entry is immediate"), which is right for an
			# attacker lunging in but exactly backwards for separation: BUMP starts
			# from inside contact by definition, so an unconditional clamp would pin
			# the bumped actor in place and it would never move at all.
			# Expressed here as truthful contact semantics rather than a "BUMP skips
			# the clamp" special case -- the clamp simply never applied to separation.
			if b_coeff < 0.0:
				t = 0.0
		elif a_coeff > _FACING_EPSILON_SQ:
			var discriminant: float = b_coeff * b_coeff - 4.0 * a_coeff * c_coeff
			if discriminant >= 0.0:
				var t_candidate: float = (-b_coeff - sqrt(discriminant)) / (2.0 * a_coeff)
				if t_candidate >= 0.0 and t_candidate <= 1.0:
					t = t_candidate
		# else: a_coeff ~= 0 (no movement this tick) and not already inside -> no entry.

		if t < best_t:
			best_t = t
			best_target_id = target_id

	if best_target_id == -1:
		return {}
	return {"target_id": best_target_id, "entry_position": start + travel * best_t}


## True if a and b's registered combat_radius circles overlap (horizontal distance —
## flattened like melee's reach check, GAME-RULES §3 "spreads on contact"). Pure
## SimWorld distance math against `entities`/`_combat_radius` — no Area3D/
## body_entered, no generic collision subsystem (locked scope fence).
func _actors_overlap(a: int, b: int) -> bool:
	var offset: Vector3 = entities.get(b, Vector3.ZERO) - entities.get(a, Vector3.ZERO)
	offset.y = 0.0
	var contact: float = _contact_distance(a, b)
	return offset.length_squared() <= contact * contact


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

	var eligible_sources: Dictionary = {}  # actor_id -> {status_id, remaining_duration}, snapshot -- never re-read after this loop
	for actor_id in _status_instances.keys():
		var instance: Dictionary = _status_instances[actor_id]
		if instance.applied_tick < tick_count and _health.get(actor_id, 0.0) > 0.0:
			eligible_sources[actor_id] = {"status_id": instance.id, "remaining_duration": instance.ticks_remaining}

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
			collected.append({"recipient": recipient_id, "source": source_id, "status_id": eligible_sources[source_id].status_id, "remaining_duration": eligible_sources[source_id].remaining_duration, "pair_key": pair_key})

	collected.sort_custom(func(x, y): return x.recipient < y.recipient if x.recipient != y.recipient else x.source < y.source)
	for entry in collected:
		_contact_transmitted_pairs[entry.pair_key] = true
		events.append(_apply_status(entry.recipient, entry.status_id, "spread", entry.source, "", entry.remaining_duration))
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
				events.append_array(_clear_attack_input_state(actor_id))
				_clear_clamps_targeting(actor_id)
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
