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
const PromptBubble := preload("res://scripts/exploration/prompt_bubble.gd")

@export var map_title: String = "District"
@export var map_hint: String = "WASD or arrows to walk  \u00b7  Enter at a door or a person  \u00b7  J journal  \u00b7  Esc menu"
## The looping bed under this street, if the file exists (see assets/audio/ambience/).
@export var ambience_path: String = "res://assets/audio/ambience/street.ogg"
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
# Doors the player can stand at but not open: a witness who failed and will
# not talk again, or any witness once the case's statements are spent. The
# prompt says which; Enter does nothing.
var portal_blocked: Dictionary = {}
var active_interview_portal: ScenePortal = null
# Whichever office, transit or exit portal the player is standing in, if any.
var active_portal: ScenePortal = null
var transit_portal: ScenePortal = null
# The prompt that floats over the active door, stop or exit.
var prompt_bubble: Label
const DOOR_LIFT := 84.0
const STOP_LIFT := 64.0
# What each interview door's marker shows, by portal - the layout test reads it.
var door_markers: Dictionary = {}
# Doors to somewhere that is neither an interview nor the call floor - the
# detective's desk. A district places one from its _build_buildings() with
# _place_exit_door(); the street remembers the door on the way in, so the way
# back out lands beside it.
var exit_doors: Array[ScenePortal] = []
var standing_label: Label
var statements_label: Label
var objective_label: Label

# What _build_map() actually put down, so the layout test can check the
# rectangles that are on screen rather than recompute them from the tables.
var built_buildings: Array[Rect2] = []
var built_labels: Array[Rect2] = []

var street_stops: Array[Dictionary] = []
var active_stop: Dictionary = {}
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


# Lampposts stand on the pavements, one side of the road at a time: a lamp on
# the top pavement, then one on the bottom, then the top again, never a pair
# across from each other. Each district lists its own; the layout test checks
# the alternation and that no lamp stands in a side street's mouth.
func lamp_top_x() -> Array:
	return []


func lamp_bottom_x() -> Array:
	return []


# {"x", "y", "kind" ("a"/"b"), "tint"} per pedestrian. A stop stands on one of
# these unless it is the noticeboard or marked `is_fixture` - a stop on a thing
# the district draws itself (a sign, a door) rather than on a person.
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


# The way to the next district, or empty when this one is a dead end:
# {"position": where the portal stands, "prompt", "target": the other scene,
# "arrival": where the player appears in that scene}. Both ends set the other
# district's spawn, so arriving never means standing inside the way back.
func transit() -> Dictionary:
	return {}


# Rectangles a building must not be built on. Side streets by default; a
# district that draws other roads adds them here so the layout test sees them.
func obstacle_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for street_x in side_street_x_positions():
		rects.append(Rect2(Vector2(float(street_x), BOTTOM_PAVEMENT_END),
			Vector2(SIDE_STREET_WIDTH, MAP_HEIGHT - BOTTOM_PAVEMENT_END)))
	return rects


# How many buildings a row kind has, for the door tables and the test. "street"
# and "block" are every district's; a district with a building outside those
# tables (Terminal Road's site office) names a row of its own and answers for it.
func slot_count(row: String) -> int:
	match row:
		"street":
			return building_row().size()
		"block":
			return block_buildings().size()
	return 0


func has_office() -> bool:
	return office_row_index() >= 0


# --- Lifecycle ---------------------------------------------------------------

func _ready() -> void:
	title_label.text = map_title
	hint_label.text = map_hint
	# Prompts float over the map now; the HUD's corner labels stay in the scene
	# files but never show.
	portal_label.visible = false
	interview_label.visible = false
	prompt_bubble = PromptBubble.new()
	add_child(prompt_bubble)
	AudioManager.stop_music()
	AudioManager.play_ambience(ambience_path)
	if SessionState.has_urban_return_spawn:
		player.global_position = SessionState.urban_return_spawn
		SessionState.has_urban_return_spawn = false
	else:
		player.global_position = player_spawn
	player.movement_bounds = movement_bounds

	_setup_office_portal()
	_build_interview_portals()
	_build_transit()
	_build_stop_ui()

	_setup_camera_limits()
	_build_map()

	# The first street of the case opens the case file on the player. Deferred
	# so the street is on screen underneath it.
	if SessionState.briefing_pending:
		SessionState.briefing_pending = false
		CaseJournal.show_briefing.call_deferred()


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
		# A playtester took six statements to Elena and got The Building
		# Stands, never having heard that the owner's name was a thing to get.
		# The door says so while it is missing; so does hers, and the journal.
		portal.prompt_text = "Enter the call center" if SessionState.owner_named() \
			else "Enter the call center - nobody has named the owner yet"
	elif SessionState.case_locked:
		# Marco is gone, so the office holds nothing the player can reach. The
		# door becomes the way to close an investigation that cannot be closed.
		portal.prompt_text = "File the case as unresolved"
	else:
		portal.prompt_text = "Enter the offices"
	portal.player_entered.connect(_on_portal_entered)
	portal.player_exited.connect(_on_portal_exited)


func _build_transit() -> void:
	var data := transit()
	if data.is_empty():
		return
	transit_portal = ScenePortal.new()
	transit_portal.target_scene = str(data.get("target", ""))
	transit_portal.prompt_text = str(data.get("prompt", "Follow the street"))
	transit_portal.monitoring = true
	transit_portal.monitorable = true
	var shape := RectangleShape2D.new()
	shape.size = INTERVIEW_PORTAL_SIZE
	var collider := CollisionShape2D.new()
	collider.shape = shape
	transit_portal.add_child(collider)
	transit_portal.global_position = data.get("position", Vector2.ZERO)
	add_child(transit_portal)
	transit_portal.player_entered.connect(_on_portal_entered)
	transit_portal.player_exited.connect(_on_portal_exited)


# Crossing to the other district: the player appears at that district's
# arrival point, and any interview they open over there returns over there.
func _take_transit() -> void:
	var data := transit()
	SessionState.urban_return_spawn = data.get("arrival", Vector2.ZERO)
	SessionState.has_urban_return_spawn = true
	SessionState.urban_return_scene = str(data.get("target", SessionState.DEFAULT_STREET_SCENE))
	_transition_to_scene(str(data.get("target", "")))


func _transit_in_reach() -> bool:
	if transit_portal == null:
		return false
	return player.global_position.distance_to(transit_portal.global_position) <= 40.0


func _place_exit_door(door_base: Vector2, prompt: String, target: String) -> ScenePortal:
	var door := ScenePortal.new()
	door.target_scene = target
	door.prompt_text = prompt
	door.monitoring = true
	door.monitorable = true
	var shape := RectangleShape2D.new()
	shape.size = INTERVIEW_PORTAL_SIZE
	var collider := CollisionShape2D.new()
	collider.shape = shape
	door.add_child(collider)
	door.global_position = door_base + Vector2(0.0, 14.0)
	add_child(door)
	exit_doors.append(door)
	door.player_entered.connect(_on_portal_entered)
	door.player_exited.connect(_on_portal_exited)
	return door


func _exit_door_in_reach() -> ScenePortal:
	for door in exit_doors:
		if player.global_position.distance_to(door.global_position) <= 40.0:
			return door
	return null


# The person behind a door, read off their case file: their role decides
# whether the door costs a statement, their name what a closed door says.
func _case_person(case_path: String) -> Dictionary:
	var file := FileAccess.open(case_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return (parsed as Dictionary).get("person", {})


# What a door says, given the case behind it and where the case stands.
func _door_prompt(entry: Dictionary, person: Dictionary) -> String:
	var role := str(person.get("role", ""))
	var person_id := str(person.get("person_id", ""))
	if SessionState.STATEMENT_ROLES.has(role):
		if SessionState.is_witness_closed(person_id):
			return "%s won't talk to you again" % str(person.get("name", "This witness"))
		if SessionState.statements_left() <= 0:
			return "No time for another statement - the case moves with what it has"
	return str(entry["prompt"])


func _door_is_blocked(person: Dictionary) -> bool:
	var role := str(person.get("role", ""))
	if not SessionState.STATEMENT_ROLES.has(role):
		return false
	return SessionState.is_witness_closed(str(person.get("person_id", ""))) or SessionState.statements_left() <= 0


# One Area2D per interviewee, created from interviewees(). _build_map() drops
# each one at its building's door.
func _build_interview_portals() -> void:
	for entry in interviewees():
		var person := _case_person(str(entry["case"]))
		var interview_portal := ScenePortal.new()
		interview_portal.target_scene = INTERVIEW_SCENE
		interview_portal.prompt_text = _door_prompt(entry, person)
		if _door_is_blocked(person):
			portal_blocked[interview_portal] = true
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
func _place_interviewee_door(row: String, slot: int, building_rect: Rect2, door_base: Vector2,
		label_y: float = 18.0) -> void:
	var table := interviewees()
	for i in range(table.size()):
		var entry: Dictionary = table[i]
		if str(entry.get("row", "")) != row or int(entry.get("slot", -1)) != slot:
			continue
		if i < interview_portals.size():
			interview_portals[i].global_position = door_base + Vector2(0.0, 14.0)
			_add_door_marker(interview_portals[i], door_base, _case_person(str(entry["case"])))
		_add_building_label(building_rect, str(entry["label"]), label_y)
		return


# A badge over the door saying how things stand with the person behind it -
# the same reading the journal's People page gives, so a street can be walked
# without opening the journal to know which doors are still worth knocking on.
func _add_door_marker(door: ScenePortal, door_base: Vector2, person: Dictionary) -> void:
	var marker: Dictionary = CaseJournal.door_marker(person)
	door_markers[door] = marker
	var size := Vector2(24.0, 24.0)
	var top_left := door_base + Vector2(-size.x * 0.5, -DOOR_LIFT + 6.0)

	var shadow := ColorRect.new()
	shadow.color = Color(0.06, 0.06, 0.09, 0.75)
	shadow.position = top_left + Vector2(2.0, 2.0)
	shadow.size = size
	shadow.z_index = 40
	decor.add_child(shadow)

	var face := ColorRect.new()
	face.color = Color.html(str(marker.get("color", TextStyle.COLOR_TACTIC)))
	face.position = top_left
	face.size = size
	face.z_index = 41
	decor.add_child(face)

	var glyph := Label.new()
	glyph.text = str(marker.get("glyph", "?"))
	glyph.position = top_left
	glyph.size = size
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
	glyph.add_theme_font_size_override("font_size", 17)
	glyph.add_theme_color_override("font_color", Color(0.10, 0.09, 0.05))
	glyph.add_theme_constant_override("outline_size", 0)
	glyph.z_index = 42
	decor.add_child(glyph)


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
		# The menu asks before abandoning the run; this used to go straight to
		# the main menu, which resets the session.
		CaseJournal.open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and _can_enter_interview():
		SessionState.pending_case_path = str(portal_case_paths.get(active_interview_portal, ""))
		_remember_return_spawn(active_interview_portal.global_position)
		_transition_to_scene(active_interview_portal.target_scene)
	elif event.is_action_pressed("ui_accept") and _transit_in_reach():
		_take_transit()
	elif event.is_action_pressed("ui_accept") and _exit_door_in_reach() != null:
		var door := _exit_door_in_reach()
		_remember_return_spawn(door.global_position)
		_transition_to_scene(door.target_scene)
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
	SessionState.investigation_outcome_note = "Marco Navarro stopped talking and the people above him were never named. What is on file describes a series of calls and nobody who made them."
	SessionState.has_urban_return_spawn = false
	_transition_to_scene("res://scenes/investigation/investigation_end.tscn")


func _remember_return_spawn(exit_position: Vector2) -> void:
	SessionState.urban_return_spawn = exit_position + Vector2(0.0, 20.0)
	SessionState.has_urban_return_spawn = true
	# The interview's "Return to the Street" comes back to this street.
	SessionState.urban_return_scene = scene_file_path if not scene_file_path.is_empty() \
		else SessionState.DEFAULT_STREET_SCENE


# --- Building the map --------------------------------------------------------
# Four passes, each overridable on its own: the ground, the buildings, the props,
# the stops. A district that differs in one pass overrides that pass and calls
# the primitives below; it does not restate the other three.

func _build_map() -> void:
	_clear_decor()
	built_buildings.clear()
	built_labels.clear()
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
		_add_side_street(street_x, ROAD_END, MAP_HEIGHT, SIDEWALK_HEIGHT)


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
			_add_building_label(rect, "OFFICES")
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
	# Which tile this is, for the layout test to read the ground back.
	sprite.set_meta("tile", atlas_coord)
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
	built_buildings.append(Rect2(top_left, size))
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


# `label_y` is the label's offset from the building's top. A building whose
# roof leaves the frame needs it lower than the default or the label does too.
func _add_building_label(building_rect: Rect2, text: String, label_y: float = 18.0) -> void:
	# Wide enough for the name: "VALDERRAMA" does not fit the box "OFFICES" does.
	var label_size := Vector2(maxf(96.0, 12.0 * text.length() + 16.0), 22.0)
	var top_left := Vector2(
		building_rect.position.x + building_rect.size.x * 0.5 - label_size.x * 0.5,
		building_rect.position.y + label_y
	)
	built_labels.append(Rect2(top_left, label_size))

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


# A side street from y_start to y_end: a road strip with a kerb either side.
# `mouth` is the depth of the main pavement it cuts through where it meets the
# road - at the start for a street running down from the road, at the end for
# one running down into it. The road strip runs the whole way, so the two roads
# join; the kerbs begin past the mouth. Until 2026-09-20 the street started
# below the pavement, and the pavement's tiles ran across every junction.
func _add_side_street(x_start: float, y_start: float, y_end: float, mouth: float = 0.0, mouth_at_end: bool = false) -> void:
	var road_left := x_start + SIDE_STREET_SIDEWALK
	var road_width := SIDE_STREET_WIDTH - SIDE_STREET_SIDEWALK * 2.0
	var height := y_end - y_start
	var kerb_top := y_start if mouth_at_end else y_start + mouth
	var kerb_height := height - mouth
	_add_tiled_rect(TILE_SIDEWALK, Vector2(x_start, kerb_top), Vector2(SIDE_STREET_SIDEWALK, kerb_height))
	_add_tiled_rect(TILE_ROAD, Vector2(road_left, y_start), Vector2(road_width, height))
	_add_tiled_rect(TILE_SIDEWALK, Vector2(road_left + road_width, kerb_top), Vector2(SIDE_STREET_SIDEWALK, kerb_height))


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


# One tile from the Kenney sheet as a free-standing sprite: a cone, a crate,
# a pane of glass. Centred on `at`.
func _add_tile_sprite(atlas_coord: Vector2i, at: Vector2, tile_scale: float = 2.0) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _tile_texture(atlas_coord)
	sprite.centered = true
	sprite.scale = Vector2(tile_scale, tile_scale)
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)


# A region of a sheet standing on `base` (bottom-centre), the way lampposts do.
func _add_prop(texture: Texture2D, source_rect: Rect2, base: Vector2, prop_scale: float,
		solid: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = source_rect
	sprite.centered = true
	sprite.scale = Vector2(prop_scale, prop_scale)
	var size := source_rect.size * prop_scale
	sprite.position = base - Vector2(0.0, size.y * 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)
	if solid:
		_add_wall_segment(base - Vector2(size.x * 0.5, size.y), size)


# A run of fence tiles along y, with an opening for a gate. Solid apart from
# the gap, so a site is a place you enter, not a texture you walk over.
func _add_fence(x_start: float, x_end: float, y: float, gap: Vector2 = Vector2.ZERO,
		atlas_coord: Vector2i = Vector2i(21, 14), tile_scale: float = 2.0) -> void:
	var step := TILE_SIZE * tile_scale
	var x := x_start
	while x + step <= x_end + 0.5:
		var inside_gap := gap != Vector2.ZERO and x + step > gap.x and x < gap.y
		if not inside_gap:
			_add_tile_sprite(atlas_coord, Vector2(x + step * 0.5, y + step * 0.5), tile_scale)
		x += step
	if gap == Vector2.ZERO:
		_add_wall_segment(Vector2(x_start, y), Vector2(x_end - x_start, step))
	else:
		_add_wall_segment(Vector2(x_start, y), Vector2(gap.x - x_start, step))
		_add_wall_segment(Vector2(gap.y, y), Vector2(x_end - gap.y, step))


# Painted lines: four thin rectangles, no collision.
func _add_outline(rect: Rect2, color: Color, thickness: float = 3.0) -> void:
	var edges := [
		Rect2(rect.position, Vector2(rect.size.x, thickness)),
		Rect2(rect.position + Vector2(0.0, rect.size.y - thickness), Vector2(rect.size.x, thickness)),
		Rect2(rect.position, Vector2(thickness, rect.size.y)),
		Rect2(rect.position + Vector2(rect.size.x - thickness, 0.0), Vector2(thickness, rect.size.y)),
	]
	for edge in edges:
		var strip := ColorRect.new()
		strip.color = color
		strip.position = edge.position
		strip.size = edge.size
		decor.add_child(strip)


# A sign on posts with a few lines of text - the noticeboard's bigger cousin,
# for a hoarding or a shopfront. `base` is where the posts meet the ground.
#
# The labels are made first and measured, and the board is built around them:
# a Label cannot be narrower than its text, so a line wider than a fixed face
# grows off the board's left edge and loses its centring. Measuring after
# add_child() uses the project theme's real font, not a guess at it.
func _add_signboard(base: Vector2, lines: Array, board_size: Vector2 = Vector2(150.0, 62.0),
		face_color: Color = Color(0.94, 0.92, 0.86, 1.0), text_color: Color = Color(0.16, 0.16, 0.24, 1.0),
		accent_color: Color = Color(0.63, 0.12, 0.12, 1.0)) -> void:
	const MARGIN := 24.0
	var labels: Array[Label] = []
	for i in range(lines.size()):
		var label := Label.new()
		label.text = str(lines[i])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", accent_color if i > 0 else text_color)
		decor.add_child(label)
		labels.append(label)
		board_size.x = maxf(board_size.x, label.get_minimum_size().x + MARGIN)

	var top_left := base - Vector2(board_size.x * 0.5, board_size.y + 20.0)
	var line_height := board_size.y / maxf(1.0, float(lines.size()))
	for i in range(labels.size()):
		labels[i].position = top_left + Vector2(0.0, line_height * i)
		labels[i].size = Vector2(board_size.x, line_height)

	# Posts, frame and face go in behind the text, in that order.
	var behind: Array[Control] = []
	for post_x in [base.x - board_size.x * 0.35, base.x + board_size.x * 0.35]:
		var post := ColorRect.new()
		post.color = Color(0.33, 0.24, 0.16, 1.0)
		post.position = Vector2(post_x - 5.0, top_left.y + board_size.y)
		post.size = Vector2(10.0, 22.0)
		behind.append(post)
	var frame := ColorRect.new()
	frame.color = Color(0.24, 0.20, 0.16, 1.0)
	frame.position = top_left - Vector2(4.0, 4.0)
	frame.size = board_size + Vector2(8.0, 8.0)
	behind.append(frame)
	var face := ColorRect.new()
	face.color = face_color
	face.position = top_left
	face.size = board_size
	behind.append(face)
	var first_label_index := labels[0].get_index() if not labels.is_empty() else decor.get_child_count()
	for node in behind:
		decor.add_child(node)
		decor.move_child(node, first_label_index)
		first_label_index += 1


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
	# The case's two numbers, always visible. Standing gates seven of the
	# doors and used to show only on the summary screen; a budget the player
	# did not know about would read as unfair the first time it bit.
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

	# The journal's first open objective, so the case has a direction on screen.
	objective_label = Label.new()
	objective_label.offset_left = 20.0
	objective_label.offset_top = 130.0
	objective_label.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_TACTIC))
	hud.add_child(objective_label)
	_refresh_objective_label()

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
	if not inspection_open:
		prompt_bubble.show_above(entry.get("position", Vector2.ZERO), str(entry.get("prompt", "")), STOP_LIFT)


func _on_stop_exited(body: Node, entry: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	if active_stop.get("area", null) == entry.get("area", null):
		active_stop = {}
		prompt_bubble.hide_bubble()


func _stop_body(stop: Dictionary) -> String:
	var parts: Array[String] = []
	var body := str(stop.get("body", ""))
	if bool(stop.get("cites_number", false)):
		body = body % SessionState.OPERATION_NUMBER
	elif bool(stop.get("cites_name", false)):
		body = body % SessionState.COMPANY_NAME
	elif bool(stop.get("cites_call_floor", false)):
		body = body % SessionState.CALL_FLOOR_NAME.split(" ")[0]
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
	prompt_bubble.hide_bubble()
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)

	SessionState.record_reflection_milestone(
		str(stop.get("milestone_title", "")), str(stop.get("milestone_detail", "")))
	var tactic_id := str(stop.get("tactic_id", ""))
	if not tactic_id.is_empty():
		SessionState.record_tactic_learned(tactic_id,
			"Heard on the street - %s" % str(stop.get("title", "")))
	# Two sources naming the same number - or the same company - is the whole
	# point of a street. It is the player joining sources up, so it earns its
	# own line in the summary.
	if not pattern_milestone_title().is_empty() and _cited_number_count() >= 2:
		SessionState.record_reflection_milestone(pattern_milestone_title(), pattern_milestone_detail())


func _refresh_objective_label() -> void:
	var tracked: Dictionary = CaseJournal.tracked_objective()
	objective_label.visible = not tracked.is_empty()
	objective_label.text = "> %s" % str(tracked.get("title", ""))


func _close_stop() -> void:
	_refresh_objective_label()
	inspection_open = false
	inspect_panel.visible = false
	player.set_physics_process(true)
	if not active_stop.is_empty():
		prompt_bubble.show_above(active_stop.get("position", Vector2.ZERO), str(active_stop.get("prompt", "")), STOP_LIFT)


# Read off the milestones rather than a counter of its own, so it survives the
# player walking off to an interview and coming back to a rebuilt street.
func _cited_number_count() -> int:
	var count := 0
	for stop in street_stops:
		if not (bool(stop.get("cites_number", false)) or bool(stop.get("cites_name", false))):
			continue
		if SessionState.has_reflection_milestone(str(stop.get("milestone_title", ""))):
			count += 1
	return count


# --- Doors -------------------------------------------------------------------

func _can_enter_portal() -> bool:
	if active_portal == portal:
		return true
	return player.global_position.distance_to(portal.global_position) <= 40.0


func _can_enter_interview() -> bool:
	if active_interview_portal != null:
		return not portal_blocked.has(active_interview_portal)
	for interview_portal in interview_portals:
		if player.global_position.distance_to(interview_portal.global_position) <= 40.0:
			active_interview_portal = interview_portal
			return not portal_blocked.has(interview_portal)
	return false


# The office door, the way to the other district and the desk's door all
# report here; whichever the player is in is the active one.
func _on_portal_entered(portal_node: ScenePortal) -> void:
	active_portal = portal_node
	prompt_bubble.show_above(portal_node.global_position, portal_node.prompt_text, DOOR_LIFT)


func _on_portal_exited(portal_node: ScenePortal) -> void:
	if active_portal == portal_node:
		active_portal = null
		prompt_bubble.hide_bubble()


func _on_interview_entered(portal_node: ScenePortal) -> void:
	active_interview_portal = portal_node
	prompt_bubble.show_above(portal_node.global_position, portal_node.prompt_text, DOOR_LIFT)


func _on_interview_exited(portal_node: ScenePortal) -> void:
	if active_interview_portal == portal_node:
		active_interview_portal = null
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
