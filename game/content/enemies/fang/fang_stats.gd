class_name FangStats
extends Resource
## Fang (Common state, M1 roster per GAME-RULES §3/§7 seed+7) tunables — looked up
## via ContentDB, never literals in scripts.

## First-pass numbers, TESTED at the M1 playtest gate 2026-08-11 (build d1dbab0,
## seed 0): verdict ITERATE, M1 NOT closed. Combat reads fair and legible (no unseen
## damage), but the gate found no encounter decisions -- "any reasonable way to kill
## works" -- and no realistically available failure: "failure must be orchestrated by
## the player." No threshold below was individually judged, so treat each as UNREFUTED,
## never confirmed. Named tuning axis for the next pass: enemy OUTPUT (damage, attack
## cadence, aggression) -- durability tuning ALONE only lengthens fights without making
## failure available. A re-gate on a frozen post-batch build closes M1
## (GAME-RULES calibration-note law).
@export var max_health: float = 20.0
@export var family: StringName = &"fang"
## FLINCH threshold (batch, PROVISIONAL/UNVALIDATED 2026-08-12): post-mitigation HP
## damage that must accumulate inside the shared pressure window before a
## pressure-capable hit can cash it out. 16.0 = the sword's hits 1+2 (8+8), so Fang
## teaches the BASELINE lesson: land the whole combo, the finisher pays off. Tuned
## jointly with max_health -- the two are ONE decision per enemy, never separately.
@export var flinch_threshold: float = 16.0
## CADENCE CONSTRAINT (locked as an invariant, value PROVISIONAL/UNVALIDATED):
## health-hit i-frames gate INDEPENDENT SEQUENTIAL hits, so this value doubles as a
## cap on any attacker's authored hit cadence. At 15 it silently absorbed sword_burn_A's
## own combo hits 2 and 3 (gaps of 6 and 7 ticks) -- a full 1->2->3 landed hit 1 only.
## Rule: iframe_ticks_on_hit < the smallest gap between consecutive authored hits.
## 5 keeps one tick of margin under that 6-tick minimum. Probed 2026-08-11 and played
## through the gate that day; unrefuted, still PROVISIONAL -- revisit at the re-gate.
## tests/test_combo_cadence_fixture.gd fails if a cadence retune ever violates the rule.
@export var iframe_ticks_on_hit: int = 5
## Burn contact-spread proximity radius (GAME-RULES §3) — matches the existing
## collision capsule's radius (fang.tscn), same first-pass/eyeballed status.
@export var combat_radius: float = 1.0
