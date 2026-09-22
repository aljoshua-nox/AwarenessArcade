extends Control

## The card shown once at launch, before the main menu.
##
## The standard fiction notice - nobody in the game is a real person, no
## company is a real company - plus the one line a scam-awareness game owes its
## player: the tactics are shown so they can be recognised, not copied. It is
## the project's main scene; every other road to the menu (an ending, the
## credits' Back, the pause menu) goes straight to main_menu.tscn and never
## passes through here again.
##
## It fades in and ignores input until it has, so a key held from the launcher
## cannot skip it unread. After that any key, a click, or the button continues.

const TextStyle := preload("res://scripts/systems/text_style.gd")

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const FADE_IN_SECONDS := 0.6

const HEADING := "Disclaimer"
const PARAGRAPHS := [
	"Dial and Deceive is a work of fiction. The people, companies, phone numbers, addresses and events in it are products of the writers' imagination or are used fictitiously. Any resemblance to actual persons, living or dead, to real businesses or organizations, or to actual events is purely coincidental.",
	"The scam tactics shown are drawn from patterns reported in real fraud cases and are depicted for awareness and education only. Nothing in this game is meant as instruction, and the game does not endorse fraud or any other crime.",
]
const PROMPT := "Press any key or click to continue."

## Where Continue goes. A test points it at "" so the card can be driven
## without leaving the tree (go_to_scene ignores an empty path).
var next_scene: String = MAIN_MENU_SCENE
## Set once the fade has finished; input before then is dropped.
var can_continue: bool = false
var continued: bool = false

var card: PanelContainer


func _ready() -> void:
	AudioManager.stop_ambience()
	# The menu's track starts under the card and carries into the menu, which
	# asks for the same one and so does not restart it.
	AudioManager.play_music("menu", -12.0)
	_build_ui()
	card.modulate = Color(1, 1, 1, 0)
	var fade := create_tween()
	fade.tween_property(card, "modulate", Color.WHITE, FADE_IN_SECONDS)
	fade.finished.connect(func() -> void: can_continue = true)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey:
		pressed = event.is_pressed() and not event.is_echo()
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.is_pressed()
	if not pressed:
		return
	# Marked before leaving: change_scene_to_file() takes this node out of the
	# tree at once, and a node outside the tree has no viewport to mark.
	get_viewport().set_input_as_handled()
	_continue()


func _continue() -> void:
	if continued or not can_continue:
		return
	continued = true
	SessionState.go_to_scene(next_scene)


# --- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	card = PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 0)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = HEADING.to_upper()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_HINT))
	column.add_child(heading)

	for paragraph in PARAGRAPHS:
		var body := Label.new()
		body.text = str(paragraph)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(600, 0)
		body.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_SPEECH))
		column.add_child(body)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	column.add_child(spacer)

	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(220, 44)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_continue)
	column.add_child(continue_button)

	var prompt := Label.new()
	prompt.text = PROMPT
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	column.add_child(prompt)


## Everything on the screen as one string, for the test to search.
func rendered_text() -> String:
	var text := ""
	for label in find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text
