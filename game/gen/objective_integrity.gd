class_name ObjectiveIntegrity
extends RefCounted
## DECLARED PROGRESSION, PROVED ON THE COMPOSED FLOOR (ADR-001 S3b).
##
## A recipe node may declare itself MANDATORY or OPTIONAL (FloorRecipe.PROGRESSION_*). This class
## turns each declaration into integrity questions about the floor that was actually composed --
## the emitted ids, the placed footprints -- and asks ProgressionValidator.check_objective each one:
##
##   MANDATORY node   its ground withheld: no route to completion.
##                    each of its MANDATORY fights never cleared: no route.
##                    each of its keys never lifted: no route.
##                    each of its receivers never fed: no route.
##   OPTIONAL node    its ground is reachable (so the next claim is not vacuous), and
##                    with its ground withheld the floor is still completed.
##
## Undeclared nodes claim nothing, and an ambient roster inside a mandatory node is never made a
## required kill: only an encounter whose own role is mandatory is asked about. The entry is never
## asked about its ground -- every route starts on it.
##
## SOLVABILITY IS SEPARATE. `baseline` is the ordinary ProgressionValidator.check; the claims
## answer a different question and are read alongside it, never folded into it.

const KIND_GROUND: StringName = &"ground"
const KIND_REACH: StringName = &"reach"
const KIND_CLEAR: StringName = &"clear"
const KIND_LIFT: StringName = &"lift"
const KIND_DELIVER: StringName = &"deliver"

const OUTCOME_PASS: StringName = &"pass"
const OUTCOME_FAIL: StringName = &"fail"
const OUTCOME_UNSUPPORTED: StringName = &"unsupported"


## One integrity question and its answer. `expected` is the verdict the declaration promises.
class Claim:
	extends RefCounted
	var node: StringName = &""
	var declared: StringName = &""
	var kind: StringName = &""
	var record_id: int = -1
	var expected: StringName = &""
	var result: ProgressionValidator.ObjectiveResult = null

	func holds() -> bool:
		return result != null and result.verdict == expected

	## The declaration is contradicted outright (as opposed to left undecided by the model).
	func broken() -> bool:
		return result != null and result.verdict != expected and result.verdict != ProgressionValidator.ObjectiveResult.UNSUPPORTED

	func describe() -> String:
		var what: String = String(kind) if record_id < 0 else "%s %d" % [kind, record_id]
		return "%s %s / %s: expected %s, got %s" % [declared, node, what, expected, result.summary() if result != null else "nothing"]


class Report:
	extends RefCounted
	var outcome: StringName = OUTCOME_UNSUPPORTED
	var baseline: ProgressionReport = null
	var claims: Array = []  # Array[Claim]

	func broken_claims() -> Array:
		return claims.filter(func(claim: Claim) -> bool: return claim.broken())

	func claims_of(kind: StringName) -> Array:
		return claims.filter(func(claim: Claim) -> bool: return claim.kind == kind)

	func summary() -> String:
		var lines: PackedStringArray = ["objective integrity: %s (%d claims; baseline %s)" % [String(outcome).to_upper(), claims.size(), String(baseline.outcome).to_upper() if baseline != null else "none"]]
		for claim: Claim in claims:
			if not claim.holds():
				lines.append("  " + claim.describe())
		return "\n".join(lines)


static func check(recipe: FloorRecipe, composed: FloorComposer.ComposeResult, plan: FloorPlan, rules: Dictionary) -> Report:
	var report := Report.new()
	report.baseline = ProgressionValidator.check(plan, rules)
	if composed == null or composed.draft == null or composed.emit == null:
		return report  # a fallback floor has no nodes to hold to their declarations
	var session := ProgressionValidator.ObjectiveSession.new(plan, rules)
	for index: int in recipe.nodes.size():
		var node: Dictionary = recipe.nodes[index]
		var declared: StringName = node.get("progression", &"")
		if declared == &"":
			continue
		var instance: FloorDraft.PieceInstance = composed.draft.instances[index]
		var footprint: Rect2 = FloorDraft.world_footprint(instance)
		if declared == FloorRecipe.PROGRESSION_OPTIONAL:
			report.claims.append(_ask(session, node, declared, KIND_REACH, -1, {}, {ProgressionValidator.GOAL_ENTER: footprint}, ProgressionValidator.ObjectiveResult.ROUTE_FOUND))
			report.claims.append(_ask(session, node, declared, KIND_GROUND, -1, {ProgressionValidator.FORBID_GROUND: [footprint]}, {}, ProgressionValidator.ObjectiveResult.ROUTE_FOUND))
			continue
		var none: StringName = ProgressionValidator.ObjectiveResult.ROUTE_NONE
		if index > 0:
			report.claims.append(_ask(session, node, declared, KIND_GROUND, -1, {ProgressionValidator.FORBID_GROUND: [footprint]}, {}, none))
		for site: EncounterSite in instance.piece.body.encounters:
			if site.role == FloorLayers.ROLE_MANDATORY:
				var id: int = composed.emit.global_id(instance.instance_id, &"encounter", site.encounter_id)
				report.claims.append(_ask(session, node, declared, KIND_CLEAR, id, {ProgressionValidator.FORBID_CLEAR: [id]}, {}, none))
		for carriable: CarriablePlan in instance.piece.body.carriables:
			var id: int = composed.emit.global_id(instance.instance_id, &"carriable", carriable.carriable_id)
			report.claims.append(_ask(session, node, declared, KIND_LIFT, id, {ProgressionValidator.FORBID_LIFT: [id]}, {}, none))
		for trigger: FloorTrigger in instance.piece.body.triggers:
			if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
				var id: int = composed.emit.global_id(instance.instance_id, &"trigger", trigger.trigger_id)
				report.claims.append(_ask(session, node, declared, KIND_DELIVER, id, {ProgressionValidator.FORBID_DELIVER: [id]}, {}, none))
	report.outcome = _outcome(report)
	return report


static func _ask(session: ProgressionValidator.ObjectiveSession, node: Dictionary, declared: StringName, kind: StringName, record_id: int,
		forbidden: Dictionary, goal: Dictionary, expected: StringName) -> Claim:
	var claim := Claim.new()
	claim.node = node.get("key", &"")
	claim.declared = declared
	claim.kind = kind
	claim.record_id = record_id
	claim.expected = expected
	claim.result = session.ask(forbidden, goal)
	return claim


## FAIL when the floor cannot be finished or a declaration is contradicted outright; UNSUPPORTED
## when the model could not decide something; PASS only when every claim holds on a solvable floor.
static func _outcome(report: Report) -> StringName:
	if report.baseline.outcome == ProgressionReport.OUTCOME_FAIL or not report.broken_claims().is_empty():
		return OUTCOME_FAIL
	if report.baseline.outcome == ProgressionReport.OUTCOME_UNSUPPORTED:
		return OUTCOME_UNSUPPORTED
	for claim: Claim in report.claims:
		if not claim.holds():
			return OUTCOME_UNSUPPORTED
	return OUTCOME_PASS
