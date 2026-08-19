extends GutTest
## RETIRED — `tests/fixtures/ai_baseline_p17_fang.json` is EXPERIMENT EVIDENCE.
## Falsified 2026-08-19. It no longer gates anything.
##
## WHAT IT WAS. Recorded 2026-08-18 as the governing baseline for Fang's P17 approach
## weave, immediately after that mechanic shipped.
##
## WHY ITS GATING AUTHORITY ENDED — the playtest falsified the hypothesis, verdict ITERATE:
##   * Q2 (the finding under test) FAILED: "same approach with wobble". The weave changed
##     the geometry of the approach without changing the encounter.
##   * Q5 FAILED: wand tracking unchanged — the player's problem was not altered.
##   * Q1 readable but repetitive · Q3 release hinge PASS · Q4 facing acceptable ·
##     Q6 opener PASS · Q7 unanswered, carried to the successor design.
## A falsified mechanic does not stay in live code merely because it is tested, so the
## weave was reverted: sim expression, all four Fang content fields, and its test file.
##
## WHY THE ARTIFACT SURVIVES ANYWAY. It is the only record of what the falsified mechanic
## actually did — the "after" of an experiment whose "before" is `ai_baseline_pre_p29.json`.
## Deleting it would leave the ROADMAP verdict as an unbacked assertion. BRAIN: "Never
## rewrite yesterday's baseline to describe today — retire its gating role, preserve its
## evidence role. A historical fixture's value is proving what changed." That rule applied
## when the weave landed; it applies identically now that it has been withdrawn. Retiring a
## baseline is not a punishment for a mechanic failing, it is what baselines are for.
##
## FIXTURE ROLES AFTER THE REVERT (all three files byte-untouched):
##   1. `ai_baseline_pre_p29.json` — historical evidence, AND once again a description of
##      Fang's LIVE behaviour, since the revert restored the straight approach.
##   2. `ai_canary_ooze.json` — unchanged, still the ACTIVE gate on the shared path.
##   3. THIS artifact — experiment evidence only. Nothing gates against it.
##
## WHAT THIS FILE STILL DOES: proves the evidence exists and still shows the weave, so the
## verdict above stays backed by something. It never compares against live behaviour --
## that is precisely the authority that was retired, and live Fang no longer weaves at all.

const EVIDENCE_PATH: String = "res://tests/fixtures/ai_baseline_p17_fang.json"
const FALSIFIED_ON: String = "2026-08-19"


func _load() -> Array:
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.READ)
	assert_not_null(file, "EXPERIMENT EVIDENCE MISSING at %s -- preserved deliberately (falsified %s); it is the only record of what the weave did" % [EVIDENCE_PATH, FALSIFIED_ON])
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Array, "evidence fixture must still be a JSON array")
	return parsed if parsed is Array else []


func test_weave_experiment_evidence_is_preserved_intact() -> void:
	var evidence: Array = _load()
	assert_gt(evidence.size(), 0, "the preserved experiment evidence must not be empty")
	for entry in evidence:
		assert_true(entry is String, "every evidence row is a serialized event string")


## The evidence must still SHOW the falsified behaviour, or it backs nothing. A statement
## about the file only -- never a comparison against live Fang, which is straight again.
func test_evidence_still_shows_the_woven_approach_that_was_falsified() -> void:
	var evidence: Array = _load()
	var max_lateral: float = 0.0
	var sign_changes: int = 0
	var previous_sign: int = 0
	for entry in evidence:
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
	assert_gt(max_lateral, 0.1, "the evidence must still record the weave's lateral displacement")
	assert_gt(sign_changes, 0, "...and its centre crossings -- otherwise it does not evidence a zig-zag at all")


## THE REVERT, asserted from the other side: Fang must no longer author a weave. If this
## ever fails, either the revert regressed or a successor mechanic landed without updating
## the record above -- both are things a future session must be told about loudly.
func test_live_fang_no_longer_authors_the_falsified_mechanic() -> void:
	var stats: Resource = ContentDB.get_resource(&"enemy", &"fang")
	for field in ["approach_weave_degrees", "approach_weave_period_ticks", "approach_weave_release_distance", "approach_weave_phase_stride_ticks"]:
		assert_false(field in stats, "FangStats must no longer carry '%s' -- the falsified mechanic was reverted on %s" % [field, FALSIFIED_ON])
