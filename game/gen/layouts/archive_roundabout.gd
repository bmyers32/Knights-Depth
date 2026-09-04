class_name ArchiveRoundaboutLayout
extends RefCounted
## FLOOR 2 — three folded legs (rebuilt 2026-09-04).
##
## THE MEASURED PROBLEM: the previous version showed 10 of its 11 spaces from the drop, six of
## them at half or more. The cause was not size. The floor was laid out ALONG the camera's
## strongest viewing direction, and it had almost nothing to occlude with.
##
## THE CAMERA IS THE CONSTRAINT, and it was measured rather than guessed:
##   * the view is DEEP AND NARROW -- half-width 13 at the player's own depth, 45.6 at sixty
##     ahead, widening ~0.54 per unit. So a north-south column of spaces is read end to end, and
##     lateral offset alone can never win, because the offset needed grows as fast as the floor.
##   * a wall of height h at distance t hides ground out to t/(1 - h/12). At the DEFAULT obstacle
##     height of 2.4 that is barely 12 units of shadow -- useless. At height 9 a fold wall hides
##     the whole of the next leg. THAT is why the walls below are tall, and why they are few.
##
## MEASURED AFTER AUTHORING, not predicted: from the drop the floor now shows OVERLOOK 100%,
## DESCENT 100%, LANDING 88%, LANE A 36% -- four of fourteen spaces, and nothing past the first
## corner. From the Landing it shows two. The middle leg appears when the player turns into
## Lane A; the late leg when they reach Fold 2. That is the progression, and it is a number.
##
##   z=-2   +----------+
##          | OVERLOOK | e3                        LEG A runs SOUTH, west side
##  -12     +----++----+
##          | DESCENT  | e1.5    c1 ONE-WAY, sealed behind you
##  -26     +----++----+
##  -48 +--------++--------+----------------+
##      |     LANDING      |     LANE A     |  first fight, then east
##  -24 +------------------+-------++-------+
##      ################################  ||   <- FOLD WALL 1 (height 9), gap at the connector
##  -60                            +------++-+
##                                 | FOLD 1  |
##  -76 +-------------------+------++--------+   +--------+
##      |     GALLERY       |   SPILLWAY     |c8 |  VAULT |   LEG B runs WEST
##  -52 +---++--------------+----------------+   +--------+
##      || ################################       <- FOLD WALL 2 (height 9), gap at the west
## -100 ++--------+
##      | FOLD 2  |
## -114 +---------+---------------------+
##      |      PUZZLE BAY               |   ^ toggle switch, both doors legible
##      +----[D1]----------[D2]---------+
## -130 +---------+      +--------------+
##      |  WEST   |      |    EAST      |   LEG C runs EAST
##      +---------+      +------++------+
## -146                  +-------++---------------------+
##                       |        JUNCTION              |
##                       +------------++----------------+
## -162                               +--++------+
##                                    | TERRACE  | e1  [] all-party exit
##                                    +----------+
##
## EACH LEG TURNS ACROSS THE VIEW, and a tall architectural mass stands at each fold with the
## connector as its only gap. That is the whole method: the floor cooperates with the camera
## instead of pointing down it.
##
## OPENNESS IS PRESERVED, deliberately. Every patch edge stays a LEDGE with its low rim -- the
## human liked that and it is not reversed here. The walls are FEW and LARGE, placed only where
## the floor needs to hide a later chapter. Open local spaces, separated by occluding transitions.
##
## THE WALLS ARE REAL WALLS. They exclude bodies, stop shots and are drawn from the same authored
## rect. A sight blocker that a shot passes through would be the presentation-lies defect P34 was
## fought over, arriving through the back door.
##
## THE ALTERNATING DOORS are the first true consumer of the reversible switch: one toggle in the
## bay, both doors visible from it, and the doors swap together. Not the Vault -- that stays a
## simple local one-shot beside its own door, because its unresolved problem is destination
## reward, never switch complexity.

# Patch ids
const P_OVERLOOK := 0
const P_DESCENT := 1
const P_LANDING := 2
const P_LANE_A := 3
const P_FOLD1 := 4
const P_SPILLWAY := 5
const P_GALLERY := 6
const P_VAULT := 7
const P_FOLD2 := 8
const P_PUZZLE_BAY := 9
const P_PUZZLE_WEST := 10
const P_PUZZLE_EAST := 11
const P_JUNCTION := 12
const P_TERRACE := 13

# Connection ids
const C_DESCEND := 0
const C_COMMIT := 1
const C_VAULT := 2
const C_DOOR_WEST := 3
const C_DOOR_EAST := 4
const C_TO_TERRACE := 5

# Encounter ids
const E_LANDING := 0
const E_GALLERY := 1
const E_SPILLWAY := 2
const E_JUNCTION := 3

# Trigger ids
const T_COMMIT := 0
const T_GALLERY := 1
const T_SPILLWAY := 2
const T_JUNCTION := 3
const T_EXIT := 4
const T_VAULT_REVEAL := 5

# World object ids
const S_VAULT := 0        # concealed one-shot, beside the vault door
const S_ALTERNATE := 1    # the toggle, in the puzzle bay
const B_VAULT_COVER := 0  # ordinary prop, one hit
const B_GALLERY_RUBBLE := 1
const B_BAY_PROP := 2

const EXIT_PLATE := Rect2(9.0, -158.0, 4.0, 4.0)

## TALL ENOUGH TO MATTER. A fold wall exists to hide the next chapter, and the arithmetic above
## says 2.4 would hide twelve units of it. Nine hides the whole of the next leg from the one
## before -- measured, then raised from seven when the Landing was still reading 40% of the late
## floor down the western channel.
const _FOLD_WALL_HEIGHT: float = 9.0


static func build(plan: FloorPlan) -> void:
	_spatial(plan)
	_progression(plan)
	_world_objects(plan)
	_encounters(plan)
	plan.entry_point = Vector3(-36.0, 0.0, -7.0)
	plan.end_marker = Vector3(11.0, 0.0, -156.0)


# --- SPATIAL ---------------------------------------------------------------------------

static func _spatial(plan: FloorPlan) -> void:
	# LEG A — entry, descent, first fight, then a lane turning east.
	_patch(plan, P_OVERLOOK, Rect2(-44.0, -12.0, 16.0, 10.0), 3.0, &"high")
	_patch(plan, P_DESCENT, Rect2(-40.0, -24.0, 10.0, 12.0), 1.5, &"ramp")
	_patch(plan, P_LANDING, Rect2(-46.0, -48.0, 34.0, 22.0), 0.0, &"stone")
	_patch(plan, P_LANE_A, Rect2(-16.0, -44.0, 30.0, 10.0), 0.0, &"stone")
	_patch(plan, P_FOLD1, Rect2(4.0, -60.0, 12.0, 26.0), 0.0, &"stone")

	# LEG B — running back west: the hazard lane, the integrated chamber, the optional branch.
	_patch(plan, P_SPILLWAY, Rect2(-10.0, -76.0, 28.0, 20.0), 0.0, &"stone")
	_patch(plan, P_GALLERY, Rect2(-48.0, -78.0, 40.0, 26.0), 0.0, &"arena")
	_patch(plan, P_VAULT, Rect2(22.0, -72.0, 14.0, 14.0), 0.0, &"arena")
	_patch(plan, P_FOLD2, Rect2(-46.0, -100.0, 14.0, 26.0), 0.0, &"stone")

	# LEG C — running back east: the alternating doors, the rejoin, the exit.
	_patch(plan, P_PUZZLE_BAY, Rect2(-44.0, -114.0, 30.0, 16.0), 0.0, &"stone")
	_patch(plan, P_PUZZLE_WEST, Rect2(-44.0, -130.0, 14.0, 14.0), 0.0, &"stone")
	_patch(plan, P_PUZZLE_EAST, Rect2(-26.0, -130.0, 14.0, 14.0), 0.0, &"stone")
	_patch(plan, P_JUNCTION, Rect2(-26.0, -146.0, 54.0, 18.0), 0.0, &"stone")
	_patch(plan, P_TERRACE, Rect2(4.0, -162.0, 18.0, 14.0), 1.0, &"high")

	# THE TWO FOLD WALLS. Few and large, per the ruling -- one architectural mass at each turn,
	# with the connector as its only gap. Not wall spam, and not a perimeter: everywhere else the
	# floor keeps its open low-rim edges.
	_obstacle(plan, 0, Rect2(-48.0, -52.0, 50.0, 4.0), _FOLD_WALL_HEIGHT)
	_obstacle(plan, 1, Rect2(-30.0, -86.0, 50.0, 4.0), _FOLD_WALL_HEIGHT)

	# THE GALLERY'S APPROACH MASSES. Ordinary height: these are cover and approach angles, not
	# chapter dividers, and they should not hide the room they shape.
	_obstacle(plan, 2, Rect2(-38.0, -70.0, 5.0, 5.0), 2.4)
	_obstacle(plan, 3, Rect2(-22.0, -62.0, 5.0, 5.0), 2.4)
	# THE SPILLWAY'S SLOW LANE, pushing the safe route wide of the spikes.
	_obstacle(plan, 4, Rect2(-2.0, -70.0, 4.0, 8.0), 2.4)

	# THE SPIKES, out of step so the fast line is a rhythm rather than one gate.
	_spikes(plan, 0, Rect2(4.0, -70.0, 6.0, 6.0), 0)
	_spikes(plan, 1, Rect2(4.0, -62.0, 6.0, 6.0), 25)


static func _patch(plan: FloorPlan, patch_id: int, rect: Rect2, elevation: float, surface: StringName) -> void:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	patch.elevation = elevation
	patch.surface = surface
	patch.boundary_style = &"ledge"
	plan.patches.append(patch)


static func _obstacle(plan: FloorPlan, obstacle_id: int, rect: Rect2, height: float) -> void:
	var obstacle := ObstaclePlan.new()
	obstacle.obstacle_id = obstacle_id
	obstacle.rect = rect
	obstacle.height = height
	plan.obstacles.append(obstacle)


static func _spikes(plan: FloorPlan, pad_id: int, rect: Rect2, offset: int) -> void:
	var pad := SpikePadPlan.new()
	pad.pad_id = pad_id
	pad.rect = rect
	pad.safe_ticks = 55
	pad.active_ticks = 35
	pad.phase_offset_ticks = offset
	pad.damage = 10.0
	pad.damage_type = &"force"
	plan.spike_pads.append(pad)


# --- PROGRESSION -----------------------------------------------------------------------

static func _progression(plan: FloorPlan) -> void:
	_connect(plan, C_DESCEND, P_OVERLOOK, P_DESCENT, Rect2(-37.5, -13.5, 5.0, 3.0), true)
	# THE ONE-WAY COMMITMENT: the floor's real phase transition, and why it needs no party plate.
	_connect(plan, C_COMMIT, P_DESCENT, P_LANDING, Rect2(-37.5, -27.5, 5.0, 6.0), true)
	# THE VAULT DOOR, opened by the concealed switch standing beside it.
	_connect(plan, C_VAULT, P_SPILLWAY, P_VAULT, Rect2(16.5, -67.0, 6.0, 5.0), false)
	# THE ALTERNATING PAIR. West starts OPEN, east CLOSED; the toggle swaps both at once.
	_connect(plan, C_DOOR_WEST, P_PUZZLE_BAY, P_PUZZLE_WEST, Rect2(-39.0, -117.0, 5.0, 6.0), true)
	_connect(plan, C_DOOR_EAST, P_PUZZLE_BAY, P_PUZZLE_EAST, Rect2(-21.0, -117.0, 5.0, 6.0), false)
	_connect(plan, C_TO_TERRACE, P_JUNCTION, P_TERRACE, Rect2(10.0, -151.0, 5.0, 6.0), true, false)

	_trigger(plan, T_COMMIT, FloorLayers.TRIGGER_REGION, Rect2(-40.0, -36.0, 8.0, 8.0), [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_COMMIT),
	], false)
	# STAGED: each leg's fight begins on arrival, at the ENTRANCE band of its space.
	#
	# THE BANDS ARE DEEP ON PURPOSE. A narrow one is a trigger the player can stride over between
	# ticks, and a staging beat that sometimes does not happen is worse than no staging at all.
	_trigger(plan, T_SPILLWAY, FloorLayers.TRIGGER_REGION, Rect2(-8.0, -64.0, 24.0, 11.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_SPILLWAY),
	], false)
	_trigger(plan, T_GALLERY, FloorLayers.TRIGGER_REGION, Rect2(-46.0, -64.0, 34.0, 9.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_GALLERY),
	], false)
	_trigger(plan, T_JUNCTION, FloorLayers.TRIGGER_REGION, Rect2(-24.0, -138.0, 50.0, 9.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_JUNCTION),
	], false)
	# BREAKING THE COVER REVEALS THE SWITCH BEHIND IT. Dropped by accident in the fold rebuild,
	# which left the switch permanently hidden and the Vault permanently shut -- caught by the
	# build checks rather than by a human finding a door that never opened.
	_trigger(plan, T_VAULT_REVEAL, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, Rect2(), [
		FloorLayers.effect(FloorLayers.EFFECT_REVEAL_SWITCH, S_VAULT),
	], false, B_VAULT_COVER)
	_trigger(plan, T_EXIT, FloorLayers.TRIGGER_GROUP_OCCUPANCY, EXIT_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, -1),
	], true)


static func _connect(plan: FloorPlan, connection_id: int, near_id: int, far_id: int, aperture: Rect2, starts_open: bool, has_barrier: bool = true) -> void:
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = aperture
	connection.starts_open = starts_open
	connection.has_barrier = has_barrier
	plan.connections.append(connection)


static func _trigger(plan: FloorPlan, trigger_id: int, kind: StringName, region: Rect2, effects: Array[Dictionary], renders_as_plate: bool, source_id: int = -1) -> void:
	var trigger := FloorTrigger.new()
	trigger.trigger_id = trigger_id
	trigger.kind = kind
	trigger.region = region
	trigger.source_id = source_id
	trigger.effects = effects
	trigger.renders_as_plate = renders_as_plate
	plan.triggers.append(trigger)


# --- WORLD OBJECTS ---------------------------------------------------------------------

static func _world_objects(plan: FloorPlan) -> void:
	# THE VAULT'S CONTROL, beside its own door: concealed, one-shot, obvious cause and effect.
	var vault_switch := HitSwitchPlan.new()
	vault_switch.switch_id = S_VAULT
	vault_switch.position = Vector3(14.0, 0.0, -73.0)
	vault_switch.radius = 0.7
	vault_switch.mode = HitSwitchPlan.MODE_ONE_SHOT
	vault_switch.starts_hidden = true
	vault_switch.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_VAULT)]
	plan.hit_switches.append(vault_switch)

	# THE ALTERNATING TOGGLE, in the bay with BOTH doors in front of it. Its two effects fire
	# together, so the doors swap in one indivisible consequence rather than in sequence.
	var toggle := HitSwitchPlan.new()
	toggle.switch_id = S_ALTERNATE
	toggle.position = Vector3(-30.0, 0.0, -104.0)
	toggle.radius = 0.8
	toggle.mode = HitSwitchPlan.MODE_TOGGLE
	toggle.effects = [
		FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, C_DOOR_WEST),
		FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, C_DOOR_EAST),
	]
	plan.hit_switches.append(toggle)

	# ORDINARY PROPS BREAK IN ONE HIT.
	_breakable(plan, B_VAULT_COVER, Vector3(12.0, 0.0, -73.0), 1.1, 1.0)
	_breakable(plan, B_BAY_PROP, Vector3(-38.0, 0.0, -124.0), 1.0, 1.0)
	# THE GALLERY'S RUBBLE: a route decision, so it authors a real cost. It holds the Watcher's
	# sightline BOTH ways and occupies the lane in front of it -- one act changes fight and route.
	_breakable(plan, B_GALLERY_RUBBLE, Vector3(-30.0, 0.0, -66.0), 2.0, 46.0, Rect2(-33.0, -68.0, 6.0, 4.0))


static func _breakable(plan: FloorPlan, breakable_id: int, position: Vector3, radius: float, durability: float, blocking_rect: Rect2 = Rect2()) -> void:
	var breakable := BreakablePlan.new()
	breakable.breakable_id = breakable_id
	breakable.position = position
	breakable.radius = radius
	breakable.durability = durability
	breakable.blocking_rect = blocking_rect
	plan.breakables.append(breakable)


# --- ENCOUNTERS ------------------------------------------------------------------------

static func _encounters(plan: FloorPlan) -> void:
	_encounter(plan, E_LANDING, P_LANDING, FloorLayers.ROLE_AMBIENT, true, [
		{"enemy_key": &"ooze", "position": Vector3(-22.0, 0.0, -40.0)},
		{"enemy_key": &"fang", "position": Vector3(-36.0, 0.0, -34.0)},
	] as Array[Dictionary])
	# THE INTEGRATED CHAMBER: a Watcher behind rubble that holds the line both ways, Fangs coming
	# round the approach masses, and the player choosing whether to break through or go around.
	_encounter(plan, E_GALLERY, P_GALLERY, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"watcher", "position": Vector3(-30.0, 0.0, -73.0)},
		{"enemy_key": &"fang", "position": Vector3(-44.0, 0.0, -60.0)},
		{"enemy_key": &"fang", "position": Vector3(-16.0, 0.0, -73.0)},
	] as Array[Dictionary])
	_encounter(plan, E_SPILLWAY, P_SPILLWAY, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"fang", "position": Vector3(14.0, 0.0, -60.0)},
	] as Array[Dictionary])
	_encounter(plan, E_JUNCTION, P_JUNCTION, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"ooze", "position": Vector3(4.0, 0.0, -138.0)},
		{"enemy_key": &"fang", "position": Vector3(20.0, 0.0, -138.0)},
	] as Array[Dictionary])


static func _encounter(plan: FloorPlan, encounter_id: int, patch_id: int, role: StringName, at_load: bool, roster: Array[Dictionary]) -> void:
	var site := EncounterSite.new()
	site.encounter_id = encounter_id
	site.regions = [plan.patch_by_id(patch_id).rect]
	site.role = role
	site.confines_player = false
	site.spawn_at_floor_load = at_load
	site.roster = roster
	plan.encounters.append(site)
