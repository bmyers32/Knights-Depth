# HANDOFF — 2026-08-11 (M1 playtest gate run: ITERATE)
Milestone: 1 — Combat slice   Status: IN-PROGRESS, **NOT CLOSED** (M0 COMPLETE)

## M1 PLAYTEST GATE — VERDICT: ITERATE (2026-08-11, build d1dbab0, seed 0)
Ten minutes, all `debug_*` exports verified at authentic defaults (zero property
overrides on arena.tscn's root — checked, not remembered). Verbatim answers:
1. "Strafing" — done partly because it felt good.
2. One dominant meta-strategy: any reasonable way to kill works. No encounter
   nuance forcing action/weapon/timing/positioning choices. Fights end quickly;
   player deliberately draws them out to observe mechanics.
3. Failure must be orchestrated by the player. Any base-level action avoids it.
   Enemies create no meaningful pressure.
4. All damage readable and fair. No unseen damage.
5. Nothing felt unavailable within current mechanics.

**Reading:** fairness and legibility (#4) PASS and must be preserved. #2 and #3 are
what fail. The batch must honestly flip both.

**Named tuning axis so it isn't missed: enemy OUTPUT (damage, attack cadence,
aggression).** Finding #3 shows durability tuning ALONE only lengthens fights
without making failure available — do not answer this with HP alone.

### Findings carried (post-gate, NOT fixed on the frozen build)
- **G-1 possible lunge-clamp/presentation mismatch:** the Envoy visually appears to
  phase into enemies around melee contact. Classify post-gate via an
  authoritative-position vs presentation check BEFORE any fix. Discriminator:
  ordinary walking has no collision at all (`_apply_move` is unconditional; ROADMAP
  P20 open) and a killing blow releases the clamp the same tick, so only phasing
  against a SURVIVING target mid-combo indicts the clamp. Clamp distance is summed
  `combat_radius` (Envoy 0.4 + Fang 1.0 / Watcher 0.8 / Ooze 0.7), all documented as
  eyeballed against the models.
- **G-2 knockback lacks temporal consequence:** displaced enemies immediately
  re-evaluate to APPROACH and walk back in. AI is rule-correct (fresh-geometry
  re-evaluation); the unnatural feel is the ABSENCE of a reaction layer between
  displacement and re-decision. This is evidence FOR the planned FLINCHED reaction —
  re-evaluate after flinch exists; no separate locomotion rule now. Lever order if
  it survives flinch: locomotion commitment-break > threshold tuning. **More
  knockback is contraindicated** (recreates the gun push-out failure, BRAIN).
  Code fact: after an interrupting hit 3, `_cancel_enemy_windup` arms the attack
  cooldown but NOTHING gates movement — the enemy re-decides locomotion the next
  tick and walks forward while disarmed.

## SEQUENCING AMENDMENT (supersedes "gate → itch → M1 closed")
1. **M1 is NOT closed.** ITERATE is a legitimate gate outcome; the prior sequence
   lacked this branch.
2. **Web export of d1dbab0 proceeds NOW as PIPELINE VALIDATION only** — itch upload
   as draft/private, to debug HTML5 quirks against a small frozen tested build.
   **This does NOT satisfy the M1 itch criterion.**
3. **The post-gate combat batch IS the ITERATE response.** Scope unchanged
   (flinch/pressure, vulnerability windows, charge retune, continuation window,
   enemy-by-enemy HP+threshold tuning from 3.7 evidence) PLUS the enemy-output axis.
4. **Batch exit criterion: RE-GATE.** Same `/playtest`, same five questions, same
   no-fixes discipline, on a frozen post-batch build. M1 closes on PASS —
   specifically honest flips of #2 (decisions exist) and #3 (failure realistically
   available) with #4 (fairness) preserved. That passing build becomes the public
   itch build and satisfies the M1 criterion.
5. **Treat Rule: the batch loses treat status** (it is now required M1 work). The
   rule fires at actual M1 closure instead.
6. **G-1 verification runs at the START of the batch, before flinch implementation**
   — a clamp regression would qualify as a defect fix under the fence amendment.

## Next action
Web export (pipeline validation, draft upload) → batch recon incl. G-1 → batch.
Full batch design: `.claude/plans/advisory-decision-consolidated-swirling-flamingo.md`
+ advisory v3. Committed pre-gate work: `d1dbab0` (i-frame/combo cadence fix — its
commit message holds the full probe narrative and consumer audit).

## Open tensions (carried)
- **26-vs-20:** a full 1→2→3 deals 26 to a 20 HP enemy. Now decided from gate
  evidence: HP is a lever but NOT the first or only one (see the output axis above).
  HP and each enemy's flinch threshold stay ONE co-authored decision per enemy.
- Burn's 12-total ratio shifts against any raised HP — re-feel in the batch.
- **Wand cadence (7.8 audit, recorded only, no tuning):** `fire_interval_ticks=15`
  vs the OLD i-frame 15 meant arrivals landed exactly at the boundary vs a
  stationary target, and every other shot was ABSORBED vs a target closing at
  3.0 u/s. At i-frame 5 those absorbs disappear, raising effective wand damage vs
  approaching enemies.
- All AI numbers, lunge/windup values, and i-frame 5 are unrefuted, never confirmed
  — the gate judged the loop as a whole, not any individual threshold.
- **GAME-RULES §3 needs THREE rules added by hand** (guard.py blocks agent edits):
  "distance preferences govern movement only"; Burn's duration-inheritance rule;
  the §2 governance-ladder terminus for any Candidate Principle the batch promotes.

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

## Do NOT redo
- Fence amendment (permanent, advisory §1): a pre-gate freeze never blocks narrow
  fixes to defects that invalidate what the gate measures; see BRAIN principle 10.
- `iframe_ticks_on_hit` is a CADENCE CAP, not just a mercy window; don't "fix" the
  fixture by relaxing its assertion. Why: BRAIN + `fang_stats.gd`.
- Integration fixtures stay scoped to defensive-vs-offensive seams, not every seam.
- Authored attack movement (`executing`) REPLACES input, never blends; verified by
  `envoy.gd`'s attack-before-move order + BRAIN's same-tick-transition entry.
- The lunge clamp is attack-authored movement, not collision; see ROADMAP P20.
- `windup` is never buffer-eligible (ROADMAP P22) — scope cut, not canon.
- Player poise is unconditional-cancel-on-any-hit in M1 (ROADMAP P23).
- Ally-filtering lives in `_is_valid_target`; never duplicate per-weapon.
- The `"returning"` AI state doesn't exist; disengage is instantaneous re-anchor.

## Concepts introduced (learning ledger)
A playtest gate can PASS on fairness and legibility while FAILING on decisions and
consequence — "feels good" and "is a game" are separate verdicts, which is why the
five questions are asked individually rather than as one overall impression.

## Files touched
10 × `game/content/**/*_stats.gd` + `damage_matrix.gd` (gate date/verdict stamped
into calibration notes per GAME-RULES §3) · `HANDOFF.md`
