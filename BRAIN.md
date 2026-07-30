# BRAIN.md — Wisdom
On-demand file (never auto-loaded). /closeout appends here when a session produced a
lesson that passes ALL four invariants. At each milestone completion, prune: merge
overlapping entries, delete anything a law in GAME-RULES already covers.

## Schema — every entry must pass all four (fail one → it's not wisdom, it's a note)
| Invariant | Requirement |
|---|---|
| Compression | Title <12 words, no qualifiers |
| Generative | Applies beyond the incident that created it |
| Falsifiable | Ignoring it → specific, nameable failure |
| Decompressible | Body expands into the full reasoning chain: incident, mechanism, failure-if-ignored, where else it applies |

## Wisdom

### A configured hook is not a working hook — trigger it to know
**Incident (M0):** `.claude/settings.json` wired the IP guard to `python3 scripts/guard.py`.
This machine's PATH only has `python`. The hook command failed to spawn, so `guard.py`
never ran — a file containing "Spiral Knights" written straight into `game/actors/`
with zero warning. **Mechanism:** a hook can be present, correctly matched, and
syntactically valid in settings.json while still never executing, because the failure
mode (bad interpreter name) is silent — no error surfaces during normal tool use.
**Failure if ignored:** any red-line enforcement mechanism (guard hooks, lint hooks,
pre-commit checks) can rot invisibly; trusting that "it's configured" substitutes for
verifying it actually fires. **Applies elsewhere:** every hook in this repo, any future
hook added at M3+ (netcode/save-schema guards), any cross-platform command wiring
(`python3` vs `python`, `node` vs path-qualified). Verify a guard by trying to trip it,
not by reading its config.

### New global class_name scripts need an editor scan before headless tests
**Incident (M0):** added `class_name ToySimWorld` in `game/sim/toy_sim_world.gd`, wrote
a GUT test referencing it, ran headless — `Identifier "ToySimWorld" not declared`.
**Mechanism:** Godot's global class registry (`.godot/global_script_class_cache.cfg`)
is only rebuilt by the editor's filesystem scan; the headless GUT command line
(`--headless -s addons/gut/gut_cmdln.gd`) does not trigger one. Fixed by running
`godot --headless --editor --quit-after 3` once to force the scan. **Failure if
ignored:** chasing a phantom "my code is broken" bug when the code is fine and the
class cache is just stale. **Applies elsewhere:** every future global class in this
project — `SimWorld`, `Command`, `ContentDB`, `DepthGenerator` (M1–M2) will all hit
this the first time they're added or renamed.

### A string-matched path check breaks the moment the caller's path format changes
**Incident (M0):** `guard.py`'s "root docs may name the inspiration" exception checked
`"/" not in lowered_path` on an absolute path — always false, since absolute paths are
full of separators. The exception silently never fired; writing legitimate content
("Spiral Knights") into `BRAIN.md`, a root planning doc, got blocked. **Mechanism:**
path-shape assumptions (relative vs. absolute, separator style) baked into a string
check instead of resolved with a path library. **Failure if ignored:** any future
path-based rule (file-scoping, protected-dir checks) breaks the same way, silently,
the first time the caller's path format doesn't match what the string check assumed.
**Applies elsewhere:** any hook/script in this repo that gates behavior on a file path
— always resolve with `pathlib`/`os.path`, never assume relative-vs-absolute shape.
