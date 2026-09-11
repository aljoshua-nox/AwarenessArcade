extends Node2D

const TextStyle := preload("res://scripts/systems/text_style.gd")

@export var map_title: String = "Urban Block"
@export var map_hint: String = "Move with WASD or arrow keys. Press Enter at a door to interact."
@export_file("*.tscn") var portal_target_scene: String = "res://scenes/exploration/office_interior.tscn"
@export var player_spawn: Vector2 = Vector2(150, 950)
@export var movement_bounds: Rect2 = Rect2(Vector2(48, 48), Vector2(1824, 984))

@onready var decor: Node2D = %Decor
@onready var player: ExplorationPlayer = %Player
@onready var title_label: Label = %MapTitle
@onready var hint_label: Label = %MapHint
@onready var portal_label: Label = %PortalLabel
@onready var portal: ScenePortal = %Portal
@onready var interview_label: Label = %InterviewLabel
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var hud: CanvasLayer = %HUD

const INTERVIEW_SCENE := "res://scenes/investigation/interview.tscn"
const CASE_MARIA := "res://resources/cases/interview_case_001.json"
const CASE_KEVIN := "res://resources/cases/interview_case_002.json"
const CASE_MARCO := "res://resources/cases/interview_case_003.json"
const CASE_EVELYN := "res://resources/cases/interview_case_005.json"
const CASE_LINA := "res://resources/cases/interview_case_006.json"

# The cast, and which building each one lives in. Portals used to be three
# hand-placed nodes in the scene file, which capped the cast at three and made
# adding a witness a scene edit; they are built from this table instead.
#
# `row` picks the terrace: "block" is the residential row on the grass below the
# road, "street" is the shop row the office stands in. `slot` is an index into
# that row's building list. Doors are not all in one row on purpose - the
# residential row has room for three without crowding the trees and the side
# streets, and the two who work out of premises rather than homes (Lina's print
# shop, Marco at the call centre) belong on the commercial row anyway.
#
# Adding a witness: one row here, plus a building in the matching list if the
# slot is not already there. test_urban.tscn fails if a slot does not exist or
# if a building lands on a side street, a tree or another building.
const INTERVIEWEES := [
	{"case": CASE_EVELYN, "label": "EVELYN", "prompt": "Speak with Evelyn Marsh", "row": "block", "slot": 0},
	{"case": CASE_MARIA, "label": "MARIA", "prompt": "Speak with Maria Santos", "row": "block", "slot": 1},
	{"case": CASE_KEVIN, "label": "KEVIN", "prompt": "Speak with Kevin Dizon", "row": "block", "slot": 2},
	{"case": CASE_LINA, "label": "LINA", "prompt": "Speak with Lina Reyes", "row": "street", "slot": 1},
	{"case": CASE_MARCO, "label": "MARCO", "prompt": "Interrogate Marco Navarro", "row": "street", "slot": 4},
]

const INTERVIEW_PORTAL_SIZE := Vector2(56.0, 44.0)

# The street's own content. Exploration was pure transit between doors, which
# wasted the one space the player crosses over and over. What these are FOR is
# pattern-recognition living somewhere other than a dialogue tree: the same
# number and the same script turning up at door after door, so the player joins
# it up themselves instead of being told in an interview that scripts get reused.
#
# The number itself is SessionState.OPERATION_NUMBER: the call floor's own
# ledger has to print the SAME string, so there is exactly one copy of it.
# Nothing points the repetition out - noticing it is the mechanic.
const STOP_SIZE := Vector2(104.0, 96.0)
# Below the residential terrace (buildings end at y 702.4), clear of the trees
# at y 600/950 and of both side streets. test_urban checks that.
const NOTICEBOARD_POSITION := Vector2(980.0, 770.0)

# Each stop sits on an NPC from NPC_SPOTS, except the noticeboard. `cites_number`
# marks the ones that print that number - reading two of them is what earns the
# pattern milestone, so the payoff is for joining sources up, not for walking far.
const STREET_STOPS := [
	{
		"position": NOTICEBOARD_POSITION,
		"is_noticeboard": true,
		"title": "Community noticeboard",
		"prompt": "Read the noticeboard",
		"body": "A cork board on a post outside the terrace, behind cracked perspex. Under a bus timetable and a card for guitar lessons, a barangay notice has been pinned square in the middle and laminated against the weather.\n\nWARNING - TELEPHONE FRAUD IN THIS AREA. Callers claim to be from your bank's fraud desk, a device support line, or a prize office. Reported number: %s. They will ask you to stay on the line. Hang up. Call your bank on the number printed on your own card. No bank, agency or prize office will ever ask you to read out a one-time code.",
		"note": "That last line is the one worth carrying out of the game. A code sent to your phone is the bank checking it is you. Reading it aloud to a caller hands them the check.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
		"tactic_id": "repeated_script",
		"cites_number": true,
		"milestone_title": "The Warning Was Already Up",
		"milestone_detail": "A community notice on the street named the operation's number and all three of its scripts - the information existed before the case did.",
	},
	{
		"position": Vector2(700.0, 600.0),
		"title": "Neighbour on the terrace",
		"prompt": "Talk to the neighbour",
		"body": "Someone is out on the step with a mug, watching you work down the row. \"You're asking about the calls.\" A nod at the houses either side. \"I got the same one. Fraud desk, account compromised, stay on the line while they secure it.\" A shrug. \"I put the phone down. Then I asked next door. Next door got it too, word for word.\"",
		"note": "Three households, one script, delivered to each as though it had been written for them. A call that feels personally aimed is usually a form letter read aloud.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "repeated_script",
		"milestone_title": "Word For Word, Three Doors Apart",
		"milestone_detail": "Neighbours on one row received identical wording, which is what makes it a script rather than a targeted approach.",
	},
	{
		"position": Vector2(330.0, 216.0),
		"title": "Passer-by at the crossing",
		"prompt": "Talk to the passer-by",
		"body": "\"My mother had one of these.\" They answer before you have finished asking. \"Twice. Once in March, once about six weeks ago. Different story the second time - a refund instead of a fraud alert - but the same wrong pronunciation of her surname both times.\"",
		"note": "Being called twice is not bad luck. A number that answers is worth more than one that does not, so it is kept, sold on and worked again under a fresh story.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "reused_victim_list",
		"milestone_title": "Called Twice, Six Weeks Apart",
		"milestone_detail": "One resident was worked twice from the same list under two different scripts - answering once marks a number as live.",
	},
	{
		"position": Vector2(740.0, 216.0),
		"title": "Shopkeeper",
		"prompt": "Talk to the shopkeeper",
		"body": "\"That your poster?\" A tip of the head down the road towards the noticeboard. \"I put the number up in my window as well. Big, where you can't miss it. %s.\" They straighten a stack of receipts. \"Four people came in this month to ask me if it was real. Four that came in. I've no idea how many just paid it.\"",
		"note": "The people who come in to ask are the ones who did not lose anything. What a scam costs a street is never the number of reports - it is the silence around them.",
		"note_color": TextStyle.COLOR_WRONG,
		"marker": TextStyle.MARK_HARM,
		"cites_number": true,
		"milestone_title": "Four Asked. Nobody Counted The Rest.",
		"milestone_detail": "A shopkeeper posted the number and fielded four queries in a month - the questions asked out loud are a fraction of the actual contact.",
	},
	{
		"position": Vector2(1200.0, 408.0),
		"title": "Waiting at the kerb",
		"prompt": "Talk to the person waiting",
		"body": "\"Scam calls?\" A short laugh. \"You'd have to be pretty gullible, wouldn't you. My grandmother, maybe. Not me - I'd hear it coming a mile off.\" A pause, and the laugh goes out of it. \"...Why? What is it they say?\"",
		"note": "Everyone believes they would hear it coming, and that belief is the thing the scripts are built around. Being busy, tired or halfway out the door does more work than being credulous ever did. The question at the end is the honest part.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"milestone_title": "\"You'd Have To Be Gullible\"",
		"milestone_detail": "The commonest myth about fraud victims, met on the street - confidence that you would spot it is exactly what the scripts count on.",
	},
	{
		"position": Vector2(1750.0, 950.0),
		"title": "Resident by the back path",
		"prompt": "Talk to the resident",
		"body": "\"I stopped answering months ago.\" They say it without looking up from the gate latch. \"They ring anyway. Same number every time - %s - four or five times a week, then nothing for a month, then it starts again.\" The latch drops into place. \"I know what it is now. I just want it to stop.\"",
		"note": "The calls do not stop because a confirmed line stays on the list whatever the person does. Letting unknown callers go to voicemail costs nothing and is what takes a number back off it.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
		"tactic_id": "reused_victim_list",
		"cites_number": true,
		"milestone_title": "The Number That Keeps Ringing",
		"milestone_detail": "A resident who stopped answering is still called weekly from the same number - refusing does not remove you from a list, it only confirms you are on it.",
	},
]

const PATTERN_MILESTONE := "One Number, More Than One Door"
const PATTERN_DETAIL := "The number on the community notice is the number two residents read back from their own phones - the same line worked the whole street."

var interview_portals: Array[ScenePortal] = []
var portal_case_paths: Dictionary = {}
var active_interview_portal: ScenePortal = null

var street_stops: Array[Dictionary] = []
var active_stop: Dictionary = {}
var stop_label: Label
var inspect_panel: PanelContainer
var inspect_title: Label
var inspect_body: RichTextLabel
var inspection_open: bool = false

const MAP_WIDTH := 1920.0
const MAP_HEIGHT := 1080.0

const TILES_DIR := "res://assets/art/maps/kenney_roguelike-modern-city/Tiles/tile_%04d.png"
const TILE_SIZE := 16
const TILE_COLS := 37

const TILE_SIDEWALK := Vector2i(0, 19)
const TILE_ROAD := Vector2i(15, 21)
const TILE_GRASS := Vector2i(0, 24)
const TILE_CAR_TOP := Vector2i(31, 17)
const TILE_CAR_BOTTOM := Vector2i(31, 18)
const TILE_TREE := Vector2i(6, 18)

const WALLS_ROOF_TEXTURE: Texture2D = preload("res://assets/art/maps/urban/walls_grass_roof.png")
const DOORS_TEXTURE: Texture2D = preload("res://assets/art/maps/urban/doors_windows.png")
const PROPS_TEXTURE: Texture2D = preload("res://assets/art/maps/urban/props.png")
const NPC_A_TEXTURE: Texture2D = preload("res://assets/art/characters/24by24ModernRPGGuy.png")
const NPC_B_TEXTURE: Texture2D = preload("res://assets/art/maps/Little_Bits_Office_tileset/businessman1/businessman1_idle_down.png")

const ROOF_SOURCE_SIZE := Vector2(48.0, 96.0)
const ROOF_OLIVE_X := 0.0
const ROOF_TAN_X := 64.0
const ROOF_MAUVE_X := 128.0
const ROOF_ROSE_X := 192.0
const ROOF_BRICK_X := 256.0
const DOOR_SOURCE_RECT := Rect2(144.0, 48.0, 32.0, 40.0)
const LAMP_SOURCE_RECT := Rect2(303.0, 40.0, 32.0, 88.0)
const NPC_A_SOURCE_RECT := Rect2(0.0, 0.0, 24.0, 24.0)
const NPC_B_SOURCE_RECT := Rect2(0.0, 0.0, 16.0, 32.0)

const SIDEWALK_HEIGHT := 32.0
const ROAD_HEIGHT := 160.0
const BUILDING_ROW_BOTTOM := 200.0
const ROW_BUILDING_SCALE := Vector2(3.2, 2.0)
const BLOCK_BUILDING_SCALE := Vector2(2.6, 1.9)
const DOOR_SCALE := 1.6
const LAMP_SCALE := 1.6

const SIDE_STREET_WIDTH := 96.0
const SIDE_STREET_SIDEWALK := 16.0
const SIDE_STREET_X_POSITIONS := [520.0, 1400.0]

const CAR_TINTS := [
	Color(1, 1, 1, 1),
	Color(0.72, 0.75, 0.82, 1),
	Color(0.95, 0.55, 0.32, 1),
]

const BUILDING_ROW := [
	{"x": 242.0, "color": ROOF_TAN_X},
	{"x": 456.0, "color": ROOF_OLIVE_X},
	{"x": 669.0, "color": ROOF_MAUVE_X},
	{"x": 883.0, "color": ROOF_BRICK_X},
	{"x": 1097.0, "color": ROOF_ROSE_X},
	{"x": 1310.0, "color": ROOF_TAN_X},
	{"x": 1524.0, "color": ROOF_OLIVE_X},
]
const OFFICE_ROW_INDEX := 3

# Positions are constrained, not decorative. A block building is 124.8 wide, so
# each entry occupies [x, x + 124.8] at y 520-702.4, and that band already
# contains the two side streets ([520,616] and [1400,1496]), the trees at y 600
# (x 400, 1000, 1550) and a pedestrian at x 700. An earlier five-across layout
# put one house in the middle of a side street and another through a tree.
const BLOCK_BUILDINGS := [
	{"x": 140.0, "color": ROOF_ROSE_X},
	{"x": 780.0, "color": ROOF_TAN_X},
	{"x": 1150.0, "color": ROOF_MAUVE_X},
]

const CAR_SPOTS := [300.0, 650.0, 1250.0, 1600.0, 1800.0]
const TREE_SPOTS := [
	Vector2(400.0, 600.0), Vector2(650.0, 950.0), Vector2(1000.0, 600.0),
	Vector2(1250.0, 950.0), Vector2(1550.0, 600.0), Vector2(1850.0, 950.0),
	Vector2(300.0, 950.0),
]
const LAMP_TOP_X := [350.0, 900.0, 1450.0]
const LAMP_BOTTOM_X := [350.0, 900.0, 1300.0]

const NPC_SPOTS := [
	{"x": 330.0, "y": 216.0, "kind": "a", "tint": Color(1, 1, 1, 1)},
	{"x": 1200.0, "y": 408.0, "kind": "b", "tint": Color(1, 1, 1, 1)},
	{"x": 700.0, "y": 600.0, "kind": "a", "tint": Color(0.85, 1.0, 0.85, 1)},
	{"x": 1750.0, "y": 950.0, "kind": "a", "tint": Color(1.0, 0.85, 0.85, 1)},
	{"x": 740.0, "y": 216.0, "kind": "b", "tint": Color(1, 1, 1, 1)},
]


func _ready() -> void:
	title_label.text = map_title
	hint_label.text = map_hint
	if SessionState.has_urban_return_spawn:
		player.global_position = SessionState.urban_return_spawn
		SessionState.has_urban_return_spawn = false
	else:
		player.global_position = player_spawn
	player.movement_bounds = movement_bounds
	# The office door always leads onto the call floor now. Elena is confronted
	# from inside it, so the player walks the operation before reaching her.
	portal.target_scene = portal_target_scene
	if SessionState.suspect_flipped:
		portal.prompt_text = "Enter the call center"
	elif SessionState.case_locked:
		# Marco is gone, so the office holds nothing the player can reach. The
		# door becomes the way to close an investigation that cannot be closed.
		portal.prompt_text = "File the case as unresolved"
	else:
		portal.prompt_text = "Enter the office"
	portal.player_entered.connect(_on_portal_entered)
	portal.player_exited.connect(_on_portal_exited)

	_build_interview_portals()
	_build_stop_ui()

	_setup_camera_limits()
	_build_map()


# One Area2D per interviewee, created from INTERVIEWEES. _build_map() drops
# each one at its building's door.
func _build_interview_portals() -> void:
	for entry in INTERVIEWEES:
		var interview_portal := ScenePortal.new()
		interview_portal.target_scene = INTERVIEW_SCENE
		interview_portal.prompt_text = str(entry["prompt"])
		interview_portal.monitoring = true
		interview_portal.monitorable = true

		var shape := RectangleShape2D.new()
		shape.size = INTERVIEW_PORTAL_SIZE
		var collider := CollisionShape2D.new()
		collider.shape = shape
		interview_portal.add_child(collider)

		add_child(interview_portal)
		interview_portals.append(interview_portal)
		portal_case_paths[interview_portal] = str(entry["case"])
		interview_portal.player_entered.connect(_on_interview_entered)
		interview_portal.player_exited.connect(_on_interview_exited)


# Drops the portal for whoever lives in this row/slot, if anyone does, and
# labels the building so the player can tell the doors apart.
func _place_interviewee_door(row: String, slot: int, building_rect: Rect2, door_base: Vector2) -> void:
	for i in range(INTERVIEWEES.size()):
		var entry: Dictionary = INTERVIEWEES[i]
		if str(entry.get("row", "")) != row or int(entry.get("slot", -1)) != slot:
			continue
		if i < interview_portals.size():
			interview_portals[i].global_position = door_base + Vector2(0.0, 14.0)
		_add_building_label(building_rect, str(entry["label"]))
		return


func _setup_camera_limits() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_WIDTH)
	camera.limit_bottom = int(MAP_HEIGHT)


func _unhandled_input(event: InputEvent) -> void:
	# A stop is a modal read, so it eats both keys before anything else can act
	# on them - otherwise Escape would quit to the menu out from under it.
	if inspection_open:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_close_stop()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		SessionState.go_to_scene("res://scenes/main_menu/main_menu.tscn")
	elif event.is_action_pressed("ui_accept") and _can_enter_interview():
		SessionState.pending_case_path = str(portal_case_paths.get(active_interview_portal, ""))
		_remember_return_spawn(active_interview_portal.global_position)
		_transition_to_scene(active_interview_portal.target_scene)
	elif event.is_action_pressed("ui_accept") and _can_enter_portal():
		if SessionState.case_locked and not SessionState.suspect_flipped:
			_file_case_unresolved()
			return
		_remember_return_spawn(portal.global_position)
		_transition_to_scene(portal.target_scene)
	elif event.is_action_pressed("ui_accept") and not active_stop.is_empty():
		# Last, deliberately. A stop is optional flavour and a door is the way
		# on, so an overlap must never leave the player unable to go inside -
		# the shopkeeper's zone used to swallow the office door completely.
		_open_stop(active_stop)


# The fourth ending from the original plan: the case is closed because it
# cannot be carried any further, not because it was solved or sold.
func _file_case_unresolved() -> void:
	SessionState.investigation_case_title = "The Call Center Investigation"
	SessionState.investigation_person_name = "No suspect in custody"
	SessionState.investigation_outcome = "insufficient_evidence"
	SessionState.investigation_outcome_note = "Marco Navarro stopped talking and the operation above him was never named. What is on file describes a series of calls and nobody who made them."
	SessionState.has_urban_return_spawn = false
	_transition_to_scene("res://scenes/investigation/investigation_end.tscn")


func _remember_return_spawn(exit_position: Vector2) -> void:
	SessionState.urban_return_spawn = exit_position + Vector2(0.0, 20.0)
	SessionState.has_urban_return_spawn = true


func _build_map() -> void:
	_clear_decor()

	var sidewalk_top_end := _add_tiled_band(TILE_SIDEWALK, 0.0, BUILDING_ROW_BOTTOM + SIDEWALK_HEIGHT, MAP_WIDTH)
	var road_end := _add_tiled_band(TILE_ROAD, sidewalk_top_end, ROAD_HEIGHT, MAP_WIDTH)
	var sidewalk_bottom_end := _add_tiled_band(TILE_SIDEWALK, road_end, SIDEWALK_HEIGHT, MAP_WIDTH)
	_add_tiled_band(TILE_GRASS, sidewalk_bottom_end, MAP_HEIGHT - sidewalk_bottom_end, MAP_WIDTH)

	for street_x in SIDE_STREET_X_POSITIONS:
		_add_side_street(street_x, sidewalk_bottom_end, MAP_HEIGHT)

	var building_height := ROOF_SOURCE_SIZE.y * ROW_BUILDING_SCALE.y
	var row_top := BUILDING_ROW_BOTTOM - building_height
	for i in range(BUILDING_ROW.size()):
		var entry: Dictionary = BUILDING_ROW[i]
		var rect := _add_building(Vector2(entry["x"], row_top), entry["color"], ROW_BUILDING_SCALE)
		var door_base := _add_shop_door(rect)
		if i == OFFICE_ROW_INDEX:
			portal.global_position = door_base + Vector2(0.0, 14.0)
			_add_building_label(rect, "OFFICE")
		else:
			_place_interviewee_door("street", i, rect, door_base)

	for i in range(BLOCK_BUILDINGS.size()):
		var entry: Dictionary = BLOCK_BUILDINGS[i]
		var rect := _add_building(Vector2(entry["x"], 520.0), entry["color"], BLOCK_BUILDING_SCALE)
		var door_base := _add_shop_door(rect)
		_place_interviewee_door("block", i, rect, door_base)

	for spot in TREE_SPOTS:
		_add_tree(spot)

	for x in LAMP_TOP_X:
		_add_lamppost(Vector2(x, sidewalk_top_end - 8.0))
	for x in LAMP_BOTTOM_X:
		_add_lamppost(Vector2(x, road_end + 8.0))

	for spot in NPC_SPOTS:
		if spot["kind"] == "a":
			_add_npc(Vector2(spot["x"], spot["y"]), NPC_A_TEXTURE, NPC_A_SOURCE_RECT, 2.0, spot["tint"])
		else:
			_add_npc(Vector2(spot["x"], spot["y"]), NPC_B_TEXTURE, NPC_B_SOURCE_RECT, 2.2, spot["tint"])

	var curb_y := sidewalk_top_end + 24.0
	for i in range(CAR_SPOTS.size()):
		_add_car(Vector2(CAR_SPOTS[i], curb_y), CAR_TINTS[i % CAR_TINTS.size()])

	_build_street_stops()

	portal_label.visible = false
	interview_label.visible = false
	active_interview_portal = null


func _clear_decor() -> void:
	for child in decor.get_children():
		child.queue_free()


func _tile_texture(atlas_coord: Vector2i) -> Texture2D:
	var index := atlas_coord.y * TILE_COLS + atlas_coord.x
	return load(TILES_DIR % index)


func _add_tiled_rect(atlas_coord: Vector2i, top_left: Vector2, size: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var sprite := Sprite2D.new()
	sprite.texture = _tile_texture(atlas_coord)
	sprite.centered = false
	sprite.position = top_left
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, size.x, size.y)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)


func _add_tiled_band(atlas_coord: Vector2i, top: float, height: float, width: float) -> float:
	_add_tiled_rect(atlas_coord, Vector2(0.0, top), Vector2(width, height))
	return top + height


func _add_building(top_left: Vector2, color_x: float, image_scale: Vector2) -> Rect2:
	var sprite := Sprite2D.new()
	sprite.texture = WALLS_ROOF_TEXTURE
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(color_x, 0.0, ROOF_SOURCE_SIZE.x, ROOF_SOURCE_SIZE.y)
	sprite.scale = image_scale
	sprite.position = top_left
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)

	var size := Vector2(ROOF_SOURCE_SIZE.x * image_scale.x, ROOF_SOURCE_SIZE.y * image_scale.y)
	_add_wall_segment(top_left, size)
	return Rect2(top_left, size)


func _add_shop_door(building_rect: Rect2) -> Vector2:
	var door_size := DOOR_SOURCE_RECT.size * DOOR_SCALE
	var center_x := building_rect.position.x + building_rect.size.x * 0.5
	var bottom_y := building_rect.position.y + building_rect.size.y

	var sprite := Sprite2D.new()
	sprite.texture = DOORS_TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = DOOR_SOURCE_RECT
	sprite.centered = true
	sprite.scale = Vector2(DOOR_SCALE, DOOR_SCALE)
	sprite.position = Vector2(center_x, bottom_y - door_size.y * 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)

	return Vector2(center_x, bottom_y)


func _add_building_label(building_rect: Rect2, text: String) -> void:
	var label_size := Vector2(96.0, 22.0)
	var top_left := Vector2(
		building_rect.position.x + building_rect.size.x * 0.5 - label_size.x * 0.5,
		building_rect.position.y + 18.0
	)

	var background := ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08, 0.65)
	background.position = top_left
	background.size = label_size
	decor.add_child(background)

	var label := Label.new()
	label.text = text
	label.position = top_left
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	decor.add_child(label)


func _add_side_street(x_start: float, y_start: float, y_end: float) -> void:
	var road_left := x_start + SIDE_STREET_SIDEWALK
	var road_width := SIDE_STREET_WIDTH - SIDE_STREET_SIDEWALK * 2.0
	var height := y_end - y_start
	_add_tiled_rect(TILE_SIDEWALK, Vector2(x_start, y_start), Vector2(SIDE_STREET_SIDEWALK, height))
	_add_tiled_rect(TILE_ROAD, Vector2(road_left, y_start), Vector2(road_width, height))
	_add_tiled_rect(TILE_SIDEWALK, Vector2(road_left + road_width, y_start), Vector2(SIDE_STREET_SIDEWALK, height))


func _add_tree(tree_position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _tile_texture(TILE_TREE)
	sprite.centered = true
	sprite.scale = Vector2(2.2, 2.2)
	sprite.position = tree_position
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)


func _add_lamppost(base_position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = PROPS_TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = LAMP_SOURCE_RECT
	sprite.centered = true
	sprite.scale = Vector2(LAMP_SCALE, LAMP_SCALE)
	sprite.position = base_position - Vector2(0.0, LAMP_SOURCE_RECT.size.y * LAMP_SCALE * 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)


func _add_npc(npc_position: Vector2, texture: Texture2D, source_rect: Rect2, npc_scale: float, tint: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = source_rect
	sprite.centered = true
	sprite.scale = Vector2(npc_scale, npc_scale)
	sprite.modulate = tint
	sprite.position = npc_position
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)


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


func _add_car(spawn_position: Vector2, tint: Color) -> void:
	var car := Node2D.new()
	car.position = spawn_position
	decor.add_child(car)

	var top_half := Sprite2D.new()
	top_half.texture = _tile_texture(TILE_CAR_TOP)
	top_half.centered = true
	top_half.scale = Vector2(2.0, 2.0)
	top_half.modulate = tint
	top_half.position = Vector2(0.0, -TILE_SIZE)
	top_half.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	car.add_child(top_half)

	var bottom_half := Sprite2D.new()
	bottom_half.texture = _tile_texture(TILE_CAR_BOTTOM)
	bottom_half.centered = true
	bottom_half.scale = Vector2(2.0, 2.0)
	bottom_half.modulate = tint
	bottom_half.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	car.add_child(bottom_half)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = Vector2(0.0, -8.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30.0, 30.0)
	shape.shape = rect
	body.add_child(shape)
	car.add_child(body)


# --- Street stops ------------------------------------------------------------

func _build_stop_ui() -> void:
	stop_label = Label.new()
	stop_label.offset_left = 20.0
	stop_label.offset_top = 130.0
	stop_label.visible = false
	hud.add_child(stop_label)

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

	# The bodies are variable length and one of them is a whole poster, so the
	# text grows and the container scrolls - a fixed-height label would swallow
	# everything past the fold, which this project has been bitten by before.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	inspect_body = RichTextLabel.new()
	inspect_body.bbcode_enabled = true
	inspect_body.fit_content = true
	inspect_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspect_body)

	var footer := Label.new()
	footer.text = "Enter or Esc to step away"
	footer.add_theme_font_size_override("font_size", 13)
	column.add_child(footer)


func _build_street_stops() -> void:
	street_stops.clear()
	active_stop = {}
	for data in STREET_STOPS:
		var stop_position: Vector2 = data["position"]
		if bool(data.get("is_noticeboard", false)):
			_add_noticeboard(stop_position)

		var area := Area2D.new()
		area.position = stop_position
		area.monitoring = true
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = STOP_SIZE
		shape.shape = rect
		area.add_child(shape)
		decor.add_child(area)

		var entry: Dictionary = data.duplicate()
		entry["area"] = area
		street_stops.append(entry)
		area.body_entered.connect(_on_stop_entered.bind(entry))
		area.body_exited.connect(_on_stop_exited.bind(entry))


func _add_noticeboard(base_position: Vector2) -> void:
	var board_size := Vector2(88.0, 60.0)
	var top_left := base_position - Vector2(board_size.x * 0.5, board_size.y + 24.0)

	var post := ColorRect.new()
	post.color = Color(0.33, 0.24, 0.16, 1.0)
	post.position = Vector2(base_position.x - 6.0, top_left.y + board_size.y)
	post.size = Vector2(12.0, 28.0)
	decor.add_child(post)

	var frame := ColorRect.new()
	frame.color = Color(0.28, 0.20, 0.13, 1.0)
	frame.position = top_left - Vector2(5.0, 5.0)
	frame.size = board_size + Vector2(10.0, 10.0)
	decor.add_child(frame)

	var face := ColorRect.new()
	face.color = Color(0.90, 0.88, 0.80, 1.0)
	face.position = top_left
	face.size = board_size
	decor.add_child(face)

	var label := Label.new()
	label.text = "NOTICE"
	label.position = top_left
	label.size = board_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.55, 0.12, 0.10, 1.0))
	decor.add_child(label)


func _on_stop_entered(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	active_stop = entry
	stop_label.text = str(entry.get("prompt", ""))
	stop_label.visible = not inspection_open


func _on_stop_exited(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	if active_stop.get("area", null) == entry.get("area", null):
		active_stop = {}
		stop_label.visible = false


func _stop_body(stop: Dictionary) -> String:
	var parts: Array[String] = []
	var body := str(stop.get("body", ""))
	if bool(stop.get("cites_number", false)):
		body = body % SessionState.OPERATION_NUMBER
	parts.append(TextStyle.dialogue(body))
	var note := str(stop.get("note", ""))
	if not note.is_empty():
		var marker: String = str(stop.get("marker", TextStyle.MARK_SCENE))
		var tone: String = str(stop.get("note_color", TextStyle.COLOR_HINT))
		parts.append(TextStyle.system(marker, note, tone))
	return "\n\n".join(parts)


func _open_stop(stop: Dictionary) -> void:
	inspection_open = true
	inspect_title.text = str(stop.get("title", ""))
	inspect_body.text = _stop_body(stop)
	inspect_panel.visible = true
	stop_label.visible = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)

	SessionState.record_reflection_milestone(
		str(stop.get("milestone_title", "")), str(stop.get("milestone_detail", "")))
	var tactic_id := str(stop.get("tactic_id", ""))
	if not tactic_id.is_empty():
		SessionState.record_tactic_learned(tactic_id,
			"Heard on the street - %s" % str(stop.get("title", "")))
	# Two people naming the same number is the whole point of the street. It is
	# the player joining sources up, so it earns its own line in the summary.
	if _cited_number_count() >= 2:
		SessionState.record_reflection_milestone(PATTERN_MILESTONE, PATTERN_DETAIL)


func _close_stop() -> void:
	inspection_open = false
	inspect_panel.visible = false
	player.set_physics_process(true)
	if not active_stop.is_empty():
		stop_label.text = str(active_stop.get("prompt", ""))
		stop_label.visible = true


# Read off the milestones rather than a counter of its own, so it survives the
# player walking off to an interview and coming back to a rebuilt street.
func _cited_number_count() -> int:
	var count := 0
	for stop in street_stops:
		if not bool(stop.get("cites_number", false)):
			continue
		if SessionState.has_reflection_milestone(str(stop.get("milestone_title", ""))):
			count += 1
	return count


func _can_enter_portal() -> bool:
	if portal_label.visible:
		return true
	return player.global_position.distance_to(portal.global_position) <= 40.0


func _can_enter_interview() -> bool:
	if interview_label.visible and active_interview_portal != null:
		return true
	for interview_portal in interview_portals:
		if player.global_position.distance_to(interview_portal.global_position) <= 40.0:
			active_interview_portal = interview_portal
			return true
	return false


func _on_portal_entered(portal_node: ScenePortal) -> void:
	portal_label.text = portal_node.prompt_text
	portal_label.visible = true


func _on_portal_exited(_portal_node: ScenePortal) -> void:
	portal_label.visible = false


func _on_interview_entered(portal_node: ScenePortal) -> void:
	active_interview_portal = portal_node
	interview_label.text = portal_node.prompt_text
	interview_label.visible = true


func _on_interview_exited(portal_node: ScenePortal) -> void:
	if active_interview_portal == portal_node:
		active_interview_portal = null
		interview_label.visible = false


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
