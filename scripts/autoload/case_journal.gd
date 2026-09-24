extends Node

## The case journal: the one overlay the detective carries, and the pause menu.
##
## The tactic notebook used to be the only overlay - a corner button, a
## full-screen panel, the game paused beneath it. That frame is the right shape
## for everything the detective holds, so it is one overlay with tabs now, and
## the notebook is its Tactics tab. `TacticNotebook` keeps the catalogue; this
## owns the screen. Tabs are registered in TABS and filled by `_fill_<id>()`.
##
## Built as an autoload rather than a scene so it is reachable from the street,
## an interview and the office alike, without any of those scenes needing to
## know it exists. It is the detective's, so it is not offered on the call
## floor: the scammer carries nothing into the prologue, and the notebook that
## used to show there had every entry locked.
##
## It also owns the pause menu. Esc on a street or a floor used to go straight
## to the main menu, which resets the session - one mis-press abandoned the
## run with no confirm. The scenes call `open_pause()` instead and the menu asks.

## Preloaded rather than referenced as a global class - see text_style.gd.
const TextStyle := preload("res://scripts/systems/text_style.gd")

const JOURNAL_ACTION := "toggle_journal"
const NOTEBOOK_ACTION := "toggle_notebook"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
## The menu is not part of the fiction, and the prologue is the scammer's half.
const HIDDEN_IN_SCENES := [
	"res://scenes/main_menu/disclaimer.tscn",
	MAIN_MENU_SCENE,
	"res://scenes/main_menu/credits.tscn",
	"res://scenes/prologue/prologue_call.tscn",
	"res://scenes/prologue/prologue_end.tscn",
]

const BRIEFING_PATH := "res://resources/journal/briefing.json"
const OBJECTIVES_PATH := "res://resources/journal/objectives.json"

const TAB_OBJECTIVES := "objectives"
const TAB_BRIEF := "brief"
const TAB_PEOPLE := "people"
const TAB_EVIDENCE := "evidence"
const TAB_TACTICS := "tactics"
## One row per tab, in display order. The id names the `_fill_<id>()` that
## renders it into its page. The brief has a tab of its own rather than a
## place above the objectives: it is read once, and the objectives are what
## the player opens the journal for after that.
const TABS := [
	{"id": TAB_OBJECTIVES, "label": "Objectives  (J)"},
	{"id": TAB_BRIEF, "label": "Brief"},
	{"id": TAB_PEOPLE, "label": "People"},
	{"id": TAB_EVIDENCE, "label": "Evidence"},
	{"id": TAB_TACTICS, "label": "Tactics  (N)"},
]

## The desk sergeant's brief: who the player is and what a statement is for.
## Loaded from JSON so the validator can lint it like any other prose.
var briefing: Dictionary = {}
## The case's objectives, in file order - see the Objectives section below.
var objectives: Array[Dictionary] = []

var is_open: bool = false
var is_pause_open: bool = false
var current_tab: String = ""

var layer: CanvasLayer
var open_button: Button
var panel_root: Control
var tab_buttons: Dictionary = {}
var tab_pages: Dictionary = {}
# The Tactics tab's rows and count.
var entries_box: VBoxContainer
var progress_label: Label

var pause_root: Control
var pause_buttons: VBoxContainer
var sound_button: Button
var journal_button: Button
var notebook_button: Button
var confirm_box: VBoxContainer


func _ready() -> void:
	# Must keep running while the tree is paused, or the overlay could not be
	# closed again once it has paused the game beneath it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_briefing()
	_load_objectives()
	# Connected before the overlay is built, so its own buttons click too.
	get_tree().node_added.connect(_on_node_added)
	_build_ui()
	_build_pause_menu()
	_refresh_button_visibility.call_deferred()


# --- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	open_button = Button.new()
	open_button.text = "Journal  (J)"
	open_button.custom_minimum_size = Vector2(150, 34)
	open_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	open_button.position = Vector2(-166, 12)
	open_button.pressed.connect(toggle)
	layer.add_child(open_button)

	panel_root = Control.new()
	panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_root.visible = false
	layer.add_child(panel_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_root.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 48)
	panel_root.add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)

	var inner := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		inner.add_theme_constant_override(side, 20)
	panel.add_child(inner)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	inner.add_child(column)

	var title := Label.new()
	title.text = "Case Journal"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	column.add_child(tab_row)

	# Each tab is a page of its own so switching is a visibility flip, and the
	# page that is open is the only one rebuilt.
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(pages)

	var group := ButtonGroup.new()
	for tab in TABS:
		var tab_id := str(tab.get("id", ""))
		var button := Button.new()
		button.text = str(tab.get("label", tab_id))
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(150, 34)
		button.pressed.connect(_on_tab_pressed.bind(tab_id))
		button.set_meta("silent", true)
		tab_row.add_child(button)
		tab_buttons[tab_id] = button

		var page := VBoxContainer.new()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.add_theme_constant_override("separation", 10)
		page.visible = false
		pages.add_child(page)
		tab_pages[tab_id] = page

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(160, 40)
	close_button.pressed.connect(close)
	column.add_child(close_button)


## A page's scrolling body. Variable-length content in a fixed-height panel
## has to scroll, or entries below the fold become unreachable as a list grows.
func _add_scrolling_box(page: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	return box


func _add_note(page: VBoxContainer, text: String) -> Label:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)
	return note


func _clear_page(page: VBoxContainer) -> void:
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()


func _on_tab_pressed(tab_id: String) -> void:
	AudioManager.play_sfx("tab")
	_select_tab(tab_id)


func _select_tab(tab_id: String) -> void:
	if not tab_pages.has(tab_id):
		return
	current_tab = tab_id
	for id in tab_pages.keys():
		(tab_pages[id] as Control).visible = id == tab_id
		(tab_buttons[id] as Button).set_pressed_no_signal(id == tab_id)
	_rebuild_tab(tab_id)


func _rebuild_tab(tab_id: String) -> void:
	var page: VBoxContainer = tab_pages.get(tab_id)
	if page == null:
		return
	_clear_page(page)
	var filler := "_fill_%s" % tab_id
	if has_method(filler):
		call(filler, page)


# --- The case file ------------------------------------------------------------

func _load_briefing() -> void:
	var file := FileAccess.open(BRIEFING_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open briefing: %s" % BRIEFING_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Briefing is not a dictionary")
		return
	briefing = parsed


## `{statements}` is the budget, expanded here so the brief cannot drift from
## the number the HUD prints. The number and the company name are deliberately
## NOT expandable in the brief: noticing them is the street's mechanic.
func _expand_tokens(text: String) -> String:
	return text.replace("{statements}", str(SessionState.STATEMENT_BUDGET))


## The brief as bbcode. The header is the case file talking (monospaced, the
## CASE NOTE color); the sergeant's paragraphs are a person writing.
func briefing_text() -> String:
	if briefing.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append(TextStyle.system("CASE FILE %s" % str(briefing.get("case_number", "")),
		str(briefing.get("subject", "")), TextStyle.COLOR_HINT))
	lines.append("[color=#%s]To: %s\nFrom: %s[/color]" % [TextStyle.COLOR_NARRATION,
		str(briefing.get("to", "")), str(briefing.get("from", ""))])
	for paragraph in briefing.get("paragraphs", []):
		lines.append(_expand_tokens(str(paragraph)))
	# Only when the player worked the shift and someone on it kept the number.
	if SessionState.prologue_played and SessionState.reports_filed > 0:
		lines.append("[i]%s[/i]" % _expand_tokens(str(briefing.get("prologue_note", ""))))
	lines.append("[color=#%s]%s[/color]" % [TextStyle.COLOR_HINT, _expand_tokens(str(briefing.get("closing", "")))])
	return "\n\n".join(lines)


func _fill_brief(page: VBoxContainer) -> void:
	var box := _add_scrolling_box(page)
	var brief := RichTextLabel.new()
	brief.bbcode_enabled = true
	brief.fit_content = true
	brief.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief.text = briefing_text()
	box.add_child(brief)


## The brief, on arrival: the journal opens on it.
func show_briefing() -> void:
	open(TAB_BRIEF)


# --- Objectives ---------------------------------------------------------------
# What to do next, without saying how. An objective is a row in
# resources/journal/objectives.json with an `unlock_when` (absent = open from
# the start), a `complete_when`, and optionally a `failed_when`; each is one
# condition or `{"any": [...]}`. Conditions are a closed vocabulary read off
# SessionState - see _condition_holds() - and the validator checks every id.

const OBJECTIVE_LOCKED := "locked"
const OBJECTIVE_ACTIVE := "active"
const OBJECTIVE_DONE := "done"
const OBJECTIVE_FAILED := "failed"


func _load_objectives() -> void:
	var file := FileAccess.open(OBJECTIVES_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open objectives: %s" % OBJECTIVES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Objectives file is not a dictionary")
		return
	for entry in (parsed as Dictionary).get("objectives", []):
		if entry is Dictionary:
			objectives.append(entry)


func _condition_holds(condition: Variant) -> bool:
	if condition == null:
		return true
	if not condition is Dictionary:
		return false
	var c: Dictionary = condition
	if c.has("any"):
		for option in c.get("any", []):
			if _condition_holds(option):
				return true
		return false
	if c.has("statements_at_least"):
		return SessionState.statements_taken >= int(c["statements_at_least"])
	if c.has("credibility_at_least"):
		return SessionState.detective_credibility >= int(c["credibility_at_least"])
	if c.has("interviewed"):
		return SessionState.interviewed_people.has(str(c["interviewed"]))
	if c.has("flag"):
		var value: Variant = SessionState.get(str(c["flag"]))
		return value is bool and value
	if c.has("case_stuck"):
		return SessionState.case_stuck() == bool(c["case_stuck"])
	if c.has("evidence"):
		return SessionState.has_evidence(str(c["evidence"]))
	if c.has("milestone"):
		return SessionState.has_reflection_milestone(str(c["milestone"]))
	return false


## Done is sticky (SessionState.objectives_done), so an objective completed on
## standing does not reopen when a failed interview lowers it again. Complete
## outranks failed: a suspect flipped after he lawyered up is a flip.
func objective_state(objective: Dictionary) -> String:
	var id := str(objective.get("id", ""))
	if SessionState.objectives_done.has(id):
		return OBJECTIVE_DONE
	if _condition_holds(objective.get("complete_when")):
		if not id.is_empty():
			SessionState.objectives_done.append(id)
			# Heard the first time the journal or a HUD notices it is done.
			AudioManager.play_sfx("objective")
		return OBJECTIVE_DONE
	if objective.has("failed_when") and _condition_holds(objective["failed_when"]):
		return OBJECTIVE_FAILED
	if objective.has("unlock_when") and not _condition_holds(objective["unlock_when"]):
		return OBJECTIVE_LOCKED
	return OBJECTIVE_ACTIVE


func objectives_in_state(state: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for objective in objectives:
		if objective_state(objective) == state:
			found.append(objective)
	return found


## The one line the HUD tracks: the first active objective in file order.
func tracked_objective() -> Dictionary:
	var active := objectives_in_state(OBJECTIVE_ACTIVE)
	return active[0] if not active.is_empty() else {}


func _objective_row(box: VBoxContainer, objective: Dictionary, state: String) -> void:
	var row := PanelContainer.new()
	box.add_child(row)
	var row_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		row_margin.add_theme_constant_override(side, 12)
	row.add_child(row_margin)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_margin.add_child(body)

	var title := str(objective.get("title", ""))
	var detail := str(objective.get("detail", ""))
	match state:
		OBJECTIVE_DONE:
			body.text = "[color=#%s][b]DONE[/b]  %s[/color]" % [TextStyle.COLOR_CORRECT, title]
		OBJECTIVE_FAILED:
			body.text = "[color=#%s][b]CLOSED[/b]  %s[/color]\n[color=#%s]%s[/color]" % [
				TextStyle.COLOR_WRONG, title, TextStyle.COLOR_NARRATION,
				str(objective.get("failed_detail", detail))]
		_:
			body.text = "[b]%s[/b]\n%s" % [title, detail]


func _fill_objectives(page: VBoxContainer) -> void:
	var active := objectives_in_state(OBJECTIVE_ACTIVE)
	var failed := objectives_in_state(OBJECTIVE_FAILED)
	var done := objectives_in_state(OBJECTIVE_DONE)
	_add_note(page, "What the case needs next. How is yours to work out; the People page says who is where.")
	var box := _add_scrolling_box(page)
	if active.is_empty() and failed.is_empty() and done.is_empty():
		_add_note(box, "Nothing on file yet.")
	for objective in active:
		_objective_row(box, objective, OBJECTIVE_ACTIVE)
	for objective in failed:
		_objective_row(box, objective, OBJECTIVE_FAILED)
	for objective in done:
		_objective_row(box, objective, OBJECTIVE_DONE)


# --- People -------------------------------------------------------------------
# Every door in the case, where it is, what it takes to open, and how it went.
# Derived, not authored: the streets' own door tables say who stands where,
# the case files say what they need, SessionState says what happened.

## Each place names the script whose INTERVIEWEES table places its doors, or
## lists its cases outright with the flag that opens the door (the floors).
const PLACES := [
	{"name": "Sampaguita Street", "script": "res://scripts/exploration/urban_exterior.gd"},
	{"name": "Terminal Road", "script": "res://scripts/exploration/terminal_road.gd"},
	{"name": "{call_floor} - 3F", "cases": ["res://resources/cases/interview_case_004.json"],
		"door_flag": "suspect_flipped", "door_locked": "The operator has to name her first"},
	{"name": "{tech_floor} - 4F", "cases": ["res://resources/cases/interview_case_011.json"],
		"door_flag": "witness_flipped", "door_locked": "Someone on her floor has to turn first"},
]

var _person_cache: Dictionary = {}


func _case_person(case_path: String) -> Dictionary:
	if _person_cache.has(case_path):
		return _person_cache[case_path]
	var person: Dictionary = {}
	var file := FileAccess.open(case_path, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			person = (parsed as Dictionary).get("person", {})
	_person_cache[case_path] = person
	return person


func _place_cases(place: Dictionary) -> Array:
	if place.has("cases"):
		return place["cases"]
	var script: Script = load(str(place.get("script", "")))
	if script == null:
		return []
	var cases: Array = []
	for entry in script.get_script_constant_map().get("INTERVIEWEES", []):
		cases.append(str(entry.get("case", "")))
	return cases


## One row per door: {name, role, place, gate, status, tone}. `tone` is the
## text color the status renders in.
## The floors are named after the operation's own doors, which live on
## SessionState as one copy each; a const table cannot read an autoload, so the
## name carries the token and is expanded here.
func place_name(place: Dictionary) -> String:
	var name := str(place.get("name", "")).replace("{call_floor}", SessionState.CALL_FLOOR_NAME)
	return name.replace("{tech_floor}", SessionState.TECH_FLOOR_NAME)


func people_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for place in PLACES:
		for case_path in _place_cases(place):
			var person := _case_person(str(case_path))
			if person.is_empty():
				continue
			var row := {
				"name": str(person.get("name", "")),
				"role": str(person.get("role", "")),
				"place": place_name(place),
				"gate": int(person.get("min_credibility", 0)),
			}
			var status := _person_status(person, place)
			row["status"] = status[0]
			row["tone"] = status[1]
			rows.append(row)
	return rows


func _person_status(person: Dictionary, place: Dictionary) -> Array:
	var person_id := str(person.get("person_id", ""))
	var role := str(person.get("role", ""))
	var gate := int(person.get("min_credibility", 0))
	var outcome := str(SessionState.interview_outcomes.get(person_id, ""))
	var takes_statement: bool = SessionState.STATEMENT_ROLES.has(role)

	if takes_statement and SessionState.is_witness_closed(person_id):
		return ["Won't talk to you again", TextStyle.COLOR_WRONG]
	match outcome:
		"success":
			return ["Statement on record", TextStyle.COLOR_CORRECT]
		"whistleblower":
			return ["Flipped - he named his director", TextStyle.COLOR_CORRECT]
		"turned":
			return ["Turned - she will say what her floor does", TextStyle.COLOR_CORRECT]
		"owner_named":
			return ["Named the owner", TextStyle.COLOR_CORRECT]
		"partial":
			return ["Partial statement", TextStyle.COLOR_TACTIC]
		"failure":
			if role == "Suspect":
				return ["Shut the door - come back with a witness", TextStyle.COLOR_WRONG]
			return ["Interview went wrong", TextStyle.COLOR_WRONG]
		SessionState.OUTCOME_HESITANT:
			if SessionState.detective_credibility >= gate:
				return ["Turned you away once - your credibility is enough now", TextStyle.COLOR_TACTIC]
			return ["Turned you away - needs Credibility %d" % gate, TextStyle.COLOR_TACTIC]
	if not outcome.is_empty():
		return ["Spoken to", TextStyle.COLOR_NARRATION]
	if place.has("door_flag") and not bool(SessionState.get(str(place["door_flag"]))):
		return [str(place.get("door_locked", "Door locked")), TextStyle.COLOR_NARRATION]
	if takes_statement and SessionState.statements_left() <= 0:
		return ["No statements left to take", TextStyle.COLOR_WRONG]
	if gate > SessionState.detective_credibility:
		return ["Will not talk to a stranger - needs Credibility %d" % gate, TextStyle.COLOR_NARRATION]
	if takes_statement:
		return ["Will talk", TextStyle.COLOR_HINT]
	return ["Costs no statement", TextStyle.COLOR_HINT]


## What the marker over a person's door shows, from the same state the People
## page reads, so the two never disagree. {glyph, color}: "?" not yet visited,
## "!" turned away or shut down (come back with more), a check for a statement
## or a flip on record, "x" for a door that will not open again.
func door_marker(person: Dictionary) -> Dictionary:
	var person_id := str(person.get("person_id", ""))
	var role := str(person.get("role", ""))
	var outcome := str(SessionState.interview_outcomes.get(person_id, ""))
	var takes_statement: bool = SessionState.STATEMENT_ROLES.has(role)
	if takes_statement and SessionState.is_witness_closed(person_id):
		return {"glyph": "\u00d7", "color": TextStyle.COLOR_WRONG}
	match outcome:
		"success", "whistleblower", "turned", "owner_named":
			return {"glyph": "\u2713", "color": TextStyle.COLOR_CORRECT}
		"partial":
			return {"glyph": "\u2713", "color": TextStyle.COLOR_TACTIC}
		"failure":
			return {"glyph": "!", "color": TextStyle.COLOR_WRONG}
		SessionState.OUTCOME_HESITANT:
			return {"glyph": "!", "color": TextStyle.COLOR_HINT}
	if takes_statement and SessionState.statements_left() <= 0:
		return {"glyph": "\u00d7", "color": TextStyle.COLOR_WRONG}
	return {"glyph": "?", "color": TextStyle.COLOR_TACTIC}


func _fill_people(page: VBoxContainer) -> void:
	_add_note(page, "Every door in the case: where it is, what it takes to open, and how it went.")
	var box := _add_scrolling_box(page)
	var current_place := ""
	for row in people_rows():
		if str(row.get("place", "")) != current_place:
			current_place = str(row.get("place", ""))
			var heading := Label.new()
			heading.text = current_place.to_upper()
			heading.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
			heading.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_HINT))
			box.add_child(heading)
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gate: int = int(row.get("gate", 0))
		var gate_text := "  [color=#%s](Credibility %d)[/color]" % [TextStyle.COLOR_NARRATION, gate] if gate > 0 else ""
		line.text = "[b]%s[/b]  [color=#%s]%s[/color]%s\n[color=#%s]%s[/color]" % [
			str(row.get("name", "")), TextStyle.COLOR_NARRATION, str(row.get("role", "")), gate_text,
			str(row.get("tone", TextStyle.COLOR_NARRATION)), str(row.get("status", ""))]
		box.add_child(line)


# --- Evidence -----------------------------------------------------------------
# What is held, and what each piece proves. Mid-case this was visible only
# inside Present Evidence, one interview at a time.

func _person_name(person_id: String) -> String:
	for place in PLACES:
		for case_path in _place_cases(place):
			var person := _case_person(str(case_path))
			if str(person.get("person_id", "")) == person_id:
				return str(person.get("name", ""))
	return ""


func _fill_evidence(page: VBoxContainer) -> void:
	var items: Array[Dictionary] = SessionState.investigation_inventory
	_add_note(page, "%d item%s in the file. A statement given in one interview can be put to the next." % [
		items.size(), "" if items.size() == 1 else "s"])
	var box := _add_scrolling_box(page)
	if items.is_empty():
		_add_note(box, "Nothing yet. What you hold comes from the people who talk to you.")
		return
	# Statements first, because they are the only thing a suspect answers to. A
	# victim's whole pool is seeded when their interview opens, so most of a full
	# file is records they had on the table rather than anything the case earned.
	for group in [{"title": "STATEMENTS SECURED", "secured": true},
			{"title": "RECORDS ON FILE", "secured": false}]:
		var rows: Array[Dictionary] = []
		for item in items:
			if bool(item.get("secured", false)) == bool(group["secured"]):
				rows.append(item)
		if rows.is_empty():
			continue
		var heading := Label.new()
		heading.text = "%s  (%d)" % [str(group["title"]), rows.size()]
		heading.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_HINT))
		heading.add_theme_font_override("font", load(TextStyle.FONT_SYSTEM))
		box.add_child(heading)
		for item in rows:
			var line := RichTextLabel.new()
			line.bbcode_enabled = true
			line.fit_content = true
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var lines: Array[String] = []
			var source := _person_name(str(item.get("person_id", "")))
			lines.append("[b]%s[/b]%s" % [str(item.get("label", "")),
				"  [color=#%s]from %s[/color]" % [TextStyle.COLOR_NARRATION, source] if not source.is_empty() else ""])
			if not str(item.get("description", "")).is_empty():
				lines.append(str(item.get("description", "")))
			if not str(item.get("tactic", "")).is_empty():
				lines.append("[color=#%s]TACTIC: %s[/color]" % [TextStyle.COLOR_TACTIC, str(item.get("tactic", ""))])
			line.text = "\n".join(lines)
			box.add_child(line)


# --- Tactics ------------------------------------------------------------------

func _fill_tactics(page: VBoxContainer) -> void:
	progress_label = Label.new()
	page.add_child(progress_label)
	_add_note(page, "What these calls actually do, and how to recognize it on a real one. Entries unlock as you meet them.")
	entries_box = _add_scrolling_box(page)

	var found: int = TacticNotebook.learned_count()
	progress_label.text = "%d of %d tactics recorded" % [found, TacticNotebook.tactics.size()]

	for entry in TacticNotebook.tactics:
		var tactic_id := str(entry.get("id", ""))
		var known := SessionState.has_learned_tactic(tactic_id)

		var row := PanelContainer.new()
		entries_box.add_child(row)

		var row_margin := MarginContainer.new()
		for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			row_margin.add_theme_constant_override(side, 12)
		row.add_child(row_margin)

		var body := RichTextLabel.new()
		body.bbcode_enabled = true
		# fit_content plus the ScrollContainer above: a fixed height would
		# silently clip the longer entries.
		body.fit_content = true
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_margin.add_child(body)

		if known:
			var context := str(SessionState.get_learned_tactic(tactic_id).get("context", ""))
			var lines: Array[String] = []
			lines.append("[b]%s[/b]" % str(entry.get("name", "")))
			lines.append(str(entry.get("summary", "")))
			lines.append("[color=#%s]HOW TO SPOT IT: %s[/color]" % [TextStyle.COLOR_HINT, str(entry.get("spot_it", ""))])
			if not context.is_empty():
				lines.append("[i][color=#%s]%s[/color][/i]" % [TextStyle.COLOR_NARRATION, context])
			body.text = "\n\n".join(lines)
		else:
			# Locked entries exist so the player can see the set is incomplete -
			# the shape of what they have not met yet is itself information.
			body.text = "[color=#%s][b]Not yet recorded[/b]\n%s[/color]" % [
				TextStyle.COLOR_NARRATION,
				"You have not met this one yet, or it went past unnamed."]


# --- Open / close -------------------------------------------------------------

func toggle(tab_id: String = "") -> void:
	if is_open:
		close()
	else:
		open(tab_id)


func open(tab_id: String = "") -> void:
	if is_open:
		return
	if is_pause_open:
		close_pause()
	is_open = true
	AudioManager.play_sfx("page")
	(tab_buttons[TAB_TACTICS] as Button).visible = SessionState.notebook_collected
	var target := tab_id if tab_pages.has(tab_id) else str(TABS[0].get("id", ""))
	_select_tab(target)
	panel_root.visible = true
	open_button.visible = false
	# Pausing means reading the journal never lets the player walk the map
	# while it is up.
	get_tree().paused = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	panel_root.visible = false
	get_tree().paused = false
	_refresh_button_visibility()


# --- Pause menu ---------------------------------------------------------------

func _build_pause_menu() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	layer.add_child(pause_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)

	pause_buttons = VBoxContainer.new()
	pause_buttons.add_theme_constant_override("separation", 10)
	column.add_child(pause_buttons)
	_add_pause_button("Resume", close_pause)
	journal_button = _add_pause_button("Case Journal", open.bind(""))
	notebook_button = _add_pause_button("Tactic Notebook", open.bind(TAB_TACTICS))
	sound_button = _add_pause_button(AudioManager.volume_label(), _cycle_volume)
	_add_pause_button("Return to Main Menu", _ask_to_abandon)

	# Leaving resets the session. The one question this menu exists to ask.
	confirm_box = VBoxContainer.new()
	confirm_box.add_theme_constant_override("separation", 10)
	confirm_box.visible = false
	column.add_child(confirm_box)

	var warning := Label.new()
	warning.text = "This abandons the case. Nothing is kept."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_WRONG))
	confirm_box.add_child(warning)

	var leave := Button.new()
	leave.text = "Abandon the case"
	leave.custom_minimum_size = Vector2(0, 40)
	leave.pressed.connect(_abandon_run)
	confirm_box.add_child(leave)

	var stay := Button.new()
	stay.text = "Keep going"
	stay.custom_minimum_size = Vector2(0, 40)
	stay.pressed.connect(_show_pause_buttons)
	confirm_box.add_child(stay)


func _add_pause_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(on_pressed)
	pause_buttons.add_child(button)
	return button


func open_pause() -> void:
	if is_pause_open or is_open:
		return
	is_pause_open = true
	journal_button.visible = SessionState.journal_collected
	notebook_button.visible = SessionState.notebook_collected
	# The main menu has the same control; pick up whatever it was set to there.
	sound_button.text = AudioManager.volume_label()
	_show_pause_buttons()
	pause_root.visible = true
	open_button.visible = false
	get_tree().paused = true


func close_pause() -> void:
	if not is_pause_open:
		return
	is_pause_open = false
	pause_root.visible = false
	get_tree().paused = false
	_refresh_button_visibility()


func is_asking_to_abandon() -> bool:
	return is_pause_open and confirm_box.visible


func _cycle_volume() -> void:
	AudioManager.cycle_volume()
	sound_button.text = AudioManager.volume_label()


func _ask_to_abandon() -> void:
	pause_buttons.visible = false
	confirm_box.visible = true


func _show_pause_buttons() -> void:
	pause_buttons.visible = true
	confirm_box.visible = false


func _abandon_run() -> void:
	close_pause()
	SessionState.go_to_scene(MAIN_MENU_SCENE)


# --- Input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_pause_open:
		if event.is_action_pressed("ui_cancel"):
			if is_asking_to_abandon():
				_show_pause_buttons()
			else:
				close_pause()
			get_viewport().set_input_as_handled()
		return

	var wants_journal := _pressed(event, JOURNAL_ACTION, KEY_J)
	var wants_notebook := _pressed(event, NOTEBOOK_ACTION, KEY_N)
	if is_open:
		if event.is_action_pressed("ui_cancel") or wants_journal or wants_notebook:
			close()
			get_viewport().set_input_as_handled()
		return

	if not _available_here():
		return
	if wants_journal:
		open()
		get_viewport().set_input_as_handled()
	elif wants_notebook and SessionState.notebook_collected:
		open(TAB_TACTICS)
		get_viewport().set_input_as_handled()


func _pressed(event: InputEvent, action: String, fallback_key: Key) -> bool:
	if InputMap.has_action(action) and event.is_action_pressed(action):
		return true
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == fallback_key


# Every button in the game clicks. Connected here, as buttons are added, so
# no screen has to remember to do it; a button that makes its own sound (the
# journal's tabs) opts out with the "silent" meta.
func _on_node_added(node: Node) -> void:
	_refresh_button_visibility.call_deferred()
	if node is Button and not node.has_meta("silent"):
		(node as Button).pressed.connect(AudioManager.play_sfx.bind("click"))


func shows_button_in(scene_path: String) -> bool:
	return not HIDDEN_IN_SCENES.has(scene_path)


## Offered in this scene, and picked up: the journal is handed over at the
## desk the case starts at, so until then there is nothing to open.
func _available_here() -> bool:
	var current := get_tree().current_scene
	return SessionState.journal_collected and shows_button_in(current.scene_file_path if current != null else "")


## For the desk to call when a tool is picked up.
func refresh_availability() -> void:
	_refresh_button_visibility()


func _refresh_button_visibility() -> void:
	if open_button == null or is_open or is_pause_open:
		return
	open_button.visible = _available_here()
