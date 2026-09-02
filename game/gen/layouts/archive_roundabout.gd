class_name ArchiveRoundaboutLayout
extends RefCounted
## FLOOR 2 — the second hand-authored floor, and the test of whether the grammar generalises.
##
## THE QUESTION IT ANSWERS: can the same vocabulary produce a materially different convincing
## place without another foundational rewrite? Nothing here is a new primitive. Every beat is
## built from what Floor 1 proved: patches, traversal connections, occupancy triggers, effects,
## encounter roles, and boundary styles.
##
## TOPOLOGY: fork and rejoin, deliberately NOT another ring or corridor chain.
##
##   z=-2     ┌──────────────┐
##            │   OVERLOOK   │  e3   entry, establishing view of the concourse and the fork
##   -10      └──────┬┬──────┘
##                   ││ c0
##   -18      ┌──────┴┴──────┐
##            │     RAMP     │  e1.5
##            └──────┬┬──────┘
##                   ││ c1
##   -46 ┌───────────┴┴────────────────────┐
##       │          OPEN CONCOURSE           │  ambient home; ▫ control plate
##       └──┬┬──────────────────────────┬┬─┘
##          ││ c2 GATED          c3 open ││
##   -62 ┌──┴┴────┐    ~~ GAP ~~    ┌────┴┴──┐  c4  ┌──────────┐
##       │ ROUTE A │   (32 wide)    │ ROUTE B ├─────┤  VAULT   │ ▫ opt-in
##   -61 └────┬────┘                └────┬───┘      └──────────┘
##   -71 ┌────┴─────────────────────────┴─────────┐
##       │  JUNCTION   ▪ party-sync (WEST end)     │  <- SEEN across the gap
##       └────┬┬──────────────────────────────────┘
##            ││ c5  opens on party-sync
##   -85 ┌────┴┴─────┐
##       │  TERRACE  │ e1  ▪ all-party exit
##       └───────────┘
##
## EVERY CLOSABLE GATE BRIDGES A REAL GAP. Patches joined by a gate that can shut are disjoint,
## so the aperture is the only thing spanning them -- otherwise the union spans the seam anyway
## and the gate is decoration (FloorPlan._reject_bypassable_gates).
##
## ROUTES A AND B ARE NOT MIRRORS. The party-sync plate sits at the junction's WEST end, so
## Route B (open, east) lands a long walk from it while Route A (gated, west) drops in beside it.
## That is what makes the fork a decision rather than a decoration: the Concourse control BUYS a
## shortcut, and pays for it with the response it wakes. No rewards, no drops -- spatial value
## only, which is all the deferred economy permits.
##
## MEASURED BEFORE BUILDING, not assumed:
##   * the Junction reads at 19% down the screen from the Concourse north edge (real camera,
##     unproject_position) -- the visible-before-reachable beat is real. The Overlook CANNOT
##     carry a view of the Terrace, so it is not asked to.
##   * accepted v1 Ooze locomotion transits the Route B fork with zero stall ticks.
##
## WALLS ONLY WHERE THEY EARN IT. Everything is LEDGE except the Vault, whose inward sides are
## WALL so the optional fight cannot be farmed by shooting in from the gallery -- and whose outer
## map-facing side is LEDGE, because that edge is merely exposed. One patch, two meanings: the
## per-edge vocabulary's first shipped consumer.

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
const E_VAULT := 2

# Trigger ids
const T_CONTROL := 0
const T_VAULT := 1
const T_PARTY := 2
const T_EXIT := 3

## PLATE SIZE SIGNALS SEMANTIC WEIGHT, carried over from Floor 1 as an authoring convention:
## small for a local single-actor action, large for party synchronisation and floor transition.
## No schema needed -- a plate's footprint IS its trigger region.
const CONTROL_PLATE := Rect2(-15.0, -33.0, 2.0, 2.0)
const VAULT_PLATE := Rect2(35.0, -56.0, 2.0, 2.0)
const PARTY_PLATE := Rect2(-24.0, -68.0, 4.0, 4.0)
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
	_patch(plan, P_ROUTE_A, Rect2(-30.0, -62.0, 14.0, 14.0), 0.0, &"stone", &"ledge")
	_patch(plan, P_ROUTE_B, Rect2(16.0, -62.0, 14.0, 14.0), 0.0, &"stone", &"ledge")
	# THE VAULT: solid inward for occlusion, open on the map-facing east side.
	# SET APART FROM ROUTE B, not abutting it. Abutting rects share zero AREA -- so they would not
	# connect for movement -- while still suppressing each other's wall, because ground lies just
	# beyond the edge. That combination reads as an open side you cannot cross. Standing the vault
	# off by 2 units lets its own walls derive, and the aperture below carves the single mouth.
	_patch(plan, P_VAULT, Rect2(32.0, -60.0, 12.0, 12.0), 0.0, &"arena", &"wall", {"east": &"ledge"})
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
	# DEEPER THAN WIDE, deliberately. The sim derives a closed gate's solid barrier from the
	# aperture's proportions, so a mouth wider than it is deep gets a barrier lying ALONG the
	# direction of travel -- shots then run parallel to it and pass through the shut gate.
	_connect(plan, C_TO_A, P_CONCOURSE, P_ROUTE_A, Rect2(-24.5, -50.0, 5.0, 6.0), false)
	# THE OPEN ROUTE, and the floor's natural first traversal.
	# Shaped to match its twin, so the fork reads as one choice with two answers.
	_connect(plan, C_TO_B, P_CONCOURSE, P_ROUTE_B, Rect2(19.5, -50.0, 5.0, 6.0), true)
	# The Vault's mouth: open, because the encounter inside is opt-in rather than gated.
	# Spans the standoff so it overlaps BOTH -- route B ends at x=30, the vault starts at x=32.
	_connect(plan, C_VAULT, P_ROUTE_B, P_VAULT, Rect2(28.5, -56.5, 5.0, 5.0), true)
	_connect(plan, C_TO_TERRACE, P_JUNCTION, P_TERRACE, Rect2(-22.5, -74.5, 5.0, 5.0), false)

	# THE CONTROL BEAT: one record, two consequences -- the shortcut opens AND something notices.
	# Non-sealing, so buying the shortcut never becomes a mandatory combat lock.
	_trigger(plan, T_CONTROL, FloorLayers.TRIGGER_REGION, CONTROL_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_A),
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_CONTROL_RESPONSE),
	], true)
	# OPT-IN. The Vault fight exists only if the player deliberately steps on its plate; walking
	# in, looking, and leaving costs nothing.
	_trigger(plan, T_VAULT, FloorLayers.TRIGGER_REGION, VAULT_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_VAULT),
	], true)
	_trigger(plan, T_PARTY, FloorLayers.TRIGGER_GROUP_OCCUPANCY, PARTY_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_TERRACE),
	], true)
	_trigger(plan, T_EXIT, FloorLayers.TRIGGER_GROUP_OCCUPANCY, EXIT_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, -1),
	], true)


static func _connect(plan: FloorPlan, connection_id: int, near_id: int, far_id: int, aperture: Rect2, starts_open: bool) -> void:
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = aperture
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

	# THE CONTROL RESPONSE. Optional and NON-SEALING: opening the shortcut wakes something, but
	# the player may still walk away up either route.
	var response := EncounterSite.new()
	response.encounter_id = E_CONTROL_RESPONSE
	response.regions = [plan.patch_by_id(P_CONCOURSE).rect]
	response.role = FloorLayers.ROLE_OPTIONAL
	response.confines_player = false
	response.spawn_at_floor_load = false
	response.roster = [{"enemy_key": &"watcher", "position": Vector3(-18.0, 0.0, -38.0)}]
	plan.encounters.append(response)

	# THE VAULT. Genuinely skippable in GEOMETRY, not merely in metadata: Route B reaches the
	# junction without ever entering, and this site never confines anyone.
	var vault := EncounterSite.new()
	vault.encounter_id = E_VAULT
	vault.regions = [plan.patch_by_id(P_VAULT).rect]
	vault.role = FloorLayers.ROLE_OPTIONAL
	vault.confines_player = false
	vault.spawn_at_floor_load = false
	vault.roster = [
		{"enemy_key": &"fang", "position": Vector3(33.0, 0.0, -51.0)},
		{"enemy_key": &"ooze", "position": Vector3(39.0, 0.0, -57.0)},
	]
	plan.encounters.append(vault)
