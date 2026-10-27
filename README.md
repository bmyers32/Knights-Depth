# Knight Depths

Top-down co-op action roguelite. Solo hobby project, built in Godot with GDScript.
Workflow and law files: see CLAUDE.md / QUICKSTART.md.

## Pins (no upgrades mid-milestone — GAME-RULES / CLAUDE.md stack table)
- Godot: 4.7 stable (win64) — engine exe lives at `C:\Godot\`
- GUT: 9.7.1

## Running tests (headless CI — /closeout runs this every session)
From the repo root, in PowerShell (the leading `&` is required):

& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd

Use the `_console.exe` for headless runs (it prints to the terminal);
the plain exe is the editor.

**Automated runs go through the harness** (2026-10-27), never the raw exe: it refuses to start
while any Godot is open (the editor, a playtest), times out and kills what it launched, and logs
every run to `build/test_timing.csv`.

    python -I tools/verify.py --tier 1|2|3 [--files a.gd] [--recipes r] [--mutation spec.json]
    python -I tools/godot_run.py --label NAME -- --headless -s addons/gut/gut_cmdln.gd
    python -I tools/mutate.py tools/mutation_specs/<spec>.json
    python -I tools/check_test_loops.py      # every test `while` loop must be visibly bounded

## Notes
- Shell is Windows PowerShell — bash snippets need translating.
- Test config: `.gutconfig.json` at repo root (hidden in Godot's FileSystem dock — normal).