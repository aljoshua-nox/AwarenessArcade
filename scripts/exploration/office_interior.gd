extends Node2D

@export var map_title: String = "Office Interior"
@export var map_hint: String = "Explore the office. Press Enter at the exit to go back outside."
@export_file("*.tscn") var portal_target_scene: String = "res://scenes/exploration/urban_exterior.tscn"
@export var player_spawn: Vector2 = Vector2(320, 540)
@export var movement_bounds: Rect2 = Rect2(Vector2(48, 48), Vector2(1184, 624))

@onready var decor: Node2D = %Decor
@onready var player: ExplorationPlayer = %Player
@onready var title_label: Label = %MapTitle
@onready var hint_label: Label = %MapHint
@onready var portal_label: Label = %PortalLabel
@onready var portal: ScenePortal = %Portal
@onready var fade_overlay: ColorRect = %FadeOverlay

const ROOM_BASE := Color(0.73, 0.70, 0.63, 1.0)
const OFFICE_WALLS := preload("res://assets/art/maps/office/wall_tiles.png")
const OFFICE_FLOOR := preload("res://assets/art/maps/office/floor_tiles.png")
const DESK := preload("res://assets/art/maps/office/desk.png")
const DESK_WITH_PC := preload("res://assets/art/maps/office/desk_with_pc.png")
const CABINET := preload("res://assets/art/maps/office/cabinet.png")
const PLANT := preload("res://assets/art/maps/office/plant.png")
const PARTITION_1 := preload("res://assets/art/maps/office/partition_1.png")
const PARTITION_2 := preload("res://assets/art/maps/office/partition_2.png")
const WATER_COOLER := preload("res://assets/art/maps/office/water_cooler.png")
const PRINTER := preload("res://assets/art/maps/office/printer.png")


func _ready() -> void:
	title_label.text = map_title
	hint_label.text = map_hint
	player.global_position = player_spawn
	player.movement_bounds = movement_bounds
	portal.target_scene = portal_target_scene
	portal.prompt_text = "Return to the street"
	portal.player_entered.connect(_on_portal_entered)
	portal.player_exited.connect(_on_portal_exited)
	_build_map()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SessionState.go_to_scene("res://scenes/main_menu/main_menu.tscn")
	elif event.is_action_pressed("ui_accept") and _can_enter_portal():
		_transition_to_scene(portal.target_scene)


func _build_map() -> void:
	_clear_decor()
	var viewport_size := get_viewport().get_visible_rect().size
	_add_solid_background(viewport_size, -40, ROOM_BASE)
	_add_scaled_sprite(OFFICE_WALLS, Vector2(viewport_size.x * 0.5, 188.0), Vector2(viewport_size.x / OFFICE_WALLS.get_width(), 1.9), -30, Color(0.98, 0.98, 0.98, 1.0))
	_add_scaled_sprite(OFFICE_FLOOR, Vector2(viewport_size.x * 0.5, 510.0), Vector2(viewport_size.x / OFFICE_FLOOR.get_width(), 6.2), -29, Color(1.0, 1.0, 1.0, 1.0))

	_add_sprite(PARTITION_1, Vector2(320.0, 322.0), Vector2(2.0, 2.0), -10)
	_add_sprite(PARTITION_2, Vector2(620.0, 322.0), Vector2(2.0, 2.0), -10)
	_add_sprite(DESK, Vector2(250.0, 520.0), Vector2(2.0, 2.0), -8)
	_add_sprite(DESK_WITH_PC, Vector2(530.0, 500.0), Vector2(2.0, 2.0), -8)
	_add_sprite(PRINTER, Vector2(150.0, 470.0), Vector2(2.0, 2.0), -8)
	_add_sprite(CABINET, Vector2(1125.0, 520.0), Vector2(2.0, 2.0), -8)
	_add_sprite(PLANT, Vector2(1080.0, 450.0), Vector2(2.0, 2.0), -8)
	_add_sprite(WATER_COOLER, Vector2(1000.0, 500.0), Vector2(2.0, 2.0), -8)

	portal.global_position = Vector2(122.0, 540.0)
	portal_label.visible = false


func _clear_decor() -> void:
	for child in decor.get_children():
		child.queue_free()


func _add_solid_background(viewport_size: Vector2, z_index: int, tint: Color) -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(tint)
	var texture := ImageTexture.create_from_image(image)
	_add_scaled_sprite(texture, viewport_size * 0.5, Vector2(viewport_size.x, viewport_size.y), z_index, Color(1, 1, 1, 1))


func _add_scaled_sprite(texture: Texture2D, position: Vector2, scale: Vector2, z_index: int, tint: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = position
	sprite.z_index = z_index
	sprite.modulate = tint
	sprite.scale = scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor.add_child(sprite)


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
