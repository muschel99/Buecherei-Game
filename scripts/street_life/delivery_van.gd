class_name DeliveryVan
extends StreetVehicle
## Der Lieferwagen (seit Etappe 5a): bringt die Kartons der Bestellungen. Er kommt vom
## Straßenende am Anfang der Mittellinie (StreetPaths), fährt auf der Bücherei-Seite
## (Linksverkehr) heran, hält vor dem Lieferort, öffnet die Schiebetür und stellt die Kartons
## einen nach dem anderen ab (sie hüpfen hinüber, DeliveryManager.unload_one). Ist ein Platz
## besetzt (Spielfigur, Passant), kommt der Karton daneben; ist alles besetzt, wartet er. Dann
## schließt er die Tür, fährt weiter und verschwindet am anderen Ende außer Sicht.
## Was er geladen hat, verwaltet der DeliveryManager (dort wird es auch gespeichert).
## Szene: scenes/street_life/delivery_van.tscn (Model austauschbar, Vorlage zum Modellieren:
## assets/models/templates/street_life/delivery_van.glb).

enum State { DRIVE_IN, OPEN, UNLOAD, CLOSE, DRIVE_OUT }

## Wo die Tür sitzt (lokal, Mitte der Tür): von hier hüpfen die Kartons hinaus.
@export var door_point: Vector3 = Vector3(0.88, 1.0, -0.1)
## So lange gleitet die Tür auf bzw. zu (Sekunden).
@export var door_time: float = 0.7
## Eigenes Modell: Ein Teil namens "Door" gleitet beim Öffnen so weit nach hinten (Meter) und
## ein klein wenig nach außen.
@export var door_slide: float = 0.78

var _state := State.DRIVE_IN
var _stop_s := 0.0
var _stop_lat := 0.0
var _timer := 0.0
var _manager: DeliveryManager


## Für StreetLife: Solange der Wagen unterwegs ist, fährt in seiner Richtung niemand los
## (niemand muss hinter ihm warten oder überholen).
func is_delivering() -> bool:
	return active


## Losfahren zum Lieferort: stop_s = Stelle auf der Mittellinie, an der die Tür vor den
## Kartons steht, stop_lat = Lage dicht am Bordstein.
func start_trip(route: StreetRoute, stop_s: float, stop_lat: float, manager: DeliveryManager) -> void:
	_manager = manager
	_stop_s = stop_s
	_stop_lat = stop_lat
	_state = State.DRIVE_IN
	begin(route, 1, GameConfig.delivery_van_speed)
	_open_door(false, 0.01)


func debug_text() -> String:
	return super.debug_text() + " zustand=%s" % State.keys()[_state]


## Mitte der Tür in Weltkoordinaten.
func get_door_position() -> Vector3:
	return global_transform * door_point


func step(delta: float) -> void:
	if not active:
		return
	match _state:
		State.DRIVE_IN:
			var wanted := _wanted_speed()
			var left := _stop_s - _s
			wanted = minf(wanted, sqrt(2.0 * BRAKE * 0.6 * maxf(0.0, left)) + 0.15)
			if left < 14.0:
				_target_lat = lerpf(_stop_lat, lane(), clampf((left - 2.0) / 12.0, 0.0, 1.0))
			_drive(delta, wanted if left > 0.02 else 0.0)
			if left <= 0.05 and speed < 0.05:
				speed = 0.0
				_state = State.OPEN
				_timer = door_time
				_open_door(true, door_time)
		State.OPEN:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.UNLOAD
				_timer = 0.2
		State.UNLOAD:
			_timer -= delta
			if _timer > 0.0:
				return
			var result := _manager.unload_one(get_door_position()) if _manager else DeliveryManager.UNLOAD_EMPTY
			if result == DeliveryManager.UNLOAD_EMPTY:
				_state = State.CLOSE
				_timer = door_time + 0.4
				_open_door(false, door_time)
			else:
				# Platz besetzt: kurz warten und noch einmal versuchen
				_timer = GameConfig.delivery_unload_interval if result == DeliveryManager.UNLOAD_PLACED else 0.5
		State.CLOSE:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.DRIVE_OUT
		State.DRIVE_OUT:
			super.step(delta)


var _door: Node3D
var _door_closed := Vector3.ZERO
var _door_tween: Tween


func _open_door(open: bool, duration: float) -> void:
	if _model == null:
		return
	if _model.has_method("open_door"):
		_model.call("open_door", open, duration)
		return
	# Eigenes Modell: das Teil "Door" (falls vorhanden) gleitet nach hinten
	if _door == null:
		_door = _model.find_child("Door", true, false) as Node3D
		if _door == null:
			return
		_door_closed = _door.position
	if _door_tween:
		_door_tween.kill()
	var target := _door_closed + (Vector3(0.07, 0.0, -door_slide) if open else Vector3.ZERO)
	_door_tween = create_tween()
	_door_tween.tween_property(_door, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
