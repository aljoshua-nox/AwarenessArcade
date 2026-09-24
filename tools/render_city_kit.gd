extends Node

## Renders the street buildings out of Kenney's City Kit (Commercial), which is
## a 3D kit, into the flat sprites the streets draw. Each model is shot once,
## straight at its front and tilted down, so it reads like the rest of the
## top-down map, with its walls repainted. Run it after adding a row to JOBS:
##
##   godot --path . res://tools/render_city_kit.tscn
##
## then `godot --headless --path . --import` so the new PNGs get their sidecars.
## The kit sits in a .gdignore'd folder, so the models are read with
## GLTFDocument at runtime and never imported or shipped - only these PNGs are.

const MODELS := "res://assets/kenney_city-kit-commercial_2.1/Models/GLB format/%s.glb"
const COLORMAP := "res://assets/kenney_city-kit-commercial_2.1/Models/GLB format/Textures/colormap.png"
const OUT_DIR := "res://assets/art/maps/city_kit/"

const PITCH_DEGREES := 30.0
# Source pixels per model unit; the streets draw the sprites at 2x.
const PIXELS_PER_UNIT := 88.0

# Regions of the kit's colormap: the wall swatch every building paints its
# facade from, and the dark roof deck (it also darkens the shopfront piers),
# lifted to concrete so the roofs do not read as holes in the map.
const WALL_SWATCH := Rect2i(192, 256, 64, 128)
const ROOF_SWATCH := Rect2i(64, 256, 64, 128)
const ROOF_CONCRETE := Color(0.50, 0.49, 0.46)

const PAINTS := {
	"cream": Color(1.0, 0.93, 0.78),
	"mint": Color(0.78, 0.93, 0.84),
	"peach": Color(1.0, 0.82, 0.70),
	"sky": Color(0.80, 0.90, 1.0),
	"lemon": Color(1.0, 0.95, 0.70),
	"lilac": Color(0.92, 0.86, 0.98),
	"greige": Color(0.84, 0.83, 0.78),
}

# [model, paint] - an empty paint keeps the kit's own walls. The file is
# "<model>_<paint>.png", or "<model>.png" unpainted.
const JOBS := [
	["building-a", "cream"], ["building-a", "peach"],
	["building-b", "lilac"], ["building-b", "mint"],
	["building-c", "cream"], ["building-c", "lilac"], ["building-c", "mint"],
	["building-c", "peach"], ["building-c", "sky"],
	["building-d", "cream"], ["building-d", "lemon"],
	["building-e", ""], ["building-e", "mint"],
	["building-f", "peach"],
	["building-g", "cream"], ["building-g", "sky"],
	["building-h", ""],
	["building-l", "greige"],
	["building-skyscraper-e", ""],
]

var colormap: Image
var viewport: SubViewport
var world: Node3D
var camera: Camera3D


func _ready() -> void:
	colormap = Image.load_from_file(ProjectSettings.globalize_path(COLORMAP))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_stage()
	_run.call_deferred()


func _run() -> void:
	for job in JOBS:
		await _render(str(job[0]), str(job[1]))
	get_tree().quit()


func _build_stage() -> void:
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -28.0, 0.0)
	sun.light_energy = 0.75
	world.add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.01
	camera.far = 100.0
	world.add_child(camera)


func _render(model: String, paint: String) -> void:
	var building := _load_model(model)
	if building == null:
		return
	world.add_child(building)
	# The kit's fronts face -Z; turn them to the camera.
	building.rotation_degrees.y = 180.0
	var texture := _painted_colormap(paint)
	for node in building.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var original := mesh_instance.mesh.surface_get_material(surface) as StandardMaterial3D
			var material := original.duplicate() as StandardMaterial3D if original else StandardMaterial3D.new()
			material.albedo_texture = texture
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mesh_instance.set_surface_override_material(surface, material)

	# Frame the model's bounds exactly, at a fixed pixels-per-unit, so every
	# building comes out at the same scale.
	var bounds := _bounds(building)
	var pitch := deg_to_rad(PITCH_DEGREES)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.global_position = bounds.get_center() + Vector3(0.0, sin(pitch), cos(pitch)) * 20.0
	var to_camera := camera.global_transform.affine_inverse()
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for i in range(8):
		var corner := to_camera * bounds.get_endpoint(i)
		low = Vector2(minf(low.x, corner.x), minf(low.y, corner.y))
		high = Vector2(maxf(high.x, corner.x), maxf(high.y, corner.y))
	var middle := (low + high) * 0.5
	camera.global_position += camera.global_transform.basis.x * middle.x + camera.global_transform.basis.y * middle.y
	var size := Vector2i(ceili((high.x - low.x) * PIXELS_PER_UNIT) + 2, ceili((high.y - low.y) * PIXELS_PER_UNIT) + 2)
	viewport.size = size
	camera.size = float(size.y) / PIXELS_PER_UNIT

	for i in range(3):
		await RenderingServer.frame_post_draw
	var file := model + ("_" + paint if paint != "" else "") + ".png"
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("rendered %s %s" % [file, size])
	building.queue_free()
	await get_tree().process_frame


func _load_model(model: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(MODELS % model), state)
	if error != OK:
		push_error("could not read %s (%d)" % [model, error])
		return null
	return document.generate_scene(state) as Node3D


func _painted_colormap(paint: String) -> ImageTexture:
	var image := colormap.duplicate() as Image
	_fill_swatch(image, ROOF_SWATCH, ROOF_CONCRETE, false)
	if paint != "":
		_fill_swatch(image, WALL_SWATCH, PAINTS[paint], true)
	return ImageTexture.create_from_image(image)


# `tint` multiplies the swatch's own shading; otherwise the swatch is replaced
# by `color`, keeping its gradient.
func _fill_swatch(image: Image, region: Rect2i, color: Color, tint: bool) -> void:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var pixel := image.get_pixel(x, y)
			if tint:
				image.set_pixel(x, y, Color(pixel.r * color.r, pixel.g * color.g, pixel.b * color.b, pixel.a))
			else:
				var shade := (pixel.r + pixel.g + pixel.b) / 3.0 / 0.33
				image.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, 1.0))


func _bounds(root: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box := mesh_instance.global_transform * mesh_instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
