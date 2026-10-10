class_name DeliveryManager
extends Marker3D
## Der Lieferdienst: Nach einer Bestellung stehen kurz darauf Kartons vor der Tür –
## ein Karton pro Objekt (drei Stühle und eine Lampe = vier Kartons).
## Wie lange es dauert: GameConfig.delivery_time.
## Seit Etappe 5a bringt sie ein Lieferwagen (DeliveryVan, Teil des Straßenlebens StreetLife):
## Ist eine Bestellung fällig, wartet sie auf den Wagen; er nimmt alles mit, was fällig ist,
## hält vor der Bücherei und stellt die Kartons einzeln ab (unload_one). Was während seiner
## Fahrt fällig wird, bringt er bei der nächsten Fahrt. Ist ein Platz besetzt (Spielfigur,
## Passant), kommt der Karton auf den nächsten freien Platz. Ohne Straßenleben
## (GameConfig.street_life_enabled aus) erscheinen die Kartons wie früher direkt.
##
## Dieser Knoten ist der Lieferort (ein Marker3D – im Editor als kleines Kreuz zu sehen).
## Lieferort verschieben: In der Hauptszene im Szenenbaum "Outside/Deliveries" anklicken und
## mit den Pfeilen verschieben. Die Kartons stapeln sich von hier aus:
## - nebeneinander in Richtung stack_direction (weg von der Tür),
## - bis zu GameConfig.delivery_stack_height übereinander,
## - nach GameConfig.delivery_stacks_per_row Stapeln eine neue Reihe in Richtung row_direction.
## Jeder Karton behält seinen Stapel; wird ein unterer eingesammelt, rutschen die oberen nach.
## Bestellungen unterwegs (auch was gerade im Lieferwagen ist) und alle liegenden Kartons werden
## mit dem Spielstand gespeichert; nach dem Laden bringt der Wagen den Rest.

## Wird gesendet, wenn ein Karton vor der Tür erscheint.
signal delivery_arrived(box: DeliveryBox)

const GROUP := "delivery_manager"
const BOX_SCENE := preload("res://scenes/objects/delivery_box.tscn")
## Höchstens so viele Reihen hintereinander (seit Etappe 5a 2 statt 3: so bleibt auf dem Gehweg
## immer ein Durchgang für Passanten). Ist alles voll, wird höher gestapelt.
const MAX_ROWS := 2
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
## Antworten von unload_one: Karton abgestellt, Platz besetzt (gleich noch mal), Wagen leer.
const UNLOAD_PLACED := 0
const UNLOAD_BLOCKED := 1
const UNLOAD_EMPTY := 2
## So lange hüpft ein Karton vom Wagen an seinen Platz (Sekunden).
const HOP_TIME := 0.55
## Ein Platz gilt als besetzt, wenn jemand so nah daran steht (Meter, waagerecht).
const BLOCK_DISTANCE := 0.65

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
## Fällige Bestellungen, die auf den Lieferwagen warten (je Bestellung ein Inhalt).
var _due: Array = []
## Was gerade im Lieferwagen ist: einzelne Karton-Inhalte (siehe split_contents).
var _van_load: Array = []
## Kartons dieser Fahrt schon abgestellt (für den Hinweis "Lieferung ist da").
var _trip_count := 0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.PERSIST_GROUP)


## Nimmt eine Bestellung an. contents: Liste von
## { "kind": "furniture", "surface" oder "books", "id": "...", "count": Anzahl }.
## Bei "books" ist die id das Genre und count die Zahl der Bücherpakete.
## wait: so viele Sekunden bis zur Lieferung (Standard: GameConfig.delivery_time).
func place_order(contents: Array, wait: float = -1.0) -> void:
	if contents.is_empty():
		return
	_orders.append({"contents": contents.duplicate(true), "remaining": GameConfig.delivery_time if wait < 0.0 else wait})
	SaveManager.request_save()


func _process(delta: float) -> void:
	# Läuft nur, wenn das Spiel nicht pausiert ist (im Pausenmenü wartet die Lieferung)
	var life := _street_life()
	for order in _orders.duplicate():
		order.remaining -= delta
		if order.remaining <= 0.0:
			_orders.erase(order)
			if life:
				_due.append(order.contents)
			else:
				_deliver(order.contents)
	if life == null and not (_due.is_empty() and _van_load.is_empty()):
		# Straßenleben ausgeschaltet: was noch wartet, kommt direkt
		for contents in _due:
			_deliver(contents)
		for contents in _van_load:
			_deliver(contents)
		_due.clear()
		_van_load.clear()
	elif life and not _due.is_empty() and _van_load.is_empty() and life.send_van(self):
		# Der Lieferwagen nimmt alles mit, was jetzt fällig ist
		for contents in _due:
			_van_load.append_array(split_contents(contents))
		_due.clear()
		_trip_count = 0


## Das Straßenleben mit Lieferwagen (null = keins, dann wie früher ohne Wagen).
func _street_life() -> StreetLife:
	if not GameConfig.street_life_enabled:
		return null
	var life := get_tree().get_first_node_in_group(StreetLife.GROUP) as StreetLife
	return life if life and life.has_van() else null


## Der Lieferwagen stellt einen Karton ab: Er hüpft von der Tür ("from", global) auf den
## nächsten freien Platz. Antwort: UNLOAD_PLACED, UNLOAD_BLOCKED (alles besetzt, gleich noch
## einmal) oder UNLOAD_EMPTY (Wagen leer).
func unload_one(from: Vector3) -> int:
	if _van_load.is_empty():
		return UNLOAD_EMPTY
	var key = _free_stack_avoiding(_blocking_points())
	if key == null:
		return UNLOAD_BLOCKED
	var contents: Array = _van_load.pop_front()
	var box := _add_box(contents, randf_range(-1.0, 1.0), false, 0.0, key)
	box.hop_from(to_local(from), box.transform, HOP_TIME)
	_trip_count += 1
	if _trip_count == 1:
		var total := 1 + _van_load.size()
		Notice.post(self, "Lieferung ist da" if total == 1 else "Lieferung ist da (%d Kartons)" % total)
	delivery_arrived.emit(box)
	SaveManager.request_save()
	return UNLOAD_PLACED


## Hat der Lieferwagen noch etwas geladen?
func van_has_load() -> bool:
	return not _van_load.is_empty()


## Wo gerade jemand steht (Spielfigur, Passanten) – dort kommt kein Karton hin.
func _blocking_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var life := get_tree().get_first_node_in_group(StreetLife.GROUP) as StreetLife
	if life:
		points = life.blocking_points()
	return points


## Der nächste freie Platz, an dem niemand steht (null = alle besetzt).
func _free_stack_avoiding(points: Array[Vector3]):
	var avoid: Array[Vector2i] = []
	for row in MAX_ROWS:
		for column in maxi(1, GameConfig.delivery_stacks_per_row):
			var key := Vector2i(column, row)
			var spot := global_transform * _slot_origin(key)
			for p in points:
				if Vector2(p.x - spot.x, p.z - spot.z).length() < BLOCK_DISTANCE:
					avoid.append(key)
					break
	var key := _find_free_stack(avoid)
	return null if key in avoid else key


## Eine Bestellung kommt an: ein Karton pro Objekt, kurz nacheinander.
func _deliver(contents: Array) -> void:
	var singles := split_contents(contents)
	Notice.post(self, "Lieferung ist da" if singles.size() == 1 else "Lieferung ist da (%d Kartons)" % singles.size())
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
	return _orders.size() + _due.size() + (1 if not _van_load.is_empty() else 0)


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
	for contents in _due + _van_load:
		all_contents.append_array(contents)
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
## avoid: Plätze, die gerade besetzt sind (dort steht jemand).
func _find_free_stack(avoid: Array[Vector2i] = []) -> Vector2i:
	var per_row := maxi(1, GameConfig.delivery_stacks_per_row)
	var height := maxi(1, GameConfig.delivery_stack_height)
	for row in MAX_ROWS:
		for level in height:
			for column in per_row:
				var key := Vector2i(column, row)
				if _stack_size(key) == level and not key in avoid:
					return key
	# Alles voll: auf den niedrigsten freien Stapel
	var best := Vector2i(-1, -1)
	for row in MAX_ROWS:
		for column in per_row:
			var key := Vector2i(column, row)
			if key in avoid:
				continue
			if best.x < 0 or _stack_size(key) < _stack_size(best):
				best = key
	return best if best.x >= 0 else Vector2i(0, 0) if avoid.is_empty() else avoid[0]


## Fußpunkt eines Stapels (ohne die kleine Verschiebung je Karton), lokal.
func _slot_origin(key: Vector2i) -> Vector3:
	return stack_direction.normalized() * key.x * STACK_SPACING + row_direction.normalized() * key.y * ROW_SPACING


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
	# Was fällig ist oder gerade im Lieferwagen liegt, bringt er nach dem Laden (sofort fällig)
	for contents in _due:
		orders.append({"contents": contents, "remaining": 0.0})
	for contents in _van_load:
		orders.append({"contents": contents, "remaining": 0.0})
	return {"orders": orders, "boxes": boxes}


func load_save_data(data: Dictionary) -> void:
	for box in get_boxes():
		box.queue_free()
	_stacks.clear()
	_orders.clear()
	_due.clear()
	_van_load.clear()
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
