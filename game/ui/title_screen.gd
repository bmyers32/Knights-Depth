class_name TitleScreen
extends Control
## The first thing the game shows (M2 Slice 3). One deliberate action -- go Home -- and
## nothing behind it: no SimWorld, no Envoy, no camera, so no gameplay can run under the title by
## construction. The name is the project's working title (P14 leaves the decision open).

signal start_requested

const TITLE_TEXT: String = "KNIGHTS DEPTH"
const SUBTITLE_TEXT: String = "An expedition below the Commons"
const START_TEXT: String = "Enter"
const FOOTER_TEXT: String = "M2 development build"

const _TEXT_COLOR: Color = Color(0.86, 0.92, 0.92)
const _DIM_COLOR: Color = Color(0.60, 0.68, 0.70)
const _BACKGROUND: Color = Color(0.05, 0.07, 0.09)
const _ACCENT: Color = Color(0.62, 0.86, 0.90)

@export var title_font_size: int = 64
@export var subtitle_font_size: int = 22
@export var button_font_size: int = 24
@export var footer_font_size: int = 14

var _start: Button
var _requested: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = _BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	_label(column, TITLE_TEXT, title_font_size, _ACCENT)
	_label(column, SUBTITLE_TEXT, subtitle_font_size, _DIM_COLOR)
	_start = Button.new()
	_start.text = START_TEXT
	_start.add_theme_font_size_override("font_size", button_font_size)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.pressed.connect(request_start)
	column.add_child(_start)
	var footer := _label(self, FOOTER_TEXT, footer_font_size, _DIM_COLOR)
	footer.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(16.0, -32.0)
	# Enter / Space work at once, without reaching for the mouse.
	_start.grab_focus()


## The one action. Latched: a double click or a held key asks once.
func request_start() -> void:
	if _requested:
		return
	_requested = true
	_start.disabled = true
	start_requested.emit()


func freeze() -> void:
	_requested = true
	_start.disabled = true


func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
