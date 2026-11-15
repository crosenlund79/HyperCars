class_name GarageScreen
extends CanvasLayer
## The garage between garage races (M3.5): buy and sell rounds of the five
## weapons, mount one weapon type in each slot, then race (or go back to the
## grid panel). Shows money, prices, owned rounds and the last race's prize.
## All rules live in PlayerGarage; this screen only calls it and redraws.

signal race_requested
signal closed

const W := WeaponRules.Weapon
## Disabled buttons (cannot buy / sell): a dimmed plate and faint text.
const DISABLED_PLATE := Color(0.55, 0.5, 0.47, 0.5)
const DISABLED_TEXT := Color(0.95, 0.91, 0.81, 0.32)

var garage: PlayerGarage
var _resolver: AssetResolver
var _icons: Dictionary = {}
var _root: Control
var _money: Label
var _last: Label
var _summary: Label
var _race_button: Button
var _cards: Dictionary = {}
var _sfx: AudioStreamPlayer


func setup(p_garage: PlayerGarage, resolver: AssetResolver) -> void:
	garage = p_garage
	_resolver = resolver
	layer = 20
	_icons = Hud.weapon_icons(resolver)
	_root = Control.new()
	_root.theme = HyperTheme.build(resolver)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := TextureRect.new()
	bg.texture = resolver.get_texture(AssetCatalog.GARAGE_BACKDROP)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = AssetCatalog.SPECS[AssetCatalog.GARAGE_BACKDROP].display_size
	_root.add_child(bg)

	var title := HyperTheme.label("GARAGE", 60, HyperTheme.GOLD, 700)
	title.position = Vector2(40, 90)
	_root.add_child(title)
	_money = HyperTheme.label("", 44, HyperTheme.CREAM, 700)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money.size = Vector2(500, 60)
	_money.position = Vector2(740, 92)
	_root.add_child(_money)
	_last = HyperTheme.label("", 20, HyperTheme.CREAM, 500)
	_last.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_last.size = Vector2(700, 30)
	_last.position = Vector2(540, 150)
	_root.add_child(_last)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.position = Vector2(26, 196)
	_root.add_child(row)
	for w in WeaponRules.ALL_WEAPONS:
		row.add_child(_card(w))

	var footer := PanelContainer.new()
	footer.position = Vector2(26, 560)
	footer.custom_minimum_size = Vector2(1228, 0)
	_root.add_child(footer)
	var fbox := HBoxContainer.new()
	fbox.add_theme_constant_override("separation", 24)
	footer.add_child(fbox)
	_summary = HyperTheme.label("", 21, HyperTheme.CREAM, 600)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fbox.add_child(_summary)
	_race_button = Button.new()
	_race_button.text = "RACE!"
	_race_button.custom_minimum_size = Vector2(220, 56)
	_race_button.pressed.connect(func() -> void:
		_play("ui/ui_select")
		race_requested.emit())
	fbox.add_child(_race_button)
	# Controls hint on a soft dark strip so it reads over the workshop floor.
	var strip := ColorRect.new()
	strip.color = Color(0.1, 0.07, 0.06, 0.55)
	strip.size = Vector2(1280, 34)
	strip.position = Vector2(0, 680)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(strip)
	var hint := HyperTheme.label("Arrows: move    Enter / Space: choose    Esc: grid panel    Prices are per round; selling pays half",
		17, Color(HyperTheme.CREAM, 0.88), 600)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.size = Vector2(1280, 34)
	hint.position = Vector2(0, 680)
	_root.add_child(hint)
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Effects"
	add_child(_sfx)
	visible = false


## Opens the screen (refreshes every number) with RACE! focused, so one press skips shopping.
func open() -> void:
	visible = true
	refresh()
	_race_button.grab_focus()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_play("ui/ui_back")
		closed.emit()


func refresh() -> void:
	_money.text = "$ %d" % garage.money
	if garage.races_settled == 0:
		_last.text = "Starting money. Top five finishers win prize money."
	else:
		_last.text = "Last race: %s   prize $%d" % [_ordinal(garage.last_position), garage.last_prize]
	var front := garage.equipped[PlayerGarage.FRONT]
	var rear := garage.equipped[PlayerGarage.REAR]
	_summary.text = "FRONT: %s x%d      REAR: %s x%d" % [WeaponRules.weapon_name(front), garage.count(front) if front != W.NONE else 0,
		WeaponRules.weapon_name(rear), garage.count(rear) if rear != W.NONE else 0]
	for w in _cards:
		var c: Dictionary = _cards[w]
		c.owned.text = "Owned: %d" % garage.count(w)
		c.buy.disabled = not garage.can_buy(w)
		c.sell.disabled = not garage.can_sell(w)
		var slot := WeaponRules.slot_of(w)
		var mounted: bool = garage.equipped[slot] == w
		c.equip.text = "EQUIPPED" if mounted else "EQUIP"
		c.equip.disabled = mounted
		# equipped is a state, not an unavailable action: gold, not greyed out
		c.equip.add_theme_color_override("font_disabled_color", HyperTheme.GOLD if mounted else DISABLED_TEXT)
		c.panel.self_modulate = Color(1.15, 1.05, 0.8) if mounted else Color.WHITE


func _card(w: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(232, 340)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var icon := TextureRect.new()
	icon.texture = _icons.get(w)
	icon.flip_h = w == W.REAR_MISSILE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(180, 64)
	box.add_child(icon)
	var name := HyperTheme.label(WeaponRules.weapon_name(w).to_upper(), 21, HyperTheme.GOLD, 700)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)
	var slot := HyperTheme.label("%s SLOT" % ("FRONT" if WeaponRules.slot_of(w) == 0 else "REAR"), 15, HyperTheme.CREAM_DIM, 600)
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(slot)
	var price := HyperTheme.label("Buy $%d    Sell $%d" % [garage.rules.price(w), garage.rules.sell_price(w)], 18, HyperTheme.CREAM, 600)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price)
	var owned := HyperTheme.label("", 20, HyperTheme.CREAM, 600)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(owned)
	var trade := HBoxContainer.new()
	trade.alignment = BoxContainer.ALIGNMENT_CENTER
	trade.add_theme_constant_override("separation", 6)
	box.add_child(trade)
	var buy := _small_button("BUY")
	buy.pressed.connect(func() -> void: _trade(w, true))
	var sell := _small_button("SELL")
	sell.pressed.connect(func() -> void: _trade(w, false))
	trade.add_child(buy)
	trade.add_child(sell)
	var equip := _small_button("EQUIP")
	equip.custom_minimum_size = Vector2(180, 44)
	equip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	equip.pressed.connect(func() -> void:
		if garage.equip(WeaponRules.slot_of(w), w):
			_play("ui/ui_select")
		refresh())
	box.add_child(equip)
	_cards[w] = {"panel": panel, "owned": owned, "buy": buy, "sell": sell, "equip": equip}
	return panel


func _trade(w: int, buying: bool) -> void:
	var ok := garage.buy(w) if buying else garage.sell(w)
	_play(("ui/shop_buy" if buying else "ui/shop_sell") if ok else "ui/ui_back")
	refresh()


func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 19)
	for side in ["left", "right"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box: StyleBox = _root.theme.get_stylebox(state, "Button").duplicate()
			box.set("content_margin_" + side, 12)
			b.add_theme_stylebox_override(state, box)
	# unavailable actions read clearly as inactive: darker, more transparent plate, faint text
	var off: StyleBox = b.get_theme_stylebox("disabled")
	if off is StyleBoxTexture:
		off.modulate_color = DISABLED_PLATE
	b.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	b.custom_minimum_size = Vector2(87, 44)
	return b


func _play(logical: String) -> void:
	_sfx.stream = _resolver.get_audio(logical)
	_sfx.play()


static func _ordinal(n: int) -> String:
	if n <= 0:
		return "-"
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]
