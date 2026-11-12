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
## Sitzen (z. B. auf der Bank im Garten; Gesäß auf Sitzhöhe 0,45 m). Leer = Stehen.
@export var sit_animation: StringName = &"Sit"
## Bei diesem Tempo (m/s) passen die Schritte der Geh-Animation genau; schneller oder
## langsamer spielt sie entsprechend schneller oder langsamer.
@export var walk_animation_speed: float = 1.3
## Überblenden zwischen zwei Animationen (Sekunden).
@export var animation_blend: float = 0.25
## Die Figur zeigt mit ihrer Vorderseite nach +Z (glTF/Blender-Standard). Zeigt deine Figur
## nach -Z, hier einschalten.
@export var model_faces_back: bool = false

## Die Figur bewegt sich selbst (Methode animate des Modells, z. B. ChibiPasserbyModel mit
## eigenem AnimationPlayer) – dann sucht Passerby keinen AnimationPlayer.
@export var model_animates: bool = false

@export_group("Körper")
## Größe zufällig etwas ändern (GameConfig.passerby_height_range). Aus bei Figuren, die selbst
## schon verschieden groß sind (Chibi-Figuren: gleich großer Kopf bei allen).
@export var vary_size: bool = true
## Platz, den die Figur braucht (Radius in Metern) – zum Ausweichen.
@export var radius: float = 0.25

## Größter seitlicher Schritt beim Ausweichen (m/s).
const SIDESTEP_SPEED := 0.75
## So weit voraus wird ausgewichen (Meter).
const LOOK_AHEAD := 3.6
## So weit voraus richtet sich die bevorzugte Lage nach dem Weg (Meter).
const COMFORT_LOOK_AHEAD := 1.5
## So lange (Sekunden) wartet ein Passant, wenn ihm jemand den Weg versperrt (z. B. die
## Spielfigur) – danach dreht er um und geht einen anderen Weg.
const PATIENCE := 6.0
## So weit vom Fahrbahnrand wartet man vor dem Überqueren (Meter, Mitte der Figur).
const CURB_WAIT := 0.45
## Drehtempo der Figur (je Sekunde, weich).
const TURN_RATE := 7.0
## Ist auf dem Gehweg kein Platz (Engstelle neben Laterne, Kübel oder Kiste, und jemand kommt
## entgegen), tritt man kurz an den Rand der Fahrbahn: so weit (Meter, Mitte der Figur) über
## den erlaubten Streifen hinaus und mindestens so lange (Sekunden) – nur, wenn kein Fahrzeug
## kommt (Fahrzeuge bremsen dann für einen).
const STEP_OFF := 0.8
const STEP_OFF_TIME := 2.0
## Für den kurzen Schritt an den Fahrbahnrand reicht es, wenn so viele Sekunden lang kein
## Fahrzeug kommt (zum Überqueren wartet man länger, siehe StreetLife.road_clear_for).
const STEP_OFF_LOOK := 3.0
## So lange (Sekunden) versucht man höchstens, zum Überqueren an den Bordstein zu kommen.
const CROSS_GIVE_UP := 4.0
## So weit (Meter) geht man beim Überqueren höchstens schräg in Laufrichtung.
const CROSS_DRIFT := 0.3
## So lange wartet man am Bordstein höchstens auf stehende Fahrzeuge (s), dann geht man auf dieser Seite weiter
const CROSS_WAIT_MAX := 15.0
## Stehen sich zwei an einer Engstelle gegenüber, geht nach so vielen Sekunden einer so lange
## (YIELD_TIME) ganz an seinen linken Rand – so kommen beide aneinander vorbei.
const FACE_OFF_TIME := 1.0
const YIELD_TIME := 2.5
## Sicherheitsnetz: Steckt man so lange (Sekunden) an einer Laterne, einem Kübel o. Ä. fest,
## darf man eine Weile hindurchgehen (ghost_static), bis man frei ist.
const WEDGED_TIME := 1.5
## Hinsetzen: so weit vor dem Sitzplatz steht man vorher (Meter), so lange dauert das Hinsetzen
## bzw. Aufstehen (Sekunden).
const SIT_FRONT := 0.5
const SIT_TIME := 0.9
## So lange wartet man höchstens, wenn beim Hinsetzen oder Aufstehen jemand im Weg steht (s)
const SIT_PATIENCE := 4.0

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
var _shadows := -1
var _old_lat := 0.0
var _blocked_time := 0.0
var _step_off := 0.0
var _squeezed := false
var _front_walker: Passerby = null
var _face_off := 0.0
var _yield := 0.0
## Sich aneinander vorbeidrücken (seit Etappe 6j): Zeit, in der zwei Passanten enger aneinander vorbei dürfen
## (StreetLife.SQUEEZE_GAP statt der vollen Kreise); _stand_off = wie lange schon jemand direkt davor steht
var squeeze := 0.0
var _stand_off := 0.0
const SQUEEZE_AFTER := 1.6
const SQUEEZE_TIME := 2.5
## Für das Prüfwerkzeug: warum es gerade nicht weitergeht
var _why := ""
## > 0: feste Hindernisse (Laternen, Kübel) halten gerade nicht auf (Sekunden, siehe WEDGED_TIME).
var ghost_static := 0.0
## Plaudern (seit Etappe 6c): laufende Runde (ChatSession) und Pause bis zum nächsten Plausch
var chat: ChatSession
var chat_cooldown := 0.0
var _bubble: ChatBubble
## Katzen streicheln (seit Etappe 6h): Pause bis zum nächsten Mal; diese Katze ist beim Gehen kein Hindernis
var pet_cooldown := 0.0
var ignore_agent: Object = null
## Zu zweit unterwegs (seit der Nachbesserung von 6h): der Begleiter; follows = ich gehe neben (bzw. hinter) ihm
var companion: Passerby
var follows := false
var _pair_side := 1.0
## Abstand nebeneinander (m, Mitte zu Mitte) bzw. hintereinander, wo der Gehweg zu schmal ist
const PAIR_GAP := 0.62
const PAIR_LAG := 0.9
## Anwohner und Ladenbesucher (seit Etappe 6i): Höhe des Bodens, auf dem man gerade geht (Laden, Zimmer)
var floor_y := 0.0
## Gehört dieser Passant zu einem Haus (StreetHomes)? Dann kehrt er nicht in den allgemeinen Vorrat zurück.
var resident: Dictionary = {}
var _turn_left := 0.0
var _say_me := false
## Laden, in dem man gerade ist (für den Abschied von dort)
var _visiting: Dictionary = {}
## Beim Durchgehen durch eine Tür: nach so vielen Metern hinter der Türmitte gibt man sie wieder frei
const DOOR_RELEASE_PAST := 0.55
## So weit neben der Tür wartet man, wenn gerade jemand anderes hindurchgeht (m)
const DOOR_WAIT_ASIDE := 0.9


func _ready() -> void:
	_model = get_node_or_null("Model") as Node3D
	_body = get_node_or_null("Body") as AnimatableBody3D
	if _model and not model_animates:
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
	# Absätze: manche Frauen (Chibi-Figuren 0–2 sind Frauen)
	var figure: Variant = _model.get("figure") if _model else null
	_heels = figure != null and int(figure) < 3 and rng.randf() < GameConfig.passerby_heels_share
	var size := rng.randf_range(GameConfig.passerby_height_range.x, GameConfig.passerby_height_range.y)
	scale = Vector3.ONE * (size if vary_size else 1.0)
	_shadows = -1
	set_shadows(0)
	set_detail_distance(GameConfig.street_detail_distance)


func set_active(enabled: bool) -> void:
	active = enabled
	visible = enabled
	on_road = false
	velocity2 = Vector2.ZERO
	if _body:
		for shape: CollisionShape3D in _body.find_children("*", "CollisionShape3D", true, false):
			shape.set_deferred("disabled", not enabled)


## Schatten nur in der Nähe (StreetLife schaltet je nach Entfernung und Grafikstufe):
## 0 = keiner, 1 = einfach, 2 = genau (siehe PasserbyPlaceholder; eigene Figuren: an/aus).
func set_shadows(level: int) -> void:
	if level == _shadows or _model == null:
		return
	_shadows = level
	if _model.has_method("set_shadows"):
		_model.call("set_shadows", level)
	else:
		var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for part: GeometryInstance3D in _model.find_children("*", "GeometryInstance3D", true, false):
			part.cast_shadow = mode


func set_detail_distance(distance: float) -> void:
	if _model and _model.has_method("set_detail_distance"):
		_model.call("set_detail_distance", distance)


## Startet mit einer neuen Liste von Schritten (von StreetLife geplant) an der Stelle start.
func begin(start: Vector2, actions: Array[Dictionary], face: Vector2, start_floor: float = 0.0) -> void:
	pos = start
	floor_y = start_floor
	_visiting = {}
	# Alles vom letzten Weg vergessen (die Figur kommt aus dem Vorrat) – sonst suchte sie ihre
	# Lage auf der Straße dort, wo sie zuletzt war
	_route = null
	_s = 0.0
	_lat = 0.0
	_target_lat = 0.0
	_step_off = 0.0
	_blocked_time = 0.0
	_face_off = 0.0
	_yield = 0.0
	ghost_static = 0.0
	companion = null
	follows = false
	_pair_side = 1.0 if randf() < 0.5 else -1.0
	_actions = actions
	_action = {}
	_yaw = atan2(face.x, face.y)
	_height = start_floor
	set_active(true)
	_place()
	_next_action()


## Der aktuelle Weg und die Lage darauf (für StreetLife, z. B. zum Weiterplanen).
func get_route() -> StreetRoute:
	return _route


func get_route_s() -> float:
	return _s


## Den Besuch am Schaufenster auslassen (Platz versperrt) und gleich weitergehen.
func skip_visit() -> void:
	while not _actions.is_empty() and _actions[0].get("visit", false):
		_actions.pop_front()
	_next_action()


## Den aktuellen Schritt auslassen (wenn er nicht weitergeht).
func skip_action() -> void:
	_next_action()


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


## Steht der Passant (mit seinem Körper) auf der Fahrbahn? Nur dann bremsen Fahrzeuge für ihn.
func body_on_road() -> bool:
	if on_road:
		return true
	if _route == null or not life.is_centerline(_route):
		return false
	return absf(_lat) - radius * scale.x < GameConfig.street_width / 2.0 + 0.05


## Ist die Figur wirklich auf der Fahrbahn (überquert sie oder ragt mit dem Körper deutlich hinein, z. B. beim
## Ausweichen an den Rand)? Seit Etappe 6f bremsen Fahrzeuge nur dafür – wer am Bordstein auf dem Gehweg steht,
## zählt nicht mehr.
func center_on_road() -> bool:
	if on_road:
		return true
	if _route == null or not life.is_centerline(_route):
		return false
	return absf(_lat) - radius * scale.x < GameConfig.street_width / 2.0 - GameConfig.road_person_margin


## Zustand als Text (Prüfwerkzeug).
func debug_text() -> String:
	var band := _band_here() if _route else Vector2.ZERO
	return "%s s=%.2f/%.2f lat=%.2f ziel=%.2f band=%s tempo=%.2f teil=%s dir=%d" % [get_action_type(), _s,
		float(_action.get("to", NAN)), _lat, _target_lat, band, minf(speed_pref, _speed_limit),
		_route.part_at(_s) if _route else "", _dir]


## Für das Prüfwerkzeug: mit wem unterwegs, plaudert er, was bremst.
func pair_text() -> String:
	var text := ""
	if companion != null and is_instance_valid(companion):
		text += " [zu zweit mit %s%s]" % [companion.name, ", folgt" if follows else ""]
	if chat != null:
		text += " [plaudert]"
	if _yield > 0.0:
		text += " [weicht aus]"
	if squeeze > 0.0:
		text += " [drückt sich vorbei]"
	if _why != "":
		text += " [%s]" % _why
	return text


## Was gerade passiert ("walk", "cross", "stand", "sit", "leave").
func get_action_type() -> String:
	return String(_action.get("type", ""))


## Wird von StreetLife in jedem Physik-Schritt aufgerufen.
func step(delta: float) -> void:
	if not active:
		return
	chat_cooldown = maxf(0.0, chat_cooldown - delta)
	pet_cooldown = maxf(0.0, pet_cooldown - delta)
	squeeze = maxf(0.0, squeeze - delta)
	var before := pos
	match String(_action.get("type", "")):
		"walk":
			_step_walk(delta)
		"cross":
			_step_cross(delta)
		"stand":
			_step_stand(delta)
		"sit":
			_step_sit(delta)
		"leave":
			_step_leave(delta)
		"pet":
			_step_pet(delta)
		"door":
			_step_door(delta)
		"chore":
			_step_chore(delta)
		"buy":
			_step_buy(delta)
		"call":
			_step_call()
		"wait":
			_step_wait(delta)
		_:
			_next_action()
	velocity2 = (pos - before) / maxf(delta, 0.0001)
	_place()
	_update_facing(delta)
	_animate(delta)
	_footsteps(pos.distance_to(before))


## Schritte hören (seit Etappe 6e): je Schritt ein Laut (zufällige Variante, leicht andere Tonhöhe und
## Geschwindigkeit) – nur in der Nähe der Spielfigur und leise; manche Frauen gehen mit Absätzen.
var _step_left := 0.0
var _heels := false


func _footsteps(moved: float) -> void:
	if moved <= 0.0001 or not is_visible_in_tree():
		return
	_step_left -= moved
	if _step_left > 0.0:
		return
	_step_left = GameConfig.passerby_stride * scale.x * randf_range(0.92, 1.08)
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_to(global_position) > GameConfig.passerby_step_hear_distance:
		return
	Audio.play_at("footsteps/heels" if _heels else "footsteps/street", global_position, GameConfig.passerby_step_volume_db,
		Audio.vary(0.08))


# --- Schritte ---

func _next_action() -> void:
	ignore_agent = null
	if _model and _model.has_method("set_pet_target"):
		_model.call("set_pet_target", null)
	_attend(null)
	_set_road_scan(false)
	if _actions.is_empty():
		_action = {"type": "leave", "gate": false}
	else:
		_action = _actions.pop_front()
	_phase = 0
	_phase_time = 0.0
	_wait = 0.0
	if _action.has("shop_enter"):
		# Laden voll? Dann eben nicht hinein (der Rest des Besuchs fällt weg)
		var shop: Dictionary = _action.shop_enter
		if not life.homes.shop_has_room(shop):
			skip_shop()
			return
		life.homes.shop_enter(shop, self)
		_visiting = shop
	match String(_action.type):
		"walk":
			if _action.get("visit", false):
				var there := life.window_route(pos, _action.spot, _action.face)
				if there == null:
					skip_visit()  # vor dem Fenster ist kein Platz (z. B. viele Kartons)
					return
				_action.route = there
				_action.to = there.length()
			elif _action.has("half"):
				# In eine Gasse: der Weg beginnt genau dort, wo man gerade steht
				var points: PackedVector2Array = (_action.route as StreetRoute).points.duplicate()
				points[0] = pos
				_action.route = StreetPaths.alley_route(points, float(_action.half))
				_action.to = (_action.route as StreetRoute).length()
			elif _action.get("from_here", false):
				# Kurzer Weg: dort beginnen, wo man gerade wirklich steht (Zwischenpunkte bleiben – z. B. der Bogen um das
				# Fahrrad vor dem Blumenladen, seit Etappe 6j)
				var route: StreetRoute = _action.route
				var points: PackedVector2Array = route.points.duplicate()
				points[0] = pos
				var there := StreetRoute.from_points(points, GameConfig.passerby_short_path_half_width)
				if points.size() == 2 and life.homes:
					# gerade erst geplant (vielleicht vor dem ersten Physik-Bild): jetzt noch einmal auf Festes prüfen
					there = (life.homes._route_to(pos, points[1]).route as StreetRoute)
				_action.route = there
				_action.to = there.length()
			_set_route(_action.route)
			_dir = 1 if float(_action.to) >= _s else -1
		"cross":
			# Steht an dieser Stelle eine Laterne o. Ä. im Weg, ein Stück weiter überqueren: erst
			# ganz normal auf dem Gehweg (mit Ausweichen) bis dorthin, dann hinüber
			var here := life.centerline.project(pos)
			var at_s := life.clear_crossing_s(here.x, here.y)
			here = Vector2(here.x, 0.0)
			if absf(at_s - here.x) > 0.1 and not _action.get("moved", false):
				_action.moved = true
				_actions.push_front(_action)
				_actions.push_front({"type": "walk", "route": life.sidewalks[side], "to": at_s})
				_next_action()
				return
			_set_route(life.crossing_route)
			_action.at_s = _s


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
	var action := _action
	var before := pos
	if _action.get("fixed_path", false):
		# Fester, kurzer Weg (zur Ladentür, im Laden, zur Haustür): er ist so gebaut, dass er passt – die groben
		# Hindernis-Kreise daneben (Blumenständer, Kübel) halten hier nicht auf (seit Etappe 6j)
		ghost_static = maxf(ghost_static, 0.2)
	_walk_along(delta, _pair_want(_comfort_lat()))
	if _action.has("floor_to") and _route:
		# Treppe (seit Etappe 7, Bücherei): die Bodenhöhe wächst gleichmäßig entlang des Wegs
		var t := clampf(_s / maxf(_route.length(), 0.01), 0.0, 1.0)
		floor_y = lerpf(float(_action.get("floor_from", floor_y)), float(_action.floor_to), t)
	# Unterwegs umgedreht (neue Schritte von StreetLife)? Dann gilt schon der neue Weg – nicht
	# mit dem alten Ziel vergleichen (sonst fiele der neue Weg weg und er verschwände mitten
	# auf der Straße)
	if not is_same(action, _action):
		return
	var to: float = _action.to
	# Am Ziel – oder knapp davor und es geht nicht weiter (z. B. eine Kiste dicht daneben)
	if (to - _s) * _dir <= 0.0 or (absf(to - _s) < 0.25 and pos.distance_to(before) < 0.001):
		if _action.has("passing"):
			life.passing(self, String(_action.passing))
		_next_action()


## Über die Straße: zum Bordstein, umschauen, warten bis frei, hinüber.
func _step_cross(delta: float) -> void:
	var to_side: int = _action.to_side
	var half := GameConfig.street_width / 2.0
	var curb := (half + CURB_WAIT) * float(side)
	var far_curb := (half + CURB_WAIT) * float(to_side)
	_phase_time += delta
	match _phase:
		0:  # an den Bordstein (nicht durch andere hindurch; steht etwas im Weg, seitlich vorbei)
			if _phase_time > CROSS_GIVE_UP:
				# Kommt nicht an den Bordstein (z. B. eng zwischen Laterne und anderen): doch nicht
				# hinüber, auf dieser Seite weiter bis zum Ende
				var to_end := -0.5 if _dir < 0 else life.centerline.length() + 0.5
				replace_actions([{"type": "walk", "route": life.sidewalks[side], "to": to_end}, {"type": "leave", "gate": false}])
				return
			var goal_s: float = _action.get("at_s", _s)
			if not is_equal_approx(_s, goal_s):
				# Erst auf dem Gehweg bis zur freien Stelle, dann zum Bordstein
				var s_try := move_toward(_s, goal_s, speed_pref * delta)
				if not life.blocks_move(self, _route.point_at(s_try, _lat)):
					_s = s_try
				_anim_state = &"walk"
				_anim_speed = speed_pref
				pos = _route.point_at(_s, _lat)
				return
			var lat := move_toward(_lat, curb, speed_pref * 0.8 * delta)
			if not life.blocks_move(self, _route.point_at(_s, lat)):
				_lat = lat
			else:
				for way: int in [_dir, -_dir]:
					var try_s: float = _s + way * speed_pref * 0.6 * delta
					if not life.blocks_move(self, _route.point_at(try_s, _lat)):
						_s = try_s
						break
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
		2:  # warten, bis kein Fahrzeug kommt – und dem nächsten, das kommt, nachschauen, bis es vorbei ist
			var car := life.vehicle_coming(self)
			_attend(car)
			_anim_state = &"idle" if _phase_time < 4.0 or car != null else &"look"
			if life.road_clear_for(self):
				_attend(null)
				_phase = 3
				on_road = true
				_set_road_scan(true)
			elif _phase_time > CROSS_WAIT_MAX:
				# Es wird nicht frei (z. B. stehen Fahrzeuge davor und warten vor der Spielfigur): nicht ewig am
				# Bordstein stehen, sondern auf dieser Seite weitergehen (seit Etappe 6j)
				_attend(null)
				var to_end := -0.5 if _dir < 0 else life.centerline.length() + 0.5
				replace_actions([{"type": "walk", "route": life.sidewalks[side], "to": to_end}, {"type": "leave", "gate": false}])
				return
		3:  # hinüber (leicht schräg in Laufrichtung) – steht dort jemand, ein Stück daneben
			if not _action.has("from_s"):
				_action.from_s = _s
			# beim Hinübergehen nach links und rechts schauen; kommt ein Auto, ihm nachschauen
			var coming := life.vehicle_coming(self)
			_attend(coming)
			_set_road_scan(coming == null)
			var lat := move_toward(_lat, far_curb, speed_pref * delta)
			# Schräg höchstens CROSS_DRIFT weit (die freie Stelle drüben ist so viel breiter)
			var s_next := _s
			if absf(_s - float(_action.from_s)) < CROSS_DRIFT:
				s_next = _s + _dir * 0.25 * delta
			# Sicherheitsnetz: Hängt man auf der Fahrbahn fest (Fahrzeuge warten), durch Laterne
			# oder Kübel hindurch
			_action.road_time = float(_action.get("road_time", 0.0)) + delta
			if _action.road_time > 6.0 and ghost_static <= 0.0:
				ghost_static = 2.0
			ghost_static = maxf(0.0, ghost_static - delta)
			if life.blocks_move(self, _route.point_at(s_next, lat)):
				# Seitlich ausweichen: erst in Laufrichtung, sonst in die andere
				lat = _lat
				s_next = _s
				for way: int in [_dir, -_dir]:
					var try_s: float = _s + way * speed_pref * 0.6 * delta
					if not life.blocks_move(self, _route.point_at(try_s, lat)):
						s_next = try_s
						break
			_lat = lat
			_s = s_next
			_anim_state = &"walk"
			_anim_speed = speed_pref
			if is_equal_approx(_lat, far_curb):
				on_road = false
				side = to_side
				pos = _route.point_at(_s, _lat)
				_next_action()
				return
	pos = _route.point_at(_s, _lat)


## Mitte der Tür, durch die man gerade will (zum Hinschauen beim Warten).
func door_point() -> Vector2:
	return _action.get("middle", pos)


## Durch eine Tür (seit Etappe 6i): zum Startpunkt gehen, die Hand zur Tür (door_in/door_out), die Tür geht auf,
## hindurch; hinter der Türmitte gibt man sie frei. Mit "vanish" (nach Hause) wartet man, bis sie zu ist – erst dann
## verschwindet man, ungesehen hinter der geschlossenen Tür.
func _step_door(delta: float) -> void:
	var door: HouseDoor = _action.door
	var from: Vector2 = _action.from_pos
	var to: Vector2 = _action.to_pos
	_phase_time += delta
	if _action.get("fixed_path", false):
		ghost_static = maxf(ghost_static, 0.2)  # Bücherei: Stufen und Kübel neben der Treppe halten nicht auf
	match _phase:
		0:  # zum Startpunkt vor bzw. hinter der Tür
			var step := speed_pref * 0.75
			# Kommt gerade jemand anderes durch die Tür, wartet man einen Schritt daneben und lässt ihn heraus
			# (seit Etappe 6j – vorher standen sich beide im Türrahmen gegenüber und gingen dann durcheinander hindurch)
			var goal := from
			var waiting := door.busy_for(self)
			if waiting:
				var through := (to - from).normalized()
				goal = from + Vector2(-through.y, through.x) * DOOR_WAIT_ASIDE - through * 0.35
				_phase_time = minf(_phase_time, 2.0)
			var next := pos.move_toward(goal, step * delta)
			var free := not life.blocks_move(self, next)
			if free:
				pos = next
			_anim_state = &"walk" if free and pos.distance_to(goal) > 0.01 else &"idle"
			_anim_speed = step
			if waiting:
				if pos.distance_to(goal) < 0.05:
					_action.face = (door_point() - pos).normalized()  # zur Tür schauen, bis sie frei ist
				return
			_action.erase("face")
			if pos.distance_to(from) < 0.02 or _phase_time > 8.0:
				_phase = 1
				_phase_time = 0.0
				_action.face = (to - from).normalized()
		1:  # Tür öffnen
			_anim_state = &"idle"
			_anim_speed = 0.0
			if not _action.get("started", false):
				if door.busy_for(self):
					_phase = 0  # jemand kommt gerade heraus: daneben warten
					return
				if _phase_time < 0.35:
					return  # erst zur Tür drehen
				_action.started = true
				door.request(self)
				if _model and _model.has_method("play_clip"):
					# nur der Abschnitt mit der Hand an der Tür (Anfang, Länge in Sekunden)
					var clip: StringName = &"door_in" if bool(_action.get("push", true)) else &"door_out"
					var part: Vector2 = GameConfig.house_door_clip_in if clip == &"door_in" else GameConfig.house_door_clip_out
					_model.call("play_clip", clip, part.y, Vector2.ZERO, 0.0, false, part.x)
			if door.is_open():
				_phase = 2
				_phase_time = 0.0
				if _action.has("floor"):
					floor_y = float(_action.floor)
		2:  # hindurch (steht jemand im Weg, z. B. die Spielfigur vor der Tür: warten, die Tür bleibt offen)
			var step := speed_pref * 0.8
			var next := pos.move_toward(to, step * delta)
			if life.blocks_move(self, next) and _phase_time < 12.0:
				_anim_state = &"idle"
				_anim_speed = 0.0
				return
			pos = next
			_anim_state = &"walk"
			_anim_speed = step
			var past: Vector2 = pos - _action.middle
			if not _action.get("released", false) and past.dot(to - from) > 0.0 and past.length() > DOOR_RELEASE_PAST:
				_action.released = true
				door.release(self)
			if pos.distance_to(to) < 0.02:
				if not _action.get("released", false):
					_action.released = true
					door.release(self)
				_phase = 3
				_phase_time = 0.0
		3:  # drinnen hinter der Tür: warten, bis sie zu ist (nach Hause) – sonst gleich weiter
			_anim_state = &"idle"
			_anim_speed = 0.0
			if not bool(_action.get("vanish", false)):
				if _action.has("shop_exit"):
					life.homes.shop_leave(_action.shop_exit, self)
					_visiting = {}
				_next_action()
				return
			if door.is_closed():
				active = false
				finished.emit(self)


## Rückfrage (seit Etappe 7, Bücherei-Besucher): "callable" wird mit dieser Figur aufgerufen; liefert es eine Liste von
## Schritten, kommen sie gleich als Nächstes dran (so plant die Bücherei erst dann, wenn man wirklich dort ist).
func _step_call() -> void:
	var action := _action
	var more: Variant = (_action.callable as Callable).call(self)
	if not is_same(action, _action):
		return  # die Rückfrage hat schon neue Schritte gesetzt (replace_actions)
	if more is Array:
		var list: Array[Dictionary] = []
		for entry: Variant in more:
			if entry is Dictionary:
				list.append(entry)
		list.append_array(_actions)
		_actions = list
	_next_action()


## Warten (seit Etappe 7): stehen bleiben (Blick "face", Animation "anim"), bis "until" (Callable mit dieser Figur) true
## liefert – z. B. an der Theke, bis gestempelt ist. "every" (Callable) wird dabei jedes Bild aufgerufen.
func _step_wait(delta: float) -> void:
	_phase_time += delta
	_anim_state = StringName(_action.get("anim", &"idle"))
	_anim_speed = 0.0
	if _action.has("every"):
		(_action.every as Callable).call(self, delta)
	if (_action.until as Callable).call(self):
		_next_action()


## Eine kleine Arbeit (seit Etappe 6i): Blumen gießen oder fegen. Steht schon am Platz (Weg davor als "walk").
## An der Theke (seit Etappe 6i): zum Platz gehen (ist er besetzt, kurz warten), Verkäufer und Kunde schauen sich an und reden
## abwechselnd, am Ende bekommt man die Tüte (im Pub keine).
func _step_buy(delta: float) -> void:
	var shop: Dictionary = _action.shop
	var spot: Vector2 = _action.spot
	var vendor: Passerby = shop.get("vendor")
	_phase_time += delta
	match _phase:
		0:  # hin zur Theke
			if not life.homes.claim_counter(shop, self):
				_anim_state = &"idle"
				_anim_speed = 0.0
				if _phase_time > 15.0:
					_next_action()  # lange besetzt: ohne Einkauf weiter
				return
			var step := speed_pref * 0.75
			pos = pos.move_toward(spot, step * delta)
			_anim_state = &"walk"
			_anim_speed = step
			if pos.distance_to(spot) < 0.02:
				_phase = 1
				_phase_time = 0.0
				_turn_left = 0.0
				if vendor and vendor._model and _model:
					_model.call("set_chat_partner", vendor._model)
					vendor._model.call("set_chat_partner", _model)
		1:  # reden und bezahlen
			_anim_state = &"idle"
			_anim_speed = 0.0
			_turn_left -= delta
			if _turn_left <= 0.0:
				_turn_left = randf_range(1.8, 3.0)
				_say_me = not _say_me
				chat_turn(_say_me, _turn_left)
				if vendor:
					vendor.chat_turn(not _say_me, _turn_left)
			if _phase_time >= float(_action.get("time", 5.0)):
				chat_turn(false, 0.0, true)
				if vendor:
					vendor.chat_turn(false, 0.0, true)
				var bag := String(shop.get("bag", ""))
				if not bag.is_empty():
					give_bag(true, bag)
					life.homes.stat_bags += 1
				if _model and _model.has_method("trigger_face"):
					_model.call("trigger_face", &"buy")
				life.homes.release_counter(shop, self)
				_next_action()


func _step_chore(delta: float) -> void:
	_phase_time += delta
	_anim_state = &"idle"
	_anim_speed = 0.0
	if _phase == 0:
		if _phase_time < 0.45:
			return  # erst hindrehen
		_phase = 1
		if _model and _model.has_method("start_chore"):
			var left := float(_model.call("start_chore", String(_action.kind), float(_action.time)))
			_action.time = maxf(float(_action.time), left)
	if _phase_time >= float(_action.time):
		if _model and _model.has_method("stop_chore"):
			_model.call("stop_chore")
		_next_action()


## Stehen bleiben und schauen (Schaufenster: "browse").
func _step_stand(delta: float) -> void:
	# Plaudern: erst aufeinander zu (bis zum Abstand fürs Reden bzw. Händeschütteln)
	if _action.has("approach"):
		_step_approach(delta)
		return
	_phase_time += delta
	_anim_state = _action.get("anim", &"idle")
	_anim_speed = 0.0
	# kleine Pause unterwegs: einmal eine Animation (umschauen, strecken, gähnen, auf die Uhr schauen …)
	if _phase == 0:
		_phase = 1
		var pause := StringName(_action.get("pause", ""))
		var gesture := String(_action.get("gesture", ""))
		if pause != &"" and _model and _model.has_method("play_pause"):
			var duration := float(_model.call("play_pause", pause))
			if duration > 0.0:
				_action.time = maxf(float(_action.get("time", 3.0)), duration + 0.2)
			elif pause == &"look_around" or pause == &"watch":
				_action.anim = &"look"
		elif pause != &"":
			# Figur ohne diese Animationen: Umschauen bzw. die einfache Geste
			if pause == &"look_around":
				_action.anim = &"look"
			gesture = "watch" if pause == &"watch" else ("" if pause == &"look_around" else "stretch")
		if not gesture.is_empty() and _model and _model.has_method("play_gesture"):
			_model.call("play_gesture", StringName(gesture))
	if _phase_time >= float(_action.get("time", 3.0)):
		_next_action()


## Zum Plaudern aufeinander zugehen (höchstens ein paar Sekunden; wer nicht hinkommt, redet von dort aus).
func _step_approach(delta: float) -> void:
	_phase_time += delta
	var target: Vector2 = _action.approach
	if pos.distance_to(target) < 0.02 or _phase_time > 3.5:
		_action.erase("approach")
		_phase_time = 0.0
		_anim_state = &"idle"
		_anim_speed = 0.0
		return
	var step := float(_action.get("approach_speed", speed_pref * 0.55))
	var next := pos.move_toward(target, step * delta)
	if not life.blocks_move(self, next):
		# geht es von der Blickrichtung weg (Schritt zurück), läuft die Geh-Animation rückwärts
		var face: Vector2 = _action.get("face", Vector2.ZERO)
		var backwards := face.dot(target - pos) < 0.0
		pos = next
		_anim_state = &"walk"
		_anim_speed = -step if backwards else step
	else:
		_anim_state = &"idle"
		_anim_speed = 0.0


## Plaudern beginnen (StreetLife): stehen bleiben, zum anderen schauen (seit Etappe 6h vorher bis spot aufeinander
## zugehen, z. B. zum Händeschütteln), danach weitergehen.
func start_chat(session: ChatSession, face: Vector2, time: float, spot: Vector2 = Vector2.INF) -> void:
	chat = session
	_actions.push_front(_action)
	_action = {"type": "stand", "face": face, "anim": &"idle", "time": time + 8.0, "chat": true}
	if spot != Vector2.INF and spot.distance_to(pos) > 0.03:
		_action.approach = spot
	_phase = 0
	_phase_time = 0.0
	_set_partner(session.other(self))


## Plaudern im Sitzen (zwei auf derselben Bank): sitzen bleiben, bis die Runde vorbei ist.
func start_seat_chat(session: ChatSession, time: float) -> void:
	chat = session
	if _action.get("type") == "sit":
		_action.time = maxf(float(_action.get("time", 0.0)), _phase_time + time + 1.0)
	_set_partner(session.other(self))


func _set_partner(other: Passerby) -> void:
	if _model and _model.has_method("set_chat_partner"):
		_model.call("set_chat_partner", other._model if other else null)


## Jemandem über die Straße zuwinken (nur kurz, man bleibt nicht stehen): hinschauen und mit der rechten Hand winken.
func wave_across(other: Passerby) -> void:
	if _model == null or not _model.has_method("wave_hello"):
		return
	_model.call("wave_hello", 2.2)
	_model.call("trigger_face", &"wave")
	_attend(other)
	get_tree().create_timer(2.4).timeout.connect(func() -> void: _attend(null))


## Nach dem Händeschütteln wieder ein Stück auseinander (bis passerby_chat_gap zwischen beiden): jeder geht die
## Hälfte des fehlenden Stücks langsam rückwärts.
func chat_back_off(partner: Passerby) -> void:
	if not _action.get("chat", false) or partner == null:
		return
	var away := pos - partner.pos
	var dist := away.length()
	var want := GameConfig.passerby_chat_gap * scale.x
	if dist < 0.01 or dist >= want:
		return
	_action.approach = life.keep_on_sidewalk(side, pos + away / dist * (want - dist) / 2.0)
	_action.approach_speed = GameConfig.passerby_step_back_speed
	_action.face = -away / dist  # einander zugewandt (nach der Umarmung standen sie nebeneinander)
	_phase_time = 0.0


## Steht man schon am Platz fürs Plaudern? (ChatSession wartet darauf mit der Begrüßung)
func chat_ready() -> bool:
	return chat != null and not _action.has("approach")


## Sitzt man gerade (nicht beim Hinsetzen oder Aufstehen)?
func is_sitting() -> bool:
	return get_action_type() == "sit" and _phase == 3


## Begrüßung beim Plaudern: Händeschütteln (beide gleichzeitig) oder winken; liefert die Dauer.
func chat_greet(handshake: bool, wave: bool, hug_side: float = 0.0) -> float:
	if _model == null or not _model.has_method("play_clip"):
		return 0.8
	if hug_side != 0.0:
		_model.call("start_hug", hug_side, GameConfig.passerby_hug_time)
		return GameConfig.passerby_hug_time
	_model.call("trigger_face", &"handshake" if handshake else &"greet")
	if handshake:
		var duration := float(_model.call("play_clip", &"handshake"))
		if duration > 0.0:
			return duration
	if wave and not carries_bag():
		_model.call("wave_hello", 2.4)
		return 2.0
	return 0.8


## Gangart und Tasche neu auswürfeln (StreetLife, bei jedem Losgehen).
func restyle(rng: RandomNumberGenerator) -> void:
	if _model and _model.has_method("restyle"):
		_model.call("restyle", rng)


## Die Spielfigur grüßen (seit der Nachbesserung von 6h): kurz stehen bleiben und zu ihr drehen (target = Welt),
## danach weitergehen – nur im normalen Gehen auf dem Gehweg.
func greet_stop(target: Vector3, seconds: float) -> bool:
	if get_action_type() != "walk" or on_road or body_on_road() or chat != null or ignore_agent != null:
		return false
	if life.crowded_near(self, 1.3):
		return false  # nicht mitten im Gedränge stehen bleiben
	if _action.get("visit", false) or _action.has("half") or _action.has("alley") or _action.get("from_here", false):
		return false
	var d := life.to_local2(target) - pos
	if d.length() < 0.3:
		return false
	_actions.push_front(_action)
	_action = {"type": "stand", "face": d.normalized(), "anim": &"idle", "time": seconds}
	_phase = 0
	_phase_time = 0.0
	return true


## Gehen beide gerade auf demselben Weg (dann gehen sie zusammen)?
func _paired_walking() -> bool:
	return companion != null and is_instance_valid(companion) and companion.active and companion.companion == self \
		and get_action_type() == "walk" and companion.get_action_type() == "walk" and companion._route == _route


## Wohin der Begleiter will: neben den ersten (auf die Seite, wo Platz ist), sonst genau hinter ihn.
func _pair_want(want: float) -> float:
	if not follows or not _paired_walking():
		return want
	var band := _band_here()
	var gap := PAIR_GAP * scale.x
	for k in 2:
		var lat := companion._lat + _pair_side * gap
		if lat >= band.x and lat <= band.y:
			return lat
		_pair_side = -_pair_side
	return companion._lat


## Tempo zu zweit: der Begleiter hält sich neben (bzw. hinter) dem ersten, der erste wartet, wenn er zurückfällt.
func _pair_speed() -> float:
	if not _paired_walking():
		return speed_pref
	var ahead := (companion._s - _s) * float(_dir)
	if follows:
		# erst seitlich neben den ersten, dann aufholen (sonst ginge man durch ihn hindurch); hintereinander mit Abstand
		var side_by_side := absf(companion._lat - _lat) > PAIR_GAP * 0.75 * scale.x
		if not side_by_side and ahead < -0.2:
			return speed_pref  # hintereinander und ich bin vorn (Engstelle): einfach weiter, der andere folgt
		var lag := 0.0 if side_by_side else PAIR_LAG
		return clampf(companion.velocity2.length() + (ahead - lag) * 1.2, 0.0, speed_pref * 1.5)
	if ahead < -1.3 and absf(companion._lat - _lat) > PAIR_GAP * 0.75 * scale.x:
		return speed_pref * 0.55  # der Begleiter fällt zurück: etwas langsamer
	return speed_pref


## Können die restlichen Schritte zu zweit gegangen werden (nur gehen, überqueren, verschwinden)?
func can_walk_on_with_someone() -> bool:
	if _actions.is_empty():
		return false
	for a: Dictionary in _actions:
		if not String(a.get("type", "")) in ["walk", "cross", "leave", "stand"]:
			return false
		if a.get("visit", false) or a.has("half") or a.has("alley") or a.get("from_here", false):
			return false
	return true


## Dieselben restlichen Schritte wie der andere (StreetLife.walk_together) – man geht mit ihm mit.
func adopt_plan_of(other: Passerby) -> void:
	_actions.clear()
	for a: Dictionary in other._actions:
		_actions.append(a.duplicate())
	speed_pref = minf(speed_pref, other.speed_pref)
	other.speed_pref = speed_pref
	comfort_pref = other.comfort_pref


## Pause beim Plaudern im Gehen: keiner erzählt.
func chat_quiet() -> void:
	if _model and _model.has_method("set_talking"):
		_model.call("set_talking", false)


## Plaudern im Gehen (zu zweit): Runde gilt, so lange beide unterwegs sind; den anderen dabei anschauen.
func join_walking_chat(session: ChatSession) -> void:
	chat = session
	_set_partner(session.other(self))


## Wie lange das Stehen noch dauert (s; 0 = steht nicht).
func stand_time_left() -> float:
	return float(_action.get("time", 0.0)) - _phase_time if get_action_type() == "stand" else 0.0


## Eine Katze reibt sich an den Beinen (CatLife): noch eine Weile stehen bleiben, zu ihr hinunterschauen, freuen.
func hold_for_cat(cat: StreetCat, seconds: float) -> void:
	if get_action_type() != "stand":
		return
	_action.time = maxf(float(_action.get("time", 0.0)), _phase_time + seconds)
	_attend(cat)
	if _model and _model.has_method("trigger_face"):
		_model.call("trigger_face", &"pet")


## Nach dem Reiben: die Katze streicheln (mit freien Händen und wenn gerade kein Gespräch läuft), sonst weiter anschauen.
func pet_from_rub(cat: StreetCat) -> void:
	if get_action_type() == "stand" and chat == null and not carries_bag() and cat.can_be_petted() and pet_cooldown <= 0.0:
		if start_pet(cat, cat.adult and cat.posture != "lie"):
			life.stat_pets += 1


## Wen die Figur gerade anschaut (Katze, Auto; null = wieder wie sonst).
func _set_road_scan(on: bool) -> void:
	if _model and "road_scan" in _model:
		_model.set("road_scan", on)


func _attend(node: Node3D) -> void:
	if _model and _model.has_method("look_at_node"):
		_model.call("look_at_node", node)


## Einkaufstasche geben oder wegnehmen (Anwohner bei der Arbeit: nie; nach dem Einkauf: mit der Tüte des Ladens).
func give_bag(on: bool, model_path: String = "") -> void:
	if _model and _model.has_method("give_bag"):
		_model.call("give_bag", on, model_path)


## Gegenstand in die rechte Hand (siehe ChibiPasserbyModel.set_prop).
func set_prop(kind: StringName) -> void:
	if _model and _model.has_method("set_prop"):
		_model.call("set_prop", kind)


## Trägt die Figur eine Einkaufstasche? (die Hand ist dann belegt)
func carries_bag() -> bool:
	return _model != null and bool(_model.get("carries_bag"))


## Tempo der Gangart gegenüber normalem Gehen (StreetLife setzt damit das Wunschtempo).
func speed_factor() -> float:
	return float(_model.call("speed_factor")) if _model and _model.has_method("speed_factor") else 1.0


## Höhe der Hand beim Händeschütteln (m).
func handshake_height() -> float:
	return float(_model.call("handshake_height")) * scale.y if _model and _model.has_method("handshake_height") else 0.7


## Lage der rechten Hand beim Händeschütteln (x seitlich, z vorn, Meter; StreetLife stellt die beiden passend hin).
func handshake_hand() -> Vector2:
	return Vector2(_model.call("handshake_hand")) * scale.x if _model and _model.has_method("handshake_hand") else Vector2(-0.05, 0.3)


## Wer beim Plaudern dran ist: erzählt (Hände, Sprechblase) oder hört zu (lacht oder brummt manchmal leise,
## siehe PasserbyVoice). finished = Runde vorbei.
func chat_turn(speaking: bool, seconds: float, finished: bool = false, goodbye: bool = false) -> void:
	if _model and _model.has_method("set_talking"):
		_model.call("set_talking", speaking and not finished)
	if finished:
		chat = null
		chat_cooldown = GameConfig.passerby_chat_cooldown
		_set_partner(null)
		if _action.get("chat", false):
			_action.erase("approach")
			_action.time = 0.0
			# zum Abschied noch kurz winken
			if goodbye and _model and _model.has_method("wave_hello") and not carries_bag():
				_model.call("trigger_face", &"goodbye")
				_model.call("wave_hello", 1.8)
				_action.time = _phase_time + 1.6
		return
	var laughing := randf() < (0.25 if speaking else 0.3)
	if _model and _model.has_method("trigger_face"):
		if speaking:
			_model.call("trigger_face", &"chat_laugh" if laughing else &"chat_talk")
		else:
			_model.call("trigger_face", &"chat_laugh" if laughing else &"chat_listen")
	if _model and _model.has_method("chat_react"):
		_model.call("chat_react", speaking, laughing)
	if not speaking:
		return
	if _bubble == null:
		_bubble = ChatBubble.new()
		_bubble.name = "ChatBubble"
		add_child(_bubble)
	var head := 1.0
	if _model and _model.has_method("eye_point"):
		head = to_local(_model.call("eye_point")).y + 0.12
	if is_visible_in_tree():
		_bubble.pop(head)


## Eine Katze streicheln (seit Etappe 6h, StreetLife): hingehen, sich zu ihr drehen, bücken (kleine Katze oder
## liegend: pet_reach, die Hand streicht hin und her) bzw. hinknien (große Katze: pet_cat), danach weiter.
## false = geht gerade nicht (Figur ohne diese Animationen, kein Platz).
func start_pet(cat: StreetCat, kneel: bool) -> bool:
	if _model == null or not _model.has_method("pet_hand") or carries_bag():
		return false
	_actions.push_front(_action)
	_action = {"type": "pet", "cat": cat, "kneel": kneel, "from": life.to_local2(cat.global_position)}
	_phase = 0
	_phase_time = 0.0
	ignore_agent = cat
	_attend(cat)
	pet_cooldown = GameConfig.passerby_pet_cooldown
	return true


## Platz zum Streicheln: so stehen, dass die rechte Hand (pet_hand) über der Katze ist; der direkte Weg zuerst,
## sonst etwas weiter herum (nie auf der Fahrbahn, nicht an Laterne oder Kübel).
func _pet_spot(cat_pos: Vector2, kneel: bool) -> Dictionary:
	var hand: Vector2 = Vector2(_model.call("pet_hand", kneel)) * scale.x
	var to_me := pos - cat_pos
	if to_me.length() < 0.01:
		to_me = Vector2(0.0, 1.0)
	to_me = to_me.normalized()
	for turn in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var away := to_me.rotated(turn)
		var face := -away
		var target := cat_pos + away * (0.06 if kneel else 0.03)
		# Hand = Lage + face × z + links × x (links = (face.y, -face.x))
		var spot := target - face * hand.y - Vector2(face.y, -face.x) * hand.x
		if life.pet_spot_ok(self, spot):
			return {"spot": spot, "face": face}
	return {}


func _step_pet(delta: float) -> void:
	_phase_time += delta
	var cat: StreetCat = _action.cat if is_instance_valid(_action.get("cat")) else null
	var kneel: bool = _action.kneel
	match _phase:
		0:  # hingehen
			if cat == null or not cat.active or (not cat.is_resting() and not cat.is_petted()) \
					or life.to_local2(cat.global_position).distance_to(_action.from) > 0.5 or _phase_time > 7.0:
				_next_action()
				return
			var there := _pet_spot(life.to_local2(cat.global_position), kneel)
			if there.is_empty():
				_next_action()
				return
			_action.face = there.face
			var spot: Vector2 = there.spot
			var step := speed_pref * 0.6
			var next := pos.move_toward(spot, step * delta)
			_anim_state = &"walk"
			_anim_speed = step
			if life.blocks_move(self, next):
				_anim_state = &"idle"
				_anim_speed = 0.0
			else:
				pos = next
			if pos.distance_to(spot) < 0.02:
				_phase = 1
				_phase_time = 0.0
				cat.wait_for(4.0)
		1:  # zur Katze drehen
			_anim_state = &"idle"
			_anim_speed = 0.0
			if _phase_time > 0.45:
				if cat == null or not cat.can_be_petted():
					_next_action()
					return
				var duration := 0.0
				if kneel:
					duration = float(_model.call("play_clip", &"pet_cat"))
				else:
					duration = float(_model.call("play_clip", &"pet_reach", -1.0, ChibiPasserbyModel.PET_REACH_HOLD,
						randf_range(2.0, 4.0), true))
				if duration <= 0.0:
					_next_action()
					return
				_action.time = duration
				_model.call("set_pet_target", cat)
				_action.touch = ChibiPasserbyModel.PET_KNEEL_TOUCH if kneel else ChibiPasserbyModel.PET_REACH_TOUCH
				_phase = 2
				_phase_time = 0.0
				cat.wait_for(duration + 1.0)
				_model.call("trigger_face", &"pet")
		2:  # streicheln (die Katze hält still und schnurrt, solange die Hand bei ihr ist)
			_anim_state = &"idle"
			_anim_speed = 0.0
			if _action.has("touch") and _phase_time >= float(_action.touch):
				_action.erase("touch")
				if cat and cat.can_be_petted():
					cat.pet(self, maxf(1.0, float(_action.time) - _phase_time - (1.4 if kneel else 1.0)))
			var playing := bool(_model.call("is_playing_clip"))
			if _phase_time >= float(_action.time) or (not playing and _phase_time > 0.5):
				_next_action()


## Hinsetzen (Sitzplatz aus StreetLife): vor den Platz gehen, umdrehen, hinsetzen, sitzen,
## aufstehen und zurück an die Stelle, an der man ankam.
func _step_sit(delta: float) -> void:
	var spot: Vector2 = _action.spot
	var face: Vector2 = _action.face
	# so weit vor dem Sitz hinstellen (vor einem Tisch weniger, Angabe des Sitzplatzes)
	var front := spot + face * float(_action.get("front", _sit_value("sit_front", SIT_FRONT))) * scale.x
	var sit_time := _sit_value("sit_time", SIT_TIME)
	_phase_time += delta
	_anim_speed = 0.0
	match _phase:
		0:  # vor den Platz
			if not _action.has("back"):
				_action.back = pos
				_prepare_sit()
			_anim_state = &"walk"
			_anim_speed = speed_pref * 0.7
			var next := pos.move_toward(front, speed_pref * 0.7 * delta)
			# (nach ein paar Sekunden trotzdem weiter: zwei, die sich nebeneinander setzen wollen, hielten sich sonst
			# für immer gegenseitig auf – seit Etappe 6j)
			if not life.blocks_move(self, next) or _phase_time > SIT_PATIENCE:
				pos = next
			if pos.distance_to(front) < 0.01:
				_phase = 1
				_phase_time = 0.0
		1:  # zur Blickrichtung drehen
			_anim_state = &"idle"
			if _phase_time > 0.5:
				_phase = 2
				_phase_time = 0.0
		2:  # hinsetzen (ein Stück zurück auf den Sitz)
			_anim_state = &"sit"
			pos = front.lerp(spot, smoothstep(0.0, 1.0, _phase_time / sit_time))
			if _phase_time >= sit_time:
				_phase = 3
				_phase_time = 0.0
				if _action.has("pub_seat"):
					life.homes.pub_sat_down(self, _action.pub_seat)
		3:  # sitzen
			_anim_state = &"sit"
			if _phase_time >= float(_action.get("time", 20.0)):
				_phase = 4
				_phase_time = 0.0
				life.release_seat(self)
				if _action.has("pub_seat"):
					life.homes.pub_stood_up(self, _action.pub_seat)
		4:  # aufstehen
			_anim_state = &"idle"
			pos = spot.lerp(front, smoothstep(0.0, 1.0, _phase_time / sit_time))
			if _phase_time >= sit_time:
				_phase = 5
		5:  # zurück an die Stelle, an der man ankam
			_anim_state = &"walk"
			_anim_speed = speed_pref * 0.7
			var back: Vector2 = _action.back
			var next := pos.move_toward(back, speed_pref * 0.7 * delta)
			if not life.blocks_move(self, next):
				pos = next
			# Steht dort schon jemand (der Banknachbar ist gleichzeitig aufgestanden): von hier aus weiter
			if pos.distance_to(back) < 0.01 or _phase_time > sit_time + SIT_PATIENCE * 0.5:
				_next_action()


## Sitzhöhe und Lehne ans Modell geben.
func _prepare_sit() -> void:
	if _model and "sit_height" in _model:
		_model.set("sit_height", float(_action.get("height", 0.45)) / scale.y)
	if _model and "relaxed_sit" in _model:
		var chair: Variant = _action.get("seat")
		_model.set("relaxed_sit", true)
		var backrest := float(_action.get("backrest", (chair as StreetSeat).backrest if chair is StreetSeat else 0.0))
		_model.set("sit_backrest", backrest)
		_model.set("sit_leans", randf() < GameConfig.passerby_lean_back_share)


## Sitzt schon beim Start (feste Pub-Gäste): gleich in der Sitzhaltung, ohne Hinsetzen.
func begin_seated(spot: Vector2, face: Vector2, height: float, start_floor: float, backrest: float) -> void:
	var actions: Array[Dictionary] = [{"type": "sit", "seat": null, "spot": spot, "face": face, "height": height, "time": INF,
		"front": 0.25, "back": spot, "backrest": backrest}]
	begin(spot, actions, face, start_floor)
	_prepare_sit()
	_phase = 3
	_yaw = atan2(face.x, face.y)
	if _model and _model.has_method("snap_seated"):
		_model.call("snap_seated")


## Im Sitzen einen Schluck trinken oder essen (StreetHomes).
func take_sip() -> void:
	if _model and _model.has_method("take_sip"):
		_model.call("take_sip")
		_model.call("trigger_face", &"sip")


## Kleine Bewegung im Stehen (Verkäufer: umschauen, nicken …), wenn gerade nichts anderes läuft.
func play_idle_clip(clip: StringName) -> void:
	if _model and _model.has_method("play_clip"):
		_model.call("play_clip", clip, 3.2)


## Laden-Besuch abbrechen (kein Platz drinnen): die Schritte davon auslassen und auf dem Gehweg weiter.
func skip_shop() -> void:
	while not _actions.is_empty() and _actions[0].get("shop_visit", false):
		var dropped: Dictionary = _actions.pop_front()
		if dropped.has("pub_seat"):
			(dropped.pub_seat as Dictionary).occupant = null  # reservierter Platz wird wieder frei
	_next_action()


## Weg (m) bzw. Zeit (s) des Hinsetzens: vom Modell, wenn es sie vorgibt (seine Sitz-Animation),
## sonst die festen Werte.
func _sit_value(key: String, fallback: float) -> float:
	if _model and key in _model:
		var value := float(_model.get(key))
		if value > 0.0:
			return value
	return fallback


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
	var action := _action
	_walk_along(delta, _comfort_lat())
	if is_same(action, _action):
		_action.extra = extra + absf(_s - before)


## Ein Stück am Weg entlang, mit Ausweichen. want = Wunsch-Lage (lat).
func _walk_along(delta: float, want: float) -> void:
	var normal := _band_here()
	_yield = maxf(0.0, _yield - delta)
	if _yield > 0.0:
		# Ganz an die linke Seite des Streifens, damit der andere vorbeikommt
		want = normal.y if _dir > 0 else normal.x
	var wide := _off_curb_band(normal)
	var band := normal
	_step_off = maxf(0.0, _step_off - delta)
	# Schon am Fahrbahnrand (oder die Zeit läuft noch): dort weitergehen, solange es nötig ist
	var stepped := _step_off > 0.0 or _lat < normal.x - 0.01 or _lat > normal.y + 0.01
	if stepped:
		# Am Fahrbahnrand: immer im breiten Streifen planen (sonst schwankte das Ziel)
		band = wide
		_target_lat = _avoid(want, wide)
	else:
		_target_lat = _avoid(want, normal)
		if _squeezed and wide != normal and life.road_clear_for(self, STEP_OFF_LOOK):
			# Auf dem Gehweg ist kein Platz: an den Fahrbahnrand, wenn dort Platz ist
			var lat := _avoid(want, wide)
			if not _squeezed:
				_step_off = STEP_OFF_TIME
				band = wide
				_target_lat = lat
	_old_lat = _lat
	_lat = move_toward(_lat, _target_lat, SIDESTEP_SPEED * delta)
	# Zurück vom Fahrbahnrand nach und nach (nie ein Sprung) – aber nie über ihn hinaus
	var old := clampf(_old_lat, wide.x, wide.y)
	_lat = clampf(_lat, minf(band.x, old), maxf(band.y, old))
	var pair_speed := _pair_speed()
	var speed := minf(pair_speed, _speed_limit)
	_why = ""
	if speed < 0.15:
		_why = "paar %.2f, limit %.2f" % [pair_speed, _speed_limit]
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
		# Nie in jemanden hinein. Erst nur geradeaus versuchen (ohne den Seitenschritt – seit Etappe 6j: zwei, die
		# zusammen gehen, hielten sich sonst gegenseitig fest, wenn der eine zur Seite des anderen wollte), dann nur
		# zur Seite, sonst stehen bleiben
		var straight := _route.point_at(new_s, _old_lat)
		if ds > 0.0 and not life.blocks_move(self, straight):
			new_pos = straight
			_lat = _old_lat
		else:
			new_s = _s
			new_pos = _route.point_at(_s, _lat)
			if life.blocks_move(self, new_pos):
				new_pos = pos
				_lat = _old_lat
			speed = 0.0
			_why += " versperrt"
	var moved := pos.distance_to(new_pos)
	_s = new_s
	pos = new_pos
	# Versperrt jemand lange den Weg (z. B. die Spielfigur in einer schmalen Gasse): umdrehen
	# bzw. das Schaufenster auslassen
	ghost_static = maxf(0.0, ghost_static - delta)
	# Gegenüber steht jemand und keiner kommt weiter: einer (fest ausgewählt) tritt beiseite
	if moved < 0.12 * delta and is_instance_valid(_front_walker):
		# Hilft auch das Beiseitetreten nicht (Engstelle zwischen Kübeln, der andere steht auf einem schmalen Weg zum
		# Schaufenster): beide drücken sich Schulter an Schulter aneinander vorbei (seit Etappe 6j – vorher standen
		# sie sich bis zu 6 s gegenüber und einer drehte um)
		_stand_off += delta
		if _stand_off > SQUEEZE_AFTER:
			squeeze = SQUEEZE_TIME
			_front_walker.squeeze = SQUEEZE_TIME
			_stand_off = 0.0
		if _yield <= 0.0:
			_face_off += delta
			if _face_off > FACE_OFF_TIME and get_instance_id() < _front_walker.get_instance_id():
				_yield = YIELD_TIME
				_face_off = 0.0
	elif moved >= 0.12 * delta:
		_face_off = 0.0
		_stand_off = 0.0
	if moved < 0.12 * delta:
		_blocked_time += delta
		if _blocked_time > WEDGED_TIME and ghost_static <= 0.0 and life.touches_static(self):
			ghost_static = 1.5
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


## Erlaubter Streifen mit dem Rand der Fahrbahn (nur auf den Gehwegen der Straße).
func _off_curb_band(band: Vector2) -> Vector2:
	if _route == null or not life.is_centerline(_route) or _route == life.crossing_route:
		return band
	var edge := GameConfig.street_width / 2.0 + Street.CURB_TOP + StreetPaths.CURB_CLEARANCE - STEP_OFF
	if side > 0:
		return Vector2(minf(band.x, edge), band.y)
	return Vector2(band.x, maxf(band.y, -edge))


## Sucht die nächste freie Lage zur Wunsch-Lage und setzt das Tempo-Limit (bremsen).
## _squeezed: Es gibt keine ganz freie Lage (man müsste sich an jemandem vorbeiquetschen).
func _avoid(want: float, band: Vector2) -> float:
	_speed_limit = INF
	_squeezed = false
	_front_walker = null
	var narrow := band.y - band.x < 0.8
	var intervals: Array[Vector4] = []  # (von, bis, entgegenkommend 0/1, Abstand voraus)
	for obstacle in life.obstacles_near(self, LOOK_AHEAD + 1.5):
		if companion != null and obstacle.get("agent") == companion and _paired_walking():
			continue  # mit dem Begleiter stimmt man sich selbst ab (nebeneinander)
		if obstacle.kind == "static" and _action.get("fixed_path", false):
			continue  # fester kurzer Weg zur Tür: er ist so gebaut, dass er passt (Kreise daneben bremsen nicht)
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
		if squeeze > 0.0 and obstacle.kind == "walker":
			gap = StreetLife.SQUEEZE_GAP + 0.02
		elif obstacle.kind == "static" and narrow:
			# Schmaler Weg zum Schaufenster: der Platz dort ist geprüft frei; was knapp neben dem Weg steht
			# (Kübel, Blumenständer), bremst nicht (sonst blieb man 6 s davor stehen und kehrte um)
			gap = radius * scale.x + float(obstacle.radius) - 0.03
		intervals.append(Vector4(lage.y - gap, lage.y + gap, 1.0 if their_speed < -0.2 else 0.0, along))
		if along > 0.0 and along < gap + 0.6 and absf(_lat - lage.y) < gap and obstacle.kind == "walker" and their_speed < 0.2:
			_front_walker = obstacle.agent
		if along > 0.0 and absf(_lat - lage.y) < gap - 0.02 and not (squeeze > 0.0 and obstacle.kind == "walker"):
			# Es steht direkt vor mir: bremsen (hinter Langsameren her: deren Tempo) – nicht beim Vorbeidrücken, da hält
			# nur blocks_move den kleinen Abstand
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
			# Wer direkt neben mir ist (Laterne, Passant), durch den gehe ich nicht hindurch auf
			# seine andere Seite
			var middle := (iv.x + iv.y) / 2.0
			if iv.w < (iv.y - iv.x) / 2.0 and signf(c - middle) != signf(_lat - middle):
				cost += 30.0
			# Wie tief steckt diese Lage im Bereich eines anderen? (Ist nirgends ganz frei, gewinnt
			# die Lage mit der kleinsten Überschneidung – meist der Rand des Streifens.)
			var depth := minf(c - iv.x, iv.y - c)
			if depth > 0.0:
				cost += 10.0 + depth * 20.0 / maxf(0.5, iv.w)
			# Entgegenkommenden links ausweichen (beide tun es – so treffen sie sich nie, auch
			# nicht in Engstellen: dort zählt die richtige Seite mehr als ein Stück Überschneidung)
			if iv.z > 0.5 and signf(c - (iv.x + iv.y) / 2.0) != signf(left):
				cost += 6.0
		if cost < best_cost:
			best_cost = cost
			best = c
	_squeezed = best_cost >= 10.0
	return clampf(best, band.x, band.y)


# --- Darstellung ---

func _place() -> void:
	var y := floor_y
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
	elif _action.get("type") in ["pet", "door", "chore", "buy", "wait"] and _action.has("face"):
		var face: Vector2 = _action.face
		target = atan2(face.x, face.y)
		# beim Hindurchgehen (door, Phase 2) in Gehrichtung – die Seiten bleiben gleich
	elif _action.get("type") == "sit" and _phase in [1, 2, 3, 4]:
		var face: Vector2 = _action.face
		target = atan2(face.x, face.y)
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
			&"sit":
				anim_name = sit_animation if sit_animation != &"" else idle_animation
		if anim_name != &"" and _anim_player.has_animation(anim_name):
			if _anim_player.current_animation != anim_name:
				_anim_player.play(anim_name, animation_blend)
			_anim_player.speed_scale = _anim_speed / walk_animation_speed if _anim_state == &"walk" else 1.0
	elif _model and _model.has_method("animate"):
		_model.call("animate", _anim_state, _anim_speed / scale.x, delta)
