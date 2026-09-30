extends RefCounted

## The menus' look, an RPG title screen: a pixel-font title, a framed window,
## pixel-font buttons and one pointer beside the selected button. Shared by the
## main menu, the credits, the pause menu and Spot the Scam. Preload it (no
## class_name - see AGENTS.md):
##
##     const MenuStyle := preload("res://scripts/systems/menu_style.gd")
##
## Kenney's fonts and RPG UI pack (CC0). Both fonts import with antialiasing
## off and are drawn at multiples of 8, their pixel grid; both are capitals
## only, so they are for labels and short buttons, never for reading text.

const TITLE_FONT := preload("res://assets/art/ui/kenney_kenney-fonts/Fonts/Kenney Pixel Square.ttf")
const BUTTON_FONT := preload("res://assets/art/ui/kenney_kenney-fonts/Fonts/Kenney Mini Square.ttf")
const POINTER_TEXTURE := preload("res://assets/art/ui/kenney_ui-pack-rpg-expansion/PNG/arrowSilver_right.png")

const GOLD := Color(0.96, 0.78, 0.38)
const GOLD_DIM := Color(0.66, 0.5, 0.25)
const CREAM := Color(0.93, 0.9, 0.82)
const WINDOW_FILL := Color(0.06, 0.07, 0.1, 0.94)
## The title's drop: the logo's red. PLAIN_DROP is for a title that must not
## look like a prize (the prologue summary - the scammer's takings).
const TITLE_DROP := Color(0.62, 0.09, 0.08)
const PLAIN_DROP := Color(0.02, 0.02, 0.03)
const BUTTON_FONT_SIZE := 24

## A Button variation that wears the pixel font, for a window whose other
## buttons keep the body font (Spot the Scam's answers).
const PIXEL_BUTTON := &"PixelButton"


## Dresses a PanelContainer as the window: dark fill, gold frame and a faint
## second line inside it. Call it before adding the panel's content - the
## inner line is a child, and has to be drawn first.
static func dress_window(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = WINDOW_FILL
	style.set_border_width_all(3)
	style.border_color = GOLD_DIM
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 18
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		inset.add_theme_constant_override(side, 3)
	panel.add_child(inset)
	var inner_line := Panel.new()
	inner_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line_style := StyleBoxFlat.new()
	line_style.draw_center = false
	line_style.set_border_width_all(1)
	line_style.border_color = Color(GOLD, 0.35)
	line_style.set_corner_radius_all(3)
	inner_line.add_theme_stylebox_override("panel", line_style)
	inset.add_child(inner_line)


## The window's buttons, set as the panel's theme. With pixel_buttons every
## button in it wears the pixel font; without, only those given PIXEL_BUTTON.
static func theme(pixel_buttons: bool = true) -> Theme:
	var menu_theme := Theme.new()
	menu_theme.set_type_variation(PIXEL_BUTTON, &"Button")
	menu_theme.set_font("font", PIXEL_BUTTON, BUTTON_FONT)
	menu_theme.set_font_size("font_size", PIXEL_BUTTON, BUTTON_FONT_SIZE)
	if pixel_buttons:
		menu_theme.set_font("font", "Button", BUTTON_FONT)
		menu_theme.set_font_size("font_size", "Button", BUTTON_FONT_SIZE)
	menu_theme.set_constant("outline_size", "Button", 0)
	menu_theme.set_color("font_color", "Button", CREAM)
	menu_theme.set_color("font_disabled_color", "Button", Color(CREAM, 0.35))
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		menu_theme.set_color(state, "Button", GOLD)
	menu_theme.set_stylebox("normal", "Button", plate(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1)))
	menu_theme.set_stylebox("hover", "Button", plate(Color(GOLD, 0.12), Color(GOLD, 0.7)))
	menu_theme.set_stylebox("pressed", "Button", plate(Color(GOLD, 0.24), GOLD))
	menu_theme.set_stylebox("hover_pressed", "Button", plate(Color(GOLD, 0.24), GOLD))
	menu_theme.set_stylebox("disabled", "Button", plate(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.05)))
	# Focus draws over the state box, so it is the gold edge alone: a button
	# selected from the keyboard lights the same way as a hovered one.
	var focus := plate(Color(0, 0, 0, 0), Color(GOLD, 0.7))
	focus.draw_center = false
	menu_theme.set_stylebox("focus", "Button", focus)
	return menu_theme


static func plate(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(2)
	style.border_color = edge
	style.set_corner_radius_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## Pixel letters over a drop: gold over the logo's red unless told otherwise.
## size: a multiple of 8.
static func style_title(label: Label, size: int, color: Color = GOLD, drop: Color = TITLE_DROP) -> void:
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.03))
	label.add_theme_constant_override("outline_size", size / 6)
	label.add_theme_color_override("font_shadow_color", drop)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", size / 8)
	label.add_theme_constant_override("shadow_outline_size", size / 6)


## A gold rule with a diamond in the middle, under a title.
static func divider(half_width: int = 150) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for index in range(3):
		if index == 1:
			var gem_box := Control.new()
			gem_box.custom_minimum_size = Vector2(12, 12)
			var gem := ColorRect.new()
			gem.color = GOLD
			gem.size = Vector2(8, 8)
			gem.position = Vector2(2, 2)
			gem.pivot_offset = Vector2(4, 4)
			gem.rotation_degrees = 45
			gem_box.add_child(gem)
			row.add_child(gem_box)
			continue
		var rule := ColorRect.new()
		rule.color = Color(GOLD_DIM, 0.9)
		rule.custom_minimum_size = Vector2(half_width, 2)
		rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rule)
	return row


## The pointer: one arrow, left of whichever button holds it, nudging back and
## forth. `owner` runs the nudge, so it must already be in the tree.
static func make_pointer(owner: Node) -> TextureRect:
	var pointer := TextureRect.new()
	pointer.texture = POINTER_TEXTURE
	pointer.modulate = GOLD
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip := POINTER_TEXTURE.get_size()
	pointer.anchor_top = 0.5
	pointer.anchor_bottom = 0.5
	pointer.offset_top = -tip.y / 2.0
	pointer.offset_bottom = tip.y / 2.0
	pointer.offset_left = -tip.x - 16
	pointer.offset_right = -16
	var nudge := owner.create_tween().set_loops()
	nudge.tween_property(pointer, "position:x", pointer.offset_left + 5, 0.4).set_trans(Tween.TRANS_SINE)
	nudge.tween_property(pointer, "position:x", pointer.offset_left, 0.4).set_trans(Tween.TRANS_SINE)
	return pointer


## Selecting any of these buttons (hover or the arrow keys) moves the pointer
## to it. The first one holds it to begin with.
static func carry_pointer(pointer: TextureRect, buttons: Array) -> void:
	for button in buttons:
		(button as Button).focus_entered.connect(func() -> void: point_at(pointer, button))
	if not buttons.is_empty():
		point_at(pointer, buttons[0])


static func point_at(pointer: TextureRect, button: Control) -> void:
	var holder := pointer.get_parent()
	if holder == button:
		return
	if holder:
		holder.remove_child(pointer)
	button.add_child(pointer)


## Hovering selects, so the mouse and the arrow keys move one cursor rather
## than lighting two buttons at once.
static func hover_selects(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus())
