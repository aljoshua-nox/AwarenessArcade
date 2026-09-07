extends Node

## Headless smoke test for the tactic notebook.
##
##   godot --headless --path . res://tools/test_notebook.tscn
##
## Exits 0 if every check passes, 1 otherwise. Covers the catalogue, the
## collection state, the overlay itself, and the path that matters most: a
## tactic met in an interview actually turning up in the notebook.

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
	for row in TacticNotebook.entries_box.get_children():
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
	print("\n[the overlay]")
	SessionState.reset_session()
	SessionState.record_tactic_learned("manufactured_urgency", "Named while interviewing Maria Santos")

	_check(not TacticNotebook.is_open, "the notebook starts closed")
	TacticNotebook.open()
	await get_tree().process_frame
	_check(TacticNotebook.is_open, "it opens")
	_check(TacticNotebook.panel_root.visible, "the panel is visible")
	# Reading it must not cost prologue time or let the player walk the map.
	_check(get_tree().paused, "opening pauses the game beneath it")
	_check(TacticNotebook.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the notebook still runs while paused, so it can be closed again")

	var texts := _entry_texts()
	_check(texts.size() == TacticNotebook.tactics.size(),
		"every tactic has a row, found or not (got %d)" % texts.size())
	_check(TacticNotebook.progress_label.text.contains("1 of"), "progress counts what has been found")

	var joined := "\n".join(texts)
	_check(joined.contains("Manufactured urgency"), "a found tactic is named")
	_check(joined.contains("HOW TO SPOT IT"), "a found tactic carries its guidance")
	_check(joined.contains("Named while interviewing Maria Santos"), "it records where it was learned")
	_check(joined.contains("Not yet recorded"), "unfound tactics show as locked so the set reads as incomplete")
	_check(not joined.contains("The reused victim list"),
		"a locked entry does not leak the answer it is hiding")

	TacticNotebook.close()
	await get_tree().process_frame
	_check(not TacticNotebook.is_open, "it closes")
	_check(not get_tree().paused, "closing unpauses")

	# Reachable from anywhere in the fiction, but not from the title screen,
	# where there is nothing collected to read.
	_check(not TacticNotebook.shows_button_in("res://scenes/main_menu/main_menu.tscn"),
		"the notebook button stays off the main menu")
	for scene in ["res://scenes/exploration/urban_exterior.tscn",
			"res://scenes/exploration/office_interior.tscn",
			"res://scenes/investigation/interview.tscn",
			"res://scenes/prologue/prologue_call.tscn"]:
		_check(TacticNotebook.shows_button_in(scene), "the notebook is reachable from %s" % scene.get_file())


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
