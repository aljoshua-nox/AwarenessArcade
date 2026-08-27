extends Node2D

@export var map_title: String = "Urban Block"
@export var map_hint: String = "Move with WASD or arrow keys. Press Enter at the office door."
@export_file("*.tscn") var portal_target_scene: String = "res://scenes/exploration/office_interior.tscn"
@export var player_spawn: Vector2 = Vector2(180, 540)
@export var movement_bounds: Rect2 = Rect2(Vector2(48, 48), Vector2(1184, 624))

@onready var decor: Node2D = %Decor
@onready var player: ExplorationPlayer = %Player
@onready var title_label: Label = %MapTitle
@onready var hint_label: Label = %MapHint
@onready var portal_label: Label = %PortalLabel
@onready var portal: ScenePortal = %Portal
@onready var fade_overlay: ColorRect = %FadeOverlay

const URBAN_BACKGROUND := preload("res://assets/art/maps/kenney_roguelike-modern-city/Sample.png")


func _ready() -> void:
	title_label.text = map_title
	hint_label.text = map_hint
	player.global_position = player_spawn
	player.movement_bounds = movement_bounds
	portal.target_scene = portal_target_scene
	portal.prompt_text = "Enter the office"
	portal.player_entered.connect(_on_portal_entered)
	portal.player_exited.connect(_on_portal_exited)
	_build_map()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SessionState.go_to_menu()
	elif event.is_action_pressed("ui_accept") and _can_enter_portal():
		_transition_to_scene(portal.target_scene)


func _build_map() -> void:
	_clear_decor()
	var viewport_size := get_viewport().get_visible_rect().size
	_add_fitted_background(URBAN_BACKGROUND, viewport_size, -40, Color(1, 1, 1, 1.0))
	portal.global_position = Vector2(470.0, 320.0)
	portal_label.visible = false


func _clear_decor() -> void:
	for child in decor.get_children():
		child.queue_free()


func _add_fitted_background(texture: Texture2D, viewport_size: Vector2, z_index: int, tint: Color) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = viewport_size * 0.5
	sprite.z_index = z_index
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var texture_size := texture.get_size()
	var scale_factor := maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)
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
