# HANDOFF — 2026-08-02 (Gun + aim/cooldown fix session)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- Phase D step 6 committed (bacdd0c): gun (ranged weapon class) through the existing
  combat pipeline, plus a same-day fix pass driven by manual playtest findings.
- `SimWorld` gained: `set_equipped_weapon(actor_id, weapon_id)` — sim-owned equip
  state; attack Commands now carry only `{aim}`, never `weapon_id`. `register_gun(...)`.
  A shared `_resolve_hit_on_target` tail (iframe/matrix/shield/knockback/death) reused
  by BOTH melee's per-target loop and a projectile's arrival — a bullet is gated
  identically to a sword swing. Projectiles resolve via swept-segment collision
  (closest point on each tick's travel segment, earliest hit wins, actor_id tie-break).
  New Events: `projectile_fired`, `projectile_expired`. New rejection reason
  `on_cooldown` (fire_interval_ticks, below).
- Two-stage mouse aim (manual playtest finding): ground-plane-only intersection missed
  anything clicked above ground level (new BRAIN entry). Fixed with raycast-aimable-
  layer-first, ground-plane-fallback-second; Fang got its first collider (`TargetBody`,
  dedicated `aimable_targets` physics layer 2) + an `AimAnchor` at body-center height,
  sized against the model's real measured bounding box. Command boundary unchanged —
  the raycast only shapes a direction; the sim alone resolves the hit.
- Content: `GunStats` (new, `wand_A`), `SwordStats.weapon_class` (closed a GAME-RULES
  §3 gap). wand_A: knockback 0.0 (repeat-fire knockback drifted a target off the gun's
  own aim line — BRAIN, second occurrence), `fire_interval_ticks` 15 — a basic semi-
  automatic cadence gate, explicitly NOT the slice-B shared press/hold/release charge
  model.
- Tests: `tests/test_gun.gd` (10 cases: spawn/deferred resolution, travel/arrival,
  expiry, ownership, shared-pipeline reuse, swept-segment selection + tie-break,
  determinism) + 2 fire-cooldown cases. `test_combat.gd`/`test_shield.gd` updated for
  the equip-based attack helper (regression guard — all prior assertions unchanged).
  **86/86 GUT passing headless.**
- Manual F6 retest (user, post-fix): head/torso/feet clicks hit, empty-ground aim
  follows the cursor without snapping, silhouette-edge clicks feel forgiving not
  magnetic, standing repeat-fire lands consecutively, spam-click correctly gated at the
  interval (rejected clicks don't rotate facing), multiple distances behave, sword
  re-checked and unaffected.

## Not done / next action
1. **Phase D Step 7: Ooze + Watcher stubs** through the content pipeline (mirrors
   Fang's shape: enemy stats resource + ContentDB registration; both damage-matrix rows
   already locked in `damage_matrix.tres`), plus **Burn status v1** per the single-
   status-slot law (GAME-RULES §3) — DoT ticks, spreads on contact, replaces whatever
   status is currently active (statuses are exclusive, never stacked).
2. Steps 8-10 of Phase D (renumbered): real arena (retires
   `game/dev/envoy_movement_dev.tscn`), 10-min playtest gate, itch build. Not started.

## Open tensions
- Shield/i-frame numbers (unchanged this session) and now gun numbers (speed 8.0,
  damage 6.0, hit_radius 0.4, max_lifetime_ticks 60, fire_interval_ticks 15) are all
  first-pass and explicitly unvalidated — calibrate together at the M1 playtest gate.
- Fang's new collision capsule (radius 1.0, height 3.0) is a first-pass eyeball against
  the model's AABB, deliberately excluding its tail's width — revisit visually once
  there's real lighting/camera framing at the arena step.
- Pyre name provisional; Hollow true name unassigned; palettes provisional; CORE-
  FANTASY pillars are developer homework, no deadline. (carried, unchanged)

## Concepts introduced this session
- None new — camera-ray/ground-plane mouse aim was introduced last session; this
  session added a raycast-a-physics-layer stage on top of that same recipe (one more
  step, not a new concept).

## Do NOT redo
- Naming re-litigation: slate is LOCKED (LEXICON amendment rule).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12).
- guard.py: do not remove the self-path exemption or scan the guard's own source.
- `godot --headless --import` before any headless GUT run that added a new
  `class_name` script (`GunStats` this session) — see BRAIN.
- sim/ never references Resource or ContentDB directly — driver resolves content,
  passes plain scalars into SimWorld registration methods. Do not "simplify" this.
- Command.params carries only per-tick intent, never authoritative values — attack
  Commands carry `{aim}` ONLY now, never a `weapon_id` or a target id. The equipped
  weapon is sim-owned state (`set_equipped_weapon`); do not put weapon selection back
  on the Command.
- No runtime weapon-switching Command/UI yet (deliberately deferred) — the dev
  scaffold picks its weapon via one exported `starting_weapon_id`, not a cycle input.
- `fire_interval_ticks` is a flat per-weapon cooldown ONLY — explicitly NOT the
  slice-B shared press/hold/release charge model GAME-RULES §3 locks. Do not grow it
  into charge semantics ad hoc; that lands as its own weapon-agnostic mechanism later.
- A new aimable enemy needs a collider on the `aimable_targets` physics layer (2) AND a
  `get_aim_anchor_position()` method (on itself or its collider's parent) — skipping
  either silently reverts that enemy to ground-plane-only aiming (BRAIN).
- Knockback can silently move an actor out of another attack's reach OR off a
  repeat-fire weapon's aim line — re-derive positions before trusting reach/aim math in
  any future scripted sequence, multi-step encounter, or repeat-fire weapon (BRAIN).

## Files touched
`game/sim/sim_world.gd` · `game/actors/envoy/envoy.gd` ·
`game/actors/enemies/fang/fang.gd`/`.tscn` · `game/autoload/content_db.gd` ·
`game/content/weapons/sword_stats.gd`/`.tres` ·
`game/content/weapons/gun_stats.gd`/`.tres` (new) ·
`game/dev/envoy_movement_dev.gd`/`.tscn` · `tests/test_combat.gd` ·
`tests/test_shield.gd` · `tests/test_gun.gd` (new) — all committed in `bacdd0c`.
