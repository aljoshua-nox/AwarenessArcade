extends Node

## Renders the street so the block layout can be looked at. The cast grew from
## three doors to five, and door spacing is not something a headless assertion
## can judge.
##
##   godot --path . res://tools/capture_urban.tscn

const URBAN_SCENE := "res://scenes/exploration/urban_exterior.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SessionState.reset_session()
	var view: Node = load(URBAN_SCENE).instantiate()
	add_child(view)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var camera: Camera2D = view.player.get_node("Camera2D")
	camera.zoom = Vector2(0.66, 0.66)
	view.player.global_position = Vector2(960, 540)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var path := "user://urban_preview.png"
	var image := get_viewport().get_texture().get_image()
	if image.save_png(path) == OK:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(path))
	get_tree().quit()
