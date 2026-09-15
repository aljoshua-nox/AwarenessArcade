extends Node2D

## A walkable district: bands of pavement and road, rows of buildings with doors
## that open interviews, pedestrians and props, and the street stops the player
## can read. This is everything a district *does*; what a district *is* - which
## buildings, which doors, which stops - lives in the script that extends this
## one and answers the table functions below (`interviewees()`, `building_row()`
## and so on). `urban_exterior.gd` is the terrace. The cast is meant to grow past
## one map, and a second district must not mean a second copy of 800 lines.
##
## Tables are functions rather than constants because GDScript constants cannot
## be overridden in a subclass. A district keeps its tables as constants of its
## own and returns them, so tests can still read them off the instance.

const TextStyle := preload("res://scripts/systems/text_style.gd")

@export var map_title: String = "District"
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
const INTERVIEW_PORTAL_SIZE := Vector2(56.0, 44.0)
const STOP_SIZE := Vector2(104.0, 96.0)

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

# The three bands every district shares: a pavement under the frontage row, the
# road, a pavement, and whatever the district puts below that. The edges are
# named because buildings, lamps, kerbs and the layout test all key off them.
const SIDEWALK_HEIGHT := 32.0
const ROAD_HEIGHT := 160.0
const BUILDING_ROW_BOTTOM := 200.0
const TOP_PAVEMENT_END := BUILDING_ROW_BOTTOM + SIDEWALK_HEIGHT
const ROAD_END := TOP_PAVEMENT_END + ROAD_HEIGHT
const BOTTOM_PAVEMENT_END := ROAD_END + SIDEWALK_HEIGHT
const BLOCK_ROW_TOP := 520.0
const ROW_BUILDING_SCALE := Vector2(3.2, 2.0)
const BLOCK_BUILDING_SCALE := Vector2(2.6, 1.9)
const DOOR_SCALE := 1.6
const LAMP_SCALE := 1.6

const SIDE_STREET_WIDTH := 96.0
const SIDE_STREET_SIDEWALK := 16.0

const CAR_TINTS := [
	Color(1, 1, 1, 1),
	Color(0.72, 0.75, 0.82, 1),
	Color(0.95, 0.55, 0.32, 1),
]


# --- What a district is -------------------------------------------------------
# Override these. Each returns the district's own table; the defaults describe
# an empty lot so a district only has to answer for what it has.

# Rows of {"case", "label", "prompt", "row", "slot"}. `row` is "street" (the
# frontage row) or "block" (the houses below the road); `slot` indexes into
# that row's building list.
func interviewees() -> Array:
	return []


# The frontage row along the top pavement: {"x", "color"} per unit, at
# ROW_BUILDING_SCALE.
func building_row() -> Array:
	return []


# Which frontage unit is the office (its door leads to the call floor), or -1
# when this district has none.
func office_row_index() -> int:
	return -1


# The houses on the ground below the road: {"x", "color"} at BLOCK_ROW_TOP,
# BLOCK_BUILDING_SCALE.
func block_buildings() -> Array:
	return []


# x of each side street running down from the lower pavement to the map edge.
func side_street_x_positions() -> Array:
	return []


func car_spots() -> Array:
	return []


func tree_spots() -> Array:
	return []


func lamp_top_x() -> Array:
	return []


func lamp_bottom_x() -> Array:
	return []


# {"x", "y", "kind" ("a"/"b"), "tint"} per pedestrian. A non-noticeboard stop
# must stand on one of these.
func npc_spots() -> Array:
	return []


# The stops - see the terrace's STREET_STOPS for the shape of a row.
func street_stops_table() -> Array:
	return []


# Recorded when the player has read two stops that cite the operation's number.
# Empty means this district has no such pattern to notice.
func pattern_milestone_title() -> String:
	return ""


func pattern_milestone_detail() -> String:
	return ""


func has_office() -> bool:
	return office_row_index() >= 0


# --- Lifecycle ---------------------------------------------------------------

func _ready() -> void:
	title_label.text = map_title
	hint_label.text = map_hint
	if SessionState.has_urban_return_spawn:
		player.global_position = SessionState.urban_return_spawn
		SessionState.has_urban_return_spawn = false
	else:
		player.global_position = player_spawn
	player.movement_bounds = movement_bounds

	_setup_office_portal()
	_build_interview_portals()
	_build_stop_ui()

	_setup_camera_limits()
	_build_map()


# The office door always leads onto the call floor. Elena is confronted from
# inside it, so the player walks the operation before reaching her. A district
# without an office parks the scene's portal node where nothing can reach it.
func _setup_office_portal() -> void:
	if not has_office():
		portal.monitoring = false
		portal.monitorable = false
		portal.global_position = Vector2(-1000.0, -1000.0)
		return
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


# One Area2D per interviewee, created from interviewees(). _build_map() drops
# each one at its building's door.
func _build_interview_portals() -> void:
	for entry in interviewees():
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
	var table := interviewees()
	for i in range(table.size()):
		var entry: Dictionary = table[i]
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
	elif event.is_action_pressed("ui_accept") and has_office() and _can_enter_portal():
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


# --- Building the map --------------------------------------------------------
# Four passes, each overridable on its own: the ground, the buildings, the props,
# the stops. A district that differs in one pass overrides that pass and calls
# the primitives below; it does not restate the other three.

func _build_map() -> void:
	_clear_decor()
	_build_ground()
	_build_buildings()
	_build_props()
	_build_street_stops()

	portal_label.visible = false
	interview_label.visible = false
	active_interview_portal = null


func _build_ground() -> void:
	_add_tiled_band(TILE_SIDEWALK, 0.0, TOP_PAVEMENT_END, MAP_WIDTH)
	_add_tiled_band(TILE_ROAD, TOP_PAVEMENT_END, ROAD_HEIGHT, MAP_WIDTH)
	_add_tiled_band(TILE_SIDEWALK, ROAD_END, SIDEWALK_HEIGHT, MAP_WIDTH)
	_add_tiled_band(TILE_GRASS, BOTTOM_PAVEMENT_END, MAP_HEIGHT - BOTTOM_PAVEMENT_END, MAP_WIDTH)

	for street_x in side_street_x_positions():
		_add_side_street(street_x, BOTTOM_PAVEMENT_END, MAP_HEIGHT)


func _build_buildings() -> void:
	var building_height := ROOF_SOURCE_SIZE.y * ROW_BUILDING_SCALE.y
	var row_top := BUILDING_ROW_BOTTOM - building_height
	var row := building_row()
	for i in range(row.size()):
		var entry: Dictionary = row[i]
		var rect := _add_building(Vector2(entry["x"], row_top), entry["color"], ROW_BUILDING_SCALE)
		var door_base := _add_shop_door(rect)
		if i == office_row_index():
			portal.global_position = door_base + Vector2(0.0, 14.0)
			_add_building_label(rect, "OFFICE")
		else:
			_place_interviewee_door("street", i, rect, door_base)

	var houses := block_buildings()
	for i in range(houses.size()):
		var entry: Dictionary = houses[i]
		var rect := _add_building(Vector2(entry["x"], BLOCK_ROW_TOP), entry["color"], BLOCK_BUILDING_SCALE)
		var door_base := _add_shop_door(rect)
		_place_interviewee_door("block", i, rect, door_base)


func _build_props() -> void:
	for spot in tree_spots():
		_add_tree(spot)

	for x in lamp_top_x():
		_add_lamppost(Vector2(x, TOP_PAVEMENT_END - 8.0))
	for x in lamp_bottom_x():
		_add_lamppost(Vector2(x, ROAD_END + 8.0))

	for spot in npc_spots():
		if spot["kind"] == "a":
			_add_npc(Vector2(spot["x"], spot["y"]), NPC_A_TEXTURE, NPC_A_SOURCE_RECT, 2.0, spot["tint"])
		else:
			_add_npc(Vector2(spot["x"], spot["y"]), NPC_B_TEXTURE, NPC_B_SOURCE_RECT, 2.2, spot["tint"])

	var curb_y := TOP_PAVEMENT_END + 24.0
	var cars := car_spots()
	for i in range(cars.size()):
		_add_car(Vector2(cars[i], curb_y), CAR_TINTS[i % CAR_TINTS.size()])


func _clear_decor() -> void:
	for child in decor.get_children():
		child.queue_free()


# --- Primitives ----------------------------------------------------------------

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
	for data in street_stops_table():
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
	if not pattern_milestone_title().is_empty() and _cited_number_count() >= 2:
		SessionState.record_reflection_milestone(pattern_milestone_title(), pattern_milestone_detail())


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


# --- Doors -------------------------------------------------------------------

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
