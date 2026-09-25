extends PanelContainer

## The box a street stop or an office station opens: a title, a body that
## scrolls when it is long, and the key that closes it. One script for the
## streets and the floors - they were two copies and had already drifted apart.
##
## It sits at the bottom of the screen, clear of the HUD, and is only as tall as
## its text up to MAX_BODY_HEIGHT, so a neighbor's three lines do not open a
## poster-sized box and the person talking stays in view above it.
## Preloaded, not a class_name - see text_style.gd.

const TextStyle := preload("res://scripts/systems/text_style.gd")

const WIDTH := 860.0
const BOTTOM_GAP := 24.0
const MARGIN := 22.0
## Tall enough for the call list, short enough to stay under the HUD's lines.
const MAX_BODY_HEIGHT := 380.0

var title_label: Label
var body: RichTextLabel
var scroll: ScrollContainer
var footer: Label


func _init(footer_text: String = "Enter or Esc to step away") -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	visible = false

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, int(MARGIN))
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	column.add_child(title_label)

	# Variable-length text in a bounded box has to scroll, or anything past
	# the fold is unreachable (see AGENTS.md).
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	body = RichTextLabel.new()
	# Text with no box of its own - the panel around it is the box.
	body.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	footer = Label.new()
	footer.text = footer_text
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	footer.add_theme_font_size_override("font_size", 13)
	column.add_child(footer)


func open(title: String, text: String) -> void:
	title_label.text = title
	body.text = text
	scroll.scroll_vertical = 0
	visible = true
	_fit()


## Measures the text at the width it will wrap to and sizes the box to it.
func _fit() -> void:
	body.size.x = WIDTH - MARGIN * 2.0
	scroll.custom_minimum_size.y = minf(body.get_content_height(), MAX_BODY_HEIGHT)
	var height := get_combined_minimum_size().y
	offset_top = -BOTTOM_GAP - height
	offset_bottom = -BOTTOM_GAP
