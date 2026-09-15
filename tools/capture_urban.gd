extends Node

## Renders the street so the block layout can be looked at, then the noticeboard
## panel open. The cast grew from three doors to five, and neither door spacing
## nor the density of the longest stop is something a headless assertion can
## judge.
##
##   godot --path . res://tools/capture_urban.tscn

const URBAN_SCENE := "res://scenes/exploration/urban_exterior.tscn"
const TERMINAL_SCENE := "res://scenes/exploration/terminal_road.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SessionState.reset_session()
	var view: Node = await _render_whole(URBAN_SCENE, "urban_preview")

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
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame

	# The second district, same framing, so the two can be compared side by side.
	SessionState.reset_session()
	view = await _render_whole(TERMINAL_SCENE, "terminal_preview")

	get_tree().quit()


func _render_whole(scene_path: String, preview_name: String) -> Node:
	var view: Node = load(scene_path).instantiate()
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

	_save(preview_name)
	return view


func _save(preview_name: String) -> void:
	var path := "user://%s.png" % preview_name
	var image := get_viewport().get_texture().get_image()
	if image.save_png(path) == OK:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(path))
	else:
		printerr("could not save %s" % preview_name)
