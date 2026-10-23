class_name ProgressionReport
extends RefCounted
## WHAT THE PROGRESSION VALIDATOR CONCLUDED ABOUT ONE FloorPlan (ADR-001 S0).
##
## THREE OUTCOMES, NEVER BLURRED:
##   PASS         the exit is reachable from arrival using only SUPPORTED actions, and from every
##                state the supported actions can reach, the exit stays reachable (no softlock).
##                Still conditional on the listed `assumptions` (a fight the floor asks for is
##                assumed winnable -- combat is design, not progression), stated, never silent.
##   FAIL         the supported model found the exit unreachable, or a reachable state from which
##                it can never be reached again -- and no relaxation the model knows of helps.
##   UNSUPPORTED  the answer depends on something the model deliberately does not establish
##                (a switch that could only be shot, a state budget exhausted, an effect kind it
##                does not know). Reported as the limitation it is, never rounded to PASS.
##
## Plain data with a to_dict(): a generator rejecting a candidate reads `outcome`; a human reads
## summary(); a test reads `findings` by kind.

const OUTCOME_PASS: StringName = &"pass"
const OUTCOME_FAIL: StringName = &"fail"
const OUTCOME_UNSUPPORTED: StringName = &"unsupported"

const SEVERITY_FAIL: StringName = &"fail"
const SEVERITY_UNSUPPORTED: StringName = &"unsupported"
const SEVERITY_INFO: StringName = &"info"

var outcome: StringName = OUTCOME_UNSUPPORTED
## [{kind, severity, message, refs: {layer: id}, trace: [String]}], most severe first.
var findings: Array[Dictionary] = []
## What a PASS is conditional on, in words a human can check ("encounter 3 cleared by combat").
var assumptions: Array[String] = []
## What the model never establishes, whatever the outcome -- so a PASS is read for what it is.
var limitations: Array[String] = []
## The supported actions, in order, that reach the exit (empty unless some path was found).
var trace: Array[String] = []
var states_explored: int = 0
## Records the model left out because nothing about progression depends on them -- a decorative
## prop, an unwatched optional fight -- by layer: {layer: [ids]}. Listed so "ignored" is visible.
var ignored: Dictionary = {}


func is_pass() -> bool:
	return outcome == OUTCOME_PASS


func findings_of(kind: StringName) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for finding in findings:
		if finding["kind"] == kind:
			matched.append(finding)
	return matched


func add_finding(kind: StringName, severity: StringName, message: String, refs: Dictionary = {}, action_trace: Array[String] = []) -> void:
	findings.append({"kind": kind, "severity": severity, "message": message, "refs": refs, "trace": action_trace})


## One readable block: the verdict line, then every finding with its references.
func summary() -> String:
	var lines: PackedStringArray = []
	var verdict: String = String(outcome).to_upper()
	if outcome == OUTCOME_PASS and not assumptions.is_empty():
		verdict += " (assuming %d)" % assumptions.size()
	lines.append("progression: %s after %d states, %d step(s) to the exit" % [verdict, states_explored, trace.size()])
	for finding in findings:
		lines.append("  [%s] %s: %s %s" % [finding["severity"], finding["kind"], finding["message"], _refs_text(finding["refs"])])
	for assumption in assumptions:
		lines.append("  assuming: " + assumption)
	for limitation in limitations:
		lines.append("  not modelled: " + limitation)
	var layers: Array = ignored.keys()
	layers.sort()
	for layer in layers:
		lines.append("  progression-neutral %s ignored: %s" % [layer, str(ignored[layer])])
	return "\n".join(lines)


func to_dict() -> Dictionary:
	return {
		"outcome": String(outcome), "findings": findings.duplicate(true),
		"assumptions": assumptions.duplicate(), "limitations": limitations.duplicate(),
		"trace": trace.duplicate(), "states_explored": states_explored, "ignored": ignored.duplicate(true),
	}


static func _refs_text(refs: Dictionary) -> String:
	if refs.is_empty():
		return ""
	var parts: PackedStringArray = []
	var keys: Array = refs.keys()
	keys.sort()
	for key in keys:
		parts.append("%s %s" % [key, str(refs[key])])
	return "(" + ", ".join(parts) + ")"
