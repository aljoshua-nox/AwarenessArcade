extends Node

signal session_reset
signal case_resolved(result: Dictionary)

var cases_reviewed: int = 0
var victims_protected: int = 0
var failed_interventions: int = 0
var alert_level: int = 0
var evidence_linked: int = 0
var current_case: Dictionary = {}
var last_result: Dictionary = {}
var resolution_history: Array = []

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


func start_prologue() -> void:
	reset_prologue()
	go_to_scene("res://scenes/prologue/prologue_call.tscn")


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
	cases_reviewed = 0
	victims_protected = 0
	failed_interventions = 0
	alert_level = 0
	evidence_linked = 0
	current_case = {}
	last_result = {}
	resolution_history.clear()
	has_urban_return_spawn = false
	suspect_flipped = false
	prologue_call_log.clear()
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


func start_case(case_data: Dictionary) -> void:
	current_case = case_data


func register_evidence_linked(count: int = 1) -> void:
	evidence_linked += count


func resolve_case(result: Dictionary) -> void:
	cases_reviewed += 1
	last_result = result

	if result.get("protected", false):
		victims_protected += 1
	else:
		failed_interventions += 1

	alert_level = clamp(alert_level + int(result.get("alert_delta", 0)), 0, 10)
	resolution_history.append(result)
	case_resolved.emit(result)


func go_to_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)
