class_name SettingsPanel
extends PanelContainer
## Audio settings: Master, Music, Engine, Effects and Voice volume with mute toggles.
## Changes apply immediately and are saved.

signal closed

var settings: AudioSettings
var _sliders: Dictionary = {}
var _mutes: Dictionary = {}
var _back: Button


func setup(p_settings: AudioSettings) -> void:
	settings = p_settings
	custom_minimum_size = Vector2(720, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := HyperTheme.label("AUDIO SETTINGS", 34, HyperTheme.GOLD, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for bus in AudioSettings.BUSES:
		var name := HyperTheme.label(bus.to_upper(), 22, HyperTheme.CREAM, 600)
		name.custom_minimum_size = Vector2(120, 0)
		grid.add_child(name)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.custom_minimum_size = Vector2(260, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value = settings.volume[bus] * 100.0
		grid.add_child(slider)
		var value := HyperTheme.label("%d%%" % int(slider.value), 20, HyperTheme.CREAM_DIM, 500)
		value.custom_minimum_size = Vector2(60, 0)
		grid.add_child(value)
		var mute := CheckButton.new()
		mute.text = "Mute"
		mute.custom_minimum_size = Vector2(110, 0)
		mute.button_pressed = settings.muted[bus]
		grid.add_child(mute)
		slider.value_changed.connect(func(v: float) -> void:
			value.text = "%d%%" % int(v)
			settings.set_volume(bus, v / 100.0)
			settings.save_settings())
		mute.toggled.connect(func(on: bool) -> void:
			settings.set_muted(bus, on)
			settings.save_settings())
		_sliders[bus] = slider
		_mutes[bus] = mute
	var hint := HyperTheme.label("Left / Right adjust the focused slider. Settings are saved automatically.", 16, HyperTheme.CREAM_DIM, 500)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_back = Button.new()
	_back.text = "BACK"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: closed.emit())
	box.add_child(_back)


func focus_first() -> void:
	_sliders["Master"].grab_focus()


func slider(bus: String) -> HSlider:
	return _sliders[bus]


func mute_toggle(bus: String) -> CheckButton:
	return _mutes[bus]
