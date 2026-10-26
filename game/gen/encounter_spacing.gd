class_name EncounterSpacing
extends RefCounted
## SPAWN SAFETY FOR PLATE-ACTIVATED ENCOUNTERS (ADR-001 S2.5, human finding 2026-10-23: "enemies
## appear directly on top of the player"). A roster member that becomes present on activation
## must stand outside its own ARRIVAL REACH from every point the activating player can occupy:
## the distance it can close and strike across before the player has had time to read it.
##
##   reach = envoy body + enemy body + preferred attack distance
##         + move speed x (shortest windup + reaction allowance) / ticks per second
##
## Every term is content (EnvoyStats, the enemy's stats, its natural weapons); nothing here is a
## chosen dimension. CALIBRATED AGAINST THE SHIPPED FLOORS: every activated encounter the human
## accepted passes (the closest, E_POCKET's fang at 5.83 against a fang reach of 5.7) and the
## S2 exit gallery the human rejected (2.0, 2.2) fails.
##
## THE ACTIVATION POINT IS THE REGION'S CENTRE: exact for a plate the player steps onto, a median
## estimate for a threshold zone the player crosses. The pessimistic alternative -- the region's
## point nearest the spawn -- was tried and REJECTED by the same calibration: three shipped
## threshold rooms (E_HALL, E_POCKET, E_WORKS) author their rosters inside the zone that wakes
## them, and the human never found them unfair.
##
## Detection only, like FloorPlan.violations(): findings, never repairs. Activations by a
## non-region trigger (a switch, a breakable) are not judged: where the player stands at that
## moment is a property of the source record, which this rule does not model yet.

const RULE_SPAWN_WITHIN_REACH: StringName = &"spawn_within_reach"
const RULE_REACH_UNKNOWN: StringName = &"spawn_reach_unknown"


static func arrival_reach(envoy_radius: float, enemy_radius: float, preferred_attack_distance: float, move_speed: float, shortest_windup_ticks: int, reaction_ticks: int, ticks_per_second: float) -> float:
	return envoy_radius + enemy_radius + preferred_attack_distance + move_speed * float(shortest_windup_ticks + reaction_ticks) / ticks_per_second


## Where the player is taken to stand when a region trigger fires.
static func activation_point(region: Rect2) -> Vector2:
	return region.get_center()


## Every spawn inside its own arrival reach of the region that activates it. `reach_by_key` maps
## an enemy key to the reach computed by `arrival_reach`; a roster key it lacks is a finding.
static func findings(layout: AuthoredLayout, reach_by_key: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for trigger: FloorTrigger in layout.triggers:
		if trigger.region.get_area() <= 0.0:
			continue
		for effect: Dictionary in trigger.effects:
			if effect.get("kind", &"") != FloorLayers.EFFECT_ACTIVATE_ENCOUNTER:
				continue
			var site: EncounterSite = _site_of(layout, effect)
			if site == null:
				continue
			for member: Dictionary in site.roster:
				var enemy_key: StringName = member.get("enemy_key", &"")
				if not reach_by_key.has(enemy_key):
					out.append({"rule": RULE_REACH_UNKNOWN, "message": "%s: encounter '%s' casts '%s', whose arrival reach was not supplied" % [layout.layout_id, site.key, enemy_key],
						"refs": {"encounter": site.key, "enemy": enemy_key}})
					continue
				var position: Vector3 = member.get("position", Vector3.ZERO)
				var distance: float = Vector2(position.x, position.z).distance_to(activation_point(trigger.region))
				var required: float = float(reach_by_key[enemy_key])
				if distance < required:
					out.append({"rule": RULE_SPAWN_WITHIN_REACH,
						"message": "%s: '%s' of encounter '%s' spawns %.2f from the plate '%s' that wakes it; its arrival reach is %.2f" % [layout.layout_id, enemy_key, site.key, distance, trigger.key, required],
						"refs": {"trigger": trigger.key, "encounter": site.key, "enemy": enemy_key, "distance": distance, "required": required}})
	return out


static func _site_of(layout: AuthoredLayout, effect: Dictionary) -> EncounterSite:
	var wanted_key: StringName = effect.get("target_key", &"")
	var wanted_id: int = int(effect.get("target_id", -1))
	for site: EncounterSite in layout.encounters:
		if (wanted_key != &"" and site.key == wanted_key) or (wanted_key == &"" and site.encounter_id == wanted_id):
			return site
	return null
