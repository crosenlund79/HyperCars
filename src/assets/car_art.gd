class_name CarArt
extends RefCounted
## Which images a car is drawn with (P2 animated wheels). Every car has a
## wheel-free body ("cars/body_*") that the game completes with four instances
## of the shared wheel ("cars/wheel"). A user's older flattened car image
## ("cars/car_*", wheels painted in) is still honoured: when it is overridden
## and no body override exists, it is drawn as it is, without extra wheels, so
## nothing is doubled.

## Slight per-rival tints for the junker (index = racer id).
const JUNKER_TINTS: Array[Color] = [Color(1, 1, 1), Color(1, 0.92, 0.9), Color(0.92, 0.95, 1),
	Color(0.96, 1, 0.9), Color(1, 0.97, 0.86), Color(0.94, 0.9, 1), Color(1, 0.9, 0.96),
	Color(0.9, 1, 0.98), Color(1, 0.95, 0.92), Color(0.9, 0.94, 0.94)]


## {body: Texture2D, wheels: bool, body_logical: String} for a car image name.
static func look(resolver: AssetResolver, car_logical: String) -> Dictionary:
	var body := AssetCatalog.body_of(car_logical)
	if resolver.has_override(body) or not resolver.has_override(car_logical):
		return {"body": resolver.get_texture(body), "wheels": true, "body_logical": body}
	return {"body": resolver.get_texture(car_logical), "wheels": false, "body_logical": car_logical}


## Picture of the complete car for icons (standings, results, title): the
## flattened car image, or the user's body when only that is supplied.
static func icon(resolver: AssetResolver, car_logical: String) -> Texture2D:
	var body := AssetCatalog.body_of(car_logical)
	if resolver.has_override(body) and not resolver.has_override(car_logical):
		return resolver.get_texture(body)
	return resolver.get_texture(car_logical)
