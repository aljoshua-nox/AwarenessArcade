extends Control

## The prologue: the player works a shift on the operation's call floor.
##
## One call is one conversation with one person, driven by that person's own
## script in resources/dialogue/calls/. The only meter is the victim's DOUBT -
## per call, reset every time the line connects, moved by nothing but the line
## the player just chose. Every ending is an authored node that declares what
## it cost (`payout`) and what the victim said about it afterwards
## (`consequence`), so the number the ledger prints and the words the interview
## quotes back are the same fact. Session-level pressure is the shift clock and
## REPORTS: a victim who catches on keeps the number, and three reports pull
## the line.

const TextStyle := preload("res://scripts/systems/text_style.gd")

const CONTENT_PATH := "res://resources/dialogue/call_content.json"
const RING_SFX := "res://assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3"
const REPORT_SFX := "res://assets/audio/sfx/434379__kila_vat__notification-sound-handmade.mp3"
const DIAL_TONE_SFX := "res://assets/audio/sfx/360480__giddster__dial-tone.wav"
const CHOICE_BUTTON_COUNT := 4
# Above this the victim is one bad line from hanging up; at the ceiling they do.
const DOUBT_WARNING := 75
const DOUBT_CEILING := 100
# Matches the interview engine's typewriter so both halves of the game read at
# the same speed. BEAT_PAUSE is the beat between one revealed line and the next.
const TYPE_CHARS_PER_SECOND := 55.0
const BEAT_PAUSE := 0.35

var calls_value: Label
var reports_value: Label
var session_value: Label
var doubt_value: Label
var doubt_bar: ProgressBar
var doubt_warning: Label
var timer_value: Label
var timer_bar: ProgressBar
var victim_list: ItemList
var victim_portrait: TextureRect
var profile_value: RichTextLabel
var dialogue_value: RichTextLabel
var back_to_menu_button: Button
var end_prologue_button: Button
var choice_buttons: Array[Button] = []

# One flat dictionary per victim: the script's `person` block plus its
# `start_node`, `hang_up_node`, `perspective_variants` and `nodes`.
var victims: Array[Dictionary] = []
var preview_victim_index: int = -1
var current_victim_index: int = -1
var current_node_id: String = ""
var current_node: Dictionary = {}
var current_prompt_text: String = ""
var doubt: int = 0
var call_active: bool = false
var current_call_time_left: float = 0.0
var current_call_time_limit: float = 0.0
# Victim indices already called this shift. A script opens on a first contact
# and would not read twice, and a person who hung up on you does not pick up
# again ten minutes later - so a number is worked once.
var called_indices: Dictionary = {}
# The transcript is revealed one line at a time rather than dumped as a block.
# `transcript_lines` is what has already been typed into the box; anything still
# waiting sits in `pending_beats` and is drained by _advance_beats(). The box
# holds the whole call, so each beat types from `revealed_chars` to the end
# instead of retyping the history above it.
var transcript_lines: Array[String] = []
var pending_beats: Array[String] = []
var revealed_chars: int = 0
var beat_tween: Tween
# A shift that ends while the closing beats of a call are still typing waits
# for them: {reason, note} is handed to the summary once the queue drains.
var pending_shift_end: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var prologue_end_transition_started: bool = false
# Tests drive the shift to its end without leaving the scene.
var suppress_scene_change: bool = false


func _ready() -> void:
	rng.randomize()
	_build_ui()
	AudioManager.play_stream(DIAL_TONE_SFX, -14.0)
	_load_content()
	doubt_bar.max_value = float(DOUBT_CEILING)
	timer_bar.max_value = SessionState.time_left
	_populate_victims()
	_refresh_ui()


# Both clocks only run while the player can act. The victim's lines take real
# seconds to type, and a clock that ran through them would make reading speed
# the mechanic - it would reward skipping the very text the call is made of.
func _process(delta: float) -> void:
	if prologue_end_transition_started or not pending_shift_end.is_empty():
		return
	if _is_revealing():
		return
	SessionState.time_left = maxf(0.0, SessionState.time_left - delta)
	if call_active:
		current_call_time_left = maxf(0.0, current_call_time_left - delta)
	if SessionState.time_left <= 0.0:
		# A call still live when the shift clock expires was never logged at all,
		# so that victim silently vanished from the ledger. Record it as cut off.
		if call_active:
			_end_current_call(SessionState.CALL_TIMEOUT, {},
				"The line goes dead mid-sentence. The shift clock has run out, and the floor manager has killed every open call.")
		_schedule_shift_end("Shift Over", "The shift clock ran out.")
		return
	if call_active and current_call_time_left <= 0.0:
		_end_current_call(SessionState.CALL_HUNG_UP, {},
			"The silence on the line goes on a beat too long, and then it is not silence, it is a dial tone. They waited as long as they were going to.")
	_update_timer_display()


# Same contract as the interview: a click or Space drops the rest of the queue
# in at once for anyone who reads faster than the typewriter.
func _unhandled_input(event: InputEvent) -> void:
	if not _is_revealing():
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed:
		skip = true
	elif event.is_action_pressed("ui_accept"):
		skip = true
	if skip:
		_finish_reveal()
		get_viewport().set_input_as_handled()


func _on_dialogue_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _is_revealing():
		_finish_reveal()
		dialogue_value.accept_event()


# --- UI ----------------------------------------------------------------------

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
	reports_value = Label.new()
	top_bar.add_child(reports_value)
	session_value = Label.new()
	session_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(session_value)

	var meters_row := HBoxContainer.new()
	meters_row.add_theme_constant_override("separation", 18)
	root.add_child(meters_row)
	doubt_value = Label.new()
	doubt_bar = ProgressBar.new()
	var doubt_column := _build_meter("Doubt", doubt_value, doubt_bar)
	doubt_column.custom_minimum_size = Vector2(320, 0)
	doubt_warning = Label.new()
	doubt_warning.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_WRONG))
	doubt_warning.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	doubt_warning.add_theme_font_size_override("font_size", 13)
	doubt_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doubt_warning.visible = false
	doubt_column.add_child(doubt_warning)
	meters_row.add_child(doubt_column)
	timer_value = Label.new()
	timer_bar = ProgressBar.new()
	meters_row.add_child(_build_meter("Shift", timer_value, timer_bar))

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 14)
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_row)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(280, 0)
	left_column.add_theme_constant_override("separation", 8)
	main_row.add_child(left_column)

	var list_label := Label.new()
	list_label.text = "The List"
	left_column.add_child(list_label)

	victim_list = ItemList.new()
	# Tall enough for the whole list without scrolling. The cast is expected
	# to grow; the list scrolls past this.
	victim_list.custom_minimum_size = Vector2(0, 176)
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
	# Grow to fit the card's note instead of clipping it mid-word. Safe because
	# the whole column sits inside root_scroll.
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
	# _unhandled_input never sees a click the transcript panel consumed itself,
	# and the box is the natural place to click to hurry a line along.
	dialogue_value.gui_input.connect(_on_dialogue_gui_input)
	dialogue_panel.add_child(dialogue_value)

	for index in range(CHOICE_BUTTON_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	end_prologue_button.text = "End Shift & Investigate"
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
	calls_value.text = "Calls: %d" % SessionState.calls_made
	reports_value.text = "Reports: %d / %d" % [SessionState.reports_filed, SessionState.REPORTS_TO_PULL_LINE]
	_refresh_doubt_display()
	_update_timer_display()
	if call_active:
		session_value.text = "On the line: %s" % str(victims[current_victim_index].get("name", "Unknown"))
	elif preview_victim_index >= 0 and preview_victim_index < victims.size():
		session_value.text = "Card: %s" % str(victims[preview_victim_index].get("name", "Unknown"))
	else:
		session_value.text = "Line open"
	_update_dialogue_display()


# The meter's own title already names the stat, so the value is just the number.
func _refresh_doubt_display() -> void:
	if not call_active:
		doubt_value.text = "-"
		doubt_bar.value = 0.0
		doubt_bar.modulate = Color(1, 1, 1)
		doubt_warning.visible = false
		return
	doubt_value.text = "%d / %d" % [doubt, DOUBT_CEILING]
	doubt_bar.value = float(doubt)
	if doubt >= DOUBT_WARNING:
		doubt_bar.modulate = Color.html(TextStyle.COLOR_WRONG)
		doubt_warning.text = "They are close to hanging up."
		doubt_warning.visible = true
	else:
		doubt_bar.modulate = Color(1, 1, 1)
		doubt_warning.visible = false


func _update_timer_display() -> void:
	var session_text := _format_time(SessionState.time_left)
	timer_bar.value = SessionState.time_left
	if call_active and current_call_time_limit > 0.0:
		timer_value.text = "%s  (patience %s)" % [session_text, _format_time(current_call_time_left)]
	else:
		timer_value.text = session_text


func _populate_victims() -> void:
	victim_list.clear()
	for i in range(victims.size()):
		var row := victim_list.add_item(_row_text(i))
		victim_list.set_item_metadata(row, i)
		if called_indices.has(i):
			victim_list.set_item_disabled(row, true)
	if victim_list.item_count > 0:
		victim_list.select(0)
		_preview_victim(0)


func _row_text(index: int) -> String:
	var victim: Dictionary = victims[index]
	var text := "%s, %d" % [str(victim.get("name", "Unknown")), int(victim.get("age", 0))]
	if called_indices.has(index):
		text += "  - called"
	return text


# The roster names one script file per victim, in list order. Each file is
# shaped like an interview case (a `person` block plus the graph) and is
# flattened here so everything downstream reads one dictionary per victim.
func _load_content() -> void:
	victims.clear()
	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open call roster: %s" % CONTENT_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Call roster is not a dictionary: %s" % CONTENT_PATH)
		return
	for script_path in (parsed as Dictionary).get("calls", []):
		var victim := _load_script(str(script_path))
		if not victim.is_empty():
			victims.append(victim)


func _load_script(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open call script: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Call script is not a dictionary: %s" % path)
		return {}
	var data := parsed as Dictionary
	var victim: Dictionary = (data.get("person", {}) as Dictionary).duplicate()
	victim["script_path"] = path
	victim["start_node"] = str(data.get("start_node", ""))
	victim["hang_up_node"] = str(data.get("hang_up_node", ""))
	victim["perspective_variants"] = data.get("perspective_variants", {})
	victim["nodes"] = data.get("nodes", {})
	return victim


# The list rows happen to line up with `victims` today because every victim is
# listed, but the signals hand out ROW numbers, not indices into the data. The
# evidence list made exactly that assumption and broke the moment it started
# filtering, so these resolve through the row's metadata instead. Free to filter
# or reorder this list later - the cast is expected to grow.
func _victim_index_for_row(row: int) -> int:
	if row < 0 or row >= victim_list.item_count:
		return -1
	return int(victim_list.get_item_metadata(row))


func _row_for_victim_index(index: int) -> int:
	for row in range(victim_list.item_count):
		if int(victim_list.get_item_metadata(row)) == index:
			return row
	return -1


func _on_victim_selected(row: int) -> void:
	_preview_victim(_victim_index_for_row(row))


func _on_victim_clicked(row: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		_start_call(_victim_index_for_row(row))


func _on_victim_activated(row: int) -> void:
	_start_call(_victim_index_for_row(row))


func _preview_victim(index: int) -> void:
	if index < 0 or index >= victims.size():
		return
	if call_active:
		return

	preview_victim_index = index
	var victim: Dictionary = victims[index]
	_show_card(victim)
	current_node_id = ""
	current_node = {}
	current_prompt_text = ""
	_reset_transcript()
	if called_indices.has(index):
		_queue_beats([TextStyle.system(TextStyle.MARK_SCENE,
			"%s has been worked this shift. The number stays on the list." % str(victim.get("name", "Unknown")),
			TextStyle.COLOR_NARRATION)])
	else:
		_queue_beats([TextStyle.system(TextStyle.MARK_SCENE,
			"Card for %s. Click the name again to dial." % str(victim.get("name", "Unknown")),
			TextStyle.COLOR_NARRATION)])
	_sync_choice_buttons()
	_refresh_ui()


func _show_card(victim: Dictionary) -> void:
	var portrait_path := str(victim.get("portrait", ""))
	if not portrait_path.is_empty():
		victim_portrait.texture = load(portrait_path)
	profile_value.text = _build_profile_text(victim)


func _build_profile_text(victim: Dictionary) -> String:
	var muted: String = TextStyle.COLOR_NARRATION
	var text_lines: Array[String] = []
	text_lines.append("[b]%s[/b]" % str(victim.get("name", "Unknown")))
	text_lines.append("[color=#%s]Age %d - %s[/color]" % [muted, int(victim.get("age", 0)), str(victim.get("occupation", "Unknown"))])
	var traits := str(victim.get("traits", ""))
	if not traits.is_empty():
		text_lines.append("[font_size=12][color=#%s]%s[/color][/font_size]" % [muted, traits])
	var script_name := str(victim.get("script", ""))
	if not script_name.is_empty():
		text_lines.append("[font_size=12][color=#%s]Script: %s[/color][/font_size]" % [TextStyle.COLOR_TACTIC, script_name])
	return "\n".join(text_lines)


# --- The call ----------------------------------------------------------------

func _start_call(index: int) -> void:
	if index < 0 or index >= victims.size():
		return
	if call_active or called_indices.has(index):
		return
	if prologue_end_transition_started or not pending_shift_end.is_empty():
		return

	AudioManager.play_stream(RING_SFX, -10.0)
	current_victim_index = index
	preview_victim_index = index
	call_active = true
	SessionState.calls_made += 1
	var victim: Dictionary = victims[index]
	doubt = clampi(int(victim.get("doubt_start", 20)), 0, DOUBT_CEILING)
	current_call_time_limit = float(victim.get("patience_seconds", 60.0))
	current_call_time_left = current_call_time_limit
	_show_card(victim)
	_reset_transcript()
	_queue_beats([TextStyle.system(TextStyle.MARK_DIALING,
		"%s - %d, %s" % [str(victim.get("name", "Unknown")), int(victim.get("age", 0)), str(victim.get("occupation", "")).to_lower()],
		TextStyle.COLOR_HINT)])
	_load_node(str(victim.get("start_node", "")))
	_refresh_ui()


func _current_nodes() -> Dictionary:
	if current_victim_index < 0 or current_victim_index >= victims.size():
		return {}
	return victims[current_victim_index].get("nodes", {})


# Three kinds of node. A `doubt_check` branches on the meter and is never shown.
# An `outcome` node is an ending: its prompt is the last thing said, and the
# call closes on it. Anything else is a line the player answers.
func _load_node(node_id: String) -> void:
	var node: Dictionary = _current_nodes().get(node_id, {})
	if node.is_empty():
		push_error("Call script has no node '%s'" % node_id)
		_end_current_call(SessionState.CALL_ABORTED, {}, "The script runs out. You put the phone down.")
		return

	var doubt_check: Dictionary = node.get("doubt_check", {})
	if not doubt_check.is_empty():
		var calm := doubt <= int(doubt_check.get("max_doubt", DOUBT_CEILING))
		_load_node(str(doubt_check.get("next_if_calm", "")) if calm else str(doubt_check.get("next_if_wary", "")))
		return

	current_node_id = node_id
	current_node = node
	current_prompt_text = str(node.get("prompt", ""))
	if not current_prompt_text.is_empty():
		_queue_beats([TextStyle.dialogue(current_prompt_text)])

	var outcome := str(node.get("outcome", ""))
	if not outcome.is_empty():
		_end_current_call(outcome, node)
		return
	_sync_choice_buttons()
	_update_dialogue_display()


func _on_choice_pressed(choice_index: int) -> void:
	if not call_active or current_node.is_empty():
		return
	var choices: Array = current_node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]

	# The player's line, then the tactic it was, named - the same amber the
	# interview uses when the detective names it from the other side.
	var beats: Array[String] = [TextStyle.dialogue("You: \"%s\"" % str(choice.get("text", "")))]
	var tactic_id := str(choice.get("tactic_id", ""))
	if not tactic_id.is_empty():
		SessionState.record_tactic_used(tactic_id)
		beats.append(TextStyle.system(TextStyle.MARK_TACTIC_USED, _tactic_name(tactic_id), TextStyle.COLOR_TACTIC))
	_queue_beats(beats)

	doubt = clampi(doubt + int(choice.get("doubt", 0)), 0, DOUBT_CEILING)
	_refresh_doubt_display()
	current_node = {}
	_sync_choice_buttons()
	if doubt >= DOUBT_CEILING:
		_load_node(str(victims[current_victim_index].get("hang_up_node", "")))
	else:
		_load_node(str(choice.get("next", "")))
	_refresh_ui()


# Close the call and write it down. `ending` is the authored node when the call
# ended on one, and carries the payout, the consequence and whether the victim
# reported the number; `closing_line` is narration for the endings the engine
# forces (the patience clock, the shift clock, the end-shift button).
#
# A payout is the fact that matters about a victim, so it is what the ledger and
# the interview key off; the outcome is how the call happened to end.
func _end_current_call(outcome: String, ending: Dictionary = {}, closing_line: String = "") -> void:
	var victim: Dictionary = {}
	if current_victim_index >= 0 and current_victim_index < victims.size():
		victim = victims[current_victim_index]
	var payout := int(ending.get("payout", 0))
	var consequence := _pick_consequence_line(victim, outcome, ending)
	var reported := bool(ending.get("reports", false))

	if not victim.is_empty():
		SessionState.record_prologue_call(
			str(victim.get("person_id", "")),
			str(victim.get("name", "")),
			outcome,
			payout,
			consequence)
		called_indices[current_victim_index] = true
		var row := _row_for_victim_index(current_victim_index)
		if row >= 0:
			victim_list.set_item_text(row, _row_text(current_victim_index))
			victim_list.set_item_disabled(row, true)
	if payout > 0:
		SessionState.profit += payout
	if not victim.is_empty():
		SessionState.victims_affected += 1
	if reported:
		SessionState.reports_filed += 1
		AudioManager.play_stream(REPORT_SFX, -8.0)
		SessionState.record_reflection_milestone("First Report Filed",
			"Someone you called kept the number and passed it on.")

	var beats: Array[String] = []
	if not closing_line.is_empty():
		beats.append(TextStyle.dialogue(closing_line))
	beats.append(_call_ended_line(outcome, payout))
	if reported:
		beats.append(TextStyle.system(TextStyle.MARK_REPORTED,
			"Reports on this line: %d of %d." % [SessionState.reports_filed, SessionState.REPORTS_TO_PULL_LINE],
			TextStyle.COLOR_WRONG))
	beats.append_array(_consequence_beats(victim, consequence))
	_queue_beats(beats)

	current_node_id = ""
	current_node = {}
	current_prompt_text = ""
	call_active = false
	current_victim_index = -1
	current_call_time_left = 0.0
	current_call_time_limit = 0.0
	_sync_choice_buttons()

	if SessionState.reports_filed >= SessionState.REPORTS_TO_PULL_LINE:
		SessionState.record_reflection_milestone("Line Pulled",
			"Enough of the people you called reported the number that the floor took the line away.")
		_schedule_shift_end("Line Pulled",
			"Three of the numbers you worked reported the call. The floor manager pulls your line and hands the list to someone else.")
	_refresh_ui()


func _call_ended_line(outcome: String, payout: int) -> String:
	var body := ""
	var tone: String = TextStyle.COLOR_HINT
	match outcome:
		SessionState.CALL_SUCCESS:
			body = "Transferred %s." % _format_currency(payout)
			tone = TextStyle.COLOR_WRONG
		SessionState.CALL_PARTIAL:
			body = "Partial transfer, %s." % _format_currency(payout)
			tone = TextStyle.COLOR_WRONG
		SessionState.CALL_REFUSED:
			body = "No payout. They said no."
			tone = TextStyle.COLOR_TACTIC
		SessionState.CALL_HUNG_UP:
			body = "No payout. They hung up."
			tone = TextStyle.COLOR_TACTIC
		SessionState.CALL_ABORTED:
			body = "No payout. You dropped the call."
		SessionState.CALL_TIMEOUT:
			body = "No payout. The shift ended mid-call."
		_:
			body = "The line was pulled."
	return TextStyle.system(TextStyle.MARK_CALL_ENDED, body, tone)


# What this call cost the person on the other end, in their own words. The
# ending the call reached is the most specific source - it was written for
# exactly this route - and the victim's `perspective_variants` cover the
# endings the engine forces: the most specific line the writer left for this
# exact outcome, else the one for what the call did to them.
func _pick_consequence_line(victim: Dictionary, outcome: String, ending: Dictionary = {}) -> String:
	if victim.is_empty() or outcome.is_empty():
		return ""
	var authored := _pick_text(ending.get("consequence", ""))
	if not authored.is_empty():
		return authored
	var perspective_data: Dictionary = victim.get("perspective_variants", {})
	if perspective_data.is_empty():
		return ""
	for key in [outcome, SessionState.disposition_for_outcome(outcome)]:
		var quote := _pick_text(perspective_data.get(key, []))
		if not quote.is_empty():
			return quote
	return ""


# Deliberately not a random chance. The project's guardrail is that scam
# success must never read as pure power fantasy, and a harm beat that only
# fired on some calls let the player bank a payout with no cost shown at all.
func _consequence_beats(victim: Dictionary, quote: String) -> Array[String]:
	if victim.is_empty() or quote.is_empty():
		return []
	SessionState.record_reflection_milestone("Voices of the Victims",
		"Every call ends with what it cost the person on the other end.")
	return [
		TextStyle.system(TextStyle.MARK_AFTERMATH,
			"%s, %d" % [str(victim.get("name", "Unknown")), int(victim.get("age", 0))],
			TextStyle.COLOR_NARRATION),
		TextStyle.dialogue("\"%s\"" % quote),
	]


func _tactic_name(tactic_id: String) -> String:
	for entry in TacticNotebook.tactics:
		if str(entry.get("id", "")) == tactic_id:
			return str(entry.get("name", tactic_id))
	return tactic_id


# --- Choices -----------------------------------------------------------------

# The buttons are the gate on the reveal: you cannot answer a line that has not
# finished arriving. A disabled Button still swallows mouse input, which would
# eat the click-to-skip, so it stops accepting the mouse while it is grayed out.
func _sync_choice_buttons() -> void:
	var revealing := _is_revealing()
	var choices: Array = current_node.get("choices", [])
	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]
		if call_active and index < choices.size():
			var choice: Dictionary = choices[index]
			button.visible = true
			button.disabled = revealing
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE if revealing else Control.MOUSE_FILTER_STOP
			button.text = str(choice.get("text", "Choice"))
		else:
			button.visible = false
			button.disabled = true
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.text = ""


# --- Transcript reveal -------------------------------------------------------

func _build_dialogue_text() -> String:
	var text_parts: Array[String] = []
	text_parts.append("[b]Call Transcript[/b]")
	text_parts.append_array(transcript_lines)
	return "\n\n".join(text_parts)


func _is_typing() -> bool:
	return beat_tween != null and beat_tween.is_running()


func _is_revealing() -> bool:
	return _is_typing() or not pending_beats.is_empty()


func _queue_beats(beats: Array) -> void:
	for beat in beats:
		var trimmed := str(beat).strip_edges()
		if not trimmed.is_empty():
			pending_beats.append(trimmed)
	if not _is_typing():
		_advance_beats()


func _update_dialogue_display() -> void:
	# The pump owns the box while a beat is in flight - re-rendering mid-tween
	# would restart the line. _refresh_ui() calls this on every state change.
	if _is_typing():
		return
	_advance_beats()


func _advance_beats() -> void:
	if not pending_beats.is_empty():
		_rebase_read_mark()
		transcript_lines.append(pending_beats.pop_front())
	_render_and_reveal()


# The read mark can only ever be at or below what is on screen. A new call
# empties the box, so the mark has to come back down with it or the next beat
# would be measured against characters that no longer exist and never type.
func _rebase_read_mark() -> void:
	dialogue_value.text = _build_dialogue_text()
	revealed_chars = mini(revealed_chars, dialogue_value.get_total_character_count())


func _render_and_reveal() -> void:
	var new_text := _build_dialogue_text()
	if new_text != dialogue_value.text:
		dialogue_value.text = new_text
	var total := dialogue_value.get_total_character_count()
	if total <= revealed_chars:
		revealed_chars = total
		dialogue_value.visible_characters = total
		# Never strand the queue on a beat that added nothing: the buttons are
		# gated on the reveal finishing, so a stall here is a softlock.
		if not pending_beats.is_empty():
			_advance_beats()
			return
		_on_queue_drained()
		return
	dialogue_value.visible_characters = revealed_chars
	beat_tween = create_tween()
	beat_tween.tween_property(dialogue_value, "visible_characters", total,
		float(total - revealed_chars) / TYPE_CHARS_PER_SECOND)
	beat_tween.tween_interval(BEAT_PAUSE)
	beat_tween.tween_callback(_on_beat_revealed)
	_sync_choice_buttons()


func _on_beat_revealed() -> void:
	# A tween still reports is_running() from inside its own final callback, so
	# drop the reference first - otherwise the last beat of a reply would leave
	# the choice buttons grayed out with nothing left to wait for.
	beat_tween = null
	revealed_chars = dialogue_value.get_total_character_count()
	dialogue_value.visible_characters = revealed_chars
	if pending_beats.is_empty():
		_on_queue_drained()
		return
	_advance_beats()


func _finish_reveal() -> void:
	if beat_tween != null:
		beat_tween.kill()
		beat_tween = null
	while not pending_beats.is_empty():
		transcript_lines.append(pending_beats.pop_front())
	dialogue_value.text = _build_dialogue_text()
	revealed_chars = dialogue_value.get_total_character_count()
	dialogue_value.visible_characters = revealed_chars
	_on_queue_drained()


# Everything queued has been read. The buttons open, and a shift end that was
# waiting on the closing beats of the last call goes through.
func _on_queue_drained() -> void:
	_sync_choice_buttons()
	if not pending_shift_end.is_empty():
		var reason := str(pending_shift_end.get("reason", ""))
		var note := str(pending_shift_end.get("note", ""))
		pending_shift_end = {}
		_start_prologue_end_transition(reason, note)


# A new call starts a new transcript. The header is counted as already revealed
# so it does not retype itself every time the player picks a target.
func _reset_transcript() -> void:
	if beat_tween != null:
		beat_tween.kill()
		beat_tween = null
	pending_beats.clear()
	transcript_lines.clear()
	dialogue_value.text = _build_dialogue_text()
	revealed_chars = dialogue_value.get_total_character_count()
	dialogue_value.visible_characters = revealed_chars


# --- Shift end ----------------------------------------------------------------

func _schedule_shift_end(reason: String, note: String) -> void:
	if prologue_end_transition_started or not pending_shift_end.is_empty():
		return
	pending_shift_end = {"reason": reason, "note": note}
	_sync_choice_buttons()
	if not _is_revealing():
		_on_queue_drained()


func _start_prologue_end_transition(reason: String, note: String) -> void:
	if prologue_end_transition_started:
		return
	prologue_end_transition_started = true
	if suppress_scene_change:
		SessionState.prologue_end_reason = reason
		SessionState.prologue_end_note = note
		return
	SessionState.go_to_prologue_end(reason, note)


func _on_back_to_menu_pressed() -> void:
	SessionState.go_to_menu()


func _on_end_prologue_pressed() -> void:
	if prologue_end_transition_started:
		return
	if call_active:
		_end_current_call(SessionState.CALL_ABORTED, {}, "You put the phone down mid-sentence and log off.")
	_start_prologue_end_transition("Shift Ended Early",
		"You logged off the floor to see what the calls left behind.")


# --- Helpers ------------------------------------------------------------------

func _format_currency(amount: int) -> String:
	return TextStyle.currency(amount)


func _format_time(seconds_left: float) -> String:
	var total_seconds := int(ceil(seconds_left))
	var minutes := floori(float(total_seconds) / 60.0)
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _pick_text(value: Variant) -> String:
	if value is Array:
		var options: Array = value
		if options.is_empty():
			return ""
		return str(options[rng.randi_range(0, options.size() - 1)])
	return str(value)
