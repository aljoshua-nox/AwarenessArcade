extends Node

var _stream_player: AudioStreamPlayer
# A second player for ambience, so a bed under a street or a floor is not cut
# off by every sting the first player fires.
var _ambience_player: AudioStreamPlayer
var ambience_path: String = ""


func _ready() -> void:
	_stream_player = AudioStreamPlayer.new()
	add_child(_stream_player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.volume_db = -12.0
	add_child(_ambience_player)


## Loop `path` under the scene, or keep it playing if it already is. A path
## that is empty or whose file is not in the project stops whatever was
## playing - so a scene can name the file it wants before anyone has found one.
func play_ambience(path: String, volume_db: float = -12.0) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		stop_ambience()
		return
	if path == ambience_path and _ambience_player.playing:
		return
	var stream: AudioStream = load(path)
	if stream == null:
		stop_ambience()
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif "loop" in stream:
		stream.set("loop", true)
	ambience_path = path
	_ambience_player.stream = stream
	_ambience_player.volume_db = volume_db
	_ambience_player.play()


func stop_ambience() -> void:
	ambience_path = ""
	if _ambience_player != null:
		_ambience_player.stop()


func ambience_playing() -> bool:
	return _ambience_player != null and _ambience_player.playing


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
