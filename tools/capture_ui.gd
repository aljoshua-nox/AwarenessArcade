extends Node

## Renders UI screens to PNGs so layout and theming can be reviewed without
## playing to them. Needs a real (non-headless) run:
##
##   godot --path . res://tools/capture_ui.tscn
##
## Writes prologue_preview.png, prologue_ending_preview.png,
## prologue_summary_preview.png, evidence_preview.png and harm_preview.png under
## user://. The second is the densest a call gets: a
## paid ending, with the tactic-used line, the call-ended line, a report and the
## victim afterwards all in the box. The last is the densest an interview
## opening gets: a harmed victim's own words quoted off the call record, on top
## of the authored case note.

const PROLOGUE_SCENE := "res://scenes/prologue/prologue_call.tscn"
const PROLOGUE_END_SCENE := "res://scenes/prologue/prologue_end.tscn"
const INTERVIEW_SCENE := "res://scenes/investigation/interview.tscn"
const CASE_MARIA := "res://resources/cases/interview_case_001.json"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _capture_prologue()
	await _capture_prologue_ending()
	await _capture_prologue_summary()
	await _capture_evidence_list()
	await _capture_harmed_opening()
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


# One answered line, then straight to the refusal ending: the transcript holds
# the dialing line, the opening, the player's line, the tactic it was, the
# victim's reply, CALL ENDED, REPORTED and AFTER THE CALL at once.
func _capture_prologue_ending() -> void:
	SessionState.reset_session()
	SessionState.reset_prologue()
	var view: Node = load(PROLOGUE_SCENE).instantiate()
	view.suppress_scene_change = true
	add_child(view)
	await get_tree().process_frame
	view._start_call(0)
	view._finish_reveal()
	view._on_choice_pressed(1)
	view._finish_reveal()
	view._load_node("refused")
	view._finish_reveal()
	await _settle()
	_save("prologue_ending_preview")
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


# The shift summary after a full shift: three calls with three different
# outcomes, each quoted, and the tactics used listed above them.
func _capture_prologue_summary() -> void:
	SessionState.reset_session()
	SessionState.reset_prologue()
	SessionState.prologue_played = true
	SessionState.calls_made = 3
	SessionState.reports_filed = 1
	SessionState.profit = 23500
	SessionState.record_tactic_used("authority_impersonation")
	SessionState.record_tactic_used("manufactured_urgency")
	SessionState.record_prologue_call("maria_santos", "Maria S.", SessionState.CALL_SUCCESS, 18500,
		"He sounded like the bank. He even knew about the text. I read the code out like I was helping, and it was my medicine money going out the door while I was saying thank you.")
	SessionState.record_prologue_call("evelyn_marsh", "Evelyn Marsh", SessionState.CALL_REFUSED, 0,
		"I told him winnings don't have an entry fee and he hung up. Rather rude, in the end.")
	SessionState.record_prologue_call("lina_reyes", "Lina Reyes", SessionState.CALL_PARTIAL, 5000,
		"I only sent half. I thought that was clever.")
	SessionState.record_reflection_milestone("First Report Filed", "Someone you called kept the number and passed it on.")
	SessionState.prologue_end_reason = "Shift Ended Early"
	SessionState.prologue_end_note = "You logged off the floor to see what the calls left behind."
	var view: Node = load(PROLOGUE_END_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	await _settle()
	_save("prologue_summary_preview")
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _capture_evidence_list() -> void:
	SessionState.reset_session()
	# Above Maria's gate of 55. Without this she takes the hesitant branch, which
	# seeds no evidence at all - so this shot was of an empty list, and the
	# select(1) below was throwing an out-of-bounds every run.
	SessionState.detective_credibility = 75
	SessionState.pending_case_path = CASE_MARIA
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame

	# Walk to the evidence step, then open the list and select a row with the
	# list focused - the state where the whole panel used to wash out.
	view._on_choice_pressed(_choice_to(view, "ask_call"))
	view._on_choice_pressed(0)
	view._on_choice_pressed(_quiz_answer(view, true))
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


# The worst case for the opening beat: a harmed disposition, whose prompt is
# already the longest in the case, carrying a quoted consequence off the call
# record AND the authored note. Density here cannot be asserted - look at it.
func _capture_harmed_opening() -> void:
	SessionState.reset_session()
	SessionState.prologue_played = true
	SessionState.detective_credibility = 80
	SessionState.record_prologue_call("maria_santos", "Maria S.", SessionState.CALL_SUCCESS, 18500,
		"I trusted the caller because they sounded like bank staff. Now I am trying to figure out how to cover medicine and groceries.")
	SessionState.pending_case_path = CASE_MARIA
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	view._finish_typing()
	await _settle()
	_save("harm_preview")
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame

# Quiz options are shuffled when the quiz opens, so a test that wants the right
# (or a wrong) answer has to look at the buttons as dealt rather than press a
# fixed slot.
func _quiz_answer(view: Node, correct: bool) -> int:
	var options: Array = view.current_quiz.get("options", [])
	for i in range(options.size()):
		if bool(options[i].get("correct", false)) == correct:
			return i
	return -1

# Choices are authored in a deliberate order, and that order changes when the
# writing does - the harsh line is no longer always last. A walk names the node
# it wants to reach instead of a slot.
func _choice_to(view: Node, node_id: String) -> int:
	var choices: Array = view.current_node.get("choices", [])
	for i in range(choices.size()):
		if str(choices[i].get("next", "")) == node_id:
			return i
	return -1
