extends SceneTree
## PURSUIT AROUND A CENTRAL BLOCK (2026-10-13). INSTRUMENT BEFORE AUTHORING.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/measure_block_pursuit.gd
##
## The Foundry's circular chamber wants a non-walkable machine in the middle of its main fight.
## Pursuit has a ONE-waypoint detour and no pathfinder, and a target standing directly across a
## block can need two turns to reach. This measures whether the shipped enemies actually arrive,
## for a range of block sizes, before a floor is authored around the answer.
##
## Reports only. Nothing is tuned from this and no navigation system is implied by running it.
##
## FIXED WINDOW, and the trace says whether the enemy was ENGAGED: a flat zero from an idle enemy
## looks exactly like a pinned one (HANDOFF trap list).
##
## Loaded DYNAMICALLY: a `-s` script compiles before autoloads register.

const PLAYER_ID: int = 0
const ENEMY_ID: int = 100
const DT: float = 1.0 / 30.0
const WINDOW_TICKS: int = 600
const ROOM := Rect2(0.0, 0.0, 40.0, 40.0)
const BLOCK_SIZES: Array[float] = [0.0, 3.0, 4.0, 6.0, 8.0, 10.0]
## How far each actor stands off the block's face. Small on purpose: an activated roster still
## obeys its leash (18 from its anchor), so a target 30 units away is simply not chased and a
## trace of that measures the leash, not the block. A first pass did exactly that.
const STAND_OFF: float = 3.0


## [label, enemy start, player position], placed either side of a block of this size. The
## 0-size row keeps the 3-unit placement so it is a like-for-like control with nothing in the way.
func _cases(size: float) -> Array:
	var reach: float = maxf(size, 3.0) * 0.5 + STAND_OFF
	var c := Vector3(ROOM.get_center().x, 0.0, ROOM.get_center().y)
	return [
		["across z", c + Vector3(0, 0, -reach), c + Vector3(0, 0, reach)],
		["across x", c + Vector3(-reach, 0, 0), c + Vector3(reach, 0, 0)],
		["off-axis", c + Vector3(0, 0, -reach), c + Vector3(reach * 0.5, 0, reach)],
		["diagonal", c + Vector3(-reach, 0, -reach), c + Vector3(reach, 0, reach)],
	]


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	print("room %s, window %d ticks. 'reach' = closest approach to the player; 'pinned' = ticks" % [ROOM, WINDOW_TICKS])
	print("spent engaged, out of range, and moving less than half a step.")
	print("")
	for enemy_key: StringName in [&"fang", &"ooze", &"watcher"]:
		var stats: Resource = db.get_resource(&"enemy", enemy_key)
		print("%s  radius %.2f  speed %.2f  detection %.1f" % [enemy_key, stats.combat_radius, stats.move_speed, stats.detection_radius])
		for size: float in BLOCK_SIZES:
			var line: String = "  block %4.1f |" % size
			for case: Array in _cases(size):
				line += " %s %s |" % [case[0], _measure(db, enemy_key, size, case[1], case[2])]
			print(line)
		print("")
	quit(0)


func _measure(db: Object, enemy_key: StringName, size: float, enemy_at: Vector3, player_at: Vector3) -> String:
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var sim: Object = load("res://game/sim/sim_world.gd").new()
	var bounds_script: GDScript = load("res://game/sim/walkable_bounds.gd")
	sim.set_damage_matrix({}, 1.5, 0.5)

	var rooms: Array[Rect2] = [ROOM]
	var blocks: Array[Rect2] = []
	if size > 0.0:
		blocks.append(Rect2(ROOM.get_center() - Vector2(size, size) * 0.5, Vector2(size, size)))

	var envoy: Resource = db.get_resource(&"envoy", &"default")
	sim.add_entity(PLAYER_ID, player_at, envoy.move_speed, Vector3(0, 0, -1), envoy.combat_radius)
	# Survivable on purpose: this measures arrival, and a dead target ends the chase.
	sim.register_combatant(PLAYER_ID, 1000000.0, envoy.family, 0, envoy.combat_radius, &"player")
	sim.mark_run_persistent(PLAYER_ID)
	sim.load_floor(bounds_script.new(rooms, blocks), player_at)
	sim.register_patches(rooms)
	sim.register_obstacles(blocks)
	sim.register_encounter(0, rooms, &"mandatory", true, true)

	registrar.register_enemy_body(sim, ENEMY_ID, enemy_key, enemy_at)
	registrar.register_enemy_ai(sim, ENEMY_ID, enemy_key, enemy_at)
	sim.assign_actor_encounter(ENEMY_ID, 0)
	# ACTIVATED, the way a party plate does it: a confined roster member of a live encounter
	# never consults its leash. Forcing the AI state alone left every enemy leashed at its spawn
	# -- a flat zero that read as "pinned" and was nothing of the kind.
	sim.debug_activate_encounter(0)

	var stats: Resource = db.get_resource(&"enemy", enemy_key)
	var full_step: float = stats.move_speed * DT
	var closest: float = enemy_at.distance_to(player_at)
	var pinned: int = 0
	var engaged: bool = false
	var commands: Array = Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))
	for tick in WINDOW_TICKS:
		var before: Vector3 = sim.entities[ENEMY_ID]
		sim.tick(commands, DT)
		var after: Vector3 = sim.entities[ENEMY_ID]
		var distance: float = after.distance_to(player_at)
		closest = minf(closest, distance)
		if String(sim._ai_state.get(ENEMY_ID, "")) == "active" and before.distance_to(after) > 0.0:
			engaged = true
		# Further out than it wants to attack from, so standing still is not "holding its distance".
		if distance > stats.preferred_attack_distance + 1.5 and before.distance_to(after) < full_step * 0.5:
			pinned += 1
	return "reach %5.1f pinned %3d%s" % [closest, pinned, "" if engaged else " NEVER MOVED"]
