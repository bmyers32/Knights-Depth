# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** First M2 gate work has landed.

**M2 Slice 1 (seeded bounded floor) is COMMITTED and has a HUMAN PASS.** Suite **523/523**.
Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
`run_seed → DepthGenerator.generate(seed, depth) → FloorPlan → SimWorld.load_floor()` is
live and playable: one seeded rectangular chamber, sim-authoritative walkable bounds,
floor-driven spawning, seed/depth visible on screen.

**Human verdict:** bounds read as natural, placement feels fair, combat unaffected — but
the chamber is a **COMBAT-ROOM PRIMITIVE, not a floor**. Ruled explicitly: *do not enlarge
the rectangle and call that exploration.* It gets reused as the COMBAT room type.

## Next action — M2 MULTI-ROOM SLICE (proposal approved, 4 rulings issued)
Build the complete linear floor before asking for another human look:
**ENTRY → TRAVERSAL → COMBAT(lock) → CLEAR → TRAVERSAL → FLOOR END**

Build order (do NOT stop for a human look after 1–3; hand back the integrated slice):
1. **Multi-rect clamp fix** — evaluate legal candidates across ALL rects containing `from`,
   pick the deterministic candidate nearest the intended destination. Array order must
   never create a phantom wall at a doorway.
2. **`RoomPlan[]` / `ConnectionPlan[]`** + linear-chain generator; `walkable_rects` becomes
   the DERIVED flattened union (room rects + aperture rects). Apertures **overlap** both
   rooms — abutting rects give a zero-area junction and break continuity.
3. **Camera follow (P21)** — translating only, preserve the validated 45° angle and combat
   framing/scale, clamp to floor extent. No room snapping.
4. **Encounter lock + room roster + activation/clear + gate barriers.**

### The four rulings (binding)
1. **Enemy room confinement: ALWAYS**, not conditional on lock state. Applies to every
   authoritative enemy displacement seam, not just locomotion. Consumes P18's
   bounded-by-room direction.
2. **Combat lock seals BOTH SIDES** — player and every living roster actor. Nothing may
   push/lunge/bump/burrow out through a closed connection. Clears only when the roster is
   dead; a burrowed Fang is ALIVE and still counts. On clear, gates reopen permanently.
3. **End-of-floor marker: YES** — deterministic visual endpoint only. NOT an elevator, NOT
   floor-transition logic, NOT run-end UI. It exists to make the test grammar visible.
4. **Dormant combat aggro: NO** — a dormant roster does not detect the player through an
   open doorway. Entry activates the encounter, then the roster wakes. **Do not build
   doorway LOS/visibility propagation.**

### One implementation detail called out as must-be-explicit
Closed-aperture legality **must not shrink the combat space or snap an actor away from a
doorway threshold**. Define which side/portion of an aperture belongs to the locked
encounter, and **test activation while the player is mid-threshold**.

## Open items / live fences
- **NUMERIC FENCE (M1, unchanged).** `close_frustration_ticks = 90` (PROVISIONAL, fallback
  60) · Survey package (`hit_radius` 0.20 / speed 7.0 / windup 34 / vulnerable 23–34) ·
  `engagement_delay_ticks = 10` · wand `flinch_capability = none` · all M1 HP/flinch values.
  `vulnerable_start_tick` is explicitly FROZEN.
- **M2 PROVISIONAL values** (StratumConfig, validated only by play):
  `min_spawn_distance_from_entry = 10.0` · `min_spawn_separation = 3.0` · chamber size
  ranges. The chamber Z ceiling (26) exists **because of the fixed camera** — P21 lifts it.
- **PROJECTILE-VS-WORLD COLLISION: deferred by explicit fence** (ROADMAP P20, not only a
  code comment). Body displacement obeys bounds; projectiles do not. Trigger to revisit:
  first floor with interior geometry or a non-convex chamber.
- **P20 body-blocking still open.** Actor-vs-actor overlap is unsolved; the generator works
  around it with `min_spawn_separation`. Ally separation (M3 co-op) also undecided.
- **Step 2 will deliberately invalidate `tests/fixtures/floor_plan_golden.json`.** That is a
  DELIBERATE re-baseline with a dated reason in the same commit — never a re-record to make
  red go green.
- **ROADMAP prune DUE at M2 close** — Index over cap. P16/P28/P29 are tombstone candidates.
- Carried from M1: three GAME-RULES §3 rules want a human edit · **P14** working title ·
  P16 BUMP pass-through (P20) · 5.10 chain-flinch feel.

## Traps this repo has actually sprung (read before touching these areas)
- **A remembered audit list goes stale.** P17's position-write list (move/lunge/bump/burrow)
  was missing BOTH knockback paths and `add_entity`. **Re-run the `entities[]` audit before
  adding any displacement mechanic** — `grep -n "entities\[" game/sim/sim_world.gd`.
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
· **placement-refuses vs displacement-clamps as distinct seams**.
