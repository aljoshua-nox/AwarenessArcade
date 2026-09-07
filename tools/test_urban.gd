extends Node

## Headless smoke test for the street and the credibility economy.
##
##   godot --headless --path . res://tools/test_urban.tscn
##
## The cast is meant to grow. Interview doors used to be three hand-placed nodes
## in the scene file, which silently capped it at three; they are built from a
## table now, and this suite is what catches the table and the buildings drifting
## apart.

const URBAN_SCENE := "res://scenes/exploration/urban_exterior.tscn"

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
	var view: Node = load(URBAN_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _gate_of(case_path: String) -> int:
	var file := FileAccess.open(case_path, FileAccess.READ)
	if file == null:
		return -1
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	var person: Dictionary = (parsed as Dictionary).get("person", {})
	return int(person.get("min_credibility", 0))


func _run() -> void:
	print("\n--- street and credibility economy smoke test ---")
	await _test_doors()
	await _test_credibility_economy()
	await _test_locked_case()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures.size() > 0 else 0)


# Losing Marco used to strand the player: he is the only route to Elena, so the
# street had nothing left to offer and no ending existed.
func _test_locked_case() -> void:
	print("
[a case that cannot be carried further]")
	SessionState.reset_session()
	var view := await _open()
	_check(view.portal.prompt_text == "Enter the office", "the office reads normally while the case is alive")
	await _close(view)

	SessionState.reset_session()
	SessionState.case_locked = true
	view = await _open()
	_check(view.portal.prompt_text == "File the case as unresolved",
		"a dead case turns the office door into the way out (%s)" % view.portal.prompt_text)
	_check(view.has_method("_file_case_unresolved"), "the street can close an unwinnable case")
	view._file_case_unresolved()
	_check(SessionState.investigation_outcome == "insufficient_evidence",
		"filing it records the lockout ending (%s)" % SessionState.investigation_outcome)
	await _close(view)

	# A flipped suspect outranks the flag - that case is still winnable.
	SessionState.reset_session()
	SessionState.case_locked = true
	SessionState.suspect_flipped = true
	view = await _open()
	_check(view.portal.prompt_text == "Enter the call center",
		"a flipped suspect keeps the confrontation open")
	await _close(view)


func _test_doors() -> void:
	print("\n[one door per interviewee]")
	SessionState.reset_session()
	var view := await _open()

	var expected: int = view.INTERVIEWEES.size()
	_check(view.interview_portals.size() == expected,
		"a portal exists for every interviewee (%d of %d)" % [view.interview_portals.size(), expected])
	_check(view.BLOCK_BUILDINGS.size() >= expected,
		"there is a building for every door (%d buildings, %d doors)" % [view.BLOCK_BUILDINGS.size(), expected])

	# Every door must lead somewhere, and somewhere different.
	var seen_cases := {}
	var placed := 0
	for interview_portal in view.interview_portals:
		var case_path: String = str(view.portal_case_paths.get(interview_portal, ""))
		if not case_path.is_empty():
			seen_cases[case_path] = true
		if interview_portal.global_position != Vector2.ZERO:
			placed += 1
		_check(FileAccess.file_exists(case_path), "door points at a case file that exists (%s)" % case_path.get_file())
	_check(seen_cases.size() == expected, "no two doors open the same case")
	_check(placed == expected, "every door was positioned on a building (%d of %d)" % [placed, expected])

	# Doors that sit on top of each other would be unusable.
	var xs: Array[float] = []
	for interview_portal in view.interview_portals:
		xs.append(interview_portal.global_position.x)
	xs.sort()
	var min_gap := 999999.0
	for i in range(1, xs.size()):
		min_gap = minf(min_gap, xs[i] - xs[i - 1])
	_check(min_gap > 80.0, "doors are far enough apart to enter individually (closest %.0f px)" % min_gap)

	await _close(view)


func _test_credibility_economy() -> void:
	print("\n[the credibility economy]")
	var view := await _open()
	var gates := {}
	for entry in view.INTERVIEWEES:
		gates[str(entry["label"])] = _gate_of(str(entry["case"]))
	await _close(view)

	# A run must always have somewhere to start, or the game is unplayable from
	# the opening frame.
	var start := 50
	var open_at_start := 0
	for label in gates:
		if int(gates[label]) <= start:
			open_at_start += 1
	_check(open_at_start > 0, "at least one witness will talk to a detective who has done nothing yet")

	# ...and not everything, or credibility buys nothing.
	var gated := 0
	for label in gates:
		if int(gates[label]) > start:
			gated += 1
	_check(gated >= 2, "several witnesses are out of reach at the start (got %d)" % gated)

	var distinct := {}
	for label in gates:
		distinct[int(gates[label])] = true
	_check(distinct.size() >= 3, "gates sit at more than one threshold (got %d distinct)" % distinct.size())

	# The lockout the four-ending plan wanted: failing early can put the case
	# further out of reach than it was at the start.
	SessionState.reset_session()
	SessionState.record_interview_outcome("evelyn_marsh", "failure")
	_check(SessionState.detective_credibility < start,
		"a failed interview costs standing (%d)" % SessionState.detective_credibility)
	var reachable_after_failure := 0
	for label in gates:
		if int(gates[label]) <= SessionState.detective_credibility:
			reachable_after_failure += 1
	_check(reachable_after_failure < open_at_start + gated,
		"failing shuts doors that were open before (%d reachable)" % reachable_after_failure)

	# And success opens them again.
	SessionState.reset_session()
	SessionState.record_interview_outcome("evelyn_marsh", "success")
	_check(SessionState.detective_credibility > start,
		"a good interview buys standing (%d)" % SessionState.detective_credibility)
	var reachable_after_success := 0
	for label in gates:
		if int(gates[label]) <= SessionState.detective_credibility:
			reachable_after_success += 1
	_check(reachable_after_success > open_at_start,
		"one good interview opens at least one new door (%d reachable)" % reachable_after_success)
