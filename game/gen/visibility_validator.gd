class_name VisibilityValidator
extends RefCounted
## CAN THE PLAYER SEE IT FROM WHERE THEY ACTUALLY STAND? (ADR-001 §5.4, S4.)
##
## A recipe declares VISIBILITY edges, {from, from_port, to, to_port, intent, mandatory, door_port}:
## from a `vantage` port of one placed piece to an `anchor` port of another (or the same). Both are
## author-declared points; the generator never searches for standing points. The camera is the
## shared CameraFraming (O1): placed exactly where FollowCamera would put it for an Envoy on the
## vantage, edge stop included, projected with the real perspective.
##
## A LOOK is a five-point cross around the anchor (the lock face of a door is a vertical cross along
## the door's line; any other anchor a flat one). A point is SEEN when it is in front of the camera,
## inside the safe band, and the straight line to it crosses no rendered occluder: wall boxes from
## every solid segment, obstacle boxes, and every closed gate except the one the anchor shows. The
## occluders are FloorBuilder's own dimensions (test-pinned), so this is a check against the opaque
## mass the player sees, not against screen coordinates alone. Breakables ARE occluders, intact,
## as the player meets them on arrival (owner review, 2026-10-28): a reveal that only works once
## an urn is smashed is not a reveal.
##
## INTENT. `reveal` holds when the anchor is seen; `conceal` holds when it is not -- a destination the
## fold is meant to hide is a declared fact too, checked, never inferred from unreachability.
##
## MANDATORY ONLY WHEN ENFORCEABLE (§5.4, corrected). A declared-mandatory reveal rejects a floor
## only when the progression validator confirms the relationship that makes it a reveal: the anchor
## shows a LOCKED DOOR (`door_port`, opened only by key receivers), the vantage is reachable with the
## key never delivered, and the ground beyond the door is not. An unreachable destination is never,
## by itself, a reason for anything to be visible.
##
## AN INVALID DECLARATION IS NEVER QUIETLY OPTIONAL (owner review, 2026-10-28). What a piece can
## know -- the vantage and anchor ports exist, the door port is a gate, only key receivers open it
## -- is checked by FloorRecipe.lint() through `declaration_fault` for every piece the node can cast,
## so a recipe that declares an impossible mandatory reveal never composes (structural fallback).
## What only a placed floor can know -- the vantage reachable with the key withheld, the ground
## beyond shut away -- is asked here; an unenforceable result is reported, and certification (the
## sweep's verdict) FAILS on it rather than counting it as an optional reveal.
##
## WHEN THE QUESTIONS ARE ASKED. The relationship only decides whether an UNHELD reveal rejects; a
## reveal that holds rejects nothing either way. So `ENFORCE_WHEN_UNHELD` (the composer) asks them
## only for a declared-mandatory edge that does not hold -- the same rejection, without paying for a
## progression model on every passing floor -- and `ENFORCE_ALWAYS` (certification, the sweep) asks
## them for every declared-mandatory edge so the report can say the relationship was confirmed.

const INTENT_REVEAL: StringName = &"reveal"
const INTENT_CONCEAL: StringName = &"conceal"
const INTENTS: Array[StringName] = [INTENT_REVEAL, INTENT_CONCEAL]

const VERDICT_SEEN: StringName = &"seen"
const VERDICT_UNSEEN: StringName = &"unseen"
## The edge could not be evaluated on this floor (a port the cast piece lacks, ground nobody can
## stand on). A mandatory edge in this state rejects like an unseen one.
const VERDICT_ERROR: StringName = &"error"

const ENFORCE_WHEN_UNHELD: StringName = &"when_unheld"
const ENFORCE_ALWAYS: StringName = &"always"

const _OPENERS: Array[StringName] = [FloorLayers.EFFECT_OPEN_CONNECTION, FloorLayers.EFFECT_TOGGLE_CONNECTION]

## The ground box the reachability question asks the Envoy to stand in, around the vantage.
const _VANTAGE_HALF: float = 0.5


## One look from one standing point at one target.
class Sight:
	extends RefCounted
	var camera: Vector3 = Vector3.ZERO
	var screen: Vector2 = Vector2.ZERO
	var centre_seen: bool = false
	var seen_points: int = 0
	var points: int = 0
	## Why each unseen point is unseen: "behind", "off-band", or the occluder that cut it.
	var misses: PackedStringArray = []

	func share() -> float:
		return float(seen_points) / float(points) if points > 0 else 0.0

	func seen(min_share: float) -> bool:
		return centre_seen and share() >= min_share - 0.000001


class EdgeResult:
	extends RefCounted
	var index: int = -1
	var edge: Dictionary = {}
	var intent: StringName = INTENT_REVEAL
	var declared_mandatory: bool = false
	var enforceable: bool = false
	var enforcement_asked: bool = false
	var enforcement: String = ""
	var vantage: Vector3 = Vector3.ZERO
	var anchor: Vector3 = Vector3.ZERO
	var sight: Sight = null
	var verdict: StringName = VERDICT_ERROR
	var detail: String = ""

	func mandatory() -> bool:
		return declared_mandatory and enforceable

	func holds() -> bool:
		if verdict == VERDICT_ERROR:
			return false
		return verdict == (VERDICT_SEEN if intent == INTENT_REVEAL else VERDICT_UNSEEN)

	## Only ever true once the relationship has been asked (ENFORCE_WHEN_UNHELD asks exactly then).
	func rejects() -> bool:
		return mandatory() and not holds()

	func label() -> String:
		return "%s.%s -> %s.%s (%s)" % [edge.get("from", &""), edge.get("from_port", &""), edge.get("to", &""), edge.get("to_port", &""), intent]

	func to_dict() -> Dictionary:
		var out: Dictionary = {"edge": label(), "intent": String(intent), "declared_mandatory": declared_mandatory,
			"mandatory": mandatory(), "enforcement_asked": enforcement_asked, "enforcement": enforcement, "verdict": String(verdict), "holds": holds(), "detail": detail,
			"vantage": [vantage.x, vantage.y, vantage.z], "anchor": [anchor.x, anchor.y, anchor.z]}
		if sight != null:
			out["share"] = sight.share()
			out["centre_seen"] = sight.centre_seen
			out["screen"] = [snappedf(sight.screen.x, 0.01), snappedf(sight.screen.y, 0.01)]
			out["misses"] = Array(sight.misses)
		return out


class Report:
	extends RefCounted
	var edges: Array = []  # Array[EdgeResult]

	func rejecting() -> Array:
		return edges.filter(func(result: EdgeResult) -> bool: return result.rejects())

	func to_dicts() -> Array:
		return edges.map(func(result: EdgeResult) -> Dictionary: return result.to_dict())


static func check(recipe: FloorRecipe, draft: FloorDraft, emit: DraftEmitter.EmitReport, plan: FloorPlan,
		framing: CameraFraming, rules: Dictionary, enforce: StringName = ENFORCE_WHEN_UNHELD) -> Report:
	var report := Report.new()
	var extent: Rect2 = extent_of(plan)
	var every_occluder: Array[Dictionary] = occluders(plan, framing, [])
	var bounds := WalkableBounds.new(plan.all_rects(), plan.obstacle_rects())
	var radius: float = float(rules.get("body_radius", 0.0))
	var session: ProgressionValidator.ObjectiveSession = null
	for index: int in recipe.visibility.size():
		var edge: Dictionary = recipe.visibility[index]
		var result := EdgeResult.new()
		result.index = index
		result.edge = edge
		result.intent = edge.get("intent", INTENT_REVEAL)
		result.declared_mandatory = bool(edge.get("mandatory", false))
		report.edges.append(result)
		var from_index: int = recipe._index_of(edge.get("from", &""))
		var to_index: int = recipe._index_of(edge.get("to", &""))
		var viewer: FloorDraft.PieceInstance = draft.instances[from_index]
		var target: FloorDraft.PieceInstance = draft.instances[to_index]
		var vantage_port: PiecePort = viewer.piece.port(edge.get("from_port", &""))
		var anchor_port: PiecePort = target.piece.port(edge.get("to_port", &""))
		if vantage_port == null or vantage_port.kind != PiecePort.KIND_VANTAGE or anchor_port == null or anchor_port.kind != PiecePort.KIND_ANCHOR:
			result.detail = "the cast pieces (%s, %s) do not carry vantage '%s' and anchor '%s'" % [viewer.piece.piece_id, target.piece.piece_id, edge.get("from_port", &""), edge.get("to_port", &"")]
			result.enforcement = "not evaluated"
			result.enforcement_asked = true
			result.enforceable = result.declared_mandatory  # a promised reveal that cannot be checked is not waved through
			continue
		result.vantage = FloorDraft.world_point(viewer, vantage_port.position)
		result.anchor = FloorDraft.world_point(target, anchor_port.position)
		var door: int = -1
		var along: Vector3 = Vector3.ZERO
		var door_port_key: StringName = edge.get("door_port", &"")
		if door_port_key != &"":
			var door_port: PiecePort = target.piece.port(door_port_key)
			door = _connection_at(draft, emit, target.instance_id, door_port_key)
			if door_port != null:
				along = Vector3(1, 0, 0) if PiecePort.runs_along_x(FloorDraft.world_edge(target, door_port.edge)) else Vector3(0, 0, 1)
		if not bounds.fits(Vector3(result.vantage.x, 0.0, result.vantage.z), radius):
			result.detail = "the vantage %s is not ground an Envoy can stand on" % result.vantage
		else:
			var blockers: Array[Dictionary] = every_occluder if door < 0 else every_occluder.filter(func(blocker: Dictionary) -> bool: return blocker.get("gate", -1) != door)
			result.sight = look(framing, extent, blockers, result.vantage, result.anchor, along)
			result.verdict = VERDICT_SEEN if result.sight.seen(framing.reveal_min_visible_share) else VERDICT_UNSEEN
		if result.declared_mandatory and (enforce == ENFORCE_ALWAYS or not result.holds()):
			if session == null:
				session = ProgressionValidator.ObjectiveSession.new(plan, rules)
			result.enforcement_asked = true
			_enforce(result, recipe, draft, plan, session, edge, to_index, door)
		elif result.declared_mandatory:
			result.enforcement = "not asked: the reveal holds"
	return report


## The two progression questions that make a declared reveal enforceable (header). Sets
## `enforceable` and says why in `enforcement`.
static func _enforce(result: EdgeResult, recipe: FloorRecipe, draft: FloorDraft, plan: FloorPlan,
		session: ProgressionValidator.ObjectiveSession, edge: Dictionary, to_index: int, door: int) -> void:
	if door < 0:
		result.enforcement = "no locked door: a mandatory reveal must name the door it shows (door_port)"
		return
	var receivers: Array[int] = []
	var others: PackedStringArray = []
	for trigger: FloorTrigger in plan.triggers:
		if _opens(trigger.effects, door):
			if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
				receivers.append(trigger.trigger_id)
			else:
				others.append("trigger %s (%s)" % [trigger.key, trigger.kind])
	for hit_switch: HitSwitchPlan in plan.hit_switches:
		if _opens(hit_switch.effects, door):
			others.append("switch %s" % hit_switch.key)
	if receivers.is_empty() or not others.is_empty():
		result.enforcement = "door %d is not opened by key receivers alone (%s)" % [door, ", ".join(others) if not others.is_empty() else "nothing opens it"]
		return
	var beyond: Rect2 = _beyond(recipe, draft, edge.get("to", &""), edge.get("door_port", &""))
	if beyond.get_area() <= 0.0:
		result.enforcement = "no recipe edge leaves through door port '%s'" % edge.get("door_port", &"")
		return
	var locked: Dictionary = {ProgressionValidator.FORBID_DELIVER: receivers}
	var stand := Rect2(result.vantage.x - _VANTAGE_HALF, result.vantage.z - _VANTAGE_HALF, _VANTAGE_HALF * 2.0, _VANTAGE_HALF * 2.0)
	var reach: ProgressionValidator.ObjectiveResult = session.ask(locked, {ProgressionValidator.GOAL_ENTER: stand})
	if reach.verdict != ProgressionValidator.ObjectiveResult.ROUTE_FOUND:
		result.enforcement = "the vantage is not reachable while the door is locked (%s)" % reach.verdict
		return
	var past: ProgressionValidator.ObjectiveResult = session.ask(locked, {ProgressionValidator.GOAL_ENTER: beyond})
	if past.verdict != ProgressionValidator.ObjectiveResult.ROUTE_NONE:
		result.enforcement = "the ground beyond the door is not shut away by it (%s)" % past.verdict
		return
	result.enforceable = true
	result.enforcement = "locked door %d: vantage reachable, beyond unreachable, key withheld (receivers %s)" % [door, receivers]


## A toggle opens a closed door as surely as an open does, so both count as openers.
static func _opens(effects: Array[Dictionary], connection_id: int) -> bool:
	for effect: Dictionary in effects:
		if effect.get("kind", &"") in _OPENERS and int(effect.get("target_id", -1)) == connection_id:
			return true
	return false


## Why a piece cannot carry a declared-mandatory reveal's end, or "" when it can. `role` is "vantage"
## (the viewing piece) or "anchor" (the piece showing the door). Piece-local facts only: the door is
## addressed by its port (`@door_port`), the only way a piece body names its own joint.
static func declaration_fault(piece: FloorPiece, role: StringName, port_key: StringName, door_port_key: StringName = &"") -> String:
	var wanted: StringName = PiecePort.KIND_VANTAGE if role == &"vantage" else PiecePort.KIND_ANCHOR
	var port: PiecePort = piece.port(port_key)
	if port == null or port.kind != wanted:
		return "piece '%s' has no %s port '%s'" % [piece.piece_id, wanted, port_key]
	if role == &"vantage":
		return ""
	var door: PiecePort = piece.port(door_port_key)
	if door == null or door.kind != PiecePort.KIND_GATE:
		return "piece '%s' has no gate port '%s' to lock" % [piece.piece_id, door_port_key]
	var reference: StringName = StringName(FloorPiece.PORT_REFERENCE_PREFIX + String(door_port_key))
	var receivers: int = 0
	var others: PackedStringArray = []
	for trigger: FloorTrigger in piece.body.triggers:
		if _names_opener(trigger.effects, reference):
			if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED:
				receivers += 1
			else:
				others.append("trigger %s (%s)" % [trigger.key, trigger.kind])
	for hit_switch: HitSwitchPlan in piece.body.hit_switches:
		if _names_opener(hit_switch.effects, reference):
			others.append("switch %s" % hit_switch.key)
	if receivers == 0 or not others.is_empty():
		return "piece '%s' door '%s' is not opened by key receivers alone (%s)" % [piece.piece_id, door_port_key, ", ".join(others) if not others.is_empty() else "nothing opens it"]
	return ""


static func _names_opener(effects: Array[Dictionary], reference: StringName) -> bool:
	for effect: Dictionary in effects:
		if effect.get("kind", &"") in _OPENERS and StringName(effect.get("target_key", &"")) == reference:
			return true
	return false


## The footprint of the node on the far side of the recipe edge that leaves `node` by `port`.
static func _beyond(recipe: FloorRecipe, draft: FloorDraft, node: StringName, port: StringName) -> Rect2:
	for edge: Dictionary in recipe.edges:
		var other: StringName = &""
		if edge.get("from", &"") == node and edge.get("from_port", &"") == port:
			other = edge.get("to", &"")
		elif edge.get("to", &"") == node and edge.get("to_port", &"") == port:
			other = edge.get("from", &"")
		if other != &"":
			return FloorDraft.world_footprint(draft.instances[recipe._index_of(other)])
	return Rect2()


## The emitted connection at a placed piece's port, or -1 when no joint binds it.
static func _connection_at(draft: FloorDraft, emit: DraftEmitter.EmitReport, instance_id: StringName, port_key: StringName) -> int:
	for joint: FloorDraft.Joint in draft.joints:
		if joint.instance_id == instance_id and joint.port_key == port_key:
			return int(emit.joints.get(joint.joint_id, {}).get("connection_id", -1))
	return -1


## The floor's extent exactly as the Arena hands it to FollowCamera: the union of walkable rects.
static func extent_of(plan: FloorPlan) -> Rect2:
	var extent: Rect2 = Rect2()
	var rects: Array[Rect2] = plan.all_rects()
	for index: int in rects.size():
		extent = rects[index] if index == 0 else extent.merge(rects[index])
	return extent


## Every opaque box FloorBuilder draws that can stand between the camera and a target: walls on
## every solid segment (pushed outward by half their thickness, as built), obstacles at their own
## height, intact breakables at their drawn size, and closed gates over their whole aperture
## (conservative: the drawn barrier is a slab inside it). Gates in `except` are left out -- the door
## an anchor shows is the target, not cover.
static func occluders(plan: FloorPlan, framing: CameraFraming, except: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var height: float = framing.occluder_wall_height
	var thickness: float = framing.occluder_wall_thickness
	for segment: Dictionary in plan.solid_segments():
		var at: float = float(segment["at"]) + float(segment["outward"]) * thickness * 0.5
		var low: float = float(segment["min"])
		var span: float = float(segment["max"]) - low
		var elevation: float = float(segment["elevation"])
		var box: AABB
		if segment["axis"] == &"x":
			box = AABB(Vector3(at - thickness * 0.5, elevation, low), Vector3(thickness, height, span))
		else:
			box = AABB(Vector3(low, elevation, at - thickness * 0.5), Vector3(span, height, thickness))
		out.append({"box": box, "what": "wall %s=%s" % [segment["axis"], segment["at"]]})
	for obstacle: ObstaclePlan in plan.obstacles:
		out.append({"box": AABB(Vector3(obstacle.rect.position.x, 0.0, obstacle.rect.position.y), Vector3(obstacle.rect.size.x, obstacle.height, obstacle.rect.size.y)),
			"what": "obstacle %s" % obstacle.key})
	for breakable: BreakablePlan in plan.breakables:
		if breakable.blocking_rect.get_area() > 0.0:
			var rect: Rect2 = breakable.blocking_rect
			out.append({"box": AABB(Vector3(rect.position.x, 0.0, rect.position.y), Vector3(rect.size.x, framing.occluder_blocker_height, rect.size.y)),
				"what": "breakable %s" % breakable.key})
		else:
			var side: float = breakable.radius * framing.occluder_breakable_scale
			out.append({"box": AABB(breakable.position + Vector3(-side * 0.5, 0.0, -side * 0.5), Vector3(side, side, side)), "what": "breakable %s" % breakable.key})
	for connection: TraversalConnection in plan.connections:
		if connection.has_barrier and not connection.starts_open and not connection.connection_id in except:
			var rect: Rect2 = connection.aperture
			out.append({"box": AABB(Vector3(rect.position.x, 0.0, rect.position.y), Vector3(rect.size.x, framing.occluder_gate_height, rect.size.y)),
				"what": "closed gate %d" % connection.connection_id, "gate": connection.connection_id})
	return out


## One look: the camera FollowCamera would hold for an Envoy at `stand`, at the five-point cross
## around `target`. `along` is the door's line for a door target; zero means a flat ground cross.
static func look(framing: CameraFraming, extent: Rect2, blockers: Array[Dictionary], stand: Vector3, target: Vector3, along: Vector3 = Vector3.ZERO) -> Sight:
	var sight := Sight.new()
	sight.camera = framing.camera_position(stand, extent)
	var spread: float = framing.reveal_sample_spread
	var points: Array[Vector3] = [target]
	if along != Vector3.ZERO:
		points.append_array([target + along * spread, target - along * spread, target + Vector3.UP * spread, target - Vector3.UP * spread])
	else:
		points.append_array([target + Vector3(spread, 0, 0), target - Vector3(spread, 0, 0), target + Vector3(0, 0, spread), target - Vector3(0, 0, spread)])
	for index: int in points.size():
		var point: Vector3 = points[index]
		var projected: Dictionary = framing.project(sight.camera, point)
		if index == 0:
			sight.screen = projected["screen"]
		var miss: String = ""
		if projected["behind"]:
			miss = "behind"
		elif not framing.in_safe_band(projected["screen"]):
			miss = "off-band"
		else:
			for blocker: Dictionary in blockers:
				if (blocker["box"] as AABB).intersects_segment(sight.camera, point) != null:
					miss = blocker["what"]
					break
		sight.points += 1
		if miss == "":
			sight.seen_points += 1
			if index == 0:
				sight.centre_seen = true
		else:
			sight.misses.append(miss)
	return sight
