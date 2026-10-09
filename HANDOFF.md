# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.**

**FLOOR 2 SPATIAL / TOPOLOGY GATE: PASS (Breon, 2026-09-09).**
> "Overall I like the floor... I am satisfied with the progress and what was generated with
> respect to the floor plan... I think we are done iterating this floor right now."

**SCOPE: spatial composition only** — topology, rooms, connectors. NOT content density, reward
economy, hazard roster, enemy tuning, art, or procedural rules. Cleanup is allowed WITHOUT
reopening the gate; only a regression proving the spatial plan invalid reopens it.
Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Floor 2 is a **308 x 150 production-scale floor**, far wider than deep, in four independent
layers. Court --north hall--> T --west--> spike hall (pads + 2 Watchers) --> optional west loop;
--east--> long hall, one bend --> Works --> **Arena** --> Reward Hall + exit. The Arena holds a
centred party plate, a symmetrical four-arm spike cross, and **three true waves** chained by
ordinary `encounter_cleared` triggers — no wave manager was needed or built. Full shape and the
reasoning behind every coordinate: FLOOR-AUTHORING-NOTES.md.

## P36 SLICE A — DONE (2026-10-09). Floors are CONTENT.
`AuthoredLayout` (.tres) -> `LayoutCompiler` -> the same `FloorPlan`. The coordinate-bearing
builders are **deleted** (reasoning preserved in FLOOR-AUTHORING-NOTES.md), so there is ONE
authoritative representation. Records carry semantic `key`s — `target_key = &"C_VAULT"` rather
than `target_id = 3` — and the compiler resolves them **within the referenced layer**, rejecting
duplicates, dangling and wrong-layer references. `generate(seed, depth)` unchanged.
**Deferred by rule of two:** FloorSequence/FloorFamily/role, one consumer each. **Arcade/Gate
direction is ROADMAP P6/P37 and is NOT BUILT.**

## Next action — in this order
1. **Repair the canonical snapshot.** `to_dict()` omits `obstacles`, `spike_pads`,
   `hit_switches`, `breakable.blocking_rect` and `connection.flank_style` — three whole layers
   the golden gate does not protect. Expand coverage and re-record DELIBERATELY, because the
   serialization widened, never because a floor changed.
2. **Repair the vocabulary/IP guard.** It is a PreToolUse hook: run bare it scans nothing and
   exits 0, and most edits here arrive via Bash so it rarely fires at all. It also substring-
   matches, so `navi` trips on `NavigationServer` and `navigation`. Give /gate a real repository
   scan, kill the false positives, and prove genuinely banned content is rejected.
3. **The smallest playable M2 multi-floor expedition** — that consumer decides the minimal run
   state and whether `depth` must finally split.

## The macro composition seam
How authored layouts, families, missions, boss sequences and depth composition fit together
**without prematurely building a generic generator**. Procedural generation stays fenced until
that seam is named. Audit: P36-MACRO-COMPOSITION-AUDIT.md.

## Closed baselines from the Floor 2 arc — do not reopen without new evidence
Weapon-agnostic controls · props one-hit · enemies immune to spike pads · shield absorbs
environmental spike damage · 150-tick spike window (measured 99) · activation engages a roster
immediately, ordinary disengage/reacquire resumes after · true encounter-clear wave chaining ·
**self-Burn return-to-owner fix + persistent status provenance** · `_reject_props_off_floor` ·
connector flank-style **complement** regression · ledger visible on HUD · projectile elevation.

## Open items / live fences
- **NUMERIC FENCE (M1, unchanged).** `close_frustration_ticks = 90` · Survey package ·
  `engagement_delay_ticks = 10` · wand `flinch_capability = none` · all M1 HP/flinch values ·
  `vulnerable_start_tick` explicitly FROZEN.
- **SEED HONESTY.** `generate(seed, depth)` resolves an AUTHORED layout: seeds do NOT vary
  geometry; the plan says `authored_layout`, the HUD prints it, a test pins it.
- **NO `interact` VERB EXISTS** — *no active consumer uses it*, NOT that interaction is rejected.
  Gear stations, elevators and rest-floor controls may need it: restore only the narrow surface a
  concrete consumer requires, never the schema wholesale.
- **AMBIENT TERRITORIES MUST BE CONVEX** (union == bounding box). Straight-line AI has no
  obstacle routing; wrapping a void makes pursuit scrape. Guarded by a test proved to fail.
- **ALL_ACTIVE_ENVOYS_OCCUPY_REGION** is ONE condition with TWO consumers (party plate, floor
  exit). Never grow a second copy of the occupancy math.
- **BODY-AWARE LEGALITY.** `fits(point, radius)` tests the body against the walkable UNION.
  Never reimplement as a per-rect shrink — a body in a doorway fits neither rect alone.
- **Occupancy != legality.** Triggers use the anchor + `WalkableBounds.contains` (INCLUSIVE);
  bounds use `fits`. Never merge them.
- **Aperture overlap MUST stay > 0.** Abutting rects share zero area — every threshold becomes
  a discontinuity and the gate/snap problem returns.
- **THROWABLE DEFERRED.** Law banked: *if progression requires a capability, the floor must
  guarantee access to it.*
- **Breakables are NOT combatants** (`test_breakable_props.gd`). Projectiles TERMINATE on props.
- **P34 PROJECTILE-VS-WORLD: design returned, awaiting review.** Shots still pass through walls.
- **Still out:** procedural assembly · minimap · elevator · drop economy · treasure/shop
  taxonomy · vertical combat · **P20 body-blocking**. **ROADMAP prune DUE at M2 close.**
- Carried from M1: three §3 rules want a human edit · **P14** title · P16 BUMP (P20) · 5.10.

## Traps this repo has actually sprung (read before touching these areas)
- **A remembered audit list goes stale.** P17's position-write list (move/lunge/bump/burrow)
  was missing BOTH knockback paths and `add_entity`. **Re-run the `entities[]` audit before
  adding any displacement mechanic** — `grep -n "entities\[" game/sim/sim_world.gd`. That
  audit is why the multi-room seal was a one-function change: all 8 sites already funnel
  through `_legal_bounds_for`.
- **A test that stops measuring at the first hit can lie**, and so can a flat zero: the Ooze
  recon's first trace looked like a stuck enemy and was an IDLE one, out of detection range.
  Use a FIXED window and confirm the mechanism fired before believing a zero.
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.contains`/`is_inside` are
  INCLUSIVE.** A clamped actor rests ON the boundary, so `has_point` calls it escaped.
- **Integration tests must drive the SHIPPED weapon the shipped way.** A phase-less "attack"
  is not a swing for a combo weapon — the crate test did nothing until it sent pressed/released.
- **A splice needs BOTH anchors verified.** An end anchor 2500 lines too far once deleted
  `tick()` and the whole combat pipeline. Check the end anchor's line number before splicing.
- **Presentation is test-exempt, so it is the blind spot.** `test_presentation_contracts.gd`
  pins method surfaces and drives real verbs through the real arena; rosters are found via
  `_enemy_of_family(arena, family)` on a searched seed, never a hardcoded one.
- **Never re-record `ai_baseline_pre_p29.json`** (M1 gate) or the P17 Fang baseline to green a
  test. **A scanner never proven to fail is not a scanner** — STATE_SCOPES and the ambient
  convexity guard were both verified by injecting a real violation and watching them go red.
- Run diagnostics **without** suppressing stderr. A `-s` tool script compiles **before**
  autoloads register — `load()` anything touching ContentDB, never by `class_name`.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd`
- New `class_name`? `--headless --import` first. Boot check: `--headless --quit-after 120`.
- Tools: `record_floor_plan_golden.gd` (re-baseline — deliberate only) ·
  `diagnose_ooze_pursuit.gd` · `record_family_locomotion.gd` ·
  `diagnose_projectile_geometry.gd` · `measure_survey_cadence.gd`

## Concepts introduced (learning ledger)
Sim tick vs frame · Command/Event plain-data boundary · service-locator autoload · seeded RNG
streams · fixed combat pipeline order · typed GDScript arrays · half-open intervals ·
Minkowski-sum collision · derived-vs-stored state · cosmetic prediction · golden-behaviour
baselines · guard clauses vs world facts · GUT smoke tests · pure function + per-call RNG ·
reflection-based coverage scanners · union-of-rects legality vs per-axis clamp (wall slide) ·
placement-refuses vs displacement-clamps · overlapping rects as connectivity · per-actor
legality regions at one seam · camera lerp · **rect-subtraction body fit (union, not per-rect)**
· **edge-triggered occupancy conditions** · **retiring vocabulary at zero consumers**.
