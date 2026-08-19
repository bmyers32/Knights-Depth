extends SceneTree
## Proves the P17 cutoff detector sees the EXACT movement shapes scurry v1 was blind to.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_cutoff_detector.gd
##
## v1's autopsy (ROADMAP P17) measured radial separation and recorded:
##     diagonal-45 kite  -> minimum refreshed on 886/900 ticks, NEVER fired
##     circling kite     -> NEVER fired
## Those are the two cases below, run against the SHIPPED Fang content. A detector that cannot
## see them is not a fix, whatever else it does.
##
## It also records the rollover boundary the spec flags: `recent_route` covers 2N ticks just
## before a bucket rollover and N just after, so its magnitude halves. Sustained travel below
## ~60% of full speed sits near the trust floor and can flicker. THIS IS OBSERVABILITY, NOT
## MITIGATION -- record the values, do not tune from them, and do not add hysteresis before a
## human verdict.

const PLAYER_ID: int = 0
const FANG_ID: int = 1
const DT: float = 1.0 / 30.0
const TICKS: int = 900

## The two v1 blind cases, plus a half-speed straight run to expose the rollover boundary.
const CASES: Array = ["diagonal-45", "circling", "straight-half-speed"]


func _init() -> void:
	var iterations: int = 0
	while Engine.get_main_loop() == null and iterations < 20:
		await create_timer(0.01).timeout
		iterations += 1

	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var route_tuning: Resource = db.get_resource(&"combat", &"route_tuning")
	var fang: Resource = db.get_resource(&"enemy", &"fang")
	print("route_window_ticks %d   cutoff_min_route_distance %.2f   envoy %.2f   fang %.2f" % [
		route_tuning.route_window_ticks, fang.cutoff_min_route_distance,
		db.get_resource(&"envoy", &"default").move_speed, fang.move_speed])
	print("\n%-20s %9s %9s %9s %9s %8s   %s" % ["case", "min |r|", "max |r|", "post-roll", "eligible%", "cutoffs", "verdict"])
	print("-".repeat(96))
	for case_name: String in CASES:
		_run(case_name, route_tuning.route_window_ticks, fang.cutoff_min_route_distance)
	print("\nv1 recorded NEVER FIRES for diagonal-45 and circling. Any 'SEES IT' above is the")
	print("detector change doing its job; it is NOT evidence the cutoff is fun. Human verdict only.")
	quit(0)


func _player_direction(case_name: String, player_position: Vector3, fang_position: Vector3) -> Vector3:
	var away: Vector3 = player_position - fang_position
	away.y = 0.0
	if away.length() < 0.001:
		away = Vector3(0, 0, 1)
	away = away.normalized()
	match case_name:
		"diagonal-45":
			return away.rotated(Vector3.UP, deg_to_rad(45.0))
		"circling":
			return away.rotated(Vector3.UP, deg_to_rad(90.0))
		"straight-half-speed":
			return away * 0.5  # a partial-magnitude direction: _apply_move normalizes, so drive it
	return away


func _run(case_name: String, window: int, trust_floor: float) -> void:
	var sim: Object = load("res://game/sim/sim_world.gd").new()
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")

	var envoy_stats: Resource = db.get_resource(&"envoy", &"default")
	var speed: float = envoy_stats.move_speed * (0.5 if case_name == "straight-half-speed" else 1.0)
	sim.seed_combat_rng(20260819)
	sim.set_route_window(window)
	sim.add_entity(PLAYER_ID, Vector3(4.0, 0.0, 0.0), speed)
	sim.register_combatant(PLAYER_ID, 100000.0, envoy_stats.family, 0, envoy_stats.combat_radius, &"player")
	registrar.register_enemy_body(sim, FANG_ID, &"fang", Vector3(0, 0, -4.0))
	registrar.register_enemy_ai(sim, FANG_ID, &"fang", Vector3(0, 0, -4.0))
	sim.debug_override_health(FANG_ID, 100000.0)

	var minimum: float = INF
	var maximum: float = 0.0
	var worst_post_rollover: float = INF
	var eligible_ticks: int = 0
	var sampled: int = 0
	var cutoffs: int = 0

	for tick in TICKS:
		var direction: Vector3 = _player_direction(case_name, sim.entities[PLAYER_ID], sim.entities[FANG_ID])
		var commands: Array[Command] = [Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": direction})]
		for event in sim.tick(commands, DT):
			if event.kind == "cutoff_committed":
				cutoffs += 1
		if tick <= window * 2:
			continue  # warm-up: the horizon has not filled yet
		var magnitude: float = sim.recent_route(PLAYER_ID).length()
		minimum = minf(minimum, magnitude)
		maximum = maxf(maximum, magnitude)
		sampled += 1
		if magnitude >= trust_floor:
			eligible_ticks += 1
		# The tick immediately after a bucket boundary is where the horizon is shortest.
		if sim.tick_count % window == 0:
			worst_post_rollover = minf(worst_post_rollover, magnitude)

	var eligible_percent: float = 100.0 * float(eligible_ticks) / float(maxi(1, sampled))
	var verdict: String = "SEES IT" if eligible_percent > 90.0 else ("FLICKERS" if eligible_percent > 5.0 else "BLIND")
	print("%-20s %9.2f %9.2f %9.2f %8.1f%% %8d   %s" % [
		case_name, minimum, maximum, worst_post_rollover, eligible_percent, cutoffs, verdict])
