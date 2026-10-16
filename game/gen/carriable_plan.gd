class_name CarriablePlan
extends Resource
## WORLD INTERACTION layer: a physical object an Envoy lifts, carries and delivers (Floor 4 Stage
## 2, ruled 2026-10-16). First consumer: the Foundry's two keys.
##
## NOT A HIT-SWITCH, NOT A BREAKABLE, NOT A COMBATANT. It is never struck, has no durability and
## no health, and enemies never target it. It shares nothing with the hit scans: an Envoy reaches
## it by standing close and aiming toward it, and the sim alone decides whether that press lifted it
## (SimWorld._resolve_interaction_target).
##
## ITS DESTINATION IS NOT ITS PROPERTY. A carriable names no socket and no gate. Where it can go
## is authored on the RECEIVER (a FloorTrigger of kind carriable_inserted), so "either key fits
## either receiver" is true by construction rather than by a matching rule.
##
## Copied, never aliased, by LayoutCompiler -- the same reason every other layer record is.

## AUTHORING IDENTITY (P36 Slice A): content cross-references and tests use it; the runtime never
## reads it.
@export var key: StringName = &""
@export var carriable_id: int = -1
## Where it rests before anyone lifts it.
@export var position: Vector3 = Vector3.ZERO
## A HIDDEN carriable is not drawn and cannot be lifted until an authored reveal makes it real --
## the hit-switch concealment rule, applied to a thing you carry.
@export var starts_hidden: bool = false
