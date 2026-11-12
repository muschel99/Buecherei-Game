class_name LibraryDoorLink
extends HouseDoor
## Die Ladentür der Bücherei (Door) für Passanten (seit Etappe 7): Besucher melden sich wie an einer Haustür der Straße an
## (request/release), die echte Tür geht dann auf und – wenn die Besucher sie geöffnet haben – hinterher wieder zu.
## Hat die Spielfigur sie geöffnet, bleibt sie offen. Bewegt wird sie in LibraryVisits.step.

var door: Door
var _opened_by_us := false
## Wie lange die Tür schon offen steht (Sekunden; im Prüfwerkzeug läuft die Zeit schneller als die Tür-Animation)
var _open_time := 0.0


func _init(the_door: Door = null) -> void:
	door = the_door


func is_closed() -> bool:
	return door == null or not door.is_ajar()


func is_open() -> bool:
	return door != null and door.is_open and (door.open_amount() >= 0.92 or _open_time > GameConfig.door_open_time)


func is_in_use() -> bool:
	return not _users.is_empty() or (_opened_by_us and door.is_ajar())


func step(delta: float) -> void:
	if door == null:
		return
	_hold = maxf(0.0, _hold - delta)
	_open_time = _open_time + delta if door.is_open else 0.0
	if not _users.is_empty():
		if not door.is_open:
			door.set_open(true)
			_opened_by_us = true
	elif _hold <= 0.0 and _opened_by_us:
		_opened_by_us = false
		if door.is_open:
			door.set_open(false)  # wartet selbst, solange jemand im Schwenkbereich ist
