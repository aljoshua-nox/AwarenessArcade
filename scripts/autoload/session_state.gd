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

# How well the player read the manipulation across the whole session. This is
# folded into the ending: the case is closed by evidence, but whether the player
# leaves able to recognise the next scam is a separate question, and the game
# should answer it out loud.
const AWARENESS_SHARP := "sharp"        # named every tactic put in front of them
const AWARENESS_MIXED := "mixed"        # named some
const AWARENESS_BLIND := "blind"        # named none
const AWARENESS_UNTESTED := "untested"  # never reached a tactic quiz

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
# Every tactic quiz answered, as {"tactic": String, "correct": bool}. The
# counters are the score; this is what was actually missed, which is the part
# worth naming back to the player at the end.
var tactic_reads: Array[Dictionary] = []
# Tactics the player has collected in the notebook, as
# {"id": String, "context": String}. The context records where they met it, so
# the notebook can say when it was learned rather than only that it was.
var tactics_learned: Array[Dictionary] = []
var detective_credibility: int = 50
var interviewed_people: Array[String] = []
var pending_case_path: String = ""
var urban_return_spawn: Vector2 = Vector2.ZERO
var has_urban_return_spawn: bool = false
var suspect_flipped: bool = false
# Set when an interview ends on a node marked `locks_case`. Losing Marco means
# nobody will ever name the floor above him, so the confrontation can never
# happen - without this the player simply wanders a street with nothing left to
# do and no ending. The street offers to file the case unresolved instead.
var case_locked: bool = false


func record_interview_outcome(person_id: String, outcome: String) -> void:
	if not interviewed_people.has(person_id):
		interviewed_people.append(person_id)
	if outcome == "success" or outcome == "whistleblower":
		detective_credibility = clampi(detective_credibility + 15, 0, 100)
	elif outcome == "partial":
		detective_credibility = clampi(detective_credibility + 5, 0, 100)
	elif outcome == "failure":
		detective_credibility = clampi(detective_credibility - 10, 0, 100)


func record_tactic_read(correct: bool, tactic: String = "") -> void:
	tactic_reads_total += 1
	tactic_reads.append({"tactic": tactic, "correct": correct})
	if correct:
		tactic_reads_correct += 1
		detective_credibility = clampi(detective_credibility + 3, 0, 100)
	else:
		detective_credibility = clampi(detective_credibility - 3, 0, 100)


# The tactics the player got wrong, in the order they met them, de-duplicated
# so a retried interview does not list the same miss twice.
func get_missed_tactics() -> Array[String]:
	var missed: Array[String] = []
	var named := {}
	for entry in tactic_reads:
		var tactic := str(entry.get("tactic", ""))
		if tactic.is_empty() or bool(entry.get("correct", false)):
			continue
		if named.has(tactic):
			continue
		named[tactic] = true
		missed.append(tactic)
	return missed


# Collected once. Meeting the same tactic again keeps the first context, which
# is the moment it was actually learned.
func record_tactic_learned(tactic_id: String, context: String = "") -> void:
	if tactic_id.is_empty() or has_learned_tactic(tactic_id):
		return
	tactics_learned.append({"id": tactic_id, "context": context})


func has_learned_tactic(tactic_id: String) -> bool:
	for entry in tactics_learned:
		if str(entry.get("id", "")) == tactic_id:
			return true
	return false


func get_learned_tactic(tactic_id: String) -> Dictionary:
	for entry in tactics_learned:
		if str(entry.get("id", "")) == tactic_id:
			return entry
	return {}


func get_awareness_tier() -> String:
	if tactic_reads_total <= 0:
		return AWARENESS_UNTESTED
	if tactic_reads_correct >= tactic_reads_total:
		return AWARENESS_SHARP
	if tactic_reads_correct <= 0:
		return AWARENESS_BLIND
	return AWARENESS_MIXED


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


# `person_id` is the identity that survives across the two halves and is what
# the investigation must key off; `victim_name` is only what the office ledger
# prints. They deliberately differ per character, so they are stored separately.
func record_prologue_call(person_id: String, victim_name: String, outcome: String, payout: int) -> void:
	if victim_name.is_empty():
		return
	prologue_call_log.append({
		"person_id": person_id,
		"name": victim_name,
		"outcome": outcome,
		"payout": payout,
	})


# The most recent call made to this victim, or {} if they were never called.
# Keyed on person_id, never on the display name: the prologue calls her
# "Maria S." and her case file calls her "Maria Santos", so a name lookup
# silently returns nothing instead of failing loudly.
func get_call_record(person_id: String) -> Dictionary:
	if person_id.is_empty():
		return {}
	var found: Dictionary = {}
	for entry in prologue_call_log:
		if str(entry.get("person_id", "")) == person_id:
			found = entry
	return found


# How this victim should open when the detective interviews them. A victim who
# was called more than once is judged by the worst thing that happened to them,
# not by the last call: money taken outranks a later refusal.
func get_victim_disposition(person_id: String) -> String:
	if not prologue_played or person_id.is_empty():
		return DISPOSITION_NEUTRAL
	var seen_resistant := false
	var seen_unfinished := false
	for entry in prologue_call_log:
		if str(entry.get("person_id", "")) != person_id:
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
	case_locked = false
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
	tactic_reads.clear()
	tactics_learned.clear()
	detective_credibility = 50
	interviewed_people.clear()
	pending_case_path = ""
	session_reset.emit()


func go_to_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)
