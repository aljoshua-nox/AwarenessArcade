# Ambience beds

Each walkable scene names a looping bed and plays it through `AudioManager.play_ambience()`
if the file exists; a missing file means silence, not an error. Drop a file in under the
exact name, run `godot --headless --path . --import`, and add a row to `CREDITS.md`.

| file | scene | source |
|---|---|---|
| `street.ogg` | Sampaguita Street, Terminal Road | 100 s cut from kevp888's Freesound 441454 (a Philippine street), crossfaded to loop |
| `call_floor.ogg` | Call Floor 3F, Tech Support Floor 4F, and the Anti-Fraud Desk at -22 dB | 100 s cut from qubodup's Freesound 211945, crossfaded to loop |

Both CC-BY 4.0 - their lines are on the in-game credits screen. The originals (a 43 MB
WAV and a 50 MB FLAC) live outside the repo in the workspace's `downloads/audio-originals/`;
Godot cannot read FLAC and the WAV would have shipped uncompressed, so
`scratchpad/audio_prep.py` (kept with the session notes) cut and encoded them with
libsndfile. A room tone for the desk would still be welcome: OGG, a minute, CC0 or CC-BY,
named `office.ogg`, and point `detective_office.gd`'s `ambience_path` at it.
