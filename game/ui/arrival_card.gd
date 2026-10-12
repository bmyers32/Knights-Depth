class_name ArrivalCard
extends CanvasLayer
## Temporary arrival notice for a descent -- NOT the elevator, the next-floor preview or a
## descent animation, which are separate M2 gate items (ROADMAP P35). It says where the party
## just arrived and gets out of the way.
##
## NON-BLOCKING BY CONSTRUCTION (ruled): it never pauses the sim, never takes input, and sits
## clear of the play area. The sim keeps ticking underneath from the first tick of the new floor.

## How long the card stays up. Presentation time (seconds), not a sim duration -- nothing in
## the sim waits on it.
@export var display_seconds: float = 2.5

@onready var _label: Label = $Label
var _remaining_seconds: float = 0.0


func show_arrival(depth: int, stratum_id: StringName) -> void:
	_label.text = "Depth %d · %s" % [depth, String(stratum_id).capitalize()]
	_remaining_seconds = display_seconds
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_remaining_seconds -= delta
	if _remaining_seconds <= 0.0:
		visible = false
