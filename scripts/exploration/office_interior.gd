extends Node2D

@export var map_title: String = "Call Floor"
@export var map_hint: String = "Move with WASD or arrow keys. Press Enter to examine what you find."
@export_file("*.tscn") var portal_target_scene: String = "res://scenes/exploration/urban_exterior.tscn"
@export var player_spawn: Vector2 = Vector2(190, 320)
@export var movement_bounds: Rect2 = Rect2(Vector2(96, 240), Vector2(1096, 424))

@onready var decor: Node2D = %Decor
@onready var player: ExplorationPlayer = %Player
@onready var title_label: Label = %MapTitle
@onready var hint_label: Label = %MapHint
@onready var portal_label: Label = %PortalLabel
@onready var portal: ScenePortal = %Portal
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var hud: CanvasLayer = $HUD

const TextStyle := preload("res://scripts/systems/text_style.gd")

const CONFRONTATION_SCENE := "res://scenes/investigation/interview.tscn"
const CASE_ELENA := "res://resources/cases/interview_case_004.json"

# wall_tiles.png and floor_tiles.png are ATLASES, not single images - the old
# map stretched each whole sheet across the screen as one sprite, which is why
# the top of the room read as unfinished. Everything below is cut from them by
# region instead.
const OFFICE_WALLS := preload("res://assets/art/maps/office/wall_tiles.png")
const OFFICE_FLOOR := preload("res://assets/art/maps/office/floor_tiles.png")
const OFFICE_OBJECTS := preload("res://assets/art/maps/Little_Bits_Office_tileset/Office tiles/Little_Bits_office_objects.png")

const FLOOR_TILE := Rect2(48.0, 0.0, 32.0, 32.0)
const FLOOR_CARPET := Rect2(80.0, 0.0, 32.0, 32.0)

const WALL_WINDOW := Rect2(24.0, 8.0, 48.0, 64.0)
const WALL_DOORWAY := Rect2(88.0, 8.0, 48.0, 58.0)
const WALL_PANEL := Rect2(144.0, 80.0, 32.0, 32.0)
const WALL_BENCH := Rect2(89.0, 80.0, 46.0, 24.0)
const WALL_COUNTER := Rect2(0.0, 80.0, 70.0, 32.0)
const WALL_POST := Rect2(144.0, 29.0, 6.0, 34.0)

const OBJ_DESK_BACK := Rect2(66.0, 1.0, 30.0, 16.0)
const OBJ_DESK_FRONT := Rect2(66.0, 17.0, 32.0, 15.0)
const OBJ_CHAIR := Rect2(33.0, 32.0, 14.0, 16.0)
const OBJ_MONITOR := Rect2(17.0, 6.0, 14.0, 15.0)
const OBJ_CABINET := Rect2(96.0, 2.0, 16.0, 26.0)
const OBJ_FILE_CABINET := Rect2(48.0, 64.0, 16.0, 32.0)
const OBJ_COOLER := Rect2(16.0, 64.0, 16.0, 24.0)
const OBJ_PLANT := Rect2(48.0, 48.0, 17.0, 18.0)
const OBJ_SOFA := Rect2(99.0, 70.0, 26.0, 19.0)
const OBJ_EASEL := Rect2(70.0, 66.0, 20.0, 26.0)
const OBJ_DOOR := Rect2(128.0, 50.0, 32.0, 34.0)
const OBJ_SHELF := Rect2(96.0, 32.0, 16.0, 14.0)

const CEILING_COLOR := Color(0.13, 0.13, 0.17, 1.0)
const WALL_UPPER := Color(0.64, 0.64, 0.78, 1.0)
const WALL_LOWER := Color(0.55, 0.55, 0.70, 1.0)
const WALL_BASEBOARD := Color(0.38, 0.38, 0.52, 1.0)

const WALL_TOP := 56.0
const WALL_BASE := 216.0
const SIDE_WALL_WIDTH := 72.0
const NEAR_WALL_HEIGHT := 44.0
const DESK_ROW_BACK := 336.0
const DESK_ROW_FRONT := 486.0
const DESK_COLUMNS := [340.0, 500.0, 660.0, 820.0, 980.0]

const STATION_SIZE := Vector2(104.0, 92.0)
const DIRECTOR_DOOR_POSITION := Vector2(1090.0, 268.0)
const EXIT_DOOR_POSITION := Vector2(190.0, 262.0)

var stations: Array[Dictionary] = []
var active_station: Dictionary = {}
var inspect_panel: PanelContainer
var inspect_title: Label
var inspect_body: RichTextLabel
var station_label: Label
var inspection_open: bool = false


func _ready() -> void:
	title_label.text = map_title
	hint_label.text = map_hint
	player.global_position = player_spawn
	player.movement_bounds = movement_bounds
	portal.target_scene = portal_target_scene
	portal.prompt_text = "Return to the street"
	portal.player_entered.connect(_on_portal_entered)
	portal.player_exited.connect(_on_portal_exited)
	_build_hud()
	_build_map()


func _unhandled_input(event: InputEvent) -> void:
	if inspection_open:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_close_inspection()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		SessionState.go_to_scene("res://scenes/main_menu/main_menu.tscn")
	elif event.is_action_pressed("ui_accept") and not active_station.is_empty():
		if bool(active_station.get("is_confrontation", false)):
			SessionState.pending_case_path = CASE_ELENA
			_transition_to_scene(CONFRONTATION_SCENE)
		else:
			_open_inspection(active_station)
	elif event.is_action_pressed("ui_accept") and _can_enter_portal():
		_transition_to_scene(portal.target_scene)


# --- Inspection UI -----------------------------------------------------------

func _build_hud() -> void:
	station_label = Label.new()
	station_label.offset_left = 20.0
	station_label.offset_top = 102.0
	station_label.visible = false
	hud.add_child(station_label)

	inspect_panel = PanelContainer.new()
	inspect_panel.set_anchors_preset(Control.PRESET_CENTER)
	inspect_panel.anchor_left = 0.5
	inspect_panel.anchor_right = 0.5
	inspect_panel.anchor_top = 0.5
	inspect_panel.anchor_bottom = 0.5
	inspect_panel.offset_left = -380.0
	inspect_panel.offset_right = 380.0
	inspect_panel.offset_top = -230.0
	inspect_panel.offset_bottom = 230.0
	inspect_panel.visible = false
	hud.add_child(inspect_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	inspect_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	inspect_title = Label.new()
	inspect_title.add_theme_font_size_override("font_size", 22)
	column.add_child(inspect_title)

	# Station text grows well past the panel, so it has to scroll (see AGENTS.md).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	inspect_body = RichTextLabel.new()
	inspect_body.bbcode_enabled = true
	inspect_body.fit_content = true
	inspect_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspect_body)

	var close_hint := Label.new()
	close_hint.text = "Press Enter or Esc to step back"
	close_hint.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_NARRATION))
	close_hint.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	close_hint.add_theme_font_size_override("font_size", 13)
	column.add_child(close_hint)


func _open_inspection(station: Dictionary) -> void:
	inspection_open = true
	inspect_title.text = str(station.get("title", ""))
	inspect_body.text = _station_body(station)
	inspect_panel.visible = true
	station_label.visible = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)

	var milestone_title := str(station.get("milestone_title", ""))
	if not milestone_title.is_empty():
		SessionState.record_reflection_milestone(milestone_title, str(station.get("milestone_detail", "")))


func _close_inspection() -> void:
	inspection_open = false
	inspect_panel.visible = false
	player.set_physics_process(true)
	if not active_station.is_empty():
		station_label.text = str(active_station.get("prompt", ""))
		station_label.visible = true


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
			note = "transferred %d - RECONTACT" % payout
			tone = TextStyle.COLOR_WRONG
		elif outcome == SessionState.CALL_PARTIAL:
			note = "partial %d - warm, try again" % payout
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

	portal.global_position = EXIT_DOOR_POSITION
	portal_label.visible = false
	station_label.visible = false


func _build_room_shell(viewport_size: Vector2) -> void:
	_add_solid_rect(Vector2.ZERO, Vector2(viewport_size.x, WALL_TOP), CEILING_COLOR, -40)
	_add_solid_rect(Vector2(0.0, WALL_TOP), Vector2(viewport_size.x, 96.0), WALL_UPPER, -40)
	_add_solid_rect(Vector2(0.0, WALL_TOP + 96.0), Vector2(viewport_size.x, WALL_BASE - WALL_TOP - 96.0), WALL_LOWER, -40)
	_add_solid_rect(Vector2(0.0, WALL_BASE - 8.0), Vector2(viewport_size.x, 8.0), WALL_BASEBOARD, -38)

	# Proper tiled floor, cut from the atlas rather than one stretched sheet.
	var floor_texture := _extract_texture(OFFICE_FLOOR, FLOOR_TILE)
	_add_tiled_rect(floor_texture, Vector2(0.0, WALL_BASE), Vector2(viewport_size.x, viewport_size.y - WALL_BASE), 2.0, -36)

	# A carpeted strip marks the director's end of the floor.
	var carpet_texture := _extract_texture(OFFICE_FLOOR, FLOOR_CARPET)
	_add_tiled_rect(carpet_texture, Vector2(960.0, WALL_BASE), Vector2(viewport_size.x - 960.0, 160.0), 2.0, -35)

	# Side and near walls, so the room reads as a room instead of a floor that
	# runs off every edge.
	var floor_height := viewport_size.y - WALL_BASE
	_add_solid_rect(Vector2(0.0, WALL_BASE), Vector2(SIDE_WALL_WIDTH, floor_height), WALL_LOWER, -34)
	_add_solid_rect(Vector2(SIDE_WALL_WIDTH - 8.0, WALL_BASE), Vector2(8.0, floor_height), WALL_BASEBOARD, -33)
	_add_solid_rect(Vector2(viewport_size.x - SIDE_WALL_WIDTH, WALL_BASE), Vector2(SIDE_WALL_WIDTH, floor_height), WALL_LOWER, -34)
	_add_solid_rect(Vector2(viewport_size.x - SIDE_WALL_WIDTH, WALL_BASE), Vector2(8.0, floor_height), WALL_BASEBOARD, -33)
	_add_solid_rect(Vector2(0.0, viewport_size.y - NEAR_WALL_HEIGHT), Vector2(viewport_size.x, NEAR_WALL_HEIGHT), WALL_LOWER, -34)
	_add_solid_rect(Vector2(0.0, viewport_size.y - NEAR_WALL_HEIGHT), Vector2(viewport_size.x, 8.0), WALL_BASEBOARD, -33)


func _build_back_wall_fittings() -> void:
	# Way out, at the left of the back wall.
	_add_prop(OFFICE_WALLS, WALL_DOORWAY, Vector2(EXIT_DOOR_POSITION.x, WALL_BASE + 4.0), 2.1, -30)

	for x in [430.0, 620.0]:
		_add_prop(OFFICE_WALLS, WALL_WINDOW, Vector2(x, WALL_BASE - 6.0), 1.9, -32)

	# Noticeboards. The left one is the shift rota the player can read.
	_add_prop(OFFICE_WALLS, WALL_PANEL, Vector2(300.0, WALL_BASE - 34.0), 2.0, -32)
	_add_prop(OFFICE_WALLS, WALL_PANEL, Vector2(800.0, WALL_BASE - 34.0), 1.7, -32)

	# The director's office: an actual door, not an unmarked patch of wall.
	_add_prop(OFFICE_OBJECTS, OBJ_DOOR, Vector2(DIRECTOR_DOOR_POSITION.x, WALL_BASE + 8.0), 2.9, -30)
	_add_wall_plate(Vector2(DIRECTOR_DOOR_POSITION.x, 118.0), "E. CRUZ")


func _build_call_floor() -> void:
	for x in DESK_COLUMNS:
		_add_prop(OFFICE_OBJECTS, OBJ_CHAIR, Vector2(x, DESK_ROW_BACK - 30.0), 2.1, -12)
		_add_prop(OFFICE_OBJECTS, OBJ_DESK_BACK, Vector2(x, DESK_ROW_BACK), 2.4, -10)
		_add_prop(OFFICE_OBJECTS, OBJ_MONITOR, Vector2(x - 18.0, DESK_ROW_BACK - 30.0), 1.6, -11)

	for x in DESK_COLUMNS:
		_add_prop(OFFICE_OBJECTS, OBJ_CHAIR, Vector2(x, DESK_ROW_FRONT - 34.0), 2.1, -12)
		_add_prop(OFFICE_OBJECTS, OBJ_DESK_FRONT, Vector2(x, DESK_ROW_FRONT), 2.4, -10)
		_add_prop(OFFICE_OBJECTS, OBJ_MONITOR, Vector2(x + 16.0, DESK_ROW_FRONT - 36.0), 1.6, -11)

	# Thin divider posts between stations. (The pack's partition_1/2 sprites are
	# cubicle corner pieces meant to be assembled - standalone they read as
	# floating brown slabs, so the wall sheet's posts are used instead.)
	for x in [420.0, 580.0, 740.0, 900.0]:
		_add_prop(OFFICE_WALLS, WALL_POST, Vector2(x, DESK_ROW_BACK - 6.0), 2.0, -13)


func _build_props() -> void:
	# Water cooler and cabinets belong against the walls, not mid-room.
	_add_prop(OFFICE_OBJECTS, OBJ_COOLER, Vector2(1168.0, 330.0), 2.3, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_FILE_CABINET, Vector2(1168.0, 430.0), 2.1, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_CABINET, Vector2(128.0, 340.0), 2.1, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_FILE_CABINET, Vector2(128.0, 440.0), 2.1, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_SHELF, Vector2(880.0, 262.0), 2.2, -8)

	_add_prop(OFFICE_OBJECTS, OBJ_PLANT, Vector2(126.0, 640.0), 2.4, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_PLANT, Vector2(1170.0, 640.0), 2.4, -8)
	_add_prop(OFFICE_OBJECTS, OBJ_SOFA, Vector2(230.0, 668.0), 2.2, -8)

	_build_stations()
	_add_director_door()


func _build_stations() -> void:
	_add_station({
		"title": "Script binders",
		"prompt": "Examine the script binders",
		"body": "Three laminated scripts sit in a rack on the nearest desk, thumbed soft at the corners. BANK VERIFICATION. DEVICE SUPPORT. PRIZE RELEASE. Someone has written in the margin of the first one, in ballpoint: \"if they say they'll call the bank back, remind them the account is frozen NOW.\"",
		"note": "Three different stories, one identical mechanism: every script is built to remove the few minutes a person needs to check. That is the product being sold here, not the story.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"milestone_title": "The Scripts Are Written Down",
		"milestone_detail": "The call floor keeps three interchangeable scripts, each engineered around denying the victim time to verify.",
	}, Vector2(360.0, 612.0))
	_add_prop(OFFICE_OBJECTS, OBJ_DESK_FRONT, Vector2(360.0, 604.0), 2.6, -10)
	_add_prop(OFFICE_OBJECTS, OBJ_SHELF, Vector2(300.0, 596.0), 2.0, -11)

	_add_station({
		"title": "The call list",
		"prompt": "Examine the call list",
		"body": "A ring binder, open on the supervisor's desk. Column headings in marker: NAME. NUMBER. LAST RESULT. Names run down the page in a dozen different hands, some crossed out, most not. Taped inside the cover, on a strip of card gone furry at the edges, is the line every desk on this floor dials out on: %s." % SessionState.OPERATION_NUMBER,
		"is_ledger": true,
		"milestone_title": "The List Has Your Handwriting On It",
		"milestone_detail": "The operation's ledger holds the victims the player called during the prologue - proof that a scam list is a durable asset, not a one-off.",
	}, Vector2(660.0, 612.0))
	_add_prop(OFFICE_WALLS, WALL_BENCH, Vector2(660.0, 604.0), 1.9, -10)

	_add_station({
		"title": "Bonus board",
		"prompt": "Examine the bonus board",
		"body": "A whiteboard by the water cooler. Names down the left, a running tally to the right. The last column is headed ESCALATED and carries a bonus rate double the others. Under it, someone has drawn a small smiling face.",
		"note": "The operation pays more when the victim becomes distressed, because distress is what stops people thinking. Fear is not a side effect of the business model here. It is the business model.",
		"note_color": TextStyle.COLOR_WRONG,
		"marker": TextStyle.MARK_HARM,
		"milestone_title": "Distress Is A Performance Metric",
		"milestone_detail": "The floor pays a doubled bonus rate for calls that escalate a victim into distress - harm is deliberately incentivised, not incidental.",
	}, Vector2(1000.0, 612.0))
	_add_prop(OFFICE_OBJECTS, OBJ_EASEL, Vector2(1000.0, 606.0), 2.4, -10)

	_add_station({
		"title": "The shift rota",
		"prompt": "Examine the shift rota",
		"body": "Forty desks. Forty headsets, most still warm. A printed rota is taped beside the door: the heaviest staffing runs late morning and early evening, with a thinner night shift marked SENIORS / SHIFT WORKERS.",
		"note": "The hours are chosen the way the scripts are. Late morning finds retired people at home alone; the night shift finds people too tired to argue. Being targeted is not evidence of being careless - it is evidence of being reachable at a particular hour.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_SCENE,
		"milestone_title": "Forty Desks, Not One Caller",
		"milestone_detail": "The operation runs forty stations on a rota timed to catch specific groups when they are most isolated or most tired.",
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
	var locked := not SessionState.suspect_flipped
	var body := "A door at the back of the floor, blinds drawn. The nameplate reads E. CRUZ - FLOOR DIRECTOR."
	if locked:
		body += " The handle doesn't move, and nobody on this floor is going to open it for a stranger."
	else:
		body += " There is someone moving behind the blinds."

	var data := {
		"title": "Floor director's office",
		"prompt": "Confront the Operation" if not locked else "Examine the director's door",
		"body": body,
		"is_confrontation": not locked,
	}
	if locked:
		data["note"] = "Marco is the way through this door. Until a caller on this floor is willing to name the person running it, there is nothing here to open."
		data["note_color"] = TextStyle.COLOR_HINT
		data["marker"] = TextStyle.MARK_HINT

	_add_station(data, DIRECTOR_DOOR_POSITION)


func _on_station_entered(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	active_station = entry
	station_label.text = str(entry.get("prompt", ""))
	station_label.visible = not inspection_open


func _on_station_exited(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	if active_station.get("area", null) == entry.get("area", null):
		active_station = {}
		station_label.visible = false


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
# bottom edge sits, which makes laying furniture out far easier than centres.
func _add_prop(texture: Texture2D, region: Rect2, base_position: Vector2, prop_scale: float, z_index: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = true
	sprite.scale = Vector2(prop_scale, prop_scale)
	sprite.position = base_position - Vector2(0.0, region.size.y * prop_scale * 0.5)
	sprite.z_index = z_index
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)


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
	if portal_label.visible:
		return true
	return player.global_position.distance_to(portal.global_position) <= 120.0


func _on_portal_entered(portal_node: ScenePortal) -> void:
	portal_label.text = portal_node.prompt_text
	portal_label.visible = true


func _on_portal_exited(_portal_node: ScenePortal) -> void:
	portal_label.visible = false


func _transition_to_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.25)
	tween.finished.connect(func () -> void:
		SessionState.go_to_scene(scene_path)
	)
