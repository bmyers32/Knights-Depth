class_name GunStats
extends Resource
## Gun-class weapon tunables (Prime Directive 3) — looked up via ContentDB, never
## literals in scripts. Ranged: a deterministic projectile with travel time through
## the same combat pipeline melee uses (GAME-RULES §3), not a hitscan.

## weapon_class (not `class` — reserved word for inner classes in GDScript) is
## GAME-RULES §3's required tag on every weapon resource (sword/gun/bomb).
@export var weapon_class: StringName = &"gun"

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law). speed is continuous (units/second, mirrors
## movement); max_lifetime_ticks and fire_interval_ticks are sim-tick counts at 30 Hz
## (60 ticks = 2.0s, so an unfired shot travels up to 16 units before despawning).
## fire_interval_ticks=15 is a basic semi-automatic fire-rate gate (a flat cooldown
## between shots) — NOT the slice-B shared press/hold/release charge model GAME-RULES
## §3 locks; that lands as its own weapon-agnostic mechanism later, gun included.
## knockback_distance=0.0 (manual playtest finding, 2026-08-02): at this weapon's own
## ~16-unit range, repeat-fire knockback displaced a stationary target off the gun's
## aim line before the next shot arrived, not out of reach — a sword's single discrete
## swing can afford knockback, a gun's repeat-fire cadence along one line cannot.
@export var base_damage: float = 6.0
@export var damage_type: StringName = &"force"
@export var speed: float = 8.0
@export var max_lifetime_ticks: int = 60
## PROJECTILE VOLUME — the bolt's OWN radius, and nothing else. PROVISIONAL/UNVALIDATED,
## re-derived 2026-08-14 (P29 item 3) from 0.40 to 0.20.
##
## Before the geometry correction this number was doing two jobs: describing the bolt AND
## silently compensating for a collision test that never consulted the target's body. The
## body term is now explicit (collision resolves at hit_radius + target.combat_radius), so
## the compensation had to come back out or every body would be counted twice.
##
## 0.20, not the 0.15 first proposed: presentation is now tied 1:1 to this value
## (ProjectileTracer draws exactly hit_radius at VISUAL_SCALE 1.0), and the earlier 0.18
## tracer was already reported too small in playtest — 0.15 would have regressed that
## finding through the visual law itself.
##
## READABILITY DISCIPLINE (binding): if 0.20 still reads poorly, fix it with NON-WIDTH
## presentation levers only — trail, persistence, brightness/contrast, departure and
## impact cues. Never widen collision to buy visibility; lateral radius is gameplay
## geometry, not a display setting.
##
## This is the BASELINE for GunStats. wand_A (gun_stats.tres) inherits it. The dormant
## carousel guns (gun_pierce_A/arc/umbral) explicitly author the pre-correction 0.4 and
## are deliberately left alone -- recorded as content debt at ROADMAP P26.
@export var hit_radius: float = 0.20
@export var knockback_distance: float = 0.0
@export var fire_interval_ticks: int = 15
## Optional status payload (GAME-RULES §3) — see SwordStats.status_id. No M1 gun
## variant sets this; kept symmetric with SwordStats so both weapon classes carry the
## same content shape for future weapons.
@export var status_id: StringName = &""
## Normal-hit proc chance for status_id (GAME-RULES §1.3 combat RNG) — see
## SwordStats.status_proc_chance. All M1 gun variants stay 0.0 (guns never proc).
@export var status_proc_chance: float = 0.0

## FLINCH — see MeleeAttackProfile.flinch_capability for the full enum and the
## independence law. wand_A ships contributes + &"exploit" (PROVISIONAL): it punishes
## VULNERABLE windows at range but never cashes pressure, so the sword finisher keeps
## the cash-out monopoly. Framing: this is LOADOUT/SYSTEM identity — the wand's family
## identity stays "simple reliable ranged weapon." If exploit proves unearned, compare
## against &"none" FIRST; do not build compensating gun features.
##
## SEAM NOTE (recorded deliberately): these fields sit on GunStats because a gun is
## currently one weapon = one attack = one hit identity — there is no per-attack
## profile layer beneath it, unlike SwordStats.combo_profiles. They MIGRATE to
## per-attack profiles when guns gain basic/charge/burst distinctions (ROADMAP P26).
## Do not invent a profile layer for two fields now.
@export var flinch_capability: StringName = &"exploit"
@export var contributes_pressure: bool = true
