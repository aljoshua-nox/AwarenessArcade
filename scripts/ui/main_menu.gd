extends Control

const TextStyle := preload("res://scripts/systems/text_style.gd")
const ScamCheckData := preload("res://scripts/scam_check/scam_check_data.gd")

const CREDITS_SCENE := "res://scenes/main_menu/credits.tscn"
const SCAM_CHECK_SCENE := "res://scenes/scam_check/scam_check.tscn"

# The menu's own look, an RPG title screen: a pixel-font title, a framed
# window, and one pointer beside the selected button. Kenney's fonts and RPG UI
# pack (CC0). Both fonts import with antialiasing off and are drawn at
# multiples of 8, their pixel grid; both are capitals only.
const TITLE_FONT := preload("res://assets/art/ui/kenney_kenney-fonts/Fonts/Kenney Pixel Square.ttf")
const BUTTON_FONT := preload("res://assets/art/ui/kenney_kenney-fonts/Fonts/Kenney Mini Square.ttf")
const POINTER_TEXTURE := preload("res://assets/art/ui/kenney_ui-pack-rpg-expansion/PNG/arrowSilver_right.png")
const GOLD := Color(0.96, 0.78, 0.38)
const GOLD_DIM := Color(0.66, 0.5, 0.25)
const CREAM := Color(0.93, 0.9, 0.82)
const WINDOW_FILL := Color(0.06, 0.07, 0.1, 0.94)
const BUTTON_SIZE := Vector2(360, 40)

var menu_column: VBoxContainer
var start_button: Button
var pointer: TextureRect
var case_files_button: Button
# The Case Files: the five endings over the record on disk, reached ones by
# title, the rest as a steer. Takes the menu's place in the panel while open.
var case_files: VBoxContainer
var record_count: Label
var ending_rows: VBoxContainer
var files_buttons: HBoxContainer
var clear_confirm: VBoxContainer
var back_button: Button
var keep_button: Button


func _ready() -> void:
	AudioManager.stop_ambience()
	AudioManager.play_music("menu", -12.0)
	_build_ui()
	SessionState.reset_session()
	# Back from the Spot the Scam page, which lives in Case Files.
	if SessionState.menu_opens_case_files:
		SessionState.menu_opens_case_files = false
		_open_case_files()
	else:
		start_button.grab_focus.call_deferred()


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
	panel.add_theme_stylebox_override("panel", _window_style())
	# Every button in the window, the Case Files' included, wears the menu's
	# own button style rather than the game-wide one.
	panel.theme = _button_theme()
	center.add_child(panel)

	# The window's second, inner line: the double frame of an RPG text box.
	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		inset.add_theme_constant_override(side, 3)
	panel.add_child(inset)
	var inner_line := Panel.new()
	inner_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line_style := StyleBoxFlat.new()
	line_style.draw_center = false
	line_style.set_border_width_all(1)
	line_style.border_color = Color(GOLD, 0.35)
	line_style.set_corner_radius_all(3)
	inner_line.add_theme_stylebox_override("panel", line_style)
	inset.add_child(inner_line)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	menu_column = VBoxContainer.new()
	menu_column.alignment = BoxContainer.ALIGNMENT_CENTER
	# The header is its own tight block over the buttons: six buttons under the
	# logo have to fit a 720-high window.
	menu_column.add_theme_constant_override("separation", 8)
	margin.add_child(menu_column)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	menu_column.add_child(header)

	var logo := TextureRect.new()
	logo.texture = load("res://logo.png")
	logo.custom_minimum_size = Vector2(160, 160)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(logo)

	var title := Label.new()
	title.text = "Dial and Deceive"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_title(title, 48)
	header.add_child(title)

	header.add_child(_divider())

	var subtitle := Label.new()
	subtitle.text = "Play the scam, then investigate it. A prototype about fraud, harm, and accountability."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size = Vector2(560, 0)
	subtitle.add_theme_color_override("font_color", CREAM.darkened(0.12))
	header.add_child(subtitle)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	menu_column.add_child(gap)

	pointer = TextureRect.new()
	pointer.texture = POINTER_TEXTURE
	pointer.modulate = GOLD
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Left of whichever button holds it, centered on it; nudges back and forth.
	var tip := POINTER_TEXTURE.get_size()
	pointer.anchor_top = 0.5
	pointer.anchor_bottom = 0.5
	pointer.offset_top = -tip.y / 2.0
	pointer.offset_bottom = tip.y / 2.0
	pointer.offset_left = -tip.x - 16
	pointer.offset_right = -16
	var nudge := create_tween().set_loops()
	nudge.tween_property(pointer, "position:x", pointer.offset_left + 5, 0.4).set_trans(Tween.TRANS_SINE)
	nudge.tween_property(pointer, "position:x", pointer.offset_left, 0.4).set_trans(Tween.TRANS_SINE)

	start_button = _add_menu_button("Start", _start_game)
	_point_at(start_button)

	var skip_button := _add_menu_button("Skip to Investigation", _start_investigation_only)
	skip_button.tooltip_text = "Start at the detective half with no prologue history. Every witness opens neutral."

	case_files_button = _add_menu_button("", _open_case_files)
	case_files_button.tooltip_text = "The endings this copy of the game has reached, a word on the ones it has not, and your Spot the Scam results."

	_add_menu_button("Credits", SessionState.go_to_scene.bind(CREDITS_SCENE))

	# The one volume control, mirrored on the pause menu: On -> Quiet -> Off.
	var sound_button := _add_menu_button(AudioManager.volume_label(), Callable())
	sound_button.pressed.connect(func() -> void:
		AudioManager.cycle_volume()
		sound_button.text = AudioManager.volume_label())

	_add_menu_button("Quit", Callable(get_tree(), "quit"))

	_build_case_files(margin)
	_refresh_case_files()

	# Hovering selects, so the mouse and the arrow keys move one cursor rather
	# than lighting two buttons at once.
	for button in panel.find_children("*", "Button", true, false):
		(button as Button).mouse_entered.connect((button as Button).grab_focus)


func _add_menu_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if action.is_valid():
		button.pressed.connect(action)
	button.focus_entered.connect(_point_at.bind(button))
	menu_column.add_child(button)
	return button


# The pointer is one node, handed to the selected button.
func _point_at(button: Button) -> void:
	var holder := pointer.get_parent()
	if holder == button:
		return
	if holder:
		holder.remove_child(pointer)
	button.add_child(pointer)


func _style_title(label: Label, size: int) -> void:
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", size / 6)
	# A drop in the logo's red, under the outline.
	label.add_theme_color_override("font_shadow_color", Color(0.62, 0.09, 0.08))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", size / 8)
	label.add_theme_constant_override("shadow_outline_size", size / 6)


# A gold rule with a diamond in the middle, under the title.
func _divider() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for index in range(3):
		if index == 1:
			var gem_box := Control.new()
			gem_box.custom_minimum_size = Vector2(12, 12)
			var gem := ColorRect.new()
			gem.color = GOLD
			gem.size = Vector2(8, 8)
			gem.position = Vector2(2, 2)
			gem.pivot_offset = Vector2(4, 4)
			gem.rotation_degrees = 45
			gem_box.add_child(gem)
			row.add_child(gem_box)
			continue
		var rule := ColorRect.new()
		rule.color = Color(GOLD_DIM, 0.9)
		rule.custom_minimum_size = Vector2(150, 2)
		rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rule)
	return row


func _window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = WINDOW_FILL
	style.set_border_width_all(3)
	style.border_color = GOLD_DIM
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 18
	style.set_content_margin_all(6)
	return style


func _button_theme() -> Theme:
	var theme := Theme.new()
	theme.set_font("font", "Button", BUTTON_FONT)
	theme.set_font_size("font_size", "Button", 24)
	theme.set_constant("outline_size", "Button", 0)
	theme.set_color("font_color", "Button", CREAM)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", GOLD)
	theme.set_stylebox("normal", "Button", _plate(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1)))
	theme.set_stylebox("hover", "Button", _plate(Color(GOLD, 0.12), Color(GOLD, 0.7)))
	theme.set_stylebox("pressed", "Button", _plate(Color(GOLD, 0.24), GOLD))
	# Focus draws over the state box, so it is the gold edge alone: a button
	# selected from the keyboard lights the same way as a hovered one.
	var focus := _plate(Color(0, 0, 0, 0), Color(GOLD, 0.7))
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)
	return theme


func _plate(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(2)
	style.border_color = edge
	style.set_corner_radius_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _build_case_files(parent: Control) -> void:
	case_files = VBoxContainer.new()
	case_files.alignment = BoxContainer.ALIGNMENT_CENTER
	case_files.add_theme_constant_override("separation", 12)
	case_files.visible = false
	parent.add_child(case_files)

	var files_title := Label.new()
	files_title.text = "Case Files"
	files_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_title(files_title, 32)
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

	# Spot the Scam's own page: past results, Copy Results for a playtest, and
	# an after check for a player who ran out of time before an ending.
	var scam_check_button := Button.new()
	scam_check_button.text = "Spot the Scam Results"
	scam_check_button.custom_minimum_size = Vector2(230, 44)
	scam_check_button.pressed.connect(_open_scam_check)
	files_buttons.add_child(scam_check_button)

	var clear_button := Button.new()
	clear_button.text = "Clear Record"
	clear_button.custom_minimum_size = Vector2(180, 44)
	clear_button.pressed.connect(_ask_to_clear)
	files_buttons.add_child(clear_button)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(140, 44)
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

	keep_button = Button.new()
	keep_button.text = "Keep it"
	keep_button.custom_minimum_size = Vector2(160, 44)
	keep_button.pressed.connect(_show_files_buttons)
	confirm_row.add_child(keep_button)


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
		# The window's own plate rather than the game-wide grey box.
		var plate := _plate(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1))
		plate.content_margin_top = 8
		plate.content_margin_bottom = 8
		row.add_theme_stylebox_override("normal", plate)
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
	back_button.grab_focus()


func _show_menu() -> void:
	case_files.visible = false
	menu_column.visible = true
	case_files_button.grab_focus()


func _ask_to_clear() -> void:
	files_buttons.visible = false
	clear_confirm.visible = true
	keep_button.grab_focus()


func _show_files_buttons() -> void:
	clear_confirm.visible = false
	files_buttons.visible = true
	if case_files.visible:
		back_button.grab_focus()


func _clear_record() -> void:
	SessionState.clear_ending_record()
	_refresh_case_files()
	_show_files_buttons()


func _open_scam_check() -> void:
	SessionState.scam_check_entry = ""
	SessionState.go_to_scene(SCAM_CHECK_SCENE)


func _start_game() -> void:
	_begin(ScamCheckData.ROUTE_PROLOGUE)


func _start_investigation_only() -> void:
	_begin(ScamCheckData.ROUTE_SKIP)


# Spot the Scam is offered on the way in - except while a check is already
# waiting in this sitting: its second half is at the next ending, and a new
# check would close it. Then the waiting check notes how the game was played.
# Only here, on the player's path - never in SessionState.start_*(), which the
# test runners call directly.
func _begin(route: String) -> void:
	if offers_spot_the_scam():
		SessionState.scam_check_entry = SessionState.SCAM_CHECK_FROM_START_SKIP \
			if route == ScamCheckData.ROUTE_SKIP else SessionState.SCAM_CHECK_FROM_START_PROLOGUE
		SessionState.go_to_scene(SCAM_CHECK_SCENE)
		return
	ScamCheckData.new().note_route(route)
	if route == ScamCheckData.ROUTE_SKIP:
		SessionState.start_investigation_direct()
	else:
		SessionState.start_prologue()


func offers_spot_the_scam() -> bool:
	return not ScamCheckData.new().has_open_check()
