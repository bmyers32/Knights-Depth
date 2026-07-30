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

## Notes
- Shell is Windows PowerShell — bash snippets need translating.
- Test config: `.gutconfig.json` at repo root (hidden in Godot's FileSystem dock — normal).