# HANDOFF — 2026-08-05 (Slice B + 3 manual-pass rounds: lunge, windup, contact clamp)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
Slice B (3-hit combo + hold-to-charge) built to the full locked phased-attack
Command spec, then three manual-pass follow-up rounds on top, each with a
post-implementation validation pass (real bugs caught both times):
1. Interrupt-as-graded-content, extended input buffer (cooldown-only), charge-ready
   cue, arena geometry/debug exports. 226/226.
2. Forward lunge + charge windup — the sim's first multi-tick pending-attack
   execution window (`SimWorld._melee_hold`: `charging`/`windup`/`executing`
   3-state record); input buffer extended to cover mid-swing presses too (two
   deadline sources, one buffer, hard fence). 263/263.
3. Lunge-contact clamp — authored lunge movement sweeps against hostile contact
   distance (segment-vs-circle, shared `_contact_distance` formula with Burn's
   contact-spread) so a lunge can no longer pass through an enemy. Retained-clamp
   through knockback; cleared on target death/despawn same tick. 280/280.
Committed as `1c73113`. Full design/spec detail: conversation history + the
now-stale plan file `four-changes-from-the-resilient-piglet.md` (superseded by
the actual implementation — don't treat it as current spec).

## Not done / next action
**The only two M1 exit criteria (GAME-RULES §5) still open: the 10-min playtest
gate and the itch.io build.** Stage and run `/playtest` as its own session:
- All `debug_*` exports verified at authentic default THIS session (nothing to
  fix): `debug_loadout_override=false`, `debug_force_aggro=false`,
  `debug_enable_fang/ooze/watcher=true` each, `debug_show_attack_state=false`.
- Explicit watch-item for the playtest itself: "trading during lunge" feel
  (player poise is ungraded in M1 — see ROADMAP P23). The manual re-pass found no
  complaints, but that was scripted/directed testing, not a free-play read.
- After a PASS verdict, logged: itch.io build upload is the last remaining gate.

## Open tensions (carried)
- Per-run combat-seed derivation: still open M2 run-structure question.
- All AI numbers (radii, windup/cooldown ticks, engagement-band distances) and
  sword_burn_A's lunge/windup/fire_interval values are first-pass/unvalidated —
  calibrate together at the real playtest gate, not before.
- GAME-RULES §3 still needs two rules added by hand (guard.py blocks agent edits):
  "distance preferences govern movement only" and Burn's duration-inheritance rule
  — both already enforced in code via STANDING RULE comments in `sim_world.gd`,
  just not yet mirrored into the law file itself.

## Do NOT redo
- Authored attack movement (`executing` state) REPLACES input, never blends with
  it — this is why `envoy.gd`'s Command array builds `attack` before `move`. Don't
  reorder without re-deriving the same-tick transition consequence.
- The lunge-contact clamp is attack-authored movement semantics, not a general
  collision layer — it never targets allies, and ROADMAP P20 (general
  collision/bounds) stays fully open. Don't read the clamp as "collision is solved."
- `windup` state is never buffer-eligible today — a deliberate scope cut
  (ROADMAP P22), not a technical wall or a design law. Don't cite it as canon.
- Player poise is unconditional-cancel-on-any-hit in M1, not graded by
  `interrupt_strength` (ROADMAP P23) — future content, not a gap to silently fix.
- `debug_loadout_override`/`debug_force_aggro`/`debug_enable_*`/
  `debug_show_attack_state` are diagnostic-only — all must stay at their authentic
  default (see above) for `/playtest`/itch build.
- Ally-filtering lives in `_is_valid_target`; never duplicate per-weapon.
- The `"returning"` AI state doesn't exist; disengage is instantaneous re-anchor.
- Attack priority always beats movement preference once cooldown is ready and the
  target is in reach.

## Concepts introduced (learning ledger)
Multi-tick sim state machines: an autonomous per-tick scan phase
(`_advance_pending_attacks`) paired with a synchronous same-tick catch-up call
from a Command handler, both able to advance the same actor-keyed record —
see BRAIN.md's new entry for the general lesson this surfaced twice.

## Files touched
`game/sim/sim_world.gd` · `game/content/weapons/melee_attack_profile.gd` (new) ·
`game/content/weapons/sword_stats.gd`/`sword_burn_A.tres` ·
`game/actors/envoy/envoy.gd`/`.tscn` ·
`game/actors/enemies/telegraph_indicator.gd` ·
`game/arena/arena.gd`/`.tscn` ·
`game/content/enemies/natural_weapons/{fang_bite,ooze_slam,watcher_pulse}.tres`,
`natural_weapon_stats.gd` (leash_radius widen) ·
`tests/test_{combo,charge,interrupt,lunge,charge_windup,
pending_attack_cancellation,lunge_clamp,attack_buffer}.gd` (new/extended) ·
`ROADMAP.md` (P20 update, P21–P23 new) · `BRAIN.md` (new entry, pending) —
all committed this session except the closeout's own doc updates.
