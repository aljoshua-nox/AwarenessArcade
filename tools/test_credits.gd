extends Node

## Headless check of the credits screen.
##
##   godot --headless --path . res://tools/test_credits.tscn
##
## Exits 0 if every check passes, 1 otherwise. The screen exists because some
## of what ships is licensed on the condition that the credit appears in the
## game; a rewrite of the screen, or of the JSON behind it, must not be able
## to drop one of those lines without this failing. So the wording that
## matters is pinned here a second time, on purpose, apart from the file.

const CREDITS_SCENE := "res://scenes/main_menu/credits.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"
const CREDITS_MD := "res://CREDITS.md"
const CreditsScreen := preload("res://scripts/ui/credits.gd")

# The lines the licenses require, verbatim where the author gave wording.
const MUST_CARRY := [
	"Portrait Pack by Calciumtrice, usable under Creative Commons Attribution 3.0 license.",
	"Font Awesome Free 7.2.0",
	"Image by rawpixel.com on Magnific",
	"Tension by Tsorthan Grove - CC-BY 4.0",
	"Music by GloryToTheMachine",
	"Produced by Julie Damsgaard/Spring Spring/Spring Enterprises @ https://spring-enterprises.neocities.org",
	"kevp888", "qubodup", "MoKoLoKo", "nuFF3",
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


func _run() -> void:
	print("\n--- credits screen smoke test ---")
	_test_file()
	await _test_screen()
	await _test_reachable()

	print("\n%d checks, %d failed" % [checks, failures.size()])
	for f in failures:
		print("  - %s" % f)
	await get_tree().process_frame
	await get_tree().process_frame
	# A sound still in the mixer at quit is reported as a leak.
	await AudioManager.settle()
	get_tree().quit(1 if failures.size() > 0 else 0)


# The JSON is the screen's source; CREDITS.md is the project's. They must agree
# on every required line, so one cannot be changed without the other.
func _test_file() -> void:
	print("\n[the credits file]")
	var data: Dictionary = CreditsScreen.load_credits()
	_check(not data.is_empty(), "credits.json loads")
	var sections: Array = data.get("sections", [])
	_check(sections.size() >= 6, "it has sections (%d)" % sections.size())
	var required: Array = CreditsScreen.required_entries(data)
	_check(required.size() >= MUST_CARRY.size(),
		"it marks the required lines (%d marked, %d expected)" % [required.size(), MUST_CARRY.size()])

	var record := ""
	var file := FileAccess.open(CREDITS_MD, FileAccess.READ)
	_check(file != null, "CREDITS.md is readable")
	if file != null:
		record = file.get_as_text()
	for entry in required:
		var key := str((entry as Dictionary).get("key", (entry as Dictionary).get("line", "")))
		_check(not key.is_empty(), "a required line carries a key to look up")
		_check(record.contains(key), "CREDITS.md records '%s'" % key.left(48))
	for wording in MUST_CARRY:
		var present := false
		for entry in required:
			if str((entry as Dictionary).get("line", "")).contains(wording):
				present = true
		_check(present, "the file carries '%s' as a required line" % wording.left(48))


func _test_screen() -> void:
	print("\n[the screen]")
	var view := await _open(CREDITS_SCENE)
	var text: String = view.rendered_text()
	_check(text.length() > 500, "the screen renders the credits (%d characters)" % text.length())
	for wording in MUST_CARRY:
		_check(text.contains(wording), "on screen: '%s'" % wording.left(48))
	for section in (view.credits as Dictionary).get("sections", []):
		_check(text.contains(str((section as Dictionary).get("title", "")).to_upper()),
			"section '%s' is drawn" % str((section as Dictionary).get("title", "")))
	_check(text.contains("Godot Engine"), "the engine is credited")
	_check(not text.contains("ikot.ph"), "the unlicensed carinderia photo is not credited as if it were licensed")

	var back: Button = null
	for button in view.find_children("*", "Button", true, false):
		if (button as Button).text == "Back":
			back = button
	_check(back != null, "there is a Back button")
	if back != null:
		_check(back.pressed.is_connected(view._back), "and it goes back to the menu")
	_check(AudioManager.music_path == str(AudioManager.MUSIC["menu"]), "the menu music keeps playing under it")
	_check(not CaseJournal.shows_button_in(CREDITS_SCENE), "the journal button stays hidden here")
	await _close(view)


func _test_reachable() -> void:
	print("\n[reachable from the main menu]")
	_check(ResourceLoader.exists(CREDITS_SCENE), "the credits scene exists")
	var menu := await _open(MAIN_MENU_SCENE)
	var credits_button: Button = null
	for button in menu.find_children("*", "Button", true, false):
		if (button as Button).text == "Credits":
			credits_button = button
	_check(credits_button != null, "the main menu has a Credits button")
	_check(str(menu.CREDITS_SCENE) == CREDITS_SCENE, "it points at the credits scene")
	await _close(menu)
