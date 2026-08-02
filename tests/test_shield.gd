extends GutTest
## Shield state machine (READY/HELD/BROKEN) and i-frame invulnerability window
## (Phase D step 5, HANDOFF) — GAME-RULES §3: hold-to-block with its own break meter
## that regenerates, knockback on break; i-frames on hit, durations in sim ticks.
## Locked invariants from this session's design lock (see HANDOFF/BRAIN):
## i-frames start ONLY on an unblocked, non-lethal hit; blocked hits and shield
## breaks never arm the timer; absorbed swings never refresh it; READY regenerates,
## HELD freezes, BROKEN withholds regen until break_recovery_delay_ticks elapse then
## flips to READY the instant meter > 0; BROKEN rejects held block commands by name;
## re-entering HELD after a break requires a fresh rising edge (release then press),
## never just continuing to hold through the break.

var sim: SimWorld

const ATTACKER_ID := 0
const TARGET_ID := 1
const WEAPON_ID := &"sword_A"
const TARGET_FAMILY := &"test_target"  # absent from the matrix -> multiplier always 1.0
const TARGET_POSITION := Vector3(0, 0, -1)  # directly ahead of the attacker's default facing


func before_each() -> void:
	sim = SimWorld.new()
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
	sim.register_weapon(WEAPON_ID, 10.0, &"force", 2.0, 60.0, 1.0)
	sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
	sim.set_damage_matrix({}, 1.5, 0.5)


func _register_target(max_health: float = 100.0, iframe_ticks: int = 0) -> void:
	sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
	sim.register_combatant(TARGET_ID, max_health, TARGET_FAMILY, iframe_ticks)


func _register_shield(meter_max: float = 20.0, regen_per_tick: float = 1.0, break_recovery_delay_ticks: int = 3, knockback_distance: float = 2.0) -> void:
	sim.register_shield(TARGET_ID, meter_max, regen_per_tick, break_recovery_delay_ticks, knockback_distance)


func _tick_block(held: bool) -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, TARGET_ID, "block", {"held": held})], 1.0 / 30.0)


func _tick_attack() -> Array[Event]:
	return sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)


func _tick_noop() -> Array[Event]:
	return sim.tick([], 1.0 / 30.0)


func _events_of_kind(events: Array[Event], kind: String) -> Array:
	return events.filter(func(e): return e.kind == kind)


# --- i-frames ---

func test_unblocked_nonlethal_hit_starts_iframe_timer() -> void:
	_register_target(100.0, 5)
	_tick_attack()
	assert_eq(sim._iframe_ticks_remaining.get(TARGET_ID, 0), 5)


func test_absorbed_second_hit_deals_no_damage_and_emits_attack_absorbed() -> void:
	_register_target(100.0, 5)
	_tick_attack()
	var events := _tick_attack()
	var absorbed := _events_of_kind(events, "attack_absorbed")
	assert_eq(absorbed.size(), 1)
	assert_eq(absorbed[0].payload.get("reason"), "iframes")
	assert_eq(_events_of_kind(events, "hit").size(), 0)
	assert_almost_eq(sim._health[TARGET_ID], 90.0, 0.001, "the absorbed swing must deal zero damage")


func test_iframe_timer_counts_down_and_expires() -> void:
	_register_target(100.0, 2)
	_tick_attack()  # arms the timer at 2, health 90
	assert_eq(sim._iframe_ticks_remaining[TARGET_ID], 2)
	_tick_noop()  # 2 -> 1
	assert_eq(sim._iframe_ticks_remaining[TARGET_ID], 1)
	_tick_noop()  # 1 -> 0
	assert_eq(sim._iframe_ticks_remaining[TARGET_ID], 0)
	var events := _tick_attack()
	assert_eq(_events_of_kind(events, "hit").size(), 1, "i-frames must have expired -- a normal hit should land")


## Off-by-one boundary pin, driven entirely by consecutive attacks (no noop ticks) so
## it exercises the exact interleaving of _advance_iframes' decrement and
## _apply_attack's gate check within tick() -- duration=2 is the minimal window that
## still yields one genuinely protected tick, given tick() always decrements once,
## even on the very tick that resolves the arming hit's next attack. The application
## tick and the expiration tick must never drift silently through a future refactor.
func test_iframe_boundary_two_tick_window_absorbs_exactly_once() -> void:
	_register_target(100.0, 2)
	var arming := _tick_attack()  # normal hit, health 90, arms remaining=2
	assert_eq(_events_of_kind(arming, "hit").size(), 1)
	var protected_tick := _tick_attack()  # tick() decrements 2 -> 1 first, then gate sees 1 > 0
	assert_eq(_events_of_kind(protected_tick, "attack_absorbed").size(), 1, "the tick immediately after the arming hit must still be protected")
	assert_almost_eq(sim._health[TARGET_ID], 90.0, 0.001, "the protected tick must deal zero damage")
	var expired_tick := _tick_attack()  # tick() decrements 1 -> 0 first, then gate sees 0, not > 0
	assert_eq(_events_of_kind(expired_tick, "hit").size(), 1, "the very next tick must land a normal hit -- exactly one protected tick from a duration=2 window")
	assert_almost_eq(sim._health[TARGET_ID], 80.0, 0.001)


func test_blocked_hit_does_not_start_iframe_timer() -> void:
	_register_target(100.0, 5)
	_register_shield(20.0, 1.0, 3, 2.0)
	_tick_block(true)  # rising edge -> HELD
	var events := _tick_attack()  # damage 10 < meter 20 -> absorbed by the shield, not blocked by i-frames
	assert_eq(_events_of_kind(events, "blocked").size(), 1)
	assert_eq(sim._iframe_ticks_remaining.get(TARGET_ID, 0), 0, "a blocked hit must never arm the i-frame timer")


func test_shield_break_does_not_start_iframe_timer() -> void:
	_register_target(100.0, 5)
	_register_shield(5.0, 1.0, 3, 2.0)  # meter smaller than the 10-damage swing
	_tick_block(true)
	var events := _tick_attack()
	assert_eq(_events_of_kind(events, "shield_broken").size(), 1)
	assert_eq(sim._iframe_ticks_remaining.get(TARGET_ID, 0), 0, "a shield break must never arm the i-frame timer")


func test_lethal_hit_starts_no_iframe_timer() -> void:
	_register_target(5.0, 5)  # dies to the first 10-damage swing
	var events := _tick_attack()
	assert_eq(_events_of_kind(events, "died").size(), 1)
	assert_eq(sim._iframe_ticks_remaining.get(TARGET_ID, 0), 0, "a lethal hit must not arm a timer for the dead")


func test_absorbed_attack_does_not_refresh_iframe_timer() -> void:
	_register_target(100.0, 5)
	_tick_attack()  # timer -> 5
	_tick_noop()  # 5 -> 4
	# tick() always decrements at its own top (4 -> 3) before resolving the attack,
	# so the absorbed swing sees 3 (>0, still absorbed) -- the point under test is
	# that it stays 3 afterward instead of jumping back up to 5.
	_tick_attack()
	assert_eq(sim._iframe_ticks_remaining[TARGET_ID], 3, "an absorbed swing must not refresh the active timer")


# --- Shield state machine: READY / regen ---

func test_ready_state_meter_regenerates_each_tick() -> void:
	_register_target()
	_register_shield(20.0, 1.0, 3, 2.0)
	sim._shield_meter[TARGET_ID] = 10.0  # simulate partial depletion for a clean regen check
	_tick_block(false)
	assert_almost_eq(sim._shield_meter[TARGET_ID], 11.0, 0.001)


func test_ready_state_regen_clamps_at_meter_max() -> void:
	_register_target()
	_register_shield(20.0, 5.0, 3, 2.0)
	sim._shield_meter[TARGET_ID] = 18.0
	_tick_block(false)
	assert_almost_eq(sim._shield_meter[TARGET_ID], 20.0, 0.001, "regen must not overshoot meter_max")


# --- Shield state machine: HELD ---

func test_block_rising_edge_enters_held() -> void:
	_register_target()
	_register_shield()
	assert_eq(sim._shield_state[TARGET_ID], "ready")
	_tick_block(true)
	assert_eq(sim._shield_state[TARGET_ID], "held")


func test_block_start_tick_recorded_on_rising_edge() -> void:
	_register_target()
	_register_shield()
	_tick_noop()
	var tick_before: int = sim.tick_count
	_tick_block(true)
	assert_eq(sim._block_start_tick[TARGET_ID], tick_before, "block-start tick must record the tick the rising edge was processed on")


func test_held_state_meter_frozen_no_regen() -> void:
	_register_target()
	_register_shield(20.0, 5.0, 3, 2.0)
	_tick_block(true)  # -> HELD
	sim._shield_meter[TARGET_ID] = 10.0
	_tick_block(true)  # still held
	assert_almost_eq(sim._shield_meter[TARGET_ID], 10.0, 0.001, "meter must not regenerate while HELD")


func test_release_returns_held_to_ready() -> void:
	_register_target()
	_register_shield()
	_tick_block(true)
	assert_eq(sim._shield_state[TARGET_ID], "held")
	_tick_block(false)
	assert_eq(sim._shield_state[TARGET_ID], "ready")


# --- Shield state machine: absorption & break ---

func test_partial_damage_absorbed_reduces_meter_and_emits_blocked() -> void:
	_register_target()
	_register_shield(20.0, 1.0, 3, 2.0)
	_tick_block(true)
	var events := _tick_attack()  # 10 damage into a 20 meter
	var blocked := _events_of_kind(events, "blocked")
	assert_eq(blocked.size(), 1)
	assert_almost_eq(blocked[0].payload.get("damage_absorbed"), 10.0, 0.001)
	assert_almost_eq(sim._shield_meter[TARGET_ID], 10.0, 0.001)
	assert_eq(sim._shield_state[TARGET_ID], "held", "a non-breaking block must not change state")
	assert_almost_eq(sim._health[TARGET_ID], 100.0, 0.001, "a blocked hit must deal zero health damage")


func test_overflow_damage_breaks_shield_with_zero_spill_to_health() -> void:
	_register_target()
	_register_shield(5.0, 1.0, 3, 2.0)  # damage(10) >= meter(5)
	_tick_block(true)
	var events := _tick_attack()
	var broken := _events_of_kind(events, "shield_broken")
	assert_eq(broken.size(), 1)
	assert_eq(sim._shield_state[TARGET_ID], "broken")
	assert_almost_eq(sim._shield_meter[TARGET_ID], 0.0, 0.001)
	assert_almost_eq(sim._health[TARGET_ID], 100.0, 0.001, "shield identity is full absorption -- overflow never spills to health")


func test_break_applies_the_shields_own_knockback_along_attack_direction() -> void:
	_register_target()
	_register_shield(5.0, 1.0, 3, 2.0)
	_tick_block(true)
	_tick_attack()
	var target_position: Vector3 = sim.entities[TARGET_ID]
	assert_almost_eq(target_position.z, -3.0, 0.001, "break knockback (distance 2.0) should push the target from -1 to -3 along the attack's -Z direction")


## Consolidated cross-check: a breaking hit's ENTIRE outcome set in one place, so a
## future refactor that accidentally also fires "hit"/"attack_absorbed", spends an
## i-frame slot, or applies the weapon's (rather than the shield's) knockback fails
## a single obvious test instead of three separate ones going quietly stale.
func test_shield_break_emits_only_shield_broken_no_hit_no_iframe_no_weapon_knockback() -> void:
	_register_target(100.0, 7)  # nonzero iframe_ticks_on_hit -- a real slot to accidentally consume
	_register_shield(5.0, 1.0, 3, 2.0)  # damage(10) >= meter(5); weapon knockback_distance is 1.0 (before_each)
	_tick_block(true)
	var events := _tick_attack()
	assert_eq(events.size(), 1, "a breaking hit must emit exactly one event")
	assert_eq(events[0].kind, "shield_broken")
	assert_eq(_events_of_kind(events, "hit").size(), 0, "a break must never also emit a health-damage hit event")
	assert_eq(_events_of_kind(events, "attack_absorbed").size(), 0)
	assert_almost_eq(sim._health[TARGET_ID], 100.0, 0.001, "health-damage outcome must not occur")
	assert_eq(sim._iframe_ticks_remaining.get(TARGET_ID, 0), 0, "hit-i-frame outcome must not occur")
	var target_position: Vector3 = sim.entities[TARGET_ID]
	assert_almost_eq(target_position.z, -3.0, 0.001, "must move by the SHIELD's knockback_distance (2.0: -1 -> -3), not the weapon's (1.0: -1 -> -2)")


func test_broken_state_blocks_regen_until_recovery_delay_elapses() -> void:
	_register_target()
	_register_shield(5.0, 10.0, 3, 2.0)  # large regen_per_tick makes post-delay recovery obvious
	_tick_block(true)
	_tick_attack()  # breaks: meter 0, break_ticks_remaining = 3
	assert_eq(sim._shield_break_ticks_remaining[TARGET_ID], 3)
	_tick_block(false)  # 3 -> 2
	assert_almost_eq(sim._shield_meter[TARGET_ID], 0.0, 0.001, "meter must stay at 0 during the recovery delay")
	assert_eq(sim._shield_state[TARGET_ID], "broken")
	_tick_block(false)  # 2 -> 1
	assert_eq(sim._shield_state[TARGET_ID], "broken")
	_tick_block(false)  # 1 -> 0 (delay elapses this tick; regen begins NEXT tick)
	assert_eq(sim._shield_state[TARGET_ID], "broken")
	_tick_block(false)  # delay already 0 -> regen fires
	assert_eq(sim._shield_state[TARGET_ID], "ready")
	assert_almost_eq(sim._shield_meter[TARGET_ID], 5.0, 0.001, "regen clamps at meter_max even on the recovery tick")


func test_broken_transitions_to_ready_the_instant_meter_exceeds_zero() -> void:
	_register_target()
	_register_shield(5.0, 0.01, 1, 2.0)  # tiny regen step, 1-tick delay
	_tick_block(true)
	_tick_attack()  # break: meter 0, break_ticks_remaining = 1
	_tick_block(false)  # delay: 1 -> 0
	assert_eq(sim._shield_state[TARGET_ID], "broken")
	_tick_block(false)  # delay already 0 -> regen fires: 0 + 0.01 = 0.01 > 0
	assert_eq(sim._shield_state[TARGET_ID], "ready", "no minimum threshold -- a sliver of meter is enough to leave BROKEN")
	assert_almost_eq(sim._shield_meter[TARGET_ID], 0.01, 0.0001)


func test_broken_state_rejects_held_block_command_with_reason() -> void:
	_register_target()
	_register_shield(5.0, 1.0, 5, 2.0)
	_tick_block(true)
	_tick_attack()  # break
	var events := _tick_block(true)  # still holding through the break
	var rejected := _events_of_kind(events, "block_rejected")
	assert_eq(rejected.size(), 1)
	assert_eq(rejected[0].payload.get("reason"), "broken")


## Distinct from test_broken_state_rejects_held_block_command_with_reason above (which
## holds continuously through the break): here the player genuinely releases first and
## then presses again -- a real rising edge -- while still inside the recovery delay.
## A fresh press must be rejected exactly like a continued hold; BROKEN has no
## "but you just pressed it" exception.
func test_broken_state_rejects_a_fresh_press_arriving_while_still_broken() -> void:
	_register_target()
	_register_shield(5.0, 1.0, 10, 2.0)  # long delay so the fresh press still lands inside it
	_tick_block(true)
	_tick_attack()  # break: meter 0, break_ticks_remaining = 10
	_tick_block(false)  # genuine release
	var events := _tick_block(true)  # genuine fresh press -- rising edge, but still broken
	var rejected := _events_of_kind(events, "block_rejected")
	assert_eq(rejected.size(), 1, "a fresh rising-edge press must be rejected just like a continued hold")
	assert_eq(rejected[0].payload.get("reason"), "broken")
	assert_eq(sim._shield_state[TARGET_ID], "broken", "a fresh press must not force a state change while still broken")


func test_broken_state_does_not_reject_a_released_block_command() -> void:
	_register_target()
	_register_shield(5.0, 1.0, 5, 2.0)
	_tick_block(true)
	_tick_attack()  # break
	var events := _tick_block(false)  # not attempting to block -- nothing to reject
	assert_eq(_events_of_kind(events, "block_rejected").size(), 0)


# --- Fresh-intent rule ---

func test_holding_through_break_does_not_reenter_held_on_recovery() -> void:
	_register_target()
	_register_shield(5.0, 10.0, 1, 2.0)  # 1-tick delay, large regen for fast recovery
	_tick_block(true)  # -> HELD
	_tick_attack()  # break: meter 0, delay = 1
	_tick_block(true)  # still held through the break: delay 1 -> 0, rejected (still broken)
	var events := _tick_block(true)  # delay already 0 -> regen -> ready; held has no rising edge (never released)
	assert_eq(sim._shield_state[TARGET_ID], "ready", "continuously holding through a break must not auto re-enter HELD")
	assert_eq(_events_of_kind(events, "block_rejected").size(), 0, "no longer BROKEN, so no rejection either -- just not (re-)engaging")


func test_release_and_repress_after_break_enters_held() -> void:
	_register_target()
	_register_shield(5.0, 10.0, 1, 2.0)
	_tick_block(true)  # -> HELD
	_tick_attack()  # break: meter 0, delay = 1
	_tick_block(false)  # released: delay 1 -> 0 (still broken)
	_tick_block(false)  # delay already 0 -> regen -> ready (held is false, no transition)
	assert_eq(sim._shield_state[TARGET_ID], "ready")
	_tick_block(true)  # genuine rising edge -> HELD
	assert_eq(sim._shield_state[TARGET_ID], "held", "a real release-then-repress must re-engage the shield")


# --- Determinism ---

func test_block_and_attack_sequence_is_deterministic() -> void:
	var results: Array = []
	for _i in range(2):
		var local_sim := SimWorld.new()
		local_sim.add_entity(ATTACKER_ID, Vector3.ZERO, 4.0)
		local_sim.register_weapon(WEAPON_ID, 10.0, &"force", 2.0, 60.0, 1.0)
		local_sim.set_equipped_weapon(ATTACKER_ID, WEAPON_ID)
		local_sim.set_damage_matrix({}, 1.5, 0.5)
		local_sim.add_entity(TARGET_ID, TARGET_POSITION, 0.0)
		local_sim.register_combatant(TARGET_ID, 100.0, TARGET_FAMILY, 5)
		local_sim.register_shield(TARGET_ID, 20.0, 1.0, 3, 2.0)
		local_sim.tick([Command.new(local_sim.tick_count, TARGET_ID, "block", {"held": true})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, ATTACKER_ID, "attack", {"aim": Vector3.ZERO})], 1.0 / 30.0)
		local_sim.tick([Command.new(local_sim.tick_count, TARGET_ID, "block", {"held": false})], 1.0 / 30.0)
		results.append({"meter": local_sim._shield_meter[TARGET_ID], "state": local_sim._shield_state[TARGET_ID], "health": local_sim._health[TARGET_ID]})
	assert_eq(results[0], results[1], "an identical command sequence must produce identical sim state")
