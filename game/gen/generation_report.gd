class_name GenerationReport
extends RefCounted
## WHAT ONE COMPOSITION DID, AND WHY (ADR-001 §5.6, owner ruling O2; S2).
##
## OUTSIDE FloorPlan.to_dict() BY RULING: diagnostics describe the generation, not the floor,
## so a golden never changes because a counter did. Associated with its result by the caller
## (ComposeResult holds both); a static "last report" is a debug convenience only.
##
## COUNTS, NOT CLAIMS. A fallback is a fallback, recorded apart from a success and never added
## to one; a structural failure (an emitter or validator refusing the composed floor) is a
## separate flag from a search that merely ran out of positions. Elapsed time is measured for
## the §5 M2 gate and reported; nothing in the composer branches on it.

var recipe_id: StringName = &""
var floor_seed: int = 0
var depth: int = 0
## Attempts made (1 = the first seed sufficed); the attempt that produced the result.
var attempts: int = 0
## Accepted placements across all attempts, undone ones included (the budget's own count).
var placements: int = 0
## Frames popped (a node with nowhere to go, its parent's placement undone).
var backtracks: int = 0
## Placements undone because a closing edge could not be routed from them.
var retries: int = 0
## reason -> count, across all attempts.
var rejections: Dictionary = {}
var fallback: bool = false
var structural: bool = false
var failing_validator: String = ""
## node key -> {piece_id, transform, origin}
var cast: Dictionary = {}
## edge "from>to" -> {profile, shape, legs: Array[float], length}
var routes: Dictionary = {}
var extent: Rect2 = Rect2()
var elapsed_usec: int = 0
var log: PackedStringArray = []


func succeeded() -> bool:
	return not fallback and not structural


func reject(reason: StringName) -> void:
	rejections[reason] = int(rejections.get(reason, 0)) + 1


func note(line: String) -> void:
	log.append(line)


## A stable description of the arrangement: which piece stands where under which transform, and
## the shape and length of every route. Two seeds that differ only here differ in arrangement.
func spatial_signature() -> String:
	var parts: PackedStringArray = []
	var keys: Array = cast.keys()
	keys.sort()
	for key: StringName in keys:
		var placed: Dictionary = cast[key]
		parts.append("%s=%s/%s@%s" % [key, placed["piece_id"], placed["transform"], placed["origin"]])
	var edge_keys: Array = routes.keys()
	edge_keys.sort()
	for key: String in edge_keys:
		var route: Dictionary = routes[key]
		parts.append("%s:%s%s" % [key, route["shape"], route["legs"]])
	return " ".join(parts)


func summary() -> String:
	var head: String = "gen %s seed %d depth %d: %s after %d attempt(s), %d placement(s), %d retr(y/ies), %d backtrack(s), %.2f ms" % [
		recipe_id, floor_seed, depth,
		"FALLBACK" if fallback else ("STRUCTURAL FAILURE" if structural else "composed"),
		attempts, placements, retries, backtracks, elapsed_usec / 1000.0]
	var lines: PackedStringArray = [head]
	if failing_validator != "":
		lines.append("  failing validator: " + failing_validator)
	if not rejections.is_empty():
		var reasons: Array = rejections.keys()
		reasons.sort()
		var counted: PackedStringArray = []
		for reason: StringName in reasons:
			counted.append("%s=%d" % [reason, rejections[reason]])
		lines.append("  rejections: " + ", ".join(counted))
	return "\n".join(lines)


func to_dict() -> Dictionary:
	return {
		"recipe_id": String(recipe_id), "floor_seed": floor_seed, "depth": depth, "attempts": attempts,
		"placements": placements, "retries": retries, "backtracks": backtracks, "rejections": rejections.duplicate(),
		"fallback": fallback, "structural": structural, "failing_validator": failing_validator,
		"cast": cast.duplicate(true), "routes": routes.duplicate(true),
		"extent": {"x": extent.position.x, "z": extent.position.y, "w": extent.size.x, "d": extent.size.y},
		"elapsed_usec": elapsed_usec, "signature": spatial_signature(),
	}
