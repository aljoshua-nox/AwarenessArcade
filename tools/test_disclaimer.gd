extends Node

## Headless check of the disclaimer card.
##
##   godot --headless --path . res://tools/test_disclaimer.tscn
##
## Exits 0 if every check passes, 1 otherwise. The card is the first thing the
## game shows, so this pins that it is still the project's main scene, that
## the fiction notice is on it, that a key held from launch cannot skip it
## before it has faded in, and that it then hands off to the main menu.

const DISCLAIMER_SCENE := "res://scenes/main_menu/disclaimer.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

# The phrases the notice has to keep, whatever else is reworded.
const MUST_CARRY := [
	"work of fiction",
	"living or dead",
	"purely coincidental",
	"awareness and education only",
]

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("  FAIL  %s" % label)
	else:
		print("  ok    %s" % label)


func _open(scene_path: String) -> Node:
	var view: Node = load(scene_path).instantiate()
	add_child(view)
	await get_tree().process_frame
	return view


func _close(view: Node) -> void:
	remove_child(view)
	view.queue_free()
	await get_tree().process_frame


func _key_press() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	return event


func _run() -> void:
	print("\n--- disclaimer card smoke test ---")
	_test_placement()
	await _test_screen()
	await _test_continue()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	# A sound still in the mixer at quit is reported as a leak.
	await AudioManager.settle()
	get_tree().quit(1 if failures.size() > 0 else 0)


func _test_placement() -> void:
	print("\n[where it sits]")
	_check(ResourceLoader.exists(DISCLAIMER_SCENE), "the disclaimer scene exists")
	_check(str(ProjectSettings.get_setting("application/run/main_scene")) == DISCLAIMER_SCENE,
		"it is the project's main scene")
	_check(not CaseJournal.shows_button_in(DISCLAIMER_SCENE), "the journal button stays hidden here")


func _test_screen() -> void:
	print("\n[the card]")
	var view := await _open(DISCLAIMER_SCENE)
	var text: String = view.rendered_text()
	_check(text.contains(str(view.HEADING).to_upper()), "the heading is drawn")
	for wording in MUST_CARRY:
		_check(text.contains(wording), "on screen: '%s'" % wording)
	_check(text.contains(str(view.PROMPT)), "the player is told how to continue")

	var continue_button: Button = null
	for button in view.find_children("*", "Button", true, false):
		if (button as Button).text == "Continue":
			continue_button = button
	_check(continue_button != null, "there is a Continue button")
	if continue_button != null:
		_check(continue_button.pressed.is_connected(view._continue), "and it continues")
	_check(str(view.MAIN_MENU_SCENE) == MAIN_MENU_SCENE and str(view.next_scene) == MAIN_MENU_SCENE,
		"Continue goes to the main menu")
	_check(AudioManager.music_path == str(AudioManager.MUSIC["menu"]), "the menu music starts under it")
	await _close(view)


# The card fades in and drops input until it has; after that one press is
# enough, and a second does nothing.
func _test_continue() -> void:
	print("\n[continuing]")
	var view := await _open(DISCLAIMER_SCENE)
	view.next_scene = ""
	_check(not view.can_continue, "input is not taken while the card is still fading in")
	view._unhandled_input(_key_press())
	_check(not view.continued, "a key held from launch does not skip it")

	await get_tree().create_timer(view.FADE_IN_SECONDS + 0.2).timeout
	_check(view.can_continue, "input is taken once the fade has finished")
	view._unhandled_input(_key_press())
	_check(view.continued, "then a key continues")
	await _close(view)
