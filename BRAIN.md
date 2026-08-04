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

**Second occurrence (M1, gun session):** this repeated as a real GAMEPLAY defect, not
just a scripted-verification artifact — wand_A's own knockback (0.5, sword-scale)
displaced a stationary Fang sideways off the gun's straight aim line between
successive shots, at a real ~16-unit range (not out of reach at all — off the firing
line). Manual playtest caught it; nothing in the sim layer or the earlier scripted
checks would have, since a displaced-but-still-alive target produces no error, just a
shot that quietly stops landing. Fixed by giving the gun zero knockback rather than
tuning the distance down, since ANY nonzero knockback with a component perpendicular
to a repeat-fire weapon's line eventually walks the target off it. **Applies
elsewhere:** any future rapid-fire or multi-hit-per-action weapon (later weapon
classes, DoT-adjacent mechanics) — knockback and repeat-fire cadence are in tension by
construction; a discrete single-swing weapon (sword) can absorb it, a cadence weapon
generally can't.

### A ground-plane-only aim ray misses anything above ground level
**Incident (M1, gun session):** the Envoy's mouse-to-world aim intersected the camera
ray with a horizontal plane at ground height. Clicking Fang's feet worked; clicking
its torso or head silently aimed at wherever that ray crossed y=0 instead — which, for
a raised screen point, is well past the target, not at it. Manual playtest was the
only thing that caught it; the sim-only combat pipeline can't distinguish "aimed
correctly and the swing/shot missed" from "computed the wrong aim entirely," so this
was invisible to every headless test and scripted check written before the fix.
**Mechanism:** a camera ray through a screen point above a target's on-screen
silhouette still points somewhat downward (toward the camera's own look direction), so
it crosses y=0 beyond the target's horizontal position — the higher up the model's
body the cursor lands, the further past the target the ground intersection drifts.
Ground-plane-only math is only correct for something that IS at y=0. **Failure if
ignored:** any top-down/isometric camera project's click-to-target or ability-aim math
built on ground-plane intersection alone feels randomly unresponsive for anything with
vertical extent (any enemy taller than a doormat) — reads as a mysterious "hit
detection is broken" bug rather than the geometric certainty it actually is. **Applies
elsewhere:** every future aimable entity in this project (Ooze, Watcher, and beyond)
needs the SAME two-stage treatment (raycast real colliders on the dedicated
"aimable_targets" physics layer first, ground-plane intersection as fallback only) — an
enemy added without a collider on that layer, or without a `get_aim_anchor_position()`
method (on itself or its collider's parent), silently reverts to the broken
ground-plane-only behavior for any click on its body.

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

### A seeded RNG draw must happen before any outcome-dependent branch, not after
**Incident (M1, Burn contact-spread + combat RNG session):** Burn's proc roll was
first designed to live inside `_resolve_hit_on_target`'s non-lethal branch, mirroring
where i-frames get armed — the natural instinct, since arming a DoT on a corpse is
pointless. The locked spec caught this before it shipped: a lethal hit must still
consume exactly one roll, or two runs with an identical seed and identical commands
diverge the instant one of them happens to kill its target one hit earlier than the
other. **Mechanism:** RNG stream advancement is a property of "a roll was attempted,"
not "the roll's outcome mattered afterward" — gating the draw itself on a downstream
outcome (survival, in this case) makes the stream's state depend on gameplay state
that has nothing to do with randomness. **Failure if ignored:** the exact bug GAME-RULES
§1.3 seeding exists to prevent — "seed + command log" bug reports become unreliable
because identical inputs no longer guarantee identical outputs. **Applies elsewhere:**
any future post-hit RNG consumer (other status procs, crit rolls, loot rolls tied to
a killing blow) — draw before checking whether the target survived, never after.

### Cooldown/equip state keyed by actor_id silently follows a weapon switch
**Incident (M1, combat RNG session):** A test armed a long cooldown on a throwaway
`cooldown_burn` weapon, then switched the attacker back to the real test weapon
(0.0 fire_interval_ticks) expecting a clean slate — the next attack was rejected
anyway. `SimWorld._next_fire_tick` is keyed by `actor_id`, not `weapon_id`: cooldown
state belongs to the ATTACKER, shared across whatever weapon they currently have
equipped, by original design (predates this session). **Mechanism:** `set_equipped_weapon`
only changes which weapon's stats resolve an attack; it was never intended to reset
any of the attacker's other per-actor state (facing, cooldown). **Failure if ignored:**
any future runtime weapon-switching feature (a real player-facing cycle, a loadout
swap) will silently inherit whatever cooldown the PREVIOUS weapon armed — a fast
weapon switched-to right after a slow weapon's swing reads as randomly unresponsive.
**Applies elsewhere:** the eventual player-facing weapon-switch Command (currently
deferred, HANDOFF) needs an explicit design decision here — reset cooldown on switch,
or keep it shared — before it ships, not discovered via a confused playtester.

### The editor can silently rewrite a .tres, dropping fields matching script defaults
**Incident (M1, Burn/Ooze/Watcher session):** After `godot --headless --import` (run
to register new `class_name` scripts, per this file's own standing lesson),
`envoy_stats.tres`, `fang_stats.tres`, and `gun_stats.tres` all showed as modified in
git — every explicit field whose value equaled the script's own `@export` default had
been silently removed, leaving only `script = ExtResource(...)`. Values are
byte-identical in practice (the script default fills the gap), but the diff alone
looks like data loss. **Mechanism:** Godot's resource saver omits fields at their
default value as a size optimization; simply opening/scanning the project (even
`--headless --import`, not a full editor session) can trigger a resave of any `.tres`
the import step touches. **Failure if ignored:** a future session reviewing `git diff`
after an import step could mistake this for an accidental revert of tuned content and
"fix" it by re-adding values that were never actually lost — or worse, panic-revert a
real change sitting in the same file. **Applies elsewhere:** every `.tres` in the
project, every time `--headless --import` (or the editor generally) runs — always
diff the ACTUAL remaining fields against the script's defaults before treating a
`.tres` change as suspicious; a shrunk resource file is not automatically a bug.

**Second occurrence (M1, Phase D step 8 recon):** `sword_burn_A.tres` showed the
identical pattern mid-session — `weapon_class`/`base_damage`/`damage_type`/`reach`/
`cone_half_angle_degrees`/`knockback_distance` all dropped, `uid=` added, values
unchanged in practice. Confirms the lesson is a standing property of this
project's workflow, not a one-off from the session that discovered it.

### Instrument before trusting a bug report's hypothesized cause
**Incident (M1, pre-gate fix pass):** "Ooze retreat bug" arrived with a specific
hypothesis — sticky BACK_AWAY state — plus an ordered checklist to confirm it.
Instrumenting and reproducing the exact literal scenario proved the hypothesis
WRONG: the per-tick decision was already correctly stateless in both directions
(two new permanent tests confirmed it). The real defect, found by digging one
layer further instead of stopping at "hypothesis disproven, no bug here," was a
PRIORITY bug — retreat could pre-empt an attack that could otherwise land,
letting a player crowd an enemy inside its own minimum_attack_distance and
suppress its attack indefinitely. **Mechanism:** a human describing a symptom
("it keeps retreating and never attacks") reaches for the closest-fitting mental
model (state stuck) even when the real defect is a decision-ORDER problem that
produces a similar-looking symptom through an entirely different mechanism.
**Failure if ignored:** fixing the HYPOTHESIZED mechanism (e.g. hysteresis on
re-entering retreat) would have smoothed the visible jitter while leaving the
actual exploit live and undiscovered. **Applies elsewhere:** any future bug
report arriving with a proposed root cause — verify the literal hypothesis first
(instrument, reproduce exactly as described); a disproven hypothesis is a cue to
look one layer further, not a reason to close the report as already-correct.

### Reordering a shared decision's priority invalidates test setups, not just assertions
**Incident (M1, pre-gate fix pass):** making attack-priority outrank movement
preference (a locked defect fix) broke 3 existing AI tests that had never
directly asserted anything about attacks — they tested pure retreat/spacing
behavior, using a long `windup_ticks`/`fire_interval_ticks` to make attacks
"never happen" so retreat could be observed in isolation. Once cooldown-ready
started outranking distance, those same setups began attacking on tick 0 instead,
since a fresh actor's cooldown defaults to "ready" regardless of
`fire_interval_ticks` (which only gates the NEXT cooldown, after a first attack).
**Mechanism:** a test's isolation strategy often depends on an implicit
precondition ("this parameter combination makes behavior X unreachable") living
in the surrounding code's control flow, not in the test itself — changing that
flow's priority ORDER can silently invalidate the isolation without touching the
test's own assertions or looking like an obviously related change. **Failure if
ignored:** a reordering fix appears clean (few lines changed in one function)
while quietly breaking test coverage elsewhere in a way that's easy to patch
mechanically (make the assertion pass again) without noticing the test no longer
proves what its name claims. **Applies elsewhere:** any future change to a shared
decision function's condition ORDER in this codebase — re-examine every existing
test that reaches that function, not just ones whose assertions reference the
changed behavior directly.
