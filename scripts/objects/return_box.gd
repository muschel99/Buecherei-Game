class_name ReturnBox
extends Node3D
## Der Rückgabekasten: Hier werfen (später) die Besucher ihre ausgeliehenen Bücher ein.
##
## E nimmt alle Bücher auf einmal heraus – ich trage sie dann (BookStock.carried) und kann
## sie mit E an einem passenden Regal einräumen. Kein Zeitdruck: Die Bücher dürfen
## beliebig lange im Kasten liegen.
## Bis es Besucher gibt, legt die Testtaste F9 ein paar zufällige Bücher hinein
## (GameConfig.debug_return_box_key, siehe BookStock).
## Durch das Fenster sieht man einen kleinen Stapel der Bücher (Platzhalter).
## Der Inhalt wird mit dem Raum gespeichert (PlacedFurniture.get_contents_data).

## So viele Bücher sind im Fenster höchstens zu sehen.
const MAX_VISIBLE := 10

var books: Array[Book] = []

var _multimesh: MultiMesh
var _interactable: Interactable
var _is_live := false


func _ready() -> void:
	add_to_group(PlacedFurniture.CONTENTS_GROUP)
	var stack := MultiMeshInstance3D.new()
	stack.name = "Stack"
	_multimesh = BookLook.create_multimesh()
	stack.multimesh = _multimesh
	stack.material_override = BookLook.get_material()
	var point := get_node_or_null("StackPoint") as Node3D
	if point:
		stack.transform = point.transform
	add_child(stack)
	_interactable = get_node_or_null("Interactable") as Interactable
	_is_live = FurnitureUtils.find_placed_furniture(self) != null
	if _is_live:
		add_to_group(BookStock.RETURN_BOX_GROUP)
		if _interactable:
			_interactable.interacted.connect(_on_interacted)
	_update()


## Legt Bücher in den Kasten (später: Besucher bringen Bücher zurück).
func add_books(new_books: Array) -> void:
	books.append_array(new_books)
	_update()
	if _is_live:
		SaveManager.request_save()


## Nimmt alle Bücher heraus.
func take_all() -> Array[Book]:
	var all := books.duplicate()
	books.clear()
	_update()
	if _is_live:
		SaveManager.request_save()
	return all


## Wie viele Bücher dieses Genres liegen im Kasten? (für den Bestand)
func count_books(genre_id: String) -> int:
	var count := 0
	for book in books:
		if book.genre_id == genre_id:
			count += 1
	return count


func _on_interacted(_interactor: Node) -> void:
	if books.is_empty():
		Notice.post(self, "Der Rückgabekasten ist leer.")
		return
	BookStock.carry(take_all())


## Stapel im Fenster und Hinweistext aktualisieren.
func _update() -> void:
	var visible_count := mini(books.size(), MAX_VISIBLE)
	_multimesh.instance_count = visible_count
	var height := 0.0
	for i in visible_count:
		var book := books[i]
		var size := BookLook.get_size(book)
		var thickness := size.x
		# Liegend: Rücken nach vorn, leicht verdreht wie hineingeworfen
		var turn := (float((book.look >> 8) & 255) / 255.0 - 0.5) * 0.5
		var basis := Basis(Vector3.UP, turn) * Basis(Vector3.BACK, PI / 2.0) * Basis.from_scale(Vector3(thickness, size.y * 0.8, size.z * 0.9))
		_multimesh.set_instance_transform(i, Transform3D(basis, Vector3(0.0, height + thickness / 2.0, 0.0)))
		_multimesh.set_instance_color(i, BookLook.get_color(book))
		_multimesh.set_instance_custom_data(i, BookLook.get_custom(book))
		height += thickness
	if _interactable:
		if books.is_empty():
			_interactable.prompt_text = "Rückgabekasten (leer)"
		else:
			_interactable.prompt_text = "Rückgabekasten leeren (%d %s)" % [books.size(), "Buch" if books.size() == 1 else "Bücher"]


# --- Speichern (über PlacedFurniture) ---

func get_contents_data() -> Dictionary:
	return {"books": Book.list_to_save_data(books)}


func load_contents_data(data: Dictionary) -> void:
	books = Book.list_from_save_data(data.get("books"))
	_update()


## Der Kasten wird weggeräumt (Taste X): Die Bücher darin gehen ins Lager.
func release_contents() -> void:
	var all := take_all()
	BookStock.store_books(all)
	var shown := {}
	for book in all:
		var genre := book.get_genre()
		if genre and not shown.has(genre):
			shown[genre] = true
			StorageIndicator.add_item(self, genre)
