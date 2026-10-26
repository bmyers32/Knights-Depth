# ADR-001 — Hybrid hierarchical procedural floor generation

**Status:** APPROVED IN PRINCIPLE (owner, 2026-10-22) with the rulings and corrections recorded in §0.
Implementation proceeds stage by stage: **S0 shipped** (`6631ed8`, reviewed and accepted 2026-10-23);
**S1 shipped** (`5b588c6`, reviewed PASS 2026-10-23); **S2 technical implementation verified and
committed** (`a4f87dd`, technical PASS 2026-10-23; §7, "as built"); **S2 human gate: ITERATE**
(played 2026-10-23: better than the first authored rooms, seed 42 the best arrangement; the final
sealing chamber too small, enemies waking on the player, too many mechanics in one room, routes
wanting interest) → **S2.5 committed** (`6d252cd`, 2026-10-26; §7, "S2.5 as built";
`ADR-001-S2-MEASUREMENTS.md` §S2.5) with its **human gate: ITERATE**; **S3a (folded remote-key
expedition: geometry and content) authorized 2026-10-26 with a no-commit G1 review gate; S3b and later
are not authorized.** Nothing in this document changes a GAME-RULES law, a milestone criterion, or the
player-facing meaning of any existing acceptance item (§8).

Labels: **[C]** confirmed in the repository · **[R]** recommendation · **[M]** a value to be measured
before it is chosen · **[O]** an owner decision, with its ruling.

---

## 0. Owner rulings and corrections (binding)

| Id | Ruling |
|---|---|
| O1 | Shared camera configuration resource, read by `FollowCamera` and handed to gen/; existing camera behaviour preserved exactly. |
| O2 | `GenerationReport` stays OUTSIDE `FloorPlan.to_dict()`; diagnostics must still be associable with the floor they describe. A static `last_report` is a temporary debug interface only. |
| O3 | Fresh run seed per expedition; explicit debug seed override; replay by seed. Not part of S0. |
| O4 | Every threshold is measured before a number is locked. Generation targets and reliability checks stay explicit. |
| O5 | The authored baseline may use hand-made hallways; the comparison is player experience and authoring effort. |
| O6 | Piece transforms default to identity; mirroring is an explicit per-piece opt-in. |
| O7 | Technical vocabulary: **FloorPiece**, **TraversalProfile**, **Junction** (LEXICON, technical register). |

Corrections carried into the design: pieces are lintable on their own and playable through generated
entry/exit fixtures, not held to whole-floor rules (§6); progression validation reports PASS / FAIL /
UNSUPPORTED and never claims what it cannot model (§5.3, built in S0); generation diagnostics are kept
per floor despite next-floor preview generation, and fallbacks are counted apart from successes
(§5.6); the first coding step is the smallest useful one (§7).

---

## 1. Context [C]

- A floor built as "rectangular rooms joined by doors" was rejected in play ("It's still giving 4
  boxes", 2026-08-28). The validated model is a continuous, stateful traversal space; no layer parents
  another (`game/gen/floor_layers.gd`).
- The frozen criterion for a floor: *"seeing somewhere before you can reach it, finding what opens the
  way — rather than moving between generated arenas."*
- Floor 2 and Floor 4 earn their beats with **cross-area** relationships: a loop whose far door opens
  from the cache; a fork left deliberately unlocked; keys lifted in one place and delivered in another
  (`FLOOR-AUTHORING-NOTES.md`, `foundry_assembly.tres`). "Length and branching are the reveal tool"
  (BRAIN 13); hallways are defined by elongation and flow, not emptiness (BRAIN 12); an overlap is not a
  doorway (BRAIN 16).
- Pipeline today: `AuthoredLayout (.tres) → LayoutCompiler.compile → FloorPlan → arena._unpack_floor /
  FloorBuilder`. `DepthGenerator.generate(seed, depth)` is the pinned interface; its body selects an
  authored layout by depth and validates. `derive_floor_seed` is live and unused. Generation has no RNG.
- The camera is fixed at 45° (`(0,12,12)` on floors); reveals are camera-distance facts.
- `FloorPlan.validate()` reported by `push_error` only; `FloorPlan` is plain data with a `to_dict()`
  golden; the sim keys records by id in dictionaries (ids need not be contiguous; -1 is the sentinel);
  the exit console is a single plan field registered under fixed id 0.

---

## 2. Decision

**Hybrid hierarchical composition.** A generated *experience graph* with three distinct edge sets
(physical, visibility, dependency), assembled from authored cycle templates, casts **authored
FloorPieces** for the moments that need design judgement (landmarks, objectives, encounters, entry,
exit), places them under camera-derived constraints, routes **generated connective ground** between
them from a small set of **TraversalProfiles** (with **Junctions** where routes meet), wires
dependencies **across pieces** through symbolic ports, and lowers the result through a new `FloorDraft`
to an ordinary `AuthoredLayout` → the unchanged `LayoutCompiler` → `FloorPlan`.

Responsibility boundaries:

| Owns | Never owns |
|---|---|
| **Author** — a piece's interior: geometry, rosters, reveals, ports | hallway geometry, which piece goes where, cross-piece wiring |
| **Planner** — which roles exist, the three edge sets, where gates and unlocks go | any coordinate |
| **Placer + router (one coupled search)** — piece positions, connective ground, joints, junctions | piece interiors, rosters |
| **Wirer** — ports → effects; identifier renumbering | gameplay semantics (FloorLayers' vocabulary, unchanged) |
| **Validators** — machine-checkable structure, progression, visibility, fit, budgets | gameplay or visual approval |
| **LayoutCompiler, SimWorld, Arena, FloorBuilder** — unchanged consumers | any knowledge of pieces |

Rejected alternatives, recorded: pure set-piece composition (scales the rejected result; a full loop
has to fit inside one module); mission-driven full generation (too much algorithm for one person, and
it would have to encode judgement the project learned by playing). Fallback if the hybrid fails its
prototype: authored floor skeletons with variable chapters (§7, F).

---

## 3. Compatibility guarantees (hard)

- `DepthGenerator.generate(seed, depth) -> FloorPlan` is the only entry; a recipe-backed depth runs
  the pipeline inside it. Callers are unchanged: `main.gd` prepares Floor 1 once at Ready Room entry;
  `arena.gd` generates `_next_plan` once per floor load and installs that object on descent.
  **Prepared-plan identity is preserved by construction** — nothing new caches or regenerates.
- Generation is synchronous inside `generate`; the <100 ms gate (GAME-RULES §5 M2) bounds the hitch.
- The generator emits only the nine existing layers plus the three markers. A piece needing a mechanic
  the sim lacks is unauthorable; the sim is never extended from gen/.
- The sim stays flat; `solid_segments()` stays the one wall truth; the combat RNG is untouched;
  `Command`/`Event` shapes are untouched; existing goldens (depths 1–4) are untouched.
- No parallel procedural gameplay system exists: pieces are authored in the same `AuthoredLayout`
  format floors are, and compile through the same code.

---

## 4. Data contracts (minimal)

```
FloorPiece (.tres, game/content/floors/pieces/)                      [built S1]
  piece_id: StringName
  role: StringName                      entry | landmark | objective | encounter | exit
  body: AuthoredLayout                  LOCAL coordinates; references nothing outside body
                                        except `@<port key>` on a connection-layer effect (its own joint)
  footprint: Rect2                      reserved cells incl. walls; body rects ⊆ footprint
  allowed_transforms: Array[StringName] default [&"identity"]; &"mirror_x" opt-in (O6)
  ports: Array[PiecePort]
  lint(enemy_keys) -> findings          {rule, message, refs}; the stratum is body.stratum_id
  DEFERRED TO S2 (no consumer before the caster): depth_min, depth_max, weight, tags

PiecePort (one type; `kind` decides which fields are read)         [built S1]
  key: StringName                        unique in the piece: &"in", &"out", &"side", ...
  kind: connector | gate | unlock | vantage | anchor
  edge, offset, width, patch_key         connector/gate: where a joint aperture may sit; offset is
                                         measured from the edge's min coordinate (x-min for north/south,
                                         z-min for east/west); the patch must reach the edge across the span
  trigger_key / switch_key               unlock: the body record whose effects gain the cross-piece effect
  position: Vector3                      vantage (where the party can stand) / anchor (what must be seen)

TraversalProfile (.tres, five instances, §5.2)
  profile_id, width, length_min, length_max, max_turns, flank_style, mouth_width   [M]

CycleTemplate (.tres)
  nodes [{role, tags, optional}]; physical [{a, b, profile, gate?}];
  visibility [{from, to, mandatory}]; dependency [{unlock_node, gate_edge}]; splice_in, splice_out

FloorRecipe (.tres)
  recipe_id, stratum_id, templates (ordered), flow_axis, grid_cell [M],
  budgets {candidates_per_piece, placements, reseeds}, fallback: AuthoredLayout

FloorDraft (RefCounted, in memory only)  pieces placed + hallway rects + joints + the three edge sets
  [built S1] place(piece, origin, transform) -> iNN · lay(rects, surface, boundary) -> hNN ·
  bind(instance, port, hallway, overlap, flank) -> jNN; world = T(local) + origin, one mapping
  (world_rect / world_point / world_edge / port_span). Edge sets arrive with the planner (S2/S3).
DraftEmitter.emit(draft) -> EmitReport   [built S1] layout OR errors {kind, message, refs}; remap table
GenerationReport (RefCounted, O2)         seed, attempts, rejections by reason, fallback flags, validators, time
```

Deliberately absent until a consumer exists: connector types beyond width, rarity tiers,
monster-count predicates, visual identity, piece rotation, `FloorSequence`.

---

## 5. Pipeline and algorithms

```
run_seed, depth
 └ floor_seed = derive_floor_seed(run_seed, depth)                                  [C]
   streams: plan = derive(floor_seed,1) · cast = derive(floor_seed,2) ·
            place = derive(floor_seed,3) · populate = derive(floor_seed,4) (reserved)
 1 PLAN     recipe + plan stream → ExperienceGraph
 2 CAST+PLACE+ROUTE  one coupled depth-first search, piece by piece (§5.1)
 3 WIRE     ports → effects; renumber (§5.5)
 4 EMIT     FloorDraft → AuthoredLayout (flat)
 5 COMPILE  LayoutCompiler.compile (unchanged) → FloorPlan
 6 VALIDATE existing rules via violations() · progression (§5.3) · visibility (§5.4) · fit · budgets
   fail → reject attempt → reseed → fallback (§5.6)
 7 plan.authored_layout = false; report associated with the plan (O2)
```

### 5.1 Coupled placement and routing

Placement and routing are **one search** in plan order (critical path first, breadth-first from
`entry`; optional branches after the critical path is placed and routed). For node N with parent P on
physical edge E (profile F):

1. **Cast:** candidates by role/tags/stratum/depth band, sorted by `piece_id`, weighted-shuffled by
   the cast stream, unused pieces preferred, capped by `candidates_per_piece`.
2. **Transform:** identity, then `mirror_x` if the piece allows it.
3. **Position candidates come from the route, not the other way round.** For P's port and the
   candidate's port, enumerate the leg shapes F allows (straight; L; Z/U), each leg length stepped on
   the grid within `[length_min, length_max]`, lateral offsets alternating ± around `flow_axis`. Each
   leg shape fixes the child's position exactly. The enumeration order is fixed, so determinism comes
   from the stream-shuffled candidate order alone.
4. **Reject a position** if: its footprint (plus one grid cell of margin) overlaps any placed footprint
   or routed ground; any hallway rect comes within one cell of ground it is not meant to join
   (**[C]** abutting patches join — `_touches` is inclusive — so unintended adjacency would silently
   create a passage); the extent limit is exceeded; a VISIBILITY edge involving N becomes unsatisfiable
   (quick projection, §5.4); a mandatory reveal's distance band is violated.
5. **Accept** the first position whose route is clear; commit hallway rects and joints to the draft.
6. **Failure:** no position for any transform of any candidate → pop N and try P's *next position*
   (position and candidate are one search node). The global `placements` budget counts every accepted
   placement, including undone ones.
7. **Cycle-closing edges** are routed once both ends exist; failure backtracks the last node of the
   cycle — a cycle template without its closing edge is a different experience.

A* is **not** the primary router: leg enumeration yields straight runs with deliberate turns, which is
what BRAIN 12–14 ask of a hallway. A* is the fallback inside a leg that must detour around a placed
footprint (turn penalty, per-leg turn cap from the profile); needing it often is a diagnostic.

**Placement RNG, stated precisely.** Three stream-driven choices produce different valid arrangements
from different seeds: which template splices where (plan stream), which piece fills each role (cast
stream), and the order candidate positions are tried within each profile's legal bands (place stream
shuffles the *start* of the fixed enumeration ring, never its contents). Everything else — leg shapes,
lengths, joint placement, routing — is a deterministic function of those choices, so two seeds differ
in arrangement while every arrangement honours the same authored traversal intent (the profile bands,
the mandatory reveal bands, the dependency structure). Re-seeding on failure uses `derive(floor_seed,
attempt)`, so the retry sequence is itself reproducible.

### 5.2 Intentional connective spaces: five TraversalProfiles

| Profile | Intent | Legs | Length | Flanks | Extra |
|---|---|---|---|---|---|
| **APPROACH** | arrive at a destination that owns its reveal: a run, then a turn after which it appears | 1–2 (turn mandatory when the reveal is declared *not-before-the-turn*) | long [M] | ledge default | mouth widens to the port width |
| **LINK** | two spaces that should read as adjacent | 1 | short [M] | per recipe | — |
| **DETOUR** | the optional or objective limb, visibly longer and lateral | 2 | long [M] | ledge | ambient scenery props allowed, never blockers |
| **SHORTCUT** | the return arm of a cycle, closed until opened | 1–2 | short [M] | wall | far joint is a gated connection, `starts_open=false`, `has_barrier=true` |
| **JUNCTION** | a node where ≥3 routes meet: a hallway with three mouths and nothing in it | — | J×J [M] | ledge | — |

APPROACH ties hallway shape to the reveal rule; DETOUR reads as a choice because it is visibly longer
than the LINK beside it at a JUNCTION; SHORTCUT is understood as earned because it is the closed thing
walked past earlier. All numbers are **[M]**, derived from Floor 2's measured corridors (its apertures
are 5 wide **[C]**) and the widest body radius; none is a literal in code.

### 5.3 Progression validation (built in S0 — `game/gen/progression_validator.gd`)

**Three edge sets, three validators.** PHYSICAL is checked by reachability; VISIBILITY by projection
(§5.4); DEPENDENCY by the state search below. They are never merged.

**State (the smallest honest one):** the Envoy's position (as a piece of legal body-centre ground),
connection open bits, trigger fired/enabled bits, props broken, switches revealed/spent, carriables
revealed and located (home / held / dropped-at / inserted), encounter dormant/active/cleared, the
sealing encounter in force. Reachability is computed **from where the Envoy stands**, never from the
entry; ground is cut into cells at occupancy regions, blocking props and obstacles; the search walks
**legal body-centre ground** (each cell eroded by the body, plus the exact strip two adjoining cells
cover together), so a region spanning a corridor is crossed only by firing it, a plate in a wide room
can be skirted, and a strip narrower than a body is passable only where neighbouring ground covers it.

**Supported actions** (each one FloorLayers kind, applied as `SimWorld._apply_floor_effect` applies
it): enter a region/group-occupancy trigger; break a prop from ground in attack reach; hit a *visible*
switch from ground in attack reach; lift a revealed carriable from ground in pickup reach; deliver the
held carriable at an unfilled receiver the Envoy can stand in; clear an active encounter (recorded as an
assumption). An attack-type action while carrying sets the key down where the Envoy stands.

**Outcomes:** PASS (exit reachable by supported actions and, from every reachable state, still
reachable — no softlock; conditional on the listed assumptions); FAIL (unreachable or a softlock, and
no relaxation the model knows of helps); UNSUPPORTED (the answer depends on something the model refuses
to establish: a switch only a shot could reach, ground only a point could walk, an unknown effect kind,
a state budget exceeded). Findings carry the affected ids and the action trace that leads to them.
Progression-neutral records (a scenery prop, an unwatched optional fight) are left out of the state and
**listed** in the report, never hidden.

**Proved against the shipped floors (S0 tests):** Floors 1–4, the Terminal and the Ready Room PASS;
each PASS route replays through a real `SimWorld` to the sim's own `floor_complete`; removing the
crate's enable, the third wave's door, or one Foundry key makes the right floor FAIL with the right
references; negative fixtures show the one-way softlock, the key left behind, the plate skirted vs the
corridor crossed, the sliver a body cannot slip past, and the UNSUPPORTED verdicts.

**Stated limitations (always printed):** enemy bodies and hazards never block or harm; fights are won
when chosen; confinement geometry is not checked; group occupancy is solo; keys are set down only at
action points; switches by melee reach only; a body stands only where one piece of ground, or two
adjoining pieces, cover it. Nothing beyond the supported rules is ever claimed.

### 5.4 Visibility validation (S4)

Inputs are passed in by `DepthGenerator` like body radii (FloorPlan stays autoload-free): camera
offset, pitch, vertical FOV, viewport aspect, edge margins, floor extent — read from the **shared camera
resource** (O1). Per VISIBILITY edge (vantage V, anchor A): camera position = V + offset, clamped by the
same edge-margin rule `FollowCamera` applies, as pure maths pinned by a test against the real node's
`unproject_position` on Floor 2 (`tools/measure_floor2_sightline.gd` is the reference); A must project
inside the safe band [M]; a segment camera→A against obstacle boxes and 2.2-high wall segments must be
clear (approximate, conservative); and A's ground must be unreachable in the initial progression state.

**Reveal ordering, corrected.** Geometric visibility is not a reveal. A reveal is **mandatory** only when
the template also declares a progression relationship the validator can enforce: the destination is
unreachable while the vantage is reachable, and every route from the vantage to the destination passes
through the vantage's piece (the visibility validator asks the progression validator both questions).
A visibility edge without that enforceable relationship is **optional**: generated, checked for
geometry, reported, but never a reason to reject a floor. Vantage and anchor are author-declared ports;
the generator never searches for standing points.

### 5.5 Transform policy and identifier safety

**Transforms.** Pieces: identity unless `allowed_transforms` lists `mirror_x` (O6) — mirroring negates
x, flips rects, swaps `boundary_east/west`, remaps port edges; a piece with camera-sensitive reveals,
asymmetric encounters, switches or hazards simply does not opt in. Connective ground: any cardinal
orientation (it is profile-generated, not authored).

**Identifiers.** The emitter owns renumbering, with a table, never arithmetic: instances are ordered in
plan order and prefixed `iNN`; a per-layer counter allocates dense ids in instance order; a remap table
`(instance, layer, local_id) → global_id` is built before any reference is resolved; every intra-piece
reference is rewritten through it **by its target layer** (`effects[].target_id` via the compiler's own
effect→layer table, `trigger.source_id` via its kind→layer table, `connection.patch_ids`, and
`breakable.conceals_trigger_id`, which the compiler copies verbatim and an offset scheme would miss);
keys become `iNN.KEY`; `@port` references resolve to joint connection ids; an unresolved reference, a
key collision, or a reference into a layer the table lacks is an emit error (structural failure), never
a compiled floor. `exit_console` is one plan field registered under fixed id 0 — unaffected, and the
emitter asserts exactly one exit piece supplies it. Ids are ≥ 0 (−1 is the sentinel). Connective ground
is a pseudo-instance `h` on the same counters.

### 5.6 Failure handling, diagnostics, determinism

| Class | Meaning | Handling | Diagnostic |
|---|---|---|---|
| Rejected candidate | a position or piece failed a placement/routing check | normal search | counted by reason |
| Exhausted attempt | budgets spent, or a validator failed the emitted floor | reseed `derive(floor_seed, attempt)` ≤ `reseeds` | attempt number, failing validator |
| Fallback used | all attempts exhausted | the recipe's authored `fallback` is compiled; `authored_layout = true` | `gen: fallback` line + flag; **counted apart from successes, never a success** |
| Structural failure | emitter invariant broken, validator budget exceeded, unsupported semantics | `push_error`; fallback; flagged separately | `structural = true` |

**Per-floor diagnostics despite preview generation (O2).** `generate` is called for Floor N+1 while
Floor N plays; a single static "last report" would then describe the *next* floor. The report is
therefore associated with its plan by identity — `DepthGenerator.report_for(plan)` keyed on the
`FloorPlan` object (a weak map; the plan is the key, so the preview's report and the installed report
are the same object, exactly as the plan is) — while `FloorPlan.to_dict()` stays untouched. A static
`last_report` may exist for debugging only and is never read by tests or tools.

**Determinism.** One sub-stream per stage; every collection sorted by id before it is drawn from; the
decorate/populate streams never write to the plan; the combat RNG is separate. The same seed gives the
same floor, the same failure class, and the same fallback.

**Spatial invariance vs full equality.** Changing the `populate` salt must leave patches, connections,
triggers, obstacles and markers byte-identical while rosters may differ: the test compares `to_dict()`
with encounter rosters stripped — a comparison, not a claim of `to_dict()` equality.

---

## 6. Prototype and authoring requirements

**Recipe `proto_archive`:** entry → APPROACH → landmark (gated) ; landmark → LINK → junction ;
junction → DETOUR → objective ; objective → SHORTCUT (gated, opened by the objective) → landmark ;
landmark → LINK → encounter → LINK → exit. VISIBILITY: entry.vantage → landmark.anchor (mandatory:
the landmark is unreachable while the vantage is reachable, and every route to it passes the vantage).
DEPENDENCY: objective.unlock → the landmark's gate and the shortcut's gate.

**Explicit, demonstrably solvable experience graph** (the objective is never behind the gate it opens):

```
 entry ──APPROACH──► landmark ──LINK──► junction ──DETOUR──► objective
   ▲ vantage           gate G                                  unlock U ──► opens G, opens S
   └───sees anchor─────┘   ▲                                      │
                           └────────── SHORTCUT S (closed) ◄──────┘
 landmark ──LINK──► encounter (seals, encounter_cleared opens its far door) ──LINK──► exit
 Solvable: entry → junction → objective → U fires → back by S → through G → encounter → exit.
 Dependency holds: G's far side is unreachable in every state where U has not fired.
 No softlock: no one-way exists before U; the encounter seals and reopens on clear.
```

**Pieces (8):** entry ×1 (arrival + vantage port); exit ×1 (pad + console, like the Reward Hall);
landmark ×2 (same ports, different architecture; one opts into `mirror_x`); objective ×2 (a
breakable-revealed plate; a key + receiver); encounter ×2 (one sealing, one ambient). At least two
candidates at three roles plus mirroring give the "meaningful substitutions"; the recipe gives the
cross-piece dependency, the cycle and shortcut, and the camera-constrained reveal.

**Mandatory authored baseline (O5):** `proto_template.tres`, hand-authored from the **same eight piece
bodies** with hand-made hallways, plus a variable-slot variant swapping objective and encounter pieces.
Compared on gameplay quality, variation, authoring effort, implementation complexity and
maintainability — not generation success.

**Authoring.** A piece is an `AuthoredLayout` in local coordinates (the existing `gen_*.py`-style
scratch scripts already produce these) plus its `FloorPiece` wrapper. **Piece lint (automated):** body
⊆ footprint; ports on the footprint edge; port patches touch their edge; rosters ⊆
`StratumConfig.enemy_keys`; territories inside the body; unlock ports name real records; every listed
transform is one the emitter supports. **Standalone play:** a piece is loaded through a generated
*test fixture* — an entry stub joined at its `in` port and an exit stub at its `out` port — so it is
playable in the standalone Arena without itself satisfying whole-floor requirements (an exit plate, a
console, a complete progression).

---

## 7. Staged plan — dependencies, tests, gates

| Stage | Builds | Depends on | Automated | Early falsification |
|---|---|---|---|---|
| **S0** (authorized) | `FloorPlan.violations()` beneath an unchanged `validate()`; `ProgressionValidator` + `ProgressionReport`; tests against Floors 1–4, the hubs, negative fixtures, and a real-sim replay | — | see §5.3 | "the state model cannot express the shipped floors" |
| S1 | `FloorPiece`/`PiecePort`/`FloorDraft`/emitter/renumbering; a hand-written two-piece draft | S0 | emitted layout compiles; ids dense/unique; all five reference kinds remapped (mutant: skip `conceals_trigger_id` → caught); mirror swaps edge styles; hand draft ≡ hand-translated layout | "pieces cannot be composed through the unchanged compiler" |
| **S1 as built** (2026-10-23, pending review) | `game/gen/piece_port.gd`, `floor_piece.gd`, `floor_draft.gd`, `draft_emitter.gd`; pieces `archive_entry_apron` (gate port, crate-hidden plate opens `@out`) and `archive_exit_gallery` (mirror opt-in; plate → sealing fight → revealed switch → revealed key → receiver → exit); baseline `tests/fixtures/floor_s1_baseline.tres` | S0 | `to_dict()` of the composed plan **equals the hand-authored baseline exactly** (B mirrored and placed by hand); S0 validator PASS with the authored route; real-SimWorld replay to `floor_complete`; every reference category remapped by layer, numeric and keyed, with a second piece whose local ids ≠ global ids; mirror reflects rects, points, ports and swaps east/west styles; gate joints need a gap; unintended adjacency, overlapping footprints, unbound ports, lint failures, role counts and stratum mismatch are structured errors with no layout; 17/17 mutants caught | **not falsified**: two pieces composed through the unchanged compiler. Found on the way: a joint's flank style must agree with the hallway's boundary where the aperture's sides coincide with the hallway's sides — `FloorPlan` refuses two styles on one span, so S2's profiles must carry one style for a hallway AND its joints |
| S2 | profiles, leg enumeration, coupled search, fallback; a recipe with no gates | S1 | same seed → identical; N-seed sweep: 0 overlaps/unintended adjacencies, fallback rate, p99 time; diversity metrics | **the hard one:** do routed hallways read as a place? Human look at 3 seeds *before* S3 |
| **S2 as built** (`a4f87dd`, technical PASS 2026-10-23; human gate OPEN, not performed) | `game/gen/seed_mix.gd` (the pinned derivation, autoload-free; `DepthGenerator.derive_floor_seed` delegates), `traversal_profile.gd`, `floor_recipe.gd`, `generation_report.gd`, `floor_composer.gd`; `FloorPiece` gained `depth_min/max`, `weight`, `tags`; `FloorDraft.Joint.rect_index` + `mark()/rewind()`; emitter refuses an ambiguous joint. Content: profiles `approach` (8 wide, 24–40, ≤3 legs), `link` (6, 8–16, 1 leg), `detour` (6, 28–48, ≤3), `shortcut` (6, 12–48, ≤2, wall); six new pieces (landmark rotunda / gallery, encounter pit [sealing, own gate] / lane [ambient], objective crate store / switch vault [own gates]); recipe `proto_archive`: entry →APPROACH→ landmark →LINK→ encounter →LINK→ exit, landmark.side →DETOUR→ objective, objective.out →SHORTCUT→ encounter.side (closes the cycle). Numbers measured first (`ADR-001-S2-MEASUREMENTS.md`). Tools: `tools/compose_floor_sweep.gd`, `draw_composed_floor.gd` (SVG), `composed_floor_playground.tscn` (debug-playable, not on any itinerary) | S1 | 200-seed sweep at depth 1: **200 composed, 0 fallback, 0 structural, 13 reseeded; every composed floor PASSes the S0 validator; 200 distinct spatial signatures; p50 15.5 ms, p90 31 ms, p99 55 ms, max 63 ms**; same seed → identical `to_dict()`; the global and combat streams untouched; an impossible extent backtracks, stays within budget and falls back, reported apart | Machine: not falsified. **Human (the real S2 gate): not yet performed.** Honest reading of the diagrams: the critical path is a straight column of rooms joined by straight LINKs; the APPROACH jog and the side loop are the only lateral events, and mirroring is never reached (identity always fits first). Risk of the rejected "four boxes" reading is REAL on the main line and must be judged by eye |
| **S2.5 as built** (`6d252cd`, committed 2026-10-26 as technical foundation; human gate played: **ITERATE**) | **Diagnosis:** the exit gallery's guards were authored 2.0 and 2.2 from its plate (shipped sealing rooms: never under 5.83 from the activating region's centre) in a 12 × 8 patch (shipped three-roster arenas: 520–616) that also held the switch, key, receiver, console and exit; `SimWorld._activate_encounter` makes the roster present and *active* the same tick with no engagement opener (`_acquire_aggro` arms one; activation does not — fang/ooze carry a 0-tick opener anyway), so a fang in band bites 12 ticks later. Content, not a sim defect; the opener asymmetry is noted for the owner, unchanged. **Changes:** `game/gen/encounter_spacing.gd` — ARRIVAL REACH derived from stats (`EnvoyStats.spawn_reaction_ticks` 15, new) with the activation point at the region's centre, calibrated so every shipped room passes and the gallery fails; `archive_encounter_pit` resized to 20 × 26 (spawns 12.5–15.1 ahead of the plate, a 3 × 3 cover pillar); `archive_exit_landing` (pad, console, urn; `in` + west `side`); the column recipe re-pooled onto the landing (the gallery stays on disk as the S1 baseline fixture); `link_turn` profile (6 wide, 16–32, one bend); recipe `proto_archive_dogleg` (landmark.side →LINK_TURN→ encounter, landmark.out →DETOUR→ objective, objective.out →SHORTCUT→ exit.side, closing). Tools take `--recipe=`; `tools/play_composed_floor.ps1 -Seed N -Recipe R [-Diagram]` | S2 | 200 seeds each: column **200 / 0 fallback / 9 reseeded / p99 52 ms**; dogleg **200 / 0 / 8 / p99 59 ms** (106 ms before the landing's side door moved to its far end); 0 spawn findings on every composed floor of both; every floor PASSes S0; in the dogleg the encounter stands 18–36 off the landmark's axis and the shortcut enters the exit's side on every seed; mirroring still never required. `tests/test_encounter_spacing.gd` (7) and two dogleg tests; mutants 5/5 | Machine: not falsified. **Human (played): ITERATE.** The enlarged arena improved; the dogleg lacked meaningful exploration; the shortcut was unsatisfying; the opening crate-and-plate interaction was trivial and is ruled out. Committed as a foundation (pit, landing, `link_turn`, spacing rule), not as approved player-facing level design; a different topology is not gameplay purpose |
| S3 | ports → effects, gates, shortcut, progression validator in the loop | S2, S0 | dependency holds / solvable on sweeps; mutant: remove the unlock effect → caught; headless walkthrough objective → gate → shortcut → exit. **Experience contract (added after the S2 playtest, 2026-10-23):** (1) a carried key is lifted in one piece and delivered in another, and the shortest route between the lift site and its receiver is at least one DETOUR `length_min` (measured per floor, reported); (2) an objective's unlock acts on a gate in a *different* piece (the shortcut's far door or the exit's side) — an unlock that only opens its own piece counts for nothing; (3) at least one dependency edge makes the player return through or look back at ground already seen (the opened door stands where they have been); (4) the validator's progression trace is scored by PIECES CROSSED between dependent interactions, and a sequence confined to one piece scores zero cross-area progression however many steps it has; (5) `EncounterSpacing` findings reject an attempt like a plan violation, with the reaches supplied as the radii are; (6) the sealing encounter stays a dedicated arena (no key, switch, receiver or exit inside it) | "cross-piece progression is unsafe"; "the floor is a corridor of rooms each solved where you stand" |
| S4 | camera resource (O1), projection + occlusion, mandatory-vs-optional reveals | S2 | projection == real FollowCamera on Floor 2 within ε; a blocked reveal fails; an optional reveal never rejects | "reveals cannot be guaranteed geometrically" |
| S5 | prototype behind a debug itinerary slot; baseline template; goldens; seed policy (O3) | S3, S4 | one golden per recipe (dated); preview ≡ install identity for a composed depth; spatial-invariance test; sweep report | the architecture, against §7.F |

**Playtest gates (human, qualitative — never satisfied by validators):** after S2, three seeds,
one question: "hallways — architecture, or trench/filler?"; after S5, three seeds of the prototype and
three of the baseline, blind order where practical: the frozen sentence verbatim; seen-before-reached;
the earned shortcut; the encounter in the route; seams; seed distinguishability.

**Hard acceptance for S5 (machine):** 0 structural violations; 0 FAIL progression verdicts and 0
UNSUPPORTED on the prototype recipe; every mandatory VISIBILITY satisfied; fallback rate ≤ threshold
[O4]; p99 generation time < 100 ms; diversity ≥ threshold [O4] on an N-seed sweep. **Passing validators
is never gameplay approval.**

**F. Falsification policy.** Three-seed playtests are evidence, not statistics. A failed gate triggers
one bounded iteration (profiles, bands, piece edits — not architecture) and a re-look; a second failure
of the same criterion is architectural: adopt the authored-template-with-slots baseline (which exists by
then) and keep S0–S1, which pay for themselves on authored floors.

---

## 8. Governance, risks, deferred work

**Preserved, not amended:** GAME-RULES §5 M2 ("≥8 distinct room segments", "stratum theme drives segment
pool…") keeps its player-facing meaning; FloorPiece instances are **not** automatically segments, and any
amendment that changes an acceptance criterion's meaning is a separate explicit owner review. ROADMAP
records this ADR (P53); LEXICON records O7's technical terms; CLAUDE.md gains a `content/floors/` row
only when that folder exists (S1); a golden for the prototype recipe is recorded, dated, at S5; the seed
policy is P50 (O3), scheduled with S5, untouched by S0.

**Risks:** routed hallways read as filler (S2 gate); diversity nominal (metrics + human); generation time
under backtracking (budgets + sweep); unintended adjacency creating passages (margin rule + validator);
sim `Vector3.ZERO` sentinels [U] (keep the composed origin outside the floor); melee-through-walls [U]
(triage separately); M3 must *send* plans, not regenerate them (§2 float honesty; `from_dict` deferred).

**Deferred:** piece rotation; non-axis-aligned geometry; authoritative elevation; generated population
(populate stream reserved) and generated encounter design; dressing art; `FloorSequence`; A* as primary
router; multi-key puzzles; timed hazards in the progression model; ground that only three or more cells
cover together.

**Owner decisions still open:** O4's numbers (fallback rate, diversity floor, safe screen band, grid
cell, profile widths/lengths) — all measured first, none proposed here.
