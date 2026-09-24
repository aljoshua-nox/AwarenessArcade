extends Node

## Headless smoke test for the investigation ending screen.
##
##   godot --headless --path . res://tools/test_ending.tscn
##
## Exits 0 if every check passes, 1 otherwise. The ending had no coverage at
## all before the awareness verdict was folded into it.

const END_SCENE := "res://scenes/investigation/investigation_end.tscn"
# Every final ending this suite opens goes on the record, so the record it
# writes is a scratch one, deleted at the end.
const SCRATCH_RECORD := "user://test_endings.cfg"

# SessionState's fields that are not investigation state, so they are not in
# the snapshot a reopened case restores. A new field on SessionState has to be
# named here or in INVESTIGATION_STATE, or the classification check fails -
# which is the point: a field nobody classified would silently survive a
# reopen.
const PROLOGUE_AND_META_STATE := [
	"calls_made", "victims_affected", "reports_filed", "profit", "time_left",
	"prologue_tactics_used", "prologue_end_reason", "prologue_end_note",
	"prologue_call_log", "prologue_played",
	"checkpoints", "ending_record_path",
]

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("  FAIL  %s" % label)
	else:
		print("  ok    %s" % label)


func _open(outcome: String) -> Node:
	SessionState.investigation_outcome = outcome
	SessionState.investigation_outcome_note = "test note"
	var view: Node = load(END_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


# Seed a session that answered `correct` of `total` tactic quizzes.
func _seed_reads(correct: int, total: int, missed_names: Array) -> void:
	SessionState.reset_session()
	var miss_index := 0
	for i in range(total):
		var is_correct := i < correct
		var tactic := ""
		# A miss may be given as a name, or as [name, catalogue id] when the test
		# cares about the advice the ending answers it with.
		var tactic_id := ""
		if not is_correct and miss_index < missed_names.size():
			var named: Variant = missed_names[miss_index]
			if named is Array:
				tactic = str(named[0])
				tactic_id = str(named[1])
			else:
				tactic = str(named)
			miss_index += 1
		elif is_correct:
			tactic = "Read tactic %d" % i
		SessionState.record_tactic_read(is_correct, tactic, tactic_id)


func _run() -> void:
	print("\n--- investigation ending smoke test ---")
	SessionState.ending_record_path = SCRATCH_RECORD
	SessionState.clear_ending_record()
	await _test_tiers()
	await _test_verdict_reaches_the_ending()
	await _test_verdict_changes_with_awareness()
	await _test_missed_tactics_are_named()
	await _test_untested_and_midcase()
	await _test_sections_start_collapsed()
	await _test_lockout_ending()
	await _test_ending_record()
	await _test_checkpoints()
	await _test_reopen_from_the_ending()
	SessionState.clear_ending_record()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	# A sound still in the mixer at quit is reported as a leak.
	await AudioManager.settle()
	get_tree().quit(1 if failures.size() > 0 else 0)


# The reference lists used to unroll to roughly forty lines and bury the
# ending under themselves. They are still one click away, just not by default.
func _test_sections_start_collapsed() -> void:
	print("\n[the lists do not bury the ending]")
	_seed_reads(2, 4, ["Manufactured urgency"])
	SessionState.add_evidence({"id": "a", "label": "Phishing text", "tactic": "Manufactured urgency"})
	SessionState.add_evidence({"id": "b", "label": "Bank alert", "tactic": "Denying time to verify"})
	# One the interview earned, against two the victim had on the table.
	SessionState.add_evidence({"id": "t", "label": "Maria's Confirmed Testimony",
		"tactic": "A confirmed victim testimony", "secured": true, "script": "bank_fraud"})
	SessionState.statements_taken = 1
	SessionState.record_reflection_milestone("Key Witness Secured", "She confirmed the text.",
		SessionState.MILESTONE_CASE)
	SessionState.record_reflection_milestone("First Report Filed", "A call crossed the report threshold.")

	var view := await _open("full_takedown")
	_check(not view.evidence_value.visible, "evidence starts collapsed")
	_check(not view.milestones_value.visible, "milestones start collapsed")
	_check(not view.records_value.visible, "so do the records")
	_check(not view.observations_value.visible, "and what was noticed along the way")
	_check(view.evidence_header.text.contains("(1)"),
		"statements count only what the interview earned (%s)" % view.evidence_header.text)
	_check(view.records_header.text.contains("(2)"),
		"records count what the victim had on the table (%s)" % view.records_header.text)
	_check(view.milestones_header.text.contains("(1)"), "the interviews' milestones are counted apart")
	_check(view.observations_header.text.contains("(1)"), "...from the ones read off a wall")
	_check(view.evidence_header.text.begins_with(">"), "a collapsed section points right")

	# The one line that says what the case holds, above every list.
	_check(view.case_profile.text.contains("1 statement taken"),
		"the profile counts the statements (%s)" % view.case_profile.text)
	_check(view.case_profile.text.contains("1 scam proved"), "...and the scams they prove")
	_check(view.case_profile.text.contains("owner not named"), "...and says the owner is missing")
	_check(view.case_profile.text.contains("THE CASE FILE"), "...as the case file talking")

	# The ending itself is never hidden behind a click.
	_check(view.outcome_note.text.length() > 0, "the verdict is visible without expanding anything")

	view._toggle_section(view.evidence_header, view.evidence_value)
	_check(view.evidence_value.visible, "clicking the header expands it")
	_check(view.evidence_header.text.begins_with("v"), "an expanded section points down")
	_check(view.evidence_value.text.contains("Maria's Confirmed Testimony"), "the expanded list names the statement")
	_check(view.evidence_value.text.contains("A confirmed victim testimony"), "and keeps the tactic it proves")
	view._toggle_section(view.records_header, view.records_value)
	_check(view.records_value.text.contains("Phishing text") and view.records_value.text.contains("Bank alert"),
		"the records list holds what was handed over")
	_check(not view.evidence_value.text.contains("Phishing text"), "...and the two lists do not repeat each other")
	view._toggle_section(view.records_header, view.records_value)
	_check(view.evidence_value.fit_content, "the list grows rather than clipping as evidence accumulates")

	view._toggle_section(view.evidence_header, view.evidence_value)
	_check(not view.evidence_value.visible, "clicking again collapses it")

	_check(view.awareness_bar.visible, "the awareness bar shows once a quiz has been answered")
	_check(is_equal_approx(view.awareness_bar.value, 50.0),
		"the bar reflects 2 of 4 (got %.0f)" % view.awareness_bar.value)
	await _close(view)

	# With no quizzes answered there is no ratio to draw.
	SessionState.reset_session()
	var bare := await _open("full_takedown")
	_check(not bare.awareness_bar.visible, "the bar hides when nothing has been tested")
	await _close(bare)


func _test_lockout_ending() -> void:
	print("
[the insufficient-evidence ending]")
	_seed_reads(4, 4, [])
	var view := await _open("insufficient_evidence")
	_check(view.outcome_label.text.contains("Insufficient Evidence"), "the fourth ending has its own title")
	_check(view.outcome_note.text.contains("nobody charged"), "it says plainly that nobody was charged")
	_check(view.outcome_note.text.contains("not the same as being able to prove"),
		"a sharp reading gets its own verdict here too")
	_check(not view.continue_button.visible, "it is a true ending, not a mid-case summary")
	await _close(view)

	# The fifth ending: both floors fall and the owner walks.
	_seed_reads(4, 4, [])
	view = await _open("building_stands")
	_check(not view.continue_button.visible, "the building standing is a true ending too")
	_check(view.outcome_label.text.contains("Building Stands"), "...with its own title (%s)" % view.outcome_label.text)
	_check(view.outcome_note.text.contains("never got was a name"), "...and a sharp verdict of its own")
	for tier in ["sharp", "mixed", "blind"]:
		_check(view.AWARENESS_VERDICTS["building_stands"].has(tier), "...and a verdict for the %s reader" % tier)
	await _close(view)
	view = await _open("insufficient_evidence")
	await _close(view)

	_seed_reads(0, 4, ["Manufactured urgency"])
	var blind := await _open("insufficient_evidence")
	_check(blind.outcome_note.text.contains("Nothing was proved and nothing was understood"),
		"a blind reading gets the harsher one")
	await _close(blind)


func _test_tiers() -> void:
	print("\n[awareness tiers]")
	SessionState.reset_session()
	_check(SessionState.get_awareness_tier() == SessionState.AWARENESS_UNTESTED,
		"a session with no quizzes is untested")
	_seed_reads(4, 4, [])
	_check(SessionState.get_awareness_tier() == SessionState.AWARENESS_SHARP, "all correct reads as sharp")
	_seed_reads(2, 4, ["Manufactured urgency", "The impossible scan"])
	_check(SessionState.get_awareness_tier() == SessionState.AWARENESS_MIXED, "some correct reads as mixed")
	_seed_reads(0, 3, ["Manufactured urgency", "The impossible scan", "The reused victim list"])
	_check(SessionState.get_awareness_tier() == SessionState.AWARENESS_BLIND, "none correct reads as blind")


func _test_verdict_reaches_the_ending() -> void:
	print("\n[the verdict reaches the ending text]")
	_seed_reads(4, 4, [])
	var view := await _open("full_takedown")
	_check(view.outcome_note.text.contains("name every lever"),
		"a sharp reading is stated in the ending itself, not just the scorecard")
	await _close(view)


func _test_verdict_changes_with_awareness() -> void:
	print("\n[the same ending reads differently]")
	_seed_reads(0, 4, ["Manufactured urgency"])
	var blind_view := await _open("full_takedown")
	var blind_text: String = blind_view.outcome_note.text
	await _close(blind_view)

	_seed_reads(4, 4, [])
	var sharp_view := await _open("full_takedown")
	var sharp_text: String = sharp_view.outcome_note.text
	await _close(sharp_view)

	_check(blind_text != sharp_text, "the same outcome ends differently depending on awareness")
	_check(blind_text.contains("The scripts are not"), "a blind takedown says the scripts outlive the office")
	_check(not sharp_text.contains("The scripts are not"), "a sharp takedown does not")

	# The sharpest line in the game: understanding did not stop the bribe.
	_seed_reads(4, 4, [])
	var bribed := await _open("bribed")
	_check(bribed.outcome_note.text.contains("never the thing standing in the way"),
		"reading every tactic and taking the bribe anyway has its own ending")
	await _close(bribed)


func _test_missed_tactics_are_named() -> void:
	print("\n[the misses are named]")
	_seed_reads(1, 3, ["Manufactured urgency", "The impossible scan"])
	var missed := SessionState.get_missed_tactics()
	_check(missed.size() == 2, "both misses are recorded (got %d)" % missed.size())
	_check(missed.has("Manufactured urgency"), "a missed tactic is named")

	# A retried interview must not list the same miss twice.
	SessionState.record_tactic_read(false, "Manufactured urgency")
	_check(SessionState.get_missed_tactics().size() == 2, "a repeated miss is not listed twice")

	var view := await _open("partial_justice")
	_check(view.scorecard_value.text.contains("Went unnamed"), "the scorecard lists what went unnamed")
	_check(view.scorecard_value.text.contains("The impossible scan"), "it names the specific tactic")
	await _close(view)

	# The ending is the last screen of the run, so a miss is answered here with
	# the catalogue's own defense rather than a pointer to a tab nobody reopens.
	_seed_reads(0, 2, [["Manufactured urgency", "manufactured_urgency"],
		["The impossible scan", "impossible_scan"]])
	view = await _open("partial_justice")
	var advice := TacticNotebook.spot_it("manufactured_urgency")
	_check(not advice.is_empty(), "the catalogue has a defense for the tactic")
	_check(view.scorecard_value.text.contains(advice), "a missed tactic is answered with how to spot it")
	_check(view.scorecard_value.text.contains(TacticNotebook.spot_it("impossible_scan")),
		"...for each one listed")
	await _close(view)

	# Missing everything must not put a wall of advice on the screen the lists
	# were just trimmed off.
	_seed_reads(0, 5, [["Manufactured urgency", "manufactured_urgency"],
		["The impossible scan", "impossible_scan"],
		["Paying to receive", "advance_fee"],
		["The reused victim list", "reused_victim_list"],
		["Impersonating a trusted authority", "authority_impersonation"]])
	view = await _open("partial_justice")
	_check(SessionState.get_missed_tactic_entries().size() == 5, "all five misses are on record")
	_check(view.scorecard_value.text.contains(TacticNotebook.spot_it("advance_fee")),
		"the third miss is still answered")
	_check(not view.scorecard_value.text.contains(TacticNotebook.spot_it("reused_victim_list")),
		"the fourth is not - the advice is capped")
	_check(view.scorecard_value.text.contains("and 2 more"),
		"...and the rest are pointed at (%s)" % view.scorecard_value.text.right(60))
	await _close(view)


func _test_untested_and_midcase() -> void:
	print("\n[no verdict where one would be premature]")
	SessionState.reset_session()
	var view := await _open("full_takedown")
	_check(not view.outcome_note.text.contains("name every lever"),
		"a session that never reached a quiz gets no verdict")
	await _close(view)

	# Mid-case interview summaries are not endings.
	_seed_reads(4, 4, [])
	var mid := await _open("success")
	_check(not mid.outcome_note.text.contains("name every lever"),
		"a mid-case summary carries no closing verdict")
	await _close(mid)


# The record on disk: which of the five this copy of the game has shown. It
# is written by the screen, read by the menu, and is not a save.
func _test_ending_record() -> void:
	print("\n[the ending record]")
	SessionState.clear_ending_record()
	SessionState.reset_session()
	_check(SessionState.endings_reached().is_empty(), "a cleared record is empty")
	_check(not FileAccess.file_exists(SCRATCH_RECORD), "...and there is no file")

	# The table itself: five endings, each titled, each steered, each with a
	# verdict for every reader.
	var view := await _open("success")
	_check(SessionState.ENDINGS.size() == 5, "five endings are on the table")
	for entry in SessionState.ENDINGS:
		var id := str(entry.get("id", ""))
		_check(not str(entry.get("title", "")).is_empty(), "%s has a title" % id)
		_check(not str(entry.get("steer", "")).is_empty(), "%s has a steer" % id)
		_check(view.AWARENESS_VERDICTS.has(id), "%s has awareness verdicts" % id)
		_check(view.OUTCOME_MESSAGES.has(id), "%s has an outcome message" % id)
		for tier in ["sharp", "mixed", "blind"]:
			_check(view.AWARENESS_VERDICTS.get(id, {}).has(tier), "%s has a %s verdict" % [id, tier])
	for id in view.AWARENESS_VERDICTS.keys():
		_check(SessionState.is_final_outcome(str(id)), "every verdict belongs to an ending on the table (%s)" % id)
	_check(SessionState.is_final_outcome("bribed"), "a closing outcome is final")
	_check(not SessionState.is_final_outcome("success"), "a mid-case outcome is not")
	_check(SessionState.ending_title("building_stands") == "The Building Stands", "the title reads off the table")
	_check(SessionState.endings_reached().is_empty(), "a mid-case summary is not recorded")
	await _close(view)

	view = await _open("partial_justice")
	_check(SessionState.endings_reached() == ["partial_justice"],
		"a closing screen records its ending (%s)" % str(SessionState.endings_reached()))
	_check(FileAccess.file_exists(SCRATCH_RECORD), "...on disk")
	_check(view.outcome_label.text == "Case Closed: Partial Justice", "the closing title reads off the table (%s)" % view.outcome_label.text)
	_check(view.outcome_note.text.contains("Endings on record: 1 of 5"), "the screen counts the record")
	await _close(view)

	view = await _open("partial_justice")
	_check(SessionState.endings_reached().size() == 1, "reaching the same ending twice records it once")
	await _close(view)

	view = await _open("bribed")
	_check(SessionState.endings_reached() == ["partial_justice", "bribed"],
		"the record lists endings in the table's order, not the order reached")
	_check(view.outcome_note.text.contains("Endings on record: 2 of 5"), "the count follows")
	await _close(view)

	# It really is the file: a fresh reader sees the same two.
	var config := ConfigFile.new()
	_check(config.load(SCRATCH_RECORD) == OK, "the record loads as a config file")
	_check(bool(config.get_value("endings", "bribed", false)), "...with the ending in it")
	_check(not bool(config.get_value("endings", "full_takedown", false)), "...and not the ones unreached")

	# Nothing on the record is progress.
	var keys: Array = config.get_section_keys("endings") if config.has_section("endings") else []
	for key in keys:
		_check(SessionState.is_final_outcome(str(key)), "the record holds ending ids and nothing else (%s)" % key)

	_check(SessionState.has_reached_ending("bribed"), "has_reached_ending reads the record")
	_check(not SessionState.has_reached_ending("full_takedown"), "...and says no for the rest")
	SessionState.record_ending("success")
	_check(SessionState.endings_reached().size() == 2, "recording a mid-case outcome by hand does nothing")

	# A new game does not touch it.
	SessionState.reset_session()
	_check(SessionState.endings_reached().size() == 2, "the record survives a fresh game")

	SessionState.clear_ending_record()
	_check(SessionState.endings_reached().is_empty(), "clearing empties it")
	_check(not FileAccess.file_exists(SCRATCH_RECORD), "...by deleting the file, so cleared and fresh are the same")
	SessionState.clear_ending_record()
	_check(true, "clearing an empty record is harmless")


# The snapshots a closing screen can go back to: one per suspect's door, the
# whole detective half and none of the prologue.
func _test_checkpoints() -> void:
	print("\n[checkpoints]")
	SessionState.reset_session()

	# Every field on SessionState is either investigation state (restored) or
	# prologue/meta state (left alone). Nothing is allowed to be neither.
	for property in SessionState.get_script().get_script_property_list():
		var name := str(property.get("name", ""))
		if name.is_empty() or name.ends_with(".gd"):
			continue
		var classified: bool = SessionState.INVESTIGATION_STATE.has(name) or PROLOGUE_AND_META_STATE.has(name)
		_check(classified, "SessionState.%s is classified as investigation or prologue state" % name)
	for name in SessionState.INVESTIGATION_STATE:
		_check(not PROLOGUE_AND_META_STATE.has(name), "%s is not listed on both sides" % name)

	# A run with a prologue behind it, two witnesses in, at Marco's door.
	# (reset_session() leaves the milestones to reset_prologue(), so an earlier
	# test's are still here.)
	SessionState.reset_prologue()
	SessionState.prologue_played = true
	SessionState.record_prologue_call("maria_santos", "Maria S.", SessionState.CALL_SUCCESS, 18500, "I paid.")
	SessionState.detective_credibility = 86
	SessionState.statements_taken = 2
	SessionState.add_evidence({"id": "test_evelyn", "label": "Evelyn's testimony", "tactic": "Advance fee"})
	SessionState.add_evidence({"id": "test_maria", "label": "Maria's testimony", "tactic": "Manufactured urgency"})
	SessionState.record_interview_outcome("evelyn_marsh", "success")
	SessionState.record_tactic_read(true, "Manufactured urgency")
	SessionState.record_reflection_milestone("Two statements", "A case with legs.")
	SessionState.urban_return_scene = "res://scenes/exploration/urban_exterior.tscn"
	SessionState.urban_return_spawn = Vector2(100, 200)
	SessionState.has_urban_return_spawn = true
	SessionState.push_checkpoint("marco_navarro", "Before Marco Navarro")
	_check(SessionState.checkpoints.size() == 1, "a suspect's door pushes a checkpoint")
	_check(str(SessionState.checkpoints[0]["label"]) == "Before Marco Navarro", "...labelled")

	# The case moves on: Marco flips, Dennis names the owner, a third statement.
	SessionState.suspect_flipped = true
	SessionState.record_interview_outcome("marco_navarro", "whistleblower")
	SessionState.add_evidence({"id": SessionState.OWNER_NAME_EVIDENCE, "label": "The Name Above The Floors"})
	SessionState.statements_taken = 3
	SessionState.record_tactic_read(false, "The impossible scan")
	SessionState.record_reflection_milestone("Owner Named", "A name on the leases.")
	SessionState.urban_return_scene = "res://scenes/exploration/terminal_road.tscn"
	SessionState.push_checkpoint("dennis_mercado", "Before Dennis Mercado")
	SessionState.push_checkpoint("elena_cruz", "Before Elena Cruz")
	_check(SessionState.checkpoints.size() == 3, "each suspect's door is its own checkpoint")

	# Re-entering a door replaces its checkpoint and moves it to the end.
	SessionState.push_checkpoint("marco_navarro", "Before Marco Navarro")
	_check(SessionState.checkpoints.size() == 3, "re-entering a suspect does not pile up checkpoints")
	_check(str(SessionState.checkpoints[2]["person_id"]) == "marco_navarro", "...the latest visit is the one kept, at the end")
	_check(bool(SessionState.checkpoints[2]["state"]["suspect_flipped"]), "...with the case as it is now")
	_check(str(SessionState.checkpoints[0]["person_id"]) == "dennis_mercado", "...and the others keep their order")
	SessionState.push_checkpoint("", "nobody")
	_check(SessionState.checkpoints.size() == 3, "a door with no person_id pushes nothing")

	# The snapshot is a copy, not a reference.
	var dennis_state: Dictionary = SessionState.checkpoints[0]["state"]
	var held_then: int = (dennis_state["investigation_inventory"] as Array).size()
	SessionState.add_evidence({"id": "test_later", "label": "Something found later"})
	_check((dennis_state["investigation_inventory"] as Array).size() == held_then, "the snapshot does not change when the case does")

	# Going back: the state before Dennis, the prologue untouched.
	SessionState.restore_investigation(dennis_state)
	# 86, +15 for the whistleblower (clamped at 100), -3 for the missed quiz.
	_check(SessionState.detective_credibility == 97, "credibility is restored (got %d)" % SessionState.detective_credibility)
	_check(SessionState.statements_taken == 3, "statements are restored")
	_check(SessionState.has_evidence(SessionState.OWNER_NAME_EVIDENCE), "the evidence held then is held again")
	_check(not SessionState.has_evidence("test_later"), "...and what came after is gone")
	_check(SessionState.suspect_flipped, "flags are restored")
	_check(SessionState.tactic_reads_total == 2, "the quiz record is restored")
	_check(SessionState.reflection_milestones.size() == 2, "milestones are restored")
	_check(SessionState.urban_return_scene.ends_with("terminal_road.tscn"), "the return street is the door's")
	_check(SessionState.prologue_played, "the prologue is still played")
	_check(SessionState.prologue_call_log.size() == 1, "the call log is untouched")
	_check(SessionState.checkpoints.size() == 3, "restoring does not drop the checkpoints")

	# A second reopen of the same checkpoint starts from the same place.
	SessionState.add_evidence({"id": "test_again", "label": "Found again"})
	SessionState.restore_investigation(dennis_state)
	_check(not SessionState.has_evidence("test_again"), "a checkpoint can be reopened more than once")

	# The earliest one: before Marco, as first entered.
	var marco_state: Dictionary = SessionState.checkpoints[2]["state"]
	_check(bool(marco_state["suspect_flipped"]), "(the replaced Marco checkpoint is the later visit)")
	SessionState.restore_investigation({"detective_credibility": 86, "suspect_flipped": false, "statements_taken": 2})
	_check(SessionState.detective_credibility == 86 and not SessionState.suspect_flipped, "a partial state restores only what it names")
	_check(SessionState.has_evidence(SessionState.OWNER_NAME_EVIDENCE), "...and leaves the rest")

	# Typed arrays survive the round trip.
	_check(SessionState.interviewed_people.is_typed() and SessionState.interviewed_people.get_typed_builtin() == TYPE_STRING,
		"interviewed_people is still typed after a restore")
	SessionState.interviewed_people.append("kevin_dizon")
	_check(SessionState.interviewed_people.has("kevin_dizon"), "...and still usable")

	# A fresh investigation forgets them; Main Menu goes through reset_session.
	SessionState.reset_investigation()
	_check(SessionState.checkpoints.is_empty(), "a fresh investigation has no checkpoints")
	_check(SessionState.prologue_call_log.size() == 1, "(reset_investigation still keeps the call log)")
	SessionState.reset_session()
	_check(SessionState.checkpoints.is_empty(), "a fresh game has none either")


# The closing screen offers the checkpoints; a mid-case summary does not.
func _test_reopen_from_the_ending() -> void:
	print("\n[reopening from the ending]")
	_seed_reads(4, 4, [])
	var view := await _open("full_takedown")
	_check(not view.reopen_button.visible, "with no checkpoints there is nothing to reopen")
	await _close(view)

	_seed_reads(4, 4, [])
	SessionState.statements_taken = 2
	SessionState.detective_credibility = 68
	SessionState.add_evidence({"id": "test_evelyn", "label": "Evelyn's testimony"})
	SessionState.push_checkpoint("marco_navarro", "Before Marco Navarro")
	SessionState.suspect_flipped = true
	SessionState.push_checkpoint("elena_cruz", "Before Elena Cruz")

	view = await _open("success")
	_check(not view.reopen_button.visible, "a mid-case summary does not offer to reopen")
	_check(view.continue_button.visible, "...it has the street for that")
	await _close(view)

	view = await _open("full_takedown")
	_check(view.reopen_button.visible, "a closing screen with checkpoints offers to reopen")
	_check(not view.continue_button.visible, "...and still hides the street")
	_check(view.button_row.visible and not view.reopen_box.visible, "the chooser starts closed")

	view._on_reopen_pressed()
	_check(view.reopen_box.visible and not view.button_row.visible, "opening the chooser takes the button row's place")
	_check(view.reopen_list.get_child_count() == 2, "one button per checkpoint (got %d)" % view.reopen_list.get_child_count())
	var first: Button = view.reopen_list.get_child(0)
	_check(first.text.begins_with("Before Marco Navarro"), "the door is named (%s)" % first.text.get_slice("\n", 0))
	_check(first.text.contains("Statements 2 of 6"), "...with the statements spent then")
	_check(first.text.contains("Credibility 68"), "...the standing then")
	_check(first.text.contains("1 on file"), "...and what was on file")
	_check(view.reopen_list.get_child(1).text.begins_with("Before Elena Cruz"), "oldest first")

	view._show_button_row()
	_check(view.button_row.visible and not view.reopen_box.visible, "Back closes the chooser")
	view._on_reopen_pressed()
	_check(view.reopen_list.get_child_count() == 2, "opening it again does not double the list")
	await _close(view)

	# Reopening restores the state; the scene change is the street's business.
	SessionState.add_evidence({"id": "test_after", "label": "After the ending"})
	SessionState.restore_investigation(SessionState.checkpoints[0]["state"])
	_check(not SessionState.suspect_flipped, "reopening before Marco un-flips him")
	_check(not SessionState.has_evidence("test_after"), "...and drops what came after")
	_check(SessionState.checkpoints.size() == 2, "...keeping the checkpoints for another go")
	SessionState.reopen_case(7)
	_check(SessionState.checkpoints.size() == 2, "an index off the list does nothing")
	SessionState.reset_session()
