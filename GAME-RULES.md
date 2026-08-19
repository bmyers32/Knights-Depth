# GAME-RULES.md — Domain Law
Purpose: code contradicting this file is a bug by definition — fix the code or amend
this file deliberately via the Change Log (§7). Always loaded with CLAUDE.md.

## §1 Failure Catalog → Law
(No prior dead project to autopsy — these are the documented graveyard of solo
SK-like/MMO attempts. Treat them as if they cost us a codebase already.)
1. **Netcode retrofitted onto single-player** kills more co-op projects than any other
   cause → Sim/presentation split + Command/Event pattern from Milestone 1. Sim must
   run headless (CI proof: a script ticks SimWorld 1000x with scripted commands, no
   display server). Netcode later swaps the driver, not the game.
2. **Magic numbers scattered in scripts** make tuning archaeological → every tunable in
   content resources/config with a name. A number appearing twice in code is a defect.
3. **Unseeded/global RNG** makes procedural bugs unreproducible → seeded RNG streams
   per system (gen, combat, loot — separate streams so one system's draws don't shift
   another's). Seed on debug overlay; bug repro = seed + command log.
4. **Building an engine instead of a game** → rule of two: no generic framework/tool
   until two concrete shipped uses exist. Copy-paste twice before abstracting.
5. **Polish before fun** → playtest gate: a mechanic proves fun in a 10-minute
   ugly-graphics playtest before receiving any art/juice/animation budget.
6. **"While I'm here" scope creep** → ideas route to ROADMAP Feature Proposals with
   the entry format; never inline. Every milestone has a written NOT-list.
7. **Asset license contamination** creates legal risk the day you share a build → ASSETS.md manifest;
   nothing enters the repo without source + license + date line. SK IP = never.
8. **Frame-rate-dependent gameplay** (logic in `_process`, missing `dt`, physics in
   render loop) → gameplay on the fixed sim tick only; document tick rate (start:
   30 Hz sim, 60+ fps render, interpolated).
9. **Node-path spaghetti** (`get_node("../../../HUD")`) couples everything → signals
   up, calls down; cross-tree access only via autoloads whitelisted in CLAUDE.md.
10. **Save-format drift** corrupts long-term saves → version field in every save file
    from the first write; a migration or an explicit "unsupported version" path exists
    for every version ever shipped.
11. **All-or-nothing MMO stranding** — quitting mid-M3 leaves nothing playable →
    Always-Playable Exit: every milestone ends as a STANDALONE game you (and friends)
    can actually play (itch build). M2's build is explicitly a complete single-player
    game with an ending screen, not a demo of a future MMO. A finished thing you can
    hand to a friend is also the strongest motivation fuel this project has.
12. **Unpushed work doesn't exist** — solo dev, one disk → private remote from Session 0;
    push is a /closeout step, not a choice. The repo never ends a session ahead of origin.

## §2 Simulation Architecture
- Tick model: SimWorld advances in fixed ticks. Inputs become Commands stamped with the
  tick they apply to. SimWorld consumes Commands, mutates state, emits Events.
- Presentation subscribes to Events and interpolates between sim states for rendering.
- Honesty clause: GDScript floats ≠ bit-perfect determinism across machines. We do NOT
  chase lockstep determinism; the M3 model is server-authoritative state + client
  prediction (§4). Seeded reproducibility (§1.3) is for debugging on one machine.
- SimWorld knows nothing about Nodes, scenes, or rendering. `import`/preload of any
  Node-derived type inside sim/ fails code review by definition.

## §3 Combat Spec v1 (M1 scope — original names, RG-inspired mechanics; see MECHANICS-REFERENCE.md)
- Damage types: **Force** (baseline), **Pierce**, **Arc**, **Umbral**. Six enemy
  families (Fang, Dread, Tinker, Ooze, Hollow, Watcher — see LEXICON.md; "Automaton"
  renamed), each weak to exactly ONE type and resistant to exactly ONE; Force is
  nobody's weakness and everybody's fallback. Matrix lives in one data resource; a
  content-lint test asserts the invariants (each non-Force type = weakness of exactly
  two families; every family resists exactly one non-Force type). M1 ships THREE
  families: **Fang, Ooze, Watcher** — one playable weakness per specialized type
  (Pierce/Umbral/Arc), the cleanest combat-slice test of the matrix. Hollow debuts
  in the Archive (M2) alongside its true-name reveal. LOCKED until playtest evidence
  says otherwise (§7 seed+7); the matrix ships complete.
- **Family × State orthogonality:** enemy identity = family (matrix row) + state
  (Common / Drifted / Claimed — content-level tag). States NEVER touch the damage
  matrix; they drive spawn tables, AI flavor, visuals, and narrative. A state variant
  that needs its own matrix row is a design error (WORLD-CANON).
- **Anti-multiplier rule:** a family does NOT require every state variant. Content
  ships as authored family–state combinations; the orthogonal model permits reuse,
  it never mandates a complete family × state product (RISKS #13's logic applies to
  enemies too). M1 ships exactly ONE authored state per family, covering all three
  states: **Common Fang · Drifted Ooze · Claimed Watcher** (follows the canon's
  spawn-skew guidance; teaches the three-axis model with zero content multiplication).
- Dual-type weapons resolve as two simultaneous half-attacks, each checked against
  the matrix independently — no averaging.
- Telegraph law: every enemy attack telegraphs with a ground indicator colored by its
  damage type; hit feedback color encodes resisted/neutral/weak. One config table maps
  type → palette; presentation reads it, never hardcodes colors.
- **Channel law:** damage types own telegraph/hit-effect color. Entity STATES
  (Drifted / Claimed) own SILHOUETTE and MOTION RHYTHM/COORDINATION — the TEMPORAL
  channel: Drifted breaks rhythm (asymmetry, staggered timing); Claimed shares it
  (synchronized pacing, mirrored formations). FAMILIES own BASELINE MOTION PATH — the
  SPATIAL channel: the shape a family traces through space while approaching, holding,
  or committing. The two channels are ORTHOGONAL BUT COMPOSABLE: state does not replace
  family path identity, and family path identity must not accidentally impersonate
  state coordination. A Drifted Fang is BOTH channels composing — "never merge" is
  explicitly rejected as false to legitimate composition.
  BINDING CONSEQUENCE for content: any family-owned path shape whose phase derives from
  a global clock MUST carry a deterministic per-actor phase offset, normalized against
  the shape's own period so actor identity shifts PHASE only — never period, waveform or
  amplitude. Without it a group of Common actors renders synchronized and reads as
  Claimed — state coordination impersonated by an accident of implementation.
  State identity never competes with type color for the same channel; exact palettes
  stay provisional until the Umbral/damage-type art pass (LEXICON.md).
- Status v1: exactly ONE effect ships in M1 (**Burn**: DoT ticks, spreads on contact —
  in data). Architecture law from day one: **one status slot per entity**; a new
  status replaces the current one per a priority table in data (statuses are exclusive,
  never stacked). Full roster (Frost, Jolt, Venom, Daze, Hex, Slumber) with defined
  identities lives in ROADMAP — one per playtested iteration after M2.
- Melee: 3-hit combo + hold-to-charge. Ranged: projectile with travel time. Every
  weapon resource carries a `class` field (sword/gun/bomb) even though bombs land
  later. Shield: hold to block, own break meter that regenerates, knockback on break.
  i-frames on dodge/hit (durations in sim ticks — never seconds in code).
- **Enemy action selection (P29).** Enemy AI may select one authored `action_id` from
  its repertoire according to deterministic distance-band eligibility. AI still decides
  only locomotion, whether to attack now, and which eligible authored action to commit;
  all action shape and resolution remain content-owned. Action eligibility must never be
  ambiguous: authored bands may not overlap. For the current repertoire model,
  non-terminal bands are half-open `[min, max)` and only the repertoire's outermost band
  includes its maximum. Selection commits at windup start and is never re-evaluated
  during that windup. Aim is sampled at the fire tick, not at action commitment.
- Knockback resolves inside the sim pipeline (hit → matrix → status → knockback →
  death/events), so M3 can replicate it; it is not a physics-engine impulse.
- Every threshold ships with a calibration note: observed feel at default, and the
  playtest date that validated it.

## §4 Netcode Invariants (bind from M1 via architecture; enforced in M3)
1. Server is authoritative over: health, damage, status, spawns, loot, floor layout.
2. Client predicts ONLY its own movement + attack animation start; server corrections
   reconcile. A client message is a *request*, validated server-side, never a command
   the server obeys blindly.
3. Remote players render interpolated, ~2 snapshots behind.
4. All net messages are the same Command/Event types as offline (that's the point).
5. Playability bar: 4 players at 150 ms artificial latency + 2% loss must feel fair.
6. Never trust client-reported position for hit resolution; server rewinds/validates.
7. (M4+) Credentials: never store plaintext passwords — prefer federated/itch/Steam auth
   over rolling our own; if unavoidable, argon2/bcrypt only. Auth + VPS hardening is its
   own Medium-ambiguity design session at M4 kickoff, never improvised inline.

## §5 Milestone Exit Gates (order mandatory; /closeout checks the active row)
| M | Exit criteria — ALL must pass |
|---|---|
| 0 | 2 warmup games finished (not perfect); repo + hooks + tests scaffold run green; Godot version pinned |
| 1 | Headless sim CI green · 3 enemy types with data-driven stats · damage-matrix unit tests both directions (weak & resist) · combo/charge/shield/i-frames in sim ticks · Burn status test · 10-min playtest gate PASSED and logged · itch.io build uploaded |
| 2 | Same seed → byte-identical FloorPlan (golden-seed test) · run structure = 2 themed strata (**Archive, Foundry** — WORLD-CANON; each stratum's "one world rule" is an M2 design question, not a gate item) (3–5 floors each) with a safe rest floor between, elevator auto-descend at rest floors · stratum theme drives segment pool + hazard/status set + enemy-family weights (all from config) · next-floor preview on the elevator (theme + expected families) · depth-scaled enemy defense from per-stratum config · typed_damage_ramp knob (early floors deal Force-only, typed damage phases in) · gen time <100 ms/floor · ≥8 distinct room segments · minimap · **complete game**: title, run-end screen (framed as Emergency Recall / extraction per WORLD-CANON), restart (§1.11) · **netcode spike**: one moving entity replicated between 2 clients in a throwaway branch — meet the M3 wall while it's small · hand the build to ≥1 friend and watch them play (fresh eyes catch what the builder can't) · playtest gate · itch build |
| 3 | 2–4 clients on LAN + 150 ms artificial latency playable per §4.5 · server-authority tests (client cannot self-heal/teleport) · reconnect mid-run works · a real co-op session with ≥1 friend · itch build |
| 4 | Save/load round-trip property test (save→load→save byte-identical) · schema versioned · hub scene with crafting/heat loop · dedicated headless server runs on a VPS · §4.7 auth design session held before any account code · ≥1 friend playtest · playtest gate |
| 5 | Re-scoped at M4 exit — criteria written then, not now |

## §6 Design Laws — World & Systems
(Produced by the world-identity design arc; canon in WORLD-CANON.md, vocabulary in
LEXICON.md. §6.1–.2 are hard gates; §6.6 is explicitly a tiebreaker, never a gate.)
1. **One fiction, many mechanics.** New systems must attach to existing fiction; new
   lore must explain existing systems. Inventing a separate lore explanation for a
   mechanic Synchronization already covers = world fragmentation. (Exemplar:
   Synchronization explains expeditions, loadout, depth strain, death, respawn.)
2. **Deepen before create.** Every feature first names the existing system it deepens.
   Every NEW permanent progression loop must justify its lifetime maintenance cost
   (tuning, UI, save data, tutorials, bug surface) — count loops, not concepts.
3. **Layer rule.** Every stratum introduces one new rule of the world before it
   introduces stronger enemies. Depth = conceptual escalation, not bigger numbers.
4. **Expression, not access.** Narrative choices (protocols) primarily change how
   shared systems behave, not which systems a player can use. Rare deliberate gating
   (secret ending, lore reveal) is allowed; parallel progression ecosystems are not.
5. **Seduction principle.** Drift-derived power must be genuinely tempting — a trade,
   never a trap. If Temper/Drifted gear is strictly worse, the world's central
   argument collapses.
6. **Thesis tiebreaker.** The central fantasy (CORE-FANTASY.md) breaks ties among
   features that already passed §6.1–.2 — it never substitutes for them (almost
   anything can be argued to "reinforce identity" if you squint).
7. **Vocabulary law.** LEXICON.md governs player-facing strings AND code identifiers
   (e.g. `drift_level`, never `corruption_level`). Banned strings are guard-enforced;
   new names follow the grammar.
8. **The world predates the war.** Not every phenomenon aligns to a force. Umbral is
   primordial, aligned to neither Drift nor Axiom. Some spiders are just spiders.
   **Three axes, never merged:** world forces (Drift/Axiom/Humanity) = philosophy;
   entity states (Common/Drifted/Claimed) = what something became; damage types =
   combat method. Any family/state wields any type per its attack data — a Drifted
   beast still bites (Force); types are never faction property. Umbral's combat
   identity is coherence disruption, not "dark damage" (LEXICON.md).

## §7 Change Log
| Date | § | Change | Reason |
|---|---|---|---|
| (seed) | all | Initial law: solo-MMO failure commons + SK mechanics research | Project baseline |
| (seed+1) | §1.11–12, §4.7, §5 | Portfolio-Safe Exit, push discipline, auth seed, devlog/external-tester/spike gates | RISKS.md review: risks 1–4, 6, 7 |
| (seed+2) | §1.11, §5 | Portfolio framing removed: devlogs dropped from gates, §1.11 → Always-Playable Exit, testers → friend playtests; Treat Rule added (AGENTS.md) | Goal reprioritized: hobby > portfolio; motivation is the metric |
| (seed+3) | §3, §5 M2 | Family/damage matrix invariants + telegraph law + single-status-slot law; M2 gate now specifies strata/rest-floor run structure, next-floor preview, depth scaling, typed-damage ramp | Wiki mechanics research → MECHANICS-REFERENCE.md |
| (seed+4) | §3, §5 M2, §6 (new), §7 | World-identity capture: knight→Envoy global rename; Automaton→Watcher; M1 families = Fang/Hollow/Watcher; family×state orthogonality; channel law (types=color, forces=motion); strata named (Archive, Foundry); Emergency Recall framing; Design Laws §6 added; LEXICON.md, WORLD-CANON.md, CORE-FANTASY.md created | Ten-document lore/design arc converged; captured before drift. M0 complete. |
| (seed+5) | §6.8, LEXICON, ROADMAP P10 | Three-axis law explicit (forces/states/damage-methods never merged); Umbral combat identity = coherence disruption; P10 fixed — Drifted gear costs are Umbral-neutral | Post-capture review caught P10 residue binding Drift↔Umbral; type-count challenge declined (4 types × 6 families is a locked arithmetic pair per §3 invariants) |
| (seed+6) | §3, LEXICON, WORLD-CANON, MECHANICS-REF, SETUP, CORE-FANTASY, ROADMAP P9/P12 | QA fixes: "corruption engine"→Drift engine (LEXICON's own violation!); Umbral=dark gloss corrected; channel law forces→STATES; knight→Envoy in warmup text; anti-multiplier rule for family×state (one authored state per M1 family); Act 3 chronology; Umbral softened to general coherence disruption; CORE-FANTASY marked provisional-authority; P9 god-variable guard; P12/P7 decoupled per rule of two | External QA diff review; validates that vocabulary needs mechanical enforcement (guard.py), not authorial attention |
| (seed+7) | §3, CLAUDE.md M1 | M1 roster LOCKED: Fang/Ooze/Watcher (one weakness per specialized type — combat-slice validation) as Common/Drifted/Claimed respectively; Hollow moved to Archive (M2) debut with true-name reveal | Developer decision after QA review; combat validation beats compressed cosmology in an arena slice; reversal requires playtest evidence |
| 2026-08-14 | §3 | P29 enemy repertoire amendment. Enemy AI authority widened narrowly from movement + attack timing to deterministic selection of an authored action by distance eligibility. Action shape remains content-owned. Added non-overlapping range-band semantics, windup-time action commitment, and fire-time aim sampling. | First consumer: Watcher `watcher_survey` |
| 2026-08-18 | §3 | P17 channel-law amendment. Motion resolved into two channels: FAMILIES own BASELINE MOTION PATH (spatial), entity STATES own MOTION RHYTHM/COORDINATION (temporal). The channels are ORTHOGONAL BUT COMPOSABLE — "never merge" was considered and rejected as false to legitimate composition (a Drifted Fang is both channels composing). Added the binding content consequence that globally-phased family motion must carry a deterministic per-actor phase offset, normalized against its own period so actor identity shifts phase only. | First consumer: Fang authored approach weave (ROADMAP P17) |
