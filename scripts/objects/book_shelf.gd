class_name BookShelf
extends Node3D
## Ein Bücherregal: Bücher stehen frei auf Brettern (BookRow), die Rücken zeigen nach vorn.
##
## So baut man ein Bücherregal (siehe scenes/furniture/bookshelf.tscn):
## - In der Möbel-Szene einen Knoten mit diesem Script anlegen ("BookShelf").
## - Darunter für jedes Brett einen BookRow-Knoten (Reihenfolge = Reihenfolge beim Befüllen).
## - Ein Interactable "Interactable" – ohne eigene Kollisionsform: Man trifft das Regal über
##   seinen festen Körper (Interactable.find_for), so bleibt Deko im Regal erreichbar.
## Jedes Brett bekommt automatisch eine Ablagefläche (PlacementSurface) für kleine Deko.
##
## Jedes Buch steht an einer freien Stelle seines Bretts (linke Kante _x, feines Raster
## GameConfig.shelf_grid_step) – auch rechts beginnend, in der Mitte oder mit Lücken.
## Kommt ein Buch nah an ein anderes (GameConfig.shelf_snap_distance), rückt es bündig heran.
## Schiebe ich es zwischen zwei Bücher, rücken die Nachbarn zur Seite, wenn Platz ist.
##
## Bedienung (Bücher mit der Maus, das Menü mit R):
## - Rechtsklick auf ein Buch: dieses Buch in die Hand nehmen (obenauf auf den Stapel).
## - Linksklick, während ich Bücher trage: das Buch obenauf genau dort abstellen, wo ich
##   hinschaue. Vorher zeigt eine halbdurchsichtige Vorschau, wo es hinkommt; passt es nicht
##   (kein Platz, falsches Genre), ist die Vorschau dezent rötlich.
## - Linksklick halten (Ring): alle getragenen Bücher einräumen, die hierher passen – ab dem
##   Fach und der Stelle, auf die ich schaue; der Rest in die nächstgelegenen passenden Fächer.
## - R: Regal-Menü (Genre je Fach wählen, aus dem Lager auffüllen, sortieren, alles zurück
##   ins Lager) – eine eigene, ruhige Taste, damit sich das Menü nie aus Versehen öffnet.
## - E blättert hier (wie überall ohne eigene E-Aktion) durch die Bücher in der Hand.
## Schaue ich ein Regal an, steht sein Genre als ruhiger Schriftzug unten in der Bildmitte
## (GenreCaption) – Schilder am Regal gibt es nicht.
## Auffüllen und Sortieren füllen freie Plätze von links nach rechts, Fach für Fach.
##
## Deko im Regal: Im Gestaltungsmodus lässt sich kleine Deko auf die Bretter stellen (nur,
## was in der Höhe ins Fach passt, und nur an freie Stellen). Deko ist ein eigenes
## Möbelstück, das auf dem Regal steht (support_uid) – es wandert beim Verschieben mit und
## geht beim Wegräumen ins Inventar. Wo Deko steht, kommen keine Bücher hin; Sortieren und
## Auffüllen lassen sie stehen, wo sie ist.
##
## Leistung: Alle Bücher eines Regals werden in einem einzigen Rutsch gezeichnet
## (MultiMesh); die Buchrücken kommen aus einem gemeinsamen Bild (BookArt).
## Genre und Bücher (mit ihrer Lage) werden mit dem Regal im Raum gespeichert
## (PlacedFurniture). Wird das Regal mit X weggeräumt, gehen die Bücher ins Lager
## (release_contents).

## Wird gesendet, wenn sich Bücher oder Genre ändern.
signal contents_changed

## Genre-Wert für "Gemischt": Hier passt jedes Buch hinein.
const MIXED := "mixed"
## So weit vor dem Regal beginnt ein Buch, das hineingleitet (in Metern).
const SLIDE_DISTANCE := 0.26
## So lange rücken Bücher zur Seite oder zusammen (in Sekunden).
const MOVE_TIME := 0.22
## Kleiner Abstand zwischen zwei Büchern (in Metern, dazu je Buch ein Hauch Zufall)
const BOOK_GAP := 0.0015
## Rechenungenauigkeit beim Vergleichen von Lagen (in Metern)
const EPSILON := 0.0001
## So viel Luft bleibt zwischen Deko und Büchern (in Metern)
const DECO_MARGIN := 0.003
## Sortierarten (Kennung, Name im Menü). Neue Art: hier eintragen und in _sort_key ergänzen.
const SORT_MODES := [
	["genre_title", "Nach Genre und Titel"],
	["title", "Nach Titel"],
	["author", "Nach Autor"],
	["color", "Nach Farbe"],
]

## Von Hand gewähltes Genre je Brett (Fach), gleiche Reihenfolge wie die Bretter:
## "" = keins (nimmt alles), MIXED = Gemischt, sonst die Genre-id. Gilt nur, wenn das Fach
## nicht auf "Auto" steht (siehe row_auto).
var row_genres: Array[String] = []
## "Auto" je Fach (Standard): Das Fach nimmt jedes Buch an und übernimmt sein Genre aus den
## Büchern darin – alle gleich = dieses Genre, verschiedene = Gemischt, leer = keins.
var row_auto: Array[bool] = []
# Während des Sortierens: das Genre je Fach von vorher (siehe _placing_tier)
var _genre_snapshot: Array[String] = []
## Zuletzt gewählte Sortierart (siehe SORT_MODES), wird mit dem Regal gespeichert.
var sort_mode: String = "genre_title"
## Genre des ganzen Regals: das gemeinsame Genre aller Fächer (bei "Auto" das erkannte) – ""
## wenn sie verschieden sind (nur lesen; zum Ändern set_genre bzw. set_row_genre).
var genre_id: String:
	get:
		if _rows.is_empty():
			return ""
		var first := get_row_genre(0)
		for r in _rows.size():
			if get_row_genre(r) != first:
				return ""
		return first

var _rows: Array[BookRow] = []
var _row_books: Array = []  # je Brett die Bücher, von links nach rechts
var _x: Dictionary = {}  # Book -> linke Kante auf seinem Brett (Brettmitte = 0, in Metern)
var _targets: Dictionary = {}  # Book -> Endlage (Transform im Regal)
var _anims: Dictionary = {}  # Book -> { "from", "start", "time", "appear" }
var _leaving: Array[Dictionary] = []  # Bücher, die gerade herausgleiten
var _order: Array[Book] = []  # Reihenfolge im MultiMesh
var _index: Dictionary = {}  # Book -> Nummer im MultiMesh
var _clock := 0.0
var _multimesh: MultiMesh
var _interactable: Interactable
var _is_live := false  # steht wirklich im Raum (nicht Vorschau oder Foto)
var _room: Room = null
var _surfaces: Array[PlacementSurface] = []  # je Brett eine Ablagefläche für Deko
var _blocked_cache: Array = []  # je Brett die Bereiche mit Deko (leer = neu berechnen)

# Was ich gerade anschaue
var _hover_book: Book = null
## Wo das Buch obenauf hinkäme: { "book", "row", "left", "moves" (Book -> neue linke Kante),
## "ok" } – leer, wenn ich auf kein Brett schaue.
var _plan: Dictionary = {}
# Wohin ich gerade auf die Bretter schaue: { "row", "x" } (leer = kein Brett)
var _aim: Dictionary = {}
var _ghost: MeshInstance3D
var _ghost_material: ShaderMaterial
var _ghost_transform := Transform3D()
var _ghost_shake := -1.0
var _highlights: Dictionary = {}  # Fach -> Kasten zum Hervorheben (siehe highlight_rows)
var _highlight_tween: Tween  # Linksklick, obwohl es nicht passt: Vorschau schüttelt kurz


func _ready() -> void:
	add_to_group(PlacedFurniture.CONTENTS_GROUP)
	for child in get_children():
		if child is BookRow:
			_rows.append(child)
			_row_books.append([])
			row_genres.append("")
			row_auto.append(true)
	var books_instance := MultiMeshInstance3D.new()
	books_instance.name = "Books"
	_multimesh = BookLook.create_multimesh()
	books_instance.multimesh = _multimesh
	books_instance.material_override = BookLook.get_material()
	add_child(books_instance)
	set_process(false)
	# Sobald alle Buchrücken gezeichnet sind, die Bücher damit zeigen
	BookArt.atlas_ready.connect(_refresh_instances)

	_interactable = get_node_or_null("Interactable") as Interactable
	_is_live = FurnitureUtils.find_placed_furniture(self) != null
	if _is_live:
		add_to_group(BookStock.SHELF_GROUP)
		BookStock.carried_changed.connect(_on_carried_changed)
		_create_row_surfaces()
		_room = _find_room()
		if _room:
			# Deko aufgestellt, verschoben oder weggeräumt: Bereiche neu berechnen
			_room.layout_changed.connect(_forget_blocked)
		if _interactable:
			_interactable.highlight_owner = false
			_interactable.handles_placing = true
			_interactable.prompt_text = ""  # E blättert hier durch die Bücher in der Hand
			_interactable.menu_text = "Menü"  # R = Regal-Menü
			_interactable.menu_requested.connect(_on_menu_requested)
			_interactable.take_requested.connect(_on_take_requested)
			_interactable.place_requested.connect(_on_place_requested)
			_interactable.place_all_requested.connect(_on_place_all_requested)
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


## Hat mindestens ein Fach schon ein Genre (oder "Gemischt") – von Hand oder erkannt?
func has_genre() -> bool:
	for r in _rows.size():
		if not get_row_genre(r).is_empty():
			return true
	return false


## Anzeigename eines Genres: "Gemischt", z. B. "Krimi" – oder "" (noch keins gewählt).
static func genre_display_name(id: String) -> String:
	if id == MIXED:
		return "Gemischt"
	var genre := Catalog.get_genre(id)
	return genre.display_name if genre else ""


## Anzeigename des Genres des ganzen Regals (leer, wenn die Fächer verschieden sind).
func get_genre_name() -> String:
	return genre_display_name(genre_id)


## Wie viele Fächer (Bretter) hat das Regal?
func get_row_count() -> int:
	return _rows.size()


## Genre eines Fachs ("" = keins, MIXED = Gemischt). Bei "Auto" das aus den Büchern erkannte.
func get_row_genre(row: int) -> String:
	if row < 0 or row >= row_genres.size():
		return ""
	return detect_row_genre(row) if is_row_auto(row) else row_genres[row]


## Steht das Fach auf "Auto"?
func is_row_auto(row: int) -> bool:
	return row >= 0 and row < row_auto.size() and row_auto[row]


## Stehen alle Fächer auf "Auto"?
func is_all_auto() -> bool:
	return not row_auto.is_empty() and not row_auto.has(false)


## Das Genre, das die Bücher in diesem Fach ergeben: alle gleich = dieses Genre,
## verschiedene = MIXED, leer = "".
func detect_row_genre(row: int) -> String:
	if row < 0 or row >= _row_books.size():
		return ""
	var found := ""
	for book: Book in _row_books[row]:
		if found.is_empty():
			found = book.genre_id
		elif book.genre_id != found:
			return MIXED
	return found


## Kurzer Name eines Fachs für das Menü: "Fach 1", "Fach 2" … – durchnummeriert von oben
## links nach unten rechts (wie man liest), egal in welcher Reihenfolge die Bretter in der
## Szene stehen.
func get_row_label(row: int) -> String:
	return "Fach %d" % (get_fach_order().find(row) + 1)


## Die Fächer in Lesereihenfolge: von oben nach unten, auf gleicher Höhe von links nach rechts.
func get_fach_order() -> Array[int]:
	var order: Array[int] = []
	for r in _rows.size():
		order.append(r)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ya := snappedf(_rows[a].position.y, 0.01)
		var yb := snappedf(_rows[b].position.y, 0.01)
		if not is_equal_approx(ya, yb):
			return ya > yb
		return _rows[a].position.x < _rows[b].position.x)
	return order


## Passt ein Buch dieses Genres in dieses Fach? ("Auto", "Gemischt" und Fächer ohne Genre
## nehmen alles.)
func row_accepts(row: int, book_genre_id: String) -> bool:
	if is_row_auto(row):
		return true
	var id := get_row_genre(row)
	return id.is_empty() or id == MIXED or id == book_genre_id


## Passt ein Buch dieses Genres in irgendein Fach dieses Regals?
func accepts(book_genre_id: String) -> bool:
	for r in _rows.size():
		if row_accepts(r, book_genre_id):
			return true
	return false


## Wie viele Bücher dieses Genres stehen hier? (für den Bestand)
func count_books(of_genre_id: String) -> int:
	var count := 0
	for book in get_books():
		if book.genre_id == of_genre_id:
			count += 1
	return count


## Für wie viele Bücher ist ungefähr noch Platz (row = nur dieses Fach)? Bücher sind
## verschieden dick, daher nur ungefähr.
func get_free_estimate(only_row: int = -1) -> int:
	var free_width := 0.0
	for r in _rows.size():
		if only_row >= 0 and r != only_row:
			continue
		for segment in _segments(r):
			var used := 0.0
			for book in _books_in(r, segment):
				used += _book_width(book)
			free_width += maxf(segment.y - segment.x - used, 0.0)
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

## Gibt allen Fächern von Hand dasselbe Genre (MIXED = Gemischt; "Auto" geht aus). Bücher, die
## nicht mehr passen, gleiten heraus und gehen ins Lager. Liefert, wie viele das waren.
func set_genre(new_genre_id: String) -> int:
	for r in row_genres.size():
		row_genres[r] = new_genre_id
		row_auto[r] = false
	return _remove_mismatched()


## Wählt das Genre eines Fachs von Hand ("Auto" geht aus). Bücher dieses Fachs, die nicht mehr
## passen, gehen ins Lager. Liefert, wie viele das waren.
func set_row_genre(row: int, new_genre_id: String) -> int:
	if row < 0 or row >= row_genres.size():
		return 0
	row_genres[row] = new_genre_id
	row_auto[row] = false
	return _remove_mismatched()


## Schaltet "Auto" für ein Fach ein oder aus. Aus: Das Fach bleibt bei dem Genre, das es gerade
## hat (so ändert sich nichts Sichtbares). Bücher müssen dabei nie heraus.
func set_row_auto(row: int, auto: bool) -> void:
	if row < 0 or row >= row_auto.size() or row_auto[row] == auto:
		return
	if not auto:
		row_genres[row] = detect_row_genre(row)
	row_auto[row] = auto
	_changed()


## "Auto" für alle Fächer ein oder aus.
func set_all_auto(auto: bool) -> void:
	for r in row_auto.size():
		if row_auto[r] != auto:
			if not auto:
				row_genres[r] = detect_row_genre(r)
			row_auto[r] = auto
	_changed()


func _remove_mismatched() -> int:
	var mismatched: Array[Book] = []
	for r in _rows.size():
		for book: Book in _row_books[r]:
			if not row_accepts(r, book.genre_id):
				mismatched.append(book)
	remove_books(mismatched)
	_send_to_storage(mismatched)
	_changed()
	return mismatched.size()


## Stellt Bücher ins Regal: jedes an die erste freie Stelle eines passenden Fachs (zuerst
## Fächer mit genau seinem Genre, dann "Gemischt"; von links nach rechts – Deko bleibt, wo
## sie ist). only_row: nur in dieses Fach. Sie gleiten nacheinander hinein.
## Liefert die Bücher, für die kein Platz mehr war.
func add_books(new_books: Array, animate: bool = true, only_row: int = -1) -> Array[Book]:
	var rest: Array[Book] = []
	var interval := 0.0
	if animate and not new_books.is_empty():
		interval = minf(GameConfig.book_slide_interval, GameConfig.book_slide_max_total / new_books.size())
	var placed := 0
	for book: Book in new_books:
		var spot := _find_free_spot(book, only_row)
		if spot.is_empty():
			rest.append(book)
			continue
		_put(book, spot.row, spot.left)
		if animate:
			_slide_in(book, placed * interval)
		placed += 1
	_refresh_instances()
	if placed > 0:
		_changed()
	return rest


## Ein Buch, das gerade an seinen Platz gestellt wurde, startet etwas kleiner vor dem Regal
## und gleitet hinein (nach "delay" Sekunden).
func _slide_in(book: Book, delay: float) -> void:
	var start: Transform3D = _targets[book]
	start.basis = start.basis * Basis.from_scale(Vector3.ONE * 0.7)
	start.origin += Vector3(0.0, 0.03, SLIDE_DISTANCE)
	_anims[book] = {"from": start, "start": _clock + delay, "time": GameConfig.book_slide_time, "appear": true}


## Nimmt Bücher aus dem Regal: Sie gleiten heraus, die übrigen bleiben stehen, wo sie sind.
## (Wohin die Bücher danach gehen, entscheidet der Aufrufer.)
func remove_books(to_remove: Array, animate: bool = true) -> void:
	if to_remove.is_empty():
		return
	var step := minf(GameConfig.book_slide_interval, GameConfig.book_slide_max_total / to_remove.size()) * 0.6
	var count := 0
	for book: Book in to_remove:
		var row := _row_of(book)
		if row < 0:
			continue
		if animate:
			_leaving.append({"transform": _current_transform(book), "color": BookLook.get_color(book),
				"book": book, "start": _clock + count * step, "time": GameConfig.book_slide_time})
			count += 1
		_row_books[row].erase(book)
		_x.erase(book)
		_targets.erase(book)
		_anims.erase(book)
		if book == _hover_book:
			_hover_book = null
			BookInfoCard.hide_card(self)
	_refresh_instances()
	_changed()


## Füllt das Regal aus dem Lager, Fach für Fach: jede mit Büchern ihres Genres (bei "Auto" das
## erkannte) – "Gemischt" gleichmäßig aus allen Genres im Lager bzw. bei "Auto" aus den Genres,
## die schon darin stehen (nach Genre gruppiert, innerhalb nach Titel sortiert). Fächer ohne
## Genre (auch leere "Auto"-Fächer) bleiben leer. Liefert, wie viele es waren.
func fill_from_storage() -> int:
	var count := 0
	# Erst die Fächer mit festem Genre, dann die gemischten
	for pass_mixed in [false, true]:
		for r in _rows.size():
			var id := get_row_genre(r)
			if id.is_empty() or (id == MIXED) != pass_mixed:
				continue
			var wanted := get_free_estimate(r) + 2  # ein paar mehr; was nicht passt, geht zurück
			if wanted <= 2:
				continue
			var taken: Array[Book] = []
			if id == MIXED:
				# "Auto" und gemischt: nur mit den Genres, die schon darin stehen
				var shares := _mixed_shares(wanted, genres_in_row(r) if is_row_auto(r) else [])
				for genre in shares:
					taken.append_array(_sorted_by_title(BookStock.take_books(genre, shares[genre])))
			else:
				taken = _sorted_by_title(BookStock.take_books(id, wanted))
			var rest := add_books(taken, true, r)
			BookStock.put_back_first(rest)
			count += taken.size() - rest.size()
	return count


## Legt alle Bücher zurück ins Lager (sie gleiten heraus). Liefert, wie viele es waren.
func return_all_to_storage() -> int:
	var all := get_books()
	remove_books(all)
	_send_to_storage(all)
	return all.size()


## Räumt die getragenen Bücher ein, die hierher passen. Was nicht passt (anderes Genre
## oder kein Platz), trage ich weiter. Liefert, wie viele eingeräumt wurden.
func put_carried() -> int:
	var taken := BookStock.take_carried_where(func(book: Book) -> bool: return accepts(book.genre_id))
	var rest := add_books(taken)
	BookStock.return_to_hand(rest)
	return taken.size() - rest.size()


## Linksklick halten: Räumt die getragenen Bücher ab der Stelle ein, auf die ich schaue
## (Fach "row", Stelle aim_x, Brettmitte = 0). Von dort füllen sie die freien Plätze dieses
## Fachs – erst nach rechts, dann nach links. Was dort nicht hinpasst (Platz oder Genre), kommt
## in die nächstgelegenen anderen Fächer mit passendem Genre; was nirgends passt, trage ich
## weiter. Liefert, wie viele eingeräumt wurden.
func put_carried_at(row: int, aim_x: float) -> int:
	if row < 0 or row >= _rows.size():
		return put_carried()
	var taken := BookStock.take_carried_where(func(book: Book) -> bool: return accepts(book.genre_id))
	if taken.is_empty():
		return 0
	var others := _rows_by_distance(row)
	var interval := minf(GameConfig.book_slide_interval, GameConfig.book_slide_max_total / taken.size())
	var start := NAN  # Startstelle im angeschauten Fach (linke Kante des ersten Buchs)
	var rest: Array[Book] = []
	var placed := 0
	for book in taken:
		var spot := {}
		if row_accepts(row, book.genre_id):
			if is_nan(start):
				start = _start_at(row, aim_x, _book_width(book))
			spot = _spot_near(row, book, start)
		for tier in 3:
			for r in others:
				if not spot.is_empty():
					break
				if row_accepts(r, book.genre_id) and _placing_tier(r, book.genre_id) == tier:
					spot = _find_free_spot(book, r)
		if spot.is_empty():
			rest.append(book)
			continue
		_put(book, spot.row, spot.left)
		_slide_in(book, placed * interval)
		placed += 1
	_refresh_instances()
	if placed > 0:
		_changed()
	BookStock.return_to_hand(rest)
	return placed


## Die anderen Fächer, das nächstgelegene zuerst (gemessen von Brettmitte zu Brettmitte;
## bei gleichem Abstand zuerst das in Lesereihenfolge frühere).
func _rows_by_distance(row: int) -> Array[int]:
	var order := get_fach_order()
	var result: Array[int] = []
	for r in order:
		if r != row:
			result.append(r)
	var here := _rows[row].position
	result.sort_custom(func(a: int, b: int) -> bool:
		var da := _rows[a].position.distance_to(here)
		var db := _rows[b].position.distance_to(here)
		if not is_equal_approx(da, db):
			return da < db
		return order.find(a) < order.find(b))
	return result


## Wo das erste Buch beim Einräumen ab aim_x beginnt: auf dem feinen Raster, nah am linken
## Nachbarn bündig, und so weit innen, dass es in die freie Lücke passt.
func _start_at(row: int, aim_x: float, width: float) -> float:
	var start := snappedf(aim_x - width / 2.0, maxf(GameConfig.shelf_grid_step, 0.001))
	for gap in _free_gaps(row):
		if start + width / 2.0 >= gap.x - EPSILON and start + width / 2.0 <= gap.y + EPSILON:
			if start - gap.x <= GameConfig.shelf_snap_distance:
				start = gap.x
			if gap.y - gap.x >= width - EPSILON:
				start = clampf(start, gap.x, gap.y - width)
	return start


## Freier Platz für ein Buch in diesem Fach, möglichst nah an "start": zuerst rechts davon
## (nächste freie Stelle), wenn rechts nichts mehr frei ist, links davon (bündig von rechts).
func _spot_near(row: int, book: Book, start: float) -> Dictionary:
	var width := _book_width(book)
	var best_right := INF
	var best_left := -INF
	for gap in _free_gaps(row):
		if gap.y - gap.x < width - EPSILON:
			continue
		var right := maxf(gap.x, start)
		if right + width <= gap.y + EPSILON:
			best_right = minf(best_right, right)
		var left := minf(gap.y, start) - width
		if left >= gap.x - EPSILON:
			best_left = maxf(best_left, left)
	if best_right < INF:
		return {"row": row, "left": best_right}
	if best_left > -INF:
		return {"row": row, "left": best_left}
	return {}


## Die freien Lücken eines Fachs (von, bis), ohne Deko und ohne Bücher.
func _free_gaps(row: int) -> Array[Vector2]:
	var gaps: Array[Vector2] = []
	for segment in _segments(row):
		var cursor := segment.x
		for other in _books_in(row, segment):
			if _x[other] > cursor + EPSILON:
				gaps.append(Vector2(cursor, _x[other]))
			cursor = maxf(cursor, _x[other] + _book_width(other))
		if segment.y > cursor + EPSILON:
			gaps.append(Vector2(cursor, segment.y))
	return gaps


## Sortiert die Bücher (mode: siehe SORT_MODES; leer = zuletzt gewählte Art) – sie rücken
## sanft an ihre neuen Plätze, von links nach rechts ohne Lücken, jedes in ein Fach mit
## passendem Genre. Deko bleibt stehen, wo sie ist. Die Art wird gemerkt.
func sort_books(mode: String = "") -> void:
	if not mode.is_empty() and SORT_MODES.any(func(entry: Array) -> bool: return entry[0] == mode):
		sort_mode = mode
	var all := get_books()
	var keys := {}
	for book in all:
		keys[book] = _sort_key(book)
	all.sort_custom(func(a: Book, b: Book) -> bool:
		var ka: Array = keys[a]
		var kb: Array = keys[b]
		for i in ka.size():
			if ka[i] is String:
				var order := (ka[i] as String).naturalnocasecmp_to(kb[i])
				if order != 0:
					return order < 0
			elif ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	var old: Dictionary = {}
	for book in all:
		old[book] = _current_transform(book)
	# Auto-Fächer behalten beim Sortieren ihr Genre (sonst wären sie kurz alle leer und alles
	# käme durcheinander)
	_genre_snapshot.clear()
	for r in _rows.size():
		_genre_snapshot.append(get_row_genre(r))
	_clear_rows()
	var overflow: Array[Book] = []
	for book in all:
		var spot := _find_free_spot(book)
		if spot.is_empty():
			overflow.append(book)
			continue
		_put(book, spot.row, spot.left)
	_genre_snapshot.clear()
	for book in _targets:
		_anims[book] = {"from": old[book], "start": _clock, "time": MOVE_TIME * 2.0, "appear": false}
	_send_to_storage(overflow)
	_refresh_instances()
	_changed()


## Wonach ein Buch bei der aktuellen Sortierart eingeordnet wird (Liste: erst nach dem ersten
## Wert, bei Gleichstand nach dem nächsten).
func _sort_key(book: Book) -> Array:
	match sort_mode:
		"title":
			return [book.title, book.data.author]
		"author":
			# Nach Nachnamen (wie in Büchereien), dann Vorname und Titel
			var names := book.data.author.split(" ", false)
			var surname: String = names[-1] if not names.is_empty() else ""
			return [surname, book.data.author, book.title]
		"color":
			# Nach Farbton im Farbkreis; fast graue Einbände (Schwarz, Weiß, Grau) ans Ende,
			# von dunkel nach hell
			var color := BookLook.get_color(book)
			var hue := color.h if color.s >= 0.15 else 2.0 + color.v
			return [snappedf(hue, 0.001), book.title]
		_:
			return [_genre_rank(book.genre_id), book.title]


func _genre_rank(id: String) -> int:
	var rank := 0
	for genre in Catalog.get_all_genres():
		if genre.get_id() == id:
			return rank
		rank += 1
	return 999


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
	for r in mini(row_genres.size(), other.row_genres.size()):
		row_genres[r] = other.row_genres[r]
		row_auto[r] = other.row_auto[r]
	sort_mode = other.sort_mode
	_clear_rows()
	for r in mini(_rows.size(), other._row_books.size()):
		for book: Book in other._row_books[r]:
			_put(book, r, other._x[book])
	_refresh_instances()


# --- Fach hervorheben (Regal-Menü) ---

## Hebt diese Fächer dezent hervor (leere Liste = keins). Die Kästen entstehen erst, wenn sie
## gebraucht werden, und blenden sanft ein.
func highlight_rows(rows: Array[int]) -> void:
	var was_visible: Array[int] = []
	var newly: Array[int] = []
	for r in _highlights:
		if (_highlights[r] as MeshInstance3D).visible:
			was_visible.append(r)
	for r in _highlights:
		(_highlights[r] as MeshInstance3D).visible = rows.has(r)
	var shown := false
	for r in rows:
		if r < 0 or r >= _rows.size():
			continue
		if not _highlights.has(r):
			_highlights[r] = _create_highlight(_rows[r])
		var box: MeshInstance3D = _highlights[r]
		if not was_visible.has(r):
			newly.append(r)  # nur neu hinzukommende blenden ein (kein Flackern)
		box.visible = true
		shown = true
	if shown and not newly.is_empty():
		if _highlight_tween:
			_highlight_tween.kill()
		# Was schon leuchtet, bleibt ganz hell; nur Neues blendet sanft ein
		for r in _highlights:
			(_highlights[r].material_override as ShaderMaterial).set_shader_parameter("strength",
				0.0 if newly.has(r) else 1.0)
		_highlight_tween = create_tween()
		_highlight_tween.tween_method(func(value: float) -> void:
			for r in newly:
				(_highlights[r].material_override as ShaderMaterial).set_shader_parameter("strength", value),
			0.0, 1.0, 0.12)


func _create_highlight(row: BookRow) -> MeshInstance3D:
	var size := Vector3(row.width + 0.012, maxf(row.height - 0.008, 0.02), row.depth + 0.012)
	var box := MeshInstance3D.new()
	box.name = "FachHighlight"
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/fach_highlight.gdshader")
	material.set_shader_parameter("half_size", size / 2.0)
	material.set_shader_parameter("fill", GameConfig.fach_highlight_fill)
	material.set_shader_parameter("edge", GameConfig.fach_highlight_edge)
	box.material_override = material
	box.transform = row.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, size.y / 2.0 + 0.004, 0.0))
	box.visible = false
	add_child(box)
	return box


# --- Deko im Regal ---

## Das Bücherregal, zu dem eine Ablagefläche gehört (ein Brett) – oder null.
static func find_for_surface(surface: Node) -> BookShelf:
	var row := surface.get_parent() if surface else null
	if row is BookRow and row.get_parent() is BookShelf:
		return row.get_parent()
	return null


## Gestaltungsmodus: Darf Deko mit diesen Eckpunkten (in der Welt) auf diesem Brett stehen?
## Nur, wenn dort keine Bücher stehen.
func is_free_for_deco(surface: PlacementSurface, corners: PackedVector3Array) -> bool:
	var row := _surfaces.find(surface)
	if row < 0:
		return true
	var span := _span_on_row(row, corners)
	span = Vector2(span.x - DECO_MARGIN, span.y + DECO_MARGIN)
	for book: Book in _row_books[row]:
		if span.x < _x[book] + _book_width(book) - EPSILON and span.y > _x[book] + EPSILON:
			return false
	return true


## Jedes Brett bekommt eine Ablagefläche für Deko (so hoch, wie das Fach Platz bietet).
func _create_row_surfaces() -> void:
	for row in _rows:
		var surface := PlacementSurface.new()
		surface.name = "DecoSurface"
		surface.max_height = row.height
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(row.width, 0.03, row.depth)
		shape.shape = box
		surface.add_child(shape)
		row.add_child(surface)
		_surfaces.append(surface)


func _find_room() -> Room:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	return node as Room


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


## Stellt das Buch obenauf in der Hand dorthin, wo die Vorschau gerade steht.
## Liefert false, wenn es dort nicht hinpasst.
func place_active_book() -> bool:
	if _plan.is_empty() or not _plan.ok or _plan.book != BookStock.get_active_book():
		return false
	var row: int = _plan.row
	var moves: Dictionary = _plan.moves
	var left: float = _plan.left
	var start := _ghost_transform
	_set_plan({})
	var book := BookStock.take_active()
	# Die Nachbarn rücken zur Seite, das Buch gleitet von der Vorschau an seinen Platz
	for other: Book in moves:
		_x[other] = moves[other]
		_layout_book(other, true)
	_put(book, row, left)
	_anims[book] = {"from": start, "start": _clock, "time": MOVE_TIME * 1.3, "appear": false}
	_refresh_instances()
	_changed()
	return true


## Stellt das Buch obenauf an eine bestimmte Stelle: Brett und Lage entlang des Bretts
## (Mitte des Buchs, Brettmitte = 0). Für Tests und spätere Besucher.
func place_active_book_at(row: int, center_x: float) -> bool:
	var book := BookStock.get_active_book()
	if book == null or row < 0 or row >= _rows.size():
		return false
	_set_plan(_plan_for(row, book, center_x))
	return place_active_book()


# --- Speichern (über PlacedFurniture) ---

func get_contents_data() -> Dictionary:
	var rows := []
	for list: Array in _row_books:
		var saved := []
		for book: Book in list:
			var entry := book.to_save_data()
			entry["x"] = snappedf(_x[book], 0.0001)
			saved.append(entry)
		rows.append(saved)
	# "genre" bleibt für ältere Spielversionen mit drin (gemeinsames Genre oder "")
	return {"genre": genre_id, "row_genres": row_genres.duplicate(), "row_auto": row_auto.duplicate(),
		"rows": rows, "sort": sort_mode}


func load_contents_data(data: Dictionary) -> void:
	# Genre je Fach – ältere Spielstände kennen nur ein Genre für das ganze Regal
	var saved_rows = data.get("row_genres")
	var saved_auto = data.get("row_auto")
	for r in row_genres.size():
		if saved_rows is Array and r < saved_rows.size():
			row_genres[r] = str(saved_rows[r])
		elif saved_rows is Array:
			row_genres[r] = ""  # ein Fach, das es beim Speichern noch nicht gab: Auto
		else:
			row_genres[r] = str(data.get("genre", ""))
		# "Auto" – ältere Spielstände kennen es nicht: Fächer ohne Genre gelten als "Auto",
		# Fächer mit gewähltem Genre bleiben dabei
		if saved_auto is Array and r < saved_auto.size():
			row_auto[r] = bool(saved_auto[r])
		else:
			row_auto[r] = row_genres[r].is_empty()
	# Sortierart – ältere Spielstände kennen sie nicht (dann wie früher: Genre und Titel)
	var saved_sort := str(data.get("sort", "genre_title"))
	sort_mode = saved_sort if SORT_MODES.any(func(entry: Array) -> bool: return entry[0] == saved_sort) \
		else "genre_title"
	_clear_rows()
	_anims.clear()
	_leaving.clear()
	var overflow: Array[Book] = []
	var rows = data.get("rows")
	if rows is Array:
		for r in rows.size():
			if not rows[r] is Array:
				continue
			# Ältere Spielstände (ohne Lage "x"): dicht an dicht von links
			var cursor := -INF
			for entry in rows[r]:
				var book := Book.from_save_data(entry)
				if book == null:
					continue
				if r >= _rows.size():
					overflow.append(book)
					continue
				var left := maxf(cursor, -_rows[r].width / 2.0)
				if entry is Dictionary and entry.has("x"):
					left = float(entry["x"])
				if _fits_at(r, book, left):
					_put(book, r, left)
					cursor = left + _book_width(book)
				else:
					overflow.append(book)
		_refresh_instances()
	# Ältere Spielstände: alle Bücher in einer Liste – der Reihe nach einräumen
	overflow.append_array(Book.list_from_save_data(data.get("books")))
	# Passt etwas nicht mehr (z. B. weil das Regal umgebaut wurde), kommt es an eine
	# andere freie Stelle – oder ins Lager
	BookStock.store_books(add_books(overflow, false))
	_update_prompt()


## Das Regal wird weggeräumt (Taste X): Alle Bücher gehen zurück ins Lager.
func release_contents() -> void:
	var all := get_books()
	_clear_rows()
	_anims.clear()
	_send_to_storage(all)


# --- Anordnung ---

## Platz, den ein Buch auf dem Brett braucht (Dicke und ein Hauch Luft).
func _book_width(book: Book) -> float:
	return book.data.size.x + BOOK_GAP + _jitter(book, 8) * 0.0025


## Stellt ein Buch auf ein Brett (linke Kante "left") – ohne Animation.
func _put(book: Book, row: int, left: float) -> void:
	_x[book] = left
	var list: Array = _row_books[row]
	var index := 0
	while index < list.size() and _x[list[index]] < left:
		index += 1
	list.insert(index, book)
	_targets[book] = _book_transform(_rows[row], book, left)


## Neue Endlage eines Buchs nach einer Verschiebung (animate: sanft hinrücken).
func _layout_book(book: Book, animate: bool) -> void:
	var row := _row_of(book)
	if row < 0:
		return
	var list: Array = _row_books[row]
	list.sort_custom(func(a: Book, b: Book) -> bool: return _x[a] < _x[b])
	var target := _book_transform(_rows[row], book, _x[book])
	if animate and _targets.has(book) and not (_targets[book] as Transform3D).is_equal_approx(target):
		_anims[book] = {"from": _current_transform(book), "start": _clock, "time": MOVE_TIME, "appear": false}
	_targets[book] = target


func _clear_rows() -> void:
	for list: Array in _row_books:
		list.clear()
	_x.clear()
	_targets.clear()


func _row_of(book: Book) -> int:
	for r in _row_books.size():
		if _row_books[r].has(book):
			return r
	return -1


## Bereiche eines Bretts, auf denen Deko steht (von, bis) – dort kommen keine Bücher hin.
func _get_blocked(row: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not _is_live:
		return result
	if _blocked_cache.is_empty():
		_update_blocked()
	result.assign(_blocked_cache[row])
	return result


## Sucht die Deko auf den Brettern: alles, was im Raum auf diesem Regal steht.
func _update_blocked() -> void:
	_blocked_cache.clear()
	for r in _rows.size():
		_blocked_cache.append([])
	var item := FurnitureUtils.find_placed_furniture(self)
	if item == null or _room == null:
		return
	for other in _room.get_dependents(item):
		var row := _row_at(other.global_position)
		if row < 0 or other.get_model() == null:
			continue
		var span := _span_on_row(row, _corners_of(other.get_model()))
		_blocked_cache[row].append(Vector2(span.x - DECO_MARGIN, span.y + DECO_MARGIN))


func _forget_blocked() -> void:
	_blocked_cache.clear()


## Auf welchem Brett steht dieser Punkt (in der Welt)? -1 = auf keinem.
func _row_at(world_position: Vector3) -> int:
	for r in _rows.size():
		var row := _rows[r]
		var local := row.global_transform.affine_inverse() * world_position
		if absf(local.y) < 0.03 and absf(local.x) <= row.width / 2.0 + 0.05 and absf(local.z) <= row.depth / 2.0 + 0.05:
			return r
	return -1


## Von wo bis wo (entlang des Bretts, Brettmitte = 0) reichen diese Punkte (in der Welt)?
func _span_on_row(row: int, corners: PackedVector3Array) -> Vector2:
	var to_row := _rows[row].global_transform.affine_inverse()
	var span := Vector2(INF, -INF)
	for corner in corners:
		var x := (to_row * corner).x
		span = Vector2(minf(span.x, x), maxf(span.y, x))
	return span


## Die acht Ecken des umgebenden Quaders eines Modells (in der Welt).
static func _corners_of(model: Node3D) -> PackedVector3Array:
	var box := FurnitureUtils.get_local_aabb(model)
	var corners := PackedVector3Array()
	for i in 8:
		corners.append(model.global_transform * box.get_endpoint(i))
	return corners


## Die freien Abschnitte eines Bretts zwischen Seitenwänden und Deko, als (von, bis).
func _segments(row: int) -> Array[Vector2]:
	var half := _rows[row].width / 2.0
	var result: Array[Vector2] = []
	var start := -half
	var blocked := _get_blocked(row)
	blocked.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for interval in blocked:
		if interval.x > start + EPSILON:
			result.append(Vector2(start, minf(interval.x, half)))
		start = maxf(start, interval.y)
	if half > start + EPSILON:
		result.append(Vector2(start, half))
	return result


## Die Bücher, die in diesem Abschnitt stehen (von links nach rechts).
func _books_in(row: int, segment: Vector2) -> Array[Book]:
	var result: Array[Book] = []
	for book: Book in _row_books[row]:
		var center: float = _x[book] + _book_width(book) / 2.0
		if center >= segment.x and center <= segment.y:
			result.append(book)
	return result


## Passt das Buch genau an diese Stelle, ohne etwas zu überschneiden?
func _fits_at(row: int, book: Book, left: float) -> bool:
	var right := left + _book_width(book)
	var inside := false
	for segment in _segments(row):
		if left >= segment.x - EPSILON and right <= segment.y + EPSILON:
			inside = true
	if not inside:
		return false
	for other: Book in _row_books[row]:
		if other != book and left < _x[other] + _book_width(other) - EPSILON and right > _x[other] + EPSILON:
			return false
	return true


## Reihenfolge beim Einräumen: 0 = Fach mit genau diesem Genre, 1 = gemischt oder noch ohne
## Genre, 2 = Auto-Fach mit einem anderen Genre (das danach "Gemischt" wird).
func _placing_tier(row: int, book_genre_id: String) -> int:
	var id: String = _genre_snapshot[row] if row < _genre_snapshot.size() else get_row_genre(row)
	if id == book_genre_id:
		return 0
	return 1 if id.is_empty() or id == MIXED else 2


## Erste freie Stelle für ein Buch: zuerst in Fächern mit genau seinem Genre, dann in
## gemischten (bzw. noch ohne Genre), zuletzt in Auto-Fächern mit anderem Genre; Brett für Brett, in jedem Abschnitt von links nach
## rechts, bündig an den Nachbarn links. only_row: nur dieses Fach. Leer, wenn es nirgends passt.
func _find_free_spot(book: Book, only_row: int = -1) -> Dictionary:
	var width := _book_width(book)
	var rows: Array[int] = []
	for tier in 3:
		for r in _rows.size():
			if (only_row < 0 or r == only_row) and row_accepts(r, book.genre_id) \
					and _placing_tier(r, book.genre_id) == tier:
				rows.append(r)
	for r in rows:
		for segment in _segments(r):
			var cursor := segment.x
			for other in _books_in(r, segment):
				if _x[other] - cursor >= width - EPSILON:
					return {"row": r, "left": cursor}
				cursor = maxf(cursor, _x[other] + _book_width(other))
			if segment.y - cursor >= width - EPSILON:
				return {"row": r, "left": cursor}
	return {}


## Wohin ein Buch käme, wenn ich es an die Stelle aim_x (Brettmitte = 0) stelle:
## auf das feine Raster, nah an einem Nachbarn bündig, und zwischen anderen Büchern so,
## dass die Nachbarn nur so weit wie nötig zur Seite rücken.
func _plan_for(row: int, book: Book, aim_x: float) -> Dictionary:
	var width := _book_width(book)
	var step := maxf(GameConfig.shelf_grid_step, 0.001)
	var desired := snappedf(aim_x - width / 2.0, step)
	var plan := {"book": book, "row": row, "left": desired, "moves": {}, "ok": false}
	var segment := _segment_near(row, aim_x)
	if segment == Vector2.ZERO:
		return plan
	plan.left = clampf(desired, segment.x, maxf(segment.x, segment.y - width))
	if not row_accepts(row, book.genre_id):
		return plan
	var books := _books_in(row, segment)
	var used := 0.0
	for other in books:
		used += _book_width(other)
	if used + width > segment.y - segment.x + EPSILON:
		return plan  # in diesem Abschnitt ist kein Platz mehr
	# Nachbarn links und rechts der gewünschten Stelle
	var center := desired + width / 2.0
	var left_books: Array[Book] = []
	var right_books: Array[Book] = []
	var left_width := 0.0
	var right_width := 0.0
	for other in books:
		if _x[other] + _book_width(other) / 2.0 < center:
			left_books.append(other)
			left_width += _book_width(other)
		else:
			right_books.append(other)
			right_width += _book_width(other)
	# So weit innen bleiben, dass die Nachbarn zur Seite rücken können
	var left := clampf(desired, segment.x + left_width, segment.y - right_width - width)
	# Einrasten: Steht das Buch frei, aber nah an einem Nachbarn oder Rand, rückt es heran
	var previous_edge := segment.x
	if not left_books.is_empty():
		previous_edge = _x[left_books[-1]] + _book_width(left_books[-1])
	var next_edge := segment.y
	if not right_books.is_empty():
		next_edge = _x[right_books[0]]
	if left >= previous_edge - EPSILON and left + width <= next_edge + EPSILON:
		var gap_left := left - previous_edge
		var gap_right := next_edge - (left + width)
		if gap_left <= GameConfig.shelf_snap_distance and gap_left <= gap_right:
			left = previous_edge
		elif gap_right <= GameConfig.shelf_snap_distance:
			left = next_edge - width
	# Nachbarn nur so weit zur Seite schieben wie nötig
	var moves := {}
	var limit := left + width
	for other in right_books:
		if _x[other] >= limit - EPSILON:
			break
		moves[other] = limit
		limit += _book_width(other)
	limit = left
	for i in range(left_books.size() - 1, -1, -1):
		var other := left_books[i]
		var other_width := _book_width(other)
		if _x[other] + other_width <= limit + EPSILON:
			break
		moves[other] = limit - other_width
		limit -= other_width
	plan.left = left
	plan.moves = moves
	plan.ok = true
	return plan


## Der freie Abschnitt, in dem die Stelle x liegt (oder der nächste) – ZERO, wenn es keinen gibt.
func _segment_near(row: int, x: float) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for segment in _segments(row):
		var distance := 0.0
		if x < segment.x:
			distance = segment.x - x
		elif x > segment.y:
			distance = x - segment.y
		if distance < best_distance:
			best_distance = distance
			best = segment
	return best


## Lage eines Buchs auf dem Brett: linke Kante bei left, vorn bündig (mit einem Hauch
## Abweichung), ganz leicht gedreht.
func _book_transform(row: BookRow, book: Book, left: float) -> Transform3D:
	var size := book.data.size
	var height := minf(size.y, row.height - 0.015)
	var depth := minf(size.z, row.depth - 0.01)
	var inset := _jitter(book, 16) * 0.012
	var yaw := (_jitter(book, 24) - 0.5) * deg_to_rad(1.6)
	var origin := Vector3(left + size.x / 2.0, height / 2.0, row.depth / 2.0 - depth / 2.0 - inset)
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


## Wohin ich auf den Brettern schaue: { "row": Brett, "x": Stelle (Brettmitte = 0) } –
## leer, wenn der Blick kein Brett trifft. Gemessen wird kurz hinter der Vorderkante.
func _find_aim(from: Vector3, direction: Vector3) -> Dictionary:
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
		best = {"row": r, "x": clampf(hit.x, -row.width / 2.0, row.width / 2.0)}
		best_distance = t
	return best


func _on_aimed(from: Vector3, direction: Vector3) -> void:
	_set_hover(_pick_book(from, direction))
	var aim := _find_aim(from, direction)
	_aim = aim
	# Schriftzug: Genre des Fachs, auf das ich schaue (bzw. des angeschauten Buchs)
	var row: int = _row_of(_hover_book) if _hover_book else aim.get("row", -1)
	var row_genre := get_row_genre(row)
	if row_genre.is_empty():
		GenreCaption.hide_text(self)
	else:
		GenreCaption.show_text(self, genre_display_name(row_genre))
	var active := BookStock.get_active_book()
	_set_plan({} if aim.is_empty() or active == null else _plan_for(aim.row, active, aim.x))
	_update_prompt()


func _on_aim_ended() -> void:
	_aim = {}
	GenreCaption.hide_text(self)
	_set_hover(null)
	_set_plan({})
	_update_prompt()


## Hebt ein Buch hervor (es leuchtet leicht und rutscht ein Stück heraus) und zeigt
## seine Infokarte.
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


## Zeigt die halbdurchsichtige Vorschau dort, wo das Buch obenauf hinkäme (rötlich, wenn es
## nicht passt). Muss es zwischen andere geschoben werden, schwebt sie ein Stück davor.
func _set_plan(plan: Dictionary) -> void:
	var old_book: Book = _plan.get("book")
	var old_ok: bool = _plan.get("ok", false)
	var had_moves: bool = not (_plan.get("moves", {}) as Dictionary).is_empty()
	_plan = plan
	if plan.is_empty():
		if _ghost:
			_ghost.visible = false
		if old_book:
			_refresh_instances()  # angeschautes Buch wieder herausrutschen lassen
		return
	if _ghost == null:
		_create_ghost()
	var book: Book = plan.book
	var row := _rows[plan.row]
	var has_moves := not (plan.moves as Dictionary).is_empty()
	_ghost_transform = _book_transform(row, book, plan.left)
	if not plan.ok or has_moves:
		_ghost_transform.origin += Vector3(0.0, 0.01, GameConfig.book_insert_preview_pull)
	else:
		_ghost_transform.origin += Vector3(0.0, 0.0, 0.002)
	if book != old_book or plan.ok != old_ok or not _ghost.visible:
		FurnitureUtils.set_blueprint_valid(_ghost_material, plan.ok)
	_ghost.transform = _ghost_transform
	_ghost.visible = true
	if old_book == null or has_moves != had_moves:
		_refresh_instances()


func _create_ghost() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.name = "Preview"
	_ghost.mesh = BookLook.get_mesh()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_material = FurnitureUtils.make_blueprint_material(true)
	_ghost.material_override = _ghost_material
	add_child(_ghost)


## R: Regal-Menü.
func _on_menu_requested(_interactor: Node) -> void:
	open_menu()


## Buch nehmen (rechte Maustaste): das angeschaute Buch.
func _on_take_requested(_interactor: Node) -> void:
	if _hover_book:
		take_book(_hover_book)


## Buch ablegen (linke Maustaste kurz): das Buch obenauf dorthin stellen, wo die Vorschau
## steht. Passt es nicht, schüttelt sich die Vorschau kurz (ohne Text).
func _on_place_requested(_interactor: Node) -> void:
	if _plan.is_empty():
		return
	if not place_active_book():
		_ghost_shake = 0.0
		set_process(true)


## Linke Maustaste gehalten: alle getragenen Bücher einräumen, die hierher passen – ab dem
## Fach und der Stelle, auf die ich schaue.
func _on_place_all_requested(_interactor: Node) -> void:
	if count_matching_carried() > 0:
		if _aim.is_empty():
			put_carried()
		else:
			put_carried_at(_aim.row, _aim.x)


## Öffnet das Regal-Menü für dieses Regal (R – auch, wenn ich Deko darin anschaue).
func open_menu() -> void:
	_set_hover(null)
	_set_plan({})
	get_tree().call_group(ShelfMenu.GROUP, "open_for", self)


func _on_carried_changed() -> void:
	if not _plan.is_empty() and _plan.book != BookStock.get_active_book():
		_set_plan({})
	_update_prompt()


# --- Zeichnen und Animation ---

## Wo das Buch gerade zu sehen ist (mitten in der Animation oder an seinem Platz).
## Das angeschaute Buch rutscht ein Stück heraus – nicht, solange eine Vorschau zu sehen ist.
func _current_transform(book: Book) -> Transform3D:
	var target: Transform3D = _targets.get(book, Transform3D())
	if book == _hover_book and _plan.is_empty():
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
	var count := _order.size() + _leaving.size()
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
	set_process(not _anims.is_empty() or not _leaving.is_empty() or _ghost_shake >= 0.0)


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
	_update_ghost_shake(delta)
	if _anims.is_empty() and _leaving.is_empty() and _ghost_shake < 0.0:
		set_process(false)


## Die Vorschau schüttelt sich kurz hin und her (Linksklick, obwohl das Buch nicht passt).
func _update_ghost_shake(delta: float) -> void:
	if _ghost_shake < 0.0:
		return
	_ghost_shake += delta
	var fade := clampf(1.0 - _ghost_shake / 0.35, 0.0, 1.0)
	if _ghost and _ghost.visible:
		_ghost.transform = _ghost_transform.translated_local(Vector3(sin(_ghost_shake * 45.0) * 0.3 * fade, 0.0, 0.0))
	if fade <= 0.0:
		_ghost_shake = -1.0


# --- Hinweise ---

## Tastensymbole unter der Bildmitte: Nehmen (beim angeschauten Buch) und R = Menü.
## Ablegen und Einräumen zeigen die Tragehinweise unten (siehe CarryIndicator).
func _update_prompt() -> void:
	if _interactable == null:
		return
	var matching := count_matching_carried() if _is_live else 0
	_interactable.supports_place_all = matching > 0
	_interactable.take_text = "Nehmen" if _hover_book else ""


# --- Hilfsfunktionen ---

## Die Genres, die in diesem Fach stehen.
func genres_in_row(row: int) -> Array:
	var result := []
	for book: Book in _row_books[row]:
		if not result.has(book.genre_id):
			result.append(book.genre_id)
	return result


## Wie viele Bücher je Genre bei einem gemischten Regal aus dem Lager kommen:
## möglichst gleichmäßig verteilt, Genre-Reihenfolge wie im Katalog (only_genres: nur diese).
func _mixed_shares(wanted: int, only_genres: Array = []) -> Dictionary:
	var shares := {}
	var open: Array[String] = []
	for genre in Catalog.get_all_genres():
		if (only_genres.is_empty() or only_genres.has(genre.get_id())) and BookStock.get_stored_count(genre.get_id()) > 0:
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
