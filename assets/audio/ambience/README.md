# Ambience beds

Each walkable scene names a looping bed and plays it through `AudioManager.play_ambience()`
if the file exists; a missing file means silence, not an error. Drop a file in under the
exact name, run `godot --headless --path . --import`, and add a row to `CREDITS.md`.

| file | scene | what to look for |
|---|---|---|
| `street.mp3` | Sampaguita Street, Terminal Road | a quiet residential street: distant traffic, a tricycle, birds, a radio somewhere |
| `call_floor.mp3` | Call Floor 3F, Tech Support Floor 4F | an open-plan office: keyboards, low chatter, phones |
| `office.mp3` | Anti-Fraud Desk | a small office: a fan, a clock, a corridor |

MP3, OGG or WAV; a minute or two is enough (it loops). Freesound.org filters by license -
use **CC0** or CC-BY only; CC-BY ones go on the in-game credits screen. The old
`407292__nightwatcher98__office-ambience.mp3` that earlier notes mention was removed
from the repo before it was ever wired in, so nothing here is credited yet.
