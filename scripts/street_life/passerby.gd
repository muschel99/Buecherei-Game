class_name Passerby
extends Node3D
## Ein Passant auf der Straße (seit Etappe 5a). Wohin er geht, plant StreetLife (eine Liste von
## Schritten: gehen, über die Straße gehen, stehen bleiben, verschwinden); dieses Script führt
## die Schritte aus, weicht dabei aus und steuert die Bewegung der Figur.
##
## Aufbau der Szene (scenes/street_life/passerby.tscn):
##   Passerby  (dieses Script)
##   ├── Body   AnimatableBody3D (Ebene "street_life"): die Spielfigur läuft nicht hindurch
##   └── Model  die Figur – Platzhalter (PasserbyPlaceholder) oder eine eigene .glb-Figur
## Eigene Figur: "Model" ersetzen; hat sie einen AnimationPlayer, spielt dieses Script die
## Animationen mit den Namen unten (Gehen, Stehen, Umschauen, ins Schaufenster schauen).
## Anleitung: docs/ASSET_GUIDE.md, „Eigene Passanten“.
##
## Ausweichen: Jeder Weg (StreetRoute) hat einen erlaubten Streifen. Wer vor einem steht oder
## entgegenkommt, wird als Bereich auf dem Streifen eingetragen; der Passant sucht die nächste
## freie Stelle daneben (Entgegenkommenden weicht er nach links aus, wie man in England geht).
## Ist nirgends Platz, bremst er und wartet. In die Spielfigur läuft er nie hinein.

## Am Ende der Schritte (verschwunden, zurück in den Vorrat von StreetLife).
signal finished(passerby: Passerby)

@export_group("Animationen (eigene Figur)")
## Namen der Animationen im AnimationPlayer der eigenen Figur ("" = nicht vorhanden).
@export var walk_animation: StringName = &"Walk"
@export var idle_animation: StringName = &"Idle"
## Umschauen (z. B. vor dem Überqueren der Straße). Leer = Stehen.
@export var look_animation: StringName = &"LookAround"
## Ins Schaufenster schauen. Leer = Stehen.
@export var browse_animation: StringName = &""
## Bei diesem Tempo (m/s) passen die Schritte der Geh-Animation genau; schneller oder
## langsamer spielt sie entsprechend schneller oder langsamer.
@export var walk_animation_speed: float = 1.3
## Überblenden zwischen zwei Animationen (Sekunden).
@export var animation_blend: float = 0.25
## Die Figur zeigt mit ihrer Vorderseite nach +Z (glTF/Blender-Standard). Zeigt deine Figur
## nach -Z, hier einschalten.
@export var model_faces_back: bool = false

@export_group("Körper")
## Platz, den die Figur braucht (Radius in Metern) – zum Ausweichen.
@export var radius: float = 0.25

## Größter seitlicher Schritt beim Ausweichen (m/s).
const SIDESTEP_SPEED := 0.75
## So weit voraus wird ausgewichen (Meter).
const LOOK_AHEAD := 3.6
## So weit voraus richtet sich die bevorzugte Lage nach dem Weg (Meter).
const COMFORT_LOOK_AHEAD := 1.5
## So lange (Sekunden) wartet ein Passant, wenn die Spielfigur ihm den Weg versperrt – danach
## dreht er um und geht einen anderen Weg.
const PATIENCE := 6.0
## Drehtempo der Figur (je Sekunde, weich).
const TURN_RATE := 7.0

var life: StreetLife
var active := false
## Lage unter "Outside" (x, z) und Geschwindigkeit (für andere, die ausweichen).
var pos := Vector2.ZERO
var velocity2 := Vector2.ZERO
## Eigenes Wunschtempo und bevorzugte Lage im bequemen Streifen (0 = innen, 1 = außen).
var speed_pref := 1.2
var comfort_pref := 0.5
## Auf welchem Gehweg (1 = Bücherei-Seite, -1 = gegenüber).
var side := 1
## Gerade auf der Fahrbahn (beim Überqueren) – Fahrzeuge bremsen dafür.
var on_road := false

var _actions: Array[Dictionary] = []
var _action: Dictionary = {}
var _route: StreetRoute
var _s := 0.0
var _lat := 0.0
var _dir := 1
var _target_lat := 0.0
var _speed_limit := INF
var _yaw := 0.0
var _height := 0.0
var _anim_state: StringName = &"idle"
var _anim_speed := 0.0
var _phase_time := 0.0
var _phase := 0
var _wait := 0.0
var _anim_player: AnimationPlayer
var _model: Node3D
var _body: AnimatableBody3D
var _shadows := true
var _old_lat := 0.0
var _blocked_time := 0.0


func _ready() -> void:
	_model = get_node_or_null("Model") as Node3D
	_body = get_node_or_null("Body") as AnimatableBody3D
	if _model:
		var players := _model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_anim_player = players[0]
		if model_faces_back:
			_model.rotation.y = PI
	set_active(false)


## Neues Aussehen (Platzhalter: Farben, Frisur, Kleidung) und etwas andere Größe.
func randomize_look(rng: RandomNumberGenerator) -> void:
	if _model and _model.has_method("randomize_look"):
		_model.call("randomize_look", rng)
	var size := rng.randf_range(GameConfig.passerby_height_range.x, GameConfig.passerby_height_range.y)
	scale = Vector3.ONE * size
	_shadows = true
	set_shadows(false)
	set_detail_distance(GameConfig.street_detail_distance)


func set_active(enabled: bool) -> void:
	active = enabled
	visible = enabled
	on_road = false
	velocity2 = Vector2.ZERO
	if _body:
		for shape: CollisionShape3D in _body.find_children("*", "CollisionShape3D", true, false):
			shape.set_deferred("disabled", not enabled)


## Schatten nur in der Nähe (StreetLife schaltet je nach Entfernung und Grafikstufe).
func set_shadows(enabled: bool) -> void:
	if enabled == _shadows or _model == null:
		return
	_shadows = enabled
	if _model.has_method("set_shadows"):
		_model.call("set_shadows", enabled)
	else:
		var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for part: GeometryInstance3D in _model.find_children("*", "GeometryInstance3D", true, false):
			part.cast_shadow = mode


func set_detail_distance(distance: float) -> void:
	if _model and _model.has_method("set_detail_distance"):
		_model.call("set_detail_distance", distance)


## Startet mit einer neuen Liste von Schritten (von StreetLife geplant) an der Stelle start.
func begin(start: Vector2, actions: Array[Dictionary], face: Vector2) -> void:
	pos = start
	_actions = actions
	_action = {}
	_yaw = atan2(face.x, face.y)
	_height = 0.0
	set_active(true)
	_place()
	_next_action()


## Der aktuelle Weg und die Lage darauf (für StreetLife, z. B. zum Weiterplanen).
func get_route() -> StreetRoute:
	return _route


func get_route_s() -> float:
	return _s


## Neue Schritte ab hier (z. B. nach dem Umdrehen).
func replace_actions(actions: Array[Dictionary]) -> void:
	_actions = actions
	_next_action()


## Der aktuelle Schritt (für StreetLife).
func get_action() -> Dictionary:
	return _action


## Laufrichtung auf dem aktuellen Weg (1 = s wächst).
func get_direction() -> int:
	return _dir


## Zustand als Text (Prüfwerkzeug).
func debug_text() -> String:
	var band := _band_here() if _route else Vector2.ZERO
	return "%s s=%.2f/%.2f lat=%.2f ziel=%.2f band=%s tempo=%.2f teil=%s dir=%d" % [get_action_type(), _s,
		float(_action.get("to", NAN)), _lat, _target_lat, band, minf(speed_pref, _speed_limit),
		_route.part_at(_s) if _route else "", _dir]


## Was gerade passiert ("walk", "cross", "stand", "leave").
func get_action_type() -> String:
	return String(_action.get("type", ""))


## Wird von StreetLife in jedem Physik-Schritt aufgerufen.
func step(delta: float) -> void:
	if not active:
		return
	var before := pos
	match String(_action.get("type", "")):
		"walk":
			_step_walk(delta)
		"cross":
			_step_cross(delta)
		"stand":
			_step_stand(delta)
		"leave":
			_step_leave(delta)
		_:
			_next_action()
	velocity2 = (pos - before) / maxf(delta, 0.0001)
	_place()
	_update_facing(delta)
	_animate(delta)


# --- Schritte ---

func _next_action() -> void:
	if _actions.is_empty():
		_action = {"type": "leave", "gate": false}
	else:
		_action = _actions.pop_front()
	_phase = 0
	_phase_time = 0.0
	_wait = 0.0
	match String(_action.type):
		"walk":
			_set_route(_action.route)
			_dir = 1 if float(_action.to) >= _s else -1
		"cross":
			_set_route(life.crossing_route)


func _set_route(route: StreetRoute) -> void:
	# Auf derselben Straße (Gehweg, Fahrbahn) bleibt s gleich: nur in der Nähe suchen
	var same_street := _route != null and life.is_centerline(_route) and life.is_centerline(route)
	_route = route
	var lage := route.project(pos, _s - 8.0, _s + 8.0) if same_street else route.project(pos)
	_s = lage.x
	_lat = lage.y
	_target_lat = _lat


## Gehen bis zur Stelle "to" auf dem Weg.
func _step_walk(delta: float) -> void:
	var to: float = _action.to
	_walk_along(delta, _comfort_lat())
	if (to - _s) * _dir <= 0.0:
		if _action.has("passing"):
			life.passing(self, String(_action.passing))
		_next_action()


## Über die Straße: zum Bordstein, umschauen, warten bis frei, hinüber.
func _step_cross(delta: float) -> void:
	var to_side: int = _action.to_side
	var half := GameConfig.street_width / 2.0
	var curb := (half + 0.32) * float(side)
	var far_curb := (half + 0.32) * float(to_side)
	_phase_time += delta
	match _phase:
		0:  # an den Bordstein
			_lat = move_toward(_lat, curb, speed_pref * 0.8 * delta)
			_anim_state = &"walk"
			_anim_speed = speed_pref * 0.8
			if is_equal_approx(_lat, curb):
				_phase = 1
				_phase_time = 0.0
		1:  # nach links und rechts schauen
			_anim_state = &"look"
			_anim_speed = 0.0
			if _phase_time > float(_action.get("look_time", 1.6)):
				_phase = 2
		2:  # warten, bis kein Fahrzeug kommt
			_anim_state = &"idle" if _phase_time < 4.0 else &"look"
			if life.road_clear_for(self):
				_phase = 3
				on_road = true
		3:  # hinüber (leicht schräg in Laufrichtung)
			_lat = move_toward(_lat, far_curb, speed_pref * delta)
			_s += _dir * 0.25 * delta
			_anim_state = &"walk"
			_anim_speed = speed_pref
			if is_equal_approx(_lat, far_curb):
				on_road = false
				side = to_side
				_next_action()


## Stehen bleiben und schauen (Schaufenster: "browse").
func _step_stand(delta: float) -> void:
	_phase_time += delta
	_anim_state = _action.get("anim", &"idle")
	_anim_speed = 0.0
	if _phase_time >= float(_action.get("time", 3.0)):
		_next_action()


## Verschwinden – aber nur, wenn es gerade niemand sieht. Sonst ein Stück weitergehen (am
## Straßenende) bzw. am Tor warten (in der Gasse).
func _step_leave(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.4
		if not life.is_visible_spot(pos, 1.8 * scale.y, 0.4):
			active = false
			finished.emit(self)
			return
	if bool(_action.get("gate", false)) or _route == null:
		_anim_state = &"idle"
		_anim_speed = 0.0
		return
	# Weiter geradeaus, hinter dem Ende verlängert sich der Weg
	var extra: float = _action.get("extra", 0.0)
	if extra > 20.0:
		_anim_state = &"idle"
		return
	var before := _s
	_walk_along(delta, _comfort_lat())
	_action.extra = extra + absf(_s - before)


## Ein Stück am Weg entlang, mit Ausweichen. want = Wunsch-Lage (lat).
func _walk_along(delta: float, want: float) -> void:
	var band := _band_here()
	_target_lat = _avoid(want, band)
	_old_lat = _lat
	_lat = move_toward(_lat, _target_lat, SIDESTEP_SPEED * delta)
	_lat = clampf(_lat, band.x, band.y)
	var speed := minf(speed_pref, _speed_limit)
	if speed < 0.02:
		speed = 0.0
	var ds := speed * delta
	if ds > 0.0:
		# In Kurven ist der Weg neben der Mittellinie länger oder kürzer: ausgleichen
		var p0 := _route.point_at(_s, _lat)
		var p1 := _route.point_at(_s + _dir * ds, _lat)
		var real := p0.distance_to(p1)
		if real > 0.0001:
			ds *= ds / real
	var new_s := _s + _dir * ds
	var new_pos := _route.point_at(new_s, _lat)
	if life.blocks_move(self, new_pos):
		# Nie in jemanden hinein: nur zur Seite, sonst stehen bleiben
		new_s = _s
		new_pos = _route.point_at(_s, _lat)
		if life.blocks_move(self, new_pos):
			new_pos = pos
			_lat = _old_lat
		speed = 0.0
	_s = new_s
	pos = new_pos
	# Versperrt die Spielfigur lange den Weg (z. B. in einer schmalen Gasse): umdrehen
	if speed < 0.05 and life.player_blocks(self):
		_blocked_time += delta
		if _blocked_time > PATIENCE:
			_blocked_time = 0.0
			life.turn_around(self)
	else:
		_blocked_time = maxf(0.0, _blocked_time - delta)
	_anim_state = &"walk" if speed > 0.05 else &"idle"
	_anim_speed = speed


## Bevorzugte Lage im bequemen Streifen des Wegs – schon ein Stück voraus geschaut, damit man
## rechtzeitig in eine Engstelle (Torbogen) hineinschwenkt.
func _comfort_lat() -> float:
	var comfort := _route.comfort_at(_s + _dir * COMFORT_LOOK_AHEAD)
	return lerpf(comfort.x, comfort.y, comfort_pref)


## Erlaubter Bereich hier und kurz voraus zusammen: Vor einer Engstelle darf man schon dorthin
## gehen, wo man gleich sein muss.
func _band_here() -> Vector2:
	var here := _route.band_at(_s)
	var ahead := _route.band_at(_s + _dir * 1.0)
	return Vector2(minf(here.x, ahead.x), maxf(here.y, ahead.y))


## Sucht die nächste freie Lage zur Wunsch-Lage und setzt das Tempo-Limit (bremsen).
func _avoid(want: float, band: Vector2) -> float:
	_speed_limit = INF
	var intervals: Array[Vector4] = []  # (von, bis, entgegenkommend 0/1, Abstand voraus)
	for obstacle in life.obstacles_near(self, LOOK_AHEAD + 1.5):
		var lage := _route.project(obstacle.pos, _s - 2.0, _s + 2.0 + LOOK_AHEAD) if _dir > 0 \
			else _route.project(obstacle.pos, _s - 2.0 - LOOK_AHEAD, _s + 2.0)
		var along := (lage.x - _s) * _dir
		if along < -0.45 or along > LOOK_AHEAD:
			continue
		var forward := _route.direction_at(lage.x) * float(_dir)
		var their_speed: float = (obstacle.vel as Vector2).dot(forward)
		# Wer vor mir in meine Richtung schneller läuft, ist kein Hindernis
		if along > 0.0 and their_speed > 0.2 and their_speed >= speed_pref * 0.95:
			continue
		var gap: float = radius * scale.x + float(obstacle.radius) + (0.06 if obstacle.kind == "walker" else 0.12)
		intervals.append(Vector4(lage.y - gap, lage.y + gap, 1.0 if their_speed < -0.2 else 0.0, along))
		if along > 0.0 and absf(_lat - lage.y) < gap - 0.02:
			# Es steht direkt vor mir: bremsen (hinter Langsameren her: deren Tempo)
			var limit := speed_pref * clampf((along - gap - 0.05) / 0.9, 0.0, 1.0)
			if their_speed > 0.1:
				limit = maxf(limit, minf(their_speed, speed_pref))
			_speed_limit = minf(_speed_limit, limit)
	if intervals.is_empty():
		return clampf(want, band.x, band.y)
	var left := float(_dir)  # lat > 0 liegt links der Laufrichtung, wenn s wächst
	var best := want
	var best_cost := INF
	var candidates := PackedFloat32Array([want, _target_lat, band.x, band.y])
	for iv in intervals:
		candidates.append(iv.x - 0.01)
		candidates.append(iv.y + 0.01)
	for c in candidates:
		if c < band.x - 0.001 or c > band.y + 0.001:
			continue
		var cost := absf(c - want) + absf(c - _target_lat) * 0.3
		for iv in intervals:
			# Wie tief steckt diese Lage im Bereich eines anderen? (Ist nirgends ganz frei, gewinnt
			# die Lage mit der kleinsten Überschneidung – meist der Rand des Streifens.)
			var depth := minf(c - iv.x, iv.y - c)
			if depth > 0.0:
				cost += 10.0 + depth * 20.0 / maxf(0.5, iv.w)
			# Entgegenkommenden links ausweichen (beide tun es – so treffen sie sich nie)
			if iv.z > 0.5 and signf(c - (iv.x + iv.y) / 2.0) != signf(left):
				cost += 1.0
		if cost < best_cost:
			best_cost = cost
			best = c
	return clampf(best, band.x, band.y)


# --- Darstellung ---

func _place() -> void:
	var y := 0.0
	if _route and _route.parts.size() > 0 and life and life.is_centerline(_route):
		if absf(_lat) < GameConfig.street_width / 2.0:
			y = -GameConfig.curb_height
	# Bordstein hinunter und hinauf: ein kleiner, schneller Schritt
	_height = move_toward(_height, y, get_physics_process_delta_time() * 1.5)
	position = Vector3(pos.x, _height, pos.y)


func _update_facing(delta: float) -> void:
	var target := _yaw
	if _action.get("type") == "stand" and _action.has("face"):
		var face: Vector2 = _action.face
		target = atan2(face.x, face.y)
	elif _action.get("type") == "cross" and _phase in [1, 2]:
		var normal := _route.normal_at(_s) * -float(side)
		target = atan2(normal.x, normal.y)
	elif _action.get("type") == "leave" and bool(_action.get("gate", false)) and _action.has("face"):
		var face: Vector2 = _action.face
		target = atan2(face.x, face.y)
	elif velocity2.length() > 0.15:
		target = atan2(velocity2.x, velocity2.y)
	_yaw = lerp_angle(_yaw, target, minf(1.0, delta * TURN_RATE))
	rotation.y = _yaw


func _animate(delta: float) -> void:
	if _anim_player:
		var anim_name: StringName = walk_animation
		match _anim_state:
			&"idle":
				anim_name = idle_animation
			&"look":
				anim_name = look_animation if look_animation != &"" else idle_animation
			&"browse":
				anim_name = browse_animation if browse_animation != &"" else idle_animation
		if anim_name != &"" and _anim_player.has_animation(anim_name):
			if _anim_player.current_animation != anim_name:
				_anim_player.play(anim_name, animation_blend)
			_anim_player.speed_scale = _anim_speed / walk_animation_speed if _anim_state == &"walk" else 1.0
	elif _model and _model.has_method("animate"):
		_model.call("animate", _anim_state, _anim_speed / scale.x, delta)
