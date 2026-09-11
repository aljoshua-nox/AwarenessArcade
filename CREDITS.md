# Asset Credits — Dial and Deceive

Tracking file for every third-party art/audio/font asset used in the game, so we can
build an in-game credits screen and stay license-compliant. Update this whenever a
new asset is added under `assets/`.

Status legend: ✅ confirmed from bundled license/readme · ⚠️ needs verification (no
license file bundled, or license terms require per-file checking).

> **Redistribution — resolved 2026-09-08.**
> Two packs permitted use in a built game but forbade redistributing the raw
> files: **Modern Office 2D Props** ("Resell, sublicense, share, or redistribute
> the assets as standalone files" is not permitted) and **Pixel Life – Desk
> Essentials** ("no resale or redistribution of standalone files"). Committing
> their PNGs to a public Git repository is exactly that. **Neither was
> referenced by the game**, so both were removed from version control rather
> than kept under terms the repository could not satisfy. Do not re-add them to
> this repo while it is public.
>
> **Font Awesome** (CC BY 4.0) and the **Calciumtrice Portrait Pack** (CC-BY 3.0)
> both *require* attribution in the shipped game, not just in this file. The
> planned in-game credits screen is what satisfies that.
>
> **Removed the same day, all unreferenced by the game:** Modern Office 2D
> Props, Pixel Life – Desk Essentials, 25 Portrait Pixel Art pack1 (terms never
> stated), FG11 Trial (unidentifiable, folder marked "Trial"), MetroCity +
> MetroCity 2.0 (CC0, simply unused), and the `Modern_City_GameKit/` folder —
> 319 files, ~12 MB. See the note on the `urban/` sheets below before assuming
> the GameKit question is closed.


## Art

| Asset(s) | Location | Source / Author | License | Status |
|---|---|---|---|---|
| Background elements (clouds, castle, fence) | `assets/art/backgrounds/kenney_background-elements/` | Kenney Vleugels (kenney.nl) | CC0 | ✅ |
| UI Pack 2.0 | `assets/art/ui/kenney_ui-pack/` | Kenney (kenney.nl) | CC0 | ✅ |
| UI Pack: RPG Expansion | `assets/art/ui/kenney_ui-pack-rpg-expansion/` | Kenney (kenney.nl) | CC0 | ✅ |
| Kenney Fonts pack | `assets/art/ui/kenney_kenney-fonts/` | Kenney (kenney.nl) | CC0 | ✅ |
| Input Prompts 1.5 | `assets/art/ui/kenney_input-prompts_1.5/` | Kenney (kenney.nl) | CC0 | ✅ |
| Roguelike Modern City 2.0 | `assets/art/maps/kenney_roguelike-modern-city/` | Kenney (kenney.nl) | CC0 | ✅ |
| RPG Urban Pack 1.0 | `assets/art/maps/kenney_rpg-urban-pack/` | Kenney (kenney.nl) | CC0 | ✅ |
| PixelOffice pack (characters + office props) | `assets/art/maps/PixelOffice/` | itch.io asset pack ("PixelOffice") | CC0 | ✅ |
| Free Office Pixel Art | `assets/art/maps/free-office-pixel-art/` | arlantr — [itch.io](https://arlantr.itch.io/) / [OpenGameArt](https://opengameart.org/users/arlantr) | Free to use, credit appreciated | ✅ |
| Little Bits: Office (tileset + businessman1 character) | `assets/art/maps/Little_Bits_Office_tileset/` | AdricCustoms — [itch.io](https://adriccustoms.itch.io/little-bits-office) | Name-your-own-price; creator states use is unrestricted ("Use it for whatever you like"). No formal license text published | ✅ identified, terms informal |
| Urban tile sheets — **three of these build the city block** (`walls_grass_roof` = every building, `doors_windows` = every door, `props` = lampposts) | `assets/art/maps/urban/` | ⚠️ **Unidentified — the one remaining licensing question.** Byte-identical copies of files from the removed `Modern_City_GameKit/` pack. **Checked against Kenney's RPG Urban Pack (2026-09-08): not a match.** Only `urban_map.png` in this folder is Kenney's — it is `Tilemap/tilemap.png` byte for byte, and it is unused. The other five are a different pack in a visibly different style: freely-arranged detailed sprites, not Kenney's strict flat 16x16 grid | ⚠️ unknown | ⚠️ **unresolved — ask whoever downloaded the art.** Three searches found nothing |
| Kenney RPG Urban Pack tilemap (stray copy) | `assets/art/maps/urban/urban_map.png` | Kenney (kenney.nl) — byte-identical to `kenney_rpg-urban-pack/Tilemap/tilemap.png` | CC0 | ✅ (unused; a duplicate of a file already in the repo) |
| Street terrain — pavements, road, grass, cars, trees (`TILES_DIR` in `urban_exterior.gd`) | `assets/art/maps/kenney_roguelike-modern-city/Tiles/` | Kenney (kenney.nl) | CC0 | ✅ |
| Office tile sheets — floor and wall tiles used by the call floor (`floor_tiles`, `wall_tiles`; other props unused) | `assets/art/maps/office/` | ⚠️ unidentified; did not match the removed GameKit pack, so a separate source | ⚠️ unknown | ⚠️ needs source lookup |
| Numbered character pack (`pack/pack/1.png`…) | `assets/art/characters/pack/` | ⚠️ unidentified — no bundled license found | ⚠️ unknown | ⚠️ needs source lookup |
| Player detective sprite (idle/walk, 4 directions) | `assets/art/characters/player/` | ⚠️ unidentified — likely custom or from one of the packs above | ⚠️ unknown | ⚠️ needs source lookup |
| Portrait Pack (`fella 1`, `fella 2`, `lady 1`, `lady 2`) | `assets/art/portraits/` | Calciumtrice — [OpenGameArt](https://opengameart.org/content/portrait-pack) (identified 2026-09-12; the "C" monogram bottom-right is the artist's) | **CC-BY 3.0** — attribution required. Author's notice: *"Portrait Pack by Calciumtrice, usable under Creative Commons Attribution 3.0 license."* | ✅ |
| Portraits (`lady 3`, `lady 4`) | `assets/art/portraits/` | ⚠️ supplied by the team on 2026-09-09 / 2026-09-12; 1254x1254 RGB, so not from the Calciumtrice pack — **source not yet recorded** | ⚠️ unknown | ⚠️ ask whoever supplied them |
| UI/status icons (bell, clock, phone, shield, gear, user, etc.) | `assets/art/icons/` | **Font Awesome Free 7.2.0** — fontawesome.com (embedded in SVG headers) | CC BY 4.0 (icons) — attribution required | ✅ |
| Background photos: Alesia Kazantceva | `assets/art/backgrounds/alesia-kazantceva-VWcPlbHglYc-unsplash.jpg` | Alesia Kazantceva — [Unsplash](https://unsplash.com/photos/VWcPlbHglYc) | Unsplash License (free, attribution appreciated not required) | ✅ |
| Background photos: Copernico | `assets/art/backgrounds/copernico-p_kICQCOM4s-unsplash.jpg` | Copernico — [Unsplash](https://unsplash.com/photos/p_kICQCOM4s) | Unsplash License | ✅ |
| Background photos: Israel Andrade | `assets/art/backgrounds/israel-andrade-YI_9SivVt_s-unsplash.jpg` | Israel Andrade — [Unsplash](https://unsplash.com/photos/YI_9SivVt_s) | Unsplash License | ✅ |
| Background photos: Jose Losada | `assets/art/backgrounds/jose-losada-DyFjxmHt3Es-unsplash.jpg` | Jose Losada — [Unsplash](https://unsplash.com/photos/DyFjxmHt3Es) | Unsplash License | ✅ |
| Background photos: LYCS Architecture | `assets/art/backgrounds/lycs-architecture-U2BI3GMnSSE-unsplash.jpg` | LYCS Architecture — [Unsplash](https://unsplash.com/photos/U2BI3GMnSSE) | Unsplash License | ✅ |
| Background photos: Nastuh Abootalebi (x2) | `assets/art/backgrounds/nastuh-abootalebi-eHD8Y1Znfpk-unsplash.jpg`, `assets/art/backgrounds/nastuh-abootalebi-yWwob8kwOCk-unsplash.jpg` | Nastuh Abootalebi — [Unsplash](https://unsplash.com/photos/eHD8Y1Znfpk), [Unsplash](https://unsplash.com/photos/yWwob8kwOCk) | Unsplash License | ✅ |

## Fonts

| Asset | Location | Source / Author | License | Status |
|---|---|---|---|---|
| IBM Plex Sans | `assets/fonts/IBM_Plex_Sans/` | IBM | SIL Open Font License 1.1 | ✅ |
| IBM Plex Mono | `assets/fonts/IBM_Plex_Mono/` | IBM Corp. | SIL Open Font License 1.1 — confirmed, `OFL.txt` bundled | ✅ |
| Kenney Fonts | `assets/art/ui/kenney_kenney-fonts/Fonts/` | Kenney (kenney.nl) | CC0 | ✅ |

## Audio

All SFX/ambience filenames follow the Freesound.org convention `<id>__<username>__<description>`.
Freesound license varies per-upload (CC0, CC-BY, CC-BY-NC, or Sampling+), so each one below
must be checked individually at `freesound.org/s/<id>/` before shipping — do not assume CC0.

**Verification status (checked 2026-09-08).** freesound.org could not be reached from
tooling — the site is currently serving an expired TLS certificate, and web.archive.org
is unavailable here too — so only the licence that surfaced in search results could be
confirmed. The remaining three need someone to open the URL in a browser; the licence is
printed on the sound's page. Every file listed below is referenced by the game.

| Asset | Location | Freesound user | Freesound ID | License |
|---|---|---|---|---|
| Dial tone | `assets/audio/sfx/360480__giddster__dial-tone.wav` | giddster | [360480](https://freesound.org/s/360480/) | ⚠️ unverified — site unreachable |
| Notification sound (handmade) | `assets/audio/sfx/434379__kila_vat__notification-sound-handmade.mp3` | kila_vat | [434379](https://freesound.org/s/434379/) | ⚠️ unverified — site unreachable |
| Radio static | `assets/audio/sfx/524204__joviansounds__radio-static.wav` | JovianSounds | [524204](https://freesound.org/s/524204/) | **CC0** — no attribution required (confirmed) |
| Phone ringing 5 | `assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3` | AUDACITIER | [629201](https://freesound.org/s/629201/) | ⚠️ unverified — site unreachable |

No music tracks are currently in `assets/audio/music/` (empty).

## Open items

1. **Identify the `urban/` tile sheets.** They draw the city block the whole investigation
   walks around, and nobody knows where they came from. Ask whoever downloaded the art —
   their itch.io library or browser download history will answer it far faster than
   searching. Failing that, replace them with the Kenney *Roguelike Modern City* / *RPG
   Urban Pack* already in this project, both CC0.
2. Identify the remaining ⚠️ art: the `office/` floor and wall tiles, the numbered `pack/`
   character sheets, the player detective sprite, and the two newer portraits (`lady 3`,
   `lady 4`) — record where those came from and under what terms. The original four
   portraits are resolved (Calciumtrice, CC-BY 3.0).
3. Confirm each Freesound SFX's actual license (CC0 vs CC-BY vs CC-BY-NC) — CC-BY entries
   need "Author — title (freesound.org)" in the credits screen; CC-BY-NC entries are not
   safe to ship in a commercial release.
4. Font Awesome Free icons are CC BY 4.0 — the credits screen must include an attribution
   line for Font Awesome (fontawesome.com) since these are not the CC0 subset. The same
   screen must carry "Portrait Pack by Calciumtrice, usable under Creative Commons
   Attribution 3.0 license." for the four original portraits.
4. Modern Office 2D Props Pack (nacl1234) forbids standalone redistribution — fine as
   embedded assets in the compiled game, just don't ship the raw PNG/JSON files separately.
