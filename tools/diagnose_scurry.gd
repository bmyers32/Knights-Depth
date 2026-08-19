extends SceneTree
## Measures the SHIPPED Fang scurry against a representative triggered-retreat scenario.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_scurry.gd
##
## The test suite pins mechanical laws with synthetic values on purpose; this answers the
## separate question of whether the AUTHORED 2.5/45/0.30/15/18/90 actually produce the
## intended spacing outcome in play. Numbers here are observations for a playtest to judge,
## never a substitute for one — and per the P17 spec, "returns to bite range" is the intended
## outcome of THIS representative scenario, not a universal guarantee.

const PLAYER_ID: int = 0
const FANG_ID: int = 1
const DT: float = 1.0 / 30.0


const START_DISTANCES: Array = [1.65, 6.0]


func _init() -> void:
	var iterations: int = 0
	while Engine.get_main_loop() == null and iterations < 20:
		await create_timer(0.01).timeout
		iterations += 1

	for start_distance: float in START_DISTANCES:
		_measure(start_distance)
	quit(0)


func _measure(start_distance: float) -> void:
	print("
--- Fang starts %.2f units away, player retreats from tick 0 ---" % start_distance)
	var sim: Object = load("res://game/sim/sim_world.gd").new()
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")

	var envoy_stats: Resource = db.get_resource(&"envoy", &"default")
	sim.add_entity(PLAYER_ID, Vector3.ZERO, envoy_stats.move_speed)
	sim.register_combatant(PLAYER_ID, envoy_stats.max_health, envoy_stats.family, 0, envoy_stats.combat_radius, &"player")
	registrar.register_enemy_body(sim, FANG_ID, &"fang", Vector3(0, 0, -start_distance))
	registrar.register_enemy_ai(sim, FANG_ID, &"fang", Vector3(0, 0, -start_distance))

	print("envoy speed %.2f  fang speed %.2f  -> permanent deficit %.2f u/s" % [
		envoy_stats.move_speed, db.get_resource(&"enemy", &"fang").move_speed,
		envoy_stats.move_speed - db.get_resource(&"enemy", &"fang").move_speed])

	var commit_tick: int = -1
	var gap_at_commit: float = 0.0
	var displace_end_tick: int = -1
	var gap_at_displace_end: float = 0.0
	var settle_end_tick: int = -1

	for tick in 600:
		var commands: Array = [Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3(0, 0, 1)})]
		var typed: Array[Command] = []
		typed.assign(commands)
		var events: Array = sim.tick(typed, DT)
		var gap: float = sim.entities[FANG_ID].distance_to(sim.entities[PLAYER_ID])
		for event in events:
			if event.kind == "scurry_committed" and commit_tick == -1:
				commit_tick = event.tick
				gap_at_commit = gap
			elif event.kind == "scurry_ended" and displace_end_tick == -1:
				displace_end_tick = event.tick
				gap_at_displace_end = gap
				settle_end_tick = int(sim._scurry_settle_until_tick.get(FANG_ID, -1))
		if displace_end_tick != -1 and tick > displace_end_tick + 40:
			break

	if commit_tick == -1:
		print("  NO COMMITMENT in 600 ticks")
		return

	print("committed          tick %d (%.2f s of retreat)  gap %.2f" % [commit_tick, commit_tick * DT, gap_at_commit])
	print("displacement ended tick %d (%.2f s later)      gap %.2f" % [displace_end_tick, (displace_end_tick - commit_tick) * DT, gap_at_displace_end])
	print("net closure        %.2f units" % (gap_at_commit - gap_at_displace_end))
	print("settle until       tick %d (%.2f s punish window)" % [settle_end_tick, (settle_end_tick - displace_end_tick) * DT])
	print("  final gap vs bite range %.2f" % db.get_resource(&"enemy", &"fang").preferred_attack_distance)
