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
