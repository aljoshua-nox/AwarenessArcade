extends "res://scripts/exploration/office_interior.gd"

## The start of the shift: the scammer walks onto the call floor, finds their
## desk, and the calls begin when they sit down. It is the same room the
## detective walks later - the third floor, ClearLine's, with the same
## benches, the same bonus board and the same director's door - seen by
## somebody who works there. The call list in that room is the one this shift
## writes, so the player sits at the desk the case will come back to.
##
## The room is office_interior.gd's; what differs is who is in it. The player
## is an operator, not the detective (a Modern Interiors character). No
## standing, no statements, no journal - the scammer carries none of it. The
## door does not open, the stairs are not theirs, and the reads are the floor's
## own paperwork in the floor's own words, with no case notes under them.

const OPERATOR_IDLE: Texture2D = preload("res://assets/art/characters/modern_interiors/Operator_idle_16x16.png")
const OPERATOR_RUN: Texture2D = preload("res://assets/art/characters/modern_interiors/Operator_run_16x16.png")
# The pedestrians' scale, which is the detective's size.
const OPERATOR_SCALE := 1.5

# The middle seat of the middle bench in the back row, reached from the aisle
# behind it.
const YOUR_DESK_POSITION := Vector2(660.0, 386.0)
const SHIFT_BOARD_POSITION := Vector2(300.0, 268.0)
const BONUS_BOARD_POSITION := Vector2(1000.0, 612.0)

# Tests sit down without leaving the scene.
var suppress_scene_change: bool = false
var shift_started: bool = false


func _init() -> void:
	map_hint = "WASD or arrows to walk  ·  Enter to examine  ·  Esc menu"
	portal_target_scene = ""


func _ready() -> void:
	super()
	player.use_pack_character(OPERATOR_IDLE, OPERATOR_RUN, OPERATOR_SCALE)


func exit_prompt() -> String:
	return "You've clocked in. No one leaves early."


func _can_enter_portal() -> bool:
	return false


# --- The HUD ------------------------------------------------------------------

# The floors' HUD without the detective's numbers: one line saying where to go.
func _build_hud() -> void:
	station_label = Label.new()
	station_label.visible = false
	hud.add_child(station_label)

	objective_label = Label.new()
	objective_label.theme_type_variation = &"HudLine"
	objective_label.offset_left = 9.0
	objective_label.offset_top = 75.0
	objective_label.add_theme_color_override("font_color", Color.html(TextStyle.COLOR_TACTIC))
	hud.add_child(objective_label)
	_refresh_objective_label()

	inspect_panel = InspectPanel.new("Enter or Esc to step back")
	hud.add_child(inspect_panel)
	inspect_title = inspect_panel.title_label
	inspect_body = inspect_panel.body


func _refresh_objective_label() -> void:
	objective_label.visible = true
	objective_label.text = "> Go to your desk (back row, middle)"


# --- The room -----------------------------------------------------------------

# The floor's furniture where the detective will find it; three things to read
# and one desk that is yours.
func _build_stations() -> void:
	_add_part("bookcase_pair", Vector2(360.0, 604.0), -10, true)
	_add_part("chair_front", Vector2(660.0, 572.0), -12, true)
	_add_part("desk_ledger", Vector2(660.0, 604.0), -10, true)
	_add_part("whiteboard", Vector2(1000.0, 606.0), -10, true)

	_add_station({
		"title": "Your desk",
		"prompt": "Sit down and start your shift",
		"is_your_desk": true,
	}, YOUR_DESK_POSITION)

	_add_station({
		"title": "The shift board",
		"prompt": "Read the shift board",
		"body": _shift_board_text(),
	}, SHIFT_BOARD_POSITION)

	_add_station({
		"title": "Bonus board",
		"prompt": "Look at the bonus board",
		"body": "A whiteboard by the water cooler, a laminated header across the top: %s - FLOOR 3 - MONTHLY INCENTIVES. Names down the left, a tally beside each. Yours is near the bottom, with nothing beside it yet. The last column is ESCALATED, and it pays double - the team lead's word for a call where the person got scared enough to stop asking questions. Under it, someone has drawn a smiley face." % SessionState.CALL_FLOOR_NAME.to_upper(),
	}, BONUS_BOARD_POSITION)


# The prologue's rules, as the team lead would put them: its clock, the list,
# patience and doubt, dropping a number, and the reports that pull the line.
func _shift_board_text() -> String:
	return "A sheet taped to the board by the door, in the team lead's marker:\n\nSHIFT - %d MINUTES. WORK THE LIST. ONE CALL PER NUMBER.\nDON'T KEEP THEM WAITING, AND DON'T PUSH TOO HARD. EITHER WAY, THEY HANG UP.\nIF THEY START ASKING QUESTIONS, YOU CAN DROP THE NUMBER. A DROPPED NUMBER IS BETTER THAN A REPORT.\n%d REPORTS AND THE LINE GETS PULLED." % [
		int(SessionState.SHIFT_SECONDS / 60.0), SessionState.REPORTS_TO_PULL_LINE]


# The door the detective will open at the end of the case. From this side of
# it, a door nobody on the floor goes through.
func _add_director_door() -> void:
	_add_station({
		"title": "The director's door",
		"prompt": "Look at the director's door",
		"body": "A door at the back of the floor, blinds drawn. The nameplate reads %s - FLOOR DIRECTOR. The team lead takes the tally in there at the end of every shift. You've never been past the door." % director_nameplate(),
	}, DIRECTOR_DOOR_POSITION)


# The stairs are drawn - it is the same room - but the floor above is not yours.
func _add_stairs() -> void:
	pass


# --- Sitting down -------------------------------------------------------------

func _open_inspection(station: Dictionary) -> void:
	if bool(station.get("is_your_desk", false)):
		_sit_down()
		return
	super(station)


# The shift starts: the call screen takes over from here, with its own sound,
# so the floor's bed is left to it to stop.
func _sit_down() -> void:
	if shift_started:
		return
	shift_started = true
	prompt_bubble.hide_bubble()
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	if suppress_scene_change:
		return
	_transition_to_scene(SessionState.PROLOGUE_CALL_SCENE, "")
