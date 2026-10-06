class_name ShopWindow
extends CanvasLayer
## Der Shop am Tablet auf der Theke: Möbel, Deko, Wandfarben, Böden und Decken kaufen
## und Dinge aus dem Inventar verkaufen.
##
## - Reiter "Kaufen": alles Freigeschaltete nach Kategorien, mit Vorschau, Preis und Stil.
##   Ein Klick legt es in den Warenkorb (Möbel auch mehrfach). "Bestellen" bezahlt
##   (Wallet) und gibt die Bestellung an den Lieferdienst (DeliveryManager) – kurz darauf
##   steht ein Karton vor der Tür.
## - Reiter "Verkaufen": Möbel aus dem Inventar (nicht die im Raum) gegen einen Teil des
##   Preises (GameConfig.sell_price_share).
## Öffnen: E am Tablet. Schließen: Esc oder "Schließen" (Esc-Regel über MenuStack).
## Solange der Shop offen ist, ist der Mauszeiger sichtbar und die Spielfigur steht still.

const GROUP := "shop_window"
const KEY_COLOR := Color(0.96, 0.78, 0.48)
const MUTED_COLOR := Color(0.85, 0.78, 0.68, 0.8)
const TEXT_COLOR := Color(1.0, 0.96, 0.88)
const SOFT_WARNING_COLOR := Color(1.0, 0.8, 0.62)
const CARD_SIZE := Vector2(196, 262)
const PREVIEW_SIZE := Vector2(176, 118)

## Pfad zur Spielfigur (im Inspektor der Hauptszene eingetragen).
@export var player_path: NodePath

@onready var _player: Player = get_node(player_path)
@onready var _buy_tab_button: Button = %BuyTabButton
@onready var _sell_tab_button: Button = %SellTabButton
@onready var _close_button: Button = %CloseButton
@onready var _money_label: Label = %MoneyLabel
@onready var _buy_view: Control = %BuyView
@onready var _sell_view: Control = %SellView
@onready var _category_list: VBoxContainer = %CategoryList
@onready var _item_scroll: ScrollContainer = %ItemScroll
@onready var _item_flow: HFlowContainer = %ItemFlow
@onready var _cart_list: VBoxContainer = %CartList
@onready var _total_label: Label = %TotalLabel
@onready var _cart_message: Label = %CartMessage
@onready var _order_button: Button = %OrderButton
@onready var _sell_list: VBoxContainer = %SellList
@onready var _sell_info: Label = %SellInfo
@onready var _sell_message: Label = %SellMessage

var is_open: bool = false

## Kategorien links: [Anzeigename, "furniture" oder "surface", Kategorie bzw. Art]
var _categories: Array = []
var _category_buttons: Array[Button] = []
var _current_category: int = 0
## Warenkorb: Einträge { "kind": "furniture"/"surface", "id": "...", "count": Anzahl }
var _cart: Array[Dictionary] = []
var _order_text := ""
var _thumbnails: ThumbnailRenderer
var _selected_style: StyleBoxFlat
var _refresh_queued := false


func _ready() -> void:
	add_to_group(GROUP)
	hide()
	_thumbnails = ThumbnailRenderer.new()
	_thumbnails.name = "Thumbnails"
	add_child(_thumbnails)
	_selected_style = _make_selected_style()
	for button: Button in [_buy_tab_button, _sell_tab_button]:
		button.add_theme_stylebox_override("pressed", _selected_style)
		button.add_theme_stylebox_override("hover_pressed", _selected_style)
	for category in FurnitureData.Category.values():
		_categories.append([FurnitureData.get_category_display_name(category), "furniture", category])
	_categories.append(["Wandfarben", "surface", SurfaceData.Kind.WALL])
	_categories.append(["Böden", "surface", SurfaceData.Kind.FLOOR])
	_categories.append(["Decken", "surface", SurfaceData.Kind.CEILING])
	_build_category_buttons()

	_buy_tab_button.pressed.connect(_show_view.bind(true))
	_sell_tab_button.pressed.connect(_show_view.bind(false))
	_close_button.pressed.connect(close)
	_order_button.pressed.connect(_on_order_pressed)
	Wallet.money_changed.connect(func(_money: int, _change: int) -> void: _queue_refresh())
	Inventory.changed.connect(_queue_refresh)
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
	_show_view(true)


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


## true = Reiter "Kaufen", false = "Verkaufen".
func _show_view(buy: bool) -> void:
	_buy_tab_button.set_pressed_no_signal(buy)
	_sell_tab_button.set_pressed_no_signal(not buy)
	_buy_view.visible = buy
	_sell_view.visible = not buy
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
	else:
		_refresh_sell_list()


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


func _show_category(index: int) -> void:
	var scroll := _item_scroll.scroll_vertical
	_current_category = index
	for i in _category_buttons.size():
		_category_buttons[i].set_pressed_no_signal(i == index)
	for child in _item_flow.get_children():
		_item_flow.remove_child(child)
		child.queue_free()
	var offers := get_offers(index)
	for item in offers:
		_item_flow.add_child(_create_offer_card(item))
	if offers.is_empty():
		_item_flow.add_child(_small_label("Hier gibt es gerade nichts zu kaufen.", 16, MUTED_COLOR))
	_item_scroll.set_deferred("scroll_vertical", scroll)


## Eine Karte im Shop: Vorschau, Name, Stile, Preis und was man davon schon hat.
func _create_offer_card(item: Resource) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = item.description if item is FurnitureData else ""
	card.pressed.connect(add_to_cart.bind(item))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	box.add_child(_create_preview(item))

	var title := _small_label(item.display_name, 16, TEXT_COLOR)
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


## Vorschau: ein Foto des Möbelstücks bzw. ein Farbfeld der Oberfläche.
func _create_preview(item: Resource) -> Control:
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

## Legt etwas in den Warenkorb (Möbel auch mehrfach, Oberflächen einmal).
func add_to_cart(item: Resource) -> void:
	var kind := "surface" if item is SurfaceData else "furniture"
	var entry := _find_cart_entry(kind, item.get_id())
	if entry.is_empty():
		_cart.append({"kind": kind, "id": item.get_id(), "count": 1})
	elif kind == "furniture":
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
	if entry.kind == "furniture":
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


# --- Hilfsfunktionen ---

func _find_cart_entry(kind: String, id: String) -> Dictionary:
	for entry in _cart:
		if entry.kind == kind and entry.id == id:
			return entry
	return {}


func _resource_of(entry: Dictionary) -> Resource:
	if entry.kind == "surface":
		return Catalog.get_surface(entry.id)
	return Catalog.get_furniture(entry.id)


func _price_of(entry: Dictionary) -> int:
	var resource := _resource_of(entry)
	return resource.price if resource else 0


func _name_of(entry: Dictionary) -> String:
	var resource := _resource_of(entry)
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
