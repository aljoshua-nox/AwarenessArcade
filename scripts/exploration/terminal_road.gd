extends "res://scripts/exploration/district_exterior.gd"

## Terminal Road: the second district, down the terrace's second side street.
## A working district where the terrace is a residential one - a frontage row
## with a boarding house, a canteen and the tower the company owns; a bus bay;
## a construction site with the same company's name on the hoarding; two
## houses on the grass. The same list reaches here as reaches the terrace, and
## that is the point: a list is a spreadsheet, not a neighbourhood.
##
## The layout is the one in the workspace's future-map/terminal-road.png,
## drawn with the same primitives at the same coordinates. The doors arrive
## with the people who live behind them; until then a unit is a shopfront.

const BUSES_TEXTURE: Texture2D = preload("res://assets/art/maps/urban/buses_cars.png")

const CASE_TRISH := "res://resources/cases/interview_case_008.json"
const CASE_BEA := "res://resources/cases/interview_case_009.json"
const CASE_JOEL := "res://resources/cases/interview_case_010.json"
const CASE_CARMEN := "res://resources/cases/interview_case_012.json"
const CASE_DENNIS := "res://resources/cases/interview_case_013.json"

# Who lives behind which door. Trish in the first house on the grass, the one
# home on this map; Bea in the boarding house at the head of the frontage row,
# two doors from the canteen she eats at; Joel at the site office on the plot -
# interviewed at work, which is where the call found him; Carmen at the canteen,
# in her kitchen doorway; Dennis in the tower's lobby - the one operator who
# goes upstairs, and the player gets as far as reception and no further.
# "site" and "tower" are this district's own rows: one building each, placed
# in _build_buildings.
const INTERVIEWEES := [
	{"case": CASE_TRISH, "label": "TRISH", "prompt": "Speak with Patricia Lim", "row": "block", "slot": 0},
	{"case": CASE_BEA, "label": "BEA", "prompt": "Speak with Bea Santiago", "row": "street", "slot": 0},
	{"case": CASE_JOEL, "label": "JOEL", "prompt": "Speak with Joel Abad", "row": "site", "slot": 0},
	{"case": CASE_CARMEN, "label": "CARMEN", "prompt": "Speak with Carmen Salazar", "row": "street", "slot": CANTEEN_ROW_INDEX},
	{"case": CASE_DENNIS, "label": "DENNIS", "prompt": "Interrogate Dennis Mercado", "row": "tower", "slot": 0},
]

# Kenney sheet coordinates for the ground and props this district adds.
const TILE_DIRT := Vector2i(14, 26)
const TILE_FENCE := Vector2i(21, 14)
const TILE_GLASS := Vector2i(13, 6)
const TILE_CONE := Vector2i(14, 18)
const TILE_CRATE := Vector2i(13, 16)
const TILE_HAZARD := Vector2i(15, 17)
const TILE_AWNING := Vector2i(25, 12)

# Regions of props.png and buses_cars.png.
const BUS_STOP_SIGN_RECT := Rect2(2.0, 74.0, 20.0, 56.0)
const BENCH_RECT := Rect2(266.0, 150.0, 34.0, 30.0)
const VENDING_RECT := Rect2(206.0, 150.0, 28.0, 40.0)
const SKIP_RECT := Rect2(2.0, 4.0, 26.0, 36.0)
const BUS_TEAL_RECT := Rect2(2.0, 2.0, 28.0, 53.0)
const BUS_YELLOW_RECT := Rect2(88.0, 2.0, 28.0, 53.0)

# The lower band, left to right: bus bay | side street | site | side street | grass.
const BUS_BAY_END := 560.0
const SITE_START := 656.0
const SITE_END := 1300.0
const GRASS_START := 1396.0
const SIDE_STREET_X_POSITIONS := [560.0, 1300.0]
# The arrival street cuts the frontage row from the top edge to the pavement,
# at the same x as the terrace's second side street: it is the same street.
const ARRIVAL_STREET_X := 1400.0

# The frontage row. Slot 0 is the boarding house (Bea), slot 1 the canteen
# (Carmen); 2 and 3 are the internet cafe and the remittance counter, whose
# stops stand outside; 4 and 5 are past the arrival street, one of them spare.
# The tower is not a row unit - see _build_buildings.
const BUILDING_ROW := [
	{"x": 90.0, "color": ROOF_MAUVE_X},
	{"x": 320.0, "color": ROOF_BRICK_X},
	{"x": 550.0, "color": ROOF_TAN_X},
	{"x": 780.0, "color": ROOF_OLIVE_X},
	{"x": 1560.0, "color": ROOF_ROSE_X},
	{"x": 1750.0, "color": ROOF_MAUVE_X},
]
const CANTEEN_ROW_INDEX := 1

# The tower: wider and taller than a row unit, its roof above the top of the
# map - the one building on either district you cannot see the top of.
const TOWER_TOP_LEFT := Vector2(1010.0, -80.0)
const TOWER_SCALE := Vector2(4.6, 2.92)
const TOWER_LABEL_Y := 120.0
const TOWER_DOOR_LABEL_Y := 150.0

# The site office: a squat unit on the plot - Joel's door, row "site" slot 0.
const SITE_OFFICE_TOP_LEFT := Vector2(760.0, 560.0)
const SITE_OFFICE_SCALE := Vector2(3.4, 1.15)
const SITE_FENCE_Y := 428.0
const SITE_GATE := Vector2(940.0, 1004.0)
const HOARDING_BASE := Vector2(1130.0, 505.0)

# Trish's house (slot 0, when she is written) and a neighbour's.
const BLOCK_BUILDINGS := [
	{"x": 1470.0, "color": ROOF_ROSE_X},
	{"x": 1720.0, "color": ROOF_TAN_X},
]

const CAR_SPOTS := [200.0, 700.0, 1250.0, 1750.0]
# No trees - see urban_exterior.gd. The table stays for the layout test.
const TREE_SPOTS := []
# Alternating sides along the road (see district_exterior.gd), the top ones in
# the gaps between buildings, the bottom ones clear of the side streets' mouths.
const LAMP_TOP_X := [282.0, 972.0, 1732.0]
const LAMP_BOTTOM_X := [500.0, 1200.0]

# The conductor, the cafe owner, the remittance clerk, the site worker in the
# gate, the neighbour on the grass. Their stops arrive with the characters
# whose stories they set up; until then they are pedestrians.
const NPC_SPOTS := [
	{"x": 480.0, "y": 620.0, "kind": "b", "tint": Color(1, 1, 1, 1)},
	{"x": 620.0, "y": 216.0, "kind": "b", "tint": Color(1, 1, 1, 1)},
	{"x": 860.0, "y": 216.0, "kind": "a", "tint": Color(1, 1, 1, 1)},
	{"x": 972.0, "y": 470.0, "kind": "a", "tint": Color(1.0, 0.92, 0.75, 1)},
	{"x": 1660.0, "y": 780.0, "kind": "a", "tint": Color(0.85, 1.0, 0.85, 1)},
]

# The street's stops. Two need no character - the company's name on the tower
# and on the site hoarding; `cites_name` prints SessionState.COMPANY_NAME the
# way `cites_number` prints the operation's number on the terrace, the call
# floor's bonus board will print it too, and reading both earns the pattern
# milestone. The rest arrive with the people whose stories they set up: the
# cafe owner and the neighbor with Trish and Bea, the site worker with Joel,
# the remittance clerk with Carmen. Nothing points anything out.
# The directory beside the tower's doors - clear of the door itself, which is
# Dennis's - keeps the company's name on the street.
const DIRECTORY_STOP_POSITION := Vector2(1215.0, 262.0)
const STREET_STOPS := [
	{
		"position": DIRECTORY_STOP_POSITION,
		"is_fixture": true,
		"title": "Building directory",
		"prompt": "Read the building directory",
		"body": "A brass directory beside the glass doors, polished, the letters set by hand. %s. 3F - CUSTOMER SERVICE. 4F - TECHNICAL SUPPORT. 5F - HOLDINGS, NO ELEVATOR ACCESS. Under it, on an easel, a smaller sign: RECEPTION CLOSED TO THE PUBLIC.",
		"note": "A business that scams people still has a lobby and a directory. The company's name is real; so are the floor numbers. It is the two words after them that are not - and the floor without elevator access is the one the directory says least about.",
		"note_color": TextStyle.COLOR_HINT,
		"marker": TextStyle.MARK_HINT,
		"cites_name": true,
		"milestone_title": "The Name On The Door",
		"milestone_detail": "The tower on Terminal Road carries a company name, two floors described as services, and a fifth floor with no elevator access - the operation has a front door the public is not allowed through, and an owner above it.",
	},
	{
		"position": Vector2(1130.0, 535.0),
		"is_fixture": true,
		"title": "Site billboard",
		"prompt": "Read the billboard",
		"body": "A painted board on the site fence, sun-faded at one corner: ANOTHER DEVELOPMENT BY %s. Under it, smaller, a completion date that has already passed. Beyond the fence a half-poured floor and a stack of crates that has been there long enough to grow a tarpaulin.",
		"note": "The same name is on a building down the road. A company that puts its name on a billboard is asking to be looked up - and a company that puts it on a locked door is asking not to be.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"cites_name": true,
		"milestone_title": "The Name On The Fence",
		"milestone_detail": "The construction site on Terminal Road is branded with the same company as the tower - the operation has more than one address.",
	},
	{
		"position": Vector2(620.0, 216.0),
		"title": "Internet cafe owner",
		"prompt": "Talk to the cafe owner",
		"body": "He's wiping a keyboard with a rag, the door propped open for the heat. \"The job ad? It's been on my board since March.\" He nods at a corkboard inside, layered with flyers. \"Customer service rep, no experience needed, training provided, five slots left. The kids take a photo of it. Then they come back and cash in the 'training fee' at my counter, because the ad says to, and I get my cut like with any cash-in.\" He puts the keyboard down. \"I'm not proud of it, ha. I also can't tell which job ads are real. Nobody can.\"",
		"note": "Nobody pays to get hired. A fee before the first day of work - training, uniform, processing, 'reservation' - is the product. The job is just the packaging.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "advance_fee",
		"milestone_title": "The Ad On The Board",
		"milestone_detail": "The same job advertisement has hung in the internet cafe for months - applicants pay the fee at the counter under it, and the counter takes its cut either way.",
	},
	{
		"position": Vector2(860.0, 216.0),
		"title": "Remittance clerk",
		"prompt": "Talk to the clerk",
		"body": "The window is half open with an electric fan going behind it. \"Ate Carmen from the canteen? Yes, I remember. Six o'clock, still in her apron, phone on her shoulder.\" She counts out someone's change while she talks. \"I asked her three times - ma'am, are you sure, who is this account name? She said it's the electric company. I told her the electric company has an office two streets from here, open until seven. She said there's no time, they'll cut the line by six-thirty.\" The change slides across the counter. \"So I sent it. It's not my money. I ask three times, then I send it.\"",
		"note": "The fee is invented, and the deadline is there so nobody checks. A real bill has an office and a company name on it. A 'reconnection fee' to a personal account, due in thirty minutes, is a fee for nothing - the thirty minutes is the whole trick.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "invented_fee",
		"milestone_title": "She Asked Three Times",
		"milestone_detail": "The remittance clerk asks every customer who the money is for, and sends it anyway - the last check before a scam completes is a counter that is not allowed to say no.",
	},
	{
		"position": Vector2(972.0, 470.0),
		"title": "Ricky, one of Joel's crew",
		"prompt": "Talk to Ricky",
		"body": "He's leaning on the gatepost with an unlit cigarette. \"Kuya Joel? He took a call in the middle of a pour. Middle of it, ha.\" He shakes his head. \"Case number, warrant, an officer coming to the gate at four o'clock. He went white. I've seen that man take a beam on the shoulder and just keep going. He went white.\" The cigarette goes behind his ear. \"He walked out to the road for twenty minutes. Came back, finished the pour like nothing happened. Then he didn't talk to anybody for a week.\"",
		"note": "Fear aimed at what a man cannot afford to lose - not the money, the day's work. A foreman who cannot leave a pour will pay to be left alone. The script knew that before it dialed.",
		"note_color": TextStyle.COLOR_TACTIC,
		"marker": TextStyle.MARK_TACTIC,
		"tactic_id": "manufactured_fear",
		"milestone_title": "He Went White Mid-Pour",
		"milestone_detail": "A site worker watched the foreman take the warrant call - the fear was aimed at the day he could not lose, not at the money.",
	},
	{
		"position": Vector2(1660.0, 780.0),
		"title": "Tita Baby, Trish's neighbor",
		"prompt": "Talk to Tita Baby",
		"body": "A woman watering plants in front of the house next to the pink one, who lowers her voice. \"The Lim girl? Trish? Paid for a job that didn't exist. Everyone on this row knows. Nobody says it in front of her mother.\" She shrugs, not unkindly. \"My nephew almost did the same last year. Same ad. The only reason he didn't is he didn't have the two thousand.\"",
		"note": "Being too broke to pay the fee is not the same as seeing through it. And the ones who could pay are the ones who go quiet - what a scam costs a street is never the number of reports.",
		"note_color": TextStyle.COLOR_WRONG,
		"marker": TextStyle.MARK_HARM,
		"milestone_title": "Nobody Says It In Front Of Her Mother",
		"milestone_detail": "A whole row knows about a young woman's lost fee and keeps it from her family - the silence around a scam is part of how it keeps running.",
	},
]

const PATTERN_MILESTONE := "One Name, More Than One Sign"
const PATTERN_DETAIL := "The company on the tower's locked door is the company on the site billboard down the road - the same name, on the building you cannot enter and the ground it is buying."

# The arrival street's portal, at its head; the terrace's exit is the same
# street's foot. Arriving puts the player just below it, facing into the district.
const TRANSIT := {
	"position": Vector2(1448.0, 60.0),
	"prompt": "Back up the side street to Sampaguita Street",
	"target": "res://scenes/exploration/urban_exterior.tscn",
	"arrival": Vector2(1448.0, 950.0),
}


func _init() -> void:
	map_title = "Terminal Road"
	map_hint = "WASD or arrows to walk  \u00b7  Enter at a door or a person  \u00b7  J journal  \u00b7  Esc menu"
	player_spawn = Vector2(1448.0, 120.0)


func interviewees() -> Array:
	return INTERVIEWEES


func building_row() -> Array:
	return BUILDING_ROW


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


func slot_count(row: String) -> int:
	if row == "site" or row == "tower":
		return 1
	return super(row)


# The arrival street counts as ground nothing may be built on, like the two
# below the road.
func obstacle_rects() -> Array[Rect2]:
	var rects := super()
	rects.append(Rect2(Vector2(ARRIVAL_STREET_X, 0.0), Vector2(SIDE_STREET_WIDTH, TOP_PAVEMENT_END)))
	return rects


# --- Building it ---------------------------------------------------------------

# The three bands are the terrace's. What is under them is not grass: a bus
# bay on pavement, a dirt plot behind a fence, and grass only at the far end.
func _build_ground() -> void:
	_add_tiled_band(TILE_SIDEWALK, 0.0, TOP_PAVEMENT_END, MAP_WIDTH)
	_add_tiled_band(TILE_ROAD, TOP_PAVEMENT_END, ROAD_HEIGHT, MAP_WIDTH)
	_add_tiled_band(TILE_SIDEWALK, ROAD_END, SIDEWALK_HEIGHT, MAP_WIDTH)

	var lower_height := MAP_HEIGHT - BOTTOM_PAVEMENT_END
	_add_tiled_rect(TILE_SIDEWALK, Vector2(0.0, BOTTOM_PAVEMENT_END), Vector2(BUS_BAY_END, lower_height))
	_add_tiled_rect(TILE_DIRT, Vector2(SITE_START, BOTTOM_PAVEMENT_END), Vector2(SITE_END - SITE_START, lower_height))
	_add_tiled_rect(TILE_GRASS, Vector2(GRASS_START, BOTTOM_PAVEMENT_END), Vector2(MAP_WIDTH - GRASS_START, lower_height))
	for street_x in SIDE_STREET_X_POSITIONS:
		_add_side_street(street_x, ROAD_END, MAP_HEIGHT, SIDEWALK_HEIGHT)
	_add_side_street(ARRIVAL_STREET_X, 0.0, TOP_PAVEMENT_END, SIDEWALK_HEIGHT, true)

	# The bus bay: painted bays, two buses in them, the sign, somewhere to sit.
	for bay_x in [110.0, 260.0, 410.0]:
		_add_outline(Rect2(Vector2(bay_x - 40.0, 470.0), Vector2(80.0, 250.0)), Color(1.0, 0.84, 0.35, 0.7))
	_add_prop(BUSES_TEXTURE, BUS_TEAL_RECT, Vector2(110.0, 658.0), 2.2, true)
	_add_prop(BUSES_TEXTURE, BUS_YELLOW_RECT, Vector2(260.0, 658.0), 2.2, true)
	_add_prop(PROPS_TEXTURE, BUS_STOP_SIGN_RECT, Vector2(470.0, 560.0), 1.6)
	_add_prop(PROPS_TEXTURE, BENCH_RECT, Vector2(150.0, 800.0), 1.8, true)
	_add_prop(PROPS_TEXTURE, BENCH_RECT, Vector2(150.0, 860.0), 1.8, true)
	_add_prop(PROPS_TEXTURE, VENDING_RECT, Vector2(400.0, 900.0), 1.7, true)

	# The site: a fence with a gate, and the mess of a job that has stalled.
	_add_fence(SITE_START, SITE_END, SITE_FENCE_Y, SITE_GATE, TILE_FENCE)
	for cone in [Vector2(700.0, 520.0), Vector2(760.0, 520.0), Vector2(1240.0, 520.0), Vector2(1180.0, 1000.0)]:
		_add_tile_sprite(TILE_CONE, cone)
	for crate in [Vector2(1150.0, 640.0), Vector2(1190.0, 640.0), Vector2(1170.0, 610.0)]:
		_add_tile_sprite(TILE_CRATE, crate)
	_add_tiled_rect(TILE_HAZARD, Vector2(700.0, 860.0), Vector2(160.0, 96.0))
	_add_prop(PROPS_TEXTURE, SKIP_RECT, Vector2(1230.0, 900.0), 2.0, true)
	_add_signboard(HOARDING_BASE, ["ANOTHER DEVELOPMENT BY", SessionState.COMPANY_NAME])


func _build_buildings() -> void:
	super()

	# The canteen's awning, over slot 1's door.
	var canteen: Dictionary = BUILDING_ROW[CANTEEN_ROW_INDEX]
	for x in range(int(canteen["x"]) + 4, int(canteen["x"]) + 150, 32):
		_add_tile_sprite(TILE_AWNING, Vector2(float(x) + 16.0, 156.0))

	# The tower, faced in glass, named. Its lobby is the stop at its door.
	var tower := _add_building(TOWER_TOP_LEFT, ROOF_TAN_X, TOWER_SCALE)
	for y in range(int(TOWER_TOP_LEFT.y), int(tower.end.y) - 24, 32):
		for x in range(int(TOWER_TOP_LEFT.x) + 8, int(tower.end.x) - 24, 32):
			_add_tile_sprite(TILE_GLASS, Vector2(float(x) + 16.0, float(y) + 16.0))
	var tower_door := _add_shop_door(tower)
	_add_building_label(tower, SessionState.COMPANY_NAME.split(" ")[0], TOWER_LABEL_Y)
	_place_interviewee_door("tower", 0, tower, tower_door, TOWER_DOOR_LABEL_Y)

	# The site office, inside the fence. Its door is a row of its own.
	var site_office := _add_building(SITE_OFFICE_TOP_LEFT, ROOF_OLIVE_X, SITE_OFFICE_SCALE)
	var site_door := _add_shop_door(site_office)
	_place_interviewee_door("site", 0, site_office, site_door)
