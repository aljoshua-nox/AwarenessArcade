extends Node

## The player's tactic notebook.
##
## Every manipulation tactic in this game used to appear once and scroll away.
## The only durable record was a number on the end-of-case scorecard, which is a
## score rather than the content. What a player should leave holding is a list of
## red flags they could recognise on a real phone call, so that list gets a home
## they can open at any time.
##
## Built as an autoload overlay rather than a scene so it is reachable from the
## prologue, the street, an interview and the office alike, without every one of
## those scenes needing to know it exists.

## Preloaded rather than referenced as a global class - see text_style.gd.
const TextStyle := preload("res://scripts/systems/text_style.gd")

const CATALOGUE_PATH := "res://resources/tactics/tactic_catalogue.json"
const TOGGLE_ACTION := "toggle_notebook"
## The menu is not part of the fiction and has nothing to collect yet.
const HIDDEN_IN_SCENES := ["res://scenes/main_menu/main_menu.tscn"]

var tactics: Array[Dictionary] = []
var is_open: bool = false

var layer: CanvasLayer
var open_button: Button
var panel_root: Control
var entries_box: VBoxContainer
var progress_label: Label


func _ready() -> void:
	# Must keep running while the tree is paused, or the notebook could not be
	# closed again once it has paused the game beneath it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_catalogue()
	_build_ui()
	get_tree().node_added.connect(_on_node_added)
	_refresh_button_visibility.call_deferred()


func _load_catalogue() -> void:
	var file := FileAccess.open(CATALOGUE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open tactic catalogue: %s" % CATALOGUE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Tactic catalogue is not a dictionary")
		return
	for entry in (parsed as Dictionary).get("tactics", []):
		if entry is Dictionary:
			tactics.append(entry)


func has_tactic(tactic_id: String) -> bool:
	for entry in tactics:
		if str(entry.get("id", "")) == tactic_id:
			return true
	return false


func learned_count() -> int:
	var found := 0
	for entry in tactics:
		if SessionState.has_learned_tactic(str(entry.get("id", ""))):
			found += 1
	return found


# --- UI -----------------------------------------------------------------------

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	open_button = Button.new()
	open_button.text = "Notebook  (N)"
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
	title.text = "Tactic Notebook"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)

	progress_label = Label.new()
	column.add_child(progress_label)

	var blurb := Label.new()
	blurb.text = "What these calls actually do, and how to recognise it on a real one. Entries unlock as you meet them."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(blurb)

	# Variable-length content in a fixed-height panel has to scroll, or entries
	# below the fold become unreachable as the list grows.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	entries_box = VBoxContainer.new()
	entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_box.add_theme_constant_override("separation", 14)
	scroll.add_child(entries_box)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(160, 40)
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _rebuild_entries() -> void:
	for child in entries_box.get_children():
		entries_box.remove_child(child)
		child.queue_free()

	var found := learned_count()
	progress_label.text = "%d of %d tactics recorded" % [found, tactics.size()]

	for entry in tactics:
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

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_rebuild_entries()
	panel_root.visible = true
	open_button.visible = false
	# Pausing means reading the notebook never costs the player prologue time,
	# and never lets them walk the map while it is up.
	get_tree().paused = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	panel_root.visible = false
	get_tree().paused = false
	_refresh_button_visibility()


func _unhandled_input(event: InputEvent) -> void:
	var wants_toggle := false
	if InputMap.has_action(TOGGLE_ACTION) and event.is_action_pressed(TOGGLE_ACTION):
		wants_toggle = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		wants_toggle = true
	if wants_toggle:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _on_node_added(_node: Node) -> void:
	_refresh_button_visibility.call_deferred()


func shows_button_in(scene_path: String) -> bool:
	return not HIDDEN_IN_SCENES.has(scene_path)


func _refresh_button_visibility() -> void:
	if open_button == null or is_open:
		return
	var current := get_tree().current_scene
	var path := current.scene_file_path if current != null else ""
	open_button.visible = shows_button_in(path)
