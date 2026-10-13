# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.**

**FLOOR 2 SPATIAL / TOPOLOGY GATE: PASS (Breon, 2026-09-09)** — spatial composition only, not density, tuning,
art or procedural rules. Cleanup is allowed; only a regression proving the plan invalid reopens it.
Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Floor 2 is a **308 x 150 production-scale floor** in four independent layers: Court -> T -> west spike hall /
east long hall -> Works -> **Arena** (party plate, spike cross, **three true waves** chained by ordinary
`encounter_cleared` triggers — no wave manager) -> Reward Hall + exit. Full shape: FLOOR-AUTHORING-NOTES.md.

## P36 SLICE A — DONE (2026-10-09). Floors are CONTENT.
`AuthoredLayout` (.tres) -> `LayoutCompiler` -> `FloorPlan`; semantic `key`s resolve **within the referenced
layer**. **Deferred by rule of two:** FloorSequence / FloorFamily / role. **Arcade/Gate (P6/P37) NOT BUILT**.

## REPAIRED INSTRUMENTS (2026-10-09)
- **Snapshot (`69e4905`):** `FloorPlan.to_dict()` carries every runtime field; coverage test changes ONE value at
  a time. Three goldens (depths 1–3), baselines going forward.
- **Guard (`57c9d6d`):** `--scan` for /gate (quote RESULT line + counts) · `--staged` pre-commit. Gaps: lowercase
  run-ons · per-clone hook · Pattern/Loom/Thread unenforced. Two acknowledged `knight` WARNs (envoy files).

## TWO-FLOOR EXPEDITION — DONE (`1540699`). **HUMAN PASS 2026-10-12, SCOPED** (this slice only).
`game/sim/expedition.gd` owns seed, itinerary, position, complete; `advance()` is the one rule.
- **Accepted limitation:** the itinerary is an `@export` default on Arena. Do NOT build a content framework to
  remove it; `depth` is NOT split from itinerary position — only a real consumer may force either.
- **M3 flag:** a floor change is a driver call (`sim.load_floor`), not an Event. Decide its shape in M3.

## FIRST TERMINAL — DONE (`22d6597`). **CORE: HUMAN PASS 2026-10-12. ENVIRONMENT: PARTIAL, DEFERRED.**
Shipped itinerary `[1, 2, 3]`: Floor 1 -> Floor 2 -> "Depth 3 · Terminal" (recovery plate + exit) -> Complete.
- **Recovery:** sim effect `restore_envoy_health` — living Envoys to 100%, once per visit, no revive, shield
  untouched; emits `envoys_restored`. `target_id = -1` means "no target"; a named target is refused.
- **Statuses end at floor COMPLETION** (final floor too): cleared in the completing tick, before status
  resolution; Event `status_cleared {reason: "floor_complete"}` — approved as distinct from `status_expired`.
- `place_label` on AuthoredLayout/FloorPlan; goldens re-baselined for that one key (dated log in the recorder).
- **DEBT, not accepted:** the Terminal room is bland greybox — owes atmosphere and spatial character in the
  digital-Lattice identity (never medieval/steampunk/industrial cavern). Spent plate stays lit: accepted nit.
- **Routes human-tested: NOT RECORDED** until Breon confirms; never infer from config. `[1, 3, 2]` is QA-only.
- **Accepted partials:** `_TERMINAL_DEPTH = 3` in `depth_generator.gd`; no dedicated 1000-tick script.
  **NOT BUILT** (ROADMAP "M2 TERMINAL"): Continue/Extract, tiers, shops, Companion finds, inventory.

## Next action
**Foundry design session, no code** (`/kickoff`): settle Foundry's "one world rule" (GAME-RULES §6.3) and home
the digital-reality art direction in WORLD-CANON. Then scope the first Foundry floor. Nothing is pre-authorized.

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
- **Still out (M2 gate):** Foundry stratum · rest-floor gate (NOT claimed) · elevator + next-floor preview · stratum-driven
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
- Tools: `record_floor_plan_golden.gd` (all 3 depths; deliberate re-baseline only) · `diagnose_ooze_pursuit.gd` ·
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
transitions)** · **phase order inside a tick** · **standing rule vs one-shot effect**.
