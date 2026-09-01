extends GutTest
## THE ACTIVE GATE on the shared locomotion/decision path (P17 baseline split).
##
## Ooze is named here for one reason and it must stay true: **no family-identity work
## touches it.** P17's approach weave was authored on Fang alone and has since been reverted
## as falsified; Ooze was unaffected throughout, in both directions. So any drift this test
## reports came from the shared machinery in `_decide_single_ai_command` / `_apply_move`,
## never from an intended content change -- which is exactly what a canary is for, and why
## the gate sits on an explicitly unaffected family rather than on one that moves.
##
## RETIRED, THEN RESTORED (2026-08-31 -> 2026-09-01). Cardinal pursuit was briefly authored onto
## Ooze, which falsified the premise above, so this artifact was retired to
## `ai_canary_ooze_pre_cardinal.json` and re-recorded per the instruction at the foot of this
## header. That implementation was then REVERTED as unauthorized, so Ooze returned to pre-cardinal
## behaviour and this artifact is the pre-cardinal stream once more. The retired copy is KEPT as
## evidence rather than deleted: it records that the retirement happened and why, which a silent
## restore would erase. The premise holds again -- but narrowly, since cardinal steering is still
## a live design candidate and would require the same treatment if authorized.
##
## NO FAMILY CURRENTLY QUALIFIES AS AN UNTOUCHED CANARY, recorded honestly rather than
## manufactured: Fang carries burrow, and P33 authored `avoid_commit_ticks = 45` onto BOTH Ooze
## and Watcher, so local avoidance is live for them. Zeroing Watcher's purely to create a clean
## canary was considered and REJECTED -- changing shipped content to manufacture an invariant is
## worse than admitting the invariant is unavailable.
##
## THIS OUTLIVED THE MECHANIC THAT PROMPTED IT, deliberately. The three-artifact discipline
## is preserved independently of P17's verdict: the shared locomotion path still needs an
## honest gate, and Fang will move again when P17's successor lands.
##
## THE CONTRACT: byte-identical, with NO additive-key allow-list. The P29 baseline needed
## one because P29 was mid-flight when it was recorded; this artifact was recorded against
## the behaviour it governs, so any difference at all is a regression requiring explanation
## — never a normalization exception, and never a re-record.
##
## IF THIS TEST GOES RED AND THE CHANGE WAS INTENDED: retire this artifact to evidence and
## record a new dated one. Do not overwrite it.

const CANARY_PATH: String = "res://tests/fixtures/ai_canary_ooze.json"


func _load() -> Array:
	var file := FileAccess.open(CANARY_PATH, FileAccess.READ)
	assert_not_null(file, "canary fixture missing at %s -- regenerate with tools/record_family_locomotion.gd" % CANARY_PATH)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Array, "canary fixture must be a JSON array")
	return parsed if parsed is Array else []


func test_ooze_locomotion_is_unchanged() -> void:
	var expected: Array = _load()
	assert_gt(expected.size(), 0, "sanity: the canary must not be empty")

	var current: Array = FamilyLocomotionScenario.run(&"ooze")

	# Report the FIRST divergence with its index rather than only a size mismatch: a stream
	# that diverges at event 40 and one that diverges at event 240 are very different bugs,
	# and "arrays differ" names neither.
	var limit: int = min(expected.size(), current.size())
	for i in limit:
		if expected[i] != current[i]:
			fail_test("first divergence at event %d of %d\n  canary:  %s\n  current: %s" % [i, limit, expected[i], current[i]])
			return
	assert_eq(current.size(), expected.size(), "event COUNT changed (streams agree up to event %d) -- the shared locomotion/decision path must not add, drop or reorder events for an unaffected family" % limit)
	if current.size() == expected.size():
		pass_test("%d events byte-identical" % current.size())


## THE CANARY MUST BE REAL. A fixture that never reaches the branches it is supposed to
## protect would pass forever while proving nothing -- the "convenience-zeroed defenses"
## failure. These kinds are verified against the recording, not assumed.
func test_canary_actually_exercises_the_shared_path() -> void:
	var expected: Array = _load()
	var kinds: Dictionary = {}
	var moved_ticks: Dictionary = {}
	for entry in expected:
		var parts: PackedStringArray = String(entry).split("|")
		kinds[parts[1]] = true
		if parts[1] == "moved" and parts[2].contains("actor_id=%d" % FamilyLocomotionScenario.ENEMY_ID):
			moved_ticks[parts[0]] = true
	for required in ["moved", "attack_telegraph", "hit", "melee_swing"]:
		assert_true(kinds.has(required), "canary must exercise '%s' -- otherwise it cannot see a regression in it" % required)
	assert_gt(moved_ticks.size(), 30, "the canary must contain a substantial ENEMY approach, or it is not gating locomotion at all")
