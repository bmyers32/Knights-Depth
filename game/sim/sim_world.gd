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
## DAMAGE SOURCE KINDS (ruled 2026-09-03). A closed pair, deliberately: damage is caused either
## by an ACTOR, which has an id and can be parried and can earn aggro, or by the ENVIRONMENT,
## which has neither. Everything else about resolution is identical, and BOTH travel the same
## authoritative pipeline -- a hazard is not an attacker, but it is also not a second combat
## system. There is no phantom attacker id anywhere and no environment faction.
const SOURCE_ACTOR: StringName = &"actor"
const SOURCE_ENVIRONMENT: StringName = &"environment"

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
## gets its OWN GAME-RULES §1.3 stream, never combat's). AI decides locomotion,
## whether to attack now, and (P29, GAME-RULES §3) WHICH eligible authored action to
## commit — nothing else. It synthesizes the same Command shapes a player would send and
## never bypasses _apply_move/_apply_attack. Action SHAPE stays content in every case.
## actor_id -> Vector3, the leash/detection anchor. Scene-init/encounter-reset data
## only in the sense that register_ai unconditionally overwrites it on
## re-registration — at runtime it RE-ANCHORS to the stopped position on disengage
## (locked behavior, pre-gate fix pass: no universal return-to-spawn).
var _ai_spawn_position: Dictionary = {}
var _ai_state: Dictionary = {}  # actor_id -> "idle" | "active"
var _ai_tuning: Dictionary = {}  # actor_id -> {preferred_attack_distance, minimum_attack_distance, detection_radius, leash_radius}
## P29 repertoire: actor_id -> Array of {id, min_range, max_range, windup_ticks,
## is_terminal}. is_terminal is DERIVED at registration (the single largest max_range),
## never authored -- see _select_action for the half-open boundary convention it serves.
var _ai_repertoire: Dictionary = {}
## CLOSE-FRUSTRATION SELECTION (P29 Watcher pass). TWO LITERAL FACTS, one write site each.
## Episode consumption is DERIVED by comparing them and is never stored as a mutable flag:
## a flag would need a second write site to clear, and the moment those two writes drift
## apart the flag lies about the facts it summarises.
##
## _ai_last_in_close_band is the last tick the target was ACTUALLY inside the close band --
## refreshed EVERY tick while close, not stamped once on entry. That distinction is the
## whole mechanic: frustration must measure time since the actor was LAST able to be close,
## so a long melee exchange followed by being pushed out starts the clock at the moment it
## left, never at the moment it first arrived.
var _ai_last_in_close_band: Dictionary = {}   # actor_id -> tick (literal proximity fact)
var _ai_last_frustration_commit: Dictionary = {}  # actor_id -> tick (literal commitment fact)
## Renamed from _ai_last_survey_commit (P17 selector, behaviour-preserving): the fact is the
## consumption of a close-frustration EPISODE, which is family-neutral. Watcher spends it by
## committing a Survey; Fang spends it by committing a Burrow. The primitive is NOT broadened --
## it still means exactly "this actor already spent this failed-close episode", nothing more.
## The resolved close band itself, derived once at registration (the repertoire entry with
## the lowest min_range that does NOT itself require close frustration). Stored so the
## per-tick proximity test reuses band_contains() against the AUTHORED band rather than
## re-deriving "close range" from some other number -- one definition, one predicate.
var _ai_close_band: Dictionary = {}           # actor_id -> band Dictionary
## Below this separation the far-side direction is undefined and must not be chosen by float
## noise; the burrow falls back to the opposite of its own authored jump direction.
const BURROW_FAR_SIDE_EPSILON: float = 0.001
## The FIXED candidate set for emergence: the far-side direction rotated by these offsets, tried
## in this order. A fixed list, not a search -- no pathfinding, no navigation, and identical
## across identical runs by construction.
const BURROW_CANDIDATE_DEGREES: Array = [0.0, 60.0, -60.0, 120.0, -120.0, 180.0]

## COMBAT PARTICIPATION (P17 burrow). ONE narrow fact, and absence from this dict means
## PRESENT -- the ordinary case costs nothing to represent.
##
## RULED for v1: TARGETABLE and COLLIDABLE stay conceptually distinct dimensions but are
## PHYSICALLY FUSED here, because burrow needs both OFF together and splitting identical APIs
## before a consumer needs different answers would be speculative semantic surface. Split when
## the first real consumer requires them to disagree.
##
## Its whole reach is one line in _is_valid_target, which is the single predicate every hit
## scan, contact clamp and bump target selection already routes through.
var _combat_absent: Dictionary = {}
## BURROW lifecycle, advanced authoritatively in its own tick phase while ordinary AI is
## suspended. One record with a phase field: the lifecycle is strictly linear
## (jump -> underground -> reacquisition), so parallel dicts would only invite an inconsistent
## middle.
## P33 BOUNDED LOCAL AVOIDANCE. PER-ACTOR AI STATE whose lifetime ends with the floor, filed
## here with the rest of the _ai_* family and scoped SCOPE_FLOOR for the same reason they are --
## NOT promoted to floor-global state merely because a floor transition clears it.
##
## Only what the behaviour consumes. The committed SIDE is deliberately absent: it is derivable
## from the waypoint's position relative to the actor-to-target line, and a stored field that
## duplicates a derivable fact is a second truth waiting to disagree.
## BAND LATERAL TRACKING. The target's position as of this actor's last decision -- the only way
## to see that the target MOVED, since the sim stores positions and not velocities. Per-actor AI
## state, floor lifetime, filed with the rest of the _ai_* family.
var _ai_band_last_target: Dictionary = {}  # actor_id -> Vector3
var _ai_avoid_waypoint: Dictionary = {}  # actor_id -> Vector3, the committed local target
var _ai_avoid_deadline: Dictionary = {}  # actor_id -> int, absolute tick the commitment lapses
var _ai_burrow: Dictionary = {}                # actor_id -> resolved config
var _burrow: Dictionary = {}                   # actor_id -> live lifecycle record
var _next_burrow_tick: Dictionary = {}         # actor_id -> int, production pacing
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


## ---------------------------------------------------------------------------------
## M2 FLOOR/RUN ARCHITECTURE. One SimWorld per RUN; each floor is a new encounter space
## loaded into it. The sim is never recreated as a cleanup convenience and state is never
## copied between worlds — that would rebuild M4's job at M2 and break M3's reconnect gate.
## ---------------------------------------------------------------------------------

## The loaded floor's walkable law (game/sim/walkable_bounds.gd). null = no floor loaded, in
## which case every seam below is identity — which is exactly why the entire pre-M2 suite is
## unaffected by construction rather than by luck: nothing that never calls load_floor can
## observe bounds at all.
var _bounds: WalkableBounds = null
## actor_id -> true for the actors that SURVIVE a floor transition. Today the Envoy alone.
## Deliberately an explicit opt-in registry rather than an allegiance test: "the player
## persists" is a RUN decision, and an enemy that ever became allegiance "player" must not
## silently inherit immortality across floors.
var _run_persistent_actors: Dictionary = {}

## --- FLOOR LAYERS (M2 floor grammar) --------------------------------------------------
## FOUR INDEPENDENT LAYERS; no layer parents another. Rooms-plus-doors was falsified as the
## parent abstraction, so geometry, progression, encounters and interactions are siblings.
##
## THREE NOTIONS OF "WHERE MAY THIS ACTOR BE", still never merged:
##   1. FLOOR WALKABILITY (_bounds) -- every patch plus the apertures of OPEN connections.
##      Rebuilt whenever a connection changes, which is what makes a blocked gate an actual
##      wall rather than a picture of one.
##   2. TERRITORY (_actor_encounter) -- permanent for an enemy lifetime. Every floor enemy
##      belongs to one encounter site and never leaves its region, whatever the state. True for
##      AMBIENT rosters too: ambient means no ceremony and no player lock, NOT whole-floor
##      roaming, and this slice adds no roaming or pathfinding system.
##   3. CONFINEMENT (_active_confinement) -- TEMPORARY. While a confining encounter runs, the
##      Envoy is sealed into that site region as well.
## _bounds is never mutated to express (2) or (3). Legality resolves per actor at the one seam
## every authoritative displacement already funnels through (_legal_bounds_for).
var _connections: Dictionary = {}        # connection_id -> {aperture}
var _connection_open: Dictionary = {}    # connection_id -> bool  (THE gate state)
## switch_id -> {position, radius, mode, effects, hidden, spent}. A PERSISTENT hit target: it
## survives activation, unlike a breakable, which is the whole reason it is not one.
var _hit_switches: Dictionary = {}
## Static obstacle footprints, subtracted from every region this floor builds.
var _obstacle_rects: Array[Rect2] = []
## pad_id -> {rect, safe_ticks, active_ticks, phase_offset, damage, damage_type, was_active}.
## `was_active` exists only so a PHASE CHANGE can be announced once instead of every tick.
var _spike_pads: Dictionary = {}
## connection_id -> the solid line a CLOSED gate presents, derived from real patch geometry in
## _rebuild_regions. THE ONE AUTHORITATIVE ORIENTATION: presentation reads it back through
## gate_barrier() rather than deriving its own, so the barrier and the picture of it cannot be
## oriented differently (P34).
var _gate_barriers: Dictionary = {}
var _triggers: Dictionary = {}           # trigger_id -> {kind, region, source_id, once, effects}
var _triggers_fired: Dictionary = {}     # trigger_id -> true
var _trigger_condition_met: Dictionary = {}  # trigger_id -> bool, last tick's occupancy state (edge detection)
var _trigger_enabled: Dictionary = {}    # trigger_id -> bool; a dormant controller is not evaluated at all
## P34. STATIC SOLID SEGMENTS -- IMMUTABLE FLOOR DATA, handed over whole by the generator and
## never mutated after load. It is registered rather than derived here so the sim and
## presentation provably read the SAME canonical fact (FloorPlan.solid_segments), never two
## computations of it.
##
## STATE-SCOPE, HONESTLY: this is floor-lifetime data like _patch_rects, so it is classified
## SCOPE_FLOOR for lifetime -- but it is NOT a mutable collision mirror, and nothing writes to it
## after load_floor. Dynamic blocking (a closed gate) is NOT stored here at all: it derives from
## _connection_open, which is already the authoritative mutable state for exactly that question.
var _solid_segments: Array[Dictionary] = []
var _breakables: Dictionary = {}         # breakable_id -> {position, radius, durability}
var _encounters: Dictionary = {}         # encounter_id -> {region, role, confines_player}
var _encounter_bounds: Dictionary = {}   # encounter_id -> WalkableBounds, region CLIPPED to walkable
var _encounter_roster: Dictionary = {}   # encounter_id -> Array[int]
var _encounter_state: Dictionary = {}    # encounter_id -> "dormant" | "active" | "cleared"
var _actor_encounter: Dictionary = {}    # actor_id -> encounter_id (enemies only)
## All patch rects, kept so bounds can be rebuilt when a connection opens or closes.
var _patch_rects: Array[Rect2] = []
## The site currently sealing the Envoy, or -1. At most one: a second simultaneous seal has no
## authored consumer and would be speculative generality.
var _active_confinement: int = -1
## Set once every active Envoy stands on the authored exit region. Deliberately a FACT and an
## Event and nothing else: there is no next floor to descend to yet, and inventing one to give
## this somewhere to go would be building a system to satisfy a flag.
var _floor_complete: bool = false

const SCOPE_RUN: StringName = &"run"
const SCOPE_FLOOR: StringName = &"floor"
const SCOPE_RUN_ACTOR: StringName = &"run_actor"
const SCOPE_ACTOR_TRANSIENT: StringName = &"actor_transient"

## THE EXECUTABLE DEFINITION OF load_floor(), not documentation. load_floor ITERATES this
## map; it does not carry a second hand-written cleanup list. That kills the drift class
## where a scope table and a clear-list disagree and the table is the one nobody runs.
##
## tests/test_floor_scope.gd enumerates SimWorld's script variables and FAILS on any that is
## missing here, so new state must classify itself or break the build (§1.1's "every sim
## change touches both futures" made mechanical).
##
##   SCOPE_RUN             untouched by a floor transition
##   SCOPE_FLOOR           cleared wholesale — belongs to the departing encounter
##   SCOPE_RUN_ACTOR       actor-keyed; entries survive ONLY for _run_persistent_actors.
##                         Named for the RESTRICTION, not for "carried", so it cannot be
##                         misread as "this whole collection persists".
##   SCOPE_ACTOR_TRANSIENT actor-keyed; cleared for EVERY actor, run-persistent included
##
## FLOOR-TRANSITION LAW (Breon, 2026-08-28): a floor transition is an ENCOUNTER BOUNDARY.
## This is deliberately unlike burrow, which is temporary non-participation INSIDE one
## encounter. Durable run progression carries; transient combat effects do not. Burn
## specifically does NOT survive a floor change.
const STATE_SCOPES: Dictionary = {
	# --- RUN: content registration tables (keyed by content id, not actor) and the clock.
	"_weapons": SCOPE_RUN,
	"_melee_combo_profiles": SCOPE_RUN,
	"_melee_charge_profiles": SCOPE_RUN,
	"_melee_charge_threshold_ticks": SCOPE_RUN,
	"_melee_combo_reset_ticks": SCOPE_RUN,
	"_melee_input_buffer_ticks": SCOPE_RUN,
	"_matrix_families": SCOPE_RUN,
	"_matrix_weak_multiplier": SCOPE_RUN,
	"_matrix_resist_multiplier": SCOPE_RUN,
	"_status_config": SCOPE_RUN,
	"_status_priority": SCOPE_RUN,
	"_action_susceptibility": SCOPE_RUN,
	"_pressure_window_ticks": SCOPE_RUN,
	"_flinch_recovery_ticks": SCOPE_RUN,
	"_combat_rng": SCOPE_RUN,
	"_run_persistent_actors": SCOPE_RUN,
	# NEVER RESET: every absolute-tick deadline in this file is measured against it, so a
	# mid-run reset would make every stale deadline instantly satisfied.
	"tick_count": SCOPE_RUN,
	# Stays monotonic even though _projectiles clears, so an id is never reused within a
	# run and a run's event log stays unambiguous.
	"_next_projectile_id": SCOPE_RUN,

	# --- RUN_ACTOR: durable run state. Survives for the Envoy, pruned for floor actors.
	"entities": SCOPE_RUN_ACTOR,  # + explicitly repositioned to the new entry point
	"_move_speeds": SCOPE_RUN_ACTOR,
	"_facings": SCOPE_RUN_ACTOR,
	"_health": SCOPE_RUN_ACTOR,
	"_families": SCOPE_RUN_ACTOR,
	"_iframe_ticks_on_hit": SCOPE_RUN_ACTOR,
	"_combat_radius": SCOPE_RUN_ACTOR,
	"_allegiance": SCOPE_RUN_ACTOR,
	"_flinch_thresholds": SCOPE_RUN_ACTOR,
	"_equipped_weapon": SCOPE_RUN_ACTOR,
	"_weapon_loadouts": SCOPE_RUN_ACTOR,
	"_shields": SCOPE_RUN_ACTOR,
	# SHIELD RULING (Breon): load_floor must NOT refill the meter. The shield already has
	# exactly one recovery law — it regenerates whenever it is not raised (_apply_block) —
	# and a floor-load refill would be a second, competing authority. The METER carries at
	# whatever value ordinary play left it; only the transient state machine around it
	# resets below. Clearing this instead would be a stealth NERF, not neutrality:
	# _shield_meter.get(id, 0.0) defaults to zero.
	"_shield_meter": SCOPE_RUN_ACTOR,

	# --- ACTOR_TRANSIENT: combat state whose episode ended with the floor.
	"_status_instances": SCOPE_ACTOR_TRANSIENT,  # Burn does NOT cross a floor boundary
	"_iframe_ticks_remaining": SCOPE_ACTOR_TRANSIENT,
	# Cooldowns are absolute-tick deadlines against a clock that keeps running; a carried
	# value is either already expired or an arbitrary delay on the new floor's first swing.
	"_next_fire_tick": SCOPE_ACTOR_TRANSIENT,
	"_melee_hold": SCOPE_ACTOR_TRANSIENT,
	"_combo_index": SCOPE_ACTOR_TRANSIENT,
	"_combo_expire_tick": SCOPE_ACTOR_TRANSIENT,
	"_melee_buffered_press": SCOPE_ACTOR_TRANSIENT,
	# Shield INPUT/BREAK state (not the meter). Clearing restores the neutral machine for
	# free: _shield_state.get(id, "ready") and _shield_break_ticks_remaining.get(id, 0)
	# already default to exactly the values a fresh floor wants, so no re-priming rule —
	# and therefore no second shield authority — is introduced.
	"_shield_state": SCOPE_ACTOR_TRANSIENT,
	"_shield_break_ticks_remaining": SCOPE_ACTOR_TRANSIENT,
	"_block_held_prev": SCOPE_ACTOR_TRANSIENT,
	"_block_start_tick": SCOPE_ACTOR_TRANSIENT,
	"_shield_bump_ready_tick": SCOPE_ACTOR_TRANSIENT,
	"_bump_slides": SCOPE_ACTOR_TRANSIENT,
	"_parry_exposed_until_tick": SCOPE_ACTOR_TRANSIENT,
	"_parry_exposed_damage_multiplier": SCOPE_ACTOR_TRANSIENT,
	"_flinched_until_tick": SCOPE_ACTOR_TRANSIENT,
	"_pressure_contributions": SCOPE_ACTOR_TRANSIENT,
	"_combat_absent": SCOPE_ACTOR_TRANSIENT,
	"_ai_attack_start_tick": SCOPE_ACTOR_TRANSIENT,
	"_ai_attack_fire_tick": SCOPE_ACTOR_TRANSIENT,

	# --- FLOOR: belongs entirely to the departing encounter's actors or geometry.
	"_projectiles": SCOPE_FLOOR,  # in-flight shots always die with the floor
	"_contact_transmitted_pairs": SCOPE_FLOOR,  # keyed by actor PAIR, not actor
	"_ai_spawn_position": SCOPE_FLOOR,
	"_ai_state": SCOPE_FLOOR,
	"_ai_tuning": SCOPE_FLOOR,
	"_ai_repertoire": SCOPE_FLOOR,
	"_ai_last_in_close_band": SCOPE_FLOOR,
	"_ai_last_frustration_commit": SCOPE_FLOOR,
	"_ai_close_band": SCOPE_FLOOR,
	"_ai_band_last_target": SCOPE_FLOOR,
	"_ai_avoid_waypoint": SCOPE_FLOOR,
	"_ai_avoid_deadline": SCOPE_FLOOR,
	"_ai_burrow": SCOPE_FLOOR,
	"_burrow": SCOPE_FLOOR,
	"_next_burrow_tick": SCOPE_FLOOR,
	"_bounds": SCOPE_FLOOR,  # not a collection — assigned by load_floor, see below
	# Rooms and encounters describe ONE floor's geometry and encounter progress. All of it
	# dies with the floor, including which room owned which actor.
	"_connections": SCOPE_FLOOR,
	"_connection_open": SCOPE_FLOOR,
	"_hit_switches": SCOPE_FLOOR,
	"_obstacle_rects": SCOPE_FLOOR,
	"_spike_pads": SCOPE_FLOOR,
	"_gate_barriers": SCOPE_FLOOR,
	"_triggers": SCOPE_FLOOR,
	"_triggers_fired": SCOPE_FLOOR,
	"_trigger_condition_met": SCOPE_FLOOR,
	"_trigger_enabled": SCOPE_FLOOR,
	"_solid_segments": SCOPE_FLOOR,  # immutable after load; scoped for LIFETIME, not mutation
	"_breakables": SCOPE_FLOOR,
	"_encounters": SCOPE_FLOOR,
	"_encounter_bounds": SCOPE_FLOOR,
	"_encounter_roster": SCOPE_FLOOR,
	"_encounter_state": SCOPE_FLOOR,
	"_actor_encounter": SCOPE_FLOOR,
	"_patch_rects": SCOPE_FLOOR,         # Array — cleared by the same loop
	"_active_confinement": SCOPE_FLOOR,  # not a collection — reset by load_floor
	"_floor_complete": SCOPE_FLOOR,  # not a collection — reset by load_floor
}


## Marks an actor as surviving floor transitions. The driver calls this for the Envoy once,
## at run setup.
func mark_run_persistent(actor_id: int) -> void:
	_run_persistent_actors[actor_id] = true


## Installs a generated floor: retires the departing encounter, adopts the new walkable law,
## and moves the run-persistent actors to the new entry point.
##
## Takes PLAIN VALUES rather than a FloorPlan on purpose — sim/ stays ignorant of gen/, the
## same boundary ContentRegistrar draws for Resources (Prime Directive 1). The driver
## unpacks the plan; sim never imports the layer above it.
##
## The new roster is registered by the caller AFTER this returns, through the ordinary
## production path (ContentRegistrar.register_enemy_body/register_enemy_ai) — there is no
## parallel "generated enemy" registration path to drift from the hand-authored one.
func load_floor(bounds: WalkableBounds, entry_point: Vector3) -> void:
	for state_name: String in STATE_SCOPES:
		var scope: StringName = STATE_SCOPES[state_name]
		if scope == SCOPE_RUN:
			continue
		var value: Variant = get(state_name)
		if value is Array:
			(value as Array).clear()
			continue
		if not (value is Dictionary):
			continue  # non-collection floor state (_bounds, _active_confinement) set below
		var collection: Dictionary = value
		if scope == SCOPE_RUN_ACTOR:
			for actor_id: int in collection.keys():
				if not _run_persistent_actors.has(actor_id):
					collection.erase(actor_id)
		else:
			collection.clear()

	_bounds = bounds
	_active_confinement = -1  # not a Dictionary, so the clearing loop above cannot reach it
	_floor_complete = false   # likewise
	# Entry placement is not routed through add_entity's validation: these actors are
	# already registered, and the entry point's legality is the GENERATOR's contract
	# (test_depth_generator.gd asserts it), not something to re-decide per floor.
	for actor_id: int in _run_persistent_actors:
		entities[actor_id] = entry_point


## PHYSICAL LEGALITY, and nothing else: "where is this body FORBIDDEN to leave right now".
##
## THE SPLIT (ruled 2026-08-31). This predicate used to answer two different questions at once,
## and the collapse produced a real defect: an ambient Ooze shield-bumped toward open floor
## clamped against its own territory edge -- an INVISIBLE WALL in walkable ground, which reads
## to a player as an enemy wedged in a gap. A behavioural leash had been compiled into physical
## legality. The two are now separated:
##
##   PHYSICAL LEGALITY (here)   floor walkability + body extent, WALL, closed connection, and
##                              encounter confinement where it is genuinely hard. Hard-stops
##                              BOTH voluntary movement and forced displacement.
##   AI TERRITORY (_home_territory, consumed in _pursuit_direction)  where an actor voluntarily
##                              lives and where it returns. Never clamps a body.
##
## ONE GEOMETRY, TWO DOORS. Both read _encounter_bounds; neither duplicates it. That is the
## point -- behaviour and legality consult the same authored fact through different semantics.
##
## Returns null when no floor is loaded, keeping every seam an identity operation for a bare
## SimWorld -- the property that leaves the whole pre-M2 suite untouched.
func _legal_bounds_for(actor_id: int) -> WalkableBounds:
	if _actor_encounter.has(actor_id) and _hard_encounter_confinement_applies(actor_id):
		return _encounter_bounds.get(int(_actor_encounter[actor_id]), _bounds)
	if _active_confinement >= 0 and _run_persistent_actors.has(actor_id):
		return _encounter_bounds.get(_active_confinement, _bounds)
	return _bounds


## Does a HARD confinement rule currently bind this actor's body to its site?
##
## SEALING IS THE AUTHORITY, NOT ROLE (ruled 2026-09-03, after human play). This used to read
## "the site is not ambient", justified as a proxy that held because every non-ambient roster
## was either deferred until its encounter "activates and seals" or dead. It carried its own
## warning that role must never harden into a synonym for physical solidity, and a mechanical
## revisit trigger for the one way it was expected to break.
##
## FLOOR 2 BROKE IT A DIFFERENT WAY, which the trigger was too narrow to catch. An OPTIONAL,
## NON-SEALING encounter guards the shortcut it opens: it activates, but `confines_player` is
## false, so the player may walk out through an open doorway. The roster could not. Reproduced:
## the doorway measured LEGAL FOR THE PLAYER AND ILLEGAL FOR THE WATCHER at every point past
## Route A's edge -- an open door that one side of the fight is walled behind. The same walls
## then killed the Fang: it burrowed, every emergence candidate rings the player at the authored
## radius, the player was outside its confined bounds, all candidates were refused as illegal
## placement, and the fail-safe put it down underground. To the player it simply vanished.
##
## THE ASYMMETRY WAS THE BUG. If an encounter does not seal the player in, walling its roster in
## is not a fight -- it is a room the player can step out of and shoot into. So a roster is hard
## confined EXACTLY WHILE ITS OWN ENCOUNTER IS THE ONE ACTUALLY SEALING THE PLAYER, which is a
## live authoritative fact rather than a proxy for one. Everything else leashes (below).
func _hard_encounter_confinement_applies(actor_id: int) -> bool:
	var encounter_id: int = int(_actor_encounter[actor_id])
	if not _encounters.has(encounter_id):
		return false
	return _active_confinement == encounter_id


## THE BEHAVIOURAL DOOR onto the same geometry: where this actor walks back to, never a wall it
## meets. Null only for an actor with no site at all, or one whose site is currently sealing --
## a physically confined actor never consults a leash, because it cannot leave in the first place.
##
## EVERY UNSEALED SITE IS NOW A HOME, not only ambient ones. That follows from the ruling above:
## the moment a non-sealing roster stopped being walled in, it needed somewhere to return to, or
## it would drift wherever a chase happened to end. Ambient was never special here -- it was
## simply the only role that had reached this door.
func _home_territory(actor_id: int) -> WalkableBounds:
	if not _actor_encounter.has(actor_id):
		return null
	var encounter_id: int = int(_actor_encounter[actor_id])
	if not _encounters.has(encounter_id) or _hard_encounter_confinement_applies(actor_id):
		return null
	return _encounter_bounds.get(encounter_id, null)


## The nearest body-valid point inside home. Each authored home rect is INSET by the body radius
## -- so the result is somewhere the body actually fits, not merely a point inside the rect --
## then the position is clamped into it and the nearest candidate wins.
##
## TIE RULE: equal distances resolve on authored array order. That is a DETERMINISM RULE FOR
## DEGENERATE GEOMETRY so an identical state always yields an identical destination (M3 needs
## client and server to agree); it carries no gameplay meaning and expresses no route preference.
func _nearest_home_point(actor_id: int) -> Vector3:
	var home: WalkableBounds = _home_territory(actor_id)
	if home == null:
		return Vector3.ZERO
	var from: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var radius: float = _body_radius_for(actor_id)
	var best: Vector3 = Vector3.ZERO
	var best_distance: float = INF
	# INSET BY RADIUS **PLUS THE ARRIVAL TOLERANCE**. Insetting by the radius alone puts the
	# destination exactly on the last fitting line, so an actor that stops "close enough" stops
	# just OUTSIDE home and never arrives. The margin is what makes arrival and being-home the
	# same event rather than two that miss each other by a hair.
	var margin: float = radius + _AVOID_ARRIVAL_TOLERANCE
	for rect: Rect2 in home.rects:
		var min_x: float = rect.position.x + margin
		var max_x: float = rect.end.x - margin
		var min_z: float = rect.position.y + margin
		var max_z: float = rect.end.y - margin
		if min_x > max_x or min_z > max_z:
			continue  # this rect cannot hold this body at all
		var candidate := Vector3(clampf(from.x, min_x, max_x), from.y, clampf(from.z, min_z, max_z))
		var distance: float = candidate.distance_squared_to(from)
		if distance < best_distance - 0.000001:  # strict: ties keep the earlier rect
			best_distance = distance
			best = candidate
	return best


## THE AUTHORITATIVE BODY EXTENT for movement legality (ruled 2026-08-29). combat_radius is
## already the sim's one physical-body notion -- Burn's contact-spread and the projectile
## Minkowski sweep both resolve against it -- so legality reads the SAME number rather than
## introducing a second, silently divergent footprint. An actor with no registered body
## (0.0) keeps point legality exactly, which is what leaves the pre-M2 suite untouched.
func _body_radius_for(actor_id: int) -> float:
	return _combat_radius.get(actor_id, 0.0)


## Displacement seam (see WalkableBounds.clamp_step). Every authoritative write to entities[]
## that MOVES an already-placed actor routes through here; the audit of those sites lives in
## tests/test_floor_bounds.gd, which drives each one at a wall AND at a sealed gate.
##
## Body extent enters HERE, at the funnel, which is why making legality body-aware touched no
## call site: all eight displacement seams already asked this one function where they may go.
func _clamp_to_bounds(actor_id: int, from: Vector3, to: Vector3) -> Vector3:
	var region: WalkableBounds = _legal_bounds_for(actor_id)
	return to if region == null else region.clamp_step(from, to, _body_radius_for(actor_id))


## PLACEMENT seam counterpart -- same per-actor region AND same body extent as the clamp, so a
## burrowing Fang can never surface outside the territory that owns it, and can never surface
## somewhere its body does not fit.
func _point_is_legal_for(actor_id: int, point: Vector3) -> bool:
	var region: WalkableBounds = _legal_bounds_for(actor_id)
	return true if region == null else region.fits(point, _body_radius_for(actor_id))


# --- FLOOR REGISTRATION (the driver unpacks a FloorPlan; sim never imports gen/) ---------

func register_patches(rects: Array[Rect2]) -> void:
	_patch_rects = rects.duplicate()
	_rebuild_regions()


## Static obstacles, as EXCLUSIONS from walkable space. Registered separately from patches
## because they are a subtraction rather than an addition -- and kept here so every rebuild
## re-applies them, instead of surviving only in whatever bounds happened to be built first.
## A timed hazard. Its damage is ENVIRONMENT-sourced and travels the ordinary damage pipeline,
## so a shield absorbs it, repeated ticks can break that shield, and i-frames gate repeats --
## all of which is existing law rather than anything this hazard invents.
func register_spike_pad(pad_id: int, rect: Rect2, safe_ticks: int, active_ticks: int, phase_offset_ticks: int, damage: float, damage_type: StringName) -> void:
	_spike_pads[pad_id] = {
		"rect": rect, "safe_ticks": maxi(1, safe_ticks), "active_ticks": maxi(1, active_ticks),
		"phase_offset": phase_offset_ticks, "damage": damage, "damage_type": damage_type,
		"was_active": false,
	}


func register_obstacles(rects: Array[Rect2]) -> void:
	_obstacle_rects = rects.duplicate()
	_rebuild_regions()


## A connection owns AVAILABILITY and nothing else -- it is never told which controller changed
## it. That is the point of the law: switches, objectives, encounter clears and one-way
## commitment all reach it through the same effect and stay indistinguishable from here.
func register_connection(connection_id: int, aperture: Rect2, starts_open: bool) -> void:
	_connections[connection_id] = {"aperture": aperture}
	_connection_open[connection_id] = starts_open
	_rebuild_regions()


func register_trigger(trigger_id: int, kind: StringName, region: Rect2, source_id: int, once: bool, effects: Array, starts_enabled: bool = true) -> void:
	_triggers[trigger_id] = {"kind": kind, "region": region, "source_id": source_id, "once": once, "effects": effects}
	_trigger_enabled[trigger_id] = starts_enabled





## A BREAKABLE IS NOT A COMBATANT (see the pre-code inheritance audit, ROADMAP). It is
## deliberately absent from _families / _health / _combat_radius, so it enters none of the six
## scans a combatant would join -- no shield bump, no lunge clamp, no burrow occupancy, no Burn
## contact-spread, no i-frames, no flinch, no pressure, no knockback, no status -- and crucially
## it is never a valid target for an enemy. It shares only DETECTION with melee and projectiles;
## resolution forks immediately into _resolve_hit_on_breakable.
## Hands the sim the floor's canonical boundary. No derivation happens here on purpose: one
## computation, in FloorPlan, read by both consumers.
func register_solid_segments(segments: Array[Dictionary]) -> void:
	_solid_segments = segments


## `blocking_rect` (2026-09-03): an EMPTY rect keeps the original behaviour exactly -- a target
## and nothing more. A real rect means this prop OCCUPIES that ground until destroyed, using the
## same exclusion representation a static obstacle uses. "Solid until broken" is therefore the
## obstacle law with an end date, not a second notion of impassable.
func register_breakable(breakable_id: int, position: Vector3, radius: float, durability: float, blocking_rect: Rect2 = Rect2()) -> void:
	_breakables[breakable_id] = {
		"position": position, "radius": radius, "durability": durability,
		"blocking_rect": blocking_rect,
	}


## A PERSISTENT hit target. Shares only DETECTION with the melee cone and the projectile sweep,
## exactly as a breakable does -- it is not a combatant, it has no health, and it is never a
## valid target for enemy AI.
func register_hit_switch(switch_id: int, position: Vector3, radius: float, mode: StringName, effects: Array, starts_hidden: bool = false) -> void:
	_hit_switches[switch_id] = {
		"position": position, "radius": radius, "mode": mode,
		"effects": effects, "hidden": starts_hidden, "spent": false,
	}


## TERRITORY IS A UNION OF REGIONS, never one rect (ruled 2026-08-29). Confinement itself was
## validated and is kept; what human play falsified was the accidental assumption that a
## territory equals exactly one WalkablePatch, which read as an ambient enemy "stuck on the
## corner" the moment its quarry stepped across a patch seam it was authored to inhabit.
## Widening a territory is now an AUTHORING act, not a repeal of confinement -- and emphatically
## not floor-wide roaming, which stays out along with any pathfinding.
func register_encounter(encounter_id: int, regions: Array[Rect2], role: StringName, confines_player: bool, spawn_at_floor_load: bool = true) -> void:
	_encounters[encounter_id] = {
		"regions": regions, "role": role, "confines_player": confines_player,
		"spawn_at_floor_load": spawn_at_floor_load,
	}
	_encounter_roster[encounter_id] = []
	# AMBIENT sites never seal, so they get no dormant/active/cleared life at all -- their
	# roster simply exists and fights if you walk through. Giving them a state machine they
	# never advance would invite a future reader to believe ambient encounters can be cleared.
	if role != &"ambient":
		_encounter_state[encounter_id] = "dormant"
	_rebuild_regions()


## Binds an actor to the site that owns it for the rest of its life. Refuses LOUDLY if the actor
## is not standing in that territory -- the same placement law as add_entity, for the same
## reason: silently accepting it would leave an actor permanently clamped against a region it is
## not inside, which presents as "the enemy is stuck" rather than as the content bug it is.
func assign_actor_encounter(actor_id: int, encounter_id: int) -> bool:
	if not _encounters.has(encounter_id):
		push_error("SimWorld.assign_actor_encounter: unknown encounter %d" % encounter_id)
		return false
	var territory: WalkableBounds = _encounter_bounds[encounter_id]
	# BODY-AWARE, like every other placement check: a roster member whose body does not fit
	# inside its own territory would spend its life clamped against the boundary, which is
	# exactly the "the enemy is stuck" presentation this refusal exists to prevent.
	if not territory.fits(entities.get(actor_id, Vector3.ZERO), _body_radius_for(actor_id)):
		push_error("SimWorld.assign_actor_encounter: actor %d at %s is outside encounter %d, or its body does not fit inside it" % [actor_id, entities.get(actor_id, Vector3.ZERO), encounter_id])
		return false
	_actor_encounter[actor_id] = encounter_id
	var roster: Array = _encounter_roster[encounter_id]
	if not roster.has(actor_id):
		roster.append(actor_id)
	# A DEFERRED roster is registered up front but does not PARTICIPATE until its site is
	# activated: alive, untargetable, and not drawn. That is precisely what _combat_absent
	# already means (burrow authored it), so this reuses the one predicate every hit scan,
	# contact clamp and bump selection already funnels through rather than inventing a second
	# notion of "present". It is also what gives the party button a roster that ARRIVES.
	if not bool(_encounters[encounter_id]["spawn_at_floor_load"]):
		_combat_absent[actor_id] = true
	return true


## Recomputes both legality views. A BLOCKED connection contributes no aperture, which removes
## the passage beyond a threshold while each patch's own rect still covers its half of it -- so
## closing a gate never shrinks a space and never snaps an actor off a doorway.
##
## Encounter territories are the site's region CLIPPED TO WALKABLE GROUND, not the raw rect: a
## region is an authoring convenience that may overhang a void, and confining an actor to a raw
## rectangle would let it walk on nothing.
func _rebuild_regions() -> void:
	# Barriers depend on patch geometry, so they are recomputed wherever regions are -- both
	# registration orders (patches then connections, or the reverse) end up with the same answer.
	for connection_id in _connections:
		_gate_barriers[connection_id] = _derive_gate_barrier(_connections[connection_id]["aperture"])
	var open_rects: Array[Rect2] = _patch_rects.duplicate()
	for connection_id in _connections:
		if bool(_connection_open.get(connection_id, false)):
			open_rects.append(_connections[connection_id]["aperture"])
	_bounds = WalkableBounds.new(open_rects, _obstacle_rects)
	for encounter_id in _encounters:
		var regions: Array = _encounters[encounter_id]["regions"]
		var clipped: Array[Rect2] = []
		for region: Rect2 in regions:
			for rect in open_rects:
				var shared: Rect2 = rect.intersection(region)
				if shared.get_area() > 0.0:
					clipped.append(shared)
		# Territories carry the exclusions too: an obstacle inside a fight is solid for the
		# roster as much as for the player, and a home that ignored them would send an actor
		# walking back into a column.
		_encounter_bounds[encounter_id] = WalkableBounds.new(clipped, _obstacle_rects)


## Read-only participation query, so the driver can mirror a deferred roster without poking a
## private field (same precedent as debug_describe_melee_state).
func debug_is_combat_absent(actor_id: int) -> bool:
	return _combat_absent.has(actor_id)


func debug_describe_floor() -> Dictionary:
	return {
		"connections_open": _connection_open.duplicate(),
		"encounters": _encounter_state.duplicate(),
		"active_confinement": _active_confinement,
		"breakables": _breakables.size(), "floor_complete": _floor_complete,
	}


# --- CONTROLLERS: trigger -> effect -----------------------------------------------------

## Advances region triggers and every encounter by one tick. Runs inside tick() BEFORE AI
## decides, so a commitment boundary or an activation takes hold on the same tick it is earned.
func _advance_floor_state() -> Array[Event]:
	var events: Array[Event] = []
	var trigger_ids: Array = _triggers.keys()
	trigger_ids.sort()  # autonomous-phase law: deterministic order, never Dictionary order
	for trigger_id: int in trigger_ids:
		var trigger: Dictionary = _triggers[trigger_id]
		var kind: StringName = trigger["kind"]
		if kind != &"region_entered" and kind != &"group_occupancy":
			continue
		# A DORMANT controller is skipped ENTIRELY rather than evaluated-and-ignored, so it
		# cannot bank an occupancy edge while it waits. That is what makes the plate under the
		# crate fire when it is revealed under an Envoy already standing on it.
		if not bool(_trigger_enabled.get(trigger_id, true)):
			continue
		var met: bool = _occupancy_condition_met(trigger)
		# EDGE-TRIGGERED, FALSE -> TRUE. A plate everyone is still standing on must not re-fire
		# every tick; it fires when the condition BECOMES true and stays quiet until it lapses.
		# Tracked for one-shot triggers too, so the two notions never disagree.
		var was_met: bool = bool(_trigger_condition_met.get(trigger_id, false))
		_trigger_condition_met[trigger_id] = met
		if not met or was_met or _triggers_fired.has(trigger_id):
			continue
		events.append_array(_fire_trigger(trigger_id))
	events.append_array(_advance_encounters())
	return events


## OCCUPANCY IS AN ANCHOR QUESTION, NOT A BODY QUESTION (ruled). "Is this actor standing on
## this plate" is deliberately NOT the legality predicate: a body merely grazing the edge of a
## plate is not standing on it, and merging the two would let a wide actor operate a plate it
## has not stepped onto. Both consumers route through WalkableBounds.contains, the one shared
## INCLUSIVE helper, so Rect2.has_point's exclusive far edge can never re-enter here.
##
##   region_entered   ANY living party member on the region
##   group_occupancy  ALL_ACTIVE_ENVOYS_OCCUPY_REGION (below)
func _occupancy_condition_met(trigger: Dictionary) -> bool:
	var region: Rect2 = trigger["region"]
	if trigger["kind"] == &"group_occupancy":
		return all_active_envoys_occupy(region)
	for actor_id: int in _run_persistent_actors:
		if _health.get(actor_id, 0.0) <= 0.0:
			continue
		var position: Vector3 = entities.get(actor_id, Vector3.ZERO)
		if WalkableBounds.contains(region, position.x, position.z):
			return true
	return false


## ALL_ACTIVE_ENVOYS_OCCUPY_REGION -- ONE condition, TWO consumers (the party plate and the
## floor exit). Committing to a fight and finishing a floor ask the same question, so they share
## this and never grow a second copy of the occupancy math.
##
## THE DENOMINATOR IS THE EXPEDITION, NOT THE ROOM. Derived from _run_persistent_actors -- the
## active party roster -- rather than from an authored count or "whoever is nearby", because a
## count would let a subset commit everyone while a teammate is still outside. Solo M2 resolves
## to exactly one Envoy with no special case, and M3 changes that roster's MEMBERSHIP without
## touching this condition.
func all_active_envoys_occupy(region: Rect2) -> bool:
	var living: int = 0
	for actor_id: int in _run_persistent_actors:
		if _health.get(actor_id, 0.0) <= 0.0:
			continue
		living += 1
		var position: Vector3 = entities.get(actor_id, Vector3.ZERO)
		if not WalkableBounds.contains(region, position.x, position.z):
			return false
	return living > 0


## Applies one trigger's effects ATOMICALLY -- the whole ordered list lands within this call, so
## a trigger can never be observed half-fired. This is where the party button's "seal the rear,
## open the way forward, wake the roster" becomes one indivisible consequence instead of three
## systems that happen to agree.
func _fire_trigger(trigger_id: int) -> Array[Event]:
	var trigger: Dictionary = _triggers[trigger_id]
	if bool(trigger["once"]):
		_triggers_fired[trigger_id] = true
	var events: Array[Event] = [Event.new(tick_count, "floor_trigger_fired", {
		"trigger_id": trigger_id, "kind": String(trigger["kind"]), "effects": trigger["effects"].size(),
	})]
	for effect in trigger["effects"]:
		events.append_array(_apply_floor_effect(effect))
	return events


## THE ONE WRITER of connection availability. Extracted when TOGGLE joined OPEN and BLOCK
## (2026-09-03): three effects writing the same state through three copies of "assign, rebuild,
## announce" is exactly how one of them quietly forgets to rebuild.
##
## A no-op change announces nothing, so a gate already open cannot emit a second opening.
func _set_connection_open(connection_id: int, opened: bool) -> Array[Event]:
	if bool(_connection_open[connection_id]) == opened:
		return []
	_connection_open[connection_id] = opened
	_rebuild_regions()
	return [Event.new(tick_count, "connection_changed", {"connection_id": connection_id, "open": opened})]


func _apply_floor_effect(effect: Dictionary) -> Array[Event]:
	var kind: StringName = effect["kind"]
	var target_id: int = int(effect["target_id"])
	match String(kind):
		"open_connection", "block_connection":
			if not _connection_open.has(target_id):
				return []
			return _set_connection_open(target_id, kind == &"open_connection")
		"activate_encounter":
			return _activate_encounter(target_id)
		"enable_trigger":
			if not _triggers.has(target_id) or bool(_trigger_enabled.get(target_id, true)):
				return []
			_trigger_enabled[target_id] = true
			return [Event.new(tick_count, "floor_trigger_enabled", {"trigger_id": target_id})]
		"toggle_connection":
			if not _connection_open.has(target_id):
				return []
			return _set_connection_open(target_id, not bool(_connection_open[target_id]))
		"reveal_switch":
			if not _hit_switches.has(target_id) or not bool(_hit_switches[target_id]["hidden"]):
				return []
			_hit_switches[target_id]["hidden"] = false
			return [Event.new(tick_count, "switch_revealed", {"switch_id": target_id})]
		"complete_floor":
			if _floor_complete:
				return []
			_floor_complete = true
			return [Event.new(tick_count, "floor_complete", {})]
	push_warning("SimWorld: unknown floor effect kind '%s'" % kind)
	return []


## ACTIVATION IS AUTHORED. There is no "the player entered the region, therefore fight" rule
## anywhere in this file -- an encounter starts because an effect said so. That generalises the
## one thing the last playtest positively liked: the explicit button-then-encounter beat.
## Activates an encounter through the ORDINARY path, for tests and tools that need a fight to
## be genuinely live rather than merely registered. Not a second activation route: it calls the
## same function an authored effect does, so seal state, roster arrival and events are identical.
##
## It exists because sealing became a LIVE FACT rather than a property of role (2026-09-03):
## a registered-but-dormant encounter seals nobody, and a fixture that wants a seal must now say
## so, exactly as a floor must.
func debug_activate_encounter(encounter_id: int) -> Array[Event]:
	return _activate_encounter(encounter_id)


func _activate_encounter(encounter_id: int) -> Array[Event]:
	if String(_encounter_state.get(encounter_id, "")) != "dormant":
		return []
	_encounter_state[encounter_id] = "active"
	if bool(_encounters[encounter_id]["confines_player"]):
		_active_confinement = encounter_id
	var arrived: Array = []
	for member_id: int in _encounter_roster[encounter_id]:
		if _health.get(member_id, 0.0) <= 0.0:
			continue
		# A deferred roster becomes PRESENT here -- the same participation flip burrow uses on
		# emergence, so presentation already knows how to mirror it.
		_combat_absent.erase(member_id)
		debug_set_ai_active(member_id)
		arrived.append(member_id)
	return [Event.new(tick_count, "encounter_activated", {
		"encounter_id": encounter_id, "roster": _encounter_roster[encounter_id].size(),
		"actor_ids": arrived,
	})]


## Only the CLEAR half runs autonomously; activation is always an effect.
func _advance_encounters() -> Array[Event]:
	var events: Array[Event] = []
	var encounter_ids: Array = _encounter_state.keys()
	encounter_ids.sort()
	for encounter_id: int in encounter_ids:
		if String(_encounter_state[encounter_id]) != "active":
			continue
		# A COMBAT-ABSENT actor (a burrowed Fang) is ALIVE, so it still counts. Keying the clear
		# on _health rather than on participation is what makes that true with no special case:
		# burrow is temporary non-participation INSIDE an encounter, never leaving one.
		var roster_alive: bool = false
		for member_id: int in _encounter_roster[encounter_id]:
			if _health.get(member_id, 0.0) > 0.0:
				roster_alive = true
				break
		if roster_alive:
			continue
		_encounter_state[encounter_id] = "cleared"
		if _active_confinement == encounter_id:
			_active_confinement = -1
		events.append(Event.new(tick_count, "encounter_cleared", {"encounter_id": encounter_id}))
		events.append_array(_fire_triggers_watching(&"encounter_cleared", encounter_id))
	return events


## Fires every not-yet-spent trigger watching a given source. The source never knows its
## watchers exist -- an encounter does not open doors, it merely finishes.
func _fire_triggers_watching(kind: StringName, source_id: int) -> Array[Event]:
	var events: Array[Event] = []
	var trigger_ids: Array = _triggers.keys()
	trigger_ids.sort()
	for trigger_id: int in trigger_ids:
		var trigger: Dictionary = _triggers[trigger_id]
		if trigger["kind"] != kind or int(trigger["source_id"]) != source_id:
			continue
		if _triggers_fired.has(trigger_id):
			continue
		events.append_array(_fire_trigger(trigger_id))
	return events


## BREAKABLE RESOLUTION -- the fork point. Detection is shared with the melee cone and the
## projectile sweep; everything past this line is deliberately NOT the combatant pipeline. No
## i-frames, no matrix, no shield, no parry, no pressure, no flinch, no knockback, no status,
## no death Event: a prop takes direct durability damage and either survives or is gone.
func _resolve_hit_on_breakable(attacker_id: int, breakable_id: int, damage: float) -> Array[Event]:
	if not _breakables.has(breakable_id):
		return []
	var breakable: Dictionary = _breakables[breakable_id]
	breakable["durability"] = float(breakable["durability"]) - damage
	var events: Array[Event] = [Event.new(tick_count, "breakable_hit", {
		"attacker_id": attacker_id, "breakable_id": breakable_id,
		"durability": breakable["durability"],
	})]
	if float(breakable["durability"]) > 0.0:
		return events
	var vacated: Rect2 = breakable.get("blocking_rect", Rect2())
	_breakables.erase(breakable_id)
	# THE GROUND COMES BACK, and every gameplay fact the prop owned updates at once: the union
	# regains the space and territories are re-clipped, so movement and pursuit change together
	# rather than one lagging behind a mesh that has already vanished. Shots need no step here --
	# they stopped at the prop's own detection, which disappears with it.
	if vacated.get_area() > 0.0:
		var remaining: Array[Rect2] = []
		for rect: Rect2 in _obstacle_rects:
			if rect != vacated:
				remaining.append(rect)
		_obstacle_rects = remaining
		_rebuild_regions()
	events.append(Event.new(tick_count, "breakable_destroyed", {"breakable_id": breakable_id}))
	events.append_array(_fire_triggers_watching(&"breakable_destroyed", breakable_id))
	return events


## Breakables inside a melee swing's cone. Reuses the SAME reach and cone test the combatant
## scan applies, against a second small collection -- not a duplicated sweep.
## AN ACCEPTED ACTIVATION. Returns the events it caused, or nothing when the hit is ignored.
##
## ONE PROJECTILE IS ONE ACTIVATION, structurally rather than by cooldown: a shot TERMINATES on
## the prop it meets, so it cannot register twice, and no multi-projectile weapon exists in the
## model at all -- there are no pellets, and _spawn_projectile emits exactly one shot per attack.
## A melee swing resolves its cone once. So the "burst flips the door open, shut, open" hazard
## has no source today, and the safeguard is the existing contact identity rather than a new
## repeat-hit framework. IF a spread weapon is ever authored, THIS is the comment that has to be
## revisited: the guarantee lives in one-contact-per-attack, not in the switch.
func _resolve_hit_on_switch(switch_id: int) -> Array[Event]:
	if not _hit_switches.has(switch_id):
		return []
	var switch: Dictionary = _hit_switches[switch_id]
	if bool(switch["hidden"]):
		return []  # unreachable: a hidden switch is not offered to any hit scan
	if switch["mode"] == &"one_shot" and bool(switch["spent"]):
		return []
	switch["spent"] = true
	var events: Array[Event] = [Event.new(tick_count, "switch_activated", {
		"switch_id": switch_id, "mode": switch["mode"],
	})]
	for authored_effect: Dictionary in switch["effects"]:
		events.append_array(_apply_floor_effect(authored_effect))
	events.append_array(_fire_triggers_watching(&"switch_activated", switch_id))
	return events


## Destroys a breakable through the ORDINARY resolution path, for tests and tools that need a
## prop gone without staging a firing line to it. Not a second destruction route: the same
## function a hit calls, so reveals, effects, vacated ground and events are all identical.
func debug_destroy_breakable(breakable_id: int) -> Array[Event]:
	if not _breakables.has(breakable_id):
		return []
	return _resolve_hit_on_breakable(-1, breakable_id, float(_breakables[breakable_id]["durability"]))


## Presses a switch through the ORDINARY activation path, for the same reason.
func debug_activate_hit_switch(switch_id: int) -> Array[Event]:
	return _resolve_hit_on_switch(switch_id)


## Every VISIBLE switch the melee cone covers. Hidden ones are absent from the scan entirely, so
## concealment is physical rather than a flag consulted after the fact.
func _switches_in_cone(attacker_position: Vector3, resolved_aim: Vector3, weapon: Dictionary) -> Array:
	var hit_ids: Array = []
	var switch_ids: Array = _hit_switches.keys()
	switch_ids.sort()
	for switch_id: int in switch_ids:
		var switch: Dictionary = _hit_switches[switch_id]
		if bool(switch["hidden"]):
			continue
		var offset: Vector3 = switch["position"] - attacker_position
		offset.y = 0.0
		var reach: float = float(weapon.reach) + float(switch["radius"])
		if offset.length() > reach:
			continue
		if offset.length() > 0.001 and rad_to_deg(offset.normalized().angle_to(resolved_aim)) > float(weapon.arc_degrees) * 0.5:
			continue
		hit_ids.append(switch_id)
	return hit_ids


## Earliest VISIBLE switch along a projectile's travel segment, as {switch_id, t}, or empty.
func _find_earliest_switch_hit(start: Vector3, end: Vector3, hit_radius: float) -> Dictionary:
	var best: Dictionary = {}
	var switch_ids: Array = _hit_switches.keys()
	switch_ids.sort()
	for switch_id: int in switch_ids:
		var switch: Dictionary = _hit_switches[switch_id]
		if bool(switch["hidden"]):
			continue
		var t: float = _segment_reaches_point(start, end, switch["position"], float(switch["radius"]) + hit_radius)
		if t < 0.0:
			continue
		if best.is_empty() or t < float(best["t"]):
			best = {"switch_id": switch_id, "t": t}
	return best


## Parametric t at which the swept shot first comes within `radius` of a point, or -1.
func _segment_reaches_point(start: Vector3, end: Vector3, point: Vector3, radius: float) -> float:
	var travel: Vector3 = end - start
	travel.y = 0.0
	var to_point: Vector3 = point - start
	to_point.y = 0.0
	var length_squared: float = travel.length_squared()
	var t: float = 0.0 if length_squared < 0.000001 else clampf(to_point.dot(travel) / length_squared, 0.0, 1.0)
	var nearest: Vector3 = start + travel * t
	var offset: Vector3 = point - nearest
	offset.y = 0.0
	return t if offset.length() <= radius else -1.0


func _breakables_in_cone(attacker_position: Vector3, resolved_aim: Vector3, weapon: Dictionary) -> Array:
	var hit_ids: Array = []
	var breakable_ids: Array = _breakables.keys()
	breakable_ids.sort()
	for breakable_id: int in breakable_ids:
		var breakable: Dictionary = _breakables[breakable_id]
		var offset: Vector3 = breakable["position"] - attacker_position
		offset.y = 0.0
		var distance_sq: float = offset.length_squared()
		# Minkowski, exactly as the projectile sweep does it: reach plus the prop's own body,
		# so a wide crate is hittable from where it visually is.
		var reach: float = float(weapon.reach) + float(breakable["radius"])
		if distance_sq > reach * reach:
			continue
		if distance_sq > _FACING_EPSILON_SQ:
			var normalized_offset: Vector3 = offset / sqrt(distance_sq)
			if resolved_aim.dot(normalized_offset) < weapon.cone_threshold:
				continue
		hit_ids.append(breakable_id)
	return hit_ids


## Earliest SOLID WORLD obstruction along this tick's travel segment, as {t}, or empty.
##
## SIM AUTHORITY ONLY: axis-aligned segment maths against canonical floor data. No physics
## query, no raycast, no collision shape, no NavigationServer -- the same fence _actors_overlap
## already sits behind.
##
## Static segments and CLOSED GATES are checked together because a projectile does not care which
## kind of solid it met; only their SOURCES differ, and a gate's solidity is read live from
## _connection_open rather than stored anywhere.
##
## THE SEGMENT'S ENDS ARE NOT INFLATED by hit_radius, deliberately. Inflating them would let a
## shot threading a doorway be stopped by the jamb it visibly cleared; the failure that remains
## is a shot squeaking through a hair's gap, which is the kinder way to be wrong.
func _find_earliest_solid_hit(start: Vector3, end: Vector3, hit_radius: float) -> Dictionary:
	var best_t: float = INF
	for segment in _solid_segments:
		var t: float = _segment_crossing(start, end, segment, hit_radius)
		if t >= 0.0 and t < best_t:
			best_t = t
	for connection_id in _connections:
		if bool(_connection_open.get(connection_id, false)):
			continue  # an open route obstructs nothing
		var t: float = _segment_crossing(start, end, _gate_barriers[connection_id], hit_radius)
		if t >= 0.0 and t < best_t:
			best_t = t
	return {} if best_t == INF else {"t": best_t}


## A CLOSED GATE IS A SOLID LINE ACROSS THE DIRECTION OF TRAVEL.
##
## DERIVED FROM THE PATCHES THE APERTURE JOINS, NOT FROM ANY SHAPE (ruled 2026-09-02). The
## previous rule inferred travel from the APERTURE'S proportions -- true for a corridor-shaped
## aperture, FALSE for a doorway-shaped one wider than it is deep. Floor 2 authored exactly
## that, so the barrier was laid ALONG the direction of travel: a shot fired at the shut gate
## ran parallel to its own barrier and passed straight through, while presentation drew the box
## across the opening. The picture and the rule disagreed, which is what P34 forbids.
##
## NO SHAPE RULE CAN WORK, and the first attempt at this fix proved it by failing the same way:
## measuring the GAP instead of the aperture is still a shape heuristic, and a wide doorway
## between narrowly-separated rooms has a gap that is longer ALONG travel than across it. Only
## the patches themselves carry the answer. Travel runs along the axis that SEPARATES them, and
## the barrier lies across that axis.
func _derive_gate_barrier(aperture: Rect2) -> Dictionary:
	var touched: Array[Rect2] = []
	for rect in _patch_rects:
		if rect.intersection(aperture).get_area() > 0.0:
			touched.append(rect)
	for i in touched.size():
		for j in range(i + 1, touched.size()):
			var a: Rect2 = touched[i]
			var b: Rect2 = touched[j]
			var apart_on_x: bool = a.end.x < b.position.x or b.end.x < a.position.x
			var apart_on_z: bool = a.end.y < b.position.y or b.end.y < a.position.y
			# Exactly one axis may carry the gap; both would mean a diagonal relationship the
			# grammar has no meaning for, and neither means they touch (see the fallback).
			if apart_on_x == apart_on_z:
				continue
			if apart_on_z:
				return {"axis": &"z", "at": (minf(a.end.y, b.end.y) + maxf(a.position.y, b.position.y)) * 0.5,
					"min": aperture.position.x, "max": aperture.end.x}
			return {"axis": &"x", "at": (minf(a.end.x, b.end.x) + maxf(a.position.x, b.position.x)) * 0.5,
				"min": aperture.position.y, "max": aperture.end.y}
	# NO SEPARATED PAIR: either the patches touch -- in which case a closed gate separates nothing
	# anyway and FloorPlan._reject_bypassable_gates refuses to author it -- or no patches are
	# registered at all, which is a bare unit fixture. Preserved verbatim as the pre-2026-09-02
	# rule so those fixtures keep their exact behaviour rather than silently losing their barrier.
	if aperture.size.y >= aperture.size.x:
		return {"axis": &"z", "at": aperture.position.y + aperture.size.y * 0.5,
			"min": aperture.position.x, "max": aperture.end.x}
	return {"axis": &"x", "at": aperture.position.x + aperture.size.x * 0.5,
		"min": aperture.position.y, "max": aperture.end.y}


## THE ORIENTATION PRESENTATION MUST DRAW. Read back rather than re-derived, so a gate's picture
## is a projection of the rule instead of a second opinion about it.
func gate_barrier(connection_id: int) -> Dictionary:
	return _gate_barriers.get(connection_id, {})


## Parametric t in [0,1] at which the projectile's leading edge meets this segment, or -1.
func _segment_crossing(start: Vector3, end: Vector3, segment: Dictionary, hit_radius: float) -> float:
	var vertical: bool = segment["axis"] == &"x"
	var from_axis: float = start.x if vertical else start.z
	var to_axis: float = end.x if vertical else end.z
	var delta: float = to_axis - from_axis
	if absf(delta) <= 0.000001:
		return -1.0  # travelling parallel to this boundary: it is not in the way
	var at: float = float(segment["at"])
	# Contact is when the LEADING EDGE reaches the plane, not the centre.
	var touch: float = at - signf(delta) * hit_radius
	var t: float = (touch - from_axis) / delta
	if t < 0.0 or t > 1.0:
		return -1.0
	var across: float = (start.z + (end.z - start.z) * t) if vertical else (start.x + (end.x - start.x) * t)
	if across < float(segment["min"]) or across > float(segment["max"]):
		return -1.0  # crossed the infinite line, but past the end of the real wall
	return t


## Earliest breakable along a projectile's travel segment, as {breakable_id, t}, or empty.
## Same Minkowski segment test _find_earliest_swept_hit uses on combatants.
func _find_earliest_breakable_hit(start: Vector3, end: Vector3, hit_radius: float) -> Dictionary:
	var travel: Vector3 = end - start
	var travel_length_sq: float = travel.length_squared()
	var best_id: int = -1
	var best_t: float = INF
	var breakable_ids: Array = _breakables.keys()
	breakable_ids.sort()
	for breakable_id: int in breakable_ids:
		var breakable: Dictionary = _breakables[breakable_id]
		var position: Vector3 = breakable["position"]
		var t: float = 0.0
		if travel_length_sq > _FACING_EPSILON_SQ:
			t = clamp((position - start).dot(travel) / travel_length_sq, 0.0, 1.0)
		var closest_point: Vector3 = start + travel * t
		var effective_radius: float = hit_radius + float(breakable["radius"])
		if closest_point.distance_squared_to(position) <= effective_radius * effective_radius and t < best_t:
			best_t = t
			best_id = breakable_id
	return {} if best_id < 0 else {"breakable_id": best_id, "t": best_t}


func _init() -> void:
	_combat_rng.seed = 0


## Explicit combat-RNG seeding (GAME-RULES §1.3: seeded per-system, attributable).
## Callers (the dev scaffold's debug print, GUT tests) call this once after
## SimWorld.new() — mirrors register_status/set_damage_matrix's post-construction
## configuration pattern rather than a constructor param, so it never breaks the
## existing zero-arg SimWorld.new() call sites.
func seed_combat_rng(seed: int) -> void:
	_combat_rng.seed = seed


## PLACEMENT seam (M2). Returns false and registers NOTHING when a floor is loaded and the
## requested position is outside it.
##
## FAILS LOUDLY RATHER THAN CLAMPING, deliberately: silently sliding an illegal spawn into
## the room would hide a generator or content defect behind a floor that merely looks a bit
## odd. The generator's own contract is that it never emits a placement the sim would reject
## (it validates against the same WalkableBounds), so reaching this branch always means a
## real bug — and a missing enemy plus an error line is a diagnosable bug, while a quietly
## relocated one is not.
##
## Returns bool rather than push_error alone so the failure is observable to a test and to
## the caller (ContentRegistrar aborts the rest of that actor's registration on false,
## instead of leaving a combatant with no position).
## REGISTRATION PLACEMENT SEAM -- one of the two body-aware placement consumers (the other is
## burrow emergence, _legal_emergence_candidates). The two REFUSE DIFFERENTLY on purpose:
## registration refuses LOUDLY and abandons the actor, because a spawn its body cannot occupy
## is a content defect that must be seen; emergence silently rotates to its next candidate,
## because retrying is its authored behaviour.
##
## body_radius is passed rather than read from _combat_radius because registration order is
## add_entity THEN register_combatant -- the body is not known to the sim yet at this call.
## Callers hand the same stats.combat_radius they are about to register (content_registrar).
func add_entity(actor_id: int, position: Vector3, move_speed: float, facing: Vector3 = Vector3(0.0, 0.0, -1.0), body_radius: float = 0.0) -> bool:
	if _bounds != null and not _bounds.fits(position, body_radius):
		push_error("SimWorld.add_entity: actor %d placed outside walkable bounds at %s (body radius %.2f) — refusing to register (placement never silently clamps)" % [actor_id, position, body_radius])
		return false
	entities[actor_id] = position
	_move_speeds[actor_id] = move_speed
	_facings[actor_id] = _normalize_horizontal(facing, Vector3(0.0, 0.0, -1.0))
	return true


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
## set_weapon_loadout's comment). Every action id in `repertoire` must already be
## registered via register_weapon/register_gun (a melee action's reach == its resolved
## max_range, so a settle-in-band enemy can always actually land what it fires —
## content's job to keep those consistent, not sim's to enforce).
##
## P29: `repertoire` is an Array of {id, min_range, max_range, windup_ticks} — the
## authored actions this actor may choose between, and the distance band each is chosen
## from. ARRAY ORDER CARRIES NO MEANING and nothing here may make it carry any: bands are
## validated non-overlapping by content lint, so at most one can ever match. Windup is
## per-ACTION (it left _ai_tuning at P29); spacing and leash stay per-ACTOR.
##
## spawn_position anchors the leash (leash_radius is measured from here, never the
## actor's drifting current position — though disengage re-anchors this to wherever the
## actor stopped, see the leash-exceeded branch below). Starts "idle" — no initial aggro;
## detection_radius (read from _ai_tuning at decide-time) gates first acquisition
## exactly like re-acquisition. preferred_attack_distance/minimum_attack_distance
## (engagement-spacing fix) bound the band an engaged enemy tries to hold: farther
## than preferred -> approach, closer than minimum -> back away, inside the band ->
## stop. Since P29 they govern MOVEMENT ONLY; attack eligibility is the action band.
func register_ai(actor_id: int, repertoire: Array[Dictionary], spawn_position: Vector3, preferred_attack_distance: float, minimum_attack_distance: float, detection_radius: float, leash_radius: float, engagement_delay_ticks: int = 0, close_frustration_ticks: int = 0, burrow_jump_distance: float = 0.0, burrow_jump_step_distance: float = 0.0, burrow_underground_ticks: int = 0, burrow_emergence_radius: float = 0.0, burrow_emergence_retry_ticks: int = 0, burrow_reacquisition_ticks: int = 0, burrow_cooldown_ticks: int = 0, avoid_commit_ticks: int = 0) -> void:
	# The TERMINAL band is the one with the largest max_range — the only band that
	# includes its own maximum (see _select_action). Derived, never authored, so content
	# cannot accidentally declare two terminals or none.
	var terminal_max: float = -INF
	for action in repertoire:
		terminal_max = max(terminal_max, float(action.max_range))
	var resolved: Array[Dictionary] = []
	var lowest_band_id: String = ""
	var lowest_min: float = INF
	for action in repertoire:
		resolved.append({
			"id": String(action.id),
			"min_range": float(action.min_range),
			"max_range": float(action.max_range),
			"windup_ticks": int(action.windup_ticks),
			"is_terminal": is_equal_approx(float(action.max_range), terminal_max),
			"requires_close_frustration": bool(action.get("requires_close_frustration", false)),
		})
		if float(action.min_range) < lowest_min:
			lowest_min = float(action.min_range)
			lowest_band_id = String(action.id)
	_lint_band_overlap(actor_id, resolved)
	_ai_repertoire[actor_id] = resolved
	_ai_spawn_position[actor_id] = spawn_position
	_ai_state[actor_id] = "idle"
	_ai_tuning[actor_id] = {
		"preferred_attack_distance": preferred_attack_distance,
		"minimum_attack_distance": minimum_attack_distance,
		"detection_radius": detection_radius,
		"leash_radius": leash_radius,
		"engagement_delay_ticks": engagement_delay_ticks,
		"close_frustration_ticks": close_frustration_ticks,
		"avoid_commit_ticks": avoid_commit_ticks,
	}
	# The CLOSE band: the innermost action that is not itself frustration-gated. Derived
	# from authored bands, never from a separate "close range" number, so the proximity test
	# and the selector agree by construction.
	_ai_close_band.erase(actor_id)
	var closest_min: float = INF
	for action in resolved:
		if bool(action.requires_close_frustration):
			continue
		if float(action.min_range) < closest_min:
			closest_min = float(action.min_range)
			_ai_close_band[actor_id] = action
	for action in resolved:
		if bool(action.requires_close_frustration) and not _ai_close_band.has(actor_id):
			push_warning("register_ai [actor %d]: '%s' requires close frustration but the repertoire has no ungated close action -- it could never become selectable" % [actor_id, action.id])
	_register_burrow(actor_id, burrow_jump_distance, burrow_jump_step_distance, burrow_underground_ticks, burrow_emergence_radius, burrow_emergence_retry_ticks, burrow_reacquisition_ticks, burrow_cooldown_ticks, close_frustration_ticks)
	# Equip the LOWEST-BAND action so _equipped_weapon is never empty for an AI actor.
	# Chosen from authored band values, not from array position — element 0 is not
	# privileged. Commitment overwrites this at every windup start, so the initial pick
	# only matters before the actor's first attack; for a single-action repertoire it is
	# that one action, identical to pre-P29.
	if lowest_band_id != "":
		set_equipped_weapon(actor_id, lowest_band_id)


## Registration-time enforcement of GAME-RULES §3's "authored bands may not overlap"
## (same precedent as _lint_flinch_capability and the hit_active_ticks clamp: content
## that would otherwise fail SILENTLY is warned, never silently accepted).
##
## GENERAL by construction, not a special case. Two bands overlap iff some distance
## satisfies BOTH, so the check asks exactly that, using the selector's own predicate
## (band_contains) rather than a re-derived inequality. The lowest distance the two could
## share is max(min_range); if either band is eligible past it they both are, and if that
## exact point is eligible for both -- the shared-maximum case, where two terminal bands
## are each inclusive at the same edge -- it is caught by the identical test. A
## first-match selector faced with any of these would silently become an ARRAY-ORDER
## priority, the one thing the no-hidden-priority ruling forbids.
##
## STRENGTH: push_warning, matching every other sim-side lint in this file (sim has no
## hard-fail idiom and must stay headless-safe). The HARD failure for the same law lives
## at the content-lint layer, tests/test_content_validation.gd::test_no_two_bands_overlap,
## which uses this same predicate. Every overlap is treated identically at both layers.
func _lint_band_overlap(actor_id: int, resolved: Array[Dictionary]) -> void:
	for i in resolved.size():
		for j in range(i + 1, resolved.size()):
			var a: Dictionary = resolved[i]
			var b: Dictionary = resolved[j]
			var shared: float = maxf(float(a.min_range), float(b.min_range))
			if band_contains(a, shared) and band_contains(b, shared):
				push_warning("register_ai [actor %d]: bands '%s' [%.3f, %.3f] and '%s' [%.3f, %.3f] both cover distance %.3f -- overlapping bands make action selection ambiguous (GAME-RULES §3), which repertoire ORDER must never silently resolve" % [
					actor_id, a.id, a.min_range, a.max_range, b.id, b.min_range, b.max_range, shared])


## THE one aggro-acquisition seam (P29 iteration). Before this existed, three separate
## sites flipped _ai_state to "active" -- passive detection, hit-establishes-aggro, and
## status-establishes-aggro -- and anything that had to happen "when an enemy engages"
## would have had to be repeated at all three or be silently bypassable (get shot from
## outside detection range and the engagement opener simply would not arm).
##
## Returns true only for a GENUINE inactive -> active transition. An already-active enemy
## is a no-op: a hit or status landing on an enemy already fighting you is not a fresh
## engagement, and must never re-arm the opener (that would let repeated chip damage
## repeatedly suppress an enemy's attacks). Non-AI actors are ignored, preserving the
## _ai_state.has() guard the hit/status callers used to carry inline.
func _acquire_aggro(actor_id: int) -> bool:
	if not _ai_state.has(actor_id) or _ai_state[actor_id] == "active":
		return false
	_ai_state[actor_id] = "active"
	# ENGAGEMENT OPENER (P29 iteration, playtest finding: "first-engagement firing reads
	# mechanically range-triggered"). A fresh actor's _next_fire_tick defaults to 0, so
	# the instant the player crossed a band edge the cooldown was ALREADY satisfied and a
	# windup began that same tick. This arms the existing shared readiness gate instead of
	# adding a parallel clock, so the delay composes with cooldown for free and suppresses
	# only the ATTACK -- the enemy still approaches during it, which is the point: it
	# closes on you first, then commits.
	# max(), never assignment: re-acquisition must never SHORTEN a cooldown already
	# running (disengage/re-engage would otherwise be an attack-speed exploit).
	var delay: int = int(_ai_tuning.get(actor_id, {}).get("engagement_delay_ticks", 0))
	if delay > 0:
		_next_fire_tick[actor_id] = max(int(_next_fire_tick.get(actor_id, 0)), tick_count + delay)
	# Close-frustration starts counting from ACQUISITION, not from zero. Load-bearing:
	# without this a freshly-acquired distant Watcher would read as already-frustrated and
	# OPEN by surveying -- recreating exactly the "range-triggered" defect the engagement
	# opener was introduced to fix.
	_ai_last_in_close_band[actor_id] = tick_count
	return true


## Debug-only, setup-time direct write (arena.gd's debug_force_aggro) -- called ONCE
## from _ready(), never during ticking. Skips authentic detection_radius gating for
## manual diagnostic testing; the real gameplay driver never calls this
## (debug_force_aggro defaults false). Must be called AFTER register_ai for this
## actor (which unconditionally sets "idle" internally) -- this exists so the one
## place that ever mutates _ai_state stays inside SimWorld even for a debug hook,
## instead of arena.gd reaching into the dict directly.
func debug_set_ai_active(actor_id: int) -> void:
	_ai_state[actor_id] = "active"
	# Mirrors _acquire_aggro's initialization (minus the engagement opener, which this hook
	# deliberately skips): a debug-forced actor must still start UN-frustrated, or it would
	# survey on its first eligible tick and the hook would silently change behaviour it only
	# claims to skip detection gating for.
	_ai_last_in_close_band[actor_id] = tick_count


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
	# BURROW advances here for the same reason as the bump slide -- before AI decisions, so a
	# displacing actor's own move Command is suppressed this same tick. Ordinary AI is
	# SUSPENDED underground, but this lifecycle is authoritative and keeps advancing.
	events.append_array(_advance_burrow())
	events.append_array(_advance_hazards())
	# AI (Phase D step 8 Phase 4) decides enemy Commands here, right before dispatch,
	# so its output (move/attack) feeds through the exact same handlers below a
	# player's own Commands would — no separate resolution path. It also appends any
	# "attack_telegraph" Events directly into this tick's events (a side effect of the
	# DECISION itself, not of a Command being applied, so it can't be an
	# _apply_*-returned Event like everything else here).
	# FLOOR STATE advances before AI decides, so a commitment boundary, an authored activation
	# or a newly-opened route takes hold on the same tick it is earned -- never one tick later,
	# which would let a player slip through a gate that had already logically closed.
	events.append_array(_advance_floor_state())
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
			# A burrowing actor does not steer: authored displacement replaces locomotion, and an
			# underground actor has no locomotion to express at all.
			if _burrow.has(command.actor_id):
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
	var start: Vector3 = position
	position += direction * speed * dt
	# BOUNDS SEAM 1/6 — ordinary locomotion.
	position = _clamp_to_bounds(command.actor_id, start, position)
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
	# P17 burrow: a combat-ABSENT actor is alive but not participating. This one line reaches
	# every hit scan, the authored-displacement contact clamp and bump target selection at once,
	# because all four already funnel through this predicate -- which is exactly why the burrow
	# audit found ALIVE == PRESENT PARTICIPANT true by construction in a single function.
	if _combat_absent.has(target_id):
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

	# FAIL-CLOSED (P17 burrow): an absent actor resolves no attack. Ordinary AI is already
	# suspended underground and any committed windup is cancelled at submerge, so this is a belt
	# to that brace -- but "unreachable by construction" is exactly the claim that stops being
	# true when a second consumer arrives, and the guard costs one line.
	if _combat_absent.has(actor_id):
		return [Event.new(tick_count, "attack_rejected", {"actor_id": actor_id, "reason": "combat_absent"})]

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
			# BOUNDS SEAM 2/6 — authored melee lunge displacement. The contact sweep
			# shortens the segment first and the wall clamps whatever endpoint survived,
			# so whichever legal stopping condition comes first is the one that wins.
			if contact.is_empty():
				entities[actor_id] = _clamp_to_bounds(actor_id, start, end)
			else:
				entities[actor_id] = _clamp_to_bounds(actor_id, start, contact.entry_position)
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

	# BREAKABLES share this swing DETECTION and nothing else. The cone/reach test above is
	# reused against the prop registry; resolution then forks away from the combatant pipeline
	# entirely (see _resolve_hit_on_breakable and the ROADMAP inheritance audit).
	for breakable_id: int in _breakables_in_cone(attacker_position, resolved_aim, weapon):
		events.append_array(_resolve_hit_on_breakable(actor_id, breakable_id, float(weapon.damage)))
	# A switch is struck by the same swing that would break a crate. It takes no damage -- there
	# is nothing to damage -- so it is a contact, not a hit resolution.
	for switch_id: int in _switches_in_cone(attacker_position, resolved_aim, weapon):
		events.append_array(_resolve_hit_on_switch(switch_id))

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
## Reads _equipped_weapon, which since P29 is the COMMITTED action -- so an interrupted
## multi-action enemy is charged the cooldown of the action it was actually performing,
## not some other entry in its repertoire.
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


## projectile_id (P29 tracer lifecycle, -1 = not from a projectile): a shot that
## terminates ON A TARGET does so through one of FOUR events below (attack_absorbed,
## blocked, shield_broken, hit) — only lifetime expiry emits projectile_expired. None of
## the four used to identify the projectile, so presentation could not tell which tracer
## had ended, and a blocked shot whose tracer sailed on would read as a hit-detection bug.
## Threaded as ONE optional parameter and stamped CONDITIONALLY (the established
## attack_profile_id precedent) rather than as a new event kind, so every melee-path
## payload stays byte-identical and no existing assertion moves.
##
## source_kind (2026-09-03): SOURCE_ACTOR by default, so every existing caller is unchanged byte
## for byte. SOURCE_ENVIRONMENT differs in exactly two places, both below, and in NOTHING else --
## i-frames, the damage matrix, the shield meter, shield break, pressure, flinch, knockback and
## death all resolve identically. That is the point: hazards must not grow a parallel pipeline.
func _resolve_hit_on_target(attacker_id: int, target_id: int, weapon: Dictionary, resolved_aim: Vector3, weapon_id: String, attack_profile_id: String = "", projectile_id: int = -1, source_kind: StringName = SOURCE_ACTOR) -> Array[Event]:
	# i-frames fully negate a hit: no damage, no knockback, no status, no meter
	# interaction — the attack simply doesn't land (locked invariant).
	if _iframe_ticks_remaining.get(target_id, 0) > 0:
		var absorbed: Dictionary = {"attacker_id": attacker_id, "target_id": target_id, "reason": "iframes"}
		if source_kind != SOURCE_ACTOR:
			absorbed["source"] = source_kind
		return [_stamp_projectile(Event.new(tick_count, "attack_absorbed", absorbed), projectile_id)]

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
		var blocked: Array[Event] = [_stamp_projectile(_resolve_blocked_hit(target_id, target_position, resolved_aim, attacker_id, damage), projectile_id)]
		# P16 perfect parry: a hit landing inside the window measured from the shield's
		# own rising edge (_block_start_tick, which already existed) marks the ATTACKER
		# PARRY EXPOSED. The meter still drained above, deliberately -- a parry's only
		# extra reward is the offensive punish window, never meter efficiency.
		# A PARRY EXPOSES ITS ATTACKER, and the environment has none to expose. The shield still
		# absorbed the damage above -- that is ordinary shield law and applies to hazards exactly
		# as the ruling requires; only the counter-attack half has nobody to aim at.
		if source_kind == SOURCE_ACTOR:
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
		# BOUNDS SEAM 3/6 — hit knockback. Displacement INFLICTED on an actor obeys the
		# same walls as displacement it chooses: being shoved through a wall is the same
		# defect as walking through one.
		knocked_position = _clamp_to_bounds(target_id, target_position, target_position + resolved_aim * weapon.knockback_distance)
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
	# ENVIRONMENT DAMAGE ACQUIRES NO AGGRO. "The floor hurt me, therefore attack the player" is
	# not an inference the sim gets to make; ordinary perception may still find the player on its
	# own, which is a different mechanism entirely.
	if source_kind == SOURCE_ACTOR and _allegiance.get(attacker_id, &"enemy") == &"player":
		_acquire_aggro(target_id)

	var hit_payload: Dictionary = {
		# attacker_id is -1 for the environment. TRUTHFULLY absent rather than fabricated: a
		# consumer that needs to know who did this can ask, and get an honest "nobody".
		#
		# The `source` field is stamped CONDITIONALLY below -- the established attack_profile_id
		# precedent -- so every actor-sourced payload stays byte-identical and no recorded
		# baseline moves. The canary caught this immediately when the field was unconditional,
		# which is exactly its job; re-recording a baseline to accommodate a new field would have
		# thrown away the evidence that nothing else had changed.
		"attacker_id": attacker_id,
		"target_id": target_id,
		"damage": damage,
		"damage_type": weapon.damage_type,
		"family": family,
		"position": knocked_position,
	}
	if source_kind != SOURCE_ACTOR:
		hit_payload["source"] = source_kind
	# Slice B: profile identity never substitutes for weapon identity -- omitted
	# entirely (not even an empty string) for the original flat path, so every
	# existing test's exact payload-key expectations stay untouched.
	if attack_profile_id != "":
		hit_payload["attack_profile_id"] = attack_profile_id
	var events: Array[Event] = [_stamp_projectile(Event.new(tick_count, "hit", hit_payload), projectile_id)]
	if cancels_windup:
		events.append(Event.new(tick_count, "windup_interrupted", {"actor_id": target_id, "attacker_id": attacker_id}))
	if flinch_reason != "":
		# ANY successful authoritative flinch aborts a self-propelled backward jump, EXPLOIT or
		# PRESSURE alike. Hooked on the ROUTE being selected rather than on the deadline write
		# used by earlier mechanics: those differ when a flinch lands on an already-flinched
		# actor, and the ruling is any successful flinch.
		_abort_burrow_jump(target_id)
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
		_end_burrow(target_id)
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


## Conditionally tags a projectile's TERMINAL event with the id of the shot that caused
## it (P29). -1 (every melee path) leaves the payload untouched, byte-for-byte — the same
## "profile identity never substitutes for weapon identity" discipline attack_profile_id
## already follows. Presentation's whole tracer rule is then one line: an event carrying
## my projectile_id ends me.
func _stamp_projectile(event: Event, projectile_id: int) -> Event:
	if projectile_id >= 0:
		event.payload["projectile_id"] = projectile_id
	return event


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
##
## PROJECTILE-VS-WALL IS DEFERRED, NOT OVERLOOKED (M2 Slice 1 fence; ROADMAP P20 carries the
## entry so the decision does not live only here). Projectiles do NOT consume the bounds
## seam: Slice 1 floors are single convex chambers, so a shot leaving the walkable rect has
## already left the play area and projectile_max_lifetime_ticks retires it through the
## existing projectile_expired Event. Ruling it in now would mean inventing impact-position
## and status-drop semantics against no geometry. TRIGGER TO REVISIT: the first floor with
## interior geometry or a non-convex chamber. Player/enemy BODY displacement obeys bounds
## today — this fence covers world/projectile collision only.
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

		# A shot is checked against combatants AND breakables on the same segment, and whichever
		# is met FIRST stops it. Props are therefore lightweight physical cover for projectile
		# traversal (ruled). A penetrable prop would have to be authored deliberately later;
		# penetration is never the default.
		var actor_hit: Dictionary = _find_earliest_swept_hit(start_position, end_position, projectile.attacker_id, weapon.hit_radius)
		var breakable_hit: Dictionary = _find_earliest_breakable_hit(start_position, end_position, weapon.hit_radius)
		var switch_hit: Dictionary = _find_earliest_switch_hit(start_position, end_position, weapon.hit_radius)
		var world_hit: Dictionary = _find_earliest_solid_hit(start_position, end_position, weapon.hit_radius)

		# THE ORDERING LAW (P34). Smallest authoritative parametric travel distance wins. The
		# WORLD -> BREAKABLE -> ACTOR order applies ONLY to exact/epsilon-equivalent ties and is
		# a DETERMINISM RULE FOR DEGENERATE GEOMETRY -- never a general gameplay priority. It
		# exists because M3 needs a client and a server to resolve the same shot identically,
		# not because walls are "more important" than actors.
		var world_first: bool = not world_hit.is_empty() \
			and (breakable_hit.is_empty() or float(world_hit["t"]) <= float(breakable_hit["t"]) + _TIE_EPSILON) \
			and (switch_hit.is_empty() or float(world_hit["t"]) <= float(switch_hit["t"]) + _TIE_EPSILON) \
			and (actor_hit.is_empty() or float(world_hit["t"]) <= float(actor_hit["t"]) + _TIE_EPSILON)
		if world_first:
			# A shot stopped by the world has NO impact event of its own, so this is the one
			# termination that needs provenance -- hence the reason field, and hence why actor
			# and breakable impacts deliberately do not carry one.
			events.append(Event.new(tick_count, "projectile_expired", {
				"attacker_id": projectile.attacker_id, "weapon_id": projectile.weapon_id,
				"projectile_id": projectile_id,
				"position": start_position + (end_position - start_position) * float(world_hit["t"]),
				"reason": PROJECTILE_END_WORLD,
			}))
			expired_ids.append(projectile_id)
			continue
		# The switch joins the SAME ordering law (P34): smallest parametric distance wins, and the
		# WORLD -> BREAKABLE -> SWITCH -> ACTOR order applies ONLY to exact ties, as a determinism
		# rule for degenerate geometry. It is not a claim that props matter more than actors.
		var breakable_first: bool = not breakable_hit.is_empty() \
			and (switch_hit.is_empty() or float(breakable_hit["t"]) <= float(switch_hit["t"]) + _TIE_EPSILON) \
			and (actor_hit.is_empty() or float(breakable_hit["t"]) <= float(actor_hit["t"]) + _TIE_EPSILON)
		if breakable_first:
			# Stamped with the projectile id so presentation retires the tracer through the same
			# uniform rule every other terminal event uses.
			for event in _resolve_hit_on_breakable(projectile.attacker_id, int(breakable_hit["breakable_id"]), float(weapon.damage)):
				events.append(_stamp_projectile(event, projectile_id))
			expired_ids.append(projectile_id)
			continue
		var switch_first: bool = not switch_hit.is_empty() and (actor_hit.is_empty() or float(switch_hit["t"]) <= float(actor_hit["t"]) + _TIE_EPSILON)
		if switch_first:
			# THE SHOT IS SPENT ON IT, which is also what makes one projectile exactly one
			# activation: it cannot come back round and toggle the same switch again.
			for event in _resolve_hit_on_switch(int(switch_hit["switch_id"])):
				events.append(_stamp_projectile(event, projectile_id))
			expired_ids.append(projectile_id)
			continue
		if not actor_hit.is_empty():
			events.append_array(_resolve_hit_on_target(projectile.attacker_id, int(actor_hit["target_id"]), weapon, projectile.direction, projectile.weapon_id, "", projectile_id))
			expired_ids.append(projectile_id)
			continue

		projectile.position = end_position
		projectile.ticks_alive += 1
		if projectile.ticks_alive >= weapon.max_lifetime_ticks:
			events.append(Event.new(tick_count, "projectile_expired", {
				"attacker_id": projectile.attacker_id, "weapon_id": projectile.weapon_id,
				"projectile_id": projectile_id, "position": projectile.position,
				"reason": PROJECTILE_END_LIFETIME,
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
## Returns {"target_id": int, "t": float}, or {} for no hit. The parametric t is returned
## (M2 floor grammar) because a shot may also meet a BREAKABLE on the same segment, and
## "whichever is struck first" cannot be decided from ids alone.
func _find_earliest_swept_hit(start: Vector3, end: Vector3, attacker_id: int, hit_radius: float) -> Dictionary:
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
		# AUTHORITATIVE GEOMETRY (P29 iteration item 3, playtest: "apparent hits that
		# miss"). The test is projectile radius + the TARGET'S BODY -- a Minkowski sum --
		# not the projectile radius alone. Before this, a shot had to pass within
		# hit_radius of a target's CENTRE: measured at 0.40 against an Ooze whose authored
		# body is 1.45, so shots visually crossing three-quarters of the body registered
		# as clean misses (tools/diagnose_projectile_geometry.gd).
		#
		# combat_radius is the SAME authoritative body radius _contact_distance already
		# gives Burn's contact-spread, the melee lunge clamp and P16's bump. Every other
		# contact system in the sim consulted it; only this one did not. Reusing it means
		# the correction scales per family for free and adds no new tunable.
		#
		# The sum lives ONLY in collision space: the tracer draws the projectile radius
		# alone, because that is the object the player sees (see ProjectileTracer).
		var effective_radius: float = hit_radius + _combat_radius.get(target_id, 0.0)
		if closest_point.distance_squared_to(target_position) <= effective_radius * effective_radius and t < best_t:
			best_t = t
			best_target_id = target_id

	return {} if best_target_id == -1 else {"target_id": best_target_id, "t": best_t}


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
## considers actors of a DIFFERENT allegiance, so a bumped enemy can still slide through
## another enemy. UPDATED (M2 Slice 1): the "past the visual arena edge" half of this
## limitation is now CLOSED — the slide clamps to the loaded floor's WalkableBounds like
## every other authoritative displacement. Body-blocking between actors remains open, and
## remains P20's.
## Autonomous-phase law (see tick()): sorted ids, no mutation of the collection while
## iterating -- completed slides are collected first and erased afterwards.
## FLINCH DOES NOT ABORT A SLIDE — ruled 2026-08-19, and NEWLY REVIEWED, not backdated.
##
## Recorded honestly because the record was checked first and came back empty: P16 banked
## the "§3 non-flinching-displacement law" (LEXICON's BUMP entry;
## test_bump_during_a_committed_windup_never_disturbs_its_timeline), but that is the
## OPPOSITE PROPOSITION — it says a bump never INFLICTS flinch/interruption on the actor it
## displaces. Whether an actor already sliding, flinched by something ELSE, keeps sliding
## was never specified, never tested, and fell out of this phase simply not being gated by
## _flinched_until_tick. It is a consequence that was reviewed and then ruled deliberate; it
## was not intended all along, and must never be described as though it were.
##
## THE PRINCIPLE (the part that generalises): FLINCH SUPPRESSES AGENCY. Externally imposed
## displacement is not agency, so already-imparted forced motion COMPLETES. The flinch
## early-return lives in _decide_single_ai_command, which withholds an actor's own Commands
## — exactly the right place for a rule about agency, and exactly why this phase is
## correctly outside it.
##
## SAME PRINCIPLE, OPPOSITE ANSWER, for anything self-propelled: a committed mobility action
## an actor CHOSE is agency, so a successful flinch must
## abort it and forfeit the remaining authored movement. Do not read this comment as
## precedent for "authored displacement always completes" — the question is always whose
## agency the motion expresses, never whether the motion is authored.
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
		# BOUNDS SEAM 5/6 — shield bump slide.
		if contact.is_empty():
			entities[actor_id] = _clamp_to_bounds(actor_id, start, end)
		else:
			entities[actor_id] = _clamp_to_bounds(actor_id, start, contact.entry_position)
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
		# BOUNDS SEAM 4/6 — shield-break knockback.
		var knocked_position: Vector3 = _clamp_to_bounds(target_id, target_position, target_position + resolved_aim * shield.knockback_distance)
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
## existing simulation, not a new gameplay system: it decides locomotion, whether to
## attack now, and which eligible authored action to commit (P29), synthesizing the exact
## same Command shapes a player would send. No RNG (deterministic AI v1). Actors iterate in sorted
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
		_refresh_close_proximity(actor_id, player_id)
		commands.append_array(_decide_single_ai_command(actor_id, player_id, events))
	return commands


## LITERAL PROXIMITY FACT, refreshed EVERY tick the target is genuinely inside the close
## band -- never stamped once on entry, and never skipped because of what the actor happens
## to be doing. It runs here, ahead of every decision branch, deliberately: an earlier
## version sat inside _decide_single_ai_command AFTER the flinched and mid-windup early
## returns, so the fact went stale for the whole of every windup and a Watcher that had been
## in melee the entire time read as long-frustrated the moment it looked. Position is a fact
## about the world, not about the actor's current activity.
##
## Tested against the AUTHORED close band with the same band_contains() the selector uses,
## so "close" has exactly one definition in the codebase.
##
## This is also precisely why displacement does NOT provoke a Survey: a bump merely stops
## the refresh, leaving the entire close_frustration_ticks still to elapse.
func _refresh_close_proximity(actor_id: int, player_id: int) -> void:
	var close_band: Dictionary = _ai_close_band.get(actor_id, {})
	if close_band.is_empty():
		return
	var to_player: Vector3 = entities.get(player_id, Vector3.ZERO) - entities.get(actor_id, Vector3.ZERO)
	to_player.y = 0.0
	if band_contains(close_band, to_player.length()):
		_ai_last_in_close_band[actor_id] = tick_count


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

	# DORMANT ROSTER (ruled): a triggered encounter roster does not perceive the player at all
	# until an AUTHORED effect activates the site -- which is precisely why this slice needs no
	# line-of-sight or visibility propagation.
	#
	# AMBIENT sites register no state entry, so their rosters fall straight through this guard
	# and engage by ordinary detection. That is ambient in one line, with no special case.
	#
	# Gated on ENCOUNTER STATE rather than on _ai_state, deliberately: debug_force_aggro
	# writes _ai_state directly at setup, and a state-based guard would let a debug hook
	# silently repeal a design law it only claims to skip detection gating for.
	if _actor_encounter.has(actor_id):
		if String(_encounter_state.get(int(_actor_encounter[actor_id]), "")) == "dormant":
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
			# DISENGAGED RETURN. Territory's third job (after authored spawn and acquisition
			# association): once nobody is being chased, an ambient actor that has been carried
			# or has wandered out of its home walks back. This is the ONLY place home constrains
			# movement -- it never limits an engaged pursuit.
			return _return_home_commands(actor_id, events)
		_acquire_aggro(actor_id)
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
	# BURROW suspends ordinary AI for its whole lifecycle -- jump, underground and the
	# reacquisition beat alike. The actor yields NO Command, which is what makes "cannot attack
	# during the beat" structural rather than a second gate someone can forget. The lifecycle
	# itself keeps advancing in its own authoritative phase.
	if _burrow.has(actor_id):
		return []

	if _ai_attack_fire_tick.has(actor_id):
		return _decide_attack_commands(actor_id, "", player_id, events)

	var to_player: Vector3 = player_position - position
	to_player.y = 0.0
	var distance_to_player: float = to_player.length()

	# P29: attack ELIGIBILITY is now "some authored action's band contains this distance",
	# not "within preferred_attack_distance". preferred/minimum revert to movement-only
	# (they were already movement-only for the retreat/approach rules; this removes their
	# last eligibility job). For a single-action repertoire the two are the same test by
	# construction — see _select_action.
	var selected_action_id: String = _select_action(actor_id, distance_to_player)
	if tick_count >= _next_fire_tick.get(actor_id, 0) and selected_action_id != "":
		return _decide_attack_commands(actor_id, selected_action_id, player_id, events)

	# BURROW SELECTOR -- deliberately AFTER the attack check above. If a valid attack is
	# available, frontal engagement is succeeding and burrow must not replace it; the mechanic
	# exists for the case where the Fang cannot establish pressure at all.
	if _should_burrow(actor_id):
		events.append(Event.new(tick_count, "burrow_committed", {
			"actor_id": actor_id, "source": "selector",
			"frustration_elapsed": tick_count - int(_ai_last_in_close_band.get(actor_id, tick_count)),
		}))
		_begin_burrow_jump(actor_id, player_id)
		return []

	if distance_to_player < tuning.minimum_attack_distance:
		return [Command.new(tick_count, actor_id, "move", {"direction": -to_player.normalized()})]

	if distance_to_player > tuning.preferred_attack_distance:
		# PURSUIT IS DETECTION-GOVERNED, NOT TERRITORY-GOVERNED (ruled 2026-08-31 after play).
		# An ENGAGED ambient enemy chases anywhere physically legal; its home constrains where it
		# lives and where it returns, never how far it may follow while the fight is on. The only
		# limits here are the real ones -- floor, wall, closed gate, seal -- applied downstream by
		# the clamp, plus P33 routing around genuine geometry.
		return [Command.new(tick_count, actor_id, "move", {"direction": _pursuit_direction(actor_id, player_position, events)})]

	# IN BAND. Radial distance is satisfied, so approach is done -- but the old law held position
	# ABSOLUTELY, and a distance band is blind to lateral motion. Measured consequence: a player
	# circling at band distance produced 0.00 units of translation over 600 ticks while the Ooze
	# faced and attacked, which reads as "following me but stuck". Tangential tracking is the
	# answer to exactly that, and only that.
	var tracking: Vector3 = _band_tracking_direction(actor_id, player_position)
	if tracking == Vector3.ZERO:
		return []  # stationary target, or nothing legal: hold, as before
	return [Command.new(tick_count, actor_id, "move", {"direction": tracking})]


# --- P33: BOUNDED LOCAL OBSTACLE AVOIDANCE ----------------------------------------------
## Sampling step as a fraction of the body radius. NOT a tunable: it is a correctness parameter,
## fine enough that a body cannot tunnel across a gap narrower than itself, which is the only
## way this detector could lie by omission.
const _AVOID_SAMPLE_FRACTION: float = 0.5
## Below this, a target counts as stationary and the actor holds. Deliberately smaller than one
## tick of player travel so ordinary strafing registers, and large enough that float noise in a
## standing target cannot make an actor drift.
const _BAND_TRACK_EPSILON: float = 0.001
## WAYPOINT ARRIVAL TOLERANCE -- "close enough to the waypoint to consider it reached", and
## nothing else. It is deliberately NOT derived from the body radius even though the radius is
## right there: those are different concepts, and conflating them is exactly the defect this
## replaced. The first candidate offset IS one body radius, so a radius-sized arrival test
## accepted a freshly chosen waypoint immediately -- commit, reached, reselect, every tick,
## with avoid_commit_ticks never mattering (live evidence: 41 commits in one encounter, 38 of
## them cleared as "reached", deadlines two ticks apart).
##
## 0.25 is an absolute distance chosen against this game's SCALE, not against any actor:
## corridors are 5.00 wide and bodies are 1.7-2.9 across, so a quarter unit is unambiguously
## standing on the spot. The invariant it must satisfy -- tolerance < the smallest authored body
## radius, hence < the smallest possible first offset -- is PINNED BY TEST against shipped
## content rather than enforced by deriving it, so authoring a small enemy fails loudly instead
## of silently resurrecting the collision.
const _AVOID_ARRIVAL_TOLERANCE: float = 0.25


# --- P34: PROJECTILE TERMINATION PROVENANCE ----------------------------------------------
## THE CLOSED ENUM, frozen after auditing every path that destroys a projectile. Four exist:
##
##   1. BREAKABLE impact -- emits breakable_hit (+ breakable_destroyed), stamped with the
##      projectile id. Already authoritative and already retires the tracer.
##   2. ACTOR impact -- emits hit (and blocked / shield_broken / death as applicable), carrying
##      the projectile id. Likewise already authoritative.
##   3. LIFETIME expiry -- emits projectile_expired. Nothing else explains it.
##   4. FLOOR UNLOAD -- _projectiles is SCOPE_FLOOR and is cleared wholesale; no per-projectile
##      event is emitted, and presentation drops every tracer on floor rebuild anyway.
##
## SO THE ENUM HAS EXACTLY TWO MEMBERS: the reasons that actually accompany a
## projectile_expired. Cases 1 and 2 are DELIBERATELY ABSENT -- their own hit events completely
## explain the destruction and already carry the projectile id, so a termination reason there
## would be a second channel for provenance those events own (ruled). Case 4 needs no event.
##
## projectile_expired therefore means: THIS PROJECTILE CEASED TO EXIST AND NO OTHER EVENT
## EXPLAINS WHY. Broadening it to every termination was considered and rejected: it would emit a
## second terminal event for shots that already have one, and presentation's uniform "any event
## carrying my projectile_id retires me" rule would fire twice for one shot.
##
## A NEW REASON REQUIRES A REAL CONSUMER AND AN EXPLICIT SCHEMA CHANGE. No free-form strings, no
## "future reasons" placeholder -- test_projectile_world.gd pins the membership and the count.
const PROJECTILE_END_LIFETIME: StringName = &"lifetime"
const PROJECTILE_END_WORLD: StringName = &"world"
const PROJECTILE_END_REASONS: Array[StringName] = [PROJECTILE_END_LIFETIME, PROJECTILE_END_WORLD]
## Tolerance for "arrived at the same instant". Only degenerate geometry ever reaches it.
const _TIE_EPSILON: float = 0.000001


## THE DETECTOR (validated 7/7 on the real failing geometry before any of this existed --
## tools/diagnose_obstruction_detector.gd, whose seven cases are now tests).
##
## "Is my intended direct movement toward the target obstructed by authoritative floor geometry?"
##
## Answered from sim state alone: no physics query, no raycast, no navigation agent, ever. It
## walks the direct line at BODY WIDTH against this actor's OWN legality region, so territory
## confinement and body extent are both respected by construction rather than by a second rule.
##
## HORIZON IS detection_radius, not a picked constant: an actor that only pursues what it can
## detect has no business reasoning about geometry beyond that. Returns the first blocked point,
## or {} for clear.
func _direct_route_obstruction(actor_id: int, target: Vector3) -> Dictionary:
	var region: WalkableBounds = _legal_bounds_for(actor_id)
	if region == null:
		return {}
	var radius: float = _body_radius_for(actor_id)
	if radius <= 0.0:
		return {}  # a bodiless actor cannot be obstructed by width
	var from: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var span: Vector3 = target - from
	span.y = 0.0
	var horizon: float = float(_ai_tuning.get(actor_id, {}).get("detection_radius", 0.0))
	var distance: float = minf(span.length(), horizon)
	if distance <= 0.0001:
		return {}
	# STOP SHORT OF THE TARGET'S OWN GROUND. A pursuer needs a clear route to WHERE IT WILL
	# STAND, not into the target's body -- and a wide actor frequently cannot fit where a narrow
	# Envoy is standing. Sampling all the way in made every route unqualifiable in the
	# near-tangent case, which is a false obstruction, not a real one.
	distance -= float(_ai_tuning.get(actor_id, {}).get("preferred_attack_distance", 0.0))
	if distance <= 0.0001:
		return {}
	var direction: Vector3 = span.normalized()
	var step: float = maxf(radius * _AVOID_SAMPLE_FRACTION, 0.05)
	var travelled: float = step
	while travelled <= distance:
		var probe: Vector3 = from + direction * travelled
		if not region.fits(probe, radius):
			return {"at": probe, "distance": travelled}
		travelled += step
	return {}


## THE SELECTOR. Perpendicular sidesteps generated in a STABLE order so identical authoritative
## state yields an identical route: offsets ascend from one body radius in half-radius
## increments up to the detection horizon, and RIGHT is generated before LEFT at each offset.
##
## A candidate qualifies only if the waypoint is body-legal AND both legs -- actor to waypoint,
## waypoint to target -- are clear to the same detector. The first qualifying OFFSET wins.
##
## PINNED TIE RULE: if both sides qualify at the SAME offset, the waypoint nearer the target
## wins; if those are equal within epsilon, RIGHT wins by authored convention. This is a
## degeneracy rule for replayability, NOT a steering preference -- the observed geometry is
## asymmetric (right clears at 4.35 u, left finds nothing within 16), so geometry decides almost
## always. Nothing here consults RNG, container order or any engine query.
func _select_avoidance_waypoint(actor_id: int, target: Vector3) -> Vector3:
	var region: WalkableBounds = _legal_bounds_for(actor_id)
	var radius: float = _body_radius_for(actor_id)
	if region == null or radius <= 0.0:
		return Vector3.ZERO
	var from: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var span: Vector3 = target - from
	span.y = 0.0
	if span.length() <= 0.0001:
		return Vector3.ZERO
	var forward: Vector3 = span.normalized()
	var perpendicular := Vector3(-forward.z, 0.0, forward.x)
	# TWO CANDIDATE CLASSES, ranked together by TOTAL ROUTE LENGTH.
	#
	# APERTURES FIRST, because they are the only candidates that can express "advance THROUGH the
	# opening". Perpendicular offsets can only step sideways, and committed legs made that visible:
	# every waypoint chosen from them sat FURTHER from the target than the actor already stood
	# (measured, eleven legs in a row), turning honest commitment into a slow lateral shuffle.
	#
	# Shortest-total-route ranking was tried over perpendicular candidates ALONE and changed
	# nothing -- they all sit the same `offset` away and barely alter distance-to-target, so there
	# was nothing for a ranking to prefer. The ranking was never wrong; the candidate set was
	# empty of anything worth ranking. With apertures in it, |from -> wp| + |wp -> target| now
	# genuinely favours routing through a doorway over shuffling beside a wall.
	#
	# Deterministic throughout: apertures enumerated in sorted connection-id order, then
	# perpendicular offsets ascending right-before-left; strict improvement, so ties keep the
	# earlier candidate. Identical state yields an identical route.
	var candidates: Array[Vector3] = _aperture_candidates(from, target, region, radius)
	var cap: float = float(_ai_tuning.get(actor_id, {}).get("detection_radius", 0.0))
	var offset: float = radius
	while offset <= cap:
		candidates.append(from + perpendicular * offset)
		candidates.append(from - perpendicular * offset)
		offset += radius * _AVOID_SAMPLE_FRACTION

	var best: Vector3 = Vector3.ZERO
	var best_route: float = INF
	for candidate: Vector3 in candidates:
		if not _waypoint_qualifies(actor_id, candidate, target, region, radius):
			continue
		var route: float = from.distance_to(candidate) + candidate.distance_to(target)
		if route < best_route - 0.0001:
			best_route = route
			best = candidate
	return best


## AUTHORITATIVE OPENINGS, from the structure that already owns them: _connections holds the
## aperture geometry and _connection_open holds the gate state. Route-finding CONSUMES that fact
## -- it does not rediscover doorways from presentation meshes, and keeps no private copy of
## them, the same single-source rule P34 established for walls.
##
## A CLOSED GATE IS NOT AN OPENING, read live rather than cached, so a route through a door that
## just shut is never proposed.
##
## TWO POINTS PER OPENING: the body-valid spot nearest the ACTOR, and the one nearest the TARGET.
## Never the geometric centre -- route to somewhere the pursuer can actually stand.
##
## The near point is what "advance THROUGH the opening" needs. A first version offered only the
## target-side point, which is useless in the common case: when the target already stands inside
## the aperture, clamping it returns the target's own position, whose leg IS the blocked direct
## line -- so the candidate never qualified and the aperture class did nothing at all.
func _aperture_candidates(from: Vector3, target: Vector3, region: WalkableBounds, radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if region == null:
		return out
	var connection_ids: Array = _connections.keys()
	connection_ids.sort()  # determinism: never let Dictionary order reach a route
	for connection_id: int in connection_ids:
		if not bool(_connection_open.get(connection_id, false)):
			continue
		var aperture: Rect2 = _connections[connection_id]["aperture"]
		# INSET THE WIDTH ONLY. An aperture deliberately OVERLAPS the spaces it joins, so its
		# long axis runs into open ground on both sides -- insetting that axis too pushes the
		# entry point deep inside the corridor, where the body can no longer be reached in a
		# straight line from beside the mouth. Measured: it made every aperture candidate fail
		# qualification, so the class contributed nothing. Only the WIDTH must clear the body;
		# region.fits() judges the rest against the real union.
		var narrow_is_x: bool = aperture.size.x <= aperture.size.y
		var min_x: float = aperture.position.x + (radius if narrow_is_x else 0.0)
		var max_x: float = aperture.end.x - (radius if narrow_is_x else 0.0)
		var min_z: float = aperture.position.y + (0.0 if narrow_is_x else radius)
		var max_z: float = aperture.end.y - (0.0 if narrow_is_x else radius)
		if min_x > max_x or min_z > max_z:
			continue  # this body does not fit through this opening at all
		for anchor: Vector3 in [from, target]:
			var point := Vector3(clampf(anchor.x, min_x, max_x), 0.0, clampf(anchor.z, min_z, max_z))
			if region.fits(point, radius) and not out.has(point):
				out.append(point)
	return out


## A waypoint is only useful if the actor can both REACH it and GO ON from it. Checking only the
## first leg is how an actor commits to a corner it then cannot leave.
func _waypoint_qualifies(actor_id: int, waypoint: Vector3, target: Vector3, region: WalkableBounds, radius: float) -> bool:
	if not region.fits(waypoint, radius):
		return false
	var from: Vector3 = entities.get(actor_id, Vector3.ZERO)
	if not _segment_is_clear(region, from, waypoint, radius, 0.0):
		return false
	# Same stop-short as the detector, and for the same reason: the second leg must reach the
	# STANDING position, never the target's own footprint.
	return _segment_is_clear(region, waypoint, target, radius,
		float(_ai_tuning.get(actor_id, {}).get("preferred_attack_distance", 0.0)))


func _segment_is_clear(region: WalkableBounds, from: Vector3, to: Vector3, radius: float, stop_short: float) -> bool:
	var span: Vector3 = to - from
	span.y = 0.0
	var distance: float = span.length() - stop_short
	if distance <= 0.0001:
		return true
	var direction: Vector3 = span.normalized()
	var step: float = maxf(radius * _AVOID_SAMPLE_FRACTION, 0.05)
	var travelled: float = step
	while travelled <= distance:
		if not region.fits(from + direction * travelled, radius):
			return false
		travelled += step
	return true


## Walks a disengaged ambient actor back to its home territory, through the SAME P33 detector,
## selector and commitment that player-directed pursuit uses. Empty once it is home, or for
## anyone with no ambient home at all -- which is every actor whose confinement is physical.
func _return_home_commands(actor_id: int, events: Array[Event]) -> Array[Command]:
	var home: WalkableBounds = _home_territory(actor_id)
	if home == null:
		return []
	var here: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var radius: float = _body_radius_for(actor_id)
	if home.fits(here, radius):
		return []  # already home: idle means idle
	var home_point: Vector3 = _nearest_home_point(actor_id)
	# ARRIVAL USES THE P33 TOLERANCE, not the body radius. A radius-sized guard here stopped the
	# actor one full body short of its own destination -- which is short of being home at all,
	# since the destination is already inset by that radius. Same collision of two concepts the
	# P33 arrival repair fixed, and it is the same constant precisely so they cannot diverge.
	if home_point == Vector3.ZERO or here.distance_to(home_point) <= _AVOID_ARRIVAL_TOLERANCE:
		return []
	var heading: Vector3 = _pursuit_direction(actor_id, home_point, events)
	if heading == Vector3.ZERO:
		return []
	return [Command.new(tick_count, actor_id, "move", {"direction": heading})]


## BOUNDED LATERAL MATCHING inside the attack band (ruled 2026-09-01).
##
## THE SEMANTIC SPLIT is the whole design: the RADIAL component governs distance and is already
## handled by the approach/retreat clauses; only the TANGENTIAL component -- the part of the
## target's motion perpendicular to the actor->target line -- gives an actor at valid attack range
## a reason to reposition. Extracting it keeps "stay at my fighting distance" and "follow you
## around" as separate laws instead of collapsing them into a chase.
##
## NOT VELOCITY COPYING. Only the DIRECTION of the tangential component is taken; the actor then
## moves at its OWN move_speed under its OWN legality, so a fast player out-runs a slow blob
## exactly as before. Mirroring the target's velocity would have erased the family's character,
## which is the thing this is supposed to preserve.
##
## NO SMOOTHING MACHINERY. One frame of remembered target position, differenced. If that proves
## jittery in play it becomes an evidenced question, not a pre-emptive filter.
func _band_tracking_direction(actor_id: int, target: Vector3) -> Vector3:
	var previous: Vector3 = _ai_band_last_target.get(actor_id, target)
	_ai_band_last_target[actor_id] = target
	var motion: Vector3 = target - previous
	motion.y = 0.0
	if motion.length() <= _BAND_TRACK_EPSILON:
		return Vector3.ZERO  # a stationary target must not make the actor wander
	var from: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var radial: Vector3 = target - from
	radial.y = 0.0
	if radial.length() <= 0.0001:
		return Vector3.ZERO
	radial = radial.normalized()
	var tangential: Vector3 = motion - radial * motion.dot(radial)
	if tangential.length() <= _BAND_TRACK_EPSILON:
		return Vector3.ZERO  # target moved straight at or away from us: that is the radial law's job
	return tangential.normalized()


## THE APPROACH DIRECTION, and the ONLY seam P33 touches. Everything below the returned vector
## -- the clamp, WalkableBounds, all eight displacement seams, the combat pipeline -- is
## untouched: avoidance changes what the AI ASKS FOR, never what legality permits.
func _pursuit_direction(actor_id: int, target: Vector3, events: Array[Event]) -> Vector3:
	var from: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var direct: Vector3 = target - from
	direct.y = 0.0
	direct = direct.normalized()
	if int(_ai_tuning.get(actor_id, {}).get("avoid_commit_ticks", 0)) <= 0:
		return direct  # this family authors no avoidance: ABSENCE IS OFF

	# THE COMMITTED LEG (ruled 2026-08-31 after play rejected the zig-zag).
	#
	# WHILE COMMITTED, THE WAYPOINT IS THE STEERING TARGET AND THE PLAYER IS ONLY THE COMBAT
	# TARGET. Those were the same thing before, and that identity was the defect: the sidestep
	# made the direct line look clear, `route_clear` dropped the leg, taking the direct line
	# re-obstructed it, and a new near-identical waypoint was chosen 2-3 ticks later. Live log:
	# waypoints 0.08 apart, cycling indefinitely. Every decision in that loop was locally correct,
	# which is why nothing caught it -- the loop lived in the TRANSITION, not in any one rule.
	#
	# `route_clear` IS DELIBERATELY NO LONGER AN EXIT. A direct line that opens mid-leg is exactly
	# the transient the sidestep itself created; acting on it is what closes the loop. The leg is
	# re-evaluated against the world when it ENDS, not while it is being walked.
	if _ai_avoid_waypoint.has(actor_id):
		var waypoint: Vector3 = _ai_avoid_waypoint[actor_id]
		var region: WalkableBounds = _legal_bounds_for(actor_id)
		var radius: float = _body_radius_for(actor_id)
		var reason: String = ""
		if tick_count >= int(_ai_avoid_deadline.get(actor_id, 0)):
			reason = "deadline"
		elif from.distance_to(waypoint) <= _AVOID_ARRIVAL_TOLERANCE:
			reason = "reached"
		elif region != null and (not region.fits(waypoint, radius) \
				or not _segment_is_clear(region, from, waypoint, radius, 0.0)):
			# The LEG ITSELF became impossible -- a gate shut across it, or the actor was
			# displaced somewhere the route no longer works from. That is a real invalidation,
			# unlike a passing direct line.
			reason = "leg_invalid"
		if reason.is_empty():
			var toward: Vector3 = waypoint - from
			toward.y = 0.0
			return toward.normalized()
		# The leg is over: fall through and assess the CURRENT world fresh, this tick.
		_clear_avoidance(actor_id, reason, events)

	if _direct_route_obstruction(actor_id, target).is_empty():
		return direct
	var chosen: Vector3 = _select_avoidance_waypoint(actor_id, target)
	if chosen == Vector3.ZERO:
		return direct  # nothing legal within the horizon: today's behaviour, honestly
	_ai_avoid_waypoint[actor_id] = chosen
	_ai_avoid_deadline[actor_id] = tick_count + int(_ai_tuning[actor_id]["avoid_commit_ticks"])
	# INSTRUMENTATION, not decoration: a behaviour that merely appears to work because an actor
	# slid somewhere useful is not this mechanic firing. The chain is observable in the log.
	events.append(Event.new(tick_count, "avoidance_committed", {
		"actor_id": actor_id, "waypoint": chosen, "deadline": _ai_avoid_deadline[actor_id],
	}))
	var toward_new: Vector3 = chosen - from
	toward_new.y = 0.0
	return toward_new.normalized()


func _clear_avoidance(actor_id: int, reason: String, events: Array[Event]) -> void:
	if not _ai_avoid_waypoint.has(actor_id):
		return
	_ai_avoid_waypoint.erase(actor_id)
	_ai_avoid_deadline.erase(actor_id)
	events.append(Event.new(tick_count, "avoidance_cleared", {"actor_id": actor_id, "reason": reason}))


## BURROW registration. ABSENCE IS OFF: a record exists only when content authors a usable
## burrow, so every other family and every hand-registered test enemy is untouched.
func _register_burrow(actor_id: int, jump_distance: float, jump_step_distance: float, underground_ticks: int, emergence_radius: float, emergence_retry_ticks: int, reacquisition_ticks: int, cooldown_ticks: int, close_frustration_ticks: int) -> void:
	_ai_burrow.erase(actor_id)
	if is_zero_approx(jump_distance) and is_zero_approx(jump_step_distance) and underground_ticks <= 0:
		return  # not authored at all
	if jump_distance <= 0.0 or jump_step_distance <= 0.0 or underground_ticks <= 0:
		push_warning("register_ai [actor %d]: burrow partially authored (jump %.2f, step %.2f, underground %d) -- treated as OFF" % [actor_id, jump_distance, jump_step_distance, underground_ticks])
		return
	if emergence_retry_ticks <= 0:
		push_warning("register_ai [actor %d]: burrow authored with no emergence retry window -- a single blocked tick would kill the actor by fail-safe" % actor_id)
	if close_frustration_ticks <= 0:
		push_warning("register_ai [actor %d]: burrow authored with close_frustration_ticks 0 -- the SELECTOR is therefore off for this actor (a zero patience means no selector, never instant frustration). The action remains reachable by the dev trigger." % actor_id)
	_ai_burrow[actor_id] = {
		"jump_distance": jump_distance,
		"jump_step_distance": jump_step_distance,
		"underground_ticks": underground_ticks,
		"emergence_radius": emergence_radius,
		"emergence_retry_ticks": emergence_retry_ticks,
		"reacquisition_ticks": reacquisition_ticks,
		"cooldown_ticks": cooldown_ticks,
	}


## THE BURROW SELECTOR (P17 final leg). Three derived conditions, no stored selection state.
##
## SIGNAL RULING: close-range frustration, and specifically NOT a health threshold (which says
## nothing about whether frontal engagement is working) or a post-flinch trigger (which would
## select around punishment rather than around inability to establish pressure).
##
## Why this signal survives the scurry autopsy: it measures the FANG'S OWN ACHIEVEMENT -- "did I
## reach close range" -- rather than the player's velocity. Scurry's detector measured RADIAL
## SEPARATION and was blind to diagonal kiting (radial speed 2.83 against Fang's 3.00 reads as
## the Fang successfully closing) and to circling (radial speed 0.00). This one is sensitive to
## every shape that actually denies engagement, and correctly stays quiet while the player
## circles in contact, because there engagement IS working.
##
## SHARED PRIMITIVE, NOT A FRAMEWORK (rule-of-two ruling): Watcher and Fang consume the same
## authoritative observation -- _close_frustration_satisfied / _refresh_close_proximity -- while
## their selection POLICIES stay family-specific. The primitive was renamed to be family-neutral
## and deliberately NOT broadened.
func _should_burrow(actor_id: int) -> bool:
	if not _ai_burrow.has(actor_id) or _burrow.has(actor_id):
		return false
	# Cooldown is an INDEPENDENT FLOOR, not the pacer. Under consumption-at-commitment the
	# episode is the primary limiter, so this may prove mostly inert -- which is exactly why
	# burrow_cooldown_ticks stays PROVISIONAL until ordinary play reports otherwise.
	if tick_count < int(_next_burrow_tick.get(actor_id, 0)):
		return false
	# A ZERO PATIENCE IS NOT "INSTANTLY FRUSTRATED" -- it means this family authors no selector.
	# _close_frustration_satisfied compares elapsed >= required, so a required of 0 is satisfied
	# on literally every tick, and a burrow-authoring actor with no authored patience would
	# commit one at its first opportunity forever. Absence is OFF, the same rule the rest of this
	# file follows; the inert 0 that Ooze and Watcher carry must stay inert.
	if int(_ai_tuning.get(actor_id, {}).get("close_frustration_ticks", 0)) <= 0:
		return false
	return _close_frustration_satisfied(actor_id)


## Read-only selector snapshot (AGENTS.md Invariable #2, and the scurry lesson made concrete:
## its detector was falsified by an autopsy that should have run before play). Reports every
## condition's LIVE value against its threshold, so a log answers "why did it not burrow"
## without re-deriving anything by hand.
func debug_describe_burrow_selection(actor_id: int, player_id: int) -> Dictionary:
	if not _ai_burrow.has(actor_id):
		return {"actor_id": actor_id, "authored": false}
	var required: int = int(_ai_tuning.get(actor_id, {}).get("close_frustration_ticks", 0))
	var last_close: int = int(_ai_last_in_close_band.get(actor_id, tick_count))
	var to_player: Vector3 = entities.get(player_id, Vector3.ZERO) - entities.get(actor_id, Vector3.ZERO)
	to_player.y = 0.0
	var spent: bool = _ai_last_frustration_commit.has(actor_id) and int(_ai_last_frustration_commit[actor_id]) > last_close
	return {
		"actor_id": actor_id,
		"authored": true,
		"distance": to_player.length(),
		"frustration_elapsed": tick_count - last_close,
		"frustration_required": required,
		"episode_spent": spent,
		"cooldown_remaining": maxi(0, int(_next_burrow_tick.get(actor_id, 0)) - tick_count),
		"would_select": _should_burrow(actor_id),
		"phase": String(_burrow[actor_id].phase) if _burrow.has(actor_id) else "idle",
	}


## STAGE 1 CONTROLLED TRIGGER (spec: validate an action before validating its selector). The
## scurry entangled action quality with selector quality -- its detector never recognised
## representative play, so the response was never cleanly judged. Burrow therefore fires ON
## DEMAND first and earns a selector only after a human verdict on the action itself.
##
## Returns false when the actor cannot start one, so a driver can report a no-op rather than
## silently doing nothing.
func debug_trigger_burrow(actor_id: int, player_id: int) -> bool:
	if not _ai_burrow.has(actor_id) or _burrow.has(actor_id):
		return false
	if _health.get(actor_id, 0.0) <= 0.0 or _combat_absent.has(actor_id):
		return false
	_begin_burrow_jump(actor_id, player_id)
	return true


## The selector's own commitment event is emitted at its gate; this exists so the DEBUG path is
## equally observable rather than quietly different.
func debug_burrow_commit_event(actor_id: int) -> Event:
	return Event.new(tick_count, "burrow_committed", {"actor_id": actor_id, "source": "debug", "frustration_elapsed": -1})


## JUMP: a large backward disengage, away from the player at commitment. Self-propelled, so it
## is abortable (see _abort_burrow_jump) -- unlike the P16 bump, which is imposed on its target
## and completes through a flinch.
func _begin_burrow_jump(actor_id: int, player_id: int) -> void:
	var config: Dictionary = _ai_burrow[actor_id]
	var position: Vector3 = entities.get(actor_id, Vector3.ZERO)
	var away: Vector3 = _normalize_horizontal(position - entities.get(player_id, Vector3.ZERO), _facings.get(actor_id, Vector3(0.0, 0.0, -1.0)))
	# CONSUMPTION AT COMMITMENT (ruled), identical to the Watcher's Survey and stamped in the ONE
	# place both the selector and the debug trigger pass through, so the two entry points can
	# never disagree about episode state.
	#
	# Consumption is DERIVED, never stored as a flag: `commit_tick <= last_close` means this
	# episode's burrow is unspent. So the Fang must genuinely RE-ENTER its close band before
	# another becomes available -- and because Fang's band is [0, 1.65] while emergence lands at
	# 2.0, EMERGENCE ITSELF DOES NOT CLEAR THE EPISODE. It must still close the last 0.35 units.
	# That is what makes "one burrow per unresolved close-frustration episode" structural rather
	# than tuned: a player who keeps retreating never lets the band be re-entered, so the episode
	# stays spent and no burrow spam is possible during that unresolved pursuit.
	_ai_last_frustration_commit[actor_id] = tick_count
	_burrow[actor_id] = {
		"phase": "jump",
		"direction": away,
		# Counted in STEPS, never against an end tick: the record is created during one tick's
		# decisions and first advances on the NEXT, which makes tick arithmetic off-by-one bait.
		"steps_remaining": maxi(1, ceili(float(config.jump_distance) / float(config.jump_step_distance))),
		"step_distance": float(config.jump_step_distance),
		"entry_position": position,
		"player_at_commit": entities.get(player_id, Vector3.ZERO),
		"deadline_tick": 0,
		"retry_deadline_tick": 0,
	}


## ANY successful authoritative FLINCH aborts the jump -- EXPLOIT or PRESSURE alike. Remaining
## movement is FORFEITED, and Fang NEVER transitions underground from an aborted jump: the
## submerge is a consequence of completing the disengage, not of having attempted it.
##
## Reachable only during the above-ground jump. Once underground the actor is unhittable, so
## there is no flinch to arrive.
func _abort_burrow_jump(actor_id: int) -> void:
	if not _burrow.has(actor_id) or String(_burrow[actor_id].phase) != "jump":
		return
	_end_burrow(actor_id)


## Clears every trace of a burrow. Called on completion, on abort, and from BOTH death sites.
##
## Called from both death sites deliberately: the hit-death path runs _clear_reaction_state but
## the STATUS-death path does not (a pre-existing asymmetry, left alone here rather than
## "fixed" as a side effect). Hanging burrow cleanup off that function alone would leak
## combat-absence on a Burn death -- leaving a living-then-dead Fang absent forever, which is
## precisely the soft-lock the emergence fail-safe exists to prevent.
func _end_burrow(actor_id: int) -> void:
	var config: Dictionary = _ai_burrow.get(actor_id, {})
	if _burrow.has(actor_id):
		_next_burrow_tick[actor_id] = tick_count + int(config.get("cooldown_ticks", 0))
	_burrow.erase(actor_id)
	_combat_absent.erase(actor_id)


## SUBMERGE. Everything that must stop being true about a present body happens here, once.
func _submerge(actor_id: int) -> Array[Event]:
	var burrow: Dictionary = _burrow[actor_id]
	var config: Dictionary = _ai_burrow[actor_id]
	_combat_absent[actor_id] = true
	# A windup committed before the burrow must not fire from underground.
	_cancel_enemy_windup(actor_id)
	# CONTACT EPISODES terminate at submerge (ruled), explicitly rather than by relying on the
	# stale-pair sweep noticing the overlap ended. Emergence therefore begins a FRESH episode,
	# so stale pair state can never suppress a valid post-emergence spread.
	for pair_key in _contact_transmitted_pairs.keys():
		if pair_key.x == actor_id or pair_key.y == actor_id:
			_contact_transmitted_pairs.erase(pair_key)
	burrow.phase = "underground"
	burrow.deadline_tick = tick_count + int(config.underground_ticks)
	burrow.retry_deadline_tick = burrow.deadline_tick + int(config.emergence_retry_ticks)
	return [Event.new(tick_count, "burrow_submerged", {"actor_id": actor_id})]


## The FIXED candidate set, in fixed order. Returns the first point that overlaps nothing, or an
## empty Dictionary when every candidate is blocked this tick.
##
## Fork C geometry: the far side of the player, relative to where Fang went under. Committed at
## burrow entry -- no underground retargeting and no blind-spot homing, so player movement after
## the tell can legitimately degrade the emergence. That is the counterplay.
func _find_burrow_emergence_point(actor_id: int) -> Dictionary:
	var burrow: Dictionary = _burrow[actor_id]
	var config: Dictionary = _ai_burrow[actor_id]
	var player_at_commit: Vector3 = burrow.player_at_commit
	var relation: Vector3 = player_at_commit - burrow.entry_position
	relation.y = 0.0
	var far_side: Vector3 = Vector3.ZERO
	if relation.length() < BURROW_FAR_SIDE_EPSILON:
		# DEGENERATE: Fang went under essentially on top of the player, so "far side" has no
		# meaning. Fall back to the opposite of the authored jump direction -- already committed
		# state at this moment, deterministic, and "came up the far side from where I leapt" is
		# coherent. No RNG, and no per-actor variation that would smuggle in de-correlation.
		far_side = -burrow.direction
	else:
		far_side = relation.normalized()
	for degrees in BURROW_CANDIDATE_DEGREES:
		var candidate: Vector3 = player_at_commit + far_side.rotated(Vector3.UP, deg_to_rad(degrees)) * float(config.emergence_radius)
		candidate.y = 0.0
		# PLACEMENT SEAM (M2) — emergence is placement, not displacement, so a candidate
		# outside the walkable floor is invalid for EXACTLY the same reason an occupied one
		# is, and is refused the same way: the fixed candidate set keeps rotating. The
		# deterministic ordering, the retry window, and the fail-safe death on exhaustion
		# (_resolve_burrow_emergence_timeout) are untouched — this adds a reason a candidate
		# can be rejected, never a new way to resolve emergence.
		if not _point_is_legal_for(actor_id, candidate):
			continue
		if not _burrow_point_is_occupied(actor_id, candidate):
			return {"position": candidate, "degrees": degrees}
	return {}


## Occupancy for a point rather than for a movement. _find_earliest_lunge_contact clamps MOTION;
## emergence is not motion, so this composes the same authoritative geometry (_contact_distance)
## into the missing question. Every living actor counts, allies included: materialising inside
## an ally is as illegal as materialising inside the Envoy.
func _burrow_point_is_occupied(actor_id: int, point: Vector3) -> bool:
	for other_id in _families.keys():
		if other_id == actor_id or _health.get(other_id, 0.0) <= 0.0 or _combat_absent.has(other_id):
			continue
		var offset: Vector3 = entities.get(other_id, Vector3.ZERO) - point
		offset.y = 0.0
		if offset.length() < _contact_distance(actor_id, other_id):
			return true
	return false


## THE AUTHORITATIVE BURROW PHASE. Advances even though ordinary AI is suspended -- suspension
## withholds an actor's own Commands, it does not pause a committed lifecycle.
func _advance_burrow() -> Array[Event]:
	var events: Array[Event] = []
	var actor_ids: Array = _burrow.keys()
	actor_ids.sort()
	for actor_id in actor_ids:
		if _health.get(actor_id, 0.0) <= 0.0:
			continue  # death cleanup owns this actor now
		var burrow: Dictionary = _burrow[actor_id]
		match String(burrow.phase):
			"jump":
				var start: Vector3 = entities.get(actor_id, Vector3.ZERO)
				var end: Vector3 = start + burrow.direction * float(burrow.step_distance)
				var contact: Dictionary = _find_earliest_lunge_contact(start, end, actor_id)
				# BOUNDS SEAM 6/6 — burrow backward-jump displacement.
				entities[actor_id] = _clamp_to_bounds(actor_id, start, contact.entry_position if not contact.is_empty() else end)
				_facings[actor_id] = burrow.direction
				burrow.steps_remaining = int(burrow.steps_remaining) - 1
				if not contact.is_empty() or int(burrow.steps_remaining) <= 0:
					events.append_array(_submerge(actor_id))
			"underground":
				if tick_count < int(burrow.deadline_tick):
					continue
				var spot: Dictionary = _find_burrow_emergence_point(actor_id)
				if spot.is_empty():
					if tick_count < int(burrow.retry_deadline_tick):
						continue  # stay under; never emerge overlapping a collidable actor
					events.append_array(_resolve_burrow_emergence_timeout(actor_id))
					continue
				entities[actor_id] = spot.position
				_facings[actor_id] = _normalize_horizontal(burrow.player_at_commit - spot.position, burrow.direction)
				_combat_absent.erase(actor_id)
				burrow.phase = "reacquisition"
				burrow.deadline_tick = tick_count + int(_ai_burrow[actor_id].reacquisition_ticks)
				events.append(Event.new(tick_count, "burrow_emerged", {"actor_id": actor_id, "position": spot.position}))
			"reacquisition":
				if tick_count >= int(burrow.deadline_tick):
					_end_burrow(actor_id)
	return events


## THE HAZARD TICK. Phase is a pure function of tick_count, so two machines running the same
## floor agree without exchanging anything -- which is what makes this replayable for M3.
##
## DAMAGE IS APPLIED EVERY ACTIVE TICK an actor stands on the pad, and i-frames do the rest:
## the first tick lands, the i-frame window swallows the next several, and the cadence falls out
## of the defensive law already in place. That is deliberate -- a hazard-specific damage interval
## would be a second timing system saying the same thing, and the two would eventually disagree.
func _advance_hazards() -> Array[Event]:
	var events: Array[Event] = []
	var pad_ids: Array = _spike_pads.keys()
	pad_ids.sort()
	for pad_id: int in pad_ids:
		var pad: Dictionary = _spike_pads[pad_id]
		var active: bool = _spike_pad_is_active(pad_id)
		if active != bool(pad["was_active"]):
			pad["was_active"] = active
			events.append(Event.new(tick_count, "hazard_phase_changed", {
				"pad_id": pad_id, "active": active,
			}))
		if not active:
			continue
		var actor_ids: Array = _health.keys()
		actor_ids.sort()
		for actor_id: int in actor_ids:
			if _health.get(actor_id, 0.0) <= 0.0 or _combat_absent.has(actor_id):
				continue
			var position: Vector3 = entities.get(actor_id, Vector3.ZERO)
			if not WalkableBounds.contains(pad["rect"], position.x, position.z):
				continue
			events.append_array(_resolve_hit_on_target(
				-1, actor_id, _hazard_profile(pad), Vector3(0.0, 0.0, 1.0), "spike_pad",
				"", -1, SOURCE_ENVIRONMENT))
	return events


## Pure function of the tick: no stored timer, nothing to fall out of sync, and identical on
## every machine that reaches this tick with this floor loaded.
func _spike_pad_is_active(pad_id: int) -> bool:
	var pad: Dictionary = _spike_pads[pad_id]
	var cycle: int = int(pad["safe_ticks"]) + int(pad["active_ticks"])
	return posmod(tick_count + int(pad["phase_offset"]), cycle) >= int(pad["safe_ticks"])


## The hazard's damage PROFILE, in the shape the pipeline already consumes. Knockback is zero --
## spikes are underfoot, not a blow from a direction -- and it grants no flinch and feeds no
## pressure ledger, because neither belongs to a floor.
func _hazard_profile(pad: Dictionary) -> Dictionary:
	return {
		"damage": pad["damage"], "damage_type": pad["damage_type"],
		"knockback_distance": 0.0, "contributes_pressure": false,
		"flinch_capability": "none", "interrupt_strength": 0,
	}


## Read-only hazard snapshot (AGENTS.md Invariable #2: every mechanic must be observable).
func debug_describe_spike_pad(pad_id: int) -> Dictionary:
	if not _spike_pads.has(pad_id):
		return {}
	var pad: Dictionary = _spike_pads[pad_id]
	var cycle: int = int(pad["safe_ticks"]) + int(pad["active_ticks"])
	return {
		"pad_id": pad_id, "active": _spike_pad_is_active(pad_id),
		"ticks_into_cycle": posmod(tick_count + int(pad["phase_offset"]), cycle),
		"cycle_ticks": cycle,
	}


## RETRY WINDOW EXHAUSTED. P17 authored this under open-arena scope, where every emergence
## candidate being blocked was supposed to be unreachable, so the only resolution was a loud
## death -- strictly better than a living Fang left absent forever.
##
## FLOORS PRODUCED A REAL CONSUMER (ruled 2026-09-03). A committed destination can become
## invalid for ordinary world reasons: the player retreats behind a gate that shuts, stands
## where this body does not fit, or is ringed by other actors. Killing an enemy for a room
## layout is not a fail-safe, it is a defect with a warning attached -- the human watched a Fang
## vanish and read it, correctly, as a bug.
##
## SO THERE ARE NOW TWO OUTCOMES, and the second one means something narrower than it used to.
##
## FIRST FALLBACK — ABORT TO THE BURROW ENTRY. "The burrow failed; it comes back where it
## started." The entry is committed historical state, so this is deterministic, needs no search,
## retargets nothing underground, and can place the actor nowhere surprising. Occupancy is still
## checked: the whole point of the retry window is that nothing emerges inside another body.
##
## FINAL FAIL-SAFE — the loud death is KEPT, but now fires only when the authored candidates AND
## the deterministic abort destination are all impossible. That is a genuinely degenerate world
## state rather than an ordinary obstruction, which is what the original comment assumed it was.
func _resolve_burrow_emergence_timeout(actor_id: int) -> Array[Event]:
	var entry: Vector3 = _burrow[actor_id].entry_position
	if _point_is_legal_for(actor_id, entry) and not _burrow_point_is_occupied(actor_id, entry):
		entities[actor_id] = entry
		_combat_absent.erase(actor_id)
		_end_burrow(actor_id)
		return [Event.new(tick_count, "burrow_aborted", {"actor_id": actor_id, "position": entry})]

	push_warning(("burrow_emergence_timeout [actor %d]: every authored emergence candidate stayed blocked "
		+ "for the full retry window AND the burrow entry at %s is itself no longer a legal, unoccupied "
		+ "placement. Both the authored emergence and the deterministic abort destination are impossible, "
		+ "so the actor dies underground rather than emerging illegally or remaining absent forever. This "
		+ "is a placement-invariant failure, not a tuning outcome.") % [actor_id, entry])
	_health[actor_id] = 0.0
	_end_burrow(actor_id)
	var events: Array[Event] = [Event.new(tick_count, "died", {"actor_id": actor_id})]
	events.append_array(_clear_attack_input_state(actor_id))
	_clear_clamps_targeting(actor_id)
	_clear_reaction_state(actor_id)
	_status_instances.erase(actor_id)
	return events


## Read-only burrow snapshot (AGENTS.md Invariable #2: every mechanic must be observable).
func debug_describe_burrow(actor_id: int) -> Dictionary:
	if not _ai_burrow.has(actor_id):
		return {"actor_id": actor_id, "authored": false}
	if not _burrow.has(actor_id):
		return {"actor_id": actor_id, "authored": true, "phase": "idle", "combat_absent": _combat_absent.has(actor_id)}
	var burrow: Dictionary = _burrow[actor_id]
	return {
		"actor_id": actor_id,
		"authored": true,
		"phase": String(burrow.phase),
		"combat_absent": _combat_absent.has(actor_id),
		"ticks_to_deadline": maxi(0, int(burrow.deadline_tick) - tick_count),
	}


## P29 ACTION SELECTOR — the AI's one new power, and deliberately its only one: "which of
## my authored actions applies at this distance". No RNG, no scoring, no priority, no
## array-order tiebreak. Returns "" when nothing applies.
##
## BOUNDARY CONVENTION (ruled): non-terminal bands are HALF-OPEN [min, max); only the
## terminal band (largest max_range, derived in register_ai) includes its own maximum. A
## closed interval on both ends would let adjacent authored bands BOTH match at the
## shared edge, which is exactly the ambiguity the overlap law forbids. No epsilon and no
## tie-breaking: content must satisfy next.min_range == prev.max_range exactly.
##
## Consequence worth stating: a SINGLE-action repertoire is by definition terminal, so
## its band is [0.0, max] inclusive at both ends — byte-identical to the pre-P29
## `distance <= preferred_attack_distance` gate. That equivalence is what
## tests/test_ai_backward_compat.gd exists to hold.
##
## "" (nothing applies) is NOT a state. It is the same condition as being outside the
## family's overall attackable range: the caller's gate simply fails and ordinary
## actor-level locomotion continues. Under v1's gapless content it is only reachable
## beyond the terminal max; a future authored interior dead band makes it reachable
## inside engagement range with no code change here.
func _select_action(actor_id: int, distance: float) -> String:
	for action in _ai_repertoire.get(actor_id, []):
		if not band_contains(action, distance):
			continue
		if bool(action.requires_close_frustration) and not _close_frustration_satisfied(actor_id):
			# Eligible by RANGE, not by CONTEXT. Returning "" reuses the already-specified,
			# already-tested "no action applies" path: ordinary locomotion continues, which
			# IS "resume movement/decision" -- no new AI state, and no immediate cycling.
			return ""
		return String(action.id)
	return ""


## Close-frustration gate for the ONE action that authors it (watcher_survey). Two
## questions, both answered from literal facts:
##   1. Has this actor been unable to reach close range for its family's patience?
##   2. Is this failed-close episode's single fallback still unspent?
##
## Episode consumption is DERIVED, never stored: a survey committed more recently than the
## last moment of genuine close range means this episode already spent its fallback. Because
## re-entering close range refreshes the proximity fact to *now*, an episode clears itself
## with no explicit reset and no flag to fall out of sync.
##
## CONSUMPTION IS AT COMMITMENT (locked): interrupting a committed survey does NOT restore
## the opportunity. The Watcher spent its fallback by committing; a new one requires genuine
## close-range re-establishment followed by a fresh failed-close episode.
func _close_frustration_satisfied(actor_id: int) -> bool:
	var required: int = int(_ai_tuning.get(actor_id, {}).get("close_frustration_ticks", 0))
	# Default to tick_count (zero elapsed) rather than 0: an actor with no recorded
	# proximity fact must read as NOT frustrated, never as maximally frustrated.
	var last_close: int = int(_ai_last_in_close_band.get(actor_id, tick_count))
	if tick_count - last_close < required:
		return false
	# has(), not a sentinel: any numeric "never committed" default can compare GREATER than
	# a legitimately smaller last_close and read as consumed. Absence is the honest test.
	if not _ai_last_frustration_commit.has(actor_id):
		return true
	return int(_ai_last_frustration_commit[actor_id]) <= last_close


## THE band-eligibility predicate — half-open [min, max) unless terminal, then [min, max].
## Public and extracted deliberately: the content lint that enforces GAME-RULES §3's
## "authored bands may not overlap" must test the SAME notion of eligibility the selector
## uses, or the law and its enforcement drift apart and the lint starts approving
## repertoires the selector treats as ambiguous. One predicate, both callers.
static func band_contains(action: Dictionary, distance: float) -> bool:
	if distance < float(action.min_range):
		return false
	if distance < float(action.max_range):
		return true
	return bool(action.is_terminal) and distance <= float(action.max_range)


## Read-only action-selection snapshot (AGENTS.md Invariable #2: every mechanic must be
## observable). Exists specifically so an accidental band GAP is diagnosable on sight
## instead of presenting as "the enemy mysteriously stopped attacking" — it reports the
## live distance and, when nothing is eligible, the nearest authored band edge. Never
## called from sim itself; the scene driver polls it behind a debug_* export.
func debug_describe_action_selection(actor_id: int, player_id: int) -> Dictionary:
	if not _ai_repertoire.has(actor_id):
		return {}
	var to_player: Vector3 = entities.get(player_id, Vector3.ZERO) - entities.get(actor_id, Vector3.ZERO)
	to_player.y = 0.0
	var distance: float = to_player.length()
	var selected: String = _select_action(actor_id, distance)
	var description: Dictionary = {
		"actor_id": actor_id,
		"distance": distance,
		"selected": selected,
		"state": _ai_state.get(actor_id, "idle"),
	}
	if selected == "":
		var nearest_id: String = ""
		var nearest_gap: float = INF
		for action in _ai_repertoire[actor_id]:
			var gap: float = maxf(float(action.min_range) - distance, distance - float(action.max_range))
			if gap < nearest_gap:
				nearest_gap = gap
				nearest_id = "%s [%.2f, %.2f]" % [action.id, action.min_range, action.max_range]
		description["nearest_band"] = nearest_id
		description["distance_to_nearest_band"] = nearest_gap
	return description


## In-range attack timing — two nullable tick fields, not a distinct "windup" state
## (locked). Reuses the shared per-actor fire-rate gate (_next_fire_tick, the same
## one _apply_attack already checks) instead of a second AI-owned cooldown dict, so
## an enemy can't start a new windup before fire_interval_ticks has elapsed from its
## last actual attack. P29 RULING: that gate stays SHARED ACROSS THE REPERTOIRE for v1 —
## firing any action cools down every action. Revisit trigger at ROADMAP P29.
##
## selected_action_id is "" on the fire-side call (the action was already committed at
## windup start and must never be re-selected — see the commitment block below).
func _decide_attack_commands(actor_id: int, selected_action_id: String, player_id: int, events: Array[Event]) -> Array[Command]:
	if _ai_attack_fire_tick.has(actor_id):
		if tick_count < _ai_attack_fire_tick[actor_id]:
			return []  # still winding up
		_ai_attack_start_tick.erase(actor_id)
		_ai_attack_fire_tick.erase(actor_id)
		# AIM CAPTURE (locked, and load-bearing for P29's ranged action): aim is sampled
		# HERE, at the fire tick, toward the player's THEN-CURRENT position -- never at
		# commit time. A long windup would make commit-time aim stale before the shot
		# left, turning a readable attack into one that is unavoidable or trivial purely
		# by whether the player happened to move. The windup communicates WHEN the attack
		# fires; travel time supplies the dodge. Projectile direction is then fixed at
		# spawn and never steers (no seeking -- ROADMAP P17).
		var stored_facing: Vector3 = _facings.get(actor_id, Vector3(0.0, 0.0, -1.0))
		var aim: Vector3 = _normalize_horizontal(entities.get(player_id, Vector3.ZERO) - entities.get(actor_id, Vector3.ZERO), stored_facing)
		return [Command.new(tick_count, actor_id, "attack", {"aim": aim})]

	if tick_count < _next_fire_tick.get(actor_id, 0):
		return []  # shared repertoire cooldown from the last attack hasn't elapsed yet
	if selected_action_id == "":
		return []  # no authored action covers this distance

	# COMMITMENT (P29). Re-equipping IS the commitment: _equipped_weapon is already "which
	# authored attack shape resolves this actor's attack Command", and _flinch_mode_of,
	# _cancel_enemy_windup and _apply_attack all read it. So per-action susceptibility
	# windows, per-action cooldown arming on interrupt, and melee-vs-projectile resolution
	# all follow from this one assignment -- no parallel "committed action" record, and
	# Command.params stays per-tick intent ({aim}), never an id.
	#
	# A committed action NEVER re-evaluates: distance changing mid-windup does not swap it
	# (the same locked rule that already forbids mid-windup cancellation). Walking out of
	# the band produces an attack that may simply MISS -- a miss, not a cancellation.
	set_equipped_weapon(actor_id, selected_action_id)
	var windup_ticks: int = 0
	for action in _ai_repertoire.get(actor_id, []):
		if String(action.id) == selected_action_id:
			windup_ticks = int(action.windup_ticks)
			# LITERAL COMMITMENT FACT -- stamped at COMMIT, which is what makes an
			# interrupted survey still consume the episode with no un-stamp path.
			if bool(action.requires_close_frustration):
				_ai_last_frustration_commit[actor_id] = tick_count
			break
	_ai_attack_start_tick[actor_id] = tick_count
	_ai_attack_fire_tick[actor_id] = tick_count + windup_ticks
	var damage_type: String = _weapons.get(selected_action_id, {}).get("damage_type", "force")
	events.append(Event.new(tick_count, "attack_telegraph", {
		"actor_id": actor_id, "damage_type": damage_type, "action_id": selected_action_id,
	}))
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
		if _allegiance.get(source_actor_id, &"enemy") == &"player":
			_acquire_aggro(target_id)
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

	# RULED (P17 burrow): Burn CONTINUES ticking underground -- _advance_status_ticks is
	# deliberately untouched -- but contact SPREAD does not occur, because a body that is not
	# spatially present cannot be in contact with anything. Visibility does not answer either
	# question; both are explicit rulings.
	var alive_ids: Array = _families.keys().filter(func(id): return _health.get(id, 0.0) > 0.0 and not _combat_absent.has(id))
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
				# Burn is the ONLY route to death underground (an absent actor cannot be hit), so
				# this site must clear burrow state too. It does NOT call _clear_reaction_state --
				# a pre-existing asymmetry with the hit-death path, deliberately left alone rather
				# than changed as a side effect -- which is exactly why burrow cleanup lives in its
				# own helper called from both sites instead of riding on that function.
				_end_burrow(actor_id)
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
