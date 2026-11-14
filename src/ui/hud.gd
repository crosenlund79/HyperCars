class_name Hud
extends CanvasLayer
## Minimal race HUD: lap counter, race time, control mode, and the centre
## message used for mode selection and the finish. Built in code from the
## painted panel texture so the panel can be overridden like any other asset.

const TEXT_COLOR := Color("ead9b8")
const OUTLINE_COLOR := Color("2a2220")

var _lap_label: Label
var _time_label: Label
var _mode_label: Label
var _message_panel: NinePatchRect
var _message_label: Label


func setup(resolver: AssetResolver) -> void:
	var texture := resolver.get_texture(AssetCatalog.HUD_PANEL)
	var info := _panel(texture, Vector2(24, 20), Vector2(300, 132))
	var box := VBoxContainer.new()
	box.position = Vector2(26, 18)
	box.add_theme_constant_override("separation", 2)
	info.add_child(box)
	_lap_label = _label(30)
	_time_label = _label(24)
	_mode_label = _label(18)
	for l in [_lap_label, _time_label, _mode_label]:
		box.add_child(l)

	_message_panel = _panel(texture, Vector2(340, 250), Vector2(600, 220))
	_message_label = _label(28)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message_panel.add_child(_message_label)


func show_mode_select(mode: CarModel.ControlMode) -> void:
	_show_message("CONTROL MODE\n<  %s  >\n\nLeft / Right to change - Fire to start" % mode_name(mode))
	_mode_label.text = mode_name(mode)


func show_racing(mode: CarModel.ControlMode) -> void:
	_message_panel.visible = false
	_mode_label.text = mode_name(mode)


func show_finished(lap_times: Array[float], total: float) -> void:
	var lines := PackedStringArray(["FINISHED", "Total  %s" % format_time(total)])
	for i in lap_times.size():
		lines.append("Lap %d  %s" % [i + 1, format_time(lap_times[i])])
	lines.append("Fire to race again")
	_show_message("\n".join(lines))


func update_race(lap: int, lap_count: int, elapsed: float) -> void:
	_lap_label.text = "LAP %d / %d" % [lap, lap_count]
	_time_label.text = format_time(elapsed)


## Centre panel sized to its text (about 42 px per line at font size 28).
func _show_message(text: String) -> void:
	_message_label.text = text
	_message_panel.size.y = 56.0 + 42.0 * text.count("\n") + 42.0
	_message_panel.position.y = 360.0 - _message_panel.size.y * 0.5
	_message_panel.visible = true


static func mode_name(mode: CarModel.ControlMode) -> String:
	return "FIRE TO ACCELERATE" if mode == CarModel.ControlMode.FIRE_TO_ACCELERATE else "FIRE TO BRAKE"


static func format_time(seconds: float) -> String:
	var total_ms := int(round(seconds * 1000.0))
	return "%02d:%02d.%02d" % [total_ms / 60000, (total_ms / 1000) % 60, (total_ms % 1000) / 10]


func _panel(texture: Texture2D, pos: Vector2, size: Vector2) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = texture
	var margin: int = int(AssetCatalog.SPECS[AssetCatalog.HUD_PANEL].patch_margin * texture.get_width() / 96.0)
	panel.patch_margin_left = margin
	panel.patch_margin_right = margin
	panel.patch_margin_top = margin
	panel.patch_margin_bottom = margin
	panel.position = pos
	panel.size = size
	add_child(panel)
	return panel


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TEXT_COLOR)
	l.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	l.add_theme_constant_override("outline_size", 6)
	return l
