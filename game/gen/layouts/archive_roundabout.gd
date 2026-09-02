class_name ArchiveRoundaboutLayout
extends RefCounted
## FLOOR 2 - the second hand-authored floor, and the test of whether the grammar generalises.
##
## THE QUESTION IT ANSWERS: can the same vocabulary produce a materially different convincing
## place without another foundational rewrite? Nothing here is a new primitive. Every beat is
## built from what Floor 1 proved: patches, traversal connections, occupancy triggers, effects,
## encounter roles, and boundary styles.
##
## TOPOLOGY: fork and rejoin, deliberately NOT another ring or corridor chain.
##
##   z=-2     +--------------+
##            |   OVERLOOK   |  e3   entry, establishing view of the concourse and the fork
##   -10      +------++------+
##                   || c0
##   -18      +------++------+
##            |     RAMP     |  e1.5
##            +------++------+
##                   || c1
##   -46 +-----------++--------------------+
##       |        OPEN CONCOURSE           |  ambient home; [] control plate by the A mouth
##       +--------++--------++-------------+
##        c2 GATED||        || c3 open
##   -62 +--------++-+ gap +-++-----------+  c4  +----------+
##       | ROUTE A    | 8u |   ROUTE B    +------+  VAULT   |  empty; exploratory space
##   -61 +-----+------+    +------+-------+      +----------+
##   -71 +-----+------------------+---------------+
##       |              JUNCTION                  |  <- SEEN across the gap
##       +------------++--------------------------+
##                    || c5  always open
##   -85 +------------++-+
##       |    TERRACE    | e1  [] all-party exit
##       +---------------+
##
## THE FORK IS 20 UNITS WIDE, NOT 46 (2026-09-02). It was structurally real and behaviourally
## invisible: the camera reaches 34 units of width at the mouths' depth, so two mouths 46 apart
## could never appear together, and the player picked a side by walking at one wall of a very
## wide room. The CONCOURSE KEEPS ITS RATIFIED WIDTH -- the openness was the floor's best beat --
## and only the mouths moved inboard. Measured through the real shipped camera: both land near
## 25% and 75% across, with the Junction dead centre between them.
##
## ROUTES A AND B ARE NOT MIRRORS. The exit sits at the Terrace's west end, so Route B (open,
## east) lands a long walk from it while Route A (gated, west) drops in beside it. Route A saves
## roughly 14 units of walking toward a destination the player can already see.
##
## THE CONTROL DOES NOT CHARGE DISTANCE, BECAUSE IT CANNOT. Costing every placement showed the
## two requirements are opposed on a one-pass floor: a detour big enough to feel like a price
## costs MORE than the 14 units the shortcut saves, and any detour cheap enough to preserve the
## shortcut's value is nearly free. So the control sits where its purpose is legible -- in sight
## of the mouth it opens -- and the PRICE is the response it wakes, which now stands AT that
## mouth rather than loose in the open room the player could simply walk away from.
##
## MEASURED BEFORE BUILDING, not assumed: the Junction reads at 19% down the screen from the
## Concourse's north edge, so the visible-before-reachable beat is real; and accepted v1 Ooze
## locomotion transits the fork with zero stall ticks.
##
## THE VAULT IS EMPTY (2026-09-02). Its fight asked for a detour, combat and risk and paid
## essentially nothing, so it was deactivated rather than given a faked reward. The room remains
## as exploratory space. With no fight to occlude, its mixed WALL/LEDGE treatment lost its
## rationale and was removed rather than preserved to keep a capability alive -- per-edge
## overrides now have ZERO authored consumers, recorded for the zero-consumer audit.
##
## NO INTERMEDIATE PARTY PLATE. It required the same all-party occupancy as the exit, immediately
## before the exit, and its only consequence was opening a door a few steps away -- with the real
## exit already visible on screen while standing on it. The final exit owns synchronisation now.

# Patch ids
const P_OVERLOOK := 0
const P_RAMP := 1
const P_CONCOURSE := 2
const P_ROUTE_A := 3
const P_ROUTE_B := 4
const P_VAULT := 5
const P_JUNCTION := 6
const P_TERRACE := 7

# Connection ids
const C_DESCEND := 0
const C_RAMP := 1
const C_TO_A := 2
const C_TO_B := 3
const C_VAULT := 4
const C_TO_TERRACE := 5

# Encounter ids
const E_CONCOURSE_AMBIENT := 0
const E_CONTROL_RESPONSE := 1

# Trigger ids
const T_CONTROL := 0
const T_EXIT := 1

## PLATE SIZE SIGNALS SEMANTIC WEIGHT, carried over from Floor 1 as an authoring convention:
## small for a local single-actor action, large for party synchronisation and floor transition.
## No schema needed -- a plate's footprint IS its trigger region.
## PLACED FOR CAUSAL LEGIBILITY, not for walking cost. It sits just short of the mouth it opens,
## so "this control buys that way down" is something the player sees rather than deduces.
const CONTROL_PLATE := Rect2(-11.0, -44.0, 2.0, 2.0)
const EXIT_PLATE := Rect2(-22.0, -82.0, 4.0, 4.0)


static func build(plan: FloorPlan) -> void:
	_spatial(plan)
	_progression(plan)
	_encounters(plan)
	plan.entry_point = Vector3(0.0, 0.0, -6.0)
	plan.end_marker = Vector3(-20.0, 0.0, -79.0)


# --- SPATIAL ---------------------------------------------------------------------------

static func _spatial(plan: FloorPlan) -> void:
	_patch(plan, P_OVERLOOK, Rect2(-8.0, -10.0, 16.0, 8.0), 3.0, &"high", &"ledge")
	_patch(plan, P_RAMP, Rect2(-4.0, -18.0, 8.0, 8.0), 1.5, &"ramp", &"ledge")
	# THE CONCOURSE is one rect on purpose: an ambient territory must be convex (P33), and a single
	# rectangle is convex by construction rather than by inspection.
	_patch(plan, P_CONCOURSE, Rect2(-26.0, -46.0, 52.0, 28.0), 0.0, &"stone", &"ledge")
	# BOTH ROUTES STAND OFF THE CONCOURSE BY 2 UNITS, and their apertures bridge the gap.
	# Route A's gate is closable, and a closable gate between TOUCHING patches separates nothing:
	# inclusive edges plus body-aware union legality make a body straddling the seam legal, so the
	# union spans it whether the gate is open or shut (FloorPlan._reject_bypassable_gates). Route B
	# needs no gate, but is stood off identically -- an asymmetric fork would read as two different
	# kinds of opening when they are meant to read as one choice with two answers.
	# MOUTHS 20 APART, not 46: a lateral choice only reads as a choice when both options fit the
	# camera's reach at the decision point.
	_patch(plan, P_ROUTE_A, Rect2(-16.0, -62.0, 12.0, 14.0), 0.0, &"stone", &"ledge")
	_patch(plan, P_ROUTE_B, Rect2(4.0, -62.0, 12.0, 14.0), 0.0, &"stone", &"ledge")
	# THE VAULT, now an empty alcove off Route B. Uniformly LEDGE like the rest of the floor: the
	# mixed treatment existed to occlude a fight that no longer happens here, and a validated
	# capability is not entitled to survive without a consumer.
	_patch(plan, P_VAULT, Rect2(18.0, -60.0, 12.0, 12.0), 0.0, &"arena", &"ledge")
	# The junction spans the full width, so both routes rejoin it by patch OVERLAP -- no aperture
	# is needed where no CONTROL is wanted, exactly as the hall's arms worked on Floor 1.
	_patch(plan, P_JUNCTION, Rect2(-30.0, -71.0, 60.0, 10.0), 0.0, &"stone", &"ledge")
	# STOOD OFF THE JUNCTION for the same reason: its gate is closable, so the aperture must be
	# the only thing bridging the two.
	_patch(plan, P_TERRACE, Rect2(-28.0, -85.0, 16.0, 12.0), 1.0, &"high", &"ledge")


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


# --- PROGRESSION -----------------------------------------------------------------------

static func _progression(plan: FloorPlan) -> void:
	_connect(plan, C_DESCEND, P_OVERLOOK, P_RAMP, Rect2(-2.5, -11.5, 5.0, 3.0), true)
	_connect(plan, C_RAMP, P_RAMP, P_CONCOURSE, Rect2(-2.5, -19.5, 5.0, 3.0), true)
	# THE GATED SHORTCUT. Closed until the Concourse control is stood on.
	_connect(plan, C_TO_A, P_CONCOURSE, P_ROUTE_A, Rect2(-12.5, -50.0, 5.0, 6.0), false)
	# THE OPEN ROUTE, and the floor's natural first traversal. Shaped to match its twin, so the
	# fork reads as one choice with two answers rather than two kinds of opening.
	_connect(plan, C_TO_B, P_CONCOURSE, P_ROUTE_B, Rect2(7.5, -50.0, 5.0, 6.0), true)
	# The Vault's mouth. Spans the standoff so it overlaps BOTH -- Route B ends at x=16, the
	# Vault starts at x=18.
	_connect(plan, C_VAULT, P_ROUTE_B, P_VAULT, Rect2(14.5, -56.5, 5.0, 5.0), true)
	# ALWAYS OPEN, and barrier-less. The all-party plate that used to gate this was redundant
	# with the exit a few steps beyond it -- the same requirement, immediately again, with the
	# real exit already on screen while standing on it.
	_connect(plan, C_TO_TERRACE, P_JUNCTION, P_TERRACE, Rect2(-22.5, -74.5, 5.0, 5.0), true, false)

	# THE CONTROL BEAT: one record, two consequences -- the shortcut opens AND something takes up
	# position at it. Non-sealing, so buying the shortcut is never a mandatory combat lock; the
	# player may open Route A, look at what is standing in it, and take the long way instead.
	_trigger(plan, T_CONTROL, FloorLayers.TRIGGER_REGION, CONTROL_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_A),
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_CONTROL_RESPONSE),
	], true)
	# THE ONLY COMMITMENT PLATE ON THE FLOOR. It inherits the loud treatment automatically:
	# prominence is DERIVED from trigger.kind in presentation, never authored twice.
	_trigger(plan, T_EXIT, FloorLayers.TRIGGER_GROUP_OCCUPANCY, EXIT_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, -1),
	], true)


static func _connect(plan: FloorPlan, connection_id: int, near_id: int, far_id: int, aperture: Rect2, starts_open: bool, has_barrier: bool = true) -> void:
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = aperture
	connection.has_barrier = has_barrier
	connection.starts_open = starts_open
	plan.connections.append(connection)


static func _trigger(plan: FloorPlan, trigger_id: int, kind: StringName, region: Rect2, effects: Array[Dictionary], renders_as_plate: bool) -> void:
	var trigger := FloorTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.kind = kind
	trigger.region = region
	trigger.source_id = -1
	trigger.effects = effects
	trigger.renders_as_plate = renders_as_plate
	plan.triggers.append(trigger)


# --- ENCOUNTERS ------------------------------------------------------------------------

static func _encounters(plan: FloorPlan) -> void:
	# AMBIENT, living in the concourse. Its home is the single concourse rect, so P33's convexity
	# constraint holds by construction. Pursuit itself is detection-governed and may follow the
	# player anywhere; home only decides where it walks back to.
	var ambient := EncounterSite.new()
	ambient.encounter_id = E_CONCOURSE_AMBIENT
	ambient.regions = [plan.patch_by_id(P_CONCOURSE).rect]
	ambient.role = FloorLayers.ROLE_AMBIENT
	ambient.confines_player = false
	ambient.spawn_at_floor_load = true
	ambient.roster = [
		{"enemy_key": &"ooze", "position": Vector3(10.0, 0.0, -34.0)},
		{"enemy_key": &"fang", "position": Vector3(-8.0, 0.0, -40.0)},
	]
	plan.encounters.append(ambient)

	# THE CONTROL RESPONSE, standing AT the mouth it guards (2026-09-02).
	#
	# It used to wake loose in the Concourse -- the room the player was already standing in and
	# could simply walk away from -- so even its cost was soft. Costing the control by DISTANCE
	# was then shown to be impossible on a one-pass floor: a detour big enough to feel like a
	# price costs more than the 14 units the shortcut saves, and anything cheaper is nearly free.
	# So the price is this, paid by whoever actually takes the shortcut, and the trade is honest:
	# the long way is free, the short way goes through something.
	#
	# NON-SEALING and LOCAL. Its territory is Route A alone, which is one rect and therefore
	# convex by construction (P33).
	var response := EncounterSite.new()
	response.encounter_id = E_CONTROL_RESPONSE
	response.regions = [plan.patch_by_id(P_ROUTE_A).rect]
	response.role = FloorLayers.ROLE_OPTIONAL
	response.confines_player = false
	response.spawn_at_floor_load = false
	response.roster = [
		{"enemy_key": &"watcher", "position": Vector3(-10.0, 0.0, -52.0)},
		{"enemy_key": &"fang", "position": Vector3(-13.0, 0.0, -56.0)},
	]
	plan.encounters.append(response)
