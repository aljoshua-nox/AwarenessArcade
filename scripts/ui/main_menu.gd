extends Control

const TextStyle := preload("res://scripts/systems/text_style.gd")

const CREDITS_SCENE := "res://scenes/main_menu/credits.tscn"

var menu_column: VBoxContainer
var case_files_button: Button
# The Case Files: the five endings over the record on disk, reached ones by
# title, the rest as a steer. Takes the menu's place in the panel while open.
var case_files: VBoxContainer
var record_count: Label
var ending_rows: VBoxContainer
var files_buttons: HBoxContainer
var clear_confirm: VBoxContainer


func _ready() -> void:
	AudioManager.stop_ambience()
	AudioManager.play_music("menu", -12.0)
	_build_ui()
	SessionState.reset_session()


func _unhandled_input(event: InputEvent) -> void:
	# Esc steps back out of the Case Files one layer at a time, the way it
	# steps out of the pause menu's confirm.
	if case_files.visible and event.is_action_pressed("ui_cancel"):
		if clear_confirm.visible:
			_show_files_buttons()
		else:
			_show_menu()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/art/backgrounds/copernico-p_kICQCOM4s-unsplash.jpg")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 440)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	menu_column = VBoxContainer.new()
	menu_column.alignment = BoxContainer.ALIGNMENT_CENTER
	# Six buttons under the logo: at 14 the panel touched both edges of a
	# 720-high window.
	menu_column.add_theme_constant_override("separation", 10)
	margin.add_child(menu_column)

	var logo := TextureRect.new()
	logo.texture = load("res://logo.png")
	logo.custom_minimum_size = Vector2(160, 160)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_column.add_child(logo)

	var title := Label.new()
	title.text = "Dial and Deceive"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	menu_column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Play the scam, then investigate it. A prototype about fraud, harm, and accountability."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size = Vector2(560, 0)
	menu_column.add_child(subtitle)

	var start_button := Button.new()
	start_button.text = "Start"
	start_button.custom_minimum_size = Vector2(220, 44)
	start_button.pressed.connect(_start_game)
	menu_column.add_child(start_button)

	var skip_button := Button.new()
	skip_button.text = "Skip to Investigation"
	skip_button.custom_minimum_size = Vector2(220, 44)
	skip_button.tooltip_text = "Start at the detective half with no prologue history. Every witness opens neutral."
	skip_button.pressed.connect(_start_investigation_only)
	menu_column.add_child(skip_button)

	case_files_button = Button.new()
	case_files_button.custom_minimum_size = Vector2(220, 44)
	case_files_button.tooltip_text = "The endings this copy of the game has reached, and a word on the ones it has not."
	case_files_button.pressed.connect(_open_case_files)
	menu_column.add_child(case_files_button)

	var credits_button := Button.new()
	credits_button.text = "Credits"
	credits_button.custom_minimum_size = Vector2(220, 44)
	credits_button.pressed.connect(SessionState.go_to_scene.bind(CREDITS_SCENE))
	menu_column.add_child(credits_button)

	# The one volume control, mirrored on the pause menu: On -> Quiet -> Off.
	var sound_button := Button.new()
	sound_button.text = AudioManager.volume_label()
	sound_button.custom_minimum_size = Vector2(220, 44)
	sound_button.pressed.connect(func() -> void:
		AudioManager.cycle_volume()
		sound_button.text = AudioManager.volume_label())
	menu_column.add_child(sound_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(220, 44)
	quit_button.pressed.connect(Callable(get_tree(), "quit"))
	menu_column.add_child(quit_button)

	_build_case_files(margin)
	_refresh_case_files()


func _build_case_files(parent: Control) -> void:
	case_files = VBoxContainer.new()
	case_files.alignment = BoxContainer.ALIGNMENT_CENTER
	case_files.add_theme_constant_override("separation", 12)
	case_files.visible = false
	parent.add_child(case_files)

	var files_title := Label.new()
	files_title.text = "Case Files"
	files_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	files_title.add_theme_font_size_override("font_size", 24)
	case_files.add_child(files_title)

	record_count = Label.new()
	record_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	case_files.add_child(record_count)

	ending_rows = VBoxContainer.new()
	ending_rows.add_theme_constant_override("separation", 10)
	case_files.add_child(ending_rows)

	files_buttons = HBoxContainer.new()
	files_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	files_buttons.add_theme_constant_override("separation", 12)
	case_files.add_child(files_buttons)

	var clear_button := Button.new()
	clear_button.text = "Clear Record"
	clear_button.custom_minimum_size = Vector2(200, 44)
	clear_button.pressed.connect(_ask_to_clear)
	files_buttons.add_child(clear_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(160, 44)
	back_button.pressed.connect(_show_menu)
	files_buttons.add_child(back_button)

	# Clearing forgets every ending reached. The one question this panel asks.
	clear_confirm = VBoxContainer.new()
	clear_confirm.add_theme_constant_override("separation", 10)
	clear_confirm.visible = false
	case_files.add_child(clear_confirm)

	var warning := Label.new()
	warning.text = "This forgets every ending on record. It cannot be undone."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_WRONG))
	clear_confirm.add_child(warning)

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_row.add_theme_constant_override("separation", 12)
	clear_confirm.add_child(confirm_row)

	var clear := Button.new()
	clear.text = "Clear the record"
	clear.custom_minimum_size = Vector2(200, 44)
	clear.pressed.connect(_clear_record)
	confirm_row.add_child(clear)

	var keep := Button.new()
	keep.text = "Keep it"
	keep.custom_minimum_size = Vector2(160, 44)
	keep.pressed.connect(_show_files_buttons)
	confirm_row.add_child(keep)


# Read off the file each time it is shown: the ending screen writes it, and the
# menu is the next thing the player sees.
func _refresh_case_files() -> void:
	var reached := SessionState.endings_reached()
	var total := SessionState.ENDINGS.size()
	case_files_button.text = "Case Files  (%d of %d)" % [reached.size(), total]
	record_count.text = "Endings on record: %d of %d" % [reached.size(), total]
	for child in ending_rows.get_children():
		ending_rows.remove_child(child)
		child.queue_free()
	for index in range(total):
		var entry: Dictionary = SessionState.ENDINGS[index]
		var row := RichTextLabel.new()
		row.bbcode_enabled = true
		row.fit_content = true
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := str(entry.get("id", ""))
		if reached.has(id):
			row.text = "[b]%d.  %s[/b]   [color=#%s]reached[/color]" % [
				index + 1, str(entry.get("title", "")), TextStyle.COLOR_CORRECT]
		else:
			# A steer, never the route: the same rule the objectives follow.
			row.text = "[b]%d.  ???[/b]\n    [color=#%s]%s[/color]" % [
				index + 1, TextStyle.COLOR_NARRATION, str(entry.get("steer", ""))]
		ending_rows.add_child(row)


func _open_case_files() -> void:
	_refresh_case_files()
	_show_files_buttons()
	menu_column.visible = false
	case_files.visible = true


func _show_menu() -> void:
	case_files.visible = false
	menu_column.visible = true


func _ask_to_clear() -> void:
	files_buttons.visible = false
	clear_confirm.visible = true


func _show_files_buttons() -> void:
	clear_confirm.visible = false
	files_buttons.visible = true


func _clear_record() -> void:
	SessionState.clear_ending_record()
	_refresh_case_files()
	_show_files_buttons()


func _start_game() -> void:
	SessionState.start_prologue()


func _start_investigation_only() -> void:
	SessionState.start_investigation_direct()
