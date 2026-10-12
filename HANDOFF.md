# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.**

**FLOOR 2 SPATIAL / TOPOLOGY GATE: PASS (Breon, 2026-09-09).** SCOPE: spatial composition only (topology, rooms,
connectors) — NOT density, rewards, hazards, enemy tuning, art or procedural rules. Cleanup is allowed WITHOUT
reopening the gate; only a regression proving the spatial plan invalid reopens it.
Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Floor 2 is a **308 x 150 production-scale floor** in four independent layers: Court -> T -> west spike hall /
east long hall -> Works -> **Arena** (party plate, spike cross, **three true waves** chained by ordinary
`encounter_cleared` triggers — no wave manager) -> Reward Hall + exit. Full shape: FLOOR-AUTHORING-NOTES.md.

## P36 SLICE A — DONE (2026-10-09). Floors are CONTENT.
`AuthoredLayout` (.tres) -> `LayoutCompiler` -> the same `FloorPlan`; builders **deleted**; semantic `key`s resolve
**within the referenced layer** and never reach a compiled plan. **Deferred by rule of two:** FloorSequence /
FloorFamily / role. **Arcade/Gate (P6/P37) NOT BUILT**; procedural generation stays fenced (P36 audit doc).

## REPAIRED INSTRUMENTS (2026-10-09)
- **Snapshot (`69e4905`):** `FloorPlan.to_dict()` carries every runtime field; the coverage test changes ONE value
  at a time. Two goldens: depth 1 and depth 2 (a baseline going forward, NOT proof of the old Floor 2).
- **Guard (`57c9d6d`):** edit hook · `--scan` (for /gate) · `--staged` (`.githooks/pre-commit`). **/gate's IP item =
  the `--scan` RESULT line and its counts.** Gaps: lowercase run-ons · hook is per-clone, `--no-verify` skips it ·
  Pattern/Loom/Thread unenforced. Two acknowledged `knight` WARNs (envoy files).

## TWO-FLOOR EXPEDITION — DONE (`1540699`). **HUMAN PASS 2026-10-12, SCOPED.**
Boot -> Floor 1 -> instant descent + non-blocking arrival card -> Floor 2 -> Expedition Complete -> R redeploys.
`game/sim/expedition.gd` owns seed, itinerary (list of depths), position, complete; `advance()` is the one rule.
`Arena.begin_expedition()` (entry) is separate from `_load_floor()` (ROADMAP P38 constraint). Suite 847 -> 871.
- **PASS scope:** this slice only — NOT the M2 milestone, elevator presentation, multiplayer or Arcade; does NOT
  reopen Floor 1/2 spatial design. Human-observed vs test-only split is in ROADMAP "M2 TWO-FLOOR EXPEDITION".
- **Accepted limitation:** `itinerary = [1, 2]` is an `@export` default on Arena. Do NOT build a content framework
  merely to remove it; `depth` is NOT split from itinerary position — only a real consumer may force either.
- **M3 flag:** a floor change is a driver call (`sim.load_floor`), not an Event. Decide its shape in M3.
  Tests boot one floor with `arena.itinerary = [n] as Array[int]`.

## Next action
**DECIDE on the next-slice proposal** (`/kickoff`; presented 2026-10-12 — NOT approved; nothing pre-authorized:
not the terminal, not Foundry, not a run-state refactor, and no assumed depth/position split).
- **Target sequence (Breon):** `Archive Floor 1 -> Archive Floor 2 -> Safe Terminal -> Foundry`. An initial
  development sequence, NOT the full M2 floor count. The terminal belongs at the Archive/Foundry transition.
- **Proposed slice:** a minimal Safe Terminal as the third entry (`[1, 2, 3]`): a tiny authored floor, no
  encounters, exit completes it. Foundry stays out. Open questions returned to Breon: what the terminal DOES in
  v1 · what stratum/label it carries · whether a third layout turns `DepthGenerator`'s two-entry `if` into data.

## Closed baselines from the Floor 2 arc — do not reopen without new evidence
Weapon-agnostic controls · props one-hit · enemies immune to spike pads · shield absorbs environmental spike
damage · 150-tick spike window (measured 99) · activation engages a roster immediately, ordinary
disengage/reacquire resumes after · true encounter-clear wave chaining · **self-Burn return-to-owner fix +
persistent status provenance** · `_reject_props_off_floor` · connector flank-style **complement** regression ·
ledger visible on HUD · projectile elevation.

## Open items / live fences
- **NUMERIC FENCE (M1, unchanged).** `close_frustration_ticks = 90` · Survey package · `engagement_delay_ticks =
  10` · wand `flinch_capability = none` · all M1 HP/flinch values · `vulnerable_start_tick` explicitly FROZEN.
- **SEED HONESTY.** `generate(seed, depth)` resolves an AUTHORED layout: seeds do NOT vary geometry; the plan says
  `authored_layout`, the HUD prints it, a test pins it.
- **NO `interact` VERB EXISTS** — *no active consumer uses it*, NOT that interaction is rejected. Gear stations,
  elevators and rest-floor controls may need it: restore only the narrow surface a concrete consumer requires,
  never the schema wholesale.
- **AMBIENT TERRITORIES MUST BE CONVEX** (union == bounding box): straight-line AI has no obstacle routing.
  Guarded by a test proved to fail.
- **ALL_ACTIVE_ENVOYS_OCCUPY_REGION** is ONE condition with TWO consumers (party plate, floor exit). Never grow a
  second copy of the occupancy math.
- **BODY-AWARE LEGALITY.** `fits(point, radius)` tests the body against the walkable UNION. Never reimplement as a
  per-rect shrink — a body in a doorway fits neither rect alone.
- **Occupancy != legality.** Triggers use the anchor + `contains` (INCLUSIVE); bounds use `fits`.
- **Aperture overlap MUST stay > 0.** Abutting rects share zero area — every threshold becomes a discontinuity and
  the gate/snap problem returns.
- **THROWABLE DEFERRED.** Law banked: *if progression requires a capability, the floor must guarantee access to
  it.*
- **Breakables are NOT combatants** (`test_breakable_props.gd`); projectiles TERMINATE on props. P34
  projectile-vs-world LANDED 2026-08-31 — shots stop on walls and closed gates.
- **Still out (M2 gate):** Foundry stratum · rest floor · elevator + next-floor preview · stratum-driven
  pools/weights · depth-scaled defence · typed_damage_ramp · minimap · netcode spike · friend playtest · playtest
  gate · itch build. **ROADMAP prune DUE at M2 close** (its index also lacks a P37 row).
- Carried from M1: three §3 rules want a human edit · **P14** title · P16 BUMP (P20) · 5.10.

## Traps this repo has actually sprung (read before touching these areas)
- **A remembered audit list goes stale.** P17's position-write list (move/lunge/bump/burrow) was missing BOTH
  knockback paths and `add_entity`. **Re-run the `entities[]` audit before adding any displacement mechanic** —
  `grep -n "entities\[" game/sim/sim_world.gd`. That audit is why the multi-room seal was a one-function change:
  all 8 sites already funnel through `_legal_bounds_for`.
- **A test that stops measuring at the first hit can lie**, and so can a flat zero: the Ooze recon's first trace
  looked like a stuck enemy and was an IDLE one, out of detection range. Use a FIXED window and confirm the
  mechanism fired before believing a zero.
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.contains`/`is_inside` are INCLUSIVE.** A
  clamped actor rests ON the boundary, so `has_point` calls it escaped.
- **Integration tests must drive the SHIPPED weapon the shipped way.** A phase-less "attack" is not a swing for a
  combo weapon — the crate test did nothing until it sent pressed/released.
- **A splice needs BOTH anchors verified.** An end anchor 2500 lines too far once deleted `tick()` and the whole
  pipeline. Check the end anchor's line number before splicing.
- **Presentation is test-exempt, so it is the blind spot.** `test_presentation_contracts.gd` drives real verbs
  through the real arena; rosters via `_enemy_of_family`, never a fixed seed.
- **Never re-record `ai_baseline_pre_p29.json`** (M1) or the P17 Fang baseline to green a test. **A scanner never
  proven to fail is not a scanner** — STATE_SCOPES and the ambient convexity guard were both verified by injecting
  a real violation and watching them go red.
- Run diagnostics **without** suppressing stderr. A `-s` tool script compiles **before** autoloads register —
  `load()` anything touching ContentDB, never by `class_name`.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd`
- New `class_name`? `--headless --import` first. Boot check: `--headless --quit-after 120`.
- Guard: `python scripts/guard.py --scan` · tests `scripts/test_guard_{scan,amendment}.py` · new clone: `--install-hook`
- Tools: `record_floor_plan_golden.gd` (BOTH floors; deliberate re-baseline only) · `diagnose_ooze_pursuit.gd` ·
  `record_family_locomotion.gd` · `diagnose_projectile_geometry.gd` · `measure_survey_cadence.gd`

## Concepts introduced (learning ledger)
Sim tick vs frame · Command/Event plain-data boundary · service-locator autoload · seeded RNG streams · fixed
combat pipeline order · typed GDScript arrays · half-open intervals · Minkowski-sum collision ·
derived-vs-stored state · cosmetic prediction · golden-behaviour baselines · guard clauses vs world facts · GUT
smoke tests · pure function + per-call RNG · reflection-based coverage scanners · union-of-rects legality vs
per-axis clamp (wall slide) · placement-refuses vs displacement-clamps · overlapping rects as connectivity ·
per-actor legality regions at one seam · camera lerp · rect-subtraction body fit · edge-triggered occupancy ·
retiring vocabulary at zero consumers · **Resource vs RefCounted for serialisable content** · **authored data vs
compiled runtime identity** · **layer-scoped key resolution** · **complement invariants between paired
functions** · **PreToolUse hooks are not repo audits** · **mutation-based coverage (prove values, not names)** ·
**token vs substring matching** · **git index vs working tree** · **fail-closed vs fail-open** ·
**`core.hooksPath`** · **run state vs floor state** · **resolve-after-batch (deferred
transitions)**.
