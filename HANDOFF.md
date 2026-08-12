# HANDOFF — 2026-08-11 (M1 playtest gate run: ITERATE)
Milestone: 1 — Combat slice   Status: IN-PROGRESS, **NOT CLOSED** (M0 COMPLETE)

## M1 PLAYTEST GATE — VERDICT: ITERATE (2026-08-11, build d1dbab0, seed 0)
Ten minutes, all `debug_*` at authentic defaults (verified, not remembered). Verbatim
answers in `1431eed`; the two failures, which the batch must honestly flip:
2. "One dominant meta-strategy: any reasonable way to kill works. No encounter nuance
   forcing action/weapon/timing/positioning choices. Fights end quickly; player
   deliberately draws them out to observe mechanics."
3. "Failure must be orchestrated by the player. Any base-level action avoids it.
   Enemies create no meaningful pressure."
Passing and to be PRESERVED: #4 fairness/legibility ("all damage readable and fair").
#1 strafing felt good; #5 nothing felt unavailable. **Named tuning axis: enemy OUTPUT
(damage, attack cadence, aggression)** — #3 shows durability tuning ALONE only
lengthens fights without making failure available; not HP alone.

### Findings carried (post-gate, NOT fixed on the frozen build)
- **G-1 CLASSIFIED (2026-08-12): combat-geometry vs rendered-scale mismatch, NO clamp
  defect.** Sim rests the Envoy exactly at the authored contact distance
  (`test_lunge_clamp.gd:96`); sim radii, scene capsules, and measured model extents
  were all authored independently and disagree — full numbers/caveats in `e8d9979`.
  **`combat_radius`/`reach`/Burn spread are UNTOUCHABLE (coupling):** model-accurate
  contact ≈3.2 vs sword reach 2.0/2.5 would stop the lunge outside its own reach.
  **LADDER:** (1) throwaway presentation-only per-model scaling, fastest means, judged
  by eye — NOT radius-matching; (2) FALSIFICATION — if it reads toy-scale the real
  defect is GLOBAL combat scale, its own deliberate pass; (3) stylization REFUTED.
  **Recording:** scale factors are tuning values — per model, dated,
  PROVISIONAL/UNVALIDATED, judged at the re-gate; no silent scene-file magic numbers.
  Mechanism chosen AFTER results (rule of two — none approved yet); whichever wins is
  presentation-only, never read by the sim.
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
2. **Export lane CLOSED** (`fdf0fa9`) — Web pipeline smoke validation passed; see
   `WEB-EXPORT-NOTES.md` (nothreads trade, scope fence, reopening condition). The
   itch DRAFT upload is optional/non-blocking; remaining unknowns are hosting-
   specific. The post-re-gate itch upload stays MANDATORY (written M1 exit criterion).
3. **The batch IS the ITERATE response.** Scope unchanged (flinch/pressure,
   vulnerability windows, charge retune, continuation window, enemy-by-enemy HP+
   threshold tuning) PLUS the enemy-output axis and the G-1 scaling experiment.
4. **Batch exit criterion: RE-GATE** — same `/playtest`, five questions, no-fixes
   discipline, frozen build. M1 closes on honest flips of #2 and #3 with #4 intact;
   that build becomes the public itch build.
5. **Treat Rule:** batch loses treat status (required M1 work); fires at M1 closure.

## ★ BATCH NORTH STAR (pinned)
**The gate's core finding: the player has no meaningful decisions and must cooperate
to fail.** Flinch is the STRUCTURE; what makes it matter is enemy durability, threat,
susceptibility differences, and vulnerability windows. No further infrastructure and
no G-1 polish beyond the throwaway experiment until the re-gate questions can be
answered. **NEXT ACTION — locked batch order:** G-1 throwaway visual-scale experiment
→ flinch/pressure implementation → dev-target mechanical validation → enemy-by-enemy
HP/output/threshold tuning from gate evidence → live batch playtest → re-gate.
Design: `.claude/plans/advisory-decision-consolidated-swirling-flamingo.md` +
advisory v3. `d1dbab0`'s message holds the probe narrative + i-frame audit.

## Batch item — sub-frame press/release (slot: after flinch core, before playtest)
Assume NEITHER bug nor synthetic-only artifact until evidenced. Observed in the web
smoke test: a synthetic click with press+release inside one 30 Hz frame produced NO
swing (`envoy.gd`'s `if/elif` sent `pressed`, never `released`); a 250 ms hold worked.
(a) RECON the real input→Command path — can both edges fall in one presentation frame
with only one forwarded? (b) TEST that an ultra-short press/release between adjacent
ticks never strands `_melee_hold` in `charging`. (c) Close with evidence either way.
M3: input sampling vs tick boundaries is a networking-inherited problem class.

## Open tensions (carried)
- **26-vs-20:** a full 1→2→3 deals 26 to a 20 HP enemy. HP is a lever but NOT the
  first or only one (see the output axis); HP and each enemy's flinch threshold stay
  ONE co-authored decision. Burn's 12-total ratio shifts against any raised HP.
- **Wand cadence (7.8 audit, recorded only, no tuning):** at i-frame 5 the absorbs
  that ate every other shot vs an approaching target are gone. Numbers in `d1dbab0`.
- All AI/lunge/windup values and i-frame 5 are unrefuted, never confirmed — the gate judged the loop as a whole, not any individual threshold.
- **GAME-RULES §3 needs THREE rules added by hand** (guard.py blocks agent edits):
  "distance preferences govern movement only"; Burn's duration-inheritance rule;
  the §2 governance-ladder terminus for any Candidate Principle the batch promotes.

**Coverage gap — read before trusting a green suite here.** Booting the real arena
headless exercises registration but NEVER engagement: the Envoy spawns at origin and
enemies sit ~16–17 units away, beyond their 8.0 detection radius, so no AI activates
and a clean boot is a NULL result for AI behavior. Automated coverage there is
value-transfer only (`test_content_registrar.gd` asserts every authored value reaches
sim, incl. `register_enemy_ai`'s tuning; `test_enemy_ai.gd` covers behavior on its own
hand-built sim). **arena.gd scope honesty:** no assertion-level coverage, and never
had any; its registration change is a verbatim move (diff review + clean boot +
value-level tests on what it delegates to), but the wiring INSIDE `_register_enemies`
(telegraph cache, `debug_force_aggro`, per-family gating) rests on play alone. Not
made worse; not claimed as covered. The web smoke test (`fdf0fa9`) did exercise live
AI end-to-end in a browser — the first real evidence that wiring works.

## Do NOT redo
- Fence amendment (permanent, advisory §1): a pre-gate freeze never blocks narrow
  fixes to defects that invalidate what the gate measures; see BRAIN principle 10.
- `iframe_ticks_on_hit` is a CADENCE CAP, not a mercy window; don't "fix" the fixture
  by relaxing its assertion (BRAIN + `fang_stats.gd`). Integration fixtures stay
  scoped to defensive-vs-offensive seams, not every seam.
- Authored attack movement (`executing`) REPLACES input, never blends; why:
  `envoy.gd`'s attack-before-move order + BRAIN's same-tick-transition entry.
- Scope cuts, NOT canon: lunge clamp is attack-authored movement, not collision
  (P20); `windup` never buffer-eligible (P22); player poise unconditional-cancel (P23).
- Ally-filtering lives in `_is_valid_target`, never per-weapon; `"returning"` AI state
  doesn't exist (disengage re-anchors instantly). Export policy: `WEB-EXPORT-NOTES.md`.

## Concepts introduced (learning ledger)
A gate can PASS on fairness/legibility while FAILING on decisions and consequence:
"feels good" and "is a game" are separate verdicts — hence five questions, answered
individually, never collapsed into one overall impression.

## Files touched
Session commits: `d1dbab0` i-frame fix · `1431eed` gate record · `e8d9979`/`1337754`
G-1 ruling · `da80b2d` BRAIN · `fdf0fa9` Web export preset + `WEB-EXPORT-NOTES.md`.
