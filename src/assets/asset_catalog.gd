class_name AssetCatalog
extends RefCounted
## Replacement contract for every graphic used by the game.
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
