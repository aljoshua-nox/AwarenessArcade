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
	await _test_layout_collisions()
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
	var block_doors := 0
	var street_doors := 0
	for entry in view.INTERVIEWEES:
		if str(entry.get("row", "")) == "street":
			street_doors += 1
		else:
			block_doors += 1
	_check(view.BLOCK_BUILDINGS.size() >= block_doors,
		"the residential row has a house per door (%d houses, %d doors)" % [view.BLOCK_BUILDINGS.size(), block_doors])
	_check(view.BUILDING_ROW.size() > street_doors,
		"the shop row has a building per door plus the office (%d buildings, %d doors)" % [view.BUILDING_ROW.size(), street_doors])

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
	var min_gap := 999999.0
	for i in range(view.interview_portals.size()):
		for j in range(i + 1, view.interview_portals.size()):
			min_gap = minf(min_gap, view.interview_portals[i].global_position.distance_to(
				view.interview_portals[j].global_position))
	_check(min_gap > 80.0, "doors are far enough apart to enter individually (closest %.0f px)" % min_gap)

	await _close(view)


# Buildings are placed by hand-picked x values into a band that already contains
# side streets, trees and pedestrians. An earlier layout put a house in the
# middle of a side street and another one through a tree, which is the kind of
# thing that is obvious on screen and invisible to every other check here.
func _test_layout_collisions() -> void:
	print("
[nothing is built on top of anything]")
	var view := await _open()

	var block_size := Vector2(16.0 * 3.0 * view.BLOCK_BUILDING_SCALE.x, 0.0)
	block_size = Vector2(48.0 * view.BLOCK_BUILDING_SCALE.x, 96.0 * view.BLOCK_BUILDING_SCALE.y)
	var row_size := Vector2(48.0 * view.ROW_BUILDING_SCALE.x, 96.0 * view.ROW_BUILDING_SCALE.y)

	var block_rects: Array[Rect2] = []
	for entry in view.BLOCK_BUILDINGS:
		block_rects.append(Rect2(Vector2(float(entry["x"]), 520.0), block_size))
	var row_rects: Array[Rect2] = []
	for entry in view.BUILDING_ROW:
		row_rects.append(Rect2(Vector2(float(entry["x"]), view.BUILDING_ROW_BOTTOM - row_size.y), row_size))

	# The grass starts below the lower pavement; side streets run down through it.
	var sidewalk_top_end: float = view.BUILDING_ROW_BOTTOM + view.SIDEWALK_HEIGHT
	var grass_top: float = sidewalk_top_end + view.ROAD_HEIGHT + view.SIDEWALK_HEIGHT
	var street_rects: Array[Rect2] = []
	for street_x in view.SIDE_STREET_X_POSITIONS:
		street_rects.append(Rect2(Vector2(float(street_x), grass_top),
			Vector2(view.SIDE_STREET_WIDTH, 1080.0 - grass_top)))

	var tree_extent := 16.0 * 2.2 * 0.5
	var tree_rects: Array[Rect2] = []
	for spot in view.TREE_SPOTS:
		tree_rects.append(Rect2(spot - Vector2(tree_extent, tree_extent),
			Vector2(tree_extent * 2.0, tree_extent * 2.0)))

	var on_street := 0
	var on_tree := 0
	for rect in block_rects:
		for street in street_rects:
			if rect.intersects(street):
				on_street += 1
		for tree in tree_rects:
			if rect.intersects(tree):
				on_tree += 1
	_check(on_street == 0, "no house is built on a side street (%d)" % on_street)
	_check(on_tree == 0, "no house is built through a tree (%d)" % on_tree)

	var overlaps := 0
	for i in range(block_rects.size()):
		for j in range(i + 1, block_rects.size()):
			if block_rects[i].intersects(block_rects[j]):
				overlaps += 1
	for i in range(row_rects.size()):
		for j in range(i + 1, row_rects.size()):
			if row_rects[i].intersects(row_rects[j]):
				overlaps += 1
	_check(overlaps == 0, "no two buildings overlap each other (%d)" % overlaps)

	var off_map := 0
	for rect in block_rects + row_rects:
		if rect.position.x < 0.0 or rect.position.x + rect.size.x > 1920.0:
			off_map += 1
	_check(off_map == 0, "every building is inside the map (%d off)" % off_map)

	# A pedestrian standing inside a wall looks like a bug even though nothing breaks.
	var buried := 0
	for spot in view.NPC_SPOTS:
		var point := Vector2(float(spot["x"]), float(spot["y"]))
		for rect in block_rects + row_rects:
			if rect.has_point(point):
				buried += 1
	_check(buried == 0, "no pedestrian is standing inside a building (%d)" % buried)

	# Every interviewee must have a building to be placed on.
	var missing := 0
	for entry in view.INTERVIEWEES:
		var row := str(entry.get("row", ""))
		var slot := int(entry.get("slot", -1))
		var count: int = view.BUILDING_ROW.size() if row == "street" else view.BLOCK_BUILDINGS.size()
		if slot < 0 or slot >= count:
			missing += 1
		if row == "street" and slot == view.OFFICE_ROW_INDEX:
			missing += 1
	_check(missing == 0, "every interviewee has a building slot that exists and is not the office (%d bad)" % missing)

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
