# HANDOFF — 2026-07-31 (Envoy sim pipeline session)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- Phase D step 2 committed (61df44f): real Envoy input -> Command -> SimWorld ->
  presentation pipeline, replacing the M0 toy pattern.
  - `SimWorld.add_entity(actor_id, position, move_speed)` — tunables register once,
    Commands now carry only per-tick intent (`direction`). `move`'s old
    `params.speed` is gone; sim reads `_move_speeds` set at registration.
  - `ContentDB` autoload (`game/autoload/content_db.gd`): explicit registry, method is
    `get_resource(family: StringName, id: StringName) -> Resource` — NOT `get()`
    (GDScript can't override native `Object.get()`, hard parse error; CLAUDE.md Core
    Interfaces line corrected to match). Missing family/id -> `push_error` + `null`,
    no bare `assert()` (stripped in release exports).
  - `game/content/envoy/envoy_stats.gd`/`.tres` — first real content resource,
    `move_speed = 4.0` (matches the M0 toy's calibrated feel).
  - `game/actors/envoy/envoy.gd`/`.tscn` — real Envoy: `build_command()` builds
    `move` only; `sync_from_sim(sim_position)` is presentation-only, sets transform,
    never sim state (Prime Directive 1).
  - `game/dev/envoy_movement_dev.gd`/`.tscn` — dev-only scaffold, owns the one shared
    `SimWorld`, drives the tick loop. Explicitly temporary; dies at Phase D step 8.
  - `project.godot`: `ContentDB` autoload registered; `attack`/`block` Input Map
    actions added (LMB/RMB) but nothing reads them yet — only `move` enters the
    Command stream this session; `physics/common/physics_interpolation=true` (engine
    smooths transforms set in `_physics_process` across faster render frames — no
    manual lerp code).
  - Tests: `test_sim_world.gd` updated for the registration flow (+1 new boundary
    test: unregistered entity + move command = no movement); `test_content_db.gd`
    added (4 registry cases + 1 sim-integration case). 17/17 GUT passing headless.
- Verification Gate: all items PASS or N/A (fun-impact N/A — pure plumbing, no
  playtest-gated mechanic yet).
- BRAIN: two entries updated — "class_name needs editor scan" hit a 3rd time
  (`EnvoyStats`); "GDScript can't override native Object methods" is new wisdom.

## Not done / next action
1. **Phase D step 3: sword damage pipeline.** First sim mechanic beyond `move` —
   hit detect -> damage-type matrix -> status apply -> knockback -> death/events
   (fixed pipeline order, GAME-RULES §3/Core Interfaces). Needs an `attack` Command
   kind (bindings already exist in Input Map, unused), a weapon content resource
   family (`sword_A` mesh is in the repo, no resource wrapping it yet), and a target
   to hit — likely pairs naturally with step 5 (first enemy, Fang) rather than
   sequencing strictly.
2. Steps 4-10 of Phase D: first enemy (Fang) in sim, shield/i-frames, gun, enemies
   2&3 (Ooze/Watcher) + Burn status, real arena (Kenney assets — retires
   `game/dev/envoy_movement_dev.tscn`), 10-min playtest gate, itch build. Not started.

## Open tensions
- Pyre name provisional (Temper art direction); Hollow true name unassigned.
- Palettes provisional pending Umbral/damage-type art pass (channel law holds).
- Sync-as-meter: default NO (narrative only); annotated in canon.
- CORE-FANTASY pillars are [YOUR CALL] drafts — developer homework, no deadline.

## Concepts introduced this session
- Godot physics interpolation (project setting): automatically smooths any transform
  written in `_physics_process` across the faster `_process` render frames between
  fixed sim ticks — replaces hand-rolled lerp-between-snapshots code entirely.
- GDScript cannot override a native `Object`/`Node` method (`get`, `set`, `free`,
  `connect`, ...) with a different signature — hard parse error, not a warning; check
  new autoload/service-locator method names against `Object`'s method list first.

## Do NOT redo
- Naming re-litigation: slate is LOCKED (LEXICON amendment rule).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12).
- Do not rename statuses to lore words (REJECTED — ROADMAP NOT-list).
- guard.py: do not remove the self-path exemption or scan the guard's own source.
- Sim design calls are the pattern, not open questions: entities keyed by actor_id in
  a Dictionary; tunables register via `SimWorld.add_entity(actor_id, position,
  move_speed)` — **superseded from last session:** tunables no longer travel in
  `Command.params`; params carry only per-tick intent (e.g. `direction`).
- SimWorld ownership: ONE shared instance per level, owned by a scene-level driver
  (not an autoload, not one-per-actor). Actors hold a direct reference and the driver
  calls down (pulls commands, pushes results) — no `get_node` upward paths, no
  signals needed for this. Don't generalize it into a reusable `SimDriver` class until
  a second concrete scene needs it (rule of two) — that's naturally step 8 (real arena).
- ContentDB's lookup method is `get_resource(family, id)`, never `get()` — see BRAIN.
- Headless GUT runs need a prior `godot --headless --import` (not `--quit-after N`,
  which can race and abort mid-scan) whenever a new `class_name` script is added —
  see BRAIN "class_name needs editor scan."
- Asset intake pattern: extract zips to OS temp (never into the repo), inspect for
  wrapper folders and license files directly, confirm glb vs external-ref gltf before
  copying, one commit per intake batch.

## Files touched
`CLAUDE.md` (Core Interfaces line) · `BRAIN.md` (2 entries) · `game/sim/sim_world.gd` ·
`game/autoload/content_db.gd` (new) · `game/content/envoy/**` (new) ·
`game/actors/envoy/envoy.gd`/`.tscn` (new) · `game/dev/**` (new) ·
`tests/test_sim_world.gd` · `tests/test_content_db.gd` (new) · `project.godot` — all
committed in 61df44f. `HANDOFF.md` (this file, committed at closeout).
