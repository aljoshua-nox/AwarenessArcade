extends Node

## Headless smoke test for the tactic notebook and the case journal it lives in.
##
##   godot --headless --path . res://tools/test_notebook.tscn
##
## Exits 0 if every check passes, 1 otherwise. Covers the catalogue, the
## collection state, the overlay itself (the journal's Tactics tab), the pause
## menu the same overlay owns, and the path that matters most: a tactic met in
## an interview actually turning up in the notebook.

const INTERVIEW_SCENE := "res://scenes/investigation/interview.tscn"
const CASE_MARIA := "res://resources/cases/interview_case_001.json"

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


func _open_interview(case_path: String) -> Node:
	SessionState.reset_session()
	# Maria is gated at 55 now; this suite is about the notebook, not the gate.
	SessionState.detective_credibility = 75
	SessionState.pending_case_path = case_path
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _index_of(view: Node, evidence_id: String) -> int:
	for i in range(view.evidence_list.item_count):
		if str(view.evidence_list.get_item_metadata(i)) == evidence_id:
			return i
	return -1


func _entry_texts() -> Array[String]:
	var found: Array[String] = []
	for row in CaseJournal.entries_box.get_children():
		for child in row.get_children():
			for leaf in child.get_children():
				if leaf is RichTextLabel:
					found.append(leaf.text)
	return found


func _run() -> void:
	print("\n--- tactic notebook smoke test ---")
	_test_catalogue()
	_test_collection_state()
	await _test_overlay()
	await _test_briefing()
	await _test_pause_menu()
	await _test_learned_in_an_interview()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures.size() > 0 else 0)


func _test_catalogue() -> void:
	print("\n[catalogue]")
	_check(TacticNotebook.tactics.size() > 0, "the catalogue loads (got %d)" % TacticNotebook.tactics.size())
	_check(TacticNotebook.has_tactic("manufactured_urgency"), "a known tactic id resolves")
	_check(not TacticNotebook.has_tactic("not_a_tactic"), "an unknown id does not")
	var missing_guidance: Array[String] = []
	for entry in TacticNotebook.tactics:
		if str(entry.get("spot_it", "")).strip_edges().is_empty():
			missing_guidance.append(str(entry.get("id", "")))
	_check(missing_guidance.is_empty(),
		"every entry carries how-to-spot-it guidance (missing: %s)" % ", ".join(missing_guidance))


func _test_collection_state() -> void:
	print("\n[collecting]")
	SessionState.reset_session()
	_check(SessionState.tactics_learned.is_empty(), "a fresh session has an empty notebook")
	_check(not SessionState.has_learned_tactic("manufactured_urgency"), "nothing is known up front")

	SessionState.record_tactic_learned("manufactured_urgency", "first context")
	_check(SessionState.has_learned_tactic("manufactured_urgency"), "a tactic is recorded")
	_check(TacticNotebook.learned_count() == 1, "the notebook counts it (got %d)" % TacticNotebook.learned_count())

	# Meeting it again must keep the moment it was actually learned.
	SessionState.record_tactic_learned("manufactured_urgency", "second context")
	_check(SessionState.tactics_learned.size() == 1, "meeting it twice records it once")
	_check(str(SessionState.get_learned_tactic("manufactured_urgency").get("context", "")) == "first context",
		"the first context is the one kept")

	SessionState.record_tactic_learned("", "no id")
	_check(SessionState.tactics_learned.size() == 1, "an empty id records nothing")

	SessionState.reset_session()
	_check(SessionState.tactics_learned.is_empty(), "restarting clears the notebook")


func _test_overlay() -> void:
	print("
[the overlay]")
	SessionState.reset_session()
	SessionState.record_tactic_learned("manufactured_urgency", "Named while interviewing Maria Santos")

	_check(not CaseJournal.is_open, "the journal starts closed")
	CaseJournal.open(CaseJournal.TAB_TACTICS)
	await get_tree().process_frame
	_check(CaseJournal.is_open, "it opens")
	_check(CaseJournal.panel_root.visible, "the panel is visible")
	_check(CaseJournal.current_tab == CaseJournal.TAB_TACTICS, "on the tab that was asked for")
	# Reading it must not let the player walk the map.
	_check(get_tree().paused, "opening pauses the game beneath it")
	_check(CaseJournal.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the journal still runs while paused, so it can be closed again")

	var texts := _entry_texts()
	_check(texts.size() == TacticNotebook.tactics.size(),
		"every tactic has a row, found or not (got %d)" % texts.size())
	_check(CaseJournal.progress_label.text.contains("1 of"), "progress counts what has been found")

	var joined := "
".join(texts)
	_check(joined.contains("Manufactured urgency"), "a found tactic is named")
	_check(joined.contains("HOW TO SPOT IT"), "a found tactic carries its guidance")
	_check(joined.contains("Named while interviewing Maria Santos"), "it records where it was learned")
	_check(joined.contains("Not yet recorded"), "unfound tactics show as locked so the set reads as incomplete")
	_check(not joined.contains("The reused victim list"),
		"a locked entry does not leak the answer it is hiding")

	CaseJournal.close()
	await get_tree().process_frame
	_check(not CaseJournal.is_open, "it closes")
	_check(not get_tree().paused, "closing unpauses")

	# Every tab in the table has a page and a button, and opening with no tab
	# lands on the first one.
	for tab in CaseJournal.TABS:
		var tab_id := str(tab.get("id", ""))
		_check(CaseJournal.tab_pages.has(tab_id) and CaseJournal.tab_buttons.has(tab_id),
			"the %s tab has a page and a button" % tab_id)
	CaseJournal.open()
	_check(CaseJournal.current_tab == str(CaseJournal.TABS[0].get("id", "")),
		"opening with no tab lands on the first")
	CaseJournal.close()
	await get_tree().process_frame

	# The detective's, so it is reachable everywhere in the investigation and
	# nowhere in the prologue - the scammer carries nothing onto the call
	# floor, and the notebook that used to show there had every entry locked.
	for scene in ["res://scenes/main_menu/main_menu.tscn",
			"res://scenes/prologue/prologue_call.tscn",
			"res://scenes/prologue/prologue_end.tscn"]:
		_check(not CaseJournal.shows_button_in(scene), "the journal stays off %s" % scene.get_file())
	for scene in ["res://scenes/exploration/urban_exterior.tscn",
			"res://scenes/exploration/terminal_road.tscn",
			"res://scenes/exploration/office_interior.tscn",
			"res://scenes/exploration/office_floor_four.tscn",
			"res://scenes/investigation/interview.tscn",
			"res://scenes/investigation/investigation_end.tscn"]:
		_check(CaseJournal.shows_button_in(scene), "the journal is reachable from %s" % scene.get_file())


# The desk sergeant's brief: the case file's first page, and the only place the
# game says who the player is and what a statement is for.
func _test_briefing() -> void:
	print("
[the briefing]")
	SessionState.reset_session()
	_check(not CaseJournal.briefing.is_empty(), "the briefing loads")
	_check((CaseJournal.briefing.get("paragraphs", []) as Array).size() >= 3, "it has a body")

	var text := CaseJournal.briefing_text()
	_check(text.contains("CASE FILE"), "it opens as the case file talking")
	_check(text.contains(str(CaseJournal.briefing.get("case_number", "?"))), "it carries the case number")
	_check(text.contains("holds %d statements" % SessionState.STATEMENT_BUDGET),
		"{statements} expands to the budget")
	_check(not text.contains("{statements}"), "no token is left unexpanded")
	# The number and the name are the street's to reveal. The validator refuses
	# them in the file; this pins that the render does not add them either.
	_check(not text.contains(SessionState.OPERATION_NUMBER), "the brief never prints the operation's number")
	_check(not text.to_lower().contains(SessionState.COMPANY_NAME.to_lower()), "nor the company's name")
	var prologue_note := str(CaseJournal.briefing.get("prologue_note", ""))
	_check(not text.contains(prologue_note), "a skip run gets no line about last night's shift")

	SessionState.prologue_played = true
	SessionState.reports_filed = 2
	_check(CaseJournal.briefing_text().contains(prologue_note),
		"a shift somebody reported puts a line about it in the brief")
	SessionState.reports_filed = 0
	_check(not CaseJournal.briefing_text().contains(prologue_note),
		"a shift nobody reported does not")
	SessionState.reset_session()

	CaseJournal.show_briefing()
	await get_tree().process_frame
	_check(CaseJournal.is_open and CaseJournal.current_tab == CaseJournal.TAB_CASE,
		"showing the briefing opens the journal on the case file")
	var page: Control = CaseJournal.tab_pages[CaseJournal.TAB_CASE]
	var rendered := ""
	for label in page.find_children("*", "RichTextLabel", true, false):
		rendered += (label as RichTextLabel).text
	_check(rendered.contains("holds %d statements" % SessionState.STATEMENT_BUDGET), "the page shows the brief")
	CaseJournal.close()
	await get_tree().process_frame


# Esc on a street or a floor used to go straight to the main menu, which resets
# the session. The pause menu asks first.
func _test_pause_menu() -> void:
	print("
[the pause menu]")
	_check(not CaseJournal.is_pause_open, "the pause menu starts closed")
	CaseJournal.open_pause()
	await get_tree().process_frame
	_check(CaseJournal.is_pause_open, "it opens")
	_check(CaseJournal.pause_root.visible, "the panel is visible")
	_check(get_tree().paused, "opening pauses the game beneath it")
	_check(not CaseJournal.is_asking_to_abandon(), "it does not open on the confirm step")

	CaseJournal._ask_to_abandon()
	_check(CaseJournal.is_asking_to_abandon(), "leaving asks first")
	CaseJournal._show_pause_buttons()
	_check(not CaseJournal.is_asking_to_abandon(), "and can be backed out of")

	# The journal is a step out of the pause menu, not on top of it.
	CaseJournal.open(CaseJournal.TAB_TACTICS)
	await get_tree().process_frame
	_check(CaseJournal.is_open and not CaseJournal.is_pause_open, "opening the journal from the menu closes the menu")
	_check(get_tree().paused, "the game stays paused underneath")
	CaseJournal.close()
	await get_tree().process_frame
	_check(not get_tree().paused, "closing the journal resumes")

	CaseJournal.open_pause()
	CaseJournal.close_pause()
	await get_tree().process_frame
	_check(not CaseJournal.is_pause_open, "resume closes it")
	_check(not get_tree().paused, "and unpauses")


# The path that matters: meet a tactic in play, find it in the notebook after.
func _test_learned_in_an_interview() -> void:
	print("\n[learned in play]")
	var view := await _open_interview(CASE_MARIA)
	_check(SessionState.tactics_learned.is_empty(), "nothing is known walking in")

	view._on_choice_pressed(1)
	view._on_choice_pressed(0)
	view._on_choice_pressed(0)  # through the quiz to the evidence step
	_check(SessionState.has_learned_tactic("manufactured_urgency"),
		"answering the tactic quiz records it in the notebook")

	var decoy := _index_of(view, "ev_internet_note")
	var before: int = SessionState.tactics_learned.size()
	view._on_evidence_chosen(decoy)
	_check(SessionState.tactics_learned.size() == before, "a decoy teaches nothing and records nothing")

	view._on_evidence_chosen(_index_of(view, "ev_phishing_text"))
	_check(SessionState.has_learned_tactic("manufactured_urgency"), "the key evidence keeps its entry")

	var context := str(SessionState.get_learned_tactic("manufactured_urgency").get("context", ""))
	_check(context.contains("Maria"), "the entry remembers who it was learned from (%s)" % context)
	await _close(view)
