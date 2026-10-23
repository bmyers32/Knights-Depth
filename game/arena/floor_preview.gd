class_name FloorPreview
extends RefCounted
## What a console says about a floor the party has not reached yet, DERIVED from that floor's own
## plan: its depth, what the place is called, its stratum, and which families its roster actually
## fields, most numerous first. Two consumers, one derivation (§1.4 rule of two): the exit console's
## next-floor preview and the Ready Room's Floor 1 briefing. Both are handed the plan that will
## actually be installed, never a second generate() that could disagree with it.
##
## No thresholds ("Fang-heavy") until a variable roster exists to need them (P6).


static func of(plan: FloorPlan) -> Dictionary:
	var counts: Dictionary = {}
	for spawn: Dictionary in plan.all_spawns():
		var stats: Resource = ContentDB.get_resource(&"enemy", spawn["enemy_key"])
		var family: StringName = stats.family if stats != null else StringName(spawn["enemy_key"])
		counts[family] = int(counts.get(family, 0)) + 1
	var families: Array = counts.keys()
	# Ties broken by name so the line never depends on Dictionary order.
	families.sort_custom(func(a: StringName, b: StringName) -> bool:
		return counts[a] > counts[b] or (counts[a] == counts[b] and String(a) < String(b)))
	return {
		"depth": plan.depth, "place": place_name(plan),
		"stratum": String(plan.stratum_id).capitalize(), "families": families,
	}


## A place with a name of its own is shown by it; every other floor is known by its stratum.
static func place_name(plan: FloorPlan) -> String:
	return plan.place_label if plan.place_label != "" else String(plan.stratum_id).capitalize()
