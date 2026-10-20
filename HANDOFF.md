# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS (NOT complete).** Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Shipped run (`arena.gd` itinerary `[1, 2, 3, 4]`): Floor 1 -> Floor 2 (308x150, Arena waves) -> Depth 3 Terminal
(recovery plate) -> **Depth 4, the first Foundry floor** -> Expedition Complete. Floors are content: `AuthoredLayout`
(.tres) -> `LayoutCompiler` -> `FloorPlan`; `DepthGenerator` picks the floor by DEPTH and the layout names its
stratum. Four goldens (depths 1-4), dated log in `tools/record_floor_plan_golden.gd`.

## EXPEDITION SLICE 1 — SHIPPED `df302bb`, HUMAN PASS 2026-10-19/20 (gameplay + presentation)
- **Descent authority:** `game/sim/expedition.gd` phase machine (exploring -> descending -> complete) owns a
  45-tick ride (`arena.descent_ticks`, PROVISIONAL). During it the SimWorld is NOT ticked and Commands are dropped.
  FAILURE WINS ordering kept. Final floor: immediate completion (no ride).
- **Cached plan = the promise:** `arena._next_plan` is generated at floor install; the console preview reads it and
  the descent installs THAT object (`assert_same` tested). Never regenerate it elsewhere.
- **Exit pad = progression** (4 emissive corner posts; old gold pillar + overhead text REMOVED).
- **Exit console = optional info**, authored per layout (`exit_console` in AuthoredLayout -> FloorPlan; non-solid,
  off every trigger, beside the pad). Read with the PRIMARY ATTACK via `SimWorld._resolve_interaction_target`:
  enemy targeted -> attack · carrying -> insert/drop · loose key focused -> lift · console focused -> inspect ·
  else attack. Inspect clears attack input (no swing/charge/fire from that press) and emits ONE Event
  `exit_console_inspected`; the panel's open state is presentation-only. E stays unbound.
  Dismiss: attack again · Esc (`ui_cancel`) · walk out of reach (`exit_console_within_reach`, cone ignored).
  Final floor's console says "Extraction / Emergency Recall".
- **Transmission:** `game/arena/transmission_field.gd` (column + rings + glow shell). Envoy hidden past
  `vanish_progress` (never scaled), screen fades (`game/ui/descent_overlay.gd`), plan installs, Envoy reappears at
  the entry with a fading shell. Visuals reset on arrival, restart, new expedition, reload and final completion.
- Panel: `game/ui/exit_console_panel.gd`. Tests: `test_exit_console.gd` (13, bare sim), `test_expedition_flow.gd`,
  `test_expedition.gd`. 11/11 mutants caught (descent timing/plan identity/press consumption/panel/visibility).
- Known flags (accepted): panel does not pause combat; floor is still built synchronously under the black screen
  (-> ROADMAP **P45**, planned, not built); no FloorPlan validator for console placement (arena test covers ships).

## Floor 4 + P44 — ALL HUMAN PASS
- **Floor 4 gameplay + spatial design: HUMAN PASS (2026-10-18).** Layout `foundry_assembly.tres`; tests
  `test_floor4.gd`, `test_carriables.gd`, P41 contracts in `test_presentation_contracts.gd`.
- Physical keys, one button; focus = aim (reach 2.0, 60-deg cone, walkable line, underfoot 0.45 never focused).
- North corridor: four 5-unit pads, groups {0,2}/{1,3}, safe 130 / active 30 (P41 warning, presentation only).
- **P44:** ONE shared `EnvoyStats.iframe_ticks_on_hit = 90`, accepted baseline, NOT a lock. Retune only as a
  different SHARED value, on evidence. The two AI-baseline helpers keep i-frames 0 ON PURPOSE.
- **DEFERRED (not required):** west-wing spike section · optional discovery Stage 4. P43 far Fang: KEEP as ruled.
- **Preserved as planned work, not started:** P39 Foundry presentation + loot-room payoff · P40 elevation.

## Next action — Expedition Slice 2: Emergency Recall + run-end flow. **Plan first, no code.**
Run /kickoff-style planning: prose walkthrough + files, then WAIT for approval. Scope candidates to propose:
the final-floor exit (and/or a recall input) leads into an extraction sequence reusing the transmission field;
a run-end screen framed as Emergency Recall (WORLD-CANON), covering both extraction and death; restart into a
fresh expedition. Questions to raise: does death share the Recall framing; where restart lands (straight into
Floor 1 vs a title — title/run-start is the slice AFTER this); what the run-end screen reports (depth, time?)
without inventing a reward layer. Floor transitions stay a driver call, not an Event (M3 flag).
**Not authorized:** loot screen, continue/extract choice UI, party boarding, rewards, multiplayer sync, generic
UI framework, title screen, west hazards, new hazard/enemy families, generator work, art pass, canon edits.

## Accepted partials / flags
- **M3 (P42):** the attack Command's `aim` LENGTH is behavioural. Authoritative input must carry the full vector.
- **M3:** descent readiness (P45) must never let a client stall authoritative state; server decides floor change.
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
- **Still out (M2 gate):** 3-5 floors per stratum (Archive 2, Foundry 1) · >=8 segments / procedural question
  (authored vs procedural vs hybrid design review still owed; any change via GAME-RULES §7) · stratum-driven
  pools/weights · depth-scaled defence · typed_damage_ramp · minimap · title + Emergency Recall run-end ·
  netcode spike · friend playtest · playtest gate · itch build. (Elevator auto-descend + next-floor preview:
  delivered by Slice 1, pending the full gate.) **ROADMAP prune DUE at M2 close** (Index lacks a P37 row).
  Carried from M1: three §3 rules want a human edit · P14 · P16 · 5.10.

## Traps this repo has actually sprung
- **GUT ignores `-gtest=<path>` and runs the WHOLE suite.** Use `-gselect=test_floor4`; check the reported count.
- **A local itinerary change breaks the suite.** Run the suite with `[1, 2, 3, 4]`; it must be that at commit.
- **Bound every predicate-wait loop in a test** (BRAIN) — an unbounded `while` hung a mutation run ~2.5 h.
- **New `class_name` -> `--headless --import`** or scripts fail with "Could not find type".
- **Material floats are float32** — track a bool for presentation state, never compare read-back energies.
- **Measure the shared knob before splitting it by source** (BRAIN) — the 15+90 P44 split was built and rejected.
- **Position a cross-source test OFF the pad** — at long windows the pad re-activates and lands first.
- **Walk-to helpers stop short** — use `_beside(key_at)` in test_floor4.
- **Bash heredocs choke on large inline Python** — write to the scratchpad and run `python -I <file>`.
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.contains` is INCLUSIVE.**
- **Drive the SHIPPED weapon the shipped way** (pressed/released), and **verify BOTH anchors of a splice**.
- **Presentation is test-exempt, so it is the blind spot** — `test_presentation_contracts.gd`.
- **Never re-record `ai_baseline_pre_p29.json` or the P17 Fang baseline.** A `-s` tool compiles before autoloads.
- **Never round-trip source through PowerShell Get-Content/Set-Content** (UTF-8 corruption).
- A Bash `cd` into a subfolder breaks the `scripts/guard.py` pre-edit hook (relative path) — cd back to root.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd` (1059, ~2 min)
- One file: add `-gselect=test_floor4`. Headless sim CI: `-gselect=test_sim_world
  -gunit_test_name=test_ticks_1000_times_headless`. New `class_name`? `--headless --import` first.
- Boot check: `--headless --path . --quit-after 300`. Guard: `python -I scripts/guard.py --scan` (RESULT line).
- Goldens: `-s tools/record_floor_plan_golden.gd` (deliberate re-baseline only, dated note; `git diff tests/fixtures`).
- Mutation check: scratchpad script backs up, mutates one anchor, runs `-gselect`, restores + byte-compares;
  give each run a `timeout`.

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
not the resolved tick · integrated pulse phase anchored at activation · post-hit invulnerability (i-frames) as one
shared window · parameter sweep before a rule split · **phase machine owning a frozen-sim transition** ·
**cached plan as a promise (identity, not equality)** · **contextual press arbitration** · **bounded test loops**.
