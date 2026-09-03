class_name ArchiveRoundaboutLayout
extends RefCounted
## FLOOR 2 — the second authored floor, at production scale (rebuilt 2026-09-03).
##
## THE DIAGNOSIS THIS ANSWERS was never dimensions. The previous version's whole argument was
## visible from the entry: the Overlook showed the Concourse, which showed the fork and the
## Junction, which showed the exit. One idea, legible in about eight seconds, and everything
## afterwards was executing it. So this adds A MIDDLE THE ENTRY CANNOT SEE rather than metres.
##
##   z=-2   +----------+
##          | OVERLOOK | e3   sees the Landing and NOTHING past it
##  -10     +----++----+
##               || c0
##  -18     +----++----+
##          | DESCENT  | e1.5
##  -20     +----++----+  c1 -- ONE-WAY: sealed behind you
##  -34 +--------++---------+
##      |    THE LANDING    |  first combat pocket, shaped by obstacles
##      +--++------------++-+
##      c2 ||            || c3
##  -54 +--++-------+ +--++-----------+
##      |  THICKET  | |   SPILLWAY    |   west: search    east: timed spikes
##  -38 +-----++----+ +------++-------+
##        c4 ||              || c5
##  -72 +----++--------------++--------+
##      |        THE GALLERY           |  THE INTEGRATED CHAMBER
##  -58 +------++----------++----------+
##    c6 GATED ||          || c7 open
##  -88 +------++-+       ++-------+ c8 +--------+
##      | ROUTE A  |      | ROUTE B +----+ VAULT |  gated by the Thicket switch
##  -74 +----+-----+      +----+----+    +-------+
##  -97 +----+----------------+------------------+
##      |              THE JUNCTION              |  a later fight, unseen from entry
##  -87 +--------------++------------------------+
##                     || c9  always open
## -111 +--------------++-+
##      |     TERRACE     | e1   [] all-party exit
##      +-----------------+
##
## THE THICKET AND THE SPILLWAY HIDE EACH OTHER. Both reach the Gallery, so neither is a detour
## anyone regrets -- and taking one means not seeing the other, which is replay value from
## geometry rather than from content.
##
## THE GALLERY IS THE ONE COMPOSITION THE RULING REQUIRED BE PROVEN: a Watcher behind blocking
## rubble that holds the sightline BOTH ways, obstacles shaping two approach lanes, and a spike
## lane across the shorter one. Breaking the rubble changes the fight AND opens a lane -- one
## act, both consequences. Threat-visible-before-actionable is the combat form of the
## visible-before-reachable principle the first version proved.
##
## TWO DISTINCT FLOOR VERBS, deliberately not homogenised: Route A is bought by STANDING on a
## plate in the Gallery; the Vault is opened by FINDING a concealed switch in the Thicket and
## SHOOTING it. Presence versus perception -- the spatial meanings differ, so the verbs do.
##
## NO PARTY BUTTON. One is permitted only for a genuine mid-floor phase transition, and the
## honest transition here is the one-way commitment, which needs no gathering. Adding a plate
## anyway would repeat exactly the redundancy the previous iteration removed.
##
## NO SPECIAL BLOCKS. Nothing here consumes a chain-clear, an explosive or a respawning block,
## and placing one to demonstrate an API is what the fences forbid. The Gallery's rubble is the
## concrete consumer that would JUSTIFY chain-clear later, if a floor ever wants a formation.
##
## THE VAULT'S DESTINATION IS STILL EMPTY. Access is now genuinely interesting; arriving is not.
## That remains blocked on reward vocabulary, and no enemies are placed there to disguise it.

# Patch ids
const P_OVERLOOK := 0
const P_DESCENT := 1
const P_LANDING := 2
const P_THICKET := 3
const P_SPILLWAY := 4
const P_GALLERY := 5
const P_ROUTE_A := 6
const P_ROUTE_B := 7
const P_VAULT := 8
const P_JUNCTION := 9
const P_TERRACE := 10

# Connection ids
const C_DESCEND := 0
const C_COMMIT := 1
const C_TO_THICKET := 2
const C_TO_SPILLWAY := 3
const C_THICKET_ON := 4
const C_SPILLWAY_ON := 5
const C_TO_A := 6
const C_TO_B := 7
const C_VAULT := 8
const C_TO_TERRACE := 9

# Encounter ids
const E_LANDING := 0
const E_GALLERY := 1
const E_ROUTE_A_RESPONSE := 2
const E_JUNCTION := 3

# Trigger ids
const T_COMMIT := 0
const T_GALLERY := 1
const T_CONTROL := 2
const T_VAULT_SWITCH := 3
const T_JUNCTION := 4
const T_EXIT := 5

# World object ids
const S_VAULT := 0            # the concealed hit-switch
const B_COVER := 0            # the vegetation hiding it
const B_THICKET_RUBBLE := 1   # partly blocks the way on
const B_GALLERY_RUBBLE := 2   # holds the Watcher's sightline, and a lane

## PLATE SIZE SIGNALS SEMANTIC WEIGHT: small for a local action, large for floor transition.
##
## MOVED CLEAR OF THE GALLERY'S WEST OBSTACLE (2026-09-04). It previously sat at (-13,-65),
## overlapping the column at x[-14,-10] z[-68,-64] -- so the plate poked out from under permanent
## geometry. The human read that exactly as it was: an accident, not concealment. Clipping is not
## discovery language; a control is either plainly visible or hidden behind something removable.
const CONTROL_PLATE := Rect2(-20.0, -62.0, 2.0, 2.0)
const EXIT_PLATE := Rect2(-22.0, -108.0, 4.0, 4.0)


static func build(plan: FloorPlan) -> void:
	_spatial(plan)
	_progression(plan)
	_world_objects(plan)
	_encounters(plan)
	plan.entry_point = Vector3(0.0, 0.0, -6.0)
	plan.end_marker = Vector3(-20.0, 0.0, -106.0)


# --- SPATIAL ---------------------------------------------------------------------------

static func _spatial(plan: FloorPlan) -> void:
	_patch(plan, P_OVERLOOK, Rect2(-8.0, -10.0, 16.0, 8.0), 3.0, &"high")
	_patch(plan, P_DESCENT, Rect2(-4.0, -18.0, 8.0, 8.0), 1.5, &"ramp")
	_patch(plan, P_LANDING, Rect2(-14.0, -34.0, 28.0, 14.0), 0.0, &"stone")
	_patch(plan, P_THICKET, Rect2(-32.0, -54.0, 24.0, 16.0), 0.0, &"stone")
	_patch(plan, P_SPILLWAY, Rect2(8.0, -54.0, 24.0, 16.0), 0.0, &"stone")
	_patch(plan, P_GALLERY, Rect2(-26.0, -72.0, 52.0, 14.0), 0.0, &"arena")
	_patch(plan, P_ROUTE_A, Rect2(-16.0, -88.0, 12.0, 14.0), 0.0, &"stone")
	_patch(plan, P_ROUTE_B, Rect2(4.0, -88.0, 12.0, 14.0), 0.0, &"stone")
	_patch(plan, P_VAULT, Rect2(18.0, -86.0, 12.0, 12.0), 0.0, &"arena")
	_patch(plan, P_JUNCTION, Rect2(-30.0, -97.0, 60.0, 10.0), 0.0, &"stone")
	_patch(plan, P_TERRACE, Rect2(-28.0, -111.0, 16.0, 12.0), 1.0, &"high")

	# THE LANDING'S OBSTACLES. Widely spaced on purpose: these make approach ANGLES and broken
	# sightlines, never a slalom. Every lane between them is measured against the widest authored
	# body before this ships, which is the mechanical half of "no AI slalom".
	_obstacle(plan, 0, Rect2(-9.0, -31.0, 3.0, 3.0))
	_obstacle(plan, 1, Rect2(3.0, -27.0, 3.0, 3.0))

	# THE SPILLWAY'S SLOW LANE. The obstacles push the safe route wide, so the spikes below are a
	# question of pace rather than a wall: the fast line is the timed line.
	_obstacle(plan, 2, Rect2(17.0, -50.0, 3.0, 5.0))
	_obstacle(plan, 3, Rect2(25.0, -46.0, 3.0, 5.0))

	# THE GALLERY'S TWO APPROACHES. Closing on what stands behind the rubble is a choice of side.
	_obstacle(plan, 4, Rect2(-14.0, -68.0, 4.0, 4.0))
	_obstacle(plan, 5, Rect2(10.0, -68.0, 4.0, 4.0))

	# THE SPILLWAY'S SPIKES, out of step with each other so the fast line is a rhythm rather than
	# a single gate. OFFSETS, not separate clocks -- phase is a pure function of the tick.
	_spikes(plan, 0, Rect2(9.0, -51.0, 5.0, 5.0), 0)
	_spikes(plan, 1, Rect2(9.0, -45.0, 5.0, 5.0), 25)
	# AND ONE IN THE GALLERY, across the shorter approach to the rubble.
	_spikes(plan, 2, Rect2(-4.0, -67.0, 8.0, 4.0), 12)


static func _patch(plan: FloorPlan, patch_id: int, rect: Rect2, elevation: float, surface: StringName) -> void:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	patch.elevation = elevation
	patch.surface = surface
	# EVERY EDGE IS A LEDGE. The open-edge lip now makes an authored drop read as intentional, so
	# the floor needs no walls to look finished -- and walls belong only where they earn it.
	patch.boundary_style = &"ledge"
	plan.patches.append(patch)


static func _obstacle(plan: FloorPlan, obstacle_id: int, rect: Rect2) -> void:
	var obstacle := ObstaclePlan.new()
	obstacle.obstacle_id = obstacle_id
	obstacle.rect = rect
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
	_connect(plan, C_DESCEND, P_OVERLOOK, P_DESCENT, Rect2(-2.5, -11.5, 5.0, 3.0), true)
	# THE ONE-WAY COMMITMENT. Open on arrival, sealed the moment the player is past it -- the
	# floor's real phase transition, and the reason it needs no party plate to mark one.
	_connect(plan, C_COMMIT, P_DESCENT, P_LANDING, Rect2(-2.5, -21.0, 5.0, 6.0), true)
	# NOT flush with the Thicket's east edge at x=-8: an aperture flank landing exactly on a patch
	# edge makes the two disagree about that span -- aperture sides are walls, patch sides here are
	# ledges -- and FloorPlan refuses the conflict rather than picking a winner.
	_connect(plan, C_TO_THICKET, P_LANDING, P_THICKET, Rect2(-12.5, -39.0, 5.0, 7.0), true)
	_connect(plan, C_TO_SPILLWAY, P_LANDING, P_SPILLWAY, Rect2(8.5, -39.0, 5.0, 7.0), true)
	_connect(plan, C_THICKET_ON, P_THICKET, P_GALLERY, Rect2(-22.0, -59.0, 5.0, 7.0), true)
	_connect(plan, C_SPILLWAY_ON, P_SPILLWAY, P_GALLERY, Rect2(16.0, -59.0, 5.0, 7.0), true)
	# THE FORK. A is bought by standing on the Gallery's control; B is simply open.
	_connect(plan, C_TO_A, P_GALLERY, P_ROUTE_A, Rect2(-12.5, -75.0, 5.0, 6.0), false)
	_connect(plan, C_TO_B, P_GALLERY, P_ROUTE_B, Rect2(7.5, -75.0, 5.0, 6.0), true)
	# THE VAULT DOOR. Opened only by the concealed switch two spaces back, so the branch is
	# genuinely controlled: there is no other way in.
	_connect(plan, C_VAULT, P_ROUTE_B, P_VAULT, Rect2(14.5, -82.0, 5.0, 5.0), false)
	_connect(plan, C_TO_TERRACE, P_JUNCTION, P_TERRACE, Rect2(-22.5, -100.0, 5.0, 5.0), true, false)

	# ONE-WAY, authored as an ordinary region trigger blocking an ordinary connection -- no
	# directional predicate anywhere, exactly as TraversalConnection's own note requires.
	_trigger(plan, T_COMMIT, FloorLayers.TRIGGER_REGION, Rect2(-2.0, -28.0, 4.0, 4.0), [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_COMMIT),
	], false)
	# STAGED ACTIVATION: the Gallery's fight begins when the player is in the Gallery, from
	# whichever branch they took.
	# ON THE ENTRANCE BAND, not the far end: both branches arrive at the Gallery's NORTH edge, so
	# a region at its southern end would only fire once the fight was already behind the player.
	_trigger(plan, T_GALLERY, FloorLayers.TRIGGER_REGION, Rect2(-24.0, -63.0, 48.0, 5.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_GALLERY),
	], false)
	# THE SHORTCUT'S CONTROL. Standing, not shooting: presence is its meaning.
	_trigger(plan, T_CONTROL, FloorLayers.TRIGGER_REGION, CONTROL_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_TO_A),
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_ROUTE_A_RESPONSE),
	], true)
	# BREAKING THE COVER REVEALS THE SWITCH. The switch was always there; the vegetation was in
	# front of it. That is the only thing REVEAL means.
	_trigger(plan, T_VAULT_SWITCH, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, Rect2(), [
		FloorLayers.effect(FloorLayers.EFFECT_REVEAL_SWITCH, S_VAULT),
	], false, B_COVER)
	_trigger(plan, T_JUNCTION, FloorLayers.TRIGGER_REGION, Rect2(-28.0, -91.0, 56.0, 4.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_JUNCTION),
	], false)
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
	# THE CONCEALED SWITCH, and the vegetation in front of it. Hidden means NOT DRAWN AND NOT
	# HITTABLE: concealment is physical here, never a flag consulted after the fact.
	# BESIDE THE DOOR IT OPENS (2026-09-04). It used to stand in the Thicket, two spaces and a
	# whole chamber away from the Vault -- so hitting it changed something the player could not
	# see, and the causal link had to be inferred rather than read. We have no vocabulary for
	# remote causality, and inventing one to rescue a placement is exactly backwards.
	#
	# It remains a ONE-SHOT switch, not a reversible one. Correcting the record: the toggle was
	# never wired to the Vault; what was wrong was the DISTANCE, and that is now fixed.
	var vault_switch := HitSwitchPlan.new()
	vault_switch.switch_id = S_VAULT
	vault_switch.position = Vector3(13.5, 0.0, -80.0)
	vault_switch.radius = 0.7
	vault_switch.mode = HitSwitchPlan.MODE_ONE_SHOT
	vault_switch.starts_hidden = true
	vault_switch.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_VAULT)]
	plan.hit_switches.append(vault_switch)

	# THE COVER SITS WITH THE SWITCH, beside the door they open. An ordinary prop, so ONE HIT.
	_breakable(plan, B_COVER, Vector3(11.0, 0.0, -80.0), 1.1, 1.0)
	# THE THICKET'S BLOCKER, and now its ONLY prop. It occupies ground until broken, so the direct
	# line west is a choice between clearing it and walking around -- which is the whole of its
	# job, and is why it no longer shares a room with a concealment prop that meant something
	# entirely different. Two boxes with unrelated purposes in one space read as neither.
	#
	# Authored durability, deliberately above the one-hit baseline: this one is a route decision
	# rather than scenery, and it should cost something to remove.
	_breakable(plan, B_THICKET_RUBBLE, Vector3(-18.0, 0.0, -44.0), 1.6, 30.0, Rect2(-20.0, -46.0, 4.0, 4.0))
	# THE GALLERY'S RUBBLE, which is the whole integrated beat: it holds the Watcher's sightline
	# BOTH ways and occupies the lane in front of it. One act changes the fight and the route.
	_breakable(plan, B_GALLERY_RUBBLE, Vector3(0.0, 0.0, -61.5), 2.0, 46.0, Rect2(-3.0, -63.0, 6.0, 3.0))


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
	# THE LANDING: the first fight, among the obstacles rather than beside them.
	_encounter(plan, E_LANDING, P_LANDING, FloorLayers.ROLE_AMBIENT, true, [
		{"enemy_key": &"ooze", "position": Vector3(7.0, 0.0, -31.0)},
		{"enemy_key": &"fang", "position": Vector3(-7.0, 0.0, -25.0)},
	])
	# THE GALLERY: the integrated chamber. The WATCHER stands behind the rubble -- visible,
	# understood, and not yet actionable, because that rubble holds the line both ways. The Fangs
	# come round the obstacles while the player decides whether to break through or go around.
	_encounter(plan, E_GALLERY, P_GALLERY, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"watcher", "position": Vector3(0.0, 0.0, -69.0)},
		{"enemy_key": &"fang", "position": Vector3(-20.0, 0.0, -62.0)},
		{"enemy_key": &"fang", "position": Vector3(20.0, 0.0, -62.0)},
	])
	# THE PRICE OF THE SHORTCUT, standing in the shortcut. Non-sealing: open Route A, look at
	# what is in it, and take the long way instead if that is the better trade.
	_encounter(plan, E_ROUTE_A_RESPONSE, P_ROUTE_A, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"watcher", "position": Vector3(-10.0, 0.0, -81.0)},
	])
	# THE JUNCTION: a later fight, in a space the entry never showed.
	_encounter(plan, E_JUNCTION, P_JUNCTION, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"ooze", "position": Vector3(-8.0, 0.0, -92.0)},
		{"enemy_key": &"fang", "position": Vector3(10.0, 0.0, -92.0)},
	])


static func _encounter(plan: FloorPlan, encounter_id: int, patch_id: int, role: StringName, at_load: bool, roster: Array[Dictionary]) -> void:
	var site := EncounterSite.new()
	site.encounter_id = encounter_id
	# ONE RECT PER HOME, so P33's convexity constraint holds by construction rather than by
	# inspection -- and so a disengaged actor's walk home is a straight line to somewhere real.
	site.regions = [plan.patch_by_id(patch_id).rect]
	site.role = role
	site.confines_player = false
	site.spawn_at_floor_load = at_load
	site.roster = roster
	plan.encounters.append(site)
