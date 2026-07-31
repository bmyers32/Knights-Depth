class_name Event
extends RefCounted
## Sim output per CLAUDE.md Core Interfaces: {tick, kind, payload}. Plain data — same
## shape crosses the wire unchanged when M3 swaps the offline driver for a net driver.

var tick: int
var kind: String
var payload: Dictionary


func _init(p_tick: int, p_kind: String, p_payload: Dictionary = {}) -> void:
	tick = p_tick
	kind = p_kind
	payload = p_payload
