class_name ArchivePrototypeLayout
extends RefCounted
## THE HAND-AUTHORED PROTOTYPE FLOOR. One deterministic floor built through the production data
## structures, to test the floor GRAMMAR before any procedural assembly exists.
##
## DATA-AS-CODE, deliberately. A .tres schema for six interlocking layers would have to be
## invented, hand-written and thrown away before a second floor ever exists (§1.4 rule of two).
## When a second authored floor arrives, THIS is what migrates to a resource -- not sooner.
##
## THE GRAMMAR IT ENCODES, in order:
##   START -> one-way commitment -> irregular open hall wrapping a VOID -> a forward route
##   visible but BLOCKED -> a branch (west solves, east is inhabited) -> breakable search
##   revealing a switch -> switch opens the blocked route -> PARTY PLATE: rear seals, forward
##   opens, roster spawns, encounter begins -> clear -> the way onward opens -> ramp to raised
##   ground -> endpoint.
##
## TWO BEATS CHANGED AFTER HUMAN PLAY (2026-08-29), both removing input that bought nothing:
##   * the party button is now a PLATE you stand on, not an E interactable -- a coordination
##     trigger, which is what the beat always meant (ruled).
##   * the final switch is GONE. An obvious door whose only ask was one E press had no
##     discovery and no decision in it, so the last connection now opens from its REAL
##     prerequisite: clearing the encounter. No puzzle was invented to preserve the press.
##
##  z=0    ┌───────────────┐                     p0  START
##         │       ▲       │
##  -6     └──────┬┬───────┘
##                ││ c0  one-way: entering the hall seals it behind you
##  -12    ┌──────┴┴───────┐                     pS  hall, south strip
##  -16    ├────┐     ┌────┤
##         │ pW │VOID │ pE │  <- paths wrap a hole; pE is AMBIENT territory
##  -28/30 ├────┘     └────┤
##  -34    └──────┬┬───────┘                     pN  hall, north strip
##                ││ c1  BLOCKED -- visible from the hall long before it opens
##  -36    ┌──────┴┴───────┐                     pApproach  (PARTY PLATE, stand on it)
##  -42    └──────┬┬───────┘
##                ││ c2  BLOCKED until the button
##  -48    ┌──────┴┴───────┐
##         │    ARENA      │                     pArena  (validated combat dimensions)
##  -68    └──────┬┬───────┘
##                ││ c3  BLOCKED until the encounter clears
##  -70/76 ┌──────┴┴───────┐  pRamp   elevation 1
##  -74/88 │   HIGH GROUND │  pHigh   elevation 2  (LEDGE edges: no wall mesh, still bounded)
##                ││ c4  opens with c3, on the same encounter clear
##  -92/98 └──────┴┴───────┘  pEnd    endpoint marker
##
## EVERY CONNECTION APERTURE OVERLAPS BOTH PATCHES IT JOINS by _OVERLAP; patches that simply
## touch would share zero area and make the threshold a discontinuity. Patch-to-patch overlaps
## inside the hall need no connection at all -- connectivity is rectangle overlap, and a
## TraversalConnection exists only where CONTROL is wanted.

const _OVERLAP: float = 1.5
const _APERTURE_HALF_WIDTH: float = 2.5

# Patch ids
const P_START := 0
const P_HALL_SOUTH := 1
const P_HALL_WEST := 2
const P_HALL_EAST := 3
const P_HALL_NORTH := 4
const P_APPROACH := 5
const P_ARENA := 6
const P_RAMP := 7
const P_HIGH := 8
const P_END := 9

# Connection ids
const C_COMMIT := 0
const C_TO_APPROACH := 1
const C_TO_ARENA := 2
const C_TO_RAMP := 3
const C_TO_END := 4

# Encounter ids
const E_ARENA := 0
const E_EAST_AMBIENT := 1

# Interactable ids
const I_HIDDEN_SWITCH := 0

## The plate the expedition must stand on to commit to the fight. Sits inside pApproach, so the
## seal closes around where the party already is.
const PARTY_PLATE_REGION := Rect2(-2.0, -41.0, 4.0, 4.0)

# Breakable ids
const B_CRATE := 0


static func build(plan: FloorPlan) -> void:
	_spatial(plan)
	_progression(plan)
	_encounters(plan)
	_interaction(plan)
	plan.entry_point = Vector3(0.0, 0.0, -3.0)
	plan.end_marker = Vector3(0.0, 0.0, -95.0)


# --- SPATIAL --------------------------------------------------------------------------

static func _spatial(plan: FloorPlan) -> void:
	# The hall is FOUR patches forming a ring. The hole in the middle is not authored as a
	# "void object" -- it is simply ground nobody laid, which is the whole reason irregular
	# silhouettes are free in a union-of-patches model.
	_patch(plan, P_START, Rect2(-7.0, -6.0, 14.0, 6.0), 0.0, &"stone")
	_patch(plan, P_HALL_SOUTH, Rect2(-16.0, -16.0, 32.0, 4.0), 0.0, &"stone")
	_patch(plan, P_HALL_WEST, Rect2(-16.0, -30.0, 8.0, 16.0), 0.0, &"stone")
	_patch(plan, P_HALL_EAST, Rect2(8.0, -30.0, 8.0, 16.0), 0.0, &"stone")
	_patch(plan, P_HALL_NORTH, Rect2(-16.0, -34.0, 32.0, 6.0), 0.0, &"stone")
	_patch(plan, P_APPROACH, Rect2(-6.0, -42.0, 12.0, 6.0), 0.0, &"stone")
	# Arena keeps the dimensions VALIDATED BY PLAY as a combat room (30 x 20).
	_patch(plan, P_ARENA, Rect2(-15.0, -68.0, 30.0, 20.0), 0.0, &"arena")
	_patch(plan, P_RAMP, Rect2(-4.0, -76.0, 8.0, 6.0), 1.0, &"ramp")
	# THE RAISED PLATFORM READS AS A LEDGE, not a walled box. Sim legality is identical -- the
	# Envoy still cannot step off -- but nothing is rendered to hide the drop, which is the
	# whole point of the distinction (human finding: not every walkable edge needs a wall).
	_patch(plan, P_HIGH, Rect2(-12.0, -88.0, 24.0, 14.0), 2.0, &"high", &"ledge")
	_patch(plan, P_END, Rect2(-6.0, -98.0, 12.0, 6.0), 2.0, &"high", &"ledge")


static func _patch(plan: FloorPlan, patch_id: int, rect: Rect2, elevation: float, surface: StringName, boundary_style: StringName = &"wall") -> void:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	patch.elevation = elevation
	patch.surface = surface
	patch.boundary_style = boundary_style
	plan.patches.append(patch)


# --- PROGRESSION ----------------------------------------------------------------------

static func _progression(plan: FloorPlan) -> void:
	_connect(plan, C_COMMIT, P_START, P_HALL_SOUTH, true)
	_connect(plan, C_TO_APPROACH, P_HALL_NORTH, P_APPROACH, false)
	_connect(plan, C_TO_ARENA, P_APPROACH, P_ARENA, false)
	_connect(plan, C_TO_RAMP, P_ARENA, P_RAMP, false)
	_connect(plan, C_TO_END, P_HIGH, P_END, false)

	# ONE-WAY COMMITMENT, expressed as an ordinary controller rather than a new legality rule:
	# reaching the hall fires once and blocks the way back. Nothing about C_COMMIT is special.
	_trigger(plan, 0, FloorLayers.TRIGGER_REGION, plan.patch_by_id(P_HALL_SOUTH).rect, -1, [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_COMMIT),
	])
	# Search -> discovery: breaking the crate reveals the switch that opens the forward route.
	_trigger(plan, 1, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, Rect2(), B_CRATE, [
		FloorLayers.effect(FloorLayers.EFFECT_REVEAL_INTERACTABLE, I_HIDDEN_SWITCH),
	])
	_trigger(plan, 2, FloorLayers.TRIGGER_INTERACTED, Rect2(), I_HIDDEN_SWITCH, [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_APPROACH),
	])
	# THE PARTY PLATE -- the whole reference sequence as ONE authored record. Reading these
	# three lines tells you everything standing on it does; splitting them across gate, spawn
	# and presentation code is how "why did the door shut?" becomes unanswerable.
	#
	# It is a PLATE, not a button: the beat was always "the party commits together", and an E
	# press could never express that. Its condition is every living Envoy standing here at once
	# (solo resolves to one), and it fires on the FALSE -> TRUE edge, so waiting on it is quiet.
	_trigger(plan, 3, FloorLayers.TRIGGER_PARTY_PLATE, PARTY_PLATE_REGION, -1, [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_TO_APPROACH),
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_ARENA),
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_ARENA),
	])
	# THE REAL PREREQUISITE FOR THE WAY OUT IS THE FIGHT. Both remaining connections open on the
	# clear, so the route onward is continuous once it is earned. The switch that used to sit on
	# the high ground is gone: it gated nothing the clear had not already decided.
	_trigger(plan, 4, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, Rect2(), E_ARENA, [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_RAMP),
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_END),
	])


## Builds the aperture between two patches stacked along -Z, poking _OVERLAP into each.
static func _connect(plan: FloorPlan, connection_id: int, near_id: int, far_id: int, starts_open: bool) -> void:
	var near: Rect2 = plan.patch_by_id(near_id).rect
	var far: Rect2 = plan.patch_by_id(far_id).rect
	var min_z: float = far.end.y - _OVERLAP
	var max_z: float = near.position.y + _OVERLAP
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = Rect2(-_APERTURE_HALF_WIDTH, min_z, _APERTURE_HALF_WIDTH * 2.0, max_z - min_z)
	connection.starts_open = starts_open
	plan.connections.append(connection)


static func _trigger(plan: FloorPlan, trigger_id: int, kind: StringName, region: Rect2, source_id: int, effects: Array[Dictionary]) -> void:
	var trigger := FloorTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.kind = kind
	trigger.region = region
	trigger.source_id = source_id
	trigger.effects = effects
	plan.triggers.append(trigger)


# --- ENCOUNTER ------------------------------------------------------------------------

static func _encounters(plan: FloorPlan) -> void:
	# MANDATORY. Its region spans the approach, the corridor and the arena so that pressing the
	# button from the approach never leaves the Envoy standing outside their own confinement --
	# the seal closes around where the player already is, it never drags them somewhere.
	var arena := EncounterSite.new()
	arena.encounter_id = E_ARENA
	arena.regions = [Rect2(-15.0, -68.0, 30.0, 32.0)]
	arena.role = FloorLayers.ROLE_MANDATORY
	arena.confines_player = true
	arena.spawn_at_floor_load = false  # the button summons them; that is the point of the beat
	arena.roster = [
		{"enemy_key": &"fang", "position": Vector3(-8.0, 0.0, -60.0)},
		{"enemy_key": &"ooze", "position": Vector3(9.0, 0.0, -58.0)},
		{"enemy_key": &"watcher", "position": Vector3(0.0, 0.0, -63.0)},
	]
	plan.encounters.append(arena)

	# AMBIENT. No activation ceremony and no lock: it inhabits the hall and fights if you cross
	# it. Its territory is the EAST ARM PLUS BOTH STRIPS -- a union, authored deliberately.
	# Binding it to the single patch it spawns in is what made it stick on the corner the
	# instant the player stepped across a seam (human finding), and confinement was never the
	# defect. The WEST ARM is pointedly excluded: the branch that solves the floor stays a place
	# you can work in, which is what makes the branch mean anything.
	# Still CONFINED, and still no roaming system and no pathfinding.
	var east := EncounterSite.new()
	east.encounter_id = E_EAST_AMBIENT
	east.regions = [
		plan.patch_by_id(P_HALL_EAST).rect,
		plan.patch_by_id(P_HALL_SOUTH).rect,
		plan.patch_by_id(P_HALL_NORTH).rect,
	]
	east.role = FloorLayers.ROLE_AMBIENT
	east.confines_player = false
	east.spawn_at_floor_load = true
	east.roster = [{"enemy_key": &"ooze", "position": Vector3(12.0, 0.0, -22.0)}]
	plan.encounters.append(east)


# --- WORLD INTERACTION -----------------------------------------------------------------

static func _interaction(plan: FloorPlan) -> void:
	# The blocker's solution is deliberately ELSEWHERE, down the west branch, behind a prop.
	# THE ONLY INTERACTABLE LEFT ON THE FLOOR, and the only one that earned its E: you have to
	# search for it, and breaking the crate is what reveals it.
	_interactable(plan, I_HIDDEN_SWITCH, Vector3(-12.0, 0.0, -24.0), &"switch", true)

	var crate := BreakablePlan.new()
	crate.breakable_id = B_CRATE
	crate.position = Vector3(-12.0, 0.0, -24.0)
	crate.radius = 0.9
	crate.durability = 1.0
	crate.conceals_interactable_id = I_HIDDEN_SWITCH
	plan.breakables.append(crate)


static func _interactable(plan: FloorPlan, interactable_id: int, position: Vector3, kind: StringName, starts_hidden: bool) -> void:
	var interactable := InteractablePlan.new()
	interactable.interactable_id = interactable_id
	interactable.position = position
	interactable.kind = kind
	interactable.starts_hidden = starts_hidden
	plan.interactables.append(interactable)
