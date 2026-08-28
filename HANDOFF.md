# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** First M2 gate work has landed.

**M2 multi-room slice CLOSED (`5cff467`): mechanics PASS / grammar FALSIFIED (`d0b5f49`).
M2 FLOOR-GRAMMAR PROTOTYPE BUILT — AWAITING HUMAN PASS.** Suite **581/581**. Boots clean.
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

## Next action — THE HUMAN PASS
Press play. **WASD** to move, **E** to interact, mouse to attack, **R** to restart.
Route: walk in → west arm → break the crate → E on the switch → follow the opened route →
E on the orange button → fight → ramp → E on the last switch → the gold pillar.

### FROZEN CRITERION (verbatim — the verdict is rendered against this exact sentence)
> "The floor passes only if it feels like traversing and interacting with a place — seeing
> somewhere before you can reach it, finding what opens the way — rather than moving between
> generated arenas."

**FLAG:** sealed-encounter difficulty is still unjudged (a 30 HP Envoy dies to the roster in
~40 s of continuous engagement, and sealing removes retreat). Roster size is the first knob.
Not retuned blind — combat values are fenced and this is a human call.

## Open items / live fences
- **NUMERIC FENCE (M1, unchanged).** `close_frustration_ticks = 90` · Survey package ·
  `engagement_delay_ticks = 10` · wand `flinch_capability = none` · all M1 HP/flinch values.
  `vulnerable_start_tick` is explicitly FROZEN.
- **SEED HONESTY.** `generate(seed, depth)` keeps its signature but resolves an AUTHORED
  layout: seeds do NOT vary geometry, the plan carries `authored_layout = true`, the HUD says
  "authored layout", and a test asserts two seeds give identical geometry. When procedural
  assembly returns, that notice must come off with it.
- **Aperture overlap MUST stay > 0.** Abutting rects share zero area, turning every threshold
  into a discontinuity and re-opening the gate/snap problem the overlap solves.
- **`ArchivePrototypeLayout` is data-as-code** and migrates to a resource only when a SECOND
  authored floor exists (§1.4 rule of two).
- **THROWABLE DEFERRED**, with the mutually-exclusive switch-door puzzle, as one unit. It is a
  new gameplay capability, not floor plumbing. Design law banked: *if progression requires a
  capability, the floor must guarantee access to that capability.*
- **Breakables are NOT combatants** and must never become them — see the inheritance audit in
  ROADMAP and `tests/test_breakable_props.gd`. Projectiles TERMINATE on props (cover);
  penetration would have to be authored deliberately.
- **PROJECTILE-VS-WORLD (walls) still deferred** (ROADMAP P20). Body displacement obeys
  bounds; projectiles only stop on breakables.
- **P20 body-blocking still open.** Actor-vs-actor overlap is unsolved.
- **Still out:** procedural assembly · branching topology · minimap · elevator · drop economy ·
  treasure/shop/puzzle taxonomy · vertical combat · presentation polish.
- **ROADMAP prune DUE at M2 close** — Index over cap.
- Carried from M1: three §3 rules want a human edit · **P14** title · P16 BUMP pass-through
  (P20) · 5.10 chain-flinch feel.

## Traps this repo has actually sprung (read before touching these areas)
- **A remembered audit list goes stale.** P17's position-write list (move/lunge/bump/burrow)
  was missing BOTH knockback paths and `add_entity`. **Re-run the `entities[]` audit before
  adding any displacement mechanic** — `grep -n "entities\[" game/sim/sim_world.gd`. That
  audit is why the multi-room seal was a one-function change: all 8 sites already funnel
  through `_legal_bounds_for`.
- **A test that stops measuring at the first hit can lie.** One reported "no attacks" because
  the Envoy had already died during the walk-in, and a dead player produces no AI at all. Use
  a FIXED window; confirm the mechanism fired before believing a zero.
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.is_inside` is INCLUSIVE.**
  A clamped actor rests ON the boundary, so `has_point` reports it as escaped.
- **Integration tests must drive the SHIPPED weapon the shipped way.** A phase-less "attack"
  Command is not a swing at all for a combo weapon — the crate test silently did nothing until
  it sent pressed/released.
- **A splice needs BOTH anchors verified.** Replacing a region of sim_world.gd with an end
  anchor 2500 lines too far deleted `tick()` and the whole combat pipeline. `git checkout` +
  redo was faster than repair; check the end anchor's line number before splicing.
- **Presentation is test-exempt, so it is the blind spot.** `test_presentation_contracts.gd`
  pins method surfaces + drives real verbs through the real arena. Generated rosters are found
  via `_enemy_of_family(arena, family)` on a searched seed, never a hardcoded one.
- **Never re-record `ai_baseline_pre_p29.json`** (M1 gate) or the P17 Fang baseline to make a
  test pass. **A scanner never proven to fail is not a scanner** — STATE_SCOPES was verified by
  injecting a real unclassified var and watching it go red. Do this for the next one too.
- Run diagnostics **without** suppressing stderr; confirm the mechanism fired before trusting
  numbers. A `-s` tool script compiles **before** autoloads register — `load()` anything
  touching ContentDB dynamically, never by `class_name`.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd`
- New `class_name`? run `--headless --import` first.
- Boot check: `--headless --quit-after 120` (real main scene, prints seed + floor).
- Tools: `tools/record_floor_plan_golden.gd` (golden re-baseline — deliberate only) ·
  `tools/record_family_locomotion.gd` · `tools/diagnose_projectile_geometry.gd` ·
  `tools/measure_survey_cadence.gd`

## Concepts introduced (learning ledger)
Sim tick vs frame · Command/Event plain-data boundary · service-locator autoload · seeded
RNG streams · fixed combat pipeline order · typed GDScript arrays · half-open intervals ·
Minkowski-sum collision · derived-vs-stored state · cosmetic prediction / dead reckoning ·
golden-behaviour baselines · guard clauses vs world facts · GUT scene-instantiation smoke
tests · **pure function + per-call RNG as a purity mechanism** · **reflection-based coverage
scanners (`get_property_list`)** · **union-of-rects legality vs per-axis clamp (wall slide)**
· **placement-refuses vs displacement-clamps as distinct seams** · **overlapping rects as
connectivity (no portal/graph model)** · **per-actor legality regions (floor / owned room /
encounter seal) resolved at one seam** · **exponential frame-rate-independent camera lerp**.
