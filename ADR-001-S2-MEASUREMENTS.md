# ADR-001 S2 — spatial parameters, measured (2026-10-23)

Owner ruling O4: every threshold is measured before a number is locked. This records what the
shipped floors actually do and the **provisional prototype values** derived from them. They are
starting points for the S2 proof, not world rules; each lives in content (`game/content/floors/
profiles/*.tres`, `recipes/*.tres`) and is changed there, never in code.

Sources: `game/content/layouts/archive_prototype.tres` (Floor 1), `archive_roundabout.tres`
(Floor 2), `terminal.tres`, `foundry_assembly.tres` (Floor 4); `game/content/envoy/envoy_stats.gd`,
`game/content/enemies/*/*_stats.tres`; `game/arena/follow_camera.gd`. Method: a parser over the
`.tres` files (patch rects, apertures, obstacle rects) computing granularity, aperture width across
travel and depth along it, the gap between joined patches, corridor dimensions, the smallest
separation between unjoined patches, and extents.

| Parameter | Measured | Provisional S2 value | Where it lives |
|---|---|---|---|
| Coordinate granularity | gcd of every patch/aperture coordinate on all four floors = **0.5**; patch corners are overwhelmingly multiples of 2 | **grid cell 2.0** for leg lengths and positions; port spans keep the authored 0.5 | `FloorRecipe.grid_cell` |
| Aperture width across travel | Floor 1: 5 (all five). Terminal: 5. Floor 2: 5, 6, 8, 10 (main route 8; halls 10). Floor 4: 5, 6, 8, 9 | LINK / DETOUR hallways **6** wide, APPROACH **8** wide; a port may be narrower than its profile (the hallway covers it), never wider | `TraversalProfile.width` |
| Joint gap (edge to edge of joined patches) | **2** on every closable or barrier-bearing connection on every floor; 0 only where two open spaces abut (Floor 2 `C_DESCEND`, Floor 4 hub seams); 4–10 where the aperture is itself a short corridor | **2.0** | `TraversalProfile.gap` |
| Aperture overlap into each patch | 1.5 at width 5 (Floor 1, Terminal 2.5, Floor 4 pockets); 2–4 at widths 6–10 (Floor 2) | **1.5** at width 6, **3.0** at width 8 | `TraversalProfile.overlap` |
| Corridor widths | Floor 1: 4, 6. Floor 2: 10, 12. Floor 4: 5 (rim), 8, 10 | 6 (LINK, DETOUR), 8 (APPROACH); Floor 2's 10–12 halls are *rooms that read as halls*, not connectors | profiles |
| Corridor lengths | Floor 1: 32, 32. Floor 2: 32, 40 (east halls), 32 (west). Floor 4: 34, 34, 28, 19 | APPROACH **24–40**; DETOUR **28–48** total over 2–3 legs; LINK **8–16** (Floor 2 adjacent rooms sit 2–10 apart; a LINK is the shortest hallway that still reads as one) | `length_min` / `length_max` |
| Minimum leg before a turn | Floor 2's bends turn after ≥ 12; Floor 4's jog after 8 | **8** | `TraversalProfile.leg_min` |
| Legs per profile | Floor 2's halls bend once (`C_EAST_HALL_BEND`); Floor 4's east hall jogs (`P_EAST_JOG`: two turns, same heading) | APPROACH **≤ 3** (straight, one turn, or a jog), LINK **1**, DETOUR **≤ 3**, SHORTCUT **≤ 2** | `TraversalProfile.max_legs` |
| Junction clearance | Floor 2 `P_JUNCTION` 12×12; Floor 4 `P_JUNCTION` 16×12, `P_HUB` 32×26 | not consumed in S2 (the landmark's third port is the fork); record 12×12 for the JUNCTION profile when a route needs it | — |
| Body radius / aperture clearance | Envoy 0.45; Watcher 0.85; **Ooze 1.45** (widest); `FloorPlan` refuses an aperture ≤ 2 × widest body on the floor | every profile ≥ 6 > 2.9; thin-ground never arises from a profile | existing `impassable_aperture` rule |
| Separation between unjoined ground | smallest on Floor 2 and Floor 4: **2.0** (Terminal 22; Floor 1 6) | **margin 2.0** (= one grid cell): a footprint or hallway may come no closer than this to ground it does not join | `FloorRecipe.margin` |
| Floor extents | Floor 1 32×98; Terminal 20×38; Floor 4 136×162; Floor 2 308×150 | prototype extent **160 × 170** (entry at the origin, flow toward −z) | `FloorRecipe.extent` |
| Camera | `FollowCamera` edge margins 6.0 / 6.0 | not consumed in S2 (S4) | — |
| Generation budgets | none existed | candidates per piece **3**, placements **200**, reseeds **3**; the §5 M2 100 ms gate stays the acceptance bar, measured not branched on | `FloorRecipe` |

**Not measured, deliberately:** fallback-rate threshold, diversity floor, safe screen band (O4,
still open) — the S2 sweep produces the numbers the owner will rule on.

## S2.5 — spatial and encounter quality (2026-10-23, after the S2 playtest: ITERATE)

The playtest's finding — enemies wake "directly on top of the player" in a chamber that also holds
a switch, a key, its receiver and the exit — was measured against every encounter the human had
already accepted. Sources: the four shipped layouts' `activate_encounter` triggers, roster
positions and territories; `envoy_stats.gd`; `*_stats.gd`; `natural_weapons/*.tres`;
`physics_ticks_per_second = 30`.

| Parameter | Measured | Provisional S2.5 value | Where it lives |
|---|---|---|---|
| Spawn distance from the activating region's centre, shipped sealing rooms | smallest **5.83** (Floor 2 `E_POCKET`, a deliberate ambush); next 6.00, 6.32 (`E_WORKS`), 7.0, 8.06; plates with a party trigger 10–24 | the S2 exit gallery: **2.0 and 2.2**; the S2 pit: 5.0, 5.0, 7.1 | — |
| **Arrival reach** = envoy body + enemy body + preferred attack distance + speed × (shortest windup + reaction) / 30 | fang 0.45 + 0.9 + 1.65 + 3.0 × (12 + 15)/30 = **5.70**; ooze 0.45 + 1.45 + 2.2 + 1.5 × (30 + 15)/30 = **6.35**; watcher 0.45 + 0.85 + 2.0 + 2.0 × (20 + 15)/30 = **5.63** | reaction allowance **15 ticks** (0.5 s): the largest whole value under which every accepted room passes and the rejected gallery fails; the activation point is the region's **centre** (nearest-point flags three accepted threshold rooms) | `EnvoyStats.spawn_reaction_ticks`; `EncounterSpacing` |
| Sealing territory area, shipped, by roster size | 1 roster: 256; 2: 344–360; 3: 520, 529, 616; 4-wave arenas 1072–1600 | pit **20 × 26 = 520** (three roster), spawns 12.5–15.1 from the plate's centre, all ahead of it (the camera shows ~70 units ahead and ~10 behind) | `archive_encounter_pit.tres` |
| Mechanics per piece | shipped: a sealing fight, a key lift and its receiver are never in one patch; the S2 exit gallery held plate, fight, switch, key, receiver, console and exit in 12 × 8 | exit **landing** 16 × 16: pad, console, one urn; the key chain is S3's, across pieces | `archive_exit_landing.tres` |
| Turning LINK band | Floor 2's bent hall: 12 + 20; Floor 4's jog 8 + 8 + 12 | `link_turn` **16–32** total, two legs ≥ 8 (the first leg must clear the landmark's own half-width before the bend) | `profiles/link_turn.tres` |
| Side door height on the landing | — | offset 1 of 16 (the far end): the dogleg's shortcut arrives from an objective that stands below the landing's top; the lower the door, the wider the band of objective positions with an 8-unit first leg. Measured: p99 106 ms → 59 ms, rejections 22 379 → 6 193 over 200 seeds | `archive_exit_landing.tres` |

**Human S2.5 gate (played): ITERATE.** The enlarged arena improved; the dogleg lacked meaningful
exploration; the shortcut was unsatisfying; the opening crate-and-plate interaction was trivial. These
numbers stand as the foundation S3 builds on (committed `6d252cd`); none is an acceptance of the floors.
