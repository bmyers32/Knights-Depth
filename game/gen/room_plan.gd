class_name RoomPlan
extends RefCounted
## One room of a floor: its role, its walkable rectangle, and its OWN encounter content.
##
## Rooms are the authoring and gameplay view of a floor; FloorPlan.walkable_rects is the
## flattened legality view the sim consumes. Both describe the same floor, and the flattened
## form is DERIVED from the rooms so the two cannot disagree (AGENTS.md Truth Homes).
##
## The vocabulary is deliberately three words. Shops, puzzles, secrets and treasure rooms are
## later work; adding a kind here without a mechanic behind it would be authoring a taxonomy
## instead of a game.
##   ENTRY      where the Envoy arrives. No roster.
##   TRAVERSAL  connective space. No roster. This is what makes a floor feel explored.
##   COMBAT     owns a roster and seals while its encounter is live.

const KIND_ENTRY: StringName = &"entry"
const KIND_TRAVERSAL: StringName = &"traversal"
const KIND_COMBAT: StringName = &"combat"

var room_id: int = -1
var kind: StringName = KIND_TRAVERSAL
var rect: Rect2 = Rect2()
## [{"enemy_key": StringName, "position": Vector3}] -- ROOM-LOCAL. Every actor here is owned
## by this room for its whole lifetime (confinement is unconditional, not lock-scoped), and
## an encounter clears only when every one of them is dead.
var spawns: Array[Dictionary] = []


func centre() -> Vector3:
	return Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)
