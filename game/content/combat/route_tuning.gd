class_name RouteTuning
extends Resource
## The ONE world-level parameter of the two-bucket recent-locomotion fact (P17 spec
## `d070b63`) — resolved by the driver and unpacked into SimWorld as a plain value, exactly
## like DamageMatrix and FlinchTuning.
##
## WHY IT IS WORLD-LEVEL and not Fang content, per the spec's sentence test:
##   "Does changing this alter what the sim says recent travel IS, or only what Fang is
##    willing to react to?"
## Changing the window changes what the sim reports as an actor's recent travel, for every
## observer. It defines the fact. Consumer interpretation — how much coherent travel Fang
## requires before trusting that direction — is `FangStats.cutoff_min_route_distance` and
## lives with the consumer.
##
## This resource holds exactly one field on purpose. θ (turn threshold) and G (stop grace)
## were DELETED by the representation, not moved here: a bounded horizon ages a turn out by
## in-window cancellation and a stop out by ceasing to contribute. See the spec's recorded
## review lesson about auditing every job a deleted parameter used to do.

## The bucket width. `recent_route` always covers between N and 2N ticks of ordinary
## locomotion, because normalization keeps one completed bucket plus the one in progress.
##
## PROVISIONAL/UNVALIDATED (spec `d070b63`). 15 ticks = a 0.5–1.0 s recent-history horizon
## at 30 Hz. Larger widens the horizon and increases lag behind a curving route (at radius 4
## the chord trails the true tangent by 14°–29° at this value); smaller tightens the lag but
## leaves less accumulated travel at the short end of the window, pushing eligibility toward
## the trust floor.
##
## HORIZON, NOT TRUST: this governs how much recent history shapes the derived DIRECTION.
## How much coherent travel a consumer requires before believing it is a separate job with a
## separate number (FangStats.cutoff_min_route_distance). Future tuning must not conflate
## them — they answer different questions and move for different reasons.
@export var route_window_ticks: int = 15
