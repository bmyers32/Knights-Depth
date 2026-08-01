# HANDOFF — 2026-08-01 (Shield block + hit i-frames session)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- Phase D step 5 committed (ba28e4d): shield block + hit i-frames, full design lock
  captured via AskUserQuestion before implementation (see commit body for the complete
  rule set — full-absorb block, READY/HELD/BROKEN state machine, fresh-intent recovery).
- `SimWorld` gained: `register_shield(actor_id, meter_max, regen_per_tick,
  break_recovery_delay_ticks, knockback_distance)`; `register_combatant` gained a 4th
  optional param `iframe_ticks_on_hit` (default 0, non-breaking). New `block` Command
  (`{held: bool}`, sent every tick like `move` — continuous intent, not edge-triggered).
  New Events: `blocked`, `shield_broken`, `block_rejected(reason)`, `attack_absorbed
  (reason)`. `_advance_iframes()` decrements once per `tick()` call, independent of
  which Commands arrive.
- Shield state machine: READY regenerates each tick; HELD freezes the meter (a
  commitment); BROKEN withholds regen for `break_recovery_delay_ticks` then flips to
  READY the instant meter > 0 (no minimum). READY->HELD requires a RISING EDGE of
  `held` — this is the whole fresh-intent mechanism: holding straight through a break
  never auto-re-enters HELD, but a real press always does, with no separate "just
  recovered" flag needed. BROKEN rejects any held block command by name
  (`block_rejected`, reason `"broken"`), whether it's a continued hold or a fresh press.
- i-frames: armed ONLY by an unblocked, non-lethal hit (never by a blocked hit, a
  shield break, or an absorbed swing — one shared timer, trigger is a parameter, dodge
  will arm the same timer later per ROADMAP P15). Full negation while active: no
  damage, no knockback, no status.
- New content: `ShieldStats` (`game/content/shield/`, new `shield` ContentDB family);
  `FangStats.iframe_ticks_on_hit`. Calibration note added with tick->second
  conversions at 30Hz (regen 0.4/tick = 1.67s full regen; break delay 30 ticks = 1.0s)
  — explicitly marked UNVALIDATED PENDING THE STEP 8 PLAYTEST, not "feels right yet."
- Tests: `tests/test_shield.gd`, 26 cases covering every locked invariant including 4
  the user specifically re-audited post-hoc: fresh-press-while-broken rejection
  (distinct from continued-hold rejection), no-auto-resume-after-recovery, a
  consolidated single-break-event test (no hit/iframe/weapon-knockback also firing),
  and off-by-one boundary pins for both the break-delay and hit-iframe timers (driven
  by consecutive real ticks, not just noop counters). **74/74 GUT passing headless.**
- Scripted headless smoke test run against the REAL (unmodified) dev scaffold scene
  (`envoy_movement_dev.tscn`) — instantiated it, grabbed its real `sim`/actor refs,
  disabled its automatic `_physics_process` (own driver would double-tick otherwise),
  drove a scripted Command sequence, logged tick/state/meter. Confirmed all 6 required
  behaviors against REAL content values (frozen-while-HELD, regen-while-lowered,
  break-forces-off, no-auto-reraise, release+press-reraises, i-frame full negation).
  Driver script was scratchpad-only, deleted after — dev scene file itself untouched.
  Hit BRAIN-worthy bug twice: knockback from one scripted attack silently moved the
  target out of the NEXT scripted attack's reach (zero events, no error) — see BRAIN.
  **This was a headless/scripted check only, not a substitute for a real Input-driven
  pass — see the user's manual pass below, done after closeout.**
- **User's manual pass on `envoy_movement_dev.tscn` (post-closeout, via F6 on the
  opened scene):** movement and Envoy->Fang combat confirmed working. Sword cone
  behaves according to stored movement-facing (expected — no dedicated aim input
  exists yet). Finding: mouse-to-world aim is NOT wired; expected to arrive with
  Phase D Step 6 gun work (aim becomes the shared `params.aim` convention once sword
  and gun are its two concrete consumers). Shield input (hold/release RMB) can be
  sanity-checked now, but visual depletion, break, recovery, and hit-i-frame
  validation remain BLOCKED until an enemy can attack the Envoy — that's Step 7.
- ROADMAP: P15 (dodge — own input, shares this session's i-frame timer) and P16
  (timed shield bounce, layers on the recorded `_block_start_tick`) logged.

## Not done / next action
1. **Phase D Step 6: gun** — implement a projectile with deterministic travel time
   through the existing attack pipeline. Aim becomes the shared `params.aim`
   convention now that sword and gun are its two concrete consumers (this also wires
   real mouse-to-world aim, per the manual-pass finding above). Do NOT add homing,
   spread, ammo, reload, weapon switching, or a generalized weapons framework in this
   slice.
2. Steps 7-10 of Phase D (renumbered): enemies 2&3 (Ooze/Watcher) + Burn status, real
   arena (retires `game/dev/envoy_movement_dev.tscn`), 10-min playtest gate, itch
   build. Not started. **Step 7 also unblocks the shield's visual validation** (an
   attacker for the Envoy is what's been missing).

## Open tensions
- Shield/i-frame numbers (meter 20, regen 0.4/tick, break delay 30 ticks, break
  knockback 1.5) are first-pass and explicitly unvalidated — calibrate at the M1
  playtest gate alongside the existing sword/Fang/matrix numbers.
- Pyre name provisional (Temper art direction); Hollow true name unassigned.
- Palettes provisional pending Umbral/damage-type art pass (channel law holds).
- CORE-FANTASY pillars are [YOUR CALL] drafts — developer homework, no deadline.

## Concepts introduced this session
- None new — shield state-machine and i-frame design came from the user fully
  specified via AskUserQuestion answers; no first-use engine-concept explanation
  needed this session.

## Do NOT redo
- Naming re-litigation: slate is LOCKED (LEXICON amendment rule).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12).
- guard.py: do not remove the self-path exemption or scan the guard's own source.
- `godot --headless --import` before any headless GUT run that added a new
  `class_name` script (`ShieldStats` this session) — see BRAIN.
- sim/ never references Resource or ContentDB directly — driver resolves content,
  passes plain scalars into SimWorld registration methods. Do not "simplify" this.
- Command.params carries only per-tick intent, never authoritative values.
- Block Command is continuous (`held` sent every tick), never edge-triggered — mirrors
  `move`. Do not switch it to a `block_start`/`block_stop` pair.
- HELD is entered from READY only on a rising edge of `held` — do not "simplify" to
  `state == ready and held` (that's exactly the bug the fresh-intent rule prevents).
- Dodge is NOT implemented (ROADMAP P15) — do not build it ad hoc inside a future
  session; it must arm the SAME i-frame timer this session built, never a second one.
- Knockback can silently move an actor out of another attack's reach with zero events
  — re-derive positions before trusting reach math in any future scripted sequence or
  multi-step encounter design (BRAIN).

## Files touched
`game/sim/sim_world.gd` · `game/actors/envoy/envoy.gd` · `game/autoload/content_db.gd`
· `game/dev/envoy_movement_dev.gd` · `game/content/enemies/fang/fang_stats.gd`/`.tres`
· `game/content/shield/shield_stats.gd`/`.tres` (new) · `tests/test_shield.gd` (new)
· `ROADMAP.md` (P15/P16) · `BRAIN.md` (knockback-invalidates-reach lesson) — all
committed in d4c7c29. `HANDOFF.md` (this file, updated post-closeout to record the
user's manual pass; not yet committed).
