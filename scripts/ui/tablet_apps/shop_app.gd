class_name ShopApp
extends TabletApp
## Gemeinsame Grundlage der Einkaufs-Apps auf dem Theken-Tablet ("Einrichtung" und "Bücher"):
## Angebotskarten mit Vorschau, Name, Stilen und Preis, dazu ein Warenkorb mit "Bestellen".
## Bestellen bezahlt (Wallet) und gibt die Bestellung an den Lieferdienst (DeliveryManager) –
## kurz darauf stehen die Kartons vor der Tür. Jede App hat ihren eigenen Warenkorb.

const SOFT_WARNING_COLOR := Color(1.0, 0.8, 0.62)
const CARD_SIZE := Vector2(196, 262)
const PREVIEW_SIZE := Vector2(176, 118)
const CART_WIDTH := 320.0

## Warenkorb: Einträge { "kind": "furniture"/"surface"/"books", "id": "...", "count": Anzahl }
## (bei "books": id = Genre, count = Zahl der Bücherpakete)
var cart: Array[Dictionary] = []

var _order_text := ""
var _cart_list: VBoxContainer
var _total_label: Label
var _cart_message: Label
var _order_button: Button


func app_opened() -> void:
	_order_text = ""


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
		cart.append({"kind": kind, "id": item.get_id(), "count": 1})
	elif kind != "surface":
		entry.count += 1
	_order_text = ""
	request_refresh()


func _change_cart_count(entry: Dictionary, change: int) -> void:
	entry.count += change
	if entry.count <= 0:
		cart.erase(entry)
	_order_text = ""
	request_refresh()


func get_cart_total() -> int:
	var total := 0
	for entry in cart:
		total += _price_of(entry) * int(entry.count)
	return total


## Bestellen: bezahlen und an den Lieferdienst geben.
func order() -> void:
	var total := get_cart_total()
	var deliveries := _get_deliveries()
	if cart.is_empty() or deliveries == null or not Wallet.spend(total, "Einkauf am Tablet"):
		request_refresh()
		return
	deliveries.place_order(cart)
	cart.clear()
	_order_text = "Danke! In etwa %d Sekunden steht der Karton vor der Tür." % roundi(GameConfig.delivery_time)
	request_refresh()


## Baut den Warenkorb (rechte Spalte) in "parent".
func build_cart(parent: Container) -> Control:
	var panel := make_panel(14.0)
	panel.custom_minimum_size.x = CART_WIDTH
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(make_label("Warenkorb", 19))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_cart_list = VBoxContainer.new()
	_cart_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cart_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_cart_list)
	_total_label = make_label("", 18, TabletFrame.KEY_COLOR)
	box.add_child(_total_label)
	_cart_message = make_label("", 15, TabletFrame.MUTED_COLOR)
	box.add_child(_cart_message)
	_order_button = Button.new()
	_order_button.text = "Bestellen"
	_order_button.focus_mode = Control.FOCUS_NONE
	_order_button.add_theme_font_size_override("font_size", 19)
	_order_button.pressed.connect(order)
	box.add_child(_order_button)
	return panel


func refresh_cart() -> void:
	clear(_cart_list)
	for entry in cart:
		_cart_list.add_child(_create_cart_row(entry))
	if cart.is_empty():
		_cart_list.add_child(make_label("Noch leer.", 15, TabletFrame.MUTED_COLOR))
	var total := get_cart_total()
	_total_label.text = "Summe: " + Wallet.format(total)
	var affordable := Wallet.can_afford(total)
	_order_button.disabled = cart.is_empty() or not affordable
	_cart_message.remove_theme_color_override("font_color")
	if not _order_text.is_empty():
		_cart_message.text = _order_text
	elif cart.is_empty():
		_cart_message.text = "Klick auf etwas legt es hinein."
	elif not affordable:
		# Freundlich, ohne Strafe: einfach zeigen, wie viel fehlt
		_cart_message.text = "Es fehlen noch %s." % Wallet.format(total - Wallet.money)
		_cart_message.add_theme_color_override("font_color", SOFT_WARNING_COLOR)
	else:
		_cart_message.text = "Lieferung in etwa %d Sekunden." % roundi(GameConfig.delivery_time)


## Eine Zeile im Warenkorb: Name oben, darunter Anzahl (− 2 +) und Preis.
func _create_cart_row(entry: Dictionary) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	block.add_child(make_label(_name_of(entry), 15))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	block.add_child(row)
	if entry.kind != "surface":
		row.add_child(make_icon_button(TabletIconButton.Icon.MINUS, _change_cart_count.bind(entry, -1)))
		var count := make_label(str(entry.count), 16)
		count.custom_minimum_size.x = 22
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
		row.add_child(make_icon_button(TabletIconButton.Icon.PLUS, _change_cart_count.bind(entry, 1)))
	else:
		row.add_child(make_icon_button(TabletIconButton.Icon.CLOSE, _change_cart_count.bind(entry, -1), "Entfernen"))
	var price := make_label(Wallet.format(_price_of(entry) * int(entry.count)), 16, TabletFrame.KEY_COLOR)
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	return block


# --- Angebotskarten ---

## Eine Karte: Vorschau, Name, Stile, Preis und was man davon schon hat. Ein Klick legt sie in
## den Warenkorb.
func create_offer_card(item: Resource) -> Button:
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
	box.add_child(create_preview(item))
	var title_text: String = item.display_name
	if item is GenreData:
		title_text = "%s – Paket mit %d Büchern" % [item.display_name, GameConfig.books_per_package]
	var title := _small_label(title_text, 16, TabletFrame.TEXT_COLOR)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.custom_minimum_size.y = 42
	box.add_child(title)
	box.add_child(create_style_row(item.styles))
	box.add_child(_small_label(Wallet.format(item.price), 17, TabletFrame.KEY_COLOR))
	# Was habe ich schon? Oberflächen kauft man nur einmal.
	var status := ""
	if item is SurfaceData:
		var id: String = item.get_id()
		if Inventory.owns_surface(id):
			status = "✓ Gehört dir schon"
		elif _is_surface_on_the_way(id):
			status = "Schon bestellt"
		elif not _find_cart_entry("surface", id).is_empty():
			status = "Im Warenkorb"
		card.disabled = not status.is_empty()
		card.modulate.a = 0.55 if card.disabled else 1.0
		if status.is_empty():
			status = "Einmal kaufen, immer nutzen"
	elif item is GenreData:
		# Sammlung: wie viele Titel des Genres kenne ich schon?
		var catalog := Catalog.get_books_of_genre(item.get_id()).size()
		status = "Sammlung: %d von %d" % [BookStock.get_discovered_count(item.get_id()), catalog]
	else:
		var owned := Inventory.get_count(item.get_id()) + _count_in_room(item.get_id())
		status = "Hast du: %d" % owned if owned > 0 else ""
	box.add_child(_small_label(status, 13, TabletFrame.MUTED_COLOR))
	# Lange Zeilen enden mit "…", statt über den Kartenrand zu ragen
	for label in box.get_children():
		if label is Label and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.clip_text = true
	return card


## Vorschau: ein Foto des Möbelstücks, ein Farbfeld der Oberfläche bzw. ein Bücherstapel.
func create_preview(item: Resource) -> Control:
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
	if tablet and tablet.thumbnails:
		tablet.thumbnails.request(item, func(texture: Texture2D) -> void:
			var target := picture_ref.get_ref() as TextureRect
			if target:
				target.texture = texture)
	return picture


func create_style_row(styles: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	for style in StyleTags.to_list(styles):
		row.add_child(_small_label("● " + StyleTags.get_display_name(style), 13, StyleTags.get_color(style)))
	if styles == 0:
		row.add_child(_small_label("○ stilneutral", 13, TabletFrame.MUTED_COLOR))
	return row


# --- Hilfsfunktionen ---

func _find_cart_entry(kind: String, id: String) -> Dictionary:
	for entry in cart:
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
		return "Bücherpaket %s (%d Bücher)" % [resource.display_name, GameConfig.books_per_package]
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


func _small_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
