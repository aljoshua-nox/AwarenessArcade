extends Node

## Every sound in the game goes through here: a pool of players for effects
## (so a footstep and a click can overlap instead of cutting each other off),
## one looping player for the bed under a scene, and one for music.
##
## Paths that are empty or not in the project play nothing and never error, so
## a scene can name the sound it wants before anyone has found the file.

## The effects the game uses, by name, so a scene never spells a path twice.
const SFX := {
	"click": "res://assets/audio/sfx/ui/click.ogg",
	"tab": "res://assets/audio/sfx/ui/tab.ogg",
	"door": "res://assets/audio/sfx/ui/door.ogg",
	"confirm": "res://assets/audio/sfx/ui/confirm.ogg",
	"objective": "res://assets/audio/sfx/ui/objective.ogg",
	"error": "res://assets/audio/sfx/ui/error.ogg",
	"page": "res://assets/audio/sfx/page_turn.ogg",
	"pen": "res://assets/audio/sfx/pen_scratch.ogg",
	"step": "res://assets/audio/sfx/477357__nuff3__steps-tile_3a.ogg",
	"hang_up": "res://assets/audio/sfx/575853__martian__intercom-bell-phone-hang-up.wav",
}
const SFX_VOLUME := {
	"click": -14.0, "tab": -14.0, "door": -8.0, "confirm": -10.0, "objective": -6.0,
	"error": -10.0, "page": -6.0, "pen": -8.0, "step": -20.0, "hang_up": -8.0,
}

const MUSIC := {
	"menu": "res://assets/audio/music/tension_loop.ogg",
	"prologue": "res://assets/audio/music/thought_loop.ogg",
	"ending": "res://assets/audio/music/something_isnt_adding_up.ogg",
	"crime_scene": "res://assets/audio/music/crime_scene.ogg",
}

const SFX_PLAYERS := 4

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0
var _ambience_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var ambience_path: String = ""
var music_path: String = ""


func _ready() -> void:
	# Sounds keep playing under the pause menu and the journal.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.volume_db = -12.0
	add_child(_ambience_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -12.0
	add_child(_music_player)


# Playback objects are released on the mix thread a moment after stop(); a
# process that quits before then reports them as leaked at exit. Headless
# frames are far too quick to cover that gap, so the test runners await this
# before quit(). Not needed in the game - closing the window takes long enough.
func settle() -> void:
	stop()
	stop_ambience()
	stop_music()
	await get_tree().create_timer(0.2).timeout


# --- Effects ------------------------------------------------------------------

## Play one of the named effects in SFX at its usual volume.
func play_sfx(name: String, volume_db: float = NAN) -> void:
	var path := str(SFX.get(name, ""))
	if path.is_empty():
		push_warning("AudioManager: no effect named '%s'" % name)
		return
	play_stream(path, SFX_VOLUME.get(name, 0.0) if is_nan(volume_db) else volume_db)


## Play a stream by path on the next free effects player. The older callers
## (the prologue's ring and dial tone, the interview's stings) use this.
func play_stream(path: String, volume_db: float = 0.0) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func stop() -> void:
	for player in _sfx_players:
		player.stop()


# --- Ambience -----------------------------------------------------------------

## Loop `path` under the scene, or keep it playing if it already is. A path
## that is empty or whose file is not in the project stops whatever was
## playing - so a scene can name the file it wants before anyone has found one.
func play_ambience(path: String, volume_db: float = -12.0) -> void:
	ambience_path = _play_looped(_ambience_player, path, ambience_path, volume_db)


func stop_ambience() -> void:
	ambience_path = ""
	if _ambience_player != null:
		_ambience_player.stop()


func ambience_playing() -> bool:
	return _ambience_player != null and _ambience_player.playing


# --- Music --------------------------------------------------------------------

## Loop one of the tracks in MUSIC (or a path), or keep it if it is already on.
func play_music(name_or_path: String, volume_db: float = -12.0) -> void:
	var path := str(MUSIC.get(name_or_path, name_or_path))
	music_path = _play_looped(_music_player, path, music_path, volume_db)


func stop_music() -> void:
	music_path = ""
	if _music_player != null:
		_music_player.stop()


func music_playing() -> bool:
	return _music_player != null and _music_player.playing


## Shared by the bed and the music: returns the path now playing, or "".
func _play_looped(player: AudioStreamPlayer, path: String, current: String, volume_db: float) -> String:
	if path.is_empty() or not ResourceLoader.exists(path):
		player.stop()
		return ""
	if path == current and player.playing:
		return current
	var stream: AudioStream = load(path)
	if stream == null:
		player.stop()
		return ""
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif "loop" in stream:
		stream.set("loop", true)
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	return path
