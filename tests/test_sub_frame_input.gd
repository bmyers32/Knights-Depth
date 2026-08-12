extends GutTest
## STEP 4 — sub-frame press/release. Locks the phased-input contract that envoy.gd's
## edge forwarding depends on.
##
## RECON FINDING (real defect, not a harness artifact): build_commands runs once per
## PHYSICS tick (30 Hz). In a physics context both Input.is_action_just_pressed and
## is_action_just_released report true when a click opened AND closed since the
## previous tick — any click under ~33 ms. envoy.gd's former if/elif chain forwarded
## only "pressed" and discarded the release, stranding _melee_hold in "charging"
## forever: the following tick carries no edge and no held state, so nothing ever
## closed it, and every later press hit the already-charging silent no-op branch.
##
## envoy.gd now forwards BOTH edges. These tests pin the sim-side behavior that fix
## relies on, and pin the hazard itself so a future refactor cannot quietly restore it.
## Deliberately narrow: no input-buffer redesign, no command history, no render/sim
## interpolation, no prediction.

const ATTACKER_ID := 0
const TARGET_ID := 1
const DT := 1.0 / 30.0
const AIM := Vector3(0, 0, -1)

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.seed_combat_rng(0)
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, envoy.move_speed)
	sim.register_combatant(ATTACKER_ID, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	ContentRegistrar.register_enemy_body(sim, TARGET_ID, &"fang", Vector3(0, 0, -1.6))
	ContentRegistrar.register_weapon(sim, &"sword_burn_A")
	sim.set_equipped_weapon(ATTACKER_ID, &"sword_burn_A")
	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)
	var burn: BurnStats = ContentDB.get_resource(&"status", &"burn")
	sim.register_status(burn.status_id, burn.damage_per_tick, burn.tick_interval_ticks, burn.duration_ticks)
	sim.set_status_priority((ContentDB.get_resource(&"status", &"priority_table") as StatusPriorityTable).priority)
	var tuning: FlinchTuning = ContentDB.get_resource(&"combat", &"flinch_tuning")
	sim.set_flinch_tuning(tuning.pressure_window_ticks, tuning.flinch_recovery_ticks)


func _phase(phase: String) -> Command:
	return Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": AIM, "phase": phase})


func _of(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


func _drain(ticks: int = 20) -> Array[Event]:
	var all: Array[Event] = []
	for _i in range(ticks):
		all.append_array(sim.tick([], DT))
	return all


## The real client case, post-fix: both edges arrive in ONE tick, in order.
func test_both_edges_in_one_tick_resolve_as_exactly_one_tap() -> void:
	var events: Array[Event] = sim.tick([_phase("pressed"), _phase("released")], DT)
	events.append_array(_drain())
	assert_eq(_of(events, "melee_swing").size(), 1, "a sub-tick click is one clean tap")
	assert_eq(_of(events, "melee_swing")[0].payload.attack_profile_id, "1")
	assert_eq(_of(events, "hit").size(), 1)
	assert_false(sim._melee_hold.has(ATTACKER_ID), "and it must leave no open hold behind")


func test_sub_tick_clicks_advance_the_combo_normally() -> void:
	var profiles: Array = []
	for _i in range(3):
		# The swing resolves at hit_active_ticks, NOT on the tick carrying the edges,
		# so the drain has to be part of the collection window.
		var events: Array[Event] = sim.tick([_phase("pressed"), _phase("released")], DT)
		events.append_array(_drain(12))
		for event in events:
			if event.kind == "melee_swing":
				profiles.append(event.payload.attack_profile_id)
		CombatTestHelpers.settle(sim, ATTACKER_ID, AIM, DT)
	assert_eq(profiles, ["1", "2", "3"], "sub-tick clicks are ordinary taps, not a special case")


## THE HAZARD, pinned: a "pressed" whose release is never forwarded strands the hold
## and kills every later press. This is what the old if/elif chain produced. If a
## refactor ever drops an edge again, this test explains exactly what breaks.
func test_a_lost_release_edge_strands_the_hold_and_deadens_later_presses() -> void:
	sim.tick([_phase("pressed")], DT)  # release deliberately never sent
	_drain(30)
	assert_eq(sim._melee_hold.get(ATTACKER_ID, {}).get("state", ""), "charging",
		"an unreleased hold stays open indefinitely -- nothing times it out")
	var later: Array[Event] = sim.tick([_phase("pressed")], DT)
	later.append_array(_drain())
	assert_eq(_of(later, "melee_swing").size(), 0,
		"and every later press is silently swallowed by the already-charging branch")


func test_holding_across_ticks_still_charges_normally() -> void:
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_burn_A")
	sim.tick([_phase("pressed")], DT)
	var charge_ready: int = 0
	for _i in range(sword.charge_threshold_ticks + 2):
		charge_ready += _of(sim.tick([_phase("held")], DT), "charge_ready").size()
	assert_eq(charge_ready, 1, "the multi-tick hold path is untouched by the edge fix")
	var events: Array[Event] = sim.tick([_phase("released")], DT)
	events.append_array(_drain(30))
	assert_eq(_of(events, "melee_swing")[0].payload.attack_profile_id, "charge")


## Frame alignment must not change the OUTCOME, only its timing — otherwise identical
## player intent would resolve differently depending on where ticks happened to fall,
## which is a determinism defect even when nothing strands (and a networking-inherited
## problem class: input sampling vs tick boundaries, M3).
func test_outcome_is_independent_of_which_tick_the_edges_land_on() -> void:
	var same_tick: Array[Event] = sim.tick([_phase("pressed"), _phase("released")], DT)
	same_tick.append_array(_drain())
	var a: Array = _of(same_tick, "melee_swing").map(func(e): return e.payload.attack_profile_id)

	before_each()  # fresh sim
	var split: Array[Event] = sim.tick([_phase("pressed")], DT)
	split.append_array(sim.tick([_phase("released")], DT))
	split.append_array(_drain())
	var b: Array = _of(split, "melee_swing").map(func(e): return e.payload.attack_profile_id)

	assert_eq(a, b, "a sub-tick click and a one-tick-apart click must resolve identically")
