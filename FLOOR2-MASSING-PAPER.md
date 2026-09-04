# Floor 2 — Massing and Reveal

Paper deliverable. **No geometry rebuilt.** Camera untouched, as ruled.

Mechanical candidate: **`2353ecc`** (795/795). Addendum work: **`98e8d7a`** (797/797).

---

## 1. The finding that reframes the problem

The reveal instrument was extended to ask not only *how much* of a space is visible but **whether
its way in is visible too** — because that is what separates a glimpse from a solved route.

Run against the shipped floor, the result is sharper than "too much is visible":

> **Zero spaces, from any standing point on the floor, are FORESHADOWED.**
> Every space in view is either SOLVED (most of it visible *and* its aperture visible) or
> `oriented`. The floor has **no glimpse register at all** — spaces are either fully explained or
> entirely absent.

That is the difference the reference screenshot has and we don't. It is not that the reference
hides more. It is that the reference has a **middle state**: you can see something is over there
and you cannot yet see how you get to it.

So the design target moves from *hide the next chapter* to **show it without showing the way in**.

## 2. What the research question actually is

Not "how tall must a wall be". The governing arithmetic, measured earlier, is:

> A mass of height *h* at distance *t* from the camera hides ground out to **`t / (1 − h/12)`**.

Read that as a *ratio*, and the design lever falls out:

**The same modest height covers far more ground when it stands near what it hides than when it
stands near the viewer.** A height-4 mass 45 units away shadows ground out to 67. The same mass
15 units away shadows only to 22.

This is why the reference achieves containment with ordinary architecture and we needed
height-9 slabs: **we were placing walls near the player instead of near the thing being hidden.**
A room's own near wall is worth more than a barrier across the room you are standing in.

### Principles extracted (not geometry copied)

1. **A room's near wall hides its own far half.** Cheap, ordinary height, and it reads as
   architecture rather than as a screen.
2. **L-shaped limbs turn an aperture around a corner**, so the space is visible while its mouth
   is not. This is the direct producer of the missing FORESHADOW state.
3. **Enter rooms from the side, not the camera-facing edge** — an aperture perpendicular to the
   view is hidden by very little.
4. **Lateral travel is worth more than depth**, because the view is narrow beside the player and
   deep in front: 13 units of half-width at your own depth, 45 at sixty ahead.
5. **Overlapping silhouettes at different depths** read as containment without either mass being
   large.

## 3. Current vs proposed, at the level of principles

| | Shipped floor | Proposal |
|---|---|---|
| Footprint | 84 × 160 | **112 × 172** — broader, and it *uses* the width |
| Direction changes | 2 folds, both 90° turns on a strip | 4, with major spaces at genuinely different x |
| Occluders | 2 slabs, **height 9**, across the floor near the player | 7 masses, **all height 4**, standing beside what they hide |
| Foreshadowed spaces | **0, anywhere** | 1–3 at every station |
| Reveal at entry | 4 spaces, 3 SOLVED, 0 glimpsed | 5 spaces, 3 SOLVED (all local), **1 glimpsed** |

## 4. The blockout

```
        x=-58                    x=-4            x=+40
  z=-2   ┌─OVERLOOK─┐
         └────┬─────┘
  -24    ┌─DESCENT──┐
         └────┬─────┘
  -46  ┌──LANDING───┐───WEST HALL──────────┐          leg 1: south, then EAST
       └────────────┘══════════════════╗   │
  -58            ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓╝   │   ← court's near wall + L-limb
  -74                          ┌─COURT─────┴──┐  ┌─VAULT─┐
                               │              ├──┤       │   leg 2: broad open, EAST
  -84            ▓▓▓▓  ▓▓▓▓▓▓▓▓│▓▓▓▓▓▓▓▓▓     │  └───────┘
  -92                          │  SOUTH LANE──┘        ← lane's near wall + L-limb
  -78   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                ← HALL's own near wall
 -100  ┌────────────HALL──────────┐                     leg 3: back WEST
       └──────────────────────────┘
 -108   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                         ← puzzle bay's near wall
 -124  ┌──PUZZLE BAY──┐
       └──[D1]──[D2]──┘
 -140  ┌P WEST┐ ┌P EAST┐
 -158        ┌─────JUNCTION──────────┐                  leg 4: EAST again
 -150         ▓▓▓▓▓▓▓▓▓▓▓                       ← screens the terrace approach
 -174                  ┌─TERRACE─┐  ▪ exit
```

**Route:** south → **east** (west hall) → south into the court → **east** to the vault branch →
**south-west** down the south lane → **west** into the hall → south to the puzzle bay → **east**
along the junction → terrace.

Four direction changes, and the major spaces sit at x ≈ −44, −18, +16, −28, +0. That is lateral
travel doing work, not a strip with corners.

## 5. Measured reveal, per station

| Standing at | In view | Solved | Glimpsed | Notable |
|---|---|---|---|---|
| **the drop** | 5 | 3 | 1 | local problem solved; `WEST HALL 48% oriented` is the next direction; `SOUTH LANE 4%` is a sliver of later |
| landing | 3 | 1 | 0 | tight — the floor has closed around you |
| west hall | 6 | 1 | 2 | the court appears; `SOUTH LANE 28% FORESHADOW` |
| **court** | 6 | **0** | 3 | the middle of the floor is *all partial knowledge* |
| south lane | 5 | 1 | 2 | junction resolves; terrace only glimpsed |
| hall | 5 | 3 | 1 | the puzzle doors resolve on arrival |
| puzzle bay | 5 | 3 | 1 | terrace still only 4% |
| junction | 2 | 1 | 1 | final approach |

**Orientation now, foreshadowing next, route later** — and the court, the floor's centre, solves
nothing at all.

## 6. Are the height-9 walls still necessary?

**No.** Every mass in the proposal is **height 4**, and the reveal profile above is better than
the shipped floor's. The height-9 slabs were compensating for placement, not for physics: they
stood near the player, where shadow reach is shortest.

One correction from the measurement itself, worth recording because it was my error: the first
massing run left the Hall at **80% visible from the Landing** — whole-room comprehension of a
late space. The fix was not a taller mass but the Hall's **own near wall**, standing 50 units
from the viewer instead of 25. Same height, far more shadow.

## 7. Camera

**No A/B proposed, and none needed.** The ruling made a camera proposal conditional on
current-camera massing failing. It does not fail. Camera work stays on ROADMAP rather than
half-opened.

## 8. What I want ruled

1. **The blockout** — four legs, the space names and rough coordinates above.
2. **All masses at height 4**, dropping the height-9 slabs entirely.
3. **The court as the floor's centre of gravity** — a broad open space that resolves nothing,
   with the Vault branching east off it.
4. **Keeping the existing beats** in their new homes: spikes in the south lane, the integrated
   chamber in the hall, alternating doors in the puzzle bay, one-way commitment at the descent.

No new capability is required. On approval I will author it, re-measure on the real plan, and run
the integrated checks before handing it over.
