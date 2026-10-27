class_name ProgressionValidator
extends RefCounted
## CAN THE PARTY GET FROM ARRIVAL TO THE EXIT, AND NEVER GET STUCK ON THE WAY? (ADR-001 S0.)
##
## A pure search over a FloorPlan: no SimWorld, no Node, no autoload. It re-reads the plan's own
## layers the way the sim reads them -- the same vocabulary (FloorLayers), the same inclusive
## occupancy (WalkableBounds.contains), the same effect semantics (SimWorld._apply_floor_effect)
## -- and never a second opinion about what a trigger or an effect means. Where the sim's rule is
## not knowable from plan data alone, the model is conservative and SAYS SO (ProgressionReport
## limitations), because a validator that passes what the sim forbids is worse than none.
##
## THE SMALLEST STATE THAT IS HONEST. Position matters: after a one-way commitment the Envoy is
## on the far side, so reachability is from WHERE THE ENVOY STANDS, never from the entry. Ground
## is cut into CELLS at occupancy regions, blocking props and obstacles, so a region that spans a
## corridor is crossed only by firing it, while a plate in a wide room can be walked around --
## which is exactly what the sim allows (occupancy is a point test, legality a body-aware union).
## And the Envoy is a BODY: the search walks the ground its CENTRE may legally occupy (each cell
## eroded by the body, plus the exact strip two adjoining cells cover together), so a strip
## narrower than a body is passable only where neighbouring ground covers the rest of it.
##
## TWO QUESTIONS, KEPT APART (S3b). `check` asks whether the floor can be finished and never gets
## stuck. `check_objective` asks the integrity question: with a declared outcome FORBIDDEN (a fight
## never cleared, a key never lifted or delivered, a piece of ground never entered), does ANY route
## to the goal remain? It forbids an ACTION in the search; it never deletes a record from the floor,
## so the floor under test is the floor that ships.
##
## SUPPORTED ACTIONS -- each is one FloorLayers kind, applied as SimWorld applies it:
##   enter a region / group-occupancy trigger   (solo: one Envoy IS the party)
##   break a breakable from ground in attack reach    -> breakable_destroyed watchers
##   hit a VISIBLE switch from ground in attack reach -> its effects, switch_activated watchers
##   lift a revealed carriable from ground in pickup reach -> carriable_lifted watchers
##   deliver the held carriable at an unfilled receiver the Envoy can stand in
##   clear an active encounter  (ASSUMED winnable; recorded as an assumption, never silent)
## An attack-type action while carrying first sets the key down where the Envoy stands (the sim:
## that press drops, it never swings while carrying). With the `set_down_anywhere` rule the search
## also sets the key down VOLUNTARILY on any reachable ground (the sim's drop press), one point per
## piece of ground -- opt-in, because it multiplies the state space by the ground a key can lie on.
##
## NOT A PUZZLE SOLVER. Anything outside those rules is either conservative (modelled as "cannot")
## or surfaced through a second, deliberately OPTIMISTIC search: if relaxing a rule the model
## cannot establish (a switch shot from afar; ground a body cannot be centred on) is what makes
## the exit reachable, the verdict is UNSUPPORTED -- not PASS, and not FAIL.

const _HELD: int = -1
const _INSERTED: int = -2
const _HOME: int = -3

## Everything an action's rules read, with the sim's own meanings. Supplied by the caller (tests,
## later DepthGenerator) from content, never looked up here: this class reaches no autoload.
##   body_radius   the Envoy's combat radius; 0 degrades to a point, exactly as WalkableBounds.fits
##   attack_reach  melee reach (plus the target's own radius, as _breakables_in_cone adds it)
##   pickup_reach  the carry reach a lift is offered within
##   max_states    the search budget; exceeding it is reported, never silently truncated
##   set_down_anywhere  a held key may be set down on any reachable piece of ground (the voluntary
##                 drop press), not only where an attack or a fight forces it down
const DEFAULT_RULES: Dictionary = {"body_radius": 0.0, "attack_reach": 0.0, "pickup_reach": 0.0, "max_states": 20000, "set_down_anywhere": false}

## Relaxations the optimistic search may switch on. Each names one thing the strict model
## refuses to establish; a verdict that needs one is UNSUPPORTED, and the finding says which.
##   ranged_switches  a visible switch may be activated from anywhere the party can stand
##   thin_ground      the Envoy is a point: ground narrower than a body may be walked
const RELAX_RANGED_SWITCHES: StringName = &"ranged_switches"
const RELAX_THIN_GROUND: StringName = &"thin_ground"
const _RELAXATIONS_TO_TRY: Array = [[RELAX_RANGED_SWITCHES], [RELAX_THIN_GROUND], [RELAX_RANGED_SWITCHES, RELAX_THIN_GROUND]]

const _LIMITATION_SET_DOWN: String = "a carried key is set down only where an attack or a fight happens, never elsewhere"
const _LIMITATION_SET_DOWN_ANYWHERE: String = "a carried key may be set down on any reachable ground, one point per piece of it; a key knocked loose by a hit (the sim drops it where the carrier stood) is the same set-down, but enemy pressure itself is not modelled"
const _STANDING_LIMITATIONS: Array[String] = [
	"enemy bodies and hazards never block or harm the party (spike pads, rosters in doorways)",
	"an active encounter is cleared whenever the party chooses, without modelling the fight",
	"while a sealing encounter is active only clearing it is possible; confinement geometry is not checked",
	"group occupancy is evaluated for a solo party (M3 party membership is not modelled)",
	_LIMITATION_SET_DOWN,
	"switches are activated by melee reach only (ranged activation is reported, not proven)",
	"a body stands only where one piece of ground, or two adjoining pieces, cover its whole footprint",
]


static func check(plan: FloorPlan, rules: Dictionary = {}) -> ProgressionReport:
	var report := ProgressionReport.new()
	var settings: Dictionary = DEFAULT_RULES.duplicate()
	settings.merge(rules, true)
	report.limitations.assign(_limitations(settings))
	var model := _Model.new(plan, settings, report)
	if not model.ok:
		report.outcome = ProgressionReport.OUTCOME_UNSUPPORTED if report.findings_of(&"entry_off_floor").is_empty() else ProgressionReport.OUTCOME_FAIL
		return report
	if model.goal_triggers.is_empty():
		report.add_finding(&"no_exit", ProgressionReport.SEVERITY_FAIL,
			"no trigger on this floor completes it (no complete_floor effect), so there is nothing to reach")
		report.outcome = ProgressionReport.OUTCOME_FAIL
		return report

	var strict := _Search.new(model, false)
	strict.run(model.initial_state())
	report.states_explored = strict.explored.size()
	if strict.over_budget:
		report.add_finding(&"state_budget", ProgressionReport.SEVERITY_UNSUPPORTED,
			"the search exceeded %d states before concluding; this floor's progression is too wide for the model" % int(settings["max_states"]))
		report.outcome = ProgressionReport.OUTCOME_UNSUPPORTED
		return report

	var rescuer := _Rescuer.new(plan, settings, model)
	if strict.goal_key == "":
		var rescue: Dictionary = rescuer.rescue(model.initial_state())
		if rescue.is_empty():
			report.add_finding(&"exit_unreachable", ProgressionReport.SEVERITY_FAIL,
				"no sequence of supported actions reaches the exit from arrival", strict.frontier_refs())
			report.outcome = ProgressionReport.OUTCOME_FAIL
		else:
			report.add_finding(&"unsupported_" + String(rescue["relaxation"]), ProgressionReport.SEVERITY_UNSUPPORTED,
				"the exit is reachable only if %s, which this model does not establish" % rescue["because"],
				{}, rescue["trace"])
			report.outcome = ProgressionReport.OUTCOME_UNSUPPORTED
		return report

	report.trace = strict.trace_to(strict.goal_key)
	# The route's fights are what this PASS is conditional on. Fights elsewhere on the floor are
	# covered by the standing limitation: any fight entered is assumed winnable.
	for step in report.trace:
		if step.begins_with("clear encounter "):
			report.assumptions.append("encounter %s is cleared by combat" % step.trim_prefix("clear encounter "))
	# NO SOFTLOCK: every state the supported actions can reach must still reach the exit. A one-way
	# commitment crossed too early, a key left behind a sealed door -- those are states, and the
	# search visited them.
	var unsupported: bool = false
	for key in strict.states_that_cannot_finish():
		var state: Dictionary = strict.explored[key]
		var how: Array[String] = strict.trace_to(key)
		var rescue: Dictionary = rescuer.rescue(state)
		if rescue.is_empty():
			report.add_finding(&"softlock", ProgressionReport.SEVERITY_FAIL,
				"after these steps no supported action ever reaches the exit again", strict.refs_for(state), how)
		else:
			unsupported = true
			report.add_finding(&"unsupported_" + String(rescue["relaxation"]), ProgressionReport.SEVERITY_UNSUPPORTED,
				"after these steps the exit is reachable only if %s" % rescue["because"], {}, how)
	if not report.findings_of(&"softlock").is_empty():
		report.outcome = ProgressionReport.OUTCOME_FAIL
	elif unsupported:
		report.outcome = ProgressionReport.OUTCOME_UNSUPPORTED
	else:
		report.outcome = ProgressionReport.OUTCOME_PASS
	return report


static func _limitations(settings: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for line: String in _STANDING_LIMITATIONS:
		out.append(_LIMITATION_SET_DOWN_ANYWHERE if line == _LIMITATION_SET_DOWN and bool(settings["set_down_anywhere"]) else line)
	return out


# --- OBJECTIVE INTEGRITY (S3b) ---------------------------------------------------------------------

## What may be forbidden, by the ids the plan uses:
##   clear    Array[int] encounter ids that are never cleared (a sealing one, once active, holds the
##            party for good -- exactly what "this fight is never won" means)
##   lift     Array[int] carriable ids never lifted
##   deliver  Array[int] receiver trigger ids never delivered to
##   ground   Array[Rect2] ground the party never stands on (a piece's footprint)
const FORBID_CLEAR: StringName = &"clear"
const FORBID_LIFT: StringName = &"lift"
const FORBID_DELIVER: StringName = &"deliver"
const FORBID_GROUND: StringName = &"ground"
## What the query asks to reach. {} is floor completion; {lift: id} is holding that key; {open: id}
## is that connection standing open; {enter: Rect2} is standing on ground that touches the rect.
const GOAL_COMPLETE: StringName = &"complete"
const GOAL_LIFT: StringName = &"lift"
const GOAL_OPEN: StringName = &"open"
const GOAL_ENTER: StringName = &"enter"


## THE ANSWER TO ONE INTEGRITY QUESTION, three ways and never blurred:
##   ROUTE_NONE   exhaustive: no sequence of supported actions reaches the goal with the forbidden
##                outcomes withheld, and no relaxation the model knows of finds one either
##   ROUTE_FOUND  a route exists; `trace` is it, step by step (for a mandatory claim: the bypass)
##   UNSUPPORTED  the budget ran out, the model could not be built, or only a RELAXED search finds a
##                route -- the model cannot say either way, and `reason` says why
## It says nothing about solvability: `check` answers that, and a caller reads both.
class ObjectiveResult:
	extends RefCounted
	const ROUTE_NONE: StringName = &"route_none"
	const ROUTE_FOUND: StringName = &"route_found"
	const UNSUPPORTED: StringName = &"unsupported"
	var verdict: StringName = UNSUPPORTED
	var forbidden: Dictionary = {}
	var goal: Dictionary = {}
	var trace: Array[String] = []
	var states_explored: int = 0
	var reason: String = ""

	func summary() -> String:
		var line: String = "objective %s (goal %s, forbidding %s) after %d states" % [String(verdict).to_upper(), str(goal), str(forbidden), states_explored]
		if reason != "":
			line += ": " + reason
		if not trace.is_empty():
			line += "\n  route: " + " -> ".join(trace)
		return line

	func to_dict() -> Dictionary:
		return {"verdict": String(verdict), "forbidden": str(forbidden), "goal": str(goal), "trace": trace.duplicate(),
			"states_explored": states_explored, "reason": reason}


static func check_objective(plan: FloorPlan, rules: Dictionary, forbidden: Dictionary, goal: Dictionary = {}) -> ObjectiveResult:
	return ObjectiveSession.new(plan, rules).ask(forbidden, goal)


## MANY INTEGRITY QUESTIONS ABOUT ONE FLOOR share one model: cutting the ground, eroding it by the
## body and joining the pieces is the expensive part, and it does not depend on what is forbidden.
## The relaxed point model is built once too, the first time a strict search finds nothing.
class ObjectiveSession:
	extends RefCounted
	var _settings: Dictionary
	var _model: _Model
	var _rescuer: _Rescuer
	var _failure: String = ""

	func _init(plan: FloorPlan, rules: Dictionary) -> void:
		_settings = ProgressionValidator.DEFAULT_RULES.duplicate()
		_settings.merge(rules, true)
		var scratch := ProgressionReport.new()
		_model = _Model.new(plan, _settings, scratch)
		if not _model.ok:
			_failure = "the model could not be built: %s" % scratch.summary()
		_rescuer = _Rescuer.new(plan, _settings, _model)

	func ask(forbidden: Dictionary, goal: Dictionary = {}) -> ObjectiveResult:
		var result := ObjectiveResult.new()
		result.forbidden = forbidden.duplicate(true)
		result.goal = goal.duplicate()
		if _failure != "":
			result.reason = _failure
			return result
		if ProgressionValidator._goal_kind(goal) == ProgressionValidator.GOAL_COMPLETE and _model.goal_triggers.is_empty():
			result.reason = "no trigger completes this floor, so completion is not a question the model can ask"
			return result
		var constraints: Dictionary = {"forbid": forbidden, "goal": goal}
		var strict := _Search.new(_model, false, constraints)
		strict.run(_model.initial_state())
		result.states_explored = strict.explored.size()
		if strict.over_budget:
			result.reason = "the search exceeded %d states before concluding" % int(_settings["max_states"])
			return result
		if strict.goal_key != "":
			result.verdict = ObjectiveResult.ROUTE_FOUND
			result.trace = strict.trace_to(strict.goal_key)
			return result
		var rescue: Dictionary = _rescuer.rescue(_model.initial_state(), constraints)
		if not rescue.is_empty():
			result.reason = "a route exists only if %s, which this model does not establish" % rescue["because"]
			result.trace.assign(rescue["trace"])
			return result
		result.verdict = ObjectiveResult.ROUTE_NONE
		return result


static func _goal_kind(goal: Dictionary) -> StringName:
	if goal.has(GOAL_LIFT):
		return GOAL_LIFT
	if goal.has(GOAL_OPEN):
		return GOAL_OPEN
	if goal.has(GOAL_ENTER):
		return GOAL_ENTER
	return GOAL_COMPLETE


## Whether some relaxation the strict model refuses would reach the exit from a state, and the
## smallest one that does. Tried one at a time first, so a finding names the single rule in
## question whenever one suffices. The point model is built once, only if it is ever needed.
class _Rescuer:
	extends RefCounted

	var plan: FloorPlan
	var settings: Dictionary
	var model: _Model
	var point_model: _Model = null

	func _init(the_plan: FloorPlan, the_settings: Dictionary, the_model: _Model) -> void:
		plan = the_plan
		settings = the_settings
		model = the_model

	## {relaxation, because, trace}, or empty when no relaxation helps. `constraints` (forbidden
	## outcomes, a goal) bind the relaxed search exactly as they bind the strict one.
	func rescue(state: Dictionary, constraints: Dictionary = {}) -> Dictionary:
		for relaxations: Array in _RELAXATIONS_TO_TRY:
			var thin: bool = RELAX_THIN_GROUND in relaxations
			var ranged: bool = RELAX_RANGED_SWITCHES in relaxations
			var search := _Search.new(_point_model() if thin else model, ranged, constraints)
			search.run(_point_model().translate(model, state) if thin else state)
			if search.goal_key == "":
				continue
			var because: PackedStringArray = []
			if ranged:
				because.append("a switch can be activated from beyond melee reach")
			if thin:
				because.append("ground narrower than a body can be walked")
			return {"relaxation": "_and_".join(relaxations), "because": " and ".join(because), "trace": search.trace_to(search.goal_key)}
		return {}

	func _point_model() -> _Model:
		if point_model == null:
			var point_rules: Dictionary = settings.duplicate()
			point_rules["body_radius"] = 0.0
			point_model = _Model.new(plan, point_rules, ProgressionReport.new())
		return point_model


# --- THE MODEL: cells, legal ground for a body, and the plan's records indexed for the search ----

class _Model:
	extends RefCounted

	var ok: bool = true
	var rules: Dictionary
	var plan: FloorPlan
	var radius: float = 0.0
	## Ground, cut: {id, rect, trigger (index or -1), connection (index or -1), blocker (breakable index or -1)}
	var cells: Array[Dictionary] = []
	## Where the Envoy's CENTRE may be: {id, rect, cell}. With no body, exactly the cells.
	var pieces: Array[Dictionary] = []
	var adjacency: Array = []  # piece id -> Array[int]
	var connections: Array[TraversalConnection] = []
	var triggers: Array[FloorTrigger] = []
	var breakables: Array[BreakablePlan] = []
	var switches: Array[HitSwitchPlan] = []
	var carriables: Array[CarriablePlan] = []
	var encounters: Array[EncounterSite] = []
	var goal_triggers: Array[int] = []
	var entry_piece: int = -1

	func _init(floor_plan: FloorPlan, settings: Dictionary, report: ProgressionReport) -> void:
		plan = floor_plan
		rules = settings
		radius = maxf(float(rules["body_radius"]), 0.0)
		connections = plan.connections
		_keep_only_what_progression_depends_on(report)
		for index in triggers.size():
			if not _known_trigger_kind(triggers[index].kind):
				report.add_finding(&"unknown_trigger_kind", ProgressionReport.SEVERITY_UNSUPPORTED,
					"trigger %d has a kind '%s' this model does not know" % [triggers[index].trigger_id, triggers[index].kind],
					{"trigger": triggers[index].trigger_id})
				ok = false
			for effect: Dictionary in triggers[index].effects:
				var kind: StringName = effect.get("kind", &"")
				if kind == FloorLayers.EFFECT_COMPLETE_FLOOR:
					goal_triggers.append(index)
				elif not _known_effect(kind):
					report.add_finding(&"unknown_effect", ProgressionReport.SEVERITY_UNSUPPORTED,
						"trigger %d has an effect kind '%s' this model does not know" % [triggers[index].trigger_id, kind],
						{"trigger": triggers[index].trigger_id})
					ok = false
		for index in switches.size():
			for effect: Dictionary in switches[index].effects:
				if not _known_effect(effect.get("kind", &"")):
					report.add_finding(&"unknown_effect", ProgressionReport.SEVERITY_UNSUPPORTED,
						"switch %d has an effect kind '%s' this model does not know" % [switches[index].switch_id, effect.get("kind", &"")],
						{"switch": switches[index].switch_id})
					ok = false
		_build_cells()
		_build_pieces()
		_build_adjacency()
		entry_piece = piece_containing(plan.entry_point.x, plan.entry_point.z)
		if entry_piece < 0:
			report.add_finding(&"entry_off_floor", ProgressionReport.SEVERITY_FAIL,
				"the entry point stands on no ground the Envoy's body can occupy")
			ok = false

	## ONLY WHAT PROGRESSION CAN DEPEND ON BECOMES STATE. A decorative prop or an unwatched optional
	## fight changes nothing the exit depends on, and every such record would double the state
	## space for no answer (Floor 2 carries 33 props). Relevance is a fixpoint read off the plan's own
	## cross-references: a record matters if some effect that matters names it, if it is watched by a
	## trigger that matters, if it shapes ground (a blocking prop), or if it holds the party (a
	## sealing encounter). Everything left out is listed in the report, never silently dropped.
	func _keep_only_what_progression_depends_on(report: ProgressionReport) -> void:
		var trigger_ok: Dictionary = {}
		var switch_ok: Dictionary = {}
		var breakable_ok: Dictionary = {}
		var carriable_ok: Dictionary = {}
		var encounter_ok: Dictionary = {}
		var changed: bool = true
		while changed:
			changed = false
			for trigger in plan.triggers:
				if not trigger_ok.has(trigger.trigger_id) and _effects_matter(trigger.effects, trigger_ok, switch_ok, carriable_ok, encounter_ok):
					trigger_ok[trigger.trigger_id] = true
					changed = true
			for encounter in plan.encounters:
				if encounter.role == FloorLayers.ROLE_AMBIENT or encounter_ok.has(encounter.encounter_id):
					continue
				if encounter.confines_player or _watched(FloorLayers.TRIGGER_ENCOUNTER_CLEARED, encounter.encounter_id, trigger_ok):
					encounter_ok[encounter.encounter_id] = true
					changed = true
			for hit_switch in plan.hit_switches:
				if switch_ok.has(hit_switch.switch_id):
					continue
				if _effects_matter(hit_switch.effects, trigger_ok, switch_ok, carriable_ok, encounter_ok) \
						or _watched(FloorLayers.TRIGGER_SWITCH_ACTIVATED, hit_switch.switch_id, trigger_ok):
					switch_ok[hit_switch.switch_id] = true
					changed = true
			for breakable in plan.breakables:
				if breakable_ok.has(breakable.breakable_id):
					continue
				if breakable.blocking_rect.get_area() > 0.0 or _watched(FloorLayers.TRIGGER_BREAKABLE_DESTROYED, breakable.breakable_id, trigger_ok):
					breakable_ok[breakable.breakable_id] = true
					changed = true
			for carriable in plan.carriables:
				if carriable_ok.has(carriable.carriable_id):
					continue
				# Any receiver takes any key, so one relevant receiver makes every key matter.
				if _any_relevant_receiver(trigger_ok) or _watched(FloorLayers.TRIGGER_CARRIABLE_LIFTED, carriable.carriable_id, trigger_ok):
					carriable_ok[carriable.carriable_id] = true
					changed = true
		for trigger in plan.triggers:
			if trigger_ok.has(trigger.trigger_id):
				triggers.append(trigger)
			else:
				_ignore(report, "triggers", trigger.trigger_id)
		for hit_switch in plan.hit_switches:
			if switch_ok.has(hit_switch.switch_id):
				switches.append(hit_switch)
			else:
				_ignore(report, "switches", hit_switch.switch_id)
		for breakable in plan.breakables:
			if breakable_ok.has(breakable.breakable_id):
				breakables.append(breakable)
			else:
				_ignore(report, "breakables", breakable.breakable_id)
		for carriable in plan.carriables:
			if carriable_ok.has(carriable.carriable_id):
				carriables.append(carriable)
			else:
				_ignore(report, "carriables", carriable.carriable_id)
		# Ambient sites have no dormant/active/cleared life in the sim (register_encounter), so
		# they have none here either.
		for encounter in plan.encounters:
			if encounter_ok.has(encounter.encounter_id):
				encounters.append(encounter)
			else:
				_ignore(report, "encounters", encounter.encounter_id)

	func _effects_matter(effects: Array[Dictionary], trigger_ok: Dictionary, switch_ok: Dictionary, carriable_ok: Dictionary, encounter_ok: Dictionary) -> bool:
		for effect: Dictionary in effects:
			var kind: StringName = effect.get("kind", &"")
			var target: int = int(effect.get("target_id", -1))
			match kind:
				FloorLayers.EFFECT_COMPLETE_FLOOR:
					return true
				FloorLayers.EFFECT_OPEN_CONNECTION, FloorLayers.EFFECT_BLOCK_CONNECTION, FloorLayers.EFFECT_TOGGLE_CONNECTION:
					if connection_index_of(target) >= 0:
						return true
				FloorLayers.EFFECT_ACTIVATE_ENCOUNTER:
					if encounter_ok.has(target):
						return true
				FloorLayers.EFFECT_ENABLE_TRIGGER:
					if trigger_ok.has(target):
						return true
				FloorLayers.EFFECT_REVEAL_SWITCH:
					if switch_ok.has(target):
						return true
				FloorLayers.EFFECT_REVEAL_CARRIABLE:
					if carriable_ok.has(target):
						return true
				_:
					# An effect this model does not know is reported by the caller; it counts as
					# mattering so the record that carries it is examined rather than dropped.
					if not _known_effect(kind):
						return true
		return false

	func _watched(kind: StringName, source_id: int, trigger_ok: Dictionary) -> bool:
		for trigger in plan.triggers:
			if trigger.kind == kind and trigger.source_id == source_id and trigger_ok.has(trigger.trigger_id):
				return true
		return false

	func _any_relevant_receiver(trigger_ok: Dictionary) -> bool:
		for trigger in plan.triggers:
			if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED and trigger_ok.has(trigger.trigger_id):
				return true
		return false

	static func _ignore(report: ProgressionReport, layer: String, id: int) -> void:
		if not report.ignored.has(layer):
			report.ignored[layer] = []
		report.ignored[layer].append(id)

	static func _known_effect(kind: StringName) -> bool:
		return kind in [FloorLayers.EFFECT_OPEN_CONNECTION, FloorLayers.EFFECT_BLOCK_CONNECTION,
			FloorLayers.EFFECT_TOGGLE_CONNECTION, FloorLayers.EFFECT_ACTIVATE_ENCOUNTER,
			FloorLayers.EFFECT_ENABLE_TRIGGER, FloorLayers.EFFECT_REVEAL_SWITCH,
			FloorLayers.EFFECT_REVEAL_CARRIABLE, FloorLayers.EFFECT_COMPLETE_FLOOR,
			FloorLayers.EFFECT_RESTORE_ENVOY_HEALTH]

	static func _known_trigger_kind(kind: StringName) -> bool:
		return kind in [FloorLayers.TRIGGER_REGION, FloorLayers.TRIGGER_GROUP_OCCUPANCY,
			FloorLayers.TRIGGER_BREAKABLE_DESTROYED, FloorLayers.TRIGGER_SWITCH_ACTIVATED,
			FloorLayers.TRIGGER_ENCOUNTER_CLEARED, FloorLayers.TRIGGER_CARRIABLE_INSERTED,
			FloorLayers.TRIGGER_CARRIABLE_LIFTED]

	# --- ground ----------------------------------------------------------------------------------

	## Occupancy triggers cut the ground: a region's footprint becomes its own cells, so walking
	## through it is a transition the search sees. Receivers and watchers cut nothing.
	func _is_occupancy(trigger: FloorTrigger) -> bool:
		return (trigger.kind == FloorLayers.TRIGGER_REGION or trigger.kind == FloorLayers.TRIGGER_GROUP_OCCUPANCY) \
				and trigger.region.get_area() > 0.0

	func _build_cells() -> void:
		for patch in plan.patches:
			_cut_into_cells(patch.rect, -1)
		for index in connections.size():
			_cut_into_cells(connections[index].aperture, index)

	func _cut_into_cells(ground: Rect2, connection_index: int) -> void:
		# Obstacles are holes: a point inside one is illegal for every body (WalkableBounds.fits).
		var pieces_of_ground: Array[Rect2] = [ground]
		for obstacle in plan.obstacles:
			pieces_of_ground = _subtract_all(pieces_of_ground, obstacle.rect)
		# Then each occupancy region and each blocking prop claims its footprint as tagged cells.
		var tagged: Array[Dictionary] = []
		for piece in pieces_of_ground:
			tagged.append({"rect": piece, "trigger": -1, "blocker": -1})
		for index in triggers.size():
			if _is_occupancy(triggers[index]):
				tagged = _claim(tagged, triggers[index].region, "trigger", index)
		for index in breakables.size():
			if breakables[index].blocking_rect.get_area() > 0.0:
				tagged = _claim(tagged, breakables[index].blocking_rect, "blocker", index)
		for piece in tagged:
			if piece["rect"].get_area() <= 0.0:
				continue
			cells.append({"id": cells.size(), "rect": piece["rect"], "trigger": piece["trigger"],
				"connection": connection_index, "blocker": piece["blocker"]})

	## Splits every piece the cutter overlaps into "inside, tagged" and "outside, as it was".
	static func _claim(pieces_of_ground: Array[Dictionary], cutter: Rect2, tag: String, value: int) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for piece in pieces_of_ground:
			var rect: Rect2 = piece["rect"]
			if not rect.intersects(cutter):
				out.append(piece)
				continue
			var inside: Dictionary = piece.duplicate()
			inside["rect"] = rect.intersection(cutter)
			inside[tag] = value  # a blocker over a plate is both
			out.append(inside)
			for remainder in _subtract(rect, cutter):
				var outside: Dictionary = piece.duplicate()
				outside["rect"] = remainder
				out.append(outside)
		return out

	static func _subtract_all(pieces_of_ground: Array[Rect2], cutter: Rect2) -> Array[Rect2]:
		var out: Array[Rect2] = []
		for piece in pieces_of_ground:
			out.append_array(_subtract(piece, cutter))
		return out

	## The same cut WalkableBounds makes when it asks what ground a body is missing: border-touching
	## rects cover nothing, so they are not cuts.
	static func _subtract(piece: Rect2, cutter: Rect2) -> Array[Rect2]:
		var out: Array[Rect2] = []
		if not piece.intersects(cutter):
			out.append(piece)
			return out
		var inter: Rect2 = piece.intersection(cutter)
		if inter.position.x > piece.position.x:
			out.append(Rect2(piece.position.x, piece.position.y, inter.position.x - piece.position.x, piece.size.y))
		if inter.end.x < piece.end.x:
			out.append(Rect2(inter.end.x, piece.position.y, piece.end.x - inter.end.x, piece.size.y))
		if inter.position.y > piece.position.y:
			out.append(Rect2(inter.position.x, piece.position.y, inter.size.x, inter.position.y - piece.position.y))
		if inter.end.y < piece.end.y:
			out.append(Rect2(inter.position.x, inter.end.y, inter.size.x, piece.end.y - inter.end.y))
		return out

	## WHERE A BODY'S CENTRE MAY BE. Legality is body-aware against the union of walkable rects
	## (WalkableBounds.fits), so the centre may stand wherever the whole footprint is on ground:
	## inside one cell eroded by the radius, or inside the strip two adjoining cells cover together
	## -- their overlap along the seam, spanning both across it -- eroded likewise and kept to the
	## cell it belongs to. Exact for a pair; ground only three cells cover together is not claimed
	## (stated limitation). With no body, every cell is its own piece, untouched.
	func _build_pieces() -> void:
		for cell in cells:
			var rect: Rect2 = cell["rect"]
			if radius <= 0.0:
				pieces.append({"id": pieces.size(), "rect": rect, "cell": int(cell["id"])})
				continue
			_add_piece(_erode(rect), int(cell["id"]))
			for other_cell in cells:
				if other_cell["id"] == cell["id"]:
					continue
				var other: Rect2 = other_cell["rect"]
				var x0: float = maxf(rect.position.x, other.position.x)
				var x1: float = minf(rect.end.x, other.end.x)
				var z0: float = maxf(rect.position.y, other.position.y)
				var z1: float = minf(rect.end.y, other.end.y)
				if x1 - x0 < -0.0001 or z1 - z0 < -0.0001:
					continue  # not even touching
				# Stacked along z: the shared x-strip spans both; side by side along x: the shared z-strip.
				var low_z: float = minf(rect.position.y, other.position.y)
				var low_x: float = minf(rect.position.x, other.position.x)
				if x1 - x0 > 0.0:
					var strip := Rect2(x0, low_z, x1 - x0, maxf(rect.end.y, other.end.y) - low_z)
					_add_piece(_clip(_erode(strip), rect), int(cell["id"]))
				if z1 - z0 > 0.0:
					var strip := Rect2(low_x, z0, maxf(rect.end.x, other.end.x) - low_x, z1 - z0)
					_add_piece(_clip(_erode(strip), rect), int(cell["id"]))

	## The part of `a` inside `b`, INCLUSIVE, so a line or a point survives (Rect2.intersection
	## drops anything with no area). Negative size when they do not meet.
	static func _clip(a: Rect2, b: Rect2) -> Rect2:
		if a.size.x < 0.0 or a.size.y < 0.0:
			return a
		var x0: float = maxf(a.position.x, b.position.x)
		var z0: float = maxf(a.position.y, b.position.y)
		return Rect2(x0, z0, minf(a.end.x, b.end.x) - x0, minf(a.end.y, b.end.y) - z0)

	func _erode_fits(ground: Rect2) -> bool:
		return ground.size.x >= 2.0 * radius - 0.0001 and ground.size.y >= 2.0 * radius - 0.0001

	func _erode(ground: Rect2) -> Rect2:
		if not _erode_fits(ground):
			return Rect2(0, 0, -1, -1)
		return Rect2(ground.position.x + radius, ground.position.y + radius,
			maxf(ground.size.x - 2.0 * radius, 0.0), maxf(ground.size.y - 2.0 * radius, 0.0))

	## A piece may be a line or a point (a cell exactly a body wide): still legal ground for a centre.
	func _add_piece(rect: Rect2, cell_id: int) -> void:
		if rect.size.x < 0.0 or rect.size.y < 0.0:
			return
		for piece in pieces:
			if int(piece["cell"]) == cell_id and piece["rect"] == rect:
				return
		pieces.append({"id": pieces.size(), "rect": rect, "cell": cell_id})

	## TWO PIECES JOIN WHERE THE CENTRE CAN PASS FROM ONE TO THE OTHER: they overlap, or share a
	## seam of positive length. A corner alone joins nothing (a path through a single point is not
	## something the clamp can be trusted to find).
	func _build_adjacency() -> void:
		adjacency.resize(pieces.size())
		for i in pieces.size():
			adjacency[i] = []
		for i in pieces.size():
			for j in range(i + 1, pieces.size()):
				if _joined(pieces[i]["rect"], pieces[j]["rect"]):
					adjacency[i].append(j)
					adjacency[j].append(i)

	static func _joined(a: Rect2, b: Rect2) -> bool:
		var span_x: float = minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
		var span_z: float = minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
		if span_x < -0.0001 or span_z < -0.0001:
			return false
		return maxf(span_x, span_z) > 0.0001

	func piece_containing(x: float, z: float) -> int:
		for piece in pieces:
			if WalkableBounds.contains(piece["rect"], x, z):
				return int(piece["id"])
		return -1

	## A piece of this cell, for carrying a position over from a model with a different body.
	func piece_of_cell(cell_id: int) -> int:
		for piece in pieces:
			if int(piece["cell"]) == cell_id:
				return int(piece["id"])
		return -1

	## A state of another model of the SAME plan, expressed in this model's pieces: positions are
	## carried over by the cell they stand in (cells do not depend on the body; pieces do).
	func translate(from: _Model, state: Dictionary) -> Dictionary:
		var out: Dictionary = state.duplicate(true)
		if int(state["pos"]) >= 0:
			out["pos"] = piece_of_cell(int(from.pieces[int(state["pos"])]["cell"]))
		for index in out["c_at"].size():
			if int(out["c_at"][index]) >= 0:
				out["c_at"][index] = piece_of_cell(int(from.pieces[int(out["c_at"][index])]["cell"]))
		return out

	static func distance_to_rect(x: float, z: float, rect: Rect2) -> float:
		var dx: float = maxf(maxf(rect.position.x - x, 0.0), x - rect.end.x)
		var dz: float = maxf(maxf(rect.position.y - z, 0.0), z - rect.end.y)
		return sqrt(dx * dx + dz * dz)

	func cell_of(piece_id: int) -> Dictionary:
		return cells[int(pieces[piece_id]["cell"])]

	# --- state -----------------------------------------------------------------------------------

	func initial_state() -> Dictionary:
		var state: Dictionary = {
			"pos": entry_piece,
			"open": [], "fired": [], "enabled": [], "broken": [], "sw_revealed": [], "sw_spent": [],
			"c_revealed": [], "c_at": [], "enc": [], "holding": -1, "confined": -1, "done": false,
		}
		for connection in connections:
			state["open"].append(connection.starts_open)
		for trigger in triggers:
			state["fired"].append(false)
			state["enabled"].append(trigger.starts_enabled)
		for breakable in breakables:
			state["broken"].append(false)
		for hit_switch in switches:
			state["sw_revealed"].append(not hit_switch.starts_hidden)
			state["sw_spent"].append(false)
		for carriable in carriables:
			state["c_revealed"].append(not carriable.starts_hidden)
			state["c_at"].append(_HOME)
		for encounter in encounters:
			state["enc"].append(0)  # 0 dormant, 1 active, 2 cleared
		return state

	static func key_of(state: Dictionary) -> String:
		return "%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|%d|%d|%s" % [state["pos"], state["open"], state["fired"],
			state["enabled"], state["broken"], state["sw_revealed"], state["sw_spent"], state["c_revealed"],
			state["c_at"], state["enc"], state["holding"], state["confined"], state["done"]]

	func trigger_index_of(trigger_id: int) -> int:
		for index in triggers.size():
			if triggers[index].trigger_id == trigger_id:
				return index
		return -1

	func connection_index_of(connection_id: int) -> int:
		for index in connections.size():
			if connections[index].connection_id == connection_id:
				return index
		return -1

	func switch_index_of(switch_id: int) -> int:
		for index in switches.size():
			if switches[index].switch_id == switch_id:
				return index
		return -1

	func carriable_index_of(carriable_id: int) -> int:
		for index in carriables.size():
			if carriables[index].carriable_id == carriable_id:
				return index
		return -1

	func encounter_index_of(encounter_id: int) -> int:
		for index in encounters.size():
			if encounters[index].encounter_id == encounter_id:
				return index
		return -1


# --- THE SEARCH: breadth-first over states, every transition one supported action ----------------

class _Search:
	extends RefCounted

	var model: _Model
	## The ranged_switches relaxation: a visible switch is hit from wherever the party stands.
	var ranged: bool = false
	var explored: Dictionary = {}   # key -> state
	var parent: Dictionary = {}     # key -> {"from": key, "action": String}
	var successors: Dictionary = {} # key -> Array[String]
	var goal_key: String = ""
	var goal_keys: Array[String] = []
	var over_budget: bool = false
	## Integrity constraints, resolved to THIS model's indices (a point model cuts ground into
	## different pieces, so ground is resolved per model, from the forbidden rects).
	var no_clear: Dictionary = {}     # encounter index -> true
	var no_lift: Dictionary = {}      # carriable index -> true
	var no_deliver: Dictionary = {}   # trigger index -> true
	var no_ground: Dictionary = {}    # piece id -> true
	var goal_kind: StringName = ProgressionValidator.GOAL_COMPLETE
	var goal_index: int = -1
	var goal_rect: Rect2 = Rect2()
	var set_down_anywhere: bool = false

	func _init(the_model: _Model, ranged_switches: bool, constraints: Dictionary = {}) -> void:
		model = the_model
		ranged = ranged_switches
		set_down_anywhere = bool(model.rules.get("set_down_anywhere", false))
		var forbid: Dictionary = constraints.get("forbid", {})
		for encounter_id: int in forbid.get(ProgressionValidator.FORBID_CLEAR, []):
			if model.encounter_index_of(encounter_id) >= 0:
				no_clear[model.encounter_index_of(encounter_id)] = true
		for carriable_id: int in forbid.get(ProgressionValidator.FORBID_LIFT, []):
			if model.carriable_index_of(carriable_id) >= 0:
				no_lift[model.carriable_index_of(carriable_id)] = true
		for trigger_id: int in forbid.get(ProgressionValidator.FORBID_DELIVER, []):
			if model.trigger_index_of(trigger_id) >= 0:
				no_deliver[model.trigger_index_of(trigger_id)] = true
		for ground: Rect2 in forbid.get(ProgressionValidator.FORBID_GROUND, []):
			for piece in model.pieces:
				if (piece["rect"] as Rect2).intersects(ground):
					no_ground[int(piece["id"])] = true
		var goal: Dictionary = constraints.get("goal", {})
		goal_kind = ProgressionValidator._goal_kind(goal)
		if goal_kind == ProgressionValidator.GOAL_LIFT:
			goal_index = model.carriable_index_of(int(goal[ProgressionValidator.GOAL_LIFT]))
		elif goal_kind == ProgressionValidator.GOAL_OPEN:
			goal_index = model.connection_index_of(int(goal[ProgressionValidator.GOAL_OPEN]))
		elif goal_kind == ProgressionValidator.GOAL_ENTER:
			goal_rect = goal[ProgressionValidator.GOAL_ENTER]

	## The goal the search stops at. Completion stops expansion (the floor is over); the other goals
	## are states like any other and the search goes on past them.
	func _is_goal(state: Dictionary) -> bool:
		match goal_kind:
			ProgressionValidator.GOAL_LIFT:
				return goal_index >= 0 and int(state["c_at"][goal_index]) == _HELD
			ProgressionValidator.GOAL_OPEN:
				return goal_index >= 0 and bool(state["open"][goal_index])
			ProgressionValidator.GOAL_ENTER:
				for piece_id: int in _reachable(state):
					if (model.pieces[piece_id]["rect"] as Rect2).intersects(goal_rect):
						return true
				return false
		return bool(state["done"])

	func run(start: Dictionary) -> void:
		if no_ground.has(int(start["pos"])):
			return  # arrival itself is forbidden ground: nothing can be reached
		var queue: Array[Dictionary] = [start]
		var start_key: String = _Model.key_of(start)
		explored[start_key] = start
		successors[start_key] = []
		if goal_kind != ProgressionValidator.GOAL_COMPLETE and _is_goal(start):
			goal_keys.append(start_key)
			goal_key = start_key
		# Arrival inside a live region fires it on the first tick, exactly as the sim's edge does:
		# the un-fired arrival is not a state anyone can act in.
		var arrival: Dictionary = _fire_if_standing_in_live_region(start, "arrive")
		if not arrival.is_empty():
			queue = []
			if _discover(arrival, start_key):
				queue.append(arrival["state"])
		while not queue.is_empty():
			var state: Dictionary = queue.pop_front()
			var key: String = _Model.key_of(state)
			if bool(state["done"]):
				continue
			if explored.size() > int(model.rules["max_states"]):
				over_budget = true
				return
			for move in _moves(state):
				if _discover(move, key):
					queue.append(move["state"])

	func _discover(move: Dictionary, from_key: String) -> bool:
		var next: Dictionary = move["state"]
		if not bool(move.get("canonical", false)):
			_canonicalise(next)
		var next_key: String = _Model.key_of(next)
		successors[from_key].append(next_key)
		if explored.has(next_key):
			return false
		explored[next_key] = next
		successors[next_key] = []
		parent[next_key] = {"from": from_key, "action": move["action"]}
		if _is_goal(next):
			goal_keys.append(next_key)
			if goal_key == "":
				goal_key = next_key
		return true

	## Where the Envoy stands within one state is any piece of its reachable ground; one
	## representative (the lowest id, preferring plain ground over a region) keeps the state space
	## finite and the same position from being explored once per piece.
	func _canonicalise(state: Dictionary) -> void:
		var reach: Dictionary = _reachable(state)
		var best: int = -1
		var best_plain: int = -1
		for piece_id: int in reach:
			if best < 0 or piece_id < best:
				best = piece_id
			if int(model.cell_of(piece_id)["trigger"]) < 0 and (best_plain < 0 or piece_id < best_plain):
				best_plain = piece_id
		if best_plain >= 0:
			state["pos"] = best_plain
		elif best >= 0:
			state["pos"] = best

	func trace_to(key: String) -> Array[String]:
		var steps: Array[String] = []
		var at: String = key
		while parent.has(at):
			steps.push_front(parent[at]["action"])
			at = parent[at]["from"]
		return steps

	## Every explored state from which no goal state can be reached, by reverse walk from the goals.
	func states_that_cannot_finish() -> Array[String]:
		var reverse: Dictionary = {}
		for from_key in successors:
			for to_key in successors[from_key]:
				if not reverse.has(to_key):
					reverse[to_key] = []
				reverse[to_key].append(from_key)
		var can_finish: Dictionary = {}
		var queue: Array[String] = goal_keys.duplicate()
		for key in queue:
			can_finish[key] = true
		while not queue.is_empty():
			var key: String = queue.pop_front()
			for from_key in reverse.get(key, []):
				if not can_finish.has(from_key):
					can_finish[from_key] = true
					queue.append(from_key)
		var stuck: Array[String] = []
		for key in explored:
			if not can_finish.has(key):
				stuck.append(key)
		return stuck

	## What a stuck state is held up by: the closed gates and unfired triggers, by id.
	func refs_for(state: Dictionary) -> Dictionary:
		var closed: Array[int] = []
		for index in model.connections.size():
			if not bool(state["open"][index]):
				closed.append(model.connections[index].connection_id)
		var unfired: Array[int] = []
		for index in model.triggers.size():
			if not bool(state["fired"][index]):
				unfired.append(model.triggers[index].trigger_id)
		return {"closed_connections": closed, "unfired_triggers": unfired}

	## Across every explored state: the gates no supported action ever opened, the triggers none fired.
	func frontier_refs() -> Dictionary:
		var never_opened: Dictionary = {}
		for index in model.connections.size():
			never_opened[index] = true
		var never_fired: Dictionary = {}
		for index in model.triggers.size():
			never_fired[index] = true
		for key in explored:
			var state: Dictionary = explored[key]
			for index in model.connections.size():
				if bool(state["open"][index]):
					never_opened.erase(index)
			for index in model.triggers.size():
				if bool(state["fired"][index]):
					never_fired.erase(index)
		var closed: Array[int] = []
		for index in never_opened:
			closed.append(model.connections[index].connection_id)
		closed.sort()
		var unfired: Array[int] = []
		for index in never_fired:
			unfired.append(model.triggers[index].trigger_id)
		unfired.sort()
		return {"connections_never_opened": closed, "triggers_never_fired": unfired}

	# --- reachability within one state --------------------------------------------------------

	func _enterable(state: Dictionary, cell: Dictionary) -> bool:
		if int(cell["connection"]) >= 0 and not bool(state["open"][int(cell["connection"])]):
			return false
		if int(cell["blocker"]) >= 0 and not bool(state["broken"][int(cell["blocker"])]):
			return false
		return true

	func _live_trigger(state: Dictionary, trigger_index: int) -> bool:
		if trigger_index < 0:
			return false
		if not bool(state["enabled"][trigger_index]):
			return false
		return not (model.triggers[trigger_index].once and bool(state["fired"][trigger_index]))

	## Ground the Envoy can stand on without firing anything: from its piece, across joined pieces,
	## never INTO a live region (that is an action). Starting inside one is allowed, since standing
	## still re-fires nothing (edge-triggered).
	func _reachable(state: Dictionary) -> Dictionary:
		var seen: Dictionary = {}
		var start: int = int(state["pos"])
		if start < 0:
			return seen
		var queue: Array[int] = [start]
		seen[start] = true
		while not queue.is_empty():
			var at: int = queue.pop_front()
			for next: int in model.adjacency[at]:
				if seen.has(next):
					continue
				var cell: Dictionary = model.cell_of(next)
				if not _enterable(state, cell) or _live_trigger(state, int(cell["trigger"])) or no_ground.has(next):
					continue
				seen[next] = true
				queue.append(next)
		return seen

	# --- the supported actions -------------------------------------------------------------------

	func _moves(state: Dictionary) -> Array[Dictionary]:
		var moves: Array[Dictionary] = []
		# A SEALING ENCOUNTER HOLDS THE PARTY: until it is cleared nothing else is reachable -- and a
		# fight forbidden to clear holds it for good.
		if int(state["confined"]) >= 0:
			if not no_clear.has(int(state["confined"])):
				moves.append(_clear_encounter(state, int(state["confined"])))
			return moves
		var reach: Dictionary = _reachable(state)
		# 1. Step into a live region from ground beside it.
		for piece in model.pieces:
			var cell: Dictionary = model.cells[int(piece["cell"])]
			var trigger_index: int = int(cell["trigger"])
			if not _live_trigger(state, trigger_index) or not _enterable(state, cell) or no_ground.has(int(piece["id"])):
				continue
			if not _beside_reach(int(piece["id"]), reach):
				continue
			var next: Dictionary = _copy(state)
			next["pos"] = int(piece["id"])
			_fire(next, trigger_index)
			moves.append({"state": next, "action": "enter trigger %d" % model.triggers[trigger_index].trigger_id})
		# 2. Break a prop from ground within attack reach (reach plus the prop's own radius).
		for index in model.breakables.size():
			if bool(state["broken"][index]):
				continue
			var prop: BreakablePlan = model.breakables[index]
			var from: int = _piece_within(reach, prop.position, float(model.rules["attack_reach"]) + prop.radius)
			if from < 0:
				continue
			var next: Dictionary = _copy(state)
			next["pos"] = from
			_drop_if_holding(next)
			next["broken"][index] = true
			_fire_watchers(next, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, prop.breakable_id)
			moves.append({"state": next, "action": "break breakable %d" % prop.breakable_id})
		# 3. Hit a visible switch.
		for index in model.switches.size():
			var hit_switch: HitSwitchPlan = model.switches[index]
			if not bool(state["sw_revealed"][index]):
				continue
			if hit_switch.mode == HitSwitchPlan.MODE_ONE_SHOT and bool(state["sw_spent"][index]):
				continue
			var from: int = _piece_within(reach, hit_switch.position, float(model.rules["attack_reach"]) + hit_switch.radius)
			var shot: bool = false
			if from < 0 and ranged and not reach.is_empty():
				from = int(state["pos"])
				shot = true
			if from < 0:
				continue
			var next: Dictionary = _copy(state)
			next["pos"] = from
			_drop_if_holding(next)
			next["sw_spent"][index] = true
			for effect: Dictionary in hit_switch.effects:
				_apply(next, effect)
			_fire_watchers(next, FloorLayers.TRIGGER_SWITCH_ACTIVATED, hit_switch.switch_id)
			moves.append({"state": next, "action": "%s switch %d" % ["shoot" if shot else "hit", hit_switch.switch_id]})
		# 4. Lift a key, if the hands are free.
		if int(state["holding"]) < 0:
			for index in model.carriables.size():
				var at: int = int(state["c_at"][index])
				if at == _HELD or at == _INSERTED or not bool(state["c_revealed"][index]) or no_lift.has(index):
					continue
				var key_point: Vector3 = model.carriables[index].position if at == _HOME else _centre(model.pieces[at]["rect"])
				var from: int = _piece_within(reach, key_point, float(model.rules["pickup_reach"]))
				if from < 0:
					continue
				var next: Dictionary = _copy(state)
				next["pos"] = from
				next["holding"] = index
				next["c_at"][index] = _HELD
				_fire_watchers(next, FloorLayers.TRIGGER_CARRIABLE_LIFTED, model.carriables[index].carriable_id)
				moves.append({"state": next, "action": "lift carriable %d" % model.carriables[index].carriable_id})
		# 5. Deliver the held key at an unfilled receiver the Envoy can stand in.
		if int(state["holding"]) >= 0:
			for index in model.triggers.size():
				var trigger: FloorTrigger = model.triggers[index]
				if trigger.kind != FloorLayers.TRIGGER_CARRIABLE_INSERTED or not _live_trigger(state, index) or no_deliver.has(index):
					continue
				var from: int = _piece_overlapping(reach, trigger.region)
				if from < 0:
					continue
				var next: Dictionary = _copy(state)
				next["pos"] = from
				var held: int = int(next["holding"])
				next["holding"] = -1
				next["c_at"][held] = _INSERTED
				_fire(next, index)
				moves.append({"state": next, "action": "deliver carriable %d to receiver %d" % [model.carriables[held].carriable_id, trigger.trigger_id]})
		# 6. Clear an active encounter (assumed winnable, recorded).
		for index in model.encounters.size():
			if int(state["enc"][index]) == 1 and not no_clear.has(index):
				moves.append(_clear_encounter(state, index))
		# 7. Set the held key down on reachable ground (the voluntary drop; opt-in). Never inside a
		# live receiver: there the same press delivers instead, exactly as in the sim. ONE POINT PER
		# CELL, the lowest reachable piece of it: cells are exactly where doors, regions and masses
		# cut the ground, so two set-downs in one cell differ in nothing progression can tell apart.
		# The Envoy stays where it stood (its reachable ground is unchanged), so the state is
		# already canonical and is not re-walked.
		if set_down_anywhere and int(state["holding"]) >= 0:
			var ids: Array = reach.keys()
			ids.sort()
			var cells_done: Dictionary = {}
			for piece_id: int in ids:
				var cell_id: int = int(model.pieces[piece_id]["cell"])
				if cells_done.has(cell_id) or _in_live_receiver(state, piece_id):
					continue
				cells_done[cell_id] = true
				var next: Dictionary = _copy(state)
				var held: int = int(next["holding"])
				next["holding"] = -1
				next["c_at"][held] = piece_id
				moves.append({"state": next, "action": "set down carriable %d" % model.carriables[held].carriable_id, "canonical": true})
		return moves

	func _in_live_receiver(state: Dictionary, piece_id: int) -> bool:
		for index in model.triggers.size():
			var trigger: FloorTrigger = model.triggers[index]
			if trigger.kind == FloorLayers.TRIGGER_CARRIABLE_INSERTED and _live_trigger(state, index) \
					and (model.pieces[piece_id]["rect"] as Rect2).intersects(trigger.region, true):
				return true
		return false

	func _clear_encounter(state: Dictionary, index: int) -> Dictionary:
		var encounter: EncounterSite = model.encounters[index]
		var next: Dictionary = _copy(state)
		_drop_if_holding(next)
		next["enc"][index] = 2
		if int(next["confined"]) == index:
			next["confined"] = -1
		_fire_watchers(next, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, encounter.encounter_id)
		return {"state": next, "action": "clear encounter %d" % encounter.encounter_id}

	func _drop_if_holding(state: Dictionary) -> void:
		var held: int = int(state["holding"])
		if held < 0:
			return
		state["holding"] = -1
		state["c_at"][held] = int(state["pos"])

	# --- firing and effects, as SimWorld does them ------------------------------------------------

	func _fire(state: Dictionary, trigger_index: int) -> void:
		if model.triggers[trigger_index].once:
			state["fired"][trigger_index] = true
		for effect: Dictionary in model.triggers[trigger_index].effects:
			_apply(state, effect)

	## Watchers of a source fire if not yet spent -- SimWorld._fire_triggers_watching consults
	## `fired` alone; `enabled` gates occupancy evaluation only. Mirrored exactly.
	func _fire_watchers(state: Dictionary, kind: StringName, source_id: int) -> void:
		for index in model.triggers.size():
			var trigger: FloorTrigger = model.triggers[index]
			if trigger.kind != kind or trigger.source_id != source_id or bool(state["fired"][index]):
				continue
			_fire(state, index)

	func _apply(state: Dictionary, effect: Dictionary) -> void:
		var kind: StringName = effect.get("kind", &"")
		var target: int = int(effect.get("target_id", -1))
		match kind:
			FloorLayers.EFFECT_OPEN_CONNECTION, FloorLayers.EFFECT_BLOCK_CONNECTION:
				var index: int = model.connection_index_of(target)
				if index >= 0:
					state["open"][index] = kind == FloorLayers.EFFECT_OPEN_CONNECTION
			FloorLayers.EFFECT_TOGGLE_CONNECTION:
				var index: int = model.connection_index_of(target)
				if index >= 0:
					state["open"][index] = not bool(state["open"][index])
			FloorLayers.EFFECT_ACTIVATE_ENCOUNTER:
				var index: int = model.encounter_index_of(target)
				if index >= 0 and int(state["enc"][index]) == 0:
					state["enc"][index] = 1
					if model.encounters[index].confines_player:
						state["confined"] = index
			FloorLayers.EFFECT_ENABLE_TRIGGER:
				var index: int = model.trigger_index_of(target)
				if index >= 0 and not bool(state["enabled"][index]):
					state["enabled"][index] = true
					# Enabled under an Envoy already standing on it: the next tick fires it.
					var pos: int = int(state["pos"])
					if pos >= 0 and int(model.cell_of(pos)["trigger"]) == index and _live_trigger(state, index):
						_fire(state, index)
			FloorLayers.EFFECT_REVEAL_SWITCH:
				var index: int = model.switch_index_of(target)
				if index >= 0:
					state["sw_revealed"][index] = true
			FloorLayers.EFFECT_REVEAL_CARRIABLE:
				var index: int = model.carriable_index_of(target)
				if index >= 0:
					state["c_revealed"][index] = true
			FloorLayers.EFFECT_COMPLETE_FLOOR:
				state["done"] = true
			FloorLayers.EFFECT_RESTORE_ENVOY_HEALTH:
				pass

	func _fire_if_standing_in_live_region(state: Dictionary, action: String) -> Dictionary:
		var pos: int = int(state["pos"])
		if pos < 0:
			return {}
		var trigger_index: int = int(model.cell_of(pos)["trigger"])
		if not _live_trigger(state, trigger_index):
			return {}
		var next: Dictionary = _copy(state)
		_fire(next, trigger_index)
		return {"state": next, "action": "%s inside trigger %d" % [action, model.triggers[trigger_index].trigger_id]}

	# --- geometry helpers --------------------------------------------------------------------------

	## A region piece is entered from a joined piece the Envoy can already stand on.
	func _beside_reach(piece_id: int, reach: Dictionary) -> bool:
		for neighbour: int in model.adjacency[piece_id]:
			if reach.has(neighbour):
				return true
		return false

	## The lowest-id reachable piece within `distance` of the point, preferring plain ground over a
	## region (standing in a dormant region is a choice, never forced on the Envoy), or -1.
	func _piece_within(reach: Dictionary, point: Vector3, distance: float) -> int:
		var ids: Array = reach.keys()
		ids.sort()
		var fallback: int = -1
		for piece_id: int in ids:
			if _Model.distance_to_rect(point.x, point.z, model.pieces[piece_id]["rect"]) > distance + 0.0001:
				continue
			if int(model.cell_of(piece_id)["trigger"]) < 0:
				return piece_id
			if fallback < 0:
				fallback = piece_id
		return fallback

	## The lowest-id reachable piece the region overlaps (inclusive, as occupancy is), or -1.
	func _piece_overlapping(reach: Dictionary, region: Rect2) -> int:
		var ids: Array = reach.keys()
		ids.sort()
		for piece_id: int in ids:
			if (model.pieces[piece_id]["rect"] as Rect2).intersects(region, true):
				return piece_id
		return -1

	static func _centre(rect: Rect2) -> Vector3:
		return Vector3(rect.position.x + rect.size.x * 0.5, 0.0, rect.position.y + rect.size.y * 0.5)

	static func _copy(state: Dictionary) -> Dictionary:
		return state.duplicate(true)
