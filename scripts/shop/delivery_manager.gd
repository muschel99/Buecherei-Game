class_name DeliveryManager
extends Marker3D
## Der Lieferdienst: Nach einer Bestellung stehen kurz darauf Kartons vor der Tür –
## ein Karton pro Objekt (drei Stühle und eine Lampe = vier Kartons).
## Wie lange es dauert: GameConfig.delivery_time.
##
## Dieser Knoten ist der Lieferort (ein Marker3D – im Editor als kleines Kreuz zu sehen).
## Lieferort verschieben: In der Hauptszene im Szenenbaum "Outside/Deliveries" anklicken und
## mit den Pfeilen verschieben. Die Kartons stapeln sich von hier aus:
## - nebeneinander in Richtung stack_direction (weg von der Tür),
## - bis zu GameConfig.delivery_stack_height übereinander,
## - nach GameConfig.delivery_stacks_per_row Stapeln eine neue Reihe in Richtung row_direction.
## Jeder Karton behält seinen Stapel; wird ein unterer eingesammelt, rutschen die oberen nach.
## Bestellungen unterwegs und alle liegenden Kartons werden mit dem Spielstand gespeichert.
## Später (z. B. Etappe 11) kann hier ein Lieferbote die Kartons bringen.

## Wird gesendet, wenn ein Karton vor der Tür erscheint.
signal delivery_arrived(box: DeliveryBox)

const GROUP := "delivery_manager"
const BOX_SCENE := preload("res://scenes/objects/delivery_box.tscn")
## Abstand der Stapel nebeneinander und der Reihen (in Metern). Ein Karton ist 0,5 x 0,42 m
## groß; die Abstände lassen auch schief stehenden Kartons Luft.
const STACK_SPACING := 0.64
const ROW_SPACING := 0.58
## Höhe eines Kartons (0,36 m) plus ein Hauch Luft
const BOX_HEIGHT := 0.362
## Kleine zufällige Verschiebung je Karton (in Metern), damit es natürlich aussieht
const BOX_SHIFT := 0.015
## So lange fällt ein neuer Karton sanft an seinen Platz bzw. rutschen Kartons nach (Sekunden)
const SETTLE_TIME := 0.3
## Neue Kartons einer Lieferung erscheinen kurz nacheinander (Sekunden Abstand)
const SPAWN_STAGGER := 0.12

## Richtung, in die weitere Stapel nebeneinander wachsen (weg von der Tür).
## Steht der Lieferort rechts neben der Tür (vom Gehweg aus gesehen links), auf (1, 0, 0) stellen.
@export var stack_direction: Vector3 = Vector3(-1, 0, 0)
## Richtung, in die neue Reihen wachsen (weg von der Hauswand, hinaus auf den Gehweg).
@export var row_direction: Vector3 = Vector3(0, 0, -1)

## Name im Spielstand.
var save_key: String = "deliveries"

## Bestellungen unterwegs: { "contents": [...], "remaining": Sekunden }
var _orders: Array[Dictionary] = []
## Stapel: Vector2i(Stapel, Reihe) -> Array[DeliveryBox] (von unten nach oben)
var _stacks: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.PERSIST_GROUP)


## Nimmt eine Bestellung an. contents: Liste von
## { "kind": "furniture", "surface" oder "books", "id": "...", "count": Anzahl }.
## Bei "books" ist die id das Genre und count die Zahl der Bücherpakete.
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
			_deliver(order.contents)


## Eine Bestellung kommt an: ein Karton pro Objekt, kurz nacheinander.
func _deliver(contents: Array) -> void:
	var singles := split_contents(contents)
	var text := "Deine Lieferung ist da – der Karton steht vor der Tür."
	if singles.size() > 1:
		text = "Deine Lieferung ist da – %d Kartons stehen vor der Tür." % singles.size()
	Notice.post(self, text)
	for i in singles.size():
		var box := _add_box(singles[i], randf_range(-1.0, 1.0), true, i * SPAWN_STAGGER)
		delivery_arrived.emit(box)
	SaveManager.request_save()


## Teilt einen Inhalt in einzelne Objekte auf: [Stuhl ×3, Lampe] -> [Stuhl], [Stuhl],
## [Stuhl], [Lampe]. Jedes Ergebnis ist der Inhalt eines Kartons (ein Bücherpaket = ein Karton).
static func split_contents(contents: Array) -> Array:
	var result := []
	for entry in contents:
		if not entry is Dictionary:
			continue
		var count := maxi(1, int(entry.get("count", 1)))
		if entry.get("kind") == "surface":
			count = 1  # Oberflächen gibt es nur einmal
		for i in count:
			result.append([{"kind": str(entry.get("kind", "furniture")), "id": str(entry.get("id", "")), "count": 1}])
	return result


## Wie viele Bestellungen sind noch unterwegs?
func get_order_count() -> int:
	return _orders.size()


## Wie viele Kartons stehen vor der Tür?
func get_box_count() -> int:
	return get_boxes().size()


## Alle Kartons vor der Tür (Stapel für Stapel, jeweils von unten nach oben).
func get_boxes() -> Array[DeliveryBox]:
	var result: Array[DeliveryBox] = []
	for key in _sorted_stack_keys():
		result.append_array(_stacks[key])
	return result


## Ist diese Oberfläche schon bestellt (unterwegs oder im Karton vor der Tür)?
## Oberflächen kauft man nur einmal.
func is_surface_on_the_way(id: String) -> bool:
	var all_contents: Array = []
	for order in _orders:
		all_contents.append_array(order.contents)
	for box in get_boxes():
		all_contents.append_array(box.contents)
	for entry in all_contents:
		if entry.get("kind") == "surface" and str(entry.get("id")) == id:
			return true
	return false


# --- Stapeln ---

## Stellt einen Karton auf den nächsten freien Platz (oder auf einen bestimmten Stapel).
## turn: -1 bis 1, wie schief er steht. animate: sanft herunterfallen lassen.
func _add_box(contents: Array, turn: float, animate: bool, delay: float = 0.0, stack_key = null) -> DeliveryBox:
	var box: DeliveryBox = BOX_SCENE.instantiate()
	box.contents = contents
	box.turn = turn
	var key: Vector2i = stack_key if stack_key is Vector2i else _find_free_stack()
	if not _stacks.has(key):
		_stacks[key] = []
	_stacks[key].append(box)
	add_child(box)
	box.unpacked.connect(_on_box_unpacked)
	var target := _slot_transform(key, _stacks[key].size() - 1, box)
	if animate:
		# Erscheint ein Stück darüber und fällt sanft an seinen Platz
		box.transform = target.translated(Vector3.UP * 0.35)
		box.visible = delay <= 0.0
		box.move_to(target, SETTLE_TIME, delay, true, delay > 0.0)
	else:
		box.transform = target
	_update_covered(key)
	return box


## Der nächste freie Platz: Erst stehen die Kartons einer Reihe nebeneinander, dann
## wird diese Reihe Lage für Lage aufgestockt; ist sie voll, kommt die nächste Reihe.
func _find_free_stack() -> Vector2i:
	var per_row := maxi(1, GameConfig.delivery_stacks_per_row)
	var height := maxi(1, GameConfig.delivery_stack_height)
	for row in 3:
		for level in height:
			for column in per_row:
				var key := Vector2i(column, row)
				if _stack_size(key) == level:
					return key
	# Alles voll: auf den niedrigsten Stapel der ersten Reihe
	var best := Vector2i(0, 0)
	for column in per_row:
		if _stack_size(Vector2i(column, 0)) < _stack_size(best):
			best = Vector2i(column, 0)
	return best


func _stack_size(key: Vector2i) -> int:
	return _stacks[key].size() if _stacks.has(key) else 0


## Lage eines Kartons: Stapel, Höhe und seine eigene kleine Drehung/Verschiebung.
func _slot_transform(key: Vector2i, level: int, box: DeliveryBox) -> Transform3D:
	var along := stack_direction.normalized()
	var out := row_direction.normalized()
	var origin := along * key.x * STACK_SPACING + out * key.y * ROW_SPACING + Vector3.UP * level * BOX_HEIGHT
	# Kleine, für jeden Karton feste Abweichung (aus seiner Drehung abgeleitet)
	origin += along * box.turn * BOX_SHIFT + out * sin(box.turn * 7.0) * BOX_SHIFT
	var yaw := deg_to_rad(GameConfig.delivery_box_turn * box.turn)
	return Transform3D(Basis(Vector3.UP, yaw), origin)


func _on_box_unpacked(box: DeliveryBox) -> void:
	for key in _stacks:
		var stack: Array = _stacks[key]
		var index := stack.find(box)
		if index < 0:
			continue
		stack.remove_at(index)
		# Die Kartons darüber rutschen sanft nach (sobald der untere geschrumpft ist)
		for level in range(index, stack.size()):
			var above: DeliveryBox = stack[level]
			above.move_to(_slot_transform(key, level, above), SETTLE_TIME, GameConfig.unpack_time * 0.45)
		if stack.is_empty():
			_stacks.erase(key)
		else:
			_update_covered(key)
		break
	SaveManager.request_save()


## Merkt sich bei jedem Karton, ob noch einer auf ihm steht (dann hebt er sich beim
## Auspacken nicht an, sondern schrumpft an Ort und Stelle).
func _update_covered(key: Vector2i) -> void:
	var stack: Array = _stacks.get(key, [])
	for i in stack.size():
		stack[i].covered = i < stack.size() - 1


func _sorted_stack_keys() -> Array:
	var keys := _stacks.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return keys


# --- Speichern und Laden ---

func get_save_data() -> Dictionary:
	var boxes := []
	for key in _sorted_stack_keys():
		for box: DeliveryBox in _stacks[key]:
			boxes.append({"contents": box.contents, "stack": [key.x, key.y], "turn": box.turn})
	var orders := []
	for order in _orders:
		orders.append({"contents": order.contents, "remaining": order.remaining})
	return {"orders": orders, "boxes": boxes}


func load_save_data(data: Dictionary) -> void:
	for box in get_boxes():
		box.queue_free()
	_stacks.clear()
	_orders.clear()
	var boxes = data.get("boxes")
	if boxes is Array:
		for entry in boxes:
			if entry is Dictionary and entry.get("contents") is Array:
				var stack = entry.get("stack")
				var key = null
				if stack is Array and stack.size() == 2:
					key = Vector2i(int(stack[0]), int(stack[1]))
				for contents in split_contents(entry.contents):
					_add_box(contents, float(entry.get("turn", 0.0)), false, 0.0, key)
					key = null  # weitere Objekte aus einem alten Sammelkarton: auf freie Plätze
			elif entry is Array:
				# Spielstand von vorher: ein Karton pro Bestellung – jetzt einzeln
				for contents in split_contents(entry):
					_add_box(contents, randf_range(-1.0, 1.0), false)
	var orders = data.get("orders")
	if orders is Array:
		for order in orders:
			if order is Dictionary and order.get("contents") is Array:
				_orders.append({"contents": order.contents, "remaining": float(order.get("remaining", 0.0))})
