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
## Seit Etappe 6h (Teil 8) mit den Animationen der Entwicklerin: jede Figur hat ihre Gangart (walk_clip: walk,
## walk_female/walk_male, stroll = schlendern, walk_bag = mit Einkaufstasche), ihre Art zu stehen (idle_clip) und
## zu sitzen (sit_clip); einzelne Auftritte über play_clip (Umschauen, Strecken, Gähnen, Seufzen, Winken, Nicken,
## Zeigen, Lachen, Händeschütteln, Katze streicheln); beim Plaudern reden die Hände (talk…, im Sitzen sit_talk…).
## Wer eine Einkaufstasche trägt (carries_bag), hält sie in der rechten Hand; sie hängt senkrecht und pendelt.

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
## Animationen, die sich wiederholen (seit Etappe 6h auch Gangarten, Stehen, Reden und Sitzen); gekürzte
## Animationen laufen hin und her (PINGPONG), damit es an der Schnittstelle nicht springt.
const LOOPS: Array[StringName] = [&"walk", &"idle", &"idle_2", &"sit_idle", &"ride", &"walk_female", &"walk_male",
	&"stroll", &"walk_bag", &"idle_happy", &"idle_foot", &"talk", &"talk_one", &"talk_two", &"sit_restless"]
const PINGPONG: Array[StringName] = [&"idle_shift", &"idle_bag", &"sit_talk", &"sit_talk_legs", &"sit_talk_hands"]
## Händeschütteln: Lage der rechten Hand beim Schütteln (x seitlich, z vorn; × Hüfthöhe der Figur, gemessen in
## der Animation handshake zwischen 1,6 und 2,5 s – seit der Nachbesserung mit dem kleinen Schritt nach vorn: 0,73)
## plus eine halbe Handdicke, sonst stecken die Hände ineinander
const HANDSHAKE_HAND := Vector2(-0.025, 0.775)
## Katze streicheln: dort ist die Hand (x seitlich, z vorn; × Hüfthöhe): kurz bücken (pet_reach, Hand nah am
## Boden, Abschnitt PET_REACH_HOLD hin und her) bzw. hinknien (pet_cat, Hand auf etwa 0,55 × Hüfthöhe)
const PET_REACH_HAND := Vector2(-0.033, 0.32)
const PET_KNEEL_HAND := Vector2(-0.29, 0.85)
const PET_REACH_HOLD := Vector2(1.7, 2.5)
## Zeitpunkt (s), an dem die Hand die Katze erreicht
const PET_REACH_TOUCH := 1.2
const PET_KNEEL_TOUCH := 2.3
## Winken im Gehen und Sitzen: nur der rechte Arm aus der Animation wave (Abschnitt in Sekunden)
const WAVE_CLIP := Vector2(0.45, 3.35)
## Auftritte über den ganzen Körper (Schritt, Bücken, Knien, Tür, Gießen, Heben) – alle anderen nur Oberkörper
const FULL_BODY: Array[StringName] = [&"handshake", &"pet_reach", &"pet_cat", &"door_in", &"door_out", &"water", &"pick_up",
	&"lift"]
## Überblenden der Ebenen (s); Zeitpunkt in sit_talk_legs mit übereinandergeschlagenen Beinen
const LAYER_BLEND := 0.4
const LEGS_CROSSED_TIME := 2.0
const RIGHT_ARM: PackedStringArray = ["RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"RightThumbMetacarpal", "RightThumbProximal", "RightThumbDistal", "RightIndexProximal", "RightIndexIntermediate",
	"RightIndexDistal", "RightMiddleProximal", "RightMiddleIntermediate", "RightMiddleDistal", "RightRingProximal",
	"RightRingIntermediate", "RightRingDistal", "RightLittleProximal", "RightLittleIntermediate", "RightLittleDistal"]
## Ausdrücke mit offenen Augen: ab und zu zwischendurch, vor dem Schaufenster, beim Grüßen.
## Ausdrücke kommen seit Etappe 6c nur über Auslöser (FaceTriggers, trigger_face) – sonst neutral-freundlich.
## Physik-Ebenen, die den Blick verdecken (world, sight_blocker).
const SIGHT_MASK := 1 | 128

## Alle Chibi-Figuren auf der Straße (für Blicke und Grüße untereinander).
static var _everyone: Array[ChibiPasserbyModel] = []

## Höhe der Sitzfläche beim Sitzen (Meter; setzt Passerby).
var sit_height := 0.45
## Kopfhöhe sitzend = (Kopf oben − Hüfte in Ruhehaltung) × SLOPE + BASE (head_above_seat)
const SIT_HEAD_SLOPE := 1.31
const SIT_HEAD_BASE := -0.075
## Weg (m) und Dauer (s) des Hinsetzens laut Animation (0 = Passerby nimmt eigene Werte).
var sit_front := 0.0
var sit_time := 0.0
## Fahrrad passend zu dieser Figur (aus der Animation "ride"; 0 = Figur ohne Radfahr-Animation):
## Rahmengröße gegenüber dem Hollandrad in voller Größe und Höhe des Sitzpunkts (volle Größe).
var ride_scale := 0.0
var ride_seat := 0.0
## Anhalten auf dem Rad (seit der Nachbesserung 3 von 6h, Haltung "ride_stop"): Kurbelstellung und Neigung des Rads
## nach links (Grad), aus der Figur
var ride_stop_crank := PI / 4.0
var ride_stop_lean := 0.0
## Ebene für die Anhalte-Haltung (erst beim ersten Anhalten angelegt)
var _ride_mod: ChibiGestureModifier
## Gangart, Art zu stehen und zu sitzen (randomize_look), Einkaufstasche in der rechten Hand
var walk_clip: StringName = &"walk"
var idle_clip: StringName = &"idle"
var sit_clip: StringName = &"sit_idle"
var carries_bag := false

var _player: AnimationPlayer
var _head_modifier: ChibiHeadModifier
## Gesten zusätzlich zur Animation (seit Etappe 6c): welche, wie lange noch, plaudert gerade
var _gesture_modifier: ChibiGestureModifier
## Zeit des letzten Lauts dieser Figur (PasserbyVoice)
var _voice_last := -100.0
## Seit wann die Figur zur Spielfigur schaut (-1 = gerade nicht) und bis wann sie es nicht wieder tut
var _player_look_since := -1.0
var _player_rest_until := 0.0
var _gesture: ChibiGestureModifier.Gesture = ChibiGestureModifier.Gesture.NONE
var _gesture_left := 0.0
var _gesture_time := 0.0
var _talking := false
## Tempo, bei dem die Füße der Geh-Animation genau passen; Höhe der Sitzfläche unter dem Po.
var _walk_speed := 1.0
var _sit_seat := 0.23
## Tempo je Gangart (Animation → m/s, aus der Figur)
var _walk_speeds: Dictionary = {}
var _prev_state: StringName = &""
## Einzelner Auftritt (play_clip): Animation, Restzeit, Abschnitt zum Hin-und-her, Richtung …; leer = keiner
var _shot: Dictionary = {}
## Beim Plaudern: Animation des Erzählens (leer = Gesten über den GestureModifier), beim Start an zufälliger Stelle
var _talk_clip: StringName = &""
## Ebenen über der Grundbewegung (seit der Nachbesserung 3 von 6h, weichere Übergänge): Oberkörper aus Rede-, Lach-,
## Nick- und Zeige-Animationen (die Beine bleiben aus Stehen bzw. Sitzen – nichts rutscht mehr); im Sitzen manchmal
## übereinandergeschlagene Beine (aus sit_talk_legs, weich hinein und wieder heraus)
var _upper_mod: ChibiGestureModifier
var _legs_mod: ChibiGestureModifier
var _upper: Dictionary = {}  # clip, t, left, loop
var _legs_cross := false
var _legs_wait := 0.0
## Gesprächspartner (wird angeschaut, auch wenn er daneben sitzt); etwas, das gezielt angeschaut wird (look_at_node)
var _chat_partner: Node3D
## Beim gemeinsamen Gehen abwechselnd zum Gegenüber und nach vorn schauen (seit Nachbesserung 4 von 6h)
var _walk_look_on := true
var _walk_look_until := 0.0
## Beim Überqueren der Fahrbahn nach links und rechts schauen (Passerby setzt das)
var road_scan := false
## Sitzen (Passanten, nicht am Steuer): entspannt, Hände auf den Oberschenkeln. Lehne hinter dem Sitz (Abstand von der
## Sitzmitte in m, 0 = keine) und ob sich diese Figur gerade daran anlehnt (Passerby setzt das beim Hinsetzen).
var relaxed_sit := false
var sit_backrest := 0.0
var sit_leans := false
var _back_shift := 0.0
var _attention: Node3D
## Einkaufstasche: Modell, Pendel (Ausschlag x/z in Bogenmaß, Geschwindigkeit), letzte Lage/Geschwindigkeit der Hand
var _bag: Node3D
var _bag_swing := Vector2.ZERO
var _bag_spin := Vector2.ZERO
var _hand_last := Vector3.INF
var _hand_vel := Vector3.ZERO
var _hand_bone := -1
## Gegenstand in der Hand (seit Etappe 6i): Art (&"can", &"broom", &"mug", &"cup", &"cake" …), Modell, Halter an der Hand
var _prop_kind: StringName = &""
var _prop: Node3D
var _prop_mount: BoneAttachment3D
## Arbeit gerade (Gießen/Fegen): "" = keine, sonst "water"/"sweep"; Umarmung läuft; im Sitzen: Schluck trinken bzw. essen
var _chore := ""
var _chore_time := 0.0
var _hugging := false
var _sip_t := -1.0
## Übergänge Hinsetzen/Aufstehen: welcher läuft gerade und seit wann
var _transition: StringName = &""
var _transition_t := 0.0
var _seated := 0.0

var _phase := 0.0
var _swing := 0.0
var _sit := 0.0
var _time := 0.0
var _head_yaw := 0.0
var _skirt_sit := 0.0
var _pet_target: Node3D
var _bag_down := 0.0
var _bag_height := 0.0
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
	restyle(rng)
	# Grundausdruck neutral (Augen offen – so läuft und fährt man); andere Ausdrücke kommen ab und zu
	mood = Mood.NEUTRAL
	_mood_left = 0.0
	_mood_wait = rng.randf_range(GameConfig.chibi_mood_wait.x, GameConfig.chibi_mood_wait.y)
	_measure()


func _pick(rng: RandomNumberGenerator, colors: Array[Color]) -> Color:
	return colors[rng.randi_range(0, colors.size() - 1)] if not colors.is_empty() else Color.WHITE


## Gangart, Art zu stehen und zu sitzen, Einkaufstasche neu auswürfeln (seit Etappe 6h; StreetLife ruft das bei
## jedem Losgehen – so ist nicht immer dieselbe Figur mit Tasche unterwegs). Mit Tasche gehen und stehen sie anders.
func restyle(rng: RandomNumberGenerator) -> void:
	var female := int(figure) < 3
	carries_bag = rng.randf() < GameConfig.passerby_bag_share
	if carries_bag:
		walk_clip = &"walk_bag"
		idle_clip = &"idle_bag"
	else:
		walk_clip = _weighted(rng, GameConfig.passerby_walk_styles.get("female" if female else "male", {}), &"walk")
		idle_clip = _weighted(rng, GameConfig.passerby_idle_styles, &"idle")
	sit_clip = _weighted(rng, GameConfig.passerby_sit_styles, &"sit_idle")
	_set_bag(rng)


## Ein Eintrag aus {Name: Gewicht}, zufällig nach Gewicht.
static func _weighted(rng: RandomNumberGenerator, weights: Dictionary, fallback: StringName) -> StringName:
	var total := 0.0
	for key in weights:
		total += float(weights[key])
	var r := rng.randf() * total
	for key in weights:
		r -= float(weights[key])
		if r <= 0.0:
			return StringName(key)
	return fallback


## Einkaufstasche geben oder wegnehmen (seit Etappe 6i: nach dem Einkauf, Anwohner bei der Arbeit); Gangart passt sich an.
func give_bag(on: bool, model_path: String = "") -> void:
	carries_bag = on
	if on:
		walk_clip = &"walk_bag"
		idle_clip = &"idle_bag"
	elif walk_clip == &"walk_bag":
		walk_clip = &"walk"
		idle_clip = &"idle"
	if _bag:
		_bag.queue_free()
		_bag = null
	if not on:
		return
	var path := model_path if not model_path.is_empty() else GameConfig.passerby_bag_models[randi() % GameConfig.passerby_bag_models.size()]
	var scene := load(path) as PackedScene
	if scene == null:
		return
	_bag = scene.instantiate() as Node3D
	_bag.name = "Bag"
	_bag.top_level = true
	add_child(_bag)
	_bag_height = 0.0
	_bag_swing = Vector2.ZERO
	_bag_spin = Vector2.ZERO
	_hand_last = Vector3.INF


## Einkaufstasche an- oder ablegen (zufällig eine der Taschen aus GameConfig.passerby_bag_models).
func _set_bag(rng: RandomNumberGenerator) -> void:
	if _bag:
		_bag.queue_free()
		_bag = null
	if not carries_bag or GameConfig.passerby_bag_models.is_empty():
		return
	var scene := load(GameConfig.passerby_bag_models[rng.randi() % GameConfig.passerby_bag_models.size()]) as PackedScene
	if scene == null:
		return
	_bag = scene.instantiate() as Node3D
	_bag.name = "Bag"
	_bag.top_level = true
	add_child(_bag)
	_bag_height = 0.0
	_bag_swing = Vector2.ZERO
	_bag_spin = Vector2.ZERO
	_hand_last = Vector3.INF


## Tempo dieser Gangart gegenüber dem normalen Gehen (schlendern und mit Tasche langsamer, StreetLife).
func speed_factor() -> float:
	var base := float(_walk_speeds.get("walk", _walk_speed))
	var mine := float(_walk_speeds.get(String(walk_clip), base))
	var limits := GameConfig.passerby_style_speed_limits
	return clampf(mine / maxf(base, 0.01), limits.x, limits.y)


## Lage der rechten Hand beim Händeschütteln bzw. beim Streicheln (x seitlich, z vorn; Meter in der Figur).
func handshake_hand() -> Vector2:
	return HANDSHAKE_HAND * _hip_height


## Höhe der rechten Hand beim Händeschütteln (m; × Hüfthöhe, gemessen) – sehr verschieden große Figuren schütteln
## sich nicht die Hand (die Animation passt die Höhe nicht an).
func handshake_height() -> float:
	return 1.13 * _hip_height


func pet_hand(kneel: bool) -> Vector2:
	return (PET_KNEEL_HAND if kneel else PET_REACH_HAND) * _hip_height


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
		for anim_name in PINGPONG:
			if _player.has_animation(anim_name):
				_player.get_animation(anim_name).loop_mode = Animation.LOOP_PINGPONG
		var extras: Dictionary = {}
		for node in [_skeleton, _skeleton.get_parent() if _skeleton else null]:
			if node and node.has_meta("extras"):
				extras = node.get_meta("extras")
		var info: Dictionary = extras.get("chibi_anim", {})
		_walk_speed = float(info.get("walk_speed", 1.0))
		_walk_speeds = info.get("walk_speeds", {})
		_sit_seat = float(info.get("sit_seat", 0.23))
		sit_front = float(info.get("sit_down_shift", 0.0))
		sit_time = float(info.get("sit_down_time", 0.0))
		ride_scale = float(info.get("ride_scale", 0.0))
		ride_seat = float(info.get("ride_seat", 0.0))
		ride_stop_crank = float(info.get("ride_stop_crank", PI / 4.0))
		ride_stop_lean = float(info.get("ride_stop_lean", 0.0)) if _player.has_animation(&"ride_stop") else 0.0
		_player.play(&"idle")
	_head_bone = _skeleton.find_bone("Head") if _skeleton else -1
	if _skeleton:
		var upper_bones := PackedStringArray()
		for i in _skeleton.get_bone_count():
			var bone_name := _skeleton.get_bone_name(i)
			if bone_name == "Hips" or bone_name.contains("Leg") or bone_name.contains("Foot") or bone_name.contains("Toes"):
				continue
			upper_bones.append(bone_name)
		_upper_mod = _layer("UpperLayer", upper_bones)
		_legs_mod = _layer("LegsLayer", PackedStringArray(["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
			"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]))
		_gesture_modifier = ChibiGestureModifier.new()
		_gesture_modifier.name = "GestureModifier"
		_skeleton.add_child(_gesture_modifier)
		_head_modifier = ChibiHeadModifier.new()
		_head_modifier.name = "HeadModifier"
		_head_modifier.head_scale = GameConfig.chibi_head_scale
		_skeleton.add_child(_head_modifier)
	_prev_state = &""
	_transition = &""
	_seated = 0.0
	_shot = {}
	_upper = {}
	_legs_cross = false
	_hand_bone = _skeleton.find_bone("RightHand") if _skeleton else -1
	_hand_last = Vector3.INF
	_prop = null
	_prop_mount = null
	_prop_kind = &""
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


func _enter_tree() -> void:
	if not Engine.is_editor_hint() and not _everyone.has(self):
		_everyone.append(self)


func _exit_tree() -> void:
	_everyone.erase(self)


## Wie hoch der Kopf (mit Frisur) über der Sitzfläche ist, wenn die Figur sitzt (Meter, ohne eigene Skalierung) –
## für Fahrer in Autos (seit Etappe 6f passt VehicleModel die Größe an die Kopffreiheit an). Aus der Ruhehaltung:
## oberster Punkt von Körper und Frisur über der Hüfte, umgerechnet mit SIT_HEAD_* (an allen sechs Figuren und
## Frisuren in der Sitz-Animation gemessen, eher etwas zu hoch).
func head_above_seat() -> float:
	var m := head_metrics()
	return (m.x - m.y) * SIT_HEAD_SLOPE + SIT_HEAD_BASE


## [oberster Punkt (Körper + sichtbare Frisur), Hüfthöhe] in der Ruhehaltung, Koordinaten der Figur.
func head_metrics() -> Vector2:
	if _model == null or _skeleton == null:
		return Vector2(1.0, 0.5)
	var top := 0.0
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		if not (mi.name.begins_with("Hair") or mi.name == "Body"):
			continue
		var box := mi.mesh.get_aabb()
		top = maxf(top, box.end.y)
	var hip := _skeleton.find_bone("LeftUpperLeg")
	var hip_y := _skeleton.get_bone_global_rest(hip).origin.y if hip >= 0 else top * 0.45
	return Vector2(top, hip_y)


## Augenhöhe der Figur (Welt).
func eye_point() -> Vector3:
	if _skeleton and _head_bone >= 0:
		return _skeleton.global_transform * (_skeleton.get_bone_global_pose(_head_bone).origin + Vector3(0.0, 0.09, 0.0))
	return global_position + Vector3.UP


## Unsichtbare Passanten (im Vorrat) rechnen keine Animation.
func _on_visibility_changed() -> void:
	if _player:
		_player.active = is_visible_in_tree()
	_hand_last = Vector3.INF


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
	# negatives Tempo = rückwärts (ein Schritt zurück beim Plaudern): die Geh-Animation läuft rückwärts
	var walking := state == &"walk" and absf(speed) > 0.05
	if _transition == &"":
		var walk_name := walk_clip if _player.has_animation(walk_clip) else &"walk"
		var idle_name := idle_clip if _player.has_animation(idle_clip) else &"idle"
		match state:
			&"walk":
				clip = walk_name if walking else idle_name
				var natural := float(_walk_speeds.get(String(walk_name), _walk_speed))
				clip_speed = signf(speed) * clampf(absf(speed) / maxf(natural, 0.1), 0.5, 2.0)
			&"sit":
				clip = sit_clip if _player.has_animation(sit_clip) else &"sit_idle"
				_seated = 1.0
			&"browse":
				clip = &"idle_bag" if carries_bag else &"idle_2"
			_:
				clip = idle_name
		if state != &"sit":
			_seated = 0.0
		# Einzelner Auftritt hat Vorrang – solange die Haltung passt (Gehen beendet ihn)
		if not _shot.is_empty():
			if bool(_shot.seated) != (state == &"sit") or walking:
				_shot = {}
			else:
				clip = _shot.clip
	elif not _shot.is_empty():
		_shot = {}
	var restart: bool = not _player.is_playing() and (_shot.is_empty() or clip != _shot.clip)
	if _player.has_animation(clip) and (_player.current_animation != clip or restart):
		# ins Sitzen und zwischen Sitz-Haltungen langsamer überblenden (weicher)
		_player.play(clip, BLEND * (2.0 if state == &"sit" or _seated > 0.0 else 1.0))
	_update_layers(state, walking, delta)
	# Im Sitzen entspannt zurückgelehnt (nur Passanten, nicht am Steuer; weich hin und zurück)
	if _gesture_modifier:
		_update_sit_rest(state, delta)
	if not _shot.is_empty() and clip == _shot.clip:
		_player.speed_scale = _update_shot(delta)
	else:
		_player.speed_scale = clip_speed if walking else 1.0
	# Kopf: beim Umschauen nach links und rechts, im Schaufenster leicht gesenkt
	var target_yaw := 0.0
	var target_pitch := 0.0
	if state == &"look":
		target_yaw = sin(_time * 1.4) * 42.0
	elif state == &"browse":
		target_yaw = sin(_time * 0.5) * 14.0
		target_pitch = 10.0
	elif road_scan:
		target_yaw = sin(_time * 1.3) * 40.0
	# Wer in der Nähe ist, wird angeschaut (hat Vorrang vor dem Umschauen) – beim Umschauen an der Bordsteinkante nur das
	# Auto, dem man nachschaut, nicht der Begleiter
	_update_face(state, delta, GameConfig.chibi_look_max_yaw)
	if _focus and (state != &"look" or _attention != null):
		target_yaw = _focus_turn.x
		target_pitch = _focus_turn.y
	_head_yaw = lerpf(_head_yaw, target_yaw, minf(1.0, delta * 5.0))
	_head_pitch = lerpf(_head_pitch, target_pitch, minf(1.0, delta * 3.0))
	_update_gesture(delta)
	_update_pet(delta)
	if _head_modifier:
		_head_modifier.yaw = _head_yaw
		_head_modifier.pitch = _head_pitch + _nod_pitch + _gesture_head_pitch()
		# Wer jemanden anschaut, hält den Kopf dorthin (die Animation dreht ihn nicht gleichzeitig weg)
		_head_modifier.hold = move_toward(_head_modifier.hold, 0.85 if _focus else 0.0, delta * 2.0)
	# Sitzen: Figur auf die Höhe der Sitzfläche heben (die Animation sitzt auf ihrer eigenen Höhe)
	_model.position.y = (sit_height - _sit_seat) * _seated
	# Rock: im Sitzen eng um die Oberschenkel (weich hinein und heraus)
	if bottom == Bottom.SKIRT:
		_skirt_sit = move_toward(_skirt_sit, 1.0 if state == &"sit" else 0.0, delta / 0.6)
		set_skirt_sit(_skirt_sit)
	_update_bag(delta)
	_update_chore(delta)


## Einzelner Auftritt je Bild: Abschnitt hin und her, danach vorwärts zu Ende oder rückwärts zum Anfang.
## Liefert die Abspielrichtung (speed_scale).
func _update_shot(delta: float) -> float:
	var pos := _player.current_animation_position
	var hold: Vector2 = _shot.hold
	var direction := float(_shot.dir)
	_shot.left = float(_shot.left) - delta
	if float(_shot.hold_left) > 0.0 and (bool(_shot.holding) or pos >= hold.x):
		_shot.holding = true
		_shot.hold_left = float(_shot.hold_left) - delta
		if direction > 0.0 and pos >= hold.y:
			direction = -1.0
		elif direction < 0.0 and pos <= hold.x:
			direction = 1.0
	elif bool(_shot.back) and pos >= hold.y - 0.02:
		direction = -1.0
	_shot.dir = direction
	# zu Ende: Zeit um (weich in die Grundhaltung) bzw. rückwärts wieder am Anfang
	# (kurz vor dem Ende, sonst hält der AnimationPlayer an und finge von vorn an)
	if float(_shot.left) <= 0.12 or (direction < 0.0 and float(_shot.hold_left) <= 0.0 and pos <= 0.03):
		_shot = {}
		return 1.0
	return direction


## Einkaufstasche: hängt am Griffpunkt der rechten Hand senkrecht nach unten (wie die Figur gedreht), pendelt
## mit den Bewegungen der Hand und wird vom Bein nach außen gedrückt.
func _update_bag(delta: float) -> void:
	if _bag == null:
		return
	_bag.visible = is_visible_in_tree()
	if _skeleton == null or _hand_bone < 0 or not _bag.visible or delta <= 0.0:
		return
	# Im Sitzen steht die Tasche neben einem auf dem Boden (seit Etappe 6j – vorher setzten sich Taschenträger nie):
	# beim Hinsetzen wandert sie aus der Hand hinunter, beim Aufstehen wieder hinauf
	_bag_down = move_toward(_bag_down, 1.0 if _seated > 0.5 else 0.0, delta / GameConfig.passerby_bag_set_down_time)
	if _bag_down >= 1.0:
		_bag.global_transform = _bag_ground()
		_hand_last = Vector3.INF
		_bag_swing = Vector2.ZERO
		_bag_spin = Vector2.ZERO
		return
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bone)
	var grip := hand * Vector3(0.0, 0.05, -0.02)
	if _hand_last == Vector3.INF:
		_hand_last = grip
		_hand_vel = Vector3.ZERO
	var vel := (grip - _hand_last) / delta
	var acc := (vel - _hand_vel) / delta
	_hand_last = grip
	_hand_vel = vel
	var yaw := Basis(Vector3.UP, global_rotation.y)
	var local_acc := yaw.inverse() * acc
	local_acc = local_acc.limit_length(30.0)
	# Pendel: Ausschlag der Unterkante in x und z (Bogenmaß)
	var length := GameConfig.passerby_bag_pendulum
	var force := -_bag_swing * (9.8 / length) - Vector2(local_acc.x, local_acc.z) / length - _bag_spin * GameConfig.passerby_bag_damping
	_bag_spin += force * delta
	_bag_swing += _bag_spin * delta
	var limit := deg_to_rad(GameConfig.passerby_bag_max_swing)
	_bag_swing = _bag_swing.clamp(Vector2(-limit, -limit), Vector2(limit, limit))
	# vom Bein weg: die Mitte der Tasche bleibt mindestens passerby_bag_clear außen (rechts = -x)
	var local_grip := global_transform.affine_inverse() * grip
	var away := clampf((-GameConfig.passerby_bag_clear * scale.x - local_grip.x) / length, -0.8, 0.8)
	var swing_x := minf(_bag_swing.x, asin(away)) if away < 0.8 else _bag_swing.x
	_bag.global_transform = Transform3D(yaw * Basis(Vector3.RIGHT, -_bag_swing.y) * Basis(Vector3.BACK, swing_x), grip)
	if _bag_down > 0.0:
		_bag.global_transform = _bag.global_transform.interpolate_with(_bag_ground(), smoothstep(0.0, 1.0, _bag_down))


## Wo die Tasche im Sitzen steht: rechts neben den Füßen auf dem Boden, leicht schräg (Ursprung der Tasche = Griff oben).
func _bag_ground() -> Transform3D:
	if _bag_height <= 0.0:
		_bag_height = _measure_bag()
	var spot: Vector2 = GameConfig.passerby_bag_ground_spot * scale.x
	var floor_point := global_transform * Vector3(spot.x, 0.0, spot.y)
	var basis := global_basis.orthonormalized() * Basis(Vector3.UP, deg_to_rad(-20.0))
	return Transform3D(basis, floor_point + Vector3.UP * _bag_height)


## Höhe der Tasche vom Griff bis zum Boden der Tasche (aus den Netzen; ohne Netz 0,3 m).
func _measure_bag() -> float:
	var lowest := 0.0
	for node in _bag.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var box := _bag.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		lowest = minf(lowest, box.position.y)
	return -lowest if lowest < -0.05 else 0.3


## Gegenstand in die rechte Hand nehmen (&"" = weglegen). Die Figur nimmt ihn nur, wo es niemand sieht (Anwohner hinter der
## geschlossenen Tür, Gäste an der Theke). &"broom" hängt nicht an der Hand: der Stiel wird beim Fegen zwischen die Hände gesetzt.
func set_prop(kind: StringName) -> void:
	if kind == _prop_kind:
		return
	if _prop:
		_prop.queue_free()
		_prop = null
	if _prop_mount:
		_prop_mount.queue_free()
		_prop_mount = null
	if _gesture_modifier:
		_gesture_modifier.grip_right = 0.0
	_prop_kind = kind
	if kind == &"" or _skeleton == null:
		return
	var scene := load(String(GameConfig.passerby_prop_models.get(String(kind), ""))) as PackedScene
	if scene == null:
		return
	_prop = scene.instantiate() as Node3D
	_prop.name = "Prop"
	if kind == &"broom":
		_skeleton.add_child(_prop)
		return
	_prop_mount = BoneAttachment3D.new()
	_prop_mount.name = "PropMount"
	_prop_mount.bone_name = "RightHand"
	_skeleton.add_child(_prop_mount)
	_prop_mount.add_child(_prop)
	var place: Dictionary = GameConfig.passerby_prop_hold.get(String(kind), {})
	_prop.position = place.get("pos", Vector3.ZERO)
	_prop.basis = (place.get("basis", Basis()) as Basis).scaled(Vector3.ONE * float(place.get("scale", 1.0)))
	if _gesture_modifier:
		_gesture_modifier.grip_right = 1.0


func get_prop() -> StringName:
	return _prop_kind


## Sitzt sofort (feste Gäste beim Start), ohne Hinsetz-Bewegung.
func snap_seated() -> void:
	_prev_state = &"sit"
	_seated = 1.0
	_transition = &""
	if _player and _player.has_animation(sit_clip):
		_player.play(sit_clip, 0.0)


## Eine Arbeit beginnen: "water" (gießen, Animation water hin und her) oder "sweep" (fegen, Geste über der Grundhaltung).
## Liefert die Dauer.
func start_chore(kind: String, seconds: float) -> float:
	_chore = kind
	_chore_time = 0.0
	if kind == "water":
		trigger_face(&"water")
		return play_clip(&"water", -1.0, GameConfig.chore_water_hold, seconds)
	if _gesture_modifier:
		trigger_face(&"sweep")
		_gesture_modifier.body_scale = _hip_height / 0.607
		_gesture = ChibiGestureModifier.Gesture.SWEEP
		_gesture_left = seconds
		_gesture_time = 0.0
	return seconds


func stop_chore() -> void:
	_chore = ""
	if _gesture == ChibiGestureModifier.Gesture.SWEEP:
		_gesture = ChibiGestureModifier.Gesture.NONE


## Umarmung beginnen (Partner seitlich: side = +1 links, -1 rechts).
func start_hug(side: float, seconds: float) -> void:
	if _gesture_modifier == null:
		return
	_hugging = true
	_gesture_modifier.body_scale = _hip_height / 0.607
	_gesture_modifier.hug_side = side
	_gesture = ChibiGestureModifier.Gesture.HUG
	_gesture_left = seconds
	_gesture_time = 0.0
	trigger_face(&"hug")


## Im Sitzen einen Schluck trinken bzw. ein Stück essen (rechte Hand mit dem Gegenstand zum Mund und zurück).
func take_sip() -> void:
	if _gesture_modifier == null or _prev_state != &"sit":
		return
	_gesture_modifier.body_scale = _hip_height / 0.607
	_gesture = ChibiGestureModifier.Gesture.DRINK
	_gesture_left = 2.6
	_gesture_time = 0.0
	_sip_t = 0.0


func _update_chore(delta: float) -> void:
	if _prop_kind == &"broom" and _prop and _gesture_modifier:
		# Besen zwischen den Händen (solange gefegt wird, sonst aufrecht in der Hand neben der Figur)
		if _chore == "sweep":
			_chore_time += delta
			var p := ChibiGestureModifier.sweep_points(_gesture_time, _gesture_modifier.body_scale)
			var head: Vector3 = p.head
			var top: Vector3 = p.top
			var along := top - head
			var y := along.normalized()
			var x := y.cross(Vector3.FORWARD).normalized()
			# der Stiel reicht bis knapp über die obere Hand (Modell: 1,02 m)
			_prop.transform = Transform3D(Basis(x, y, x.cross(y)).scaled(Vector3.ONE * ((along.length() + 0.07) / 1.02)), head)
		else:
			_prop.transform = Transform3D(Basis(), Vector3(-0.28 * _gesture_modifier.body_scale, 0.0, 0.05))
	if _gesture_modifier and _gesture == ChibiGestureModifier.Gesture.DRINK and _sip_t >= 0.0:
		_sip_t += delta
		_gesture_modifier.sip = sin(clampf(_sip_t / 2.4, 0.0, 1.0) * PI)
		if _sip_t >= 2.4:
			_sip_t = -1.0
	if _hugging and _gesture != ChibiGestureModifier.Gesture.HUG:
		_hugging = false


## Radfahren: Haltung zur Kurbelstellung crank (Bogenmaß; 0 = Kurbel auf der Seite x < 0 vorn,
## wachsend = vorwärts treten). Die Animation "ride" ist genau eine Kurbelumdrehung; der Kopf schaut
## ab und zu ein wenig zur Seite.
func pose_ride(crank: float, delta: float, stop: float = 0.0) -> void:
	if _player == null or not _player.has_animation(&"ride"):
		return
	_time += delta
	if _player.current_animation != &"ride":
		_player.play(&"ride", 0.0)
	_player.speed_scale = 0.0
	_player.seek(fposmod(crank / TAU, 1.0) * _player.get_animation(&"ride").length, true)
	# Anhalten: die Haltung mit dem Fuß auf dem Boden als eigene Ebene darüber, Gewicht = stop (weich hin und zurück).
	# Nicht über das Überblenden des AnimationPlayers – das steht bei Tempo 0 still und bliebe halb hängen.
	if stop > 0.0 and _player.has_animation(&"ride_stop"):
		if _ride_mod == null:
			var bones := PackedStringArray()
			for i in _skeleton.get_bone_count():
				bones.append(_skeleton.get_bone_name(i))
			_ride_mod = _layer("RideStopLayer", bones)
			# gleich nach den Formreglern, vor allen anderen Ebenen (Kopf und Blick wirken weiter)
			var shape := _skeleton.get_node_or_null("ShapeModifier")
			_skeleton.move_child(_ride_mod, shape.get_index() + 1 if shape else 0)
			_ride_mod.set_clip(_player.get_animation(&"ride_stop"), _clip_prefix(), bones)
			_ride_mod.clip_time = 0.0
		_ride_mod.gesture = ChibiGestureModifier.Gesture.CLIP
		_ride_mod.weight = smoothstep(0.0, 1.0, stop)
	elif _ride_mod:
		_ride_mod.gesture = ChibiGestureModifier.Gesture.NONE
		_ride_mod.weight = 0.0
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


## Einzelner Auftritt einer Animation der Figur: im Stehen (z. B. &"look_around", &"wave", &"handshake") oder im
## Sitzen (Namen mit "sit_"). max_time = höchstens so lange (weich zurück in die Grundhaltung); hold = Abschnitt
## [von, bis] (s), der hold_time Sekunden hin und her läuft; back = danach rückwärts zum Anfang (bücken und wieder
## aufrichten). Liefert die Dauer (0 = gibt es nicht). Losgehen beendet den Auftritt sofort.
func play_clip(clip: StringName, max_time: float = -1.0, hold: Vector2 = Vector2.ZERO, hold_time: float = 0.0,
		back: bool = false, start: float = 0.0) -> float:
	if _player == null or not _player.has_animation(clip):
		return 0.0
	var length := _player.get_animation(clip).length
	var duration := length
	if not clip in FULL_BODY and hold_time <= 0.0 and not back:
		# nur Oberkörper, Kopf und Arme – die Beine bleiben in der Grundhaltung
		duration = minf(length, max_time) if max_time > 0.0 else length
		_upper = {"clip": clip, "t": 0.0, "left": duration, "loop": false, "seated": String(clip).begins_with("sit_")}
		return duration
	if hold_time > 0.0 or back:
		# rückwärts endet er von selbst am Anfang (die Zeit ist nur eine Obergrenze)
		duration = hold.y + hold_time + (hold.y + 1.0 if back else length - hold.y)
	if max_time > 0.0:
		duration = minf(duration, max_time)
	_shot = {"clip": clip, "left": duration, "hold": hold, "hold_left": hold_time, "back": back, "dir": 1.0,
		"holding": false, "seated": String(clip).begins_with("sit_")}
	_player.play(clip, BLEND)
	_player.seek(start)
	return duration


## Läuft gerade ein einzelner Auftritt?
func is_playing_clip() -> bool:
	return not _shot.is_empty() or (not _upper.is_empty() and not bool(_upper.loop))


## Eine Ebene über der Grundbewegung (übernimmt die Drehungen dieser Knochen aus einer Animation, weich ein-/ausgeblendet).
func _layer(layer_name: String, bones: PackedStringArray) -> ChibiGestureModifier:
	var layer := ChibiGestureModifier.new()
	layer.name = layer_name
	layer.clip_wave_fix = false
	layer.set_meta("bones", bones)
	_skeleton.add_child(layer)
	return layer


## Ebenen je Bild: Oberkörper (Auftritt oder Reden), Beine im Sitzen übereinander.
func _update_layers(state: StringName, walking: bool, delta: float) -> void:
	if _upper_mod == null or _player == null:
		return
	var seated := state == &"sit" and _transition == &""
	# Reden als Schleife (solange niemand einen Auftritt hat)
	if _talking and _talk_clip != &"" and (_upper.is_empty() or bool(_upper.loop)) and not walking:
		if _upper.get("clip", &"") != _talk_clip:
			_upper = {"clip": _talk_clip, "t": randf() * _player.get_animation(_talk_clip).length, "left": INF, "loop": true,
				"seated": String(_talk_clip).begins_with("sit_")}
	elif not _talking and not _upper.is_empty() and bool(_upper.loop):
		_upper.left = minf(float(_upper.left), 0.35)  # ausblenden
	var want := 0.0
	if not _upper.is_empty():
		var fits := not walking and bool(_upper.seated) == seated and _transition == &""
		var anim := _player.get_animation(_upper.clip)
		_upper.t = float(_upper.t) + delta
		_upper.left = float(_upper.left) - delta
		if not fits or float(_upper.left) <= 0.0:
			_upper = {}
		else:
			if _upper_mod.clip != anim:
				_upper_mod.set_clip(anim, _clip_prefix(), _upper_mod.get_meta("bones"))
			var t := float(_upper.t)
			if anim.loop_mode == Animation.LOOP_PINGPONG:
				t = pingpong(t, anim.length)
			elif bool(_upper.loop):
				t = fposmod(t, anim.length)
			_upper_mod.clip_time = minf(t, anim.length)
			_upper_mod.gesture = ChibiGestureModifier.Gesture.CLIP
			want = clampf(float(_upper.left) / LAYER_BLEND, 0.0, 1.0)
	_upper_mod.weight = move_toward(_upper_mod.weight, want, delta / LAYER_BLEND)
	if _upper_mod.weight <= 0.0 and _upper.is_empty():
		_upper_mod.gesture = ChibiGestureModifier.Gesture.NONE
	# Beine übereinander: im Sitzen nach ein paar Sekunden manchmal, beim Aufstehen weich wieder auseinander
	if seated:
		_legs_wait -= delta
		if _legs_wait <= 0.0:
			_legs_wait = randf_range(8.0, 20.0)
			_legs_cross = randf() < GameConfig.passerby_cross_legs_chance
	else:
		_legs_cross = false
		_legs_wait = randf_range(2.0, 5.0)
	if _legs_cross and _player.has_animation(&"sit_talk_legs") and _legs_mod.clip == null:
		_legs_mod.set_clip(_player.get_animation(&"sit_talk_legs"), _clip_prefix(), _legs_mod.get_meta("bones"))
		_legs_mod.clip_time = LEGS_CROSSED_TIME
		_legs_mod.gesture = ChibiGestureModifier.Gesture.CLIP
	_legs_mod.weight = move_toward(_legs_mod.weight, 1.0 if _legs_cross else 0.0,
		delta / (GameConfig.passerby_cross_legs_time if _legs_cross or seated else 0.35))
	if _legs_mod.weight <= 0.0 and not _legs_cross:
		_legs_mod.gesture = ChibiGestureModifier.Gesture.NONE
		_legs_mod.clip = null


func _clip_prefix() -> String:
	return str(_player.get_node(_player.root_node).get_path_to(_skeleton))


## Eine Pause unterwegs (StreetLife): &"watch" = auf die Uhr schauen (mit Tasche watch_bag, sonst die Geste),
## sonst eine Animation der Figur (look_around, stretch_arms, yawn …). Liefert die Dauer.
func play_pause(kind: StringName) -> float:
	var longest := GameConfig.passerby_pause_clip_max
	if kind == &"watch":
		if carries_bag and _player and _player.has_animation(&"watch_bag"):
			trigger_face(&"watch")
			return play_clip(&"watch_bag", longest)
		play_gesture(&"watch")
		return 2.6
	if carries_bag and kind != &"look_around":
		return 0.0  # mit Tasche nur umschauen und auf die Uhr schauen
	var duration := play_clip(kind, longest)
	if duration > 0.0:
		var faces := {&"stretch_arms": &"stretch", &"stretch_neck": &"stretch", &"yawn": &"yawn", &"sigh": &"sigh"}
		if faces.has(kind):
			trigger_face(faces[kind])
	return duration


## Eine Geste zusätzlich zur Animation: &"wave" (winken), &"watch" (auf die Uhr schauen), &"stretch"
## (sich strecken). duration < 0: die übliche Dauer der Geste.
func play_gesture(gesture_name: StringName, duration: float = -1.0) -> void:
	var gestures := {&"wave": [ChibiGestureModifier.Gesture.WAVE, 2.2], &"watch": [ChibiGestureModifier.Gesture.WATCH, 2.6],
		&"stretch": [ChibiGestureModifier.Gesture.STRETCH, 2.4]}
	if not gestures.has(gesture_name):
		return
	# Winken seit Etappe 6h mit der Wink-Animation: nur der rechte Arm, über Gehen oder Sitzen gelegt
	if gesture_name == &"wave" and _gesture_modifier and _player and _player.has_animation(&"wave"):
		var prefix := str(_player.get_node(_player.root_node).get_path_to(_skeleton))
		_gesture_modifier.set_clip(_player.get_animation(&"wave"), prefix, RIGHT_ARM)
		_gesture = ChibiGestureModifier.Gesture.CLIP
		_gesture_left = minf(duration, WAVE_CLIP.y - WAVE_CLIP.x) if duration > 0.0 else WAVE_CLIP.y - WAVE_CLIP.x
		_gesture_time = 0.0
		return
	_gesture = gestures[gesture_name][0]
	_gesture_left = duration if duration > 0.0 else float(gestures[gesture_name][1])
	_gesture_time = 0.0
	if gesture_name == &"watch":
		trigger_face(&"watch")
	elif gesture_name == &"stretch":
		trigger_face(&"stretch")


## Beim Plaudern erzählen die Hände mit (bis set_talking(false)): eine der Animationen talk/talk_one/talk_two
## (im Sitzen sit_talk…), an zufälliger Stelle begonnen; mit Tasche ohne Hände.
func set_talking(on: bool) -> void:
	if on and not _talking:
		var seated := _prev_state == &"sit"
		var options: Array[StringName] = []
		for c: StringName in ([&"sit_talk", &"sit_talk_legs", &"sit_talk_hands"] if seated else [&"talk", &"talk_one", &"talk_two"]):
			if _player != null and _player.has_animation(c):
				options.append(c)
		_talk_clip = &"" if options.is_empty() or (carries_bag and not seated) else options.pick_random()
	_talking = on
	# der Mund spricht mit (ChibiCharacter.talking: wechselnde Mundbilder a/e/o, dazwischen geschlossen)
	talking = on


## Plaudern: Wer erzählt, zeigt manchmal irgendwohin oder gestikuliert; wer zuhört, nickt, wiegt den Kopf oder
## lacht mit (nur Frauen, wie bei den Lauten). laughing = dieser Wechsel ist lustig.
func chat_react(speaking: bool, laughing: bool) -> void:
	var seated := _prev_state == &"sit"
	if not _shot.is_empty():
		return
	if _prev_state == &"walk":
		# im Gehen keine Auftritte (die Beine gehen weiter): nur nicken
		if not speaking and randf() < GameConfig.passerby_chat_nod_chance:
			_nod_t = 0.0
		return
	if speaking:
		if not seated and not carries_bag and randf() < GameConfig.passerby_chat_gesture_chance:
			play_clip([&"point", &"point_back", &"gesture"].pick_random())
		return
	if laughing and int(figure) < 3 and not carries_bag:
		play_clip(&"sit_laugh" if seated else &"laugh", 3.2)
	elif randf() < GameConfig.passerby_chat_nod_chance:
		if seated or carries_bag:
			_nod_t = 0.0
		else:
			play_clip([&"nod", &"nod", &"nod_think", &"shake_think", &"shake_head"].pick_random())


## Katze, die gerade gestreichelt wird (seit Etappe 6j: die rechte Hand legt sich auf ihren Kopf; null = keine).
func set_pet_target(cat: Node3D) -> void:
	_pet_target = cat


var _show_at: Variant = null


## Rechte Hand zu einer Stelle (Welt) heben, z. B. den Leseausweis über die Theke halten (seit Etappe 7); null = nicht.
func show_hand_at(point: Variant) -> void:
	_show_at = point


## Lesen (seit Testrunde 7b, Bücherei): ein aufgeschlagenes Buch mit beiden Händen vor der Brust, der Blick ruht darauf.
var _reading := false
var _read_book: Node3D


func set_reading(on: bool) -> void:
	_reading = on
	if on and _read_book == null:
		_read_book = _make_open_book()
		add_child(_read_book)
		_read_book.top_level = true
		look_at_node(_read_book)
	if not on and _read_book and _attention == _read_book:
		look_at_node(null)


## Aufgeschlagenes Buch: zwei Seitenblöcke in flachem V auf einem Einband (einfache Körper).
func _make_open_book() -> Node3D:
	var book := Node3D.new()
	book.name = "OpenBook"
	var cover := StandardMaterial3D.new()
	cover.albedo_color = Color.from_hsv(randf(), 0.45, 0.55)
	cover.roughness = 0.85
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.94, 0.9, 0.8)
	paper.roughness = 0.9
	for side: float in [-1.0, 1.0]:
		var half := Node3D.new()
		half.rotation.z = side * deg_to_rad(9.0)
		book.add_child(half)
		var c := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(0.078, 0.004, 0.105)
		c.mesh = cb
		c.material_override = cover
		c.position = Vector3(side * 0.04, -0.002, 0.0)
		half.add_child(c)
		var p := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.072, 0.012, 0.098)
		p.mesh = pb
		p.material_override = paper
		p.position = Vector3(side * 0.038, 0.006, 0.0)
		half.add_child(p)
	return book


func _update_pet(delta: float) -> void:
	if _gesture_modifier == null:
		return
	var petting: bool = _pet_target != null and is_instance_valid(_pet_target) and not _shot.is_empty() \
		and _shot.clip in [&"pet_reach", &"pet_cat"]
	if petting and _pet_target.has_method("head_top"):
		_gesture_modifier.pet_point = _skeleton.global_transform.affine_inverse() * (_pet_target.call("head_top") as Vector3)
	# Lesen: Buch vor der Brust, leicht zum Gesicht gekippt; die Hände halten es (ChibiGestureModifier.read_point)
	if _read_book:
		var chest := _skeleton.find_bone("UpperChest")
		if chest < 0:
			chest = _skeleton.find_bone("Chest")
		var base := _skeleton.get_bone_global_pose(chest).origin if chest >= 0 else Vector3(0, _hip_height * 1.4, 0)
		var scale_now := _hip_height / 0.607
		var point := base + Vector3(0.0, -0.13, 0.2) * scale_now
		_gesture_modifier.read_point = point
		_gesture_modifier.read_weight = move_toward(_gesture_modifier.read_weight, 1.0 if _reading else 0.0, delta / 0.6)
		_read_book.global_transform = _skeleton.global_transform * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-28.0))
			.scaled(Vector3.ONE * scale_now * 1.25), point)
		_read_book.visible = _gesture_modifier.read_weight > 0.3
		if not _reading and _gesture_modifier.read_weight <= 0.0:
			_read_book.queue_free()
			_read_book = null
	var showing := _show_at is Vector3
	if showing:
		_gesture_modifier.show_point = _skeleton.global_transform.affine_inverse() * (_show_at as Vector3)
	_gesture_modifier.show_weight = move_toward(_gesture_modifier.show_weight, 1.0 if showing else 0.0, delta / 0.4)
	_gesture_modifier.body_scale = _hip_height / 0.607
	_gesture_modifier.pet_weight = move_toward(_gesture_modifier.pet_weight, 1.0 if petting else 0.0, delta / 0.3)


## Wen die Figur beim Plaudern anschaut (null = niemand Bestimmtes).
func set_chat_partner(partner: Node3D) -> void:
	_chat_partner = partner


## Etwas gezielt anschauen (Katze an den Beinen, Auto beim Warten am Bordstein; null = wieder wie sonst) – hat Vorrang
## vor allem anderen, auch vor der Spielfigur.
func look_at_node(node: Node3D) -> void:
	_attention = node


func _update_gesture(delta: float) -> void:
	if _gesture_modifier == null:
		return
	_gesture_time += delta
	var active := _gesture
	if _gesture != ChibiGestureModifier.Gesture.NONE:
		_gesture_left -= delta
		if _gesture_left <= 0.0:
			_gesture = ChibiGestureModifier.Gesture.NONE
	elif _talking and (_talk_clip == &"" or _prev_state == &"walk") and not carries_bag:
		active = ChibiGestureModifier.Gesture.TALK  # im Gehen (zu zweit) erzählen die Hände über die Geste
	var fading_in := _gesture != ChibiGestureModifier.Gesture.NONE or active == ChibiGestureModifier.Gesture.TALK
	if fading_in and active != ChibiGestureModifier.Gesture.NONE:
		if _gesture_modifier.gesture != active:
			_gesture_modifier.weight = 0.0
			_gesture_modifier.time = 0.0
		_gesture_modifier.gesture = active
		var ramp := 0.45 if _gesture_left > 0.4 or active == ChibiGestureModifier.Gesture.TALK else _gesture_left / 0.4 * 0.45
		var full := 0.65 if _prev_state == &"walk" else 1.0  # im Gehen schwingen die Arme noch etwas mit
		_gesture_modifier.weight = move_toward(_gesture_modifier.weight, full if ramp >= 0.45 else ramp / 0.45 * full, delta / 0.35)
	else:
		_gesture_modifier.weight = move_toward(_gesture_modifier.weight, 0.0, delta / 0.35)
		if _gesture_modifier.weight <= 0.0:
			_gesture_modifier.gesture = ChibiGestureModifier.Gesture.NONE
	_gesture_modifier.time = _gesture_time
	_gesture_modifier.clip_time = WAVE_CLIP.x + _gesture_time
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
	# passender kurzer Laut (Lachen, „hm“, „oh“) – sparsam, siehe PasserbyVoice
	var head := to_local(eye_point()).y + 0.05 if is_inside_tree() else 1.0
	_voice_last = PasserbyVoice.speak(self, trigger, int(figure) < 3, head, _voice_last)


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
	if _attention and is_instance_valid(_attention) and _attention.is_visible_in_tree():
		_focus = _attention
		return
	var now_s := Time.get_ticks_msec() / 1000.0
	if camera and now_s >= _player_rest_until:
		var dist := _focus_distance(me, forward, camera.global_position, GameConfig.chibi_look_player_radius,
			GameConfig.chibi_look_angle)
		if dist < INF and _line_clear(me, camera.global_position):
			best = camera
			best_dist = dist
	# Nur kurz zur Spielfigur schauen (seit Etappe 6f): nach chibi_player_glance_time Sekunden wieder zum
	# Gegenüber bzw. nach vorn, und eine Weile nicht mehr – sonst starrten plaudernde Passanten die ganze Zeit
	if best == camera and best != null:
		if _player_look_since < 0.0:
			_player_look_since = now_s
		elif now_s - _player_look_since > GameConfig.chibi_player_glance_time:
			_player_rest_until = now_s + GameConfig.chibi_player_glance_rest
			_player_look_since = -1.0
			best = null
			best_dist = INF
	else:
		_player_look_since = -1.0
	# Beim gemeinsamen Gehen mal zum Gegenüber, mal auf den Weg schauen (sonst starren sie sich die ganze Strecke an),
	# beim Überqueren der Fahrbahn gar nicht
	var partner_ok: bool = _chat_partner != null and is_instance_valid(_chat_partner) and _chat_partner.is_visible_in_tree() \
		and not road_scan
	if partner_ok and _prev_state == &"walk":
		if now_s >= _walk_look_until:
			_walk_look_on = not _walk_look_on
			var span: Vector2 = GameConfig.passerby_walk_look_time if _walk_look_on else GameConfig.passerby_walk_away_time
			_walk_look_until = now_s + randf_range(span.x, span.y)
		partner_ok = _walk_look_on
	if best == null and partner_ok:
		best = _chat_partner
		best_dist = me.distance_to(_chat_partner.global_position)
	if best == null:
		for other in _everyone:
			if other == self or not other.is_visible_in_tree() or other == _chat_partner:
				continue
			var dist := _focus_distance(me, forward, other.eye_point(), GameConfig.chibi_look_others_radius,
				GameConfig.chibi_look_others_angle)
			if dist < best_dist:
				best = other
				best_dist = dist
	_focus = best
	if best == null or best_dist > GameConfig.chibi_greet_radius:
		return
	# Wer im Auto oder auf dem Rad sitzt, wird angeschaut, aber nicht gegrüßt (kein Winken zu Autofahrern)
	if best is ChibiPasserbyModel and not (best.get_parent() is Passerby):
		return
	var id := best.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_greeted.get(id, -INF)) < GameConfig.chibi_greet_cooldown:
		return
	_greeted[id] = now
	var chance := GameConfig.chibi_greet_chance_player if best == camera else GameConfig.chibi_greet_chance_others
	if randf() < chance:
		# Grüßen: Lächeln und Nicken, manchmal auch winken; die Spielfigur seit der Nachbesserung von 6h auch mit Nicken
		# und Lachen (Augen zu) – und dafür meist kurz stehen bleiben und sich zu ihr drehen (nie beim Winken wegdrehen)
		var to_player := best == camera
		var wave_chance := GameConfig.chibi_wave_chance_player if to_player else GameConfig.chibi_wave_chance
		var wave := randf() < wave_chance and not carries_bag
		# Nicken geht im Vorbeigehen; wer winkt, bleibt dafür stehen und dreht sich zu dem Gegrüßten (seit der Nachbesserung
		# von 6h) – geht das gerade nicht (über die Straße, Gedränge), wird genickt statt gewinkt
		if wave and _prev_state == &"walk":
			var walker := get_parent()
			var stopped := false
			if to_player and walker and walker.has_method("greet_stop"):
				stopped = bool(walker.call("greet_stop", camera.global_position, GameConfig.chibi_greet_stop_time))
			wave = stopped
		trigger_face(&"wave" if wave else (&"greet_laugh" if to_player and randf() < 0.5 else &"greet"))
		_nod_t = 0.0
		if wave:
			wave_hello()


## Sitzen entspannt: zurückgelehnt, Hände auf den Oberschenkeln; wer sich anlehnt, rutscht auf dem Sitz nach hinten bis an
## die Lehne. Weich hin und zurück; beim Reden (Ebene mit Handbewegungen) lösen sich die Hände.
func _update_sit_rest(state: StringName, delta: float) -> void:
	var sitting := relaxed_sit and state == &"sit" and _transition == &""
	var lean_want := GameConfig.passerby_sit_lean if sitting else 0.0
	var round_want := GameConfig.passerby_sit_round if sitting else 0.0
	var shift_want := 0.0
	if sitting and sit_leans and sit_backrest > 0.0:
		var t := clampf(inverse_lerp(0.13, 0.24, sit_backrest), 0.0, 1.0)
		lean_want = lerpf(GameConfig.passerby_sit_lean_chair, GameConfig.passerby_sit_lean_bench, t)
		round_want = GameConfig.passerby_sit_round_lean
		shift_want = maxf(0.0, sit_backrest - (GameConfig.passerby_sit_back_depth + 0.03 * maxf(body_shape, 0.0)))
	# Beine übereinander: runder Rücken, nach vorn gebeugt; sonst zurückgelehnt, die Schultern über der Hüfte
	if sitting and _legs_mod:
		lean_want = lerpf(lean_want, GameConfig.passerby_sit_lean_crossed, _legs_mod.weight)
		round_want = lerpf(round_want, GameConfig.passerby_sit_round_crossed, _legs_mod.weight)
	var step := delta / GameConfig.passerby_sit_lean_time
	_gesture_modifier.lean = move_toward(_gesture_modifier.lean, lean_want, step * 25.0)
	_gesture_modifier.round_back = move_toward(_gesture_modifier.round_back, round_want, step * 25.0)
	_back_shift = move_toward(_back_shift, shift_want, step * 0.2)
	_model.position.z = -_back_shift
	var talking_hands := _upper_mod.weight if _upper_mod else 0.0
	_gesture_modifier.thigh_lift = GameConfig.passerby_sit_hand_lift + 0.02 * maxf(body_shape, 0.0)
	_gesture_modifier.hands_on_thighs = move_toward(_gesture_modifier.hands_on_thighs, (1.0 if sitting else 0.0) * (1.0 - talking_hands), step * 2.0)


## Winken (seit Etappe 6h immer mit der Wink-Animation: der rechte Arm wird über Gehen, Stehen oder Sitzen gelegt,
## der Oberarm etwas weiter außen – siehe ChibiGestureModifier.clip_arm_out).
func wave_hello(max_time: float = 3.0) -> void:
	play_gesture(&"wave", max_time)


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
	if _focus is StreetCat:
		return _focus.global_position + Vector3.UP * 0.15 * _focus.scale.y
	if _focus is StreetVehicle:
		return _focus.global_position + Vector3.UP * 0.8
	return _focus.global_position


## Sieht man von a nach b? (Häuser und Mauern verdecken, Glas mit Metadaten "see_through" nicht)
func _line_clear(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a, b, SIGHT_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.collider as Object).has_meta("see_through")
