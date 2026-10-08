class_name ReturnBox
extends Node3D
## Der Rückgabekasten: genau einer, fest in der Hauswand neben der Eingangstür eingebaut –
## wie ein Briefkasten-Einwurf. Außen ist der Einwurf (später werfen Besucher dort ihre
## Bücher ein, auch bei geschlossenem Laden), innen eine Klappe, aus der ich sie nehme.
##
## - E (innen): so viele Bücher, wie in meine Hände passen (GameConfig.max_carried_books);
##   Rechtsklick: eins. Ich trage sie dann (BookStock.carried) und räume sie ein.
## - Der Kasten ist immer zu – die Bücher darin sieht man nicht. Schaue ich ihn an, zeigt eine
##   kleine Anzeige (CountBadge) mit Buchsymbol, wie viele darin liegen.
## - Platz für GameConfig.return_box_capacity Bücher. Ist er voll, nimmt er nichts mehr an
##   (add_books liefert, was nicht hineinpasst).
## - Wie der Einwurf außen aussieht, wähle ich in der App "Fassade" (set_slot, Datenblätter
##   ReturnSlotData in data/return_slots/).
## - Wo er sitzt: ein Marker unter "ReturnBoxSpots" im Raum (bisher nur einer, neben der Tür;
##   move_to_spot). Ursprung = Mitte der Wand am Boden, +Z zeigt in den Raum.
## - Bis es Besucher gibt, legt die Testtaste F9 ein paar Bücher hinein (siehe DebugKeys).
## - Er wird nicht aufgestellt, gekauft oder verkauft. Gespeichert wird er selbst (Gruppe
##   persist): Bücher, Einwurf-Variante und Ort.

## Der Kasten hat sich geändert (Bücher, Einwurf).
signal changed

## So hieß der frühere, frei aufstellbare Rückgabekasten (Möbel-id) – nur für alte Spielstände
## (siehe Room._load_furniture_entry).
const LEGACY_FURNITURE_ID := "return_box"
## Was der frühere Kasten im Shop kostete (für Erstattungen in alten Spielständen)
const LEGACY_PRICE := 90
## Knoten im Raum mit den möglichen Orten (Marker3D, Name = Kennung des Orts)
const SPOTS_NODE := "ReturnBoxSpots"
const DEFAULT_SPOT := "BesideDoor"

var save_key := "return_box"
var books: Array[Book] = []
## Kennung der gewählten Einwurf-Variante (ReturnSlotData)
var slot_id: String = ""
## Kennung des Orts (Marker unter ReturnBoxSpots)
var spot_id: String = DEFAULT_SPOT

var _interactable: Interactable
var _slot_point: Node3D
var _slot_model: Node3D
var _is_aimed := false


func _ready() -> void:
	add_to_group(BookStock.RETURN_BOX_GROUP)
	add_to_group(SaveManager.PERSIST_GROUP)
	_slot_point = get_node_or_null("SlotPoint") as Node3D
	_interactable = get_node_or_null("Interactable") as Interactable
	if _interactable:
		_interactable.interacted.connect(_on_interacted)
		_interactable.take_requested.connect(_on_take_requested)
		_interactable.aimed.connect(_on_aimed)
		_interactable.aim_ended.connect(_on_aim_ended)
	move_to_spot(spot_id)
	set_slot(GameConfig.return_box_default_slot, false)
	_update()


## Der Rückgabekasten im Spiel (oder null).
static func find(tree: SceneTree) -> ReturnBox:
	return tree.get_first_node_in_group(BookStock.RETURN_BOX_GROUP) as ReturnBox


## Gehört dieser Körper (z. B. von einem Strahl getroffen) zum Rückgabekasten?
static func is_part(node: Node) -> bool:
	while node:
		if node is ReturnBox:
			return true
		node = node.get_parent()
	return false


# --- Bücher ---

func get_capacity() -> int:
	return GameConfig.return_box_capacity


## Wie viele Bücher passen noch hinein?
func get_free_space() -> int:
	return maxi(0, get_capacity() - books.size())


func is_full() -> bool:
	return get_free_space() <= 0


## Bücher einwerfen (später: Besucher bringen Bücher zurück). Liefert, was nicht mehr
## hineinpasst (der Kasten ist voll) – das bleibt beim, der es einwerfen wollte.
func add_books(new_books: Array) -> Array[Book]:
	var rest: Array[Book] = []
	var room := get_free_space()
	for book: Book in new_books:
		if room > 0:
			books.append(book)
			room -= 1
		else:
			rest.append(book)
	if rest.size() < new_books.size():
		_changed()
	return rest


## Nimmt bis zu "amount" Bücher heraus (die zuletzt eingeworfenen zuerst).
func take_some(amount: int) -> Array[Book]:
	var taken: Array[Book] = []
	while taken.size() < amount and not books.is_empty():
		taken.append(books.pop_back())
	if not taken.is_empty():
		_changed()
	return taken


## Nimmt alle Bücher heraus.
func take_all() -> Array[Book]:
	var all: Array[Book] = books.duplicate()
	books.clear()
	if not all.is_empty():
		_changed()
	return all


## Alle Bücher im Kasten.
func get_books() -> Array[Book]:
	return books


## Wie viele Bücher dieses Genres liegen im Kasten? (für den Bestand)
func count_books(genre_id: String) -> int:
	var count := 0
	for book in books:
		if book.genre_id == genre_id:
			count += 1
	return count


## Alter Spielstand: Frühere Rückgabekästen im Inventar (Verkaufspreis) oder noch in einem
## Lieferkarton (voller Preis, bezahlt, aber nie angekommen) gibt es nicht mehr – das Geld
## kommt zurück.
static func refund_legacy(count: int, full_price: bool) -> void:
	var each := LEGACY_PRICE if full_price else roundi(LEGACY_PRICE * GameConfig.sell_price_share)
	Wallet.earn(each * count, "Rückgabekasten erstattet")


## Bücher aus einem früheren, aufgestellten Rückgabekasten (alter Spielstand): Sie kommen
## hier hinein; was nicht mehr passt, geht ins Lager.
func receive_legacy_books(old_books: Array) -> void:
	var rest := add_books(old_books)
	if not rest.is_empty():
		BookStock.store_books(rest)


# --- Einwurf und Ort ---

## Die gewählte Einwurf-Variante (unbekannte Kennung = die erste vorhandene).
func get_slot() -> ReturnSlotData:
	var data := Catalog.get_return_slot(slot_id)
	if data == null:
		var all := Catalog.get_all_return_slots()
		data = all[0] if not all.is_empty() else null
	return data


## Wählt die Optik des Einwurfs (Kennung einer ReturnSlotData). notify = false: still (beim
## Start und Laden – kein Speichern).
func set_slot(id: String, notify: bool = true) -> void:
	var data := Catalog.get_return_slot(id)
	if data == null:
		var all := Catalog.get_all_return_slots()
		if all.is_empty():
			return
		data = all[0]
	var changed_id := data.get_id() != slot_id
	slot_id = data.get_id()
	if _slot_model == null or changed_id:
		_build_slot_model(data)
	if changed_id and notify:
		_changed()


## Setzt den Kasten an einen Ort (Marker unter ReturnBoxSpots im Raum). Unbekannt = bleibt.
func move_to_spot(id: String) -> void:
	var spots := get_parent().get_node_or_null(SPOTS_NODE) if get_parent() else null
	var marker := spots.get_node_or_null(NodePath(id)) as Node3D if spots else null
	if marker == null:
		return
	spot_id = id
	global_transform = marker.global_transform


func _build_slot_model(data: ReturnSlotData) -> void:
	if _slot_model:
		# Erst aus dem Baum nehmen, damit nie zwei Einwürfe gleichzeitig darin hängen
		_slot_model.get_parent().remove_child(_slot_model)
		_slot_model.queue_free()
		_slot_model = null
	if _slot_point == null or data.scene_path.is_empty() or not ResourceLoader.exists(data.scene_path):
		return
	var packed := load(data.scene_path) as PackedScene
	_slot_model = packed.instantiate() as Node3D if packed else null
	if _slot_model:
		_slot_model.name = "SlotModel"
		_slot_point.add_child(_slot_model)


# --- Spielfigur ---

## E: so viele Bücher, wie in die Hände passen.
func _on_interacted(_interactor: Node) -> void:
	_take_into_hands(BookStock.get_free_hand_space())


## Rechtsklick (Buch nehmen): ein Buch.
func _on_take_requested(_interactor: Node) -> void:
	_take_into_hands(1)


func _take_into_hands(amount: int) -> void:
	if books.is_empty():
		return
	if amount <= 0:
		BookStock.show_hands_full()
		return
	BookStock.carry(take_some(amount))


func _on_aimed(_from: Vector3, _direction: Vector3) -> void:
	if not _is_aimed:
		_is_aimed = true
		_show_badge()


func _on_aim_ended() -> void:
	_is_aimed = false
	CountBadge.hide_badge(self)


func _show_badge() -> void:
	CountBadge.show_count(self, books.size(), is_full())


func _changed() -> void:
	_update()
	changed.emit()
	SaveManager.request_save()


## Tastensymbole und Anzeige aktualisieren.
func _update() -> void:
	if _interactable:
		# Leer: keine Symbole (die Anzeige zeigt 0)
		_interactable.prompt_text = "" if books.is_empty() else "Leeren"
		_interactable.take_text = "" if books.is_empty() else "Nehmen"
	if _is_aimed:
		_show_badge()


# --- Speichern ---

func get_save_data() -> Dictionary:
	return {"books": Book.list_to_save_data(books), "slot": slot_id, "spot": spot_id}


func load_save_data(data: Dictionary) -> void:
	books = Book.list_from_save_data(data.get("books"))
	move_to_spot(str(data.get("spot", DEFAULT_SPOT)))
	set_slot(str(data.get("slot", GameConfig.return_box_default_slot)), false)
	_update()
	changed.emit()
