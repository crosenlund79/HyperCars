class_name AssetCatalog
extends RefCounted
## Replacement contract for every graphic and sound used by the game.
## Overrides may use any resolution but must keep the template's aspect ratio and
## orientation; the game scales each texture to its display size in world pixels.

const CAR_PLAYER := "cars/car_player"
## Opponent cars: "cars/car_ai_1" .. "cars/car_ai_9" (see ai_car()).
const AI_CAR_COUNT := 9
const TARMAC := "track/tarmac"
const GRASS := "track/grass"
const WALL := "track/wall"
const START_LINE := "track/start_line"
const HUD_PANEL := "ui/hud_panel"
const STAR_GOLD := "ui/star_gold"
const STAR_SILVER := "ui/star_silver"
const STAR_BRONZE := "ui/star_bronze"
const BUTTON := "ui/button"
const LOGO := "ui/logo"
const TREE_ROUND := "scenery/tree_round"
const TREE_BLOOM := "scenery/tree_bloom"
const BUSH := "scenery/bush"
const FLOWERS := "scenery/flowers"
const ROCK := "scenery/rock"
const TYRE_STACK := "scenery/tyre_stack"
const FLAG := "scenery/flag"
const GRANDSTAND := "scenery/grandstand"
const ROAD_WEAR := "decals/road_wear"
const GRID_BOX := "decals/grid_box"
const TIRE_MARK := "decals/tire_mark"
const SMOKE := "fx/smoke"
const DUST := "fx/dust"
const SPARK := "fx/spark"
const CONFETTI := "fx/confetti"
const MISSILE := "weapons/missile"
const MINE := "weapons/mine"
const BLAST := "fx/blast"
const LAMP_POST := "scenery/lamp_post"
const HOMING_MISSILE := "weapons/homing_missile"
const SUPER_MISSILE := "weapons/super_missile"
const GARAGE_BACKDROP := "ui/garage_backdrop"

## display_size: world/screen pixels the texture is scaled to (sprites, strips).
## tile_world_size: world pixels covered by one repeat of a seamless tile.
const SPECS := {
	CAR_PLAYER: {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Top-down, nose pointing right (+X), centred pivot, transparent background."},
	"cars/car_ai_1": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 1; same contract as the player car."},
	"cars/car_ai_2": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 2; same contract as the player car."},
	"cars/car_ai_3": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 3; same contract as the player car."},
	"cars/car_ai_4": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 4; same contract as the player car."},
	"cars/car_ai_5": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 5; same contract as the player car."},
	"cars/car_ai_6": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 6; same contract as the player car."},
	"cars/car_ai_7": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 7; same contract as the player car."},
	"cars/car_ai_8": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 8; same contract as the player car."},
	"cars/car_ai_9": {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Opponent car 9; same contract as the player car."},
	TARMAC: {"template_size": Vector2i(256, 256), "tile_world_size": 256.0,
		"notes": "Seamless repeating road surface, opaque."},
	GRASS: {"template_size": Vector2i(256, 256), "tile_world_size": 256.0,
		"notes": "Seamless repeating off-track ground, opaque."},
	WALL: {"template_size": Vector2i(128, 32), "display_size": Vector2(80, 20),
		"notes": "Barrier strip, seamless left-right, repeated along the track edge; transparent background."},
	START_LINE: {"template_size": Vector2i(32, 128), "display_size": Vector2(24, 150),
		"notes": "Start/finish strip, long axis across the road; stretched to road width."},
	HUD_PANEL: {"template_size": Vector2i(96, 96), "patch_margin": 24,
		"notes": "Nine-patch panel; 24 px corners are not stretched (scaled with the texture)."},
	STAR_GOLD: {"template_size": Vector2i(48, 48), "display_size": Vector2(22, 22),
		"notes": "1st place marker in the race history; square, centred, transparent background."},
	STAR_SILVER: {"template_size": Vector2i(48, 48), "display_size": Vector2(22, 22),
		"notes": "2nd place marker; same contract as the gold star."},
	STAR_BRONZE: {"template_size": Vector2i(48, 48), "display_size": Vector2(22, 22),
		"notes": "3rd place marker; same contract as the gold star."},
	BUTTON: {"template_size": Vector2i(96, 48), "patch_margin": 16,
		"notes": "Menu button nine-patch (16 px corners); hover/pressed/focus states are tints of it."},
	LOGO: {"template_size": Vector2i(880, 240), "display_size": Vector2(660, 180),
		"notes": "Title logo; transparent background, centred."},
	TREE_ROUND: {"template_size": Vector2i(128, 128), "display_size": Vector2(128, 128),
		"notes": "Top-down tree canopy, centred, transparent; sways gently."},
	TREE_BLOOM: {"template_size": Vector2i(112, 112), "display_size": Vector2(112, 112),
		"notes": "Top-down blossom tree, centred, transparent; sways gently."},
	BUSH: {"template_size": Vector2i(72, 72), "display_size": Vector2(72, 72), "notes": "Top-down bush, centred, transparent."},
	FLOWERS: {"template_size": Vector2i(64, 64), "display_size": Vector2(64, 64), "notes": "Flower patch, centred, transparent."},
	ROCK: {"template_size": Vector2i(56, 56), "display_size": Vector2(56, 56), "notes": "Rock, centred, transparent."},
	TYRE_STACK: {"template_size": Vector2i(56, 56), "display_size": Vector2(56, 56), "notes": "Tyre stack, centred, transparent."},
	FLAG: {"template_size": Vector2i(96, 64), "display_size": Vector2(48, 64), "frames": 2,
		"notes": "Marshal flag: horizontal strip of 2 frames (48x64 each), pole foot at bottom-left third."},
	GRANDSTAND: {"template_size": Vector2i(192, 80), "display_size": Vector2(288, 120),
		"notes": "Top-down grandstand; the crowd side (bottom edge) faces the track."},
	ROAD_WEAR: {"template_size": Vector2i(160, 64), "display_size": Vector2(240, 96),
		"notes": "Semi-transparent road wear decal, long axis along the driving direction."},
	GRID_BOX: {"template_size": Vector2i(72, 48), "display_size": Vector2(72, 48),
		"notes": "Painted grid-slot bracket; open side faces the driving direction (+X)."},
	TIRE_MARK: {"template_size": Vector2i(32, 12), "display_size": Vector2(10, 26),
		"notes": "Pair of rear-tyre marks along +X (stamped repeatedly while sliding); seamless left-right."},
	SMOKE: {"template_size": Vector2i(32, 32), "display_size": Vector2(32, 32), "notes": "Tyre-smoke particle, soft, transparent."},
	DUST: {"template_size": Vector2i(32, 32), "display_size": Vector2(32, 32), "notes": "Dust particle, soft, transparent."},
	SPARK: {"template_size": Vector2i(24, 24), "display_size": Vector2(24, 24), "notes": "Impact spark particle."},
	CONFETTI: {"template_size": Vector2i(12, 12), "display_size": Vector2(12, 12),
		"notes": "White confetti piece; tinted at runtime, so keep it white/light."},
	MISSILE: {"template_size": Vector2i(40, 16), "display_size": Vector2(30, 12),
		"notes": "Missile, nose pointing right (+X), centred; also the HUD missile icon. Homing/super missiles are tinted."},
	MINE: {"template_size": Vector2i(64, 32), "display_size": Vector2(26, 26), "frames": 2,
		"notes": "Mine: horizontal strip of 2 frames (32x32 each: lamp off / lamp on), blinks while armed; also the HUD mine icon."},
	BLAST: {"template_size": Vector2i(96, 96), "display_size": Vector2(110, 110),
		"notes": "Explosion burst, centred, transparent; scaled up and faded out."},
	HOMING_MISSILE: {"template_size": Vector2i(40, 16), "display_size": Vector2(30, 12),
		"notes": "Homing missile, nose pointing right (+X), centred; also the HUD / garage icon."},
	SUPER_MISSILE: {"template_size": Vector2i(40, 20), "display_size": Vector2(34, 17),
		"notes": "Super missile (orbits its car), nose pointing right (+X), centred; also the HUD / garage icon."},
	GARAGE_BACKDROP: {"template_size": Vector2i(640, 360), "display_size": Vector2(1280, 720),
		"notes": "Garage screen background, full screen (16:9), opaque; the centre is covered by the weapon cards."},
	LAMP_POST: {"template_size": Vector2i(48, 48), "display_size": Vector2(56, 56),
		"notes": "Lighting pilot: top-down lamp post, lamp head towards the top (-Y), rotated to face the track."},
}

## Replaceable audio: logical name -> spec. bus: Music / Engine / Effects.
const AUDIO := {
	"vehicles/engine_loop": {"loop": true, "bus": "Engine",
		"notes": "Seamless engine loop around 46 Hz fundamental; pitched up with speed. WAV recommended for exact looping."},
	"vehicles/tire_squeal": {"loop": true, "bus": "Effects", "notes": "Seamless tyre squeal loop; WAV recommended."},
	"vehicles/impact_car": {"loop": false, "bus": "Effects", "notes": "Car-to-car bump, < 1 s."},
	"vehicles/impact_wall": {"loop": false, "bus": "Effects", "notes": "Car hits barrier, < 1 s."},
	"race/start_go": {"loop": false, "bus": "Effects", "notes": "Played when the race starts."},
	"race/finish": {"loop": false, "bus": "Effects", "notes": "Finish jingle (player finishes / spectator winner)."},
	"ui/ui_move": {"loop": false, "bus": "Effects", "notes": "Menu focus change."},
	"ui/ui_select": {"loop": false, "bus": "Effects", "notes": "Menu confirm."},
	"ui/ui_back": {"loop": false, "bus": "Effects", "notes": "Menu back."},
	"ambience/ambience": {"loop": true, "bus": "Effects", "notes": "Trackside ambience loop (wind, birds), stereo."},
	"music/music_menu": {"loop": true, "bus": "Music", "notes": "Menu music loop, stereo."},
	"music/music_race": {"loop": true, "bus": "Music", "notes": "Race music loop, stereo."},
	"weapons/missile_launch": {"loop": false, "bus": "Effects", "notes": "Missile fired."},
	"weapons/explosion": {"loop": false, "bus": "Effects", "notes": "Missile/mine explosion and car destroyed."},
	"weapons/mine_drop": {"loop": false, "bus": "Effects", "notes": "Mine dropped (clunk + arming beep)."},
	"weapons/empty": {"loop": false, "bus": "Effects", "notes": "Fire pressed with no ammunition left."},
	"ui/shop_buy": {"loop": false, "bus": "Effects", "notes": "Garage: weapon bought (coins)."},
	"ui/shop_sell": {"loop": false, "bus": "Effects", "notes": "Garage: weapon sold."},
	"weapons/homing_launch": {"loop": false, "bus": "Effects", "notes": "Homing missile fired (launch + seeker chirp)."},
	"weapons/super_launch": {"loop": false, "bus": "Effects", "notes": "Super missile fired (rising whirl)."},
}


## Logical name of opponent car n (1-based), cycling if more cars than templates.
static func ai_car(n: int) -> String:
	return "cars/car_ai_%d" % ((n - 1) % AI_CAR_COUNT + 1)


## Converts a world-space tile size to the UV scale for a texture of any resolution.
static func uv_per_world_pixel(texture: Texture2D, tile_world_size: float) -> Vector2:
	return Vector2(texture.get_width(), texture.get_height()) / tile_world_size


## Scale that maps a texture of any resolution onto its display size.
static func scale_for(texture: Texture2D, display_size: Vector2) -> Vector2:
	return display_size / Vector2(texture.get_width(), texture.get_height())
