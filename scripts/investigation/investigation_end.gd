extends Control

const FINAL_OUTCOMES := ["full_takedown", "partial_justice", "bribed"]

const OUTCOME_LABELS := {
	"success": "Case Lead Confirmed",
	"partial": "Investigation Incomplete",
	"whistleblower": "Whistleblower Secured",
	"failure": "Lead Lost",
	"full_takedown": "Case Closed: Operation Dismantled",
	"partial_justice": "Case Closed: Partial Justice",
	"bribed": "Case Closed: Compromised",
}

const OUTCOME_MESSAGES := {
	"success": "You connected the testimony to hard evidence. This lead is strong enough to push the investigation forward.",
	"partial": "You have a rough picture of what happened, but nothing yet that ties it to the wider operation. The case needs more.",
	"whistleblower": "The suspect agreed to identify the wider operation. The case against the call center is no longer circumstantial.",
	"failure": "This lead has gone cold. The person you spoke with wasn't willing to give you anything more.",
	"full_takedown": "Every testimony you gathered held up. The operation is being dismantled from the top down, not just the callers who made the calls.",
	"partial_justice": "The callers face consequences, but the case wasn't strong enough to reach whoever was really running things.",
	"bribed": "The investigation ends here - not because the evidence ran out, but because it stopped being pursued.",
}

var title_label: Label
var outcome_label: Label
var outcome_note: RichTextLabel
var evidence_value: RichTextLabel
var milestones_value: RichTextLabel
var continue_button: Button


func _ready() -> void:
	_build_ui()
	_refresh_view()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := TextureRect.new()
	background.texture = load("res://assets/art/backgrounds/jose-losada-DyFjxmHt3Es-unsplash.jpg")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		root_margin.add_theme_constant_override(side, 16)
	add_child(root_margin)

	var root_scroll := ScrollContainer.new()
	root_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_margin.add_child(root_scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_scroll.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	column.add_child(title_label)

	outcome_label = Label.new()
	outcome_label.add_theme_font_size_override("font_size", 18)
	column.add_child(outcome_label)

	outcome_note = RichTextLabel.new()
	outcome_note.bbcode_enabled = true
	outcome_note.fit_content = true
	outcome_note.custom_minimum_size = Vector2(0, 60)
	column.add_child(outcome_note)

	var evidence_title := Label.new()
	evidence_title.text = "Evidence on File"
	column.add_child(evidence_title)

	evidence_value = RichTextLabel.new()
	evidence_value.bbcode_enabled = true
	evidence_value.fit_content = true
	evidence_value.custom_minimum_size = Vector2(0, 120)
	column.add_child(evidence_value)

	var milestones_title := Label.new()
	milestones_title.text = "Reflection Milestones"
	column.add_child(milestones_title)

	milestones_value = RichTextLabel.new()
	milestones_value.bbcode_enabled = true
	milestones_value.fit_content = true
	milestones_value.custom_minimum_size = Vector2(0, 100)
	column.add_child(milestones_value)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(button_row)

	continue_button = Button.new()
	continue_button.text = "Return to the Street"
	continue_button.custom_minimum_size = Vector2(200, 44)
	continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(continue_button)

	var main_menu_button := Button.new()
	main_menu_button.text = "Main Menu"
	main_menu_button.custom_minimum_size = Vector2(160, 44)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	button_row.add_child(main_menu_button)


func _refresh_view() -> void:
	title_label.text = "%s - %s" % [SessionState.investigation_case_title, SessionState.investigation_person_name]
	var outcome := SessionState.investigation_outcome
	outcome_label.text = OUTCOME_LABELS.get(outcome, "Interview Concluded")
	continue_button.visible = not FINAL_OUTCOMES.has(outcome)
	var note_lines: Array[String] = []
	note_lines.append(OUTCOME_MESSAGES.get(outcome, ""))
	note_lines.append(SessionState.investigation_outcome_note)
	note_lines.append("Cooperation reached: %d / 100" % SessionState.investigation_cooperation)
	note_lines.append("Detective credibility: %d / 100" % SessionState.detective_credibility)
	outcome_note.text = "\n\n".join(note_lines)
	evidence_value.text = _build_evidence_text()
	milestones_value.text = _build_milestones_text()


func _build_evidence_text() -> String:
	if SessionState.investigation_inventory.is_empty():
		return "[i]No evidence has been logged yet.[/i]"
	var lines: Array[String] = []
	for item in SessionState.investigation_inventory:
		var label := str(item.get("label", "Evidence"))
		var description := str(item.get("description", ""))
		var tactic := str(item.get("tactic", ""))
		if tactic.is_empty():
			lines.append("- [b]%s[/b]: %s" % [label, description])
		else:
			lines.append("- [b]%s[/b]: %s [i](Tactic: %s)[/i]" % [label, description, tactic])
	return "\n".join(lines)


func _build_milestones_text() -> String:
	if SessionState.reflection_milestones.is_empty():
		return "[i]No reflection milestones were recorded this session.[/i]"
	var lines: Array[String] = []
	for milestone in SessionState.reflection_milestones:
		var title := str(milestone.get("title", ""))
		var detail := str(milestone.get("detail", ""))
		if detail.is_empty():
			lines.append("- %s" % title)
		else:
			lines.append("- [b]%s[/b]: %s" % [title, detail])
	return "\n".join(lines)


func _on_continue_pressed() -> void:
	SessionState.go_to_scene("res://scenes/exploration/urban_exterior.tscn")


func _on_main_menu_pressed() -> void:
	SessionState.go_to_menu()
