extends SceneTree
## WHY DOES A ROSTER MEMBER OF AN ACTIVE, SEALING ENCOUNTER GO INERT?
##
## The Arena's second wave spawned, engaged, and then stood still. That was "explained" by the
## authored positions being far from the player, and a roster-clustering workaround made the
## symptom go away -- which is exactly the shape of a fix that hides a law conflict. This
## reproduces the failure at the smallest scale that is still REAL: one sealing encounter, one
## roster member, ordinary activation, ordinary ticks.
##
## LIVENESS FIRST. Every previous diagnostic in this project that produced a confident wrong
## headline did so because the mechanism under test was never running -- a dormant roster read as
## "cannot use the door", a windup-locked actor read as a stall, a melee command that never
## resolved read as a dead switch. So this prints, every tick: the encounter's state, the actor's
## life, the confinement, whether the AI step actually produced Commands, and a CONTROL actor
## placed close enough that it must stay engaged. If the control ever goes inert too, the
## instrument is broken and the run says so instead of blaming the floor.

const DT := 1.0 / 30.0
const ROOM := Rect2(-30.0, -30.0, 60.0, 60.0)
const ENCOUNTER := 7
const FAR := 1
const NEAR := 2
const PLAYER := 0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var sim: Object = load("res://game/sim/sim_world.gd").new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(WalkableBounds.new([ROOM] as Array[Rect2], [] as Array[Rect2]), Vector3.ZERO)
	# THE PATCH MATTERS. An encounter clips its authored region against the floor's PATCHES, so a
	# fixture that registers none stores a territory with zero rects -- which is missing data
	# wearing the shape of an answer. The first run of this tool made that mistake and the
	# control actor went inert alongside the subject, which is what a control is for.
	sim.register_patches([ROOM] as Array[Rect2])

	sim.add_entity(PLAYER, Vector3(0.0, 0.0, 20.0), 4.0, Vector3(0, 0, -1), 0.85)
	sim.register_combatant(PLAYER, 100.0, &"envoy", 0, 0.85, &"player")

	# A SEALING encounter covering the whole room: the player cannot leave, so no honest reading
	# of "the player wandered off" is available to explain a disengage.
	sim.register_encounter(ENCOUNTER, [ROOM] as Array[Rect2], FloorLayers.ROLE_MANDATORY, true, true)
	_add(sim, FAR, Vector3(0.0, 0.0, -8.0))    # 28 from the player: beyond detection AND leash
	_add(sim, NEAR, Vector3(0.0, 0.0, 14.0))   # 6 from the player: the control

	print("ENCOUNTER ENGAGEMENT DIAGNOSIS")
	print("   room %s   player at %s" % [ROOM, sim.entities[PLAYER]])
	var tuning: Dictionary = sim._ai_tuning[FAR]
	print("   tuning: detection %.1f   leash %.1f" % [tuning.detection_radius, tuning.leash_radius])
	for actor_id in [FAR, NEAR]:
		print("   actor %d spawn %s -> %.1f from the player" % [
			actor_id, sim._ai_spawn_position[actor_id],
			(sim.entities[PLAYER] - sim._ai_spawn_position[actor_id]).length()])

	var terr = sim._encounter_bounds.get(ENCOUNTER, null)
	print("   territory rects: %s   player inside=%s" % [
		str(terr.rects) if terr != null else "NULL",
		str(terr.is_inside(sim.entities[PLAYER])) if terr != null else "n/a"])
	print("")
	print("   BEFORE ACTIVATION")
	_report(sim, -1)

	sim.debug_activate_encounter(ENCOUNTER)
	print("   AT ACTIVATION (no tick yet)")
	_report(sim, 0)

	for tick in range(1, 6):
		sim.tick([] as Array[Command], DT)
		_report(sim, tick)

	print("")
	print("   VERDICT")
	var far_state: String = String(sim._ai_state.get(FAR, ""))
	var near_state: String = String(sim._ai_state.get(NEAR, ""))
	if near_state != "active":
		print("   INSTRUMENT BROKEN: the CONTROL actor went inert too, so this run measures the")
		print("   fixture rather than the law. Do not draw a conclusion from it.")
	elif far_state == "active":
		print("   NO DEFECT REPRODUCED at this distance -- re-check the predicate before ruling.")
	else:
		var spawn_to_player: float = (sim.entities[PLAYER] - sim._ai_spawn_position[FAR]).length()
		print("   REPRODUCED. The control stayed engaged throughout, so the AI step was live and")
		print("   the far actor's transition is real, not an artefact of nothing running.")
		print("")
		print("   PREDICATE: _advance_ai, state == \"active\" branch --")
		print("     (player_position - _ai_spawn_position[actor]).length() > tuning.leash_radius")
		print("     %.1f > %.1f  ->  _ai_state = \"idle\"" % [spawn_to_player, tuning.leash_radius])
		print("")
		print("   The leash is measured from the actor's SPAWN ANCHOR to the PLAYER, and it is")
		print("   evaluated for EVERY active actor with no reference to encounter membership.")
		print("   Encounter state is consulted in exactly one place in _advance_ai -- the DORMANT")
		print("   guard -- so an ACTIVE encounter's roster is governed by ambient territory rules")
		print("   the instant after activation engages it.")
	quit(0)


func _add(sim: Object, actor_id: int, at: Vector3) -> void:
	sim.add_entity(actor_id, at, 4.0, Vector3(0, 0, 1), 0.85)
	sim.register_combatant(actor_id, 500.0, &"watcher", 0, 0.85, &"enemy")
	sim.register_weapon(&"probe_bite", 5.0, &"force", 2.0, 90.0, 0.0, 9999)
	# Detection 10 / leash 18: the shipped Fang and Ooze values, not invented ones.
	sim.register_ai(actor_id, CombatTestHelpers.single_action_repertoire(&"probe_bite", 2.0, 10000),
		at, 2.2, 1.9, 10.0, 18.0, 0, 0, 0.0, 0.0, 0, 0.0, 0, 0, 0, 45)
	if not sim.assign_actor_encounter(actor_id, ENCOUNTER):
		push_error("fixture: actor %d did not bind to its site -- the run is invalid" % actor_id)


func _report(sim: Object, tick: int) -> void:
	var label: String = "pre" if tick < 0 else str(tick)
	print("   tick %-4s encounter=%-8s confinement=%-3d  FAR=%-7s alive=%s  NEAR=%-7s alive=%s" % [
		label,
		String(sim._encounter_state.get(ENCOUNTER, "?")),
		int(sim.debug_describe_floor()["active_confinement"]),
		String(sim._ai_state.get(FAR, "-")), str(sim._health.get(FAR, 0.0) > 0.0),
		String(sim._ai_state.get(NEAR, "-")), str(sim._health.get(NEAR, 0.0) > 0.0)])
