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
##
## THE DESCENT IS RUN STATE, NOT A SCREEN EFFECT (M2 expedition frame, Slice 1). Between a
## completed floor and the next one the expedition is DESCENDING for a fixed number of sim-rate
## ticks; this object owns that countdown and announces each transition as a plain-data Event, so
## a future server can send the same Events a client renders. The floor's SimWorld is not ticked
## while this counts -- the driver enforces that by asking `phase`.

const PHASE_EXPLORING: StringName = &"exploring"
const PHASE_DESCENDING: StringName = &"descending"
const PHASE_COMPLETE: StringName = &"complete"

var run_seed: int
var itinerary: Array[int]
var position: int = 0
var is_complete: bool = false
var phase: StringName = PHASE_EXPLORING
## How long a descent lasts, in sim-rate ticks. Run configuration handed in by the driver.
var descent_ticks: int
var descent_ticks_remaining: int = 0


func _init(seed_value: int, depths: Array[int], descent_tick_count: int = 1) -> void:
	assert(not depths.is_empty(), "an expedition needs at least one itinerary entry")
	# Zero would make "descending" a state that is entered and left in the same tick, which no
	# consumer could ever observe -- a countdown that cannot count.
	assert(descent_tick_count >= 1, "a descent lasts at least one tick")
	run_seed = seed_value
	# Copied, not aliased: the caller's array is configuration, this one is run state.
	itinerary = depths.duplicate()
	descent_ticks = descent_tick_count


func current_depth() -> int:
	return itinerary[position]


func has_next() -> bool:
	return position + 1 < itinerary.size()


## -1 when the current floor is the last: there is no "next depth" to name, and inventing one
## would let a preview promise a floor that will never load.
func next_depth() -> int:
	return itinerary[position + 1] if has_next() else -1


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
	phase = PHASE_COMPLETE
	return false


## The current floor was completed. With an entry left the expedition starts DESCENDING (the
## position does not move until the descent ends); on the last entry it completes at once.
##
## Accepted only while EXPLORING, so a completion arriving mid-descent or after the end is
## refused rather than queued -- one completion, one transition.
func complete_floor(tick: int) -> Array[Event]:
	if phase != PHASE_EXPLORING:
		return []
	var from_depth: int = current_depth()
	if has_next():
		phase = PHASE_DESCENDING
		descent_ticks_remaining = descent_ticks
		return [Event.new(tick, "descent_begun", {
			"from_depth": from_depth, "to_depth": next_depth(), "descent_ticks": descent_ticks,
		})]
	advance()
	return [Event.new(tick, "expedition_complete", {"final_depth": from_depth})]


## One sim-rate tick of the descent. The tick that exhausts the countdown moves the expedition
## onto the next entry and emits floor_entered; the driver installs that floor in response.
func tick_descent(tick: int) -> Array[Event]:
	if phase != PHASE_DESCENDING:
		return []
	descent_ticks_remaining -= 1
	if descent_ticks_remaining > 0:
		return []
	advance()
	phase = PHASE_EXPLORING
	return [Event.new(tick, "floor_entered", {
		"run_seed": run_seed, "depth": current_depth(), "position": position,
	})]


## 0.0 at the start of a descent, 1.0 on the tick it ends. Presentation reads this; it never
## keeps a clock of its own.
func descent_progress() -> float:
	if phase != PHASE_DESCENDING:
		return 0.0
	return 1.0 - float(descent_ticks_remaining) / float(descent_ticks)
