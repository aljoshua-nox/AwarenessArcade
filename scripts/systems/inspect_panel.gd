extends PanelContainer

## The box a street stop or an office station opens: a title, a body that
## scrolls when it is long, the case file's note on a card of its own, and the
## key that closes it. One script for the streets and the floors - they were
## two copies and had already drifted apart. People on the street talk through
## TalkBox instead; this is for things that are read.
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
## The note's card scrolls with the text, inside this, so a long read (the call
## list) scrolls no sooner with a card than it did without one.
const MAX_BODY_HEIGHT := 380.0
const SEPARATION := 12
const RULE_COLOR := Color(0.79, 0.83, 0.88, 0.25)

var title_label: Label
var body: RichTextLabel
var scroll: ScrollContainer
var content: VBoxContainer
var rule: ColorRect
var note_card: PanelContainer
var note: RichTextLabel
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
	column.add_theme_constant_override("separation", SEPARATION)
	margin.add_child(column)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	column.add_child(title_label)

	# Variable-length text in a bounded box has to scroll, or anything past
	# the fold is unreachable (see AGENTS.md).
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", SEPARATION)
	scroll.add_child(content)

	body = RichTextLabel.new()
	# Text with no box of its own - the panel around it is the box.
	body.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(body)

	# What the case file makes of it, set apart from what was read: a thin rule,
	# then a card whose left edge is the note's color, as on the journal's pages.
	rule = ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.color = RULE_COLOR
	rule.visible = false
	content.add_child(rule)

	note_card = PanelContainer.new()
	note_card.theme_type_variation = &"Card"
	note_card.visible = false
	content.add_child(note_card)
	note = RichTextLabel.new()
	note.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	note.bbcode_enabled = true
	note.scroll_active = false
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_card.add_child(note)

	footer = Label.new()
	footer.text = footer_text
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	footer.add_theme_font_size_override("font_size", 13)
	column.add_child(footer)


## `note` is a system line (TextStyle.system), shown on the card edged in
## `note_color`; leave it empty for a box with nothing to add.
func open(title: String, text: String, note_text: String = "", note_color: String = "") -> void:
	title_label.text = title
	body.text = text
	note.text = note_text
	var has_note := not note_text.is_empty()
	rule.visible = has_note
	note_card.visible = has_note
	if has_note:
		var edge: StyleBoxFlat = note_card.get_theme_stylebox("panel").duplicate()
		edge.border_color = Color.html(note_color if not note_color.is_empty() else TextStyle.COLOR_HINT)
		note_card.add_theme_stylebox_override("panel", edge)
	scroll.scroll_vertical = 0
	visible = true
	_fit()


## Everything the box is showing, as one string - what tests read.
func shown_text() -> String:
	if note_card.visible:
		return "%s\n\n%s" % [body.text, note.text]
	return body.text


## Measures the text at the width it really wraps to and sizes the box to it.
## That width is inside the panel's own margins as well as MARGIN: measuring
## without them came out a line short on a long text, and the box opened with
## its last line hidden behind a scrollbar.
func _fit() -> void:
	var inner := WIDTH - MARGIN * 2.0 - _side_margins(self, SIDE_LEFT, SIDE_RIGHT)
	body.size.x = inner
	var needed := body.get_content_height()
	if note_card.visible:
		note.size.x = inner - _side_margins(note_card, SIDE_LEFT, SIDE_RIGHT)
		note.custom_minimum_size.y = note.get_content_height()
		var card_height := note.custom_minimum_size.y + _side_margins(note_card, SIDE_TOP, SIDE_BOTTOM)
		needed += SEPARATION * 2.0 + rule.custom_minimum_size.y + card_height
	scroll.custom_minimum_size.y = minf(needed, MAX_BODY_HEIGHT)
	var height := get_combined_minimum_size().y
	offset_top = -BOTTOM_GAP - height
	offset_bottom = -BOTTOM_GAP


func _side_margins(control: Control, first: Side, second: Side) -> float:
	var style := control.get_theme_stylebox("panel")
	if style == null:
		return 0.0
	return style.get_margin(first) + style.get_margin(second)
