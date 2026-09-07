extends Control

const DEFAULT_CASE_PATH := "res://resources/cases/interview_case_001.json"
const SUMMARY_SCENE := "res://scenes/investigation/investigation_end.tscn"

const HIT_SFX := "res://assets/audio/sfx/434379__kila_vat__notification-sound-handmade.mp3"
const MISS_SFX := "res://assets/audio/sfx/524204__joviansounds__radio-static.wav"

const TYPE_CHARS_PER_SECOND := 55.0
const EVIDENCE_MISS_COOPERATION := -10
const LOW_COOPERATION_WARNING := 25
const FALLBACK_FAILURE_NODE := "__cooperation_failure"
const CHOICE_BUTTON_COUNT := 4

# Text voices live in TextStyle so this screen and the office call floor can't
# drift apart. Preloaded rather than used as a global class - see that file.
const TextStyle := preload("res://scripts/systems/text_style.gd")

var portrait_rect: TextureRect
var person_value: RichTextLabel
var cooperation_value: Label
var cooperation_bar: ProgressBar
var cooperation_warning: Label
var credibility_value: Label
var prompt_value: RichTextLabel
var choice_buttons: Array[Button] = []
var present_evidence_button: Button
var evidence_panel: PanelContainer
var evidence_list: ItemList
var present_selected_evidence_button: Button
var end_interview_button: Button

var case_data: Dictionary = {}
var person: Dictionary = {}
var evidence_items: Array[Dictionary] = []
var nodes: Dictionary = {}
var current_node_id: String = ""
var current_node: Dictionary = {}
var cooperation: int = 50
var interview_over: bool = false

# Nodes only apply their cooperation delta once, so revisiting a node in a loop
# (ask -> press -> ask) can't be farmed for free cooperation.
var visited_nodes: Dictionary = {}
# Same guard for evidence: showing the same item at the same node twice re-reads
# the response but pays out cooperation only once.
var presented_evidence: Dictionary = {}
var answered_quizzes: Dictionary = {}
var quiz_active: bool = false
var current_quiz: Dictionary = {}
var evidence_misses: int = 0
var type_tween: Tween

# How this person carries the prologue into the room. Everything after the
# opening beat is shared, so this is a different first impression - not a
# separate script per outcome. Empty on a case with no `dispositions` block,
# and on DISPOSITION_NEUTRAL, which is deliberately the unmodified case.
var disposition: String = SessionState.DISPOSITION_NEUTRAL
var disposition_opening: String = ""
var disposition_note: String = ""
var opening_node_id: String = ""


func _ready() -> void:
	_build_ui()
	_load_case()
	_apply_disposition()
	_refresh_person_panel()
	credibility_value.text = "Detective Credibility: %d" % SessionState.detective_credibility
	var start_node := _determine_start_node()
	if start_node == str(case_data.get("start_node", "")):
		_seed_inventory()
	_load_node(start_node)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_typing():
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed:
		skip = true
	elif event.is_action_pressed("ui_accept"):
		skip = true
	if skip:
		_finish_typing()
		get_viewport().set_input_as_handled()


# The prologue-to-investigation coupling. What the player did to this person
# while playing the scammer sets how far open the door is, and rewrites the
# opening beat so the room reflects it.
#
# A victim who was robbed opens withdrawn and ashamed - harder to reach, but
# they have a paper trail. One who refused opens angry and willing, with little
# to prove. That is a trade, not a difficulty tax: playing the prologue well
# changes the route through the interview rather than making it strictly worse.
#
# Keyed on person_id, never the display name - the two halves spell these
# characters differently on purpose.
func _apply_disposition() -> void:
	opening_node_id = str(case_data.get("start_node", ""))
	disposition = SessionState.get_victim_disposition(str(person.get("person_id", "")))
	var table: Dictionary = person.get("dispositions", {})
	var entry: Dictionary = table.get(disposition, {})
	if entry.is_empty():
		return
	# Cooperation applies on every branch, including a hesitant one: being
	# robbed makes someone harder to reach whichever door you came in by.
	if entry.has("cooperation"):
		cooperation = clampi(int(entry["cooperation"]), 0, 100)
	# The opening text only replaces the default start. A hesitant branch has
	# its own reason for existing and keeps its own words.
	disposition_opening = str(entry.get("prompt", ""))
	disposition_note = str(entry.get("note", ""))


func _determine_start_node() -> String:
	var default_start := str(case_data.get("start_node", ""))
	var min_credibility_variant: Variant = person.get("min_credibility", null)
	if min_credibility_variant == null:
		return default_start
	var min_credibility := int(min_credibility_variant)
	if SessionState.detective_credibility < min_credibility:
		var hesitant_start := str(person.get("hesitant_start", ""))
		if not hesitant_start.is_empty():
			return hesitant_start
	return default_start


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := TextureRect.new()
	background.texture = load("res://assets/art/backgrounds/jose-losada-DyFjxmHt3Es-unsplash.jpg")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
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

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	root_scroll.add_child(root)

	var title_label := Label.new()
	title_label.text = "Interview"
	title_label.add_theme_font_size_override("font_size", 24)
	root.add_child(title_label)

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 14)
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_row)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(260, 0)
	left_column.add_theme_constant_override("separation", 8)
	main_row.add_child(left_column)

	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(0, 160)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_column.add_child(portrait_rect)

	var person_panel := PanelContainer.new()
	person_panel.custom_minimum_size = Vector2(0, 140)
	left_column.add_child(person_panel)
	person_value = RichTextLabel.new()
	person_value.bbcode_enabled = true
	# Grow to fit the traits line instead of clipping it mid-word. Safe because
	# the whole column sits inside root_scroll.
	person_value.fit_content = true
	person_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	person_panel.add_child(person_value)

	var cooperation_column := VBoxContainer.new()
	left_column.add_child(cooperation_column)
	var cooperation_title := Label.new()
	cooperation_title.text = "Cooperation"
	cooperation_column.add_child(cooperation_title)
	cooperation_value = Label.new()
	cooperation_column.add_child(cooperation_value)
	cooperation_bar = ProgressBar.new()
	cooperation_bar.custom_minimum_size = Vector2(0, 18)
	cooperation_bar.min_value = 0.0
	cooperation_bar.max_value = 100.0
	cooperation_bar.show_percentage = false
	cooperation_column.add_child(cooperation_bar)
	cooperation_warning = Label.new()
	cooperation_warning.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_WRONG))
	cooperation_warning.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	cooperation_warning.add_theme_font_size_override("font_size", 13)
	cooperation_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cooperation_warning.visible = false
	cooperation_column.add_child(cooperation_warning)

	credibility_value = Label.new()
	left_column.add_child(credibility_value)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 8)
	main_row.add_child(right_column)

	var prompt_panel := PanelContainer.new()
	prompt_panel.custom_minimum_size = Vector2(0, 260)
	prompt_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(prompt_panel)
	prompt_value = RichTextLabel.new()
	prompt_value.bbcode_enabled = true
	prompt_value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_panel.add_child(prompt_value)

	present_evidence_button = Button.new()
	present_evidence_button.text = "Present Evidence"
	present_evidence_button.custom_minimum_size = Vector2(0, 40)
	present_evidence_button.visible = false
	present_evidence_button.pressed.connect(_on_present_evidence_pressed)
	right_column.add_child(present_evidence_button)

	evidence_panel = PanelContainer.new()
	evidence_panel.visible = false
	right_column.add_child(evidence_panel)
	var evidence_column := VBoxContainer.new()
	evidence_panel.add_child(evidence_column)
	var evidence_title := Label.new()
	evidence_title.text = "Choose evidence to present:"
	evidence_column.add_child(evidence_title)
	var evidence_caution := Label.new()
	evidence_caution.text = "A wrong presentation costs cooperation."
	evidence_caution.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_TACTIC))
	evidence_caution.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	evidence_caution.add_theme_font_size_override("font_size", 13)
	evidence_column.add_child(evidence_caution)
	evidence_list = ItemList.new()
	evidence_list.custom_minimum_size = Vector2(0, 120)
	evidence_list.item_activated.connect(_on_evidence_chosen)
	evidence_column.add_child(evidence_list)

	var evidence_buttons_row := HBoxContainer.new()
	evidence_buttons_row.add_theme_constant_override("separation", 12)
	evidence_column.add_child(evidence_buttons_row)

	present_selected_evidence_button = Button.new()
	present_selected_evidence_button.text = "Present Selected Evidence"
	present_selected_evidence_button.pressed.connect(_on_present_selected_evidence_pressed)
	evidence_buttons_row.add_child(present_selected_evidence_button)

	var evidence_cancel := Button.new()
	evidence_cancel.text = "Cancel"
	evidence_cancel.pressed.connect(func () -> void: evidence_panel.visible = false)
	evidence_buttons_row.add_child(evidence_cancel)

	for index in range(CHOICE_BUTTON_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_choice_pressed.bind(index))
		right_column.add_child(button)
		choice_buttons.append(button)

	end_interview_button = Button.new()
	end_interview_button.text = "View Case Summary"
	end_interview_button.custom_minimum_size = Vector2(200, 40)
	end_interview_button.visible = false
	end_interview_button.pressed.connect(_on_end_interview_pressed)
	root.add_child(end_interview_button)


func _load_case() -> void:
	var case_path := DEFAULT_CASE_PATH
	if not SessionState.pending_case_path.is_empty():
		case_path = SessionState.pending_case_path
	SessionState.pending_case_path = ""

	var file := FileAccess.open(case_path, FileAccess.READ)
	if file == null:
		push_error("Could not open interview case: %s" % case_path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Interview case is not a dictionary: %s" % case_path)
		return

	case_data = parsed as Dictionary
	person = case_data.get("person", {})
	nodes = case_data.get("nodes", {})
	evidence_items.clear()
	for item in case_data.get("evidence", []):
		if item is Dictionary:
			evidence_items.append(item)


func _seed_inventory() -> void:
	for item in evidence_items:
		SessionState.add_evidence(item)


func _refresh_person_panel() -> void:
	var portrait_path := str(person.get("portrait", ""))
	if not portrait_path.is_empty():
		portrait_rect.texture = load(portrait_path)

	var muted: String = TextStyle.COLOR_NARRATION
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % str(person.get("name", "Unknown")))
	lines.append("[color=#%s]%s, Age %d[/color]" % [muted, str(person.get("role", "Person")), int(person.get("age", 0))])
	var occupation := str(person.get("occupation", ""))
	if not occupation.is_empty():
		lines.append("[color=#%s]%s[/color]" % [muted, occupation])
	var traits := str(person.get("traits", ""))
	if not traits.is_empty():
		lines.append("[font_size=12][color=#%s]%s[/color][/font_size]" % [muted, traits])
	person_value.text = "\n".join(lines)


func _load_node(node_id: String, lead_in: String = "") -> void:
	current_node_id = node_id
	current_node = nodes.get(node_id, {})
	if current_node.is_empty():
		return

	var evidence_check: Dictionary = current_node.get("evidence_check", {})
	if not evidence_check.is_empty():
		var required: Array = evidence_check.get("required_evidence", [])
		var held := 0
		for required_id in required:
			if SessionState.has_evidence(str(required_id)):
				held += 1
		# `min_matching` lets a check ask for "any N of these" instead of all of
		# them. The endings need it: once there is more than one pair of
		# witnesses who could carry a case, demanding two *named* testimonies
		# would make every witness after the second one decorative.
		var needed := required.size()
		if evidence_check.has("min_matching"):
			needed = clampi(int(evidence_check["min_matching"]), 1, required.size())
		var met := held >= needed
		var branch_target := str(evidence_check.get("next_if_met", "")) if met else str(evidence_check.get("next_if_not_met", ""))
		_load_node(branch_target, lead_in)
		return

	if not visited_nodes.has(node_id):
		visited_nodes[node_id] = true
		var cooperation_delta := int(current_node.get("cooperation", 0))
		if cooperation_delta != 0:
			_apply_cooperation(cooperation_delta)

	var milestone: Dictionary = current_node.get("milestone", {})
	if not milestone.is_empty():
		SessionState.record_reflection_milestone(str(milestone.get("title", "")), str(milestone.get("detail", "")))

	for granted_item in current_node.get("grants_evidence", []):
		if granted_item is Dictionary:
			SessionState.add_evidence(granted_item)

	var outcome := str(current_node.get("outcome", ""))

	# Losing the room is a real ending: bail out to the failure node instead of
	# letting the player keep questioning someone who has shut down.
	if outcome.is_empty() and cooperation <= 0:
		var failure_id := _failure_node_id()
		if node_id != failure_id:
			_load_node(failure_id, lead_in)
			return

	var quiz: Dictionary = current_node.get("tactic_quiz", {})
	if not quiz.is_empty():
		if not answered_quizzes.has(node_id):
			_start_quiz(quiz, lead_in)
			return
		# Already answered. Quiz nodes carry no prompt of their own, so walking
		# back into one must fall through instead of showing an empty screen.
		var resume := str(quiz.get("next", ""))
		if resume.is_empty():
			resume = str(quiz.get("next_correct", ""))
		if not resume.is_empty() and resume != node_id:
			_load_node(resume, lead_in)
			return

	quiz_active = false
	current_quiz = {}

	var node_prompt := str(current_node.get("prompt", ""))
	if node_id == opening_node_id and not disposition_opening.is_empty():
		node_prompt = disposition_opening
	var has_evidence_prompt := bool(current_node.get("evidence_prompt", false))
	var display_prompt := _style_dialogue(node_prompt)
	# A claim is a checkable assertion, pinned above the evidence list so the
	# player is looking for a thing that does not fit rather than a thing that
	# corroborates. Presenting the right record is the whole mechanic.
	var claim := str(current_node.get("claim", ""))
	if not claim.is_empty():
		display_prompt = "%s\n\n%s" % [display_prompt, _system_line(TextStyle.MARK_CLAIM, claim, TextStyle.COLOR_HINT)]
	# Say out loud that this is the player's own doing, or the mechanic is
	# invisible - the cooperation bar alone gives them nothing to compare against.
	if node_id == opening_node_id and not disposition_note.is_empty():
		display_prompt = "%s

%s" % [display_prompt, _system_line(TextStyle.MARK_HARM, disposition_note, TextStyle.COLOR_WRONG)]
	if has_evidence_prompt:
		var evidence_hint := str(current_node.get("evidence_hint", ""))
		if not evidence_hint.is_empty():
			display_prompt = "%s\n\n%s" % [display_prompt, _system_line(TextStyle.MARK_HINT, evidence_hint, TextStyle.COLOR_HINT)]
	if lead_in.is_empty():
		_reveal_prompt(display_prompt)
	else:
		_reveal_prompt("%s\n\n%s" % [lead_in, display_prompt])
	evidence_panel.visible = false
	present_evidence_button.visible = has_evidence_prompt

	var choices: Array = current_node.get("choices", [])
	_show_choices(choices)

	interview_over = not outcome.is_empty()
	end_interview_button.visible = interview_over
	if interview_over:
		present_evidence_button.visible = false
		_hide_choices()
		SessionState.investigation_case_title = str(case_data.get("title", ""))
		SessionState.investigation_person_name = str(person.get("name", ""))
		SessionState.investigation_outcome = outcome
		SessionState.investigation_outcome_note = node_prompt
		SessionState.investigation_cooperation = cooperation
		SessionState.investigation_evidence_misses = evidence_misses
		SessionState.record_interview_outcome(str(person.get("person_id", "")), outcome)
		if bool(current_node.get("locks_case", false)):
			SessionState.case_locked = true
		if outcome == "whistleblower":
			SessionState.suspect_flipped = true
		if outcome == "failure":
			_play_sting(false)

	_refresh_cooperation_display()


func _show_choices(choices: Array) -> void:
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		if index < choices.size():
			var choice: Dictionary = choices[index]
			button.visible = true
			button.disabled = false
			button.text = str(choice.get("text", "Choice"))
		else:
			button.visible = false
			button.disabled = true
			button.text = ""


func _hide_choices() -> void:
	for button in choice_buttons:
		button.visible = false
		button.disabled = true


func _failure_node_id() -> String:
	var configured := str(case_data.get("failure_node", ""))
	if not configured.is_empty() and nodes.has(configured):
		return configured
	if not nodes.has(FALLBACK_FAILURE_NODE):
		nodes[FALLBACK_FAILURE_NODE] = {
			"prompt": "%s stops answering. \"I think we're done here.\" Whatever they still knew, you aren't getting it today." % str(person.get("name", "They")),
			"outcome": "failure",
			"choices": [],
		}
	return FALLBACK_FAILURE_NODE


func _apply_cooperation(delta: int) -> void:
	if delta == 0:
		return
	cooperation = clampi(cooperation + delta, 0, 100)
	_refresh_cooperation_display()


func _refresh_cooperation_display() -> void:
	cooperation_value.text = "%d / 100" % cooperation
	cooperation_bar.value = cooperation
	if cooperation <= LOW_COOPERATION_WARNING:
		cooperation_bar.modulate = Color(1.0, 0.5, 0.4)
		cooperation_warning.text = "They are close to shutting down. Ease off."
		cooperation_warning.visible = not interview_over
	else:
		cooperation_bar.modulate = Color(1, 1, 1)
		cooperation_warning.visible = false


# --- Tactic quiz -------------------------------------------------------------

func _start_quiz(quiz: Dictionary, lead_in: String) -> void:
	quiz_active = true
	current_quiz = quiz
	present_evidence_button.visible = false
	evidence_panel.visible = false
	end_interview_button.visible = false

	var setup := str(quiz.get("setup", ""))
	var question := _system_line(TextStyle.MARK_HINT, str(quiz.get("question", "")), TextStyle.COLOR_HINT)
	var body := question
	if not setup.is_empty():
		body = "%s\n\n%s" % [_style_dialogue(setup), question]
	if not lead_in.is_empty():
		body = "%s\n\n%s" % [lead_in, body]
	_reveal_prompt(body)

	var options: Array = quiz.get("options", [])
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		if index < options.size():
			var option: Dictionary = options[index]
			button.visible = true
			button.disabled = false
			button.text = str(option.get("text", "Option"))
		else:
			button.visible = false
			button.disabled = true
			button.text = ""


func _answer_quiz(option_index: int) -> void:
	var options: Array = current_quiz.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return
	var option: Dictionary = options[option_index]
	var correct := bool(option.get("correct", false))

	answered_quizzes[current_node_id] = true
	quiz_active = false
	SessionState.record_tactic_read(correct, str(current_quiz.get("tactic", "")))
	# The quiz explains the tactic on a wrong answer too, so the notebook
	# entry is earned either way - the teaching is not conditional on
	# playing well.
	var quiz_tactic_id := str(current_quiz.get("tactic_id", ""))
	if not quiz_tactic_id.is_empty():
		var learned_where := "Named while interviewing %s" % str(person.get("name", "a witness"))
		if not correct:
			learned_where = "Explained after a misread, interviewing %s" % str(person.get("name", "a witness"))
		SessionState.record_tactic_learned(quiz_tactic_id, learned_where)
	_apply_cooperation(int(option.get("cooperation", 0)))
	_play_sting(correct)

	var feedback := str(option.get("feedback", ""))
	var lead_in := ""
	if correct:
		lead_in = _system_line(TextStyle.MARK_CORRECT, feedback, TextStyle.COLOR_CORRECT)
	else:
		lead_in = _system_line(TextStyle.MARK_WRONG, "That is not the manipulation. %s" % feedback, TextStyle.COLOR_WRONG)

	if correct:
		var milestone: Dictionary = current_quiz.get("milestone", {})
		if not milestone.is_empty():
			SessionState.record_reflection_milestone(str(milestone.get("title", "")), str(milestone.get("detail", "")))

	var next_node := str(option.get("next", ""))
	if next_node.is_empty():
		next_node = str(current_quiz.get("next_correct", "")) if correct else str(current_quiz.get("next_wrong", ""))
	if next_node.is_empty():
		next_node = str(current_quiz.get("next", ""))
	if next_node.is_empty():
		next_node = current_node_id
	_load_node(next_node, lead_in)


# --- Choices and evidence ----------------------------------------------------

func _on_choice_pressed(choice_index: int) -> void:
	if quiz_active:
		_answer_quiz(choice_index)
		return
	var choices: Array = current_node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]
	var choice_cooperation := int(choice.get("cooperation", 0))
	if choice_cooperation != 0:
		_apply_cooperation(choice_cooperation)
		_play_sting(choice_cooperation > 0)
	var next_node := str(choice.get("next", ""))
	if next_node.is_empty():
		return
	_load_node(next_node)


func _on_present_evidence_pressed() -> void:
	evidence_list.clear()
	for item in SessionState.investigation_inventory:
		var index := evidence_list.add_item(str(item.get("label", "Evidence")))
		var tooltip := str(item.get("description", ""))
		var tactic := str(item.get("tactic", ""))
		if not tactic.is_empty():
			tooltip = "%s\n\nTactic: %s" % [tooltip, tactic]
		evidence_list.set_item_tooltip(index, tooltip)
	evidence_panel.visible = true


func _on_present_selected_evidence_pressed() -> void:
	var selected := evidence_list.get_selected_items()
	if selected.is_empty():
		return
	_on_evidence_chosen(selected[0])


func _on_evidence_chosen(index: int) -> void:
	if index < 0 or index >= SessionState.investigation_inventory.size():
		return
	var item: Dictionary = SessionState.investigation_inventory[index]
	var item_id := str(item.get("id", ""))
	evidence_panel.visible = false

	var accepts: Array = current_node.get("accepts_evidence", [])
	for entry in accepts:
		if str(entry.get("evidence_id", "")) == item_id:
			var response := _style_dialogue(str(entry.get("response", "")))
			var tactic := str(item.get("tactic", ""))
			var is_wrong := bool(entry.get("wrong", false))
			# Presenting corroboration teaches "keep your records". Catching a
			# lie teaches the sharper thing - a scam story does not survive
			# cross-checking - so it gets its own marker rather than being
			# reported as one more successful piece of evidence.
			if bool(entry.get("contradicts", false)):
				var broke := str(entry.get("contradiction_note", ""))
				if broke.is_empty():
					broke = "That account does not survive the record you are holding."
				response = "%s\n\n%s" % [response, _system_line(
					TextStyle.MARK_CONTRADICTION, broke, TextStyle.COLOR_CORRECT)]
			if not tactic.is_empty():
				var mark: String = TextStyle.MARK_WRONG if is_wrong else TextStyle.MARK_TACTIC
				var tone: String = TextStyle.COLOR_WRONG if is_wrong else TextStyle.COLOR_TACTIC
				response = "%s\n\n%s" % [response, _system_line(mark, tactic, tone)]
				# Reading a tactic off a piece of evidence is how most of them are
				# met, so that is where most notebook entries come from. A decoy
				# presented wrongly teaches nothing and unlocks nothing.
				if not is_wrong:
					SessionState.record_tactic_learned(str(item.get("tactic_id", "")),
						"From %s, shown to %s" % [str(item.get("label", "evidence")), str(person.get("name", "a witness"))])
			var presentation_key := "%s|%s" % [current_node_id, item_id]
			var repeated := presented_evidence.has(presentation_key)
			presented_evidence[presentation_key] = true
			var cooperation_delta := 0 if repeated else int(entry.get("cooperation", 0))
			_apply_cooperation(cooperation_delta)
			_play_sting(not is_wrong and cooperation_delta >= 0)
			if is_wrong and not repeated:
				evidence_misses += 1
			var next_node := str(entry.get("next", current_node_id))
			_load_node(next_node, response)
			return

	_handle_evidence_miss(item)


# An unlisted piece of evidence used to be a free retry. Now it costs the room's
# patience and still teaches what the item actually demonstrates.
func _handle_evidence_miss(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	var presentation_key := "%s|%s" % [current_node_id, item_id]
	if not presented_evidence.has(presentation_key):
		presented_evidence[presentation_key] = true
		evidence_misses += 1
		_apply_cooperation(int(current_node.get("evidence_miss_cooperation", EVIDENCE_MISS_COOPERATION)))
	_play_sting(false)

	var label := str(item.get("label", "That evidence"))
	var tactic := str(item.get("tactic", ""))
	var body := ""
	if tactic.is_empty():
		body = "%s doesn't show a tactic. It's background detail, not proof of anything, and chasing it costs you the room." % label
	else:
		body = "%s is real evidence, but not of what you just asked about. Keep it on file - it demonstrates: %s" % [label, tactic]

	_load_node(current_node_id, _system_line(TextStyle.MARK_WRONG, body, TextStyle.COLOR_WRONG))


# --- Text voices -------------------------------------------------------------

func _style_dialogue(raw: String) -> String:
	return TextStyle.dialogue(raw)


func _system_line(marker: String, body: String, color: String) -> String:
	return TextStyle.system(marker, body, color)


# --- Presentation ------------------------------------------------------------

func _reveal_prompt(text: String) -> void:
	if type_tween != null and type_tween.is_running():
		type_tween.kill()
	prompt_value.text = text
	var character_count := prompt_value.get_total_character_count()
	if character_count <= 0:
		prompt_value.visible_ratio = 1.0
		return
	prompt_value.visible_ratio = 0.0
	type_tween = create_tween()
	type_tween.tween_property(prompt_value, "visible_ratio", 1.0, float(character_count) / TYPE_CHARS_PER_SECOND)


func _is_typing() -> bool:
	return type_tween != null and type_tween.is_running()


func _finish_typing() -> void:
	if type_tween != null:
		type_tween.kill()
	prompt_value.visible_ratio = 1.0


func _play_sting(positive: bool) -> void:
	AudioManager.play_stream(HIT_SFX if positive else MISS_SFX, -16.0)
	_flinch(positive)


func _flinch(positive: bool) -> void:
	if portrait_rect.texture == null:
		return
	portrait_rect.pivot_offset = portrait_rect.size / 2.0
	var tint := Color(0.75, 1.0, 0.8) if positive else Color(1.0, 0.6, 0.55)
	var tilt := 0.03 if positive else 0.06
	var tween := create_tween()
	tween.tween_property(portrait_rect, "modulate", tint, 0.08)
	tween.parallel().tween_property(portrait_rect, "rotation", tilt, 0.06)
	tween.tween_property(portrait_rect, "rotation", -tilt * 0.6, 0.08)
	tween.tween_property(portrait_rect, "rotation", 0.0, 0.08)
	tween.parallel().tween_property(portrait_rect, "modulate", Color(1, 1, 1), 0.2)


func _on_end_interview_pressed() -> void:
	SessionState.go_to_scene(SUMMARY_SCENE)
