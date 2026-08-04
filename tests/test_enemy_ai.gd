extends GutTest
## Enemy AI (Phase D step 8 Phase 4): pursue/attack/leash state machine, reusing the
## existing combat pipeline entirely (attacks are synthesized Commands, not a second
## resolution path).

var sim: SimWorld

const PLAYER_ID := 0
const ENEMY_ID := 1
const WEAPON_ID := &"test_bite"


func _make_sim() -> SimWorld:
	return SimWorld.new()


func _register_player(s: SimWorld, position: Vector3) -> void:
	s.add_entity(PLAYER_ID, position, 4.0)
	s.register_combatant(PLAYER_ID, 30.0, &"envoy", 0, 0.4, &"player")


## preferred_attack_distance replaced the old single attack_range (engagement-spacing
## fix); minimum_attack_distance defaults to 0.0 so existing calls that don't care
## about spacing keep their prior "stop anywhere within reach" behavior unchanged.
func _register_enemy(s: SimWorld, position: Vector3, preferred_attack_distance: float = 1.5, windup_ticks: int = 10, detection_radius: float = 8.0, leash_radius: float = 10.0, fire_interval_ticks: int = 30, damage: float = 5.0, move_speed: float = 3.0, minimum_attack_distance: float = 0.0) -> void:
	s.add_entity(ENEMY_ID, position, move_speed)
	s.register_combatant(ENEMY_ID, 20.0, &"fang", 15, 1.0, &"enemy")
	s.register_weapon(WEAPON_ID, damage, &"force", preferred_attack_distance, 90.0, 0.0, fire_interval_ticks)
	s.register_ai(ENEMY_ID, WEAPON_ID, position, preferred_attack_distance, minimum_attack_distance, windup_ticks, detection_radius, leash_radius)


func _tick(s: SimWorld, times: int) -> Array[Event]:
	var all_events: Array[Event] = []
	for i in times:
		all_events.append_array(s.tick([], 1.0 / 30.0))
	return all_events


func test_pursuit_closes_and_stops_at_attack_range() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -5), 1.5, 10000, 8.0, 10.0, 9999)
	_tick(sim, 90)
	var distance: float = sim.entities[ENEMY_ID].distance_to(sim.entities[PLAYER_ID])
	assert_lt(distance, 5.0, "enemy should have moved closer to the player")
	assert_true(distance <= 1.6, "enemy should stop once within (near) attack range, not walk into/through the player")


func test_hit_lands_exactly_windup_ticks_after_telegraph() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -1.0), 1.5, 10, 8.0, 10.0, 9999)
	var events: Array[Event] = _tick(sim, 11)
	var telegraphs := events.filter(func(e): return e.kind == "attack_telegraph")
	var hits := events.filter(func(e): return e.kind == "hit")
	assert_eq(telegraphs.size(), 1)
	assert_eq(hits.size(), 1)
	if telegraphs.size() == 1 and hits.size() == 1:
		assert_eq(hits[0].tick - telegraphs[0].tick, 10, "hit must land exactly windup_ticks after its telegraph")


# --- Attack priority over movement (locked defect fix, pre-gate pass) ---
# "Distance preferences govern movement only; they never gate attack eligibility" --
# crowding an enemy inside its own minimum_attack_distance must never suppress an
# otherwise-valid attack (the actual defect: retreat used to pre-empt it).

func test_crowded_target_with_cooldown_ready_still_triggers_attack() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	# Distance 0.2 is deep inside minimum_attack_distance(0.8) -- crowded.
	_register_enemy(sim, Vector3(0, 0, -0.2), 1.5, 10, 8.0, 10.0, 9999, 5.0, 3.0, 0.8)
	var events: Array[Event] = sim.tick([], 1.0 / 30.0)
	assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 1, "cooldown ready + within reach must start an attack even when crowded inside minimum_attack_distance")


func test_crowding_cannot_suppress_attacks_indefinitely() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	# Player stands still, deep inside minimum(0.8), for the whole run.
	_register_enemy(sim, Vector3(0, 0, -0.2), 1.5, 10, 8.0, 10.0, 30, 5.0, 3.0, 0.8)
	var telegraph_count := 0
	for i in 100:
		var events: Array[Event] = sim.tick([], 1.0 / 30.0)
		telegraph_count += events.filter(func(e): return e.kind == "attack_telegraph").size()
	assert_gt(telegraph_count, 1, "crowding must never permanently disarm an enemy -- it must land repeated attacks over time, not just once and then go silent")


func test_enemy_attack_resolves_at_near_zero_separation() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, 0), 1.5, 5, 8.0, 10.0, 9999, 5.0, 3.0, 0.8)  # exact same position as the player
	var events: Array[Event] = _tick(sim, 6)
	assert_eq(events.filter(func(e): return e.kind == "hit").size(), 1, "point-blank (near-zero separation) melee must still resolve a hit")


## Windup is never cancelled by a distance change (locked, pre-gate fix pass:
## "distance preferences govern movement only" applies to an in-progress windup
## too) -- it always runs to completion and the Command fires at fire_tick
## regardless. If the target has genuinely left the WEAPON's real reach by then,
## the swing simply misses via the same reach check every attack goes through;
## that's a miss, not a cancellation, and _next_fire_tick advancing anyway proves
## the attack was actually attempted rather than silently dropped.
func test_windup_completes_and_fires_even_after_target_leaves_range_then_misses() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -1.0), 1.5, 10, 8.0, 10.0, 9999)
	_tick(sim, 3)
	# Still well within leash_radius(10) of spawn(0,0,-1) -- this is about the
	# windup itself, not the leash.
	sim.entities[PLAYER_ID] = Vector3(0, 0, 5.0)
	var events: Array[Event] = _tick(sim, 20)
	assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 0, "no SECOND telegraph -- this is still the original windup completing, not a fresh one")
	var hits := events.filter(func(e): return e.kind == "hit")
	assert_eq(hits.size(), 0, "the target genuinely left weapon reach by fire_tick, so the completed swing misses")
	assert_eq(sim._next_fire_tick[ENEMY_ID], 10 + 9999, "the fire-cooldown gate must have advanced -- proving the attack was actually attempted, not silently dropped")


func test_blocked_enemy_hit_damages_shield_meter_not_health() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	sim.register_shield(PLAYER_ID, 20.0, 0.0, 30, 1.0)
	_register_enemy(sim, Vector3(0, 0, -1.0), 1.5, 5, 8.0, 10.0, 9999)
	var events: Array[Event] = []
	for i in 6:
		events.append_array(sim.tick([Command.new(sim.tick_count, PLAYER_ID, "block", {"held": true})], 1.0 / 30.0))
	var hits := events.filter(func(e): return e.kind == "hit")
	var blocked := events.filter(func(e): return e.kind == "blocked")
	assert_eq(hits.size(), 0)
	assert_eq(blocked.size(), 1)
	assert_almost_eq(sim._health[PLAYER_ID], 30.0, 0.001, "a blocked enemy hit must deal zero health damage")


func test_iframes_absorb_an_enemy_hit() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -1.0), 1.5, 5, 8.0, 10.0, 9999)
	sim._iframe_ticks_remaining[PLAYER_ID] = 30
	var events: Array[Event] = _tick(sim, 6)
	var hits := events.filter(func(e): return e.kind == "hit")
	var absorbed := events.filter(func(e): return e.kind == "attack_absorbed")
	assert_eq(hits.size(), 0)
	assert_eq(absorbed.size(), 1)
	assert_almost_eq(sim._health[PLAYER_ID], 30.0, 0.001)


func test_cooldown_gates_attack_cadence() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -1.0), 1.5, 5, 8.0, 10.0, 20)
	var events: Array[Event] = _tick(sim, 6)  # first attack fires at tick 5
	assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 1)

	events = _tick(sim, 10)  # ticks 6..15 -- inside the tick-5 attack's 20-tick cooldown
	assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 0, "no new windup should start before fire_interval_ticks elapses")

	events = _tick(sim, 10)  # ticks 16..25 -- cooldown (tick 5 + 20 = tick 25) elapses within this batch
	assert_eq(events.filter(func(e): return e.kind == "attack_telegraph").size(), 1, "a new windup should start once the shared fire cooldown elapses")


func test_dead_enemy_emits_nothing() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -1.0), 1.5, 5, 8.0, 10.0, 9999)
	sim._health[ENEMY_ID] = 0.0
	var events: Array[Event] = _tick(sim, 20)
	assert_eq(events.size(), 0, "a dead enemy must not move, telegraph, or attack")


## Disengagement (locked behavior change, pre-gate fix pass): no universal
## return-to-spawn. On leash-exceeded, the enemy stops EXACTLY where it is and goes
## idle immediately -- it never paths home.
func test_disengaged_enemy_stops_in_place_and_idles() -> void:
	sim = _make_sim()
	var spawn := Vector3(0, 0, -5)
	_register_player(sim, Vector3(0, 0, -2))
	_register_enemy(sim, spawn, 0.5, 100000, 8.0, 8.0, 9999, 5.0, 3.0)
	sim._next_fire_tick[ENEMY_ID] = 100000  # keep this purely about movement, not attack priority
	_tick(sim, 60)  # pursue and settle near the player
	var position_at_disengage_trigger: Vector3 = sim.entities[ENEMY_ID]
	assert_gt(position_at_disengage_trigger.distance_to(spawn), 1.0, "sanity: the enemy must have actually left its spawn to chase")

	sim.entities[PLAYER_ID] = Vector3(0, 0, 100)  # now far outside leash_radius -- triggers disengage
	_tick(sim, 1)
	assert_eq(sim._ai_state[ENEMY_ID], "idle", "leash-exceeded must go idle immediately, not a 'returning' transit state")
	var position_right_after_disengage: Vector3 = sim.entities[ENEMY_ID]

	_tick(sim, 60)  # if any homeward pathing remained, this window would reveal it
	assert_eq(sim.entities[ENEMY_ID], position_right_after_disengage, "a disengaged enemy must never move again on its own -- no homeward pathing")
	assert_gt(sim.entities[ENEMY_ID].distance_to(spawn), 1.0, "it must NOT have walked back toward the original spawn point")


func test_reanchored_leash_governs_the_next_chase() -> void:
	sim = _make_sim()
	var spawn := Vector3(0, 0, -5)
	_register_player(sim, Vector3(0, 0, -2))
	_register_enemy(sim, spawn, 0.5, 100000, 8.0, 8.0, 9999, 5.0, 3.0)
	sim._next_fire_tick[ENEMY_ID] = 100000
	_tick(sim, 60)  # pursue away from spawn
	sim.entities[PLAYER_ID] = Vector3(0, 0, 100)  # disengage -- re-anchors here
	_tick(sim, 1)
	var new_anchor: Vector3 = sim.entities[ENEMY_ID]
	assert_ne(new_anchor, spawn, "sanity: the new anchor must differ from the original spawn")

	# Re-acquire from the new anchor, then check the leash is measured from IT, not
	# the original spawn: probe further along the same (spawn -> new_anchor)
	# direction, comfortably within leash_radius(8.0) of the new anchor but by
	# construction even farther from the OLD spawn than the new anchor already is.
	sim.entities[PLAYER_ID] = new_anchor  # within detection of the new anchor -> re-acquires
	_tick(sim, 1)
	assert_eq(sim._ai_state[ENEMY_ID], "active")
	var away_from_spawn: Vector3 = (new_anchor - spawn).normalized() if new_anchor != spawn else Vector3(1, 0, 0)
	var probe_position: Vector3 = new_anchor + away_from_spawn * 7.9  # within leash_radius(8.0) of new_anchor
	assert_gt(probe_position.distance_to(spawn), 8.0, "sanity: this probe point is already beyond the leash measured from the OLD spawn")
	sim.entities[PLAYER_ID] = probe_position
	_tick(sim, 1)
	assert_eq(sim._ai_state[ENEMY_ID], "active", "the leash must be measured from the re-anchored position, not the original spawn")


func test_detection_resumes_from_the_new_anchor_after_disengage() -> void:
	sim = _make_sim()
	var spawn := Vector3(0, 0, -5)
	_register_player(sim, Vector3(0, 0, -2))
	_register_enemy(sim, spawn, 0.5, 100000, 2.0, 8.0, 9999, 5.0, 3.0)
	sim._next_fire_tick[ENEMY_ID] = 100000
	_tick(sim, 60)  # pursue away from spawn
	sim.entities[PLAYER_ID] = Vector3(0, 0, 100)
	_tick(sim, 1)  # disengage; re-anchors and goes idle
	var new_anchor: Vector3 = sim.entities[ENEMY_ID]
	assert_eq(sim._ai_state[ENEMY_ID], "idle")

	# Far from the NEW anchor's detection_radius(2.0) -- must stay idle.
	sim.entities[PLAYER_ID] = new_anchor + Vector3(20.0, 0, 0)
	_tick(sim, 5)
	assert_eq(sim._ai_state[ENEMY_ID], "idle", "must not detect from far outside the new anchor's detection_radius")

	# Within the NEW anchor's detection_radius -- must re-acquire.
	sim.entities[PLAYER_ID] = new_anchor + Vector3(1.0, 0, 0)
	_tick(sim, 1)
	assert_eq(sim._ai_state[ENEMY_ID], "active", "must re-acquire from the new anchor's detection_radius, exactly like the original idle->active rule")


## "Spawn positions remain scene-initialization/encounter-reset data only" (locked):
## re-registering (as happens on an arena reset / fresh SimWorld) explicitly restores
## the authored spawn, overriding any runtime re-anchoring from a prior encounter.
func test_encounter_reset_restores_spawn_position_explicitly() -> void:
	sim = _make_sim()
	var original_spawn := Vector3(0, 0, -5)
	_register_player(sim, Vector3(0, 0, -2))
	_register_enemy(sim, original_spawn, 0.5, 100000, 8.0, 8.0, 9999, 5.0, 3.0)
	sim._next_fire_tick[ENEMY_ID] = 100000
	_tick(sim, 60)
	sim.entities[PLAYER_ID] = Vector3(0, 0, 100)
	_tick(sim, 1)  # disengage -- re-anchors away from original_spawn
	assert_ne(sim._ai_spawn_position[ENEMY_ID], original_spawn, "sanity: the anchor must have moved off the original spawn")

	sim.register_ai(ENEMY_ID, WEAPON_ID, original_spawn, 0.5, 0.0, 100000, 8.0, 8.0)
	assert_eq(sim._ai_spawn_position[ENEMY_ID], original_spawn, "an explicit encounter reset (re-registration) must restore the authored spawn position")


func test_idle_enemy_acquires_only_on_detection_entry() -> void:
	sim = _make_sim()
	var spawn := Vector3(0, 0, 0)
	_register_player(sim, Vector3(0, 0, -20))  # far outside detection_radius
	_register_enemy(sim, spawn, 1.5, 10000, 5.0, 8.0, 9999, 5.0, 3.0)
	var events_far: Array[Event] = _tick(sim, 10)
	assert_eq(events_far.filter(func(e): return e.kind == "moved").size(), 0, "an idle enemy outside detection_radius must not move")

	sim.entities[PLAYER_ID] = Vector3(0, 0, -3)  # now within detection_radius(5.0)
	var events_near: Array[Event] = _tick(sim, 10)
	assert_gt(events_near.filter(func(e): return e.kind == "moved").size(), 0, "the enemy must acquire and pursue once the player enters detection_radius")


func test_identical_starting_state_produces_identical_events() -> void:
	var sim_a := _make_sim()
	_register_player(sim_a, Vector3(0, 0, -3))
	_register_enemy(sim_a, Vector3(0, 0, 0), 1.5, 8, 8.0, 10.0, 40)

	var sim_b := _make_sim()
	_register_player(sim_b, Vector3(0, 0, -3))
	_register_enemy(sim_b, Vector3(0, 0, 0), 1.5, 8, 8.0, 10.0, 40)

	for i in 60:
		var events_a: Array[Event] = sim_a.tick([], 1.0 / 30.0)
		var events_b: Array[Event] = sim_b.tick([], 1.0 / 30.0)
		assert_eq(events_a.size(), events_b.size(), "tick %d event count must match" % i)
		for j in events_a.size():
			assert_eq(events_a[j].kind, events_b[j].kind)
			assert_eq(events_a[j].payload, events_b[j].payload)
	assert_eq(sim_a.entities[ENEMY_ID], sim_b.entities[ENEMY_ID])


# --- Hit-establishes-aggro (locked defect fix, pre-gate pass) ---

func test_hit_from_outside_detection_activates() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, -1.0))
	# detection_radius=0.5 is far smaller than the 1.0 distance the player attacks
	# from -- passive idle->active would never trigger on its own here.
	_register_enemy(sim, Vector3(0, 0, 0), 1.5, 10000, 0.5, 10.0, 9999)
	assert_eq(sim._ai_state[ENEMY_ID], "idle")
	sim.register_weapon(&"player_test_sword", 5.0, &"force", 2.0, 90.0, 0.0)
	sim.set_equipped_weapon(PLAYER_ID, &"player_test_sword")
	sim.tick([Command.new(sim.tick_count, PLAYER_ID, "attack", {"aim": Vector3(0, 0, 1)})], 1.0 / 30.0)
	assert_eq(sim._ai_state[ENEMY_ID], "active", "a landed hostile hit from the player must activate the target regardless of detection_radius")


func test_activated_enemy_stays_active_outside_detection_but_inside_leash() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, -1.0))
	_register_enemy(sim, Vector3(0, 0, 0), 1.5, 10000, 0.5, 10.0, 9999)
	sim._ai_state[ENEMY_ID] = "active"  # simulate already-activated via a prior hit
	sim.entities[PLAYER_ID] = Vector3(0, 0, -3.0)  # outside detection_radius(0.5), inside leash_radius(10.0)
	_tick(sim, 20)
	assert_eq(sim._ai_state[ENEMY_ID], "active", "aggro must persist outside detection_radius as long as the player stays within leash_radius")


func test_leash_exceed_after_activation_disengages_in_place() -> void:
	sim = _make_sim()
	var spawn := Vector3(0, 0, 0)
	_register_player(sim, Vector3(0, 0, -1.0))
	_register_enemy(sim, spawn, 1.5, 10000, 0.5, 5.0, 9999)
	sim._ai_state[ENEMY_ID] = "active"
	var position_before_disengage: Vector3 = sim.entities[ENEMY_ID]
	sim.entities[PLAYER_ID] = Vector3(0, 0, 50)  # beyond leash_radius(5.0) from spawn
	_tick(sim, 1)
	assert_eq(sim._ai_state[ENEMY_ID], "idle", "exceeding the leash after an aggro-establishing hit must still disengage and reset to idle")
	assert_eq(sim.entities[ENEMY_ID], position_before_disengage, "disengage must stop the enemy in place, never path it home")


func test_burn_tick_alone_does_not_reaggro_a_reset_enemy() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 50))  # far outside detection_radius and leash_radius
	_register_enemy(sim, Vector3(0, 0, 0), 1.5, 10000, 2.0, 5.0, 9999)
	sim.register_status(&"burn", 1.0, 2, 10)
	# Directly place an already-active status instance, bypassing _apply_status
	# entirely -- the aggro-establishment hook only fires on an APPLICATION, so this
	# setup proves a subsequent TICK alone (not a fresh application) is being tested,
	# exactly like a status that was applied earlier and is now just resolving.
	sim._status_instances[ENEMY_ID] = {"id": "burn", "ticks_remaining": 10, "next_tick": sim.tick_count + 1, "applied_tick": -1}
	assert_eq(sim._ai_state[ENEMY_ID], "idle")
	_tick(sim, 5)  # long enough for at least one DoT pulse to resolve
	assert_eq(sim._ai_state[ENEMY_ID], "idle", "a status TICK alone must never (re-)establish aggro, only an APPLICATION can")


# --- Engagement spacing (locked defect fix, pre-gate pass) ---

func test_enemy_settles_in_band_and_never_overlaps_player() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	_register_enemy(sim, Vector3(0, 0, -5), 1.5, 10000, 8.0, 10.0, 9999, 5.0, 3.0, 0.8)
	_tick(sim, 90)
	var distance: float = sim.entities[ENEMY_ID].distance_to(sim.entities[PLAYER_ID])
	assert_true(distance >= 0.8 and distance <= 1.6, "enemy must settle inside its engagement band, never overlapping the player")


## Attack priority (locked defect fix) means retreat only runs when an attack ISN'T
## simultaneously eligible -- so isolating pure retreat behavior needs the weapon's
## cooldown busy (see "during cooldown, the enemy may still retreat" requirement).
## Without this, a fresh actor's cooldown defaults to "ready", and this scenario's
## distance is well within reach, so the enemy would correctly attack instead.
func test_too_close_backs_away() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	# Starts well inside minimum_attack_distance(0.8).
	_register_enemy(sim, Vector3(0, 0, -0.3), 1.5, 10000, 8.0, 10.0, 9999, 5.0, 3.0, 0.8)
	sim._next_fire_tick[ENEMY_ID] = 100000  # cooldown busy: isolate movement from attack priority
	var initial_distance: float = sim.entities[ENEMY_ID].distance_to(sim.entities[PLAYER_ID])
	_tick(sim, 5)
	var later_distance: float = sim.entities[ENEMY_ID].distance_to(sim.entities[PLAYER_ID])
	assert_gt(later_distance, initial_distance, "an enemy closer than minimum_attack_distance must back away")


## Ooze retreat bug, direction 1 (locked invariant): the decision is recomputed from
## CURRENT distance every tick, never carried over -- so a retreating enemy must stop
## the INSTANT the gap reaches minimum_attack_distance, even while the player's own
## retreat keeps widening the gap further afterward. Checked per-tick via the
## enemy's actual movement direction (not the sim's internal decision label, so this
## test stays meaningful even if that internal representation ever changes).
func test_backing_away_ends_the_instant_distance_reaches_minimum() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	var minimum := 0.8
	_register_enemy(sim, Vector3(0, 0, -0.3), 1.8, 10000, 8.0, 10.0, 9999, 5.0, 3.0, minimum)
	# Attack priority (locked defect fix) would otherwise take over here (cooldown
	# defaults to ready, distance is well within reach) -- busy the cooldown so this
	# test isolates movement, per "distance preferences govern movement only."
	sim._next_fire_tick[ENEMY_ID] = 100000
	var saw_back_away := false
	for i in 60:
		var pre_player: Vector3 = sim.entities[PLAYER_ID]
		var pre_enemy: Vector3 = sim.entities[ENEMY_ID]
		var pre_distance: float = pre_enemy.distance_to(pre_player)
		var to_enemy: Vector3 = pre_enemy - pre_player
		to_enemy.y = 0.0
		var retreat_direction: Vector3 = to_enemy.normalized() if to_enemy.length() > 0.001 else Vector3(0, 0, 1)
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": retreat_direction})], 1.0 / 30.0)
		var post_enemy: Vector3 = sim.entities[ENEMY_ID]
		var enemy_delta: Vector3 = post_enemy - pre_enemy
		if pre_distance < minimum:
			saw_back_away = true
			continue
		# At or above minimum: the enemy must not have moved further away from
		# where the player stood at the start of THIS tick (no residual back-away).
		if enemy_delta.length() > 0.0001:
			var away_direction: Vector3 = pre_enemy - pre_player
			away_direction.y = 0.0
			away_direction = away_direction.normalized()
			var away_component: float = enemy_delta.normalized().dot(away_direction)
			assert_true(away_component <= 0.01, "tick %d: distance %.3f >= minimum %.3f, but the enemy still moved away from the player" % [i, pre_distance, minimum])
	assert_true(saw_back_away, "sanity: the enemy must have actually been below minimum at some point in this run")


## Ooze retreat bug, direction 2 (reactivity proven both ways, locked): a sticky
## "back away for N ticks then give up" state would show up here as the enemy
## freezing or drifting sideways while still below minimum, even as a faster player
## keeps closing the gap it can't outrun.
func test_enemy_keeps_backing_away_while_a_faster_player_advances_into_it() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, -0.7))
	var minimum := 1.0
	_register_enemy(sim, Vector3(0, 0, -1.0), 1.8, 10000, 8.0, 10.0, 9999, 5.0, 1.5, minimum)  # ooze-like speed, slower than the player
	sim._next_fire_tick[ENEMY_ID] = 100000  # cooldown busy: isolate movement from attack priority
	var checked_ticks := 0
	for i in 40:
		var pre_player: Vector3 = sim.entities[PLAYER_ID]
		var pre_enemy: Vector3 = sim.entities[ENEMY_ID]
		var pre_distance: float = pre_enemy.distance_to(pre_player)
		var toward_enemy: Vector3 = pre_enemy - pre_player
		toward_enemy.y = 0.0
		var advance_direction: Vector3 = toward_enemy.normalized() if toward_enemy.length() > 0.001 else Vector3(0, 0, -1)
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": advance_direction})], 1.0 / 30.0)
		if pre_distance >= minimum:
			continue
		checked_ticks += 1
		var post_enemy: Vector3 = sim.entities[ENEMY_ID]
		var enemy_delta: Vector3 = post_enemy - pre_enemy
		assert_true(enemy_delta.length() > 0.0001, "tick %d: an enemy below minimum_attack_distance must actively try to back away, never stand frozen" % i)
		var away_direction: Vector3 = pre_enemy - pre_player
		away_direction.y = 0.0
		away_direction = away_direction.normalized()
		var away_component: float = enemy_delta.normalized().dot(away_direction)
		assert_true(away_component > 0.5, "tick %d: the enemy's movement must be directed away from the player" % i)
	assert_gt(checked_ticks, 0, "sanity: the enemy must have been below minimum for at least one checked tick")


func test_position_frozen_during_windup() -> void:
	sim = _make_sim()
	_register_player(sim, Vector3(0, 0, 0))
	# Distance 1.0 sits inside [0.8, 1.5] from the start -- no approach/back-away first.
	_register_enemy(sim, Vector3(0, 0, -1.0), 1.5, 20, 8.0, 10.0, 9999, 5.0, 3.0, 0.8)
	_tick(sim, 1)  # windup begins
	var position_during_windup: Vector3 = sim.entities[ENEMY_ID]
	_tick(sim, 5)  # still winding (windup_ticks=20)
	assert_eq(sim.entities[ENEMY_ID], position_during_windup, "position must stay frozen for the whole windup")


func test_engagement_spacing_is_deterministic() -> void:
	var sim_a := _make_sim()
	_register_player(sim_a, Vector3(0, 0, -3))
	_register_enemy(sim_a, Vector3(0, 0, 0), 1.5, 8, 8.0, 10.0, 40, 5.0, 3.0, 0.8)

	var sim_b := _make_sim()
	_register_player(sim_b, Vector3(0, 0, -3))
	_register_enemy(sim_b, Vector3(0, 0, 0), 1.5, 8, 8.0, 10.0, 40, 5.0, 3.0, 0.8)

	for i in 60:
		var events_a: Array[Event] = sim_a.tick([], 1.0 / 30.0)
		var events_b: Array[Event] = sim_b.tick([], 1.0 / 30.0)
		assert_eq(events_a.size(), events_b.size(), "tick %d event count must match" % i)
		for j in events_a.size():
			assert_eq(events_a[j].kind, events_b[j].kind)
			assert_eq(events_a[j].payload, events_b[j].payload)
	assert_eq(sim_a.entities[ENEMY_ID], sim_b.entities[ENEMY_ID])
