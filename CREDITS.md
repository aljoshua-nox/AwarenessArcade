# Asset Credits — Dial and Deceive

Tracking file for every third-party art/audio/font asset used in the game, so the
in-game credits screen can quote it and the project stays license-compliant. Update
this whenever a new asset is added under `assets/`.

**The credits screen exists (2026-09-20):** main menu -> Credits, built from
`resources/credits/credits.json`. Every entry there marked `required` carries the
author's own wording and a `key` that `tools/test_credits.tscn` looks up in this file,
so a required line cannot be changed in one place without the other noticing. When a
new attribution-licensed asset lands, add its row here *and* its entry there.

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
> in-game credits screen (built 2026-09-20) is what satisfies that.
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
| Portraits (`lady 3`, `lady 4`, `fella 3`, `fella 4`) | `assets/art/portraits/` | **AI-generated**, produced by the team (2026-09-09 to 2026-09-12); 1254x1254 RGB | No third-party license — generated for this project. No attribution owed to anyone; the generator used is not recorded here | ✅ |
| Portraits (`teddy`, `joel`, `trish`, `carmen`, `dennis`, `bea`, `rowena`, `gus`) | `assets/art/portraits/` | **AI-generated**, produced by the team (2026-09-12) from the briefs in the workspace's `future-cast.md`; 1254x1254 RGB. Added to the repo 2026-09-15 ahead of the characters they are for; `teddy` became Teodoro Villanueva (`interview_case_007`), `trish` Patricia Lim (`008`), `bea` Bea Santiago (`009`) and `joel` Joel Abad (`010`) the same day, `rowena` Rowena Ocampo (`011`), `carmen` Carmen Salazar (`012`) and `dennis` Dennis Mercado (`013`) on 2026-09-16; `gus` is deliberately unreferenced - the owner has no interview, only a name, and the portrait is held for an epilogue | No third-party license — generated for this project. Same terms as the row above | ✅ |
| UI/status icons (bell, clock, phone, shield, gear, user, etc.) | `assets/art/icons/` | **Font Awesome Free 7.2.0** — fontawesome.com (embedded in SVG headers) | CC BY 4.0 (icons) — attribution required | ✅ |
| Main menu and credits backdrop | `assets/art/backgrounds/copernico-p_kICQCOM4s-unsplash.jpg` | Copernico — [Unsplash](https://unsplash.com/photos/p_kICQCOM4s) | Unsplash License (free, attribution appreciated not required) | ✅ |
| Prologue, endings and default interview backdrop | `assets/art/backgrounds/jose-losada-DyFjxmHt3Es-unsplash.jpg` | Jose Losada — [Unsplash](https://unsplash.com/photos/DyFjxmHt3Es) | Unsplash License | ✅ |
| Office photo behind the directors' interviews (`office` / `call_floor` settings) | `assets/art/backgrounds/pexels-yankrukov-8867271.jpg` | Yan Krukau — [Pexels](https://www.pexels.com/photo/8867271/) (in the repo since the first commit; row added 2026-09-20) | Pexels License (free to use, attribution not required) | ✅ |
| ~~Eight unreferenced photos~~ — removed 2026-09-20 | ~~`alesia-kazantceva-…`, `israel-andrade-…`, `lycs-architecture-…`, `nastuh-abootalebi-…` (x2), `pexels-mart-production-7709259`, `pexels-yankrukov-8867190`, `pexels-yankrukov-8867265`~~ | Unsplash and Pexels photographers, all free licenses | Nothing referenced them and they added ~80 MB of texture to the build. The same day every remaining background was scaled to 1920 px wide (the most any screen shows), which took the exported `.exe` from 337 MB to a fraction of that | removed |
| Interview backdrop: home (Maria, Kevin, Evelyn, Teodoro, Trish) | `assets/art/backgrounds/settings/home.jpg` | Jenn Causing — [Unsplash](https://unsplash.com/photos/elegant-living-room-with-chandelier-and-ornate-furniture-wMrgMaPt26E) (added 2026-09-19) | Unsplash License | ✅ |
| Interview backdrop: boarding house (Bea) | `assets/art/backgrounds/settings/boarding_house.jpg` | Rob Wingate — [Unsplash](https://unsplash.com/photos/window-curtain-open-wide-Fd9tUmRBJzk) | Unsplash License | ✅ |
| Interview backdrop: print shop (Lina) | `assets/art/backgrounds/settings/shop.jpg` | Aleksandr Galichkin — [Unsplash](https://unsplash.com/photos/industrial-printing-press-with-purple-ink-rollers-QRykXu51r_0) | Unsplash License | ✅ |
| Interview backdrop: construction site (Joel) | `assets/art/backgrounds/settings/site.jpg` | Roman Kravtsov — [Unsplash](https://unsplash.com/photos/portable-buildings-and-construction-materials-on-site-3aX0xSHWn6A) | Unsplash License | ✅ |
| Interview backdrop: tower lobby (Dennis) | `assets/art/backgrounds/settings/lobby.jpg` | Aalo Lens — [Unsplash](https://unsplash.com/photos/modern-reception-desk-with-marble-and-wood-accents-ke212Tnsmw0) | Unsplash License | ✅ |
| Interview backdrop: interrogation room (Marco) | `assets/art/backgrounds/settings/interrogation.jpg` | rawpixel.com — [Magnific](https://www.magnific.com/free-photo/dark-small-room-with-table-chair_2989655.htm) | Magnific free license — **attribution required**: *"Image by rawpixel.com on Magnific"*. Goes on the in-game credits screen with the Font Awesome and Calciumtrice lines | ✅ |
| Interview backdrop: carinderia (Carmen) | `assets/art/backgrounds/settings/canteen.jpg` | Denniz Futalan — [Pexels](https://www.pexels.com/photo/authentic-filipino-eatery-inside-dumaguete-market-37899233/), *Authentic Filipino Eatery Inside Dumaguete Market*; 1920x1440 (replaced 2026-09-20 - the earlier file here was a blog photo with no license, and is gone from the repo) | Pexels License (free to use, attribution not required) | ✅ |

## Fonts

| Asset | Location | Source / Author | License | Status |
|---|---|---|---|---|
| IBM Plex Sans | `assets/fonts/IBM_Plex_Sans/` | IBM | SIL Open Font License 1.1 | ✅ |
| IBM Plex Mono | `assets/fonts/IBM_Plex_Mono/` | IBM Corp. | SIL Open Font License 1.1 — confirmed, `OFL.txt` bundled | ✅ |
| Kenney Fonts | `assets/art/ui/kenney_kenney-fonts/Fonts/` | Kenney (kenney.nl) | CC0 | ✅ |

## Audio

Freesound files keep the site's `<id>__<username>__<description>` name; everything else is
named for what it does in the game. Licenses below are as the user recorded them when the
files were downloaded (2026-09-19) or as read off the sound's page (2026-09-20).
**Every CC-BY line goes on the in-game credits screen.**

### Ambience (loops under a scene)

| Asset | Location | Author / source | License | Status |
|---|---|---|---|---|
| Street bed (Sampaguita Street, Terminal Road) | `assets/audio/ambience/street.ogg` | kevp888 - *LS_33886_PH_Street* - [freesound.org/s/441454](https://freesound.org/s/441454/). A 100 s cut of the 43 MB original, crossfaded to loop, encoded to OGG; the original is outside the repo in `downloads/audio-originals/` | **CC-BY 4.0** - attribution required | ✅ |
| Office bed (Call Floor, Tech Support Floor; the Anti-Fraud Desk at -22 dB) | `assets/audio/ambience/call_floor.ogg` | qubodup - *The Office* - [freesound.org/s/211945](https://freesound.org/s/211945/). A 100 s cut of the FLAC original (Godot cannot read FLAC), same treatment | **CC-BY 4.0** - attribution required | ✅ |

Also downloaded and credited by the user but **not in the repo and not used**: kevp888's
*LS_34158_PH_StreetAndStation* (671498, CC-BY 4.0; moved to `downloads/audio-originals/`),
and seven CC0 room-tone/office sounds (stomachache 192529, keweldog 181708, vrodge 119555,
esperri 119154, DiArchangeli 108695, shaugestuen 89985, beckmen 79711) that were never
copied into `assets/audio/`. Nothing is owed for them unless one is wired in later.

### Music

| Asset | Location | Author / source | License | Status |
|---|---|---|---|---|
| Main menu | `assets/audio/music/tension_loop.ogg` | Tsorthan Grove - *Tension* - [opengameart.org/content/tension](https://opengameart.org/content/tension). Encoded from the FLAC the author ships | **CC-BY 4.0** - credit line: *"Tension by Tsorthan Grove - CC-BY 4.0"* | ✅ |
| Prologue (under the calls) | `assets/audio/music/thought_loop.ogg` | GloryToTheMachine - *Thought Loop* (OpenGameArt). Encoded from the author's FLAC | **CC-BY 4.0** - the author's required notice: *"Music by GloryToTheMachine"* | ✅ |
| Ending screens | `assets/audio/music/something_isnt_adding_up.ogg` | Spring Spring - *I know he's the culprit, but something just isn't adding up here...* from *The Puppyland Serial Murder Case* (OpenGameArt). Unmodified, renamed | **CC-BY-SA 4.0** - required notice: *"Produced by Julie Damsgaard/Spring Spring/Spring Enterprises @ https://spring-enterprises.neocities.org"* | ✅ |
| Reserved (not yet played anywhere; `MUSIC["crime_scene"]`) | `assets/audio/music/crime_scene.ogg` | Spring Spring - *Crime Scene*, same album | CC-BY-SA 4.0, same notice | ✅ |

The album's other two tracks (*Tybarne*, *Dio e popolo*) were moved to `downloads/audio-originals/` unused.

### Sound effects

| Asset | Location | Author / source | License | Status |
|---|---|---|---|---|
| Button click, journal tab, door, statement landed, objective done, statement missed | `assets/audio/sfx/ui/click.ogg`, `tab.ogg`, `door.ogg`, `confirm.ogg`, `objective.ogg`, `error.ogg` | Kenney - *Interface Sounds* (kenney.nl): `click_001`, `click_003`, `open_001`, `confirmation_001`, `confirmation_002`, `error_004`, copied under short names. The full pack, and the unused *UI Audio* pack, are in `downloads/audio-originals/` | CC0 | ✅ |
| Journal opens | `assets/audio/sfx/page_turn.ogg` | jephwallace - *turning pages book slow quickly* - [freesound.org/s/318615](https://freesound.org/s/318615/); one turn cut from the recording | CC0 | ✅ |
| Something new written in the journal (tactic, milestone) | `assets/audio/sfx/pen_scratch.ogg` | MoKoLoKo - *Writing with a felt tip pen* - [freesound.org/s/325133](https://freesound.org/s/325133/); 1.2 s cut | **CC-BY 4.0** - attribution required | ✅ |
| Footsteps | `assets/audio/sfx/477357__nuff3__steps-tile_3a.ogg` | nuFF3 - *Steps-Tile_3a* - [freesound.org/s/477357](https://freesound.org/s/477357/) | **CC-BY 4.0** - attribution required | ✅ |
| A caller hangs up on you | `assets/audio/sfx/575853__martian__intercom-bell-phone-hang-up.wav` | martian - *intercom bell phone hang up* - [freesound.org/s/575853](https://freesound.org/s/575853/) | CC0 | ✅ |
| Dial tone (prologue) | `assets/audio/sfx/360480__giddster__dial-tone.wav` | giddster - *Dial tone* - [freesound.org/s/360480](https://freesound.org/s/360480/) | **CC0** (read off the page 2026-09-20) | ✅ |
| Report filed (prologue) | `assets/audio/sfx/434379__kila_vat__notification-sound-handmade.mp3` | kila_vat - *Notification Sound (handmade)* - [freesound.org/s/434379](https://freesound.org/s/434379/) | **CC-BY 4.0** (read off the page 2026-09-20) - attribution required; on the credits screen | ✅ |
| Phone ringing 5 (prologue) | `assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3` | AUDACITIER - *Phone Ringing #5* - [freesound.org/s/629201](https://freesound.org/s/629201/) | **CC-BY 4.0** (read off the page 2026-09-20) - attribution required; on the credits screen | ✅ |
| Radio static | `assets/audio/sfx/524204__joviansounds__radio-static.wav` | JovianSounds - [freesound.org/s/524204](https://freesound.org/s/524204/) | CC0 (confirmed) | ✅ - **no longer referenced**; the interview's miss sting is Kenney's `error.ogg` since 2026-09-19 |

## Open items

1. **Identify the `urban/` tile sheets.** They draw the city block the whole investigation
   walks around, and nobody knows where they came from. Ask whoever downloaded the art —
   their itch.io library or browser download history will answer it far faster than
   searching. Failing that, replace them with the Kenney *Roguelike Modern City* / *RPG
   Urban Pack* already in this project, both CC0.
2. Identify the remaining ⚠️ art: the `office/` floor and wall tiles, the numbered `pack/`
   character sheets, and the player detective sprite. All sixteen portraits are resolved:
   four are Calciumtrice's pack (CC-BY 3.0), twelve are AI-generated by the team.
3. ~~Confirm the three prologue Freesound SFX still marked ⚠️ (360480, 434379, 629201).~~
   Read off their pages 2026-09-20: the dial tone is CC0; the notification and the ring
   are CC-BY 4.0 and went on the credits screen the same day. Nothing in the build is
   CC-BY-NC.
4. ~~The interrogation-room backdrop (Magnific / rawpixel.com) requires attribution — the
   credits screen must carry "Image by rawpixel.com on Magnific".~~ On the screen since
   2026-09-20. ~~The carinderia backdrop (`settings/canteen.jpg`) has no license at all.~~
   Replaced the same day with a Pexels photo (Denniz Futalan); nothing in the build is
   unlicensed now except the `urban/` tile sheets in item 1.
5. ~~Font Awesome Free icons are CC BY 4.0 — the credits screen must include an attribution
   line ... "Portrait Pack by Calciumtrice, usable under Creative Commons Attribution 3.0
   license."~~ Both on the screen since 2026-09-20, with the music and Freesound lines;
   `test_credits` pins all ten.
4. Modern Office 2D Props Pack (nacl1234) forbids standalone redistribution — fine as
   embedded assets in the compiled game, just don't ship the raw PNG/JSON files separately.
