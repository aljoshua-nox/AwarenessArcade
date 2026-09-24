extends Node

## Headless smoke test for the streets and the credibility economy.
##
##   godot --headless --path . res://tools/test_urban.tscn
##
## The cast is meant to grow. Interview doors used to be three hand-placed nodes
## in the scene file, which silently capped it at three; they are built from a
## table now, and this suite is what catches the table and the buildings drifting
## apart. There is more than one street now, so the layout checks run over every
## district in DISTRICTS, and the transit between them is checked both ways.

const URBAN_SCENE := "res://scenes/exploration/urban_exterior.tscn"
const TERMINAL_SCENE := "res://scenes/exploration/terminal_road.tscn"

# Every walkable district, with what its street is expected to carry. A new
# district is a row here; the layout, door and stop checks then cover it.
const DISTRICTS := [
	{"scene": URBAN_SCENE, "name": "Sampaguita Street", "boards": 1, "min_stops": 5, "cites": "number"},
	{"scene": TERMINAL_SCENE, "name": "Terminal Road", "boards": 0, "min_stops": 2, "cites": "name"},
]

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


func _open(scene_path: String = URBAN_SCENE) -> Node:
	var view: Node = load(scene_path).instantiate()
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
	print("\n--- streets and credibility economy smoke test ---")
	for district in DISTRICTS:
		await _test_doors(district)
		await _test_layout_collisions(district)
		await _test_street_stops(district)
		await _test_street_stops_record(district)
	await _test_cases_unique()
	await _test_transit()
	await _test_credibility_economy()
	await _test_locked_case()
	await _test_statement_budget_doors()
	await _test_briefing_on_arrival()
	await _test_desk_door()
	_test_movement_keys()
	await _test_prompts_and_markers()
	for district in DISTRICTS:
		await _test_lamps_and_junctions(district)

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	# A sound still in the mixer at quit is reported as a leak.
	await AudioManager.settle()
	get_tree().quit(1 if failures.size() > 0 else 0)


# Lampposts alternate sides along the road - never a pair facing each other -
# and never stand in the mouth of a side street, which is road now: a side
# street's tiles run through the main pavement where the two meet, so the
# roads read as connected instead of the pavement cutting the junction.
func _test_lamps_and_junctions(district: Dictionary) -> void:
	print("\n[lamps alternate and the junctions join - %s]" % district["name"])
	var view := await _open(str(district["scene"]))
	var lamps: Array = []
	for x in view.lamp_top_x():
		lamps.append({"x": float(x), "side": "top"})
	for x in view.lamp_bottom_x():
		lamps.append({"x": float(x), "side": "bottom"})
	lamps.sort_custom(func(a, b): return a["x"] < b["x"])
	_check(lamps.size() >= 4, "there are lamps along the road (%d)" % lamps.size())
	var alternates := true
	var spaced := true
	for i in range(1, lamps.size()):
		if lamps[i]["side"] == lamps[i - 1]["side"]:
			alternates = false
		if lamps[i]["x"] - lamps[i - 1]["x"] < 180.0:
			spaced = false
	_check(alternates, "they alternate sides along the road")
	_check(spaced, "and are spread out, not bunched")
	var half: float = view.SIDE_STREET_WIDTH * 0.5 + 30.0
	for lamp in lamps:
		if lamp["side"] == "bottom":
			for street_x in view.side_street_x_positions():
				_check(absf(lamp["x"] - (float(street_x) + view.SIDE_STREET_WIDTH * 0.5)) > half,
					"bottom lamp at %.0f is clear of the side street at %.0f" % [lamp["x"], float(street_x)])
	# The mouth of every side street is road, not pavement: the road strip's
	# tiles start at the main road's edge, a pavement's height above the kerbs.
	var road_tops: Array = []
	var kerb_tops: Array = []
	for child in view.decor.get_children():
		if not (child is Sprite2D) or not child.has_meta("tile"):
			continue
		for street_x in view.side_street_x_positions():
			var road_left: float = float(street_x) + view.SIDE_STREET_SIDEWALK
			if is_equal_approx(child.position.x, road_left) and child.get_meta("tile") == view.TILE_ROAD:
				road_tops.append(child.position.y)
			if is_equal_approx(child.position.x, float(street_x)) and child.get_meta("tile") == view.TILE_SIDEWALK:
				kerb_tops.append(child.position.y)
	_check(road_tops.size() >= view.side_street_x_positions().size() and road_tops.min() <= view.ROAD_END,
		"each side street's road starts at the main road's edge (top %s)" % str(road_tops.min() if road_tops.size() > 0 else "none"))
	_check(kerb_tops.size() >= view.side_street_x_positions().size() and kerb_tops.min() >= view.BOTTOM_PAVEMENT_END,
		"...and its kerbs start below the main pavement (top %s)" % str(kerb_tops.min() if kerb_tops.size() > 0 else "none"))
	await _close(view)


# Losing Marco used to strand the player: he is the only route to Elena, so the
# street had nothing left to offer and no ending existed.
func _test_locked_case() -> void:
	print("\n[a case that cannot be carried further]")
	SessionState.reset_session()
	var view := await _open()
	_check(view.portal.prompt_text == "Enter the offices", "the office reads normally while the case is alive")
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

	# Six statements spent, no testimony, Marco stonewalling: the same door.
	SessionState.reset_session()
	SessionState.statements_taken = SessionState.STATEMENT_BUDGET
	view = await _open()
	_check(SessionState.case_stuck(), "a spent budget with no flipped operator is a stuck case")
	_check(view.portal.prompt_text == "File the case as unresolved",
		"a stuck case turns the office door into the way out too (%s)" % view.portal.prompt_text)
	await _close(view)
	SessionState.reset_session()
	SessionState.statements_taken = SessionState.STATEMENT_BUDGET - 1
	_check(not SessionState.case_stuck(), "one statement left is not stuck")

	# A flipped suspect outranks the flag - that case is still winnable.
	SessionState.reset_session()
	SessionState.case_locked = true
	SessionState.suspect_flipped = true
	view = await _open()
	_check(view.portal.prompt_text.begins_with("Enter the call center"),
		"a flipped suspect keeps the confrontation open")
	# The door says what is still missing, until it is not.
	_check(view.portal.prompt_text.contains("nobody has named the owner"),
		"...and nudges while the owner's name is not in the file (%s)" % view.portal.prompt_text)
	await _close(view)
	SessionState.add_evidence({"id": SessionState.OWNER_NAME_EVIDENCE, "label": "The Name Above The Floors"})
	view = await _open()
	_check(view.portal.prompt_text == "Enter the call center", "with the name in the file the nudge goes")
	await _close(view)

	# A district with no office parks the scene's portal where nothing reaches it.
	SessionState.reset_session()
	view = await _open(TERMINAL_SCENE)
	_check(not view.has_office(), "Terminal Road has no office")
	_check(not view.movement_bounds.has_point(view.portal.global_position),
		"...so its office portal is out of the walkable bounds")
	await _close(view)


func _test_doors(district: Dictionary) -> void:
	print("\n[one door per interviewee - %s]" % district["name"])
	SessionState.reset_session()
	var view := await _open(str(district["scene"]))

	var expected: int = view.interviewees().size()
	_check(view.interview_portals.size() == expected,
		"a portal exists for every interviewee (%d of %d)" % [view.interview_portals.size(), expected])
	# Every row the doors name must have a building per door - and the shop row
	# one more, for the office, where there is one.
	var doors_per_row := {}
	for entry in view.interviewees():
		var row := str(entry.get("row", ""))
		doors_per_row[row] = int(doors_per_row.get(row, 0)) + 1
	for row in doors_per_row:
		var needed: int = int(doors_per_row[row]) + (1 if row == "street" and view.has_office() else 0)
		_check(view.slot_count(row) >= needed,
			"row '%s' has a building per door (%d buildings, %d needed)" % [row, view.slot_count(row), needed])

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


# Buildings are placed by hand-picked x values into ground that already holds
# side streets, trees and pedestrians. An earlier layout put a house in the
# middle of a side street and another one through a tree, which is the kind of
# thing that is obvious on screen and invisible to every other check here. The
# rectangles checked are the ones _build_map() actually drew, not a recompute
# from the tables, so a district that adds a building outside the tables (the
# tower, the site office) is covered too.
func _test_layout_collisions(district: Dictionary) -> void:
	print("\n[nothing is built on top of anything - %s]" % district["name"])
	var view := await _open(str(district["scene"]))

	var building_rects: Array[Rect2] = view.built_buildings
	_check(building_rects.size() >= view.building_row().size() + view.block_buildings().size(),
		"every building in the tables was drawn (%d drawn)" % building_rects.size())

	var obstacle_rects: Array[Rect2] = view.obstacle_rects()
	var tree_rects: Array[Rect2] = view.built_trees
	_check(tree_rects.size() == view.tree_spots().size(),
		"every tree in the table was drawn (%d of %d)" % [tree_rects.size(), view.tree_spots().size()])

	var on_street := 0
	var on_tree := 0
	for rect in building_rects:
		for street in obstacle_rects:
			if rect.intersects(street):
				on_street += 1
		for tree in tree_rects:
			if rect.intersects(tree):
				on_tree += 1
	_check(on_street == 0, "no building is built on a street (%d)" % on_street)
	_check(on_tree == 0, "no building is built through a tree (%d)" % on_tree)

	var overlaps := 0
	for i in range(building_rects.size()):
		for j in range(i + 1, building_rects.size()):
			if building_rects[i].intersects(building_rects[j]):
				overlaps += 1
	_check(overlaps == 0, "no two buildings overlap each other (%d)" % overlaps)

	var off_map := 0
	for rect in building_rects:
		if rect.position.x < 0.0 or rect.position.x + rect.size.x > view.MAP_WIDTH:
			off_map += 1
	_check(off_map == 0, "every building is inside the map (%d off)" % off_map)

	# A label above the top of the map is a name nobody can read - the tower's
	# roof leaves the frame on purpose, its label must not.
	var lost_labels := 0
	for rect in view.built_labels:
		if rect.position.y < 0.0 or rect.position.x < 0.0 or rect.end.x > view.MAP_WIDTH:
			lost_labels += 1
	_check(lost_labels == 0, "every building label is on the map (%d off)" % lost_labels)

	# A pedestrian standing inside a wall looks like a bug even though nothing breaks.
	var buried := 0
	for spot in view.npc_spots():
		var point := Vector2(float(spot["x"]), float(spot["y"]))
		for rect in building_rects:
			if rect.has_point(point):
				buried += 1
	_check(buried == 0, "no pedestrian is standing inside a building (%d)" % buried)

	# A tree is solid over its whole sprite, so one on a road, over a door or a
	# stop, or on top of somebody is a wall the player walks into.
	var doors: Array[Rect2] = []
	for door in view.interview_portals:
		doors.append(_area_rect(door, view.INTERVIEW_PORTAL_SIZE))
	for door in view.exit_doors:
		doors.append(_area_rect(door, view.INTERVIEW_PORTAL_SIZE))
	if view.has_office():
		doors.append(_area_rect(view.portal, view.INTERVIEW_PORTAL_SIZE))
	for stop in view.street_stops:
		doors.append(_area_rect(stop["area"], view.STOP_SIZE))
	var misplaced_trees := 0
	for tree in tree_rects:
		if tree.position.x < 0.0 or tree.end.x > view.MAP_WIDTH or tree.end.y > view.MAP_HEIGHT:
			misplaced_trees += 1
		for street in obstacle_rects:
			if tree.intersects(street):
				misplaced_trees += 1
		for spot in view.npc_spots():
			if tree.has_point(Vector2(float(spot["x"]), float(spot["y"]))):
				misplaced_trees += 1
		for door in doors:
			if tree.intersects(door):
				misplaced_trees += 1
	_check(misplaced_trees == 0, "no tree stands on a road, a person, a door or a stop, or off the map (%d)" % misplaced_trees)

	# Every interviewee must have a building to be placed on.
	var missing := 0
	for entry in view.interviewees():
		var row := str(entry.get("row", ""))
		var slot := int(entry.get("slot", -1))
		if slot < 0 or slot >= view.slot_count(row):
			missing += 1
		if row == "street" and slot == view.office_row_index():
			missing += 1
	_check(missing == 0, "every interviewee has a building slot that exists and is not the office (%d bad)" % missing)

	await _close(view)


# A witness lives on one street. The same case reachable from two districts
# would be two doors to one person.
func _test_cases_unique() -> void:
	print("\n[every case is on exactly one street]")
	var owners := {}
	var duplicated: Array[String] = []
	for district in DISTRICTS:
		var view := await _open(str(district["scene"]))
		for entry in view.interviewees():
			var case_path := str(entry.get("case", ""))
			if owners.has(case_path):
				duplicated.append(case_path.get_file())
			owners[case_path] = district["name"]
		await _close(view)
	_check(duplicated.is_empty(), "no case has a door on two streets (%s)" % ", ".join(duplicated))
	_check(owners.size() >= 6, "the streets between them hold the cast (%d doors)" % owners.size())


# The side street that used to run off the bottom of the map goes somewhere
# now. Each end must point at the other, stand inside its own walkable bounds,
# and land the player inside the other's - just off the way back, not on it.
func _test_transit() -> void:
	print("\n[the side street goes somewhere]")
	SessionState.reset_session()
	var terrace := await _open(URBAN_SCENE)
	var road := await _open(TERMINAL_SCENE)

	_check(terrace.transit_portal != null, "the terrace has a way out")
	_check(road.transit_portal != null, "Terminal Road has a way back")
	if terrace.transit_portal == null or road.transit_portal == null:
		await _close(terrace)
		await _close(road)
		return

	_check(terrace.transit_portal.target_scene == TERMINAL_SCENE, "the terrace's exit leads to Terminal Road")
	_check(road.transit_portal.target_scene == URBAN_SCENE, "Terminal Road's exit leads back to the terrace")
	_check(terrace.movement_bounds.has_point(terrace.transit_portal.global_position),
		"the terrace's exit can be walked to")
	_check(road.movement_bounds.has_point(road.transit_portal.global_position),
		"Terminal Road's exit can be walked to")

	var to_road: Vector2 = terrace.transit()["arrival"]
	var to_terrace: Vector2 = road.transit()["arrival"]
	_check(road.movement_bounds.has_point(to_road), "arriving on Terminal Road lands inside its bounds")
	_check(terrace.movement_bounds.has_point(to_terrace), "arriving on the terrace lands inside its bounds")
	_check(to_road.distance_to(road.transit_portal.global_position) > 40.0,
		"arriving on Terminal Road does not put the player inside the way back")
	_check(to_terrace.distance_to(terrace.transit_portal.global_position) > 40.0,
		"arriving on the terrace does not put the player inside the way back")

	# An exit must not double as a stop or a door.
	var exit_rect := _area_rect(terrace.transit_portal, terrace.INTERVIEW_PORTAL_SIZE)
	var collisions := 0
	for stop in terrace.street_stops:
		if _area_rect(stop["area"], terrace.STOP_SIZE).intersects(exit_rect):
			collisions += 1
	for door in terrace.interview_portals:
		if _area_rect(door, terrace.INTERVIEW_PORTAL_SIZE).intersects(exit_rect):
			collisions += 1
	_check(collisions == 0, "the terrace's exit overlaps no stop or door (%d)" % collisions)

	await _close(terrace)
	await _close(road)

	# Taking the exit sets where the player appears and which street an
	# interview returns to; opening the other district then honours both.
	SessionState.reset_session()
	terrace = await _open(URBAN_SCENE)
	terrace._take_transit()
	_check(SessionState.urban_return_scene == TERMINAL_SCENE,
		"leaving for Terminal Road makes it the street interviews return to")
	_check(SessionState.has_urban_return_spawn and SessionState.urban_return_spawn == to_road,
		"...and sets the arrival point")
	await _close(terrace)
	road = await _open(TERMINAL_SCENE)
	_check(road.player.global_position == to_road,
		"opening Terminal Road puts the player at the arrival point (%s)" % road.player.global_position)
	_check(not SessionState.has_urban_return_spawn, "the arrival point is consumed on use")

	# A door used on Terminal Road returns to Terminal Road, not the terrace.
	road._remember_return_spawn(Vector2(500.0, 500.0))
	_check(SessionState.urban_return_scene == TERMINAL_SCENE,
		"a door on Terminal Road remembers Terminal Road (%s)" % SessionState.urban_return_scene.get_file())
	await _close(road)

	SessionState.reset_session()
	_check(SessionState.urban_return_scene == URBAN_SCENE, "a fresh session starts on Sampaguita Street")


func _test_credibility_economy() -> void:
	print("\n[the credibility economy]")
	var gates := {}
	var open_per_district := {}
	for district in DISTRICTS:
		var view := await _open(str(district["scene"]))
		var open_here := 0
		for entry in view.interviewees():
			var gate := _gate_of(str(entry["case"]))
			gates[str(entry["label"])] = gate
			if gate <= 50:
				open_here += 1
		open_per_district[district["name"]] = [open_here, view.interviewees().size()]
		await _close(view)

	# A run must always have somewhere to start, or the game is unplayable from
	# the opening frame.
	var start := 50
	var open_at_start := 0
	for label in gates:
		if int(gates[label]) <= start:
			open_at_start += 1
	_check(open_at_start > 0, "at least one witness will talk to a detective who has done nothing yet")

	# ...and a street with doors on it must have one of them open at the start,
	# or walking there is a dead trip. A street with no doors yet is allowed.
	for district_name in open_per_district:
		var counts: Array = open_per_district[district_name]
		if int(counts[1]) == 0:
			print("        (%s has no doors yet - skipping the entry-witness check)" % district_name)
			continue
		_check(int(counts[0]) > 0, "%s has a witness the player can open at the start (%d of %d)"
			% [district_name, counts[0], counts[1]])

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


# The street used to be pure transit between doors. These are the things worth
# stopping for, and what they teach is a pattern - the same number, or the same
# name, at door after door - so the checks are about the pattern holding
# together, not about any one line of writing.
func _test_street_stops(district: Dictionary) -> void:
	print("\n[the street is worth walking - %s]" % district["name"])
	SessionState.reset_session()
	var view := await _open(str(district["scene"]))

	var stops: Array = view.street_stops
	_check(stops.size() >= int(district["min_stops"]), "the street has stops on it (%d)" % stops.size())

	# Layout: a stop the player cannot reach, or one buried in a wall, is dead.
	var building_rects: Array[Rect2] = view.built_buildings
	var street_rects: Array[Rect2] = view.obstacle_rects()

	var bounds: Rect2 = view.movement_bounds
	var buried := 0
	var unreachable := 0
	var on_street := 0
	for stop in stops:
		var point: Vector2 = stop["position"]
		if not bounds.has_point(point):
			unreachable += 1
		for rect in building_rects:
			if rect.has_point(point):
				buried += 1
		if bool(stop.get("is_noticeboard", false)):
			for street in street_rects:
				if street.has_point(point):
					on_street += 1
	_check(unreachable == 0, "every stop is inside the walkable bounds (%d outside)" % unreachable)
	_check(buried == 0, "no stop is buried inside a building (%d)" % buried)
	_check(on_street == 0, "the noticeboard is not planted in a side street (%d)" % on_street)

	# Every stop stands on an actual pedestrian, or on a thing the district
	# draws for it (the noticeboard, a hoarding, a door) - or the player walks
	# up to a prompt with nobody and nothing attached to it.
	var npc_points: Array[Vector2] = []
	for spot in view.npc_spots():
		npc_points.append(Vector2(float(spot["x"]), float(spot["y"])))
	var orphaned := 0
	var boards := 0
	for stop in stops:
		if bool(stop.get("is_noticeboard", false)):
			boards += 1
		elif bool(stop.get("is_fixture", false)):
			continue
		elif not npc_points.has(stop["position"]):
			orphaned += 1
	_check(boards == int(district["boards"]), "the street has the noticeboards it should (%d)" % boards)
	_check(orphaned == 0, "every other stop stands on a pedestrian or a fixture (%d floating)" % orphaned)

	# A stop sitting on a door locked the player out of the building: both answer
	# Enter, and the store owner's zone covered the office portal completely, so
	# standing at the door opened the shop dialogue instead. Doors win the
	# keypress now, but an overlap would then hide the stop, so the geometry has
	# to stay clear either way.
	var door_rects: Array[Rect2] = []
	if view.has_office():
		door_rects.append(_area_rect(view.portal, view.INTERVIEW_PORTAL_SIZE))
	for door in view.interview_portals:
		door_rects.append(_area_rect(door, view.INTERVIEW_PORTAL_SIZE))
	if view.transit_portal != null:
		door_rects.append(_area_rect(view.transit_portal, view.INTERVIEW_PORTAL_SIZE))

	var shadowed: Array[String] = []
	var crowded: Array[String] = []
	for stop in stops:
		var area: Area2D = stop["area"]
		var stop_rect := _area_rect(area, view.STOP_SIZE)
		for door_rect in door_rects:
			if stop_rect.intersects(door_rect):
				shadowed.append(str(stop.get("title", "?")))
				break
		# _can_enter_portal() also accepts anything within 120px of the office
		# door, which reaches past the rectangles.
		if view.has_office() and area.global_position.distance_to(view.portal.global_position) <= 120.0:
			crowded.append(str(stop.get("title", "?")))
	_check(shadowed.is_empty(), "no stop overlaps a door or the exit (%s)" % ", ".join(shadowed))
	_check(crowded.is_empty(), "no stop sits inside the office door's reach (%s)" % ", ".join(crowded))

	# Content: each stop has to be openable and has to leave something behind.
	var incomplete := 0
	for stop in stops:
		if str(stop.get("prompt", "")).is_empty() or str(stop.get("title", "")).is_empty():
			incomplete += 1
		if str(stop.get("milestone_title", "")).is_empty():
			incomplete += 1
	_check(incomplete == 0, "every stop has a prompt, a title and a milestone (%d incomplete)" % incomplete)

	var catalogue_ids := _catalogue_ids()
	var bad_tactics: Array[String] = []
	for stop in stops:
		var tid := str(stop.get("tactic_id", ""))
		if not tid.is_empty() and not catalogue_ids.has(tid):
			bad_tactics.append(tid)
	_check(bad_tactics.is_empty(),
		"every tactic a stop unlocks is in the catalogue (bad: %s)" % ", ".join(bad_tactics))

	# The through-line. More than one source has to print it, and it has to be
	# the same string the call floor prints: the operation's number on the
	# terrace, the company's name on Terminal Road.
	var cite_key := "cites_number" if str(district["cites"]) == "number" else "cites_name"
	var cited_string: String = SessionState.OPERATION_NUMBER if cite_key == "cites_number" else SessionState.COMPANY_NAME
	var citing: Array[Dictionary] = []
	for stop in stops:
		if bool(stop.get(cite_key, false)):
			citing.append(stop)
	_check(citing.size() >= 2, "more than one source names the %s (%d)" % [district["cites"], citing.size()])
	var unprinted := 0
	for stop in citing:
		if not view._stop_body(stop).contains(cited_string):
			unprinted += 1
	_check(unprinted == 0, "every source that cites the %s actually prints it (%d silent)" % [district["cites"], unprinted])

	# The poster is the one place the game gives real-world advice outright.
	if int(district["boards"]) > 0:
		var board: Dictionary = {}
		for stop in stops:
			if bool(stop.get("is_noticeboard", false)):
				board = stop
		_check(view._stop_body(board).contains("one-time code"),
			"the noticeboard carries the advice, not just a warning")

	await _close(view)


# Reading a stop has to leave the player with something: a milestone in the
# summary, and the tactic in the notebook where it teaches one.
func _test_street_stops_record(district: Dictionary) -> void:
	print("\n[what the street leaves behind - %s]" % district["name"])
	SessionState.reset_session()
	var view := await _open(str(district["scene"]))

	var first: Dictionary = view.street_stops[0]
	_check(not SessionState.has_reflection_milestone(str(first.get("milestone_title", ""))),
		"the milestone is not recorded before the player reads it")
	view._open_stop(first)
	_check(view.inspection_open, "reading a stop opens the panel")
	_check(not view.player.is_physics_processing(), "the player is held still while reading")
	_check(SessionState.has_reflection_milestone(str(first.get("milestone_title", ""))),
		"reading a stop records its milestone")
	if not str(first.get("tactic_id", "")).is_empty():
		_check(SessionState.has_learned_tactic(str(first.get("tactic_id", ""))),
			"reading a stop unlocks the tactic it teaches")
	view._close_stop()
	_check(not view.inspection_open, "stepping away closes the panel")
	_check(view.player.is_physics_processing(), "the player can move again")

	# One source naming the number is not a pattern. Two is.
	var cite_key := "cites_number" if str(district["cites"]) == "number" else "cites_name"
	_check(not SessionState.has_reflection_milestone(view.pattern_milestone_title()),
		"one source naming the %s is not yet a pattern" % district["cites"])
	var cited := 0
	for stop in view.street_stops:
		if not bool(stop.get(cite_key, false)):
			continue
		view._open_stop(stop)
		view._close_stop()
		cited += 1
		if cited == 2:
			break
	_check(cited == 2, "two sources citing the %s were read (%d)" % [district["cites"], cited])
	_check(SessionState.has_reflection_milestone(view.pattern_milestone_title()),
		"two sources naming the same %s records the pattern" % district["cites"])

	await _close(view)


func _catalogue_ids() -> Array[String]:
	var ids: Array[String] = []
	var file := FileAccess.open("res://resources/tactics/tactic_catalogue.json", FileAccess.READ)
	if file == null:
		return ids
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var entries: Variant = parsed.get("tactics", []) if typeof(parsed) == TYPE_DICTIONARY else parsed
	for entry in entries:
		ids.append(str(entry.get("id", "")))
	return ids


func _area_rect(area: Area2D, fallback: Vector2) -> Rect2:
	var size := fallback
	var shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		size = (shape.shape as RectangleShape2D).size
	return Rect2(area.global_position - size * 0.5, size)


# The budget on the street: the counter is on the HUD, a witness door closes
# when the witness failed or the statements are spent, and the suspects' doors
# never do.
func _test_statement_budget_doors() -> void:
	print("\n[the budget at the doors]")
	SessionState.reset_session()
	var view := await _open()
	_check(view.statements_label.text == "Statements: 0 of %d" % SessionState.STATEMENT_BUDGET,
		"the street shows the budget (%s)" % view.statements_label.text)
	# Standing gates seven doors; it used to be visible only on the summary.
	_check(view.standing_label.text == "Credibility: %d" % SessionState.detective_credibility,
		"the street shows standing (%s)" % view.standing_label.text)
	_check(view.portal_blocked.is_empty(), "a fresh case has every door open")
	await _close(view)

	SessionState.reset_session()
	SessionState.statements_taken = SessionState.STATEMENT_BUDGET
	view = await _open()
	var evelyn := _door_for(view, "interview_case_005.json")
	var marco := _door_for(view, "interview_case_003.json")
	_check(evelyn != null and evelyn.prompt_text.begins_with("No time for another statement"),
		"a spent budget closes a witness's door (%s)" % (evelyn.prompt_text if evelyn else "?"))
	_check(marco != null and marco.prompt_text == "Interrogate Marco Navarro",
		"...and leaves the suspect's open (%s)" % (marco.prompt_text if marco else "?"))
	view.player.global_position = evelyn.global_position
	_check(not view._can_enter_interview(), "Enter at a closed door does nothing")
	view.active_interview_portal = null
	view.player.global_position = marco.global_position
	_check(view._can_enter_interview(), "Enter at the suspect's door still works")
	await _close(view)

	SessionState.reset_session()
	SessionState.closed_witnesses.append("kevin_d")
	view = await _open()
	var kevin := _door_for(view, "interview_case_002.json")
	evelyn = _door_for(view, "interview_case_005.json")
	_check(kevin != null and kevin.prompt_text == "Kevin Dizon won't talk to you again",
		"a failed witness's door says so (%s)" % (kevin.prompt_text if kevin else "?"))
	_check(evelyn != null and evelyn.prompt_text == "Speak with Evelyn Marsh", "...and the others are untouched")
	_check(view.portal_blocked.size() == 1, "exactly one door is closed")
	await _close(view)

	# Terminal Road reads the same budget.
	SessionState.reset_session()
	SessionState.statements_taken = SessionState.STATEMENT_BUDGET
	view = await _open(TERMINAL_SCENE)
	var trish := _door_for(view, "interview_case_008.json")
	var dennis := _door_for(view, "interview_case_013.json")
	_check(trish != null and view.portal_blocked.has(trish), "a spent budget closes Trish's door")
	_check(dennis != null and not view.portal_blocked.has(dennis), "...and not the closer's")
	await _close(view)


func _door_for(view: Node, case_file: String) -> ScenePortal:
	for door in view.interview_portals:
		if str(view.portal_case_paths.get(door, "")).ends_with(case_file):
			return door
	return null


# The first street of the case opens the case file on the player, once. The
# flag is set by the two ways into the investigation and consumed here, so a
# street instantiated on its own - every other test in this file - never opens
# it unasked.
func _test_briefing_on_arrival() -> void:
	print("
[the briefing on arrival]")
	SessionState.reset_session()
	var view := await _open()
	_check(not CaseJournal.is_open, "a street opened on its own shows no briefing")
	await _close(view)

	SessionState.briefing_pending = true
	view = await _open()
	await get_tree().process_frame
	_check(CaseJournal.is_open, "arriving with the briefing pending opens the journal")
	_check(CaseJournal.current_tab == CaseJournal.TAB_BRIEF, "on the brief")
	_check(not SessionState.briefing_pending, "and consumes the flag")
	CaseJournal.close()
	await _close(view)

	view = await _open()
	await get_tree().process_frame
	_check(not CaseJournal.is_open, "coming back to the street does not show it again")
	await _close(view)

	SessionState.briefing_pending = true
	SessionState.reset_investigation()
	_check(not SessionState.briefing_pending, "a reset clears a pending briefing")


# The detective's desk has a door on Sampaguita Street: the case starts inside
# it, and walking out lands the player where a fresh street puts them anyway.
func _test_desk_door() -> void:
	print("\n[the desk's door]")
	SessionState.reset_session()
	var terrace := await _open(URBAN_SCENE)
	_check(terrace.exit_doors.size() == 1, "Sampaguita Street has the desk's door (got %d)" % terrace.exit_doors.size())
	if terrace.exit_doors.is_empty():
		await _close(terrace)
		return
	var door: ScenePortal = terrace.exit_doors[0]
	_check(door.target_scene == SessionState.DESK_SCENE, "it leads to the desk")
	_check(terrace.movement_bounds.has_point(door.global_position), "it can be walked to")
	_check(terrace.player_spawn.distance_to(door.global_position) <= 40.0,
		"the street's default spawn is at the desk's door - leaving the desk for the first time lands there")
	var outside := door.global_position + Vector2(0.0, 20.0)
	var inside_a_wall := 0
	for rect in terrace.built_buildings:
		if rect.has_point(outside) or rect.has_point(terrace.player_spawn):
			inside_a_wall += 1
	_check(inside_a_wall == 0, "neither the spawn nor the return point is inside a building")

	# The door is a door: standing at it must not read as the office or a stop.
	terrace.player.global_position = door.global_position
	terrace.active_portal = door
	_check(not terrace._can_enter_portal(), "standing at the desk's door is not standing at the office")
	terrace.active_portal = null
	var door_rect := _area_rect(door, terrace.INTERVIEW_PORTAL_SIZE)
	var collisions := 0
	for stop in terrace.street_stops:
		if _area_rect(stop["area"], terrace.STOP_SIZE).intersects(door_rect):
			collisions += 1
	for other in terrace.interview_portals:
		if _area_rect(other, terrace.INTERVIEW_PORTAL_SIZE).intersects(door_rect):
			collisions += 1
	_check(collisions == 0, "the desk's door overlaps no stop or interview door (%d)" % collisions)
	await _close(terrace)

	var road := await _open(TERMINAL_SCENE)
	_check(road.exit_doors.is_empty(), "Terminal Road has no desk")
	await _close(road)


# The hint on every walkable scene promises WASD or arrows. The player reads
# the move_* actions, so both sets have to be on them - the ui_* actions it
# used to read are arrows only, and WASD did nothing.
func _test_movement_keys() -> void:
	print("
[movement keys]")
	var expected := {
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
	}
	for action in expected:
		_check(InputMap.has_action(action), "%s exists" % action)
		var keys: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys.append((event as InputEventKey).keycode)
		for key in expected[action]:
			_check(keys.has(key), "%s answers to %s" % [action, OS.get_keycode_string(key)])
	var player_script: Script = load("res://scripts/exploration/exploration_player.gd")
	_check(player_script.source_code.contains("\"move_left\", \"move_right\", \"move_up\", \"move_down\""),
		"the player reads the move_* actions")


# Prompts float over the door, the stop or the exit the player is standing at,
# and every interview door wears a marker saying how things stand with the
# person behind it - the same reading the journal's People page gives.
func _test_prompts_and_markers() -> void:
	print("\n[prompts over doors, markers on them]")
	SessionState.reset_session()
	var view := await _open()
	# The street's spawn is at the desk's door, so the first thing the player
	# sees is that door's prompt. The door is an Area2D, and an overlap is only
	# reported on the physics step after the body lands in it - one process
	# frame is not always enough, which made this check flake. Wait for the
	# physics server to have seen the spawn before reading the bubble.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(view.prompt_bubble != null and view.prompt_bubble.visible and view.prompt_bubble.text == "Go in to your desk",
		"at spawn the prompt is the desk's door (%s)" % (view.prompt_bubble.text if view.prompt_bubble else "?"))
	_check(not view.portal_label.visible and not view.interview_label.visible, "the corner labels stay off")
	view._on_portal_exited(view.active_portal)
	_check(not view.prompt_bubble.visible, "stepping off it hides the prompt")

	var evelyn := _door_for(view, "interview_case_005.json")
	view._on_interview_entered(evelyn)
	_check(view.prompt_bubble.visible and view.prompt_bubble.text == evelyn.prompt_text,
		"standing at a door shows its prompt (%s)" % view.prompt_bubble.text)
	_check(view.prompt_bubble.global_position.y < evelyn.global_position.y - 40.0, "...above the door")
	var center_x: float = view.prompt_bubble.global_position.x + view.prompt_bubble.size.x * 0.5
	_check(absf(center_x - evelyn.global_position.x) < 2.0, "...centered on it")
	view._on_interview_exited(evelyn)
	_check(not view.prompt_bubble.visible, "leaving the door hides it")

	view._on_portal_entered(view.portal)
	_check(view.prompt_bubble.visible and view.prompt_bubble.text == view.portal.prompt_text, "the office door prompts too")
	_check(view._can_enter_portal(), "and counts as in reach of the office")
	view._on_portal_exited(view.portal)
	_check(not view.prompt_bubble.visible and view.active_portal == null, "leaving it clears both")

	var stop: Dictionary = view.street_stops[0]
	view._on_stop_entered(view.player, stop)
	_check(view.prompt_bubble.visible and view.prompt_bubble.text == str(stop.get("prompt", "")), "a stop prompts")
	view._open_stop(stop)
	_check(not view.prompt_bubble.visible, "reading it hides the prompt")
	view._close_stop()
	_check(view.prompt_bubble.visible, "closing brings the prompt back")
	view._on_stop_exited(view.player, stop)
	_check(not view.prompt_bubble.visible, "walking off hides it")

	# Markers: one per interview door, all "?" on a fresh case.
	var doors: Array = view.interview_portals
	_check(view.door_markers.size() == doors.size(), "every interview door has a marker (%d of %d)" % [view.door_markers.size(), doors.size()])
	var fresh := 0
	for door in doors:
		if str(view.door_markers.get(door, {}).get("glyph", "")) == "?":
			fresh += 1
	_check(fresh == doors.size(), "a fresh case marks every door as unvisited (%d)" % fresh)
	await _close(view)

	# The markers follow the case.
	SessionState.record_interview_outcome("evelyn_marsh", "success")
	SessionState.record_interview_outcome("maria_santos", "partial", true)
	SessionState.record_interview_outcome("kevin_d", "failure")
	SessionState.record_statement("kevin_d", "Victim", "failure", false)
	SessionState.record_interview_outcome("marco_navarro", "failure")
	view = await _open()
	_check(_glyph(view, "interview_case_005.json") == "\u2713", "a statement on record is a check")
	_check(_glyph(view, "interview_case_001.json") == "!", "turned away for want of standing is a bang")
	_check(_glyph(view, "interview_case_002.json") == "\u00d7", "a witness who will not talk again is a cross")
	_check(_glyph(view, "interview_case_003.json") == "!", "a suspect who shut the door is a bang, not a cross - his door still opens")
	_check(_glyph(view, "interview_case_007.json") == "?", "an unvisited door stays a question mark")
	await _close(view)

	SessionState.reset_session()
	SessionState.statements_taken = SessionState.STATEMENT_BUDGET
	view = await _open()
	_check(_glyph(view, "interview_case_007.json") == "\u00d7", "a spent budget crosses out the witnesses not yet taken")
	_check(_glyph(view, "interview_case_003.json") == "?", "...but not the suspect")
	await _close(view)


func _glyph(view: Node, case_file: String) -> String:
	return str(view.door_markers.get(_door_for(view, case_file), {}).get("glyph", "?"))
