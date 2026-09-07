extends Node

## Renders the investigation ending screen to PNGs so the layout can actually be
## looked at. Layout and density are the things a headless assertion cannot
## check, and this screen is the one that grows worst as a case fills up.
##
##   godot --path . res://tools/capture_ending.tscn
##
## Writes ending_collapsed.png and ending_expanded.png under user://, both with
## a worst-case case file loaded.

const END_SCENE := "res://scenes/investigation/investigation_end.tscn"


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


# Everything a player could be holding at the final ending: the full evidence
# set from every case, plus every milestone. This is the case the screen has to
# survive, not the empty one.
func _seed_worst_case() -> void:
	SessionState.reset_session()
	SessionState.investigation_case_title = "The Elena Cruz Confrontation"
	SessionState.investigation_person_name = "Elena Cruz"
	SessionState.investigation_outcome = "full_takedown"
	SessionState.investigation_outcome_note = "She stopped talking the moment the second testimony was read to her."
	SessionState.investigation_cooperation = 58
	SessionState.detective_credibility = 82

	for i in range(4):
		SessionState.record_tactic_read(i < 3, "Tactic %d" % i)

	for path in ["res://resources/cases/interview_case_001.json",
			"res://resources/cases/interview_case_002.json",
			"res://resources/cases/interview_case_003.json",
			"res://resources/cases/interview_case_004.json"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = parsed
		for item in data.get("evidence", []):
			if item is Dictionary:
				SessionState.add_evidence(item)
		for node in data.get("nodes", {}).values():
			for granted in node.get("grants_evidence", []):
				if granted is Dictionary:
					SessionState.add_evidence(granted)
			var quiz: Dictionary = node.get("tactic_quiz", {})
			var milestone: Dictionary = quiz.get("milestone", node.get("milestone", {}))
			if not milestone.is_empty():
				SessionState.record_reflection_milestone(
					str(milestone.get("title", "")), str(milestone.get("detail", "")))


func _run() -> void:
	_seed_worst_case()
	print("seeded %d evidence, %d milestones" % [
		SessionState.investigation_inventory.size(),
		SessionState.reflection_milestones.size()])

	var view: Node = load(END_SCENE).instantiate()
	add_child(view)
	await _settle()
	_save("ending_collapsed")

	view._toggle_section(view.evidence_header, view.evidence_value)
	view._toggle_section(view.milestones_header, view.milestones_value)
	await _settle()
	_save("ending_expanded")

	get_tree().quit()
