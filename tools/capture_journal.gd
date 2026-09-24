extends Node

## Renders the case journal and the pause menu over the street so the overlay
## can be reviewed without playing to it. Needs a real (non-headless) run:
##
##   godot --path . res://tools/capture_journal.tscn
##
## Writes briefing_preview.png (the case file as it opens on arrival, after a
## reported shift), objectives_preview.png (the case file mid-case: one
## objective closed, some done, some open), people_preview.png (every door,
## mid-case), evidence_preview.png (a file with three items in it),
## journal_preview.png (the Tactics tab with one entry recorded) and
## pause_preview.png (the pause menu on its confirm step, the one screen it
## exists for) under user://.

const URBAN_SCENE := "res://scenes/exploration/urban_exterior.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SessionState.reset_session()
	SessionState.record_tactic_learned("manufactured_urgency", "Named while interviewing Maria Santos")
	var view: Node = load(URBAN_SCENE).instantiate()
	add_child(view)
	await _settle()

	SessionState.prologue_played = true
	SessionState.reports_filed = 3
	CaseJournal.show_briefing()
	await _settle()
	_save("briefing_preview")
	CaseJournal.close()
	SessionState.prologue_played = false
	SessionState.reports_filed = 0

	# Mid-case: a statement taken, a witness lost, the operator lawyered up.
	SessionState.statements_taken = 2
	SessionState.record_interview_outcome("evelyn_marsh", "success")
	SessionState.record_interview_outcome("maria_santos", "partial", true)
	SessionState.record_interview_outcome("kevin_d", "failure")
	SessionState.record_statement("kevin_d", "Victim", "failure", false)
	SessionState.record_interview_outcome("marco_navarro", "failure")
	SessionState.case_locked = true
	SessionState.add_evidence({"id": "test_evelyn_confirmed", "label": "Evelyn's Statement",
		"description": "The raffle call, the fee, the refusal - on record.", "tactic": "Advance fee: a prize that costs money to collect", "person_id": "evelyn_marsh", "script": "lottery", "secured": true})
	SessionState.add_evidence({"id": "ev_raffle_stub", "label": "The Raffle Stub",
		"description": "A ticket for a draw she never entered.", "tactic": "Unsolicited prize", "person_id": "evelyn_marsh"})
	SessionState.add_evidence({"id": "ev_phishing_text", "label": "The Text Before The Call",
		"description": "A message four minutes before the call, from a number that is not her bank's.", "tactic": "Manufactured urgency", "person_id": "maria_santos"})
	for tab in [CaseJournal.TAB_OBJECTIVES, CaseJournal.TAB_PEOPLE, CaseJournal.TAB_EVIDENCE]:
		CaseJournal.open(tab)
		await _settle()
		_save({CaseJournal.TAB_OBJECTIVES: "objectives_preview", CaseJournal.TAB_PEOPLE: "people_preview",
			CaseJournal.TAB_EVIDENCE: "evidence_preview"}[tab])
		CaseJournal.close()
	SessionState.reset_investigation()
	SessionState.record_tactic_learned("manufactured_urgency", "Named while interviewing Maria Santos")

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
