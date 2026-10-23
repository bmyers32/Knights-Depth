class_name FadeOverlay
extends CanvasLayer
## The short black fade between places (M2 Slice 3). Presentation time only: it decides nothing,
## it only tells GameMain when the screen is dark (swap now) and when it is clear again (hand
## input back). While it runs it swallows the mouse, so nothing underneath can be clicked mid-move.

@export var fade_out_seconds: float = 0.25
@export var fade_in_seconds: float = 0.25

var _rect: ColorRect
## +1 darkening, -1 clearing, 0 idle.
var _direction: int = 0
var _alpha: float = 0.0
var _on_done: Callable = Callable()


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func fade_out(on_dark: Callable) -> void:
	_begin(1, on_dark)


func fade_in(on_clear: Callable) -> void:
	_begin(-1, on_clear)


## Black at once, for a screen something else has already darkened (the deployment transmission).
func cover() -> void:
	_alpha = 1.0
	_rect.color.a = _alpha
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP


## Clear at once, for a destination that brings its own arrival picture.
func uncover() -> void:
	_direction = 0
	_on_done = Callable()
	_alpha = 0.0
	_rect.color.a = _alpha
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_busy() -> bool:
	return _direction != 0


func alpha() -> float:
	return _alpha


func _begin(direction: int, on_done: Callable) -> void:
	_direction = direction
	_on_done = on_done
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if _direction == 0:
		return
	var seconds: float = fade_out_seconds if _direction > 0 else fade_in_seconds
	_alpha = clampf(_alpha + _direction * (delta / maxf(seconds, 0.0001)), 0.0, 1.0)
	_rect.color.a = _alpha
	var finished: bool = _alpha >= 1.0 if _direction > 0 else _alpha <= 0.0
	if not finished:
		return
	if _direction < 0:
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_direction = 0
	var done: Callable = _on_done
	_on_done = Callable()
	if done.is_valid():
		done.call()
