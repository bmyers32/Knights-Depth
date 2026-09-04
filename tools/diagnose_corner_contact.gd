extends SceneTree
## CORNER SNAG — is it retired, or general? (ruled 2026-09-06, §I)
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_corner_contact.gd
##
## The human reported snagging while rounding the corner at the spike-lane entrance. That block
## has since been moved. Two possibilities, and they need separating:
##   A. RETIRED  -- it was that composition, and moving the block resolved it.
##   B. GENERAL  -- a reproducible wall-contact/corner movement issue independent of Floor 2.
##
## Tested against SYNTHETIC corners, deliberately: if the defect is general it must appear on
## geometry that has nothing to do with Floor 2, and if it only ever appears on one floor's
## coordinates then it was a layout problem.
##
## Reports only.

const DT: float = 1.0 / 30.0
const PLAYER: int = 0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	print("CORNER CONTACT — does a body slide along geometry, or stick to it?")
	print("")
	# PRESSING INTO A CONCAVE CORNER, as a control. Stopping here is CORRECT -- there is nowhere
	# to go -- and reporting it as a snag would be reading intended behaviour as a defect.
	_corner("control: pressed into a concave corner", Vector3(1, 0, -1), Vector3(-6.0, 0.0, -6.0),
		[Rect2(-2.0, -14.0, 24.0, 4.0), Rect2(8.0, -14.0, 4.0, 24.0)])
	# A flat face taken obliquely: the ordinary slide.
	_corner("oblique face", Vector3(1, 0, -1), Vector3(-6.0, 0.0, -6.0),
		[Rect2(-10.0, -14.0, 40.0, 4.0)])
	# THE REPORTED CASE: travelling ALONG a face and ROUNDING its outside corner. The player is
	# never pressing into geometry here -- they are moving past it -- so any stall is a snag.
	# CONTROL: driven straight into a face. Stopping is correct, and this case exists only so the
	# clean results below cannot be mistaken for the tool being unable to detect a stall at all.
	# Two earlier versions of this probe placed the body INSIDE the mass's own span and reported
	# the resulting head-on stop as a snag -- the same false headline twice.
	_corner("control: driven head-on into a face", Vector3(1, 0, 0), Vector3(-18.0, 0.0, -10.0),
		[Rect2(-10.0, -14.0, 12.0, 6.0)])
	# The same brush, but angled INTO the face while travelling along it -- the way a player
	# actually hugs a corner rather than tracing it perfectly.
	_corner("hugging a face while rounding it", Vector3(3, 0, -1), Vector3(-18.0, 0.0, -6.0),
		[Rect2(-10.0, -14.0, 12.0, 6.0)])
	# And the same, entering a gap between two masses -- the shape a lane mouth makes.
	_corner("threading a gap between two masses", Vector3(1, 0, 0), Vector3(-18.0, 0.0, -6.0),
		[Rect2(-10.0, -14.0, 12.0, 6.0), Rect2(-10.0, -2.0, 12.0, 6.0)])


func _corner(label: String, direction: Vector3, start: Vector3, masses: Array) -> void:
	var room: Array[Rect2] = [Rect2(-20.0, -30.0, 50.0, 40.0)]
	var sim: Object = load("res://game/sim/sim_world.gd").new()
	sim.set_damage_matrix({}, 1.5, 0.5)
	var blockers: Array[Rect2] = []
	for mass: Rect2 in masses:
		blockers.append(mass)
	sim.load_floor(load("res://game/sim/walkable_bounds.gd").new(room, blockers), Vector3.ZERO)
	sim.register_patches(room)
	sim.register_obstacles(blockers)
	sim.add_entity(PLAYER, start, 6.0, Vector3(0, 0, -1), 0.45)
	sim.register_combatant(PLAYER, 100.0, &"envoy", 0, 0.45, &"player")

	var stalls: int = 0
	var worst: int = 0
	var travelled: float = 0.0
	for tick in 240:
		var before: Vector3 = sim.entities[PLAYER]
		sim.tick([Command.new(sim.tick_count, PLAYER, "move", {"direction": direction.normalized()})] as Array[Command], DT)
		var moved: float = before.distance_to(sim.entities[PLAYER])
		travelled += moved
		if moved < 0.001:
			stalls += 1
			worst = maxi(worst, stalls)
		else:
			stalls = 0
	print("%-38s travelled %6.2f   longest stall %3d ticks (%.2f s)" % [
		label, travelled, worst, worst * DT])
	if label.begins_with("control"):
		print("   ^ expected to stop: there is nowhere to go, and that is the clamp working.")
	elif worst > 15:
		print("   ^ SNAG. The body is moving PAST this shape, not into it, and it still stalls.")
	else:
		print("   ^ clean; contact costs the blocked component only, which is the intended clamp.")
