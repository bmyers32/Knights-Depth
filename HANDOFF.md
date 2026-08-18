# HANDOFF
Milestone: **2 — Procedural depths. NOT STARTED.** No M2 gate item exists yet.
Last session closed the **P29 Watcher arc (PASS)**; the repo is between build items.

Frozen P29 point: `9378316` · closure record: `bf9db99` · suite **425/425 green**.
Public M1 build: https://bmyers32.itch.io/knight-depths

## Where things stand
M1 shipped and is closed. Everything since has been post-M1 combat work on the M2-era
docket, not M2 gate work: **P16** (shield bump + perfect parry) then **P29** (enemy action
repertoire → contextual Watcher selection). M2 itself — seeded floors, strata, elevators,
minimap, run-end screen, netcode spike — has **zero lines written**.

## Next action (pick one, no discussion needed)
1. **Start M2 properly** — `/kickoff 2`. Design against GAME-RULES §5's M2 row. This is
   the milestone-advancing choice and the one the project's own gating wants next.
2. **Take a Treat** (AGENTS.md Momentum Protocol — available now, P29 just closed).
   ROADMAP has fun items ready: **P1 bombs**, **P30 wand commitment/reward**,
   **P31 reflected-projectile parry**, **P17 family movement identities**.
3. **Clear a follow-up** from the P29 docket below.

## P29 follow-up docket (dispatched, none are blockers)
Each has a named trigger in its ROADMAP entry. Most likely to fire first:
- **Melee-range animation readability** → **P32** (+ P28's open revalidation trigger).
  Gates melee parry AND P28's weapon-reach/contact re-check. There is still no sword model
  or attack animation; melee has no "now" moment to time a parry against.
- **Kiting-punisher family** → **P17**. Owns the infinite-kite answer (see below).
- Survey package escalation (+ disguise fence) · aim-lock fork → **P29**
- Reflected-projectile parry → **P31** (replaces a banked mechanic; needs its own fork review)
- Wand commitment/reward → **P30** · Family movement identities → **P17**

## Open items / live fences
- **NUMERIC FENCE.** These are validated or ruled and do NOT move without a specific new
  playtest finding: `close_frustration_ticks = 90` (Watcher patience, PROVISIONAL; **60**
  is the recorded fallback), Survey package (`hit_radius` 0.20 / speed 7.0 / windup 34 /
  vulnerable 23–34), `engagement_delay_ticks = 10`, wand basic `flinch_capability = none`,
  all M1 HP/flinch thresholds.
- **`vulnerable_start_tick` is explicitly frozen.** Ruled: positioning determines which
  counterplay is available; the window is NOT to be moved so it becomes reachable from
  arbitrary ranged positioning.
- **Infinite-kite consequence (intended, watch only).** A player who never lets the Watcher
  close gets exactly ONE Survey — the episode never clears. Ruling: *"If infinite-kite ever
  proves too safe, that becomes evidence for a new episode-reset rule — never a reason to
  weaken one-survey-per-episode preemptively."*
- **GAME-RULES §3 aim law preserved.** Action-lock only. Correct phrasing, use verbatim:
  *"Movement during windup changes the eventual fire-tick aim; it does not defeat the shot
  by invalidating a previously locked target position."* Aim-lock is a filed fork, never a
  workaround.
- **Naming fence.** The close-frustration gate is deliberately narrow
  (`requires_close_frustration`, `close_frustration_ticks`, `_close_frustration_satisfied`).
  Generalise to a context framework **only** when a second real consumer exists.
- **ROADMAP prune is DUE at M2 close** — Index has **31** live entries (cap 20). Not
  mandatory until milestone completion. P16 / P28 / P29 are the obvious tombstone candidates.
- Carried from M1: three GAME-RULES §3 rules still want a human edit · **P14** working title
  (itch slug now permanent) · P16 BUMP pass-through (P20) · 5.10 chain-flinch feel.

## Traps this repo has actually sprung (read before touching these areas)
- **Presentation is test-exempt, so it is the blind spot.** A shared component under
  `actors/enemies/` (TelegraphIndicator) is used by the **player** too; deleting a method
  crashed the build with 416/416 green and a clean boot. `tests/test_presentation_contracts.gd`
  now guards method surface + drives one real player verb through the real arena.
- **Never re-record `tests/fixtures/ai_baseline_pre_p29.json`** to make a test pass. It is
  the M1-preservation gate; regenerate only for a deliberate, dated behaviour change.
- Run diagnostics **without** suppressing stderr, and confirm the mechanism fired before
  trusting numbers (a tool once printed a clean all-zero table having done nothing).

## Commands
- Suite: `& "C:\Godot\Godot_v4.7-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd`
- New `class_name`? run `--headless --import` first.
- Tools: `tools/record_ai_baseline.gd` (baseline regen — deliberate only) ·
  `tools/diagnose_projectile_geometry.gd` · `tools/measure_survey_cadence.gd`

## Concepts introduced (learning ledger)
Sim tick vs frame (`_physics_process` vs `_process`) · Command/Event plain-data boundary ·
service-locator autoload (ContentDB) · seeded RNG streams · fixed combat pipeline order ·
typed GDScript arrays (`Array[Command]`) · half-open interval conventions · Minkowski-sum
collision (projectile radius + body radius) · derived-vs-stored state (episode consumption
from two timestamps) · cosmetic prediction / dead reckoning (tracer) · golden-behaviour
baselines + normalizer allow-lists · guard clauses vs world facts (refresh before early
returns) · GUT scene-instantiation smoke tests.
