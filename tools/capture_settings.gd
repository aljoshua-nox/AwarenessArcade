extends Node

## Renders one interview per setting so the backdrop behind each kind of
## place can be reviewed. Needs a real (non-headless) run:
##
##   godot --path . res://tools/capture_settings.tscn
##
## Writes setting_<name>.png under user:// for every key of the interview's
## SETTING_BACKGROUNDS that a case uses. A setting whose photo is missing renders
## the office fallback, which is the thing to notice.

const INTERVIEW_SCENE := "res://scenes/investigation/interview.tscn"
const CASES := {
	"home": "res://resources/cases/interview_case_001.json",
	"boarding_house": "res://resources/cases/interview_case_009.json",
	"shop": "res://resources/cases/interview_case_006.json",
	"canteen": "res://resources/cases/interview_case_012.json",
	"site": "res://resources/cases/interview_case_010.json",
	"lobby": "res://resources/cases/interview_case_013.json",
	"interrogation": "res://resources/cases/interview_case_003.json",
	"call_floor": "res://resources/cases/interview_case_004.json",
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for setting in CASES:
		SessionState.reset_session()
		SessionState.detective_credibility = 100
		SessionState.suspect_flipped = true
		SessionState.pending_case_path = str(CASES[setting])
		var view: Node = load(INTERVIEW_SCENE).instantiate()
		add_child(view)
		await get_tree().process_frame
		if view.has_method("_finish_reveal"):
			view._finish_reveal()
		for i in range(5):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "user://setting_%s.png" % setting
		if get_viewport().get_texture().get_image().save_png(path) == OK:
			print("PREVIEW: %s (%s)" % [ProjectSettings.globalize_path(path), view.background.texture.resource_path.get_file()])
		remove_child(view)
		view.queue_free()
		await get_tree().process_frame
	get_tree().quit()
