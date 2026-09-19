extends Label

## The prompt that floats above whatever the player can press Enter on.
##
## Door, stop and station prompts used to print in the top-left corner of the
## HUD, a screen away from the thing they were about. This is a Label in world
## space - a child of the map, not of the HUD layer - so it sits over the door
## it names and moves with the camera like everything else on the map. One per
## scene; the scene points it at the active thing and hides it when nothing is.
##
## Preloaded and instanced with `.new()` from the scene scripts - not a
## `class_name`, for the reason text_style.gd gives.

const FILL := Color(0.06, 0.07, 0.10, 0.88)
const EDGE := Color(0.79, 0.83, 0.88, 0.55)


func _ready() -> void:
	z_index = 60
	visible = false
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 15)
	var box := StyleBoxFlat.new()
	box.bg_color = FILL
	box.border_color = EDGE
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 5.0
	add_theme_stylebox_override("normal", box)


## Put `prompt` centered above `anchor`, its bottom edge `lift` pixels up.
func show_above(anchor: Vector2, prompt: String, lift: float) -> void:
	text = prompt
	reset_size()
	size = get_minimum_size()
	global_position = anchor - Vector2(size.x * 0.5, lift + size.y)
	visible = true


func hide_bubble() -> void:
	visible = false
