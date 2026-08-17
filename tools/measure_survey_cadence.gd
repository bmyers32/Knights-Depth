extends SceneTree
## P29 second-cycle item 2 — SURVEY CADENCE measurement.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_survey_cadence.gd
##
## Playtest finding: "the Watcher shoots too often and still feels too interval-driven."
## Originally written to measure survey-to-survey cadence and size a fire_interval change.
## That cadence proposal was REJECTED in favour of contextual selection, so this tool's job
## is now the inverse: demonstrating that Survey is NOT periodic. It measures cadence and
## candidate fire_interval values — so the proposal is evidence rather
## than arithmetic. It changes nothing: candidates are applied to the sim's RESOLVED
## profile at setup, never to any .tres.
##
## The Watcher is pinned at a fixed range inside its survey band with speed 0, isolating
## cadence from locomotion. Loaded dynamically for the usual `-s`/autoload reason.

const PLAYER_ID: int = 0
const WATCHER_ID: int = 1
const TICKS: int = 900
const RANGE: float = 6.0
const CANDIDATES: Array = [45, 60, 80, 90]

static var EMPTY: Array[Command] = []


func _init() -> void:
	var n: int = 0
	while Engine.get_main_loop() == null and n < 20:
		await create_timer(0.01).timeout
		n += 1

	var SimWorldScript: GDScript = load("res://game/sim/sim_world.gd")
	var Registrar: GDScript = load("res://game/content/content_registrar.gd")
	var db: Object = get_root().get_node("ContentDB")
	var survey: Resource = db.get_resource(&"natural_weapon", &"watcher_survey")

	print("\n=== P29 survey cadence ===")
	print("windup_ticks = %d   authored fire_interval_ticks = %d   (30 Hz sim)\n" % [survey.windup_ticks, survey.fire_interval_ticks])

	for interval in CANDIDATES:
		var result: Dictionary = _measure(SimWorldScript, Registrar, int(interval))
		var fires: int = int(result.fires)
		var gaps: Array = result.gaps
		# Distinguish the three cases explicitly. Since Survey became contextual, ONE fire
		# is the expected healthy result -- the episode grants a single fallback, so there is
		# no recurring cadence to measure at all. Reporting that as "no surveys observed"
		# would read as a broken mechanic when it is the mechanic working.
		if fires == 0:
			print("  interval %3d ->  NO SURVEY AT ALL in %ds -- gate never opened" % [interval, TICKS / 30])
			continue
		if gaps.is_empty():
			print("  interval %3d ->  EXACTLY 1 survey in %ds -- NOT PERIODIC (one fallback per failed-close episode; the episode never cleared because close range was never re-established)" % [interval, TICKS / 30])
			continue
		var total: int = 0
		for g in gaps:
			total += int(g)
		var mean: float = float(total) / float(gaps.size())
		var marker: String = "   <-- authored today" if int(interval) == survey.fire_interval_ticks else ""
		print("  interval %3d ->  fire-to-fire %5.1f ticks (%.2f s)   post-survey silence %d ticks (%.2f s)   surveys in %ds: %d%s" % [
			interval, mean, mean / 30.0, int(interval), float(interval) / 30.0, TICKS / 30, fires, marker])

	print("\nNote: post-survey silence gates the WHOLE repertoire (shared per-actor cooldown),")
	print("      so it is also the window in which the Watcher can close to melee unpunished.")
	print("=== end ===\n")
	quit(0)


## Returns {"fires": int, "gaps": Array} -- the fire COUNT alongside the gaps, so a single
## non-periodic fire can never be reported as "nothing happened".
func _measure(SimWorldScript: GDScript, Registrar: GDScript, interval: int) -> Dictionary:
	var sim: Object = SimWorldScript.new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	sim.add_entity(PLAYER_ID, Vector3.ZERO, 0.0)
	sim.register_combatant(PLAYER_ID, 1000000.0, &"envoy", 0, 0.45, &"player")
	Registrar.register_enemy_body(sim, WATCHER_ID, &"watcher", Vector3(0, 0, -RANGE))
	Registrar.register_enemy_ai(sim, WATCHER_ID, &"watcher", Vector3(0, 0, -RANGE))
	# Pin it: speed 0 so it cannot close out of its own survey band mid-measurement.
	sim._move_speeds[WATCHER_ID] = 0.0
	# Candidate interval applied to the RESOLVED profile only -- content is untouched.
	sim._weapons["watcher_survey"].fire_interval_ticks = interval
	sim.debug_set_ai_active(WATCHER_ID)

	var fire_ticks: Array = []
	for _t in TICKS:
		for event in sim.tick(EMPTY, 1.0 / 30.0):
			if event.kind == "projectile_fired":
				fire_ticks.append(event.tick)
	var gaps: Array = []
	for i in range(1, fire_ticks.size()):
		gaps.append(int(fire_ticks[i]) - int(fire_ticks[i - 1]))
	return {"fires": fire_ticks.size(), "gaps": gaps}
