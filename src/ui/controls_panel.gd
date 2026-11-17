class_name ControlsPanel
extends PanelContainer
## Controls and short how-to-play help.

signal closed

const ROWS := [
	["RACING", ""],
	["Steer", "Left / Right   (A / D, d-pad, left stick)"],
	["Fire", "Space / Ctrl   (pad A)"],
	["Fire to Accelerate", "Hold Fire to accelerate, release to brake"],
	["Fire to Brake", "Accelerates by itself, hold Fire to brake hard"],
	["Front / rear weapon", "Up / Down while racing   (W / S)"],
	["Weapons / style / laps", "Up / Down, C and Tab on the grid panel"],
	["Lighting pilot", "L (dusk lighting on / off, experiment)"],
	["Back to menu", "Esc on the grid or results"],
	["TWO PLAYERS", ""],
	["Join", "Race > Two players: each presses Cross / A (keyboard: Space)"],
	["Drive", "Own controller: stick / d-pad steer, Cross / A fire, up / down weapons"],
	["LAN / online", "Race > Two players: LAN / online. Host shares its address; see docs/NETWORK_PLAY.md"],
	["SPECTATING", ""],
	["Follow a driver", "Click a name in the standings, or the < > arrows (grid order)"],
	["History / Counts", "Tab"],
	["Hide / show panel", "H"],
	["Scroll history", "Left / Right"],
	["Normal / fast", "F"],
	["Stop spectating", "Esc"],
	["THE RACE", ""],
	["Laps", "Count only when every checkpoint is passed in order"],
	["Grid", "Next race starts from the reversed result: the winner starts last"],
	["Garage race", "Results: Enter = garage, Tab = skip shopping; top five win prize money"],
]

var _back: Button


func setup() -> void:
	custom_minimum_size = Vector2(760, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := HyperTheme.label("CONTROLS & HELP", 34, HyperTheme.GOLD, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 0)
	box.add_child(grid)
	for row in ROWS:
		var heading: bool = String(row[1]).is_empty()
		var a := HyperTheme.label(row[0], 17, HyperTheme.GOLD if heading else HyperTheme.CREAM, 700 if heading else 600)
		grid.add_child(a)
		grid.add_child(HyperTheme.label(row[1], 17, HyperTheme.CREAM, 500))
	_back = Button.new()
	_back.text = "BACK"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: closed.emit())
	box.add_child(_back)


func focus_first() -> void:
	_back.grab_focus()
