extends GutTest
## THE ACTIVE GATE on the shared locomotion/decision path (P17 baseline split).
##
## ARTIFACT RETIRED AND RE-RECORDED 2026-08-31, per the instruction at the foot of this header.
##
## The original premise was: "Ooze is named here for one reason and it must stay true -- no
## family-identity work touches it." THAT PREMISE IS NOW FALSE. The cardinal-pursuit ruling
## authored CARDINAL_COMMITTED onto Ooze specifically, so the family chosen for being untouched
## became the family under active identity development. The pre-cardinal stream is preserved as
## `ai_canary_ooze_pre_cardinal.json` -- evidence, never overwritten -- and this artifact holds
## the post-cardinal recording.
##
## WHAT IT STILL GUARDS: drift in the shared machinery of `_decide_single_ai_command` /
## `_apply_move`, which is the real job. What it no longer guarantees is that a red result means
## SHARED drift rather than intended Ooze work.
##
## FLAGGED FOR RULING, not decided here: a canary belongs on a family identity work does not
## touch, and Watcher is the only one left that qualifies. Relocating the guard is a judgement
## about what it should watch, so it is recorded rather than taken unilaterally.
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
