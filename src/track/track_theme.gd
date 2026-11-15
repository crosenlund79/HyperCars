class_name TrackTheme
extends Resource
## One visual theme variant of the circuit (Variant 1, 2, 3 ...). Visual only:
## the layout, collision, physics and race rules are identical for every
## variant. Internal names stay generic ("variant_N"); only display_name is
## thematic, so artwork can be replaced without renaming code or folders.
##
## Assets: a variant looks up "variant_N/<logical name>" first (when the asset
## catalogue defines it) and otherwise falls back to the shared asset, so a
## variant only provides what it changes. Variant 1 is the baseline and uses
## the shared assets directly.

const VARIANT_COUNT := 3
const PATH := "res://src/track/themes/variant_%d.tres"

@export_range(1, 9) var variant := 1
## Name shown in menus (thematic; never used as an identifier).
@export var display_name := "Variant 1"
## Trackside props: shared logical asset names (resolved per variant), their
## relative frequency and whether they sway (tall props). Same placement
## algorithm and seed for every variant.
@export var scenery: Array[String] = []
@export var scenery_weights: Array[float] = []
@export var scenery_sway: Array[bool] = []
## Colour of the dust a car throws up when it runs off the road.
@export var dust_color := Color(0.75, 0.66, 0.5, 0.7)


## The asset this variant uses for a shared logical name.
func asset(logical: String) -> String:
	return AssetCatalog.themed(logical, variant)


static func load_variant(n: int) -> TrackTheme:
	return load(PATH % clampi(n, 1, VARIANT_COUNT))
