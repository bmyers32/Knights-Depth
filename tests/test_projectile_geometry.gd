extends GutTest
## P29 iteration item 3 — AUTHORITATIVE PROJECTILE GEOMETRY.
##
## Playtest finding: "the projectile's visual/authoritative relationship produces apparent
## hits that miss." Diagnosis (tools/diagnose_projectile_geometry.gd) measured the cause:
## the swept hit test compared distance-to-CENTRE against the projectile radius alone and
## never consulted the target's body, so a wand shot needed to pass within 0.40 of an
## Ooze whose authored body is 1.45 — shots crossing three-quarters of the visible body
## were clean misses.
##
## The correction is `projectile.hit_radius + target.combat_radius`, reusing the same
## authoritative body radius _contact_distance already supplies to Burn contact-spread,
## the melee lunge clamp and P16's bump. This file pins the resulting boundary exactly, in
## both directions, because "hits feel better now" is not a testable claim and a geometry
## rule that drifts is how the original defect happened.
##
## The sum exists ONLY in collision space. The tracer draws the projectile radius alone.

var sim: SimWorld

const SHOOTER_ID := 0
const TARGET_ID := 1
const GUN := &"probe_gun"
const DT := 1.0 / 30.0
const GUN_RADIUS := 0.40
const RANGE := 8.0


## Fires one shot straight down -Z from (offset, 0, 0) at a target parked at (0, 0, -RANGE),
## so the shot's perpendicular distance from the target's centre is exactly `offset`.
## Returns true if it resolved a hit on the target.
func _shot_at_offset(offset: float, body: float, family: StringName = &"fang") -> bool:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(SHOOTER_ID, Vector3(offset, 0.0, 0.0), 0.0)
	sim.register_combatant(SHOOTER_ID, 9999.0, &"envoy", 0, 0.45, &"player")
	sim.add_entity(TARGET_ID, Vector3(0.0, 0.0, -RANGE), 0.0)
	sim.register_combatant(TARGET_ID, 9999.0, family, 0, body, &"enemy")
	sim.register_gun(GUN, 5.0, &"force", 9.0, 90, GUN_RADIUS, 0.0, 0)
	sim.set_equipped_weapon(SHOOTER_ID, GUN)
	sim.tick([Command.new(sim.tick_count, SHOOTER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)
	for _t in 120:
		for event in sim.tick([], DT):
			if event.kind == "hit" and int(event.payload.get("target_id", -1)) == TARGET_ID:
				return true
	return false


# --- the boundary, per family -------------------------------------------------------

## The three shipped M1 bodies, each at a lateral offset that is INSIDE the visible body
## but well OUTSIDE the old centre-only test. Every one of these was a miss before.
func test_a_graze_inside_the_body_now_lands_for_every_m1_family() -> void:
	for row in [{"family": &"fang", "body": 0.9}, {"family": &"ooze", "body": 1.45}, {"family": &"watcher", "body": 0.85}]:
		var graze: float = float(row.body) * 0.9  # clearly within the body, far outside 0.40
		assert_true(_shot_at_offset(graze, row.body, row.family),
			"%s: a shot passing %.2f from centre is inside a %.2f body and must land (old centre-only test called this a miss)" % [row.family, graze, row.body])


## And the other direction, which matters just as much: a shot genuinely outside the
## summed volume must STILL MISS. The correction widens the hit volume to the truth, it
## does not make projectiles unmissable.
func test_a_shot_outside_the_summed_volume_still_misses() -> void:
	for row in [{"family": &"fang", "body": 0.9}, {"family": &"ooze", "body": 1.45}, {"family": &"watcher", "body": 0.85}]:
		var outside: float = float(row.body) + GUN_RADIUS + 0.25
		assert_false(_shot_at_offset(outside, row.body, row.family),
			"%s: %.2f is beyond body+radius and must remain a clean miss" % [row.family, outside])


# --- exact boundary behaviour -------------------------------------------------------

func test_just_inside_the_summed_radius_hits() -> void:
	var body := 0.9
	assert_true(_shot_at_offset(body + GUN_RADIUS - 0.02, body),
		"just inside body+radius must hit")


func test_just_outside_the_summed_radius_misses() -> void:
	var body := 0.9
	assert_false(_shot_at_offset(body + GUN_RADIUS + 0.02, body),
		"just outside body+radius must miss")


## Tangent: the test is `<=`, so exact contact counts as a hit. Pinned so the inclusivity
## is a decision on record rather than an accident of an operator.
func test_exact_tangent_counts_as_a_hit() -> void:
	var body := 0.9
	assert_true(_shot_at_offset(body + GUN_RADIUS, body),
		"exact tangent (distance == body + radius) is inclusive")


## A zero-radius body must behave exactly as before the correction — proof the change is
## purely additive and cannot have shifted anything that carries no combat_radius.
func test_a_bodyless_target_is_unchanged_by_the_correction() -> void:
	assert_true(_shot_at_offset(GUN_RADIUS - 0.02, 0.0), "still hits inside the raw projectile radius")
	assert_false(_shot_at_offset(GUN_RADIUS + 0.02, 0.0), "still misses outside it")


# --- incoming: hostile projectile against the Envoy ---------------------------------

func test_a_hostile_projectile_uses_the_envoys_body_too() -> void:
	var envoy: EnvoyStats = ContentDB.get_resource(&"envoy", &"default")
	var survey: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", &"watcher_survey")
	var summed: float = survey.projectile_hit_radius + envoy.combat_radius

	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	# Envoy offset laterally by nearly the full summed radius; the shot is fired straight
	# down -Z from the Watcher so aim-tracking cannot mask the geometry.
	sim.add_entity(SHOOTER_ID, Vector3(summed * 0.9, 0.0, 0.0), 0.0)
	sim.register_combatant(SHOOTER_ID, 9999.0, &"envoy", 0, envoy.combat_radius, &"player")
	sim.add_entity(TARGET_ID, Vector3(0.0, 0.0, -6.0), 0.0)
	sim.register_combatant(TARGET_ID, 9999.0, &"watcher", 0, 0.85, &"enemy")
	sim.register_gun(&"survey_probe", 6.0, &"force", survey.projectile_speed, survey.projectile_max_lifetime_ticks, survey.projectile_hit_radius, 0.0, 0)
	sim.set_equipped_weapon(TARGET_ID, &"survey_probe")
	sim.tick([Command.new(sim.tick_count, TARGET_ID, "attack", {"aim": Vector3(0, 0, 1)})], DT)

	var landed := false
	for _t in 120:
		for event in sim.tick([], DT):
			if event.kind == "hit" and int(event.payload.get("target_id", -1)) == SHOOTER_ID:
				landed = true
	assert_true(landed, "an incoming shot must resolve against the Envoy's body, not only its centre point")


# --- invariants the correction must not have broken ---------------------------------

## Ally pass-through is unchanged: allies are filtered at candidacy, BEFORE any geometry
## runs, so a wider hit volume must not start expiring shots on friendly bodies.
func test_allies_still_pass_through_despite_the_wider_volume() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(SHOOTER_ID, Vector3.ZERO, 0.0)
	sim.register_combatant(SHOOTER_ID, 9999.0, &"envoy", 0, 0.45, &"player")
	sim.add_entity(2, Vector3(0.0, 0.0, -3.0), 0.0)
	sim.register_combatant(2, 9999.0, &"envoy", 0, 2.0, &"player")  # huge ALLIED body on the line
	sim.add_entity(TARGET_ID, Vector3(0.0, 0.0, -8.0), 0.0)
	sim.register_combatant(TARGET_ID, 9999.0, &"fang", 0, 0.9, &"enemy")
	sim.register_gun(GUN, 5.0, &"force", 9.0, 90, GUN_RADIUS, 0.0, 0)
	sim.set_equipped_weapon(SHOOTER_ID, GUN)
	sim.tick([Command.new(sim.tick_count, SHOOTER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)

	var hit_enemy := false
	for _t in 120:
		for event in sim.tick([], DT):
			assert_ne(int(event.payload.get("target_id", -1)), 2, "an ally must never be hit, however large its body")
			if event.kind == "hit" and int(event.payload.get("target_id", -1)) == TARGET_ID:
				hit_enemy = true
	assert_true(hit_enemy, "and the shot must carry through to the hostile behind it")


## No tunnelling regression: the test still sweeps the whole travel SEGMENT, so a fast
## shot cannot skip a body it crossed between ticks.
func test_a_fast_shot_still_cannot_tunnel_through_a_body() -> void:
	sim = SimWorld.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(SHOOTER_ID, Vector3.ZERO, 0.0)
	sim.register_combatant(SHOOTER_ID, 9999.0, &"envoy", 0, 0.45, &"player")
	sim.add_entity(TARGET_ID, Vector3(0.0, 0.0, -5.0), 0.0)
	sim.register_combatant(TARGET_ID, 9999.0, &"fang", 0, 0.9, &"enemy")
	sim.register_gun(&"railgun", 5.0, &"force", 400.0, 90, GUN_RADIUS, 0.0, 0)  # >13 units per tick
	sim.set_equipped_weapon(SHOOTER_ID, &"railgun")
	sim.tick([Command.new(sim.tick_count, SHOOTER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)

	var landed := false
	for _t in 20:
		for event in sim.tick([], DT):
			if event.kind == "hit" and int(event.payload.get("target_id", -1)) == TARGET_ID:
				landed = true
	assert_true(landed, "a shot that crosses the body within a single tick must still resolve")


## Determinism when expanded volumes compete: two hostiles whose widened volumes both
## contain the path. Earliest point along the segment wins, and an exact tie breaks to the
## lower actor_id — the same rule every other sweep in the sim uses.
func test_earliest_hit_selection_is_deterministic_when_volumes_compete() -> void:
	for _run in 3:
		sim = SimWorld.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		sim.add_entity(SHOOTER_ID, Vector3.ZERO, 0.0)
		sim.register_combatant(SHOOTER_ID, 9999.0, &"envoy", 0, 0.45, &"player")
		# 5 is NEARER along the path; 2 is further. Both overlap the line generously.
		sim.add_entity(5, Vector3(0.5, 0.0, -4.0), 0.0)
		sim.register_combatant(5, 9999.0, &"ooze", 0, 1.45, &"enemy")
		sim.add_entity(2, Vector3(0.5, 0.0, -7.0), 0.0)
		sim.register_combatant(2, 9999.0, &"ooze", 0, 1.45, &"enemy")
		sim.register_gun(GUN, 5.0, &"force", 9.0, 90, GUN_RADIUS, 0.0, 0)
		sim.set_equipped_weapon(SHOOTER_ID, GUN)
		sim.tick([Command.new(sim.tick_count, SHOOTER_ID, "attack", {"aim": Vector3(0, 0, -1)})], DT)

		var struck: int = -1
		for _t in 120:
			for event in sim.tick([], DT):
				if event.kind == "hit" and struck == -1:
					struck = int(event.payload.get("target_id", -1))
		assert_eq(struck, 5, "the NEARER body along the segment must always be the one struck, every run")
