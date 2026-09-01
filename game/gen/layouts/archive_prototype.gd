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
##   revealing a HIDDEN PLATE -> standing on it opens the blocked route -> PARTY PLATE: rear
##   seals, forward opens, roster spawns, encounter begins -> clear -> the way onward opens ->
##   ramp to raised ground -> EXIT PLATE completes the floor.
##
## THERE IS NO `interact` VERB ON THIS FLOOR. Every control is something you STAND ON, and the
## floor has no press left that a player could not have discovered by walking.
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
## The door-control response: a small, UNSEALED arrival when the hidden plate opens the way.
const E_PLATE_RESPONSE := 2

# Trigger ids
const T_COMMIT := 0
const T_CRATE := 1
const T_HIDDEN_PLATE := 2
const T_PARTY_PLATE := 3
const T_CLEARED := 4
const T_EXIT_PLATE := 5

## What the crate hides: a plate, dormant until the crate is gone. Sits where the crate stood,
## down the west branch, deliberately far from the route it opens.
##
## SMALLER THAN THE PARTY PLATE, footprint and look both (human finding 2026-08-29). The two
## read as different KINDS OF THING -- a local control you discovered, versus a coordinated
## commitment the whole expedition steps onto -- and that difference is carried entirely by
## authoring and presentation. No mechanic distinguishes them.
##
## The footprint shrinks WITH the mesh, never independently: a plate whose visual is smaller
## than its trigger would fire from ground that does not look like a plate, which is exactly
## the kind of quiet dishonesty the gate/rule split exists to prevent.
const HIDDEN_PLATE_REGION := Rect2(-13.0, -25.0, 2.0, 2.0)
## The plate the expedition must stand on to commit to the fight. Sits inside pApproach, so the
## seal closes around where the party already is.
const PARTY_PLATE_REGION := Rect2(-2.0, -41.0, 4.0, 4.0)
## THE FLOOR EXIT. Not a passive marker any more: progression is gated on the whole expedition
## standing here together, which is the same condition the party plate asks (FloorLayers).
const EXIT_PLATE_REGION := Rect2(-2.0, -97.0, 4.0, 4.0)

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
	# THE ROUNDABOUT, authored per side (2026-09-01). The human wanted this space to stop feeling
	# boxed in; the VOID must stay solid because P34's progression protection depends on it -- the
	# concealed crate sits across that hole and must not be shootable from the hall.
	#
	# So the ring is opened OUTWARD and kept solid INWARD:
	#   outer perimeter          -> ledge, and the space reads as open
	#   void-facing interior     -> wall, and the hole reads as a real separation
	# Patch-level style could not say both, which is precisely what falsified it.
	_patch(plan, P_HALL_SOUTH, Rect2(-16.0, -16.0, 32.0, 4.0), 0.0, &"stone", &"wall",
		{"north": &"ledge", "east": &"ledge", "west": &"ledge"})  # south faces the void
	_patch(plan, P_HALL_WEST, Rect2(-16.0, -30.0, 8.0, 16.0), 0.0, &"stone", &"wall",
		{"west": &"ledge"})  # east faces the void
	_patch(plan, P_HALL_EAST, Rect2(8.0, -30.0, 8.0, 16.0), 0.0, &"stone", &"wall",
		{"east": &"ledge"})  # west faces the void
	_patch(plan, P_HALL_NORTH, Rect2(-16.0, -34.0, 32.0, 6.0), 0.0, &"stone", &"wall",
		{"south": &"ledge", "east": &"ledge", "west": &"ledge"})  # north faces the void
	_patch(plan, P_APPROACH, Rect2(-6.0, -42.0, 12.0, 6.0), 0.0, &"stone")
	# Arena keeps the dimensions VALIDATED BY PLAY as a combat room (30 x 20).
	_patch(plan, P_ARENA, Rect2(-15.0, -68.0, 30.0, 20.0), 0.0, &"arena")
	_patch(plan, P_RAMP, Rect2(-4.0, -76.0, 8.0, 6.0), 1.0, &"ramp")
	# THE RAISED PLATFORM READS AS A LEDGE, not a walled box. Sim legality is identical -- the
	# Envoy still cannot step off -- but nothing is rendered to hide the drop, which is the
	# whole point of the distinction (human finding: not every walkable edge needs a wall).
	_patch(plan, P_HIGH, Rect2(-12.0, -88.0, 24.0, 14.0), 2.0, &"high", &"ledge")
	_patch(plan, P_END, Rect2(-6.0, -98.0, 12.0, 6.0), 2.0, &"high", &"ledge")


static func _patch(plan: FloorPlan, patch_id: int, rect: Rect2, elevation: float, surface: StringName, boundary_style: StringName = &"wall", side_overrides: Dictionary = {}) -> void:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	patch.elevation = elevation
	patch.surface = surface
	patch.boundary_style = boundary_style
	patch.boundary_north = side_overrides.get("north", &"")
	patch.boundary_south = side_overrides.get("south", &"")
	patch.boundary_east = side_overrides.get("east", &"")
	patch.boundary_west = side_overrides.get("west", &"")
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
	_trigger(plan, T_COMMIT, FloorLayers.TRIGGER_REGION, plan.patch_by_id(P_HALL_SOUTH).rect, -1, [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_COMMIT),
	])
	# SEARCH -> DISCOVERY, with no press in it. Breaking the crate ENABLES the plate it hid;
	# stepping onto that plate opens the forward route. The discovery is the crate and the
	# plate, never a keypress -- the E only ever confirmed something the player already knew.
	_trigger(plan, T_CRATE, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, Rect2(), B_CRATE, [
		FloorLayers.effect(FloorLayers.EFFECT_ENABLE_TRIGGER, T_HIDDEN_PLATE),
	])
	# THE DOOR-CONTROL BEAT: opening the way is answered. One authored record, two effects, no new
	# machinery -- the audit found the beat already expressible as trigger + connection effect +
	# encounter activation, so nothing was built for it.
	_trigger(plan, T_HIDDEN_PLATE, FloorLayers.TRIGGER_REGION, HIDDEN_PLATE_REGION, -1, [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_APPROACH),
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_PLATE_RESPONSE),
	], false, true)
	# THE PARTY PLATE -- the whole reference sequence as ONE authored record. Reading these
	# three lines tells you everything standing on it does; splitting them across gate, spawn
	# and presentation code is how "why did the door shut?" becomes unanswerable.
	#
	# It is a PLATE, not a button: the beat was always "the party commits together", and an E
	# press could never express that. Its condition is every living Envoy standing here at once
	# (solo resolves to one), and it fires on the FALSE -> TRUE edge, so waiting on it is quiet.
	_trigger(plan, T_PARTY_PLATE, FloorLayers.TRIGGER_GROUP_OCCUPANCY, PARTY_PLATE_REGION, -1, [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_TO_APPROACH),
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_ARENA),
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_ARENA),
	], true, true)
	# THE REAL PREREQUISITE FOR THE WAY OUT IS THE FIGHT. Both remaining connections open on the
	# clear, so the route onward is continuous once it is earned. The switch that used to sit on
	# the high ground is gone: it gated nothing the clear had not already decided.
	_trigger(plan, T_CLEARED, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, Rect2(), E_ARENA, [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_RAMP),
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_END),
	])
	# THE EXIT IS THE SAME QUESTION AS THE COMMITMENT: is everyone here? One shared condition,
	# two authored consequences. Completing the floor is a FACT and an Event -- there is no next
	# floor yet, and faking one to give this somewhere to go would be building a system to
	# satisfy a flag.
	_trigger(plan, T_EXIT_PLATE, FloorLayers.TRIGGER_GROUP_OCCUPANCY, EXIT_PLATE_REGION, -1, [
		FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, -1),
	], true, true)


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


static func _trigger(plan: FloorPlan, trigger_id: int, kind: StringName, region: Rect2, source_id: int, effects: Array[Dictionary], starts_enabled: bool = true, renders_as_plate: bool = false) -> void:
	var trigger := FloorTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.kind = kind
	trigger.region = region
	trigger.source_id = source_id
	trigger.effects = effects
	trigger.starts_enabled = starts_enabled
	trigger.renders_as_plate = renders_as_plate
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

	# THE DOOR-CONTROL RESPONSE. OPTIONAL and explicitly NOT sealing: solving the floor draws
	# attention, but the player may still walk away up the route they just opened. `confines_player
	# = false` is what keeps this a pressure beat rather than a second arena, and
	# `spawn_at_floor_load = false` is what makes it ARRIVE rather than having been waiting.
	var response := EncounterSite.new()
	response.encounter_id = E_PLATE_RESPONSE
	response.regions = [plan.patch_by_id(P_HALL_WEST).rect, plan.patch_by_id(P_HALL_SOUTH).rect]
	response.role = FloorLayers.ROLE_OPTIONAL
	response.confines_player = false
	response.spawn_at_floor_load = false
	response.roster = [{"enemy_key": &"fang", "position": Vector3(-12.0, 0.0, -17.0)}]
	plan.encounters.append(response)

	# AMBIENT. No activation ceremony and no lock: it inhabits the east column and fights if you
	# cross it. Territory is authored as a UNION and may span patches -- binding it to the single
	# patch it spawns in is what made it stick the instant the player crossed a seam.
	#
	# BUT IT IS DELIBERATELY ONE CONVEX RECTANGLE, not the whole hall ring. Instrumentation
	# (tools/diagnose_ooze_pursuit.gd) confirmed that a territory wrapping the VOID makes
	# straight-line pursuit rub along the corner: 80 of 80 contact-phase ticks lost to legality
	# for 0.9 units of progress. The AI has no obstacle routing and this prototype is not the
	# place to invent one, so the AUTHORING obeys the AI's actual capability:
	#
	#   AMBIENT TERRITORIES USED BY STRAIGHT-LINE AI MUST BE CONVEX -- their walkable union must
	#   equal their own bounding box, so no pursuit inside them ever needs to route around
	#   anything. Guarded by test_depth_generator.gd, not by memory.
	#
	# This column spans the east arm and its junction with BOTH strips, so the Ooze still meets
	# anyone crossing its ground, and reads as guarding its arm rather than scraping a corner.
	# Obstacle-aware navigation is ROADMAP work (P33), for a floor that actually needs it.
	var east := EncounterSite.new()
	east.encounter_id = E_EAST_AMBIENT
	east.regions = [Rect2(8.0, -34.0, 8.0, 22.0)]
	east.role = FloorLayers.ROLE_AMBIENT
	east.confines_player = false
	east.spawn_at_floor_load = true
	east.roster = [{"enemy_key": &"ooze", "position": Vector3(12.0, 0.0, -22.0)}]
	plan.encounters.append(east)


# --- WORLD INTERACTION -----------------------------------------------------------------

static func _interaction(plan: FloorPlan) -> void:
	# The blocker's solution is deliberately ELSEWHERE, down the west branch, under a prop.
	var crate := BreakablePlan.new()
	crate.breakable_id = B_CRATE
	crate.position = Vector3(-12.0, 0.0, -24.0)
	crate.radius = 0.9
	crate.durability = 1.0
	crate.conceals_trigger_id = T_HIDDEN_PLATE
	plan.breakables.append(crate)
