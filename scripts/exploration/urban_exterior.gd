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
# bottom-left with its door over the map's default spawn - so walking out of
# it for the first time and being dropped on the street by a test are the same
# place. Clear of the tree at (300, 950) and the first side street at 520.
const DESK_TOP_LEFT := Vector2(88.0, 748.0)

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
		"body": "A cork board on a post at the end of the row, behind cracked plastic. Under a bus schedule and a card for guitar lessons, a barangay notice has been pinned square in the middle and laminated against the rain.\n\nBARANGAY ADVISORY - TELEPHONE SCAMS. Callers pretend to be your bank's fraud department, a tech support line, or a raffle office. Reported number: %s. They will tell you to stay on the line. Hang up. Call your bank using the number on the back of your card. No bank, government office or prize office will ever ask for your OTP.",
		"note": "The last line is the one to remember. A one-time code sent to your phone is the bank checking it is really you. Reading it out to a caller hands them the check.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
		"tactic_id": "repeated_script",
		"cites_number": true,
		"milestone_title": "The Warning Was Already Up",
		"milestone_detail": "A community notice on the street named the operation's number and all three of its scripts - the information existed before the case did.",
	},
	{
		"position": Vector2(700.0, 600.0),
		"title": "Aling Nena, Maria's neighbor",
		"prompt": "Talk to Aling Nena",
		"body": "She is out on the step with a mug of coffee, and she has clearly been watching you go door to door. \"You're the one asking about the calls, no? Come, come.\" She points at Maria's house with her lips. \"I got the same call as Maria. 'Ma'am, this is the fraud department of your bank, somebody is using your account, please stay on the line while we secure it.' Word for word.\" She shakes her head. \"I hung up. Then I asked next door. Same call, same day. Ask Maria.\"",
		"note": "Same lines, same order, two doors apart. A bank calling about your account does not sound exactly like the call your neighbor got. That is a script, and the person reading it does not know who you are.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "repeated_script",
		"milestone_title": "Word For Word, Three Doors Apart",
		"milestone_detail": "Neighbors on one row received identical wording, which is what makes it a script rather than a targeted approach.",
	},
	{
		"position": Vector2(330.0, 216.0),
		"title": "Jomar, on his way to work",
		"prompt": "Talk to Jomar",
		"body": "A young man in a polo and an ID lanyard, checking the road for a jeep. He answers before you finish the question. \"Scam calls? My mother got two. One in March - 'ma'am, your account is compromised.' Then last month, different story - 'ma'am, you have a refund.' Different story, same voice. And both times they said her surname wrong. The same wrong way.\" He laughs, not really amused. \"So it's the same people, right? They just kept her number.\"",
		"note": "Called twice, months apart, with a new story and the same mispronounced name. A number that answers gets kept and worked again. A second call is not bad luck - it means the first call put you on a list.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "reused_victim_list",
		"milestone_title": "Called Twice, Six Weeks Apart",
		"milestone_detail": "One resident was worked twice from the same list under two different scripts - answering once marks a number as live.",
	},
	{
		"position": Vector2(740.0, 216.0),
		"title": "Store owner",
		"prompt": "Talk to the store owner",
		"body": "\"Ah, the poster by the bulletin board? Mine is bigger.\" She points at the window of the sari-sari store, where a sheet of bond paper says DO NOT ANSWER THIS NUMBER - %s in marker. \"Four people came in this month to ask me if that number is really a scam. Four who asked.\" She goes back to counting coins into a jar. \"How many just paid and kept quiet? That, I don't know. People don't come to the store to tell you they got fooled.\"",
		"note": "Four people asked. Nobody knows how many paid. The ones who lost money are the ones who stop talking, so what a street reports is always smaller than what it lost.",
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
		"body": "A man in a work shirt at the curb, one eye on the road. \"Scam calls?\" He laughs. \"Boss, you'd have to be really slow to fall for that. My lola, maybe. Not me - I'd know right away.\" A jeep passes, full, and he doesn't flag it. The laugh fades a little. \"...Why, what do they say when they call?\"",
		"note": "Everybody thinks they would catch it. The scripts count on exactly that: they are built for someone who is busy, tired or in the middle of something, not someone who is slow. His last question is the honest one.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"milestone_title": "\"You'd Have To Be Gullible\"",
		"milestone_detail": "The commonest myth about fraud victims, met on the street - confidence that you would spot it is exactly what the scripts count on.",
	},
	{
		"position": Vector2(1750.0, 950.0),
		"title": "Aling Rosa, Teddy's neighbor",
		"prompt": "Talk to Aling Rosa",
		"body": "An older woman locking her gate, not looking up. \"I stopped answering months ago. They still call. Same number every time - %s - four, five times a week, then nothing for a month, then again.\" The padlock clicks. \"I know what it is now. I just want it to stop. Teddy next door still answers. He's eighty-one, he thinks it's rude not to.\"",
		"note": "The calls do not stop, because a number that once answered stays on the list whatever the person does now. Let unknown numbers go to voicemail - a line that never picks up is the only thing that gets it taken off.",
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
# contains the two side streets ([520,616] and [1400,1496]), formerly trees at y 600
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
# No trees: the only tree tile in the city set is a thin green stalk that read
# as a bottle standing on the grass (removed 2026-09-19). The table and the
# layout test's tree check stay, so a proper tree can be put back as rows here.
const TREE_SPOTS := []
const LAMP_TOP_X := [350.0, 900.0, 1450.0]
const LAMP_BOTTOM_X := [350.0, 900.0, 1300.0]

const NPC_SPOTS := [
	{"x": 330.0, "y": 216.0, "kind": "a", "tint": Color(1, 1, 1, 1)},
	{"x": 1200.0, "y": 408.0, "kind": "b", "tint": Color(1, 1, 1, 1)},
	{"x": 700.0, "y": 600.0, "kind": "a", "tint": Color(0.85, 1.0, 0.85, 1)},
	{"x": 1750.0, "y": 950.0, "kind": "a", "tint": Color(1.0, 0.85, 0.85, 1)},
	{"x": 740.0, "y": 216.0, "kind": "b", "tint": Color(1, 1, 1, 1)},
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
	map_hint = "Move with WASD or arrow keys. Press Enter at a door to interact."


func _build_buildings() -> void:
	super()
	var desk := _add_building(DESK_TOP_LEFT, ROOF_OLIVE_X, BLOCK_BUILDING_SCALE)
	var desk_door := _add_shop_door(desk)
	_add_building_label(desk, "ANTI-FRAUD")
	_place_exit_door(desk_door, "Go in to your desk", SessionState.DESK_SCENE)


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


func transit() -> Dictionary:
	return TRANSIT
