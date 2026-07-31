# HANDOFF — 2026-07-30 (guard.py hardening session)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- `scripts/guard.py` updated per LEXICON.md "Banned & Watch Terms": hard-blocks navi,
  net king, netking, dark web, undernet, virus, corruption (case-insensitive, scoped to
  game/, tests/, content/ via pathlib component matching — never string search).
- Warn-only (never block) added for "knight" in new game/ code; exempts asset
  filenames, README, and the repo name ("Knight Depths").
- Fixed a latent bug: the pre-existing SK-IP content check referenced an undefined
  `lowered_path`, so it had never actually functioned (silent NameError on every real
  trip) despite being wired correctly since M0 — see BRAIN's hook-verification entry,
  second occurrence.
- Fixed Edit/MultiEdit schema mismatch: content extraction read `new_str`, which
  doesn't match the real tool field (`new_string`) or MultiEdit's `edits[]` array — both
  were previously unscanned by any check.
- Added a self-path exemption so guard.py doesn't trip its own IP/LEXICON term lists
  when edited (those lists must exist as literal text in the file it guards).
- RISKS #14 mitigation column: noted guard only covers Edit/Write/MultiEdit, Bash file
  writes bypass the hook — accepted gap.
- Verified via a 12-case trip matrix (3 LEXICON blocks, 1 warn, 4 allows, 1 fresh SK-IP
  block, 1 guard-self-exemption check, 2 regression checks) — all passed as expected.
- GUT suite re-run clean: 2 scripts, 5 tests, 9 asserts, 0.371s, no regressions
  (expected — no sim/gen code touched).
- Committed `7f43611` (bundles this session's guard hardening with the prior
  world-identity-capture session's files, which were staged but uncommitted at
  session start) and pushed to origin/main.
- BRAIN.md: appended second occurrence + guard-can't-scan-its-own-source observation
  to the existing "configured hook is not a working hook" entry (no new entry).

## Not done / next action
1. `/kickoff 1` session 1 — sim skeleton per SETUP-AND-START.md Phase D: SimWorld,
   Command/Event types, headless-tick proof. No M1 combat code exists yet.
2. Asset intake session (KayKit/Quaternius CC0 pulls for Envoy + Fang/Ooze/Watcher) —
   still pending from the world-identity-capture session, untouched this session.
3. M1 combat slice itself (Envoy, sword+gun+shield, 3 enemies, 1 arena, Burn status) —
   not started.

## Open tensions
- Pyre name provisional (Temper art direction); Hollow true name unassigned.
- Palettes provisional pending Umbral/damage-type art pass (channel law holds).
- Sync-as-meter: default NO (narrative only); annotated in canon.
- CORE-FANTASY pillars are [YOUR CALL] drafts — developer homework, no deadline.

## Concepts introduced this session
- PreToolUse hooks: stdin JSON tool-call payload, exit 0 = allow / exit 2 = block,
  stderr surfaces to Claude on block. "Configured" ≠ "verified" — a hook can be wired
  correctly and still silently never fire; the only proof is deliberately tripping it.

## Do NOT redo
- Naming re-litigation: slate is LOCKED (LEXICON amendment rule — playtest/collision
  evidence + dated amendment only).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12).
- Do not rename statuses to lore words (REJECTED — ROADMAP NOT-list).
- guard.py: do not remove the `scripts/guard.py` self-path exemption or scan the
  guard's own source for banned/IP content — it's structurally self-referential.

## Files touched
scripts/guard.py · RISKS.md · BRAIN.md · HANDOFF.md (this file)
(prior session's bundle, committed alongside: LEXICON.md, WORLD-CANON.md,
CORE-FANTASY.md, GAME-RULES.md, CLAUDE.md, AGENTS.md, MECHANICS-REFERENCE.md,
ROADMAP.md, QUICKSTART.md, SETUP-AND-START.md)
