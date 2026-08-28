class_name ConnectionPlan
extends RefCounted
## A doorway/corridor joining two rooms.
##
## The aperture is a WALKABLE RECT IN ITS OWN RIGHT that OVERLAPS both rooms it joins -- not a
## portal, not a graph edge with special traversal rules. Connectivity is literally rectangle
## overlap, which is why the sim needs no pathfinding or portal logic to let an actor walk
## from one room to the next: the destination is simply inside some rect.
##
## THE OVERLAP IS LOAD-BEARING FOR GATING. Because the aperture pokes INTO each room, the
## portion of it that lies within a room is already covered by that room's own rect. So
## sealing an encounter needs no aperture surgery at all: confining an actor to the room rect
## leaves the threshold legal and only removes the corridor beyond it. That is what makes
## "closing a gate never shrinks the combat space and never snaps an actor off the threshold"
## true by construction rather than by a special case.

var connection_id: int = -1
## The two rooms this joins, as room_ids.
var room_ids: Vector2i = Vector2i(-1, -1)
var aperture: Rect2 = Rect2()
## True when either side is a COMBAT room -- i.e. presentation should build a barrier here
## that can visibly close. PRESENTATION ONLY: the mechanical seal is room confinement in the
## sim, never a mutation of the walkable set (SimWorld._legal_bounds_for).
var gated: bool = false


func joins(room_id: int) -> bool:
	return room_ids.x == room_id or room_ids.y == room_id


func other_room(room_id: int) -> int:
	return room_ids.y if room_ids.x == room_id else room_ids.x
