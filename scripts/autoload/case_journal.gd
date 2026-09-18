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
	MAIN_MENU_SCENE,
	"res://scenes/prologue/prologue_call.tscn",
	"res://scenes/prologue/prologue_end.tscn",
]

const TAB_TACTICS := "tactics"
## One row per tab, in display order. The id names the `_fill_<id>()` that
## renders it into its page.
const TABS := [
	{"id": TAB_TACTICS, "label": "Tactics  (N)"},
]

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
var confirm_box: VBoxContainer


func _ready() -> void:
	# Must keep running while the tree is paused, or the overlay could not be
	# closed again once it has paused the game beneath it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_pause_menu()
	get_tree().node_added.connect(_on_node_added)
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
		button.pressed.connect(_select_tab.bind(tab_id))
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
	_add_pause_button("Case Journal", open.bind(""))
	_add_pause_button("Tactic Notebook", open.bind(TAB_TACTICS))
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


func _add_pause_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(on_pressed)
	pause_buttons.add_child(button)


func open_pause() -> void:
	if is_pause_open or is_open:
		return
	is_pause_open = true
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
	elif wants_notebook:
		open(TAB_TACTICS)
		get_viewport().set_input_as_handled()


func _pressed(event: InputEvent, action: String, fallback_key: Key) -> bool:
	if InputMap.has_action(action) and event.is_action_pressed(action):
		return true
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == fallback_key


func _on_node_added(_node: Node) -> void:
	_refresh_button_visibility.call_deferred()


func shows_button_in(scene_path: String) -> bool:
	return not HIDDEN_IN_SCENES.has(scene_path)


func _available_here() -> bool:
	var current := get_tree().current_scene
	return shows_button_in(current.scene_file_path if current != null else "")


func _refresh_button_visibility() -> void:
	if open_button == null or is_open or is_pause_open:
		return
	open_button.visible = _available_here()
