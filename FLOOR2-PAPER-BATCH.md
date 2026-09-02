# Floor 2 Iteration — Paper Batch

For cheap veto **before** building sections D–G. Sections A and C of the ruling are already
landed (724/724 green). Nothing in D–G has been authored.

Measured on paper coordinates through the real shipped camera
(`tools/measure_floor2_fork_proposal.gd`), so the veto is informed rather than speculative.

---

## 1. Revised fork sequencing

**The failure being fixed:** the mouths sit 46 apart; the camera reaches 34 units of width at
their depth. Both measured OFF-SCREEN. The player never saw a fork.

**Proposal: keep the Concourse's ratified width, bring only the MOUTHS inboard.** The human
ratified the openness, so the fix spends nothing that worked. Only the routes move.

| | Shipped | Proposed |
|---|---|---|
| Concourse | `(-26,-46) 52x28` | **unchanged** |
| Route A | `(-30,-62) 14x14` | `(-16,-62) 12x14` |
| Route B | `(16,-62) 14x14` | `(4,-62) 12x14` |
| Mouth separation | 46 | **20** |
| Vault | `(32,-60) 12x12` | `(18,-60) 12x12` (follows Route B) |

**Measured result** — three candidate decision points, all with both mouths legible:

| Stand | Mouth A | Mouth B | Junction |
|---|---|---|---|
| `z = -34` | 27% down / **25% across** | 27% down / **75% across** | 13% down / 50% across |
| `z = -40` | 35% down / 20% across | 35% down / 80% across | 16% down / 50% across |
| `z = -44` | 43% down / 16% across | 43% down / 84% across | 19% down / 50% across |

Symmetric, both flanking the destination, which sits dead centre. That reads as **"two ways
down, the place you're going straight ahead"** — a fork presented as a fork.

**Preserved as required:** Junction still visible across the gap (15-unit void unchanged, middle
still unwalkable); Route B initially open; Route A initially gated. Camera untouched.

---

## 2. Route A control — exact placement, and what a one-pass floor does to it

**Re-costed against the real destination.** With the intermediate party plate removed (§F),
Route A no longer saves distance to a plate whose purpose needed explaining — it saves distance
to **the exit, which the player can already see**.

- Route A foot → exit: **21.5**
- Route B foot → exit: **35.5**
- **Route A saves 14.0 units of walking.**

**Then the control was costed in the same currency it pays in:**

| Control placement | Detour cost | Verdict |
|---|---|---|
| On the way west (shipped position) | **5.2** | Worth it — saves 8.9 more than it costs |
| West wing (a real detour) | 17.7 | **Never worth it** — costs 17.7, saves 14.0 |
| East wing (on the way to the default route) | 33.4 | **Never worth it** |

### The finding this produces

> **On a one-pass floor, distance cannot be a control's price.** For the shortcut to be worth
> buying, the detour to its control must be *much* smaller than the saving — which means the
> control must sit nearly on the way — which means it is nearly free. A free control is not a
> choice. The two constraints are in direct opposition, and no placement resolves them.

This is a structural result, not a tuning problem. **Placement cannot fix beat 6.**

**Therefore the control's real price must be the response it wakes** — the only other currency
available. Proposed, within existing vocabulary and *without* moving the control into the Vault:

- **Control stays in the Concourse** at a ~5-unit detour (`(-14, -32)`, essentially the shipped
  spot). Per §E.
- **The response moves to Route A's mouth** instead of spawning loose in the open Concourse.
  Today it wakes in the room the player is already standing in and can simply be walked away
  from, so even its cost is soft. Placed at the route it opens, the price is paid by whoever
  actually takes the shortcut.

That makes the trade legible and real: **long walk, free — or short walk, through something.**
Both sides are existing currencies (distance saved / encounter). No new mechanics.

**Flagged:** this is the one place I am proposing a change the ruling did not explicitly order.
It is offered because the measurement showed placement alone cannot work, and §E asked for the
finding if Route A's value stayed weak. Veto it and the control simply stays as shipped, weak
for the reason measured above.

---

## 3. Vault — no reveal is proposed

Per §G, the encounter is **deactivated**; the room stays as exploratory space.

**With no encounter inside, there is nothing to reveal.** Under the REVEAL rider, a tease must
name a real authored object that changes from hidden to visible, seen from a stated point
through a stated aperture. An empty room offers no such object, and inventing one purely to
justify a tease is exactly the expansion of reveal semantics the rider forbids.

**So: no tease, no reveal, no `REVEAL_INTERACTABLE` use on this floor.** Returned as a finding
rather than solved.

**Consequence to note honestly.** The Vault's mixed boundary was authored to occlude the fight
inside. With the fight gone, that rationale is gone. What remains is a spatial read — an alcove
walled on three sides and open to the drop on the fourth — which the new ledge lip (§C, landed)
now makes legible as an intentional edge. **That is a weaker reason than the original.** If it
is not convincing, the honest alternatives are all-`wall` (a plain side room) or all-`ledge` (an
open shelf); either would leave per-edge overrides with **zero shipped consumers** and due for
retirement under the same rule that retired `switch`. Flagged for decision; I have not assumed
one.

---

## 4. M1 exit/elevator presentation audit — inheritance decision

### What M1 already ships

| Element | Where | What it is |
|---|---|---|
| Exit plate | `floor_builder.gd:288` | Mesh is **exactly** the trigger region. Orange `(0.92,0.62,0.24)`, thick `0.12`, emissive `0.5`. |
| Prominence | `floor_builder.gd:88` | **Derived** from `trigger.kind` — `TRIGGER_GROUP_OCCUPANCY` renders loud, everything else minor/blue/thin. Never authored twice. |
| End marker | `floor_builder.gd:310` | A 1.6 × 3.2 × 1.6 gold emissive pillar standing inside the exit plate. Test-enforced to sit within the plate region. |
| Floor complete | `arena.gd:626` | **`print("FLOOR COMPLETE: ...")` and nothing else.** No screen change. |
| Death | `arena.gd:533` → `failure_overlay` | "Synchronization Failure / Press R to restart" |

### What does not exist

**No elevator anywhere in code** — no scene, script, resource, constant, or field. It is
explicitly ruled out of current scope in three separate source comments. No next-floor preview.
No title screen, no run-end success screen, no transition, no fade, no HUD.

### Decision

**Floor 2 inherits the M1 dialect unchanged. Nothing is evolved, and nothing is invented.**

- The exit stays a group-occupancy plate plus end-marker pillar.
- It inherits the loud orange treatment **automatically**, because prominence derives from
  `trigger.kind` — removing the intermediate party plate (§F) requires no presentation work at
  all, and leaves the exit as the floor's only commitment plate, which is exactly the emphasis
  the ruling wants.
- **There is no elevator to inherit or parallel-invent.** The question does not arise.

**Gap recorded, not filled:** winning a floor currently produces *less* feedback than dying — a
`print()` versus an overlay. That is real, and it is M2 gate scope (run-end / Emergency Recall
framing), not this iteration. Building it now would be inventing the second dialect the rider
warns against, one milestone early.

### Standing rule banked

> Before inventing presentation for a newly generalized mechanic, check whether an earlier
> milestone already presented one of its concrete members. Reuse, or evolve consciously and say
> so.

Recorded in BRAIN.md.

---

## 5. Hostile-area rename — already landed

**Commons → the Concourse.** LEXICON now reserves *the Commons* for the safe upper layer and
M4 hub explicitly, and adds *Concourse* (Ancient register: Lattice infrastructure built for
movement, not for living). Code identifiers renamed with it (`P_CONCOURSE`,
`E_CONCOURSE_AMBIENT`).

---

## 6. Revised beat accounts — existing currencies only

### Route A

| | |
|---|---|
| **Pays** | a ~5-unit detour to the control; **and an encounter at the route's mouth** (proposed §2) |
| **Receives** | 14.0 units of walking saved, to a destination the player can already see |
| **Currency** | distance saved · encounter (as cost) · route access |
| **Exchange** | **net-positive and legible.** Both sides are visible at the decision point: the fork is on screen (§1), and the exit is what the saving points at. |
| **If §2 is vetoed** | Pays 5.2 distance, receives 14.0 distance. Still net-positive, but the control remains nearly free — "press this, get a fight you can walk away from." Weak for the measured structural reason, not a fixable one. |

### Vault

| | |
|---|---|
| **Pays** | a short detour off Route B. **No combat, no risk** — the encounter is deactivated |
| **Receives** | exploratory space; a room to look into and leave |
| **Currency** | none — and that is now honest, because nothing is charged |
| **Exchange** | **neutral, deliberately.** It is a place, not a transaction |

The Vault is **explicitly a placeholder consumer awaiting reward/environmental vocabulary**, and
is **not** evidence that meaningful optional content has been solved. Recorded as required by §G.

---

## Build list, if this passes veto

1. Move Route A / Route B / Vault inboard (§1); re-point apertures.
2. Remove `T_PARTY` and the `C_TO_TERRACE` gating beat; the terrace connection becomes always-open
   with no barrier (§F).
3. Deactivate `E_VAULT` and `T_VAULT`; keep `P_VAULT` and `C_VAULT` (§G).
4. Move the control response to Route A's mouth (§2) — **only if not vetoed**.
5. Re-run the real-camera fork measurement on final authored coordinates, and require both mouths
   visible.
6. Mechanical verification: route legality · gate behaviour · projectile blocking · Route B
   progression · Route A gating/control · final all-party exit · Junction sightline · both fork
   mouths visible · Floor 1 unaffected.

Environmental vocabulary remains held.
