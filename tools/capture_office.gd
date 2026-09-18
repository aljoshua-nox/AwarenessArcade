extends Node

## Renders the office call floor to a PNG so the map layout can be reviewed
## without playing through to it. Needs a real (non-headless) run:
##
##   godot --path . --resolution 1280x720 res://tools/capture_office.tscn
##
## Writes user://office_preview.png (the whole floor) and
## user://ledger_preview.png (the call list open, reading back a seeded shift).

const OFFICE_SCENE := "res://scenes/exploration/office_interior.tscn"
const FLOOR_FOUR_SCENE := "res://scenes/exploration/office_floor_four.tscn"
const FLOOR_FOUR_OUTPUT := "user://office_four_preview.png"
const DESK_SCENE := "res://scenes/exploration/detective_office.tscn"
const DESK_OUTPUT := "user://desk_preview.png"
const OUTPUT := "user://office_preview.png"
const LEDGER_OUTPUT := "user://ledger_preview.png"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SessionState.reset_session()
	SessionState.reset_prologue()
	# Show the unlocked state so the director's door reads as the confrontation.
	SessionState.suspect_flipped = true

	# The call list reads back prologue_call_log, and reset_prologue() empties
	# it - so this shot used to render the "page has been torn out" fallback
	# every time, and the ledger, which is the one place the two halves of the
	# game visibly connect, had never appeared in its own review screenshot.
	# Seed a mixed shift: money taken, a refusal, and a call that never landed.
	SessionState.prologue_played = true
	SessionState.record_prologue_call("maria_santos", "Maria S.", SessionState.CALL_SUCCESS, 2200)
	SessionState.record_prologue_call("kevin_d", "Kevin Dizon", SessionState.CALL_PARTIAL, 900)
	SessionState.record_prologue_call("evelyn_marsh", "Evelyn M.", SessionState.CALL_REFUSED, 0)
	SessionState.record_prologue_call("lina_reyes", "Lina Reyes", SessionState.CALL_TIMEOUT, 0)

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

	_save(OUTPUT)

	# Seeding the log above is only half of it - the ledger lives inside the
	# station panel, which this tool never opened, so the room shot alone still
	# would not show it. Open the call list and photograph the thing itself.
	for station in office.stations:
		if str(station.get("title", "")) == "The call list":
			office._open_inspection(station)
			break
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(LEDGER_OUTPUT)
	remove_child(office)
	office.queue_free()
	await get_tree().process_frame

	# The floor above, unlocked, same framing.
	SessionState.witness_flipped = true
	var upstairs: Node = load(FLOOR_FOUR_SCENE).instantiate()
	add_child(upstairs)
	await get_tree().process_frame
	var upstairs_camera := upstairs.player.get_node_or_null("Camera2D") as Camera2D
	if upstairs_camera != null:
		upstairs_camera.enabled = false
	var camera_four := Camera2D.new()
	upstairs.add_child(camera_four)
	camera_four.position = Vector2(640.0, 360.0)
	camera_four.zoom = Vector2.ONE
	camera_four.make_current()
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(FLOOR_FOUR_OUTPUT)
	remove_child(upstairs)
	upstairs.queue_free()
	await get_tree().process_frame

	# The detective's desk, as the case opens on it: nothing taken yet.
	SessionState.reset_investigation()
	var desk: Node = load(DESK_SCENE).instantiate()
	add_child(desk)
	await get_tree().process_frame
	var desk_camera := desk.player.get_node_or_null("Camera2D") as Camera2D
	if desk_camera != null:
		desk_camera.enabled = false
	var camera_desk := Camera2D.new()
	desk.add_child(camera_desk)
	camera_desk.position = Vector2(640.0, 360.0)
	camera_desk.zoom = Vector2.ONE
	camera_desk.make_current()
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(DESK_OUTPUT)

	get_tree().quit()


func _save(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		printerr("could not save preview: %d" % error)
	else:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(path))
