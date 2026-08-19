extends GutTest
## THE NEW GOVERNING BASELINE for Fang (P17 baseline split, recorded 2026-08-18).
##
## Created only AFTER the approved P17 approach weave existed — a baseline recorded before
## the behaviour it governs would be a prediction, not a record. It supersedes nothing by
## overwriting: `tests/fixtures/ai_baseline_pre_p29.json` still holds Fang's pre-P17
## straight-line approach as frozen evidence, and this fixture is the "after" half of
## "prove what changed".
##
## THE CONTRACT: byte-identical, NO additive-key allow-list. Any difference is a regression
## requiring explanation. When Fang's motion path next changes lawfully, retire this
## artifact to evidence and record a new dated one — do not re-record this file.

const BASELINE_PATH: String = "res://tests/fixtures/ai_baseline_p17_fang.json"


func _load() -> Array:
	var file := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	assert_not_null(file, "baseline missing at %s -- regenerate with tools/record_family_locomotion.gd" % BASELINE_PATH)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Array, "baseline must be a JSON array")
	return parsed if parsed is Array else []


func test_fang_locomotion_matches_the_p17_baseline() -> void:
	var expected: Array = _load()
	assert_gt(expected.size(), 0, "sanity: the baseline must not be empty")

	var current: Array = FamilyLocomotionScenario.run(&"fang")

	var limit: int = min(expected.size(), current.size())
	for i in limit:
		if expected[i] != current[i]:
			fail_test("first divergence at event %d of %d\n  baseline: %s\n  current:  %s" % [i, limit, expected[i], current[i]])
			return
	assert_eq(current.size(), expected.size(), "event COUNT changed (streams agree up to event %d)" % limit)
	if current.size() == expected.size():
		pass_test("%d events byte-identical" % current.size())


## THE POINT OF THE SPLIT, made assertable. The retired artifact records a Fang approach
## with zero lateral offset; this one must record the opposite. If this ever passes with a
## straight path, the weave silently stopped working and the baseline would happily go on
## "proving" nothing.
func test_baseline_records_a_genuinely_woven_approach() -> void:
	var expected: Array = _load()
	var max_lateral: float = 0.0
	var sign_changes: int = 0
	var previous_sign: int = 0
	for entry in expected:
		var row: String = String(entry)
		if not row.contains("|moved|") or not row.contains("actor_id=%d" % FamilyLocomotionScenario.ENEMY_ID):
			continue
		var x: float = float(row.split("position=(")[1].trim_suffix(")").split(",")[0])
		max_lateral = maxf(max_lateral, absf(x))
		var current_sign: int = signi(int(roundf(x * 1000.0)))
		if current_sign != 0 and previous_sign != 0 and current_sign != previous_sign:
			sign_changes += 1
		if current_sign != 0:
			previous_sign = current_sign
	assert_gt(max_lateral, 0.1, "the P17 baseline must record real lateral displacement -- a straight path means the weave is not in the recording")
	assert_gt(sign_changes, 0, "the path must cross the centre line -- a one-sided offset is a drift, not a zig-zag")


## Fang's premise for this artifact, asserted rather than trusted.
func test_fang_authors_the_approach_weave() -> void:
	var stats: Resource = ContentDB.get_resource(&"enemy", &"fang")
	assert_gt(stats.approach_weave_degrees, 0.0, "this baseline governs Fang's WOVEN approach -- it is meaningless if the content stops authoring one")
	assert_gt(stats.approach_weave_phase_stride_ticks, 0, "GAME-RULES §3 binding consequence: globally-phased family motion needs a per-actor offset")
