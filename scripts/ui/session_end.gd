extends Control


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = load("res://assets/art/backgrounds/alesia-kazantceva-VWcPlbHglYc-unsplash.jpg")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.62)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Session Summary"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)

	var summary := RichTextLabel.new()
	summary.bbcode_enabled = false
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.fit_content = true
	summary.custom_minimum_size = Vector2(560, 180)
	var resolution_text: String = SessionState.last_result.get("summary", "No resolution recorded.")
	var confidence_text: String = str(SessionState.last_result.get("confidence", 0))
	var time_left_text: String = str(SessionState.last_result.get("time_left", 0))
	var linked_text: String = str(SessionState.last_result.get("linked_clues", 0))
	summary.text = "Cases reviewed: %d\nVictims protected: %d\nFailed interventions: %d\nAlerts raised: %d\n\nLatest result: %s" % [
		SessionState.cases_reviewed,
		SessionState.victims_protected,
		SessionState.failed_interventions,
		SessionState.alert_level,
		resolution_text
	]
	summary.text += "\nConfidence: %s%%" % confidence_text
	summary.text += "\nTime left: %ss" % time_left_text
	summary.text += "\nLinked clues: %s" % linked_text
	column.add_child(summary)

	var back_button := Button.new()
	back_button.text = "Back to Menu"
	back_button.custom_minimum_size = Vector2(200, 42)
	back_button.pressed.connect(_back_to_menu)
	column.add_child(back_button)


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
