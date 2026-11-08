class_name StreetVehicle
extends Node3D
## Ein Fahrzeug auf der Straße (seit Etappe 5a): Fahrrad, Auto oder Lieferwagen. Fährt von
## einem versteckten Straßenende zum anderen auf der Mittellinie der Straße (StreetPaths), im
## Linksverkehr wie in England. Bremst weich für alles, was vor ihm auf der Fahrbahn ist
## (Fußgänger beim Überqueren, die Spielfigur, langsamere Fahrzeuge) und fährt nie jemanden um.
## Fahrräder (is_bike) fahren nie um Hindernisse herum (seit Nachbesserung 4 von 6h): schon einige Meter vorher werden
## sie langsamer und halten davor an.
##
## Aufbau der Szenen (scenes/street_life/cyclist.tscn, car.tscn, delivery_van.tscn):
##   <Fahrzeug>  (dieses Script oder DeliveryVan)
##   ├── Body    AnimatableBody3D (Ebene "street_life"): die Spielfigur läuft nicht hindurch
##   └── Model   Platzhalter oder eigenes Modell (Vorderseite nach +Z, Räder auf y = 0)
## Ein Platzhalter-Modell darf die Methoden build(rng, farbe), animate(tempo, delta) und
## set_shadows(an) haben; ein eigenes Modell braucht nichts davon. Hat ein eigenes Modell einen
## AnimationPlayer mit der Animation move_animation (z. B. Treten), läuft sie passend zum Tempo.

## Am Ende der Fahrt (verschwunden, zurück in den Vorrat von StreetLife).
signal finished(vehicle: StreetVehicle)

@export_group("Maße")
## Länge und Breite (Meter) – zum Bremsen und Ausweichen.
@export var length: float = 3.6
@export var width: float = 1.6
## Abstand der Fahrspur von der Straßenmitte (Meter, im Linksverkehr).
@export var lane_offset: float = 1.25
## Fährt um Hindernisse herum (Fahrrad), statt anzuhalten.
@export var is_bike: bool = false

@export_group("Animation (eigenes Modell)")
## Name der Fahr-Animation im AnimationPlayer des Modells ("" = keine) und das Tempo (m/s), bei
## dem sie genau passt.
@export var move_animation: StringName = &""
@export var move_animation_speed: float = 4.0

## Bremsen und Anfahren (m/s²)
const BRAKE := 4.0
const ACCELERATE := 1.6
## Seit Etappe 6c: so schnell ändert sich die Beschleunigung (m/s³) – Anfahren beginnt sanft und läuft
## sanft aus; so schnell folgt die Fahrzeugrichtung der Kurve (je Sekunde)
const JERK := 2.4
const TURN_FOLLOW := 6.0
## Beim Bremsen baut sich die Verzögerung schneller auf (m/s³); so viel zu schnell (m/s) darf ein
## Fahrzeug während des weichen Übergangs sein, sonst bremst es sofort
const JERK_BRAKE := 7.0
const BRAKE_SLACK := 0.6
## Abstand, mit dem vor einem Hindernis gehalten wird (Meter, zwischen den Rändern).
const STOP_GAP := 1.6
## So weit voraus wird geschaut (Meter).
const LOOK_AHEAD := 22.0
## Seitliches Ausweichen (m/s).
const SWERVE_SPEED := 1.2
## Seitlicher Abstand zu Menschen (Meter, zwischen den Rändern) und Tempo beim Vorbeifahren (m/s).
const PERSON_GAP := 0.55
const PASS_SPEED := 2.0
## Unter dem Torbogen: höchstens so schnell (m/s) und so viel der normalen Spur (näher zur Mitte).
const PASSAGE_SPEED := 3.0
const PASSAGE_LANE := 0.72
## … und zwar weich: so viele Meter vor und hinter dem Bogen beginnt bzw. endet der Übergang (seit der Nachbesserung
## von 6h – vorher sprang die Spur am Bogen, die Fahrzeuge schlugen einen Haken)
const PASSAGE_EASE := 12.0
## Bereich des Torbogens auf der Mittellinie (s von – bis, samt Vorlauf; einmal ausgemessen)
static var _passage := Vector2(NAN, NAN)

var life: StreetLife
var active := false
var pos := Vector2.ZERO
var speed := 0.0
var cruise_speed := 5.0
## Fahrtrichtung auf der Mittellinie: 1 = s wächst (zum abbiegenden Ende hin), -1 = zurück.
var direction := 1

var _route: StreetRoute
var _s := 0.0
var _lat := 0.0
var _target_lat := 0.0
var _end_s := 0.0
var _extra := 0.0
var _check := 0.0
var _model: Node3D
var _body: AnimatableBody3D
var _anim_player: AnimationPlayer
## Beschleunigung jetzt (m/s², für weiches Anfahren und das Nicken der Karosserie) und Drehrate (rad/s)
var _accel := 0.0
var _turn_rate := 0.0
var _yaw := 0.0
var _yaw_ready := false
## Geräusche (seit Etappe 6e): Abstand zum nächsten Menschen vor mir auf der Fahrbahn (INF = keiner),
## wie lange ich schon für ihn warte, Pause bis zum nächsten Hupen/Klingeln
var _person_ahead := INF
var _waiting := 0.0
var _sound_cool := 0.0
var _bell_timer := 0.0


func _ready() -> void:
	_model = get_node_or_null("Model") as Node3D
	_body = get_node_or_null("Body") as AnimatableBody3D
	if _model:
		var players := _model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_anim_player = players[0]
	set_active(false)


func set_active(enabled: bool) -> void:
	active = enabled
	visible = enabled
	if _body:
		for shape: CollisionShape3D in _body.find_children("*", "CollisionShape3D", true, false):
			shape.set_deferred("disabled", not enabled)


## Neues Aussehen (Platzhalter: Farben).
func randomize_look(rng: RandomNumberGenerator, color: Color) -> void:
	if _model and _model.has_method("build"):
		_model.call("build", rng, color)


func set_shadows(enabled: bool) -> void:
	if _model == null:
		return
	if _model.has_method("set_shadows"):
		_model.call("set_shadows", enabled)
		return
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part: GeometryInstance3D in _model.find_children("*", "GeometryInstance3D", true, false):
		part.cast_shadow = mode


## Losfahren am versteckten Ende (dir = 1: vom Anfang der Mittellinie, -1: vom Ende).
func begin(route: StreetRoute, dir: int, cruise: float) -> void:
	_route = route
	direction = dir
	cruise_speed = cruise
	_s = 0.0 if dir > 0 else route.length()
	_end_s = route.length() + 1.0 if dir > 0 else -1.0
	_lat = lane()
	_target_lat = _lat
	_extra = 0.0
	speed = cruise * 0.8
	_accel = 0.0
	_waiting = 0.0
	_bell_timer = randf_range(GameConfig.bike_bell_random_interval.x * 0.3, GameConfig.bike_bell_random_interval.y)
	set_active(true)
	_place(0.0)


## Lage auf der Straße (s, lat) und Fahrspur.
func get_s() -> float:
	return _s


func get_lat() -> float:
	return _lat


## Wie sehr gilt der Torbogen hier (0 = gar nicht, 1 = darunter): weich über PASSAGE_EASE Meter davor und dahinter.
func _passage_blend() -> float:
	if is_nan(_passage.x):
		_passage = Vector2(INF, -INF)
		var s := 0.0
		var total := _route.length()
		while s <= total:
			if _route.part_at(s) in ["passage", "before_passage", "after_passage"]:
				_passage = Vector2(minf(_passage.x, s), maxf(_passage.y, s))
			s += 0.25
	if _passage.x > _passage.y:
		return 0.0
	# vorn am Fahrzeug messen (es soll schon gerade stehen, wenn die Nase hineinfährt)
	var front := _s + direction * length / 2.0
	var d := maxf(maxf(_passage.x - front, front - _passage.y), 0.0)
	var back := _s - direction * length / 2.0
	d = minf(d, maxf(maxf(_passage.x - back, back - _passage.y), 0.0))
	return 1.0 - smoothstep(0.0, PASSAGE_EASE, d)


func lane() -> float:
	return StreetPaths.lane_offset(direction, lane_offset)


## Abstand (Rand zu Rand) zu einem Passanten – für das Prüfwerkzeug.
func distance_to_walker(walker: Passerby) -> float:
	var forward := Vector2(sin(rotation.y), cos(rotation.y))
	var d := walker.pos - pos
	var dx := maxf(absf(d.dot(forward)) - length / 2.0, 0.0)
	var dy := maxf(absf(d.dot(Vector2(forward.y, -forward.x))) - width / 2.0, 0.0)
	return sqrt(dx * dx + dy * dy) - walker.radius * walker.scale.x


## Zustand als Text (Prüfwerkzeug).
func debug_text() -> String:
	return "%s s=%.1f lat=%.2f ziel=%.2f tempo=%.1f richtung=%d" % [name, _s, _lat, _target_lat, speed, direction]


## Wird von StreetLife in jedem Physik-Schritt aufgerufen.
func step(delta: float) -> void:
	if not active:
		return
	_drive(delta, _wanted_speed())
	_sounds(delta)
	if (_s - _end_s) * direction >= 0.0:
		_leave(delta)


## Wie schnell darf ich gerade fahren? (Bremsen für Hindernisse vor mir.)
func _wanted_speed() -> float:
	var limit := cruise_speed
	_person_ahead = INF
	var swerve := lane()
	# Unter dem Torbogen (und kurz davor/dahinter) gehen Fußgänger am Rand: langsam und mit
	# Abstand zur Mitte hin fahren
	var gate := _passage_blend()
	if gate > 0.0:
		limit = minf(limit, lerpf(cruise_speed, PASSAGE_SPEED, gate))
		swerve = lane() * lerpf(1.0, PASSAGE_LANE, gate)
	for obstacle in life.road_obstacles(self):
		var lage := _route.project(obstacle.pos, _s - 2.0, _s + LOOK_AHEAD) if direction > 0 \
			else _route.project(obstacle.pos, _s - LOOK_AHEAD, _s + 2.0)
		var along := (lage.x - _s) * direction - length / 2.0 - float(obstacle.reach)
		if along < -0.3 or along > LOOK_AHEAD:
			continue
		if obstacle.kind == "cat_near":
			# Katze am Straßenrand: rechtzeitig langsamer (sie könnte loslaufen)
			limit = minf(limit, GameConfig.vehicle_cat_near_speed + maxf(0.0, along) * 0.35)
			continue
		# Katzen auf der Fahrbahn laufen quer hinüber: für sie zählt die ganze Breite (sonst fährt man hindurch, wenn sie
		# gerade noch auf der anderen Seite der Fahrbahn sind)
		var cat: bool = obstacle.kind == "cat"
		# Menschen bekommen mehr Abstand als Fahrzeuge
		var person: bool = obstacle.kind in ["walker", "player"]
		# Entgegenkommende fahren in ihrer eigenen Spur vorbei: nur bremsen, wenn sie sich berühren
		# würden (sonst warten im engen Torbogen beide aufeinander)
		var margin := PERSON_GAP if person else (0.05 if obstacle.kind == "vehicle_oncoming" else 0.25)
		var half := width / 2.0 + float(obstacle.radius) + margin
		if not cat and absf(lage.y - _lat) >= half and absf(lage.y - _target_lat) >= half:
			continue
		if person and not obstacle.get("on_road", true):
			# am Bordstein bzw. Rand (seit Etappe 6f): nicht anhalten, nicht ausweichen, nicht klingeln – nur
			# langsam vorbei
			limit = minf(limit, PASS_SPEED + maxf(0.0, along) * 0.4)
			continue
		if person:
			_person_ahead = minf(_person_ahead, along)
		# Vor dem Hindernis anhalten: Katzen mit mehr Abstand und sanft, Fahrräder bremsen schon einige Meter vorher
		var gap := STOP_GAP + 1.0 if cat else (GameConfig.bike_stop_gap if is_bike else STOP_GAP)
		var stop := maxf(0.0, along - gap)
		var their: float = obstacle.get("speed", 0.0)
		var brake := GameConfig.bike_brake if is_bike else (BRAKE * (0.5 if cat else 1.0))
		limit = minf(limit, maxf(sqrt(2.0 * brake * stop), 0.0) + maxf(0.0, their) * clampf(stop / 6.0, 0.0, 1.0))
	_target_lat = swerve
	return limit


func _drive(delta: float, wanted: float) -> void:
	var before := speed
	if wanted < speed:
		# Bremsen: die Verzögerung baut sich weich auf und läuft vor dem Halten aus (kein Ruck)
		var need := minf(BRAKE * 1.5, (speed - wanted) * 2.2 + 0.3)
		_accel = move_toward(minf(_accel, 0.0), -need, JERK_BRAKE * delta)
		speed = maxf(wanted, speed + _accel * delta)
		# Sicherheitsnetz: deutlich zu schnell (jemand tritt plötzlich auf die Fahrbahn) = sofort bremsen
		if speed > wanted + BRAKE_SLACK:
			speed = maxf(wanted + BRAKE_SLACK, speed - BRAKE * 1.5 * delta)
	else:
		# Anfahren: Beschleunigung baut sich langsam auf und läuft vor dem Wunschtempo aus
		var target := minf(ACCELERATE, (wanted - speed) * 1.4)
		_accel = move_toward(_accel, target, JERK * delta)
		speed = minf(wanted, speed + maxf(_accel, 0.0) * delta)
	if wanted < 0.05 and speed < 0.12:
		speed = 0.0
		_accel = 0.0
	var real_accel := (speed - before) / maxf(delta, 0.0001)
	# seitlich nie schneller als es zum Tempo passt (langsam fahrend kein Sprung zur Seite)
	_lat = move_toward(_lat, _target_lat, minf(SWERVE_SPEED, maxf(0.25, speed * 0.45)) * delta)
	var ds := speed * delta
	if ds > 0.0:
		var p0 := _route.point_at(_s, _lat)
		var p1 := _route.point_at(_s + direction * ds, _lat)
		var real := p0.distance_to(p1)
		if real > 0.0001:
			ds *= ds / real
	_s += direction * ds
	_place(delta)
	if _model and _model.has_method("animate_drive"):
		_model.call("animate_drive", speed, delta, real_accel, _turn_rate)
	elif _model and _model.has_method("animate"):
		_model.call("animate", speed, delta)
	elif _anim_player and move_animation != &"" and _anim_player.has_animation(move_animation):
		if _anim_player.current_animation != move_animation:
			_anim_player.play(move_animation)
		_anim_player.speed_scale = speed / maxf(0.1, move_animation_speed)


## Hupen und Klingeln (seit Etappe 6e): Autos hupen kurz und freundlich, wenn jemand vor ihnen auf der Fahrbahn
## steht und sie schon einen Moment warten; Fahrräder klingeln, wenn jemand vor ihnen ist, und ab und zu so.
func _sounds(delta: float) -> void:
	_sound_cool = maxf(0.0, _sound_cool - delta)
	if _model == null or not is_visible_in_tree():
		return
	if is_bike:
		_bell_timer -= delta
		var someone := _person_ahead < 8.0
		if (someone and _sound_cool <= 0.0) or _bell_timer <= 0.0:
			if _model.has_method("ring"):
				_model.call("ring")
			_sound_cool = GameConfig.bike_bell_cooldown
			_bell_timer = randf_range(GameConfig.bike_bell_random_interval.x, GameConfig.bike_bell_random_interval.y)
		return
	_waiting = _waiting + delta if _person_ahead < 10.0 and speed < 2.5 else 0.0
	if _waiting > GameConfig.car_horn_wait and _sound_cool <= 0.0:
		if _model.has_method("honk"):
			_model.call("honk")
		_sound_cool = GameConfig.car_horn_cooldown


## Am Ende: verschwinden, sobald es niemand sieht – sonst noch ein Stück weiterfahren.
func _leave(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.3
	if not life.is_visible_spot(pos, 1.8, length / 2.0 + 0.5) or _extra > 40.0:
		active = false
		finished.emit(self)
	else:
		_end_s += direction * 2.0
		_extra += 2.0


func _place(delta: float) -> void:
	var before := pos
	pos = _route.point_at(_s, _lat)
	var forward := _route.direction_at(_s) * float(direction)
	var moved := pos - before
	if delta > 0.0 and moved.length() > 0.001:
		forward = moved.normalized()
	position = Vector3(pos.x, -GameConfig.curb_height, pos.y)
	# Richtung weich nachführen (keine Ruckler in Kurven und beim Ausweichen)
	var target_yaw := atan2(forward.x, forward.y)
	if not _yaw_ready or delta <= 0.0:
		_yaw = target_yaw
		_yaw_ready = true
		_turn_rate = 0.0
	else:
		var turned := lerp_angle(_yaw, target_yaw, minf(1.0, delta * TURN_FOLLOW))
		_turn_rate = lerpf(_turn_rate, angle_difference(_yaw, turned) / delta, minf(1.0, delta * 4.0))
		_yaw = turned
	rotation.y = _yaw
