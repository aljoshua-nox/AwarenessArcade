extends Node

signal session_reset

# What actually happened on a call the player made in the prologue. These used
# to collapse into "success", "partial" and an empty string that meant four
# different things at once - hung up on you, ran out of time, got shut down, or
# was abandoned when the player ended the session. "She refused you" and "you
# never reached her" are opposite facts about a victim, and the investigation
# half needs to tell them apart.
const CALL_SUCCESS := "success"      # full transfer - money taken
const CALL_PARTIAL := "partial"      # partial transfer - money taken
const CALL_REFUSED := "refused"      # heard the pitch out, paid nothing
const CALL_HUNG_UP := "hung_up"      # bailed mid-call before it could land
const CALL_ESCALATED := "escalated"  # suspicion maxed, the line was shut down
const CALL_TIMEOUT := "timeout"      # the shift clock expired mid-call
const CALL_ABORTED := "aborted"      # the player ended the session mid-call

# How a victim carries that into the detective half. Derived, never stored, so
# there is exactly one place this mapping lives.
const DISPOSITION_HARMED := "harmed"          # you took their money
const DISPOSITION_RESISTANT := "resistant"    # they refused you, unharmed
const DISPOSITION_UNFINISHED := "unfinished"  # the call never resolved
const DISPOSITION_NEUTRAL := "neutral"        # you never called them at all

# Prologue (scam-call sim) state
var calls_made: int = 0
var victims_affected: int = 0
var reports_filed: int = 0
var profit: int = 0
var trust: int = 35
var suspicion: int = 10
var reputation: int = 75
var time_left: float = 240.0
var alerts: String = "No active alerts"
var community_alert_active: bool = false
var bank_security_active: bool = false
var investigation_notice_active: bool = false
var reflection_milestones: Array[Dictionary] = []
var prologue_end_reason: String = ""
var prologue_end_note: String = ""
# Who the player personally called while playing the scammer. Read back on the
# call floor in the office, so the operation's own ledger names their victims.
var prologue_call_log: Array[Dictionary] = []
# False on a skip-the-prologue run. Anything in the investigation that reads
# prologue history must stay playable when this is false.
var prologue_played: bool = false

# Investigation state (evidence inventory carried between interviews)
var investigation_inventory: Array[Dictionary] = []
var investigation_case_title: String = ""
var investigation_person_name: String = ""
var investigation_outcome: String = ""
var investigation_outcome_note: String = ""
var investigation_cooperation: int = 0
var investigation_evidence_misses: int = 0
var tactic_reads_correct: int = 0
var tactic_reads_total: int = 0
var detective_credibility: int = 50
var interviewed_people: Array[String] = []
var pending_case_path: String = ""
var urban_return_spawn: Vector2 = Vector2.ZERO
var has_urban_return_spawn: bool = false
var suspect_flipped: bool = false


func record_interview_outcome(person_id: String, outcome: String) -> void:
	if not interviewed_people.has(person_id):
		interviewed_people.append(person_id)
	if outcome == "success" or outcome == "whistleblower":
		detective_credibility = clampi(detective_credibility + 15, 0, 100)
	elif outcome == "partial":
		detective_credibility = clampi(detective_credibility + 5, 0, 100)
	elif outcome == "failure":
		detective_credibility = clampi(detective_credibility - 10, 0, 100)


func record_tactic_read(correct: bool) -> void:
	tactic_reads_total += 1
	if correct:
		tactic_reads_correct += 1
		detective_credibility = clampi(detective_credibility + 3, 0, 100)
	else:
		detective_credibility = clampi(detective_credibility - 3, 0, 100)


func add_evidence(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	if item_id.is_empty() or has_evidence(item_id):
		return
	investigation_inventory.append(item)


func has_evidence(item_id: String) -> bool:
	for item in investigation_inventory:
		if str(item.get("id", "")) == item_id:
			return true
	return false


func reset_prologue() -> void:
	calls_made = 0
	victims_affected = 0
	reports_filed = 0
	profit = 0
	trust = 35
	suspicion = 10
	reputation = 75
	time_left = 240.0
	alerts = "No active alerts"
	community_alert_active = false
	bank_security_active = false
	investigation_notice_active = false
	reflection_milestones.clear()
	prologue_end_reason = ""
	prologue_end_note = ""
	prologue_call_log.clear()
	prologue_played = false


func start_prologue() -> void:
	reset_prologue()
	prologue_played = true
	go_to_scene("res://scenes/prologue/prologue_call.tscn")


# The skip-the-prologue branch: drop straight into the detective half with no
# call history at all. Every victim then reads as DISPOSITION_NEUTRAL, so the
# investigation must always be winnable from this state - it is the baseline
# the prologue coupling varies away from, not a degraded mode.
func start_investigation_direct() -> void:
	reset_prologue()
	go_to_scene("res://scenes/exploration/urban_exterior.tscn")


func go_to_prologue_end(reason: String, note: String = "") -> void:
	prologue_end_reason = reason
	prologue_end_note = note
	go_to_scene("res://scenes/prologue/prologue_end.tscn")


func record_prologue_call(victim_name: String, outcome: String, payout: int) -> void:
	if victim_name.is_empty():
		return
	prologue_call_log.append({
		"name": victim_name,
		"outcome": outcome,
		"payout": payout,
	})


# The most recent call made to this victim, or {} if they were never called.
func get_call_record(victim_name: String) -> Dictionary:
	var found: Dictionary = {}
	for entry in prologue_call_log:
		if str(entry.get("name", "")) == victim_name:
			found = entry
	return found


# How this victim should open when the detective interviews them. A victim who
# was called more than once is judged by the worst thing that happened to them,
# not by the last call: money taken outranks a later refusal.
func get_victim_disposition(victim_name: String) -> String:
	if not prologue_played:
		return DISPOSITION_NEUTRAL
	var seen_resistant := false
	var seen_unfinished := false
	for entry in prologue_call_log:
		if str(entry.get("name", "")) != victim_name:
			continue
		var outcome := str(entry.get("outcome", ""))
		if outcome == CALL_SUCCESS or outcome == CALL_PARTIAL:
			return DISPOSITION_HARMED
		elif outcome == CALL_REFUSED or outcome == CALL_HUNG_UP:
			seen_resistant = true
		else:
			seen_unfinished = true
	if seen_resistant:
		return DISPOSITION_RESISTANT
	if seen_unfinished:
		return DISPOSITION_UNFINISHED
	return DISPOSITION_NEUTRAL


func record_reflection_milestone(milestone: String, detail: String = "") -> void:
	if milestone.is_empty():
		return
	for entry in reflection_milestones:
		if entry.get("title", "") == milestone:
			return
	reflection_milestones.append({
		"title": milestone,
		"detail": detail,
	})


func go_to_menu() -> void:
	go_to_scene("res://scenes/main_menu/main_menu.tscn")


func reset_session() -> void:
	has_urban_return_spawn = false
	suspect_flipped = false
	prologue_call_log.clear()
	prologue_played = false
	investigation_inventory.clear()
	investigation_case_title = ""
	investigation_person_name = ""
	investigation_outcome = ""
	investigation_outcome_note = ""
	investigation_cooperation = 0
	investigation_evidence_misses = 0
	tactic_reads_correct = 0
	tactic_reads_total = 0
	detective_credibility = 50
	interviewed_people.clear()
	pending_case_path = ""
	session_reset.emit()


func go_to_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)
