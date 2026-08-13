# HANDOFF — 2026-08-11 (M1 playtest gate run: ITERATE)
Milestone: 1 — Combat slice   Status: IN-PROGRESS, **NOT CLOSED** (M0 COMPLETE)

## M1 PLAYTEST GATE — VERDICT: ITERATE (2026-08-11, build d1dbab0, seed 0)
Verbatim answers in `1431eed`. The two FAILURES the re-gate must re-ask: (#2) "one
dominant meta-strategy: any reasonable way to kill works; no encounter nuance forcing
action/weapon/timing/positioning choices"; (#3) "failure must be orchestrated by the
player; enemies create no meaningful pressure." PRESERVE #4 fairness/legibility ("all
damage readable and fair"). Named tuning axis: enemy OUTPUT, not durability alone.

### Findings carried
- **G-1 CLOSED as FALSIFIED** (`e8d9979`/`1337754`) — clamp correct; was rendered-scale
  vs combat-geometry, resolved by P28. Still FORBIDDEN: `model_scale`; raising
  `combat_radius` or sword `reach` alone; AABB-derived radii.
- **G-2 knockback lacks temporal consequence** — AI is rule-correct; the unnatural feel
  is the ABSENCE of a reaction layer. Flinch resolves the successful-flinch case by
  construction (a flinched enemy emits no movement). Re-read at the re-gate, LOG ONLY.
  More knockback is contraindicated (recreates the gun push-out failure, BRAIN).

## SEQUENCING AMENDMENT (supersedes "gate → itch → M1 closed")
1. **M1 is NOT closed.** ITERATE is a legitimate outcome the prior sequence lacked.
2. **Export lane CLOSED** (`fdf0fa9`) — see `WEB-EXPORT-NOTES.md` (nothreads trade,
   scope fence, reopening condition). Draft upload optional; the post-re-gate itch
   upload stays MANDATORY (written M1 exit criterion).
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
- **GAME-RULES §3 needs THREE rules added by hand** (guard.py blocks agent edits):
  "distance preferences govern movement only"; Burn's duration-inheritance rule;
  the §2 governance-ladder terminus for any Candidate Principle the batch promotes.

**Coverage gap — read before trusting a green suite here.** A headless arena boot
exercises registration but NEVER engagement: the Envoy spawns at origin, enemies sit
beyond their detection radius, so no AI activates and a clean boot is a NULL result for
AI behavior. Automated coverage there is value-transfer only. `arena.gd` has no
assertion-level coverage and never had any; its wiring rests on play. The web smoke test
(`fdf0fa9`) is the only end-to-end evidence that live AI wiring works.

## ★ RE-GATE SESSION PIN (frozen build; read before running)
Same five questions, no fixes mid-session, all `debug_*` at authentic defaults —
including the batch's new `debug_validation_target_health` and
`debug_flinch_threshold_override`, which MUST be 0.0 (verify via arena.tscn having no
property overrides, don't remember it).
**VERDICT THRESHOLD IS ABSOLUTE, not comparative:** the bar is "a viable M1 combat
foundation despite primitive content." "Materially better than last gate" is context
only, never the test. Known shallownesses — windup thinness, no action repertoires, no
animation, no encounter composition — are OBSERVED, not fixed, and do not pre-decide
the verdict.
**Method:** play naturally for most of the ten minutes; probe deliberately near the end
— 9.13 cross-weapon cash-out (three bands: NEVER / SOMETIMES-with-intent /
ALMOST-ALWAYS), G-2 re-read now that flinch exists (LOG ONLY, no locomotion rule), 9.8
finisher-cycling cost (is 1-2-3-cancel-1-2-3 still costless?).
PASS → M1 closes, public itch build, Treat Rule fires, repertoire + P17 pull-forward
become next-milestone scoping. ITERATE → the finding becomes the repertoire's mandate.

## Do NOT redo
- `flinched` payload key is `recovery_deadline_set` — CONTRACT: true iff processing that
  flinch WROTE `_flinched_until_tick`. It names the observable write, not a design
  meaning, so it survives a future flip from non-extension to refresh. Never restore the
  old name `extended`: it read as the inverse of the mechanic on a first flinch.
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
