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
## The victim speaking after the call is over, to somebody who is not the
## player. Warm like speech, because it is speech, but clearly not the cream of
## a live line in the transcript.
const COLOR_AFTERMATH := "e8a894"

const FONT_SPEECH_ITALIC := "res://assets/fonts/IBM_Plex_Sans/IBMPlexSans-Italic-VariableFont_wdth,wght.ttf"

const MARK_TACTIC := "TACTIC IDENTIFIED"
const MARK_CORRECT := "TACTIC READ"
const MARK_WRONG := "MISREAD"
const MARK_HINT := "CASE NOTE"
const MARK_SCENE := "OBSERVED"
const MARK_HARM := "HARM ON RECORD"
## A specific, checkable assertion the suspect has just made.
const MARK_CLAIM := "CLAIM ON RECORD"
## That assertion failing against something the player is carrying.
const MARK_CONTRADICTION := "CONTRADICTION"
## The prologue's call floor talking: the line connecting, the tactic the player
## just used being named, the call closing, a report landing, and the victim's
## own words afterwards.
const MARK_DIALING := "DIALING"
const MARK_TACTIC_USED := "TACTIC USED"
const MARK_CALL_ENDED := "CALL ENDED"
const MARK_REPORTED := "REPORTED"
## What the call cost the person on the other end, in their own words. Kept as
## flat a timestamp as the four markers around it - the floor's own log format
## carrying a sentence the floor would never write is the point, and the styling
## below (aftermath()) is what tells the reader this is not the call.
const MARK_AFTERMATH := "AFTER THE CALL"

static var _speech_regex: RegEx


## Money, the way every screen prints it: "P18,500". The prologue, its summary
## and the office ledger all show the same payouts, so they share one formatter.
static func currency(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return "%sP%s" % ["-" if amount < 0 else "", out]


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


## A victim speaking after the call has ended - the one line in the prologue
## transcript that is not the call. Italic and its own warm tone, so it reads as
## something said later and elsewhere rather than another line on the phone.
static func aftermath(raw: String) -> String:
	if raw.is_empty():
		return raw
	return "[font=%s][color=#%s]%s[/color][/font]" % [FONT_SPEECH_ITALIC, COLOR_AFTERMATH, raw]


## The case file speaking: monospaced and color-coded, never mistakable for a
## line of dialogue.
static func system(marker: String, body: String, color: String) -> String:
	return "[font=%s][color=#%s][b]%s[/b]  %s[/color][/font]" % [FONT_SYSTEM, color, marker, body]
