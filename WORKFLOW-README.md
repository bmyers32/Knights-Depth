# WORKFLOW-README.md — How this system works
One-time read for the human; Claude never loads this file.

## Design principle
Always-loaded files carry only law. Rituals are slash commands (zero tokens until
invoked). Hard constraints are hooks (zero tokens, can't be rationalized around).
State between sessions lives in HANDOFF.md + git, not in the context window.

## Token architecture — what loads when
| Layer | Files | Cost |
|---|---|---|
| Every session (launch) | CLAUDE.md → imports AGENTS.md + GAME-RULES.md | ~450 lean lines, the whole law |
| Once per session | HANDOFF.md (read by /kickoff) | ≤120 lines, capped |
| Only when invoked | /kickoff /closeout /gate /recon /playtest /resume | 0 until typed |
| On demand | ROADMAP.md, BRAIN.md, ASSETS.md | 0 until referenced |
| Never (enforced, not read) | scripts/guard.py via settings.json hook | 0 |

Note: `@imports` load at launch — they organize, they don't save tokens. That's why
AGENTS.md and GAME-RULES.md are kept terse: they're paid for every single session.

## The session loop
```
/clear → /kickoff <M> → [approve plan] → build → /gate before commits
       → /playtest when a mechanic needs the fun check
       → /closeout → approve commit → /clear
```
Rules: /clear between milestones and when switching session type (build↔bug↔design).
Never /clear with uncommitted work or an unwritten HANDOFF. /compact is a mid-session
stopgap only — never during verification (project-root CLAUDE.md survives compaction
and is re-injected, but conversation-only instructions are not).

## Bootstrap (Session 0)
1. Install Godot 4.7, pin the exact version in the repo README.
2. `git init`; create a PRIVATE remote (GitHub/GitLab) and push — GAME-RULES §1.12 applies from day one; add `.gitignore` (Godot: .godot/, exports/).
3. Open Claude Code in the repo. First launch will show a one-time approval dialog for
   the `@AGENTS.md` / `@GAME-RULES.md` imports — approve it (declining disables imports).
4. Verify the hook: ask Claude to add the phrase "Spiral Knights" to any file — it must
   be blocked. If the hook errors instead, check the current hook schema in the Claude
   Code docs (hooks page) and adjust settings.json / guard.py field names.
5. Install the GUT addon; create `tests/` with one trivial passing test and the headless
   sim CI script stub (`godot --headless -s tools/sim_ci.gd` pattern).
6. Bootstrap prompt: "Read CLAUDE.md, AGENTS.md, GAME-RULES.md. Confirm in <300 words:
   the purpose seed, the 7 Prime Directives, the 3 truth homes, HANDOFF's role. No code."
7. Start Milestone 0 with `/kickoff 0`.

## Maintenance rules (prevent the drift this system caught in its ancestor)
- Every file referenced anywhere must exist. A dangling reference is worse than a
  missing file — excise or create, never leave.
- HANDOFF cap is enforced socially at /closeout: if it exceeds 120 lines, narrative
  moves to the commit message. Duplicate bullets = the file is accreting; prune.
- BRAIN.md and ROADMAP.md get a prune pass at every milestone completion. ROADMAP is
  index-first: commands read the Index table only; dead entries become Graveyard
  tombstones. Git history is the archive — prune fearlessly.
- CLAUDE.md target: under ~200 lines including its tables. If it grows, move the
  outgrown section to a nested CLAUDE.md in the relevant subdirectory (nested files
  load when Claude reads files there — free until relevant).
- Run `/memory` occasionally: promote useful auto-memory notes into BRAIN.md or delete
  them, so the two memory layers don't diverge.
- Milestone 5's exit criteria are deliberately unwritten — write them at M4 exit, when
  you know what "MMO layer" realistically means for one person.
