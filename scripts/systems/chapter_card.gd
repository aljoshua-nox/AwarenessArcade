extends CanvasLayer

## The title card in front of each half of the game: PART ONE, THE CALLER, then
## PART TWO, THE CASE. Switching sides is the game's whole idea - you work the
## phones, then you trace them - so the player, and a room watching one, is
## told which side they are on before the first screen of it.
##
## It sits on the tree's root, not in a scene, so it can cover a scene change:
## it fades to black over the screen that sent it, swaps the scene underneath,
## holds the title, and fades out over the new scene. The tree is paused while
## it is up, so no clock runs and nobody walks underneath it. Once the title is
## up, any key or click moves it along; before that input is dropped, so a key
## still held from the last screen cannot skip it unread.
##
## SessionState.go_to_scene_with_card() is the way in. Deliberately NOT a
## `class_name` - see text_style.gd.

const MenuStyle := preload("res://scripts/systems/menu_style.gd")
const TextStyle := preload("res://scripts/systems/text_style.gd")

const NODE_NAME := "ChapterCard"
const CARD_LAYER := 100

## Card id -> the three lines it shows. The title is drawn in the menus' pixel
## font, which is capitals only; everything under it is read, so it is not.
const CARDS := {
	"caller": {
		"part": "PART ONE",
		"title": "THE CALLER",
		"line": "You work the phones on a scam call floor. One shift, one list of names.",
		"drop": Color(0.62, 0.09, 0.08),
	},
	"case": {
		"part": "PART TWO",
		"title": "THE CASE",
		"line": "Now you are the detective. Trace the calls back to the people behind them.",
		"drop": Color(0.07, 0.3, 0.42),
	},
}

var card_id: String = "caller"
## Where the card goes once the screen is black. Empty changes nothing, which
## is how a test drives the card without leaving its runner.
var scene_path: String = ""
var fade_to_black: float = 0.35
var text_in: float = 0.5
var hold: float = 2.4
var fade_out: float = 0.6

var can_skip: bool = false
var leaving: bool = false
var black: ColorRect
var part_label: Label
var title_label: Label
var line_label: Label
var sequence: Tween


func _ready() -> void:
	name = NODE_NAME
	layer = CARD_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	sequence = create_tween()
	sequence.tween_property(black, "modulate:a", 1.0, fade_to_black)
	sequence.tween_callback(_swap_scene)
	sequence.tween_property(part_label, "modulate:a", 1.0, text_in * 0.6)
	sequence.tween_callback(_slam_title)
	sequence.tween_property(title_label, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sequence.parallel().tween_property(title_label, "modulate:a", 1.0, 0.1)
	sequence.tween_property(line_label, "modulate:a", 1.0, text_in)
	sequence.tween_callback(func() -> void: can_skip = true)
	sequence.tween_interval(hold)
	sequence.tween_callback(_leave)


# Everything the card blocks, it blocks here: _input runs before the GUI and
# before any scene's _unhandled_input, and the scene underneath is paused.
func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey:
		pressed = event.is_pressed() and not event.is_echo()
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.is_pressed()
	get_viewport().set_input_as_handled()
	if pressed and can_skip:
		_leave()


func _swap_scene() -> void:
	if not scene_path.is_empty():
		SessionState.go_to_scene(scene_path)
	get_tree().paused = true


# The title lands like the stamps on the call floor and in the case file: big,
# then down, with the thud. Its pivot is only known once the column has laid
# it out, which it has by the time the part line has faded in.
func _slam_title() -> void:
	title_label.pivot_offset = title_label.size / 2.0
	title_label.scale = Vector2(1.8, 1.8)
	AudioManager.play_sfx("stamp")


func _leave() -> void:
	if leaving:
		return
	leaving = true
	can_skip = false
	if sequence != null and sequence.is_valid():
		sequence.kill()
	get_tree().paused = false
	var out := create_tween()
	for node in [black, part_label, title_label, line_label]:
		out.parallel().tween_property(node, "modulate:a", 0.0, fade_out)
	out.tween_callback(queue_free)


func _build() -> void:
	var entry: Dictionary = CARDS.get(card_id, CARDS["caller"])

	black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	black.modulate.a = 0.0
	add_child(black)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	part_label = Label.new()
	part_label.text = str(entry["part"])
	part_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	part_label.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	part_label.add_theme_font_size_override("font_size", 20)
	part_label.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	part_label.modulate.a = 0.0
	column.add_child(part_label)

	title_label = Label.new()
	title_label.text = str(entry["title"])
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MenuStyle.style_title(title_label, 72, MenuStyle.CREAM, entry["drop"])
	title_label.modulate.a = 0.0
	column.add_child(title_label)

	line_label = Label.new()
	line_label.text = str(entry["line"])
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.add_theme_font_size_override("font_size", 20)
	line_label.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_SPEECH))
	line_label.modulate.a = 0.0
	column.add_child(line_label)
