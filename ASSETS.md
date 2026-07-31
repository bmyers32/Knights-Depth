# ASSETS.md — Asset Manifest (GAME-RULES §1.7)
Nothing enters the repo without a line here. Format:
`| path | source | license | date | note |`

| Path | Source | License | Date | Note |
|---|---|---|---|---|
| game/actors/envoy/models/Knight.glb | KayKit Adventurers 2.0 (kaylousberg.com) | CC0 | 2026-07-31 | Temporary Envoy body mesh; filename LEXICON-exempt, code identifiers must say `envoy` |
| game/actors/envoy/animations/Rig_Medium_General.glb | KayKit Character Animations 1.1 (kaylousberg.com) | CC0 | 2026-07-31 | Idle/hit/death/spawn clips for Rig_Medium |
| game/actors/envoy/animations/Rig_Medium_MovementBasic.glb | KayKit Character Animations 1.1 (kaylousberg.com) | CC0 | 2026-07-31 | Walk/run/jump clips for Rig_Medium |
| game/actors/envoy/animations/Rig_Medium_MovementAdvanced.glb | KayKit Character Animations 1.1 (kaylousberg.com) | CC0 | 2026-07-31 | Dodge/strafe clips for Rig_Medium (i-frame dodge per GAME-RULES §3) |
| game/actors/envoy/animations/Rig_Medium_CombatMelee.glb | KayKit Character Animations 1.1 (kaylousberg.com) | CC0 | 2026-07-31 | 1H/2H/block melee clips for Rig_Medium (sword combo/charge, shield block) |
| game/actors/envoy/animations/Rig_Medium_CombatRanged.glb | KayKit Character Animations 1.1 (kaylousberg.com) | CC0 | 2026-07-31 | Aim/shoot/reload clips for Rig_Medium (gun class) |
| game/content/weapons/models/sword_A.gltf + .bin | KayKit Fantasy Weapons Bits 1.0 (kaylousberg.com) | CC0 | 2026-07-31 | Sword-class weapon mesh, M1 default variant |
| game/content/weapons/models/wand_A.gltf + .bin | KayKit Fantasy Weapons Bits 1.0 (kaylousberg.com) | CC0 | 2026-07-31 | Gun-class weapon mesh (one-handed quick-shot analog); uses Ranged_1H clips |
| game/content/weapons/models/shield_A.gltf + .bin | KayKit Fantasy Weapons Bits 1.0 (kaylousberg.com) | CC0 | 2026-07-31 | Shield-class mesh, M1 default variant |
| game/content/weapons/models/weapons_bits_texture.png | KayKit Fantasy Weapons Bits 1.0 (kaylousberg.com) | CC0 | 2026-07-31 | Shared texture referenced by sword_A/wand_A/shield_A gltf |
| game/actors/enemies/fang/models/Dino.gltf | Quaternius Ultimate Monsters, "Big" set (quaternius.com) | CC0 | 2026-07-31 | Common Fang stand-in (beast); self-contained embedded gltf |
| game/actors/enemies/ooze/models/GreenSpikyBlob.gltf | Quaternius Ultimate Monsters, "Blob" set (quaternius.com) | CC0 | 2026-07-31 | Drifted Ooze stand-in (asymmetric silhouette matches Drifted channel law); self-contained embedded gltf |
| game/actors/enemies/watcher/models/Goleling.gltf | Quaternius Ultimate Monsters, "Flying" set (quaternius.com) | CC0 | 2026-07-31 | Claimed Watcher stand-in (hovering construct); self-contained embedded gltf |

Allowed licenses: CC0, original work by the developer, or explicitly attributed
CC-BY (attribution block goes in CREDITS at first CC-BY entry).
Never allowed: anything from Spiral Knights, extracted game files of any title,
"found on the internet" sprites, licensed sports/film/character IP.
