# HANDOFF — 2026-07-30 (world-identity capture session, claude.ai)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- M0 complete (both warmups done and closed out prior to this session).
- Ten-document lore/design arc captured into law: LEXICON.md, WORLD-CANON.md,
  CORE-FANTASY.md created; GAME-RULES gained §6 Design Laws (Change Log now §7).
- Global renames: knight→Envoy (CLAUDE.md, GAME-RULES, SETUP/QUICKSTART Phase D);
  Automaton→Watcher (true name Custodian) in §3 + MECHANICS-REFERENCE matrix.
- §3 amendments: family×state orthogonality;
  channel law (damage types=color, forces=silhouette/motion).
- §5 M2: strata named (Archive, Foundry); run-end screen = Emergency Recall framing.
- ROADMAP +P7–P14 (Companion, Protocols, Drift scalar, gear states, Contested,
  Frames, community world-state, title) + NOT-list additions.
- RISKS +12–14 (canon-outruns-milestones, gear-state multiplier, lexicon regression).
- BRAIN +2 entries (native-sounding loanwords; capture-at-convergence).
- Post-capture amendment (seed+5): three-axis law explicit in §6.8; Umbral combat
  identity = coherence disruption; P10 Drift↔Umbral residue removed; type-count
  challenge DECLINED (4 types × 6 families = locked arithmetic pair; playtest is
  the venue for combat-feel challenges, not further documents).
- QA fixes (seed+6): LEXICON's own "corruption engine" violation → Drift engine;
  Umbral=dark gloss; channel law forces→STATES; warmup knight→Envoy; anti-multiplier
  rule; Act 3 chronology; CORE-FANTASY provisional-authority; P9/P12 tightened.
- **M1 roster LOCKED (seed+7): Common Fang · Drifted Ooze · Claimed Watcher** — one
  weakness per specialized type. Hollow → Archive (M2) debut with true-name reveal.
  Reversal requires playtest evidence.

## Not done / next action
1. **guard.py update** (file wasn't in session): banned strings per LEXICON — navi,
   net king, netking, dark web, undernet, virus, corruption. Warn-only: `knight` in
   NEW game/ identifiers. Normalize case + resolve paths with pathlib (BRAIN).
   Verify by tripping BOTH directions:
   BLOCK: game/content/corruption_weapon.tres · game/actors/virus.gd ·
   tests/test_netking.gd — WARN: game/actors/knight.gd — ALLOW: README "Knight
   Depths" · ASSETS.md KayKit filenames · GAME-RULES §7 history · BRAIN retrospectives.
2. Copy updated files into repo root, review diff, commit + push
   ("World identity capture + QA fixes + M1 roster — §7 seed+4..7").
3. Then: asset intake session or /kickoff 1 session 1 (sim skeleton per Phase D).

## Open tensions
- Pyre name provisional (Temper art direction); Hollow true name unassigned.
- Palettes provisional pending Umbral/damage-type art pass (channel law holds).
- Sync-as-meter: default NO (narrative only); annotated in canon.
- CORE-FANTASY pillars are [YOUR CALL] drafts — developer homework, no deadline.

## Concepts introduced this session
- (design, not engine) Register-based naming grammar; orthogonal state tags vs.
  matrix rows; channel separation for visual language.

## Do NOT redo
- Naming re-litigation: slate is LOCKED per LEXICON amendment rule (vetoes were
  taken; changes now require playtest/collision evidence + dated amendment).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12; canon annotated).
- Do not rename statuses to lore words (REJECTED — ROADMAP NOT-list).

## Files touched
LEXICON.md (new) · WORLD-CANON.md (new) · CORE-FANTASY.md (new) · GAME-RULES.md ·
CLAUDE.md · AGENTS.md · MECHANICS-REFERENCE.md · ROADMAP.md · RISKS.md · BRAIN.md ·
QUICKSTART.md · SETUP-AND-START.md
