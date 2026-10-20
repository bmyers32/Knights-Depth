extends GutTest
## The Expedition's one rule, with no scene and no sim: an ordered itinerary, a position in it,
## and "is there a next entry?" deciding between a descent and the end of the run.

func _expedition(depths: Array[int]) -> Expedition:
	return Expedition.new(2026, depths)


func test_a_new_expedition_stands_on_its_first_entry() -> void:
	var expedition: Expedition = _expedition([1, 2])
	assert_eq(expedition.position, 0)
	assert_eq(expedition.current_depth(), 1)
	assert_false(expedition.is_complete)
	assert_eq(expedition.run_seed, 2026, "the seed is the expedition's, fixed at the start")


func test_advancing_with_an_entry_left_descends_to_it() -> void:
	var expedition: Expedition = _expedition([1, 2])
	assert_true(expedition.advance(), "a further entry means a descent")
	assert_eq(expedition.position, 1)
	assert_eq(expedition.current_depth(), 2)
	assert_false(expedition.is_complete, "descending is not completing")


func test_advancing_past_the_last_entry_completes_the_expedition() -> void:
	var expedition: Expedition = _expedition([1, 2])
	expedition.advance()
	assert_false(expedition.advance(), "no further entry means no descent")
	assert_true(expedition.is_complete)
	assert_eq(expedition.current_depth(), 2, "and it stays on the floor it finished on")


func test_a_one_entry_itinerary_completes_on_its_first_floor() -> void:
	var expedition: Expedition = _expedition([2])
	assert_false(expedition.advance())
	assert_true(expedition.is_complete)


## A duplicated completion signal must never run past the end or complete the run twice.
func test_a_completed_expedition_refuses_to_advance() -> void:
	var expedition: Expedition = _expedition([1, 2])
	expedition.advance()
	expedition.advance()
	assert_false(expedition.advance())
	assert_false(expedition.advance())
	assert_eq(expedition.position, 1, "the position never moves again")
	assert_true(expedition.is_complete)


## The itinerary handed in is configuration; the expedition's copy is run state. Editing one
## must not rewrite the other.
func test_the_itinerary_is_copied_not_aliased() -> void:
	var configured: Array[int] = [1, 2]
	var expedition: Expedition = Expedition.new(0, configured)
	configured.append(3)
	configured[0] = 9
	assert_eq(expedition.itinerary, [1, 2] as Array[int])


## The itinerary names the ORDER, not consecutive depths: an entry is whatever depth it says.
func test_entries_are_visited_in_itinerary_order() -> void:
	var expedition: Expedition = _expedition([2, 1])
	assert_eq(expedition.current_depth(), 2)
	assert_true(expedition.advance())
	assert_eq(expedition.current_depth(), 1)


# --- THE DESCENT (M2 expedition frame, Slice 1) --------------------------------------------

func _kinds(events: Array[Event]) -> Array[String]:
	var kinds: Array[String] = []
	for event in events:
		kinds.append(event.kind)
	return kinds


func test_completing_a_floor_with_an_entry_left_begins_a_descent() -> void:
	var expedition: Expedition = Expedition.new(7, [1, 2] as Array[int], 3)
	var events: Array[Event] = expedition.complete_floor(40)
	assert_eq(_kinds(events), ["descent_begun"] as Array[String])
	assert_eq(events[0].tick, 40, "stamped with the tick the floor was completed on")
	assert_eq(events[0].payload, {"from_depth": 1, "to_depth": 2, "descent_ticks": 3})
	assert_eq(expedition.phase, Expedition.PHASE_DESCENDING)
	assert_eq(expedition.position, 0, "the party has not arrived anywhere yet")
	assert_false(expedition.is_complete)


## EXACTLY descent_ticks ticks, and the arrival is announced once, on the last of them.
func test_a_descent_lasts_exactly_its_ticks_and_arrives_once() -> void:
	var expedition: Expedition = Expedition.new(7, [1, 2] as Array[int], 3)
	expedition.complete_floor(0)
	assert_eq(_kinds(expedition.tick_descent(0)), [] as Array[String], "tick 1 of 3")
	assert_eq(_kinds(expedition.tick_descent(0)), [] as Array[String], "tick 2 of 3")
	assert_eq(expedition.position, 0)
	var arrival: Array[Event] = expedition.tick_descent(0)
	assert_eq(_kinds(arrival), ["floor_entered"] as Array[String], "tick 3 of 3 arrives")
	assert_eq(arrival[0].payload, {"run_seed": 7, "depth": 2, "position": 1})
	assert_eq(expedition.phase, Expedition.PHASE_EXPLORING)
	assert_eq(expedition.position, 1)
	assert_eq(_kinds(expedition.tick_descent(0)), [] as Array[String], "and a further tick is no second arrival")


## One completion, one transition: a completion mid-descent is refused, never queued.
func test_a_completion_during_a_descent_is_refused() -> void:
	var expedition: Expedition = Expedition.new(0, [1, 2, 3] as Array[int], 2)
	expedition.complete_floor(0)
	assert_eq(_kinds(expedition.complete_floor(0)), [] as Array[String])
	expedition.tick_descent(0)
	expedition.tick_descent(0)
	assert_eq(expedition.position, 1, "one floor down, not two")
	assert_eq(expedition.phase, Expedition.PHASE_EXPLORING)


func test_completing_the_last_floor_completes_without_a_descent() -> void:
	var expedition: Expedition = Expedition.new(0, [1, 2] as Array[int], 5)
	expedition.complete_floor(0)
	for i in 5:
		expedition.tick_descent(0)
	var events: Array[Event] = expedition.complete_floor(99)
	assert_eq(_kinds(events), ["expedition_complete"] as Array[String])
	assert_eq(events[0].payload, {"final_depth": 2})
	assert_true(expedition.is_complete)
	assert_eq(expedition.phase, Expedition.PHASE_COMPLETE)
	assert_eq(_kinds(expedition.complete_floor(100)), [] as Array[String], "the end happens once")
	assert_eq(_kinds(expedition.tick_descent(100)), [] as Array[String])


func test_the_next_depth_is_named_only_when_there_is_one() -> void:
	var expedition: Expedition = Expedition.new(0, [1, 3] as Array[int], 1)
	assert_eq(expedition.next_depth(), 3)
	expedition.complete_floor(0)
	expedition.tick_descent(0)
	assert_eq(expedition.next_depth(), -1, "the last floor leads out, not to a depth")
	assert_false(expedition.has_next())


func test_descent_progress_runs_from_zero_to_one() -> void:
	var expedition: Expedition = Expedition.new(0, [1, 2] as Array[int], 4)
	assert_eq(expedition.descent_progress(), 0.0, "not descending")
	expedition.complete_floor(0)
	assert_eq(expedition.descent_progress(), 0.0)
	expedition.tick_descent(0)
	assert_almost_eq(expedition.descent_progress(), 0.25, 0.0001)
	expedition.tick_descent(0)
	expedition.tick_descent(0)
	assert_almost_eq(expedition.descent_progress(), 0.75, 0.0001)


# --- EMERGENCY RECALL (M2 Slice 2) ---------------------------------------------------------

func test_a_recall_ends_the_expedition_as_a_failure_not_a_completion() -> void:
	var expedition: Expedition = Expedition.new(0, [1, 2, 3] as Array[int], 1)
	expedition.complete_floor(0)
	expedition.tick_descent(1)
	var events: Array[Event] = expedition.recall(7)
	assert_eq(_kinds(events), ["emergency_recall"] as Array[String])
	assert_eq(events[0].tick, 7)
	assert_eq(events[0].payload, {"final_depth": 2, "position": 1, "floors_cleared": 1})
	assert_true(expedition.is_recalled)
	assert_false(expedition.is_complete, "Recall is never completion")
	assert_true(expedition.is_over())
	assert_eq(expedition.phase, Expedition.PHASE_RECALLED)


func test_a_recall_happens_once_and_nothing_overturns_it() -> void:
	var expedition: Expedition = Expedition.new(0, [1, 2] as Array[int], 1)
	expedition.recall(0)
	assert_eq(_kinds(expedition.recall(1)), [] as Array[String], "the end happens once")
	assert_eq(_kinds(expedition.complete_floor(2)), [] as Array[String], "a later completion is refused")
	assert_eq(_kinds(expedition.tick_descent(3)), [] as Array[String])
	assert_false(expedition.is_complete)
	assert_eq(expedition.floors_cleared(), 0)


func test_a_recall_is_refused_mid_descent_and_after_completion() -> void:
	var descending: Expedition = Expedition.new(0, [1, 2] as Array[int], 5)
	descending.complete_floor(0)
	assert_eq(_kinds(descending.recall(1)), [] as Array[String], "a suspended floor cannot fall")
	assert_false(descending.is_recalled)
	var done: Expedition = Expedition.new(0, [1] as Array[int], 1)
	done.complete_floor(0)
	assert_eq(_kinds(done.recall(1)), [] as Array[String], "an extracted expedition stays extracted")
	assert_false(done.is_recalled)


func test_floors_cleared_counts_finished_entries() -> void:
	var expedition: Expedition = Expedition.new(0, [1, 2, 3] as Array[int], 1)
	assert_eq(expedition.floors_cleared(), 0)
	for i in 2:
		expedition.complete_floor(0)
		expedition.tick_descent(0)
	assert_eq(expedition.floors_cleared(), 2, "two behind, standing on the third")
	expedition.complete_floor(0)
	assert_eq(expedition.floors_cleared(), 3, "extraction finishes the floor it ends on")
