extends Node

var _stream_player: AudioStreamPlayer


func _ready() -> void:
	_stream_player = AudioStreamPlayer.new()
	add_child(_stream_player)


func play_stream(path: String, volume_db: float = 0.0) -> void:
	if path.is_empty():
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	_stream_player.stream = stream
	_stream_player.volume_db = volume_db
	_stream_player.play()


func stop() -> void:
	if _stream_player:
		_stream_player.stop()
