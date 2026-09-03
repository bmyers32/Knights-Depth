extends GutTest
## ENVIRONMENTAL DAMAGE AND THE TIMED SPIKE PAD (ruled 2026-09-03).
##
## THE SEAM: a damage source is either an ACTOR, which has an id and can be parried and can earn
## aggro, or the ENVIRONMENT, which has neither. BOTH travel the SAME authoritative pipeline --
## a hazard is not an attacker, but it is also not a second combat system.
##
## THE SHIELD RULING, which overturned my own recommendation: a shield DOES protect against
## spikes. It drains, it can break, and the existing break consequence follows. Shielding is
## resource expenditure, not hazard immunity -- so a player may time the spikes, evade them, or
## deliberately spend shield to push through.
##
## NO PHANTOM ATTACKER, no environment faction, no trap AI entity.

const DT := 1.0 / 30.0
const PLAYER := 0
const ENEMY := 1
const PAD := 0
const ROOM := Rect2(-20.0, -10.0, 40.0, 20.0)
const SPIKES := Rect2(-2.0, -2.0, 4.0, 4.0)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	# 10 safe, 10 active, and no i-frames by default so a test measures the hazard rather than
	# the defensive window -- the i-frame law gets its own test below, deliberately.
	sim.register_spike_pad(PAD, SPIKES, 10, 10, 0, 12.0, &"force")
	sim.add_entity(PLAYER, Vector3(0.0, 0.0, 0.0), 6.0, Vector3(0, 0, 1), 0.45)
	sim.register_combatant(PLAYER, 500.0, &"envoy", 0, 0.45, &"player")


func _run(ticks: int) -> Array[Event]:
	var events: Array[Event] = []
	for i in ticks:
		events.append_array(sim.tick([] as Array[Command], DT))
	return events


## Advances to the first tick of an ACTIVE phase, so a test starts from a known place.
func _run_to_active() -> void:
	for i in 60:
		if sim.debug_describe_spike_pad(PAD)["active"]:
			return
		sim.tick([] as Array[Command], DT)
	assert_true(false, "the pad never became active -- the fixture is not measuring a hazard")


func _kinds(events: Array[Event]) -> Array:
	var kinds: Array = []
	for event in events:
		kinds.append(event.kind)
	return kinds


# --- 1: THE CYCLE IS AUTHORITATIVE AND DETERMINISTIC -------------------------------------------

func test_the_pad_cycles_between_safe_and_active() -> void:
	var seen_safe: bool = false
	var seen_active: bool = false
	for i in 40:
		if sim.debug_describe_spike_pad(PAD)["active"]:
			seen_active = true
		else:
			seen_safe = true
		sim.tick([] as Array[Command], DT)
	assert_true(seen_safe and seen_active, "a timed pad must actually alternate")


## PHASE IS A PURE FUNCTION OF THE TICK. Two sims at the same tick agree without exchanging
## anything, which is what makes this replayable for M3.
func test_the_phase_is_a_pure_function_of_the_tick() -> void:
	var other := SimWorld.new()
	other.set_damage_matrix({}, 1.5, 0.5)
	other.register_spike_pad(PAD, SPIKES, 10, 10, 0, 12.0, &"force")
	for i in 45:
		assert_eq(sim.debug_describe_spike_pad(PAD)["active"], other.debug_describe_spike_pad(PAD)["active"],
			"two floors at tick %d must agree about the phase" % i)
		sim.tick([] as Array[Command], DT)
		other.tick([] as Array[Command], DT)


## Offsets let neighbouring pads run out of step with no per-pad clock.
func test_a_phase_offset_shifts_a_pad_without_changing_its_cycle() -> void:
	sim.register_spike_pad(1, SPIKES, 10, 10, 10, 12.0, &"force")
	var differed: bool = false
	for i in 20:
		if sim.debug_describe_spike_pad(PAD)["active"] != sim.debug_describe_spike_pad(1)["active"]:
			differed = true
		sim.tick([] as Array[Command], DT)
	assert_true(differed, "an offset pad must not march in lockstep with its neighbour")


func test_the_phase_change_is_announced_once_not_every_tick() -> void:
	var announcements: int = 0
	for event in _run(20):
		if event.kind == "hazard_phase_changed":
			announcements += 1
	assert_lt(announcements, 4, "a 20-tick cycle announces its edges, not its every tick")
	assert_gt(announcements, 0, "but it does announce them")


# --- 2: THE DAMAGE, AND WHERE IT COMES FROM ----------------------------------------------------

func test_standing_on_active_spikes_costs_health() -> void:
	_run_to_active()
	var before: float = sim._health[PLAYER]
	_run(1)
	assert_lt(sim._health[PLAYER], before, "active spikes underfoot must hurt")


func test_standing_clear_of_the_pad_costs_nothing() -> void:
	sim.entities[PLAYER] = Vector3(10.0, 0.0, 0.0)
	var before: float = sim._health[PLAYER]
	_run(60)
	assert_eq(sim._health[PLAYER], before, "a hazard only reaches its own footprint")


func test_a_dormant_pad_costs_nothing() -> void:
	# Long safe phase, so the whole run happens while it is down.
	sim.register_spike_pad(PAD, SPIKES, 10000, 10, 0, 12.0, &"force")
	var before: float = sim._health[PLAYER]
	_run(60)
	assert_eq(sim._health[PLAYER], before, "spikes that are down are just floor")


## THE PAYLOAD IS TRUTHFUL: no fabricated actor.
func test_the_event_names_the_environment_and_invents_no_attacker() -> void:
	_run_to_active()
	var found: bool = false
	for event in _run(1):
		if event.kind != "hit":
			continue
		found = true
		assert_eq(event.payload.get("source", &""), SimWorld.SOURCE_ENVIRONMENT,
			"the source must say environment")
		assert_eq(int(event.payload.get("attacker_id", 0)), -1,
			"and the attacker must be honestly absent, never a phantom id")
	assert_true(found, "sanity: a hit must have occurred for this to mean anything")


## ACTOR-SOURCED DAMAGE IS UNCHANGED, byte for byte. The `source` field is stamped CONDITIONALLY
## -- the established attack_profile_id precedent -- so no recorded baseline moves. The AI canary
## caught this immediately when the field was unconditional, which is exactly its job.
func test_actor_sourced_damage_carries_no_source_field_at_all() -> void:
	sim.add_entity(ENEMY, Vector3(8.0, 0.0, 0.0), 0.0)
	sim.register_combatant(ENEMY, 100.0, &"fang", 0, 0.5, &"enemy")
	sim.register_gun(&"wand", 10.0, &"force", 40.0, 600, 0.2, 0.0, 1)
	sim.set_equipped_weapon(PLAYER, &"wand")
	sim.entities[PLAYER] = Vector3(-15.0, 0.0, 0.0)
	var events: Array[Event] = sim.tick(
		[Command.new(sim.tick_count, PLAYER, "attack", {"aim": Vector3(1, 0, 0)})] as Array[Command], DT)
	events.append_array(_run(90))
	var checked: bool = false
	for event in events:
		if event.kind == "hit":
			checked = true
			assert_false(event.payload.has("source"), "an ordinary hit's payload must not change shape")
	assert_true(checked, "sanity: the shot landed")


# --- 3: THE SHIELD (the human ruling) -----------------------------------------------------------

func _armed_with_a_shield(meter: float) -> void:
	sim.register_shield(PLAYER, meter, 6.0, 30, 2.0, 0)
	sim.tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})] as Array[Command], DT)


## SHIELD FIRST, HEALTH SECOND. Overturning my own recommendation, on the human's ruling.
func test_a_held_shield_absorbs_spike_damage_before_health() -> void:
	_armed_with_a_shield(500.0)
	_run_to_active()
	var health_before: float = sim._health[PLAYER]
	var meter_before: float = sim._shield_meter[PLAYER]
	for i in 3:
		sim.tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})] as Array[Command], DT)
	assert_eq(sim._health[PLAYER], health_before, "health is untouched while the shield holds")
	assert_lt(sim._shield_meter[PLAYER], meter_before, "and the meter pays instead")


## SHIELDING IS EXPENDITURE, NOT IMMUNITY: repeated ticks break it, and the ordinary break
## consequence follows -- no spike-specific meter, no spike-specific invulnerability.
func test_repeated_spike_ticks_break_the_shield_through_the_ordinary_consequence() -> void:
	_armed_with_a_shield(20.0)
	_run_to_active()
	var broke: bool = false
	for i in 40:
		for event in sim.tick([Command.new(sim.tick_count, PLAYER, "block", {"held": true})] as Array[Command], DT):
			if event.kind == "shield_broken":
				broke = true
		if broke:
			break
	assert_true(broke, "a shield spent against a hazard eventually breaks, like any other")
	# Checked AT the break, not after it: the ordinary recovery delay would have returned the
	# shield to ready by the end of the window, and asserting there would have measured recovery
	# rather than breakage.
	assert_eq(String(sim._shield_state.get(PLAYER, "")), "broken", "and lands in the ordinary broken state")


# --- 4: I-FRAMES -------------------------------------------------------------------------------

## ORDINARY I-FRAMES GATE REPEATS. The cadence of hazard damage falls out of the defensive law
## already in place rather than from a second, hazard-specific interval -- two timing systems
## saying the same thing would eventually disagree.
func test_iframes_prevent_every_active_tick_from_landing() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var rects: Array[Rect2] = [ROOM]
	sim.load_floor(WalkableBounds.new(rects), Vector3.ZERO)
	sim.register_patches(rects)
	sim.register_spike_pad(PAD, SPIKES, 1, 10000, 0, 12.0, &"force")  # effectively always active
	sim.add_entity(PLAYER, Vector3(0.0, 0.0, 0.0), 6.0, Vector3(0, 0, 1), 0.45)
	sim.register_combatant(PLAYER, 5000.0, &"envoy", 20, 0.45, &"player")  # 20 i-frame ticks

	var hits: int = 0
	var absorbed: int = 0
	for event in _run(60):
		if event.kind == "hit":
			hits += 1
		if event.kind == "attack_absorbed":
			absorbed += 1
	assert_lt(hits, 10, "60 active ticks must not mean 60 accepted hits")
	assert_gt(hits, 0, "but standing in spikes must still hurt")
	assert_gt(absorbed, 0, "and the intervening ticks are absorbed by the ordinary i-frame law")


# --- 5: AGGRO -----------------------------------------------------------------------------------

## "The floor hurt me, therefore attack the player" is not an inference the sim gets to make.
func test_environmental_damage_acquires_no_aggro() -> void:
	sim.add_entity(ENEMY, Vector3(0.0, 0.0, 0.0), 4.0, Vector3(0, 0, 1), 0.5)
	sim.register_combatant(ENEMY, 500.0, &"fang", 0, 0.5, &"enemy")
	sim.register_weapon(&"bite", 5.0, &"force", 2.0, 90.0, 0.0, 9999)
	sim.register_ai(ENEMY, CombatTestHelpers.single_action_repertoire(&"bite", 2.0, 30),
		Vector3(0.0, 0.0, 0.0), 2.2, 1.9, 0.5, 60.0, 0, 0, 0.0, 0.0, 0, 0.0, 0, 0, 0, 45)
	sim.entities[PLAYER] = Vector3(18.0, 0.0, 0.0)  # far away, outside detection
	_run_to_active()
	_run(30)
	assert_lt(sim._health[ENEMY], 500.0, "sanity: the hazard hurt the enemy")
	assert_ne(String(sim._ai_state.get(ENEMY, "")), "active",
		"being hurt by the floor must not make an enemy come looking for the player")
