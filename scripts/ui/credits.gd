extends Control

## The credits screen, reached from the main menu.
##
## Two things in the build are used under Creative Commons Attribution and
## several more under CC-BY 4.0 / CC-BY-SA 4.0 - the Calciumtrice portraits,
## the Font Awesome icons, the interrogation photo, the music and four Freesound
## recordings. Their licenses want the credit *in the game*, and a row in
## CREDITS.md is not that. This screen is what satisfies them.
##
## The lines live in resources/credits/credits.json, sections of entries, so
## the wording is data and not scattered through a builder. An entry marked
## `required` carries the author's own wording and a `key` that must also
## appear in CREDITS.md - test_credits checks both, so neither file can be
## edited without the other noticing.

const CREDITS_PATH := "res://resources/credits/credits.json"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const TextStyle := preload("res://scripts/systems/text_style.gd")

var credits: Dictionary = {}
var lines_box: VBoxContainer


func _ready() -> void:
	AudioManager.stop_ambience()
	AudioManager.play_music("menu", -12.0)
	credits = load_credits()
	_build_ui()


static func load_credits() -> Dictionary:
	var file := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open credits: %s" % CREDITS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Credits are not a dictionary: %s" % CREDITS_PATH)
		return {}
	return parsed


## Every entry in the file that carries `required: true`.
static func required_entries(data: Dictionary) -> Array:
	var found: Array = []
	for section in data.get("sections", []):
		for entry in (section as Dictionary).get("entries", []):
			if bool((entry as Dictionary).get("required", false)):
				found.append(entry)
	return found


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Handled first, then leave: change_scene_to_file() takes this node out
		# of the tree at once, and a node outside the tree has no viewport to
		# mark. The other way round was a script error in the editor and an
		# access violation in the exported release build (found 2026-09-20).
		get_viewport().set_input_as_handled()
		_back()


func _back() -> void:
	SessionState.go_to_scene(MAIN_MENU_SCENE)


# --- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/art/backgrounds/copernico-p_kICQCOM4s-unsplash.jpg")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 620)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Credits"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)

	var intro := Label.new()
	intro.text = str(credits.get("intro", ""))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	column.add_child(intro)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	lines_box = VBoxContainer.new()
	lines_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines_box.add_theme_constant_override("separation", 6)
	scroll.add_child(lines_box)

	for section in credits.get("sections", []):
		_add_section(section as Dictionary)

	var closing := Label.new()
	closing.text = str(credits.get("closing", ""))
	closing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	closing.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	lines_box.add_child(closing)
	# The scroll's reach is measured before the last label has wrapped; a
	# little room at the end keeps its second line from falling off the bottom.
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 24)
	lines_box.add_child(tail)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 40)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(_back)
	column.add_child(back)


func _add_section(section: Dictionary) -> void:
	var heading := Label.new()
	heading.text = str(section.get("title", "")).to_upper()
	heading.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	heading.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_HINT))
	# A little air above every heading but the first.
	if lines_box.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		lines_box.add_child(spacer)
	lines_box.add_child(heading)
	for entry in section.get("entries", []):
		var line := Label.new()
		line.text = str((entry as Dictionary).get("line", ""))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not bool((entry as Dictionary).get("required", false)):
			line.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_SPEECH))
			line.modulate = Color(1, 1, 1, 0.85)
		lines_box.add_child(line)


## Everything on the screen as one string, for the test to search.
func rendered_text() -> String:
	var text := ""
	for label in find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text
