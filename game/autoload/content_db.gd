extends Node
## Content lookup service locator (CLAUDE.md Core Interfaces):
## ContentDB.get_resource(family, id) -> Resource. Explicit registry, not
## folder-convention path-guessing. Ids are instance names ("default"), never type
## names, so multiple envoy loadouts can coexist later without a naming collision.
## Named get_resource, not get(): GDScript can't override native Object.get(property)
## with a different signature (hard parse error, not a style choice).

const _REGISTRY: Dictionary = {
	"envoy": {
		"default": preload("res://game/content/envoy/envoy_stats.tres"),
	},
	"weapon": {
		"sword_A": preload("res://game/content/weapons/sword_stats.tres"),
		"sword_burn_A": preload("res://game/content/weapons/sword_burn_A.tres"),
		"wand_A": preload("res://game/content/weapons/gun_stats.tres"),
		"gun_pierce_A": preload("res://game/content/weapons/gun_pierce_A.tres"),
		"gun_arc_A": preload("res://game/content/weapons/gun_arc_A.tres"),
		"gun_umbral_A": preload("res://game/content/weapons/gun_umbral_A.tres"),
	},
	"enemy": {
		"fang": preload("res://game/content/enemies/fang/fang_stats.tres"),
		"ooze": preload("res://game/content/enemies/ooze/ooze_stats.tres"),
		"watcher": preload("res://game/content/enemies/watcher/watcher_stats.tres"),
	},
	"natural_weapon": {
		"fang_bite": preload("res://game/content/enemies/natural_weapons/fang_bite.tres"),
		"ooze_slam": preload("res://game/content/enemies/natural_weapons/ooze_slam.tres"),
		"watcher_pulse": preload("res://game/content/enemies/natural_weapons/watcher_pulse.tres"),
	},
	"combat": {
		"damage_matrix": preload("res://game/content/combat/damage_matrix.tres"),
		"flinch_tuning": preload("res://game/content/combat/flinch_tuning.tres"),
	},
	"shield": {
		"default": preload("res://game/content/shield/shield_stats.tres"),
	},
	"status": {
		"burn": preload("res://game/content/status/burn_stats.tres"),
		"priority_table": preload("res://game/content/status/status_priority.tres"),
	},
}


func get_resource(family: StringName, id: StringName) -> Resource:
	var family_key := String(family)
	var id_key := String(id)
	if not _REGISTRY.has(family_key):
		push_error("ContentDB: unknown family '%s'" % family_key)
		return null
	var family_table: Dictionary = _REGISTRY[family_key]
	if not family_table.has(id_key):
		push_error("ContentDB: unknown id '%s' in family '%s'" % [id_key, family_key])
		return null
	return family_table[id_key]
