extends GutTest
## NAMED INTEGRATION FIXTURE (GAME-RULES §3 / advisory §2.6): baseline sword vs the
## baseline M1 target, using REAL content through the production registration path
## (ContentRegistrar -- the same entrypoint arena.gd uses), never hand-built profiles
## and never convenience-zeroed defenses.
##
## Why this exists: every other combo/charge test registers its target at
## iframe_ticks_on_hit = 0, so the whole suite was structurally blind to the fact that
## the target's authored health-hit i-frames (15 ticks) silently absorbed the sword's
## own combo hits 2 and 3 (authored gaps of 6 and 7 ticks). A fully landed 1->2->3 dealt
## 8 damage instead of 26, and nothing failed. See BRAIN.md.
##
## THE INVARIANT: authored offensive cadence must not be suppressed by the target's own
## ordinary defensive timing -- iframe_ticks_on_hit must stay strictly below the
## smallest gap between consecutive authored hits. This fixture fails if a future
## retune of EITHER side (cadence down, i-frames up) violates that.
##
## Scope fence (advisory §2.6 / M7): this is one named exemplar, deliberately narrow.
## It is NOT a general multi-hit rule and NOT a mandate that every combat seam grow an
## integration fixture -- only interactions where live defensive values can suppress
## authored offensive cadence.

const ATTACKER_ID := 0
const TARGET_ID := 1
const DT := 1.0 / 30.0
## Inside the sword's 2.0 reach and outside the 1.4 combined-contact distance, so the
## authored lunge still clamps normally rather than starting already in contact.
const TARGET_POSITION := Vector3(0, 0, -1.6)
const AIM := Vector3(0, 0, -1)
## Long enough for a full 1->2->3 at the fastest cadence the sim accepts, with slack.
const PROBE_TICKS := 48

var sim: SimWorld


func before_each() -> void:
	sim = SimWorld.new()
	sim.seed_combat_rng(0)
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	sim.add_entity(ATTACKER_ID, Vector3.ZERO, envoy.move_speed)
	sim.register_combatant(ATTACKER_ID, envoy.max_health, envoy.family, 0, envoy.combat_radius, &"player")
	# Real Fang BODY only -- real max_health, real iframe_ticks_on_hit, real
	# combat_radius, no engagement AI. A stationary target isolates cadence from
	# movement; the defenses under test are the authored ones, not zeroed stand-ins.
	ContentRegistrar.register_enemy_body(sim, TARGET_ID, &"fang", TARGET_POSITION)
	ContentRegistrar.register_weapon(sim, &"sword_burn_A")
	sim.set_equipped_weapon(ATTACKER_ID, &"sword_burn_A")
	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)
	# Force is neutral against every family (GAME-RULES §3), so the authored damage
	# numbers below are the resolved ones -- no multiplier arithmetic in this fixture.
	# Burn must be registered: the sword's hit 3 carries a status payload, so a landed
	# finisher reaches _apply_status. Registering the same content arena.gd does keeps
	# this fixture on the production path rather than a partially-configured sim.
	var burn: BurnStats = ContentDB.get_resource(&"status", &"burn")
	sim.register_status(burn.status_id, burn.damage_per_tick, burn.tick_interval_ticks, burn.duration_ticks)
	var priority: StatusPriorityTable = ContentDB.get_resource(&"status", &"priority_table")
	sim.set_status_priority(priority.priority)


## Spam-taps at the fastest cadence the sim accepts (alternating pressed/released,
## letting the input buffer queue what lands during recovery) -- what a player actually
## does. Health is topped up each tick so the sequence can never end early via death;
## this fixture is about hit ACCEPTANCE, and time-to-kill is a separate tuning question.
func _run_fast_combo() -> Array:
	var landed: Array = []
	var pressed: bool = false
	for _i in range(PROBE_TICKS):
		var phase: String = "released" if pressed else "pressed"
		pressed = not pressed
		sim._health[TARGET_ID] = 999.0
		for event in sim.tick([Command.new(sim.tick_count, ATTACKER_ID, "attack", {"aim": AIM, "phase": phase})], DT):
			if event.kind == "hit":
				landed.append({"tick": sim.tick_count, "profile": event.payload.get("attack_profile_id"), "damage": event.payload.damage})
			elif event.kind == "attack_absorbed" and event.payload.get("reason") == "iframes":
				landed.append({"tick": sim.tick_count, "profile": "ABSORBED", "damage": 0.0})
	return landed


func test_full_combo_lands_all_three_authored_hits() -> void:
	var landed: Array = _run_fast_combo()
	assert_gte(landed.size(), 3, "the fastest legal tap cadence must produce at least a full 1->2->3")
	var first_three: Array = landed.slice(0, 3)
	var profiles: Array = first_three.map(func(entry): return entry.profile)
	assert_eq(profiles, ["1", "2", "3"],
		"a fully landed 1->2->3 must not self-suppress through the target's own health-hit i-frames -- got %s" % [profiles])


func test_full_combo_applies_the_authored_damage_of_each_hit() -> void:
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_burn_A")
	var landed: Array = _run_fast_combo()
	var damages: Array = landed.slice(0, 3).map(func(entry): return entry.damage)
	var authored: Array = []
	for profile in sword.combo_profiles:
		authored.append(profile.damage)
	assert_eq(damages, authored,
		"each accepted combo hit must apply its own authored damage (Force is neutral vs every family)")


## The invariant stated as arithmetic, so a retune of either side fails HERE with a
## readable message rather than as a mysterious damage shortfall in a playtest.
func test_target_iframes_stay_below_the_authored_combo_gap() -> void:
	var fang: FangStats = ContentDB.get_resource(&"enemy", &"fang")
	var landed: Array = _run_fast_combo()
	var first_three: Array = landed.slice(0, 3)
	var smallest_gap: int = PROBE_TICKS
	for i in range(1, first_three.size()):
		smallest_gap = min(smallest_gap, int(first_three[i].tick) - int(first_three[i - 1].tick))
	assert_lt(fang.iframe_ticks_on_hit, smallest_gap,
		"iframe_ticks_on_hit (%d) must stay strictly below the smallest authored inter-hit gap (%d) or the combo absorbs its own hits" % [fang.iframe_ticks_on_hit, smallest_gap])
