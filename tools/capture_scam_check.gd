extends Node

## Renders the Scam Check's pages to PNGs, so the layout can be looked at: a
## message has to read at a glance, and the results hold sixteen messages side
## by side.
##
##   godot --path . res://tools/capture_scam_check.tscn
##
## Writes to user://: menu_scam_check.png (the main menu), scam_check_home.png,
## scam_check_intro.png, scam_check_text.png, scam_check_flag.png,
## scam_check_call.png, scam_check_chat.png, scam_check_saved.png,
## ending_after_check.png (a closing screen offering the after check),
## scam_check_results.png, scam_check_results_rows.png,
## scam_check_results_end.png and scam_check_home_checks.png. Uses a
## scratch record and deletes it.

const ScamCheckData := preload("res://scripts/scam_check/scam_check_data.gd")

const SCENE := "res://scenes/scam_check/scam_check.tscn"
const MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const END_SCENE := "res://scenes/investigation/investigation_end.tscn"
const SCRATCH := "user://capture_scam_check.cfg"
const SCRATCH_ENDINGS := "user://capture_scam_check_endings.cfg"


func _ready() -> void:
	_run.call_deferred()


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


func _open(scene_path: String) -> Node:
	var view: Node = load(scene_path).instantiate()
	add_child(view)
	await _settle()
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _run() -> void:
	SessionState.scam_check_path = SCRATCH
	SessionState.ending_record_path = SCRATCH_ENDINGS
	var data := ScamCheckData.new()
	data.clear()

	var view := await _open(MENU_SCENE)
	_save("menu_scam_check")
	await _close(view)

	view = await _open(SCENE)
	_save("scam_check_home")
	view.show_intro(view.MODE_BEFORE)
	await _settle()
	_save("scam_check_intro")
	view._begin()
	await _settle()
	_save("scam_check_text")
	view._ask_flag()
	await _settle(8)
	_save("scam_check_flag")
	# The first call and the first chat in set A.
	for wanted in [["call", "scam_check_call"], ["chat", "scam_check_chat"]]:
		for i in range(view.run_items.size()):
			if str(view.run_items[i].get("kind", "")) == wanted[0] and bool(view.run_items[i].get("scam", false)):
				view.item_index = i
				break
		view.show_message()
		await _settle()
		_save(wanted[1])
	view.show_saved()
	await _settle()
	_save("scam_check_saved")
	await _close(view)

	# A before check that missed most scams and trusted one real message too
	# few; an after check that spotted every scam but raised a false alarm.
	var before: Array = []
	var index := 0
	for entry in data.items_in("A"):
		var scam := bool(entry.get("scam", false))
		var call := ScamCheckData.CALL_LEGIT if scam and index % 2 == 0 else ScamCheckData.CALL_SCAM if scam else ScamCheckData.CALL_LEGIT
		if not scam and index == 1:
			call = ScamCheckData.CALL_SCAM
		before.append({"item": entry.id, "call": call, "flag": 2 if call == ScamCheckData.CALL_SCAM else -1})
		index += 1
	data.save_before("A", before)
	data.note_route(ScamCheckData.ROUTE_PROLOGUE)

	SessionState.reset_session()
	SessionState.investigation_case_title = "The Elena Cruz Confrontation"
	SessionState.investigation_person_name = "Elena Cruz"
	SessionState.investigation_outcome = "full_takedown"
	view = await _open(END_SCENE)
	_save("ending_after_check")
	await _close(view)

	var after: Array = []
	index = 0
	for entry in data.items_in("B"):
		var scam := bool(entry.get("scam", false))
		var flag := -1
		if scam:
			var flags: Array = entry.get("flags", [])
			for i in range(flags.size()):
				if not str(flags[i].get("tactic_id", "")).is_empty():
					flag = i
					break
		var call := ScamCheckData.CALL_SCAM if scam or index == 0 else ScamCheckData.CALL_LEGIT
		after.append({"item": entry.id, "call": call, "flag": flag if scam else 0})
		index += 1
	data.save_after(after)

	SessionState.scam_check_entry = SessionState.SCAM_CHECK_FROM_ENDING
	view = await _open(SCENE)
	view.show_results(1)
	await _settle(8)
	_save("scam_check_results")
	view.body_scroll.scroll_vertical = 700
	await _settle()
	_save("scam_check_results_rows")
	view.body_scroll.scroll_vertical = int(view.body_scroll.get_v_scroll_bar().max_value)
	await _settle()
	_save("scam_check_results_end")
	await _close(view)

	data.save_before("B", before)
	data.save_before("A", before)
	SessionState.scam_check_entry = ""
	view = await _open(SCENE)
	_save("scam_check_home_checks")
	await _close(view)

	data.clear()
	SessionState.clear_ending_record()
	await AudioManager.settle()
	get_tree().quit()
