extends Control

const TextStyle := preload("res://scripts/systems/text_style.gd")

const HARM_MESSAGES: Array[String] = [
	"Fraud depends on pressure, false urgency, and abuse of trust. The damage is measured in savings lost, debts created, and people left afraid to answer the phone.",
	"Scams often work by isolating one person long enough to overwhelm their judgment. The aftermath can leave victims ashamed, stressed, and financially exposed.",
	"Behind every successful fraud is a person who was made to feel rushed, confused, or scared. Those losses can affect rent, medicine, food, and family stability.",
	"Call scams exploit normal trust in banks, companies, and authorities. When the deception lands, the harm is often emotional first and financial second.",
	"Repeated fraud does not just move money. It erodes confidence, creates anxiety, and forces victims to question who they can trust next.",
	"A single deceptive call can trigger days or months of recovery. Victims may face missing savings, delayed bills, and the distress of realizing they were manipulated.",
]

var end_title: Label
var end_reason: Label
var summary_value: RichTextLabel
var call_log_value: RichTextLabel
var milestones_value: RichTextLabel
var note_value: RichTextLabel

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
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
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	end_title = Label.new()
	end_title.add_theme_font_size_override("font_size", 26)
	column.add_child(end_title)

	end_reason = Label.new()
	column.add_child(end_reason)

	summary_value = RichTextLabel.new()
	summary_value.bbcode_enabled = true
	summary_value.fit_content = true
	summary_value.custom_minimum_size = Vector2(0, 140)
	column.add_child(summary_value)

	var log_title := Label.new()
	log_title.text = "The Calls"
	column.add_child(log_title)

	call_log_value = RichTextLabel.new()
	call_log_value.bbcode_enabled = true
	call_log_value.fit_content = true
	call_log_value.custom_minimum_size = Vector2(0, 80)
	column.add_child(call_log_value)

	var milestones_title := Label.new()
	milestones_title.text = "What You Noticed"
	column.add_child(milestones_title)

	milestones_value = RichTextLabel.new()
	milestones_value.bbcode_enabled = true
	milestones_value.fit_content = true
	milestones_value.custom_minimum_size = Vector2(0, 100)
	column.add_child(milestones_value)

	note_value = RichTextLabel.new()
	note_value.bbcode_enabled = true
	note_value.fit_content = true
	note_value.custom_minimum_size = Vector2(0, 100)
	column.add_child(note_value)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(button_row)

	var continue_button := Button.new()
	continue_button.text = "Continue to Investigation"
	continue_button.custom_minimum_size = Vector2(240, 44)
	continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(continue_button)

	var main_menu_button := Button.new()
	main_menu_button.text = "Main Menu"
	main_menu_button.custom_minimum_size = Vector2(160, 44)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	button_row.add_child(main_menu_button)


func _refresh_view() -> void:
	end_title.text = "The Call Center Goes Quiet"
	end_reason.text = SessionState.prologue_end_reason if not SessionState.prologue_end_reason.is_empty() else "The operation has concluded."
	summary_value.text = _build_summary_text()
	call_log_value.text = _build_call_log_text()
	milestones_value.text = _build_milestones_text()
	var note_lines: Array[String] = []
	if not SessionState.prologue_end_note.is_empty():
		note_lines.append(SessionState.prologue_end_note)
	note_lines.append(_get_random_harm_message())
	note_lines.append("A detective has picked up the case. Time to see what your calls left behind.")
	note_value.text = "\n\n".join(note_lines)


func _build_summary_text() -> String:
	var lines: Array[String] = []
	lines.append("[b]Calls made:[/b] %d" % SessionState.calls_made)
	lines.append("[b]Reports against the line:[/b] %d of %d" % [SessionState.reports_filed, SessionState.REPORTS_TO_PULL_LINE])
	lines.append("[b]Taken from the people you called:[/b] %s" % _format_currency(SessionState.profit))
	var tactic_names: Array[String] = []
	for tactic_id in SessionState.prologue_tactics_used:
		tactic_names.append(_tactic_name(str(tactic_id)))
	if not tactic_names.is_empty():
		lines.append("[b]Tactics used:[/b] %s" % ", ".join(tactic_names))
	return "\n".join(lines)


# One row per call, in the order they were made: who, what happened, what it
# cost, and what they said about it afterwards. The same record the office
# ledger prints and the interviews quote - this is the player's first look at it.
func _build_call_log_text() -> String:
	if SessionState.prologue_call_log.is_empty():
		return "[i]You made no calls.[/i]"
	var lines: Array[String] = []
	for entry in SessionState.prologue_call_log:
		var outcome := str(entry.get("outcome", ""))
		var payout := int(entry.get("payout", 0))
		var tone: String = TextStyle.COLOR_HINT
		var what := ""
		match outcome:
			SessionState.CALL_SUCCESS:
				what = "transferred %s" % _format_currency(payout)
				tone = TextStyle.COLOR_WRONG
			SessionState.CALL_PARTIAL:
				what = "partial transfer, %s" % _format_currency(payout)
				tone = TextStyle.COLOR_WRONG
			SessionState.CALL_REFUSED:
				what = "refused"
				tone = TextStyle.COLOR_TACTIC
			SessionState.CALL_HUNG_UP:
				what = "hung up"
				tone = TextStyle.COLOR_TACTIC
			SessionState.CALL_TIMEOUT:
				what = "cut off by the shift clock"
			SessionState.CALL_ABORTED:
				what = "dropped by you"
			_:
				what = "line pulled"
		lines.append("[color=#%s][b]%s[/b] - %s[/color]" % [tone, str(entry.get("name", "Unknown")), what])
		var consequence := str(entry.get("consequence", ""))
		if not consequence.is_empty():
			lines.append(TextStyle.dialogue("\"%s\"" % consequence))
		lines.append("")
	return "\n".join(lines)


func _tactic_name(tactic_id: String) -> String:
	for entry in TacticNotebook.tactics:
		if str(entry.get("id", "")) == tactic_id:
			return str(entry.get("name", tactic_id))
	return tactic_id


func _build_milestones_text() -> String:
	if SessionState.reflection_milestones.is_empty():
		return "[i]Nothing noted this session.[/i]"

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
	SessionState.start_investigation_from_prologue()


func _on_main_menu_pressed() -> void:
	SessionState.go_to_menu()


func _format_currency(amount: int) -> String:
	return TextStyle.currency(amount)


func _get_random_harm_message() -> String:
	if HARM_MESSAGES.is_empty():
		return "Fraud operations exploit trust and vulnerability. In reality, scams cause billions in financial losses and emotional harm every year."
	return HARM_MESSAGES[rng.randi_range(0, HARM_MESSAGES.size() - 1)]
