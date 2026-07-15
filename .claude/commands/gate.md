---
description: Mid-session verification gate — run before any commit
---
Stop. Run the AGENTS.md Verification Gate on what was just built, plus a GAME-RULES
spot-check aimed at §1 specifically: no presentation writing sim state, no new magic
numbers, RNG seeded, gameplay on sim ticks not frames, no `get_node("../..")`, golden-
seed tests unchanged or deliberately re-baselined with a dated note, no SK IP, assets
manifested. Report PASS / PARTIAL / FAIL per item. PARTIAL/FAIL: list exactly what
remains, fix, re-verify. No success claims that haven't been adversarially tested
(actually run the tests and the headless sim script — do not assert from memory).
