extends ShopApp
## App "Bücher" auf dem Theken-Tablet: Bücherpakete je freigeschaltetem Genre kaufen (wie
## bisher im Shop). Ein Klick auf ein Paket legt es in den Warenkorb, "Bestellen" schickt es
## los – kurz darauf steht der Karton vor der Tür.

var _item_scroll: ScrollContainer
var _item_flow: HFlowContainer


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.set_anchors_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 16)
	add_child(columns)
	_item_scroll = ScrollContainer.new()
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_item_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_item_scroll)
	_item_flow = HFlowContainer.new()
	_item_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_flow.add_theme_constant_override("h_separation", 10)
	_item_flow.add_theme_constant_override("v_separation", 10)
	_item_scroll.add_child(_item_flow)
	build_cart(columns)


## Die Pakete, die es gerade gibt (je freigeschaltetem Genre).
func get_offers() -> Array[GenreData]:
	return BookStock.get_unlocked_genres()


func refresh() -> void:
	var scroll := _item_scroll.scroll_vertical
	clear(_item_flow)
	for genre in get_offers():
		_item_flow.add_child(create_offer_card(genre))
	_item_scroll.set_deferred("scroll_vertical", scroll)
	refresh_cart()
