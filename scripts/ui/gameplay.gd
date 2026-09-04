extends Control

const SAMPLE_CASE_PATH: String = "res://resources/cases/case_001.json"
const TIMER_PENALTY_LOW: float = 14.0
const TIMER_PENALTY_MEDIUM: float = 7.0
const CONFIDENCE_BONUS_HIGH: int = 16
const CONFIDENCE_BONUS_MEDIUM: int = 7
const CONFIDENCE_PENALTY_LOW: int = 10

var case_data: Dictionary = {}
var case_title: Label
var case_body: RichTextLabel
var context_detail: RichTextLabel
var question_detail: RichTextLabel
var evidence_detail: RichTextLabel
var evidence_feedback: Label
var status_label: Label
var case_icon: TextureRect
var alert_value_label: Label
var confidence_value_label: Label
var timer_value_label: Label
var evidence_scroll: ScrollContainer
var evidence_column: VBoxContainer
var evidence_buttons: Array[Button] = []
var selected_evidence_index: int = -1
var solved_evidence: Array[int] = []
var investigation_remaining: float = 90.0
var case_confidence: int = 35
var clue_links: int = 0
var _processed_case: bool = false


func _ready() -> void:
	_build_ui()
	_load_case(SAMPLE_CASE_PATH)
	AudioManager.play_stream("res://assets/audio/ambience/407292__nightwatcher98__office-ambience.mp3", -10.0)


func _process(delta: float) -> void:
	if _processed_case:
		return

	if investigation_remaining > 0.0:
		investigation_remaining = maxf(0.0, investigation_remaining - delta)
		_update_status()


func _build_ui() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = load("res://assets/art/backgrounds/jose-losada-DyFjxmHt3Es-unsplash.jpg")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.58)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var root_margin: MarginContainer = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	root_margin.add_child(root)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	case_icon = TextureRect.new()
	case_icon.texture = load("res://assets/art/icons/user-shield-solid-full.svg")
	case_icon.modulate = Color(0.98, 0.99, 1, 1)
	case_icon.custom_minimum_size = Vector2(40, 40)
	case_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	case_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(case_icon)

	var header_column: VBoxContainer = VBoxContainer.new()
	header_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_column)

	case_title = Label.new()
	case_title.text = "Case"
	case_title.add_theme_font_size_override("font_size", 26)
	header_column.add_child(case_title)

	case_body = RichTextLabel.new()
	case_body.bbcode_enabled = false
	case_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	case_body.fit_content = true
	case_body.scroll_active = false
	case_body.custom_minimum_size = Vector2(0, 48)
	header_column.add_child(case_body)

	var status_box: VBoxContainer = VBoxContainer.new()
	status_box.custom_minimum_size = Vector2(200, 0)
	header.add_child(status_box)

	alert_value_label = Label.new()
	alert_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_box.add_child(alert_value_label)

	confidence_value_label = Label.new()
	confidence_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_box.add_child(confidence_value_label)

	timer_value_label = Label.new()
	timer_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_box.add_child(timer_value_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_box.add_child(status_label)

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left_panel)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_scroll)

	var left_margin: MarginContainer = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 14)
	left_margin.add_theme_constant_override("margin_top", 14)
	left_margin.add_theme_constant_override("margin_right", 14)
	left_margin.add_theme_constant_override("margin_bottom", 14)
	left_scroll.add_child(left_margin)

	var left_column: VBoxContainer = VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 10)
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_child(left_column)

	var context_panel: PanelContainer = PanelContainer.new()
	context_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(context_panel)

	var context_margin: MarginContainer = MarginContainer.new()
	context_margin.add_theme_constant_override("margin_left", 12)
	context_margin.add_theme_constant_override("margin_top", 10)
	context_margin.add_theme_constant_override("margin_right", 12)
	context_margin.add_theme_constant_override("margin_bottom", 10)
	context_panel.add_child(context_margin)

	var context_column: VBoxContainer = VBoxContainer.new()
	context_column.add_theme_constant_override("separation", 8)
	context_margin.add_child(context_column)

	var context_label: Label = Label.new()
	context_label.text = "Investigation Context"
	context_label.add_theme_font_size_override("font_size", 22)
	context_column.add_child(context_label)

	context_detail = RichTextLabel.new()
	context_detail.bbcode_enabled = false
	context_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_detail.fit_content = true
	context_detail.scroll_active = false
	context_detail.custom_minimum_size = Vector2(0, 0)
	context_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	context_column.add_child(context_detail)

	question_detail = RichTextLabel.new()
	question_detail.bbcode_enabled = false
	question_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_detail.fit_content = true
	question_detail.scroll_active = false
	question_detail.custom_minimum_size = Vector2(0, 0)
	context_column.add_child(question_detail)

	var center_panel: PanelContainer = PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center_panel)

	var center_margin: MarginContainer = MarginContainer.new()
	center_margin.add_theme_constant_override("margin_left", 14)
	center_margin.add_theme_constant_override("margin_top", 14)
	center_margin.add_theme_constant_override("margin_right", 14)
	center_margin.add_theme_constant_override("margin_bottom", 14)
	center_panel.add_child(center_margin)

	var center_column: VBoxContainer = VBoxContainer.new()
	center_column.add_theme_constant_override("separation", 10)
	center_margin.add_child(center_column)

	var board_label: Label = Label.new()
	board_label.text = "Evidence Board"
	center_column.add_child(board_label)

	evidence_scroll = ScrollContainer.new()
	evidence_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_child(evidence_scroll)

	evidence_column = VBoxContainer.new()
	evidence_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evidence_scroll.add_child(evidence_column)

	evidence_detail = RichTextLabel.new()
	evidence_detail.bbcode_enabled = false
	evidence_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_detail.fit_content = false
	evidence_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evidence_detail.custom_minimum_size = Vector2(0, 92)
	center_column.add_child(evidence_detail)

	evidence_feedback = Label.new()
	evidence_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_column.add_child(evidence_feedback)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	center_column.add_child(actions)

	var link_button: Button = Button.new()
	link_button.text = "Link Selected Clue"
	link_button.pressed.connect(_link_selected_clue)
	actions.add_child(link_button)

	var resolve_button: Button = Button.new()
	resolve_button.text = "Resolve Case"
	resolve_button.pressed.connect(_resolve_case)
	actions.add_child(resolve_button)

	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(250, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_panel)

	var right_margin: MarginContainer = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 14)
	right_margin.add_theme_constant_override("margin_top", 14)
	right_margin.add_theme_constant_override("margin_right", 14)
	right_margin.add_theme_constant_override("margin_bottom", 14)
	right_panel.add_child(right_margin)

	var right_column: VBoxContainer = VBoxContainer.new()
	right_column.add_theme_constant_override("separation", 12)
	right_margin.add_child(right_column)

	var instructions: Label = Label.new()
	instructions.text = "Work from the context, inspect a clue, then submit the one that best answers the question."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_column.add_child(instructions)

	var alert_icon_row: HBoxContainer = HBoxContainer.new()
	alert_icon_row.add_theme_constant_override("separation", 8)
	right_column.add_child(alert_icon_row)

	var alert_icon: TextureRect = TextureRect.new()
	alert_icon.texture = load("res://assets/art/icons/triangle-exclamation-solid-full.svg")
	alert_icon.modulate = Color(0.98, 0.99, 1, 1)
	alert_icon.custom_minimum_size = Vector2(24, 24)
	alert_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	alert_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	alert_icon_row.add_child(alert_icon)

	var alert_label: Label = Label.new()
	alert_label.text = "Response status"
	alert_icon_row.add_child(alert_label)

	var back_button: Button = Button.new()
	back_button.text = "Return to Menu"
	back_button.pressed.connect(_return_to_menu)
	right_column.add_child(back_button)


func _load_case(path: String) -> void:
	case_data = CaseLoader.load_case(path)
	if case_data.is_empty():
		case_title.text = "No case found"
		case_body.text = "Missing case data."
		context_detail.text = "No investigation context loaded."
		question_detail.text = ""
		return

	SessionState.start_case(case_data)
	case_title.text = case_data.get("title", "Untitled Case")

	var victim: Dictionary = case_data.get("victim", {})
	var age_value: int = int(victim.get("age", 0))
	var traits_text: String = _format_traits(victim.get("traits", []))
	case_body.text = "Victim: %s\nAge: %d\nOccupation: %s\nTraits: %s\n\nIssue: %s\nUrgency: %d" % [
		victim.get("name", "Unknown"),
		age_value,
		victim.get("occupation", "Unknown"),
		traits_text,
		case_data.get("summary", ""),
		int(case_data.get("urgency", 0))
	]

	var context: Dictionary = case_data.get("context", {})
	context_detail.text = "Lead: %s\nObjective: %s\nHint: %s\nWarning: %s" % [
		context.get("lead", "Unknown"),
		context.get("objective", "Investigate the available clues."),
		context.get("hint", "Look for the strongest fraud indicators."),
		context.get("warning", "Avoid wasting time on irrelevant details.")
	]
	question_detail.text = "Investigation question:\n%s" % context.get(
		"question",
		"Which clue best supports the current fraud lead?"
	)

	_build_evidence_board()
	_update_status()


func _build_evidence_board() -> void:
	for child in evidence_column.get_children():
		child.queue_free()

	evidence_buttons.clear()
	selected_evidence_index = -1
	solved_evidence.clear()
	evidence_detail.text = "Select a clue card to inspect it."
	evidence_feedback.text = "The board becomes risky when you commit to the wrong clue."
	evidence_feedback.modulate = Color(0.9, 0.9, 0.9)

	var evidence_array: Array = case_data.get("evidence", [])
	var index: int = 0
	for evidence_variant in evidence_array:
		var evidence: Dictionary = evidence_variant
		var button: Button = Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s" % evidence.get("kind", "Evidence")
		button.tooltip_text = "Click to inspect this clue"
		button.pressed.connect(Callable(self, "_on_evidence_button_pressed").bind(index))
		button.set_meta("evidence", evidence)
		_apply_clue_button_style(button, false)
		evidence_column.add_child(button)
		evidence_buttons.append(button)
		index += 1

	if not evidence_buttons.is_empty():
		_select_evidence(0)


func _on_evidence_button_pressed(index: int) -> void:
	_select_evidence(index)


func _select_evidence(index: int) -> void:
	selected_evidence_index = index

	var button_index: int = 0
	for button in evidence_buttons:
		var is_selected: bool = button_index == index and not button.disabled
		button.button_pressed = is_selected
		_apply_clue_button_style(button, is_selected, button.disabled)
		button_index += 1

	var button: Button = evidence_buttons[index]
	var evidence_variant: Variant = button.get_meta("evidence")
	var evidence: Dictionary = evidence_variant
	var relevance: String = evidence.get("relevance", "medium")
	var hint: String = evidence.get("hint", "No clue hint available.")
	var assessment: String = evidence.get("assessment", "No assessment available.")
	var context: Dictionary = case_data.get("context", {})
	var expected: String = context.get("lead", "Unknown")

	if relevance == "high":
		evidence_feedback.text = "This clue looks promising. It may answer the question if it matches the lead."
		evidence_feedback.modulate = Color(0.68, 0.93, 0.69)
	elif relevance == "medium":
		evidence_feedback.text = "This clue might help, but it may need another clue or context to matter."
		evidence_feedback.modulate = Color(0.96, 0.85, 0.48)
	else:
		evidence_feedback.text = "This clue feels weak and may waste your limited investigation time."
		evidence_feedback.modulate = Color(0.96, 0.53, 0.53)

	evidence_detail.text = "Clue: %s\n\n%s\n\nHint:\n%s\n\nAssessment:\n%s\n\nLead check:\n%s" % [
		evidence.get("kind", "Evidence"),
		evidence.get("text", ""),
		hint,
		assessment,
		expected
	]


func _link_selected_clue() -> void:
	if selected_evidence_index < 0 or selected_evidence_index >= evidence_buttons.size():
		evidence_feedback.text = "Select a clue before linking it to the case."
		evidence_feedback.modulate = Color(0.96, 0.85, 0.48)
		return

	var button: Button = evidence_buttons[selected_evidence_index]
	if button.disabled:
		evidence_feedback.text = "This clue has already been used. Pick a different one."
		evidence_feedback.modulate = Color(0.96, 0.85, 0.48)
		return

	var evidence_variant: Variant = button.get_meta("evidence")
	var evidence: Dictionary = evidence_variant
	var relevance: String = evidence.get("relevance", "medium")
	var clue_label: String = evidence.get("kind", "Evidence")
	var evidence_id: int = selected_evidence_index

	solved_evidence.append(evidence_id)
	button.disabled = true
	button.button_pressed = false
	button.tooltip_text = "Already linked"
	_apply_clue_button_style(button, false, true)

	var context: Dictionary = case_data.get("context", {})
	var question_text: String = context.get("question", "")
	var lead_text: String = context.get("lead", "")
	var is_correct: bool = _evidence_matches_lead(evidence, lead_text, question_text)

	clue_links += 1

	if is_correct and relevance == "high":
		case_confidence = clamp(case_confidence + CONFIDENCE_BONUS_HIGH, 0, 100)
		investigation_remaining = maxf(0.0, investigation_remaining - 2.0)
		evidence_feedback.text = "%s strengthened the case and narrowed the fraud pattern." % clue_label
		evidence_feedback.modulate = Color(0.68, 0.93, 0.69)
	elif is_correct:
		case_confidence = clamp(case_confidence + CONFIDENCE_BONUS_MEDIUM, 0, 100)
		investigation_remaining = maxf(0.0, investigation_remaining - TIMER_PENALTY_MEDIUM)
		evidence_feedback.text = "%s helped a little, but the lead is still incomplete." % clue_label
		evidence_feedback.modulate = Color(0.96, 0.85, 0.48)
	else:
		case_confidence = clamp(case_confidence - CONFIDENCE_PENALTY_LOW, 0, 100)
		investigation_remaining = maxf(0.0, investigation_remaining - TIMER_PENALTY_LOW)
		SessionState.alert_level = clamp(SessionState.alert_level + 1, 0, 10)
		evidence_feedback.text = "%s did not help the investigation and cost valuable time." % clue_label
		evidence_feedback.modulate = Color(0.96, 0.53, 0.53)

	SessionState.evidence_linked = clue_links
	_update_status()
	_refresh_selection_styles()


func _resolve_case() -> void:
	_processed_case = true
	var correct_links: int = _count_correct_links()
	var protected: bool = case_confidence >= 50 and investigation_remaining > 0.0 and correct_links > 0
	var resolved: Dictionary = {
		"protected": protected,
		"alert_delta": 1 if protected else 2,
		"confidence": case_confidence,
		"time_left": int(investigation_remaining),
		"linked_clues": clue_links,
		"summary": "The case was linked early enough to warn the victim." if protected else "The case was resolved too late or with weak evidence, allowing harm to continue."
	}
	SessionState.resolve_case(resolved)
	get_tree().change_scene_to_file("res://scenes/summary/session_end.tscn")


func _refresh_selection_styles() -> void:
	var button_index: int = 0
	for button in evidence_buttons:
		var is_selected: bool = button_index == selected_evidence_index and not button.disabled
		_apply_clue_button_style(button, is_selected, button.disabled)
		button_index += 1


func _format_traits(traits_value: Variant) -> String:
	if traits_value is Array:
		var traits_array: Array = traits_value
		var parts: PackedStringArray = PackedStringArray()
		var i: int = 0
		while i < traits_array.size():
			parts.append(str(traits_array[i]))
			i += 1
		return ", ".join(parts)
	return str(traits_value)


func _apply_clue_button_style(button: Button, selected: bool, used: bool = false) -> void:
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	var pressed_style: StyleBoxFlat = StyleBoxFlat.new()

	if used:
		normal_style.bg_color = Color(0.12, 0.13, 0.16, 0.96)
		hover_style.bg_color = Color(0.12, 0.13, 0.16, 0.96)
		pressed_style.bg_color = Color(0.12, 0.13, 0.16, 0.96)
		button.add_theme_color_override("font_color", Color(0.56, 0.58, 0.62))
		button.add_theme_color_override("font_hover_color", Color(0.56, 0.58, 0.62))
		button.add_theme_color_override("font_pressed_color", Color(0.56, 0.58, 0.62))
	else:
		if selected:
			normal_style.bg_color = Color(0.91, 0.80, 0.27, 1.0)
			hover_style.bg_color = Color(0.96, 0.87, 0.38, 1.0)
			pressed_style.bg_color = Color(0.82, 0.69, 0.18, 1.0)
			button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
			button.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05))
			button.add_theme_color_override("font_pressed_color", Color(0.03, 0.03, 0.03))
		else:
			normal_style.bg_color = Color(0.18, 0.20, 0.24, 0.96)
			hover_style.bg_color = Color(0.24, 0.27, 0.32, 1.0)
			pressed_style.bg_color = Color(0.29, 0.32, 0.38, 1.0)
			button.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
			button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
			button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))

	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.42, 0.44, 0.50, 1.0)
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8

	hover_style.border_width_left = 1
	hover_style.border_width_top = 1
	hover_style.border_width_right = 1
	hover_style.border_width_bottom = 1
	hover_style.border_color = Color(0.60, 0.62, 0.68, 1.0)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	hover_style.content_margin_left = 12
	hover_style.content_margin_right = 12
	hover_style.content_margin_top = 8
	hover_style.content_margin_bottom = 8

	pressed_style.border_width_left = 1
	pressed_style.border_width_top = 1
	pressed_style.border_width_right = 1
	pressed_style.border_width_bottom = 1
	pressed_style.border_color = Color(0.60, 0.52, 0.12, 1.0)
	pressed_style.corner_radius_top_left = 4
	pressed_style.corner_radius_top_right = 4
	pressed_style.corner_radius_bottom_left = 4
	pressed_style.corner_radius_bottom_right = 4
	pressed_style.content_margin_left = 12
	pressed_style.content_margin_right = 12
	pressed_style.content_margin_top = 8
	pressed_style.content_margin_bottom = 8

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)


func _evidence_matches_lead(evidence: Dictionary, lead_text: String, question_text: String) -> bool:
	var kind: String = String(evidence.get("kind", "")).to_lower()
	var text: String = String(evidence.get("text", "")).to_lower()
	var lead: String = lead_text.to_lower()
	var question: String = question_text.to_lower()

	if lead.contains("bank") or question.contains("bank"):
		return kind == "call transcript" or kind == "message" or kind == "alert"

	if lead.contains("tech") or question.contains("tech"):
		return kind == "message" or kind == "alert"

	if lead.contains("lottery") or question.contains("lottery"):
		return kind == "message" or kind == "report"

	return text.contains("bank") or text.contains("transfer") or text.contains("urgent") or text.contains("number")


func _count_correct_links() -> int:
	var count: int = 0
	var context: Dictionary = case_data.get("context", {})
	var lead_text: String = String(context.get("lead", ""))
	var question_text: String = String(context.get("question", ""))
	for index in solved_evidence:
		if index >= 0 and index < evidence_buttons.size():
			var button: Button = evidence_buttons[index]
			var evidence_variant: Variant = button.get_meta("evidence")
			var evidence: Dictionary = evidence_variant
			if _evidence_matches_lead(evidence, lead_text, question_text):
				count += 1
	return count


func _update_status() -> void:
	status_label.text = "Linked clues: %d" % clue_links
	alert_value_label.text = "Alert: %d" % SessionState.alert_level
	confidence_value_label.text = "Confidence: %d%%" % case_confidence
	timer_value_label.text = "Time left: %ds" % int(ceil(investigation_remaining))


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
