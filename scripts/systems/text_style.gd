extends RefCounted

## Shared text voices for every screen that mixes people talking with the case
## file talking. The rule the player learns: monospaced type is the case file,
## proportional type is a person.
##
## Callers pass plain prose - never put [color]/[font] tags in JSON content.
##
## Deliberately NOT a `class_name`: a global class is invisible until Godot
## rescans the project, so a fresh clone (or an editor that was already open)
## fails to parse every script referencing it. Consumers preload it instead:
##     const TextStyle := preload("res://scripts/systems/text_style.gd")

const FONT_SYSTEM := "res://assets/fonts/IBM_Plex_Mono/IBMPlexMono-Medium.ttf"

const COLOR_SPEECH := "f7f0e2"
const COLOR_NARRATION := "a7b0bb"
const COLOR_TACTIC := "e8b454"
const COLOR_CORRECT := "78d08b"
const COLOR_WRONG := "ff8368"
const COLOR_HINT := "79c6e8"

const MARK_TACTIC := "TACTIC IDENTIFIED"
const MARK_CORRECT := "TACTIC READ"
const MARK_WRONG := "MISREAD"
const MARK_HINT := "CASE NOTE"
const MARK_SCENE := "OBSERVED"
const MARK_HARM := "HARM ON RECORD"

static var _speech_regex: RegEx


static func _regex() -> RegEx:
	if _speech_regex == null:
		_speech_regex = RegEx.new()
		_speech_regex.compile("\"[^\"]*\"")
	return _speech_regex


## A person speaking: quoted speech is brightened, the stage direction around it
## stays dim, so the eye lands on the words actually said out loud.
static func dialogue(raw: String) -> String:
	if raw.is_empty():
		return raw
	var speech := _regex().sub(raw, "[color=#%s]$0[/color]" % COLOR_SPEECH, true)
	return "[color=#%s]%s[/color]" % [COLOR_NARRATION, speech]


## The case file speaking: monospaced and colour-coded, never mistakable for a
## line of dialogue.
static func system(marker: String, body: String, color: String) -> String:
	return "[font=%s][color=#%s][b]%s[/b]  %s[/color][/font]" % [FONT_SYSTEM, color, marker, body]
