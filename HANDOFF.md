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
- Pre-gate fix pass (multiple rounds, replayed by user): ally-filtering; hit-
  establishes-aggro; attack-priority-beats-movement-preference (closed a real
  crowding exploit); disengage-in-place with leash re-anchor (no return-to-spawn);
  Burn contact-spread transmits the source's REMAINING duration (fixed clump
  lethality). See git history for full detail — all still-locked invariants.
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
Superseded by the three manual-pass rounds below (Slice B is built; see those
sections for current status) — `/playtest` gate + itch.io build remain the next
real action once the manual re-pass on this round's lunge-clamp addition lands.

## Open tensions
- Per-run combat-seed derivation: still open M2 run-structure question (carried).
- All AI numbers (radii, windup/cooldown ticks, engagement-band distances) are
  first-pass/unvalidated, same as Burn's — calibrate together at the real gate.
- Watcher's natural-attack id (`watcher_pulse`) is a placeholder name.
- GAME-RULES §3 needs two new locked rules added by hand (guard.py blocks agent
  edits): "distance preferences govern movement only" (`sim_world.gd`'s STANDING
  RULE comment) and Burn's duration-inheritance rule.

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

## Manual-pass follow-up session (2026-08-05, after this file was last written)
Two rounds of manual-pass follow-up landed on top of Slice B: (1) interrupt-as-
graded-content, input buffer, charge-ready cue, arena geometry/debug exports —
5-item round, complete, 226/226 green; (2) forward lunge + charge windup + extended
mid-swing input buffer — the first multi-tick pending-attack execution window on the
player side (`SimWorld._melee_hold`'s 3-state charging/windup/executing record),
complete, 263/263 green. Full details in the conversation/plan file
(`four-changes-from-the-resilient-piglet.md`); two facts specifically flagged for
GAME-RULES-adjacent recording (guard.py blocks agent edits to GAME-RULES.md itself,
same STANDING-RULE workaround as before):
- **Player poise, M1 simplification**: player windup/executing attacks have NO
  poise in M1 — any non-lethal enemy hit cancels them unconditionally, never graded
  by `interrupt_strength` (no enemy content sets that field). Graded player poise
  (mirroring the player-interrupts-enemy mechanic) is future content work. Watch for
  "trading during lunge feels terrible" in the re-pass — the fix is future poise
  content, not a change to this slice.
- **Known limitation (updated by the third manual-pass round below)**: no
  authoritative movement collision exists anywhere in the sim — walking, enemy
  movement, and actor-vs-actor separation in general can still overlap and cross
  intended arena boundaries. The one exception: lunge's own contact pass-through
  is now fixed (see "Lunge pass-through fix" section below) — authored attack
  movement clamps to hostile contact; this is attack-authored movement semantics,
  not general collision. "Sim collision/bounds" (ROADMAP P20) stays open for
  everything else.
- Also captured to ROADMAP (deferred, not built): camera-follow (the fixed arena
  camera doesn't track the Envoy — noted when repositioning Watcher for visibility).
- `debug_show_attack_state` (arena.gd) prints the Envoy's live pending-attack state
  each tick when on — useful for the manual re-pass on buffer-boundary/materialization
  timing feel checks.
- **Confirmed, no code change**: the wand's lack of charge is already expressed as
  "no charge profile registered" content, not a weapon-type branch —
  `_apply_attack`'s `is_phased_melee = _melee_combo_profiles.has(weapon_id)` is a
  pure presence check. Future caveat: today's phased resolution machinery assumes a
  melee sweep; a future wand charge would still need the resolution layer taught to
  branch on resolution type (melee sweep vs. projectile spawn) via the same
  profile-driven pattern — not a Command-layer change, but not literally zero-code.

## Lunge pass-through fix (2026-08-05, third manual-pass round)
Authored melee lunge movement now clamps to hostile contact — a swept
segment-vs-circle check against the authoritative combined-combat-radii contact
distance (`SimWorld._contact_distance`, one shared formula/epsilon with Burn's own
`_actors_overlap`, `_CONTACT_PADDING=0.0` since Burn's existing formula has zero
tolerance today and nonzero padding isn't justified against it). 280/280 green.
Two records, both explicit per this round's spec:
- **Refinement to the lunge-constraints rule**: lunge still shares walking's world
  movement constraints exactly (both remain fully unconstrained — no walls, no
  bounds, no general body-blocking). Target-contact clamping is the *attack's own
  authored movement semantics*, not a collision layer — walking has no target, so
  there is no inconsistency between "lunge is now constrained by contact" and
  "walking still isn't."
- **ROADMAP P20 (sim movement collision/bounds) stays fully open** — walls, bounds,
  and general actor separation are untouched by this fix, which resolves only the
  lunge-specific pass-through defect (with the test suite as evidence, pending
  manual playtest confirmation).

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
