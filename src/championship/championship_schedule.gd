class_name ChampionshipSchedule
extends Resource
## One championship: its rounds (circuit, biome, time of day, laps) and the
## points per finishing position. Configurable as resources
## (src/championship/*.tres); the game rotates through the schedules listed in
## SCHEDULES, so later championships race different combinations.

const SCHEDULES: Array[String] = [
	"res://src/championship/hypercars_cup.tres",
	"res://src/championship/night_series.tres",
]

@export var title := "HyperCars Cup"
## Per round: DevLayouts id, biome (theme variant 1..3), night, laps.
@export var layouts: PackedStringArray = PackedStringArray()
@export var variants: PackedInt32Array = PackedInt32Array()
@export var nights: Array[bool] = []
@export var laps: PackedInt32Array = PackedInt32Array()
## Points for 1st, 2nd, ...; positions beyond the list and DNFs score nothing.
@export var points: PackedInt32Array = PackedInt32Array([25, 18, 15, 12, 10, 8, 6, 4, 2, 1])


func round_count() -> int:
	return layouts.size()


func get_round(i: int) -> Dictionary:
	return {"layout": layouts[i], "variant": variants[i], "night": nights[i], "laps": laps[i]}


func points_for(position: int) -> int:
	return points[position - 1] if position >= 1 and position <= points.size() else 0


## "Round 1: Kestrel Ridge - Green Valley, day, 3 laps" lines.
func describe() -> String:
	var lines := PackedStringArray([title.to_upper()])
	for i in round_count():
		var r: Dictionary = get_round(i)
		lines.append("Round %d:  %s  -  %s, %s, %d laps" % [i + 1, DevLayouts.display_name(r.layout),
			TrackTheme.load_variant(r.variant).display_name, "night" if r.night else "day", r.laps])
	return "\n".join(lines)


## The schedule for the n-th championship (0-based), cycling through SCHEDULES.
static func for_run(n: int) -> ChampionshipSchedule:
	return load(SCHEDULES[posmod(n, SCHEDULES.size())])
