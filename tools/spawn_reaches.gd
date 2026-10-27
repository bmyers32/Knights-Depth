extends RefCounted
## EACH ENEMY'S ARRIVAL REACH (EncounterSpacing), derived from content for the tools that compose
## floors -- the seed sweep and the debug playground -- so both judge spawns by the same numbers
## the composer rejects on. Content is loaded BY PATH: a `-s` tool has no ContentDB autoload.
## (The tests derive the same reaches independently, through ContentDB, as a cross-check.)

const ENVOY_STATS := "res://game/content/envoy/envoy_stats.tres"


static func for_keys(enemy_keys: Array) -> Dictionary:
	var envoy: Resource = load(ENVOY_STATS)
	var ticks_per_second: float = float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
	var reaches: Dictionary = {}
	for key: StringName in enemy_keys:
		var stats: Resource = load("res://game/content/enemies/%s/%s_stats.tres" % [key, key])
		if stats == null:
			continue
		var windup: int = -1
		for action_id: StringName in stats.action_ids:
			var weapon: Resource = load("res://game/content/enemies/natural_weapons/%s.tres" % action_id)
			if weapon != null and (windup < 0 or weapon.windup_ticks < windup):
				windup = weapon.windup_ticks
		reaches[key] = EncounterSpacing.arrival_reach(envoy.combat_radius, stats.combat_radius, stats.preferred_attack_distance, stats.move_speed, maxi(windup, 0), envoy.spawn_reaction_ticks, ticks_per_second)
	return reaches
