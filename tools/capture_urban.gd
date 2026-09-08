extends Node

## Renders the street so the block layout can be looked at, then the noticeboard
## panel open. The cast grew from three doors to five, and neither door spacing
## nor the density of the longest stop is something a headless assertion can
## judge.
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

	_save("urban_preview")

	# The noticeboard is the longest body on the street and the one place the
	# game gives real-world advice outright, so it is the one worth looking at.
	for stop in view.street_stops:
		if bool(stop.get("is_noticeboard", false)):
			view._open_stop(stop)
			break
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("noticeboard_preview")

	get_tree().quit()


func _save(preview_name: String) -> void:
	var path := "user://%s.png" % preview_name
	var image := get_viewport().get_texture().get_image()
	if image.save_png(path) == OK:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(path))
	else:
		printerr("could not save %s" % preview_name)
