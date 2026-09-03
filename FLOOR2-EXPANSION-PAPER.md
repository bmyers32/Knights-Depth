# Floor 2 Expansion — Paper Authoring Pass

Section 18-B. **Nothing here is built.** Section 18-A is landed and pushed (738/738 green);
sections C and D wait on this veto.

---

# Part 1 — Two seams returned before implementation

## 1.1 The burrow emergence law (§3 FANG)

**Status: the observed defect is fixed; the underlying law question is still open, and the
ruling asked for it rather than a fallback.**

The Fang vanished because every emergence candidate was refused as illegal placement, the retry
window expired, and `_resolve_burrow_emergence_timeout` killed it. Re-keying confinement removed
the *cause we saw* — candidates ring the player, and the player is no longer outside the actor's
legal bounds.

**The law is still unwritten.** Emergence commits its destination at entry, and that destination
can still become invalid for reasons that have nothing to do with confinement:

- the player retreats through a gate that then closes behind them;
- the player stands somewhere the Fang's body does not fit (a narrow aperture, a ledge lip's
  inner corner);
- the player is ringed by other actors, so every candidate is occupied.

In all three the current resolution is **death by fail-safe**, whose own comment calls it "a v1
SCOPE/INVARIANT FAILURE (open-arena placement only), not a tuning outcome". Floor 2 is not an
open arena, and floors are only getting more enclosed from here.

**Candidate laws, not implemented:**

| | Law | Cost |
|---|---|---|
| A | **Abort to entry.** Re-emerge where it went under — legal by construction, deterministic, no teleport toward the player. "It came back up where it went down." | Burrow sometimes achieves nothing. Arguably correct: the player's retreat *is* the counterplay. |
| B | **Emerge at the nearest legal point toward the committed destination.** Preserves intent under obstruction. | Needs a search; risks emerging somewhere that reads as arbitrary. |
| C | **Keep the fail-safe death** but make it truly unreachable by widening candidates. | Leaves a lethal edge case in place and only moves the threshold. |

**Recommendation: A.** It is the only one that needs no new search, cannot place an actor
anywhere surprising, and matches the P17 language the ruling preserved — *burrow resolves or
truthfully aborts*. **Not implemented; awaiting a ruling.**

## 1.2 The hit-switch seam (§5)

**Finding: existing vocabulary can already express "hit a world target → fire authored floor
effects", and it does so without pretending anything is an enemy.** It cannot express a switch
that *persists*.

What ships today:

- `BreakablePlan` — a hittable world object that is explicitly **not a combatant**. It shares
  only detection with the melee cone and the projectile sweep.
- `TRIGGER_BREAKABLE_DESTROYED` — a trigger watching a breakable, firing on destruction.
- `_fire_triggers_watching("breakable_destroyed", id)` → the ordinary effects list, including
  `OPEN_CONNECTION` and `BLOCK_CONNECTION`.

So **shoot object → door opens is authorable right now**, with zero new vocabulary. Floor 1
already ships a near-identical chain (break crate → `ENABLE_TRIGGER` → plate appears).

**The gap is exactly one thing: the object is consumed.** A breakable that fires effects is
destroyed doing it. That is right for a crate and wrong for a switch — and it makes a *toggle*
(§5's "flip authored door states") inexpressible, since destruction happens once.

**Two honest options:**

| | Approach | Assessment |
|---|---|---|
| A | **Author the switch AS a breakable.** Zero new vocabulary. The switch shatters when shot and the door opens. | Truthful mechanically; the *fiction* is "shoot the fragile thing", not "throw a switch". One-shot only. No toggle, ever. |
| B | **Add `persists: bool` to the breakable seam** — at zero durability it fires its effects and, if persistent, resets to full durability instead of being erased. One field, one branch, reusing the whole existing hit path, registry and trigger kind. Toggle then falls out of authored effects (`OPEN` one, `BLOCK` another). | Genuinely small. Still not a combatant, still not an interactable, no new Command, no `interact` return. |

**Recommendation: B**, and I would keep the name honest — the family is *hittable world object*,
of which a crate is the consumed case and a switch the persisting one. **Flagged, not built.**
If A is preferred the paper below still works; the Vault switch simply shatters.

---

# Part 2 — The expanded floor

## 2.1 What is actually wrong with the current floor

Not size. **You can see the whole argument from the entry.** The Overlook shows the Concourse,
the Concourse shows the fork and the Junction, and the Junction shows the exit. The floor is one
idea, legible in about eight seconds, and everything after that is executing it.

So the expansion adds a **middle the entry cannot see**, not more metres. The fork stops being
the first thing you meet and becomes the thing you arrive at having already done something.

## 2.2 Spaces

Coordinates are indicative and **pre-measurement**; the camera and clearance runs come before
building, as before.

| # | Space | Approx | Earns itself by |
|---|---|---|---|
| 1 | **Overlook** | `(-8,-10) 16x8`, elev 3 | entry, orientation, sightline down onto the Apron only — **no longer sees the fork** |
| 2 | **Descent** | `(-4,-18) 8x8`, elev 1.5 | approach |
| 3 | **The Apron** | `(-20,-36) 40x18` | **first combat pocket.** Static obstacles (3–4 columns) break sightlines; ambient Fang + Ooze. Obstacles make approach angles, not a maze |
| 4 | **The Thicket** | `(-30,-52) 22x16` | **environmental interaction.** Vegetation + destructible debris; conceals the Vault switch. Reached west out of the Apron |
| 5 | **The Spillway** | `(8,-52) 22x16` | **timed hazard.** Two spike pads on the direct line; a slower obstacle-shaped detour around them. Reached east out of the Apron |
| 6 | **Concourse** | `(-26,-66) 52x14` | **primary circulation / fork.** Both branches rejoin here. Keeps the ratified openness; first sight of the Junction |
| 7 | **Route A** *(gated)* | `(-16,-82) 12x14` | shortcut, bought at the control |
| 8 | **Route B** *(open)* | `(4,-82) 12x14` | free route |
| 9 | **The Vault** *(gated)* | `(18,-80) 12x12` | **optional challenge branch**, off Route B behind a switch-controlled door |
| 10 | **Junction** | `(-30,-91) 60x10` | **second traversal pocket**, rejoin; seen across the gap |
| 11 | **Terrace** | `(-28,-105) 16x12`, elev 1 | final approach + exit |

**Eleven spaces, and the Overlook can see three of them.** The Thicket and the Spillway are
parallel branches off the Apron — both lead to the Concourse, so neither is a detour you regret,
and taking one means not seeing the other. That is replay value from geometry alone.

## 2.3 Pacing

```
ENTRY ──► DESCENT ──► APRON ──────────────► CONCOURSE ──► ROUTE A / B ──► JUNCTION ──► TERRACE ──► EXIT
 look        walk    obstacles + fight   ╱   fork          shortcut vs      rejoin       final
                                        ╱    + control      free route
                          ┌── THICKET ─┤     (visible from
                          │  conceal   │      one place)
                          │  + switch  │
                          └── SPILLWAY ┘          VAULT ◄── switch-controlled door
                             spike timing         optional challenge branch
```

Distinct interactions before the exit: **fight among obstacles · break/search vegetation ·
shoot a concealed switch · time a hazard crossing · choose a route · optionally take the
Vault**. None of them is a corridor.

## 2.4 The concrete beats

### Concealment → discovery (§10.1)
**In the Thicket.** A cluster of vegetation/debris breakables; one of them conceals a **real
authored object** — the Vault's hit-switch — which begins **hidden and becomes visible** when
its cover is destroyed. This is `REVEAL` in its literal sense, and it is the mechanism Floor 1
already ships for the crate → plate chain.

- **Object revealed:** the Vault switch (a real hittable world object, not a cue).
- **Seen from:** standing in the Thicket, after breaking the cover in front of it.
- **Through:** no aperture — it is in the same room, physically behind the vegetation.

### Remote hit-switch → door (§10.2, §5)
The revealed switch is **not** where the door is. It sits in the Thicket; the Vault door is off
Route B, across the Concourse.

- **Observation point → target:** the player must return to a spot with a sightline to the
  switch and shoot it. Sightline to be **measured before building**, not asserted.
- **Effect:** `OPEN_CONNECTION` on the Vault door, authored explicitly.
- Deliberately a different verb from the plates: a plate is *go and stand*; the switch is
  *notice, line up, and hit*.

**Flag:** if the switch is only ever shot from point-blank after breaking its cover, the "remote"
half is fiction. Two candidate fixes — put the switch across the Thicket's own void so its cover
must be broken from range, or place cover such that the shot is naturally taken from a distance.
**Measured before building; if neither reads, I return that rather than pretending.**

### Timed hazard (§10.3, §7)
**The Spillway.** Two spike pads on the fast line between the Apron and the Concourse, with a
slower obstacle-lined path around them. **Not a choke point** — never "stand still, wait, cross".
The pads are on the *quick* route, so the decision is pace versus patience, and during a fight
they become a positioning hazard rather than a gate.

### Destructible composition (§10.4)
**The Thicket**, beyond the concealment cluster: debris partly blocking the direct line to the
Concourse. Break through, or walk around. Ordinary destructibles only — **no chain-clear, no
explosive, no delayed, no respawning.** Per §19 those stay unbuilt until a floor needs them.

### Obstacle-shaped combat (§10.5)
**The Apron.** 3–4 static obstacles, broad and widely spaced: cover and approach angles, no
slalom. Every lane between them will be **width-verified against the widest authored body**
before building — the clearance guard landed in 18-A does exactly this, and §12 requires it.

## 2.5 The Vault as an optional branch (§11)

**Structure:** main route stays valid and never touches the Vault. The Vault sits behind a
**visibly closed door** off Route B. Its door is controlled by the Thicket switch — so the player
sees a shut door, and separately finds a switch, and connects the two.

**Explicitly: no enemies are spawned in the Vault merely because it is optional** (§11).

**Beat account, honestly:**

| | |
|---|---|
| Player pays | a branch into the Thicket, breaking cover, finding and hitting the switch, then walking to the Vault |
| Player receives | access to a room that, today, contains **nothing of value** |
| Exchange | **still not net-positive** |

> The route to the Vault is now interesting. The **destination** is not. Environmental
> interaction makes the journey worth doing; it does not substitute for a reason to arrive.
> **This remains blocked on reward vocabulary**, and I am not going to claim otherwise by
> putting a fight in there.

**Two ways forward, for the ruling:**
1. Build the branch now, with the Vault as an empty room, and accept it is a placeholder
   destination whose payoff arrives with the reward seam. The *interaction chain* is real and
   testable regardless.
2. Hold the Vault branch until reward vocabulary exists, and spend this expansion's optional
   space on the Thicket/Spillway fork alone — which is already a real choice.

**Recommendation: 1**, because the switch/door/conceal chain is the thing we want to prove, and
an empty room is honest where a manufactured fight would not be.

## 2.6 What this needs built (§18-C)

Only the consumers this floor actually uses:

| Capability | Status |
|---|---|
| Static gameplay obstacle authoring | **NEW.** Solid to bodies *and* to projectiles, from one authored fact — no presentation-only cover |
| Ordinary destructible (vegetation/debris) | **Mostly exists.** `BreakablePlan` ships; needs no new law for break-to-clear |
| Concealment → reveal a real object | **Exists.** `conceals_trigger_id` + `ENABLE_TRIGGER`, shipped on Floor 1 |
| Remote hit-switch → door | **Needs the §1.2 ruling.** Option A: zero new vocabulary. Option B: one field |
| Timed spike pad | **NEW.** Authoritative SAFE/ACTIVE cycle; environment→actor damage source to be audited first |
| Chain-clear / explosive / delayed / respawning | **NOT NEEDED.** Stay unbuilt (§19) |

**Capability flag on the spike pad:** §7 requires auditing whether environment→actor damage has
a truthful source representation today. It does not — every damage path currently originates
from an `attacker_id`. A hazard is not an attacker, and giving it a fake actor id would be
exactly the pretending §7 forbids. **I will return that seam with the spike-pad implementation
rather than inventing a phantom attacker.**

## 2.7 Risks I want on record

- **Scale.** Eleven spaces is roughly 2.5× the current floor. If it plays as *long* rather than
  *full*, the Thicket/Spillway pair is the first thing to cut — they are parallel, so removing
  one costs no connectivity.
- **AI under obstacles (§12).** Accepted v1 locomotion is the constraint. Lanes get measured, and
  if a normal composition exposes a real navigation deficiency I return it as a concrete
  consumer rather than deforming the floor around the AI.
- **Two new mechanics at once** (obstacle + spike pad) plus a possible seam change. If that is
  too much in one batch, the spike pad is separable — the Spillway degrades to an
  obstacle-shaped alternate route and stays a real choice.

---

## Veto surface

1. **§1.1** — burrow emergence law: A / B / C, or leave open.
2. **§1.2** — hit-switch: A (switch shatters) or B (one `persists` field).
3. **§2.2** — eleven spaces, or fewer.
4. **§2.5** — build the Vault branch as a placeholder destination, or hold it.
5. **§2.6** — spike pad in this batch, or deferred.

Environmental vocabulary beyond the above stays held. No generator, no family framework, no
reward system.
