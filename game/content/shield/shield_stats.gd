class_name ShieldStats
extends Resource
## Shield-class tunables (Prime Directive 3) — looked up via ContentDB, never literals
## in scripts. GAME-RULES §3: hold-to-block with its own break meter that regenerates,
## knockback on break. State machine (READY/HELD/BROKEN) lives in SimWorld
## (register_shield); this resource only carries the resolved numbers.

## VALIDATED-FOR-M1 at the combat RE-GATE 2026-08-13 (frozen build 41ffd5a): verdict
## PASS against the absolute bar "a viable M1 combat foundation despite primitive
## content". Observed feel, verbatim: "much better now... I can die sometimes when I
## get aggro from all three and try to manage them all at once"; "no incoming damage
## felt unreasonable"; "Displacement and flinch looked good".
## VALIDATED-FOR-M1 means judged SOUND AS A FOUNDATION in live play -- NOT individually
## optimised, and not a claim any single number below is right. NUMERIC-TUNING FENCE:
## no further HP/output/flinch-threshold micro-tuning until a specific future playtest
## finding demands it (GAME-RULES calibration-note law). These are the project's first meaningful
## combat-feel defaults (shield/i-frames, Phase D step 5) — UNVALIDATED PENDING THE
## STEP 8 PLAYTEST. Do not treat the seconds figures below as "this feels right";
## they exist only so the tick counts are legible against real time while reading data.
@export var meter_max: float = 20.0
## Regen rate. At the project's fixed 30 Hz sim tick (CLAUDE.md Stack): 0.4/tick =
## 12.0 meter/sec -> a full 0->20 regen takes 50 ticks ≈ 1.67s. Unvalidated feel.
@export var regen_per_tick: float = 0.4
## Ticks the meter stays locked at 0 after a break before regen resumes. At 30 Hz:
## 30 ticks = 1.0s. Unvalidated feel.
@export var break_recovery_delay_ticks: int = 30
@export var knockback_distance: float = 1.5

## --- P16 TREAT (M1 close): shield bump + perfect parry ---------------------------
## TWO SEPARABLE MECHANICS sharing only the shield. Tune them independently; neither
## implies the other. Progression: normal block = safety · bump = spacing control ·
## perfect parry = defense converted into a short offensive advantage.
##
## 1. SHIPPED BUMP — spacing utility, deliberately NOT timing-dependent. Fires on the
## READY->HELD RISING EDGE only, so any player gets it; it is not a skill check.
## Eligibility is `distance <= _contact_distance(blocker, hostile) + bump_padding`, so
## the authored number means EXTRA PROXIMITY BEYOND the two actors' combat footprints
## and therefore scales itself across Fang (0.90), Watcher (0.85) and Ooze (1.45)
## without per-family values. PROVISIONAL/UNVALIDATED.
@export var bump_padding: float = 0.35
## BUMP is a short authored SLIDE, not KNOCKBACK (LEXICON): the target is pushed out
## over bump_slide_ticks so the motion reads as a physical shove followed by a brief
## authoritative slide -- "get off me" -- rather than the impulse of a heavy hit.
## The field was renamed from bump_knockback_distance the moment it stopped using
## knockback semantics; a name that lies about its mechanism is worse than a rename.
## CANDIDATE B, VALIDATED FOR CURRENT USE (playtest 2026-08-13): 2.5 over 10 ticks =
## 0.250 u/tick. Observed feel, verbatim: "reads sufficiently like a shove/slide instead
## of ordinary knockback". That is the motion-language finding this revision existed to
## answer, so it is answered; NO FURTHER TUNING without a specific future finding.
## Validated means the motion READS RIGHT -- not that the numbers are optimal, and not
## that every consequence was exercised. Comfortably below the sword charge lunge's
## 0.3125 u/tick, so no easing framework is needed.
## STILL UNTESTED, carried deliberately: B's 10-tick slide spans most of Fang's 12-tick
## windup, so bumping a winding-up Fang can carry it out of reach and make the attack
## whiff. Once, that is legitimate spacing payoff; if it ever becomes the COMMON case,
## ordinary bump has become de facto attack denial and is leaking perfect parry's
## mastery value into a no-timing baseline action. Candidate A (2.0 over 7) is the
## one-edit step back if that is ever observed. A was drafted first for this reason and
## was never playtested, so the concern is UNTESTED rather than resolved.
@export var bump_distance: float = 2.5
@export var bump_slide_ticks: int = 10
## Own absolute cooldown so holding, or re-raising, cannot continuously repel. While
## it is cooling down the shield still raises and blocks entirely normally -- the bump
## is the only thing suppressed. LOCKED RULE: the cooldown arms only when at least one
## hostile is actually displaced; it rate-limits the spacing EFFECT, and an empty
## shield raise spends nothing.
@export var bump_cooldown_ticks: int = 45

## 2. PERFECT PARRY — mastery layer. A hit resolving within this many ticks of the
## shield's rising edge (SimWorld._block_start_tick, which already exists) marks the
## ATTACKER "PARRY EXPOSED" (LEXICON): a temporary INCOMING-DAMAGE MULTIPLIER, and
## nothing else. Deliberately ONE reward -- no stun, no automatic flinch, no meter
## refund, no bonus direct damage, no extra i-frames.
## The parried hit still drains the meter normally: a parry must not quietly become a
## meter-efficiency mechanic too.
@export var parry_window_ticks: int = 6
## PARRY EXPOSED is distinct from VULNERABLE (an enemy action's flinch susceptibility)
## and implies NO EXPLOIT susceptibility -- damage only. REFRESH, never stack: a newly
## earned parry always sets a fresh FULL window (until = now + exposure), never adds
## remaining duration, and the multiplier never compounds. This deliberately DIVERGES
## from flinch's non-extension rule -- a defender-earned window should renew on every
## success, whereas flinch must not be extendable by the attacker.
@export var parry_exposure_ticks: int = 45
@export var parry_damage_multiplier: float = 1.5
