# Floor 2 Diagnosis — 2026-09-02

Input for a design ruling. Produced after the human ITERATE verdict. **No floor composition
has been changed:** the three legality/truthfulness defects were repaired because they were
ordered, and the rename was ordered. Every beat is exactly as the human played it.

Where a claim could be measured it was measured. Two of my own starting assumptions were
wrong and are corrected below.

---

## 1. Closed-gate bypass — reproduced, fixed, generalized

**The defect.** A closed connection claims to separate two patches. Nothing checked that it
does. Closing a gate removes its aperture from the walkable union and **subtracts nothing** —
so if the two patches also touch each other, the union spans their seam whether the gate is
open or shut.

**Why touching is enough.** Walkable edges are INCLUSIVE and legality is BODY-AWARE against
the UNION. A body straddling the seam of two abutting rects is covered by both halves and
fits perfectly. "Zero shared area" does not mean "not connected" once bodies exist — a
comment in `WalkableBounds` asserted the opposite, and was written before body-aware legality
arrived.

**Reproduction** (`tools/reproduce_gate_bypass.gd`), before the fix:

| Gate | Aperture | Body-legal seam samples | Outside the blocking span |
|---|---|---|---|
| `C_TO_A` (the gated shortcut) | `(-27,-47.5) 10x3` | **365 of 401** | 22 |
| `C_TO_TERRACE` (above the party area) | `(-22.5,-72.5) 5x3` | **377 of 401** | 252 |

Behavioural proof: the Envoy stood **inside Route A on tick 333**, walking straight south,
with `C_TO_A` reporting CLOSED the entire time and the control never touched.

**Both gates on the floor were decoration.**

**The fix, in the authored geometry.** Patches joined by a closable gate now stand off by 2
units, so the aperture is the only thing bridging them. Post-fix: 0 of 401 legal seam samples
on both gates; the Envoy is stopped at z = −45.55, short of the seam.

**The general guard** — `FloorPlan._reject_bypassable_gates`, run inside
`DepthGenerator.generate` so every plan is checked whoever produced it, including a future
procedural producer. Detection only; a plan is never silently repaired. No invisible
collision, no presentation-only panel, no floor-specific exception.

It applies to any **closable** connection, not only those that start shut — a one-way
commitment that seals nothing is the same defect.

**Scope, stated honestly and asserted in the tests.** It proves a gate is the only DIRECT
adjacency between its two patches. It does **not** prove global separation, and must not:
routes that fork and rejoin are legitimate grammar, so "reachable the long way round" is a
routing fact, not a broken gate. A bypass through a third patch bridging both would not be
caught; that case is indistinguishable from an intended rejoin without authorial intent the
plan does not record. **This is the guard's known limit, and the one place it could be
extended if a future floor needs more.**

**Found by the guard — second defect.** Floor 2's connections never named their patches
(`patch_ids` left at `(-1,-1)`). Every structural check above them silently skipped, and
presentation drew each corridor slab at y=0 regardless of elevation — visibly wrong at the
entry descent, where the slab floated below ground standing 1.5–3.0 units higher.

---

## 2. The structure above the final party area — identified

Asked mechanically, not inferred from appearance.

| Question | Answer |
|---|---|
| Object / ID | `C_TO_TERRACE`, connection id **5**. The only authored object between Junction and Terrace. |
| Presentation only? | **No.** A real connection. `FloorBuilder._build_connection` draws two boxes: a corridor floor slab the size of the aperture, and — because `has_barrier` defaults true — a barrier box `aperture.width x 2.6 x 0.6` in `_GATE_CLOSED_COLOR` (red), `visible = not starts_open`. |
| Controlling state | `SimWorld._connection_open[5]`. Opened by trigger `T_PARTY` (group occupancy, all active Envoys on the party plate) via `EFFECT_OPEN_CONNECTION`. Presentation mirrors it through `set_gate_closed` and never decides. |
| Walkability it owns | Its aperture is in the walkable union **only while open**. Since the standoff fix, Junction and Terrace are disjoint, so it is the sole legal crossing — before the fix it owned nothing. |
| Projectile behaviour it owns | A closed gate is a solid line across its aperture (`_gate_segment`), so shots stop at it. See §3 — it was **not** stopping them. |
| Does removing it change progression? | **Yes.** Remove it and the Terrace is unreachable. Remove it *and* the standoff, and the Terrace is permanently open and the party-sync beat has no consequence at all. |

**It is a real gate, not decoration.** Two things made it unreadable: its barrier leaked shots
(§3), and the beat it gates is redundant (§6, row 8). Its visual footprint does correspond to
the authoritative aperture; that part was already true.

---

## 3. Closed gates that stop nothing — third defect, same family

Found while identifying the object above, and verified behaviourally: **a shot fired straight
at the shut shortcut gate passed through it.**

`SimWorld._gate_segment` derives the barrier's axis from the aperture's **proportions**,
assuming travel runs along the aperture's longer dimension. True for a CORRIDOR-shaped
aperture; false for a DOORWAY-shaped one. Floor 2 authored a 10-wide × 5-deep mouth between
patches separated along z, so the barrier was placed **along** the direction of travel. The
projectile ran parallel to its own barrier and never crossed it.

Presentation, meanwhile, always draws the barrier box across the opening. **The picture and
the rule disagreed** — precisely what P34 forbids.

Fixed by authoring both fork mouths deeper than wide, and guarded
(`_reject_misoriented_gate_barriers`). The guard is **pinned to the sim rather than merely
asserted**: `gen/` may not import `sim/`, so the rule is restated in `FloorPlan`, and a second
copy that drifts is worse than no check — the test therefore shoots at a gate the guard
accepts and one it rejects, and requires the sim to agree both times.

**Deliberately not fixed at the root.** The honest fix is to derive the barrier from the
patches a connection joins rather than from the aperture's shape. That changes the sim/gen
registration contract (`register_connection`), which is a ruling, not a repair. **Flagged for
decision.**

---

## 4. The Vault wall — legibility failure, root cause identified

Classified as ordered: **the geometry is structurally correct and communicates the wrong
thing.** Not the same class as the bypassable gate.

**Root cause: `ledge` has no presentation at all.** The boundary vocabulary has two values and
only one of them draws anything. `wall` → a box. `ledge` → *nothing*. So "intentional open
edge" and "wall not built yet" are rendered by literally the same picture — an absence. The
Vault reads as unfinished because an unfinished room and a deliberately open-sided room are
visually identical under the current renderer.

Three compounding factors, in order of weight:

1. **No visual language for an intentional edge** (above). The root cause, and
   floor-independent — Floor 1's fully-open hall has the same ambiguity; it simply never had a
   *partially* walled room to contrast against.
2. **The open side is not an entrance.** The room is entered through a mouth in the *west*
   wall; the open *east* side is not a route and leads nowhere. An opening that is not a
   passage reads as a missing wall. This is the human's own condition — *"unless the opening
   leads somewhere intentional"* — stated exactly.
3. **The asymmetry has an invisible reason.** Three walls and one open side, where the open
   side faces off the edge of the map. The reason (projectile occlusion for the encounter
   inside) is real but cannot be perceived from inside the room.

Not automatically converted to all-`wall`, and not preserved to save the per-edge consumer.

**Note the coupling:** the Vault is currently the per-edge vocabulary's only shipped consumer.
If §8's recommendation is declined and the Vault is removed, the per-edge capability returns
to zero consumers and falls under the same retirement rule that retired the `switch`
interactable. That is a consequence of the beat ruling, not an argument against it.

---

## 5. Terminology — done

The hostile open room was called a **Commons**. LEXICON reserves that for the *safe* upper
inhabited layer and the M4 hub — the one warm name in the vocabulary. A room full of enemies
wearing it makes that word mean nothing.

Renamed to **the Concourse** (Ancient register: Lattice infrastructure built for movement, not
for living). Both the reservation and the new term are recorded in LEXICON.md.

---

## 6. Beat-economy account

Measured at each decision point through the real shipped camera
(`tools/measure_floor2_legibility.gd`), because **a currency the player cannot see when they
choose is not a currency.**

| # | Beat | M/O | Player pays | Player receives | Currency | Exchange |
|---|---|---|---|---|---|---|
| 1 | **Overlook** | M | seconds | Concourse far edge + Route B mouth at 10% down screen. Junction/Terrace only marginal (top 0–5%) | information, orientation | **weak-positive** |
| 2 | **Ramp** | M | seconds | nothing | — | **neutral** (connective tissue; legitimate) |
| 3 | **Concourse** | M | crossing distance; an avoidable Ooze + Fang | sightline to the Junction (19% down), route choice, the control | information, revealed destination, encounter-avoidable | **net-positive** — the floor's strongest beat, human-ratified |
| 4 | **Route B** | M-ish | distance (lands far from the plate) | progress with no prerequisite | progression access | **neutral** — the baseline A is measured against, a legitimate role |
| 5 | **Vault** | O | detour, voluntary combat, time, risk | **nothing** | **none exists** | **TAX** |
| 6 | **Control + response** | O | a near-free detour; wakes a Watcher | Route A access | route access | **weak** |
| 7 | **Route A** | O | — | lands beside the party plate; measured at <50% of B's distance | distance saved | **weak** |
| 8 | **Intermediate party-sync** | M | regrouping, standing still | a door opens a few steps away | progression access | **REDUNDANT TAX** |
| 9 | **Final all-party exit** | M | regrouping | floor completion | progression access | **net-positive**, ratified |

### Two corrections to my own assumptions

**I was wrong that Route A's payoff is illegible.** Measured: from the control plate the party
plate reads at **12% down, 37% across**; from mid-Concourse at **16% down, 9% across**. The
player *can* see what the shortcut buys.

**What is actually illegible is the alternative.** From mid-Concourse both route mouths measure
**OFF-SCREEN**, horizontally. The camera reaches 34 units of width at the mouths' depth; the
mouths sit **46 apart**. They are 12 units too far apart to ever appear together.

> **The player never sees the fork as a fork.** They see a destination and one wall of a very
> wide room, and pick a side by walking at it. That — not the shortcut's value — is why the
> choice does not read as a choice.

A general, reusable constraint follows: **a lateral choice only reads as a choice if both
options fit the camera's reach at the decision point.** The Concourse is 52 wide; the camera
shows 26 units at the player's own depth.

Two further measurements worth banking:

- **The Vault** shows a mouth and a plate at the far right edge (78% / 94% across) with its
  **interior off-screen**. You see a side room with a button, and cannot see what is inside or
  what it is for — which is precisely "random."
- **The redundancy of beat 8 is visible on screen.** Standing on the party plate, the *actual
  exit plate* is already visible at 24% down. The player looks at the real exit while standing
  on a plate whose only job is to open the door in between.

### The single root cause under beats 5, 6 and 7

**The floor has one currency and spends it on itself.** Route access buys route access. On a
floor walked once, "another route" and "a shorter route" are the only things anything can pay,
and neither compounds. That closed loop — not the number of beats — is why several beats feel
like tax. Beat 5 fails hardest because it is a *dead end*: it cannot even pay in route access.

---

## 7. Split

### FIXABLE NOW WITH EXISTING VOCABULARY

| Beat | Finding | Existing-vocabulary fix |
|---|---|---|
| 1 | Overlook establishes the room but not the choice | Reposition/raise the Overlook, or narrow the fork, so both mouths are in reach. Elevation + position only. |
| 3 → 7 | The fork is 46 apart in a 34-unit view | **Narrow the Concourse, or bring the mouths inboard.** Pure geometry. The highest-value single change on the floor. |
| 5 | Vault has no payoff | **Move the Route A control INTO the Vault.** The optional fight then pays in route access — a currency that already exists — and the control stops being free. One change fixes 5 and 6 together. |
| 6 | Control is nearly free; its response is escapable | Same change: the cost becomes the Vault fight, not a Watcher the player can walk away from. |
| 7 | The shortcut's saving is real and visible, but the alternative is not | Follows from the fork fix. Optionally re-currency it: let Route B force an encounter Route A bypasses (encounter vocabulary, already shipped). |
| 8 | Party plate redundant, visibly so | (a) **Remove it**, letting the exit own synchronization; or (b) all-ready → **activates a final encounter** → clearing it opens the exit. Both use shipped vocabulary; (b) is the real *"everyone ready to trigger something"* semantic. |
| §4 | Open edge reads as an unbuilt wall | **Give `ledge` a presentation** — a low lip or kerb at open edges. Presentation-only, reads the same derived segments, single-source preserved. Fixes every ledge on every floor, not just this room. |

### BLOCKED ON FUTURE VOCABULARY

| Want | Blocked on |
|---|---|
| An optional encounter that pays in **gain** rather than route access — "a fight worth taking" rather than "a fight that unlocks a door" | loot / reward / economy vocabulary |
| Making the Concourse **crossing** itself interesting rather than merely wide | environmental hazard vocabulary (the held package) |
| A second, non-route currency, so the floor stops paying itself | reward economy |

**"Needs reward" is recorded as a finding, not as authorization.**

Every beat currently marked TAX has an existing-vocabulary fix available. **The floor does not
need new mechanics to stop feeling like tax** — it needs its one currency spent outward instead
of in a loop, and its lateral choice to fit on screen.

---

## 8. On the Vault surviving

Per the instruction not to force it: the Vault **can** be saved within existing vocabulary, by
making it the home of the Route A control. That is a genuine answer to *"why might I choose to
do this?"* — you fight for the shortcut — and it costs nothing new.

If that is not taken, it should be **removed rather than kept**, and preserved as a candidate
for reward/environmental vocabulary. A fake optional beat is worse than none.

**Recommendation: fold the control into the Vault.** It converts the floor's two weakest
optional beats into one real one, and it is the only change that gives an optional encounter a
price the player can already understand.

---

## Status

719/719 green. Floor 1 unaffected and passes both new guards unchanged, so its one-way
commitment was authored correctly all along.

Awaiting ruling. No beat has been resequenced, repositioned, removed or retimed.
