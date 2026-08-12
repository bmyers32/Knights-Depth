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

**Reading:** fairness/legibility (#4) PASS and must be preserved; #2 and #3 are what
fail, and the batch must honestly flip both. **Named tuning axis so it isn't missed:
enemy OUTPUT (damage, attack cadence, aggression)** — #3 shows durability tuning
ALONE only lengthens fights without making failure available; not HP alone.

### Findings carried (post-gate, NOT fixed on the frozen build)
- **G-1 CLASSIFIED (2026-08-12): combat-geometry vs rendered-scale mismatch. NO
  clamp defect.** Sim rests the Envoy exactly at the authored contact distance
  (`test_lunge_clamp.gd:96` asserts it); `_contact_distance` is just summed
  `combat_radius`. Three independently-authored extents all disagree — sim radii vs
  scene capsules (a uniform 1.0×3.0 copied default) vs measured model half-extents;
  full numbers + caveats in `e8d9979`'s commit message. ~2 units of overlap are
  authored in, and even the NARROWER model axis exceeds the authored radius always.
  **`combat_radius`/`reach`/Burn spread are UNTOUCHABLE (coupling):** model-accurate
  contact ≈3.2 vs sword reach 2.0/2.5 — raising radii would stop the lunge outside
  the Envoy's own reach and every hit would whiff.
  **Resolution = EXPERIMENT LADDER, not a settled decision:** (1) batch start — a
  THROWAWAY presentation-only per-model scaling experiment by fastest means, judged
  by eye so contact distance reads as plausible proximity; NOT radius-matching (false
  precision). Fang may need little correction, Ooze likely the most; judge the
  Envoy's own scale too. (2) FALSIFICATION — if scaled models read toy-scale, the
  real defect is GLOBAL combat scale, and only then consider the coupled
  reach/radius/spread retune as its own deliberate pass. (3) Stylization is REFUTED
  by the gate observation itself.
  **Recording requirement:** scale factors are tuning values — record per model with
  date, PROVISIONAL/UNVALIDATED, judge at the re-gate. **No silent scene-file magic
  numbers.** Mechanism chosen AFTER results (rule of two — no approved mechanism yet):
  per-resource field if scales are per-enemy; shared constant or import-scale fix if
  ~uniform. Whichever wins: presentation-only, never read by the sim.
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
1. **M1 is NOT closed.** ITERATE is a legitimate outcome the prior sequence lacked.
2. **Web export of d1dbab0 = PIPELINE VALIDATION only**, does NOT satisfy the M1
   itch criterion. Lane: templates+preset (user) → headless export + local HTTP
   validation (agent) → draft/private page (user) → quirks write-up → back to combat.
   Write-up must state: Web/itch validation proves packaging and browser
   compatibility ONLY; it does not substitute for later Windows desktop/Steam
   pipeline validation.
3. **The batch IS the ITERATE response.** Scope unchanged (flinch/pressure,
   vulnerability windows, charge retune, continuation window, enemy-by-enemy
   HP+threshold tuning) PLUS the enemy-output axis and the G-1 scaling experiment.
4. **Batch exit criterion: RE-GATE** — same `/playtest`, five questions, no-fixes
   discipline, frozen build. M1 closes on honest flips of #2 and #3 with #4 intact;
   that build becomes the public itch build.
5. **Treat Rule: batch loses treat status** (required M1 work now); fires at closure.

## Next action
Web export (pipeline validation) → batch recon incl. G-1 → batch. Design:
`.claude/plans/advisory-decision-consolidated-swirling-flamingo.md` + advisory v3.
Pre-gate work `d1dbab0`; its commit message holds the probe narrative + i-frame audit.

## Open tensions (carried)
- **26-vs-20:** a full 1→2→3 deals 26 to a 20 HP enemy. HP is a lever but NOT the
  first or only one (see the output axis); HP and each enemy's flinch threshold stay
  ONE co-authored decision. Burn's 12-total ratio shifts against any raised HP.
- **Wand cadence (7.8 audit, recorded only, no tuning):** at i-frame 5 the absorbs
  that ate every other shot vs an approaching target are gone. Numbers in `d1dbab0`.
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
- Authored attack movement (`executing`) REPLACES input, never blends; why:
  `envoy.gd`'s attack-before-move order + BRAIN's same-tick-transition entry.
- Scope cuts, NOT canon: lunge clamp is attack-authored movement, not collision
  (P20); `windup` never buffer-eligible (P22); player poise unconditional-cancel (P23).
- Ally-filtering lives in `_is_valid_target`, never per-weapon; the `"returning"` AI
  state doesn't exist (disengage is an instantaneous re-anchor).

## Concepts introduced (learning ledger)
A gate can PASS on fairness/legibility while FAILING on decisions and consequence:
"feels good" and "is a game" are separate verdicts — hence five questions, answered
individually, never collapsed into one overall impression.

## Files touched
10 × `game/content/**/*_stats.gd` + `damage_matrix.gd` (gate verdict stamped into calibration notes, §3) · `HANDOFF.md`
