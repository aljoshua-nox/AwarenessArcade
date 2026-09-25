extends Node2D

## A floor of the operation's building. This script is floor 3 - the call floor
## the office door on Sampaguita Street opens onto, Elena's - and it is also the
## base for every other floor: the room, the walls, the stations, the inspection
## panel and the director's door are shared, and what differs between floors is
## answered by the functions under "What a floor is". office_floor_four.gd is
## the tech-support floor upstairs, Rowena's. The takedown ending names three
## floors; the building has two you can walk.

@export var map_title: String = ""
@export var map_hint: String = "WASD or arrows to walk  \u00b7  Enter to examine  \u00b7  J journal  \u00b7  Esc menu"
## The looping bed under this floor, if the file exists (see assets/audio/ambience/).
@export var ambience_path: String = "res://assets/audio/ambience/call_floor.ogg"
@export var ambience_db: float = -12.0
@export_file("*.tscn") var portal_target_scene: String = "res://scenes/exploration/urban_exterior.tscn"
@export var player_spawn: Vector2 = Vector2(190, 320)
@export var movement_bounds: Rect2 = Rect2(Vector2(96, 232), Vector2(1096, 432))

@onready var decor: Node2D = %Decor
@onready var player: ExplorationPlayer = %Player
@onready var title_label: Label = %MapTitle
@onready var hint_label: Label = %MapHint
@onready var portal_label: Label = %PortalLabel
@onready var portal: ScenePortal = %Portal
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var hud: CanvasLayer = $HUD

const TextStyle := preload("res://scripts/systems/text_style.gd")
const InspectPanel := preload("res://scripts/systems/inspect_panel.gd")
const PromptBubble := preload("res://scripts/exploration/prompt_bubble.gd")

const CONFRONTATION_SCENE := "res://scenes/investigation/interview.tscn"
const CASE_ELENA := "res://resources/cases/interview_case_004.json"
const FLOOR_FOUR_SCENE := "res://scenes/exploration/office_floor_four.tscn"

# The rooms are LimeZu's Modern Interiors (free), by part name - see
# interior_parts.gd, which also says why the sheets are cut down. The water
# cooler is the one Little Bits object left: the bonus board is "by the water
# cooler", and the free pack has none.
const Parts := preload("res://scripts/exploration/interior_parts.gd")
const INTERIORS: Texture2D = preload("res://assets/art/maps/modern_interiors/interiors.png")
const ROOM_BUILDER: Texture2D = preload("res://assets/art/maps/modern_interiors/room_builder.png")
const OFFICE_OBJECTS := preload("res://assets/art/maps/Little_Bits_Office_tileset/Office tiles/Little_Bits_office_objects.png")
const OBJ_COOLER := Rect2(16.0, 64.0, 16.0, 24.0)

# Above the wall is the cut-away the pack draws its rooms with: dark, edged
# where it meets the room.
const CEILING_COLOR := Color(0.13, 0.13, 0.17, 1.0)
const ROOM_EDGE_COLOR := Color(0.93, 0.93, 0.95, 1.0)

# The wall is three tiles high at 2x - its trim, a plain course, its
# baseboard - which puts a door at about a head above the player.
const WALL_BASE := 216.0
const WALL_FACE_TOP := WALL_BASE - 96.0
const SIDE_WALL_WIDTH := 72.0
const NEAR_WALL_HEIGHT := 44.0
const DESK_ROW_BACK := 336.0
const DESK_ROW_FRONT := 486.0
const DESK_COLUMNS := [340.0, 500.0, 660.0, 820.0, 980.0]
# The director's end of the floor, in parquet: right of here, down to here.
const DIRECTOR_FLOOR := Rect2(960.0, WALL_BASE, 320.0, 160.0)

const STATION_SIZE := Vector2(104.0, 92.0)
const DIRECTOR_DOOR_POSITION := Vector2(1090.0, 268.0)
# Where the way out sits on the back wall. The floors keep it at the left;
# the desk moves it along, because with the camera fenced to the room the
# left end of that wall sits under the HUD's text.
var exit_door_position := Vector2(190.0, 262.0)
# The stairwell up, on the back wall between the last window and the director's
# carpet - the stairs sit beside the director's office because the other
# director's office sits above it. STAIRS_ARRIVAL is where the floor above
# puts a player coming back down: just in front of these stairs. Going up
# sets nothing - the floor above starts its player at its own way down.
const STAIRS_POSITION := Vector2(900.0, 268.0)
const STAIRS_ARRIVAL := Vector2(900.0, 330.0)

var stations: Array[Dictionary] = []
var active_station: Dictionary = {}
var inspect_panel: InspectPanel
var inspect_title: Label
var inspect_body: RichTextLabel
var station_label: Label
# The prompt that floats over the active station or the exit door.
var prompt_bubble: Label
var active_portal: ScenePortal = null
const STATION_LIFT := 104.0
const EXIT_LIFT := 60.0
var standing_label: Label
var statements_label: Label
var objective_label: Label
var inspection_open: bool = false


# --- What a floor is ----------------------------------------------------------
# Override these on another floor. The defaults are floor 3.

# The case the director's door opens when it is unlocked.
func confrontation_case() -> String:
	return CASE_ELENA


func director_nameplate() -> String:
	return "E. CRUZ"


# Whether this floor's confrontation is the one that ends the case. Elena's is;
# Rowena's, upstairs, is one of the two places the owner's name comes from.
func confrontation_ends_case() -> bool:
	return true


# What unlocks the director's door on this floor. Elena's opens when Marco
# flips; Rowena's when Bea turns.
func director_unlocked() -> bool:
	return SessionState.suspect_flipped


func director_locked_note() -> String:
	return "Marco Navarro, the operator at the shops on Sampaguita Street, is the way through this door. Until a caller on this floor is willing to name the person running it, there is nothing here to open."


# The scene the stairwell leads up to, or empty on a floor with no stairs up.
func stairs_target() -> String:
	return FLOOR_FOUR_SCENE


# The street door opens straight onto this floor, so the way out says what
# the game skips: the operation rents the upper floors of an ordinary
# building, and the lobby and the second floor are somebody else's.
func exit_prompt() -> String:
	return "Down three flights, past the lobby, to the street"


# The room's paint and floor: a Parts.WALL_ROWS key and a Parts.FLOORS key.
# Every room has its own, so the stairs lead somewhere that looks like
# somewhere else.
func wall_style() -> String:
	return "beige"


func floor_style() -> String:
	return "carpet"


# Whether the way out is drawn as a staircase (a floor above's way down)
# rather than a door.
func exit_is_stairs() -> bool:
	return false


func _ready() -> void:
	# The call floor is named after the operation's own door, one copy of which
	# lives on SessionState; a subclass that set its own title in _init keeps it.
	if map_title.is_empty():
		map_title = "%s - 3F" % SessionState.CALL_FLOOR_NAME
	title_label.text = map_title
	hint_label.text = map_hint
	portal_label.visible = false
	prompt_bubble = PromptBubble.new()
	add_child(prompt_bubble)
	AudioManager.stop_music()
	AudioManager.play_ambience(ambience_path, ambience_db)
	# Coming down the stairs lands in front of them, not at the street door.
	# Only the floor above sets this, on its way out (_take_exit).
	if SessionState.has_office_return_spawn:
		player.global_position = SessionState.office_return_spawn
		SessionState.has_office_return_spawn = false
	else:
		player.global_position = player_spawn
	player.movement_bounds = movement_bounds
	portal.target_scene = portal_target_scene
	portal.prompt_text = exit_prompt()
	portal.player_entered.connect(_on_portal_entered)
	portal.player_exited.connect(_on_portal_exited)
	_build_hud()
	_build_map()
	_fence_camera()


# The rooms are one screen; the player's camera would otherwise centre on a
# player standing by the left wall and show half a screen of nothing beyond
# it. Seen at the desk, where the spawn is nearest the wall. The streets do
# the same against their map size.
func _fence_camera() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var room := get_viewport().get_visible_rect().size
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room.x)
	camera.limit_bottom = int(room.y)
	camera.reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if inspection_open:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_close_inspection()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		# The menu asks before abandoning the run; this used to go straight to
		# the main menu, which resets the session.
		CaseJournal.open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not active_station.is_empty():
		if bool(active_station.get("is_confrontation", false)):
			SessionState.pending_case_path = confrontation_case()
			_transition_to_scene(CONFRONTATION_SCENE)
		elif bool(active_station.get("is_stairs", false)):
			_take_stairs()
		else:
			_open_inspection(active_station)
	elif event.is_action_pressed("ui_accept") and _can_enter_portal():
		_take_exit()


# Up the stairs. The floor above starts its player at its own door down, so
# there is nothing to remember here. This used to set the return spawn on the
# way UP, and the floor above consumed it on arrival - the player climbed the
# stairs and appeared where the stairs are on THIS floor, across the room from
# the door they had just come through.
func _take_stairs() -> void:
	_transition_to_scene(stairs_target())


# Out through the door on the back wall. On the call floor that is the street;
# a floor above overrides this to land in front of the stairs it came up.
func _take_exit() -> void:
	_transition_to_scene(portal.target_scene)


# --- Inspection UI -----------------------------------------------------------

func _build_hud() -> void:
	# Kept off screen: prompts float over the station now. Stays a node so the
	# capture tools and tests that read it keep working.
	station_label = Label.new()
	station_label.visible = false
	hud.add_child(station_label)

	# The same two numbers the street shows, in the same place, so walking
	# indoors does not lose sight of the case.
	standing_label = Label.new()
	standing_label.offset_left = 20.0
	standing_label.offset_top = 74.0
	standing_label.text = "Credibility: %d" % SessionState.detective_credibility
	standing_label.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_HINT))
	hud.add_child(standing_label)

	statements_label = Label.new()
	statements_label.offset_left = 20.0
	statements_label.offset_top = 102.0
	statements_label.text = "Statements: %d of %d" % [SessionState.statements_taken, SessionState.STATEMENT_BUDGET]
	statements_label.add_theme_color_override("font_color",
		Color.html(TextStyle.COLOR_WRONG) if SessionState.statements_left() <= 1 else Color.html(TextStyle.COLOR_HINT))
	hud.add_child(statements_label)

	# On a plate, because indoors this line falls on the back wall's trim.
	# Offset so the text still lines up with the lines above it.
	objective_label = Label.new()
	objective_label.theme_type_variation = &"HudLine"
	objective_label.offset_left = 9.0
	objective_label.offset_top = 127.0
	objective_label.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_TACTIC))
	hud.add_child(objective_label)
	_refresh_objective_label()

	inspect_panel = InspectPanel.new("Enter or Esc to step back")
	hud.add_child(inspect_panel)
	inspect_title = inspect_panel.title_label
	inspect_body = inspect_panel.body


func _open_inspection(station: Dictionary) -> void:
	inspection_open = true
	inspect_panel.open(str(station.get("title", "")), _station_body(station))
	prompt_bubble.hide_bubble()
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)

	var milestone_title := str(station.get("milestone_title", ""))
	if not milestone_title.is_empty():
		SessionState.record_reflection_milestone(milestone_title, str(station.get("milestone_detail", "")))


func _refresh_objective_label() -> void:
	var tracked: Dictionary = CaseJournal.tracked_objective()
	objective_label.visible = not tracked.is_empty()
	objective_label.text = "> %s" % str(tracked.get("title", ""))


func _close_inspection() -> void:
	_refresh_objective_label()
	inspection_open = false
	inspect_panel.visible = false
	player.set_physics_process(true)
	if not active_station.is_empty():
		_show_station_prompt(active_station)


func _station_body(station: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(TextStyle.dialogue(str(station.get("body", ""))))
	if bool(station.get("is_ledger", false)):
		parts.append(_build_call_log_text())
	var marker := str(station.get("marker", TextStyle.MARK_SCENE))
	var note := str(station.get("note", ""))
	if not note.is_empty():
		parts.append(TextStyle.system(marker, note, str(station.get("note_color", TextStyle.COLOR_HINT))))
	return "\n\n".join(parts)


# The payoff: the operation's own ledger, listing the people the player called
# themselves during the prologue.
func _build_call_log_text() -> String:
	if SessionState.prologue_call_log.is_empty():
		return TextStyle.system(TextStyle.MARK_SCENE,
			"The most recent page has been torn out. Whoever worked this list last took their numbers with them.",
			TextStyle.COLOR_HINT)

	var lines: Array[String] = []
	lines.append("[font=%s][color=#%s]     THIS WEEK - FLOOR 3[/color][/font]" % [TextStyle.FONT_SYSTEM, TextStyle.COLOR_NARRATION])
	for entry in SessionState.prologue_call_log:
		var entry_name := str(entry.get("name", "Unknown"))
		var outcome := str(entry.get("outcome", ""))
		var payout := int(entry.get("payout", 0))
		var note := ""
		var tone: String = TextStyle.COLOR_NARRATION
		# Every non-paying call used to print as "hung up", including ones the
		# player simply ran out of time on. The ledger is the operation's own
		# record - it should be accurate about what happened on each number.
		if outcome == SessionState.CALL_SUCCESS:
			note = "transferred %s - RECONTACT" % TextStyle.currency(payout)
			tone = TextStyle.COLOR_WRONG
		elif outcome == SessionState.CALL_PARTIAL:
			note = "partial %s - warm, try again" % TextStyle.currency(payout)
			tone = TextStyle.COLOR_WRONG
		elif outcome == SessionState.CALL_HUNG_UP:
			note = "no payout - hung up early, still live"
			tone = TextStyle.COLOR_TACTIC
		elif outcome == SessionState.CALL_ESCALATED:
			note = "line pulled mid-call - rest the number, still live"
			tone = TextStyle.COLOR_HINT
		elif outcome == SessionState.CALL_TIMEOUT:
			note = "cut off - shift ended mid-call, still live"
			tone = TextStyle.COLOR_HINT
		elif outcome == SessionState.CALL_ABORTED:
			note = "dropped by operator - unworked, still live"
			tone = TextStyle.COLOR_HINT
		else:
			note = "no payout - refused, still live"
			tone = TextStyle.COLOR_TACTIC
		lines.append("[font=%s][color=#%s]     %s ......... %s[/color][/font]" % [TextStyle.FONT_SYSTEM, tone, entry_name, note])
	lines.append(TextStyle.system(TextStyle.MARK_HARM,
		"You made these calls. Nobody on this page was removed from it - not even the ones who refused. A refusal only marks the number as answered by a real person, which is worth more than a number that never picks up.",
		TextStyle.COLOR_WRONG))
	return "\n".join(lines)


# --- Map ---------------------------------------------------------------------

func _build_map() -> void:
	_clear_decor()
	stations.clear()
	active_station = {}

	var viewport_size := get_viewport().get_visible_rect().size
	_build_room_shell(viewport_size)
	_build_back_wall_fittings()
	_build_call_floor()
	_build_props()

	portal.global_position = exit_door_position
	portal_label.visible = false
	station_label.visible = false


func _build_room_shell(viewport_size: Vector2) -> void:
	_add_solid_rect(Vector2.ZERO, Vector2(viewport_size.x, WALL_FACE_TOP), CEILING_COLOR, -40)
	_add_tiled_rect(_wall_texture(wall_style()), Vector2(0.0, WALL_FACE_TOP),
		Vector2(viewport_size.x, WALL_BASE - WALL_FACE_TOP), Parts.SCALE, -40)
	var floor_texture := _extract_texture(ROOM_BUILDER, Parts.FLOORS[floor_style()])
	_add_tiled_rect(floor_texture, Vector2(0.0, WALL_BASE), Vector2(viewport_size.x, viewport_size.y - WALL_BASE), Parts.SCALE, -36)

	# Side and near walls, cut away like the ceiling, so the room reads as a
	# room instead of a floor that runs off every edge.
	var floor_height := viewport_size.y - WALL_BASE
	_add_solid_rect(Vector2(0.0, WALL_BASE), Vector2(SIDE_WALL_WIDTH, floor_height), CEILING_COLOR, -34)
	_add_solid_rect(Vector2(SIDE_WALL_WIDTH - 4.0, WALL_BASE), Vector2(4.0, floor_height - NEAR_WALL_HEIGHT + 4.0), ROOM_EDGE_COLOR, -33)
	_add_solid_rect(Vector2(viewport_size.x - SIDE_WALL_WIDTH, WALL_BASE), Vector2(SIDE_WALL_WIDTH, floor_height), CEILING_COLOR, -34)
	_add_solid_rect(Vector2(viewport_size.x - SIDE_WALL_WIDTH, WALL_BASE), Vector2(4.0, floor_height - NEAR_WALL_HEIGHT + 4.0), ROOM_EDGE_COLOR, -33)
	_add_solid_rect(Vector2(0.0, viewport_size.y - NEAR_WALL_HEIGHT), Vector2(viewport_size.x, NEAR_WALL_HEIGHT), CEILING_COLOR, -34)
	_add_solid_rect(Vector2(SIDE_WALL_WIDTH - 4.0, viewport_size.y - NEAR_WALL_HEIGHT), Vector2(viewport_size.x - SIDE_WALL_WIDTH * 2.0 + 8.0, 4.0), ROOM_EDGE_COLOR, -33)


# One column of a wall style, trim to baseboard: the style's top tile, the
# plain lower half of it twice over, then its bottom tile. Tiled across the
# back wall.
func _wall_texture(style: String) -> ImageTexture:
	var sheet := ROOM_BUILDER.get_image()
	var top := int(Parts.WALL_ROWS[style]) * 16
	var x := int(Parts.WALL_COLUMN_X)
	var column := Image.create(16, 48, false, sheet.get_format())
	column.blit_rect(sheet, Rect2i(x, top, 16, 16), Vector2i(0, 0))
	column.blit_rect(sheet, Rect2i(x, top + 8, 16, 8), Vector2i(0, 16))
	column.blit_rect(sheet, Rect2i(x, top + 8, 16, 8), Vector2i(0, 24))
	column.blit_rect(sheet, Rect2i(x, top + 16, 16, 16), Vector2i(0, 32))
	return ImageTexture.create_from_image(column)


func _build_back_wall_fittings() -> void:
	# Way out, at the left of the back wall.
	_add_exit()

	for x in [430.0, 620.0]:
		_add_part("blinds", Vector2(x, WALL_BASE - 20.0), -32)

	# The shift schedule the player can read, and the floor's map.
	_add_part("pin_board", Vector2(300.0, WALL_BASE - 18.0), -32)
	_add_part("map", Vector2(760.0, WALL_BASE - 22.0), -32)

	# The director's office: a door with its blinds down, and a parquet floor
	# outside it.
	var parquet := _extract_texture(ROOM_BUILDER, Parts.FLOORS["parquet"])
	_add_tiled_rect(parquet, DIRECTOR_FLOOR.position, DIRECTOR_FLOOR.size, Parts.SCALE, -35)
	_add_part("office_door", Vector2(DIRECTOR_DOOR_POSITION.x, WALL_BASE), -30)
	_add_wall_plate(Vector2(DIRECTOR_DOOR_POSITION.x, 138.0), director_nameplate())

	# The stairwell up, where there is a floor above.
	if not stairs_target().is_empty():
		_add_part("stairs", Vector2(STAIRS_POSITION.x, WALL_BASE + 64.0), -30)
		_add_wall_plate(Vector2(STAIRS_POSITION.x, 138.0), "STAIRS - 4F")


func _add_exit() -> void:
	if exit_is_stairs():
		_add_part("stairs", Vector2(exit_door_position.x, WALL_BASE + 64.0), -30)
	else:
		_add_part("wall_door", Vector2(exit_door_position.x, WALL_BASE), -30)


# Two rows of benches, three desks each with a monitor, back to back: the back
# row's operators face the wall, the front row's face the room from behind
# their desks - so the aisle between the rows is where the chairs are, and the
# walkway past the exhibits along the bottom stays open. Benches and chairs are
# solid; the monitors sit inside their bench's block.
func _build_call_floor() -> void:
	for x in DESK_COLUMNS:
		for seat in [-32.0, 0.0, 32.0]:
			_add_part("chair_front", Vector2(x + seat, DESK_ROW_FRONT - 30.0), -12, true)
		_add_part("desk_bench", Vector2(x, DESK_ROW_BACK), -10, true)
		_add_part("desk_bench", Vector2(x, DESK_ROW_FRONT), -10, true)
		for seat in [-32.0, 0.0, 32.0]:
			_add_part("monitor", Vector2(x + seat, DESK_ROW_BACK - 24.0), -9)
			_add_part("chair_back", Vector2(x + seat, DESK_ROW_BACK + 26.0), -8, true)
			_add_part("monitor", Vector2(x + seat, DESK_ROW_FRONT - 24.0), -9)


func _build_props() -> void:
	# Water cooler and cabinets belong against the walls, not mid-room.
	_add_prop(OFFICE_OBJECTS, OBJ_COOLER, Vector2(1168.0, 330.0), 2.3, -8, true)
	_add_part("drawers", Vector2(1168.0, 430.0), -8, true)
	_add_part("bookcase", Vector2(128.0, 340.0), -8, true)
	_add_part("drawers", Vector2(128.0, 440.0), -8, true)

	_add_part("plant_tree", Vector2(126.0, 640.0), -8, true)
	_add_part("palm", Vector2(1170.0, 640.0), -8, true)
	_add_part("sofa", Vector2(230.0, 668.0), -8, true)

	_build_stations()
	_add_director_door()
	_add_stairs()


func _build_stations() -> void:
	_add_station({
		"title": "Script binders",
		"prompt": "Examine the script binders",
		"body": "Three laminated scripts sit in a rack on the nearest desk, thumbed soft at the corners. BANK VERIFICATION. DEVICE SUPPORT. PRIZE RELEASE. Someone has written in the margin of the first one, in ballpoint: \"if they say they'll call the bank back, remind them the account is frozen NOW.\"",
		"note": "Three different stories, one identical mechanism: every script is built to remove the few minutes a person needs to check. That is the product being sold here, not the story. None of it goes in the file: a script proves that a floor reads scripts, and the license downstairs says it may. What makes it a case is a person it was read to, on record.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"milestone_title": "The Scripts Are Written Down",
		"milestone_detail": "The call floor keeps three interchangeable scripts, each engineered around denying the victim time to verify.",
	}, Vector2(360.0, 612.0))
	_add_part("bookcase_pair", Vector2(360.0, 604.0), -10, true)

	_add_station({
		"title": "The call list",
		"prompt": "Examine the call list",
		"body": "A ring binder, open on the supervisor's desk. Column headings in marker: NAME. NUMBER. LAST RESULT. Names run down the page in a dozen different hands, some crossed out, most not. Taped inside the cover, on a strip of card worn soft at the edges, is the number every desk on this floor calls from: %s." % SessionState.OPERATION_NUMBER,
		"is_ledger": true,
		"note": "Names and numbers are not victims until one of them says what the call did. This is what a raid will seize - once there is a case to raid for.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
		"milestone_title": "The List Has Your Handwriting On It",
		"milestone_detail": "The operation's ledger holds the victims the player called during the prologue - proof that a scam list is a durable asset, not a one-time thing.",
	}, Vector2(660.0, 612.0))
	_add_part("chair_front", Vector2(660.0, 572.0), -12, true)
	_add_part("desk_ledger", Vector2(660.0, 604.0), -10, true)

	_add_station({
		"title": "Bonus board",
		"prompt": "Examine the bonus board",
		"body": "A whiteboard by the water cooler, a printed and laminated header across the top of it: %s - FLOOR 3 - MONTHLY INCENTIVES. Names down the left, a running tally to the right. The last column is headed ESCALATED and carries a bonus rate double the others. Under it, someone has drawn a small smiling face." % SessionState.CALL_FLOOR_NAME.to_upper(),
		"note": "The operation pays more when the victim becomes distressed, because distress is what stops people thinking. Fear is not a side effect of the business model here. It is the business model.",
		"note_color": TextStyle.COLOR_WRONG,
		"marker": TextStyle.MARK_HARM,
		"milestone_title": "Distress Is A Performance Metric",
		"milestone_detail": "The floor pays a doubled bonus rate for calls that escalate a victim into distress - harm is deliberately incentivized, not incidental.",
	}, Vector2(1000.0, 612.0))
	_add_part("whiteboard", Vector2(1000.0, 606.0), -10, true)

	_add_station({
		"title": "The shift schedule",
		"prompt": "Examine the shift schedule",
		"body": "Forty desks. Forty headsets, most still warm. A printed schedule is taped beside the door: the heaviest staffing runs late morning and early evening, with a thinner night shift, and a note beside it on who to call: SENIORS / SHIFT WORKERS.",
		"note": "The hours are chosen the way the scripts are. Late morning finds retired people at home alone; the night shift finds people too tired to argue. Being targeted is not evidence of being careless - it is evidence of being reachable at a particular hour.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_SCENE,
		"milestone_title": "Forty Desks, Not One Caller",
		"milestone_detail": "The operation runs forty stations on a schedule timed to catch specific groups when they are most isolated or most tired.",
	}, Vector2(300.0, 268.0))


func _add_station(data: Dictionary, station_position: Vector2) -> void:
	var area := Area2D.new()
	area.position = station_position
	area.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = STATION_SIZE
	shape.shape = rect
	area.add_child(shape)
	decor.add_child(area)

	var entry := data.duplicate()
	entry["area"] = area
	stations.append(entry)

	area.body_entered.connect(_on_station_entered.bind(entry))
	area.body_exited.connect(_on_station_exited.bind(entry))

	_add_floor_marker(station_position)


func _add_floor_marker(marker_position: Vector2) -> void:
	var size := Vector2(26.0, 26.0)
	var top_left := marker_position + Vector2(-size.x * 0.5, -78.0)
	_add_solid_rect(top_left + Vector2(2.0, 2.0), size, Color(0.06, 0.06, 0.09, 0.75), 4)
	_add_solid_rect(top_left, size, Color.html(TextStyle.COLOR_TACTIC), 5)

	var marker := Label.new()
	marker.text = "?"
	marker.position = top_left
	marker.size = size
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	marker.add_theme_font_size_override("font_size", 18)
	marker.add_theme_color_override("font_color", Color(0.10, 0.09, 0.05))
	marker.add_theme_constant_override("outline_size", 0)
	marker.z_index = 6
	decor.add_child(marker)


# Elena is now confronted from inside the floor she runs, so the player walks
# past the evidence of the operation before reaching her.
func _add_director_door() -> void:
	var locked := not director_unlocked()
	var body := "A door at the back of the floor, blinds drawn. The nameplate reads %s - FLOOR DIRECTOR." % director_nameplate()
	if locked:
		body += " The handle doesn't move, and nobody on this floor is going to open it for a stranger."
	else:
		body += " There is someone moving behind the blinds."

	var prompt := "Examine the director's door"
	if not locked:
		prompt = "Confront the Operation"
		# The last door before the ending: say what is still missing.
		if confrontation_ends_case() and not SessionState.owner_named():
			prompt += " - nobody has named the owner yet"
	var data := {
		"title": "Floor director's office",
		"prompt": prompt,
		"body": body,
		"is_confrontation": not locked,
	}
	if locked:
		data["note"] = director_locked_note()
		data["note_color"] = TextStyle.COLOR_HINT
		data["marker"] = TextStyle.MARK_HINT

	_add_station(data, DIRECTOR_DOOR_POSITION)


# The stairwell is a station so it shares the prompt and the marker, but Enter
# on it climbs rather than reads. Always open: the floor above can be walked
# before its director can be reached, which is where the player learns which
# witnesses she answers for.
func _add_stairs() -> void:
	if stairs_target().is_empty():
		return
	_add_station({
		"title": "Stairwell",
		"prompt": "Take the stairs to the fourth floor",
		"is_stairs": true,
	}, STAIRS_POSITION)


func _on_station_entered(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	active_station = entry
	if not inspection_open:
		_show_station_prompt(entry)


func _on_station_exited(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	if active_station.get("area", null) == entry.get("area", null):
		active_station = {}
		prompt_bubble.hide_bubble()


func _show_station_prompt(station: Dictionary) -> void:
	var area: Area2D = station.get("area", null)
	var anchor: Vector2 = area.global_position if area != null else player.global_position
	station_label.text = str(station.get("prompt", ""))
	prompt_bubble.show_above(anchor, station_label.text, STATION_LIFT)


# --- Existing map helpers ----------------------------------------------------

func _clear_decor() -> void:
	for child in decor.get_children():
		child.queue_free()


func _add_solid_rect(top_left: Vector2, size: Vector2, color: Color, z_index: int) -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.centered = false
	sprite.position = top_left
	sprite.scale = size
	sprite.z_index = z_index
	decor.add_child(sprite)


# Pull one tile out of an atlas so it can be repeated. Sprite2D's texture_repeat
# tiles the whole texture, not a region, so the region has to become its own
# texture first.
func _extract_texture(source: Texture2D, region: Rect2) -> ImageTexture:
	var sub := source.get_image().get_region(Rect2i(region))
	return ImageTexture.create_from_image(sub)


func _add_tiled_rect(texture: Texture2D, top_left: Vector2, size: Vector2, tile_scale: float, z_index: int) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = top_left
	sprite.scale = Vector2(tile_scale, tile_scale)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, size.x / tile_scale, size.y / tile_scale)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z_index
	decor.add_child(sprite)


# Place an atlas sprite standing on the floor: base_position is where its
# bottom edge sits, which makes laying furniture out far easier than centers.
# `solid` blocks the player over the whole sprite, the way the street's props
# do - there is no y-sorting in here, so any overlap would draw the player on
# top of the desk. The stations' zones reach past their furniture, so a solid
# desk still prompts from the floor in front of it.
func _add_prop(texture: Texture2D, region: Rect2, base_position: Vector2, prop_scale: float, z_index: int,
		solid: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = true
	sprite.scale = Vector2(prop_scale, prop_scale)
	var size := region.size * prop_scale
	sprite.position = base_position - Vector2(0.0, size.y * 0.5)
	sprite.z_index = z_index
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)
	if solid:
		_add_wall_segment(base_position - Vector2(size.x * 0.5, size.y), size)


# A named part of the interiors sheet (interior_parts.gd), standing on
# base_position at the rooms' scale.
func _add_part(part: String, base_position: Vector2, z_index: int, solid: bool = false) -> void:
	_add_prop(INTERIORS, Parts.PARTS[part], base_position, Parts.SCALE, z_index, solid)


# The same body the street's buildings and props stand behind.
func _add_wall_segment(top_left: Vector2, size: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = top_left + size * 0.5
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	decor.add_child(body)


func _add_wall_plate(center: Vector2, text: String) -> void:
	var size := Vector2(104.0, 20.0)
	var top_left := center - size * 0.5
	_add_solid_rect(top_left, size, Color(0.10, 0.10, 0.14, 0.85), -25)
	var label := Label.new()
	label.text = text
	label.position = top_left
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_TACTIC))
	label.z_index = -24
	decor.add_child(label)


func _add_sprite(texture: Texture2D, position: Vector2, scale: Vector2, z_index: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = position
	sprite.z_index = z_index
	sprite.scale = scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)


func _can_enter_portal() -> bool:
	if active_portal == portal:
		return true
	return player.global_position.distance_to(portal.global_position) <= 120.0


func _on_portal_entered(portal_node: ScenePortal) -> void:
	active_portal = portal_node
	prompt_bubble.show_above(portal_node.global_position, portal_node.prompt_text, EXIT_LIFT)


func _on_portal_exited(portal_node: ScenePortal) -> void:
	if active_portal == portal_node:
		active_portal = null
		prompt_bubble.hide_bubble()


func _transition_to_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	AudioManager.play_sfx("door")
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.25)
	tween.finished.connect(func () -> void:
		SessionState.go_to_scene(scene_path)
	)
