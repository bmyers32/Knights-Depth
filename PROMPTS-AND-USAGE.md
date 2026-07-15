# PROMPTS-AND-USAGE.md — What to Type, and When
For the human. Claude never loads this file. The slash commands live in
`.claude/commands/` and cost zero tokens until you type them.

## The one-time prompt (Session 0, after setup Checkpoint B)
```
Read CLAUDE.md, AGENTS.md, GAME-RULES.md. Confirm in <300 words: the purpose seed,
the 7 Prime Directives, the 3 truth homes, and HANDOFF.md's role. No code.
```
If the summary sounds right, the system is live.

## The commands — trigger → type this
| When | Type | What happens |
|---|---|---|
| Starting a normal session on milestone N | `/kickoff N` | Reads HANDOFF + the milestone's exit criteria, scans only what the milestone touches, states the plan, WAITS for your approval before code |
| Returning after a gap, or feeling stuck/flat | `/resume` | Skips all ceremony; reads HANDOFF only and offers one 30-minute win. Ceremony resumes after momentum |
| Before any commit | `/gate` | Verification checklist + GAME-RULES §1 spot-check; actually runs the tests, reports PASS/PARTIAL/FAIL |
| A mechanic feels ready to judge (or before spending art/juice time on it) | `/playtest <mechanic>` | Builds it runnable, hands YOU the 10-minute feel checklist, logs the verdict. Only you can pass this gate |
| Ending any session (no exceptions) | `/closeout` | Final gate → overwrite HANDOFF (≤120 lines) → ROADMAP/BRAIN capture → proposes commit → asks → pushes |
| Stuck >30 min on the same error, or something smells structurally wrong | `/recon <symptom>` | Read-only topology scan ending in ranked hypotheses + the cheapest experiment to falsify the top one |

## The session rhythm
```
/clear → /kickoff N (or /resume) → approve plan → build → /gate → /closeout → approve commit → /clear
```
Short evening? One commit + updated HANDOFF = a successful session. Stop there guilt-free.

## Ad-hoc prompt templates (paste and fill)
**Concept tutoring** (any time something's unfamiliar):
```
Before we build this: explain <concept> in 2-3 sentences for a Python dev, with a
Godot doc link. Then offer: you build it, or I drive and you review.
```
**Treat Rule session** (milestone done, or motivation low):
```
Invoking the Treat Rule. I want to pull <ROADMAP id or fun idea> forward. Scope it
to one session, run it through /gate like anything else, log it in HANDOFF.
```
**Design debate** (before a big decision):
```
Design question, no code yet: <question>. Give me the simplest baseline version
first, then 1-2 alternatives with what each trades off. Check MECHANICS-REFERENCE.md
for how the reference game handled it.
```
**New asset session**:
```
Adding assets from <source>. Before anything enters the repo: license check, then
ASSETS.md lines for each file, then wire them in.
```
**When Claude drifts** (over-formal, skipping gates, or bloating docs):
```
Re-read AGENTS.md Momentum Protocol / Verification Gate and continue accordingly.
```

## What you never need to prompt
The law files (CLAUDE.md → AGENTS.md + GAME-RULES.md) load automatically every
session. The guard hook blocks reference-game IP and law-file edits mechanically.
You never need to remind Claude of the rules — if behavior drifts, the one-liner
above points it back at the file instead of re-explaining.
