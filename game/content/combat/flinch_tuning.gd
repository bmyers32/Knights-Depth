class_name FlinchTuning
extends Resource
## Shared flinch/pressure tunables (Prime Directive 3) — one resource, resolved by the
## driver and unpacked into SimWorld as plain values, exactly like DamageMatrix.
##
## These are deliberately SHARED, not per-enemy or per-weapon:
## - pressure_window_ticks is ONE global clock (ROADMAP P5 addendum). Per-weapon
##   windows only if multiple real weapons prove the shared model cannot support their
##   rhythm (§1.4 rule of two). Per-enemy susceptibility is expressed by each enemy's
##   own flinch_threshold, never by giving it a private clock.
## - flinch_recovery_ticks is the baseline reaction duration; a per-enemy override is a
##   later content decision, not a mechanism to build ahead of a consumer.

## Sim ticks a recorded pressure contribution stays live (GAME-RULES §3: durations in
## sim ticks, never seconds). Contributions expire individually on their own ticks —
## a rolling queue, NOT a refreshed timer, so late damage never revives early damage.
##
## TWO-CLOCK RULE (locked): this and the sword's combo continuation window
## (SwordStats.combo_reset_ticks) are intentionally INDEPENDENT clocks. Do not
## equalize them. A delayed stored finisher may legitimately arrive pressure-expired —
## that is temporal mastery, not a bug. The primary tuning instrument for this value is
## the cross-weapon cash-out playtest (build pressure at range, switch, close, finish),
## judged on a NEVER / SOMETIMES-with-intent / ALMOST-ALWAYS band — never timer
## arithmetic.
##
## PROVISIONAL/UNVALIDATED first pass (2026-08-12): 90 ticks = 3.0s at 30 Hz, chosen
## as roughly twice the sword's 45-tick combo reset so an uninterrupted 1->2->3
## comfortably lands inside one window while a disengage-and-return does not.
@export var pressure_window_ticks: int = 90

## Sim ticks an enemy stays FLINCHED. Effective attack denial is
## max(recovery, remaining cooldown) — never the sum — because both are absolute
## tick deadlines that run concurrently (GAME-RULES §3).
## PROVISIONAL/UNVALIDATED first pass: 20 ticks (~0.67s) — long enough to read as a
## real reaction and to reposition, short enough that chaining it demands intent.
@export var flinch_recovery_ticks: int = 20
