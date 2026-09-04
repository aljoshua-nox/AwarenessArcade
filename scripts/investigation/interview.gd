extends Control

const DEFAULT_CASE_PATH := "res://resources/cases/interview_case_001.json"
const SUMMARY_SCENE := "res://scenes/investigation/investigation_end.tscn"

var portrait_rect: TextureRect
var person_value: RichTextLabel
var cooperation_value: Label
var cooperation_bar: ProgressBar
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


func _ready() -> void:
	_build_ui()
	_load_case()
	_refresh_person_panel()
	credibility_value.text = "Detective Credibility: %d" % SessionState.detective_credibility
	var start_node := _determine_start_node()
	if start_node == str(case_data.get("start_node", "")):
		_seed_inventory()
	_load_node(start_node)


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
	person_value.fit_content = false
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

	credibility_value = Label.new()
	left_column.add_child(credibility_value)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 8)
	main_row.add_child(right_column)

	var prompt_panel := PanelContainer.new()
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

	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
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

	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % str(person.get("name", "Unknown")))
	lines.append("%s, Age %d" % [str(person.get("role", "Person")), int(person.get("age", 0))])
	lines.append(str(person.get("occupation", "")))
	lines.append(str(person.get("traits", "")))
	person_value.text = "\n".join(lines)


func _load_node(node_id: String, lead_in: String = "") -> void:
	current_node_id = node_id
	current_node = nodes.get(node_id, {})
	if current_node.is_empty():
		return

	var evidence_check: Dictionary = current_node.get("evidence_check", {})
	if not evidence_check.is_empty():
		var required: Array = evidence_check.get("required_evidence", [])
		var all_present := true
		for required_id in required:
			if not SessionState.has_evidence(str(required_id)):
				all_present = false
				break
		var branch_target := str(evidence_check.get("next_if_met", "")) if all_present else str(evidence_check.get("next_if_not_met", ""))
		_load_node(branch_target, lead_in)
		return

	var cooperation_delta := int(current_node.get("cooperation", 0))
	if cooperation_delta != 0:
		cooperation = clampi(cooperation + cooperation_delta, 0, 100)

	var milestone: Dictionary = current_node.get("milestone", {})
	if not milestone.is_empty():
		SessionState.record_reflection_milestone(str(milestone.get("title", "")), str(milestone.get("detail", "")))

	var node_prompt := str(current_node.get("prompt", ""))
	var has_evidence_prompt := bool(current_node.get("evidence_prompt", false))
	var display_prompt := node_prompt
	if has_evidence_prompt:
		var evidence_hint := str(current_node.get("evidence_hint", ""))
		if not evidence_hint.is_empty():
			display_prompt = "%s\n\n[i]%s[/i]" % [node_prompt, evidence_hint]
	if lead_in.is_empty():
		prompt_value.text = display_prompt
	else:
		prompt_value.text = "%s\n\n%s" % [lead_in, display_prompt]
	evidence_panel.visible = false
	present_evidence_button.visible = has_evidence_prompt

	for granted_item in current_node.get("grants_evidence", []):
		if granted_item is Dictionary:
			SessionState.add_evidence(granted_item)

	var choices: Array = current_node.get("choices", [])
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

	var outcome := str(current_node.get("outcome", ""))
	interview_over = not outcome.is_empty()
	end_interview_button.visible = interview_over
	if interview_over:
		present_evidence_button.visible = false
		for button in choice_buttons:
			button.visible = false
			button.disabled = true
		SessionState.investigation_case_title = str(case_data.get("title", ""))
		SessionState.investigation_person_name = str(person.get("name", ""))
		SessionState.investigation_outcome = outcome
		SessionState.investigation_outcome_note = node_prompt
		SessionState.investigation_cooperation = cooperation
		SessionState.record_interview_outcome(str(person.get("person_id", "")), outcome)
		if outcome == "whistleblower":
			SessionState.suspect_flipped = true

	_refresh_cooperation_display()


func _refresh_cooperation_display() -> void:
	cooperation_value.text = "Cooperation: %d" % cooperation
	cooperation_bar.value = cooperation


func _on_choice_pressed(choice_index: int) -> void:
	var choices: Array = current_node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]
	var next_node := str(choice.get("next", ""))
	if next_node.is_empty():
		return
	_load_node(next_node)


func _on_present_evidence_pressed() -> void:
	evidence_list.clear()
	for item in SessionState.investigation_inventory:
		evidence_list.add_item(str(item.get("label", "Evidence")))
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
			var response := str(entry.get("response", ""))
			var tactic := str(item.get("tactic", ""))
			if not tactic.is_empty():
				response = "%s\n\n[i]Tactic noted: %s[/i]" % [response, tactic]
			var cooperation_delta := int(entry.get("cooperation", 0))
			cooperation = clampi(cooperation + cooperation_delta, 0, 100)
			var next_node := str(entry.get("next", current_node_id))
			_load_node(next_node, response)
			return

	prompt_value.text = "%s doesn't seem to connect to what you just asked about." % str(item.get("label", "That evidence"))


func _on_end_interview_pressed() -> void:
	SessionState.go_to_scene(SUMMARY_SCENE)
