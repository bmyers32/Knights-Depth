# HANDOFF — 2026-08-03 (Ooze/Watcher + Burn + combat RNG session)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- Phase D step 7 committed (60aaa9c): Ooze + Watcher pushed through the content
  pipeline mirroring Fang (stats resource, ContentDB, actor scene with `TargetBody`/
  `AimAnchor`), wired into the dev scaffold as a static enemy-to-enemy close pair
  (Fang kept isolated) for manual spread testing.
- Burn status v1 (GAME-RULES §3): single status slot (`SimWorld._status_instances`,
  one record per actor), exclusive replace via a data-driven priority table
  (`StatusPriorityTable`, ships with just `burn` — mirrors DamageMatrix's
  ships-complete pattern), DoT/duration in sim ticks. Contact-episode spread:
  `combat_radius` overlap, one-tick grace before a status can spread or tick,
  exactly one transmission per undirected pair (`Vector2i`) per continuous overlap
  episode, player<->player rejected. New autonomous-phase law (code comment only,
  see Open tensions): scans collect secondary effects during a read-only pass and
  commit them afterward, never mutating what they iterate.
- Manual-playtest correction, same session: Burn no longer always applies on a
  sword_burn_A hit. It now rolls a content-driven `status_proc_chance` (0.3,
  provisional) through `SimWorld`'s first seeded combat RNG stream (GAME-RULES
  §1.3) — `_combat_rng`, seeded to 0 by default in `_init()`, overridden via
  `seed_combat_rng(seed)`. Roll-consumption is strict: draws only after a hit
  clears every validation/defense gate; blocked/absorbed/missed/cooldown-rejected
  draw nothing; a lethal eligible hit still consumes exactly one roll (stream must
  never diverge on victim HP); chance 0.0/1.0 short-circuit without drawing. One
  event kind, `status_proc {attacker_id, target_id, status_id, chance, result}`.
  `sword_A`/all guns stay at 0.0 (unaffected, verified by test).
- Envoy registered as a real combatant for the first time (health, family,
  combat_radius) — required for Burn's enemy<->player spread leg. No death/respawn
  system exists; a lethal hit against the Envoy just prints a loud, distinct line.
- Dev scaffold: weapon-cycle debug key (raw `KEY_TAB`, 6 weapons incl. 3 typed dev
  guns `gun_pierce_A`/`gun_arc_A`/`gun_umbral_A`), `combat_seed` export + print.
- Manual pass (user): TAB-cycled to `sword_burn_A`, repeated swings showed both proc
  outcomes printing, `status_applied` only following success, rate feels occasional
  (feel only — step 8 tunes); changed `combat_seed`, got a different reproducible
  sequence; restored it, got the original sequence back.
- Tests: `test_burn.gd` (apply/refresh/DoT/expiry/grace/outcome-seam/priority-lint),
  `test_burn_spread.gd` (full contact-episode edge-case list), `test_status_proc.gd`
  (roll-consumption: blocked/absorbed/missed/cooldown-rejected draw nothing, lethal
  hit consumes exactly one roll, 0.0/1.0 no-draw, seed determinism). **135/135 GUT
  passing headless.**

## Not done / next action
1. **Phase D Step 8**: real arena (retires `game/dev/envoy_movement_dev.tscn`),
   Envoy death handling / Emergency Recall (currently only a dev-only print, no
   actual respawn/run-end system), then the 10-min `/playtest` gate + itch build.

## Open tensions
- **Per-run combat-seed derivation is an open M2 run-structure requirement**: real
  runs must derive a combat seed independently of the gen seed (§1.3 separate
  streams) — seed 0 is only this session's fixed dev baseline, not a design for
  actual play. Needs a decision at M2 kickoff.
- GAME-RULES §2 still needs the autonomous-phase law added by hand — `guard.py`
  hard-blocks agent edits to GAME-RULES.md itself (by design), so it was never
  amended there this session. `sim_world.gd`'s `tick()`/`_advance_contact_spread`/
  `_advance_status_ticks` comments are the only current record of the law.
- All new numeric values (Burn's 2.0/15/90, combat radii, Envoy's 30.0 max_health,
  sword_burn_A's 0.3 proc chance) are first-pass/unvalidated — calibrate at the
  step 8 playtest gate.
- Pyre name provisional; Hollow true name unassigned; palettes provisional; CORE-
  FANTASY pillars are developer homework, no deadline. (carried, unchanged)

## Concepts introduced this session
- Seeded RNG streams (dedicated `RandomNumberGenerator` instances, one per system,
  never the engine's global `randf()`/`randi()`) — first concrete instance of
  GAME-RULES §1.3's law, via the combat stream.

## Do NOT redo
- Naming re-litigation: slate is LOCKED (LEXICON amendment rule).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12).
- guard.py: do not remove the self-path exemption, scan the guard's own source, or
  attempt to bypass its GAME-RULES.md/CLAUDE.md/AGENTS.md protection — those edits
  are the user's to make.
- `godot --headless --import` before any headless GUT run that added a new
  `class_name` script (`BurnStats`, `StatusPriorityTable`, `OozeStats`,
  `WatcherStats` this session) — see BRAIN.
- sim/ never references Resource or ContentDB directly. Command.params carries only
  per-tick intent (`{aim}`/`{direction}`/`{held}`) — never a weapon_id, target id, or
  status id. (carried, unchanged)
- `_combat_rng` has exactly ONE draw site (`_roll_status_proc`) — no other sim/ code
  may call `randf()`/`randi()` on it or any future stream; loot/gen get their OWN
  dedicated `RandomNumberGenerator` instances, never share this one (BRAIN).
- The dev-scaffold TAB weapon-cycle is a debug-only direct `set_equipped_weapon`
  call from the driver, not a new Command/UI — does not reopen the deferred
  player-facing weapon-switch feature.
- `sword_burn_A`/`gun_pierce_A`/`gun_arc_A`/`gun_umbral_A` are dev-only content
  variants for manual testing, not finished M1 weapons — Step 8 decides which real
  weapon (if any) actually ships Burn.
- `_next_fire_tick` (attack cooldown) is keyed by `actor_id`, not `weapon_id` — it's
  shared across whatever weapon that actor currently has equipped (BRAIN).

## Files touched
`game/sim/sim_world.gd` · `game/autoload/content_db.gd` ·
`game/content/enemies/{fang,ooze,watcher}/*_stats.gd`/`.tres` ·
`game/content/envoy/envoy_stats.gd`/`.tres` ·
`game/content/weapons/{sword,gun}_stats.gd`, `sword_burn_A.tres`,
`gun_{pierce,arc,umbral}_A.tres` (new) ·
`game/content/status/{burn_stats,status_priority}.gd`/`.tres` (new) ·
`game/actors/enemies/{ooze,watcher}/*.gd`/`.tscn` (new) ·
`game/dev/envoy_movement_dev.gd`/`.tscn` ·
`tests/test_{combat,content_db}.gd` ·
`tests/test_{burn,burn_spread,status_proc}.gd` (new) — all committed in `60aaa9c`.
