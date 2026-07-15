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
**Why deferred:** M4 by design; do not front-load progression before fun is proven.

### P6 — Rotating gate map (arcade)
**Idea:** Multiple concurrent descent "gates" whose upcoming floors rotate on a
timer and are previewable, making route planning a meta-game.
**Reasoning:** The reference game's most distinctive structural feature; genuinely an
MMO-layer system since its value comes from a shared persistent world.
**Why deferred:** M5. The M2 next-floor preview is the single-run seed of this idea.

## Graveyard
(One-line tombstones of SHIPPED/REJECTED proposals, pruned at milestone completion.
Full text lives in git history — `git log -p ROADMAP.md` resurrects anything.)
