# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Shipped run (`arena.gd` itinerary `[1, 2, 3, 4]`): Floor 1 -> Floor 2 (308x150, Arena waves) -> Depth 3 Terminal
(recovery plate) -> **Depth 4, the first Foundry floor** -> Expedition Complete. Floors are content: `AuthoredLayout`
(.tres) -> `LayoutCompiler` -> `FloorPlan`; `DepthGenerator` picks the floor by DEPTH and the layout names its
stratum. Four goldens (depths 1-4), dated log in `tools/record_floor_plan_golden.gd`.

## FOUNDRY FLOOR 4 — STAGE 2 DONE (`d5840e9`). **HUMAN MECHANIC PLAYTEST PASS 2026-10-16.**
Layout `game/content/layouts/foundry_assembly.tres`; tests `tests/test_floor4.gd` (42), `tests/test_carriables.gd` (39).
Stage 1 geometry (human spatial PASS 2026-10-15) is unchanged except: the west return shortcut connection was DELETED.
- **Physical keys, one button.** The primary attack press resolves at most ONE action, decided in
  `SimWorld._resolve_interaction_target` (pure; `interaction_focus()` is the same call, so the focus ring can't lie):
  carrying + in an unfilled receiver -> insert · carrying elsewhere -> drop · empty-handed + key focused -> lift ·
  else ordinary attack. No E, no `interact` Command.
- **Focus = aim direction** (playtest revision): key within `pickup_reach` 2.0, inside a 60-deg half-angle cone,
  straight path walkable; enemy under the cursor always wins; a key within `pickup_underfoot_radius` 0.45 is NEVER
  focused (step off, aim back) — this prevents drop/lift cycling. Values in `envoy_stats.gd`, felt good in play.
- **Carrying:** no attack, block or bump (lift lowers a held shield); weapon switch allowed; full speed. A damaging
  hit (damage > 0) drops the key at the pre-knockback position; blocked/i-frame/zero hits and Burn ticks do not;
  death from any cause releases it. No compensating i-frames or auto-retrieval.
- **Gates in series:** Gate 1's receiver (`R_GATE_1`) in the hub, Gate 2's (`R_GATE_2`) in the vestibule behind
  Gate 1. Either key fits either receiver; the first delivered always opens Gate 1. Only closing effect on the floor
  is the party plate, beyond both gates — no gate can strand a key (test-proven).
- **West:** key `K_WEST` waits visibly at the far east end of the top band (seen from the hub across the void). Its
  FIRST lift (`T_WEST_LIFT`, kind `carriable_lifted`, once) wakes optional `E_WEST_RETURN` (2 Fang + Ooze) on the way
  back; the only way home is the way in. The west ambush (planned as Stage 3) was BUILT AND PLAYTESTED here.
- **East:** Watchers re-placed to (53,-50)/(50,-46) — inside their 18-unit leash of the whole doorway AND the key bay
  (they used to be leashed off the tick after activation). Leash rule 2026-09-08 untouched. Human-confirmed.
- Loot room = 3 placeholder breakables that drop NOTHING (P39). `reveal_carriable` / `starts_hidden` exist but no
  floor uses them now (kept: tiny, mirrors `reveal_switch`).

## Next action — P41: timed-hazard pre-activation telegraph (human requirement). **Propose first, then build.**
Do NOT start it before the human approves the proposal. Read ROADMAP **P41** (binding constraints). Smallest shape:
FloorBuilder pad visuals read `SimWorld.spike_pad_ticks_until_active(pad_id)` each tick (`_step`, after the
sim tick) and map ticks-remaining -> warning phase: safe / warning (lead ~45-60 ticks, provisional) / active
(must equal the authoritative active state exactly). Pulse accelerates, bounded rate, contrast + pattern change,
not colour alone. Lead + pulse bounds as named presentation constants (or content). No new sim state, Event or
timer; no golden change; the 3-band connector warns per-band by its own phase. Tests in
`test_presentation_contracts.gd` (phase mapping, active-coincides-with-sim, per-band independence).
Then a human playtest of readability. **Only after that:** the deferred optional west-wing spike section.
After that: Stage 4 (optional discovery, only with a real payoff) · Stage 5 full-floor verdict, then art (P39).
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
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd` (984, ~90 s)
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
table · schema rebaseline as a shown diff · **aim cone as soft lock-on** · **one query for press and indicator**
· **mutation-proved guards** · **placement inside the leash envelope**.
