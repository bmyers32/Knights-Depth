extends SceneTree
## DOES THE VAULT'S CONTROL OBEY THE WEAPON-AGNOSTIC WORLD-CONTROL LAW? (ruled 2026-09-06)
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_vault_switch.gd
##
## DIAGNOSE BEFORE FIXING. The persistent switch was reported weapon-agnostic "by construction"
## through the shared world-hit cone. If the Vault's one-shot control still rejects a weapon, the
## question is WHICH of these is true:
##   1. it shares that seam and some OTHER condition rejects the hit;
##   2. it is a parallel switch/control hit path -- a rule-of-two consolidation defect;
##   3. something else concrete.
##
## Every gating fact is printed before any verdict, so a "no" cannot be mistaken for the wrong no.
##
## THIS TOOL WAS WRONG THREE TIMES BEFORE IT WAS RIGHT, and each fault produced the SAME false
## headline -- "the sword cannot operate the switch". It read sim._weapons, where swords do not
## live; it wrote equip state directly instead of cycling through the real Command; and it sent
## an unphased `attack`, when melee resolves on a PRESSED/RELEASED pair. The liveness line below
## is what caught all three: zero attacks resolved is not evidence about a switch.
##
## Reports only.

const DT: float = 1.0 / 30.0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var L: GDScript = load("res://game/gen/layouts/archive_roundabout.gd")
	print("VAULT SWITCH — weapon-agnostic diagnosis")
	print("")

	# ONE SEAM OR TWO? Answered by reading the sim, not by assuming.
	var source: String = FileAccess.get_file_as_string("res://game/sim/sim_world.gd")
	var melee_calls: int = source.count("_resolve_hit_on_switch")
	print("STRUCTURE: _resolve_hit_on_switch referenced %d times in sim_world.gd" % melee_calls)
	print("   (definition + melee-cone consumer + projectile consumer = 3 means ONE shared seam)")
	print("   _switches_in_cone present: %s   _find_earliest_switch_hit present: %s" % [
		str(source.contains("func _switches_in_cone")), str(source.contains("func _find_earliest_switch_hit"))])
	print("")

	for weapon_id in ["sword_burn_A", "wand_A"]:
		_probe(L, StringName(weapon_id))
	quit(0)


func _probe(L: GDScript, weapon_id: StringName) -> void:
	var arena: Node3D = load("res://game/arena/arena.tscn").instantiate()
	arena.depth = 2
	Engine.get_main_loop().root.add_child(arena)
	var sim: Object = arena.sim
	var envoy_id: int = arena.envoy.actor_id
	sim.debug_override_health(envoy_id, 100000.0)

	var switch_position: Vector3 = Vector3.ZERO
	for hit_switch: HitSwitchPlan in load("res://game/gen/depth_generator.gd").generate(arena.run_seed, 2).hit_switches:
		if hit_switch.switch_id == L.S_VAULT:
			switch_position = hit_switch.position

	# Reveal it first: a hidden switch is in no hit scan at all, which is a DIFFERENT no.
	sim.debug_destroy_breakable(L.B_VAULT_COVER)
	var hidden: bool = bool(sim._hit_switches[L.S_VAULT]["hidden"])

	var equipped: bool = weapon_id in arena.loadout_weapon_ids
	print("WEAPON %s" % weapon_id)
	print("   in shipped loadout: %s   switch hidden after clearing cover: %s" % [str(equipped), str(hidden)])
	if not equipped:
		print("   SKIPPED: not an authored weapon on this floor.")
		arena.queue_free()
		return

	# EQUIPPED THROUGH THE REAL COMMAND, not by writing sim state. Calling set_equipped_weapon
	# directly left the sword unable to swing at all -- zero attacks resolved -- and the probe
	# reported that as "the switch rejects the sword". It was the instrument.
	var empty_setup: Array = Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))
	for attempt in 4:
		if StringName(sim._equipped_weapon.get(envoy_id, &"")) == weapon_id:
			break
		sim.tick([Command.new(sim.tick_count, envoy_id, "switch_weapon", {})] as Array[Command], DT)
		for settle in 20:
			sim.tick(empty_setup, DT)
	print("   equipped after cycling: %s" % String(sim._equipped_weapon.get(envoy_id, &"")))
	# READ THROUGH THE CONTENT, not through a sim registry. A first version reached into
	# sim._weapons and errored on the sword -- swords resolve through combo profiles and are not
	# in that dictionary at all. That is an instrument fault, and reading it as "the sword cannot
	# operate the switch" would have been a bug report about the diagnostic.
	var stats: Resource = Engine.get_main_loop().root.get_node("ContentDB").get_resource(&"weapon", weapon_id)
	var is_projectile: bool = stats is GunStats
	var reach: float = 3.0 if is_projectile else 2.6
	print("   content class: %s" % stats.get_class() if stats == null else "   profile: %s" % ("projectile" if is_projectile else "melee"))

	# SWEEP THE DISTANCE rather than guess one. "No activation" at a single stand-off proves
	# nothing -- it may simply be out of reach, which is not a weapon-identity gate and would be
	# the wrong defect to report.
	var empty: Array = Array([], TYPE_OBJECT, &"RefCounted", load("res://game/sim/command.gd"))
	var reached_at: float = -1.0
	for tenths in range(10, 61, 5):
		var stand_off: float = float(tenths) / 10.0
		sim._hit_switches[L.S_VAULT]["spent"] = false
		sim.entities[envoy_id] = switch_position + Vector3(-stand_off, 0.0, 0.0)
		var activated: bool = false
		for tick in 60:
			var commands: Array = empty
			if tick % 20 == 0:
				commands = [Command.new(sim.tick_count, envoy_id, "attack", {"aim": Vector3(1, 0, 0), "phase": "pressed"})] as Array[Command]
			elif tick % 20 == 2:
				commands = [Command.new(sim.tick_count, envoy_id, "attack", {"aim": Vector3(1, 0, 0), "phase": "released"})] as Array[Command]
			for event in sim.tick(commands, DT):
				if event.kind == "switch_activated":
					activated = true
			if activated:
				break
		if activated and reached_at < 0.0:
			reached_at = stand_off
	# LIVENESS: did this weapon actually SWING? Silence from an observer is evidence only when the
	# observer is connected to the behaviour. A sword that never resolves an attack in the probe
	# would report exactly the same "never operates it" as a sword the switch rejects.
	sim._hit_switches[L.S_VAULT]["spent"] = false
	sim.register_breakable(99, switch_position + Vector3(-2.0, 0.0, 0.0), 0.7, 1.0)
	sim.entities[envoy_id] = switch_position + Vector3(-3.5, 0.0, 0.0)
	var swings: int = 0
	var broke: bool = false
	for tick in 120:
		var commands: Array = empty
		if tick % 20 == 0:
			commands = [Command.new(sim.tick_count, envoy_id, "attack", {"aim": Vector3(1, 0, 0), "phase": "pressed"})] as Array[Command]
		elif tick % 20 == 2:
			commands = [Command.new(sim.tick_count, envoy_id, "attack", {"aim": Vector3(1, 0, 0), "phase": "released"})] as Array[Command]
		for event in sim.tick(commands, DT):
			if event.kind == "melee_swing" or event.kind == "projectile_fired":
				swings += 1
			if event.kind == "breakable_destroyed":
				broke = true
	print("   LIVENESS: %d attacks resolved; broke a test prop at the same spot: %s" % [swings, str(broke)])

	if reached_at >= 0.0:
		print("   OPERATES THE SWITCH, from as far as %.1f units away" % reached_at)
	else:
		print("   NEVER OPERATES IT, at any distance from 1.0 to 6.0 -- this is a real gate")
	print("   vault door open: %s" % str(bool(sim._connection_open[L.C_VAULT])))
	print("")
	arena.queue_free()
