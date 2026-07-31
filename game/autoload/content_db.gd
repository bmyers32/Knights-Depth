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
