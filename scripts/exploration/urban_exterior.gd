extends "res://scripts/exploration/district_exterior.gd"

## The terrace: the first district, and the one the case starts on. A shop row
## with the office in it along the top, four houses on the grass below the
## road, two side streets, and the street stops that teach the reused list.
## Everything that makes a district walkable lives in district_exterior.gd;
## this file is the tables that say what stands where.

const CASE_MARIA := "res://resources/cases/interview_case_001.json"
const CASE_KEVIN := "res://resources/cases/interview_case_002.json"
const CASE_MARCO := "res://resources/cases/interview_case_003.json"
const CASE_EVELYN := "res://resources/cases/interview_case_005.json"
const CASE_LINA := "res://resources/cases/interview_case_006.json"
const CASE_TEDDY := "res://resources/cases/interview_case_007.json"

# The cast, and which building each one lives in. Portals used to be three
# hand-placed nodes in the scene file, which capped the cast at three and made
# adding a witness a scene edit; they are built from this table instead.
#
# `row` picks the terrace: "block" is the residential row on the grass below the
# road, "street" is the shop row the office stands in. `slot` is an index into
# that row's building list. Doors are not all in one row on purpose - the
# residential row has room for four without crowding the trees and the side
# streets, and the two who work out of premises rather than homes (Lina's print
# shop, Marco at the call centre) belong on the commercial row anyway.
#
# Adding a witness: one row here, plus a building in the matching list if the
# slot is not already there. test_urban.tscn fails if a slot does not exist or
# if a building lands on a side street, a tree or another building.
const INTERVIEWEES := [
	{"case": CASE_EVELYN, "label": "EVELYN", "prompt": "Speak with Evelyn Marsh", "row": "block", "slot": 0},
	{"case": CASE_MARIA, "label": "MARIA", "prompt": "Speak with Maria Santos", "row": "block", "slot": 1},
	{"case": CASE_KEVIN, "label": "KEVIN", "prompt": "Speak with Kevin Dizon", "row": "block", "slot": 2},
	{"case": CASE_TEDDY, "label": "TEDDY", "prompt": "Speak with Teodoro Villanueva", "row": "block", "slot": 3},
	{"case": CASE_LINA, "label": "LINA", "prompt": "Speak with Lina Reyes", "row": "street", "slot": 1},
	{"case": CASE_MARCO, "label": "MARCO", "prompt": "Interrogate Marco Navarro", "row": "street", "slot": 4},
]

# The street's own content. Exploration was pure transit between doors, which
# wasted the one space the player crosses over and over. What these are FOR is
# pattern-recognition living somewhere other than a dialogue tree: the same
# number and the same script turning up at door after door, so the player joins
# it up themselves instead of being told in an interview that scripts get reused.
#
# The number itself is SessionState.OPERATION_NUMBER: the call floor's own
# ledger has to print the SAME string, so there is exactly one copy of it.
# Nothing points the repetition out - noticing it is the mechanic.
#
# Below the residential terrace (buildings end at y 702.4), clear of the trees
# at y 600/950 and of both side streets. test_urban checks that.
const NOTICEBOARD_POSITION := Vector2(980.0, 770.0)

# Each stop sits on an NPC from NPC_SPOTS, except the noticeboard. `cites_number`
# marks the ones that print that number - reading two of them is what earns the
# pattern milestone, so the payoff is for joining sources up, not for walking far.
const STREET_STOPS := [
	{
		"position": NOTICEBOARD_POSITION,
		"is_noticeboard": true,
		"title": "Community noticeboard",
		"prompt": "Read the noticeboard",
		"body": "A cork board on a post outside the terrace, behind cracked perspex. Under a bus timetable and a card for guitar lessons, a barangay notice has been pinned square in the middle and laminated against the weather.\n\nWARNING - TELEPHONE FRAUD IN THIS AREA. Callers claim to be from your bank's fraud desk, a device support line, or a prize office. Reported number: %s. They will ask you to stay on the line. Hang up. Call your bank on the number printed on your own card. No bank, agency or prize office will ever ask you to read out a one-time code.",
		"note": "That last line is the one worth carrying out of the game. A code sent to your phone is the bank checking it is you. Reading it aloud to a caller hands them the check.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
		"tactic_id": "repeated_script",
		"cites_number": true,
		"milestone_title": "The Warning Was Already Up",
		"milestone_detail": "A community notice on the street named the operation's number and all three of its scripts - the information existed before the case did.",
	},
	{
		"position": Vector2(700.0, 600.0),
		"title": "Neighbour on the terrace",
		"prompt": "Talk to the neighbour",
		"body": "Someone is out on the step with a mug, watching you work down the row. \"You're asking about the calls.\" A nod at the houses either side. \"I got the same one. Fraud desk, account compromised, stay on the line while they secure it.\" A shrug. \"I put the phone down. Then I asked next door. Next door got it too, word for word.\"",
		"note": "Three households, one script, delivered to each as though it had been written for them. A call that feels personally aimed is usually a form letter read aloud.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "repeated_script",
		"milestone_title": "Word For Word, Three Doors Apart",
		"milestone_detail": "Neighbours on one row received identical wording, which is what makes it a script rather than a targeted approach.",
	},
	{
		"position": Vector2(330.0, 216.0),
		"title": "Passer-by at the crossing",
		"prompt": "Talk to the passer-by",
		"body": "\"My mother had one of these.\" They answer before you have finished asking. \"Twice. Once in March, once about six weeks ago. Different story the second time - a refund instead of a fraud alert - but the same wrong pronunciation of her surname both times.\"",
		"note": "Being called twice is not bad luck. A number that answers is worth more than one that does not, so it is kept, sold on and worked again under a fresh story.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "reused_victim_list",
		"milestone_title": "Called Twice, Six Weeks Apart",
		"milestone_detail": "One resident was worked twice from the same list under two different scripts - answering once marks a number as live.",
	},
	{
		"position": Vector2(740.0, 216.0),
		"title": "Shopkeeper",
		"prompt": "Talk to the shopkeeper",
		"body": "\"That your poster?\" A tip of the head down the road towards the noticeboard. \"I put the number up in my window as well. Big, where you can't miss it. %s.\" They straighten a stack of receipts. \"Four people came in this month to ask me if it was real. Four that came in. I've no idea how many just paid it.\"",
		"note": "The people who come in to ask are the ones who did not lose anything. What a scam costs a street is never the number of reports - it is the silence around them.",
		"note_color": TextStyle.COLOR_WRONG,
		"marker": TextStyle.MARK_HARM,
		"cites_number": true,
		"milestone_title": "Four Asked. Nobody Counted The Rest.",
		"milestone_detail": "A shopkeeper posted the number and fielded four queries in a month - the questions asked out loud are a fraction of the actual contact.",
	},
	{
		"position": Vector2(1200.0, 408.0),
		"title": "Waiting at the kerb",
		"prompt": "Talk to the person waiting",
		"body": "\"Scam calls?\" A short laugh. \"You'd have to be pretty gullible, wouldn't you. My grandmother, maybe. Not me - I'd hear it coming a mile off.\" A pause, and the laugh goes out of it. \"...Why? What is it they say?\"",
		"note": "Everyone believes they would hear it coming, and that belief is the thing the scripts are built around. Being busy, tired or halfway out the door does more work than being credulous ever did. The question at the end is the honest part.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"milestone_title": "\"You'd Have To Be Gullible\"",
		"milestone_detail": "The commonest myth about fraud victims, met on the street - confidence that you would spot it is exactly what the scripts count on.",
	},
	{
		"position": Vector2(1750.0, 950.0),
		"title": "Resident by the back path",
		"prompt": "Talk to the resident",
		"body": "\"I stopped answering months ago.\" They say it without looking up from the gate latch. \"They ring anyway. Same number every time - %s - four or five times a week, then nothing for a month, then it starts again.\" The latch drops into place. \"I know what it is now. I just want it to stop.\"",
		"note": "The calls do not stop because a confirmed line stays on the list whatever the person does. Letting unknown callers go to voicemail costs nothing and is what takes a number back off it.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
		"tactic_id": "reused_victim_list",
		"cites_number": true,
		"milestone_title": "The Number That Keeps Ringing",
		"milestone_detail": "A resident who stopped answering is still called weekly from the same number - refusing does not remove you from a list, it only confirms you are on it.",
	},
]

const PATTERN_MILESTONE := "One Number, More Than One Door"
const PATTERN_DETAIL := "The number on the community notice is the number two residents read back from their own phones - the same line worked the whole street."

const SIDE_STREET_X_POSITIONS := [520.0, 1400.0]

const BUILDING_ROW := [
	{"x": 242.0, "color": ROOF_TAN_X},
	{"x": 456.0, "color": ROOF_OLIVE_X},
	{"x": 669.0, "color": ROOF_MAUVE_X},
	{"x": 883.0, "color": ROOF_BRICK_X},
	{"x": 1097.0, "color": ROOF_ROSE_X},
	{"x": 1310.0, "color": ROOF_TAN_X},
	{"x": 1524.0, "color": ROOF_OLIVE_X},
]
const OFFICE_ROW_INDEX := 3

# Positions are constrained, not decorative. A block building is 124.8 wide, so
# each entry occupies [x, x + 124.8] at y 520-702.4, and that band already
# contains the two side streets ([520,616] and [1400,1496]), the trees at y 600
# (x 400, 1000, 1550) and a pedestrian at x 700. An earlier five-across layout
# put one house in the middle of a side street and another through a tree. The
# fourth house sits in the right-hand pocket past the second side street, clear
# of the tree at 1550 (which ends at 1567.6) and the resident at (1750, 950).
const BLOCK_BUILDINGS := [
	{"x": 140.0, "color": ROOF_ROSE_X},
	{"x": 780.0, "color": ROOF_TAN_X},
	{"x": 1150.0, "color": ROOF_MAUVE_X},
	{"x": 1620.0, "color": ROOF_BRICK_X},
]

const CAR_SPOTS := [300.0, 650.0, 1250.0, 1600.0, 1800.0]
const TREE_SPOTS := [
	Vector2(400.0, 600.0), Vector2(650.0, 950.0), Vector2(1000.0, 600.0),
	Vector2(1250.0, 950.0), Vector2(1550.0, 600.0), Vector2(1850.0, 950.0),
	Vector2(300.0, 950.0),
]
const LAMP_TOP_X := [350.0, 900.0, 1450.0]
const LAMP_BOTTOM_X := [350.0, 900.0, 1300.0]

const NPC_SPOTS := [
	{"x": 330.0, "y": 216.0, "kind": "a", "tint": Color(1, 1, 1, 1)},
	{"x": 1200.0, "y": 408.0, "kind": "b", "tint": Color(1, 1, 1, 1)},
	{"x": 700.0, "y": 600.0, "kind": "a", "tint": Color(0.85, 1.0, 0.85, 1)},
	{"x": 1750.0, "y": 950.0, "kind": "a", "tint": Color(1.0, 0.85, 0.85, 1)},
	{"x": 740.0, "y": 216.0, "kind": "b", "tint": Color(1, 1, 1, 1)},
]


func _init() -> void:
	map_title = "Urban Block"
	map_hint = "Move with WASD or arrow keys. Press Enter at a door to interact."


func interviewees() -> Array:
	return INTERVIEWEES


func building_row() -> Array:
	return BUILDING_ROW


func office_row_index() -> int:
	return OFFICE_ROW_INDEX


func block_buildings() -> Array:
	return BLOCK_BUILDINGS


func side_street_x_positions() -> Array:
	return SIDE_STREET_X_POSITIONS


func car_spots() -> Array:
	return CAR_SPOTS


func tree_spots() -> Array:
	return TREE_SPOTS


func lamp_top_x() -> Array:
	return LAMP_TOP_X


func lamp_bottom_x() -> Array:
	return LAMP_BOTTOM_X


func npc_spots() -> Array:
	return NPC_SPOTS


func street_stops_table() -> Array:
	return STREET_STOPS


func pattern_milestone_title() -> String:
	return PATTERN_MILESTONE


func pattern_milestone_detail() -> String:
	return PATTERN_DETAIL
