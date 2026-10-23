class_name FloorDraft
extends RefCounted
## THE STRUCTURAL INTERMEDIATE BETWEEN PLACED PIECES AND ONE FLAT AuthoredLayout (ADR-001 §4, S1).
##
## IN MEMORY ONLY, AND ONLY STRUCTURE. A draft holds which pieces stand where under which
## transform, the connective ground laid between them, and the joints that bind a piece's port
## to that ground. It holds NO gameplay record of its own -- a piece's body is read from the
## piece, never copied here, so there is exactly one authored copy of every trigger and roster
## (the draft is a list of placements, not a second floor).
##
## IDENTITIES ARE ALLOCATED HERE, IN ORDER, AND NEVER REUSED: instances are `i00, i01, ...` in
## placement order, hallways `h00, ...`, joints `j00, ...`. The emitter's remap table and the
## emitted layout's keys (`i01.T_PLATE`) are built on these, so the same draft always lowers to
## the same floor and a reader can trace any emitted record back to its piece.
##
## EXPLICIT COORDINATES, EXPLICIT TRANSFORMS. `origin` is where the piece's local origin lands
## on the floor; `transform` is identity unless the caller says otherwise AND the piece allows
## it (O6; the emitter refuses the rest). Nothing here searches, scores or chooses: placement
## is S2's, and this class would not know how to begin.
##
## WORLD = T(local) + origin, where T is identity or mirror_x (x -> -x). The three `world_*`
## helpers are the ONE definition of that mapping; the emitter and the joint geometry both go
## through them, so a rect and the point inside it can never be transformed two different ways.

## One placed piece.
class PieceInstance:
	extends RefCounted
	var instance_id: StringName = &""
	var piece: FloorPiece = null
	var origin: Vector2 = Vector2.ZERO
	var transform: StringName = FloorPiece.TRANSFORM_IDENTITY


## Connective ground in WORLD coordinates: one or more rects that overlap where they turn, so
## the walkable union already joins them and no connection is needed inside the fragment. Its
## surface and boundary are presentation facts the fragment carries whole.
class HallwayFragment:
	extends RefCounted
	var hallway_id: StringName = &""
	var rects: Array[Rect2] = []
	var surface: StringName = &"stone"
	var boundary_style: StringName = &"wall"


## A port bound to a hallway. The emitter turns it into one TraversalConnection whose aperture
## straddles the port edge: `overlap` into the piece's patch, across the gap, `overlap` into the
## hallway rect. A gate port's joint starts closed with a barrier; a connector's starts open.
class Joint:
	extends RefCounted
	var joint_id: StringName = &""
	var instance_id: StringName = &""
	var port_key: StringName = &""
	var hallway_id: StringName = &""
	var overlap: float = 0.0
	var flank_style: StringName = &"wall"


var draft_id: StringName = &""
var place_label: String = ""
var stratum_id: StringName = &""
var instances: Array[PieceInstance] = []
var hallways: Array[HallwayFragment] = []
var joints: Array[Joint] = []


func place(piece: FloorPiece, origin: Vector2, transform: StringName = FloorPiece.TRANSFORM_IDENTITY) -> StringName:
	var instance := PieceInstance.new()
	instance.instance_id = StringName("i%02d" % instances.size())
	instance.piece = piece
	instance.origin = origin
	instance.transform = transform
	instances.append(instance)
	return instance.instance_id


func lay(rects: Array[Rect2], surface: StringName, boundary_style: StringName) -> StringName:
	var hallway := HallwayFragment.new()
	hallway.hallway_id = StringName("h%02d" % hallways.size())
	hallway.rects = rects.duplicate()
	hallway.surface = surface
	hallway.boundary_style = boundary_style
	hallways.append(hallway)
	return hallway.hallway_id


func bind(instance_id: StringName, port_key: StringName, hallway_id: StringName, overlap: float, flank_style: StringName) -> StringName:
	var joint := Joint.new()
	joint.joint_id = StringName("j%02d" % joints.size())
	joint.instance_id = instance_id
	joint.port_key = port_key
	joint.hallway_id = hallway_id
	joint.overlap = overlap
	joint.flank_style = flank_style
	joints.append(joint)
	return joint.joint_id


func instance_of(instance_id: StringName) -> PieceInstance:
	for instance: PieceInstance in instances:
		if instance.instance_id == instance_id:
			return instance
	return null


func hallway_of(hallway_id: StringName) -> HallwayFragment:
	for hallway: HallwayFragment in hallways:
		if hallway.hallway_id == hallway_id:
			return hallway
	return null


# --- THE PLACEMENT MAPPING ------------------------------------------------------------------

static func world_rect(instance: PieceInstance, local: Rect2) -> Rect2:
	var placed: Rect2 = local
	if instance.transform == FloorPiece.TRANSFORM_MIRROR_X:
		placed = Rect2(-(local.position.x + local.size.x), local.position.y, local.size.x, local.size.y)
	return Rect2(placed.position + instance.origin, placed.size)


static func world_point(instance: PieceInstance, local: Vector3) -> Vector3:
	var x: float = -local.x if instance.transform == FloorPiece.TRANSFORM_MIRROR_X else local.x
	return Vector3(x + instance.origin.x, local.y, local.z + instance.origin.y)


## Mirroring swaps the two x-facing sides and leaves north and south alone.
static func world_edge(instance: PieceInstance, side: StringName) -> StringName:
	if instance.transform != FloorPiece.TRANSFORM_MIRROR_X:
		return side
	if side == PiecePort.EDGE_EAST:
		return PiecePort.EDGE_WEST
	if side == PiecePort.EDGE_WEST:
		return PiecePort.EDGE_EAST
	return side


static func world_footprint(instance: PieceInstance) -> Rect2:
	return world_rect(instance, instance.piece.footprint)


## A port's line on the placed footprint. A mirrored north/south port is reflected across the
## footprint (its offset is measured from x-min, which mirroring moves to the other end); an
## east/west port keeps its offset and changes edge.
static func port_span(instance: PieceInstance, port: PiecePort) -> Dictionary:
	var offset: float = port.offset
	if instance.transform == FloorPiece.TRANSFORM_MIRROR_X and PiecePort.runs_along_x(port.edge):
		offset = instance.piece.footprint.size.x - port.offset - port.width
	return PiecePort.span_on(world_footprint(instance), world_edge(instance, port.edge), offset, port.width)
