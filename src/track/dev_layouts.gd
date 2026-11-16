class_name DevLayouts
extends RefCounted
## Track layouts besides the classic circuit. Chosen on the title screen
## (LAYOUT button, never saved: every launch starts on the classic circuit) or,
## for developer testing, with a command-line argument after "--", e.g.
##   godot --path . -- --layout=exp_figure8_01
## which preselects that layout on the title screen. The visual theme (TRACK
## button: Green Valley / Heather Moor / Snow Pass) is independent of the
## layout. Unknown ids are ignored with a warning. Id "" = the classic circuit.

const LAYOUTS := {
	"exp_figure8_01": "res://src/track/layouts/exp_figure8_01.tres",
}
const ARG := "--layout="
const CLASSIC := ""
const NAMES := {
	"": "Classic Circuit",
	"exp_figure8_01": "Figure Eight (Experimental)",
}


## Layout ids in menu order (the classic circuit first).
static func ids() -> Array[String]:
	var out: Array[String] = [CLASSIC]
	for id in LAYOUTS:
		out.append(id)
	return out


static func display_name(id: String) -> String:
	return NAMES.get(id, id)


## The layout resource for an id (null = the scene's classic circuit).
static func load_layout(id: String) -> TrackLayout:
	return load(LAYOUTS[id]) if LAYOUTS.has(id) else null


## The id of a loaded layout ("" for the classic circuit or an unknown one).
static func id_of(layout: TrackLayout) -> String:
	if layout != null:
		for id in LAYOUTS:
			if LAYOUTS[id] == layout.resource_path:
				return id
	return CLASSIC


## Id given on the command line ("" when none or unknown).
static func selected_id(args: PackedStringArray = OS.get_cmdline_user_args()) -> String:
	for a in args:
		if a.begins_with(ARG):
			var id := a.substr(ARG.length())
			if LAYOUTS.has(id):
				return id
			push_warning("DevLayouts: unknown layout '%s' (known: %s)" % [id, ", ".join(LAYOUTS.keys())])
	return ""


## The selected experimental layout, or null for the normal circuit.
static func load_selected(args: PackedStringArray = OS.get_cmdline_user_args()) -> TrackLayout:
	var id := selected_id(args)
	return load(LAYOUTS[id]) if not id.is_empty() else null
