class_name Expedition
extends RefCounted
## One run's progression: an ordered itinerary of floors, where the party is in it, and whether
## it is over. Plain data in the sim layer (GAME-RULES §2 -- no Node), held by the driver beside
## the SimWorld it drives, so "which floor is next" and "was that the last one" are never
## presentation state and never inferred from a layout or a stratum.
##
## DELIBERATELY NOT A FRAMEWORK (§1.4). This is the smallest thing the first two-floor run
## needs. There is no FloorSequence resource, no mission, no branching: an itinerary is a list.
##
## AN ENTRY IS A DEPTH, and that is a known simplification: today's two entries sit at depths 1
## and 2, so "position in the itinerary" and "absolute depth" are the same number shifted by
## one. They stop being the same the first time a floor can appear at more than one position
## (ROADMAP P6). Split them then, against that consumer -- not before.

var run_seed: int
var itinerary: Array[int]
var position: int = 0
var is_complete: bool = false


func _init(seed_value: int, depths: Array[int]) -> void:
	assert(not depths.is_empty(), "an expedition needs at least one itinerary entry")
	run_seed = seed_value
	# Copied, not aliased: the caller's array is configuration, this one is run state.
	itinerary = depths.duplicate()


func current_depth() -> int:
	return itinerary[position]


## THE ONE COMPLETION RULE, called when the current floor has been completed. Returns true when
## the expedition moved to a further entry (the caller descends), false when there was none --
## in which case the expedition is now complete.
##
## Idempotent once complete: a second call changes nothing, so a duplicated completion signal
## can never run past the end or complete the expedition twice.
func advance() -> bool:
	if is_complete:
		return false
	if position + 1 < itinerary.size():
		position += 1
		return true
	is_complete = true
	return false
