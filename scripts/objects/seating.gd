class_name Seating
extends Node3D
## Macht ein Möbelstück zum Sitzmöbel: Mit E setzt man sich auf einen freien Sitzplatz.
##
## So wird ein Möbelstück zum Sitzmöbel:
## 1. Einen Knoten "Seating" mit diesem Script hinzufügen.
## 2. Darunter für jeden Sitzplatz einen SeatPoint auf die Sitzfläche setzen
##    (Blickrichtung +Z = nach vorn).
## 3. Darunter einen Interactable mit Kollisionsform über der Sitzfläche anlegen.

var _interactable: Interactable = null


func _ready() -> void:
	for node in get_children():
		if node is Interactable:
			_interactable = node
			_interactable.prompt_text = "Hinsetzen"
			_interactable.interacted.connect(_on_interactable_interacted)


## Alle Sitzplätze dieses Möbelstücks.
func get_seats() -> Array[SeatPoint]:
	var seats: Array[SeatPoint] = []
	for node in get_children():
		if node is SeatPoint:
			seats.append(node)
	return seats


## Freie Sitzplätze (für die Spielfigur und später für Besucher).
func get_free_seats() -> Array[SeatPoint]:
	return get_seats().filter(func(seat: SeatPoint) -> bool: return seat.is_free())


func _process(_delta: float) -> void:
	if _interactable:
		_interactable.prompt_text = "Hinsetzen" if not get_free_seats().is_empty() else "Besetzt"


func _on_interactable_interacted(interactor: Node) -> void:
	if not interactor is Player:
		return
	var player := interactor as Player
	# Der freie Platz, der am nächsten an der Stelle liegt, auf die man schaut
	var aim := player.get_aim_point()
	var best: SeatPoint = null
	for seat in get_free_seats():
		if best == null or seat.global_position.distance_to(aim) < best.global_position.distance_to(aim):
			best = seat
	if best:
		player.sit_down(best)
