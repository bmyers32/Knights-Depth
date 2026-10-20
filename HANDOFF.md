# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS (NOT complete).** Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Shipped run (`arena.gd` itinerary `[1, 2, 3, 4]`): Floor 1 -> Floor 2 (308x150, Arena waves) -> Depth 3 Terminal
(recovery plate) -> **Depth 4, the first Foundry floor** -> Extraction. Floors are content: `AuthoredLayout`
(.tres) -> `LayoutCompiler` -> `FloorPlan`; `DepthGenerator` picks the floor by DEPTH and the layout names its
stratum. Four goldens (depths 1-4), dated log in `tools/record_floor_plan_golden.gd`.

## EXPEDITION SLICE 2 — SHIPPED `0cd4d7c`, HUMAN gameplay + visual PASS 2026-10-20
- **Recovery law** (GAME-RULES §3 Recovery + §7 row, applied 2026-10-20 via the guard's amendment seam):
  one free **Emergency Resynchronization** per Envoy per combat floor. Automatic, in place, **100% max HP**
  (human decision, do not lower without playtest evidence), plus the shared 90-tick post-hit window.
  Delay `EnvoyStats.resync_delay_ticks = 45` (HUMAN: feels good). Second fall on a floor -> **Emergency Recall**
  (failure). Final exit -> **Extraction** (success). Distinct wording on one shared summary.
- **Sim (`sim_world.gd`):** incapacitated == `_health <= 0` (no downed state machine; overkill is NOT
  clamped -- assert `<= 0`). `_on_incapacitated` at the hit-death and Burn-death sites: clears status
  (`status_cleared` reason `incapacitated`), commits the charge (`resync_begun`) or reports the PARTY fact
  `recovery_exhausted` (`_party_can_recover`). `_advance_resyncs` runs right after `_advance_iframes` ->
  `resynchronized`. Downed actors' move/block/switch are dropped in the Command loop. Enemies have no
  profile -> their deaths are byte-identical to before. State: `_resync_profiles` RUN_ACTOR,
  `_resyncs_used_on_floor` + `_resync_due_tick` ACTOR_TRANSIENT (load_floor = fresh charge, never banks).
- **Expedition:** `PHASE_RECALLED`, `is_recalled`, `is_over()`, `recall(tick)` (EXPLORING only, once),
  `floors_cleared()`. `emergency_recall` Event; `expedition_complete` stays success-only.
- **Arena:** `_envoy_alive` RETIRED (reads `sim.is_active`). `_resolve_transitions()` = Recall THEN floor
  completion (the one place the order lives). Exhausted on completing tick -> Recall wins; revival pending
  -> completion deferred to the revival tick (dropping it would softlock). World STOPS on both endings
  (Recall despawns tracers). `_finalize_run` once -> frozen `_summary_rows` -> `RunSummaryOverlay`.
- **UI:** `run_summary_overlay.gd` (rows list; NO loot row -- P46), `resync_overlay.gd` (countdown from
  sim). Old `failure_overlay` / `expedition_complete_overlay` deleted. Final console says "Extraction".
- **Downed presentation (HUMAN PASS):** `envoy.collapse()` tips `Model` over (0.4 s, 88 deg) on `died`,
  stays down; `envoy.stand()` on `resynchronized` and every `_load_floor`. Presentation only.
- Tests: `test_resync.gd` (15), `test_expedition.gd` (+4), `test_expedition_flow.gd` (55; FAILURE WINS
  re-baselined 2026-10-20, `_deliver(..., "fall")` = real lethal hit). Mutants 10/10 + 2/2 caught.

**Unchanged, all HUMAN PASS:** Floor 4 (keys: focus = aim, reach 2.0, underfoot 0.45 never focused) · P44
shared 90-tick window · Slice 1 (phases, 45-tick descent, cached `_next_plan` identity, console, transmission).

## Next action — Expedition Slice 3: minimal title screen + run-start flow. **Plan first, no code.**
Run /kickoff-style planning, then WAIT for approval. Today a run starts on scene boot (`_ready ->
begin_expedition()`) and R reloads the scene from anywhere, including the run summary ("Press R to
redeploy"). Slice 3 should give boot a title, start a run from it, and route both run-end outcomes back
(or to a redeploy). Keep `begin_expedition()` the one run entry. Questions to raise: does R stay global;
what the title shows (name, seed?); title -> run transition (reuse transmission?).
**Not authorized:** loot, rewards, settings menus, accounts, co-op, animation system, new hazards/enemies,
generator work, art pass.

## Deferred (ROADMAP, do NOT build in M2 slices)
- **P46** loot on the run-end summary (append rows; Recall loot retention UNDECIDED). **P49** dramatic
  death/resync animation (KayKit rig clips first). **P45** descent preloading.
- **P47** co-op health-sacrifice revival (50% own max paid, 50% target max; separate from the free 100%).
- **P48** co-op downed Envoy carried through a transition: resync on arrival at 100%; into a combat floor
  it spends THAT floor's charge (spend AFTER load_floor); into a Terminal = full reset, no debt.

## Accepted partials / flags
- **M3:** `aim` LENGTH is behavioural (P42); P45 never stalls authority; floor change = driver call, not Event.
- Itinerary is an `@export` default; `_TERMINAL_DEPTH = 3` / `_FOUNDRY_DEPTH = 4`; no layout table. Terminal
  is bland greybox (debt). §6.3 (Foundry's "one world rule") is an OPEN M2 question.
- i-frames show nothing on screen; a held shield on an active pad drains every tick; enemies freeze while
  the Envoy is down (existing "no living player" rule) -- all existing law, accepted in playtest.
- Two untracked files at repo root (`KNIGHTS-DEPTH-EXPLORATION-*`) are the human's; NEVER commit them.

## Open items / live fences
- **NUMERIC FENCE (M1).** `close_frustration_ticks = 90` · Survey package · `engagement_delay_ticks = 10` ·
  wand `flinch_capability = none` · all M1 HP/flinch values · `vulnerable_start_tick` FROZEN.
- **LEASH RULE (2026-09-08) is law.** **SEED HONESTY.** **Enemies are immune to environmental hazards.**
- **Closable connections need DISJOINT patches; an aperture must overlap both.** **Free-standing masses
  <= 3x3.** **AMBIENT TERRITORIES CONVEX** · triggers INCLUSIVE. **Progression capability must be guaranteed.**
- **Still out (M2 gate):** 3-5 floors per stratum (Archive 2, Foundry 1) · >=8 segments / procedural
  question (design review owed; via GAME-RULES §7) · stratum-driven pools/weights · depth-scaled defence ·
  typed_damage_ramp · minimap · **title screen (Slice 3)** · netcode spike · friend playtest · playtest gate
  · itch build. (Run-end Recall/Extraction screen + restart: delivered by Slice 2, pending the full gate.)
  **ROADMAP prune DUE at M2 close** (Index lacks a P37 row). Carried from M1: three §3 rules want a human
  edit · P14 · P16 · 5.10.

## Traps this repo has actually sprung
- **GUT ignores `-gtest=<path>`.** Use `-gselect=test_floor4`. In PowerShell build it as a variable
  (`$arg = "-gselect=" + $t`) -- an inline `-gselect=$t` is passed literally.
- **GAME-RULES.md edits are hook-blocked even with approval.** The sanctioned path: a JSON manifest
  (target, approval citation, pre_sha256, exact replace/insert_after edits) then
  `python -I scripts/guard.py --amend <manifest> --i-have-explicit-user-approval`. Never bypass.
- **A local itinerary change breaks the suite.** It must be `[1, 2, 3, 4]` at commit.
- **Bound every predicate-wait loop in a test** (BRAIN). **New `class_name` -> `--headless --import`.**
  **Bash heredocs choke on Python with quotes/tabs** -- scratchpad script + `python -I`. **Material floats
  are float32.** **Measure the shared knob before splitting it by source** (BRAIN).
- **Position a cross-source test OFF the pad.** **Walk-to helpers stop short** (`_beside(key_at)`).
  **`Rect2.has_point` far edge EXCLUSIVE; `WalkableBounds.contains` INCLUSIVE.** **Drive the SHIPPED weapon
  the shipped way**, and **verify BOTH anchors of a splice**.
- **Presentation is test-exempt, so it is the blind spot** -- `test_presentation_contracts.gd`.
- **Never re-record `ai_baseline_pre_p29.json` or the P17 Fang baseline.** **Never round-trip source
  through PowerShell Get-Content/Set-Content** (UTF-8 corruption).
- A Bash `cd` into a subfolder breaks the `scripts/guard.py` pre-edit hook -- cd back to root.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd` (1096, ~2 min,
  35 orphans is the baseline). Headless sim CI: `-gselect=test_sim_world
  -gunit_test_name=test_ticks_1000_times_headless`. Boot: `--headless --path . --quit-after 300`.
- Guard: `python -I scripts/guard.py --scan` (2 pre-existing `knight` warnings). Goldens:
  `-s tools/record_floor_plan_golden.gd` (deliberate re-baseline only, dated note).
- Mutation check: scratchpad script backs up, mutates one anchor (assert unique), runs `-gselect`,
  restores + byte-compares; give each run a `timeout`.

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
shared window · parameter sweep before a rule split · phase machine owning a frozen-sim transition ·
cached plan as a promise (identity, not equality) · contextual press arbitration · bounded test loops ·
**zero health as the downed state** · **commit-at-incapacitation (no half-spent state)** · **party predicate
vs per-actor fact** · **outcome finalized once at the run boundary** · **transition priority in one function**.
