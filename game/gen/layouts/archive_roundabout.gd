class_name ArchiveRoundaboutLayout
extends RefCounted
## FLOOR 2 — broad, massed, four turns (rebuilt 2026-09-04 from the approved massing paper).
##
## THE MEASURED FAILURE THIS ANSWERS was sharper than "too much is visible". The previous floor
## had ZERO FORESHADOWED SPACES: everything in view was either SOLVED (enough of it, and its way
## in, to be understood) or oriented. There was no middle register -- no "something is over
## there and I do not yet know how to reach it". Spaces were fully explained or absent.
##
## SO THE TARGET IS NOT CONCEALMENT. It is partial knowledge: solve the local space, orient
## toward the next, occasionally glimpse something beyond it, and learn how it connects only by
## walking there.
##
## THE ARITHMETIC THAT REPLACED THE GIANT WALLS. A mass of height h at distance t hides ground
## out to t/(1 - h/12). Read as a ratio: the SAME modest height covers far more ground standing
## near what it hides than near the viewer. Height 4 at 45 units shadows to 67; the same mass at
## 15 units shadows only to 22. The old height-9 slabs were compensating for PLACEMENT, not for
## physics -- they stood beside the player. Every mass here is height 4 and stands beside the
## thing it conceals, and the measured reveal is better than the slabs achieved.
##
##        x=-58                x=-4              x=+40
##  z=-2   +-OVERLOOK-+
##  -24    +-DESCENT--+          c1 ONE-WAY, sealed behind you
##  -46  +--LANDING---+---WEST HALL---------+          leg 1: south, then EAST
##       +------------+#################  # |          <- court's near wall + L-limb
##  -74                     +---COURT------+--+  +-VAULT-+   leg 2: the broad centre
##                          |                 +--+       |   (Vault branches EAST)
##  -84         ####  ######|##########       |  +-------+   <- south lane's near wall
##  -92                     |   SOUTH LANE----+
##  -78   ######################                         <- the HALL'S OWN near wall
## -100  +----------HALL-----------+                     leg 3: back WEST
## -108   ##############                                 <- puzzle bay's near wall
## -124  +--PUZZLE BAY--+
##       +--[D1]--[D2]--+
## -140  +P WEST+ +P EAST+
## -158       +------JUNCTION---------+                  leg 4: EAST again
## -150        ##########                                <- screens the terrace approach
## -174                    +-TERRACE-+  [] all-party exit
##
## THE COURT IS THE FLOOR'S CENTRE OF GRAVITY: a broad open landmark that branches organise
## around, and the one space that -- measured -- solves nothing at all from inside it.
##
## BEATS KEPT, HOMES CHANGED. Every successful beat carried forward, and every one re-checked in
## its new approach direction rather than transplanted. The integrated chamber now faces an
## approach from the EAST, so its rubble and its Watcher are oriented for that and not for the
## north-facing composition they were authored in.

# Patch ids
const P_OVERLOOK := 0
const P_DESCENT := 1
const P_LANDING := 2
const P_WEST_HALL := 3
const P_COURT := 4
const P_VAULT := 5
const P_SOUTH_LANE := 6
const P_HALL := 7
const P_PUZZLE_BAY := 8
const P_PUZZLE_WEST := 9
const P_PUZZLE_EAST := 10
const P_JUNCTION := 11
const P_TERRACE := 12

# Connection ids
const C_DESCEND := 0
const C_COMMIT := 1
const C_TO_COURT := 2
const C_VAULT := 3
const C_TO_LANE := 4
const C_TO_HALL := 5
const C_TO_BAY := 6
const C_DOOR_WEST := 7
const C_DOOR_EAST := 8
const C_TO_JUNCTION := 9
const C_TO_TERRACE := 10

# Encounter ids
const E_LANDING := 0
const E_COURT := 1
const E_HALL := 2
const E_JUNCTION := 3

# Trigger ids
const T_COMMIT := 0
const T_COURT := 1
const T_HALL := 2
const T_JUNCTION := 3
const T_VAULT_REVEAL := 4
const T_EXIT := 5

# World object ids
const S_VAULT := 0        # concealed one-shot, beside the Vault door
const S_ALTERNATE := 1    # the toggle, in the puzzle bay
const B_VAULT_COVER := 0
const B_HALL_RUBBLE := 1
const B_BAY_PROP := 2

const EXIT_PLATE := Rect2(14.0, -170.0, 4.0, 4.0)

## EVERY MASS IS THIS TALL. Not a law -- an authored choice for this floor, and the thing the
## human replay is asked to judge. What IS durable is where they stand: beside what they hide.
const _MASS_HEIGHT: float = 4.0


static func build(plan: FloorPlan) -> void:
	_spatial(plan)
	_progression(plan)
	_world_objects(plan)
	_encounters(plan)
	plan.entry_point = Vector3(-48.0, 0.0, -7.0)
	plan.end_marker = Vector3(16.0, 0.0, -168.0)


# --- SPATIAL ---------------------------------------------------------------------------

static func _spatial(plan: FloorPlan) -> void:
	# LEG 1 — down the west side, then EAST.
	_patch(plan, P_OVERLOOK, Rect2(-56.0, -12.0, 16.0, 10.0), 3.0, &"high")
	_patch(plan, P_DESCENT, Rect2(-52.0, -24.0, 10.0, 12.0), 1.5, &"ramp")
	_patch(plan, P_LANDING, Rect2(-58.0, -46.0, 28.0, 20.0), 0.0, &"stone")
	_patch(plan, P_WEST_HALL, Rect2(-34.0, -42.0, 32.0, 10.0), 0.0, &"stone")

	# LEG 2 — the Court: the floor's centre of gravity, with the Vault branching EAST off it.
	_patch(plan, P_COURT, Rect2(-4.0, -74.0, 40.0, 30.0), 0.0, &"arena")
	_patch(plan, P_VAULT, Rect2(40.0, -66.0, 14.0, 14.0), 0.0, &"arena")

	# LEG 3 — south, then back WEST through the hazard lane into the integrated chamber.
	_patch(plan, P_SOUTH_LANE, Rect2(0.0, -92.0, 30.0, 10.0), 0.0, &"stone")
	_patch(plan, P_HALL, Rect2(-52.0, -100.0, 50.0, 22.0), 0.0, &"arena")

	# LEG 4 — the alternating doors, the rejoin, and EAST again to the exit.
	_patch(plan, P_PUZZLE_BAY, Rect2(-50.0, -124.0, 28.0, 16.0), 0.0, &"stone")
	_patch(plan, P_PUZZLE_WEST, Rect2(-50.0, -140.0, 12.0, 12.0), 0.0, &"stone")
	_patch(plan, P_PUZZLE_EAST, Rect2(-34.0, -140.0, 12.0, 12.0), 0.0, &"stone")
	_patch(plan, P_JUNCTION, Rect2(-30.0, -158.0, 58.0, 16.0), 0.0, &"stone")
	_patch(plan, P_TERRACE, Rect2(8.0, -174.0, 18.0, 14.0), 1.0, &"high")

	# --- THE MASSES. Each stands beside what it hides, which is the whole method. ---
	#
	# THEIR FACES ARE KEPT OFF PATCH EDGES, and the apertures likewise. A mass face flush with a
	# patch's own edge makes the two disagree about one span -- a wall and a ledge claiming the
	# same line -- and FloorPlan refuses the conflict rather than picking a winner. Every offset
	# below that looks arbitrary is avoiding exactly that.
	# The Court's near wall, and an L-limb turning it north so the Court's mouth is round a
	# corner rather than straight down the view from the Landing.
	_mass(plan, 0, Rect2(-29.0, -58.0, 26.0, 6.0))
	# The limb sits EAST of the mouth, screening it from the Court's interior rather than
	# standing in front of it -- the first placement blocked the very doorway it was meant to
	# hide, which the floor walk caught immediately.
	_mass(plan, 1, Rect2(2.0, -53.0, 6.0, 10.0))
	# The south lane's near wall -- in TWO limbs, with the lane's own mouth between them. The
	# first version was one 26-wide slab that covered the aperture it was meant to stand beside,
	# so the way in was walled up by the wall whose job was to hide it.
	_mass(plan, 2, Rect2(6.0, -84.0, 11.0, 6.0))
	_mass(plan, 9, Rect2(25.0, -84.0, 7.0, 6.0))
	_mass(plan, 3, Rect2(-14.0, -84.0, 8.0, 14.0))
	# THE HALL'S OWN NEAR WALL. Added during paper measurement, when the Hall read 80% from the
	# Landing -- whole-room comprehension of a late space. The fix was not a taller mass earlier
	# but this one, standing 50 units from that viewpoint instead of 25. A space participates in
	# controlling its own reveal.
	_mass(plan, 4, Rect2(-58.0, -77.0, 50.0, 6.0))
	_mass(plan, 5, Rect2(-34.0, -107.0, 26.0, 6.0))
	_mass(plan, 6, Rect2(-2.0, -150.0, 24.0, 6.0))

	# COMBAT MASSING in the Hall, shaping an approach that now comes from the EAST.
	_mass(plan, 7, Rect2(-20.0, -98.0, 5.0, 5.0))
	_mass(plan, 8, Rect2(-34.0, -86.0, 5.0, 5.0))

	# THE HAZARD LANE, crossed heading WEST along the south lane. Cadence is set from a measured
	# crossing, not from feel (tools/measure_spike_crossing.gd), and the pads share a phase
	# because they form ONE unbroken lane with no safe ground to stop on.
	_spikes(plan, 0, Rect2(10.0, -92.0, 6.0, 10.0))
	_spikes(plan, 1, Rect2(16.0, -92.0, 6.0, 10.0))


static func _patch(plan: FloorPlan, patch_id: int, rect: Rect2, elevation: float, surface: StringName) -> void:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	patch.elevation = elevation
	patch.surface = surface
	# LOW-RIM EDGES EVERYWHERE. Solidity comes from authored masses, never from closing rooms in.
	patch.boundary_style = &"ledge"
	plan.patches.append(patch)


static func _mass(plan: FloorPlan, obstacle_id: int, rect: Rect2) -> void:
	var obstacle := ObstaclePlan.new()
	obstacle.obstacle_id = obstacle_id
	obstacle.rect = rect
	obstacle.height = _MASS_HEIGHT
	plan.obstacles.append(obstacle)


static func _spikes(plan: FloorPlan, pad_id: int, rect: Rect2) -> void:
	var pad := SpikePadPlan.new()
	pad.pad_id = pad_id
	pad.rect = rect
	# RE-DERIVED FOR THIS LANE, not inherited. The previous lane measured 114 ticks and took 143;
	# this one is shorter and crossed east-to-west, and measures 99 (tools/measure_spike_crossing).
	# 124 is that plus 25% grace. Carrying 143 across would have been a number that once meant
	# something, which is how a derived value quietly becomes a magic one.
	pad.safe_ticks = 124
	pad.active_ticks = 35
	pad.phase_offset_ticks = 0
	pad.damage = 10.0
	pad.damage_type = &"force"
	plan.spike_pads.append(pad)


# --- PROGRESSION -----------------------------------------------------------------------

static func _progression(plan: FloorPlan) -> void:
	_connect(plan, C_DESCEND, P_OVERLOOK, P_DESCENT, Rect2(-49.5, -13.5, 5.0, 3.0), true)
	# THE ONE-WAY COMMITMENT: this floor's real phase transition, and why it needs no party plate.
	_connect(plan, C_COMMIT, P_DESCENT, P_LANDING, Rect2(-49.5, -27.5, 5.0, 6.0), true)
	# WIDE ENOUGH TO ACTUALLY OVERLAP THE COURT. An earlier version was nudged west to dodge a
	# boundary-style conflict and ended up overlapping the Court by half a unit -- a doorway that
	# validated cleanly and that no body could pass through.
	_connect(plan, C_TO_COURT, P_WEST_HALL, P_COURT, Rect2(-9.0, -46.0, 8.0, 8.0), true)
	# THE VAULT DOOR, opened by the concealed switch standing beside it.
	_connect(plan, C_VAULT, P_COURT, P_VAULT, Rect2(34.5, -62.0, 7.0, 6.0), false)
	_connect(plan, C_TO_LANE, P_COURT, P_SOUTH_LANE, Rect2(18.0, -84.0, 6.0, 12.0), true)
	_connect(plan, C_TO_HALL, P_SOUTH_LANE, P_HALL, Rect2(-5.0, -90.0, 10.0, 6.0), true)
	_connect(plan, C_TO_BAY, P_HALL, P_PUZZLE_BAY, Rect2(-42.0, -110.0, 6.0, 12.0), true)
	# THE ALTERNATING PAIR: west starts OPEN, east CLOSED; the toggle swaps both at once.
	_connect(plan, C_DOOR_WEST, P_PUZZLE_BAY, P_PUZZLE_WEST, Rect2(-46.0, -129.0, 5.0, 6.0), true)
	_connect(plan, C_DOOR_EAST, P_PUZZLE_BAY, P_PUZZLE_EAST, Rect2(-31.0, -129.0, 5.0, 6.0), false)
	_connect(plan, C_TO_JUNCTION, P_PUZZLE_EAST, P_JUNCTION, Rect2(-29.5, -144.0, 6.0, 8.0), true)
	_connect(plan, C_TO_TERRACE, P_JUNCTION, P_TERRACE, Rect2(14.0, -162.0, 5.0, 6.0), true, false)

	_trigger(plan, T_COMMIT, FloorLayers.TRIGGER_REGION, Rect2(-52.0, -36.0, 10.0, 8.0), [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_COMMIT),
	], false)
	# STAGED FIGHTS, banded at the ENTRANCE each space is actually approached from -- and the
	# approach directions changed with the rebuild, so these are re-placed rather than carried.
	# The Court is entered from the NORTH-WEST; the Hall from the EAST; the Junction from the WEST.
	_trigger(plan, T_COURT, FloorLayers.TRIGGER_REGION, Rect2(-4.0, -54.0, 20.0, 10.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_COURT),
	], false)
	_trigger(plan, T_HALL, FloorLayers.TRIGGER_REGION, Rect2(-12.0, -96.0, 10.0, 16.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_HALL),
	], false)
	_trigger(plan, T_JUNCTION, FloorLayers.TRIGGER_REGION, Rect2(-28.0, -152.0, 14.0, 10.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_JUNCTION),
	], false)
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
	# THE VAULT'S CONTROL, beside its own door on the Court's east side: concealed, one-shot,
	# obvious cause and effect. Not the toggle -- the Vault's unresolved problem is destination
	# reward, never switch complexity.
	var vault_switch := HitSwitchPlan.new()
	vault_switch.switch_id = S_VAULT
	vault_switch.position = Vector3(32.0, 0.0, -66.0)
	vault_switch.radius = 0.7
	vault_switch.mode = HitSwitchPlan.MODE_ONE_SHOT
	vault_switch.starts_hidden = true
	vault_switch.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_VAULT)]
	plan.hit_switches.append(vault_switch)

	# THE ALTERNATING TOGGLE, in the bay with BOTH doors in front of it. Its effects fire
	# together, so the doors swap in one indivisible consequence.
	var toggle := HitSwitchPlan.new()
	toggle.switch_id = S_ALTERNATE
	toggle.position = Vector3(-38.0, 0.0, -114.0)
	toggle.radius = 0.8
	toggle.mode = HitSwitchPlan.MODE_TOGGLE
	toggle.effects = [
		FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, C_DOOR_WEST),
		FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, C_DOOR_EAST),
	]
	plan.hit_switches.append(toggle)

	# EVERY PROP BREAKS IN ONE HIT. Challenge is positioning and consequence, never hit points.
	_breakable(plan, B_VAULT_COVER, Vector3(30.0, 0.0, -66.0), 1.1)
	_breakable(plan, B_BAY_PROP, Vector3(-46.0, 0.0, -118.0), 1.0)
	# THE HALL'S RUBBLE, now placed for an approach from the EAST: it stands between the doorway
	# and the Watcher, holding that sightline both ways.
	_breakable(plan, B_HALL_RUBBLE, Vector3(-24.0, 0.0, -89.0), 2.0, Rect2(-27.0, -91.0, 6.0, 4.0))


static func _breakable(plan: FloorPlan, breakable_id: int, position: Vector3, radius: float, blocking_rect: Rect2 = Rect2()) -> void:
	var breakable := BreakablePlan.new()
	breakable.breakable_id = breakable_id
	breakable.position = position
	breakable.radius = radius
	breakable.durability = 1.0
	breakable.blocking_rect = blocking_rect
	plan.breakables.append(breakable)


# --- ENCOUNTERS ------------------------------------------------------------------------

static func _encounters(plan: FloorPlan) -> void:
	_encounter(plan, E_LANDING, P_LANDING, FloorLayers.ROLE_AMBIENT, true, [
		{"enemy_key": &"ooze", "position": Vector3(-38.0, 0.0, -38.0)},
		{"enemy_key": &"fang", "position": Vector3(-50.0, 0.0, -32.0)},
	] as Array[Dictionary])
	# THE COURT: open ground, so the fight here is about space rather than cover.
	_encounter(plan, E_COURT, P_COURT, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"fang", "position": Vector3(10.0, 0.0, -64.0)},
		{"enemy_key": &"ooze", "position": Vector3(24.0, 0.0, -56.0)},
	] as Array[Dictionary])
	# THE INTEGRATED CHAMBER, re-oriented for an EAST approach: the Watcher stands deep west with
	# the rubble between it and the doorway, so the threat is visible and not yet actionable, and
	# the Fangs come round the masses while the player chooses to break through or go around.
	_encounter(plan, E_HALL, P_HALL, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"watcher", "position": Vector3(-42.0, 0.0, -89.0)},
		{"enemy_key": &"fang", "position": Vector3(-25.0, 0.0, -83.0)},
		{"enemy_key": &"fang", "position": Vector3(-30.0, 0.0, -96.0)},
	] as Array[Dictionary])
	_encounter(plan, E_JUNCTION, P_JUNCTION, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"ooze", "position": Vector3(-4.0, 0.0, -153.0)},
		{"enemy_key": &"fang", "position": Vector3(16.0, 0.0, -153.0)},
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
