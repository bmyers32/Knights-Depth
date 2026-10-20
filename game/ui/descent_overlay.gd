class_name DescentOverlay
extends CanvasLayer
## The screen fade of a descent: it darkens as the transmission completes and clears after
## arrival. No caption -- where the descent leads is the exit console's to say, and only when
## asked (revised 2026-10-19). PLACEHOLDER presentation for the M2 expedition frame (P39).
##
## IT OWNS NO TIMING THAT MATTERS. While descending, the darkness is set from the Expedition's
## progress each sim tick (show_progress); the descent ends when the Expedition says so. Only the
## fade back up after arrival runs on presentation time, and the sim is already live under it.

## Progress at which the screen starts to darken, and the darkness it reaches at the end. Late, so
## the transmission itself is seen before the screen goes.
@export var fade_start_progress: float = 0.75
@export var max_darkness: float = 1.0
## Seconds the screen takes to clear after arrival. Presentation time only.
@export var arrival_fade_seconds: float = 0.5

@onready var _shade: ColorRect = $Shade
var _clearing_seconds: float = 0.0
var _descending: bool = false


func begin() -> void:
	_descending = true
	_clearing_seconds = 0.0
	show_progress(0.0)
	visible = true


func show_progress(progress: float) -> void:
	_shade.color.a = max_darkness * smoothstep(fade_start_progress, 1.0, progress)


func arrive() -> void:
	_descending = false
	_clearing_seconds = arrival_fade_seconds


func is_descending() -> bool:
	return _descending


func _process(delta: float) -> void:
	if not visible or _descending:
		return
	_clearing_seconds -= delta
	_shade.color.a = max_darkness * clampf(_clearing_seconds / arrival_fade_seconds, 0.0, 1.0)
	if _clearing_seconds <= 0.0:
		visible = false
