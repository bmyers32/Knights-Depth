# Environmental Damage Source — Narrow Seam Audit

Section 14-C, returned before the spike pad is coded, as ruled. **Nothing implemented.**

---

## What `attacker_id` actually drives

Audited inside `_resolve_hit_on_target`, the one function every damage path funnels through.
There are **three call sites** in the whole sim, and `attacker_id` is consulted for exactly four
things:

| # | Use | Site | Truly needs an attacker? |
|---|---|---|---|
| 1 | **Event provenance** — `attacker_id` in `hit` / `attack_absorbed` payloads | payload construction | **No.** Informational. Needs a *source*, which may be an actor or not. |
| 2 | **Shield block** — `_resolve_blocked_hit(..., attacker_id, ...)` | held-shield branch | **No**, and see the open question below. |
| 3 | **Parry** — `_try_parry(target_id, attacker_id)` | inside the block branch | **Yes**, structurally: a parry exposes *the attacker*. A hazard has nobody to expose. |
| 4 | **Aggro acquisition** — `if _allegiance.get(attacker_id, &"enemy") == &"player": _acquire_aggro(target_id)` | post-damage | **No.** It asks one yes/no question: *was this caused by the player?* |

**Only #4 changes behaviour**, and it only reads a category, never an identity. Everything else
is either provenance or an actor-versus-actor defence that a hazard has no counterpart for.

## The narrow representation

> **A damage source is `{kind, id}`.** Every damage today is implicitly
> `{kind: actor, id: attacker_id}`. Environmental damage is `{kind: environment, id: <hazard id>}`.

Concretely, and deliberately without a new pipeline:

1. One **defaulted** parameter `source_kind: StringName = &"actor"` threaded into
   `_resolve_hit_on_target`. Three call sites; every existing caller is unchanged.
2. Four guards on `source_kind == &"actor"`: shield block, parry, aggro, weapon knockback.
3. Payloads gain `"source": source_kind`; `attacker_id` becomes `-1` for environment rather
   than a phantom actor. Presentation and tests read the new field only if they care.

**Environmental damage runs the same function**, so GAME-RULES §3's fixed pipeline order (hit →
matrix → status → knockback → death/events) is preserved rather than duplicated. A second
resolution path would be the real risk here, and this avoids it.

**Blast radius:** 3 call sites, 4 guards, 1 payload field. `attacker_id` appears 34 times in the
sim, but the rest is provenance plumbing that a `-1` satisfies. Six test files read the payload;
none of them assert on hazard damage, because none exists yet.

**No phantom attacker ids. No environment faction. No AI entity.**

---

## Three questions I cannot answer from the code

These are design rulings, not implementation details, and they are why this is returned rather
than built.

### Q1 — Does a held shield block environmental damage?

A shield is aimed. Spikes are underfoot. Blocking them with a raised shield reads wrong, and
it would also let a player stand in a hazard indefinitely by holding block.

**Recommendation: no.** Environmental damage ignores the shield entirely. It is not an attack
arriving from a direction.

### Q2 — Do i-frames negate environmental damage?

Today i-frames "fully negate a hit: no damage, no knockback, no status, no meter" — a locked
invariant for attacks. If they also negate hazards, a dodge-roll through a spike field is free,
which is arguably good movement play and arguably an exploit.

**Recommendation: yes, i-frames still negate it** — but flagged as the one with real gameplay
consequence, and the one most likely to want revisiting after play. It keeps the invariant
locked rather than carving an exception into it on paper.

### Q3 — Does hazard damage acquire aggro?

**Recommendation: no.** `_acquire_aggro` exists so that hitting an enemy makes it notice *you*.
A spike pad is nobody. Enemies should not become aware of the player because the floor hurt
them.

---

## What this unblocks

The same representation serves the **explosive block** (§11) without further change: an
explosion is environment-sourced damage with a position and a radius. That is the second
concrete consumer the ruling asked the seam to support, and it needs nothing this does not
already give it.

**Not designed here:** damage *profiles* for hazards (type, amount, tick cadence) are content,
and belong in the spike pad's own resource rather than in this seam.

---

## Recommendation

Implement the three-point representation above with Q1 = no shield, Q2 = i-frames apply,
Q3 = no aggro — **on your ruling**, since all three are felt in play rather than visible in code.
