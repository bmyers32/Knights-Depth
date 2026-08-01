# HANDOFF — 2026-07-31 (Sword damage pipeline session)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- Phase D step 3 + partial step 4 committed (1658f9f): deterministic sword-attack
  pipeline against a minimal real Fang target. Full walkthrough: input -> Envoy
  `build_commands(tick)` (move always, `attack` on just-pressed) -> `SimWorld.tick`
  -> `hit`/`died`/`attack_rejected`/`moved` Events -> dev-scaffold prints + presentation
  sync (position only, never sim-state writes).
- `SimWorld` gained: facing (horizontal, normalized, never zero — invariant enforced
  in `_normalize_horizontal`, shared by move-facing-update and aim resolution),
  `register_combatant(actor_id, max_health, family)`, `register_weapon(weapon_id,
  damage, damage_type, reach, cone_half_angle_degrees, knockback_distance)`,
  `set_damage_matrix(families, weak_multiplier, resist_multiplier)`. All three
  registration methods take plain scalars/dicts — the scene driver resolves
  `ContentDB` resources and unpacks them; **sim/ still never touches Resource or
  Node types**, matching the existing `move_speed` pattern.
- `attack` Command: `params = {weapon_id, aim}` only — reach/damage/cone/knockback
  are content values, never in the Command. Pipeline order (GAME-RULES §3): validate
  (dead attacker / unknown weapon -> `attack_rejected`, facing NOT updated) -> aim
  resolve (explicit aim, else falls back to stored facing) -> facing updates only on
  acceptance -> hit detect (radius + cone, actor_id-sorted for determinism, self/dead
  excluded) -> damage-matrix multiplier -> knockback (position offset in sim, no
  physics impulse) -> death event.
- New content resources: `DamageMatrix` (`game/content/combat/`) ships **all 6
  families complete** per GAME-RULES §3 even though only Fang has enemy content yet;
  `SwordStats` (Force-typed baseline, `game/content/weapons/`); `FangStats`
  (`game/content/enemies/fang/`). Registered in `ContentDB` under new `weapon`,
  `enemy`, `combat` families. All numeric values are first-pass/provisional — no
  playtest date yet, calibrate at the M1 playtest gate.
- Fang stub actor (`game/actors/enemies/fang/`): position-sync presentation only, no
  AI/loot/animation — exists solely to give the pipeline a real target.
- Tests: `tests/test_combat.gd` (23 cases: facing/aim resolution, hit detection,
  damage matrix, knockback, death, rejection, determinism), `tests/test_damage_matrix.gd`
  (5-case content-lint asserting the §3 matrix invariants), `test_content_db.gd` +3.
  **48/48 GUT passing headless** (91 asserts, 1.6s).
- Verification Gate: all items PASS (fun-impact N/A — pipeline plumbing, not yet the
  playtest-gated mechanic; no RNG this feature, so PD4 doesn't apply).
- Explicit note carried forward: the single-hit attack is the first proven step of
  the LOCKED 3-hit combo + hold-to-charge spec (GAME-RULES §3) — not a scope
  reduction. Combo/charge will sequence multiple attacks through this same pipeline.

## Not done / next action
1. **Phase D step 5: shield + i-frames.** Hold-to-block with its own break meter that
   regenerates, knockback on break (GAME-RULES §3); i-frames on dodge/hit, durations
   in sim ticks — never seconds — from config. Likely needs a `block` Command kind
   (Input Map binding already exists, unused) and an i-frame/block-state flag per
   entity in SimWorld, following the same "driver resolves content, sim takes plain
   scalars" boundary established this session.
2. Steps 6-10 of Phase D (renumbered): gun, enemies 2&3 (Ooze/Watcher) + Burn status,
   real arena (retires `game/dev/envoy_movement_dev.tscn`), 10-min playtest gate,
   itch build. Not started.

## Open tensions
- Pyre name provisional (Temper art direction); Hollow true name unassigned.
- Palettes provisional pending Umbral/damage-type art pass (channel law holds).
- Sync-as-meter: default NO (narrative only); annotated in canon.
- CORE-FANTASY pillars are [YOUR CALL] drafts — developer homework, no deadline.
- Damage-matrix multipliers (weak x1.5, resist x0.5) and sword/Fang numbers (10 dmg,
  2.0 reach, 60° cone, 1.0 knockback, 20 HP) are first-pass guesses, not calibrated —
  flag for the M1 playtest gate.

## Concepts introduced this session
- None new — the facing/aim/cone-hit-detection design (horizontal dot-product
  threshold, radius+cone hit query) came from the user fully specified; no first-use
  explanation was needed this session.

## Do NOT redo
- Naming re-litigation: slate is LOCKED (LEXICON amendment rule).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12).
- Do not rename statuses to lore words (REJECTED — ROADMAP NOT-list).
- guard.py: do not remove the self-path exemption or scan the guard's own source.
- ContentDB's lookup method is `get_resource(family, id)`, never `get()` — see BRAIN.
- Headless GUT runs need a prior `godot --headless --import` whenever a new
  `class_name` script is added (`DamageMatrix`/`FangStats`/`SwordStats` hit this
  again this session, 4th occurrence) — see BRAIN "class_name needs editor scan."
- SimWorld ownership: ONE shared instance per level, owned by a scene-level driver
  (not an autoload, not one-per-actor); don't generalize into a reusable `SimDriver`
  until a second concrete scene needs it (rule of two) — still step 8 (real arena).
- sim/ never references Resource or ContentDB directly — the driver always resolves
  content and passes plain scalars/dicts into SimWorld registration methods
  (`add_entity`, `register_combatant`, `register_weapon`, `set_damage_matrix`). Do
  not "simplify" this by having SimWorld preload/ContentDB.get_resource itself.
- Command.params carries only per-tick intent (`direction`, `weapon_id`, `aim`) —
  never authoritative values (damage/reach/cone/cooldown live in registered content).
- No combo counter, charge-hold, or attack cooldown state exists yet — the single
  discrete attack is deliberate scope, not an oversight; do not bolt on combo/charge
  as a second path. Sequence future attacks through `_apply_attack`.
- Asset intake pattern: extract zips to OS temp (never into the repo), inspect for
  wrapper folders and license files directly, confirm glb vs external-ref gltf before
  copying, one commit per intake batch.

## Files touched
`game/sim/sim_world.gd` · `game/actors/envoy/envoy.gd` · `game/autoload/content_db.gd`
· `game/dev/envoy_movement_dev.gd`/`.tscn` · `game/actors/enemies/fang/**` (new) ·
`game/content/combat/damage_matrix.gd`/`.tres` (new) ·
`game/content/weapons/sword_stats.gd`/`.tres` (new) ·
`game/content/enemies/fang/fang_stats.gd`/`.tres` (new) ·
`tests/test_combat.gd` (new) · `tests/test_damage_matrix.gd` (new) ·
`tests/test_content_db.gd` — all committed in 1658f9f. `HANDOFF.md` (this file,
committed at closeout).
