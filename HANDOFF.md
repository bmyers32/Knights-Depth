# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Shipped run (`arena.gd` itinerary `[1, 2, 3, 4]`): Floor 1 -> Floor 2 (308x150, Arena waves) -> Depth 3 Terminal
(recovery plate) -> **Depth 4, the first Foundry floor** -> Expedition Complete. Floors are content: `AuthoredLayout`
(.tres) -> `LayoutCompiler` -> `FloorPlan`; `DepthGenerator` picks the floor by DEPTH and the layout names its
stratum (`AuthoredLayout.stratum_id`, default archive). Four goldens (depths 1-4), dated log in the recorder.

## FOUNDRY FLOOR 4 — STAGE 1 DONE (`8f5cee4`). **HUMAN SPATIAL PASS 2026-10-15.**
Layout `game/content/layouts/foundry_assembly.tres`; tests `tests/test_floor4.gd` (28). Topology follows
`screenshots from human/map topology/Map reference 1.png` (gitignored, local only):
raised landing + U + 3 stairs (elev 1.5 -> 0, PRESENTATION ONLY; sim is planar) -> lower access (optional Fang
pair) -> HUB -> west loop (fight in bottom band; key at NW apex niche, revealed on clear; key opens lock W + a
return door into the hub) / east room (Watchers, key in north bay behind cover; **optional loot room** off its
east wall) -> two locks in series (W then E, vestibule between) -> write-sequence connector (the 3 pads that
passed play 2026-10-13, unchanged) -> chamber (party plate, 3 waves) -> exit run.
- Measured: west circuit 120.3 (target 115-130), east 67.7 out / 55.2 back.
- **Keys are still hit-switch stand-ins.** Either order works because the locks are two closed connections.
- **Loot room = 3 placeholder breakables that drop NOTHING.** No reward system exists (ROADMAP P39).
- **Everything with a prop/control/fight stays at elevation 0** (test-enforced): FloorBuilder draws ordinary
  breakables and obstacle wall faces at y=0 regardless of ground. Not fixed; P39.
- Known: stairs read weakly; tracers/bare-ground aim sit at the Envoy's height on raised ground (code-read, not
  captured); kited rosters rub walls on the way home (sim pursuit limit, not fixed).
- Visual sparseness was ruled a PRESENTATION debt (P39), NOT a reason for more geometry, hazards or obstacles.

## Next action — Stage 2: physical keys. **NOT AUTHORIZED until the human confirms two things:**
1. **The seven interaction defaults** (reviewer-supported, human-unconfirmed): (1) shield block allowed while
   carrying, shield bump not; (2) no drop on damage; (3) E to insert; (4) either key fits either socket;
   (5) pickup rejected during active/executing attacks; (6) weapon switch allowed; (7) no speed penalty.
   Carrying disables attacking (`attack_rejected` reason "carrying").
2. **Snapshot rebaseline:** `to_dict()` always serializes `carriables` (never conditionally omitted). Floors 1-3
   goldens each gain exactly `\t"carriables": [],` between "breakables" and "connections" (d1 before line 22,
   d2 before 549, d3 before 4). Explicit dated note. Diff already shown to the human.
Proposed shape (review before building): restore a narrow `interact` Command; `CarriablePlan{carriable_id,
position}`; reach as an Envoy content tunable; sockets are FloorTriggers with condition `carriable_inserted`
(+ `carriable_lifted` for Stage 3); events carriable_lifted/dropped/inserted, interact_rejected. Attack gate
at the top of `_apply_attack` (`sim_world.gd` ~1953) beside `combat_absent` — buffered presses, pending holds and
the shield bump are SEPARATE paths and each needs the gate. `STATE_SCOPES` + `test_floor_scope` must cover it.
**Recoverability is proven per floor by tests, NOT a global rule:** Floor 4 delivers on an open-only route.
Prove: keys start reachable; drop/recover on both routes; inserted keys cannot be lost; death/R-reload consistent;
no closed gate can strand a key. Then a human mechanic playtest.

**Stage 3 (separate, unimplemented):** west key-lift ambush (finite, existing encounter activation, no spawner;
test fairness; if no fair placement, propose the smallest arrival delay) + ONE localized west hazard. Then
playtest the carrying return. **Stage 4:** evaluate optional discovery (only with a real payoff). **Stage 5:**
full-floor verdict, then art (P39). Not authorized anywhere: turrets, throwing, chemistry, spawners, new enemy
families, reward infrastructure, authoritative height, global halo, canon edits.

## Accepted partials / flags
- Itinerary is an `@export` default on Arena; `_TERMINAL_DEPTH = 3` / `_FOUNDRY_DEPTH = 4` in `depth_generator.gd`.
  Do NOT build a layout table/framework (ruled 2026-10-12; Foundry showed none is needed).
- `SimWorld.spike_pad_ticks_until_active` is a read-only countdown; no presentation reads it yet.
- Terminal room is bland greybox (debt). M3 flag: a floor change is a driver call, not an Event.
- GAME-RULES §6.3 (Foundry's "one world rule") remains an OPEN M2 question; the Foundry is a themed stratum.
- Two untracked briefing files at repo root (`KNIGHTS-DEPTH-EXPLORATION-*`) are the human's; never commit them.

## Open items / live fences
- **NUMERIC FENCE (M1).** `close_frustration_ticks = 90` · Survey package · `engagement_delay_ticks = 10` · wand
  `flinch_capability = none` · all M1 HP/flinch values · `vulnerable_start_tick` FROZEN.
- **SEED HONESTY.** Seeds do NOT vary authored geometry; the plan says `authored_layout`, the HUD prints it.
- **`interact` was retired at zero consumers** (`envoy.gd:83-85`); E is still bound in `project.godot`. Stage 2 is
  its first real consumer: restore only the narrow surface needed.
- **Enemies are immune to environmental hazards.** Sim state only via Commands. Tunables in content.
- **Closable connections need DISJOINT patches; an aperture must overlap both.** Pursuit routes through named
  apertures — any join an enemy chases through must be a named connection. Ledge vs wall on one span = error.
- **Free-standing masses <= 3x3** (`tools/measure_block_pursuit.gd`: an Ooze pins on 4).
- **AMBIENT TERRITORIES CONVEX** · **ALL_ACTIVE_ENVOYS_OCCUPY_REGION is ONE condition, two consumers** ·
  `fits(point, radius)` against the UNION, never per-rect shrink · triggers use INCLUSIVE `contains`.
- **If progression requires a capability, the floor must guarantee access to it.**
- **Still out (M2 gate):** rest-floor gate · elevator + next-floor preview · stratum-driven pools/weights ·
  depth-scaled defence · typed_damage_ramp · minimap · netcode spike · friend playtest · playtest gate · itch
  build. **ROADMAP prune DUE at M2 close** (Index lacks a P37 row). Carried from M1: three §3 rules want a human edit · P14 · P16 · 5.10.

## Traps this repo has actually sprung
- **GUT ignores `-gtest=<path>` and runs the WHOLE suite.** Use `-gselect=test_floor4`; check the reported count.
- **A local itinerary change breaks the suite.** The human sets `[4]` to play Floor 4 directly; ~11 expedition
  tests fail under it. Run the suite with `[1, 2, 3, 4]` and restore theirs; it must be `[1,2,3,4]` at commit.
- **Re-run the `entities[]` audit before any displacement mechanic** (`grep -n "entities\[" game/sim/sim_world.gd`).
- **A flat zero can be an IDLE enemy, not a stuck one.** Fixed window; confirm the mechanism fired.
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.contains` is INCLUSIVE.**
- **Drive the SHIPPED weapon the shipped way** (pressed/released), and **verify BOTH anchors of a splice**.
- **Presentation is test-exempt, so it is the blind spot** — `test_presentation_contracts.gd`.
- **Never re-record `ai_baseline_pre_p29.json` or the P17 Fang baseline.** A scanner never proven to fail is not a
  scanner. A `-s` tool compiles before autoloads: `load()` anything touching ContentDB.
- **Never round-trip source through PowerShell Get-Content/Set-Content** (UTF-8 corruption).
- A Bash `cd` into a subfolder breaks the `scripts/guard.py` pre-edit hook (relative path) — cd back to root.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd` (930, ~60 s)
- One file: add `-gselect=test_floor4`. Headless sim CI: `-gselect=test_sim_world
  -gunit_test_name=test_ticks_1000_times_headless`. New `class_name`? `--headless --import` first.
- Boot check: `--headless --quit-after 120`. Guard: `python scripts/guard.py --scan` (quote counts + RESULT).
- Goldens: `-s tools/record_floor_plan_golden.gd` (all 4 depths; deliberate re-baseline only, dated note, then
  `git diff tests/fixtures` must show only the intended depth).

## Concepts introduced (learning ledger)
Sim tick vs frame · Command/Event plain-data boundary · service-locator autoload · seeded RNG streams · fixed
combat pipeline order · typed GDScript arrays · half-open intervals · Minkowski-sum collision · derived-vs-stored
state · cosmetic prediction · golden-behaviour baselines · guard clauses vs world facts · GUT smoke tests · pure
function + per-call RNG · reflection-based coverage scanners · union-of-rects legality vs per-axis clamp ·
placement-refuses vs displacement-clamps · overlapping rects as connectivity · camera lerp · rect-subtraction
body fit · edge-triggered occupancy · retiring vocabulary at zero consumers · Resource vs RefCounted · authored
data vs compiled identity · layer-scoped key resolution · complement invariants · mutation-based coverage ·
git index vs working tree · fail-closed vs fail-open · `core.hooksPath` · run state vs floor state ·
resolve-after-batch · phase order inside a tick · standing rule vs one-shot effect · **presentation-only
elevation over a planar sim** · **apertures as the pursuit graph** · **content follows the layout, not the depth
table** · **schema rebaseline as a shown diff**.
