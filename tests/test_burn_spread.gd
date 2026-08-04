extends GutTest
## Burn contact-episode spread (Phase D step 7, HANDOFF) — GAME-RULES §3 "spreads on
## contact", locked design: combat_radius overlap, one-tick grace, one transmission
## per undirected pair per continuous contact episode, player<->player rejected.
## Hit-application/DoT/expiry/refresh mechanics live in test_burn.gd; this file is
## contact-spread only, using a direct _apply_status helper (_ignite) to seed a
## Burning actor without needing a real weapon/attack in play.

var sim: SimWorld

const DAMAGE_PER_TICK := 1.0
## Deliberately long so no DoT pulse ever fires during these spread-focused tests --
## keeps health/pulse timing out of the picture; only application/expiry matter here.
const TICK_INTERVAL := 100
const DURATION := 5


func before_each() -> void:
	sim = SimWorld.new()
	sim.register_status(&"burn", DAMAGE_PER_TICK, TICK_INTERVAL, DURATION)
	sim.set_status_priority({"burn": 0})


func _register(actor_id: int, position: Vector3, combat_radius: float, allegiance: StringName) -> void:
	sim.add_entity(actor_id, position, 0.0)
	sim.register_combatant(actor_id, 100.0, &"test_family", 0, combat_radius, allegiance)


## Seeds actor_id as already-Burning without a real attack -- isolates contact-spread
## behavior from hit-application mechanics (covered separately in test_burn.gd).
func _ignite(actor_id: int) -> void:
	sim._apply_status(actor_id, &"burn", "hit", -1, "")


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- Grace window ---

func test_newly_ignited_target_does_not_spread_on_its_application_tick() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")  # already overlapping (distance 1.0 <= radius sum 2.0)
	_ignite(1)
	var events := _tick_noop()  # tick_count still 0 at scan time -- 1's applied_tick(0) == tick_count(0)
	assert_eq(_events_of_kind(events, "status_applied").size(), 0, "grace: cannot spread on its own application tick")


func test_preexisting_overlap_transmits_once_source_becomes_eligible() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()  # grace tick
	var events := _tick_noop()  # 1 now eligible -- overlap existed before 1 was even Burning
	var applied := _events_of_kind(events, "status_applied")
	assert_eq(applied.size(), 1)
	assert_eq(applied[0].payload.get("application_source"), "spread")
	assert_eq(applied[0].payload.get("target_id"), 2)
	assert_eq(applied[0].payload.get("source_actor_id"), 1)
	assert_true(sim._status_instances.has(2))


func test_separating_during_grace_window_prevents_transmission() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()  # grace tick
	sim.entities[1] = Vector3(100, 0, 0)  # 1 moves away before it becomes an eligible source
	var events := _tick_noop()
	assert_eq(_events_of_kind(events, "status_applied").size(), 0, "separation before eligibility must prevent transmission")


func test_newly_spread_burn_does_not_chain_within_the_same_tick() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")          # A -- source
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")       # B -- overlaps A only
	_register(3, Vector3(2.5, 0, 0), 1.0, &"enemy")     # C -- overlaps B only (A-C distance 2.5 > combined radius 2.0)
	_ignite(1)
	_tick_noop()  # grace for A
	var events := _tick_noop()  # A -> B transmits this tick
	assert_true(sim._status_instances.has(2))
	assert_false(sim._status_instances.has(3), "C must not catch fire in the same tick B first catches it")
	assert_eq(_events_of_kind(events, "status_applied").filter(func(e): return e.payload.get("target_id") == 3).size(), 0)
	_tick_noop()  # grace for B
	_tick_noop()  # B -> C transmits once B is itself an eligible source
	assert_true(sim._status_instances.has(3), "C catches it once B becomes an eligible source on a later tick")


func test_hit_applied_burn_can_spread_back_to_an_overlapping_source_via_contact() -> void:
	# A hit-driven application never touches _contact_transmitted_pairs (only the
	# contact-spread phase does) -- so if the "attacker" that just ignited a target via
	# a weapon hit remains overlapping it, the target can spread it back once its own
	# grace clears, since this specific pair has never transmitted via contact before.
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	sim._apply_status(2, &"burn", "hit", 1, "sword_burn_test")  # simulates 1's melee hit landing on 2
	_tick_noop()  # grace for 2
	var events := _tick_noop()  # 2 now eligible; 1 still overlapping and unburned
	var applied := _events_of_kind(events, "status_applied")
	assert_eq(applied.size(), 1)
	assert_eq(applied[0].payload.get("target_id"), 1)
	assert_eq(applied[0].payload.get("source_actor_id"), 2)
	assert_eq(applied[0].payload.get("application_source"), "spread")


# --- Allegiance ---

func test_enemy_to_enemy_spread_works() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()
	var events := _tick_noop()
	assert_eq(_events_of_kind(events, "status_applied").size(), 1)


func test_enemy_to_player_spread_works() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"player")
	_ignite(1)
	_tick_noop()
	var events := _tick_noop()
	assert_eq(_events_of_kind(events, "status_applied").size(), 1)


func test_player_to_enemy_spread_works() -> void:
	_register(1, Vector3.ZERO, 1.0, &"player")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()
	var events := _tick_noop()
	assert_eq(_events_of_kind(events, "status_applied").size(), 1)


func test_player_to_player_spread_is_rejected() -> void:
	_register(1, Vector3.ZERO, 1.0, &"player")
	_register(2, Vector3(1, 0, 0), 1.0, &"player")
	_ignite(1)
	_tick_noop()
	var events := _tick_noop()
	assert_eq(_events_of_kind(events, "status_applied").size(), 0, "player -> player spread must be rejected")
	assert_false(sim._status_instances.has(2))


# --- One transmission per continuous contact episode ---

func test_pair_cannot_retransmit_twice_in_one_continuous_episode() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()  # grace
	_tick_noop()  # transmits 1 -> 2
	assert_true(sim._status_instances.has(2))
	# Directly clear 2's status (not via expiry) to isolate "already transmitted this
	# episode" from status-duration bookkeeping.
	sim._status_instances.erase(2)
	var events := _tick_noop()  # still overlapping, 1 still Burning, but the pair already transmitted
	assert_eq(_events_of_kind(events, "status_applied").size(), 0, "a pair that already transmitted this episode must not transmit again while still overlapping")


func test_separation_then_recontact_allows_a_new_transmission() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()  # grace
	_tick_noop()  # transmits 1 -> 2
	assert_true(sim._status_instances.has(2))
	sim._status_instances.erase(2)
	sim.entities[2] = Vector3(100, 0, 0)  # separate
	_tick_noop()  # cleanup clears the stale pair marker (no longer overlapping)
	sim.entities[2] = Vector3(1, 0, 0)  # re-contact
	var events := _tick_noop()
	assert_eq(_events_of_kind(events, "status_applied").size(), 1, "separation followed by renewed overlap must permit a new transmission")


func test_contact_pair_marker_clears_on_separation() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()
	_tick_noop()  # transmits, pair marked
	assert_true(sim._contact_transmitted_pairs.has(Vector2i(1, 2)))
	sim.entities[2] = Vector3(100, 0, 0)
	_tick_noop()
	assert_false(sim._contact_transmitted_pairs.has(Vector2i(1, 2)))


func test_contact_pair_marker_clears_on_death() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()
	_tick_noop()  # transmits, pair marked
	assert_true(sim._contact_transmitted_pairs.has(Vector2i(1, 2)))
	sim._health[2] = 0.0  # simulate death from an unrelated source
	_tick_noop()
	assert_false(sim._contact_transmitted_pairs.has(Vector2i(1, 2)))


# --- Event vocabulary ---

## Duration inheritance (locked, pre-gate fix pass): spread grants the recipient
## the transmitting source's REMAINING duration at transmission time, capped at the
## configured full duration -- never a fresh full-duration copy. This block
## deliberately overrides the shared DURATION(5)/TICK_INTERVAL(100) config with a
## bigger duration so there's room to observe a genuinely-decayed remaining value.

func test_spread_transmits_at_most_the_sources_remaining_duration() -> void:
	sim.register_status(&"burn", DAMAGE_PER_TICK, TICK_INTERVAL, 90)
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(100, 0, 0), 1.0, &"enemy")  # far apart -- no contact while ticking down
	_ignite(1)
	for i in range(51):  # 1st call is the grace tick (no decrement); 50 further decrements: 90 -> 40
		_tick_noop()
	assert_eq(sim._status_instances[1].ticks_remaining, 40, "sanity: source must be at exactly 40 remaining before contact")
	sim.entities[2] = Vector3(1, 0, 0)  # bring into contact
	_tick_noop()  # transmits -- source already eligible
	assert_true(sim._status_instances.has(2))
	assert_eq(sim._status_instances[2].ticks_remaining, 40, "recipient must inherit the source's remaining duration, not a fresh full-duration copy")


func test_spread_transmission_never_alters_the_sources_own_duration() -> void:
	sim.register_status(&"burn", DAMAGE_PER_TICK, TICK_INTERVAL, 90)
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(100, 0, 0), 1.0, &"enemy")
	_ignite(1)
	for i in range(51):
		_tick_noop()
	sim.entities[2] = Vector3(1, 0, 0)
	_tick_noop()  # transmits; source also takes its own normal per-tick decrement THIS tick
	assert_eq(sim._status_instances[1].ticks_remaining, 39, "the source's own duration must keep decrementing on its own schedule, unaffected by having just transmitted")


func test_spread_chain_remaining_duration_is_monotonically_non_increasing() -> void:
	sim.register_status(&"burn", DAMAGE_PER_TICK, TICK_INTERVAL, 20)
	_register(1, Vector3.ZERO, 1.0, &"enemy")          # A -- source
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")       # B -- overlaps A only
	_register(3, Vector3(2.5, 0, 0), 1.0, &"enemy")     # C -- overlaps B only
	_ignite(1)
	_tick_noop()  # grace for A
	_tick_noop()  # A -> B transmits
	assert_true(sim._status_instances.has(2))
	var hop1_remaining: int = sim._status_instances[2].ticks_remaining
	assert_true(hop1_remaining <= 20)
	_tick_noop()  # grace for B
	_tick_noop()  # B -> C transmits
	assert_true(sim._status_instances.has(3))
	var hop2_remaining: int = sim._status_instances[3].ticks_remaining
	assert_true(hop2_remaining <= hop1_remaining, "each hop's remaining duration must never exceed the previous hop's -- a chain can only lose duration, never gain it")


func test_separation_then_recontact_transmits_the_sources_current_remaining_duration() -> void:
	sim.register_status(&"burn", DAMAGE_PER_TICK, TICK_INTERVAL, 20)
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()  # grace
	_tick_noop()  # first transmission -- no decrements have occurred yet, so this is a full-duration snapshot
	assert_true(sim._status_instances.has(2))
	assert_eq(sim._status_instances[2].ticks_remaining, 20)
	sim._status_instances.erase(2)  # target becomes unburned again (not via expiry -- isolates from duration bookkeeping)
	sim.entities[2] = Vector3(100, 0, 0)  # separate
	for i in range(10):
		_tick_noop()  # cleanup clears the stale pair marker; source keeps decaying
	sim.entities[2] = Vector3(1, 0, 0)  # re-contact
	var events := _tick_noop()  # second transmission
	assert_eq(_events_of_kind(events, "status_applied").size(), 1, "separation followed by renewed overlap to a currently-unburned target must still transmit")
	assert_true(sim._status_instances.has(2))
	assert_lt(sim._status_instances[2].ticks_remaining, 20, "the second transmission must reflect the source's CURRENT (lower) remaining duration, not the first snapshot")


func test_spread_chain_duration_is_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.register_status(&"burn", DAMAGE_PER_TICK, TICK_INTERVAL, 20)
		local_sim.set_status_priority({"burn": 0})
		local_sim.add_entity(1, Vector3.ZERO, 0.0)
		local_sim.register_combatant(1, 100.0, &"test_family", 0, 1.0, &"enemy")
		local_sim.add_entity(2, Vector3(1, 0, 0), 0.0)
		local_sim.register_combatant(2, 100.0, &"test_family", 0, 1.0, &"enemy")
		local_sim.add_entity(3, Vector3(2.5, 0, 0), 0.0)
		local_sim.register_combatant(3, 100.0, &"test_family", 0, 1.0, &"enemy")
		local_sim._apply_status(1, &"burn", "hit", -1, "")
		for i in range(6):
			local_sim.tick([], 1.0 / 30.0)
		results.append(local_sim._status_instances.duplicate(true))
	assert_eq(results[0], results[1], "identical Burn spread chains must produce identical remaining-duration state")


## "Spread never refreshes an already-Burning target" is already-locked spec
## (contact-model rule 2, enforced by _advance_contact_spread's "recipient already
## has an active status" check) -- this pins it with a case the OTHER existing tests
## don't reach: a recipient that has a status from an UNRELATED application (not
## this pair's own prior transmission, so the pair-marker isn't what's blocking it)
## and is still within ITS OWN grace, so it isn't yet counted as an eligible source
## either -- isolating the has()-check itself, not the pair-marker or the
## both-eligible skip.
func test_spread_does_not_apply_to_a_target_that_already_has_any_status() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()  # grace for 1
	sim._apply_status(2, &"burn", "hit", 99, "")  # 2 gets Burn from an unrelated source, same tick 1 becomes eligible
	var events := _tick_noop()
	assert_eq(_events_of_kind(events, "status_applied").filter(func(e): return e.payload.get("application_source") == "spread").size(), 0, "a target that already has any status must never receive a spread application")


func test_spread_applied_status_has_no_source_weapon_id() -> void:
	_register(1, Vector3.ZERO, 1.0, &"enemy")
	_register(2, Vector3(1, 0, 0), 1.0, &"enemy")
	_ignite(1)
	_tick_noop()
	var events := _tick_noop()
	var applied := _events_of_kind(events, "status_applied")
	assert_eq(applied.size(), 1)
	assert_eq(applied[0].payload.get("application_source"), "spread")
	assert_null(applied[0].payload.get("source_weapon_id"), "source_weapon_id must be absent for spread applications")
