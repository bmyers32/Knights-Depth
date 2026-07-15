---
description: Read-only topology scan of the repo (or a subsystem / stubborn bug)
argument-hint: [subsystem or symptom]
---
Read-only reconnaissance — no file modifications, no builds. Target: $ARGUMENTS
(whole repo if empty).
Produce a compact topology report:
1. Inventory: scenes, autoloads, sim/ modules, content resource families, gen pipeline,
   test suites — with the entry points into each.
2. Data flow: input → Command → SimWorld → Event → presentation. Flag ANY edge that
   bypasses this (a node mutating sim state, sim importing a Node type).
3. Coupling: what shares the sim (offline driver, future net driver, tests) — the blast
   radius map for the current milestone.
4. Defect scan against GAME-RULES §1: magic numbers, unseeded RNG, `_process` gameplay
   logic, deep node paths, unmanifested assets, computed-but-unused values.
5. Test coverage gaps in sim/ and gen/ (presentation is exempt by law).
6. If pointed at a bug: end with ranked hypotheses + the single cheapest experiment to
   falsify the top one (usually: replay the seed + command log).
Formatting: structured, terse, cross-referenced — written so it's still useful when
pasted into a future session.
