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
| P17 | Per-family engagement identities | PROPOSED | Movement/attack personality as content on top of the shared AI; M2 content pass |
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
| P29 | Enemy action repertoire / distance-conditioned selection | **ITERATE (concept validated) 2026-08-14** | Ranged action works; closure blocked on opener feel, windup/arrival readability, wand A/B |
| P30 | Wand charge profile | **NEAR-TERM (weapon docket)** | Promoted 2026-08-14; likely home for committed ranged flinch authority, pending the P29 item-4 A/B |
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
**Status:** **ITERATE — concept validated.** Playtest verdict rendered by Breon
2026-08-14, verbatim:
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
**ITERATION LANDED 2026-08-14 (pre-replay).** Items 1-4 of the required closure work are
implemented and suite-green; the verdict remains ITERATE until the re-playtest renders a
new one.

**REPLAY ATTRIBUTION FENCE (binding on how the next session is read).** The next arena
session is NOT a pure wand-capability comparison against the original P29 build. Four
things changed underneath it since the first playtest: projectile collision geometry,
projectile visual radius, the Watcher engagement delay, and vulnerability presentation.
Treat the replay as **validation of the current composed P29 iteration**; the wand
EXPLOIT/NONE toggle isolates only that ONE variable within the new, frozen substrate.
Do NOT attribute global feel changes solely to the capability toggle.

**Remaining P29 queue — entirely arena-side, nothing left to build:**
1. wand basic EXPLOIT vs NONE A/B (`debug_wand_flinch_none`), pressure contribution unchanged.
2. Watcher opener feel at `engagement_delay_ticks = 10`.
3. Vulnerable-window cue legibility.
4. Projectile visibility + arrival readability + dodge feel under corrected geometry.
5. Q8 parry re-ask (below).

**STOP-LINE:** no further pre-playtest changes of any kind. No selection-architecture
work, no HP/damage/flinch-threshold tuning, no charge implementation, and no additional
projectile-radius tuning before the replay. The substrate under the A/B is trustworthy
and stays still until it is measured.

**Q8 (parry reach) — BLOCKED UPSTREAM, NOT FAILED (2026-08-14).** The question was
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

### P30 — Wand charge profile
**Status:** NEAR-TERM, promoted to the weapon docket 2026-08-14 out of the P29 playtest.
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

## Graveyard
(One-line tombstones of SHIPPED/REJECTED proposals, pruned at milestone completion.
Full text lives in git history — `git log -p ROADMAP.md` resurrects anything.)
