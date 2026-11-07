class_name ChatSession
extends RefCounted
## Zwei Passanten plaudern miteinander (seit Etappe 6c): Sie wechseln sich ab – wer dran ist, erzählt mit
## den Händen, murmelt und zeigt eine Sprechblase mit Symbol; der andere hört zu, lächelt, lacht manchmal
## mit. StreetLife startet die Runde (beide bleiben stehen) und ruft update() in jedem Schritt.
## Seit Etappe 6h: erst gehen beide aufeinander zu (Passerby.chat_ready), dann Begrüßung – Händeschütteln
## (handshake, beide gleichzeitig) oder einer winkt –, dann wird geplaudert; zum Abschied winken sie manchmal.
## Im Sitzen (seated, zwei auf einer Bank) ohne Annähern und Begrüßung; vorbei, sobald einer aufsteht.

var a: Passerby
var b: Passerby
var time_left := 10.0
var handshake := false
var seated := false
var _speaker := 0
var _turn_left := 0.0
## 0 = aufeinander zu, 1 = Begrüßung, 2 = plaudern
var _phase := 0
var _phase_left := 4.0


func _init(first: Passerby, second: Passerby, duration: float) -> void:
	a = first
	b = second
	time_left = duration
	_speaker = randi() % 2
	_turn_left = 0.0


## Der andere in dieser Runde.
func other(walker: Passerby) -> Passerby:
	return b if walker == a else a


## false = vorbei (beide gehen weiter).
func update(delta: float) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b) or not a.active or not b.active \
			or (seated and (not a.is_sitting() or not b.is_sitting())):
		end()
		return false
	if seated and _phase == 0:
		_phase = 2
	_phase_left -= delta
	match _phase:
		0:  # aufeinander zu
			if (a.chat_ready() and b.chat_ready()) or _phase_left <= 0.0:
				# Hände treffen sich nur, wenn beide am Platz sind
				var shake := handshake and a.chat_ready() and b.chat_ready()
				var waver := randi() % 2
				_phase_left = maxf(a.chat_greet(shake, waver == 0), b.chat_greet(shake, waver == 1))
				_phase = 1
			return true
		1:  # Begrüßung
			if _phase_left <= 0.0:
				_phase = 2
			return true
	time_left -= delta
	if time_left <= 0.0:
		end(randf() < GameConfig.passerby_goodbye_wave_chance and not seated)
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


func end(goodbye: bool = false) -> void:
	for walker in [a, b]:
		if is_instance_valid(walker):
			walker.chat_turn(false, 0.0, true, goodbye)
