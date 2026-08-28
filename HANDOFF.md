# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** First M2 gate work has landed.

**M2 Slice 1 COMMITTED (`e7bea74`, human PASS). M2 MULTI-ROOM SLICE BUILT — AWAITING HUMAN
PASS.** Suite **552/552**. Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
One seeded, explorable, multi-room floor is playable end to end:
**ENTRY -> TRAVERSAL -> COMBAT(seal) -> CLEAR -> TRAVERSAL -> FLOOR END.**
`FloorPlan -> RoomPlan[] + ConnectionPlan[] -> derived walkable_rects`; room roles come from
`StratumConfig.room_sequence` (content), sizes/rosters/placements are seeded. Follow camera
(P21) consumed. Default `run_seed = 0` builds 4 rooms / 3 connections / 4 enemies.

## Next action — THE HUMAN PASS (this is the whole next step)
Press play. The five questions this slice exists to answer:
1. Does moving through connected spaces feel like **exploring a floor**, not standing in a
   bigger arena?
2. Does entering the combat room and having the exits **seal** read naturally?
3. Does the fight stay **spatially coherent** under room confinement?
4. Does clearing it and continuing onward feel like **meaningful progression**?
5. Does the **follow camera** keep combat readable while allowing exploration?

**FLAG FOR THAT PASS — difficulty moved and nobody has judged it.** Sealing removes retreat,
which was Slice 1's implicit safety valve. Measured: the shipped 30 HP Envoy dies to a 4-Fang
sealed room in roughly 40 s of continuous engagement. `spawn_count_min/max` (3-5) stay
PROVISIONAL and are the first knob if the encounter reads as unfair. Deliberately NOT retuned
blind — combat values are fenced and this is a human call.

## Open items / live fences
- **NUMERIC FENCE (M1, unchanged).** `close_frustration_ticks = 90` (PROVISIONAL, fallback 60)
  · Survey package (`hit_radius` 0.20 / speed 7.0 / windup 34 / vulnerable 23-34) ·
  `engagement_delay_ticks = 10` · wand `flinch_capability = none` · all M1 HP/flinch values.
  `vulnerable_start_tick` is explicitly FROZEN.
- **M2 PROVISIONAL values** (StratumConfig, validated only by play): `spawn_count_min/max`
  3-5 (see difficulty flag above) · `min_spawn_distance_from_entry = 10.0` ·
  `min_spawn_separation = 3.0` · `corridor_length` 6.0 · `aperture_width` 5.0 ·
  `aperture_overlap` 1.5 · connective room sizes. **Combat-room sizes (24-34 x 20-26) are
  VALIDATED BY PLAY** — do not retune them to make a floor longer; add rooms instead.
- **`aperture_overlap` MUST stay > 0.** Abutting rects share zero area, which turns every
  threshold into a discontinuity and re-opens the gate/snap problem the overlap solves.
- **PROJECTILE-VS-WORLD COLLISION: deferred by explicit fence** (ROADMAP P20). Body
  displacement obeys bounds; projectiles do not. Trigger: first non-convex chamber or interior
  geometry.
- **P20 body-blocking still open.** Actor-vs-actor overlap is unsolved; the generator works
  around it with `min_spawn_separation`.
- **Burrow emergence is bounded by room ownership.** Candidates sit around the PLAYER, so
  triggering a burrow while the Envoy is in another room kills the Fang by fail-safe. Correct,
  unreachable in real play (a live encounter seals the player in), and the reason burrow tests
  call `_place_envoy_in_room_of`.
- **Golden fixture was RE-BASELINED 2026-08-28** for the room schema — logged with its reason
  in `tools/record_floor_plan_golden.gd`. It is not a drift-hiding re-record; never do one.
- **ROADMAP prune DUE at M2 close** — Index over cap. P16/P28/P29 are tombstone candidates.
- Carried from M1: three GAME-RULES §3 rules want a human edit · **P14** working title ·
  P16 BUMP pass-through (P20) · 5.10 chain-flinch feel.

## Traps this repo has actually sprung (read before touching these areas)
- **A remembered audit list goes stale.** P17's position-write list (move/lunge/bump/burrow)
  was missing BOTH knockback paths and `add_entity`. **Re-run the `entities[]` audit before
  adding any displacement mechanic** — `grep -n "entities\[" game/sim/sim_world.gd`. That
  audit is why the multi-room seal was a one-function change: all 8 sites already funnel
  through `_legal_bounds_for`.
- **A test that stops measuring at the first hit can lie.** `test_combat_runs_normally_inside_
  the_sealed_room` broke out on first damage and reported "no attacks" — the Envoy had already
  died during the walk-in, and a dead player produces no AI at all. Use a FIXED window and
  confirm the mechanism fired before believing a zero.
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.is_inside` is INCLUSIVE.**
  A correctly-clamped actor rests exactly ON the boundary, so `has_point` reports it as having
  escaped. Use an inclusive check in tests.
- **Presentation is test-exempt, so it is the blind spot.** `tests/test_presentation_contracts.gd`
  pins method surfaces + drives real verbs through the real arena. It broke when Slice 1
  retired the named `$Fang`/`$Watcher` scene children — generated rosters are now found via
  `_enemy_of_family(arena, family)` on a searched seed, never a hardcoded one.
- **Never re-record `ai_baseline_pre_p29.json`** (M1-preservation gate) or the P17 Fang
  baseline to make a test pass.
- **A scanner never proven to fail is not a scanner.** The STATE_SCOPES scanner was verified
  by injecting a real unclassified var and watching it go red. Do this for the next one too.
- Run diagnostics **without** suppressing stderr; confirm the mechanism fired before
  trusting numbers.
- A `-s` tool script compiles **before** autoloads register — `load()` anything touching
  ContentDB dynamically, never by `class_name`.

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd`
- New `class_name`? run `--headless --import` first.
- Boot check: `--headless --quit-after 120` (real main scene, prints seed + floor).
- Tools: `tools/record_floor_plan_golden.gd` (golden re-baseline — deliberate only) ·
  `tools/record_family_locomotion.gd` · `tools/diagnose_projectile_geometry.gd` ·
  `tools/measure_survey_cadence.gd`

## Concepts introduced (learning ledger)
Sim tick vs frame · Command/Event plain-data boundary · service-locator autoload · seeded
RNG streams · fixed combat pipeline order · typed GDScript arrays · half-open intervals ·
Minkowski-sum collision · derived-vs-stored state · cosmetic prediction / dead reckoning ·
golden-behaviour baselines · guard clauses vs world facts · GUT scene-instantiation smoke
tests · **pure function + per-call RNG as a purity mechanism** · **reflection-based coverage
scanners (`get_property_list`)** · **union-of-rects legality vs per-axis clamp (wall slide)**
· **placement-refuses vs displacement-clamps as distinct seams** · **overlapping rects as
connectivity (no portal/graph model)** · **per-actor legality regions (floor / owned room /
encounter seal) resolved at one seam** · **exponential frame-rate-independent camera lerp**.
