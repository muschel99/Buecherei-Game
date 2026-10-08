extends TabletApp
## App "Statistik" auf dem Theken-Tablet: ein ruhiger Überblick zum gelegentlichen Reinschauen.
##
## Oben ein paar große Zahlen (Kacheln), darunter schlichte Balken "je Genre". Bewusst wenig:
## kein Dashboard, nur ein paar schöne Zahlen.
##
## Neue Werte ergänzen (z. B. später Besucher, ausgeliehene Bücher, Kaffee und Kuchen):
## Ein beliebiger Knoten kommt in die Gruppe SOURCE_GROUP ("stat_sources") und hat eine Funktion
## get_stats(), die eine Liste von Einträgen liefert. Zwei Arten gibt es:
##   {"label": "Besucher heute", "value": 12, "order": 50}                 -> eine Kachel
##   {"label": "Ausgeliehen je Genre", "per_genre": {"crime": 3, …}, "order": 60}  -> Balken
## Freiwillig: "note" (kleiner Text unter der Zahl), "symbol" (StockSymbol.Kind für ein kleines
## Symbol). Werte, die es (noch) nicht gibt, einfach weglassen – sie erscheinen dann nicht.
## Die Werte zu den Büchern stehen unten in _book_stats() (gleiche Form).

const SOURCE_GROUP := "stat_sources"
## Kacheln je Reihe (höchstens)
const TILES_PER_ROW := 4

var _box: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	# Etwas Luft an den Seiten, damit es ruhig wirkt
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 8)
	scroll.add_child(margin)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 22)
	margin.add_child(_box)


## Alle Einträge: die Bücher-Werte und alles aus der Gruppe "stat_sources", nach "order".
func get_stats() -> Array[Dictionary]:
	var result: Array[Dictionary] = _book_stats()
	for source in get_tree().get_nodes_in_group(SOURCE_GROUP):
		if source.has_method("get_stats"):
			for entry in source.get_stats():
				if entry is Dictionary and (entry.has("value") or entry.has("per_genre")):
					result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 100)) < int(b.get("order", 100)))
	return result


func refresh() -> void:
	clear(_box)
	var tiles: Array[Dictionary] = []
	for entry in get_stats():
		if entry.has("per_genre"):
			_add_tiles(tiles)
			tiles.clear()
			_box.add_child(_create_genre_bars(entry))
		else:
			tiles.append(entry)
	_add_tiles(tiles)


## Die Werte zu den Büchern (alles, was es im Spiel schon gibt).
func _book_stats() -> Array[Dictionary]:
	var total := 0
	var shelves := 0
	var loose := 0
	var stored := 0
	var per_genre := {}
	var discovered := 0
	var catalog := 0
	for entry in BookStock.get_overview():
		total += entry.total
		shelves += entry.shelves
		loose += entry.loose
		stored += entry.stored
		discovered += entry.discovered
		catalog += entry.catalog
		if entry.total > 0:
			per_genre[entry.genre.get_id()] = entry.total
	var shelf_count := get_tree().get_nodes_in_group(BookStock.SHELF_GROUP).size()
	return [
		{"label": "Bücher", "value": total, "note": "insgesamt", "order": 10},
		{"label": "Im Regal", "value": shelves, "note": "in %d %s" % [shelf_count, "Regal" if shelf_count == 1 else "Regalen"],
			"symbol": StockSymbol.Kind.SHELF, "order": 20},
		{"label": "Ausgelegt", "value": loose, "symbol": StockSymbol.Kind.LOOSE, "order": 30},
		{"label": "Im Lager", "value": stored, "symbol": StockSymbol.Kind.STORAGE, "order": 40},
		{"label": "Titel entdeckt", "value": "%d / %d" % [discovered, catalog], "order": 45},
		{"label": "Bücher je Genre", "per_genre": per_genre, "order": 50},
	]


## Kacheln in Reihen (höchstens TILES_PER_ROW nebeneinander, alle gleich breit).
func _add_tiles(tiles: Array[Dictionary]) -> void:
	var row: HBoxContainer = null
	for i in tiles.size():
		if i % TILES_PER_ROW == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			_box.add_child(row)
		row.add_child(_create_tile(tiles[i]))
	# Letzte Reihe auffüllen, damit alle Kacheln gleich breit bleiben
	if row:
		for i in (TILES_PER_ROW - tiles.size() % TILES_PER_ROW) % TILES_PER_ROW:
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(gap)


## Eine Kachel: kleines Symbol und Wort oben, darunter groß die Zahl, ganz unten ein Hinweis.
func _create_tile(entry: Dictionary) -> Control:
	var panel := make_panel(18.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.name = str(entry.get("label", "Wert"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)
	if entry.has("symbol"):
		var symbol := StockSymbol.create(entry.symbol)
		symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(symbol)
	var label := make_label(str(entry.get("label", "")), 16, TabletFrame.MUTED_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(label)
	var value := make_label(_format(entry.value), 40, TabletFrame.TEXT_COLOR)
	value.name = "Value"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(value)
	var note := make_label(str(entry.get("note", "")), 14, TabletFrame.MUTED_COLOR)
	box.add_child(note)
	return panel


## Schlichte waagrechte Balken je Genre (eine Farbe, längster Balken = volle Breite).
func _create_genre_bars(entry: Dictionary) -> Control:
	var panel := make_panel(18.0)
	panel.name = str(entry.get("label", "Je Genre"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(make_label(str(entry.get("label", "")), 17, TabletFrame.MUTED_COLOR))
	var counts: Dictionary = entry.per_genre
	if counts.is_empty():
		box.add_child(make_label("Noch nichts da.", 15, TabletFrame.MUTED_COLOR))
		return panel
	var biggest := 1
	for id in counts:
		biggest = maxi(biggest, int(counts[id]))
	# Größte zuerst; gleich große nach Name
	var ids := counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return counts[a] > counts[b] if counts[a] != counts[b] else _genre_name(a) < _genre_name(b))
	for id: String in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.tooltip_text = "%s: %d" % [_genre_name(id), counts[id]]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(row)
		var name_label := make_label(_genre_name(id), 16)
		name_label.custom_minimum_size.x = 170
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
		var bar := StatBar.new()
		bar.share = float(counts[id]) / float(biggest)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var number := make_label(str(counts[id]), 16)
		number.autowrap_mode = TextServer.AUTOWRAP_OFF
		number.custom_minimum_size.x = 44
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(number)
	return panel


static func _genre_name(id: String) -> String:
	var genre := Catalog.get_genre(id)
	return genre.display_name if genre else id


## Zahlen mit Tausenderpunkt (1.250), Texte so, wie sie sind.
static func _format(value: Variant) -> String:
	if value is int:
		var digits := str(absi(value))
		var result := ""
		while digits.length() > 3:
			result = "." + digits.right(3) + result
			digits = digits.left(digits.length() - 3)
		return ("-" if value < 0 else "") + digits + result
	return str(value)


## Ein dünner, ruhiger Balken mit runden Enden (und einer zarten Spur dahinter).
class StatBar:
	extends Control

	const HEIGHT := 10.0
	const TRACK_COLOR := Color(1.0, 0.95, 0.85, 0.07)

	var share := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(60, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radius := HEIGHT / 2.0
		_round_bar(size.x, TRACK_COLOR, radius)
		if share > 0.0:
			_round_bar(maxf(size.x * share, HEIGHT), TabletFrame.KEY_COLOR, radius)

	func _round_bar(width: float, color: Color, radius: float) -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(radius))
		box.anti_aliasing = true
		draw_style_box(box, Rect2(0.0, (size.y - HEIGHT) / 2.0, width, HEIGHT))
