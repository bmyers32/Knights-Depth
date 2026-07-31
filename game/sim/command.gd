class_name Command
extends RefCounted
## Sim mutation request per CLAUDE.md Core Interfaces: {tick, actor_id, kind, params}.
## Plain data, zero Node imports — same shape crosses the wire unchanged when M3
## swaps the offline driver for a net driver (GAME-RULES SS4.4).

var tick: int
var actor_id: int
var kind: String
var params: Dictionary


func _init(p_tick: int, p_actor_id: int, p_kind: String, p_params: Dictionary = {}) -> void:
	tick = p_tick
	actor_id = p_actor_id
	kind = p_kind
	params = p_params
