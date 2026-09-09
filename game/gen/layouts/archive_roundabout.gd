class_name ArchiveRoundaboutLayout
extends RefCounted
## FLOOR 2 — explore, decide, commit, fight, cross, arrive.
## (Rebuilt 2026-09-08 from the approved route-choice expansion.)
##
## THE CORRECTION THIS FLOOR IS BUILT ON. Earlier versions tried to create mystery by standing
## large masses in front of things. That failed twice in play, and the diagnosis was not "the
## walls are wrong" but "the floor is too short to hide itself". A floor long enough to have
## several substantial sections can show you its neighbours freely and still keep its ending
## unresolved, because the ending is genuinely far away rather than merely occluded.
##
##     LENGTH AND BRANCHING ARE THE REVEAL TOOL. Screening masses were the wrong instrument.
##
## AND THE DECISION IS THE GALLERY (moved there 2026-09-09, from a human screenshot of the exact
## standing point). The whole westward sequence -- lane, chamber, pocket, puzzle rooms, cache --
## is OPTIONAL, and the critical path strikes EAST across new ground instead. An earlier pass got
## this wrong by hanging a NEW optional limb beside the old mainline rather than reclassifying the
## mainline itself; a later one put the fork in the Court, one room too early.
##
## SO THE SHAPE IS NO LONGER A FOLDED RIBBON. It is a spine with a fork at its centre:
##
##      x=-58    -30     -4      +48   +80   +112  +136      +188    +214
##  z=-2  +-OVERLOOK-+
##  -24   +-DESCENT--+           c1 ONE-WAY, sealed behind you
##  -46 +--LANDING---+--WEST HALL-+
##  -74                   +--------COURT--------+    +-VAULT-+  (optional, north-east)
##                                   | one hall, straight north
##                          spikes + Watchers        the critical east
##  -110   optional west <== SPIKE HALL ==+== T ==+================>
##                                              ** THE FORK **
##  -84                                            +-GALLERY-+
##  -96     +---------- SOUTH LANE ----------+     left: down   right: east
##          (spikes, crossed WEST)                     |             |
## -100 +------ THE HALL ------+    |                       +-WORKS-+     fight + control
##        |                |        |                           +-APPROACH-+   breathe
## (opt)  +-POCKET         |        |                                 |
## (opt)  +-PUZZLE BAY     |        |                +------- THE ARENA -------+
## (opt)  +-[D1]--[D2]     |        |                | [plate] at dead centre  |
## (opt)  +-P WEST P EAST -> CACHE -> RETURN RUN     | four spike arms, a cross|
##                            |________^             +-------------------------+
##                         the loop closes                       |
##                                                   +-REWARD HALL, and its exit-+
##
##   CRITICAL   Landing · West Hall · Court · THE JUNCTION (the fork) · the Sweep · Works ·
##              the Turn · ARENA · Reward Hall (which carries the exit)
##   OPTIONAL   Vault (east, off the Court)
##              THE WHOLE WEST (South Lane · Hall · Pocket · Puzzle Bay · doors · Cache), which
##              returns to the Hall by its own far-side door and to the Court by the lane.
##
## BOTH WAYS OUT OF THE FORK ARE OPEN. Nothing is locked there, because the choosing is the
## beat -- lock half of it and it stops being a decision and becomes an errand. The floor's one
## irreversible moment is the party plate at the CENTRE OF THE ARENA: step into the middle of the
## climax room together and the exploration phase closes behind you as the first wave wakes.
##
## THE FLOOR IS NOW WELL OVER TWICE AS WIDE AS IT IS DEEP, roughly 322 x 138 -- against 126 x 186
## four passes ago. That inversion is the point rather than a side effect: the mystery comes from a
## floor with somewhere further to go, and six screening masses have been deleted across four
## passes to pay for it. Nothing here is hidden by standing something in front of it.

# Patch ids
const P_OVERLOOK := 0
const P_DESCENT := 1
const P_LANDING := 2
const P_WEST_HALL := 3
const P_COURT := 4
const P_VAULT := 5
const P_SPIKE_HALL := 6
const P_HALL := 7
const P_PUZZLE_BAY := 8
const P_PUZZLE_WEST := 9
const P_PUZZLE_EAST := 10
const P_POCKET := 11
const P_CACHE := 12
const P_RETURN_RUN := 13
## THE EASTERN CRITICAL CHAPTER. A junction, then a JOURNEY, then one room that asks something,
## then a turn, then the climax. The previous version had three rooms of roughly equal weight and
## the honest answer to "what do you DO here" was "walk through some props" in two of them.
const P_JUNCTION := 14
const P_NORTH_HALL := 15
const P_EAST_HALL_A := 16
const P_EAST_HALL_B := 17
const P_WORKS := 18
const P_ARENA_LINK := 19
const P_ARENA := 20
const P_REWARD_HALL := 21

# Connection ids
const C_DESCEND := 0
const C_COMMIT := 1
const C_TO_COURT := 2
const C_VAULT := 3
const C_TO_LANE := 4
const C_TO_HALL := 5
const C_POCKET := 6
const C_BAY := 7
const C_DOOR_WEST := 8
const C_DOOR_EAST := 9
const C_TO_CACHE := 10
const C_CACHE_RUN := 11
## THE LOOP'S FAR-SIDE DOOR. Closed until the Cache is reached, so the west branch is a LOOP
## rather than an out-and-back -- you come back to the decision by a way you opened, not by
## retracing eight rooms.
const C_RETURN := 12
## THE CRITICAL WAY EAST, open from the moment the Court is reached. Nothing is locked at the
## fork: the choice IS the beat, and locking half of it would make it an errand.
const C_TO_JUNCTION := 13
## THE T'S TWO ARMS. West is the optional chapter, east is the critical hallway.
const C_JUNCTION_WEST := 14
const C_JUNCTION_EAST := 15
const C_EAST_HALL_BEND := 16
const C_HALL_WORKS := 17
## EARNED IN THE WORKS, which is that room's whole point.
const C_WORKS_LINK := 18
const C_LINK_ARENA := 19
## OPENED BY THE FINAL WAVE'S CLEAR.
const C_ARENA_REWARD := 20
const C_TO_WEST_HALL := 21

# Encounter ids
const E_LANDING := 0
const E_COURT := 1
const E_HALL := 2
const E_POCKET := 3
## THE ARENA'S THREE AUTHORED WAVES. Each is an ordinary sealing encounter; the sequence is made
## of ordinary encounter-cleared triggers. No wave machinery exists, and none was needed.
const E_WAVE_1 := 4
const E_WAVE_2 := 5
const E_WAVE_3 := 6
const E_WORKS := 7
const E_SPIKE_HALL := 8

# Trigger ids
const T_COMMIT := 0
const T_COURT := 1
const T_HALL := 2
const T_VAULT_REVEAL := 3
const T_POCKET := 4
const T_CACHE := 5
const T_PARTY := 6
const T_WAVE_1_CLEAR := 7
const T_WAVE_2_CLEAR := 8
const T_WAVE_3_CLEAR := 9
const T_EXIT := 10
const T_WORKS := 11
const T_SPIKE_HALL := 12

# World object ids
const S_VAULT := 0        # concealed one-shot, beside the Vault door
const S_ALTERNATE := 1    # the toggle, in the puzzle bay
const S_WORKS := 2        # the way on, behind the Works' fight
const B_VAULT_COVER := 0
const B_HALL_RUBBLE := 1
const B_BAY_PROP := 2
const B_COURT_A := 3
const B_COURT_B := 4
const B_COURT_C := 5
const B_COURT_D := 6
const B_HALL_GREEN_A := 7
const B_HALL_GREEN_B := 8
## THE SOUTH LANE'S FORMATION -- one hit each, but they occupy ground, which is what makes
## clearing them a route decision rather than target practice.
const B_LANE_A := 9
const B_LANE_B := 10
## The West Pocket's search cluster.
const B_POCKET_A := 11
const B_POCKET_B := 12
const B_POCKET_C := 13
## THE HALL'S PARTITIONS. These are what make the room a problem rather than a crossing: they
## define which lanes are open toward the control, and the enemies are placed to contest them.
const B_HALL_P_A := 14
const B_HALL_P_B := 15
const B_HALL_P_C := 16
const B_HALL_P_D := 17
## The Cache's search cluster -- the west loop's destination.
const B_CACHE_A := 18
const B_CACHE_B := 19
const B_CACHE_C := 20
const B_CACHE_D := 21
## The Arena's cover. Props, not masses: they define approach lanes and then stop existing once
## the fight has used them up.
const B_ARENA_A := 22
const B_ARENA_B := 23
const B_ARENA_C := 24
const B_ARENA_D := 25
const B_RUN_PROP := 26
const B_WORKS_A := 27
const B_WORKS_B := 28
## THE SWEEP'S SCENERY, and scenery is all it is: three props at the OUTER edge of the bend, so
## the journey has something passing by it. A traversal that has to be solved is a room.
const B_HALL_DRESSING_A := 29
const B_HALL_DRESSING_B := 30
const B_HALL_DRESSING_C := 31

## THE COMMITMENT PLATE, at the heart of the Arena. Whole active party, standing together, in the
## middle of the room the fight is about to happen in -- which says "everyone is here, begin" far
## better than a button in a corridor ever did.
const PARTY_PLATE := Rect2(193.0, -137.0, 4.0, 4.0)
## IN THE REWARD HALL ITSELF. The payoff and the departure are one room (ruled 2026-09-09): a
## corridor between them would put an empty walk where the release should be.
const EXIT_PLATE := Rect2(240.0, -136.0, 4.0, 4.0)

## EVERY MASS IS THIS TALL. Not a law -- an authored choice for this floor, and the thing the
## human replay is asked to judge. What IS durable is where they stand: beside what they hide,
## and inside a room whose composition they take part in.
const _MASS_HEIGHT: float = 4.0


static func build(plan: FloorPlan) -> void:
	_spatial(plan)
	_progression(plan)
	_world_objects(plan)
	_encounters(plan)
	plan.entry_point = Vector3(-48.0, 0.0, -7.0)
	plan.end_marker = Vector3(242.0, 0.0, -134.0)


# --- SPATIAL ---------------------------------------------------------------------------

static func _spatial(plan: FloorPlan) -> void:
	# CHAPTER 1 — down the west side, then EAST.
	_patch(plan, P_OVERLOOK, Rect2(-56.0, -12.0, 16.0, 10.0), 3.0, &"high")
	_patch(plan, P_DESCENT, Rect2(-52.0, -24.0, 10.0, 12.0), 1.5, &"ramp")
	_patch(plan, P_LANDING, Rect2(-58.0, -46.0, 28.0, 20.0), 0.0, &"stone")
	# SEPARATED FROM THE LANDING (2026-09-09). These two OVERLAPPED by 40 square units and were
	# connected by nothing else -- the patch overlap WAS the doorway. That is the oldest instance
	# of the exact fault the human named as patch soup, and it predates every eastern room I have
	# been blamed for: two rectangles sharing a corner, with no architecture saying where one room
	# ends and the next begins. They are now disjoint with a real aperture between them.
	_patch(plan, P_WEST_HALL, Rect2(-28.0, -42.0, 32.0, 10.0), 0.0, &"stone")

	# CHAPTER 2 — the Court: the floor's centre of gravity, with the Vault branching EAST off it.
	# WIDENED EAST (2026-09-09) so its two ways on sit on DIFFERENT WALLS. At 40 wide both mouths
	# crowded the same south-east corner three units apart, which is a doorway with a doorway
	# beside it rather than a fork. The lane still drops from the south edge; the east way now
	# leaves from the east edge, and the choice reads as a direction rather than as a pair of gaps.
	_patch(plan, P_COURT, Rect2(-4.0, -74.0, 48.0, 30.0), 0.0, &"arena")
	_patch(plan, P_VAULT, Rect2(50.0, -64.0, 14.0, 14.0), 0.0, &"arena")

	# CHAPTER 3 — the hazard lane, crossed WEST into the decision room.
	# EXTENDED EAST TO x=58 (2026-09-09) so it reaches under the Gallery, which is now the fork.
	# The descent used to drop from the Court; the optional route is entered a room later, and the
	# lane had to come to meet it. The crossing itself is unchanged and is in fact improved -- the
	# approach east of the pads is longer, so the prop formation and the hazard read as two beats
	# with ground between them rather than as one cluttered mouth.
	# THE SPIKE HALL -- a HALLWAY that happens to contain a hazard (2026-09-09, third correction).
	#
	# THE MISTAKE THIS RETIRES: "there are spikes here, therefore this is a spike room." A room was
	# built to hold a trap, then widened again so a junction could meet it, and the result was a
	# chamber whose shape was argued for by its contents rather than by its spatial job. Gameplay
	# does not imply a room. A hallway may carry pads, props, enemies and pressure and remain a
	# hallway, because what makes it one is elongation and directional flow -- not emptiness.
	#
	# So the hazard lives in the LEFT BRANCH of the fork: twelve deep like every other hall in this
	# composition, crossed along its length, with the optional west at its far end.
	_patch(plan, P_SPIKE_HALL, Rect2(-12.0, -116.0, 26.0, 12.0), 0.0, &"stone")
	_patch(plan, P_HALL, Rect2(-30.0, -100.0, 28.0, 22.0), 0.0, &"arena")

	# THE WEST LOOP — every room here is optional, and it comes back to the Hall on its own.
	_patch(plan, P_POCKET, Rect2(-56.0, -98.0, 20.0, 18.0), 0.0, &"stone")
	_patch(plan, P_PUZZLE_BAY, Rect2(-58.0, -124.0, 26.0, 16.0), 0.0, &"stone")
	_patch(plan, P_PUZZLE_WEST, Rect2(-58.0, -140.0, 12.0, 12.0), 0.0, &"stone")
	_patch(plan, P_PUZZLE_EAST, Rect2(-44.0, -140.0, 12.0, 12.0), 0.0, &"stone")
	_patch(plan, P_CACHE, Rect2(-30.0, -134.0, 18.0, 16.0), 0.0, &"stone")
	_patch(plan, P_RETURN_RUN, Rect2(-24.0, -116.0, 10.0, 14.0), 0.0, &"stone")

	# THE CRITICAL EAST — and it STAYS east, holding one latitude for roughly 180 units instead of
	# turning north again after a few paces. THREE BEATS BEFORE THE CLIMAX, each with a different
	# job, because a long route made of one repeated idea is just a corridor with corners:
	#
	# --- THE T, AND THE TWO THINGS IT CHOOSES BETWEEN ---------------------------------------
	#
	# THE FORK IS A HALLWAY, NOT A ROOM, and it is NOT the spike room either. Both mistakes have
	# now been made: a 26x18 chamber you had to solve to learn a choice existed, and then a spike
	# room quietly widened until three connections could meet in it. A route decision is route
	# grammar. It gets 14x10 of readable floor with three mouths and nothing whatsoever inside.
	#
	#      stem SOUTH  <- straight up from the Court
	#      arm  WEST   -> the spike hall and the optional chapter beyond it
	#      arm  EAST   -> the long hallway and everything critical
	#
	# TWELVE WIDE, LIKE EVERYTHING IT JOINS. The north approach is twelve across, the junction is
	# twelve square, and both branches are twelve deep -- so the fork reads as ONE HALL SPLITTING
	# rather than as rectangles colliding. Every previous version changed scale at the fork, and
	# every previous version read as a pile.
	_patch(plan, P_JUNCTION, Rect2(16.0, -116.0, 12.0, 12.0), 0.0, &"stone")
	# STRAIGHT NORTH OUT OF THE COURT, and nothing else. The loop of intermediate geometry that
	# used to stand between the bottom room and the choice is gone: the coordinates moved to suit
	# the route rather than the route bending to suit coordinates that were already there.
	_patch(plan, P_NORTH_HALL, Rect2(16.0, -102.0, 12.0, 26.0), 0.0, &"stone")

	# --- THE LONG EAST HALLWAY: one piece of architecture, two patches -----------------------
	#
	# CONSTANT WIDTH IS WHAT MAKES IT ONE THING. The previous version put three slabs of unlike
	# size at unlike latitudes and it read as layered rectangles rather than as a hall -- the
	# implementation seams became the architecture. Both legs here are twelve deep, exactly, and
	# only the DIRECTION changes at the bend. Width may vary elsewhere on other floors when the
	# change is authored architecture; it may never vary because two patches happened to differ.
	_patch(plan, P_EAST_HALL_A, Rect2(34.0, -116.0, 32.0, 12.0), 0.0, &"stone")
	_patch(plan, P_EAST_HALL_B, Rect2(72.0, -128.0, 40.0, 12.0), 0.0, &"stone")

	# THE WORKS: the one pre-Arena room that earned its room status, and the only space on the
	# eastern route with walls rather than a rim. An enclosed workshop should look enclosed.
	_patch(plan, P_WORKS, Rect2(118.0, -134.0, 26.0, 20.0), 0.0, &"arena", &"wall")
	# And a short connector out of it, so leaving the Works and entering the Arena are two
	# separate readable events rather than one room dissolving into the next.
	_patch(plan, P_ARENA_LINK, Rect2(150.0, -140.0, 16.0, 12.0), 0.0, &"stone")
	# DEEPENED TO 34 for the cross. A symmetrical four-arm pattern around a centred plate needs
	# room on all four sides at once, and at 28 deep the north and south perimeters came out two
	# units wide -- a pattern that is symmetrical on paper and impassable at its edges.
	_patch(plan, P_ARENA, Rect2(172.0, -152.0, 46.0, 34.0), 0.0, &"arena")
	# THE TERMINUS, and the other walled space on the floor. A destination you have earned should
	# feel enclosed; a hallway should not.
	_patch(plan, P_REWARD_HALL, Rect2(224.0, -144.0, 26.0, 20.0), 0.0, &"stone", &"wall")

	# --- THE MASSES. Each participates in the composition of the room it stands in. ---
	#
	# SIZE ALONE IS NOT CONTENT (ruled 2026-09-08). A large mass earns its place by taking part in
	# combat, route division, puzzle structure or landmark identity. A lone giant block on open
	# ground is filler, and this floor has now removed four of them across three passes.
	#
	# AND EACH KEEPS ITS DISTANCE FROM THE WALKING LINE. The view ray reaches the ground AT the
	# player, descending one unit per unit, so its height d short of the player is exactly d:
	#
	#     A MASS OF HEIGHT h COVERS THE PLAYER WHENEVER THEY WALK WITHIN h UNITS OF ITS
	#     CAMERA-FACING FACE.
	#
	# THEIR FACES ARE KEPT OFF PATCH EDGES, and the apertures likewise. A mass face flush with a
	# patch's own edge makes the two disagree about one span -- a wall and a ledge claiming the
	# same line -- and FloorPlan refuses the conflict rather than picking a winner.

	# The Court's mouth, screened from the Court's interior AND shaping its north-west corner as
	# fighting space. Two jobs, which is why it stays.
	_mass(plan, 1, Rect2(2.0, -53.0, 6.0, 10.0))

	# MASSES 2 AND 9 DELETED (ruled 2026-09-08) -- and deleted because their PURPOSE INVERTED, not
	# because large geometry is out of fashion. They existed to hide the South Lane from the Court.
	# The South Lane is now the optional west route, and optional content works by being GLIMPSED
	# from the fork so the detour can tempt. Two masses whose whole job was concealing the thing
	# the fork is supposed to advertise are now arguing against the floor. Not replaced.

	# MASS 3 DELETED (ruled 2026-09-08). 8x10 standing in the void between the West Hall and the
	# Hall, concealing hallway geometry and doing nothing else.
	# MASS 5 DELETED (ruled 2026-09-08). 14x3 in the void north of the old Puzzle Bay, screening
	# that room's approach only -- and the room it screened has moved into the west loop.
	# Neither is replaced. Their reveal work passes to the floor's new length, which is the
	# priority order: topology first, blocks last.

	# THE HALL'S PARTITION ANCHORS. These now define the room's lanes together with the rubble
	# and the prop rows -- cover the fight uses, not cover the room hides behind.
	_mass(plan, 7, Rect2(-16.0, -97.0, 5.0, 5.0))
	_mass(plan, 8, Rect2(-27.0, -84.5, 5.0, 5.0))

	# THE COURT'S LANDMARK, MOVED NORTH-EAST (2026-09-09) and off the fork's own sightline. It was
	# standing between the Court's entrance and the decision, so the way in ran round it and the
	# choice arrived after a bend -- exactly the "extra zig-zag before the actual fork" the ruling
	# names. It still gives the room something to be; it no longer stands in the middle of the
	# question the room exists to ask.
	# AND EAST AGAIN, after the instrument caught it. At x[22,30] it was off the fork's sightline
	# but its shadow fell across the Court's own ring -- 10% of the ground a player reads while
	# standing in the middle of the room. A landmark that darkens the room it orients is not doing
	# the job it is kept for.
	_mass(plan, 10, Rect2(32.0, -58.0, 8.0, 8.0))

	# MASSES 11 AND 12 DELETED (ruled 2026-09-08). Identified from the human's screenshot by
	# signature rather than by guesswork -- the Envoy stood in the only slot on the entire floor,
	# a mass close on each side, and the mapping tool found exactly one such place. They ate
	# fighting room, cut sightlines and made no tactical relationship, which is the whole case
	# against filler. THE ARENA GETS NO REPLACEMENT MASS: its composition is the plate, the
	# hazard clusters, the waves and open ground to move in.

	# THE HAZARD LANE off the Court, crossed heading WEST. Cadence is set from a measured
	# crossing (tools/measure_spike_crossing.gd), and the pads share a phase because they form
	# ONE unbroken lane with no safe ground to stop on.
	# ACROSS THE HALL'S FULL DEPTH, so the crossing runs along its LENGTH -- the direction the
	# player is already travelling. One unbroken lane with no safe ground between the pads, which
	# is why they still share a phase.
	_spikes(plan, 0, Rect2(-6.0, -116.0, 6.0, 12.0))
	_spikes(plan, 1, Rect2(0.0, -116.0, 6.0, 12.0))

	# THE ARENA'S CROSS. A DIFFERENT USE OF THE SAME VOCABULARY from the lane's crossing: there the
	# hazard is a timing corridor you commit to, here it is combat geometry that changes where you
	# WANT to stand and complicates the retreat you were counting on.
	#
	# FOUR ARMS, CARDINAL, SYMMETRICAL ABOUT THE PLATE at (159, -95) -- north and south arms 9.5
	# out, west and east arms 10.5 out. The room reads as one composition rather than as objects
	# that happened to fit, which is the whole difference between a pattern and scatter.
	#
	# WHAT THE SYMMETRY IS NOT ALLOWED TO COST, checked rather than hoped for:
	#   * every arm stands 5 or 6 clear of the plate, so the commitment point is never a timing
	#     puzzle -- the hazard FRAMES it and does not gate it
	#   * the four DIAGONAL quadrants are open, so there are four ways in to the centre
	#   * perimeters of 5 (north/south) and 10 (east/west) ring the whole pattern
	#   * the entrance quadrant is clear: you never cross a doorway onto a pad
	#
	# OPPOSITE ARMS SHARE A PHASE, adjacent arms alternate. The safe ground swings between the
	# vertical and horizontal diagonals instead of the room blinking on and off together -- and a
	# symmetrical pattern with a symmetrical rhythm is one the player can actually learn.
	_spikes(plan, 2, Rect2(192.0, -147.0, 6.0, 5.0), 0)    # north arm
	_spikes(plan, 3, Rect2(192.0, -128.0, 6.0, 5.0), 0)    # south arm
	_spikes(plan, 4, Rect2(182.0, -138.0, 5.0, 6.0), 92)   # west arm
	_spikes(plan, 5, Rect2(203.0, -138.0, 5.0, 6.0), 92)   # east arm


## `boundary` is &"ledge" for a rimmed space and &"wall" for an enclosed one. Connectors and open
## chambers take the rim; destinations that should feel like buildings take the wall.
static func _patch(plan: FloorPlan, patch_id: int, rect: Rect2, elevation: float, surface: StringName, boundary: StringName = &"ledge") -> void:
	var patch := WalkablePatch.new()
	patch.patch_id = patch_id
	patch.rect = rect
	patch.elevation = elevation
	patch.surface = surface
	patch.boundary_style = boundary
	plan.patches.append(patch)


static func _mass(plan: FloorPlan, obstacle_id: int, rect: Rect2) -> void:
	var obstacle := ObstaclePlan.new()
	obstacle.obstacle_id = obstacle_id
	obstacle.rect = rect
	obstacle.height = _MASS_HEIGHT
	plan.obstacles.append(obstacle)


static func _spikes(plan: FloorPlan, pad_id: int, rect: Rect2, phase_offset: int = 0) -> void:
	var pad := SpikePadPlan.new()
	pad.pad_id = pad_id
	pad.rect = rect
	# 150, RAISED FROM 124 BY HUMAN RULING. The measured crossing is 99 ticks, and 124 -- the
	# calculated minimum plus 25% -- was falsified in play: a well-timed crossing "barely
	# succeeds". The calculation was right about the walk and wrong about the beat, because the
	# beat includes RECOGNISING the opening and deciding to go. 150 leaves ~51 ticks for that.
	pad.safe_ticks = 150
	pad.active_ticks = 35
	pad.phase_offset_ticks = phase_offset
	pad.damage = 10.0
	pad.damage_type = &"force"
	plan.spike_pads.append(pad)


# --- PROGRESSION -----------------------------------------------------------------------

static func _progression(plan: FloorPlan) -> void:
	_connect(plan, C_DESCEND, P_OVERLOOK, P_DESCENT, Rect2(-49.5, -13.5, 5.0, 3.0), true)
	# THE ONE-WAY COMMITMENT into the floor proper.
	_connect(plan, C_COMMIT, P_DESCENT, P_LANDING, Rect2(-49.5, -27.5, 5.0, 6.0), true)
	# THE DOORWAY THAT THE OVERLAP USED TO BE.
	_connect(plan, C_TO_WEST_HALL, P_LANDING, P_WEST_HALL, Rect2(-33.0, -40.0, 10.0, 6.0), true, true, &"ledge")
	_connect(plan, C_TO_COURT, P_WEST_HALL, P_COURT, Rect2(-9.0, -46.0, 8.0, 8.0), true)
	# THE VAULT DOOR, opened by the concealed switch standing beside it.
	_connect(plan, C_VAULT, P_COURT, P_VAULT, Rect2(41.0, -60.0, 13.0, 6.0), false)
	# STRAIGHT NORTH OUT OF THE COURT.
	_connect(plan, C_TO_LANE, P_COURT, P_NORTH_HALL, Rect2(18.0, -80.0, 8.0, 8.0), true, true, &"ledge")
	# THE OPTIONAL CHAPTER, at the far end of the spike hall: the hazard is the price of the detour
	# rather than a room you visit on the way to one.
	_connect(plan, C_TO_HALL, P_SPIKE_HALL, P_HALL, Rect2(-10.0, -108.0, 10.0, 12.0), true, true, &"ledge")

	# --- THE WEST LOOP: open from the moment the Hall is entered, and never required. ---
	_connect(plan, C_POCKET, P_HALL, P_POCKET, Rect2(-38.0, -92.0, 10.0, 8.0), true)
	_connect(plan, C_BAY, P_POCKET, P_PUZZLE_BAY, Rect2(-50.0, -110.0, 8.0, 14.0), true)
	# THE ALTERNATING PAIR: west starts OPEN, east CLOSED; the toggle swaps both at once.
	_connect(plan, C_DOOR_WEST, P_PUZZLE_BAY, P_PUZZLE_WEST, Rect2(-55.0, -130.0, 5.0, 7.0), true)
	_connect(plan, C_DOOR_EAST, P_PUZZLE_BAY, P_PUZZLE_EAST, Rect2(-41.0, -130.0, 5.0, 7.0), false)
	_connect(plan, C_TO_CACHE, P_PUZZLE_EAST, P_CACHE, Rect2(-36.0, -132.0, 10.0, 6.0), true)
	_connect(plan, C_CACHE_RUN, P_CACHE, P_RETURN_RUN, Rect2(-22.0, -119.0, 6.0, 7.0), true)
	# THE LOOP CLOSES HERE, and only from this side. Reaching the Cache opens it; the player then
	# walks a way they have made rather than a way they have already seen.
	_connect(plan, C_RETURN, P_RETURN_RUN, P_HALL, Rect2(-22.0, -104.0, 6.0, 8.0), false)

	# --- THE CRITICAL EAST. Open from the start: the fork is a choice, never a lock. ---
	#
	# AND ARRIVING AT THE T, with both ways on in front of you and nothing in between.
	_connect(plan, C_TO_JUNCTION, P_NORTH_HALL, P_JUNCTION, Rect2(18.0, -108.0, 8.0, 10.0), true, true, &"ledge")
	# RIGHT, OUT OF THE FORK, and then simply a long way east. Nothing between the junction and the
	# Works is closable, fought in, or solved -- it is the journey, and journeys have no doors.
	#
	# AND ITS CORRIDORS ARE RIMMED, NOT WALLED (2026-09-09). Every connector on the critical route
	# now carries `ledge` flanks: knee-high, still bounding the route, still keeping the Envoy and
	# the ground they walk on in plain sight. The two CLOSABLE doors keep their walls, because a
	# door that shuts has to look like something that can shut.
	#
	# CONNECTOR IS NOT AN OCCLUDER. The next room owns its own reveal -- its architecture, its
	# entrance angle, the bend immediately before it -- and making fifty units of hallway tall to
	# hide a destination is solving the destination's problem in the wrong place.
	_connect(plan, C_JUNCTION_WEST, P_JUNCTION, P_SPIKE_HALL, Rect2(10.0, -114.0, 10.0, 8.0), true, true, &"ledge")
	_connect(plan, C_JUNCTION_EAST, P_JUNCTION, P_EAST_HALL_A, Rect2(25.0, -114.0, 12.0, 8.0), true, true, &"ledge")
	# THE BEND, and the only place the hallway changes direction.
	_connect(plan, C_EAST_HALL_BEND, P_EAST_HALL_A, P_EAST_HALL_B, Rect2(62.0, -122.0, 14.0, 10.0), true, true, &"ledge")
	_connect(plan, C_HALL_WORKS, P_EAST_HALL_B, P_WORKS, Rect2(109.0, -128.0, 12.0, 8.0), true, true, &"ledge")
	# EARNED IN THE WORKS: the room's control stands behind its fight, so the way on is a place you
	# have to reach rather than a door that opens because you arrived.
	_connect(plan, C_WORKS_LINK, P_WORKS, P_ARENA_LINK, Rect2(141.0, -134.0, 12.0, 8.0), false)
	_connect(plan, C_LINK_ARENA, P_ARENA_LINK, P_ARENA, Rect2(163.0, -140.0, 12.0, 8.0), true, true, &"ledge")
	# OPENED BY THE THIRD WAVE'S CLEAR, and by nothing else.
	_connect(plan, C_ARENA_REWARD, P_ARENA, P_REWARD_HALL, Rect2(215.0, -138.0, 12.0, 8.0), false)

	_trigger(plan, T_COMMIT, FloorLayers.TRIGGER_REGION, Rect2(-52.0, -36.0, 10.0, 8.0), [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_COMMIT),
	], false)
	# STAGED FIGHTS, banded at the ENTRANCE each space is actually approached from.
	_trigger(plan, T_COURT, FloorLayers.TRIGGER_REGION, Rect2(-4.0, -54.0, 20.0, 10.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_COURT),
	], false)
	_trigger(plan, T_HALL, FloorLayers.TRIGGER_REGION, Rect2(-12.0, -96.0, 10.0, 16.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_HALL),
	], false)
	_trigger(plan, T_VAULT_REVEAL, FloorLayers.TRIGGER_BREAKABLE_DESTROYED, Rect2(), [
		FloorLayers.effect(FloorLayers.EFFECT_REVEAL_SWITCH, S_VAULT),
	], false, B_VAULT_COVER)
	_trigger(plan, T_POCKET, FloorLayers.TRIGGER_REGION, Rect2(-52.0, -94.0, 14.0, 10.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_POCKET),
	], false)
	# REACHING THE CACHE OPENS THE WAY HOME. The loop's far-side door is the payoff's companion:
	# what you get for going all the way is that you do not have to come all the way back.
	_trigger(plan, T_CACHE, FloorLayers.TRIGGER_REGION, Rect2(-26.0, -130.0, 12.0, 8.0), [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_RETURN),
	], false)

	# THE COMMITMENT, at the centre of the Arena. One indivisible consequence: the way back closes
	# and the first wave wakes in the same instant, so the plate means exactly one thing --
	# "everyone is here, begin". Entering the Arena starts nothing; walking to the middle of it
	# together does.
	#
	# CLOSING THE WEST IS LEGITIMATE HERE because the player had a legible chance at it first: the
	# western rooms are in view on the way down into the floor, both ways out of the Court are open
	# from the moment they reach it, and the Arena can be walked into, looked at and walked back
	# out of before anyone stands on this.
	_trigger(plan, T_PARTY, FloorLayers.TRIGGER_GROUP_OCCUPANCY, PARTY_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_BLOCK_CONNECTION, C_LINK_ARENA),
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_WAVE_1),
	], true)

	# --- THE ARENA'S WAVES, built entirely from vocabulary that already existed. ---
	#
	# An encounter already advances to "cleared" the tick its whole roster is dead, already emits
	# encounter_cleared, and already fires triggers watching it. A wave sequence is therefore
	# three authored encounters and two triggers -- no wave state, no phase manager, no new
	# effect kind. The capability was audited before it was assumed to be missing.
	_trigger(plan, T_WAVE_1_CLEAR, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, Rect2(), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_WAVE_2),
	], false, E_WAVE_1)
	_trigger(plan, T_WAVE_2_CLEAR, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, Rect2(), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_WAVE_3),
	], false, E_WAVE_2)
	_trigger(plan, T_WAVE_3_CLEAR, FloorLayers.TRIGGER_ENCOUNTER_CLEARED, Rect2(), [
		FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_ARENA_REWARD),
	], false, E_WAVE_3)

	_trigger(plan, T_SPIKE_HALL, FloorLayers.TRIGGER_REGION, Rect2(6.0, -114.0, 8.0, 8.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_SPIKE_HALL),
	], false)
	_trigger(plan, T_WORKS, FloorLayers.TRIGGER_REGION, Rect2(120.0, -132.0, 12.0, 16.0), [
		FloorLayers.effect(FloorLayers.EFFECT_ACTIVATE_ENCOUNTER, E_WORKS),
	], false)
	_trigger(plan, T_EXIT, FloorLayers.TRIGGER_GROUP_OCCUPANCY, EXIT_PLATE, [
		FloorLayers.effect(FloorLayers.EFFECT_COMPLETE_FLOOR, -1),
	], true)


## `flank_style` is &"wall" for a doorway and &"ledge" for a hallway. See TraversalConnection.
static func _connect(plan: FloorPlan, connection_id: int, near_id: int, far_id: int, aperture: Rect2, starts_open: bool, has_barrier: bool = true, flank_style: StringName = &"wall") -> void:
	var connection := TraversalConnection.new()
	connection.connection_id = connection_id
	connection.patch_ids = Vector2i(near_id, far_id)
	connection.aperture = aperture
	connection.starts_open = starts_open
	connection.has_barrier = has_barrier
	connection.flank_style = flank_style
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
	# obvious cause and effect.
	var vault_switch := HitSwitchPlan.new()
	vault_switch.switch_id = S_VAULT
	vault_switch.position = Vector3(42.0, 0.0, -62.0)
	vault_switch.radius = 0.7
	vault_switch.mode = HitSwitchPlan.MODE_ONE_SHOT
	vault_switch.starts_hidden = true
	vault_switch.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_VAULT)]
	plan.hit_switches.append(vault_switch)

	# THE WORKS' CONTROL, standing behind that room's fight. The eastern chapter needs one beat
	# that is solved rather than crossed, and this is it: the way on is a specific place you have
	# to reach while three enemies would rather you did not.
	var works_switch := HitSwitchPlan.new()
	works_switch.switch_id = S_WORKS
	works_switch.position = Vector3(139.0, 0.0, -130.0)
	works_switch.radius = 0.8
	works_switch.mode = HitSwitchPlan.MODE_ONE_SHOT
	works_switch.effects = [FloorLayers.effect(FloorLayers.EFFECT_OPEN_CONNECTION, C_WORKS_LINK)]
	plan.hit_switches.append(works_switch)

	# THE ALTERNATING TOGGLE, in the bay with BOTH doors in front of it.
	var toggle := HitSwitchPlan.new()
	toggle.switch_id = S_ALTERNATE
	toggle.position = Vector3(-45.0, 0.0, -114.0)
	toggle.radius = 0.8
	toggle.mode = HitSwitchPlan.MODE_TOGGLE
	toggle.effects = [
		FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, C_DOOR_WEST),
		FloorLayers.effect(FloorLayers.EFFECT_TOGGLE_CONNECTION, C_DOOR_EAST),
	]
	plan.hit_switches.append(toggle)

	# S_HALL RETIRED (2026-09-08). It opened the commitment gate, and the gate it opened no longer
	# exists -- the Hall is optional content now and nothing on the critical path waits on it. Its
	# room keeps everything that made it worth fighting in: the rubble, the partition rows and a
	# roster placed to contest both ways round. A control with nothing to control is ceremony, and
	# deleting it is cheaper than inventing a door for it to open.

	# EVERY PROP BREAKS IN ONE HIT. Challenge is positioning and consequence, never hit points.
	_breakable(plan, B_VAULT_COVER, Vector3(40.0, 0.0, -62.0), 1.1)
	# MOVED BACK ONTO THE BAY'S FLOOR (2026-09-08). It had been orphaned in void when the Puzzle
	# Bay moved east in an earlier pass -- the room travelled and its prop did not. FloorPlan now
	# refuses that class of drift outright rather than relying on anyone noticing it.
	_breakable(plan, B_BAY_PROP, Vector3(-46.0, 0.0, -116.0), 1.0)
	# THE COURT'S CLUSTERS, asymmetric on purpose: a loose group west of the landmark and a
	# tighter one south-east, so the room has a near side and a far side rather than a pattern.
	_breakable(plan, B_COURT_A, Vector3(2.0, 0.0, -58.0), 1.0)
	_breakable(plan, B_COURT_B, Vector3(5.0, 0.0, -62.0), 1.0)
	# MOVED SOUTH-WEST (2026-09-09), off the line between the Court's entrance and its fork. They
	# had been sitting on the diagonal the player walks to reach the decision, which is the same
	# mistake as the landmark and for the same reason: the room's job is to present a choice, and
	# everything standing in the way of seeing it is working against the room.
	_breakable(plan, B_COURT_C, Vector3(6.0, 0.0, -70.0), 1.0)
	_breakable(plan, B_COURT_D, Vector3(10.0, 0.0, -67.0), 1.0)
	# THE WEST HALL IS A QUIET CONNECTOR: something to look at, nothing to fight.
	_breakable(plan, B_HALL_GREEN_A, Vector3(-26.0, 0.0, -37.0), 1.0)
	_breakable(plan, B_HALL_GREEN_B, Vector3(-22.0, 0.0, -39.0), 1.0)
	# THE SOUTH LANE'S FORMATION: unblock, THEN commit. It sits EAST of the pads, so clearing it
	# never eats into the crossing window. It SHAPES rather than SEALS -- the gap between the two
	# blockers admits the widest authored body, so pursuit is never walled off.
	# FRAMING THE CROSSING'S APPROACH, tucked against the hall's two rims so the middle of the path
	# stays clear. They mark where the safe ground ends without standing in it.
	_breakable(plan, B_LANE_A, Vector3(9.0, 0.0, -115.0), 1.2, Rect2(8.0, -116.0, 2.0, 2.0))
	_breakable(plan, B_LANE_B, Vector3(9.0, 0.0, -105.0), 1.2, Rect2(8.0, -106.0, 2.0, 2.0))
	# THE WEST POCKET'S SEARCH CLUSTER.
	_breakable(plan, B_POCKET_A, Vector3(-48.0, 0.0, -88.0), 1.0)
	_breakable(plan, B_POCKET_B, Vector3(-45.0, 0.0, -90.0), 1.0)
	_breakable(plan, B_POCKET_C, Vector3(-50.0, 0.0, -91.0), 1.0)
	# THE HALL'S RUBBLE: the first thing seen through the doorway, with the room's Watcher behind
	# it and the control beyond that.
	_breakable(plan, B_HALL_RUBBLE, Vector3(-8.0, 0.0, -89.0), 2.0, Rect2(-11.0, -91.0, 6.0, 4.0))
	# THE HALL'S PARTITION ROWS, north and south of the rubble. Together the three define which
	# way across the room is open, and the enemies are placed to contest each of them.
	_breakable(plan, B_HALL_P_A, Vector3(-20.0, 0.0, -82.0), 1.0)
	_breakable(plan, B_HALL_P_B, Vector3(-16.0, 0.0, -82.0), 1.0)
	_breakable(plan, B_HALL_P_C, Vector3(-24.0, 0.0, -95.0), 1.0)
	_breakable(plan, B_HALL_P_D, Vector3(-20.0, 0.0, -95.0), 1.0)
	# THE CACHE'S SEARCH CLUSTER. The west loop's destination is a search, honestly: the room is
	# the natural home of a reward once that vocabulary exists, and inventing a placeholder prize
	# now would be faking a system rather than building one.
	_breakable(plan, B_CACHE_A, Vector3(-24.0, 0.0, -128.0), 1.0)
	_breakable(plan, B_CACHE_B, Vector3(-20.0, 0.0, -126.0), 1.0)
	_breakable(plan, B_CACHE_C, Vector3(-26.0, 0.0, -124.0), 1.0)
	_breakable(plan, B_CACHE_D, Vector3(-18.0, 0.0, -130.0), 1.0)
	_breakable(plan, B_RUN_PROP, Vector3(-19.0, 0.0, -110.0), 1.0)
	# THE ARENA'S ONLY SOLID OBJECTS, and there are four one-hit crates rather than two masses.
	# They sit on the apron and the perimeter -- somewhere to break a line of sight for a moment,
	# never anything standing between the player and the middle of the room.
	_breakable(plan, B_ARENA_A, Vector3(175.0, 0.0, -123.0), 1.0)
	_breakable(plan, B_ARENA_B, Vector3(175.0, 0.0, -147.0), 1.0)
	_breakable(plan, B_ARENA_C, Vector3(215.0, 0.0, -123.0), 1.0)
	_breakable(plan, B_ARENA_D, Vector3(215.0, 0.0, -147.0), 1.0)
	# THE FORK CARRIES NOTHING AT ALL. Its last two crates went with the room they were dressing:
	# a junction whose only job is to be read does not need something standing in it.
	# THE WORKS: cover for its fight, placed between the door and the control.
	_breakable(plan, B_WORKS_A, Vector3(130.0, 0.0, -118.0), 1.0)
	_breakable(plan, B_WORKS_B, Vector3(132.0, 0.0, -126.0), 1.0)
	# THE SWEEP'S SCENERY, on the OUTER edge of the bend and off the walking line -- something to
	# pass, never something to solve.
	_breakable(plan, B_HALL_DRESSING_A, Vector3(60.0, 0.0, -114.0), 1.0)
	_breakable(plan, B_HALL_DRESSING_B, Vector3(78.0, 0.0, -126.0), 1.0)
	_breakable(plan, B_HALL_DRESSING_C, Vector3(100.0, 0.0, -126.0), 1.0)


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
		{"enemy_key": &"ooze", "position": Vector3(34.0, 0.0, -60.0)},
	] as Array[Dictionary])
	# THE DECISION ROOM'S FIGHT -- DELIBERATELY NOT SEALING.
	#
	# Sealing was available and would have been truthful: a confining encounter already forbids
	# leaving until its roster is dead, so "clear the Hall to proceed" needs no new mechanic. It
	# is NOT used, because sealing would shut the west door for the duration and the west door is
	# the thing this room exists to offer. Here the enemies are COMBAT PRESSURE ON A TASK, not a
	# clear condition: the control can be reached and hit while all three are alive, and a player
	# who wants the west loop deals with them because the loop's mouth is on the far side.
	_encounter(plan, E_HALL, P_HALL, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"watcher", "position": Vector3(-24.0, 0.0, -88.0)},
		{"enemy_key": &"fang", "position": Vector3(-8.0, 0.0, -96.0)},
		{"enemy_key": &"fang", "position": Vector3(-14.0, 0.0, -81.0)},
	] as Array[Dictionary])
	# THE POCKET'S OPTIONAL FIGHT, the west loop's first beat.
	_encounter(plan, E_POCKET, P_POCKET, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"fang", "position": Vector3(-52.0, 0.0, -86.0)},
		{"enemy_key": &"fang", "position": Vector3(-42.0, 0.0, -94.0)},
	] as Array[Dictionary])

	# THE SPIKE HALL'S RANGED PRESSURE. Two Watchers at the hall's FAR CORNERS -- the existing
	# ranged family, not a new turret archetype invented for one phrase. They hold the ground the
	# crossing delivers you onto, so the hazard and the threat ask different things at the same
	# time: the pads decide WHEN you move, the Watchers decide whether standing still is an option.
	#
	# They stand clear of the pads and clear of the walking line, at the two far-side corners, so
	# the safe ground either side of the crossing stays genuinely safe to occupy.
	_encounter(plan, E_SPIKE_HALL, P_SPIKE_HALL, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"watcher", "position": Vector3(-9.0, 0.0, -113.0)},
		{"enemy_key": &"watcher", "position": Vector3(-9.0, 0.0, -107.0)},
	] as Array[Dictionary])
	# THE WORKS' FIGHT, with the control behind it. The Watcher holds the far end beside the
	# switch; the Fangs come round the cover.
	_encounter(plan, E_WORKS, P_WORKS, FloorLayers.ROLE_OPTIONAL, false, [
		{"enemy_key": &"watcher", "position": Vector3(137.0, 0.0, -124.0)},
		{"enemy_key": &"fang", "position": Vector3(126.0, 0.0, -130.0)},
		{"enemy_key": &"fang", "position": Vector3(128.0, 0.0, -118.0)},
	] as Array[Dictionary])

	# --- THE ARENA'S THREE WAVES. Each roster is authored, never generated. ---
	#
	# ALL THREE SEAL. That is what holds both doors shut for the duration: the rear was already
	# blocked by the commitment, and the forward door opens only on the third clear. The sealing
	# flag is doing its ordinary job, which is why the Arena needed no bespoke arena logic.
	#
	# PLACED BY COMPOSITION, NOT BY RANGE (2026-09-08). An earlier draft clustered all three waves
	# within 18 units of the room's centre, because a roster member further out engaged on
	# activation and went inert on the next tick. That was a workaround for a law conflict, and
	# the conflict has since been fixed at its seam (_leash_exceeded): an ACTIVE encounter's
	# territory is its authored region, not an M1 radius. So these positions answer the fight --
	# flanks, sightlines, the anchors, and room to move -- and nothing else.
	#
	# EVERY MEMBER MUST VISIBLY WAKE, and "visibly" turned out to be the harder half.
	#
	# TWO CONSTRAINTS, BOTH MEASURED, NEITHER GUESSED:
	#
	#   1. ENGAGEMENT. Activation engages a roster and ordinary law governs it from there, so a
	#      spawn parked beyond the pursuit relationship engages and gives up on the same tick and
	#      reads as a statue. Every position below is within that relationship of the plate.
	#
	#   2. THE CAMERA, which is the one that actually reshaped these rosters. The view is ~13 units
	#      wide at the player's OWN row and widens with distance ahead, so a 46-wide room cannot be
	#      seen across at the latitude you are standing on. The first draft spread these waves
	#      handsomely across the full width and FOUR OF TEN woke off screen
	#      (tools/verify_arena_readability.gd). A threat that wakes where you cannot see it is
	#      unfair in the one way a wave arena must never be.
	#
	# So the rosters favour ground AHEAD of the plate rather than beside it -- north buys width,
	# lateral does not. The room's full 46 is still used, by movement and by the hazard clusters;
	# it is the WAKING that is kept inside the frame.
	#
	# WAVE 1 — three Fangs spread across the western half, around the first cluster. Fast and
	# simple: the room teaches its own geometry before it asks anything.
	_encounter(plan, E_WAVE_1, P_ARENA, FloorLayers.ROLE_MANDATORY, false, [
		{"enemy_key": &"fang", "position": Vector3(184.0, 0.0, -144.0)},
		{"enemy_key": &"fang", "position": Vector3(201.0, 0.0, -147.0)},
		{"enemy_key": &"fang", "position": Vector3(203.0, 0.0, -142.0)},
	] as Array[Dictionary], true)
	# WAVE 2 — a Watcher in the far EAST corner with the second anchor between it and the player,
	# and the Oozes on the northern flank. The ranged threat is deliberately at the room's far
	# extreme: it can only be answered by crossing, which is the wave's whole shape and was
	# impossible to author while a spawn 40 units out would simply stand still.
	_encounter(plan, E_WAVE_2, P_ARENA, FloorLayers.ROLE_MANDATORY, false, [
		{"enemy_key": &"watcher", "position": Vector3(208.0, 0.0, -144.0)},
		{"enemy_key": &"ooze", "position": Vector3(183.0, 0.0, -143.0)},
		{"enemy_key": &"ooze", "position": Vector3(188.0, 0.0, -130.0)},
	] as Array[Dictionary], true)
	# WAVE 3 — the composite, and a mirror. The Watcher moves to the WEST corner so the room is
	# not solved by learning one side, the Fangs take opposite ends of the northern edge, and the
	# Ooze holds the middle south. Corner to corner across all 46 units, on purpose.
	_encounter(plan, E_WAVE_3, P_ARENA, FloorLayers.ROLE_MANDATORY, false, [
		{"enemy_key": &"watcher", "position": Vector3(180.0, 0.0, -142.0)},
		{"enemy_key": &"fang", "position": Vector3(206.0, 0.0, -146.0)},
		{"enemy_key": &"fang", "position": Vector3(185.0, 0.0, -146.0)},
		{"enemy_key": &"ooze", "position": Vector3(200.0, 0.0, -128.0)},
	] as Array[Dictionary], true)


static func _encounter(plan: FloorPlan, encounter_id: int, patch_id: int, role: StringName, at_load: bool, roster: Array[Dictionary], confines: bool = false) -> void:
	var site := EncounterSite.new()
	site.encounter_id = encounter_id
	site.regions = [plan.patch_by_id(patch_id).rect]
	site.role = role
	site.confines_player = confines
	site.spawn_at_floor_load = at_load
	site.roster = roster
	plan.encounters.append(site)
