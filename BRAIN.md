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

## Milestones
**M0 closed** (warmups, repo/workflow bootstrap). **M1 closed 2026-08-13** — combat
slice, re-gate PASS on frozen build `41ffd5a`, public build at
https://bmyers32.itch.io/knight-depths. Every entry below was earned during M0–M1.
Milestone-completion prune performed at M1 close: no entry was found redundant against
a GAME-RULES law, and none overlapped enough to merge — the two pairs that share a root
(verdict/line-count, and quiescence/timestamps) already cross-reference each other and
are load-bearing separately, so both were kept deliberately rather than by omission.

## Wisdom

### Quiescence: "stopped acting" is not "idle"
**Incident (M1, flinch dev-target validation):** three of four test failures in one
session shared a cause. A fixture drove combo taps, stopped, then measured pressure and
deadlines — but the input buffer had a press QUEUED, which materialized on its own ticks
later and landed a surprise hit that banked fresh pressure and broke an expiry
assertion. Separately, the tap driver ended mid-cycle leaving an open `charging` hold,
so the next test's `pressed` hit `_begin_melee_hold`'s already-charging **silent no-op**
branch and the charge it was trying to measure never armed at all. **Mechanism:** an
input system with buffering and multi-tick execution has state that outlives the last
Command sent, and every one of its quiet failure modes is silent — a swallowed press and
a press that simply hasn't materialized yet look identical from outside.
**Failure if ignored:** measurements are taken against a sim still mid-action, and the
resulting assertions pass or fail for reasons unrelated to what they claim to test —
the most expensive kind of green suite. **The invariant:** before measuring post-action
combat state, establish that the actor has (1) no open attack execution or hold, (2) no
queued buffered press, and (3) passed any relevant attack-eligibility deadline. That is
`CombatTestHelpers.settle()`, deliberately one shared location — per-file copies are how
a timing rule drifts between fixtures. **Applies elsewhere:** rearm (if it lands),
switch-reset tech, charge sequencing, the deferred multi-hit model, and every M3
networking/replay test, where "has this actor finished acting?" becomes a question asked
across a wire.

### Count steps for executions; reserve tick deadlines for expiry
**Incident (M1, P16 bump slide):** the bump's authored displacement stored
`end_tick = tick_count + slide_ticks` and stepped while `tick_count < end_tick`. It
delivered **six** of seven steps. The record is created during one tick's *Command*
phase but first advances in the *next* tick's autonomous phase, so the window the
arithmetic describes and the window the stepping actually occupies are offset by one.
Fixed by storing `steps_remaining` and decrementing — after which the count cannot
drift no matter which phase creates or advances it. **Mechanism:** a tick deadline
answers "has the moment passed?", which is a question about *state*. An execution that
must perform exactly N discrete steps is asking "how much work is left?", which is a
question about *progress* — and reconstructing progress from two timestamps silently
imports every phase-boundary offset between them. The two questions look
interchangeable because both are expressed in ticks. **The rule:** absolute tick
deadlines stay correct and preferred for EXPIRY/ELIGIBILITY state — cooldowns
(`_next_fire_tick`), FLINCHED recovery, PARRY EXPOSED, pressure contribution expiry;
they compose (that is what makes `max(recovery, cooldown)` free) and there is no step
count to lose. But for an EXECUTION that must perform exactly N per-tick steps —
especially when creation and first advancement fall in different phases of the same
tick — carry explicit progress (`steps_remaining`, a step index) or use authoritative
`Event` timestamps, never start/end arithmetic. **Failure if ignored:** the execution
silently delivers N−1 steps, which reads as a *tuning* problem ("the bump feels short")
rather than an arithmetic one, so it gets "fixed" by inflating the authored distance
and the real defect ships. **Applies elsewhere:** this was the THIRD phase-boundary
off-by-one in a single session — see the entry below on `Event.tick`, and the
same-tick-transition entry further down. It will recur in any future multi-tick
authored execution: staged multi-hit charges (P27), recoil/dash displacement (P26),
M2's elevator transitions, and any M3 reconciliation that replays a partially-completed
execution across a wire.

### Events carry the authoritative timestamp, not tick_count
**Incident (M1, same session):** a fixture recorded `sim.tick_count` immediately after
`sim.tick()` returned and asserted a flinch deadline equalled `hit_tick +
recovery_ticks`. It failed by exactly one. `SimWorld.tick()` advances `tick_count` as
its final statement, so a read afterwards describes the sim AFTER advancement — one tick
later than the Events produced during that tick. **Mechanism:** the sim has two
legitimate notions of "now" — the tick being simulated, and the tick about to be
simulated — and the convenient one to reach for from outside is the wrong one for
describing something that already happened. **Failure if ignored:** every exact-deadline
or exact-expiry assertion is silently skewed by one tick, which reads as an off-by-one in
the MECHANIC rather than in the measurement, sending you to debug correct code.
**The convention:** `Event.tick` is the authoritative occurrence timestamp; use it for
anything asserting when something happened. Recorded here, in `SimWorld.tick()`'s own
comment, and in `CombatTestHelpers` — findable from all three directions, because a
convention that lives only in a commit message is not findable at all.
**Applies elsewhere:** every future timing assertion (status expiry, cooldown windows,
M2 elevator/floor transitions) and any M3 replay or reconciliation log, where an
off-by-one in event stamping corrupts the comparison itself.

### Never stamp a verdict the human hasn't rendered
**Incident (M1, playtest gate, 2026-08-11):** the user finished the ten-minute gate
saying "overall combat feels good... nothing else felt gate-blocking," then asked to
proceed to the itch build. Since the itch build is only reachable after a PASS, the
agent inferred PASS and wrote "verdict PASS" into ten content resources' calibration
notes. The actual verdict, delivered next message, was **ITERATE** — combat was fair
and legible but had no encounter decisions and no available failure. Ten files now
carried a false claim about a judgment only the player can make, in exactly the place
future tuning sessions look for authority. **Mechanism:** a verdict is a human
judgment, but its *consequences* (build, close-out, next milestone) look procedural,
so an agent tracking the procedure reconstructs the verdict from the next step being
requested rather than waiting for the words. The inference is often right, which is
what makes it dangerous — it fails silently and only in the cases that matter.
**Failure if ignored:** the project's own records assert a fun-verdict nobody gave,
and GAME-RULES §1.5's whole point (a mechanic earns budget only by passing a real
playtest) is defeated by a plausible guess. **Applies elsewhere:** every human-only
judgment in this project — /playtest verdicts, "is this fun," friend-playtest results
(M2+), the M4 auth design session. Record what the human said verbatim; if the verdict
itself is missing, the correct output is a blank marked "not yet rendered," never an
inference. **Shared root with the entry below:** an authoritative source was available
and a proxy was consulted instead.

### A line-count cap needs a counter that counts blank lines
**Incident (M1, same session):** HANDOFF.md has a hard 120-line cap. The agent checked
it with PowerShell's `(Get-Content f | Measure-Object -Line).Lines`, which does not
count empty strings — so ~11 blank lines vanished from every measurement. Reported
"118" and "106" were really ~128 and ~116; the file was silently over a HARD cap while
being reported as comfortably under it, across several trim cycles. Caught only by
running `wc -l` for an unrelated reason and seeing 131 where 121 was expected.
**Mechanism:** the cap is defined on physical lines, but the convenient tool measured a
subtly different quantity that agrees with the real one on most inputs — a proxy that
is correct until the exact moment precision matters. **Failure if ignored:** a "hard"
constraint erodes into an approximate one, and the erosion is invisible because the
measurement always reports success. **Applies elsewhere:** any enforced numeric limit
in this project (HANDOFF's cap, ROADMAP's 20-entry Index trigger, M2's <100 ms/floor
gen budget, future file-size or tick-budget limits) — verify the measurement tool
counts the thing the rule names, once, deliberately, before trusting it. Corollary
already learned the hard way here: PowerShell's `Get-Content` also mis-decodes UTF-8 as
ANSI, so console mojibake is not evidence of a corrupted file. **Shared root with the
entry above:** don't substitute a proxy measurement for the authoritative one.

### A defensive timer tuned in isolation becomes an offensive cadence cap
**Incident (M1, pre-gate i-frame probe, 2026-08-11):** every M1 enemy shipped
`iframe_ticks_on_hit = 15` — a defensive value chosen when the only question was "how
long is a target invulnerable after a hit." The sword's 3-hit combo, tuned separately,
resolves its hits 6 and 7 ticks apart. Probing the real content through the production
registration path showed hit 1 landing (8 damage, i-frames → 15), then hit 2 at +6 and
hit 3 at +7 both returning `attack_absorbed/iframes`. Forty-eight ticks of maximal
spam-tapping dealt 24 damage — three repeats of hit 1 — instead of 26 per combo. The
combo mechanic named in the M1 exit gate effectively did not exist, and nothing failed.
**Mechanism:** health i-frames gate INDEPENDENT SEQUENTIAL hits, so the same number that
reads as "defensive mercy window" is silently also the maximum rate at which ANY attacker
may land hits. Two teams of tuning — enemy defense and weapon cadence — write to one
shared variable from opposite directions, and neither authoring site mentions the other.
**Failure if ignored:** an authored attack sequence quietly loses most of its hits;
because an absorbed hit and a missed hit produce different-but-equally-silent outcomes
during play, this reads as vague "mush" rather than a defect with an address. Worse, the
value is invisible in the direction that matters — the Envoy is registered with
`iframe_ticks_on_hit = 0`, so in the shipped build this timer only ever regulates the
PLAYER'S damage output, never protects them. **Applies elsewhere:** every future rapid
or multi-hit weapon (Brandish-style staged charges, bombs, rapid-fire guns), the same
tension knockback already has with repeat-fire cadence (see the knockback entry below —
same shape, different variable), and the M2 typed_damage_ramp if defense values ever
scale per stratum. Any defensive duration must be written down alongside the fastest
offensive cadence it will ever gate: here, `iframe_ticks_on_hit < smallest authored
inter-hit gap`, now enforced by `tests/test_combo_cadence_fixture.gd`. Corollary: this
timer is also an implicit sampling rate for anything that accumulates per landed hit —
the M1 batch's flinch-pressure model inherits it directly.

### Convenience-zeroed defenses in tests hide the interactions worth testing
**Incident (M1, same probe):** the i-frame/combo defect survived 280 green tests because
EVERY combo and charge test registered its target with `iframe_ticks_on_hit = 0` and
hand-built its own attack profiles — a reasonable isolation choice per test, and a
structural blind spot in aggregate. No test in the suite ever put the real sword against
a target carrying real authored defenses. A parallel unpack of content into sim shapes
inside the tests made the divergence permanent: production and tests were reading the
same `.tres` files through two different code paths. **Mechanism:** unit isolation
deliberately removes the very interactions that only appear when two independently-tuned
subsystems meet; if no fixture ever re-assembles them, "all tests pass" measures each
part in a world where the other part is switched off. **Failure if ignored:** a mechanic
listed in a milestone exit gate can be fully implemented, fully tested, and
non-functional at the same time. **Applies elsewhere:** any combat seam where live
defensive values can suppress authored offensive cadence — keep at least ONE named
integration fixture per such seam, driving the production registration path with real
content. Deliberately NOT a mandate that every combat seam grow an integration fixture;
the trigger is specifically "a defensive value can cancel an offensive one."

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

### A same-tick state transition needs "did I cause it," not "did it happen"
**Incident (M1, lunge/windup pending-attack session):** two validation-pass
findings in the same feature. (A) `_apply_phased_melee_attack`'s synchronous
catch-up call checked ambient post-call state (`_melee_hold[actor].state ==
"executing"`) after calling `_release_melee_hold`, without confirming THIS call
caused the transition — a mid-swing buffered press's own "released" (its
`_release_melee_hold` call takes an early-return branch, touching nothing) could
still see an unrelated already-open "executing" record left by the tick's earlier
autonomous phase, and double-processed that tick's lunge movement. Fixed by
capturing pre-call state (`was_charging`) and gating the catch-up call on the
actual before/after transition, not the post-call snapshot alone. (B) `envoy.gd`
built the `move` Command before `attack`; on a tap-release tick that transitions
straight to "executing," ordinary WASD movement applied BEFORE the transition,
then the synchronous catch-up call ALSO applied the swing's first lunge step —
one tick blended free input with authored movement, breaking the locked "authored
movement replaces input" rule. Fixed by reordering `attack` before `move`.
**Mechanism:** when a sim tick has more than one entry point into the same
actor-keyed state record (an autonomous per-tick scan phase plus a synchronous
same-tick call triggered by a Command), logic gating on "is the state now X" must
distinguish "I just caused this transition" from "this was already true before I
ran" — otherwise an unrelated second caller reading the same post-state either
double-processes an effect or silently races against another Command's
ordering-dependent side effect. **Failure if ignored:** a duplicated one-tick
effect or a blended authored/input movement tick, both invisible to assertions
that only check final state — caught here only by a validation pass reasoning
through call order, not by any test that ran green. **Applies elsewhere:** any
future sim phase with more than one entry point into the same actor-keyed state
dict — a buffered input materializing into a state machine an autonomous phase
already advanced this tick, M2's elevator/floor-transition logic if it ever gets
a similar dual-trigger shape, and any M3 netcode reconciliation path where a
server correction and a normal tick advance the same actor's state in the same
frame.

### A measurement must prove its mechanism fired before its numbers mean anything
**Incident (P29 iteration, 2026-08-14):** a diagnostic script written to measure projectile
hit geometry printed a clean, plausible, fully-formatted table — every case reading
`measured_effective = 0.00`. The number was interpretable ("only dead-centre shots hit"),
which is exactly what made it dangerous. In fact `SimWorld.tick()` had rejected every
Command: the script passed an untyped `Array` where a typed `Array[Command]` was required,
the engine reported it on **stderr**, and the run had been invoked with `2>/dev/null`. No
projectile was ever spawned. The instrument measured nothing and said so in a format
indistinguishable from a result. **Mechanism:** an instrument has two independent failure
modes — the thing being measured can be wrong, or the measurement can never have happened
— and a well-formatted zero looks like the first while being the second. Suppressing the
channel where the engine reports the second is what makes them indistinguishable.
**Failure if ignored:** a diagnosis reports a false finding with full confidence, and the
"fix" that follows is aimed at a mechanism that was never running — the most expensive
possible outcome of measuring, worse than not measuring at all. **The rule:** before
trusting any measurement, assert that its mechanism FIRED — a non-zero count of the
intermediate the measurement depends on (here: projectiles actually spawned). Never run a
diagnostic with stderr suppressed. A result whose "no effect" case and whose "never ran"
case print identically is not yet an instrument. **Applies elsewhere:** every future
tools/ diagnostic, every calibration probe, the M2 gen-time budget measurement, and any
M3 latency/reconciliation harness — all of which will be read for their numbers by a
session that did not write them. Corollary, learned the same day: this is the
line-count-cap lesson's sibling — there the tool measured a subtly different quantity;
here the tool measured nothing at all.
**Second occurrence, same session, opposite direction — RE-VALIDATE AN INSTRUMENT'S SIGNAL
SHAPE WHEN THE MECHANIC CHANGES UNDER IT:** the survey-cadence tool computed gaps between
consecutive fires, so it needed at least TWO fires to say anything. Once Survey became
contextual it fires exactly ONCE per failed-close episode — and the tool printed "no surveys
observed", which reads as a dead mechanic when it was in fact the mechanic working
perfectly. The measurement code was still correct; what had changed was the SHAPE of the
signal it was built to see. An instrument silently inherits assumptions about its subject
(here: "this thing is periodic"), and those assumptions expire when the subject is
redesigned. **Rule:** when a mechanic changes character, re-read every instrument pointed at
it and make sure its zero/absent/degenerate cases still print something distinguishable —
"1 fire, not periodic" and "0 fires, gate never opened" are opposite findings and must never
share an output line.

### Enforce a rule with the same notion of the thing the rest of the sim uses
**Incident (P29, 2026-08-14, twice in one feature):** (A) action-band overlap was
enforced by a content-lint test using a sorted-adjacent `next.min >= prev.max`
inequality, while the selector decided eligibility with half-open/terminal-inclusive
`band_contains()`. The two disagreed on a degenerate band sitting on another's inclusive
maximum: the lint APPROVED a repertoire the selector treated as ambiguous. (B) swept
projectile collision compared distance-to-CENTRE against the weapon's radius alone, while
Burn contact-spread, the melee lunge clamp and P16's bump all consulted `combat_radius`,
the authoritative body. A wand shot needed to pass within 0.40 of an Ooze whose authored
body is 1.45 — shots crossing three-quarters of the visible body were "clean misses", and
it surfaced as the vague playtest complaint "apparent hits that miss". **Mechanism:** when
a rule is enforced (or a contact resolved) using a *re-derived* notion of the underlying
concept rather than the shared one, the two definitions agree on ordinary inputs and
diverge exactly at the boundaries — which is where the interesting bugs and the entire
point of the rule live. **Failure if ignored:** the guard certifies the thing it exists to
forbid, or one subsystem silently disagrees with every other about what "contact" means,
and the symptom reaches the player as feel ("it looks like it hit") rather than as an
error. **The rule:** one predicate, one source of truth, shared by the decider and every
enforcer — `band_contains()` for eligibility, `combat_radius` for bodies. If a check needs
its own copy of the definition, that is the defect. **Applies elsewhere:** every future
spatial query (M2 room/segment bounds, P20 walls and body-blocking, seeking projectiles),
any second content lint, and M3 server-side validation, where a server re-deriving "was
that a legal hit" differently from the sim IS the desync.


### Position is a world fact, not an activity fact — refresh it before every early return
**Incident (P29 Watcher selection pass, 2026-08-17):** the close-frustration mechanic rests
on one literal fact — the last tick the Watcher was actually inside its close band. The
refresh was written inside the per-actor decision function, which reads naturally, and was
placed after the function's existing guard clauses: the FLINCHED return at the top, and the
mid-windup return below it. Both are early returns, and both are common states — a melee
enemy spends most of its time in one or the other. So the "where was I" fact silently froze
for the whole of every windup and every flinch recovery. A Watcher standing in melee the
entire time accumulated frustration credit as though it had been kept at range, and would
fall back to its ranged action from point-blank. **Mechanism:** a guard clause answers "is
this actor able to act right now"; a positional fact answers "where is this actor". Placing
the second behind the first silently couples a property of the WORLD to the actor's
ACTIVITY, and every state that skips the decision logic then also skips reality. The bug is
invisible in code review because the refresh looks obviously present two lines above where
it is read. **Failure if ignored:** state that describes the world drifts out of sync with
the world in exactly the states that matter most (mid-action, mid-reaction), and the
mechanic built on it fires under conditions that never happened. **The rule:** facts about
the world are refreshed unconditionally, ahead of every branch that can skip work —
ideally in the phase that iterates actors, not inside the function that decides for one.
Facts about a decision may live with the decision. **Applies elsewhere:** any future
positional or environmental fact an AI accumulates (P18 territory/return-to-post, M2 room
occupancy, threat/aggro tables, and any M3 server-side state that must remain true whether
or not an actor was eligible to act that tick).
**Corollary, from the same mechanic the same day — a "never happened" sentinel must be
smaller than every real value it will be compared against.** Episode consumption was
derived by comparing two timestamps, with `.get(actor, -1)` standing in for "never
committed". A test aged the other timestamp negative, `-1 > -90` became true, and a survey
that had never occurred read as already spent. Numeric sentinels quietly participate in the
comparisons they were meant to sit outside of. Ask `has()` — absence is the honest test, and
it cannot be out-ordered.

### Boot-clean is not interact-clean
**THE LESSON, verbatim:** *"Boot-clean is not interact-clean — smoke verification must
exercise at least one core player verb, not just scene load."*

**PROCESS LESSON banked at P29 close (2026-08-18), verbatim:** *"A green suite and clean
scene boot only prove the paths they actually exercise. Shared presentation components need
at least one smoke that executes a core player verb through the real scene."*

**Incident (P29, 2026-08-17):** the vulnerable-cue rewrite replaced `TelegraphIndicator`
wholesale, carrying `flash()` forward and adding `mark_vulnerable()`/`clear()` — and
dropping `set_active()`, which no enemy uses and the ENVOY does, for its charge-ready cue.
The component lives under `game/actors/enemies/` and reads as enemy-only; it is shared with
the player. The build was committed and declared frozen on two green signals: 416/416 tests
and a clean headless arena boot. It crashed on the first mouse click, in
`_report_events -> envoy.clear_charge_ready() -> set_active()`.
**Mechanism — three independent gaps lining up, none of which is individually unreasonable:**
(1) GDScript resolves a method at CALL time, so a deleted method is not a parse error and
nothing failed at import; (2) the suite is deliberately presentation-free (CLAUDE.md exempts
presentation), so no test ever loads an actor scene or calls these methods; (3) the smoke
check ran `--headless --quit-after`, which loads the scene, ticks the sim, and exits —
**it never sends an attack**, and the charge cue only fires on a `charge_ready` Event that
only a player melee hold produces. Every signal was honest about what it measured; none of
them measured the thing that broke. **Failure if ignored:** a build passes every automated
gate and every reviewer, is tagged frozen, handed over for a playtest, and dies on the
first input — costing the playtest session itself, which is the scarcest resource in a solo
hobby project. **The rule:** a component under one subsystem's folder may still have
consumers elsewhere — grep the callers before deleting a method — and smoke verification
must drive at least one real player verb (attack, block, switch) through the real scene,
not merely construct it. **Applies elsewhere:** every future shared presentation component
(the projectile tracer already has two consumers), every "frozen build" handoff, and the M2
elevator/floor-transition and run-end flows, whose failure modes are likewise invisible to
a boot that never interacts.

### Never rewrite yesterday's baseline to describe today
**Lesson (verbatim):** "Never rewrite yesterday's baseline to describe today — retire its
gating role, preserve its evidence role. A historical fixture's value is proving what
changed." **Incident (P17 Fang recon — caught in recon, before it was suffered):**
`tests/fixtures/ai_baseline_pre_p29.json` records Fang's per-tick positions, built through
the production `ContentRegistrar` from the real `.tres`. Any authored change to Fang
locomotion turns it red. Because "a deliberate, dated behaviour change" is the sanctioned
reason to regenerate, the obvious move — re-record it — is *procedurally legal* and
destroys exactly what the artifact is for. **Mechanism:** a golden baseline holds two
distinct roles at once. Its GATING role ("nothing has drifted since") is meaningful only
while the recorded system is unchanged. Its EVIDENCE role ("this is what the system did on
that date") survives the change and is the only record of the prior state. Re-recording
silently swaps the evidence for a fresh assertion of the present — the artifact keeps its
authoritative name while proving strictly less. **Failure if ignored:** the suite goes
green, the fixture's header still calls itself a preservation gate, and nothing anywhere
proves what the change actually altered — so a later *unintended* drift through the same
shared decision function has nothing left to be caught against. **The rule:** when a
historical artifact becomes obsolete because the system lawfully changed, do not edit the
old artifact until it appears to have anticipated the new behaviour. Split the roles into
separate artifacts, each with exactly one job: preserve the original byte-for-byte as
evidence and retire its gating authority *in its own consuming test*; put the active gate
on an explicitly-named unaffected subject; create the new governing baseline separately,
only once the new behaviour actually exists. No half-retired fixtures, and no artifact
whose authority varies by row. **Applies elsewhere:** M2's golden-seed FloorPlan baselines,
M3 recorded net-traces, M4 save-schema round-trip fixtures. Shares a root with "Reordering
a shared decision's priority invalidates test setups, not just assertions" (the artifact
that catches such drift must stay honest) and "Never stamp a verdict the human hasn't
rendered" — an artifact must not claim authority it no longer earns.

### A different path is not a different decision
**Incident (P17, Fang approach weave, falsified 2026-08-19):** the playtest finding was
"enemy approach behavior feels too uniform". The answer shipped was a content-authored
zig-zag: Fang stopped walking a straight line and started weaving toward the player. It
worked exactly as designed, was fully tested, and the verdict was still ITERATE — "same
approach with wobble". **Mechanism:** the weave changed the SHAPE OF THE PATH while leaving
every quantity the player actually plays against untouched — spacing, timing, threat window,
and the difficulty of tracking the target with a ranged weapon. Two playtest questions
failed together (Q2 "does this read as a different family" and Q5 "is it harder to track")
and they were the same failure wearing two hats: nothing the player *does* changed, so the
new geometry registered as decoration on the old encounter. The tell was available before
the build — the design's own notes predicted "closing speed drops ~18%" and predicted
nothing at all about what the player would have to do differently. **Failure if ignored:**
you spend a full implement/test/playtest/revert cycle to learn something a single question
would have surfaced, and worse, the failure reads as "the numbers need tuning" (more
amplitude! shorter period!) when no value of a parameter fixes a mechanic that was never
addressing the finding. **The rule:** before building a behavior identity, state the
sentence "the player must now do X instead of Y". If X and Y are the same, the design
changes what the enemy LOOKS like, not what it IS, and no amount of tuning will convert one
into the other. Movement identity lives in the decision it forces — reach, timing, spacing,
commitment, punish window — never in the curve it traces getting there. **Applies
elsewhere:** every remaining P17 family identity, P18's idle wander, P19's mass/knockback
factor, and any future "make X feel more distinct" finding. Corollary earned the same day:
the falsified mechanic still paid for itself, because the experiment was *disposable by
construction* — content-authored, default-off, one sim expression, its own test file, and
its own dated baseline. Design experiments should be built to be deleted; the cost of being
wrong is exactly the cost of the revert.

## Candidate Principles (pre-lock)
Design laws captured from the post-M1 combat advisory arc. These are NOT wisdom entries
(no incident produced them) and NOT law yet. Governance ladder — the only path to
GAME-RULES.md: reference evidence → candidate principle here → repo inspection +
implementation need → batch playtest → GAME-RULES lock. Exception: rules required as
architectural invariants (determinism/authority class) may enter GAME-RULES without
playtest validation.

1. **Moveset coherence.** Sequential/multi-stage attacks are judged by the state each
   stage creates for the next. Under baseline conditions — the target takes no
   independent action between stages beyond consequences the attack itself authored —
   one successful stage must leave the next reasonably attainable, unless
   contact-breaking is explicitly authored weapon identity. Enemy evasion, spacing, and
   repositioning are legitimate counterplay, never a coherence violation. (Guard against
   misuse: this must never become "enemies hold still for combos.")
2. **Sequence economy.** A weapon's basic chain, finisher, charge transition, cancels,
   and reset/exit paths are competing exits from shared input state, balanced as ONE
   economy, never tuned independently. At every decision node, "why choose A over B?"
   must have an answer in both directions.
3. **Charge choice.** Every weapon line with a charge must answer both "why use the basic
   attack here?" and "why charge here?" No answer to either = structural defect. A charge
   is not mandatory content; add one only when it creates a real decision.
4. **Independence.** Flinch-trigger capability, pressure-contribution eligibility,
   knockback, damage, and status are independent authored dimensions. Never derive one
   from another.
5. **Expressible susceptibility.** The flinch system must stay able to express highly
   susceptible enemies that knowledgeable players can repeatedly manipulate.
6. **Test philosophy.** Mechanical tests protect simulation laws; a small number of NAMED
   content fixtures protect exemplar behaviors; tuning is validated by playtest, never
   encoded wholesale as arithmetic assertions across profiles.
7. **Commitment vs cancelable recovery.** Irreversible attack commitment and cancelable
   recovery are distinct. Shield/switch cancellation may end only execution authored as
   cancelable; a spawned projectile or a landed hit does not automatically erase
   remaining balance-bearing cost. **FENCE:** this does NOT authorize adding commitment
   locks to attacks that do not already need them. Commitment is content-authored risk,
   not a mandatory phase every attack must possess. The sword's existing post-hit shield
   cancel is authored-cancelable by design and stands; the gun's fire→spawn→free
   timeline needs nothing added (verified, recon 7.9).
8. **Switch persistence.** Switching changes the active weapon; it never IMPLICITLY
   resets weapon-owned state (cooldown, sequence step, charge, future ammo/heat/marks).
   Every persistent weapon-owned state CATEGORY has defined holstered semantics from a
   system-level default, with explicit content override where a weapon differs (default:
   cooldown CONTINUE, charge CANCEL; sword sequence may author RESET). Unequipping is
   never the hidden reason state changed. Any authored reset-on-switch stays subject to
   principle 2 and the bypass invariant: attack→switch→attack must never reach privileged
   sequence states more cheaply than the normal economy permits.
9. **Content-first escalation.** When observed play shows a problem: flip/tune cheap
   authored dimensions first; tune the content that OWNS the problem second; escalate to
   structural change only when existing seams demonstrably cannot express the result.
   Corollary: if an A/B comparison of authored content is expensive to run, fix the
   content seam before debating the content.
10. **Depth is composition, not compulsion.** Multiple viable approaches at differing
   effort/safety is desirable, not a defect; encounter depth must come from composing
   situations, never from converting combat into mandatory single-answer counters.
   Established at the M1 re-gate, where the player named the freedom to kill an enemy
   several ways — at different levels of effort and safety — as a thing they *liked*,
   while real decisions appeared under multi-enemy pressure. The failure mode this
   guards against is manufacturing "decision-making" metrics by making each enemy a lock
   with exactly one key. Verbatim fence recorded at ROADMAP P29.
12. **Combat mechanics have outpaced the enemy decision/movement layer.** A CURRENT
   PROJECT FINDING, not a universal law — recorded because it explains a class of feedback
   that would otherwise read as unrelated complaints. The P29 re-playtest found the
   Watcher fair, readable and parryable, and still "too interval-driven": every mechanical
   property was right and it continued to feel mechanical. The mechanics layer (windups,
   susceptibility windows, flinch routes, projectile geometry, parry) is now considerably
   richer than the layer that decides WHEN and WHERE an enemy acts, which is still
   approach / hold / attack-when-legal. Richness therefore bottlenecks on movement and
   choice, and further mechanical depth returns less and less until that layer catches up.
   **How to use it:** when a mechanically-correct enemy still feels flat, check whether the
   complaint is really about the mechanic or about the decision that preceded it before
   spending another iteration on the mechanic. **What it does NOT license:** building a
   selection/utility framework on this observation alone — the standing ROADMAP trigger
   (does the Watcher resume positioning before surveying again?) is deliberately narrower
   and must fire on its own evidence.

11. **A feature freeze does not freeze the thing being measured.** A pre-gate fence
   ("no new implementation before the playtest") never prohibits narrow fixes for
   CONFIRMED defects that invalidate the mechanics the gate exists to measure —
   otherwise the gate certifies a build whose headline mechanic does not function, and
   its verdict is worthless. Such a fix must preserve existing architecture, prefer
   content/data correction where sufficient, and re-run the full suite before the gate.
   Established when the M1 gate was about to measure a combo whose hits 2 and 3 were
   being absorbed. Generalizes to every future milestone gate and code freeze:
   distinguish "don't add scope" (always binding) from "don't repair the instrument"
   (never intended).
