extends Control

## How a person on the street talks: one line at a time, in a cream speech box
## with their name on a tab and a tail pointing at them, the way the shift
## floor's overheard calls look. Enter (or a click) finishes the line typing in,
## then turns the page; a bobbing arrow says there is more.
##
## A stage direction ("She points at Maria's house with her lips.") rides along
## in gray italics above the spoken line it belongs to, so a short beat is not
## a press of its own. The case note comes last, as its own dark page in the
## case file's monospaced voice - it is the file talking, not the person. Esc
## jumps straight to it, and Esc on it closes the box, so skipping the talk
## never skips the lesson.
##
## The box sits at the bottom of the screen, clear of the person talking; when
## the person is low on the screen it moves up under the HUD and the tail turns
## to point down at them.
##
## Preloaded, not a class_name - see text_style.gd.

const TextStyle := preload("res://scripts/systems/text_style.gd")

const WIDTH := 880.0
const EDGE_GAP := 26.0
## Below the HUD's four lines, for a box that has moved up.
const TOP_Y := 196.0
## The tallest box the street's pages make, give or take a line. A speaker
## whose head is below the top of a box this tall moves the box up.
const TALL_BOX := 190.0
const TYPE_CHARS_PER_SECOND := 55.0
const FONT_SIZE := 19
const PADDING := Vector4(28.0, 20.0, 28.0, 32.0)
const TEXT_WIDTH := WIDTH - 56.0
const FILL := Color(0.97, 0.94, 0.89, 0.97)
const INK := Color(0.11, 0.11, 0.14)
const MUTED := Color(0.42, 0.39, 0.36)
const EDGE := Color(0.20, 0.22, 0.29)
const NOTE_FILL := Color(0.07, 0.08, 0.11, 0.96)

var box: PanelContainer
var text: RichTextLabel
var tab: PanelContainer
var tab_label: Label
var arrow: Label
var footer: Label
var tail: Polygon2D
var tail_inner: Polygon2D

var speaker: String = ""
var pages: Array[String] = []
var note_line: String = ""
var note_color: String = ""
var page_index: int = -1
var on_note: bool = false
var at_top: bool = false
var speaker_at: Vector2 = Vector2.ZERO
var type_tween: Tween
var arrow_tween: Tween
var arrow_rest: Vector2


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	tail = Polygon2D.new()
	tail.color = EDGE
	add_child(tail)
	tail_inner = Polygon2D.new()
	tail.add_child(tail_inner)

	box = PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	text = RichTextLabel.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.bbcode_enabled = true
	text.scroll_active = false
	# Lay the whole page out first, then reveal it: words do not jump to the
	# next line as they type, and a page is measured at its full height even
	# when the last one was closed halfway through typing.
	text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	# Text with no box of its own - the box around it is the box.
	text.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	for size_name in ["normal_font_size", "italics_font_size", "bold_font_size"]:
		text.add_theme_font_size_override(size_name, FONT_SIZE)
	text.add_theme_constant_override("line_separation", 4)
	box.add_child(text)

	tab = PanelContainer.new()
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = EDGE
	tab_style.set_corner_radius_all(6)
	tab_style.content_margin_left = 14.0
	tab_style.content_margin_right = 14.0
	tab_style.content_margin_top = 3.0
	tab_style.content_margin_bottom = 4.0
	tab.add_theme_stylebox_override("panel", tab_style)
	tab_label = Label.new()
	tab_label.add_theme_font_size_override("font_size", 16)
	tab_label.add_theme_color_override("font_color", FILL)
	tab.add_child(tab_label)
	add_child(tab)

	arrow = Label.new()
	arrow.text = "▼"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_constant_override("outline_size", 0)
	add_child(arrow)

	footer = Label.new()
	footer.text = "Enter or Esc to step away"
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	add_child(footer)


## Open on the first page. `speaker_screen` is where the person stands on
## screen, which is where the tail points.
func open(speaker_name: String, body: String, note: String, color: String, speaker_screen: Vector2) -> void:
	speaker = speaker_name
	pages = pages_for(body)
	note_line = note
	note_color = color
	speaker_at = speaker_screen
	at_top = speaker_screen.y > get_viewport_rect().size.y - EDGE_GAP - TALL_BOX - 30.0
	visible = true
	page_index = -1
	on_note = false
	if pages.is_empty():
		_show_note()
	else:
		_show_page(0)


func is_open() -> bool:
	return visible


func is_typing() -> bool:
	return type_tween != null and type_tween.is_running()


func has_note() -> bool:
	return not note_line.is_empty()


## Enter or a click: finish the line, or turn the page, or close after the
## last one. Returns whether the box is still open.
func advance() -> bool:
	if not visible:
		return false
	if is_typing():
		_finish_typing()
		return true
	if not on_note and page_index < pages.size() - 1:
		AudioManager.play_sfx("click")
		_show_page(page_index + 1)
		return true
	if not on_note and has_note():
		AudioManager.play_sfx("click")
		_show_note()
		return true
	close()
	return false


## Esc: straight to the case note, or close from it. Returns whether the box
## is still open.
func skip_to_note() -> bool:
	if not visible:
		return false
	if not on_note and has_note():
		_show_note()
		_finish_typing()
		return true
	close()
	return false


func close() -> void:
	if type_tween != null:
		type_tween.kill()
	visible = false
	page_index = -1
	on_note = false


## The whole conversation as one string, the way tests and the capture tools
## read it.
func shown_text() -> String:
	return text.get_parsed_text()


# --- Pages --------------------------------------------------------------------

## Pages from a stop's body: a line with speech in it is a page; lines of pure
## stage direction ride along as a lead-in to the next one; a direction left at
## the end is a page of its own.
static func pages_for(body: String) -> Array[String]:
	var found: Array[String] = []
	var lead: Array[String] = []
	for raw in body.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			continue
		lead.append(line)
		if line.contains("\""):
			found.append(_page_bbcode(lead))
			lead.clear()
	if not lead.is_empty():
		found.append(_page_bbcode(lead))
	return found


static func _page_bbcode(lines: Array[String]) -> String:
	var out: Array[String] = []
	for line in lines:
		out.append(_line_bbcode(line))
	return "\n".join(out)


# Quoted speech in ink; everything around it in muted italic.
static func _line_bbcode(line: String) -> String:
	var regex := RegEx.new()
	regex.compile("\"[^\"]*\"")
	var pieces: Array[String] = []
	var last := 0
	for found in regex.search_all(line):
		var before := line.substr(last, found.get_start() - last).strip_edges()
		if not before.is_empty():
			pieces.append("[i][color=#%s]%s[/color][/i]" % [MUTED.to_html(false), before])
		pieces.append("[color=#%s]%s[/color]" % [INK.to_html(false), found.get_string()])
		last = found.get_end()
	var after := line.substr(last).strip_edges()
	if not after.is_empty():
		pieces.append("[i][color=#%s]%s[/color][/i]" % [MUTED.to_html(false), after])
	return " ".join(pieces)


# --- Showing a page -----------------------------------------------------------

func _show_page(index: int) -> void:
	page_index = index
	on_note = false
	var style := StyleBoxFlat.new()
	style.bg_color = FILL
	style.border_color = EDGE
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	_pad(style)
	box.add_theme_stylebox_override("panel", style)
	# The game's outline helps light text over the map; on cream it only
	# thickens dark letters.
	text.add_theme_constant_override("outline_size", 0)
	text.text = pages[index]
	tab.visible = true
	tab_label.text = speaker
	arrow.add_theme_color_override("font_color", EDGE)
	_layout(true)
	_type_in()


func _show_note() -> void:
	on_note = true
	var style := StyleBoxFlat.new()
	style.bg_color = NOTE_FILL
	style.border_color = Color.html(note_color) if not note_color.is_empty() else Color.html(TextStyle.COLOR_HINT)
	style.border_width_left = 5
	style.set_corner_radius_all(6)
	_pad(style)
	box.add_theme_stylebox_override("panel", style)
	text.add_theme_constant_override("outline_size", 2)
	text.text = note_line
	tab.visible = false
	_layout(false)
	_type_in()


func _pad(style: StyleBoxFlat) -> void:
	style.content_margin_left = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_right = PADDING.z
	style.content_margin_bottom = PADDING.w


# Sized from the text measured at the width it wraps to, not from the
# container's minimum size, which lags a frame behind new text - the tail and
# the arrow were placed for a box shorter than the one that got drawn.
func _layout(with_tail: bool) -> void:
	text.visible_ratio = 1.0
	text.size.x = TEXT_WIDTH
	text.custom_minimum_size.y = text.get_content_height()
	var box_size := Vector2(WIDTH, text.custom_minimum_size.y + PADDING.y + PADDING.w)
	box.size = box_size
	var screen := get_viewport_rect().size
	var y := TOP_Y if at_top else screen.y - EDGE_GAP - box_size.y
	box.position = Vector2((screen.x - WIDTH) * 0.5, y)

	tab.reset_size()
	var tab_size := tab.get_combined_minimum_size()
	tab.position = box.position + Vector2(24.0, -tab_size.y + 4.0)

	arrow_rest = box.position + box_size - Vector2(34.0, 30.0)
	arrow.position = arrow_rest
	footer.reset_size()
	footer.position = box.position + box_size - footer.get_combined_minimum_size() - Vector2(22.0, 6.0)

	tail.visible = with_tail
	if with_tail:
		var x := clampf(speaker_at.x, box.position.x + 48.0 + tab_size.x, box.position.x + WIDTH - 48.0)
		var edge := box.position.y + 2.0
		var tip := -22.0
		if at_top:
			edge = box.position.y + box_size.y - 2.0
			tip = 22.0
		tail.polygon = PackedVector2Array([Vector2(x - 15.0, edge), Vector2(x + 15.0, edge), Vector2(x, edge + tip)])
		tail_inner.color = FILL
		tail_inner.polygon = PackedVector2Array([Vector2(x - 10.0, edge - signf(tip) * 2.0),
			Vector2(x + 10.0, edge - signf(tip) * 2.0), Vector2(x, edge + tip * 0.68)])


func _type_in() -> void:
	if type_tween != null:
		type_tween.kill()
	_show_cue(false)
	var count := text.get_total_character_count()
	if count <= 0:
		_finish_typing()
		return
	text.visible_ratio = 0.0
	type_tween = create_tween()
	type_tween.tween_property(text, "visible_ratio", 1.0, float(count) / TYPE_CHARS_PER_SECOND)
	type_tween.tween_callback(_show_cue.bind(true))


func _finish_typing() -> void:
	if type_tween != null:
		type_tween.kill()
	text.visible_ratio = 1.0
	_show_cue(true)


# The arrow when there is another page, the closing hint on the last one; both
# only once the page has finished typing in.
func _show_cue(ready: bool) -> void:
	var last := on_note or (page_index >= pages.size() - 1 and not has_note())
	arrow.visible = ready and not last
	footer.visible = ready and last
	if arrow_tween != null:
		arrow_tween.kill()
	arrow.position = arrow_rest
	if arrow.visible:
		arrow_tween = create_tween().set_loops()
		arrow_tween.tween_property(arrow, "position:y", arrow_rest.y + 3.0, 0.35)
		arrow_tween.tween_property(arrow, "position:y", arrow_rest.y, 0.35)
