class_name AchievementToast
extends CanvasLayer
## Small "Achievement unlocked" notification that slides in at the top right,
## one at a time (queued), with a jingle. Presentation only.

const SHOW_TIME := 3.2

var _resolver: AssetResolver
var _panel: PanelContainer
var _name: Label
var _queue: Array[String] = []
var _busy := false
var _sfx: AudioStreamPlayer


func setup(resolver: AssetResolver) -> void:
	_resolver = resolver
	layer = 45
	var root := Control.new()
	root.theme = HyperTheme.build(resolver)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = resolver.get_texture(AssetCatalog.ACHIEVEMENT_BADGE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = AssetCatalog.SPECS[AssetCatalog.ACHIEVEMENT_BADGE].display_size
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -4)
	row.add_child(text)
	text.add_child(HyperTheme.label("ACHIEVEMENT UNLOCKED", 15, HyperTheme.GOLD, 700))
	_name = HyperTheme.label("", 23, HyperTheme.CREAM, 700)
	text.add_child(_name)
	_panel.visible = false
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Effects"
	add_child(_sfx)


func show_unlock(id: String) -> void:
	_queue.append(id)
	if not _busy:
		_next()


## Below the kill feed's tallest stack (top right), clear of the standings (left).
const TOP := 172.0


func pending() -> int:
	return _queue.size() + (1 if _busy else 0)


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		_panel.visible = false
		return
	_busy = true
	var e := AchievementCatalog.entry(_queue.pop_front())
	_name.text = e.get("name", "?")
	_panel.visible = true
	_panel.reset_size()
	var w := _panel.get_combined_minimum_size().x
	_panel.position = Vector2(1280 + 10, TOP)
	_sfx.stream = _resolver.get_audio("ui/achievement")
	_sfx.play()
	var tw := create_tween()
	tw.tween_property(_panel, "position:x", 1280 - w - 18, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(_panel, "position:x", 1280 + 10, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(_next)
