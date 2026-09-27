extends Control

## Spot the Scam (the Scam Check, scam_check, in the code and older notes): an
## opt-in quiz on the main menu that measures whether the game improves scam
## recognition. One set of eight messages before the game,
## the other set after an ending, and nothing about the answers is shown until
## both are in - then the two tries sit side by side, pair by pair.
##
## Pages, one at a time in the same panel: home (the check's status, past
## checks, copy and clear), intro, message, saved (the before check is done)
## and results. A closing screen opens it straight at the after intro
## (SessionState.scam_check_entry).

const TextStyle := preload("res://scripts/systems/text_style.gd")
const ScamCheckData := preload("res://scripts/scam_check/scam_check_data.gd")

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const ENDING_SCENE := "res://scenes/investigation/investigation_end.tscn"
const BACKGROUND := "res://assets/art/backgrounds/copernico-p_kICQCOM4s-unsplash.jpg"

const MODE_BEFORE := "before"
const MODE_AFTER := "after"

const PAGE_HOME := "home"
const PAGE_INTRO := "intro"
const PAGE_MESSAGE := "message"
const PAGE_SAVED := "saved"
const PAGE_RESULTS := "results"

const KIND_LABELS := {"text": "TEXT MESSAGE", "chat": "CHAT", "call": "PHONE CALL"}
const BODY_SIZE := 19
const MESSAGE_SIZE := 21
const QUESTION_SIZE := 22

var data: ScamCheckData
var came_from_ending := false
var page := ""

var title_label: Label
var subtitle_label: Label
var body_scroll: ScrollContainer
var body: VBoxContainer
var footer: HBoxContainer
var notice: Label

# The run in progress.
var mode := ""
var set_id := ""
var run_items: Array[Dictionary] = []
var item_index := 0
var answers: Array[Dictionary] = []
# The flag options as shown: display slot -> the option's index in the file.
var flag_order: Array[int] = []
var asking_flag := false
# The check the results page is showing.
var shown_check: Dictionary = {}


func _ready() -> void:
	data = ScamCheckData.new()
	came_from_ending = SessionState.scam_check_entry == SessionState.SCAM_CHECK_FROM_ENDING
	SessionState.scam_check_entry = ""
	AudioManager.stop_ambience()
	# From the menu the menu's music carries on; from an ending, the ending's.
	if not came_from_ending:
		AudioManager.play_music("menu", -12.0)
	_build_ui()
	if came_from_ending and data.has_open_check():
		show_intro(MODE_AFTER)
	else:
		show_home()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# No Esc out of a message: a stray key would throw away the answers so far.
	if page == PAGE_MESSAGE:
		return
	get_viewport().set_input_as_handled()
	if page == PAGE_HOME:
		_leave()
	elif page == PAGE_INTRO:
		_back_from_intro()
	elif page == PAGE_RESULTS and not came_from_ending:
		show_home()


func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = load(BACKGROUND)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		root_margin.add_theme_constant_override(side, 16)
	add_child(root_margin)

	var centring_row := HBoxContainer.new()
	root_margin.add_child(centring_row)
	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centring_row.add_child(left_spacer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 0)
	centring_row.add_child(panel)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centring_row.add_child(right_spacer)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	column.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	column.add_child(subtitle_label)

	# Everything a page says scrolls; its buttons stay put below it.
	body_scroll = ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(body_scroll)

	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 14)
	body_scroll.add_child(gutter)

	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	gutter.add_child(body)

	notice = Label.new()
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_HINT))
	notice.visible = false
	column.add_child(notice)

	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)


# --- Building blocks -----------------------------------------------------------

func _start_page(name: String, title: String, subtitle: String = "") -> void:
	page = name
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	notice.visible = false
	notice.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_HINT))
	for box in [body, footer]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	body_scroll.scroll_vertical = 0


func _text(bbcode: String, size: int = BODY_SIZE) -> RichTextLabel:
	var label := RichTextLabel.new()
	# Text with no box of its own - the panel around it is the box.
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.bbcode_enabled = true
	# fit_content inside the page's ScrollContainer, so nothing is clipped.
	label.fit_content = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		label.add_theme_font_size_override(key, size)
	label.text = bbcode
	return label


func _card(parent: Control, accent: String = "") -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# In the tree first: until then the theme's Card style is not what answers.
	parent.add_child(card)
	if not accent.is_empty():
		var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		style.border_color = Color.html(accent)
		card.add_theme_stylebox_override("panel", style)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)
	return inner


func _button(text: String, action: Callable, width: int = 220, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 46)
	button.pressed.connect(action)
	(footer if parent == null else parent).add_child(button)
	return button


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row


static func _color(text: String, color: String) -> String:
	return "[color=#%s]%s[/color]" % [color, text]


static func _mono(text: String, color: String) -> String:
	return "[font=%s][color=#%s]%s[/color][/font]" % [TextStyle.FONT_SYSTEM, color, text]


# The message itself: who it is from, then each line - the other person's in
# speech color, the player's own marked "You:", a picture as a caption.
func message_text(entry: Dictionary) -> String:
	var kind := str(entry.get("kind", "text"))
	var lines: Array[String] = []
	lines.append("%s  %s" % [_mono(str(KIND_LABELS.get(kind, "MESSAGE")), TextStyle.COLOR_NARRATION),
		_color(str(entry.get("source", "")), TextStyle.COLOR_NARRATION)])
	for line in entry.get("lines", []):
		if line.has("attachment"):
			lines.append(_color("[i](Sent a picture: %s)[/i]" % str(line.get("attachment", "")), TextStyle.COLOR_NARRATION))
			continue
		var text := _expand(str(line.get("text", "")))
		match str(line.get("from", "them")):
			"you":
				lines.append("%s %s" % [_color("You:", TextStyle.COLOR_NARRATION), _color(text, TextStyle.COLOR_SPEECH)])
			"note":
				lines.append(_color("[i]%s[/i]" % text, TextStyle.COLOR_NARRATION))
			_:
				if kind == "call":
					text = "\"%s\"" % text
				lines.append(_color(text, TextStyle.COLOR_SPEECH))
	return "\n\n".join(lines)


# A link is drawn, never written out: a made-up address could be a real one.
static func _expand(text: String) -> String:
	return text.replace("{link}", "[u][color=#%s]link[/color][/u]" % TextStyle.COLOR_HINT)


func _situation_text(entry: Dictionary) -> String:
	return _color("[i]%s[/i]" % str(entry.get("situation", "")), TextStyle.COLOR_NARRATION)


# --- Home ------------------------------------------------------------------------

func show_home() -> void:
	_start_page(PAGE_HOME, "Spot the Scam", "A short before-and-after check of how well you spot scams")
	body.add_child(_text("Before you play, you judge 8 messages: texts, chats and phone calls. "
		+ "After you finish the game, you judge 8 different ones. You won't see any answers until "
		+ "the end, when your two tries are shown side by side."))
	body.add_child(_text(_color("Your answers stay on this computer, with no names. The messages are "
		+ "made up for this check.", TextStyle.COLOR_NARRATION), 17))

	var open := data.open_check()
	var status_box := _card(body, TextStyle.COLOR_TACTIC if not open.is_empty() else "")
	if open.is_empty():
		status_box.add_child(_text("No check is waiting."))
		_button("Take the Before Check", show_intro.bind(MODE_BEFORE), 260, _row(status_box))
	else:
		var played := _played_line(open)
		status_box.add_child(_text("[b]Check %d is waiting for its after check.[/b]\nBefore check taken %s.%s" % [
			int(open.get("number", 0)), str(open.get("before_done", "")),
			"" if played.is_empty() else "\n" + played]))
		var actions := _row(status_box)
		_button("Take the After Check", show_intro.bind(MODE_AFTER), 260, actions)
		var fresh := _button("Start a New Check", show_intro.bind(MODE_BEFORE), 240, actions)
		fresh.tooltip_text = "For a different player. The waiting check is kept as unfinished."

	var all := data.checks()
	if not all.is_empty():
		body.add_child(_text("[b]Past checks[/b]"))
		for check in all:
			if check == open:
				continue
			var line := "Check %d  -  %s  -  " % [int(check.get("number", 0)), str(check.get("before_done", "")).get_slice(" ", 0)]
			var button := Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0, 40)
			if ScamCheckData.is_complete(check):
				var before := data.score(check.get("before", []))
				var after := data.score(check.get("after", []))
				button.text = line + "right answers %d of %d before, %d of %d after" % [
					int(before.right), int(before.answered), int(after.right), int(after.answered)]
				button.pressed.connect(show_results.bind(int(check.get("number", 0))))
			else:
				button.text = line + ScamCheckData.status(check)
				button.disabled = true
			body.add_child(button)
		body.add_child(_text(_color("Saved at %s" % ProjectSettings.globalize_path(data.record_path),
			TextStyle.COLOR_NARRATION), 15))

	var copy := _button("Copy Results", _copy_results, 200)
	copy.disabled = all.is_empty()
	copy.tooltip_text = "One row per check, ready to paste into a spreadsheet."
	var clear := _button("Clear Record", _ask_to_clear, 200)
	clear.disabled = all.is_empty()
	_button("Back", _leave, 160)


func _played_line(check: Dictionary) -> String:
	var parts: Array[String] = []
	match str(check.get("route", "")):
		ScamCheckData.ROUTE_PROLOGUE:
			parts.append("played from the start")
		ScamCheckData.ROUTE_SKIP:
			parts.append("skipped to the investigation")
		ScamCheckData.ROUTE_BOTH:
			parts.append("played from the start and skipped")
	var endings: Array = check.get("endings", [])
	if not endings.is_empty():
		var titles: Array[String] = []
		for id in endings:
			titles.append(SessionState.ending_title(str(id)))
		parts.append("reached %s" % ", ".join(titles))
	if parts.is_empty():
		return ""
	return "Since then: %s." % "; ".join(parts)


func _copy_results() -> void:
	DisplayServer.clipboard_set(data.csv_text())
	var count := data.checks().size()
	notice.text = "Copied %d check%s. Paste into a spreadsheet." % [count, "" if count == 1 else "s"]
	notice.visible = true


# Clearing forgets every check. The one question this page asks.
func _ask_to_clear() -> void:
	for child in footer.get_children():
		footer.remove_child(child)
		child.queue_free()
	notice.text = "This forgets every check on this computer. It cannot be undone."
	notice.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_WRONG))
	notice.visible = true
	_button("Clear the Record", _clear_record, 200)
	_button("Keep It", show_home, 160)


func _clear_record() -> void:
	data.clear()
	show_home()


func _leave() -> void:
	if came_from_ending:
		SessionState.go_to_scene(ENDING_SCENE)
	else:
		SessionState.go_to_menu()


# --- Intro -----------------------------------------------------------------------

func show_intro(which: String) -> void:
	mode = which
	if mode == MODE_BEFORE:
		_start_page(PAGE_INTRO, "Before You Play", "8 messages")
		body.add_child(_text("You'll see 8 messages: texts, chats and phone calls. Some are scams and some are real. For each one, decide "
			+ "if it's a scam or legit. If you say it's a scam, pick what gave it away."))
		body.add_child(_text("Take your time. There's no timer. Once you move on to the next message, "
			+ "you can't go back to the one before."))
		body.add_child(_text("You won't see any answers yet. They come at the end, next to your answers "
			+ "from after the game."))
		if data.has_open_check():
			body.add_child(_text(_color("The check that's waiting will be kept as unfinished.", TextStyle.COLOR_TACTIC)))
	else:
		_start_page(PAGE_INTRO, "After the Game", "8 new messages")
		body.add_child(_text("These 8 messages are different from the ones before the game. Some are scams and some are real. Same as "
			+ "before: decide if each one is a scam or legit, and if it's a scam, pick what gave it away."))
		body.add_child(_text("Your results come right after, side by side with your answers from before."))
	body.add_child(_text(_color("These messages are made up for this check. Don't call, text or open "
		+ "anything in them.", TextStyle.COLOR_NARRATION), 17))
	_button("Begin", _begin, 200)
	_button("Not Now" if mode == MODE_AFTER else "Back", _back_from_intro, 160)


func _back_from_intro() -> void:
	if came_from_ending and mode == MODE_AFTER:
		SessionState.go_to_scene(ENDING_SCENE)
	else:
		show_home()


func _begin() -> void:
	if mode == MODE_BEFORE:
		set_id = data.next_first_set()
	else:
		var open := data.open_check()
		if open.is_empty():
			show_home()
			return
		set_id = ScamCheckData.other_set(str(open.get("first_set", ScamCheckData.SETS[0])))
	run_items = data.items_in(set_id)
	item_index = 0
	answers.clear()
	show_message()


# --- A message -------------------------------------------------------------------

func show_message() -> void:
	asking_flag = false
	var entry := run_items[item_index]
	var heading := "Before the Game" if mode == MODE_BEFORE else "After the Game"
	_start_page(PAGE_MESSAGE, heading, "Message %d of %d" % [item_index + 1, run_items.size()])
	body.add_child(_text(_situation_text(entry)))
	var card := _card(body)
	card.add_child(_text(message_text(entry), MESSAGE_SIZE))
	body.add_child(_text("[b]Is this a scam?[/b]", QUESTION_SIZE))
	_choice_button("It's a scam", _answer_call.bind(ScamCheckData.CALL_SCAM), 260)
	_choice_button("It's legit", _answer_call.bind(ScamCheckData.CALL_LEGIT), 260)


# No keyboard focus on an answer: the theme draws focus like hover, and a
# clicked slot would stay lit on the next message.
func _choice_button(text: String, action: Callable, width: int, parent: Control = null) -> Button:
	var button := _button(text, action, width, parent)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 19)
	return button


func _answer_call(call: String) -> void:
	if call == ScamCheckData.CALL_LEGIT:
		_record_answer(call, -1)
		return
	_ask_flag()


# Asked whenever the player says "scam" - on a legit message too - so being
# asked gives nothing away.
func _ask_flag() -> void:
	asking_flag = true
	var entry := run_items[item_index]
	# Drop the "Is this a scam?" line and its buttons; the message stays up.
	var question := body.get_child(body.get_child_count() - 1)
	body.remove_child(question)
	question.queue_free()
	for child in footer.get_children():
		footer.remove_child(child)
		child.queue_free()
	body.add_child(_text("[b]What gave it away?[/b]", QUESTION_SIZE))
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	body.add_child(options)
	flag_order.clear()
	for i in range((entry.get("flags", []) as Array).size()):
		flag_order.append(i)
	# Shuffled, so the first slot is never a pattern.
	flag_order.shuffle()
	var flags: Array = entry.get("flags", [])
	for slot in range(flag_order.size()):
		var option := _choice_button(str(flags[flag_order[slot]].get("text", "")),
			_answer_flag.bind(slot), 0, options)
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var change := Button.new()
	change.text = "Change my answer"
	change.flat = true
	change.focus_mode = Control.FOCUS_NONE
	change.pressed.connect(show_message)
	footer.add_child(change)
	# The options sit below the message; bring them into view.
	await get_tree().process_frame
	if is_instance_valid(body_scroll):
		body_scroll.scroll_vertical = int(body_scroll.get_v_scroll_bar().max_value)


func _answer_flag(slot: int) -> void:
	_record_answer(ScamCheckData.CALL_SCAM, flag_order[slot])


func _record_answer(call: String, flag: int) -> void:
	answers.append({"item": str(run_items[item_index].get("id", "")), "call": call, "flag": flag})
	item_index += 1
	if item_index < run_items.size():
		show_message()
	elif mode == MODE_BEFORE:
		data.save_before(set_id, answers)
		show_saved()
	else:
		var check := data.save_after(answers)
		show_results(int(check.get("number", 0)))


# --- Saved -----------------------------------------------------------------------

func show_saved() -> void:
	_start_page(PAGE_SAVED, "Saved", "The before check is done")
	body.add_child(_text("Your answers are saved on this computer. You'll see them at the end, next "
		+ "to your answers from after the game."))
	body.add_child(_text("Now play the game from the main menu: Start, or Skip to Investigation. When you "
		+ "reach an ending, the ending screen offers the after check. You can also take it any time "
		+ "from Spot the Scam on the main menu."))
	_button("Main Menu", SessionState.go_to_menu, 200)


# --- Results ---------------------------------------------------------------------

func show_results(number: int) -> void:
	shown_check = data.check_number(number)
	var first := str(shown_check.get("first_set", ScamCheckData.SETS[0]))
	_start_page(PAGE_RESULTS, "Spot the Scam: Your Results", "Check %d  -  set %s before the game, set %s after" % [
		number, first, ScamCheckData.other_set(first)])
	var before := data.score(shown_check.get("before", []))
	var after := data.score(shown_check.get("after", []))

	body.add_child(_text(verdict(before, after)))
	_add_summary_grid(before, after)
	body.add_child(_text(_tactics_text()))

	body.add_child(_text("[b]Message by message[/b]\n%s" % _color(
		"Each row is the same trick in two different messages: the left one before the game, the "
		+ "right one after.", TextStyle.COLOR_NARRATION)))
	for row in data.pair_rows(shown_check):
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 12)
		body.add_child(pair)
		_add_review_card(pair, "BEFORE", row["before"], row["before_answer"])
		_add_review_card(pair, "AFTER", row["after"], row["after_answer"])

	var copy := _button("Copy Results", _copy_results, 200)
	copy.tooltip_text = "One row per check, ready to paste into a spreadsheet."
	if came_from_ending:
		_button("Back to the Ending", SessionState.go_to_scene.bind(ENDING_SCENE), 220)
	else:
		_button("Back", show_home, 160)
	_button("Main Menu", SessionState.go_to_menu, 160)


# One honest sentence about the two tries. Spotting more scams while calling
# more real messages scams is not the same result as spotting more scams, and
# the game only ever shows scams - so it says which one happened.
static func verdict(before: Dictionary, after: Dictionary) -> String:
	var total := int(after.answered)
	var spotted_up := int(after.scams_spotted) > int(before.scams_spotted)
	var alarms_up := int(after.false_alarms) > int(before.false_alarms)
	var line := ""
	if int(before.right) == total and int(after.right) == total:
		line = "Every message right, before and after."
	elif spotted_up and alarms_up:
		line = "You spotted more scams after playing, but you also called more real messages scams. The game only shows you scams, so look at what made the real ones safe below."
	elif spotted_up:
		line = "You spotted more scams after playing, without calling more real messages scams. That's the skill the game is for."
	elif int(after.right) > int(before.right):
		line = "More right answers after playing than before. The rows below show which messages changed."
	elif int(after.right) < int(before.right):
		line = "Fewer right answers after playing than before. The rows below show which messages got through, and why."
	else:
		line = "About the same before and after. The rows below show which tricks still got through."
	if int(after.flags_named) > int(before.flags_named):
		line += " You also named more of the red flags."
	return line


func _add_summary_grid(before: Dictionary, after: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	_card(body).add_child(grid)
	for heading in ["", "Before", "After"]:
		grid.add_child(_cell("[b]%s[/b]" % heading))
	var rows := [
		["Right answers", "right", "answered", false],
		["Scams spotted", "scams_spotted", "scams", false],
		["Real messages trusted", "legit_trusted", "legit", false],
		["Red flags named", "flags_named", "scams", false],
	]
	for row in rows:
		var was := int(before[row[1]])
		var now := int(after[row[1]])
		grid.add_child(_cell(str(row[0])))
		grid.add_child(_cell("%d of %d" % [was, int(before[row[2]])]))
		var tone := TextStyle.COLOR_SPEECH
		if now > was:
			tone = TextStyle.COLOR_CORRECT
		elif now < was:
			tone = TextStyle.COLOR_WRONG
		grid.add_child(_cell(_color("%d of %d" % [now, int(after[row[2]])], tone)))


func _cell(bbcode: String) -> RichTextLabel:
	var cell := _text(bbcode)
	cell.size_flags_horizontal = Control.SIZE_FILL
	cell.custom_minimum_size = Vector2(220, 0)
	cell.autowrap_mode = TextServer.AUTOWRAP_OFF
	return cell


# Each tactic the check tests: how many of the scams using it were caught
# before and after, and the catalogue's one-line defense for any that still got
# past after the game.
func _tactics_text() -> String:
	var first := str(shown_check.get("first_set", ScamCheckData.SETS[0]))
	var before := data.tactic_catches(first, shown_check.get("before", []))
	var after := data.tactic_catches(ScamCheckData.other_set(first), shown_check.get("after", []))
	var lines: Array[String] = ["[b]Scams caught, by tactic[/b]"]
	for tactic in data.tactics_tested(first):
		var was: Array = before.get(tactic, [0, 0])
		var now: Array = after.get(tactic, [0, 0])
		var all_caught: bool = now[0] == now[1]
		var tone := TextStyle.COLOR_CORRECT if all_caught else TextStyle.COLOR_WRONG
		var line := "%s  %s" % [TacticNotebook.tactic_name(tactic),
			_color("caught %d of %d before, %d of %d after" % [was[0], was[1], now[0], now[1]], tone)]
		if not all_caught:
			line += "\n    %s" % _color(TacticNotebook.spot_it(tactic), TextStyle.COLOR_HINT)
		lines.append(line)
	return "\n".join(lines)


func _add_review_card(row: HBoxContainer, label: String, entry: Dictionary, answer: Dictionary) -> void:
	var right := ScamCheckData.answered_right(entry, answer)
	var inner := _card(row, TextStyle.COLOR_CORRECT if right else TextStyle.COLOR_WRONG)
	inner.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is_scam := bool(entry.get("scam", false))
	var said := str(answer.get("call", ""))
	var lines: Array[String] = []
	lines.append(_mono(label, TextStyle.COLOR_NARRATION))
	lines.append(_situation_text(entry))
	lines.append(message_text(entry))
	var verdict_line := "It was %s. You said %s." % [
		"[b]a scam[/b]" if is_scam else "[b]legit[/b]",
		"scam" if said == ScamCheckData.CALL_SCAM else "legit"]
	lines.append(_color(verdict_line, TextStyle.COLOR_CORRECT if right else TextStyle.COLOR_WRONG))
	if said == ScamCheckData.CALL_SCAM:
		var flags: Array = entry.get("flags", [])
		var index := int(answer.get("flag", -1))
		if index >= 0 and index < flags.size():
			var named := not ScamCheckData.flag_tactic(entry, index).is_empty()
			lines.append(_color("What gave it away: you picked \"%s\"" % str(flags[index].get("text", "")),
				TextStyle.COLOR_CORRECT if named else TextStyle.COLOR_WRONG))
	lines.append(_color(str(entry.get("why", "")), TextStyle.COLOR_HINT))
	inner.add_child(_text("\n\n".join(lines), 16))
