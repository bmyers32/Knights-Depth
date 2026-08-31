extends SceneTree
## PURSUIT ZIGZAG + RETURN-CORNER REPRO (human findings 2026-08-31). MECHANISM BEFORE ANY FIX.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_moving_target_pursuit.gd
##
## TWO SYMPTOMS, INSTRUMENTED TOGETHER because they may share one cause:
##   1. the Ooze rubs around a corner while RETURNING home
##   2. during ordinary pursuit it visibly zig-zags / realigns repeatedly, appearing to follow
##      without approaching naturally
##
## THE DISCRIMINATING VARIABLE is target motion. P33 was validated entirely against a STATIONARY
## target; the human load was a moving player. So the same geometry is driven twice:
##
##   CASE A  stationary target -- the validated load
##   CASE B  moving player     -- the observed load
##
## Per tick this records: requested vector, detector result, selected waypoint, commit/clear
## events with reason, commitment lifetime, target displacement, whether avoidance re-enters
## immediately after clearing, and real progress toward the target.
##
## NO SMOOTHING, NO HYSTERESIS, NO SELECTOR CHANGE is proposed or applied here. If the mechanism
## turns out to be mathematically fine but visibly indecisive, that is a DESIGN finding to
## return, not something to tune away.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0
const ENEMY: int = 1
const RADIUS: float = 1.45
const SPEED: float = 1.5
const TICKS: int = 400

## The shipped fight space: arena -> neck -> approach, with the pursuer off-axis beside the jamb.
const ARENA := Rect2(-15.0, -68.0, 30.0, 20.0)
const NECK := Rect2(-2.5, -49.5, 5.0, 9.0)
const APPROACH := Rect2(-6.0, -42.0, 12.0, 6.0)


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	print("MOVING-TARGET PURSUIT DIAGNOSTIC — same geometry, two target loads\n")
	_case("A  STATIONARY target (the validated P33 load)", false, false)
	_case("B  MOVING player (the observed load)", true, false)
	_case("C  RETURN home, disengaged, around the same corner", false, true)
	print("\nREAD THIS AS MECHANISM, NOT AS A VERDICT. A high realign count with steady progress")
	print("is an APPEARANCE problem; a high realign count with stalled progress is a mechanism")
	print("problem. They want different answers and must not be conflated.")
	quit(0)


func _case(label: String, target_moves: bool, return_home: bool) -> void:
	var sim_script: GDScript = load("res://game/sim/sim_world.gd")
	var bounds_script: GDScript = load("res://game/sim/walkable_bounds.gd")
	var helpers: GDScript = load("res://tests/helpers/combat_test_helpers.gd")
	var rects: Array[Rect2] = [ARENA, NECK, APPROACH]

	var sim: Object = sim_script.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.load_floor(bounds_script.new(rects), Vector3.ZERO)
	sim.register_patches(rects)

	var player_at := Vector3(0.0, 0.0, -43.0)
	var enemy_at := Vector3(-5.0, 0.0, -50.0)
	sim.add_entity(PLAYER, player_at, 0.0, Vector3(0, 0, -1), 0.4)
	sim.register_combatant(PLAYER, 5000.0, &"envoy", 0, 0.4, &"player")
	sim.mark_run_persistent(PLAYER)
	sim.add_entity(ENEMY, enemy_at, SPEED, Vector3(0, 0, -1), RADIUS)
	sim.register_combatant(ENEMY, 500.0, &"ooze", 0, RADIUS, &"enemy")
	sim.register_weapon(&"t", 5.0, &"force", 1.9, 90.0, 0.0, 9999)
	# Detection is generous for A and B, and DELIBERATELY TINY for C. A first pass gave C the
	# same 40-unit detection and the actor simply ACQUIRED the player 21 units away -- so it was
	# chasing, not returning, and its "negative progress" was correct pursuit under the new
	# ruling. Confirm the mechanism you meant to measure is the one running.
	var detection: float = 5.0 if return_home else 40.0
	sim.register_ai(ENEMY, helpers.single_action_repertoire(&"t", 1.9, 10000),
		enemy_at, 2.2, 1.9, detection, 80.0, 0, 0, 0.0, 0.0, 0, 0.0, 0, 0, 0, 45)
	sim._next_fire_tick[ENEMY] = 1_000_000

	if return_home:
		# Home is the ARENA; the actor starts up the neck and must come back round the jamb.
		var home: Array[Rect2] = [ARENA]
		sim.register_encounter(0, home, &"ambient", false, true)
		sim.entities[ENEMY] = Vector3(-5.0, 0.0, -60.0)
		sim.assign_actor_encounter(ENEMY, 0)
		sim.entities[ENEMY] = Vector3(-1.5, 0.0, -45.0)  # bumped up the neck, outside home
		sim.entities[PLAYER] = Vector3(0.0, 0.0, -39.0)  # far enough to stay disengaged
	else:
		sim.debug_set_ai_active(ENEMY)

	var empty: Array = Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))
	var commits: int = 0
	var clears: Dictionary = {}
	var detector_fired: int = 0
	var realigns: int = 0
	var immediate_reentry: int = 0
	var lifetimes: Array = []
	var committed_since: int = -1
	var last_direction := Vector3.ZERO
	var cleared_last_tick: bool = false
	var start: Vector3 = sim.entities[ENEMY]
	var target_travel: float = 0.0

	for tick in TICKS:
		var before: Vector3 = sim.entities[ENEMY]
		var goal: Vector3 = sim.entities[PLAYER]
		if return_home:
			goal = sim._nearest_home_point(ENEMY)
		if not sim._direct_route_obstruction(ENEMY, goal).is_empty():
			detector_fired += 1

		var was_committed: bool = sim._ai_avoid_waypoint.has(ENEMY)
		var events: Array = sim.tick(empty, DT)
		for event in events:
			if event.kind == "avoidance_committed":
				commits += 1
				if cleared_last_tick:
					immediate_reentry += 1
				committed_since = tick
			elif event.kind == "avoidance_cleared":
				var reason: String = String(event.payload["reason"])
				clears[reason] = int(clears.get(reason, 0)) + 1
				if committed_since >= 0:
					lifetimes.append(tick - committed_since)
				cleared_last_tick = true
		if not events.any(func(e): return e.kind == "avoidance_cleared"):
			cleared_last_tick = false

		var after: Vector3 = sim.entities[ENEMY]
		var moved: Vector3 = after - before
		if moved.length() > 0.0001:
			var direction: Vector3 = moved.normalized()
			# A "realign" is a heading change sharper than ~25 degrees between consecutive ticks.
			if last_direction != Vector3.ZERO and direction.dot(last_direction) < 0.9:
				realigns += 1
			last_direction = direction

		if target_moves:
			# Strafe the player laterally, the shape a human actually produces while fighting.
			var wobble: float = sin(float(tick) * 0.06) * 2.5
			sim.entities[PLAYER] = player_at + Vector3(wobble, 0.0, 0.0)
			target_travel += absf(cos(float(tick) * 0.06) * 0.06 * 2.5)

	var goal_now: Vector3 = sim._nearest_home_point(ENEMY) if return_home else sim.entities[PLAYER]
	var closed: float = start.distance_to(goal_now) - sim.entities[ENEMY].distance_to(goal_now)
	var mean_life: float = 0.0
	for life in lifetimes:
		mean_life += float(life)
	mean_life = 0.0 if lifetimes.is_empty() else mean_life / float(lifetimes.size())

	print("CASE %s" % label)
	print("   ai_state            %s" % sim._ai_state.get(ENEMY, "?"))
	print("   detector fired      %d of %d ticks" % [detector_fired, TICKS])
	print("   commits             %d   (immediate re-entry after a clear: %d)" % [commits, immediate_reentry])
	print("   clear reasons       %s" % clears)
	print("   mean commitment     %.1f ticks" % mean_life)
	print("   heading realigns    %d  (>25 deg turn between consecutive ticks)" % realigns)
	print("   net progress        %.2f u toward goal   final gap %.2f" % [closed, sim.entities[ENEMY].distance_to(goal_now)])
	print("   target travelled    %.2f u" % target_travel)
	print("")
