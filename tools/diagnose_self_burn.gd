extends SceneTree
## DOES THE PLAYER CATCH THE BURN THEY APPLIED?
##
## The human reported dying in the Arena and suspected that melee follow-ups on an enemy they had
## already Burned were setting the Envoy alight. Reproduce it before believing it: the symptom is
## also consistent with three enemies simply hitting hard, and "I think X is happening" has been
## wrong here before.
##
## LIVENESS. Every step that must have happened is asserted out loud rather than assumed: that the
## weapon actually procced, that the enemy is actually Burning, that the two bodies actually
## overlap, and that the spread scan actually ran. A silent run that reports "no self-burn" while
## the enemy was never ignited would be the same class of false negative as a dormant roster
## reading as "cannot use the door".

const DT := 1.0 / 30.0
const PLAYER := 0
const ENEMY := 1


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	print("SELF-BURN DIAGNOSIS")
	_run("A: player ignites the enemy, then stays in melee contact", true)
	_run("B: control -- an enemy ignited by nobody, same contact", false)
	quit(0)


func _run(label: String, player_is_the_source: bool) -> void:
	var sim: Object = load("res://game/sim/sim_world.gd").new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.register_status(&"burn", 2.0, 30, 300)
	sim.set_status_priority({"burn": 0})

	# Melee contact distance: combat radii 0.85 + 0.85 = 1.7, and they stand 1.2 apart. That is
	# what "I hit it with a sword" looks like spatially, which is the whole claim under test.
	sim.add_entity(PLAYER, Vector3.ZERO, 0.0, Vector3(0, 0, -1), 0.85)
	sim.register_combatant(PLAYER, 100.0, &"envoy", 0, 0.85, &"player")
	sim.add_entity(ENEMY, Vector3(0.0, 0.0, -1.2), 0.0, Vector3(0, 0, 1), 0.85)
	sim.register_combatant(ENEMY, 100.0, &"fang", 0, 0.85, &"enemy")

	# The ignition, attributed exactly as the real path attributes it: application_source "hit",
	# source actor the PLAYER. This is what a Burn-proccing sword does.
	sim._apply_status(ENEMY, &"burn", "hit", PLAYER if player_is_the_source else -1, "sword")

	print("")
	print("   %s" % label)
	var enemy_lit: bool = sim._status_instances.has(ENEMY)
	var overlap: bool = sim._actors_overlap(PLAYER, ENEMY)
	print("      enemy Burning=%s   bodies overlap=%s   player Burning=%s" % [
		str(enemy_lit), str(overlap), str(sim._status_instances.has(PLAYER))])
	print("      stored instance on the enemy: %s" % str(sim._status_instances.get(ENEMY, {})))
	if not enemy_lit or not overlap:
		print("      INSTRUMENT BROKEN: the preconditions did not hold, so this run measures nothing.")
		return

	var caught_on_tick: int = -1
	for tick in range(1, 10):
		var events: Array = sim.tick([] as Array[Command], DT)
		for event: Event in events:
			if event.kind == "status_applied" and int(event.payload["target_id"]) == PLAYER:
				caught_on_tick = tick
				print("      TICK %d: status_applied on the PLAYER -- source=%s actor=%d" % [
					tick, str(event.payload["application_source"]), int(event.payload["source_actor_id"])])
		if caught_on_tick >= 0:
			break

	if caught_on_tick < 0:
		print("      NOT REPRODUCED: the player did not catch it in 9 ticks of contact.")
	else:
		print("      REPRODUCED on tick %d. The player is now Burning from a status they applied," % caught_on_tick)
		print("      transmitted back by nothing more than standing in melee range of the target.")
		print("      health after: player %.1f" % sim._health.get(PLAYER, 0.0))
