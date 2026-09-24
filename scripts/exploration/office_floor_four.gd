extends "res://scripts/exploration/office_interior.gd"

## The fourth floor: tech support, Rowena Ocampo's. The floor above Elena's,
## reached by the stairwell at the back of the call floor. It runs the
## remote-access script Kevin fell for and the recruitment that hired Bea off
## the advertisement that scammed Trish - which is why the two witnesses who
## can crack its director are a tech-support victim and a job-offer one.
## The room is the call floor's; what is on the desks is not.

const CASE_ROWENA := "res://resources/cases/interview_case_011.json"
const CALL_FLOOR_SCENE := "res://scenes/exploration/office_interior.tscn"


func _init() -> void:
	map_title = "%s - 4F" % SessionState.TECH_FLOOR_NAME
	map_hint = "WASD or arrows to walk  \u00b7  Enter to examine  \u00b7  J journal  \u00b7  Esc menu"
	portal_target_scene = CALL_FLOOR_SCENE


func confrontation_case() -> String:
	return CASE_ROWENA


func director_nameplate() -> String:
	return "R. OCAMPO"


# Rowena's door is a way to the owner's name, not the end of the case.
func confrontation_ends_case() -> bool:
	return false


func director_unlocked() -> bool:
	return SessionState.witness_flipped


func director_locked_note() -> String:
	return "Bea Santiago, the operator in the boarding house on Terminal Road, is the way through this door. Until someone who works on this floor is willing to say what it does, there is nothing here to open."


# No floor above this one that the player can walk. The exit door at the left
# of the back wall is the stairs down, and it is also where a player who has
# just climbed them appears: player_spawn sits in front of that door.
func stairs_target() -> String:
	return ""


func exit_prompt() -> String:
	return "Take the stairs down to the call floor"


# The floor above is painted and carpeted differently from the one below, so
# the stairs visibly go somewhere, and its way out is a staircase, not a door.
func wall_style() -> String:
	return "greyblue"


func floor_style() -> String:
	return "tile_grey"


func exit_is_stairs() -> bool:
	return true


# Down the stairs. The call floor puts a returning player in front of its
# stairwell, not at the street door.
func _take_exit() -> void:
	SessionState.office_return_spawn = STAIRS_ARRIVAL
	SessionState.has_office_return_spawn = true
	super()


# Four exhibits, in the same four places as the floor below, so the player who
# has walked one floor knows how to walk the other. What they show is what this
# floor does that the one below does not.
# The short names people use for the two floors - the first word of each.
func _call_floor_short() -> String:
	return SessionState.CALL_FLOOR_NAME.split(" ")[0]


func _tech_floor_short() -> String:
	return SessionState.TECH_FLOOR_NAME.split(" ")[0]


func _build_stations() -> void:
	_add_station({
		"title": "The remote-access script",
		"prompt": "Examine the script",
		"body": "A single laminated script in a rack, thicker than the three downstairs, its steps numbered. STEP 1 - CONFIRM THE WARNING THEY SAW. STEP 3 - ASK THEM TO INSTALL THE SUPPORT TOOL AND READ YOU THE SESSION CODE. STEP 4 - IF THEY HESITATE, SAY THE TECHNICIAN IS ALREADY CONNECTED. STEP 6 - THE REMOVAL FEE. Every page is initialed at the bottom: R.O.",
		"note": "The 'support tool' is remote access, and the session code is the customer unlocking their own machine for a stranger. Nothing on the machine was ever wrong; the fee at step 6 is for fixing the problem step 1 invented.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"milestone_title": "The Script Upstairs",
		"milestone_detail": "The fourth floor keeps one script, longer than the call floor's three, initialed by its director on every page - the remote-access call is written and owned, not improvised.",
	}, Vector2(360.0, 612.0))
	_add_part("bookcase_pair", Vector2(360.0, 604.0), -10, true)

	_add_station({
		"title": "The session log",
		"prompt": "Examine the session log",
		"body": "A printout on the supervisor's desk: SUPPORT TOOL - SESSIONS THIS WEEK. Columns for operator ID, start, end, outcome. Most IDs begin 4F. A handful begin 3F, all of them late at night - one of them, 3F-07 NAVARRO, from 23:04 to 23:41, outcome PAID.",
		"note": "%s downstairs uses %s's tool after hours. A floor-3 operator who says he was never in the building at night has his ID on a floor-4 printout. The floors share a script, a list and a login; %s and %s are two names on two doors and one operation." % [_call_floor_short(), _tech_floor_short(), _call_floor_short(), _tech_floor_short()],
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_SCENE,
		"milestone_title": "One Login, Two Floors",
		"milestone_detail": "The fourth floor's session log carries floor-3 operator IDs after hours - the building's floors are one operation with two nameplates.",
	}, Vector2(660.0, 612.0))
	_add_part("chair_front", Vector2(660.0, 572.0), -12, true)
	_add_part("desk_bench", Vector2(660.0, 604.0), -10, true)
	_add_part("monitor", Vector2(660.0, 580.0), -9)

	_add_station({
		"title": "The headset rack",
		"prompt": "Examine the headset rack",
		"body": "Forty hooks on a board by the water cooler, each numbered 4F-01 to 4F-40, most with a headset on it and a strip of tape underneath. About half the strips have a surname. 4F-12: SANTIAGO. 4F-19: blank. 4F-31: blank, with the tape peeled and stuck back down.",
		"note": "A name on a hook is a person who has been here long enough to be given one. Half the hooks have none: this floor hires by the batch and loses them by the batch, and the ones who stay are the ones with rent due.",
		"note_color": TextStyle.COLOR_WRONG,
		"marker": TextStyle.MARK_HARM,
		"milestone_title": "Her Name Is On The Rack",
		"milestone_detail": "The fourth floor's headset rack carries the operator numbers of the people it recruited - one of them a witness who has agreed to talk.",
	}, Vector2(1000.0, 612.0))
	_add_part("whiteboard", Vector2(1000.0, 606.0), -10, true)

	_add_station({
		"title": "The recruitment folder",
		"prompt": "Examine the recruitment folder",
		"body": "A ring binder by the door, RECRUITMENT on the spine. Inside, the advertisement - %s. CUSTOMER SERVICE REPRESENTATIVES, NO EXPERIENCE, TRAINING PROVIDED, 5 SLOTS LEFT - printed and dated, one copy per month, the same five slots every time. Behind it, a list of applicants in two columns: PAID FEE and HIRED. The columns never share a name." % SessionState.TECH_FLOOR_NAME.to_upper(),
		"note": "The advertisement is itself one of the scripts. Applicants who pay the training fee are victims; applicants who do not are interviewed and become operators. The floor recruits its staff and its marks from the same page, and the page decides which is which by whether they can pay.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"milestone_title": "The Ad Is The Script",
		"milestone_detail": "The fourth floor's recruitment folder runs the same advertisement monthly and sorts applicants into the ones who paid a fee and the ones who were hired - the job offer is a scam and a hiring funnel at once.",
	}, Vector2(300.0, 268.0))
