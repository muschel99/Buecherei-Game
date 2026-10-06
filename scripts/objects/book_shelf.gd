class_name BookShelf
extends Node3D
## Ein Bücherregal: Bücher stehen in Fächern (BookRow), die Rücken zeigen nach vorn.
##
## So baut man ein Bücherregal (siehe scenes/furniture/bookshelf.tscn):
## - In der Möbel-Szene einen Knoten mit diesem Script anlegen ("BookShelf").
## - Darunter für jedes Fach einen BookRow-Knoten (Reihenfolge = Reihenfolge beim Befüllen).
## - Optional ein Marker3D "SignPoint": Dort hängt das Genre-Schild (Mitte, vorn).
## - Ein Interactable "Interactable" mit Kollisionsform: E öffnet das Regal-Menü bzw.
##   räumt getragene Bücher ein.
##
## Leistung: Alle Bücher eines Regals werden in einem einzigen Rutsch gezeichnet
## (MultiMesh). Jedes Buch ist ein gestreckter Würfel mit eigener Farbe – so bleiben auch
## hunderte Bücher im Raum leicht für den PC.
## Das Regal merkt sich sein Genre und seine Bücher; gespeichert wird beides mit dem Raum
## (PlacedFurniture.get_contents_data). Wird das Regal mit X weggeräumt, gehen die Bücher
## ins Lager (release_contents).

## Wird gesendet, wenn sich Bücher oder Genre ändern.
signal contents_changed

## Genre-Wert für "Gemischt": Hier passt jedes Buch hinein.
const MIXED := "mixed"
## So weit vor dem Regal beginnt ein Buch, das hineingleitet (in Metern).
const SLIDE_DISTANCE := 0.26
## So lange rücken Bücher zusammen, wenn eine Lücke entsteht (in Sekunden).
const MOVE_TIME := 0.3
## Größe des Genre-Schilds (Breite, Höhe in Metern).
const SIGN_SIZE := Vector2(0.3, 0.075)
const SIGN_TEXT_COLOR := Color(0.98, 0.94, 0.84)

## Genre dieses Regals: "" = noch keins gewählt, MIXED = Gemischt, sonst die Genre-id.
var genre_id: String = ""
## Alle Bücher im Regal (in Reihenfolge: Fach für Fach, von links nach rechts).
var books: Array[Book] = []

var _rows: Array[BookRow] = []
var _targets: Array[Transform3D] = []  # Endlage je Buch (gleiche Reihenfolge wie books)
var _looks: Dictionary = {}  # Book -> { "size", "color", "custom" }
var _index: Dictionary = {}  # Book -> Nummer im MultiMesh
var _row_index := 0  # Schreibmarke: Fach und Stelle, an die das nächste Buch kommt
var _row_x := 0.0
var _anims: Dictionary = {}  # Book -> { "from", "start", "time", "appear" }
var _leaving: Array[Dictionary] = []  # Bücher, die gerade herausgleiten
var _clock := 0.0
var _multimesh: MultiMesh
var _sign_plate: MeshInstance3D
var _sign_label: Label3D
var _interactable: Interactable
var _is_live := false  # steht wirklich im Raum (nicht Vorschau oder Foto)


func _ready() -> void:
	add_to_group(PlacedFurniture.CONTENTS_GROUP)
	for child in get_children():
		if child is BookRow:
			_rows.append(child)
	var books_instance := MultiMeshInstance3D.new()
	books_instance.name = "Books"
	_multimesh = BookLook.create_multimesh()
	books_instance.multimesh = _multimesh
	books_instance.material_override = BookLook.get_material()
	add_child(books_instance)
	_create_sign()
	_reset_cursor()
	set_process(false)

	_interactable = get_node_or_null("Interactable") as Interactable
	_is_live = FurnitureUtils.find_placed_furniture(self) != null
	if _is_live:
		add_to_group(BookStock.SHELF_GROUP)
		BookStock.carried_changed.connect(_update_prompt)
		if _interactable:
			_interactable.interacted.connect(_on_interacted)
	_update_prompt()


# --- Abfragen ---

## Name des Regals (aus dem Datenblatt des Möbelstücks).
func get_display_name() -> String:
	var item := FurnitureUtils.find_placed_furniture(self)
	return item.data.display_name if item and item.data else "Bücherregal"


## Hat das Regal schon ein Genre (oder "Gemischt")?
func has_genre() -> bool:
	return not genre_id.is_empty()


## Anzeigename des Genres: "Gemischt", z. B. "Krimi" – oder "" (noch keins gewählt).
func get_genre_name() -> String:
	if genre_id == MIXED:
		return "Gemischt"
	var genre := Catalog.get_genre(genre_id)
	return genre.display_name if genre else ""


## Passt ein Buch dieses Genres hierher? ("Gemischt" nimmt alles.)
func accepts(book_genre_id: String) -> bool:
	return genre_id == MIXED or (has_genre() and genre_id == book_genre_id)


## Alle Bücher im Regal.
func get_books() -> Array[Book]:
	return books


## Wie viele Bücher dieses Genres stehen hier? (für den Bestand)
func count_books(of_genre_id: String) -> int:
	var count := 0
	for book in books:
		if book.genre_id == of_genre_id:
			count += 1
	return count


## Für wie viele Bücher ist ungefähr noch Platz? (Bücher sind verschieden dick.)
func get_free_estimate() -> int:
	if _row_index >= _rows.size():
		return 0
	var free_width := _rows[_row_index].width / 2.0 - _row_x
	for i in range(_row_index + 1, _rows.size()):
		free_width += _rows[i].width
	var range_t := GameConfig.book_thickness_range
	var average := range_t.x + (range_t.y - range_t.x) / 2.4 + 0.0025
	return maxi(0, floori(free_width / average))


## Wie viele der getragenen Bücher passen vom Genre her hierher?
func count_matching_carried() -> int:
	var count := 0
	for book in BookStock.carried:
		if accepts(book.genre_id):
			count += 1
	return count


# --- Ändern ---

## Wählt das Genre (MIXED = Gemischt). Bücher, die nicht mehr passen, gleiten heraus
## und gehen ins Lager. Liefert, wie viele das waren.
func set_genre(new_genre_id: String) -> int:
	genre_id = new_genre_id
	var mismatched: Array[Book] = []
	for book in books:
		if not accepts(book.genre_id):
			mismatched.append(book)
	remove_books(mismatched)
	_send_to_storage(mismatched)
	_update_sign()
	_changed()
	return mismatched.size()


## Stellt Bücher ins Regal, so viele hineinpassen – sie gleiten nacheinander hinein.
## Liefert die Bücher, für die kein Platz mehr war.
func add_books(new_books: Array, animate: bool = true) -> Array[Book]:
	var rest: Array[Book] = []
	var interval := 0.0
	if animate and not new_books.is_empty():
		interval = minf(GameConfig.book_slide_interval, GameConfig.book_slide_max_total / new_books.size())
	var placed := 0
	for book: Book in new_books:
		var target: Variant = _place_next(book)
		if target == null:
			rest.append(book)
			continue
		books.append(book)
		_targets.append(target)
		if animate:
			# Startet etwas kleiner vor dem Regal und gleitet an seinen Platz
			var start: Transform3D = target
			start.basis = start.basis * Basis.from_scale(Vector3.ONE * 0.7)
			start.origin += Vector3(0.0, 0.03, SLIDE_DISTANCE)
			_anims[book] = {"from": start, "start": _clock + placed * interval,
				"time": GameConfig.book_slide_time, "appear": true}
		placed += 1
	_refresh_instances()
	if placed > 0:
		_changed()
	return rest


## Nimmt Bücher aus dem Regal: Sie gleiten heraus, die übrigen rücken zusammen.
## (Wohin die Bücher danach gehen, entscheidet der Aufrufer.)
func remove_books(to_remove: Array, animate: bool = true) -> void:
	if to_remove.is_empty():
		return
	var step := minf(GameConfig.book_slide_interval, GameConfig.book_slide_max_total / to_remove.size()) * 0.6
	var count := 0
	for book: Book in to_remove:
		var index := books.find(book)
		if index < 0:
			continue
		if animate:
			var look := _look(book)
			_leaving.append({"transform": _current_transform(book, index), "color": look.color,
				"custom": look.custom, "start": _clock + count * step, "time": GameConfig.book_slide_time})
			count += 1
		_anims.erase(book)
		books.remove_at(index)
		_targets.remove_at(index)
	_relayout(animate)
	_refresh_instances()
	_changed()


## Füllt das Regal aus dem Lager: mit Büchern seines Genres – bei "Gemischt" gleichmäßig
## aus allen Genres im Lager (nach Genre gruppiert). Liefert, wie viele es waren.
func fill_from_storage() -> int:
	if not has_genre():
		return 0
	var wanted := get_free_estimate() + 3  # ein paar mehr; was nicht passt, geht zurück
	var taken: Array[Book] = []
	if genre_id == MIXED:
		var shares := _mixed_shares(wanted)
		for id in shares:
			taken.append_array(BookStock.take_books(id, shares[id]))
	else:
		taken = BookStock.take_books(genre_id, wanted)
	var rest := add_books(taken)
	BookStock.put_back_first(rest)
	return taken.size() - rest.size()


## Legt alle Bücher zurück ins Lager (sie gleiten heraus). Liefert, wie viele es waren.
func return_all_to_storage() -> int:
	var all := books.duplicate()
	remove_books(all)
	_send_to_storage(all)
	return all.size()


## Räumt die getragenen Bücher ein, die hierher passen. Was nicht passt (anderes Genre
## oder kein Platz), trage ich weiter. Liefert, wie viele eingeräumt wurden.
func put_carried() -> int:
	if not has_genre():
		return 0
	var taken := BookStock.take_carried("" if genre_id == MIXED else genre_id)
	var rest := add_books(taken)
	BookStock.carry(rest)
	return taken.size() - rest.size()


## Zeigt Beispielbücher (für das Vorschaubild im Shop; nicht im Bestand).
func show_sample_books() -> void:
	var titles: Array[BookData] = []
	for genre in Catalog.get_all_genres():
		if genre.is_unlocked:
			titles.append_array(Catalog.get_books_of_genre(genre.get_id()))
	if titles.is_empty() or _rows.is_empty():
		return
	var samples: Array[Book] = []
	var wanted := roundi(get_free_estimate() * 0.75)
	for i in wanted:
		var book := Book.create_from(titles[(i * 7) % titles.size()])
		book.look = i * 7919
		samples.append(book)
	add_books(samples, false)


# --- Speichern (über PlacedFurniture) ---

func get_contents_data() -> Dictionary:
	return {"genre": genre_id, "books": Book.list_to_save_data(books)}


func load_contents_data(data: Dictionary) -> void:
	genre_id = str(data.get("genre", ""))
	books.clear()
	_targets.clear()
	_anims.clear()
	_leaving.clear()
	_reset_cursor()
	# Passt etwas nicht mehr (z. B. weil das Regal umgebaut wurde), kommt es ins Lager
	BookStock.store_books(add_books(Book.list_from_save_data(data.get("books")), false))
	_update_sign()
	_update_prompt()


## Das Regal wird weggeräumt (Taste X): Alle Bücher gehen zurück ins Lager.
func release_contents() -> void:
	var all := books.duplicate()
	books.clear()
	_targets.clear()
	_anims.clear()
	_send_to_storage(all)


# --- Anordnung ---

## Setzt die Schreibmarke an den Anfang des ersten Fachs.
func _reset_cursor() -> void:
	_row_index = 0
	_row_x = -_rows[0].width / 2.0 if not _rows.is_empty() else 0.0


## Nächster freier Platz für dieses Buch (Transform im Regal) – oder null, wenn es voll ist.
func _place_next(book: Book) -> Variant:
	var size: Vector3 = _look(book).size
	while _row_index < _rows.size():
		var row := _rows[_row_index]
		if _row_x + size.x <= row.width / 2.0 + 0.0001:
			var placed := _book_transform(row, book, size)
			_row_x += size.x + _jitter(book, 8) * 0.003 + 0.001
			return placed
		_row_index += 1
		if _row_index < _rows.size():
			_row_x = -_rows[_row_index].width / 2.0
	return null


## Lage eines Buchs im Fach: vorn bündig (mit einem Hauch Abweichung), leicht gedreht.
func _book_transform(row: BookRow, book: Book, size: Vector3) -> Transform3D:
	var height := minf(size.y, row.height - 0.015)
	var depth := minf(size.z, row.depth - 0.01)
	var inset := _jitter(book, 16) * 0.012
	var yaw := (_jitter(book, 24) - 0.5) * deg_to_rad(2.0)
	var origin := Vector3(_row_x + size.x / 2.0, height / 2.0, row.depth / 2.0 - depth / 2.0 - inset)
	var local := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size.x, height, depth)), origin)
	return row.transform * local


## Eine feste Zahl zwischen 0 und 1 aus dem Aussehen des Buchs (für kleine Abweichungen).
func _jitter(book: Book, shift: int) -> float:
	return float((book.look >> shift) & 255) / 255.0


## Ordnet alle Bücher neu an (z. B. nachdem welche herausgenommen wurden).
## animate: Bücher, die ihren Platz wechseln, rücken sanft nach.
func _relayout(animate: bool) -> void:
	var old: Dictionary = {}
	for i in books.size():
		old[books[i]] = _current_transform(books[i], i)
	_reset_cursor()
	_targets.clear()
	var overflow: Array[Book] = []
	for book in books.duplicate():
		var target: Variant = _place_next(book)
		if target == null:
			overflow.append(book)
			books.erase(book)
			_anims.erase(book)
			continue
		_targets.append(target)
		if animate and not _anims.has(book) and not (old[book] as Transform3D).is_equal_approx(target):
			_anims[book] = {"from": old[book], "start": _clock + 0.08, "time": MOVE_TIME, "appear": false}
	_send_to_storage(overflow)


# --- Zeichnen und Animation ---

func _look(book: Book) -> Dictionary:
	if not _looks.has(book):
		_looks[book] = {"size": BookLook.get_size(book), "color": BookLook.get_color(book),
			"custom": BookLook.get_custom(book)}
	return _looks[book]


## Wo das Buch gerade zu sehen ist (mitten in der Animation oder an seinem Platz).
func _current_transform(book: Book, index: int) -> Transform3D:
	var target := _targets[index]
	if not _anims.has(book):
		return target
	var anim: Dictionary = _anims[book]
	if _clock < anim.start:
		# Noch nicht dran: unsichtbar (Größe 0) bzw. noch am alten Platz
		return Transform3D(Basis.from_scale(Vector3.ZERO), target.origin) if anim.appear else anim.from
	var progress := clampf((_clock - anim.start) / anim.time, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	return (anim.from as Transform3D).interpolate_with(target, eased)


## Überträgt alle Bücher ins MultiMesh (Anzahl, Lage, Farbe, Verzierung).
func _refresh_instances() -> void:
	var count := books.size() + _leaving.size()
	if _multimesh.instance_count != count:
		_multimesh.instance_count = count
	_index.clear()
	for i in books.size():
		var book := books[i]
		var look := _look(book)
		_index[book] = i
		_multimesh.set_instance_transform(i, _current_transform(book, i))
		_multimesh.set_instance_color(i, look.color)
		_multimesh.set_instance_custom_data(i, look.custom)
	for j in _leaving.size():
		var leaving := _leaving[j]
		var index := books.size() + j
		_multimesh.set_instance_transform(index, _leaving_transform(leaving))
		_multimesh.set_instance_color(index, leaving.color)
		_multimesh.set_instance_custom_data(index, leaving.custom)
	set_process(not _anims.is_empty() or not _leaving.is_empty())


## Ein herausgleitendes Buch: nach vorn, dabei kleiner werdend.
func _leaving_transform(leaving: Dictionary) -> Transform3D:
	var start: Transform3D = leaving.transform
	var progress := clampf((_clock - leaving.start) / leaving.time, 0.0, 1.0)
	var eased := progress * progress
	var result := start
	result.origin += Vector3(0.0, 0.04 * eased, SLIDE_DISTANCE * eased)
	result.basis = start.basis * Basis.from_scale(Vector3.ONE * maxf(1.0 - eased, 0.001))
	return result


func _process(delta: float) -> void:
	_clock += delta
	for book: Book in _anims.keys():
		var index: int = _index.get(book, -1)
		if index < 0:
			_anims.erase(book)
			continue
		var anim: Dictionary = _anims[book]
		var finished: bool = _clock >= anim.start + anim.time
		if finished:
			_anims.erase(book)
		_multimesh.set_instance_transform(index, _current_transform(book, index))
	var leaving_done := true
	for j in _leaving.size():
		var leaving := _leaving[j]
		_multimesh.set_instance_transform(books.size() + j, _leaving_transform(leaving))
		if _clock < leaving.start + leaving.time:
			leaving_done = false
	if leaving_done and not _leaving.is_empty():
		_leaving.clear()
		_refresh_instances()
	if _anims.is_empty() and _leaving.is_empty():
		set_process(false)


# --- Schild und Hinweis ---

## Das kleine Genre-Schild vorn am Regal (Platzhalter: Brettchen mit Schrift).
func _create_sign() -> void:
	var point := get_node_or_null("SignPoint") as Node3D
	if point == null:
		return
	_sign_plate = MeshInstance3D.new()
	_sign_plate.name = "SignPlate"
	var plate := BoxMesh.new()
	plate.size = Vector3(SIGN_SIZE.x, SIGN_SIZE.y, 0.008)
	_sign_plate.mesh = plate
	var material := StandardMaterial3D.new()
	material.roughness = 0.7
	_sign_plate.material_override = material
	_sign_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	point.add_child(_sign_plate)
	_sign_label = Label3D.new()
	_sign_label.name = "SignLabel"
	_sign_label.position = Vector3(0.0, 0.0, 0.0055)
	_sign_label.double_sided = false
	_sign_label.font_size = 48
	_sign_label.outline_size = 0
	_sign_label.modulate = SIGN_TEXT_COLOR
	_sign_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	point.add_child(_sign_label)
	_update_sign()


func _update_sign() -> void:
	if _sign_plate == null:
		return
	var visible_sign := has_genre()
	_sign_plate.visible = visible_sign
	_sign_label.visible = visible_sign
	if not visible_sign:
		return
	var genre := Catalog.get_genre(genre_id)
	var color := genre.get_main_color().darkened(0.15) if genre else Color(0.42, 0.33, 0.26)
	# Helle Genre-Farben bekommen dunkle Schrift, damit man sie gut lesen kann
	_sign_label.modulate = Color(0.16, 0.12, 0.1) if color.get_luminance() > 0.55 else SIGN_TEXT_COLOR
	(_sign_plate.material_override as StandardMaterial3D).albedo_color = color
	_sign_label.text = get_genre_name()
	# Lange Namen etwas kleiner schreiben, damit sie aufs Schild passen
	var font := _sign_label.font if _sign_label.font else ThemeDB.fallback_font
	var text_width := font.get_string_size(_sign_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _sign_label.font_size).x
	_sign_label.pixel_size = minf(0.0011, SIGN_SIZE.x * 0.88 / maxf(text_width, 1.0))


## Hinweistext unten in der Bildmitte (nach "E – ").
func _update_prompt() -> void:
	if _interactable == null:
		return
	var matching := count_matching_carried() if has_genre() else 0
	if matching > 0:
		_interactable.prompt_text = "%d getragene %s einräumen" % [matching, "Buch" if matching == 1 else "Bücher"]
	elif not has_genre():
		_interactable.prompt_text = "Bücherregal einräumen"
	else:
		_interactable.prompt_text = "Regal: %s (%d %s)" % [get_genre_name(), books.size(), "Buch" if books.size() == 1 else "Bücher"]


func _on_interacted(_interactor: Node) -> void:
	# Trage ich passende Bücher, werden sie gleich eingeräumt – sonst öffnet sich das Menü
	if count_matching_carried() > 0 and put_carried() > 0:
		return
	get_tree().call_group(ShelfMenu.GROUP, "open_for", self)


# --- Hilfsfunktionen ---

## Wie viele Bücher je Genre bei einem gemischten Regal aus dem Lager kommen:
## möglichst gleichmäßig verteilt, Genre-Reihenfolge wie im Katalog.
func _mixed_shares(wanted: int) -> Dictionary:
	var shares := {}
	var open: Array[String] = []
	for genre in Catalog.get_all_genres():
		if BookStock.get_stored_count(genre.get_id()) > 0:
			open.append(genre.get_id())
			shares[genre.get_id()] = 0
	var remaining := wanted
	while remaining > 0 and not open.is_empty():
		var share := maxi(1, ceili(float(remaining) / open.size()))
		for id in open.duplicate():
			var available := BookStock.get_stored_count(id) - int(shares[id])
			var amount := mini(share, mini(available, remaining))
			shares[id] += amount
			remaining -= amount
			if available - amount <= 0:
				open.erase(id)
			if remaining <= 0:
				break
	return shares


## Bücher ins Lager – mit einem kleinen Bücherstapel je Genre in der Lager-Anzeige.
func _send_to_storage(to_store: Array) -> void:
	if to_store.is_empty():
		return
	BookStock.store_books(to_store)
	if not _is_live:
		return
	var shown := {}
	for book: Book in to_store:
		var genre := book.get_genre()
		if genre and not shown.has(genre):
			shown[genre] = true
			StorageIndicator.add_item(self, genre)


func _changed() -> void:
	_update_prompt()
	contents_changed.emit()
	if _is_live:
		SaveManager.request_save()
