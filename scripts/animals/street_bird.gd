class_name StreetBird
extends StreetAnimal
## Ein Vogel (seit Etappe 6g, weich und mit Flug in Bögen seit 6h): kleiner Singvogel ("bird") oder Taube
## ("pigeon"). Gesteuert von BirdLife: fliegt einen Weg ab (fly_path), sitzt auf einem Platz (Dachrinne,
## Gesims, Geländer, Fensterladen, Efeu, Rand eines Blumenkastens, Laternenarm, Vogelhäuschen) oder ist am
## Boden – Singvögel picken und hüpfen, Tauben gehen mit nickendem Kopf und picken.
##
## Flügel: Formvariante „spread“ im Modell – angelegt beim Sitzen (0), ausgebreitet beim Fliegen (1); dazu die
## Bewegungen takeoff (Abheben), fly (Flügelschlag), glide (Gleiten), land (Landen mit Bremsen).
## Erscheint und verschwindet nie sichtbar: Wege beginnen und enden außerhalb des Blickfelds (BirdLife).

signal path_done(bird: StreetBird)

enum State { POOL, WAIT, FLY, PERCH }

## Art: "bird" (Singvogel) oder "pigeon" (Taube) – bestimmt das Verhalten am Boden
@export var kind := "bird"

## Wie weit ein Hüpfer reicht (m), wie weit sich Vögel am Boden von ihrem Platz entfernen
const HOP_DISTANCE := 0.09
const GROUND_RANGE := 0.45
const PIGEON_RANGE := 1.1
const PIGEON_WALK := 0.22
## So schnell klappen die Flügel auf und zu (s)
const SPREAD_TIME := 0.14

var life: BirdLife
var state := State.POOL
## Platz, auf dem der Vogel sitzt (siehe BirdLife: pos, face, out, kind, …)
var spot: Dictionary = {}
var flock: Dictionary = {}
## Endet der Weg außerhalb des Blickfelds (dann zurück in den Vorrat)?
var leaving := false
var species := 0

var _points := PackedVector3Array()
var _lengths := PackedFloat32Array()
var _s := 0.0
var _speed := 4.0
var _delay := 0.0
var _from_perch := false
var _takeoff_left := 0.0
var _landing := false
var _bound := 0.0
var _spread := 0.0
var _spread_target := 0.0
var _spread_index := -1
var _chirp := 0.0
var _act := 0.0
var _move_from := Vector3.ZERO
var _move_to := Vector3.ZERO
var _move_t := 1.0
var _move_time := 0.4
var _yaw_target := 0.0
var _pitch := 0.0
var _roll := 0.0
var _last_yaw := 0.0


func _ready() -> void:
	super._ready()
	set_shadows(false)
	visible = false
	if mesh:
		_spread_index = mesh.find_blend_shape_by_name(&"spread")


## Weg abfliegen: Punkte (Welt), Tempo, Verzögerung vor dem Start (Schwarm: nicht alle gleichzeitig).
## Sitzt der Vogel, bleibt er bis zum Start sitzen; aus dem Vorrat wartet er unsichtbar (außer Sicht).
func fly_path(points: PackedVector3Array, speed: float, delay: float = 0.0) -> void:
	_points = points
	_lengths = PackedFloat32Array()
	var total := 0.0
	_lengths.append(0.0)
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
		_lengths.append(total)
	_s = 0.0
	_speed = speed
	_delay = delay
	_from_perch = state == State.PERCH
	if state == State.POOL:
		state = State.WAIT
		visible = false
		if not points.is_empty():
			global_position = points[0]
	if delay <= 0.0:
		_start_flight()


func _start_flight() -> void:
	state = State.FLY
	visible = true
	_landing = false
	_bound = randf() * 0.6
	if not _points.is_empty():
		global_position = _points[0]
	_spread_target = 1.0
	if _from_perch:
		_takeoff_left = anim_length(&"takeoff") * 0.9
		play(&"takeoff", 0.06)
		if anim:
			anim.seek(0.0, true)
	else:
		_takeoff_left = 0.0
		play(&"fly", 0.1)


## Sitzen/picken/gehen auf einem Platz.
func settle(new_spot: Dictionary) -> void:
	spot = new_spot
	state = State.PERCH
	global_position = spot.pos
	_yaw_target = StreetAnimal.yaw_of(spot.face)
	_pitch = 0.0
	_roll = 0.0
	_move_t = 1.0
	_spread_target = 0.0
	_act = randf_range(0.6, 2.0)
	_chirp = randf_range(2.0, GameConfig.bird_chirp_interval.y)
	play(&"peck" if spot.kind in ["ground", "feed"] and randf() < 0.6 else &"idle", 0.2)


func hide_bird() -> void:
	state = State.POOL
	visible = false
	if anim:
		anim.stop()
	current_anim = &""
	spot = {}
	flock = {}
	leaving = false
	_spread = 0.0
	_spread_target = 0.0
	_apply_spread()


## Prüfwerkzeug: Anfang und Ende des aktuellen Flugwegs.
func debug_path_start() -> Vector3:
	return _points[0] if not _points.is_empty() else global_position


func debug_path_end() -> Vector3:
	return _points[_points.size() - 1] if not _points.is_empty() else global_position


func is_on_ground() -> bool:
	return state == State.PERCH and String(spot.get("kind", "")) == "ground"


## Wartet der Vogel noch auf seinen Start (Schwarm fliegt nacheinander los)?
func is_waiting() -> bool:
	return _delay > 0.0


## Restlicher Weg in Metern (Fliegen).
func remaining() -> float:
	return (_lengths[-1] - _s) if not _lengths.is_empty() else 0.0


func step(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0:
			_start_flight()
	match state:
		State.FLY:
			if _delay <= 0.0:
				_step_fly(delta)
		State.PERCH:
			_step_perch(delta)
	if _spread != _spread_target:
		_spread = move_toward(_spread, _spread_target, delta / SPREAD_TIME)
		_apply_spread()


func _apply_spread() -> void:
	if mesh and _spread_index >= 0:
		mesh.set_blend_shape_value(_spread_index, _spread)


func _step_fly(delta: float) -> void:
	var total := _lengths[-1] if not _lengths.is_empty() else 0.0
	var left := total - _s
	# sanft anfahren und vor der Landung langsamer (nicht bei Durchflügen und beim Wegfliegen)
	# seit der Nachbesserung von 6h ruhiger: die ersten Meter langsam steigend, vor der Landung deutlich abbremsen
	var start := GameConfig.bird_takeoff_ease
	var v := _speed * clampf(0.25 + 0.75 * smoothstep(0.0, start, _s), 0.0, 1.0)
	if not leaving:
		v = minf(v, maxf(GameConfig.bird_landing_speed, left * GameConfig.bird_landing_brake))
	_s = minf(_s + v * delta, total)
	var p := _sample(_s)
	var ahead := _sample(minf(_s + 0.3, total))
	var dir := ahead - p
	global_position = p
	if dir.length() > 0.001:
		var flat := Vector3(dir.x, 0.0, dir.z)
		if flat.length() > 0.01:
			_yaw_target = StreetAnimal.yaw_of(flat)
		var slope := dir.normalized().y
		_pitch = lerpf(_pitch, clampf(-slope, -0.5, 0.5) * 0.7, minf(1.0, delta * 5.0))
		# in Kurven leicht schräg legen
		var turn_rate := angle_difference(_last_yaw, rotation.y) / maxf(delta, 0.001)
		_roll = lerpf(_roll, clampf(turn_rate * 0.12, -0.45, 0.45), minf(1.0, delta * 4.0))
		_last_yaw = rotation.y
		_animate_flight(delta, slope, left)
	_turn(delta, 6.0)
	if _s >= total - 0.001:
		path_done.emit(self)


## Abheben, Flügelschlag und Gleiten im Wechsel (kleine Vögel fliegen in Wellen: ein paar Schläge, dann kurz
## mit angelegten Flügeln), Landen mit Bremsen.
func _animate_flight(delta: float, slope: float, left: float) -> void:
	if _takeoff_left > 0.0:
		_takeoff_left -= delta
		return
	var land_at := 0.55 if kind == "bird" else 1.1
	if not leaving and left < land_at:
		if not _landing:
			_landing = true
			play(&"land", 0.08)
			if anim:
				anim.seek(0.0, true)
		return
	if slope < -0.22 and left > 1.6:
		play(&"glide", 0.2)
		return
	if kind == "bird":
		_bound += delta
		var cycle := fmod(_bound, 0.85)
		play(&"fly" if cycle < 0.6 else &"glide", 0.12)
	else:
		play(&"fly" if slope > -0.05 else &"glide", 0.2)


func _step_perch(delta: float) -> void:
	_pitch = lerpf(_pitch, 0.0, minf(1.0, delta * 8.0))
	_roll = lerpf(_roll, 0.0, minf(1.0, delta * 8.0))
	if _move_t < 1.0:
		_move_t = minf(1.0, _move_t + delta / _move_time)
		var k := _move_t if kind == "pigeon" else smoothstep(0.0, 1.0, _move_t)
		global_position = _move_from.lerp(_move_to, k)
	_turn(delta, 6.0)
	if _delay > 0.0:
		return
	_act -= delta
	if _act <= 0.0 and _move_t >= 1.0:
		_next_activity()
	_chirp -= delta
	if _chirp <= 0.0:
		_chirp = randf_range(GameConfig.bird_chirp_interval.x, GameConfig.bird_chirp_interval.y) * (2.0 if kind == "pigeon" else 1.0)
		if life:
			life.chirp(self)


## Am Boden: picken, hüpfen (Singvogel) bzw. ein paar Schritte gehen (Taube), umschauen.
## Auf Plätzen: umschauen, manchmal umdrehen; am Futterbrett picken.
func _next_activity() -> void:
	var where := String(spot.get("kind", ""))
	if where == "ground":
		var roll := randf()
		if roll < 0.42:
			_act = randf_range(1.0, 3.0)
			play(&"peck", 0.15)
		elif roll < 0.8:
			_move_on_ground()
		else:
			_act = randf_range(0.8, 2.2)
			play(&"idle", 0.2)
	elif where == "feed":
		_act = randf_range(1.0, 3.0)
		play(&"peck" if randf() < 0.7 else &"idle", 0.2)
	else:
		_act = randf_range(2.0, 6.0)
		if randf() < 0.3:
			var face: Vector3 = spot.face
			_yaw_target = StreetAnimal.yaw_of(face) + randf_range(-0.8, 0.8)
		play(&"idle", 0.25)


func _move_on_ground() -> void:
	var center: Vector3 = spot.get("center", spot.pos)
	var reach := PIGEON_RANGE if kind == "pigeon" else GROUND_RANGE
	var step := randf_range(0.25, 0.7) if kind == "pigeon" else HOP_DISTANCE
	var a := randf() * TAU
	var dir := Vector3(sin(a), 0.0, cos(a))
	var target := global_position + dir * step
	if Vector2(target.x - center.x, target.z - center.z).length() > reach:
		dir = center - global_position
		dir.y = 0.0
		dir = dir.normalized()
		target = global_position + dir * step
	target.y = center.y
	if life and not life.ground_free(target, self):
		_act = 0.4
		return
	_move_from = global_position
	_move_to = target
	_move_t = 0.0
	_yaw_target = StreetAnimal.yaw_of(dir)
	if kind == "pigeon":
		_move_time = step / PIGEON_WALK
		_act = _move_time
		play(&"walk", 0.15)
	else:
		_move_time = 0.42
		_act = 0.45
		play(&"hop", 0.08)


func _turn(delta: float, rate: float) -> void:
	rotation.y = lerp_angle(rotation.y, _yaw_target, minf(1.0, delta * rate))
	rotation.x = _pitch
	rotation.z = _roll


## Punkt auf dem Weg nach s Metern.
func _sample(s: float) -> Vector3:
	if _points.size() < 2:
		return _points[0] if not _points.is_empty() else global_position
	var lo := 0
	var hi := _lengths.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _lengths[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg := _lengths[hi] - _lengths[lo]
	var t := (s - _lengths[lo]) / seg if seg > 0.0001 else 0.0
	return _points[lo].lerp(_points[hi], t)
