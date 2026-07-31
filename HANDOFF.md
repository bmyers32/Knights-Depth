# HANDOFF — 2026-07-31 (Asset intake session)
Milestone: 1 — Combat slice   Status: IN-PROGRESS (M0 COMPLETE)

## Done this session
- Asset intake (committed cfe116d): KayKit + Quaternius CC0 pulls for Envoy body,
  weapons, animations, and the three M1 enemy stand-ins.
  - `game/actors/envoy/models/Knight.glb` — temp Envoy body (KayKit Adventurers 2.0).
  - `game/actors/envoy/animations/` — Rig_Medium General/MovementBasic/
    MovementAdvanced/CombatMelee/CombatRanged (KayKit Character Animations 1.1).
    Skipped Adventurers' own bundled General/MovementBasic — confirmed byte-identical
    clip names to the fuller pack, would've been duplicate content.
  - `game/content/weapons/models/` — sword_A, wand_A (gun-class stand-in, one-handed
    quick-shot per Ranged_1H clips), shield_A + shared texture (KayKit Fantasy
    Weapons Bits 1.0).
  - `game/actors/enemies/{fang,ooze,watcher}/models/` — Dino, GreenSpikyBlob, Goleling
    (Quaternius Ultimate Monsters: Big/Blob/Flying sets).
  - All 13 files logged in ASSETS.md; all 4 source-pack licenses re-verified directly
    from their License.txt this session (not from memory) — all CC0.
- Kenney (environment/UI/audio) deliberately held for the arena session (M1 step 8);
  extracted to temp for inspection only, never entered the repo.
- Verification Gate run at closeout: all items PASS or N/A, no partials.
- Headless GUT: 11/11 passing, 20 asserts, 0.789s — unaffected by this session (no
  sim/gen code touched).

## Not done / next action
1. **Phase D step 2: wire input→Command→SimWorld, render Envoy model (Knight.glb)
   interpolated from sim state.** Needs: an Envoy scene/Node (CharacterBody3D, per the
   toy pattern), `attack`/`block` input actions (only `move_*` exist in project.godot's
   Input Map so far), and a real move-speed tunable — natural point to stand up
   ContentDB/content resources (deliberately deferred out of the sim-skeleton session).
2. Steps 3-10 of Phase D (sword/damage pipeline, first enemy, shield/i-frames, gun,
   enemies 2&3 + Burn, arena + playtest, itch build) — not started.

## Open tensions
- Pyre name provisional (Temper art direction); Hollow true name unassigned.
- Palettes provisional pending Umbral/damage-type art pass (channel law holds).
- Sync-as-meter: default NO (narrative only); annotated in canon.
- CORE-FANTASY pillars are [YOUR CALL] drafts — developer homework, no deadline.

## Concepts introduced this session
- glTF/GLB self-containment: a `.glb` embeds its buffer+textures (single file); a loose
  `.gltf` may reference external `.bin`/texture files instead — checked per-file before
  importing rather than assuming either way.

## Do NOT redo
- Naming re-litigation: slate is LOCKED (LEXICON amendment rule).
- Do not add Companion/Protocol mechanics before M4 (RISKS #12).
- Do not rename statuses to lore words (REJECTED — ROADMAP NOT-list).
- guard.py: do not remove the self-path exemption or scan the guard's own source.
- Sim design calls are the pattern, not open questions: entities keyed by actor_id in
  a Dictionary; per-actor tunables travel in Command.params until ContentDB exists.
- Delegation mode: build directly, don't offer "you drive, I review" unless asked.
- Asset intake pattern: extract zips to OS temp (never into the repo), inspect for
  wrapper folders and license files directly, confirm glb vs external-ref gltf before
  copying, one commit per intake batch.

## Files touched
`ASSETS.md` · `game/actors/envoy/**` · `game/actors/enemies/**` ·
`game/content/weapons/models/**` — all already committed in cfe116d.
`HANDOFF.md` (this file, committed at closeout).
