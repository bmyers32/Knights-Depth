class_name RunSummaryOverlay
extends CanvasLayer
## The end of an expedition (M2 Slice 2): ONE layout, TWO outcomes that never read alike.
## Extraction is the party coming home; Emergency Recall is recovery running out. They share the
## frame and the facts table, and differ in headline, line and accent -- never one "run over" card.
##
## IT REPORTS, IT NEVER DECIDES. The driver finalizes the outcome once, at the authoritative
## boundary, and hands this a frozen list of [label, value] rows taken from run state and the
## damage ledger. Nothing here reads the sim, and nothing here can change what it was given.
##
## THE ROWS ARE A LIST ON PURPOSE. Loot gathered belongs on this screen once loot exists (ROADMAP);
## it will arrive as more rows or its own section appended below these, not as a rewrite. Until
## then it is ABSENT -- never an empty or zero row standing in for a system that does not exist.

const OUTCOME_EXTRACTION: StringName = &"extraction"
const OUTCOME_RECALL: StringName = &"recall"

const _COPY: Dictionary = {
	OUTCOME_EXTRACTION: {
		"title": "EXPEDITION ENDED",
		"headline": "EXTRACTION COMPLETE",
		"line": "The Envoy completed the expedition and extracted to the Commons.",
		"accent": Color(0.55, 0.85, 0.72),
	},
	OUTCOME_RECALL: {
		"title": "EXPEDITION ENDED",
		"headline": "EMERGENCY RECALL",
		"line": "Recovery exhausted. The Envoy was recalled to the Commons before the expedition was complete.",
		"accent": Color(0.92, 0.55, 0.42),
	},
}
const RESTART_HINT: String = "Press R to redeploy"

@export var title_font_size: int = 18
@export var headline_font_size: int = 40
@export var body_font_size: int = 20
@export var hint_font_size: int = 16
@export var panel_width: float = 560.0
## The screen darkens over this long before the summary appears -- the recall's "signal lost" beat,
## and long enough for the extraction's transmission to finish. Presentation time only.
@export var intro_seconds: float = 1.6
@export var max_darkness: float = 0.82

const _TEXT_COLOR: Color = Color(0.86, 0.92, 0.92)
const _DIM_COLOR: Color = Color(0.60, 0.68, 0.70)
const _BACKGROUND: Color = Color(0.05, 0.07, 0.09, 0.92)

var _shade: ColorRect
var _panel: PanelContainer
var _style: StyleBoxFlat
var _title: Label
var _headline: Label
var _line: Label
var _rows_box: VBoxContainer
var _hint: Label
var _outcome: StringName = &""
var _rows: Array = []
var _intro_elapsed: float = 0.0


func _ready() -> void:
	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_shade)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -panel_width * 0.5
	_panel.offset_right = panel_width * 0.5
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_style = StyleBoxFlat.new()
	_style.bg_color = _BACKGROUND
	_style.set_border_width_all(2)
	_style.set_content_margin_all(24.0)
	_panel.add_theme_stylebox_override("panel", _style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	_title = _label(column, title_font_size, _DIM_COLOR)
	_headline = _label(column, headline_font_size, _TEXT_COLOR)
	_line = _label(column, body_font_size, _TEXT_COLOR)
	_rows_box = VBoxContainer.new()
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rows_box)
	_hint = _label(column, hint_font_size, _DIM_COLOR)
	_hint.text = RESTART_HINT
	_panel.visible = false
	visible = false


## Shown ONCE per expedition: a second call is refused, so a late duplicate can never swap the
## outcome on screen or rewrite the facts under it.
func show_outcome(outcome: StringName, rows: Array) -> void:
	if is_open():
		return
	assert(_COPY.has(outcome), "unknown run outcome '%s'" % outcome)
	_outcome = outcome
	_rows = rows.duplicate(true)
	var copy: Dictionary = _COPY[outcome]
	_title.text = copy["title"]
	_headline.text = copy["headline"]
	_headline.add_theme_color_override("font_color", copy["accent"])
	_style.border_color = copy["accent"]
	_line.text = copy["line"]
	for child in _rows_box.get_children():
		child.queue_free()
	for row: Array in _rows:
		var label: Label = _label(_rows_box, body_font_size, _TEXT_COLOR)
		label.text = "%s:  %s" % [row[0], row[1]]
	_intro_elapsed = 0.0
	_shade.color.a = 0.0
	_panel.visible = false
	visible = true


func is_open() -> bool:
	return visible


func outcome() -> StringName:
	return _outcome


## The value shown against a label, or "" when the summary has no such row.
func row_value(label: String) -> String:
	for row: Array in _rows:
		if row[0] == label:
			return row[1]
	return ""


func row_labels() -> Array:
	return _rows.map(func(row: Array) -> String: return row[0])


## Everything the summary says, top to bottom -- what a reader of the screen would read.
func text() -> String:
	var lines: PackedStringArray = [_title.text, _headline.text, _line.text]
	for row: Array in _rows:
		lines.append("%s:  %s" % [row[0], row[1]])
	lines.append(_hint.text)
	return "\n".join(lines)


## 0..1 through the intro; 1 once the summary is up. The extraction's transmission is drawn
## against this so the two cannot drift apart.
func intro_progress() -> float:
	if not visible:
		return 0.0
	return clampf(_intro_elapsed / intro_seconds, 0.0, 1.0)


func is_summary_shown() -> bool:
	return _panel.visible


func _process(delta: float) -> void:
	if not visible or _panel.visible:
		return
	_intro_elapsed += delta
	var progress: float = intro_progress()
	_shade.color.a = max_darkness * smoothstep(0.35, 1.0, progress)
	if progress >= 1.0:
		_panel.visible = true


func _label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
