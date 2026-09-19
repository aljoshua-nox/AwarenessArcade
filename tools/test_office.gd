extends Node

## Headless smoke test for the office call floor.
##
##   godot --headless --path . res://tools/test_office.tscn
##
## Exits 0 if every check passes, 1 otherwise.

const OFFICE_SCENE := "res://scenes/exploration/office_interior.tscn"
const DESK_SCENE := "res://scenes/exploration/detective_office.tscn"
const FLOOR_FOUR_SCENE := "res://scenes/exploration/office_floor_four.tscn"

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
	await _test_fourth_floor()
	await _test_detective_desk()
	await _test_floor_prompts()
	await _test_camera_fenced()
	_test_ambience()
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
	# A sound still in the mixer at quit is reported as a leak.
	await AudioManager.settle()
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
	_check(view.stations.size() == 6, "four exhibits, the director's door and the stairwell (got %d)" % view.stations.size())
	for title in ["Script binders", "The call list", "Bonus board", "The shift schedule", "Floor director's office", "Stairwell"]:
		_check(not _station(view, title).is_empty(), "station present: %s" % title)
	# The floor keeps the street's two numbers on screen.
	_check(view.standing_label.text == "Standing: %d" % SessionState.detective_credibility,
		"the floor shows standing (%s)" % view.standing_label.text)
	_check(view.statements_label.text == "Statements: 0 of %d" % SessionState.STATEMENT_BUDGET,
		"the floor shows the budget (%s)" % view.statements_label.text)
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
	_check(body.contains("P4,200"), "a successful call shows its payout")
	_check(body.contains("RECONTACT"), "a paying victim is flagged for recontact")
	_check(body.contains("still live"), "even a refusal keeps the number on the list")
	_check(body.contains("HARM ON RECORD"), "the ledger carries the harm marker")
	# The company's name is printed by the street (the tower's directory, the
	# site billboard) and by this floor's bonus board, and it has to be the
	# same string in all three - the player is meant to notice, unprompted.
	_check(view._station_body(_station(view, "Bonus board")).contains(SessionState.COMPANY_NAME),
		"the bonus board prints the same company name the street does")
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
	call_view._start_call(0)
	call_view._finish_reveal()
	# An ending node declares what it cost; the engine records what it declares.
	call_view._end_current_call(SessionState.CALL_SUCCESS, {"payout": 3300})
	call_view._finish_reveal()

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
	call_view._end_current_call(SessionState.CALL_ABORTED)
	_check(SessionState.prologue_call_log.size() == 1, "ending with no active call logs nothing")

	remove_child(call_view)
	call_view.queue_free()
	await get_tree().process_frame

	# And the office reads it back.
	var view := await _open()
	_check(view._station_body(_station(view, "The call list")).contains("P3,300"), "the office ledger shows the logged call")
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


# The floor above. Reached by the stairwell on the call floor, always open;
# its director's door is not, until Bea has turned.
func _test_fourth_floor() -> void:
	print("\n[the fourth floor]")
	SessionState.reset_session()
	var view := await _open()
	var stairs := _station(view, "Stairwell")
	_check(bool(stairs.get("is_stairs", false)), "the stairwell climbs rather than reads")
	_check(view.stairs_target() == FLOOR_FOUR_SCENE, "...to the fourth floor")
	view._take_stairs()
	_check(SessionState.has_office_return_spawn and SessionState.office_return_spawn == view.STAIRS_ARRIVAL,
		"climbing remembers where to land coming back down")
	await _close(view)

	# Coming back down lands in front of the stairs, not at the street door.
	view = await _open()
	_check(view.player.global_position == view.STAIRS_ARRIVAL, "the call floor puts a returning player at the stairs")
	_check(not SessionState.has_office_return_spawn, "...and consumes the arrival point")
	await _close(view)
	view = await _open()
	_check(view.player.global_position == view.player_spawn, "a fresh visit still starts at the street door")
	await _close(view)

	# The floor itself: its own four exhibits, no ledger, no stairs up, and a
	# way down.
	SessionState.reset_session()
	var upstairs: Node = load(FLOOR_FOUR_SCENE).instantiate()
	add_child(upstairs)
	await get_tree().process_frame
	_check(upstairs.stations.size() == 5, "four exhibits plus the director's door upstairs (got %d)" % upstairs.stations.size())
	for title in ["The remote-access script", "The session log", "The headset rack", "The recruitment folder", "Floor director's office"]:
		_check(not _station(upstairs, title).is_empty(), "upstairs station present: %s" % title)
	_check(_station_quiet(upstairs, "Stairwell").is_empty(), "no stairs up from the top floor")
	_check(_station_quiet(upstairs, "The call list").is_empty(), "the ledger stays on the call floor")
	_check(upstairs.portal.target_scene == OFFICE_SCENE, "the way out of the fourth floor is the call floor")
	_check(upstairs.portal.prompt_text.contains("stairs down"), "...and says so (%s)" % upstairs.portal.prompt_text)
	_check(upstairs._station_body(_station(upstairs, "The headset rack")).contains("SANTIAGO"),
		"the headset rack carries the recruit's name")
	_check(upstairs._station_body(_station(upstairs, "The session log")).contains("23:04"),
		"the session log holds the 23:04 session Marco's alibi breaks on")

	# Rowena's door: inert until Bea turns, then the confrontation with her case.
	var door := _station(upstairs, "Floor director's office")
	_check(not bool(door.get("is_confrontation", false)), "Rowena's door is inert before Bea turns")
	_check(upstairs._station_body(door).contains("R. OCAMPO"), "the nameplate is hers")
	_check(upstairs._station_body(door).contains("Bea is the way through"), "the locked door points at Bea")
	await _close_node(upstairs)

	SessionState.reset_session()
	SessionState.witness_flipped = true
	upstairs = load(FLOOR_FOUR_SCENE).instantiate()
	add_child(upstairs)
	await get_tree().process_frame
	door = _station(upstairs, "Floor director's office")
	_check(bool(door.get("is_confrontation", false)), "the door opens once Bea has turned")
	_check(upstairs.confrontation_case().ends_with("interview_case_011.json"), "...onto Rowena's case")
	await _close_node(upstairs)

	# Marco flipping does not open the fourth floor, and Bea turning does not
	# open the third - each floor has its own way in.
	SessionState.reset_session()
	SessionState.suspect_flipped = true
	upstairs = load(FLOOR_FOUR_SCENE).instantiate()
	add_child(upstairs)
	await get_tree().process_frame
	_check(not bool(_station(upstairs, "Floor director's office").get("is_confrontation", false)),
		"Marco's flip does not open Rowena's door")
	await _close_node(upstairs)


func _close_node(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


# A lookup that does not count a missing station as a failure - for asserting
# that a station is absent.
func _station_quiet(view: Node, title: String) -> Dictionary:
	for station in view.stations:
		if str(station.get("title", "")) == title:
			return station
	return {}


# The case starts at the detective's desk: the case file and the notebook are
# picked up there (the desk and the side table), the door does not open until
# both are, and the brief opens when the file is taken.
func _test_detective_desk() -> void:
	print("\n[the detective's desk]")
	SessionState.reset_session()
	SessionState.briefing_pending = true
	_check(SessionState.DESK_SCENE == DESK_SCENE and ResourceLoader.exists(DESK_SCENE),
		"both ways into the investigation have a desk to land at")
	var desk: Node = load(DESK_SCENE).instantiate()
	add_child(desk)
	await get_tree().process_frame

	_check(desk.stations.size() == 3, "the desk, the side table and the map, nothing else (got %d)" % desk.stations.size())
	# One desk, not forty: the call floor's bed was wrong here. The street
	# through the window, well down, is what plays.
	_check(str(desk.ambience_path).ends_with("street.ogg") and float(desk.ambience_db) <= -20.0,
		"the desk hears the street through the window, not the call floor (%s at %.0f dB)" % [str(desk.ambience_path).get_file(), float(desk.ambience_db)])
	for title in ["Your desk", "The side table", "The district map"]:
		_check(not _station(desk, title).is_empty(), "station present: %s" % title)
	var titles: Array[String] = []
	for station in desk.stations:
		titles.append(str(station.get("title", "")))
	_check(not titles.has("Floor director's office") and not titles.has("Stairwell"), "no director's door and no stairs")
	_check(desk.portal.target_scene == "res://scenes/exploration/urban_exterior.tscn", "the way out is Sampaguita Street")

	# Stand at the door with nothing taken.
	desk.player.global_position = desk.portal.global_position
	_check(not desk._can_enter_portal(), "the door does not open before the tools are taken")
	_check(desk.portal.prompt_text.begins_with("Take the case file"), "and says why (%s)" % desk.portal.prompt_text)
	_check(not CaseJournal._available_here(), "the journal is not offered before the file is taken")

	var desk_station := _station(desk, "Your desk")
	_check(str(desk_station.get("prompt", "")) == "Take the case file", "the desk offers the file")
	desk._open_inspection(desk_station)
	await get_tree().process_frame
	_check(SessionState.journal_collected, "taking the file hands over the journal")
	_check(not SessionState.briefing_pending, "and consumes the pending brief, so the street will not show it again")
	_check(CaseJournal.is_open and CaseJournal.current_tab == CaseJournal.TAB_BRIEF, "and opens the brief")
	_check(not desk.inspection_open, "without a station panel under it")
	CaseJournal.close()
	await get_tree().process_frame
	_check(str(desk_station.get("prompt", "")) == "Read the case file", "the desk now offers to re-read it")
	_check(not desk._can_enter_portal(), "one tool is not enough for the door")

	var table := _station(desk, "The side table")
	_check(str(table.get("prompt", "")) == "Take your notebook", "the table offers the notebook")
	desk._open_inspection(table)
	await get_tree().process_frame
	_check(SessionState.notebook_collected, "taking the notebook hands over the Tactics tab")
	_check(desk.inspection_open and desk.inspect_body.text.contains("half its pages used"),
		"the table reads as the notebook being taken")
	desk._close_inspection()
	_check(str(table.get("prompt", "")) == "Examine the table", "the table now reads as cleared")
	desk._open_inspection(table)
	_check(desk.inspect_body.text.contains("notebook gone"), "and says so")
	desk._close_inspection()

	_check(desk._can_enter_portal(), "with both tools taken the door opens")
	_check(desk.portal.prompt_text.begins_with("Head out"), "and the prompt says where (%s)" % desk.portal.prompt_text)
	_check(CaseJournal._available_here(), "the journal is offered now")

	remove_child(desk)
	desk.queue_free()
	await get_tree().process_frame

	# Coming back later finds the tools already taken.
	var again: Node = load(DESK_SCENE).instantiate()
	add_child(again)
	await get_tree().process_frame
	_check(str(_station(again, "Your desk").get("prompt", "")) == "Read the case file", "a later visit re-reads the file")
	_check(str(_station(again, "The side table").get("prompt", "")) == "Examine the table", "and finds the table cleared")
	_check(again.portal.prompt_text.begins_with("Head out"), "and the door open")
	remove_child(again)
	again.queue_free()
	await get_tree().process_frame


# Station and exit prompts float over the thing, the way the street's do.
# A camera with no limits centres on a player by the left wall and shows a
# half-screen of void beside the room. Every floor fences it to the room.
func _test_camera_fenced() -> void:
	print("
[the camera stays in the room]")
	for scene_path in [OFFICE_SCENE, "res://scenes/exploration/office_floor_four.tscn", SessionState.DESK_SCENE]:
		SessionState.reset_session()
		var view: Node = load(scene_path).instantiate()
		add_child(view)
		await get_tree().process_frame
		var camera: Camera2D = view.player.get_node("Camera2D")
		var room: Vector2 = get_viewport().get_visible_rect().size
		_check(camera.limit_left == 0 and camera.limit_top == 0 and camera.limit_right == int(room.x)
			and camera.limit_bottom == int(room.y),
			"%s fences the camera to the room (%d,%d..%d,%d)" % [scene_path.get_file(), camera.limit_left,
			camera.limit_top, camera.limit_right, camera.limit_bottom])
		_check(camera.zoom.x >= 1.0, "...and the view is no wider than the room (zoom %.1f)" % camera.zoom.x)
		remove_child(view)
		view.queue_free()
		await get_tree().process_frame


func _test_floor_prompts() -> void:
	print("\n[prompts on the floor]")
	SessionState.reset_session()
	var view := await _open()
	# The spawn is a step inside the street door, so once physics has run the
	# door's prompt is up. Waiting for it makes the check deterministic: read
	# before the first physics step it was hidden, after it shown, and the
	# suite flipped between the two with the machine's load.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(view.prompt_bubble != null and view.prompt_bubble.visible and view.prompt_bubble.text == view.portal.prompt_text,
		"the spawn is inside the street door's reach, so its prompt is up (%s)" % view.prompt_bubble.text)
	view._on_portal_exited(view.portal)
	_check(not view.prompt_bubble.visible, "stepping off it hides the prompt")
	_check(not view.station_label.visible and not view.portal_label.visible, "the corner labels stay off")
	var ledger := _station(view, "The call list")
	view._on_station_entered(view.player, ledger)
	_check(view.prompt_bubble.visible and view.prompt_bubble.text == str(ledger.get("prompt", "")),
		"standing at a station shows its prompt (%s)" % view.prompt_bubble.text)
	var area: Area2D = ledger.get("area")
	_check(view.prompt_bubble.global_position.y < area.global_position.y - 80.0, "...above its marker")
	view._open_inspection(ledger)
	_check(not view.prompt_bubble.visible, "reading it hides the prompt")
	view._close_inspection()
	_check(view.prompt_bubble.visible, "closing brings it back")
	view._on_station_exited(view.player, ledger)
	_check(not view.prompt_bubble.visible, "walking off hides it")

	view._on_portal_entered(view.portal)
	_check(view.prompt_bubble.visible and view.prompt_bubble.text == view.portal.prompt_text, "the exit door prompts")
	_check(view._can_enter_portal(), "and counts as in reach")
	view._on_portal_exited(view.portal)
	_check(not view.prompt_bubble.visible and view.active_portal == null, "leaving it clears both")
	await _close(view)


# A bed under a scene is one file away: the scene names it, the manager plays
# it if it exists and stays silent if it does not.
func _test_ambience() -> void:
	print("\n[ambience]")
	AudioManager.play_ambience("res://assets/audio/ambience/not_here.mp3")
	_check(not AudioManager.ambience_playing(), "a bed that is not in the repo plays nothing")
	_check(AudioManager.ambience_path.is_empty(), "and leaves no path behind")
	var stand_in := "res://assets/audio/sfx/434379__kila_vat__notification-sound-handmade.mp3"
	AudioManager.play_ambience(stand_in)
	_check(AudioManager.ambience_path == stand_in, "a file that exists is taken up")
	_check(AudioManager._ambience_player.stream != null and bool(AudioManager._ambience_player.stream.get("loop")),
		"and set to loop")
	AudioManager.play_ambience(stand_in)
	_check(AudioManager.ambience_path == stand_in, "asking for the same bed again keeps it")
	AudioManager.stop_ambience()
	_check(not AudioManager.ambience_playing() and AudioManager.ambience_path.is_empty(), "stopping clears it")

	# The beds and the music that ship are real files that loop.
	for path in ["res://assets/audio/ambience/street.ogg", "res://assets/audio/ambience/call_floor.ogg"]:
		_check(ResourceLoader.exists(path), "%s is in the repo" % path.get_file())
	for name in AudioManager.MUSIC:
		_check(ResourceLoader.exists(str(AudioManager.MUSIC[name])), "music '%s' is in the repo" % name)
	for name in AudioManager.SFX:
		_check(ResourceLoader.exists(str(AudioManager.SFX[name])), "effect '%s' is in the repo" % name)
	AudioManager.play_music("menu")
	_check(AudioManager.music_path == str(AudioManager.MUSIC["menu"]), "music plays by name")
	_check(bool(AudioManager._music_player.stream.get("loop")), "and loops")
	AudioManager.play_music("not_a_track")
	_check(AudioManager.music_path.is_empty() and not AudioManager.music_playing(), "an unknown track stops the music")
	AudioManager.play_sfx("click")
	AudioManager.play_sfx("step")
	_check(AudioManager._sfx_players.size() == AudioManager.SFX_PLAYERS, "effects play from a pool, not one player")
	AudioManager.stop_music()
