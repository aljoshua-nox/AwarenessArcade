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

# The floor at work. The detective walks this room empty; the shift walks it
# full. Unnamed operators in the pack's four bodies (the street's pedestrians
# wear them too - nobody here has a name, and a bench hides all but a head and
# shoulders). The back row faces the wall, so it is backs above the chairs; the
# front row faces the room over its monitors. The empty chair in the middle of
# the back row is the player's.
const OPERATOR_BODIES := ["Adam", "Alex", "Amelia", "Bob"]
const OPERATOR_SHEET := "res://assets/art/characters/modern_interiors/%s_%s_16x16.png"
# Frames on the pack's sheets: idle runs right, up, left, down; the phone
# sheet's sixth frame is looking down at the phone.
const FRAME_BACK := Rect2(16.0, 0.0, 16.0, 32.0)
const FRAME_FRONT := Rect2(48.0, 0.0, 16.0, 32.0)
const FRAME_PHONE := Rect2(80.0, 0.0, 16.0, 32.0)
# Where a seated operator's sprite ends. Low enough that the chair back (back
# row) or the desk (front row) covers everything below the shoulders.
const BACK_ROW_BOTTOM := DESK_ROW_BACK + 6.0
const FRONT_ROW_BOTTOM := DESK_ROW_FRONT - 42.0
const SEAT_OFFSETS := [-32.0, 0.0, 32.0]
# Seats nobody is in: yours, and a few people on a break.
const EMPTY_SEATS := ["back:660", "back:372", "front:852", "front:468"]

# Half of other people's calls, heard across the floor. Every one is a script
# the player is about to read from: the bank, the prize, the computer, the
# grandson, the electricity, the officer at the gate - and the same moves under
# all of them (don't hang up, don't tell anyone, read me the numbers).
const CHATTER := [
	"Good afternoon po, this is the fraud department of your bank.",
	"Don't hang up, ma'am. The transfer is still pending.",
	"Congratulations! Your entry was drawn this morning.",
	"It's just the release fee, then the prize goes out today.",
	"Sir, your computer has been sending us error reports.",
	"Read me the six numbers, slowly. I'll wait.",
	"If we don't fix this now, the account gets frozen.",
	"Your grandson is safe, Lola, but the bail is due today.",
	"This is the final notice before your electricity is cut.",
	"Stay on the line with me, okay? Don't call anyone else.",
	"It's confidential for now, so don't tell your family yet.",
	"The officer will be at your gate by four.",
]
# A line every second or two, never two on top of each other, never over the
# player or the prompt they are reading.
const CHATTER_FIRST := 0.8
const CHATTER_GAP_MIN := 1.4
const CHATTER_GAP_MAX := 2.2
const CHATTER_HOLD := 2.8
const CHATTER_MAX := 2
const CHATTER_CLEAR_OF_PLAYER := 170.0
const CHATTER_LIFT := 4.0
const CHATTER_TAIL := 7.0
const CHATTER_FILL := Color(0.97, 0.94, 0.89, 0.94)
const CHATTER_INK := Color(0.1, 0.1, 0.13)

# Tests sit down without leaving the scene.
var suppress_scene_change: bool = false
var shift_started: bool = false
# {sprite, head (the top of the head, world space), row}
var operators: Array[Dictionary] = []
# {label, anchor} for every line in the air.
var chatter: Array[Dictionary] = []
var chatter_timer: Timer
var recent_lines: Array[String] = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	map_hint = "WASD or arrows to walk  ·  Enter to examine  ·  Esc menu"
	portal_target_scene = ""


func _ready() -> void:
	rng.randomize()
	super()
	player.use_pack_character(OPERATOR_IDLE, OPERATOR_RUN, OPERATOR_SCALE)
	chatter_timer = Timer.new()
	chatter_timer.one_shot = true
	chatter_timer.timeout.connect(_on_chatter_timer)
	add_child(chatter_timer)
	chatter_timer.start(CHATTER_FIRST)


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

# The benches as the detective will find them, with the shift sitting at them.
# Drawn between the furniture's layers: a back-row operator over the desk and
# monitor (z -9, after them) and under the chair back (z -8); a front-row one
# over the chair (z -12) and under the desk (z -10).
func _build_call_floor() -> void:
	super()
	operators.clear()
	var seat_number := 0
	for x in DESK_COLUMNS:
		for offset in SEAT_OFFSETS:
			var seat_x := float(x) + float(offset)
			for row in ["back", "front"]:
				seat_number += 1
				if EMPTY_SEATS.has("%s:%d" % [row, int(seat_x)]):
					continue
				_seat_operator(seat_number, seat_x, row)


func _seat_operator(seat_number: int, seat_x: float, row: String) -> void:
	var body := str(OPERATOR_BODIES[(seat_number * 3 + (1 if row == "front" else 0)) % OPERATOR_BODIES.size()])
	var frame := FRAME_BACK
	var sheet := "idle"
	if row == "front":
		frame = FRAME_FRONT
		if seat_number % 3 == 0:
			frame = FRAME_PHONE
			sheet = "phone"
	var sprite := Sprite2D.new()
	sprite.texture = load(OPERATOR_SHEET % [body, sheet])
	sprite.region_enabled = true
	sprite.region_rect = frame
	sprite.centered = true
	sprite.scale = Vector2(OPERATOR_SCALE, OPERATOR_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -9 if row == "back" else -11
	var height := frame.size.y * OPERATOR_SCALE
	var bottom := BACK_ROW_BOTTOM if row == "back" else FRONT_ROW_BOTTOM
	sprite.position = Vector2(seat_x, bottom - height * 0.5)
	decor.add_child(sprite)
	operators.append({"sprite": sprite, "head": Vector2(seat_x, bottom - height), "row": row})
	# Somebody breathing, shifting in a chair: a pixel or two, each on their own beat.
	var settle := sprite.create_tween().set_loops()
	settle.tween_interval(rng.randf_range(0.6, 2.4))
	settle.tween_property(sprite, "position:y", sprite.position.y - 2.0, 0.3)
	settle.tween_property(sprite, "position:y", sprite.position.y, 0.3)


# --- Chatter ------------------------------------------------------------------

func _on_chatter_timer() -> void:
	_say_something()
	if not shift_started:
		chatter_timer.start(rng.randf_range(CHATTER_GAP_MIN, CHATTER_GAP_MAX))


## One overheard line over one operator, or null when nobody is free to say
## one: the shift has started, the player is reading, two lines are already in
## the air, or no free operator's bubble would clear the player, the prompt
## over whatever they are standing at, and the lines already up.
func _say_something() -> Label:
	_forget_finished_lines()
	if shift_started or inspection_open or chatter.size() >= CHATTER_MAX or operators.is_empty():
		return null
	var line := _pick_line()
	var candidates := operators.duplicate()
	candidates.shuffle()
	for speaker in candidates:
		var head: Vector2 = speaker["head"]
		if head.distance_to(player.global_position) < CHATTER_CLEAR_OF_PLAYER:
			continue
		var label := _speech_bubble(head, line)
		if not _bubble_is_clear(label):
			remove_child(label)
			label.queue_free()
			continue
		recent_lines.append(line)
		if recent_lines.size() > 4:
			recent_lines.pop_front()
		label.modulate.a = 0.0
		var fade := label.create_tween()
		fade.tween_property(label, "modulate:a", 1.0, 0.15)
		fade.tween_interval(CHATTER_HOLD)
		fade.tween_property(label, "modulate:a", 0.0, 0.4)
		fade.tween_callback(label.queue_free)
		chatter.append({"label": label, "anchor": head, "fade": fade})
		return label
	return null


# A line is placed clear of the player and the prompt, but the player walks
# on. When they walk under one, or a prompt comes up where one is, the line
# gets out of the way: the player and the thing they can press Enter on come
# first.
func _process(_delta: float) -> void:
	for entry in chatter:
		if bool(entry.get("hushed", false)) or not is_instance_valid(entry["label"]):
			continue
		var label: Label = entry["label"]
		var rect := _bubble_rect(label)
		var in_the_way := rect.intersects(_player_rect())
		if prompt_bubble.visible and rect.intersects(Rect2(prompt_bubble.global_position, prompt_bubble.size)):
			in_the_way = true
		if in_the_way:
			entry["hushed"] = true
			var running: Tween = entry.get("fade", null)
			if running != null and running.is_valid():
				running.kill()
			var out := label.create_tween()
			out.tween_property(label, "modulate:a", 0.0, 0.12)
			out.tween_callback(label.queue_free)


func _forget_finished_lines() -> void:
	var still_up: Array[Dictionary] = []
	for entry in chatter:
		if is_instance_valid(entry["label"]) and not (entry["label"] as Node).is_queued_for_deletion() \
				and not bool(entry.get("hushed", false)):
			still_up.append(entry)
	chatter = still_up


func _speech_bubble(head: Vector2, line: String) -> Label:
	var label: Label = PromptBubble.new()
	add_child(label)
	_style_as_speech(label)
	label.show_above(head, "\"%s\"" % line, CHATTER_LIFT + CHATTER_TAIL)
	var room := get_viewport().get_visible_rect().size
	var centered_x := label.global_position.x
	label.global_position.x = clampf(centered_x, SIDE_WALL_WIDTH + 4.0,
		room.x - SIDE_WALL_WIDTH - 4.0 - label.size.x)
	# The tail points at whoever said it, even when the bubble was nudged
	# inside the room.
	var tail_x := label.size.x * 0.5 + (centered_x - label.global_position.x)
	var tail := Polygon2D.new()
	tail.color = CHATTER_FILL
	tail.polygon = PackedVector2Array([
		Vector2(tail_x - 6.0, label.size.y - 1.0),
		Vector2(tail_x + 6.0, label.size.y - 1.0),
		Vector2(tail_x, label.size.y + CHATTER_TAIL),
	])
	label.add_child(tail)
	return label


# Clear of the player, of the prompt they may be reading, and of every line
# already up.
func _bubble_is_clear(label: Label) -> bool:
	var rect := _bubble_rect(label).grow(6.0)
	if rect.intersects(_player_rect()):
		return false
	if prompt_bubble.visible and rect.intersects(Rect2(prompt_bubble.global_position, prompt_bubble.size)):
		return false
	for entry in chatter:
		if is_instance_valid(entry["label"]) and rect.intersects(_bubble_rect(entry["label"])):
			return false
	return true


func _player_rect() -> Rect2:
	return Rect2(player.global_position - Vector2(24.0, 60.0), Vector2(48.0, 72.0))


func _bubble_rect(label: Label) -> Rect2:
	return Rect2(label.global_position, label.size + Vector2(0.0, CHATTER_TAIL))


# Any line but the last few, so the floor does not repeat itself in a breath.
func _pick_line() -> String:
	var choices: Array[String] = []
	for line in CHATTER:
		if not recent_lines.has(str(line)):
			choices.append(str(line))
	return choices[rng.randi_range(0, choices.size() - 1)]


# A speech bubble, not a prompt: the prompts over doors and boards are dark
# plates the player can press Enter on, and these are other people talking.
func _style_as_speech(label: Label) -> void:
	label.z_index = 55
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", CHATTER_INK)
	var box := StyleBoxFlat.new()
	box.bg_color = CHATTER_FILL
	box.set_corner_radius_all(8)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 4.0
	label.add_theme_stylebox_override("normal", box)


func _clear_chatter() -> void:
	for entry in chatter:
		if is_instance_valid(entry["label"]):
			(entry["label"] as Node).queue_free()
	chatter.clear()


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
	chatter_timer.stop()
	_clear_chatter()
	prompt_bubble.hide_bubble()
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	if suppress_scene_change:
		return
	_transition_to_scene(SessionState.PROLOGUE_CALL_SCENE, "")
