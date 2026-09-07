extends Control


func _ready() -> void:
	_build_ui()
	SessionState.reset_session()


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

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var logo := TextureRect.new()
	logo.texture = load("res://logo.png")
	logo.custom_minimum_size = Vector2(180, 180)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(logo)

	var title := Label.new()
	title.text = "Dial and Deceive"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Play the scam, then investigate it. A prototype about fraud, harm, and accountability."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.custom_minimum_size = Vector2(560, 0)
	column.add_child(subtitle)

	var start_button := Button.new()
	start_button.text = "Start"
	start_button.custom_minimum_size = Vector2(220, 44)
	start_button.pressed.connect(_start_game)
	column.add_child(start_button)

	var skip_button := Button.new()
	skip_button.text = "Skip to Investigation"
	skip_button.custom_minimum_size = Vector2(220, 44)
	skip_button.tooltip_text = "Start at the detective half with no prologue history. Every witness opens neutral."
	skip_button.pressed.connect(_start_investigation_only)
	column.add_child(skip_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(220, 44)
	quit_button.pressed.connect(Callable(get_tree(), "quit"))
	column.add_child(quit_button)


func _start_game() -> void:
	SessionState.start_prologue()


func _start_investigation_only() -> void:
	SessionState.start_investigation_direct()
