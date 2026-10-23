class_name ExitConsolePanel
extends CanvasLayer
## What the exit console says when inspected (M2 expedition frame, Slice 1): where the descent
## leads -- depth, place, stratum, the families expected -- or, on the last floor, that this is
## the way out. READ-ONLY presentation: it is handed a preview the driver derived from the cached
## destination plan and never asks for one of its own. Opening it changes nothing in the sim.
##
## It takes no clicks (every control ignores the mouse), so a press while it is open still
## reaches the attack button's own arbitration exactly as it would with the panel closed.

@export var title_font_size: int = 18
@export var depth_font_size: int = 40
@export var body_font_size: int = 22
@export var hint_font_size: int = 15
@export var panel_width: float = 380.0

const _TEXT_COLOR: Color = Color(0.86, 0.92, 0.92)
const _DIM_COLOR: Color = Color(0.60, 0.68, 0.70)
const _BACKGROUND: Color = Color(0.05, 0.07, 0.09, 0.86)
const _EDGE: Color = Color(0.55, 0.78, 0.82, 0.7)

## The final floor's console. Extraction only: Emergency Recall is the FAILURE ending (M2 Slice 2,
## 2026-10-20), and a way out that named it would promise the wrong one.
const EXTRACTION_HEADLINE: String = "Extraction"
const EXTRACTION_BODY: String = "The expedition ends here."

var _title: Label
var _headline: Label
var _place: Label
var _expected: Label
var _detail: Label
var _hint: Label


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_width - 32.0
	panel.offset_right = -32.0
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = _BACKGROUND
	style.border_color = _EDGE
	style.set_border_width_all(2)
	style.set_content_margin_all(20.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_title = _label(column, title_font_size, _DIM_COLOR)
	_headline = _label(column, depth_font_size, _TEXT_COLOR)
	_place = _label(column, body_font_size, _TEXT_COLOR)
	_expected = _label(column, body_font_size, _TEXT_COLOR)
	_detail = _label(column, hint_font_size, _DIM_COLOR)
	_detail.visible = false
	_hint = _label(column, hint_font_size, _DIM_COLOR)
	_hint.text = "Attack again, Esc, or walk away to close"
	visible = false


## `preview` is the driver's next_floor_preview(): {depth, place, stratum, families}. Empty means
## there is no next floor, and the console says so rather than inventing one.
## `title` and `detail` let a second reader of a plan (the Ready Room's Floor 1 briefing, M2 Slice 3)
## use the same panel; the exit console passes neither.
func open(preview: Dictionary, title: String = "DESCENT", detail: String = "") -> void:
	_detail.text = detail
	_detail.visible = detail != ""
	if preview.is_empty():
		_title.text = "WAY OUT"
		_headline.text = EXTRACTION_HEADLINE
		_place.text = EXTRACTION_BODY
		_expected.visible = false
	else:
		_title.text = title
		_headline.text = "Depth %d" % int(preview["depth"])
		var place: String = preview["place"]
		var stratum: String = preview["stratum"]
		_place.text = place if place == stratum else "%s · %s stratum" % [place, stratum]
		var names: PackedStringArray = []
		for family: StringName in preview["families"]:
			names.append(String(family).capitalize())
		_expected.text = "Expected: " + (", ".join(names) if not names.is_empty() else "no hostiles")
		_expected.visible = true
	visible = true


## A console that describes a PLACE rather than a floor ahead (the Commons notice, M2 Slice 3).
func open_notice(title: String, headline: String, body: String) -> void:
	_title.text = title
	_headline.text = headline
	_place.text = body
	_expected.visible = false
	_detail.visible = false
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


## Everything the panel currently says, top to bottom -- what a reader of the screen would read.
func text() -> String:
	var lines: PackedStringArray = []
	for label: Label in [_title, _headline, _place, _expected, _detail]:
		if label.visible:
			lines.append(label.text)
	return "\n".join(lines)


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
