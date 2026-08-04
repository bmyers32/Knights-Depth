class_name SwordStats
extends Resource
## Sword-class weapon tunables (Prime Directive 3) — looked up via ContentDB, never
## literals in scripts. M1 default sword: Force-typed (GAME-RULES §3's "everybody's
## fallback" baseline), single discrete attack this session — combo/charge fields
## join this resource when Phase D sequences the locked 3-hit + hold-to-charge spec
## on top of this same pipeline.
##
## SLICE B SPEC (locked, captured pre-build — nothing built yet; spec input for
## when Slice B planning opens, supersedes any earlier draft):
## - Combo moves to PER-HIT content profiles — each of the 3 combo steps carries
##   its OWN damage/reach/knockback/status-proc/timing, not one shared field set
##   on this resource. sword_burn_A: hits 1-2 proc 0.0, hit 3 gets a configurable
##   chance (status_proc_chance below keeps meaning "hit 3's chance" for
##   sword_burn_A once the per-hit split lands — do not repurpose it).
## - A charge attack SELECTS ITS OWN content profile (the seam requirement) — a
##   charge is never a hardcoded bigger normal hit.
## - First charge implementation: ONE charged strike only — independent
##   geometry/damage/knockback/timing, 100% Burn proc for sword_burn_A.
## - NOT Slice B baseline: the advancing multi-hit "Brandish" charge (staged
##   multi-tick attack). That's later content (ROADMAP P5 addendum) with its own
##   spec — interruption, owner-death, per-pulse status, defense-across-waves —
##   answered when Brandish becomes real content, not assumed here.

## weapon_class (not `class` — reserved word for inner classes in GDScript) is
## GAME-RULES §3's required tag on every weapon resource (sword/gun/bomb).
@export var weapon_class: StringName = &"sword"

## Provisional first-pass numbers, no playtest date yet (GAME-RULES calibration-note
## law) — revisit at the M1 playtest gate.
@export var base_damage: float = 10.0
@export var damage_type: StringName = &"force"
@export var reach: float = 2.0
@export var cone_half_angle_degrees: float = 60.0
@export var knockback_distance: float = 1.0
## Optional status payload (GAME-RULES §3) — empty means this weapon never applies a
## status. sword_A stays empty; sword_burn_A (dev-only Burn carrier, HANDOFF) is the
## only M1 weapon that sets this, so the baseline sword's proven behavior is untouched.
@export var status_id: StringName = &""
## Normal-hit proc chance for status_id (GAME-RULES §1.3 combat RNG) — default 0.0
## (sword_A never rolls). sword_burn_A calibration note (GAME-RULES §3 law):
## 0.3 dominated group fights during the pre-gate clump-burn replay (2026-08-04) —
## lowered to 0.15. Revisit again at the real M1 playtest gate. See the SLICE B
## SPEC note above for how this field's meaning narrows to "hit 3's chance" once
## per-hit combo profiles land — do not overload it with charge semantics before then.
@export var status_proc_chance: float = 0.0
