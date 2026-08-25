extends SceneTree
## Measures the SHIPPED Stage-2 chain: emerge -> reacquisition beat -> ordinary attack.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_burrow_chain.gd
##
## Stage 2 asks whether the reacquisition beat is a GENUINE response window rather than merely a
## visible one. That is a human judgement, but the human should not have to time it by eye --
## these are the actual tick gaps the authored content produces, reported so the verdict is
## rendered against known quantities.
##
## Reports, and does NOT tune. No number here is adjusted before Breon's verdict.

const PLAYER_ID: int = 0
const FANG_ID: int = 1
const DT: float = 1.0 / 30.0


func _init() -> void:
	var i: int = 0
	while Engine.get_main_loop() == null and i < 20:
		await create_timer(0.01).timeout
		i += 1

	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var fang: Resource = db.get_resource(&"enemy", &"fang")
	var bite: Resource = db.get_resource(&"natural_weapon", &"fang_bite")
	print("shipped: reacquisition %d  emergence_radius %.2f  preferred %.2f  bite windup %d  fire_interval %d" % [
		fang.burrow_reacquisition_ticks, fang.burrow_emergence_radius,
		fang.preferred_attack_distance, bite.windup_ticks, bite.fire_interval_ticks])
	print("")
	for label in ["player stationary", "player retreating"]:
		_measure(label)
	print("\nThe window a player actually gets is emergence -> HIT: the reacquisition beat plus the")
	print("approach plus the telegraph, all of it before damage lands. Reported, not tuned.")
	quit(0)


func _measure(label: String) -> void:
	var sim: Object = load("res://game/sim/sim_world.gd").new()
	var registrar: GDScript = load("res://game/content/content_registrar.gd")
	var db: Object = Engine.get_main_loop().root.get_node("ContentDB")
	var envoy_stats: Resource = db.get_resource(&"envoy", &"default")

	sim.seed_combat_rng(20260825)
	sim.add_entity(PLAYER_ID, Vector3.ZERO, envoy_stats.move_speed)
	sim.register_combatant(PLAYER_ID, 100000.0, envoy_stats.family, 0, envoy_stats.combat_radius, &"player")
	registrar.register_enemy_body(sim, FANG_ID, &"fang", Vector3(0, 0, -4.0))
	registrar.register_enemy_ai(sim, FANG_ID, &"fang", Vector3(0, 0, -4.0))
	sim.debug_override_health(FANG_ID, 100000.0)
	sim.debug_trigger_burrow(FANG_ID, PLAYER_ID)

	var submerged: int = -1
	var emerged: int = -1
	var telegraph: int = -1
	var hit: int = -1
	for tick in 400:
		var commands: Array[Command] = []
		if label == "player retreating":
			commands.append(Command.new(sim.tick_count, PLAYER_ID, "move", {"direction": Vector3(1, 0, 0)}))
		for event in sim.tick(commands, DT):
			match event.kind:
				"burrow_submerged":
					if submerged == -1:
						submerged = event.tick
				"burrow_emerged":
					if emerged == -1:
						emerged = event.tick
				"attack_telegraph":
					if emerged != -1 and telegraph == -1:
						telegraph = event.tick
				"hit":
					if int(event.payload.get("attacker_id", -1)) == FANG_ID and hit == -1:
						hit = event.tick
		if hit != -1:
			break

	print("--- %s ---" % label)
	if emerged == -1:
		print("  never emerged")
		return
	print("  jump -> submerge      %3d ticks (%.2f s)" % [submerged, submerged * DT])
	print("  submerge -> emerge    %3d ticks (%.2f s)" % [emerged - submerged, (emerged - submerged) * DT])
	if telegraph == -1:
		print("  emerge -> telegraph   never attacked within the window")
		return
	print("  emerge -> telegraph   %3d ticks (%.2f s)   <- beat + approach, no attack may start" % [telegraph - emerged, (telegraph - emerged) * DT])
	if hit == -1:
		print("  telegraph -> hit      did not resolve")
		return
	print("  telegraph -> hit      %3d ticks (%.2f s)   <- the tell itself" % [hit - telegraph, (hit - telegraph) * DT])
	print("  EMERGE -> HIT         %3d ticks (%.2f s)   <- total response window" % [hit - emerged, (hit - emerged) * DT])
