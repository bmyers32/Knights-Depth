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
