extends GutTest
## Burn status v1 (Phase D step 7, HANDOFF) — GAME-RULES §3: DoT ticks, one status
## slot per entity, exclusive/never stacked. Covers hit-application, the one-tick
## grace window, DoT/duration scheduling, refresh, the outcome seam (ROADMAP P2), and
## the priority-table content-lint. Contact-episode spread lives in
## test_burn_spread.gd.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"sword_burn_test"
const TARGET_FAMILY := &"test_target"  # absent from the matrix -> multiplier always 1.0
const TARGET_POSITION := Vector3(0, 0, -1)  # directly ahead of the attacker's default facing
const DAMAGE_PER_TICK := 4.0
const TICK_INTERVAL := 3
const DURATION := 9  # exactly 3 pulses across the full duration (9 / 3)


func before_each() -> void:
	sim = SimWorld.new()
	sim.seed_combat_rng(1)  # inert at chance=1.0 below (no draw), but explicit per GAME-RULES §1.3
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	# status_proc_chance=1.0 -- this file tests apply/DoT/expiry/refresh mechanics,
	# deliberately deterministic; the proc-chance/combat-RNG mechanism itself is
	# covered separately in test_status_proc.gd.
	sim.register_weapon(WEAPON_ID, 10.0, &"force", 2.0, 60.0, 1.0, 0, &"burn", 1.0)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.register_status(&"burn", DAMAGE_PER_TICK, TICK_INTERVAL, DURATION)
	sim.set_status_priority({"burn": 0})


func _register_target(max_health: float = 100.0) -> void:
	sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	sim.register_combatant(TARGET_ID, max_health, TARGET_FAMILY, 0, 0.0, &"enemy")


func _tick_attack() -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- Hit application ---

func test_hit_from_burn_weapon_applies_status_and_emits_status_applied() -> void:
	_register_target()
	var events := _tick_attack()
	var applied := _events_of_kind(events, "status_applied")
	assert_eq(applied.size(), 1)
	assert_eq(applied[0].payload.get("status_id"), "burn")
	assert_eq(applied[0].payload.get("application_source"), "hit")
	assert_eq(applied[0].payload.get("target_id"), TARGET_ID)
	assert_eq(applied[0].payload.get("source_actor_id"), ATTACKER_ID)
	assert_eq(applied[0].payload.get("source_weapon_id"), String(WEAPON_ID))
	assert_true(sim._status_instances.has(TARGET_ID))
	assert_eq(sim._status_instances[TARGET_ID].id, "burn")


func test_weapon_without_status_id_never_applies_status() -> void:
	sim.register_weapon(&"plain_sword", 10.0, &"force", 2.0, 60.0, 1.0)  # no status_id -> defaults to &""
	sim.set_equipped_weapon(ATTACKER_ID, &"plain_sword")
	_register_target()
	var events := _tick_attack()
	assert_eq(_events_of_kind(events, "status_applied").size(), 0)
	assert_false(sim._status_instances.has(TARGET_ID))


func test_lethal_hit_does_not_apply_status() -> void:
	_register_target(5.0)  # dies to the 10-damage swing
	var events := _tick_attack()
	assert_eq(_events_of_kind(events, "died").size(), 1)
	assert_eq(_events_of_kind(events, "status_applied").size(), 0)
	assert_false(sim._status_instances.has(TARGET_ID))


func test_iframe_absorbed_hit_does_not_apply_status() -> void:
	_register_target()
	sim._iframe_ticks_remaining[TARGET_ID] = 5
	var events := _tick_attack()
	assert_eq(_events_of_kind(events, "attack_absorbed").size(), 1)
	assert_eq(_events_of_kind(events, "status_applied").size(), 0)


func test_shielded_hit_does_not_apply_status() -> void:
	_register_target()
	sim.register_shield(TARGET_ID, 20.0, 1.0, 3, 2.0)
	sim.tick([Command.new(sim.tick_count, TARGET_ID, "block", {"held": true})], 1.0 / 30.0)
	var events := _tick_attack()
	assert_eq(_events_of_kind(events, "blocked").size(), 1)
	assert_eq(_events_of_kind(events, "status_applied").size(), 0)


# --- Grace window / DoT + duration scheduling ---

func test_no_status_resolved_on_the_application_tick() -> void:
	_register_target()
	var events := _tick_attack()
	assert_eq(_events_of_kind(events, "status_resolved").size(), 0, "grace: no DoT on the application tick")


func test_dot_pulses_on_schedule_and_not_before() -> void:
	_register_target()
	_tick_attack()
	for i in range(TICK_INTERVAL - 1):
		var events := _tick_noop()
		assert_eq(_events_of_kind(events, "status_resolved").size(), 0, "no pulse before the configured interval elapses")
	var pulse_events := _tick_noop()
	var resolved := _events_of_kind(pulse_events, "status_resolved")
	assert_eq(resolved.size(), 1)
	assert_almost_eq(resolved[0].payload.get("damage"), DAMAGE_PER_TICK, 0.001)


func test_status_expires_after_duration_with_final_pulse_still_applied() -> void:
	_register_target(100.0)
	_tick_attack()  # the initial weapon hit itself deals 10.0 (WEAPON_ID's own damage), on top of Burn's 3 later pulses
	var last_events: Array[Event] = []
	for i in range(DURATION):
		last_events = _tick_noop()
	var expired := _events_of_kind(last_events, "status_expired")
	assert_eq(expired.size(), 1)
	var resolved := _events_of_kind(last_events, "status_resolved")
	assert_eq(resolved.size(), 1, "the final duration tick still resolves its due pulse before expiring")
	assert_almost_eq(sim._health[TARGET_ID], 100.0 - 10.0 - 3 * DAMAGE_PER_TICK, 0.001, "initial hit (10.0) plus 3 DoT pulses total across the full duration")
	assert_false(sim._status_instances.has(TARGET_ID))


func test_lethal_dot_pulse_emits_died_and_clears_the_status() -> void:
	# The initial weapon hit itself deals 10.0 -- health must survive that hit (so
	# Burn actually gets applied, per "lethal hits skip status") but be low enough that
	# the FIRST DoT pulse afterward is lethal.
	_register_target(10.0 + DAMAGE_PER_TICK / 2.0)
	_tick_attack()
	var last_events: Array[Event] = []
	for i in range(TICK_INTERVAL):
		last_events = _tick_noop()
	assert_eq(_events_of_kind(last_events, "status_resolved").size(), 1)
	assert_eq(_events_of_kind(last_events, "died").size(), 1)
	assert_eq(_events_of_kind(last_events, "status_expired").size(), 0, "a lethal pulse clears the status via death, not expiry")
	assert_false(sim._status_instances.has(TARGET_ID))


func test_reapplying_burn_via_hit_refreshes_duration_and_schedule() -> void:
	_register_target()
	_tick_attack()  # tick_count 0 -> 1; applied_tick=0, next_tick=TICK_INTERVAL, ticks_remaining=DURATION
	_tick_noop()  # ticks_remaining decremented once; tick_count 1 -> 2
	_tick_attack()  # re-hit at tick_count=2 -> refreshes
	var instance: Dictionary = sim._status_instances[TARGET_ID]
	assert_eq(instance.ticks_remaining, DURATION, "refresh resets duration to full, never stacks")
	assert_eq(instance.next_tick, 2 + TICK_INTERVAL)
	assert_eq(instance.applied_tick, 2)


# --- Outcome seam (ROADMAP P2: status x family interaction layer, e.g. Ooze healing) ---

func test_zero_damage_outcome_still_emits_status_resolved_without_health_loss() -> void:
	sim.register_status(&"burn", 0.0, TICK_INTERVAL, DURATION)
	_register_target(100.0)
	_tick_attack()
	for i in range(TICK_INTERVAL - 1):
		_tick_noop()
	var events := _tick_noop()
	var resolved := _events_of_kind(events, "status_resolved")
	assert_eq(resolved.size(), 1, "a zero-damage outcome must still flow through as a real status_resolved event")
	assert_almost_eq(resolved[0].payload.get("damage"), 0.0, 0.001)
	assert_almost_eq(sim._health[TARGET_ID], 100.0 - 10.0, 0.001, "zero-damage DoT outcome must not touch health beyond the initial weapon hit")


# --- Content lint ---

func test_priority_table_only_references_registered_statuses() -> void:
	var priority_table: StatusPriorityTable = ContentDB.get_resource(&"status", &"priority_table")
	for status_id in priority_table.priority.keys():
		var status_resource: Resource = ContentDB.get_resource(&"status", status_id)
		assert_not_null(status_resource, "%s referenced in the priority table must resolve as a real status resource" % status_id)


# --- Determinism ---

func test_determinism_burn_apply_and_dot_sequence() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.seed_combat_rng(1)
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_weapon(WEAPON_ID, 10.0, &"force", 2.0, 60.0, 1.0, 0, &"burn", 1.0)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		local_sim.register_status(&"burn", DAMAGE_PER_TICK, TICK_INTERVAL, DURATION)
		local_sim.set_status_priority({"burn": 0})
		local_sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
		local_sim.register_combatant(TARGET_ID, 100.0, TARGET_FAMILY, 0, 0.0, &"enemy")
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
		for i in range(DURATION):
			local_sim.tick([], 1.0 / 30.0)
		results.append({"health": local_sim._health[TARGET_ID], "status_instances": local_sim._status_instances.duplicate(true)})
	assert_eq(results[0], results[1], "identical Burn command sequences must produce identical sim state")
