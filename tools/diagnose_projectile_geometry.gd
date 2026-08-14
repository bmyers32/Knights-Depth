extends SceneTree
## P29 item 3 DIAGNOSIS — projectile visual/authoritative coherence.
##
## Run:  & "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s tools/diagnose_projectile_geometry.gd
##
## The playtest finding was "the projectile's visual/authoritative relationship produces
## apparent hits that miss." This MEASURES where the authoritative hit boundary actually
## sits relative to the body the player aims at, rather than assuming it.
##
## Method: shooter and target are offset laterally so the shot's straight-line path has a
## perpendicular distance from the target's CENTRE exactly equal to that offset. Offsets
## sweep outward; the largest offset that still resolves a `hit` IS the effective
## authoritative hit radius. That is compared against the target's authored combat_radius
## — this project's single source of truth for "how big is this body" (shared by Burn
## contact-spread and the melee lunge clamp via _contact_distance).
##
## Classification, in the verdict's own terms:
##   effective_hit_radius < combat_radius -> SIM-MISS   (geometry/content question)
##   tracer radius        < effective     -> TRACER-LIE (cosmetic doctrine: tracer bug)
##
## Loaded dynamically for the usual reason: a `-s` script compiles before project
## autoloads exist, so a compile-time reference to anything touching ContentDB fails.

const STEPS: int = 20


static var EMPTY: Array[Command] = []


func _init() -> void:
	var iterations: int = 0
	while Engine.get_main_loop() == null and iterations < 20:
		await create_timer(0.01).timeout
		iterations += 1

	var SimWorldScript: GDScript = load("res://game/sim/sim_world.gd")
	var Registrar: GDScript = load("res://game/content/content_registrar.gd")
	var CommandScript: GDScript = load("res://game/sim/command.gd")
	var db: Object = get_root().get_node("ContentDB")

	print("\n=== P29 item 3: projectile geometry diagnosis ===")
	print("shots per case: %d\n" % STEPS)

	var wand: Resource = db.get_resource(&"weapon", &"wand_A")
	print("OUTGOING  wand_A  (authored hit_radius %.2f)" % wand.hit_radius)
	for family in [&"fang", &"ooze", &"watcher"]:
		var stats: Resource = db.get_resource(&"enemy", family)
		var effective: float = _sweep_outgoing(SimWorldScript, Registrar, CommandScript, family, stats.combat_radius)
		_report(String(family), effective, stats.combat_radius, wand.hit_radius)

	var survey: Resource = db.get_resource(&"natural_weapon", &"watcher_survey")
	var envoy: Resource = db.get_resource(&"envoy", &"default")
	print("\nINCOMING  watcher_survey  (authored hit_radius %.2f)" % survey.projectile_hit_radius)
	var incoming: float = _sweep_incoming(SimWorldScript, Registrar, envoy.combat_radius)
	_report("envoy", incoming, envoy.combat_radius, survey.projectile_hit_radius)
	print("  NOTE: the incoming row is NOT a valid perpendicular-distance measurement.")
	print("        The Watcher samples aim at its fire tick toward the player's CURRENT")
	print("        position, so offsetting the player changes the firing ANGLE rather than")
	print("        the miss distance -- this row measures aim tracking, not geometry.")
	print("        Incoming geometry is pinned by tests/test_projectile_geometry.gd instead,")
	print("        which fires along a fixed axis so the offset is a true miss distance.")

	print("\n=== end diagnosis ===\n")
	quit(0)


func _hit_landed(events: Array, target_id: int) -> bool:
	for event in events:
		if event.kind == "hit" and int(event.payload.get("target_id", -1)) == target_id:
			return true
	return false


## Largest lateral offset at which a player wand shot still resolves a hit on `family`.
func _sweep_outgoing(SimWorldScript: GDScript, Registrar: GDScript, CommandScript: GDScript, family: StringName, body: float) -> float:
	var largest_hit: float = -1.0
	for step in STEPS:
		var offset: float = (float(step) / float(STEPS - 1)) * (body * 1.6)
		var sim: Object = SimWorldScript.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		sim.add_entity(0, Vector3(offset, 0.0, 0.0), 0.0)
		sim.register_combatant(0, 999.0, &"envoy", 0, 0.45, &"player")
		Registrar.register_enemy_body(sim, 1, family, Vector3(0.0, 0.0, -8.0))
		Registrar.register_weapon(sim, &"wand_A")
		sim.set_equipped_weapon(0, &"wand_A")
		# Array[Command], not a plain Array: SimWorld.tick's typed parameter REJECTS an
		# untyped array outright, and the rejection surfaces only on stderr -- an earlier
		# run of this very script silently measured nothing but printed a clean table.
		var typed: Array[Command] = []
		typed.append(CommandScript.new(sim.tick_count, 0, "attack", {"aim": Vector3(0, 0, -1)}))
		sim.tick(typed, 1.0 / 30.0)
		for _t in 120:
			if _hit_landed(sim.tick(EMPTY, 1.0 / 30.0), 1):
				largest_hit = max(largest_hit, offset)
				break
	return largest_hit


## Largest lateral offset at which the Watcher's survey still resolves a hit on the Envoy.
func _sweep_incoming(SimWorldScript: GDScript, Registrar: GDScript, body: float) -> float:
	var largest_hit: float = -1.0
	for step in STEPS:
		var offset: float = (float(step) / float(STEPS - 1)) * (body * 2.6)
		var sim: Object = SimWorldScript.new()
		sim.set_damage_matrix({}, 1.5, 0.5)
		sim.add_entity(0, Vector3(offset, 0.0, 0.0), 0.0)
		sim.register_combatant(0, 99999.0, &"envoy", 0, body, &"player")
		Registrar.register_enemy_body(sim, 1, &"watcher", Vector3(0.0, 0.0, -6.0))
		Registrar.register_enemy_ai(sim, 1, &"watcher", Vector3(0.0, 0.0, -6.0))
		sim.debug_set_ai_active(1)
		for _t in 200:
			if _hit_landed(sim.tick(EMPTY, 1.0 / 30.0), 0):
				largest_hit = max(largest_hit, offset)
				break
	return largest_hit


## effective is expected to be authored + body (a Minkowski sum) once the P29 item-3
## geometry correction is in. Anything materially SHORT of that means the resolver stopped
## consulting the authoritative body again.
##
## The tracer is deliberately compared against the PROJECTILE radius alone, never the sum:
## the sum exists only in collision space, and drawing it would visualise a volume the
## player is not aiming (rider b). A tracer smaller than its own projectile radius is the
## lie; a tracer smaller than the sum is correct by design.
func _report(label: String, effective: float, body: float, authored: float) -> void:
	var expected: float = authored + body
	var ratio: float = (effective / body) * 100.0 if body > 0.0 else 0.0
	var verdict: String = "coherent (authored + body)" if effective >= expected - 0.15 else "SIM-MISS: authoritative volume is SMALLER than authored + body"
	print("  %-8s body=%.2f  authored_hit_radius=%.2f  expected=%.2f  measured_effective=%.2f  (%.0f%% of body)  -> %s" % [
		label, body, authored, expected, effective, ratio, verdict])
	# No tracer check here on purpose: arena.gd feeds ProjectileTracer.launch() this very
	# authored hit_radius, per weapon, at VISUAL_SCALE 1.0 — so tracer and projectile
	# radius cannot diverge by construction. A single const here would only ever produce
	# false positives against whichever weapon it was not sized for.
