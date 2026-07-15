# SETUP-AND-START.md — Zero to First Code
One-time read for the human. Work top to bottom; each phase ends with a checkpoint you
can verify. Timeboxes are honest estimates for evenings/weekends — halve nothing.

---

## Phase A — Machine setup (~1 evening)

**A1. Install Godot 4 (standard build, not .NET).**
Download the current stable 4.x from godotengine.org (check the site — don't grab a
random mirror). You're writing GDScript, so the standard build is correct.
→ Write the exact version number into the repo README the moment you have it. That's
the pin (CLAUDE.md stack table: no engine upgrades mid-milestone).

**A2. Install git + create the private remote.**
Install git. On GitHub (or GitLab): create a **private** repo named `knight-depths`,
empty — no README, no license yet. GAME-RULES §1.12 applies from the first commit:
unpushed work doesn't exist.

**A3. Install Claude Code.**
Follow the current install instructions in the official docs (docs.claude.com → Claude
Code) — the install method has changed over time, so use the docs, not a blog post.
Verify with `claude --version` in a terminal.

**A4. Confirm Python is on PATH** (the guard hook needs it): `python3 --version` —
on Windows this is usually `python --version`. **Windows note:** if only `python`
works, edit `.claude/settings.json` and change the hook command from
`python3 scripts/guard.py` to `python scripts/guard.py`.

**A5. Optional but nice:** VS Code + the "godot-tools" extension if you prefer editing
GDScript outside Godot. The built-in editor is fine to start; don't yak-shave here.

**A6. Asset staging.** Create `~/game-assets-staging/` (outside any repo) and move all
downloaded asset zips there. Originals stay in staging permanently; only curated,
manifested imports ever enter the repo.

✅ **Checkpoint A:** `godot`, `git`, `claude`, and `python`/`python3` all run from a terminal.

---

## Phase B — Repo + workflow bootstrap (~1 evening)

**B1. Create the project folder and unzip the workflow.**
Make `knight-depths/`, extract the workflow zip into it so `CLAUDE.md`, `AGENTS.md`,
`GAME-RULES.md`, `.claude/`, `scripts/` sit at the root.

**B2. Create the Godot project *in that folder*.**
Open Godot → New Project → point it at `knight-depths/` (project.godot must land at
repo root, next to CLAUDE.md). **Renderer: choose "Compatibility"** — it's the only
renderer that exports to HTML5, and web builds are how friends will play your itch
uploads without downloading anything. For this art style you lose nothing.

**B3. .gitignore.** Create it with:
```
.godot/
exports/
*.tmp
```
(The `.godot/` folder is per-machine cache. Asset `.import` sidecar files, if present,
DO get committed.)

**B4. First commit + push.**
```
git init
git add -A
git commit -m "Bootstrap: workflow docs + empty Godot project"
git remote add origin <your-private-repo-url>
git push -u origin main
```

**B5. Install GUT (the test framework).**
In Godot: AssetLib tab → search "GUT" → install (it lands in `addons/gut/`) → Project
Settings → Plugins → enable GUT. Create a `tests/` folder with one trivial test file
`tests/test_sanity.gd`:
```gdscript
extends GutTest

func test_sanity():
    assert_eq(1 + 1, 2)
```
Create `.gutconfig.json` at repo root:
```json
{ "dirs": ["res://tests/"], "should_exit": true }
```
Then prove the headless pipeline works — this exact command is your CI:
```
godot --headless -s addons/gut/gut_cmdln.gd
```
(You may need the full path to the godot binary. Put the working command in the README —
/closeout runs it every session.)

**B6. Set the sim tick.**
Project Settings → Physics → Common → Physics Ticks per Second → **30** (GAME-RULES §1.8
documents 30 Hz sim / 60+ fps render). If you later find 30 feels coarse for combat,
raising it is a deliberate Change Log amendment, not a silent tweak.

**B7. Wire up Claude Code.**
In the repo root run `claude`. First launch shows a one-time approval dialog for the
`@AGENTS.md` / `@GAME-RULES.md` imports — **approve it** (declining silently disables
the law files). Then verify the guard hook: ask Claude to add the phrase "Spiral
Knights" to any file. It must be **blocked** with the Prime Directive 5 message. If the
hook errors instead of blocking, check the hooks page in the Claude Code docs and align
the field names in `scripts/guard.py` / `.claude/settings.json` — hook schemas have
evolved across versions.

**B8. Session 0 prompt.** Paste this as your first real message:
```
Read CLAUDE.md, AGENTS.md, GAME-RULES.md. Confirm in <300 words: the purpose seed,
the 7 Prime Directives, the 3 truth homes, and HANDOFF.md's role. No code.
```
If the summary matches your intent, the system is live. Commit + push anything touched.

✅ **Checkpoint B:** headless GUT run is green · hook blocks SK IP · Session 0 summary
sounded right · repo pushed.

---

## Phase C — Milestone 0: warmups (~1–2 weeks of evenings)

The point of M0 is that your first decisions on the real game aren't your first-ever
gamedev decisions. Two throwaway games, timeboxed, finished-not-perfect.

**C1. Warmup 1 — the official 2D tutorial (2–4 hours).**
Do "Your First 3D Game" (Squash the Creeps) from the official Godot docs — the project is now 3D low-poly, so learn the 3D node vocabulary first — **type it
yourself**, in a separate scratch project, largely without Claude writing the code.
Use Claude as a tutor ("explain signals like I'm a Python dev"), not as hands. This is
the one place hands-on-keyboard genuinely beats delegation: it installs the vocabulary
(scene tree, nodes, signals, input actions, `_process` vs `_physics_process`) that every
future session assumes.

**C2. Warmup 2 — tiny arena, inside the real repo (3–6 hours).**
Now in `knight-depths/`, run `/kickoff 0`. Build: a knight that moves with WASD
(define input actions `move_up/down/left/right`, `attack`, `block` in the Input Map —
names in config, never keycodes in scripts), a sword swing that's a short-lived hitbox
(Area3D), one dummy enemy with HP that dies. Crucially, build it as a **miniature of
the real architecture**: a tiny `sim/` with a SimWorld holding knight/enemy state,
input converted to Commands, mesh positions read from sim state. It will feel like
ceremony for something this small — that's the rehearsal. Ask Claude to explain the
split as you go; this is where Prime Directive 1 stops being abstract.

**C3. Concepts checklist** (have met all of these by M0 exit — met, not mastered):
scene tree & instancing · nodes vs Resources · signals (up) vs method calls (down) ·
input actions · fixed tick vs frame · collision layers/masks · typed GDScript
(`var hp: int = 10`, `func tick(dt: float) -> void`).

**C4. Close out:** `/closeout` → GAME-RULES §5 M0 row → tick Milestone 0 in CLAUDE.md
→ commit, push, `/clear`.

✅ **Checkpoint C:** two finished warmups exist · the tiny arena runs its sim headlessly
in a GUT test · M0 ticked.

---

## Phase D — Milestone 1 begins: the combat slice

`/clear`, then `/kickoff 1`. Expect ~6–10 sessions of 1–2 hours. A proven ordering —
each session ends with something visible or a green test (Momentum Protocol):

1. **Sim skeleton.** `sim/sim_world.gd`, `sim/command.gd`, `sim/event.gd` as plain
   classes (zero Node imports — the headless GUT test enforcing this IS the deliverable).
   SimWorld.tick() moves one entity from scripted MoveCommands. Boring on screen,
   load-bearing forever.
2. **Knight moves for real.** Input → Commands → sim → model interpolation. First
   moment the architecture pays rent visibly.
3. **Sword + damage pipeline.** 3-hit combo in sim ticks, hit detection, the 4-type
   damage matrix read from `content/` resources (§3). GUT tests: weak AND resist
   directions.
4. **First enemy** (data-driven stats in a `.tres`), death event, hit feedback.
5. **Shield + i-frames.** Block, break meter, knockback through the pipeline —
   i-frame durations in ticks, in config.
6. **Gun.** Projectile with travel time, through the same pipeline.
7. **Enemies 2 & 3 + Burn.** Status v1 in data; contact spread test.
8. **Arena + `/playtest`.** One handcrafted room, 10 ugly minutes, verdict logged.
   Iterate tuning (data changes only!) until PASS.
9. **Itch build.** Export (HTML5 via Compatibility renderer), upload, hand the link to
   one friend. Art comes from the staging folder via an asset-intake session: KayKit
   Adventurers (knight, weapons) + Character Animations, Quaternius monsters for
   enemies, Kenney for environment/UI/audio — glTF preferred, **every import logged
   in ASSETS.md the moment it enters the repo**.
10. `/closeout` M1. Then take the Treat Rule — you'll have earned it.

## Standing habits from day one
- Every session: `/kickoff N` (or `/resume` after a gap) → build → `/gate` before
  commits → `/closeout` → push → `/clear`.
- Tuning numbers live in `content/` and config. If you type a bare number into a
  script, the /gate will catch it — save it the trouble.
- Stuck >30 min on the same error: stop, run `/recon <symptom>`.
- Short evening? Minimum-session rule: one commit + updated HANDOFF = a good session.
