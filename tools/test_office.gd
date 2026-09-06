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

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures.size() > 0 else 0)


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
	SessionState.record_prologue_call("Maria S.", "success", 4200)
	SessionState.record_prologue_call("Kevin Dizon", "partial", 900)
	SessionState.record_prologue_call("Evelyn Marsh", "", 0)

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
