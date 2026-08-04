# HANDOFF — 2026-08-04 (Phase D step 8: real arena + enemy AI + defect fixes)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- Phase D step 8, all 5 phases: retired `game/dev/envoy_movement_dev.*` for
  `game/arena/arena.tscn` (now `project.godot`'s main scene). Fixed
  sword_burn_A+wand_A+shield loadout, switchable via a real `switch_weapon`
  Command (Q). Envoy death freezes input, shows a temporary overlay, R restarts.
  Enemy AI: idle/active state machine, home-leash, engagement-spacing band,
  windup/attack timing reusing the existing combat pipeline entirely.
  `debug_loadout_override` brings back the old 6-weapon TAB carousel for
  diagnosis only (default false — must stay false for `/playtest`/itch build).
- Pre-gate fix pass (multiple rounds, replayed by user): ally-filtering
  (same-allegiance never a valid target, checked first in the shared hit path —
  melee excludes allies, projectiles pass through); hit-establishes-aggro (a
  landed player hit/status activates AI regardless of detection_radius);
  attack-priority reorder fixing a real exploit — crowding an enemy inside
  minimum_attack_distance could previously suppress its attack indefinitely;
  distance preferences now govern movement only, never attack eligibility;
  disengagement rewritten — no universal return-to-spawn, an enemy that loses
  aggro stops in place, goes idle, and RE-ANCHORS its leash to the stop point;
  Burn contact-spread now transmits the source's REMAINING duration (snapshotted,
  capped at full), which alone fixed clump lethality, no number changes needed.
- Calibration: sword_burn_A proc chance 0.3 -> 0.15 post clump-burn replay
  (dated note in `sword_stats.gd`).
- Slice B (combo/charge) fully spec'd, NOT built — locked in `sword_stats.gd`'s
  "SLICE B SPEC" comment: per-hit combo profiles (sword_burn_A hits 1-2 proc 0.0,
  hit 3 configurable), charge selects its OWN content profile (never a hardcoded
  bigger normal hit), first charge = one charged strike, 100% Burn proc. Advancing
  multi-hit "Brandish" explicitly NOT Slice B baseline (ROADMAP P5 addendum).
- ROADMAP: P17 (engagement identities), P18 (idle wander/return-to-post/room
  territory), P19 (per-family mass/knockback, own proposal), addenda to P5.
- **176/176 GUT passing headless** (14 scripts, 658 asserts) — 3 new test files,
  5 existing files updated for ally-allegiance + attack-priority reorder.

## Not done / next action
1. **Slice B planning** opens next session — usual fork questions before code,
   locked spec above as input. Last M1 gate item before playtest is reachable.
2. Then: `/playtest` gate (log result) + itch.io build — both explicitly blocked
   on Slice B (GAME-RULES §5: "combo/charge/shield/i-frames in sim ticks").

## Open tensions
- Per-run combat-seed derivation: still open M2 run-structure question (carried).
- All AI numbers (radii, windup/cooldown ticks, engagement-band distances) are
  first-pass/unvalidated, same as Burn's — calibrate together at the real gate.
- Watcher's natural-attack id (`watcher_pulse`) is a placeholder name.
- GAME-RULES §3 needs two new locked rules added by hand (guard.py blocks agent
  edits): "distance preferences govern movement only" (`sim_world.gd`'s STANDING
  RULE comment) and Burn's duration-inheritance rule.

## Concepts introduced this session
- None explained fresh — this session was spec execution from the user's own
  fully-specified technical direction throughout.

## Do NOT redo
- `game/dev/envoy_movement_dev.*` is gone; `game/arena/arena.tscn` is the real
  thing and the main scene now.
- `debug_loadout_override` is diagnostic-only — never true for `/playtest`/itch.
- The `"returning"` AI state no longer exists — disengage is instantaneous
  (stop + idle + re-anchor). Don't reintroduce a homeward-pathing transit state.
- Attack priority always beats movement preference once cooldown is ready and
  the target is in reach — don't let a future engagement feature (P17/P18)
  quietly reopen the crowding-disarms-the-enemy exploit fixed this session.
- Ally-filtering lives in `_is_valid_target`, checked at candidacy time in the
  shared hit path — any future attacker type gets it for free; never duplicate
  the check per-weapon.
- sword_burn_A's 0.15 proc chance and all engagement-AI numbers are provisional.

## Files touched
`game/sim/sim_world.gd` · `game/arena/{arena.tscn,.gd}` (new) ·
`game/ui/failure_overlay.{tscn,gd}` (new) ·
`game/actors/enemies/telegraph_indicator.{tscn,gd}` (new) ·
`game/actors/enemies/{fang,ooze,watcher}/*` (telegraph wiring) ·
`game/actors/envoy/envoy.gd` · `game/content/enemies/natural_weapons/*` (new) ·
`game/content/weapons/sword_stats.gd`/`sword_burn_A.tres` ·
`game/autoload/content_db.gd` · `project.godot` ·
`tests/test_{ally_filtering,enemy_ai,weapon_switch}.gd` (new),
`tests/test_{burn,burn_spread,combat,content_db,gun,shield,status_proc}.gd` ·
`ROADMAP.md` — pending commit.
