# ROADMAP.md — Knight Depths
Future work + ideas outside current milestone scope. Milestone status lives in CLAUDE.md.

<!-- TOKEN DISCIPLINE: read ONLY the Index below unless a specific entry is needed —
     then jump to it by id. Append = one Index row + full entry at the bottom of
     Feature Proposals. At milestone completion (mandatory once the Index exceeds
     20 live entries): delete SHIPPED/REJECTED entries, leave a one-line tombstone
     in the Graveyard. Git history is the archive — deletion loses nothing. -->

## Index
| Id | Proposal | Status | One-liner |
|---|---|---|---|
| P1 | Bombs — third weapon class | TREAT-CANDIDATE | Placed AoE/status class; pipeline already carries `class` field |
| P2 | Full status roster | PROPOSED | Frost/Jolt/Venom/Daze/Hex/Slumber, one per playtested iteration |
| P3 | Consumable vials | PROPOSED | Any-build status application + common loot drop |
| P4 | Mender-type enemy | PROPOSED | Enemy healer → kill-priority decisions; justifies Venom |
| P5 | Gear stars, heat, crafting | PROPOSED | M4 progression skeleton, recorded shape |
| P6 | Rotating gate map (arcade) | PROPOSED | M5 shared-world route meta-game |
| P7 | Companion system | PROPOSED | One slot, protocol-determined occupant; sync-anchor fiction; M4+ |
| P8 | Protocols (Mend/Temper) | PROPOSED | Per-run philosophy loadout; expression not access; M4+ |
| P9 | Drift scalar | PROPOSED | Zone `drift: float` in sim drives spawns/presentation; M2-adjacent |
| P10 | Gear states (Mended/Stable/Drifted) | PROPOSED | Mechanical identities per state; content multiplier — earned rollout |
| P11 | Contested enemy state | PROPOSED | Caught between forces; elite encounters, post-M2 |
| P12 | Frames (mobility platforms) | PROPOSED | Combat identities, not transport; maybe a Companion-slot expression |
| P13 | Community world-state | PROPOSED | Shared Drift scalar + thresholds; architect-for at P9, build M5-if-ever |
| P14 | Title decision | PROPOSED | Replace working title from lexicon families; zero urgency |
| P15 | Dodge (own input + i-frame trigger) | PROPOSED | Second §3 i-frame source; must reuse the hit-i-frame timer, never a new mechanism |
| P16 | Shield bump + perfect parry | **TREAT (M1 close)** | SPLIT into two separable mechanics: bump = spacing utility (no timing); parry = mastery layer |
| P17 | Per-family engagement identities | **BURROW PRE-CODE SPEC (FROZEN)** | Weave, scurry and cutoff all falsified and reverted. Positive datum: the LUNGE. Burrow/ambush spec frozen: one participation predicate, fixed-candidate emergence with fail-safe timeout, Stage-1 action-only test |
| P18 | Idle wander + return-to-post + room territory | PROPOSED | Post-disengage idle behavior layer; needs its own RNG stream; M2 |
| P19 | Per-family mass/knockback factor | PROPOSED | Weight scales pipeline knockback only; binds to family, never to state (§6.8) |
| P20 | Sim movement collision/bounds | PROPOSED | No wall/body-blocking exists anywhere; lunge (manual-pass) inherits and exposes it |
| P21 | Arena camera-follow | PROPOSED | Fixed camera doesn't track the Envoy; noted repositioning Watcher for visibility |
| P22 | Buffer eligibility during charge windup | PROPOSED | Scope cut, not canon — a projected `end_tick` is already computable |
| P23 | Graded player poise | PROPOSED | Mirrors `interrupt_strength`; M1 ships unconditional cancel only |
| P24 | Reactions beyond flinch + enemy action phases | PROPOSED | Knockdown, player-side reactions, punishable recoveries; second consumer decides shared infra |
| P25 | Weapon-owned state & switch semantics | PROPOSED | Holstered-state categories, switch-reset tech, ammo/heat — all gated on a real consumer |
| P26 | Ranged weapon identity futures | PROPOSED | Distance bands, committed burst, hazards, marks; identity = changed decision, not new numbers |
| P27 | Multi-hit / attack-instance model | PROPOSED | Re-hit eligibility as a separate question from global health i-frames; incl. cross-attacker suppression |
| P29 | Enemy action repertoire / distance-conditioned selection | **PASS / CLOSED 2026-08-18** | Frozen point `9378316`; follow-ups dispatched to P17/P28/P30/P31/P32 |
| P30 | Wand commitment/reward mechanic | **NEAR-TERM (weapon docket)** | Broadened 2026-08-17; charge vs consecutive-hit empowerment — evaluate before implementing |
| P31 | Reflected-projectile parry | PROPOSED | Breon design intent; must-reconnect + one-reflect-per-raise; needs its own fork review |
| P28 | Global combat-scale coherence pass | RESOLVED for M1 (narrowed) | Was mostly Ooze's undersized footprint, not a global rescale; animation-alignment revalidation still open |

Statuses: PROPOSED → TREAT-CANDIDATE → IN-MILESTONE → SHIPPED / REJECTED.

## Deferred (known, intentionally outside M0–M5 — the standing NOT-list)
- **Economy balance & trading** — auction-house *mechanics* are M5; economy *tuning*
  (sinks, faucets, dual currency) needs real player data a hobby project may never
  have. Design doc only, if ever.
- **Cosmetics/wardrobe, Steam integration, mobile ports, monetization** — irrelevant to
  a hobby built for the fun of building it. Revisit only if the goal ever changes.
- **Full status-effect roster** — M1 ships Burn only (GAME-RULES §3). Shock/freeze/
  poison/stun/curse analogues land one per playtested iteration after M2.
- **Lockstep determinism** — explicitly rejected (GAME-RULES §2 honesty clause);
  server-authoritative model instead. Do not reopen without a written reason.
- **PvP** — M5 candidate; needs M3 netcode to be proven first.
- **Custom level editor** — §1.4 rule of two: hand-author segments in the Godot editor
  until the pain is demonstrated twice.
- **Protocol expansion beyond Mend/Temper** — architecture supports N protocols; the
  design commits to TWO. Each protocol must reinterpret gear+Companion+playstyle
  coherently; that cost is why "why stop at two?" stays parked. Revisit post-M4.
- **Guild bases / guild progression** — M5-if-ever; folded under P13's world-state
  architecture question. Do not design independently.
- **Programmable companion AI + companion personality** — likely the SAME feature
  (P7 notes); post-M4 dream, not a pillar. High cost even before personality.
- **Status renames to lore vocabulary** — REJECTED (LEXICON.md: statuses are Plain
  register; combat vocabulary is UX). Do not reopen without playtest evidence.

## Feature Proposals
(Format per entry: `### P<n> — Title` then Idea / Reasoning / Design questions / Why
deferred. Append at the bottom + add an Index row. Nothing enters milestone scope
without moving through this list.)

### P1 — Bombs — the third weapon class
**Idea:** Placed-explosive weapon class specializing in area denial and status
application (fuse timer, blast radius, status payload — all in data).
**Reasoning:** The reference game's combat triangle is melee/ranged/bomb, and bombs
are its support/control leg — co-op composition gets much richer with a third class.
Weapon resources already carry a `class` field (§3), so the pipeline is ready.
**Design questions:** Fuse in sim ticks vs. contact-triggered? Self-damage? Does the
charge attack change the blast shape?
**Why deferred:** M1 proves the pipeline with two classes; bombs are the first
post-M2 Treat Rule candidate.

### P2 — Full status roster (one per playtested iteration, post-M2)
**Idea:** Frost (immobilize, broken by any damage, bonus damage on natural expiry),
Jolt (periodic Arc spasms that also hit the victim's adjacent allies; interrupts only
during telegraphs), Venom (attack/defense down + blocks all healing), Daze (move +
attack-speed slow, very short), Hex (damage on any ability use; scariest weapons may
Hex their own wielder on charge), Slumber (full disable + regen, broken by damage).
**Reasoning:** Identities translated from the reference game's roster — each status
has a distinct tactical job (crowd control, anti-heal, setup, anti-turtle) rather than
being a reskinned DoT. The single-status-slot law (§3) makes each addition cheap.
**Design questions:** Priority/replacement table values; which statuses enemies may
apply to players in early tiers.
**Why deferred:** Ship one, playtest, ship the next — never batch-add.

### P3 — Consumable vials
**Idea:** Throwable/usable items that apply any status (or cure) regardless of loadout.
**Reasoning:** Gives every build access to tactical statuses and gives loot tables a
useful common drop; pairs with the mender-enemy proposal below.
**Why deferred:** Needs the status roster to exist first.

### P4 — Mender-type enemy
**Idea:** An enemy that heals nearby enemies (visible heal feedback).
**Reasoning:** The single cheapest tactical spice in the reference game — it turns
every encounter into a kill-priority decision. Also creates Venom's (anti-heal) reason
to exist.
**Why deferred:** M2 content addition once 3+ base enemies are proven fun.

### P5 — Gear stars, heat, and recipe crafting
**Idea:** 0–5 star gear rarity, items leveling through use, recipe+material crafting;
armor sets as playstyle identities instead of character classes.
**Reasoning:** The reference game's entire progression skeleton — this is M4's
crafting/heat loop already in CLAUDE.md, recorded here with the mechanical shape.
**Addendum — charge-profile differentiation (captured pre-build, Slice B era):**
weapon lines differentiate by CHARGE PROFILE (the per-hit/charge content-profile
seam Slice B establishes, see `sword_stats.gd`'s SLICE B SPEC comment), and
enhancement/upgrade strengthens or REPLACES a profile rather than just scaling
numbers. Worked example: "Brandish" — a powerful strike PLUS an advancing line of
pushing, damaging, status-bearing impacts — is the second concrete charge shape
(sword_burn_A's single charged strike is the first), and needs its own spec
(interruption, owner-death, per-pulse status, defense-across-waves) once it becomes
real content.
**Addendum — weapon slot count (captured pre-build, Phase D step 8):** the reference
game supports multiple equipped weapon slots (2 base, up to 4) + shield,
cycle-accessible mid-combat. The current `equipped-weapon` + `switch_weapon`
Command architecture (`SimWorld.set_weapon_loadout`/`_apply_switch_weapon`) already
generalizes to N slots — slot *count* is progression content to unlock, not an
architecture change. Do not redesign cycling to add more slots; just register a
longer loadout array.
**Addendum — combo length is a flinch-economy decision, not a weapon-feel decision
(2026-08-11, combat-advisory arc):** under the batch's pressure model, sequence length ×
per-hit damage × cadence × the SHARED pressure window jointly determine how often a
player can access enemy control. A second sword family cannot pick its combo length
freely; it inherits that economy. Content-authoring constraint to apply BEFORE any
second sword line is authored. Keep the pressure window shared/global — per-weapon
windows only if multiple real weapons prove the shared model cannot support their rhythm
(§1.4). Related constraints recorded at the same time: attack-speed modifiers must not
silently alter authored movement or reach (snapshot vs dynamic vs authored timing
semantics get locked before modifiers ship); split/multi-channel damage must not
double-dip generic bonuses; and status value is evaluated in the geometry and timing of
the exact weapon applying it — there is no fixed "status = −X% damage" formula.
**Why deferred:** M4 by design; do not front-load progression before fun is proven.
Charge-profile plumbing itself lands with Slice B (M1); this addendum is only about
progression differentiating BY that plumbing, which stays M4.
**Addendum — M3 delivery requirement for phased attack Commands (Slice B, built this
session):** the sword's combo/charge model sends explicit `attack` phases
(`pressed`/`held`/`released`) rather than inferring transitions from a missing
per-tick Command. That avoids one class of ambiguity, but does NOT by itself solve
transport loss — a dropped `released` (or `pressed`) is still a dropped transition
and would leave `SimWorld._melee_hold` open with no way to resolve it. M3's
server-authoritative model (GAME-RULES §4) must provide reliable delivery/sequencing
for these edge-bearing phases, or a periodic input-state reconciliation mechanism, so
a lost network message can never leave an actor's attack state stuck mid-hold. Not a
concern for M1 (single offline driver, no packet loss) — flagged here so M3 netcode
work doesn't discover it late.

### P6 — Rotating gate map (arcade)
**Idea:** Multiple concurrent descent "gates" whose upcoming floors rotate on a
timer and are previewable, making route planning a meta-game.
**Reasoning:** The reference game's most distinctive structural feature; genuinely an
MMO-layer system since its value comes from a shared persistent world.
**Why deferred:** M5. The M2 next-floor preview is the single-run seed of this idea.

### P7 — Companion system (one slot, many expressions)
**Idea:** Every Envoy has one Companion slot — a synchronization anchor (WORLD-CANON).
The loaded protocol determines the occupant: Mend → a Reclaimed being that grows;
Temper → the Pyre (Drift engine fed by residue from defeated enemies; name
provisional per LEXICON).
**Reasoning:** One architecture, many fantasies — the single-status-slot philosophy at
system scale. §6.2: this is ONE progression loop, deliberately, not three (AI pet +
mount + virus companion collapsed here by design).
**Design questions:** Behavior config depth vs. cost; does personality emerge from
config over time (the "programmable + beloved" unification)? Frames (P12) as
mission-specific slot expressions?
**Why deferred:** Canon now, mechanics M4+ — annotated in WORLD-CANON so fiction
doesn't outrun the roadmap (RISKS #12).

### P8 — Protocols: Mend / Temper
**Idea:** Per-expedition philosophy loadout ("Load Protocol: MEND/TEMPER"), not a
permanent faction. Changes how shared systems behave — Companion expression, gear
interaction with Drift, support-vs-risk flavor. §6.4 governs: expression, not access.
**Reasoning:** Turns the Purify/Purge schism into build identity (the core pillar:
gear defines playstyle); dissolves faction-lock problems; roguelite-native.
**Design questions:** What concretely differs at M4 scope (companion + 2–3 behavior
modifiers is plenty)? Co-op composition effects?
**Why deferred:** Needs Companion (P7) and progression (M4) to exist first.

### P9 — Drift scalar
**Idea:** `drift: float` per zone/run in the sim; presentation derives palette shifts,
music, spawn-table weights, hazard density from thresholds. Headlessly testable.
**Reasoning:** Replaces N boolean world-state flags with one scalar — textbook
sim/presentation split. Single-player first; the community version (P13) is the same
system pointed at a server, which keeps live-events possible without building netcode
now.
**Design questions:** Per-run, per-save, or per-zone-persistent? Threshold table in
config; interaction with typed_damage_ramp. **Rule-of-two guard:** first prove ONE
concrete consumer; do not create a universal Drift scalar merely because several
future systems (spawn weighting, visuals, run exposure, community state) might use
something with the same name — that's a god variable.
**Why deferred:** M2-adjacent — consider during M2 design sessions, after golden-seed
gen exists. Not an M2 gate item.

### P10 — Gear states: Mended / Stable / Drifted
**Idea:** Weapon identities, not rarity: Stable = baseline; Drifted = mechanical
mutation (e.g. 6-hit combo, whiff-stun; doubled parry window, overload on fail) —
challenge, not stat tax; Mended = reliable/synergistic. Drifted gear's downsides are
ARCHITECTURAL, not numeric (e.g. occupies the wielder's status slot, or opens a
type vulnerability) — and Umbral-neutral per §6.8: damage types are never faction
property.
**Reasoning:** Aspirational mastery + the seduction principle (§6.5) made tangible.
**Design questions:** Which weapon gets the first Drifted identity; acquisition path
per protocol.
**Why deferred:** CONTENT MULTIPLIER (RISKS #13) — most weapons ship Stable-only;
states are earned content one weapon at a time, post-M2, Treat-Rule friendly.

### P11 — Contested enemy state
**Idea:** Third state tag: caught between Drift and Axiom influence; elite/miniboss
encounters where both motion languages collide on one body.
**Reasoning:** Free drama from the orthogonal family×state architecture (§3).
**Why deferred:** Needs Drifted+Claimed states shipped and readable first.

### P12 — Frames (mobility platforms)
**Idea:** Combat-identity platforms (spider frame, hover rig, assault walker) —
change movement AND tactics; never "+5% speed," never a gear grind.
**Reasoning:** Concept preserved from the arc; implementation archived. Relationship
to Companion (P7) is UNRESOLVED — do not share a slot or base class without two
concrete overlapping uses (§1.4 rule of two); ownership, animation, collision, and
netcode needs may differ entirely.
**Why deferred:** §6.2 — a fourth loop needs its lifetime cost justified.

### P13 — Community world-state
**Idea:** Shared Drift scalar across all players; community actions move zone
thresholds (merchants evacuate at 0.95, boss appears at 0.68, etc.).
**Reasoning:** "Architect for it, don't build it" — P9's design must not preclude a
server-side source for the scalar; that single constraint keeps this alive for free.
**Why deferred:** M5-if-ever; re-scope with M5 per §5.

### P14 — Title decision
**Idea:** Replace working title "Knight Depths" with a lexicon-family title.
**Reasoning:** Repo name is the last knight standing (LEXICON: exempt, temporarily).
Titles get trademark/collision search before adoption (Lattice and Loom both collide
commercially as bare names).
**Why deferred:** Zero urgency; titles crystallize once the world's language has been
lived in. Explicitly deferred ≠ forgotten.

### P15 — Dodge: own input, sim movement burst, i-frame trigger
**Idea:** A dedicated dodge input (needs its own Input Map action — none exists yet)
that triggers a short sim-side movement burst with a cooldown, and arms the SAME
invulnerability timer the shield/i-frames session built (`SimWorld
._iframe_ticks_remaining`, armed via `_iframe_ticks_on_hit`-style content data in
ticks) — never a second invulnerability mechanism living in parallel.
**Reasoning:** GAME-RULES §3 already says "i-frames on dodge/hit" — the architecture
anticipates this, but this milestone's scope (Phase D step 5) only implements the
"hit" trigger, since no dodge input/command/animation exists anywhere in the repo yet.
This is sequencing against an unscheduled feature, not a scope reduction.
**Design questions:** Dodge distance/duration in ticks; cooldown length; does a dodge
cancel an in-progress block/attack; i-frame duration shared with hit-i-frames or its
own (probably longer) content field.
**Why deferred:** Not part of the shield/i-frame step this session — no input binding
or movement-burst design has been done. First candidate once combo/charge (§3) also
needs revisiting, since dodge likely interacts with combo timing.

### P16 — Shield bump + perfect parry (TREAT, pulled forward at M1 close)
**Status:** the ONE guilt-free out-of-order Treat item (AGENTS.md Momentum Protocol),
chosen 2026-08-13. Still passes /gate; it just skips the queue.

**SPLIT (developer direction, 2026-08-13):** the original entry conflated one timing-
gated mechanic. It is now TWO separable behaviors with INDEPENDENT tuning. The baseline
bump must NOT become timing-dependent — that was the correction.

**1. Shield bump — baseline spacing utility.** Raising the shield while an enemy is
inside a very close authored proximity pushes it away. NO precision timing required:
this is spacing control available to any player, not a skill check. Its own cooldown
prevents holding or re-raising the shield from continuously repelling everything.
Reuses the existing authoritative displacement path (the same knockback resolution the
combat pipeline already owns) — no generic reaction framework.

**2. Perfect parry — mastery layer.** A block landing inside a short timing window
converts defense into a brief offensive advantage. Preferred first payoff: the parried
attacker takes INCREASED DAMAGE for a short deterministic duration. Deliberately ONE
reward — no stun + flinch + damage + meter refund + knockback package. Uses the
narrowest existing damage-modifier seam; no generalized armor/debuff framework invented
for a single consumer.

**Desired shield progression:** normal block = safety · bump = spacing control ·
perfect parry = defense converted into short offensive advantage.

**Foundations that already exist:** `_block_start_tick` (recorded on every READY→HELD
rising edge) gives the parry window its reference point for free; `_contact_distance`
gives bump its proximity test; the knockback pipeline gives bump its displacement; and
flinch's absolute-deadline pattern (`_flinched_until_tick`) is the precedent for the
parry's temporary vulnerability window.
**Why deferred until now:** shield v1 shipped the flat block/break model only; both
layers needed a playtested base to attach to. That base passed its re-gate.

### P17 — Per-family engagement identities
**Idea:** Movement/attack personality translated from the reference game, layered as
CONTENT on top of the shared AI (pursue/engage/leash) built in Phase D step 8 — never
as AI special cases (the locked build-shape rule: attack shape is content; since P29
the AI decides locomotion, whether to attack now, and which eligible authored action to
commit — never how that action behaves).
- **Ooze:** shuffle approach, a visible charge-up, then a hop-attack (windup +
  self-knockback + a wide/360° cone) — a pull-forward Treat Rule candidate if the M1
  replay finds the three families feeling too uniform.
- **Fang:** a pack-call, a reposition beat, and a delayed chomp — needs the
  deliberately-deferred reposition system (Phase D step 8's engagement-spacing fix
  shipped only approach/back-away/stop, no tangential reposition).
- **A slow-advancing undead archetype** with either a charged leap or a ranged
  status-carrying cone attack. Family TBD — Watcher vs. Hollow gets decided at M2's
  enemy-content session, not here. The cone itself is M2-gated regardless of family:
  it needs the first ranged ENEMY attack, the first enemy-applied status, and
  typed_damage_ramp to all exist first (M1 ships melee-only, Force-only enemies per
  the onboarding rule).
- **A turret archetype:** stationary, ranged, tiered (single-shot / tri-cone /
  seeking). Seeking needs per-tick projectile steering toward a moving target — a new
  sim capability; today's projectiles travel in a fixed straight line from spawn.
**BREON'S FANG SKETCHES (verbatim, captured 2026-08-17):**
> zig-zag rush → windup on arrival
> burst lunge → readable recovery → decide

**FAMILY TAXONOMY (captured 2026-08-17)** — the axis each family should express, so
movement identity is authored toward a stated character rather than invented per enemy:
- **Fang** — aggressive, NONLINEAR, committing.
- **Ooze** — area-denial, positional.
- **Watcher** — deliberate; punishable, committed tells.

Note both Fang sketches share a shape P29 does not currently have: movement and attack as
ONE authored beat (arrive-then-windup, lunge-then-recover-then-decide), rather than
movement that stops so an attack can start. That is the same seam the held Watcher
selection trigger points at from the other direction — worth designing together if both
fire.

**Reasoning:** Identities translated from the reference game's roster, same spirit as
P2's status roster — each family becomes tactically distinct rather than a reskinned
pursue-and-hit loop, without adding a second AI code path per family.
**Design questions:** Which family gets Watcher vs. Hollow's true-name slot; how much
of "personality" is timing/cone-shape data vs. genuinely new AI states (reposition,
projectile steering); whether the reposition system Fang needs is worth building
before a second family also wants it (rule of two).
**Why deferred:** M1's AI ships the minimum viable shared engagement loop only
(GAME-RULES §5 M1 gate doesn't require distinct enemy personalities); this is M2
content-pass work once 3+ base enemies are proven fun, per P4's existing "M2 content
addition" precedent.

---

**STATUS 2026-08-19 — FANG WEAVE FALSIFIED AND REVERTED. Successor recon below.**

**VERDICT: ITERATE — weave hypothesis FALSIFIED, P17 finding REINFORCED.** The original
playtest finding (enemy approach feels too uniform) still stands; the weave was the wrong
answer to it, and knowing that is the experiment's return.

**RAW ANSWERS (verbatim):** readable but repetitive · same approach with wobble (Q2 FAIL,
the finding under test) · release hinge PASS · facing acceptable · wand tracking unchanged
(Q5 FAIL) · opener PASS · Q7 unanswered, carried to the successor design.

**WHY IT FAILED, stated once so the successor does not repeat it.** Q2 and Q5 failed
together and they are the same failure: the weave changed the SHAPE OF THE PATH without
changing the DECISION the player faces. Tracking with `wand_A` was unchanged, spacing was
unchanged, timing was unchanged — so a wobble is what was left. Geometry is not identity.

**REVERTED** (a falsified mechanic does not stay in live code merely because it is tested):
the sim expression and its registration/observability surface, all four `FangStats` fields,
the inert copies on Ooze/Watcher, the registrar pass-through, `arena.gd`'s debug export, and
`tests/test_approach_weave.gd`. Verified byte-complete: live behaviour is 294/294 events
identical to `ai_baseline_pre_p29.json` again.

**PRESERVED — the experiment's durable yield, none of it dependent on the mechanic:**
- **GAME-RULES §3 channel-law amendment + §7 row.** A design law is not dependent on its
  first consumer surviving. Families own BASELINE MOTION PATH (spatial); states own MOTION
  RHYTHM/COORDINATION (temporal); orthogonal but composable. The BINDING per-actor
  phase-offset consequence stands and will bind the successor if it is globally phased.
- **The guard's approved-amendment seam** (`scripts/guard.py --amend`) + its 27 adversarial
  checks. Governance infrastructure, unrelated to what it was first used to record.
- **The three-artifact baseline discipline**, including the recorder's inability to
  overwrite the historical fixture.
- **THE RELEASE/STRAIGHTEN FINDING (Q3 PASS) — carried forward as a REQUIREMENT, not a
  suggestion.** The one validated piece: a committed movement must STRAIGHTEN AND SETTLE
  before the next decision, rather than flowing straight into a windup. Any successor
  mobility mechanic must end in a settle beat.

**FIXTURE ROLES after the revert (all three files byte-untouched, roles stated in their
consuming tests):**
1. `ai_baseline_pre_p29.json` — historical evidence, AND once again an accurate description
   of Fang's live behaviour. The second is a FACT, not a restored authority: gating stays
   with the Ooze canary, because re-blessing in reverse is still re-blessing.
2. `ai_canary_ooze.json` — unchanged, still the ACTIVE gate on the shared locomotion path.
3. `ai_baseline_p17_fang.json` — retired to EXPERIMENT EVIDENCE, falsified 2026-08-19. Its
   consuming test documents the verdict and no longer gates; it asserts the evidence still
   shows the weave, so the verdict above stays backed by something.

**§3/§7 PROVENANCE (unchanged, retained).** Approved in-conversation 2026-08-18; applied via
`python scripts/guard.py --amend <manifest> --i-have-explicit-user-approval`; pre `4d4f3471…`
to post `2956edfb…`; delta confined to two hunks; LF-only/no-BOM/UTF-8 preserved.

---

## P17 SUCCESSOR RECON — FANG SITUATIONAL MOBILITY (recon only, nothing implemented)

Target shape: pursue → retreat/denial condition → **scurry commitment** → fast authored
displacement → settle/straighten → fresh decision → bite windup if appropriate.
FENCES: Fang-specific · no generic movement or retreat-detection framework · no Fang
HP/damage/flinch tuning · no Ooze/Watcher changes.

**1. MOBILITY-VS-ATTACK — YES, representable, and the precedent already exists.**
`_bump_slides` (P16 shield bump) is already exactly "a short authoritative multi-tick
displacement that is neither ordinary locomotion nor an attack", and it does **not** touch
`_melee_hold`: its own dict, its own `_advance_bump_slides()` tick phase running *before*
`_decide_ai_commands`, clamping through the shared `_find_earliest_lunge_contact`, and
suppressing the actor's own `move` Command for its duration. Blocked = the slide ends, never
chases. Its progress is counted in STEPS rather than compared against an end tick — a
deliberate anti-off-by-one lesson worth inheriting verbatim.
- Currently player-side only (shield bump), but the machinery is allegiance-agnostic.
- **FORK (rule of two):** bump is consumer #1; a scurry is #2, which is exactly §1.4's
  threshold. Copy the shape a second time (fences-compliant; §1.4 literally says copy twice
  before abstracting) **vs.** extract a shared authored-displacement concept now.
  Surfaced, not decided.

**2. RETREAT SIGNAL — the sim retains NO movement history. The absence IS the finding.**
Per-actor movement state is exactly `entities` (current position), `_move_speeds` (a
constant), and `_facings` (last movement DIRECTION, normalized). There is no previous
position, no velocity, and no history buffer anywhere. `_facings` is the only residue of
motion and it is unusable as a movement signal: magnitude-free, and *also written by attacks*
(`_apply_attack` sets it on any accepted attack). Forks, in ascending cost:
- **(c) failed-closure window** — needs NO new state class: it is P29's existing pattern.
- **(b) distance increasing N ticks while pursuing** — one remembered distance + one
  counter. A *relation*, not a velocity.
- **(a) away-projected player velocity** — requires genuinely new retained per-actor state
  that every other system must then maintain honestly. Most expensive, most general.
**P29 TRANSFER: yes, structurally, and it is the strongest lead.** `_refresh_close_proximity`
stores an honest timestamp of a world FACT, refreshed before every decision branch, never
stamped once and never skipped for what the actor happens to be doing; the episode is then
DERIVED from two timestamps rather than stored as a flag that can desync. "Player retreating
while I pursue" is the sibling fact of "unable to close" and takes the same shape.
- **FENCE COLLISION TO SURFACE:** P29's naming fence says `requires_close_frustration` /
  `close_frustration_ticks` stay deliberately narrow and generalise to a context framework
  **only** when a second real consumer exists. A retreat-triggered scurry would BE that
  second consumer. This is the moment that fence gets tested — flagged, not decided.

**3. TARGETING FORK (surfaced, not decided).**
- **Current position** — what the AI already uses; zero new machinery.
- **Projected position** — needs player velocity, i.e. fork 2(a)'s new retained state.
- **Positional relation ("get in front")** — needs a committed DESTINATION. Note the §3
  interaction: aim is sampled at the FIRE TICK precisely so a windup cannot commit to a
  stale target position. A destination committed at scurry start is the same class of thing.
  Precedent cuts both ways: bump already commits a direction at commit time and never
  re-evaluates — but bump lasts a few ticks, and a scurry would last longer, which is
  exactly the span over which "committed" becomes "stale".

**4. CANCELLATION / FLINCH / RECOVERY — currently UNSPECIFIED, and load-bearing here.**
`_advance_bump_slides()` runs in its own phase and is **not** gated by `_flinched_until_tick`
— the flinch early-return lives in `_decide_single_ai_command`, which suppresses *Commands*
only. So a scurry built on the bump shape would **continue through a flinch** unless
explicitly cancelled. There is no cancellation path for a slide today; bump never needed one
at 1–3 ticks (it is cleared with reaction state, nothing more). A longer commitment makes
these real decisions: does a flinch abort the scurry, freeze it, or let it finish? Does an
aborted scurry consume its trigger episode (P29 ruled consumption-at-commitment for the
survey — a direct precedent)? What arms the cooldown on an aborted one?

**5. NARROWEST CONTENT SHAPE (candidate, Fang-only).** Displacement per step + step count
(inherit bump's counter, not an end tick) · settle/recovery ticks · one trigger parameter
matching whichever fork in 2 is chosen · a cooldown so it cannot chain. The carried Q3
requirement lands here: the settle beat is **not** optional trim — it is the part that
playtested PASS, and it must exist before the fresh decision.

**OPEN FROM THE PREVIOUS EXPERIMENT:** Q7 (multiple Fangs — individual predators, or
accidental coordination?) is unanswered and carries to the successor, along with §3's
binding per-actor phase-offset consequence if the successor is globally phased.

---

## P17 SCURRY v1 — **FALSIFIED 2026-08-19, REVERTED.** Successor recon below.

Spec `8dd504e` · implementation `9691931` (frozen candidate, preserved in history) · verdict
rendered by Breon after single-Fang play.

### RAW PLAYTEST ANSWERS (verbatim)
- **Q1 trigger legibility:** *"It feels like random mobility, should be moving around to get in
  front of where I'm running towards like arc around and get in front of me as to force me to
  change directions or walk into the attack."*
- **Q2 pressure / pre-registered criterion:** *"Kite and fire feels the same level of freeness."*
- **Q3 commitment/counterplay:** *"Didn't really get to test this chase was weak."*
- **Q4 closure amount:** *"No."*
- **Q5 settle payoff:** *"Sure didn't really get to feel it."*
- **Q6 overall identity:** *"No."*

### FORMAL FALSIFICATION BASIS
The criterion was pre-registered before implementation: *falsified if optimal player behavior
is unchanged, regardless of appearance.* **Q2 is that criterion verbatim in play terms.**
Q1/Q4/Q6 reinforce it — the mobility did not read as purposeful pursuit, the spacing change
was not consequential, and Fang gained no distinct approach decision. Q3/Q5 are
low-signal/inconclusive: the chase never generated enough pressure for those sub-beats to
become evaluable.

**NO TUNING.** Trigger delay, speed, step count, authored distance and settle duration cannot
rescue a mechanic that failed its player-decision criterion.

### TRIGGER AUTOPSY (diagnostic only, run against frozen `9691931` BEFORE the revert)
Purpose: ensure the successor does not inherit a blind detector.

**SCOPE, STATED PRECISELY — four claims, no more (correction to an earlier overclaim):**
1. **The P17 scurry v1 EXPERIMENT: FALSIFIED** by Breon, on its pre-registered
   player-decision criterion.
2. **The DETECTOR: specifically FALSIFIED** by the autopsy below. Rejected for this
   consumer; must not be tuned or reused.
3. **The RAPID-CLOSURE RESPONSE: SUPERSEDED / UNPROVEN — not independently falsified.** It
   was never exercised under a detector that recognized representative kiting, so no verdict
   on the response itself is available. It is superseded by the clarified design target.
4. **`9691931` is preserved as a DORMANT FALLBACK:** rapid-closure-with-a-working-detector,
   live again if the cutoff experiment later falsifies.

An earlier draft of this entry asserted that the dash would have failed even under a working
detector. No evidence supports that claim; it is withdrawn, and no equivalent claim may be
written back in. Claim 3 above is the whole of what is known about the response.

**BANKED FINDING:** *Retreat is not equivalent to increasing radial distance. Cutoff behavior
cares about sustained player travel direction.*

**WITHDRAWN CLAIM (2026-08-20).** After a scurry-build play session the agent reported that
the arena log contained "zero scurry events" and offered it as live-play corroboration of the
autopsy. **That reasoning was invalid and is withdrawn.** `arena.gd::_report_events` had no
case for any scurry event kind, so the log could not have contained one regardless of whether
the mechanic fired. The same hole was then found for the cutoff kinds, which is what prompted
the audit.

This withdrawal touches NOTHING else. The scurry verdict was Breon's human judgement, not
derived from logs, and the autopsy stands on the 886/900 refresh measurement and the cos45deg
arithmetic -- both independent of arena logging.

**BRAIN CANDIDATE, riding with the P17 closeout (not promoted, gates nothing):**
*"Absence from a channel is evidence only if the channel can observe the event."* Before
treating a silent log, an empty result set or an unfired assertion as information, verify the
observer could have recorded the thing whose absence is being read. Related to the existing
"a measurement must prove its mechanism fired before its numbers mean anything" -- this is its
negative-space twin, about absence rather than presence.

900 ticks (30 s) per run. Authored trigger: `separation >= 2.5` AND `elapsed >= 45`.

| path | firing | minimum refreshes | max separation | max elapsed | commits |
|---|---|---|---|---|---|
| radial retreat | no | 3 | 2.53 | 76 | 2 (first @77) |
| radial retreat | yes | 5 | 2.53 | 76 | 2 (first @77) |
| diagonal-45 retreat | no | **886** | **0.00** | **1** | **0 — NEVER FIRES** |
| diagonal-45 retreat | yes | **886** | **0.00** | **1** | **0 — NEVER FIRES** |
| circling / strafing | no | 96 | 0.09 | 18 | **0 — NEVER FIRES** |
| circling / strafing | yes | 96 | 0.09 | 18 | **0 — NEVER FIRES** |

**CLAIM CONFIRMED: the signal measured RADIAL SEPARATION; the behavior we care about is
SUSTAINED DIRECTIONAL TRAVEL.** The cause is arithmetic, not tuning — compare the RADIAL
component of player travel against Fang's 3.00 u/s:

| player behavior | radial speed | result |
|---|---|---|
| straight retreat | 4.00 | gains 1.00 u/s — minimum stops improving, trigger can arm |
| diagonal-45 retreat | 4.00 × cos45° = **2.83** | Fang **GAINS** 0.17 u/s — minimum improves nearly every tick |
| circling | **0.00** | Fang **GAINS** 3.00 u/s — minimum improves constantly |

At 45° the minimum refreshed on **886 of 900 ticks**, resetting BOTH terms continuously. The
Fang perceived *retreat → reset → retreat → reset*; the player experienced one continuous
kite. Only pure radial flight — the one kite shape no player uses exclusively — could ever
arm it. Firing changed nothing (flinch-clearing added 2 refreshes on the radial path and no
commits anywhere), so the blindness is **geometric, not reaction-driven**.

This independently explains Q1 ("random mobility"), Q3 ("chase was weak") and the difficulty
of evaluating the committed line: commitments appeared only during incidental pure-radial
moments, disconnected from what the player felt they were doing.

*Reproducibility: the finding above is analytic (the cos45° arithmetic) and re-derivable
without tooling. The empirical harness ran against `9691931` and was not committed, since a
diagnostic for a deleted mechanic is dead code.*

*Note the autopsy's limit: it proves the detector never armed under realistic kiting. It says
nothing about how the dash would have felt had it armed correctly, and no such claim is made.*

### CORE DESIGN CLARIFICATION (Breon)
Fang should not merely **close the current gap**. Fang should **CONTEST THE PLAYER'S CHOSEN
MOVEMENT DIRECTION** — arc toward the space ahead of the player's travel, get in front of the
route, and force a redirect, an evade, a defensive tool, or a walk into the attack.

Not *"faster object chasing current coordinates."* Instead: **"predator trying to cut off your
route."**

### PRESERVED (independent of the mechanic)
Pre-code spec discipline · this verdict and its raw answers · the autopsy evidence above ·
the C.1 bump/flinch agency ruling and its regression test · GAME-RULES §3 channel-law
amendment · the guard's approved-amendment seam and its 27 adversarial checks · the
three-artifact baseline/evidence discipline · both BRAIN lessons.

### REMOVED FROM LIVE CODE
Six content fields (Fang + inert copies), all runtime state, both events, the observability
export, the registrar pass-through, the test file, and the diagnostic tool. No dead tuning
knobs and no dormant runtime seams left behind merely because they were tested.

---

## P17 CUTOFF — **FALSIFIED BY PLAY 2026-08-22, REVERTED.** Burrow pivot below.

Spec `d070b63` · implementation `43c597e` · frozen play candidate `a2c00aa`.

**VERDICT (Breon, verbatim):** *"It just looked like running a football route — couple yards
up, diagonal cut to a point. Didn't look or feel good."* He did not voluntarily redirect
because of the incoming cutoff. The pre-registered player-decision criterion failed.

### EVIDENCE SCOPE — narrow, and the narrowness matters
Log evidence from the human session: **3 `cutoff_committed`, 3 `cutoff_ended`, 0
`cutoff_aborted`, all three ending `budget_spent`.** Therefore established:
- the detector fired during real representative play — the mechanic actually participated;
- geometric side selection was active (both signs observed, not defaulting to the tie);
- Breon meaningfully experienced the authored lateral-leg → diagonal-run grammar;
- **none of the three executions reached its committed lead point.**

**THE SHIPPED BOUNDED CUTOFF BEHAVIOR WAS PLAYTESTED AND FALSIFIED. Lead-point arrival
itself remains untested.** Do NOT record "the full intended lead-point arrival was tested and
rejected" — it was not. Do NOT downgrade the experiment to "untested" either: the capped
movement was the actual candidate played, and the two-segment locomotion grammar was visible
enough to render a human verdict on.

**NO RETUNE.** `cutoff_max_steps` must not be raised to force arrival. The complaint is
upstream of completion distance — the two-segment locomotion GRAMMAR read as an artificial
football route. A larger budget extends the same rejected grammar. The three-for-three
`budget_spent` result is important evidence about the experiment's CONSTRUCTION; it does not
reopen the verdict. If cutoff geometry is ever historically revisited, the budget limitation
must be considered then — it is not a reason for another cutoff iteration now.

**STATUS: recoverable historical evidence, NOT a dormant fallback.** Unlike the scurry, the
cutoff is not an active alternate design candidate.

**SCURRY's scope stays separate and must not be merged with the above:** experiment falsified ·
radial detector *specifically* falsified · rapid-closure response never independently tested
under a working detector · `9691931` may remain a dormant response fallback if future evidence
specifically justifies revisiting rapid closure.

### POSITIVE DATUM — the one thing P17 has proven likeable
**Breon, verbatim: *"I kind of like the lunge."*** Interpreted NARROWLY: the LUNGE has
positive human evidence, so *discrete committed authored displacement* is a promising
direction. This is NOT a universal rule that all committed displacement is good — two
committed-displacement mechanics have already been falsified. What the lunge shares with the
burrow proposal is the shape: **commit → strong authored movement/state change → readable
resolution.** That makes the pivot evidence-informed rather than an arbitrary fourth pursuit
experiment.

### BRAIN CANDIDATES riding with the P17 closeout (recorded, not promoted, gating nothing)
1. **"An authored movement budget must permit the representative trajectory the experiment
   claims to test."** A bounded movement experiment can be mechanically correct yet terminate
   systematically before completing its authored objective. If that is calculable from
   representative trigger geometry *before* play, verify the budget rather than discover
   three-for-three truncation during the human run. **Scope:** this does NOT claim truncation
   caused the falsification — Breon rejected the grammar itself. It concerns experimental
   VALIDITY: prove a bounded action can complete the representative trajectory it claims to
   expose, so the human knows whether they are judging the complete action or a systematically
   truncated form.
2. **"Validate an action before validating its selector."** Scurry showed action quality and
   selector quality can entangle: its detector failed to recognise representative play, so the
   response was never cleanly exercised.
3. *(earlier)* **"Absence from a channel is evidence only if the channel can observe the
   event."**

---

# P17 SUCCESSOR — FANG BURROW v1 · **PRE-CODE SPECIFICATION (FROZEN)**
**APPROVED · NOT IMPLEMENTED at time of writing.** Committed before code so the design is a
fixed target the implementation is measured against.

Fang performs a LARGE BACKWARD JUMP, disappears into the ground, relocates, POPS UP AROUND the
player — ideally behind — pauses briefly as it emerges, then attacks. The identity is a MODE
CHANGE: ordinary engagement → conspicuous disengage → temporarily absent from the combat
picture → reappear → forced target reacquisition → resume combat. The player's problem moves
from *"How do I maintain my kite route?"* to **"Where is the Fang going to reappear, and how do
I respond when it does?"**

Evidence-informed rather than arbitrary: it shares the shape of P17's one positive datum
(*"I kind of like the lunge"*) — **commit → strong authored movement/state change → readable
resolution.**

## STAGE 1 CRITERION (frozen before implementation)
**Burrow passes only if it changes what Breon pays attention to:** the
backward-jump/disappearance/emergence sequence must make him meaningfully REACQUIRE and RESPOND
to Fang rather than continue solving the same frontal engagement. **Verdict is Breon's alone.**

FALSIFIED if it reads as random teleportation · unavoidable behind-you damage · disappearing
only to waste time · cosmetic movement around the same old engagement problem · or a move that
does not change what the player pays attention to.

## STAGING (binding)
- **Stage 1** — controlled, dev-triggered burrow ONLY: jump → disappear → underground → emerge
  → reacquisition beat. Tests mobility and reacquisition. Explicitly NOT gate state, since the
  trigger export must be on. Action-quality verdict.
- **Stage 2** — only after Stage-1 survival: deliberately orchestrate a normal post-emergence
  attack to judge "emerge then attack" fairness.
- **Production burrow stores no Bite/attack target, in either stage.**

PROCESS RULE: *validate an action before validating its selector.* No normal-AI burrow
selection is designed until Stage 1 passes.

## 1. COMBAT-PARTICIPATION FACT — one predicate (ruled)
```
_combat_absent[actor_id] = true    # while not participating; absence from the dict = present
```
**One line into `_is_valid_target`** covers all four consumers at once — melee sweep, projectile
sweep, authored-displacement contact clamp, shield-bump targeting — because they all filter
`_families.keys()` through that single predicate.

TARGETABLE and COLLIDABLE remain **conceptually distinct dimensions, physically fused for v1**.
Burrow needs both OFF together, so splitting identical APIs now would be speculative semantic
surface. **Split when the first real consumer requires different answers.**

| Bypass seam | Ruling | Cost |
|---|---|---|
| `_advance_status_ticks` | **Burn CONTINUES underground** | zero |
| `_advance_contact_spread` | **spread does NOT occur** | one filter term |
| `_cleanup_stale_contact_pairs` | submerge explicitly terminates episodes | one loop at submerge |
| `_decide_single_ai_command` | ordinary AI suspends | one early return |
| pressure (`_record_pressure`/`_pressure_sum`) | **ages normally** across the trip | zero |
| `_apply_attack` | **fail-closed guard**: an absent actor resolves no attack | one guard (belt to the suspended-AI brace) |

Presentation mirrors authoritative participation: `TargetBody` collider + visibility are driven
from the sim's events, never independently. That collider is **dimension 5 — the one no sim gate
can reach** — so the mirror is a cross-layer contract, pinned by test.

## 2. LIFECYCLE
`jump → underground → (emergence attempts) → reacquisition beat → erase, fresh ordinary decision`

Advances in its **own authoritative tick phase** beside `_advance_bump_slides`. Ordinary AI is
suspended underground, but **the burrow lifecycle keeps advancing authoritatively.** Death can
terminate it at any point. Windup committed before burrow is cancelled at submerge via the
existing `_cancel_enemy_windup`.

**JUMP INTERRUPTION:** ANY successful authoritative FLINCH aborts the self-propelled backward
jump, whether it arrived by EXPLOIT or PRESSURE — hooked on the successful-flinch test
(`flinch_reason != ""`), NOT on the deadline-write test used by the two prior mechanics. Those
differ when a flinch lands on an already-flinched actor. Remaining jump movement is FORFEITED,
and **Fang never transitions underground from an aborted jump.** Deliberately does not inherit
P16 bump's continue-through-flinch: bump is imposed motion, this is chosen motion.

## 3. DEATH UNDERGROUND
Underground the Fang cannot be hit at all, so **health reaching zero underground is reachable by
exactly one route: Burn DoT**, which continues by ruling. Not a general case.

Behaviour: death resolves immediately · burrow terminates permanently · **no emergence** ·
normal `died` event · normal death cleanup clears burrow and combat-absence state · no new event
kind · **no special corpse/emergence presentation invented.**

**Recon'd presentation consequence, recorded not solved:** `arena.gd`'s `died` handler
`queue_free()`s a node that is already hidden, so a Burn kill on a burrowed Fang is **visually
silent** — no corpse, no emergence, it simply never returns.

## 4. EMERGENCE — fixed candidate set, retry window, fail-safe death
```
relation     = player_position_at_commit - burrow_entry_position
far_side_dir = normalize(relation)
emerge_point = player_position_at_commit + far_side_dir * burrow_emergence_radius
```
Player position and destination **COMMIT AT BURROW ENTRY.** No underground retargeting, no
blind-spot homing. Player movement after the tell may make emergence less ideal — intended
counterplay.

**DEGENERATE CASE** (`length(relation) < ε`, ε a named constant): fall back to **opposite the
authored backward-jump direction** — already committed state at that moment, and "came up the
far side from where I leapt" is coherent. No RNG, and no multi-Fang de-correlation through the
fallback.

**CANDIDATES:** the far-side direction rotated by a FIXED list — **0°, ±60°, ±120°, 180°** —
tested with the existing contact-distance geometry. No search, no pathfinding. Open-arena scope
only; rooms do not exist yet.

**RETRY WINDOW:** from the underground deadline, re-check all six candidates **every
authoritative tick** until `burrow_emergence_retry_ticks` expires. **Fang must never knowingly
emerge overlapping a collidable actor.**

**TIMEOUT FAIL-SAFE** (a supposedly unreachable open-arena condition, NOT a tuning mechanic):
if the window expires with no valid candidate — no emergence · **Fang dies authoritatively
underground** · normal death cleanup clears burrow + combat-absence · normal `died` event · a
LOUD WARNING naming `burrow_emergence_timeout` as a v1 scope/invariant failure · no special
corpse presentation. The alternative — leaving a living Fang combat-absent for the rest of the
encounter — risks an encounter soft-lock, which is strictly worse than a diagnosable death.

## 5. POST-EMERGENCE
Reacquisition beat completes → **fresh ordinary AI decision** → existing Bite/lunge logic
handles what is appropriate now. No attack target carried underground; existing selection and
fire-time aim law remain authoritative. **Burrow earns position; it does not guarantee damage.**
No damage merely for emerging.

The beat's PURPOSE is banked, not its duration: the player must be able to perceive *"There it
is"* and then locate, turn, reposition/dodge, shield, or apply control. **Categorically unlike
the scurry and cutoff settle beats**, which had no demonstrated player-facing purpose; this one
has an explicit informational function.

## 6. EVENTS — two kinds, both audited
| Kind | Purpose | Audit decision |
|---|---|---|
| `burrow_submerged` | presentation hides + disables TargetBody | printed |
| `burrow_emerged` | presentation shows + re-enables at the new position | printed |

`burrow_jump_started` is **dropped** — no presentation consumer yet. Abort and death emit no new
kinds. **Every new emitted kind must receive a printed-or-explicitly-passed decision in the
retained event-report completeness audit; no unclassified emitted kinds.**

## 7. PROVISIONAL NUMERIC PACKAGE (all PROVISIONAL/UNVALIDATED, outside the M1 numeric fence)
| Field | Value | Reasoning |
|---|---|---|
| `burrow_jump_distance` | 4.0 | more than a second of ordinary movement, delivered fast — a conspicuous disengage |
| `burrow_jump_step_distance` | 0.35 | 10.5 u/s over ~12 steps (0.4 s) |
| `burrow_underground_ticks` | 40 | 1.33 s — long enough to lose track, short enough to avoid "disappearing to waste time" |
| `burrow_emergence_radius` | 2.0 | just outside bite range (1.65), so engaging still costs a step |
| `burrow_emergence_retry_ticks` | 60 | 2.0 s fail-safe window; a transient blockage clears well inside it |
| `burrow_reacquisition_ticks` | 24 | 0.8 s — deliberately longer than the 12-tick bite windup, so response is possible rather than merely visible |
| `burrow_cooldown_ticks` | 240 | production only; Stage 1 is dev-triggered |

## 8. TESTS
**Participation:** absent Fang unhittable by melee · unhittable by projectile · in-flight
projectile continues and expires normally · not bump-targetable · does not clamp authored
displacement · **Burn continues ticking underground** · **contact spread does not occur** ·
submerge erases contact pairs and post-emergence spread works · stored pressure ages normally ·
`_apply_attack` fail-closed for an absent actor.

**Lifecycle:** jump aborts on EXPLOIT flinch · aborts on PRESSURE flinch · an aborted jump never
submerges · remaining jump forfeited · AI suspended underground while the burrow lifecycle keeps
advancing · **Burn death underground fires `died`, erases burrow, and no emergence follows** ·
death cleanup clears participation and burrow state.

**Emergence:** far-side geometry · degenerate fallback uses the jump direction · occupied primary
rotates through the fixed candidate set · **all candidates blocked before deadline → remains
underground, no overlap** · **a candidate becoming free → deterministic emergence** · **deadline
expires → no materialization, normal authoritative death, burrow cleared, warning emitted, no
later emergence** · never overlaps a combat body · determinism across identical runs.

## FENCES
No generic teleport framework · no generic phasing framework · no steering/pathfinding · no
route prediction · no damage on emergence · no guaranteed Bite inside burrow · no continuous
underground homing · no Ooze changes · no Watcher changes · no multi-Fang coordination · no
normal-AI selection or repertoire tuning before a Stage-1 PASS · the human fun verdict remains
Breon's authority.

### P18 — Idle wander + return-to-post + room territory
**Idea:** Three related post-disengage behaviors, captured together since they all
sit on top of the same M1 disengage-in-place mechanic (Phase D step 8 pre-gate fix
pass — no universal return-to-spawn; an idle enemy just stands at its re-anchored
position):
- **Bounded idle wander** — the first AI behavior that needs genuine randomness.
  Must draw from its OWN dedicated `RandomNumberGenerator` stream per GAME-RULES
  §1.3, never `_combat_rng` (BRAIN's existing "one draw site" invariant for that
  stream extends naturally: a new behavior needing randomness gets a new stream,
  it never reaches for an existing one).
- **"Return-to-post"** — an authored FAMILY TRAIT (some enemies patrol back to a
  post-disengage anchor, some don't), not a universal rule reinstated. A natural
  fit for Watcher/Custodian specifically, per the motion-language law (WORLD-CANON/
  GAME-RULES §6.8): Claimed states share rhythm/synchronized pacing, and returning
  to a post reads as disciplined/synchronized in exactly that way.
- **Room/encounter-based territory bounds** — once M2 floor generation exists,
  leash/detection radii graduate from "distance from an anchor point" to "bounded
  by the room/encounter the enemy was placed in." The current anchor-point model is
  the correct M1 placeholder, not a design to defend past M2.
**Reasoning:** All three are the natural next layer once M1 proved the minimal
disengage-in-place model works; none of them belong in M1 (GAME-RULES §5 M1 gate
doesn't ask for idle personality or floor-aware territory, and M1 has no rooms yet
for the third item to even attach to).
**Why deferred:** M2 — wander/return-to-post are content-pass work like P17 (may
even land in the same session); room-based territory is gated on M2 floor
generation existing at all.

### P19 — Per-family mass/knockback factor
**Idea:** A per-family mass/knockback-resistance factor, applied ONLY at the shared
hit-knockback resolution point in the combat pipeline — never to self-movement,
scripted movement, or (until deliberately tested) shield-break recoil. A heavy
family gets pushed less by the same hit; a light one gets pushed more.
**Reasoning:** Own front door, not folded into an existing proposal, because it's a
genuinely separate mechanic from engagement AI (P17) or charge profiles (P5
addendum) even though it shares the combat pipeline with both. Weight binds to
FAMILY/body archetype, never to entity STATE (Common/Drifted/Claimed) — GAME-RULES
§6.8's three-axis law: a Claimed Fang is still light. Any future state-based
displacement resistance is a deliberate state modifier, decided at M2's state-
content pass, not an accidental side effect of this factor.
**Design questions:** Where the factor lives in content (per-family stats resource
vs. a new shared table); whether shield-break recoil ever adopts it, and if so
under what evidence.
**Update (2026-08-11, combat-advisory arc): SECOND CONSUMER CONFIRMED** — knockback
resistance/weight is now wanted by two independent mechanics, which satisfies this
entry's own trigger condition: (1) melee sequence coherence — knockback from an early
combo hit can push a target out of reach of the next authored hit, and (2) ranged
follow-up range — the same displacement walks a target off a repeat-fire weapon's line
(the shipped `wand_A.knockback_distance = 0.0` is that problem already solved by
deletion rather than by weight). Still NOT in the post-gate combat batch — recorded so
the trigger isn't re-litigated later. No family-specific hacks in the meantime.
**Why deferred:** trigger met, but sequencing puts flinch first — flinch changes how
often knockback even matters, so tuning weight before it would be tuning against a
baseline about to move.

### P20 — Sim movement collision/bounds
**Idea:** Authoritative movement collision in sim/ — arena bounds (walls) and
body-blocking between actors. Confirmed by direct read this session: `_apply_move`
is unconditional `position += direction * speed * dt`, and nothing in the codebase
(sim or presentation — the Envoy's CharacterBody3D never calls `move_and_slide`/
`move_and_collide`) constrains movement at all today.
**Reasoning:** Manual-pass forward lunge (GAME-RULES §3) inherits and exposes this
directly — a lunge is authored displacement with the exact same lack of constraints
ordinary walking has, so it can carry an actor through a wall or through another
actor's body just as easily as walking already can. Recorded explicitly as a known
M1 limitation rather than solved inline (see HANDOFF).
**Update (2026-08-05):** the lunge-vs-hostile-contact pass-through case specifically
is now fixed (`SimWorld._find_earliest_lunge_contact`/`_contact_distance`) —
authored attack movement clamps to a living hostile's combined-combat-radii contact
distance, sharing one formula/epsilon with Burn's contact-spread. This is
attack-authored movement semantics, not a general collision layer: ordinary
walking, enemy movement, walls, and actor-vs-actor separation in general remain
exactly as unconstrained as before. **P20 stays fully open** for all of that — this
was a narrow, lunge-specific fix, not a down payment on general collision.
**Design questions:** Wall bounds first (arena is currently a flat 40x40 box with no
interior geometry, so this is moot until M2 floor generation adds walls) vs.
body-blocking first (relevant now, three enemies + Envoy can already overlap);
whether this lives as a generic sim-side collision pass or per-system clamping
(movement, lunge, knockback each currently free-write `entities[actor_id]`).
**Ally-separation question (open, raised by the lunge-clamp fix):** the lunge clamp
deliberately never targets allies (`_find_earliest_lunge_contact` is hostile-only,
matching the existing hit-detection ally filter). Whether allies should ever push
apart from each other — a co-op-relevant question once multiple players share the
arena in M3 — is undecided and NOT answered by this fix; it's a separate future
design call, not folded into general body-blocking above by default.
**Why deferred:** No wall geometry exists yet to make bounds meaningful (M2 floor
generation gates that half); body-blocking has no trigger yet beyond "it looks odd"
— revisit if playtesting finds overlap actively hurts readability/fairness, or when
M2 floor generation lands and walls become real.

### P21 — Arena camera-follow
**Idea:** The M1 arena's `FixedCamera` doesn't track the Envoy — noted this session
while repositioning Watcher's station specifically because its old position sat
outside the fixed camera's forward view entirely.
**Reasoning:** A camera that doesn't follow the player becomes a real usability
problem the moment the arena is large enough for the player to walk off-frame (the
40x40 geometry fix already makes this plausible at the perimeter stations).
**Why deferred:** M1's fixed framing is sufficient for the current combat-slice
testing footprint; not worth the scope now. Revisit if the manual re-pass finds
perimeter-station movement walking the Envoy off-frame.

### P22 — Buffer eligibility during charge windup
**Idea:** Extend the mid-swing input buffer (built alongside the lunge/windup
pending-attack record) to cover the `windup` state too, buffering a press against a
PROJECTED `end_tick` (`windup_end_tick + charge_profile.lunge_duration_ticks`)
rather than today's rule where any press during windup is unconditionally rejected
`mid_swing`.
**Reasoning:** The projected deadline is already computable with existing fields —
this is a scope cut for engineering-complexity reasons (another branch in an
already-dense state machine), not a technical wall. Recorded explicitly so "charge
windup can't buffer" is never mistaken for a design law later.
**Why deferred:** No evidence yet that it's needed — the third manual-pass round's
re-pass found no complaints about mid-windup presses feeling dropped. Revisit if a
future playtest surfaces windup-press frustration specifically.

### P23 — Graded player poise
**Idea:** Mirror the existing player-interrupts-enemy `interrupt_strength` mechanic
in the other direction — enemy attacks would need a threshold to interrupt a
player's pending windup/executing attack, instead of today's M1 rule where ANY
non-lethal hit cancels unconditionally.
**Reasoning:** The lunge/windup pending-attack system (third manual-pass round)
ships player poise as a deliberate M1 simplification, not a permanent design law —
see `SimWorld._resolve_hit_on_target`'s interrupt-site comment and HANDOFF's
"Manual-pass follow-up session" note. **Trading-feel evidence:** the manual re-pass
on this round (2026-08-05) explicitly watched for "trading during lunge feels
terrible" and reported no new findings — no complaint surfaced. That's one data
point against urgency, not a verdict; a longer/less scripted playtest could still
surface it.
**Why deferred:** No evidence of a problem yet (see above); building graded poise
speculatively would be exactly the kind of future-proofing AGENTS.md warns against.

### P24 — Reactions beyond flinch + enemy action-phase structure
**Idea:** Everything in the reaction space the post-M1 combat batch deliberately does NOT
build, kept together because they all wait on the same evidence (does flinch prove fun?):
- **Knockdown** — the next reaction after flinch. Its arrival is the SECOND consumer that
  triggers evaluating shared reaction infrastructure; until then flinch stays a concrete
  actor state, not a framework (§1.4 rule of two).
- **Player-side reactions** — future design space. Do NOT generalize the enemy FLINCHED
  state to cover the player now; player poise is its own proposal (P23).
- **Enemy action-phase structure, incl. punishable recoveries** — M1 enemies have exactly
  ONE authored phase: a windup (`_ai_attack_start_tick`/`_ai_attack_fire_tick`), then an
  instant resolve. There is no recovery phase to make vulnerable, no multi-phase action
  object, and no authored displacement inside an action. The batch's per-action
  VULNERABLE window therefore lands as an offset pair inside the windup only; "bait the
  attack, punish the recovery" needs this proposal first.
- **Two disjoint vulnerability windows** in one action — deferred until an enemy needs it;
  the batch ships base-mode-outside / interval-overrides-to-VULNERABLE, which already
  expresses protected-early/vulnerable-late as base PROTECTED + a late interval.
**Reasoning:** the batch's flinch system is the first reaction this project has ever had.
Every item here is a second or third instance of a pattern with exactly one instance.
**Why deferred:** all of it is gated on the batch playtest answering "is being able to
control an enemy's actions fun, and at what frequency?"

### P25 — Weapon-owned state & switch semantics
**Idea:** The general form of a question M1 currently answers by accident. Today
`_next_fire_tick` is actor-keyed (cooldown CONTINUES across a switch), `_melee_hold` is
cleared (charge CANCELS), and `_combo_index` is cleared (sequence RESETS) — which happens
to match the intended defaults exactly, but nothing states them as a contract. Covers:
- **Declared holstered semantics per state CATEGORY**, with content override where a
  weapon differs, rather than per-state authoring on every content entry.
- **Switch-reset tech** — investigate-only. Adopt only if switching ever carries real
  commitment. Any M1 conclusion is provisional with an explicit revalidation trigger when
  the loadout expands toward four weapons + shield (P5's slot-count addendum).
- **Universal switch transition time/cost** — a legal future LOADOUT-system decision if
  ever wanted. Explicitly NOT derivable from the commitment/recovery principle; no global
  switching restriction now.
- **Ammo / reload / magazine state** — only when a concrete weapon's decision loop needs
  resource cycling. Holstered semantics must be settled BEFORE any resource whose
  behavior depends on unequipping. Magazine state is weapon-owned; no universal
  switch-refill; no generic persistence framework ahead of a consumer.
- **Per-weapon combo state** — `_combo_index` is per-actor, not per-weapon. Correct today
  only because a switch wipes it. A second combo weapon that should REMEMBER its step
  while holstered forces this.
**Invariant that survives all of it:** attack→switch→attack must never reach privileged
sequence states more cheaply than the normal economy permits.
**Why deferred:** one combo weapon and one gun cannot demonstrate a switch economy.

### P26 — Ranged weapon identity futures
**CONTENT DEBT — pre-correction projectile radii (recorded 2026-08-14, P29 item 3).**
Projectile collision now resolves at `projectile.hit_radius + target.combat_radius`, so
`hit_radius` means the projectile's OWN volume and nothing else. The two ACTIVE values
were re-derived accordingly (wand_A 0.40 -> 0.20, watcher_survey 0.50 -> 0.20).
`gun_pierce_A`, `gun_arc_A` and `gun_umbral_A` still author the PRE-CORRECTION 0.4. They
are deliberately untouched: they are dev-carousel only, and dormant numeric content is not
retuned without a consumer. **Trigger:** re-derive them when any of those weapons enters
an active loadout or a validation slice. Recorded here ONCE rather than annotated into
each dormant resource — the note belongs with the ranged-weapon docket, not scattered
across content nobody is reading.


**Idea:** Ranged depth arrives through content-authored projectile / commitment / control
behavior, never a universal projectile behavior graph. Identity = a CHANGED COMBAT
DECISION; one new lifecycle behavior at a time. The M1 wand is deliberately the simple
baseline. Candidates: distance-band transformation · committed burst · ricochet/geometry
(needs authoritative walls, so M2 at the earliest) · heavy recoil cannon (needs
displacement + re-hit maturity) · persistent hazard + displacement (damage collision ≠
movement collision ≠ AI-nav influence, all explicit — a damaging field is not
automatically navigation-blocking) · setup/detonation marks (snapshot-vs-resolution
semantics, lifecycle cleanup, cross-player permission, no recursive chains; the solo loop
must be complete without allies) · owner-relative/return projectiles (explicit
authoritative compound state, never invisible helper actors).
**First advanced consumer note (not scheduled):** committed burst / simple charge gun —
composes with the existing charge input, flinch vulnerability, and the commitment
principle without needing walls or persistent state.
**Also parked here:** direct charge access for future charge guns (hold begins charge, no
sacrificial precursor shot) · charge chaining (HOLD_TO_CHAIN vs FRESH_PRESS) only when a
weapon needs it · shield bump/displacement as a ranged-loadout spacing tool (revisit after
flinch validation and P19) · delayed-effect snapshot semantics · explicit projectile
defense-interaction traits (blockable / pierces / terrain / friendly-fire) as authored
data, never subclass accidents · **target-facing displacement**, which first requires
DEFINING authoritative gameplay facing (movement heading vs aim vs attack-facing vs
AI-facing vs a dedicated sim orientation — these currently disagree); that is its own
design/authority fork at the first consumer and must never be smuggled into a knockback
helper · **co-op obstruction as a first-class balance metric** ("does optimal use
repeatedly invalidate teammates' correct decisions?" — priced or redesigned) ·
generalist/Force damage needs a POSITIVE identity once typed loadouts matter ("neutral"
≠ specialist-without-upside) · environmental utility axis (destructibles, switches,
hazard triggering) when levels consume it.
**Why deferred:** the M1 gun proves the projectile pipeline; every item above is a second
weapon's job, and several are gated on M2 geometry existing at all.

### P27 — Multi-hit / attack-instance model
**Idea:** Attack-instance hit legality is a SEPARATE question from global health
i-frames. M1 has no multi-hit mechanic at all — verified by probe (2026-08-11): one swing
produces exactly one hit per target, a projectile hits once and expires, and a status DoT
bypasses i-frames entirely. So one i-frame value currently does exactly one job. Covers:
- **Re-hit eligibility** for staged multi-hit charges (the Brandish-style line, P5
  addendum): per-stage i-frame policy, per-stage knockback/flinch/status eligibility (NO
  naive independent per-stage proc rolls — 5×30% ≈ 83%), shield-break and death
  mid-sequence, attacker cancel commitment.
- **Cross-attacker i-frame/pressure suppression** — i-frames are target-global and
  source-agnostic today, so in M3 co-op two players' hits would suppress each other, and
  one player's hit would eat another's pressure contribution. No current consumer (single
  player), and the fix is explicitly NOT attacker-scoped i-frames by default — that's the
  decision this proposal exists to make deliberately.
- **Attack-instance identity** — `projectile_id` exists; nothing else has an instance id.
- **Co-op pressure attribution** — M1 records pressure contributions with no attacker
  attribution (no shares, no assists). Any future attribution rides here.
**Reasoning:** own front door because "how often may a target be hit" is a different
question from "how long is a target merciful after being hit," and conflating them is
exactly what produced the M1 combo-cadence defect (BRAIN).
**Why deferred:** defined by the first real multi-hit consumer; constrained until then
only by the recorded audit above. Do not pre-build.

### P28 — Global combat-scale coherence pass
**SPATIAL-COHERENCE DEBT — Ooze vertical artifact (recorded 2026-08-17, P29 re-playtest).**
Observed: the Ooze's 3D SILHOUETTE and its ground-plane FOOTPRINT disagree — combat
resolves on a horizontal circle while the model reads as a tall spiked mass, so contact
can look wrong vertically even when it is horizontally correct.
**DO NOT touch `combat_radius`.** It is the authoritative body radius shared by Burn
contact-spread, the melee lunge clamp, bump and (since P29) projectile collision; moving
it to fix a vertical reading would break four horizontal systems that are correct.
**Not scheduled.** Schedule only if a future session reports it as UNFAIR rather than
merely odd-looking. The likely fix lives in presentation or in a future vertical
dimension to contact, not in the existing radius.


**Status: RESOLVED for M1 (2026-08-13) — hypothesis NARROWED BY BETTER MEASUREMENT,
not confirmed.** The barrier is lifted; live tuning may proceed. Do NOT reopen without
a concrete new spatial finding.
**Outcome:** there was no need to globally rescale the combat system. Core-silhouette
analysis (radial p50 across each model's torso band) plus a live playtest showed the
defect was primarily **Ooze's undersized authored footprint** — 0.70 against a real
body of ~1.45, roughly half — with minor cleanup elsewhere. The earlier "contact ≈3.2
vs reach 2.0, therefore impossible" reading was an artifact of measuring mesh AABB,
which is dominated by appendages: Fang's 2.32 is nose-to-tail length, Watcher's 2.19 is
outstretched arms, the Envoy's 0.97 is a raised weapon. Measured at the core instead,
Envoy/Fang/Watcher were already about right.
**Adopted (Candidate A, PROVISIONAL/UNVALIDATED):** combat_radius Envoy 0.45 / Fang
0.90 / Watcher 0.85 / Ooze 1.45; Ooze preferred_attack_distance 1.8 → 2.20; each
family's minimum_attack_distance set to its contact distance. **Sword reach unchanged
at 2.0 / 2.5** — max contact is 1.90, still inside it. Burn spread co-tuned for free
through the shared `_contact_distance`. Candidate B (generous core, reach 2.4/2.9)
was defined but deliberately NOT tested: only try it against a concrete spatial
failure. No model scaling; world scale not reopened.
**Playtest verdict (2026-08-13):** Ooze no longer swallows the Envoy at contact; all
three distances believable in motion; world scale normal; enemy spacing fine; no new
Burn/contact problem observed.
**REVALIDATION TRIGGER (open):** there is no sword model or attack animation yet, so
weapon-reach/contact ALIGNMENT is explicitly unvalidated — nothing shows a strike arc
or a contact frame. Re-check reach/contact presentation once real attack visuals
exist. Do NOT retune this geometry to solve an animation problem unless authoritative
contact itself proves wrong.
**Method retained below** for that revalidation and for any future scale question.

**(Original brief, retained as method:)**
**Origin (G-1, closed as falsified 2026-08-12):** the lunge clamp is mechanically
correct. The defect is a mismatch between rendered world scale and authoritative
combat geometry — combat radii, melee reach/contact distances, and rendered
silhouettes were never calibrated as ONE spatial system. Evidence: at Ooze's authored
1.1 contact distance the Envoy renders fully inside the mesh; a uniform 0.40 model
scale neither resolved the overlap nor kept the world readable (it read toy-scale),
and the Envoy's own model half-extent (~0.97) already consumes ~88% of that 1.1
budget, so no per-model scaling can close it. Full detail: `e8d9979`, `1337754`.
**FORBIDDEN until this pass runs:** `model_scale` fields · raising `combat_radius`
alone · raising sword `reach` alone · deriving any combat radius from mesh AABB or
capsule extents.
**Brief:**
- Establish a canonical perceived gameplay FOOTPRINT first, then derive combat radius
  → reach → attack movement → enemy spacing → Burn contact around it. Do NOT preserve
  current ratios automatically — they were authored independently and some may be
  wrong relative to each other.
- **Anchor candidate** (default unless visual judgment overrules): asset-meter
  alignment — the Envoy's footprint = its glTF model's actual occupancy at scale 1.0,
  so all future KayKit/Quaternius/Kenney content lands at native scale through M2.
  (A uniform k ≈ 2.5 survives only as a starting estimate under this anchor, never as
  the method.)
- Non-circular meshes (Fang) use a gameplay body footprint judged around the
  meaningful CORE silhouette — never full mesh extent.
- Burn contact spread and the lunge clamp distance stay co-tuned (locked, one shared
  `_contact_distance` formula).
- Own commit(s); suite green before and after; distance-asserting tests updated
  DELIBERATELY, not mechanically; all values PROVISIONAL until the re-gate; camera
  reframe (P21-adjacent) evaluated in the same pass.
**Why here and not earlier:** it is a deliberate design pass, not a bug fix. Doing it
before flinch exists would tune spacing against combat that has no reaction layer yet.

### P29 — Enemy action repertoire / distance-conditioned action selection
**Status:** **PASS — CLOSED 2026-08-18.** Frozen point: commit `9378316`
(`9378316964ab94f4223ca9e447563477e2ec6294`).

Closing verdict rendered by Breon 2026-08-18, verbatim:
> "P29 — PASS. The Watcher now feels like it is making a contextual decision instead of
> automatically shooting because I entered a range band. It chases first, uses Survey as a
> fallback after being kept out, and one Survey per failed-close episode feels sensible
> rather than repetitive. The Survey itself is fair and readable, I can intentionally parry
> it, and I can now identify the vulnerable phase; the exploit route also works mechanically
> when I am positioned to use it. The remaining animation, projectile-package, aim-lock,
> reflected-parry, wand-reward, and broader movement-identity ideas are follow-up work, not
> blockers for this Watcher selection slice."

**What this verdict does and does not certify**, since the follow-up docket is large: it
certifies the SELECTION SLICE — contextual choice over range-triggered fire, the
one-Survey-per-failed-close-episode economy, Survey's fairness/readability, deliberate
parry, an identifiable vulnerable phase, and the exploit route working mechanically when
positioned for it. It explicitly does NOT certify melee-range animation readability, the
projectile package, aim behaviour, parry payout design, wand reward design, or movement
identities — all named by Breon as follow-up work rather than blockers, and all dispatched
with triggers below.

**PROVENANCE OF THE CLOSING VERDICT (diff-verified, not asserted).** The replay ran on the
working tree, because the prior frozen commit `51d16b5` crashed on attack. The only
gameplay delta between the played tree and `9378316` is the `set_active()` restoration —
21 insertions, 0 deletions — which was present during the replay; everything else differing
was tests and documentation. The verdict therefore attaches to `9378316` honestly.

**FOLLOW-UP DOCKET — DISPATCHED, each with its named trigger:**
| Item | Home | Trigger |
|---|---|---|
| Melee-range animation readability | P32 (+ P28's open revalidation trigger) | Melee parry stays blocked until an impact/arrival presentation exists; P28 re-checks weapon-reach/contact alignment once real attack visuals land |
| Survey package escalation (+ disguise fence) | P29 (below) | Selection judged successful on identity, but Survey still lacks weight as an event |
| Aim-lock fork | P29 (below) | Continuous tracking makes the long-windup Survey too turret-like or undermines movement counterplay |
| Reflected-projectile parry | P31 | Requires its own fork review — it REPLACES a banked mechanic |
| Wand commitment/reward | P30 | Evaluate charge vs consecutive-hit empowerment before implementing |
| Family movement identities | P17 | M2 content pass; Fang sketches + taxonomy captured |
| Kiting-punisher family | P17 / selection note | **Owns the infinite-kite answer** — if infinite-kite proves too safe, it is evidence for a new episode-reset rule, never a reason to weaken one-survey-per-episode |

**HISTORY — the two prior verdicts that produced this closure are recorded in full below:
the first playtest (2026-08-14) immediately following, and the re-playtest (2026-08-17)
further down under RE-PLAYTEST.**

**HISTORY — first playtest verdict, rendered by Breon 2026-08-14, verbatim:**
> "P29 — ITERATE, concept validated. The Watcher's ranged action materially improves
> group-combat pressure, feels fair, preserves both close and ranged approaches, and
> strengthens the Watcher's 'read the windup' identity. P29 is not closed because the
> current implementation does not yet make its higher-skill interaction windows legible:
> the vulnerable interval and intentional parry timing could not be identified during
> play, the projectile's visual/authoritative relationship produces apparent hits that
> miss, and first-engagement firing reads mechanically range-triggered. Required
> iteration is limited to engagement-opener feel using content levers first,
> windup/projectile readability, and the wand EXPLOIT-vs-NONE comparison. Selection
> architecture remains unchanged unless the re-playtest provides evidence that these
> narrower changes are insufficient."

Per M1 precedent the iteration items are REQUIRED closure work; **the next verdict comes
from the re-playtest, never from the suite going green.** Selection architecture is NOT
reopened. Opened at M1 close (2026-08-13); explicitly NOT a retroactive M1 prerequisite.
**Idea:** enemies gain a repertoire of authored actions and choose between them by
situation (distance first). The AI's new power is narrowly "which of my authored
actions applies here"; everything about an action — reach, windup, damage, telegraph,
susceptibility window — stays CONTENT, preserving the locked build-shape rule that the
AI decides only locomotion, whether to attack now, and which eligible authored action to
commit. First concrete second-action consumer: a
**ranged action**, pulling P17's ranged archetype forward. A Force-typed ranged attack
respects MECHANICS-REFERENCE §2's onboarding rule (all early enemy damage is baseline
type) and needs no enemy-applied status, so only P17's M2 content-pass timing moves.
**THE COMPOSITION FENCE (verbatim, carried from the M1 re-gate — this is the point):**
> "Multiple viable approaches at differing effort/safety is desirable, not a defect.
> Enemy repertoire depth must create decisions through situation composition, never by
> converting combat into mandatory single-answer counters."
**Why it matters:** the M1 re-gate's answer to "is there a dominant strategy?" was that
the player *values* killing enemies several ways at differing effort and safety, with
real decisions emerging under group pressure. Depth must come from composing situations,
not from making each enemy a lock with one key.
**Design questions — ALL SETTLED, built 2026-08-14 (verdict not yet rendered):**
selection = authored `action_id` from the enemy resource's `action_ids`; conditioned on
non-overlapping distance bands, no RNG and no array-order priority; cooldown SHARED
per-actor; the Watcher gets the ranged action (`watcher_survey`), Fang and Ooze stay
single-action. Boundary convention: non-terminal bands are half-open `[min, max)`, only
the outermost band includes its maximum — a closed interval would make adjacent bands
both match at the shared edge and violate the overlap law in v1's own content.
Whether a second action dilutes the EXPLOIT lesson was answered by DESIGN rather than
deferred: the survey teaches the SAME lesson at a second distance with a different tool,
and its longer windup makes it the most readable action in the game. **The playtest, not
this entry, decides whether that worked.**

**Filed revisit triggers (do not act on these without the named evidence):**
- **Per-action cooldown.** Reconsider ONLY on evidence that use of one authored action is
  suppressing otherwise-desired availability of another *specifically because both share
  `_next_fire_tick`*. "The survey fires too rarely" is NOT that evidence — exhaust the
  content levers first (band edges, actor spacing, windup/cadence, projectile tuning).
- **Action-derived movement preference.** P29 deliberately kept the engagement band
  actor-level; coupling selection to movement would make the Watcher hold at survey range
  and become a turret, letting the player skip its melee action entirely. This becomes a
  real design question when a range-**maintaining** family arrives (the kiting-punisher
  fork) — designed then, for that consumer, and it will need hysteresis at the band
  boundary. Never adopt it as a fix for "the ranged action fires too rarely."
- **The no-gaps content lint is PROVISIONAL** (`tests/test_content_validation.gd::
  test_bands_tile_without_gaps`), typo prevention rather than schema law. Removal trigger:
  the first enemy design that deliberately wants a meaningful interior dead band. Delete
  the test and nothing else — the fall-through behaviour is already specified and already
  covered by `test_interior_band_gap_falls_through_to_ordinary_locomotion`. Overlap stays
  permanently forbidden.
**RE-PLAYTEST 2026-08-17 — VERDICT: ITERATE (second cycle).** Rendered by Breon, verbatim:
> "P29 — ITERATE. The Watcher is better now and the ranged pressure works. The engagement
> delay made it feel like it noticed me before acting, the projectile is fair and readable,
> and I can intentionally parry it. The ranged attack also adds good pressure when I'm
> fighting something else. But I still can't intentionally identify the vulnerable window,
> the Watcher shoots too often and still feels too interval-driven, and basic wand flinch
> is clearly too strong. I want another iteration on those things before I consider P29
> done."

**BANKED (settled, hands off — do not retune while chasing an unrelated finding):**
- Engagement opener PASS at `engagement_delay_ticks = 10`; UNVALIDATED marker removed.
- Lateral projectile geometry PASS.
- **Q8 UNBLOCKED and PASSED** — projectile parry is readable and deliberately timeable.

**LOCKED — basic wand flinch capability = NONE** (pressure contribution unchanged).
*Identity consequence, recorded precisely:* with basic wand at NONE the Watcher's
VULNERABLE window is no longer safely cashable from range by basic fire. The direct
EXPLOIT route requires CLOSING and landing sword hit 1 or hit 2 during the window
(locked map, pinned by test: hits 1-2 EXPLOIT, hit 3 PRESSURE, charge PRESSURE).
Movement tools (bump, charge lunge) help close distance but are **NOT exploit triggers** —
never conflate traversal with capability in docs, comments or design talk. Future
committed wand mechanics may earn ranged exploitation on their own terms (P30).

**VULNERABILITY ROUTE — BANKED PASS 2026-08-17.** The controlled close-position probe
passed: an EXPLOIT-capable sword hit landing at offset 26, inside the authored 23-34 window,
produced `windup_interrupted` and `flinched` with `reason: "exploit"`, and the shot never
left. **It could not have passed for the wrong reason** — sword_burn_A authors
`interrupt_strength = 0` on hits 1-2 (only hit 3 carries 1), so graded interruption cannot
cancel a windup here and the cancel can only have come from the vulnerability route. A
negative control pins the other side: the identical hit BEFORE the window produces no flinch,
no cancel, and the Survey fires as authored. Both are permanent tests.

**SCOPE OF THE BANK, ruled explicitly:** this is MECHANICAL verification. It is **not** a
claim that normal ranged Survey situations leave enough travel time to reach the Watcher.
**Positioning determines which counterplay is available**, and `vulnerable_start_tick` is
NOT to be changed to make the window reachable from arbitrary ranged positioning — the
window's perceptibility passed on its own. Survey timing stays frozen.

**VULNERABILITY CONFOUND — RESOLVED AS UNRECALLED → CONTROLLED PROBE.** No defect is
inferred from memory. With the cue fix landed, the probe is a REQUIRED step of the next
playtest: approach with sword, wait for the now-legible vulnerable transition, deliberately
land hit 1 or 2, and observe whether the survey interrupts.
- Interrupt occurs → **no defect**; the cue fix closed the whole finding.
- Confirmed in-window hit with NO interrupt → **mechanical defect**: diagnose
  `_flinch_mode_of` / window resolution on the survey before anything else.

**ITERATION BATCH (second cycle):**
1. **Vulnerable cue** — unmistakable phase transition (preparation → distinct "open now" →
   fire). Timing unchanged, derivation unchanged, no new events. LANDED 2026-08-17: the
   first attempt failed because the disc was already full-size and full-brightness for the
   whole windup, so the window was a change of DEGREE inside an unchanging presentation.
   Now understated-and-still while preparing, then a hard pop into a continuous PULSE —
   a change of KIND, with motion doing the work.
2. **Survey cadence** — increase `watcher_survey.fire_interval_ticks`. PROVISIONAL, returns
   for approval before landing.
3. **Ooze vertical artifact** — recorded to spatial-coherence debt (P28-adjacent) below.

**Q8 (parry reach) — RESOLVED 2026-08-17: UNBLOCKED and PASSED.** History below.
**Was BLOCKED UPSTREAM, NOT FAILED (2026-08-14).** The question was
"after parrying a survey at range, can you reach the Watcher while PARRY EXPOSED is still
useful?" It could not be answered because no perceptible ARRIVAL cue existed to time a
shield-raise against — the player could not deliberately choose the parry moment, so
nothing about parry REACH was ever exercised. Recording this as a parry-tuning failure
would have been a false negative about a mechanic that never got to run.
**Q8 ACCEPTANCE FENCE:** arrival presentation must improve timing readability WITHOUT
visually overstating projectile collision width (see the projectile presentation law in
game/actors/projectile_tracer.gd). Only if intentional parry becomes possible does it
become legitimate to evaluate whether parry reach or window themselves need tuning.
**Re-ask after items 2-3.** The entry criterion is strictly upstream of reach: *can the
player deliberately choose the parry moment at all?* Only once that is YES does parry
reach/window tuning become diagnosable — and only then may any parry number move.

**SELECTION ARCHITECTURE — HOLD SUPERSEDED 2026-08-17; WATCHER SELECTION PASS OPENED.**
Recorded precisely, because the reason matters: **the ROADMAP trigger below did NOT fire.**
Its planned cue+cadence replay never took place. The hold was instead superseded by a
stronger Watcher IDENTITY ruling from Breon, verbatim:
> "It shouldn't be the main choice of action when a certain condition exists. It should be
> a potential selection that's not chosen every time a condition is met. Turret characters
> will shoot projectiles at interval. Watcher's should be a unique projectile — maybe large
> and fastish with a long wind up that it's locked into after it ascertains your location."

**CADENCE PROPOSAL REJECTED (45 -> 80 NOT landed; `fire_interval_ticks` stays 45).** The
measurement was sound but aimed at the wrong finding: it addressed FREQUENCY, while the
clarified concern is SELECTION IDENTITY. Making the same automatic choice less often does
not make it a choice. Do not revive it as a workaround for selection.

**CONTROLLED SWORD EXPLOIT PROBE — MOVED.** It now runs against the REDESIGNED Survey, so
it is performed once, against the Survey intended to ship, rather than twice against a
version being replaced.

**Scoping from the superseded hold, retained because it is still true:** cadence evidence
was clean; architecture evidence was not yet sufficient. The trigger text below is kept as
the historical record of what would have re-opened this, and is now moot.

**SUPERSEDED — original one-cycle hold (both seats + Breon, 2026-08-17).**
Scoping recorded so the hold is a decision rather than a delay: **cadence evidence is
CLEAN** (the survey fires too often — tune now); **architecture evidence is NOT yet
sufficient** (presentation failed, so counterplay was never actually observed under
legible conditions).

**ROADMAP TRIGGER, verbatim:**
> "After cue + cadence fixes: does the Watcher resume fighting/positioning before deciding
> to survey again, or does it still feel like it is waiting for the survey timer to become
> legal? If the latter, the trigger has fired and the narrow Watcher-specific
> approach-frustration seam opens."

**The pattern this would translate** (reference-game shape): attempt approach → melee
attempts → ranged fallback when closing is frustrated.
**Sketch, if the trigger fires:** primary desire is a THREAT POSITION; approach succeeds →
the close option; approach frustrated for an authored duration or attempt count → survey;
after a survey → resume movement/decision, **never immediate cycling**.
**Explicitly NOT a utility framework.** Bands remain pure eligibility; this would be a
narrow, authored, inspectable Watcher-specific seam, not a scoring layer.

**CONTEXTUAL SURVEY SELECTION — IMPLEMENTED 2026-08-17 (awaiting replay).** Survey is
gated by close-frustration: the Watcher must have failed to reach its close band for
`close_frustration_ticks` (90, PROVISIONAL; **candidate fallback 60** if the replay finds it
passive), and each failed-close episode grants exactly ONE fallback. Represented as two
literal facts — last tick actually inside the close band (refreshed continuously) and last
tick Survey was committed — with episode consumption DERIVED from their ordering, never a
mutable flag. Consumption is at COMMITMENT: interrupting a committed Survey does not restore
the opportunity. Deliberately narrow naming (`requires_close_frustration`,
`close_frustration_ticks`, `_close_frustration_satisfied`); **generalise only when a second
real context-conditioned action exists.**

**Emergent consequence to watch at the replay (not a defect, a direct result of the ruled
design):** a player who kites *indefinitely and never lets the Watcher close* receives
exactly ONE Survey, ever — the episode never clears because close range is never
re-established. Mitigating in practice: the arena is bounded, the Watcher keeps closing at
2.0, and other enemies force engagement. Flagged so it is recognised as the rule working
rather than the Watcher going inert.

**Ruling on how that evidence may be used, verbatim:**
> "If infinite-kite ever proves too safe, that becomes evidence for a new episode-reset
> rule — never a reason to weaken one-survey-per-episode preemptively."

Cross-reference: punishing a player who sustains distance is precisely the **range-maintaining
("kiting-punisher") family** already recorded as the trigger for action-derived movement
preference (see the selection-architecture note below and the P17 family-identity docket).
If infinite-kite reads as too safe, the first question is whether the answer belongs to a
NEW episode-reset rule or to that family's own design — not to the Watcher's episode
semantics, which are ruled.

**AIM-LOCK — FUTURE FORK (not opened; GAME-RULES §3 preserved unchanged).** Survey is
ACTION-locked only: once selected the Watcher cannot abandon the windup, and aim continues
to be sampled at the fire tick. Correct mechanical description, to be used verbatim in docs,
comments and any player-facing copy: *"Movement during windup changes the eventual fire-tick
aim; it does not defeat the shot by invalidating a previously locked target position."*
**Trigger, verbatim:** *"if later playtest shows continuous tracking makes the long-windup
survey too turret-like or undermines movement counterplay, compare fire-tick aim vs authored
aim-lock and amend §3 explicitly if aim-lock wins."* Never worked around.

**PACKAGE ESCALATION — "large / fastish / long-windup" Survey (queued, NOT scheduled).**
Trigger: the selection pass is judged successful on identity, but Survey still lacks weight
or distinctiveness as an event. Re-validation costs ride with it: `hit_radius` re-derivation,
Q8 parry re-verification, and corridor math at the new speed (a reactive escape must remain
possible at representative engagement distances under fire-tick aim — "fastish" is sized
against the dodge it must still permit, never chosen as an adjective).
**Fence, verbatim:** *"If selection does not fix the identity problem, do not try to disguise
that failure by making the projectile more dramatic."* A failed selection pass is
re-diagnosed at the selection layer, never masked with content spectacle.

**BUMP-PROVOKES-SURVEY — explicitly NOT implemented.** Displacement already feeds the
proximity clock naturally: a bump stops the refresh, leaving the full patience still to
elapse. "Bump instantly provokes Survey" is a separate behavioural rule requiring its own
evidence; a dedicated test pins that it does not happen today.

**CANDIDATE PROJECT FINDING (captured 2026-08-17, NOT a framework requirement).** Enemy
identity increasingly depends on HOW an enemy reaches and CHOOSES an attack situation, not
merely which attack becomes legal at a given distance. Distance-band eligibility answered
"what may I do from here" and that was the right first step; it does not answer "what am I
trying to achieve, and is this the moment for it." Recorded as an observation to test, not
as licence to build a generic selector — see the fence below.

**FUTURE DIRECTION — context/intent-conditioned selection (captured 2026-08-14, NOT
scheduled).** Bands stay what they are: pure ELIGIBILITY ("which actions are legal from
here"). The direction is to add a separate, explicit INTENT layer that chooses among the
already-eligible actions — engagement, retreat, and player-occupied contexts being the
first three worth naming. This keeps the no-hidden-priority rule intact, because intent
would be an authored, inspectable input rather than an implicit ordering. It is NOT a
utility/scoring framework and must not become one.
**Trigger (either):** the re-playtest, after items 1–2 below, still reads
range-triggered; OR the range-maintaining ("kiting-punisher") family arrives, which
already carries its own deferred movement-coupling question.

**Open after the build, before any tuning:** whether the two Watcher tells are
distinguishable. They share a telegraph COLOUR by law (both Force; damage types own
colour, GAME-RULES §3 channel law) and are separated by windup duration (20 vs 34) plus
the tracer. If a playtest finds them confusable, the fix is another non-colour channel
(disc size, pulse rate) — never a colour the damage type does not own.

### P30 — Wand commitment/reward mechanic
**Status:** NEAR-TERM, promoted 2026-08-14, **BROADENED 2026-08-17** after the wand A/B
locked basic ranged flinch to NONE.
**Broadened scope — evaluate BEFORE implementing, do not assume the charge shape.** The
question is what a wand's *commitment/reward* mechanic should be, and there are at least
two candidate shapes that are not the same design:
- **Charge** — hold to pay up front, spend the commitment before the payoff.
- **Consecutive-hit empowerment** — the reward accrues from sustained accurate fire, so
  the commitment is paid in continued exposure rather than in a hold.
Pick by which one creates a real decision (BRAIN candidate principle 3), not by which is
easier to author. This is also the earliest legitimate home for RANGED exploitation, now
that basic fire cannot cash a window — but that authority must be EARNED by the committed
mechanic, never restored to basic fire.
**Idea:** give the wand a charge profile — the ranged counterpart to the sword's
hold-to-charge, which today has no ranged equivalent at all (the wand is deliberately the
simple baseline, P26).
**Why it was promoted:** P29's item-4 A/B asks whether the BASIC wand shot should carry
EXPLOIT flinch authority. Both answers point here. If basic-EXPLOIT proves too strong,
the charge profile is the natural home for *committed* ranged flinch authority — you pay
a hold for the right to interrupt, which is the same bargain the sword's charge already
makes. If basic-EXPLOIT proves fine, the charge still needs its own distinct answer to
BRAIN candidate principle 3 ("why use the basic attack here?" AND "why charge here?"),
and inheriting flinch authority unexamined would fail it.
**Explicitly gated:** do not author this until the item-4 comparison is played. Its whole
design question is downstream of that result.
**Design questions:** what the charge changes (damage? projectile count? travel? pierce?)
— identity must be a CHANGED DECISION, not a bigger number (P26) · whether charge-shot
flinch authority is EXPLOIT or a committed variant · how it composes with the shared
per-actor cooldown · does it want its own tracer treatment.
**Reasoning:** P26 already parks "committed burst / simple charge gun" as the first
advanced ranged consumer and "direct charge access for future charge guns". This
promotes exactly that slice to near-term, with a concrete trigger, rather than leaving it
in the general ranged-futures pool.

### P31 — Reflected-projectile parry
**Status:** PROPOSED, captured 2026-08-17. **Requires its own fork review before any
build** — this would REPLACE the current instant-EXPOSED-on-parry reward, so it is a
change to a shipped, validated mechanic rather than an addition.
**Idea (Breon's design intent):** parrying a projectile REFLECTS it rather than simply
marking the attacker PARRY EXPOSED.
- **Must-reconnect trigger:** the reflected shot has to actually hit the attacker to pay
  out. The reward becomes an aimed outcome, not an automatic one.
- **One reflect per shield raise:** the raise is the resource, so a held shield cannot
  farm reflections.
**Why it needs a fork review:** Q8 passed on the CURRENT parry (readable, deliberately
timeable, instant EXPOSED). Replacing the payout changes what the player is timing FOR,
and could unsettle a banked PASS. Design questions: does a reflected shot use the
player's damage or the enemy's; can it be re-parried; what happens on a miss; does
EXPOSED remain as a fallback or disappear entirely.

### P32 — Melee parry timing (blocked upstream on impact presentation)
**Status:** BLOCKED UPSTREAM, captured 2026-08-17. Not a failure — a prerequisite.
**Finding:** projectile parry passed (Q8) precisely because a travelling projectile shows
its ARRIVAL. Melee has no equivalent: the telegraph says an attack is COMING, but nothing
says **now**, and "now" is what a parry is timed against.
**Prerequisite:** an impact/arrival presentation for melee attacks — the melee analogue of
watching a shot close the distance.
**Do not** attempt to fix this by widening the melee parry window; that trades a timing
problem for a leniency problem and leaves the player still unable to aim their timing.


## Graveyard
(One-line tombstones of SHIPPED/REJECTED proposals, pruned at milestone completion.
Full text lives in git history — `git log -p ROADMAP.md` resurrects anything.)
