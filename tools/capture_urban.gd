extends Node

## Renders both streets whole so the layout can be looked at, then the
## noticeboard panel open. The cast grew from three doors to five, and neither
## door spacing nor the density of the longest stop is something a headless
## assertion can judge.
##
##   godot --path . res://tools/capture_urban.tscn

const URBAN_SCENE := "res://scenes/exploration/urban_exterior.tscn"
const TERMINAL_SCENE := "res://scenes/exploration/terminal_road.tscn"
# How far above y 0 the whole-map renders start: the frontage row is several
# storeys and stands above the map's top edge.
const SKY_SHOWN := 300


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _render_whole(URBAN_SCENE, "urban_preview")
	await _render_whole(TERMINAL_SCENE, "terminal_preview")

	# The noticeboard is the longest body on the street and the one place the
	# game gives real-world advice outright, so it is the one worth looking at.
	SessionState.reset_session()
	var view: Node = load(URBAN_SCENE).instantiate()
	add_child(view)
	for i in range(8):
		await get_tree().process_frame
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
	await AudioManager.settle()
	get_tree().quit()


# The whole map at 1:1, from SKY_SHOWN above y 0 to the bottom, without the
# HUD or the player - the same framing for both districts, so they compare.
func _render_whole(scene_path: String, preview_name: String) -> void:
	SessionState.reset_session()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080 + SKY_SHOWN)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var view: Node = load(scene_path).instantiate()
	viewport.add_child(view)
	for i in range(6):
		await get_tree().process_frame
	view.hud.visible = false
	view.player.visible = false
	view.prompt_bubble.visible = false
	(view.player.get_node("Camera2D") as Camera2D).enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(960.0, (1080.0 - SKY_SHOWN) * 0.5)
	view.add_child(camera)
	camera.make_current()
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(preview_name, viewport.get_texture().get_image())
	viewport.queue_free()
	await get_tree().process_frame


func _save(preview_name: String, image: Image = null) -> void:
	var path := "user://%s.png" % preview_name
	if image == null:
		image = get_viewport().get_texture().get_image()
	if image.save_png(path) == OK:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(path))
	else:
		printerr("could not save %s" % preview_name)
