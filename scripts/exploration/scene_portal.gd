extends Area2D
class_name ScenePortal

signal player_entered(portal: ScenePortal)
signal player_exited(portal: ScenePortal)

@export_file("*.tscn") var target_scene: String = ""
@export var prompt_text: String = "Press Enter to travel"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_entered.emit(self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_exited.emit(self)
