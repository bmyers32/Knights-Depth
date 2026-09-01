# ROADMAP.md — Knight Depths
Future work + ideas outside current milestone scope. Milestone status lives in CLAUDE.md.

<!-- TOKEN DISCIPLINE: read ONLY the Index below unless a specific entry is needed —
     then jump to it by id. Append = one Index row + full entry at the bottom of
     Feature Proposals. At milestone completion (mandatory once the Index exceeds
     20 live entries): delete SHIPPED/REJECTED entries, leave a one-line tombstone
     in the Graveyard. Git history is the archive — deletion loses nothing. -->

## Index
| Id | Proposal | Status | One-liner |
|---|---|---|---|
| P1 | Bombs — third weapon class | TREAT-CANDIDATE | Placed AoE/status class; pipeline already carries `class` field |
| P2 | Full status roster | PROPOSED | Frost/Jolt/Venom/Daze/Hex/Slumber, one per playtested iteration |
| P3 | Consumable vials | PROPOSED | Any-build status application + common loot drop |
| P4 | Mender-type enemy | PROPOSED | Enemy healer → kill-priority decisions; justifies Venom |
| P5 | Gear stars, heat, crafting | PROPOSED | M4 progression skeleton, recorded shape |
| P6 | Rotating gate map (arcade) | PROPOSED | M5 shared-world route meta-game |
| P7 | Companion system | PROPOSED | One slot, protocol-determined occupant; sync-anchor fiction; M4+ |
| P8 | Protocols (Mend/Temper) | PROPOSED | Per-run philosophy loadout; expression not access; M4+ |
| P9 | Drift scalar | PROPOSED | Zone `drift: float` in sim drives spawns/presentation; M2-adjacent |
| P10 | Gear states (Mended/Stable/Drifted) | PROPOSED | Mechanical identities per state; content multiplier — earned rollout |
| P11 | Contested enemy state | PROPOSED | Caught between forces; elite encounters, post-M2 |
| P12 | Frames (mobility platforms) | PROPOSED | Combat identities, not transport; maybe a Companion-slot expression |
| P13 | Community world-state | PROPOSED | Shared Drift scalar + thresholds; architect-for at P9, build M5-if-ever |
| P14 | Title decision | PROPOSED | Replace working title from lexicon families; zero urgency |
| P15 | Dodge (own input + i-frame trigger) | PROPOSED | Second §3 i-frame source; must reuse the hit-i-frame timer, never a new mechanism |
| P16 | Shield bump + perfect parry | **TREAT (M1 close)** | SPLIT into two separable mechanics: bump = spacing utility (no timing); parry = mastery layer |
| P17 | Per-family engagement identities | **CLOSED 2026-08-28 — BURROW SHIPPED** | Weave/scurry/cutoff falsified; BURROW passed all three human gates (action, fairness, selector). Fang has a validated ambush identity chosen by ordinary AI. Values frozen; debts carried out separately |
| P18 | Idle wander + return-to-post + room territory | PROPOSED | Post-disengage idle behavior layer; needs its own RNG stream; M2 |
| P19 | Per-family mass/knockback factor | PROPOSED | Weight scales pipeline knockback only; binds to family, never to state (§6.8) |
| P20 | Sim movement collision/bounds | **WALL HALF CLOSED 2026-08-28 (M2 Slice 1)** | Floor bounds now clamp all 6 displacement seams + 2 placement seams. STILL OPEN: actor-vs-actor body-blocking, and projectile-vs-world (named fence below) |
| P21 | Arena camera-follow | PROPOSED — **now rate-limiting M2 floor size** | Fixed camera doesn't track the Envoy; StratumConfig's chamber Z ceiling is set by this, not by design taste |
| P22 | Buffer eligibility during charge windup | PROPOSED | Scope cut, not canon — a projected `end_tick` is already computable |
| P23 | Graded player poise | PROPOSED | Mirrors `interrupt_strength`; M1 ships unconditional cancel only |
| P24 | Reactions beyond flinch + enemy action phases | PROPOSED | Knockdown, player-side reactions, punishable recoveries; second consumer decides shared infra |
| P25 | Weapon-owned state & switch semantics | PROPOSED | Holstered-state categories, switch-reset tech, ammo/heat — all gated on a real consumer |
| P26 | Ranged weapon identity futures | PROPOSED | Distance bands, committed burst, hazards, marks; identity = changed decision, not new numbers |
| P27 | Multi-hit / attack-instance model | PROPOSED | Re-hit eligibility as a separate question from global health i-frames; incl. cross-attacker suppression |
| P29 | Enemy action repertoire / distance-conditioned selection | **PASS / CLOSED 2026-08-18** | Frozen point `9378316`; follow-ups dispatched to P17/P28/P30/P31/P32 |
| P30 | Wand commitment/reward mechanic | **NEAR-TERM (weapon docket)** | Broadened 2026-08-17; charge vs consecutive-hit empowerment — evaluate before implementing |
| P33 | Ooze movement quality | **PASS 2026-09-01 · closed** | Built to the frozen spec. Measured on the real geometry: rub ticks 203 -> 0, arrival 321 -> 202 ticks. All 11 pre-registered tests green |
| P34 | Projectile-vs-world obstruction | **LANDED 2026-08-31 · migration classified B** | Human gate PASSED ("they read naturally"). One authored WALL/LEDGE fact shared by sim + presentation; shots stop on walls and closed gates, pass open ledges |
| P31 | Reflected-projectile parry | PROPOSED | Breon design intent; must-reconnect + one-reflect-per-raise; needs its own fork review |
| P28 | Global combat-scale coherence pass | RESOLVED for M1 (narrowed) | Was mostly Ooze's undersized footprint, not a global rescale; animation-alignment revalidation still open |

Statuses: PROPOSED → TREAT-CANDIDATE → IN-MILESTONE → SHIPPED / REJECTED.

## FLOOR 1 AUTHORING 2026-09-01 — door beat LANDED; roundabout BLOCKED on a real fork.

### DOOR-CONTROL ENEMY RESPONSE — **built with existing primitives, nothing new**
The audit found the beat already expressible, so nothing was built for it:
`TRIGGER_REGION` (the revealed plate) -> `EFFECT_OPEN_CONNECTION` + `EFFECT_ACTIVATE_ENCOUNTER`.

`E_PLATE_RESPONSE` is **OPTIONAL**, `confines_player = false`, `spawn_at_floor_load = false` --
so solving the floor draws a single Fang into the west arm as pressure, and the player may still
walk away up the route they just opened. It arrives rather than having been waiting.

**A FALSIFICATION GUARD FIRED, and it was right to.** "No encounter may activate by geometry" is
the multi-room slice's falsified rule made unrepresentable, and it blocked this beat. The law's
own wording was always *"unless it was authored deliberately"* while the test implemented a
blanket ban. **REFINED, in both copies:** the exemption is not "party plates only" but *anything
the player can SEE and must deliberately stand on* -- and a second test now pins the other half,
that an activation claiming the exemption must ACTUALLY draw a plate, so flipping the flag cannot
silently buy one. **An invisible region trigger starting a fight is still banned**, which is the
ban that ever mattered.

### OPEN ROUNDABOUT — **NOT APPLIED. Design fork, measured.**
Ledging the four hall patches was tried and **reopens the P34 sequence break**: with the void's
edges no longer solid, the crate becomes shootable from across the hall. Two tests went red,
correctly.

**THE CAUSE IS GRANULARITY.** `boundary_style` is **per-patch**, and every hall patch touches BOTH
the outer perimeter -- where "boxed in" comes from -- and the void, where the projectile protection
comes from. One flag cannot open one and keep the other.

**OPTIONS, none taken:**
1. **Per-edge boundary style.** Solves it exactly: outer edges ledge, void edges wall. It is a
   real capability addition, not the "authoring change, not a new mechanic" the ruling scoped.
2. **Split the hall into outer and inner bands** so the styles can differ per patch. Authoring
   only, but it changes walkable geometry to work around a schema limit -- and the seams would be
   invisible to the player while being load-bearing for anyone reading the layout later.
3. **Accept the sequence break.** Rejected: P34 exists to close it.
4. **Ledge elsewhere** (approach, arena) where no void is involved. A partial win that does not
   touch the region the ruling actually named.

Returned for ruling rather than guessed, because option 1 exceeds the authorized scope and option
2 trades a schema problem for a geometry problem.

## P33 MOVEMENT QUALITY — **PASS (Breon, 2026-09-01).** Arc closed.

Replay of `bab167d`, verbatim:
> "The chase went well. Slime chased me all around, didn't look bad — just some inefficient
> movements as it zigs before approaching, sometimes looking like it's retreating a little bit.
> I approve of that for now."

Rendered against the frozen criterion:
> "When the Ooze has to go around something, it looks like it picked somewhere to go and goes
> there, rather than changing its mind back and forth."

### ACCEPTED V1 IMPERFECTION — recorded as accepted, not as an open failure
Pursuit may take an inefficient initial zig, which can momentarily read as a slight retreat before
the approach. **Human explicitly approves it for now.** Do NOT optimise this further merely because
a mathematically shorter route exists. Reopen only if Floor 2 or larger-floor play produces a
materially worse manifestation.

### THE ARC, closed
| finding | disposition |
|---|---|
| original rapid zig-zag | real |
| mid-leg `route_clear` oscillation | identified, structurally removed |
| cardinal steering promotion | withdrawn after invalid recon evidence |
| east-lane apparent navigation stall | reclassified as attack-band hold |
| attack-band absolute hold | proven mechanically |
| lateral attack-band tracking | implemented |
| final normal-play chase | **human-approved** |

Historical mechanisms that are no longer active are NOT reopened merely because later movement
looks imperfect. `bab167d` is the accepted v1 movement baseline.

## BOUNDED LATERAL MATCHING — **BUILT 2026-09-01.** The band hold answered.

Option 2 as ruled. The absolute in-band hold is replaced by: maintain radial attack spacing while
allowing bounded TANGENTIAL movement to follow a laterally moving target.

| case | before | after |
|---|---|---|
| **player circling at band distance** | 0.00 u, **0/600** ticks | **2.21 u, 377/600 ticks** |
| player retreating (control) | 11.80 u, 236/600 | **11.80 u, 236/600 — unchanged** |
| telegraphs, both cases | 8 | **8 — unchanged** |
| gap while tracking | — | 2.05, still inside 1.90-2.20 |

**THE SEMANTIC SPLIT is the design.** Radial motion belongs to the approach/retreat law and is
untouched; only the tangential component -- the part of the target's motion perpendicular to the
actor->target line -- gives an actor already at fighting distance a reason to reposition. A test
asserts directly that purely radial target motion produces NO tracking.

**NOT VELOCITY COPYING.** Only the DIRECTION of the tangential component is taken; the actor then
moves at its own `move_speed` under its own legality, so a fast player still out-runs a slow blob.
Mirroring velocity would have erased the family character this is meant to preserve.

**ONE FIELD**, `_ai_band_last_target` -- the sim stores positions, not velocities, so seeing that
a target MOVED requires one remembered position. Per-actor AI state, floor lifetime, filed with
the `_ai_*` family. No smoothing machinery: one frame differenced. If that proves jittery in play
it becomes an evidenced question, not a pre-emptive filter.

### BLOCKED LATERAL TRACK — EXPECTED BEHAVIOUR, recorded so it is not re-reported as a stall
P33 avoidance is deliberately NOT blended into band tracking. **A player who strafes the Ooze into
a wall's shadow will see it stop tracking -- planted again, legitimately this time, with a visible
wall explaining it.** That is the intended v1 result, not a defect; ordinary pursuit resumes only
when the normal distance conditions require it.

### HELD, per ruling
Attack cadence (~2.8 s per swing) is a SECONDARY OBSERVATION, not a tuning item -- it sits inside
the M1 numeric fence and is reconsidered only if the Ooze still feels inert now that it visibly
tracks. Band width stays 1.90-2.20: **it was never the defect**, and no width fixes a distance
band's blindness to lateral motion.

## P33 EVIDENCE LEDGER (quoted verbatim into the criterion's record)

The frozen criterion stays OPEN. Every prior "failure" turned out to be a different mechanism
than the sentence was judging, which is why it stayed open this long:

| finding | disposition |
|---|---|
| rapid zig-zag | **real, structurally addressed** |
| cardinal promotion | **withdrawn after invalid recon evidence** |
| apparent east-lane navigation stall | **reclassified as attack-band hold** |
| attack-band hold | **now proven mechanically, and fixed** |

> "When the Ooze has to go around something, it looks like it picked somewhere to go and goes
> there, rather than changing its mind back and forth."

The next replay judges the COMPLETE shipped behaviour -- ordinary pursuit, obstacle behaviour
where encountered, attack-band locomotion, disengage and return -- and only then is
PASS/ITERATE rendered.

## ATTACK-BAND HOLD — **MECHANISM IDENTIFIED 2026-09-01.** Not obstacle navigation.

`tools/diagnose_attack_band_hold.gd`, on an open plain where nothing can be blamed on geometry,
preconditions asserted every tick:

| case | translation | ticks moving | telegraphs |
|---|---|---|---|
| **player STRAFES at band distance** | **0.00 u over 600 ticks** | **0 / 600** | 8 |
| player RETREATS (control) | 11.80 u | 236 / 600 | 8 |

**The Ooze is completely planted for twenty seconds while facing and attacking.** Pursuit itself
is healthy -- the control chases correctly.

### WHY
The authored band is `minimum 1.90 .. preferred 2.20` -- **0.30 units wide** -- and movement
preference governs APPROACH ONLY: an actor inside the band holds. **It is a DISTANCE band, so
lateral motion is invisible to it.** A player circling at ~2.0 stays inside it forever, and the
Ooze never translates.

That is precisely the reported symptom -- *"facing/following the player while barely moving"* --
and it is a COMBAT LOCOMOTION / READABILITY question, not obstacle routing. No steering grammar
would have changed it: the actor never asks for a route because it never wants to move.

### COSTED OPTIONS, none taken
1. **Keep planted.** Zero cost. Defensible as Ooze character -- a slow blob that plants and swings
   -- but a human has now read it as broken once, which is evidence against.
2. **Lateral matching (smallest mechanical change).** While in band, translate to hold relative
   position when the target has lateral velocity. Keeps the distance law untouched; adds a
   movement clause inside the band rather than a new steering vocabulary. This is the option that
   actually addresses the observation.
3. **Band tuning -- REJECTED BY ANALYSIS, not by taste.** Widening or narrowing 1.90-2.20 cannot
   help: a distance band is blind to lateral motion at ANY width, so a circling player stays
   inside whatever band exists. Recording the reason so it is not retried.
4. **Attack cadence (content).** Windup 30 ticks + 55-tick interval means roughly one swing per
   2.8 s; standing still between slow swings is what reads as idle rather than menacing. Inside
   the M1 numeric fence, so it is a human call, not a change to propose here.

### CONSEQUENCE FOR P33
The frozen movement criterion stays OPEN, and this finding narrows what remains: the original
rapid zig-zag was real and was structurally fixed; the cross-void stall was invalid evidence; the
east-lane "stall" is this band hold. **No navigation defect is currently outstanding.**

## EAST-LANE STALL RECON 2026-09-01 — **NOT A NAVIGATION DEFECT on this reconstruction.**

**THE SCREENSHOT DID NOT REACH THIS SESSION.** It reached the review seat; no image is in this
context. Worked from the description instead -- "long right-hand vertical lane near the upper
section, Ooze immediately north of the Envoy in apparently continuous traversable space" -- mapped
to authored geometry rather than pixels: **P_HALL_EAST**, `Rect2(8,-30,8,16)`, northern end.

### THE FOURTH INSTRUMENTATION FAILURE, and this one nearly shipped a verdict
The first run of this recon reported **0.00 u over 400 ticks, 0 legs committed** -- a textbook
stall. It was measuring **a corpse**. The 30 HP Envoy died to the Ooze mid-measurement, and *"no
living player: enemies stop acting entirely"* is a locked law, so the actor correctly did nothing.

The precondition check I had already added did not catch it, because **it asserted state only at
t=0** and the player died later. The tool now overrides player health every tick and asserts
`_find_living_player_id()`, not merely `ai_state`.

Four instances now, all the same shape: **idle actor / disengaged actor / wrong legality region /
dead player.** Each produced perfectly accurate numbers answering a different question.

### WITH ENGAGEMENT AND LIVENESS BOTH PROVEN
```
moves on 91/400 ticks    net 1.45 u    legs committed 0    final gap 1.90
```
It settles at **exactly `minimum_attack_distance` (1.90)** and holds, windup active, attacking on
cadence. **Cardinal never engages because the gap almost never exceeds `preferred` (2.20).**

**CLASSIFICATION: the movement-band hold, which is the shipped AI law** -- movement preference
governs approach only, and an actor inside the band holds. A slow enemy planted at attack range
between slow swings READS as stuck without being stuck.

**CAVEAT, stated rather than buried:** this is the reconstruction, not the screenshot. If the real
frame had a materially larger gap, the mechanism there is different and this recon does not cover
it. The mapping is a hypothesis from a description.

### CONSEQUENCE FOR THE CARDINAL RULING
The evidence that promoted cardinal steering was the cross-void case, since withdrawn as
unreachable. This recon does not replace it: **no navigation failure was found at the described
location.** If the movement-band hold is what the human saw, the lever is the attack/movement band
(content), not the steering grammar.

## WATCHER CANARY AUDIT — **DOES NOT QUALIFY.**
The ruling asked whether Watcher can host the replacement untouched-family canary. It cannot:
P33 authored `avoid_commit_ticks = 45` onto Watcher, so local avoidance is LIVE for it. It is not
a family that current navigation work leaves alone.

No family currently qualifies: Ooze has cardinal, Fang has burrow plus avoidance, Watcher has
avoidance. Establishing the canary on Watcher would repeat the exact mistake that invalidated the
Ooze one.

**OPTION, not taken:** author `avoid_commit_ticks = 0` on Watcher -- "absence is off" restores its
pre-P33 straight-line pursuit and makes it genuinely untouched. That is a behaviour decision about
a shipped family, so it is returned for ruling rather than made here.

## P33 — CARDINAL STEERING RECON + COSTING, 2026-08-31. **NO CODE. Awaiting ruling.**

Human replay of `69016ee`: pursuit **better overall** ("it did better when chasing me around for
the most part"), but still visibly zig-zagging, and the Ooze **stalled** in the upper area.
Preference stated plainly: *"Can it not just go south, south, south until lined up, then west,
west, west?"* The frozen movement criterion is NOT satisfied. No PASS stamped.

### THE STALL — REPRODUCED, and it is worse than "sluggish"
**No screenshot reached this session**, so the location was reconstructed from the description
(led back toward its origin; upper area) as the HALL ring. If the real stall was elsewhere this
recon measured the wrong spot -- said here rather than quietly answering a different question.

`tools/diagnose_hall_stall.gd`, Ooze at (12,-22) east arm, player at (-12,-22) west arm, straight
across the void:

```
obstruction to player   blocked at 2.9 u
APERTURE candidates     2, both at z = -13.5 (connection 0, back toward START -- useless here)
selected waypoint       NONE
NET DISPLACEMENT        0.00 u over 300 ticks
```

**Total paralysis, not slow pursuit.**

**CLASSIFICATION: class 3, INEXPRESSIBLE.** Not truly blocked -- a legal route exists and is
walked below. Not a closed-gate dead end -- the ring route needs no gate at all, because hall
connectivity is PATCH OVERLAP, not authored connections. And that is the precise gap: **the
aperture vocabulary can only see `_connections`, and the hall has none where it matters.** The
route the player can see is one the selector has no word for.

### CORRECTION 2026-08-31 — the "0.00 paralysis" reproduction was INVALID. Withdrawn.

Instrumenting engagement state (which the fixture had not printed) shows the actor was **not
stalled — it was disengaged**:

```
ooze (12,-22)   player (-12,-22)   separation 24.00
detection_radius 10.00   leash_radius 18.00
*** SEPARATION EXCEEDS LEASH: this actor DISENGAGES
```

`debug_set_ai_active` forced it active, and the leash check on the very next tick sent it
straight back to idle. **The zero movement was an idle enemy, exactly the trap this project has
now sprung three times** (the first Ooze recon, case C of the moving-target harness, and now
this). The tool prints `ai_state`, separation and leash up front so the fixture cannot lie again.

**WHAT SURVIVES THE CORRECTION:** `_select_avoidance_waypoint` genuinely returns NONE across the
hall void -- that is a real vocabulary finding, measured directly rather than inferred from
movement, and it stands.

**WHAT DOES NOT:** the claim that the shipped selector paralyses an engaged Ooze in the hall.
No engaged actor was ever measured there.

### AND THE GEOMETRY SAYS THAT CASE CANNOT ARISE
The hall void spans x(-8, 8). An Ooze in the east arm and a player across the void are therefore
**at least ~20 units apart**, against a detection radius of 10 and a leash of 18. **A
void-crossing pursuit is unreachable for this enemy on this floor** -- it disengages long before
the geometry could block it.

So the hall-void case is NOT the human stall, and cardinal pursuit cannot be graded against it.
The reported symptom was an Ooze that "would not proceed farther despite facing/following the
player", which describes an ENGAGED actor -- a state the fixture never produced.

**THE STALL LOCATION IS THEREFORE STILL UNIDENTIFIED.** No screenshot reached this session. The
honest next step is to obtain the actual location rather than to keep reconstructing candidates:
a stall inside 10 units has a different cause than anything measured so far, and guessing again
would repeat the error above.

**CARDINAL PURSUIT IS IMPLEMENTED AND GREEN**, and its mechanism tests pass on constructed
geometry -- but it is NOT yet demonstrated against the human's actual stall, because that stall
has not been located.

### MODEL B, SIMULATED ON THAT EXACT STATE

| policy | result |
|---|---|
| per-step axis re-pick | **gave up after 81 switches**, gap 10.61 |
| **axis-committed** | **ARRIVED after 4 switches, 148 steps** |

Four legs. Literally south-then-west. On the geometry where the shipped model moves 0.00.

**AND THE CRITICAL FINDING: cardinal grammar is NOT oscillation-immune by construction.** That
hypothesis was worth holding and it is FALSE -- measured twice. A naive cardinal policy flapped
one step onto the free axis, re-read itself as aligned, switched back into the wall, and looped:
the same two-state oscillation P33 already fixed, wearing cardinal clothing. **Immunity comes
from COMMITMENT, not from cardinality.** So the oscillation regression must survive translation,
and "by construction" earns a test rather than a claim.

### COMPONENT LEDGER — what B keeps, adapts, retires
**KEPT, unchanged:**
- body-aware legality (`fits` / `clamp_step`) -- every cardinal leg still clamps
- `_AVOID_ARRIVAL_TOLERANCE` -- "aligned on this axis" needs exactly that tolerance, same constant
- deadline bounding -- a cardinal leg still needs a bounded life
- determinism discipline -- axis, direction and tie order all deterministic, no RNG
- the aperture FACT (`_connections` + `_connection_open`) -- consumed as *which opening does my
  blocked axis route through*, still single-source, still refusing closed gates
- territory semantics, detection-governed pursuit, disengaged return -- untouched
- **the committed-leg law itself** -- a cardinal leg IS a commitment; the measurement above is
  what proves that law is the load-bearing part rather than the candidate shape

**ADAPTED:**
- candidate vocabulary: perpendicular offsets + aperture points -> axis choice (X/Z) + direction
- exit conditions: reached / deadline / leg_invalid -> **aligned-on-axis** / blocked / deadline /
  target invalid
- the oscillation regression: re-expressed against AXIS FLAPPING rather than waypoint churn --
  and it must stay red-able, per the measurement above

**RETIRED:**
- perpendicular offset generation (the sideways-only vocabulary that scored 0 advancing legs)
- shortest-total-route ranking (nothing left to rank once the choice is an axis)
- open: whether a waypoint POINT survives at all, or a leg becomes (axis, direction) -- an
  implementation choice, not a design fork

### SCOPE — per-family authored policy, not a universal rewrite
Cardinal is an **Ooze** answer. The movement seam is shared, so the policy must be **authored in
content, not branched in code**: a stats field selecting the family's steering grammar.

This is not a workaround -- it is GAME-RULES §3 channel law, which already says FAMILIES own
BASELINE MOTION PATH. Fang keeps its current language (lunge and burrow were built on committed
displacement, and its authored approach weave is a validated family identity that cardinal legs
would destroy); Watcher unchanged.

### THE THREE MODELS
**A. current aperture/perpendicular committed legs.** To remove the remaining zig-zag AND the
stall it would need another candidate class for patch-overlap openings -- a third vocabulary
bolted on because the second had a blind spot. **Not recommended.**
**B. cardinal committed pursuit.** Solves the stall in 4 legs, matches the stated preference,
retires more machinery than it adds. **Recommended.**
**C. multi-waypoint routing.** Still not earned: B walks this route with no planning at all.

### GATE
Open-roundabout authoring, Floor 2 and the generator all stay held.

## APERTURE-AWARE CANDIDATES — **BUILT 2026-08-31.** Closure restored, commitment kept.

### AUDIT FIRST: no design fork
`_connections` (aperture geometry) + `_connection_open` (gate state) already own "where is the
traversable opening", including open/closed. Route-finding **consumes** that fact; it builds no
private copy and never touches presentation meshes -- the same single-source rule P34 set for
walls. Nothing new was authored, and no new state was added.

### RE-CERTIFICATION, same strafing case, same geometry

| | perpendicular only | **with apertures** |
|---|---|---|
| commits | 11 | **4** |
| legs that ADVANCE toward the target | **0 of 11** | **3 of 4** |
| mean commitment | 34.9 t | **39.8 t** |
| `route_clear` exits | 0 | **0** |
| final gap | 6.04 | **2.08** |

Closure is restored to the pre-B churning model's level (~2.05) **while keeping everything B
won**: no mid-leg `route_clear`, ~40-tick commitments, purposeful straight legs.

Leg trace, with apertures: `(-1.05,-49.5)` ADVANCES, same again ADVANCES, one sideways,
`(1.05,-43.0)` ADVANCES to within 1.10 of the target. Against perpendicular-only, where all
eleven legs were sideways.

**RATCHET TIGHTENED 7.0 -> 3.0**, as it was written to be. It is not a knob: loosening it again
means the mechanism regressed.

### THREE IMPLEMENTATION ERRORS, each found by measurement rather than reasoning
1. **Target-side point only.** The first version clamped only the target into the aperture. When
   the target already stands *inside* the opening that returns the target's own position, whose
   leg IS the blocked direct line -- so no aperture candidate ever qualified and the class did
   nothing. Fixed by offering the point nearest the ACTOR as well.
2. **Insetting both axes.** An aperture deliberately OVERLAPS the spaces it joins, so insetting
   its long axis pushed the entry point deep inside the corridor, unreachable in a straight line
   from beside the mouth. Only the WIDTH must clear the body; `region.fits()` judges the rest
   against the real union.
3. **A fixture that did not match the shipped floor.** The strafing test registered the neck as a
   patch but never as the CONNECTION it actually is on Floor 1, so it measured a floor where the
   sim had never been told a doorway existed.

### ONE TEST REFINED RATHER THAN SATISFIED
`test_successive_waypoints_are_never_near_identical` began failing on `(-1.05,-49.5)` twice --
but that is an actor walking a full 40-tick leg toward the correct doorway, running its deadline,
and re-committing to that same doorway while advancing 8.57 -> 7.77. **Near-identity alone is not
the defect; near-identity IN RAPID SUCCESSION is**, which is what the live log showed. The test
now pins the pair. Weakening it to pass would have hidden the real signature.

### SCENARIO 4 / OPTION C
Still gated, and now honestly gateable: committed-leg routing finally has an adequate candidate
vocabulary, so a surviving failure would mean something. Re-cost after the open-roundabout
authoring, against real revised geometry -- not against the perpendicular-only generator that
made a generator weakness look like leg-count insufficiency.

## P33 OPTION B — **BUILT 2026-08-31.** Oscillation removed; a NEW finding took its place.

`route_clear` is no longer an exit. While committed, the **waypoint is the steering target and
the player is only the combat target**, so a direct line opening mid-leg -- the transient the
sidestep itself created -- can no longer close the loop. A leg ends only on: reached, deadline,
or the leg itself becoming physically impossible (`leg_invalid`).

**THE OSCILLATION IS GONE, measured on the strafing load:**

| | before | after |
|---|---|---|
| `route_clear` exits | dominant | **0** |
| commit cycle | every 2-3 ticks | ~40 ticks mean |
| successive waypoints | ~0.08 apart | > 0.5 apart |

### BUT CLOSURE REGRESSED, and the cause is the CANDIDATE GENERATOR
Final gap against a strafing player: **6.04**, where the old churning model reached ~2.05.

Measured cause, not guessed. Across an entire pursuit **every chosen waypoint sat FURTHER from
the target than the actor already stood**:

```
t  0  wp_to_target 9.64   gap_now 8.60
t 45  wp_to_target 9.50   gap_now 9.39
t 70  wp_to_target 9.90   gap_now 8.89
...  eleven legs, every one of them
```

Perpendicular offsets can only step SIDEWAYS; nothing in that generator can express *advance
through the gap*. Short legs hid it -- the actor re-chose before the waste showed. Long legs turn
it into a slow sideways shuffle: **the same defect wearing a calmer face**, and plausibly worse
to watch than the zig-zag it replaced.

**SHORTEST-TOTAL-ROUTE RANKING WAS TRIED AND REVERTED.** It changed nothing: every candidate sits
the same `offset` from the actor and barely alters distance-to-target, so minimising
|from -> wp| + |wp -> target| still lands sideways. That result is what IDENTIFIES the generator
rather than the ranking as the constraint -- and it is why no ranking over these candidates can
fix it. Candidate generation and ordering are therefore left exactly as ruled.

### THIS IS THE SCENARIO-4 CAVEAT ARRIVING EARLY
The recon flagged that *a candidate-generator limit and a leg-count limit look identical from
outside*. That was recorded as a caveat about the hall ring. It is now the live constraint in
ORDINARY FIGHT-SPACE GEOMETRY, which means the distinction the C-trigger depends on is no longer
hypothetical: **C's trigger must not be evaluated against this generator**, or a generator
weakness will be mistaken for proof that multi-leg routing is required.

### RATCHET, NOT ACCEPTANCE
`test_a_strafing_player_is_not_lost_entirely` bounds the gap at 7.0 to catch regression while the
design question is open. **It must be tightened when the generator is answered, never loosened.**

### THE OPEN QUESTION, for ruling
Committed legs are correct and the oscillation is genuinely dead. What remains is that the
generator proposes only sidesteps. Options, none taken:
1. **Aperture-aware candidates** -- propose points at gap/threshold mouths, so "go through the
   doorway" becomes expressible. Smallest change that could restore closure.
2. **Accept the standoff** -- a slow blob that keeps station but rarely corners a strafing player
   may be acceptable enemy character rather than a defect.
3. **Re-sequence** -- apply Floor 1 authoring first and re-measure; different geometry may not
   provoke it.

## P33 REOPENED — ZIG-ZAG REJECTED BY PLAY. Navigation recon returned 2026-08-31. NO CODE.

**Human verdict on `ec82254`:** *"The zig zag to get to you is bad."* and *"I wouldn't even mind
just moving in straight lines to get to where it wants to go."*

Not classified acceptable on telemetry: reaching attack range, positive progress and internally
correct detector/commit/clear traces are all true and all beside the point. The player-facing
result fails.

### THE MECHANISM (from the live log, recovered before it was discarded)
```
COMMIT (12.50, -16.31) deadline 186942   CLEAR route_clear
COMMIT (12.49, -16.23) deadline 186944   CLEAR route_clear
COMMIT (12.49, -16.11) deadline 186947   CLEAR route_clear
COMMIT (12.47, -16.03) deadline 186949   CLEAR route_clear
```
Deadlines 2-3 ticks apart, waypoints 0.08 apart. **A two-state oscillation with no hysteresis:**
sidestepping is exactly what makes the direct line look clear, and taking the direct line is
exactly what re-obstructs it. Every individual decision is correct; the loop between them is not
forbidden anywhere, because each half was validated against a stationary target where it never
closes.

### HOW MANY COMMITTED LEGS DOES THE REAL GEOMETRY NEED?
`tools/cost_navigation_models.gd`, Floor 1 values, deterministic candidates:

| scenario | result |
|---|---|
| 1 stationary, across the arena | **DIRECT** |
| 2 player around one corner (arena -> neck) | **1 leg** |
| 3 strafing player | **1 leg** |
| 3b strafed to the far side | **1 leg** |
| 5 disengaged return, neck -> arena | **1 leg** |
| 4 TOP-OF-SQUARE, west arm -> east arm across the hall void | **no route within 2 legs** |

**Every fight-space case is one leg or none.** The only failure is the hall ring.

### RECOMMENDATION: **B — committed straight-leg waypoint navigation**
Smallest design that meets the bar. Direct when clear; one deterministic intermediate point when
blocked; straight line to it; **player motion alone never cancels a valid leg**; reassess only on
arrival, physical invalidation, target invalidation, or bounded failure.

The change that kills the oscillation is one rule: **while committed, the WAYPOINT is the
steering target and the player is only the combat target.** `route_clear` stops being an exit
condition mid-leg -- which is precisely the transition producing the 2-3 tick cycle.

Reuses the existing detector, candidate generation, ordering, tie rule, deadline and arrival
tolerance. Return home differs only in destination; no second implementation.

### WHY NOT A (hysteresis on the current model)
It still re-steers continuously against a moving target -- it would slow the oscillation, not
remove it, and it adds a tuning knob to disguise a structural loop. Rejected on the ruling's own
terms.

### WHY NOT C YET, AND THE HONEST CAVEAT
C is not needed for any fight-space case measured. **But scenario 4 is now REACHABLE because of
the detection-governed pursuit ruling** -- an ambient Ooze in the east arm may chase across the
hall, and B will grind at the void edge exactly as before.

By inspection that route is *up the arm, along the strip, down the far arm* -- **two intermediate
points**, which B cannot express and my two-leg search with perpendicular-plus-rect-centre
candidates did not find. **A CANDIDATE-GENERATOR LIMIT AND A LEG-COUNT LIMIT LOOK IDENTICAL FROM
OUTSIDE**, and this recon cannot fully separate them; that distinction should be settled before
C is built, not assumed.

**A cheaper answer may already be queued:** the open-roundabout authoring item removes
unnecessary walls from that same hall. If the roundabout no longer wraps a void, scenario 4 stops
existing and C stays unbuilt. **Recommend B now, and let Floor 1 authoring decide whether C is
ever earned.**

## AMBIENT PURSUIT IS **DETECTION-GOVERNED** (ruled 2026-08-31 after play). Leash-hold deleted.

Human play judged the v1 home-edge hold visibly artificial. Ruled: **territory does not limit
active pursuit.** While engagement holds, an ambient enemy chases anywhere physically legal.

**Territory keeps exactly three jobs:** authored spawn/home context - acquisition association -
the destination it walks back to **once disengaged**. Nothing else.

Hard physical law is untouched: floor, WALL, closed gate and sealed encounter all still bind.
**KITING IS AN ACCEPTED CONSEQUENCE** at this floor scale, recorded as a decision rather than
tolerated silently. No speculative anti-kite constraint was added. If larger floors make it
undesirable, that is a new evidenced question, never a reason to restore an invisible boundary.

**BUMP FINDING CLOSED.** Human replay confirmed the bump crosses the former invisible edge, the
actor stays engaged while in range, and it returns once engagement ends.

**THREE TESTS WERE INVERTED, deliberately and individually** -- each had encoded the leash law:
`test_an_ambient_actor_will_not_voluntarily_chase_out_of_home` (now asserts it DOES chase out,
plus a new explicit kiting test so the accepted consequence is pinned rather than implied),
`..._stays_in_its_territory` in the grammar suite (now asserts physical legality still binds),
and `test_avoidance_cannot_leave_its_territory` (now pins a SEALED encounter, the confinement
that genuinely outranks avoidance).

## MOVING-TARGET PURSUIT + RETURN CORNER — INSTRUMENTED 2026-08-31. **Two different answers.**

`tools/diagnose_moving_target_pursuit.gd`, same shipped geometry, three loads:

| | detector | commits | mean commit | realigns | net progress | final gap |
|---|---|---|---|---|---|---|
| A stationary (validated P33 load) | 76/400 | 2 | 37.5 t | 3 | +6.43 u | 2.17 |
| B moving player (observed load) | 177/400 | 10 (4 immediate re-entry) | 17.3 t | **22** | +5.44 u | 2.05 |
| C return home, disengaged | 10/400 | 1 | 10.0 t | 1 | +4.53 u | **0.20** |

### ZIGZAG — **APPEARANCE, not mechanism. Returned as a DESIGN FINDING, unfixed.**
Case B realigns 7x more often than A and holds commitments half as long, but **it still arrives**
(+5.44 u, final gap 2.05, inside attack range). The mechanism is succeeding.

The cause is target motion, not a selector defect: a strafing player repeatedly changes whether
the direct line is obstructed, so `route_clear` fires 7 times and avoidance re-enters immediately
4 times. Commitment behaves exactly as specified -- **the world keeps invalidating its premise.**
P33 was validated entirely against a stationary target, so this load was never exercised.

**NO smoothing, hysteresis or selector change applied**, per ruling: a mechanism that is
mathematically right but reads as indecision is a design question, not a tuning job.

### CORRECTION 2026-08-31 — the LIVE zigzag signature does NOT match my reproduction.

The ruling session's own log (build `215e635`) was recovered before it was discarded, and it
shows a tighter and different cycle than case B did. **My "appearance, not mechanism" conclusion
was drawn from a reproduction whose signature does not match live play, and I am withdrawing it.**

Consecutive commit/clear pairs from the real session, one ambient Ooze:

```
COMMIT waypoint (12.50, -16.31)  deadline 186942
CLEAR  route_clear
COMMIT waypoint (12.49, -16.23)  deadline 186944
CLEAR  route_clear
COMMIT waypoint (12.49, -16.11)  deadline 186947
CLEAR  route_clear
COMMIT waypoint (12.47, -16.03)  deadline 186949
CLEAR  route_clear
COMMIT waypoint (12.45, -15.95)  deadline 186951
```

**Deadlines 2-3 ticks apart. Waypoints ~0.08 apart. `route_clear` every time.**

| | my case B | live session |
|---|---|---|
| mean commitment | 17.3 ticks | **2-3 ticks** |
| dominant exit | route_clear (7 of 10) | route_clear, but immediately |
| character | occasional re-planning | **sustained oscillation** |

### THE MECHANISM, now identified
A two-state oscillation with no hysteresis between them:

1. direct line to the player is obstructed -> commit to a sidestep
2. the actor steps aside; from the new position the direct line **genuinely clears** ->
   `route_clear` fires, correctly
3. it turns back toward the player, which walks straight back into the obstruction
4. commit again -- 2 ticks after the last one

**Every individual decision is correct.** The detector is right, the selector is right, the exit
is right. The defect is that steps 2 and 3 form a cycle: sidestepping is exactly what makes the
direct route look clear, and taking the direct route is exactly what re-obstructs it. Nothing in
the design forbids that loop, because each half was validated separately against a stationary
target where it never closes.

This is a MECHANISM finding, not an appearance one. It is the shape a player reads as "following
without approaching".

### WHAT IS STILL UNKNOWN
This log is from `215e635`, which still had the leash-hold. The hold could return a ZERO heading
while a commitment was live, so it may have contributed. `ec82254` deleted it, and my post-fix
case B measured a 17.3-tick mean commitment rather than 2-3.

**So the honest position is: the mechanism is identified, but whether it survives on the current
build is unmeasured.** Re-observation on `ec82254` should come before any fix is designed --
otherwise a hysteresis knob may be built for a loop that the pursuit ruling already broke.

**Still no smoothing, hysteresis or selector change applied.**

### RETURN CORNER — **not reproducible after the ruling; likely deleted by it.**
Case C returns cleanly: 1 commit, +4.53 u, final gap 0.20. It gets home.

**The likely explanation is that the ruling removed the cause.** The symptom was observed on
`215e635`, where an engaged actor outside home steered *home* while the player kept it engaged
near the corner -- home-ward and player-ward pulling against each other at a jamb. Under
detection-governed pursuit that state no longer exists: engaged means chase, disengaged means
return, never both. **This wants confirmation in play rather than being declared fixed.**

### A HARNESS ERROR WORTH KEEPING
Case C first ran with 40-unit detection and reported **negative** progress, which looked exactly
like a broken return and was in fact correct pursuit: the actor had acquired the player 21 units
away and was chasing it. Same trap as the earlier idle-Ooze reading. The tool now prints
`ai_state`, so a case that measures the wrong mechanism says so.

## TERRITORY SPLIT — **BUILT 2026-08-31.** Behavioural leash separated from physical legality.

The wedged-Ooze cause, fixed at its root. `_legal_bounds_for` now answers ONE question --
*where is this body physically forbidden to leave* -- and ambient territory no longer
participates in it.

| source | voluntary | forced displacement |
|---|---|---|
| floor / WALL / closed connection | cannot cross | **hard stop** |
| hard encounter seal | cannot cross | **hard stop** |
| ambient home territory | will not leave | **MAY cross if floor-legal; returns** |

**ONE GEOMETRY, TWO DOORS.** `_legal_bounds_for` and `_home_territory` both read
`_encounter_bounds`; neither duplicates it. Behaviour and legality consult the same authored
fact through different semantics -- which is the structural point, not an accident.

**NO NEW RETAINED STATE, verified rather than asserted.** `outside_home` is derived from
position each tick; resumption likewise. The diff adds zero `var` declarations and touches zero
STATE_SCOPES rows -- checked mechanically, so the scanner's silence is a RESULT.

**GUARDED CONSERVATISM, made executable.** Hard confinement currently keys on role, which is
sufficient only because every non-ambient roster in shipped content is deferred or dead.
`test_no_shipped_encounter_spawns_a_non_ambient_roster_at_floor_load` is the mechanical revisit
trigger: the day `FLOOR_LOAD + non-ambient` is authored, a roster is present and hittable before
its fight seals, role stops being a sufficient proxy, and activation/seal state must become
authoritative. The test names the function to change when it fails.

**V1 LIMITATION, RECORDED NOT DRESSED UP.** At the leash edge the actor tries two
axis-preserving slides and otherwise HOLDS. It is not tactical repositioning and must not grow
into one to prettify the boundary; if holding reads badly in play, that is evidence for a
ruling, not licence.

**ONE PRE-EXISTING LAW DELIBERATELY OVERTURNED.**
`test_territory_binds_knockback_not_only_locomotion` asserted that an AMBIENT territory binds
knockback. That is exactly the law the evidence falsified. It was rewritten as
`test_a_hard_seal_binds_knockback_not_only_locomotion`, preserving the original intent -- forced
displacement is not exempt from confinement -- against the confinement that is genuinely hard.
The ambient half moved to `test_territory_semantics.gd`, where it now asserts the opposite.

**P33 REUSED, NOT DUPLICATED.** Return feeds the home point into the same detector, selector,
commitment, arrival tolerance and clamp. No second navigation system, no new stored side.

## WEDGED-OOZE REPRODUCTION 2026-08-31 — **APERTURE WIDTH IS NOT THE CAUSE. DO NOT WIDEN.**

Reproduced before changing anything (`tools/diagnose_wedged_ooze.gd`). The four-way contradiction
resolves cleanly, and none of the pre-routed causes was the real one.

**MEASURED:**
- every aperture: authored width 5.00, **legal centre band 2.08** for a 1.45-radius body. Passable
  with room to spare. The clearance validator was right.
- jamb-hugging probe at all five mouths: **free** in all three directions. No corner trap exists.
- **the ambient Ooze's territory is x in [8, 16].** Its westernmost legal centre is **x = 9.45**
  (territory edge 8.0 + body radius 1.45). The nearest hall aperture mouth is x in [-2.5, 2.5] --
  **6.95 units beyond anywhere it may legally stand.**

**THE OOZE CANNOT REACH A HALL OPENING AT ALL, SO IT CANNOT BE WEDGED IN ONE.** What it does is
stop dead at x = 9.45 -- and a shield bump shoving it west against that limit is exactly the
event that makes the stop vivid.

**THE ACTUAL DEFECT IS THAT THE BOUNDARY IS INVISIBLE.** The territory edge at x = 8 runs through
the MIDDLE of the hall strips, which are walkable floor from x = -16 to x = 16 with no wall
anywhere near it. So a player sees an enemy halt in open ground for no visible reason. "Stuck in
the gap" is the only available reading; there is nothing on screen offering another.

Its territory is convex (guarded by test), so genuine wedging is geometrically impossible: from
any legal point a body can always move. Nothing is stuck. It is BOUNDED, invisibly.

**A DESIGN LAW IS AVAILABLE HERE, not yet ruled:**
> *An enemy's confinement boundary must coincide with something the player can see.* Territory
> that ends in open floor cannot be read as territory -- only as a bug.

**OPTIONS, none applied:**
1. **Author the territory to visible geometry** -- make the east arm's mouth the boundary, so the
   Ooze stops where a wall or floor change explains it. Authoring only; convexity preserved.
2. **Accept and signal it** -- keep the region, add a presentation cue (surface change at the
   arm's mouth). Also authoring only, and it composes with the open-roundabout idea below.
3. **Widen the territory to the whole hall ring** -- REJECTED on existing evidence: it breaks the
   P33 ambient-convexity constraint and reinstates the corner-rubbing this same Ooze produced.

**NOT DONE:** no aperture widened, no body resized, no validator changed, no territory
re-authored. The pre-routed "widen modestly" branch is explicitly NOT taken, because the measured
cause is not width.

## M2 REPLAY CLOSE — FLOOR GRAMMAR STAYS **PASS**. 2026-08-29.

Replayed `af85f3f` unchanged, one clean run to FLOOR COMPLETE with zero errors and zero
warnings. Every beat fired once, in order.

### Human findings, verbatim
- hidden plate interaction **feels good**;
- hidden plate should be **smaller / less prominent** than the party plate;
- open ledges **look fine**;
- **no E is needed for this floor grammar**; walking over authored controls feels good;
- Ooze **still struggles to follow cleanly around the wall/corner**.

### NO-E — recorded as a PROTOTYPE FINDING, not a law
> Occupancy-driven floor interactions feel natural here; no E is needed for this floor grammar.

This is NOT a permanent law against deliberate-interaction consumers. `interact` stays retired
until a concrete consumer genuinely requires a press (see the amended scope above).

### HIDDEN PLATE — presentation, and footprint, both quieter
Mechanics unchanged; no new mechanic distinguishes the two plates. The hidden plate is now
2.0 x 2.0 (was 3.2), cooler-coloured, thinner and dimmer; commitment plates stay bold and warm.
Prominence is READ from the authored trigger kind rather than authored twice.
**The mesh remains exactly the trigger region** -- shrinking the picture without the footprint
would make a plate fire from ground that does not look like a plate.

### THE TWO REMAINING FOUNDATIONS before the grammar scales up
1. **P33** obstacle navigation (recon below)
2. **P34** projectile-vs-world (approved direction, open questions still to close)

Procedural floor scaling waits on both: larger and folded layouts would only multiply whatever
these leave broken.

## P33 — OBSTACLE NAVIGATION · RECON RETURNED 2026-08-29. **NO IMPLEMENTATION.**

### CLASSIFICATION CORRECTION (recorded before anything else)
**The territory-union simplification is NOT falsified, and must not be unwound.** It held as
scoped: it preserved confinement, removed the accidental one-patch boundary behaviour, and kept
the Ooze inside its intended authored area. It was never a navigation mechanism and never
claimed to be.

The surviving symptom is a DIFFERENT and already-known thing -- straight-line steering has no
way around an obstruction -- previously carried as a deferred limitation. **The second live
sighting graduates it from deferred limitation to ACTIVE DESIGN REQUIREMENT.**

### DETECTOR FIRST — VALIDATED 7/7 (`tools/diagnose_obstruction_detector.gd`)
The scurry lesson applied: the trigger is validated on the real failing geometry BEFORE any
behaviour is designed on it. The detector question, exactly as ruled: *is my intended direct
movement toward the target obstructed by authoritative floor geometry?*

| case | required | result |
|---|---|---|
| LITERAL corner (arena -> neck, off-axis) | FIRE | blocked after 0.72 u |
| DIAGONAL into the neck | FIRE | blocked after 2.17 u |
| NEAR-TANGENT grazing the west jamb | FIRE | blocked after 1.45 u |
| CONTROL clear line across the open arena | quiet | clear |
| CONTROL straight up the middle of the neck | quiet | clear |
| HORIZON same corner 23 u away | quiet | clear |
| CONTROL inside the convex ambient column | quiet | clear |

**The first authoring of these cases was WRONG and the tool caught it.** Two "literal" cases sat
23 u away with a 12 u lookahead, so the detector correctly said *clear* and I had a red result
that was really a mis-authored test. Lookahead is now tied to `detection_radius` (10.0) rather
than picked -- an actor that only pursues what it can detect has no business reasoning past it --
and the cases sit where rubbing actually happens: AT the obstruction. The horizon case is now
asserted deliberately, so "quiet beyond lookahead" is recorded as designed, not as a miss.

Sampling steps at half the body radius, so a body cannot tunnel through a gap narrower than
itself. Pure sim geometry -- no physics query, no raycast, no navmesh, anywhere.

### THE SIX QUESTIONS, ANSWERED
Measured at the literal corner, driving `WalkableBounds.clamp_step` directly (the authoritative
displacement seam locomotion itself calls), 180 ticks:

1. **Where is the Envoy relative to the blocking wall?** Up the 5-wide neck between the arena
   and the approach, with the arena's north jamb between it and the pursuer. This geometry is
   the MANDATORY encounter's territory -- and note that the ambient-convexity constraint does
   not cover it, deliberately: the party-plate beat REQUIRES the seal to span approach +
   corridor + arena, so "just make it convex too" is not available here as it was for ambient.
2. **What does it request each tick?** Straight at the target, every single tick. Pursuit never
   stops asking for the blocked vector.
3. **What does legality permit?** **133 of 180 ticks lost more than half the step.** Per-tick
   motion decays 0.0500 -> 0.0252 -> 0.0196 -> **0.0047** as the approach angle turns into the
   jamb. It travels 2.11 u in six seconds and is asymptotically stalling, pinned at z = -49.45,
   which is exactly the arena edge (-48.0) minus the body radius (1.45).
4. **Can the actor prove the route is obstructed from sim geometry alone?** **YES** -- the
   detector above does exactly that, deterministically, with no engine involvement.
5. **Is there a legal local route around it inside the territory?** **YES, and it is
   asymmetric**: a right sidestep of 4.35 u perpendicular yields a legal two-leg route; the left
   side finds nothing within 16 u. Asymmetry matters -- it means the choice is usually forced by
   geometry rather than by a tie rule, but the tie rule must still exist.
6. **What minimal retained state is needed?** **Three fields, per actor, floor-scoped**: the
   committed waypoint, the side chosen, and a re-evaluation deadline. Without commitment a
   sidestep is just rubbing with extra steps -- the moment the waypoint stops being the nearest
   improvement, direct pursuit re-requests the blocked vector.

### THE THREE OPTIONS, COSTED

**A. Keep direct steering + wall slide.** Cost zero. **REJECTED by its own measurement**: it IS
the observed behaviour (133/180 ticks lost, decaying to 0.0047 u/tick). Recorded so the baseline
is a number rather than an impression.

**B. NARROW DETERMINISTIC LOCAL AVOIDANCE — RECOMMENDED.**
Shape, and no larger: detect the blocked direct route (validated detector) -> probe perpendicular
offsets outward in a fixed ascending sequence, first legal two-leg waypoint wins -> COMMIT to it
-> re-evaluate on arrival, on the direct line clearing, on the waypoint becoming illegal, or on a
commit deadline.
- **Determinism:** offsets ascend in fixed increments of half a body radius; both sides are
  probed at each offset; if both are legal at the same offset the tie breaks on distance to
  target, then on an authored side preference. No RNG, no engine query, no iteration-order
  dependence, no neighbour sampling. Same sim state -> same route, which is what M3 needs.
- **Blast radius:** ONE seam -- the AI's chosen movement vector. `_clamp_to_bounds`,
  `WalkableBounds` and the combat pipeline are all untouched.
- **Cost:** roughly 75 lines of sim plus 3 STATE_SCOPES entries, and a test file carrying the
  seven detector cases plus commitment, re-evaluation, the tie rule, determinism (same state ->
  same route twice) and a clear-line no-regression control.
- **Serves the current floors?** Yes -- the probe shows ONE waypoint clears the only concave
  territory that exists.

**C. FULL PATHFINDING.** Godot NavMesh/NavigationAgent is **rejected outright**: it would put
gameplay authority outside SimWorld, which breaks Prime Directive 1 and cannot be replicated by
the M3 driver. A sim-side A* over the rect-overlap graph is buildable -- roughly 150 lines
(graph, search, path-following, replanning) plus stable node ordering and cost/id tie-breaks --
but it is a framework with ONE consumer, which §1.4 forbids until there are two.
**Its honest trigger condition:** a floor that needs MORE THAN ONE TURN. That is not
hypothetical -- the earlier ambient-ring probe found no single-waypoint route around the void,
needing two. Today that case is excluded by the ambient-convexity constraint, so B suffices; the
day an authored territory legitimately needs two turns, B stops being enough and C is earned.

### RECOMMENDATION
**Option B**, on the already-validated detector, with C's trigger condition written down so the
upgrade is a recognised event rather than a discovery. Nothing implemented pending your choice.

## M2 INTERACTION RULINGS BUILT + TWO RECONS RETURNED — 2026-08-29. Suite 603 -> 608.

### HIDDEN CONTROL, AND THE RETIREMENT OF `interact`
Breaking the crate no longer reveals a switch; it ENABLES a dormant PLATE (`FloorTrigger.
starts_enabled`, `EFFECT_ENABLE_TRIGGER`). Stepping onto that plate opens the route. A dormant
trigger is skipped ENTIRELY rather than evaluated-and-ignored, so it banks no occupancy edge
while it waits -- which is what makes a plate revealed under an Envoy already standing there
still fire.

**SWITCH RETIRED, AND EVERYTHING THAT ONLY IT USED.** The audit the ruling asked for found the
hidden switch was the last authored interactable, so `switch` became a zero-consumer kind --
and with it `InteractablePlan`, `TRIGGER_INTERACTED`, `EFFECT_REVEAL_INTERACTABLE`,
`use_radius`, the `interact` Command, its sim handler and the E binding. All retired together.
**The floor now has no `interact` verb at all. Every control is something you stand on.**

### SCOPE OF THAT RETIREMENT — AMENDED 2026-08-29 (Breon), read this before citing it
The retirement is a statement about CONSUMERS, not a verdict on the verb. The recorded law is
exactly:

> **No active floor-grammar consumer currently uses `interact`. Do not restore the machinery
> until a concrete deliberate-action consumer requires it.**

The evidence only ever supported that. It does NOT support "deliberate interaction is rejected",
and this file must not be cited as though it did. Plausible future M2 consumers where accidental
proximity activation would be actively WRONG: loadout/gear stations, elevators, rest-floor
controls, and other authored objects a player must choose to operate. When one of those arrives,
reintroduce **only the narrow surface it requires** -- not the retired schema wholesale.

The prototype-floor assertions (`test_no_authored_control_requires_a_press`, and the golden
fixture's `interacted` check) are scoped to THIS authored plan and to the committed fixture, so
they describe today's floor rather than legislating every future one. That scoping is deliberate
and must survive any rewrite of them.

### ONE SHARED GROUP-OCCUPANCY CONDITION
`SimWorld.all_active_envoys_occupy(region)` -- ALL_ACTIVE_ENVOYS_OCCUPY_REGION -- extracted
because it now has TWO concrete consumers. Every living member of the active expedition,
simultaneously, anchor position, inclusive predicate, FALSE -> TRUE edge only. The denominator
is `_run_persistent_actors` (the expedition), never an authored count and never "whoever is in
the room", so a subset can never commit the party. Solo resolves to one with no special case;
M3 changes that roster's membership without touching the condition.

Effects stay authored separately -- the whole point of extracting the CONDITION and not the
consequence:
- **party plate** -> seal rear · open forward · activate roster · begin encounter
- **exit plate**  -> `complete_floor`

### THE FLOOR EXIT IS A CONDITION, NOT A PILLAR
Progression is gated on the whole expedition standing on the final space. `floor_complete` is a
FLOOR-scoped fact plus one Event, and nothing more: there is no next floor to descend to, and
faking one to give the flag somewhere to go would be building a system to satisfy a test.

### RECON 1 RETURNED — OOZE CORNER-RUBBING. **EXPECTED CAUSE CONFIRMED.**
Instrumented on the real floor with `tools/diagnose_ooze_pursuit.gd`.

**A first pass measured nothing and looked like a finding.** With the player 24 units away the
Ooze sat perfectly still for 240 ticks -- which reads exactly like being stuck and was actually
an IDLE enemy outside its 10-unit detection radius. The tool now prints separation, detection
radius and `ai_state` so a zero can never be mistaken for a stall again (the repo's own trap:
confirm the mechanism fired before believing a zero).

With the player at 9.22 units, across the void:
- **Q1/Q2** requested direction is straight at the player every tick; the per-axis clamp grants
  only the unblocked component. Free approach down its own arm, then contact.
- **Q3** the straight line is BLOCKED at t=0.43 -- it crosses ground nobody laid.
- **Q4 contact phase: 80 of 80 ticks lost to legality, for 0.916 units of progress.** It is NOT
  stuck -- it grinds forward and would round the corner -- but it reads as sluggish scraping.
- **Q5** a route exists (the trace walks one); the coarse waypoint probe cannot describe it.

**DISPOSITION: direct steering vs obstacle. Not a bounds defect.** Applied as the ruled v1
AUTHORING CONSTRAINT: an ambient territory's walkable union must EQUAL ITS OWN BOUNDING BOX.
A solid rectangle is convex, so no pursuit inside one ever needs routing. The east Ooze's
territory is now the single convex column `Rect2(8, -34, 8, 22)` -- the east arm plus its
junction with both strips -- so it still meets anyone crossing its ground and reads as guarding
its arm. **Guarded by test, and the guard was proved to fail**: re-injecting the void-wrapping
territory turns it red with the void's own coordinates. Obstacle-aware navigation is **P33**,
for a floor that genuinely needs a territory that wraps something.

Nothing was weakened, shrunk, widened or tuned to get here.

### RECON 2 RETURNED — PROJECTILE-VS-WORLD (**P34 · DESIGN ONLY, NO CODE**)
See the P34 pre-code design below. The swept-collision core is UNTOUCHED pending review.

## M2 FLOOR GRAMMAR — RULED CORRECTIONS BUILT 2026-08-29. Suite 582 -> 603.

Breon's rulings on the human-play findings above, as built. **The frozen floor-grammar verdict
remains UNRENDERED** — none of this stamps it.

### RULING 1 — BODY EXTENT IS PART OF AUTHORITATIVE LEGALITY
`WalkableBounds.fits(point, radius)` is now the legality predicate: a position is legal only
when the actor's body footprint lies inside the walkable UNION. `combat_radius` is the radius,
because it is already the sim's one physical-body notion (Burn contact-spread, projectile
sweep) — legality reads the same number rather than inventing a second footprint.

**THE UNION IS TESTED AS A UNION.** Shrinking each rect by the radius independently is the
obvious implementation and would have broken the floor: an actor in a doorway straddles a patch
and an aperture and fits NEITHER alone. `fits` subtracts the whole union from the body's
bounding box and asks whether any uncovered remainder actually reaches the body, so
connectivity survives by construction. Two tests fail immediately if anyone "optimises" that
into a per-rect shrink.

Radius 0 degrades to the old point predicate exactly, which is why the pre-M2 suite was
untouched. Body extent entered at the two funnels (`_clamp_to_bounds`, `_point_is_legal_for`),
so **all eight displacement seams inherited it with no call-site change**.

VERIFIED: straight edge · tangency (a body may rest against a wall) · overlapping-aperture
traversal · concave corner · 25-unit knockback · three different authored radii · bodiless
backward-compat · both placement consumers, each with its own refusal mode —
**registration** refuses LOUDLY and abandons the actor (a content defect must be seen);
**burrow emergence** refuses SILENTLY and rotates to its next candidate (retrying is its
authored behaviour). Plus the amendment: two bodies pinned against one wall still QUALIFY as
contact, so body-aware resting positions did not silently break Burn spread or the lunge clamp.

**Authored clearance validator** (narrow, complements the law rather than replacing it): every
roster member must fit inside its own territory, and no aperture may be narrower than the
widest body the floor spawns. No route model and no pathfinding was invented to check it.

### RULING 2 — OCCUPANCY IS NOT BODY LEGALITY
Two different questions, kept apart: bounds ask "does this body FIT here", triggers ask "is this
actor STANDING here". Occupancy uses the anchor position and one shared INCLUSIVE helper
(`WalkableBounds.contains`), so `Rect2.has_point`'s exclusive far edge — the documented trap —
cannot re-enter through a hand-rolled test. A body merely grazing a plate does not stand on it.

**PARTY PLATE.** Occupancy-driven, never an E press. Condition: every living member of the
active expedition standing on the region at once — derived from `_run_persistent_actors`, NOT
an authored count and NOT "whoever is in the room", so a subset can never commit the party.
Solo resolves to one Envoy with no special case, and M3 changes the roster's membership without
touching the condition. Fires on the FALSE -> TRUE edge only. The atomic effect list is
unchanged: seal rear, open forward, activate roster, in one tick.
Small step triggers keep using `TRIGGER_REGION`, which already existed — no new machinery.

### RULING 3 — AMBIENT TERRITORY IS A UNION, NOT ONE PATCH
Confinement kept; the accidental "territory == exactly one WalkablePatch" assumption dropped.
`EncounterSite.regions` is a union, and the east Ooze now inhabits **the east arm plus both hall
strips**. The WEST ARM is pointedly excluded: the branch that solves the floor stays a place you
can work in, which is what makes the branch mean anything. Still confined, still flowing through
`_legal_bounds_for`, still no roaming and no pathfinding.

### WALLS / LEDGES
`WalkablePatch.boundary_style` = `wall` | `ledge`, read only by FloorBuilder. A ledge renders no
vertical boundary; the sim bounds the actor anyway, because legality was never the meshes' job.
The raised platform and endpoint are ledges. No polish beyond proving the distinction holds.

### FINAL MEANINGLESS E — REMOVED
`I_END_SWITCH` and its trigger are gone. The last connection opens from its REAL prerequisite,
the encounter clear, alongside the ramp. **The floor's only remaining interactable is the hidden
switch you have to search for** — the one E that was ever earned. No puzzle was invented to
preserve the press.

### Deliberate golden re-baseline
Two schema fields changed (`boundary_style`, `regions`) and two authored beats changed by
ruling, so the old fixture describes a floor nothing can produce. Reason + date logged in
`tools/record_floor_plan_golden.gd`, hand-inspected before commit. No M1 behaviour baseline was
touched.

### Still out, unchanged
Procedural assembly · branching topology · minimap · elevator · drop economy · throwable ·
general pathfinding · whole-floor roaming · combat tuning.

## M2 FLOOR GRAMMAR — **PASS (Breon, 2026-08-29).** Verdict rendered against the frozen criterion.

> "The floor passes only if it feels like traversing and interacting with a place — seeing
> somewhere before you can reach it, finding what opens the way — rather than moving between
> generated arenas."

**VERDICT: PASS — iterate implementation defects.** The floor-grammar ABSTRACTION is validated:
four independent layers, encounter region != room, a continuous stateful traversal space. It
reads as a place, and traversal itself feels good. **Current linearity is ACCEPTABLE for this
prototype** and is not a defect; route complexity belongs to larger layouts, optional branches
and procedural assembly. Every remaining finding is an implementation or content-law defect,
never a rejection of the abstraction.

The raw human findings and the recon that followed are preserved verbatim below, unedited.

## M2 FLOOR GRAMMAR — PLAYED END TO END 2026-08-29 (build `9f97834`). RAW FINDINGS.

The authored prototype was played start to endpoint on the committed build, unmodified.
**No PASS/FAIL is stamped here.** The frozen criterion verdict belongs to Breon alone and has
not been rendered; these are the human findings and the read-only recon that followed them.

### Human findings, verbatim
> "It felt more like a floor albeit linear."
> "Traversing felt good."

- the Ooze on the early right branch was too wide to chase through the hallway, became stuck
  on the corner, and visibly clipped through the wall;
- every walkable boundary does not need a wall — some reference-floor platforms have
  open/ledge edges while still preventing the player from falling;
- small floor triggers should activate automatically when stepped on rather than requiring E;
- the party encounter trigger should activate when the required party members are
  simultaneously on the plate; this is a coordination trigger, not an E interactable;
- requiring E on the final obvious progression switch/door felt unnecessary — either
  progression should happen naturally there or the interaction should be justified by a hidden
  switch / obvious puzzle / objective.

### 1. FLOOR GRAMMAR — POSITIVE (movement off the falsified baseline)
The prior failure was "four boxes / generated arenas". This build reads substantially more
like a floor, and traversal itself feels good. **Current linearity alone is NOT recorded as a
structural failure** — this is one small hand-authored grammar prototype, and route complexity
belongs to larger layouts, optional branches and procedural assembly. Branching machinery must
NOT be added merely to make this prototype less linear.

### 2. OOZE PASSAGE — RECON COMPLETE. The human's *observations* hold; the *stated cause* does not.
Read-only recon, no fix applied. Three separate causes, none of them "the Ooze is too wide":

**(a) The sim position was NEVER illegal.** `WalkableBounds.is_inside` / `clamp_step` are POINT
predicates over a union of rects; `clamp_step` lands a clamped actor EXACTLY on the boundary and
`is_inside` is INCLUSIVE there. The Ooze was legally placed at all times. **No eight-seam breach.**

**(b) "Cannot follow / stuck on the corner" is TERRITORY CONFINEMENT, working as ruled.** The
east arm's ambient site is authored as `region = P_HALL_EAST.rect` = x 8..16, z -30..-14, and
`SimWorld._legal_bounds_for` confines an enemy to its own site's territory ALWAYS — ambient
included, unconditional on activation. Chase the player west of x=8 and the Ooze clamps onto
x=8 and stops. That is the authored law (`floor_layers.gd`: "ambient does not yet mean
whole-floor roaming"), surfacing as an apparent movement defect. The corner it "sticks" on is
the territory boundary at the arm/strip junction, not a geometry pinch.

**(c) The clipping is POINT-LEGALITY vs BODY-WIDTH — one real structural gap.** The sim already
owns an authoritative body radius (`combat_radius`; Ooze = **1.45**), used by Burn contact-spread
and the projectile Minkowski sweep — but `WalkableBounds` never reads it. A body clamped onto
x=8 therefore extends 1.45 into ground nobody laid, exactly where `floor_builder.build_walls`
drew the void wall. Clipping and boundary-hugging are ONE defect with ONE cause: **bounds do not
know actor size.**

**Clearance is NOT the binding constraint here.** The arm is 8.0 wide and apertures are 5.0
wide against a 2.9 diameter — the passage fits. The clearance law is still worth authoring, but
it would not have prevented this.

**Design fork (genuine, unresolved):** does `combat_radius` enter the bounds predicate — making
legality body-aware everywhere, with an M3 replication cost and a re-baseline of every clamp
test — or does presentation inset the wall mesh / does authoring guarantee clearance? Cheapest
honest option is recorded below; the choice is a design call, not a defect fix.

### 3. WALKABILITY != WALL MESH — CONFIRMED CHEAP
`floor_builder.build_walls` samples each patch edge in 1.0 spans and erects a wall wherever no
walkable ground lies 0.5 beyond. It is already COMPUTED from the union, not authored, and it is
already presentation-only (meshes carry no collision; sim legality is the sole authority). So
open/ledge edges need **no new sim boundary system** — only an authored per-patch or per-edge
boundary STYLE that `_walls_for` reads. Sim legality is untouched by construction.

### 4. TRIGGER SEMANTICS — the automatic half ALREADY EXISTS
`TRIGGER_REGION` (`region_entered`) is implemented and shipping: `_advance_floor_state` scans
run-persistent actors each tick and fires on occupancy, with no E. The one-way commitment beat
already uses it. **"Automatic floor trigger" is therefore not new machinery** — the switch/plate
beats simply need re-authoring onto the kind that already exists.

**PARTY PLATE — what is genuinely missing:** a required-occupant COUNT. Today the region loop
`break`s on the first occupant found and `FloorTrigger.once` defaults true. A plate needs
`required_occupants` (solo M2 resolves to 1) and non-`once` re-evaluation. Model the condition
only; build no M3 networking. Validated encounter behaviour is unchanged — activation semantics
change, the atomic seal/open/spawn effect list does not.

**OCCUPANCY PREDICATE — one deliberate answer owed, for BOTH consumers.** Occupancy is currently
`Rect2.has_point(x, z)` — a POINT test, and `Rect2.has_point` is EXCLUSIVE on the far edge
(the documented trap), so it disagrees with `WalkableBounds.is_inside`, which is INCLUSIVE.
This is the SAME point-vs-body seam as finding 2(c), surfacing in a second consumer in the same
session. Resolve it ONCE, deliberately, for plates and bounds together.

### 5. FINAL INTERACTION — MEANINGLESS E
The end switch is `I_END_SWITCH` → trigger 5 → `OPEN_CONNECTION(C_TO_END)`, a one-effect switch
with no discovery and no decision. Smallest coherent outcomes: open `C_TO_END` on the
prerequisite directly (a `TRIGGER_ENCOUNTER_CLEARED` or region trigger — both already exist, so
this is an authoring edit, not new code), OR give the interaction a real discovery purpose.
Do NOT invent a puzzle merely to preserve the press.

### Provenance (both standing questions, answered on the record)
1. **Commit-before-play HELD.** The played build was `9f97834`, working tree verified clean by
   `git status` immediately before launch, launched unmodified. Nothing uncommitted was played.
2. **The frozen criterion DID ride ahead of the build.** It is present verbatim in `d0b5f49`
   (the docs commit that closed the multi-room playtest and declared the grammar falsified),
   which precedes the implementation commit `9f97834`. The criterion was pre-registered, not
   back-filled. No process defect to record on this one.

### Session telemetry (captured from the play process before its log was discarded)
The floor was played **twice** in one launch, both on `9f97834`.

- **ZERO errors and ZERO warnings for the whole session.** No refused placement, no
  illegal-position report, no bounds complaint. This is a SECOND line of evidence, independent
  of the code reading in finding 2(a), that the sim never held an actor somewhere illegal.
- **Run 1** fired triggers 0→4 and cleared the encounter, but **trigger 5 (the final E switch)
  never fired** — the run ended without it and was restarted with `R`. Why is not recorded;
  do not over-read it. It sits alongside finding 5 as a fact, not as its proof.
- **Run 2** fired all six triggers through to the endpoint.
- The crate was destroyed by **melee** in run 1 and by a **projectile** in run 2
  (`"projectile_id": 1`). The projectile-terminates-on-prop seam is therefore proven IN LIVE
  PLAY, not only in `test_breakable_props.gd`.

### NOT DONE, deliberately
No procedural-generation expansion · no pathfinding system · no roster tuning · no presentation
polish beyond what proving open/ledge boundaries requires · no fix of any kind applied yet.

## M2 FLOOR GRAMMAR — HAND-AUTHORED PROTOTYPE BUILT. **PLAYED 2026-08-29; see findings above.**

Suite 552 -> 581. Boots clean. No procedural assembly; no throwable; no minimap/elevator.

### What shipped
Four independent layers, none parenting another — `FloorPlan` now carries
`WalkablePatch[]` · `TraversalConnection[]` + `FloorTrigger[]` · `EncounterSite[]` ·
`InteractablePlan[]` + `BreakablePlan[]`. Rooms are gone as an abstraction; a patch is
geometry with no semantics, and **encounter region != physical room**.

One authored floor implements the whole grammar:
START → one-way commitment → hall wrapping a **void** → forward route **visible but
blocked** → branch (west solves, east is inhabited) → **break the crate** → reveals a
switch → switch opens the route → **PARTY BUTTON** (rear seals + forward opens + roster
ARRIVES + fight begins, one record) → clear → ramp opens → raised ground → ordinary switch
→ endpoint.

### Laws as built
- **The gate does not know why it opened.** `test_any_controller_opens_a_connection_the_same_way`
  drives a region trigger, an interactable and an encounter-clear into the SAME effect.
- **Atomic multi-effect.** The party button is three effects in one trigger record, applied
  in one tick and never observable half-fired.
- **Activation is authored.** There is no "entered the region ⇒ fight" rule in the sim at
  all; `test_no_encounter_activates_merely_because_a_region_was_entered` makes the falsified
  rule unrepresentable.
- **Territory is unconditional** — including AMBIENT, which means no ceremony and no lock,
  never whole-floor roaming. Proved for knockback, not just locomotion.
- **One-way commitment is not new legality math** — an ordinary connection plus a one-shot
  region trigger that blocks it. Bounds stay positional, so all eight displacement seams are
  untouched.
- **Elevation is presentation only.** The sim stays flat; the driver lifts transforms.
  `test_the_envoy_is_lifted_onto_high_ground_without_the_sim_knowing` pins both halves.

### The breakable seam (audit verdict honoured)
Props live in `_breakables`, absent from `_families`/`_health`/`_combat_radius`, so they
enter none of the six combatant scans BY CONSTRUCTION. They share the melee cone and the
projectile Minkowski sweep — detection only — and fork at resolution.
`tests/test_breakable_props.gd` asserts every "must not": no i-frames, no knockback, no
status/spread, no pressure/flinch, no lunge or bump blocking, no burrow occupancy, and
**enemies never attack scenery**. Projectiles terminate on props (cover), with a
destroy-the-cover control proving it measured cover rather than a broken path.

### Deliberate re-baseline
`floor_plan_golden.json` re-recorded for the new schema — reason and date logged in
`tools/record_floor_plan_golden.gd`, hand-inspected before commit. No M1 behaviour baseline
was touched.

### Recorded, not fixed
- **Seed honesty.** `generate(seed, depth)` keeps its signature but resolves an authored
  layout: **seeds do not vary geometry**, the plan says `authored_layout = true`, the HUD
  prints "authored layout", and a test asserts two seeds give identical geometry.
- **`_walk_to` in tests has no pathfinding** (straight-line steering, like a player holding a
  direction), so tests route through intermediate points. A direct walk failing because the
  void is in the way is the void working.
- **`ArchivePrototypeLayout` is data-as-code.** It migrates to a resource when a SECOND
  authored floor exists (§1.4), not sooner.

## M2 FLOOR GRAMMAR — DIRECTION SET 2026-08-28 (pre-code; model under review)

The floor is NOT `rooms + doors + combat rooms`. It is **a continuous, stateful traversal
space whose available routes change in response to player actions.**

### FROZEN HUMAN CRITERION (verbatim; do not paraphrase when judging)
> "The floor passes only if it feels like traversing and interacting with a place — seeing
> somewhere before you can reach it, finding what opens the way — rather than moving between
> generated arenas."

Verdict is Breon's alone, rendered against this exact sentence on the committed candidate.
(An earlier working paraphrase was superseded 2026-08-28; this is the binding wording.)
The already-validated encounter trigger/lock behaviour is NOT re-tested from zero — this
slice judges whether those mechanics now live inside a convincing exploration-floor grammar.

### FOUR INDEPENDENT CONCEPTS — a physical room is NOT the parent of any of them
1. **SPATIAL** — walkable patches/open areas, narrower connectors, irregular silhouettes,
   ramps/elevation PRESENTATION, voids/blockers, folded topology (later destinations visible
   before reachable).
2. **PROGRESSION** — controlled traversal connections, one-way commitment, gates/blockers,
   switches, objective dependencies, route availability state.
3. **ENCOUNTER** — encounter sites/regions, spawn groups, AUTHORED activation conditions,
   MANDATORY / OPTIONAL / AMBIENT, temporary confinement, completion conditions.
4. **WORLD INTERACTION** — interactables, minimal breakables, concealed interactables.

**ENCOUNTER REGION != PHYSICAL ROOM.** A room may survive as authored metadata or as a
combat shape; it is not the abstraction the other three hang from.

### CONTROLLED TRAVERSAL CONNECTION LAW
A gate/door/blocker is a traversal connection whose availability is controlled by
authoritative floor state. **The connection does not need to know WHY it opened or closed.**
Controllers may be switch state, objective completion, encounter activation/clear, one-way
commitment, or a party button. Keep controller / state / effect separation explicit.

**BRAIN CANDIDATE (banked):** *"The gate does not need to understand why it opened."*

### INTERACTION / OBJECTIVE LAW
One interactable may ATOMICALLY cause multiple deterministic floor-state changes. Reference:
a PARTY BUTTON seals the rear route, opens forward route(s), spawns/activates an encounter
roster, and begins encounter state — as ONE authored action. Do not distribute ownership of
that sequence across gate code, spawn code and presentation independently.

### ENCOUNTER ACTIVATION IS AUTHORED
`enter encounter area => start combat` is REJECTED as the universal rule (it is what the
multi-room slice shipped). Initial activation vocabulary stays narrow: explicit
pressure/party button · ordinary interactable/switch · trigger volume WHERE SPECIFICALLY
AUTHORED. Roles: MANDATORY (may control required progression) · OPTIONAL (physically
bypassable without activation) · AMBIENT (inhabits the floor, no arena-lock semantics).
The validated lock/confinement mechanics remain usable by triggered encounters.

### SPATIAL DEPTH — NOT VERTICAL COMBAT
Obtain depth first through irregular silhouettes, paths wrapping voids, ramps/raised
PRESENTATION, occlusion, foreground/background masses, folded topology, and areas visible
before reachable. Combat stays on the established plane. **Only if the hand-authored
prototype still feels flat after these spatial changes does that become evidence for
authoritative height mechanics.**

### SCOPE FENCES FOR THE NEXT PROTOTYPE
- **HAND-AUTHORED FIRST.** DepthGenerator does NOT procedurally assemble this yet.
- **MINIMAL BREAKABLE APPROVED**, narrowly: breakable -> destroyed -> optionally reveals /
  enables a contained interactable. Its only job is to test *search environment -> discover
  progression control*. NO currency, NO hearts, NO loot table, NO generalized destructible
  framework. Destructible/drop ECONOMY stays OUT.
- **THROWABLE PUZZLE DEFERRED.** A respawning throwable / ranged switch is a new gameplay
  capability, not floor-state plumbing, and must get its own narrow costed design. Prove
  switch-controlled topology with an ordinary interactable or a second switch instead.
  **Do not smuggle it in as level-design work.**
  **PRINCIPLE BANKED (design law):** *if progression requires a capability, the floor must
  guarantee access to that capability.* The mutually-exclusive switch-door puzzle from the
  live reference is deferred WITH its throwable, as one unit.
- Still out: branching procedural generation · minimap · elevator · drop economy ·
  treasure/shop/puzzle taxonomy · full vertical combat · presentation polish.

### TARGET PROTOTYPE FLOOR (one deterministic hand-authored floor)
START/LOADOUT-PREP -> one-way commitment -> irregular traversal/open space -> visible-but-
blocked route -> alternate/side path -> breakable search revealing an interactable ->
interactable changes blocker state -> explicit PARTY-BUTTON encounter -> rear seals +
forward route(s) change + enemies spawn -> clear -> ramp/elevation transition -> ordinary
switch-controlled route interaction -> endpoint.

Requirements: >=1 branch · >=1 route visible before reachable · >=1 irregular/open area ·
>=1 narrower path · 1 blocker whose solution is elsewhere · 1 concealment-by-breakable ·
1 explicit triggered encounter · **encounter must NOT start merely because the player entered
its physical area** · 1 post-clear continuation · >=1 ramp/elevation presentation change ·
simple endpoint.

### BREAKABLE INHERITANCE AUDIT (run against `d0b5f49` BEFORE any code) — VERDICT: FORK

Question: does `register_combatant` fork cleanly before the reaction layer? **It does not.**
A prop registered as a combatant enters `_families`, which is iterated by SIX scans:

| site | function | inherited |
|---|---|---|
| 1626 | `_resolve_melee_swing` | **WANTED** — melee finds it |
| 2084 | `_find_earliest_swept_hit` | **WANTED** — projectiles find it |
| 2130 | `_apply_shield_bump` | WRONG — a prop would be bump-slid |
| 2766 | `_burrow_point_is_occupied` | WRONG — unauthored burrow blocker |
| 3092 | `_find_earliest_lunge_contact` | WRONG — lunge clamps against it |
| 3183 | `_advance_contact_spread` | WRONG — Burn spreads to/through it |

And `_resolve_hit_on_target` would additionally confer: i-frames · block/parry · damage-matrix
multiplier · pressure recording · flinch routing · knockback (+ bounds clamp) · windup cancel ·
status proc and application · `_clear_clamps_targeting`. Worse, `_is_valid_target` returns
`allegiance(target) != allegiance(attacker)`, so a `&"world"` prop would be **a valid target
for enemies** — they would attack the scenery.

Four of six scans wrong, ten reactions wrong, plus enemy targeting: the convenience path would
require scattered combatant exceptions, which is exactly what the ruling forbids.

**VERDICT — dedicated damageable-prop seam, sharing DETECTION only.** Props live in their own
`_breakables` registry and are in `_families`/`_health`/`_combat_radius` **never**, so they
enter zero of the six scans by construction rather than by exception. The two scans that SHOULD
see them already have the right shape: each builds a candidate list and then applies geometry,
so breakable ids join the candidate list and the pipeline **forks at resolution** —
`_resolve_hit_on_breakable` instead of `_resolve_hit_on_target`. The melee cone test and the
projectile Minkowski sweep are reused as-is; neither is duplicated.

**v1 semantics, exactly:** weapon hit -> direct durability loss -> destroyed -> optionally
reveal/enable a contained interactable. Nothing else.

**PROJECTILE RULING (v1):** a projectile that hits a breakable registers the hit, applies
breakable damage, and TERMINATES on it. Breakables are therefore lightweight physical cover for
projectile traversal. A penetrable prop would have to be explicitly authored later; penetration
is never the default. The audit verifies this behaviour explicitly by test.

### STATE-SCOPE OBLIGATION
Every new authoritative floor state gets an explicit STATE_SCOPES classification and scanner
coverage. At minimum: connection/gate state · objective/interactable state · encounter state ·
spawned encounter roster ownership · breakable/reveal state. All FLOOR-scoped; none may leak
into run-persistent actor state.

## M2 MULTI-ROOM SLICE — **SPLIT VERDICT 2026-08-28. MECHANICS PASS / GRAMMAR FALSIFIED.**

Built on the committed Slice-1 baseline (`e7bea74`). Suite 523 -> 552.
Grammar now playable end to end: **ENTRY -> TRAVERSAL -> COMBAT(seal) -> CLEAR -> TRAVERSAL
-> FLOOR END.**

### PLAYTEST CLOSEOUT — build `5cff467` (provenance verified, not inferred)
HEAD `5cff46747f68f2693fefa0ad1c92b9c4771dbf54`, committed 2026-08-28 16:46:36 -0400.
Working tree clean, zero commits after it, reflog shows HEAD never moved, no source file
modified after the commit timestamp.

**RAW HUMAN FINDINGS (Breon, near-verbatim):**
> "It's still giving 4 boxes."
- bounds/connections were readable and natural
- placement felt fair/intended
- combat remained solid and unaffected by the floor changes
- the explicit "hit this button, start the encounter" sequence was solid
- the build worked as a battle-arena/combat-room structure
- it did NOT yet feel like the desired exploration-style floor
- the world lacked the spatial/depth feeling shown in the live references

### VERDICT — BOTH HALVES, RECORDED SEPARATELY

**PASS (validated; NOT to be re-tested from zero, NOT to be erased):**
1. connected walkability
2. combat-room confinement / locking
3. encounter trigger -> spawn -> lock sequence
4. clear -> reopen -> continue
5. follow-camera viability
6. **POSITIVE DATUM (Breon, verbatim):** the explicit "hit this button, start the encounter"
   sequence **"was solid."** This is the seed of the authored-activation direction, not an
   incidental nicety — the thing that worked is the thing being generalised.

**FALSIFIED / INSUFFICIENT AS FLOOR GRAMMAR:**
"FloorPlan = sequential rectangular rooms connected by doors" as the PRIMARY
exploration-floor abstraction. A chain of boxes reads as generated arenas, not as a place.

**THE ERROR WAS THE PARENT ABSTRACTION, NOT THE MECHANICS.** Making the rectangles bigger,
more numerous, or more varied does not fix this and is explicitly rejected. The pivot keeps
every validated mechanic and re-parents the spatial/content model around them: a floor is a
CONTINUOUS, STATEFUL TRAVERSAL SPACE whose available routes change in response to player
actions. See the floor-grammar entry below.

### Topology
`FloorPlan` -> `RoomPlan[]` + `ConnectionPlan[]` -> DERIVED `walkable_rects`. Room ROLES come
from `StratumConfig.room_sequence` (content, not code), so a second combat room is a .tres
edit. Sizes, rosters and placements are seeded. Branching graphs are later work.

**Apertures OVERLAP the rooms they join** — never merely abut. Two rects touching on a line
share zero area, so an actor is only ever inside one and the threshold becomes a
discontinuity. That overlap is also what makes gating free: the room's own rect already covers
its half of the aperture, so sealing removes only the corridor beyond and can never shrink the
room or snap an actor off a doorway.

### The four rulings, as built
1. **Enemy room confinement is ALWAYS**, not lock-scoped, and binds every displacement seam —
   proved for knockback, not just locomotion. Consumes P18's bounded-by-room direction.
2. **The seal binds both sides.** One resolver (`SimWorld._legal_bounds_for`) answers "where
   may this actor be" for enemies (own room, always), the sealed Envoy (locked room), and
   everyone else (whole floor). `_bounds` is never mutated to express a gate.
3. **Terminal marker** — deterministic endpoint, no elevator/transition/run-end logic.
4. **Dormant rosters do not aggro through doorways.** Gated on ENCOUNTER STATE rather than
   `_ai_state`, so `debug_force_aggro` cannot silently repeal the law. No LOS model exists.

Clear condition keys on `_health`, so a **burrowed Fang is alive and keeps its room sealed** —
burrow is temporary non-participation INSIDE an encounter and must never read as leaving one.

### Fixed: the array-order phantom wall
Slice 1's clamp chose the FIRST array-order rect containing the actor. In a doorway (inside
both room and aperture) that made wall placement depend on authoring order. `clamp_step` now
evaluates a candidate in every containing rect and keeps the one nearest the destination; ties
break on array order, so it stays deterministic for M3.

### Interactions found while building (recorded, not defects)
- **Burrow emergence is bounded by room ownership.** Candidates are placed around the PLAYER;
  if the player is in a different room, all are illegal and the fail-safe correctly kills the
  Fang underground. Unreachable in real play — a live encounter seals the player in — but it
  is why burrow tests must place the Envoy in-room.
- **DIFFICULTY MOVED, and nobody has judged it.** Sealing removes retreat, which was the
  implicit safety valve in Slice 1. Measured: the shipped 30 HP Envoy dies to a 4-Fang sealed
  room in roughly 40 s of continuous engagement. `spawn_count_min/max` stay PROVISIONAL and
  are the first knob if the first encounter reads as unfair. NOT retuned blind — combat values
  are under a numeric fence and this is a human call.

### P21 CONSUMED
`FollowCamera` translates only: M1's validated 45-degree offset is preserved exactly, so combat
readability and apparent scale are untouched. Edge clamp is deliberately CONSERVATIVE
(`edge_margin_*` = 6.0) because the failure modes are asymmetric — showing void past a wall is
cosmetic, holding focus so far from the Envoy that it leaves frame is fatal. Room-snapped
framing deferred: it brings a transition-feel question that would confound this playtest.

## M2 SLICE 1 — SEEDED BOUNDED FLOOR. **HUMAN PASS 2026-08-28.**

First M2 gate work. `run_seed -> DepthGenerator.generate(seed, depth) -> FloorPlan ->
SimWorld.load_floor()` with sim-authoritative walkable bounds, floor-driven spawning, and
mechanically-enforced run/floor state scopes. Suite 473 -> 523.

**HUMAN VERDICT (Breon):** generated bounds read as natural; enemy placement feels
fair/intended; combat behaviour unaffected. **The chamber is validated as a COMBAT-ROOM
PRIMITIVE, not as a floor** — it does not yet resemble an exploration floor, and
"enlarge the rectangle" is explicitly rejected as an answer. Reused, not discarded, as
the COMBAT room type by the multi-room slice below.

### What this slice established (do not re-litigate)
- **One SimWorld per RUN.** Floors load into it; the sim is never recreated as a cleanup
  convenience and state is never copied between worlds. `tick_count` is the run clock and
  never resets.
- **`STATE_SCOPES` is executable.** `load_floor()` iterates it rather than carrying a
  parallel clear-list, and a scanner test fails the build on any unclassified sim state.
  Proved capable of failing before being trusted.
- **FLOOR-TRANSITION LAW:** a transition is an ENCOUNTER BOUNDARY — deliberately unlike
  burrow, which is temporary non-participation inside ONE encounter. Durable run
  progression carries (health, equipment, loadout); transient combat effects do not.
  **Burn does NOT cross a floor.**
- **SHIELD:** no floor-load refill. Continuous regeneration stays the single recovery
  authority; the meter carries at whatever play left it. Clearing it would have been a
  stealth nerf (it defaults to 0.0), refilling it a stealth heal.
- **Placement fails loudly, displacement clamps.** An out-of-bounds spawn registers
  NOTHING and errors; it is never silently relocated into the room.

### THE STALE-AUDIT FINDING (the reason this slice was cheap)
The remembered P17 position-write list (move / lunge / bump / burrow) was **incomplete**:
it omitted BOTH knockback paths and registration placement. All eight authoritative
`entities[]` writers now consume one legality seam, which is why the multi-room slice can
add encounter gates as a ONE-FUNCTION change. `tests/test_floor_bounds.gd` drives each
site at a wall. **Re-run that audit before adding any new displacement mechanic.**

## Deferred (known, intentionally outside M0–M5 — the standing NOT-list)
- **Economy balance & trading** — auction-house *mechanics* are M5; economy *tuning*
  (sinks, faucets, dual currency) needs real player data a hobby project may never
  have. Design doc only, if ever.
- **Cosmetics/wardrobe, Steam integration, mobile ports, monetization** — irrelevant to
  a hobby built for the fun of building it. Revisit only if the goal ever changes.
- **Full status-effect roster** — M1 ships Burn only (GAME-RULES §3). Shock/freeze/
  poison/stun/curse analogues land one per playtested iteration after M2.
- **Lockstep determinism** — explicitly rejected (GAME-RULES §2 honesty clause);
  server-authoritative model instead. Do not reopen without a written reason.
- **PvP** — M5 candidate; needs M3 netcode to be proven first.
- **Custom level editor** — §1.4 rule of two: hand-author segments in the Godot editor
  until the pain is demonstrated twice.
- **Protocol expansion beyond Mend/Temper** — architecture supports N protocols; the
  design commits to TWO. Each protocol must reinterpret gear+Companion+playstyle
  coherently; that cost is why "why stop at two?" stays parked. Revisit post-M4.
- **Guild bases / guild progression** — M5-if-ever; folded under P13's world-state
  architecture question. Do not design independently.
- **Programmable companion AI + companion personality** — likely the SAME feature
  (P7 notes); post-M4 dream, not a pillar. High cost even before personality.
- **Status renames to lore vocabulary** — REJECTED (LEXICON.md: statuses are Plain
  register; combat vocabulary is UX). Do not reopen without playtest evidence.

## Feature Proposals
(Format per entry: `### P<n> — Title` then Idea / Reasoning / Design questions / Why
deferred. Append at the bottom + add an Index row. Nothing enters milestone scope
without moving through this list.)

### P1 — Bombs — the third weapon class
**Idea:** Placed-explosive weapon class specializing in area denial and status
application (fuse timer, blast radius, status payload — all in data).
**Reasoning:** The reference game's combat triangle is melee/ranged/bomb, and bombs
are its support/control leg — co-op composition gets much richer with a third class.
Weapon resources already carry a `class` field (§3), so the pipeline is ready.
**Design questions:** Fuse in sim ticks vs. contact-triggered? Self-damage? Does the
charge attack change the blast shape?
**Why deferred:** M1 proves the pipeline with two classes; bombs are the first
post-M2 Treat Rule candidate.

### P2 — Full status roster (one per playtested iteration, post-M2)
**Idea:** Frost (immobilize, broken by any damage, bonus damage on natural expiry),
Jolt (periodic Arc spasms that also hit the victim's adjacent allies; interrupts only
during telegraphs), Venom (attack/defense down + blocks all healing), Daze (move +
attack-speed slow, very short), Hex (damage on any ability use; scariest weapons may
Hex their own wielder on charge), Slumber (full disable + regen, broken by damage).
**Reasoning:** Identities translated from the reference game's roster — each status
has a distinct tactical job (crowd control, anti-heal, setup, anti-turtle) rather than
being a reskinned DoT. The single-status-slot law (§3) makes each addition cheap.
**Design questions:** Priority/replacement table values; which statuses enemies may
apply to players in early tiers.
**Why deferred:** Ship one, playtest, ship the next — never batch-add.

### P3 — Consumable vials
**Idea:** Throwable/usable items that apply any status (or cure) regardless of loadout.
**Reasoning:** Gives every build access to tactical statuses and gives loot tables a
useful common drop; pairs with the mender-enemy proposal below.
**Why deferred:** Needs the status roster to exist first.

### P4 — Mender-type enemy
**Idea:** An enemy that heals nearby enemies (visible heal feedback).
**Reasoning:** The single cheapest tactical spice in the reference game — it turns
every encounter into a kill-priority decision. Also creates Venom's (anti-heal) reason
to exist.
**Why deferred:** M2 content addition once 3+ base enemies are proven fun.

### P5 — Gear stars, heat, and recipe crafting
**Idea:** 0–5 star gear rarity, items leveling through use, recipe+material crafting;
armor sets as playstyle identities instead of character classes.
**Reasoning:** The reference game's entire progression skeleton — this is M4's
crafting/heat loop already in CLAUDE.md, recorded here with the mechanical shape.
**Addendum — charge-profile differentiation (captured pre-build, Slice B era):**
weapon lines differentiate by CHARGE PROFILE (the per-hit/charge content-profile
seam Slice B establishes, see `sword_stats.gd`'s SLICE B SPEC comment), and
enhancement/upgrade strengthens or REPLACES a profile rather than just scaling
numbers. Worked example: "Brandish" — a powerful strike PLUS an advancing line of
pushing, damaging, status-bearing impacts — is the second concrete charge shape
(sword_burn_A's single charged strike is the first), and needs its own spec
(interruption, owner-death, per-pulse status, defense-across-waves) once it becomes
real content.
**Addendum — weapon slot count (captured pre-build, Phase D step 8):** the reference
game supports multiple equipped weapon slots (2 base, up to 4) + shield,
cycle-accessible mid-combat. The current `equipped-weapon` + `switch_weapon`
Command architecture (`SimWorld.set_weapon_loadout`/`_apply_switch_weapon`) already
generalizes to N slots — slot *count* is progression content to unlock, not an
architecture change. Do not redesign cycling to add more slots; just register a
longer loadout array.
**Addendum — combo length is a flinch-economy decision, not a weapon-feel decision
(2026-08-11, combat-advisory arc):** under the batch's pressure model, sequence length ×
per-hit damage × cadence × the SHARED pressure window jointly determine how often a
player can access enemy control. A second sword family cannot pick its combo length
freely; it inherits that economy. Content-authoring constraint to apply BEFORE any
second sword line is authored. Keep the pressure window shared/global — per-weapon
windows only if multiple real weapons prove the shared model cannot support their rhythm
(§1.4). Related constraints recorded at the same time: attack-speed modifiers must not
silently alter authored movement or reach (snapshot vs dynamic vs authored timing
semantics get locked before modifiers ship); split/multi-channel damage must not
double-dip generic bonuses; and status value is evaluated in the geometry and timing of
the exact weapon applying it — there is no fixed "status = −X% damage" formula.
**Why deferred:** M4 by design; do not front-load progression before fun is proven.
Charge-profile plumbing itself lands with Slice B (M1); this addendum is only about
progression differentiating BY that plumbing, which stays M4.
**Addendum — M3 delivery requirement for phased attack Commands (Slice B, built this
session):** the sword's combo/charge model sends explicit `attack` phases
(`pressed`/`held`/`released`) rather than inferring transitions from a missing
per-tick Command. That avoids one class of ambiguity, but does NOT by itself solve
transport loss — a dropped `released` (or `pressed`) is still a dropped transition
and would leave `SimWorld._melee_hold` open with no way to resolve it. M3's
server-authoritative model (GAME-RULES §4) must provide reliable delivery/sequencing
for these edge-bearing phases, or a periodic input-state reconciliation mechanism, so
a lost network message can never leave an actor's attack state stuck mid-hold. Not a
concern for M1 (single offline driver, no packet loss) — flagged here so M3 netcode
work doesn't discover it late.

### P6 — Rotating gate map (arcade)
**Idea:** Multiple concurrent descent "gates" whose upcoming floors rotate on a
timer and are previewable, making route planning a meta-game.
**Reasoning:** The reference game's most distinctive structural feature; genuinely an
MMO-layer system since its value comes from a shared persistent world.
**Why deferred:** M5. The M2 next-floor preview is the single-run seed of this idea.

### P7 — Companion system (one slot, many expressions)
**Idea:** Every Envoy has one Companion slot — a synchronization anchor (WORLD-CANON).
The loaded protocol determines the occupant: Mend → a Reclaimed being that grows;
Temper → the Pyre (Drift engine fed by residue from defeated enemies; name
provisional per LEXICON).
**Reasoning:** One architecture, many fantasies — the single-status-slot philosophy at
system scale. §6.2: this is ONE progression loop, deliberately, not three (AI pet +
mount + virus companion collapsed here by design).
**Design questions:** Behavior config depth vs. cost; does personality emerge from
config over time (the "programmable + beloved" unification)? Frames (P12) as
mission-specific slot expressions?
**Why deferred:** Canon now, mechanics M4+ — annotated in WORLD-CANON so fiction
doesn't outrun the roadmap (RISKS #12).

### P8 — Protocols: Mend / Temper
**Idea:** Per-expedition philosophy loadout ("Load Protocol: MEND/TEMPER"), not a
permanent faction. Changes how shared systems behave — Companion expression, gear
interaction with Drift, support-vs-risk flavor. §6.4 governs: expression, not access.
**Reasoning:** Turns the Purify/Purge schism into build identity (the core pillar:
gear defines playstyle); dissolves faction-lock problems; roguelite-native.
**Design questions:** What concretely differs at M4 scope (companion + 2–3 behavior
modifiers is plenty)? Co-op composition effects?
**Why deferred:** Needs Companion (P7) and progression (M4) to exist first.

### P9 — Drift scalar
**Idea:** `drift: float` per zone/run in the sim; presentation derives palette shifts,
music, spawn-table weights, hazard density from thresholds. Headlessly testable.
**Reasoning:** Replaces N boolean world-state flags with one scalar — textbook
sim/presentation split. Single-player first; the community version (P13) is the same
system pointed at a server, which keeps live-events possible without building netcode
now.
**Design questions:** Per-run, per-save, or per-zone-persistent? Threshold table in
config; interaction with typed_damage_ramp. **Rule-of-two guard:** first prove ONE
concrete consumer; do not create a universal Drift scalar merely because several
future systems (spawn weighting, visuals, run exposure, community state) might use
something with the same name — that's a god variable.
**Why deferred:** M2-adjacent — consider during M2 design sessions, after golden-seed
gen exists. Not an M2 gate item.

### P10 — Gear states: Mended / Stable / Drifted
**Idea:** Weapon identities, not rarity: Stable = baseline; Drifted = mechanical
mutation (e.g. 6-hit combo, whiff-stun; doubled parry window, overload on fail) —
challenge, not stat tax; Mended = reliable/synergistic. Drifted gear's downsides are
ARCHITECTURAL, not numeric (e.g. occupies the wielder's status slot, or opens a
type vulnerability) — and Umbral-neutral per §6.8: damage types are never faction
property.
**Reasoning:** Aspirational mastery + the seduction principle (§6.5) made tangible.
**Design questions:** Which weapon gets the first Drifted identity; acquisition path
per protocol.
**Why deferred:** CONTENT MULTIPLIER (RISKS #13) — most weapons ship Stable-only;
states are earned content one weapon at a time, post-M2, Treat-Rule friendly.

### P11 — Contested enemy state
**Idea:** Third state tag: caught between Drift and Axiom influence; elite/miniboss
encounters where both motion languages collide on one body.
**Reasoning:** Free drama from the orthogonal family×state architecture (§3).
**Why deferred:** Needs Drifted+Claimed states shipped and readable first.

### P12 — Frames (mobility platforms)
**Idea:** Combat-identity platforms (spider frame, hover rig, assault walker) —
change movement AND tactics; never "+5% speed," never a gear grind.
**Reasoning:** Concept preserved from the arc; implementation archived. Relationship
to Companion (P7) is UNRESOLVED — do not share a slot or base class without two
concrete overlapping uses (§1.4 rule of two); ownership, animation, collision, and
netcode needs may differ entirely.
**Why deferred:** §6.2 — a fourth loop needs its lifetime cost justified.

### P13 — Community world-state
**Idea:** Shared Drift scalar across all players; community actions move zone
thresholds (merchants evacuate at 0.95, boss appears at 0.68, etc.).
**Reasoning:** "Architect for it, don't build it" — P9's design must not preclude a
server-side source for the scalar; that single constraint keeps this alive for free.
**Why deferred:** M5-if-ever; re-scope with M5 per §5.

### P14 — Title decision
**Idea:** Replace working title "Knight Depths" with a lexicon-family title.
**Reasoning:** Repo name is the last knight standing (LEXICON: exempt, temporarily).
Titles get trademark/collision search before adoption (Lattice and Loom both collide
commercially as bare names).
**Why deferred:** Zero urgency; titles crystallize once the world's language has been
lived in. Explicitly deferred ≠ forgotten.

### P15 — Dodge: own input, sim movement burst, i-frame trigger
**Idea:** A dedicated dodge input (needs its own Input Map action — none exists yet)
that triggers a short sim-side movement burst with a cooldown, and arms the SAME
invulnerability timer the shield/i-frames session built (`SimWorld
._iframe_ticks_remaining`, armed via `_iframe_ticks_on_hit`-style content data in
ticks) — never a second invulnerability mechanism living in parallel.
**Reasoning:** GAME-RULES §3 already says "i-frames on dodge/hit" — the architecture
anticipates this, but this milestone's scope (Phase D step 5) only implements the
"hit" trigger, since no dodge input/command/animation exists anywhere in the repo yet.
This is sequencing against an unscheduled feature, not a scope reduction.
**Design questions:** Dodge distance/duration in ticks; cooldown length; does a dodge
cancel an in-progress block/attack; i-frame duration shared with hit-i-frames or its
own (probably longer) content field.
**Why deferred:** Not part of the shield/i-frame step this session — no input binding
or movement-burst design has been done. First candidate once combo/charge (§3) also
needs revisiting, since dodge likely interacts with combo timing.

### P16 — Shield bump + perfect parry (TREAT, pulled forward at M1 close)
**Status:** the ONE guilt-free out-of-order Treat item (AGENTS.md Momentum Protocol),
chosen 2026-08-13. Still passes /gate; it just skips the queue.

**SPLIT (developer direction, 2026-08-13):** the original entry conflated one timing-
gated mechanic. It is now TWO separable behaviors with INDEPENDENT tuning. The baseline
bump must NOT become timing-dependent — that was the correction.

**1. Shield bump — baseline spacing utility.** Raising the shield while an enemy is
inside a very close authored proximity pushes it away. NO precision timing required:
this is spacing control available to any player, not a skill check. Its own cooldown
prevents holding or re-raising the shield from continuously repelling everything.
Reuses the existing authoritative displacement path (the same knockback resolution the
combat pipeline already owns) — no generic reaction framework.

**2. Perfect parry — mastery layer.** A block landing inside a short timing window
converts defense into a brief offensive advantage. Preferred first payoff: the parried
attacker takes INCREASED DAMAGE for a short deterministic duration. Deliberately ONE
reward — no stun + flinch + damage + meter refund + knockback package. Uses the
narrowest existing damage-modifier seam; no generalized armor/debuff framework invented
for a single consumer.

**Desired shield progression:** normal block = safety · bump = spacing control ·
perfect parry = defense converted into short offensive advantage.

**Foundations that already exist:** `_block_start_tick` (recorded on every READY→HELD
rising edge) gives the parry window its reference point for free; `_contact_distance`
gives bump its proximity test; the knockback pipeline gives bump its displacement; and
flinch's absolute-deadline pattern (`_flinched_until_tick`) is the precedent for the
parry's temporary vulnerability window.
**Why deferred until now:** shield v1 shipped the flat block/break model only; both
layers needed a playtested base to attach to. That base passed its re-gate.

### P17 — Per-family engagement identities
**Idea:** Movement/attack personality translated from the reference game, layered as
CONTENT on top of the shared AI (pursue/engage/leash) built in Phase D step 8 — never
as AI special cases (the locked build-shape rule: attack shape is content; since P29
the AI decides locomotion, whether to attack now, and which eligible authored action to
commit — never how that action behaves).
- **Ooze:** shuffle approach, a visible charge-up, then a hop-attack (windup +
  self-knockback + a wide/360° cone) — a pull-forward Treat Rule candidate if the M1
  replay finds the three families feeling too uniform.
- **Fang:** a pack-call, a reposition beat, and a delayed chomp — needs the
  deliberately-deferred reposition system (Phase D step 8's engagement-spacing fix
  shipped only approach/back-away/stop, no tangential reposition).
- **A slow-advancing undead archetype** with either a charged leap or a ranged
  status-carrying cone attack. Family TBD — Watcher vs. Hollow gets decided at M2's
  enemy-content session, not here. The cone itself is M2-gated regardless of family:
  it needs the first ranged ENEMY attack, the first enemy-applied status, and
  typed_damage_ramp to all exist first (M1 ships melee-only, Force-only enemies per
  the onboarding rule).
- **A turret archetype:** stationary, ranged, tiered (single-shot / tri-cone /
  seeking). Seeking needs per-tick projectile steering toward a moving target — a new
  sim capability; today's projectiles travel in a fixed straight line from spawn.
**BREON'S FANG SKETCHES (verbatim, captured 2026-08-17):**
> zig-zag rush → windup on arrival
> burst lunge → readable recovery → decide

**FAMILY TAXONOMY (captured 2026-08-17)** — the axis each family should express, so
movement identity is authored toward a stated character rather than invented per enemy:
- **Fang** — aggressive, NONLINEAR, committing.
- **Ooze** — area-denial, positional.
- **Watcher** — deliberate; punishable, committed tells.

Note both Fang sketches share a shape P29 does not currently have: movement and attack as
ONE authored beat (arrive-then-windup, lunge-then-recover-then-decide), rather than
movement that stops so an attack can start. That is the same seam the held Watcher
selection trigger points at from the other direction — worth designing together if both
fire.

**Reasoning:** Identities translated from the reference game's roster, same spirit as
P2's status roster — each family becomes tactically distinct rather than a reskinned
pursue-and-hit loop, without adding a second AI code path per family.
**Design questions:** Which family gets Watcher vs. Hollow's true-name slot; how much
of "personality" is timing/cone-shape data vs. genuinely new AI states (reposition,
projectile steering); whether the reposition system Fang needs is worth building
before a second family also wants it (rule of two).
**Why deferred:** M1's AI ships the minimum viable shared engagement loop only
(GAME-RULES §5 M1 gate doesn't require distinct enemy personalities); this is M2
content-pass work once 3+ base enemies are proven fun, per P4's existing "M2 content
addition" precedent.

---

**STATUS 2026-08-19 — FANG WEAVE FALSIFIED AND REVERTED. Successor recon below.**

**VERDICT: ITERATE — weave hypothesis FALSIFIED, P17 finding REINFORCED.** The original
playtest finding (enemy approach feels too uniform) still stands; the weave was the wrong
answer to it, and knowing that is the experiment's return.

**RAW ANSWERS (verbatim):** readable but repetitive · same approach with wobble (Q2 FAIL,
the finding under test) · release hinge PASS · facing acceptable · wand tracking unchanged
(Q5 FAIL) · opener PASS · Q7 unanswered, carried to the successor design.

**WHY IT FAILED, stated once so the successor does not repeat it.** Q2 and Q5 failed
together and they are the same failure: the weave changed the SHAPE OF THE PATH without
changing the DECISION the player faces. Tracking with `wand_A` was unchanged, spacing was
unchanged, timing was unchanged — so a wobble is what was left. Geometry is not identity.

**REVERTED** (a falsified mechanic does not stay in live code merely because it is tested):
the sim expression and its registration/observability surface, all four `FangStats` fields,
the inert copies on Ooze/Watcher, the registrar pass-through, `arena.gd`'s debug export, and
`tests/test_approach_weave.gd`. Verified byte-complete: live behaviour is 294/294 events
identical to `ai_baseline_pre_p29.json` again.

**PRESERVED — the experiment's durable yield, none of it dependent on the mechanic:**
- **GAME-RULES §3 channel-law amendment + §7 row.** A design law is not dependent on its
  first consumer surviving. Families own BASELINE MOTION PATH (spatial); states own MOTION
  RHYTHM/COORDINATION (temporal); orthogonal but composable. The BINDING per-actor
  phase-offset consequence stands and will bind the successor if it is globally phased.
- **The guard's approved-amendment seam** (`scripts/guard.py --amend`) + its 27 adversarial
  checks. Governance infrastructure, unrelated to what it was first used to record.
- **The three-artifact baseline discipline**, including the recorder's inability to
  overwrite the historical fixture.
- **THE RELEASE/STRAIGHTEN FINDING (Q3 PASS) — carried forward as a REQUIREMENT, not a
  suggestion.** The one validated piece: a committed movement must STRAIGHTEN AND SETTLE
  before the next decision, rather than flowing straight into a windup. Any successor
  mobility mechanic must end in a settle beat.

**FIXTURE ROLES after the revert (all three files byte-untouched, roles stated in their
consuming tests):**
1. `ai_baseline_pre_p29.json` — historical evidence, AND once again an accurate description
   of Fang's live behaviour. The second is a FACT, not a restored authority: gating stays
   with the Ooze canary, because re-blessing in reverse is still re-blessing.
2. `ai_canary_ooze.json` — unchanged, still the ACTIVE gate on the shared locomotion path.
3. `ai_baseline_p17_fang.json` — retired to EXPERIMENT EVIDENCE, falsified 2026-08-19. Its
   consuming test documents the verdict and no longer gates; it asserts the evidence still
   shows the weave, so the verdict above stays backed by something.

**§3/§7 PROVENANCE (unchanged, retained).** Approved in-conversation 2026-08-18; applied via
`python scripts/guard.py --amend <manifest> --i-have-explicit-user-approval`; pre `4d4f3471…`
to post `2956edfb…`; delta confined to two hunks; LF-only/no-BOM/UTF-8 preserved.

---

## P17 SUCCESSOR RECON — FANG SITUATIONAL MOBILITY (recon only, nothing implemented)

Target shape: pursue → retreat/denial condition → **scurry commitment** → fast authored
displacement → settle/straighten → fresh decision → bite windup if appropriate.
FENCES: Fang-specific · no generic movement or retreat-detection framework · no Fang
HP/damage/flinch tuning · no Ooze/Watcher changes.

**1. MOBILITY-VS-ATTACK — YES, representable, and the precedent already exists.**
`_bump_slides` (P16 shield bump) is already exactly "a short authoritative multi-tick
displacement that is neither ordinary locomotion nor an attack", and it does **not** touch
`_melee_hold`: its own dict, its own `_advance_bump_slides()` tick phase running *before*
`_decide_ai_commands`, clamping through the shared `_find_earliest_lunge_contact`, and
suppressing the actor's own `move` Command for its duration. Blocked = the slide ends, never
chases. Its progress is counted in STEPS rather than compared against an end tick — a
deliberate anti-off-by-one lesson worth inheriting verbatim.
- Currently player-side only (shield bump), but the machinery is allegiance-agnostic.
- **FORK (rule of two):** bump is consumer #1; a scurry is #2, which is exactly §1.4's
  threshold. Copy the shape a second time (fences-compliant; §1.4 literally says copy twice
  before abstracting) **vs.** extract a shared authored-displacement concept now.
  Surfaced, not decided.

**2. RETREAT SIGNAL — the sim retains NO movement history. The absence IS the finding.**
Per-actor movement state is exactly `entities` (current position), `_move_speeds` (a
constant), and `_facings` (last movement DIRECTION, normalized). There is no previous
position, no velocity, and no history buffer anywhere. `_facings` is the only residue of
motion and it is unusable as a movement signal: magnitude-free, and *also written by attacks*
(`_apply_attack` sets it on any accepted attack). Forks, in ascending cost:
- **(c) failed-closure window** — needs NO new state class: it is P29's existing pattern.
- **(b) distance increasing N ticks while pursuing** — one remembered distance + one
  counter. A *relation*, not a velocity.
- **(a) away-projected player velocity** — requires genuinely new retained per-actor state
  that every other system must then maintain honestly. Most expensive, most general.
**P29 TRANSFER: yes, structurally, and it is the strongest lead.** `_refresh_close_proximity`
stores an honest timestamp of a world FACT, refreshed before every decision branch, never
stamped once and never skipped for what the actor happens to be doing; the episode is then
DERIVED from two timestamps rather than stored as a flag that can desync. "Player retreating
while I pursue" is the sibling fact of "unable to close" and takes the same shape.
- **FENCE COLLISION TO SURFACE:** P29's naming fence says `requires_close_frustration` /
  `close_frustration_ticks` stay deliberately narrow and generalise to a context framework
  **only** when a second real consumer exists. A retreat-triggered scurry would BE that
  second consumer. This is the moment that fence gets tested — flagged, not decided.

**3. TARGETING FORK (surfaced, not decided).**
- **Current position** — what the AI already uses; zero new machinery.
- **Projected position** — needs player velocity, i.e. fork 2(a)'s new retained state.
- **Positional relation ("get in front")** — needs a committed DESTINATION. Note the §3
  interaction: aim is sampled at the FIRE TICK precisely so a windup cannot commit to a
  stale target position. A destination committed at scurry start is the same class of thing.
  Precedent cuts both ways: bump already commits a direction at commit time and never
  re-evaluates — but bump lasts a few ticks, and a scurry would last longer, which is
  exactly the span over which "committed" becomes "stale".

**4. CANCELLATION / FLINCH / RECOVERY — currently UNSPECIFIED, and load-bearing here.**
`_advance_bump_slides()` runs in its own phase and is **not** gated by `_flinched_until_tick`
— the flinch early-return lives in `_decide_single_ai_command`, which suppresses *Commands*
only. So a scurry built on the bump shape would **continue through a flinch** unless
explicitly cancelled. There is no cancellation path for a slide today; bump never needed one
at 1–3 ticks (it is cleared with reaction state, nothing more). A longer commitment makes
these real decisions: does a flinch abort the scurry, freeze it, or let it finish? Does an
aborted scurry consume its trigger episode (P29 ruled consumption-at-commitment for the
survey — a direct precedent)? What arms the cooldown on an aborted one?

**5. NARROWEST CONTENT SHAPE (candidate, Fang-only).** Displacement per step + step count
(inherit bump's counter, not an end tick) · settle/recovery ticks · one trigger parameter
matching whichever fork in 2 is chosen · a cooldown so it cannot chain. The carried Q3
requirement lands here: the settle beat is **not** optional trim — it is the part that
playtested PASS, and it must exist before the fresh decision.

**OPEN FROM THE PREVIOUS EXPERIMENT:** Q7 (multiple Fangs — individual predators, or
accidental coordination?) is unanswered and carries to the successor, along with §3's
binding per-actor phase-offset consequence if the successor is globally phased.

---

## P17 SCURRY v1 — **FALSIFIED 2026-08-19, REVERTED.** Successor recon below.

Spec `8dd504e` · implementation `9691931` (frozen candidate, preserved in history) · verdict
rendered by Breon after single-Fang play.

### RAW PLAYTEST ANSWERS (verbatim)
- **Q1 trigger legibility:** *"It feels like random mobility, should be moving around to get in
  front of where I'm running towards like arc around and get in front of me as to force me to
  change directions or walk into the attack."*
- **Q2 pressure / pre-registered criterion:** *"Kite and fire feels the same level of freeness."*
- **Q3 commitment/counterplay:** *"Didn't really get to test this chase was weak."*
- **Q4 closure amount:** *"No."*
- **Q5 settle payoff:** *"Sure didn't really get to feel it."*
- **Q6 overall identity:** *"No."*

### FORMAL FALSIFICATION BASIS
The criterion was pre-registered before implementation: *falsified if optimal player behavior
is unchanged, regardless of appearance.* **Q2 is that criterion verbatim in play terms.**
Q1/Q4/Q6 reinforce it — the mobility did not read as purposeful pursuit, the spacing change
was not consequential, and Fang gained no distinct approach decision. Q3/Q5 are
low-signal/inconclusive: the chase never generated enough pressure for those sub-beats to
become evaluable.

**NO TUNING.** Trigger delay, speed, step count, authored distance and settle duration cannot
rescue a mechanic that failed its player-decision criterion.

### TRIGGER AUTOPSY (diagnostic only, run against frozen `9691931` BEFORE the revert)
Purpose: ensure the successor does not inherit a blind detector.

**SCOPE, STATED PRECISELY — four claims, no more (correction to an earlier overclaim):**
1. **The P17 scurry v1 EXPERIMENT: FALSIFIED** by Breon, on its pre-registered
   player-decision criterion.
2. **The DETECTOR: specifically FALSIFIED** by the autopsy below. Rejected for this
   consumer; must not be tuned or reused.
3. **The RAPID-CLOSURE RESPONSE: SUPERSEDED / UNPROVEN — not independently falsified.** It
   was never exercised under a detector that recognized representative kiting, so no verdict
   on the response itself is available. It is superseded by the clarified design target.
4. **`9691931` is preserved as a DORMANT FALLBACK:** rapid-closure-with-a-working-detector,
   live again if the cutoff experiment later falsifies.

An earlier draft of this entry asserted that the dash would have failed even under a working
detector. No evidence supports that claim; it is withdrawn, and no equivalent claim may be
written back in. Claim 3 above is the whole of what is known about the response.

**BANKED FINDING:** *Retreat is not equivalent to increasing radial distance. Cutoff behavior
cares about sustained player travel direction.*

**WITHDRAWN CLAIM (2026-08-20).** After a scurry-build play session the agent reported that
the arena log contained "zero scurry events" and offered it as live-play corroboration of the
autopsy. **That reasoning was invalid and is withdrawn.** `arena.gd::_report_events` had no
case for any scurry event kind, so the log could not have contained one regardless of whether
the mechanic fired. The same hole was then found for the cutoff kinds, which is what prompted
the audit.

This withdrawal touches NOTHING else. The scurry verdict was Breon's human judgement, not
derived from logs, and the autopsy stands on the 886/900 refresh measurement and the cos45deg
arithmetic -- both independent of arena logging.

**BRAIN CANDIDATE, riding with the P17 closeout (not promoted, gates nothing):**
*"Absence from a channel is evidence only if the channel can observe the event."* Before
treating a silent log, an empty result set or an unfired assertion as information, verify the
observer could have recorded the thing whose absence is being read. Related to the existing
"a measurement must prove its mechanism fired before its numbers mean anything" -- this is its
negative-space twin, about absence rather than presence.

900 ticks (30 s) per run. Authored trigger: `separation >= 2.5` AND `elapsed >= 45`.

| path | firing | minimum refreshes | max separation | max elapsed | commits |
|---|---|---|---|---|---|
| radial retreat | no | 3 | 2.53 | 76 | 2 (first @77) |
| radial retreat | yes | 5 | 2.53 | 76 | 2 (first @77) |
| diagonal-45 retreat | no | **886** | **0.00** | **1** | **0 — NEVER FIRES** |
| diagonal-45 retreat | yes | **886** | **0.00** | **1** | **0 — NEVER FIRES** |
| circling / strafing | no | 96 | 0.09 | 18 | **0 — NEVER FIRES** |
| circling / strafing | yes | 96 | 0.09 | 18 | **0 — NEVER FIRES** |

**CLAIM CONFIRMED: the signal measured RADIAL SEPARATION; the behavior we care about is
SUSTAINED DIRECTIONAL TRAVEL.** The cause is arithmetic, not tuning — compare the RADIAL
component of player travel against Fang's 3.00 u/s:

| player behavior | radial speed | result |
|---|---|---|
| straight retreat | 4.00 | gains 1.00 u/s — minimum stops improving, trigger can arm |
| diagonal-45 retreat | 4.00 × cos45° = **2.83** | Fang **GAINS** 0.17 u/s — minimum improves nearly every tick |
| circling | **0.00** | Fang **GAINS** 3.00 u/s — minimum improves constantly |

At 45° the minimum refreshed on **886 of 900 ticks**, resetting BOTH terms continuously. The
Fang perceived *retreat → reset → retreat → reset*; the player experienced one continuous
kite. Only pure radial flight — the one kite shape no player uses exclusively — could ever
arm it. Firing changed nothing (flinch-clearing added 2 refreshes on the radial path and no
commits anywhere), so the blindness is **geometric, not reaction-driven**.

This independently explains Q1 ("random mobility"), Q3 ("chase was weak") and the difficulty
of evaluating the committed line: commitments appeared only during incidental pure-radial
moments, disconnected from what the player felt they were doing.

*Reproducibility: the finding above is analytic (the cos45° arithmetic) and re-derivable
without tooling. The empirical harness ran against `9691931` and was not committed, since a
diagnostic for a deleted mechanic is dead code.*

*Note the autopsy's limit: it proves the detector never armed under realistic kiting. It says
nothing about how the dash would have felt had it armed correctly, and no such claim is made.*

### CORE DESIGN CLARIFICATION (Breon)
Fang should not merely **close the current gap**. Fang should **CONTEST THE PLAYER'S CHOSEN
MOVEMENT DIRECTION** — arc toward the space ahead of the player's travel, get in front of the
route, and force a redirect, an evade, a defensive tool, or a walk into the attack.

Not *"faster object chasing current coordinates."* Instead: **"predator trying to cut off your
route."**

### PRESERVED (independent of the mechanic)
Pre-code spec discipline · this verdict and its raw answers · the autopsy evidence above ·
the C.1 bump/flinch agency ruling and its regression test · GAME-RULES §3 channel-law
amendment · the guard's approved-amendment seam and its 27 adversarial checks · the
three-artifact baseline/evidence discipline · both BRAIN lessons.

### REMOVED FROM LIVE CODE
Six content fields (Fang + inert copies), all runtime state, both events, the observability
export, the registrar pass-through, the test file, and the diagnostic tool. No dead tuning
knobs and no dormant runtime seams left behind merely because they were tested.

---

## P17 CUTOFF — **FALSIFIED BY PLAY 2026-08-22, REVERTED.** Burrow pivot below.

Spec `d070b63` · implementation `43c597e` · frozen play candidate `a2c00aa`.

**VERDICT (Breon, verbatim):** *"It just looked like running a football route — couple yards
up, diagonal cut to a point. Didn't look or feel good."* He did not voluntarily redirect
because of the incoming cutoff. The pre-registered player-decision criterion failed.

### EVIDENCE SCOPE — narrow, and the narrowness matters
Log evidence from the human session: **3 `cutoff_committed`, 3 `cutoff_ended`, 0
`cutoff_aborted`, all three ending `budget_spent`.** Therefore established:
- the detector fired during real representative play — the mechanic actually participated;
- geometric side selection was active (both signs observed, not defaulting to the tie);
- Breon meaningfully experienced the authored lateral-leg → diagonal-run grammar;
- **none of the three executions reached its committed lead point.**

**THE SHIPPED BOUNDED CUTOFF BEHAVIOR WAS PLAYTESTED AND FALSIFIED. Lead-point arrival
itself remains untested.** Do NOT record "the full intended lead-point arrival was tested and
rejected" — it was not. Do NOT downgrade the experiment to "untested" either: the capped
movement was the actual candidate played, and the two-segment locomotion grammar was visible
enough to render a human verdict on.

**NO RETUNE.** `cutoff_max_steps` must not be raised to force arrival. The complaint is
upstream of completion distance — the two-segment locomotion GRAMMAR read as an artificial
football route. A larger budget extends the same rejected grammar. The three-for-three
`budget_spent` result is important evidence about the experiment's CONSTRUCTION; it does not
reopen the verdict. If cutoff geometry is ever historically revisited, the budget limitation
must be considered then — it is not a reason for another cutoff iteration now.

**STATUS: recoverable historical evidence, NOT a dormant fallback.** Unlike the scurry, the
cutoff is not an active alternate design candidate.

**SCURRY's scope stays separate and must not be merged with the above:** experiment falsified ·
radial detector *specifically* falsified · rapid-closure response never independently tested
under a working detector · `9691931` may remain a dormant response fallback if future evidence
specifically justifies revisiting rapid closure.

### POSITIVE DATUM — the one thing P17 has proven likeable
**Breon, verbatim: *"I kind of like the lunge."*** Interpreted NARROWLY: the LUNGE has
positive human evidence, so *discrete committed authored displacement* is a promising
direction. This is NOT a universal rule that all committed displacement is good — two
committed-displacement mechanics have already been falsified. What the lunge shares with the
burrow proposal is the shape: **commit → strong authored movement/state change → readable
resolution.** That makes the pivot evidence-informed rather than an arbitrary fourth pursuit
experiment.

### BRAIN CANDIDATES riding with the P17 closeout (recorded, not promoted, gating nothing)
1. **"An authored movement budget must permit the representative trajectory the experiment
   claims to test."** A bounded movement experiment can be mechanically correct yet terminate
   systematically before completing its authored objective. If that is calculable from
   representative trigger geometry *before* play, verify the budget rather than discover
   three-for-three truncation during the human run. **Scope:** this does NOT claim truncation
   caused the falsification — Breon rejected the grammar itself. It concerns experimental
   VALIDITY: prove a bounded action can complete the representative trajectory it claims to
   expose, so the human knows whether they are judging the complete action or a systematically
   truncated form.
2. **"Validate an action before validating its selector."** Scurry showed action quality and
   selector quality can entangle: its detector failed to recognise representative play, so the
   response was never cleanly exercised.
3. *(earlier)* **"Absence from a channel is evidence only if the channel can observe the
   event."**

---

# P17 SUCCESSOR — FANG BURROW v1 · **PRE-CODE SPECIFICATION (FROZEN)**
**APPROVED · NOT IMPLEMENTED at time of writing.** Committed before code so the design is a
fixed target the implementation is measured against.

Fang performs a LARGE BACKWARD JUMP, disappears into the ground, relocates, POPS UP AROUND the
player — ideally behind — pauses briefly as it emerges, then attacks. The identity is a MODE
CHANGE: ordinary engagement → conspicuous disengage → temporarily absent from the combat
picture → reappear → forced target reacquisition → resume combat. The player's problem moves
from *"How do I maintain my kite route?"* to **"Where is the Fang going to reappear, and how do
I respond when it does?"**

Evidence-informed rather than arbitrary: it shares the shape of P17's one positive datum
(*"I kind of like the lunge"*) — **commit → strong authored movement/state change → readable
resolution.**

## STAGE 1 CRITERION (frozen before implementation)
**Burrow passes only if it changes what Breon pays attention to:** the
backward-jump/disappearance/emergence sequence must make him meaningfully REACQUIRE and RESPOND
to Fang rather than continue solving the same frontal engagement. **Verdict is Breon's alone.**

FALSIFIED if it reads as random teleportation · unavoidable behind-you damage · disappearing
only to waste time · cosmetic movement around the same old engagement problem · or a move that
does not change what the player pays attention to.

## STAGING (binding)
- **Stage 1** — controlled, dev-triggered burrow ONLY: jump → disappear → underground → emerge
  → reacquisition beat. Tests mobility and reacquisition. Explicitly NOT gate state, since the
  trigger export must be on. Action-quality verdict.
- **Stage 2** — only after Stage-1 survival: deliberately orchestrate a normal post-emergence
  attack to judge "emerge then attack" fairness.
- **Production burrow stores no Bite/attack target, in either stage.**

PROCESS RULE: *validate an action before validating its selector.* No normal-AI burrow
selection is designed until Stage 1 passes.

## 1. COMBAT-PARTICIPATION FACT — one predicate (ruled)
```
_combat_absent[actor_id] = true    # while not participating; absence from the dict = present
```
**One line into `_is_valid_target`** covers all four consumers at once — melee sweep, projectile
sweep, authored-displacement contact clamp, shield-bump targeting — because they all filter
`_families.keys()` through that single predicate.

TARGETABLE and COLLIDABLE remain **conceptually distinct dimensions, physically fused for v1**.
Burrow needs both OFF together, so splitting identical APIs now would be speculative semantic
surface. **Split when the first real consumer requires different answers.**

| Bypass seam | Ruling | Cost |
|---|---|---|
| `_advance_status_ticks` | **Burn CONTINUES underground** | zero |
| `_advance_contact_spread` | **spread does NOT occur** | one filter term |
| `_cleanup_stale_contact_pairs` | submerge explicitly terminates episodes | one loop at submerge |
| `_decide_single_ai_command` | ordinary AI suspends | one early return |
| pressure (`_record_pressure`/`_pressure_sum`) | **ages normally** across the trip | zero |
| `_apply_attack` | **fail-closed guard**: an absent actor resolves no attack | one guard (belt to the suspended-AI brace) |

Presentation mirrors authoritative participation: `TargetBody` collider + visibility are driven
from the sim's events, never independently. That collider is **dimension 5 — the one no sim gate
can reach** — so the mirror is a cross-layer contract, pinned by test.

## 2. LIFECYCLE
`jump → underground → (emergence attempts) → reacquisition beat → erase, fresh ordinary decision`

Advances in its **own authoritative tick phase** beside `_advance_bump_slides`. Ordinary AI is
suspended underground, but **the burrow lifecycle keeps advancing authoritatively.** Death can
terminate it at any point. Windup committed before burrow is cancelled at submerge via the
existing `_cancel_enemy_windup`.

**JUMP INTERRUPTION:** ANY successful authoritative FLINCH aborts the self-propelled backward
jump, whether it arrived by EXPLOIT or PRESSURE — hooked on the successful-flinch test
(`flinch_reason != ""`), NOT on the deadline-write test used by the two prior mechanics. Those
differ when a flinch lands on an already-flinched actor. Remaining jump movement is FORFEITED,
and **Fang never transitions underground from an aborted jump.** Deliberately does not inherit
P16 bump's continue-through-flinch: bump is imposed motion, this is chosen motion.

## 3. DEATH UNDERGROUND
Underground the Fang cannot be hit at all, so **health reaching zero underground is reachable by
exactly one route: Burn DoT**, which continues by ruling. Not a general case.

Behaviour: death resolves immediately · burrow terminates permanently · **no emergence** ·
normal `died` event · normal death cleanup clears burrow and combat-absence state · no new event
kind · **no special corpse/emergence presentation invented.**

**Recon'd presentation consequence, recorded not solved:** `arena.gd`'s `died` handler
`queue_free()`s a node that is already hidden, so a Burn kill on a burrowed Fang is **visually
silent** — no corpse, no emergence, it simply never returns.

## 4. EMERGENCE — fixed candidate set, retry window, fail-safe death
```
relation     = player_position_at_commit - burrow_entry_position
far_side_dir = normalize(relation)
emerge_point = player_position_at_commit + far_side_dir * burrow_emergence_radius
```
Player position and destination **COMMIT AT BURROW ENTRY.** No underground retargeting, no
blind-spot homing. Player movement after the tell may make emergence less ideal — intended
counterplay.

**DEGENERATE CASE** (`length(relation) < ε`, ε a named constant): fall back to **opposite the
authored backward-jump direction** — already committed state at that moment, and "came up the
far side from where I leapt" is coherent. No RNG, and no multi-Fang de-correlation through the
fallback.

**CANDIDATES:** the far-side direction rotated by a FIXED list — **0°, ±60°, ±120°, 180°** —
tested with the existing contact-distance geometry. No search, no pathfinding. Open-arena scope
only; rooms do not exist yet.

**RETRY WINDOW:** from the underground deadline, re-check all six candidates **every
authoritative tick** until `burrow_emergence_retry_ticks` expires. **Fang must never knowingly
emerge overlapping a collidable actor.**

**TIMEOUT FAIL-SAFE** (a supposedly unreachable open-arena condition, NOT a tuning mechanic):
if the window expires with no valid candidate — no emergence · **Fang dies authoritatively
underground** · normal death cleanup clears burrow + combat-absence · normal `died` event · a
LOUD WARNING naming `burrow_emergence_timeout` as a v1 scope/invariant failure · no special
corpse presentation. The alternative — leaving a living Fang combat-absent for the rest of the
encounter — risks an encounter soft-lock, which is strictly worse than a diagnosable death.

## 5. POST-EMERGENCE
Reacquisition beat completes → **fresh ordinary AI decision** → existing Bite/lunge logic
handles what is appropriate now. No attack target carried underground; existing selection and
fire-time aim law remain authoritative. **Burrow earns position; it does not guarantee damage.**
No damage merely for emerging.

The beat's PURPOSE is banked, not its duration: the player must be able to perceive *"There it
is"* and then locate, turn, reposition/dodge, shield, or apply control. **Categorically unlike
the scurry and cutoff settle beats**, which had no demonstrated player-facing purpose; this one
has an explicit informational function.

## 6. EVENTS — two kinds, both audited
| Kind | Purpose | Audit decision |
|---|---|---|
| `burrow_submerged` | presentation hides + disables TargetBody | printed |
| `burrow_emerged` | presentation shows + re-enables at the new position | printed |

`burrow_jump_started` is **dropped** — no presentation consumer yet. Abort and death emit no new
kinds. **Every new emitted kind must receive a printed-or-explicitly-passed decision in the
retained event-report completeness audit; no unclassified emitted kinds.**

## 7. PROVISIONAL NUMERIC PACKAGE (all PROVISIONAL/UNVALIDATED, outside the M1 numeric fence)
| Field | Value | Reasoning |
|---|---|---|
| `burrow_jump_distance` | 4.0 | more than a second of ordinary movement, delivered fast — a conspicuous disengage |
| `burrow_jump_step_distance` | 0.35 | 10.5 u/s over ~12 steps (0.4 s) |
| `burrow_underground_ticks` | 40 | 1.33 s — long enough to lose track, short enough to avoid "disappearing to waste time" |
| `burrow_emergence_radius` | 2.0 | just outside bite range (1.65), so engaging still costs a step |
| `burrow_emergence_retry_ticks` | 60 | 2.0 s fail-safe window; a transient blockage clears well inside it |
| `burrow_reacquisition_ticks` | 24 | 0.8 s — deliberately longer than the 12-tick bite windup, so response is possible rather than merely visible |
| `burrow_cooldown_ticks` | 240 | production only; Stage 1 is dev-triggered |

## 8. TESTS
**Participation:** absent Fang unhittable by melee · unhittable by projectile · in-flight
projectile continues and expires normally · not bump-targetable · does not clamp authored
displacement · **Burn continues ticking underground** · **contact spread does not occur** ·
submerge erases contact pairs and post-emergence spread works · stored pressure ages normally ·
`_apply_attack` fail-closed for an absent actor.

**Lifecycle:** jump aborts on EXPLOIT flinch · aborts on PRESSURE flinch · an aborted jump never
submerges · remaining jump forfeited · AI suspended underground while the burrow lifecycle keeps
advancing · **Burn death underground fires `died`, erases burrow, and no emergence follows** ·
death cleanup clears participation and burrow state.

**Emergence:** far-side geometry · degenerate fallback uses the jump direction · occupied primary
rotates through the fixed candidate set · **all candidates blocked before deadline → remains
underground, no overlap** · **a candidate becoming free → deterministic emergence** · **deadline
expires → no materialization, normal authoritative death, burrow cleared, warning emitted, no
later emergence** · never overlaps a combat body · determinism across identical runs.

## STAGE 1 — **PASS (Breon, 2026-08-25).** First P17 mechanic to survive a human verdict.

**Verdict against the frozen criterion:** the backward jump reads well · the sequence feels
deliberate and predator-like · the disappearance reads intentionally, *"like it's disappearing
into the bush"* · emergence feels predator-like · **burrow DOES change what Breon pays
attention to** · overall a good mechanic, worth keeping and developing.

Three pursuit-geometry experiments were falsified before this (weave, scurry, cutoff). The
difference is not polish: burrow changed the player's QUESTION rather than the enemy's path.

**Session evidence** (`dd02e63`, full log preserved): 9 burrow attempts, all nine completing
`key → triggered → submerged → emerged`, with Ooze and Watcher correctly refusing all 18 times.
Interleaved across the session and confirming two ruled behaviours in live play for the first
time: a wand shot in flight while the Fang was absent **expired normally rather than hitting or
being deleted**, and a Watcher survey fired undisturbed during another burrow.

**PROVENANCE — commit-then-revert.** `dd02e63` DID carry `debug_burrow_trigger`
committed-enabled; it was enabled in `dd2abbf` and inherited by every later commit, so the PASS
was rendered on a build whose scene had exactly one deliberate `debug_*` override. The pattern,
recorded for reuse: a candidate that must deviate from gate state COMMITS the deviation, so the
running build still equals a commit and the verdict stays tied to an exact hash; the deviation
is then reverted the moment the stage closes, whichever way the verdict went (`678df06`). A
local Inspector flip would have kept the repo clean but produced a build matching no commit,
breaking the traceability every P17 verdict has depended on.

### DEFECT observed and fixed separately (`afd94ea`) — presentation, not mechanics
Breon: on re-entry the Fang *"looked like it quickly flew from off-screen to the emergence point
rather than coming up from underground."*

**Root cause:** the project runs `physics_interpolation=true` at 30 Hz. The sim teleported
correctly in a single tick and the transform never occupied an intermediate position — but to
the RENDERER a one-tick jump is indistinguishable from very fast travel, so it smoothly drew the
trip. **Fix:** `teleport_from_sim()` snaps the transform AND calls
`reset_physics_interpolation()`. No animation added, no timing changed; the jump and
disappearance that playtested well are byte-identical.

**Bug class worth remembering:** invisible to every test that samples the scene tree, because
the artifact exists only BETWEEN physics ticks. Automation can prove the transform teleports and
the node stays hidden throughout; only a human eye could see the interpolation. The verification
declares that limit rather than implying more.

### CAPTURES riding with this closeout
1. **Burrow presentation polish beyond the minimum emergence fix** — a real emerge-from-ground
   animation, dust/ground cue, a submerge tell. Deliberately NOT done as part of the defect fix,
   which was scoped to the minimum that communicates emergence.
2. **PRE-EXISTING ASYMMETRY: the status-tick death path does not call `_clear_reaction_state`;
   the hit-death path does.** Found while wiring burrow cleanup and deliberately NOT absorbed
   into unrelated work. It must be either fixed deliberately or ruled intentional. Burrow works
   around it by cleaning up from its own helper at both death sites, which is why a Burn death
   underground does not leak combat-absence — but the asymmetry itself is untouched and still
   owns whatever else `_clear_reaction_state` covers (pressure, parry exposure, bump slides) on
   a status death.

---

# STAGE 2 — EMERGE → ATTACK FAIRNESS · **PRE-REGISTERED**

**Question:** does the reacquisition beat provide a GENUINE response window before the
post-emergence attack, or merely a visible one? **Verdict is Breon's alone**, rendered on the
committed Stage-2 candidate.

**Production burrow stores no Bite or attack target.** The attack that follows is an ordinary
AI decision under existing selection and fire-time aim law. Controlled orchestration (the dev
trigger) exposes the sequence reliably; it does not manufacture the attack.

**Measured chain, shipped values** (`tools/diagnose_burrow_chain.gd`, reported not tuned):

| | player stationary | player retreating |
|---|---|---|
| jump → submerge | 11 ticks (0.37 s) | 11 ticks (0.37 s) |
| submerge → emerge | 40 ticks (1.33 s) | 40 ticks (1.33 s) |
| emerge → telegraph | 28 ticks (0.93 s) — beat + approach, no attack may start | **never attacked** |
| telegraph → hit | 12 ticks (0.40 s) — the tell itself | — |
| **EMERGE → HIT** | **40 ticks (1.33 s) total response window** | — |

The retreating case is the counterplay working: the destination commits at burrow entry, so a
player who keeps moving leaves the Fang surfacing too far away to reach them at all.

**FALSIFIED if** the attack lands before the player can realistically respond · the beat reads
as visible but not usable · emergence-plus-attack feels like an unavoidable ambush rather than a
readable one · or the sequence is threatening but unfair.

## STAGE 2 — **PASS (Breon, 2026-08-28).** The burrow ACTION is validated.

**Verdict:** can locate / turn / respond before the attack · emerge→attack feels fair · the
reacquisition pause is appropriately timed · the attack follow-up strengthens Fang's predator
identity · no additional mechanical concerns.

**ACTION-VALIDATION PHASE CLOSED. Stage 1 PASS + Stage 2 PASS.** Six of the seven authored
values are now VALIDATED-FOR-ACTION and **FROZEN**: jump distance and step, underground
duration, emergence radius, emergence retry window, reacquisition beat. **Do not tune them
without contrary playtest evidence** — two mechanics were already lost by iterating on the wrong
layer, and a validated action is not a place to go looking for improvement.

**`burrow_cooldown_ticks = 240` remains PROVISIONAL**, deliberately: it paces how OFTEN the
action happens, and nothing has yet decided WHEN it happens at all. It is validated only once a
selector exists and is itself validated.

**Housekeeping:** Stage-2 trigger reverted, canonical build back to gate state (zero `debug_*`
overrides). Commit-then-revert applied for the second time, as designed.

### BITE-DISPLACEMENT CLASSIFICATION (asked and answered before classifying)
**Does the shipped Bite profile author displacement after telegraph? NO.**
- `fang_bite.tres` authors none;
- `NaturalWeaponStats` has **no displacement fields at all** — an enemy action cannot author any;
- `register_weapon`, the flat path every enemy action registers through, takes no lunge params;
- every `entities[actor_id]` write in the sim is accounted for — `_apply_move`, the PLAYER's
  melee lunge, bump slides, and burrow. `_resolve_melee_swing` never moves the attacker.

So presentation is **not** hiding authoritative sim motion; the Fang genuinely stands still
through its bite. **Filed as attack-movement animation/presentation debt**, not a presentation
defect. Related to, and distinct from, P28's still-open weapon-reach/animation revalidation
trigger and P32.

---

# P17 FINAL LEG — BURROW SELECTOR · **PROPOSAL, AWAITING REVIEW. NO CODE.**

The action is validated; production Fang still has no way to choose it. Selector work inherits
the standing doctrine: **the validated action stays frozen**, the selector is a design proposal
first, trigger observability must be provable, and it must not repeat scurry's structurally
blind detection.

### 1. WHERE THE DECISION LIVES
**NOT the P29 repertoire.** That law scopes action selection to attack SHAPE chosen by distance
band; burrow is mobility, and giving a non-attack a band would corrupt the law it would be
borrowing. The burrow gate belongs in `_decide_single_ai_command`, in the pursue branch,
**after** the attack-eligibility check — so a Fang that can bite always bites, and burrow is
what it does when the frontal approach is not available.

### 2. THE SIGNAL — three forks, costed
| Fork | Cost | Blindness profile | Risk |
|---|---|---|---|
| **A. Close-range frustration** *(lean)* | Reuses `_ai_last_in_close_band`, an existing, proven, already-instrumented fact (Watcher survey) | Measures the FANG'S OWN achievement — "did I reach close range" — not the player's velocity. Therefore sensitive to every kite shape that actually denies engagement, including the diagonal case that made scurry blind (at 45° the Fang gains only 0.17 u/s, so ~35 s to close from 6 units). Correctly does NOT fire while the player circles in contact, because engagement is working | Trips P29's naming fence — see §3 |
| **B. Health threshold** | `_health` exists; zero new state | None — a fact about the Fang, always evaluable | Says nothing about whether the frontal approach is working; fires at a fixed HP so it becomes predictable, and needs the cooldown to avoid spamming at low health |
| **C. Post-flinch disengage** | `_flinched_until_tick` exists | None | Likely feels BAD: the player lands a combo and the enemy vanishes, which reads as escaping punishment and rewards the enemy for being hit |

**Lean: A alone for v1.** It is the only fork that answers the question the burrow exists to
answer, and it is the only one already observable. B is a plausible later addition as an
independent second trigger; C is not recommended.

### 3. THE FENCE DECISION THIS FORCES
P29's naming fence states that `requires_close_frustration` / `close_frustration_ticks` stay
deliberately narrow, and generalise to a shared context concept **only when a second real
consumer exists**. A burrow selector on fork A **would be that second consumer** — the rule of
two fires, and it needs a deliberate answer rather than a default:
- **generalise** the vocabulary into a shared "failed engagement" fact used by both, or
- **duplicate narrowly** for burrow, keeping the Watcher's gate untouched.
Surfaced, not decided. Same shape as the extraction decision that was deliberately answered NO
at consumer #2 for authored displacement.

### 4. GUARDS
Off cooldown · not already burrowing · not mid-windup (structurally excluded — the attack gate
returns before this point). A minimum-distance guard is probably redundant, since a frustrated
Fang is by definition not close, and should not be added without evidence it is needed.

### 5. OBSERVABILITY — mandatory, and pre-registered
`debug_describe_burrow_selection(actor, player)` reporting each condition's LIVE value against
its threshold — frustration elapsed vs required, cooldown remaining, distance — plus an arena
`debug_show_burrow_selection`. The scurry's detector was falsified by an autopsy that should
have been run before play; the selector must be diagnosable from a log without re-deriving it.

### 6. PRE-REGISTERED DETECTOR VERIFICATION — before any human play
A diagnostic must prove, on shipped content, that the trigger:
- **fires** under sustained diagonal kiting, standoff at range, and wall-hugging retreat;
- **does not fire** during ordinary close engagement or while the player circles in contact.
Explicitly modelled on the scurry autopsy. A selector that has not been run against the movement
shapes players actually use is not ready for a human.

### 7. PRE-REGISTERED HUMAN CRITERION
The selector passes only if burrow **appears at moments that read as the Fang deciding the
frontal approach is not working** — the player should be able to feel why it happened.
**FALSIFIED if** it reads as arbitrary · fires so often it becomes a rhythm rather than an event ·
never appears in ordinary play · or makes the Fang feel evasive rather than predatory.
`burrow_cooldown_ticks` is the tuning lever for frequency, and is the ONLY burrow value still
open.

### SELECTOR — IMPLEMENTED (2026-08-28). P17's final leg.

**Signal:** close-range frustration. Health-threshold and post-flinch forks rejected for v1 —
the first does not measure failed engagement, the second selects around punishment rather than
around inability to establish pressure.

**Gate:** `_decide_single_ai_command`, in the pursue branch, AFTER the ordinary attack check. If
a valid attack exists, frontal engagement is succeeding and burrow must not replace it.

**Rule-of-two ruling applied:** the exact shared FACT was consolidated — close-range frustration
/ failure to achieve close engagement — and nothing more. `_ai_last_survey_commit` →
`_ai_last_frustration_commit` as a behaviour-preserving rename; `_close_frustration_satisfied`
and `_refresh_close_proximity` remain the shared primitive; `requires_close_frustration` stays
action-authored on `NaturalWeaponStats`; burrow is not a repertoire action, so Fang's selector
consults the predicate directly. **The primitive was NOT broadened.** Watcher's suite is the
pin: the only test touched was a single identifier reference, with its assertion, setup and
expected outcome untouched.

**Episode semantics, as ruled:** nothing increments — frustration is `tick_count −
_ai_last_in_close_band`, a timestamp going stale · reset by re-entering the close band or by
aggro acquisition (`_acquire_aggro` writes it, which is why disengage→re-acquire starts clean) ·
success is POSITIONAL presence inside the band, nothing else · ordinary attacks do not affect it
and the refresh precedes the mid-windup return so a biting Fang keeps refreshing · **burrow
consumes the episode at commitment, identically to Survey** · cooldown is an independent floor.

**One burrow per unresolved close-frustration episode** — not "once per pursuit". Fang's band is
[0, 1.65] and emergence lands at 2.0, so **emergence does not itself clear the episode**; the
Fang must still close the last 0.35 units. Player stays → Fang closes → episode resets →
frustration may accumulate normally. Player keeps retreating → band never re-entered → episode
stays spent → no burrow spam during that unresolved pursuit. Anti-repetition is structural, not
tuned.

**DEFECT FOUND AND FIXED during implementation:** `close_frustration_ticks = 0` was satisfied on
every tick, so any burrow-authoring actor with no authored patience would have committed one at
its first opportunity forever. **A zero patience now means NO SELECTOR**, never instant
frustration — absence is off, the rule the rest of the file follows. Warned at registration.

**Values:** `close_frustration_ticks = 90` (3.0 s) is a FIRST SELECTOR HYPOTHESIS, not
validated. Matching the Watcher is a coincidence of scale, not coupling.
`burrow_cooldown_ticks = 240` remains PROVISIONAL and may prove mostly inert, since the episode
is the primary limiter. **Neither is tuned before ordinary-play evidence.**

**PRE-REGISTERED DETECTOR PROOF — 14/14 on shipped content** (`tools/prove_burrow_selector.gd`),
run before human play as the scurry autopsy should have been:
fires under diagonal kiting (tick 90) · fires under sustained standoff (tick 90) · fires under
straight-line retreat at ordinary move speed (tick 90) · does NOT fire during ordinary
successful close engagement · resets on disengage→re-acquire (80 → 2 elapsed) · consumption
blocks repeat until genuine close-band re-entry, with the snapshot reporting WHY · cooldown
suppresses an otherwise-valid rebuilt episode.

**GEOMETRY NAMED HONESTLY.** The wall-hug case was replaced: the arena has no walls, so the
low-closure-rate case is straight-line retreat, where the gap is governed purely by the speed
differential (Envoy 4.0 vs Fang 3.0 = −1.00 u/s). And "sustained standoff" as first written was
not a standoff at all — a stationary player at range is SUCCESSFUL engagement, since the Fang
simply walks up. A genuine standoff is a HELD GAP, realised by speed-matching the player so the
separation never closes.

**Observability:** `burrow_committed` carries source (selector vs debug) and the frustration
elapsed at commitment, so an ordinary session log says WHY. `debug_describe_burrow_selection`
reports every condition's live value against its threshold.

### PRE-REGISTERED ORDINARY-PLAY CRITERION (frozen verbatim)

> **"Does Fang choose the validated burrow at moments that make its predator identity stronger
> without becoming repetitive, arbitrary, or an escape from engagements that were already
> working?"**

**Verdict is Breon's alone**, rendered against that exact sentence, on the committed ordinary-AI
candidate. **Burrow frequency is instrumented and reported as a FINDING, not judged against a
preselected target.** No further burrow ACTION tuning unless selector play produces contrary
evidence.

### SELECTOR — **PASS (Breon, 2026-08-28). P17 CLOSED.**

**Verdict against the frozen criterion:** ordinary AI chose burrow in appropriate situations ·
burrow improved Fang's predator identity · it did not become repetitive or arbitrary · no
general selector or frequency concern surfaced.

**INSTRUMENTED FINDING, not a target:** 6 burrows across the session, all `source: "selector"`,
five committing at `frustration_elapsed: 90` (the threshold exactly) and one at `127` — the
latter matured while suppressed by either the cooldown floor or a still-spent episode, then
fired once clear. Six commits, six submerges, six emergences; no aborts, no timeouts, no repeat
inside an unresolved episode. **Recorded as an observation. Nothing tuned from it.**

**FROZEN:** `close_frustration_ticks = 90`, `burrow_cooldown_ticks = 240`, emergence geometry,
and the validated burrow action. No tuning without contrary evidence.

### FIRST-BURROW ANOMALY — CLASSIFIED, NO DEFECT, NO CHANGE
Reported once, on the first burrow only: Fang emerged in front of Breon, appeared not to
respond, and resumed only after he attacked it.

**Answered from the captured session evidence:**
- **Did the lifecycle exit and erase its state?** YES — and the log proves it independently: the
  SECOND burrow committed at `frustration_elapsed: 90`, which requires the Fang to have
  **re-entered its close band** (clearing the spent episode) and then failed to close for 90
  fresh ticks. It could not have done either while suspended.
- **Did ordinary AI resume?** YES. Successive projectile hits track the Fang from `(-9.11, 2.53)`
  through `(-1.52, 0.86)`, `(0.07, 0.75)`, `(2.37, 0.64)`, `(4.57, 0.55)` to `(7.37, 0.44)` —
  it was pursuing the retreating player the whole time.
- **Position/distance after emergence:** emerged at `(-4.27, 2.61)`; the player's next shot came
  from `(-2.97, 0.31)`, about **2.6 units** away.
- **Active/aggroed?** YES — proven by the later selector burrow, which the selector cannot reach
  from an inactive actor.
- **Decision-suppressing state?** **YES, and this is the cause.** Two `shield bumped` events land
  on the Fang immediately after emergence. A bump slide suppresses the bumped actor's own move
  Command for its whole duration — locked P16 behaviour, authored displacement replaces
  locomotion. Shipped values are 2.5 units over 10 ticks with a 45-tick cooldown, so two bumps
  span ~65 ticks, and the emergence-to-first-hit displacement of ~4.8 units matches two bumps'
  worth of 5.0 almost exactly. Stacked on the 24-tick reacquisition beat, that is roughly a
  second and a half of legitimately suppressed locomotion at precisely the moment a player is
  watching for a reaction.
- **Were ordinary move Commands emitted while it looked still?** NO — correctly. The beat
  suspends AI by design; the bump slides suppress locomotion by design.
- **Did the attack change a state that explains resumption?** **NO — the timing was
  coincidental.** A wand hit clears no bump slide and alters no AI state, and the Fang was
  already active. The weapon switch and first shots simply coincided with the slides expiring.

**VERDICT: valid existing behavior, compounding.** Two independently validated mechanics — the
Stage-1/2-validated reacquisition beat and the locked P16 bump — overlapped at the worst moment
for readability. Recorded and closed with **no change**, per the standing rule.

Pinned by `test_post_emergence_stillness_is_bump_suppression_not_leftover_burrow_state`, which
asserts the burrow record and combat-absence are BOTH gone, that ordinary AI is demonstrably
pursuing, and that a bump then holds the Fang still anyway — so post-emergence stillness can
never again be misattributed to burrow state.

**Observation filed, not acted on:** a freshly-emerged Fang is bump-eligible before it acts. That
is a balance question about two validated mechanics meeting, not a defect, and it needs its own
evidence before anyone touches either.

---

# P17 — **CLOSED 2026-08-28.**

Four experiments, three falsified, one validated across three human gates.

| Experiment | Verdict | Lesson banked |
|---|---|---|
| Approach weave | FALSIFIED | *A different path is not a different decision* |
| Scurry | FALSIFIED (detector specifically) | *Closing distance is not the same as contesting movement* |
| Cutoff | FALSIFIED BY PLAY | grammar rejected upstream of any number |
| **Burrow** | **PASS × 3** (action Stage 1, fairness Stage 2, selector) | mode change beats path geometry |

Fang now has a validated ambush identity chosen by ordinary AI. **Frozen** unless contrary
evidence appears.

**Debts and captures carried out of P17** (none silently absorbed): burrow presentation polish
beyond the minimum emergence fix · attack-movement animation debt (the shipped Bite authors no
displacement, confirmed at four levels) · the `_clear_reaction_state` asymmetry between the
hit-death and status-death paths, to be fixed deliberately or ruled intentional · the
bump-on-emergence readability observation above.

### FENCES
The validated action stays frozen · no selector implementation before proposal approval · no
generic context framework without the §3 ruling · no Ooze/Watcher changes · no multi-Fang
coordination · the human verdict remains Breon's.

## FENCES
No generic teleport framework · no generic phasing framework · no steering/pathfinding · no
route prediction · no damage on emergence · no guaranteed Bite inside burrow · no continuous
underground homing · no Ooze changes · no Watcher changes · no multi-Fang coordination · no
normal-AI selection or repertoire tuning before a Stage-1 PASS · the human fun verdict remains
Breon's authority.

### P18 — Idle wander + return-to-post + room territory
**Idea:** Three related post-disengage behaviors, captured together since they all
sit on top of the same M1 disengage-in-place mechanic (Phase D step 8 pre-gate fix
pass — no universal return-to-spawn; an idle enemy just stands at its re-anchored
position):
- **Bounded idle wander** — the first AI behavior that needs genuine randomness.
  Must draw from its OWN dedicated `RandomNumberGenerator` stream per GAME-RULES
  §1.3, never `_combat_rng` (BRAIN's existing "one draw site" invariant for that
  stream extends naturally: a new behavior needing randomness gets a new stream,
  it never reaches for an existing one).
- **"Return-to-post"** — an authored FAMILY TRAIT (some enemies patrol back to a
  post-disengage anchor, some don't), not a universal rule reinstated. A natural
  fit for Watcher/Custodian specifically, per the motion-language law (WORLD-CANON/
  GAME-RULES §6.8): Claimed states share rhythm/synchronized pacing, and returning
  to a post reads as disciplined/synchronized in exactly that way.
- **Room/encounter-based territory bounds** — once M2 floor generation exists,
  leash/detection radii graduate from "distance from an anchor point" to "bounded
  by the room/encounter the enemy was placed in." The current anchor-point model is
  the correct M1 placeholder, not a design to defend past M2.
**Reasoning:** All three are the natural next layer once M1 proved the minimal
disengage-in-place model works; none of them belong in M1 (GAME-RULES §5 M1 gate
doesn't ask for idle personality or floor-aware territory, and M1 has no rooms yet
for the third item to even attach to).
**Why deferred:** M2 — wander/return-to-post are content-pass work like P17 (may
even land in the same session); room-based territory is gated on M2 floor
generation existing at all.

### P19 — Per-family mass/knockback factor
**Idea:** A per-family mass/knockback-resistance factor, applied ONLY at the shared
hit-knockback resolution point in the combat pipeline — never to self-movement,
scripted movement, or (until deliberately tested) shield-break recoil. A heavy
family gets pushed less by the same hit; a light one gets pushed more.
**Reasoning:** Own front door, not folded into an existing proposal, because it's a
genuinely separate mechanic from engagement AI (P17) or charge profiles (P5
addendum) even though it shares the combat pipeline with both. Weight binds to
FAMILY/body archetype, never to entity STATE (Common/Drifted/Claimed) — GAME-RULES
§6.8's three-axis law: a Claimed Fang is still light. Any future state-based
displacement resistance is a deliberate state modifier, decided at M2's state-
content pass, not an accidental side effect of this factor.
**Design questions:** Where the factor lives in content (per-family stats resource
vs. a new shared table); whether shield-break recoil ever adopts it, and if so
under what evidence.
**Update (2026-08-11, combat-advisory arc): SECOND CONSUMER CONFIRMED** — knockback
resistance/weight is now wanted by two independent mechanics, which satisfies this
entry's own trigger condition: (1) melee sequence coherence — knockback from an early
combo hit can push a target out of reach of the next authored hit, and (2) ranged
follow-up range — the same displacement walks a target off a repeat-fire weapon's line
(the shipped `wand_A.knockback_distance = 0.0` is that problem already solved by
deletion rather than by weight). Still NOT in the post-gate combat batch — recorded so
the trigger isn't re-litigated later. No family-specific hacks in the meantime.
**Why deferred:** trigger met, but sequencing puts flinch first — flinch changes how
often knockback even matters, so tuning weight before it would be tuning against a
baseline about to move.

### P20 — Sim movement collision/bounds
**Idea:** Authoritative movement collision in sim/ — arena bounds (walls) and
body-blocking between actors. Confirmed by direct read this session: `_apply_move`
is unconditional `position += direction * speed * dt`, and nothing in the codebase
(sim or presentation — the Envoy's CharacterBody3D never calls `move_and_slide`/
`move_and_collide`) constrains movement at all today.
**Reasoning:** Manual-pass forward lunge (GAME-RULES §3) inherits and exposes this
directly — a lunge is authored displacement with the exact same lack of constraints
ordinary walking has, so it can carry an actor through a wall or through another
actor's body just as easily as walking already can. Recorded explicitly as a known
M1 limitation rather than solved inline (see HANDOFF).
**Update (2026-08-05):** the lunge-vs-hostile-contact pass-through case specifically
is now fixed (`SimWorld._find_earliest_lunge_contact`/`_contact_distance`) —
authored attack movement clamps to a living hostile's combined-combat-radii contact
distance, sharing one formula/epsilon with Burn's contact-spread. This is
attack-authored movement semantics, not a general collision layer: ordinary
walking, enemy movement, walls, and actor-vs-actor separation in general remain
exactly as unconstrained as before. **P20 stays fully open** for all of that — this
was a narrow, lunge-specific fix, not a down payment on general collision.
**Design questions:** Wall bounds first (arena is currently a flat 40x40 box with no
interior geometry, so this is moot until M2 floor generation adds walls) vs.
body-blocking first (relevant now, three enemies + Envoy can already overlap);
whether this lives as a generic sim-side collision pass or per-system clamping
(movement, lunge, knockback each currently free-write `entities[actor_id]`).
**Ally-separation question (open, raised by the lunge-clamp fix):** the lunge clamp
deliberately never targets allies (`_find_earliest_lunge_contact` is hostile-only,
matching the existing hit-detection ally filter). Whether allies should ever push
apart from each other — a co-op-relevant question once multiple players share the
arena in M3 — is undecided and NOT answered by this fix; it's a separate future
design call, not folded into general body-blocking above by default.
**Why deferred:** No wall geometry exists yet to make bounds meaningful (M2 floor
generation gates that half); body-blocking has no trigger yet beyond "it looks odd"
— revisit if playtesting finds overlap actively hurts readability/fairness, or when
M2 floor generation lands and walls become real.

**UPDATE 2026-08-28 — THE WALL HALF IS CLOSED (M2 Slice 1).** M2 floor generation
landed, so walls became real and this entry's own trigger fired. `WalkableBounds`
(`game/sim/walkable_bounds.gd`) is now the sim-authoritative walkable law for a
loaded floor; Godot wall meshes are a rendering of it, never its source (GAME-RULES
§4.6 — a server must be able to validate a position).

A pre-implementation audit re-enumerated every authoritative write to
`SimWorld.entities[]` and **found the remembered P17 list stale**: it named move /
lunge / bump / burrow but omitted BOTH knockback paths and registration placement.
All eight sites now consume the seam, and `tests/test_floor_bounds.gd` drives each
one at a wall:
- DISPLACEMENT (clamped, per-axis so wall contact slides rather than sticks):
  `_apply_move` · melee lunge · hit knockback · shield-break knockback · bump slide ·
  burrow backward jump.
- PLACEMENT (refused, never clamped): burrow emergence candidates · `add_entity`.
  An out-of-bounds spawn fails LOUDLY and registers nothing — silently relocating it
  would hide a generator defect behind a floor that merely looks odd.
Bounds are OPTIONAL (`_bounds == null` ⇒ every seam is identity), which is why the
whole pre-M2 suite is unaffected by construction rather than by luck.

**STILL OPEN, and still P20's:**
1. **Actor-vs-actor body-blocking.** Untouched. Enemies and the Envoy still overlap
   freely; the generator works around it with `min_spawn_separation` rather than the
   sim solving it. The ally-separation question (co-op relevant, M3) also stays open.
2. **PROJECTILE-VS-WORLD COLLISION — the named Slice 1 fence.** Projectiles
   deliberately do NOT consume the bounds seam. Slice 1 floors are single convex
   chambers, so a shot leaving the walkable rect has already left the play area and
   `projectile_max_lifetime_ticks` retires it through the existing
   `projectile_expired` Event. Ruling it in now would mean inventing impact-position
   and status-drop semantics against no geometry. **This is a decision, not an
   oversight** — recorded here as well as at `SimWorld._advance_projectiles` so it
   cannot be mistaken for one. **TRIGGER TO REVISIT:** the first floor with interior
   geometry or a non-convex chamber. Body displacement obeys bounds today; this fence
   covers world/projectile collision only.
3. **No navmesh, pathfinding, obstacle graph, or multi-rect doorway handling.**
   `WalkableBounds` is axis-aligned rects and two predicates, and `clamp_step`'s
   multi-rect path is explicitly untested — Slice 1 authors exactly one rect per floor.

### P21 — Arena camera-follow
**Idea:** The M1 arena's `FixedCamera` doesn't track the Envoy — noted this session
while repositioning Watcher's station specifically because its old position sat
outside the fixed camera's forward view entirely.
**Reasoning:** A camera that doesn't follow the player becomes a real usability
problem the moment the arena is large enough for the player to walk off-frame (the
40x40 geometry fix already makes this plausible at the perimeter stations).
**Why deferred:** M1's fixed framing is sufficient for the current combat-slice
testing footprint; not worth the scope now. Revisit if the manual re-pass finds
perimeter-station movement walking the Envoy off-frame.

**UPDATE 2026-08-28 (M2 Slice 1): this is now a CONSTRAINT ON CONTENT, not just a
comfort issue.** `StratumConfig.chamber_max_size`'s Z ceiling (26) exists because the
`FixedCamera` at (0, 12, 12) walks the entry point off the bottom of frame on a deeper
chamber — the generator is being sized around the camera. The chamber's south wall
already sits marginally outside the frame at the current maximum. Recorded so the
ceiling is never mistaken for a design preference: **when P21 lands, that number is the
first thing that should rise.**

### P22 — Buffer eligibility during charge windup
**Idea:** Extend the mid-swing input buffer (built alongside the lunge/windup
pending-attack record) to cover the `windup` state too, buffering a press against a
PROJECTED `end_tick` (`windup_end_tick + charge_profile.lunge_duration_ticks`)
rather than today's rule where any press during windup is unconditionally rejected
`mid_swing`.
**Reasoning:** The projected deadline is already computable with existing fields —
this is a scope cut for engineering-complexity reasons (another branch in an
already-dense state machine), not a technical wall. Recorded explicitly so "charge
windup can't buffer" is never mistaken for a design law later.
**Why deferred:** No evidence yet that it's needed — the third manual-pass round's
re-pass found no complaints about mid-windup presses feeling dropped. Revisit if a
future playtest surfaces windup-press frustration specifically.

### P23 — Graded player poise
**Idea:** Mirror the existing player-interrupts-enemy `interrupt_strength` mechanic
in the other direction — enemy attacks would need a threshold to interrupt a
player's pending windup/executing attack, instead of today's M1 rule where ANY
non-lethal hit cancels unconditionally.
**Reasoning:** The lunge/windup pending-attack system (third manual-pass round)
ships player poise as a deliberate M1 simplification, not a permanent design law —
see `SimWorld._resolve_hit_on_target`'s interrupt-site comment and HANDOFF's
"Manual-pass follow-up session" note. **Trading-feel evidence:** the manual re-pass
on this round (2026-08-05) explicitly watched for "trading during lunge feels
terrible" and reported no new findings — no complaint surfaced. That's one data
point against urgency, not a verdict; a longer/less scripted playtest could still
surface it.
**Why deferred:** No evidence of a problem yet (see above); building graded poise
speculatively would be exactly the kind of future-proofing AGENTS.md warns against.

### P24 — Reactions beyond flinch + enemy action-phase structure
**Idea:** Everything in the reaction space the post-M1 combat batch deliberately does NOT
build, kept together because they all wait on the same evidence (does flinch prove fun?):
- **Knockdown** — the next reaction after flinch. Its arrival is the SECOND consumer that
  triggers evaluating shared reaction infrastructure; until then flinch stays a concrete
  actor state, not a framework (§1.4 rule of two).
- **Player-side reactions** — future design space. Do NOT generalize the enemy FLINCHED
  state to cover the player now; player poise is its own proposal (P23).
- **Enemy action-phase structure, incl. punishable recoveries** — M1 enemies have exactly
  ONE authored phase: a windup (`_ai_attack_start_tick`/`_ai_attack_fire_tick`), then an
  instant resolve. There is no recovery phase to make vulnerable, no multi-phase action
  object, and no authored displacement inside an action. The batch's per-action
  VULNERABLE window therefore lands as an offset pair inside the windup only; "bait the
  attack, punish the recovery" needs this proposal first.
- **Two disjoint vulnerability windows** in one action — deferred until an enemy needs it;
  the batch ships base-mode-outside / interval-overrides-to-VULNERABLE, which already
  expresses protected-early/vulnerable-late as base PROTECTED + a late interval.
**Reasoning:** the batch's flinch system is the first reaction this project has ever had.
Every item here is a second or third instance of a pattern with exactly one instance.
**Why deferred:** all of it is gated on the batch playtest answering "is being able to
control an enemy's actions fun, and at what frequency?"

### P25 — Weapon-owned state & switch semantics
**Idea:** The general form of a question M1 currently answers by accident. Today
`_next_fire_tick` is actor-keyed (cooldown CONTINUES across a switch), `_melee_hold` is
cleared (charge CANCELS), and `_combo_index` is cleared (sequence RESETS) — which happens
to match the intended defaults exactly, but nothing states them as a contract. Covers:
- **Declared holstered semantics per state CATEGORY**, with content override where a
  weapon differs, rather than per-state authoring on every content entry.
- **Switch-reset tech** — investigate-only. Adopt only if switching ever carries real
  commitment. Any M1 conclusion is provisional with an explicit revalidation trigger when
  the loadout expands toward four weapons + shield (P5's slot-count addendum).
- **Universal switch transition time/cost** — a legal future LOADOUT-system decision if
  ever wanted. Explicitly NOT derivable from the commitment/recovery principle; no global
  switching restriction now.
- **Ammo / reload / magazine state** — only when a concrete weapon's decision loop needs
  resource cycling. Holstered semantics must be settled BEFORE any resource whose
  behavior depends on unequipping. Magazine state is weapon-owned; no universal
  switch-refill; no generic persistence framework ahead of a consumer.
- **Per-weapon combo state** — `_combo_index` is per-actor, not per-weapon. Correct today
  only because a switch wipes it. A second combo weapon that should REMEMBER its step
  while holstered forces this.
**Invariant that survives all of it:** attack→switch→attack must never reach privileged
sequence states more cheaply than the normal economy permits.
**Why deferred:** one combo weapon and one gun cannot demonstrate a switch economy.

### P26 — Ranged weapon identity futures
**CONTENT DEBT — pre-correction projectile radii (recorded 2026-08-14, P29 item 3).**
Projectile collision now resolves at `projectile.hit_radius + target.combat_radius`, so
`hit_radius` means the projectile's OWN volume and nothing else. The two ACTIVE values
were re-derived accordingly (wand_A 0.40 -> 0.20, watcher_survey 0.50 -> 0.20).
`gun_pierce_A`, `gun_arc_A` and `gun_umbral_A` still author the PRE-CORRECTION 0.4. They
are deliberately untouched: they are dev-carousel only, and dormant numeric content is not
retuned without a consumer. **Trigger:** re-derive them when any of those weapons enters
an active loadout or a validation slice. Recorded here ONCE rather than annotated into
each dormant resource — the note belongs with the ranged-weapon docket, not scattered
across content nobody is reading.


**Idea:** Ranged depth arrives through content-authored projectile / commitment / control
behavior, never a universal projectile behavior graph. Identity = a CHANGED COMBAT
DECISION; one new lifecycle behavior at a time. The M1 wand is deliberately the simple
baseline. Candidates: distance-band transformation · committed burst · ricochet/geometry
(needs authoritative walls, so M2 at the earliest) · heavy recoil cannon (needs
displacement + re-hit maturity) · persistent hazard + displacement (damage collision ≠
movement collision ≠ AI-nav influence, all explicit — a damaging field is not
automatically navigation-blocking) · setup/detonation marks (snapshot-vs-resolution
semantics, lifecycle cleanup, cross-player permission, no recursive chains; the solo loop
must be complete without allies) · owner-relative/return projectiles (explicit
authoritative compound state, never invisible helper actors).
**First advanced consumer note (not scheduled):** committed burst / simple charge gun —
composes with the existing charge input, flinch vulnerability, and the commitment
principle without needing walls or persistent state.
**Also parked here:** direct charge access for future charge guns (hold begins charge, no
sacrificial precursor shot) · charge chaining (HOLD_TO_CHAIN vs FRESH_PRESS) only when a
weapon needs it · shield bump/displacement as a ranged-loadout spacing tool (revisit after
flinch validation and P19) · delayed-effect snapshot semantics · explicit projectile
defense-interaction traits (blockable / pierces / terrain / friendly-fire) as authored
data, never subclass accidents · **target-facing displacement**, which first requires
DEFINING authoritative gameplay facing (movement heading vs aim vs attack-facing vs
AI-facing vs a dedicated sim orientation — these currently disagree); that is its own
design/authority fork at the first consumer and must never be smuggled into a knockback
helper · **co-op obstruction as a first-class balance metric** ("does optimal use
repeatedly invalidate teammates' correct decisions?" — priced or redesigned) ·
generalist/Force damage needs a POSITIVE identity once typed loadouts matter ("neutral"
≠ specialist-without-upside) · environmental utility axis (destructibles, switches,
hazard triggering) when levels consume it.
**Why deferred:** the M1 gun proves the projectile pipeline; every item above is a second
weapon's job, and several are gated on M2 geometry existing at all.

### P27 — Multi-hit / attack-instance model
**Idea:** Attack-instance hit legality is a SEPARATE question from global health
i-frames. M1 has no multi-hit mechanic at all — verified by probe (2026-08-11): one swing
produces exactly one hit per target, a projectile hits once and expires, and a status DoT
bypasses i-frames entirely. So one i-frame value currently does exactly one job. Covers:
- **Re-hit eligibility** for staged multi-hit charges (the Brandish-style line, P5
  addendum): per-stage i-frame policy, per-stage knockback/flinch/status eligibility (NO
  naive independent per-stage proc rolls — 5×30% ≈ 83%), shield-break and death
  mid-sequence, attacker cancel commitment.
- **Cross-attacker i-frame/pressure suppression** — i-frames are target-global and
  source-agnostic today, so in M3 co-op two players' hits would suppress each other, and
  one player's hit would eat another's pressure contribution. No current consumer (single
  player), and the fix is explicitly NOT attacker-scoped i-frames by default — that's the
  decision this proposal exists to make deliberately.
- **Attack-instance identity** — `projectile_id` exists; nothing else has an instance id.
- **Co-op pressure attribution** — M1 records pressure contributions with no attacker
  attribution (no shares, no assists). Any future attribution rides here.
**Reasoning:** own front door because "how often may a target be hit" is a different
question from "how long is a target merciful after being hit," and conflating them is
exactly what produced the M1 combo-cadence defect (BRAIN).
**Why deferred:** defined by the first real multi-hit consumer; constrained until then
only by the recorded audit above. Do not pre-build.

### P28 — Global combat-scale coherence pass
**SPATIAL-COHERENCE DEBT — Ooze vertical artifact (recorded 2026-08-17, P29 re-playtest).**
Observed: the Ooze's 3D SILHOUETTE and its ground-plane FOOTPRINT disagree — combat
resolves on a horizontal circle while the model reads as a tall spiked mass, so contact
can look wrong vertically even when it is horizontally correct.
**DO NOT touch `combat_radius`.** It is the authoritative body radius shared by Burn
contact-spread, the melee lunge clamp, bump and (since P29) projectile collision; moving
it to fix a vertical reading would break four horizontal systems that are correct.
**Not scheduled.** Schedule only if a future session reports it as UNFAIR rather than
merely odd-looking. The likely fix lives in presentation or in a future vertical
dimension to contact, not in the existing radius.


**Status: RESOLVED for M1 (2026-08-13) — hypothesis NARROWED BY BETTER MEASUREMENT,
not confirmed.** The barrier is lifted; live tuning may proceed. Do NOT reopen without
a concrete new spatial finding.
**Outcome:** there was no need to globally rescale the combat system. Core-silhouette
analysis (radial p50 across each model's torso band) plus a live playtest showed the
defect was primarily **Ooze's undersized authored footprint** — 0.70 against a real
body of ~1.45, roughly half — with minor cleanup elsewhere. The earlier "contact ≈3.2
vs reach 2.0, therefore impossible" reading was an artifact of measuring mesh AABB,
which is dominated by appendages: Fang's 2.32 is nose-to-tail length, Watcher's 2.19 is
outstretched arms, the Envoy's 0.97 is a raised weapon. Measured at the core instead,
Envoy/Fang/Watcher were already about right.
**Adopted (Candidate A, PROVISIONAL/UNVALIDATED):** combat_radius Envoy 0.45 / Fang
0.90 / Watcher 0.85 / Ooze 1.45; Ooze preferred_attack_distance 1.8 → 2.20; each
family's minimum_attack_distance set to its contact distance. **Sword reach unchanged
at 2.0 / 2.5** — max contact is 1.90, still inside it. Burn spread co-tuned for free
through the shared `_contact_distance`. Candidate B (generous core, reach 2.4/2.9)
was defined but deliberately NOT tested: only try it against a concrete spatial
failure. No model scaling; world scale not reopened.
**Playtest verdict (2026-08-13):** Ooze no longer swallows the Envoy at contact; all
three distances believable in motion; world scale normal; enemy spacing fine; no new
Burn/contact problem observed.
**REVALIDATION TRIGGER (open):** there is no sword model or attack animation yet, so
weapon-reach/contact ALIGNMENT is explicitly unvalidated — nothing shows a strike arc
or a contact frame. Re-check reach/contact presentation once real attack visuals
exist. Do NOT retune this geometry to solve an animation problem unless authoritative
contact itself proves wrong.
**Method retained below** for that revalidation and for any future scale question.

**(Original brief, retained as method:)**
**Origin (G-1, closed as falsified 2026-08-12):** the lunge clamp is mechanically
correct. The defect is a mismatch between rendered world scale and authoritative
combat geometry — combat radii, melee reach/contact distances, and rendered
silhouettes were never calibrated as ONE spatial system. Evidence: at Ooze's authored
1.1 contact distance the Envoy renders fully inside the mesh; a uniform 0.40 model
scale neither resolved the overlap nor kept the world readable (it read toy-scale),
and the Envoy's own model half-extent (~0.97) already consumes ~88% of that 1.1
budget, so no per-model scaling can close it. Full detail: `e8d9979`, `1337754`.
**FORBIDDEN until this pass runs:** `model_scale` fields · raising `combat_radius`
alone · raising sword `reach` alone · deriving any combat radius from mesh AABB or
capsule extents.
**Brief:**
- Establish a canonical perceived gameplay FOOTPRINT first, then derive combat radius
  → reach → attack movement → enemy spacing → Burn contact around it. Do NOT preserve
  current ratios automatically — they were authored independently and some may be
  wrong relative to each other.
- **Anchor candidate** (default unless visual judgment overrules): asset-meter
  alignment — the Envoy's footprint = its glTF model's actual occupancy at scale 1.0,
  so all future KayKit/Quaternius/Kenney content lands at native scale through M2.
  (A uniform k ≈ 2.5 survives only as a starting estimate under this anchor, never as
  the method.)
- Non-circular meshes (Fang) use a gameplay body footprint judged around the
  meaningful CORE silhouette — never full mesh extent.
- Burn contact spread and the lunge clamp distance stay co-tuned (locked, one shared
  `_contact_distance` formula).
- Own commit(s); suite green before and after; distance-asserting tests updated
  DELIBERATELY, not mechanically; all values PROVISIONAL until the re-gate; camera
  reframe (P21-adjacent) evaluated in the same pass.
**Why here and not earlier:** it is a deliberate design pass, not a bug fix. Doing it
before flinch exists would tune spacing against combat that has no reaction layer yet.

### P29 — Enemy action repertoire / distance-conditioned action selection
**Status:** **PASS — CLOSED 2026-08-18.** Frozen point: commit `9378316`
(`9378316964ab94f4223ca9e447563477e2ec6294`).

Closing verdict rendered by Breon 2026-08-18, verbatim:
> "P29 — PASS. The Watcher now feels like it is making a contextual decision instead of
> automatically shooting because I entered a range band. It chases first, uses Survey as a
> fallback after being kept out, and one Survey per failed-close episode feels sensible
> rather than repetitive. The Survey itself is fair and readable, I can intentionally parry
> it, and I can now identify the vulnerable phase; the exploit route also works mechanically
> when I am positioned to use it. The remaining animation, projectile-package, aim-lock,
> reflected-parry, wand-reward, and broader movement-identity ideas are follow-up work, not
> blockers for this Watcher selection slice."

**What this verdict does and does not certify**, since the follow-up docket is large: it
certifies the SELECTION SLICE — contextual choice over range-triggered fire, the
one-Survey-per-failed-close-episode economy, Survey's fairness/readability, deliberate
parry, an identifiable vulnerable phase, and the exploit route working mechanically when
positioned for it. It explicitly does NOT certify melee-range animation readability, the
projectile package, aim behaviour, parry payout design, wand reward design, or movement
identities — all named by Breon as follow-up work rather than blockers, and all dispatched
with triggers below.

**PROVENANCE OF THE CLOSING VERDICT (diff-verified, not asserted).** The replay ran on the
working tree, because the prior frozen commit `51d16b5` crashed on attack. The only
gameplay delta between the played tree and `9378316` is the `set_active()` restoration —
21 insertions, 0 deletions — which was present during the replay; everything else differing
was tests and documentation. The verdict therefore attaches to `9378316` honestly.

**FOLLOW-UP DOCKET — DISPATCHED, each with its named trigger:**
| Item | Home | Trigger |
|---|---|---|
| Melee-range animation readability | P32 (+ P28's open revalidation trigger) | Melee parry stays blocked until an impact/arrival presentation exists; P28 re-checks weapon-reach/contact alignment once real attack visuals land |
| Survey package escalation (+ disguise fence) | P29 (below) | Selection judged successful on identity, but Survey still lacks weight as an event |
| Aim-lock fork | P29 (below) | Continuous tracking makes the long-windup Survey too turret-like or undermines movement counterplay |
| Reflected-projectile parry | P31 | Requires its own fork review — it REPLACES a banked mechanic |
| Wand commitment/reward | P30 | Evaluate charge vs consecutive-hit empowerment before implementing |
| Family movement identities | P17 | M2 content pass; Fang sketches + taxonomy captured |
| Kiting-punisher family | P17 / selection note | **Owns the infinite-kite answer** — if infinite-kite proves too safe, it is evidence for a new episode-reset rule, never a reason to weaken one-survey-per-episode |

**HISTORY — the two prior verdicts that produced this closure are recorded in full below:
the first playtest (2026-08-14) immediately following, and the re-playtest (2026-08-17)
further down under RE-PLAYTEST.**

**HISTORY — first playtest verdict, rendered by Breon 2026-08-14, verbatim:**
> "P29 — ITERATE, concept validated. The Watcher's ranged action materially improves
> group-combat pressure, feels fair, preserves both close and ranged approaches, and
> strengthens the Watcher's 'read the windup' identity. P29 is not closed because the
> current implementation does not yet make its higher-skill interaction windows legible:
> the vulnerable interval and intentional parry timing could not be identified during
> play, the projectile's visual/authoritative relationship produces apparent hits that
> miss, and first-engagement firing reads mechanically range-triggered. Required
> iteration is limited to engagement-opener feel using content levers first,
> windup/projectile readability, and the wand EXPLOIT-vs-NONE comparison. Selection
> architecture remains unchanged unless the re-playtest provides evidence that these
> narrower changes are insufficient."

Per M1 precedent the iteration items are REQUIRED closure work; **the next verdict comes
from the re-playtest, never from the suite going green.** Selection architecture is NOT
reopened. Opened at M1 close (2026-08-13); explicitly NOT a retroactive M1 prerequisite.
**Idea:** enemies gain a repertoire of authored actions and choose between them by
situation (distance first). The AI's new power is narrowly "which of my authored
actions applies here"; everything about an action — reach, windup, damage, telegraph,
susceptibility window — stays CONTENT, preserving the locked build-shape rule that the
AI decides only locomotion, whether to attack now, and which eligible authored action to
commit. First concrete second-action consumer: a
**ranged action**, pulling P17's ranged archetype forward. A Force-typed ranged attack
respects MECHANICS-REFERENCE §2's onboarding rule (all early enemy damage is baseline
type) and needs no enemy-applied status, so only P17's M2 content-pass timing moves.
**THE COMPOSITION FENCE (verbatim, carried from the M1 re-gate — this is the point):**
> "Multiple viable approaches at differing effort/safety is desirable, not a defect.
> Enemy repertoire depth must create decisions through situation composition, never by
> converting combat into mandatory single-answer counters."
**Why it matters:** the M1 re-gate's answer to "is there a dominant strategy?" was that
the player *values* killing enemies several ways at differing effort and safety, with
real decisions emerging under group pressure. Depth must come from composing situations,
not from making each enemy a lock with one key.
**Design questions — ALL SETTLED, built 2026-08-14 (verdict not yet rendered):**
selection = authored `action_id` from the enemy resource's `action_ids`; conditioned on
non-overlapping distance bands, no RNG and no array-order priority; cooldown SHARED
per-actor; the Watcher gets the ranged action (`watcher_survey`), Fang and Ooze stay
single-action. Boundary convention: non-terminal bands are half-open `[min, max)`, only
the outermost band includes its maximum — a closed interval would make adjacent bands
both match at the shared edge and violate the overlap law in v1's own content.
Whether a second action dilutes the EXPLOIT lesson was answered by DESIGN rather than
deferred: the survey teaches the SAME lesson at a second distance with a different tool,
and its longer windup makes it the most readable action in the game. **The playtest, not
this entry, decides whether that worked.**

**Filed revisit triggers (do not act on these without the named evidence):**
- **Per-action cooldown.** Reconsider ONLY on evidence that use of one authored action is
  suppressing otherwise-desired availability of another *specifically because both share
  `_next_fire_tick`*. "The survey fires too rarely" is NOT that evidence — exhaust the
  content levers first (band edges, actor spacing, windup/cadence, projectile tuning).
- **Action-derived movement preference.** P29 deliberately kept the engagement band
  actor-level; coupling selection to movement would make the Watcher hold at survey range
  and become a turret, letting the player skip its melee action entirely. This becomes a
  real design question when a range-**maintaining** family arrives (the kiting-punisher
  fork) — designed then, for that consumer, and it will need hysteresis at the band
  boundary. Never adopt it as a fix for "the ranged action fires too rarely."
- **The no-gaps content lint is PROVISIONAL** (`tests/test_content_validation.gd::
  test_bands_tile_without_gaps`), typo prevention rather than schema law. Removal trigger:
  the first enemy design that deliberately wants a meaningful interior dead band. Delete
  the test and nothing else — the fall-through behaviour is already specified and already
  covered by `test_interior_band_gap_falls_through_to_ordinary_locomotion`. Overlap stays
  permanently forbidden.
**RE-PLAYTEST 2026-08-17 — VERDICT: ITERATE (second cycle).** Rendered by Breon, verbatim:
> "P29 — ITERATE. The Watcher is better now and the ranged pressure works. The engagement
> delay made it feel like it noticed me before acting, the projectile is fair and readable,
> and I can intentionally parry it. The ranged attack also adds good pressure when I'm
> fighting something else. But I still can't intentionally identify the vulnerable window,
> the Watcher shoots too often and still feels too interval-driven, and basic wand flinch
> is clearly too strong. I want another iteration on those things before I consider P29
> done."

**BANKED (settled, hands off — do not retune while chasing an unrelated finding):**
- Engagement opener PASS at `engagement_delay_ticks = 10`; UNVALIDATED marker removed.
- Lateral projectile geometry PASS.
- **Q8 UNBLOCKED and PASSED** — projectile parry is readable and deliberately timeable.

**LOCKED — basic wand flinch capability = NONE** (pressure contribution unchanged).
*Identity consequence, recorded precisely:* with basic wand at NONE the Watcher's
VULNERABLE window is no longer safely cashable from range by basic fire. The direct
EXPLOIT route requires CLOSING and landing sword hit 1 or hit 2 during the window
(locked map, pinned by test: hits 1-2 EXPLOIT, hit 3 PRESSURE, charge PRESSURE).
Movement tools (bump, charge lunge) help close distance but are **NOT exploit triggers** —
never conflate traversal with capability in docs, comments or design talk. Future
committed wand mechanics may earn ranged exploitation on their own terms (P30).

**VULNERABILITY ROUTE — BANKED PASS 2026-08-17.** The controlled close-position probe
passed: an EXPLOIT-capable sword hit landing at offset 26, inside the authored 23-34 window,
produced `windup_interrupted` and `flinched` with `reason: "exploit"`, and the shot never
left. **It could not have passed for the wrong reason** — sword_burn_A authors
`interrupt_strength = 0` on hits 1-2 (only hit 3 carries 1), so graded interruption cannot
cancel a windup here and the cancel can only have come from the vulnerability route. A
negative control pins the other side: the identical hit BEFORE the window produces no flinch,
no cancel, and the Survey fires as authored. Both are permanent tests.

**SCOPE OF THE BANK, ruled explicitly:** this is MECHANICAL verification. It is **not** a
claim that normal ranged Survey situations leave enough travel time to reach the Watcher.
**Positioning determines which counterplay is available**, and `vulnerable_start_tick` is
NOT to be changed to make the window reachable from arbitrary ranged positioning — the
window's perceptibility passed on its own. Survey timing stays frozen.

**VULNERABILITY CONFOUND — RESOLVED AS UNRECALLED → CONTROLLED PROBE.** No defect is
inferred from memory. With the cue fix landed, the probe is a REQUIRED step of the next
playtest: approach with sword, wait for the now-legible vulnerable transition, deliberately
land hit 1 or 2, and observe whether the survey interrupts.
- Interrupt occurs → **no defect**; the cue fix closed the whole finding.
- Confirmed in-window hit with NO interrupt → **mechanical defect**: diagnose
  `_flinch_mode_of` / window resolution on the survey before anything else.

**ITERATION BATCH (second cycle):**
1. **Vulnerable cue** — unmistakable phase transition (preparation → distinct "open now" →
   fire). Timing unchanged, derivation unchanged, no new events. LANDED 2026-08-17: the
   first attempt failed because the disc was already full-size and full-brightness for the
   whole windup, so the window was a change of DEGREE inside an unchanging presentation.
   Now understated-and-still while preparing, then a hard pop into a continuous PULSE —
   a change of KIND, with motion doing the work.
2. **Survey cadence** — increase `watcher_survey.fire_interval_ticks`. PROVISIONAL, returns
   for approval before landing.
3. **Ooze vertical artifact** — recorded to spatial-coherence debt (P28-adjacent) below.

**Q8 (parry reach) — RESOLVED 2026-08-17: UNBLOCKED and PASSED.** History below.
**Was BLOCKED UPSTREAM, NOT FAILED (2026-08-14).** The question was
"after parrying a survey at range, can you reach the Watcher while PARRY EXPOSED is still
useful?" It could not be answered because no perceptible ARRIVAL cue existed to time a
shield-raise against — the player could not deliberately choose the parry moment, so
nothing about parry REACH was ever exercised. Recording this as a parry-tuning failure
would have been a false negative about a mechanic that never got to run.
**Q8 ACCEPTANCE FENCE:** arrival presentation must improve timing readability WITHOUT
visually overstating projectile collision width (see the projectile presentation law in
game/actors/projectile_tracer.gd). Only if intentional parry becomes possible does it
become legitimate to evaluate whether parry reach or window themselves need tuning.
**Re-ask after items 2-3.** The entry criterion is strictly upstream of reach: *can the
player deliberately choose the parry moment at all?* Only once that is YES does parry
reach/window tuning become diagnosable — and only then may any parry number move.

**SELECTION ARCHITECTURE — HOLD SUPERSEDED 2026-08-17; WATCHER SELECTION PASS OPENED.**
Recorded precisely, because the reason matters: **the ROADMAP trigger below did NOT fire.**
Its planned cue+cadence replay never took place. The hold was instead superseded by a
stronger Watcher IDENTITY ruling from Breon, verbatim:
> "It shouldn't be the main choice of action when a certain condition exists. It should be
> a potential selection that's not chosen every time a condition is met. Turret characters
> will shoot projectiles at interval. Watcher's should be a unique projectile — maybe large
> and fastish with a long wind up that it's locked into after it ascertains your location."

**CADENCE PROPOSAL REJECTED (45 -> 80 NOT landed; `fire_interval_ticks` stays 45).** The
measurement was sound but aimed at the wrong finding: it addressed FREQUENCY, while the
clarified concern is SELECTION IDENTITY. Making the same automatic choice less often does
not make it a choice. Do not revive it as a workaround for selection.

**CONTROLLED SWORD EXPLOIT PROBE — MOVED.** It now runs against the REDESIGNED Survey, so
it is performed once, against the Survey intended to ship, rather than twice against a
version being replaced.

**Scoping from the superseded hold, retained because it is still true:** cadence evidence
was clean; architecture evidence was not yet sufficient. The trigger text below is kept as
the historical record of what would have re-opened this, and is now moot.

**SUPERSEDED — original one-cycle hold (both seats + Breon, 2026-08-17).**
Scoping recorded so the hold is a decision rather than a delay: **cadence evidence is
CLEAN** (the survey fires too often — tune now); **architecture evidence is NOT yet
sufficient** (presentation failed, so counterplay was never actually observed under
legible conditions).

**ROADMAP TRIGGER, verbatim:**
> "After cue + cadence fixes: does the Watcher resume fighting/positioning before deciding
> to survey again, or does it still feel like it is waiting for the survey timer to become
> legal? If the latter, the trigger has fired and the narrow Watcher-specific
> approach-frustration seam opens."

**The pattern this would translate** (reference-game shape): attempt approach → melee
attempts → ranged fallback when closing is frustrated.
**Sketch, if the trigger fires:** primary desire is a THREAT POSITION; approach succeeds →
the close option; approach frustrated for an authored duration or attempt count → survey;
after a survey → resume movement/decision, **never immediate cycling**.
**Explicitly NOT a utility framework.** Bands remain pure eligibility; this would be a
narrow, authored, inspectable Watcher-specific seam, not a scoring layer.

**CONTEXTUAL SURVEY SELECTION — IMPLEMENTED 2026-08-17 (awaiting replay).** Survey is
gated by close-frustration: the Watcher must have failed to reach its close band for
`close_frustration_ticks` (90, PROVISIONAL; **candidate fallback 60** if the replay finds it
passive), and each failed-close episode grants exactly ONE fallback. Represented as two
literal facts — last tick actually inside the close band (refreshed continuously) and last
tick Survey was committed — with episode consumption DERIVED from their ordering, never a
mutable flag. Consumption is at COMMITMENT: interrupting a committed Survey does not restore
the opportunity. Deliberately narrow naming (`requires_close_frustration`,
`close_frustration_ticks`, `_close_frustration_satisfied`); **generalise only when a second
real context-conditioned action exists.**

**Emergent consequence to watch at the replay (not a defect, a direct result of the ruled
design):** a player who kites *indefinitely and never lets the Watcher close* receives
exactly ONE Survey, ever — the episode never clears because close range is never
re-established. Mitigating in practice: the arena is bounded, the Watcher keeps closing at
2.0, and other enemies force engagement. Flagged so it is recognised as the rule working
rather than the Watcher going inert.

**Ruling on how that evidence may be used, verbatim:**
> "If infinite-kite ever proves too safe, that becomes evidence for a new episode-reset
> rule — never a reason to weaken one-survey-per-episode preemptively."

Cross-reference: punishing a player who sustains distance is precisely the **range-maintaining
("kiting-punisher") family** already recorded as the trigger for action-derived movement
preference (see the selection-architecture note below and the P17 family-identity docket).
If infinite-kite reads as too safe, the first question is whether the answer belongs to a
NEW episode-reset rule or to that family's own design — not to the Watcher's episode
semantics, which are ruled.

**AIM-LOCK — FUTURE FORK (not opened; GAME-RULES §3 preserved unchanged).** Survey is
ACTION-locked only: once selected the Watcher cannot abandon the windup, and aim continues
to be sampled at the fire tick. Correct mechanical description, to be used verbatim in docs,
comments and any player-facing copy: *"Movement during windup changes the eventual fire-tick
aim; it does not defeat the shot by invalidating a previously locked target position."*
**Trigger, verbatim:** *"if later playtest shows continuous tracking makes the long-windup
survey too turret-like or undermines movement counterplay, compare fire-tick aim vs authored
aim-lock and amend §3 explicitly if aim-lock wins."* Never worked around.

**PACKAGE ESCALATION — "large / fastish / long-windup" Survey (queued, NOT scheduled).**
Trigger: the selection pass is judged successful on identity, but Survey still lacks weight
or distinctiveness as an event. Re-validation costs ride with it: `hit_radius` re-derivation,
Q8 parry re-verification, and corridor math at the new speed (a reactive escape must remain
possible at representative engagement distances under fire-tick aim — "fastish" is sized
against the dodge it must still permit, never chosen as an adjective).
**Fence, verbatim:** *"If selection does not fix the identity problem, do not try to disguise
that failure by making the projectile more dramatic."* A failed selection pass is
re-diagnosed at the selection layer, never masked with content spectacle.

**BUMP-PROVOKES-SURVEY — explicitly NOT implemented.** Displacement already feeds the
proximity clock naturally: a bump stops the refresh, leaving the full patience still to
elapse. "Bump instantly provokes Survey" is a separate behavioural rule requiring its own
evidence; a dedicated test pins that it does not happen today.

**CANDIDATE PROJECT FINDING (captured 2026-08-17, NOT a framework requirement).** Enemy
identity increasingly depends on HOW an enemy reaches and CHOOSES an attack situation, not
merely which attack becomes legal at a given distance. Distance-band eligibility answered
"what may I do from here" and that was the right first step; it does not answer "what am I
trying to achieve, and is this the moment for it." Recorded as an observation to test, not
as licence to build a generic selector — see the fence below.

**FUTURE DIRECTION — context/intent-conditioned selection (captured 2026-08-14, NOT
scheduled).** Bands stay what they are: pure ELIGIBILITY ("which actions are legal from
here"). The direction is to add a separate, explicit INTENT layer that chooses among the
already-eligible actions — engagement, retreat, and player-occupied contexts being the
first three worth naming. This keeps the no-hidden-priority rule intact, because intent
would be an authored, inspectable input rather than an implicit ordering. It is NOT a
utility/scoring framework and must not become one.
**Trigger (either):** the re-playtest, after items 1–2 below, still reads
range-triggered; OR the range-maintaining ("kiting-punisher") family arrives, which
already carries its own deferred movement-coupling question.

**Open after the build, before any tuning:** whether the two Watcher tells are
distinguishable. They share a telegraph COLOUR by law (both Force; damage types own
colour, GAME-RULES §3 channel law) and are separated by windup duration (20 vs 34) plus
the tracer. If a playtest finds them confusable, the fix is another non-colour channel
(disc size, pulse rate) — never a colour the damage type does not own.

### P30 — Wand commitment/reward mechanic
**Status:** NEAR-TERM, promoted 2026-08-14, **BROADENED 2026-08-17** after the wand A/B
locked basic ranged flinch to NONE.
**Broadened scope — evaluate BEFORE implementing, do not assume the charge shape.** The
question is what a wand's *commitment/reward* mechanic should be, and there are at least
two candidate shapes that are not the same design:
- **Charge** — hold to pay up front, spend the commitment before the payoff.
- **Consecutive-hit empowerment** — the reward accrues from sustained accurate fire, so
  the commitment is paid in continued exposure rather than in a hold.
Pick by which one creates a real decision (BRAIN candidate principle 3), not by which is
easier to author. This is also the earliest legitimate home for RANGED exploitation, now
that basic fire cannot cash a window — but that authority must be EARNED by the committed
mechanic, never restored to basic fire.
**Idea:** give the wand a charge profile — the ranged counterpart to the sword's
hold-to-charge, which today has no ranged equivalent at all (the wand is deliberately the
simple baseline, P26).
**Why it was promoted:** P29's item-4 A/B asks whether the BASIC wand shot should carry
EXPLOIT flinch authority. Both answers point here. If basic-EXPLOIT proves too strong,
the charge profile is the natural home for *committed* ranged flinch authority — you pay
a hold for the right to interrupt, which is the same bargain the sword's charge already
makes. If basic-EXPLOIT proves fine, the charge still needs its own distinct answer to
BRAIN candidate principle 3 ("why use the basic attack here?" AND "why charge here?"),
and inheriting flinch authority unexamined would fail it.
**Explicitly gated:** do not author this until the item-4 comparison is played. Its whole
design question is downstream of that result.
**Design questions:** what the charge changes (damage? projectile count? travel? pierce?)
— identity must be a CHANGED DECISION, not a bigger number (P26) · whether charge-shot
flinch authority is EXPLOIT or a committed variant · how it composes with the shared
per-actor cooldown · does it want its own tracer treatment.
**Reasoning:** P26 already parks "committed burst / simple charge gun" as the first
advanced ranged consumer and "direct charge access for future charge guns". This
promotes exactly that slice to near-term, with a concrete trigger, rather than leaving it
in the general ranged-futures pool.

### P31 — Reflected-projectile parry
**Status:** PROPOSED, captured 2026-08-17. **Requires its own fork review before any
build** — this would REPLACE the current instant-EXPOSED-on-parry reward, so it is a
change to a shipped, validated mechanic rather than an addition.
**Idea (Breon's design intent):** parrying a projectile REFLECTS it rather than simply
marking the attacker PARRY EXPOSED.
- **Must-reconnect trigger:** the reflected shot has to actually hit the attacker to pay
  out. The reward becomes an aimed outcome, not an automatic one.
- **One reflect per shield raise:** the raise is the resource, so a held shield cannot
  farm reflections.
**Why it needs a fork review:** Q8 passed on the CURRENT parry (readable, deliberately
timeable, instant EXPOSED). Replacing the payout changes what the player is timing FOR,
and could unsettle a banked PASS. Design questions: does a reflected shot use the
player's damage or the enemy's; can it be re-parried; what happens on a miss; does
EXPOSED remain as a fallback or disappear entirely.

### P32 — Melee parry timing (blocked upstream on impact presentation)
**Status:** BLOCKED UPSTREAM, captured 2026-08-17. Not a failure — a prerequisite.
**Finding:** projectile parry passed (Q8) precisely because a travelling projectile shows
its ARRIVAL. Melee has no equivalent: the telegraph says an attack is COMING, but nothing
says **now**, and "now" is what a parry is timed against.
**Prerequisite:** an impact/arrival presentation for melee attacks — the melee analogue of
watching a shot close the distance.
**Do not** attempt to fix this by widening the melee parry window; that trades a timing
problem for a leniency problem and leaves the player still unable to aim their timing.


# P33 — BOUNDED LOCAL OBSTACLE AVOIDANCE · **PRE-CODE SPECIFICATION (FROZEN). NO CODE WRITTEN.**

Option B approved 2026-08-29 on the recon above. This spec returns for review BEFORE
implementation. Frozen means: the criterion and the laws below are fixed before any code exists,
so the result is judged against what was promised rather than against what was built.

## FROZEN PASS SENTENCE (verbatim — the verdict is rendered against this exact sentence)
> "The avoidance passes when the Ooze follows around the corner instead of rubbing at it:
> recognizes obstruction, routes around, arrives"

## V1 CAPABILITY, AND ITS CEILING
Recognize ONE intervening obstruction, choose ONE deterministic local route around it, commit
long enough to clear it, then return to normal pursuit.

**EXPLICITLY NOT BUILT:** NavMesh / NavigationAgent authority · A* · a navigation graph · a
general waypoint framework · multi-turn planning.

**ESCALATION TRIGGER, written down so the upgrade is a recognised event and not a discovery:**
a required engagement route that cannot be solved with ONE local turn. The earlier ambient-ring
probe (no single-waypoint route around the void) is evidence that such a consumer can exist. It
is not the current consumer, and the ambient-convexity constraint currently excludes it.

## 1. DETECTOR LAW
Avoidance may begin ONLY when the already-validated authoritative obstruction detector fires
within the pursuit horizon. No engine physics or navigation query may substitute for it, ever.

The detector is the one validated 7/7 in `tools/diagnose_obstruction_detector.gd`:
- question: *is my intended direct movement toward the target obstructed by authoritative floor
  geometry?*
- walks the direct line at BODY WIDTH against the actor's own legality region
  (`_legal_bounds_for` -> `fits`), so territory confinement and body extent are both respected
  by construction;
- horizon = the actor's `detection_radius`, not a picked constant. An actor that only pursues
  what it can detect has no business reasoning past that;
- samples at HALF the body radius, so a body cannot tunnel across a gap narrower than itself;
- returns the first blocked point, or nothing.

Porting it into sim/ must not change its behaviour: the seven validated cases become tests.

## 2. CANDIDATE SELECTION — DETERMINISM IS THE WHOLE POINT
Candidates are perpendicular sidesteps from the blocked line, generated and evaluated in a
STABLE order. Identical authoritative state must yield an identical selected route.

Generation order, fixed:
1. offsets ascend from one body radius in increments of half a body radius, to a cap;
2. at each offset, the RIGHT candidate is generated before the LEFT one;
3. a candidate qualifies only if the waypoint is body-legal AND both legs (actor -> waypoint,
   waypoint -> target) are unobstructed by the same detector;
4. the FIRST qualifying candidate wins.

**PINNED TIE RULE.** If the right and left candidates qualify at the SAME offset, the winner is
the one whose waypoint is nearer the target; if those distances are equal within epsilon, RIGHT
wins by authored convention. This is a degeneracy rule, not a steering preference — the observed
case is asymmetric (right clears at 4.35 u, left finds nothing within 16), so geometry decides
almost always and the tie rule exists to make the remainder replayable.

FORBIDDEN as inputs: RNG · container or iteration order · physics-query order · anything not
derivable from authoritative sim state.

## 3. COMMITMENT AND STATE
Without commitment a sidestep is rubbing with extra steps: the moment the waypoint stops being
the nearest improvement, direct pursuit re-requests the blocked vector.

**STATE CLASSIFICATION (ruled).** These are PER-ACTOR AI FIELDS whose lifetime ends with the
floor. They are filed alongside the existing `_ai_*` family and classified `SCOPE_FLOOR` for the
same reason those are — NOT promoted to floor-global state merely because a floor transition
clears them.

Store ONLY what the behaviour consumes:
| field | why it cannot be derived |
|---|---|
| `_ai_avoid_waypoint` | the committed local target; re-deriving it every tick is the oscillation |
| `_ai_avoid_deadline` | absolute sim tick at which commitment lapses; bounds the behaviour |

**The committed SIDE is deliberately NOT stored**: it is derivable from the waypoint's position
relative to the actor-to-target line, and a field that duplicates a derivable fact is a second
truth waiting to disagree. If implementation proves it genuinely cannot be derived, add it then
and say so — do not add it speculatively.

## 4. EXIT CONDITIONS
Leave avoidance when ANY applies:
1. direct pursuit becomes unobstructed (detector goes quiet);
2. the committed waypoint is reached or cleared;
3. the commitment deadline expires;
4. target or encounter state invalidates pursuit (death, clear, combat-absence, leash).

**The deadline must fail DETERMINISTICALLY and must never leave an actor permanently in
avoidance.** On expiry the actor returns to ordinary pursuit; if the obstruction still fires, a
fresh selection may occur. That is bounded degradation to today's behaviour, never a stall.

## 5. WHAT MUST NOT CHANGE
Body-aware legality · territory-union confinement · the existing movement clamp
(`_clamp_to_bounds` / `WalkableBounds.clamp_step`) · the combat pipeline. **None of them may be
weakened to make avoidance easier.** Avoidance changes only the DIRECTION the AI asks for; the
displacement seam that answers is untouched.

## 6. REQUIRED TESTS (pre-registered; all must exist before this is called done)
- literal observed right-side route succeeds
- opposite side has no route in that case and is NOT selected
- diagonal blocked approach
- near-tangent blocked approach
- unobstructed pursuit does NOT enter avoidance
- deterministic tie case
- side commitment prevents oscillation
- direct route becoming clear exits avoidance early
- deadline / failure path is bounded
- same initial sim state produces an identical route
- instrumentation proves detector -> selector -> committed avoidance actually FIRED

That last one is load-bearing: a behaviour that appears to work because the actor happened to
slide somewhere useful is not this mechanic firing. Confirm the chain before believing a result.

## 7. BLAST RADIUS
ONE seam — the AI's chosen movement vector. Nothing in `WalkableBounds`, `_clamp_to_bounds`,
the eight displacement seams, or the combat pipeline is touched. Pure function of sim state, so
the M3 driver replicates it unchanged.

## P33 — COMMITMENT DEFECT **FIXED 2026-08-31.** Churn 41 -> 2 commits.

Arrival predicate repaired, selector untouched. Measured on the same literal geometry:

| | commits | rub ticks | arrives | exit reasons |
|---|---|---|---|---|
| before the fix | **41** | 0 | 202 | 38 x reached |
| after the fix | **2** | 0 | 205 | 1 route_clear, 1 deadline |
| baseline (avoidance off) | 0 | 203 | 321 | -- |

`route_clear` now appears as an exit, which is the semantically correct one: a commitment ends
because avoidance is no longer NEEDED, not because the actor drifted a body-width from its own
waypoint. Arrival moved 202 -> 205 ticks (0.1 s), noise against the 321 baseline it beats.

**THE FIX:** `_AVOID_ARRIVAL_TOLERANCE = 0.25`, an absolute distance chosen against the game's
SCALE (corridors 5.00 wide, bodies 1.7-2.9 across), replacing the body-radius test. Deliberately
NOT derived from the radius even though it was available -- "how big am I" and "am I standing on
it" are different concepts, and conflating them WAS the defect. The invariant (tolerance < the
smallest authored body radius, hence < the smallest possible first offset) is pinned by test
against shipped content, so authoring a small enemy fails loudly instead of silently
resurrecting the collision.

Four regressions added, including the one that pins the original defect directly: after selecting
a minimum-offset waypoint, the next tick must still be committed.

### The finding, as recorded before the fix

First appearance of the mechanic in real play (the ambient Ooze, during the P34 visual-check
session). It WORKS -- no errors, no stalls, and it routed -- but it is not doing what the spec
said, and the evidence is unambiguous:

- **41 commit events for one encounter**; 38 of 41 cleared by `reached`
- consecutive deadlines **2 ticks apart** in an unbroken run (371, 373, 375, 377, 379 ...)
- successive waypoints **0.03 apart** in x

**CAUSE, confirmed in code.** `_select_avoidance_waypoint` generates its first candidate at
`offset = radius`, and the `reached` exit fires at `distance <= radius`. A first-offset waypoint
therefore satisfies "reached" AT SELECTION TIME, before any movement. Commitment lasts one tick
and `avoid_commit_ticks = 45` never matters. The mechanic degrades to a per-tick greedy sidestep.

**WHY THE TESTS MISSED IT, which is the more useful half.**
`test_commitment_prevents_per_tick_reconsideration` asserts the waypoint does not CHANGE while
committed -- and it passes, because in that fixture the first offset does not qualify and the
selector reaches for a larger one, so the commitment genuinely holds. Real geometry qualifies at
the first offset. **The test proved the loop it was watching and not the one that occurs**:
commit -> reached -> re-commit is a different cycle from commit -> waypoint mutates.

**Severity: NOT Sev-1.** The measured improvement stands (rub 203 -> 0, arrival 321 -> 202) and
that measurement was taken on the shipped behaviour, defect included. What is wrong is that the
behaviour is not the one specified, the instrumentation is 40x noisier than it should be, and a
commitment that never survives a tick cannot do the job commitment exists for -- it is luck that
greedy sidestepping happens to work on this floor.

**Cheapest fix, not yet applied:** separate the two radii so they cannot collide -- either start
candidate offsets beyond the reached threshold, or make `reached` a tighter fraction of the body.
Either is a small change, but it changes shipped behaviour and wants a ruling and a re-measure
against the same rub-tick metric, plus a regression test written against THIS loop rather than
the one already covered.

## AS BUILT (2026-08-29). Suite 608 -> 623.

Implemented to this spec, at the one seam it named. **MEASURED ON THE REAL GEOMETRY** (the
shipped arena -> neck, pursuer off-axis beside the jamb, 600 ticks):

| | rub ticks | arrives |
|---|---|---|
| avoidance ON | **0** | tick 202 |
| avoidance OFF (baseline) | **203** | tick 321 |

"Rub ticks" is the recon's own metric -- ticks that lost more than half the requested step -- so
the mechanic is judged by the same measurement that condemned the baseline. That is the frozen
sentence in numbers: it follows around instead of rubbing, and arrives.

**ONE CORRECTION THE TESTS FORCED, recorded because it changed the design.** The first build
sampled the detector and the second leg all the way INTO the target's position. A 1.45-radius
Ooze frequently cannot fit where a 0.4-radius Envoy is standing, so in the near-tangent case no
route could ever qualify and avoidance silently never fired -- a FALSE obstruction, indefinitely
unresolvable. Both now stop short by `preferred_attack_distance`: a pursuer needs a clear route
to WHERE IT WILL STAND, never into the target's own footprint. The near-tangent test is what
exposed it.

**Authored, not hardcoded:** `avoid_commit_ticks` on enemy stats (45, PROVISIONAL, outside the
M1 fence). **ABSENCE IS OFF** -- 0 means a family pursues in straight lines exactly as before
P33 existed, which is what leaves every pre-existing test untouched.

**The committed SIDE is still not stored**, as specified: it never proved necessary, so the state
is exactly two fields.

Not built, as fenced: no NavMesh/NavigationAgent, no A*, no navigation graph, no waypoint
framework, no multi-turn planning. The escalation trigger stands unchanged.


# P34 — PROJECTILE-VS-WORLD OBSTRUCTION · **PRE-CODE DESIGN, AWAITING REVIEW. NO CODE WRITTEN.**

The P20 projectile fence is CONSUMED BY EVIDENCE: human play showed shots passing through
solid walls. With folded topology this is not cosmetic -- a player can hit enemies, breakables
and progression controls in areas they have not reached. Concretely, on the shipped floor the
crate at `(-12, -24)` sits across the void from the south strip, so it can be destroyed from
the hall without ever walking the west branch.

## THE RECLASSIFICATION THIS REQUIRES (amends the 2026-08-29 walls/ledges ruling)
`boundary_style` was authored as PRESENTATION ONLY. It becomes **authored floor data shared by
sim and presentation**:
- presentation reads it to decide whether to render a wall;
- **sim reads it to decide whether that boundary obstructs projectiles.**

`MOVEMENT BOUNDARY != PROJECTILE BLOCKER` stays a hard law. Movement legality remains governed
by walkable space + body-aware bounds and is untouched by this work. A ledge bounds an actor
and does NOT stop a shot.

## Q1 — how wall segments are derived today
`FloorBuilder.build_walls` walks every patch (skipping `ledge`) and every connection aperture,
samples each edge in 1.0 spans, probes 0.5 beyond the span midpoint, and adds a 0.6 x 2.2 box
where nothing walkable lies beyond. Purely presentational: no collision bodies exist, and the
sim has never had any representation of a wall. Gates are separate meshes keyed by
`connection_id`.

## Q2 — where the sweep can consume solid segments
`SimWorld._advance_projectiles`, `game/sim/sim_world.gd:2394-2397`. Per projectile per tick it
already builds two candidates over the same segment and takes the earliest:
```
actor_hit     = _find_earliest_swept_hit(start, end, attacker_id, hit_radius)   -> {target_id, t}
breakable_hit = _find_earliest_breakable_hit(start, end, hit_radius)            -> {breakable_id, t}
```
A third finder slots in beside them with no change to the pipeline's shape:
```
world_hit     = _find_earliest_solid_hit(start, end, hit_radius)                -> {edge_id, t}
```
Pure segment-vs-segment math against floor data. **No Godot physics authority anywhere** --
consistent with `_actors_overlap`'s existing "no Area3D, no body_entered" fence.

## Q3 — how the three candidate kinds compare
All three already speak the same language: a parametric `t` in [0,1] along this tick's segment.
Comparison becomes an explicit total order instead of today's two-way `<`.

## Q4 — determinism
Both existing finders sort their id arrays before scanning, so each is deterministic in
isolation. The proposal keeps that and makes the cross-kind order explicit:

> **ORDERING LAW.** Sort candidates by `t` ascending; on an exact tie, **WORLD < BREAKABLE <
> ACTOR**. A shot that reaches a wall and an actor on the same instant stops at the wall.

Ties are near-impossible in practice (an actor flush to a wall is met first, since its body
radius extends outward) but the order must be authored rather than emergent, because M3 needs a
client and a server to resolve identically.

## THE DATA — and an honest state-scope answer
Two populations, deliberately separated:

1. **STATIC SOLID EDGES — immutable, derived once per floor.** Patch perimeter edges where no
   walkable ground lies beyond AND the patch's `boundary_style` is `wall`. Same derivation
   FloorBuilder already performs, moved into `FloorPlan` so BOTH consumers read one source
   instead of presentation computing its own. **It is immutable FloorPlan data, so it gets no
   mutable-state entry in STATE_SCOPES** -- classifying it as sim state would be dishonest, and
   the ruling explicitly asks for the honest treatment rather than invented mutable state.
2. **GATE BARRIERS — mutable, but ALREADY SCOPED.** A closed connection is a physical barrier.
   Its solidity is derived from `_connection_open`, which is FLOOR-scoped and classified today.
   **No new mutable state is introduced.** A gate blocks shots exactly while it blocks movement.

## V1 BEHAVIOUR, as required
| Obstruction | Blocks projectile |
|---|---|
| `wall` edge | YES |
| closed gate | YES (derived from `_connection_open`) |
| breakable | YES — already validated, unchanged |
| actor | existing hit behaviour, unchanged |
| `ledge` / open edge | **NO** — bounded for bodies, transparent to shots |

## DIRECTION APPROVED 2026-08-29 (Breon) — IMPLEMENTATION STILL GATED
Approved as architecture; **no code until the replay is done and the open questions below are
closed.** The four rulings, as accepted:

1. **SOLID EDGE IS AUTHORITATIVE FLOOR DATA.** WALL/LEDGE stops being presentation-only. ONE
   authored boundary fact feeds both consumers -- presentation renders wall vs open ledge, sim
   decides projectile obstruction. **A second projectile-only wall representation is forbidden**:
   two descriptions of one boundary is exactly the drift Truth Homes exists to prevent.
2. **NO NEW MUTABLE COLLISION STATE.** Static solid edges are immutable FloorPlan data and get
   no STATE_SCOPES entry. Dynamic blocking derives from existing authoritative connection state,
   which remains the sole mutable authority.
3. **RESOLUTION BY SMALLEST t.** Candidates come from actors, breakables and solid world edges /
   closed blockers; the smallest authoritative parametric travel distance wins. The
   **WORLD -> BREAKABLE -> ACTOR** tie order is a DETERMINISTIC DEGENERACY RULE ONLY, for
   exact/epsilon-equivalent ties -- it is explicitly NOT a general gameplay priority, and must
   never be cited as one.
4. **SIM AUTHORITY ONLY.** Godot physics and wall meshes are never authoritative for projectile
   collision. Presentation continues to mirror FloorPlan and sim state.

### REQUIRED TESTS (pre-registered, all must exist before this is called done)
- actor clearly before wall -> actor is hit
- wall clearly before actor -> wall stops the shot
- breakable before wall -> breakable is hit and stops it
- wall before breakable -> wall stops it, prop untouched
- actor flush with wall / tie case -> pinned deterministic outcome
- open LEDGE boundary -> projectile CONTINUES (bounded for bodies, transparent to shots)
- closed connection/gate -> projectile stops
- the same connection open -> projectile passes
- no sequence-breaking shot through a solid wall into an unreached breakable or actor

## OPEN QUESTIONS FOR REVIEW (not decided here)
1. **Wall height / arcs.** Everything is flat today; a `ledge` is "not solid" and a `wall` is
   "solid to full height". No projectile has vertical travel, so height is currently a
   non-question -- but authoring it as a boolean now is a decision worth making deliberately.
2. **Should a blocked shot emit an Event?** Presentation wants a spark; `projectile_expired`
   already exists and could carry a reason field rather than growing a new kind.
3. **Edge sampling vs exact segments.** FloorBuilder samples in 1.0 spans because it is drawing
   scenery. The sim wants EXACT segments; deriving them exactly is a different (and simpler)
   computation than sampling, and the two must not silently diverge.
4. **Does the ambient-convexity constraint interact with this?** A convex territory has no
   internal walls, so ambient enemies gain no new cover. Worth confirming before assuming.

## LANDED 2026-08-31 — MIGRATION CLASSIFIED **B**. Suite 623 -> 637.

**HUMAN VISUAL GATE PASSED (Breon):** *"Yes, they read naturally."*

**DIFFERENCE LEDGER (the B-class record):**
> openings — opening-width check — the old sampler rendered 6.00 against authoritative 5.00
> walkability; the canonical renderer displays the actual 5.00 aperture uniformly across all 8
> mouths; human inspection found the passages still read naturally and did not reduce apparent
> traversability or route readability.

Every other checklist item was A. The four doubled/overlapping segment pairs found during
migration were fixed mechanically rather than escalated -- the gate consumed only the one
question evidence could not reach.

**THE CLOSED ENUM, after auditing all four termination paths.** Breakable impact and actor
impact are completely explained by their own authoritative hit events, which already carry the
projectile id and already retire the tracer; floor unload emits nothing. So exactly two reasons
have real consumers: `{lifetime, world}`. `projectile_expired` means "ceased to exist and no
other event explains why". Broadening it to every termination was considered and REJECTED --
presentation's uniform "any event carrying my projectile_id retires me" rule would fire twice
for one shot. Membership AND count are pinned by test.

**MIGRATION LEDGER** (`tools/compare_wall_migration.gd` reproduces the old sampler and diffs it):
- boundary agreement 11000/11360 points (96.83%)
- missing walls: **none**
- doubled/overlapping segments: **4 pairs found and FIXED** by merging collinear runs (45 -> 41
  segments). A mechanical defect, resolved without a gate -- coverage identical.
- wall/ledge treatment: correct, no segment on any ledge edge
- gates: `_build_connection` untouched, unchanged by construction
- **openings: 6.00 -> 5.00 uniformly across all 8 mouths.** The old sampler quantised to 1.0
  spans and probed 0.5 beyond, so it drew every threshold 1.0 WIDER than the corridor the sim
  actually permits. The canonical renderer shows the real aperture. This is the C-class item.

A first run of the opening report also showed patches 8 and 9 changing to 24.00/12.00. Those are
the LEDGE patches and it was an artifact of the report forgetting to skip them; corrected before
the ledger was trusted.

**IF THE THRESHOLDS READ NATURALLY** -> classify B with the ledger line, land unchanged.
**IF THEY READ TOO CONSTRICTED** -> do NOT restore 6.00 rendering, which would knowingly
reinstall the disagreement. Widen the AUTHORED aperture, let both consumers inherit it, re-run
the clearance validator (a 6.0 aperture is EXPECTED to satisfy the widest-body law but must be
proven, not assumed), re-baseline the golden fixture under the dated-reason rule, re-run the
suite and the migration comparison.

## Graveyard
(One-line tombstones of SHIPPED/REJECTED proposals, pruned at milestone completion.
Full text lives in git history — `git log -p ROADMAP.md` resurrects anything.)
