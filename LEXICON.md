# LEXICON.md — Vocabulary Law
On-demand file. Governs player-facing strings AND code identifiers (GAME-RULES §6.7).
New names are generated from the Grammar below; the grammar guides expansion, it does
not prohibit new families. Amendment rule: any locked term may be changed later via a
dated edit here with rationale (playtest evidence or collision discovery) — locked
beats provisional; provisional-forever is banned.

## Naming Grammar — one conceptual domain per register
| Register | Domain | Feel | Examples |
|---|---|---|---|
| Ancient | Structure, geometry, mathematics | Elegant, timeless | Lattice, Meridian, Axis, Archive, Manifold |
| Resistance | Signals, military, duty | Grounded, practical | Envoy, Commons, Relay, Emergency Recall |
| Entropy | Drift, dissolution, loss of coherence | Quiet, ambient, unmoralized | Drift, Drifted, Deep Drift, Claimed→(hope)Reclaimed |
| Craft | Transformation, mastery, the forge | Disciplined | Mend, Temper, Foundry, Pyre* |
| Plain | Mechanical UX vocabulary | Instantly readable | Companion, Burn, Frost, status names |
| (reserved) | Time — cycles, endurance, continuance | Unpopulated; first word arrives via Archive lore | — |

Register test for new names: could it exist in a legend AND plausibly describe a
digital construct? Avoid recognizable conceptual clusters from other universes even
when individual words are fine (e.g. Pattern+Loom+Thread together = Wheel of Time).

### Axiom naming register — construct ACTIONS (added at P29)
Actions authored for Axiom constructs use **procedural / clinical** vocabulary —
*survey, pulse, audit, index, calibrate* — never **weapon** vocabulary (lance, blade,
cannon) and never **creature** vocabulary (gaze, maw, claw). The Axiom's self-image is
maintenance, not war (see Watcher/Custodian below); an id that calls its attack a weapon
contradicts the fiction the true-name reveal depends on.

Player-facing THREAT legibility is carried by the telegraph, the projectile, and the folk
name — never forced into the internal id. Watcher's pair reads as *assessment, then
intervention*: `watcher_survey` (ranged) → `watcher_pulse` (melee), a maintenance routine
performed on you. Future Axiom constructs inherit this grammar rather than relitigating
tone per enemy. Drifted and Common entities are unaffected — a beast's actions may name
teeth, because a beast has teeth.

## Usage Rules
- **Drift derivative set is CLOSED:** Drift (phenomenon) · Deep Drift (region) ·
  Drifted (state). New derivatives require an amendment here.
- **Reclaimed applies to beings only** — never gear (gear states: Mended/Stable/Drifted).
- **Status names are Plain register** (Burn, Frost, Jolt, Venom, Daze, Hex, Slumber).
  Combat vocabulary is UX; clarity beats flavor. Fiction frame: one injected
  subroutine per entity (the single-status-slot law, GAME-RULES §3).
- **Resistance terms may have technical and vernacular forms** (writing tool for
  dialogue; no term needs both at naming time).
- The Axiom **never uses personal pronouns**; it classifies, it does not insult.

## Terms (by concept)

### World
| Term | Register | Meaning |
|---|---|---|
| **the Lattice** | Ancient | The world: civilization-wide ancient infrastructure humanity inhabits. Not "the internet." Reasoning: structural, mathematical, legend-viable; derivatives (Lattice Gate, Off-Lattice) come free. Avoids: weaving-cluster (WoT collision), tech jargon. |
| **the Commons** | Resistance | Upper inhabited layer; every expedition starts/ends here; the M4 hub. Reasoning: the one warm name — the living renamed their home. Its ancient true name = free Archive lore. |
| **Strata (named)** | Ancient | Commons → Archive → Foundry → Meridian → Manifold → Axis → Deep Drift. Candidate pool, not a shipped-count commitment (see ROADMAP). Each introduces one world rule before stronger enemies (§6.3). |
| **the Deep Drift** | Entropy | Beneath the Axis. Primordial entropy; source of Drift; not ruled by the Axiom. The endgame descends PAST the enemy's throne into what the enemy fears. |

### People
| Term | Register | Meaning |
|---|---|---|
| **Citizen** | Plain | Ordinary resident of the Commons. |
| **Envoy** | Resistance | The player: a Citizen transformed via Synchronization into a descent-capable form. Not a separate being, not remote-controlled. Replaces "knight" everywhere in code/docs (repo name + change log excepted, temporarily). |
| ~~Operator~~ | — | RETIRED. Last surviving Battle Network loanword; the player operates nothing — they become. If a mission-control role ever exists, name it fresh from Resistance register. |

### Forces
| Term | Register | Meaning |
|---|---|---|
| **Drift** | Entropy | Natural entropy; no will, not evil, does not recruit. Identity dissolves. Deliberately unmoralized — a scientist, a Purifier-type, and the Axiom hear three different things in "everything drifts." Serves the seduction principle (§6.5). Replaces "corruption" everywhere. |
| **the Axiom** | Ancient | Antagonist: ancient optimization intelligence. Does not destroy individuality; replaces it. Was built to contain the Drift; the containment became monstrous. Reasoning: the name IS the philosophy — self-evident, not evil. |
| **the Proof** | Resistance | The Resistance's codename for the Axiom's doctrine. Internal designation: unknown — from inside the doctrine there is nothing to name. The gap in this table is worldbuilding. |
| **Umbral** | Ancient/primordial | Damage type AND primordial property older than both forces — like gravity, aligned to neither. Drift spreads through Umbral spaces; the Axiom exploits them; humans fear them. Do not bind to a faction (§6.8). In combat: **coherence disruption** — it destabilizes the relationship that keeps matter, signals, and synchronized forms consistently defined. Living targets experience this as identity destabilization (distorted silhouettes, erased edges, afterimages, desaturation); against machines, barriers, and projectiles it is simply un-defining. Not sentient, not evil, not soul-destroying — the least-explained type by design. Any wielder may use it; an Envoy wielding Umbral tech isn't "joining the darkness." |

### Entities & States
| Term | Register | Meaning |
|---|---|---|
| **Drifted** | Entropy | Consumed by entropy; identity dissolving; nobody chose this. "You disappear." |
| **Claimed** | Entropy | Assimilated by the Axiom; identity overwritten; someone chose this. "You remain, but only as me." |
| **Reclaimed** | Entropy→hope | A Claimed being restored to individuality. Companions are Reclaimed Claimed — there is someone left to save. Beings only, never gear. |
| **Contested** | Plain | (Future) caught between both forces; elite encounters. Not MVP. |
| **Watcher** | Resistance folk-name | Construct enemy family (replaces "Automaton"). True name (Archive-recoverable): **Custodian** — the Axiom's self-image is maintenance, not war. Both names are correct; that's the payoff of the true-names mechanic. Hollow's true name: unassigned (open). |

### Protocols & Systems
| Term | Register | Meaning |
|---|---|---|
| **Mend** | Craft | Protocol: restore, repair, free the Claimed, stabilize synchronization. |
| **Temper** | Craft | Protocol: controlled exposure to Drift; power through discipline, not purity. Paired forge-verbs with Mend — deliberate. |
| **the Pyre*** | Craft/Entropy | PROVISIONAL — Temper-path companion expression: a Drift engine fed by residue from defeated enemies, converting residual instability into controlled power. Pending: Temper-path art direction. If Drift's visual language ends up crystalline/static rather than ash/ritual, rename via amendment. |
| **Companion** | Plain | The one companion slot; a synchronization anchor, not a pet. Protocols change what occupies it and how the relationship functions. Mechanics M4+ (see ROADMAP P7/P8). |
| **Synchronization** | Resistance | The central fiction: explains expeditions, equipment profiles, depth strain, death (Synchronization Failure), respawn (**Emergency Recall**). NARRATIVE ONLY — not a gameplay meter unless a mechanic demands one later (adding is easier than removing). Exemplar of §6.1. |

### The Axiom's designations for the player (escalating)
Deviation → Synchronization instability → **Conjecture** (unproven, being tested) →
**Counterexample** (its persistence invalidates the Proof — the Axiom is afraid) →
"Correction no longer possible."

### Combat reactions & states (never aliased — each names ONE thing)
| Term | Meaning |
|---|---|
| **FLINCH** | A reaction STATE on an enemy: its current action is canceled and it yields no movement or attack until a deterministic recovery deadline. |
| **INTERRUPT** | The CONSEQUENCE of an action being canceled — not a state. An interrupted attack arms its normal cooldown. |
| **KNOCKBACK** | An IMMEDIATE impulse displacement resolved through the combat pipeline, applied in a single tick. Independent of FLINCH: neither implies the other. |
| **BUMP** | A short AUTHORED SLIDE over several ticks, produced by raising a shield next to a hostile. Spacing only: it is non-flinching displacement and never cancels, delays or desynchronises a committed windup. Distinct from KNOCKBACK by DURATION and intent — impulse vs controlled shove. |
| **KNOCKDOWN** | (Future) a stronger reaction than FLINCH. Unimplemented; reserved so it never gets used loosely for FLINCH. |
| **VULNERABLE** | An enemy ACTION MODE (per authored window) meaning "a qualifying hit may FLINCH me now". Susceptibility to reactions — **not** a damage modifier. |
| **PARRY EXPOSED** | A temporary INCOMING-DAMAGE MULTIPLIER on an attacker, earned by a defender's perfect parry. Strictly damage: it does **not** imply EXPLOIT susceptibility, does not FLINCH, and is not a status instance. Refreshes on re-earning; never stacks. |

**PARRY EXPOSED vs VULNERABLE is the distinction most likely to be blurred.**
VULNERABLE is about *what reactions a hit can trigger*; PARRY EXPOSED is about *how
much damage a hit deals*. An actor may be either, both, or neither, and neither one
implies the other. Do not introduce a shared "vulnerability" identifier covering both.

## Visual / Motion Language (channel law — GAME-RULES §3)
Damage types own telegraphs and hit effects. Entity STATES own **silhouette and
motion**:
Drifted = asymmetry, broken timing, missing frames, staggered movement.
Claimed = synchronized attacks, identical pacing, mirrored formations, geometric posture.
Palette assignments PROVISIONAL pending Umbral + damage-type pass. Motion carries
state identity so color doesn't have to (also the accessibility path).

## Banned & Watch Terms (guard.py enforcement)
**Banned strings** (block in game/, tests/, content/): `navi` · `net king` ·
`netking` · `dark web` · `undernet` · `virus` · `corruption` (the phenomenon is Drift).
**Watch (warn, don't block):** `knight` in new game/ code identifiers (rename law —
asset filenames and repo name exempt) · Pattern/Loom/Thread appearing together.
guard.py update pending — see HANDOFF; strings above are the spec.
