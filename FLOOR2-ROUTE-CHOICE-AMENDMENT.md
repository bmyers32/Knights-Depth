# Floor 2 — Route-Choice Expansion (§18, paper only)

**No coordinates moved.** Base: working tree, 803/803 green. Rects below are indicative
footprints for review, not authored geometry — separation and connectivity get verified
during authoring, as before.

The correction I am acting on: **length and branching are the reveal tool.** Screening masses
were the wrong instrument for a floor that was too short.

---

## A. DECISION SPACE — the Hall

**What the player does there.** Enters from the east through the lane's doorway into a room
partitioned into three lanes by the existing rubble and two prop rows. A Watcher holds the
west end behind the rubble; two Fangs come round the flanks. A hit-switch on the Hall's west
side opens the way on — and it sits behind the fight, so the room's demand is *fight through
partitioned space, then operate something*, not *cross*.

That is the §9 ask stated as one sentence: **the room asks you to do something other than walk
through it.**

| Exit | State at entry | Leads to |
|---|---|---|
| **LEFT (west)** | **open from the moment you arrive** | the optional chapter |
| **RIGHT (south-east)** | **closed** until the Hall's switch is hit | the commitment gate, then the late chapter |

The asymmetry is the point. The optional limb is available *before* you have earned the way
on, so exploring it is a genuine choice rather than a chore you complete after the room is
already solved.

**Party commitment — recommended DEFERRED, with reasoning rather than a verdict.**

The semantic is legitimate and I am not arguing against it. Two specific objections to
shipping it in M2:

1. **A party plate with one player is a button.** M2 ships single-player. The control does not
   express "we are done exploring, proceed together" until there is a *we*.
2. **Closing the left route behind the player is what would earn it — and that is the part
   that should not ship yet.** Closing a route converts exploration into a decision, which is
   exactly right, but only once the left route has a payoff worth weighing. Today it has a
   fight and a search cluster. Closing it now punishes the player for exploring in the wrong
   order, in exchange for nothing.

**Proposal:** author the commitment gate as a real space with the plate's footprint reserved,
and gate it in M2 with the Hall's hit-switch. At M3 the switch becomes the party-occupancy
plate and the left route closes behind it — no reshape needed, because the geometry is the
same. If you want it in M2 anyway, say so and it goes in; it is one control swap.

---

## B. LEFT OPTIONAL ROUTE — a loop, not an out-and-back

The existing puzzle chain **moves west and becomes optional**. Nothing is thrown away: the
switch/two-door beat is preserved intact, it simply stops being mandatory.

```
HALL ──► POCKET (fight + search) ──► PUZZLE BAY (the toggle) ──► [W DOOR | E DOOR] ──► CACHE
  ▲                                                                                     │
  └──────────────────── return door, opens from the far side ───────────────────────────┘
```

| | |
|---|---|
| **Retained** | Pocket, Puzzle Bay, Puzzle West, Puzzle East, the toggle and its two doors |
| **Payoff** | fight, search, and a terminal **Cache** room — empty today, and said so plainly |
| **Return** | a door that opens from the far side, looping back to the Hall |

The loop answers "richer than walk left, collect, walk back" without new vocabulary — it is
one more connection that starts closed and is opened by a trigger on the far side.

**§13 preserved:** the side rooms keep the discovery reading you liked. I am not redesigning
them for visibility metrics.

**Honest note, unchanged from last pass:** the Cache and the Vault are now two optional limbs
both awaiting the same missing reward vocabulary. Recording it rather than faking it.

---

## C. RIGHT CRITICAL ROUTE — the new late chapter

The Junction and Terrace are **absorbed**, not kept and appended. Their ground becomes a real
chapter instead of a corridor and a plate.

| Space | Approx. footprint | What it is |
|---|---|---|
| **Commitment Gate** | `(-2,-116) 16 × 14` | short transition; the control; point of no return |
| **The Arena** | `(6,-146) 46 × 28` | dedicated battle space, larger than any room on the floor |
| **The Spillway** | `(28,-162) 28 × 14` | the environmental beat — spike crossing, no new hazard type |
| **The Shelf** | `(48,-178) 24 × 18`, elevated | final approach and the exit |

**Staged rounds without a new framework.** Two encounter sites in the Arena, the second
activated by a region trigger deeper into the room. Advancing commits you to the second wave.

I am **not** proposing "next round on clear" — that needs a new effect kind, and §18 says no
new framework. If staged-on-clear is what you actually want, that is a separate ruling and I
will cost it rather than smuggle it in.

**Arena composition** (the §15 demonstration piece — not scatter): two large masses that are
*fought around*, each anchoring one wave's cover; prop rows defining the approach lanes
between them; enemies placed to use both. Then the Spillway is deliberately quiet by
comparison — one hazard, no combat. Loud room, quiet room, arrival.

**Extent change:** `112 × 172` → about `130 × 176`. Chapters on the critical path go from 8 to
**10**, plus a 4-room optional loop. Growth is in chapters, not in corridor length.

---

## D. VISIBILITY

**Visible from the split — deliberately, per §1–2:**
- the west aperture and the Pocket beyond it — the optional invitation you said works
- the Commitment Gate, closed, so the right route is legible as *a route you have not earned*

**Intentionally unresolved:**
- the Arena's far half, the Spillway, and the Shelf/exit

**How, without a screening block:** the right chapter sits behind a closed gate and 20+ units
of separation, and the Arena's own architecture stands between the gate and the Shelf. The
floor's *length* does the work.

**Acceptance measurement, stated as a test rather than a promise:** after authoring, the Shelf
must measure at most FORESHADOW from every station before the Arena, and local path coverage
must stay at or below today's 6% worst case. If the Shelf measures SOLVED from the South Lane,
I report that and we rule on it — I will not quietly drop a wall in front of it.

**Note:** the current `JUNCTION 96% SOLVED from the south lane` regression is resolved by this
change rather than patched. That ground stops being a visible endpoint.

---

## E. MASS DISPOSITION

### Remove — 2

| Mass | Size | Where | Why it goes |
|---|---|---|---|
| **3** | `8 × 10` = **80** | void between West Hall and Hall | largest on the floor; screens the Hall and nothing else |
| **5** | `14 × 3` = **42** | void north of the Puzzle Bay | screens the bay's hallway geometry only |

**Flagging an inference.** I cannot see the screenshot, so I am identifying "the two large
blocks in that section" by their properties: these are the two remaining masses that stand in
voids between rooms, do no combat work, and conceal hallway geometry — the exact description
in §10. They are also two of the four (2/3/5/9) I deliberately kept last pass so this replay
could attribute. **If you meant a different pair, name them and I will swap the disposition.**

### Keep — each states its room purpose (§11)

| Mass | Purpose |
|---|---|
| **2**, **9** | they create the spike-approach reveal relationship §14 says works — removing them reopens the sightline |
| **1** | screens the Court's mouth **and** shapes its north-west corner as combat space |
| **10** | the Court's landmark; the route passes round it |
| **7**, **8** | Hall cover — **and they now become partition anchors in the Hall's authored problem**, which is what §10/§11 demand of a mass that stays |

**No one-for-one replacement.** The two removed masses are not replaced by other large blocks.
New large geometry appears only in the Arena, where it anchors a wave's cover.

---

## F. UNREACHABLE PROP

**Defect pinned:** `B_BAY_PROP` at `(-46, 0, -118)`. It is the Puzzle Bay's search prop,
orphaned when the Bay moved east to `x[-24,4]` in the last pass — the room travelled and its
prop did not. It sits in void, breakable and targetable.

**Disposition:** it returns to the Bay's floor at the Bay's new western position.

**Validation — cheap, and proposed:** a new authoring guard, `_reject_props_off_floor` — *an
authored gameplay prop's position must lie inside some patch or aperture.* Same family as
`_reject_obstructed_controls`. It costs one loop and it makes this class of drift impossible
to ship again, which matters because the cause was a room moving, and rooms will keep moving.

I would rather add the guard than fix the coordinate, and I propose both.

---

## Ruling wanted

1. **The decision-space design** — left open from arrival, right earned by the Hall's switch.
2. **Party commitment DEFERRED to M3** with the footprint reserved — or overrule and ship it now.
3. **The left chapter as a loop**, with the puzzle chain moved west and made optional.
4. **The right chapter** — Commitment Gate / Arena / Spillway / Shelf, absorbing Junction and Terrace.
5. **Staged rounds by region trigger**, not by a new on-clear effect.
6. **Mass disposition** — remove 3 and 5, with the inference above flagged.
7. **The prop fix plus the new guard.**

On approval: author, verify guards, re-measure local readability and macro reveal, full suite,
hand over for replay. No generator, no new framework.
