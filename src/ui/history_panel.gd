class_name HistoryPanel
extends NinePatchRect
## Spectator race history for the current session: fixed driver rows, one
## column per completed race (stars for 1st-3rd, numbers for 4th-9th), or the
## Position Counts view (finishes in each position). Race columns scroll
## horizontally as races accumulate.

enum View { HISTORY, COUNTS }

const CELL := Vector2(36, 26)
const NAME_WIDTH := 150.0
const TEXT_COLOR := Color("ead9b8")
const DIM_COLOR := Color("ead9b8", 0.55)
const OUTLINE_COLOR := Color("2a2220")

var view: View = View.HISTORY
var _history: RaceHistory
var _stars: Array[Texture2D] = []
var _title: Label
var _hint: Label
var _scroll: ScrollContainer
var _grid: GridContainer


## driver_ids in row order; car_textures/names keyed by driver id.
func setup(resolver: AssetResolver, history: RaceHistory, car_textures: Dictionary, names: Dictionary) -> void:
	_history = history
	texture = resolver.get_texture(AssetCatalog.HUD_PANEL)
	var margin := int(AssetCatalog.SPECS[AssetCatalog.HUD_PANEL].patch_margin * texture.get_width() / 96.0)
	patch_margin_left = margin
	patch_margin_right = margin
	patch_margin_top = margin
	patch_margin_bottom = margin
	_stars = [resolver.get_texture(AssetCatalog.STAR_GOLD), resolver.get_texture(AssetCatalog.STAR_SILVER),
		resolver.get_texture(AssetCatalog.STAR_BRONZE)]

	var box := VBoxContainer.new()
	box.position = Vector2(18, 12)
	box.size = size - Vector2(36, 24)
	add_child(box)
	_title = _label(18, TEXT_COLOR)
	box.add_child(_title)
	_hint = _label(13, DIM_COLOR)
	_hint.text = "Tab: switch view   Left/Right: scroll   F: speed   Esc: menu"
	box.add_child(_hint)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)

	var names_col := VBoxContainer.new()
	names_col.custom_minimum_size.x = NAME_WIDTH
	names_col.add_theme_constant_override("separation", 0)
	row.add_child(names_col)
	names_col.add_child(_cell_spacer())
	for id in history.driver_ids:
		var r := HBoxContainer.new()
		r.custom_minimum_size.y = CELL.y
		var icon := TextureRect.new()
		icon.texture = car_textures[id]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(34, CELL.y)
		r.add_child(icon)
		var n := _label(16, TEXT_COLOR)
		n.text = names[id]
		r.add_child(n)
		names_col.add_child(r)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	_scroll.add_child(_grid)
	refresh()


func toggle_view() -> void:
	view = View.COUNTS if view == View.HISTORY else View.HISTORY
	refresh()


## Scrolls the race columns by a number of columns (negative = left).
func scroll_columns(columns: int) -> void:
	_scroll.scroll_horizontal += int(columns * CELL.x)


func refresh() -> void:
	for child in _grid.get_children():
		child.free()
	if view == View.HISTORY:
		_title.text = "RACE HISTORY  (%d races)" % _history.race_count()
		_grid.columns = maxi(1, _history.race_count())
		if _history.race_count() == 0:
			_grid.add_child(_text_cell("-", DIM_COLOR))
			return
		for r in _history.race_count():
			_grid.add_child(_text_cell("R%d" % (r + 1), DIM_COLOR))
		for id in _history.driver_ids:
			for r in _history.race_count():
				_grid.add_child(_position_cell(_history.position_in(r, id)))
		_scroll_to_end.call_deferred()
	else:
		_title.text = "POSITION COUNTS  (%d races)" % _history.race_count()
		var positions := _history.driver_ids.size()
		_grid.columns = positions
		for p in positions:
			_grid.add_child(_text_cell(_ordinal(p + 1), DIM_COLOR))
		for id in _history.driver_ids:
			var counts := _history.position_counts(id)
			for p in positions:
				_grid.add_child(_text_cell(str(counts[p]) if counts[p] > 0 else "-", TEXT_COLOR if counts[p] > 0 else DIM_COLOR))


func _scroll_to_end() -> void:
	_scroll.scroll_horizontal = int(_grid.size.x)


func _position_cell(position: int) -> Control:
	if position >= 1 and position <= 3:
		var star := TextureRect.new()
		star.texture = _stars[position - 1]
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = CELL
		star.tooltip_text = _ordinal(position)
		return star
	return _text_cell(str(position) if position > 0 else "-", TEXT_COLOR)


func _text_cell(text: String, color: Color) -> Label:
	var l := _label(15, color)
	l.text = text
	l.custom_minimum_size = CELL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _cell_spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(NAME_WIDTH, CELL.y)
	return c


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	l.add_theme_constant_override("outline_size", 5)
	return l


static func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n
