extends GutTest
## P44 (ruled 2026-10-18, corrected the same day): ONE SHARED POST-HIT WINDOW FOR THE ENVOY.
##
## EnvoyStats.iframe_ticks_on_hit (provisional 90) is the ONLY invulnerability: any successful HP
## hit -- an enemy blow, a projectile, a spike pad -- starts it, and every ordinary hit from any
## source inside it is absorbed. Absorbed and blocked hits never restart it. There is no per-pad
## timer and no source-specific window (a 15 + 90 hazard-only split was REJECTED). Every test here
## asks the same question of a different source: does one successful HP hit buy exactly N ticks
## during which nothing else lands, and does the world behave normally the tick after?
##
## Every Envoy below registers with the SHIPPED value read from ContentDB, never a literal: a test
## that hand-picks its own window can stay green while the game ships something else (BRAIN, the
## combo-cadence escape).

const DT := 1.0 / 30.0
const PLAYER := 0
const ENEMY := 1
const PAD := 0
const ROOM := Rect2(-20.0, -10.0, 40.0, 20.0)
const SPIKES := Rect2(-2.0, -2.0, 4.0, 4.0)
const FAR_PAD := Rect2(8.0, -2.0, 4.0, 4.0)
const BITE := &"test_p44_bite"
## safe 1 / active 10000: on from tick 1 for the whole test -- "uninterrupted contact".
const ALWAYS_SAFE := 1
const ALWAYS_ACTIVE := 10000

var sim: SimWorld


func _envoy() -> EnvoyStats:
	return ContentDB.get_resource(&"envoy", &"default")


func _window() -> int:
	return _envoy().iframe_ticks_on_hit


func _build(pad_safe: int, pad_active: int, damage: float, health: float) -> void:
	sim = SimWorld.new()
	sim.seed_combat_rng(1)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	sim.register_spike_pad(PAD, SPIKES, pad_safe, pad_active, 0, damage, &"force")
	sim.add_entity(PLAYER, Vector3.ZERO, 4.0, Vector3(0, 0, 1), 0.45)
	sim.register_combatant(PLAYER, health, &"envoy", _window(), 0.45, &"player")


## An enemy beside the pad (enemies are immune to it anyway) with a knockback-free bite, so a
## blow never carries the Envoy off the spikes and muddies what the window is doing.
func _add_biter(weapon_damage: float = 5.0, status_id: StringName = &"", proc: float = 0.0) -> void:
	sim.add_entity(ENEMY, Vector3(3.0, 0.0, 0.0), 0.0, Vector3(-1, 0, 0), 0.5)
	sim.register_combatant(ENEMY, 999.0, &"test_target", 0, 0.5)
	sim.register_weapon(BITE, weapon_damage, &"force", 4.0, 60.0, 0.0, 0, status_id, proc)
	sim.set_equipped_weapon(ENEMY, BITE)


func _bite() -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ENEMY, "attack", {"aim": Vector3(-1, 0, 0)})] as Array[Command], DT)


func _run(ticks: int) -> Array[Event]:
	var events: Array[Event] = []
	for i in ticks:
		events.append_array(sim.tick([] as Array[Command], DT))
	return events


func _run_until_tick(target_tick: int) -> Array[Event]:
	return _run(target_tick - sim.tick_count)


## Hits and absorptions AGAINST THE ENVOY, by source -- the only events these laws are about.
func _against_envoy(events: Array[Event], kind: String, source: StringName = &"") -> Array[Event]:
	var out: Array[Event] = []
	for event in events:
		if event.kind != kind or int(event.payload.get("target_id", -1)) != PLAYER:
			continue
		if source == SimWorld.SOURCE_ENVIRONMENT and event.payload.get("source", &"") != SimWorld.SOURCE_ENVIRONMENT:
			continue
		if source == &"actor" and event.payload.has("source"):
			continue
		out.append(event)
	return out


func _spike_hits(events: Array[Event]) -> Array[int]:
	return _ticks_of(_against_envoy(events, "hit", SimWorld.SOURCE_ENVIRONMENT))


func _ticks_of(events: Array[Event]) -> Array[int]:
	var ticks: Array[int] = []
	for event in events:
		ticks.append(event.tick)
	return ticks


# --- 0: THE SHIPPED VALUE ------------------------------------------------------------------------

## The ruling's number, read from the resource the game actually loads -- not the script default.
## PROVISIONAL: this assertion moves deliberately with an approved retune, never to make a test pass.
func test_the_shipped_envoy_resource_carries_the_ruled_window() -> void:
	var stats: EnvoyStats = _envoy()
	assert_eq(stats.resource_path, "res://game/content/envoy/envoy_stats.tres", "sanity: the shipped resource")
	assert_eq(stats.iframe_ticks_on_hit, 90, "P44: one shared window, 90 = 3 s at 30 Hz (provisional)")


# --- 1: EXACT BOUNDARIES -----------------------------------------------------------------------

## A hit at T; T+1 .. T+N-1 absorbed; T+N is the next hit. Event.tick is the timestamp, never
## tick_count sampled afterwards (BRAIN).
func test_the_window_is_exactly_n_ticks_on_the_event_clock() -> void:
	var n: int = _window()
	_build(ALWAYS_SAFE, ALWAYS_ACTIVE, 10.0, 5000.0)
	var events: Array[Event] = _run(2 * n + 2)
	var hits: Array[int] = _spike_hits(events)
	var absorbed: Array[int] = _ticks_of(_against_envoy(events, "attack_absorbed", SimWorld.SOURCE_ENVIRONMENT))
	assert_eq(hits, [1, 1 + n, 1 + 2 * n] as Array[int], "a hit every N ticks, starting on the first active tick")
	for t in range(1, 2 * n + 2):
		assert_ne(hits.has(t), absorbed.has(t), "tick %d: exactly one of hit / absorbed" % t)
		assert_eq(hits.has(t), (t - 1) % n == 0, "tick %d: only the window boundary lands" % t)


## Pad size and timing play no part: the window belongs to the Envoy, not to the pad.
func test_the_window_ignores_pad_size_and_timing() -> void:
	var n: int = _window()
	for rect: Rect2 in [Rect2(-0.5, -0.5, 1.0, 1.0), Rect2(-15.0, -8.0, 30.0, 16.0)]:
		for timing: Vector2i in [Vector2i(ALWAYS_SAFE, ALWAYS_ACTIVE), Vector2i(1, n + 5), Vector2i(1, 3 * n)]:
			_build(timing.x, timing.y, 10.0, 5000.0)
			sim.register_spike_pad(PAD, rect, timing.x, timing.y, 0, 10.0, &"force")
			assert_eq(_spike_hits(_run(n + 2)), [1, 1 + n] as Array[int], "pad %s, timing %s" % [rect, timing])


## One 30-tick activation at 10 damage: one hit, 29 absorbed. A 90-tick window outlasts the 10
## safe ticks after it, so the next activation (50..79) is absorbed too and the one after lands.
func test_one_activation_lands_once_and_the_window_spans_the_next() -> void:
	assert_eq(_window(), 90, "this arithmetic is written for the ruled 90")
	_build(10, 30, 10.0, 500.0)
	_run_until_tick(10)
	var events: Array[Event] = _run(30)
	assert_eq(_spike_hits(events), [10] as Array[int])
	assert_eq(_against_envoy(events, "attack_absorbed", SimWorld.SOURCE_ENVIRONMENT).size(), 29)
	assert_eq(sim._health[PLAYER], 490.0)
	assert_eq(_spike_hits(_run_until_tick(120)), [100] as Array[int], "staying on after expiry permits another hit")


# --- 2: EVERY PAD, ONE WINDOW --------------------------------------------------------------------

func _assert_one_hit_per_window(events: Array[Event], pads_in_contact: int, ticks: int) -> void:
	var expected: Array[int] = []
	for t in range(1, ticks + 1, _window()):
		expected.append(t)
	assert_eq(_spike_hits(events), expected, "a second pad buys no extra hit inside the window")
	assert_eq(_against_envoy(events, "attack_absorbed", SimWorld.SOURCE_ENVIRONMENT).size(),
		pads_in_contact * ticks - expected.size(), "every other contact, from either pad, is absorbed")


func test_two_overlapping_active_pads_cannot_double_hit() -> void:
	_build(ALWAYS_SAFE, ALWAYS_ACTIVE, 10.0, 5000.0)
	sim.register_spike_pad(1, Rect2(-1.0, -1.0, 4.0, 4.0), ALWAYS_SAFE, ALWAYS_ACTIVE, 0, 10.0, &"force")
	var events: Array[Event] = _run(2)
	assert_eq(_against_envoy(events, "hit", SimWorld.SOURCE_ENVIRONMENT).size(), 1, "the first tick: one hit")
	assert_eq(_against_envoy(events, "attack_absorbed", SimWorld.SOURCE_ENVIRONMENT).size(), 1, "and the second pad absorbed")
	events.append_array(_run(_window() + 9))
	_assert_one_hit_per_window(events, 2, _window() + 10)


## Contiguous pads share an edge, and contains() is INCLUSIVE: an Envoy on the seam is in both.
func test_standing_on_the_seam_of_two_adjacent_pads_cannot_double_hit() -> void:
	_build(ALWAYS_SAFE, ALWAYS_ACTIVE, 10.0, 5000.0)
	sim.register_spike_pad(PAD, Rect2(-2.0, -2.0, 2.0, 4.0), ALWAYS_SAFE, ALWAYS_ACTIVE, 0, 10.0, &"force")
	sim.register_spike_pad(1, Rect2(0.0, -2.0, 2.0, 4.0), ALWAYS_SAFE, ALWAYS_ACTIVE, 0, 10.0, &"force")
	assert_eq(sim.entities[PLAYER].x, 0.0, "sanity: on the seam")
	_assert_one_hit_per_window(_run(_window() + 11), 2, _window() + 10)


## The general window covers a DIFFERENT pad too -- a consequence of it being general, not a
## hazard rule.
func test_the_window_covers_a_different_pad() -> void:
	_build(ALWAYS_SAFE, ALWAYS_ACTIVE, 10.0, 5000.0)
	sim.register_spike_pad(1, FAR_PAD, ALWAYS_SAFE, ALWAYS_ACTIVE, 0, 10.0, &"force")
	assert_eq(_spike_hits(_run(20)), [1] as Array[int], "sanity: the first pad hurt once")
	sim.entities[PLAYER] = Vector3(FAR_PAD.get_center().x, 0.0, FAR_PAD.get_center().y)
	assert_eq(_spike_hits(_run_until_tick(2 + _window())), [1 + _window()] as Array[int])


# --- 3: ONE WINDOW, EVERY SOURCE ---------------------------------------------------------------

## An enemy blow opens the window the spikes then meet.
func test_an_enemy_hit_protects_against_spikes_for_the_whole_window() -> void:
	var n: int = _window()
	_build(10, 30, 10.0, 500.0)
	_add_biter()
	_run_until_tick(5)
	assert_eq(_against_envoy(_bite(), "hit", &"actor").size(), 1, "sanity: the bite landed")
	# Activations 10..39 and 50..79 are wholly inside; 90..119 lands once the window ends at 5+N.
	assert_eq(_spike_hits(_run_until_tick(5 + n + 1)), [5 + n] as Array[int])


## And the spikes open the window an enemy blow then meets -- for the full N, not a shorter one.
func test_a_spike_hit_protects_against_enemy_blows_for_the_whole_window() -> void:
	var n: int = _window()
	_build(10, 30, 10.0, 500.0)
	_add_biter()
	assert_eq(_spike_hits(_run_until_tick(11)), [10] as Array[int])
	# Off the pad (still in the biter's reach), so its next activation cannot land first at 10+N.
	sim.entities[PLAYER] = Vector3(0.0, 0.0, 2.5)
	_run_until_tick(10 + n - 1)
	var inside: Array[Event] = _bite()  # tick 10 + N - 1: last absorbed tick
	assert_eq(_against_envoy(inside, "hit", &"actor").size(), 0)
	assert_eq(int(_against_envoy(inside, "attack_absorbed", &"actor")[0].payload["attacker_id"]), ENEMY)
	var after: Array[Event] = _bite()  # tick 10 + N: expired
	assert_eq(_against_envoy(after, "hit", &"actor").size(), 1, "normal eligibility resumes")


## ABSORBED HITS NEVER RESTART IT: a stream of enemy blows inside the window does not move its end.
func test_absorbed_hits_do_not_extend_the_window() -> void:
	var n: int = _window()
	_build(ALWAYS_SAFE, ALWAYS_ACTIVE, 10.0, 5000.0)
	_add_biter()
	_run(2)  # spike hit at tick 1
	var events: Array[Event] = []
	while sim.tick_count < 1 + n:
		events.append_array(_bite())
	assert_eq(_against_envoy(events, "hit").size(), 0, "nothing lands inside")
	var boundary: Array[Event] = sim.tick([] as Array[Command], DT)
	assert_eq(_spike_hits(boundary), [1 + n] as Array[int], "the window ended where the first hit put it")


# --- 4: SHIELD, BURN, DEATH -- UNCHANGED ---------------------------------------------------------

## Block grants no i-frames (the established shield law, untouched): every active tick drains the
## meter, nothing is absorbed, health is untouched -- and nothing opens a window.
func test_a_held_shield_still_pays_every_tick_and_grants_no_window() -> void:
	_build(ALWAYS_SAFE, ALWAYS_ACTIVE, 10.0, 500.0)
	sim.register_shield(PLAYER, 5000.0, 0.0, 30, 2.0, 0)
	var events: Array[Event] = []
	for i in 21:
		events.append_array(sim.tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})] as Array[Command], DT))
	var blocked: int = 0
	for event in events:
		if event.kind == "blocked" and int(event.payload["target_id"]) == PLAYER:
			blocked += 1
	assert_eq(blocked, 20, "every active tick met the shield")
	assert_eq(_against_envoy(events, "attack_absorbed").size(), 0)
	assert_eq(int(sim._iframe_ticks_remaining.get(PLAYER, 0)), 0, "a block opened no window")
	assert_eq(sim._health[PLAYER], 500.0)


## Burn's DoT neither respects nor opens the window (it never travels _resolve_hit_on_target).
func test_burn_ticks_through_the_window_and_does_not_move_it() -> void:
	var n: int = _window()
	_build(10, 30, 10.0, 500.0)
	sim.register_status(&"burn", 1.0, 3, 400)
	_add_biter(0.0, &"burn", 1.0)
	_run_until_tick(5)
	_bite()  # a 0-damage burning blow: opens the window, arms Burn
	assert_true(sim._status_instances.has(PLAYER), "sanity: burning")
	var health_before: float = sim._health[PLAYER]
	var events: Array[Event] = _run_until_tick(5 + n + 1)
	var burn_ticks: int = 0
	for event in events:
		if event.kind == "status_resolved" and int(event.payload["actor_id"]) == PLAYER:
			burn_ticks += 1
	assert_gt(burn_ticks, 0, "Burn resolved inside the window")
	assert_eq(_spike_hits(events), [5 + n] as Array[int], "Burn ticks did not restart the window")
	assert_eq(sim._health[PLAYER], health_before - float(burn_ticks) - 10.0, "Burn damage + exactly one spike hit")


## A lethal spike hit is an ordinary death: `died` on the boundary tick, nothing after it.
func test_the_lethal_spike_hit_lands_on_the_boundary_and_ends_it() -> void:
	var n: int = _window()
	_build(ALWAYS_SAFE, ALWAYS_ACTIVE, 10.0, 15.0)
	var events: Array[Event] = _run(2 * n)
	var deaths: Array[int] = []
	for event in events:
		if event.kind == "died" and int(event.payload["actor_id"]) == PLAYER:
			deaths.append(event.tick)
	assert_eq(deaths, [1 + n] as Array[int], "the second hit, on the window boundary, kills")
	for event in events:
		if event.tick > 1 + n:
			assert_ne(int(event.payload.get("target_id", -1)), PLAYER, "a corpse is not hit or absorbed")


# --- 5: DETERMINISTIC REPLAY ---------------------------------------------------------------------

func _scripted_log() -> Array:
	_build(10, 30, 10.0, 500.0)
	_add_biter()
	var stream: Array = []
	for t in 300:
		var commands: Array[Command] = []
		if t % 17 == 0:
			commands.append(Command.new(t, ENEMY, "attack", {"aim": Vector3(-1, 0, 0)}))
		if t >= 60 and t < 75:
			commands.append(Command.new(t, PLAYER, "move", {"direction": Vector3(0, 0, 1)}))
		for event in sim.tick(commands, DT):
			stream.append(FamilyLocomotionScenario.serialize(event))
	return stream


func test_the_same_commands_replay_the_same_event_log() -> void:
	var first: Array = _scripted_log()
	var second: Array = _scripted_log()
	assert_gt(first.size(), 0)
	assert_eq(first, second, "seed + command log reproduces every hit and absorption, tick for tick")


# --- 6: EVERY SHIPPED LAYOUT'S PADS --------------------------------------------------------------

## THE LAW, stated once: on a tick the Envoy stands on an active pad, the spikes land iff no HP hit
## has landed in the last N ticks.
func _assert_window_law(world: SimWorld, pad: SpikePadPlan, ticks: int, label: String) -> int:
	var last_hit: int = -1000000
	var hits: int = 0
	for i in ticks:
		var active: bool = world.spike_pad_ticks_until_active(pad.pad_id) == 0
		var tick: int = world.tick_count
		var landed: bool = false
		for event in world.tick([] as Array[Command], DT):
			if event.kind == "hit" and int(event.payload.get("target_id", -1)) == PLAYER:
				landed = true
		assert_eq(landed, active and tick - last_hit >= _window(), "%s tick %d" % [label, tick])
		if landed:
			last_hit = tick
			hits += 1
	return hits


## Every pad every shipped floor authors, at its own size, timing and phase offset.
func test_every_shipped_spike_pad_obeys_the_window() -> void:
	var checked: int = 0
	for depth in range(1, 5):
		var plan: FloorPlan = DepthGenerator.generate(0, depth)
		for pad: SpikePadPlan in plan.spike_pads:
			var world := SimWorld.new()
			world.set_damage_matrix({}, 1.5, 0.5)
			var rects: Array[Rect2] = [pad.rect.grow(2.0)]
			world.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
			world.register_patches(rects)
			world.register_spike_pad(pad.pad_id, pad.rect, pad.safe_ticks, pad.active_ticks, pad.phase_offset_ticks, pad.damage, pad.damage_type)
			# Start on a SAFE tick, Envoy not yet placed: three cycles from there hold exactly three
			# whole activations, never a partial one at each end.
			while world.spike_pad_ticks_until_active(pad.pad_id) == 0:
				world.tick([] as Array[Command], DT)
			assert_true(world.add_entity(PLAYER, Vector3(pad.rect.get_center().x, 0.0, pad.rect.get_center().y), 4.0, Vector3(0, 0, 1), 0.45))
			world.register_combatant(PLAYER, 100000.0, &"envoy", _window(), 0.45, &"player")
			var cycle: int = pad.safe_ticks + pad.active_ticks
			var hits: int = _assert_window_law(world, pad, 3 * cycle, "%s pad %d" % [plan.authored_layout, pad.pad_id])
			assert_eq(hits, 3, "%s pad %d: one hit per activation (active < N < cycle)" % [plan.authored_layout, pad.pad_id])
			checked += 1
	assert_eq(checked, 10, "Floor 2's six pads and Floor 4's four")


# --- 7: WHAT 90 DOES TO A SINGLE ENEMY (evidence, not an invariant) --------------------------------

## A window LONGER than every shipped enemy's attack interval means one enemy's own follow-up
## blows inside it are absorbed. This records that consequence instead of hiding it: each enemy
## still lands repeatedly, and no two of its landed hits are closer than the window.
func test_each_shipped_enemy_lands_at_most_once_per_window() -> void:
	for family_key: StringName in [&"fang", &"ooze", &"watcher"]:
		var world := SimWorld.new()
		FamilyLocomotionScenario.build(world, family_key)
		var envoy: EnvoyStats = _envoy()
		world.register_combatant(FamilyLocomotionScenario.PLAYER_ID, envoy.max_health, envoy.family,
			envoy.iframe_ticks_on_hit, envoy.combat_radius, &"player")
		world.debug_override_health(FamilyLocomotionScenario.PLAYER_ID, 100000.0)
		world.debug_set_ai_active(FamilyLocomotionScenario.ENEMY_ID)
		var hit_ticks: Array[int] = []
		for t in 900:
			for event in world.tick([] as Array[Command], DT):
				if event.kind == "hit" and int(event.payload.get("attacker_id", -2)) == FamilyLocomotionScenario.ENEMY_ID:
					hit_ticks.append(event.tick)
		assert_gt(hit_ticks.size(), 1, "%s: it still lands repeatedly" % family_key)
		for i in range(1, hit_ticks.size()):
			assert_gte(hit_ticks[i] - hit_ticks[i - 1], envoy.iframe_ticks_on_hit, "%s: one landed hit per window" % family_key)
