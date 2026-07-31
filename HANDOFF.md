# HANDOFF — 2026-07-31 (M1 sim skeleton session)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- Phase D step 1 (SETUP-AND-START.md): sim skeleton built and committed (666b942).
  - `game/sim/command.gd` — Command class (RefCounted), fields tick/actor_id/kind/params.
  - `game/sim/event.gd` — Event class (RefCounted), fields tick/kind/payload.
  - `game/sim/sim_world.gd` — `SimWorld.tick(commands: Array[Command], dt) -> Array[Event]`.
    Entities keyed by actor_id in a Dictionary; move speed travels in Command.params,
    not a sim-side const (keeps Prime Directive 3 clean before ContentDB exists).
  - `tests/test_sim_world.gd` — 6 GUT cases incl. the GAME-RULES §1.1 CI proof (1000
    headless ticks, zero Node touched).
- Verification Gate run twice (pre-commit and at closeout): all items PASS, no
  partials. GAME-RULES §1 spot-check also clean (grepped for SK-IP terms, get_node
  chains, `_process` gameplay logic — zero hits).
- BRAIN.md: appended second occurrence to the existing "class_name needs editor scan"
  entry — hit again cold this session exactly as the M0 entry predicted, confirming
  the lesson is load-bearing.
- Toy warmup files (`toy_sim_world.gd`, `toy_player.gd`, their tests) left untouched —
  no naming collision with the new SimWorld/Command/Event globals; both suites green.

## Not done / next action
1. Phase D step 2 — Envoy moves for real: input → Commands → SimWorld → model
   interpolation. First visible payoff of the sim/presentation split. Needs: an Envoy
   scene/Node (CharacterBody3D, per the toy pattern), `attack`/`block` input actions
   (only `move_*` exist in project.godot's Input Map so far), and a real move-speed
   tunable — this is the natural point to stand up ContentDB/content resources
   (deliberately deferred out of step 1, see Do NOT redo).
2. Asset intake session (KayKit/Quaternius CC0 pulls for Envoy + Fang/Ooze/Watcher) —
   still pending, untouched across multiple sessions now.
3. Steps 3-10 of Phase D (sword/damage pipeline, first enemy, shield/i-frames, gun,
   enemies 2&3 + Burn, arena + playtest, itch build) — not started.

## Open tensions
- Pyre name provisional (Temper art direction); Hollow true name unassigned.
- Palettes provisional pending Umbral/damage-type art pass (channel law holds).
- Sync-as-meter: default NO (narrative only); annotated in canon.
- CORE-FANTASY pillars are [YOUR CALL] drafts — developer homework, no deadline.

## Concepts introduced this session
- RefCounted vs Node: sim classes extend RefCounted (no scene tree, no rendering,
  refcounted GC) specifically so sim/ structurally cannot touch a display server.
- Godot 4 typed arrays (`Array[Command]`): runtime-checked homogeneous arrays, first
  use beyond the toy warmup's untyped `Array`.

## Do NOT redo
- Naming re-litigation: slate is LOCKED (LEXICON amendment rule).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12).
- Do not rename statuses to lore words (REJECTED — ROADMAP NOT-list).
- guard.py: do not remove the self-path exemption or scan the guard's own source.
- Sim design calls from this session are now the pattern, not open questions:
  entities keyed by actor_id in a Dictionary; per-actor tunables (speed, etc.) travel
  in Command.params until ContentDB exists, never as bare sim-side consts.
- Delegation mode stands as of this session: build directly, don't offer "you drive,
  I review" unless explicitly asked — user corrected an unprompted offer back to build.

## Files touched
`game/sim/command.gd` · `game/sim/event.gd` · `game/sim/sim_world.gd` ·
`tests/test_sim_world.gd` · `BRAIN.md` · `HANDOFF.md` (this file)
(all except this HANDOFF rewrite are already committed in 666b942)
