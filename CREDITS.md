# Asset Credits — Dial and Deceive

Tracking file for every third-party art/audio/font asset used in the game, so we can
build an in-game credits screen and stay license-compliant. Update this whenever a
new asset is added under `assets/`.

Status legend: ✅ confirmed from bundled license/readme · ⚠️ needs verification (no
license file bundled, or license terms require per-file checking).

> **Redistribution note — read before making the repository public.**
> Two packs here permit use in a built game but forbid redistributing the raw
> files: **Modern Office 2D Props** ("Resell, sublicense, share, or redistribute
> the assets as standalone files" is not permitted) and **Pixel Life – Desk
> Essentials** ("no resale or redistribution of standalone files"). Committing
> their PNGs to a public Git repository is redistribution of standalone files,
> which those terms do not allow — shipping them inside an exported `.exe` is
> what they do allow. This is unresolved. Options: keep the repository private,
> remove those assets from version control, or replace them with CC0
> equivalents.
>
> Separately, **Font Awesome** (CC BY 4.0) and **Pixel Life** (CC BY 4.0) both
> *require* attribution in the shipped game, not just in this file. The planned
> in-game credits screen is what satisfies that.

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
| Modern Office 2D Props Pack v1.0 | `assets/art/maps/ModernOffice2DProps_v1.0/` | nacl1234 | Commercial license — embed in compiled build only, no standalone redistribution | ✅ (note: cannot resell/redistribute as raw files) |
| Little Bits: Office (tileset + businessman1 character) | `assets/art/maps/Little_Bits_Office_tileset/` | AdricCustoms — [itch.io](https://adriccustoms.itch.io/little-bits-office) | Name-your-own-price; creator states use is unrestricted ("Use it for whatever you like"). No formal license text published | ✅ identified, terms informal |
| Pixel Life – Desk Essentials | `assets/art/maps/Pixel Life - Desk Essentials/` | Chris Perich — [itch.io](https://christianperich.itch.io/pixel-life-office-essentials) (download "Pixel Life - Desk Essentials.zip") | **CC BY 4.0 — attribution required.** Page also states no resale or redistribution of standalone files | ⚠️ attribution required; see redistribution note below |
| Office/urban tile sheets (`office/`, `urban/` — desk, cabinet, printer, buses, roads, etc.) | `assets/art/maps/office/`, `assets/art/maps/urban/` | ⚠️ appears to match a "Modern City Game Kit" style pack; see `Modern_City_GameKit` below — likely same source, files renamed/flattened | ⚠️ unknown | ⚠️ needs source lookup |
| Modern City GameKit (characters, props, tiles, Aseprite sources) | `assets/art/characters/Modern_City_GameKit/` | ⚠️ Still unidentified. Searched itch.io/OpenGameArt for the name and for distinctive filenames (`Detective_idle_front-Sheet`, `NPC_Copper_Idle-Sheet`, `traffic lights animation-Sheet`) with no match. Ships `.aseprite` sources, so it is likely a paid or bundled itch.io pack | ⚠️ unknown | ⚠️ unresolved — highest priority |
| 25 Portrait Pixel Art pack1 | `assets/art/characters/25_portrait_pixel_art_pack1/` | phoenix1291 (Swiss Arcade Game Entertainment) — [itch.io](https://phoenix1291.itch.io/25-portrait-pixel-art-pack1) | Free / pay-what-you-think-is-fair. **No license terms stated on the page** — only "support me if you like my work" | ⚠️ source identified, terms unstated |
| FG11 Trial (OfficeMan expression sprites) | `assets/art/characters/FG11_Trial/` | ⚠️ Still unidentified; no match for "FG11". Filenames (`103_OfficeMan_Angry/Normal/Sad/Smile/Special`) match the shape of a visual-novel character pack sold with a free sampler. **The folder name says "Trial"**, and trial/sampler builds commonly forbid redistribution | ⚠️ unknown | ⚠️ unresolved — treat as unsafe to ship |
| MetroCity — Free Top Down Character Pack | `assets/art/characters/MetroCity/` | JIK-A-4 — [itch.io](https://jik-a-4.itch.io/metrocity-free-topdown-character-pack) | CC0. Creator: "You can use it as you wish"; credit appreciated, not required. Commercial use confirmed by the creator | ✅ |
| MetroCity 2.0 (hair/suit sprites) | `assets/art/characters/MetroCity 2.0/` | JIK-A-4 — same pack, [Update 2.0](https://jik-a-4.itch.io/metrocity-free-topdown-character-pack) (Jan 2024, added "Suits and more") | CC0, as above | ✅ |
| Numbered character pack (`pack/pack/1.png`…) | `assets/art/characters/pack/` | ⚠️ unidentified — no bundled license found | ⚠️ unknown | ⚠️ needs source lookup |
| Player detective sprite (idle/walk, 4 directions) | `assets/art/characters/player/` | ⚠️ unidentified — likely custom or from one of the packs above | ⚠️ unknown | ⚠️ needs source lookup |
| Portraits (fella 1/2, lady 1/2) | `assets/art/portraits/` | ⚠️ No pack found. PNG metadata records `Software: Celsys Studio Tool` (Clip Studio Paint), which suggests hand-drawn artwork rather than a downloaded pack — **ask the team whether a member drew these** | ⚠️ unknown | ⚠️ confirm with the team first |
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

| Asset | Location | Freesound user | Freesound ID | License |
|---|---|---|---|---|
| Office ambience | `assets/audio/ambience/407292__nightwatcher98__office-ambience.mp3` | nightwatcher98 | [407292](https://freesound.org/s/407292/) | ⚠️ verify on Freesound |
| Dial tone | `assets/audio/sfx/360480__giddster__dial-tone.wav` | giddster | [360480](https://freesound.org/s/360480/) | ⚠️ verify on Freesound |
| Phone ring | `assets/audio/sfx/405319__sapatac__phone-ring.wav` | sapatac | [405319](https://freesound.org/s/405319/) | ⚠️ verify on Freesound |
| Notification sound (handmade) | `assets/audio/sfx/434379__kila_vat__notification-sound-handmade.mp3` | kila_vat | [434379](https://freesound.org/s/434379/) | ⚠️ verify on Freesound |
| Keyboard typing sounds | `assets/audio/sfx/469014__zrrion__keyboard-typing-sounds.mp3` | zrrion | [469014](https://freesound.org/s/469014/) | ⚠️ verify on Freesound |
| Radio static | `assets/audio/sfx/524204__joviansounds__radio-static.wav` | joviansounds | [524204](https://freesound.org/s/524204/) | ⚠️ verify on Freesound |
| Phone ringing 5 | `assets/audio/sfx/629201__audacitier__phone-ringing-5.mp3` | audacitier | [629201](https://freesound.org/s/629201/) | ⚠️ verify on Freesound |

No music tracks are currently in `assets/audio/music/` (empty).

## Open items

1. Identify the source/license for the packs marked ⚠️ above (Little Bits Office tileset,
   Pixel Life – Desk Essentials, Modern City GameKit + the flattened `office/`/`urban/`
   sheets, 25 Portrait Pixel Art Pack 1, FG11 Trial, MetroCity/MetroCity 2.0, the numbered
   `pack/` character sheets, the player detective sprite, and the four loose portraits).
   Check the itch.io/download folder these came from, or any purchase receipts/emails.
2. Confirm each Freesound SFX's actual license (CC0 vs CC-BY vs CC-BY-NC) — CC-BY entries
   need "Author — title (freesound.org)" in the credits screen; CC-BY-NC entries are not
   safe to ship in a commercial release.
3. Font Awesome Free icons are CC BY 4.0 — the credits screen must include an attribution
   line for Font Awesome (fontawesome.com) since these are not the CC0 subset.
4. Modern Office 2D Props Pack (nacl1234) forbids standalone redistribution — fine as
   embedded assets in the compiled game, just don't ship the raw PNG/JSON files separately.
