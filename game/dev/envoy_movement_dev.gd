extends Node3D
## Dev-only scaffold (Phase D step 2, HANDOFF) proving input -> Command -> SimWorld ->
## render for a single Envoy. The one shared SimWorld lives here, not on the Envoy
## itself (Prime Directive 1) — real levels will hold multiple sim-driven actors sharing
## one SimWorld, and ownership belongs to the scene, not to any one actor.
## Temporary: retired when the real M1 arena (step 8) replaces it.

@onready var envoy: CharacterBody3D = $Envoy

var sim := SimWorld.new()


func _ready() -> void:
	sim.add_entity(envoy.actor_id, envoy.position, envoy.stats.move_speed)


func _physics_process(delta: float) -> void:
	var commands: Array[Command] = [envoy.build_command(sim.tick_count)]
	sim.tick(commands, delta)
	envoy.sync_from_sim(sim.entities[envoy.actor_id])
