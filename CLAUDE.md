@AGENTS.md
@GAME-RULES.md

# CLAUDE.md — Knight Depths (working title)

## Grounding
Solo hobby project — built because building it is the point: a top-down co-op action
roguelite inspired by Spiral Knights' *mechanics* — 100% original IP, assets, and names.
Godot 4 + GDScript. Milestone-gated: each milestone ends as a finished, playable thing
before the next begins. Multiplayer-ready architecture from Milestone 1 even though
netcode lands in Milestone 3. Bind all decisions to this.
**Fun to play > feature count. Momentum > process purity. A playable game > a perfect plan.**

## Developer Context
Proficient Python scripter, new to gamedev. Explain engine/gamedev concepts (scene tree,
signals, fixed timestep, client prediction) in 2–3 sentences on first use, with a doc
link — understanding keeps the project enjoyable, but it's a hobby, not a curriculum.

## Prime Directives (violation = RED LINE; rationale in GAME-RULES §1)
1. All gameplay state lives in the sim layer and mutates ONLY via Commands. Presentation
   (nodes, sprites, UI) reads sim state and emits Commands — it never writes state.
2. Gameplay logic runs on the fixed sim tick (`_physics_process` / SimWorld.tick).
   `_process` is for presentation interpolation only.
3. All tunables (damage, speeds, costs, gen parameters) live in content resources or
   config — never literals in scripts. Tuning = data change, never code.
4. All procedural generation and combat RNG is seeded per-system. The active seed is
   always visible on the debug overlay and logged. Bug report = seed + command log.
5. No Spiral Knights assets, names, lore, or ripped files in the repo, ever. Every asset
   enters through ASSETS.md with a license line (CC0 or original).
6. A milestone is complete only when every GAME-RULES §5 exit criterion passes,
   including the playtest gate and an uploaded itch.io build.
7. Bug bar: no new systems while the current milestone has open Severity-1 bugs.

## Stack
| Layer | Choice | Hard Constraint |
|---|---|---|
| Engine | Godot 4.x (pin exact version in README) | No engine upgrades mid-milestone |
| Language | GDScript (typed: `var x: int`) | Static typing on all sim code |
| Sim | Plain-object sim layer, headless-runnable | Zero Node dependencies in sim/ |
| Content | Godot custom Resources (.tres) | One resource type per content family |
| Netcode (M3) | Godot high-level multiplayer API | Server-authoritative per §4 |
| Persistence (M4) | SQLite | Versioned save schema from first write |
| Tests | GUT addon | Sim + gen logic covered; presentation exempt |
| Art | 3D low-poly: KayKit + Quaternius (CC0), Kenney All-in-1 (licensed), Blockbench originals | glTF preferred; ASSETS.md manifest mandatory |
| Builds | itch.io (HTML5 or desktop) per milestone | Buildable at every close-out |

## Structure
```
knight_depths/
├── game/
│   ├── autoload/      # GameRoot, ContentDB, DebugOverlay (service locators — listed here only)
│   ├── sim/           # SimWorld, Command, Event, combat resolution — NO Node imports
│   ├── actors/        # Node scenes: knight, enemies — presentation + input → Commands
│   ├── content/       # weapons/, enemies/, status/ as .tres resources
│   ├── gen/           # seeded depth/floor generation — headless-runnable
│   ├── net/           # M3+: sync, prediction, server entry point
│   └── ui/            # HUD, menus
├── tests/             # GUT: sim, gen, content validation
├── tools/             # calibration & content-lint scripts
├── ASSETS.md          # every asset: source, license, date added
└── project.godot
```

## Core Interfaces (contracts — do not drift)
- `SimWorld.tick(commands: Array[Command], dt) -> Array[Event]` — the only mutation path.
- `Command` = {tick, actor_id, kind, params} · `Event` = {tick, kind, payload}. Both are
  plain data (serializable) — this is what makes M3 netcode a driver swap, not a rewrite.
- `ContentDB.get(family, id) -> Resource` — content lookups by id, never preloads in sim.
- `DepthGenerator.generate(seed: int, depth: int) -> FloorPlan` — pure function of inputs.
- Combat pipeline order (fixed): hit detect → damage-type matrix (§3) → status apply →
  knockback → death/events. New mechanics slot into this pipeline, never bypass it.

## Milestones (exit criteria in GAME-RULES §5)
| # | Scope | Status |
|---|---|---|
| 0 | Warmups: 2 tiny tutorial games; Godot basics; repo + workflow bootstrap | [x] |
| 1 | Combat slice: knight, sword+gun+shield, 3 enemies, 1 arena, 1 status effect | [ ] |
| 2 | Procedural depths: tile segments, seeded 5-floor runs, elevators, difficulty curve | [ ] |
| 3 | Co-op netcode: 2–4 player server-authoritative, prediction, 150ms-latency playable | [ ] |
| 4 | Persistence & hub: accounts/saves, hub scene, crafting/heat progression | [ ] |
| 5 | MMO layer: dedicated server, auction house, guilds, PvP mode (re-scope at M4 exit) | [ ] |

## Always-On Rules
- Comments explain WHY, never narrate WHAT. Cite GAME-RULES §-numbers where code
  implements a law. No docstrings restating signatures.
- Every sim/gen behavior change: GUT tests updated same session; golden-seed tests
  (fixed seed → identical floor) re-baselined only deliberately, with a dated note.
- Signals up, calls down. `get_node("../..")` is banned; cross-tree access goes through
  the autoloads listed in Structure — adding an autoload requires a CLAUDE.md edit.
- Implied requirements: implement + flag at >80% confidence — never silently add/omit.
- Ideas mid-session → ROADMAP.md Feature Proposals, never inline "while I'm here" code.
- Headless test command (this machine, PowerShell — run verbatim):
  `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd`

## Companion Files
**Always loaded:** AGENTS.md (rules of engagement), GAME-RULES.md (domain law —
contradicting code is a bug by definition).
**Per session:** HANDOFF.md (read by /kickoff, overwritten by /closeout — hard cap 120 lines).
**On demand:** ROADMAP.md, BRAIN.md (wisdom), ASSETS.md.
**Zero-token until invoked:** .claude/commands/ (kickoff, closeout, gate, recon, playtest, resume).
