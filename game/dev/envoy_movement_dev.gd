extends Node3D
## Dev-only scaffold (Phase D step 2-3, HANDOFF) proving input -> Command -> SimWorld ->
## render for a single Envoy, now extended to prove the sword damage pipeline (hit
## detect -> damage matrix -> knockback -> death/events) against a stationary Fang.
## The one shared SimWorld lives here, not on any actor (Prime Directive 1) — real
## levels will hold multiple sim-driven actors sharing one SimWorld, and ownership
## belongs to the scene, not to any one actor.
## Temporary: retired when the real M1 arena (step 8) replaces it.

@onready var envoy: CharacterBody3D = $Envoy
@onready var fang: Node3D = $Fang

var sim := SimWorld.new()


func _ready() -> void:
	sim.add_entity(envoy.actor_id, envoy.position, envoy.stats.move_speed)

	var fang_stats: FangStats = ContentDB.get_resource(&"enemy", &"fang")
	sim.add_entity(fang.actor_id, fang.position, 0.0)
	sim.register_combatant(fang.actor_id, fang_stats.max_health, fang_stats.family)

	var sword: SwordStats = ContentDB.get_resource(&"weapon", &"sword_A")
	sim.register_weapon(&"sword_A", sword.base_damage, sword.damage_type, sword.reach, sword.cone_half_angle_degrees, sword.knockback_distance)

	var matrix: DamageMatrix = ContentDB.get_resource(&"combat", &"damage_matrix")
	sim.set_damage_matrix(matrix.families, matrix.weak_multiplier, matrix.resist_multiplier)


func _physics_process(delta: float) -> void:
	var commands: Array[Command] = envoy.build_commands(sim.tick_count)
	var events: Array[Event] = sim.tick(commands, delta)
	envoy.sync_from_sim(sim.entities[envoy.actor_id])
	if fang:
		fang.sync_from_sim(sim.entities.get(fang.actor_id, fang.position))
	_report_events(events)


## Dev-only observability (AGENTS.md Invariable #2: every mechanic must be
## observable) — a real debug overlay/event log is future work, not needed for a
## two-scaffold prototype (rule of two).
func _report_events(events: Array[Event]) -> void:
	for event in events:
		match event.kind:
			"hit":
				print("hit: ", event.payload)
			"died":
				print("died: ", event.payload)
				if fang and event.payload.get("actor_id") == fang.actor_id:
					fang.queue_free()
					fang = null
			"attack_rejected":
				print("attack rejected: ", event.payload)
