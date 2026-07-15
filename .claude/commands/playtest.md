---
description: Run the playtest gate (GAME-RULES §1.5) on a mechanic or milestone build
argument-hint: <mechanic or build being tested>
---
Playtest gate for: $ARGUMENTS. This gate exists because "polish before fun" kills
projects — a mechanic earns art/juice budget only by passing it.
1. Confirm a runnable build exists (export or editor run). If not, that's the first task.
2. Give the user this checklist to play against for 10 minutes, ugly graphics and all:
   - Did you ever do something *because it felt good*, not because it worked?
   - Is there a decision per encounter, or one dominant strategy?
   - Does failure feel like your fault (fair) or the game's fault (unfair)?
   - Readability: did you ever take damage you couldn't see coming?
   - What did you WANT to do that the game didn't let you?
3. Capture answers verbatim. Verdict: PASS (invest further) / ITERATE (change X, retest)
   / KILL (mechanic to ROADMAP graveyard with reasoning).
4. Result + date + the specific tuning values tested go into HANDOFF Open Tensions and,
   for shipped thresholds, into the calibration note (GAME-RULES §3).
Never mark a §5 playtest criterion passed on my own assessment — only the user plays.
