extends Control

const TextStyle := preload("res://scripts/systems/text_style.gd")

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

# Whether the player could name the manipulation does not decide who gets
# arrested - that is what the evidence is for, and gating justice behind a quiz
# score would punish the wrong thing. What it decides is whether they leave able
# to recognise the next one, which is the entire point of the game, so the
# ending has to say it out loud instead of leaving it in a scorecard.
const AWARENESS_VERDICTS := {
	"full_takedown": {
		"sharp": "You did not only close it - you can name every lever they pulled. The office is gone, and so is the part of this that could ever be used on you.",
		"mixed": "Some of what it ran on still went past you unnamed, though, and those same lines are being read off a script somewhere else tonight.",
		"blind": "The office is gone. The scripts are not. You took an operation apart without once naming what it actually did to people - and the next crew will use the same three, because they work.",
	},
	"partial_justice": {
		"sharp": "You could not reach the top of it, but you understood it. That is the part of an unfinished case that still protects somebody.",
		"mixed": "A partial case and a partial reading of it. Both are fixable. Neither is fixed yet.",
		"blind": "The callers face consequences, and nobody involved - including you - ever said out loud what they were actually doing.",
	},
	"bribed": {
		"sharp": "You named every tactic correctly. You understood exactly what was done to Maria and to Kevin. Then you were offered money, and it turned out that understanding was never the thing standing in the way.",
		"mixed": "You saw some of it clearly. It made no difference to what you did with the envelope.",
		"blind": "You never named what they were doing, and then you took their money. The two are not unrelated - it is easier to accept payment for something you have declined to describe.",
	},
}

var title_label: Label
var outcome_label: Label
var outcome_note: RichTextLabel
var scorecard_value: RichTextLabel
var awareness_title: Label
var awareness_bar: ProgressBar
var evidence_value: RichTextLabel
var milestones_value: RichTextLabel
var evidence_header: Button
var milestones_header: Button
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

	# A fixed-width column centred by spacers, filling the available height, so
	# the reading measure stays comfortable and the panel has a real bottom to
	# pin the buttons to.
	var centring_row := HBoxContainer.new()
	centring_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centring_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_child(centring_row)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centring_row.add_child(left_spacer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	panel.size_flags_vertical = Control.SIZE_FILL
	centring_row.add_child(panel)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centring_row.add_child(right_spacer)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_label)

	outcome_label = Label.new()
	outcome_label.add_theme_font_size_override("font_size", 18)
	column.add_child(outcome_label)

	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(body_scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body_scroll.add_child(body)

	# The verdict is the ending. It gets the room, and the reference material
	# below it does not compete with it for attention.
	outcome_note = RichTextLabel.new()
	outcome_note.bbcode_enabled = true
	outcome_note.fit_content = true
	outcome_note.custom_minimum_size = Vector2(0, 60)
	body.add_child(outcome_note)

	body.add_child(_rule())

	awareness_title = Label.new()
	awareness_title.text = "Awareness"
	body.add_child(awareness_title)

	awareness_bar = ProgressBar.new()
	awareness_bar.custom_minimum_size = Vector2(0, 14)
	awareness_bar.min_value = 0.0
	awareness_bar.max_value = 100.0
	awareness_bar.show_percentage = false
	body.add_child(awareness_bar)

	scorecard_value = RichTextLabel.new()
	scorecard_value.bbcode_enabled = true
	scorecard_value.fit_content = true
	body.add_child(scorecard_value)

	body.add_child(_rule())

	# Evidence and milestones are reference, not reading. Collapsed by default
	# so a full case file does not bury the ending under forty lines of list;
	# nothing is removed, it is one click away.
	var evidence_section := _add_collapsible(body, "Evidence on file")
	evidence_header = evidence_section["header"]
	evidence_value = evidence_section["body"]

	var milestones_section := _add_collapsible(body, "Reflection milestones")
	milestones_header = milestones_section["header"]
	milestones_value = milestones_section["body"]

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


# The themed fill is red, which reads as failure at any value. Colour it by
# tier instead so a strong reading looks like one.
func _tint_awareness_bar() -> void:
	var fill := StyleBoxFlat.new()
	match SessionState.get_awareness_tier():
		SessionState.AWARENESS_SHARP:
			fill.bg_color = Color(TextStyle.COLOR_CORRECT)
		SessionState.AWARENESS_BLIND:
			fill.bg_color = Color(TextStyle.COLOR_WRONG)
		_:
			fill.bg_color = Color(TextStyle.COLOR_TACTIC)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	awareness_bar.add_theme_stylebox_override("fill", fill)


func _rule() -> Control:
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.12)
	rule.custom_minimum_size = Vector2(0, 1)
	return rule


# A header button that shows or hides its own body. Deliberately plain - the
# arrow and the count carry the affordance.
func _add_collapsible(parent: VBoxContainer, title: String) -> Dictionary:
	var header := Button.new()
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.flat = true
	header.set_meta("title", title)
	parent.add_child(header)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	# fit_content inside the screen's ScrollContainer: a fixed height would
	# silently clip the list as it grows, which is a bug this project has hit
	# three times already.
	body.fit_content = true
	body.visible = false
	parent.add_child(body)

	header.pressed.connect(_toggle_section.bind(header, body))
	return {"header": header, "body": body}


func _toggle_section(header: Button, body: RichTextLabel) -> void:
	body.visible = not body.visible
	_refresh_section_header(header, body)


func _refresh_section_header(header: Button, body: RichTextLabel) -> void:
	var arrow := "v" if body.visible else ">"
	header.text = "%s  %s   (%d)" % [arrow, str(header.get_meta("title", "")), int(header.get_meta("count", 0))]


func _refresh_view() -> void:
	var case_title := SessionState.investigation_case_title
	var person_name := SessionState.investigation_person_name
	if person_name.is_empty() or case_title.contains(person_name):
		title_label.text = case_title
	else:
		title_label.text = "%s - %s" % [case_title, person_name]
	var outcome := SessionState.investigation_outcome
	outcome_label.text = OUTCOME_LABELS.get(outcome, "Interview Concluded")
	continue_button.visible = not FINAL_OUTCOMES.has(outcome)
	var note_lines: Array[String] = []
	note_lines.append(OUTCOME_MESSAGES.get(outcome, ""))
	note_lines.append(SessionState.investigation_outcome_note)
	var verdict := _awareness_verdict(outcome)
	if not verdict.is_empty():
		note_lines.append(verdict)
	# Two running numbers do not need a paragraph each.
	note_lines.append("[color=#%s]Cooperation %d / 100     Credibility %d / 100[/color]" % [
		TextStyle.COLOR_NARRATION,
		SessionState.investigation_cooperation,
		SessionState.detective_credibility])
	outcome_note.text = "\n\n".join(note_lines)

	scorecard_value.text = _build_scorecard_text()
	var total := SessionState.tactic_reads_total
	awareness_bar.visible = total > 0
	if total > 0:
		awareness_bar.value = (float(SessionState.tactic_reads_correct) / float(total)) * 100.0
		awareness_title.text = "Awareness - %d of %d tactics named" % [
			SessionState.tactic_reads_correct, total]
	else:
		awareness_bar.value = 0.0
		awareness_title.text = "Awareness"
	_tint_awareness_bar()

	evidence_value.text = _build_evidence_text()
	evidence_header.set_meta("count", SessionState.investigation_inventory.size())
	_refresh_section_header(evidence_header, evidence_value)

	milestones_value.text = _build_milestones_text()
	milestones_header.set_meta("count", SessionState.reflection_milestones.size())
	_refresh_section_header(milestones_header, milestones_value)


# Only the three true endings carry a verdict. The per-interview outcomes are
# mid-case summaries, where a closing statement on the player's awareness would
# be premature.
func _awareness_verdict(outcome: String) -> String:
	if not FINAL_OUTCOMES.has(outcome):
		return ""
	var tier := SessionState.get_awareness_tier()
	if tier == SessionState.AWARENESS_UNTESTED:
		return ""
	return str(AWARENESS_VERDICTS.get(outcome, {}).get(tier, ""))


func _build_scorecard_text() -> String:
	var lines: Array[String] = []
	if SessionState.tactic_reads_total <= 0:
		lines.append("[i]No manipulation tactics have been identified yet this session.[/i]")
	else:
		if SessionState.tactic_reads_correct == SessionState.tactic_reads_total:
			lines.append("You named the manipulation every time it was put in front of you.")
		elif SessionState.tactic_reads_correct == 0:
			lines.append("The tactics went unnamed. These scripts work precisely because the pressure looks like ordinary procedure.")
		else:
			lines.append("Some of the manipulation went unnamed. Reviewing the tactics on file is worth the time.")
		# Naming the specific misses is the difference between a score and a
		# thing the player can go and look up.
		var missed := SessionState.get_missed_tactics()
		if not missed.is_empty():
			lines.append("[b]Went unnamed:[/b] %s" % ", ".join(missed))

	var misses := SessionState.investigation_evidence_misses
	if misses > 0:
		lines.append("[b]Evidence misread:[/b] %d time(s) in this interview. Presenting something that doesn't prove what you claim costs you the room." % misses)

	return "\n\n".join(lines)


func _build_evidence_text() -> String:
	if SessionState.investigation_inventory.is_empty():
		return "[i]No evidence has been logged yet.[/i]"
	# The description was already read in play, when the item was presented.
	# What is worth carrying out of the case is the item and the tactic it
	# proves, so each row is a name and a lesson rather than a paragraph.
	var lines: Array[String] = []
	for item in SessionState.investigation_inventory:
		var label := str(item.get("label", "Evidence"))
		var tactic := str(item.get("tactic", ""))
		if tactic.is_empty():
			lines.append("[b]%s[/b]" % label)
		else:
			lines.append("[b]%s[/b]\n    [color=#%s]%s[/color]" % [label, TextStyle.COLOR_NARRATION, tactic])
	return "\n\n".join(lines)


func _build_milestones_text() -> String:
	if SessionState.reflection_milestones.is_empty():
		return "[i]No reflection milestones were recorded this session.[/i]"
	var lines: Array[String] = []
	for milestone in SessionState.reflection_milestones:
		var title := str(milestone.get("title", ""))
		var detail := str(milestone.get("detail", ""))
		if detail.is_empty():
			lines.append("[b]%s[/b]" % title)
		else:
			lines.append("[b]%s[/b]\n    [color=#%s]%s[/color]" % [title, TextStyle.COLOR_NARRATION, detail])
	return "\n\n".join(lines)


func _on_continue_pressed() -> void:
	SessionState.go_to_scene("res://scenes/exploration/urban_exterior.tscn")


func _on_main_menu_pressed() -> void:
	SessionState.go_to_menu()
