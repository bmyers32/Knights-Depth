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

**Second occurrence (M1, guard.py LEXICON update session):** the SK-IP content check
referenced `lowered_path`, a variable never assigned anywhere in `main()` — every trip
through that branch raised `NameError`, so the check had silently never functioned
since it was written, wired correctly in settings.json the whole time. It only
surfaced when the check was deliberately re-tripped via direct stdin invocation while
adding unrelated banned-term coverage — not through any error visible during normal
tool use. Confirms the lesson generalizes past interpreter-path failures to any silent
runtime bug inside a hook body. **Adjacent, same session:** `guard.py`'s own source
contains its banned/IP term lists as plaintext (`IP_BLOCKED_CONTENT`, `LEXICON_BANNED`)
— so editing the guard through the very tool calls it's meant to gate (Edit/Write) trips
its own content check, a permanent false positive requiring an explicit self-path
exemption. **Applies elsewhere:** any future denylist-style guard whose term list lives
in the same file it scans hits this by construction the first time someone edits it.

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

**Second occurrence (M1, sim skeleton session):** hit again cold, exactly as predicted
— adding `Command`/`Event`/`SimWorld` and a GUT test referencing them threw the same
parse errors on the first headless run; the `--headless --editor --quit` rescan fixed
it immediately. Confirms the lesson is genuinely load-bearing, not a one-off.

**Third occurrence (M1, Envoy sim pipeline session):** same failure on `EnvoyStats`
(new `class_name` in `game/content/envoy/envoy_stats.gd`) referenced from a GUT test.
This time `--quit-after N` raced the scan and got killed mid-import (0 `.import` files
generated); switched to `--headless --import`, which runs importing to completion and
exits cleanly on its own — the more reliable fix going forward.

### GDScript cannot override a native Object method with a different signature
**Incident (M1, Envoy sim pipeline session):** `ContentDB.get(family, id)` was
CLAUDE.md's documented Core Interface. Godot 4.7 hard-errors at parse time: `Object`
already defines `get(StringName) -> Variant`; a script redefining `get` with a
different signature is "Parse Error... Warning treated as error", not a soft warning —
the autoload fails to instantiate and the whole project fails to boot. **Mechanism:**
non-underscore-prefixed Object/Node methods (`get`, `set`, `free`, `connect`,
`duplicate`, etc.) are real engine methods, not overridable virtuals; GDScript allows
shadowing many identifiers but enforces signature compatibility for these. **Failure if
ignored:** designing a Core Interface method name before checking it isn't already an
Object/Node method — caught here only because the headless run failed loudly at
project boot; renamed to `get_resource()` and the CLAUDE.md line amended with the
constraint inline (`# Interface — do not drift` files still need updating when the
engine makes the literal name impossible). **Applies elsewhere:** any future
autoload/service-locator method name (`DepthGenerator`, `DebugOverlay`, M3 net driver
methods) — check the name against `Object`'s method list before writing it into a
contract doc.

### Inspiration vocabulary hides best in words that feel native
**Incident (design arc, pre-M1):** "Operator" survived eight rounds of naming review
that killed Navi, Net King, and Dark Web — because it felt original. It wasn't; it was
Battle Network's word for the same role. Separately, "corruption" sat at the center of
the design for seven documents unexamined, because it arrived as a genre premise
rather than a choice. **Mechanism:** review attention goes to words that SOUND
borrowed; loanwords that match the project's register pass every scan while silently
importing the source universe's assumptions. **Failure if ignored:** the world's
identity converges back toward its inspiration one "natural-sounding" word at a time;
guard.py can't flag what nobody listed. **Applies elsewhere:** every future
MECHANICS-REFERENCE translation session; any term that "just feels right" during
content design deserves one explicit "where did this word come from?" check before it
enters LEXICON.md.

### Design conversation converges; capture at the plateau or it re-expands
**Incident (design arc, pre-M1):** ten review documents followed a clean arc — dream,
critique, simplify, unify — but each round past convergence produced lateral renames
(Weave→Loom→Lattice) rather than improvements, and twice "reduce scope" arguments
concluded by adding systems (three companion loops proposed while warning against
parallel ecosystems). **Mechanism:** open-ended review always generates output;
without a capture deadline, generation continues past the point where changes improve
anything, and the expansion reflex returns disguised as refinement. **Failure if
ignored:** decisions stay perpetually provisional, law files never get written, and
banned vocabulary calcifies in drafts while the naming session is "almost done."
**Applies elsewhere:** status-roster design (P2), M4 progression design, any future
multi-session design debate — set the capture criterion ("vetoes only, then files")
when quality of changes turns lateral.

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

### Sibling asset packs silently duplicate bundled content — diff before trusting either
**Incident (M1, asset intake session):** KayKit's Adventurers pack bundles its own
`Rig_Medium_General.glb`/`Rig_Medium_MovementBasic.glb`. The separate, dedicated
Character Animations 1.1 pack ships files of the identical name covering a superset of
categories. Parsing both glbs' animation-clip names (via the glTF JSON chunk) showed
byte-for-byte identical clip lists — the Adventurers copies were pure duplicates, not a
cut-down subset. **Mechanism:** publishers bundle a starter slice of a companion pack
into a character pack for convenience; nothing in the filename or folder structure
signals "this is a duplicate," only inspecting actual clip/mesh contents reveals it.
**Failure if ignored:** importing both copies bloats the repo with redundant binary
assets and creates two sources of truth that silently diverge the moment either pack
updates. **Applies elsewhere:** the still-pending Kenney All-in-1 mega-bundle (likely
internally overlaps with itself across sub-packs) and any future KayKit character pack
(Barbarian/Mage/Ranger/Rogue) that bundles its own minimal animation set alongside the
dedicated Animations pack — diff clip/mesh names before assuming either copy is unique.

### Knockback silently invalidates a scripted sequence's next-step reach assumption
**Incident (M1, shield/i-frame session):** A headless scripted verification sequence
had the Envoy attack Fang twice in a row to demonstrate hit i-frames. The first
swing's own knockback (`weapon.knockback_distance`) pushed Fang from range 1.5 to 2.5
— outside the sword's 2.0 reach. The second "attack" silently produced zero events
(not even `attack_rejected`), because `_apply_attack`'s reach/cone check `continue`s
with no event for an out-of-range target. That looked identical to "i-frames
correctly absorbed the swing" until inspected closely. Hit again minutes later, same
session: a shield-break's own knockback moved the Envoy out of range for a
Fang-attacks-Envoy sequence staged right after it. **Mechanism:** an out-of-range
target and a correctly-absorbed/blocked attack both emit nothing distinguishable —
there is no "didn't even reach" event, so a scripted or manual check reading "no
damage happened, as expected" can be passing for entirely the wrong reason.
**Failure if ignored:** a verification sequence (headless script or manual playtest
choreography) silently validates a mechanic that never actually fired, because an
earlier step's knockback quietly moved a participant out of range. **Applies
elsewhere:** any future scripted verification or manual playtest chaining multiple
attacks/hits between the same actors — gun travel-time step, multi-enemy encounters,
combo sequencing (M1 step 6+). Always re-derive actor positions after a
knockback-producing event before trusting the next step's reach math, or reset
positions explicitly between scripted steps.

### glTF self-containment is per-file, not per-format — verify before copying
**Incident (M1, asset intake session):** Quaternius's `.gltf` monster files embedded
buffers and textures as base64 data URIs (fully self-contained despite the "external
reference" `.gltf` extension), while KayKit's `.gltf` weapon files referenced an
external `.bin` and a shared `weapons_bits_texture.png` by URI — same file extension,
opposite packaging. Checked by parsing each file's `images`/`buffers` JSON keys for
`bufferView` (embedded) vs `uri` (external) before deciding what to copy.
**Mechanism:** `.glb` guarantees single-file self-containment by spec, but `.gltf` is
just JSON — whether a given exporter embedded assets as data URIs or left them external
is a per-file choice invisible from the extension or folder listing alone.
**Failure if ignored:** copying only the `.gltf` for an externally-referenced pack ships
a mesh with no texture and no geometry buffer — silent broken-asset bug that only
surfaces when Godot tries to load it. **Applies elsewhere:** every future non-KayKit,
non-Quaternius asset pack (Kenney included) — never assume a `.gltf`'s packaging from
its sibling pack's convention; parse `images`/`buffers` per file before the copy step.
