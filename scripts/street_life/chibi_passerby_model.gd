@tool
class_name ChibiPasserbyModel
extends ChibiCharacter
## Chibi-Figur als Passant (seit Etappe 5c): zufälliges Aussehen (randomize_look: Körper, Haut,
## Augen, Frisur, Kleidung und Farben) und Bewegung (animate): die Mixamo-Animationen aus der Figur
## (walk, idle, idle_2, sit_down, sit_idle, stand_up; übertragen von tools/blender/chibi_anim.py) –
## Gehen im passenden Tempo, Stehen, Umschauen (Kopf dreht sich, ChibiHeadModifier), Schaufenster
## (ruhiges Stehen, Blick leicht gesenkt), Hinsetzen, Sitzen, Aufstehen. Ohne Animationen in der
## Figur: eine einfache eigene Bewegung. Dieselbe Schnittstelle wie PasserbyPlaceholder (Passerby
## ruft randomize_look, animate, set_shadows; sit_height = Höhe der Sitzfläche; sit_front und
## sit_time = Weg und Dauer des Hinsetzens, passend zur Animation). Auf dem Fahrrad
## (ChibiCyclistModel): pose_ride mit der Animation "ride" (tools/blender/chibi_ride.py).
## Mimik: Grundausdruck neutral mit offenen Augen, die Augen schauen hin und her, ab und zu ein
## anderer Ausdruck (vor dem Schaufenster öfter); die Spielfigur und andere Passanten in der Nähe
## werden angeschaut und manchmal mit Lächeln und dezentem Nicken gegrüßt (Werte in GameConfig).

## Meter je Doppelschritt bei 0,55 m Beinlänge (so passen die Schritte zum Tempo)
const STRIDE := 0.95
const LEG_REFERENCE := 0.55
## Schwung beim Gehen (Grad): Oberschenkel, Knie beim Vorschwingen, Arme
const THIGH_SWING := 24.0
const KNEE_BEND := 34.0
const ARM_SWING := 16.0
## Beim Sitzen: so tief liegt die Sitzfläche unter dem Hüftgelenk (Dicke des Oberschenkels)
const SIT_THIGH := 0.062

## Überblenden zwischen zwei Animationen (Sekunden).
const BLEND := 0.3
## Animationen, die sich wiederholen.
const LOOPS: Array[StringName] = [&"walk", &"idle", &"idle_2", &"sit_idle", &"ride"]
## Ausdrücke mit offenen Augen: ab und zu zwischendurch, vor dem Schaufenster, beim Grüßen.
## Ausdrücke kommen seit Etappe 6c nur über Auslöser (FaceTriggers, trigger_face) – sonst neutral-freundlich.
## Physik-Ebenen, die den Blick verdecken (world, sight_blocker).
const SIGHT_MASK := 1 | 128

## Alle Chibi-Figuren auf der Straße (für Blicke und Grüße untereinander).
static var _everyone: Array[ChibiPasserbyModel] = []

## Höhe der Sitzfläche beim Sitzen (Meter; setzt Passerby).
var sit_height := 0.45
## Weg (m) und Dauer (s) des Hinsetzens laut Animation (0 = Passerby nimmt eigene Werte).
var sit_front := 0.0
var sit_time := 0.0
## Fahrrad passend zu dieser Figur (aus der Animation "ride"; 0 = Figur ohne Radfahr-Animation):
## Rahmengröße gegenüber dem Hollandrad in voller Größe und Höhe des Sitzpunkts (volle Größe).
var ride_scale := 0.0
var ride_seat := 0.0

var _player: AnimationPlayer
var _head_modifier: ChibiHeadModifier
## Gesten zusätzlich zur Animation (seit Etappe 6c): welche, wie lange noch, plaudert gerade
var _gesture_modifier: ChibiGestureModifier
var _gesture: ChibiGestureModifier.Gesture = ChibiGestureModifier.Gesture.NONE
var _gesture_left := 0.0
var _gesture_time := 0.0
var _talking := false
## Tempo, bei dem die Füße der Geh-Animation genau passen; Höhe der Sitzfläche unter dem Po.
var _walk_speed := 1.0
var _sit_seat := 0.23
var _prev_state: StringName = &""
## Übergänge Hinsetzen/Aufstehen: welcher läuft gerade und seit wann
var _transition: StringName = &""
var _transition_t := 0.0
var _seated := 0.0

var _phase := 0.0
var _swing := 0.0
var _sit := 0.0
var _time := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0
var _head_bone := -1
## Mimik: Restzeit des anderen Ausdrucks (0 = Grundausdruck); vor dem Schaufenster: wann es wieder
## „gefällt mir“ gibt
var _mood_left := 0.0
var _mood_wait := 10.0
var _was_browsing := false
var _browse_count := 0
## Augen: jetzige Richtung, Ziel des Hin-und-her-Schauens
var _eyes := Vector2.ZERO
var _glance := Vector2.ZERO
var _glance_wait := 1.0
## Wen die Figur anschaut (Kamera der Spielfigur oder eine andere Chibi-Figur) und Kopfdrehung dorthin
var _focus: Node3D
var _focus_turn := Vector2.ZERO
var _scan_wait := 0.0
## Wem schon zugenickt wurde (instance_id → Zeit), Nicken läuft seit
var _greeted := {}
var _nod_t := -1.0
var _nod_pitch := 0.0
var _hip_height := 0.6
var _leg_length := LEG_REFERENCE


## Neues, zufälliges Aussehen.
func randomize_look(rng: RandomNumberGenerator) -> void:
	var female := rng.randf() < 0.5
	figure = ((0 if female else 3) + rng.randi_range(0, 2)) as Figure
	body_shape = clampf(rng.randfn(0.0, 0.45), -0.9, 1.0)
	skin_color = _pick(rng, GameConfig.chibi_skin_colors)
	iris_color = _pick(rng, GameConfig.chibi_iris_colors)
	eye_shape = rng.randi_range(0, 2) as EyeShape
	hair_color = _pick(rng, GameConfig.chibi_hair_colors)
	brow_color = hair_color.darkened(0.25)
	top = Top.TSHIRT if rng.randf() < 0.5 else Top.SWEATER
	if female:
		bottom = Bottom.SKIRT if rng.randf() < 0.45 else Bottom.TROUSERS
		hair = [Hair.BOB, Hair.BUN, Hair.PIGTAILS][rng.randi_range(0, 2)]
	else:
		bottom = Bottom.TROUSERS
		hair = Hair.SHORT if rng.randf() < 0.85 else Hair.BUN
	shoes = true
	top_color = _pick(rng, GameConfig.chibi_top_colors)
	bottom_color = _pick(rng, GameConfig.chibi_bottom_colors)
	shoe_color = _pick(rng, GameConfig.chibi_shoe_colors)
	# Grundausdruck neutral (Augen offen – so läuft und fährt man); andere Ausdrücke kommen ab und zu
	mood = Mood.NEUTRAL
	_mood_left = 0.0
	_mood_wait = rng.randf_range(GameConfig.chibi_mood_wait.x, GameConfig.chibi_mood_wait.y)
	_measure()


func _pick(rng: RandomNumberGenerator, colors: Array[Color]) -> Color:
	return colors[rng.randi_range(0, colors.size() - 1)] if not colors.is_empty() else Color.WHITE


## Nach dem Laden der Figur: AnimationPlayer, Angaben zu den Animationen, Kopf-Drehung.
func _rebuild() -> void:
	super._rebuild()
	_player = null
	_head_modifier = null
	_gesture_modifier = null
	sit_front = 0.0
	sit_time = 0.0
	if _model == null:
		return
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty() and (players[0] as AnimationPlayer).has_animation(&"walk"):
		_player = players[0]
		for anim_name in LOOPS:
			if _player.has_animation(anim_name):
				_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		var extras: Dictionary = {}
		for node in [_skeleton, _skeleton.get_parent() if _skeleton else null]:
			if node and node.has_meta("extras"):
				extras = node.get_meta("extras")
		var info: Dictionary = extras.get("chibi_anim", {})
		_walk_speed = float(info.get("walk_speed", 1.0))
		_sit_seat = float(info.get("sit_seat", 0.23))
		sit_front = float(info.get("sit_down_shift", 0.0))
		sit_time = float(info.get("sit_down_time", 0.0))
		ride_scale = float(info.get("ride_scale", 0.0))
		ride_seat = float(info.get("ride_seat", 0.0))
		_player.play(&"idle")
	_head_bone = _skeleton.find_bone("Head") if _skeleton else -1
	if _skeleton:
		_gesture_modifier = ChibiGestureModifier.new()
		_gesture_modifier.name = "GestureModifier"
		_skeleton.add_child(_gesture_modifier)
		_head_modifier = ChibiHeadModifier.new()
		_head_modifier.name = "HeadModifier"
		_skeleton.add_child(_head_modifier)
	_prev_state = &""
	_transition = &""
	_seated = 0.0
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


func _enter_tree() -> void:
	if not Engine.is_editor_hint() and not _everyone.has(self):
		_everyone.append(self)


func _exit_tree() -> void:
	_everyone.erase(self)


## Augenhöhe der Figur (Welt).
func eye_point() -> Vector3:
	if _skeleton and _head_bone >= 0:
		return _skeleton.global_transform * (_skeleton.get_bone_global_pose(_head_bone).origin + Vector3(0.0, 0.09, 0.0))
	return global_position + Vector3.UP


## Unsichtbare Passanten (im Vorrat) rechnen keine Animation.
func _on_visibility_changed() -> void:
	if _player:
		_player.active = is_visible_in_tree()


## Hüfthöhe und Beinlänge der Figur (für Schrittlänge und Sitzhaltung).
func _measure() -> void:
	if _skeleton == null:
		return
	var hip := _skeleton.find_bone("LeftUpperLeg")
	var ankle := _skeleton.find_bone("LeftFoot")
	if hip >= 0 and ankle >= 0:
		_hip_height = _skeleton.get_bone_global_rest(hip).origin.y
		_leg_length = _hip_height - _skeleton.get_bone_global_rest(ankle).origin.y


## Schatten: 0 = keiner, sonst an (Stufe 1 und 2 gleich).
func set_shadows(level: int) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in _all_meshes():
		mi.cast_shadow = mode


## Bewegung je Bild: state = "walk", "idle", "look" (Umschauen), "browse" (ins Schaufenster
## schauen) oder "sit" (sitzen), speed = Tempo in m/s.
func animate(state: StringName, speed: float, delta: float) -> void:
	if _skeleton == null or _model == null:
		return
	if _player:
		_animate_clips(state, speed, delta)
		return
	_time += delta
	_sit = move_toward(_sit, 1.0 if state == &"sit" else 0.0, delta / 0.8)
	var walking := state == &"walk" and speed > 0.05
	var target_swing := clampf(speed / 1.2, 0.3, 1.2) if walking else 0.0
	_swing = move_toward(_swing, target_swing, delta * 3.0)
	if walking:
		var stride := STRIDE * _leg_length / LEG_REFERENCE
		_phase = fmod(_phase + delta * speed / stride * TAU, TAU)
	elif _swing < 0.01:
		_phase = move_toward(_phase, 0.0 if _phase < PI else TAU, delta * 4.0)
	var s := sin(_phase)
	var c := cos(_phase)
	var sit := smoothstep(0.0, 1.0, _sit)
	var turns := relaxed_arm_turns()
	# Beine: Oberschenkel schwingen (nach vorn = negative Drehung um x), das Knie beugt sich beim
	# Vorschwingen, der Fuß bleibt etwa waagerecht; im Sitzen Oberschenkel vor, Unterschenkel senkrecht
	for side in [["Left", 1.0], ["Right", -1.0]]:
		var thigh: float = -THIGH_SWING * s * side[1] * _swing
		var knee: float = (KNEE_BEND * maxf(0.0, c * side[1]) + 4.0) * _swing
		thigh = lerpf(thigh, -86.0, sit)
		knee = lerpf(knee, 86.0, sit)
		turns.append([side[0] + "UpperLeg", Vector3.RIGHT, thigh])
		turns.append([side[0] + "LowerLeg", Vector3.RIGHT, knee])
		turns.append([side[0] + "Foot", Vector3.RIGHT, lerpf(-(thigh + knee) * 0.6, 0.0, sit)])
		# Arme gegengleich zu den Beinen; im Sitzen locker auf den Schoß
		var arm: float = ARM_SWING * s * side[1] * _swing
		turns.append([side[0] + "UpperArm", Vector3.RIGHT, lerpf(arm, -38.0, sit)])
		turns.append([side[0] + "LowerArm", Vector3.UP, (6.0 * maxf(0.0, -arm / ARM_SWING) + 22.0 * sit) * -side[1]])
	# Oberkörper dreht leicht gegen die Hüfte, im Stehen ruhiges Atmen
	turns.append(["Spine", Vector3.UP, 4.0 * s * _swing])
	turns.append(["Chest", Vector3.RIGHT, sin(_time * 1.6) * 0.8 * (1.0 - minf(1.0, _swing))])
	# Kopf: beim Umschauen nach links und rechts, im Schaufenster leicht gesenkt
	var target_yaw := 0.0
	var target_pitch := 0.0
	if state == &"look":
		target_yaw = sin(_time * 1.4) * 40.0
	elif state == &"browse":
		target_yaw = sin(_time * 0.5) * 14.0
		target_pitch = 10.0
	_head_yaw = lerpf(_head_yaw, target_yaw, minf(1.0, delta * 5.0))
	_head_pitch = lerpf(_head_pitch, target_pitch, minf(1.0, delta * 3.0))
	turns.append(["Head", Vector3.RIGHT, _head_pitch])
	turns.append(["Head", Vector3.UP, _head_yaw - 4.0 * s * _swing])
	set_bone_turns(turns)
	# bei jedem Schritt hebt sich der Körper ein wenig; im Sitzen sitzt der Po auf der Sitzfläche
	var bob := absf(s) * 0.012 * _swing - 0.006 * _swing
	var seated := sit_height - (_hip_height - SIT_THIGH)
	_model.position.y = lerpf(bob, seated, sit)


## Bewegung über die Animationen der Figur.
func _animate_clips(state: StringName, speed: float, delta: float) -> void:
	_time += delta
	# Hinsetzen beginnt, wenn "sit" anfängt; Aufstehen, wenn "sit" endet – beide laufen ganz durch
	if state == &"sit" and _prev_state != &"sit":
		_start_transition(&"sit_down")
	elif state != &"sit" and _prev_state == &"sit":
		_start_transition(&"stand_up")
	_prev_state = state
	var clip: StringName = &"idle"
	var clip_speed := 1.0
	if _transition != &"":
		_transition_t += delta
		var length := _player.get_animation(_transition).length if _player.has_animation(_transition) else 0.0
		var t := clampf(_transition_t / maxf(length, 0.01), 0.0, 1.0)
		_seated = smoothstep(0.0, 1.0, t) if _transition == &"sit_down" else 1.0 - smoothstep(0.0, 1.0, t)
		clip = _transition
		if _transition_t >= length:
			_transition = &""
	if _transition == &"":
		match state:
			&"walk":
				clip = &"walk" if speed > 0.05 else &"idle"
				clip_speed = clampf(speed / maxf(_walk_speed, 0.1), 0.5, 2.0)
			&"sit":
				clip = &"sit_idle"
				_seated = 1.0
			&"browse":
				clip = &"idle_2"
			_:
				clip = &"idle"
		if state != &"sit":
			_seated = 0.0
	if _player.current_animation != clip and _player.has_animation(clip):
		_player.play(clip, BLEND)
	_player.speed_scale = clip_speed if clip == &"walk" else 1.0
	# Kopf: beim Umschauen nach links und rechts, im Schaufenster leicht gesenkt
	var target_yaw := 0.0
	var target_pitch := 0.0
	if state == &"look":
		target_yaw = sin(_time * 1.4) * 42.0
	elif state == &"browse":
		target_yaw = sin(_time * 0.5) * 14.0
		target_pitch = 10.0
	# Wer in der Nähe ist, wird angeschaut (hat Vorrang vor dem Umschauen)
	_update_face(state, delta, GameConfig.chibi_look_max_yaw)
	if _focus:
		target_yaw = _focus_turn.x
		target_pitch = _focus_turn.y
	_head_yaw = lerpf(_head_yaw, target_yaw, minf(1.0, delta * 5.0))
	_head_pitch = lerpf(_head_pitch, target_pitch, minf(1.0, delta * 3.0))
	_update_gesture(delta)
	if _head_modifier:
		_head_modifier.yaw = _head_yaw
		_head_modifier.pitch = _head_pitch + _nod_pitch + _gesture_head_pitch()
	# Sitzen: Figur auf die Höhe der Sitzfläche heben (die Animation sitzt auf ihrer eigenen Höhe)
	_model.position.y = (sit_height - _sit_seat) * _seated


## Radfahren: Haltung zur Kurbelstellung crank (Bogenmaß; 0 = Kurbel auf der Seite x < 0 vorn,
## wachsend = vorwärts treten). Die Animation "ride" ist genau eine Kurbelumdrehung; der Kopf schaut
## ab und zu ein wenig zur Seite.
func pose_ride(crank: float, delta: float) -> void:
	if _player == null or not _player.has_animation(&"ride"):
		return
	_time += delta
	if _player.current_animation != &"ride":
		_player.play(&"ride")
	_player.speed_scale = 0.0
	_player.seek(fposmod(crank / TAU, 1.0) * _player.get_animation(&"ride").length, true)
	# Kopf schaut ab und zu zur Seite – oder zu dem, der in der Nähe ist (weniger weit als zu Fuß)
	_update_face(&"ride", delta, GameConfig.chibi_look_max_yaw * 0.7)
	var target := Vector2(sin(_time * GameConfig.chibi_rider_glance_rate) * GameConfig.chibi_rider_glance, 0.0)
	if _focus:
		target = _focus_turn
	_head_yaw = lerpf(_head_yaw, target.x, minf(1.0, delta * 5.0))
	_head_pitch = lerpf(_head_pitch, target.y, minf(1.0, delta * 3.0))
	if _head_modifier:
		_head_modifier.yaw = _head_yaw
		_head_modifier.pitch = _head_pitch + _nod_pitch
	_model.position.y = 0.0


## Eine Geste zusätzlich zur Animation: &"wave" (winken), &"watch" (auf die Uhr schauen), &"stretch"
## (sich strecken). duration < 0: die übliche Dauer der Geste.
func play_gesture(gesture_name: StringName, duration: float = -1.0) -> void:
	var gestures := {&"wave": [ChibiGestureModifier.Gesture.WAVE, 2.2], &"watch": [ChibiGestureModifier.Gesture.WATCH, 2.6],
		&"stretch": [ChibiGestureModifier.Gesture.STRETCH, 2.4]}
	if not gestures.has(gesture_name):
		return
	_gesture = gestures[gesture_name][0]
	_gesture_left = duration if duration > 0.0 else float(gestures[gesture_name][1])
	_gesture_time = 0.0
	if gesture_name == &"watch":
		trigger_face(&"watch")
	elif gesture_name == &"stretch":
		trigger_face(&"stretch")


## Beim Plaudern erzählen die Hände mit (bis set_talking(false)).
func set_talking(on: bool) -> void:
	_talking = on


func _update_gesture(delta: float) -> void:
	if _gesture_modifier == null:
		return
	_gesture_time += delta
	var active := _gesture
	if _gesture != ChibiGestureModifier.Gesture.NONE:
		_gesture_left -= delta
		if _gesture_left <= 0.0:
			_gesture = ChibiGestureModifier.Gesture.NONE
	elif _talking:
		active = ChibiGestureModifier.Gesture.TALK
	var fading_in := _gesture != ChibiGestureModifier.Gesture.NONE or _talking
	if fading_in and active != ChibiGestureModifier.Gesture.NONE:
		if _gesture_modifier.gesture != active:
			_gesture_modifier.weight = 0.0
			_gesture_modifier.time = 0.0
		_gesture_modifier.gesture = active
		var ramp := 0.45 if _gesture_left > 0.4 or _talking else _gesture_left / 0.4 * 0.45
		_gesture_modifier.weight = move_toward(_gesture_modifier.weight, 1.0 if ramp >= 0.45 else ramp / 0.45, delta / 0.35)
	else:
		_gesture_modifier.weight = move_toward(_gesture_modifier.weight, 0.0, delta / 0.35)
		if _gesture_modifier.weight <= 0.0:
			_gesture_modifier.gesture = ChibiGestureModifier.Gesture.NONE
	_gesture_modifier.time = _gesture_time
	# beim Plaudern ab und zu kurz ruhige Hände
	_gesture_modifier.talk_energy = clampf(0.6 + 0.6 * sin(_gesture_time * 0.7), 0.0, 1.0)


## Beim Blick auf die Uhr schaut der Kopf nach unten.
func _gesture_head_pitch() -> float:
	if _gesture_modifier and _gesture_modifier.gesture == ChibiGestureModifier.Gesture.WATCH:
		return 24.0 * _gesture_modifier.weight
	return 0.0


func _start_transition(clip: StringName) -> void:
	if _player.has_animation(clip):
		_transition = clip
		_transition_t = 0.0
		_player.play(clip, BLEND)


## Mimik und Blick je Bild: Ausdruck zurück zum Grundausdruck oder ab und zu ein anderer, Augen
## schauen hin und her; wer in der Nähe ist, wird angeschaut (_focus, Kopfdrehung _focus_turn, den
## Rest machen die Augen) und manchmal gegrüßt (Lächeln + Nicken, _nod_pitch).
func _update_face(state: StringName, delta: float, max_yaw: float) -> void:
	if _mood_left > 0.0:
		_mood_left -= delta
		if _mood_left <= 0.0:
			mood = FaceTriggers.BASE
	# Vor dem Schaufenster: erst Staunen, dann ab und zu „gefällt mir“ (sonst kein Wechsel ohne Anlass)
	var browsing := state == &"browse"
	if browsing and not _was_browsing:
		_mood_wait = randf_range(0.6, 1.4)
		_browse_count = 0
	_was_browsing = browsing
	if browsing:
		_mood_wait -= delta
		if _mood_wait <= 0.0 and _mood_left <= 0.0:
			trigger_face(&"window_wonder" if _browse_count == 0 else &"window_like")
			_browse_count += 1
			_mood_wait = randf_range(3.0, 6.0)
	elif state == &"sit" and _mood_left <= 0.0 and randf() < delta * 0.05:
		trigger_face(&"sit_rest")
	# Wen anschauen? (nicht jedes Bild)
	_scan_wait -= delta
	if _scan_wait <= 0.0:
		_scan_wait = randf_range(0.25, 0.4)
		_scan_focus()
	var eyes_target := _glance
	if _focus:
		var d := global_transform.basis.inverse() * (_focus_point() - eye_point())
		var yaw := rad_to_deg(atan2(d.x, d.z))
		var pitch := -rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
		_focus_turn = Vector2(clampf(yaw, -max_yaw, max_yaw),
			clampf(pitch, -GameConfig.chibi_look_max_pitch, GameConfig.chibi_look_max_pitch))
		eyes_target = Vector2(clampf((yaw - _head_yaw) / 30.0, -1.0, 1.0), clampf(-(pitch - _head_pitch) / 20.0, -1.0, 1.0))
	else:
		_glance_wait -= delta
		if _glance_wait <= 0.0:
			_glance_wait = randf_range(GameConfig.chibi_glance_wait.x, GameConfig.chibi_glance_wait.y)
			var r := GameConfig.chibi_glance_range
			# öfter wieder geradeaus
			_glance = Vector2.ZERO if randf() < 0.35 else Vector2(randf_range(-r.x, r.x), randf_range(-r.y, r.y))
		eyes_target = _glance
	# Augen springen schnell zum neuen Ziel
	_eyes = _eyes.lerp(eyes_target, minf(1.0, delta * 14.0))
	if _eyes.distance_to(look) > 0.01:
		look = _eyes
	# dezentes Nicken: einmal kurz nach unten und zurück
	_nod_pitch = 0.0
	if _nod_t >= 0.0:
		_nod_t += delta
		var t := _nod_t / GameConfig.chibi_nod_time
		if t >= 1.0:
			_nod_t = -1.0
		else:
			_nod_pitch = sin(PI * t) * GameConfig.chibi_nod_angle


func _show_mood(new_mood: Mood, duration: float) -> void:
	mood = new_mood
	_mood_left = duration


## Ein Gesichtsausdruck aus einem Anlass (Auslöser aus FaceTriggers.TRIGGERS, z. B. &"greet").
func trigger_face(trigger: StringName) -> void:
	var picked := FaceTriggers.pick(trigger)
	if not picked.is_empty():
		_show_mood(picked[0], picked[1])


## Wer ist am interessantesten? Die Spielfigur (Kamera) immer zuerst, sonst die nächste andere Figur,
## die vor einem ist (nicht direkt daneben – wer nebeneinander geht, starrt sich nicht an); nur, was
## nicht verdeckt ist. Beim ersten Nahekommen vielleicht grüßen.
func _scan_focus() -> void:
	var me := eye_point()
	var forward := global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Node3D = null
	var best_dist := INF
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera:
		var dist := _focus_distance(me, forward, camera.global_position, GameConfig.chibi_look_player_radius,
			GameConfig.chibi_look_angle)
		if dist < INF and _line_clear(me, camera.global_position):
			best = camera
			best_dist = dist
	if best == null:
		for other in _everyone:
			if other == self or not other.is_visible_in_tree():
				continue
			var dist := _focus_distance(me, forward, other.eye_point(), GameConfig.chibi_look_others_radius,
				GameConfig.chibi_look_others_angle)
			if dist < best_dist:
				best = other
				best_dist = dist
	_focus = best
	if best == null or best_dist > GameConfig.chibi_greet_radius:
		return
	var id := best.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_greeted.get(id, -INF)) < GameConfig.chibi_greet_cooldown:
		return
	_greeted[id] = now
	var chance := GameConfig.chibi_greet_chance_player if best == camera else GameConfig.chibi_greet_chance_others
	if randf() < chance:
		# Grüßen: Lächeln und Nicken, manchmal auch winken
		var wave := randf() < GameConfig.chibi_wave_chance
		trigger_face(&"wave" if wave else &"greet")
		_nod_t = 0.0
		if wave:
			play_gesture(&"wave")


## Abstand zu einem Punkt, wenn er nah genug und etwa vor der Figur ist (höchstens angle Grad
## neben der Blickrichtung; sonst INF).
func _focus_distance(me: Vector3, forward: Vector3, point: Vector3, radius: float, angle: float) -> float:
	var d := point - me
	var dist := d.length()
	if dist > radius or dist < 0.2:
		return INF
	var flat := Vector3(d.x, 0.0, d.z).normalized()
	if rad_to_deg(forward.angle_to(flat)) > angle:
		return INF
	return dist


func _focus_point() -> Vector3:
	if _focus is ChibiPasserbyModel:
		return (_focus as ChibiPasserbyModel).eye_point()
	return _focus.global_position


## Sieht man von a nach b? (Häuser und Mauern verdecken, Glas mit Metadaten "see_through" nicht)
func _line_clear(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a, b, SIGHT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.collider as Object).has_meta("see_through")
