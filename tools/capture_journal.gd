extends Node

## Renders the case journal and the pause menu over the street so the overlay
## can be reviewed without playing to it. Needs a real (non-headless) run:
##
##   godot --path . res://tools/capture_journal.tscn
##
## Writes journal_preview.png (the journal open on its Tactics tab with one
## entry recorded) and pause_preview.png (the pause menu on its confirm step,
## the one screen it exists for) under user://.

const URBAN_SCENE := "res://scenes/exploration/urban_exterior.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SessionState.reset_session()
	SessionState.record_tactic_learned("manufactured_urgency", "Named while interviewing Maria Santos")
	var view: Node = load(URBAN_SCENE).instantiate()
	add_child(view)
	await _settle()

	CaseJournal.open(CaseJournal.TAB_TACTICS)
	await _settle()
	_save("journal_preview")
	CaseJournal.close()

	CaseJournal.open_pause()
	CaseJournal._ask_to_abandon()
	await _settle()
	_save("pause_preview")
	CaseJournal.close_pause()

	remove_child(view)
	view.queue_free()
	await get_tree().process_frame
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
