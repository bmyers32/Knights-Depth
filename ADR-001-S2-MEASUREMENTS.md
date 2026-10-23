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
