extends GutTest
## THE M1-PRESERVATION GATE for P29 (enemy action repertoire).
##
## P29 rewrites the AI's attack-eligibility gate in `_decide_single_ai_command` — a
## change to a SHARED decision function's condition order. BRAIN records that the last
## time that function's order changed, three AI tests broke that had never asserted
## anything about attacks: their ISOLATION depended on the surrounding control flow, not
## on their own assertions. Per-test review cannot catch that class of drift on its own,
## so this fixture compares the whole observable behaviour of the single-action families
## against a recording made BEFORE the change.
##
## THE CONTRACT (ruled): literal stream identity is impossible because attack_telegraph
## intentionally gains `action_id`. The comparison therefore runs through a normalizer
## whose explicit additive-key allow-list is EXACTLY
##     attack_telegraph -> action_id
## and nothing else (AiBaselineScenario.ADDITIVE_KEY_ALLOWLIST). After normalization the
## streams must be byte-identical: decisions, timing, movement, attack resolution,
## damage, cooldowns and reactions all unchanged.
##
## ANY ADDITIONAL DIFFERENCE IS A REGRESSION REQUIRING EXPLANATION, never another
## normalization exception and never a re-record. Regenerate the fixture only for a
## DELIBERATE, dated behaviour change (tools/record_ai_baseline.gd).

const BASELINE_PATH: String = "res://tests/fixtures/ai_baseline_pre_p29.json"


func _load_baseline() -> Array:
	var file := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	assert_not_null(file, "baseline fixture missing at %s -- regenerate with tools/record_ai_baseline.gd" % BASELINE_PATH)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Array, "baseline fixture must be a JSON array")
	return parsed if parsed is Array else []


func test_single_action_families_behave_exactly_as_before_p29() -> void:
	var baseline: Array = _load_baseline()
	assert_gt(baseline.size(), 0, "sanity: the baseline must not be empty")

	var sim := SimWorld.new()
	AiBaselineScenario.build(sim)
	var current: Array = AiBaselineScenario.run(sim)

	# Report the FIRST divergence with its index rather than only a size mismatch: a
	# stream that diverges at event 40 and a stream that diverges at event 240 are very
	# different bugs, and "arrays differ" names neither.
	var limit: int = min(baseline.size(), current.size())
	for i in limit:
		if baseline[i] != current[i]:
			fail_test("first divergence at event %d of %d\n  baseline: %s\n  current:  %s" % [i, limit, baseline[i], current[i]])
			return
	assert_eq(current.size(), baseline.size(), "event COUNT changed (streams agree up to event %d) -- P29 must not add, drop or reorder events for single-action families" % limit)
	if current.size() == baseline.size():
		pass_test("%d events byte-identical after normalization" % current.size())


## The allow-list is a CONTRACT, not a convenience. If a future change widens it, this
## test fails and forces the widening to be a deliberate, reviewed decision rather than
## a quiet edit that makes the gate above go green again.
func test_additive_key_allowlist_is_exactly_the_ruled_contract() -> void:
	assert_eq(AiBaselineScenario.ADDITIVE_KEY_ALLOWLIST.size(), 1, "exactly one event kind may gain a key")
	assert_true(AiBaselineScenario.ADDITIVE_KEY_ALLOWLIST.has("attack_telegraph"))
	assert_eq(AiBaselineScenario.ADDITIVE_KEY_ALLOWLIST["attack_telegraph"], ["action_id"])


## Guards the fixture itself: a baseline that never reaches the reaction layer would
## pass forever while proving nothing about the branches P29 actually touches. These are
## the kinds the scenario was tuned to produce (verified against the recording).
func test_baseline_exercises_the_branches_p29_can_disturb() -> void:
	var baseline: Array = _load_baseline()
	var kinds: Dictionary = {}
	for entry in baseline:
		kinds[String(entry).split("|")[1]] = true
	for required in ["moved", "melee_swing", "hit", "attack_telegraph", "attack_rejected", "flinched", "windup_interrupted", "died", "projectile_fired", "weapon_switched"]:
		assert_true(kinds.has(required), "baseline must exercise '%s' -- otherwise the gate cannot see a regression in it" % required)
