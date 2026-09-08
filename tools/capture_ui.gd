extends Node

## Renders UI screens to PNGs so layout and theming can be reviewed without
## playing to them. Needs a real (non-headless) run:
##
##   godot --path . res://tools/capture_ui.tscn
##
## Writes prologue_preview.png and evidence_preview.png under user://.

const PROLOGUE_SCENE := "res://scenes/prologue/prologue_call.tscn"
const INTERVIEW_SCENE := "res://scenes/investigation/interview.tscn"
const CASE_MARIA := "res://resources/cases/interview_case_001.json"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _capture_prologue()
	await _capture_evidence_list()
	get_tree().quit()


func _settle(frames: int = 5) -> void:
	for i in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	var path := "user://%s.png" % name
	var image := get_viewport().get_texture().get_image()
	if image.save_png(path) == OK:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(path))
	else:
		printerr("could not save %s" % name)


func _capture_prologue() -> void:
	SessionState.reset_session()
	SessionState.reset_prologue()
	var view: Node = load(PROLOGUE_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	# The transcript types itself in now, so an empty box would be all this
	# caught. Open a call and skip to the end of the reveal to render a settled
	# screen with real dialogue in it.
	view._start_call(0)
	view._finish_reveal()
	await _settle()
	_save("prologue_preview")
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _capture_evidence_list() -> void:
	SessionState.reset_session()
	SessionState.pending_case_path = CASE_MARIA
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame

	# Walk to the evidence step, then open the list and select a row with the
	# list focused - the state where the whole panel used to wash out.
	view._on_choice_pressed(1)
	view._on_choice_pressed(0)
	view._on_choice_pressed(0)
	view._on_present_evidence_pressed()
	view._finish_typing()
	await get_tree().process_frame
	view.evidence_list.select(1)
	view.evidence_list.grab_focus()

	await _settle()
	_save("evidence_preview")
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame
