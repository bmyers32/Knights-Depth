extends GutTest
## P29 band invariants, held against the REAL shipped content (damage-matrix-lint
## precedent: a content family whose rules are only in a comment drifts).
##
## TWO TIERS, deliberately kept apart in code as well as in prose:
##   PERMANENT LAW  — bands may not OVERLAP. Two bands containing the same distance make
##                    deterministic selection ambiguous, which is exactly what the
##                    no-hidden-priority ruling cannot tolerate. This never relaxes.
##   PROVISIONAL LINT — bands must TILE with no gaps. This is typo prevention, not schema
##                    law. See test_bands_tile_without_gaps for its removal trigger.

const FAMILIES: Array[StringName] = [&"fang", &"ooze", &"watcher"]


func _actions_sorted_by_min_range(enemy_key: StringName) -> Array:
	var stats: Resource = ContentDB.get_resource(&"enemy", enemy_key)
	var actions: Array = []
	for action_id: StringName in stats.action_ids:
		var action: NaturalWeaponStats = ContentDB.get_resource(&"natural_weapon", action_id)
		actions.append({
			"id": action_id,
			"min_range": action.min_range,
			"max_range": ContentRegistrar.resolve_max_range(action, stats),
			"resource": action,
		})
	actions.sort_custom(func(a, b): return a.min_range < b.min_range)
	return actions


# --- permanent law -----------------------------------------------------------------

func test_every_repertoire_is_non_empty() -> void:
	for enemy_key in FAMILIES:
		var stats: Resource = ContentDB.get_resource(&"enemy", enemy_key)
		assert_gt(stats.action_ids.size(), 0, "%s must author at least one action" % enemy_key)


## GAME-RULES §3: "Action eligibility must never be ambiguous: authored bands may not
## overlap." This is the HARD failure for that law.
##
## Tested PAIRWISE against SimWorld.band_contains -- the selector's own eligibility
## predicate -- rather than against a re-derived adjacency inequality. The earlier
## sorted-adjacent `next.min >= prev.max` form was strictly weaker: it approved a
## degenerate band like [5.0, 5.0] sitting on another band's inclusive maximum, which the
## selector treats as eligible for BOTH. Enforcing the law with a different notion of
## eligibility than the selector uses is how a lint starts certifying ambiguity.
##
## Same law is warned at registration (SimWorld._lint_band_overlap, using this same
## predicate) for content that never reaches a test. Both layers treat every overlap
## identically -- there is no privileged sub-case.
func test_no_two_bands_overlap() -> void:
	for enemy_key in FAMILIES:
		var actions: Array = _actions_sorted_by_min_range(enemy_key)
		var bands: Array = _as_selector_bands(actions)
		for i in bands.size():
			for j in range(i + 1, bands.size()):
				var shared: float = maxf(float(bands[i].min_range), float(bands[j].min_range))
				var ambiguous: bool = SimWorld.band_contains(bands[i], shared) and SimWorld.band_contains(bands[j], shared)
				assert_false(ambiguous,
					"%s: '%s' [%.2f, %.2f] and '%s' [%.2f, %.2f] are both eligible at %.2f -- overlapping bands make selection ambiguous, which no array order may silently resolve" % [
						enemy_key, bands[i].id, bands[i].min_range, bands[i].max_range,
						bands[j].id, bands[j].min_range, bands[j].max_range, shared])


## Mirrors register_ai's derivation: the terminal band is the single largest max_range,
## and only it includes its own maximum.
func _as_selector_bands(actions: Array) -> Array:
	var terminal_max: float = -INF
	for action in actions:
		terminal_max = max(terminal_max, float(action.max_range))
	var bands: Array = []
	for action in actions:
		bands.append({
			"id": action.id,
			"min_range": float(action.min_range),
			"max_range": float(action.max_range),
			"is_terminal": is_equal_approx(float(action.max_range), terminal_max),
		})
	return bands


func test_every_band_is_ordered_and_non_degenerate() -> void:
	for enemy_key in FAMILIES:
		for action in _actions_sorted_by_min_range(enemy_key):
			assert_lt(action.min_range, action.max_range,
				"%s: '%s' has an empty or inverted band" % [enemy_key, action.id])


## Exactly ONE terminal band per repertoire, and it is derived rather than authored.
## Two actions sharing the largest max_range would both be inclusive at that maximum --
## an overlap at a single point, which is still an overlap.
func test_each_repertoire_has_exactly_one_terminal_band() -> void:
	for enemy_key in FAMILIES:
		var actions: Array = _actions_sorted_by_min_range(enemy_key)
		var largest: float = -INF
		for action in actions:
			largest = max(largest, action.max_range)
		var terminal_count: int = 0
		for action in actions:
			if is_equal_approx(action.max_range, largest):
				terminal_count += 1
		assert_eq(terminal_count, 1, "%s must have exactly one outermost band" % enemy_key)


## An actor that settles where no action applies would stand in its own engagement band
## doing nothing. Reported with the owning band so a violation names its own fix.
func test_preferred_attack_distance_falls_inside_some_band() -> void:
	for enemy_key in FAMILIES:
		var stats: Resource = ContentDB.get_resource(&"enemy", enemy_key)
		var actions: Array = _actions_sorted_by_min_range(enemy_key)
		var owner: String = ""
		for i in actions.size():
			var is_terminal: bool = i == actions.size() - 1
			var inside: bool = stats.preferred_attack_distance >= actions[i].min_range and (
				stats.preferred_attack_distance < actions[i].max_range
				or (is_terminal and stats.preferred_attack_distance <= actions[i].max_range))
			if inside:
				owner = String(actions[i].id)
				break
		assert_ne(owner, "", "%s settles at %.2f, where no authored action applies" % [enemy_key, stats.preferred_attack_distance])


func test_projectile_and_melee_actions_author_their_own_fields() -> void:
	for enemy_key in FAMILIES:
		for action in _actions_sorted_by_min_range(enemy_key):
			var resource: NaturalWeaponStats = action.resource
			if resource.attack_resolution == &"projectile":
				assert_gt(resource.projectile_speed, 0.0, "%s: a projectile needs travel speed" % action.id)
				assert_gt(resource.projectile_hit_radius, 0.0, "%s: a projectile needs a hit radius" % action.id)
				assert_gt(resource.projectile_max_lifetime_ticks, 0, "%s: a projectile needs a lifetime or it never despawns" % action.id)
			else:
				assert_eq(resource.projectile_speed, 0.0, "%s: a melee action must leave projectile fields inert" % action.id)
				assert_eq(resource.projectile_hit_radius, 0.0, "%s: a melee action must leave projectile fields inert" % action.id)
				assert_eq(resource.projectile_max_lifetime_ticks, 0, "%s: a melee action must leave projectile fields inert" % action.id)


## A projectile action must be able to physically cross its own band, or its outer range
## is a lie: the AI would select it at a distance the shot expires before reaching.
func test_a_projectile_can_actually_reach_its_own_bands_far_edge() -> void:
	for enemy_key in FAMILIES:
		for action in _actions_sorted_by_min_range(enemy_key):
			var resource: NaturalWeaponStats = action.resource
			if resource.attack_resolution != &"projectile":
				continue
			var reach: float = resource.projectile_speed * (float(resource.projectile_max_lifetime_ticks) / Engine.physics_ticks_per_second)
			assert_gt(reach, action.max_range,
				"%s travels %.2f units before expiring but is selectable out to %.2f" % [action.id, reach, action.max_range])


# --- provisional lint --------------------------------------------------------------

## PROVISIONAL, NOT LAW. Purpose is typo prevention: a mistyped edge silently creates a
## distance where the enemy provably cannot act, which reads as "it mysteriously stopped
## attacking" rather than as a content error.
##
## REMOVAL TRIGGER: the first enemy design that deliberately wants a meaningful INTERIOR
## dead band. At that point delete this test and nothing else — the fall-through
## behaviour it protects is already specified and already covered by
## test_enemy_repertoire.gd::test_interior_band_gap_falls_through_to_ordinary_locomotion,
## so relaxing the lint adds no behaviour machinery. Do NOT weaken it for a content
## typo; fix the content.
func test_bands_tile_without_gaps() -> void:
	for enemy_key in FAMILIES:
		var actions: Array = _actions_sorted_by_min_range(enemy_key)
		assert_eq(actions[0].min_range, 0.0, "%s: the innermost band must start at 0" % enemy_key)
		for i in range(1, actions.size()):
			assert_almost_eq(actions[i].min_range, actions[i - 1].max_range, 0.0001,
				"%s: gap between '%s' (ends %.2f) and '%s' (starts %.2f) -- adjacent bands must satisfy next.min_range == prev.max_range exactly, with no epsilon ownership" % [
					enemy_key, actions[i - 1].id, actions[i - 1].max_range, actions[i].id, actions[i].min_range])


## A SHARED TERMINAL MAXIMUM IS AN OVERLAP — two bands containing the same distance —
## and therefore carries no privileged status: it is caught by the one general predicate,
## at both layers, exactly like any other overlap. This test pins that equivalence so the
## special-cased treatment cannot creep back.
##
## Each row is a distinct overlap SHAPE; all must be detected identically.
## Expect one "both cover distance" registration warning per row in the console.
func test_every_overlap_shape_is_detected_by_the_one_general_predicate() -> void:
	var shapes: Array = [
		{"name": "shared terminal maximum (degenerate upper band)",
			"a": {"min_range": 0.0, "max_range": 5.0}, "b": {"min_range": 5.0, "max_range": 5.0}},
		{"name": "ordinary interval overlap",
			"a": {"min_range": 0.0, "max_range": 5.0}, "b": {"min_range": 3.0, "max_range": 9.0}},
		{"name": "full containment",
			"a": {"min_range": 0.0, "max_range": 9.0}, "b": {"min_range": 2.0, "max_range": 4.0}},
		{"name": "identical bands",
			"a": {"min_range": 2.0, "max_range": 6.0}, "b": {"min_range": 2.0, "max_range": 6.0}},
	]
	for shape in shapes:
		var sim := SimWorld.new()
		sim.add_entity(1, Vector3.ZERO, 0.0)
		sim.register_weapon(&"a", 1.0, &"force", 5.0, 90.0, 0.0, 0)
		sim.register_weapon(&"b", 1.0, &"force", 5.0, 90.0, 0.0, 0)
		var repertoire: Array[Dictionary] = [
			{"id": &"a", "min_range": shape.a.min_range, "max_range": shape.a.max_range, "windup_ticks": 5},
			{"id": &"b", "min_range": shape.b.min_range, "max_range": shape.b.max_range, "windup_ticks": 5},
		]
		sim.register_ai(1, repertoire, Vector3.ZERO, 2.0, 0.0, 8.0, 20.0)

		var bands: Array = sim._ai_repertoire[1]
		var shared: float = maxf(float(bands[0].min_range), float(bands[1].min_range))
		assert_true(SimWorld.band_contains(bands[0], shared) and SimWorld.band_contains(bands[1], shared),
			"%s: both bands must be recognised as eligible at %.2f -- that IS the overlap the law forbids" % [shape.name, shared])


## And the clean case must NOT be flagged: adjacent half-open bands share an EDGE without
## sharing a distance. Without this, the overlap check could be trivially over-strict and
## every valid repertoire (including the shipped Watcher) would read as ambiguous.
func test_adjacent_half_open_bands_are_not_an_overlap() -> void:
	var sim := SimWorld.new()
	sim.add_entity(1, Vector3.ZERO, 0.0)
	sim.register_weapon(&"a", 1.0, &"force", 2.0, 90.0, 0.0, 0)
	sim.register_weapon(&"b", 1.0, &"force", 9.0, 90.0, 0.0, 0)
	var repertoire: Array[Dictionary] = [
		{"id": &"a", "min_range": 0.0, "max_range": 2.0, "windup_ticks": 5},
		{"id": &"b", "min_range": 2.0, "max_range": 9.0, "windup_ticks": 5},
	]
	sim.register_ai(1, repertoire, Vector3.ZERO, 1.0, 0.0, 8.0, 20.0)

	var bands: Array = sim._ai_repertoire[1]
	assert_false(SimWorld.band_contains(bands[0], 2.0), "the non-terminal band must NOT include its own maximum")
	assert_true(SimWorld.band_contains(bands[1], 2.0), "the upper band owns the shared edge, alone")
	assert_true(SimWorld.band_contains(bands[1], 9.0), "and the terminal band still includes its own maximum")


# --- the shipped Watcher, named explicitly -----------------------------------------

## The exemplar the whole feature was designed around, asserted by name so a silent
## content edit has to argue with a test (BRAIN test-philosophy: a small number of NAMED
## content fixtures protect exemplar behaviours).
func test_watcher_ships_the_authored_two_action_repertoire() -> void:
	var actions: Array = _actions_sorted_by_min_range(&"watcher")
	assert_eq(actions.size(), 2, "the Watcher is P29's multi-action consumer")
	assert_eq(String(actions[0].id), "watcher_pulse")
	assert_eq(actions[0].min_range, 0.0)
	assert_eq(actions[0].max_range, 2.0)
	assert_eq(String(actions[1].id), "watcher_survey")
	assert_eq(actions[1].min_range, 2.0)
	assert_eq(actions[1].max_range, 9.0)
	assert_eq(actions[1].resource.attack_resolution, &"projectile")
	assert_gt(actions[1].resource.windup_ticks, actions[0].resource.windup_ticks,
		"the ranged action pays for its range in commitment -- a longer windup is its counterplay, not an accident")


# --- locked flinch-capability map (P29 re-playtest A/B, 2026-08-17) ----------------

## Basic ranged fire cannot cash a flinch; it still builds pressure. Ruled from the live
## EXPLOIT-vs-NONE comparison ("basic wand flinch is clearly too strong").
func test_basic_guns_cannot_trigger_flinch_but_still_build_pressure() -> void:
	for weapon_id in [&"wand_A", &"gun_pierce_A", &"gun_arc_A", &"gun_umbral_A"]:
		var gun: GunStats = ContentDB.get_resource(&"weapon", weapon_id)
		assert_eq(gun.flinch_capability, &"none",
			"%s: basic ranged fire must not trigger flinch (locked 2026-08-17)" % weapon_id)
		assert_true(gun.contributes_pressure,
			"%s: pressure CONTRIBUTION is deliberately unchanged -- the wand still builds pressure, it simply cannot cash it" % weapon_id)


## The sword map is what the wand ruling's identity consequence RESTS ON: with basic
## ranged fire at NONE, the direct EXPLOIT route into an enemy's authored window requires
## closing and landing sword hit 1 or hit 2. If this map ever drifts, that consequence
## silently changes meaning, so it is pinned rather than assumed.
##
## Movement tools (shield bump, the charge's lunge) help CLOSE that distance and are NOT
## exploit triggers -- traversal is not capability. Nothing in this test treats them as such.
func test_sword_combo_authors_the_locked_exploit_pressure_map() -> void:
	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_burn_A")
	assert_eq(sword.combo_profiles.size(), 3, "sanity: the locked map describes a 3-hit combo")
	if sword.combo_profiles.size() != 3:
		return
	assert_eq(sword.combo_profiles[0].flinch_capability, &"exploit", "hit 1 is an EXPLOIT trigger")
	assert_eq(sword.combo_profiles[1].flinch_capability, &"exploit", "hit 2 is an EXPLOIT trigger")
	assert_eq(sword.combo_profiles[2].flinch_capability, &"pressure", "hit 3 cashes PRESSURE, not the window")
	assert_eq(sword.charge_profile.flinch_capability, &"pressure", "the charge cashes PRESSURE, not the window")


## Fang and Ooze stay single-action: P29 explicitly does not change them, and their
## behaviour is held byte-identical by tests/test_ai_backward_compat.gd.
func test_fang_and_ooze_remain_single_action() -> void:
	for enemy_key in [&"fang", &"ooze"]:
		var stats: Resource = ContentDB.get_resource(&"enemy", enemy_key)
		assert_eq(stats.action_ids.size(), 1, "%s must stay single-action in P29" % enemy_key)
