extends RefCounted

## Motion for the moments a player - or a room watching one - has to see
## without reading: a meter moving, a call closing, a lie breaking.
##
## A meter change is a number rising off the bar ("+15") and the bar sliding
## there with a flash. A stamp is the case file's own marker (the words the
## transcript prints: TACTIC READ, MISREAD, CONTRADICTION, or the call floor's
## PAID and REPORTED) slammed onto a portrait in the marker's color. Monospaced,
## like every line the case file speaks.
##
## Deliberately NOT a `class_name` - see text_style.gd. Preload it:
##     const ScreenFx := preload("res://scripts/systems/screen_fx.gd")

const FONT_STAMP := "res://assets/fonts/IBM_Plex_Mono/IBMPlexMono-Bold.ttf"
const OUTLINE := Color(0.03, 0.03, 0.05)
const STAMP_TILT := -0.14
const FX_META := "fx"
## Two changes to one meter closer together than this show as one number.
const MERGE_MSEC := 300


## A number that rises off a meter and fades, in `rise_color` or `fall_color`
## by its sign. Parented to `host` - the screen's root - so no container lays
## it out or clips it. Returns null when the meter has not been laid out yet: a
## delta applied while the screen is still being built has nowhere to rise from.
##
## One action often moves a meter twice in a frame - a choice's own cost, then
## the node it leads to - and two numbers drawn on one spot read as a third
## ("+22" over "+6" is "+62"). A change that lands within MERGE_MSEC of the
## last one is added into its number instead.
static func float_delta(host: Control, meter: Control, delta: int, rise_color: Color, fall_color: Color) -> Label:
	if delta == 0 or host == null or meter == null or not meter.is_inside_tree():
		return null
	var rect := meter.get_global_rect()
	if rect.size.x <= 1.0:
		return null
	var now := Time.get_ticks_msec()
	var last: Dictionary = meter.get_meta("fx_delta", {})
	var last_label: Variant = last.get("label", null)
	if is_instance_valid(last_label) and now - int(last.get("msec", 0)) < MERGE_MSEC:
		var total := int(last.get("total", 0)) + delta
		meter.set_meta("fx_delta", {"label": last_label, "total": total, "msec": int(last.get("msec", 0))})
		(last_label as Label).text = "%+d" % total
		(last_label as Label).add_theme_color_override("font_color", rise_color if total > 0 else fall_color)
		(last_label as Label).visible = total != 0
		return last_label
	var label := Label.new()
	label.text = "%+d" % delta
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", load(FONT_STAMP))
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", rise_color if delta > 0 else fall_color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	label.set_meta(FX_META, "delta")
	host.add_child(label)
	var start := rect.position - host.get_global_rect().position + Vector2(rect.size.x - 70.0, -34.0)
	label.position = start
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", start.y - 40.0, 1.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.55)
	tween.tween_callback(label.queue_free)
	meter.set_meta("fx_delta", {"label": label, "total": delta, "msec": now})
	return label


## Slide a bar to its new value instead of jumping, with a flash so the eye
## goes there. The flash is on `self_modulate`, so the screen's own warning
## tint on `modulate` is left alone. A second move while one is sliding starts
## from where the first began, so two changes in one frame read as one slide.
static func move_bar(bar: Range, from: float, to: float) -> void:
	if bar.has_meta("fx_slide"):
		var running: Tween = bar.get_meta("fx_slide")
		if running != null and running.is_valid() and running.is_running():
			from = float(bar.get_meta("fx_slide_from", from))
	stop_bar(bar)
	bar.value = from
	var slide := bar.create_tween()
	slide.tween_property(bar, "value", to, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar.set_meta("fx_slide", slide)
	bar.set_meta("fx_slide_from", from)
	var flash := bar.create_tween()
	flash.tween_property(bar, "self_modulate", Color(2.0, 2.0, 2.0), 0.06)
	flash.tween_property(bar, "self_modulate", Color.WHITE, 0.35)
	bar.set_meta("fx_flash", flash)


## Stop a bar mid-slide, for a screen that is about to set it outright.
static func stop_bar(bar: Range) -> void:
	for key in ["fx_slide", "fx_flash"]:
		if bar.has_meta(key):
			var running: Tween = bar.get_meta(key)
			if running != null and running.is_valid():
				running.kill()
			bar.remove_meta(key)
	bar.self_modulate = Color.WHITE


## Slam a stamp onto `target`, centered, at a tilt. `hold` < 0 leaves it there
## (the screen clears it); otherwise it fades after that many seconds.
static func stamp(target: Control, text: String, color: Color, font_size: int = 24, hold: float = -1.0) -> Label:
	if target == null:
		return null
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", load(FONT_STAMP))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(4, font_size / 5))
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(OUTLINE, 0.55)
	frame.border_color = color
	frame.set_border_width_all(maxi(3, font_size / 8))
	frame.set_corner_radius_all(4)
	frame.content_margin_left = font_size * 0.5
	frame.content_margin_right = font_size * 0.5
	frame.content_margin_top = font_size * 0.15
	frame.content_margin_bottom = font_size * 0.15
	label.add_theme_stylebox_override("normal", frame)
	label.set_meta(FX_META, "stamp")
	target.add_child(label)
	label.size = label.get_combined_minimum_size()
	label.position = (target.size - label.size) / 2.0
	label.pivot_offset = label.size / 2.0
	label.rotation = STAMP_TILT
	label.scale = Vector2(2.4, 2.4)
	label.modulate = Color(1, 1, 1, 0)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 0.95, 0.1)
	if hold >= 0.0:
		tween.tween_interval(hold)
		tween.tween_property(label, "modulate:a", 0.0, 0.4)
		tween.tween_callback(label.queue_free)
	AudioManager.play_sfx("stamp")
	return label


## Knock a screen sideways and let it settle. For the few moments that should
## land physically; a screen that shook on every line would stop meaning it.
static func shake(node: Control, strength: float = 6.0, duration: float = 0.25) -> void:
	if node == null:
		return
	var origin := node.position
	if node.has_meta("fx_shake"):
		var running: Tween = node.get_meta("fx_shake")
		if running != null and running.is_valid() and running.is_running():
			running.kill()
			origin = node.get_meta("fx_shake_origin", origin)
	node.set_meta("fx_shake_origin", origin)
	var steps := 6
	var step_time := duration / float(steps + 1)
	var tween := node.create_tween()
	for i in range(steps):
		var falloff := 1.0 - float(i) / float(steps)
		var side := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(node, "position", origin + Vector2(strength * falloff * side, strength * 0.3 * falloff * -side), step_time)
	tween.tween_property(node, "position", origin, step_time)
	node.set_meta("fx_shake", tween)


## A portrait reacting: a tilt and a tint, green for a line that landed well,
## red for one that did not.
static func flinch(portrait: TextureRect, positive: bool) -> void:
	if portrait == null or portrait.texture == null:
		return
	portrait.pivot_offset = portrait.size / 2.0
	var tint := Color(0.75, 1.0, 0.8) if positive else Color(1.0, 0.6, 0.55)
	var tilt := 0.03 if positive else 0.06
	var tween := portrait.create_tween()
	tween.tween_property(portrait, "modulate", tint, 0.08)
	tween.parallel().tween_property(portrait, "rotation", tilt, 0.06)
	tween.tween_property(portrait, "rotation", -tilt * 0.6, 0.08)
	tween.tween_property(portrait, "rotation", 0.0, 0.08)
	tween.parallel().tween_property(portrait, "modulate", Color(1, 1, 1), 0.2)


## Every stamp currently on `target`, newest last.
static func stamps_on(target: Node) -> Array[Label]:
	var found: Array[Label] = []
	if target == null:
		return found
	for child in target.get_children():
		if child is Label and str(child.get_meta(FX_META, "")) == "stamp" and not child.is_queued_for_deletion():
			found.append(child)
	return found


static func clear_stamps(target: Node) -> void:
	for label in stamps_on(target):
		label.get_parent().remove_child(label)
		label.queue_free()
