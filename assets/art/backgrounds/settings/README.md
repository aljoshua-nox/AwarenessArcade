# Interview backgrounds by setting

`interview.gd` picks the photo behind an interview from the case's `person.setting`.
The file for each setting goes in this folder under the exact name below; until it
is here, that setting falls back to the office photo. After adding a file, run
`godot --headless --path . --import` so it gets its `.import` sidecar, then commit both.
All seven were added on 2026-09-19 (sources and licenses in `CREDITS.md`); a file must
really be what its extension says - a PNG saved as `.jpg` fails to import and the
setting silently falls back to the office. `canteen.jpg` still needs a licensed
replacement.

| setting | file | used by |
|---|---|---|
| `home` | `home.jpg` | Maria, Kevin, Evelyn, Teodoro, Trish |
| `boarding_house` | `boarding_house.jpg` | Bea |
| `shop` | `shop.jpg` | Lina (print shop) |
| `canteen` | `canteen.jpg` | Carmen |
| `site` | `site.jpg` | Joel (construction site office) |
| `lobby` | `lobby.jpg` | Dennis (tower lobby) |
| `interrogation` | `interrogation.jpg` | Marco |

`office` and `call_floor` already resolve to photos in the parent folder.

Landscape, at least 1920 px wide, no readable brands or recognizable faces (the UI
dims it 60%, so mood matters more than detail). Unsplash and Pexels photos are fine -
that is where the existing backgrounds come from - and each one gets a row in
`CREDITS.md`.
