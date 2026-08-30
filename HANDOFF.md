# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** First M2 gate work has landed.

**M2 FLOOR GRAMMAR: PASS (Breon), CONFIRMED ON REPLAY 2026-08-29.** Hidden plate, party plate,
exit and open ledges all pass; no-E grammar reads as natural. **Two foundations remain before
the grammar scales: P33 obstacle navigation (recon returned, awaiting option choice) and P34
projectile-vs-world (direction approved, questions open).** Boots clean.
Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
A floor is now **a continuous, stateful traversal space whose available routes change in
response to player actions** — four independent layers, none parenting another:
`WalkablePatch[]` · `TraversalConnection[]` + `FloorTrigger[]` · `EncounterSite[]` ·
`InteractablePlan[]` + `BreakablePlan[]`. **Encounter region != physical room.**

One hand-authored floor implements the whole grammar:
START → one-way commitment → hall wrapping a **void** → route **visible but blocked** →
branch (west solves, east is inhabited) → **break the crate** → reveals a switch → opens the
route → **PARTY BUTTON** (rear seals + forward opens + roster arrives + fight begins, one
atomic record) → clear → ramp → raised ground → switch → endpoint.

## Next action — CHOOSE P33's OPTION, then close P34's questions
**P33 recon is returned with a costed recommendation (ROADMAP): option B, narrow committed
sidestep, on a detector already validated 7/7 against the real failing geometry.** Measured
baseline for rejecting option A: 133 of 180 ticks lost, decaying to 0.0047 u/tick. Nothing
implemented pending your choice.

Then **P34**: direction approved, four open questions still to close before implementation.
**Procedural scaling waits on both** — bigger folded layouts would only multiply what these
leave broken.

### FROZEN CRITERION (verbatim — the verdict is rendered against this exact sentence)
> "The floor passes only if it feels like traversing and interacting with a place — seeing
> somewhere before you can reach it, finding what opens the way — rather than moving between
> generated arenas."

**FLAG:** sealed-encounter difficulty remains UNJUDGED, and independent of the grammar verdict
(30 HP Envoy dies to the roster in ~40 s; sealing removes retreat). Roster size is the first
knob. Not retuned blind — combat values are fenced and this is a human call.

## Open items / live fences
- **NUMERIC FENCE (M1, unchanged).** `close_frustration_ticks = 90` · Survey package ·
  `engagement_delay_ticks = 10` · wand `flinch_capability = none` · all M1 HP/flinch values ·
  `vulnerable_start_tick` explicitly FROZEN.
- **SEED HONESTY.** `generate(seed, depth)` resolves an AUTHORED layout: seeds do NOT vary
  geometry, the plan says `authored_layout`, the HUD prints it, a test pins it. When procedural
  assembly returns, that notice comes off with it.
- **NO `interact` VERB EXISTS** (switch/InteractablePlan/TRIGGER_INTERACTED/E binding retired).
  **AMENDED SCOPE:** this says *no active consumer uses it*, NOT that deliberate interaction is
  rejected. Gear stations, elevators and rest-floor controls may legitimately need it. Restore
  only the narrow surface a concrete consumer requires — never the schema wholesale.
- **AMBIENT TERRITORIES MUST BE CONVEX** (union == its bounding box). Straight-line AI has no
  obstacle routing; wrapping a void makes pursuit scrape (80/80 contact ticks lost for 0.9u).
  Guarded by test; the guard was proved to fail. Navigation = P33, when a floor needs it.
- **ALL_ACTIVE_ENVOYS_OCCUPY_REGION** is ONE condition with TWO consumers (party plate, floor
  exit). Never grow a second copy of the occupancy math.
- **BODY-AWARE LEGALITY (2026-08-29).** `fits(point, radius)` tests the body against the
  walkable UNION. NEVER reimplement it as a per-rect shrink — a body in a doorway fits neither
  rect alone, and two tests in `test_body_bounds.gd` exist to catch exactly that.
- **Occupancy != legality.** Triggers use the anchor + `WalkableBounds.contains` (INCLUSIVE);
  bounds use `fits`. Never merge them.
- **Aperture overlap MUST stay > 0.** Abutting rects share zero area — every threshold becomes
  a discontinuity and the gate/snap problem returns.
- **`ArchivePrototypeLayout` is data-as-code**; becomes a resource at the SECOND floor.
- **THROWABLE DEFERRED** with its puzzle. Law banked: *if progression requires a capability,
  the floor must guarantee access to it.*
- **Breakables are NOT combatants** and must never become them (`test_breakable_props.gd`).
  Projectiles TERMINATE on props; penetration would have to be authored deliberately.
- **PROJECTILE-VS-WORLD: P34 design RETURNED, awaiting review.** Shots still pass through
  walls today; on this floor the crate is reachable from across the void. No code written.
- **Still out:** procedural assembly · branching topology · minimap · elevator · drop economy ·
  treasure/shop taxonomy · vertical combat · polish · **P20 actor-vs-actor body-blocking**.
  **ROADMAP prune DUE at M2 close.**
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
