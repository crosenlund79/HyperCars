class_name AssetCatalog
extends RefCounted
## Replacement contract for every graphic used in Milestone 1.
## Overrides may use any resolution but must keep the template's aspect ratio and
## orientation; the game scales each texture to its display size in world pixels.

const CAR_PLAYER := "cars/car_player"
const TARMAC := "track/tarmac"
const GRASS := "track/grass"
const WALL := "track/wall"
const START_LINE := "track/start_line"
const HUD_PANEL := "ui/hud_panel"

## display_size: world/screen pixels the texture is scaled to (sprites, strips).
## tile_world_size: world pixels covered by one repeat of a seamless tile.
const SPECS := {
	CAR_PLAYER: {"template_size": Vector2i(128, 72), "display_size": Vector2(64, 36),
		"notes": "Top-down, nose pointing right (+X), centred pivot, transparent background."},
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
}


## Converts a world-space tile size to the UV scale for a texture of any resolution.
static func uv_per_world_pixel(texture: Texture2D, tile_world_size: float) -> Vector2:
	return Vector2(texture.get_width(), texture.get_height()) / tile_world_size


## Scale that maps a texture of any resolution onto its display size.
static func scale_for(texture: Texture2D, display_size: Vector2) -> Vector2:
	return display_size / Vector2(texture.get_width(), texture.get_height())
