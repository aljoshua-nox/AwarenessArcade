extends Node

## Renders the moments that move - the numbers rising off a meter, the stamps,
## CONTRADICTION, the chapter cards - caught mid-motion, so they can be judged
## without playing to them. Needs a real (non-headless) run:
##
##   godot --path . res://tools/capture_fx.tscn
##
## Writes to user://: fx_doubt_preview.png (a line raising Doubt, its number in
## the air), fx_paid_preview.png and fx_reported_preview.png (a card stamped at
## the end of a call), fx_quiz_preview.png (TACTIC READ on an interview
## portrait, cooperation rising), fx_contradiction_preview.png, and
## fx_card_caller_preview.png / fx_card_case_preview.png.

const PROLOGUE_SCENE := "res://scenes/prologue/prologue_call.tscn"
const INTERVIEW_SCENE := "res://scenes/investigation/interview.tscn"
const CASE_MARIA := "res://resources/cases/interview_case_001.json"
const CASE_MARCO := "res://resources/cases/interview_case_003.json"
const ChapterCard := preload("res://scripts/systems/chapter_card.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _capture_call()
	await _capture_quiz()
	await _capture_contradiction()
	await _capture_card("caller")
	await _capture_card("case")
	get_tree().quit()


func _wait(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	var path := "user://%s.png" % name
	var image := get_viewport().get_texture().get_image()
	if image.save_png(path) == OK:
		print("PREVIEW: %s" % ProjectSettings.globalize_path(path))
	else:
		printerr("could not save %s" % name)


func _victim(view: Node, person_id: String) -> int:
	for i in range(view.victims.size()):
		if str(view.victims[i].get("person_id", "")) == person_id:
			return i
	return -1


func _capture_call() -> void:
	SessionState.reset_session()
	SessionState.reset_prologue()
	var view: Node = load(PROLOGUE_SCENE).instantiate()
	view.suppress_scene_change = true
	add_child(view)
	await get_tree().process_frame
	view._start_call(_victim(view, "maria_santos"))
	view._finish_reveal()
	var choices: Array = view.current_node.get("choices", [])
	var loudest := 0
	for i in range(choices.size()):
		if int(choices[i].get("doubt", 0)) > int(choices[loudest].get("doubt", 0)):
			loudest = i
	view._on_choice_pressed(loudest)
	view._finish_reveal()
	await _wait(0.3)
	_save("fx_doubt_preview")

	view._load_node("paid")
	view._finish_reveal()
	await _wait(0.5)
	_save("fx_paid_preview")

	view._start_call(_victim(view, "kevin_d"))
	view._finish_reveal()
	view._end_current_call(SessionState.CALL_REFUSED, {"reports": true})
	view._finish_reveal()
	await _wait(0.5)
	_save("fx_reported_preview")
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _open(case_path: String) -> Node:
	SessionState.detective_credibility = 75
	SessionState.pending_case_path = case_path
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


func _capture_quiz() -> void:
	SessionState.reset_session()
	var view := await _open(CASE_MARIA)
	for i in range(view.current_node.get("choices", []).size()):
		if str(view.current_node["choices"][i].get("next", "")) == "ask_call":
			view._on_choice_pressed(i)
			break
	view._on_choice_pressed(0)
	var options: Array = view.current_quiz.get("options", [])
	for i in range(options.size()):
		if bool(options[i].get("correct", false)):
			view._on_choice_pressed(i)
			break
	view._finish_typing()
	await _wait(0.3)
	_save("fx_quiz_preview")
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _capture_contradiction() -> void:
	SessionState.reset_session()
	SessionState.add_evidence({
		"id": "ev_remote_access_log",
		"tactic_id": "remote_access",
		"label": "Remote Access Log",
		"description": "A session opened on the victim's machine.",
		"tactic": "Posing as technical support to gain direct access to a victim's device.",
	})
	var view := await _open(CASE_MARCO)
	view._load_node("deny_node")
	for i in range(SessionState.investigation_inventory.size()):
		if str(SessionState.investigation_inventory[i].get("id", "")) == "ev_remote_access_log":
			view._present_evidence_index(i)
			break
	view._finish_typing()
	await _wait(0.45)
	_save("fx_contradiction_preview")
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _capture_card(card_id: String) -> void:
	var card: CanvasLayer = ChapterCard.new()
	card.card_id = card_id
	get_tree().root.add_child(card)
	var deadline := Time.get_ticks_msec() + 5000
	while not card.can_skip and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _wait(0.2)
	_save("fx_card_%s_preview" % card_id)
	card._leave()
	while is_instance_valid(card):
		await get_tree().process_frame
