class_name DeliveryManager
extends Node3D
## Der Lieferdienst: Nach einer Bestellung steht kurz darauf ein Karton vor der Tür
## (ein Karton pro Bestellung). Wie lange es dauert: GameConfig.delivery_time.
##
## Dieser Knoten liegt draußen vor der Eingangstür; die Kartons erscheinen nebeneinander
## an der Hauswand (siehe _slot_position). Bestellungen unterwegs und noch nicht
## abgeholte Kartons werden mit dem Spielstand gespeichert.
## Später (z. B. Etappe 11) kann hier ein Lieferbote den Karton bringen – der Rest
## des Spiels merkt davon nichts.

## Wird gesendet, wenn ein Karton vor der Tür erscheint.
signal delivery_arrived(box: DeliveryBox)

const GROUP := "delivery_manager"
const BOX_SCENE := preload("res://scenes/objects/delivery_box.tscn")
## Abstand der Kartons nebeneinander (entlang -X) und Anzahl pro Reihe.
const SLOT_SPACING := 0.62
const SLOTS_PER_ROW := 5

## Name im Spielstand.
var save_key: String = "deliveries"

## Bestellungen unterwegs: { "contents": [...], "remaining": Sekunden }
var _orders: Array[Dictionary] = []
var _boxes: Array[DeliveryBox] = []


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.PERSIST_GROUP)


## Nimmt eine Bestellung an. contents: Liste von
## { "kind": "furniture" oder "surface", "id": "...", "count": Anzahl }.
func place_order(contents: Array) -> void:
	if contents.is_empty():
		return
	_orders.append({"contents": contents.duplicate(true), "remaining": GameConfig.delivery_time})
	SaveManager.request_save()


func _process(delta: float) -> void:
	# Läuft nur, wenn das Spiel nicht pausiert ist (im Pausenmenü wartet die Lieferung)
	for order in _orders.duplicate():
		order.remaining -= delta
		if order.remaining <= 0.0:
			_orders.erase(order)
			var box := _spawn_box(order.contents)
			Notice.post(self, "Deine Lieferung ist da – der Karton steht vor der Tür.")
			delivery_arrived.emit(box)
			SaveManager.request_save()


## Wie viele Bestellungen sind noch unterwegs?
func get_order_count() -> int:
	return _orders.size()


## Wie viele Kartons stehen vor der Tür?
func get_box_count() -> int:
	return _boxes.size()


## Ist diese Oberfläche schon bestellt (unterwegs oder im Karton vor der Tür)?
## Oberflächen kauft man nur einmal.
func is_surface_on_the_way(id: String) -> bool:
	var all_contents: Array = []
	for order in _orders:
		all_contents.append_array(order.contents)
	for box in _boxes:
		all_contents.append_array(box.contents)
	for entry in all_contents:
		if entry.get("kind") == "surface" and str(entry.get("id")) == id:
			return true
	return false


func _spawn_box(contents: Array) -> DeliveryBox:
	var box: DeliveryBox = BOX_SCENE.instantiate()
	box.contents = contents
	add_child(box)
	_boxes.append(box)
	_arrange_boxes()
	box.unpacked.connect(_on_box_unpacked)
	return box


func _on_box_unpacked(box: DeliveryBox) -> void:
	_boxes.erase(box)
	SaveManager.request_save()


## Kartons nebeneinander an die Hauswand stellen; wird es voll, eine zweite Reihe davor
## und danach obendrauf stapeln.
func _arrange_boxes() -> void:
	for i in _boxes.size():
		_boxes[i].position = _slot_position(i)
		# leicht schief, damit es nicht zu ordentlich aussieht
		_boxes[i].rotation.y = deg_to_rad([4.0, -6.0, 2.0, -3.0, 7.0][i % 5])


@warning_ignore("integer_division")
func _slot_position(index: int) -> Vector3:
	var per_layer := SLOTS_PER_ROW * 2
	var layer := index / per_layer
	var in_layer := index % per_layer
	var row := in_layer / SLOTS_PER_ROW
	var column := in_layer % SLOTS_PER_ROW
	return Vector3(-column * SLOT_SPACING, layer * 0.37, -row * 0.55)


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	var boxes := []
	for box in _boxes:
		boxes.append(box.contents)
	var orders := []
	for order in _orders:
		orders.append({"contents": order.contents, "remaining": order.remaining})
	return {"orders": orders, "boxes": boxes}


func load_save_data(data: Dictionary) -> void:
	for box in _boxes:
		box.queue_free()
	_boxes.clear()
	_orders.clear()
	var boxes = data.get("boxes")
	if boxes is Array:
		for contents in boxes:
			if contents is Array and not contents.is_empty():
				_spawn_box(contents)
	var orders = data.get("orders")
	if orders is Array:
		for order in orders:
			if order is Dictionary and order.get("contents") is Array:
				_orders.append({"contents": order.contents, "remaining": float(order.get("remaining", 0.0))})
