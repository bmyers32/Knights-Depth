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
| P16 | Timed shield bounce | PROPOSED | Raise-in-window repels the attacker; layers on the recorded block-start tick |
| P17 | Per-family engagement identities | PROPOSED | Movement/attack personality as content on top of the shared AI; M2 content pass |
| P18 | Idle wander + return-to-post + room territory | PROPOSED | Post-disengage idle behavior layer; needs its own RNG stream; M2 |
| P19 | Per-family mass/knockback factor | PROPOSED | Weight scales pipeline knockback only; binds to family, never to state (§6.8) |
| P20 | Sim movement collision/bounds | PROPOSED | No wall/body-blocking exists anywhere; lunge (manual-pass) inherits and exposes it |
| P21 | Arena camera-follow | PROPOSED | Fixed camera doesn't track the Envoy; noted repositioning Watcher for visibility |
| P22 | Buffer eligibility during charge windup | PROPOSED | Scope cut, not canon — a projected `end_tick` is already computable |
| P23 | Graded player poise | PROPOSED | Mirrors `interrupt_strength`; M1 ships unconditional cancel only |

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

### P16 — Timed shield bounce
**Idea:** Raising the shield within `bounce_window_ticks` of an incoming hit repels
the attacker (knockback applied TO THEM instead of the block just absorbing), with an
internal `bounce_cooldown_ticks` preventing spam. Both new fields on `ShieldStats`.
Layers directly onto the shipped block system via the block-start tick SimWorld
already records on every READY→HELD rising edge (`_block_start_tick`) — the bounce
reads existing state instead of retrofitting a new one.
**Reasoning:** Rewards timing over passively holding block, translated from the
reference game's shield mechanics — a skill expression the flat "hold to negate"
model doesn't have room for on its own.
**Design questions:** Does a bounced attack still drain the meter? Does bounce work
during the post-break `break_recovery_delay_ticks` window? Can bosses/heavy attacks be
bounced, or are some attacks bounce-immune by data flag?
**Why deferred:** Shield v1 (this session) ships the flat block/break model only;
bounce is a Treat-Rule-friendly layer once the base mechanic is playtested.

### P17 — Per-family engagement identities
**Idea:** Movement/attack personality translated from the reference game, layered as
CONTENT on top of the shared AI (pursue/engage/leash) built in Phase D step 8 — never
as AI special cases (the locked build-shape rule: attack shape is content, the AI only
ever decides move + attack-now).
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
**Why deferred:** No trigger yet. Build when two enemy bodies need meaningfully
different push responses, or when Brandish (P5 addendum) lands and its advancing
impacts need family-aware pushback to feel right.

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

## Graveyard
(One-line tombstones of SHIPPED/REJECTED proposals, pruned at milestone completion.
Full text lives in git history — `git log -p ROADMAP.md` resurrects anything.)
