class_name PiecePort
extends Resource
## WHERE A FloorPiece MAY BE JOINED TO THE REST OF A FLOOR (ADR-001 §4, S1).
##
## ONE TYPE, FIVE KINDS. `kind` decides which fields are read; the rest stay at their defaults.
## A port is the ONLY thing outside a piece's body that the emitter may touch: the body is the
## author's, the joints are the draft's, and a port is the contract between them. Nothing here
## is read at runtime -- the sim sees the TraversalConnection the emitter writes at a joint.
##
##   connector   a joint aperture may sit here; the joint starts open
##   gate        the same geometry; the joint starts CLOSED with a barrier, and something must
##               open it (in S1 only the piece's own records, through `@<port key>`)
##   unlock      a body trigger or switch whose effects gain a cross-piece effect (wired in S3)
##   vantage     where the party can stand to see something (checked in S4)
##   anchor      what must be seen from a vantage (checked in S4)
##
## EDGE GEOMETRY, stated so it cannot be guessed wrong (the WalkablePatch axis law): north is the
## MAX-z side of the footprint, south MIN-z, east MAX-x, west MIN-x. `offset` is measured along
## the edge from its minimum coordinate -- from the footprint's x-min on a north/south edge, from
## its z-min on an east/west edge -- and `width` runs from there in the same direction. Mirroring
## (FloorDraft) swaps east and west and reflects a north/south offset across the footprint.

const KIND_CONNECTOR: StringName = &"connector"
const KIND_GATE: StringName = &"gate"
const KIND_UNLOCK: StringName = &"unlock"
const KIND_VANTAGE: StringName = &"vantage"
const KIND_ANCHOR: StringName = &"anchor"
const KINDS: Array[StringName] = [KIND_CONNECTOR, KIND_GATE, KIND_UNLOCK, KIND_VANTAGE, KIND_ANCHOR]
## The kinds a joint may bind: the two that place an aperture.
const JOINABLE_KINDS: Array[StringName] = [KIND_CONNECTOR, KIND_GATE]

const EDGE_NORTH: StringName = &"north"
const EDGE_SOUTH: StringName = &"south"
const EDGE_EAST: StringName = &"east"
const EDGE_WEST: StringName = &"west"
const EDGES: Array[StringName] = [EDGE_NORTH, EDGE_SOUTH, EDGE_EAST, EDGE_WEST]

## Unique within its piece. Referenced from a body effect as `@<key>` (connector/gate only).
@export var key: StringName = &""
@export var kind: StringName = KIND_CONNECTOR

## connector / gate: where on the footprint edge the aperture may sit.
@export var edge: StringName = EDGE_NORTH
@export var offset: float = 0.0
@export var width: float = 0.0
## connector / gate: the body patch that reaches this edge across the whole span.
@export var patch_key: StringName = &""

## unlock: the body record whose effects gain the cross-piece effect. Exactly one of the two.
@export var trigger_key: StringName = &""
@export var switch_key: StringName = &""

## vantage / anchor: a point in the piece's local coordinates.
@export var position: Vector3 = Vector3.ZERO


func is_joinable() -> bool:
	return kind in JOINABLE_KINDS


## Does this edge run along x (north/south) rather than along z (east/west)?
static func runs_along_x(side: StringName) -> bool:
	return side == EDGE_NORTH or side == EDGE_SOUTH


## The line a port occupies on a given footprint -- the piece's own, or the placed one:
##   at         the edge's fixed coordinate (z for north/south, x for east/west)
##   from, to   the span along the edge
##   outward    +1 / -1 along the edge's normal: the side a joint's ground lies on
## One function for both the lint and the emitter, so "where is this port" has one answer.
static func span_on(footprint: Rect2, side: StringName, offset: float, width: float) -> Dictionary:
	match String(side):
		"north":
			return {"at": footprint.end.y, "from": footprint.position.x + offset, "to": footprint.position.x + offset + width, "outward": 1.0}
		"south":
			return {"at": footprint.position.y, "from": footprint.position.x + offset, "to": footprint.position.x + offset + width, "outward": -1.0}
		"east":
			return {"at": footprint.end.x, "from": footprint.position.y + offset, "to": footprint.position.y + offset + width, "outward": 1.0}
	return {"at": footprint.position.x, "from": footprint.position.y + offset, "to": footprint.position.y + offset + width, "outward": -1.0}
