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
const CASE_EVELYN := "res://resources/cases/interview_case_005.json"
const CASE_LINA := "res://resources/cases/interview_case_006.json"
const CASE_ELENA := "res://resources/cases/interview_case_004.json"
const CASE_TEDDY := "res://resources/cases/interview_case_007.json"
const CASE_TRISH := "res://resources/cases/interview_case_008.json"
const CASE_BEA := "res://resources/cases/interview_case_009.json"
const CASE_ROWENA := "res://resources/cases/interview_case_011.json"
const CASE_DENNIS := "res://resources/cases/interview_case_013.json"

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


## Credibility that clears every witness gate (highest is Teddy at 75). Tests
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
	await _test_evidence_scoping()
	await _test_disposition_variants()
	await _test_testimony_routing()
	await _test_witness_turned()
	await _test_fourth_floor_director()
	await _test_closer()
	await _test_statement_budget()
	await _test_setting_backgrounds()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	# Let deferred frees and finished tweens settle, otherwise Godot reports
	# leaked objects at exit and muddies the result.
	await get_tree().process_frame
	await get_tree().process_frame
	# A sound still in the mixer at quit is reported as a leak.
	await AudioManager.settle()
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
	_check(view.prompt_value.text.contains("seven to two"), "the claim is specific enough to be checkable")
	_check(view.present_evidence_button.visible, "the existing evidence UI is what challenges it")

	var log_index := _index_of(view, "ev_remote_access_log")
	_check(log_index >= 0, "the log is available to present")
	var before: int = view.cooperation
	view._present_evidence_index(log_index)

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

	# A click on the line's box reveals the rest, as the prologue's transcript
	# does. The box consumes the click itself, so the scene's _unhandled_input
	# never got it and the walkthrough's "click to skip" was only true off the box.
	view = await _open(CASE_MARIA)
	_check(view._is_typing(), "the next prompt is typing")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_check(view.prompt_value.gui_input.is_connected(view._on_prompt_gui_input), "the box listens for a click")
	_check(view.prompt_value.get_parent().gui_input.is_connected(view._on_prompt_gui_input), "and so does its panel")
	view._on_prompt_gui_input(click)
	_check(not view._is_typing() and view.prompt_value.visible_ratio == 1.0, "a click on the box reveals the whole line")
	view._on_prompt_gui_input(click)
	_check(view.prompt_value.visible_ratio == 1.0, "a second click on a finished line is harmless")
	# A clicked choice kept keyboard focus, which the theme draws like hover,
	# so the next node's button in that slot looked picked out - on a quiz,
	# like the answer. The choices take no focus.
	var focusless := true
	for button in view.choice_buttons:
		if (button as Button).focus_mode != Control.FOCUS_NONE:
			focusless = false
	_check(focusless, "choice buttons take no keyboard focus, so no slot stays lit into the next node")
	await _close(view)


func _test_choice_costs() -> void:
	print("\n[choice costs]")
	var view := await _open(CASE_MARIA)
	view._on_choice_pressed(2)  # "you're one of several people I have to see today"
	_check(view.cooperation == 36, "hostile opener costs 14 cooperation (got %d)" % view.cooperation)
	_check(view.current_node_id == "rush_her", "hostile opener routes to rush_her")
	view._on_choice_pressed(0)  # apologize
	_check(view.cooperation > 36, "apologizing recovers cooperation (got %d)" % view.cooperation)
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
	view._present_evidence_index(decoy)
	_check(view.cooperation < before, "the decoy costs cooperation")
	_check(view.evidence_misses == 1, "the decoy counts as a miss")

	var repeat_before: int = view.cooperation
	view._present_evidence_index(decoy)
	_check(view.cooperation == repeat_before, "re-presenting the decoy does not double-charge")

	var key := _index_of(view, "ev_phishing_text")
	view._present_evidence_index(key)
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
	_check(wrong_text.contains("[color=#ff8368]"), "a wrong read is colored as a miss")
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
	_check(right_text.contains("[color=#78d08b]"), "a correct read is colored as a hit")

	# A successful evidence presentation appends the tactic in the system voice.
	view._present_evidence_index(_index_of(view, "ev_phishing_text"))
	var tactic_text: String = view.prompt_value.text
	_check(tactic_text.contains("TACTIC IDENTIFIED"), "successful evidence names the tactic")
	_check(tactic_text.contains("[color=#e8b454]"), "the tactic note uses the tactic color")
	await _close(view)


func _index_of(view: Node, evidence_id: String) -> int:
	for i in range(SessionState.investigation_inventory.size()):
		if str(SessionState.investigation_inventory[i].get("id", "")) == evidence_id:
			return i
	failures.append("evidence '%s' not in inventory" % evidence_id)
	return -1


# The list was the whole inventory, so by the interrogation it ran to 21 rows in
# a panel that shows four - and since every victim's evidence node only ever
# accepted that victim's own items, 14 of those rows were identical generic
# misses. It is scoped to what the case can actually respond to now.
#
# The consequence worth guarding: a row number is no longer an inventory index.
func _test_evidence_scoping() -> void:
	print("\n[the evidence list is scoped to the case]")

	# Another case's item, in the inventory BEFORE this case seeds its own, so
	# rows and inventory indices cannot accidentally agree.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.add_evidence({
		"id": "ev_popup_screenshot", "label": "Pop-up screenshot",
		"description": "Kevin's, not hers.", "tactic": "Manufactured fear",
		"tactic_id": "manufactured_fear",
	})
	SessionState.pending_case_path = CASE_MARIA
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame

	view._on_choice_pressed(1)
	view._on_choice_pressed(0)
	view._on_choice_pressed(0)  # through the quiz to ask_evidence
	view._on_present_evidence_pressed()

	_check(SessionState.investigation_inventory.size() == 6,
		"the inventory holds another case's item alongside Maria's five (%d)"
		% SessionState.investigation_inventory.size())
	_check(view.evidence_list.item_count == 5,
		"only Maria's own five are listed (%d)" % view.evidence_list.item_count)

	var listed: Array[String] = []
	for row in range(view.evidence_list.item_count):
		var index := int(view.evidence_list.get_item_metadata(row))
		listed.append(str(SessionState.investigation_inventory[index].get("id", "")))
	_check(not listed.has("ev_popup_screenshot"),
		"another victim's evidence is not offered to Maria")
	_check(listed.has("ev_internet_note"),
		"her own decoy is still listed - the careful-choice lesson survives scoping")

	# The guard. Row 0 is inventory 1 here, so a handler that treated the row as
	# an inventory index would present the pop-up screenshot and take a miss.
	_check(int(view.evidence_list.get_item_metadata(0)) != 0,
		"a row number and an inventory index genuinely disagree in this setup")
	var before: int = view.cooperation
	view._on_evidence_chosen(0)
	_check(view.cooperation > before,
		"presenting row 0 lands on that row's evidence, not the inventory's (%d -> %d)"
		% [before, view.cooperation])
	_check(view.evidence_misses == 0, "and it is not scored as a miss")
	await _close(view)

	# The suspect carries no evidence of his own, so his list is entirely what he
	# can be confronted with - the half of the rule that makes him work.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.add_evidence({"id": "ev_prize_notice", "label": "Prize notice",
		"description": "Evelyn's.", "tactic": "Paying to receive", "tactic_id": "advance_fee"})
	SessionState.add_evidence({"id": "ev_remote_access_log", "label": "Remote access log",
		"description": "Kevin's.", "tactic": "Handing over the controls", "tactic_id": "remote_access"})
	SessionState.add_evidence({"id": "test_maria_confirmed", "label": "Maria's statement",
		"description": "Confirmed.", "tactic": "", "tactic_id": ""})
	SessionState.pending_case_path = CASE_MARCO
	view = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	view._on_present_evidence_pressed()

	var marco_listed: Array[String] = []
	for row in range(view.evidence_list.item_count):
		var index := int(view.evidence_list.get_item_metadata(row))
		marco_listed.append(str(SessionState.investigation_inventory[index].get("id", "")))
	_check(marco_listed.has("test_maria_confirmed"), "testimony can be taken to the suspect")
	_check(marco_listed.has("ev_remote_access_log"),
		"so can the log his alibi has to survive")
	_check(not marco_listed.has("ev_prize_notice"),
		"an item no node of his names stays out of the list")
	await _close(view)

	# Marco is ungated, so a player can walk into the interrogation carrying
	# nothing at all. That has to read as a state, not a blank panel.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.pending_case_path = CASE_MARCO
	view = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	view._on_present_evidence_pressed()
	_check(view.evidence_list.item_count == 1, "an empty list still renders a row")
	_check(view.evidence_list.is_item_disabled(0), "and that row cannot be presented")
	var empty_before: int = view.cooperation
	view._on_evidence_chosen(0)
	_check(view.cooperation == empty_before, "the placeholder row costs nothing if activated")
	await _close(view)


# Only the opening used to vary with the prologue. Evelyn's case was written as
# a refusal, so a player who had taken her money was told, for the whole rest
# of the interview, that she had lost nothing - and Marco was told the same.
# Every node that states the premise now has a version for the other outcomes.
func _test_disposition_variants() -> void:
	print("
[the whole interview follows the prologue]")

	# Neutral is still the case exactly as written: refused, no receipt.
	var view := await _open(CASE_EVELYN)
	var lost_nothing := false
	for button in view.choice_buttons:
		if button.visible and button.text.contains("didn't lose any money"):
			lost_nothing = true
	_check(lost_nothing, "neutral Evelyn keeps the original choices")
	_check(_index_of_quiet(view, "ev_release_receipt") < 0, "neutral Evelyn has no payment to show")
	view._load_node("ask_evidence")
	_check(view.prompt_value.text.contains("hung up on me"), "neutral Evelyn refused, as written")
	await _close(view)

	# Robbed: the same nodes, the other story.
	view = await _open_after_prologue(CASE_EVELYN, "evelyn_marsh", "Evelyn Marsh", SessionState.CALL_SUCCESS)
	_check(view.disposition == SessionState.DISPOSITION_HARMED, "Evelyn reads as harmed")
	lost_nothing = false
	var bookkeeper := false
	for button in view.choice_buttons:
		if button.visible and button.text.contains("didn't lose any money"):
			lost_nothing = true
		if button.visible and button.text.contains("bookkeeper paying"):
			bookkeeper = true
	_check(not lost_nothing, "a harmed Evelyn is not told she lost nothing")
	_check(bookkeeper, "...the rude opening is rewritten for what actually happened")
	view._load_node("ask_evidence")
	_check(view.prompt_value.text.contains("I paid it anyway"), "the evidence beat says she paid")
	_check(view.prompt_value.text.contains("She paid, so there is a transaction"), "the hint follows the disposition")
	var receipt := _index_of(view, "ev_release_receipt")
	_check(receipt >= 0, "a harmed Evelyn has the payment to show")
	if receipt >= 0:
		view._present_evidence_index(receipt)
		_check(view.prompt_value.text.contains("balanced it that same evening"), "...and reacts to it in her own voice")
	var stub := _index_of(view, "ev_raffle_stub")
	view._load_node("ask_evidence")
	view._present_evidence_index(stub)
	_check(view.current_node_id == "confirm_list", "the list route still works when harmed")
	view._on_choice_pressed(0)
	_check(view.current_node_id == "end_success", "...and reaches the success ending")
	_check(view.prompt_value.text.contains("She paid"), "the ending says she paid")
	var testimony: Dictionary = {}
	for item in SessionState.investigation_inventory:
		if str(item.get("id", "")) == "test_evelyn_confirmed":
			testimony = item
	_check(str(testimony.get("description", "")).contains("paid it"), "the testimony carried forward says so too")
	_check(str(testimony.get("person_id", "")) == "evelyn_marsh", "testimony is stamped with the person it came from")
	await _close(view)

	# A Kevin who hung up has no remote session and no receipt - so no log for
	# the suspect's alibi to break - but he does have the callback.
	view = await _open_after_prologue(CASE_KEVIN, "kevin_d", "Kevin Dizon", SessionState.CALL_REFUSED, GATE_CLEAR)
	_check(_index_of_quiet(view, "ev_remote_access_log") < 0, "a resistant Kevin has no remote-access log")
	_check(_index_of_quiet(view, "ev_fee_receipt") < 0, "...and no fee receipt")
	var callback := _index_of(view, "ev_callback_log")
	_check(callback >= 0, "...but he has the callback log")
	view._load_node("ask_evidence")
	_check(view.prompt_value.text.contains("no session and no receipt"), "the hint tells the player what to look for instead")
	view._present_evidence_index(callback)
	_check(view.current_node_id == "confirm_access", "the callback is what secures him")
	_check(view.prompt_value.text.contains("called me back"), "...in words about the callback, not a session")
	_check(not view._presentable_ids().has("ev_remote_access_log"), "the log is not even in his presentable set")
	await _close(view)

	# The suspect reacts to WHOSE testimony it is and what happened to them.
	SessionState.reset_session()
	SessionState.prologue_played = true
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.record_prologue_call("evelyn_marsh", "Evelyn Marsh", SessionState.CALL_SUCCESS, 24500, "quoted")
	SessionState.add_evidence({"id": "test_evelyn_confirmed", "label": "Evelyn's Confirmed Testimony", "person_id": "evelyn_marsh"})
	SessionState.pending_case_path = CASE_MARCO
	var marco: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(marco)
	await get_tree().process_frame
	marco._load_node("deny_node")
	marco._present_evidence_index(_index_of(marco, "test_evelyn_confirmed"))
	_check(marco.prompt_value.text.contains("The bookkeeper paid"), "Marco reacts to a paid Evelyn as paid")
	_check(not marco.prompt_value.text.contains("didn't even pay"), "...and not with the line written for a refusal")
	await _close(marco)

	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.add_evidence({"id": "test_evelyn_confirmed", "label": "Evelyn's Confirmed Testimony", "person_id": "evelyn_marsh"})
	SessionState.pending_case_path = CASE_MARCO
	marco = load(INTERVIEW_SCENE).instantiate()
	add_child(marco)
	await get_tree().process_frame
	marco._load_node("deny_node")
	marco._present_evidence_index(_index_of(marco, "test_evelyn_confirmed"))
	_check(marco.prompt_value.text.contains("didn't even pay"), "with no prologue, Marco gets the line as written")
	await _close(marco)

	# A quiz keeps its options; only the framing changes for a call that never
	# reached the fee.
	view = await _open_after_prologue(CASE_LINA, "lina_reyes", "Lina Reyes", SessionState.CALL_TIMEOUT, GATE_CLEAR)
	_check(_index_of_quiet(view, "ev_transfer_receipts") < 0, "an unfinished Lina has no transfer receipts")
	_check(_index_of(view, "ev_quote_notes") >= 0, "...but she has the note she was writing")
	view._load_node("tactic_quiz_escalation")
	_check(view.prompt_value.text.contains("cut off before the fee"), "the quiz is reframed for a call that cut off")
	_check(view.choice_buttons[0].text.contains("each new fee looks small"), "...with the same options, because they are the lesson")
	await _close(view)


func _index_of_quiet(_view: Node, evidence_id: String) -> int:
	for i in range(SessionState.investigation_inventory.size()):
		if str(SessionState.investigation_inventory[i].get("id", "")) == evidence_id:
			return i
	return -1


# A suspect answers for the scripts his floor runs, not for a list of names. A
# testimony carries the script of the victim it came from; a row that accepts
# by script is the floor beneath the named rows; a check can ask for "any two
# from these scripts". This is what stops every new victim from needing a row
# in every suspect - and what makes bringing the right witness to the wrong
# floor a thing that cannot happen by accident.
func _test_testimony_routing() -> void:
	print("\n[testimony routes by script]")

	# Granting stamps the script, so the item knows which floor it implicates.
	var teddy := await _open(CASE_TEDDY)
	teddy._load_node("end_success")
	var granted := _index_of(teddy, "test_teddy_confirmed")
	_check(granted >= 0, "Teddy's confirmed testimony is granted")
	if granted >= 0:
		_check(str(SessionState.investigation_inventory[granted].get("script", "")) == "family_emergency",
			"...and carries the script that hit him (%s)" % SessionState.investigation_inventory[granted].get("script", ""))
	await _close(teddy)

	# A witness no row names by id still flips Marco, through the script row.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.add_evidence({"id": "test_teddy_confirmed", "label": "Teodoro's Confirmed Testimony",
		"person_id": "teodoro_villanueva", "script": "family_emergency"})
	SessionState.pending_case_path = CASE_MARCO
	var marco: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(marco)
	await get_tree().process_frame
	_check(marco._presentable_ids().has("test_teddy_confirmed"),
		"a script row lists a testimony no node of his names")
	marco._load_node("half_crack")
	var before: int = marco.cooperation
	marco._present_evidence_index(_index_of(marco, "test_teddy_confirmed"))
	_check(marco.current_node_id == "full_crack",
		"presenting it at half_crack flips him (landed on %s)" % marco.current_node_id)
	_check(marco.cooperation == before + 25, "...for the row's cooperation (%d -> %d)" % [before, marco.cooperation])
	_check(marco.evidence_misses == 0, "...and it is not a miss")
	await _close(marco)

	# A witness written after him - a script he answers for, an id he has never
	# seen - cracks him exactly like the ones he was written with.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.add_evidence({"id": "test_joel_confirmed", "label": "Joel's Confirmed Testimony",
		"person_id": "joel_abad", "script": "government"})
	SessionState.pending_case_path = CASE_MARCO
	marco = load(INTERVIEW_SCENE).instantiate()
	add_child(marco)
	await get_tree().process_frame
	marco._load_node("deny_node")
	before = marco.cooperation
	marco._present_evidence_index(_index_of(marco, "test_joel_confirmed"))
	_check(marco.current_node_id == "half_crack",
		"a testimony from a case that does not exist yet still cracks him (landed on %s)" % marco.current_node_id)
	_check(marco.cooperation == before + 20, "...for the script row's cooperation")
	_check(marco.prompt_value.text.contains("Maybe that one call"), "...with the generic line")
	await _close(marco)

	# A named row wins over the script row, so a written reaction survives.
	SessionState.reset_session()
	SessionState.prologue_played = true
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.record_prologue_call("evelyn_marsh", "Evelyn Marsh", SessionState.CALL_SUCCESS, 24500, "quoted")
	SessionState.add_evidence({"id": "test_evelyn_confirmed", "label": "Evelyn's Confirmed Testimony",
		"person_id": "evelyn_marsh", "script": "lottery"})
	SessionState.pending_case_path = CASE_MARCO
	marco = load(INTERVIEW_SCENE).instantiate()
	add_child(marco)
	await get_tree().process_frame
	marco._load_node("deny_node")
	marco._present_evidence_index(_index_of(marco, "test_evelyn_confirmed"))
	_check(marco.prompt_value.text.contains("The bookkeeper paid"),
		"a named row beats the script row - Evelyn still gets her own line")
	await _close(marco)

	# A testimony from a floor he does not answer for is not offered, and if
	# forced, is the ordinary unlisted-evidence miss - never a crack.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.add_evidence({"id": "test_trish_confirmed", "label": "Trish's Confirmed Testimony",
		"person_id": "patricia_lim", "script": "job_offer"})
	SessionState.pending_case_path = CASE_MARCO
	marco = load(INTERVIEW_SCENE).instantiate()
	add_child(marco)
	await get_tree().process_frame
	_check(not marco._presentable_ids().has("test_trish_confirmed"),
		"a testimony from the other floor is not in his list")
	marco._load_node("deny_node")
	before = marco.cooperation
	marco._present_evidence_index(_index_of(marco, "test_trish_confirmed"))
	_check(marco.current_node_id == "deny_node", "forcing it does not move him")
	_check(marco.evidence_misses == 1 and marco.cooperation < before, "...and costs the usual miss")
	await _close(marco)

	# The confrontation counts testimonies by script: any two from floor 3.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.suspect_flipped = true
	SessionState.add_evidence({"id": "test_teddy_confirmed", "label": "T", "person_id": "teodoro_villanueva", "script": "family_emergency"})
	SessionState.add_evidence({"id": "test_joel_confirmed", "label": "J", "person_id": "joel_abad", "script": "government"})
	SessionState.pending_case_path = CASE_ELENA
	var elena: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(elena)
	await get_tree().process_frame
	elena._load_node("final_check")
	_check(elena.current_node_id == "end_building_stands",
		"two floor-3 testimonies - neither written when she was - meet her check, and without the owner's name the building stands (landed on %s)" % elena.current_node_id)
	await _close(elena)

	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.suspect_flipped = true
	SessionState.add_evidence({"id": "test_teddy_confirmed", "label": "T", "person_id": "teodoro_villanueva", "script": "family_emergency"})
	SessionState.add_evidence({"id": "test_joel_confirmed", "label": "J", "person_id": "joel_abad", "script": "government"})
	SessionState.add_evidence({"id": "ev_owner_name", "label": "The Name Above The Floors", "description": "named"})
	SessionState.pending_case_path = CASE_ELENA
	elena = load(INTERVIEW_SCENE).instantiate()
	add_child(elena)
	await get_tree().process_frame
	elena._load_node("final_check")
	_check(elena.current_node_id == "end_full_takedown",
		"...and with the owner's name in the file the takedown reaches him (landed on %s)" % elena.current_node_id)
	_check(elena.prompt_value.text.contains(SessionState.COMPANY_NAME), "the takedown prints the one copy of the name")
	await _close(elena)

	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.suspect_flipped = true
	SessionState.add_evidence({"id": "test_teddy_confirmed", "label": "T", "person_id": "teodoro_villanueva", "script": "family_emergency"})
	SessionState.add_evidence({"id": "test_trish_confirmed", "label": "P", "person_id": "patricia_lim", "script": "job_offer"})
	SessionState.pending_case_path = CASE_ELENA
	elena = load(INTERVIEW_SCENE).instantiate()
	add_child(elena)
	await get_tree().process_frame
	elena._load_node("final_check")
	_check(elena.current_node_id == "end_partial_justice",
		"one floor-3 testimony and one from upstairs do not (landed on %s)" % elena.current_node_id)
	await _close(elena)


# The second floor's route in. Trish's testimony is what turns Bea, and Bea
# turning is what opens Rowena's door - the way Marco's flip opens Elena's.
func _test_witness_turned() -> void:
	print("\n[a witness who turns]")

	# Trish is ungated and her testimony carries the fourth floor's script.
	SessionState.reset_session()
	SessionState.detective_credibility = 50
	SessionState.pending_case_path = CASE_TRISH
	var trish: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(trish)
	await get_tree().process_frame
	_check(trish.current_node_id == "intro", "Trish talks to a detective with no standing (%s)" % trish.current_node_id)
	trish._load_node("end_success")
	var granted := _index_of(trish, "test_trish_confirmed")
	_check(granted >= 0 and str(SessionState.investigation_inventory[granted].get("script", "")) == "job_offer",
		"her testimony is tagged with the job-offer script")
	await _close(trish)

	# Trish is on the call list now, so her interview follows the call.
	var refused := await _open_after_prologue(CASE_TRISH, "patricia_lim", "Trish L.", SessionState.CALL_REFUSED, 50)
	_check(refused.disposition == SessionState.DISPOSITION_RESISTANT, "a Trish who refused reads as resistant")
	_check(refused.prompt_value.text.contains("ask Bea first"), "...and opens with the check that beat the script")
	_check(_index_of_quiet(refused, "ev_trish_fee_receipt") < 0, "...and has no receipt to show")
	_check(_index_of(refused, "ev_trish_bea_reply") >= 0, "...but has Bea's reply")
	await _close(refused)

	# Bea's reaction to Trish's testimony depends on which Trish it came from.
	SessionState.reset_session()
	SessionState.prologue_played = true
	SessionState.detective_credibility = 65
	SessionState.record_prologue_call("patricia_lim", "Trish L.", SessionState.CALL_REFUSED, 0, "quoted")
	SessionState.add_evidence({"id": "test_trish_confirmed", "label": "Trish's Confirmed Testimony",
		"person_id": "patricia_lim", "script": "job_offer"})
	SessionState.pending_case_path = CASE_BEA
	var bea_r: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(bea_r)
	await get_tree().process_frame
	bea_r._load_node("ask_evidence")
	bea_r._present_evidence_index(_index_of(bea_r, "test_trish_confirmed"))
	_check(bea_r.current_node_id == "turned", "a Trish who refused still turns Bea")
	_check(bea_r.prompt_value.text.contains("She asked me") and not bea_r.prompt_value.text.contains("She paid"),
		"...and Bea remembers being asked, not a payment")
	await _close(bea_r)

	# Bea is gated: a detective at the start cannot get past her door.
	SessionState.reset_session()
	SessionState.detective_credibility = 50
	SessionState.pending_case_path = CASE_BEA
	var bea: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(bea)
	await get_tree().process_frame
	_check(bea.current_node_id == "hesitant_intro", "Bea will not talk at the starting credibility (%s)" % bea.current_node_id)
	await _close(bea)

	# With standing and Trish's statement in hand, she turns.
	SessionState.reset_session()
	SessionState.detective_credibility = 65
	SessionState.add_evidence({"id": "test_trish_confirmed", "label": "Trish's Confirmed Testimony",
		"person_id": "patricia_lim", "script": "job_offer"})
	SessionState.pending_case_path = CASE_BEA
	bea = load(INTERVIEW_SCENE).instantiate()
	add_child(bea)
	await get_tree().process_frame
	_check(bea.current_node_id == "intro", "Bea opens the door at 65 (%s)" % bea.current_node_id)
	_check(bea._presentable_ids().has("test_trish_confirmed"), "Trish's statement is something Bea can be shown")
	bea._load_node("ask_evidence")
	var before: int = bea.cooperation
	bea._present_evidence_index(_index_of(bea, "test_trish_confirmed"))
	_check(bea.current_node_id == "turned", "the other end of her own advertisement turns her (%s)" % bea.current_node_id)
	# The row pays 20 and the node she lands on pays 10 more on first entry.
	_check(bea.cooperation == before + 30, "...and it counts for something (%d -> %d)" % [before, bea.cooperation])
	_check(not SessionState.witness_flipped, "the flag waits for the ending")
	var credibility_before: int = SessionState.detective_credibility
	bea._load_node("end_turned")
	_check(SessionState.witness_flipped, "a turned witness opens the second floor")
	var statement := _index_of(bea, "test_bea_turned")
	_check(statement >= 0 and str(SessionState.investigation_inventory[statement].get("script", "")) == "job_offer",
		"...and her statement is granted, tagged with the floor's recruiting script")
	_check(SessionState.detective_credibility == credibility_before + 15,
		"turning a witness is worth what a confirmed one is (%d -> %d)" % [credibility_before, SessionState.detective_credibility])
	_check(SessionState.investigation_outcome == "turned", "the ending records the outcome (%s)" % SessionState.investigation_outcome)
	await _close(bea)

	# Without the statement she stays a job she is defending.
	SessionState.reset_session()
	SessionState.detective_credibility = 65
	SessionState.pending_case_path = CASE_BEA
	bea = load(INTERVIEW_SCENE).instantiate()
	add_child(bea)
	await get_tree().process_frame
	bea._load_node("end_partial")
	_check(not SessionState.witness_flipped, "leaving without turning her opens nothing")
	await _close(bea)

	SessionState.witness_flipped = true
	SessionState.reset_session()
	_check(not SessionState.witness_flipped, "a fresh session starts with the second floor closed")


# Rowena denies. She is cracked by a witness from each of her floor's two
# scripts, her denial is broken by a callback, and her ending names the company
# through the engine's one copy of the name.
func _test_fourth_floor_director() -> void:
	print("\n[the fourth floor's director]")
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.witness_flipped = true
	SessionState.add_evidence({"id": "test_kevin_confirmed", "label": "Kevin's Confirmed Testimony",
		"person_id": "kevin_d", "script": "tech_support"})
	SessionState.add_evidence({"id": "test_trish_confirmed", "label": "Trish's Confirmed Testimony",
		"person_id": "patricia_lim", "script": "job_offer"})
	SessionState.pending_case_path = CASE_ROWENA
	var rowena: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(rowena)
	await get_tree().process_frame
	_check(rowena.current_node_id == "start", "Rowena opens on her own terms (%s)" % rowena.current_node_id)
	rowena._load_node("deny_node")
	var before: int = rowena.cooperation
	rowena._present_evidence_index(_index_of(rowena, "test_kevin_confirmed"))
	_check(rowena.current_node_id == "caught_callback", "Kevin's callback breaks her denial (%s)" % rowena.current_node_id)
	_check(rowena.prompt_value.text.contains("CONTRADICTION"), "...and it reads as a contradiction, not corroboration")
	_check(rowena.cooperation > before, "...and moves her")
	rowena._load_node("final_check")
	_check(rowena.current_node_id == "end_named",
		"a tech-support witness and a job-offer witness together name the company (%s)" % rowena.current_node_id)
	_check(rowena.prompt_value.text.contains(SessionState.COMPANY_NAME), "the ending prints the one copy of the name")
	_check(SessionState.has_evidence("ev_owner_name"), "...and puts the name above the floors in the file as evidence")
	_check(SessionState.investigation_outcome == "owner_named", "the outcome is recorded (%s)" % SessionState.investigation_outcome)
	await _close(rowena)

	# Two witnesses from the same script are not enough; she answers for two.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.witness_flipped = true
	SessionState.add_evidence({"id": "test_kevin_confirmed", "label": "K", "person_id": "kevin_d", "script": "tech_support"})
	SessionState.add_evidence({"id": "test_maria_confirmed", "label": "M", "person_id": "maria_santos", "script": "bank_fraud"})
	SessionState.pending_case_path = CASE_ROWENA
	rowena = load(INTERVIEW_SCENE).instantiate()
	add_child(rowena)
	await get_tree().process_frame
	_check(not rowena._presentable_ids().has("test_maria_confirmed"), "a bank-fraud witness is not something she can be shown")
	rowena._load_node("final_check")
	_check(rowena.current_node_id == "end_denied", "one witness from her floor is a denial, not a name (%s)" % rowena.current_node_id)
	_check(not SessionState.has_evidence("ev_owner_name"), "...and nothing above her is named")
	await _close(rowena)

	# Bea's own statement counts as the job-offer witness.
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.witness_flipped = true
	SessionState.add_evidence({"id": "test_kevin_confirmed", "label": "K", "person_id": "kevin_d", "script": "tech_support"})
	SessionState.add_evidence({"id": "test_bea_turned", "label": "B", "person_id": "bea_santiago", "script": "job_offer"})
	SessionState.pending_case_path = CASE_ROWENA
	rowena = load(INTERVIEW_SCENE).instantiate()
	add_child(rowena)
	await get_tree().process_frame
	rowena._load_node("deny_node")
	rowena._present_evidence_index(_index_of(rowena, "test_bea_turned"))
	_check(rowena.current_node_id == "bea_node", "the recruit's statement has its own reaction (%s)" % rowena.current_node_id)
	rowena._load_node("final_check")
	_check(rowena.current_node_id == "end_named", "Kevin and Bea together are enough (%s)" % rowena.current_node_id)
	await _close(rowena)

	SessionState.add_evidence({"id": "ev_owner_name", "label": "The Name Above The Floors"})
	SessionState.reset_session()
	_check(not SessionState.has_evidence("ev_owner_name"), "a fresh session has nobody named above the floors")


# Dennis is broken by evidence, not pressure: any two witnesses with names, from
# either floor, and he gives the name above them - the same item Rowena gives.
func _test_closer() -> void:
	print("\n[the closer]")
	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.add_evidence({"id": "test_lina_confirmed", "label": "Lina's Confirmed Testimony",
		"person_id": "lina_reyes", "script": "lottery"})
	SessionState.add_evidence({"id": "test_trish_confirmed", "label": "Trish's Confirmed Testimony",
		"person_id": "patricia_lim", "script": "job_offer"})
	SessionState.pending_case_path = CASE_DENNIS
	var dennis: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(dennis)
	await get_tree().process_frame
	_check(dennis._presentable_ids().has("test_trish_confirmed"), "the closer can be shown a witness from the other floor")
	dennis._load_node("deny_node")
	dennis._present_evidence_index(_index_of(dennis, "test_lina_confirmed"))
	_check(dennis.current_node_id == "caught_callbacks", "three callbacks break 'nobody hears my voice twice' (%s)" % dennis.current_node_id)
	_check(dennis.prompt_value.text.contains("CONTRADICTION"), "...as a contradiction")
	dennis._load_node("pressed")
	dennis._present_evidence_index(_index_of(dennis, "test_trish_confirmed"))
	_check(dennis.current_node_id == "two_names", "a second name from any script is his price (%s)" % dennis.current_node_id)
	dennis._load_node("final_check")
	_check(dennis.current_node_id == "end_named", "two names buy the owner's (%s)" % dennis.current_node_id)
	_check(SessionState.has_evidence("ev_owner_name"), "...as the same evidence Rowena gives")
	_check(dennis.prompt_value.text.contains(SessionState.COMPANY_NAME), "...printed from the one copy")
	_check(SessionState.investigation_outcome == "owner_named", "the outcome is recorded (%s)" % SessionState.investigation_outcome)
	await _close(dennis)

	SessionState.reset_session()
	SessionState.detective_credibility = GATE_CLEAR
	SessionState.add_evidence({"id": "test_maria_confirmed", "label": "M", "person_id": "maria_santos", "script": "bank_fraud"})
	SessionState.pending_case_path = CASE_DENNIS
	dennis = load(INTERVIEW_SCENE).instantiate()
	add_child(dennis)
	await get_tree().process_frame
	dennis._load_node("final_check")
	_check(dennis.current_node_id == "end_denied", "one name is a number to him (%s)" % dennis.current_node_id)
	_check(not SessionState.has_evidence("ev_owner_name"), "...and buys nothing")
	await _close(dennis)


# The investigation's pressure: a case has six statements in it. A witness
# interview that reaches an ending spends one; a refusal at the door does not;
# the suspects and directors are free; a failure closes the witness; and an
# ending pays its credibility once per person, so nothing can be farmed.
func _test_statement_budget() -> void:
	print("\n[the statement budget]")
	SessionState.reset_session()
	SessionState.detective_credibility = 50
	_check(SessionState.statements_left() == SessionState.STATEMENT_BUDGET, "a fresh case has every statement left")

	var evelyn: Node = await _open_at(CASE_EVELYN, 50)
	evelyn._load_node("end_success")
	_check(SessionState.statements_taken == 1, "a witness interview that ends spends a statement (%d)" % SessionState.statements_taken)
	_check(SessionState.detective_credibility == 65, "...and pays its credibility (%d)" % SessionState.detective_credibility)
	await _close(evelyn)

	var kevin: Node = await _open_at(CASE_KEVIN, 50)
	_check(kevin.current_node_id == "hesitant_intro", "Kevin refuses at 50")
	kevin._load_node("end_partial_hesitant")
	_check(SessionState.statements_taken == 1, "a refusal at the door spends nothing (%d)" % SessionState.statements_taken)
	await _close(kevin)

	SessionState.add_evidence({"id": "test_evelyn_confirmed", "label": "E", "person_id": "evelyn_marsh", "script": "lottery"})
	var marco: Node = await _open_at(CASE_MARCO, SessionState.detective_credibility)
	marco._load_node("end_whistleblower")
	await _close(marco)
	_check(SessionState.statements_taken == 1, "a suspect spends nothing (%d)" % SessionState.statements_taken)

	kevin = await _open_at(CASE_KEVIN, GATE_CLEAR)
	_check(kevin.current_node_id == "intro", "Kevin talks at %d" % GATE_CLEAR)
	kevin._load_node("end_shutdown")
	_check(SessionState.statements_taken == 2, "a failed interview still spent its statement (%d)" % SessionState.statements_taken)
	_check(SessionState.is_witness_closed("kevin_d"), "...and closes the witness for good")
	_check(not SessionState.is_witness_closed("evelyn_marsh"), "...only that witness")
	await _close(kevin)

	# Credibility is paid once per person. A partial then a success nets the
	# success; a second success nets nothing; a suspect cannot be farmed.
	SessionState.reset_session()
	SessionState.detective_credibility = 50
	evelyn = await _open_at(CASE_EVELYN, 50)
	evelyn._load_node("end_partial")
	_check(SessionState.detective_credibility == 55, "a partial pays 5 (%d)" % SessionState.detective_credibility)
	await _close(evelyn)
	evelyn = await _open_at(CASE_EVELYN, SessionState.detective_credibility)
	evelyn._load_node("end_success")
	_check(SessionState.detective_credibility == 65, "...and a success after it nets the full 15, not 20 (%d)" % SessionState.detective_credibility)
	await _close(evelyn)
	evelyn = await _open_at(CASE_EVELYN, SessionState.detective_credibility)
	evelyn._load_node("end_success")
	_check(SessionState.detective_credibility == 65, "a second success pays nothing (%d)" % SessionState.detective_credibility)
	await _close(evelyn)

	SessionState.reset_session()
	SessionState.detective_credibility = 50
	for i in range(2):
		SessionState.add_evidence({"id": "test_lina_confirmed", "label": "L", "person_id": "lina_reyes", "script": "lottery"})
		SessionState.add_evidence({"id": "test_trish_confirmed", "label": "T", "person_id": "patricia_lim", "script": "job_offer"})
		var dennis: Node = await _open_at(CASE_DENNIS, SessionState.detective_credibility)
		dennis._load_node("end_named")
		await _close(dennis)
	_check(SessionState.detective_credibility == 65, "running the closer's ending twice pays once (%d)" % SessionState.detective_credibility)
	_check(SessionState.statements_taken == 0, "...and the closer never spent a statement")

	SessionState.statements_taken = 4
	SessionState.closed_witnesses.append("kevin_d")
	SessionState.reset_session()
	_check(SessionState.statements_taken == 0 and SessionState.closed_witnesses.is_empty(),
		"a fresh session has every statement and every witness back")


func _open_at(case_path: String, credibility: int) -> Node:
	SessionState.detective_credibility = credibility
	SessionState.pending_case_path = case_path
	var view: Node = load(INTERVIEW_SCENE).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


# A victim's kitchen is not a call floor. The case names where it happens, the
# interview picks the photo for it, and a photo not yet added falls back to the
# office instead of a missing texture.
func _test_setting_backgrounds() -> void:
	print("\n[where the interview happens]")
	var script: Script = load("res://scripts/investigation/interview.gd")
	var default_bg: String = script.DEFAULT_BACKGROUND
	_check(ResourceLoader.exists(default_bg), "the fallback photo exists")
	_check(script.background_for("office") == default_bg, "the office is the default photo")
	_check(script.background_for("not_a_setting") == default_bg, "an unknown setting falls back to it")
	_check(script.background_for("") == default_bg, "so does a case with none")
	var call_floor: String = script.SETTING_BACKGROUNDS["call_floor"]
	_check(ResourceLoader.exists(call_floor) and script.background_for("call_floor") == call_floor,
		"the call floor has its own photo in the repo already")
	var home: String = script.SETTING_BACKGROUNDS["home"]
	if ResourceLoader.exists(home):
		_check(script.background_for("home") == home, "a home photo, once added, is used")
	else:
		_check(script.background_for("home") == default_bg, "until a home photo is added, homes fall back to the office")

	var view := await _open(CASE_MARIA)
	_check(str(view.person.get("setting", "")) == "home", "Maria is interviewed at home")
	_check(view.background != null and view.background.texture != null, "the interview draws a background")
	_check(view.background.texture.resource_path == script.background_for("home"),
		"...and it is the one her setting resolves to")
	await _close(view)
