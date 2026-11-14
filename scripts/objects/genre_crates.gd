class_name GenreCrates
extends Node3D
## Bücherkisten im Würfelregal unter der Theke (seit Testrunde 7b, Wunsch der Entwicklerin: „wie ein Kallax mit Kisten
## drin“): Die Theken haben hinten (Seite der Spielfigur) 6 x 3 Fächer; in jedem Fach steht die Kiste eines freigeschalteten
## Genres – je Thekenstil eine passende (CounterData.crate_path: Eichenkiste, Walnusskasten, Weidenkorb, Leinenbox) mit dem
## Genre-Namen in Handschrift auf dem Schild. Die Kisten SIND das Lager (BookStock): so viele Bücher, wie im Lager liegen,
## stehen darin (höchstens BOOKS_SHOWN). Rechtsklick auf eine Kiste nimmt ein Buch dieses Genres in die Hand, Linksklick legt
## das Buch obenauf zurück in seine Kiste (nur in die passende).
## Hängt an der Theke (Counter). Lage im Raum der Theke: Kundenseite +Z, Spielfigur -Z.

# Maße des Würfelregals – genau wie tools/blender/furniture_fixtures.py (CUBE_*, CRATE_*), dort gleich halten
const HALF_W := 0.94
const BOARD := 0.025
const BASE_Z := 0.09
const UNDER_TOP := 0.955
const BACK_Y := 0.25          # Rückseite des Korpus (Blender-y) = Öffnung der Fächer
const CUBE_COLS := 6
const CUBE_ROWS := 3
const CUBE_T := 0.028
const CRATE_SIZE := Vector3(0.25, 0.15, 0.29)  # Breite, Höhe, Tiefe
const LABEL_Z := 0.105
const LABEL_W := 0.12
## Vorderfläche des Schilds je Kiste (Abstand von der Kistenmitte nach vorn), die Schrift sitzt knapp davor
const LABEL_FRONT := {"crate_wicker": 0.1505, "crate_linen": 0.145}
const LABEL_FRONT_DEFAULT := 0.149
const DEFAULT_CRATE := "res://assets/models/furniture/crate_oak.glb"
const BOOK_MODEL := "res://assets/models/furniture/crate_book.glb"
const LABEL_FONT := "res://assets/ui/fonts/Caveat-Bold.woff2"
const INK := Color(0.2, 0.13, 0.09)
const BOOKS_SHOWN := 7
## So weit ragt der E-Bereich einer Kiste hinten aus der Theke (der feste Körper der Theke reicht bis z = -0,305)
const REACH_OUT := 0.1

var _crates: Dictionary = {}  # genre_id → {node, books: Node3D, interactable, genre}
var _crate_path := ""
var _dirty := true


## Hängt die Kisten in die Theke.
static func attach(counter: Node3D) -> GenreCrates:
	var crates := GenreCrates.new()
	crates.name = "GenreCrates"
	counter.add_child(crates)
	return crates


func _ready() -> void:
	BookStock.changed.connect(func() -> void: _dirty = true)
	BookStock.carried_changed.connect(func() -> void: _dirty = true)
	CounterStyle.changed.connect(func() -> void: _dirty = true)


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild()


## Mitte des Fachs (Spalte von links aus Sicht der Spielfigur, Reihe von oben), unten auf dem Boden des Fachs.
static func cell_position(column: int, row: int) -> Vector3:
	var x0 := -HALF_W + BOARD
	var z0 := BASE_Z + BOARD
	var cw := (2.0 * (HALF_W - BOARD) - (CUBE_COLS - 1) * CUBE_T) / CUBE_COLS
	var ch := (UNDER_TOP - z0 - (CUBE_ROWS - 1) * CUBE_T) / CUBE_ROWS
	# Die Spielfigur schaut von -Z nach +Z: ihr „links“ ist +X
	var x := -(x0 + cw / 2.0 + column * (cw + CUBE_T))
	var bottom := z0 + (CUBE_ROWS - 1 - row) * (ch + CUBE_T)
	return Vector3(x, bottom, -(BACK_Y - 0.01 - CRATE_SIZE.z / 2.0))


static func cell_size() -> Vector2:
	var cw := (2.0 * (HALF_W - BOARD) - (CUBE_COLS - 1) * CUBE_T) / CUBE_COLS
	var ch := (UNDER_TOP - BASE_Z - BOARD - (CUBE_ROWS - 1) * CUBE_T) / CUBE_ROWS
	return Vector2(cw, ch)


## Kisten neu aufbauen bzw. füllen (beim Start, wenn sich Lager, freigeschaltete Genres oder die Theke ändern).
func _rebuild() -> void:
	var style := CounterStyle.get_style()
	var path: String = style.crate_path if style and not style.crate_path.is_empty() else DEFAULT_CRATE
	if path != _crate_path:
		_crate_path = path
		for entry: Dictionary in _crates.values():
			(entry.node as Node).queue_free()
		_crates.clear()
	var genres: Array[GenreData] = []
	for genre: GenreData in Catalog.get_all_genres():
		if BookStock.is_genre_unlocked(genre.id):
			genres.append(genre)
	genres.sort_custom(func(a: GenreData, b: GenreData) -> bool: return a.sort_order < b.sort_order)
	var ids: Array[String] = []
	for genre in genres:
		ids.append(genre.id)
	for id: String in _crates.keys():
		if not id in ids:
			(_crates[id].node as Node).queue_free()
			_crates.erase(id)
	for i in mini(genres.size(), CUBE_COLS * CUBE_ROWS):
		var genre := genres[i]
		if not _crates.has(genre.id):
			_crates[genre.id] = _make_crate(genre)
		var crate: Dictionary = _crates[genre.id]
		(crate.node as Node3D).position = cell_position(i % CUBE_COLS, i / CUBE_COLS)
		_fill_crate(crate)


## Kiste (Modell der Theke) mit Schild in Handschrift, Halter für die Bücher und E-Bereich.
func _make_crate(genre: GenreData) -> Dictionary:
	var node := Node3D.new()
	node.name = "Crate_" + genre.id
	node.rotation.y = PI  # Vorderseite (Schild) zur Spielfigur
	add_child(node)
	var packed := load(_crate_path) as PackedScene
	if packed:
		node.add_child(packed.instantiate())
	var label := Label3D.new()
	label.text = genre.display_name
	label.font = load(LABEL_FONT)
	label.font_size = 72
	label.pixel_size = 0.00026
	label.modulate = INK
	label.outline_size = 0
	label.double_sided = false
	label.width = (LABEL_W - 0.012) / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.line_spacing = -12.0
	var front: float = LABEL_FRONT.get(_crate_path.get_file().get_basename(), LABEL_FRONT_DEFAULT)
	label.position = Vector3(0.0, LABEL_Z, front + 0.0015)
	node.add_child(label)
	var books := Node3D.new()
	books.name = "Books"
	node.add_child(books)
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	interactable.prompt_text = ""
	interactable.take_text = "Nehmen"
	interactable.handles_placing = true
	interactable.highlight_owner = false
	var cell := cell_size()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(cell.x - 0.02, cell.y - 0.01, CRATE_SIZE.z + REACH_OUT)
	shape.shape = box
	shape.position = Vector3(0.0, (cell.y - 0.01) / 2.0, REACH_OUT / 2.0)
	interactable.add_child(shape)
	node.add_child(interactable)
	interactable.take_requested.connect(func(_who: Node) -> void: _take(genre.id))
	interactable.place_requested.connect(func(_who: Node) -> void: _put_back(genre.id))
	return {"node": node, "books": books, "interactable": interactable, "genre": genre}


## Bücher in der Kiste (so viele, wie im Lager liegen, höchstens BOOKS_SHOWN): aufrecht hintereinander, Einband nach vorn,
## in den Farben des Genres, leicht nach hinten gelehnt.
func _fill_crate(crate: Dictionary) -> void:
	var genre: GenreData = crate.genre
	var books: Node3D = crate.books
	var count := BookStock.get_stored_count(genre.id)
	var shown := mini(count, BOOKS_SHOWN)
	if books.get_child_count() != shown:
		for child in books.get_children():
			child.queue_free()
		var packed := load(BOOK_MODEL) as PackedScene
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(genre.id)
		var colors: Array = genre.spine_colors if not genre.spine_colors.is_empty() else [Color(0.55, 0.4, 0.3)]
		var step := (CRATE_SIZE.z - 0.07) / maxf(1.0, BOOKS_SHOWN - 1)
		for i in shown:
			if packed == null:
				break
			var book := packed.instantiate() as Node3D
			# von hinten nach vorn, das vorderste Buch zeigt seinen Einband
			book.position = Vector3(rng.randf_range(-0.012, 0.012), 0.012, -CRATE_SIZE.z / 2.0 + 0.04 + i * step)
			book.rotation = Vector3(deg_to_rad(-rng.randf_range(6.0, 14.0)), deg_to_rad(rng.randf_range(-4.0, 4.0)), 0.0)
			book.scale = Vector3.ONE * rng.randf_range(0.9, 1.05)
			var cover_colors: Dictionary[String, Color] = {}
			cover_colors["cover"] = colors[(i + rng.randi() % colors.size()) % colors.size()]
			var variant := ColorVariant.new()
			variant.colors = cover_colors
			FurnitureUtils.apply_variant(book, variant)
			books.add_child(book)
	var interactable: Interactable = crate.interactable
	interactable.take_text = "Nehmen" if count > 0 else ""
	var active := BookStock.get_active_book()
	interactable.handles_placing = active != null and active.genre_id == genre.id


func _take(genre_id: String) -> void:
	if BookStock.get_free_hand_space() <= 0:
		BookStock.show_hands_full()
		return
	var taken := BookStock.take_books(genre_id, 1)
	if taken.is_empty():
		return
	var rest := BookStock.carry(taken)
	if not rest.is_empty():
		BookStock.put_back_first(rest)
	Audio.play_at("books/take", global_position + Vector3.UP * 0.3, -4.0, Audio.vary(0.08))


func _put_back(genre_id: String) -> void:
	var active := BookStock.get_active_book()
	if active == null or active.genre_id != genre_id:
		return
	BookStock.store_books([BookStock.take_active()])
	Audio.play_at("books/place", global_position + Vector3.UP * 0.3, -4.0, Audio.vary(0.08))
