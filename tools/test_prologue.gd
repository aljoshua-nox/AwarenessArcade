extends Node

## Headless smoke test for the prologue call screen: the transcript's
## beat-by-beat reveal, the Doubt meter, the authored endings, reports, and the
## record every call leaves for the investigation to read.
##
##   godot --headless --path . res://tools/test_prologue.tscn
##
## The call box holds the whole conversation, so the typewriter has to reveal
## only the newly queued tail while the history stays put - and the choice
## buttons have to stay shut until the line the player is answering has
## actually arrived. Doubt is the only meter and it belongs to the victim: it
## resets per call, moves only by the line the player chose, branches the
## script at its checks and hangs the call up at its ceiling. Every ending
## declares its own payout and consequence, and that is exactly what gets
## recorded. Exits 0 if every check passes, 1 otherwise.

const TextStyle := preload("res://scripts/systems/text_style.gd")

const PROLOGUE_SCENE := "res://scenes/prologue/prologue_call.tscn"
const DRAIN_TIMEOUT_MS := 12000
const MAX_WALK_STEPS := 16

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


func _open() -> Node:
	SessionState.reset_session()
	SessionState.reset_prologue()
	SessionState.prologue_played = true
	var view: Node = load(PROLOGUE_SCENE).instantiate()
	view.suppress_scene_change = true
	add_child(view)
	await get_tree().process_frame
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


# Wall-clock bounded so a stalled pump fails the suite instead of hanging it.
func _drain(view: Node, label: String) -> void:
	var deadline := Time.get_ticks_msec() + DRAIN_TIMEOUT_MS
	while view._is_revealing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not view._is_revealing(), "%s: the queue drains on its own" % label)


func _box(view: Node) -> String:
	return view.dialogue_value.text


func _victim_index(view: Node, person_id: String) -> int:
	for i in range(view.victims.size()):
		if str(view.victims[i].get("person_id", "")) == person_id:
			return i
	return -1


func _node(view: Node, person_id: String, node_id: String) -> Dictionary:
	var index := _victim_index(view, person_id)
	if index < 0:
		return {}
	return (view.victims[index].get("nodes", {}) as Dictionary).get(node_id, {})


# Index of the choice on the current node that continues the call (not a
# bail-out into an `aborted` ending), with the smallest or largest doubt.
func _choice_by_doubt(view: Node, largest: bool) -> int:
	var choices: Array = view.current_node.get("choices", [])
	var nodes: Dictionary = view.victims[view.current_victim_index].get("nodes", {})
	var best := -1
	var best_doubt := 0
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var target: Dictionary = nodes.get(str(choice.get("next", "")), {})
		if str(target.get("outcome", "")) == SessionState.CALL_ABORTED:
			continue
		var delta := int(choice.get("doubt", 0))
		if best < 0 or (delta > best_doubt if largest else delta < best_doubt):
			best = i
			best_doubt = delta
	return best


func _run() -> void:
	print("\n--- prologue call screen smoke test ---")

	await _test_opening_holds_the_prompt_back()
	await _test_choice_queues_one_beat_per_line()
	await _test_history_is_not_retyped()
	await _test_skip_drains_everything()
	await _test_ending_a_call_queues_its_summary()
	await _test_a_new_call_starts_a_new_transcript()
	await _test_doubt_belongs_to_the_call()
	await _test_doubt_checks_branch_the_script()
	await _test_doubt_ceiling_hangs_up()
	await _test_endings_record_what_they_declare()
	await _test_reports_pull_the_line()
	await _test_clocks_wait_for_the_reveal()
	await _test_patience_running_out_hangs_up()
	await _test_a_number_is_worked_once()
	await _test_every_call_outcome_has_a_cost()
	await _test_a_refused_call_is_recorded_and_shown()
	await _test_tactic_use_is_recorded()
	await _test_every_script_pays_or_hangs_up()
	await _test_victim_rows_resolve_by_metadata()
	await _test_continuing_keeps_the_call_log()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures.size() > 0 else 0)


# Starting a call used to dump the target line, the intro and the opening prompt
# into the box at once. They are beats now, and the prompt is the last of them.
func _test_opening_holds_the_prompt_back() -> void:
	print("\n[opening a call]")
	var view := await _open()
	view._start_call(0)
	var styled_prompt: String = TextStyle.dialogue(view.current_prompt_text)

	_check(view._is_revealing(), "the opening is still arriving, not already there")
	_check(not view.current_prompt_text.is_empty(), "the node's prompt is loaded")
	_check(not _box(view).contains(styled_prompt),
		"the prompt is not in the box while the line ahead of it is still typing")
	_check(view.dialogue_value.visible_characters < view.dialogue_value.get_total_character_count(),
		"the box is withholding characters rather than showing everything")
	_check(view.choice_buttons[0].disabled, "choices are shut while the call is still opening")

	await _drain(view, "opening")

	_check(view.transcript_lines[0].contains(TextStyle.MARK_DIALING)
		and view.transcript_lines[0].contains(str(view.victims[0].get("name", ""))),
		"the dialing line, naming the target, landed first")
	_check(view.transcript_lines[view.transcript_lines.size() - 1] == styled_prompt,
		"the prompt lands last, once the line ahead of it is read")
	_check(view.dialogue_value.visible_characters == view.dialogue_value.get_total_character_count(),
		"everything queued is visible once the queue is empty")
	_check(not view.choice_buttons[0].disabled, "choices open once the prompt has arrived")
	_check(view.choice_buttons[0].text == str(view.current_node["choices"][0]["text"]),
		"the first button carries the first authored choice - no shuffle")
	await _close(view)


# A choice's reply is separate beats - what the player said, the tactic it
# was, and the victim's answer - not one block joined with newlines.
func _test_choice_queues_one_beat_per_line() -> void:
	print("\n[answering a choice]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")

	var settled_lines: int = view.transcript_lines.size()
	var chosen_text := str(view.current_node["choices"][0]["text"])
	view._on_choice_pressed(0)

	_check(view.pending_beats.size() + (view.transcript_lines.size() - settled_lines) >= 3,
		"the reply is queued as several beats, not one block")
	_check(view.choice_buttons[0].disabled, "choices are shut while the reply arrives")
	_check(view.choice_buttons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"a shut choice button lets the click through so it can skip")

	await _drain(view, "reply")

	var arrived: Array[String] = []
	for i in range(settled_lines, view.transcript_lines.size()):
		arrived.append(view.transcript_lines[i])
	_check(arrived.size() >= 3, "each line of the reply is its own transcript beat")
	_check(arrived[0].contains(chosen_text), "the player's own line lands first")
	_check(arrived[1].contains(TextStyle.MARK_TACTIC_USED), "the tactic used is named second")
	_check(arrived[arrived.size() - 1] == TextStyle.dialogue(view.current_prompt_text),
		"the victim's answer lands last, after the line it answers")
	_check(not view.choice_buttons[0].disabled, "choices reopen once the reply is read")
	_check(view.choice_buttons[0].mouse_filter == Control.MOUSE_FILTER_STOP,
		"an open choice button takes the mouse again")
	await _close(view)


# The box holds the whole call, so the tween must start partway through it.
# Retyping from zero would replay the entire conversation on every beat.
func _test_history_is_not_retyped() -> void:
	print("\n[history stays put]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")

	var already_read: int = view.revealed_chars
	var opening_line: String = view.transcript_lines[0]
	_check(already_read > 0, "the opening left characters on screen")
	view._on_choice_pressed(0)
	await get_tree().process_frame

	_check(view.transcript_lines[0] == opening_line,
		"the opening line is still in the transcript, not cleared")
	_check(view.revealed_chars >= already_read,
		"the new beat types from the read mark inside the call, not from zero")
	_check(view.dialogue_value.visible_characters >= view.revealed_chars,
		"everything already read stays on screen while the new beat types")
	_check(view.dialogue_value.visible_characters < view.dialogue_value.get_total_character_count(),
		"the new beat is still arriving rather than appearing all at once")
	await _drain(view, "reply")
	_check(view.revealed_chars > already_read, "the read mark advanced with the new beat")
	await _close(view)


func _test_skip_drains_everything() -> void:
	print("\n[skipping ahead]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")

	view._on_choice_pressed(0)
	_check(view._is_revealing(), "the reply is mid-flight before the skip")
	view._finish_reveal()

	_check(not view._is_revealing(), "skipping ends the reveal outright")
	_check(view.pending_beats.is_empty(), "nothing is left queued")
	_check(_box(view).contains(TextStyle.dialogue(view.current_prompt_text)), "the prompt is in the box")
	_check(view.dialogue_value.visible_characters == view.dialogue_value.get_total_character_count(),
		"every skipped character is visible")
	_check(not view.choice_buttons[0].disabled, "choices open immediately after a skip")
	await _close(view)


func _test_ending_a_call_queues_its_summary() -> void:
	print("\n[ending a call]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")

	view._end_current_call(SessionState.CALL_REFUSED)
	_check(view._is_revealing(), "the closing lines arrive as beats, not instantly")
	_check(not view.call_active, "the call is closed")
	await _drain(view, "ending")

	var has_ended := false
	for line in view.transcript_lines:
		if line.contains(TextStyle.MARK_CALL_ENDED):
			has_ended = true
	_check(has_ended, "the call-ended line is read")
	_check(view.choice_buttons[0].visible == false, "no choices are offered after the call ends")
	await _close(view)


func _test_a_new_call_starts_a_new_transcript() -> void:
	print("\n[a second call]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")
	var first_name := str(view.victims[0].get("name", ""))
	view._end_current_call(SessionState.CALL_REFUSED)
	await _drain(view, "ending")

	view._start_call(1)
	_check(view.call_active, "a second number can be dialed")
	_check(not _box(view).contains(first_name),
		"the previous victim's call is cleared from the box")
	_check(view.revealed_chars <= view.dialogue_value.get_total_character_count(),
		"the read mark is rebased on the new transcript, not the old one")
	await _drain(view, "second opening")
	_check(_box(view).contains(str(view.victims[1].get("name", ""))),
		"the new target is named in the fresh transcript")
	await _close(view)


# The old trust meter carried from one call into the next and moved by a
# keyword scan of a randomly picked line. Doubt is the victim's, starts where
# their script says, and moves by exactly the number written on the line chosen.
func _test_doubt_belongs_to_the_call() -> void:
	print("\n[doubt is per call and per line]")
	var view := await _open()
	view._start_call(0)
	view._finish_reveal()
	var start: int = int(view.victims[0].get("doubt_start", -1))
	_check(view.doubt == start, "a call opens at the victim's own doubt_start (%d)" % start)
	_check(view.doubt_value.text.begins_with(str(start)), "the meter shows it")

	var choices: Array = view.current_node.get("choices", [])
	var pressed := -1
	for i in range(choices.size()):
		if int(choices[i].get("doubt", 0)) != 0:
			pressed = i
			break
	var delta := int(choices[pressed].get("doubt", 0))
	view._on_choice_pressed(pressed)
	view._finish_reveal()
	_check(view.doubt == start + delta, "the chosen line moved doubt by its own delta (%+d)" % delta)

	view._end_current_call(SessionState.CALL_REFUSED)
	view._finish_reveal()
	_check(view.doubt_value.text == "-", "no call, no doubt to show")
	view._start_call(1)
	view._finish_reveal()
	_check(view.doubt == int(view.victims[1].get("doubt_start", -1)),
		"the next call opens at its own start - nothing carries over")
	await _close(view)


# A `doubt_check` node is never shown; it routes on the meter. Under the
# threshold the ask lands, over it the victim balks.
func _test_doubt_checks_branch_the_script() -> void:
	print("\n[doubt checks branch]")
	var view := await _open()
	var maria := _victim_index(view, "maria_santos")
	var check: Dictionary = _node(view, "maria_santos", "code_check").get("doubt_check", {})
	var threshold := int(check.get("max_doubt", 0))
	_check(threshold > 0, "Maria's code_check has a threshold")

	view._start_call(maria)
	view._finish_reveal()
	view.doubt = threshold
	view._load_node("code_check")
	view._finish_reveal()
	_check(not view.call_active, "at the threshold she reads the code and the call closes")
	_check(str(SessionState.get_call_record("maria_santos").get("outcome", "")) == SessionState.CALL_SUCCESS,
		"...as a success")

	await _close(view)
	view = await _open()
	view._start_call(maria)
	view._finish_reveal()
	view.doubt = threshold + 1
	view._load_node("code_check")
	view._finish_reveal()
	_check(view.call_active and view.current_node_id == str(check.get("next_if_wary", "")),
		"one over the threshold she balks instead")
	_check(not view.current_node.get("choices", []).is_empty(), "...and the player gets another move")
	await _close(view)


func _test_doubt_ceiling_hangs_up() -> void:
	print("\n[the ceiling]")
	var view := await _open()
	view._start_call(0)
	view._finish_reveal()
	var person_id := str(view.victims[0].get("person_id", ""))
	var hang_up_node: Dictionary = _node(view, person_id, str(view.victims[0].get("hang_up_node", "")))
	view.doubt = view.DOUBT_CEILING - 1
	var choices: Array = view.current_node.get("choices", [])
	var pressed := -1
	for i in range(choices.size()):
		if int(choices[i].get("doubt", 0)) > 0:
			pressed = i
			break
	view._on_choice_pressed(pressed)
	view._finish_reveal()

	_check(not view.call_active, "crossing the ceiling ends the call")
	var record: Dictionary = SessionState.get_call_record(person_id)
	_check(str(record.get("outcome", "")) == SessionState.CALL_HUNG_UP, "...as a hang-up")
	_check(_box(view).contains(TextStyle.dialogue(str(hang_up_node.get("prompt", "")))),
		"the victim's own hang-up line is what was read")
	_check(str(record.get("consequence", "")) == str(hang_up_node.get("consequence", "")),
		"the consequence recorded is the one written for the hang-up")
	_check(SessionState.reports_filed == 1, "a victim who hangs up on you reports the number")
	_check(_box(view).contains(TextStyle.MARK_REPORTED), "...and the transcript says so")
	await _close(view)


# The payout used to be a computed threshold and the aftermath text a random
# variant that could name a different amount. An ending is one node that
# declares both, and the record carries exactly what it declares.
func _test_endings_record_what_they_declare() -> void:
	print("\n[endings are the record]")
	var view := await _open()
	var maria := _victim_index(view, "maria_santos")
	var paid: Dictionary = _node(view, "maria_santos", "paid")
	view._start_call(maria)
	view._finish_reveal()
	view._load_node("paid")
	view._finish_reveal()

	var record: Dictionary = SessionState.get_call_record("maria_santos")
	_check(str(record.get("outcome", "")) == SessionState.CALL_SUCCESS, "a paid ending logs a success")
	_check(int(record.get("payout", 0)) == int(paid.get("payout", -1)),
		"the payout logged is the payout the ending declares")
	_check(str(record.get("consequence", "")) == str(paid.get("consequence", "")),
		"the consequence logged is the ending's own, not a random pool line")
	_check(SessionState.profit == int(paid.get("payout", -1)), "the shift total is the sum of payouts")
	_check(SessionState.reports_filed == 0, "someone who paid did not report you")
	_check(_box(view).contains(view._format_currency(int(paid.get("payout", 0)))), "the call-ended line prints the amount")
	_check(SessionState.get_victim_disposition("maria_santos") == SessionState.DISPOSITION_HARMED,
		"the investigation will read her as harmed")

	view._start_call(_victim_index(view, "kevin_d"))
	view._finish_reveal()
	view._load_node("bail")
	view._finish_reveal()
	var bail: Dictionary = SessionState.get_call_record("kevin_d")
	_check(str(bail.get("outcome", "")) == SessionState.CALL_ABORTED, "walking away logs as dropped by the operator")
	_check(int(bail.get("payout", 0)) == 0, "...with nothing taken")
	_check(SessionState.get_victim_disposition("kevin_d") == SessionState.DISPOSITION_UNFINISHED,
		"...and the investigation reads him as unfinished")
	await _close(view)


func _test_reports_pull_the_line() -> void:
	print("\n[reports pull the line]")
	var view := await _open()
	var ids := ["maria_santos", "kevin_d", "lina_reyes"]
	for n in range(ids.size()):
		view._start_call(_victim_index(view, ids[n]))
		view._finish_reveal()
		view._load_node("refused")
		if n < ids.size() - 1:
			view._finish_reveal()
			_check(SessionState.reports_filed == n + 1, "report %d is counted" % (n + 1))
			_check(not view.prologue_end_transition_started, "the shift carries on after report %d" % (n + 1))
	_check(SessionState.reports_filed == SessionState.REPORTS_TO_PULL_LINE, "the third report lands")
	_check(not view.pending_shift_end.is_empty(), "the shift end is scheduled")
	_check(not view.prologue_end_transition_started,
		"...but waits for the closing lines of the call to be read")
	view._start_call(_victim_index(view, "ramon_tolentino"))
	_check(not view.call_active, "no new call can be dialed once the line is pulled")
	view._finish_reveal()
	_check(view.prologue_end_transition_started, "the shift ends once the queue drains")
	_check(SessionState.prologue_end_reason == "Line Pulled", "...for the stated reason")
	_check(SessionState.has_reflection_milestone("Line Pulled"), "...and it is on the record")
	await _close(view)


# A clock that ran while a line was typing would reward skipping the text.
func _test_clocks_wait_for_the_reveal() -> void:
	print("\n[the clocks wait]")
	var view := await _open()
	view._start_call(0)
	var shift_before: float = SessionState.time_left
	var patience_before: float = view.current_call_time_left
	_check(view._is_revealing(), "the opening is typing")
	view._process(1.0)
	_check(is_equal_approx(SessionState.time_left, shift_before), "the shift clock holds while a line types")
	_check(is_equal_approx(view.current_call_time_left, patience_before), "so does the victim's patience")
	view._finish_reveal()
	view._process(1.0)
	_check(SessionState.time_left < shift_before, "the shift clock runs once the player can act")
	_check(view.current_call_time_left < patience_before, "and so does patience")
	await _close(view)


func _test_patience_running_out_hangs_up() -> void:
	print("\n[patience runs out]")
	var view := await _open()
	view._start_call(0)
	view._finish_reveal()
	var person_id := str(view.victims[0].get("person_id", ""))
	view.current_call_time_left = 0.01
	view._process(0.1)
	_check(not view.call_active, "the call ends when patience runs out")
	var record: Dictionary = SessionState.get_call_record(person_id)
	_check(str(record.get("outcome", "")) == SessionState.CALL_HUNG_UP, "...as a hang-up")
	_check(not str(record.get("consequence", "")).is_empty(),
		"...with a consequence from the victim's pool, since no ending was written for it")
	_check(SessionState.reports_filed == 0, "losing their patience is not a report")
	await _close(view)


func _test_a_number_is_worked_once() -> void:
	print("\n[a number is worked once]")
	var view := await _open()
	view._start_call(0)
	view._finish_reveal()
	view._end_current_call(SessionState.CALL_REFUSED)
	view._finish_reveal()
	var calls_before: int = SessionState.calls_made
	view._start_call(0)
	_check(not view.call_active, "a victim already called this shift cannot be dialed again")
	_check(SessionState.calls_made == calls_before, "...and it does not count as a call")
	_check(view.victim_list.is_item_disabled(view._row_for_victim_index(0)), "their row is grayed out")
	_check(view.victim_list.get_item_text(view._row_for_victim_index(0)).ends_with("called"), "...and says so")
	view._start_call(1)
	_check(view.call_active, "the next number still dials")
	await _close(view)


# The project's guardrail is that scam success must never read as pure power
# fantasy. Every ending the engine can force on a call - patience, the shift
# clock, the end-shift button - still has a line in the victim's own words.
func _test_every_call_outcome_has_a_cost() -> void:
	print("\n[the cost of a call]")
	var view := await _open()
	var outcomes := [
		SessionState.CALL_SUCCESS, SessionState.CALL_PARTIAL, SessionState.CALL_REFUSED,
		SessionState.CALL_HUNG_UP, SessionState.CALL_ESCALATED, SessionState.CALL_TIMEOUT,
		SessionState.CALL_ABORTED,
	]
	var gaps: Array[String] = []
	for victim in view.victims:
		for outcome in outcomes:
			var line: String = view._pick_consequence_line(victim, outcome)
			if line.is_empty():
				gaps.append("%s/%s" % [str(victim.get("person_id", "?")), outcome])
	_check(gaps.is_empty(),
		"every victim has a consequence line for every call outcome (missing: %s)" % ", ".join(gaps))

	var maria: Dictionary = view.victims[_victim_index(view, "maria_santos")]
	var pools: Dictionary = maria.get("perspective_variants", {})
	var refused_line: String = view._pick_consequence_line(maria, SessionState.CALL_REFUSED)
	var timeout_line: String = view._pick_consequence_line(maria, SessionState.CALL_TIMEOUT)
	_check((pools.get("resistant", []) as Array).has(refused_line), "a refusal falls back to the resistant lines")
	_check((pools.get("unfinished", []) as Array).has(timeout_line), "a call that never resolved falls back to unfinished")
	var paid: Dictionary = _node(view, "maria_santos", "paid")
	_check(view._pick_consequence_line(maria, SessionState.CALL_SUCCESS, paid) == str(paid.get("consequence", "")),
		"an ending's own line beats the pool")
	_check(view._pick_consequence_line(maria, "").is_empty(), "an unknown outcome claims nothing")
	await _close(view)


func _test_a_refused_call_is_recorded_and_shown() -> void:
	print("\n[a refused call]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")
	var person_id: String = str(view.victims[0].get("person_id", ""))

	view._end_current_call(SessionState.CALL_REFUSED)
	await _drain(view, "ending")

	var record: Dictionary = SessionState.get_call_record(person_id)
	var recorded: String = str(record.get("consequence", ""))
	_check(str(record.get("outcome", "")) == SessionState.CALL_REFUSED,
		"the refusal is logged as a refusal, not a payout")
	_check(not recorded.is_empty(),
		"the call record carries what the call cost them, for the investigation to quote")
	_check(_box(view).contains(TextStyle.MARK_AFTERMATH),
		"a refused call still shows the victim afterwards")
	_check(_box(view).contains(recorded), "the line shown is the line recorded")
	await _close(view)


func _test_tactic_use_is_recorded() -> void:
	print("\n[tactics used]")
	var view := await _open()
	view._start_call(0)
	view._finish_reveal()
	var choices: Array = view.current_node.get("choices", [])
	var pressed := -1
	for i in range(choices.size()):
		if not str(choices[i].get("tactic_id", "")).is_empty():
			pressed = i
			break
	var tactic_id := str(choices[pressed].get("tactic_id", ""))
	_check(TacticNotebook.has_tactic(tactic_id), "the choice's tactic is in the catalogue")
	view._on_choice_pressed(pressed)
	view._finish_reveal()
	_check(SessionState.prologue_tactics_used.has(tactic_id), "using a tactic records it for the summary")
	_check(_box(view).contains(view._tactic_name(tactic_id)), "the transcript names the tactic used")
	_check(not SessionState.has_learned_tactic(tactic_id),
		"using a tactic does not unlock it in the notebook - naming it is the investigation's job")
	await _close(view)


# Route tuning, for every script: the calmest line at every turn reaches a
# payout, and the most aggressive line at every turn gets the phone put down.
# A script where the careful route cannot pay is unwinnable; one where the
# reckless route cannot lose has no reason to read the victim.
func _test_every_script_pays_or_hangs_up() -> void:
	print("\n[every script has both ends]")
	var view := await _open()
	for index in range(view.victims.size()):
		var person_id := str(view.victims[index].get("person_id", ""))
		for largest in [false, true]:
			SessionState.reset_prologue()
			SessionState.prologue_played = true
			view.called_indices.clear()
			view._start_call(index)
			view._finish_reveal()
			var steps := 0
			while view.call_active and steps < MAX_WALK_STEPS:
				var pick := _choice_by_doubt(view, largest)
				if pick < 0:
					break
				view._on_choice_pressed(pick)
				view._finish_reveal()
				steps += 1
			var outcome := str(SessionState.get_call_record(person_id).get("outcome", ""))
			if largest:
				_check(outcome == SessionState.CALL_HUNG_UP,
					"%s: pushing every line gets you hung up on (got '%s')" % [person_id, outcome])
			else:
				_check(outcome == SessionState.CALL_SUCCESS,
					"%s: the calm route pays out (got '%s')" % [person_id, outcome])
	await _close(view)


# The victim list hands out ROW numbers. They line up with `victims` today
# because nothing is filtered, but the evidence list made that same assumption
# and broke silently the moment it started filtering - so the contract, not the
# coincidence, is what gets checked here.
func _test_victim_rows_resolve_by_metadata() -> void:
	print("\n[the victim list resolves rows, not positions]")
	var view := await _open()

	_check(view.victim_list.item_count == view.victims.size(),
		"every victim has a row (%d rows, %d victims)"
		% [view.victim_list.item_count, view.victims.size()])

	var mismatched := 0
	for row in range(view.victim_list.item_count):
		var index: int = view._victim_index_for_row(row)
		if index < 0 or index >= view.victims.size():
			mismatched += 1
			continue
		if not view.victim_list.get_item_text(row).begins_with(
				str(view.victims[index].get("name", ""))):
			mismatched += 1
	_check(mismatched == 0, "every row resolves to the victim it names (%d wrong)" % mismatched)
	_check(view._victim_index_for_row(-1) == -1, "a row below the list resolves to nothing")
	_check(view._victim_index_for_row(view.victim_list.item_count) == -1,
		"a row past the end resolves to nothing")

	var last_row: int = view.victim_list.item_count - 1
	view._on_victim_selected(last_row)
	_check(view.preview_victim_index == view._victim_index_for_row(last_row),
		"selecting a row previews the victim that row names")
	await _close(view)


# The summary's Continue used to call reset_session(), which wiped the call log
# on the way into the investigation - so through the real player path every
# victim read as never-called, and the coupling only ever worked in tests.
func _test_continuing_keeps_the_call_log() -> void:
	print("\n[continuing keeps the log]")
	SessionState.reset_session()
	SessionState.reset_prologue()
	SessionState.prologue_played = true
	SessionState.record_prologue_call("maria_santos", "Maria S.", SessionState.CALL_SUCCESS, 2200, "quoted")
	SessionState.detective_credibility = 90
	SessionState.reset_investigation()
	_check(SessionState.prologue_played, "the prologue still counts as played")
	_check(SessionState.get_call_record("maria_santos").size() > 0, "the call log survives into the investigation")
	_check(SessionState.get_victim_disposition("maria_santos") == SessionState.DISPOSITION_HARMED,
		"...so the victim's disposition is read")
	_check(SessionState.detective_credibility == 50, "the detective's own state starts fresh")
	SessionState.reset_session()
	_check(SessionState.get_call_record("maria_santos").is_empty(), "a fresh game from the menu clears it")
	_check(not SessionState.prologue_played, "...and the prologue no longer counts as played")
