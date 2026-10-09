# P36 — Macro Composition Seam: Reconciliation Audit

**No code. No law edits. No Floor 3. No generator.** Base `8737b48`, 835/835.

---

## 1. Current repo reality

| Contract | What it actually is today |
|---|---|
| `DepthGenerator.generate(seed, depth) -> FloorPlan` | Live and pinned. Body is **a two-entry `if depth >= 2`** selecting one of two authored layouts. Stamps `run_seed`, `floor_seed`, `depth`, `stratum_id`, `authored_layout = true`, then validates. |
| `derive_floor_seed(run_seed, depth)` | Live, tested, **unused by both layouts** — deliberately kept warm so the determinism path cannot rot while assembly is off. |
| `ArchivePrototypeLayout` (Floor 1) | 320 lines, **21 authored placement calls**. |
| `ArchiveRoundaboutLayout` (Floor 2) | 818 lines, **108 authored placement calls**, 12 static helpers. |
| `FloorPlan` | Plain data: 4 layer arrays + `entry_point` / `end_marker` + seed/depth/stratum/authored flag. **No mission, family, sequence or position-in-run field exists.** |
| `StratumConfig` | Exactly two fields — `stratum_id`, `enemy_keys`. It is *not* yet a floor family in any meaningful sense. |
| Consumers | `arena.gd` (one driver), 8 test files, the tools. |

**The honest summary:** we have a *floor* contract and no *run* contract. Nothing above `FloorPlan`
exists at all. `depth` is currently doing three unrelated jobs at once — seed input, layout
selector, and the only notion of "where am I in a run".

---

## 2. Contract conflicts and stale assumptions

### UNCHANGED — still directly correct

| Claim | Status |
|---|---|
| Same seed → byte-identical FloorPlan (golden-seed gate) | Holds, tested against a JSON fixture. |
| Gen time < 100 ms/floor | Trivially holds while layouts are authored. |
| `DepthGenerator.generate(seed, depth) -> FloorPlan` as the pinned interface | **Keep.** It is the correct seam whatever produces the plan. |
| `SimWorld` receives floor facts only | Holds. Nothing above FloorPlan leaks into sim. |
| Depth-scaled enemy defence, typed_damage_ramp knobs | Still-unbuilt M2 gate items, unaffected by this seam. |

### TERMINOLOGY / REPRESENTATION DRIFT — same intent, stale wording

| Stale wording | Reality | Note |
|---|---|---|
| "**DepthGenerator**", "procedural depths" | It **selects** authored layouts and says so (`authored_layout = true`, printed on the HUD, pinned by a test) | The *name* implies generation; the seed-honesty comment already documents the gap. Rename is cosmetic and can wait — but do not let the name argue for the architecture. |
| "**≥8 distinct room segments**" | Floor 2 alone has ~22 patches; but they are *authored spaces*, not a reusable **segment pool** | The number is satisfied by accident, not by the mechanism the clause imagined. |
| "**stratum theme drives segment pool + hazard/status set + enemy-family weights (all from config)**" | `StratumConfig` has 2 fields; there is no segment pool, no hazard set, no weights | Drift *and* a real gap. The clause describes the floor-family object this audit proposes. |
| "**seeded 5-floor runs**" | No run object exists; a "run" is one floor loaded by the driver | Intent survives; representation absent. |

### NEEDS HUMAN RULING — genuine design conflict

| # | Conflict | Why it needs you |
|---|---|---|
| **R1** | **"2 themed strata (Archive, Foundry), 3–5 floors each"** vs the newer model of **missions / boss dungeons / Arcade**. A stratum is a *theme*; a mission is a *sequence*. M2's gate treats the stratum as the sequence container. | These are different axes. Does M2 ship "one Archive mission of N floors", or does M2's stratum language get amended to mean family-only? |
| **R2** | **"safe rest floor between strata" + "elevator auto-descend at rest floors"** vs **Safe Commons** as a non-hostile prep layer. | Is the rest floor the Commons, a lesser thing, or is it retired in favour of the Commons? Two names for possibly one object. |
| **R3** | **Arcade uses the actual boss-dungeon floors, not an approximation.** That means an Arcade run must be able to *splice an authored sequence into itself*. | Confirms sequences must be first-class and reusable — but is Arcade M5 (as P6 records) or earlier? It changes whether the seam needs a splice concept now. |
| **R4** | **`depth` overloaded.** It is seed input, layout selector, and run position. Arcade also wants depth as a *progression band*. | Do we split "position in this sequence" from "absolute depth band"? Arcade makes them different numbers. |
| **R5** | **M2 exit says "complete game: title, run-end screen, restart"** — a *run* is required by the gate but has no representation. | The smallest run object is arguably M2 gate work, not deferred macro work. |

---

## 3. Smallest proposed content model

Four resources. Nothing else. Each answers exactly one of §4's questions.

```
FloorSequence  (.tres)   ordered list of FloorEntry + a kind
    └─ FloorEntry        { layout_id, family_id, role }
FloorFamily    (.tres)   environment + enemy/hazard vocabulary   (StratumConfig, grown up)
FloorLayout    (.tres)   the authored spatial data for ONE floor
```

| Question from §4 | Answered by |
|---|---|
| What layout is this? | `FloorEntry.layout_id` → `FloorLayout` |
| What family/variant? | `FloorEntry.family_id` → `FloorFamily` |
| What ordered sequence is this floor in? | `FloorSequence.floors[i]` |
| What kind of sequence? | `FloorSequence.kind` — `mission` \| `boss_dungeon` (Arcade deferred) |
| What progression info selects it? | **Nothing new yet.** Today: `generate(seed, depth)` indexes the sequence. Arcade's band-based selection is deferred until Arcade is real. |

`FloorSequence.kind` is a **StringName tag, not a subclass hierarchy**. A boss dungeon differs
from a mission today only in that its last entry is a boss floor — and we have no boss floor.

**`generate()` keeps its signature.** Its body becomes: resolve the active sequence → index by
depth → load that layout → stamp → validate. Same contract, different body — exactly the
substitution the existing comment anticipates.

---

## 4. Rule-of-two check, per abstraction

| Abstraction | Consumer 1 | Consumer 2 | Verdict |
|---|---|---|---|
| **`FloorLayout` as data** | Archive Prototype (Floor 1) | Archive Roundabout (Floor 2) | ✅ **Earned.** Two real authored floors exist; HANDOFF's own trigger condition is met. |
| **`FloorSequence`** | The Archive mission (floors 1–2) | — **none** | ⚠️ **ONE consumer.** There is no second sequence, no boss dungeon, no Arcade. |
| **`FloorFamily`** | `StratumConfig` "archive" | — **none** (Foundry unbuilt) | ⚠️ **ONE consumer.** |
| **`FloorEntry.role`** | — | — | ❌ **Zero consumers.** No rest floor, no boss floor exists. |

**This is the audit's central finding, and it cuts against the obvious plan:** only the
*layout-as-data* migration has two real consumers. `FloorSequence`, `FloorFamily` and `role` each
have exactly one, and §1.4 says copy twice before abstracting.

The honest recommendation is therefore **narrower than the brief invites**: migrate layouts to
data now; write the sequence object only when a second sequence is actually authored. A
one-entry `FloorSequence` today is a framework wearing a content object's clothes.

---

## 5. What migrates from data-as-code

| Today | Should be | Why |
|---|---|---|
| 129 `_patch/_connect/_trigger/_mass/_spikes/_breakable/_encounter` calls across two layouts | **DATA** (`FloorLayout.tres`) | Pure authored values. Nothing is computed. |
| The 12 `static func _patch(...)` etc. helpers | **CODE**, and it should shrink to one shared builder | Each layout currently owns a private copy of the same twelve helpers. That duplication is the real smell. |
| `_MASS_HEIGHT`, `PARTY_PLATE`, `EXIT_PLATE` consts | **DATA** | Authored tunables (Prime Directive 3). |
| The ~250 lines of **design commentary** in Floor 2 | **CODE comments — keep, and this is a real cost of migrating** | The reasoning for every coordinate lives beside it. A `.tres` cannot hold it. |
| `plan.validate()` | **CODE** in the generator | Already correctly placed for any future producer. |

### Blast radius — measured, not estimated

| Surface | Impact |
|---|---|
| **Tests referencing layout script constants** (`L.P_ARENA`, `L.C_TO_LANE`…) | **141 references** across 4 files: `test_floor2` (89), `test_floor_walkthrough` (47), `test_gate_integrity` (2), `test_projectile_elevation` (3). A `.tres` has **no script constants** — every one of these breaks. |
| **Golden-seed fixture** | Must be re-recorded, with a dated note. Deliberate re-baseline, not a silent one. |
| `DepthGenerator` | Body only. Signature untouched. |
| `arena.gd` | None — it consumes `FloorPlan`. |
| Sim | **None.** Nothing above FloorPlan reaches it. |

**The 141 constant references are the whole cost of this migration**, and they are the reason to
do it deliberately rather than opportunistically. Mitigation exists (a layout resource can expose
a `named_ids: Dictionary`), but that is a design decision, not a detail.

---

## 6. One minimal end-to-end slice, after approval

**Slice A — layouts become data. Nothing else.**

1. `FloorLayout` resource: the four layer arrays + entry/end + a `named_ids` map for tests.
2. **One** shared builder replacing the two private helper sets.
3. Export both existing floors to `.tres` via a tool; keep the `.gd` files as the authoring
   record until the export is proven byte-identical.
4. `generate()` loads by depth from a two-entry table — *still a two-entry table.*
5. Re-record the golden fixture with a dated note.
6. Suite green; Floor 1 and Floor 2 play identically.

**Explicitly NOT in the slice:** sequences, families, missions, roles, Arcade, boss dungeons, any
rename of `DepthGenerator`.

---

## 7. Deferred, and what would release each

| Deferred | Released by |
|---|---|
| `FloorSequence` | A **second** authored sequence existing (a boss dungeon, or a second mission). |
| `FloorFamily` (grown `StratumConfig`) | The **Foundry** — a second family with its own vocabulary. |
| `FloorEntry.role` | A rest floor or a boss floor actually being authored. |
| Arcade band selection / sequence splicing | Arcade being scheduled. P6 records it as M5. |
| Renaming `DepthGenerator` | A producer that is not a selector. |
| Procedural assembly | Unchanged: fenced until the composition seam is defined **and** a floor family gives it a vocabulary to assemble from. |
| "Good floor = Floor 2-shaped" | **Never encode.** Floor 2 taught patterns, not a template. |

---

## Veto / ruling surface

1. **R1** — Do strata remain the sequence container for M2, or does "stratum" narrow to *family* and a mission become the sequence?
2. **R2** — Is the M2 "safe rest floor" the Safe Commons, or a distinct lesser thing?
3. **R3** — Is Arcade in scope soon enough that the seam must anticipate sequence splicing, or is it M5 as P6 records?
4. **R4** — Split `depth` into *position in sequence* and *absolute depth band*, or leave overloaded until Arcade forces it?
5. **R5** — Is a minimal run object M2 gate work (the gate demands a run-end screen) or deferred macro work?
6. **The recommendation itself** — I am proposing **less than the brief invites**: migrate layouts to data now, and defer `FloorSequence` / `FloorFamily` / `role` on rule-of-two grounds. Overrule if you would rather have the sequence object standing before the second sequence exists.
7. **The 141 constant references** — accept a `named_ids` map on the layout resource, or accept rewriting those tests against raw ids?
