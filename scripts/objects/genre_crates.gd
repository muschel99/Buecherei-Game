class_name GenreCrates
extends Node3D
## Bücherkisten hinter der Theke (seit Testrunde 7b, Wunsch der Entwicklerin): ein niedriges Holzregal auf der Seite der
## Spielfigur, darin je freigeschaltetem Genre eine Holzkiste mit farbigem Schild. Die Kisten SIND das Lager (BookStock):
## so viele Bücher, wie im Lager liegen, schauen oben heraus (höchstens BOOKS_SHOWN). Rechtsklick auf eine Kiste nimmt ein Buch
## dieses Genres in die Hand, Linksklick legt das Buch obenauf zurück in seine Kiste (nur in die passende).
## Hängt an der Theke (Counter) und wandert mit ihr; Lage im Raum der Theke: Kundenseite +Z, Spielfigur -Z.

const PER_ROW := 8
const RACK_WIDTH := 2.0
const RACK_DEPTH := 0.3
const LEVEL_HEIGHT := 0.25
const BOOKS_SHOWN := 7
const WOOD := Color(0.6, 0.42, 0.26)
const WOOD_DARK := Color(0.45, 0.3, 0.18)

var _crates: Dictionary = {}  # genre_id → {node, books: Node3D, interactable, genre}
var _rack: Node3D
var _dirty := true


## Hängt die Kisten hinter eine Theke.
static func attach(counter: Node3D) -> GenreCrates:
	var crates := GenreCrates.new()
	crates.name = "GenreCrates"
	counter.add_child(crates)
	return crates


func _ready() -> void:
	position = Vector3(0.0, 0.0, -0.325 - RACK_DEPTH / 2.0 - 0.01)
	BookStock.changed.connect(func() -> void: _dirty = true)
	BookStock.carried_changed.connect(func() -> void: _dirty = true)
	_build_rack()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild()


## Regal: zwei Böden, Seitenwände, Deckbrett, Rückwand zur Theke (mit Kollision).
func _build_rack() -> void:
	_rack = Node3D.new()
	_rack.name = "Rack"
	add_child(_rack)
	var wood := _material(WOOD)
	var dark := _material(WOOD_DARK)
	var h := LEVEL_HEIGHT * 2.0 + 0.04
	for part: Array in [
			[Vector3(RACK_WIDTH, 0.025, RACK_DEPTH), Vector3(0, 0.0125, 0), dark],              # Boden
			[Vector3(RACK_WIDTH, 0.022, RACK_DEPTH), Vector3(0, LEVEL_HEIGHT + 0.011, 0), wood],  # Zwischenboden
			[Vector3(RACK_WIDTH + 0.04, 0.03, RACK_DEPTH + 0.02), Vector3(0, h, 0), wood],       # Deckbrett
			[Vector3(0.025, h, RACK_DEPTH), Vector3(-RACK_WIDTH / 2.0 - 0.0125, h / 2.0, 0), wood],
			[Vector3(0.025, h, RACK_DEPTH), Vector3(RACK_WIDTH / 2.0 + 0.0125, h / 2.0, 0), wood],
			[Vector3(RACK_WIDTH, h, 0.015), Vector3(0, h / 2.0, RACK_DEPTH / 2.0 - 0.0075), dark]]:  # Rückwand (zur Theke)
		_rack.add_child(_box(part[0], part[1], part[2]))
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = FurnitureUtils.FURNITURE_LAYER_BIT
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RACK_WIDTH + 0.05, h + 0.015, RACK_DEPTH)
	shape.shape = box
	shape.position = Vector3(0, (h + 0.015) / 2.0, 0)
	body.add_child(shape)
	_rack.add_child(body)


## Kisten neu aufbauen bzw. füllen (beim Start, wenn sich das Lager oder die freigeschalteten Genres ändern).
func _rebuild() -> void:
	var genres: Array[GenreData] = []
	for genre: GenreData in Catalog.get_all_genres():
		if BookStock.is_genre_unlocked(genre.id):
			genres.append(genre)
	genres.sort_custom(func(a: GenreData, b: GenreData) -> bool: return a.sort_order < b.sort_order)
	# fehlende Kisten anlegen, alte entfernen
	var ids: Array[String] = []
	for genre in genres:
		ids.append(genre.id)
	for id: String in _crates.keys():
		if not id in ids:
			(_crates[id].node as Node).queue_free()
			_crates.erase(id)
	var slot_width := RACK_WIDTH / PER_ROW
	for i in genres.size():
		var genre := genres[i]
		if not _crates.has(genre.id):
			_crates[genre.id] = _make_crate(genre)
		var crate: Dictionary = _crates[genre.id]
		var row := i / PER_ROW
		var column := i % PER_ROW
		(crate.node as Node3D).position = Vector3(-RACK_WIDTH / 2.0 + slot_width * (column + 0.5),
			0.025 + row * (LEVEL_HEIGHT + 0.022) * (1.0 if row < 2 else 0.0), 0.0)
		(crate.node as Node3D).visible = row < 2
		_fill_crate(crate)


## Holzkiste aus Latten mit Schild in Genre-Farbe (vorn = Seite der Spielfigur) und E-Bereich.
func _make_crate(genre: GenreData) -> Dictionary:
	var node := Node3D.new()
	node.name = "Crate_" + genre.id
	add_child(node)
	var wood := _material(WOOD.lightened(0.08))
	var w := RACK_WIDTH / PER_ROW - 0.02
	var d := RACK_DEPTH - 0.05
	var h := 0.15
	node.add_child(_box(Vector3(w, 0.012, d), Vector3(0, 0.006, 0), wood))
	for side: float in [-1.0, 1.0]:
		node.add_child(_box(Vector3(0.012, h, d), Vector3(side * (w / 2.0 - 0.006), h / 2.0, 0), wood))
		for k in 2:
			node.add_child(_box(Vector3(w, 0.05, 0.012), Vector3(0, 0.035 + k * 0.07, side * (d / 2.0 - 0.006)), wood))
	# Schild vorn (zur Spielfigur, -Z)
	var color: Color = genre.spine_colors[0] if not genre.spine_colors.is_empty() else Color(0.6, 0.5, 0.4)
	node.add_child(_box(Vector3(w * 0.86, 0.06, 0.006), Vector3(0, 0.075, -d / 2.0 - 0.015), _material(color.lightened(0.15))))
	var label := Label3D.new()
	label.text = genre.display_name
	label.font = load("res://assets/ui/fonts/DejaVuSansCondensed-Bold.ttf")
	label.font_size = 64
	label.pixel_size = 0.0003
	label.modulate = Color(0.12, 0.08, 0.05) if color.get_luminance() > 0.45 else Color(0.98, 0.95, 0.88)
	label.outline_size = 0
	label.double_sided = false
	label.width = w * 0.8 / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector3(0, 0.075, -d / 2.0 - 0.019)
	label.rotation.y = PI
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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, LEVEL_HEIGHT - 0.03, d + 0.06)
	shape.shape = box
	shape.position = Vector3(0, (LEVEL_HEIGHT - 0.03) / 2.0, -0.03)
	interactable.add_child(shape)
	node.add_child(interactable)
	interactable.take_requested.connect(func(_who: Node) -> void: _take(genre.id))
	interactable.place_requested.connect(func(_who: Node) -> void: _put_back(genre.id))
	return {"node": node, "books": books, "interactable": interactable, "genre": genre}


## Bücher in der Kiste zeigen (so viele, wie im Lager liegen, höchstens BOOKS_SHOWN; Farben des Genres).
func _fill_crate(crate: Dictionary) -> void:
	var genre: GenreData = crate.genre
	var books: Node3D = crate.books
	var count := BookStock.get_stored_count(genre.id)
	var shown := mini(count, BOOKS_SHOWN)
	if books.get_child_count() != shown:
		for child in books.get_children():
			child.queue_free()
		var w := RACK_WIDTH / PER_ROW - 0.05
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(genre.id)
		for i in shown:
			var thick := rng.randf_range(0.018, 0.026)
			var tall := rng.randf_range(0.15, 0.19)
			var colors := genre.spine_colors if not genre.spine_colors.is_empty() else [Color(0.55, 0.4, 0.3)]
			var book := _box(Vector3(thick, tall, 0.13), Vector3(-w / 2.0 + 0.015 + i * (w - 0.02) / maxf(1.0, BOOKS_SHOWN - 1),
				0.012 + tall / 2.0, rng.randf_range(-0.03, 0.03)), _material(colors[i % colors.size()]))
			book.rotation.z = rng.randf_range(-0.12, 0.12)
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


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
