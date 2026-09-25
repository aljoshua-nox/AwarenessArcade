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

# The detective's desk: the building the case starts in, on the grass at the
# bottom-left with its door over the map's default spawn (set in _init) - so
# walking out of it for the first time and being dropped on the street by a
# test are the same place. Its door moved down 60 px when the street was
# redrawn (2026-09-24): the white two-storey building is taller than the old
# unit, and at the old height its roof closed off Evelyn's door above it.
const DESK_DOOR := Vector2(150.0, 990.0)

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
		"title": "Community bulletin board",
		"prompt": "Read the bulletin board",
		"body": "BARANGAY ADVISORY - TELEPHONE SCAMS. Callers pretend to be your bank's fraud department, a tech support line, or a raffle office. Reported number: %s. They will tell you to stay on the line. Hang up. Call your bank using the number on the back of your card. No bank, government office or prize office will ever ask for your OTP.",
		"note": "The last line is the one to remember. A one-time code sent to your phone is the bank checking it is really you. Reading it out to a caller hands them the key.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
		"tactic_id": "repeated_script",
		"cites_number": true,
		"milestone_title": "The Warning Was Already Up",
		"milestone_detail": "A community notice on the street named the operation's number and three of its scams - the information existed before the case did.",
	},
	{
		"position": Vector2(700.0, 600.0),
		"title": "Aling Nena, Maria's neighbor",
		"prompt": "Talk to Aling Nena",
		"body": "On the step with a mug of coffee, watching you go door to door.\n\"You're the one asking about the calls, no? Come, come.\"\nShe points at Maria's house with her lips.\n\"I got the same call as Maria. 'Ma'am, this is the fraud department of your bank, please stay on the line.' Word for word.\"\n\"I hung up. Asked next door - same call, same day. Ask Maria.\"",
		"note": "Same lines, same order, two doors apart. That is a script - and the person reading it does not know who you are.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "repeated_script",
		"milestone_title": "Word For Word, Three Doors Apart",
		"milestone_detail": "Neighbors on one street received identical wording, which is what makes it a script rather than a targeted approach.",
	},
	{
		"position": Vector2(330.0, 216.0),
		"title": "Jomar, on his way to work",
		"prompt": "Talk to Jomar",
		"body": "Polo, ID lanyard, watching the road for a jeep.\n\"Scam calls? My mother got two. March - 'ma'am, your account is compromised.' Last month - 'ma'am, you have a refund.' Same voice.\"\n\"Both times they said her surname wrong. The same wrong way.\"\nHe laughs, not amused.\n\"So it's the same people, right? They just kept her number.\"",
		"note": "A second call is not bad luck. A number that answers gets kept and worked again.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "reused_victim_list",
		"milestone_title": "Called Twice, Six Weeks Apart",
		"milestone_detail": "One resident was worked twice from the same list under two different scams - answering once marks a number as live.",
	},
	{
		"position": Vector2(740.0, 216.0),
		"title": "Store owner",
		"prompt": "Talk to the store owner",
		"body": "\"Ah, the poster by the bulletin board? Mine is bigger.\"\nHe points at the store window: a sheet of paper, DO NOT ANSWER THIS NUMBER - %s, written in marker.\n\"Four people came in this month to ask if that number is really a scam. Four who asked.\"\nHe goes back to counting coins.\n\"How many paid and kept quiet? That, I don't know. Nobody comes to the store to say they got fooled.\"",
		"note": "Four asked. Nobody knows how many paid. What a street reports is always smaller than what it lost.",
		"note_color": TextStyle.COLOR_WRONG,
		"marker": TextStyle.MARK_HARM,
		"cites_number": true,
		"milestone_title": "Four Asked. Nobody Counted The Rest.",
		"milestone_detail": "A store owner posted the number and fielded four questions in a month - the questions asked out loud are a fraction of the actual contact.",
	},
	{
		"position": Vector2(1200.0, 408.0),
		"title": "Carlo, waiting for a jeep",
		"prompt": "Talk to Carlo",
		"body": "A man in a work shirt at the curb.\n\"Scam calls?\"\nHe laughs.\n\"Boss, you'd have to be really slow to fall for that. My lola, maybe. Not me.\"\nA jeep passes, full. He doesn't flag it. The laugh fades.\n\"...Why, what do they say when they call?\"",
		"note": "Everybody thinks they would catch it. The scams are built for someone busy or tired, not someone slow. His last question is the honest one.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"milestone_title": "\"You'd Have To Be Gullible\"",
		"milestone_detail": "The commonest myth about fraud victims, met on the street - confidence that you would spot it is exactly what the scams count on.",
	},
	{
		"position": Vector2(1750.0, 950.0),
		"title": "Aling Rosa, Teddy's neighbor",
		"prompt": "Talk to Aling Rosa",
		"body": "An older woman locking her gate, not looking up.\n\"I stopped answering months ago. They still call. Same number every time - %s. Four, five times a week, then nothing, then again.\"\nThe padlock clicks.\n\"I know what it is now. I just want it to stop. Teddy next door still answers. He's eighty-one - he thinks it's rude not to.\"",
		"note": "A number that once answered stays on the list. Let unknown numbers ring out - a line that never picks up is what gets it taken off.",
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

# The shop row. The office is the tallest thing on the street - six storeys
# with a water tank, the call floors on its third and fourth - because the
# player climbs it; everything else is two or three.
const BUILDING_ROW := [
	{"door_x": 319.0, "kit": "building-b_mint"},
	{"door_x": 533.0, "kit": "building-g_sky"},
	{"door_x": 746.0, "kit": "building-c_cream"},
	{"door_x": 960.0, "kit": "building-l_greige"},
	{"door_x": 1174.0, "kit": "building-d_lemon"},
	{"door_x": 1387.0, "kit": "building-a_peach"},
	{"door_x": 1601.0, "kit": "building-b_lilac"},
]
const OFFICE_ROW_INDEX := 3

# Positions are constrained, not decorative. The houses stand on
# BLOCK_ROW_BOTTOM in a band that already holds the two side streets
# ([520,616] and [1400,1496]), the trees and two residents; they are the
# kit's two-storey models, because a three-storey one reaches the pavement
# above and Carlo stands on that. An earlier five-across layout put one house
# in the middle of a side street and another through a tree. test_urban checks
# the drawn rectangles against all of it.
const BLOCK_BUILDINGS := [
	{"door_x": 202.0, "kit": "building-c_lilac"},
	{"door_x": 842.0, "kit": "building-c_peach"},
	{"door_x": 1212.0, "kit": "building-e_mint"},
	{"door_x": 1682.0, "kit": "building-c_sky"},
]

# Trees on the grass, clear of the houses, the doors and everyone standing
# about. (The city set's own tree tile read as a green bottle and was removed
# on 2026-09-19; these are the RPG Urban pack's.)
const TREE_SPOTS := [
	{"at": Vector2(430.0, 700.0), "kind": "small"},
	{"at": Vector2(1010.0, 620.0), "kind": "cluster"},
	{"at": Vector2(1330.0, 880.0), "kind": "tall"},
	{"at": Vector2(1840.0, 700.0), "kind": "tall"},
	{"at": Vector2(430.0, 1010.0), "kind": "cluster"},
	{"at": Vector2(690.0, 1010.0), "kind": "tall"},
	{"at": Vector2(880.0, 1062.0), "kind": "small"},
	{"at": Vector2(1240.0, 1000.0), "kind": "small"},
	{"at": Vector2(1580.0, 1050.0), "kind": "cluster"},
	{"at": Vector2(1880.0, 1040.0), "kind": "tall"},
]
# Alternating sides along the road (see district_exterior.gd), the top ones in
# the gaps between buildings, the bottom ones clear of the side streets' mouths.
const LAMP_TOP_X := [426.0, 1067.0, 1707.0]
const LAMP_BOTTOM_X := [760.0, 1350.0]

# Jomar, Carlo (on his phone at the curb), Aling Nena, Aling Rosa (whose phone
# keeps ringing), the store owner.
const NPC_SPOTS := [
	{"x": 330.0, "y": 216.0, "who": "Bob", "pose": "idle"},
	{"x": 1200.0, "y": 408.0, "who": "Adam", "pose": "phone"},
	{"x": 700.0, "y": 600.0, "who": "Amelia", "pose": "idle"},
	{"x": 1750.0, "y": 950.0, "who": "Amelia", "pose": "phone"},
	{"x": 740.0, "y": 216.0, "who": "Alex", "pose": "idle"},
]


# The second side street runs off the bottom of the map. It used to go
# nowhere; it goes to Terminal Road. The portal sits in its 64 px road strip,
# inside movement_bounds, clear of every stop.
const TRANSIT := {
	"position": Vector2(1448.0, 1010.0),
	"prompt": "Follow the side street to Terminal Road",
	"target": "res://scenes/exploration/terminal_road.tscn",
	"arrival": Vector2(1448.0, 120.0),
}


func _init() -> void:
	map_title = "Sampaguita Street"
	map_hint = "WASD or arrows to walk  \u00b7  Enter at a door or a person  \u00b7  J journal  \u00b7  Esc menu"
	player_spawn = DESK_DOOR + Vector2(0.0, 20.0)


func _build_buildings() -> void:
	super()
	_add_city_building("building-e", DESK_DOOR)
	_add_sign(DESK_DOOR.x, DESK_DOOR.y - SIGN_LIFT, "ANTI-FRAUD")
	_place_exit_door(DESK_DOOR, "Go in to your desk", SessionState.DESK_SCENE)


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


func transit() -> Dictionary:
	return TRANSIT
