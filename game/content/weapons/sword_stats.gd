class_name SwordStats
extends Resource
## Sword-class weapon tunables (Prime Directive 3) — looked up via ContentDB, never
## literals in scripts. M1 default sword: Force-typed (GAME-RULES §3's "everybody's
## fallback" baseline).
##
## SLICE B (built this session — combo_profiles/charge_profile below): 3-hit combo
## with PER-HIT content profiles + hold-to-charge, both resolved through SimWorld's
## phased press/held/released attack model. NOT in this slice: the advancing
## multi-hit "Brandish" charge (staged multi-tick attack) — that's later content
## (ROADMAP P5 addendum) with its own spec, not assumed here.

## weapon_class (not `class` — reserved word for inner classes in GDScript) is
## GAME-RULES §3's required tag on every weapon resource (sword/gun/bomb).
@export var weapon_class: StringName = &"sword"

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law).
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

## SLICE B (this session): a weapon with a non-empty combo_profiles array is
## registered via SimWorld.register_melee_profiles instead of register_weapon and
## resolves through the phased press/held/released attack model (SimWorld._apply_
## phased_melee_attack) — the flat fields above (base_damage etc.) go unused for it.
## An EMPTY array (sword_A's default) keeps a weapon on the original flat
## instant-resolve path untouched. Exactly 3 entries when non-empty (the locked
## 3-hit combo); index 0/1/2 = hit 1/2/3.
@export var combo_profiles: Array[MeleeAttackProfile] = []
## The charge attack's OWN content profile (Slice B spec: never a hardcoded bigger
## normal hit) — only meaningful when combo_profiles is non-empty.
@export var charge_profile: MeleeAttackProfile = null
## Sim ticks the attack button must be held before a "released" phase resolves as
## the charge_profile instead of the current combo step — see SLICE B SPEC.
@export var charge_threshold_ticks: int = 0
## Sim ticks of inactivity after a completed tap swing before the combo sequence
## resets to hit 1 on the next press (GAME-RULES §3 calibration-note law: revisit at
## the M1 playtest gate).
@export var combo_reset_ticks: int = 0
## Manual-pass fix (2026-08-04): a "pressed" arriving during recovery used to be
## DROPPED outright (attack_rejected/on_cooldown, no swing at all) -- diagnosed as
## the likely dominant cause of "mush" (a slightly-early real click reading as
## nothing happening, worse than landing slightly late). A press within this many
## ticks of the cooldown clearing is QUEUED instead (SimWorld._melee_buffered_press)
## and automatically opens once the cooldown actually elapses. 0 (sword_A's default)
## is a true full disable -- see the calibration note below for why.
@export var input_buffer_ticks: int = 0
## Manual-pass calibration (2026-08-04): a real decision between finishing the combo
## and committing to the charge needs the threshold and the combo's own recovery
## windows to not overlap by accident — see the calibration note below for the exact
## numbers landed on.
##
## Charge-ready cue color (Prime Directive 3: no literal Color in scripts). No
## duration field alongside it -- the cue has no fixed duration by design (see
## SimWorld's "charge_ready"/"melee_hold_canceled" events): it's a persistent on/off
## listener, not a timed flash, since the player may hold indefinitely once
## saturated. TelegraphIndicator.set_active(color, active) is the presentation-side
## primitive; the Envoy only ever calls it in response to an Event, never polls sim
## state for it (locked precedent for every future persistent indicator).
@export var charge_ready_tint_color: Color = Color.WHITE

## Calibration note (GAME-RULES §3 law, no playtest date yet — first pass, chosen by
## feel/read-only reasoning, 2026-08-04): sword_burn_A.tres sets charge_threshold_
## ticks=48 (1.6s @ 30Hz, doubled from an initial 24/0.8s after a manual pass found a
## tap risked accidentally charging) and combo_reset_ticks=45 (1.5s); hits 1-2 deal 8
## damage/no proc, hit 3 deals 10 with the existing 0.15 Burn proc, the charge deals
## 20 with a guaranteed Burn proc. input_buffer_ticks=6 (200ms, matches hits 1-2's
## own recovery width as a first-pass reference scale). All numbers here are
## unvalidated placeholders — revisit together at the real M1 playtest gate, same as
## every other AI/Burn number from this milestone. Isolation note: input_buffer_
## ticks=0 is a true, complete, one-line disable of the whole buffer mechanism (a
## genuinely on-cooldown press is never within a 0-tick window); charge_threshold_
## ticks and combo_reset_ticks are likewise clean one-line reverts on their own.
##
## Lunge/windup calibration (manual-pass, 2026-08-05, first pass, unvalidated):
## hit1 lunge 0.5 over 4 ticks (hit_active 2), hit2 lunge 1.0 over 5 ticks
## (hit_active 2), hit3 lunge 1.2 over 5 ticks (hit_active 3) — small-then-more,
## flattening rather than spiking, per the intended curve (hit3 already carries the
## interrupt + Burn proc, so it doesn't also need to be the biggest movement spike).
## Charge: lunge 2.5 over 8 ticks (hit_active 4), windup_ticks=8 (~0.27s of
## anticipation) — the true large commitment. fire_interval_ticks reduced from the
## pre-lunge values (6/6/10/20 -> 2/1/5/5) since combo cadence between swings is now
## lunge_duration_ticks + fire_interval_ticks, not fire_interval_ticks alone —
## reduced to keep roughly the original total cadence rather than stacking lunge
## time on top of the old recovery windows unchanged.
