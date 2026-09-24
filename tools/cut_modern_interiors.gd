extends Node

## Cuts the parts named in scripts/exploration/interior_parts.gd out of LimeZu's
## Modern Interiors (free) into assets/art/maps/modern_interiors/. The output
## sheets keep the pack's layout, so a rect in the parts table is the same rect
## in either, but hold only the parts the rooms use: the free pack is
## non-commercial and stays out of the public repo (.gitignore). Needs the pack
## at assets/Modern_Interiors_Free_v2.2/. Then `--import`.
##
##   godot --headless --path . res://tools/cut_modern_interiors.tscn

const Parts := preload("res://scripts/exploration/interior_parts.gd")

const PACK := "res://assets/Modern_Interiors_Free_v2.2/Modern tiles_Free/Interiors_free/16x16/"


func _ready() -> void:
	var interiors := _load(PACK + "Interiors_free_16x16.png")
	var room := _load(PACK + "Room_Builder_free_16x16.png")
	if interiors == null or room == null:
		get_tree().quit(1)
		return

	var parts: Array[Rect2i] = []
	for rect in Parts.PARTS.values():
		parts.append(Rect2i(rect))
	_save(_masked(interiors, parts), Parts.INTERIORS_SHEET)

	var room_parts: Array[Rect2i] = []
	for row in Parts.WALL_ROWS.values():
		room_parts.append(Rect2i(int(Parts.WALL_COLUMN_X), int(row) * 16, 16, 32))
	for rect in Parts.FLOORS.values():
		room_parts.append(Rect2i(rect))
	_save(_masked(room, room_parts), Parts.ROOM_BUILDER_SHEET)
	get_tree().quit()


func _load(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		push_error("missing %s - the free pack is not in the repo; put it back under assets/" % path)
	return image


func _masked(source: Image, keep: Array[Rect2i]) -> Image:
	var out := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	var converted := source.duplicate() as Image
	converted.convert(Image.FORMAT_RGBA8)
	for rect in keep:
		out.blit_rect(converted, rect, rect.position)
	return out


func _save(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	image.save_png(ProjectSettings.globalize_path(path))
	print("wrote ", path)
