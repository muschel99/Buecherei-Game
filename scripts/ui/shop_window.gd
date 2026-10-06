class_name ShopWindow
extends CanvasLayer
## Der Shop am Tablet auf der Theke: Bücher, Möbel, Deko, Wandfarben, Böden und Decken
## kaufen, Dinge aus dem Inventar verkaufen und den Bücherbestand ansehen.
##
## - Reiter "Kaufen": alles Freigeschaltete nach Kategorien, mit Vorschau, Preis und Stil.
##   Ein Klick legt es in den Warenkorb (Möbel und Bücherpakete auch mehrfach). "Bestellen"
##   bezahlt (Wallet) und gibt die Bestellung an den Lieferdienst (DeliveryManager) – kurz
##   darauf stehen die Kartons vor der Tür. Bücherpakete gibt es je freigeschaltetem Genre.
## - Reiter "Verkaufen": Möbel aus dem Inventar (nicht die im Raum) gegen einen Teil des
##   Preises (GameConfig.sell_price_share).
## - Reiter "Bestand": wie viele Bücher je Genre ich habe – im Regal, im Lager, unterwegs.
## - Reiter "Sammlung": alle Titel eines Genres mit Cover; unentdeckte als "?". Ein Klick auf
##   ein Buch im Lager legt es obenauf in die Hand.
## Öffnen: E am Tablet. Schließen: Esc oder "Schließen" (Esc-Regel über MenuStack).
## Solange der Shop offen ist, ist der Mauszeiger sichtbar und die Spielfigur steht still.

const GROUP := "shop_window"
const KEY_COLOR := Color(0.96, 0.78, 0.48)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.8)
const TEXT_COLOR := Color(1.0, 0.96, 0.88)
const SOFT_WARNING_COLOR := Color(1.0, 0.8, 0.62)
const CARD_SIZE := Vector2(196, 262)
const PREVIEW_SIZE := Vector2(176, 118)
## Die drei Reiter oben
const VIEW_BUY := "buy"
const VIEW_SELL := "sell"
const VIEW_STOCK := "stock"
const VIEW_COLLECTION := "collection"

## Pfad zur Spielfigur (im Inspektor der Hauptszene eingetragen).
@export var player_path: NodePath

@onready var _player: Player = get_node(player_path)
@onready var _buy_tab_button: Button = %BuyTabButton
@onready var _sell_tab_button: Button = %SellTabButton
@onready var _stock_tab_button: Button = %StockTabButton
@onready var _collection_tab_button: Button = %CollectionTabButton
@onready var _close_button: Button = %CloseButton
@onready var _money_label: Label = %MoneyLabel
@onready var _buy_view: Control = %BuyView
@onready var _sell_view: Control = %SellView
@onready var _category_list: VBoxContainer = %CategoryList
@onready var _filter_bar: FilterBar = %FilterBar
@onready var _item_scroll: ScrollContainer = %ItemScroll
@onready var _item_flow: HFlowContainer = %ItemFlow
@onready var _cart_list: VBoxContainer = %CartList
@onready var _total_label: Label = %TotalLabel
@onready var _cart_message: Label = %CartMessage
@onready var _order_button: Button = %OrderButton
@onready var _sell_list: VBoxContainer = %SellList
@onready var _sell_info: Label = %SellInfo
@onready var _sell_message: Label = %SellMessage
@onready var _stock_view: Control = %StockView
@onready var _stock_grid: GridContainer = %StockGrid
@onready var _stock_message: Label = %StockMessage
@onready var _store_carried_button: Button = %StoreCarriedButton
@onready var _collection_view: Control = %CollectionView
@onready var _collection_genre_list: VBoxContainer = %CollectionGenreList
@onready var _collection_column: VBoxContainer = %CollectionColumn
@onready var _collection_header: Label = %CollectionHeader

var is_open: bool = false

## Kategorien links: [Anzeigename, "books", "furniture" oder "surface", Kategorie bzw. Art]
var _categories: Array = []
var _category_buttons: Array[Button] = []
var _current_category: int = 0
## Warenkorb: Einträge { "kind": "furniture"/"surface"/"books", "id": "...", "count": Anzahl }
## (bei "books": id = Genre, count = Zahl der Bücherpakete)
var _cart: Array[Dictionary] = []
var _order_text := ""
var _thumbnails: ThumbnailRenderer
var _selected_style: StyleBoxFlat
var _refresh_queued := false
var _collection_picker: BookPicker
var _collection_genre := ""


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_thumbnails = ThumbnailRenderer.new()
	_thumbnails.name = "Thumbnails"
	add_child(_thumbnails)
	_selected_style = _make_selected_style()
	for button: Button in [_buy_tab_button, _sell_tab_button, _stock_tab_button, _collection_tab_button]:
		button.add_theme_stylebox_override("pressed", _selected_style)
		button.add_theme_stylebox_override("hover_pressed", _selected_style)
	_categories.append(["Bücher", "books", null])
	for category in FurnitureData.Category.values():
		_categories.append([FurnitureData.get_category_display_name(category), "furniture", category])
	_categories.append(["Wandfarben", "surface", SurfaceData.Kind.WALL])
	_categories.append(["Böden", "surface", SurfaceData.Kind.FLOOR])
	_categories.append(["Decken", "surface", SurfaceData.Kind.CEILING])
	_build_category_buttons()

	_buy_tab_button.pressed.connect(_show_view.bind(VIEW_BUY))
	_sell_tab_button.pressed.connect(_show_view.bind(VIEW_SELL))
	_stock_tab_button.pressed.connect(_show_view.bind(VIEW_STOCK))
	_collection_tab_button.pressed.connect(_show_view.bind(VIEW_COLLECTION))
	_collection_picker = BookPicker.new()
	_collection_picker.book_chosen.connect(_on_collection_book_chosen)
	_collection_column.add_child(_collection_picker)
	_store_carried_button.pressed.connect(_on_store_carried_pressed)
	_close_button.pressed.connect(close)
	_order_button.pressed.connect(_on_order_pressed)
	_filter_bar.changed.connect(_on_filter_changed)
	Wallet.money_changed.connect(func(_money: int, _change: int) -> void: _queue_refresh())
	Inventory.changed.connect(_queue_refresh)
	BookStock.changed.connect(_queue_refresh)
	BookStock.carried_changed.connect(_queue_refresh)
	_sell_info.text = ("Du bekommst %d %% des Preises zurück.\n\nVerkaufen kannst du alles, was im " \
		+ "Inventar liegt. Was im Raum steht, räumst du vorher im Gestaltungsmodus (Tab) mit X " \
		+ "ins Inventar. Wandfarben, Böden und Decken behältst du für immer.") \
		% roundi(GameConfig.sell_price_share * 100.0)


func _process(_delta: float) -> void:
	# Im Pausenmenü ausblenden (dieser Knoten läuft auch bei Pause weiter)
	visible = is_open and not get_tree().paused


# --- Öffnen und Schließen ---

## Wird vom Tablet aufgerufen (E).
func open_shop() -> void:
	if is_open:
		return
	is_open = true
	MenuStack.open(self)
	_player.movement_enabled = false
	_player.interaction_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_order_text = ""
	_sell_message.text = ""
	_stock_message.text = ""
	_show_view(VIEW_BUY)


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	MenuStack.close(self)
	_player.movement_enabled = true
	_player.interaction_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Esc (über den MenuStack): Shop schließen.
func close_from_escape() -> void:
	close()


## Nach dem Pausenmenü: Mauszeiger wieder sichtbar.
func restore_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Zeigt einen Reiter: VIEW_BUY ("Kaufen"), VIEW_SELL ("Verkaufen") oder VIEW_STOCK ("Bestand").
func _show_view(view: String) -> void:
	_buy_tab_button.set_pressed_no_signal(view == VIEW_BUY)
	_sell_tab_button.set_pressed_no_signal(view == VIEW_SELL)
	_stock_tab_button.set_pressed_no_signal(view == VIEW_STOCK)
	_collection_tab_button.set_pressed_no_signal(view == VIEW_COLLECTION)
	_collection_view.visible = view == VIEW_COLLECTION
	_buy_view.visible = view == VIEW_BUY
	_sell_view.visible = view == VIEW_SELL
	_stock_view.visible = view == VIEW_STOCK
	_refresh()


## Geld oder Inventar haben sich geändert: alles neu zeigen (einmal pro Bild).
func _queue_refresh() -> void:
	if _refresh_queued or not is_open:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	_money_label.text = "Kontostand: " + Wallet.format(Wallet.money)
	if _buy_view.visible:
		_show_category(_current_category)
		_refresh_cart()
	elif _sell_view.visible:
		_refresh_sell_list()
	elif _stock_view.visible:
		_refresh_stock()
	else:
		_refresh_collection()


# --- Kaufen: Kategorien und Angebote ---

func _build_category_buttons() -> void:
	for i in _categories.size():
		var button := Button.new()
		button.text = _categories[i][0]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_stylebox_override("pressed", _selected_style)
		button.add_theme_stylebox_override("hover_pressed", _selected_style)
		button.pressed.connect(_on_category_pressed.bind(i))
		_category_list.add_child(button)
		_category_buttons.append(button)


func _on_category_pressed(index: int) -> void:
	_item_scroll.scroll_vertical = 0
	_show_category(index)


func _on_filter_changed() -> void:
	_item_scroll.scroll_vertical = 0
	_show_category(_current_category)


## Was in dieser Kategorie zu den gewählten Filtern passt.
func get_visible_offers(index: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for item in get_offers(index):
		if _filter_bar.matches(item):
			result.append(item)
	return result


## Alles, was es in dieser Kategorie zu kaufen gibt.
func get_offers(index: int) -> Array[Resource]:
	var category: Array = _categories[index]
	var result: Array[Resource] = []
	if category[1] == "books":
		result.append_array(BookStock.get_unlocked_genres())
	elif category[1] == "furniture":
		for data in Catalog.get_furniture_in_category(category[2]):
			if not data.is_essential:
				result.append(data)
	else:
		result.append_array(Catalog.get_surfaces_of_kind(category[2]))
	return result


func _show_category(index: int) -> void:
	var scroll := _item_scroll.scroll_vertical
	_current_category = index
	for i in _category_buttons.size():
		_category_buttons[i].set_pressed_no_signal(i == index)
	for child in _item_flow.get_children():
		_item_flow.remove_child(child)
		child.queue_free()
	# Filter: nur die Unterkategorien anbieten, die es hier wirklich gibt
	var all_offers := get_offers(index)
	var category: Array = _categories[index]
	var subcategories := FilterBar.present_subcategories(category[2], all_offers) if category[1] == "furniture" else []
	_filter_bar.setup(subcategories)
	var offers := get_visible_offers(index)
	for item in offers:
		_item_flow.add_child(_create_offer_card(item))
	if all_offers.is_empty():
		_item_flow.add_child(_small_label("Hier gibt es gerade nichts zu kaufen.", 16, MUTED_COLOR))
	elif offers.is_empty():
		_item_flow.add_child(_small_label("Dazu passt hier gerade nichts – probier einen anderen Filter.", 16, MUTED_COLOR))
	_item_scroll.set_deferred("scroll_vertical", scroll)


## Eine Karte im Shop: Vorschau, Name, Stile, Preis und was man davon schon hat.
func _create_offer_card(item: Resource) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = item.description if item is FurnitureData or item is GenreData else ""
	card.pressed.connect(add_to_cart.bind(item))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	box.add_child(_create_preview(item))

	var title_text: String = item.display_name
	if item is GenreData:
		title_text = "%s – Paket mit %d Büchern" % [item.display_name, GameConfig.books_per_package]
	var title := _small_label(title_text, 16, TEXT_COLOR)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.custom_minimum_size.y = 42
	box.add_child(title)
	box.add_child(_create_style_row(item.styles))
	box.add_child(_small_label(Wallet.format(item.price), 17, KEY_COLOR))

	# Was habe ich schon? Oberflächen kauft man nur einmal.
	var status := ""
	if item is SurfaceData:
		var id: String = item.get_id()
		if Inventory.owns_surface(id):
			status = "✓ Gehört dir schon"
		elif _is_surface_on_the_way(id):
			status = "Schon bestellt – kommt bald"
		elif _find_cart_entry("surface", id):
			status = "Liegt im Warenkorb"
		card.disabled = not status.is_empty()
		card.modulate.a = 0.55 if card.disabled else 1.0
		if status.is_empty():
			status = "Einmal kaufen, immer nutzen"
	elif item is GenreData:
		# Sammlung: wie viele Titel des Genres kenne ich schon?
		var catalog := Catalog.get_books_of_genre(item.get_id()).size()
		status = "Sammlung: %d von %d Titeln" % [BookStock.get_discovered_count(item.get_id()), catalog]
	else:
		var owned := Inventory.get_count(item.get_id()) + _count_in_room(item.get_id())
		status = "Hast du schon: %d" % owned if owned > 0 else "Klicken: in den Warenkorb"
	box.add_child(_small_label(status, 13, MUTED_COLOR))
	# Lange Zeilen enden mit "…", statt über den Kartenrand zu ragen
	for label in box.get_children():
		if label is Label and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.clip_text = true
	return card


## Vorschau: ein Foto des Möbelstücks, ein Farbfeld der Oberfläche bzw. ein Bücherstapel.
func _create_preview(item: Resource) -> Control:
	if item is GenreData:
		var stack := TextureRect.new()
		stack.texture = BookIcons.get_stack_icon(item)
		stack.custom_minimum_size = PREVIEW_SIZE
		stack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stack.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stack.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return stack
	if item is SurfaceData:
		var swatch := ColorRect.new()
		swatch.color = item.preview_color
		swatch.custom_minimum_size = PREVIEW_SIZE
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return swatch
	var picture := TextureRect.new()
	picture.custom_minimum_size = PREVIEW_SIZE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Schwache Referenz: Ist die Karte schon wieder weg (z. B. Kategorie gewechselt), bevor
	# das Foto fertig ist, wird es einfach nicht mehr eingesetzt
	var picture_ref: WeakRef = weakref(picture)
	_thumbnails.request(item, func(texture: Texture2D) -> void:
		var target := picture_ref.get_ref() as TextureRect
		if target:
			target.texture = texture)
	return picture


# --- Warenkorb ---

## Legt etwas in den Warenkorb (Möbel und Bücherpakete auch mehrfach, Oberflächen einmal).
func add_to_cart(item: Resource) -> void:
	var kind := "furniture"
	if item is SurfaceData:
		kind = "surface"
	elif item is GenreData:
		kind = "books"
	var entry := _find_cart_entry(kind, item.get_id())
	if entry.is_empty():
		_cart.append({"kind": kind, "id": item.get_id(), "count": 1})
	elif kind != "surface":
		entry.count += 1
	_order_text = ""
	_refresh()


func _change_cart_count(entry: Dictionary, change: int) -> void:
	entry.count += change
	if entry.count <= 0:
		_cart.erase(entry)
	_order_text = ""
	_refresh()


func get_cart_total() -> int:
	var total := 0
	for entry in _cart:
		total += _price_of(entry) * int(entry.count)
	return total


func _refresh_cart() -> void:
	for child in _cart_list.get_children():
		_cart_list.remove_child(child)
		child.queue_free()
	for entry in _cart:
		_cart_list.add_child(_create_cart_row(entry))
	if _cart.is_empty():
		_cart_list.add_child(_small_label("Noch leer.", 15, MUTED_COLOR))

	var total := get_cart_total()
	_total_label.text = "Summe: " + Wallet.format(total)
	var affordable := Wallet.can_afford(total)
	_order_button.disabled = _cart.is_empty() or not affordable
	_cart_message.remove_theme_color_override("font_color")
	if not _order_text.is_empty():
		_cart_message.text = _order_text
	elif _cart.is_empty():
		_cart_message.text = "Klicke auf etwas, um es in den Warenkorb zu legen."
	elif not affordable:
		# Freundlich, ohne Strafe: einfach zeigen, wie viel fehlt
		_cart_message.text = ("Dafür reicht dein Geld gerade nicht ganz – es fehlen noch %s. " \
			+ "Nimm etwas aus dem Warenkorb oder verkaufe Dinge, die du nicht mehr brauchst.") \
			% Wallet.format(total - Wallet.money)
		_cart_message.add_theme_color_override("font_color", SOFT_WARNING_COLOR)
	else:
		_cart_message.text = "Nach dem Bestellen steht in etwa %d Sekunden ein Karton vor der Tür." \
			% roundi(GameConfig.delivery_time)


## Eine Zeile im Warenkorb: Name oben, darunter Anzahl (− 2 +) und Preis.
func _create_cart_row(entry: Dictionary) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var name_label := _small_label(_name_of(entry), 15, TEXT_COLOR)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(name_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	block.add_child(row)
	if entry.kind != "surface":
		row.add_child(_small_button("−", _change_cart_count.bind(entry, -1)))
		var count := _small_label(str(entry.count), 15, TEXT_COLOR)
		count.custom_minimum_size.x = 22
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count)
		row.add_child(_small_button("+", _change_cart_count.bind(entry, 1)))
	else:
		row.add_child(_small_button("✕", _change_cart_count.bind(entry, -1)))
	var price := _small_label(Wallet.format(_price_of(entry) * int(entry.count)), 15, KEY_COLOR)
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	return block


## Bestellen: bezahlen und an den Lieferdienst geben.
func _on_order_pressed() -> void:
	var total := get_cart_total()
	var deliveries := _get_deliveries()
	if _cart.is_empty() or deliveries == null or not Wallet.spend(total, "Einkauf im Shop"):
		_refresh()
		return
	deliveries.place_order(_cart)
	_cart.clear()
	_order_text = "Danke für deine Bestellung! In etwa %d Sekunden steht der Karton vor der Tür." \
		% roundi(GameConfig.delivery_time)
	_refresh()


# --- Verkaufen ---

func _refresh_sell_list() -> void:
	for child in _sell_list.get_children():
		_sell_list.remove_child(child)
		child.queue_free()
	var count := 0
	for data in Inventory.get_stored_furniture():
		if data.is_essential:
			continue
		_sell_list.add_child(_create_sell_row(data))
		count += 1
	if count == 0:
		var empty := _small_label("Im Inventar liegt gerade nichts, was du verkaufen kannst.", 17, MUTED_COLOR)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sell_list.add_child(empty)


func _create_sell_row(data: FurnitureData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var picture := _create_preview(data)
	picture.custom_minimum_size = Vector2(110, 70)
	row.add_child(picture)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(_small_label("%s  ×%d" % [data.display_name, Inventory.get_count(data.get_id())], 17, TEXT_COLOR))
	info.add_child(_create_style_row(data.styles))
	info.add_child(_small_label("Neupreis: " + Wallet.format(data.price), 13, MUTED_COLOR))
	row.add_child(info)

	var button := Button.new()
	button.text = "Verkaufen: +" + Wallet.format(data.get_sell_price())
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(sell.bind(data))
	row.add_child(button)
	return row


## Verkauft ein Exemplar aus dem Inventar.
func sell(data: FurnitureData) -> void:
	if data.is_essential or not Inventory.take_furniture(data.get_id()):
		return
	var price := data.get_sell_price()
	Wallet.earn(price, "Verkauf im Shop")
	_sell_message.text = "%s verkauft – du bekommst %s." % [data.display_name, Wallet.format(price)]


# --- Bestand ---

const STOCK_COLUMNS := ["Genre", "Im Regal", "Im Lager", "Unterwegs", "Gesamt", "Sammlung"]


## Die Bestandsliste: je Genre, wie viele Bücher im Regal, im Lager und unterwegs
## (getragen oder im Rückgabekasten) sind.
func _refresh_stock() -> void:
	for child in _stock_grid.get_children():
		_stock_grid.remove_child(child)
		child.queue_free()
	_stock_grid.columns = STOCK_COLUMNS.size()
	for i in STOCK_COLUMNS.size():
		_add_stock_cell(STOCK_COLUMNS[i], MUTED_COLOR, i > 0)
	var sums := [0, 0, 0, 0, 0, 0]
	for entry in BookStock.get_overview():
		var genre: GenreData = entry.genre
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := TextureRect.new()
		icon.texture = BookIcons.get_stack_icon(genre)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		name_row.add_child(icon)
		name_row.add_child(_small_label(genre.display_name, 17, TEXT_COLOR))
		_stock_grid.add_child(name_row)
		var values := [entry.shelves, entry.stored, entry.elsewhere, entry.total]
		for i in values.size():
			sums[i] += values[i]
			_add_stock_cell(str(values[i]), KEY_COLOR if i == 3 else TEXT_COLOR, true)
		_add_stock_cell("%d / %d" % [entry.discovered, entry.catalog], MUTED_COLOR, true)
		sums[4] += entry.discovered
		sums[5] += entry.catalog
	_add_stock_cell("Zusammen", MUTED_COLOR, false)
	for i in 4:
		_add_stock_cell(str(sums[i]), KEY_COLOR, true)
	_add_stock_cell("%d / %d" % [sums[4], sums[5]], KEY_COLOR, true)

	var carried := BookStock.carried.size()
	_store_carried_button.visible = carried > 0
	_store_carried_button.text = "Getragene Bücher ins Lager legen (%d)" % carried


func _add_stock_cell(text: String, color: Color, is_number: bool) -> void:
	var label := _small_label(text, 17, color)
	if is_number:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size.x = 96
	else:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_grid.add_child(label)


func _on_store_carried_pressed() -> void:
	# Je Genre ein kleiner Bücherstapel in der Lager-Anzeige
	for genre_id in BookStock.get_carried_counts():
		var genre := Catalog.get_genre(genre_id)
		if genre:
			StorageIndicator.add_item(self, genre)
	var count := BookStock.store_carried()
	if count > 0:
		_stock_message.text = "%d %s ins Lager gelegt." % [count, "Buch" if count == 1 else "Bücher"]


# --- Sammlung ---

## Genres in der Sammlung: freigeschaltete und alle, von denen ich schon Titel kenne.
func _collection_genres() -> Array[GenreData]:
	var result: Array[GenreData] = []
	for genre in Catalog.get_all_genres():
		if BookStock.is_genre_unlocked(genre.get_id()) or BookStock.get_discovered_count(genre.get_id()) > 0:
			result.append(genre)
	return result


func _refresh_collection() -> void:
	var genres := _collection_genres()
	if genres.is_empty():
		return
	var ids := genres.map(func(genre: GenreData) -> String: return genre.get_id())
	if not ids.has(_collection_genre):
		_collection_genre = ids[0]
	# Genre-Knöpfe links mit Sammelstand
	for child in _collection_genre_list.get_children():
		_collection_genre_list.remove_child(child)
		child.queue_free()
	for genre in genres:
		var id := genre.get_id()
		var button := Button.new()
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  %d/%d" % [genre.display_name, BookStock.get_discovered_count(id),
			Catalog.get_books_of_genre(id).size()]
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("pressed", _selected_style)
		button.add_theme_stylebox_override("hover_pressed", _selected_style)
		button.set_pressed_no_signal(id == _collection_genre)
		button.pressed.connect(func() -> void:
			_collection_genre = id
			_queue_refresh())
		_collection_genre_list.add_child(button)
	# Wo stehen meine Exemplare? Je Titel-id gezählt: insgesamt, im Lager, im Regal
	var total := {}
	var stored := {}
	var shelved := {}
	for book in BookStock.get_all_owned_books():
		total[book.data.id] = int(total.get(book.data.id, 0)) + 1
	for book in BookStock.get_stored_books(_collection_genre):
		stored[book.data.id] = int(stored.get(book.data.id, 0)) + 1
	for shelf in get_tree().get_nodes_in_group(BookStock.SHELF_GROUP):
		for book: Book in shelf.get_books():
			shelved[book.data.id] = int(shelved.get(book.data.id, 0)) + 1
	var entries := []
	for data in Catalog.get_books_of_genre(_collection_genre):
		var known := BookStock.is_discovered(data.id)
		var in_storage := int(stored.get(data.id, 0))
		var on_shelf := int(shelved.get(data.id, 0))
		var elsewhere := int(total.get(data.id, 0)) - in_storage - on_shelf
		var notes: Array[String] = []
		if in_storage > 0:
			notes.append("%d im Lager" % in_storage)
		if on_shelf > 0:
			notes.append("%d im Regal" % on_shelf)
		if elsewhere > 0:
			notes.append("%d unterwegs" % elsewhere)
		if known and notes.is_empty():
			notes.append("gerade keins da")
		entries.append({"data": data, "known": known, "note": " · ".join(notes), "enabled": in_storage > 0})
	var genre := Catalog.get_genre(_collection_genre)
	_collection_header.text = "%s: %d von %d Titeln entdeckt" % [genre.display_name,
		BookStock.get_discovered_count(_collection_genre), entries.size()]
	_collection_picker.show_entries(entries)


## Ein Buch aus dem Lager obenauf in die Hand nehmen.
func _on_collection_book_chosen(data: BookData) -> void:
	for book in BookStock.get_stored_books(data.genre_id):
		if book.data == data and BookStock.take_stored_book(book):
			BookStock.carry([book])
			close()
			Notice.post(self, "„%s“ liegt obenauf in deiner Hand – schau auf eine Stelle im Regal und drücke E." % data.title)
			return


# --- Hilfsfunktionen ---

func _find_cart_entry(kind: String, id: String) -> Dictionary:
	for entry in _cart:
		if entry.kind == kind and entry.id == id:
			return entry
	return {}


func _resource_of(entry: Dictionary) -> Resource:
	if entry.kind == "surface":
		return Catalog.get_surface(entry.id)
	if entry.kind == "books":
		return Catalog.get_genre(entry.id)
	return Catalog.get_furniture(entry.id)


func _price_of(entry: Dictionary) -> int:
	var resource := _resource_of(entry)
	return resource.price if resource else 0


func _name_of(entry: Dictionary) -> String:
	var resource := _resource_of(entry)
	if resource is GenreData:
		return "Bücherpaket %s (je %d Bücher)" % [resource.display_name, GameConfig.books_per_package]
	return resource.display_name if resource else str(entry.id)


func _get_deliveries() -> DeliveryManager:
	return get_tree().get_first_node_in_group(DeliveryManager.GROUP) as DeliveryManager


func _is_surface_on_the_way(id: String) -> bool:
	var deliveries := _get_deliveries()
	return deliveries != null and deliveries.is_surface_on_the_way(id)


func _count_in_room(id: String) -> int:
	var count := 0
	for room in get_tree().get_nodes_in_group(SaveManager.PERSIST_GROUP):
		if room is Room:
			count += room.count_placed(id)
	return count


func _create_style_row(styles: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	for style in StyleTags.to_list(styles):
		row.add_child(_small_label("● " + StyleTags.get_display_name(style), 13, StyleTags.get_color(style)))
	if styles == 0:
		row.add_child(_small_label("○ stilneutral", 13, MUTED_COLOR))
	return row


func _small_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _small_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(30, 0)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _make_compact_style(Color(0.3, 0.21, 0.15)))
	button.add_theme_stylebox_override("hover", _make_compact_style(Color(0.45, 0.31, 0.2)))
	button.add_theme_stylebox_override("pressed", _make_compact_style(Color(0.22, 0.15, 0.1)))
	button.pressed.connect(action)
	return button


func _make_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.45, 0.31, 0.2, 1)
	style.border_color = KEY_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	# Gleiche Innenränder wie im Theme, damit sich die Knopfbreite beim Auswählen nicht ändert
	style.set_content_margin_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	return style


## Kleiner Knopf-Stil für + und − im Warenkorb.
func _make_compact_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	return style
