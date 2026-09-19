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
const CALL_ESCALATED := "escalated"  # the line was pulled mid-call (kept in the vocabulary; the ledger prints it)
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
# leaves able to recognize the next scam is a separate question, and the game
# should answer it out loud.
const AWARENESS_SHARP := "sharp"        # named every tactic put in front of them
const AWARENESS_MIXED := "mixed"        # named some
const AWARENESS_BLIND := "blind"        # named none
const AWARENESS_UNTESTED := "untested"  # never reached a tactic quiz

# The operation's outgoing line. It is world fact rather than session state, but
# it lives here because two scenes have to print the SAME string: the street
# (a community notice and two residents citing it) and the call floor's own
# ledger. The player is meant to notice the repetition unprompted, which only
# works if there is one copy of it.
const OPERATION_NUMBER := "0917-555-0142"

# The second district's version of the same trick. The company that owns the
# floors is named on the tower the player cannot get past the lobby of, on the
# hoarding of the site down the road, and - once the boss exists - on the call
# floor's own bonus board. Same rule: one copy, and nothing points it out.
const COMPANY_NAME := "VALDERRAMA HOLDINGS"

# The prologue's only session-level pressure besides the shift clock. A victim
# who catches on and keeps the number files a report; this many and the floor
# pulls the line. The old trust/suspicion/reputation meters lived here - they
# were session-wide numbers that a per-call conversation could not honestly
# move, which is why the text and the bars disagreed.
const REPORTS_TO_PULL_LINE := 3

# Prologue (scam-call sim) state
var calls_made: int = 0
var victims_affected: int = 0
var reports_filed: int = 0
# Money taken across the shift. Never shown as a running score during play -
# the summary reports it as the victims' losses.
var profit: int = 0
var time_left: float = 240.0
# Catalogue tactic ids the player used on the calls, in first-use order.
# Recorded for the summary; deliberately does NOT unlock the notebook - the
# investigation is where a tactic is named, the prologue is where it is used.
var prologue_tactics_used: Array[String] = []
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
# How each interview last ended, by person_id - the outcome, or "hesitant" for
# a refusal at the door for want of standing. The journal's People page reads
# it; the doors and the credit rules above do not.
const OUTCOME_HESITANT := "hesitant"
var interview_outcomes: Dictionary = {}

# The investigation's pressure. The prologue has a four-minute shift; the
# investigation has a case with this many statements in it. A victim or a
# witness costs one when their interview reaches an ending - not when they
# refuse at the door for want of standing - and the suspects and directors
# cost nothing: they are the payoff, and the player is already in the
# building. When it is spent, the case has to move with what it has; if what
# it has cannot flip Marco, his lawyered ending is the lockout that closes it.
const STATEMENT_BUDGET := 6
const STATEMENT_ROLES := ["Victim", "Witness"]
var statements_taken: int = 0
# A witness whose interview failed is closed for good. The endings already say
# so - "you will not get to see it again" - and the map now agrees.
var closed_witnesses: Array[String] = []
# Credibility an ending has already paid, per person, so a second visit cannot
# farm it. A partial then a success still nets the full success.
var interview_credit: Dictionary = {}
var pending_case_path: String = ""
var urban_return_spawn: Vector2 = Vector2.ZERO
var has_urban_return_spawn: bool = false
# Which street the player left from. There is more than one now, and the
# interview's "Return to the Street" has to go back to the one with the door
# they walked in through, not always the terrace. Set alongside the spawn.
const DEFAULT_STREET_SCENE := "res://scenes/exploration/urban_exterior.tscn"
# Where the case starts: the detective's desk, whose door is on that street.
const DESK_SCENE := "res://scenes/exploration/detective_office.tscn"
var urban_return_scene: String = DEFAULT_STREET_SCENE
# Coming down the office stairs lands in front of them, not at the street door.
var office_return_spawn: Vector2 = Vector2.ZERO
var has_office_return_spawn: bool = false
var suspect_flipped: bool = false
# The second floor's equivalent: a witness who works there and has agreed to
# say so. Set by Bea's `turned` outcome; it is what opens Rowena's door, the
# way suspect_flipped opens Elena's.
var witness_flipped: bool = false
# Set when an interview ends on a node marked `locks_case`. Losing Marco means
# nobody will ever name the floor above him, so the confrontation can never
# happen - without this the player simply wanders a street with nothing left to
# do and no ending. The street offers to file the case unresolved instead.
var case_locked: bool = false
# The detective's tools, picked up at the desk the case starts at. The journal
# (and its J key and corner button) exists once the case file is taken; the
# Tactics tab (and N) once the notebook is. The desk's door will not open
# until both are, so outside that room these are always true.
var journal_collected: bool = false
var notebook_collected: bool = false
# Objectives the journal has seen completed. Every condition an objective can
# complete on is monotonic except standing, which a failed interview lowers -
# so without this, "earn the standing" would reopen every time standing dipped
# under its gate after the doors it was about had already been walked through.
# Done is done.
var objectives_done: Array[String] = []
# The briefing is shown once, on arrival. Set by the two ways into the
# investigation and consumed by the first scene that can show it, so a scene
# instantiated on its own (a test, a render pass) never opens it unasked.
var briefing_pending: bool = false


func record_interview_outcome(person_id: String, outcome: String, hesitant: bool = false) -> void:
	if not interviewed_people.has(person_id):
		interviewed_people.append(person_id)
	interview_outcomes[person_id] = OUTCOME_HESITANT if hesitant else outcome
	var gain := 0
	if outcome == "success" or outcome == "whistleblower" or outcome == "turned" or outcome == "owner_named":
		gain = 15
	elif outcome == "partial":
		gain = 5
	if gain > 0:
		# Paid once per person: the best ending they have given, not every visit.
		var already := int(interview_credit.get(person_id, 0))
		if gain > already:
			detective_credibility = clampi(detective_credibility + (gain - already), 0, 100)
			interview_credit[person_id] = gain
	elif outcome == "failure":
		detective_credibility = clampi(detective_credibility - 10, 0, 100)


# A witness interview that reached an ending spends a statement, and one that
# failed closes the witness. A hesitant refusal at the door is neither.
func record_statement(person_id: String, role: String, outcome: String, hesitant: bool) -> void:
	if not STATEMENT_ROLES.has(role) or hesitant:
		return
	statements_taken += 1
	if outcome == "failure" and not closed_witnesses.has(person_id):
		closed_witnesses.append(person_id)


func statements_left() -> int:
	return maxi(0, STATEMENT_BUDGET - statements_taken)


func is_witness_closed(person_id: String) -> bool:
	return closed_witnesses.has(person_id)


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
	AudioManager.play_sfx("pen")


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
	time_left = 240.0
	prologue_tactics_used.clear()
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
	briefing_pending = true
	go_to_scene(DESK_SCENE)


# Continue from the prologue summary into the detective half. The investigation
# starts clean, but the call log is the whole point of having played the
# prologue and must survive - this used to call reset_session(), which wiped
# it, so the coupling only ever worked in tests that seeded the log afterwards.
func start_investigation_from_prologue() -> void:
	reset_investigation()
	briefing_pending = true
	go_to_scene(DESK_SCENE)


func record_tactic_used(tactic_id: String) -> void:
	if tactic_id.is_empty() or prologue_tactics_used.has(tactic_id):
		return
	prologue_tactics_used.append(tactic_id)


func go_to_prologue_end(reason: String, note: String = "") -> void:
	prologue_end_reason = reason
	prologue_end_note = note
	go_to_scene("res://scenes/prologue/prologue_end.tscn")


# `person_id` is the identity that survives across the two halves and is what
# the investigation must key off; `victim_name` is only what the office ledger
# prints. They deliberately differ per character, so they are stored separately.
# `consequence` is the victim's own words about what that call did to them,
# picked in the prologue and carried here so the investigation can quote the
# specific harm back rather than describing it in general terms.
func record_prologue_call(person_id: String, victim_name: String, outcome: String, payout: int,
		consequence: String = "") -> void:
	if victim_name.is_empty():
		return
	prologue_call_log.append({
		"person_id": person_id,
		"name": victim_name,
		"outcome": outcome,
		"payout": payout,
		"consequence": consequence,
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


# What one call outcome did to the person on the other end. The single place
# that mapping lives: get_victim_disposition() folds a whole call history down
# with it, and the prologue uses it to pick which perspective line a victim
# gives when the call ends. Anything not explicitly harmful or refused is a call
# that never resolved - the victim was left not knowing what it was.
func disposition_for_outcome(outcome: String) -> String:
	if outcome == CALL_SUCCESS or outcome == CALL_PARTIAL:
		return DISPOSITION_HARMED
	if outcome == CALL_REFUSED or outcome == CALL_HUNG_UP:
		return DISPOSITION_RESISTANT
	return DISPOSITION_UNFINISHED


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
		var mapped := disposition_for_outcome(str(entry.get("outcome", "")))
		if mapped == DISPOSITION_HARMED:
			return DISPOSITION_HARMED
		elif mapped == DISPOSITION_RESISTANT:
			seen_resistant = true
		else:
			seen_unfinished = true
	if seen_resistant:
		return DISPOSITION_RESISTANT
	if seen_unfinished:
		return DISPOSITION_UNFINISHED
	return DISPOSITION_NEUTRAL


func has_reflection_milestone(title: String) -> bool:
	if title.is_empty():
		return false
	for entry in reflection_milestones:
		if str(entry.get("title", "")) == title:
			return true
	return false


func record_reflection_milestone(milestone: String, detail: String = "") -> void:
	if milestone.is_empty() or has_reflection_milestone(milestone):
		return
	reflection_milestones.append({
		"title": milestone,
		"detail": detail,
	})
	AudioManager.play_sfx("pen")


func go_to_menu() -> void:
	go_to_scene("res://scenes/main_menu/main_menu.tscn")


# Everything, for a fresh game from the menu.
func reset_session() -> void:
	prologue_call_log.clear()
	prologue_played = false
	reset_investigation()


# The detective half only. Leaves the prologue's call history alone.
func reset_investigation() -> void:
	has_urban_return_spawn = false
	urban_return_scene = DEFAULT_STREET_SCENE
	has_office_return_spawn = false
	suspect_flipped = false
	witness_flipped = false
	case_locked = false
	journal_collected = false
	notebook_collected = false
	objectives_done.clear()
	briefing_pending = false
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
	interview_outcomes.clear()
	statements_taken = 0
	closed_witnesses.clear()
	interview_credit.clear()
	pending_case_path = ""
	session_reset.emit()


func go_to_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)
