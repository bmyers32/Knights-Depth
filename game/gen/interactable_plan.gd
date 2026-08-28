class_name InteractablePlan
extends RefCounted
## WORLD INTERACTION layer: something the player deliberately operates.
##
## Narrow on purpose -- a party button and an ordinary switch differ only in presentation and
## in what their trigger does. The BEHAVIOUR is entirely in the trigger's effect list, so
## adding a third kind needs no new mechanism.
##
## `starts_hidden` is how concealment-by-breakable works: the interactable is authored into the
## floor from the start but is neither visible nor usable until a REVEAL effect enables it.
## That keeps "search the environment -> discover progression control" a floor-state question
## rather than a spawning one.

var interactable_id: int = -1
var position: Vector3 = Vector3.ZERO
## Player must be within this distance to operate it.
var use_radius: float = 2.0
## &"party_button" | &"switch" -- presentation key only; consequence lives in the trigger.
var kind: StringName = &"switch"
var starts_hidden: bool = false
