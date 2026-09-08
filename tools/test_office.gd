extends Node

## Headless smoke test for the office call floor.
##
##   godot --headless --path . res://tools/test_office.tscn
##
## Exits 0 if every check passes, 1 otherwise.

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


func _open() -> Node:
	var view: Node = load(OFFICE_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _station(view: Node, title: String) -> Dictionary:
	for entry in view.stations:
		if str(entry.get("title", "")) == title:
			return entry
	failures.append("station '%s' not found" % title)
	return {}


func _run() -> void:
	print("\n--- office call floor smoke test ---")
	await _test_stations_exist()
	await _test_ledger_reads_back_prologue()
	await _test_ledger_without_prologue()
	await _test_director_door_gate()
	await _test_inspection_panel()
	await _test_prologue_logs_calls()
	_test_outcome_vocabulary()
	await _test_ledger_distinguishes_outcomes()
	_test_disposition_mapping()
	_test_skip_prologue_branch()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures.size() > 0 else 0)


# The outcome vocabulary: every way a call can end must be distinguishable.
# These used to collapse into an empty string, so "she refused you" and "you
# ran out of time" were the same fact.
func _test_outcome_vocabulary() -> void:
	print("
[call outcome vocabulary]")
	var all := [SessionState.CALL_SUCCESS, SessionState.CALL_PARTIAL, SessionState.CALL_REFUSED,
		SessionState.CALL_HUNG_UP, SessionState.CALL_ESCALATED, SessionState.CALL_TIMEOUT,
		SessionState.CALL_ABORTED]
	var unique := {}
	for outcome in all:
		unique[outcome] = true
		_check(not str(outcome).is_empty(), "outcome '%s' is a real value, not an empty string" % outcome)
	_check(unique.size() == all.size(), "all %d outcomes are distinct" % all.size())


func _test_ledger_distinguishes_outcomes() -> void:
	print("
[the ledger tells the outcomes apart]")
	SessionState.reset_session()
	SessionState.reset_prologue()
	SessionState.prologue_played = true
	SessionState.record_prologue_call("maria_santos", "Maria S.", SessionState.CALL_REFUSED, 0)
	SessionState.record_prologue_call("kevin_d", "Kevin Dizon", SessionState.CALL_HUNG_UP, 0)
	SessionState.record_prologue_call("lina_reyes", "Lina Reyes", SessionState.CALL_TIMEOUT, 0)
	SessionState.record_prologue_call("ramon_tolentino", "Ramon Tolentino", SessionState.CALL_ESCALATED, 0)
	SessionState.record_prologue_call("noah_paredes", "Noah Paredes", SessionState.CALL_ABORTED, 0)

	var view := await _open()
	var body: String = view._station_body(_station(view, "The call list"))
	_check(body.contains("refused"), "a refusal is written as a refusal")
	_check(body.contains("hung up early"), "hanging up early reads differently from refusing")
	_check(body.contains("shift ended"), "running out of time is not reported as hanging up")
	_check(body.contains("line pulled"), "an escalated call says the line was pulled")
	_check(body.contains("unworked"), "a call the operator dropped reads as unworked")
	_check(not body.contains("RECONTACT"), "no unpaid call is flagged for recontact")
	await _close(view)


# The seam the prologue-to-investigation coupling will hang off.
func _test_disposition_mapping() -> void:
	print("
[victim disposition]")
	SessionState.reset_session()
	SessionState.reset_prologue()
	SessionState.prologue_played = true
	SessionState.record_prologue_call("maria_santos", "Maria S.", SessionState.CALL_SUCCESS, 4200)
	SessionState.record_prologue_call("kevin_d", "Kevin Dizon", SessionState.CALL_REFUSED, 0)
	SessionState.record_prologue_call("lina_reyes", "Lina Reyes", SessionState.CALL_TIMEOUT, 0)

	_check(SessionState.get_victim_disposition("maria_santos") == SessionState.DISPOSITION_HARMED,
		"a victim you took money from reads as harmed")
	_check(SessionState.get_victim_disposition("kevin_d") == SessionState.DISPOSITION_RESISTANT,
		"a victim who refused reads as resistant")
	_check(SessionState.get_victim_disposition("lina_reyes") == SessionState.DISPOSITION_UNFINISHED,
		"a call cut short reads as unfinished")
	_check(SessionState.get_victim_disposition("evelyn_marsh") == SessionState.DISPOSITION_NEUTRAL,
		"a victim never called reads as neutral")

	# Money taken outranks a later refusal by the same person.
	SessionState.record_prologue_call("kevin_d", "Kevin Dizon", SessionState.CALL_PARTIAL, 900)
	_check(SessionState.get_victim_disposition("kevin_d") == SessionState.DISPOSITION_HARMED,
		"money taken outranks a refusal on a second call")
	_check(not SessionState.get_call_record("maria_santos").is_empty(), "a called victim has a call record")
	_check(SessionState.get_call_record("evelyn_marsh").is_empty(), "an uncalled victim has no call record")

	# The bug this plumbing exists to prevent: the display name is not an
	# identity. Looking up by it must find nothing rather than quietly working
	# for some characters and not others.
	_check(SessionState.get_victim_disposition("Maria S.") == SessionState.DISPOSITION_NEUTRAL,
		"the prologue display name is not a valid lookup key")
	_check(SessionState.get_victim_disposition("Maria Santos") == SessionState.DISPOSITION_NEUTRAL,
		"the case-file display name is not a valid lookup key either")
	_check(SessionState.get_victim_disposition("") == SessionState.DISPOSITION_NEUTRAL,
		"an empty id never matches an entry")


# Skipping the prologue must leave the investigation playable, not degraded.
func _test_skip_prologue_branch() -> void:
	print("
[skip-the-prologue branch]")
	SessionState.reset_session()
	SessionState.reset_prologue()
	_check(not SessionState.prologue_played, "a fresh session has not played the prologue")
	for id in ["maria_santos", "kevin_d", "evelyn_marsh"]:
		_check(SessionState.get_victim_disposition(id) == SessionState.DISPOSITION_NEUTRAL,
			"%s opens neutral with no prologue history" % id)

	# A stale log must not leak into a skip run.
	SessionState.record_prologue_call("maria_santos", "Maria S.", SessionState.CALL_SUCCESS, 4200)
	SessionState.prologue_played = true
	SessionState.reset_prologue()
	_check(SessionState.prologue_call_log.is_empty(), "resetting the prologue clears the call log")
	_check(not SessionState.prologue_played, "resetting the prologue clears the played flag")
	_check(SessionState.get_victim_disposition("maria_santos") == SessionState.DISPOSITION_NEUTRAL,
		"a victim harmed in a previous run does not leak into a skip run")
	_check(SessionState.has_method("start_investigation_direct"), "the menu has a direct investigation entry point")


func _test_stations_exist() -> void:
	print("\n[stations]")
	SessionState.reset_session()
	SessionState.reset_prologue()
	var view := await _open()
	_check(view.stations.size() == 5, "four exhibits plus the director's door (got %d)" % view.stations.size())
	for title in ["Script binders", "The call list", "Bonus board", "The shift rota", "Floor director's office"]:
		_check(not _station(view, title).is_empty(), "station present: %s" % title)
	await _close(view)


func _test_ledger_reads_back_prologue() -> void:
	print("\n[call list reads back the prologue]")
	SessionState.reset_session()
	SessionState.reset_prologue()
	SessionState.record_prologue_call("maria_santos", "Maria S.", "success", 4200)
	SessionState.record_prologue_call("kevin_d", "Kevin Dizon", "partial", 900)
	SessionState.record_prologue_call("evelyn_marsh", "Evelyn Marsh", "", 0)

	var view := await _open()
	var ledger := _station(view, "The call list")
	var body: String = view._station_body(ledger)
	_check(body.contains("Maria S."), "the ledger names a victim the player called")
	_check(body.contains("Kevin Dizon"), "the ledger names every victim called")
	_check(body.contains("4200"), "a successful call shows its payout")
	_check(body.contains("RECONTACT"), "a paying victim is flagged for recontact")
	_check(body.contains("still live"), "even a refusal keeps the number on the list")
	_check(body.contains("HARM ON RECORD"), "the ledger carries the harm marker")
	_check(body.contains("IBMPlexMono"), "the ledger renders in the system voice")

	view._open_inspection(ledger)
	_check(SessionState.reflection_milestones.size() > 0, "inspecting records a reflection milestone")
	await _close(view)


func _test_ledger_without_prologue() -> void:
	print("\n[call list with no prologue history]")
	SessionState.reset_session()
	SessionState.reset_prologue()
	var view := await _open()
	var body: String = view._station_body(_station(view, "The call list"))
	_check(body.contains("torn out"), "an empty log falls back to the torn-out page")
	_check(not body.contains("RECONTACT"), "no fabricated ledger rows appear")
	await _close(view)


func _test_director_door_gate() -> void:
	print("\n[director's door]")
	SessionState.reset_session()
	SessionState.suspect_flipped = false
	var view := await _open()
	var door := _station(view, "Floor director's office")
	_check(not bool(door.get("is_confrontation", false)), "the door is inert before Marco flips")
	_check(str(door.get("prompt", "")) == "Examine the director's door", "locked door reads as examinable")
	_check(view._station_body(door).contains("Marco is the way through"), "locked door points at Marco")
	await _close(view)

	SessionState.reset_session()
	SessionState.suspect_flipped = true
	view = await _open()
	door = _station(view, "Floor director's office")
	_check(bool(door.get("is_confrontation", false)), "the door becomes the confrontation once Marco flips")
	_check(str(door.get("prompt", "")) == "Confront the Operation", "unlocked door prompts the confrontation")
	await _close(view)


# The office ledger is only as good as the prologue feeding it. If this wiring
# breaks, the call list silently falls back to "torn out" and the payoff is lost.
func _test_prologue_logs_calls() -> void:
	print("\n[prologue feeds the ledger]")
	SessionState.reset_session()
	SessionState.reset_prologue()

	var call_view: Node = load("res://scenes/prologue/prologue_call.tscn").instantiate()
	add_child(call_view)
	await get_tree().process_frame

	_check(call_view.victims.size() > 0, "prologue victims loaded (got %d)" % call_view.victims.size())
	call_view.current_victim_index = 0
	call_view.current_call_outcome = "success"
	call_view.current_call_reward = 3300
	call_view._end_current_call("test call ended")

	_check(SessionState.prologue_call_log.size() == 1, "ending a call writes one ledger entry")
	if SessionState.prologue_call_log.size() == 1:
		var entry: Dictionary = SessionState.prologue_call_log[0]
		var expected: String = str(call_view.victims[0].get("name", ""))
		_check(str(entry.get("name", "")) == expected, "the entry names the victim actually called (%s)" % expected)
		var expected_id: String = str(call_view.victims[0].get("person_id", ""))
		_check(not expected_id.is_empty(), "the prologue victim carries a person_id")
		_check(str(entry.get("person_id", "")) == expected_id,
			"the entry carries the person_id, not just the name (%s)" % expected_id)
		_check(int(entry.get("payout", 0)) == 3300, "the entry keeps the payout")
		_check(str(entry.get("outcome", "")) == "success", "the entry keeps the outcome")

	# Ending the prologue with no call in progress must not invent an entry.
	call_view.current_victim_index = -1
	call_view._end_current_call("wrapped up")
	_check(SessionState.prologue_call_log.size() == 1, "ending with no active call logs nothing")

	remove_child(call_view)
	call_view.queue_free()
	await get_tree().process_frame

	# And the office reads it back.
	var view := await _open()
	_check(view._station_body(_station(view, "The call list")).contains("3300"), "the office ledger shows the logged call")
	# The street's residents keep naming one number. It has to be this one, or
	# the pattern the street is built to teach dead-ends here.
	_check(view._station_body(_station(view, "The call list")).contains(SessionState.OPERATION_NUMBER),
		"the ledger dials out on the number the street keeps naming")
	await _close(view)


func _test_inspection_panel() -> void:
	print("\n[inspection panel]")
	SessionState.reset_session()
	SessionState.reset_prologue()
	var view := await _open()
	_check(not view.inspection_open, "panel starts closed")
	view._open_inspection(_station(view, "Bonus board"))
	_check(view.inspection_open, "panel opens")
	_check(view.inspect_panel.visible, "panel is visible")
	_check(not view.player.is_physics_processing(), "the player is frozen while reading")
	_check(view.inspect_body.text.contains("business model"), "bonus board names the harm")
	view._close_inspection()
	_check(not view.inspection_open, "panel closes")
	_check(view.player.is_physics_processing(), "the player can move again")
	await _close(view)
