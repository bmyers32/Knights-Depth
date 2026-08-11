# HANDOFF — 2026-08-11 (pre-gate i-frame/combo cadence fix)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
Probed, confirmed, and fixed a Sev-1 defect that made the M1 combo mechanic
effectively non-functional, then captured the post-gate combat batch's design.
1. **Confirmed integration defect:** target-global health-hit i-frames at 15 ticks
   self-suppressed the baseline sword's independently authored combo hits at ~6–7
   tick gaps. Corrected to PROVISIONAL 5 ticks through enemy content. A named
   real-content integration fixture now guards cadence × target-i-frame
   compatibility. **General lesson:** independently valid defensive timing and
   offensive cadence can become structurally incompatible when composed — recurs
   for burst guns (P26), multi-hit charges (P27), co-op attackers, and
   attack-speed changes.
   Probe evidence (real content, production registration path): hit 1 lands at
   t=4 (8 dmg), hit 2 at t=10 and hit 3 at t=17 both return
   `attack_absorbed/iframes`. 48 ticks of maximal spam dealt 24 damage — three
   repeats of hit 1 — instead of 26 per combo. Invisible to 280 green tests:
   every combo/charge test registered targets at iframe 0.
2. **Consumer audit (why the fix is content-only).** One value, one job — probe
   showed no same-attack re-hit (1 hit per swing per target), one hit each on two
   targets in a cone, and Burn DoT pulsing freely under full i-frames.
3. **The fix.** `iframe_ticks_on_hit` 15 → **5** on all three families (highest
   value preserving cadence with margin; binding gap is 6). Content only — no
   attacker-scoped i-frames, no ownership/scope change, no sword special-case.
   Guarded by `tests/test_combo_cadence_fixture.gd` (real content through
   `ContentRegistrar`: all three hits land with authored damage, AND
   `iframe_ticks_on_hit < smallest authored inter-hit gap`).
4. **`ContentRegistrar`** (new, `game/content/content_registrar.gd`) — the content
   → SimWorld registration path moved verbatim out of `arena.gd` so fixtures use
   the SAME entrypoint production does. A test that reimplements the unpack is what
   let this escape. Split `register_enemy_body` / `register_enemy_ai` so a fixture
   can register a target with REAL defenses and no autonomous behavior.
5. Docs: BRAIN (2 wisdom entries + `## Candidate Principles (pre-lock)` = the 9
   combat design laws), RISKS 15–17, ROADMAP P24–P27 + P19/P5 addendum updates.

290/290 headless (963 asserts). The guard was adversarially tripped: reverting
Fang to 15 produced exactly 3 failures naming the arithmetic, then restored green.

**Coverage gap — read before trusting a green suite here.** Booting the real arena
headless exercises registration but NEVER engagement: the Envoy spawns at origin and
enemies sit ~16–17 units away, beyond their 8.0 detection radius, so no AI activates
and a clean boot is a NULL result for AI behavior. Automated coverage there is
value-transfer only (`test_content_registrar.gd` asserts every authored value reaches
sim, incl. `register_enemy_ai`'s tuning; `test_enemy_ai.gd` covers behavior on its own
hand-built sim). Arena wiring rests on manual play. **arena.gd scope honesty:** no
assertion-level coverage, and never had any. This session's change is a verbatim move
— verified by diff review, clean boot, and value-level tests on what it delegates to —
but the wiring INSIDE `_register_enemies` (telegraph cache, `debug_force_aggro`,
per-family gating) rests on the boot alone. Not made worse; not claimed as covered.

Full batch design: the plan file
`.claude/plans/advisory-decision-consolidated-swirling-flamingo.md` + advisory v3.

## Not done / next action
**The only two M1 exit criteria (GAME-RULES §5) still open: the 10-min playtest
gate and the itch.io build.** Run `/playtest` as its own session, all `debug_*`
exports at authentic default (`debug_loadout_override=false`,
`debug_force_aggro=false`, `debug_enable_fang/ooze/watcher=true`,
`debug_show_attack_state=false`). Record, do NOT fix during the gate:
- 3.1 Guaranteed hit-3 interrupt: reliable payoff or trivializing?
- 3.2 Endless 1→2→3→1 cycling: does immediate re-entry feel costless?
- 3.3 After hit 1/2 contact, is the next hit reachable, or does knockback defeat
  the sequence? (Now that hits 2–3 actually land, this is a real question again.)
- 3.4 Post-hit shield cancel per hit incl. finisher: deliberate spacing control?
- 3.5 Charge vs basic: which did you pick each encounter, and why?
- 3.6 Burn contact tension after clamped-contact ignition: intentional?
- 3.7 Per family, with full combos landing: hits/cycles to kill; does one-combo
  lethality feel right, cheap, or premature; does charge (20) read as a one-shot;
  does Burn get enough target lifetime to matter; does any enemy present a
  manipulation opportunity before death?
- **NEW watch-item:** the Envoy has NO health i-frames (`arena.gd` passes a
  hardcoded 0; `EnvoyStats` has no such field). Do overlapping or closely spaced
  enemy hits produce unfair burst damage? A positive finding triggers DIAGNOSIS in
  the post-gate batch — adding an `EnvoyStats` field is a candidate fix, not the
  pre-approved one.
- Carried: "trading during lunge" feel (player poise is ungraded — ROADMAP P23).
After a PASS verdict: itch.io HTML5 build is the last remaining gate item.

## Open tensions (carried)
- **26-vs-20:** a full 1→2→3 now deals 26 damage to a 20 HP enemy, so a baseline
  enemy dies to one combo and a finisher-flinch could never be observed on it.
  DELIBERATELY NOT FIXED pre-gate — decided from 3.7 evidence, enemy-by-enemy,
  with raising HP the preferred first live lever (never a blanket bump, and don't
  lower sword damage first unless the gate indicts sword damage specifically).
  HP and each enemy's flinch threshold are ONE co-authored decision.
- Burn's 12-total ratio shifts against any raised HP — re-feel in the batch, no
  preemptive Burn retune.
- **Wand cadence (7.8 audit, recorded only, no tuning):** `fire_interval_ticks=15`
  vs the OLD i-frame 15 meant arrivals landed at exactly the boundary against a
  stationary target (zero margin), and every other shot was ABSORBED against a
  target closing at 3.0 u/s (arrivals 11 ticks apart). At i-frame 5 those absorbs
  disappear — the fix raises the wand's effective damage vs approaching enemies.
  Watch it at the gate; do not tune the wand.
- All AI numbers, lunge/windup values, and the new i-frame 5 are first-pass and
  unvalidated — calibrate together at the gate.
- **GAME-RULES §3 needs THREE rules added by hand** (guard.py blocks agent edits):
  "distance preferences govern movement only"; Burn's duration-inheritance rule;
  and the §2 governance-ladder terminus for any Candidate Principle the batch
  promotes. The first two are already enforced in code via STANDING RULE comments.

## Do NOT redo
- Fence amendment (permanent, advisory §1): a pre-gate freeze never blocks narrow
  fixes to defects that invalidate what the gate measures; see BRAIN principle 10.
- `iframe_ticks_on_hit` is a CADENCE CAP, not just a mercy window; don't "fix" the
  fixture by relaxing its assertion. Why: BRAIN + `fang_stats.gd`.
- Integration fixtures stay scoped to defensive-vs-offensive seams, not every
  seam; verified by BRAIN's second wisdom entry.
- Authored attack movement (`executing`) REPLACES input, never blends; verified by
  `envoy.gd`'s attack-before-move order + BRAIN's same-tick-transition entry.
- The lunge clamp is attack-authored movement, not collision; see ROADMAP P20.
- `windup` is never buffer-eligible (ROADMAP P22) — scope cut, not canon.
- Player poise is unconditional-cancel-on-any-hit in M1 (ROADMAP P23).
- Ally-filtering lives in `_is_valid_target`; never duplicate per-weapon.
- The `"returning"` AI state doesn't exist; disengage is instantaneous re-anchor.

## Concepts introduced (learning ledger)
Test/production divergence via parallel content unpacking: two code paths reading
the same `.tres` files drift silently, so a fixture that hand-builds what
production registers can pass forever while production is broken — the reason
`ContentRegistrar` is a shared entrypoint rather than a convenience.

## Files touched
`game/content/content_registrar.gd` (+`.uid`, new) · `game/arena/arena.gd` ·
`game/content/enemies/{fang,ooze,watcher}/*_stats.gd` (+ooze/watcher `.tres`) ·
`tests/test_{combo_cadence_fixture,content_registrar}.gd` (new) · `BRAIN.md` ·
`RISKS.md` · `ROADMAP.md` · `HANDOFF.md`
