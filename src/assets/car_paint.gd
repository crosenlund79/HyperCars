class_name CarPaint
extends RefCounted
## Championship reward cars: a rival's car repainted in the player's red.
## The body's main paint colour (the most common saturated hue) is turned
## red; windows, accents, outlines and shading keep their colours, so the
## silhouette and details stay the rival's. Done once per race on the CPU, so
## the same picture serves the car sprite and every icon. Works for user art
## too; when an image cannot be read (or has no clear paint colour) the
## original texture is returned unchanged (the player marker still shows the
## player's car).

## The player's red (hue of template_body_player's paint).
const PLAYER_HUE := 0.03
## Hue distance from the main paint colour that still counts as paint.
const HUE_WINDOW := 0.07
const MIN_SATURATION := 0.25
const MIN_VALUE := 0.18


## The texture repainted with its main paint colour in player red, or the
## texture itself when that is not possible.
static func repaint(texture: Texture2D, hue: float = PLAYER_HUE) -> Texture2D:
	if texture == null:
		return texture
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var red := repaint_image(image, hue)
	return ImageTexture.create_from_image(red) if red != null else texture


## The repainted copy of an image, or null when it has no clear paint colour.
static func repaint_image(source: Image, hue: float = PLAYER_HUE) -> Image:
	var image := source.duplicate() as Image
	if image.is_compressed() and image.decompress() != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	var main_hue := dominant_hue(image)
	if main_hue < 0.0:
		return null
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a <= 0.0 or c.s < MIN_SATURATION or c.v < MIN_VALUE:
				continue
			if _hue_distance(c.h, main_hue) > HUE_WINDOW:
				continue
			# keep shading: same value, a little extra saturation so it reads red
			image.set_pixel(x, y, Color.from_hsv(hue, maxf(c.s, 0.55), c.v, c.a))
	return image


## Most common saturated hue (0..1) of the opaque pixels, -1 when there is none.
static func dominant_hue(image: Image) -> float:
	var bins := PackedInt32Array()
	bins.resize(36)
	var total := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a < 0.5 or c.s < MIN_SATURATION or c.v < MIN_VALUE:
				continue
			bins[int(c.h * 36.0) % 36] += 1
			total += 1
	if total < 20:
		return -1.0
	var best := 0
	for i in 36:
		if bins[i] > bins[best]:
			best = i
	return (best + 0.5) / 36.0


static func _hue_distance(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 1.0 - d)
