class_name ChatSession
extends RefCounted
## Zwei Passanten plaudern miteinander (seit Etappe 6c): Sie wechseln sich ab – wer dran ist, erzählt mit
## den Händen, murmelt und zeigt eine Sprechblase mit Symbol; der andere hört zu, lächelt, lacht manchmal
## mit. StreetLife startet die Runde (beide bleiben stehen) und ruft update() in jedem Schritt.

var a: Passerby
var b: Passerby
var time_left := 10.0
var _speaker := 0
var _turn_left := 0.0


func _init(first: Passerby, second: Passerby, duration: float) -> void:
	a = first
	b = second
	time_left = duration
	_speaker = randi() % 2
	_turn_left = 0.0


## false = vorbei (beide gehen weiter).
func update(delta: float) -> bool:
	time_left -= delta
	if time_left <= 0.0 or not is_instance_valid(a) or not is_instance_valid(b) or not a.active or not b.active:
		end()
		return false
	_turn_left -= delta
	if _turn_left <= 0.0:
		_speaker = 1 - _speaker
		_turn_left = randf_range(1.6, 3.2)
		var speaker := a if _speaker == 0 else b
		var listener := b if _speaker == 0 else a
		speaker.chat_turn(true, _turn_left)
		listener.chat_turn(false, _turn_left)
	return true


func end() -> void:
	for walker in [a, b]:
		if is_instance_valid(walker):
			walker.chat_turn(false, 0.0, true)
