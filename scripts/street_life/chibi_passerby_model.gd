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

## Höhe der Sitzfläche beim Sitzen (Meter; setzt Passerby).
var sit_height := 0.45
## Weg (m) und Dauer (s) des Hinsetzens laut Animation (0 = Passerby nimmt eigene Werte).
var sit_front := 0.0
var sit_time := 0.0
## Fahrrad passend zu dieser Figur: so viel kleiner als das Hollandrad in echter Größe (aus der
## Animation "ride"; 0 = Figur ohne Radfahr-Animation).
var ride_scale := 0.0

var _player: AnimationPlayer
var _head_modifier: ChibiHeadModifier
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
	mood = [Mood.NEUTRAL, Mood.NEUTRAL, Mood.HAPPY, Mood.CONTENT][rng.randi_range(0, 3)]
	_measure()


func _pick(rng: RandomNumberGenerator, colors: Array[Color]) -> Color:
	return colors[rng.randi_range(0, colors.size() - 1)] if not colors.is_empty() else Color.WHITE


## Nach dem Laden der Figur: AnimationPlayer, Angaben zu den Animationen, Kopf-Drehung.
func _rebuild() -> void:
	super._rebuild()
	_player = null
	_head_modifier = null
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
		_player.play(&"idle")
	if _skeleton:
		_head_modifier = ChibiHeadModifier.new()
		_head_modifier.name = "HeadModifier"
		_skeleton.add_child(_head_modifier)
	_prev_state = &""
	_transition = &""
	_seated = 0.0
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


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
	_head_yaw = lerpf(_head_yaw, target_yaw, minf(1.0, delta * 5.0))
	_head_pitch = lerpf(_head_pitch, target_pitch, minf(1.0, delta * 3.0))
	if _head_modifier:
		_head_modifier.yaw = _head_yaw
		_head_modifier.pitch = _head_pitch
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
	if _head_modifier:
		_head_modifier.yaw = sin(_time * GameConfig.chibi_rider_glance_rate) * GameConfig.chibi_rider_glance
		_head_modifier.pitch = 0.0
	_model.position.y = 0.0


func _start_transition(clip: StringName) -> void:
	if _player.has_animation(clip):
		_transition = clip
		_transition_t = 0.0
		_player.play(clip, BLEND)
