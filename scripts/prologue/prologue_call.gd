extends Control

const TextStyle := preload("res://scripts/systems/text_style.gd")

const CONTENT_PATH := "res://resources/dialogue/call_content.json"
const MAX_TRUST_GAIN := 5
const MAX_TRUST_LOSS := 6
const MAX_SUSPICION_GAIN := 4
const MAX_SUSPICION_LOSS := 3
const COMMUNITY_ALERT_CALLS := 3
const COMMUNITY_ALERT_REPUTATION := 65
const COMMUNITY_ALERT_SUSPICION := 18
const BANK_SECURITY_PROFIT := 2600
const BANK_SECURITY_SUSPICION := 30
const INVESTIGATION_REPORTS := 1
const INVESTIGATION_SUSPICION := 50
const INVESTIGATION_REPUTATION := 45

const RING_SFX := "res://assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3"
const ALERT_SFX := "res://assets/audio/sfx/434379__kila_vat__notification-sound-handmade.mp3"
const DIAL_TONE_SFX := "res://assets/audio/sfx/360480__giddster__dial-tone.wav"
const SUGGESTED_CALL_TARGET := 3

var calls_value: Label
var profit_value: Label
var alerts_value: Label
var session_value: Label
var trust_value: Label
var trust_bar: ProgressBar
var suspicion_value: Label
var suspicion_bar: ProgressBar
var reputation_value: Label
var reputation_bar: ProgressBar
var timer_value: Label
var timer_bar: ProgressBar
var victim_list: ItemList
var victim_portrait: TextureRect
var profile_value: RichTextLabel
var dialogue_value: RichTextLabel
var back_to_menu_button: Button
var end_prologue_button: Button
var choice_buttons: Array[Button] = []

var victims: Array[Dictionary] = []
var dialogue_nodes: Dictionary = {}
var preview_victim_index: int = -1
var current_victim_index: int = -1
var current_node_id: String = ""
var current_node: Dictionary = {}
var current_prompt_text: String = ""
var current_payout_amount: int = 0
var current_payout_floor: int = 0
var current_payout_model: String = ""
var current_call_reward: int = 0
var current_call_outcome: String = ""
var current_call_consequence_lines: Array[String] = []
var current_call_notice_lines: Array[String] = []
var current_call_time_left: float = 0.0
var current_call_time_limit: float = 0.0
var transcript_lines: Array[String] = []
var current_choice_indices: Array[int] = []
var last_alert_text: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var call_active: bool = false
var prologue_end_transition_started: bool = false


func _ready() -> void:
	rng.randomize()
	_build_ui()
	AudioManager.play_stream(DIAL_TONE_SFX, -14.0)
	_load_content()
	trust_bar.max_value = 100.0
	suspicion_bar.max_value = 100.0
	reputation_bar.max_value = 100.0
	timer_bar.max_value = SessionState.time_left
	last_alert_text = "No active alerts"
	_populate_victims()
	_refresh_ui()


func _process(delta: float) -> void:
	SessionState.time_left = maxf(0.0, SessionState.time_left - delta)
	if call_active and current_call_time_left > 0.0:
		current_call_time_left = maxf(0.0, current_call_time_left - delta)
	if SessionState.time_left <= 0.0 and not prologue_end_transition_started:
		# A call still live when the shift clock expires was never logged at all,
		# so that victim silently vanished from the ledger. Record it as cut off.
		if call_active:
			_end_current_call("The shift clock ran out mid-call.", SessionState.CALL_TIMEOUT)
		_start_prologue_end_transition("Session Time Expired", "The session timer ran out.")
		return
	elif call_active and current_call_time_left <= 0.0 and not current_node.is_empty():
		_end_current_call("Victim hung up after waiting too long.", SessionState.CALL_HUNG_UP)
	_update_timer_display()


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

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 24)
	root.add_child(top_bar)

	calls_value = Label.new()
	top_bar.add_child(calls_value)
	profit_value = Label.new()
	top_bar.add_child(profit_value)
	session_value = Label.new()
	session_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(session_value)
	alerts_value = Label.new()
	alerts_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	alerts_value.clip_text = true
	alerts_value.custom_minimum_size = Vector2(320, 0)
	alerts_value.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_bar.add_child(alerts_value)

	var meters_row := HBoxContainer.new()
	meters_row.add_theme_constant_override("separation", 18)
	root.add_child(meters_row)
	trust_value = Label.new()
	trust_bar = ProgressBar.new()
	meters_row.add_child(_build_meter("Trust", trust_value, trust_bar))
	suspicion_value = Label.new()
	suspicion_bar = ProgressBar.new()
	meters_row.add_child(_build_meter("Suspicion", suspicion_value, suspicion_bar))
	reputation_value = Label.new()
	reputation_bar = ProgressBar.new()
	meters_row.add_child(_build_meter("Reputation", reputation_value, reputation_bar))
	timer_value = Label.new()
	timer_bar = ProgressBar.new()
	meters_row.add_child(_build_meter("Time", timer_value, timer_bar))

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 14)
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_row)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(280, 0)
	left_column.add_theme_constant_override("separation", 8)
	main_row.add_child(left_column)

	var list_label := Label.new()
	list_label.text = "Targets"
	left_column.add_child(list_label)

	victim_list = ItemList.new()
	victim_list.custom_minimum_size = Vector2(0, 120)
	left_column.add_child(victim_list)

	victim_portrait = TextureRect.new()
	victim_portrait.custom_minimum_size = Vector2(0, 110)
	victim_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	victim_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_column.add_child(victim_portrait)

	var profile_panel := PanelContainer.new()
	profile_panel.custom_minimum_size = Vector2(0, 130)
	left_column.add_child(profile_panel)
	profile_value = RichTextLabel.new()
	profile_value.bbcode_enabled = true
	# Grow to fit the traits/angle lines instead of clipping them mid-word.
	# Safe because the whole column sits inside root_scroll.
	profile_value.fit_content = true
	profile_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_panel.add_child(profile_value)

	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 8)
	main_row.add_child(right_column)

	var dialogue_panel := PanelContainer.new()
	dialogue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(dialogue_panel)
	dialogue_value = RichTextLabel.new()
	dialogue_value.bbcode_enabled = true
	dialogue_value.scroll_following = true
	dialogue_value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_panel.add_child(dialogue_value)

	for index in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		button.pressed.connect(_on_choice_pressed.bind(index))
		right_column.add_child(button)
		choice_buttons.append(button)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	root.add_child(bottom_row)

	back_to_menu_button = Button.new()
	back_to_menu_button.text = "Back to Menu"
	back_to_menu_button.custom_minimum_size = Vector2(160, 36)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	bottom_row.add_child(back_to_menu_button)

	end_prologue_button = Button.new()
	end_prologue_button.text = "End Prologue & Investigate"
	end_prologue_button.custom_minimum_size = Vector2(220, 36)
	end_prologue_button.pressed.connect(_on_end_prologue_pressed)
	bottom_row.add_child(end_prologue_button)

	victim_list.item_selected.connect(_on_victim_selected)
	victim_list.item_clicked.connect(_on_victim_clicked)
	victim_list.item_activated.connect(_on_victim_activated)


func _build_meter(title: String, value_label: Label, bar: ProgressBar) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(160, 0)
	var title_label := Label.new()
	title_label.text = title
	column.add_child(title_label)
	column.add_child(value_label)
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	column.add_child(bar)
	return column


func _refresh_ui() -> void:
	calls_value.text = "Calls: %d / %d suggested" % [SessionState.calls_made, SUGGESTED_CALL_TARGET]
	profit_value.text = "Profit: %s" % _format_currency(SessionState.profit)
	_update_alert_display()
	# The meter's own title label already names each stat - repeating it here
	# rendered every meter twice ("Trust" above "Trust: 35").
	trust_value.text = "%d / 100" % SessionState.trust
	trust_bar.value = SessionState.trust
	suspicion_value.text = "%d / 100" % SessionState.suspicion
	suspicion_bar.value = SessionState.suspicion
	reputation_value.text = "%d / 100" % SessionState.reputation
	reputation_bar.value = SessionState.reputation
	_update_timer_display()
	if current_node.is_empty():
		if preview_victim_index >= 0 and preview_victim_index < victims.size():
			var preview_victim: Dictionary = victims[preview_victim_index]
			session_value.text = "Previewing %s" % str(preview_victim.get("name", "Unknown"))
		else:
			session_value.text = "Call center on standby"
	else:
		var victim: Dictionary = victims[current_victim_index]
		session_value.text = "Targeting %s" % str(victim.get("name", "Unknown"))
	_update_dialogue_display()


func _populate_victims() -> void:
	victim_list.clear()
	for victim in victims:
		victim_list.add_item("%s, %d" % [str(victim.get("name", "Unknown")), int(victim.get("age", 0))])
	if victim_list.item_count > 0:
		victim_list.select(0)
		_preview_victim(0)


func _load_content() -> void:
	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open dialogue content: %s" % CONTENT_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Dialogue content is not a dictionary: %s" % CONTENT_PATH)
		return

	var content := parsed as Dictionary
	victims.clear()
	for victim_data in content.get("victims", []):
		if victim_data is Dictionary:
			victims.append(victim_data)
	dialogue_nodes = content.get("dialogue_nodes", {})


func _on_victim_selected(index: int) -> void:
	_preview_victim(index)


func _on_victim_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		_start_call(index)


func _on_victim_activated(index: int) -> void:
	_start_call(index)


func _preview_victim(index: int) -> void:
	if index < 0 or index >= victims.size():
		return
	if not current_node.is_empty():
		return

	preview_victim_index = index
	var victim: Dictionary = victims[index]
	_set_victim_context(victim)
	var portrait_path := str(victim.get("portrait", ""))
	if not portrait_path.is_empty():
		victim_portrait.texture = load(portrait_path)
	transcript_lines.clear()
	transcript_lines.append("Previewing target: %s" % str(victim.get("name", "Unknown")))
	transcript_lines.append("Click the name again to begin the call.")
	call_active = false
	current_node_id = ""
	current_node = {}
	current_prompt_text = ""
	_clear_choices()
	_refresh_ui()


func _start_call(index: int) -> void:
	if index < 0 or index >= victims.size():
		return
	if call_active:
		return

	AudioManager.play_stream(RING_SFX, -10.0)
	current_victim_index = index
	preview_victim_index = index
	call_active = true
	SessionState.calls_made += 1
	var victim: Dictionary = victims[index]
	_set_victim_context(victim)
	current_call_time_limit = _get_victim_patience_seconds(victim)
	current_call_time_left = current_call_time_limit
	var portrait_path := str(victim.get("portrait", ""))
	if not portrait_path.is_empty():
		victim_portrait.texture = load(portrait_path)
	transcript_lines.clear()
	transcript_lines.append("Selected target: %s" % str(victim.get("name", "Unknown")))
	var intro_line := _pick_text(victim.get("intro_variants", victim.get("intro", "Call line ready.")))
	if not intro_line.is_empty():
		transcript_lines.append(intro_line)
	_load_node(str(victim.get("start_node", "")))
	_refresh_ui()


func _load_node(node_id: String) -> void:
	current_node_id = node_id
	current_node = dialogue_nodes.get(node_id, {})
	if current_node.is_empty():
		current_prompt_text = ""
		_end_current_call("Call ended. Select another victim to continue.", SessionState.CALL_ABORTED)
		return

	current_prompt_text = _pick_text(current_node.get("prompt_variants", current_node.get("prompt", "")))

	var choices: Array = current_node.get("choices", [])
	current_choice_indices = []
	for i in range(choices.size()):
		current_choice_indices.append(i)
	current_choice_indices.shuffle()
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		if index < current_choice_indices.size():
			var choice: Dictionary = choices[current_choice_indices[index]]
			button.visible = true
			button.disabled = false
			button.text = str(choice.get("text", "Choice"))
		else:
			button.visible = false
			button.disabled = true
			button.text = ""
	_update_dialogue_display()


func _clear_choices() -> void:
	current_choice_indices.clear()
	for button in choice_buttons:
		button.visible = false
		button.disabled = true
		button.text = ""


func _update_dialogue_display() -> void:
	var text_parts: Array[String] = []
	text_parts.append("[b]Call Transcript[/b]")
	text_parts.append_array(transcript_lines)
	if call_active and not current_prompt_text.is_empty():
		text_parts.append("[i]%s[/i]" % current_prompt_text)
	# The preview prompt is not repeated here - _preview_victim already appends
	# "Click the name again to begin the call." to the transcript.
	dialogue_value.text = "\n\n".join(text_parts)


func _end_current_call(summary_line: String, end_reason: String = SessionState.CALL_REFUSED) -> void:
	# Log who this was before the call state is cleared - the office call floor
	# reads these names back to the player later, and the investigation half
	# reads them to decide how each victim opens.
	#
	# A payout is the fact that matters, so it outranks however the call
	# happened to terminate: if they transferred money and the line was pulled a
	# moment later, they were still robbed. `end_reason` is only recorded when
	# no money changed hands, which is precisely the case the old empty-string
	# outcome could not describe.
	if current_victim_index >= 0 and current_victim_index < victims.size():
		var logged_outcome := current_call_outcome
		if logged_outcome.is_empty():
			logged_outcome = end_reason
		SessionState.record_prologue_call(
			str(victims[current_victim_index].get("name", "")),
			logged_outcome,
			current_call_reward)
	if current_call_reward > 0:
		SessionState.profit += current_call_reward
	SessionState.victims_affected += 1
	if current_call_reward == 0:
		SessionState.record_reflection_milestone("Trust Broken", "The call ended without a payout after trust broke down.")
	if not current_call_consequence_lines.is_empty():
		transcript_lines.append_array(current_call_consequence_lines)
	_maybe_add_perspective_moment()
	current_node_id = ""
	current_node = {}
	current_prompt_text = ""
	call_active = false
	current_victim_index = -1
	preview_victim_index = -1
	current_call_reward = 0
	current_call_outcome = ""
	current_call_consequence_lines.clear()
	current_call_notice_lines.clear()
	current_call_time_left = 0.0
	current_call_time_limit = 0.0
	transcript_lines.append(summary_line)
	_clear_choices()
	if SessionState.prologue_end_reason.is_empty() and SessionState.suspicion >= 100:
		_start_prologue_end_transition("Investigation Escalates", "Police suspicion reached the maximum level.")
		return
	if SessionState.prologue_end_reason.is_empty() and SessionState.time_left <= 0.0:
		_start_prologue_end_transition("Session Time Expired", "The session timer ran out.")
		return
	_update_dialogue_display()


func _on_choice_pressed(choice_index: int) -> void:
	if current_node.is_empty():
		return

	var choices: Array = current_node.get("choices", [])
	if choice_index < 0 or choice_index >= current_choice_indices.size():
		return

	var option: Dictionary = choices[current_choice_indices[choice_index]]
	var trust_change := int(option.get("trust", 0))
	var suspicion_change := int(option.get("suspicion", 0))
	var reputation_change := int(option.get("reputation", 0))
	var alert_text := str(option.get("alert", ""))
	var next_node := str(option.get("next_node", ""))
	var can_pay_out := bool(option.get("success", false))
	var partial_success := bool(option.get("partial_success", false))
	var outcome_label := str(option.get("outcome_label", ""))
	var tactic := str(option.get("tactic", ""))
	var victim := victims[current_victim_index] if current_victim_index >= 0 and current_victim_index < victims.size() else {}
	if not victim.is_empty():
		var tactic_bonus := _get_tactic_bonus(victim, tactic)
		trust_change += tactic_bonus["trust"]
		suspicion_change += tactic_bonus["suspicion"]
	var resistance_trust := 0
	var resistance_suspicion := 0
	var prompt_resistance := _get_resistance_adjustment(current_prompt_text)
	resistance_trust += int(prompt_resistance["trust"])
	resistance_suspicion += int(prompt_resistance["suspicion"])
	var profit_awarded := 0
	current_call_reward = 0
	current_call_outcome = ""
	current_call_consequence_lines.clear()
	current_call_notice_lines.clear()
	var lines: Array[String] = []
	lines.append(_pick_text(option.get("player_line_variants", option.get("player_line", option.get("text", "")))))
	var victim_line := _pick_text(option.get("victim_line_variants", option.get("victim_line", "")))
	if not victim_line.is_empty():
		lines.append(victim_line)
		var resistance := _get_resistance_adjustment(victim_line)
		resistance_trust += int(resistance["trust"])
		resistance_suspicion += int(resistance["suspicion"])
	var node_reaction := _pick_text(current_node.get("reaction_variants", ""))
	if not node_reaction.is_empty():
		lines.append(node_reaction)
		var reaction_resistance := _get_resistance_adjustment(node_reaction)
		resistance_trust += int(reaction_resistance["trust"])
		resistance_suspicion += int(reaction_resistance["suspicion"])
	trust_change += resistance_trust
	suspicion_change += resistance_suspicion
	var system_effects := _get_system_notice_effects(victim)
	trust_change += int(system_effects["trust"])
	suspicion_change += int(system_effects["suspicion"])
	trust_change = _clamp_meter_delta(trust_change, MAX_TRUST_GAIN, MAX_TRUST_LOSS)
	suspicion_change = _clamp_meter_delta(suspicion_change, MAX_SUSPICION_GAIN, MAX_SUSPICION_LOSS)
	var trust_after := clampi(SessionState.trust + trust_change, 0, 100)
	var suspicion_after := clampi(SessionState.suspicion + suspicion_change, 0, 100)
	if current_payout_model == "lottery":
		current_payout_amount = max(current_payout_floor, current_payout_amount - (max(0, trust_change) * 250) + (max(0, suspicion_change) * 120))
		if current_node.is_empty() == false:
			lines.append("The claim amount shifts as the conversation continues.")
	if partial_success:
		profit_awarded = int(option.get("partial_profit", option.get("profit", 0)))
		current_call_reward = profit_awarded
		current_call_outcome = "partial"
		if outcome_label.is_empty():
			outcome_label = "partial transfer"
		var partial_aftermath := _format_consequence_text(_pick_text(option.get("partial_aftermath_variants", [])))
		if not partial_aftermath.is_empty():
			current_call_consequence_lines.append(partial_aftermath)
	elif can_pay_out and next_node.is_empty():
		var success_trust := int(victim.get("success_trust", 55))
		var success_suspicion := int(victim.get("success_suspicion", 65))
		if SessionState.community_alert_active:
			success_trust += 5
		if SessionState.investigation_notice_active:
			success_suspicion -= 5
		if trust_after >= success_trust and suspicion_after <= success_suspicion:
			profit_awarded = int(option.get("profit", 0))
			current_call_reward = profit_awarded
			current_call_outcome = "success"
			if outcome_label.is_empty():
				outcome_label = _get_success_outcome_label()
			var success_aftermath := _format_consequence_text(_pick_text(option.get("success_aftermath_variants", current_node.get("success_aftermath_variants", ""))))
			if not success_aftermath.is_empty():
				current_call_consequence_lines.append(success_aftermath)
	elif next_node.is_empty():
		var failure_aftermath := _format_consequence_text(_pick_text(option.get("failure_aftermath_variants", [])))
		if not failure_aftermath.is_empty():
			current_call_consequence_lines.append(failure_aftermath)
	if current_call_outcome == "success":
		_apply_bank_security_reduction(tactic, lines)
		lines.append("Outcome: %s trust, %s suspicion, %s, %s reputation." % [
			_format_signed(trust_change),
			_format_signed(suspicion_change),
			outcome_label,
			_format_signed(reputation_change),
		])
	elif current_call_outcome == "partial":
		_apply_bank_security_reduction(tactic, lines)
		lines.append("Outcome: %s trust, %s suspicion, %s, %s reputation." % [
			_format_signed(trust_change),
			_format_signed(suspicion_change),
			outcome_label,
			_format_signed(reputation_change),
		])
	else:
		lines.append("Outcome: %s trust, %s suspicion, no payout, %s reputation." % [
			_format_signed(trust_change),
			_format_signed(suspicion_change),
			_format_signed(reputation_change),
		])
	transcript_lines.append("\n".join(lines))
	SessionState.trust = trust_after
	SessionState.suspicion = suspicion_after
	SessionState.reputation = clampi(SessionState.reputation + reputation_change, 0, 100)
	if next_node.is_empty() and current_call_outcome != "success" and suspicion_after >= 45:
		SessionState.reports_filed += 1
		if SessionState.reports_filed == 1:
			SessionState.record_reflection_milestone("First Report Filed", "The first suspicious call crossed the report threshold.")
	_update_system_notices()
	SessionState.alerts = _build_alert_text(alert_text)
	if SessionState.suspicion >= 100:
		_end_current_call("Investigation escalates and the line is shut down.", SessionState.CALL_ESCALATED)
		return
	if next_node.is_empty():
		if current_call_outcome == "success":
			_end_current_call("Call ended after a full transfer.")
		elif current_call_outcome == "partial":
			_end_current_call("Call ended after a partial transfer.")
		else:
			_end_current_call("Call ended with no payout.", SessionState.CALL_REFUSED)
	else:
		_load_node(next_node)
	_refresh_ui()


func _format_currency(amount: int) -> String:
	return "P%d" % amount


func _format_time(seconds_left: float) -> String:
	var total_seconds := int(ceil(seconds_left))
	var minutes := floori(float(total_seconds) / 60.0)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _format_signed(amount: int) -> String:
	return "%+d" % amount


func _pick_text(value: Variant) -> String:
	if value is Array:
		var options: Array = value
		if options.is_empty():
			return ""
		return str(options[rng.randi_range(0, options.size() - 1)])
	return str(value)


func _format_consequence_text(text: String) -> String:
	if text.is_empty():
		return ""
	var victim_name := "The victim"
	if current_victim_index >= 0 and current_victim_index < victims.size():
		victim_name = str(victims[current_victim_index].get("name", "The victim"))
	return text.replace("{victim_name}", victim_name)


func _start_prologue_end_transition(reason: String, note: String) -> void:
	if prologue_end_transition_started:
		return
	prologue_end_transition_started = true
	SessionState.go_to_prologue_end(reason, note)


func _update_timer_display() -> void:
	var session_text := _format_time(SessionState.time_left)
	timer_bar.value = SessionState.time_left
	if call_active and current_call_time_limit > 0.0:
		timer_value.text = "%s  (call %s)" % [session_text, _format_time(current_call_time_left)]
	else:
		timer_value.text = session_text


func _get_victim_patience_seconds(victim: Dictionary) -> float:
	return float(victim.get("patience_seconds", 60.0))


func _build_alert_text(extra_alert: String = "") -> String:
	var alerts: Array[String] = []
	if SessionState.community_alert_active:
		alerts.append("Community Alert Issued")
	if SessionState.bank_security_active:
		alerts.append("Bank Security Alert")
	if SessionState.investigation_notice_active:
		alerts.append("Investigation Notice")
	if not extra_alert.is_empty():
		alerts.append(extra_alert)
	if alerts.is_empty():
		return "No active alerts"
	return " | ".join(alerts)


func _update_alert_display() -> void:
	var current_alert := SessionState.alerts
	if current_alert != "No active alerts" and current_alert != last_alert_text:
		last_alert_text = current_alert
		AudioManager.play_stream(ALERT_SFX, -8.0)
	alerts_value.text = "Alerts: %s" % current_alert


func _append_system_notice(notice_text: String) -> void:
	if notice_text.is_empty():
		return
	transcript_lines.append(notice_text)
	current_call_notice_lines.append(notice_text)


func _update_system_notices() -> void:
	if not SessionState.community_alert_active and (
			SessionState.calls_made >= COMMUNITY_ALERT_CALLS
			or SessionState.suspicion >= COMMUNITY_ALERT_SUSPICION
			or SessionState.reputation <= COMMUNITY_ALERT_REPUTATION):
		SessionState.community_alert_active = true
		_append_system_notice("System Notice: Community Alert Issued. Residents are warning each other about scam calls, and new victims are becoming more skeptical.")
		SessionState.record_reflection_milestone("Community Alert Issued", "Repeated suspicious calls triggered a community warning response.")
	if not SessionState.bank_security_active and (
			SessionState.profit >= BANK_SECURITY_PROFIT
			or SessionState.suspicion >= BANK_SECURITY_SUSPICION):
		SessionState.bank_security_active = true
		_append_system_notice("System Notice: Bank Security Alert. Financial institutions are flagging suspicious transfers, and some payouts are being reduced.")
		SessionState.record_reflection_milestone("Bank Security Triggered", "High suspicion or profit drew bank security checks into the session.")
	if not SessionState.investigation_notice_active and (
			SessionState.reports_filed >= INVESTIGATION_REPORTS
			or SessionState.suspicion >= INVESTIGATION_SUSPICION
			or SessionState.reputation <= INVESTIGATION_REPUTATION):
		SessionState.investigation_notice_active = true
		_append_system_notice("System Notice: Investigation Notice. Law enforcement is tracking scam reports, and suspicion is rising faster.")
		SessionState.record_reflection_milestone("Investigation Escalates", "Reports and suspicion pushed the session toward law enforcement attention.")


func _get_system_notice_effects(_victim: Dictionary) -> Dictionary:
	var effects := {"trust": 0, "suspicion": 0}
	if SessionState.community_alert_active:
		effects["trust"] -= 2
		effects["suspicion"] += 1
	if SessionState.investigation_notice_active:
		effects["suspicion"] += 2
	return effects


func _apply_bank_security_reduction(tactic: String, lines: Array[String]) -> void:
	if not SessionState.bank_security_active:
		return
	if tactic != "bank" and current_payout_model != "lottery":
		return
	if current_call_reward <= 0:
		return

	var reduced_reward := int(round(float(current_call_reward) * 0.5))
	if reduced_reward < current_call_reward:
		current_call_reward = reduced_reward
		lines.append("System Notice: Bank security flags part of the transfer, reducing the payout.")


func _maybe_add_perspective_moment() -> void:
	if current_call_outcome.is_empty():
		return
	if rng.randf() > 0.45:
		return
	if current_victim_index < 0 or current_victim_index >= victims.size():
		return

	var victim: Dictionary = victims[current_victim_index]
	var perspective_data: Dictionary = victim.get("perspective_variants", {})
	if perspective_data.is_empty():
		return

	var outcome_quotes: Variant = perspective_data.get(current_call_outcome, [])
	var quote := _pick_text(outcome_quotes)
	if quote.is_empty():
		return

	var victim_name := str(victim.get("name", "Unknown"))
	var age := int(victim.get("age", 0))
	SessionState.record_reflection_milestone("Voices of the Victims", "A victim perspective line appeared after the call ended.")
	transcript_lines.append("Victim Perspective")
	transcript_lines.append("%s, %d" % [victim_name, age])
	transcript_lines.append("\"%s\"" % quote)


func _get_tactic_bonus(victim: Dictionary, tactic: String) -> Dictionary:
	var preferred_tactic := str(victim.get("preferred_tactic", ""))
	var bonus := {"trust": 0, "suspicion": 0, "profit": 0}
	if tactic.is_empty() or preferred_tactic.is_empty():
		return bonus
	if tactic == preferred_tactic:
		bonus["trust"] = int(round(float(victim.get("tactic_trust_bonus", 4)) * 0.25))
		bonus["suspicion"] = int(round(float(victim.get("tactic_suspicion_bonus", -1)) * 0.5))
		bonus["profit"] = int(victim.get("tactic_profit_bonus", 5))
	elif tactic == "pressure":
		bonus["trust"] = int(round(float(victim.get("pressure_trust_bonus", 1)) * 0.4))
		bonus["suspicion"] = int(round(float(victim.get("pressure_suspicion_bonus", 1)) * 0.5))
	return bonus


func _get_success_outcome_label() -> String:
	if current_payout_model == "lottery":
		return "claim secured"
	return "access secured"


func _get_resistance_adjustment(text: String) -> Dictionary:
	var lower_text := text.to_lower()
	var adjustment := {"trust": 0, "suspicion": 0}
	if lower_text.find("not giving") != -1 \
			or lower_text.find("not comfortable") != -1 \
			or lower_text.find("not convinced") != -1 \
			or lower_text.find("not sure") != -1 \
			or lower_text.find("need proof") != -1 \
			or lower_text.find("need to think") != -1 \
			or lower_text.find("verify") != -1 \
			or lower_text.find("checking") != -1 \
			or lower_text.find("cautious") != -1 \
			or lower_text.find("careful") != -1 \
			or lower_text.find("suspicious") != -1:
		adjustment["trust"] -= 6
		adjustment["suspicion"] += 2
	if lower_text.find("do not trust") != -1 \
			or lower_text.find("don't trust") != -1 \
			or lower_text.find("hang up") != -1 \
			or lower_text.find("not ready") != -1 \
			or lower_text.find("problem") != -1 \
			or lower_text.find("worry") != -1 \
			or lower_text.find("risk") != -1 \
			or lower_text.find("budget") != -1 \
			or lower_text.find("lose") != -1:
		adjustment["trust"] -= 4
		adjustment["suspicion"] += 1
	return adjustment


func _set_victim_context(victim: Dictionary) -> void:
	current_payout_model = str(victim.get("payout_model", "fixed"))
	current_payout_amount = int(victim.get("base_payout", 0))
	current_payout_floor = int(victim.get("payout_floor", 0))
	profile_value.text = _build_profile_text(victim)


func _build_profile_text(victim: Dictionary) -> String:
	var muted: String = TextStyle.COLOR_NARRATION
	var text_lines: Array[String] = []
	text_lines.append("[b]%s[/b]" % str(victim.get("name", "Unknown")))
	text_lines.append("[color=#%s]Age %d - %s[/color]" % [muted, int(victim.get("age", 0)), str(victim.get("occupation", "Unknown"))])
	var traits := str(victim.get("traits", ""))
	if not traits.is_empty():
		text_lines.append("[font_size=12][color=#%s]%s[/color][/font_size]" % [muted, traits])
	var tactic_hint := str(victim.get("best_tactic_hint", ""))
	if not tactic_hint.is_empty():
		text_lines.append("[font_size=12][color=#%s]Likely angle: %s[/color][/font_size]" % [TextStyle.COLOR_TACTIC, tactic_hint])
	return "\n".join(text_lines)


func _clamp_meter_delta(value: int, positive_cap: int, negative_cap: int) -> int:
	if value > positive_cap:
		return positive_cap
	if value < -negative_cap:
		return -negative_cap
	return value


func _on_back_to_menu_pressed() -> void:
	SessionState.go_to_menu()


func _on_end_prologue_pressed() -> void:
	if prologue_end_transition_started:
		return
	if call_active:
		_end_current_call("You wrap up the call to start the investigation.", SessionState.CALL_ABORTED)
	_start_prologue_end_transition("Investigation Begins", "You chose to end the call center session and start investigating.")
