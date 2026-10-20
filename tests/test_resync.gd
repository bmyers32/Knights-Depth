extends GutTest
## EMERGENCY RESYNCHRONIZATION (M2 Slice 2, ruled 2026-10-20), in a bare SimWorld.
##
## Incapacitated is zero health. The first incapacitation on a floor commits that floor's one free
## revival; after the delay the Envoy returns IN PLACE at FULL health with the shared post-hit
## window. With the revival spent and nobody left to carry the expedition, the sim reports
## recovery_exhausted -- a party fact the Expedition turns into Emergency Recall.
##
## Every value is the SHIPPED one from ContentDB, never a literal (BRAIN, the combo-cadence escape).

const DT := 1.0 / 30.0
const PLAYER := 0
const ENEMY := 1
const PAD := 0
const KEY := 0
const ROOM := Rect2(-20.0, -10.0, 40.0, 20.0)
const SPIKES := Rect2(-2.0, -2.0, 4.0, 4.0)
const LETHAL := 1000.0
const BITE := &"test_resync_bite"
const ALWAYS_SAFE := 1
const ALWAYS_ACTIVE := 10000

var sim: SimWorld


func _envoy() -> EnvoyStats:
	return ContentDB.get_resource(&"envoy", &"default")


func _delay() -> int:
	return _envoy().resync_delay_ticks


func _build(pad_damage: float = LETHAL, with_pad: bool = true) -> void:
	sim = SimWorld.new()
	sim.seed_combat_rng(1)
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	if with_pad:
		sim.register_spike_pad(PAD, SPIKES, ALWAYS_SAFE, ALWAYS_ACTIVE, 0, pad_damage, &"force")
	var stats: EnvoyStats = _envoy()
	sim.add_entity(PLAYER, Vector3.ZERO, stats.move_speed, Vector3(0, 0, 1), stats.combat_radius)
	sim.register_combatant(PLAYER, stats.max_health, &"envoy", stats.iframe_ticks_on_hit, stats.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.register_resync(PLAYER, stats.resyncs_per_floor, stats.resync_health_fraction, stats.resync_delay_ticks)
	var burn: BurnStats = ContentDB.get_resource(&"status", &"burn")
	sim.register_status(burn.status_id, burn.damage_per_tick, burn.tick_interval_ticks, burn.duration_ticks)


func _run(ticks: int, commands: Array[Command] = []) -> Array[Event]:
	var events: Array[Event] = []
	for i in ticks:
		var batch: Array[Command] = []
		for command in commands:
			batch.append(Command.new(sim.tick_count, command.actor_id, command.kind, command.params))
		events.append_array(sim.tick(batch, DT))
	return events


## Bounded on purpose (BRAIN): the predicate under test is the thing that might never come true.
func _run_until(kind: String, limit: int) -> Array[Event]:
	var events: Array[Event] = []
	for i in limit:
		var batch: Array[Event] = sim.tick([] as Array[Command], DT)
		events.append_array(batch)
		if not _of(batch, kind).is_empty():
			return events
	return events


func _of(events: Array[Event], kind: String) -> Array[Event]:
	return events.filter(func(e: Event) -> bool: return e.kind == kind)


func _kinds_for_player(events: Array[Event]) -> Array[String]:
	var kinds: Array[String] = []
	for event in events:
		var who: int = int(event.payload.get("actor_id", event.payload.get("target_id", -99)))
		if who == PLAYER:
			kinds.append(event.kind)
	return kinds


# --- CONTENT -------------------------------------------------------------------------------

func test_the_shipped_envoy_carries_the_ruled_revival() -> void:
	assert_eq(_envoy().resyncs_per_floor, 1, "one free revival per floor")
	assert_eq(_envoy().resync_health_fraction, 1.0, "FULL health (human decision 2026-10-20)")
	assert_eq(_envoy().resync_delay_ticks, 45, "provisional 1.5 s")


# --- THE FIRST FALL ------------------------------------------------------------------------

func test_a_lethal_spike_commits_the_revival_in_one_ordered_tick() -> void:
	_build()
	var events: Array[Event] = _run_until("died", 10)
	var fatal: Event = _of(events, "died")[0]
	var that_tick: Array[Event] = events.filter(func(e: Event) -> bool: return e.tick == fatal.tick)
	assert_eq(_kinds_for_player(that_tick), ["hit", "died", "resync_begun"] as Array[String])
	var begun: Event = _of(events, "resync_begun")[0]
	assert_eq(int(begun.payload["resync_tick"]), fatal.tick + _delay())
	assert_false(sim.is_active(PLAYER))
	assert_true(sim.resync_pending(PLAYER))
	assert_lte(sim.health_of(PLAYER), 0.0, "incapacitated IS zero health (overkill is not clamped)")
	assert_true(_of(events, "recovery_exhausted").is_empty(), "the first fall is recoverable")


func test_the_revival_lands_on_the_promised_tick_in_place_at_full_health() -> void:
	_build()
	var fell: Array[Event] = _run_until("died", 10)
	var fatal_tick: int = _of(fell, "died")[0].tick
	var where: Vector3 = sim.entities[PLAYER]
	var events: Array[Event] = _run_until("resynchronized", _delay() + 5)
	var back: Event = _of(events, "resynchronized")[0]
	assert_eq(back.tick, fatal_tick + _delay())
	assert_eq(back.payload, {"actor_id": PLAYER, "health": _envoy().max_health, "max_health": _envoy().max_health})
	assert_eq(sim.health_of(PLAYER), 30.0, "30/30, not 15/30")
	assert_eq(sim.entities[PLAYER], where, "in place")
	assert_false(sim.resync_pending(PLAYER))
	assert_eq(sim.resync_ticks_remaining(PLAYER), 0)


## The revived Envoy is standing on an always-active lethal pad, and the shared window keeps it alive
## for exactly that window -- time to step off (5 units at 4 u/s is ~38 ticks of 90).
func test_the_shared_window_covers_the_revival_on_an_active_pad() -> void:
	_build()
	_run_until("died", 10)
	var events: Array[Event] = _run_until("resynchronized", _delay() + 5)
	var revived_at: int = _of(events, "resynchronized")[0].tick
	assert_eq(_of(events, "attack_absorbed").back().tick, revived_at, "the revival tick itself is covered")
	var after: Array[Event] = _run(_envoy().iframe_ticks_on_hit + 5)
	var landed: Array[Event] = _of(after, "hit")
	assert_false(landed.is_empty(), "the pad does land again once the window is over")
	assert_eq(landed[0].tick, revived_at + _envoy().iframe_ticks_on_hit, "and not one tick sooner")


func test_a_downed_envoy_is_untargetable_and_cannot_act() -> void:
	_build()
	_run_until("died", 10)
	var where: Vector3 = sim.entities[PLAYER]
	sim.add_entity(ENEMY, Vector3(1.0, 0.0, 0.0), 0.0, Vector3(-1, 0, 0), 0.5)
	sim.register_combatant(ENEMY, 999.0, &"test_target", 0, 0.5)
	sim.register_weapon(BITE, 5.0, &"force", 4.0, 60.0, 0.0, 0)
	sim.set_equipped_weapon(ENEMY, BITE)
	var commands: Array[Command] = [
		Command.new(0, PLAYER, "move", {"direction": Vector3(1, 0, 0)}),
		Command.new(0, ENEMY, "attack", {"aim": Vector3(-1, 0, 0)}),
	]
	var events: Array[Event] = _run(_delay() - 2, commands)
	assert_eq(sim.entities[PLAYER], where, "a downed body is not steered")
	assert_true(_of(events, "hit").filter(func(e: Event) -> bool: return int(e.payload["target_id"]) == PLAYER).is_empty(),
		"nothing lands on a downed Envoy -- not the pad, not the bite")
	assert_false(sim.is_active(PLAYER), "sanity: still down")


# --- THE SECOND FALL -----------------------------------------------------------------------

func test_a_second_fall_on_the_same_floor_exhausts_recovery() -> void:
	_build()
	_run_until("died", 10)
	_run_until("resynchronized", _delay() + 5)
	var events: Array[Event] = _run_until("died", _envoy().iframe_ticks_on_hit + 5)
	assert_eq(_of(events, "died").size(), 1, "sanity: the pad killed again after the window")
	assert_true(_of(events, "resync_begun").is_empty(), "no second revival on this floor")
	var exhausted: Array[Event] = _of(events, "recovery_exhausted")
	assert_eq(exhausted.size(), 1)
	assert_eq(exhausted[0].tick, _of(events, "died")[0].tick, "reported on the fatal tick")
	var later: Array[Event] = _run(_delay() * 3)
	assert_true(_of(later, "resynchronized").is_empty(), "and nobody comes back")
	assert_lte(sim.health_of(PLAYER), 0.0)


# --- SCOPE: ONE PER FLOOR, NEVER BANKED -----------------------------------------------------

func test_a_floor_transition_brings_a_fresh_revival_and_nothing_banks() -> void:
	_build()
	_run_until("died", 10)
	_run_until("resynchronized", _delay() + 5)
	var rects: Array[Rect2] = [ROOM]
	for i in 3:
		sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	assert_eq(sim._resyncs_used_on_floor.get(PLAYER, 0), 0, "a new floor has nothing spent")
	sim.register_patches(rects)
	sim.register_spike_pad(PAD, SPIKES, ALWAYS_SAFE, ALWAYS_ACTIVE, 0, LETHAL, &"force")
	var first: Array[Event] = _run_until("died", _envoy().iframe_ticks_on_hit + 5)
	assert_eq(_of(first, "resync_begun").size(), 1, "the new floor's revival")
	_run_until("resynchronized", _delay() + 5)
	var second: Array[Event] = _run_until("died", _envoy().iframe_ticks_on_hit + 5)
	assert_eq(_of(second, "recovery_exhausted").size(), 1, "three unused floors banked nothing")


func test_ticks_alone_never_refresh_a_spent_revival() -> void:
	_build(LETHAL, false)
	sim.debug_override_health(PLAYER, 0.0)
	sim._on_incapacitated(PLAYER)
	_run(_delay() + 1)
	_run(600)
	assert_eq(sim._resyncs_used_on_floor[PLAYER], 1)


# --- BURN ----------------------------------------------------------------------------------

func test_a_burn_death_resynchronizes_clean() -> void:
	_build(LETHAL, false)
	sim.debug_override_health(PLAYER, 0.01)
	sim._apply_status(PLAYER, &"burn", "test", -1, "")
	var events: Array[Event] = _run_until("died", 200)
	assert_eq(_kinds_for_player(events.filter(func(e: Event) -> bool: return e.kind == "died" or e.kind == "resync_begun")),
		["died", "resync_begun"] as Array[String])
	_run_until("resynchronized", _delay() + 5)
	assert_eq(sim.health_of(PLAYER), 30.0)
	assert_false(sim._status_instances.has(PLAYER))
	assert_true(_of(_run(300), "status_resolved").is_empty(), "no Burn tick after the revival")


## A HIT death leaves a live status in its slot; the revival must not inherit it, because Burn
## ticks ignore the post-hit window and could kill again inside it.
func test_a_hit_death_while_burning_clears_the_burn() -> void:
	_build(LETHAL, false)
	sim._apply_status(PLAYER, &"burn", "test", -1, "")
	_run(2)
	sim.register_spike_pad(PAD, SPIKES, ALWAYS_SAFE, ALWAYS_ACTIVE, 0, LETHAL, &"force")
	var events: Array[Event] = _run_until("died", 10)
	var cleared: Array[Event] = _of(events, "status_cleared")
	assert_eq(cleared.size(), 1)
	assert_eq(int(cleared[0].payload["actor_id"]), PLAYER)
	assert_eq(String(cleared[0].payload["status_id"]), "burn")
	assert_eq(cleared[0].payload["reason"], "incapacitated")
	assert_false(sim._status_instances.has(PLAYER))
	_run_until("resynchronized", _delay() + 5)
	assert_true(_of(_run(30), "status_resolved").is_empty())


# --- KEYS AND FLOOR STATE ------------------------------------------------------------------

func test_a_carried_key_drops_once_and_stays_loose_after_the_revival() -> void:
	_build(LETHAL, false)
	var stats: EnvoyStats = _envoy()
	sim.register_carrier(PLAYER, stats.pickup_reach, stats.pickup_cone_half_angle_degrees, stats.pickup_underfoot_radius)
	sim.register_carriable(KEY, Vector3(0.0, 0.0, 1.5))
	sim.tick([Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(0, 0, 1), "phase": "pressed"})] as Array[Command], DT)
	assert_eq(sim.carried_by(PLAYER), KEY, "sanity: carrying")
	var at: Vector3 = sim.entities[PLAYER]
	sim.register_spike_pad(PAD, SPIKES, ALWAYS_SAFE, ALWAYS_ACTIVE, 0, LETHAL, &"force")
	var events: Array[Event] = _run_until("died", 10)
	var dropped: Array[Event] = _of(events, "carriable_dropped")
	assert_eq(dropped.size(), 1)
	assert_eq(dropped[0].payload["reason"], "death")
	assert_eq(_kinds_for_player(events.filter(func(e: Event) -> bool: return e.tick == dropped[0].tick)).back(), "carriable_dropped",
		"the key leaves last, after the revival is committed")
	_run_until("resynchronized", _delay() + 5)
	assert_eq(sim.carried_by(PLAYER), -1, "a revival does not hand the key back")
	assert_eq(sim._carriables.size(), 1, "no duplicate key")
	assert_eq(sim._carriables[KEY]["position"], at, "lying where it fell")


# --- WHO CAN RESYNCHRONIZE -----------------------------------------------------------------

func test_an_actor_without_a_profile_dies_exactly_as_before() -> void:
	_build(LETHAL, false)
	sim.add_entity(ENEMY, Vector3(5.0, 0.0, 0.0), 0.0, Vector3(-1, 0, 0), 0.5)
	sim.register_combatant(ENEMY, 1.0, &"test_target", 0, 0.5)
	var lethal: Dictionary = {"damage": LETHAL, "damage_type": "force", "knockback_distance": 0.0}
	var events: Array[Event] = sim._resolve_hit_on_target(PLAYER, ENEMY, lethal, Vector3(1, 0, 0), "test")
	var kinds: Array = events.map(func(e: Event) -> String: return e.kind)
	assert_eq(kinds, ["hit", "died"], "no revival vocabulary on an enemy death")
	_run(_delay() * 2)
	assert_lte(sim.health_of(ENEMY), 0.0, "the dead stay dead")


## THE PARTY PREDICATE. Recovery is exhausted only when no party member is in play or on the way
## back -- solo, "this Envoy"; with a second Envoy standing, one Envoy down for good is not the end.
func test_recovery_is_exhausted_only_when_the_whole_party_is() -> void:
	_build(LETHAL, false)
	const OTHER := 2
	sim.add_entity(OTHER, Vector3(8.0, 0.0, 0.0), 4.0, Vector3(0, 0, 1), 0.45)
	sim.register_combatant(OTHER, 30.0, &"envoy", 90, 0.45, &"player")
	sim.mark_run_persistent(OTHER)
	sim.register_resync(OTHER, 1, 1.0, _delay())
	sim._resyncs_used_on_floor[PLAYER] = 1
	sim._resyncs_used_on_floor[OTHER] = 1
	sim.debug_override_health(PLAYER, 0.0)
	assert_eq(sim._on_incapacitated(PLAYER).map(func(e: Event) -> String: return e.kind), [], "a teammate is still standing")
	sim.debug_override_health(OTHER, 0.0)
	assert_eq(sim._on_incapacitated(OTHER).map(func(e: Event) -> String: return e.kind), ["recovery_exhausted"], "now nobody is")


# --- DETERMINISM ---------------------------------------------------------------------------

func _scripted_log() -> Array:
	_build()
	var log: Array = []
	for event in _run(_delay() + _envoy().iframe_ticks_on_hit + 20):
		log.append([event.tick, event.kind, event.payload])
	return log


func test_the_same_run_replays_the_same_event_log() -> void:
	var first: Array = _scripted_log()
	var second: Array = _scripted_log()
	assert_true(first.any(func(row: Array) -> bool: return row[1] == "resynchronized"), "sanity: the log contains a revival")
	assert_true(first.any(func(row: Array) -> bool: return row[1] == "recovery_exhausted"), "and a Recall-worthy second fall")
	assert_eq(first, second)


## Same tick, environment and enemy both reaching for the Envoy: hazards resolve first, the body is
## already down when the bite arrives, and exactly one death -- one charge -- is recorded.
func test_a_hazard_and_a_blow_on_one_tick_make_one_fall() -> void:
	_build()
	sim.add_entity(ENEMY, Vector3(1.0, 0.0, 0.0), 0.0, Vector3(-1, 0, 0), 0.5)
	sim.register_combatant(ENEMY, 999.0, &"test_target", 0, 0.5)
	sim.register_weapon(BITE, LETHAL, &"force", 4.0, 60.0, 0.0, 0)
	sim.set_equipped_weapon(ENEMY, BITE)
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, ENEMY, "attack", {"aim": Vector3(-1, 0, 0)})] as Array[Command], DT)
	if _of(events, "died").is_empty():
		events = sim.tick([Command.new(sim.tick_count, ENEMY, "attack", {"aim": Vector3(-1, 0, 0)})] as Array[Command], DT)
	assert_eq(_of(events, "died").size(), 1)
	assert_eq(_of(events, "resync_begun").size(), 1)
	assert_eq(sim._resyncs_used_on_floor[PLAYER], 1, "one fall, one charge")
