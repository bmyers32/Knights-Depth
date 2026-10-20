class_name ResyncOverlay
extends CanvasLayer
## The caption for an incapacitated Envoy: Synchronization Failure, then the Emergency
## Resynchronization countdown, then a brief confirmation. PLACEHOLDER presentation (P39).
##
## IT DECIDES NOTHING. The countdown is the sim's own remaining ticks, handed in each step, and the
## caption changes only on the Events the driver forwards. Only the confirmation's linger runs on
## presentation time, and play has already resumed under it.

## Seconds the "resynchronized" line stays up. Presentation time only.
@export var confirm_seconds: float = 1.0

const FAILURE_LINE: String = "SYNCHRONIZATION FAILURE"
const RESYNC_LINE: String = "Emergency Resynchronization in %.1f s"
const RESYNCED_LINE: String = "RESYNCHRONIZED"

@onready var _label: Label = $Label
var _confirm_remaining: float = 0.0


func show_failure() -> void:
	_confirm_remaining = 0.0
	_label.text = FAILURE_LINE
	visible = true


func show_countdown(ticks_remaining: int, ticks_per_second: int) -> void:
	_confirm_remaining = 0.0
	_label.text = FAILURE_LINE + "\n" + RESYNC_LINE % (float(ticks_remaining) / float(ticks_per_second))
	visible = true


func show_resynchronized() -> void:
	_label.text = RESYNCED_LINE
	_confirm_remaining = confirm_seconds
	visible = true


func reset() -> void:
	_confirm_remaining = 0.0
	visible = false


func text() -> String:
	return _label.text


func _process(delta: float) -> void:
	if _confirm_remaining <= 0.0:
		return
	_confirm_remaining -= delta
	if _confirm_remaining <= 0.0:
		visible = false
