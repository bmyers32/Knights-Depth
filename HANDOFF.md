# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS (NOT complete).** Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Shipped run (`arena.gd` itinerary `[1, 2, 3, 4]`): Floor 1 -> Floor 2 (308x150, Arena waves) -> Depth 3 Terminal
(recovery plate) -> **Depth 4, the first Foundry floor** -> Expedition Complete. Floors are content: `AuthoredLayout`
(.tres) -> `LayoutCompiler` -> `FloorPlan`; `DepthGenerator` picks the floor by DEPTH and the layout names its
stratum. Four goldens (depths 1-4), dated log in `tools/record_floor_plan_golden.gd`.

## P44 — SHIPPED `a27686b`, HUMAN-ACCEPTED 2026-10-18
- ONE shared post-hit window for the Envoy: `EnvoyStats.iframe_ticks_on_hit = 90` (3 s), authored in
  `envoy_stats.tres`, read by `arena.gd` `register_combatant`. Any damaging hit (enemy, projectile, spike) starts
  it; absorbed/blocked hits never restart it. **Sim untouched** — `_resolve_hit_on_target` already gated hazards;
  the driver passed a literal 0.
- **90 is the accepted current baseline, NOT a balance lock.** Retune only on new gameplay evidence, and only as a
  different SHARED value. No per-pad timers, source-specific immunity or compensating enemy/hazard tuning.
- Measured sweep (N=0..90, crowd dmg/10 s + blind-corridor hits) lives in ROADMAP P44; 30 was the alternative.
- Tests: `tests/test_envoy_iframes.gd` (16), P44 sections in `test_floor4.gd` / `test_floor2.gd`, one-drop carry in
  `test_carriables.gd`. Mutations (driver literal 0; resource 15) both caught.
- The two AI-baseline helpers keep i-frames 0 ON PURPOSE (recordings predate P44; never re-record).

## FOUNDRY FLOOR 4 — Stage 2 (`d5840e9`) + P41 (`315ed5a`) + east doorway (`834940d`) + P44. ALL HUMAN PASS.
Layout `game/content/layouts/foundry_assembly.tres`; tests `test_floor4.gd` (52), `test_carriables.gd` (40),
P41 contracts in `test_presentation_contracts.gd`.
- **Physical keys, one button.** Primary press resolves ONE action in `SimWorld._resolve_interaction_target`:
  carrying + unfilled receiver -> insert · carrying elsewhere -> drop · empty-handed + key focused -> lift · attack.
- **Focus = aim:** reach 2.0, 60-deg cone, walkable line; enemy under cursor wins; underfoot (0.45) never focused.
- **Carrying:** no attack/block/bump; full speed. A damaging hit drops the key (once per window now); death releases.
- **West:** `K_WEST` lift wakes `E_WEST_RETURN`. **East:** `T_EAST = Rect2(40,-52,6,20)`; far Fang = P43 (accepted).
- **P41 warning** (presentation only): `FloorBuilder.hazard_warning_look`, painted from state(N+1) after each step.
- **North corridor:** four 5-unit pads x 18/23/28/33, groups {0,2}/{1,3}, safe 130 / active 30. A blind walk
  costs 1-2 hits at 90 (never 0); a timed crossing is clean.
- Loot room = 3 placeholder breakables that drop NOTHING (P39).

## Next action — the complete Floor 4 gameplay verdict (Stage 5). **Human playtest, no code.**
Play the full floor start to finish at itinerary `[1,2,3,4]` (or `[4]` locally — revert before commit): both
keys, both gates, west return ambush, east room from each lane, the north corridor, loot room, completion.
Record KEEP/CHANGE per area. Readiness guidance already accepted (2026-10-18):
- West-wing spike section: **DEFER** (stacks punishment on key carrying, no new decision; P39 sparseness ruling).
- North corridor: **KEEP**. P43 far Fang: **KEEP as ruled**. Stage 4 optional discovery: **DEFER** (no payoff infra).
**Then: M2 expedition design review (planning only).** Prepare the design comparison the human asked for:
authored floors vs procedural segments vs hybrid, against §5's "procedural depths / >=8 segments" item. Do NOT
edit GAME-RULES or silently replace the procedural requirement — any change goes through §7 deliberately.
Candidate next build slice after that ruling: "Expedition frame" (Terminal elevator auto-descend, next-floor
preview, Emergency Recall run-end + title). It needs its OWN plan and a ruling on floor-transition authority
(M3 flag: a floor change is a driver call, not an Event) before any code.
Not authorized: west hazards, new hazard families, generator work, elevator, title, art pass, canon edits,
turrets, throwing, spawners, new enemy families, reward infrastructure, authoritative height.

## Accepted partials / flags
- **M3 (P42):** the attack Command's `aim` LENGTH is behavioural. Authoritative input must carry the full vector.
- **Elevation (P40)** planned, not started: Floor 4 height is near-cosmetic; sim stays planar. **P39** Foundry
  presentation planned, not started. Preserve both as planned work.
- Itinerary is an `@export` default on Arena; `_TERMINAL_DEPTH = 3` / `_FOUNDRY_DEPTH = 4` in `depth_generator.gd`.
  Do NOT build a layout table/framework (ruled 2026-10-12).
- Terminal room is bland greybox (debt). GAME-RULES §6.3 (Foundry's "one world rule") is an OPEN M2 question.
- i-frames show nothing on screen (console print only). If that reads unfair in play -> ROADMAP, not inline.
- A held shield on an active pad drains every tick (block grants no i-frames) — existing law, not reopened.
- Two untracked files at repo root (`KNIGHTS-DEPTH-EXPLORATION-*`) are the human's; NEVER commit them.

## Open items / live fences
- **NUMERIC FENCE (M1).** `close_frustration_ticks = 90` · Survey package · `engagement_delay_ticks = 10` · wand
  `flinch_capability = none` · all M1 HP/flinch values · `vulnerable_start_tick` FROZEN. P44's 90 = accepted baseline.
- **LEASH RULE (2026-09-08) is law:** activation engages; the spawn-anchored leash may still end it. Fix silent
  rosters by PLACEMENT inside the envelope (BRAIN), never an "active rooms never disengage" exception.
- **SEED HONESTY.** Seeds do NOT vary authored geometry; the plan says `authored_layout`, the HUD prints it.
- **Enemies are immune to environmental hazards.** Sim state only via Commands. Tunables in content.
- **Closable connections need DISJOINT patches; an aperture must overlap both.** Ledge vs wall on one span = error.
  **Free-standing masses <= 3x3** (an Ooze pins on 4). **AMBIENT TERRITORIES CONVEX** · triggers INCLUSIVE.
- **If progression requires a capability, the floor must guarantee access to it.**
- **Still out (M2 gate):** 3-5 floors per stratum (Archive 2, Foundry 1) · >=8 segments / procedural question ·
  elevator + next-floor preview · stratum-driven pools/weights · depth-scaled defence · typed_damage_ramp · minimap
  · title + Emergency Recall run-end · netcode spike · friend playtest · playtest gate · itch build.
  **ROADMAP prune DUE at M2 close** (Index lacks a P37 row). Carried from M1: three §3 rules want a human edit ·
  P14 · P16 · 5.10.

## Traps this repo has actually sprung
- **GUT ignores `-gtest=<path>` and runs the WHOLE suite.** Use `-gselect=test_floor4`; check the reported count.
- **A local itinerary change breaks the suite.** Run the suite with `[1, 2, 3, 4]`; it must be that at commit.
- **Measure the shared knob before splitting it by source** (BRAIN) — the 15+90 P44 split was built and rejected.
- **Position a cross-source test OFF the pad** — at long windows the pad re-activates and lands first.
- **Walk-to helpers stop short** — use `_beside(key_at)` in test_floor4.
- **Bash heredocs choke on large inline Python** — write to the scratchpad and run `python -I <file>`.
- **A flag test is not an engagement test** — assert acquisition/attacks on the walked route (BRAIN).
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.contains` is INCLUSIVE.**
- **Drive the SHIPPED weapon the shipped way** (pressed/released), and **verify BOTH anchors of a splice**.
- **Presentation is test-exempt, so it is the blind spot** — `test_presentation_contracts.gd`.
- **Never re-record `ai_baseline_pre_p29.json` or the P17 Fang baseline.** A `-s` tool compiles before autoloads.
- **Never round-trip source through PowerShell Get-Content/Set-Content** (UTF-8 corruption).
- A Bash `cd` into a subfolder breaks the `scripts/guard.py` pre-edit hook (relative path) — cd back to root.
- GDScript: a local named `log` shadows a built-in — pick another name.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd` (1020, ~112 s)
- One file: add `-gselect=test_floor4`. Headless sim CI: `-gselect=test_sim_world
  -gunit_test_name=test_ticks_1000_times_headless`. New `class_name`? `--headless --import` first.
- Boot check: `--headless --path . --quit-after 90`. Guard: `python scripts/guard.py --scan` (RESULT line).
- Goldens: `-s tools/record_floor_plan_golden.gd` (deliberate re-baseline only, dated note; `git diff tests/fixtures`).
- Mutation check: back up to scratchpad, mutate one line, run its suite, restore, `fc /b` the file.

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
· mutation-proved guards · placement inside the leash envelope · triggers as cuts, not doorways · paint state(N+1),
not the resolved tick · integrated pulse phase anchored at activation · **post-hit invulnerability (i-frames) as one
shared window** · **parameter sweep before a rule split**.
