# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** First M2 gate work has landed.

**M2 FLOOR GRAMMAR: PASS (Breon, 2026-08-29)** against the frozen criterion — the abstraction
is VALIDATED; linearity is acceptable for this prototype. Interaction rulings BUILT; two recons
RETURNED. Awaiting the re-play. Suite **608/608**. Boots clean.
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

## Next action — RE-PLAY, then decide P34
Press play. **WASD** to move, mouse to attack, **R** to restart. **There is no E any more** —
every control is something you STAND ON.
Route: walk in → west arm → break the crate → **step on the plate it hid** → follow the opened
route → **stand on the orange party plate** → fight → the clear opens the whole way out → ramp
→ high ground (open ledges, no walls) → **stand on the exit plate** → FLOOR COMPLETE.

Then: **P34 projectile-vs-world design is written and awaiting your review** (ROADMAP). No code
was written for it. Note while playing that shots currently pass through walls — on this floor
the crate can be destroyed from across the void.

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
- **SEED HONESTY.** `generate(seed, depth)` keeps its signature but resolves an AUTHORED
  layout: seeds do NOT vary geometry, the plan carries `authored_layout = true`, the HUD says
  "authored layout", and a test asserts two seeds give identical geometry. When procedural
  assembly returns, that notice must come off with it.
- **NO `interact` VERB EXISTS.** Retired with its last consumer (switch/InteractablePlan/
  TRIGGER_INTERACTED/E binding) — rule of two run backwards. It returns out of git when a
  deliberate press is earned, not before.
- **AMBIENT TERRITORIES MUST BE CONVEX** (union == its own bounding box). Straight-line AI has
  no obstacle routing; a territory wrapping a void makes pursuit scrape the corner (measured:
  80/80 contact ticks lost for 0.9u). Guarded by test, and the guard was proved to fail.
- **ALL_ACTIVE_ENVOYS_OCCUPY_REGION** is ONE condition with TWO consumers (party plate, floor
  exit). Never grow a second copy of the occupancy math.
- **BODY-AWARE LEGALITY (2026-08-29).** `fits(point, radius)` tests the body against the
  walkable UNION. NEVER reimplement it as a per-rect shrink — a body in a doorway fits neither
  rect alone, and two tests in `test_body_bounds.gd` exist to catch exactly that.
- **Occupancy != legality.** Triggers use the anchor + `WalkableBounds.contains` (INCLUSIVE);
  bounds use `fits`. Never merge them.
- **Aperture overlap MUST stay > 0.** Abutting rects share zero area, turning every threshold
  into a discontinuity and re-opening the gate/snap problem the overlap solves.
- **`ArchivePrototypeLayout` is data-as-code**; migrates to a resource at the SECOND floor.
- **THROWABLE DEFERRED** as one unit with its puzzle. Design law banked: *if progression
  requires a capability, the floor must guarantee access to that capability.*
- **Breakables are NOT combatants** and must never become them (`test_breakable_props.gd`).
  Projectiles TERMINATE on props; penetration would have to be authored deliberately.
- **PROJECTILE-VS-WORLD: P34 design RETURNED, awaiting review.** Shots still pass through
  walls today; on this floor the crate is reachable from across the void. No code written.
- **P20 body-blocking still open** (actor-vs-actor overlap).
- **Still out:** procedural assembly · branching topology · minimap · elevator · drop economy ·
  treasure/shop/puzzle taxonomy · vertical combat · polish. **ROADMAP prune DUE at M2 close.**
- Carried from M1: three §3 rules want a human edit · **P14** title · P16 BUMP pass-through
  (P20) · 5.10 chain-flinch feel.

## Traps this repo has actually sprung (read before touching these areas)
- **A remembered audit list goes stale.** P17's position-write list (move/lunge/bump/burrow)
  was missing BOTH knockback paths and `add_entity`. **Re-run the `entities[]` audit before
  adding any displacement mechanic** — `grep -n "entities\[" game/sim/sim_world.gd`. That
  audit is why the multi-room seal was a one-function change: all 8 sites already funnel
  through `_legal_bounds_for`.
- **A test that stops measuring at the first hit can lie**, and so can a flat zero: the Ooze
  recon's first trace looked like a stuck enemy and was an IDLE one, out of detection range.
  Use a FIXED window and confirm the mechanism fired before believing a zero.
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
