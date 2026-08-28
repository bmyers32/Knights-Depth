extends GutTest
## P29 — enemy action repertoire / distance-conditioned action selection.
##
## Covers the selector's boundary convention, commitment, and the per-action reaction
## semantics that follow from it. The M1-preservation gate lives separately in
## tests/test_ai_backward_compat.gd; band CONTENT invariants live in
## tests/test_content_validation.gd.

var sim: SimWorld

const PLAYER_ID := 0
const ENEMY_ID := 1
const NEAR := &"near_action"
const FAR := &"far_action"

const NEAR_MAX := 2.0
const FAR_MAX := 9.0
const NEAR_WINDUP := 6
const FAR_WINDUP := 14


func _register_player(s: SimWorld, position: Vector3) -> void:
	s.add_entity(PLAYER_ID, position, 4.0)
	s.register_combatant(PLAYER_ID, 200.0, &"envoy", 0, 0.4, &"player")


## Two-action fixture mirroring the Watcher's authored shape: a melee band and a
## PROJECTILE band that tile with no overlap and no gap.
##   near [0.0, 2.0)   melee
##   far  [2.0, 9.0]   projectile, terminal
func _register_two_action_enemy(s: SimWorld, position: Vector3, reversed: bool = false) -> void:
	s.add_entity(ENEMY_ID, position, 0.0)  # speed 0: isolate SELECTION from locomotion
	s.register_combatant(ENEMY_ID, 500.0, &"watcher", 0, 0.85, &"enemy")
	s.register_weapon(NEAR, 8.0, &"force", NEAR_MAX, 90.0, 0.0, 20)
	s.register_gun(FAR, 6.0, &"force", 7.0, 60, 0.5, 0.0, 20)
	var near_entry: Dictionary = {"id": NEAR, "min_range": 0.0, "max_range": NEAR_MAX, "windup_ticks": NEAR_WINDUP}
	var far_entry: Dictionary = {"id": FAR, "min_range": NEAR_MAX, "max_range": FAR_MAX, "windup_ticks": FAR_WINDUP}
	var repertoire: Array[Dictionary] = []
	repertoire.assign([far_entry, near_entry] if reversed else [near_entry, far_entry])
	s.register_ai(ENEMY_ID, repertoire, position, 1.5, 0.0, 50.0, 100.0)
	s.debug_set_ai_active(ENEMY_ID)


func _tick(s: SimWorld, times: int) -> Array[Event]:
	var all_events: Array[Event] = []
	for _i in times:
		all_events.append_array(s.tick([], 1.0 / 30.0))
	return all_events


func _telegraphed_action(events: Array[Event]) -> String:
	for event in events:
		if event.kind == "attack_telegraph":
			return String(event.payload.get("action_id", ""))
	return ""


# --- selection --------------------------------------------------------------------

func test_distance_selects_the_action_whose_band_contains_it() -> void:
	sim = _make_at(1.0)
	assert_eq(_telegraphed_action(_tick(sim, 1)), String(NEAR), "1.0 lies in the near band")

	sim = _make_at(6.4)
	assert_eq(_telegraphed_action(_tick(sim, 1)), String(FAR), "6.4 lies in the far band")


## THE POINT of the non-overlap law: with no distance matching two bands, array order
## carries no information, so a shuffled repertoire cannot change any decision. If this
## ever fails, a hidden priority has crept in.
func test_repertoire_order_is_semantically_meaningless() -> void:
	for distance in [0.5, 1.999, 2.0, 5.0, 9.0]:
		var forward := SimWorld.new()
		_register_player(forward, Vector3.ZERO)
		_register_two_action_enemy(forward, Vector3(0, 0, -distance), false)
		var backward := SimWorld.new()
		_register_player(backward, Vector3.ZERO)
		_register_two_action_enemy(backward, Vector3(0, 0, -distance), true)
		for i in 40:
			var a: Array[Event] = forward.tick([], 1.0 / 30.0)
			var b: Array[Event] = backward.tick([], 1.0 / 30.0)
			assert_eq(a.size(), b.size(), "distance %.3f tick %d: event count must match" % [distance, i])
			for j in a.size():
				assert_eq(a[j].kind, b[j].kind, "distance %.3f tick %d" % [distance, i])
				assert_eq(a[j].payload, b[j].payload, "distance %.3f tick %d" % [distance, i])


# --- boundary convention ----------------------------------------------------------
# Half-open [min, max) for every NON-TERMINAL band; only the terminal band (largest
# max_range) includes its own maximum. Without this, both bands would match at exactly
# 2.0 and v1's own content would violate the overlap law.

func test_shared_edge_belongs_to_the_upper_band() -> void:
	sim = _make_at(NEAR_MAX)
	assert_eq(_telegraphed_action(_tick(sim, 1)), String(FAR),
		"exactly max_range of a NON-terminal band belongs to the next band up, never both")


func test_just_below_the_shared_edge_belongs_to_the_lower_band() -> void:
	sim = _make_at(NEAR_MAX - 0.001)
	assert_eq(_telegraphed_action(_tick(sim, 1)), String(NEAR))


func test_terminal_band_includes_its_own_maximum() -> void:
	sim = _make_at(FAR_MAX)
	assert_eq(_telegraphed_action(_tick(sim, 1)), String(FAR),
		"the outermost band is inclusive at its max -- this is what makes a single-action repertoire's [0, max] match the pre-P29 `distance <= preferred` gate exactly")


func test_beyond_the_terminal_band_no_action_is_eligible() -> void:
	sim = _make_at(FAR_MAX + 0.001)
	assert_eq(_telegraphed_action(_tick(sim, 1)), "", "past the terminal max, nothing applies")


## Gap fall-through, tested NOW even though v1 content is gapless: the provisional
## no-gaps lint is documented as removable without adding behaviour machinery, and this
## is the test that proves the claim. A gap must behave exactly like being out of range —
## no telegraph, no new state, ordinary locomotion continues.
func test_interior_band_gap_falls_through_to_ordinary_locomotion() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3.ZERO)
	sim.add_entity(ENEMY_ID, Vector3(0, 0, -3.0), 2.0)
	sim.register_combatant(ENEMY_ID, 100.0, &"watcher", 0, 0.85, &"enemy")
	sim.register_weapon(NEAR, 8.0, &"force", 1.0, 90.0, 0.0, 20)
	sim.register_gun(FAR, 6.0, &"force", 7.0, 60, 0.5, 0.0, 20)
	# Deliberate dead band between 1.0 and 5.0; the enemy sits at 3.0, inside it.
	var repertoire: Array[Dictionary] = [
		{"id": NEAR, "min_range": 0.0, "max_range": 1.0, "windup_ticks": NEAR_WINDUP},
		{"id": FAR, "min_range": 5.0, "max_range": 9.0, "windup_ticks": FAR_WINDUP},
	]
	sim.register_ai(ENEMY_ID, repertoire, Vector3(0, 0, -3.0), 1.5, 0.0, 50.0, 100.0)
	sim.debug_set_ai_active(ENEMY_ID)

	var events: Array[Event] = _tick(sim, 5)
	assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 0,
		"no action covers this distance, so nothing may be telegraphed")
	assert_gt(events.filter(func(e): return e.kind == "moved").size(), 0,
		"ordinary locomotion must continue -- a gap is NOT a new AI state, it is the same condition as out-of-range")
	assert_eq(sim._ai_state[ENEMY_ID], "active", "and it must not disengage either")


# --- commitment -------------------------------------------------------------------

## Once wound up the action is FIXED. This is the existing locked "windup runs to
## completion" rule extended to action identity: distance changing mid-windup must not
## silently swap which attack lands.
func test_committed_action_never_re_evaluates_when_distance_changes() -> void:
	sim = _make_at(6.4)
	var start: Array[Event] = _tick(sim, 1)
	assert_eq(_telegraphed_action(start), String(FAR), "sanity: committed to the far action")

	sim.entities[PLAYER_ID] = Vector3(0, 0, -5.4)  # now 1.0 away -- deep in the NEAR band
	var events: Array[Event] = _tick(sim, FAR_WINDUP + 2)
	assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 0,
		"no SECOND telegraph -- this is the original commitment completing, not a fresh choice")
	assert_eq(events.filter(func(e): return e.kind == "projectile_fired").size(), 1,
		"the committed FAR (projectile) action must resolve, even though the player now stands in the near band")


func test_commitment_equips_the_selected_action() -> void:
	sim = _make_at(6.4)
	_tick(sim, 1)
	assert_eq(sim._equipped_weapon[ENEMY_ID], String(FAR),
		"commitment IS the re-equip -- that is what makes susceptibility, cooldown arming and resolution all follow the chosen action")


## Shared per-actor cooldown (P29 ruling for v1): firing ANY action cools down the whole
## repertoire. Revisit trigger is filed at ROADMAP P29.
func test_firing_one_action_cools_down_the_whole_repertoire() -> void:
	sim = _make_at(6.4)
	_tick(sim, FAR_WINDUP + 1)  # commit and fire the far action (fire_interval 20)
	var fired_at: int = sim.tick_count - 1

	sim.entities[ENEMY_ID] = Vector3(0, 0, -1.0)  # now inside the NEAR band
	var during: Array[Event] = _tick(sim, 10)
	assert_eq(during.filter(func(e): return e.kind == "attack_telegraph").size(), 0,
		"the near action must be gated by the cooldown the FAR action armed -- one shared _next_fire_tick")
	assert_gt(sim._next_fire_tick[ENEMY_ID], fired_at, "sanity: a cooldown was actually armed")

	var after: Array[Event] = _tick(sim, 15)
	assert_eq(_telegraphed_action(after), String(NEAR), "once the shared cooldown elapses the near action becomes available")


# --- per-action reaction semantics -------------------------------------------------

## A weak, long-reach player attack that can trigger a flinch. register_weapon's flat
## path carries no flinch params, so the resolved profile is patched directly -- the same
## approach tests/test_flinch.gd uses, kept identical rather than invented here.
func _register_interrupter(s: SimWorld, capability: String = "exploit") -> void:
	s.set_damage_matrix({}, 1.5, 0.5)
	s.register_weapon(&"punisher", 1.0, &"force", 12.0, 180.0, 0.0, 0, &"", 0.0)
	s._weapons["punisher"].flinch_capability = capability
	s.set_equipped_weapon(PLAYER_ID, &"punisher")


## Susceptibility is owned by the COMMITTED action, by construction: _flinch_mode_of
## reads _action_susceptibility[_equipped_weapon[actor]]. Same tick offset, two actions,
## two different outcomes.
func test_vulnerable_window_is_scoped_to_the_committed_action() -> void:
	# Only the FAR action carries a window, at offsets 10..14.
	var offset := 11

	var far_sim := SimWorld.new()
	_register_player(far_sim, Vector3.ZERO)
	_register_two_action_enemy(far_sim, Vector3(0, 0, -6.4))
	far_sim.register_flinch_profile(ENEMY_ID, 9999.0)  # pressure route unreachable: isolate the window
	far_sim.set_flinch_tuning(90, 20)
	far_sim.register_action_susceptibility(FAR, &"normal", 10, 14)
	_register_interrupter(far_sim)
	far_sim.tick([], 1.0 / 30.0)  # commit
	_tick(far_sim, offset - 1)
	var far_events: Array[Event] = far_sim.tick([Command.new(far_sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(far_events.filter(func(e): return e.kind == "flinched").size(), 1,
		"inside the FAR action's authored window, a weak hit must cash out via EXPLOIT")

	var near_sim := SimWorld.new()
	_register_player(near_sim, Vector3.ZERO)
	_register_two_action_enemy(near_sim, Vector3(0, 0, -1.0))
	near_sim.register_flinch_profile(ENEMY_ID, 9999.0)
	near_sim.set_flinch_tuning(90, 20)
	near_sim.register_action_susceptibility(FAR, &"normal", 10, 14)  # same content, other action
	_register_interrupter(near_sim)
	near_sim.tick([], 1.0 / 30.0)
	_tick(near_sim, offset - 1)
	var near_events: Array[Event] = near_sim.tick([Command.new(near_sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(near_events.filter(func(e): return e.kind == "flinched").size(), 0,
		"the NEAR action authored no window, so the identical hit at the identical offset must NOT flinch -- windows never leak between actions")


func test_interrupting_a_ranged_windup_spawns_no_projectile() -> void:
	sim = _make_at(6.4)
	sim.register_flinch_profile(ENEMY_ID, 9999.0)
	sim.set_flinch_tuning(90, 20)
	sim.register_action_susceptibility(FAR, &"normal", 0, FAR_WINDUP)
	_register_interrupter(sim)
	sim.tick([], 1.0 / 30.0)  # commit

	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "windup_interrupted").size(), 1)
	events.append_array(_tick(sim, FAR_WINDUP + 5))
	assert_eq(events.filter(func(e): return e.kind == "projectile_fired").size(), 0,
		"a windup cancelled before its fire tick must never produce a shot")


## The mirror image, and the locked boundary: flinch cancels ACTION state, not combat
## entities that already exist (sim_world.gd's FLINCHED comment; BRAIN candidate
## principle 7). A shot already in flight is not recalled.
func test_flinching_after_the_shot_does_not_recall_the_projectile() -> void:
	sim = _make_at(6.4)
	sim.register_flinch_profile(ENEMY_ID, 0.5)  # trivially cashable pressure route
	sim.set_flinch_tuning(90, 20)
	_register_interrupter(sim, "pressure")

	var events: Array[Event] = _tick(sim, FAR_WINDUP + 1)
	assert_eq(events.filter(func(e): return e.kind == "projectile_fired").size(), 1, "sanity: the shot left")

	# Land two hits to bank pressure and cash it while the shot is still travelling.
	var after: Array[Event] = []
	for _i in 3:
		after.append_array(sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0))
	assert_gt(after.filter(func(e): return e.kind == "flinched").size(), 0, "sanity: the Watcher was flinched mid-flight")
	assert_eq(sim._projectiles.size(), 1, "the in-flight shot must be untouched -- flinch cancels action STATE, never an entity that already exists")


## An interrupted action arms ITS OWN cooldown, not some other action's.
func test_cancelled_action_arms_its_own_cooldown() -> void:
	sim = _make_at(6.4)
	sim.register_gun(FAR, 6.0, &"force", 7.0, 60, 0.5, 0.0, 77)  # distinctive fire_interval
	sim.register_flinch_profile(ENEMY_ID, 9999.0)
	sim.set_flinch_tuning(90, 20)
	sim.register_action_susceptibility(FAR, &"normal", 0, FAR_WINDUP)
	_register_interrupter(sim)
	sim.tick([], 1.0 / 30.0)

	var interrupt_tick: int = sim.tick_count
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(sim._next_fire_tick[ENEMY_ID], interrupt_tick + 77,
		"the cooldown must come from the action that was actually committed and cancelled")


func test_a_ranged_action_passes_through_allies_without_expiring() -> void:
	sim = _make_at(6.4)
	sim.add_entity(2, Vector3(0, 0, -3.0), 0.0)  # ally directly on the firing line
	sim.register_combatant(2, 50.0, &"fang", 0, 0.9, &"enemy")

	var events: Array[Event] = _tick(sim, FAR_WINDUP + 1)
	assert_eq(events.filter(func(e): return e.kind == "projectile_fired").size(), 1)
	# 6.4 units at speed 7.0 is ~27 ticks of travel; 40 leaves margin without being vague.
	var travel: Array[Event] = _tick(sim, 40)
	assert_eq(travel.filter(func(e): return e.kind == "hit" and e.payload.get("target_id") == 2).size(), 0,
		"allies are never candidates -- no mutual bullet shields between enemies")
	assert_gt(travel.filter(func(e): return e.kind == "hit" and e.payload.get("target_id") == PLAYER_ID).size(), 0,
		"and the shot must carry on to the real target")


# --- P16 x P29 composition ---------------------------------------------------------

## BUMP displaces a Watcher mid-windup. Displacement is not an interrupt: the committed
## action, its start tick and its fire tick all stand, the windup simply finishes from
## somewhere else. Nothing forfeits "remaining distance" because a ranged action authors
## no attack movement to forfeit.
func test_bump_during_a_committed_windup_moves_the_actor_not_the_timeline() -> void:
	sim = _make_at(2.5)
	sim.tick([], 1.0 / 30.0)  # commit the far action
	var start_tick: int = int(sim._ai_attack_start_tick[ENEMY_ID])
	var fire_tick: int = int(sim._ai_attack_fire_tick[ENEMY_ID])
	var position_before: Vector3 = sim.entities[ENEMY_ID]

	sim.register_shield(PLAYER_ID, 20.0, 0.0, 30, 0.0, 3.0, 2.0, 5, 0, 0, 0, 1.0)
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "block", {"held": true})], 1.0 / 30.0)
	_tick(sim, 5)  # let the authored slide finish

	assert_ne(sim.entities[ENEMY_ID], position_before, "sanity: the bump actually displaced it")
	assert_eq(int(sim._ai_attack_start_tick[ENEMY_ID]), start_tick, "a bump must not restart the windup")
	assert_eq(int(sim._ai_attack_fire_tick[ENEMY_ID]), fire_tick, "nor delay or advance its fire tick")
	assert_eq(sim._equipped_weapon[ENEMY_ID], String(FAR), "nor re-select the committed action")

	var events: Array[Event] = _tick(sim, FAR_WINDUP)
	assert_eq(events.filter(func(e): return e.kind == "projectile_fired").size(), 1,
		"the windup completes from the displaced position and fires normally")


# --- determinism -------------------------------------------------------------------

func test_multi_action_selection_is_deterministic() -> void:
	var a := SimWorld.new()
	_register_player(a, Vector3.ZERO)
	_register_two_action_enemy(a, Vector3(0, 0, -6.4))
	var b := SimWorld.new()
	_register_player(b, Vector3.ZERO)
	_register_two_action_enemy(b, Vector3(0, 0, -6.4))

	for i in 200:
		var events_a: Array[Event] = a.tick([], 1.0 / 30.0)
		var events_b: Array[Event] = b.tick([], 1.0 / 30.0)
		assert_eq(events_a.size(), events_b.size(), "tick %d event count must match" % i)
		for j in events_a.size():
			assert_eq(events_a[j].kind, events_b[j].kind)
			assert_eq(events_a[j].payload, events_b[j].payload)


# --- engagement opener (P29 iteration item 1) ---------------------------------------
# Playtest finding: "first-engagement firing reads mechanically range-triggered." A fresh
# actor's _next_fire_tick defaults to 0, so crossing a band edge started a windup on that
# very tick. The opener arms that SAME gate at acquisition -- no parallel clock.

const OPENER: int = 10


func _register_opener_enemy(s: SimWorld, position: Vector3, delay: int = OPENER, detection: float = 8.0) -> void:
	s.add_entity(ENEMY_ID, position, 0.0)
	s.register_combatant(ENEMY_ID, 500.0, &"watcher", 0, 0.85, &"enemy")
	s.register_weapon(NEAR, 8.0, &"force", NEAR_MAX, 90.0, 0.0, 20)
	var repertoire: Array[Dictionary] = [{"id": NEAR, "min_range": 0.0, "max_range": NEAR_MAX, "windup_ticks": NEAR_WINDUP}]
	s.register_ai(ENEMY_ID, repertoire, position, 1.5, 0.0, detection, 100.0, delay)


## All THREE acquisition paths route through the one _acquire_aggro seam, so all three
## must produce the identical deadline. Before centralisation an opener armed at only the
## passive path would have been bypassable simply by shooting from outside detection range.
func test_every_acquisition_path_arms_the_same_opener_deadline() -> void:
	var deadlines: Dictionary = {}

	# (1) passive detection
	var passive := SimWorld.new()
	_register_player(passive, Vector3.ZERO)
	_register_opener_enemy(passive, Vector3(0, 0, -1.0))
	passive.tick([], 1.0 / 30.0)
	deadlines["passive"] = int(passive._next_fire_tick.get(ENEMY_ID, -1))

	# (2) hit-establishes-aggro, from outside detection range
	var by_hit := SimWorld.new()
	_register_player(by_hit, Vector3.ZERO)
	_register_opener_enemy(by_hit, Vector3(0, 0, -1.0), OPENER, 0.1)
	by_hit.set_damage_matrix({}, 1.5, 0.5)
	by_hit.register_weapon(&"poke", 1.0, &"force", 12.0, 180.0, 0.0, 0)
	by_hit.set_equipped_weapon(PLAYER_ID, &"poke")
	assert_eq(by_hit._ai_state[ENEMY_ID], "idle", "sanity: detection alone must not have acquired")
	by_hit.tick([Command.new(by_hit.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	deadlines["hit"] = int(by_hit._next_fire_tick.get(ENEMY_ID, -1))

	# (3) status-application-establishes-aggro, also from outside detection range
	var by_status := SimWorld.new()
	_register_player(by_status, Vector3.ZERO)
	_register_opener_enemy(by_status, Vector3(0, 0, -1.0), OPENER, 0.1)
	by_status.set_damage_matrix({}, 1.5, 0.5)
	by_status.register_status(&"burn", 1.0, 2, 10)
	by_status.register_weapon(&"brand", 1.0, &"force", 12.0, 180.0, 0.0, 0, &"burn", 1.0)
	by_status.set_equipped_weapon(PLAYER_ID, &"brand")
	by_status.tick([Command.new(by_status.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	deadlines["status"] = int(by_status._next_fire_tick.get(ENEMY_ID, -1))

	for path in deadlines:
		assert_eq(deadlines[path], OPENER, "'%s' acquisition must arm the same opener deadline" % path)


## max(), never assignment: re-acquiring must not SHORTEN a cooldown already running, or
## disengage/re-engage becomes an attack-speed exploit.
func test_reacquisition_can_never_shorten_a_live_cooldown() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3(0, 0, -50.0))
	_register_opener_enemy(sim, Vector3(0, 0, -1.0))
	sim._next_fire_tick[ENEMY_ID] = 500  # a long cooldown already running
	sim.entities[PLAYER_ID] = Vector3.ZERO  # now inside detection -> acquires
	sim.tick([], 1.0 / 30.0)
	assert_eq(int(sim._next_fire_tick[ENEMY_ID]), 500,
		"acquisition must never pull a longer live cooldown forward")


## Only a GENUINE inactive -> active transition arms the opener. Chip damage on an enemy
## already fighting you must not repeatedly re-suppress its attacks.
func test_a_hit_on_an_already_active_enemy_does_not_rearm_the_opener() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3.ZERO)
	_register_opener_enemy(sim, Vector3(0, 0, -1.0))
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.register_weapon(&"poke", 1.0, &"force", 12.0, 180.0, 0.0, 0)
	sim.set_equipped_weapon(PLAYER_ID, &"poke")
	sim.tick([], 1.0 / 30.0)  # passive acquisition arms the opener
	assert_eq(sim._ai_state[ENEMY_ID], "active")
	var armed: int = int(sim._next_fire_tick[ENEMY_ID])

	for _i in 3:
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1)})], 1.0 / 30.0)
	assert_eq(int(sim._next_fire_tick[ENEMY_ID]), armed,
		"hits on an ALREADY-active enemy must not touch its readiness gate -- re-arming would let chip damage lock an enemy out of attacking")


## The opener delays the ATTACK, never the approach -- that is the whole feel it buys.
func test_the_opener_suppresses_the_attack_but_not_the_approach() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3.ZERO)
	sim.add_entity(ENEMY_ID, Vector3(0, 0, -3.0), 2.0)  # real move speed, outside the band
	sim.register_combatant(ENEMY_ID, 500.0, &"watcher", 0, 0.85, &"enemy")
	sim.register_weapon(NEAR, 8.0, &"force", NEAR_MAX, 90.0, 0.0, 20)
	var repertoire: Array[Dictionary] = [{"id": NEAR, "min_range": 0.0, "max_range": NEAR_MAX, "windup_ticks": NEAR_WINDUP}]
	sim.register_ai(ENEMY_ID, repertoire, Vector3(0, 0, -3.0), 1.5, 0.0, 8.0, 100.0, OPENER)

	var opening: Array[Event] = _tick(sim, OPENER)
	assert_eq(opening.filter(func(e): return e.kind == "attack_telegraph").size(), 0,
		"no attack may commit during the opener")
	assert_gt(opening.filter(func(e): return e.kind == "moved").size(), 0,
		"but the enemy must still be closing -- the opener is a commitment delay, not a freeze")
	assert_gt(_tick(sim, 40).filter(func(e): return e.kind == "attack_telegraph").size(), 0,
		"and it attacks normally once the opener elapses")


## A zero delay must be a true no-op, so Fang and Ooze stay byte-identical (this is what
## keeps tests/test_ai_backward_compat.gd valid).
func test_zero_delay_is_a_true_noop() -> void:
	sim = SimWorld.new()
	_register_player(sim, Vector3.ZERO)
	_register_opener_enemy(sim, Vector3(0, 0, -1.0), 0)
	var events: Array[Event] = sim.tick([], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 1,
		"with no opener authored, acquisition and commitment happen on the same tick exactly as before")


# --- telegraph timing (P29 readability verification) --------------------------------

## VERIFIED, not assumed: the telegraph Event is stamped with the SAME tick the action is
## committed on, with no dead ticks between decision and cue. Commitment and the Event
## append share one statement block in _decide_attack_commands, and _decide_ai_commands
## mutates the tick's event array in place -- but "the code looks adjacent" is not
## evidence, so this asserts the observable stamps.
##
## This is the foundation the windup-phase cue rests on: presentation derives the whole
## phase timeline from Event.tick, so a one-tick emission lag would silently skew every
## derived window by one tick (BRAIN: "Events carry the authoritative timestamp").
func test_telegraph_is_emitted_on_the_exact_commitment_tick() -> void:
	sim = _make_at(6.4)
	var events: Array[Event] = sim.tick([], 1.0 / 30.0)
	var telegraphs := events.filter(func(e): return e.kind == "attack_telegraph")
	assert_eq(telegraphs.size(), 1, "sanity: exactly one commitment this tick")
	if telegraphs.size() != 1:
		return
	assert_eq(telegraphs[0].tick, int(sim._ai_attack_start_tick[ENEMY_ID]),
		"the telegraph must carry the windup's own start tick -- zero dead ticks between decision and cue")
	assert_eq(int(sim._ai_attack_fire_tick[ENEMY_ID]) - telegraphs[0].tick, FAR_WINDUP,
		"and the full authored windup must remain ahead of the player at the moment the cue appears")


## The vulnerable window is CLIENT-DERIVABLE from what already ships: the telegraph names
## its action_id, and that action's vulnerable_start/end_tick are content the driver
## already resolves at setup. Window = [Event.tick + start, Event.tick + end]. This test
## pins the derivation so a future payload change cannot silently break the cue.
func test_vulnerable_window_is_derivable_from_the_telegraph_payload_alone() -> void:
	var s: SimWorld = _real_watcher_frustrated_at(6.0)
	var events: Array[Event] = s.tick([], 1.0 / 30.0)
	var telegraph: Event = null
	for event in events:
		if event.kind == "attack_telegraph":
			telegraph = event
	assert_not_null(telegraph)
	if telegraph == null:
		return
	var action_id: String = String(telegraph.payload.get("action_id", ""))
	var action: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", action_id)
	var window_opens: int = telegraph.tick + action.vulnerable_start_tick
	var window_closes: int = telegraph.tick + action.vulnerable_end_tick

	# Prove the derived window matches the sim's own susceptibility ruling tick-for-tick.
	for offset in range(0, action.windup_ticks + 1):
		var probe_tick: int = telegraph.tick + offset
		var derived_vulnerable: bool = probe_tick >= window_opens and probe_tick <= window_closes
		while s.tick_count < probe_tick:
			s.tick([], 1.0 / 30.0)
		if s.tick_count != probe_tick:
			continue
		var sim_mode: String = s._flinch_mode_of(ENEMY_ID)
		assert_eq(sim_mode == "vulnerable", derived_vulnerable,
			"tick %d: presentation's derived window must agree with the sim's authoritative susceptibility" % offset)


# --- close-frustration selection (P29 Watcher pass, 2026-08-17) ----------------------
# Survey is no longer selected by range alone: the Watcher must have genuinely FAILED TO
# CLOSE for its family's patience, and each failed-close episode grants exactly ONE
# fallback. These use the REAL Watcher content through ContentRegistrar; the Watcher is
# pinned (speed 0) so geometry is controlled by moving the PLAYER, isolating selection
# from locomotion.

const WATCHER_ANCHOR := Vector3(0, 0, -8.0)


func _pinned_real_watcher() -> SimWorld:
	var s := SimWorld.new()
	s.set_damage_matrix({}, 1.5, 0.5)
	s.add_entity(PLAYER_ID, Vector3.ZERO, 0.0)
	s.register_combatant(PLAYER_ID, 1000000.0, &"envoy", 0, 0.45, &"player")
	ContentRegistrar.register_enemy_body(s, ENEMY_ID, &"watcher", WATCHER_ANCHOR)
	ContentRegistrar.register_enemy_ai(s, ENEMY_ID, &"watcher", WATCHER_ANCHOR)
	s._move_speeds[ENEMY_ID] = 0.0
	s.debug_set_ai_active(ENEMY_ID)
	return s


func _place_player(s: SimWorld, distance: float) -> void:
	s.entities[PLAYER_ID] = WATCHER_ANCHOR + Vector3(0, 0, distance)


func _patience(s: SimWorld) -> int:
	return int(s._ai_tuning[ENEMY_ID].close_frustration_ticks)


func _count_surveys(events: Array[Event]) -> int:
	return events.filter(func(e): return e.kind == "attack_telegraph" and String(e.payload.get("action_id", "")) == "watcher_survey").size()


## THE PINNED CORRECTNESS REQUIREMENT. _ai_last_in_close_band is the last tick the Watcher
## was ACTUALLY close, refreshed continuously -- NOT the tick it first arrived. A long melee
## exchange followed by an exit must start the frustration clock at the EXIT, so the full
## patience still has to elapse. If the timestamp were stamped once on entry, this Watcher
## would survey the instant the player stepped away.
func test_frustration_counts_from_the_exit_tick_not_the_entry_tick() -> void:
	var s: SimWorld = _pinned_real_watcher()
	# Re-placed every tick: the Watcher's own pulse knockback would otherwise push the player
	# out of close range within ~60 ticks, and the test would silently stop testing what it
	# claims to (BRAIN: knockback invalidates a scripted sequence's next-step assumption).
	for _i in 300:
		_place_player(s, 1.0)
		_tick(s, 1)
	assert_almost_eq(float(s._ai_last_in_close_band[ENEMY_ID]), float(s.tick_count - 1), 1.0,
		"the proximity fact must have been refreshed every tick while close, not left at entry")

	_place_player(s, 6.0)  # the player steps out
	var before: Array[Event] = _tick(s, _patience(s) - 2)
	assert_eq(_count_surveys(before), 0,
		"the full patience must elapse FROM THE EXIT -- 300 ticks of prior melee must grant no credit")
	assert_gt(_count_surveys(_tick(s, 30)), 0, "and then it falls back to Survey")


## The same law from the displacement direction: being pushed off is not a provocation.
## This test exists specifically so the mechanic cannot silently become "bump immediately
## provokes Survey", which is a separate behavioural rule requiring its own evidence.
func test_displacement_out_of_close_range_does_not_immediately_provoke_survey() -> void:
	var s: SimWorld = _pinned_real_watcher()
	for _i in 60:
		_place_player(s, 1.2)
		_tick(s, 1)  # settled in close range, held there against knockback
	# Displace the WATCHER outward, exactly as a bump would.
	s.entities[ENEMY_ID] = WATCHER_ANCHOR + Vector3(0, 0, -4.0)
	var immediately: Array[Event] = _tick(s, 20)
	assert_eq(_count_surveys(immediately), 0,
		"displacement only STOPS the proximity refresh -- the whole patience is still owed")


## REGRESSION PIN: the proximity refresh must precede ALL early-returns in the AI phase.
##
## It originally sat inside _decide_single_ai_command, AFTER the FLINCHED return and the
## mid-windup return -- so the "last tick actually close" fact silently froze for the whole
## of every windup and every flinch recovery. A Watcher that had been standing in melee the
## entire time then read as long-frustrated the moment it could act again, and would fall
## back to Survey from point-blank range.
##
## Position is a fact about the WORLD, not about what the actor happens to be doing. This
## test pins the flinch case specifically, because flinch returns earliest of all.
func test_proximity_refresh_is_not_skipped_while_flinched() -> void:
	var s: SimWorld = _pinned_real_watcher()
	_place_player(s, 1.0)
	_tick(s, 1)
	s._flinched_until_tick[ENEMY_ID] = s.tick_count + 30  # flinched, but still standing close

	for _i in 30:
		_place_player(s, 1.0)
		var events: Array[Event] = _tick(s, 1)
		assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 0,
			"sanity: a flinched enemy commits nothing")
		assert_eq(int(s._ai_last_in_close_band[ENEMY_ID]), s.tick_count - 1,
			"the proximity fact must keep refreshing THROUGH the flinch -- it is a world fact, not an activity fact")

	# And the consequence that matters: it has accrued no frustration credit at all.
	_place_player(s, 6.0)
	assert_eq(_count_surveys(_tick(s, _patience(s) - 2)), 0,
		"30 flinched ticks spent in close range must grant zero frustration credit")


## A freshly acquired distant Watcher must not open pre-frustrated (that would recreate the
## range-triggered defect the engagement opener was introduced to fix).
func test_a_freshly_acquired_watcher_is_not_pre_frustrated() -> void:
	var s: SimWorld = _pinned_real_watcher()
	_place_player(s, 6.0)
	assert_eq(_count_surveys(_tick(s, _patience(s) - 2)), 0,
		"acquisition starts the clock; it must not open by surveying")
	assert_gt(_count_surveys(_tick(s, 30)), 0, "the fallback arrives only after the patience is genuinely spent")


## ONE Survey per failed-close episode. Held at range indefinitely, the Watcher does not
## become a turret on a longer timer -- it does not fire again at all until it re-establishes
## close range.
func test_exactly_one_survey_per_failed_close_episode() -> void:
	var s: SimWorld = _pinned_real_watcher()
	_place_player(s, 6.0)
	var run: Array[Event] = _tick(s, 700)
	assert_eq(_count_surveys(run), 1,
		"held at range for 700 ticks, the Watcher must fall back exactly ONCE -- the episode is spent, not merely cooling down")


## ...and the episode clears ONLY on genuine close re-establishment, after which a NEW
## failed-close episode must accrue from scratch.
func test_episode_clears_only_on_genuine_close_re_establishment() -> void:
	var s: SimWorld = _pinned_real_watcher()
	_place_player(s, 6.0)
	assert_eq(_count_surveys(_tick(s, 200)), 1, "sanity: the episode's one fallback was spent")

	for _i in 10:
		_place_player(s, 1.0)   # genuinely re-establish close range
		_tick(s, 1)
	_place_player(s, 6.0)   # and lose it again -- a NEW episode
	assert_eq(_count_surveys(_tick(s, _patience(s) - 2)), 0, "the new episode must accrue its own patience")
	assert_eq(_count_surveys(_tick(s, 30)), 1, "then it may fall back once more")


## Boundary behaviour: an actor hovering across the close band edge keeps refreshing the
## proximity fact, so frustration never matures and no episode is ever spent. The band edge
## must not become a place where state degrades.
func test_band_edge_flicker_never_matures_frustration_or_corrupts_the_episode() -> void:
	var s: SimWorld = _pinned_real_watcher()
	var surveys: int = 0
	for i in 400:
		_place_player(s, 1.95 if i % 2 == 0 else 2.05)
		surveys += _count_surveys(_tick(s, 1))
	assert_eq(surveys, 0, "flickering at the edge counts as being close -- frustration must never mature")
	# Field renamed to _ai_last_frustration_commit (P17 selector) as a behaviour-preserving
	# refactor: the fact is the consumption of a close-frustration EPISODE, which Watcher spends
	# by committing a Survey and Fang spends by committing a Burrow. IDENTIFIER ONLY -- this
	# assertion, its setup and its expected outcome are untouched, which is what makes the
	# Watcher suite the pin proving P29 semantics did not move.
	assert_false(s._ai_last_frustration_commit.has(ENEMY_ID),
		"and with no Survey ever committed, no episode may have been marked spent")


## Pulse carries no gate and must be entirely unaffected.
func test_pulse_is_never_gated_by_close_frustration() -> void:
	var s: SimWorld = _pinned_real_watcher()
	_place_player(s, 1.0)
	var events: Array[Event] = _tick(s, 40)
	assert_gt(events.filter(func(e): return e.kind == "attack_telegraph" and String(e.payload.get("action_id", "")) == "watcher_pulse").size(), 0,
		"the melee action must fire normally on the shared cooldown, ungated")


func test_close_frustration_selection_is_deterministic() -> void:
	var a: SimWorld = _pinned_real_watcher()
	var c: SimWorld = _pinned_real_watcher()
	for i in 400:
		var distance: float = 6.0 if i % 200 < 150 else 1.0
		_place_player(a, distance)
		_place_player(c, distance)
		var events_a: Array[Event] = a.tick([], 1.0 / 30.0)
		var events_c: Array[Event] = c.tick([], 1.0 / 30.0)
		assert_eq(events_a.size(), events_c.size(), "tick %d event count must match" % i)
		for j in events_a.size():
			assert_eq(events_a[j].kind, events_c[j].kind)
			assert_eq(events_a[j].payload, events_c[j].payload)


# --- CONTROLLED VULNERABILITY PROBE (P29, banked 2026-08-17) -------------------------
# Ruled scope: MECHANICAL verification only. This asks one question -- does an EXPLOIT-capable
# sword hit landing inside the Survey's visibly active window produce the intended interrupt?
# It is explicitly NOT a claim that normal ranged Survey situations leave enough travel time
# to reach the Watcher; positioning determines which counterplay is available, and the
# window's perceptibility already passed on its own.
#
# WHY THIS PROBE CANNOT PASS FOR THE WRONG REASON: sword_burn_A authors
# interrupt_strength = 0 on hits 1 and 2 (only hit 3 carries 1). Graded interruption
# therefore cannot cancel the windup here, so a cancel can ONLY have come from the flinch
# route. The negative control below closes the loop from the other side.

func _survey_probe_sim() -> SimWorld:
	var s := SimWorld.new()
	s.set_damage_matrix({}, 1.5, 0.5)
	s.add_entity(PLAYER_ID, Vector3.ZERO, 4.0)
	s.register_combatant(PLAYER_ID, 100000.0, &"envoy", 0, 0.45, &"player")
	ContentRegistrar.register_enemy_body(s, ENEMY_ID, &"watcher", WATCHER_ANCHOR)
	ContentRegistrar.register_enemy_ai(s, ENEMY_ID, &"watcher", WATCHER_ANCHOR)
	ContentRegistrar.register_weapon(s, &"sword_burn_A")
	s.set_equipped_weapon(PLAYER_ID, &"sword_burn_A")
	s._move_speeds[ENEMY_ID] = 0.0
	s.debug_set_ai_active(ENEMY_ID)
	_place_player(s, 4.0)
	s._ai_last_in_close_band[ENEMY_ID] = s.tick_count - 200  # already failed to close
	return s


## Drives a committed Survey, teleports the player into sword reach, and swings so the hit
## lands at `press_offset`+ ticks into the windup. Returns every event after commitment.
func _probe_survey_with_sword(press_offset: int) -> Dictionary:
	var s: SimWorld = _survey_probe_sim()
	var telegraph_tick: int = -1
	for _t in 5:
		for event in s.tick([], 1.0 / 30.0):
			if event.kind == "attack_telegraph":
				telegraph_tick = event.tick
	# Teleported rather than walked: this is a mechanical probe of the WINDOW, and the ruling
	# explicitly separates that from whether travel time permits the approach.
	_place_player(s, 1.9)

	var collected: Array[Event] = []
	for _t in 60:
		var commands: Array[Command] = []
		var offset: int = s.tick_count - telegraph_tick
		if offset == press_offset:
			commands.append(Command.new(s.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "pressed"}))
		if offset == press_offset + 2:
			commands.append(Command.new(s.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, -1), "phase": "released"}))
		collected.append_array(s.tick(commands, 1.0 / 30.0))
	return {"telegraph_tick": telegraph_tick, "events": collected, "sim": s}


func _offset_of(result: Dictionary, kind: String) -> int:
	for event in result.events:
		if event.kind == kind:
			return event.tick - int(result.telegraph_tick)
	return -1


## THE PROBE. An EXPLOIT hit inside the visibly active window interrupts the Survey.
func test_sword_hit_inside_the_survey_window_interrupts_it() -> void:
	var survey: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", &"watcher_survey")
	var result: Dictionary = _probe_survey_with_sword(22)

	var hit_offset: int = _offset_of(result, "hit")
	assert_between(hit_offset, survey.vulnerable_start_tick, survey.vulnerable_end_tick,
		"SANITY: the probe must actually land its hit inside the authored window, or it proves nothing")

	assert_eq(_offset_of(result, "windup_interrupted"), hit_offset, "the committed Survey must be cancelled by that hit")
	for event in result.events:
		if event.kind == "flinched":
			assert_eq(String(event.payload.get("reason", "")), "exploit",
				"and the cancel must come from the VULNERABILITY route -- hits 1-2 author interrupt_strength 0, so nothing else could have done it")
	assert_eq(result.events.filter(func(e): return e.kind == "flinched").size(), 1, "exactly one flinch")
	assert_eq(result.events.filter(func(e): return e.kind == "projectile_fired").size(), 0,
		"and the shot must never leave -- the window was punished before release")


## NEGATIVE CONTROL. The identical hit BEFORE the window changes nothing: no flinch, no
## cancel, and the Survey fires normally. Without this, the probe above could be passing
## because any sword hit cancels a windup.
func test_the_same_sword_hit_before_the_window_does_not_interrupt() -> void:
	var survey: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", &"watcher_survey")
	var result: Dictionary = _probe_survey_with_sword(6)

	var hit_offset: int = _offset_of(result, "hit")
	assert_gt(hit_offset, -1, "SANITY: the control must still land its hit")
	assert_lt(hit_offset, survey.vulnerable_start_tick, "SANITY: and land it BEFORE the window opens")

	assert_eq(result.events.filter(func(e): return e.kind == "flinched").size(), 0,
		"outside the window an EXPLOIT-capable hit must not flinch -- hit 1 is 8 damage against a threshold of 24, and its capability is exploit, so no pressure route exists either")
	assert_eq(result.events.filter(func(e): return e.kind == "windup_interrupted").size(), 0, "so nothing cancels the windup")
	assert_eq(result.events.filter(func(e): return e.kind == "projectile_fired").size(), 1,
		"and the Survey completes and fires as authored")


# --- named integration fixture: the REAL Watcher, production path -------------------
# BRAIN, "Convenience-zeroed defenses in tests hide the interactions worth testing": the
# synthetic fixtures above protect SIMULATION laws, and every one of them hand-builds its
# repertoire. If no test ever drives the shipped .tres through ContentRegistrar, the
# content and the sim can diverge while all of the above stays green -- exactly how the
# i-frame/combo-cadence defect survived 280 passing tests.

func _real_watcher_at(distance: float) -> SimWorld:
	var s := SimWorld.new()
	s.set_damage_matrix({}, 1.5, 0.5)
	s.add_entity(PLAYER_ID, Vector3.ZERO, 4.0)
	s.register_combatant(PLAYER_ID, 200.0, &"envoy", 0, 0.45, &"player")
	var spawn := Vector3(0, 0, -distance)
	ContentRegistrar.register_enemy_body(s, ENEMY_ID, &"watcher", spawn)
	ContentRegistrar.register_enemy_ai(s, ENEMY_ID, &"watcher", spawn)
	s.debug_set_ai_active(ENEMY_ID)
	return s


## A real Watcher that has ALREADY failed to close for its authored patience. Ages the
## literal proximity fact rather than poking any episode flag -- there is no flag to poke,
## which is the point of deriving episode state from facts.
func _real_watcher_frustrated_at(distance: float) -> SimWorld:
	var s: SimWorld = _real_watcher_at(distance)
	var patience: int = int(s._ai_tuning[ENEMY_ID].close_frustration_ticks)
	s._ai_last_in_close_band[ENEMY_ID] = s.tick_count - patience
	return s


## RE-BASELINED 2026-08-17 (Watcher contextual selection). DELIBERATE: range alone no longer
## selects Survey, so the original "at 6.0 units it surveys on tick 1" is no longer the
## specified behaviour. The assertion now states the RULED rule -- range plus a genuinely
## failed close -- and the un-frustrated case is asserted alongside it, which is the
## behaviour change itself rather than a weakening of the test.
func test_real_watcher_surveys_at_range_and_pulses_up_close() -> void:
	var fresh_sim: SimWorld = _real_watcher_at(6.0)
	assert_eq(_telegraphed_action(_tick(fresh_sim, 1)), "",
		"range alone must NOT select Survey -- a Watcher that has not yet failed to close has no reason to fall back")

	var far_sim: SimWorld = _real_watcher_frustrated_at(6.0)
	var far_events: Array[Event] = _tick(far_sim, 1)
	assert_eq(_telegraphed_action(far_events), "watcher_survey",
		"but a Watcher held at 6.0 units past its patience must fall back to Survey")
	var fired: Array[Event] = _tick(far_sim, 40)
	assert_gt(fired.filter(func(e): return e.kind == "projectile_fired").size(), 0,
		"and that action must actually resolve as a projectile through the real content")

	var near_sim: SimWorld = _real_watcher_at(1.5)
	assert_eq(_telegraphed_action(_tick(near_sim, 1)), "watcher_pulse",
		"and its melee action at 1.5 units -- the EXPLOIT lesson stays the steady state")


## The Watcher's authored engagement band settles it INSIDE the pulse band, so melee
## remains its default and the survey is what the player's own spacing summons. This is
## the behaviour the "do not couple movement to selection" ruling protects; if a future
## edit makes the Watcher settle in its survey band, it has become a turret.
func test_real_watcher_settles_inside_its_melee_band() -> void:
	var sim_far: SimWorld = _real_watcher_at(8.5)
	_tick(sim_far, 300)
	var settled: float = sim_far.entities[ENEMY_ID].distance_to(sim_far.entities[PLAYER_ID])
	assert_lte(settled, 2.0, "the Watcher must close into its pulse band, not hold at survey range")
	assert_eq(sim_far._select_action(ENEMY_ID, settled), "watcher_pulse",
		"its steady-state action must be the melee one")


## GAME-RULES §1.1's CI proof, strengthened for P29. test_sim_world.gd already ticks an
## EMPTY SimWorld 1000x, which proves headless-ness but exercises nothing. P29 adds the
## first autonomous multi-action decision loop AND enemy projectiles, so the meaningful
## version soaks the REAL content: 1000 ticks, both a multi-action and a single-action
## family, no display server, and every projectile it ever spawned accounted for.
func test_real_content_soaks_1000_ticks_headless() -> void:
	var s := SimWorld.new()
	s.set_damage_matrix({}, 1.5, 0.5)
	s.add_entity(PLAYER_ID, Vector3.ZERO, 4.0)
	s.register_combatant(PLAYER_ID, 100000.0, &"envoy", 0, 0.45, &"player")
	ContentRegistrar.register_enemy_body(s, ENEMY_ID, &"watcher", Vector3(0, 0, -8.0))
	ContentRegistrar.register_enemy_ai(s, ENEMY_ID, &"watcher", Vector3(0, 0, -8.0))
	ContentRegistrar.register_enemy_body(s, 2, &"fang", Vector3(3.0, 0, -8.0))
	ContentRegistrar.register_enemy_ai(s, 2, &"fang", Vector3(3.0, 0, -8.0))

	var by_action: Dictionary = {}
	var fired: int = 0
	var terminated: int = 0
	for _t in 1000:
		for event in s.tick([], 1.0 / 30.0):
			if event.kind == "attack_telegraph":
				var id: String = String(event.payload.get("action_id", ""))
				by_action[id] = int(by_action.get(id, 0)) + 1
			elif event.kind == "projectile_fired":
				fired += 1
			elif event.payload.has("projectile_id"):
				terminated += 1

	assert_eq(s.tick_count, 1000, "the sim must survive a long headless soak with real content")
	# SURVEY IS DELIBERATELY NOT ASSERTED HERE (2026-08-17). Since Survey became contextual
	# it requires a sustained FAILED CLOSE, and a soak against a stationary player produces
	# the opposite -- the Watcher simply walks in and fights. Choreographing a kite here made
	# the test depend on out-running the leash rather than on the mechanic, so Survey
	# coverage moved to the deterministic gate tests above, where the episode lifecycle is
	# actually the subject. What this soak protects is robustness and MELEE coverage.
	assert_gt(int(by_action.get("watcher_pulse", 0)), 0, "an unopposed Watcher must close and use its melee action")
	assert_gt(int(by_action.get("fang_bite", 0)), 0, "the single-action family must keep attacking normally alongside it")
	# Every shot must be accounted for: terminated, or still legitimately in flight.
	assert_eq(fired, terminated + s._projectiles.size(),
		"every projectile must either have emitted a terminal event carrying its id or still be in flight -- a shot that vanishes silently leaks a tracer")
	print("  [soak] telegraphs by action: %s | projectiles fired=%d terminated=%d in-flight=%d" % [by_action, fired, terminated, s._projectiles.size()])


func _make_at(distance: float) -> SimWorld:
	var s := SimWorld.new()
	_register_player(s, Vector3.ZERO)
	_register_two_action_enemy(s, Vector3(0, 0, -distance))
	return s
