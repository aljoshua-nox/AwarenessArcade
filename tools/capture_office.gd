extends Node

## Renders the office call floor to a PNG so the map layout can be reviewed
## without playing through to it. Needs a real (non-headless) run:
##
##   godot --path . --resolution 1280x720 res://tools/capture_office.tscn
##
## Writes user://office_preview.png (the whole floor) and
## user://ledger_preview.png (the call list open, reading back a seeded shift).

const OFFICE_SCENE := "res://scenes/exploration/office_interior.tscn"
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

	get_tree().quit()


func _save(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		printerr("could not save preview: %d" % error)
	else:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(path))
