extends Node

## Headless check of Spot the Scam (scam_check in the code), the opt-in before/after quiz.
##
##   godot --headless --path . res://tools/test_scam_check.tscn
##
## Exits 0 if every check passes, 1 otherwise. Covers the content's shape at
## runtime (the validator covers it statically), the scoring - including that
## answering "scam" to everything scores half - a before check driven through
## the screen with nothing about the answers shown, the ending screen offering
## the after check, the after check and its side-by-side results, the record
## (alternating sets, a new check closing the waiting one, backing out writing
## nothing), the spreadsheet export, and clearing. It writes a scratch record,
## never the player's.

const ScamCheckData := preload("res://scripts/scam_check/scam_check_data.gd")
const TextStyle := preload("res://scripts/systems/text_style.gd")

const SCENE := "res://scenes/scam_check/scam_check.tscn"
const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const END_SCENE := "res://scenes/investigation/investigation_end.tscn"
const SCRATCH := "user://test_scam_check.cfg"
const SCRATCH_ENDINGS := "user://test_scam_check_endings.cfg"

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("  FAIL  %s" % label)
	else:
		print("  ok    %s" % label)


func _open(scene_path: String) -> Node:
	var view: Node = load(scene_path).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _buttons(view: Node) -> Array[Button]:
	var out: Array[Button] = []
	for node in view.find_children("*", "Button", true, false):
		if (node as Button).is_inside_tree() and not (node as Button).is_queued_for_deletion():
			out.append(node)
	return out


func _button(view: Node, text: String) -> Button:
	for button in _buttons(view):
		if button.text == text:
			return button
	return null


func _press(view: Node, text: String) -> void:
	var button := _button(view, text)
	_check(button != null, "there is a '%s' button to press" % text)
	if button != null:
		button.pressed.emit()
		await get_tree().process_frame


func _screen_text(view: Node) -> String:
	var parts: PackedStringArray = []
	for node in view.find_children("*", "", true, false):
		if node.is_queued_for_deletion():
			continue
		if node is RichTextLabel:
			parts.append((node as RichTextLabel).text)
		elif node is Label:
			parts.append((node as Label).text)
		elif node is Button:
			parts.append((node as Button).text)
	return "\n".join(parts)


# The right answer to an item, as the screen would record it.
func _right_answer(entry: Dictionary) -> Dictionary:
	if not bool(entry.get("scam", false)):
		return {"item": entry.id, "call": ScamCheckData.CALL_LEGIT, "flag": -1}
	var flags: Array = entry.get("flags", [])
	for i in range(flags.size()):
		if not str(flags[i].get("tactic_id", "")).is_empty():
			return {"item": entry.id, "call": ScamCheckData.CALL_SCAM, "flag": i}
	return {}


func _answers(data: ScamCheckData, set_id: String, how: String) -> Array:
	var out: Array = []
	for entry in data.items_in(set_id):
		match how:
			"right":
				out.append(_right_answer(entry))
			"scam":
				out.append({"item": entry.id, "call": ScamCheckData.CALL_SCAM, "flag": 0})
			_:
				out.append({"item": entry.id, "call": ScamCheckData.CALL_LEGIT, "flag": -1})
	return out


func _run() -> void:
	print("\n--- scam check smoke test ---")
	SessionState.scam_check_path = SCRATCH
	SessionState.ending_record_path = SCRATCH_ENDINGS
	SessionState.scam_check_session_number = 0
	ScamCheckData.new().clear()
	SessionState.clear_ending_record()

	_test_content()
	_test_scoring()
	await _test_empty_home()
	await _test_backing_out_saves_nothing()
	await _test_before_check()
	await _test_menu()
	await _test_ending_screen()
	await _test_after_check()
	_test_record_rules()
	_test_export()
	await _test_home_with_checks()
	await _test_new_launch()
	await _test_clear()

	ScamCheckData.new().clear()
	SessionState.scam_check_session_number = 0
	SessionState.clear_ending_record()
	SessionState.scam_check_path = SessionState.SCAM_CHECK_PATH
	SessionState.ending_record_path = SessionState.ENDING_RECORD_PATH

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	# A sound still in the mixer at quit is reported as a leak.
	await AudioManager.settle()
	get_tree().quit(1 if failures.size() > 0 else 0)


func _test_content() -> void:
	print("\n[the two sets]")
	var data := ScamCheckData.new()
	for set_id in ScamCheckData.SETS:
		var items := data.items_in(set_id)
		var scams := items.filter(func(e: Dictionary) -> bool: return bool(e.get("scam", false)))
		_check(items.size() == 8, "set %s holds 8 messages" % set_id)
		_check(scams.size() == 4, "set %s is half scams, half legit" % set_id)
		for entry in items:
			var other := data.twin(entry)
			_check(not other.is_empty() and other.kind == entry.kind and other.scam == entry.scam,
				"%s has a matching twin in the other set" % entry.id)
	_check(data.tactics_tested("A") == data.tactics_tested("B") or
		(data.tactics_tested("A").size() == data.tactics_tested("B").size()
		and data.tactics_tested("A").all(func(t: String) -> bool: return data.tactics_tested("B").has(t))),
		"both sets test the same tactics")
	for tactic in data.tactics_tested("A"):
		_check(TacticNotebook.has_tactic(tactic) and not TacticNotebook.spot_it(tactic).is_empty(),
			"%s is in the catalogue, with a defense to show a player who missed it" % tactic)


func _test_scoring() -> void:
	print("\n[scoring]")
	var data := ScamCheckData.new()
	var all_scam := data.score(_answers(data, "A", "scam"))
	_check(all_scam.right == 4 and all_scam.false_alarms == 4,
		"answering 'scam' to everything scores half, with every real message a false alarm")
	var all_legit := data.score(_answers(data, "A", "legit"))
	_check(all_legit.right == 4 and all_legit.scams_spotted == 0, "answering 'legit' to everything scores half")
	var perfect := data.score(_answers(data, "A", "right"))
	_check(perfect.right == 8 and perfect.flags_named == 4 and perfect.false_alarms == 0, "a perfect set scores 8, 4 flags named")
	var catches := data.tactic_catches("A", _answers(data, "A", "right"))
	_check(not catches.is_empty() and catches.values().all(func(t: Array) -> bool: return t[0] == t[1] and t[1] > 0),
		"catching every scam catches every tactic, whichever reason was picked")
	var none := data.tactic_catches("A", _answers(data, "A", "legit"))
	_check(none.values().all(func(t: Array) -> bool: return t[0] == 0), "calling every scam legit catches none")

	# A spotted scam with a distractor picked is spotted, not named.
	var entry: Dictionary = data.items_in("A")[0]
	var distractor := -1
	var flags: Array = entry.get("flags", [])
	for i in range(flags.size()):
		if str(flags[i].get("tactic_id", "")).is_empty():
			distractor = i
	var one := data.score([{"item": entry.id, "call": ScamCheckData.CALL_SCAM, "flag": distractor}])
	_check(one.scams_spotted == 1 and one.flags_named == 0, "a scam called a scam for the wrong reason is spotted, not named")

	var scene_script: Script = load("res://scripts/scam_check/scam_check.gd")
	var worse_alarms: String = scene_script.verdict(
		{"answered": 8, "right": 4, "scams_spotted": 1, "false_alarms": 1, "flags_named": 1},
		{"answered": 8, "right": 5, "scams_spotted": 4, "false_alarms": 3, "flags_named": 3})
	_check(worse_alarms.contains("also called more real messages scams"),
		"more scams spotted with more false alarms is said as such")
	var clean: String = scene_script.verdict(
		{"answered": 8, "right": 4, "scams_spotted": 1, "false_alarms": 1, "flags_named": 1},
		{"answered": 8, "right": 8, "scams_spotted": 4, "false_alarms": 0, "flags_named": 4})
	_check(clean.contains("without calling more real messages scams"), "a clean improvement is said as one")


func _test_empty_home() -> void:
	print("\n[the Spot the Scam page, nothing on record]")
	_check(not CaseJournal.shows_button_in(SCENE), "the journal stays hidden here")
	SessionState.scam_check_entry = ""
	var view := await _open(SCENE)
	_check(view.page == view.PAGE_HOME, "from the menu it opens on its own page")
	_check(_button(view, "Take the Before Check") != null, "offering the before check")
	_check(_button(view, "Copy Results").disabled and _button(view, "Clear Record").disabled,
		"with nothing to copy or clear")
	_check(_button(view, "Take the After Check") == null, "and no after check yet")
	await _close(view)


func _test_backing_out_saves_nothing() -> void:
	print("\n[backing out halfway]")
	var view := await _open(SCENE)
	await _press(view, "Take the Before Check")
	await _press(view, "Begin")
	await _press(view, "It's legit")
	await _press(view, "It's legit")
	view.show_home()
	_check(ScamCheckData.new().checks().is_empty(), "a before check left halfway writes nothing")
	await _close(view)


func _test_before_check() -> void:
	print("\n[the before check]")
	var view := await _open(SCENE)
	await _press(view, "Take the Before Check")
	_check(view.page == view.PAGE_INTRO, "an intro comes first")
	_check(_screen_text(view).contains("made up for this check"), "saying the messages are made up")
	await _press(view, "Begin")
	_check(view.set_id == "A", "the first check on a computer starts with set A")

	var data := ScamCheckData.new()
	var items := data.items_in("A")
	var giveaway := false
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		_check(view.page == view.PAGE_MESSAGE and view.subtitle_label.text == "Message %d of 8" % (i + 1),
			"message %d of 8 is on screen" % (i + 1))
		var text := _screen_text(view)
		if text.contains(str(entry.get("why", ""))) or text.contains(TextStyle.COLOR_CORRECT) \
				or text.contains(TextStyle.COLOR_WRONG) or text.contains("It was "):
			giveaway = true
		if i == 0:
			# A scam: say so, look at the reasons, change the answer, then pick
			# a real tell.
			await _press(view, "It's a scam")
			_check(view.asking_flag, "saying 'scam' asks what gave it away")
			var shown: Array[String] = []
			for button in _buttons(view):
				shown.append(button.text)
			for flag in entry.get("flags", []):
				_check(shown.has(str(flag.get("text", ""))), "option on screen: %s" % flag.text)
			_check(_button(view, "It's a scam") == null, "and the scam/legit question is gone")
			await _press(view, "Change my answer")
			_check(not view.asking_flag and _button(view, "It's legit") != null, "the answer can be changed before moving on")
			await _press(view, "It's a scam")
			var right: Dictionary = _right_answer(entry)
			await _press(view, str(entry.flags[right.flag].text))
		elif i == 1:
			# Legit, called a scam: the reasons are asked here too, so being
			# asked gives nothing away.
			_check(not bool(entry.get("scam", true)), "the second message in set A is a legit one")
			await _press(view, "It's a scam")
			_check(view.asking_flag, "a legit message called a scam is asked the same question")
			await _press(view, str(entry.flags[0].text))
		else:
			await _press(view, "It's legit")
	_check(not giveaway, "no answer, explanation or right/wrong color is shown during the before check")
	_check(view.page == view.PAGE_SAVED, "the before check ends on a saved page")
	_check(_button(view, "Main Menu") != null, "which sends the player to play the game")

	var open := data.open_check()
	_check(int(open.get("number", 0)) == 1 and open.get("first_set") == "A", "check 1 is on record, set A first")
	var before: Array = open.get("before", [])
	_check(before.size() == 8, "with all 8 answers")
	if before.size() == 8:
		var first: Dictionary = before[0]
		_check(first.call == ScamCheckData.CALL_SCAM and first.flag == _right_answer(items[0]).flag,
			"the flag is recorded by its place in the file, not the shuffled slot")
		_check(before[1].call == ScamCheckData.CALL_SCAM, "and a false alarm is recorded as one")
	_check(data.status(open) == ScamCheckData.STATUS_WAITING, "it waits for its after check")
	await _close(view)


func _test_menu() -> void:
	print("\n[the main menu]")
	var view := await _open(MENU_SCENE)
	var button := _button(view, "Spot the Scam")
	_check(button != null, "the main menu has a Spot the Scam button")
	if button != null:
		_check(button.pressed.is_connected(view._open_scam_check), "and it opens Spot the Scam")
	for name in ["Start", "Skip to Investigation", "Credits", "Quit"]:
		_check(_button(view, name) != null, "the menu still has %s" % name)
	await _close(view)

	# How the game was played between the halves: noted by the menu's buttons.
	var data := ScamCheckData.new()
	data.note_route(ScamCheckData.ROUTE_PROLOGUE)
	_check(data.open_check().route == ScamCheckData.ROUTE_PROLOGUE, "starting the prologue is noted on the waiting check")
	data.note_route(ScamCheckData.ROUTE_SKIP)
	_check(data.open_check().route == ScamCheckData.ROUTE_BOTH, "skipping as well is noted as both")


func _test_ending_screen() -> void:
	print("\n[the ending screen]")
	SessionState.reset_session()
	SessionState.investigation_case_title = "Test"
	SessionState.investigation_outcome = "partial"
	var view := await _open(END_SCENE)
	_check(not view.after_check_button.visible, "a mid-case summary does not offer the after check")
	await _close(view)

	SessionState.investigation_outcome = "full_takedown"
	view = await _open(END_SCENE)
	_check(view.after_check_button.visible, "a closing screen offers it while a check is waiting")
	_check(view.after_check_button.pressed.is_connected(view._on_after_check_pressed), "and the button opens it")
	_check((ScamCheckData.new().open_check().get("endings", []) as Array).has("full_takedown"),
		"the ending reached is noted on the waiting check")
	await _close(view)


func _test_after_check() -> void:
	print("\n[the after check and the results]")
	SessionState.scam_check_entry = SessionState.SCAM_CHECK_FROM_ENDING
	var view := await _open(SCENE)
	_check(view.page == view.PAGE_INTRO and view.mode == view.MODE_AFTER, "from an ending it opens on the after intro")
	_check(_button(view, "Not Now") != null, "which can be put off")
	await _press(view, "Begin")
	_check(view.set_id == "B", "the after check uses the other set")

	var data := ScamCheckData.new()
	for entry in data.items_in("B"):
		if bool(entry.get("scam", false)):
			await _press(view, "It's a scam")
			await _press(view, str(entry.flags[_right_answer(entry).flag].text))
		else:
			await _press(view, "It's legit")
	_check(view.page == view.PAGE_RESULTS, "the results follow straight away")
	var check := data.check_number(1)
	_check(data.status(check) == ScamCheckData.STATUS_COMPLETE, "check 1 is complete")

	var text := _screen_text(view)
	_check(text.contains("Before") and text.contains("After"), "before and after sit side by side")
	_check(text.contains("1 of 4") and text.contains("4 of 4"), "scams spotted: 1 of 4 before, 4 of 4 after")
	_check(text.contains("without calling more real messages scams"), "the verdict says what changed")
	_check(text.contains(TacticNotebook.tactic_name("advance_fee")), "tactics are listed by their catalogue name")
	_check(text.contains("caught 1 of 1 before, 1 of 1 after"), "each with the scams using it caught before and after")
	var rows := 0
	for node in view.body.get_children():
		if node is HBoxContainer and node.get_child_count() == 2:
			rows += 1
	_check(rows == 8, "one row per matched pair, before beside after")
	for entry in data.items_in("A"):
		_check(text.contains(str(entry.get("why", ""))), "the explanation for %s is shown now" % entry.id)
	_check(_button(view, "Back to the Ending") != null, "it goes back to the ending it came from")
	_check(_button(view, "Copy Results") != null, "and can copy the results")
	await _close(view)


func _test_record_rules() -> void:
	print("\n[the record]")
	var data := ScamCheckData.new()
	_check(not data.has_open_check(), "nothing waits once the after check is in")
	_check(data.next_first_set() == "B", "the next check starts with the other set")
	var number := data.save_before(data.next_first_set(), _answers(data, "B", "legit"))
	_check(number == 2 and data.open_check().first_set == "B", "check 2 starts with set B")
	_check(data.next_first_set() == "A", "and the one after that goes back to A")
	data.save_before(data.next_first_set(), _answers(data, "A", "scam"))
	_check(data.status(data.check_number(2)) == ScamCheckData.STATUS_UNFINISHED,
		"starting a new check keeps the waiting one as unfinished")
	_check(int(data.open_check().get("number", 0)) == 3, "and check 3 is the one waiting now")


func _test_export() -> void:
	print("\n[copy results]")
	var data := ScamCheckData.new()
	var lines := data.csv_text().split("\n")
	_check(lines.size() == 4, "a header and one row per check")
	var header := lines[0].split(",")
	for set_id in ScamCheckData.SETS:
		for entry in data.items_in(set_id):
			_check(header.has(str(entry.id)), "a column for %s" % entry.id)
	for i in range(1, lines.size()):
		_check(lines[i].split(",").size() == header.size(), "row %d lines up with the header" % i)
	var row := lines[1].split(",")
	var col := func(name: String) -> String: return row[header.find(name)]
	_check(col.call("status") == ScamCheckData.STATUS_COMPLETE and col.call("first_set") == "A", "check 1: complete, set A first")
	_check(col.call("before_right") == "4" and col.call("after_right") == "8", "right answers 4 before, 8 after")
	_check(col.call("endings") == "full_takedown" and col.call("played") == ScamCheckData.ROUTE_BOTH, "with how it was played")
	_check(col.call("a_parcel_fee") == "spotted+named" and col.call("a_missed_delivery") == "false alarm",
		"each message's result is a word a spreadsheet can count")
	_check(not data.csv_text().contains("Lorna") and not data.csv_text().contains("@"), "no message text or contact details in the export")


func _test_home_with_checks() -> void:
	print("\n[the Spot the Scam page, three checks on record]")
	SessionState.scam_check_entry = ""
	var view := await _open(SCENE)
	var text := _screen_text(view)
	_check(text.contains("Check 3 is waiting"), "the waiting check is named")
	_check(_button(view, "Take the After Check") != null and _button(view, "Start a New Check") != null,
		"with its after check, or a new check for a different player")
	var past: Button = null
	var unfinished: Button = null
	for button in _buttons(view):
		if button.text.begins_with("Check 1 "):
			past = button
		elif button.text.begins_with("Check 2 "):
			unfinished = button
	_check(past != null and not past.disabled, "a finished check can be opened")
	_check(unfinished != null and unfinished.disabled, "an unfinished one is listed but cannot")
	_check(not _button(view, "Copy Results").disabled, "Copy Results is on")
	if past != null:
		past.pressed.emit()
		await get_tree().process_frame
		_check(view.page == view.PAGE_RESULTS and _button(view, "Back") != null, "a past check's results open, with a way back")
		await _press(view, "Back")
		_check(view.page == view.PAGE_HOME, "back to the Spot the Scam page")
	await _close(view)


# A check belongs to the launch it was started in. The way from the before
# check to the game passes the main menu, which resets the session - that must
# not drop it. Closing the game must, so on a shared laptop the next player's
# ending cannot complete the last player's check.
func _test_new_launch() -> void:
	print("\n[a new launch]")
	var data := ScamCheckData.new()
	var waiting := data.open_check()
	var number := int(waiting.get("number", 0))
	_check(number > 0, "a check is waiting in this launch")
	SessionState.reset_session()
	_check(data.has_open_check(), "going back to the main menu keeps it waiting")

	# What a restart leaves behind.
	SessionState.scam_check_session_number = 0
	_check(not data.has_open_check(), "after a restart, nothing is offered")
	_check(data.status(waiting) == ScamCheckData.STATUS_UNFINISHED, "the waiting check now reads unfinished")
	_check((data.check_number(number).get("before", []) as Array).size() == 8, "its before answers are still on disk")
	data.note_ending("bribed")
	_check(not (data.check_number(number).get("endings", []) as Array).has("bribed"),
		"another player's ending is not noted on it")

	SessionState.investigation_outcome = "full_takedown"
	var ending := await _open(END_SCENE)
	_check(not ending.after_check_button.visible, "the ending screen does not offer it")
	await _close(ending)

	SessionState.scam_check_entry = ""
	var view := await _open(SCENE)
	_check(_button(view, "Take the Before Check") != null and _button(view, "Take the After Check") == null,
		"the Spot the Scam page offers a new before check instead")
	var listed := false
	for button in _buttons(view):
		if button.text.begins_with("Check %d " % number) and button.disabled \
				and button.text.ends_with(ScamCheckData.STATUS_UNFINISHED):
			listed = true
	_check(listed, "and lists the old one as unfinished")
	_check(data.csv_text().contains("\n%d,%s," % [number, ScamCheckData.STATUS_UNFINISHED]),
		"Copy Results still includes it, as unfinished")
	await _close(view)


func _test_clear() -> void:
	print("\n[clearing]")
	var view := await _open(SCENE)
	await _press(view, "Clear Record")
	_check(_button(view, "Clear the Record") != null and _button(view, "Keep It") != null, "clearing asks first")
	await _press(view, "Keep It")
	_check(not ScamCheckData.new().checks().is_empty(), "keeping it keeps it")
	await _press(view, "Clear Record")
	await _press(view, "Clear the Record")
	_check(not FileAccess.file_exists(SCRATCH), "clearing deletes the file, so cleared and fresh are the same")
	_check(_button(view, "Take the Before Check") != null, "and the page starts over")
	await _close(view)
