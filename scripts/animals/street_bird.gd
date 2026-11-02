class_name StreetBird
extends StreetAnimal
## Ein kleiner Vogel (seit Etappe 6g). Gesteuert von BirdLife: fliegt einen Weg ab (fly_path), sitzt auf
## einem Platz (Dachrinne, Gesims, Fensterbank, Laternenarm, Vogelhäuschen) oder pickt und hüpft auf dem
## Gehweg. Zwitschert ab und zu (räumlich, am Vogel). Erscheint und verschwindet nie sichtbar: Wege
## beginnen und enden außerhalb des Blickfelds (hinter einem Dach), das prüft BirdLife.

signal path_done(bird: StreetBird)

enum State { POOL, FLY, PERCH }

## Wie weit ein Hüpfer reicht (m) und wie weit sich Vögel am Boden von ihrem Platz entfernen
const HOP_DISTANCE := 0.09
const GROUND_RANGE := 0.45

var life: BirdLife
var state := State.POOL
## Platz, auf dem der Vogel sitzt (siehe BirdLife: pos, face, out, kind, ground)
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
var _chirp := 0.0
var _act := 0.0
var _act_kind := &"idle"
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_t := 1.0
var _yaw_target := 0.0
var _pitch := 0.0


func _ready() -> void:
	super._ready()
	set_shadows(false)
	visible = false


## Weg abfliegen: Punkte (Welt), Tempo, Verzögerung vor dem Start (Schwarm: nicht alle gleichzeitig).
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
	state = State.FLY
	visible = true
	if not points.is_empty():
		global_position = points[0]
	if delay <= 0.0:
		play(&"fly", 0.1, 1.0)


## Sitzen/picken auf einem Platz (ohne Flug, z. B. nach der Landung).
func settle(new_spot: Dictionary) -> void:
	spot = new_spot
	state = State.PERCH
	global_position = spot.pos
	_yaw_target = StreetAnimal.yaw_of(spot.face)
	_pitch = 0.0
	_act = randf_range(0.5, 2.0)
	_act_kind = &"idle"
	_chirp = randf_range(2.0, GameConfig.bird_chirp_interval.y)
	play(&"peck" if spot.kind in ["ground", "feed"] and randf() < 0.6 else &"idle", 0.15)


func hide_bird() -> void:
	state = State.POOL
	visible = false
	spot = {}
	flock = {}
	leaving = false


func is_on_ground() -> bool:
	return state == State.PERCH and String(spot.get("kind", "")) == "ground"


## Restlicher Weg in Metern (Fliegen).
func remaining() -> float:
	return (_lengths[-1] - _s) if not _lengths.is_empty() else 0.0


func step(delta: float) -> void:
	match state:
		State.FLY:
			_step_fly(delta)
		State.PERCH:
			_step_perch(delta)


func _step_fly(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0:
			play(&"fly", 0.1, 1.0)
		return
	var total := _lengths[-1] if not _lengths.is_empty() else 0.0
	var left := total - _s
	# sanft anfahren und vor der Landung langsamer
	var v := _speed * clampf(0.45 + _s / 1.2, 0.0, 1.0)
	if not leaving:
		v = minf(v, maxf(1.1, left * 1.6))
	_s = minf(_s + v * delta, total)
	var p := _sample(_s)
	var ahead := _sample(minf(_s + 0.25, total))
	var dir := ahead - p
	global_position = p
	if dir.length() > 0.001:
		var flat := Vector3(dir.x, 0.0, dir.z)
		if flat.length() > 0.01:
			_yaw_target = StreetAnimal.yaw_of(flat)
		_pitch = lerpf(_pitch, clampf(-dir.normalized().y, -0.6, 0.6) * 0.8, minf(1.0, delta * 6.0))
		# im Sinkflug gleiten, sonst flattern (die letzten Meter vor der Landung flattern)
		if dir.normalized().y < -0.25 and left > 1.4:
			play(&"glide", 0.25, 1.0)
		else:
			play(&"fly", 0.15, 1.0)
	_turn(delta, 9.0)
	if _s >= total - 0.001:
		path_done.emit(self)


func _step_perch(delta: float) -> void:
	_pitch = lerpf(_pitch, 0.0, minf(1.0, delta * 8.0))
	if _hop_t < 1.0:
		_hop_t = minf(1.0, _hop_t + delta / 0.42)
		global_position = _hop_from.lerp(_hop_to, smoothstep(0.0, 1.0, _hop_t))
	_turn(delta, 6.0)
	_act -= delta
	if _act <= 0.0 and _hop_t >= 1.0:
		_next_activity()
	_chirp -= delta
	if _chirp <= 0.0:
		_chirp = randf_range(GameConfig.bird_chirp_interval.x, GameConfig.bird_chirp_interval.y)
		if life:
			life.chirp(self)


## Am Boden: picken, ein paar Hüpfer, umschauen. Auf Plätzen: umschauen, manchmal umdrehen.
func _next_activity() -> void:
	var kind := String(spot.get("kind", ""))
	if kind == "ground":
		var roll := randf()
		if roll < 0.45:
			_act_kind = &"peck"
			_act = randf_range(1.0, 3.0)
			play(&"peck", 0.15)
		elif roll < 0.8:
			# Hüpfer in eine neue Richtung, aber nicht weit weg vom Platz
			var center: Vector3 = spot.get("center", spot.pos)
			var a := randf() * TAU
			var dir := Vector3(sin(a), 0.0, cos(a))
			var target := global_position + dir * HOP_DISTANCE
			if Vector2(target.x - center.x, target.z - center.z).length() > GROUND_RANGE:
				dir = (center - global_position)
				dir.y = 0.0
				dir = dir.normalized()
				target = global_position + dir * HOP_DISTANCE
			target.y = center.y
			if life and not life.ground_free(target, self):
				_act = 0.4
				return
			_hop_from = global_position
			_hop_to = target
			_hop_t = 0.0
			_yaw_target = StreetAnimal.yaw_of(dir)
			_act_kind = &"hop"
			_act = 0.45
			play(&"hop", 0.08)
		else:
			_act_kind = &"idle"
			_act = randf_range(0.8, 2.2)
			play(&"idle", 0.2)
	elif kind == "feed":
		_act = randf_range(1.0, 3.0)
		play(&"peck" if randf() < 0.7 else &"idle", 0.2)
	else:
		_act = randf_range(2.0, 6.0)
		if randf() < 0.3:
			var face: Vector3 = spot.face
			_yaw_target = StreetAnimal.yaw_of(face) + randf_range(-0.9, 0.9)
		play(&"idle", 0.25)


func _turn(delta: float, rate: float) -> void:
	rotation.y = lerp_angle(rotation.y, _yaw_target, minf(1.0, delta * rate))
	rotation.x = _pitch


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
