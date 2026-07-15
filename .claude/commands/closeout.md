---
description: Close out the session — run before every /clear, no exceptions
---
Ending session. In order:
1. Run the AGENTS.md Verification Gate on all uncommitted work. Report PASS/PARTIAL/FAIL
   per item; PARTIAL/FAIL → list what remains, fix or defer explicitly, re-verify.
2. Run the headless sim CI script and GUT suite; paste the one-line result.
3. Overwrite HANDOFF.md per its template — cold-resumable without asking the user
   anything. HARD CAP 120 lines: resolved narrative goes into the commit message, not
   HANDOFF. Include the "Concepts introduced" learning ledger line.
4. If ALL GAME-RULES §5 exit criteria for the active milestone pass (including playtest
   gate + itch build): tick the milestone in CLAUDE.md, archive HANDOFF into the commit
   message, empty HANDOFF.md.
5. Any idea surfaced this session → ROADMAP.md: read ONLY its Index, add a row +
   full entry at the bottom (its token-discipline header is binding).
6. Any lesson passing all four BRAIN.md invariants → append to Wisdom. If we are at a
   milestone boundary, run the BRAIN prune pass.
7. New assets this session → confirm each has an ASSETS.md line.
8. Propose a commit message. ASK before committing. Never ship without consent.
9. After the commit: push to the private remote (GAME-RULES §1.12 — unpushed work
   doesn't exist). At milestone completion, also review RISKS.md, run the ROADMAP prune
   (delete SHIPPED/REJECTED entries → one-line Graveyard tombstones; mandatory if the
   Index exceeds 20 live entries), and remind the user the Treat Rule is available
   (AGENTS.md Momentum Protocol).
