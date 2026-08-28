extends SceneTree
## THE PRE-REGISTERED SELECTOR PROOF (P17), on SHIPPED content, before any human play.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/prove_burrow_selector.gd
##
## Scurry's detector was falsified by an autopsy that should have run BEFORE the playtest: it
## measured radial separation and never armed under the kite shapes players actually use. This
## runs the equivalent check first, against the seven cases registered in advance.
##
## GEOMETRY NAMED HONESTLY: the arena has no walls, so there is no "wall-hug" case to exercise.
## The low-closure-rate case is SUSTAINED STRAIGHT-LINE RETREAT at ordinary move speed, where
## the gap is governed purely by the speed differential (Envoy 4.0 vs Fang 3.0).
##
## Reports only. No value is tuned from these results.

const PLAYER_ID: int = 0
const FANG_ID: int = 1
const DT: float = 1.0 / 30.0

var _passes: int = 0
var _failures: Array = []


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var fang: Resource = db.get_resource(&"enemy", &"fang")
	print("shipped: close_frustration_ticks %d   close band [0, %.2f]   cooldown %d   emergence radius %.2f" % [
		fang.close_frustration_ticks, fang.preferred_attack_distance,
		fang.burrow_cooldown_ticks, fang.burrow_emergence_radius])
	print("envoy %.2f vs fang %.2f  -> straight-retreat closure rate %.2f u/s\n" % [
		db.get_resource(&"envoy", &"default").move_speed, fang.move_speed,
		fang.move_speed - db.get_resource(&"envoy", &"default").move_speed])

	_case_fires("diagonal kiting", "diagonal", 600)
	_case_standoff()
	_case_fires("straight-line retreat at ordinary speed", "retreat", 600)
	_case_quiet("ordinary successful close engagement", "engage", 600)
	_case_reset_on_reacquire()
	_case_consumption_blocks_repeat()
	_case_cooldown_suppresses_rebuilt_episode()

	print("\n%d passed, %d failed" % [_passes, _failures.size()])
	for entry in _failures:
		print("  FAILED: " + entry)
	quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  PASS  " + label)
	else:
		_failures.append(label)
		print("  FAIL  " + label)


func _build() -> Object:
	var sim: Object = load("res://game/sim/sim_world.gd").new()
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var envoy_stats: Resource = db.get_resource(&"envoy", &"default")
	sim.seed_combat_rng(20260828)
	sim.add_entity(PLAYER_ID, Vector3.ZERO, envoy_stats.move_speed)
	sim.register_combatant(PLAYER_ID, 100000.0, envoy_stats.family, 0, envoy_stats.combat_radius, &"player")
	registrar.register_enemy_body(sim, FANG_ID, &"fang", Vector3(0, 0, -5.0))
	registrar.register_enemy_ai(sim, FANG_ID, &"fang", Vector3(0, 0, -5.0))
	sim.debug_override_health(FANG_ID, 100000.0)
	return sim


func _direction(shape: String, player_position: Vector3, fang_position: Vector3) -> Vector3:
	var away: Vector3 = player_position - fang_position
	away.y = 0.0
	if away.length() < 0.001:
		away = Vector3(0, 0, 1)
	away = away.normalized()
	match shape:
		"diagonal":
			return away.rotated(Vector3.UP, deg_to_rad(45.0))
		"retreat":
			return away
		"standoff":
			return Vector3.ZERO       # stand still, far away: the Fang must close on its own
		"engage":
			return Vector3.ZERO       # stand still, near: the Fang reaches close range
	return Vector3.ZERO


## Runs a shape and returns the tick a selector burrow committed, or -1.
func _run(shape: String, ticks: int, start_gap: float) -> Dictionary:
	var sim: Object = _build()
	sim.entities[FANG_ID] = Vector3(0, 0, -start_gap)
	var committed: int = -1
	var elapsed_at_commit: int = -1
	for tick in ticks:
		var commands: Array[Command] = []
		var direction: Vector3 = _direction(shape, sim.entities[PLAYER_ID], sim.entities[FANG_ID])
		if direction.length() > 0.001:
			commands.append(Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": direction}))
		for event in sim.tick(commands, DT):
			if event.kind == "burrow_committed" and committed == -1:
				committed = event.tick
				elapsed_at_commit = int(event.payload.get("frustration_elapsed", -1))
		if committed != -1:
			break
	return {"sim": sim, "tick": committed, "elapsed": elapsed_at_commit}


func _case_fires(label: String, shape: String, ticks: int) -> void:
	print("--- MUST FIRE: %s ---" % label)
	var result: Dictionary = _run(shape, ticks, 8.0)
	_check(result.tick != -1, "%s selects a burrow (tick %s, frustration %s)" % [label, str(result.tick), str(result.elapsed)])


func _case_quiet(label: String, shape: String, ticks: int) -> void:
	print("--- MUST NOT FIRE: %s ---" % label)
	# Start inside the close band so the Fang is engaging from tick 0.
	var result: Dictionary = _run(shape, ticks, 1.2)
	_check(result.tick == -1, "%s never selects a burrow" % label)


## SUSTAINED STANDOFF, named honestly. A stationary player at range is NOT a standoff -- the
## Fang closes at 3.0 u/s and engages, which is successful engagement and must not burrow (that
## is the "engage" case). A genuine standoff is a HELD GAP, which requires the player to retreat
## at exactly the pursuer's speed. Realised here by matching the Envoy's speed to the Fang's, so
## the separation is constant and the Fang can never close.
func _case_standoff() -> void:
	print("--- MUST FIRE: sustained standoff (gap held constant) ---")
	var sim: Object = _build()
	sim._move_speeds[PLAYER_ID] = sim._move_speeds[FANG_ID]  # speed-matched: the gap never closes
	sim.entities[FANG_ID] = Vector3(0, 0, -8.0)
	var committed: int = -1
	for tick in 600:
		var away: Vector3 = (sim.entities[PLAYER_ID] - sim.entities[FANG_ID])
		away.y = 0.0
		var commands: Array[Command] = [Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": away.normalized()})]
		for event in sim.tick(commands, DT):
			if event.kind == "burrow_committed" and committed == -1:
				committed = event.tick
		if committed != -1:
			break
	_check(committed != -1, "sustained standoff selects a burrow (tick %s)" % str(committed))


func _case_reset_on_reacquire() -> void:
	print("--- EPISODE RESETS on disengage -> re-acquire ---")
	var sim: Object = _build()
	# Build REAL frustration by retreating, stopping short of the threshold so no burrow commits
	# and the episode under test is the one we built.
	for tick in 80:
		var away: Vector3 = (sim.entities[PLAYER_ID] - sim.entities[FANG_ID])
		away.y = 0.0
		sim.tick([Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": away.normalized()})] as Array[Command], DT)
	var before: Dictionary = sim.debug_describe_burrow_selection(FANG_ID, PLAYER_ID)
	# Leash out, forcing idle, then walk back into detection.
	sim.entities[PLAYER_ID] = Vector3(0, 0, 400.0)
	sim.tick([] as Array[Command], DT)
	var idle: bool = String(sim._ai_state[FANG_ID]) == "idle"
	sim.entities[PLAYER_ID] = sim.entities[FANG_ID] + Vector3(0, 0, 6.0)
	sim.tick([] as Array[Command], DT)
	sim.tick([] as Array[Command], DT)
	var after: Dictionary = sim.debug_describe_burrow_selection(FANG_ID, PLAYER_ID)
	_check(idle, "the Fang genuinely disengaged")
	_check(int(before.frustration_elapsed) > int(after.frustration_elapsed),
		"re-acquisition resets the episode (%d -> %d elapsed)" % [int(before.frustration_elapsed), int(after.frustration_elapsed)])
	_check(int(after.frustration_elapsed) < 5, "and it restarts from ~zero, not from a stale timestamp")


func _case_consumption_blocks_repeat() -> void:
	print("--- CONSUMPTION blocks repeat until genuine close-band re-entry ---")
	var result: Dictionary = _run("retreat", 600, 8.0)
	var sim: Object = result.sim
	_check(result.tick != -1, "a first burrow committed")
	# Keep retreating: the band is never re-entered, so the episode stays spent.
	var second: int = -1
	for tick in 900:
		var direction: Vector3 = _direction("retreat", sim.entities[PLAYER_ID], sim.entities[FANG_ID])
		var commands: Array[Command] = [Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": direction})]
		for event in sim.tick(commands, DT):
			if event.kind == "burrow_committed":
				second = event.tick
		if second != -1:
			break
	_check(second == -1, "no second burrow while the close band is never re-entered")
	var described: Dictionary = sim.debug_describe_burrow_selection(FANG_ID, PLAYER_ID)
	_check(bool(described.episode_spent), "and the snapshot reports the episode as SPENT, explaining why")


func _case_cooldown_suppresses_rebuilt_episode() -> void:
	print("--- COOLDOWN suppresses an otherwise-valid rebuilt episode ---")
	var result: Dictionary = _run("retreat", 600, 8.0)
	var sim: Object = result.sim
	_check(result.tick != -1, "a first burrow committed")
	# The cooldown arms at END OF DISPLACEMENT, not at commitment, so the burrow must run to
	# completion before there is a floor to test at all.
	for tick in 200:
		sim.tick([] as Array[Command], DT)
		if not sim._burrow.has(FANG_ID):
			break
	# Force the episode to look freshly rebuilt while the cooldown is still running: re-enter the
	# band (clears consumption), then re-age it past the threshold.
	sim._ai_last_in_close_band[FANG_ID] = sim.tick_count
	sim._ai_last_frustration_commit.erase(FANG_ID)
	sim._ai_last_in_close_band[FANG_ID] = sim.tick_count - 500
	var cooling: Dictionary = sim.debug_describe_burrow_selection(FANG_ID, PLAYER_ID)
	_check(int(cooling.cooldown_remaining) > 0, "the cooldown is still running")
	_check(int(cooling.frustration_elapsed) >= int(cooling.frustration_required), "and the episode is otherwise valid")
	_check(not bool(cooling.would_select), "yet the selector refuses -- cooldown is an independent floor")
