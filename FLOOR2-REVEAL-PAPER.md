# Floor 2 — Reveal and Scale, measured

Steps 8–10 of the iteration order, returned for approval before the expansion is built.
Steps 1–7 are landed and pushed (793/793 green).

---

## 1. The finding, measured

`tools/measure_floor_reveal.gd` projects every space through the real shipped camera **with
occlusion modelled** — the ray from camera to ground is blocked when it passes below a wall or
obstacle it crosses. From the entry:

> **10 of 11 spaces are in view from the drop. Six of them at half or more.**
> `OVERLOOK 100% · DESCENT 100% · LANDING 84% · THICKET 64% · SPILLWAY 60% · VAULT 88% ·
> GALLERY 48% · ROUTE A 48% · ROUTE B 48% · JUNCTION 12%`

The human's report was exact. The **Vault** — the optional branch that is supposed to be a
discovery — is 88% visible before the player has taken a step.

### My previous check was invalid, and that is worth stating plainly

The last build shipped a test asserting "the entry cannot see the later floor", implemented as
*world distance*: the Gallery is 40+ units beyond the Overlook. **Distance along the view axis
does not remove anything from view.** It only makes it smaller. The test passed and the floor
was fully exposed. A proxy that cannot fail for the reason it names is not evidence — the same
lesson as the retired shape-guard, arriving from a different direction.

## 2. Why, mechanically

The camera is fixed: 45° down, no rotation, always looking along −z. Measured view half-width:

| Depth ahead | 0 | 10 | 20 | 40 | 60 |
|---|---|---|---|---|---|
| Visible half-width | **13.0** | 18.4 | 23.9 | 34.7 | 45.6 |

**The view is deep and narrow.** It widens about **0.54 units per unit of depth**.

Two consequences:

1. **A floor laid out as a north–south column is read end to end.** Every space is "ahead", and
   ahead is exactly where this camera looks.
2. **Lateral offset alone cannot win.** To hide a space at depth *d* you need an offset greater
   than `13 + 0.54d` — which grows as fast as the floor does. I measured a switchback proposal
   with legs pushed 58 units west: it improved the drop from 10 spaces to **8**. Not enough,
   and it made the floor enormous to buy very little.

## 3. The two levers that actually work

**A. Ground behind the camera is invisible.** The camera sits at `player.z + 12`; anything at a
greater z is off-screen entirely, at any distance. So a floor that **folds back** hides its later
legs completely rather than by degrees. This is the strong tool and it costs no width.

**B. Real occluders.** Walls and tall obstacles genuinely block the ray — the instrument now
proves it. But here is the tension worth surfacing:

> **Floor 2 currently has almost nothing to occlude with.** Every patch edge is `ledge`, by an
> earlier decision the human liked — the low rim reads well. But a low rim occludes nothing. The
> floor's own aesthetic is part of why it shows itself all at once.

That is not an argument to wall everything in. It is an argument that **some walls must come
back, placed deliberately for sightline control** rather than as room boundaries — which is
exactly what the ruling authorises ("walls/terrain/obstacles used for sightline control").

## 4. Proposal

### Shape: fold the floor, don't stretch it

Three descending legs, each folding back on the last, so a later leg is *behind* the camera
rather than merely far from it:

```
        ENTRY ─► LANDING ────────────────────────►  (leg 1, running EAST)
                                                 │
                                                 ▼  short descent
   ◄──────────── GALLERY ◄──── SPILLWAY ◄────────   (leg 2, running WEST)
   │
   ▼  short descent
   PUZZLE ─────► JUNCTION ─────► TERRACE ─► EXIT     (leg 3, running EAST)
```

Each fold is a short z-step with an **occluding wall along the fold**, so from leg 1 the camera
sees leg 1 and the top of the descent — and nothing of leg 2.

### Occlusion budget, authored deliberately

- The **fold walls** (3 of them) are the primary occluders and exist for exactly this job.
- Patch edges stay `ledge` where the low rim reads well — open edges are kept as the default,
  and walls are the exception placed for a reason.
- The Gallery keeps its obstacles; they now also earn their keep as sightline breaks.

### Late-floor addition (§13)

Leg 3 adds the **alternating-door section** before the Junction, so the floor keeps unfolding
after the middle rather than collapsing toward the exit.

## 5. The alternating-door puzzle (§14 — geometry returned)

A compact local section. Switch and both doors legible together, no remote causality.

```
            ┌──────── NORTH BAY ────────┐
            │                           │
   entry ──►│   ▣ switch                │
            │                           │
            └──[ D1 ]────────[ D2 ]─────┘
                  │              │
              SOUTH-WEST      SOUTH-EAST
               (dead end,      (the way on)
                but holds
                the second
                switch position)
```

- **State A** (initial): `D1 OPEN`, `D2 CLOSED`.
- Hitting the switch → **State B**: `D1 CLOSED`, `D2 OPEN`.
- The switch is reachable from the north bay, and **both doors are visible from it**.
- Progression: the player must be on the correct side when they flip it — so the beat is
  understanding the toggle, not finding it.

**Connections needed: 2** (`D1`, `D2`). **Switches: 1**, mode `toggle`, effects
`TOGGLE_CONNECTION D1` + `TOGGLE_CONNECTION D2`. No new vocabulary — `TOGGLE_CONNECTION` and the
persistent switch both landed already, and this is a far better consumer than the Vault was.

**Presentation:** the switch already changes colour on activation (landed). Doors carry the
primary read through their own barrier geometry appearing/disappearing.

## 6. Predicted reveal, and how it will be checked

Target: **from the drop, no more than 3 spaces in view, none of them past the Landing.**

I have *not* pre-measured the fold proposal, because unlike a lateral offset its effect is
categorical — ground behind the camera is not visible at all — and pre-measuring would mean
authoring it. **The check happens after authoring, with the same tool**, and the number goes in
the build report whether or not it flatters the result.

## 7. Traversal, current vs proposed

| | Current | Proposed |
|---|---|---|
| Major spaces | 11 | 12 (adds the puzzle section) |
| Longest straight sightline | the whole floor | one leg |
| Spaces visible from drop | **10** | target ≤ 3 |
| Fold points | 0 | 3, each with an occluding wall |
| Connective lanes | 0 (spaces abut through apertures) | 3 legs' worth |

## 8. What I want ruled

1. **The fold.** Three legs with occluding walls at the folds — approved, or a different shape?
2. **Walls coming back.** Some patch edges become `wall` specifically for sightline control,
   against the current all-`ledge` aesthetic the human liked. This is the real trade.
3. **The puzzle geometry** above: two doors, one toggle switch, north bay — enough, or does it
   want a third door?
4. **Vault access** stays a concealed one-shot switch, now beside its own door. Correcting the
   record: it was never wired to the toggle.

No new capability is required for any of it.
