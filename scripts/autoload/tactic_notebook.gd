extends Node

## The tactic catalogue.
##
## Every manipulation tactic in this game used to appear once and scroll away.
## The only durable record was a number on the end-of-case scorecard, which is a
## score rather than the content. What a player should leave holding is a list of
## red flags they could recognize on a real phone call, so that list has a home.
##
## This autoload owns the catalogue - what the tactics are - and answers what has
## been collected. The screen they are read on is the Tactics tab of the case
## journal (`CaseJournal`), which used to be this file's own overlay before the
## detective had anything else to carry.

const CATALOGUE_PATH := "res://resources/tactics/tactic_catalogue.json"

var tactics: Array[Dictionary] = []


func _ready() -> void:
	_load_catalogue()


func _load_catalogue() -> void:
	var file := FileAccess.open(CATALOGUE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open tactic catalogue: %s" % CATALOGUE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Tactic catalogue is not a dictionary")
		return
	for entry in (parsed as Dictionary).get("tactics", []):
		if entry is Dictionary:
			tactics.append(entry)


func has_tactic(tactic_id: String) -> bool:
	for entry in tactics:
		if str(entry.get("id", "")) == tactic_id:
			return true
	return false


func learned_count() -> int:
	var found := 0
	for entry in tactics:
		if SessionState.has_learned_tactic(str(entry.get("id", ""))):
			found += 1
	return found
