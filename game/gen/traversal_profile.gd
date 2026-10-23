class_name TraversalProfile
extends Resource
## A CONTENT-AUTHORED SHAPE FOR GENERATED CONNECTIVE GROUND (ADR-001 §5.2, LEXICON O7; S2).
##
## Every number here was measured on the shipped floors first (ADR-001-S2-MEASUREMENTS.md) and
## lives in a .tres, never in code (Prime Directive 3). A profile says what a hallway between
## two pieces may be: how wide, how long in total, how many straight legs, how short a leg may
## be before it turns, and what its edges are made of.
##
## ONE STYLE FOR THE HALLWAY AND ITS JOINTS (S1 finding, BRAIN): an aperture's flanks coincide
## with the hallway's own edges over the overlap span, and FloorPlan refuses two styles on one
## span. The profile therefore owns `boundary_style` once, and the composer writes it to both
## the hallway rects and the joints that enter them.
##
## LENGTHS ARE GRID-STEPPED by the recipe's cell, never continuous: the enumeration ring the
## placer walks is finite and in a fixed order, which is what makes a seed reproducible.

@export var profile_id: StringName = &""
## Hallway width across travel. A port narrower than this is covered by the hallway; a port
## wider is a rejected pairing, never a silently widened aperture.
@export var width: float = 6.0
## Total route length (sum of legs, centreline) the profile allows.
@export var length_min: float = 8.0
@export var length_max: float = 16.0
## 1: straight only. 2: straight or one turn (L). 3: also two turns (Z / U).
@export var max_legs: int = 1
## The shortest leg the profile tolerates before or after a turn.
@export var leg_min: float = 8.0
## Joint geometry at both ends: the gap between the hallway rect and the port edge, and how far
## the aperture reaches into each patch.
@export var gap: float = 2.0
@export var overlap: float = 1.5
## Presentation facts carried whole: the hallway's surface and its ONE boundary style.
@export var surface: StringName = &"stone"
@export var boundary_style: StringName = &"ledge"


## Every structural fault a profile has on its own.
func lint() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if profile_id == &"":
		out.append({"rule": &"profile_id_missing", "message": "TraversalProfile: a profile must be named", "refs": {}})
	if width <= 0.0 or length_min <= 0.0 or length_max < length_min or leg_min <= 0.0 or gap < 0.0 or overlap <= 0.0:
		out.append({"rule": &"profile_band_invalid", "message": "TraversalProfile '%s': width %s, length [%s, %s], leg_min %s, gap %s, overlap %s are not a usable band"
			% [profile_id, width, length_min, length_max, leg_min, gap, overlap], "refs": {"profile": profile_id}})
	if max_legs < 1 or max_legs > 3:
		out.append({"rule": &"profile_legs_invalid", "message": "TraversalProfile '%s': max_legs %d is not 1, 2 or 3" % [profile_id, max_legs], "refs": {"profile": profile_id}})
	if leg_min * max_legs > length_max:
		out.append({"rule": &"profile_band_invalid", "message": "TraversalProfile '%s': %d legs of at least %s cannot fit in %s" % [profile_id, max_legs, leg_min, length_max], "refs": {"profile": profile_id}})
	return out
