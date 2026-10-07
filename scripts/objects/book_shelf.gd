class_name BookShelf
extends Node3D
## Ein Bücherregal: Bücher stehen auf Brettern (BookRow), die Rücken zeigen nach vorn.
##
## So baut man ein Bücherregal (siehe scenes/furniture/bookshelf.tscn):
## - In der Möbel-Szene einen Knoten mit diesem Script anlegen ("BookShelf").
## - Darunter für jedes Brett einen BookRow-Knoten (Reihenfolge = Reihenfolge beim Befüllen).
## - Optional ein Marker3D "SignPoint": Dort hängt das Genre-Schild (Mitte, vorn).
## - Ein Interactable "Interactable" mit Kollisionsform.
##
## Bedienung:
## - Linksklick auf ein Buch: dieses Buch in die Hand nehmen (obenauf auf den Stapel).
## - Rechtsklick, während ich Bücher trage: das Buch obenauf genau dort einstellen, wo ich
##   hinschaue – die Nachbarn rücken zur Seite (Vorschau schwebt vor dem Regal).
## - E tippen: Regal-Menü (Genre wählen, aus dem Lager auffüllen, sortieren, alles zurück
##   ins Lager).
## - E halten: alle getragenen Bücher einräumen, die hierher passen.
## Jedes Brett hat seine eigene Reihe; ist ein Brett voll, passt dort nichts mehr hinein.
##
## Leistung: Alle Bücher eines Regals werden in einem einzigen Rutsch gezeichnet
## (MultiMesh); die Buchrücken kommen aus einem gemeinsamen Bild (BookArt).
## Genre und Bücher werden mit dem Regal im Raum gespeichert (PlacedFurniture). Wird das
## Regal mit X weggeräumt, gehen die Bücher ins Lager (release_contents).

## Wird gesendet, wenn sich Bücher oder Genre ändern.
signal contents_changed

## Genre-Wert für "Gemischt": Hier passt jedes Buch hinein.
const MIXED := "mixed"
## So weit vor dem Regal beginnt ein Buch, das hineingleitet (in Metern).
const SLIDE_DISTANCE := 0.26
## So lange rücken Bücher zur Seite oder zusammen (in Sekunden).
const MOVE_TIME := 0.22
## Größe des Genre-Schilds (Breite, Höhe in Metern).
const SIGN_SIZE := Vector2(0.3, 0.075)
const SIGN_TEXT_COLOR := Color(0.98, 0.94, 0.84)
## Kleiner Abstand zwischen zwei Büchern (in Metern, dazu je Buch ein Hauch Zufall)
const BOOK_GAP := 0.0015

## Genre dieses Regals: "" = noch keins gewählt, MIXED = Gemischt, sonst die Genre-id.
var genre_id: String = ""

var _rows: Array[BookRow] = []
var _row_books: Array = []  # je Brett eine Liste von Büchern (links nach rechts)
var _targets: Dictionary = {}  # Book -> Endlage (Transform im Regal)
var _anims: Dictionary = {}  # Book -> { "from", "start", "time", "appear" }
var _leaving: Array[Dictionary] = []  # Bücher, die gerade herausgleiten
var _order: Array[Book] = []  # Reihenfolge im MultiMesh
var _index: Dictionary = {}  # Book -> Nummer im MultiMesh
var _clock := 0.0
var _multimesh: MultiMesh
var _sign_plate: MeshInstance3D
var _sign_label: Label3D
var _interactable: Interactable
var _is_live := false  # steht wirklich im Raum (nicht Vorschau oder Foto)

# Was ich gerade anschaue
var _hover_book: Book = null
## Vorschau beim Einstellen: Brett, Stelle, Buch (schwebt vor der Lücke)
var _gap_row := -1
var _gap_index := -1
var _ghost: Book = null
var _ghost_transform := Transform3D()
var _aim_problem := ""


func _ready() -> void:
	add_to_group(PlacedFurniture.CONTENTS_GROUP)
	for child in get_children():
		if child is BookRow:
			_rows.append(child)
			_row_books.append([])
	var books_instance := MultiMeshInstance3D.new()
	books_instance.name = "Books"
	_multimesh = BookLook.create_multimesh()
	books_instance.multimesh = _multimesh
	books_instance.material_override = BookLook.get_material()
	add_child(books_instance)
	_create_sign()
	set_process(false)
	# Sobald alle Buchrücken gezeichnet sind, die Bücher damit zeigen
	BookArt.atlas_ready.connect(_refresh_instances)

	_interactable = get_node_or_null("Interactable") as Interactable
	_is_live = FurnitureUtils.find_placed_furniture(self) != null
	if _is_live:
		add_to_group(BookStock.SHELF_GROUP)
		BookStock.carried_changed.connect(_on_carried_changed)
		if _interactable:
			_interactable.supports_hold = true
			_interactable.highlight_owner = false
			_interactable.interacted.connect(_on_tapped)
			_interactable.held.connect(_on_held)
			_interactable.clicked.connect(_on_clicked)
			_interactable.right_clicked.connect(_on_right_clicked)
			_interactable.aimed.connect(_on_aimed)
			_interactable.aim_ended.connect(_on_aim_ended)
	_update_prompt()


# --- Abfragen ---

## Name des Regals (aus dem Datenblatt des Möbelstücks).
func get_display_name() -> String:
	var item := FurnitureUtils.find_placed_furniture(self)
	return item.data.display_name if item and item.data else "Bücherregal"


## Alle Bücher im Regal (Brett für Brett, von links nach rechts).
func get_books() -> Array[Book]:
	var result: Array[Book] = []
	for list: Array in _row_books:
		result.append_array(list)
	return result


## Hat das Regal schon ein Genre (oder "Gemischt")?
func has_genre() -> bool:
	return not genre_id.is_empty()


## Anzeigename des Genres: "Gemischt", z. B. "Krimi" – oder "" (noch keins gewählt).
func get_genre_name() -> String:
	if genre_id == MIXED:
		return "Gemischt"
	var genre := Catalog.get_genre(genre_id)
	return genre.display_name if genre else ""


## Passt ein Buch dieses Genres hierher? ("Gemischt" und Regale ohne Genre nehmen alles.)
func accepts(book_genre_id: String) -> bool:
	return not has_genre() or genre_id == MIXED or genre_id == book_genre_id


## Wie viele Bücher dieses Genres stehen hier? (für den Bestand)
func count_books(of_genre_id: String) -> int:
	var count := 0
	for book in get_books():
		if book.genre_id == of_genre_id:
			count += 1
	return count


## Für wie viele Bücher ist ungefähr noch Platz? (Bücher sind verschieden dick.)
func get_free_estimate() -> int:
	var free_width := 0.0
	for r in _rows.size():
		free_width += maxf(_rows[r].width - _row_used(r), 0.0)
	var range_t := GameConfig.book_thickness_range
	var average := range_t.x + (range_t.y - range_t.x) / 2.4 + BOOK_GAP + 0.0015
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
	for book in get_books():
		if not accepts(book.genre_id):
			mismatched.append(book)
	remove_books(mismatched)
	_send_to_storage(mismatched)
	_update_sign()
	_changed()
	return mismatched.size()


## Stellt Bücher ins Regal: jedes auf das erste Brett, auf dem noch Platz ist (hinten an).
## Sie gleiten nacheinander hinein. Liefert die Bücher, für die kein Platz mehr war.
func add_books(new_books: Array, animate: bool = true) -> Array[Book]:
	var rest: Array[Book] = []
	var interval := 0.0
	if animate and not new_books.is_empty():
		interval = minf(GameConfig.book_slide_interval, GameConfig.book_slide_max_total / new_books.size())
	var placed := 0
	var touched := {}
	for book: Book in new_books:
		var row := _first_row_with_space(book)
		if row < 0:
			rest.append(book)
			continue
		_row_books[row].append(book)
		touched[row] = true
		_layout_row(row, false)
		if animate:
			# Startet etwas kleiner vor dem Regal und gleitet an seinen Platz
			var start: Transform3D = _targets[book]
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
	var touched := {}
	for book: Book in to_remove:
		var row := _row_of(book)
		if row < 0:
			continue
		if animate:
			_leaving.append({"transform": _current_transform(book), "color": BookLook.get_color(book),
				"book": book, "start": _clock + count * step, "time": GameConfig.book_slide_time})
			count += 1
		_row_books[row].erase(book)
		_targets.erase(book)
		_anims.erase(book)
		if book == _hover_book:
			_hover_book = null
		touched[row] = true
	for row in touched:
		_layout_row(row, animate)
	_refresh_instances()
	_changed()


## Füllt das Regal aus dem Lager: mit Büchern seines Genres – bei "Gemischt" gleichmäßig
## aus allen Genres im Lager (nach Genre gruppiert, innerhalb nach Titel sortiert).
## Liefert, wie viele es waren.
func fill_from_storage() -> int:
	if not has_genre():
		return 0
	var wanted := get_free_estimate() + 3  # ein paar mehr; was nicht passt, geht zurück
	var taken: Array[Book] = []
	if genre_id == MIXED:
		var shares := _mixed_shares(wanted)
		for id in shares:
			taken.append_array(_sorted_by_title(BookStock.take_books(id, shares[id])))
	else:
		taken = _sorted_by_title(BookStock.take_books(genre_id, wanted))
	var rest := add_books(taken)
	BookStock.put_back_first(rest)
	return taken.size() - rest.size()


## Legt alle Bücher zurück ins Lager (sie gleiten heraus). Liefert, wie viele es waren.
func return_all_to_storage() -> int:
	var all := get_books()
	remove_books(all)
	_send_to_storage(all)
	return all.size()


## Räumt die getragenen Bücher ein, die hierher passen. Was nicht passt (anderes Genre
## oder kein Platz), trage ich weiter. Liefert, wie viele eingeräumt wurden.
func put_carried() -> int:
	var taken := BookStock.take_carried("" if not has_genre() or genre_id == MIXED else genre_id)
	var rest := add_books(taken)
	BookStock.return_to_hand(rest)
	return taken.size() - rest.size()


## Sortiert alle Bücher nach Genre und Titel (die Bücher rücken sanft an ihre neuen Plätze).
func sort_books() -> void:
	var all := get_books()
	var genre_order := {}
	for genre in Catalog.get_all_genres():
		genre_order[genre.get_id()] = genre_order.size()
	all.sort_custom(func(a: Book, b: Book) -> bool:
		var ga := int(genre_order.get(a.genre_id, 999))
		var gb := int(genre_order.get(b.genre_id, 999))
		if ga != gb:
			return ga < gb
		return a.title.naturalnocasecmp_to(b.title) < 0)
	var old: Dictionary = {}
	for book in all:
		old[book] = _current_transform(book)
	for list: Array in _row_books:
		list.clear()
	var overflow: Array[Book] = []
	for book in all:
		var row := _first_row_with_space(book)
		if row < 0:
			overflow.append(book)
			continue
		_row_books[row].append(book)
	_targets.clear()
	for r in _rows.size():
		_layout_row(r, false)
	for book in _targets:
		_anims[book] = {"from": old[book], "start": _clock, "time": MOVE_TIME * 2.0, "appear": false}
	_send_to_storage(overflow)
	_refresh_instances()
	_changed()


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


## Übernimmt Genre und Bücher eines anderen Regals (nur zum Anzeigen, z. B. die Vorschau
## beim Verschieben im Gestaltungsmodus).
func copy_contents_from(other: BookShelf) -> void:
	genre_id = other.genre_id
	for r in mini(_rows.size(), other._row_books.size()):
		_row_books[r] = other._row_books[r].duplicate()
		_layout_row(r, false)
	_refresh_instances()


# --- Einzelne Bücher ---

## Nimmt ein bestimmtes Buch aus dem Regal in die Hand. Sind die Hände schon voll,
## wackelt nur kurz der Stapel (liefert dann false).
func take_book(book: Book) -> bool:
	if _row_of(book) < 0:
		return false
	if BookStock.is_hand_full():
		BookStock.show_hands_full()
		return false
	remove_books([book])
	BookStock.carry([book])
	return true


## Stellt das Buch obenauf in der Hand an eine bestimmte Stelle (Brett, Position).
## Liefert false, wenn es dort nicht hinpasst.
func insert_active_book(row: int, index: int) -> bool:
	var book := BookStock.get_active_book()
	if book == null or row < 0 or row >= _rows.size() or not accepts(book.genre_id) \
			or not _row_fits(row, _book_width(book)):
		return false
	var start: Transform3D = _ghost_transform if _ghost == book else Transform3D()
	BookStock.take_active()
	_clear_gap()
	_row_books[row].insert(clampi(index, 0, _row_books[row].size()), book)
	_layout_row(row, true)
	if start != Transform3D():
		_anims[book] = {"from": start, "start": _clock, "time": MOVE_TIME * 1.3, "appear": false}
	_refresh_instances()
	_changed()
	return true


# --- Speichern (über PlacedFurniture) ---

func get_contents_data() -> Dictionary:
	var rows := []
	for list: Array in _row_books:
		rows.append(Book.list_to_save_data(list))
	return {"genre": genre_id, "rows": rows}


func load_contents_data(data: Dictionary) -> void:
	genre_id = str(data.get("genre", ""))
	for list: Array in _row_books:
		list.clear()
	_targets.clear()
	_anims.clear()
	_leaving.clear()
	var overflow: Array[Book] = []
	var rows = data.get("rows")
	if rows is Array:
		for r in rows.size():
			for book in Book.list_from_save_data(rows[r]):
				if r < _rows.size() and _row_fits(r, _book_width(book)):
					_row_books[r].append(book)
				else:
					overflow.append(book)
		for r in _rows.size():
			_layout_row(r, false)
		_refresh_instances()
	# Ältere Spielstände: alle Bücher in einer Liste – der Reihe nach einräumen
	overflow.append_array(Book.list_from_save_data(data.get("books")))
	# Passt etwas nicht mehr (z. B. weil das Regal umgebaut wurde), kommt es ins Lager
	BookStock.store_books(add_books(overflow, false))
	_update_sign()
	_update_prompt()


## Das Regal wird weggeräumt (Taste X): Alle Bücher gehen zurück ins Lager.
func release_contents() -> void:
	var all := get_books()
	for list: Array in _row_books:
		list.clear()
	_targets.clear()
	_anims.clear()
	_send_to_storage(all)


# --- Anordnung ---

func _book_width(book: Book) -> float:
	return book.data.size.x + BOOK_GAP + _jitter(book, 8) * 0.0025


## Wie viel Breite die Bücher eines Bretts belegen.
func _row_used(row: int) -> float:
	var used := 0.0
	for book: Book in _row_books[row]:
		used += _book_width(book)
	return used


func _row_fits(row: int, width: float) -> bool:
	return _row_used(row) + width <= _rows[row].width + 0.0001


func _first_row_with_space(book: Book) -> int:
	for r in _rows.size():
		if _row_fits(r, _book_width(book)):
			return r
	return -1


func _row_of(book: Book) -> int:
	for r in _row_books.size():
		if _row_books[r].has(book):
			return r
	return -1


## Ordnet ein Brett neu an (mit Lücke für die Vorschau, falls eine offen ist).
## animate: Bücher, die ihren Platz wechseln, rücken sanft.
func _layout_row(row: int, animate: bool) -> void:
	var shelf_row := _rows[row]
	var list: Array = _row_books[row]
	var x := -shelf_row.width / 2.0
	for i in list.size() + 1:
		if row == _gap_row and i == _gap_index and _ghost:
			_ghost_transform = _book_transform(shelf_row, _ghost, x)
			_ghost_transform.origin += Vector3(0.0, 0.01, GameConfig.book_insert_preview_pull)
			x += _book_width(_ghost)
		if i >= list.size():
			break
		var book: Book = list[i]
		var target := _book_transform(shelf_row, book, x)
		if animate and _targets.has(book) and not _anims.has(book) \
				and not (_targets[book] as Transform3D).is_equal_approx(target):
			_anims[book] = {"from": _current_transform(book), "start": _clock, "time": MOVE_TIME, "appear": false}
		_targets[book] = target
		x += _book_width(book)


## Lage eines Buchs auf dem Brett: linke Kante bei x, vorn bündig (mit einem Hauch
## Abweichung), ganz leicht gedreht.
func _book_transform(row: BookRow, book: Book, x: float) -> Transform3D:
	var size := book.data.size
	var height := minf(size.y, row.height - 0.015)
	var depth := minf(size.z, row.depth - 0.01)
	var inset := _jitter(book, 16) * 0.012
	var yaw := (_jitter(book, 24) - 0.5) * deg_to_rad(1.6)
	var origin := Vector3(x + size.x / 2.0, height / 2.0, row.depth / 2.0 - depth / 2.0 - inset)
	var local := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size.x, height, depth)), origin)
	return row.transform * local


## Eine feste Zahl zwischen 0 und 1 je Exemplar (für kleine Abweichungen).
func _jitter(book: Book, shift: int) -> float:
	return float((book.look >> shift) & 255) / 255.0


# --- Zielen: welches Buch, welche Stelle? ---

## Das Buch, das der Blickstrahl (in der Welt) zuerst trifft – oder null.
func _pick_book(from: Vector3, direction: Vector3) -> Book:
	var to_local := global_transform.affine_inverse()
	var origin := to_local * from
	var dir := to_local.basis * direction
	var best: Book = null
	var best_distance := INF
	for book in _targets:
		var inverse := (_targets[book] as Transform3D).affine_inverse()
		var distance := _ray_box(inverse * origin, inverse.basis * dir)
		if distance < best_distance:
			best_distance = distance
			best = book
	return best


## Abstand, bei dem ein Strahl den Würfel -0.5 bis 0.5 trifft (INF = gar nicht).
static func _ray_box(origin: Vector3, dir: Vector3) -> float:
	var t_min := -INF
	var t_max := INF
	for axis in 3:
		if absf(dir[axis]) < 0.000001:
			if origin[axis] < -0.5 or origin[axis] > 0.5:
				return INF
			continue
		var t1 := (-0.5 - origin[axis]) / dir[axis]
		var t2 := (0.5 - origin[axis]) / dir[axis]
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
	if t_max < maxf(t_min, 0.0):
		return INF
	return maxf(t_min, 0.0)


## Wo ein Buch eingestellt würde: { "row": Brett, "index": Stelle } – leer, wenn der Blick
## kein Brett trifft. Gemessen wird an der Vorderkante der Bretter.
func _find_slot(from: Vector3, direction: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF
	for r in _rows.size():
		var row := _rows[r]
		var to_row := (global_transform * row.transform).affine_inverse()
		var origin := to_row * from
		var dir := to_row.basis * direction
		var plane_z := row.depth / 2.0 - 0.03
		if absf(dir.z) < 0.0001:
			continue
		var t := (plane_z - origin.z) / dir.z
		if t <= 0.0 or t >= best_distance:
			continue
		var hit := origin + dir * t
		if hit.y < -0.01 or hit.y > row.height or absf(hit.x) > row.width / 2.0 + 0.03:
			continue
		# Stelle: hinter allen Büchern, deren Mitte links vom Blickpunkt liegt
		var index := 0
		var x := -row.width / 2.0
		for book: Book in _row_books[r]:
			var width := _book_width(book)
			if x + width / 2.0 < hit.x:
				index += 1
			x += width
		best = {"row": r, "index": index}
		best_distance = t
	return best


func _on_aimed(from: Vector3, direction: Vector3) -> void:
	_set_hover(_pick_book(from, direction))
	var active := BookStock.get_active_book()
	if active == null or _hover_book:
		# Ein Buch angeschaut: das kann ich nehmen (Linksklick) – keine Lücke öffnen
		_clear_gap()
		_update_prompt()
		return
	var slot := _find_slot(from, direction)
	_aim_problem = ""
	if slot.is_empty():
		_clear_gap()
	elif not accepts(active.genre_id):
		_aim_problem = "„%s“ passt nicht in dieses Regal (%s)" % [active.title, get_genre_name()]
		_clear_gap()
	elif not _row_fits(slot.row, _book_width(active)):
		_aim_problem = "Auf diesem Brett ist kein Platz mehr"
		_clear_gap()
	else:
		_set_gap(slot.row, slot.index, active)
	_update_prompt()


func _on_aim_ended() -> void:
	_set_hover(null)
	_clear_gap()
	_aim_problem = ""
	_update_prompt()


## Hebt ein Buch hervor (es rutscht ein Stück heraus) und zeigt seine Infokarte.
func _set_hover(book: Book) -> void:
	if book == _hover_book:
		return
	_hover_book = book
	if book:
		BookInfoCard.show_book(self, book)
	else:
		BookInfoCard.hide_card(self)
	_update_prompt()
	_refresh_instances()


## Öffnet eine Lücke für das Buch obenauf (die Nachbarn rücken zur Seite).
func _set_gap(row: int, index: int, book: Book) -> void:
	if row == _gap_row and index == _gap_index and book == _ghost:
		return
	var old_row := _gap_row
	_gap_row = row
	_gap_index = index
	_ghost = book
	if old_row >= 0 and old_row != row:
		_layout_row(old_row, true)
	_layout_row(row, true)
	_refresh_instances()


func _clear_gap() -> void:
	if _gap_row < 0 and _ghost == null:
		return
	var old_row := _gap_row
	_gap_row = -1
	_gap_index = -1
	_ghost = null
	if old_row >= 0:
		_layout_row(old_row, true)
	_refresh_instances()


## E tippen: Regal-Menü.
func _on_tapped(_interactor: Node) -> void:
	_open_menu()


## E halten: alle getragenen Bücher einräumen, die hierher passen.
func _on_held(_interactor: Node) -> void:
	if count_matching_carried() > 0:
		put_carried()


## Linksklick: das angeschaute Buch nehmen.
func _on_clicked(_interactor: Node) -> void:
	if _hover_book:
		var book := _hover_book
		if take_book(book):
			_set_hover(null)


## Rechtsklick: das Buch obenauf an die markierte Stelle stellen.
func _on_right_clicked(_interactor: Node) -> void:
	var active := BookStock.get_active_book()
	if active and _ghost == active and _gap_row >= 0:
		insert_active_book(_gap_row, _gap_index)


func _open_menu() -> void:
	_set_hover(null)
	_clear_gap()
	get_tree().call_group(ShelfMenu.GROUP, "open_for", self)


func _on_carried_changed() -> void:
	if _ghost and not BookStock.carried.has(_ghost):
		_clear_gap()
	_update_prompt()


# --- Zeichnen und Animation ---

## Wo das Buch gerade zu sehen ist (mitten in der Animation oder an seinem Platz).
func _current_transform(book: Book) -> Transform3D:
	var target: Transform3D = _targets.get(book, Transform3D())
	if book == _hover_book and _ghost == null:
		target.origin += Vector3(0.0, 0.0, GameConfig.book_hover_pull)
	if not _anims.has(book):
		return target
	var anim: Dictionary = _anims[book]
	if _clock < anim.start:
		# Noch nicht dran: unsichtbar (Größe 0) bzw. noch am alten Platz
		return Transform3D(Basis.from_scale(Vector3.ZERO), target.origin) if anim.appear else anim.from
	var progress := clampf((_clock - anim.start) / anim.time, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	return (anim.from as Transform3D).interpolate_with(target, eased)


## Überträgt alle Bücher ins MultiMesh (Anzahl, Lage, Farbe, Buchrücken).
func _refresh_instances() -> void:
	_order = get_books()
	var count := _order.size() + _leaving.size() + (1 if _ghost else 0)
	if _multimesh.instance_count != count:
		_multimesh.instance_count = count
	_index.clear()
	for i in _order.size():
		var book := _order[i]
		_index[book] = i
		var color := BookLook.get_color(book)
		if book == _hover_book:
			color.a = 0.5  # hervorgehoben (siehe Shader)
		_multimesh.set_instance_transform(i, _current_transform(book))
		_multimesh.set_instance_color(i, color)
		_multimesh.set_instance_custom_data(i, BookLook.get_custom(book))
	for j in _leaving.size():
		var leaving := _leaving[j]
		var index := _order.size() + j
		_multimesh.set_instance_transform(index, _leaving_transform(leaving))
		_multimesh.set_instance_color(index, leaving.color)
		_multimesh.set_instance_custom_data(index, BookLook.get_custom(leaving.book))
	if _ghost:
		var index := count - 1
		var color := BookLook.get_color(_ghost)
		color.a = 0.5
		_multimesh.set_instance_transform(index, _ghost_transform)
		_multimesh.set_instance_color(index, color)
		_multimesh.set_instance_custom_data(index, BookLook.get_custom(_ghost))
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
		if _clock >= anim.start + anim.time:
			_anims.erase(book)
		_multimesh.set_instance_transform(index, _current_transform(book))
	var leaving_done := true
	for j in _leaving.size():
		var leaving := _leaving[j]
		_multimesh.set_instance_transform(_order.size() + j, _leaving_transform(leaving))
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


## Tastensymbole unter der Bildmitte (je ein kurzes Wort): Linksklick = Nehmen,
## Rechtsklick = Abstellen, E halten = Einräumen, E tippen = Menü.
func _update_prompt() -> void:
	if _interactable == null:
		return
	var matching := count_matching_carried() if _is_live else 0
	var carrying := _is_live and not BookStock.carried.is_empty()
	_interactable.supports_hold = matching > 0
	_interactable.hold_prompt_text = "Einräumen" if matching > 0 else ""
	_interactable.right_click_text = "Abstellen" if _ghost else ""
	_interactable.click_text = "Nehmen" if _hover_book else ""
	# Das Menü-Symbol nur, wenn sonst nichts zu tun ist (so bleibt es bei höchstens zwei Symbolen)
	_interactable.prompt_text = "Menü" if not carrying or (_ghost == null and matching == 0) else ""


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


static func _sorted_by_title(list: Array[Book]) -> Array[Book]:
	list.sort_custom(func(a: Book, b: Book) -> bool: return a.title.naturalnocasecmp_to(b.title) < 0)
	return list


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
