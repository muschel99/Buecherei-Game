class_name StreetVehicle
extends Node3D
## Ein Fahrzeug auf der Straße (seit Etappe 5a): Fahrrad, Auto oder Lieferwagen. Fährt von
## einem versteckten Straßenende zum anderen auf der Mittellinie der Straße (StreetPaths), im
## Linksverkehr wie in England. Bremst weich für alles, was vor ihm auf der Fahrbahn ist
## (Fußgänger beim Überqueren, die Spielfigur, langsamere Fahrzeuge) und fährt nie jemanden um.
## Fahrräder (can_swerve) fahren um Hindernisse herum, wenn Platz ist, statt anzuhalten.
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
@export var can_swerve: bool = false

@export_group("Animation (eigenes Modell)")
## Name der Fahr-Animation im AnimationPlayer des Modells ("" = keine) und das Tempo (m/s), bei
## dem sie genau passt.
@export var move_animation: StringName = &""
@export var move_animation_speed: float = 4.0

## Bremsen und Anfahren (m/s²)
const BRAKE := 4.0
const ACCELERATE := 1.6
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
	set_active(true)
	_place(0.0)


## Lage auf der Straße (s, lat) und Fahrspur.
func get_s() -> float:
	return _s


func get_lat() -> float:
	return _lat


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
	if (_s - _end_s) * direction >= 0.0:
		_leave(delta)


## Wie schnell darf ich gerade fahren? (Bremsen für Hindernisse vor mir.)
func _wanted_speed() -> float:
	var limit := cruise_speed
	var swerve := lane()
	# Unter dem Torbogen (und kurz davor/dahinter) gehen Fußgänger am Rand: langsam und mit
	# Abstand zur Mitte hin fahren
	var part := _route.part_at(_s + direction * length)
	if part in ["passage", "before_passage", "after_passage"] or _route.part_at(_s) in ["passage", "before_passage", "after_passage"]:
		limit = minf(limit, PASSAGE_SPEED)
		swerve = lane() * PASSAGE_LANE
	for obstacle in life.road_obstacles(self):
		var lage := _route.project(obstacle.pos, _s - 2.0, _s + LOOK_AHEAD) if direction > 0 \
			else _route.project(obstacle.pos, _s - LOOK_AHEAD, _s + 2.0)
		var along := (lage.x - _s) * direction - length / 2.0 - float(obstacle.reach)
		if along < -0.3 or along > LOOK_AHEAD:
			continue
		# Menschen bekommen mehr Abstand als Fahrzeuge
		var person: bool = obstacle.kind in ["walker", "player"]
		# Entgegenkommende fahren in ihrer eigenen Spur vorbei: nur bremsen, wenn sie sich berühren
		# würden (sonst warten im engen Torbogen beide aufeinander)
		var margin := PERSON_GAP if person else (0.05 if obstacle.kind == "vehicle_oncoming" else 0.25)
		var half := width / 2.0 + float(obstacle.radius) + margin
		if absf(lage.y - _lat) >= half and absf(lage.y - _target_lat) >= half:
			continue
		if can_swerve and obstacle.kind != "vehicle_oncoming":
			# Fahrrad: zur Straßenmitte hin vorbei, wenn dort Platz ist
			var around := lage.y - signf(lane()) * (half + 0.1)
			if absf(around) < GameConfig.street_width / 2.0 - 0.35 and life.lane_free(self, around, along + 8.0):
				swerve = around
				if person:
					limit = minf(limit, PASS_SPEED + along * 0.4)  # an Menschen langsam vorbei
				if absf(lage.y - _lat) < half:
					# Noch nicht weit genug zur Seite: so bremsen, dass es vorher reicht
					limit = minf(limit, sqrt(2.0 * BRAKE * maxf(0.0, along - 0.6)))
				continue
		var stop := maxf(0.0, along - STOP_GAP)
		var their: float = obstacle.get("speed", 0.0)
		limit = minf(limit, maxf(sqrt(2.0 * BRAKE * stop), 0.0) + maxf(0.0, their) * clampf(stop / 6.0, 0.0, 1.0))
	_target_lat = swerve
	return limit


func _drive(delta: float, wanted: float) -> void:
	if wanted < speed:
		speed = maxf(wanted, speed - BRAKE * 1.5 * delta)
	else:
		speed = minf(wanted, speed + ACCELERATE * delta)
	if wanted < 0.05 and speed < 0.3:
		speed = 0.0
	_lat = move_toward(_lat, _target_lat, SWERVE_SPEED * delta)
	var ds := speed * delta
	if ds > 0.0:
		var p0 := _route.point_at(_s, _lat)
		var p1 := _route.point_at(_s + direction * ds, _lat)
		var real := p0.distance_to(p1)
		if real > 0.0001:
			ds *= ds / real
	_s += direction * ds
	_place(delta)
	if _model and _model.has_method("animate"):
		_model.call("animate", speed, delta)
	elif _anim_player and move_animation != &"" and _anim_player.has_animation(move_animation):
		if _anim_player.current_animation != move_animation:
			_anim_player.play(move_animation)
		_anim_player.speed_scale = speed / maxf(0.1, move_animation_speed)


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
	rotation.y = atan2(forward.x, forward.y)
