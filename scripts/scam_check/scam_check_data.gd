extends RefCounted

## The Scam Check's content and its record. The items live in
## resources/scam_check/scam_check.json; the numbered checks - which set went
## first and every answer - in SessionState.scam_check_path. The quiz scene, the
## main menu and the ending screen all read through here, so what counts as a
## right answer is decided in one place.
##
## A check is taken twice: one set before the game, the other after an ending.
## The first set alternates from one check to the next on the same computer, so
## across a playtest half the players meet each set first and a set that
## happens to be harder cannot pass for improvement.
##
## Not a class_name (see AGENTS.md) - preload it:
##     const ScamCheckData := preload("res://scripts/scam_check/scam_check_data.gd")

const CONTENT_PATH := "res://resources/scam_check/scam_check.json"
const SETS := ["A", "B"]
const CALL_SCAM := "scam"
const CALL_LEGIT := "legit"
const ROUTE_PROLOGUE := "prologue"
const ROUTE_SKIP := "skip"
const ROUTE_BOTH := "both"
const STATUS_COMPLETE := "complete"
const STATUS_WAITING := "waiting for the after check"
const STATUS_UNFINISHED := "unfinished"
const SECTION_PREFIX := "check_"

var content: Dictionary = {}
var record_path: String = ""


func _init() -> void:
	record_path = SessionState.scam_check_path
	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open the Scam Check: %s" % CONTENT_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		content = parsed
	else:
		push_error("The Scam Check is not a dictionary: %s" % CONTENT_PATH)


# --- Content -------------------------------------------------------------------

func items_in(set_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in content.get("items", []):
		if str(entry.get("set", "")) == set_id:
			out.append(entry)
	return out


func item(id: String) -> Dictionary:
	for entry in content.get("items", []):
		if str(entry.get("id", "")) == id:
			return entry
	return {}


# The same trick in the other set.
func twin(entry: Dictionary) -> Dictionary:
	var other := other_set(str(entry.get("set", "")))
	for candidate in items_in(other):
		if str(candidate.get("pair", "")) == str(entry.get("pair", "")):
			return candidate
	return {}


func report() -> Dictionary:
	return content.get("report", {})


static func other_set(set_id: String) -> String:
	return SETS[1] if set_id == SETS[0] else SETS[0]


# The tactic the chosen "what gave it away" option names, or "" for a
# distractor, no choice, or a legit item.
static func flag_tactic(entry: Dictionary, flag_index: int) -> String:
	var flags: Array = entry.get("flags", [])
	if flag_index < 0 or flag_index >= flags.size():
		return ""
	return str(flags[flag_index].get("tactic_id", ""))


# --- The record ------------------------------------------------------------------

func checks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var config := ConfigFile.new()
	if config.load(record_path) != OK:
		return out
	for section in config.get_sections():
		if not section.begins_with(SECTION_PREFIX):
			continue
		var check := {}
		for key in config.get_section_keys(section):
			check[key] = config.get_value(section, key)
		out.append(check)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("number", 0)) < int(b.get("number", 0)))
	return out


func check_number(number: int) -> Dictionary:
	for check in checks():
		if int(check.get("number", 0)) == number:
			return check
	return {}


static func is_complete(check: Dictionary) -> bool:
	return not (check.get("after", []) as Array).is_empty()


static func status(check: Dictionary) -> String:
	if is_complete(check):
		return STATUS_COMPLETE
	if bool(check.get("abandoned", false)):
		return STATUS_UNFINISHED
	return STATUS_WAITING


# The one check waiting for its after half: only ever the latest, since
# starting a new check closes the one before it.
func open_check() -> Dictionary:
	var all := checks()
	if all.is_empty():
		return {}
	var last: Dictionary = all.back()
	return last if status(last) == STATUS_WAITING else {}


func has_open_check() -> bool:
	return not open_check().is_empty()


func next_first_set() -> String:
	var all := checks()
	if all.is_empty():
		return SETS[0]
	return other_set(str(all.back().get("first_set", SETS[1])))


# Written only once the whole before check is answered, so a player who backs
# out halfway leaves nothing behind.
func save_before(first_set: String, answers: Array) -> int:
	abandon_open()
	var all := checks()
	var number := 1 if all.is_empty() else int(all.back().get("number", 0)) + 1
	var config := _load_config()
	var section := "%s%d" % [SECTION_PREFIX, number]
	config.set_value(section, "number", number)
	config.set_value(section, "first_set", first_set)
	config.set_value(section, "before", answers)
	config.set_value(section, "before_done", _now())
	config.set_value(section, "route", "")
	config.set_value(section, "endings", [])
	_save_config(config)
	return number


func save_after(answers: Array) -> Dictionary:
	var check := open_check()
	if check.is_empty():
		return {}
	var number := int(check.get("number", 0))
	_set_values(number, {"after": answers, "after_done": _now()})
	return check_number(number)


func abandon_open() -> void:
	var check := open_check()
	if not check.is_empty():
		_set_values(int(check.get("number", 0)), {"abandoned": true})


# How the game was played between the two halves: the prologue, straight to
# the investigation, or both. Only the menu calls this, so a test that starts
# the prologue directly never writes to a player's record.
func note_route(route: String) -> void:
	var check := open_check()
	if check.is_empty():
		return
	var current := str(check.get("route", ""))
	var next := route if current.is_empty() or current == route else ROUTE_BOTH
	_set_values(int(check.get("number", 0)), {"route": next})


func note_ending(outcome: String) -> void:
	var check := open_check()
	if check.is_empty() or outcome.is_empty():
		return
	var endings: Array = check.get("endings", []).duplicate()
	if endings.has(outcome):
		return
	endings.append(outcome)
	_set_values(int(check.get("number", 0)), {"endings": endings})


# Deletes the file, so a cleared record and a fresh install are the same state.
func clear() -> void:
	if FileAccess.file_exists(record_path) and DirAccess.remove_absolute(record_path) != OK:
		push_warning("Could not clear the Scam Check record at %s" % record_path)


func _load_config() -> ConfigFile:
	var config := ConfigFile.new()
	# A missing file is an empty record, not an error.
	config.load(record_path)
	return config


func _save_config(config: ConfigFile) -> void:
	if config.save(record_path) != OK:
		push_warning("Could not write the Scam Check record to %s" % record_path)


func _set_values(number: int, values: Dictionary) -> void:
	var config := _load_config()
	var section := "%s%d" % [SECTION_PREFIX, number]
	for key in values:
		config.set_value(section, key, values[key])
	_save_config(config)


static func _now() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute]


# --- Scoring ---------------------------------------------------------------------

# A scam spotted is a scam called a scam; a red flag named is a spotted scam
# whose chosen reason is one of its real tells. A legit message trusted is one
# called legit - the other side of the measure, so answering "scam" to
# everything scores half, not full.
func score(answers: Array) -> Dictionary:
	var result := {"answered": 0, "scams": 0, "scams_spotted": 0, "flags_named": 0,
		"legit": 0, "legit_trusted": 0, "right": 0, "false_alarms": 0}
	for answer in answers:
		var entry := item(str(answer.get("item", "")))
		if entry.is_empty():
			continue
		result.answered += 1
		var said_scam := str(answer.get("call", "")) == CALL_SCAM
		if bool(entry.get("scam", false)):
			result.scams += 1
			if said_scam:
				result.scams_spotted += 1
				if not flag_tactic(entry, int(answer.get("flag", -1))).is_empty():
					result.flags_named += 1
		else:
			result.legit += 1
			if not said_scam:
				result.legit_trusted += 1
	result.right = result.scams_spotted + result.legit_trusted
	result.false_alarms = result.legit - result.legit_trusted
	return result


static func answered_right(entry: Dictionary, answer: Dictionary) -> bool:
	var said_scam := str(answer.get("call", "")) == CALL_SCAM
	return said_scam == bool(entry.get("scam", false))


# Every tactic the scams in a set test, in the order they first appear. The
# validator holds the two sets to the same list.
func tactics_tested(set_id: String) -> Array[String]:
	var out: Array[String] = []
	for entry in items_in(set_id):
		for tactic in entry.get("tactic_ids", []):
			if not out.has(str(tactic)):
				out.append(str(tactic))
	return out


# For each tactic a set tests: how many of the scams using it were called
# scams, out of how many use it - {tactic_id: [caught, total]}. Counted by
# message rather than by the reason picked: most scams carry two tells, and a
# player who names one of them has not missed the other.
func tactic_catches(set_id: String, answers: Array) -> Dictionary:
	var by_item := _answers_by_item(answers)
	var out := {}
	for tactic in tactics_tested(set_id):
		out[tactic] = [0, 0]
	for entry in items_in(set_id):
		if not bool(entry.get("scam", false)):
			continue
		var caught := str(by_item.get(str(entry.get("id", "")), {}).get("call", "")) == CALL_SCAM
		for tactic in entry.get("tactic_ids", []):
			var tally: Array = out[str(tactic)]
			tally[1] += 1
			if caught:
				tally[0] += 1
	return out


# The matched pairs in the order the player met them before the game, each
# with the answer given to it: the same trick, before and after.
func pair_rows(check: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var first := str(check.get("first_set", SETS[0]))
	var before := _answers_by_item(check.get("before", []))
	var after := _answers_by_item(check.get("after", []))
	for entry in items_in(first):
		var other := twin(entry)
		rows.append({
			"before": entry, "before_answer": before.get(str(entry.get("id", "")), {}),
			"after": other, "after_answer": after.get(str(other.get("id", "")), {}),
		})
	return rows


static func _answers_by_item(answers: Array) -> Dictionary:
	var out := {}
	for answer in answers:
		out[str(answer.get("item", ""))] = answer
	return out


# --- Export ----------------------------------------------------------------------

# One row per check, for a facilitator to paste into a spreadsheet: the
# totals, then each message's result by its id, set A's then set B's.
func csv_header() -> PackedStringArray:
	var columns := PackedStringArray(["check", "status", "before_taken", "after_taken", "first_set",
		"played", "endings", "before_right", "before_scams_spotted", "before_real_trusted",
		"before_flags_named", "after_right", "after_scams_spotted", "after_real_trusted",
		"after_flags_named"])
	for set_id in SETS:
		for entry in items_in(set_id):
			columns.append(str(entry.get("id", "")))
	return columns


func csv_row(check: Dictionary) -> PackedStringArray:
	var before := score(check.get("before", []))
	var after := score(check.get("after", []))
	var has_after := is_complete(check)
	var row := PackedStringArray([
		str(check.get("number", "")), status(check), str(check.get("before_done", "")),
		str(check.get("after_done", "")), str(check.get("first_set", "")),
		str(check.get("route", "")), ";".join(PackedStringArray(check.get("endings", []))),
		str(before.right), str(before.scams_spotted), str(before.legit_trusted), str(before.flags_named),
		str(after.right) if has_after else "", str(after.scams_spotted) if has_after else "",
		str(after.legit_trusted) if has_after else "", str(after.flags_named) if has_after else "",
	])
	var answers := _answers_by_item(check.get("before", []))
	answers.merge(_answers_by_item(check.get("after", [])))
	for set_id in SETS:
		for entry in items_in(set_id):
			row.append(_result_word(entry, answers.get(str(entry.get("id", "")), {})))
	return row


func csv_text() -> String:
	var lines := PackedStringArray([",".join(csv_header())])
	for check in checks():
		lines.append(",".join(csv_row(check)))
	return "\n".join(lines)


static func _result_word(entry: Dictionary, answer: Dictionary) -> String:
	if answer.is_empty():
		return ""
	var said_scam := str(answer.get("call", "")) == CALL_SCAM
	if not bool(entry.get("scam", false)):
		return "false alarm" if said_scam else "trusted"
	if not said_scam:
		return "missed"
	return "spotted+named" if not flag_tactic(entry, int(answer.get("flag", -1))).is_empty() else "spotted"
