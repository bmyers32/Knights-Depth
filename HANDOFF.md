# HANDOFF
Milestone: **2 — Procedural depths. IN PROGRESS.** First M2 gate work has landed.

**M2 Slice 1 (`e7bea74`) PASS. M2 MULTI-ROOM SLICE (`5cff467`) — SPLIT VERDICT: MECHANICS
PASS / FLOOR GRAMMAR FALSIFIED.** Suite **552/552**. No code written since; the next step is
a DATA MODEL REVIEW, not implementation.
Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
Playtest closed against `5cff46747f68f2693fefa0ad1c92b9c4771dbf54` (provenance verified:
clean tree, no later commits, reflog unmoved, no file newer than the commit).

**Breon: "It's still giving 4 boxes."** Bounds/connections readable, placement fair, combat
solid and unaffected, the explicit button-then-encounter sequence solid — but it works as a
battle-arena structure, not as an exploration floor, and lacks the spatial/depth feeling of
the live references.

**PASS, validated, DO NOT re-test from zero and DO NOT erase:** connected walkability ·
confinement/lock · trigger -> spawn -> lock · clear -> reopen -> continue · follow-camera
viability · **and the positive datum: the explicit "hit this button, start the encounter"
sequence "was solid"** — the seed of the authored-activation direction.

**FALSIFIED:** "FloorPlan = sequential rectangular rooms connected by doors" as the PRIMARY
exploration-floor abstraction. The error is the parent abstraction, not the mechanics.
Bigger/more/varied rectangles are explicitly rejected as the fix.

## Next action — DATA MODEL REVIEW, then hand-authored prototype
A floor is **a continuous, stateful traversal space whose available routes change in response
to player actions.** Four INDEPENDENT concepts (a room parents none of them):
SPATIAL · PROGRESSION · ENCOUNTER · WORLD INTERACTION. **Encounter region != physical room.**

Full direction, laws, fences and the target prototype floor are in ROADMAP
"M2 FLOOR GRAMMAR — DIRECTION SET 2026-08-28". **No implementation until the model is
reviewed.**

### FROZEN HUMAN CRITERION (verbatim — do not paraphrase when judging)
> "The floor passes only if it feels like traversing and interacting with a place — seeing
> somewhere before you can reach it, finding what opens the way — rather than moving between
> generated arenas."

### Binding laws for the next slice
- **The gate does not need to understand why it opened.** Controller / state / effect stay
  separate (BRAIN candidate, banked).
- **One interactable may atomically cause many floor-state changes** (party button: seal rear
  + open forward + spawn roster + begin encounter). Do NOT distribute that sequence across
  gate, spawn and presentation code.
- **Encounter activation is AUTHORED.** `entered the area => combat` is rejected.
- **Depth comes from space, not vertical combat** — silhouettes, voids, ramps (presentation),
  occlusion, folded topology. Only if it still feels flat afterwards is height machinery
  justified.
- **Minimal breakable approved** (reveals a concealed interactable) — no economy, no loot,
  no destructible framework. **Throwable DEFERRED**: it is a new gameplay capability, not
  floor plumbing; do not smuggle it in as level design. Principle banked: *if progression
  requires a capability, the floor must guarantee access to it.*
- **Hand-authored first + SEED HONESTY.** `generate(seed, depth)` keeps its signature but
  resolves an authored layout; seeds do NOT vary geometry yet and UI must not imply they do.

## Open items / live fences
- **NUMERIC FENCE (M1, unchanged).** `close_frustration_ticks = 90` (PROVISIONAL, fallback 60)
  · Survey package (`hit_radius` 0.20 / speed 7.0 / windup 34 / vulnerable 23-34) ·
  `engagement_delay_ticks = 10` · wand `flinch_capability = none` · all M1 HP/flinch values.
  `vulnerable_start_tick` is explicitly FROZEN.
- **M2 PROVISIONAL values** (StratumConfig): spawn counts 3-5 · spawn distance/separation ·
  corridor/aperture sizes. **Combat-room sizes (24-34 x 20-26) are VALIDATED BY PLAY.**
- **Aperture overlap MUST stay > 0.** Abutting rects share zero area, turning every threshold
  into a discontinuity and re-opening the gate/snap problem the overlap solves.
- **Sealed-encounter difficulty is UNJUDGED.** Sealing removes retreat; a 30 HP Envoy dies to
  a 4-Fang sealed room in ~40 s. Spawn counts are the first knob. Never retuned blind.
- **PROJECTILE-VS-WORLD COLLISION: deferred by explicit fence** (ROADMAP P20). Body
  displacement obeys bounds; projectiles do not. Trigger: first non-convex chamber or interior
  geometry.
- **P20 body-blocking still open.** Actor-vs-actor overlap is unsolved; the generator works
  around it with `min_spawn_separation`.
- **Burrow emergence is bounded by room ownership.** Candidates sit around the PLAYER, so a
  burrow triggered while the Envoy is elsewhere fail-safe-kills the Fang. Correct, unreachable
  in real play, and why burrow tests call `_place_envoy_in_room_of`.
- **Golden fixture was RE-BASELINED 2026-08-28** for the room schema — logged with its reason
  in `tools/record_floor_plan_golden.gd`. It is not a drift-hiding re-record; never do one.
- **ROADMAP prune DUE at M2 close** — Index over cap. P16/P28/P29 tombstone candidates.
- Carried from M1: three §3 rules want a human edit · **P14** title · P16 BUMP pass-through
  (P20) · 5.10 chain-flinch feel.

## Traps this repo has actually sprung (read before touching these areas)
- **A remembered audit list goes stale.** P17's position-write list (move/lunge/bump/burrow)
  was missing BOTH knockback paths and `add_entity`. **Re-run the `entities[]` audit before
  adding any displacement mechanic** — `grep -n "entities\[" game/sim/sim_world.gd`. That
  audit is why the multi-room seal was a one-function change: all 8 sites already funnel
  through `_legal_bounds_for`.
- **A test that stops measuring at the first hit can lie.** One reported "no attacks" because
  the Envoy had already died during the walk-in, and a dead player produces no AI at all. Use
  a FIXED window; confirm the mechanism fired before believing a zero.
- **`Rect2.has_point` is EXCLUSIVE on the far edge; `WalkableBounds.is_inside` is INCLUSIVE.**
  A clamped actor rests ON the boundary, so `has_point` reports it as escaped. Use an
  inclusive check in tests.
- **Presentation is test-exempt, so it is the blind spot.** `test_presentation_contracts.gd`
  pins method surfaces + drives real verbs through the real arena. Generated rosters are found
  via `_enemy_of_family(arena, family)` on a searched seed, never a hardcoded one.
- **Never re-record `ai_baseline_pre_p29.json`** (M1 gate) or the P17 Fang baseline to make a
  test pass. **A scanner never proven to fail is not a scanner** — STATE_SCOPES was verified by
  injecting a real unclassified var and watching it go red. Do this for the next one too.
- Run diagnostics **without** suppressing stderr; confirm the mechanism fired before trusting
  numbers. A `-s` tool script compiles **before** autoloads register — `load()` anything
  touching ContentDB dynamically, never by `class_name`.

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
