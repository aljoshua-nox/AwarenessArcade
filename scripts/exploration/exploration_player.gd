extends CharacterBody2D
class_name ExplorationPlayer

@export var move_speed: float = 180.0
@export var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1280, 720))

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D

var facing: String = "down"
# A footstep every STEP_INTERVAL seconds while walking; the first one lands the
# moment the player starts moving.
const STEP_INTERVAL := 0.34
var step_clock: float = 0.0

const FRAME_TEXTURES := {
	"idle_down": "res://assets/art/characters/player/detective_idle_front.png",
	"idle_up": "res://assets/art/characters/player/detective_idle_back.png",
	"idle_left": "res://assets/art/characters/player/detective_idle_left.png",
	"idle_right": "res://assets/art/characters/player/detective_idle_right.png",
	"walk_down": "res://assets/art/characters/player/detective_walk_front.png",
	"walk_up": "res://assets/art/characters/player/detective_walk_back.png",
	"walk_left": "res://assets/art/characters/player/detective_walk_left.png",
	"walk_right": "res://assets/art/characters/player/detective_walk_right.png",
}


func _ready() -> void:
	add_to_group("player")
	_build_animations()
	_show_idle_pose("down")


func _physics_process(delta: float) -> void:
	# move_* carries the arrows and WASD both. The ui_* actions this used to read
	# are arrows only, so the hint's "WASD" was a lie until 2026-09-19.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed

	if direction != Vector2.ZERO:
		facing = _direction_from_vector(direction)
		_play_animation("walk_%s" % facing)
		step_clock -= delta
		if step_clock <= 0.0:
			AudioManager.play_sfx("step")
			step_clock = STEP_INTERVAL
	else:
		_show_idle_pose(facing)
		step_clock = 0.0

	move_and_slide()
	_clamp_to_bounds()


func _clamp_to_bounds() -> void:
	global_position.x = clampf(global_position.x, movement_bounds.position.x, movement_bounds.end.x)
	global_position.y = clampf(global_position.y, movement_bounds.position.y, movement_bounds.end.y)


func _direction_from_vector(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"


func _play_animation(animation_name: String) -> void:
	if sprite.sprite_frames == null:
		return
	if sprite.animation != animation_name:
		sprite.play(animation_name)


func _show_idle_pose(direction_name: String) -> void:
	var animation_name := "idle_%s" % direction_name
	if sprite.sprite_frames == null:
		return
	if sprite.animation != animation_name:
		sprite.play(animation_name)
	sprite.stop()
	sprite.frame = 0


## Someone other than the detective: a Modern Interiors character, from an idle
## sheet (one frame per direction) and a run sheet (six per direction), 16x32
## frames in the pack's order - right, up, left, down. The scammer on the call
## floor wears one.
const PACK_DIRECTIONS := ["right", "up", "left", "down"]
const PACK_FRAME_SIZE := Vector2(16.0, 32.0)
const PACK_RUN_FRAMES := 6


func use_pack_character(idle_sheet: Texture2D, run_sheet: Texture2D, character_scale: float) -> void:
	var frames := SpriteFrames.new()
	for d in range(PACK_DIRECTIONS.size()):
		var idle_name := "idle_%s" % PACK_DIRECTIONS[d]
		frames.add_animation(idle_name)
		frames.set_animation_loop(idle_name, false)
		frames.add_frame(idle_name, _pack_frame(idle_sheet, d))
		var walk_name := "walk_%s" % PACK_DIRECTIONS[d]
		frames.add_animation(walk_name)
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, 10.0)
		for index in range(PACK_RUN_FRAMES):
			frames.add_frame(walk_name, _pack_frame(run_sheet, d * PACK_RUN_FRAMES + index))
	_apply_frames(frames, character_scale)
	_show_idle_pose(facing)


func _pack_frame(sheet: Texture2D, index: int) -> AtlasTexture:
	var region := AtlasTexture.new()
	region.atlas = sheet
	region.region = Rect2(Vector2(index * PACK_FRAME_SIZE.x, 0.0), PACK_FRAME_SIZE)
	return region


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	for animation_name in FRAME_TEXTURES.keys():
		var texture_path := str(FRAME_TEXTURES[animation_name])
		var sheet: Texture2D = load(texture_path)
		if sheet == null:
			continue

		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, animation_name.begins_with("walk_"))
		frames.set_animation_speed(animation_name, 8.0)

		var frame_count := int(sheet.get_width() / 32)
		if animation_name.begins_with("idle_"):
			frame_count = 1

		var frame_width := 32
		for index in range(frame_count):
			var region := AtlasTexture.new()
			region.atlas = sheet
			region.region = Rect2(index * frame_width, 0, frame_width, sheet.get_height())
			frames.add_frame(animation_name, region)

	_apply_frames(frames, 1.35)


func _apply_frames(frames: SpriteFrames, sprite_scale: float) -> void:
	sprite.sprite_frames = frames
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play("idle_down")
	sprite.stop()
	sprite.frame = 0
