class_name DamageLedger
extends RefCounted
## WHAT ACTUALLY KILLED THE PLAYER — debug attribution, not a game system.
##
## A death report of "I die too fast" is untunable. It could be three enemies landing ordinary
## hits, or overlapping attackers, or a shield break at the wrong moment, or a DoT nobody could
## see -- and softening combat without knowing which is how a game becomes both easy and still
## unfair. This records every point of damage the Envoy accepts, attributed by what the pipeline
## can TRUTHFULLY supply, so the next tuning decision has a cause attached to it.
##
## PRESENTATION-ONLY, and structurally so: it takes Events and returns strings. It holds no
## gameplay state, mutates nothing, and the sim neither knows nor cares that it exists.
##
## IT INVENTS NOTHING. Every column below comes from a payload key that is already there. Where
## the pipeline cannot separate something, the row says so rather than guessing -- an attributed
## table with one made-up column is worse than an honest table with a gap, because the made-up
## column is the one that gets believed.
##
##   hit               -> HEALTH damage. Shield-absorbed attacks never reach this event.
##   blocked           -> SHIELD damage, with the meter left after it.
##   status_resolved   -> DoT damage, with the status kind and its ORIGINAL owner where one
##                        exists. That owner only became recordable with the 2026-09-08
##                        provenance fix; before it, a Burn tick was unattributable by
##                        construction, which is exactly why self-Burn went unnoticed.

## Every accepted row, in order. Kept whole rather than pre-summarised: the interesting question
## after a death is usually the last two seconds, and a running total cannot answer that.
var rows: Array[Dictionary] = []

var health_damage: float = 0.0
var shield_damage: float = 0.0
var status_damage: float = 0.0
var shield_breaks: int = 0


## Feed it every Event the driver already receives. It picks out what lands on `player_id` and
## ignores the rest -- so the call site is one line and cannot drift out of step with the game.
func record(event: Event, player_id: int) -> void:
	match event.kind:
		"hit":
			if int(event.payload.get("target_id", -1)) != player_id:
				return
			var row: Dictionary = {
				"tick": event.tick,
				"channel": "health",
				"amount": float(event.payload.get("damage", 0.0)),
				# SOURCE_ACTOR is the default and is therefore ABSENT from the payload; the key
				# appears only for environmental damage. Reading the absence as "actor" is not an
				# assumption, it is the documented convention of that seam.
				"source_kind": String(event.payload.get("source", "actor")),
				"source_actor": int(event.payload.get("attacker_id", -1)),
				"damage_type": String(event.payload.get("damage_type", "")),
			}
			if event.payload.has("attack_profile_id"):
				row["profile"] = String(event.payload["attack_profile_id"])
			health_damage += row.amount
			rows.append(row)
		"blocked":
			if int(event.payload.get("target_id", -1)) != player_id:
				return
			var amount: float = float(event.payload.get("damage_absorbed", 0.0))
			shield_damage += amount
			rows.append({
				"tick": event.tick,
				"channel": "shield",
				"amount": amount,
				"source_kind": "actor",
				"source_actor": int(event.payload.get("attacker_id", -1)),
				"meter_left": float(event.payload.get("remaining_meter", 0.0)),
			})
		"shield_broken":
			if int(event.payload.get("actor_id", -1)) != player_id:
				return
			shield_breaks += 1
			rows.append({"tick": event.tick, "channel": "shield_broken", "amount": 0.0})
		"status_resolved":
			if int(event.payload.get("actor_id", -1)) != player_id:
				return
			var amount: float = float(event.payload.get("damage", 0.0))
			status_damage += amount
			var row: Dictionary = {
				"tick": event.tick,
				"channel": "status",
				"amount": amount,
				"source_kind": "status",
				"status": String(event.payload.get("status_id", "")),
				# ABSENT means nobody owns it, and is reported as absent. An environmental or
				# seeded affliction gets no fabricated actor id to fill the column.
				"source_actor": int(event.payload.get("source_actor_id", -1)),
			}
			rows.append(row)


func describe(row: Dictionary) -> String:
	var who: String = "unowned" if int(row.get("source_actor", -1)) < 0 else "actor %d" % int(row["source_actor"])
	match String(row.channel):
		"health":
			return "t%-6d HEALTH %6.1f  %s from %s%s" % [row.tick, row.amount, row.damage_type, who,
				("  [%s]" % row["profile"]) if row.has("profile") else ""]
		"shield":
			return "t%-6d SHIELD %6.1f  absorbed from %s, meter %.1f left" % [row.tick, row.amount, who, row.meter_left]
		"shield_broken":
			return "t%-6d SHIELD BROKEN" % row.tick
		"status":
			return "t%-6d STATUS %6.1f  %s owned by %s" % [row.tick, row.amount, row.status, who]
	return ""


## The attribution, which is the point of the whole thing.
func summary() -> String:
	var total: float = health_damage + shield_damage + status_damage
	if total <= 0.0:
		return "DAMAGE LEDGER: nothing accepted."
	var lines: Array[String] = ["DAMAGE LEDGER — %d accepted events, %.1f total" % [rows.size(), total]]
	lines.append("   health %.1f (%.0f%%)   shield %.1f (%.0f%%)   status %.1f (%.0f%%)   shield breaks %d" % [
		health_damage, health_damage / total * 100.0,
		shield_damage, shield_damage / total * 100.0,
		status_damage, status_damage / total * 100.0,
		shield_breaks])
	# WHO, not merely how much. "Three enemies at once" and "one enemy hitting three times" are
	# different problems with different fixes and the same total.
	var by_actor: Dictionary = {}
	for row in rows:
		var key: int = int(row.get("source_actor", -1))
		by_actor[key] = float(by_actor.get(key, 0.0)) + float(row.amount)
	var actors: Array = by_actor.keys()
	actors.sort()
	for actor_id: int in actors:
		lines.append("   %-12s %.1f" % ["unowned" if actor_id < 0 else "actor %d" % actor_id, by_actor[actor_id]])
	return "\n".join(lines)


func reset() -> void:
	rows.clear()
	health_damage = 0.0
	shield_damage = 0.0
	status_damage = 0.0
	shield_breaks = 0


## THE LINE THE EVALUATOR ACTUALLY SEES, on the debug HUD, updated while they play.
##
## THE FIRST VERSION OF THIS LEDGER PRINTED ONLY ON DEATH, and the human's next replay did not
## die -- so a working instrument reported nothing and read as "no damage happened". Recording and
## being observable are two different questions, and only the first had been proven.
func compact() -> String:
	var total: float = health_damage + shield_damage + status_damage
	if total <= 0.0:
		return "damage: none yet"
	return "damage %.0f = hp %.0f · shield %.0f · status %.0f%s" % [
		total, health_damage, shield_damage, status_damage,
		("  · %d shield breaks" % shield_breaks) if shield_breaks > 0 else ""]
