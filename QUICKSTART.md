# QUICKSTART.md — Getting Started, In Order
One page. Details for every step live in SETUP-AND-START.md; prompts in
PROMPTS-AND-USAGE.md. Check boxes as you go.

## Evening 1 — Machine (SETUP-AND-START Phase A)
- [ ] Install Godot 4 standard build → pin exact version in README
- [ ] Install git → create PRIVATE `knight-depths` repo on GitHub/GitLab
- [ ] Install Claude Code (per official docs) → `claude --version` works
- [ ] Check `python3 --version` (Windows: if only `python` works, edit the command
      in `.claude/settings.json` to match)
- [ ] Make `~/game-assets-staging/` OUTSIDE the repo; every downloaded asset zip
      (Kenney All-in-1, KayKit, Quaternius) lives there — zips NEVER enter the repo

## Evening 2 — Repo + workflow (Phase B)
- [ ] Make `knight-depths/`, unzip this workflow package into it
- [ ] Godot → New Project in that folder → **Compatibility renderer**
- [ ] Add `.gitignore` (`.godot/`, `exports/`) → `git init` → commit → push
- [ ] Install GUT from AssetLib → enable plugin → `tests/test_sanity.gd` +
      `.gutconfig.json` → run `godot --headless -s addons/gut/gut_cmdln.gd` → green
- [ ] Project Settings → Physics Ticks per Second → **30**
- [ ] Run `claude` in the repo → APPROVE the imports dialog
- [ ] Verify the guard: ask Claude to write "Spiral Knights" into a game file → must
      be BLOCKED
- [ ] Paste the Session 0 prompt (PROMPTS-AND-USAGE.md) → summary sounds right →
      commit, push

## Weeks 1–2 — Milestone 0 warmups (Phase C)
- [ ] Warmup 1: official "Your First 3D Game" tutorial (Squash the Creeps), typed BY
      YOU, Claude as tutor only (scratch project, 2–4 hrs)
- [ ] Warmup 2: `/kickoff 0` → tiny arena in the real repo, built as a miniature of
      the sim/presentation split (3–6 hrs)
- [ ] Concepts met: scenes, nodes vs resources, signals, input actions, fixed tick,
      collision layers, typed GDScript
- [ ] `/closeout` → tick M0 → push → `/clear`

## Then — Milestone 1 (Phase D: ~6–10 sessions)
- [ ] Asset intake session (once repo exists, before or during M1 session 2): Claude
      Code imports ONLY what M1 needs from staging — KayKit knight + weapons +
      animations, glTF preferred — and writes ASSETS.md rows
- [ ] `/kickoff 1` → follow the session ordering in SETUP-AND-START Phase D
      (sim skeleton → movement → damage pipeline → enemies → shield → gun →
      Burn → arena `/playtest` → itch build)
- [ ] Every session: `/kickoff 1` or `/resume` → build → `/gate` → `/closeout` → push
- [ ] M1 done → take the Treat Rule

## File map (what's what)
| Read by | Files |
|---|---|
| Claude, every session | CLAUDE.md → AGENTS.md + GAME-RULES.md (the law) |
| Claude, per session | HANDOFF.md (baton, ≤120 lines) |
| Claude, on demand | ROADMAP.md · BRAIN.md · RISKS.md · MECHANICS-REFERENCE.md · ASSETS.md |
| Claude, when typed | .claude/commands/: kickoff · closeout · gate · recon · playtest · resume |
| Machine, always | .claude/settings.json + scripts/guard.py (IP + law-file enforcement) |
| You, once | QUICKSTART.md · SETUP-AND-START.md · PROMPTS-AND-USAGE.md · WORKFLOW-README.md |
