# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS (NOT complete).** Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Boot -> **Title -> Home; Home, Commons, Ready Room one action apart; pad -> expedition (Floors 1, 2, Depth 3
Terminal, Depth 4 Foundry) -> summary -> Commons.** Floors: `AuthoredLayout` -> `LayoutCompiler` -> `FloorPlan`,
picked by DEPTH (authored; the seed changes nothing spatial). Four goldens unchanged.

## EXPEDITION SLICE 3 — SHIPPED `37be23d`. HUMAN: Ready Room "satisfactory for now" 2026-10-22
- **`game/main/main.gd` (`GameMain`, scene root, NOT an autoload; `run/main_scene`).** Owns which place is
  on screen, one move at a time (`go_to`: latch -> `freeze()` -> fade -> `remove_child`+`queue_free` ->
  build with exports -> fade in). `run_seed = 0` fixed (P50). `itinerary_override` empty = the Arena
  scene's own value, read via `_arena_default()` (also hands over `descent_ticks`). Prepares the Floor 1
  plan ONCE on entering the Ready Room; the briefing and `arena.prepared_first_plan` are the SAME object.
- **`game/hub/hub_space.gd` (`HubSpace`):** one scene for Home / Commons / Ready Room, own small SimWorld
  (move + console press only; no weapons/roster/Expedition). Travel = HUD buttons (click) or Tab menu
  (Tab cycles, Enter travels, Esc backs out), one latched `request_travel`. Hub camera (0, 9, 9);
  expedition keeps (0, 12, 12). Envoy drawn on visual ground (`_grounded`), sim flat.
- **Deployment = transmission:** pad `floor_complete` -> `_begin_departure` (inputs latched, travel HUD
  hidden, TransmissionField + DescentOverlay for `departure_ticks` = arena `descent_ticks` 45) ->
  `deploy_requested` once; Main CUTS under the dark screen (`FadeOverlay.cover/uncover`); the Arena
  (`arrives_by_transmission`) plays the descent's arrival (`_present_arrival`). Nothing is completed by
  deploying. Hub travel keeps the short fade.
- **Ready Room = one open hall** (`ready_room.tres`): lower arrival apron, console island ahead (lectern
  faces arrival), two stepped approaches (visual-only risers), merchant NW, armory + crafter east, pad
  unchanged at Rect2(-2,-25,4,4) in a framed north recess. Walks: briefing 0.9 s, pad 8.0 s.
- **Hub-only FloorBuilder switches** `draw_obstacle_faces = false`, `solid_raised_ground = true` (P51). **Arena:**
  `standalone` gates R; summary Button; `freeze()`; `FloorPreview`; `begin_expedition()` still the one run entry.
- Tests: navigation 31, ready_room_space 16, hub_layouts 6. Mutants: Ready Room 12/13 (survivor legitimate), deployment 9/9.
**NOT human-checked:** travel-HUD hiding during departure; a full Extraction/Recall -> Commons loop under Main. Home = shell; Commons = placeholder (P52).

## ADR-001 PROCEDURAL FLOORS — S0 `6631ed8`, S1 `5b588c6`, S2 `a4f87dd`; S2.5 `6d252cd` (human ITERATE); S3a `2879d07`; S3b `1a7a18e` G2 PASS; G3: SEGMENT OK, FLOOR NOT YET
- `ADR-001-PROCEDURAL-FLOORS.md` is the design of record (ROADMAP P53); numbers in `ADR-001-S2-MEASUREMENTS.md` (+§S2.5).
  Stages are authorized ONE AT A TIME; **S3b (progression + objective integrity) AUTHORIZED 2026-10-26, NO-COMMIT G2 gate; G3 human NOT performed; S4+ NOT authorized.**
- **S2 (committed):** `seed_mix.gd` (a `-s` tool cannot compile anything reaching ContentDB), `traversal_profile.gd`,
  `floor_recipe.gd`, `generation_report.gd`, `floor_composer.gd` (`compose(recipe, floor_seed, depth, radii)`: cast
  sorted-then-weighted; positions FROM THE ROUTE; depth-first `mark()/rewind()`; cycle-closing I/L/Z/U; fallback APART).
- **Playtest verdict:** better than the first authored rooms; seed 42 best; areas narrow, routes want interest; the exit
  gallery's sealing fight woke enemies ON the player and packed fight + switch + key + receiver + exit into 12x8.
- **S2.5 (`6d252cd`; human ITERATE: arena better, dogleg no exploration, shortcut flat, crate opening ruled out):** `game/gen/encounter_spacing.gd` ARRIVAL REACH = envoy body + enemy body + attack band + speed x
  (shortest windup + `EnvoyStats.spawn_reaction_ticks` 15)/30 from the region's CENTRE (nearest-point flagged 3 accepted
  shipped rooms -- BRAIN); fang 5.7 / ooze 6.35 / watcher 5.63; every shipped room passes, the gallery (2.0, 2.2) fails.
  Pit 20x26 (spawns 12.5-15.1 ahead of the plate, cover pillar); `archive_exit_landing` (pad+console, `in` + west `side`)
  replaces the gallery in BOTH recipes (gallery kept as the S1 fixture); `link_turn` 16-32 one bend; `proto_archive_dogleg`
  (landmark.side -LINK_TURN-> encounter; landmark.out -DETOUR-> objective; objective.out -SHORTCUT-> exit.side). Tools
  take `--recipe=` (build/compose_sweep_<recipe>.json, build/composed/<recipe>/). 200 seeds each: column 200/0 fallback/
  p99 52 ms; dogleg 200/0/p99 59 ms; 0 spawn findings; all PASS S0. **Found, unchanged:** `SimWorld._activate_encounter`
  makes a roster present AND active the same tick with no engagement opener (`_acquire_aggro` arms one) -- owner's call.
## Next action
1. **G3 2026-10-27: fold + key loop provisionally accepted; floor NOT accepted (easy outbound, weak safe-return payoff).** Next: return-path hazard crossing, FEASIBILITY REVIEW ONLY (no content change). Fold: `proto_archive_fold` + `archive_entry_hall`/`_landmark_crossing`/
   `_objective_key_vault` + `return` profile + `tools/route_metrics.gd` (ADR §7 "S3a as built"). 200/0/0, p99 14 ms. Play:
   `.\tools\play_composed_floor.ps1 -Seed 7 -Recipe proto_archive_fold -Diagram`. Integrity 200/200 (S3b). 2. Commons plan (P52).
**Deferred (ROADMAP, do NOT build in M2 slices):** P46 loot on summary · P49 death/resync animation ·
P45 descent preloading · P47/P48 co-op revival + carry-through · P38 party/loadout/route · P51 skirts.

## Accepted partials / flags
- **M3:** `aim` LENGTH is behavioural (P42); `GameMain.go_to(EXPEDITION)` is the seam a server "request deployment" replaces; hub sims local; pad deployment is SOLO, not ready-up.
- **Owed docs (wording not approved):** LEXICON **Ready Room** + **Home**; CLAUDE.md lists nonexistent
  `GameRoot`/`DebugOverlay` autoloads; `arena.gd:53` RNG comment stale. `_TERMINAL_DEPTH = 3` /
  `_FOUNDRY_DEPTH = 4`; §6.3 Foundry rule OPEN; Terminal greybox. **NEVER commit `KNIGHTS-DEPTH-EXPLORATION-*`.**

## Open items / live fences
- **NUMERIC FENCE (M1).** `close_frustration_ticks = 90` · Survey package · `engagement_delay_ticks = 10` ·
  wand `flinch_capability = none` · all M1 HP/flinch values · `vulnerable_start_tick` FROZEN.
- **LEASH RULE (2026-09-08) is law.** **SEED HONESTY.** **Enemies are immune to environmental hazards.**
- **Closable connections need DISJOINT patches; an aperture must overlap both.** **Free-standing masses
  <= 3x3 on expedition floors** (hubs exempt, ruled 2026-10-22). **AMBIENT TERRITORIES CONVEX** · triggers
  INCLUSIVE. **Progression capability must be guaranteed.**
- **Still out (M2 gate):** 3-5 floors per stratum (Archive 2, Foundry 1) · >=8 segments (ADR-001; §5 wording
  untouched) · stratum pools/weights · depth-scaled defence · typed_damage_ramp · minimap · netcode spike ·
  friend playtest · playtest gate · itch build. ROADMAP prune DUE at M2 close. M1 carry: §3 ×3 · P14 · P16 · 5.10.

## Traps this repo has actually sprung
- **GUT ignores `-gtest=<path>`.** Use `-gselect=test_floor4`. In PowerShell build it as a variable
  (`$arg = "-gselect=" + $t`) -- an inline `-gselect=$t` is passed literally.
- **GAME-RULES.md edits are hook-blocked even with approval.** Sanctioned path: a JSON manifest then
  `python -I scripts/guard.py --amend <manifest> --i-have-explicit-user-approval`. Never bypass.
- **A local itinerary change breaks the suite.** It must be `[1, 2, 3, 4]` at commit.
- **Headless root viewport is 1152x1152**: camera tests set `root.size = Vector2i(1152, 648)` and restore.
  **LayoutCompiler does NOT copy `key`**: use `layout.id_in(&"patch", key)`. **`AABB.intersects_segment`
  returns a Variant** (point or null): compare `!= null`.
- **Bound every predicate-wait loop in a test** (BRAIN). **New `class_name` -> `--headless --import`.**
  **Bash heredocs choke on Python with quotes/tabs; `cat > file` + heredoc can hang** -- Write a scratch
  script, run `python -I`. **Material floats are float32.**
- **`Rect2.has_point` far edge EXCLUSIVE; `WalkableBounds.contains` INCLUSIVE.** Abutting patches JOIN.
- **Presentation is test-exempt, so it is the blind spot** -- `test_presentation_contracts.gd`; check what
  the renderer draws before re-authoring content (BRAIN). **Never re-record `ai_baseline_pre_p29.json` or
  the P17 Fang baseline.** **Never round-trip source through PowerShell Get-Content/Set-Content.**
  A Bash `cd` into a subfolder breaks the `scripts/guard.py` pre-edit hook -- cd back to root.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd` (1234, ~3 min,
  35 orphans is the baseline). Headless sim CI: `-gselect=test_sim_world
  -gunit_test_name=test_ticks_1000_times_headless`. Boot: `--headless --path . --quit-after 300`.
- Guard: `python -I scripts/guard.py --scan` (2 pre-existing `knight` warnings). Goldens:
  `-s tools/record_floor_plan_golden.gd` (deliberate re-baseline only, dated note).
- Mutation check: scratchpad script mutates one anchor (assert unique), runs `-gselect`, restores + sha-compares, with a
  `timeout`. ONE Godot at a time (a background batch was killed for memory 2026-10-22); guarded test reads, not crashes.

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
zero health as the downed state · commit-at-incapacitation · party predicate vs per-actor fact · outcome
finalized once at the run boundary · transition priority in one function · **scene root vs autoload for
navigation** · **latched one-shot requests** · **remove_child before queue_free** · **GUI focus vs gameplay
input** · **a cut under an already-dark screen** · **renderer rules hidden behind content** · **positions from the
route, not the route from positions** · **undo by mark** · **a fixture proved impossible, not assumed**.
