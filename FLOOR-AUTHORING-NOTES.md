# Floor 1 & Floor 2 — Authoring Notes

**Extracted 2026-10-09, when the coordinate-bearing builder scripts retired (P36 Slice A).**

The floors now live in `game/content/layouts/*.tres`. A resource holds values; it cannot hold a
sentence. Everything below is the reasoning that stood beside those coordinates in
`archive_prototype.gd` and `archive_roundabout.gd` — why a mass moved, why a doorway is where it
is, which human ruling produced which number. It is preserved verbatim rather than summarised,
because the value of these notes is in the specific corrections they record.

The gameplay laws these notes reference live in GAME-RULES.md; the durable lessons are banked in
BRAIN.md 12–18. This file is the floor-specific record.


---

## Floor 2 — the Archive Roundabout

FLOOR 2 — explore, decide, commit, fight, cross, arrive.
(Rebuilt 2026-09-08 from the approved route-choice expansion.)

THE CORRECTION THIS FLOOR IS BUILT ON. Earlier versions tried to create mystery by standing
large masses in front of things. That failed twice in play, and the diagnosis was not "the
walls are wrong" but "the floor is too short to hide itself". A floor long enough to have
several substantial sections can show you its neighbours freely and still keep its ending
unresolved, because the ending is genuinely far away rather than merely occluded.

LENGTH AND BRANCHING ARE THE REVEAL TOOL. Screening masses were the wrong instrument.

AND THE DECISION IS THE GALLERY (moved there 2026-09-09, from a human screenshot of the exact
standing point). The whole westward sequence -- lane, chamber, pocket, puzzle rooms, cache --
is OPTIONAL, and the critical path strikes EAST across new ground instead. An earlier pass got
this wrong by hanging a NEW optional limb beside the old mainline rather than reclassifying the
mainline itself; a later one put the fork in the Court, one room too early.

SO THE SHAPE IS NO LONGER A FOLDED RIBBON. It is a spine with a fork at its centre:

x=-58    -30     -4      +48   +80   +112  +136      +188    +214
z=-2  +-OVERLOOK-+
-24   +-DESCENT--+           c1 ONE-WAY, sealed behind you
-46 +--LANDING---+--WEST HALL-+
-74                   +--------COURT--------+    +-VAULT-+  (optional, north-east)
| one hall, straight north
spikes + Watchers        the critical east
-110   optional west <== SPIKE HALL ==+== T ==+================>
** THE FORK **
-84                                            +-GALLERY-+
-96     +---------- SOUTH LANE ----------+     left: down   right: east
(spikes, crossed WEST)                     |             |
-100 +------ THE HALL ------+    |                       +-WORKS-+     fight + control
|                |        |                           +-APPROACH-+   breathe
(opt)  +-POCKET         |        |                                 |
(opt)  +-PUZZLE BAY     |        |                +------- THE ARENA -------+
(opt)  +-[D1]--[D2]     |        |                | [plate] at dead centre  |
(opt)  +-P WEST P EAST -> CACHE -> RETURN RUN     | four spike arms, a cross|
|________^             +-------------------------+
the loop closes                       |
+-REWARD HALL, and its exit-+

CRITICAL   Landing · West Hall · Court · THE JUNCTION (the fork) · the Sweep · Works ·
the Turn · ARENA · Reward Hall (which carries the exit)
OPTIONAL   Vault (east, off the Court)
THE WHOLE WEST (South Lane · Hall · Pocket · Puzzle Bay · doors · Cache), which
returns to the Hall by its own far-side door and to the Court by the lane.

BOTH WAYS OUT OF THE FORK ARE OPEN. Nothing is locked there, because the choosing is the
beat -- lock half of it and it stops being a decision and becomes an errand. The floor's one
irreversible moment is the party plate at the CENTRE OF THE ARENA: step into the middle of the
climax room together and the exploration phase closes behind you as the first wave wakes.

THE FLOOR IS NOW WELL OVER TWICE AS WIDE AS IT IS DEEP, roughly 322 x 138 -- against 126 x 186
four passes ago. That inversion is the point rather than a side effect: the mystery comes from a
floor with somewhere further to go, and six screening masses have been deleted across four
passes to pay for it. Nothing here is hidden by standing something in front of it.

THE EASTERN CRITICAL CHAPTER. A junction, then a JOURNEY, then one room that asks something,
then a turn, then the climax. The previous version had three rooms of roughly equal weight and
the honest answer to "what do you DO here" was "walk through some props" in two of them.

THE LOOP'S FAR-SIDE DOOR. Closed until the Cache is reached, so the west branch is a LOOP
rather than an out-and-back -- you come back to the decision by a way you opened, not by
retracing eight rooms.

THE CRITICAL WAY EAST, open from the moment the Court is reached. Nothing is locked at the
fork: the choice IS the beat, and locking half of it would make it an errand.

THE T'S TWO ARMS. West is the optional chapter, east is the critical hallway.

EARNED IN THE WORKS, which is that room's whole point.

THE ARENA'S THREE AUTHORED WAVES. Each is an ordinary sealing encounter; the sequence is made
of ordinary encounter-cleared triggers. No wave machinery exists, and none was needed.

THE SOUTH LANE'S FORMATION -- one hit each, but they occupy ground, which is what makes
clearing them a route decision rather than target practice.

THE HALL'S PARTITIONS. These are what make the room a problem rather than a crossing: they
define which lanes are open toward the control, and the enemies are placed to contest them.

The Cache's search cluster -- the west loop's destination.

The Arena's cover. Props, not masses: they define approach lanes and then stop existing once
the fight has used them up.

THE SWEEP'S SCENERY, and scenery is all it is: three props at the OUTER edge of the bend, so
the journey has something passing by it. A traversal that has to be solved is a room.

THE COMMITMENT PLATE, at the heart of the Arena. Whole active party, standing together, in the
middle of the room the fight is about to happen in -- which says "everyone is here, begin" far
better than a button in a corridor ever did.

IN THE REWARD HALL ITSELF. The payoff and the departure are one room (ruled 2026-09-09): a
corridor between them would put an empty walk where the release should be.

EVERY MASS IS THIS TALL. Not a law -- an authored choice for this floor, and the thing the
human replay is asked to judge. What IS durable is where they stand: beside what they hide,
and inside a room whose composition they take part in.

--- SPATIAL ---------------------------------------------------------------------------

CHAPTER 1 — down the west side, then EAST.

SEPARATED FROM THE LANDING (2026-09-09). These two OVERLAPPED by 40 square units and were
connected by nothing else -- the patch overlap WAS the doorway. That is the oldest instance
of the exact fault the human named as patch soup, and it predates every eastern room I have
been blamed for: two rectangles sharing a corner, with no architecture saying where one room
ends and the next begins. They are now disjoint with a real aperture between them.

CHAPTER 2 — the Court: the floor's centre of gravity, with the Vault branching EAST off it.
WIDENED EAST (2026-09-09) so its two ways on sit on DIFFERENT WALLS. At 40 wide both mouths
crowded the same south-east corner three units apart, which is a doorway with a doorway
beside it rather than a fork. The lane still drops from the south edge; the east way now
leaves from the east edge, and the choice reads as a direction rather than as a pair of gaps.

CHAPTER 3 — the hazard lane, crossed WEST into the decision room.
EXTENDED EAST TO x=58 (2026-09-09) so it reaches under the Gallery, which is now the fork.
The descent used to drop from the Court; the optional route is entered a room later, and the
lane had to come to meet it. The crossing itself is unchanged and is in fact improved -- the
approach east of the pads is longer, so the prop formation and the hazard read as two beats
with ground between them rather than as one cluttered mouth.
THE SPIKE HALL -- a HALLWAY that happens to contain a hazard (2026-09-09, third correction).

THE MISTAKE THIS RETIRES: "there are spikes here, therefore this is a spike room." A room was
built to hold a trap, then widened again so a junction could meet it, and the result was a
chamber whose shape was argued for by its contents rather than by its spatial job. Gameplay
does not imply a room. A hallway may carry pads, props, enemies and pressure and remain a
hallway, because what makes it one is elongation and directional flow -- not emptiness.

So the hazard lives in the LEFT BRANCH of the fork: twelve deep like every other hall in this
composition, crossed along its length, with the optional west at its far end.

THE WEST LOOP — every room here is optional, and it comes back to the Hall on its own.

THE CRITICAL EAST — and it STAYS east, holding one latitude for roughly 180 units instead of
turning north again after a few paces. THREE BEATS BEFORE THE CLIMAX, each with a different
job, because a long route made of one repeated idea is just a corridor with corners:

--- THE T, AND THE TWO THINGS IT CHOOSES BETWEEN ---------------------------------------

THE FORK IS A HALLWAY, NOT A ROOM, and it is NOT the spike room either. Both mistakes have
now been made: a 26x18 chamber you had to solve to learn a choice existed, and then a spike
room quietly widened until three connections could meet in it. A route decision is route
grammar. It gets 14x10 of readable floor with three mouths and nothing whatsoever inside.

stem SOUTH  <- straight up from the Court
arm  WEST   -> the spike hall and the optional chapter beyond it
arm  EAST   -> the long hallway and everything critical

TWELVE WIDE, LIKE EVERYTHING IT JOINS. The north approach is twelve across, the junction is
twelve square, and both branches are twelve deep -- so the fork reads as ONE HALL SPLITTING
rather than as rectangles colliding. Every previous version changed scale at the fork, and
every previous version read as a pile.

STRAIGHT NORTH OUT OF THE COURT, and nothing else. The loop of intermediate geometry that
used to stand between the bottom room and the choice is gone: the coordinates moved to suit
the route rather than the route bending to suit coordinates that were already there.

--- THE LONG EAST HALLWAY: one piece of architecture, two patches -----------------------

CONSTANT WIDTH IS WHAT MAKES IT ONE THING. The previous version put three slabs of unlike
size at unlike latitudes and it read as layered rectangles rather than as a hall -- the
implementation seams became the architecture. Both legs here are twelve deep, exactly, and
only the DIRECTION changes at the bend. Width may vary elsewhere on other floors when the
change is authored architecture; it may never vary because two patches happened to differ.

THE WORKS: the one pre-Arena room that earned its room status, and the only space on the
eastern route with walls rather than a rim. An enclosed workshop should look enclosed.

And a short connector out of it, so leaving the Works and entering the Arena are two
separate readable events rather than one room dissolving into the next.

DEEPENED TO 34 for the cross. A symmetrical four-arm pattern around a centred plate needs
room on all four sides at once, and at 28 deep the north and south perimeters came out two
units wide -- a pattern that is symmetrical on paper and impassable at its edges.

THE TERMINUS, and the other walled space on the floor. A destination you have earned should
feel enclosed; a hallway should not.

--- THE MASSES. Each participates in the composition of the room it stands in. ---

SIZE ALONE IS NOT CONTENT (ruled 2026-09-08). A large mass earns its place by taking part in
combat, route division, puzzle structure or landmark identity. A lone giant block on open
ground is filler, and this floor has now removed four of them across three passes.

AND EACH KEEPS ITS DISTANCE FROM THE WALKING LINE. The view ray reaches the ground AT the
player, descending one unit per unit, so its height d short of the player is exactly d:

A MASS OF HEIGHT h COVERS THE PLAYER WHENEVER THEY WALK WITHIN h UNITS OF ITS
CAMERA-FACING FACE.

THEIR FACES ARE KEPT OFF PATCH EDGES, and the apertures likewise. A mass face flush with a
patch's own edge makes the two disagree about one span -- a wall and a ledge claiming the
same line -- and FloorPlan refuses the conflict rather than picking a winner.

The Court's mouth, screened from the Court's interior AND shaping its north-west corner as
fighting space. Two jobs, which is why it stays.

MASSES 2 AND 9 DELETED (ruled 2026-09-08) -- and deleted because their PURPOSE INVERTED, not
because large geometry is out of fashion. They existed to hide the South Lane from the Court.
The South Lane is now the optional west route, and optional content works by being GLIMPSED
from the fork so the detour can tempt. Two masses whose whole job was concealing the thing
the fork is supposed to advertise are now arguing against the floor. Not replaced.

MASS 3 DELETED (ruled 2026-09-08). 8x10 standing in the void between the West Hall and the
Hall, concealing hallway geometry and doing nothing else.
MASS 5 DELETED (ruled 2026-09-08). 14x3 in the void north of the old Puzzle Bay, screening
that room's approach only -- and the room it screened has moved into the west loop.
Neither is replaced. Their reveal work passes to the floor's new length, which is the
priority order: topology first, blocks last.

THE HALL'S PARTITION ANCHORS. These now define the room's lanes together with the rubble
and the prop rows -- cover the fight uses, not cover the room hides behind.

THE COURT'S LANDMARK, MOVED NORTH-EAST (2026-09-09) and off the fork's own sightline. It was
standing between the Court's entrance and the decision, so the way in ran round it and the
choice arrived after a bend -- exactly the "extra zig-zag before the actual fork" the ruling
names. It still gives the room something to be; it no longer stands in the middle of the
question the room exists to ask.
AND EAST AGAIN, after the instrument caught it. At x[22,30] it was off the fork's sightline
but its shadow fell across the Court's own ring -- 10% of the ground a player reads while
standing in the middle of the room. A landmark that darkens the room it orients is not doing
the job it is kept for.

MASSES 11 AND 12 DELETED (ruled 2026-09-08). Identified from the human's screenshot by
signature rather than by guesswork -- the Envoy stood in the only slot on the entire floor,
a mass close on each side, and the mapping tool found exactly one such place. They ate
fighting room, cut sightlines and made no tactical relationship, which is the whole case
against filler. THE ARENA GETS NO REPLACEMENT MASS: its composition is the plate, the
hazard clusters, the waves and open ground to move in.

THE HAZARD LANE off the Court, crossed heading WEST. Cadence is set from a measured
crossing (tools/measure_spike_crossing.gd), and the pads share a phase because they form
ONE unbroken lane with no safe ground to stop on.
ACROSS THE HALL'S FULL DEPTH, so the crossing runs along its LENGTH -- the direction the
player is already travelling. One unbroken lane with no safe ground between the pads, which
is why they still share a phase.

THE ARENA'S CROSS. A DIFFERENT USE OF THE SAME VOCABULARY from the lane's crossing: there the
hazard is a timing corridor you commit to, here it is combat geometry that changes where you
WANT to stand and complicates the retreat you were counting on.

FOUR ARMS, CARDINAL, SYMMETRICAL ABOUT THE PLATE at (159, -95) -- north and south arms 9.5
out, west and east arms 10.5 out. The room reads as one composition rather than as objects
that happened to fit, which is the whole difference between a pattern and scatter.

WHAT THE SYMMETRY IS NOT ALLOWED TO COST, checked rather than hoped for:
* every arm stands 5 or 6 clear of the plate, so the commitment point is never a timing
puzzle -- the hazard FRAMES it and does not gate it
* the four DIAGONAL quadrants are open, so there are four ways in to the centre
* perimeters of 5 (north/south) and 10 (east/west) ring the whole pattern
* the entrance quadrant is clear: you never cross a doorway onto a pad

OPPOSITE ARMS SHARE A PHASE, adjacent arms alternate. The safe ground swings between the
vertical and horizontal diagonals instead of the room blinking on and off together -- and a
symmetrical pattern with a symmetrical rhythm is one the player can actually learn.

`boundary` is &"ledge" for a rimmed space and &"wall" for an enclosed one. Connectors and open
chambers take the rim; destinations that should feel like buildings take the wall.

150, RAISED FROM 124 BY HUMAN RULING. The measured crossing is 99 ticks, and 124 -- the
calculated minimum plus 25% -- was falsified in play: a well-timed crossing "barely
succeeds". The calculation was right about the walk and wrong about the beat, because the
beat includes RECOGNISING the opening and deciding to go. 150 leaves ~51 ticks for that.

--- PROGRESSION -----------------------------------------------------------------------

THE ONE-WAY COMMITMENT into the floor proper.

THE VAULT DOOR, opened by the concealed switch standing beside it.

THE OPTIONAL CHAPTER, at the far end of the spike hall: the hazard is the price of the detour
rather than a room you visit on the way to one.

--- THE WEST LOOP: open from the moment the Hall is entered, and never required. ---

THE ALTERNATING PAIR: west starts OPEN, east CLOSED; the toggle swaps both at once.

THE LOOP CLOSES HERE, and only from this side. Reaching the Cache opens it; the player then
walks a way they have made rather than a way they have already seen.

--- THE CRITICAL EAST. Open from the start: the fork is a choice, never a lock. ---

AND ARRIVING AT THE T, with both ways on in front of you and nothing in between.

RIGHT, OUT OF THE FORK, and then simply a long way east. Nothing between the junction and the
Works is closable, fought in, or solved -- it is the journey, and journeys have no doors.

AND ITS CORRIDORS ARE RIMMED, NOT WALLED (2026-09-09). Every connector on the critical route
now carries `ledge` flanks: knee-high, still bounding the route, still keeping the Envoy and
the ground they walk on in plain sight. The two CLOSABLE doors keep their walls, because a
door that shuts has to look like something that can shut.

CONNECTOR IS NOT AN OCCLUDER. The next room owns its own reveal -- its architecture, its
entrance angle, the bend immediately before it -- and making fifty units of hallway tall to
hide a destination is solving the destination's problem in the wrong place.

THE BEND, and the only place the hallway changes direction.

EARNED IN THE WORKS: the room's control stands behind its fight, so the way on is a place you
have to reach rather than a door that opens because you arrived.

OPENED BY THE THIRD WAVE'S CLEAR, and by nothing else.

STAGED FIGHTS, banded at the ENTRANCE each space is actually approached from.

REACHING THE CACHE OPENS THE WAY HOME. The loop's far-side door is the payoff's companion:
what you get for going all the way is that you do not have to come all the way back.

THE COMMITMENT, at the centre of the Arena. One indivisible consequence: the way back closes
and the first wave wakes in the same instant, so the plate means exactly one thing --
"everyone is here, begin". Entering the Arena starts nothing; walking to the middle of it
together does.

CLOSING THE WEST IS LEGITIMATE HERE because the player had a legible chance at it first: the
western rooms are in view on the way down into the floor, both ways out of the Court are open
from the moment they reach it, and the Arena can be walked into, looked at and walked back
out of before anyone stands on this.

--- THE ARENA'S WAVES, built entirely from vocabulary that already existed. ---

An encounter already advances to "cleared" the tick its whole roster is dead, already emits
encounter_cleared, and already fires triggers watching it. A wave sequence is therefore
three authored encounters and two triggers -- no wave state, no phase manager, no new
effect kind. The capability was audited before it was assumed to be missing.

`flank_style` is &"wall" for a doorway and &"ledge" for a hallway. See TraversalConnection.

--- WORLD OBJECTS ---------------------------------------------------------------------

THE VAULT'S CONTROL, beside its own door on the Court's east side: concealed, one-shot,
obvious cause and effect.

THE WORKS' CONTROL, standing behind that room's fight. The eastern chapter needs one beat
that is solved rather than crossed, and this is it: the way on is a specific place you have
to reach while three enemies would rather you did not.

THE ALTERNATING TOGGLE, in the bay with BOTH doors in front of it.

S_HALL RETIRED (2026-09-08). It opened the commitment gate, and the gate it opened no longer
exists -- the Hall is optional content now and nothing on the critical path waits on it. Its
room keeps everything that made it worth fighting in: the rubble, the partition rows and a
roster placed to contest both ways round. A control with nothing to control is ceremony, and
deleting it is cheaper than inventing a door for it to open.

EVERY PROP BREAKS IN ONE HIT. Challenge is positioning and consequence, never hit points.

MOVED BACK ONTO THE BAY'S FLOOR (2026-09-08). It had been orphaned in void when the Puzzle
Bay moved east in an earlier pass -- the room travelled and its prop did not. FloorPlan now
refuses that class of drift outright rather than relying on anyone noticing it.

THE COURT'S CLUSTERS, asymmetric on purpose: a loose group west of the landmark and a
tighter one south-east, so the room has a near side and a far side rather than a pattern.

MOVED SOUTH-WEST (2026-09-09), off the line between the Court's entrance and its fork. They
had been sitting on the diagonal the player walks to reach the decision, which is the same
mistake as the landmark and for the same reason: the room's job is to present a choice, and
everything standing in the way of seeing it is working against the room.

THE WEST HALL IS A QUIET CONNECTOR: something to look at, nothing to fight.

THE SOUTH LANE'S FORMATION: unblock, THEN commit. It sits EAST of the pads, so clearing it
never eats into the crossing window. It SHAPES rather than SEALS -- the gap between the two
blockers admits the widest authored body, so pursuit is never walled off.
FRAMING THE CROSSING'S APPROACH, tucked against the hall's two rims so the middle of the path
stays clear. They mark where the safe ground ends without standing in it.

THE HALL'S RUBBLE: the first thing seen through the doorway, with the room's Watcher behind
it and the control beyond that.

THE HALL'S PARTITION ROWS, north and south of the rubble. Together the three define which
way across the room is open, and the enemies are placed to contest each of them.

THE CACHE'S SEARCH CLUSTER. The west loop's destination is a search, honestly: the room is
the natural home of a reward once that vocabulary exists, and inventing a placeholder prize
now would be faking a system rather than building one.

THE ARENA'S ONLY SOLID OBJECTS, and there are four one-hit crates rather than two masses.
They sit on the apron and the perimeter -- somewhere to break a line of sight for a moment,
never anything standing between the player and the middle of the room.

THE FORK CARRIES NOTHING AT ALL. Its last two crates went with the room they were dressing:
a junction whose only job is to be read does not need something standing in it.
THE WORKS: cover for its fight, placed between the door and the control.

THE SWEEP'S SCENERY, on the OUTER edge of the bend and off the walking line -- something to
pass, never something to solve.

--- ENCOUNTERS ------------------------------------------------------------------------

THE COURT: open ground, so the fight here is about space rather than cover.

THE DECISION ROOM'S FIGHT -- DELIBERATELY NOT SEALING.

Sealing was available and would have been truthful: a confining encounter already forbids
leaving until its roster is dead, so "clear the Hall to proceed" needs no new mechanic. It
is NOT used, because sealing would shut the west door for the duration and the west door is
the thing this room exists to offer. Here the enemies are COMBAT PRESSURE ON A TASK, not a
clear condition: the control can be reached and hit while all three are alive, and a player
who wants the west loop deals with them because the loop's mouth is on the far side.

THE POCKET'S OPTIONAL FIGHT, the west loop's first beat.

THE SPIKE HALL'S RANGED PRESSURE. Two Watchers at the hall's FAR CORNERS -- the existing
ranged family, not a new turret archetype invented for one phrase. They hold the ground the
crossing delivers you onto, so the hazard and the threat ask different things at the same
time: the pads decide WHEN you move, the Watchers decide whether standing still is an option.

They stand clear of the pads and clear of the walking line, at the two far-side corners, so
the safe ground either side of the crossing stays genuinely safe to occupy.

THE WORKS' FIGHT, with the control behind it. The Watcher holds the far end beside the
switch; the Fangs come round the cover.

--- THE ARENA'S THREE WAVES. Each roster is authored, never generated. ---

ALL THREE SEAL. That is what holds both doors shut for the duration: the rear was already
blocked by the commitment, and the forward door opens only on the third clear. The sealing
flag is doing its ordinary job, which is why the Arena needed no bespoke arena logic.

PLACED BY COMPOSITION, NOT BY RANGE (2026-09-08). An earlier draft clustered all three waves
within 18 units of the room's centre, because a roster member further out engaged on
activation and went inert on the next tick. That was a workaround for a law conflict, and
the conflict has since been fixed at its seam (_leash_exceeded): an ACTIVE encounter's
territory is its authored region, not an M1 radius. So these positions answer the fight --
flanks, sightlines, the anchors, and room to move -- and nothing else.

EVERY MEMBER MUST VISIBLY WAKE, and "visibly" turned out to be the harder half.

TWO CONSTRAINTS, BOTH MEASURED, NEITHER GUESSED:

1. ENGAGEMENT. Activation engages a roster and ordinary law governs it from there, so a
spawn parked beyond the pursuit relationship engages and gives up on the same tick and
reads as a statue. Every position below is within that relationship of the plate.

2. THE CAMERA, which is the one that actually reshaped these rosters. The view is ~13 units
wide at the player's OWN row and widens with distance ahead, so a 46-wide room cannot be
seen across at the latitude you are standing on. The first draft spread these waves
handsomely across the full width and FOUR OF TEN woke off screen
(tools/verify_arena_readability.gd). A threat that wakes where you cannot see it is
unfair in the one way a wave arena must never be.

So the rosters favour ground AHEAD of the plate rather than beside it -- north buys width,
lateral does not. The room's full 46 is still used, by movement and by the hazard clusters;
it is the WAKING that is kept inside the frame.

WAVE 1 — three Fangs spread across the western half, around the first cluster. Fast and
simple: the room teaches its own geometry before it asks anything.

WAVE 2 — a Watcher in the far EAST corner with the second anchor between it and the player,
and the Oozes on the northern flank. The ranged threat is deliberately at the room's far
extreme: it can only be answered by crossing, which is the wave's whole shape and was
impossible to author while a spawn 40 units out would simply stand still.

WAVE 3 — the composite, and a mirror. The Watcher moves to the WEST corner so the room is
not solved by learning one side, the Fangs take opposite ends of the northern edge, and the
Ooze holds the middle south. Corner to corner across all 46 units, on purpose.


---

## Floor 1 — the Archive Prototype

THE HAND-AUTHORED PROTOTYPE FLOOR. One deterministic floor built through the production data
structures, to test the floor GRAMMAR before any procedural assembly exists.

DATA-AS-CODE, deliberately. A .tres schema for six interlocking layers would have to be
invented, hand-written and thrown away before a second floor ever exists (§1.4 rule of two).
When a second authored floor arrives, THIS is what migrates to a resource -- not sooner.

THE GRAMMAR IT ENCODES, in order:
START -> one-way commitment -> irregular open hall wrapping a VOID -> a forward route
visible but BLOCKED -> a branch (west solves, east is inhabited) -> breakable search
revealing a HIDDEN PLATE -> standing on it opens the blocked route -> PARTY PLATE: rear
seals, forward opens, roster spawns, encounter begins -> clear -> the way onward opens ->
ramp to raised ground -> EXIT PLATE completes the floor.

THERE IS NO `interact` VERB ON THIS FLOOR. Every control is something you STAND ON, and the
floor has no press left that a player could not have discovered by walking.

TWO BEATS CHANGED AFTER HUMAN PLAY (2026-08-29), both removing input that bought nothing:
* the party button is now a PLATE you stand on, not an E interactable -- a coordination
trigger, which is what the beat always meant (ruled).
* the final switch is GONE. An obvious door whose only ask was one E press had no
discovery and no decision in it, so the last connection now opens from its REAL
prerequisite: clearing the encounter. No puzzle was invented to preserve the press.

z=0    ┌───────────────┐                     p0  START
│       ▲       │
-6     └──────┬┬───────┘
││ c0  one-way: entering the hall seals it behind you
-12    ┌──────┴┴───────┐                     pS  hall, south strip
-16    ├────┐     ┌────┤
│ pW │VOID │ pE │  <- paths wrap a hole; pE is AMBIENT territory
-28/30 ├────┘     └────┤
-34    └──────┬┬───────┘                     pN  hall, north strip
││ c1  BLOCKED -- visible from the hall long before it opens
-36    ┌──────┴┴───────┐                     pApproach  (PARTY PLATE, stand on it)
-42    └──────┬┬───────┘
││ c2  BLOCKED until the button
-48    ┌──────┴┴───────┐
│    ARENA      │                     pArena  (validated combat dimensions)
-68    └──────┬┬───────┘
││ c3  BLOCKED until the encounter clears
-70/76 ┌──────┴┴───────┐  pRamp   elevation 1
-74/88 │   HIGH GROUND │  pHigh   elevation 2  (LEDGE edges: no wall mesh, still bounded)
││ c4  opens with c3, on the same encounter clear
-92/98 └──────┴┴───────┘  pEnd    endpoint marker

EVERY CONNECTION APERTURE OVERLAPS BOTH PATCHES IT JOINS by _OVERLAP; patches that simply
touch would share zero area and make the threshold a discontinuity. Patch-to-patch overlaps
inside the hall need no connection at all -- connectivity is rectangle overlap, and a
TraversalConnection exists only where CONTROL is wanted.

The door-control response: a small, UNSEALED arrival when the hidden plate opens the way.

What the crate hides: a plate, dormant until the crate is gone. Sits where the crate stood,
down the west branch, deliberately far from the route it opens.

SMALLER THAN THE PARTY PLATE, footprint and look both (human finding 2026-08-29). The two
read as different KINDS OF THING -- a local control you discovered, versus a coordinated
commitment the whole expedition steps onto -- and that difference is carried entirely by
authoring and presentation. No mechanic distinguishes them.

The footprint shrinks WITH the mesh, never independently: a plate whose visual is smaller
than its trigger would fire from ground that does not look like a plate, which is exactly
the kind of quiet dishonesty the gate/rule split exists to prevent.

The plate the expedition must stand on to commit to the fight. Sits inside pApproach, so the
seal closes around where the party already is.

THE FLOOR EXIT. Not a passive marker any more: progression is gated on the whole expedition
standing here together, which is the same condition the party plate asks (FloorLayers).

--- SPATIAL --------------------------------------------------------------------------

The hall is FOUR patches forming a ring. The hole in the middle is not authored as a
"void object" -- it is simply ground nobody laid, which is the whole reason irregular
silhouettes are free in a union-of-patches model.

THE ROUNDABOUT — FULLY OPEN (human ruling 2026-09-01). Both walls came off: the outer
perimeter so the space stops feeling boxed in, and the VOID-FACING RING because it was
protecting a rejected content assumption.

The old law was "the concealed crate must not be shootable across the void". FALSIFIED by
ruling: making a player walk the whole ring only to learn a breakable was empty is friction
without discovery. Shooting across the hole is now intentional -- and progression is
untouched by it, because breaking the crate only REVEALS the plate; you still have to walk
the west arm and stand on it.

The void needs no wall to read as a void: it is a hole in the floor, and an open edge shows
it. No blocker was added elsewhere, nothing was relocated, no hidden occlusion invented.

Arena keeps the dimensions VALIDATED BY PLAY as a combat room (30 x 20).

THE RAISED PLATFORM READS AS A LEDGE, not a walled box. Sim legality is identical -- the
Envoy still cannot step off -- but nothing is rendered to hide the drop, which is the
whole point of the distinction (human finding: not every walkable edge needs a wall).

--- PROGRESSION ----------------------------------------------------------------------

ONE-WAY COMMITMENT, expressed as an ordinary controller rather than a new legality rule:
reaching the hall fires once and blocks the way back. Nothing about C_COMMIT is special.

SEARCH -> DISCOVERY, with no press in it. Breaking the crate ENABLES the plate it hid;
stepping onto that plate opens the forward route. The discovery is the crate and the
plate, never a keypress -- the E only ever confirmed something the player already knew.

THE DOOR-CONTROL BEAT: opening the way is answered. One authored record, two effects, no new
machinery -- the audit found the beat already expressible as trigger + connection effect +
encounter activation, so nothing was built for it.

THE PARTY PLATE -- the whole reference sequence as ONE authored record. Reading these
three lines tells you everything standing on it does; splitting them across gate, spawn
and presentation code is how "why did the door shut?" becomes unanswerable.

It is a PLATE, not a button: the beat was always "the party commits together", and an E
press could never express that. Its condition is every living Envoy standing here at once
(solo resolves to one), and it fires on the FALSE -> TRUE edge, so waiting on it is quiet.

THE REAL PREREQUISITE FOR THE WAY OUT IS THE FIGHT. Both remaining connections open on the
clear, so the route onward is continuous once it is earned. The switch that used to sit on
the high ground is gone: it gated nothing the clear had not already decided.

THE EXIT IS THE SAME QUESTION AS THE COMMITMENT: is everyone here? One shared condition,
two authored consequences. Completing the floor is a FACT and an Event -- there is no next
floor yet, and faking one to give this somewhere to go would be building a system to
satisfy a flag.

Builds the aperture between two patches stacked along -Z, poking _OVERLAP into each.

--- ENCOUNTER ------------------------------------------------------------------------

MANDATORY. Its region spans the approach, the corridor and the arena so that pressing the
button from the approach never leaves the Envoy standing outside their own confinement --
the seal closes around where the player already is, it never drags them somewhere.

THE DOOR-CONTROL RESPONSE. OPTIONAL and explicitly NOT sealing: solving the floor draws
attention, but the player may still walk away up the route they just opened. `confines_player
= false` is what keeps this a pressure beat rather than a second arena, and
`spawn_at_floor_load = false` is what makes it ARRIVE rather than having been waiting.

AMBIENT. No activation ceremony and no lock: it inhabits the east column and fights if you
cross it. Territory is authored as a UNION and may span patches -- binding it to the single
patch it spawns in is what made it stick the instant the player crossed a seam.

BUT IT IS DELIBERATELY ONE CONVEX RECTANGLE, not the whole hall ring. Instrumentation
(tools/diagnose_ooze_pursuit.gd) confirmed that a territory wrapping the VOID makes
straight-line pursuit rub along the corner: 80 of 80 contact-phase ticks lost to legality
for 0.9 units of progress. The AI has no obstacle routing and this prototype is not the
place to invent one, so the AUTHORING obeys the AI's actual capability:

AMBIENT TERRITORIES USED BY STRAIGHT-LINE AI MUST BE CONVEX -- their walkable union must
equal their own bounding box, so no pursuit inside them ever needs to route around
anything. Guarded by test_depth_generator.gd, not by memory.

This column spans the east arm and its junction with BOTH strips, so the Ooze still meets
anyone crossing its ground, and reads as guarding its arm rather than scraping a corner.
Obstacle-aware navigation is ROADMAP work (P33), for a floor that actually needs it.

--- WORLD INTERACTION -----------------------------------------------------------------

The blocker's solution is deliberately ELSEWHERE, down the west branch, under a prop.
