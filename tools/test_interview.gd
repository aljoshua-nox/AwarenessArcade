extends Node

## Headless smoke test for the interview engine.
##
##   godot --headless --path . res://tools/test_interview.tscn
##
## Exits 0 if every check passes, 1 otherwise. This exists because a broken
## dialogue branch or a silently-disabled effect otherwise only shows up
## halfway through a manual playtest.

const INTERVIEW_SCENE := "res://scenes/investigation/interview.tscn"
const CASE_MARIA := "res://resources/cases/interview_case_001.json"
const CASE_KEVIN := "res://resources/cases/interview_case_002.json"
const CASE_MARCO := "res://resources/cases/interview_case_003.json"

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


## Credibility that clears every witness gate (highest is Lina at 70). Tests
## that are about the engine rather than the gates open with this; the gates
## have their own tests further down.
const GATE_CLEAR := 75


func _open(case_path: String) -> Node:
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.pending_case_path = case_path
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


# Same as _open(), but with a prologue behind it. reset_session() wipes the
# call log, so the history has to be seeded after it and before the scene
# instantiates - the interview reads its disposition in _ready().
func _open_after_prologue(case_path: String, person_id: String, victim_name: String,
		outcome: String, credibility: int = GATE_CLEAR, consequence: String = "") -> Node:
	SessionState.reset_session()
	SessionState.prologue_played = true
	SessionState.detective_credibility = credibility
	if not person_id.is_empty():
		SessionState.record_prologue_call(person_id, victim_name, outcome, 0, consequence)
	SessionState.pending_case_path = case_path
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _run() -> void:
	print("\n--- interview engine smoke test ---")

	await _test_opening_state()
	await _test_typewriter()
	await _test_choice_costs()
	await _test_quiz()
	await _test_evidence()
	await _test_failure_route()
	await _test_antifarming()
	await _test_text_voices()
	await _test_prologue_coupling()
	await _test_contradiction()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	# Let deferred frees and finished tweens settle, otherwise Godot reports
	# leaked objects at exit and muddies the result.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures.size() > 0 else 0)


# The prologue-to-investigation coupling: what the player did as the scammer
# decides how far open the door is when they arrive as the detective.
func _test_prologue_coupling() -> void:
	print("
[the prologue shapes the interview]")

	# Neutral is the untouched case. A skip-the-prologue run must play exactly
	# as the case was written, with no content missing.
	var view := await _open(CASE_MARIA)
	_check(view.disposition == SessionState.DISPOSITION_NEUTRAL, "no prologue history reads as neutral")
	_check(view.cooperation == 50, "a neutral victim opens at the default 50 (got %d)" % view.cooperation)
	_check(view.prompt_value.text.contains("already told the bank"), "a neutral victim keeps the original opening")
	_check(not view.prompt_value.text.contains("HARM ON RECORD"), "no harm marker without prologue history")
	await _close(view)

	# Robbed: withdrawn and harder to reach, and the player is told why.
	view = await _open_after_prologue(CASE_MARIA, "maria_santos", "Maria S.", SessionState.CALL_SUCCESS)
	_check(view.disposition == SessionState.DISPOSITION_HARMED, "a victim you took money from reads as harmed")
	_check(view.cooperation == 34, "a harmed victim opens below neutral (got %d)" % view.cooperation)
	_check(view.prompt_value.text.contains("folded and unfolded"), "a harmed victim gets her own opening beat")
	_check(view.prompt_value.text.contains("HARM ON RECORD"), "the player is told this is their own doing")
	await _close(view)

	# The harm is quoted back at the call that caused it. The case note is
	# written before anyone plays; this line is what the player actually did.
	const HER_WORDS := "I thought I was protecting my account, but the transfer took my savings instead."
	view = await _open_after_prologue(CASE_MARIA, "maria_santos", "Maria S.",
		SessionState.CALL_SUCCESS, GATE_CLEAR, HER_WORDS)
	_check(view.prompt_value.text.contains(HER_WORDS),
		"the victim's own words about that call are quoted back in the opening")
	_check(view.prompt_value.text.contains("Recorded after your call"),
		"the quote is attributed to the call the player made")
	_check(view.prompt_value.text.contains("folded and unfolded"),
		"quoting the record does not replace the authored opening")
	_check(view.prompt_value.text.contains("shame is quiet"),
		"the authored case note survives alongside the quote")
	await _close(view)

	# A record with no consequence on it must not leave the marker dangling.
	view = await _open_after_prologue(CASE_MARIA, "maria_santos", "Maria S.", SessionState.CALL_SUCCESS)
	_check(not view.prompt_value.text.contains("Recorded after your call"),
		"no quote is claimed when the call recorded none")
	await _close(view)

	# Someone else's words must never turn up in this victim's mouth.
	view = await _open_after_prologue(CASE_MARIA, "kevin_d", "Kevin Dizon",
		SessionState.CALL_SUCCESS, GATE_CLEAR, "I let remote access in because the warning looked real.")
	_check(not view.prompt_value.text.contains("remote access"),
		"a consequence recorded against someone else stays out of Maria's opening")
	await _close(view)

	# Refused: unharmed, angry, willing. The trade, not a difficulty tax.
	view = await _open_after_prologue(CASE_MARIA, "maria_santos", "Maria S.", SessionState.CALL_REFUSED)
	_check(view.disposition == SessionState.DISPOSITION_RESISTANT, "a victim who refused reads as resistant")
	_check(view.cooperation == 62, "a resistant victim opens above neutral (got %d)" % view.cooperation)
	_check(view.prompt_value.text.contains("Somebody official"), "a resistant victim gets her own opening beat")
	await _close(view)

	view = await _open_after_prologue(CASE_MARIA, "maria_santos", "Maria S.", SessionState.CALL_TIMEOUT)
	_check(view.cooperation == 44, "an unfinished call lands between the two (got %d)" % view.cooperation)
	await _close(view)

	# Harm is per person, not global: robbing Kevin must not change Maria.
	view = await _open_after_prologue(CASE_MARIA, "kevin_d", "Kevin Dizon", SessionState.CALL_SUCCESS)
	_check(view.cooperation == 50, "robbing someone else leaves Maria neutral (got %d)" % view.cooperation)
	await _close(view)

	# Kevin above his credibility gate gets his own harmed opening.
	view = await _open_after_prologue(CASE_KEVIN, "kevin_d", "Kevin Dizon", SessionState.CALL_SUCCESS, 70)
	_check(view.cooperation == 34, "Kevin opens harmed as well (got %d)" % view.cooperation)
	_check(view.prompt_value.text.contains("flat on the lid"), "Kevin gets his own harmed opening beat")
	await _close(view)

	# Below it, the two gates compose: the hesitant branch keeps its own words
	# but still carries the cooperation cost of what was done to him.
	view = await _open_after_prologue(CASE_KEVIN, "kevin_d", "Kevin Dizon", SessionState.CALL_SUCCESS, 40)
	_check(view.prompt_value.text.contains("feel dumb enough"), "the hesitant branch keeps its own opening")
	_check(not view.prompt_value.text.contains("flat on the lid"), "a disposition opening never overrides the hesitant branch")
	_check(view.cooperation == 34, "the hesitant branch still carries the harmed cooperation (got %d)" % view.cooperation)
	await _close(view)


# Presenting corroboration teaches "keep your records". Catching a lie teaches
# the sharper thing: a rehearsed story survives being doubted, but not being
# checked against something written down at the time.
func _test_contradiction() -> void:
	print("
[catching the suspect in a contradiction]")
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	# Kevin's remote-access log, carried over from his interview.
	SessionState.add_evidence({
		"id": "ev_remote_access_log",
		"tactic_id": "remote_access",
		"label": "Remote Access Log",
		"description": "A session opened on the victim's machine.",
		"tactic": "Posing as technical support to gain direct access to a victim's device.",
	})
	SessionState.pending_case_path = CASE_MARCO
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame

	view._load_node("deny_node")
	_check(view.prompt_value.text.contains("CLAIM ON RECORD"),
		"the suspect's alibi is pinned where the player can aim at it")
	_check(view.prompt_value.text.contains("seven till two"), "the claim is specific enough to be checkable")
	_check(view.present_evidence_button.visible, "the existing evidence UI is what challenges it")

	var log_index := _index_of(view, "ev_remote_access_log")
	_check(log_index >= 0, "the log is available to present")
	var before: int = view.cooperation
	view._on_evidence_chosen(log_index)

	_check(view.prompt_value.text.contains("CONTRADICTION"),
		"catching the lie reads differently from corroborating a story")
	_check(view.prompt_value.text.contains("23:04"), "the contradiction names the fact that breaks it")
	_check(view.cooperation > before, "breaking his account moves him (%d -> %d)" % [before, view.cooperation])
	_check(view.evidence_misses == 0, "a contradiction is not scored as a misread")
	_check(view.current_node_id == "caught_shift", "it routes to its own beat (%s)" % view.current_node_id)

	# The route has to rejoin the interview, not dead-end.
	view._on_choice_pressed(0)
	_check(view.current_node_id == "half_crack", "the contradiction leaves him half-cracked, like a testimony would")
	await _close(view)

	# Without the log, the claim simply stands.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.pending_case_path = CASE_MARCO
	var bare: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(bare)
	await get_tree().process_frame
	bare._load_node("deny_node")
	_check(bare.prompt_value.text.contains("CLAIM ON RECORD"), "the claim is still made")
	# _index_of() records a failure when an item is missing, which is the point here.
	_check(not SessionState.has_evidence("ev_remote_access_log"), "but nothing in hand disproves it")
	await _close(bare)


func _test_opening_state() -> void:
	print("\n[opening state]")
	var view := await _open(CASE_MARIA)
	_check(view.cooperation == 50, "cooperation starts at 50")
	_check(not view.prompt_value.text.is_empty(), "opening prompt is populated")
	var visible_buttons := 0
	for b in view.choice_buttons:
		if b.visible:
			visible_buttons += 1
	_check(visible_buttons == 3, "Maria's intro offers 3 real choices (got %d)" % visible_buttons)
	_check(not view.interview_over, "interview is not already over")
	await _close(view)


func _test_typewriter() -> void:
	print("\n[typewriter]")
	var view := await _open(CASE_MARIA)
	# The exact risk flagged in review: if the label hasn't parsed its BBCode
	# yet, the character count is 0 and the effect silently disables itself.
	var count: int = view.prompt_value.get_total_character_count()
	_check(count > 0, "character count is available on the first prompt (got %d)" % count)
	_check(view.prompt_value.visible_ratio < 1.0, "first prompt starts hidden and types in (ratio %.2f)" % view.prompt_value.visible_ratio)
	_check(view._is_typing(), "typewriter tween is running")
	view._finish_typing()
	_check(view.prompt_value.visible_ratio == 1.0, "skip reveals the full prompt")
	await _close(view)


func _test_choice_costs() -> void:
	print("\n[choice costs]")
	var view := await _open(CASE_MARIA)
	view._on_choice_pressed(2)  # "you're one of several people I have to see today"
	_check(view.cooperation == 36, "hostile opener costs 14 cooperation (got %d)" % view.cooperation)
	_check(view.current_node_id == "rush_her", "hostile opener routes to rush_her")
	view._on_choice_pressed(0)  # apologise
	_check(view.cooperation > 36, "apologising recovers cooperation (got %d)" % view.cooperation)
	await _close(view)


func _test_quiz() -> void:
	print("\n[tactic quiz]")
	var view := await _open(CASE_MARIA)
	view._on_choice_pressed(1)  # straight to the account of the call
	view._on_choice_pressed(0)  # "say that back to me slowly" -> quiz
	_check(view.quiz_active, "quiz activates on the quiz node")
	var options := 0
	for b in view.choice_buttons:
		if b.visible:
			options += 1
	_check(options == 4, "quiz shows all 4 options (got %d)" % options)

	var before: int = view.cooperation
	view._on_choice_pressed(1)  # a wrong answer
	_check(not view.quiz_active, "quiz closes after answering")
	_check(view.cooperation < before, "wrong answer costs cooperation")
	_check(SessionState.tactic_reads_total == 1, "wrong answer still counts as a tactic read")
	_check(SessionState.tactic_reads_correct == 0, "wrong answer is not scored correct")
	_check(view.prompt_value.text.contains("not the manipulation"), "wrong answer explains why it is wrong")
	_check(view.current_node_id == "ask_evidence", "quiz advances even when answered wrong")
	await _close(view)

	# ...and the correct answer scores.
	view = await _open(CASE_MARIA)
	view._on_choice_pressed(1)
	view._on_choice_pressed(0)
	view._on_choice_pressed(0)  # correct
	_check(SessionState.tactic_reads_correct == 1, "correct answer is scored")
	_check(SessionState.reflection_milestones.size() > 0, "correct answer records a milestone")
	await _close(view)


func _test_evidence() -> void:
	print("\n[evidence]")
	var view := await _open(CASE_MARIA)
	view._on_choice_pressed(1)
	view._on_choice_pressed(0)
	view._on_choice_pressed(0)  # through the quiz to ask_evidence
	_check(view.present_evidence_button.visible, "Present Evidence is offered")

	var decoy := _index_of(view, "ev_internet_note")
	var before: int = view.cooperation
	view._on_evidence_chosen(decoy)
	_check(view.cooperation < before, "the decoy costs cooperation")
	_check(view.evidence_misses == 1, "the decoy counts as a miss")

	var repeat_before: int = view.cooperation
	view._on_evidence_chosen(decoy)
	_check(view.cooperation == repeat_before, "re-presenting the decoy does not double-charge")

	var key := _index_of(view, "ev_phishing_text")
	view._on_evidence_chosen(key)
	_check(view.current_node_id == "confirm_phishing", "the key evidence advances the interview")
	view._on_choice_pressed(0)
	_check(view.interview_over, "interview ends after confirming")
	_check(SessionState.investigation_outcome == "success", "outcome is success")
	_check(SessionState.has_evidence("test_maria_confirmed"), "testimony is granted for later interviews")
	await _close(view)


func _test_failure_route() -> void:
	print("\n[failure route]")
	var view := await _open(CASE_MARIA)
	view.cooperation = 6
	view._on_choice_pressed(2)  # -14, drives cooperation to 0
	_check(view.interview_over, "cooperation hitting 0 ends the interview")
	_check(view.current_node_id == "end_shutdown", "it routes to the case's own failure node")
	_check(SessionState.investigation_outcome == "failure", "outcome is failure")
	_check(SessionState.detective_credibility == GATE_CLEAR - 10, "failure costs 10 credibility (got %d)" % SessionState.detective_credibility)
	await _close(view)


func _test_antifarming() -> void:
	print("\n[anti-farming + credibility gate]")
	var view := await _open(CASE_MARIA)
	view._on_choice_pressed(0)  # ask_wellbeing, +8 on first visit
	var after_first: int = view.cooperation
	view._on_choice_pressed(0)  # on to ask_call
	view._on_choice_pressed(0)  # into the quiz
	view._on_choice_pressed(0)  # correct, on to ask_evidence
	view._on_choice_pressed(0)  # press_details
	view._on_choice_pressed(0)  # back to ask_evidence - revisit, no re-award
	_check(view.cooperation > after_first, "progress still earns cooperation")
	var revisit: int = view.cooperation
	view._load_node("ask_wellbeing")
	_check(view.cooperation == revisit, "revisiting a node does not re-apply its bonus")
	await _close(view)

	# Kevin is gated at 60. _open() now arrives with standing, so drop below the
	# gate deliberately to exercise the hesitant branch.
	SessionState.reset_session()
	SessionState.detective_credibility = 50
	SessionState.pending_case_path = CASE_KEVIN
	view = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	_check(view.current_node_id == "hesitant_intro", "Kevin is hesitant below 60 credibility")
	await _close(view)

	SessionState.reset_session()
	SessionState.detective_credibility = 70
	SessionState.pending_case_path = CASE_KEVIN
	var open_view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(open_view)
	await get_tree().process_frame
	_check(open_view.current_node_id == "intro", "Kevin opens up above 60 credibility")
	await _close(open_view)


func _test_text_voices() -> void:
	print("\n[text voices]")
	_check(load("res://assets/fonts/IBM_Plex_Mono/IBMPlexMono-Medium.ttf") != null, "system mono font resource loads")

	var view := await _open(CASE_MARIA)
	var intro: String = view.prompt_value.text
	_check(intro.contains("[color=#a7b0bb]"), "narration is dimmed")
	_check(intro.contains("[color=#f7f0e2]\"I already told the bank"), "quoted speech is brightened")
	_check(not intro.contains("[font="), "plain dialogue carries no system font")

	# Reach the evidence step, which renders a CASE NOTE hint.
	view._on_choice_pressed(1)
	view._on_choice_pressed(0)
	var quiz_text: String = view.prompt_value.text
	_check(quiz_text.contains("IBMPlexMono"), "the quiz question uses the system font")
	_check(quiz_text.contains("CASE NOTE"), "the quiz question is marked as a system line")

	view._on_choice_pressed(1)  # wrong answer
	var wrong_text: String = view.prompt_value.text
	_check(wrong_text.contains("MISREAD"), "a wrong read is marked MISREAD")
	_check(wrong_text.contains("[color=#ff8368]"), "a wrong read is coloured as a miss")
	_check(wrong_text.contains("[color=#a7b0bb]"), "the following dialogue keeps its own voice")
	_check(view.present_evidence_button.visible, "evidence step reached")
	_check(wrong_text.contains("CASE NOTE"), "the evidence hint renders as a case note")
	await _close(view)

	view = await _open(CASE_MARIA)
	view._on_choice_pressed(1)
	view._on_choice_pressed(0)
	view._on_choice_pressed(0)  # correct answer
	var right_text: String = view.prompt_value.text
	_check(right_text.contains("TACTIC READ"), "a correct read is marked TACTIC READ")
	_check(right_text.contains("[color=#78d08b]"), "a correct read is coloured as a hit")

	# A successful evidence presentation appends the tactic in the system voice.
	view._on_evidence_chosen(_index_of(view, "ev_phishing_text"))
	var tactic_text: String = view.prompt_value.text
	_check(tactic_text.contains("TACTIC IDENTIFIED"), "successful evidence names the tactic")
	_check(tactic_text.contains("[color=#e8b454]"), "the tactic note uses the tactic colour")
	await _close(view)


func _index_of(view: Node, evidence_id: String) -> int:
	for i in range(SessionState.investigation_inventory.size()):
		if str(SessionState.investigation_inventory[i].get("id", "")) == evidence_id:
			return i
	failures.append("evidence '%s' not in inventory" % evidence_id)
	return -1
