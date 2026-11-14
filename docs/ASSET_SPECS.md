# HyperCars replaceable assets

Generated from `src/assets/asset_catalog.gd` (the authoritative contract). Override rules: `assets/README.md`.

Put your file at the **override path** inside `custom/` (project folder while developing; next to the executable in an exported Windows/Linux game). Restart the game to see it. A missing or invalid file falls back to the packaged `template_` asset. Never edit files in `custom/` from tools; they are yours.

## Graphics (PNG)

Any resolution is accepted as long as the **aspect ratio and orientation** match the template; the game scales it to the display size. Cars face right (+X). Transparent backgrounds unless noted.

| Override path | Template size (px) | Display size (world px) | Notes |
|---|---|---|---|
| `custom/graphics/cars/car_ai_1.png` | 128 x 72 | 64 x 36 | Opponent car 1; same contract as the player car. |
| `custom/graphics/cars/car_ai_2.png` | 128 x 72 | 64 x 36 | Opponent car 2; same contract as the player car. |
| `custom/graphics/cars/car_ai_3.png` | 128 x 72 | 64 x 36 | Opponent car 3; same contract as the player car. |
| `custom/graphics/cars/car_ai_4.png` | 128 x 72 | 64 x 36 | Opponent car 4; same contract as the player car. |
| `custom/graphics/cars/car_ai_5.png` | 128 x 72 | 64 x 36 | Opponent car 5; same contract as the player car. |
| `custom/graphics/cars/car_ai_6.png` | 128 x 72 | 64 x 36 | Opponent car 6; same contract as the player car. |
| `custom/graphics/cars/car_ai_7.png` | 128 x 72 | 64 x 36 | Opponent car 7; same contract as the player car. |
| `custom/graphics/cars/car_ai_8.png` | 128 x 72 | 64 x 36 | Opponent car 8; same contract as the player car. |
| `custom/graphics/cars/car_ai_9.png` | 128 x 72 | 64 x 36 | Opponent car 9; same contract as the player car. |
| `custom/graphics/cars/car_player.png` | 128 x 72 | 64 x 36 | Top-down, nose pointing right (+X), centred pivot, transparent background. |
| `custom/graphics/decals/grid_box.png` | 72 x 48 | 72 x 48 | Painted grid-slot bracket; open side faces the driving direction (+X). |
| `custom/graphics/decals/road_wear.png` | 160 x 64 | 240 x 96 | Semi-transparent road wear decal, long axis along the driving direction. |
| `custom/graphics/decals/tire_mark.png` | 32 x 12 | 10 x 26 | Pair of rear-tyre marks along +X (stamped repeatedly while sliding); seamless left-right. |
| `custom/graphics/fx/confetti.png` | 12 x 12 | 12 x 12 | White confetti piece; tinted at runtime, so keep it white/light. |
| `custom/graphics/fx/dust.png` | 32 x 32 | 32 x 32 | Dust particle, soft, transparent. |
| `custom/graphics/fx/smoke.png` | 32 x 32 | 32 x 32 | Tyre-smoke particle, soft, transparent. |
| `custom/graphics/fx/spark.png` | 24 x 24 | 24 x 24 | Impact spark particle. |
| `custom/graphics/scenery/bush.png` | 72 x 72 | 72 x 72 | Top-down bush, centred, transparent. |
| `custom/graphics/scenery/flag.png` | 96 x 64 | 48 x 64 | Marshal flag: horizontal strip of 2 frames (48x64 each), pole foot at bottom-left third. |
| `custom/graphics/scenery/flowers.png` | 64 x 64 | 64 x 64 | Flower patch, centred, transparent. |
| `custom/graphics/scenery/grandstand.png` | 192 x 80 | 288 x 120 | Top-down grandstand; the crowd side (bottom edge) faces the track. |
| `custom/graphics/scenery/rock.png` | 56 x 56 | 56 x 56 | Rock, centred, transparent. |
| `custom/graphics/scenery/tree_bloom.png` | 112 x 112 | 112 x 112 | Top-down blossom tree, centred, transparent; sways gently. |
| `custom/graphics/scenery/tree_round.png` | 128 x 128 | 128 x 128 | Top-down tree canopy, centred, transparent; sways gently. |
| `custom/graphics/scenery/tyre_stack.png` | 56 x 56 | 56 x 56 | Tyre stack, centred, transparent. |
| `custom/graphics/track/grass.png` | 256 x 256 | tile = 256 | Seamless repeating off-track ground, opaque. |
| `custom/graphics/track/start_line.png` | 32 x 128 | 24 x 150 | Start/finish strip, long axis across the road; stretched to road width. |
| `custom/graphics/track/tarmac.png` | 256 x 256 | tile = 256 | Seamless repeating road surface, opaque. |
| `custom/graphics/track/wall.png` | 128 x 32 | 80 x 20 | Barrier strip, seamless left-right, repeated along the track edge; transparent background. |
| `custom/graphics/ui/button.png` | 96 x 48 | nine-patch, 16 px margins | Menu button nine-patch (16 px corners); hover/pressed/focus states are tints of it. |
| `custom/graphics/ui/hud_panel.png` | 96 x 96 | nine-patch, 24 px margins | Nine-patch panel; 24 px corners are not stretched (scaled with the texture). |
| `custom/graphics/ui/logo.png` | 880 x 240 | 660 x 180 | Title logo; transparent background, centred. |
| `custom/graphics/ui/star_bronze.png` | 48 x 48 | 22 x 22 | 3rd place marker; same contract as the gold star. |
| `custom/graphics/ui/star_gold.png` | 48 x 48 | 22 x 22 | 1st place marker in the race history; square, centred, transparent background. |
| `custom/graphics/ui/star_silver.png` | 48 x 48 | 22 x 22 | 2nd place marker; same contract as the gold star. |

## Audio (OGG Vorbis or WAV)

`.ogg` is looked up first, then `.wav`. Looping sounds loop over the whole file; use WAV when a loop must be sample-exact (OGG encoding can trim the end). Buses: Music, Engine, Effects (all under Master).

| Override path (.ogg or .wav) | Loops | Bus | Notes |
|---|---|---|---|
| `custom/audio/ambience/ambience` | yes | Effects | Trackside ambience loop (wind, birds), stereo. |
| `custom/audio/music/music_menu` | yes | Music | Menu music loop, stereo. |
| `custom/audio/music/music_race` | yes | Music | Race music loop, stereo. |
| `custom/audio/race/finish` | no | Effects | Finish jingle (player finishes / spectator winner). |
| `custom/audio/race/start_go` | no | Effects | Played when the race starts. |
| `custom/audio/ui/ui_back` | no | Effects | Menu back. |
| `custom/audio/ui/ui_move` | no | Effects | Menu focus change. |
| `custom/audio/ui/ui_select` | no | Effects | Menu confirm. |
| `custom/audio/vehicles/engine_loop` | yes | Engine | Seamless engine loop around 46 Hz fundamental; pitched up with speed. WAV recommended for exact looping. |
| `custom/audio/vehicles/impact_car` | no | Effects | Car-to-car bump, < 1 s. |
| `custom/audio/vehicles/impact_wall` | no | Effects | Car hits barrier, < 1 s. |
| `custom/audio/vehicles/tire_squeal` | yes | Effects | Seamless tyre squeal loop; WAV recommended. |

## Not replaceable through custom/

- Font: `assets/fonts/Fredoka.ttf` (Fredoka, SIL Open Font License 1.1; licence in `assets/fonts/Fredoka_OFL.txt`).
