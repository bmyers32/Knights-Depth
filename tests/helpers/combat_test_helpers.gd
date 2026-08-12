class_name CombatTestHelpers
extends RefCounted
## Shared test infrastructure for combat timing. ONE location, whole suite reaches it —
## per-file copies of this logic are how a subtle timing rule drifts between fixtures.

## QUIESCENCE INVARIANT (see BRAIN): before measuring post-action combat state, a test
## must establish that the actor has
##   (1) no open attack execution or hold,
##   (2) no QUEUED buffered press, and
##   (3) passed any relevant attack-eligibility deadline (cooldown).
## "Stopped sending attack Commands" is NOT the same as "idle": a queued press
## materializes on its own ticks later and lands a surprise hit, and an open "charging"
## hold makes a subsequent press hit _begin_melee_hold's already-charging no-op branch.
## Either one silently corrupts whatever is measured afterwards.
##
## Only a "charging" hold needs an explicit release to close; every other state
## resolves by letting ticks pass. Returns true if quiescence was reached.
static func settle(sim: SimWorld, actor_id: int, aim: Vector3 = Vector3(0, 0, -1), dt: float = 1.0 / 30.0, max_ticks: int = 60) -> bool:
	for _i in range(max_ticks):
		var state: Dictionary = sim.debug_describe_melee_state(actor_id)
		var off_cooldown: bool = sim.tick_count >= int(sim._next_fire_tick.get(actor_id, 0))
		if state.is_empty() and off_cooldown:
			return true
		var commands: Array[Command] = []
		if state.get("state", "") == "charging":
			commands.append(Command.new(sim.tick_count, actor_id, "attack", {"aim": aim, "phase": "released"}))
		sim.tick(commands, dt)
	return false
