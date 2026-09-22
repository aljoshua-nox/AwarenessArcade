extends Node

## Headless smoke test for the case journal's objectives, People and Evidence
## pages, and the objective line on the HUD.
##
##   godot --headless --path . res://tools/test_journal.tscn
##
## Exits 0 if every check passes, 1 otherwise. The Tactics tab and the pause
## menu are covered by test_notebook; this drives a scripted route through the
## case and asserts the journal moves with it - objectives unlocking,
## completing and closing in the order the case is built to be played, every
## door in the game turning up on the People page with the right status, and
## the file listing what is held.

const URBAN_SCENE := "res://scenes/exploration/urban_exterior.tscn"
const OFFICE_SCENE := "res://scenes/exploration/office_interior.tscn"

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


func _state(id: String) -> String:
	for objective in CaseJournal.objectives:
		if str(objective.get("id", "")) == id:
			return CaseJournal.objective_state(objective)
	return "missing"


func _tracked() -> String:
	return str(CaseJournal.tracked_objective().get("id", ""))


func _row(name: String) -> Dictionary:
	for row in CaseJournal.people_rows():
		if str(row.get("name", "")) == name:
			return row
	return {}


func _status(name: String) -> String:
	return str(_row(name).get("status", "missing"))


func _page_text(tab_id: String) -> String:
	CaseJournal.open(tab_id)
	var page: Control = CaseJournal.tab_pages[tab_id]
	var text := ""
	for label in page.find_children("*", "RichTextLabel", true, false):
		text += (label as RichTextLabel).text + "\n"
	for label in page.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	CaseJournal.close()
	return text


func _run() -> void:
	print("\n--- case journal smoke test ---")
	_test_objectives_load()
	_test_objective_route()
	_test_lockout_route()
	_test_people_page()
	_test_evidence_page()
	await _test_hud_line()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	# A sound still in the mixer at quit is reported as a leak.
	await AudioManager.settle()
	get_tree().quit(1 if failures.size() > 0 else 0)


func _test_objectives_load() -> void:
	print("\n[objectives]")
	_check(CaseJournal.objectives.size() >= 6, "the objectives load (got %d)" % CaseJournal.objectives.size())
	SessionState.reset_session()
	var states := {}
	for objective in CaseJournal.objectives:
		states[str(objective.get("id", ""))] = CaseJournal.objective_state(objective)
	_check(states.get("first_statement") == CaseJournal.OBJECTIVE_ACTIVE, "a fresh case opens on the first statement")
	_check(states.get("find_operator") == CaseJournal.OBJECTIVE_ACTIVE, "and on finding who made the calls")
	for id in ["build_standing", "flip_operator", "file_unresolved", "confront_director", "turn_recruit", "name_owner"]:
		_check(states.get(id) == CaseJournal.OBJECTIVE_LOCKED, "%s is locked at the start" % id)
	_check(_tracked() == "first_statement", "the HUD tracks the first active objective (%s)" % _tracked())

	# Conditions the file does not use must not silently pass.
	_check(not CaseJournal._condition_holds({"not_a_condition": 1}), "an unknown condition never holds")
	_check(not CaseJournal._condition_holds({"flag": "not_a_flag"}), "an unknown flag never holds")
	_check(CaseJournal._condition_holds({"any": [{"flag": "not_a_flag"}, {"credibility_at_least": 50}]}),
		"any: holds when one option does")


# The route the case is built to be played: a statement, standing, the
# operator, the floor above him, the owner.
func _test_objective_route() -> void:
	print("\n[the route]")
	SessionState.reset_session()
	SessionState.statements_taken = 1
	_check(_state("first_statement") == CaseJournal.OBJECTIVE_DONE, "a statement completes the first objective")
	_check(_state("build_standing") == CaseJournal.OBJECTIVE_ACTIVE, "and unlocks building standing")
	_check(_tracked() == "build_standing", "which the HUD now tracks (%s)" % _tracked())

	SessionState.detective_credibility = 60
	_check(_state("build_standing") == CaseJournal.OBJECTIVE_DONE, "standing of 60 completes it")
	_check(_tracked() == "find_operator", "the HUD moves on to the operator (%s)" % _tracked())

	SessionState.record_interview_outcome("marco_navarro", "failure")
	_check(_state("find_operator") == CaseJournal.OBJECTIVE_DONE, "meeting the operator completes finding him, however it went")
	# The failure cost 10 standing, back under the gate the last objective was
	# about. Done is done: the doors it opened were walked through.
	_check(SessionState.detective_credibility < 60 and _state("build_standing") == CaseJournal.OBJECTIVE_DONE,
		"a completed objective stays completed when standing dips again")
	_check(_state("flip_operator") == CaseJournal.OBJECTIVE_ACTIVE, "and unlocks flipping him")
	_check(_state("confront_director") == CaseJournal.OBJECTIVE_LOCKED, "the director stays locked until he flips")
	_check(_state("name_owner") == CaseJournal.OBJECTIVE_LOCKED, "so does the owner")

	SessionState.suspect_flipped = true
	_check(_state("flip_operator") == CaseJournal.OBJECTIVE_DONE, "the flip completes it")
	_check(_state("confront_director") == CaseJournal.OBJECTIVE_ACTIVE, "and opens the director's door")
	_check(_state("name_owner") == CaseJournal.OBJECTIVE_ACTIVE, "and the question of the owner")
	_check(_tracked() == "name_owner", "the HUD tracks the owner's name ahead of the director's door (%s)" % _tracked())
	_check(_state("turn_recruit") == CaseJournal.OBJECTIVE_LOCKED,
		"the fourth floor stays unmentioned until the player has a reason to know it exists")

	SessionState.record_reflection_milestone("One Login, Two Floors", "")
	_check(_state("turn_recruit") == CaseJournal.OBJECTIVE_ACTIVE, "walking the fourth floor unlocks its recruit")
	SessionState.witness_flipped = true
	_check(_state("turn_recruit") == CaseJournal.OBJECTIVE_DONE, "turning her completes it")

	SessionState.add_evidence({"id": "ev_owner_name", "label": "The Name Above The Floors"})
	_check(_state("name_owner") == CaseJournal.OBJECTIVE_DONE, "the owner's name in the file completes the last one")
	_check(_tracked() == "confront_director", "and the HUD moves on to the director's door (%s)" % _tracked())

	SessionState.record_interview_outcome("elena_cruz", "full_takedown")
	_check(_state("confront_director") == CaseJournal.OBJECTIVE_DONE, "confronting the director completes it")
	_check(_tracked().is_empty(), "with nothing left, the HUD tracks nothing (%s)" % _tracked())


# Losing the operator closes an objective rather than completing it, and puts
# the unresolved filing in its place - unless he is flipped after all.
func _test_lockout_route() -> void:
	print("\n[the lockout]")
	SessionState.reset_session()
	SessionState.record_interview_outcome("marco_navarro", "failure")
	SessionState.case_locked = true
	_check(_state("flip_operator") == CaseJournal.OBJECTIVE_FAILED, "the lawyered ending closes the flip")
	_check(_state("file_unresolved") == CaseJournal.OBJECTIVE_ACTIVE, "and opens filing the case as it stands")
	var text := _page_text(CaseJournal.TAB_OBJECTIVES)
	_check(text.contains("CLOSED"), "a closed objective is marked as such on the page")
	_check(text.contains("asked for a lawyer"), "with its own account of why")

	SessionState.suspect_flipped = true
	_check(_state("flip_operator") == CaseJournal.OBJECTIVE_DONE, "a flip after the lock outranks it, as the doors do")
	_check(_state("file_unresolved") == CaseJournal.OBJECTIVE_DONE, "and the filing is no longer needed")


# Every door in the game, with its place and the state of its person.
func _test_people_page() -> void:
	print("\n[people]")
	SessionState.reset_session()
	var rows := CaseJournal.people_rows()
	var case_count := DirAccess.get_files_at("res://resources/cases").size()
	_check(rows.size() == case_count, "one row per case file (%d of %d)" % [rows.size(), case_count])
	var names := {}
	for row in rows:
		names[row.get("name")] = true
	_check(names.size() == rows.size(), "no name twice")
	_check(str(_row("Evelyn Marsh").get("place", "")) == "Sampaguita Street", "Evelyn is on Sampaguita Street")
	_check(str(_row("Patricia Lim").get("place", "")) == "Terminal Road", "Trish is on Terminal Road")
	_check(str(_row("Elena Cruz").get("place", "")).begins_with("Call Floor"), "Elena is on the call floor")
	_check(str(_row("Rowena Ocampo").get("place", "")).begins_with("Tech Support"), "Rowena is upstairs")

	_check(_status("Evelyn Marsh") == "Will talk", "an ungated witness will talk (%s)" % _status("Evelyn Marsh"))
	_check(_status("Maria Santos").contains("needs Credibility 55"), "a gated witness names her gate (%s)" % _status("Maria Santos"))
	_check(_status("Marco Navarro") == "Costs no statement", "a suspect costs nothing (%s)" % _status("Marco Navarro"))
	_check(_status("Elena Cruz").contains("name her first"), "the director's door says what opens it (%s)" % _status("Elena Cruz"))

	SessionState.record_interview_outcome("maria_santos", "partial", true)
	_check(_status("Maria Santos").contains("Turned you away"), "a hesitant refusal reads as one (%s)" % _status("Maria Santos"))
	SessionState.detective_credibility = 60
	_check(_status("Maria Santos").contains("credibility is enough now"), "and says when standing has caught up")
	SessionState.record_interview_outcome("maria_santos", "success")
	_check(_status("Maria Santos") == "Statement on record", "a success is a statement on record")
	SessionState.record_interview_outcome("evelyn_marsh", "failure")
	SessionState.record_statement("evelyn_marsh", "Victim", "failure", false)
	_check(_status("Evelyn Marsh") == "Won't talk to you again", "a failed witness is closed (%s)" % _status("Evelyn Marsh"))
	SessionState.record_interview_outcome("marco_navarro", "whistleblower")
	_check(_status("Marco Navarro").begins_with("Flipped"), "a flipped suspect says so")
	SessionState.suspect_flipped = true
	_check(_status("Elena Cruz") == "Costs no statement", "which opens the director's door on the page")
	SessionState.statements_taken = SessionState.STATEMENT_BUDGET
	_check(_status("Kevin Dizon") == "No statements left to take", "a spent budget closes the untaken doors (%s)" % _status("Kevin Dizon"))
	_check(_status("Dennis Mercado") == "Costs no statement", "but not the suspects'")

	var text := _page_text(CaseJournal.TAB_PEOPLE)
	_check(text.contains("SAMPAGUITA STREET") and text.contains("TERMINAL ROAD"), "the page is grouped by place")
	_check(text.contains("Statement on record"), "and shows the statuses")


func _test_evidence_page() -> void:
	print("\n[evidence]")
	SessionState.reset_session()
	var text := _page_text(CaseJournal.TAB_EVIDENCE)
	_check(text.contains("Nothing yet"), "an empty file says so")
	SessionState.add_evidence({"id": "test_maria_confirmed", "label": "Maria's Statement",
		"description": "She confirms the call.", "tactic": "Manufactured urgency", "person_id": "maria_santos"})
	text = _page_text(CaseJournal.TAB_EVIDENCE)
	_check(text.contains("Maria's Statement"), "an item is listed")
	_check(text.contains("TACTIC: Manufactured urgency"), "with what it proves")
	_check(text.contains("from Maria Santos"), "and who it came from")
	_check(text.contains("1 item in the file"), "and the count")


# The first active objective sits on the HUD of every walkable scene.
func _test_hud_line() -> void:
	print("\n[the HUD line]")
	SessionState.reset_session()
	var street: Node = load(URBAN_SCENE).instantiate()
	add_child(street)
	await get_tree().process_frame
	_check(street.objective_label.visible and street.objective_label.text.contains("first statement"),
		"the street tracks the first objective (%s)" % street.objective_label.text)
	remove_child(street)
	street.queue_free()
	await get_tree().process_frame

	SessionState.statements_taken = 1
	var office: Node = load(OFFICE_SCENE).instantiate()
	add_child(office)
	await get_tree().process_frame
	_check(office.objective_label.text.contains("credibility"),
		"the floor tracks the current one (%s)" % office.objective_label.text)
	remove_child(office)
	office.queue_free()
	await get_tree().process_frame
