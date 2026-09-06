extends Node

## Renders the office call floor to a PNG so the map layout can be reviewed
## without playing through to it. Needs a real (non-headless) run:
##
##   godot --path . --resolution 1280x720 res://tools/capture_office.tscn
##
## Writes to user://office_preview.png and prints the absolute path.

const OFFICE_SCENE := "res://scenes/exploration/office_interior.tscn"
const OUTPUT := "user://office_preview.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SessionState.reset_session()
	SessionState.reset_prologue()
	# Show the unlocked state so the director's door reads as the confrontation.
	SessionState.suspect_flipped = true

	var office: Node = load(OFFICE_SCENE).instantiate()
	add_child(office)
	await get_tree().process_frame

	# Replace the player-following camera with a fixed one on the room, so the
	# whole floor is in frame.
	var player_camera := office.player.get_node_or_null("Camera2D") as Camera2D
	if player_camera != null:
		player_camera.enabled = false

	var camera := Camera2D.new()
	office.add_child(camera)
	camera.position = Vector2(640.0, 360.0)
	camera.zoom = Vector2.ONE
	camera.make_current()

	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT)
	if error != OK:
		printerr("could not save preview: %d" % error)
	else:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(OUTPUT))
	get_tree().quit()
