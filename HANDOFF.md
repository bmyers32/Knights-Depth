# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Shipped run (`arena.gd` itinerary `[1, 2, 3, 4]`): Floor 1 -> Floor 2 (308x150, Arena waves) -> Depth 3 Terminal
(recovery plate) -> **Depth 4, the first Foundry floor** -> Expedition Complete. Floors are content: `AuthoredLayout`
(.tres) -> `LayoutCompiler` -> `FloorPlan`; `DepthGenerator` picks the floor by DEPTH and the layout names its
stratum. Four goldens (depths 1-4), dated log in `tools/record_floor_plan_golden.gd`.

## FOUNDRY FLOOR 4 — STAGE 2 (`d5840e9`) + P41 (`315ed5a`) + EAST DOORWAY FIX (`834940d`). **ALL HUMAN PASS.**
Layout `game/content/layouts/foundry_assembly.tres`; tests `tests/test_floor4.gd` (48), `tests/test_carriables.gd`
(39), P41 contracts in `tests/test_presentation_contracts.gd`.
- **Physical keys, one button.** Primary attack press resolves at most ONE action in
  `SimWorld._resolve_interaction_target` (pure; `interaction_focus()` is the same call): carrying + in an unfilled
  receiver -> insert · carrying elsewhere -> drop · empty-handed + key focused -> lift · else attack.
- **Focus = aim direction:** key within `pickup_reach` 2.0, 60-deg half-angle cone, walkable line; enemy under the
  cursor wins; a key within `pickup_underfoot_radius` 0.45 is never focused. Values in `envoy_stats.gd`.
- **Carrying:** no attack/block/bump; weapon switch allowed; full speed. A damaging hit drops the key at the
  pre-knockback position; death releases it. Gates in series (`R_GATE_1` hub, `R_GATE_2` vestibule); either key fits
  either receiver; no gate can strand a key.
- **West:** `K_WEST` at the top band's east end; its first lift wakes `E_WEST_RETURN` on the way back.
- **East:** Watchers at (53,-50)/(50,-46), inside leash of doorway + bay. `T_EAST` is now `Rect2(40,-52,6,20)`, the
  room's whole west column — the old doorway-width rect let a wall-hugger reach the key with the room asleep.
  Left/centre/right lanes test-proven. Far Fang (56,-40) sits out a north-wall entry (ROADMAP **P43**, accepted).
- **P41 spike-pad warning (presentation only).** `FloorBuilder.hazard_warning_look(ticks)` -> inactive / early /
  urgent / active / unknown; lead 50, primed height for the last 15, pulse 40-tick period easing to 11 over ticks
  50..30 then held 30, peak on activation. `Arena._project_hazards()` paints after every `_step` and at floor load
  from `sim.spike_pad_ticks_until_active` = state(N+1), exactly the tick damage resolves under. The
  `hazard_phase_changed` event no longer paints. Unknown pad -> `push_error`. All constants in floor_builder.gd.
- **North corridor:** four contiguous 5-unit pads x 18/23/28/33, groups {0,2}/{1,3}, safe 130 / active 30 /
  offsets 130/50/130/50: the pad ahead retracts as the pad underfoot starts warning. Envoy 0 hit i-frames -> a pad
  deals 10 per active tick (ROADMAP **P44**, not ruled).
- Loot room = 3 placeholder breakables that drop NOTHING (P39). `reveal_carriable` / `starts_hidden` unused, kept.

## Next action — the deferred optional west-wing spike section. **Propose first, then build.**
P41 unblocked it; it still needs human approval of a proposal before any code. Reuse P41's timing principle and
the stepping-stone relation (pad k+1 retracts when pad k starts warning: stagger = warning + active ticks).
After that: Stage 4 (optional discovery, only with a real payoff) · Stage 5 full-floor verdict, then art (P39).
Rulings waiting (no code until ruled): P44 hazard damage per tick · P43 far Fang (accepted as is).
Not authorized: turrets, throwing, spawners, new enemy families, reward infrastructure, authoritative height,
new hazard families, canon edits, Foundry art pass.

## Accepted partials / flags
- **M3 (P42):** the attack Command's `aim` LENGTH is now behavioural (aim point decides enemy-vs-key). Authoritative
  input/replay must carry the full vector, never a normalized direction.
- **Elevation (P40):** Floor 4's elevation is near-cosmetic by human observation; future floors name tier A/B/C
  before designing height. Sim stays planar; no speculative height system. P39 holds the apparent-depth list.
- Itinerary is an `@export` default on Arena; `_TERMINAL_DEPTH = 3` / `_FOUNDRY_DEPTH = 4` in `depth_generator.gd`.
  Do NOT build a layout table/framework (ruled 2026-10-12).
- Terminal room is bland greybox (debt). M3 flag: a floor change is a driver call, not an Event.
- GAME-RULES §6.3 (Foundry's "one world rule") remains an OPEN M2 question.
- Two untracked files at repo root (`KNIGHTS-DEPTH-EXPLORATION-*`) are the human's; NEVER commit them.

## Open items / live fences
- **NUMERIC FENCE (M1).** `close_frustration_ticks = 90` · Survey package · `engagement_delay_ticks = 10` · wand
  `flinch_capability = none` · all M1 HP/flinch values · `vulnerable_start_tick` FROZEN.
- **LEASH RULE (2026-09-08) is law:** activation engages; the ordinary spawn-anchored leash may still end it. Fix
  silent rosters by PLACEMENT inside the envelope (BRAIN), never by an "active rooms never disengage" exception.
- **SEED HONESTY.** Seeds do NOT vary authored geometry; the plan says `authored_layout`, the HUD prints it.
- **Enemies are immune to environmental hazards.** Sim state only via Commands. Tunables in content.
- **Closable connections need DISJOINT patches; an aperture must overlap both.** Pursuit routes through named
  apertures. Ledge vs wall on one span = error. **Free-standing masses <= 3x3** (an Ooze pins on 4).
- **AMBIENT TERRITORIES CONVEX** · `fits(point, radius)` against the UNION · triggers use INCLUSIVE `contains`.
- **If progression requires a capability, the floor must guarantee access to it.**
- **Still out (M2 gate):** rest-floor gate · elevator + next-floor preview · stratum-driven pools/weights ·
  depth-scaled defence · typed_damage_ramp · minimap · netcode spike · friend playtest · playtest gate · itch
  build. **ROADMAP prune DUE at M2 close** (Index lacks a P37 row). Carried from M1: three §3 rules want a human
  edit · P14 · P16 · 5.10.

## Traps this repo has actually sprung
- **GUT ignores `-gtest=<path>` and runs the WHOLE suite.** Use `-gselect=test_floor4`; check the reported count.
- **A local itinerary change breaks the suite.** The human sets `[4]` to play Floor 4 directly; ~11 expedition
  tests fail under it. Run the suite with `[1, 2, 3, 4]`; it must be `[1,2,3,4]` at commit (re-check right before).
- **Walk-to helpers stop short.** A lift test standing 0.3 short can land outside reach, or ON a dropped key
  (underfoot = never focused): use `_beside(key_at)` in test_floor4.
- **Bash heredocs choke on large inline Python** — write the script to the scratchpad and run `python -I <file>`.
- **A flag test is not an engagement test** — assert acquisition/attacks on the walked route (BRAIN).
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.contains` is INCLUSIVE.**
- **Drive the SHIPPED weapon the shipped way** (pressed/released), and **verify BOTH anchors of a splice**.
- **Presentation is test-exempt, so it is the blind spot** — `test_presentation_contracts.gd`.
- **Never re-record `ai_baseline_pre_p29.json` or the P17 Fang baseline.** A `-s` tool compiles before autoloads.
- **Never round-trip source through PowerShell Get-Content/Set-Content** (UTF-8 corruption).
- A Bash `cd` into a subfolder breaks the `scripts/guard.py` pre-edit hook (relative path) — cd back to root.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd` (997, ~90 s)
- One file: add `-gselect=test_floor4`. Headless sim CI: `-gselect=test_sim_world
  -gunit_test_name=test_ticks_1000_times_headless`. New `class_name`? `--headless --import` first.
- Boot check: `--headless --quit-after 120`. Guard: `python scripts/guard.py --scan` (quote counts + RESULT).
- Goldens: `-s tools/record_floor_plan_golden.gd` (all 4 depths; deliberate re-baseline only, dated note, then
  `git diff tests/fixtures` must show only the intended depth).
- Mutation check pattern: scratchpad `mutate.py` (disable one guard, run its suite, restore, `cmp` the file).

## Concepts introduced (learning ledger)
Sim tick vs frame · Command/Event plain-data boundary · service-locator autoload · seeded RNG streams · fixed
combat pipeline order · typed GDScript arrays · half-open intervals · Minkowski-sum collision · derived-vs-stored
state · cosmetic prediction · golden-behaviour baselines · guard clauses vs world facts · GUT smoke tests · pure
function + per-call RNG · reflection-based coverage scanners · union-of-rects legality vs per-axis clamp ·
placement-refuses vs displacement-clamps · overlapping rects as connectivity · camera lerp · rect-subtraction
body fit · edge-triggered occupancy · retiring vocabulary at zero consumers · Resource vs RefCounted · authored
data vs compiled identity · layer-scoped key resolution · complement invariants · mutation-based coverage ·
git index vs working tree · fail-closed vs fail-open · `core.hooksPath` · run state vs floor state ·
resolve-after-batch · phase order inside a tick · standing rule vs one-shot effect · presentation-only
elevation over a planar sim · apertures as the pursuit graph · content follows the layout, not the depth
table · schema rebaseline as a shown diff · aim cone as soft lock-on · one query for press and indicator
· mutation-proved guards · placement inside the leash envelope · **triggers as cuts, not doorways** · **paint state(N+1), not the
resolved tick** · **integrated pulse phase anchored at activation**.
