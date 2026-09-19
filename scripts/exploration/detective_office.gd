extends "res://scripts/exploration/office_interior.gd"

## The detective's desk: where the case starts, and the one door on Sampaguita
## Street that is the player's own. Both ways into the investigation land here
## rather than on the street, so the case opens on a desk with a file on it
## instead of on a sidewalk with nothing said.
##
## The room is the call floor's (shell, stations, inspection panel, exit door
## are all office_interior.gd's); what is in it is not. Two of its stations are
## pickups: the case file on the desk hands over the journal and opens the
## brief, the notebook on the side table hands over the Tactics tab. The exit door
## will not open until both are taken - a light gate that guarantees the brief
## is read once. There is no director's door and no stairwell.

const DESK_STREET_SCENE := "res://scenes/exploration/urban_exterior.tscn"

const DESK_POSITION := Vector2(640.0, 470.0)
const TABLE_POSITION := Vector2(1120.0, 340.0)
const MAP_POSITION := Vector2(430.0, 268.0)

# The object sheet has no locker (the tall white unit is a fridge), so the
# notebook waits on a table by the window instead.
const TABLE_UNTAKEN_BODY := "A small table by the window with your things on it: a jacket over the chair, a bottle of water, and a notebook with half its pages used. The used pages are from the last case. The rest are for this one."
const TABLE_UNTAKEN_NOTE := "The notebook records every tactic you can name. A caller's trick, written down, is a trick you will recognize the next time it is tried on you. Press N at any time to read it."
const TABLE_TAKEN_BODY := "The table by the window, with the notebook gone from it. The jacket can stay."
const TABLE_TAKEN_NOTE := "Press N at any time to open the notebook."


func _init() -> void:
	map_title = "Anti-Fraud Desk"
	map_hint = "WASD or arrows to walk  \u00b7  Enter to pick up or read  \u00b7  J journal  \u00b7  Esc menu"
	portal_target_scene = DESK_STREET_SCENE
	# A quiet room: the call floor's bed, well down, until a room tone exists.
	ambience_path = "res://assets/audio/ambience/call_floor.ogg"
	ambience_db = -22.0
	# The door sits between the map board and the first window, and the
	# player starts under it: the wall's left end is under the HUD's lines,
	# where the STREET plate and the door prompt were unreadable.
	exit_door_position = Vector2(520.0, 262.0)
	player_spawn = Vector2(520.0, 330.0)


# No director here, and no floor above.
func stairs_target() -> String:
	return ""


func director_unlocked() -> bool:
	return false


func exit_prompt() -> String:
	if not tools_collected():
		return "Take the case file and your notebook before you go"
	return "Head out to Sampaguita Street"


func tools_collected() -> bool:
	return SessionState.journal_collected and SessionState.notebook_collected


# --- The room -----------------------------------------------------------------

func _build_back_wall_fittings() -> void:
	# The way out, clear of the HUD's corner.
	_add_prop(OFFICE_WALLS, WALL_DOORWAY, Vector2(exit_door_position.x, WALL_BASE + 4.0), 2.1, -30)
	_add_wall_plate(Vector2(exit_door_position.x, 118.0), "STREET")

	for x in [620.0, 860.0]:
		_add_prop(OFFICE_WALLS, WALL_WINDOW, Vector2(x, WALL_BASE - 6.0), 1.9, -32)

	# The corkboard the district map is pinned to, and a smaller board of
	# notices nobody has taken down.
	_add_prop(OFFICE_WALLS, WALL_PANEL, Vector2(MAP_POSITION.x, WALL_BASE - 34.0), 2.0, -32)
	_add_prop(OFFICE_WALLS, WALL_PANEL, Vector2(1040.0, WALL_BASE - 34.0), 1.4, -32)


# Two desks, not forty. Yours, in the middle of the room, and the sergeant's
# by the window, with nobody at it.
func _build_call_floor() -> void:
	_add_prop(OFFICE_OBJECTS, OBJ_CHAIR, Vector2(DESK_POSITION.x, DESK_POSITION.y - 42.0), 2.1, -12)
	_add_prop(OFFICE_OBJECTS, OBJ_DESK_FRONT, Vector2(DESK_POSITION.x, DESK_POSITION.y - 8.0), 2.6, -10)
	_add_prop(OFFICE_OBJECTS, OBJ_MONITOR, Vector2(DESK_POSITION.x + 22.0, DESK_POSITION.y - 44.0), 1.6, -11)

	_add_prop(OFFICE_OBJECTS, OBJ_CHAIR, Vector2(900.0, 296.0), 2.1, -12)
	_add_prop(OFFICE_OBJECTS, OBJ_DESK_BACK, Vector2(900.0, 326.0), 2.4, -10)
	_add_prop(OFFICE_OBJECTS, OBJ_MONITOR, Vector2(882.0, 296.0), 1.6, -11)


func _build_props() -> void:
	_add_prop(OFFICE_OBJECTS, OBJ_FILE_CABINET, Vector2(128.0, 340.0), 2.1, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_FILE_CABINET, Vector2(128.0, 440.0), 2.1, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_DESK_BACK, Vector2(TABLE_POSITION.x, TABLE_POSITION.y - 10.0), 2.4, -10)
	_add_prop(OFFICE_OBJECTS, OBJ_COOLER, Vector2(1168.0, 440.0), 2.3, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_PLANT, Vector2(126.0, 640.0), 2.4, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_PLANT, Vector2(1170.0, 640.0), 2.4, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_SOFA, Vector2(230.0, 668.0), 2.2, -8)
	_build_stations()


func _build_stations() -> void:
	_add_station({
		"title": "Your desk",
		"prompt": _desk_prompt(),
		"is_brief": true,
	}, DESK_POSITION)

	var table := {
		"title": "The side table",
		"prompt": _table_prompt(),
		"is_notebook": true,
		"marker": TextStyle.MARK_HINT,
		"note_color": TextStyle.COLOR_HINT,
	}
	_set_table_text(table)
	_add_station(table, TABLE_POSITION)

	_add_station({
		"title": "The district map",
		"prompt": "Study the map",
		"body": "A street map pinned to the corkboard, the two streets the complaints came from traced over in marker: Sampaguita Street, with its shop row along the top and the houses on the grass below, and Terminal Road, down the second side street - a bus bay, a building site, a tower with a lobby. Somebody has written across the bottom in pencil: START WITH WHOEVER WILL OPEN THE DOOR.",
		"note": "Two streets, a dozen doors. The journal's People page keeps track of which ones have opened.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
	}, MAP_POSITION)


func _desk_prompt() -> String:
	return "Read the case file" if SessionState.journal_collected else "Take the case file"


func _table_prompt() -> String:
	return "Examine the table" if SessionState.notebook_collected else "Take your notebook"


func _set_table_text(station: Dictionary) -> void:
	var taken := SessionState.notebook_collected
	station["body"] = TABLE_TAKEN_BODY if taken else TABLE_UNTAKEN_BODY
	station["note"] = TABLE_TAKEN_NOTE if taken else TABLE_UNTAKEN_NOTE


# --- Pickups ------------------------------------------------------------------

# The desk opens the brief itself - the case file IS the journal - and the
# first time is when the journal is handed over. The table reads like any
# other station, but taking the notebook changes what it says afterwards.
func _open_inspection(station: Dictionary) -> void:
	if bool(station.get("is_brief", false)):
		if not SessionState.journal_collected:
			SessionState.journal_collected = true
			SessionState.briefing_pending = false
			_refresh_tools()
		CaseJournal.show_briefing()
		return
	# The table's first read is the notebook being taken, so it is rendered
	# before the pickup changes what the table says.
	var taking_notebook := bool(station.get("is_notebook", false)) and not SessionState.notebook_collected
	super(station)
	if taking_notebook:
		SessionState.notebook_collected = true
		_refresh_tools()


# Every prompt that depends on what has been picked up, re-read.
func _refresh_tools() -> void:
	for station in stations:
		if bool(station.get("is_brief", false)):
			station["prompt"] = _desk_prompt()
		elif bool(station.get("is_notebook", false)):
			station["prompt"] = _table_prompt()
			_set_table_text(station)
	if not active_station.is_empty() and station_label.visible:
		station_label.text = str(active_station.get("prompt", ""))
	portal.prompt_text = exit_prompt()
	if active_portal == portal:
		prompt_bubble.show_above(portal.global_position, portal.prompt_text, EXIT_LIFT)
	CaseJournal.refresh_availability()


# The door stays shut until the tools are taken. The prompt says so.
func _can_enter_portal() -> bool:
	return tools_collected() and super()
