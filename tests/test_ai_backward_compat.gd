extends GutTest
## RETIRED GATE — `tests/fixtures/ai_baseline_pre_p29.json` is now HISTORICAL EVIDENCE.
##
## WHAT IT WAS. From P29 until 2026-08-18 this file ran the recorded pre-P29 stream against
## live behaviour and required byte-identity after normalization: the M1-preservation gate
## for the single-action families (Fang and Ooze).
##
## WHY ITS GATING AUTHORITY ENDED. P17 gave Fang an authored approach weave — a lawful,
## dated behaviour change under GAME-RULES §3's amended channel law (families own baseline
## motion PATH). The fixture records Fang's per-tick positions, so the comparison could only
## be kept alive one of two ways, and both are forbidden:
##
##   * RE-RECORD IT. Procedurally legal ("a deliberate, dated behaviour change"), and it
##     destroys the artifact's whole point. BRAIN: "Never rewrite yesterday's baseline to
##     describe today — retire its gating role, preserve its evidence role. A historical
##     fixture's value is proving what changed."
##   * COMPARE ONLY ITS OOZE ROWS. That leaves one artifact whose authority varies by row —
##     half-retired, and unreadable to anyone who finds it later.
##
## WHAT REPLACED IT (the three-artifact split, one job each):
##   1. THIS artifact — frozen byte-for-byte, evidence of pre-P29 behaviour. Never
##      re-recorded, and `tools/record_ai_baseline.gd` remains the only thing that ever
##      could; `tools/record_family_locomotion.gd` deliberately cannot write it.
##   2. `tests/test_ai_canary_ooze.gd` — the ACTIVE gate on the shared locomotion/decision
##      path, carried by a family P17 explicitly does not touch.
##   3. `tests/test_ai_baseline_p17_fang.gd` — the governing baseline for Fang under the
##      weave; itself retired to EXPERIMENT EVIDENCE on 2026-08-19 when the playtest
##      falsified the mechanic and it was reverted.
##
## ROLE UPDATE, 2026-08-19 (the weave revert). This artifact now holds TWO roles at once,
## which is worth stating precisely because the whole point of the split was that no
## artifact should:
##   * HISTORICAL EVIDENCE — unchanged, permanent, the "before" of the P17 experiment.
##   * AND, incidentally, an accurate description of Fang's LIVE behaviour again, because
##     the revert restored the straight approach it recorded.
## The second is a FACT, not a restored authority. Gating stays with the Ooze canary. A
## fixture does not silently reacquire gating power because the world happened to move back
## toward it — re-blessing in reverse is still re-blessing, and the next lawful Fang change
## would quietly break a gate nobody deliberately re-armed.
##
## WHAT THIS FILE STILL DOES. Exactly one job: prove the evidence still exists, intact and
## parseable, and still contains what it claims to. An artifact silently deleted or
## truncated is an artifact that was never preserved.

const BASELINE_PATH: String = "res://tests/fixtures/ai_baseline_pre_p29.json"


func _load_baseline() -> Array:
	var file := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	assert_not_null(file, "HISTORICAL EVIDENCE MISSING at %s -- this artifact is preserved deliberately and must never be deleted (BRAIN: retire the gating role, preserve the evidence role)" % BASELINE_PATH)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Array, "evidence fixture must still be a JSON array")
	return parsed if parsed is Array else []


func test_pre_p29_evidence_is_preserved_intact() -> void:
	var baseline: Array = _load_baseline()
	assert_gt(baseline.size(), 0, "the preserved evidence must not be empty")
	for entry in baseline:
		assert_true(entry is String, "every evidence row is a serialized event string")


## The evidence is only worth preserving if it still shows what pre-P29 behaviour looked
## like across the branches it was recorded to cover. This is a statement ABOUT THE FILE,
## never a comparison against live behaviour -- that is precisely the authority that was
## retired.
func test_pre_p29_evidence_still_shows_the_branches_it_was_recorded_for() -> void:
	var baseline: Array = _load_baseline()
	var kinds: Dictionary = {}
	for entry in baseline:
		kinds[String(entry).split("|")[1]] = true
	for required in ["moved", "melee_swing", "hit", "attack_telegraph", "attack_rejected", "flinched", "windup_interrupted", "died", "projectile_fired", "weapon_switched"]:
		assert_true(kinds.has(required), "evidence must still contain '%s' -- a truncated record proves nothing about what changed" % required)


## Fang's pre-P29 APPROACH was a straight line. Keeping that specific fact assertable is
## what makes this artifact EVIDENCE rather than a museum piece: it is the "before" half of
## "prove what changed", and P17's whole claim is that this line is no longer straight.
##
## Scoped to the pure approach window (ticks 0-17, before the recorded player throws its
## first attack at tick 18). Past that point the recording legitimately contains lateral
## motion from knockback and from the player's own diagonal movement — first appearing at
## tick 66 — which says nothing about the enemy's authored path. Asserting over the whole
## stream would fail on displacement that was never locomotion.
const APPROACH_WINDOW_END_TICK: int = 18

func test_pre_p29_evidence_records_a_straight_fang_approach() -> void:
	var baseline: Array = _load_baseline()
	var samples: int = 0
	for entry in baseline:
		var row: String = String(entry)
		if not row.contains("|moved|") or not row.contains("actor_id=1"):
			continue
		if int(row.split("|")[0]) >= APPROACH_WINDOW_END_TICK:
			continue
		samples += 1
		var lateral: float = float(row.split("position=(")[1].trim_suffix(")").split(",")[0])
		assert_almost_eq(lateral, 0.0, 0.0001, "pre-P29 Fang approached with zero lateral offset -- this is the recorded 'before' that P17's weave is measured against")
	assert_gt(samples, 10, "the approach window must actually contain Fang movement rows, or this proves nothing")
