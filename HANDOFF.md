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
- **G-1 CLOSED as FALSIFIED (2026-08-12)** — lunge clamp mechanically CORRECT; the
  defect was rendered-scale vs combat-geometry, resolved via P28 (see amendment 6).
  Detail: `e8d9979` / `1337754`. Still FORBIDDEN: `model_scale` fields; raising
  `combat_radius` or sword `reach` alone; AABB-derived radii.
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
6. **P28 RESOLVED for M1 (2026-08-13), barrier LIFTED.** Not a global rescale: core
   silhouette (p50 of the torso band, never mesh AABB) showed the defect was mostly
   Ooze at 0.70 vs a real ~1.45 body. Candidate A adopted PROVISIONAL: combat_radius
   Envoy 0.45 / Fang 0.90 / Watcher 0.85 / Ooze 1.45; Ooze preferred 2.20; each
   minimum = its contact distance; **sword reach unchanged 2.0/2.5** (max contact
   1.90). **OPEN revalidation trigger:** no sword model/attack animation exists, so
   reach/contact ALIGNMENT is unvalidated — recheck when real attack visuals land, and
   don't retune geometry for an animation problem unless contact itself proves wrong.

## ★ BATCH NORTH STAR (pinned)
**The gate's core finding: the player has no meaningful decisions and must cooperate
to fail.** Flinch is the STRUCTURE; what makes it matter is enemy durability, threat,
susceptibility differences, and vulnerability windows. No further infrastructure and
no G-1 polish beyond the throwaway experiment until the re-gate questions can be
answered. **BATCH ORDER:** 1. G-1 closed ✓ · 2. flinch/pressure core ✓ (`2165acc`) ·
3. dev-target validation ✓ (`890f2ce`) · 4. sub-frame input fix ✓ (`5873244`) · 5. P28
scale pass ✓ RESOLVED · 6. enemy HP/output/threshold tuning ✓ **PROVISIONAL PASS** —
live play now exposes pressure flinch, EXPLOIT flinch, repeated manipulation, and
credible enemy damage. **These values are the NEXT BASELINE — no further numeric
tuning until richer AI/encounter context produces a specific finding.**
7. **← NEXT: enemy action repertoire / distance-conditioned action selection**, with a
RANGED action as the first concrete second-action consumer. 8. re-gate AFTER that
richer encounter layer exists (moved later, deliberately).
Design: `.claude/plans/advisory-decision-consolidated-swirling-flamingo.md` + v3.

## Open tensions (carried)
- **26-vs-20 CLOSED** by step 6: HP now 45/70/38 vs a 26-damage combo. Burn's 12 total
  is now 27%/17%/32% of HP (was 60%) — weaker in relative terms. Re-feel item during
  the encounter-layer work; no preemptive retune.
- Combined output if all three converge is ~13 DPS (passive death ~2.3s). If that ever
  reads unfair, the Envoy's untouched 30 HP is the lever — do NOT walk enemy output
  back, it is what makes failure available (gate #3).
- **Wand cadence (7.8 audit):** at i-frame 5 the absorbs that ate every other shot vs an approaching target are gone. Numbers in `d1dbab0`.
- Lunge/windup values and i-frame 5 remain unrefuted, never confirmed.
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
- Sub-frame input CLOSED (`5873244`): `envoy.gd` forwards BOTH edges because both fire
  in one 30 Hz tick for any click under ~33 ms; the old if/elif dropped the release and
  stranded `_melee_hold` in `charging` permanently. Don't re-collapse it to if/elif.
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
