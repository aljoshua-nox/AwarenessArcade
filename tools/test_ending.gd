extends Node

## Headless smoke test for the investigation ending screen.
##
##   godot --headless --path . res://tools/test_ending.tscn
##
## Exits 0 if every check passes, 1 otherwise. The ending had no coverage at
## all before the awareness verdict was folded into it.

const END_SCENE := "res://scenes/investigation/investigation_end.tscn"

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
		if not is_correct and miss_index < missed_names.size():
			tactic = str(missed_names[miss_index])
			miss_index += 1
		elif is_correct:
			tactic = "Read tactic %d" % i
		SessionState.record_tactic_read(is_correct, tactic)


func _run() -> void:
	print("\n--- investigation ending smoke test ---")
	await _test_tiers()
	await _test_verdict_reaches_the_ending()
	await _test_verdict_changes_with_awareness()
	await _test_missed_tactics_are_named()
	await _test_untested_and_midcase()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if failures.size() > 0 else 0)


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
