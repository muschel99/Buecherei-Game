extends ShopApp
## App "Einrichtung" auf dem Theken-Tablet: Möbel, Deko, Wandfarben, Böden und Decken kaufen
## (nach Kategorien, mit Filtern und Warenkorb) und Dinge aus dem Inventar verkaufen.
## Oben links zwei Symbol-Knöpfe: Kaufen (Tasche) und Verkaufen (Münze).

## Kategorien links: [Anzeigename, "furniture" oder "surface", Kategorie bzw. Art]
var _categories: Array = []
var _category_buttons: Array[Button] = []
var _current_category: int = 0
var _selling := false

var _buy_button: TabletIconButton
var _sell_button: TabletIconButton
var _category_column: Control
var _filter_bar: FilterBar
var _item_scroll: ScrollContainer
var _item_flow: HFlowContainer
var _buy_column: Control
var _sell_column: Control
var _sell_list: VBoxContainer
var _cart_panel: Control
var _sell_panel: Control
var _sell_message: Label


func _ready() -> void:
	for category in FurnitureData.Category.values():
		_categories.append([FurnitureData.get_category_display_name(category), "furniture", category])
	_categories.append(["Wandfarben", "surface", SurfaceData.Kind.WALL])
	_categories.append(["Böden", "surface", SurfaceData.Kind.FLOOR])
	_categories.append(["Decken", "surface", SurfaceData.Kind.CEILING])
	_build()


func app_opened() -> void:
	super.app_opened()
	_sell_message.text = ""
	show_selling(false)


## Kaufen (false) oder Verkaufen (true) zeigen.
func show_selling(selling: bool) -> void:
	_selling = selling
	_buy_button.set_pressed_no_signal(not selling)
	_sell_button.set_pressed_no_signal(selling)
	_category_column.visible = not selling
	_buy_column.visible = not selling
	_cart_panel.visible = not selling
	_sell_column.visible = selling
	_sell_panel.visible = selling
	refresh()


func refresh() -> void:
	if _selling:
		_refresh_sell_list()
	else:
		show_category(_current_category)
		refresh_cart()


# --- Kaufen ---

## Alles, was es in dieser Kategorie zu kaufen gibt.
func get_offers(index: int) -> Array[Resource]:
	var category: Array = _categories[index]
	var result: Array[Resource] = []
	if category[1] == "furniture":
		for data in Catalog.get_furniture_in_category(category[2]):
			if not data.is_essential:
				result.append(data)
	else:
		result.append_array(Catalog.get_surfaces_of_kind(category[2]))
	return result


## Was in dieser Kategorie zu den gewählten Filtern passt.
func get_visible_offers(index: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for item in get_offers(index):
		if _filter_bar.matches(item):
			result.append(item)
	return result


func get_category_count() -> int:
	return _categories.size()


func show_category(index: int) -> void:
	var scroll := _item_scroll.scroll_vertical
	_current_category = index
	for i in _category_buttons.size():
		_category_buttons[i].set_pressed_no_signal(i == index)
	clear(_item_flow)
	# Filter: nur die Unterkategorien anbieten, die es hier wirklich gibt
	var all_offers := get_offers(index)
	var category: Array = _categories[index]
	var subcategories := FilterBar.present_subcategories(category[2], all_offers) if category[1] == "furniture" else []
	_filter_bar.setup(subcategories)
	var offers := get_visible_offers(index)
	for item in offers:
		_item_flow.add_child(create_offer_card(item))
	if all_offers.is_empty():
		_item_flow.add_child(make_label("Hier gibt es gerade nichts.", 16, TabletFrame.MUTED_COLOR))
	elif offers.is_empty():
		_item_flow.add_child(make_label("Dazu passt gerade nichts.", 16, TabletFrame.MUTED_COLOR))
	_item_scroll.set_deferred("scroll_vertical", scroll)


func _on_category_pressed(index: int) -> void:
	_item_scroll.scroll_vertical = 0
	_current_category = index
	for i in _category_buttons.size():
		_category_buttons[i].set_pressed_no_signal(i == index)
	request_refresh()


## Der Filter-Knopf wird beim Neuaufbau ersetzt – darum erst am Ende des Bilds.
func _on_filter_changed() -> void:
	_item_scroll.scroll_vertical = 0
	request_refresh()


# --- Verkaufen ---

func _refresh_sell_list() -> void:
	clear(_sell_list)
	var count := 0
	for data in Inventory.get_stored_furniture():
		if data.is_essential:
			continue
		_sell_list.add_child(_create_sell_row(data))
		count += 1
	if count == 0:
		_sell_list.add_child(make_label("Im Inventar liegt gerade nichts zum Verkaufen.", 17, TabletFrame.MUTED_COLOR))


func _create_sell_row(data: FurnitureData) -> Control:
	var panel := make_panel(10.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var picture := create_preview(data)
	picture.custom_minimum_size = Vector2(110, 70)
	row.add_child(picture)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(make_label("%s  ×%d" % [data.display_name, Inventory.get_count(data.get_id())], 17))
	info.add_child(create_style_row(data.styles))
	row.add_child(info)
	var price := make_label("+" + Wallet.format(data.get_sell_price()), 17, TabletFrame.KEY_COLOR)
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.custom_minimum_size.x = 0
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	var button := make_icon_button(TabletIconButton.Icon.SELL, sell.bind(data), "Verkaufen")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return panel


## Verkauft ein Exemplar aus dem Inventar.
func sell(data: FurnitureData) -> void:
	if data.is_essential or not Inventory.take_furniture(data.get_id()):
		return
	var price := data.get_sell_price()
	Wallet.earn(price, "Verkauf am Tablet")
	_sell_message.text = "%s verkauft: +%s" % [data.display_name, Wallet.format(price)]


# --- Aufbau ---

func _build() -> void:
	var columns := HBoxContainer.new()
	columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 16)
	add_child(columns)

	# Links: Kaufen/Verkaufen und die Kategorien
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 190
	left.add_theme_constant_override("separation", 12)
	columns.add_child(left)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	left.add_child(modes)
	_buy_button = make_icon_button(TabletIconButton.Icon.BUY, show_selling.bind(false))
	_buy_button.toggle_mode = true
	modes.add_child(_buy_button)
	_sell_button = make_icon_button(TabletIconButton.Icon.SELL, show_selling.bind(true))
	_sell_button.toggle_mode = true
	modes.add_child(_sell_button)
	var category_scroll := ScrollContainer.new()
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(category_scroll)
	_category_column = category_scroll
	var category_list := VBoxContainer.new()
	category_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_list.add_theme_constant_override("separation", 6)
	category_scroll.add_child(category_list)
	for i in _categories.size():
		var button := make_choice_button(_categories[i][0], _on_category_pressed.bind(i))
		category_list.add_child(button)
		_category_buttons.append(button)

	# Mitte: Filter und Angebote (Kaufen) bzw. Inventar (Verkaufen)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	columns.add_child(middle)
	_buy_column = VBoxContainer.new()
	_buy_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_buy_column.add_theme_constant_override("separation", 10)
	middle.add_child(_buy_column)
	_filter_bar = FilterBar.new()
	_filter_bar.changed.connect(_on_filter_changed)
	_buy_column.add_child(_filter_bar)
	_item_scroll = ScrollContainer.new()
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_buy_column.add_child(_item_scroll)
	_item_flow = HFlowContainer.new()
	_item_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_flow.add_theme_constant_override("h_separation", 10)
	_item_flow.add_theme_constant_override("v_separation", 10)
	_item_scroll.add_child(_item_flow)
	var sell_scroll := ScrollContainer.new()
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(sell_scroll)
	_sell_column = sell_scroll
	_sell_list = VBoxContainer.new()
	_sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_list.add_theme_constant_override("separation", 8)
	sell_scroll.add_child(_sell_list)

	# Rechts: Warenkorb (Kaufen) bzw. kurze Info (Verkaufen)
	_cart_panel = build_cart(columns)
	var sell_panel := make_panel(14.0)
	sell_panel.custom_minimum_size.x = CART_WIDTH
	columns.add_child(sell_panel)
	_sell_panel = sell_panel
	var sell_box := VBoxContainer.new()
	sell_box.add_theme_constant_override("separation", 10)
	sell_panel.add_child(sell_box)
	sell_box.add_child(make_label("Verkaufen", 19))
	sell_box.add_child(make_label("Du bekommst %d %% des Preises zurück. Was im Raum steht, räumst du vorher im Gestaltungsmodus (Tab) mit X ins Inventar." \
		% roundi(GameConfig.sell_price_share * 100.0), 15, TabletFrame.MUTED_COLOR))
	_sell_message = make_label("", 16, TabletFrame.KEY_COLOR)
	sell_box.add_child(_sell_message)
