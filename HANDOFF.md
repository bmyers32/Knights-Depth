# HANDOFF — 2026-08-13 (M1 combat RE-GATE: PASS)
Milestone: 1 — Combat slice   Status: PASSED re-gate; ONE exit criterion left

## M1 COMBAT RE-GATE — VERDICT: PASS (2026-08-13, frozen build `41ffd5a`)
Absolute verdict against the M1 bar — **a viable combat foundation despite primitive
content** — not merely "better than last time". Verbatim answers:
1. *"much better now. I can die sometimes when I get aggro from all three and try to
   manage them all at once. I was able to get hits and charge off. Definitely solid
   enough to build off on. Displacement and flinch looked good."*
2. *"not really, but I think that's just not enough depth to force me to do anything
   specific. I like the option of being able to get the kill with anything at varying
   levels of effort and safety... There are some decisions now, especially with multiple
   enemies, but individual enemies are still basic."* → **NOT an M1 failure.** Multiple
   viable approaches at differing effort/safety is DESIRABLE (see the P29 fence).
3. Failure without orchestration: **YES** — reverses the first gate's failure condition.
4. *"no incoming damage felt unreasonable"* — fairness preserved under doubled output.
5. *"Displacement and flinch looked good."*

**Probes:** 9.13 → **SOMETIMES-with-intent** (gate classification of an observed live
wand→switch→close→hit-3 cash-out; NOT a verbatim player phrase — never quote it as one).
G-2 → no locomotion rule justified; successful flinch supplies enough temporal
consequence. 9.8 → *"it doesn't feel costless... if I don't get in good position after
the 123 i am open for hits"* → **rearm NOT justified; ladder A sufficient.**

## Provisional ledger — CLOSED
- **5.10 non-extension** — MECHANICAL: **VALIDATED** (step-3 lifecycle tests; immutable
  by construction). General flinch feel: VALIDATED. **Sustained repeated chain-flinch
  feel: STILL OPEN** — the re-gate didn't deliberately exercise it, so no claim is made.
  Boundary is written at the sim site; do not collapse it.
- **charge = PRESSURE** — **VALIDATED** (second cash-out route; charge landed under real
  threat, neither trap nor dominant answer).
- **i-frame 5 · Step-6 enemy values · P28 radii · charge_threshold 40 ·
  pressure_window 90 · flinch_recovery 20** — **VALIDATED-FOR-M1**, this re-gate cited as
  the named calibration evidence in each §3 note. Means *sound as a foundation*, NOT
  individually optimised.
- **Rearm: CLOSED at ladder A.** Sequence-level rearm state retired UNUSED — existing
  finisher cadence plus positional exposure already carries the cost. Reopen only on new
  playtest evidence.
- **Wand EXPLOIT stays PROVISIONAL** — the 9.14 capability matrix was never run.
- **NUMERIC-TUNING FENCE:** no further HP/output/flinch-threshold micro-tuning until a
  specific future playtest finding demands it.

## Not done — the ONLY remaining M1 exit criterion
**Public itch.io build upload** (GAME-RULES §5). The passing build is `41ffd5a` (or this
bookkeeping successor — gameplay-identical, docs/notes only). The earlier draft page does
NOT satisfy it. Once uploaded: tick M1 in CLAUDE.md, archive this file into the close
commit, empty HANDOFF, **Treat Rule fires**.
Export: preset "Web" at defaults, nothreads variant → `build/web/` (gitignored). See
`WEB-EXPORT-NOTES.md` for the nothreads/SharedArrayBuffer trade and the scope fence
(Web proves packaging + browser compatibility only; desktop/Steam is a separate lane).

## Next milestone (NOT retroactive M1 work)
**ROADMAP P29** — enemy action repertoire / distance-conditioned action selection, with a
ranged action as the first second-action consumer, pulling P17's ranged archetype
forward. Carries the composition fence verbatim. Do NOT reopen the frozen combat build
for repertoire work before M1's close criteria are complete.

## Do NOT redo
- `flinched` payload key is `recovery_deadline_set` — CONTRACT: true iff processing that
  flinch WROTE `_flinched_until_tick`. Names the observable write, not a design meaning,
  so it survives a future flip to refresh. Never restore the old name `extended`.
- Sub-frame input (`5873244`): `envoy.gd` forwards BOTH edges, because both fire in one
  30 Hz tick for any click under ~33 ms; the old if/elif dropped the release and stranded
  `_melee_hold` in `charging` permanently. Don't re-collapse it to if/elif.
- `iframe_ticks_on_hit` is a CADENCE CAP, not a mercy window — it must stay below the
  smallest authored inter-hit gap or the combo absorbs its own hits (BRAIN + the fixture).
- Integration fixtures stay scoped to defensive-vs-offensive seams, not every seam.
- Authored attack movement (`executing`) REPLACES input, never blends.
- G-1 CLOSED as falsified; P28 RESOLVED (narrowed — it was mostly Ooze's footprint).
  Still FORBIDDEN: `model_scale`; raising `combat_radius` or sword `reach` alone;
  AABB-derived radii. Core silhouette (torso-band p50), never mesh AABB.
- Scope cuts, NOT canon: lunge clamp is attack-authored movement, not collision (P20);
  `windup` never buffer-eligible (P22); player poise unconditional-cancel (P23).
- Ally-filtering lives in `_is_valid_target`, never per-weapon.
- **GAME-RULES §3 needs THREE rules added by hand** (guard.py blocks agent edits):
  "distance preferences govern movement only"; Burn's duration-inheritance rule; the §2
  governance-ladder terminus for any BRAIN Candidate Principle promoted to law.

**Coverage gap:** a headless arena boot exercises registration but NEVER engagement —
enemies spawn beyond detection radius, so a clean boot is a NULL result for AI behavior.
`arena.gd` has no assertion-level coverage and never had any; its wiring rests on play.

## Concepts introduced (learning ledger)
Depth is composition, not compulsion: the re-gate's "no dominant strategy?" answer was
that having several viable ways to win at differing effort/safety is a FEATURE, and real
decisions emerged from multi-enemy pressure rather than from per-enemy counters.

## Files touched
Re-gate bookkeeping only: 10 × content calibration notes · `sim_world.gd` (5.10 evidence
boundary) · `ROADMAP.md` (P29) · `BRAIN.md` (principle 10) · `HANDOFF.md`.
