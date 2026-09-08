extends Node

## Headless smoke test for the prologue call screen: the transcript's
## beat-by-beat reveal, and the consequence every call leaves behind.
##
##   godot --headless --path . res://tools/test_prologue.tscn
##
## The call box holds the whole conversation, so the typewriter has to reveal
## only the newly queued tail while the history stays put - and the choice
## buttons have to stay shut until the line the player is answering has
## actually arrived. Every call must also end by showing what it cost the person
## on the other end, and record that line for the investigation to quote back.
## Exits 0 if every check passes, 1 otherwise.

const PROLOGUE_SCENE := "res://scenes/prologue/prologue_call.tscn"
const DRAIN_TIMEOUT_MS := 8000

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
	var view: Node = load(PROLOGUE_SCENE).instantiate()
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


# The buttons are shuffled every node, so find one by what it does rather than
# by position.
func _choice_with_next(view: Node) -> int:
	var choices: Array = view.current_node.get("choices", [])
	for button_index in range(view.current_choice_indices.size()):
		var choice: Dictionary = choices[view.current_choice_indices[button_index]]
		if not str(choice.get("next_node", "")).is_empty():
			return button_index
	return -1


func _box(view: Node) -> String:
	return view.dialogue_value.text


func _run() -> void:
	print("\n--- prologue transcript reveal smoke test ---")

	await _test_opening_holds_the_prompt_back()
	await _test_choice_queues_one_beat_per_line()
	await _test_history_is_not_retyped()
	await _test_skip_drains_everything()
	await _test_ending_a_call_queues_its_summary()
	await _test_a_new_call_starts_a_new_transcript()
	await _test_every_call_outcome_has_a_cost()
	await _test_a_refused_call_is_recorded_and_shown()
	await _test_victim_rows_resolve_by_metadata()

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

	_check(view._is_revealing(), "the opening is still arriving, not already there")
	_check(view.pending_prompt, "the opening prompt is held behind the queued lines")
	_check(not view.current_prompt_text.is_empty(), "the node's prompt is loaded")
	_check(not _box(view).contains(view.current_prompt_text),
		"the prompt is not in the box while lines are still queued")
	_check(view.dialogue_value.visible_characters < view.dialogue_value.get_total_character_count(),
		"the box is withholding characters rather than showing everything")
	_check(view.choice_buttons[0].disabled, "choices are shut while the call is still opening")

	await _drain(view, "opening")

	_check(view.transcript_lines[0].begins_with("Selected target:"),
		"the target line landed first")
	_check(_box(view).contains(view.current_prompt_text),
		"the prompt lands last, once the lines ahead of it are read")
	_check(not view.pending_prompt, "the prompt is no longer pending")
	_check(view.dialogue_value.visible_characters == view.dialogue_value.get_total_character_count(),
		"everything queued is visible once the queue is empty")
	_check(not view.choice_buttons[0].disabled, "choices open once the prompt has arrived")
	await _close(view)


# The whole point of the change: a choice's reply is four separate beats (what
# the player said, what the victim said, how they reacted, what it cost), not
# one block joined with newlines.
func _test_choice_queues_one_beat_per_line() -> void:
	print("\n[answering a choice]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")

	var button_index := _choice_with_next(view)
	_check(button_index >= 0, "the opening node offers a choice that continues the call")
	var settled_lines: int = view.transcript_lines.size()
	view._on_choice_pressed(button_index)

	_check(view.pending_beats.size() + (view.transcript_lines.size() - settled_lines) >= 3,
		"the reply is queued as several beats, not one block")
	_check(view.pending_prompt, "the next prompt waits behind the reply")
	_check(not _box(view).contains(view.current_prompt_text),
		"the answered prompt leaves the box instead of sitting under its own reply")
	_check(view.choice_buttons[0].disabled, "choices are shut while the reply arrives")
	_check(view.choice_buttons[0].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"a shut choice button lets the click through so it can skip")

	await _drain(view, "reply")

	var arrived: Array[String] = []
	for i in range(settled_lines, view.transcript_lines.size()):
		arrived.append(view.transcript_lines[i])
	_check(arrived.size() >= 3, "each line of the reply is its own transcript beat")
	_check(arrived[arrived.size() - 1].begins_with("Outcome:"),
		"the outcome line lands last, after the conversation it summarises")
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
	var button_index := _choice_with_next(view)
	view._on_choice_pressed(button_index)
	await get_tree().process_frame

	# The box gets SHORTER here - the answered prompt leaves it before the reply
	# lands - so the read mark rebases downward rather than the text growing.
	_check(view.transcript_lines[0] == opening_line,
		"the opening line is still in the transcript, not cleared")
	_check(view.revealed_chars > 0,
		"the new beat types from a read mark inside the call, not from zero")
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

	var button_index := _choice_with_next(view)
	view._on_choice_pressed(button_index)
	_check(view._is_revealing(), "the reply is mid-flight before the skip")
	view._finish_reveal()

	_check(not view._is_revealing(), "skipping ends the reveal outright")
	_check(view.pending_beats.is_empty(), "nothing is left queued")
	_check(not view.pending_prompt, "the prompt is released by the skip")
	_check(_box(view).contains(view.current_prompt_text), "the prompt is in the box")
	_check(view.dialogue_value.visible_characters == view.dialogue_value.get_total_character_count(),
		"every skipped character is visible")
	_check(not view.choice_buttons[0].disabled, "choices open immediately after a skip")
	await _close(view)


func _test_ending_a_call_queues_its_summary() -> void:
	print("\n[ending a call]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")

	view._end_current_call("Call ended with no payout.", SessionState.CALL_REFUSED)
	_check(view._is_revealing(), "the closing line arrives as a beat, not instantly")
	_check(not view.call_active, "the call is closed")
	await _drain(view, "ending")

	_check(view.transcript_lines[view.transcript_lines.size() - 1] == "Call ended with no payout.",
		"the summary line is the last thing read")
	_check(view.choice_buttons[0].visible == false, "no choices are offered after the call ends")
	await _close(view)


func _test_a_new_call_starts_a_new_transcript() -> void:
	print("\n[a second call]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")
	var first_name := str(view.victims[0].get("name", ""))
	view._end_current_call("Call ended with no payout.", SessionState.CALL_REFUSED)
	await _drain(view, "ending")

	view._start_call(1)
	_check(not _box(view).contains(first_name),
		"the previous victim's call is cleared from the box")
	_check(view.revealed_chars <= view.dialogue_value.get_total_character_count(),
		"the read mark is rebased on the new transcript, not the old one")
	await _drain(view, "second opening")
	_check(_box(view).contains(str(view.victims[1].get("name", ""))),
		"the new target is named in the fresh transcript")
	await _close(view)


# The project's guardrail is that scam success must never read as pure power
# fantasy. A call used to end in silence unless money changed hands - and the
# lines written for every other outcome had never been reachable at all.
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

	# The writer's specific line beats the disposition fallback.
	var maria: Dictionary = view.victims[0]
	var pools: Dictionary = maria.get("perspective_variants", {})
	var success_line: String = view._pick_consequence_line(maria, SessionState.CALL_SUCCESS)
	var refused_line: String = view._pick_consequence_line(maria, SessionState.CALL_REFUSED)
	var timeout_line: String = view._pick_consequence_line(maria, SessionState.CALL_TIMEOUT)
	var success_pool: Array = pools.get("success", [])
	var resistant_pool: Array = pools.get("resistant", [])
	var unfinished_pool: Array = pools.get("unfinished", [])
	_check(success_pool.has(success_line), "a payout uses the outcome's own lines")
	_check(resistant_pool.has(refused_line), "a refusal falls back to the resistant lines")
	_check(unfinished_pool.has(timeout_line), "a call that never resolved falls back to unfinished")
	_check(success_line != refused_line,
		"a robbed victim and one who refused do not say the same thing")
	_check(view._pick_consequence_line(maria, "").is_empty(), "an unknown outcome claims nothing")
	await _close(view)


func _test_a_refused_call_is_recorded_and_shown() -> void:
	print("\n[a refused call]")
	var view := await _open()
	view._start_call(0)
	await _drain(view, "opening")
	var person_id: String = str(view.victims[0].get("person_id", ""))

	view._end_current_call("Call ended with no payout.", SessionState.CALL_REFUSED)
	await _drain(view, "ending")

	var record: Dictionary = SessionState.get_call_record(person_id)
	var recorded: String = str(record.get("consequence", ""))
	_check(str(record.get("outcome", "")) == SessionState.CALL_REFUSED,
		"the refusal is logged as a refusal, not a payout")
	_check(not recorded.is_empty(),
		"the call record carries what the call cost them, for the investigation to quote")
	_check(_box(view).contains("Victim Perspective"),
		"a refused call still shows the victim's perspective")
	_check(_box(view).contains(recorded), "the line shown is the line recorded")
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
		# The row's own text has to name the victim the row resolves to.
		if not view.victim_list.get_item_text(row).begins_with(
				str(view.victims[index].get("name", ""))):
			mismatched += 1
	_check(mismatched == 0, "every row resolves to the victim it names (%d wrong)" % mismatched)
	_check(view._victim_index_for_row(-1) == -1, "a row below the list resolves to nothing")
	_check(view._victim_index_for_row(view.victim_list.item_count) == -1,
		"a row past the end resolves to nothing")

	# Selecting a row has to preview that row's victim, through the same path
	# the signal uses.
	var last_row: int = view.victim_list.item_count - 1
	view._on_victim_selected(last_row)
	_check(view.preview_victim_index == view._victim_index_for_row(last_row),
		"selecting a row previews the victim that row names")
	await _close(view)
