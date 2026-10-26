@tool
class_name ChibiPasserbyModel
extends ChibiCharacter
## Chibi-Figur als Passant (seit Etappe 5c): zufälliges Aussehen (randomize_look: Körper, Haut,
## Augen, Frisur, Kleidung und Farben) und eine einfache eigene Bewegung (animate: Gehen, Stehen,
## Umschauen, ins Schaufenster schauen, Sitzen) – bis die Mixamo-Animationen eingebaut sind.
## Dieselbe Schnittstelle wie PasserbyPlaceholder (Passerby ruft randomize_look, animate,
## set_shadows; sit_height = Höhe der Sitzfläche).

## Meter je Doppelschritt bei 0,55 m Beinlänge (so passen die Schritte zum Tempo)
const STRIDE := 0.95
const LEG_REFERENCE := 0.55
## Schwung beim Gehen (Grad): Oberschenkel, Knie beim Vorschwingen, Arme
const THIGH_SWING := 24.0
const KNEE_BEND := 34.0
const ARM_SWING := 16.0
## Beim Sitzen: so tief liegt die Sitzfläche unter dem Hüftgelenk (Dicke des Oberschenkels)
const SIT_THIGH := 0.062

## Höhe der Sitzfläche beim Sitzen (Meter; setzt Passerby).
var sit_height := 0.45

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
