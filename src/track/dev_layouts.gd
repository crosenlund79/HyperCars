class_name DevLayouts
extends RefCounted
## Developer-only experimental track layouts (J0). Not in the TRACK menu and
## never saved: a layout is chosen for one run with a command-line argument
## after "--", e.g.
##   godot --path . -- --layout=exp_figure8_01
## The visual theme (TRACK button: Green Valley / Heather Moor / Snow Pass) is
## independent and still applies. Unknown ids are ignored with a warning.

const LAYOUTS := {
	"exp_figure8_01": "res://src/track/layouts/exp_figure8_01.tres",
}
const ARG := "--layout="


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
