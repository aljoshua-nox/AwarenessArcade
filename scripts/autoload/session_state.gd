extends Node

signal session_reset
signal case_resolved(result: Dictionary)

var cases_reviewed: int = 0
var victims_protected: int = 0
var failed_interventions: int = 0
var alert_level: int = 0
var evidence_linked: int = 0
var current_case: Dictionary = {}
var last_result: Dictionary = {}
var resolution_history: Array = []


func reset_session() -> void:
	cases_reviewed = 0
	victims_protected = 0
	failed_interventions = 0
	alert_level = 0
	evidence_linked = 0
	current_case = {}
	last_result = {}
	resolution_history.clear()
	session_reset.emit()


func start_case(case_data: Dictionary) -> void:
	current_case = case_data


func register_evidence_linked(count: int = 1) -> void:
	evidence_linked += count


func resolve_case(result: Dictionary) -> void:
	cases_reviewed += 1
	last_result = result

	if result.get("protected", false):
		victims_protected += 1
	else:
		failed_interventions += 1

	alert_level = clamp(alert_level + int(result.get("alert_delta", 0)), 0, 10)
	resolution_history.append(result)
	case_resolved.emit(result)


func go_to_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)
