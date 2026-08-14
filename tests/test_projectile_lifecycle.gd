extends GutTest
## P29 tracer lifecycle: every way a projectile can END must be attributable to the shot
## that caused it.
##
## WHY THIS EXISTS: presentation spawns a tracer on `projectile_fired` and removes it on
## the terminal event carrying the same projectile_id. A shot that terminates ON A TARGET
## does so through _resolve_hit_on_target, which returns one of FOUR different events —
## and before P29 none of them identified the projectile. A blocked shot whose tracer
## sailed on would read as a hit-detection bug and poison exactly the readability
## judgments the tracer exists to enable. Five exits, five tests, one negative.
##
## The tracer itself is COSMETIC PREDICTION and is not under test here (presentation is
## exempt); what is under test is the sim contract it depends on.

var sim: SimWorld

const SHOOTER_ID := 0
const TARGET_ID := 1
const GUN := &"test_gun"
const DT := 1.0 / 30.0


func before_each() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(SHOOTER_ID, Vector3.ZERO, 0.0)
	sim.register_combatant(SHOOTER_ID, 999.0, &"envoy", 0, 0.4, &"player")
	sim.add_entity(TARGET_ID, Vector3(0, 0, -3.0), 0.0)
	sim.register_combatant(TARGET_ID, 999.0, &"fang", 0, 0.9, &"enemy")
	sim.register_gun(GUN, 5.0, &"force", 9.0, 60, 0.5, 0.0, 0)
	sim.set_equipped_weapon(SHOOTER_ID, GUN)


func _fire() -> int:
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, SHOOTER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	for event in events:
		if event.kind == "projectile_fired":
			return int(event.payload.projectile_id)
	fail_test("expected a projectile_fired event")
	return -1


## Ticks until an event of one of `kinds` appears, returning it. Deliberately bounded:
## an unbounded wait would hang the suite on a regression rather than fail it.
func _await_terminal(kinds: Array, max_ticks: int = 60) -> Event:
	for _i in max_ticks:
		for event in sim.tick([], DT):
			if event.kind in kinds:
				return event
	return null


func _assert_carries_id(event: Event, projectile_id: int, exit_name: String) -> void:
	assert_not_null(event, "no terminal event for the '%s' exit" % exit_name)
	if event == null:
		return
	assert_true(event.payload.has("projectile_id"),
		"the '%s' exit must identify its projectile or presentation cannot end the tracer" % exit_name)
	assert_eq(int(event.payload.get("projectile_id", -1)), projectile_id, exit_name)


# --- the five exits ----------------------------------------------------------------

func test_hit_exit_carries_the_projectile_id() -> void:
	var projectile_id: int = _fire()
	_assert_carries_id(_await_terminal(["hit"]), projectile_id, "hit")


func test_blocked_exit_carries_the_projectile_id() -> void:
	sim.register_shield(TARGET_ID, 100.0, 0.0, 30, 0.0)
	sim.tick([Command.new(sim.tick_count, TARGET_ID, "block", {"held": true})], DT)
	var projectile_id: int = _fire()
	_assert_carries_id(_await_terminal(["blocked"]), projectile_id, "blocked")


func test_shield_broken_exit_carries_the_projectile_id() -> void:
	sim.register_shield(TARGET_ID, 1.0, 0.0, 30, 0.0)  # meter below the shot's damage
	sim.tick([Command.new(sim.tick_count, TARGET_ID, "block", {"held": true})], DT)
	var projectile_id: int = _fire()
	_assert_carries_id(_await_terminal(["shield_broken"]), projectile_id, "shield_broken")


func test_iframe_absorbed_exit_carries_the_projectile_id() -> void:
	var projectile_id: int = _fire()
	sim._iframe_ticks_remaining[TARGET_ID] = 60
	_assert_carries_id(_await_terminal(["attack_absorbed"]), projectile_id, "attack_absorbed")


func test_expiry_exit_carries_the_projectile_id() -> void:
	sim.entities[TARGET_ID] = Vector3(100, 0, 0)  # nothing on the firing line
	var projectile_id: int = _fire()
	_assert_carries_id(_await_terminal(["projectile_expired"], 90), projectile_id, "projectile_expired")


# --- the negative ------------------------------------------------------------------

## The conditional-key discipline (the attack_profile_id precedent): a melee payload must
## be byte-identical to pre-P29. If projectile_id ever leaks onto melee hits, every
## existing payload assertion silently changes shape and the backward-compat gate's
## normalizer would have to grow an exception it was explicitly forbidden to grow.
func test_melee_hits_carry_no_projectile_id_at_all() -> void:
	sim.register_weapon(&"blade", 5.0, &"force", 4.0, 90.0, 0.0, 0)
	sim.set_equipped_weapon(SHOOTER_ID, &"blade")
	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, SHOOTER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	var hits := events.filter(func(e): return e.kind == "hit")
	assert_eq(hits.size(), 1, "sanity: the swing landed")
	if hits.size() == 1:
		assert_false(hits[0].payload.has("projectile_id"),
			"a melee hit must not gain the key at all -- not even set to -1")


# --- parry integration (P16 x P29) -------------------------------------------------

## A survey-style projectile reaching a held shield inside the parry window resolves
## through the ordinary blocked-family exit AND marks the attacker PARRY EXPOSED using
## unchanged P16 semantics. Asserted together deliberately: the tracer must end and the
## defender must be rewarded, and a regression in either alone is still a bug.
##
## The shield is raised while the shot is already travelling, so the rising edge the
## parry window measures from is genuinely earned mid-flight rather than pre-held. This
## is also why _advance_projectiles' phase order matters: a projectile arriving on the
## SAME tick the shield rises sees the pre-raise state (ordinary non-retroactivity, a
## locked P16 invariant), so the raise happens with travel time still to spare.
func test_a_parried_projectile_ends_its_tracer_and_exposes_the_attacker() -> void:
	sim.register_shield(TARGET_ID, 100.0, 0.0, 30, 0.0, 0.0, 0.0, 1, 0, 8, 25, 2.0)
	var projectile_id: int = _fire()
	sim.tick([], DT)  # let the shot travel a tick before the shield goes up

	var events: Array[Event] = sim.tick([Command.new(sim.tick_count, TARGET_ID, "block", {"held": true})], DT)
	var terminal: Event = null
	for _i in 40:
		for event in events:
			if event.kind == "blocked" or event.kind == "shield_broken":
				terminal = event
		if terminal != null:
			break
		events = sim.tick([Command.new(sim.tick_count, TARGET_ID, "block", {"held": true})], DT)

	_assert_carries_id(terminal, projectile_id, "parried (blocked-family)")
	assert_true(sim._parry_exposed_until_tick.has(SHOOTER_ID),
		"a parried projectile must mark the ATTACKER exposed -- parry is resolution-agnostic")
	assert_almost_eq(sim._parry_exposure_multiplier(SHOOTER_ID), 2.0, 0.001,
		"and the exposure must carry the authored multiplier through unchanged P16 semantics")
