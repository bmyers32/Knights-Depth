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
## Builds the ONE-action repertoire that SimWorld.register_ai takes (P29). Shared here
## rather than copied into each fixture: five test files register a single-action enemy,
## and a repertoire literal duplicated five times is how the band convention drifts
## between them. A single action is by definition the TERMINAL band, so [0.0, max_range]
## is inclusive at both ends — exactly the pre-P29 `distance <= preferred` eligibility
## test, which is why every existing AI fixture keeps its original behaviour unchanged.
static func single_action_repertoire(action_id: StringName, max_range: float, windup_ticks: int) -> Array[Dictionary]:
	return [{
		"id": action_id,
		"min_range": 0.0,
		"max_range": max_range,
		"windup_ticks": windup_ticks,
	}]


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
